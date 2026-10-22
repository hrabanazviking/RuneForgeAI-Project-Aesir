#!/usr/bin/env python3
"""Observed byte hashes only. No model arithmetic or device operations."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import subprocess
import sys
import unittest
from test_hailo_source_q8_constants import make

CONFIG=argparse.Namespace()
GEOMETRIES={0:(1,4),1:(1,2),30:(1,2),2:(32,18),3:(32,20),6:(32,22),7:(32,24),8:(32,34),10:(256,84),11:(256,110),12:(256,144),13:(256,176),14:(256,210),20:(32,18),23:(256,136)}

class SourceDigest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary=str(Path(CONFIG.binary).resolve(strict=True));cls.api=str(Path(CONFIG.api).resolve(strict=True))
        cls.faults=str(Path(CONFIG.faults).resolve(strict=True))
        cls.out=Path(CONFIG.evidence).resolve();cls.out.mkdir(parents=True,exist_ok=False)
        cls.fixtures=cls.out/'fixtures';cls.fixtures.mkdir();cls.records=[];cls.ids={};cls.traces=[]
    @classmethod
    def tearDownClass(cls):
        (cls.out/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
        (cls.out/'fixtures.json').write_text(json.dumps(cls.ids,indent=2)+'\n')
        (cls.out/'trace-manifest.json').write_text(json.dumps(cls.traces,indent=2)+'\n')
        summary={'calls':len(cls.records),'accepted':sum(r['returncode']==0 for r in cls.records),'refused':sum(r['returncode']!=0 for r in cls.records),'trace_count':len(cls.traces),'fixtures':len(cls.ids)}
        (cls.out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(summary)
    def fixture(self,kind=0,blocks=513):
        n,size=GEOMETRIES[kind];payload=bytes((i*37+kind)%256 for i in range(size*blocks))
        raw,_,origin=make([('matrix.weight',n*blocks,1,kind,payload)])
        raw+=b'\x91' # A legal unreferenced odd tail is still part of the file digest.
        path=self.fixtures/f'{len(self.ids)}.gguf';path.write_bytes(raw)
        self.ids[str(path)]={'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'kind':kind,'origin':origin}
        return path,raw,origin
    def call(self,args,trace=False,fault=None,path=None,mutation=False):
        cmd=list(map(str,args));env=os.environ.copy()
        if fault:env.update(LD_PRELOAD=self.faults,AESIR_DIGEST_FAULT_PATH=str(path),AESIR_DIGEST_FAULT_MODE=fault)
        trace_path=None
        if trace:
            trace_path=self.out/f'trace-{len(self.records)}.strace'
            cmd=[CONFIG.strace,'-f','-y','-o',str(trace_path),*cmd]
        before=Path(path).read_bytes() if path and Path(path).is_file() else None
        p=subprocess.run(cmd,capture_output=True,text=True,env=env,timeout=60,stdin=subprocess.DEVNULL)
        self.records.append({'arguments':cmd,'fault':fault,'returncode':p.returncode,'stdout':p.stdout,'stderr':p.stderr})
        if trace:self.traces.append({'trace':str(trace_path),'path':str(path) if path else None,'fault':fault,'mutation':mutation,'returncode':p.returncode})
        if before is not None and not mutation:self.assertEqual(Path(path).read_bytes(),before)
        return p
    def accepted(self,p):self.assertEqual(p.returncode,0,p.stdout+p.stderr);self.assertEqual(p.stderr,'')
    def refused(self,p):self.assertNotEqual(p.returncode,0,p.stdout+p.stderr);self.assertGreater(p.returncode,0);self.assertEqual(p.stdout,'')
    def borrow(self,path,expected,first,count,byte_bound=None,calls=1024,arch='aarch64',**kw):
        return self.call([self.api,'borrow',path,expected,first,count,count or 1 if byte_bound is None else byte_bound,calls,arch],path=path,**kw)
    def test_vectors_and_independent_chunkings(self):
        vectors={b'abc':'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',b'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq':'248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1'}
        rng=random.Random(719)
        data=[b'',*vectors,bytes(range(256))]+[rng.randbytes(n) for n in (1,2,54,55,56,57,62,63,64,65,119,120,127,128,129,4095,4096,4097,16383,16384,16385)]
        for raw in data:
            expected=vectors.get(raw,hashlib.sha256(raw).hexdigest())
            self.assertEqual(hashlib.sha256(raw).hexdigest(),expected)
            for chunk in (1,7,55,56,63,64,65,4096,65536):
                p=self.call([self.api,'hash',raw.hex(),chunk]);self.accepted(p)
                self.assertEqual(p.stdout.splitlines(),[expected]*3)
    def test_invalid_and_sealed_states_preserve_inputs(self):
        for mode in (*range(7),10,11,12,13):
            p=self.call([self.api,'state',mode],trace=mode in (4,6));self.accepted(p)
            self.assertEqual(p.stdout.splitlines(),['refused',hashlib.sha256(b'').hexdigest()])
    def test_gguf_all_geometries_and_byte_boundaries(self):
        for kind in GEOMETRIES:
            path,raw,origin=self.fixture(kind)
            spans={(0,0),(len(raw),0),(0,len(raw)),(0,origin),(origin,len(raw)-origin),(len(raw)-1,1),(55,65),(63,1),(64,65)}
            for first,count in ((4095,3),(4096,65),(16383,3),(16384,65)):
                if first+count<=len(raw):spans.add((first,count))
            for first,count in sorted(spans):
                p=self.call([self.binary,path,first,count,count or 1,1024],path=path,trace=kind in (0,23) and first==0 and count==len(raw));self.accepted(p)
                obj=json.loads(p.stdout)
                self.assertEqual(obj,{'schema_version':1,'scope':'observed_source_byte_window_digest','byte_digest_computed':True,'source_fingerprint_verified':False,'immutable_source_verified':False,'binding_identity_verified':False,'execution_tested':False,'device_access':False,'source_bytes':len(raw),'first':first,'count':count,'read_calls':(count+4095)//4096,'digest_hex':hashlib.sha256(raw[first:first+count]).hexdigest()})
    def test_owner_lifetime_mutations_and_truncation(self):
        for mode in ('owned','closed','size','negative_size','origin','tail_origin','truncate','same_size'):
            path,raw,_=self.fixture()
            p=self.call([self.api,'owner',path,mode],path=path,trace=True,mutation=mode in ('truncate','same_size'))
            if mode in ('owned','same_size'):
                self.accepted(p);lines=p.stdout.splitlines();obj=json.loads(lines[-1])
                self.assertEqual(obj['digest_hex'],hashlib.sha256(path.read_bytes()).hexdigest())
                if mode=='same_size':self.assertEqual(lines[0],hashlib.sha256(raw).hexdigest());self.assertNotEqual(lines[0],obj['digest_hex']);self.assertEqual(path.read_bytes(),raw[:-1]+b'\xad')
            else:
                self.refused(p)
                if mode=='truncate':self.assertEqual(path.read_bytes(),raw[:1])
    def test_borrowed_bounds_exact_fd_and_ownership(self):
        path,raw,_=self.fixture(23)
        for first,count in ((0,0),(len(raw),0),(7,16531),(len(raw)-3,3)):
            p=self.borrow(path,len(raw),first,count,trace=True);self.accepted(p)
            self.assertEqual(p.stdout.splitlines(),[hashlib.sha256(raw[first:first+count]).hexdigest(),str((count+4095)//4096)])
        for expected,first,count,bound,calls,arch in ((-1,0,0,1,1,'aarch64'),(len(raw)-1,0,1,1,1,'aarch64'),(len(raw)+1,0,1,1,1,'aarch64'),(len(raw),-1,1,1,1,'aarch64'),(len(raw),0,-1,1,1,'aarch64'),(len(raw),len(raw)+1,0,1,1,'aarch64'),(len(raw),len(raw),1,1,1,'aarch64'),(len(raw),0,2,1,1,'aarch64'),(len(raw),0,0,0,1,'aarch64'),(len(raw),0,0,1,0,'aarch64'),(len(raw),0,0,1,1,'x86_64'),((1<<63)-1,0,1<<61,(1<<63)-1,1,'aarch64'),(len(raw),(1<<63)-1,(1<<63)-1,(1<<63)-1,1,'aarch64')):
            self.refused(self.borrow(path,expected,first,count,byte_bound=bound,calls=calls,arch=arch))
        for fd in (-1,2147483648,(1<<63)-1):self.refused(self.call([self.api,'bad_fd','aarch64',fd,0]))
        self.refused(self.borrow(self.fixtures,0,0,0,trace=True))
        self.refused(self.borrow('/dev/null',0,0,0)) # Test-only nonregular fd admission refusal.
    def test_fault_progress_budgets_and_cleanup(self):
        path,raw,_=self.fixture()
        for mode,calls,ok,expected_calls in (('short',24,True,24),('short',23,False,None),('eintr_once',2,True,2),('eintr_once',1,False,None),('eintr',3,False,None),('eof',9,False,None),('eio',9,False,None),('extra_count',9,False,None),('stat_before',9,False,None),('stat_after',9,False,None),('changed_size',9,False,None)):
            p=self.borrow(path,len(raw),11,70,calls=calls,fault=mode,trace=True)
            if ok:self.accepted(p);self.assertEqual(p.stdout.splitlines(),[hashlib.sha256(raw[11:81]).hexdigest(),str(expected_calls)])
            else:self.refused(p)
        # Fresh same descriptor API after refusals remains independent.
        p=self.borrow(path,len(raw),0,len(raw));self.accepted(p);self.assertEqual(p.stdout.splitlines()[0],hashlib.sha256(raw).hexdigest())

if __name__=='__main__':
    ap=argparse.ArgumentParser()
    for name in ('binary','api','faults','strace','evidence'):ap.add_argument('--'+name,required=True)
    CONFIG,remaining=ap.parse_known_args();unittest.main(argv=[sys.argv[0],*remaining])
