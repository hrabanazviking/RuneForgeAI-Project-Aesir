#!/usr/bin/env python3
"""Independent static source representation checks, no model evaluation."""
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
from test_hailo_source_float_constants import oracle16

CONFIG=argparse.Namespace()
TYPES={'F16':(0,2),'BF16':(1,2),'F32':(2,4)}


def source(dtype,words,shape=None,name='weight'):
    shape=[len(words)] if shape is None else shape
    assert math.prod(shape)==len(words)
    _,width=TYPES[dtype]
    header=json.dumps({name:dict(dtype=dtype,shape=shape,data_offsets=[0,len(words)*width]),
                       '__metadata__':{'source':'original ordinary file'}},ensure_ascii=False,separators=(',',':')).encode()
    payload=struct.pack('<'+('H' if width==2 else 'I')*len(words),*words)
    return struct.pack('<Q',len(header))+header+payload,8+len(header)


class SafetensorsConstants(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary=str(Path(CONFIG.binary).resolve(strict=True))
        cls.api=str(Path(CONFIG.api).resolve(strict=True))
        cls.evidence=Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True,exist_ok=False)
        cls.temp=tempfile.TemporaryDirectory(prefix='aesir-static-safetensors-')
        cls.root=Path(cls.temp.name)
        cls.records=[]
        cls.word_checks=0

    @classmethod
    def tearDownClass(cls):
        counts=dict(Counter('accepted' if r['returncode']==0 else 'refused' for r in cls.records))
        (cls.evidence/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
        (cls.evidence/'summary.json').write_text(json.dumps(dict(outcomes=counts,raw_and_expanded_word_checks=cls.word_checks),indent=2)+'\n')
        cls.temp.cleanup()
        print('Native outcomes:',counts,'raw/expanded word checks:',cls.word_checks)

    def invoke(self,raw,name='weight',first=0,count=1,bound=None,policies=(65536,16,16,4096,16),trace=False):
        path=self.root/('case-'+str(len(self.records))+'.safetensors');path.write_bytes(raw)
        command=[self.binary,str(path),name.encode().hex(),str(first),str(count),str(max(1,count) if bound is None else bound),*map(str,policies)]
        if trace:
            command=[CONFIG.strace,'-y','-o',str(self.evidence/(trace+'.strace' if isinstance(trace,str) else 'constants.strace')),
                     '-e','trace=openat,close,mmap,munmap,ioctl',*command]
        result=subprocess.run(command,capture_output=True,text=True,timeout=20,stdin=subprocess.DEVNULL)
        self.assertEqual(path.read_bytes(),raw)
        record=dict(source_sha256=hashlib.sha256(raw).hexdigest(),first=first,count=count,
                    bound=bound,policies=policies,returncode=result.returncode,stderr=result.stderr,
                    stdout_sha256=hashlib.sha256(result.stdout.encode()).hexdigest())
        if result.returncode==0:
            obj=json.loads(result.stdout)
            record['window']={k:v for k,v in obj.items() if k not in ('raw_words','binary32_words')}
            for key in ('raw_words','binary32_words'):
                values=obj[key]
                record[key+'_sha256']=hashlib.sha256(struct.pack('<'+'I'*len(values),*values)).hexdigest()
                record[key+'_edges']=[values[:4],values[-4:]]
        else: record['stdout']=result.stdout
        self.records.append(record)
        return result

    def accepted(self,result):
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        obj=json.loads(result.stdout)
        for key in ('device_access','model_evaluated','execution_tested'):self.assertIs(obj[key],False)
        return obj

    def refused(self,result):
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(result.stdout,'')
        self.assertTrue(any(x in result.stderr for x in ('SafetensorsConstants:','safetensors:','BadArgs','BadRpcHex','utf-8','UTF-8')),result.stderr)

    def check(self,dtype,words,shape=None,name='weight',first=0,count=None,trace=False):
        raw,base=source(dtype,words,shape,name)
        shape=[len(words)] if shape is None else shape
        count=len(words)-first if count is None else count
        obj=self.accepted(self.invoke(raw,name,first,count,trace=trace))
        code,width=TYPES[dtype]
        window=words[first:first+count]
        if dtype=='F16': expanded=[oracle16(1,w) for w in window]
        elif dtype=='BF16': expanded=[oracle16(30,w) for w in window]
        else: expanded=window
        self.assertEqual(obj['raw_words'],window)
        self.assertEqual(obj['binary32_words'],expanded)
        for key,want in dict(dtype=code,name_utf8_hex=name.encode().hex(),shape=shape,
                             source_bytes=len(raw),data_offset=base,elements=len(words),
                             file_offset=base,byte_count=len(words)*width,first=first,count=count).items():
            self.assertEqual(obj[key],want,key)
        type(self).word_checks+=count*2

    def test_exhaustive_f16_and_bf16_source_patterns(self):
        for dtype in ('F16','BF16'):
            self.check(dtype,list(range(65536)),shape=[256,256])

    def test_f32_special_words_payloads_endianness_and_seeded_bits(self):
        values=[0,0x80000000,0x3f800000,0xbf800000,0x7f800000,0xff800000,
                0x7fc00001,0x7f800001,0xff800001,0xffffffff,1,0x007fffff,0x00800000,
                0x7f7fffff,0x12345678,0x87654321]
        rng=random.Random(28372)
        values += [rng.getrandbits(32) for _ in range(496)]
        self.check('F32',values,shape=[2,4,64])
        for i in (0,1,len(values)-1):self.check('F32',values,first=i,count=1)

    def test_arbitrary_rank_row_major_windows_and_final_element(self):
        rng=random.Random(9314)
        for dtype in TYPES:
            words=[rng.getrandbits(32 if dtype=='F32' else 16) for _ in range(120)]
            for first,count in ((0,120),(3,19),(21,16),(110,10),(119,1),(120,0),(0,0)):
                self.check(dtype,words,[2,3,4,5],first=first,count=count)

    def test_scalar_empty_zero_axis_and_unicode_nul_names(self):
        for dtype in TYPES:
            for name in ('','Þór\0🐦','quotes"\\name'):
                self.check(dtype,[0x8001],[],name)
                self.check(dtype,[],[0,9223372036854775807,9223372036854775807],name)
                self.check(dtype,[0x8001],[],name,first=1,count=0)

    def test_element_window_bounds_and_signed_limits(self):
        raw,_=source('F16',[1,2,3,4],[2,2])
        for first,count,bound in ((-1,1,1),(0,-1,1),(5,0,1),(4,1,1),(3,2,2),
                                  (0,2,1),(0,1,0),(0,0,0),(0,1,-1),
                                  (9223372036854775807,0,1),(0,9223372036854775807,1),
                                  (-9223372036854775808,0,1),(0,-9223372036854775808,1)):
            self.refused(self.invoke(raw,first=first,count=count,bound=bound))
        self.refused(self.invoke(raw,name='absent'))
        for i in range(5):
            bounds=[65536,16,16,4096,16];bounds[i]=0
            self.refused(self.invoke(raw,policies=bounds))

    def test_invalid_window_path_wrapper_closes_mapping(self):
        raw,_=source('F16',[1,2,3,4],[2,2])
        self.refused(self.invoke(raw,count=2,bound=1,trace='refused-window'))
        trace=(self.evidence/'refused-window.strace').read_text()
        source_lines=[line for line in trace.splitlines() if '.safetensors>' in line or '.safetensors"' in line]
        opens=[line for line in source_lines if 'openat(' in line]
        closes=[line for line in source_lines if 'close(' in line]
        self.assertEqual(len(opens),1)
        self.assertEqual(len(closes),1)
        self.assertTrue(closes[0].rstrip().endswith('= 0'))
        self.assertIn('munmap(',trace)

    def test_last_two_bytes_read_without_eight_byte_overread(self):
        for dtype in ('F16','BF16'):
            self.check(dtype,[0x0001])
            self.check(dtype,[1,0xffff,0x8000],first=2,count=1)

    def test_live_owner_binding_and_snapshot_api(self):
        raw,_=source('F16',[1,2,3,4],[2,2])
        path=self.root/'api-owner.safetensors';path.write_bytes(raw)
        for case in range(18):
            result=subprocess.run([self.api,str(path),str(case)],capture_output=True,text=True,timeout=10)
            self.records.append(dict(mode='api',case=case,returncode=result.returncode,stdout=result.stdout,stderr=result.stderr))
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            obj=json.loads(result.stdout)
            self.assertTrue(obj['owned_after_close'] if case==0 else obj['refused'])

    def test_read_only_payload_trace_no_runtime_or_device(self):
        self.check('F32',[0x7f800001,0x80000000,0xffffffff,1],[2,2],trace=True)
        trace=(self.evidence/'constants.strace').read_text()
        for forbidden in ('h1x-','ioctl(','libhailort','libcuda','libggml','libtorch','_safetensors_rust'):
            self.assertNotIn(forbidden,trace)
        source_lines=[line for line in trace.splitlines() if '.safetensors>' in line or '.safetensors"' in line]
        opens=[line for line in source_lines if 'openat(' in line]
        closes=[line for line in source_lines if 'close(' in line]
        self.assertEqual(len(opens),len(closes))
        self.assertTrue(any('O_RDONLY' in line and 'O_NONBLOCK' in line for line in opens))
        self.assertTrue(any('mmap(' in line and 'PROT_READ,' in line and 'MAP_PRIVATE' in line for line in source_lines))
        linked=subprocess.check_output(['ldd',self.binary],text=True)
        for forbidden in ('torch','safetensors','hailort','cuda','ggml'):self.assertNotIn(forbidden,linked)
        (self.evidence/'native-linked-libraries.txt').write_text(linked)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for name in ('binary','api','strace','evidence'):parser.add_argument('--'+name,required=True)
    CONFIG,remaining=parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
