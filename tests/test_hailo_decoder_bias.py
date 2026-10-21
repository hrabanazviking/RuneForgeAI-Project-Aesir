#!/usr/bin/env python3
"""Independent source-bound projection-bias IR oracle; never a model forward."""
import argparse
import copy
import itertools
import json
import math
from pathlib import Path
import re
import unittest
import test_hailo_decoder_projections as old
from test_hailo_ordinary_projection_schema import declared

CONFIG=argparse.Namespace()
PROVENANCE="explicit synthetic bias recipe"


class DecoderBias(unittest.TestCase):
    setUpClass=classmethod(old.DecoderProjections.setUpClass.__func__)
    tearDownClass=classmethod(old.DecoderProjections.tearDownClass.__func__)
    child=old.DecoderProjections.child
    accept=old.DecoderProjections.accept
    refuse=old.DecoderProjections.refuse
    collection=old.DecoderProjections.collection

    def invoke(self,root,layers=2,attention="1,1",mlp="1,1",mask="1,0",scalar="source64",pairing="split_half",mode="unindexed",work=1000000,provenance=PROVENANCE,trace=None):
        label="index.json" if mode=="indexed" else "source-0.weights"
        return self.child([self.binary,mode,root,label,"config.json",2,1,8,2,mask,attention,mlp,scalar,pairing,work,provenance],trace)

    def api_call(self,root,case="valid",attention="1,1",mlp="1,1",scalar="source64"):
        return self.child([self.api,root,"source-0.weights","config.json",attention,mlp,scalar,case])

    def check(self,obj,expected,attention,mlp,provenance=PROVENANCE):
        if "lowered" in obj:
            self.assertFalse(obj["ordinary_model_admitted"]);self.assertFalse(obj["device_execution_verified"])
            obj=obj["lowered"]
        sg=obj["source_graph"];eg=obj["expanded"];recipes=obj["recipes"]
        source=sg["tensors"];ops=sg["operations"];values=eg["values"];expanded=eg["operations"]
        count=4*sum(attention)+3*sum(mlp)
        policy=sg["bias_policy"]
        self.assertEqual(policy["attention"],attention);self.assertEqual(policy["mlp"],mlp)
        self.assertEqual(policy["charged_work"],2*len(attention)+len(provenance.encode())+128*count)
        self.assertEqual(policy,recipes["bias_policy"]);self.assertEqual(policy,eg["bias_policy"])
        for g in (sg,recipes,eg):self.assertEqual(g["schema_version"],3)
        bias_ops=[x for x in ops if x["kind"]=="add_projection_bias"]
        self.assertEqual(len(bias_ops),count)
        self.assertEqual(sum(x["kind"]=="add_source_projection_vector" for x in expanded),count)
        self.assertEqual(sum(x["kind"]=="add_projection_bias" for x in recipes["recipes"]),count)
        roles={}
        for layer in range(len(attention)):
            for enabled,names in [(attention[layer],["attn_q","attn_k","attn_v","attn_output"]),(mlp[layer],["ffn_gate","ffn_up","ffn_down"])]:
                if enabled:
                    for name in names:roles[f"blk.{layer}.{name}.bias"]=False
        for op in bias_ops:
            name=op["weight"];self.assertIn(name,roles);self.assertFalse(roles[name]);roles[name]=True
            self.assertEqual(len(op["inputs"]),1)
            inp=source[op["inputs"][0]];out=source[op["output"]]
            self.assertEqual(inp["shape"],out["shape"]);self.assertEqual(out["producer"],op["id"])
            width=math.prod(inp["shape"][1:]);binding=expected["bindings"][name]
            self.assertEqual(binding["source_shape"],[width])
            linear=ops[inp["producer"]]
            self.assertEqual(linear["kind"],"linear");self.assertEqual(linear["weight"].replace(".weight",".bias"),name)
            consumers=[x["id"] for x in ops if inp["id"] in x["inputs"]]
            self.assertEqual(consumers,[op["id"]])
            recipe=next(x for x in recipes["recipes"] if x["source_operation"]==op["id"])
            self.assertEqual(recipe["weight_name"],name);self.assertEqual(recipe["divisor"],0)
            self.assertEqual(recipe["weight"],{k:binding[k] for k in ("file_offset","columns","rows","source_kind","byte_count")})
            self.assertEqual([v["shape"] for v in recipe["values"]],[inp["shape"],[width],inp["shape"]])
            self.assertEqual(recipe["operations"],[dict(kind="add_source_projection_vector",inputs=[0,1],output=2)])
            emitted=[x for x in expanded if x["source_operation"]==op["id"]]
            self.assertEqual(len(emitted),1);step=emitted[0]
            self.assertEqual(step["kind"],"add_source_projection_vector");self.assertEqual(step["recipe_step"],0)
            self.assertEqual(step["source_weight"],name);self.assertEqual(step["width"],0)
            self.assertEqual(step["inputs"],[eg["source_to_global"][inp["id"]],eg["weights"][name]["value"]])
            self.assertEqual(step["output"],eg["source_to_global"][out["id"]])
            self.assertEqual(values[step["inputs"][1]]["shape"],[width])
            self.assertEqual(values[step["inputs"][1]]["storage"],"source_weight")
            # One isolated addition operation only: feature-distinct bias must
            # span every head, rather than repeating the first head's vector.
            x=[i*3 for i in range(out["elements"])]
            b=[1000+i*7 for i in range(width)]
            actual=[x[i]+b[i%width] for i in range(len(x))]
            expected_add=[]
            for q in range(out["shape"][0]):
                for feature in range(width):expected_add.append((q*width+feature)*3+1000+feature*7)
            self.assertEqual(actual,expected_add)
            if len(out["shape"])==3 and out["shape"][1]>1:
                component=out["shape"][2]
                self.assertNotEqual(actual[component],x[component]+b[0])
        self.assertTrue(all(roles.values()))
        # Recompute every source/global lifetime and hypothetical byte timeline.
        for tensor in source:
            last=max([tensor["producer"]]+[x["id"] for x in ops if tensor["id"] in x["inputs"]])
            if tensor["persistent"] or tensor["id"]==sg["logits"]:last=len(ops)
            self.assertEqual(tensor["last_use"],last)
        sizes=[]
        for value in values:
            last=max([value["producer"]]+[x["id"] for x in expanded if value["id"] in x["inputs"]])
            if value["storage"] in ("source_weight","persistent_kv") or value["id"]==eg["result"]:last=len(expanded)
            self.assertEqual(value["last_use"],last)
            width=8 if value["storage"]=="index" else 1 if value["domain"]=="predicate" else 2
            sizes.append(0 if value["storage"] in ("source_weight","kv_view") else (value["elements"]*width+15)//16*16)
        storage=obj["storage"]
        self.assertEqual(storage["value_bytes"],sizes)
        real=[];predicate=[]
        for step in range(len(expanded)+1):
            real.append(sum(sizes[v["id"]] for v in values if v["storage"]=="activation" and v["domain"]=="real" and v["producer"]<=step<=v["last_use"]))
            predicate.append(sum(sizes[v["id"]] for v in values if v["storage"]=="activation" and v["domain"]=="predicate" and v["producer"]<=step<=v["last_use"]))
        self.assertEqual(storage["real_live_bytes"],real);self.assertEqual(storage["predicate_live_bytes"],predicate)
        self.assertEqual(storage["activation_live_bytes"],[a+b for a,b in zip(real,predicate)])
        self.assertEqual(storage["peak_activation_bytes"],max(a+b for a,b in zip(real,predicate)))
        self.assertEqual(storage["persistent_kv_bytes"],sum(sizes[v["id"]] for v in values if v["storage"]=="persistent_kv"))
        self.assertEqual(storage["input_bytes"],sum(sizes[v["id"]] for v in values if v["storage"]=="index"))
        self.assertEqual(storage["total_bytes"],expected["payload"]+storage["persistent_kv_bytes"]+storage["input_bytes"]+storage["peak_activation_bytes"])

    def test_01_actual_metadata_and_flag_grid(self):
        for attention,mlp,scalar,pairing,shards in itertools.product((0,1),(0,1),("source64","requested32"),("adjacent","split_half"),(1,3)):
            config,roles=declared(attention=bool(attention),mlp=bool(mlp),explicit=True,dimension=4)
            root,expected=self.collection(config,roles,shards=shards,dtypes=("BF16","F16","F32"))
            obj=self.accept(self.invoke(root,attention=f"{attention},{attention}",mlp=f"{mlp},{mlp}",scalar=scalar,pairing=pairing,mode="indexed" if shards>1 else "unindexed"))
            self.check(obj,expected,[attention]*2,[mlp]*2)
            self.assertEqual(obj["original_source"]["binding"]["source"]["bindings"],expected["bindings"])

    def test_02_source_neutral_mixed_layers_independent_widths(self):
        for attention,mlp,scalar,key,value in itertools.product(([0,1],[1,0],[1,1]),([0,1],[1,0]),("source64","requested32"),(2,3),(2,5)):
            config,roles=old.declared(key=key,value=value)
            for name,(canonical,shape) in list(roles.items()):
                layer=int(name.split(".")[2]) if name.startswith("model.layers.") else -1
                if layer>=0 and ((attention[layer] and "self_attn." in name) or (mlp[layer] and "mlp." in name)):
                    roles[name.replace(".weight",".bias")]=(canonical.replace(".weight",".bias"),[shape[0]])
            root,expected=self.collection(config,roles,dtypes=("BF16","F16","F32"))
            obj=self.accept(self.api_call(root,attention=",".join(map(str,attention)),mlp=",".join(map(str,mlp)),scalar=scalar))
            self.check(obj,expected,attention,mlp,"bias API test provenance")

    def test_03_policy_source_bounds_and_exact_word_retention(self):
        config,roles=declared(attention=True,mlp=True)
        root,expected=self.collection(config,roles)
        exact=4+len(PROVENANCE.encode())+14*128
        self.check(self.accept(self.invoke(root,work=exact)),expected,[1,1],[1,1])
        for work in (0,-1,1,exact-1,10000001):self.refuse(self.invoke(root,work=work))
        self.refuse(self.invoke(root,provenance=""))
        for field,value in [("attention","1"),("mlp","1,1,0"),("attention","2,1"),("mlp","-1,0"),("attention","0,1"),("mlp","1,0")]:
            self.refuse(self.invoke(root,**{field:value}))
        for name in [k for k in roles if k.endswith(".bias")][:7]:
            changed=copy.deepcopy(roles);canonical,shape=changed[name];changed[name]=(canonical,[shape[0]+1])
            r,_=self.collection(config,changed);self.refuse(self.invoke(r))
        # Source64 keeps constants even when their explicitly requested32 projection
        # would underflow/overflow. No source64 path may use those legacy slots.
        for epsilon,base in [(1e-300,1e300),(5e-324,5000000),(1e300,1e-300)]:
            changed=dict(config,rms_norm_eps=epsilon,rope_theta=base)
            r,exp=self.collection(changed,roles)
            obj=self.accept(self.invoke(r));self.check(obj,exp,[1,1],[1,1])
            self.assertEqual(obj["lowered"]["source_graph"]["source_scalars"]["epsilon"]["width"],64)
            self.refuse(self.invoke(r,scalar="requested32"))

    def test_04_retained_and_derived_mutation_refusals(self):
        config,roles=declared(attention=True,mlp=True)
        root,_=self.collection(config,roles)
        modes=re.findall(r'(?<![_a-z])mode == "([a-z_]+)"',Path("tests/hailo_decoder_bias_api.mojo").read_text())
        mutations=[m for m in modes if m not in ("valid","legacy")]
        for scalar in ("source64","requested32"):
            for mode in dict.fromkeys(mutations):self.refuse(self.api_call(root,mode,scalar=scalar))

    def test_05_zero_policy_structural_compatibility_and_readonly(self):
        config,roles=declared()
        root,expected=self.collection(config,roles)
        def normalize(obj):
            obj=copy.deepcopy(obj)
            for key in ("source_graph","recipes","expanded"):
                obj[key].pop("bias_policy",None)
                obj[key]["schema_version"]=0
            return obj
        for scalar in ("source64","requested32"):
            before=self.accept(self.api_call(root,"legacy",attention="0,0",mlp="0,0",scalar=scalar))
            after=self.accept(self.api_call(root,attention="0,0",mlp="0,0",scalar=scalar))
            self.assertEqual(normalize(before),normalize(after))
        config,roles=declared(attention=True,mlp=True)
        root,expected=self.collection(config,roles)
        obj=self.accept(self.invoke(root,trace="bias-readonly.strace"));self.check(obj,expected,[1,1],[1,1])
        trace=(self.evidence/"bias-readonly.strace").read_text()
        for forbidden in ("/dev/h1x","libhailort","libcuda","libggml","ioctl("):self.assertNotIn(forbidden,trace)
        for path,raw in expected["raw_files"].items():
            self.assertEqual(path.read_bytes(),raw)
            lines=[line for line in trace.splitlines() if str(path) in line]
            self.assertEqual(sum("pread64(" in line for line in lines),2)
            self.assertTrue(any("close(" in line for line in lines))
            self.assertFalse(any("mmap(" in line for line in lines))

    def test_06_owned_policies_and_recipe_snapshots(self):
        config,roles=declared(attention=True,mlp=True)
        root,expected=self.collection(config,roles)
        for scalar in ("source64","requested32"):
            obj=self.accept(self.child([CONFIG.ownership,root,"source-0.weights","config.json",scalar],"bias-ownership.strace" if scalar=="source64" else None))
            self.check(obj,expected,[1,1],[1,1],"bias API test provenance")
        trace=(self.evidence/"bias-ownership.strace").read_text()
        for path,raw in expected["raw_files"].items():
            opens=sum(("openat(" in line or "openat2(" in line) and json.dumps(path.name) in line for line in trace.splitlines())
            closes=sum("close(" in line and "<"+str(path)+">" in line for line in trace.splitlines())
            self.assertEqual(opens,closes)
            self.assertGreaterEqual(closes,40)
            self.assertEqual(path.read_bytes(),raw)
        for forbidden in ("/dev/h1x","libhailort","libcuda","libggml","ioctl("):
            self.assertNotIn(forbidden,trace)

    def test_07_gguf_source_vectors_and_scalar_words(self):
        from test_hailo_semantic_plan import dense_fixture
        for attention,mlp,scalar,tied in itertools.product(([0,1],[1,1]),([1,0],[1,1]),("source32","legacy32"),(False,True)):
            hidden,heads,kv,key,value,ff=8,4,2,3,5,12
            extras=[]
            for layer in range(2):
                for enabled,names,sizes in [(attention[layer],["attn_q","attn_k","attn_v","attn_output"],[heads*key,kv*key,kv*value,hidden]),(mlp[layer],["ffn_gate","ffn_up","ffn_down"],[ff,ff,hidden])]:
                    if enabled:
                        extras.extend((f"blk.{layer}.{name}.bias",width,1,0) for name,width in zip(names,sizes))
            raw,weights,_=dense_fixture(layers=2,key=key,value=value,tied=tied,extra_tensors=extras)
            path=self.root/("bias-"+str(len(self.records))+".gguf");path.write_bytes(raw)
            obj=self.accept(self.child([CONFIG.gguf,path,",".join(map(str,attention)),",".join(map(str,mlp)),"1,0",scalar]))
            expected=dict(bindings={name:dict(binding,source_shape=[binding["columns"]] if binding["rows"]==1 else [binding["columns"],binding["rows"]]) for name,binding in weights.items()},payload=sum(w["byte_count"] for w in weights.values()))
            self.check(obj,expected,attention,mlp,"GGUF bias source test")
            self.assertEqual(path.read_bytes(),raw)

    def test_08_cache_matrix_and_storage_consumer_integration(self):
        for attention,mlp,scalar,key,value in itertools.product(([0,1],[1,0],[1,1]),([0,1],[1,0]),("source64","requested32"),(2,3),(5,)):
            config,roles=old.declared(key=key,value=value)
            for name,(canonical,shape) in list(roles.items()):
                layer=int(name.split(".")[2]) if name.startswith("model.layers.") else -1
                if layer>=0 and ((attention[layer] and "self_attn." in name) or (mlp[layer] and "mlp." in name)):
                    roles[name.replace(".weight",".bias")]=(canonical.replace(".weight",".bias"),[shape[0]])
            root,expected=self.collection(config,roles)
            obj=self.accept(self.child([CONFIG.consumers,root,"source-0.weights","config.json",",".join(map(str,attention)),",".join(map(str,mlp)),scalar,"valid"]))
            self.assertFalse(obj["device_access"]);self.assertEqual(obj["matrix_schedules"],15)
            cursor=0
            for region in obj["regions"]:
                dim=key if "key_cache" in region["name"] else value
                stride=(2*dim*2+15)//16*16
                self.assertEqual(region["offset"],cursor);self.assertEqual(region["stride"],stride)
                self.assertEqual(region["bytes"],8*stride)
                self.assertEqual(region["last_element_offset"],cursor+7*stride+(2*dim-1)*2)
                cursor+=8*stride
            self.assertEqual(obj["cache_bytes"],cursor)
            count=sum(((shape[0]+4)//5)*((shape[1]+2)//3) for name,(_,shape) in roles.items() if name.endswith(".weight") and ("self_attn" in name or "mlp." in name))
            count+=((10+4)//5)*((8+2)//3)
            self.assertEqual(obj["matrix_tiles"],count)
        config,roles=declared(attention=True,mlp=True)
        root,_=self.collection(config,roles)
        for scalar,case in itertools.product(("source64","requested32"),("cache_bypass","storage_bypass","matrix_bypass")):
            result=self.child([CONFIG.consumers,root,"source-0.weights","config.json","1,1","1,1",scalar,case])
            self.refuse(result);self.assertNotIn("unexpected",result.stderr)

    def test_09_complete_frozen_gguf_outputs(self):
        from test_hailo_semantic_plan import dense_fixture
        for key,value,tied in itertools.product((2,3),(2,5),(False,True)):
            raw,_,_=dense_fixture(layers=2,key=key,value=value,tied=tied)
            path=self.root/("frozen-bias-"+str(len(self.records))+".gguf");path.write_bytes(raw)
            before=self.accept(self.child([CONFIG.frozen,path,2,1,8,"adjacent","explicit synthetic GGUF bias basis",10000,10000000,"1,0"]))
            after=self.accept(self.child([CONFIG.gguf,path,"0,0","0,0","1,0","legacy32"]))
            for name in ("source_graph","recipes","expanded"):
                after[name].pop("bias_policy")
                after[name]["schema_version"]=1
            self.assertEqual(before,after)
            self.assertEqual(path.read_bytes(),raw)


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    for key in ("binary","api","ownership","gguf","consumers","frozen","strace","evidence"):parser.add_argument("--"+key,required=True)
    CONFIG=parser.parse_args();old.CONFIG=CONFIG
    unittest.main(argv=[__file__],verbosity=2)
