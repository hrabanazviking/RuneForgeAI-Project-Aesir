#!/usr/bin/env python3
"""Independent tagged container/shape/byte/provenance checks, no model math."""
import argparse
import hashlib
import itertools
import json
import math
from pathlib import Path
import random
import struct
import subprocess
import sys
import tempfile
import unittest

import test_hailo_gguf_shapes as gguf_fixtures
import test_hailo_safetensors_inventory as safe_fixtures

CONFIG=argparse.Namespace()
MAX=(1<<63)-1


class SourceStorage(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary=str(Path(CONFIG.binary).resolve(strict=True))
        cls.api=str(Path(CONFIG.api).resolve(strict=True))
        cls.gguf_inventory=str(Path(CONFIG.gguf_inventory).resolve(strict=True))
        cls.safe_inventory=str(Path(CONFIG.safe_inventory).resolve(strict=True))
        cls.temp=tempfile.TemporaryDirectory(prefix="aesir-tagged-storage-")
        cls.root=Path(cls.temp.name)
        cls.evidence=Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True,exist_ok=True)
        cls.records=[]

    @classmethod
    def tearDownClass(cls):
        (cls.evidence/"runs.json").write_text(json.dumps(cls.records,indent=2)+"\n")
        cls.temp.cleanup()

    def child(self,command,raw=None,trace=None):
        if trace:
            command=[CONFIG.strace,"-y","-o",str(self.evidence/trace),"-e",
                     "trace=openat,close,mmap,munmap,ioctl,write",*command]
        result=subprocess.run(list(map(str,command)),capture_output=True,text=True,
                              timeout=20,stdin=subprocess.DEVNULL,check=False)
        self.records.append({"arguments":list(map(str,command)),
            "source_sha256":hashlib.sha256(raw).hexdigest() if raw is not None else None,
            "returncode":result.returncode,"stdout":result.stdout,"stderr":result.stderr})
        return result

    def accepts(self,result):
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        return json.loads(result.stdout)

    def refuses(self,result):
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(result.stdout,"")

    def file(self,format,raw):
        path=self.root/f"case-{len(self.records)}.{format}"
        path.write_bytes(raw)
        return path

    def inspect(self,format,raw,bounds=None,trace=None):
        path=self.file(format,raw)
        bounds=bounds or ((1000,64,10000000) if format=="gguf" else (1048576,1000,64,10000000,64))
        result=self.child([self.binary,format,path,*bounds],raw,trace)
        self.assertEqual(path.read_bytes(),raw)
        return result,path

    def check_common(self,report,path,raw,format):
        self.assertEqual(report["source_format"],format)
        self.assertEqual(report["source_path"],str(path))
        self.assertEqual(report["source_bytes"],len(raw))
        for flag in ("execution_tested","source_fingerprint_verified","hardware_fit_verified","tensor_values_loaded"):
            self.assertIs(report[flag],False)
        self.assertNotIn("architecture",report)
        for tensor in report["tensors"]:
            self.assertEqual(tensor["source_format"],format)
            self.assertEqual(tensor["source_path"],str(path))

    def gguf(self,tensors,compare=False):
        raw,shapes=gguf_fixtures.explicit_fixture(tensors)
        result,path=self.inspect("gguf",raw)
        report=self.accepts(result); self.check_common(report,path,raw,"gguf")
        self.assertEqual(report["metadata"],{})
        actual={x["original_name"]:x for x in report["tensors"]}
        self.assertEqual(set(actual),set(shapes))
        for name,shape,kind in tensors:
            value=actual[name]
            self.assertEqual(value["source_shape"],shape)
            self.assertEqual(value["source_kind"],kind)
            self.assertEqual(value["axis_order"],"gguf_fastest_axis_first")
            self.assertEqual(value["elements"],math.prod(shape))
            width=4 if kind==0 else 2
            size=math.prod(shape)*width if kind not in (12,13,14) else math.prod(shape)//256*{12:144,13:176,14:210}[kind]
            self.assertEqual(value["byte_count"],size)
        if compare:
            old=self.accepts(self.child([self.gguf_inventory,path],raw))
            self.assertEqual(report["data_offset"],old["data_offset"])
            for name,binding in old["bindings"].items():
                value=actual[name]
                for field in ("file_offset","source_kind","byte_count"):
                    self.assertEqual(value[field],binding[field])
                self.assertEqual(value["source_shape"][0],binding["columns"])
                self.assertEqual(value["source_shape"][1] if len(value["source_shape"])==2 else 1,binding["rows"])
        return report

    def safe(self,tensors,metadata=None,compare=False,shuffle=False):
        raw,expected,metadata=safe_fixtures.fixture(tensors,metadata,pad=3,shuffle=shuffle)
        result,path=self.inspect("safetensors",raw)
        report=self.accepts(result); self.check_common(report,path,raw,"safetensors")
        self.assertEqual(report["metadata"],metadata)
        data_offset=8+struct.unpack_from("<Q",raw)[0]
        self.assertEqual(report["data_offset"],data_offset)
        actual={x["original_name"]:x for x in report["tensors"]}
        self.assertEqual(set(actual),set(expected))
        for name,binding in expected.items():
            value=actual[name]
            self.assertEqual(value["source_kind"],binding["dtype"])
            self.assertEqual(value["source_shape"],binding["shape"])
            self.assertEqual(value["axis_order"],"row_major_outermost_first")
            self.assertEqual(value["elements"],binding["elements"])
            self.assertEqual(value["file_offset"],data_offset+binding["relative"])
            self.assertEqual(value["byte_count"],binding["bytes"])
        if compare:
            old=self.accepts(self.child([self.safe_inventory,path,1048576,1000,64,10000000,64],raw))
            self.assertEqual(report["source_bytes"],old["source_bytes"])
            for value in old["tensors"]:
                name=bytes.fromhex(value["name_utf8_hex"]).decode()
                new=actual[name]
                self.assertEqual((new["source_kind"],new["source_shape"],new["elements"],new["file_offset"],new["byte_count"]),
                                 (value["dtype"],value["shape"],value["elements"],value["offset"],value["bytes"]))
        return report

    def test_exact_gguf_original_axes_kinds_and_inventory_projection(self):
        for kind in (0,1,12,13,14,30):
            self.gguf([("vector",[256],kind),("one-row",[256,1],kind),
                       ("matrix",[256,3],kind)],compare=True)
        self.gguf([("名字_Æsir\x00tail",[8,1],0),("quote\"\\\n",[1,8],1)],compare=True)

    def test_safetensors_scalars_empties_full_axes_metadata_and_projection(self):
        for dtype in ("F16","BF16","F32"):
            self.safe([("scalar",dtype,[]),("matrix",dtype,[2,3]),("vector",dtype,[6]),
                       ("empty",dtype,[2,0,MAX]),("rank",dtype,[2,1,3,1])],
                      {"origin":"Æsir\x00tail","quoted\"":"line\n"},compare=True,shuffle=True)
        self.safe([],{"only":"metadata"},compare=True)
        self.safe([("scalar_矩阵\x00", "F32", [])],compare=True)

    def test_seeded_source_shape_collections(self):
        rng=random.Random(20261021)
        for _ in range(30):
            tensors=[]
            for i in range(rng.randrange(1,18)):
                shape=[rng.randrange(0,4) for _ in range(rng.randrange(0,8))]
                tensors.append((f"name_{i}",rng.choice(("F16","BF16","F32")),shape))
            self.safe(tensors,shuffle=True)
        for _ in range(20):
            tensors=[]
            for i in range(rng.randrange(1,18)):
                shape=[rng.randrange(1,20)]
                if rng.choice((True,False)): shape.append(rng.randrange(1,5))
                tensors.append((f"name_{i}",shape,rng.choice((0,1,30))))
            rng.shuffle(tensors);self.gguf(tensors)

    def test_tag_selects_actual_dtype_namespace_arithmetic(self):
        for kind,shape in itertools.product((0,1,2),([],[0],[0,MAX],[MAX,0,MAX],[2,3,4],[1]*64)):
            value=self.accepts(self.child([self.api,"arithmetic","safetensors",kind,*shape]))
            self.assertEqual(value,{"elements":math.prod(shape),"bytes":math.prod(shape)*(4 if kind==2 else 2)})
        for kind in (0,1,12,13,14,30):
            for shape in ([256],[256,1],[256,3]):
                value=self.accepts(self.child([self.api,"arithmetic","gguf",kind,*shape]))
                size=math.prod(shape)*(4 if kind==0 else 2) if kind not in (12,13,14) else math.prod(shape)//256*{12:144,13:176,14:210}[kind]
                self.assertEqual(value,{"elements":math.prod(shape),"bytes":size})
        for format,kind,shape in (("other",0,[8]),("gguf",2,[256]),("safetensors",30,[8]),
            ("gguf",0,[]),("gguf",0,[0]),("gguf",0,[1,1,1]),("gguf",12,[255]),
            ("safetensors",0,[-1]),("safetensors",2,[MAX,2]),("safetensors",2,[MAX])):
            self.refuses(self.child([self.api,"arithmetic",format,kind,*shape]))

    def test_direct_mutations_ownership_and_namespace_cast_refusals(self):
        fixtures={"gguf":gguf_fixtures.explicit_fixture([("a",[8,2],0),("b",[8,2],0)])[0],
                  "safetensors":safe_fixtures.fixture([("a","F16",[2,8]),("b","F16",[2,8])])[0]}
        modes=("container","path","nul_path","file_extent","data_extent","data_before_header","tensor_bound","rank_bound","work_bound",
               "entry_container","entry_path","dtype","negative_dtype","axis_order","elements","negative_axis","bytes",
               "offset_before","offset_after","offset_overflow","elements_overflow","bytes_negative","duplicate","overlap","interior_empty","cast")
        for format,raw in fixtures.items():
            path=self.file(format,raw)
            owned=self.accepts(self.child([self.api,format,path,"ownership"],raw))
            self.assertTrue(owned["ownership_checked"])
            if format=="gguf":
                closed=self.child([self.api,format,path,"closed"],raw)
                self.refuses(closed)
                self.assertIn("live GGUF source owner required",closed.stderr)
            for mode in modes:
                self.refuses(self.child([self.api,format,path,mode],raw))
            for mode in ("coverage","gap"):
                result=self.child([self.api,format,path,mode],raw)
                if format=="gguf":self.accepts(result) # GGUF allows padding/tail bytes.
                else:self.refuses(result)

    def test_bounds_and_error_cleanup(self):
        fixtures={"gguf":gguf_fixtures.explicit_fixture([("a",[8,2],0),("b",[8,2],0)])[0],
                  "safetensors":safe_fixtures.fixture([("a","F16",[2,8]),("b","F16",[2,8])])[0]}
        for format,raw in fixtures.items():
            default=(1000,64,10000000) if format=="gguf" else (1048576,1000,64,10000000,64)
            for i in range(len(default)):
                bounds=list(default);bounds[i]=0
                self.refuses(self.inspect(format,raw,bounds=bounds)[0])
            for field,value in ((0,1),(1,1),(2,1)) if format=="gguf" else ((0,1),(1,1),(2,1),(3,1),(4,65)):
                bounds=list(default);bounds[field]=value
                self.refuses(self.inspect(format,raw,bounds=bounds)[0])
            exact=(2,2,14) if format=="gguf" else (1048576,2,2,16,64)
            self.accepts(self.inspect(format,raw,bounds=exact)[0])
            below=list(exact);below[2 if format=="gguf" else 3]-=1
            self.refuses(self.inspect(format,raw,bounds=below)[0])
            self.accepts(self.inspect(format,raw,trace=format+".strace")[0])
            self.refuses(self.inspect(format,raw,bounds=(1,64,1) if format=="gguf" else (1048576,1,64,1,64),trace=format+"-error.strace")[0])
            for suffix in (".strace","-error.strace"):
                trace=(self.evidence/(format+suffix)).read_text()
                self.assertIn("O_RDONLY",trace)
                self.assertIn("munmap(",trace)
                for forbidden in ("/dev/h1x-","libhailort","libcuda","libggml","ioctl("):
                    self.assertNotIn(forbidden,trace)

    def test_paired_sort_independent_lexicographic_oracle(self):
        cases=[[],[(0,0)],[(0,0),(0,4)],[(0,4),(0,0)],[(MAX,MAX),(0,MAX)],[(5,5)]*5]
        for n in range(2,7):
            pairs=[(i//2,i//2+i%2) for i in range(n)]
            cases.extend(list(itertools.permutations(pairs))[:30])
        rng=random.Random(20261022)
        for _ in range(150):
            pairs=[(start:=rng.randrange(20),start+rng.randrange(5)) for _ in range(rng.randrange(0,50))]
            rng.shuffle(pairs);cases.append(pairs)
        cases.append(list(reversed([(i,i+1) for i in range(2000)])))
        for pairs in cases:
            value=self.accepts(self.child([self.api,"sort",*(v for pair in pairs for v in pair)]))
            ordered=sorted(pairs)
            self.assertEqual(value,{"starts":[a for a,b in ordered],"ends":[b for a,b in ordered]})


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    for name in ("binary","api","gguf-inventory","safe-inventory","strace","evidence"):
        parser.add_argument("--"+name,required=True)
    CONFIG,remaining=parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
