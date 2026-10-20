#!/usr/bin/env python3
"""Independent struct bytes + pinned C++ public-header object oracle."""
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
LIMITS={0:[65535,3,63],3:[7,15,255],27:[65535,255],
        35:[0xffffffff,1,0xffffffff,255,0xffffffff,255]}


def wire(kind,timestamp,values):
    head=struct.pack('<BI',kind,timestamp)
    if kind==0:
        count,engine,channel=values
        return head+struct.pack('<HB',count,(engine<<6)|channel)
    if kind==3:
        cluster,lcu,network=values
        return head+struct.pack('<BB',(cluster<<4)|lcu,network)
    if kind==27:
        return head+struct.pack('<HB',*values)
    return head+struct.pack('<IBIBIB',*values)


class ContextActions(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary=str(Path(CONFIG.binary).resolve(strict=True))
        cls.oracle=str(Path(CONFIG.oracle).resolve(strict=True))
        cls.ownership=str(Path(CONFIG.ownership).resolve(strict=True))
        cls.evidence=Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True,exist_ok=True)
        cls.records=[]

    @classmethod
    def tearDownClass(cls):
        (cls.evidence/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
        print('Native child scopes: '+str(dict(Counter(r['scope'] for r in cls.records))))

    def run_child(self,command,scope):
        result=subprocess.run(command,capture_output=True,text=True,timeout=10,
                              stdin=subprocess.DEVNULL,check=False)
        self.records.append({'scope':scope,'arguments':command[1:],
            'returncode':result.returncode,'stdout':result.stdout,'stderr':result.stderr})
        return result

    def accepts(self,kind,timestamp,values):
        expected=wire(kind,timestamp,values).hex()
        oracle=self.run_child([self.oracle,*map(str,(kind,timestamp,*values))],'header_oracle')
        self.assertEqual(oracle.returncode,0,oracle.stderr)
        self.assertEqual(oracle.stdout.strip(),expected)
        for mode,args in [('encode',map(str,(kind,timestamp,*values))),('decode',[expected])]:
            result=self.run_child([self.binary,mode,*args],'mojo_'+mode)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertEqual(json.loads(result.stdout),{'kind':kind,'timestamp':timestamp,
                'values':values,'canonical_hex':expected,'device_access':False,'numerical_program':False})

    def refuses(self,*args):
        result=self.run_child([self.binary,*map(str,args)],'mojo_refusal')
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(result.stdout,'')

    def test_pinned_header_sizes_offsets_and_enums(self):
        result=self.run_child([self.oracle,'layout'],'header_layout')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(json.loads(result.stdout),{'header':5,'timestamp_offset':1,
            'fetch':3,'lcu':2,'ccw':3,'write':15,'write_offsets':[0,4,5,9,10,14],
            'kinds':[0,3,27,35],'write_types':[0,1]})

    def test_zero_max_and_asymmetric_values_exact_bytes(self):
        values={0:[0x1234,2,17],3:[5,10,113],27:[0x3456,23],
                35:[0x11223344,1,0x55667788,31,0xaabbccdd,29]}
        for kind,limits in LIMITS.items():
            for timestamp,row in ((0,[0]*len(limits)),(0xffffffff,limits),
                                  (0x89abcdef,values[kind])):
                self.accepts(kind,timestamp,row)

    def test_seeded_independent_object_vectors(self):
        rng=random.Random(83431)
        for kind,limits in LIMITS.items():
            for _ in range(8):
                self.accepts(kind,rng.randrange(1<<32),[rng.randrange(v+1) for v in limits])

    def test_unsigned_width_type_and_field_count_refusals(self):
        for kind,limits in LIMITS.items():
            for field,maximum in enumerate(limits):
                for bad in (-1,maximum+1):
                    row=[0]*len(limits)
                    row[field]=bad
                    self.refuses('encode',kind,0,*row)
            for timestamp in (-1,1<<32):
                self.refuses('encode',kind,timestamp,*([0]*len(limits)))
            self.refuses('encode',kind,0,*([0]*(len(limits)-1)))
            self.refuses('encode',kind,0,*([0]*(len(limits)+1)))
        for kind in (-1,1,24,44,45,256,1<<32):
            self.refuses('encode',kind,0,0,0,0)

    def test_truncation_trailing_and_reserved_fields(self):
        for kind,values in LIMITS.items():
            raw=wire(kind,0xffffffff,values)
            for length in range(len(raw)):
                self.refuses('decode',raw[:length].hex())
            self.refuses('decode',(raw+b'\0').hex())
        raw=bytearray(wire(3,0,[0,0,0])); raw[5]=0x80
        self.refuses('decode',raw.hex())
        raw=bytearray(wire(35,0,[0]*6)); raw[9]=2
        self.refuses('decode',raw.hex())
        for kind in (1,24,44,45,255):
            self.refuses('decode',struct.pack('<BI',kind,0).hex())
        for raw in ('0','xy','f'*41,'00'*21):
            self.refuses('decode',raw)

    def test_direct_owned_snapshots(self):
        result=self.run_child([self.ownership],'ownership')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(result.stdout.strip(),'owned-value-snapshots-pass')

    def test_inspector_no_device_or_runtime_access(self):
        trace=self.evidence/'codec.strace'
        raw=wire(0,0,[5,0,1]).hex()
        result=self.run_child([CONFIG.strace,'-y','-o',str(trace),'-e',
            'trace=openat,close,mmap,munmap,ioctl',self.binary,'decode',raw],'strace_inspector')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        for forbidden in ('/dev/h1x-','libcuda','libhailort'):
            self.assertNotIn(forbidden,trace.read_text())


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for name in ('binary','oracle','ownership','strace','evidence'):
        parser.add_argument('--'+name,required=True)
    CONFIG,remaining=parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
