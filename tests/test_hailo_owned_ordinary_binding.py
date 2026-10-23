#!/usr/bin/env python3
"""Independent retained compiler-input, intent and source-word checks."""
import argparse
from collections import Counter
import copy,hashlib,json,math,os,random,struct,subprocess,sys,unittest
from pathlib import Path
from test_hailo_shard_collection import DEFAULT
import test_hailo_ordinary_projection_schema as schema_oracle
declared=schema_oracle.declared
from test_hailo_sealed_source_collection import source,COPY

CONFIG=argparse.Namespace()
PROVENANCE="explicit ordinary projection test"
COMPILER=[4096,100000,10000000,100000,10000000,8,10000,64,10000000,10000000,PROVENANCE,16777216,16384]
SCHEMA=['head_dim', 'head_origin', 'schema_provenance', 'schema_work', 'key_dim', 'value_dim', 'output', 'notes', 'work', 'owned_policy', 'source_architecture', 'source_provenance', 'source_extent', 'source_offset', 'source_weight_bytes', 'source_alias', 'source_binding', 'source_kind', 'source_tag', 'source_shape', 'source_name', 'source_path', 'source_policy', 'original_name', 'original_shape', 'original_offset', 'original_extent', 'original_metadata', 'original_metadata_count', 'architecture', 'layer_mask', 'bias_binding', 'bias_shape', 'bias_flag', 'source_columns', 'binding_offset', 'binding_bytes', 'storage_kind', 'storage_axes', 'storage_elements', 'storage_offset', 'storage_bytes', 'file_format', 'file_bytes', 'file_offset', 'config_fields', 'config_bytes', 'config_work', 'config_path', 'layer_policy', 'arch_policy', 'arch_scalar', 'arch_origin', 'arch_notes', 'arch_work', 'arch_activation', 'layer_origin', 'layer_raw', 'layer_type', 'layer_notes', 'layer_work', 'original_kind', 'original_path', 'original_axes', 'original_elements', 'original_bytes', 'original_format']
POLICY=['config.bytes', 'config.fields', 'config.work', 'config.depth', 'index.bytes', 'index.tensors', 'index.fields', 'index.work', 'index.depth', 'fd.header_bytes', 'fd.tensors', 'fd.rank', 'fd.work', 'fd.depth', 'fd.read_bytes', 'collection.shards', 'collection.tensors', 'collection.metadata_bytes', 'collection.payload_bytes', 'collection.work', 'layers.layers', 'layers.entries', 'layers.work', 'architecture.entries', 'architecture.work', 'projection.work', 'projection.source.files', 'projection.source.tensors', 'projection.source.rank', 'projection.source.work', 'hash_bytes', 'digest_calls', 'projection.provenance']

class OwnedOrdinaryBinding(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out=Path(CONFIG.evidence).resolve();cls.out.mkdir(parents=True,exist_ok=False)
        cls.runs=[];cls.fixtures=[];cls.mutations=[];cls.faults=[];cls.counts=Counter();cls.sequence=0
    @classmethod
    def tearDownClass(cls):
        for k in ('runs','fixtures','mutations','faults'):(cls.out/(k+'.json')).write_text(json.dumps(getattr(cls,k),indent=2)+'\n')
        summary=dict(calls=len(cls.runs),outcomes=dict(Counter('accepted' if r['returncode']==0 else 'refused' for r in cls.runs)),comparisons=dict(cls.counts))
        (cls.out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(summary)
    def fixture(self,indexed=True,seed=0,pad=0):
        type(self).sequence+=1;root=self.out/('model-%04d'%self.sequence);root.mkdir()
        cfg,roles=declared(layers=1+seed%2,hidden=8,heads=4,kv=2,dimension=2+seed%3,explicit=True,attention=True,mlp=True,tie=seed%3!=0,output=seed%3!=1)
        cfg.update(hidden_act='gelu' if seed%2 else 'silu',rope_scaling={'rope_type':'linear','factor':2},pretraining_tp=2,unknown=[None,{'λ':False}])
        rng=random.Random(seed);n=3 if indexed else 1;files={};windows={};bindings={};fileviews={};metadata={};weight_map={};payload=0
        for i in range(n):
            label='source-%d.weights'%i;tensors=[]
            for j,(name,(canonical,shape)) in enumerate(roles.items()):
                if j%n!=i:continue
                dtype=('F16','BF16','F32')[j%3];width=4 if dtype=='F32' else 2
                words=[rng.getrandbits(width*8) for _ in range(math.prod(shape))]
                tensors.append((name,dtype,shape,words));weight_map[name]=label
            raw,want=source(tensors,pad);files[label]=raw;windows[label]=want;offset=8+struct.unpack_from('<Q',raw)[0];path=str(root/label)
            fileviews[path]=dict(source_format='safetensors',source_bytes=len(raw),data_offset=offset);metadata[path]={'source':'tiny synthetic\0雪'}
            for name,t in want.items():
                canonical,shape=roles[name];payload+=t['byte_count']
                bindings[canonical]=dict(source_format='safetensors',source_kind=t['dtype'],original_name=name,source_path=path,source_shape=shape,axis_order='row_major_outermost_first',elements=math.prod(shape),file_offset=offset+t['relative'],byte_count=t['byte_count'],columns=shape[-1],rows=shape[0] if len(shape)==2 else 1)
        files['config.json']=json.dumps(cfg,ensure_ascii=False,separators=(',',':')).encode()
        if indexed:files['index.json']=json.dumps(dict(weight_map=weight_map,metadata=dict(total_size=payload,future=[None,{'x':True}]),unknown={'λ':None}),ensure_ascii=False,separators=(',',':')).encode()
        for label,raw in files.items():(root/label).write_bytes(raw)
        expected=dict(bindings=bindings,files=fileviews,metadata=metadata,payload=payload)
        self.fixtures.append(dict(root=str(root),indexed=indexed,files={k:dict(hex=v.hex(),sha256=hashlib.sha256(v).hexdigest()) for k,v in files.items()},windows=windows))
        return root,files,windows,cfg,expected
    def child(self,args,root=None,trace=False,env=None):
        cmd=list(map(str,args));p=None
        if trace:
            p=self.out/('trace-%04d.strace'%len(self.runs));cmd=[CONFIG.strace,'-f','-yy','-s','4096','-o',str(p),'-e','trace=%file,%desc,%memory,%network,%process',*cmd]
        r=subprocess.run(cmd,capture_output=True,text=True,timeout=90,stdin=subprocess.DEVNULL,env=env)
        self.runs.append(dict(arguments=cmd,root=str(root) if root else None,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr,trace=str(p) if p else None,fault_environment={k:v for k,v in (env or {}).items() if k.startswith('AESIR_') or k=='LD_PRELOAD'}));return r
    def args(self,root,indexed,compiler=None,policies=None):
        groups=policies or (DEFAULT if indexed else [DEFAULT[0],DEFAULT[2],DEFAULT[3],DEFAULT[4]])
        return [root,'index.json' if indexed else 'source-0.weights','config.json',*[v for g in groups for v in g],*COPY,*(compiler or COMPILER)]
    def call(self,root,indexed=True,mode='snapshot',trace=True,compiler=None,policies=None,env=None,tool=False):
        return self.child([CONFIG.binary,'indexed' if indexed else 'unindexed',*self.args(root,indexed,compiler,policies)] if tool else [CONFIG.api,'indexed' if indexed else 'unindexed',mode,*self.args(root,indexed,compiler,policies)],root,trace,env)
    def reference(self,root,indexed):
        r=self.child([CONFIG.schema,'indexed' if indexed else 'unindexed',root,'index.json' if indexed else 'source-0.weights','config.json',8,10000,64,10000000,10000000,PROVENANCE],root)
        self.assertEqual(r.returncode,0,r.stderr);return json.loads(r.stdout)
    def exact(self,r,fixture,indexed,reference=None):
        root,files,windows,cfg,expected=fixture;self.assertEqual(r.returncode,0,r.stderr);self.assertEqual(r.stderr,'');lines=r.stdout.splitlines();self.assertIn(len(lines),(1,2,3));obj=json.loads(lines[0]);schema=obj['schema']
        schema_oracle.OrdinaryProjectionSchema.check(self,schema,cfg,expected,cfg['head_dim'])
        if reference is not None:self.assertEqual(schema,reference);self.counts['complete_frozen_schemas']+=1
        collection=obj['collection'];self.assertEqual(collection['source_bytes'],sum(map(len,files.values())));self.assertEqual(collection['config_digest_hex'],hashlib.sha256(files['config.json']).hexdigest())
        if indexed:self.assertEqual(collection['index_digest_hex'],hashlib.sha256(files['index.json']).hexdigest())
        shards=collection['shards'] if indexed else [collection['source']]
        for sh in shards:self.assertEqual(sh['digest_hex'],hashlib.sha256(files[sh['label']]).hexdigest())
        self.assertEqual(collection['tensor_count'],len(expected['bindings']));self.assertEqual(collection['payload_bytes'],expected['payload'])
        for k,v in obj.items():
            if k.endswith('_verified') or k in ('execution_tested','device_access'):self.assertIs(v,False,k)
        if len(lines)>=2:
            views=json.loads(lines[1]);self.assertEqual({v['canonical'] for v in views},set(expected['bindings']))
            for view in views:
                b=expected['bindings'][view['canonical']];want=windows[Path(b['source_path']).name][b['original_name']];w=view['window']
                for key in ('dtype','raw_words','binary32_words','byte_count'):self.assertEqual(w[key],want[key],(view['canonical'],key))
                self.assertEqual(w['shape'],b['source_shape']);self.assertEqual(w['file_offset'],b['file_offset']);self.assertEqual(w['first'],0);self.assertEqual(w['count'],b['elements']);self.assertEqual(w['source_bytes'],len(files[Path(b['source_path']).name]));self.counts['exact_component_words']+=2*len(w['raw_words'])
            self.counts['complete_component_snapshots']+=1
        if len(lines)==3:
            selected=json.loads(lines[2]);b=expected['bindings'][selected['canonical']];w=selected['window'];want=windows[Path(b['source_path']).name][b['original_name']];lo=w['first'];hi=lo+w['count']
            self.assertEqual(w['raw_words'],want['raw_words'][lo:hi]);self.assertEqual(w['binary32_words'],want['binary32_words'][lo:hi]);self.assertEqual(w['file_offset'],b['file_offset']);self.assertEqual(w['shape'],b['source_shape']);self.counts['selected_component_windows']+=1;self.counts['exact_component_words']+=2*w['count']
        self.counts['complete_schema_oracles']+=1
        return obj
    def refused(self,r):
        self.assertNotEqual(r.returncode,0,r.stdout);self.assertEqual(r.stdout,'');self.assertIn('Unhandled exception caught during execution:',r.stderr)
    def restore(self,fixture):
        root,files,*_=fixture
        for label,raw in files.items():
            (root/label).write_bytes(raw);(root/(label+'.before')).unlink(missing_ok=True)
    def test_01_all_roles_representations_and_factories(self):
        for indexed in (True,False):
            for seed in range(6):
                f=self.fixture(indexed,seed);ref=self.reference(f[0],indexed)
                self.exact(self.call(f[0],indexed,trace=seed==0),f,indexed,ref)
                self.exact(self.call(f[0],indexed,tool=True,trace=seed==0),f,indexed,ref)
    def test_02_rehydrate_move_close_copied_windows_and_recovery(self):
        for indexed in (True,False):
            f=self.fixture(indexed,1);ref=self.reference(f[0],indexed)
            for mode in ('pre_cache','post_cache','move','recover','window_empty','window_last','window_zero'):
                self.exact(self.call(f[0],indexed,mode),f,indexed,ref)
            for mode in ('closed','closed_config','host','pre_shard:closed','pre_shard:owner_extent','pre_shard:file_size','pre_shard:route','post_shard:closed','post_shard:owner_extent','post_shard:namespace','missing_name','window_first','window_count','window_bound'):
                self.refused(self.call(f[0],indexed,mode));self.exact(self.call(f[0],indexed,trace=False),f,indexed,ref)
            if indexed:
                for mode in ('missing_shard','closed_index','duplicate_label','pre_shard:label','post_shard:label'):
                    self.refused(self.call(f[0],indexed,mode));self.exact(self.call(f[0],indexed,trace=False),f,indexed,ref)
    def test_03_every_schema_and_canonical_descriptor_field(self):
        for indexed in (True,False):
            f=self.fixture(indexed,1);ref=self.reference(f[0],indexed)
            for mode in SCHEMA:
                self.refused(self.call(f[0],indexed,'schema:'+mode));self.exact(self.call(f[0],indexed,trace=False),f,indexed,ref)
    def test_04_every_owned_and_external_policy_field(self):
        for indexed in (True,False):
            f=self.fixture(indexed,1);ref=self.reference(f[0],indexed)
            for prefix in ('policy:','external:'):
                for field in POLICY:
                    self.refused(self.call(f[0],indexed,prefix+field));self.exact(self.call(f[0],indexed,trace=False),f,indexed,ref)
    def test_05_complete_original_mutations_before_bind_and_after_return(self):
        for indexed in (True,False):
            f=self.fixture(indexed,1);root,files,*_=f;ref=self.reference(root,indexed)
            for when in ('before:','after:'):
                for mode in ('truncate','zero','replace','rename','same_size'):
                    records=[]
                    for repeat in range(2):
                        self.restore(f);r=self.call(root,indexed,when+mode);self.exact(r,f,indexed,ref)
                        after={k:(root/k).read_bytes() for k in files};renamed={k:(root/(k+'.before')).read_bytes().hex() if (root/(k+'.before')).exists() else None for k in files}
                        want={k:v[:1] if mode=='truncate' else v[:-1]+bytes([v[-1]^64]) if mode=='same_size' else b'' for k,v in files.items()};self.assertEqual(after,want)
                        self.assertEqual(renamed,{k:v.hex() if mode=='rename' else None for k,v in files.items()})
                        records.append((r.returncode,r.stdout,r.stderr,after,renamed));self.mutations.append(dict(root=str(root),when=when,mode=mode,repeat=repeat,before={k:v.hex() for k,v in files.items()},after={k:v.hex() for k,v in after.items()},renamed=renamed))
                    self.assertEqual(records[0],records[1]);self.counts['independent_complete_mutation_pairs']+=1
            self.restore(f)
    def test_06_exact_hash_and_parser_boundaries(self):
        for indexed in (True,False):
            for size in (4095,4096,4097,8191,8192,8193,16383,16384,16385):
                f=self.fixture(indexed,1);root,files,*_=f
                for label,raw in list(files.items()):
                    if label.endswith('.weights'):
                        n=struct.unpack_from('<Q',raw)[0];pad=max(0,size-len(raw));files[label]=struct.pack('<Q',n+pad)+raw[8:8+n]+b' '*pad+raw[8+n:]
                    else:files[label]=raw+b' '*max(0,size-len(raw))
                    (root/label).write_bytes(files[label])
                self.fixtures[-1]['files']={k:dict(hex=v.hex(),sha256=hashlib.sha256(v).hexdigest()) for k,v in files.items()}
                # Rebuild exact independent offsets after padding.
                for b in f[4]['bindings'].values():
                    raw=files[Path(b['source_path']).name];offset=8+struct.unpack_from('<Q',raw)[0];old=f[4]['files'][b['source_path']]['data_offset'];b['file_offset']+=offset-old
                for path,v in f[4]['files'].items():v.update(source_bytes=len(files[Path(path).name]),data_offset=8+struct.unpack_from('<Q',files[Path(path).name])[0])
                f[3]['head_dim']=3;ref=self.reference(root,indexed);compiler=COMPILER.copy();compiler[-2]=sum(map(len,files.values()));compiler[-1]=max((len(v)+4095)//4096 for v in files.values())
                self.exact(self.call(root,indexed,compiler=compiler),f,indexed,ref)
                for pos in (-2,-1):
                    short=compiler.copy();short[pos]-=1;self.refused(self.call(root,indexed,compiler=short))
    def test_07_hash_metadata_parser_close_faults_and_fresh_success(self):
        for indexed in (True,False):
            f=self.fixture(indexed,1);root=f[0];ref=self.reference(root,indexed)
            cases=[('config.json','error',4),('config.json','eof',4),('config.json','bad_json',5),('config.json','close_after',0),('source-0.weights','error',3),('source-0.weights','eof',3)]
            if indexed:cases += [('index.json','error',4),('index.json','bad_json',5),('index.json','close_after',0),('source-2.weights','error',3)]
            for label,mode,phase in cases:
                values=[];logs=[]
                for repeat in range(2):
                    log=self.out/('fault-%04d.jsonl'%len(self.faults));env=dict(os.environ,LD_PRELOAD=str(Path(CONFIG.faults).resolve()),AESIR_BINDING_LABEL=label,AESIR_BINDING_FAULT=mode,AESIR_BINDING_PHASE=str(phase),AESIR_BINDING_LOG=str(log))
                    r=self.call(root,indexed,env=env);self.refused(r);self.assertTrue(log.is_file());raw=log.read_bytes();self.assertIn(mode,raw.decode());logs.append(raw);values.append((r.returncode,r.stdout,r.stderr));self.faults.append(dict(label=label,mode=mode,phase=phase,repeat=repeat,log=str(log),hex=raw.hex()))
                self.assertEqual(values[0],values[1]);self.assertEqual(logs[0],logs[1]);self.counts['independent_complete_fault_pairs']+=1;self.exact(self.call(root,indexed,trace=False),f,indexed,ref)
    def test_08_missing_formats_and_later_binding_failures_remain_work(self):
        for indexed in (True,False):
            f=self.fixture(indexed,1);root=f[0];ref=self.reference(root,indexed)
            for field,value in [('hidden_size',99),('num_hidden_layers',9223372036854775807),('head_dim',17)]:
                changed=dict(f[3]);changed[field]=value;(root/'config.json').write_text(json.dumps(changed));self.refused(self.call(root,indexed));self.restore(f);self.exact(self.call(root,indexed,trace=False),f,indexed,ref)
            # Existing binder currently refuses unknown roles, scalar/empty and
            # wrong rank source geometry. These remain required implementation.
            label='source-0.weights';raw=f[1][label];n=struct.unpack_from('<Q',raw)[0];header=json.loads(raw[8:8+n]);name=next(k for k in header if k!='__metadata__')
            for shape in ([],[0],header[name]['shape']+[1]):
                changed=copy.deepcopy(header);changed[name]['shape']=shape;h=json.dumps(changed,separators=(',',':')).encode();(root/label).write_bytes(struct.pack('<Q',len(h))+h+raw[8+n:]);self.refused(self.call(root,indexed));self.restore(f)
            self.exact(self.call(root,indexed,trace=False),f,indexed,ref)

if __name__=='__main__':
    p=argparse.ArgumentParser()
    for key in ('binary','api','schema','faults','strace','evidence'):p.add_argument('--'+key,required=True)
    CONFIG,remaining=p.parse_known_args();unittest.main(argv=[sys.argv[0],*remaining],verbosity=2)
