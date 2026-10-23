#!/usr/bin/env python3
"""Full retained source-bit comparison, independently checked without a forward."""
import argparse,hashlib,json,math,os,struct,subprocess,unittest
from collections import Counter
from pathlib import Path
import test_hailo_owned_ordinary_binding as binding
CONFIG=argparse.Namespace()

class OrdinaryTensorIdentity(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out=Path(CONFIG.evidence).resolve();cls.out.mkdir(parents=True,exist_ok=False)
        cls.runs=[];cls.fixtures=[];cls.faults=[];cls.mutations=[];cls.counts=Counter();cls.sequence=0
    @classmethod
    def tearDownClass(cls):
        for name in ('runs','fixtures','faults','mutations'):(cls.out/(name+'.json')).write_text(json.dumps(getattr(cls,name),indent=2)+'\n')
        (cls.out/'summary.json').write_text(json.dumps(dict(calls=len(cls.runs),comparisons=dict(cls.counts),outcomes=dict(Counter('accepted' if r['returncode']==0 else 'refused' for r in cls.runs))),indent=2)+'\n')
    def fixture(self,indexed,dtype='F16',mismatch=(),head_dtype=None):
        type(self).sequence+=1;root=self.out/('model-%04d'%self.sequence);root.mkdir()
        cfg,roles=binding.declared(layers=1,hidden=4,heads=2,kv=1,dimension=2,explicit=True,tie=True,output=True)
        cfg.update(rms_norm_eps=1e-6,rope_theta=10000,hidden_act='silu',no_rope_layers=[1])
        width=4 if dtype=='F32' else 2;elements=40
        special=[0,1,1<<(width*8-1),(1<<(width*8))-1,0x7e01 if width==2 else 0x7fc00001,0x7e02 if width==2 else 0x7fc00002]
        raw=b''.join((special[i%len(special)]).to_bytes(width,'little') for i in range(elements))
        head=bytearray(raw)
        for byte in mismatch:head[byte]^=1
        groups=[[],[]] if indexed else [[]];weight_map={};views={};files={}
        for i,(name,(canonical,shape)) in enumerate(roles.items()):
            kind=head_dtype if name=='lm_head.weight' and head_dtype else dtype;w=4 if kind=='F32' else 2
            payload=bytes(head) if name=='lm_head.weight' and not head_dtype else raw if name=='model.embed_tokens.weight' else bytes((j*13+i)&255 for j in range(math.prod(shape)*w))
            if name=='lm_head.weight' and head_dtype:payload=bytes(math.prod(shape)*w)
            words=[int.from_bytes(payload[j:j+w],'little') for j in range(0,len(payload),w)]
            group=1 if indexed and name=='lm_head.weight' else 0;groups[group].append((name,kind,shape,words));weight_map[name]='source-%d.weights'%group
            views[canonical]=dict(source_format='safetensors',source_kind=('F16','BF16','F32').index(kind),original_name=name,source_path=str(root/weight_map[name]),source_shape=shape,axis_order='row_major_outermost_first',elements=math.prod(shape),byte_count=len(payload),payload_hex=payload.hex())
        for i,tensors in enumerate(groups):
            data,want=binding.source(tensors,8192 if indexed else 0);label='source-%d.weights'%i;files[label]=data;offset=8+struct.unpack_from('<Q',data)[0]
            for t in views.values():
                if Path(t['source_path']).name==label:t['file_offset']=offset+want[t['original_name']]['relative']
        files['config.json']=json.dumps(cfg,ensure_ascii=False,separators=(',',':')).encode()
        if indexed:files['index.json']=json.dumps(dict(weight_map=weight_map,metadata=dict(total_size=sum(t['byte_count'] for t in views.values()))),separators=(',',':')).encode()
        for label,data in files.items():(root/label).write_bytes(data)
        self.fixtures.append(dict(root=str(root),indexed=indexed,files={k:v.hex() for k,v in files.items()},views=views))
        return root,files,views,indexed
    def child(self,args,env=None):
        n=len(self.runs);trace=self.out/('trace-%04d.strace'%n);cmd=['/usr/bin/strace','-f','-yy','-s','512','-o',str(trace),'-e','trace=%file,%desc,%memory,%network,%process',*map(str,args)]
        r=subprocess.run(cmd,capture_output=True,text=True,timeout=120,stdin=subprocess.DEVNULL,env=env)
        for name in ('stdout','stderr'):(self.out/('call-%04d.'%n+name)).write_text(getattr(r,name))
        self.runs.append(dict(arguments=cmd,returncode=r.returncode,trace=str(trace),stdout=r.stdout,stderr=r.stderr,environment={k:v for k,v in (env or {}).items() if k.startswith('AESIR_') or k=='LD_PRELOAD'}));return r
    def call(self,f,mode='snapshot',left='token_embd.weight',right='output.weight',bound=100000,chunk=7,tool=False,env=None):
        root,files,views,indexed=f;args=binding.OwnedOrdinaryBinding.args(self,root,indexed)
        return self.child([CONFIG.binary,'indexed' if indexed else 'unindexed',*args,left,right,bound,chunk] if tool else [CONFIG.api,'indexed' if indexed else 'unindexed',mode,*args,left,right,bound,chunk],env)
    def exact(self,r,f,left='token_embd.weight',right='output.weight',chunk=7):
        self.assertEqual((r.returncode,r.stderr),(0,''));obj=json.loads(r.stdout);a=f[2][left];b=f[2][right]
        for key,want in [('left',a),('right',b)]:self.assertEqual(obj[key],{k:v for k,v in want.items() if k!='payload_hex'})
        self.assertEqual((obj['left_name'],obj['right_name']),(left,right));width=4 if a['source_kind']==2 else 2;raw_a=bytes.fromhex(a['payload_hex']);raw_b=bytes.fromhex(b['payload_hex']);diff=[i for i in range(a['elements']) if raw_a[i*width:(i+1)*width]!=raw_b[i*width:(i+1)*width]]
        self.assertEqual(obj['elements_per_operand'],a['elements']);self.assertEqual(obj['bytes_per_operand'],len(raw_a));self.assertEqual(obj['raw_elements_read'],2*a['elements']);self.assertEqual(obj['chunks'],(a['elements']+chunk-1)//chunk);self.assertEqual(obj['differing_elements'],len(diff));self.assertEqual(obj['first_differing_element'],diff[0] if diff else -1);self.assertEqual(obj['all_elements_equal'],not diff)
        for flag in ('graph_alias_resolved','compiled_artifact_identity_verified','execution_tested','device_access'):self.assertIs(obj[flag],False)
        self.counts['complete_comparisons']+=1;self.counts['independent_source_bytes']+=len(raw_a)+len(raw_b);return obj
    def refused(self,r):
        self.assertNotEqual(r.returncode,0);self.assertEqual(r.stdout,'');self.assertIn('Unhandled exception caught during execution:',r.stderr);self.counts['refusals']+=1
    def restore(self,f):
        for p in f[0].iterdir():p.unlink()
        for name,data in f[1].items():(f[0]/name).write_bytes(data)
    def tree(self,f):return {p.name:p.read_bytes().hex() for p in sorted(f[0].iterdir())}
    def test_01_representations_chunks_and_complete_mismatches(self):
        for indexed in (False,True):
            for dtype in ('F16','BF16','F32'):
                f=self.fixture(indexed,dtype);n=f[2]['output.weight']['elements'];width=4 if dtype=='F32' else 2
                for chunk in (1,3,7,n-1,n,n+1,9223372036854775807):self.exact(self.call(f,chunk=chunk,bound=2*n),f,chunk=chunk)
                self.exact(self.call(f,tool=True),f)
                self.exact(self.call(f,right='token_embd.weight'),f,right='token_embd.weight')
                for positions in ((0,),(width*(n//2),),(width*n-1,),(0,width*(n//2),width*n-1)):
                    g=self.fixture(indexed,dtype,positions);self.exact(self.call(g),g)
    def test_02_every_actual_output_payload_byte(self):
        for indexed in (False,True):
            for dtype in ('F16','BF16','F32'):
                f=self.fixture(indexed,dtype);t=f[2]['output.weight'];label=Path(t['source_path']).name;start=t['file_offset'];original=bytes.fromhex(t['payload_hex'])
                for byte in range(len(original)):
                    data=bytearray(f[1][label]);data[start+byte]^=1;(f[0]/label).write_bytes(data);payload=bytearray(original);payload[byte]^=1;t['payload_hex']=payload.hex();self.exact(self.call(f),f);self.counts['individual_byte_mutations']+=1
                t['payload_hex']=original.hex();self.restore(f);self.exact(self.call(f),f)
    def test_03_bounds_layout_missing_and_same_shape_roles(self):
        for indexed in (False,True):
            f=self.fixture(indexed)
            for bound,chunk in ((0,1),(-1,1),(79,7),(1,7),(80,0),(80,-1)):self.refused(self.call(f,bound=bound,chunk=chunk))
            for left,right in (('missing','output.weight'),('token_embd.weight','missing雪'),('token_embd.weight','output_norm.weight')):self.refused(self.call(f,left=left,right=right))
            self.refused(self.call(f,'nul_name'))
            self.exact(self.call(f,left='output_norm.weight',right='blk.0.attn_norm.weight'),f,left='output_norm.weight',right='blk.0.attn_norm.weight')
            for dtype in ('F16','BF16','F32'):
                g=self.fixture(indexed,dtype,head_dtype='BF16' if dtype!='BF16' else 'F32');self.refused(self.call(g))
            self.exact(self.call(f),f)
    def test_04_policy_schema_owner_cache_move_and_close(self):
        for indexed in (False,True):
            # Bias descriptor mutations use a source fixture with actual biases.
            f=binding.OwnedOrdinaryBinding.fixture(self,indexed,0);root,files,windows,cfg,expected=f
            views={k:{**{x:v for x,v in t.items() if x not in ('rows','columns')},'payload_hex':files[Path(t['source_path']).name][t['file_offset']:t['file_offset']+t['byte_count']].hex()} for k,t in expected['bindings'].items()};f=(root,files,views,indexed)
            for scope,fields in [('schema:',binding.SCHEMA),('policy:',binding.POLICY),('external:',binding.POLICY)]:
                for field in fields:self.refused(self.call(f,scope+field,right='token_embd.weight'))
            for field in ('closed','owner_extent','file_size','route','namespace'):
                self.refused(self.call(f,'shard:'+field,right='token_embd.weight'))
            if indexed:self.refused(self.call(f,'shard:label',right='token_embd.weight'))
            for mode in ('cache','move','snapshot'):self.exact(self.call(f,mode,right='token_embd.weight'),f,right='token_embd.weight')
            self.refused(self.call(f,'closed',right='token_embd.weight'));self.exact(self.call(f,right='token_embd.weight'),f,right='token_embd.weight')
    def test_05_original_mutation_pairs_keep_complete_observed_bytes(self):
        for indexed in (False,True):
            f=self.fixture(indexed)
            for action in ('same_size','truncate','rename','replace'):
                outputs=[];after=[]
                for repeat in range(2):
                    self.restore(f);before=self.tree(f);r=self.call(f,'original:'+action);self.exact(r,f);post=self.tree(f);self.assertNotEqual(before,post);outputs.append((r.returncode,r.stdout,r.stderr));after.append(post);self.mutations.append(dict(root=str(f[0]),action=action,repeat=repeat,before=before,after=post));self.restore(f);self.assertEqual(self.tree(f),before)
                self.assertEqual(outputs[0],outputs[1]);self.assertEqual(after[0],after[1]);self.counts['complete_original_mutation_pairs']+=1
            self.exact(self.call(f),f)
    def test_06_reported_fault_pairs_and_fresh_recovery(self):
        for indexed in (False,True):
            f=self.fixture(indexed)
            cases=[('config.json','error',6),('config.json','eof',6),('config.json','bad_json',7),('config.json','close_after',0),('source-0.weights','error',4),('source-0.weights','eof',4)]
            if indexed:cases.extend([('index.json','error',6),('index.json','bad_json',7),('index.json','close_after',0)])
            for label,mode,phase in cases:
                values=[];logs=[]
                for repeat in range(2):
                    log=self.out/('fault-%04d.jsonl'%len(self.faults));env=dict(os.environ,LD_PRELOAD=str(Path(CONFIG.faults).resolve()),AESIR_BINDING_LABEL=label,AESIR_BINDING_FAULT=mode,AESIR_BINDING_PHASE=str(phase),AESIR_BINDING_LOG=str(log));r=self.call(f,env=env);self.refused(r);data=log.read_bytes();self.assertIn(mode,data.decode());values.append((r.returncode,r.stdout,r.stderr));logs.append(data);self.faults.append(dict(label=label,mode=mode,phase=phase,repeat=repeat,path=str(log),hex=data.hex()))
                self.assertEqual(values[0],values[1]);self.assertEqual(logs[0],logs[1]);self.counts['complete_fault_pairs']+=1;self.exact(self.call(f),f)
    def test_07_actual_seal_copy_mapping_faults_and_short_reads(self):
        for indexed in (False,True):
            f=self.fixture(indexed)
            for mode in ('create','read_error','read_eof','write_error','write_zero','seal','missing_seals','map','copy_digest','parser_digest','source_close','short'):
                values=[];logs=[]
                for repeat in range(2):
                    log=self.out/('collection-fault-%04d.jsonl'%len(self.faults));env=dict(os.environ,LD_PRELOAD=str(Path(CONFIG.faults).resolve().with_name('sealed_collection_faults.so')),AESIR_COLLECTION_LABEL='source-0.weights',AESIR_COLLECTION_FAULT=mode,AESIR_COLLECTION_LOG=str(log));r=self.call(f,env=env)
                    if mode=='short':self.exact(r,f)
                    else:self.refused(r)
                    data=log.read_bytes();self.assertTrue(data);values.append((r.returncode,r.stdout,r.stderr));logs.append(data);self.faults.append(dict(label='source-0.weights',mode=mode,repeat=repeat,path=str(log),hex=data.hex(),family='collection'))
                self.assertEqual(values[0],values[1]);self.assertEqual(logs[0],logs[1]);self.counts['complete_fault_pairs']+=1;self.exact(self.call(f),f)

if __name__=='__main__':
    p=argparse.ArgumentParser()
    for name in ('binary','api','faults','evidence'):p.add_argument('--'+name,required=True)
    CONFIG,rest=p.parse_known_args();unittest.main(argv=[__file__,*rest],verbosity=2)
