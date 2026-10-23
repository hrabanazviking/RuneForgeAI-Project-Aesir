#!/usr/bin/env python3
"""Tiny unsigned wire values only; no model, numerical program or device."""
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
FIELDS='kind timestamp index initial_l3_cut initial_l3_offset active_apu active_ia active_sc active_l2 l2_offset_0 l2_offset_1'.split()
WIDTHS=[8,32,8,8,16,32,32,64,64,64,64]
MAXIMUM=[(1<<w)-1 for w in WIDTHS]
KINDS=(1,17)

def row(kind,values=None):
    r=[kind]+(list(values) if values is not None else [0]*10)
    if kind==17:r[3:]=[0]*8
    return r

def wire(r):
    head=struct.pack('<BIB',*r[:3])
    return head+struct.pack('<BHIIQQQQ',*r[3:]) if r[0]==1 else head

class SequencerActions(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary=str(Path(CONFIG.binary).resolve(strict=True))
        cls.oracle=str(Path(CONFIG.oracle).resolve(strict=True))
        cls.ownership=str(Path(CONFIG.ownership).resolve(strict=True))
        cls.evidence=Path(CONFIG.evidence).resolve();cls.evidence.mkdir(parents=True,exist_ok=True)
        cls.records=[]
    @classmethod
    def tearDownClass(cls):
        (cls.evidence/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
        print('Native calls: '+str(dict(Counter(r['scope'] for r in cls.records))))
    def call(self,cmd,scope,trace=False):
        ident=len(self.records);executed=cmd
        if trace:
            traced=self.evidence/f'call-{ident:05d}.strace'
            executed=[CONFIG.strace,'-f','-y','-o',str(traced),'-e',
                      'trace=openat,close,mmap,munmap,connect,ioctl,execve',*cmd]
        p=subprocess.run(executed,capture_output=True,text=True,timeout=15,stdin=subprocess.DEVNULL)
        (self.evidence/f'call-{ident:05d}.stdout').write_text(p.stdout)
        (self.evidence/f'call-{ident:05d}.stderr').write_text(p.stderr)
        self.records.append(dict(scope=scope,arguments=list(map(str,cmd)),returncode=p.returncode,
                                 stdout=p.stdout,stderr=p.stderr,traced=trace))
        if trace:
            text=traced.read_text()
            for bad in ('/dev/h1x-','/dev/hailo','libhailort','libcuda','libtorch','libonnxruntime','connect(','ioctl('):
                self.assertNotIn(bad,text)
            self.assertEqual(text.count('execve('),1,text)
        return p
    def accept(self,r):
        raw=wire(r).hex();expected=dict(zip(FIELDS,r))
        expected.update(canonical_hex=raw,device_access=False,numerical_program=False)
        c=self.call([self.oracle,*map(str,r)],'header_oracle')
        self.assertEqual((c.returncode,c.stdout,c.stderr),(0,raw+'\n',''))
        for mode,args in [('encode',list(map(str,r))),('decode',[raw])]:
            p=self.call([self.binary,mode,*args],'mojo_'+mode,True)
            self.assertEqual(p.returncode,0,p.stdout+p.stderr);self.assertEqual(p.stderr,'')
            self.assertEqual(json.loads(p.stdout),expected)
    def refuse(self,*args):
        p=self.call([self.binary,*map(str,args)],'mojo_refusal',True)
        self.assertNotEqual(p.returncode,0);self.assertEqual(p.stdout,'')
        self.assertNotEqual(p.stderr,'')
    def test_public_header_layout_and_enums(self):
        p=self.call([self.oracle,'layout'],'header_layout')
        self.assertEqual(p.returncode,0,p.stderr);self.assertEqual(p.stderr,'')
        self.assertEqual(json.loads(p.stdout),dict(header=5,timestamp=1,configuration=43,trigger=44,done=1,
            trigger_offsets=[0,1],done_offset=0,configuration_offsets=[0,1,3,7,11,19,27,35],
            kinds=[1,17],timestamp_initializer=0xffffffff))
    def test_zero_maximum_asymmetric_seeded_random(self):
        rng=random.Random(108119)
        for kind in KINDS:
            rows=[row(kind),row(kind,MAXIMUM[1:]),row(kind,[0x89abcdef,0xa5,0x71,0x1234,
                0x55667788,0x99aabbcc,0xffffffffffffffff,0x8000000000000000,
                0x0123456789abcdef,0xfedcba9876543210])]
            rows += [row(kind,[rng.randrange(m+1) for m in MAXIMUM[1:]]) for _ in range(16)]
            for r in rows:self.accept(r)
    def test_every_walking_bit_of_each_unsigned_field(self):
        for kind in KINDS:
            for field in range(1,11 if kind==1 else 3):
                for bit in range(WIDTHS[field]):
                    r=row(kind);r[field]=1<<bit;self.accept(r)
    def test_every_wire_index(self):
        for kind in KINDS:
            for index in range(256):
                r=row(kind);r[1]=0xffffffff;r[2]=index;self.accept(r)
    def test_unsigned64_and_narrow_boundaries(self):
        for field in range(1,11):
            for v in (0,1,127,128,255,256,32767,32768,65535,65536,
                      0x7fffffff,0x80000000,0xffffffff,0x100000000,
                      0x7fffffffffffffff,0x8000000000000000,0xffffffffffffffff):
                if v<=MAXIMUM[field]:
                    r=row(1);r[field]=v;self.accept(r)
    def test_all_unknown_record_ids(self):
        for kind in range(256):
            if kind in KINDS:continue
            for size in (6,49):self.refuse('decode',(bytes([kind])+bytes(size-1)).hex())
        for kind in (0,2,16,18,255,256,0xffffffff,0xffffffffffffffff):
            self.refuse('encode',kind,*([0]*10))
    def test_width_overflow_negative_and_absent_fields(self):
        for kind in KINDS:
            for field in range(11):
                for bad in (-1,MAXIMUM[field]+1):
                    r=row(kind);r[field]=bad;self.refuse('encode',*r)
            for field in range(3,11):
                for value in (1,MAXIMUM[field]):
                    r=row(17);r[field]=value;self.refuse('encode',*r)
    def test_every_truncation_trailing_and_wrong_extent(self):
        for kind in KINDS:
            raw=wire(row(kind,MAXIMUM[1:]))
            for n in range(len(raw)):self.refuse('decode',raw[:n].hex())
            for extra in (b'\0',b'\xff',bytes(49)):self.refuse('decode',(raw+extra).hex())
        self.refuse('decode',('11'+bytes(48).hex()))
        self.refuse('decode','01'+bytes(5).hex())
    def test_malformed_cli_and_bounded_text(self):
        for raw in ('0','xy','z'*98,'00'*50,' '*98):self.refuse('decode',raw)
        for args in ((),('encode',),('decode',),('decode','00','extra'),('encode',*([0]*10)),
                     ('encode',*([0]*12)),('other',)):
            self.refuse(*args)
        for text in ('','+1','-0',' 1','1 ','1x','1.0','0x10','١','18446744073709551616','0'*21):
            r=list(map(str,row(1)));r[7]=text;self.refuse('encode',*r)
        p=self.call([self.binary,'decode',wire(row(1,MAXIMUM[1:])).hex().upper()],
                    'mojo_uppercase',True)
        self.assertEqual(p.returncode,0,p.stderr)
        self.assertEqual(json.loads(p.stdout)['canonical_hex'],wire(row(1,MAXIMUM[1:])).hex())
    def test_owned_values_moves_mutations_and_recovery(self):
        p=self.call([self.ownership],'ownership',True)
        self.assertEqual((p.returncode,p.stdout,p.stderr),
            (0,'owned-sequencer-values-pass;30-refusal-and-fresh-success-cycles\n',''))

if __name__=='__main__':
    ap=argparse.ArgumentParser()
    for name in ('binary','oracle','ownership','strace','evidence'):ap.add_argument('--'+name,required=True)
    CONFIG,remaining=ap.parse_known_args();unittest.main(argv=[sys.argv[0],*remaining])
