#!/usr/bin/env python3
"""Exact synthetic byte copies and kernel/ownership gates; no model evaluation."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import random
import struct
import subprocess
import sys
import unittest
from test_hailo_source_digest import GEOMETRIES
from test_hailo_source_q8_constants import make

CONFIG=argparse.Namespace()

class SealedCopy(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary=str(Path(CONFIG.binary).resolve(strict=True));cls.api=str(Path(CONFIG.api).resolve(strict=True));cls.faults=str(Path(CONFIG.faults).resolve(strict=True))
        cls.out=Path(CONFIG.evidence).resolve();cls.out.mkdir(parents=True,exist_ok=False)
        cls.fixtures=cls.out/'fixtures';cls.fixtures.mkdir();cls.records=[];cls.ids={};cls.traces=[];cls.bytes_checked=0
    @classmethod
    def tearDownClass(cls):
        for name,value in [('runs',cls.records),('fixtures',cls.ids),('trace-manifest',cls.traces)]:
            (cls.out/(name+'.json')).write_text(json.dumps(value,indent=2)+'\n')
        summary={'calls':len(cls.records),'outcomes':dict(Counter('accepted' if r['returncode']==0 else 'refused' for r in cls.records)),'complete_copied_byte_comparisons':cls.bytes_checked,'fixtures':len(cls.ids),'traces':len(cls.traces)}
        (cls.out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(summary)
    def fixture(self,raw):
        path=self.fixtures/f'{len(self.ids)}.source';path.write_bytes(raw)
        self.ids[str(path)]={'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'hex':raw.hex()}
        return path
    def call(self,cmd,path=None,trace=False,fault=None,mutation=False):
        cmd=list(map(str,cmd));env=os.environ.copy();fault_log=self.out/f'fault-{len(self.records)}.jsonl'
        if fault:env.update(LD_PRELOAD=self.faults,AESIR_SEAL_FAULT_PATH=str(path),AESIR_SEAL_FAULT_MODE=fault,AESIR_SEAL_FAULT_LOG=str(fault_log))
        trace_path=self.out/f'trace-{len(self.records)}.strace'
        if trace:cmd=[CONFIG.strace,'-f','-y','-o',str(trace_path),*cmd]
        before=Path(path).read_bytes() if path and Path(path).is_file() else None
        p=subprocess.run(cmd,capture_output=True,text=True,env=env,timeout=60,stdin=subprocess.DEVNULL)
        events=[json.loads(line) for line in fault_log.read_text().splitlines()] if fault_log.exists() else []
        r={'arguments':cmd,'returncode':p.returncode,'stdout':p.stdout,'stderr':p.stderr,'fault':fault,'fault_events':events,'source':str(path) if path else None,'mutation':mutation}
        self.records.append(r)
        if trace:self.traces.append({'trace':str(trace_path),'run_index':len(self.records)-1})
        if before is not None and not mutation:self.assertEqual(Path(path).read_bytes(),before)
        return p,events
    def accepted(self,result):
        p=result[0];self.assertEqual(p.returncode,0,p.stdout+p.stderr);self.assertEqual(p.stderr,'');return p
    def refused(self,result,message=None):
        p=result[0];self.assertGreater(p.returncode,0,p.stdout+p.stderr);self.assertEqual(p.stdout,'');self.assertNotIn('test:',p.stderr)
        if message:self.assertIn(message,p.stderr)
        return p
    def api_copy(self,path,size,mode='bytes',bound=None,reads=1048576,writes=1048576,digests=1048576,arch='aarch64',**kw):
        return self.call([self.api,'copy',path,size,max(1,size) if bound is None else bound,reads,writes,digests,arch,mode],path=path,**kw)
    def exact(self,result,raw,counts=None,field=None):
        p=self.accepted(result);obj=json.loads(p.stdout)
        self.assertEqual(obj['source_bytes'],len(raw));self.assertEqual(bytes.fromhex(obj['hex']),raw)
        self.assertEqual(obj['digest_hex'],hashlib.sha256(raw).hexdigest());self.assertEqual(obj['reported_digest'],field or obj['digest_hex'])
        self.assertEqual(obj['seals']&15,15);self.assertEqual(obj['fd_flags']&1,1)
        if counts:self.assertEqual([obj[k] for k in ('source_read_calls','copy_write_calls','digest_read_calls')],list(counts))
        type(self).bytes_checked+=len(raw);return obj
    def test_byte_sizes_chunk_tails_and_full_source_formats(self):
        rng=random.Random(2471)
        values=[bytes(range(256))]+[rng.randbytes(n) for n in (0,1,17,55,56,63,64,65,4095,4096,4097,8193,16383,16384,16385,32769)]
        for raw in values:
            path=self.fixture(raw);n=len(raw);calls=(n+4095)//4096
            self.exact(self.api_copy(path,n,trace=n in (0,17,4097,16385)),raw,(calls,)*3)
            for first,count in sorted({(0,n),(n,0),(0,0),(max(0,n-3),min(3,n))}):
                p=self.accepted(self.call([self.binary,path,first,count,max(1,n),max(1,calls),max(1,calls),max(1,calls)],path=path,trace=n==8193 and first==0 and count==n))
                self.assertEqual(json.loads(p.stdout),{'schema_version':1,'scope':'owned_sealed_observed_source_bytes','sealed_copy_bytes_verified':True,'atomic_original_snapshot_verified':False,'source_fingerprint_verified':False,'immutable_source_verified':False,'binding_identity_verified':False,'execution_tested':False,'device_access':False,'source_bytes':n,'source_read_calls':calls,'copy_write_calls':calls,'digest_read_calls':calls,'digest_hex':hashlib.sha256(raw).hexdigest(),'window_digest_hex':hashlib.sha256(raw[first:first+count]).hexdigest()})
        for kind,(elements,size) in GEOMETRIES.items():
            raw=make([('matrix.weight',elements*3,1,kind,bytes((i*19+kind)%256 for i in range(size*3)))])[0]+b'\x91'
            self.exact(self.api_copy(self.fixture(raw),len(raw)),raw)
        header=json.dumps({'tensor':{'dtype':'F16','shape':[17],'data_offsets':[0,34]}},separators=(',',':')).encode()
        raw=struct.pack('<Q',len(header))+header+bytes(range(34));self.exact(self.api_copy(self.fixture(raw),len(raw)),raw)
    def test_kernel_seals_detachment_mutation_and_return_ownership(self):
        for n in (0,17,8193,16385):
            raw=bytes((i*37+11)%256 for i in range(n))
            for mode in ('protect','implicit','mutate','digest_field'):
                path=self.fixture(raw)
                self.exact(self.api_copy(path,n,mode,trace=True,mutation=mode=='mutate'),raw,field='untrusted-public-field' if mode=='digest_field' else None)
                if mode=='mutate':self.assertEqual(path.read_bytes(),raw[:-1]+b'\xad' if n else b'\xad')
    def test_owner_guards_restore_and_fresh_recovery(self):
        p=self.accepted(self.call([self.api,'default'],trace=True));self.assertEqual(p.stdout,'refused\n')
        raw=bytes(range(70));path=self.fixture(raw)
        for mode in ('closed','size','negative_size','arch','fd','unsealed'):
            p=self.accepted(self.api_copy(path,len(raw),mode,trace=True));self.assertEqual(p.stdout,'refused_and_recovered\n')
        self.exact(self.api_copy(path,len(raw)),raw)
    def test_input_bounds_and_pre_effect_guards(self):
        raw=bytes(range(70));path=self.fixture(raw)
        policies=[(-1,70,1,1,1,'aarch64'),(69,70,1,1,1,'aarch64'),(71,71,1,1,1,'aarch64'),(70,0,1,1,1,'aarch64'),(70,-1,1,1,1,'aarch64'),(70,69,1,1,1,'aarch64'),(70,70,0,1,1,'aarch64'),(70,70,1,0,1,'aarch64'),(70,70,1,1,0,'aarch64'),(70,70,-1,1,1,'aarch64'),(70,70,1,-1,1,'aarch64'),(70,70,1,1,-1,'aarch64'),(70,70,1,1,1,'x86_64'),(1<<61,(1<<63)-1,1,1,1,'aarch64')]
        for expected,bound,r,w,d,arch in policies:
            result=self.api_copy(path,expected,bound=bound,reads=r,writes=w,digests=d,arch=arch,trace=True);self.refused(result)
        for fd in (-1,2147483648,(1<<63)-1,1000000):self.refused(self.call([self.api,'bad_fd','aarch64',fd],trace=True))
        self.refused(self.api_copy(self.fixtures,0,trace=True))
        for first,count in ((-1,1),(0,-1),(71,0),(70,1),((1<<63)-1,(1<<63)-1)):
            self.refused(self.call([self.binary,path,first,count,70,1,1,1],path=path,trace=True))
    def test_fault_progress_independent_attempt_budgets_and_cleanup(self):
        raw=bytes(range(70));path=self.fixture(raw)
        cases=[('read_short',24,24,1,True,(24,24,1)),('read_short',23,24,1,False,None),('write_short',1,24,1,True,(1,24,1)),('write_short',1,23,1,False,None),('digest_short',1,1,24,True,(1,1,24)),('digest_short',1,1,23,False,None),('read_eintr_once',2,1,1,True,(2,1,1)),('read_eintr_once',1,1,1,False,None),('write_eintr_once',1,2,1,True,(1,2,1)),('write_eintr_once',1,1,1,False,None),('digest_eintr_once',1,1,2,True,(1,1,2)),('digest_eintr_once',1,1,1,False,None)]
        cases += [(mode,3,3,3,False,None) for mode in ('create','alias','large_fd','source_stat_before','source_stat_after','source_extent','destination_stat','destination_extent','seal','seal_after','get_seals','missing_seals','digest_stat_before','digest_stat_after','read_eintr','write_eintr','digest_eintr','read_error','write_error','digest_error','read_eof','write_zero','digest_eof','read_extra','write_extra','digest_extra')]
        cases.append(('extra_seals',1,1,1,True,(1,1,1)))
        for mode,r,w,d,ok,counts in cases:
            result=self.api_copy(path,70,reads=r,writes=w,digests=d,fault=mode,trace=True)
            if ok:self.exact(result,raw,counts)
            else:self.refused(result)
            events=result[1];self.assertLessEqual(sum(e['op']=='source_read' for e in events),r);self.assertLessEqual(sum(e['op']=='copy_write' for e in events),w)
            if not ok:self.assertLessEqual(sum(e['op']=='digest_read' for e in events),d)
            self.assertEqual(path.read_bytes(),raw)
        self.exact(self.api_copy(path,70,'close_error',fault='close_after',trace=True),raw)
        self.exact(self.api_copy(path,70,trace=True),raw)

if __name__=='__main__':
    ap=argparse.ArgumentParser()
    for name in ('binary','api','faults','strace','evidence'):ap.add_argument('--'+name,required=True)
    CONFIG,remaining=ap.parse_known_args();unittest.main(argv=[sys.argv[0],*remaining])
