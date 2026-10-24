#!/usr/bin/env python3
"""Retained source sharing and complete mathematical IR; no host model forward."""
import argparse,copy,hashlib,json,math,os,random,struct,subprocess,unittest
from pathlib import Path
from collections import Counter
from types import SimpleNamespace
import test_hailo_owned_ordinary_binding as binding
import test_hailo_owned_ordinary_compiler as ordinary
import test_hailo_ordinary_tensor_identity as identity
CONFIG=argparse.Namespace()
REQUEST=ordinary.REQUEST
SHARING=['alias','target','self','reverse','origin','provenance','work','duplicate','missing','empty']
EXPANDED=['map','missing','extra','name','source','shape','elements','producer','last','storage','alias','domain']

class OwnedTiedOutput(unittest.TestCase):
    args=binding.OwnedOrdinaryBinding.args
    refused=binding.OwnedOrdinaryBinding.refused
    @classmethod
    def setUpClass(cls):
        cls.out=Path(CONFIG.evidence).resolve();cls.out.mkdir(parents=True,exist_ok=False)
        cls.runs=[];cls.fixtures=[];cls.mutations=[];cls.faults=[];cls.counts=Counter();cls.sequence=0
    @classmethod
    def tearDownClass(cls):
        for k in ('runs','fixtures','mutations','faults'):(cls.out/(k+'.json')).write_text(json.dumps(getattr(cls,k),indent=2)+'\n')
        (cls.out/'summary.json').write_text(json.dumps(dict(calls=len(cls.runs),outcomes=dict(Counter('accepted' if r['returncode']==0 else 'refused' for r in cls.runs)),comparisons=dict(cls.counts)),indent=2)+'\n')
    def fixture(self,indexed=True,dtype='F16',separate=True,changed=None,head_dtype=None,head_shape=None,**options):
        type(self).sequence+=1;root=self.out/('model-%04d'%self.sequence);root.mkdir()
        dims=dict(layers=1,hidden=8,heads=4,kv=2,dimension=2,explicit=True,attention=True,mlp=True,tie=True,output=True);dims.update(options)
        cfg,roles=binding.declared(**dims);cfg.update(rms_norm_eps=0.0000010000000000000002,rope_theta=10000.000000000002,hidden_act='silu',use_cache=True,rope_scaling={'rope_type':'linear','factor':2},no_rope_layers=[i%2 for i in range(dims['layers'])]);cfg.update(changed or {})
        # The duplicate is appended last; base payload values depend on names,
        # never on header/index positions or the presence of the duplicate.
        head=roles.pop('lm_head.weight',None)
        if head:roles['lm_head.weight']=head
        if head and head_shape:roles['lm_head.weight']=(head[0],head_shape)
        groups=[[],[]] if indexed and separate and head else [[]];weight_map={};nwidth=4 if dtype=='F32' else 2;embedding=[]
        for name,(canonical,shape) in roles.items():
            rng=random.Random(hashlib.sha256(name.encode()).digest());words=[rng.getrandbits(nwidth*8) for _ in range(math.prod(shape))]
            if name=='model.embed_tokens.weight':embedding=words.copy()
            if name=='lm_head.weight':words=(embedding*((math.prod(shape)+len(embedding)-1)//len(embedding)))[:math.prod(shape)]
            kind=head_dtype if name=='lm_head.weight' and head_dtype else dtype
            slot=1 if len(groups)==2 and name=='lm_head.weight' else 0;groups[slot].append((name,kind,shape,words));weight_map[name]='source-%d.weights'%slot
        files={};windows={};bindings={};fileviews={};metadata={};payload=0
        for i,tensors in enumerate(groups):
            label='source-%d.weights'%i;data,want=binding.source(tensors,8192 if indexed else 0);files[label]=data;windows[label]=want;start=8+struct.unpack_from('<Q',data)[0];path=str(root/label);fileviews[path]=dict(source_format='safetensors',source_bytes=len(data),data_offset=start);metadata[path]={'source':'tiny synthetic\0雪'}
            for name,t in want.items():
                canonical,shape=roles[name];payload+=t['byte_count'];bindings[canonical]=dict(source_format='safetensors',source_kind=t['dtype'],original_name=name,source_path=path,source_shape=shape,axis_order='row_major_outermost_first',elements=math.prod(shape),file_offset=start+t['relative'],byte_count=t['byte_count'],columns=shape[-1],rows=shape[0] if len(shape)==2 else 1)
        files['config.json']=json.dumps(cfg,ensure_ascii=False,separators=(',',':')).encode()
        if indexed:files['index.json']=json.dumps(dict(weight_map=weight_map,metadata=dict(total_size=payload)),separators=(',',':')).encode()
        for name,data in files.items():(root/name).write_bytes(data)
        self.fixtures.append(dict(root=str(root),indexed=indexed,files={k:v.hex() for k,v in files.items()},windows=windows,bindings=bindings))
        return root,files,windows,cfg,dict(bindings=bindings,files=fileviews,metadata=metadata,payload=payload),indexed
    def child(self,args,trace=False,env=None):
        path=None;cmd=list(map(str,args));n=len(self.runs)
        if trace:path=self.out/('trace-%04d.strace'%n);cmd=['/usr/bin/strace','-f','-yy','-s','512','-o',str(path),'-e','trace=%file,%desc,%memory,%network,%process',*cmd]
        r=subprocess.run(cmd,capture_output=True,text=True,timeout=180,stdin=subprocess.DEVNULL,env=env)
        for ch in ('stdout','stderr'):(self.out/('call-%04d.'%n+ch)).write_text(getattr(r,ch))
        self.runs.append(dict(arguments=cmd,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr,trace=str(path) if path else None,environment={k:v for k,v in (env or {}).items() if k.startswith('AESIR_') or k=='LD_PRELOAD'}));return r
    def call(self,f,mode='snapshot',request=None,total=100000,chunk=7,operation=0,first=0,count=1,cap=131072,trace=True,tool=False,env=None):
        req=request or REQUEST;indexed=f[5];args=self.args(f[0],indexed)
        return self.child([CONFIG.binary,'indexed' if indexed else 'unindexed',*args,*req,total,chunk] if tool else [CONFIG.api,'indexed' if indexed else 'unindexed',mode,*args,*req,total,chunk,operation,first,count,cap],trace,env)
    def restore(self,f):
        for p in f[0].iterdir():p.unlink()
        for name,data in f[1].items():(f[0]/name).write_bytes(data)
    def tree(self,f):return {p.name:p.read_bytes().hex() for p in sorted(f[0].iterdir())}
    def window(self,w,f,name):ordinary.OwnedOrdinaryCompiler.window(self,w,f[:5],name)
    def reference(self,f,req):
        # Rebuild an independent embedding-only reference folder. The qualified
        # graph keeps BOTH real source bindings and is never rewritten here.
        cfg=f[3];index=f[5];dtype=('F16','BF16','F32')[f[4]['bindings']['token_embd.weight']['source_kind']]
        dims=dict(layers=cfg['num_hidden_layers'],hidden=cfg['hidden_size'],heads=cfg['num_attention_heads'],kv=cfg['num_key_value_heads'],dimension=cfg['head_dim'],attention=cfg['attention_bias'],mlp=cfg['mlp_bias'],output=False)
        g=self.fixture(index,dtype,changed=cfg,**dims)
        # Preserve missing configuration fields as well as present values.
        # The reference owns different tensor headers, never a changed policy.
        g[3].clear();g[3].update(cfg);raw=json.dumps(g[3],ensure_ascii=False,separators=(',',':')).encode();g[1]['config.json']=raw;(g[0]/'config.json').write_bytes(raw);self.fixtures[-1]['files']['config.json']=raw.hex()
        r=self.child([CONFIG.reference,'indexed' if index else 'unindexed',*self.args(g[0],index),*req]);self.assertEqual((r.returncode,r.stderr),(0,''));return json.loads(r.stdout)['lowered']
    def exact(self,r,f,req=None,reference=False):
        req=req or REQUEST;self.assertEqual((r.returncode,r.stderr),(0,''));lines=r.stdout.splitlines();self.assertIn(len(lines),(2,4));obj=json.loads(lines[0]);obs=json.loads(lines[1]);self.assertTrue(obs['all_elements_equal']);self.assertEqual(obs['differing_elements'],0);self.assertEqual(obs['raw_elements_read'],2*f[4]['bindings']['output.weight']['elements'])
        binding.OwnedOrdinaryBinding.exact(self,SimpleNamespace(returncode=0,stderr='',stdout=lines[0]+'\n'),f[:5],f[5])
        graph=obj['lowered'];sg=graph['source_graph'];alias=sg['source_weight_sharing'];self.assertEqual(alias['scope'],'structural_source_relation');self.assertIs(alias['byte_identity_verified'],False);self.assertEqual(alias['aliases'],[dict(alias_name='output.weight',target_name='token_embd.weight',source_origin='source' if 'tie_word_embeddings' in f[3] else 'documented_default:true')]);self.assertEqual(alias['provenance'],req[8]);self.assertEqual(alias['work_limit'],req[6]);self.assertEqual(alias['charged_work'],64+len(req[8].encode())+len('output.weight')+len('token_embd.weight')+len(alias['aliases'][0]['source_origin'])+2)
        self.assertEqual(set(sg['weights']),set(f[4]['bindings'])-{'output.weight'});self.assertEqual(sg['weight_bytes'],f[4]['payload'])
        expanded=graph['expanded'];self.assertEqual(set(expanded['weights']),set(f[4]['bindings']));alias_id=expanded['weights']['output.weight']['value'];target_id=expanded['weights']['token_embd.weight']['value'];self.assertNotEqual(alias_id,target_id)
        for name,b in f[4]['bindings'].items():
            actual=expanded['weights'][name];self.assertEqual({k:v for k,v in actual.items() if k!='value'},{k:b[k] for k in ('file_offset','columns','rows','source_kind','byte_count')});value=expanded['values'][actual['value']];self.assertEqual(value['source_weight'],name);self.assertEqual(value['name'],name);self.assertEqual(value['storage'],'source_weight');self.assertEqual(value['last_use'],len(expanded['operations']));self.assertEqual(value['alias_of'],-1);self.assertEqual(value['elements'],b['elements'])
        if len(lines)==4:
            for view in json.loads(lines[2]):self.window(view['window'],f,view['canonical'])
            w=json.loads(lines[3]);operation=int(r.args[-4]) if hasattr(r,'args') and r.args[-4].lstrip('-').isdigit() else 0;name=sg['operations'][operation]['weight'];self.window(w,f,name)
        if reference:
            old=self.reference(f,req);other=old['source_graph'];self.assertEqual(sg['operations'],other['operations']);self.assertEqual(sg['tensors'],other['tensors']);self.assertEqual(sg['parameters'],other['parameters']);self.assertEqual(expanded['operations'],old['expanded']['operations']);self.assertEqual(expanded['values'][:-1],old['expanded']['values']);self.assertEqual(expanded['source_to_global'],old['expanded']['source_to_global'])
            # Source offsets/namespaces differ because the reference has its
            # own complete header. Independently checked above and by windows.
            def math_recipe(x):
                if isinstance(x,list):return [math_recipe(v) for v in x]
                if not isinstance(x,dict):return x
                return {k:('<source-location>' if k in ('file_offset','source_path','source_bytes','data_offset') else math_recipe(v)) for k,v in x.items()}
            self.assertEqual(math_recipe(graph['recipes']),math_recipe(old['recipes']));self.counts['complete_independent_math_references']+=1
        self.counts['complete_tied_graphs']+=1;return obj
    def test_01_equal_sources_both_kinds_collections_and_names(self):
        for indexed in (False,True):
            for dtype in ('F16','BF16','F32'):
                for separate in ((False,True) if indexed else (False,)):
                    f=self.fixture(indexed,dtype,separate);self.exact(self.call(f,'all'),f,reference=True);self.exact(self.call(f,tool=True),f)
                    n=2*f[4]['bindings']['output.weight']['elements']
                    for chunk in (1,3,17,9223372036854775807):self.exact(self.call(f,total=n,chunk=chunk),f)
            omitted=self.fixture(indexed);omitted[3].pop('tie_word_embeddings');raw=json.dumps(omitted[3],ensure_ascii=False,separators=(',',':')).encode();omitted[1]['config.json']=raw;(omitted[0]/'config.json').write_bytes(raw);self.fixtures[-1]['files']['config.json']=raw.hex();self.exact(self.call(omitted),omitted,reference=True)
    def test_02_source_modifier_geometry_and_full_mathematics(self):
        for indexed in (False,True):
            for seed,(activation,dimension,attention,mlp) in enumerate([('silu',2,False,False),('gelu',3,True,False),('relu',4,False,True)]):
                f=self.fixture(indexed,'BF16',layers=2,dimension=dimension,attention=attention,mlp=mlp,changed=dict(hidden_act=activation,sliding_window=3,layer_types=['sliding_attention','full_attention']))
                for pairing in ('adjacent','split_half'):
                    for mode,past,returned in [('full_prefix',0,0),('cached_append',2,1)]:
                        req=REQUEST.copy();req[1]=past;req[3]=dimension if dimension%2==0 else dimension-1;req[4]=mode;req[5]=returned;req[9]=pairing;self.exact(self.call(f,'all',request=req),f,req,True)
    def test_03_every_sharing_source_policy_request_and_operation_guard(self):
        mutations=json.loads(Path(CONFIG.mutations).read_text())
        for indexed in (False,True):
            f=self.fixture(indexed)
            for prefix in ('sharing:','graph_sharing:'):
                for field in SHARING:self.refused(self.call(f,prefix+field))
            for field in EXPANDED:self.refused(self.call(f,'expanded:'+field))
            for mode in ('sharing_charge','forge_empty_use','fake_use','missing_use','false_use','bound_total','bound_chunk','supplied_total','supplied_chunk','closed'):self.refused(self.call(f,mode))
            for prefix,fields in [('schema:',binding.SCHEMA),('policy:',binding.POLICY),('external:',binding.POLICY),('request:',mutations['requests']),('supplied:',mutations['requests']),('plan:',mutations['plans'])]:
                for field in fields:self.refused(self.call(f,prefix+field))
            for mode in ('cache','pre_cache','observation','move','snapshot'):self.exact(self.call(f,mode),f)
            for field in ('closed','owner_extent','file_size','route','namespace'):self.refused(self.call(f,'shard:'+field))
            if indexed:self.refused(self.call(f,'shard:label'))
            self.exact(self.call(f),f)
    def test_04_bounds_source_semantics_unequal_bits_and_recovery(self):
        for indexed in (False,True):
            f=self.fixture(indexed)
            for total,chunk in ((0,7),(-1,7),(159,7),(160,0),(160,-1)):self.refused(self.call(f,total=total,chunk=chunk))
            for op,first,count,cap in [(-1,0,1,1),(9999,0,1,1),(0,-1,1,1),(0,0,-1,1),(0,0,2,1),(0,99999,0,1)]:self.refused(self.call(f,operation=op,first=first,count=count,cap=cap))
            for cfg in ({'tie_word_embeddings':False},{'tie_word_embeddings':None},{'hidden_act':'future'},{'rope_scaling':{'rope_type':'future','factor':2}}):g=self.fixture(indexed,changed=cfg);self.refused(self.call(g))
            absent=self.fixture(indexed,output=False);self.refused(self.call(absent))
            incompatible=self.fixture(indexed,head_dtype='BF16');self.refused(self.call(incompatible))
            wrong_shape=self.fixture(indexed,head_shape=[10,9]);self.refused(self.call(wrong_shape))
            for dtype in ('F16','BF16','F32'):
                g=self.fixture(indexed,dtype);t=g[4]['bindings']['output.weight'];label=Path(t['source_path']).name
                for pos in range(t['byte_count']):
                    data=bytearray(g[1][label]);data[t['file_offset']+pos]^=1;(g[0]/label).write_bytes(data);self.refused(self.call(g));self.counts['unequal_payload_byte_refusals']+=1
                self.restore(g);self.exact(self.call(g),g)
            self.exact(self.call(f),f)
    def test_05_complete_original_mutations_and_actual_owner_replacement(self):
        for indexed in (False,True):
            f=self.fixture(indexed)
            for mode in [p+a for p in ('before:','after:') for a in ('same_size','truncate','rename','replace')]+['replace_sealed']:
                results=[];images=[]
                for repeat in range(2):
                    self.restore(f);before=self.tree(f);r=self.call(f,mode);after=self.tree(f)
                    if mode=='replace_sealed':self.refused(r)
                    else:self.exact(r,f)
                    self.assertNotEqual(before,after);results.append((r.returncode,r.stdout,r.stderr));images.append(after);self.mutations.append(dict(root=str(f[0]),mode=mode,repeat=repeat,complete_before=before,complete_after=after));self.restore(f);self.assertEqual(self.tree(f),before)
                self.assertEqual(results[0],results[1]);self.assertEqual(images[0],images[1]);self.counts['complete_original_mutation_pairs']+=1
            self.exact(self.call(f),f)
    def test_06_copy_hash_read_close_faults_and_actual_fresh_recovery(self):
        for indexed in (False,True):
            f=self.fixture(indexed)
            cases=[('config.json','error',8),('config.json','bad_json',9),('config.json','error',10),('config.json','eof',12),('config.json','close_after',0),('source-0.weights','error',5),('source-0.weights','eof',6)]
            if indexed:cases.extend([('index.json','error',8),('index.json','bad_json',9),('index.json','close_after',0)])
            for label,mode,phase in cases:
                outputs=[];logs=[]
                for repeat in range(2):
                    log=self.out/('fault-%04d.jsonl'%len(self.faults));env=dict(os.environ,LD_PRELOAD=str(Path(CONFIG.faults).resolve()),AESIR_BINDING_LABEL=label,AESIR_BINDING_FAULT=mode,AESIR_BINDING_PHASE=str(phase),AESIR_BINDING_LOG=str(log));r=self.call(f,env=env);self.refused(r);data=log.read_bytes();self.assertIn(mode,data.decode());logs.append(data);outputs.append((r.returncode,r.stdout,r.stderr));self.faults.append(dict(path=str(log),hex=data.hex(),mode=mode,label=label,phase=phase,repeat=repeat))
                self.assertEqual(outputs[0],outputs[1]);self.assertEqual(logs[0],logs[1]);self.counts['complete_fault_pairs']+=1;self.exact(self.call(f),f)

    def test_07_actual_seal_copy_mapping_faults_and_short_reads(self):
        # Same qualified fault procedure, through this retained graph factory.
        identity.CONFIG=CONFIG
        identity.OrdinaryTensorIdentity.test_07_actual_seal_copy_mapping_faults_and_short_reads(self)

if __name__=='__main__':
    p=argparse.ArgumentParser()
    for name in ('binary','api','reference','faults','mutations','evidence'):p.add_argument('--'+name,required=True)
    CONFIG,rest=p.parse_known_args();unittest.main(argv=[__file__,*rest],verbosity=2)
