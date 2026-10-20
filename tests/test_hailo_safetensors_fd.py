#!/usr/bin/env python3
"""Copied-header and real same-fd metadata oracles; no tensor/model math."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import random
import re
import struct
import subprocess
import tempfile
import unittest
from test_hailo_safetensors_inventory import fixture, raw_file

CONFIG=argparse.Namespace()
BOUNDS=(65536,64,32,16384,32)
FDPOLICY=(*BOUNDS,65544)
ROOTPOLICY=(4095,100,100000,9223372036854775807)


class SafetensorsFd(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for name in ("binary","api","inventory","baseline","faults"):
            setattr(cls,name,str(Path(getattr(CONFIG,name)).resolve(strict=True)))
        cls.temp=tempfile.TemporaryDirectory(prefix="aesir-owned-header-")
        cls.root=Path(cls.temp.name)
        cls.evidence=Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True,exist_ok=True)
        cls.records=[]

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
                     "trace=openat,openat2,close,statx,read,pread64,write,mmap,munmap,ioctl,rename,lseek",*command]
        command=list(map(str,command))
        r=subprocess.run(command,capture_output=True,text=True,timeout=15,
                         stdin=subprocess.DEVNULL,check=False,env=env)
        self.records.append({"arguments":command,"returncode":r.returncode,"stdout":r.stdout,"stderr":r.stderr})
        return r

    def source(self,raw,name=None):
        path=self.root/(name or f"source-{len(self.records)}.safetensors")
        path.write_bytes(raw)
        return path

    def accept(self,result):
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        value=json.loads(result.stdout)
        for flag in ("device_access","tensor_values_loaded","execution_tested"):
            self.assertIs(value[flag],False)
        return value

    def refuse(self,result):
        self.assertNotEqual(result.returncode,0,result.stdout)
        self.assertEqual(result.stdout,"")

    def fd(self,path,policy=FDPOLICY,trace=None,env=None):
        return self.child([self.binary,self.root,path.name,*ROOTPOLICY,*policy],trace,env)

    def decoded(self,raw,policy=BOUNDS,size=None,mode="decode"):
        n=struct.unpack("<Q",raw[:8])[0] if len(raw)>=8 else 0
        return self.child([self.api,mode,raw[:8+n].hex(),len(raw) if size is None else size,*policy])

    def test_complete_frozen_baseline_and_independent_fields(self):
        rng=random.Random(101067)
        collections=[[],[("scalar","BF16",[])],[("vector","F32",[1])],
                     [("Æsir\0🜁","F16",[2,3]),("empty","BF16",[3,0,5])]]
        for i in range(50):
            tensors=[]
            for j in range(1+i%7):
                shape=[rng.randrange(0,4) for _ in range(rng.randrange(0,5))]
                tensors.append((f"layer-{i}-{j}",rng.choice(["F16","BF16","F32"]),shape))
            collections.append(tensors)
        for i,tensors in enumerate(collections):
            raw,want,metadata=fixture(tensors,{"origin":"synthetic\0Æsir"},pad=i%5,shuffle=i%2==0)
            path=self.source(raw)
            old=self.accept(self.child([self.baseline,path,*BOUNDS]))
            current=self.accept(self.child([self.inventory,path,*BOUNDS]))
            actual=self.accept(self.fd(path))
            copied=self.accept(self.decoded(raw,mode="ownership"))
            self.assertEqual(old,current)
            self.assertEqual(old,actual)
            self.assertEqual(old,copied)
            n=struct.unpack("<Q",raw[:8])[0]
            self.assertEqual(actual["data_offset"],n+8)
            self.assertEqual(actual["source_bytes"],len(raw))
            indexed={bytes.fromhex(t["name_utf8_hex"]).decode():t for t in actual["tensors"]}
            self.assertEqual(set(indexed),set(want))
            for name,expected in want.items():
                for key in ("dtype","shape","elements","bytes"):
                    self.assertEqual(indexed[name][key],expected[key])
                self.assertEqual(indexed[name]["offset"],n+8+expected["relative"])
            self.assertEqual(path.read_bytes(),raw)

    def test_prefix_header_extent_and_policy_edges(self):
        raw,_,_=fixture([("x","F16",[2])])
        n=struct.unpack("<Q",raw[:8])[0]
        exact=(n,1,1,4,1)
        self.accept(self.decoded(raw,policy=exact))
        path=self.source(raw)
        self.accept(self.fd(path,policy=(*exact,n+8)))
        for index in (0,1,2,3,4):
            policy=list(exact);policy[index]-=1
            self.refuse(self.decoded(raw,policy=policy))
            self.refuse(self.fd(path,policy=(*policy,n+8)))
        self.refuse(self.fd(path,policy=(*exact,n+7)))
        for index in range(6):
            for value in (0,-1):
                policy=list(FDPOLICY);policy[index]=value
                self.refuse(self.child([self.api,"plain",self.root,path.name,*policy]))
        self.refuse(self.fd(path,policy=(*BOUNDS[:4],65,65544)))
        header=raw[:8+n]
        for cut in range(len(header)):
            self.refuse(self.child([self.api,"decode",header[:cut].hex(),len(raw),*BOUNDS]))
        self.refuse(self.child([self.api,"decode",(header+b"x").hex(),len(raw),*BOUNDS]))
        for size in (-1,0,7,n+7,len(raw)-1,len(raw)+1,9223372036854775807):
            self.refuse(self.decoded(raw,size=size))
        for prefix in (b"",b"1",b"1234567",b"123456789",struct.pack("<Q",0),struct.pack("<Q",1),struct.pack("<Q",2**64-1)):
            self.refuse(self.child([self.api,"length",prefix.hex(),len(raw),65536]))
        r=self.child([self.api,"length",raw[:8].hex(),len(raw),n])
        self.assertEqual(r.returncode,0,r.stderr)
        self.assertEqual(int(r.stdout),n)

    def test_malformed_headers_and_real_special_files(self):
        bad=[b"",b"1234567",struct.pack("<Q",2**64-1),raw_file(b"[]"),raw_file(b"{}x"),
             raw_file(b"{\"x\":{\"dtype\":\"F16\",\"shape\":[1],\"data_offsets\":[0,2]}}"),
             raw_file(b"{\"__metadata__\":{\"a\":\"x\",\"a\":\"y\"}}"),
             raw_file(b"{\"__metadata__\":{\"a\":1}}"),raw_file(b"{\"x\":\"\xff\"}"),
             raw_file(b"{\"x\":{\"dtype\":\"F8\",\"shape\":[],\"data_offsets\":[0,0]}}")]
        for raw in bad:
            path=self.source(raw)
            self.refuse(self.fd(path))
            self.refuse(self.decoded(raw))
        fifo=self.root/"pipe";os.mkfifo(fifo)
        for path in (fifo,self.root):
            self.refuse(self.child([self.api,"direct",path,"unused"]))
        for value in (-1,2147483648,4294967297,9223372036854775807):
            self.refuse(self.child([self.api,"invalidfd",value]))
        r=self.child([self.api,"closeinteger",4294967297,-1],"invalid-close.strace")
        self.assertEqual(r.returncode,0,r.stderr)
        self.assertEqual(r.stdout,"-1\n-1\n")
        self.assertNotIn("close(1",(self.evidence/"invalid-close.strace").read_text())

    def assert_header_only_trace(self,path,base,trace):
        text=(self.evidence/trace).read_text()
        reads=[]
        for line in text.splitlines():
            if f"<{path}>" in line and "pread64(" in line:
                match=re.search(r", (\d+), (\d+)\)\s+=\s+(\d+)",line)
                self.assertIsNotNone(match,line)
                count,offset,result=map(int,match.groups())
                self.assertGreater(result,0)
                self.assertLessEqual(offset+result,base)
                reads.append(result)
            if f"<{path}>" in line:
                self.assertNotIn("mmap(",line)
                self.assertNotIn("read(",line)
        self.assertEqual(sum(reads),base)
        self.assertEqual(sum("close(" in line and f"<{path}>" in line for line in text.splitlines()),1)
        self.assertNotIn("ioctl(",text)
        self.assertNotIn("/dev/h1x",text)

    def test_header_only_reads_offsets_and_path_replacement(self):
        raw,_,_=fixture([("x","BF16",[3])],{"note":"x"*18000})
        path=self.source(raw)
        n=struct.unpack("<Q",raw[:8])[0]
        self.accept(self.fd(path,trace="header-only.strace"))
        self.assert_header_only_trace(path,n+8,"header-only.strace")
        self.assertEqual(path.read_bytes(),raw)
        self.accept(self.child([self.api,"offset",self.root,path.name],"offset.strace"))
        self.assert_header_only_trace(path,n+8,"offset.strace")
        original,_,_=fixture([("original","F32",[1])])
        path=self.source(original,"replace-original.safetensors")
        replacement,_,_=fixture([("replacement","F16",[5])])
        alternate=self.source(replacement,"replace-new.safetensors")
        value=self.accept(self.child([self.api,"replace",self.root,path.name,alternate],"replace.strace"))
        self.assertEqual(bytes.fromhex(value["tensors"][0]["name_utf8_hex"]).decode(),"original")
        self.assertEqual(value["source_bytes"],len(original))
        self.assertEqual(path.read_bytes(),replacement)
        self.assertFalse(alternate.exists())
        header=json.dumps({"large":{"dtype":"F16","shape":[10000000],"data_offsets":[0,20000000]}},separators=(",",":")).encode()
        sparse=self.root/"sparse.safetensors"
        with sparse.open("wb") as stream:
            stream.write(struct.pack("<Q",len(header))+header)
            stream.truncate(8+len(header)+20000000)
        value=self.accept(self.fd(sparse,trace="sparse.strace"))
        self.assertEqual(value["source_bytes"],8+len(header)+20000000)
        self.assert_header_only_trace(sparse,8+len(header),"sparse.strace")

    def test_faults_and_repeated_consumed_fd_cleanup(self):
        raw,_,_=fixture([("x","F16",[1])])
        path=self.source(raw,"fault.safetensors")
        for mode in ("short","read","eintr","eof","header_eof","body","extra_count","statx","mask","type","changed","size","close"):
            env=os.environ.copy()
            env.update(LD_PRELOAD=self.faults,AESIR_FD_FAULT_LABEL=path.name,AESIR_FD_FAULT_MODE=mode)
            r=self.fd(path,trace=f"fault-{mode}.strace",env=env)
            if mode=="short":
                self.accept(r)
                self.assert_header_only_trace(path,8+struct.unpack("<Q",raw[:8])[0],f"fault-{mode}.strace")
            else:self.refuse(r)
            text=(self.evidence/f"fault-{mode}.strace").read_text()
            self.assertEqual(sum("close(" in line and f"<{path}>" in line for line in text.splitlines()),1)
            self.assertEqual(path.read_bytes(),raw)
        valid=self.source(raw,"valid.safetensors")
        invalid=self.source(raw_file(b"{bad}"),"invalid.safetensors")
        r=self.child([self.api,"cleanup",self.root,valid.name],"cleanup.strace")
        self.assertEqual(r.returncode,0,r.stderr)
        self.assertEqual(json.loads(r.stdout)["cleanup_cycles"],40)
        text=(self.evidence/"cleanup.strace").read_text()
        for path in (valid,invalid):
            self.assertEqual(sum("close(" in line and f"<{path}>" in line for line in text.splitlines()),40)


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    for key in ("binary","api","inventory","baseline","faults","strace","evidence"):
        parser.add_argument("--"+key,required=True)
    CONFIG,rest=parser.parse_known_args()
    unittest.main(argv=["safetensors-fd",*rest])
