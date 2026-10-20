#!/usr/bin/env python3
"""Synthetic metadata and relative byte addresses only. Never reads KV data."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from test_hailo_semantic_plan import dense_fixture,MAX

CONFIG=argparse.Namespace()
DEFAULT=(2,1,64,64,64,1048576,'explicit synthetic layout; no physical resource proof')


def expected_regions(layers,capacity,heads,key,value,policy):
    kw,vw,ks,vs,_,_,_=policy
    rows=[];cursor=0
    for layer in range(layers):
        for side,(kind,dim,width,stride) in enumerate((('key',key,kw,ks),('value',value,vw,vs))):
            size=capacity*stride
            rows.append(dict(layer=layer,kind=kind,name=f'blk.{layer}.{kind}_cache',
                             source_tensor=9+23*layer+side,source_view=11+23*layer+side,
                             offset=cursor,token_bytes=heads*dim*width,stride=stride,byte_count=size,
                             first_element=cursor,last_element=cursor+(capacity-1)*stride+(heads*dim-1)*width))
            cursor+=size
    return rows,cursor


class CacheAddresses(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary=str(Path(CONFIG.binary).resolve(strict=True));cls.api=str(Path(CONFIG.api_binary).resolve(strict=True))
        cls.temp=tempfile.TemporaryDirectory(prefix='aesir-cache-layout-');cls.root=Path(cls.temp.name)
        cls.evidence=Path(CONFIG.evidence).resolve();cls.evidence.mkdir(parents=True,exist_ok=True);cls.records=[]

    @classmethod
    def tearDownClass(cls):
        (cls.evidence/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
        cls.temp.cleanup()
        print('Native outcomes: '+str(dict(Counter('accepted' if r['returncode']==0 else 'refused' for r in cls.records))))

    def run_child(self,command,source,scope):
        before=hashlib.sha256(source.read_bytes()).hexdigest()
        result=subprocess.run(command,capture_output=True,text=True,timeout=20,stdin=subprocess.DEVNULL)
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),before)
        self.records.append(dict(scope=scope,source_sha256=before,returncode=result.returncode,stdout=result.stdout,stderr=result.stderr))
        return result

    def invoke(self,source=None,session=(3,0,16),policy=DEFAULT,extra=(),trace=False):
        raw=source[0] if source is not None else dense_fixture()[0]
        path=self.root/f'fixture-{len(self.records)}.gguf';path.write_bytes(raw)
        command=[self.binary,str(path),*map(str,session),*map(str,policy),*map(str,extra)]
        if trace:command=[CONFIG.strace,'-y','-o',str(self.evidence/'layout.strace'),'-e','trace=openat,ioctl,mmap,munmap',*command]
        return self.run_child(command,path,'layout')

    def accepts(self,fixture_options=None,session=(3,0,16),policy=DEFAULT,trace=False):
        opts=fixture_options or {}
        layers=opts.get('layers',1);heads=opts.get('kv_heads',2);key=opts.get('key',2);value=opts.get('value',2)
        result=self.invoke(dense_fixture(**opts),session,policy,('enumerate',),trace)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        actual=json.loads(result.stdout)
        for flag in ('hardware_layout_verified','source_fingerprint_verified','execution_tested','device_access'):self.assertIs(actual[flag],False)
        self.assertEqual(actual['layout'],'assumed_token_major')
        self.assertEqual(actual['provenance'],policy[-1])
        regions,total=expected_regions(layers,session[2],heads,key,value,policy)
        self.assertEqual(actual['regions'],regions);self.assertEqual(actual['total_bytes'],total)
        expected=[];occupied=set()
        for region in regions:
            dim=key if region['kind']=='key' else value
            width=policy[0] if region['kind']=='key' else policy[1]
            for slot in range(session[2]):
                for head in range(heads):
                    for component in range(dim):
                        address=region['offset']+slot*region['stride']+(head*dim+component)*width
                        expected.append(address)
                        span=set(range(address,address+width))
                        self.assertFalse(occupied&span);occupied.update(span)
                        self.assertLessEqual(address+width,region['offset']+region['byte_count'])
        self.assertEqual(actual['element_offsets'],expected)
        self.assertEqual(len(occupied),layers*session[2]*heads*(key*policy[0]+value*policy[1]))
        return actual

    def refused(self,*args,**kwargs):
        result=self.invoke(*args,**kwargs)
        self.assertNotEqual(result.returncode,0);self.assertEqual(result.stdout,'')
        self.assertTrue(any(s in result.stderr for s in ("SourceInventory:", "CacheLayout:", "SemanticPlan:", "StorageEstimate:", "GGUF")),result.stderr)

    def test_exhaustive_small_relative_addresses_with_distinct_dimensions(self):
        for layers,heads,kv,key,value,capacity in ((1,4,2,2,2,16),(2,6,3,4,3,8),(3,3,1,6,1,7),(2,4,4,2,5,6)):
            for kw,vw,alignment in ((1,2,1),(2,1,16),(4,2,64)):
                ks=((kv*key*kw+alignment-1)//alignment+1)*alignment
                vs=((kv*value*vw+alignment-1)//alignment+2)*alignment
                policy=(kw,vw,ks,vs,alignment,1048576,'synthetic "α" layout\nrelative offsets only')
                self.accepts(dict(layers=layers,heads=heads,kv_heads=kv,key=key,value=value),
                             (2,1,capacity),policy)

    def test_pool_boundary_and_equal_final_entry_size(self):
        self.accepts(policy=(*DEFAULT[:5],2048,DEFAULT[-1]))
        self.refused(policy=(*DEFAULT[:5],2047,DEFAULT[-1]))
        self.accepts(policy=(2,1,8,4,4,192,'exact unpadded entries'),session=(1,0,16))
        self.accepts(dict(tied=True),session=(1,4,16))

    def test_policy_refusals_overflow_and_explicit_assumptions(self):
        for index,value in ((0,0),(1,-1),(2,0),(3,-1),(4,0),(4,3),(5,0),(6,''),
                            (0,MAX),(1,MAX),(2,MAX),(3,MAX),(2,2),(3,2),(2,65)):
            policy=list(DEFAULT);policy[index]=value;self.refused(policy=tuple(policy))
        self.refused(session=(1,16,16))
        self.refused(session=(1,0,0))

    def test_address_indices_and_diagnostic_host_enumeration_bound(self):
        for region,slot,head,component in ((-1,0,0,0),(2,0,0,0),(0,-1,0,0),(0,16,0,0),
                                           (0,0,-1,0),(0,0,2,0),(0,0,0,-1),(0,0,0,2),
                                           (MAX,0,0,0),(0,MAX,0,0)):
            self.refused(extra=(region,slot,head,component))
        accepted=self.invoke(extra=(1,15,1,1));self.assertEqual(accepted.returncode,0,accepted.stderr)
        self.assertEqual(json.loads(accepted.stdout)['element_offset'],1987)
        self.refused(source=dense_fixture(layers=9),session=(1,0,64),extra=('enumerate',))
        self.refused(extra=('unknown',))

    def test_source_bound_graph_and_returned_layout_refusals(self):
        path=self.root/'api.gguf';path.write_bytes(dense_fixture()[0])
        modes=('base_shape','base_elements','base_owner','base_producer','base_alias','base_lifetime',
               'view_alias','view_shape','view_lifetime','append_input','append_writer','append_arity',
               'append_output','append_kind','writer_kind','writer_output','writer_input','projection_weight',
               'projection_shape','projection_extent','projection_bytes','projection_consumed','source_extent',
               'hidden','heads','session','layers','rename','duplicate','foreign_owner','foreign_alias',
               'layout_overlap','layout_stride','layout_bytes','layout_name','layout_id','layout_total',
               'layout_pool','layout_dimension','layout_shape','layout_regions')
        for mode in modes:
            result=self.run_child([self.api,str(path),mode],path,'api_refusal:'+mode)
            self.assertNotEqual(result.returncode,0,mode);self.assertEqual(result.stdout,'')
            self.assertTrue(any(s in result.stderr for s in ("SourceInventory:", "CacheLayout:", "SemanticPlan:", "StorageEstimate:", "GGUF")),result.stderr)
        result=self.run_child([self.api,str(path),'ownership'],path,'ownership')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(result.stdout.strip(),'owned-cache-layout-pass')

    def test_read_only_no_cache_or_device_data(self):
        self.accepts(trace=True)
        trace=(self.evidence/'layout.strace').read_text()
        for required in ('O_RDONLY','PROT_READ, MAP_PRIVATE','munmap('):self.assertIn(required,trace)
        for forbidden in ('/dev/h1x-','libhailort','libcuda','libggml','ioctl('):self.assertNotIn(forbidden,trace)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for name in ('binary','api-binary','strace','evidence'):parser.add_argument('--'+name,required=True)
    CONFIG,remaining=parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
