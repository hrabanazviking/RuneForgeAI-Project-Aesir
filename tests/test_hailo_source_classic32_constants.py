#!/usr/bin/env python3
"""Synthetic GGUF byte/component/graph import tests; no model evaluation."""
import argparse
from collections import Counter
import ctypes
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
MAX=(1<<63)-1

def s(value):
    value=value.encode() if isinstance(value,str) else value
    return struct.pack('<Q',len(value))+value

from test_hailo_source_q8_constants import make, dense_fixture as q8_dense_fixture
KINDS=(2,3,6,7)
SIZES={2:18,3:20,6:22,7:24}

def block(kind,d,m,quants):
    # Independent source byte writer: place each logical quant bit directly.
    assert len(quants)==32
    out=bytearray(SIZES[kind]);struct.pack_into('<H',out,0,d)
    bias=kind in (3,7);high=kind in (6,7)
    if bias:struct.pack_into('<H',out,2,m)
    ho=4 if bias else 2;no=ho+(4 if high else 0)
    center=0 if bias else (16 if high else 8)
    for lane,q in enumerate(quants):
        u=q+center;assert 0<=u<(32 if high else 16)
        out[no+lane%16] |= (u&15) << (4*(lane//16))
        if high:out[ho+lane//8] |= ((u>>4)&1) << (lane%8)
    return bytes(out)

def classic32_fixture(kind=2,columns=64,rows=4,words=None,name='matrix.weight',seed=0):
    assert columns%32==0
    words=words or [0,0x8000,1,0x3c00,0x7c00,0xfc00,0x7e01,0x7d01,0xffff,0x3ff,0x400]
    rng=random.Random(seed);payload=bytearray();expected=[]
    bias=kind in (3,7);center=0 if bias else (16 if kind==6 else 8);levels=32 if kind in (6,7) else 16
    for i in range(columns*rows//32):
        d=words[i%len(words)];m=words[(i*3+1)%len(words)] if bias else 0
        q=[((j+i)%levels if seed==0 else rng.randrange(levels))-center for j in range(32)]
        payload+=block(kind,d,m,q);expected += [[d,m,oracle16(1,d),oracle16(1,m),bias,x] for x in q]
    return (*make([(name,columns,rows,kind,payload)]),expected)

def dense_fixture(kind):
    raw,bindings,origin,_=q8_dense_fixture()
    tensors=[]
    for name,b in bindings.items():
        c,r=b['columns'],b['rows'];k=0 if b['source_kind']==0 else kind
        data=raw[b['file_offset']:b['file_offset']+b['byte_count']] if k==0 else classic32_fixture(k,c,r)[0][classic32_fixture(k,c,r)[2]:]
        tensors.append((name,c,r,k,data))
    # Reuse only independent container header metadata from the synthetic writer.
    from test_hailo_source_q8_constants import dense_fixture as old
    # Metadata values are explicit; no graph/layer or numerical evaluation.
    metadata=[('llama.context_length',10,64),('llama.embedding_length',4,64),('llama.block_count',4,1),('llama.feed_forward_length',4,96),('llama.attention.head_count',10,2),('llama.attention.head_count_kv',10,1),('llama.rope.dimension_count',10,32),('llama.rope.freq_base',6,10000.),('llama.attention.layer_norm_rms_epsilon',6,.00001),('llama.attention.key_length',4,32),('llama.attention.value_length',4,32)]
    return (*make(tensors,'llama',metadata),[])

class SourceClassic32(unittest.TestCase):
    kind=2
    @classmethod
    def setUpClass(cls):
        for n in ('binary','api','tile','tile_api','inventory','semantic'):
            setattr(cls,n,str(Path(getattr(CONFIG,n)).resolve(strict=True)))
        cls.evidence=Path(CONFIG.evidence).resolve();cls.evidence.mkdir(exist_ok=False,parents=True)
        cls.temp=tempfile.TemporaryDirectory(prefix='aesir-classic32-source-');cls.root=Path(cls.temp.name)
        cls.records=[];cls.fixture_ids={};cls.components=0;cls.byte_checks=0
    @classmethod
    def tearDownClass(cls):
        (cls.evidence/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
        (cls.evidence/'fixtures.json').write_text(json.dumps(cls.fixture_ids,indent=2)+'\n')
        (cls.evidence/'summary.json').write_text(json.dumps({'calls':len(cls.records),'outcomes':dict(Counter('accepted' if x['returncode']==0 else 'refused' for x in cls.records)),'component_checks':cls.components,'byte_checks':cls.byte_checks},indent=2)+'\n')
        print('Classic32 native outcomes',dict(Counter('accepted' if x['returncode']==0 else 'refused' for x in cls.records)),'component checks',cls.components,'byte checks',cls.byte_checks)
        cls.temp.cleanup()
    def invoke(self,fixture=None,first=0,count=1,bound=4096,name='matrix.weight',mode=None,trace=False,tool=None,tail=()):
        source=fixture or classic32_fixture(self.kind);raw,bindings,origin,expected=source
        path=self.root/f'source-{len(self.records)}.gguf';path.write_bytes(raw)
        ident=hashlib.sha256(raw).hexdigest();self.fixture_ids[path.name]={'sha256':ident,'bytes':len(raw)}
        if tool:cmd=[getattr(self,tool),str(path),*map(str,tail)]
        elif mode:cmd=[self.api,str(path),mode]
        else:cmd=[self.binary,str(path),name,str(first),str(count),str(bound)]
        if trace:
            trace_path=self.evidence/f'trace-{len(self.records)}.strace'
            cmd=[CONFIG.strace,'-f','-y','-o',str(trace_path),'-e','trace=openat,close,mmap,munmap,connect,ioctl',*cmd]
        p=subprocess.run(cmd,capture_output=True,text=True,timeout=60,stdin=subprocess.DEVNULL)
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),ident)
        self.records.append({'tool':tool or ('api' if mode else 'components'),'mode':mode,'arguments':cmd,'fixture':path.name,'sha256':ident,'returncode':p.returncode,'stdout':p.stdout,'stderr':p.stderr})
        return p,bindings,expected[first:first+count],raw
    def accept(self,result,first=0,name='matrix.weight'):
        p,b,e,_=result;self.assertEqual(p.returncode,0,p.stdout+p.stderr);self.assertEqual(p.stderr,'')
        o=json.loads(p.stdout);self.assertEqual(o['source_kind'],b[name]['source_kind']);self.assertEqual(o['first'],first)
        self.assertEqual(o['binding'],[b[name][k] for k in ('file_offset','columns','rows','source_kind','byte_count')]);self.assertEqual(o['components'],e)
        for k in ('execution_tested','device_access','source_fingerprint_verified','device_weight_format_verified'):self.assertIs(o[k],False)
        type(self).components+=len(e);return o
    def refuse(self,result):
        p=result[0];self.assertNotEqual(p.returncode,0);self.assertEqual(p.stdout,'')
    def test_all_quants_special_words_and_windows(self):
        for kind in KINDS:
            self.kind=kind
            f=classic32_fixture(kind,columns=96,rows=11)
            got=self.accept(self.invoke(f,count=96*11))
            self.assertEqual({x[5] for x in got['components']},set(range(-8,8) if kind==2 else range(-16,16) if kind==6 else range(16) if kind==3 else range(32)))
            for first,count in ((0,1),(1,2),(14,5),(15,2),(30,5),(31,2),(32,32),(61,8),(95,3),(96*11-1,1)):
                self.accept(self.invoke(f,first,count),first)
            for columns,rows in ((32,1),(96,1),(32,9),(96,3)):
                f=classic32_fixture(kind,columns,rows);self.accept(self.invoke(f,count=columns*rows))
    def test_seeded_complete_component_and_high_plane_bits(self):
        for kind in KINDS:
            for seed in (3,17,401):
                f=classic32_fixture(kind,columns=96,rows=13,seed=seed);self.accept(self.invoke(f,count=1248))
            if kind in (6,7):
                for lane in range(32):
                    center=16 if kind==6 else 0
                    quants=[-center]*32;quants[lane]=16-center
                    data=block(kind,0x3c00,0x8000,quants);bias=kind==7;m=0x8000 if bias else 0
                    f=(*make([('matrix.weight',32,1,kind,data)]),[[0x3c00,m,0x3f800000,oracle16(1,m),bias,q] for q in quants])
                    self.accept(self.invoke(f,count=32))
    def test_isolated_static_reference(self):
        library=ctypes.CDLL(str(Path(CONFIG.reference_library).resolve(strict=True)))
        records=[]
        for kind,name in zip(KINDS,('q4_0','q4_1','q5_0','q5_1')):
            f=classic32_fixture(kind,64,8,words=[0x3800,0x3c00,0x4000,0xbc00])
            o=self.accept(self.invoke(f,count=512))
            payload=f[0][f[2]:];src=ctypes.create_string_buffer(payload);dest=(ctypes.c_float*512)()
            fn=getattr(library,'dequantize_row_'+name);fn.argtypes=[ctypes.c_void_p,ctypes.c_void_p,ctypes.c_int64];fn.restype=None
            fn(src,dest,512)
            def half(word):return struct.unpack('<e',struct.pack('<H',word))[0]
            expected=[struct.unpack('<I',struct.pack('<f',half(c[0])*c[5]+(half(c[1]) if c[4] else 0.)))[0] for c in o['components']]
            # For types without bias the public expression is a product only;
            # preserve negative zero in the independent expected calculation.
            if kind in (2,6):expected=[struct.unpack('<I',struct.pack('<f',half(c[0])*c[5]))[0] for c in o['components']]
            actual=list(struct.unpack('<512I',bytes(dest)));self.assertEqual(actual,expected)
            records.append({'kind':kind,'constants':512,'exact_binary32_match':True,'bits_sha256':hashlib.sha256(bytes(dest)).hexdigest()})
        (self.evidence/'static-reference.json').write_text(json.dumps(records,indent=2)+'\n')
    def test_selection_and_bound_refusals(self):
        for first,count,bound in ((-1,1,1),(0,0,1),(0,-1,1),(256,1,1),(255,2,2),(MAX,1,1),(1,MAX,MAX),(0,1,0),(0,1,-1),(0,2,1)):
            self.refuse(self.invoke(first=first,count=count,bound=bound))
        self.refuse(self.invoke(name='missing'))
        self.accept(self.invoke(count=1,bound=1))
    def test_mutable_descriptors_ownership_and_recovery(self):
        modes=('closed','bytes','offset','metadata','data_offset','data_tail','shape','rows','overflow','alignment','kind','bound_zero','bound_negative','bound_short')
        for mode in modes:
            self.refuse(self.invoke(mode=mode,trace=mode in ('closed','offset')))
            self.accept(self.invoke(count=1))
        for mode in ('ownership','recover'):self.accept(self.invoke(mode=mode,trace=True))
    def test_malformed_real_source_headers_and_non_q8_kind(self):
        f=classic32_fixture(self.kind);raw,b,o,e=f
        for data in (raw[:-1],raw[:o-1],raw[:24],b'not-gguf'):
            self.refuse(self.invoke((data,b,o,e),trace=data==raw[:-1]))
        for cols in (0,1,31,33,1048577):
            f=(*make([('matrix.weight',cols,1,self.kind,bytes(SIZES[self.kind]))]),[]);self.refuse(self.invoke(f))
        f=(*make([('matrix.weight',64,1,1,bytes(128))]),[]);self.refuse(self.invoke(f))
    def test_original_source_names_and_owned_binding(self):
        for name in ('matrix-λ-雪.weight','matrix\0tail.weight'):
            f=classic32_fixture(self.kind,name=name)
            if '\0' in name:self.accept(self.invoke(f,mode='nul_name',name=name),name=name)
            else:self.accept(self.invoke(f,count=33,name=name),name=name)
    def test_actual_source_inventory_and_graph_metadata(self):
        f=dense_fixture(self.kind)
        p,b,_,_=self.invoke(f,tool='inventory');self.assertEqual(p.returncode,0,p.stdout+p.stderr)
        o=json.loads(p.stdout);self.assertEqual(o['bindings'],b);self.assertIs(o['executable_program'],False)
        p,b,_,_=self.invoke(f,tool='semantic',tail=(3,0,16),trace=True);self.assertEqual(p.returncode,0,p.stdout+p.stderr)
        o=json.loads(p.stdout);self.assertEqual(o['weights'],b)
        for k in ('execution_tested','executable_program','source_fingerprint_verified','hardware_fit_verified'):self.assertIs(o[k],False)
    def check_tile(self,result):
        p,b,_,raw=result;self.assertEqual(p.returncode,0,p.stdout+p.stderr);o=json.loads(p.stdout)
        binding=b[o['weight']];kind=binding['source_kind'];self.assertIn(kind,KINDS);size=SIZES[kind]
        self.assertEqual(o['binding'],[binding[k] for k in ('file_offset','columns','rows','source_kind','byte_count')])
        r,n,c,k=o['rectangle'];blocks=sorted({x//32 for x in range(c,c+k)});payload=bytearray();spans=[]
        for row in range(r,r+n):
            offset=binding['file_offset']+row*(binding['columns']//32*size)+size*blocks[0]
            covered=32*len(blocks);prefix=c-32*blocks[0];span_size=size*len(blocks)
            spans.append([row,offset,span_size,32*blocks[0],covered,prefix,covered-prefix-k,len(payload)]);payload+=raw[offset:offset+span_size]
        self.assertEqual(o['spans'],spans);self.assertEqual(o['payload'],list(payload))
        for field in ('execution_tested','device_access','source_fingerprint_verified','device_weight_packing_verified'):self.assertIs(o[field],False)
        type(self).byte_checks+=len(payload)
    def test_actual_lazy_matrix_byte_tiles_rows_blocks_and_tails(self):
        f=dense_fixture(self.kind)
        for tc in (1,17,31,32,33,63,64,65):
            count=math.ceil(64/tc)
            for index in sorted({0,min(1,count-1),count-1,21*count,22*count-1,2*22*count-1}):
                self.check_tile(self.invoke(f,tool='tile',tail=(3,0,16,2,2,3,tc,index,1048576,1048576)))
        self.check_tile(self.invoke(f,tool='tile',tail=(3,0,16,2,2,3,17,1,1048576,1048576),trace=True))
    def test_byte_tile_live_guards_ownership_and_byte_bound(self):
        f=dense_fixture(self.kind)
        modes=('closed','live_size','live_data','live_missing','live_offset','live_columns','live_rows','live_kind','live_bytes','schedule_offset','schedule_columns','schedule_kind','schedule_bytes','schedule_shape','schedule_width','negative_bound','zero_bound','short_bound','negative_index','large_index')
        for mode in modes:self.refuse(self.invoke(f,tool='tile_api',tail=(mode,)))
        for mode in ('accept','ownership'):self.check_tile(self.invoke(f,tool='tile_api',tail=(mode,),trace=True))
        for bound in (-1,0,17,35):self.refuse(self.invoke(f,tool='tile',tail=(3,0,16,2,2,3,33,1,1048576,bound)))

    def test_each_format_guards_names_graph_and_tiles(self):
        for kind in KINDS:
            self.kind=kind
            self.test_selection_and_bound_refusals()
            self.test_mutable_descriptors_ownership_and_recovery()
            self.test_malformed_real_source_headers_and_non_q8_kind()
            self.test_original_source_names_and_owned_binding()
            self.test_actual_source_inventory_and_graph_metadata()
            self.test_actual_lazy_matrix_byte_tiles_rows_blocks_and_tails()
            self.test_byte_tile_live_guards_ownership_and_byte_bound()
    def test_shared_geometry_and_new_admission(self):
        known={0:(1,4),1:(1,2),30:(1,2),2:(32,18),3:(32,20),6:(32,22),7:(32,24),8:(32,34),12:(256,144),13:(256,176),14:(256,210)}
        for kind,(elements,bytes_) in known.items():
            for columns in (elements,elements*3,1048576):
                p=subprocess.run([self.api,'geometry',str(kind),str(columns)],capture_output=True,text=True,timeout=30)
                self.records.append({'tool':'geometry','arguments':[self.api,'geometry',str(kind),str(columns)],'returncode':p.returncode,'stdout':p.stdout,'stderr':p.stderr})
                self.assertEqual(p.returncode,0,p.stderr);self.assertEqual(json.loads(p.stdout),[elements,bytes_,columns//elements*bytes_])
        for kind in (-1,4,5,9,99):
            p=subprocess.run([self.api,'geometry',str(kind),'256'],capture_output=True,text=True,timeout=30)
            self.records.append({'tool':'geometry','arguments':[self.api,'geometry',str(kind),'256'],'returncode':p.returncode,'stdout':p.stdout,'stderr':p.stderr});self.assertNotEqual(p.returncode,0)
if __name__=='__main__':
    ap=argparse.ArgumentParser()
    for n in ('binary','api','tile','tile-api','inventory','semantic','reference-library','strace','evidence'):ap.add_argument('--'+n,required=True)
    CONFIG,rest=ap.parse_known_args();unittest.main(argv=[sys.argv[0],*rest])
