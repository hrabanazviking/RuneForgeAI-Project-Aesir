#!/usr/bin/env python3
"""Static source representation oracle, exhaustive 16-bit patterns. No inference."""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import subprocess
import sys
import tempfile
import unittest
from test_hailo_source_inventory import fixture

CONFIG=argparse.Namespace()
MAX=(1<<63)-1


def source_fixture(kind,words,columns=None):
    columns=columns or len(words)
    assert len(words)%columns==0
    raw,bindings,offset=fixture('source_constant_test', [('matrix.weight',columns,len(words)//columns,kind)])
    binding=bindings['matrix.weight']
    payload=struct.pack('<'+('I' if kind==0 else 'H')*len(words),*words)
    assert len(payload)==binding['byte_count']
    raw=raw[:binding['file_offset']]+payload
    return raw,binding


def oracle16(kind,word):
    if kind==1:
        exponent=(word>>10)&31; fraction=word&1023
        if exponent==31 and fraction:
            # Explicit representation payload policy, independently of Python's
            # NaN canonicalization during an actual floating-point conversion.
            return ((word&0x8000)<<16)|0x7f800000|(fraction<<13)
        value=struct.unpack('<e',struct.pack('<H',word))[0]
    else:
        exponent=(word>>7)&255; fraction=word&127
        if exponent==255:
            return ((word&0x8000)<<16)|0x7f800000|(fraction<<16)
        # Value-based arithmetic oracle, not a source bit-shift decoder.
        value=math.ldexp(float(fraction),-133) if exponent==0 else math.ldexp(float(128+fraction),exponent-134)
        if word&0x8000: value=-value
    return struct.unpack('<I',struct.pack('<f',value))[0]


class SourceFloatConstants(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary=str(Path(CONFIG.binary).resolve(strict=True))
        cls.api=str(Path(CONFIG.api_binary).resolve(strict=True))
        cls.temp=tempfile.TemporaryDirectory(prefix='aesir-source-float-')
        cls.root=Path(cls.temp.name)
        cls.evidence=Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True,exist_ok=True)
        cls.records=[]

    @classmethod
    def tearDownClass(cls):
        (cls.evidence/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
        cls.temp.cleanup()
        print('Native child scopes: '+str(dict(Counter(x['scope'].split(':')[0] for x in cls.records))))

    def run_child(self,command,source,scope):
        before=hashlib.sha256(source.read_bytes()).hexdigest()
        result=subprocess.run(command,capture_output=True,text=True,timeout=15,
                              stdin=subprocess.DEVNULL,check=False)
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),before)
        record={'scope':scope,'source_sha256':before,'returncode':result.returncode,
                'stdout_sha256':hashlib.sha256(result.stdout.encode()).hexdigest(),'stderr':result.stderr}
        if result.returncode==0 and scope.startswith('constant_window'):
            data=json.loads(result.stdout)
            record['window']={k:v for k,v in data.items() if k!='bits'}
            record['element_count']=len(data['bits'])
            record['bits_le_sha256']=hashlib.sha256(struct.pack('<'+'I'*len(data['bits']),*data['bits'])).hexdigest()
            record['first_bits']=data['bits'][:4]; record['last_bits']=data['bits'][-4:]
        else: record['stdout']=result.stdout
        self.records.append(record)
        return result

    def invoke(self,generated,first,count,name='matrix.weight',trace=False):
        raw,binding=generated
        source=self.root/f'fixture-{len(self.records)}.gguf'; source.write_bytes(raw)
        command=[self.binary,str(source),name,str(first),str(count)]
        if trace:
            command=[CONFIG.strace,'-y','-o',str(self.evidence/'constants.strace'),
                     '-e','trace=openat,close,mmap,munmap,ioctl',*command]
        return self.run_child(command,source,'constant_window'),binding

    def accepts(self,kind,words,first,count,columns=None,trace=False):
        result,binding=self.invoke(source_fixture(kind,words,columns),first,count,trace=trace)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        actual=json.loads(result.stdout)
        expected=words[first:first+count] if kind==0 else [oracle16(kind,w) for w in words[first:first+count]]
        self.assertEqual(actual['bits'],expected)
        self.assertEqual(actual['binding'],binding)
        self.assertEqual(actual['first'],first)
        self.assertEqual(actual['host_window_limit'],4096)
        self.assertEqual(actual['representation'],'ieee_binary32_bits')
        for flag in ('device_weight_format','source_fingerprint_verified','execution_tested'):
            self.assertIs(actual[flag],False)
        return actual

    def test_all_binary16_and_bfloat16_source_bit_patterns(self):
        words=list(range(65536))
        coverage=[]
        for kind in (1,30):
            for first in range(0,len(words),4096):
                self.accepts(kind,words,first,4096,columns=256)
            exponent_bits,fraction_bits=(5,10) if kind==1 else (8,7)
            top=(1<<exponent_bits)-1
            counts=Counter('nan' if ((w>>fraction_bits)&top)==top and (w&((1<<fraction_bits)-1)) else
                           'infinity' if ((w>>fraction_bits)&top)==top else 'finite' for w in words)
            coverage.append({'source_kind':kind,'patterns':65536,'classification_counts':dict(counts)})
        (self.evidence/'exhaustive-coverage.json').write_text(json.dumps(coverage,indent=2)+'\n')

    def test_binary32_payloads_passthrough_without_float_evaluation(self):
        rng=random.Random(193817)
        words=[0,0x80000000,1,0x007fffff,0x00800000,0x3f800000,0x7f7fffff,
               0x7f800000,0xff800000,0x7fc12345,0x7f812345,0xffc12345]
        words += [rng.randrange(1<<32) for _ in range(244)]
        self.accepts(0,words,0,len(words),columns=16)

    def test_cross_row_tail_and_exact_two_byte_file_end(self):
        words=[0,0x8000,1,0x03ff,0x0400,0x3c00,0x7bff,0x7c00,0x7c01,0xfc00,0x7e01,0xffff]
        for kind in (1,30):
            self.accepts(kind,words,3,7,columns=4)
            self.accepts(kind,words,11,1,columns=4)
        self.accepts(1,[0x3555],0,1)

    def test_window_bounds_missing_tensor_and_unsupported_quantized_conversion(self):
        generated=source_fixture(1,[0x3c00]*12,4)
        for first,count in ((-1,1),(0,0),(0,-1),(12,1),(11,2),(MAX,1),(0,MAX),(0,4097)):
            result,_=self.invoke(generated,first,count)
            self.assertNotEqual(result.returncode,0)
            self.assertEqual(result.stdout,'')
        result,_=self.invoke(generated,0,1,name='missing.weight')
        self.assertNotEqual(result.returncode,0)
        self.assertIn('missing tensor',result.stderr)
        for kind in (12,13,14):
            raw,bindings,_=fixture(tensors=[('matrix.weight',256,1,kind)])
            result,_=self.invoke((raw,bindings['matrix.weight']),0,1)
            self.assertNotEqual(result.returncode,0)
            self.assertIn('packed source conversion unresolved',result.stderr)
        raw,binding=generated
        result,_=self.invoke((raw[:-1],binding),0,1)
        self.assertNotEqual(result.returncode,0)

    def test_native_extent_mapping_bound_refusals_and_owned_window(self):
        source=self.root/'api.gguf'; source.write_bytes(source_fixture(1,[0x3c00]*12,4)[0])
        for mode in ('closed','byte_count','offset','metadata_offset','negative_shape','overflow_shape',
                     'kind','limit','u16_negative','u16_tail','u16_closed'):
            result=self.run_child([self.api,str(source),mode],source,'api_refusal:'+mode)
            self.assertNotEqual(result.returncode,0,mode)
            self.assertEqual(result.stdout,'')
            self.assertTrue(any(s in result.stderr for s in ('SourceFloatConstants:','SemanticPlan:','GGUF')),result.stderr)
        result=self.run_child([self.api,str(source),'ownership'],source,'ownership')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(result.stdout.strip(),'owned-source-constants-pass')

    def test_read_only_no_device_or_inference_runtime(self):
        self.accepts(1,[0x3c00]*12,3,6,columns=4,trace=True)
        trace=(self.evidence/'constants.strace').read_text()
        self.assertIn('O_RDONLY',trace)
        self.assertIn('PROT_READ, MAP_PRIVATE',trace)
        self.assertIn('munmap(',trace)
        for forbidden in ('/dev/h1x-','libcuda','libhailort'):
            self.assertNotIn(forbidden,trace)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for name in ('binary','api-binary','strace','evidence'):
        parser.add_argument('--'+name,required=True)
    CONFIG,remaining=parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
