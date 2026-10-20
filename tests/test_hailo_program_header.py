#!/usr/bin/env python3
"""Independent synthetic output header/layout checks, no compiled-file input."""
import argparse
from collections import Counter
import json
from pathlib import Path
import random
import struct
import subprocess
import sys
import unittest

CONFIG=argparse.Namespace()
U32=(1<<32)-1
U64=(1<<64)-1
FORMAT=struct.Struct('>IIIQQIQQQ')
MAGIC=0x01484546


def packed(n,w,p,a,residue,proto_hash):
    return FORMAT.pack(MAGIC,3,n,residue,w,p,a,proto_hash,0)


class ProgramHeader(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary=str(Path(CONFIG.binary).resolve(strict=True))
        cls.evidence=Path(CONFIG.evidence).resolve();cls.evidence.mkdir(parents=True,exist_ok=True)
        cls.records=[]

    @classmethod
    def tearDownClass(cls):
        (cls.evidence/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
        print('Native outcomes: '+str(dict(Counter('accepted' if r['returncode']==0 else 'refused' for r in cls.records))))

    def invoke(self,*args,trace=False):
        command=[self.binary,*map(str,args)]
        if trace:command=[CONFIG.strace,'-y','-o',str(self.evidence/'header.strace'),'-e','trace=openat,ioctl,mmap,munmap',*command]
        result=subprocess.run(command,capture_output=True,text=True,timeout=10,stdin=subprocess.DEVNULL)
        self.records.append(dict(arguments=list(map(str,args)),returncode=result.returncode,stdout=result.stdout,stderr=result.stderr))
        return result

    def accepted(self,*args,trace=False):
        result=self.invoke(*args,trace=trace)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        data=json.loads(result.stdout)
        for key in ('payload_integrity_verified','complete_program','execution_tested','device_access'):self.assertIs(data[key],False)
        return data

    def refused(self,*args):
        result=self.invoke(*args)
        self.assertNotEqual(result.returncode,0,args);self.assertEqual(result.stdout,'')
        self.assertTrue(any(s in result.stderr for s in ('BadProgramHeader','BadArgs','BadRpcHex')),result.stderr)

    def check_layout(self,data,values):
        n,w,p,a,residue,proto_hash=values
        self.assertEqual(data['header_hex'],packed(*values).hex())
        for key,value in dict(protobuf_bytes=n,ccw_bytes_with_padding=w,padding_bytes=p,
                              additional_bytes=a,residue_hash=residue,protobuf_hash=proto_hash,
                              protobuf_offset=56,padding_offset=56+n,ccw_offset=56+n+p,
                              ccw_bytes=w-p,additional_offset=56+n+w,total_bytes=56+n+w+a).items():
            self.assertEqual(data[key],value,key)
        self.assertEqual(data['outer_version'],3)

    def roundtrip(self,values):
        n,w,p,a,_,_=values;total=56+n+w+a
        first=self.accepted('encode',*values,total,total)
        second=self.accepted('decode',packed(*values).hex(),total,total)
        self.check_layout(first,values);self.check_layout(second,values)
        self.assertEqual(first,second)

    def test_complete_bytes_seeded_fields_and_all_region_origins(self):
        self.assertEqual(FORMAT.size,56)
        rng=random.Random(76351)
        for _ in range(32):
            w=rng.randrange(1<<48)
            self.roundtrip((rng.randrange(1<<32),w,rng.randrange(min(w,U32)+1),
                            rng.randrange(1<<40),rng.randrange(1<<64),rng.randrange(1<<64)))

    def test_empty_sections_padding_only_and_extreme_integer_values(self):
        for values in ((0,0,0,0,0,0),(0,17,17,0,U64,U64),(1,0,0,0,0,U64),
                       (0,0,0,19,U64,0),(U32,U32,U32,U32,U64,U64),
                       (0,U64-56,U32,0,0,0),(0,0,0,U64-56,0,0),
                       (U32,0,0,U64-56-U32,0,0)):
            self.roundtrip(values)

    def test_exact_host_bound_and_actual_extent_checks(self):
        values=(17,32,7,5,123,456);raw=packed(*values).hex();total=110
        self.check_layout(self.accepted('encode',*values,total,total),values)
        self.check_layout(self.accepted('decode',raw,U64,total),values)
        for bound,actual in ((0,total),(total-1,total),(U64,total-1),(U64,total+1),(U64,0)):
            self.refused('encode',*values,bound,actual)
            self.refused('decode',raw,bound,actual)

    def test_inconsistent_padding_and_unsigned_section_overflow(self):
        for values in ((0,0,1,0,0,0),(0,1,2,0,0,0),
                       (U32,U64,0,0,0,0),(0,U64,0,0,0,0),
                       (0,U64-56,0,1,0,0),(U32,0,0,U64,0,0),
                       (U32,U64-56,0,0,0,0)):
            self.refused('encode',*values,U64,U64)
            self.refused('decode',packed(*values).hex(),U64,U64)

    def test_magic_version_reserved_length_and_hex_refusals(self):
        raw=packed(17,32,7,5,123,456)
        for offset in (0,1,2,3,*range(48,56)):
            mutated=bytearray(raw);mutated[offset]^=1
            self.refused('decode',mutated.hex(),110,110)
        for version in (0,1,2,4,U32):
            self.refused('decode',(raw[:4]+struct.pack('>I',version)+raw[8:]).hex(),110,110)
        for data in (b'',raw[:-1],raw+b'\x00',raw[:12],raw[:4][::-1]+raw[4:]):
            self.refused('decode',data.hex(),110,110)
        for text in ('0','gg'):self.refused('decode',text,110,110)

    def test_cli_unsigned_bounds_and_invalid_modes(self):
        base=['17','32','7','5','123','456','110','110']
        for index in range(8):
            args=base.copy();args[index]='-1';self.refused('encode',*args)
        for index in (0,2):
            args=base.copy();args[index]=str(U32+1);self.refused('encode',*args)
        for index in (1,3,4,5,6,7):
            args=base.copy();args[index]=str(U64+1);self.refused('encode',*args)
        self.refused('unknown')
        self.refused('encode')
        self.refused('decode','00')

    def test_returned_bytes_and_header_are_owned(self):
        data=self.accepted('ownership')
        self.check_layout(data,(17,32,7,5,123,456))

    def test_no_file_or_device_consumer(self):
        self.accepted('encode',17,32,7,5,123,456,110,110,trace=True)
        trace=(self.evidence/'header.strace').read_text()
        for forbidden in ('/dev/h1x-','libhailort','libcuda','libggml','.gguf','.hef','ioctl('):self.assertNotIn(forbidden,trace)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for name in ('binary','strace','evidence'):parser.add_argument('--'+name,required=True)
    CONFIG,remaining=parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
