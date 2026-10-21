#!/usr/bin/env python3
"""Selected mathematical metadata/IR acceptance; never a model/attention forward."""
import argparse,copy,decimal,itertools,json,math,re,struct,unittest
from pathlib import Path
import test_hailo_decoder_projections as old
import test_hailo_decoder_window as window
from test_hailo_ordinary_projection_schema import declared

CONFIG=argparse.Namespace()
PROVENANCE="explicit synthetic session recipe"

def bits(value,width=64):
    return struct.unpack('<Q' if width==64 else '<I',struct.pack('<d' if width==64 else '<f',value))[0]

def number(word):
    return struct.unpack('<d' if word['width']==64 else '<f',struct.pack('<Q' if word['width']==64 else '<I',word['bits']))[0]

def normalize(obj):
    if isinstance(obj,list):return [normalize(x) for x in obj]
    if not isinstance(obj,dict):return obj
    return {k:6 if k=='schema_version' and v==7 else normalize(v) for k,v in obj.items() if k not in ('scaling_policy','scaling_kind','scaling_factor')}

class DecoderScaling(unittest.TestCase):
    setUpClass=classmethod(old.DecoderProjections.setUpClass.__func__)
    tearDownClass=classmethod(old.DecoderProjections.tearDownClass.__func__)
    child=old.DecoderProjections.child
    accept=old.DecoderProjections.accept
    refuse=old.DecoderProjections.refuse
    collection=old.DecoderProjections.collection

    def invoke(self,root,mode='full_prefix',returned=1,past=0,scalar='source64',windows='3,1',shards=1,query=2,work=1000000,provenance=PROVENANCE,capacity=8,bias='1,1',kind='linear',factor=2.0,width=64,mask='1,0',pairing='split_half',rope_dim=2):
        return self.child([self.binary,'unindexed' if shards==1 else 'indexed',root,'source-0.weights' if shards==1 else 'index.json','config.json',query,past,capacity,rope_dim,mask,bias,bias,scalar,pairing,work,provenance,'gelu_erf,relu',mode,returned,windows,kind,width,bits(factor,width)])

    def api_call(self,root,scalar='source64',mode='full_prefix',returned=1,past=0,capacity=8,windows='3,1',case='valid'):
        return self.child([self.api,root,'source-0.weights','config.json',scalar,mode,returned,past,capacity,windows,case])

    def check(self,obj,expected,mode,returned,source_returned=0,origin='source',provenance=PROVENANCE,windows=(3,1),window_origin='invocation',window_provenance=PROVENANCE,kind='linear',factor=2.0,width=64,scaling_origin='invocation',scaling_provenance=None):
        full=obj['lowered'] if 'lowered' in obj else obj
        window.DecoderWindow.check(self,normalize(obj),expected,mode,returned,source_returned,origin,provenance,windows,window_origin,window_provenance)
        sg,rs,eg=(full[k] for k in ('source_graph','recipes','expanded'))
        word=dict(width=width,bits=bits(factor,width));p=sg['scaling_policy']
        scaling_provenance=("scaling API test provenance" if provenance=="session API test provenance" else provenance) if scaling_provenance is None else scaling_provenance
        want=dict(kind=kind,factor=word,origin=scaling_origin,provenance=scaling_provenance,work=p['work'],charged_work=160+len(kind.encode())+len(scaling_origin.encode())+len(scaling_provenance.encode()))
        for owner in (sg,rs,eg):
            self.assertEqual(owner['schema_version'],7);self.assertEqual(owner['scaling_policy'],want)
        rotary={o['id']:o for o in sg['operations'] if o['kind'] in ('rope_query','rope_key')}
        for owner,key in ((sg,'operations'),(rs,'recipes'),(eg,'operations')):
            for op in owner[key]:
                enabled=op.get('id') in rotary if owner is sg else op['source_operation'] in rotary
                self.assertEqual(op['scaling_kind'],kind if enabled else '')
                self.assertEqual(op['scaling_factor'],word if enabled else None)
        mappings={r['source_operation']:r for r in full['rotary_mappings']}
        for r in rs['recipes']:
            if r['source_operation'] not in rotary:continue
            source=rotary[r['source_operation']];d=sg['parameters']['rope_dim'];pairs=d//2;query=sg['parameters']['query_tokens']
            sequence=['rotary_inverse_frequency']+(['rotary_frequency_scale'] if kind=='linear' else [])+['rotary_angles','cos','sin','rotary_first','rotary_second','multiply_rotary_cos','multiply_rotary_sin','subtract','multiply_rotary_sin','multiply_rotary_cos','add','rotary_assemble']
            self.assertEqual([o['kind'] for o in r['operations']],sequence)
            self.assertEqual(len(sequence),14 if kind=='linear' else 13)
            self.assertEqual(r['source_inputs'],source['inputs']);self.assertEqual(r['input_values'],[0,1])
            self.assertEqual(r['values'][0]['shape'],sg['tensors'][source['inputs'][0]]['shape'])
            self.assertEqual(r['values'][1]['shape'],[query]);self.assertEqual(r['values'][1]['domain'],'index')
            freq=r['operations'][0];self.assertEqual(freq['inputs'],[]);self.assertEqual(r['values'][freq['output']]['shape'],[pairs])
            freqid=freq['output']
            if kind=='linear':
                scale=r['operations'][1];self.assertEqual(scale['inputs'],[freqid]);freqid=scale['output'];self.assertEqual(r['values'][freqid]['shape'],[pairs]);self.assertEqual(r['values'][freqid]['domain'],'real')
            angle=next(o for o in r['operations'] if o['kind']=='rotary_angles');self.assertEqual(angle['inputs'],[1,freqid]);self.assertEqual(r['values'][angle['output']]['shape'],[query,pairs])
            self.assertEqual(mappings[r['source_operation']]['rotary_dim'],d)
            for i,v in enumerate(r['values']):
                self.assertEqual(v['elements'],math.prod(v['shape']))
                last=max([v['producer']]+[j for j,o in enumerate(r['operations']) if i in o['inputs']])
                if i==r['result']:last=len(r['operations'])
                self.assertEqual(v['last_use'],last)
            mapped=sg['tensors'][source['output']]
            self.assertEqual(r['values'][r['result']]['shape'],mapped['shape'])
        self.assertEqual(sum(o['kind']=='rotary_frequency_scale' for o in eg['operations']),len(rotary) if kind=='linear' else 0)
        return full

    def test_01_modes_factors_words_and_bases(self):
        choices=[('default',1.0,64),('default',1.0,32),('linear',0.5,64),('linear',1.0,32),('linear',1.5,64),('linear',8.0,32)]
        for scalar,mode,returned,(kind,factor,width),shards in itertools.product(('source64','requested32'),('full_prefix','cached_append'),(0,1),choices,(1,3)):
            config,roles=declared(attention=True,mlp=True,dimension=4,explicit=True)
            root,expected=self.collection(config,roles,shards=shards,dtypes=('BF16','F16','F32'));past=0 if mode=='full_prefix' else 3
            self.check(self.accept(self.invoke(root,scalar=scalar,mode=mode,returned=returned,past=past,kind=kind,factor=factor,width=width,shards=shards)),expected,mode,returned,0,'invocation',kind=kind,factor=factor,width=width)
        config,roles=declared(attention=True,mlp=True,dimension=4,explicit=True);root,expected=self.collection(config,roles)
        for mask,pairing,dim in itertools.product(('0,0','1,0','1,1'),('adjacent','split_half'),(2,4)):
            full=self.check(self.accept(self.invoke(root,mask=mask,pairing=pairing,rope_dim=dim)),expected,'full_prefix',1,0,'invocation')
            self.assertEqual(len(full['rotary_mappings']),2*sum(map(int,mask.split(','))))

    def test_02_qualified_source_projection_and_raw_owners(self):
        rows=json.loads(Path(CONFIG.oracle).read_text())['cases']
        for row in rows:
            config,roles=declared(layers=4,hidden=16);config.update(row['input'])
            root,_=self.collection(config,roles)
            run=self.child([CONFIG.source,root,'source-0.weights','config.json',1000000,PROVENANCE,'valid'])
            raw=config['rope_scaling'];kind='default' if raw is None else raw.get('type',raw.get('rope_type'))
            factor=1.0 if kind=='default' else raw.get('factor') if raw else None
            allowed=kind in ('default','linear') and type(factor) in (int,float) and math.isfinite(factor) and factor>0
            if not allowed:self.refuse(run);continue
            obj=self.accept(run);p=obj['scaling_policy']
            self.assertEqual(p['kind'],kind);self.assertEqual(p['factor'],dict(width=64,bits=bits(factor)))
            self.assertEqual(p['origin'],'source:null' if raw is None else 'source:legacy' if 'type' in raw else 'source:modern')
            fields=obj['original_source']['binding']['architecture']['layers']['source']['fields_raw']
            for key,value in config.items():self.assertEqual(json.loads(fields[key]),value)
        config,roles=declared(attention=True,mlp=True);root,_=self.collection(config,roles)
        absent=self.accept(self.child([CONFIG.source,root,'source-0.weights','config.json',1000000,PROVENANCE,'valid']))
        self.assertEqual(absent['scaling_policy']['origin'],'source:absent')
        for raw in (None,{'rope_type':'default','factor':{'dormant':['æ']}},{'type':'linear','rope_type':'dynamic','factor':1.5},{'rope_type':'linear','factor':0.5},{'type':'default','rope_type':'linear','factor':{'dormant':'æ'}}):
            config['rope_scaling']=raw;(root/'config.json').write_text(json.dumps(config))
            obj=self.accept(self.invoke(root,kind='source'));selected='default' if raw is None else raw.get('type',raw.get('rope_type'))
            self.assertEqual(obj['lowered']['source_graph']['scaling_policy']['kind'],selected)
        config['rope_scaling']={'rope_type':'linear','factor':2};(root/'config.json').write_text(json.dumps(config))
        for case in ('source_flag','source_origin','source_layer','source_work','source_scaling'):
            self.refuse(self.child([CONFIG.source,root,'source-0.weights','config.json',1000000,PROVENANCE,case]))
        for raw in ({},{'rope_type':None},{'rope_type':'linear'},{'rope_type':'linear','factor':True},{'rope_type':'linear','factor':None},{'rope_type':'future','factor':2},{'type':None,'rope_type':'linear','factor':2}):
            config['rope_scaling']=raw;(root/'config.json').write_text(json.dumps(config));self.refuse(self.invoke(root,kind='source'))
        text=json.dumps(config);(root/'config.json').write_text(text.replace('"rope_scaling": '+json.dumps(raw),'"rope_scaling":{"rope_type":"linear","rope_type":"default","factor":2}'))
        self.refuse(self.invoke(root,kind='source'))

    def test_03_policy_exact_budgets_and_scalar_words(self):
        cases=[('default',32,bits(1,32),'invocation'),('default',64,bits(1),'source:absent'),('default',64,bits(1),'source:null')]
        for width in (32,64):
            for factor in (0.5,1,1.5,2,8,1e-30,1e30):cases.append(('linear',width,bits(factor,width),'invocation'))
        cases.extend([('linear',64,1,'invocation'),('linear',64,0x7fefffffffffffff,'invocation')])
        for kind,width,word,origin in cases:
            charge=160+len(kind.encode())+len(origin.encode())+len('æ𝄞'.encode())
            for work,accepted in ((charge,True),(charge-1,False)):
                run=self.child([CONFIG.policy,kind,width,word,origin,'æ𝄞',work,1000000])
                if accepted:self.assertEqual(self.accept(run)['charged_work'],charge)
                else:self.refuse(run)
        for kind,width,word,origin,provenance,work,bound in [('future',64,bits(1),'invocation','p',1000,1000),('default',64,bits(2),'invocation','p',1000,1000),('linear',16,bits(1),'invocation','p',1000,1000),('linear',32,1<<32,'invocation','p',1000,1000),('linear',64,0,'invocation','p',1000,1000),('linear',64,0x7ff0000000000000,'invocation','p',1000,1000),('linear',64,0x7ff8000000000000,'invocation','p',1000,1000),('linear',64,bits(-1),'invocation','p',1000,1000),('linear',64,bits(1),'changed','p',1000,1000),('linear',64,bits(1),'invocation','',1000,1000),('linear',32,bits(1,32),'source:modern','p',1000,1000),('default',32,bits(1,32),'source:null','p',1000,1000),('linear',64,bits(1),'invocation','p',0,1000),('linear',64,bits(1),'invocation','p',1001,1000)]:self.refuse(self.child([CONFIG.policy,kind,width,word,origin,provenance,work,bound]))
        config,roles=declared(attention=True,mlp=True);config.update(rope_theta=1.0000000000000002,rms_norm_eps=0.0000010000000000000002,rope_scaling={'rope_type':'linear','factor':1.0000000000000002})
        root,_=self.collection(config,roles)
        obj=self.accept(self.invoke(root,kind='source'))['lowered'];self.assertEqual(obj['source_graph']['scaling_policy']['factor'],dict(width=64,bits=bits(config['rope_scaling']['factor'])))
        self.assertEqual(obj['source_graph']['source_scalars']['rope_base']['bits'],bits(config['rope_theta']))
        self.assertEqual(obj['source_graph']['source_scalars']['epsilon']['bits'],bits(config['rms_norm_eps']))

    def test_04_all_mutations_refuse_and_recover(self):
        config,roles=declared(attention=True,mlp=True);root,_=self.collection(config,roles)
        variants=list(dict.fromkeys(re.findall(r'variant == "([a-z_]+)"',Path('tests/hailo_decoder_scaling_api.mojo').read_text())))
        variants=[v for v in variants if v!='layout']
        for scalar,mode,returned,case in itertools.product(('source64','requested32'),('full_prefix','cached_append'),(0,1),variants):
            r=self.api_call(root,scalar,mode,returned,0 if mode=='full_prefix' else 1,case=case);self.refuse(r)
            self.assertNotIn('unexpected consumer accepted',r.stderr);self.assertNotIn('unexpected implicit basis acceptance',r.stderr)
        self.accept(self.api_call(root))

    def test_05_owned_state_recovery_header_bounds(self):
        # Reuse the independently traced descriptor/unchanged-byte oracle, invoking
        # this suite's scaling-aware check and original native ownership probe.
        window.DecoderWindow.test_05_owned_state_recovery_header_bounds(self)

    def test_06_frozen_complete_outputs_and_storage_consumers(self):
        config,roles=declared(attention=True,mlp=True);root,expected=self.collection(config,roles)
        for scalar,mode,returned in itertools.product(('source64','requested32'),('full_prefix','cached_append'),(0,1)):
            past=0 if mode=='full_prefix' else 1
            frozen=self.accept(self.child([CONFIG.frozen_api,root,'source-0.weights','config.json',scalar,mode,returned,past,8,'3,1','valid']))
            # Use the complete ordinary inspector and identical frozen arguments.
            args=['unindexed',root,'source-0.weights','config.json',2,past,8,2,'1,0','1,1','1,1',scalar,'split_half',1000000,PROVENANCE,'gelu_erf,relu',mode,returned,'3,1']
            oldobj=self.accept(self.child([CONFIG.frozen_binary,*args]));newobj=self.accept(self.child([self.binary,*args,'default',64,bits(1)]))
            self.assertEqual(normalize(newobj['lowered']),oldobj['lowered']);self.assertEqual(newobj['original_source'],oldobj['original_source'])
            layout=self.accept(self.api_call(root,scalar,mode,returned,past,case='layout'));self.assertEqual(layout['matrix_schedules'],15);self.assertEqual(layout['cache_bytes']==0,mode=='full_prefix')
            self.assertEqual(frozen['source_graph']['parameters']['past_tokens'],past)
        from test_hailo_semantic_plan import dense_fixture
        for scalar,mode,returned,biased in itertools.product(('source32','legacy32'),('full_prefix','cached_append'),(0,1),(False,True)):
            extras=[]
            if biased:
                for layer in range(2):extras.extend((f'blk.{layer}.{name}.bias',width,1,0) for name,width in zip(('attn_q','attn_k','attn_v','attn_output','ffn_gate','ffn_up','ffn_down'),(12,6,10,8,12,12,8)))
            raw,_,_=dense_fixture(layers=2,key=3,value=5,extra_tensors=extras);p=self.root/(f'scaling-{len(self.records)}.gguf');p.write_bytes(raw);past=0 if mode=='full_prefix' else 1
            args=[p,'1,1' if biased else '0,0','1,1' if biased else '0,0','1,0',scalar,'gelu_erf,relu',mode,returned,past,8,'3,1']
            oldobj=self.accept(self.child([CONFIG.frozen_gguf,*args]));newobj=self.accept(self.child([CONFIG.gguf,*args,'default',64,bits(1)]));self.assertEqual(normalize(newobj),oldobj)
            self.accept(self.child([CONFIG.gguf,*args,'linear',32,bits(1.5,32)]))
        for returned in (0,1):
            self.accept(self.api_call(root,returned=returned,capacity=9223372036854775807));self.refuse(self.api_call(root,mode='cached_append',past=1,capacity=9223372036854775807))
        for query,past in ((1,0),(1,3),(3,1)):
            self.check(self.accept(self.invoke(root,mode='cached_append',query=query,past=past)),expected,'cached_append',1,0,'invocation')

    def test_07_isolated_real_formula_and_qualified_constant_words(self):
        oracle=json.loads(Path(CONFIG.constant_oracle).read_text());self.assertEqual(oracle['case_count'],48)
        decimal.getcontext().prec=100;words=0
        for row in oracle['cases']:
            d=row['width'];theta=decimal.Decimal(str(row['theta']));factor=decimal.Decimal(str(row['factor']))
            for j,(default,scaled) in enumerate(zip(row['default_f32_words'],row['linear_f32_words'])):
                before=number(dict(width=32,bits=default));after=number(dict(width=32,bits=scaled))
                self.assertEqual(scaled,bits(before/float(factor),32));real=(theta**(-decimal.Decimal(2*j)/d))/factor
                self.assertLess(abs(decimal.Decimal(after)-real)/abs(real),decimal.Decimal('0.00000033'));words+=1
            config,roles=declared(attention=True,mlp=True,hidden=4*d,dimension=d,explicit=True);config['rope_theta']=row['theta'];root,expected=self.collection(config,roles)
            self.check(self.accept(self.invoke(root,factor=row['factor'],rope_dim=d)),expected,'full_prefix',1,0,'invocation',factor=row['factor'])
        self.assertEqual(words,120)

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for name in ('binary','api','source','ownership','gguf','policy','frozen-api','frozen-binary','frozen-gguf','oracle','constant-oracle','strace','evidence'):parser.add_argument('--'+name,required=True)
    CONFIG,remaining=parser.parse_known_args();old.CONFIG=CONFIG;window.CONFIG=CONFIG
    unittest.main(argv=[__file__,*remaining],verbosity=2)
