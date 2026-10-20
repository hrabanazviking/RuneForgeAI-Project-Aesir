#!/usr/bin/env python3
"""Independent real multi-file source binding checks; no model execution."""
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

CONFIG=argparse.Namespace()
DEFAULT=[[4095,1000,10000000,9223372036854775807],
         [1048576,1000,5000,10000000,64],
         [1048576,5000,10000000,64],
         [1048576,1000,64,10000000,64,1048584],
         [100,1000,10000000,9223372036854775807,100000000]]


class ShardCollection(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for name in ("binary","api","storage","faults"):
            setattr(cls,name,str(Path(getattr(CONFIG,name)).resolve(strict=True)))
        cls.temp=tempfile.TemporaryDirectory(prefix="aesir-shard-collection-")
        cls.base=Path(cls.temp.name)
        cls.evidence=Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True,exist_ok=True)
        cls.records=[];cls.cases=0

    @classmethod
    def tearDownClass(cls):
        (cls.evidence/"runs.json").write_text(json.dumps(cls.records,indent=2)+"\n")
        counts=dict(Counter("accepted" if x["returncode"]==0 else "refused" for x in cls.records))
        (cls.evidence/"summary.json").write_text(json.dumps(counts,indent=2)+"\n")
        print("Native outcomes:",counts)
        cls.temp.cleanup()

    def child(self,command,trace=None,env=None):
        if trace:
            command=[CONFIG.strace,"-y","-o",str(self.evidence/trace),"-e",
                     "trace=openat,openat2,close,statx,read,pread64,write,mmap,munmap,ioctl",*command]
        command=list(map(str,command))
        r=subprocess.run(command,capture_output=True,text=True,timeout=20,
                         stdin=subprocess.DEVNULL,check=False,env=env)
        self.records.append({"arguments":command,"returncode":r.returncode,"stdout":r.stdout,"stderr":r.stderr})
        return r

    def source(self,specs,config=None,total=True):
        type(self).cases+=1
        root=self.base/f"model-{self.cases}";root.mkdir()
        expected={};weight_map={};payload=0
        for label,tensors,metadata in specs:
            raw,want,_=fixture(tensors,metadata)
            path=root/label;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
            expected[label]=(raw,want,metadata)
            for name in want:weight_map[name]=label
            payload+=len(raw)-8-struct.unpack("<Q",raw[:8])[0]
        index={"metadata":{"total_size":payload},"weight_map":weight_map,"future":{"value":[1,2]}}
        if not total:index.pop("metadata")
        if config is None:config={"model_type":"future","tie_word_embeddings":True,"no_rope_layers":[1,0],"future":{"bias":False}}
        (root/"index.json").write_text(json.dumps(index,ensure_ascii=False))
        (root/"config.json").write_text(json.dumps(config,ensure_ascii=False))
        return root,expected,index,config

    def invoke(self,root,policies=None,index="index.json",config="config.json",trace=None,env=None):
        flat=[n for group in policies or DEFAULT for n in group]
        return self.child([self.binary,root,index,config,*flat],trace,env)

    def accept(self,r):
        self.assertEqual(r.returncode,0,r.stdout+r.stderr)
        value=json.loads(r.stdout)
        self.assertIs(value["index_tensor_binding_verified"],True)
        for flag in ("tensor_values_loaded","semantic_adapter_verified","source_fingerprint_verified","hardware_fit_verified","execution_tested"):
            self.assertIs(value[flag],False)
        return value

    def refuse(self,r):
        self.assertNotEqual(r.returncode,0,r.stdout)
        self.assertEqual(r.stdout,"")

    def check(self,specs,config=None,total=True,ownership=False,trace=None):
        root,expected,index,config=self.source(specs,config,total)
        snapshots={p:p.read_bytes() for p in root.rglob("*") if p.is_file()}
        if ownership:
            value=self.accept(self.child([self.api,"ownership",root,"index.json","config.json"],trace))
        else:value=self.accept(self.invoke(root,trace=trace))
        self.assertEqual(value["root_path"],str(root))
        self.assertEqual(value["index"]["weight_map"],index["weight_map"])
        self.assertEqual({k:json.loads(v) for k,v in value["config"]["fields_raw"].items()},config)
        labels=list(dict.fromkeys(index["weight_map"].values()))
        self.assertEqual([x["label"] for x in value["shards"]],labels)
        payload=0;axes=0;count=0
        meta=len(snapshots[root/"index.json"])+len(snapshots[root/"config.json"])
        for shard in value["shards"]:
            label=shard["label"];raw,want,metadata=expected[label]
            storage=shard["storage"]
            old=self.child([self.storage,"safetensors",root/label,*DEFAULT[3][:5]])
            self.assertEqual(old.returncode,0,old.stderr)
            self.assertEqual(storage,json.loads(old.stdout))
            self.assertEqual(storage["metadata"],metadata)
            self.assertEqual(storage["source_bytes"],len(raw))
            meta+=storage["data_offset"]
            byname={t["original_name"]:t for t in storage["tensors"]}
            self.assertEqual(set(byname),set(want))
            for name,descriptor in want.items():
                t=byname[name]
                self.assertEqual(t["source_shape"],descriptor["shape"])
                self.assertEqual(t["source_kind"],descriptor["dtype"])
                self.assertEqual(t["byte_count"],descriptor["bytes"])
                self.assertEqual(t["file_offset"],storage["data_offset"]+descriptor["relative"])
                self.assertEqual(t["source_path"],str(root/label))
                payload+=t["byte_count"];axes+=len(t["source_shape"]);count+=1
        self.assertEqual(value["tensor_count"],count)
        self.assertEqual(value["metadata_bytes"],meta)
        self.assertEqual(value["payload_bytes"],payload)
        self.assertEqual(value["work_units"],meta+len(index["weight_map"])+len(labels)+count+axes)
        for p,raw in snapshots.items():self.assertEqual(p.read_bytes(),raw)
        return root,value

    def test_actual_multishard_names_shapes_and_metadata(self):
        specs=[("sub/a.safetensors",[("embed\0Æ","BF16",[2,3]),("norm","F32",[])],{"shared":"first"}),
               ("b.safetensors",[("empty","F16",[2,0,4]),("proj","F16",[3,1])],{"shared":"second"})]
        self.check(specs,ownership=True,trace="collection.strace")
        self.check([("Æsir.safetensors",[("unicode","BF16",[1])],{"origin":"🜁"})])
        self.check([],config={})
        self.check([("single.safetensors",[("x","F32",[1])],{})],total=False)
        rng=random.Random(101068)
        for i in range(30):
            specs=[]
            for j in range(1+i%4):
                tensors=[]
                for k in range(1+(i+j)%4):
                    shape=[rng.randrange(0,4) for _ in range(rng.randrange(0,5))]
                    tensors.append((f"layer-{j}-{k}",rng.choice(["F16","BF16","F32"]),shape))
                specs.append((f"shard-{j}.safetensors",tensors,{"shared":str(j)}))
            self.check(specs,total=i%2==0)

    def test_exact_aggregate_and_parser_policies(self):
        specs=[("a.safetensors",[("a","F16",[2]),("b","F32",[])],{}),
               ("b.safetensors",[("c","BF16",[1,2])],{})]
        root,value=self.check(specs)
        policy=copy.deepcopy(DEFAULT)
        policy[4]=[2,3,value["metadata_bytes"],value["payload_bytes"],value["work_units"]]
        policy[0][1]=4
        policy[0][2]=len(str(root).encode())+sum(len(label.encode())+1 for label in ("index.json","config.json","a.safetensors","b.safetensors"))
        self.accept(self.invoke(root,policy))
        for j in range(5):
            bad=copy.deepcopy(policy);bad[4][j]-=1
            self.refuse(self.invoke(root,bad))
        for group in range(5):
            for j in range(len(DEFAULT[group])):
                bad=copy.deepcopy(DEFAULT);bad[group][j]=0
                self.refuse(self.invoke(root,bad))
        for group,j in ((1,4),(2,3),(3,4)):
            bad=copy.deepcopy(DEFAULT);bad[group][j]=65
            self.refuse(self.invoke(root,bad))
        bad=copy.deepcopy(policy);bad[0][1]-=1
        self.refuse(self.invoke(root,bad))
        bad=copy.deepcopy(policy);bad[0][2]-=1
        self.refuse(self.invoke(root,bad))
        # An invalid fd policy must refuse even when no shard label exists.
        empty,_,_,_=self.source([],config={})
        bad=copy.deepcopy(DEFAULT);bad[3][0]=0
        self.refuse(self.invoke(empty,bad))

    def test_missing_extra_misdirected_duplicate_and_totals(self):
        specs=[("a.safetensors",[("a","F16",[2]),("b","F32",[])],{}),
               ("b.safetensors",[("c","BF16",[1])],{})]
        for mutation in ("missing","extra","misdirected","missing_file","total","total_negative","bad_config","late_header","escape","absolute","nul","empty_label"):
            root,_,index,_=self.source(specs)
            if mutation=="missing":index["weight_map"]["absent"]="a.safetensors"
            if mutation=="extra":index["weight_map"].pop("b")
            if mutation=="misdirected":index["weight_map"]["a"],index["weight_map"]["c"]="b.safetensors","a.safetensors"
            if mutation=="missing_file":index["weight_map"]["c"]="missing.safetensors"
            if mutation=="total":index["metadata"]["total_size"]+=1
            if mutation=="total_negative":index["metadata"]["total_size"]=-1
            if mutation=="bad_config":(root/"config.json").write_text("{bad}")
            if mutation=="late_header":(root/"b.safetensors").write_bytes(b"bad")
            if mutation=="escape":index["weight_map"]["c"]="../outside.safetensors"
            if mutation=="absolute":index["weight_map"]["c"]=str(root/"b.safetensors")
            if mutation=="nul":index["weight_map"]["c"]="b.safetensors\0tail"
            if mutation=="empty_label":index["weight_map"]["c"]=""
            (root/"index.json").write_text(json.dumps(index))
            self.refuse(self.invoke(root,trace="late-error.strace" if mutation=="late_header" else None))
        specs=[("a.safetensors",[("dup","F16",[1]),("only-a","F16",[1])],{}),
               ("b.safetensors",[("dup","F16",[1]),("only-b","F16",[1])],{})]
        root,_,_,_=self.source(specs);self.refuse(self.invoke(root))
        for kind in ("fifo","directory","symlink"):
            root,_,index,_=self.source([("a.safetensors",[("a","F16",[1])],{})])
            label="special"
            if kind=="fifo":os.mkfifo(root/label)
            elif kind=="directory":(root/label).mkdir()
            else:(root/label).symlink_to("../outside.safetensors")
            index["weight_map"]["a"]=label
            (root/"index.json").write_text(json.dumps(index))
            self.refuse(self.invoke(root))

    def test_metadata_owned_fd_bytes_and_faults(self):
        root,_,_,_=self.source([])
        for size in (0,1,2,8191,8192,8193,20000):
            raw=bytes((j*73)%256 for j in range(size));path=root/"bytes.json";path.write_bytes(raw)
            for mode in ("metadata","metadata_offset"):
                r=self.child([self.api,mode,root,path.name,max(1,size)])
                self.assertEqual(r.returncode,0,r.stderr)
                self.assertEqual(bytes.fromhex(r.stdout.strip()),raw)
            if size>0:
                self.refuse(self.child([self.api,"metadata",root,path.name,size-1]))
        for fd in (-1,2147483648,4294967297):
            self.refuse(self.child([self.api,"invalidmetadatafd",fd,1024]))
        specs=[("a.safetensors",[("a","BF16",[1])],{})]
        root,_,_,_=self.source(specs,config={"large":"x"*9000})
        for mode in ("short","read","eintr","eof","header_eof","body","extra_count","extra","statx","mask","type","changed","size","close"):
            env=os.environ.copy();env.update(LD_PRELOAD=self.faults,AESIR_FD_FAULT_LABEL="config.json",AESIR_FD_FAULT_MODE=mode)
            r=self.invoke(root,trace=f"metadata-fault-{mode}.strace",env=env)
            if mode=="short":self.accept(r)
            else:self.refuse(r)
            lines=(self.evidence/f"metadata-fault-{mode}.strace").read_text().splitlines()
            self.assertEqual(sum("close(" in line and f"<{root/'config.json'}>" in line for line in lines),1)

    def test_traced_admission_header_reads_and_late_cleanup(self):
        root,_,index,_=self.source([("a.safetensors",[("a","F32",[2])],{}),
                                  ("b.safetensors",[("b","BF16",[1])],{})])
        self.accept(self.invoke(root,trace="exact-files.strace"))
        text=(self.evidence/"exact-files.strace").read_text()
        for label in ("index.json","config.json","a.safetensors","b.safetensors"):
            path=root/label
            self.assertEqual(sum("openat2(" in line and f"\"{label}\"" in line for line in text.splitlines()),1)
            self.assertEqual(sum("close(" in line and f"<{path}>" in line for line in text.splitlines()),1)
            self.assertFalse(any("mmap(" in line and f"<{path}>" in line for line in text.splitlines()))
            if label.endswith(".safetensors"):
                raw=path.read_bytes();base=8+struct.unpack("<Q",raw[:8])[0]
                n=0
                for line in text.splitlines():
                    if "pread64(" in line and f"<{path}>" in line:
                        m=re.search(r", (\d+), (\d+)\)\s+=\s+(\d+)",line);self.assertIsNotNone(m,line)
                        _,offset,count=map(int,m.groups());self.assertLessEqual(offset+count,base);n+=count
                self.assertEqual(n,base)
        self.assertNotIn("ioctl(",text)
        invalid=copy.deepcopy(index);invalid["weight_map"]["missing"]="b.safetensors"
        (root/"invalid.index.json").write_text(json.dumps(invalid))
        r=self.child([self.api,"cleanup",root,"index.json","config.json"],"cleanup.strace")
        self.assertEqual(r.returncode,0,r.stderr)
        self.assertEqual(json.loads(r.stdout)["cleanup_cycles"],20)
        lines=(self.evidence/"cleanup.strace").read_text().splitlines()
        self.assertEqual(sum("close(" in line and f"<{root}>" in line for line in lines),40)
        for label,count in (("index.json",20),("invalid.index.json",20),("config.json",40),("a.safetensors",40),("b.safetensors",40)):
            self.assertEqual(sum("close(" in line and f"<{root/label}>" in line for line in lines),count)


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    for name in ("binary","api","storage","faults","strace","evidence"):
        parser.add_argument("--"+name,required=True)
    CONFIG,rest=parser.parse_known_args()
    unittest.main(argv=["shard-collection",*rest])
