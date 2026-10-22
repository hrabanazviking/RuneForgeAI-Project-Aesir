#!/usr/bin/env python3
"""Independent compiler graph/index/storage oracles. Never model data evaluation."""
import argparse,copy,hashlib,itertools,json,math,struct,subprocess,unittest
from pathlib import Path
import test_hailo_decoder_projections as old
from test_hailo_ordinary_projection_schema import declared
from test_hailo_semantic_plan import dense_fixture
C=argparse.Namespace()
BITS=lambda x,w=64:struct.unpack('<Q' if w==64 else '<I',struct.pack('<d' if w==64 else '<f',x))[0]

class DynamicGraph(unittest.TestCase):
    setUpClass=classmethod(old.DecoderProjections.setUpClass.__func__)
    @classmethod
    def tearDownClass(cls):
        import shutil
        inputs={}
        for path in cls.root.rglob("*"):
            if path.is_file():inputs[str(path)]=hashlib.sha256(path.read_bytes()).hexdigest()
        copies={p:str(cls.evidence/'fixtures'/Path(p).relative_to(cls.root)) for p in inputs}
        (cls.evidence/'fixture-copies.json').write_text(json.dumps(copies,indent=2)+'\n')
        shutil.copytree(cls.root,cls.evidence/'fixtures')
        (cls.evidence/'fixture-identities.json').write_text(json.dumps(inputs,indent=2)+'\n')
        old.DecoderProjections.tearDownClass.__func__(cls)
    def child(self,command,trace=None):
        command=list(map(str,command))
        if trace:command=[C.strace,'-yy','-o',str(self.evidence/trace),'-e','trace=openat,openat2,close,mmap,munmap,pread64,read,ioctl,connect,write',*command]
        r=subprocess.run(command,capture_output=True,text=True,timeout=60,stdin=subprocess.DEVNULL)
        self.records.append(dict(arguments=command,returncode=r.returncode,stdout_sha256=hashlib.sha256(r.stdout.encode()).hexdigest(),stdout_bytes=len(r.stdout.encode()),stderr=r.stderr))
        return r
    accept=old.DecoderProjections.accept
    def collection(self,config,roles,shards=1,dtypes=("BF16",)):
        root,expected=old.DecoderProjections.collection(self,config,roles,shards,dtypes)
        return root,expected
    def refuse(self,r):
        self.assertGreater(r.returncode,0,r.stdout+r.stderr)
        self.assertEqual(r.stdout,'')
        self.assertIn('Unhandled exception caught during execution:',r.stderr)

    def fixture(self,shards=1,source=True,legacy=False):
        config,roles=declared(dimension=4,explicit=True,attention=True,mlp=True)
        config.update(max_position_embeddings=8,rope_theta=12345.6789012345,rms_norm_eps=0.000013,hidden_act='silu')
        if source:config['rope_scaling']={'type' if legacy else 'rope_type':'dynamic','factor':1.5,'original_max_position_embeddings':4,'custom':{'raw':'æ\0𝄞'},'training':[1,2]}
        root,expected=self.collection(config,roles,shards=shards,dtypes=('BF16','F16','F32'))
        return root,expected

    def invoke(self,root,shards=1,query=2,past=0,cap=32,limit=128,initial=32,ends='-',contexts='-',mode='full_prefix',returned=1,scalar='source64',origin='source',width=64,factor=1.5,mask='1,0',dim=2,pairing='split_half',windows='3,1',work=1000000,trace=None):
        return self.child([self.binary,'unindexed' if shards==1 else 'indexed',root,'source-0.weights' if shards==1 else 'index.json','config.json',query,past,cap,dim,mask,'1,1','1,1',scalar,pairing,work,'dynamic graph æ𝄞','gelu_erf,relu',mode,returned,windows,origin,width,BITS(factor,width),limit,initial,ends,contexts],trace)

    def check(self,obj,initial=32,ends=(),contexts=(),factor=1.5,width=64,reference=8):
        full=obj.get('lowered',obj);sg=full['source_graph'];rs=full['recipes'];eg=full['expanded'];p=sg['parameters'];q=p['query_tokens'];past=p['past_tokens'];n=len(sg['operations'])
        selected=initial
        for end,want in zip(ends,contexts):
            selected=reference if end<reference else max(selected,end)
            self.assertEqual(selected,want)
        selected=reference if past+q<reference else max(selected,past+q)
        state=sg['dynamic_state'];word={'width':width,'bits':BITS(factor,width)}
        for owner in (sg,rs,eg):
            self.assertEqual(owner['schema_version'],8);self.assertEqual(owner['dynamic_state'],state)
        self.assertEqual(state['source_context'],reference)
        self.assertEqual(state['before']['end_tokens'],list(ends));self.assertEqual(state['before']['selected_contexts'],list(contexts))
        self.assertEqual(state['after']['end_tokens'],[*ends,past+q]);self.assertEqual(state['after']['selected_contexts'],[*contexts,selected])
        self.assertEqual(state['context_output'],dict(reference=reference,selected=selected,limit=state['after']['policy']['limit']))
        self.assertEqual(state['after']['policy']['factor'],word)
        if 'original_source' in obj:
            theta_width=64 if 'source_scalars' in sg else 32
            self.assertEqual(state['after']['policy']['theta'],dict(width=theta_width,bits=BITS(12345.6789012345,theta_width)))
        if sg['session_policy']['return_cache']==1:self.assertEqual(state['cache_history_output'],state['after'])
        else:self.assertEqual(state['cache_history_output']['end_tokens'],[]);self.assertEqual(state['cache_history_output']['policy']['reference'],0)
        positions=next(t for t in sg['tensors'] if t['name']=='positions');pid=positions['id'];op=sg['operations'][0]
        self.assertEqual((op['kind'],op['inputs'],op['weight'],op['position_start'],op['output']),('position_range',[],'',past,pid))
        self.assertEqual((positions['shape'],positions['elements'],positions['producer'],positions['persistent'],positions['alias_of']),([q],q,0,False,-1))
        rotary={o['id']:o for o in sg['operations'] if o['kind'] in ('rope_query','rope_key')}
        self.assertEqual(state['charged_work'],128+state['before']['charged_work']+state['after']['charged_work']+64*len(rotary))
        for owner,key in ((sg,'operations'),(rs,'recipes'),(eg,'operations')):
            for o in owner[key]:
                enabled=o.get('id') in rotary if owner is sg else o['source_operation'] in rotary
                self.assertEqual((o['dynamic_reference'],o['dynamic_selected'],o['dynamic_factor']),(reference,selected,word) if enabled else (0,0,None))
                if owner is not rs:self.assertEqual(o['position_start'],past if o['kind']=='position_range' else -1)
        sequence=['rotary_inverse_frequency','dynamic_rotary_gain','dynamic_rotary_frequency','rotary_angles','cos','sin','rotary_first','rotary_second','multiply_rotary_cos','multiply_rotary_sin','subtract','multiply_rotary_sin','multiply_rotary_cos','add','rotary_assemble']
        source_map=eg['source_to_global'];values=eg['values'];global_ops=eg['operations']
        for r in rs['recipes']:
            if r['source_operation'] not in rotary:continue
            self.assertEqual([o['kind'] for o in r['operations']],sequence)
            self.assertEqual(r['source_inputs'],rotary[r['source_operation']]['inputs']);self.assertEqual(r['input_values'],[0,1])
            a,b,c=r['operations'][:3]
            self.assertEqual(a['inputs'],[]);self.assertEqual(b['inputs'],[]);self.assertEqual(c['inputs'],[a['output'],b['output']])
            self.assertEqual(r['values'][b['output']]['shape'],[1]);self.assertEqual(r['values'][c['output']]['shape'],[p['rope_dim']//2]);self.assertEqual(r['operations'][3]['inputs'],[1,c['output']])
            for i,v in enumerate(r['values']):
                self.assertEqual(v['elements'],math.prod(v['shape']))
                last=max([v['producer']]+[j for j,o in enumerate(r['operations']) if i in o['inputs']])
                if i==r['result']:last=len(r['operations'])
                self.assertEqual(v['last_use'],last)
            group=[o for o in global_ops if o['source_operation']==r['source_operation']]
            self.assertEqual(len(group),15);local={i:source_map[src] for i,src in zip(r['input_values'],r['source_inputs'])}
            for step,(actual,want) in enumerate(zip(group,r['operations'])):
                self.assertEqual(actual['recipe_step'],step);self.assertEqual(actual['kind'],want['kind']);self.assertEqual(actual['inputs'],[local[i] for i in want['inputs']])
                v=values[actual['output']];rv=r['values'][want['output']]
                self.assertEqual((v['shape'],v['elements'],v['domain']),(rv['shape'],rv['elements'],rv['domain']));local[want['output']]=actual['output']
            self.assertEqual(source_map[r['source_output']],local[r['result']])
        for tensors,ops,exports in ((sg['tensors'],sg['operations'],[sg['logits']]+sg['cache_exports']), (values,global_ops,[eg['result']]+eg['cache_exports'])):
            for i,v in enumerate(tensors):
                self.assertEqual(v['elements'],math.prod(v['shape']))
                last=max([v['producer']]+[j for j,o in enumerate(ops) if i in o['inputs']])
                if i in exports or v.get('persistent') or v.get('storage') in ('source_weight','persistent_kv'):last=len(ops)
                self.assertEqual(v['last_use'],last)
        # Independently accumulate inclusive lifetimes with distinct index/real widths.
        for tensors,ops,storage,semantic in ((sg['tensors'],sg['operations'],full['semantic_storage'],True),(values,global_ops,full['storage'],False)):
            sizes=[];real=[0]*(len(ops)+1);index=[0]*len(real);pred=[0]*len(real);kv=inputs=0
            for v in tensors:
                kind=('persistent_kv' if v['persistent'] else ('index' if v['producer']==-1 else 'activation')) if semantic else v['storage']
                domain=('index' if v['name'] in ('tokens','positions') else 'real') if semantic else v['domain']
                width=8 if domain=='index' else (1 if domain=='predicate' else 2)
                size=((v['elements']*width+15)//16)*16 if v['alias_of']==-1 and kind!='source_weight' else 0
                sizes.append(size)
                if kind=='persistent_kv':kv+=size
                elif kind=='index':inputs+=size
                elif kind=='activation':
                    line=index if domain=='index' else pred if domain=='predicate' else real
                    for j in range(v['producer'],v['last_use']+1):line[j]+=size
            self.assertEqual(storage['tensor_bytes' if semantic else 'value_bytes'],sizes)
            self.assertEqual(storage['index_live_bytes'],index);self.assertEqual(storage['persistent_kv_bytes'],kv);self.assertEqual(storage['input_bytes'],inputs)
            if semantic:
                self.assertEqual(storage['activation_live_bytes'],real);temporary=[a+b for a,b in zip(real,index)]
                self.assertEqual(storage['peak_temporary_bytes'],max(temporary));self.assertEqual(storage['temporary_peak_step'],temporary.index(max(temporary)))
                self.assertEqual(storage['peak_activation_bytes'],max(real));self.assertEqual(storage['peak_step'],real.index(max(real)))
            else:
                self.assertEqual(storage['real_live_bytes'],real);self.assertEqual(storage['predicate_live_bytes'],pred)
                temporary=[a+b+c for a,b,c in zip(real,index,pred)];self.assertEqual(storage['activation_live_bytes'],temporary);self.assertEqual(storage['peak_activation_bytes'],max(temporary))
            self.assertEqual(storage['total_bytes'],kv+inputs+max(temporary)+sg['weight_bytes'])
        return full

    def test_01_source_words_modes_positions_and_storage(self):
        for scalar,mode,returned,shards in itertools.product(('source64','requested32'),('cached_append','full_prefix'),(0,1),(1,3)):
            root,_=self.fixture(shards=shards);past=4 if mode=='cached_append' else 0
            ends='4' if past else '-';contexts='8' if past else '-'
            for width in (32,64):
                obj=self.accept(self.invoke(root,scalar=scalar,origin='invocation',mode=mode,returned=returned,past=past,ends=ends,contexts=contexts,shards=shards,width=width))
                self.check(obj,ends=(4,) if past else (),contexts=(8,) if past else (),width=width)
        for mask,dim,pairing in itertools.product(('0,0','1,0','1,1'),(2,4),('adjacent','split_half')):
            root,_=self.fixture();self.check(self.accept(self.invoke(root,mask=mask,dim=dim,pairing=pairing)))
        for legacy in (False,True):
            root,_=self.fixture(legacy=legacy);obj=self.accept(self.invoke(root));self.check(obj)
            frozen=self.accept(self.child([C.frozen,'unindexed',root,'source-0.weights','config.json',2,0,8,2,'1,0','1,1','1,1','source64','split_half',1000000,'dynamic graph æ𝄞','gelu_erf,relu','full_prefix',1,'3,1','default',64,BITS(1.)]))
            self.assertEqual(obj['original_source'],frozen['original_source'])

    def test_02_history_boundaries_extents_and_refusals(self):
        root,_=self.fixture()
        rows=[(2,0,32,32,(),()),(2,8,12,32,(8,),(32,)),(2,6,8,32,(4,6),(8,8)),(2,8,12,32,(4,8),(8,8)),(3,8,32,8,(8,),(8,)),(2,0,9223372036854775807,32,(),())]
        for q,past,cap,initial,ends,contexts in rows:
            limit=max(128,cap);mode='cached_append' if past else 'full_prefix'
            self.check(self.accept(self.invoke(root,query=q,past=past,cap=cap,initial=initial,ends=','.join(map(str,ends)) or '-',contexts=','.join(map(str,contexts)) or '-',limit=limit,mode=mode)),initial,ends,contexts)
        for kwargs in [dict(query=0),dict(past=-1),dict(query=2,past=127,cap=128,mode='cached_append'),dict(cap=129),dict(cap=9223372036854775807,limit=9223372036854775807,mode='cached_append'),dict(limit=7),dict(initial=7),dict(initial=129),dict(mode='full_prefix',past=1),dict(past=8,mode='cached_append'),dict(past=4,mode='cached_append',ends='4',contexts='32'),dict(work=1),dict(scalar='requested32',origin='source')]:
            self.refuse(self.invoke(root,**kwargs));self.check(self.accept(self.invoke(root)))
        for factor,width in [(0.,64),(-1.,32),(float('inf'),64)]:self.refuse(self.invoke(root,origin='invocation',factor=factor,width=width))

    def test_03_mutations_consumers_and_recovery(self):
        root,_=self.fixture();fields=json.loads(Path(C.mutations).read_text())
        for field in fields:
            self.refuse(self.child([self.api,root,'source-0.weights','config.json',field,'expanded']))
            self.check(self.accept(self.child([self.api,root,'source-0.weights','config.json','valid','expanded'])),factor=3.,width=32)
        for consumer,field in itertools.product(('session','bias','activation','semantic_storage','cache','matrix'),('before_theta','source_position_start','source_rotary_factor','source_export','source_position_life')):
            self.refuse(self.child([self.api,root,'source-0.weights','config.json',field,consumer]))
        self.check(self.accept(self.child([self.api,root,'source-0.weights','config.json','work','expanded'])),factor=3.,width=32)
        for name in ('valid','source_position_start','after_selected','snapshot_after','global_range_start','global_gain_life'):
            r=self.child([self.api,root,'source-0.weights','config.json',name,'expanded'],trace='dynamic-'+name+'.trace')
            if name=='valid':self.check(self.accept(r),factor=3.,width=32)
            else:self.refuse(r)
        # Header owner evidence and fresh-success cleanup; trace each format separately.
        for shards in (1,3):
            root,expected=self.fixture(shards=shards)
            self.check(self.accept(self.invoke(root,shards=shards,trace='dynamic-headers-'+str(shards)+'.trace')))
            for path,raw in expected['raw_files'].items():self.assertEqual(path.read_bytes(),raw)

    def test_04_gguf_explicit_math(self):
        raw=dense_fixture(layers=2,key=4,value=4,overrides={'llama.context_length':(10,8)})[0]
        path=self.root/'explicit.gguf';path.write_bytes(raw)
        for scalar,mode,returned,width in itertools.product(('source32','legacy32'),('cached_append','full_prefix'),(0,1),(32,64)):
            run=self.child([C.gguf,path,'0,0','0,0','1,0',scalar,'silu,silu',mode,returned,0,32,'3,1','dynamic',width,BITS(1.5,width)])
            self.check(self.accept(run),initial=8,width=width)
        self.assertEqual(path.read_bytes(),raw)

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for name in ('binary','api','gguf','frozen','mutations','strace','evidence'):parser.add_argument('--'+name,required=True)
    C=parser.parse_args();old.CONFIG=argparse.Namespace(binary=C.binary,api=C.api,evidence=C.evidence,strace=C.strace)
    suite=unittest.defaultTestLoader.loadTestsFromTestCase(DynamicGraph)
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(not result.wasSuccessful())
