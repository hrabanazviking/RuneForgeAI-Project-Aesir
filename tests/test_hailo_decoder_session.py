#!/usr/bin/env python3
"""Independent graph/index/export/storage checks; never an attention/model forward."""
import argparse
import copy
import itertools
import json
import math
from pathlib import Path
import re
import struct
import unittest
import test_hailo_decoder_projections as old
from test_hailo_ordinary_projection_schema import declared

CONFIG=argparse.Namespace()
PROVENANCE="explicit synthetic session recipe"


def normalize(obj):
    obj=copy.deepcopy(obj)
    for key in ("source_graph","recipes","expanded"):
        obj[key].pop("session_policy");obj[key].pop("cache_exports");obj[key]["schema_version"]=4
    return obj


class DecoderSession(unittest.TestCase):
    setUpClass=classmethod(old.DecoderProjections.setUpClass.__func__)
    tearDownClass=classmethod(old.DecoderProjections.tearDownClass.__func__)
    child=old.DecoderProjections.child
    accept=old.DecoderProjections.accept
    refuse=old.DecoderProjections.refuse
    collection=old.DecoderProjections.collection

    def invoke(self,root,mode="full_prefix",returned=-1,past=0,scalar="source64",attention="1,1",mlp="1,1",kinds="gelu_erf,relu",shards=1,work=1000000,provenance=PROVENANCE,capacity=8,pairing="split_half",trace=None):
        return self.child([self.binary,"unindexed" if shards==1 else "indexed",root,"source-0.weights" if shards==1 else "index.json","config.json",2,past,capacity,2,"1,0",attention,mlp,scalar,pairing,work,provenance,kinds,mode,returned],trace)

    def api_call(self,root,mode="full_prefix",returned=1,past=0,capacity=8,scalar="source64",case="valid",attention="1,1",mlp="1,1"):
        return self.child([self.api,root,"source-0.weights","config.json",attention,mlp,scalar,"gelu_erf,relu",mode,returned,past,capacity,case])

    def check(self,obj,expected,mode,returned,source_returned=0,origin="source",provenance=PROVENANCE):
        if "lowered" in obj:
            self.assertFalse(obj["ordinary_model_admitted"]);self.assertFalse(obj["device_execution_verified"])
            obj=obj["lowered"]
        sg,rs,eg=(obj[k] for k in ("source_graph","recipes","expanded"))
        policy=sg["session_policy"];layers=sg["parameters"]["layers"];query=sg["parameters"]["query_tokens"]
        past=sg["parameters"]["past_tokens"];total=past+query;capacity=sg["parameters"]["context_capacity"]
        self.assertEqual(policy,dict(mode=mode,return_cache=returned,source_return_cache=source_returned,return_origin=origin,provenance=provenance,work=policy["work"],charged_work=128*layers+2+len(mode.encode())+len(origin.encode())+len(provenance.encode())))
        for owner in (sg,rs,eg):self.assertEqual(owner["schema_version"],5);self.assertEqual(owner["session_policy"],policy)
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
            width=8 if v["storage"]=="index" else 1 if v["domain"]=="predicate" else 2
            sizes.append(0 if v["storage"] in ("source_weight","kv_view") else (v["elements"]*width+15)//16*16)
        storage=obj["storage"];self.assertEqual(storage["value_bytes"],sizes)
        real=[];predicate=[]
        for i in range(len(expanded)+1):
            real.append(sum(sizes[v["id"]] for v in vs if v["storage"]=="activation" and v["domain"]=="real" and v["producer"]<=i<=v["last_use"]))
            predicate.append(sum(sizes[v["id"]] for v in vs if v["storage"]=="activation" and v["domain"]=="predicate" and v["producer"]<=i<=v["last_use"]))
        self.assertEqual(storage["real_live_bytes"],real);self.assertEqual(storage["predicate_live_bytes"],predicate)
        self.assertEqual(storage["activation_live_bytes"],[a+b for a,b in zip(real,predicate)])
        self.assertEqual(storage["peak_activation_bytes"],max(a+b for a,b in zip(real,predicate)))
        self.assertEqual(storage["persistent_kv_bytes"],sum(sizes[v["id"]] for v in vs if v["storage"]=="persistent_kv"))
        self.assertEqual(storage["input_bytes"],sum(sizes[v["id"]] for v in vs if v["storage"]=="index"))
        self.assertEqual(storage["total_bytes"],expected["payload"]+storage["persistent_kv_bytes"]+storage["input_bytes"]+storage["peak_activation_bytes"])
        return obj

    def test_01_actual_source_modes_overrides_and_mappings(self):
        for mode,source,override,scalar,biased,shards in itertools.product(("cached_append","full_prefix"),(False,True),(-1,0,1),("source64","requested32"),(False,True),(1,3)):
            config,roles=declared(attention=biased,mlp=biased,dimension=4,explicit=True);config["use_cache"]=source
            root,expected=self.collection(config,roles,shards=shards,dtypes=("BF16","F16","F32"));flags="1,1" if biased else "0,0"
            result=self.accept(self.invoke(root,mode,override,0 if mode=="full_prefix" else 1,scalar,flags,flags,shards=shards))
            self.check(result,expected,mode,int(source) if override==-1 else override,int(source),"source" if override==-1 else "invocation")
            arch=result["original_source"]["binding"]["architecture"]
            self.assertEqual({k:json.loads(v) for k,v in arch["layers"]["source"]["fields_raw"].items()},config)
            self.assertEqual(result["original_source"]["binding"]["source"]["bindings"],expected["bindings"])

    def test_02_defaults_source_revalidation_and_bounds(self):
        config,roles=declared();config.pop("use_cache")
        root,expected=self.collection(config,roles)
        def invoke(**kw):return self.invoke(root,attention="0,0",mlp="0,0",**kw)
        self.check(self.accept(invoke()),expected,"full_prefix",1,1)
        for case in ("source_flag","source_origin","source_layer","source_work"):
            self.refuse(self.child([CONFIG.source,root,"source-0.weights","config.json","full_prefix",-1,1000000,PROVENANCE,case]))
        result=self.accept(self.child([CONFIG.source,root,"source-0.weights","config.json","cached_append",-1,1000000,PROVENANCE,"valid"]))
        self.assertEqual(result["session_policy"]["return_cache"],1)
        for mode,override in itertools.product(("cached_append","full_prefix"),(-1,0,1)):
            origin="source" if override==-1 else "invocation";exact=256+2+len(mode)+len(origin)+len(PROVENANCE.encode())
            result=self.accept(invoke(mode=mode,returned=override,past=0 if mode=="full_prefix" else 1,work=exact))
            self.check(result,expected,mode,1 if override==-1 else override,1,origin)
            for work in (0,-1,1,exact-1,10000001,9223372036854775807):self.refuse(invoke(mode=mode,returned=override,past=0 if mode=="full_prefix" else 1,work=work))
        for value in (-2,2,9223372036854775807):self.refuse(invoke(returned=value))
        self.refuse(invoke(mode="future"));self.refuse(invoke(provenance=""));self.refuse(invoke(past=1))
        utf8="æ𝄞 session";exact=256+2+11+6+len(utf8.encode())
        self.check(self.accept(invoke(work=exact,provenance=utf8)),expected,"full_prefix",1,1,provenance=utf8)

    def test_03_all_retained_derived_and_consumer_refusals(self):
        config,roles=declared(attention=True,mlp=True);root,_=self.collection(config,roles)
        variants=list(dict.fromkeys(re.findall(r'variant == "([a-z_]+)"',Path("tests/hailo_decoder_session_api.mojo").read_text())))
        variants=[v for v in variants if v not in ("layout","layout_unallocated")]
        for mode,scalar,returned,variant in itertools.product(("cached_append","full_prefix"),("source64","requested32"),(0,1),variants):
            result=self.api_call(root,mode,returned,0 if mode=="full_prefix" else 1,scalar=scalar,case=variant)
            self.refuse(result);self.assertNotIn("unexpected consumer accepted",result.stderr)
        self.accept(self.api_call(root))

    def test_04_ownership_recovery_and_descriptor_cleanup(self):
        config,roles=declared(attention=True,mlp=True);root,expected=self.collection(config,roles)
        for mode,scalar,returned in itertools.product(("cached_append","full_prefix"),("source64","requested32"),(0,1)):
            obj=self.accept(self.child([CONFIG.ownership,root,"source-0.weights","config.json",scalar,mode,returned],mode+"-"+scalar+"-"+str(returned)+".strace"))
            self.check(obj,expected,mode,returned,0,"invocation","session API test provenance")
        for path in expected["raw_files"]:self.assertEqual(path.read_bytes(),expected["raw_files"][path])
        for trace in self.evidence.glob('*.strace'):
            text=trace.read_text()
            for bad in ("/dev/h1x-","libcuda","libhailort","libggml","ioctl("):self.assertNotIn(bad,text)
            for path in expected["raw_files"]:
                opens=sum(("openat(" in l or "openat2(" in l) and json.dumps(path.name) in l for l in text.splitlines())
                closes=sum("close(" in l and "<"+str(path)+">" in l for l in text.splitlines())
                self.assertEqual(opens,closes);self.assertGreater(closes,20)
                for line in text.splitlines():
                    if "mmap(" in line:self.assertNotIn(".weights>",line)
                    match=re.search(r'pread64\(\d+<([^>]+)>, .*, (\d+), (\d+)\) = (\d+)',line)
                    if match and match[1] in expected["files"]:
                        self.assertLessEqual(int(match[3])+int(match[4]),expected["files"][match[1]]["data_offset"])


    def test_05_full_legacy_output_compatibility(self):
        config,roles=declared(attention=True,mlp=True);root,_=self.collection(config,roles)
        for scalar in ("source64","requested32"):
            after=self.accept(self.api_call(root,mode="cached_append",returned=0,past=1,scalar=scalar))
            before=self.accept(self.child([CONFIG.frozen_api,root,"source-0.weights","config.json","1,1","1,1",scalar,"gelu_erf,relu","valid"]))
            self.assertEqual(normalize(after),before)
        from test_hailo_semantic_plan import dense_fixture
        for key,value,tied in itertools.product((2,3),(2,5),(False,True)):
            raw,_,_=dense_fixture(layers=2,key=key,value=value,tied=tied)
            path=self.root/("session-frozen-"+str(len(self.records))+".gguf");path.write_bytes(raw)
            args=[path,"0,0","0,0","1,0","legacy32","silu,silu"]
            before=self.accept(self.child([CONFIG.frozen_gguf,*args]))
            after=self.accept(self.child([CONFIG.gguf,*args,"cached_append",0,1,8]))
            self.assertEqual(normalize(after),before)
            for returned in (0,1):
                self.accept(self.child([CONFIG.gguf,path,"0,0","0,0","1,0","source32","gelu_erf,relu","full_prefix",returned,0,8]))
            self.assertEqual(path.read_bytes(),raw)

    def test_06_large_unallocated_capacity_and_consumer_scenarios(self):
        config,roles=declared(attention=True,mlp=True);root,expected=self.collection(config,roles)
        for scalar,returned in itertools.product(("source64","requested32"),(0,1)):
            self.accept(self.api_call(root,returned=returned,scalar=scalar,case="layout_unallocated"))
            self.refuse(self.api_call(root,mode="cached_append",returned=returned,scalar=scalar,past=1,case="layout_unallocated"))
            for capacity in (8,9223372036854775807):
                obj=self.accept(self.api_call(root,returned=returned,scalar=scalar,capacity=capacity))
                self.check(obj,expected,"full_prefix",returned,0,"invocation","session API test provenance")
                layout=self.accept(self.api_call(root,returned=returned,scalar=scalar,capacity=capacity,case="layout"))
                self.assertEqual(layout,dict(cache_bytes=0,regions=0,persistent_storage_bytes=0,matrix_schedules=15))
            self.refuse(self.api_call(root,mode="cached_append",returned=returned,scalar=scalar,past=1,capacity=9223372036854775807))
            layout=self.accept(self.api_call(root,mode="cached_append",returned=returned,scalar=scalar,past=1,case="layout"))
            self.assertEqual(layout["regions"],4);self.assertEqual(layout["cache_bytes"],1024);self.assertEqual(layout["matrix_schedules"],15)

    def test_07_source_words_mixed_bias_and_index_bounds(self):
        for scalar,mode in itertools.product(("source64","requested32"),("cached_append","full_prefix")):
            config,roles=old.declared(key=3,value=5)
            attention=[0,1];mlp=[1,0]
            for name,(canonical,shape) in list(roles.items()):
                layer=int(name.split('.')[2]) if name.startswith('model.layers.') else -1
                if layer>=0 and ((attention[layer] and 'self_attn.' in name) or (mlp[layer] and 'mlp.' in name)):
                    roles[name.replace('.weight','.bias')]=(canonical.replace('.weight','.bias'),[shape[0]])
            root,expected=self.collection(config,roles)
            obj=self.accept(self.api_call(root,mode=mode,past=0 if mode=="full_prefix" else 1,scalar=scalar,attention="0,1",mlp="1,0"))
            self.check(obj,expected,mode,1,0,"invocation","session API test provenance")
        config,roles=declared(attention=True,mlp=True)
        for epsilon,base in ((1e-300,1e300),(5e-324,5000000),(1e300,1e-300)):
            changed=dict(config,rms_norm_eps=epsilon,rope_theta=base);root,expected=self.collection(changed,roles)
            obj=self.accept(self.invoke(root,returned=1));self.check(obj,expected,"full_prefix",1,0,"invocation")
            words=obj["lowered"]["source_graph"]["source_scalars"]
            self.assertEqual(words["epsilon"]["bits"],struct.unpack('<Q',struct.pack('<d',epsilon))[0])
            self.assertEqual(words["rope_base"]["bits"],struct.unpack('<Q',struct.pack('<d',base))[0])
            self.refuse(self.invoke(root,returned=1,scalar="requested32"))
        # Pure integer causal index sets only; no attention arithmetic/forward.
        for past in (0,1,3):
            query=2;positions=list(range(past,past+query))
            for row,pos in enumerate(positions):self.assertEqual([i for i in range(past+query) if i<=pos],list(range(past+row+1)))


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    for name in ("binary","api","ownership","gguf","source","frozen-api","frozen-gguf","strace","evidence"):parser.add_argument('--'+name,required=True)
    CONFIG,remaining=parser.parse_known_args();old.CONFIG=CONFIG
    unittest.main(argv=[__file__,*remaining],verbosity=2)
