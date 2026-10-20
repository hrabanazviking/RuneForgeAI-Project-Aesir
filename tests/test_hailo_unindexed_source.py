#!/usr/bin/env python3
"""Actual ordinary source without a fabricated index, metadata only."""
import argparse
from collections import Counter
import copy
import json
import os
from pathlib import Path
import random
import re
import struct
import subprocess
import tempfile
import unittest
from test_hailo_safetensors_inventory import fixture
from test_hailo_shard_collection import DEFAULT

CONFIG=argparse.Namespace()
UNINDEXED=[DEFAULT[0],DEFAULT[2],DEFAULT[3],DEFAULT[4]]


class UnindexedSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for name in ("binary","api","indexed","baseline","faults"):
            setattr(cls,name,str(Path(getattr(CONFIG,name)).resolve(strict=True)))
        cls.temp=tempfile.TemporaryDirectory(prefix="aesir-unindexed-source-")
        cls.base=Path(cls.temp.name);cls.counter=0;cls.records=[]
        cls.evidence=Path(CONFIG.evidence).resolve();cls.evidence.mkdir(parents=True,exist_ok=True)

    @classmethod
    def tearDownClass(cls):
        (cls.evidence/"runs.json").write_text(json.dumps(cls.records,indent=2)+"\n")
        counts=dict(Counter("accepted" if x["returncode"]==0 else "refused" for x in cls.records))
        (cls.evidence/"summary.json").write_text(json.dumps(counts,indent=2)+"\n")
        print("Native outcomes:",counts);cls.temp.cleanup()

    def child(self,args,trace=None,env=None):
        if trace:args=[CONFIG.strace,"-y","-o",str(self.evidence/trace),"-e","trace=openat,openat2,close,statx,read,pread64,write,mmap,munmap,ioctl",*args]
        args=list(map(str,args));r=subprocess.run(args,capture_output=True,text=True,timeout=15,stdin=subprocess.DEVNULL,check=False,env=env)
        self.records.append({"arguments":args,"returncode":r.returncode,"stdout":r.stdout,"stderr":r.stderr})
        return r

    def source(self,tensors,label="ordinary.weights",config=None):
        type(self).counter+=1;root=self.base/f"model-{self.counter}";root.mkdir()
        raw,expected,metadata=fixture(tensors,{"origin":"synthetic\0Æsir"})
        (root/label).parent.mkdir(parents=True,exist_ok=True);(root/label).write_bytes(raw)
        if config is None:config={"model_type":"future","future":{"rotary":[1,0]},"tie_word_embeddings":False}
        (root/"config.json").write_text(json.dumps(config,ensure_ascii=False))
        return root,raw,expected,config

    def invoke(self,root,label="ordinary.weights",policy=None,trace=None,env=None):
        return self.child([self.binary,root,label,"config.json",*[n for group in policy or UNINDEXED for n in group]],trace,env)

    def accept(self,r):
        self.assertEqual(r.returncode,0,r.stdout+r.stderr);value=json.loads(r.stdout)
        for key in ("index_present","index_tensor_binding_verified","tensor_values_loaded","semantic_adapter_verified","source_fingerprint_verified","hardware_fit_verified","execution_tested"):
            self.assertIs(value[key],False)
        self.assertNotIn("index",value)
        return value

    def refuse(self,r):
        self.assertNotEqual(r.returncode,0,r.stdout);self.assertEqual(r.stdout,"")

    def check(self,tensors,label="ordinary.weights",ownership=False):
        root,raw,want,config=self.source(tensors,label)
        r=self.child([self.api,"ownership",root,label,"config.json"]) if ownership else self.invoke(root,label)
        value=self.accept(r);base=8+struct.unpack("<Q",raw[:8])[0]
        self.assertEqual(value["source"]["label"],label)
        self.assertEqual(value["source"]["storage"]["source_path"],str(root/label))
        self.assertEqual(value["tensor_count"],len(want))
        self.assertEqual(value["metadata_bytes"],len((root/"config.json").read_bytes())+base)
        self.assertEqual(value["payload_bytes"],len(raw)-base)
        axes=sum(len(t[2]) for t in tensors)
        self.assertEqual(value["work_units"],value["metadata_bytes"]+1+len(want)+axes)
        self.assertEqual({k:json.loads(v) for k,v in value["config"]["fields_raw"].items()},config)
        index={"weight_map":{name:label for name in want},"metadata":{"total_size":len(raw)-base}}
        (root/"index.json").write_text(json.dumps(index,ensure_ascii=False))
        args=[root,"index.json","config.json",*[n for group in DEFAULT for n in group]]
        old=self.child([self.baseline,*args]);current=self.child([self.indexed,*args])
        self.assertEqual(old.returncode,0,old.stderr);self.assertEqual(current.returncode,0,current.stderr)
        self.assertEqual(json.loads(old.stdout),json.loads(current.stdout))
        if want:self.assertEqual(value["source"],json.loads(current.stdout)["shards"][0])
        self.assertEqual(value["config"],json.loads(current.stdout)["config"])
        self.assertEqual((root/label).read_bytes(),raw)
        # An unrelated malformed index must not affect direct ordinary-file loading.
        (root/"index.json").write_text("{not an index}")
        self.assertEqual(value,self.accept(self.invoke(root,label)))
        return root,value

    def test_single_file_names_shapes_and_frozen_indexed_output(self):
        self.check([],ownership=True)
        self.check([("Æsir\0🜁","BF16",[2,3]),("scalar","F32",[]),("empty","F16",[2,0,4])],"Æsir.weights",True)
        rng=random.Random(101069)
        for i in range(30):
            tensors=[]
            for j in range(i%7):
                shape=[rng.randrange(0,4) for _ in range(rng.randrange(0,5))]
                tensors.append((f"layer-{j}",rng.choice(["F16","BF16","F32"]),shape))
            self.check(tensors,ownership=i%5==0)

    def test_exact_policies_and_missing_or_malformed_sources(self):
        root,value=self.check([("x","F16",[2]),("bias","F32",[])])
        p=copy.deepcopy(UNINDEXED)
        p[0][1]=2;p[0][2]=len(str(root).encode())+len("config.json")+1+len("ordinary.weights")+1
        p[3]=[1,2,value["metadata_bytes"],value["payload_bytes"],value["work_units"]]
        self.accept(self.invoke(root,policy=p))
        for j in range(5):
            bad=copy.deepcopy(p);bad[3][j]-=1;self.refuse(self.invoke(root,policy=bad))
        for group in range(4):
            for j in range(len(p[group])):
                bad=copy.deepcopy(UNINDEXED);bad[group][j]=0;self.refuse(self.invoke(root,policy=bad))
        for group,j in ((1,3),(2,4)):
            bad=copy.deepcopy(p);bad[group][j]=65;self.refuse(self.invoke(root,policy=bad))
        for j in (1,2):
            bad=copy.deepcopy(p);bad[0][j]-=1;self.refuse(self.invoke(root,policy=bad))
        for label in ("missing","../escape",str(root/"ordinary.weights"),""):
            self.refuse(self.invoke(root,label))
        os.mkfifo(root/"pipe")
        self.refuse(self.invoke(root,"pipe"))
        (root/"dir").mkdir();self.refuse(self.invoke(root,"dir"))
        (root/"link").symlink_to("../outside.weights");self.refuse(self.invoke(root,"link"))
        (root/"bad").write_bytes(b"bad");self.refuse(self.invoke(root,"bad"))
        (root/"config.json").write_text("{bad}");self.refuse(self.invoke(root))

    def test_only_real_config_and_weight_file_reads(self):
        root,raw,_,_=self.source([("x","BF16",[2])])
        self.accept(self.invoke(root,trace="single-source.strace"))
        text=(self.evidence/"single-source.strace").read_text();base=8+struct.unpack("<Q",raw[:8])[0]
        self.assertNotIn("index.json",text);self.assertNotIn("ioctl(",text)
        for label in ("config.json","ordinary.weights"):
            path=root/label
            self.assertEqual(sum("openat2(" in x and "\""+label+"\"" in x for x in text.splitlines()),1)
            self.assertEqual(sum("close(" in x and f"<{path}>" in x for x in text.splitlines()),1)
            self.assertFalse(any("mmap(" in x and f"<{path}>" in x for x in text.splitlines()))
        copied=0
        for line in text.splitlines():
            if "pread64(" in line and f"<{root/'ordinary.weights'}>" in line:
                match=re.search(r", (\d+), (\d+)\)\s+=\s+(\d+)",line);self.assertIsNotNone(match,line)
                _,offset,n=map(int,match.groups());self.assertLessEqual(offset+n,base);copied+=n
        self.assertEqual(copied,base)

    def test_late_failures_and_implicit_error_cleanup(self):
        root,_,_,_=self.source([("x","F16",[1])])
        (root/"invalid.safetensors").write_bytes(b"bad")
        r=self.child([self.api,"cleanup",root,"ordinary.weights","config.json"],"cleanup.strace")
        self.assertEqual(r.returncode,0,r.stderr);self.assertEqual(json.loads(r.stdout)["cleanup_cycles"],20)
        text=(self.evidence/"cleanup.strace").read_text()
        for label,count in (("config.json",40),("ordinary.weights",20),("invalid.safetensors",20)):
            self.assertEqual(sum("close(" in x and f"<{root/label}>" in x for x in text.splitlines()),count)
        self.assertEqual(sum("close(" in x and f"<{root}>" in x for x in text.splitlines()),40)
        for label in ("config.json","ordinary.weights"):
            for mode in ("read","changed","close"):
                env=os.environ.copy();env.update(LD_PRELOAD=self.faults,AESIR_FD_FAULT_LABEL=label,AESIR_FD_FAULT_MODE=mode)
                self.refuse(self.invoke(root,trace=f"fault-{label}-{mode}.strace",env=env))
                lines=(self.evidence/f"fault-{label}-{mode}.strace").read_text().splitlines()
                self.assertEqual(sum("close(" in x and f"<{root/label}>" in x for x in lines),1)
                self.assertEqual(sum("close(" in x and f"<{root}>" in x for x in lines),1)


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    for name in ("binary","api","indexed","baseline","faults","strace","evidence"):
        parser.add_argument("--"+name,required=True)
    CONFIG,rest=parser.parse_known_args()
    unittest.main(argv=["unindexed-source",*rest])
