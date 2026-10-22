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

from test_hailo_source_q8_constants import make
KINDS=(10,11)
SIZES={10:84,11:110}

def block(kind,d,dmin,scales,minimums,quants):
    # Independent logical-bit writer for the qualified source fields.
    assert len(quants)==256 and len(scales)==len(minimums)==16
    out=bytearray(SIZES[kind]);present=kind==10
    struct.pack_into('<H',out,80 if present else 108,d)
    if present:struct.pack_into('<H',out,82,dmin)
    for g,scale in enumerate(scales):
        if present:
            assert 0<=scale<16 and 0<=minimums[g]<16
            out[g]=scale+16*minimums[g]
        else:
            encoded=scale+32;assert 0<=encoded<64
            for bit in range(6):
                dest=(96+g%8,4*(g//8)+bit) if bit<4 else (104+g%4,2*(g//4)+bit-4)
                out[dest[0]] |= ((encoded>>bit)&1)<<dest[1]
    for lane,q in enumerate(quants):
        encoded=q if present else q+4;assert 0<=encoded<(4 if present else 8)
        # Each 128-lane half stores four32-lane low-bit planes.
        byte=(16 if present else 32)+(lane//128)*32+lane%32
        for bit in range(2):out[byte] |= ((encoded>>bit)&1)<<(2*((lane%128)//32)+bit)
        if not present:out[lane%32] |= (1 if q>=0 else 0)<<(lane//32)
    return bytes(out)

def components(kind,d,dmin,scales,minimums,q):
    present=kind==10;dmin=dmin if present else 0
    return [[d,dmin,oracle16(1,d),oracle16(1,dmin),present,scales[i//16],minimums[i//16] if present else 0,x] for i,x in enumerate(q)]

def q2q3_fixture(kind=10,columns=512,rows=2,words=None,name='matrix.weight',seed=0):
    assert columns%256==0
    words=words or [0,0x8000,1,0x3c00,0x7c00,0xfc00,0x7e01,0x7d01,0xffff,0x3ff,0x400]
    rng=random.Random(seed);payload=bytearray();expected=[];present=kind==10
    for i in range(columns*rows//256):
        d=words[i%len(words)];dm=words[(i*3+1)%len(words)]
        scales=[(g+i)%16 if present else (g*7+i)%64-32 for g in range(16)]
        mins=[(g*3+i)%16 if present else 0 for g in range(16)]
        q=[((j+i)%4 if present else (j+i)%8-4) if not seed else rng.randrange(4 if present else 8)-(0 if present else 4) for j in range(256)]
        payload+=block(kind,d,dm,scales,mins,q);expected+=components(kind,d,dm,scales,mins,q)
    return (*make([(name,columns,rows,kind,payload)]),expected)

def dense_fixture(kind):
    hidden,ff,heads,kv,key,value,vocab=256,512,2,1,128,128,4
    tensors=[('token_embd.weight',hidden,vocab,kind),('output_norm.weight',hidden,1,0),('output.weight',hidden,vocab,kind)]
    shapes=[('attn_norm',hidden,1),('ffn_norm',hidden,1),('attn_q',hidden,heads*key),('attn_k',hidden,kv*key),('attn_v',hidden,kv*value),('attn_output',heads*value,hidden),('ffn_gate',hidden,ff),('ffn_up',hidden,ff),('ffn_down',ff,hidden)]
    tensors += [(f'blk.0.{name}.weight',c,r,0 if r==1 else kind) for name,c,r in shapes]
    rows=[]
    for name,c,r,k in tensors:
        data=bytes(c*r*4) if k==0 else q2q3_fixture(k,c,r)[0][q2q3_fixture(k,c,r)[2]:]
        rows.append((name,c,r,k,data))
    metadata=[('llama.context_length',10,64),('llama.embedding_length',4,hidden),('llama.block_count',4,1),('llama.feed_forward_length',4,ff),('llama.attention.head_count',10,heads),('llama.attention.head_count_kv',10,kv),('llama.rope.dimension_count',10,key),('llama.rope.freq_base',6,10000.),('llama.attention.layer_norm_rms_epsilon',6,.00001),('llama.attention.key_length',4,key),('llama.attention.value_length',4,value)]
    return (*make(rows,'llama',metadata),[])

class SourceQ2Q3(unittest.TestCase):
    kind=10
    @classmethod
    def setUpClass(cls):
        for n in ('binary','api','tile','tile_api','inventory','semantic'):
            setattr(cls,n,str(Path(getattr(CONFIG,n)).resolve(strict=True)))
        cls.evidence=Path(CONFIG.evidence).resolve();cls.evidence.mkdir(exist_ok=False,parents=True)
        cls.temp=tempfile.TemporaryDirectory(prefix='aesir-q2q3-source-');cls.root=Path(cls.temp.name)
        cls.records=[];cls.fixture_ids={};cls.components=0;cls.byte_checks=0
    @classmethod
    def tearDownClass(cls):
        (cls.evidence/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
        (cls.evidence/'fixtures.json').write_text(json.dumps(cls.fixture_ids,indent=2)+'\n')
        (cls.evidence/'summary.json').write_text(json.dumps({'calls':len(cls.records),'outcomes':dict(Counter('accepted' if x['returncode']==0 else 'refused' for x in cls.records)),'component_checks':cls.components,'byte_checks':cls.byte_checks},indent=2)+'\n')
        print('Q2Q3 native outcomes',dict(Counter('accepted' if x['returncode']==0 else 'refused' for x in cls.records)),'component checks',cls.components,'byte checks',cls.byte_checks)
        cls.temp.cleanup()
    def invoke(self,fixture=None,first=0,count=1,bound=4096,name='matrix.weight',mode=None,trace=False,tool=None,tail=()):
        source=fixture or q2q3_fixture(self.kind);raw,bindings,origin,expected=source
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
    def test_special_words_and_boundary_windows(self):
        for kind in KINDS:
            self.kind=kind
            f=q2q3_fixture(kind,columns=768,rows=11)
            self.accept(self.invoke(f,count=768*11,bound=768*11))
            for first,count in ((0,1),(1,2),(14,5),(15,2),(30,5),(31,2),(126,5),(127,2),(254,5),(255,2),(256,256),(511,5),(767,3),(768*11-1,1)):
                self.accept(self.invoke(f,first,count),first)
            for c,r in ((256,1),(768,1),(256,9),(768,3)):
                f=q2q3_fixture(kind,c,r);self.accept(self.invoke(f,count=c*r))
    def test_every_quant_scale_minimum_bit_and_group(self):
        for kind in KINDS:
            payload=bytearray();expected=[];present=kind==10
            cases=[]
            # Toggle every logical low/high bit separately; all256 fields checked.
            for lane in range(256):
                for bit in range(2 if present else 3):
                    q=[0 if present else -4]*256;q[lane]+=(1<<bit)
                    cases.append(([1]*16,[0]*16,q))
            for group in range(16):
                for bit in range(4 if present else 6):
                    scales=[0 if present else -32]*16;scales[group]+=(1<<bit)
                    cases.append((scales,[0]*16,[1]*256))
                if present:
                    for bit in range(4):
                        mins=[0]*16;mins[group]=1<<bit
                        cases.append(([1]*16,mins,[0]*256))
            for scales,mins,q in cases:
                payload+=block(kind,0x3c00,0x3800,scales,mins,q)
                expected+=components(kind,0x3c00,0x3800,scales,mins,q)
            f=(*make([('matrix.weight',256,len(cases),kind,payload)]),expected)
            self.accept(self.invoke(f,count=len(expected),bound=len(expected)))
    def test_seeded_complete_components(self):
        for kind in KINDS:
            for seed in (3,17,401):
                f=q2q3_fixture(kind,768,5,seed=seed);self.accept(self.invoke(f,count=3840))
    def test_isolated_static_reference(self):
        library=ctypes.CDLL(str(Path(CONFIG.reference_library).resolve(strict=True)));records=[]
        for kind,name in ((10,'q2_K'),(11,'q3_K')):
            f=q2q3_fixture(kind,512,2,words=[0x3800,0x3c00,0x4000,0xbc00])
            o=self.accept(self.invoke(f,count=1024));payload=f[0][f[2]:]
            src=ctypes.create_string_buffer(payload);dest=(ctypes.c_float*1024)()
            fn=getattr(library,'dequantize_row_'+name);fn.argtypes=[ctypes.c_void_p,ctypes.c_void_p,ctypes.c_int64];fn.restype=None
            fn(src,dest,1024)
            half=lambda w:struct.unpack('<e',struct.pack('<H',w))[0]
            expected=[half(c[0])*c[5]*c[7]-(half(c[1])*c[6] if c[4] else 0.) for c in o['components']]
            # This isolated static oracle compares full finite constant values.
            self.assertEqual(list(dest),expected)
            records.append({'gguf_source_kind':kind,'constants':1024,'complete_value_match':True,'bits_sha256':hashlib.sha256(bytes(dest)).hexdigest()})
        (self.evidence/'static-reference.json').write_text(json.dumps(records,indent=2)+'\n')
    def test_selection_and_bound_refusals(self):
        for first,count,bound in ((-1,1,1),(0,0,1),(0,-1,1),(1024,1,1),(1023,2,2),(MAX,1,1),(1,MAX,MAX),(0,1,0),(0,1,-1),(0,2,1)):
            self.refuse(self.invoke(first=first,count=count,bound=bound))
        self.refuse(self.invoke(name='missing'))
        self.accept(self.invoke(count=1,bound=1))
    def test_mutable_descriptors_ownership_and_recovery(self):
        modes=('closed','bytes','offset','metadata','data_offset','data_tail','shape','shape_missing','rank','file_size','rows','overflow','alignment','kind','bound_zero','bound_negative','bound_short')
        for mode in modes:
            self.refuse(self.invoke(mode=mode,trace=mode in ('closed','offset')))
            self.accept(self.invoke(count=1))
        for mode in ('ownership','recover'):self.accept(self.invoke(mode=mode,trace=True))
    def test_malformed_real_source_headers_and_wrong_source_kind(self):
        f=q2q3_fixture(self.kind);raw,b,o,e=f
        for data in (raw[:-1],raw[:o-1],raw[:24],b'not-gguf'):
            self.refuse(self.invoke((data,b,o,e),trace=data==raw[:-1]))
        for cols in (0,1,255,257,1048577):
            f=(*make([('matrix.weight',cols,1,self.kind,bytes(SIZES[self.kind]))]),[]);self.refuse(self.invoke(f))
        f=(*make([('matrix.weight',64,1,1,bytes(128))]),[]);self.refuse(self.invoke(f))
    def test_original_source_names_and_owned_binding(self):
        for name in ('matrix-λ-雪.weight','matrix\0tail.weight'):
            f=q2q3_fixture(self.kind,name=name)
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
        r,n,c,k=o['rectangle'];blocks=sorted({x//256 for x in range(c,c+k)});payload=bytearray();spans=[]
        for row in range(r,r+n):
            offset=binding['file_offset']+row*(binding['columns']//256*size)+size*blocks[0]
            covered=256*len(blocks);prefix=c-256*blocks[0];span_size=size*len(blocks)
            spans.append([row,offset,span_size,256*blocks[0],covered,prefix,covered-prefix-k,len(payload)]);payload+=raw[offset:offset+span_size]
        self.assertEqual(o['spans'],spans);self.assertEqual(o['payload'],list(payload))
        for field in ('execution_tested','device_access','source_fingerprint_verified','device_weight_packing_verified'):self.assertIs(o[field],False)
        type(self).byte_checks+=len(payload)
    def test_actual_lazy_matrix_byte_tiles_rows_blocks_and_tails(self):
        f=dense_fixture(self.kind)
        for tc in (1,17,31,32,33,127,128,129,255,256,257):
            count=math.ceil(256/tc)
            for index in sorted({0,min(1,count-1),count-1,85*count,86*count-1,2*86*count-1}):
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
            self.test_malformed_real_source_headers_and_wrong_source_kind()
            self.test_original_source_names_and_owned_binding()
            self.test_actual_source_inventory_and_graph_metadata()
            self.test_actual_lazy_matrix_byte_tiles_rows_blocks_and_tails()
            self.test_byte_tile_live_guards_ownership_and_byte_bound()
    def test_shared_geometry_and_new_admission(self):
        known={0:(1,4),1:(1,2),30:(1,2),2:(32,18),3:(32,20),6:(32,22),7:(32,24),8:(32,34),10:(256,84),11:(256,110),12:(256,144),13:(256,176),14:(256,210)}
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
