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

def block(d,quants):return struct.pack('<H32b',d,*quants)

def make(tensors,architecture='q8-source-field-fixture',metadata=()):
    """Independent writer takes exact payloads, never uses loader byte formulas."""
    entries=[('general.architecture',8,architecture),('general.alignment',4,32),*metadata]
    meta=bytearray()
    for key,kind,value in entries:
        meta+=s(key)+struct.pack('<I',kind)
        meta+=s(value) if kind==8 else struct.pack({4:'<I',5:'<i',6:'<f',7:'<?',10:'<Q',11:'<q'}[kind],value)
    table=bytearray();payload=bytearray();bindings={}
    for name,columns,rows,kind,data in tensors:
        while len(payload)%32:payload.append(0)
        offset=len(payload);payload+=data
        table+=s(name)+struct.pack('<I',1 if rows==1 else 2)+struct.pack('<Q',columns)
        if rows!=1:table+=struct.pack('<Q',rows)
        table+=struct.pack('<IQ',kind,offset)
        bindings[name]={'file_offset':offset,'columns':columns,'rows':rows,'source_kind':kind,'byte_count':len(data)}
    header=struct.pack('<IIQQ',0x46554747,3,len(tensors),len(entries))+meta+table
    origin=(len(header)+31)//32*32
    raw=header+bytes(origin-len(header))+payload
    for b in bindings.values():b['file_offset']+=origin
    return bytes(raw),bindings,origin

def q8_fixture(columns=64,rows=4,words=None,name='matrix.weight'):
    assert columns%32==0
    words=words or [0,0x8000,1,0x7c00,0xfc00,0x7e01,0x7d01,0xffff]
    payload=bytearray();expected=[]
    for i in range(columns*rows//32):
        d=words[i%len(words)];q=[((i*32+j)%256)-128 for j in range(32)]
        payload+=block(d,q);expected += [[d,oracle16(1,d),x] for x in q]
    result=make([(name,columns,rows,8,payload)])
    return (*result,expected)

def dense_fixture():
    hidden,ff,heads,kv,key,value,vocab=64,96,2,1,32,32,4
    tensors=[('token_embd.weight',hidden,vocab,8),('output_norm.weight',hidden,1,0),('output.weight',hidden,vocab,8)]
    shapes=[('attn_norm',hidden,1),('ffn_norm',hidden,1),('attn_q',hidden,heads*key),('attn_k',hidden,kv*key),('attn_v',hidden,kv*value),('attn_output',heads*value,hidden),('ffn_gate',hidden,ff),('ffn_up',hidden,ff),('ffn_down',ff,hidden)]
    tensors += [(f'blk.0.{name}.weight',c,r,0 if r==1 else 8) for name,c,r in shapes]
    rows=[]
    for ti,(name,c,r,kind) in enumerate(tensors):
        data=bytes(c*r*4) if kind==0 else b''.join(block(0x3800+ti,[(j+17*b)%256-128 for j in range(32)]) for b in range(c*r//32))
        rows.append((name,c,r,kind,data))
    metadata=[('llama.context_length',10,64),('llama.embedding_length',4,hidden),('llama.block_count',4,1),('llama.feed_forward_length',4,ff),('llama.attention.head_count',10,heads),('llama.attention.head_count_kv',10,kv),('llama.rope.dimension_count',10,32),('llama.rope.freq_base',6,10000.),('llama.attention.layer_norm_rms_epsilon',6,.00001),('llama.attention.key_length',4,key),('llama.attention.value_length',4,value)]
    return (*make(rows,'llama',metadata),[])

class SourceQ8(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for n in ('binary','api','tile','tile_api','inventory','semantic'):
            setattr(cls,n,str(Path(getattr(CONFIG,n)).resolve(strict=True)))
        cls.evidence=Path(CONFIG.evidence).resolve();cls.evidence.mkdir(exist_ok=False,parents=True)
        cls.temp=tempfile.TemporaryDirectory(prefix='aesir-q8-source-');cls.root=Path(cls.temp.name)
        cls.records=[];cls.fixture_ids={};cls.components=0;cls.byte_checks=0
    @classmethod
    def tearDownClass(cls):
        (cls.evidence/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
        (cls.evidence/'fixtures.json').write_text(json.dumps(cls.fixture_ids,indent=2)+'\n')
        (cls.evidence/'summary.json').write_text(json.dumps({'calls':len(cls.records),'outcomes':dict(Counter('accepted' if x['returncode']==0 else 'refused' for x in cls.records)),'component_checks':cls.components,'byte_checks':cls.byte_checks},indent=2)+'\n')
        print('Q8 native outcomes',dict(Counter('accepted' if x['returncode']==0 else 'refused' for x in cls.records)),'component checks',cls.components,'byte checks',cls.byte_checks)
        cls.temp.cleanup()
    def invoke(self,fixture=None,first=0,count=1,bound=4096,name='matrix.weight',mode=None,trace=False,tool=None,tail=()):
        source=fixture or q8_fixture();raw,bindings,origin,expected=source
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
        o=json.loads(p.stdout);self.assertEqual(o['source_kind'],8);self.assertEqual(o['first'],first)
        self.assertEqual(o['binding'],[b[name][k] for k in ('file_offset','columns','rows','source_kind','byte_count')]);self.assertEqual(o['components'],e)
        for k in ('execution_tested','device_access','source_fingerprint_verified','device_weight_format_verified'):self.assertIs(o[k],False)
        type(self).components+=len(e);return o
    def refuse(self,result):
        p=result[0];self.assertNotEqual(p.returncode,0);self.assertEqual(p.stdout,'')
    def test_all_signed_quants_special_scale_words_and_windows(self):
        f=q8_fixture()
        got=self.accept(self.invoke(f,count=256));self.assertEqual({x[2] for x in got['components']},set(range(-128,128)))
        for first,count in ((0,1),(1,2),(30,5),(31,2),(32,32),(61,8),(127,3),(255,1)):
            self.accept(self.invoke(f,first,count),first)
        for columns,rows in ((32,1),(96,1),(32,9),(96,3)):
            f=q8_fixture(columns,rows);self.accept(self.invoke(f,count=columns*rows))
    def test_exhaustive_scale_word_component_digest(self):
        payload=bytearray();h=14695981039346656037;mask=(1<<64)-1
        for d in range(65536):
            q=[(d+17*j)%256-128 for j in range(32)];payload+=block(d,q)
            word=oracle16(1,d)
            for x in q:
                for v in (d,word,x+128):h=((h^v)*1099511628211)&mask
        f=(*make([('matrix.weight',1024,2048,8,payload)]),[])
        p,*_=self.invoke(f,mode='digest',trace=True);self.assertEqual(p.returncode,0,p.stdout+p.stderr)
        self.assertEqual(json.loads(p.stdout),{'components':2097152,'scale_words':65536,'digest':h,'execution_tested':False,'device_access':False})
        type(self).components+=2097152
    def test_isolated_static_constant_reference(self):
        path=Path(CONFIG.reference_library).resolve(strict=True);digest=hashlib.sha256(path.read_bytes()).hexdigest()
        self.assertEqual(digest,'45bd8cc3f12159e7b219a95d185be74a2ad83789045e6359acf49523aee23328')
        words=[0,0x8000,1,0x3c00,0xbc00,0x7bff,0xfbff,0x3555]
        f=q8_fixture(words=words);actual=self.accept(self.invoke(f,count=256))['components']
        b=f[1]['matrix.weight'];raw=f[0][b['file_offset']:b['file_offset']+b['byte_count']]
        # Test-only tiny constant decoder. No model/context/graph/backend API.
        lib=ctypes.CDLL(str(path));fn=lib.dequantize_row_q8_0
        fn.argtypes=[ctypes.c_void_p,ctypes.POINTER(ctypes.c_float),ctypes.c_int64];fn.restype=None
        inp=ctypes.create_string_buffer(raw);values=(ctypes.c_float*256)();fn(inp,values,256)
        bits=list(struct.unpack('<256I',ctypes.string_at(values,1024)))
        expected=[struct.unpack('<I',struct.pack('<f',struct.unpack('<e',struct.pack('<H',x[0]))[0]*x[2]))[0] for x in actual]
        self.assertEqual(bits,expected)
        (self.evidence/'static-reference.json').write_text(json.dumps({'library_sha256':digest,'constants':256,'binary32_exact':True,'result_sha256':hashlib.sha256(struct.pack('<256I',*bits)).hexdigest(),'model_forward':False},indent=2)+'\n')
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
        f=q8_fixture();raw,b,o,e=f
        for data in (raw[:-1],raw[:o-1],raw[:24],b'not-gguf'):
            self.refuse(self.invoke((data,b,o,e),trace=data==raw[:-1]))
        for cols in (0,1,31,33,1048577):
            f=(*make([('matrix.weight',cols,1,8,bytes(34))]),[]);self.refuse(self.invoke(f))
        f=(*make([('matrix.weight',64,1,1,bytes(128))]),[]);self.refuse(self.invoke(f))
    def test_original_source_names_and_owned_binding(self):
        for name in ('matrix-λ-雪.weight','matrix\0tail.weight'):
            f=q8_fixture(name=name)
            if '\0' in name:self.accept(self.invoke(f,mode='nul_name',name=name),name=name)
            else:self.accept(self.invoke(f,count=33,name=name),name=name)
    def test_actual_source_inventory_and_graph_metadata(self):
        f=dense_fixture()
        p,b,_,_=self.invoke(f,tool='inventory');self.assertEqual(p.returncode,0,p.stdout+p.stderr)
        o=json.loads(p.stdout);self.assertEqual(o['bindings'],b);self.assertIs(o['executable_program'],False)
        p,b,_,_=self.invoke(f,tool='semantic',tail=(3,0,16),trace=True);self.assertEqual(p.returncode,0,p.stdout+p.stderr)
        o=json.loads(p.stdout);self.assertEqual(o['weights'],b)
        for k in ('execution_tested','executable_program','source_fingerprint_verified','hardware_fit_verified'):self.assertIs(o[k],False)
    def check_tile(self,result):
        p,b,_,raw=result;self.assertEqual(p.returncode,0,p.stdout+p.stderr);o=json.loads(p.stdout)
        binding=b[o['weight']];self.assertEqual(binding['source_kind'],8)
        self.assertEqual(o['binding'],[binding[k] for k in ('file_offset','columns','rows','source_kind','byte_count')])
        r,n,c,k=o['rectangle'];blocks=sorted({x//32 for x in range(c,c+k)});payload=bytearray();spans=[]
        for row in range(r,r+n):
            offset=binding['file_offset']+row*(binding['columns']//32*34)+34*blocks[0]
            covered=32*len(blocks);prefix=c-32*blocks[0];size=34*len(blocks)
            spans.append([row,offset,size,32*blocks[0],covered,prefix,covered-prefix-k,len(payload)]);payload+=raw[offset:offset+size]
        self.assertEqual(o['spans'],spans);self.assertEqual(o['payload'],list(payload))
        for field in ('execution_tested','device_access','source_fingerprint_verified','device_weight_packing_verified'):self.assertIs(o[field],False)
        type(self).byte_checks+=len(payload)
    def test_actual_lazy_matrix_byte_tiles_rows_blocks_and_tails(self):
        f=dense_fixture()
        for tc in (1,17,31,32,33,63,64,65):
            count=math.ceil(64/tc)
            for index in sorted({0,min(1,count-1),count-1,21*count,22*count-1,2*22*count-1}):
                self.check_tile(self.invoke(f,tool='tile',tail=(3,0,16,2,2,3,tc,index,1048576,1048576)))
        self.check_tile(self.invoke(f,tool='tile',tail=(3,0,16,2,2,3,17,1,1048576,1048576),trace=True))
    def test_byte_tile_live_guards_ownership_and_byte_bound(self):
        f=dense_fixture()
        modes=('closed','live_size','live_data','live_missing','live_offset','live_columns','live_rows','live_kind','live_bytes','schedule_offset','schedule_columns','schedule_kind','schedule_bytes','schedule_shape','schedule_width','negative_bound','zero_bound','short_bound','negative_index','large_index')
        for mode in modes:self.refuse(self.invoke(f,tool='tile_api',tail=(mode,)))
        for mode in ('accept','ownership'):self.check_tile(self.invoke(f,tool='tile_api',tail=(mode,),trace=True))
        for bound in (-1,0,33,67):self.refuse(self.invoke(f,tool='tile',tail=(3,0,16,2,2,3,33,1,1048576,bound)))

if __name__=='__main__':
    ap=argparse.ArgumentParser()
    for n in ('binary','api','tile','tile-api','inventory','semantic','reference-library','strace','evidence'):ap.add_argument('--'+n,required=True)
    CONFIG,rest=ap.parse_known_args();unittest.main(argv=[sys.argv[0],*rest])
