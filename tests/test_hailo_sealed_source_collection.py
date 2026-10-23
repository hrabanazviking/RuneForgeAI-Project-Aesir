#!/usr/bin/env python3
"""Independent ordinary backing-byte ownership, joins and static representations."""
import argparse
from collections import Counter
import copy
import hashlib
import json
import math
import os
from pathlib import Path
import random
import struct
import subprocess
import sys
import unittest
from test_hailo_shard_collection import DEFAULT
from test_hailo_source_float_constants import oracle16

CONFIG=argparse.Namespace()
COPY=[16777216,16384,16384,16384]
DTYPES={'F16':(0,2),'BF16':(1,2),'F32':(2,4)}


def encode(value):return json.dumps(value,ensure_ascii=False,separators=(',',':')).encode()


def source(tensors,pad=0):
    header={};payload=b'';expected={}
    for name,dtype,shape,words in tensors:
        code,width=DTYPES[dtype];assert math.prod(shape)==len(words)
        first=len(payload);payload+=b''.join(w.to_bytes(width,'little') for w in words)
        header[name]=dict(dtype=dtype,shape=shape,data_offsets=[first,len(payload)])
        expected[name]=dict(dtype=code,shape=shape,raw_words=words,binary32_words=words if dtype=='F32' else [oracle16(1 if dtype=='F16' else 30,w) for w in words],relative=first,byte_count=len(words)*width)
    header['__metadata__']={'source':'tiny synthetic\0雪'}
    raw=encode(header)+b' '*pad
    return struct.pack('<Q',len(raw))+raw+payload,expected


class SealedCollection(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out=Path(CONFIG.evidence).resolve();cls.out.mkdir(parents=True,exist_ok=False)
        cls.records=[];cls.fixtures=[];cls.mutations=[];cls.comparisons=Counter();cls.sequence=0
        for name in ('binary','api','indexed_control','unindexed_control','faults'):
            setattr(cls,name,str(Path(getattr(CONFIG,name)).resolve(strict=True)))
    @classmethod
    def tearDownClass(cls):
        for name,obj in [('runs',cls.records),('fixtures',cls.fixtures),('mutations',cls.mutations)]:
            (cls.out/(name+'.json')).write_text(json.dumps(obj,indent=2)+'\n')
        result=dict(calls=len(cls.records),outcomes=dict(Counter('accepted' if r['returncode']==0 else 'refused' for r in cls.records)),comparisons=dict(cls.comparisons))
        (cls.out/'summary.json').write_text(json.dumps(result,indent=2)+'\n');print(result)

    def fixture(self,indexed=True,seed=0,pad=0,empty=False):
        type(self).sequence+=1;root=self.out/('model-%04d'%self.sequence);root.mkdir()
        rng=random.Random(seed)
        shapes=[('a\0λ','F16',[8],[0,0x8000,1,0x3c00,0x7c00,0xfc00,0x7c01,0xffff]),
                ('bf','BF16',[2,2],[0,0x8001,0x7f81,0xffc1]),
                ('f32','F32',[],[0x7f800001]),('empty','F32',[2,0,3],[]),
                ('seeded','F32',[4],[rng.getrandbits(32) for _ in range(4)])]
        parts=[('nested/a.safetensors',shapes[:2]),('b.safetensors',shapes[2:])] if indexed else [('nested/a.safetensors',shapes)]
        if empty:parts=[] if indexed else [('nested/a.safetensors',[])]
        expected={};files={};weight_map={};payload=0
        for label,tensors in parts:
            raw,want=source(tensors,pad);files[label]=raw;expected[label]=want
            for name,_,_,words in tensors:weight_map[name]=label
            payload+=sum(x['byte_count'] for x in want.values())
        files['config.json']=b'{ "model_type" : "future", "rope_scaling": null, "head_dim":null, "unknown" : [1, {"x":false}] }\n'
        index={'metadata':{'total_size':payload,'future':[None,{'x':True}]},'weight_map':weight_map,'unknown':{'λ':None}}
        if indexed:files['index.json']=encode(index)
        for label,raw in files.items():
            p=root/label;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(raw)
        (root/'invalid.index.json').write_bytes(encode({'weight_map':{'late':'absent.safetensors','a\0λ':'nested/a.safetensors'}}))
        (root/'invalid.safetensors').write_bytes(b'not safetensors')
        self.fixtures.append(dict(root=str(root),indexed=indexed,files={k:dict(hex=v.hex(),bytes=len(v),sha256=hashlib.sha256(v).hexdigest()) for k,v in files.items()},windows=expected))
        return root,files,expected

    def policies(self,indexed):return copy.deepcopy(DEFAULT if indexed else [DEFAULT[0],DEFAULT[2],DEFAULT[3],DEFAULT[4]])

    def child(self,command,root=None,trace=False,env=None):
        command=list(map(str,command));tracepath=None
        if trace:
            tracepath=self.out/('trace-%04d.strace'%len(self.records))
            command=[CONFIG.strace,'-f','-yy','-s','4096','-o',str(tracepath),'-e','trace=%file,%desc,%memory,%network,%process',*command]
        r=subprocess.run(command,capture_output=True,text=True,timeout=90,stdin=subprocess.DEVNULL,env=env)
        self.records.append(dict(arguments=command,root=str(root) if root else None,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr,trace=str(tracepath) if tracepath else None,fault_environment={k:v for k,v in (env or {}).items() if k.startswith('AESIR_') or k=='LD_PRELOAD'}))
        return r

    def call(self,root,indexed=True,mode=None,policies=None,copy_policy=COPY,trace=True,env=None,first=None,config='config.json'):
        args=[root,first or ('index.json' if indexed else 'nested/a.safetensors'),config,*[v for group in policies or self.policies(indexed) for v in group],*copy_policy]
        return self.child([self.api,mode,'indexed' if indexed else 'unindexed',*args] if mode else [self.binary,'indexed' if indexed else 'unindexed',*args],root,trace,env)

    def control(self,root,indexed):
        r=self.child([self.indexed_control if indexed else self.unindexed_control,root,'index.json' if indexed else 'nested/a.safetensors','config.json',*[v for group in self.policies(indexed) for v in group]],root)
        self.assertEqual(r.returncode,0,r.stderr);return json.loads(r.stdout)

    def exact(self,result,root,files,want,indexed=True,reference=None):
        self.assertEqual(result.returncode,0,result.stdout+result.stderr);self.assertEqual(result.stderr,'')
        lines=result.stdout.splitlines();self.assertIn(len(lines),(1,2));report=json.loads(lines[0]);old=reference or self.control(root,indexed)
        for key in ('root_path','index','config','tensor_count','metadata_bytes','payload_bytes','work_units'):
            if key in old:self.assertEqual(report[key],old[key],key)
        actual=report['shards'] if indexed else [report['source']]
        oldshards=old['shards'] if indexed else [old['source']]
        self.assertEqual([{k:v for k,v in s.items() if k!='digest_hex'} for s in actual],oldshards)
        self.assertEqual(report['source_bytes'],sum(map(len,files.values())))
        self.assertEqual(report['config_digest_hex'],hashlib.sha256(files['config.json']).hexdigest())
        if indexed:self.assertEqual(report['index_digest_hex'],hashlib.sha256(files['index.json']).hexdigest())
        for shard in actual:self.assertEqual(shard['digest_hex'],hashlib.sha256(files[shard['label']]).hexdigest())
        self.assertTrue(report['owned_observed_collection'])
        for key,value in report.items():
            if key.endswith('_verified') or key in ('execution_tested','device_access'):self.assertIs(value,False,key)
        if len(lines)==2:
            data=json.loads(lines[1]);self.assertEqual(data['config_hex'],files['config.json'].hex())
            if indexed:self.assertEqual(data['index_hex'],files['index.json'].hex())
            self.assertEqual({s['label'] for s in data['shards']},set(want))
            for shard in data['shards']:
                label=shard['label'];raw=files[label];base=8+struct.unpack_from('<Q',raw)[0]
                self.assertEqual(shard['bytes_hex'],raw.hex());self.assertEqual(len(shard['windows']),len(want[label]))
                for window in shard['windows']:
                    name=bytes.fromhex(window['name_utf8_hex']).decode();expected=want[label][name]
                    for key in ('dtype','shape','raw_words','binary32_words','byte_count'):self.assertEqual(window[key],expected[key],(name,key))
                    self.assertEqual(window['file_offset'],base+expected['relative']);self.assertEqual(window['source_bytes'],len(raw));self.assertEqual(window['count'],len(expected['raw_words']))
                    self.comparisons['exact_component_words']+=2*len(expected['raw_words'])
                self.comparisons['full_shard_bytes']+=len(raw)
            self.comparisons['complete_byte_and_component_snapshots']+=1
        self.comparisons['complete_metadata_storage_and_counter_projections']+=1
        return report

    def refused(self,result):
        self.assertNotEqual(result.returncode,0,result.stdout);self.assertEqual(result.stdout,'')
        self.assertIn('Unhandled exception caught during execution:',result.stderr)

    def restore(self,root,files):
        for label,raw in files.items():
            (root/label).write_bytes(raw);(root/(label+'.before')).unlink(missing_ok=True)

    def test_complete_seeded_indexed_unindexed_bytes_and_components(self):
        for indexed in (True,False):
            for seed in range(12):
                root,files,want=self.fixture(indexed,seed,pad=seed)
                self.exact(self.call(root,indexed,mode='snapshot',trace=seed<2),root,files,want,indexed)
            root,files,want=self.fixture(indexed,empty=True)
            self.exact(self.call(root,indexed,mode='snapshot'),root,files,want,indexed)

    def test_move_retained_copied_values_caches_recovery_and_bounds(self):
        for indexed in (True,False):
            root,files,want=self.fixture(indexed);old=self.control(root,indexed)
            for mode in ('move','retained','cache','recover'):
                self.exact(self.call(root,indexed,mode=mode),root,files,want,indexed,old)
            for mode in ('byte_zero','byte_short','owner_extent','window_first','window_count','window_bound'):
                self.refused(self.call(root,indexed,mode=mode))
                self.exact(self.call(root,indexed,mode='snapshot'),root,files,want,indexed,old)

    def test_exact_page_hash_and_metadata_read_boundaries(self):
        for indexed in (True,False):
            for size in (4095,4096,4097,8191,8192,8193,16383,16384,16385):
                root,files,want=self.fixture(indexed)
                label='nested/a.safetensors';raw=files[label];n=struct.unpack_from('<Q',raw)[0]
                padding=size-len(raw);self.assertGreaterEqual(padding,0)
                files[label]=struct.pack('<Q',n+padding)+raw[8:8+n]+b' '*padding+raw[8+n:]
                files['config.json']+=b' '*(size-len(files['config.json']))
                if indexed:files['index.json']+=b' '*(size-len(files['index.json']))
                for label,raw in files.items():(root/label).write_bytes(raw)
                self.fixtures[-1]['files']={k:dict(hex=v.hex(),bytes=len(v),sha256=hashlib.sha256(v).hexdigest()) for k,v in files.items()}
                self.exact(self.call(root,indexed,mode='snapshot'),root,files,want,indexed)

    def test_full_original_mutations_and_independent_repeats(self):
        for indexed in (True,False):
            root,files,want=self.fixture(indexed);old=self.control(root,indexed)
            for mode in ('truncate','zero','replace','rename','same_size'):
                outputs=[];postimages=[]
                for repeat in range(2):
                    self.restore(root,files);r=self.call(root,indexed,mode=mode)
                    self.exact(r,root,files,want,indexed,old);outputs.append((r.returncode,r.stdout,r.stderr))
                    after={label:(root/label).read_bytes() for label in files}
                    expected={k:v[:1] if mode=='truncate' else v[:-1]+bytes([v[-1]^64]) if mode=='same_size' else b'' for k,v in files.items()}
                    self.assertEqual(after,expected);postimages.append(after)
                    renamed={k:(root/(k+'.before')).read_bytes().hex() if (root/(k+'.before')).exists() else None for k in files}
                    self.assertEqual(renamed,{k:v.hex() if mode=='rename' else None for k,v in files.items()})
                    self.mutations.append(dict(root=str(root),mode=mode,repeat=repeat,before={k:v.hex() for k,v in files.items()},after={k:v.hex() for k,v in after.items()},renamed=renamed))
                self.assertEqual(outputs[0],outputs[1]);self.assertEqual(postimages[0],postimages[1])
            self.restore(root,files)

    def test_root_parser_aggregate_and_separate_copy_limits(self):
        for indexed in (True,False):
            root,files,want=self.fixture(indexed);old=self.control(root,indexed);policies=self.policies(indexed)
            for group in range(len(policies)):
                for field in range(len(policies[group])):
                    bad=copy.deepcopy(policies);bad[group][field]=0
                    self.refused(self.call(root,indexed,policies=bad,trace=(field==0)))
            for i in range(4):
                for bound in (0,-1):
                    cp=list(COPY);cp[i]=bound;self.refused(self.call(root,indexed,copy_policy=cp))
            for total in (sum(map(len,files.values()))-1,sum(map(len,files.values()))):
                cp=list(COPY);cp[0]=total;r=self.call(root,indexed,copy_policy=cp)
                if total==sum(map(len,files.values())):self.exact(r,root,files,want,indexed,old)
                else:self.refused(r)
            # Root file attempts, collection counts, metadata, payload and work
            # limits each retain their own scope and exact successful endpoint.
            for metric,field in [('metadata_bytes',2),('payload_bytes',3),('work_units',4)]:
                for delta in (-1,0):
                    p=copy.deepcopy(policies);p[-1][field]=old[metric]+delta;r=self.call(root,indexed,policies=p)
                    if delta==0:self.exact(r,root,files,want,indexed,old)
                    else:self.refused(r)
            for group,field,value in [(0,1,len(files)-1),(-1,1,old['tensor_count']-1),(-2,2,0),(-2,4,65)]:
                p=copy.deepcopy(policies);p[group][field]=value;self.refused(self.call(root,indexed,policies=p))
            self.exact(self.call(root,indexed,mode='snapshot'),root,files,want,indexed,old)

    def test_invalid_joins_headers_symlinks_and_fresh_recovery(self):
        root,files,want=self.fixture(True);old=self.control(root,True);index=json.loads(files['index.json'])
        changes=[]
        for op in ('missing','extra','misassigned','size','duplicate'):
            obj=copy.deepcopy(index)
            if op=='missing':obj['weight_map']['missing']='b.safetensors'
            elif op=='extra':obj['weight_map'].pop('bf')
            elif op=='misassigned':obj['weight_map']['bf']='b.safetensors'
            elif op=='size':obj['metadata']['total_size']+=1
            else:
                (root/'duplicate.safetensors').write_bytes(files['nested/a.safetensors']);obj['weight_map']['f32']='duplicate.safetensors'
            changes.append(encode(obj))
        changes += [b'',b'null',b'{"weight_map":null}',b'{"weight_map":{"a":"b","\\u0061":"c"}}']
        for raw in changes:
            (root/'index.json').write_bytes(raw);self.refused(self.call(root));self.restore(root,files)
            self.exact(self.call(root,mode='snapshot'),root,files,want,True,old)
        for label in ('../outside','/etc/passwd','missing.safetensors','link.safetensors'):
            (root/'link.safetensors').unlink(missing_ok=True);(root/'link.safetensors').symlink_to(root/'nested/a.safetensors')
            obj=copy.deepcopy(index);obj['weight_map']['bf']=label;(root/'index.json').write_bytes(encode(obj))
            self.refused(self.call(root));self.restore(root,files)
        for label,raw in [('config.json',b'[]'),('nested/a.safetensors',b'x'),('b.safetensors',b'x')]:
            (root/label).write_bytes(raw);self.refused(self.call(root));self.restore(root,files)
        # Unsupported dtype stays explicit missing implementation.
        header={'f32':dict(dtype='I8',shape=[1],data_offsets=[0,1])};raw=encode(header)
        (root/'b.safetensors').write_bytes(struct.pack('<Q',len(raw))+raw+b'x');self.refused(self.call(root));self.restore(root,files)
        self.exact(self.call(root,mode='snapshot'),root,files,want,True,old)

    def test_before_parser_original_changes_after_actual_copy(self):
        root,files,want=self.fixture(True);old=self.control(root,True)
        for label in ('index.json','config.json','nested/a.safetensors','b.safetensors'):
            for mode in ('before_truncate','before_replace','before_same_size'):
                outputs=[]
                for repeat in range(2):
                    self.restore(root,files);env=self.fault_env(root,label,mode)
                    r=self.call(root,mode='snapshot',env=env);self.exact(r,root,files,want,True,old)
                    expected=files[label][:-1]+bytes([files[label][-1]^64]) if mode=='before_same_size' else b''
                    after={k:(root/k).read_bytes() for k in files};self.assertEqual(after,{**files,label:expected})
                    outputs.append((r.returncode,r.stdout,r.stderr,after))
                    self.mutations.append(dict(root=str(root),mode=mode,label=label,repeat=repeat,before={k:v.hex() for k,v in files.items()},after={k:v.hex() for k,v in after.items()}))
                self.assertEqual(outputs[0],outputs[1])
        self.restore(root,files)

    def fault_env(self,root,label,mode):
        return dict(os.environ,LD_PRELOAD=self.faults,AESIR_COLLECTION_FAULT=mode,AESIR_COLLECTION_LABEL=label,AESIR_COLLECTION_PATH=str(root/label),AESIR_COLLECTION_LOG=str(self.out/('fault-%04d.jsonl'%len(self.records))))

    def test_late_shard_fault_cleanup_reported_close_and_fresh_success(self):
        for indexed in (True,False):
            root,files,want=self.fixture(indexed);old=self.control(root,indexed)
            for label in ('config.json','b.safetensors' if indexed else 'nested/a.safetensors'):
                for mode in ('open','create','read_error','read_eof','write_error','write_zero','seal','missing_seals','copy_digest','parser_digest','source_close','close_after','short','map' if label.endswith('safetensors') else 'metadata_error'):
                    env=self.fault_env(root,label,mode);r=self.call(root,indexed,mode='snapshot',env=env)
                    if mode=='short':self.exact(r,root,files,want,indexed,old)
                    elif mode=='close_after' and label.endswith('safetensors'):
                        # Existing Safetensors close is intentionally nonraising.
                        self.exact(r,root,files,want,indexed,old)
                    else:self.refused(r)
                    log=Path(env['AESIR_COLLECTION_LOG']);self.assertTrue(log.read_text())
                    self.exact(self.call(root,indexed,mode='snapshot'),root,files,want,indexed,old)


if __name__=='__main__':
    p=argparse.ArgumentParser()
    for name in ('binary','api','indexed-control','unindexed-control','faults','strace','evidence'):p.add_argument('--'+name,required=True)
    CONFIG,rest=p.parse_known_args();unittest.main(argv=[sys.argv[0],*rest])
