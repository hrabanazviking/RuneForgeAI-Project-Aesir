#!/usr/bin/env python3
"""Independent tiny scalar/packed-control bytes. No model/numerical evaluation."""
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
KINDS=(4,5,36)
FIELDS=('kind','timestamp','cluster','lcu','network','kernel_done_address','kernel_done_count')
MAX=(36,0xffffffff,7,15,255,65535,0xffffffff)

def wire(row):
    kind,timestamp,cluster,lcu,network,address,count=row
    head=struct.pack('<BIB',kind,timestamp,(cluster<<4)|lcu)
    if kind==5:return head
    if kind==4:return head+struct.pack('<BHI',network,address,count)
    assert kind==36
    return head+struct.pack('<BI',network,count)

def canonical(kind,timestamp=0,cluster=0,lcu=0,network=0,address=0,count=0):
    return [kind,timestamp,cluster,lcu,network if kind!=5 else 0,
            address if kind==4 else 0,count if kind!=5 else 0]

class LcuActions(unittest.TestCase):
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
    def call(self,command,scope):
        p=subprocess.run(command,capture_output=True,text=True,timeout=10,stdin=subprocess.DEVNULL)
        self.records.append({'scope':scope,'arguments':list(map(str,command[1:])),
            'returncode':p.returncode,'stdout':p.stdout,'stderr':p.stderr})
        return p
    def accept(self,row):
        raw=wire(row).hex()
        h=self.call([self.oracle,*map(str,row)],'header_oracle')
        self.assertEqual(h.returncode,0,h.stderr);self.assertEqual(h.stdout,raw+'\n')
        expected=dict(zip(FIELDS,row));expected.update(canonical_hex=raw,device_access=False,numerical_program=False)
        for mode,args in [('encode',list(map(str,row))),('decode',[raw])]:
            p=self.call([self.binary,mode,*args],'mojo_'+mode)
            self.assertEqual(p.returncode,0,p.stdout+p.stderr)
            self.assertEqual(p.stderr,'');self.assertEqual(json.loads(p.stdout),expected)
    def refuse(self,*args):
        p=self.call([self.binary,*map(str,args)],'mojo_refusal')
        self.assertNotEqual(p.returncode,0);self.assertEqual(p.stdout,'')
    def test_public_object_sizes_offsets_enums(self):
        p=self.call([self.oracle,'layout'],'header_layout');self.assertEqual(p.returncode,0,p.stderr)
        self.assertEqual(json.loads(p.stdout),{'header':5,'timestamp':1,'sizes':[8,1,6],
            'enable_offsets':[0,1,2,4],'disable_offsets':[0],'batch_offsets':[0,1,2],
            'kinds':[4,5,36],'masks':[15,112]})
    def test_zero_max_asymmetric_and_random_words(self):
        rng=random.Random(108113)
        for kind in KINDS:
            rows=[canonical(kind),canonical(kind,*MAX[1:]),
                  canonical(kind,0x89abcdef,5,10,113,0x1234,0x55667788)]
            rows += [canonical(kind,*[rng.randrange(m+1) for m in MAX[1:]]) for _ in range(12)]
            for row in rows:self.accept(row)
    def test_all_valid_packed_lcu_identities(self):
        for kind in KINDS:
            for cluster in range(8):
                for lcu in range(16):self.accept(canonical(kind,0x01020304,cluster,lcu,23,4096,17))
    def test_completion_and_timestamp_boundaries(self):
        for kind in KINDS:
            for v in (0,1,255,256,65535,65536,0x7fffffff,0x80000000,0xffffffff):
                self.accept(canonical(kind,v,1,2,255,v&65535,v))
    def test_signed_width_and_absent_field_refusals(self):
        for kind in KINDS:
            for field,maximum in enumerate(MAX[1:],1):
                for bad in (-1,maximum+1):
                    row=canonical(kind);row[field]=bad;self.refuse('encode',*row)
            absent=[4,5,6] if kind==5 else [5] if kind==36 else []
            for field in absent:
                row=canonical(kind);row[field]=1;self.refuse('encode',*row)
        for kind in (-1,0,3,6,16,35,37,255,256,1<<32):
            self.refuse('encode',kind,0,0,0,0,0,0)
    def test_every_truncation_trailing_extent_and_kind(self):
        for kind in KINDS:
            raw=wire(canonical(kind,*MAX[1:]))
            for length in range(len(raw)):self.refuse('decode',raw[:length].hex())
            for extra in (b'\0',b'\xff',b'\0'*13):self.refuse('decode',(raw+extra).hex())
        for kind in (0,3,6,16,35,37,255):self.refuse('decode',struct.pack('<BI',kind,0).hex())
    def test_every_reserved_packed_identity(self):
        for kind in KINDS:
            for packed in range(128,256):
                raw=bytearray(wire(canonical(kind)));raw[5]=packed
                self.refuse('decode',raw.hex())
    def test_malformed_cli_and_unsigned_text(self):
        for raw in ('0','xy','f'*27,'00'*14):self.refuse('decode',raw)
        for args in [(),('encode',),('decode',),('decode','00','extra'),
                     ('encode',4,0,0,0,0,0),('encode',4,0,0,0,0,0,0,0),
                     ('encode',4,'18446744073709551616',0,0,0,0,0),
                     ('encode',4,'1x',0,0,0,0,0)]:self.refuse(*args)
    def test_direct_owned_snapshots_mutations_recovery(self):
        p=self.call([self.ownership],'ownership');self.assertEqual(p.returncode,0,p.stdout+p.stderr)
        self.assertEqual(p.stdout,'owned-lcu-values-pass;18-refusal-and-fresh-success-cycles\n')
    def test_trace_no_device_network_runtime_or_ioctl(self):
        specs=[]
        for kind in KINDS:
            row=canonical(kind,*MAX[1:]);specs += [[self.binary,'encode',*map(str,row)],[self.binary,'decode',wire(row).hex()]]
        specs.append([self.ownership])
        for i,cmd in enumerate(specs):
            trace=self.evidence/f'control-{i}.strace'
            p=self.call([CONFIG.strace,'-f','-y','-o',str(trace),'-e',
                'trace=openat,close,mmap,munmap,connect,ioctl',*cmd],'trace_control')
            self.assertEqual(p.returncode,0,p.stdout+p.stderr)
            text=trace.read_text()
            for bad in ('/dev/h1x-','/dev/hailo','libhailort','libcuda','libtorch','libonnxruntime','connect(','ioctl('):
                self.assertNotIn(bad,text)

if __name__=='__main__':
    ap=argparse.ArgumentParser()
    for n in ('binary','oracle','ownership','strace','evidence'):ap.add_argument('--'+n,required=True)
    CONFIG,rest=ap.parse_known_args();unittest.main(argv=[sys.argv[0],*rest])
