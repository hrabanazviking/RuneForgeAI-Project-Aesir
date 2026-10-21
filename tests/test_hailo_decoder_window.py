#!/usr/bin/env python3
"""Independent integer/graph/storage checks; never model or attention forwards."""
import argparse,copy,itertools,json,math,re,struct,unittest
from pathlib import Path
import test_hailo_decoder_projections as old
from test_hailo_ordinary_projection_schema import declared

CONFIG=argparse.Namespace()
PROVENANCE="explicit synthetic session recipe"


def normalize(obj):
    obj=copy.deepcopy(obj)
    for key in ("source_graph","recipes","expanded"):
        obj[key].pop("window_policy");obj[key]["schema_version"]=5
    for o in obj["source_graph"]["operations"]:o.pop("window_tokens")
    for r in obj["recipes"]["recipes"]:r.pop("window_tokens")
    for o in obj["expanded"]["operations"]:o.pop("window_tokens")
    obj["storage"].pop("index_live_bytes")
    return obj


class DecoderWindow(unittest.TestCase):
    setUpClass=classmethod(old.DecoderProjections.setUpClass.__func__)
    tearDownClass=classmethod(old.DecoderProjections.tearDownClass.__func__)
    child=old.DecoderProjections.child
    accept=old.DecoderProjections.accept
    refuse=old.DecoderProjections.refuse
    collection=old.DecoderProjections.collection

    def invoke(self,root,mode="full_prefix",returned=1,past=0,scalar="source64",windows="3,1",shards=1,query=2,work=1000000,provenance=PROVENANCE,capacity=8,bias="1,1"):
        return self.child([self.binary,"unindexed" if shards==1 else "indexed",root,"source-0.weights" if shards==1 else "index.json","config.json",query,past,capacity,2,"1,0",bias,bias,scalar,"split_half",work,provenance,"gelu_erf,relu",mode,returned,windows])

    def api_call(self,root,scalar="source64",mode="full_prefix",returned=1,past=0,capacity=8,windows="3,1",case="valid"):
        return self.child([self.api,root,"source-0.weights","config.json",scalar,mode,returned,past,capacity,windows,case])

    def check(self,obj,expected,mode,returned,source_returned=0,origin="source",provenance=PROVENANCE,windows=(3,1),window_origin="invocation",window_provenance=PROVENANCE):
        if "lowered" in obj:
            self.assertFalse(obj["ordinary_model_admitted"]);self.assertFalse(obj["device_execution_verified"])
            obj=obj["lowered"]
        sg,rs,eg=(obj[k] for k in ("source_graph","recipes","expanded"))
        policy=sg["session_policy"];layers=sg["parameters"]["layers"];query=sg["parameters"]["query_tokens"]
        past=sg["parameters"]["past_tokens"];total=past+query;capacity=sg["parameters"]["context_capacity"]
        self.assertEqual(policy,dict(mode=mode,return_cache=returned,source_return_cache=source_returned,return_origin=origin,provenance=provenance,work=policy["work"],charged_work=128*layers+2+len(mode.encode())+len(origin.encode())+len(provenance.encode())))
        for owner in (sg,rs,eg):self.assertEqual(owner["schema_version"],6);self.assertEqual(owner["session_policy"],policy)
        ts=sg["tensors"];ops=sg["operations"];vs=eg["values"];expanded=eg["operations"]
        names={t["name"]:t for t in ts};exports=[];full=mode=="full_prefix"
        self.assertEqual(len(sg["weights"]),len(expected["bindings"]))
        for name,binding in sg["weights"].items():self.assertEqual(binding,{k:expected["bindings"][name][k] for k in ("file_offset","columns","rows","source_kind","byte_count")})
        self.assertEqual(sum(t["persistent"] for t in ts),0 if full else 2*layers)
        self.assertEqual(sum(t["alias_of"]!=-1 for t in ts),0 if full else 2*layers)
        self.assertEqual(sum(o["kind"] in ("kv_append_keys","kv_append_values") for o in ops),0 if full else 2*layers)
        for desc in (sg,eg):self.assertEqual("kv_prefix_initialized_through_past" in desc["runtime_preconditions"],not full)
        for layer in range(layers):
            p=f"blk.{layer}.";bias=sg["bias_policy"]["attention"][layer]
            # Resolve actual typed choice by source identity, independently of IDs.
            selected={}
            for letter in ("q","k","v"):
                raw=names[p+letter];op=ops[raw["producer"]]
                self.assertEqual(op["kind"],"linear");self.assertEqual(op["weight"],p+"attn_"+letter+".weight")
                self.assertEqual(op["inputs"],[names[p+"attn_norm"]["id"]])
                selected[letter]=names[p+letter+"_biased"]["id"] if bias else raw["id"]
                if p+letter+"_rotary" in names:
                    rot=names[p+letter+"_rotary"];self.assertEqual(ops[rot["producer"]]["inputs"],[selected[letter],names["positions"]["id"]]);selected[letter]=rot["id"]
            if full:
                self.assertEqual(past,0)
                for suffix in ("key_cache","value_cache","keys_view","values_view"):self.assertNotIn(p+suffix,names)
                key,value=selected["k"],selected["v"]
            else:
                key,value=(names[p+s]["id"] for s in ("keys_view","values_view"))
                for suffix,kind,writer in (("keys_view","keys",selected["k"]),("values_view","values",selected["v"])):
                    view=names[p+suffix];base=names[p+("key_cache" if kind=="keys" else "value_cache")]
                    self.assertEqual(ops[view["producer"]]["kind"],"kv_append_"+kind)
                    self.assertEqual(ops[view["producer"]]["inputs"],[base["id"],writer]);self.assertEqual(view["alias_of"],base["id"])
                    self.assertEqual(base["shape"][0],capacity);self.assertEqual(view["shape"][0],total)
            self.assertEqual(ops[names[p+"scores"]["producer"]]["inputs"],[selected["q"],key])
            self.assertEqual(ops[names[p+"attention"]["producer"]]["inputs"],[names[p+"probabilities"]["id"],value])
            self.assertEqual(names[p+"scores"]["shape"],[sg["parameters"]["heads"],query,total])
            if returned:exports.extend([key,value])
        self.assertEqual(sg["cache_exports"],exports);self.assertEqual(rs["cache_exports"],exports)
        global_exports=[eg["source_to_global"][i] for i in exports];self.assertEqual(eg["cache_exports"],global_exports)
        for t in ts:
            self.assertEqual(t["elements"],math.prod(t["shape"]))
            last=max([t["producer"]]+[o["id"] for o in ops if t["id"] in o["inputs"]])
            if t["persistent"] or t["id"]==sg["logits"] or t["id"] in exports:last=len(ops)
            self.assertEqual(t["last_use"],last)
            mapped=vs[eg["source_to_global"][t["id"]]]
            self.assertEqual(mapped["source_tensor"],t["id"]);self.assertEqual(mapped["name"],t["name"])
            self.assertEqual(mapped["shape"],t["shape"]);self.assertEqual(mapped["elements"],t["elements"])
        for recipe in rs["recipes"]:
            sourceop=ops[recipe["source_operation"]]
            self.assertEqual(sourceop["kind"],recipe["kind"])
            self.assertEqual(recipe["source_output"],sourceop["output"])
            self.assertEqual(recipe["source_inputs"],sourceop["inputs"])
            local={i:eg["source_to_global"][source] for i,source in zip(recipe["input_values"],recipe["source_inputs"])}
            if recipe["weight_name"]:local[1]=eg["weights"][recipe["weight_name"]]["value"]
            actual=[o for o in expanded if o["source_operation"]==recipe["source_operation"]]
            self.assertEqual(len(actual),len(recipe["operations"]))
            for step,(a,b) in enumerate(zip(actual,recipe["operations"])):
                self.assertEqual(a["kind"],b["kind"]);self.assertEqual(a["recipe_step"],step)
                self.assertEqual(a["inputs"],[local[i] for i in b["inputs"]]);local[b["output"]]=a["output"]
            self.assertEqual(local[recipe["result"]],eg["source_to_global"][sourceop["output"]])
        sizes=[]
        for v in vs:
            self.assertEqual(v["elements"],math.prod(v["shape"]))
            last=max([v["producer"]]+[o["id"] for o in expanded if v["id"] in o["inputs"]])
            if v["storage"] in ("source_weight","persistent_kv") or v["id"]==eg["result"] or v["id"] in global_exports:last=len(expanded)
            self.assertEqual(v["last_use"],last)
            width=8 if v["domain"]=="index" else 1 if v["domain"]=="predicate" else 2
            sizes.append(0 if v["storage"] in ("source_weight","kv_view") else (v["elements"]*width+15)//16*16)
        storage=obj["storage"];self.assertEqual(storage["value_bytes"],sizes)
        real=[];predicate=[];indices=[]
        for i in range(len(expanded)+1):
            real.append(sum(sizes[v["id"]] for v in vs if v["storage"]=="activation" and v["domain"]=="real" and v["producer"]<=i<=v["last_use"]))
            indices.append(sum(sizes[v["id"]] for v in vs if v["storage"]=="activation" and v["domain"]=="index" and v["producer"]<=i<=v["last_use"]))
            predicate.append(sum(sizes[v["id"]] for v in vs if v["storage"]=="activation" and v["domain"]=="predicate" and v["producer"]<=i<=v["last_use"]))
        self.assertEqual(storage["real_live_bytes"],real);self.assertEqual(storage["predicate_live_bytes"],predicate)
        self.assertEqual(storage["index_live_bytes"],indices)
        self.assertEqual(storage["activation_live_bytes"],[a+b+c for a,b,c in zip(real,predicate,indices)])
        self.assertEqual(storage["peak_activation_bytes"],max(a+b+c for a,b,c in zip(real,predicate,indices)))
        self.assertEqual(storage["persistent_kv_bytes"],sum(sizes[v["id"]] for v in vs if v["storage"]=="persistent_kv"))
        self.assertEqual(storage["input_bytes"],sum(sizes[v["id"]] for v in vs if v["storage"]=="index"))
        self.assertEqual(storage["total_bytes"],expected["payload"]+storage["persistent_kv_bytes"]+storage["input_bytes"]+storage["peak_activation_bytes"])
        expected_policy=dict(windows=list(windows),origin=window_origin,provenance=window_provenance,work=sg["window_policy"]["work"],charged_work=129*layers+len(window_origin.encode())+len(window_provenance.encode()))
        for owner in (sg,rs,eg):self.assertEqual(owner["window_policy"],expected_policy)
        selected=[]
        for layer,width in enumerate(windows):
            t=names[f"blk.{layer}.masked_scores"];op=ops[t["producer"]]
            self.assertEqual(op["window_tokens"],width)
            self.assertEqual(op["kind"],"causal_window_mask" if width else "causal_mask")
            self.assertEqual(op["inputs"],[names[f"blk.{layer}.scores"]["id"],names["positions"]["id"]])
            if width:selected.append(op["id"])
        for op in ops:
            if op["kind"]!="causal_window_mask":self.assertEqual(op["window_tokens"],0)
        actual=[r for r in rs["recipes"] if r["kind"]=="causal_window_mask"]
        self.assertEqual([r["source_operation"] for r in actual],selected)
        for r in rs["recipes"]:
            if r["kind"]!="causal_window_mask":self.assertEqual(r["window_tokens"],0);continue
            layer=next(i for i in range(layers) if names[f"blk.{i}.masked_scores"]["id"]==r["source_output"])
            self.assertEqual(r["window_tokens"],windows[layer]);self.assertEqual(r["input_values"],[0,1]);self.assertEqual(r["source_input"],r["source_inputs"][0])
            self.assertEqual([(x["kind"],x["inputs"],x["output"]) for x in r["operations"]],[("prefix_key_indices",[],2),("causal_window_predicate",[1,2],3),("select_negative_infinity",[0,3],4)])
            self.assertEqual([(x["shape"],x["domain"],x["producer"],x["last_use"]) for x in r["values"]],[(names[f"blk.{layer}.scores"]["shape"],"real",-1,2),([query],"index",-1,1),([total],"index",0,1),([query,total],"predicate",1,2),(t["shape"],"real",2,3)])
        for op in expanded:
            match=next((r for r in actual if r["source_operation"]==op["source_operation"]),None)
            self.assertEqual(op["window_tokens"],match["window_tokens"] if match else 0)
        return obj

    def test_01_modes_widths_scalar_and_export_grid(self):
        for scalar,mode,returned,widths,shards in itertools.product(("source64","requested32"),("full_prefix","cached_append"),(0,1),((0,0),(1,1),(3,1),(0,4),(9223372036854775807,2)),(1,3)):
            config,roles=declared(attention=True,mlp=True,dimension=4,explicit=True)
            root,expected=self.collection(config,roles,shards=shards,dtypes=("BF16","F16","F32"));past=0 if mode=="full_prefix" else 3
            self.check(self.accept(self.invoke(root,scalar=scalar,mode=mode,returned=returned,past=past,windows=','.join(map(str,widths)),shards=shards)),expected,mode,returned,0,"invocation",windows=widths)

    def test_02_qualified_source_patterns_and_complete_owner(self):
        oracle=json.loads(Path(CONFIG.oracle).read_text())
        for row in oracle['cases']:
            config,roles=declared(layers=4);config.update(row['input'])
            root,expected=self.collection(config,roles)
            result=self.child([CONFIG.source,root,"source-0.weights","config.json",1000000,PROVENANCE,"valid"])
            if 'error' in row:self.refuse(result);continue
            obj=self.accept(result);want=[row['result']['sliding_window'] if kind=='sliding_attention' else 0 for kind in row['result']['layer_types']]
            self.assertEqual(obj['window_policy']['windows'],want)
            fields=obj['original_source']['binding']['architecture']['layers']['source']['fields_raw']
            for key,value in config.items():self.assertEqual(json.loads(fields[key]),value)
        config,roles=declared();config.update(layer_types=['full_attention']*2,sliding_window=3,no_rope_layers=[1,0])
        root,_=self.collection(config,roles)
        for case in ('source_flag','source_origin','source_layer','source_work','source_window','source_types','source_rope'):
            self.refuse(self.child([CONFIG.source,root,"source-0.weights","config.json",1000000,PROVENANCE,case]))
        for fields,widths in (({},(0,0)),({'layer_types':None,'use_sliding_window':True,'sliding_window':3,'no_rope_layers':[1,0]},(0,3)),({'layer_types':['sliding_attention','full_attention'],'use_sliding_window':False,'sliding_window':2},(2,0))):
            config,roles=declared(attention=True,mlp=True);config.update(fields);root,expected=self.collection(config,roles)
            self.check(self.accept(self.invoke(root,windows='source')),expected,'full_prefix',1,0,'invocation',windows=widths,window_origin='source')
        for fields in ({'layer_types':['sliding_attention']*2,'sliding_window':None},{'layer_types':['future']*2},{'sliding_window':0},{'sliding_window':-1},{'sliding_window':True}):
            config,roles=declared();config.update(fields);root,_=self.collection(config,roles)
            self.refuse(self.child([CONFIG.source,root,"source-0.weights","config.json",1000000,PROVENANCE,"valid"]))

    def test_03_policy_work_boundaries_and_source_words(self):
        config,roles=declared();root,expected=self.collection(config,roles)
        for origin in ('invocation','source'):
            exact=258+len(origin)+len(PROVENANCE.encode())
            for work in (exact-1,0,-1,10000001,9223372036854775807):
                self.refuse(self.child([CONFIG.policy,'0,3',origin,PROVENANCE,work,2,1000000]))
            obj=self.accept(self.child([CONFIG.policy,'0,3',origin,PROVENANCE,exact,2,1000000]));self.assertEqual(obj,dict(windows=[0,3],origin=origin,provenance=PROVENANCE,work=exact,charged_work=exact))
        exact_source=258+6+len(PROVENANCE.encode())
        obj=self.accept(self.child([CONFIG.source,root,'source-0.weights','config.json',exact_source,PROVENANCE,'valid']));self.assertEqual(obj['window_policy']['charged_work'],exact_source)
        self.refuse(self.child([CONFIG.source,root,'source-0.weights','config.json',exact_source-1,PROVENANCE,'valid']))
        for width in ('','-1,2','1','1,2,3','1,future','9223372036854775808,1'):
            self.refuse(self.invoke(root,windows=width,bias='0,0'))
        for layers in (0,-1,9223372036854775807):self.refuse(self.child([CONFIG.policy,'0,3','source',PROVENANCE,9223372036854775807,layers,9223372036854775807]))
        utf8='æ𝄞 window';exact=258+10+len(utf8.encode())
        obj=self.accept(self.child([CONFIG.policy,'0,1','invocation',utf8,exact,2,1000000]));self.assertEqual(obj['charged_work'],exact)
        self.refuse(self.invoke(root,provenance='',bias='0,0'))
        config,roles=declared(attention=True,mlp=True)
        for epsilon,theta in ((5e-324,1e300),(1e300,1e-300)):
            config.update(rms_norm_eps=epsilon,rope_theta=theta);root,expected=self.collection(config,roles)
            obj=self.check(self.accept(self.invoke(root)),expected,'full_prefix',1,0,'invocation')
            scalars=obj['source_graph']['source_scalars']
            self.assertEqual(scalars['epsilon']['bits'],struct.unpack('<Q',struct.pack('<d',epsilon))[0]);self.assertEqual(scalars['rope_base']['bits'],struct.unpack('<Q',struct.pack('<d',theta))[0])
            self.refuse(self.invoke(root,scalar='requested32'))

    def test_04_all_mutations_refuse_and_recover(self):
        config,roles=declared(attention=True,mlp=True);root,_=self.collection(config,roles)
        variants=list(dict.fromkeys(re.findall(r'variant == "([a-z_]+)"',Path('tests/hailo_decoder_window_api.mojo').read_text())))
        variants=[v for v in variants if v!='layout']
        for scalar,mode,returned,case in itertools.product(('source64','requested32'),('full_prefix','cached_append'),(0,1),variants):
            result=self.api_call(root,scalar,mode,returned,0 if mode=='full_prefix' else 1,case=case);self.refuse(result);self.assertNotIn('unexpected consumer accepted',result.stderr)
        self.accept(self.api_call(root))

    def test_05_owned_state_recovery_header_bounds(self):
        config,roles=declared(attention=True,mlp=True);root,expected=self.collection(config,roles)
        source_files=dict(expected['raw_files'])
        for name in ('config.json','index.json'):source_files[root/name]=(root/name).read_bytes()
        for scalar,mode,returned in itertools.product(('source64','requested32'),('full_prefix','cached_append'),(0,1)):
            obj=self.accept(self.child([CONFIG.ownership,root,'source-0.weights','config.json',scalar,mode,returned],f'{mode}-{scalar}-{returned}.strace'))
            self.check(obj,expected,mode,returned,0,'invocation','session API test provenance',window_provenance='window API test provenance')
        for path,raw in source_files.items():self.assertEqual(path.read_bytes(),raw)
        for trace in self.evidence.glob('*.strace'):
            text=trace.read_text()
            for bad in ('/dev/h1x-','libcuda','libhailort','libggml','ioctl('):self.assertNotIn(bad,text)
            for path in [*expected['raw_files'],root/'config.json',root]:
                opens=sum(('openat(' in l or 'openat2(' in l) and (json.dumps(path.name) in l or json.dumps(str(path)) in l) for l in text.splitlines());closes=sum('close(' in l and '<'+str(path)+'>' in l for l in text.splitlines())
                self.assertEqual(opens,closes);self.assertGreater(closes,20)
            for line in text.splitlines():
                if 'mmap(' in line:self.assertNotIn('.weights>',line)
                m=re.search(r'pread64\(\d+<([^>]+)>, .*, (\d+), (\d+)\) = (\d+)',line)
                if m and m[1] in expected['files']:self.assertLessEqual(int(m[3])+int(m[4]),expected['files'][m[1]]['data_offset'])

    def test_06_frozen_full_outputs_and_storage_consumers(self):
        config,roles=declared(attention=True,mlp=True);root,expected=self.collection(config,roles)
        for scalar,mode,returned in itertools.product(('source64','requested32'),('full_prefix','cached_append'),(0,1)):
            past=0 if mode=='full_prefix' else 1
            after=self.accept(self.api_call(root,scalar,mode,returned,past,windows='0,0'))
            before=self.accept(self.child([CONFIG.frozen_api,root,'source-0.weights','config.json','1,1','1,1',scalar,'gelu_erf,relu',mode,returned,past,8,'valid']))
            self.assertEqual(normalize(after),before)
            layout=self.accept(self.api_call(root,scalar,mode,returned,past,case='layout'))
            self.assertEqual(layout['matrix_schedules'],15);self.assertEqual(layout['cache_bytes']==0,mode=='full_prefix');self.assertEqual(layout['persistent_bytes']==0,mode=='full_prefix')
        from test_hailo_semantic_plan import dense_fixture
        for scalar,mode,returned,biased in itertools.product(('source32','legacy32'),('full_prefix','cached_append'),(0,1),(False,True)):
            extras=[]
            if biased:
                for layer in range(2):
                    extras.extend((f'blk.{layer}.{name}.bias',width,1,0) for name,width in zip(('attn_q','attn_k','attn_v','attn_output','ffn_gate','ffn_up','ffn_down'),(12,6,10,8,12,12,8)))
            raw,_,_=dense_fixture(layers=2,key=3,value=5,extra_tensors=extras)
            p=self.root/(f'window-{len(self.records)}.gguf');p.write_bytes(raw);past=0 if mode=='full_prefix' else 1
            args=[p,'1,1' if biased else '0,0','1,1' if biased else '0,0','1,0',scalar,'gelu_erf,relu',mode,returned,past,8]
            oldobj=self.accept(self.child([CONFIG.frozen_gguf,*args]));newobj=self.accept(self.child([CONFIG.gguf,*args,'0,0']));self.assertEqual(normalize(newobj),oldobj)
            positive=self.accept(self.child([CONFIG.gguf,*args,'3,1']));self.assertEqual(positive['source_graph']['window_policy']['windows'],[3,1])
        for returned in (0,1):
            self.accept(self.api_call(root,returned=returned,capacity=9223372036854775807))
            self.refuse(self.api_call(root,mode='cached_append',past=1,capacity=9223372036854775807))
        for query,past in ((1,0),(1,3),(3,1)):
            self.check(self.accept(self.invoke(root,mode='cached_append',query=query,past=past)),expected,'cached_append',1,0,'invocation')

    def test_07_independent_integer_oracle_and_extremes(self):
        rows=self.accept(self.child([CONFIG.indices,'grid']));self.assertEqual(len(rows),2720)
        for q,k,w,a in rows:self.assertEqual(a,k<=q and (w==0 or k>=max(0,q-w+1)))
        oracle=json.loads(Path(CONFIG.index_oracle).read_text())
        indexed={(q,k,w):a for q,k,w,a in rows}
        for row in oracle['rows']:
            self.assertEqual([k for k in range(20) if indexed[row['query'],k,row['window']]],row['admitted'])
        maximum=9223372036854775807
        for q,k,w in ((maximum,maximum,1),(maximum,maximum-1,1),(maximum,0,maximum),(maximum-1,0,maximum),(0,maximum,maximum),(maximum,0,0)):
            result=self.accept(self.child([CONFIG.indices,q,k,w]));self.assertEqual(result['admitted'],k<=q and (w==0 or q-k<w))
        for q,k,w in ((-1,0,1),(0,-1,1),(0,0,-1),(-9223372036854775808,0,1)):
            self.refuse(self.child([CONFIG.indices,q,k,w]))


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for name in ('binary','api','source','ownership','gguf','indices','policy','frozen-api','frozen-gguf','oracle','index-oracle','strace','evidence'):parser.add_argument('--'+name,required=True)
    CONFIG,remaining=parser.parse_known_args();old.CONFIG=CONFIG
    unittest.main(argv=[__file__,*remaining],verbosity=2)
