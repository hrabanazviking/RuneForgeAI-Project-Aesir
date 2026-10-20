#!/usr/bin/env python3
"Original JSON/index and real bounded-file oracles; no model execution."
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import random
import socket
import struct
import subprocess
import sys
import tempfile
import unittest

CONFIG=argparse.Namespace()
MAX=(1<<63)-1
DEFAULT=(1048576,10000,20000,10000000,64)


def encode(value):
    return json.dumps(value,ensure_ascii=False,separators=(",",":")).encode()


def traced_path(path):
    return "".join("\\%03o"%b if b>=128 else chr(b) for b in str(path).encode())


def depth(value):
    if isinstance(value,dict): return 1+max(map(depth,value.values()),default=0)
    if isinstance(value,list): return 1+max(map(depth,value),default=0)
    return 1


class SourceIndex(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary=str(Path(CONFIG.binary).resolve(strict=True))
        cls.api=str(Path(CONFIG.api).resolve(strict=True))
        cls.faults=str(Path(CONFIG.faults).resolve(strict=True))
        cls.temp=tempfile.TemporaryDirectory(prefix="aesir-source-index-")
        cls.root=Path(cls.temp.name)
        cls.evidence=Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True,exist_ok=True)
        cls.records=[]

    @classmethod
    def tearDownClass(cls):
        (cls.evidence/"runs.json").write_text(json.dumps(cls.records,indent=2)+"\n")
        counts=dict(Counter("accepted" if r["returncode"]==0 else "refused" for r in cls.records))
        (cls.evidence/"summary.json").write_text(json.dumps(counts,indent=2)+"\n")
        cls.temp.cleanup()
        print("Native outcomes:",counts)

    def child(self,command,raw=None,trace=None,env=None):
        if trace:
            command=[CONFIG.strace,"-y","-o",str(self.evidence/trace),"-e",
                     "trace=openat,close,statx,read,write,ioctl,mmap,munmap",*command]
        result=subprocess.run(list(map(str,command)),capture_output=True,text=True,timeout=15,
                              stdin=subprocess.DEVNULL,check=False,env=env)
        self.records.append({"source_sha256":hashlib.sha256(raw).hexdigest() if raw is not None else None,
            "arguments":list(map(str,command)),"returncode":result.returncode,
            "stdout":result.stdout,"stderr":result.stderr})
        return result

    def source(self,raw):
        path=self.root/f"index-Æsir-{len(self.records)}.json"
        path.write_bytes(raw)
        return path

    def invoke(self,raw,policy=DEFAULT,api=False,ownership=False,trace=None):
        if api:
            command=[self.api,"ownership" if ownership else "bytes",raw.hex(),*policy]
            return self.child(command,raw,trace),None
        path=self.source(raw)
        result=self.child([self.binary,path,*policy],raw,trace)
        self.assertEqual(path.read_bytes(),raw)
        return result,path

    def accept(self,result):
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        return json.loads(result.stdout)

    def refuse(self,result):
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(result.stdout,"")

    def check(self,raw,expected,policy=DEFAULT,ownership=False,trace=None):
        for api in (False,True):
            result,path=self.invoke(raw,policy,api,ownership,trace if not api else None)
            report=self.accept(result)
            self.assertEqual(report["weight_map"],expected["weight_map"])
            self.assertEqual(report["source_path"],"" if api else str(path))
            self.assertEqual(report["source_bytes"],len(raw))
            self.assertEqual(report["metadata_present"],"metadata" in expected)
            self.assertEqual({k:json.loads(v) for k,v in report["metadata_raw"].items()},expected.get("metadata",{}))
            self.assertEqual({k:json.loads(v) for k,v in report["unknown_fields_raw"].items()},
                             {k:v for k,v in expected.items() if k not in ("metadata","weight_map")})
            self.assertEqual(report["declared_total_size"],expected.get("metadata",{}).get("total_size",-1))
            fields=len(expected)+len(expected["weight_map"])+len(expected.get("metadata",{}))
            self.assertEqual(report["schema_fields"],fields)
            self.assertEqual(report["work_units"],4*len(raw)+fields)
            for flag in ("shards_opened","execution_tested","source_fingerprint_verified","hardware_fit_verified"):
                self.assertIs(report[flag],False)
            self.assertNotIn("architecture",report)
            self.assertNotIn("hardware_execution",report)
        return report

    def test_owned_original_names_labels_unknown_values_and_raw_spelling(self):
        cases=[{"weight_map":{}},{"weight_map":{},"metadata":{}},
               {"weight_map":{"tensor":"../../not-opened.safetensors","":"","nul\u0000name":"label\u0000suffix"},
                "metadata":{"total_size":0,"total_parameters":123,"unknown":[True,None,{"Æsir":"🚀"}]},
                "other":{"nested":[1,2.5,"x"]},"__other__":False}]
        for value in cases:self.check(encode(value),value,ownership=True)
        raw=b" { \"weight_map\" : {\"a\":\"s\"}, \"metadata\": {\"total_size\": -0, \"x\": [ 1e2, {\"z\" : \"\\u00e9\"} ] }, \"other\" : { \"a\" : true } } \x0a"
        expected=json.loads(raw)
        report=self.check(raw,expected,ownership=True)
        self.assertEqual(report["metadata_raw"]["total_size"],"-0")
        self.assertEqual(report["metadata_raw"]["x"],"[ 1e2, {\"z\" : \"\\u00e9\"} ]")
        self.assertEqual(report["unknown_fields_raw"]["other"],"{ \"a\" : true }")
        raw=b"{\"weight_map\":{},\"metadata\":{\"huge\":1234567890123456789012345678901234567890}}"
        self.check(raw,json.loads(raw))
        for total in (0,1,MAX):
            value={"metadata":{"total_size":total},"weight_map":{"模型\"\\\n":"分片.safetensors"}}
            self.check(encode(value),value)

    def test_seeded_index_collections_and_member_order(self):
        rng=random.Random(20261020)
        for _ in range(60):
            names={f"weight_{i}_Æsir":"shard-"+str(rng.randrange(4))+".safetensors" for i in range(rng.randrange(0,40))}
            fields=[("weight_map",names),("metadata",{"total_size":rng.randrange(100000),"unknown":{"items":[1,True,None]}}),
                    ("future",["x",{"y":False}])]
            rng.shuffle(fields);value=dict(fields)
            self.check(encode(value),value)

    def test_required_types_duplicate_decoded_keys_and_total_size_refusals(self):
        cases=[b"{}",b"[]",b"null",b"1",b"\"text\"",b"{\"weight_map\":[]}",b"{\"weight_map\":null}",
               b"{\"weight_map\":{\"x\":1}}",b"{\"weight_map\":{\"x\":false}}",b"{\"weight_map\":{\"x\":null}}",
               b"{\"weight_map\":{\"x\":[\"a\"]}}",b"{\"weight_map\":{},\"metadata\":null}",
               b"{\"weight_map\":{},\"metadata\":[]}",b"{\"weight_map\":{},\"weight_map\":{}}",
               b"{\"weight_map\":{\"a\":\"x\",\"\\u0061\":\"y\"}}",
               b"{\"weight_map\":{},\"metadata\":{\"a\":1,\"\\u0061\":2}}",
               b"{\"weight_map\":{},\"future\":{\"a\":1,\"a\":2}}",
               b"{\"weight_map\":{},\"future\":[{\"a\":1,\"a\":2}]}"]
        for raw_value in (b"-1",b"-9223372036854775808",str(MAX+1).encode(),b"true",b"null",b"\"1\"",b"1.0",b"1e0",b"[]",b"{}"):
            cases.append(b"{\"weight_map\":{},\"metadata\":{\"total_size\":"+raw_value+b"}}")
        for raw in cases:
            for api in (False,True):self.refuse(self.invoke(raw,api=api)[0])

    def test_json_utf8_escapes_numbers_trailing_and_every_truncation(self):
        good=encode({"weight_map":{"Æsir\u0000":"shard"},"metadata":{"total_size":12,"x":[True,None]}})
        for cut in range(len(good)):
            for api in (False,True):self.refuse(self.invoke(good[:cut],api=api)[0])
        cases=[good+b"{}",good+b"\x00",b"\xef\xbb\xbf"+good,b"{\"weight_map\":{},}",
            b"{\"weight_map\":{\"x\":\"s\",}}",b"{\"weight_map\":{},\"x\":[1,]}",
            b"{\"weight_map\":{},\"x\":01}",b"{\"weight_map\":{},\"x\":1.}",b"{\"weight_map\":{},\"x\":1e}",
            b"{\"weight_map\":{},\"x\":NaN}",b"{\"weight_map\":{},\"x\":Infinity}",
            b"{\"weight_map\":{},\"x\":tru}",b"{\"weight_map\":{},\"x\":\"\\x12\"}",
            b"{\"weight_map\":{\"\\uD800\":\"s\"}}",b"{\"weight_map\":{\"\\uDC00\":\"s\"}}",
            b"{\"weight_map\":{\"\\uD800\\u0041\":\"s\"}}",b"{\"weight_map\":{\"x\":\"s\x00\"}}"]
        for invalid in (b"\xff",b"\xc0\x80",b"\xe0\x80\x80",b"\xed\xa0\x80",b"\xf4\x90\x80\x80",b"\x80"):
            cases.append(b"{\"weight_map\":{\""+invalid+b"\":\"s\"}}")
            cases.append(b"{\"weight_map\":{},\"future\":\""+invalid+b"\"}")
        for raw in cases:
            for api in (False,True):self.refuse(self.invoke(raw,api=api)[0])
        value={"weight_map":{"max􏿿":"s"},"future":"é😀"}
        self.check(encode(value),value)
        self.check(b"{\"weight_map\":{\"\\uD83D\\uDE00\":\"s\"}}",{"weight_map":{"😀":"s"}})

    def test_exact_policy_limits_and_global_nesting(self):
        value={"weight_map":{"a":"s","b":"t"},"metadata":{"total_size":3,"x":{"a":[1,2]}}}
        raw=encode(value);fields=len(value)+len(value["weight_map"])+len(value["metadata"])
        exact=(len(raw),2,fields,4*len(raw)+fields,depth(value))
        self.check(raw,value,policy=exact)
        for i in range(5):
            below=list(exact);below[i]-=1
            for api in (False,True):self.refuse(self.invoke(raw,policy=below,api=api)[0])
            for invalid in (0,-1):
                below=list(DEFAULT);below[i]=invalid
                self.refuse(self.invoke(raw,policy=below,api=True)[0])
        below=list(DEFAULT);below[-1]=65
        self.refuse(self.invoke(raw,policy=below,api=True)[0])
        for level in (0,1,2,8,20,60):
            nested=1
            for _ in range(level):nested=[nested]
            value={"weight_map":{},"unknown":nested};raw=encode(value)
            exact=(len(raw),1,2,4*len(raw)+2,depth(value))
            self.check(raw,value,policy=exact)
            below=list(exact);below[-1]-=1
            self.refuse(self.invoke(raw,policy=below,api=True)[0])

    def test_real_file_admission_byte_exact_reads_and_special_files(self):
        for size in (0,1,2,8191,8192,8193,16384,20000):
            raw=bytes((i*73)%256 for i in range(size));path=self.source(raw)
            result=self.child([self.api,"filehex",path,max(1,size)],raw)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(bytes.fromhex(result.stdout.strip()),raw)
            if size:self.refuse(self.child([self.api,"filehex",path,size-1],raw))
        good=encode({"weight_map":{"a":"not-opened.safetensors"}})
        path=self.source(good)
        link=self.root/"model-link.json";link.symlink_to(path)
        self.accept(self.child([self.binary,link,*DEFAULT],good))
        valid_prefix=self.source(good+b" "*100)
        self.refuse(self.child([self.binary,valid_prefix,len(good),100,100,100000,64],good+b" "*100))
        sparse=self.root/"oversize.json"
        with sparse.open("wb") as stream:stream.truncate(1048576)
        self.refuse(self.child([self.api,"filehex",sparse,128]))
        fifo=self.root/"fifo";os.mkfifo(fifo)
        directory=self.root/"directory";directory.mkdir()
        sock_path=self.root/"socket"
        sock=socket.socket(socket.AF_UNIX);sock.bind(str(sock_path))
        try:
            for special in (fifo,directory,sock_path,self.root/"missing"):
                self.refuse(self.child([self.binary,special,*DEFAULT]))
        finally:sock.close()

    def test_real_file_faults_short_reads_and_cleanup_trace(self):
        raw=encode({"weight_map":{"a":"not-opened.safetensors"}});path=self.source(raw)
        for mode in ("short","open","statx","mask","type","changed","early_size","read","eintr","eof","extra","close"):
            env=dict(os.environ,AESIR_INDEX_FAULT_PATH=str(path),AESIR_INDEX_FAULT_MODE=mode)
            env["LD_PRELOAD"]=self.faults
            result=self.child([self.binary,path,*DEFAULT],raw,trace="fault-"+mode+".strace",env=env)
            if mode=="short":self.accept(result)
            else:self.refuse(result)
            self.assertEqual(path.read_bytes(),raw)
            trace=(self.evidence/("fault-"+mode+".strace")).read_text()
            source_lines=[x for x in trace.splitlines() if traced_path(path) in x]
            if mode!="open":
                self.assertTrue(any("close(" in x for x in source_lines),mode)
        bad=self.source(b"{\"weight_map\":")
        result=self.child([self.api,"cleanup",path,bad],raw,trace="cleanup.strace")
        self.assertEqual(self.accept(result)["cleanup_cycles"],40)
        trace=(self.evidence/"cleanup.strace").read_text()
        for source in (path,bad):
            lines=[x for x in trace.splitlines() if traced_path(source) in x]
            self.assertEqual(sum("openat(" in x for x in lines),40)
            self.assertEqual(sum("close(" in x for x in lines),40)
        for forbidden in ("/dev/h1x-","libhailort","libcuda","libggml","ioctl("):
            self.assertNotIn(forbidden,trace)
        # Index labels remain strings; only the actual index path is read.
        self.assertFalse(any("not-opened.safetensors" in x for x in trace.splitlines() if "openat(" in x))

    def test_shared_raw_span_checks(self):
        raw=" {\"Æsir\": [1,true]} ".encode()
        for first,end in ((0,len(raw)),(1,len(raw)-1),(0,0),(1,1)):
            result=self.child([self.api,"span",raw.hex(),64,first,end],raw)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(bytes.fromhex(result.stdout.strip()),raw[first:end])
        for first,end in ((-1,1),(0,len(raw)+1),(2,1),(4,len(raw)),(0,4)):
            self.refuse(self.child([self.api,"span",raw.hex(),64,first,end],raw))

    def test_shared_cursor_state_and_raw_depth(self):
        raw=" [1, {\"a\":\"Æsir\"}] ".encode()
        for position,expected in ((0,32),(1,91),(len(raw),0)):
            result=self.child([self.api,"cursor",raw.hex(),64,position,"peek"],raw)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(int(result.stdout),expected)
        for position in (-1,len(raw)+1):
            self.refuse(self.child([self.api,"cursor",raw.hex(),64,position,"peek"],raw))
        result=self.child([self.api,"cursor",raw.hex(),64,0,"raw"],raw)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(bytes.fromhex(result.stdout.strip()),raw.strip())
        for limit in (0,-1,65):
            self.refuse(self.child([self.api,"cursor",raw.hex(),limit,0,"raw"],raw))

    def test_pinned_public_index_metadata_only(self):
        path=Path(CONFIG.public_index).resolve(strict=True);raw=path.read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(),"e3a7254c086c4a78f95ad5864f435d165ffed1ed8998326ce5107b4423c15b76")
        report=self.check(raw,json.loads(raw),ownership=True,trace="public-index.strace")
        self.assertEqual(len(report["weight_map"]),326)
        self.assertEqual(len(set(report["weight_map"].values())),2)
        trace=(self.evidence/"public-index.strace").read_text()
        for label in set(report["weight_map"].values()):
            self.assertFalse(any(label in x for x in trace.splitlines() if "openat(" in x))
        opens=[x for x in trace.splitlines() if str(self.root) in x and "openat(" in x]
        self.assertTrue(all("O_RDONLY" in x and "O_NONBLOCK" in x for x in opens))
        self.assertFalse(any("mmap(" in x for x in trace.splitlines() if str(self.root) in x))
        self.assertLess(trace.index("close(",trace.index(str(self.root))),trace.index("write(1"))


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    for name in ("binary","api","faults","strace","public-index","evidence"):
        parser.add_argument("--"+name,required=True)
    CONFIG,remaining=parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
