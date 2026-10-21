#!/usr/bin/env python3
"""Independent activation IR/ownership oracle, with isolated primitive math only."""
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
import test_hailo_decoder_bias as bias_tests

CONFIG=argparse.Namespace()
PROVENANCE="explicit synthetic activation recipe"
KINDS=("silu","gelu_erf","relu")
OPS={"silu":["abs","negate","exp","add_one","reciprocal","multiply","compare_nonnegative","select","multiply"],
     "gelu_erf":["multiply_inverse_sqrt_two","erf","add_one","multiply","multiply_half"],"relu":["maximum_zero"]}


def normalize(obj):
    obj=copy.deepcopy(obj)
    for key in ("source_graph","recipes","expanded"):
        obj[key].pop("activation_policy",None)
        obj[key]["schema_version"]=3
    for recipe in obj["recipes"]["recipes"]:
        recipe.pop("source_inputs",None);recipe.pop("input_values",None)
    return obj


class DecoderActivation(unittest.TestCase):
    setUpClass=classmethod(old.DecoderProjections.setUpClass.__func__)
    tearDownClass=classmethod(old.DecoderProjections.tearDownClass.__func__)
    child=old.DecoderProjections.child
    accept=old.DecoderProjections.accept
    refuse=old.DecoderProjections.refuse
    collection=old.DecoderProjections.collection
    check_bias=bias_tests.DecoderBias.check

    def invoke(self,root,kinds="source",scalar="source64",attention="1,1",mlp="1,1",work=1000000,provenance=PROVENANCE,shards=1,trace=None):
        return self.child([self.binary,"unindexed" if shards==1 else "indexed",root,"source-0.weights" if shards==1 else "index.json","config.json",2,1,8,2,"1,0",attention,mlp,scalar,"split_half",work,provenance,kinds],trace)

    def api_call(self,root,case="valid",kinds="gelu_erf,relu",scalar="source64",attention="1,1",mlp="1,1"):
        return self.child([self.api,root,"source-0.weights","config.json",attention,mlp,scalar,kinds,case])

    def check(self,obj,expected,kinds,attention=(1,1),mlp=(1,1),provenance=PROVENANCE,bias_provenance=None):
        if "lowered" in obj:
            self.assertFalse(obj["ordinary_model_admitted"]);self.assertFalse(obj["device_execution_verified"])
            obj=obj["lowered"]
        self.check_bias(normalize(obj),expected,list(attention),list(mlp),bias_provenance or provenance)
        sg,rs,eg=(obj[k] for k in ("source_graph","recipes","expanded"))
        policy=sg["activation_policy"]
        self.assertEqual(policy["kinds"],list(kinds));self.assertEqual(policy["provenance"],provenance)
        self.assertEqual(policy["charged_work"],128*len(kinds)+len(provenance.encode())+sum(len(k.encode()) for k in kinds))
        for owner in (sg,rs,eg):
            self.assertEqual(owner["activation_policy"],policy);self.assertEqual(owner["schema_version"],4)
        tensors=sg["tensors"];ops=sg["operations"];values=eg["values"]
        byname={t["name"]:t for t in tensors}
        self.assertEqual(sum(op["kind"] in KINDS for op in ops),len(kinds))
        for layer,kind in enumerate(kinds):
            prefix=f"blk.{layer}."
            out=byname[prefix+"gate_"+kind];op=ops[out["producer"]]
            inp=byname[prefix+("gate_biased" if mlp[layer] else "gate")]
            up=byname[prefix+("up_biased" if mlp[layer] else "up")]
            product=ops[byname[prefix+"gated"]["producer"]]
            self.assertEqual(op["kind"],kind);self.assertEqual(op["inputs"],[inp["id"]]);self.assertEqual(op["weight"],"")
            self.assertEqual(product["inputs"],[out["id"],up["id"]])
            self.assertEqual([o["id"] for o in ops if out["id"] in o["inputs"]],[product["id"]])
            recipe=next(r for r in rs["recipes"] if r["source_operation"]==op["id"])
            self.assertEqual(recipe["source_input"],inp["id"]);self.assertEqual(recipe["source_output"],out["id"])
            self.assertEqual(recipe["source_inputs"],[inp["id"]]);self.assertEqual(recipe["input_values"],[0])
            self.assertEqual([o["kind"] for o in recipe["operations"]],OPS[kind])
            self.assertEqual(recipe["weight_name"],"");self.assertEqual(recipe["divisor"],0)
            self.assertEqual(recipe["epsilon_bits"],0);self.assertEqual(recipe.get("rotary_dim",0),0)
            if kind!="silu":self.assertEqual(recipe["runtime_preconditions"],["finite_real_inputs","real_precision_unqualified"])
            for i,v in enumerate(recipe["values"]):
                self.assertEqual(v["shape"],inp["shape"]);self.assertEqual(v["elements"],math.prod(inp["shape"]))
                last=max([v["producer"]]+[j for j,o in enumerate(recipe["operations"]) if i in o["inputs"]])
                if i==recipe["result"]:last=len(recipe["operations"])
                self.assertEqual(v["last_use"],last)
            emitted=[o for o in eg["operations"] if o["source_operation"]==op["id"]]
            self.assertEqual([o["kind"] for o in emitted],OPS[kind])
            local={0:eg["source_to_global"][inp["id"]]}
            for step,(localop,globalop) in enumerate(zip(recipe["operations"],emitted)):
                self.assertEqual(globalop["recipe_step"],step)
                self.assertEqual(globalop["inputs"],[local[i] for i in localop["inputs"]])
                local[localop["output"]]=globalop["output"]
                v=values[globalop["output"]]
                self.assertEqual(v["domain"],recipe["values"][localop["output"]]["domain"])
                self.assertEqual(v["alias_of"],-1);self.assertEqual(v["storage"],"activation")
            self.assertEqual(local[recipe["result"]],eg["source_to_global"][out["id"]])
        return obj

    def test_01_choices_bias_order_and_independent_lifetimes(self):
        for kinds,scalar,biased,shards in itertools.product(itertools.product(KINDS,repeat=2),("source64","requested32"),(False,True),(1,3)):
            config,roles=declared(attention=biased,mlp=biased,dimension=4,explicit=True)
            root,expected=self.collection(config,roles,shards=shards,dtypes=("BF16","F16","F32"))
            flags="1,1" if biased else "0,0"
            obj=self.accept(self.invoke(root,",".join(kinds),scalar,flags,flags,shards=shards))
            self.check(obj,expected,kinds,[int(biased)]*2,[int(biased)]*2)
            self.assertEqual(obj["original_source"]["binding"]["source"]["bindings"],expected["bindings"])

    def test_02_source_projection_defaults_and_unresolved_selectors(self):
        for selector in (None,"silu","gelu","relu"):
            config,roles=declared(attention=True,mlp=True)
            if selector is not None:config["hidden_act"]=selector
            root,expected=self.collection(config,roles)
            obj=self.accept(self.invoke(root))
            kind={None:"silu","silu":"silu","gelu":"gelu_erf","relu":"relu"}[selector]
            self.check(obj,expected,[kind]*2)
            arch=obj["original_source"]["binding"]["architecture"]
            self.assertEqual(arch["activation"],selector or "silu")
            raw=arch["layers"]["source"]["fields_raw"]
            self.assertEqual({k:json.loads(v) for k,v in raw.items()},config)
        for selector in ("gelu_new","gelu_fast","quick_gelu","relu2","unknown_activation"):
            config,roles=declared(attention=True,mlp=True);config["hidden_act"]=selector
            root,_=self.collection(config,roles)
            result=self.invoke(root);self.refuse(result)
            self.assertIn("selector lowering remains implementation work",result.stderr)

    def test_03_bounds_and_exact_source_words(self):
        config,roles=declared();root,expected=self.collection(config,roles)
        kinds=["gelu_erf","relu"];exact=256+len(PROVENANCE.encode())+12
        self.check(self.accept(self.invoke(root,",".join(kinds),attention="0,0",mlp="0,0",work=exact)),expected,kinds,[0,0],[0,0])
        for work in (0,-1,1,exact-1,10000001,9223372036854775807):
            self.refuse(self.invoke(root,",".join(kinds),attention="0,0",mlp="0,0",work=work))
        utf8="æ𝄞 activation"
        self.check(self.accept(self.invoke(root,",".join(kinds),attention="0,0",mlp="0,0",work=256+len(utf8.encode())+12,provenance=utf8)),expected,kinds,[0,0],[0,0],utf8)
        for kinds_arg in ("","silu","silu,relu,gelu_erf","gelu,relu","unknown,relu"):
            self.refuse(self.invoke(root,kinds_arg,attention="0,0",mlp="0,0"))
        self.refuse(self.invoke(root,"silu,silu",attention="0,0",mlp="0,0",provenance=""))
        for epsilon,base in ((1e-300,1e300),(5e-324,5000000),(1e300,1e-300)):
            changed=dict(config,rms_norm_eps=epsilon,rope_theta=base);root,expected=self.collection(changed,roles)
            obj=self.accept(self.invoke(root,"gelu_erf,relu",attention="0,0",mlp="0,0"))
            self.check(obj,expected,kinds,[0,0],[0,0]);self.assertEqual(obj["lowered"]["source_graph"]["source_scalars"]["epsilon"]["width"],64)
            source=obj["lowered"]["source_graph"]["source_scalars"]
            self.assertEqual(source["epsilon"]["bits"],struct.unpack("<Q",struct.pack("<d",epsilon))[0])
            self.assertEqual(source["rope_base"]["bits"],struct.unpack("<Q",struct.pack("<d",base))[0])
            self.refuse(self.invoke(root,"gelu_erf,relu",scalar="requested32",attention="0,0",mlp="0,0"))

    def test_04_mutations_and_consumer_boundaries(self):
        config,roles=declared(attention=True,mlp=True);root,_=self.collection(config,roles)
        modes=re.findall(r'mode == "([a-z_]+)"',Path("tests/hailo_decoder_activation_api.mojo").read_text())
        modes=list(dict.fromkeys(modes))
        for scalar,kinds,mode in itertools.product(("source64","requested32"),("silu,relu","gelu_erf,relu","relu,gelu_erf"),modes):
            result=self.api_call(root,mode,kinds,scalar);self.refuse(result)
            self.assertNotIn("unexpected consumer accepted",result.stderr)
        self.accept(self.api_call(root))

    def test_05_owned_inputs_snapshots_recovery_and_cleanup(self):
        config,roles=declared(attention=True,mlp=True);root,expected=self.collection(config,roles)
        for scalar in ("source64","requested32"):
            obj=self.accept(self.child([CONFIG.ownership,root,"source-0.weights","config.json",scalar],scalar+"-ownership.strace"))
            self.check(obj,expected,["gelu_erf","relu"],provenance="activation API test provenance",bias_provenance="bias API test provenance")
        for trace in self.evidence.glob("*.strace"):
            text=trace.read_text()
            for bad in ("/dev/h1x-","libcuda","libhailort","libggml","ioctl("):self.assertNotIn(bad,text)
            for path in expected["raw_files"]:
                opens=sum(("openat(" in l or "openat2(" in l) and json.dumps(path.name) in l for l in text.splitlines())
                closes=sum("close(" in l and "<"+str(path)+">" in l for l in text.splitlines())
                self.assertEqual(opens,closes);self.assertGreater(closes,20)
                self.assertNotIn("mmap(NULL, "+str(len(path.read_bytes())),text)
                self.assertEqual(path.read_bytes(),expected["raw_files"][path])

    def test_06_complete_legacy_output_compatibility(self):
        config,roles=declared(attention=True,mlp=True);root,expected=self.collection(config,roles)
        for scalar in ("source64","requested32"):
            after=self.accept(self.api_call(root,kinds="silu,silu",scalar=scalar))
            before=self.accept(self.child([CONFIG.frozen_api,root,"source-0.weights","config.json","1,1","1,1",scalar,"valid"]))
            self.assertEqual(normalize(after),before)
        from test_hailo_semantic_plan import dense_fixture
        for key,value,tied in itertools.product((2,3),(2,5),(False,True)):
            raw,_,_=dense_fixture(layers=2,key=key,value=value,tied=tied)
            path=self.root/("activation-frozen-"+str(len(self.records))+".gguf");path.write_bytes(raw)
            before=self.accept(self.child([CONFIG.frozen_gguf,path,"0,0","0,0","1,0","legacy32"]))
            after=self.accept(self.child([CONFIG.gguf,path,"0,0","0,0","1,0","legacy32","silu,silu"]))
            self.assertEqual(normalize(after),before);self.assertEqual(path.read_bytes(),raw)
            self.accept(self.child([CONFIG.gguf,path,"0,0","0,0","1,0","source32","gelu_erf,relu"]))

    def test_07_isolated_recipe_math(self):
        # Exactly one activation primitive on a scalar; no projection/layer/model.
        config,roles=declared(attention=True,mlp=True);root,_=self.collection(config,roles)
        for kind in KINDS:
            obj=self.accept(self.api_call(root,kinds=kind+","+kind))
            recipe=next(r for r in obj["recipes"]["recipes"] if r["kind"]==kind)
            for x in (-20.,-8.,-4.,-3.,-2.,-1.,-.5,0.,.125,.5,1.,2.,3.,4.,8.,20.):
                values={0:x}
                for op in recipe["operations"]:
                    args=[values[i] for i in op["inputs"]];k=op["kind"]
                    if k=="abs":v=abs(args[0])
                    elif k=="negate":v=-args[0]
                    elif k=="exp":v=math.exp(args[0])
                    elif k=="add_one":v=args[0]+1
                    elif k=="reciprocal":v=1/args[0]
                    elif k=="multiply":v=args[0]*args[1]
                    elif k=="compare_nonnegative":v=args[0]>=0
                    elif k=="select":v=args[1] if args[0] else args[2]
                    elif k=="multiply_inverse_sqrt_two":v=args[0]/math.sqrt(2)
                    elif k=="erf":v=math.erf(args[0])
                    elif k=="multiply_half":v=args[0]/2
                    elif k=="maximum_zero":v=max(0,args[0])
                    else:self.fail(k)
                    values[op["output"]]=v
                expected=x/(1+math.exp(-x)) if kind=="silu" else x*math.erfc(-x/math.sqrt(2))/2 if kind=="gelu_erf" else max(0,x)
                self.assertAlmostEqual(values[recipe["result"]],expected,delta=2e-14)

    def test_09_mixed_source_neutral_bias_and_independent_widths(self):
        for attention,mlp,scalar,kinds in itertools.product(([0,1],[1,0]),([0,1],[1,0]),("source64","requested32"),("gelu_erf,relu","relu,silu")):
            config,roles=old.declared(key=3,value=5)
            for name,(canonical,shape) in list(roles.items()):
                layer=int(name.split(".")[2]) if name.startswith("model.layers.") else -1
                if layer>=0 and ((attention[layer] and "self_attn." in name) or (mlp[layer] and "mlp." in name)):
                    roles[name.replace(".weight",".bias")]=(canonical.replace(".weight",".bias"),[shape[0]])
            root,expected=self.collection(config,roles,dtypes=("BF16","F16","F32"))
            obj=self.accept(self.api_call(root,kinds=kinds,scalar=scalar,attention=",".join(map(str,attention)),mlp=",".join(map(str,mlp))))
            self.check(obj,expected,kinds.split(","),attention,mlp,"activation API test provenance","bias API test provenance")

    def test_08_actual_cache_matrix_storage_consumers(self):
        for scalar in ("source64","requested32"):
            config,roles=declared(attention=True,mlp=True);root,_=self.collection(config,roles)
            obj=self.accept(self.child([CONFIG.consumers,root,"source-0.weights","config.json","1,1","1,1",scalar,"valid"]))
            self.assertFalse(obj["device_access"]);self.assertEqual(obj["matrix_schedules"],15)
            frozen=self.accept(self.child([CONFIG.frozen_consumers,root,"source-0.weights","config.json","1,1","1,1",scalar,"valid"]))
            self.assertEqual(obj,frozen)


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    for key in ("binary","api","ownership","gguf","consumers","frozen-api","frozen-gguf","frozen-consumers","strace","evidence"):parser.add_argument("--"+key,required=True)
    CONFIG,remaining=parser.parse_known_args();old.CONFIG=CONFIG
    unittest.main(argv=[__file__,*remaining],verbosity=2)
