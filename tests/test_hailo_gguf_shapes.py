#!/usr/bin/env python3
"""Test-owned explicit-rank GGUF directories; static metadata only."""
import argparse
import hashlib
import itertools
import json
from pathlib import Path
import random
import struct
import subprocess
import sys
import tempfile
import unittest

CONFIG=argparse.Namespace()


def text(value):
    raw=value.encode("utf-8")
    return struct.pack("<Q",len(raw))+raw


def explicit_fixture(tensors, rank_override=None):
    metadata=text("general.architecture")+struct.pack("<I",8)+text("unknown_future_arch")
    directory=bytearray(); payload=bytearray(); shapes={}
    for name,shape,kind in tensors:
        offset=(len(payload)+31)//32*32
        payload.extend(bytes(offset-len(payload)))
        rank=len(shape) if rank_override is None else rank_override
        directory+=text(name)+struct.pack("<I",rank)
        directory+=b"".join(struct.pack("<Q",axis) for axis in shape)
        directory+=struct.pack("<IQ",kind,offset)
        columns=shape[0] if shape else 0
        rows=shape[1] if len(shape)>1 else 1
        size=columns*rows*(4 if kind==0 else 2)
        if kind in (12,13,14):
            size=columns//256*{12:144,13:176,14:210}[kind]*rows
        payload.extend(bytes((i*7)%256 for i in range(size)))
        shapes[name]=shape
    prefix=struct.pack("<IIQQ",0x46554747,3,len(tensors),1)+metadata+directory
    return prefix+bytes((-len(prefix))%32)+payload,shapes


class GGUFShapes(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary=str(Path(CONFIG.binary).resolve(strict=True))
        cls.api=str(Path(CONFIG.api).resolve(strict=True))
        cls.temp=tempfile.TemporaryDirectory(prefix="aesir-gguf-shapes-")
        cls.root=Path(cls.temp.name)
        cls.evidence=Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True,exist_ok=True)
        cls.records=[]

    @classmethod
    def tearDownClass(cls):
        (cls.evidence/"runs.json").write_text(json.dumps(cls.records,indent=2)+"\n")
        cls.temp.cleanup()

    def invoke(self,generated,api=None,trace=False):
        raw,expected=generated
        source=self.root/f"fixture-{len(self.records)}.gguf"
        source.write_bytes(raw)
        command=[self.binary,str(source)] if api is None else [self.api,str(source),*api]
        if trace:
            command=[CONFIG.strace,"-y","-o",str(self.evidence/"shapes.strace"),"-e",
                     "trace=openat,close,mmap,munmap,ioctl,write",*command]
        result=subprocess.run(command,capture_output=True,text=True,timeout=15,
                              stdin=subprocess.DEVNULL,check=False)
        self.records.append({"source_sha256":hashlib.sha256(raw).hexdigest(),"api":api,
                             "returncode":result.returncode,"stdout":result.stdout,"stderr":result.stderr})
        self.assertEqual(source.read_bytes(),raw)
        return result,expected

    def accepts(self,generated,trace=False):
        result,expected=self.invoke(generated,trace=trace)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(json.loads(result.stdout),{"execution_tested":False,"shapes":expected})

    def refuses(self,generated,api=None):
        result,_=self.invoke(generated,api)
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(result.stdout,"")

    def test_rank_one_and_rank_two_are_distinct(self):
        for columns in (1,2,8,256):
            tensors=[("vector",[columns],1),("matrix_one_row",[columns,1],1),
                     ("matrix_one_column",[1,columns],1),("matrix",[columns,3],1)]
            self.accepts(explicit_fixture(tensors))

    def test_existing_kind_and_explicit_axes(self):
        for kind,rank in itertools.product((0,1,12,13,14,30),(1,2)):
            shape=[256] if rank==1 else [256,1]
            self.accepts(explicit_fixture([("a",shape,kind)]))

    def test_seeded_shapes_names_and_directory_orders(self):
        rng=random.Random(20261020)
        names=["vector_Æsir", "name\x00suffix", "quote\"\\\n", "矩阵🚀"]
        for _ in range(35):
            tensors=[]
            for i in range(rng.randrange(1,18)):
                shape=[rng.randrange(1,65)]
                if rng.choice((True,False)):
                    shape.append(rng.randrange(1,5))
                tensors.append((names[i%4]+str(i),shape,rng.choice((0,1,30))))
            rng.shuffle(tensors)
            self.accepts(explicit_fixture(tensors))

    def test_owned_copies_and_inconsistent_mutable_metadata(self):
        for shape in ([8],[8,1],[1,8],[8,3]):
            generated=explicit_fixture([("a",shape,1)])
            result,_=self.invoke(generated,api=("a","ownership"))
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertEqual(json.loads(result.stdout),shape)
            for mode in ("missing_shape","missing_tensor","empty","rank","columns","rows","vector_rows","zero_columns"):
                self.refuses(generated,api=("a",mode))
        self.refuses(explicit_fixture([("a",[8],1)]),api=("absent","ownership"))

    def test_malformed_declared_ranks_extents_and_truncation(self):
        for rank in (0,3,4,0xFFFFFFFF):
            self.refuses(explicit_fixture([("a",[8],1)],rank_override=rank))
        for shape in ([0],[0,1],[8,0],[1048577],[8,1048577]):
            self.refuses(explicit_fixture([("a",shape,1)]))
        raw,expected=explicit_fixture([("a",[8,1],1)])
        for cut in (0,4,23,len(raw)-17,len(raw)-1):
            self.refuses((raw[:cut],expected))
        self.refuses(explicit_fixture([("a",[8],1),("a",[8,1],1)]))

    def test_read_only_mapping_closed_before_output(self):
        self.accepts(explicit_fixture([("a",[8],1),("b",[8,1],1)]),trace=True)
        trace=(self.evidence/"shapes.strace").read_text()
        self.assertIn("O_RDONLY",trace)
        self.assertIn("PROT_READ, MAP_PRIVATE",trace)
        self.assertLess(trace.index("munmap(",trace.index("fixture-")),trace.index("write(1"))
        for forbidden in ("/dev/h1x-","libhailort","libcuda","libggml","ioctl("):
            self.assertNotIn(forbidden,trace)


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    for name in ("binary","api","strace","evidence"):
        parser.add_argument("--"+name,required=True)
    CONFIG,remaining=parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
