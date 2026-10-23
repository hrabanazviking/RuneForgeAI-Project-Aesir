#!/usr/bin/env python3
"""Retained source/IR lifetime and static-component selection; no host forward."""
import argparse,copy,hashlib,json,math,os,random,struct,subprocess,unittest
from collections import Counter
from pathlib import Path
import test_hailo_owned_ordinary_binding as binding
import test_hailo_ordinary_projection_schema as schema
from test_hailo_sealed_source_collection import source
CONFIG=argparse.Namespace()
PROVENANCE='selected ordinary mathematical source intent'
ROTARY_PROVENANCE='explicit mathematical activation inspector basis'
REQUEST=[2,0,8,2,'full_prefix',-1,1000000,1000000,PROVENANCE,'split_half',ROTARY_PROVENANCE,10000,10000000]

def canonical(obj):
    if isinstance(obj,list):return [canonical(v) for v in obj]
    if not isinstance(obj,dict):return obj
    # The frozen inspector has fixed graph/scalar provenance strings. Check every
    # actual new provenance and charge independently, then compare all other IR.
    return {k:('<explicit-provenance>' if k=='provenance' else '<checked-charge>' if k=='charged_work' and 'epsilon' in obj and 'rope_base' in obj else canonical(v)) for k,v in obj.items()}

class OwnedOrdinaryCompiler(unittest.TestCase):
    fixture=binding.OwnedOrdinaryBinding.fixture
    args=binding.OwnedOrdinaryBinding.args
    restore=binding.OwnedOrdinaryBinding.restore
    refused=binding.OwnedOrdinaryBinding.refused
    @classmethod
    def setUpClass(cls):
        cls.out=Path(CONFIG.evidence).resolve();cls.out.mkdir(exist_ok=False,parents=True)
        cls.runs=[];cls.fixtures=[];cls.mutations=[];cls.faults=[];cls.counts=Counter();cls.sequence=0
    @classmethod
    def tearDownClass(cls):
        for name in ('runs','fixtures','mutations','faults'):(cls.out/(name+'.json')).write_text(json.dumps(getattr(cls,name),indent=2)+'\n')
        (cls.out/'summary.json').write_text(json.dumps(dict(calls=len(cls.runs),outcomes=dict(Counter('accepted' if r['returncode']==0 else 'refused' for r in cls.runs)),comparisons=dict(cls.counts)),indent=2)+'\n')
    def child(self,args,root=None,trace=False,env=None):
        cmd=list(map(str,args));path=None
        if trace:
            path=self.out/('trace-%04d.strace'%len(self.runs));cmd=[CONFIG.strace,'-f','-yy','-s','4096','-o',str(path),'-e','trace=%file,%desc,%memory,%network,%process',*cmd]
        r=subprocess.run(cmd,capture_output=True,text=True,timeout=120,stdin=subprocess.DEVNULL,env=env)
        n=len(self.runs);outputs={}
        for name in ('stdout','stderr'):
            data=getattr(r,name).encode();p=self.out/(f'call-{n:04d}.'+name);p.write_bytes(data);outputs[name]=dict(path=str(p),bytes=len(data),sha256=hashlib.sha256(data).hexdigest())
        self.runs.append(dict(arguments=cmd,returncode=r.returncode,root=str(root) if root else None,trace=str(path) if path else None,outputs=outputs,fault_environment={k:v for k,v in (env or {}).items() if k.startswith('AESIR_') or k=='LD_PRELOAD'}));return r
    def call(self,f,indexed,mode='snapshot',request=None,operation=0,first=0,count=1,cap=131072,trace=False,tool=False,env=None,compiler=None):
        req=request or REQUEST
        cmd=[CONFIG.binary,'indexed' if indexed else 'unindexed',*self.args(f[0],indexed,compiler),*req] if tool else [CONFIG.api,'indexed' if indexed else 'unindexed',mode,*self.args(f[0],indexed,compiler),*req,operation,first,count,cap]
        return self.child(cmd,f[0],trace,env)
    def config(self,f,**changes):
        root,files,windows,cfg,expected=f;cfg.update(changes);files['config.json']=json.dumps(cfg,ensure_ascii=False,separators=(',',':')).encode();(root/'config.json').write_bytes(files['config.json'])
        next(item for item in self.fixtures if item['root']==str(root)).setdefault('configurations',[]).append(dict(hex=files['config.json'].hex(),sha256=hashlib.sha256(files['config.json']).hexdigest()))
        return f
    def reference(self,f,indexed,req,accepted=True):
        cfg=f[3];layers=cfg['num_hidden_layers'];flags=cfg.get('no_rope_layers',[int((i+1)%cfg.get('no_rope_layer_interval',4)!=0) for i in range(layers)])
        # Source no_rope_layers stores enabled flags in the qualified interpreter.
        masks=','.join(map(str,flags));a=','.join([str(int(cfg['attention_bias']))]*layers);m=','.join([str(int(cfg['mlp_bias']))]*layers)
        r=self.child([CONFIG.graph,'indexed' if indexed else 'unindexed',f[0],'index.json' if indexed else 'source-0.weights','config.json',*req[:4],masks,a,m,'source64',req[9],req[6],req[8],'source',req[4],req[5],'source','source',64,0],f[0])
        if not accepted:return r
        self.assertEqual(r.returncode,0,r.stderr);return json.loads(r.stdout)
    def exact(self,r,f,indexed,req=REQUEST,reference=True):
        self.assertEqual(r.returncode,0,r.stderr);self.assertEqual(r.stderr,'');lines=r.stdout.splitlines();obj=json.loads(lines[0]);cfg=f[3];expected=f[4]
        schema.OrdinaryProjectionSchema.check(self,obj['schema'],cfg,expected,cfg['head_dim'])
        self.assertEqual(obj['collection']['source_bytes'],sum(map(len,f[1].values())))
        self.assertEqual(obj['collection']['config_digest_hex'],hashlib.sha256(f[1]['config.json']).hexdigest())
        if indexed:self.assertEqual(obj['collection']['index_digest_hex'],hashlib.sha256(f[1]['index.json']).hexdigest())
        for sh in obj['collection']['shards'] if indexed else [obj['collection']['source']]:self.assertEqual(sh['digest_hex'],hashlib.sha256(f[1][Path(sh['storage']['source_path']).name]).hexdigest())
        full=obj['lowered'];sg=full['source_graph'];sc=sg['source_scalars']
        for key,raw in [('epsilon',cfg.get('rms_norm_eps',1e-6)),('rope_base',cfg.get('rope_theta',2000000.0))]:self.assertEqual(sc[key],dict(width=64,bits=struct.unpack('<Q',struct.pack('<d',raw))[0]))
        self.assertEqual(sc['provenance'],req[8]);self.assertEqual(sc['work_limit'],req[7]);self.assertEqual(sc['charged_work'],2+len(req[8].encode()))
        for name in ('bias_policy','activation_policy','session_policy','window_policy','scaling_policy'):self.assertEqual(sg[name]['provenance'],req[8])
        self.assertEqual(full['policy']['pairing'],req[9]);self.assertEqual(full['policy']['provenance'],req[10]);self.assertEqual(full['policy']['max_recipes'],req[11]);self.assertEqual(full['policy']['work'],req[12])
        if reference:
            old=self.reference(f,indexed,req);sr=self.child([CONFIG.schema,'indexed' if indexed else 'unindexed',f[0],'index.json' if indexed else 'source-0.weights','config.json',8,10000,64,10000000,10000000,binding.PROVENANCE],f[0]);self.assertEqual(sr.returncode,0,sr.stderr);self.assertEqual(obj['schema'],json.loads(sr.stdout));self.assertEqual(canonical(full),canonical(old['lowered']));self.counts['complete_frozen_graph_comparisons']+=1
        # Independent structural topology/lifetime checks; these evaluate no layer.
        for owner,values,operations,result in [(sg,'tensors','operations','logits'),(full['expanded'],'values','operations','result')]:
            vs=owner[values];ops=owner[operations]
            for i,v in enumerate(vs):
                self.assertEqual(v['id'],i);self.assertEqual(v['elements'],math.prod(v['shape']))
                for op in ops:
                    if i in op['inputs']:self.assertGreaterEqual(v['last_use'],op['id'])
            for i,op in enumerate(ops):
                self.assertEqual(op['id'],i);self.assertTrue(0<=op['output']<len(vs));self.assertEqual(vs[op['output']]['producer'],i)
                for j in op['inputs']:self.assertTrue(0<=j<len(vs))
        self.counts['complete_source_and_structural_oracles']+=1
        for k,v in obj.items():
            if k.endswith('_verified') or k in ('execution_tested','device_access'):self.assertIs(v,False,k)
        if len(lines)==3:
            for view in json.loads(lines[1]):self.window(view['window'],f,view['canonical']);self.counts['operation_component_windows']+=1
            selected=json.loads(lines[2]);canonical_name=sg['operations'][0]['weight']
            self.window(selected,f,canonical_name);self.counts['selected_windows']+=1
        return obj
    def window(self,w,f,name):
        b=f[4]['bindings'][name];want=f[2][Path(b['source_path']).name][b['original_name']];lo=w['first'];hi=lo+w['count']
        for key in ('raw_words','binary32_words'):self.assertEqual(w[key],want[key][lo:hi]);self.counts['exact_static_component_words']+=len(w[key])
        self.assertEqual(w['dtype'],want['dtype']);self.assertEqual(w['byte_count'],want['byte_count']);self.assertEqual(w['file_offset'],b['file_offset']);self.assertEqual(w['shape'],b['source_shape']);self.assertEqual(w['source_bytes'],len(f[1][Path(b['source_path']).name]))
    def test_01_source_graph_factories_and_windows(self):
        for indexed in (True,False):
            for seed in range(6):
                f=self.fixture(indexed,seed)
                if f[3]['tie_word_embeddings'] and 'output.weight' in f[4]['bindings']:
                    actual=self.call(f,indexed,'all',trace=True);old=self.reference(f,indexed,REQUEST,accepted=False)
                    self.refused(actual);self.refused(old);self.assertEqual((actual.returncode,actual.stdout,actual.stderr),(old.returncode,old.stdout,old.stderr));self.counts['duplicate_tied_output_required_work_refusals']+=1
                    self.refused(self.call(f,indexed,tool=True,trace=True));continue
                self.exact(self.call(f,indexed,'all',trace=seed==0),f,indexed);self.exact(self.call(f,indexed,tool=True,trace=seed==0),f,indexed)
                elements=f[4]['bindings']['token_embd.weight']['elements']
                for first,count in [(1,3),(elements-1,1),(elements,0),(0,0)]:self.exact(self.call(f,indexed,first=first,count=count),f,indexed,reference=False)
    def test_02_source_modifiers_geometry_and_sessions(self):
        for indexed in (True,False):
            for seed,activation in enumerate(('silu','gelu','relu')):
                f=self.fixture(indexed,(3,4,6)[seed]);layers=f[3]['num_hidden_layers'];self.config(f,rms_norm_eps=0.0000010000000000000002,rope_theta=10000.000000000002,hidden_act=activation,no_rope_layers=[i%2 for i in range(layers)],sliding_window=3,layer_types=['sliding_attention' if i%2 else 'full_attention' for i in range(layers)])
                for pairing in ('adjacent','split_half'):
                    for session,past,returned in [('full_prefix',0,0),('cached_append',2,1)]:
                        req=REQUEST.copy();req[1]=past;req[4]=session;req[5]=returned;req[9]=pairing
                        self.exact(self.call(f,indexed,request=req,trace=True),f,indexed,req)
            for raw in (None,{'rope_type':'default'},{'type':'linear','factor':0.5}):
                f=self.fixture(indexed,0);self.config(f,rope_scaling=raw,use_cache=False);self.exact(self.call(f,indexed,trace=True),f,indexed)
    def test_03_every_consumed_request_and_plan_field(self):
        mutations=json.loads(Path(CONFIG.mutations).read_text())
        for indexed in (True,False):
            f=self.fixture(indexed,0)
            for scope in ('request:','supplied:'):
                for field in mutations['requests']:self.refused(self.call(f,indexed,scope+field,trace=True))
            for field in mutations['plans']:self.refused(self.call(f,indexed,'plan:'+field,trace=True))
            self.exact(self.call(f,indexed,'recover',trace=True),f,indexed)
    def test_04_source_policy_cache_and_ownership(self):
        for indexed in (True,False):
            f=self.fixture(indexed,0)
            for mode in ('pre_cache','post_cache','move','recover'):self.exact(self.call(f,indexed,mode,trace=True),f,indexed)
            for scope in ('pre_schema:','schema:'):
                for field in binding.SCHEMA:self.refused(self.call(f,indexed,scope+field,trace=True))
            for scope in ('policy:','external:'):
                for field in binding.POLICY:self.refused(self.call(f,indexed,scope+field,trace=True))
            for scope in ('pre_shard:','post_shard:'):
                for field in ('closed','owner_extent','file_size','route','label','namespace'):
                    r=self.call(f,indexed,scope+field,trace=True)
                    if not indexed and field=='label':self.exact(r,f,indexed)
                    else:self.refused(r)
            self.refused(self.call(f,indexed,'closed',trace=True));self.exact(self.call(f,indexed,trace=True),f,indexed)
    def test_05_original_mutations_and_recovery(self):
        def tree(root):
            return {str(p.relative_to(root)):dict(kind='directory') if p.is_dir() else dict(kind='file',hex=p.read_bytes().hex(),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in sorted(root.rglob('*'))}
        for indexed in (True,False):
            for prefix in ('before:','after:'):
                for action in ('same_size','truncate','rename','replace'):
                    f=self.fixture(indexed,0);values=[];images=[]
                    for repeat in range(2):
                        self.restore(f);before=tree(f[0]);r=self.call(f,indexed,prefix+action,trace=True);after=tree(f[0])
                        self.exact(r,f,indexed,reference=False);self.assertNotEqual(before,after)
                        self.mutations.append(dict(root=str(f[0]),mode=prefix+action,indexed=indexed,repeat=repeat,complete_before=before,complete_after=after,returncode=r.returncode))
                        values.append((r.returncode,r.stdout,r.stderr));images.append(after);self.restore(f);self.assertEqual(tree(f[0]),before)
                    self.assertEqual(values[0],values[1]);self.assertEqual(images[0],images[1]);self.counts['independent_original_mutation_pairs']+=1
                    self.exact(self.call(f,indexed),f,indexed)
    def test_06_bounds_and_required_semantic_work(self):
        for indexed in (True,False):
            f=self.fixture(indexed,0)
            for pos,value in [(0,0),(0,9223372036854775807),(1,-1),(2,0),(3,1),(3,100),(4,'future'),(5,2),(6,0),(6,127),(7,2),(8,''),(9,'future'),(10,''),(11,0),(11,1),(12,1)]:
                req=REQUEST.copy();req[pos]=value;self.refused(self.call(f,indexed,request=req,trace=True))
            for op,first,count,cap in [(-1,0,1,1),(99999,0,1,1),(0,-1,1,1),(0,0,-1,1),(0,0,9223372036854775807,1),(0,0,2,1),(0,999999,0,1)]:self.refused(self.call(f,indexed,operation=op,first=first,count=count,cap=cap,trace=True))
            for changes in ({'hidden_act':'future'},{'rope_scaling':{'rope_type':'dynamic','factor':2}},{'layer_types':['future']},{'sliding_window':3,'layer_types':['sliding_attention'],'rope_scaling':{'rope_type':'unknown'}}):
                g=self.fixture(indexed,0);self.config(g,**changes);self.refused(self.call(g,indexed,trace=True))
            self.exact(self.call(f,indexed,trace=True),f,indexed)

    def test_07_reported_faults_independent_logs_and_fresh_recovery(self):
        for indexed in (True,False):
            f=self.fixture(indexed,0)
            cases=[('config.json','error',6),('config.json','eof',8),('config.json','bad_json',7),('config.json','close_after',0),('source-0.weights','error',4),('source-0.weights','eof',5)]
            if indexed:cases.extend([('index.json','error',6),('index.json','bad_json',7),('index.json','close_after',0)])
            for label,mode,phase in cases:
                values=[];logs=[]
                for repeat in range(2):
                    log=self.out/('fault-%04d.jsonl'%len(self.faults));env=dict(os.environ,LD_PRELOAD=str(Path(CONFIG.faults).resolve()),AESIR_BINDING_LABEL=label,AESIR_BINDING_FAULT=mode,AESIR_BINDING_PHASE=str(phase),AESIR_BINDING_LOG=str(log))
                    r=self.call(f,indexed,env=env,trace=True);self.refused(r);raw=log.read_bytes();self.assertIn(mode,raw.decode());logs.append(raw);values.append((r.returncode,r.stdout,r.stderr));self.faults.append(dict(label=label,mode=mode,phase=phase,repeat=repeat,log=str(log),hex=raw.hex()))
                self.assertEqual(values[0],values[1]);self.assertEqual(logs[0],logs[1]);self.counts['independent_complete_fault_pairs']+=1
                self.exact(self.call(f,indexed,trace=True),f,indexed)

    def test_08_existing_scaling_api_complete_frozen_controls(self):
        f=self.fixture(False,1)
        for case in ('valid','plan_factor','global_factor','recipe_factor','layout'):
            r=self.child([CONFIG.graph_api,f[0],'source-0.weights','config.json','source64','full_prefix',1,0,8,'3,1',case],f[0],trace=True)
            if case in ('valid','layout'):self.assertEqual(r.returncode,0,r.stderr)
            else:self.refused(r)

    def test_09_source_bias_flags_without_bias_payloads(self):
        saved=binding.declared
        for indexed in (True,False):
            for attention,mlp in ((False,False),(True,False),(False,True)):
                def declared(**kwargs):
                    kwargs.update(attention=attention,mlp=mlp)
                    return saved(**kwargs)
                try:
                    binding.declared=declared
                    f=self.fixture(indexed,1)
                finally:
                    binding.declared=saved
                self.exact(self.call(f,indexed,'all',trace=True),f,indexed)
    def test_10_actual_hash_page_limits_and_nonstatic_operations(self):
        for indexed in (True,False):
            f=self.fixture(indexed,1,pad=8192);policy=binding.COMPILER.copy()
            policy[-2]=sum(map(len,f[1].values()));policy[-1]=max((len(v)+4095)//4096 for v in f[1].values())
            obj=self.exact(self.call(f,indexed,compiler=policy,trace=True),f,indexed)
            for pos in (-2,-1):
                short=policy.copy();short[pos]-=1;self.refused(self.call(f,indexed,compiler=short,trace=True))
            operation=next(op['id'] for op in obj['lowered']['source_graph']['operations'] if not op['weight'])
            self.refused(self.call(f,indexed,operation=operation,trace=True))
            self.exact(self.call(f,indexed,trace=True),f,indexed)

if __name__=='__main__':
    p=argparse.ArgumentParser()
    for n in ('binary','api','graph','graph-api','schema','faults','strace','mutations','evidence'):p.add_argument('--'+n,required=True)
    CONFIG,other=p.parse_known_args();unittest.main(argv=[__file__,*other])
