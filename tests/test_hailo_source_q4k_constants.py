#!/usr/bin/env python3
"""Synthetic static constant representation checks. Never a model forward."""
import argparse
from collections import Counter
import ctypes
import hashlib
import json
from pathlib import Path
import random
import struct
import subprocess
import sys
import tempfile
import unittest
from test_hailo_source_inventory import fixture
from test_hailo_source_float_constants import oracle16

CONFIG=argparse.Namespace()
MAX=(1<<63)-1


def pack_block(scales,minimums,quants,d=0x3800,dmin=0x3400):
    """Fixture writer from integer factors, independent of the reader schema."""
    assert len(scales)==len(minimums)==8 and len(quants)==256
    packed=bytearray(struct.pack('<HH',d,dmin)+bytes(140))
    for group in range(4):
        packed[4+group]=scales[group] | ((scales[group+4]//16)<<6)
        packed[8+group]=minimums[group] | ((minimums[group+4]//16)<<6)
        packed[12+group]=(scales[group+4]%16) | ((minimums[group+4]%16)<<4)
    for pair in range(4):
        for lane in range(32):
            packed[16+pair*32+lane]=quants[pair*64+lane] | (quants[pair*64+32+lane]<<4)
    expected=[dict(d_bits=d,dmin_bits=dmin,d_binary32_bits=oracle16(1,d),
                   dmin_binary32_bits=oracle16(1,dmin),q=q,
                   scale_factor=scales[i//32],min_factor=minimums[i//32])
              for i,q in enumerate(quants)]
    return bytes(packed),expected


def generated(blocks,columns=256):
    assert len(blocks)*256%columns==0
    raw,bindings,_=fixture('static_quantized_constants',[
        ('matrix.weight',columns,len(blocks)*256//columns,12)])
    binding=bindings['matrix.weight']
    payload=b''.join(b[0] for b in blocks)
    return raw[:binding['file_offset']]+payload,binding,[c for b in blocks for c in b[1]]


def round32(value):
    return struct.unpack('<f',struct.pack('<f',value))[0]


def reconstruct(c):
    # Test-only isolated static constant reconstruction with explicit F32 steps.
    d=struct.unpack('<e',struct.pack('<H',c['d_bits']))[0]
    minimum=struct.unpack('<e',struct.pack('<H',c['dmin_bits']))[0]
    value=round32(round32(round32(d*c['scale_factor'])*c['q'])-round32(minimum*c['min_factor']))
    return struct.unpack('<I',struct.pack('<f',value))[0]


def reference(library,payload):
    # Frozen, licensed ggml-base only; no model, graph, backend or context API.
    lib=ctypes.CDLL(str(Path(library).resolve(strict=True)))
    decode=lib.dequantize_row_q4_K
    decode.argtypes=[ctypes.c_void_p,ctypes.POINTER(ctypes.c_float),ctypes.c_int64]
    decode.restype=None
    source=ctypes.create_string_buffer(payload)
    count=len(payload)//144*256
    values=(ctypes.c_float*count)()
    decode(source,values,count)
    return list(struct.unpack('<'+'I'*count,ctypes.string_at(values,4*count)))


class SourceQ4KConstants(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary=str(Path(CONFIG.binary).resolve(strict=True))
        cls.api=str(Path(CONFIG.api_binary).resolve(strict=True))
        cls.temp=tempfile.TemporaryDirectory(prefix='aesir-source-q4k-')
        cls.root=Path(cls.temp.name)
        cls.evidence=Path(CONFIG.evidence).resolve(); cls.evidence.mkdir(parents=True,exist_ok=True)
        cls.records=[]

    @classmethod
    def tearDownClass(cls):
        (cls.evidence/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
        cls.temp.cleanup()
        print('Native child scopes: '+str(dict(Counter(x['scope'] for x in cls.records))))

    def run_child(self,command,source,scope):
        before=hashlib.sha256(source.read_bytes()).hexdigest()
        result=subprocess.run(command,capture_output=True,text=True,timeout=20,stdin=subprocess.DEVNULL)
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),before)
        record=dict(scope=scope,source_sha256=before,returncode=result.returncode,
                    stdout_sha256=hashlib.sha256(result.stdout.encode()).hexdigest(),stderr=result.stderr)
        if scope=='constant_window' and result.returncode==0:
            data=json.loads(result.stdout)
            record['window']={k:v for k,v in data.items() if k!='components'}
            record['count']=len(data['components'])
            record['component_sha256']=hashlib.sha256(json.dumps(data['components'],sort_keys=True).encode()).hexdigest()
            record['first_component']=data['components'][0]; record['last_component']=data['components'][-1]
        else: record['stdout']=result.stdout
        self.records.append(record)
        return result

    def invoke(self,source_data,first,count,name='matrix.weight',trace=False):
        raw,binding,expected=source_data
        source=self.root/f'fixture-{len(self.records)}.gguf'; source.write_bytes(raw)
        command=[self.binary,str(source),name,str(first),str(count)]
        if trace: command=[CONFIG.strace,'-y','-o',str(self.evidence/'constants.strace'),
                           '-e','trace=openat,close,mmap,munmap,ioctl',*command]
        return self.run_child(command,source,'constant_window')

    def accepts(self,source_data,first,count,trace=False):
        result=self.invoke(source_data,first,count,trace=trace)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        data=json.loads(result.stdout)
        self.assertEqual(data['binding'],source_data[1])
        self.assertEqual(data['components'],source_data[2][first:first+count])
        self.assertEqual(data['first'],first)
        self.assertEqual(data['host_window_limit'],4096)
        self.assertEqual(data['representation'],'source_affine_components')
        for key in ('device_weight_format','source_fingerprint_verified','execution_tested'):
            self.assertIs(data[key],False)
        return data['components']

    def test_every_group_parameter_value_and_nibble(self):
        blocks=[]
        for n in range(64):
            blocks.append(pack_block([(n+g*7)%64 for g in range(8)],
                                     [(63-n+g*11)%64 for g in range(8)],
                                     [(i*7+n)%16 for i in range(256)],
                                     d=0x3000+n,dmin=0x3400+n*2))
        source=generated(blocks,columns=512)
        for first in range(0,16384,4096): self.accepts(source,first,4096)
        self.assertEqual({c['q'] for c in source[2]},set(range(16)))
        for group in range(8):
            for field in ('scale_factor','min_factor'):
                self.assertEqual({b[1][group*32][field] for b in blocks},set(range(64)))

    def test_group_block_row_crossings_and_exact_last_byte(self):
        blocks=[pack_block([0,1,15,16,31,32,47,63],[63,47,32,31,16,15,1,0],
                           [(i+b)%16 for i in range(256)],d=0x3c00+b,dmin=0x3800+b)
                for b in range(4)]
        source=generated(blocks,512)
        for first,count in ((0,1),(31,2),(63,2),(127,3),(255,2),(510,5),(1023,1),(0,1024)):
            self.accepts(source,first,count)

    def test_scale_special_bit_patterns_remain_representation_only(self):
        patterns=[0,0x8000,1,0x3ff,0x400,0x7bff,0x7c00,0xfc00,0x7c01,0x7e01,0xffff]
        for i,word in enumerate(patterns):
            source=generated([pack_block([63]*8,[31]*8,[i%16]*256,word,patterns[-1-i])])
            self.accepts(source,255,1)

    def test_host_cap_independent_of_source_extent_and_determinism(self):
        source=generated([pack_block([5]*8,[17]*8,[i%16 for i in range(256)])]*32,512)
        first=self.invoke(source,2048,4096)
        second=self.invoke(source,2048,4096)
        self.assertEqual(first.returncode,0,first.stderr)
        self.assertEqual(second.returncode,0,second.stderr)
        self.assertEqual(first.stdout,second.stdout)
        self.assertEqual(json.loads(first.stdout)['components'],source[2][2048:6144])
        result=self.invoke(source,0,4097)
        self.assertNotEqual(result.returncode,0); self.assertIn('explicit host bound',result.stderr)

    def test_pinned_external_constant_reference(self):
        rng=random.Random(72591)
        blocks=[pack_block([rng.randrange(64) for _ in range(8)],
                           [rng.randrange(64) for _ in range(8)],
                           [rng.randrange(16) for _ in range(256)],
                           d=0x3400+index*17,dmin=0x3000+index*13) for index in range(16)]
        source=generated(blocks,512)
        components=self.accepts(source,0,4096)
        # No decoder reuse: externally compiled frozen reference sees raw bytes.
        actual=reference(CONFIG.reference_library,b''.join(b[0] for b in blocks))
        expected=[reconstruct(c) for c in components]
        self.assertEqual(actual,expected)
        (self.evidence/'external-reference.json').write_text(json.dumps({
            'revision':'a05c9922613c6a2230dbb1d0de679519ecafb4f0',
            'library_sha256':hashlib.sha256(Path(CONFIG.reference_library).read_bytes()).hexdigest(),
            'blocks':16,'constants':4096,'exact_binary32_match':True,
            'bits_sha256':hashlib.sha256(struct.pack('<'+'I'*len(actual),*actual)).hexdigest(),
            'scope':'synthetic static constant dequantization only; no context/graph/model/forward'
        },indent=2)+'\n')

    def test_window_missing_kind_and_truncated_source_refusals(self):
        source=generated([pack_block([1]*8,[2]*8,[3]*256)])
        for first,count in ((-1,1),(0,0),(0,-1),(256,1),(255,2),(MAX,1),(0,MAX),(0,4097)):
            result=self.invoke(source,first,count)
            self.assertNotEqual(result.returncode,0); self.assertEqual(result.stdout,'')
        result=self.invoke(source,0,1,name='missing.weight')
        self.assertNotEqual(result.returncode,0); self.assertIn('missing tensor',result.stderr)
        for kind in (0,1,30,13,14):
            raw,bindings,_=fixture(tensors=[('matrix.weight',256,1,kind)])
            result=self.invoke((raw,bindings['matrix.weight'],[]),0,1)
            self.assertNotEqual(result.returncode,0); self.assertIn('requires Q4_K',result.stderr)
        result=self.invoke((source[0][:-1],source[1],[]),0,1)
        self.assertNotEqual(result.returncode,0); self.assertEqual(result.stdout,'')

    def test_native_extent_mapping_bounds_and_owned_window(self):
        raw,_,_=generated([pack_block([3]*8,[7]*8,[i%16 for i in range(256)])]*2)
        source=self.root/'api.gguf'; source.write_bytes(raw)
        for mode in ('closed','byte_count','offset','metadata_offset','data_offset','data_tail',
                     'negative_shape','overflow_shape','unaligned_columns','kind','limit','negative_limit','narrow_limit'):
            result=self.run_child([self.api,str(source),mode],source,'api_refusal')
            self.assertNotEqual(result.returncode,0,mode); self.assertEqual(result.stdout,'')
            self.assertTrue(any(s in result.stderr for s in ('SourceQ4KConstants:','SemanticPlan:','GGUF')),result.stderr)
        result=self.run_child([self.api,str(source),'ownership'],source,'ownership')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(result.stdout.strip(),'owned-q4k-constants-pass')

    def test_read_only_and_no_device_or_inference_runtime(self):
        self.accepts(generated([pack_block([63]*8,[31]*8,[i%16 for i in range(256)])]),250,6,trace=True)
        trace=(self.evidence/'constants.strace').read_text()
        for required in ('O_RDONLY','PROT_READ, MAP_PRIVATE','munmap('): self.assertIn(required,trace)
        for forbidden in ('/dev/h1x-','libcuda','libhailort','libggml'): self.assertNotIn(forbidden,trace)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for name in ('binary','api-binary','strace','reference-library','evidence'): parser.add_argument('--'+name,required=True)
    CONFIG,remaining=parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
