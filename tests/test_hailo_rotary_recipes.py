#!/usr/bin/env python3
"""Independent compiler structure + ONE tiny synthetic rotary primitive only."""
import argparse, cmath, copy, hashlib, json, math, random, struct, subprocess, tempfile, unittest
from collections import Counter
from pathlib import Path
from test_hailo_semantic_plan import dense_fixture
import test_hailo_primitive_recipes as primitive_checks

CONFIG = argparse.Namespace()
KINDS = ["rotary_inverse_frequency", "rotary_angles", "cos", "sin", "rotary_first", "rotary_second",
         "multiply_rotary_cos", "multiply_rotary_sin", "subtract", "multiply_rotary_sin",
         "multiply_rotary_cos", "add", "rotary_assemble"]
EDGES = [[], [1,2], [3], [3], [0], [0], [6,4], [7,5], [8,9], [6,5], [7,4], [11,12], [10,13,0]]
PRE = ["finite_activation_inputs", "positions_equal_past_plus_query_index", "finite_exact_integer_positions",
       "real_rotation_identity_only_precision_unqualified"]


def pairs(width, basis):
    half = width // 2
    return [(j, j+half) if basis == "split_half" else (2*j, 2*j+1) for j in range(half)]


def isolated_primitive(recipe, meta, x, positions):
    """Only this one rotary operation on synthetic values; never source weights/graph edges."""
    q,h,d = recipe["values"][0]["shape"]
    r = meta["rotary_dim"]; p = r//2
    base = struct.unpack("<f", struct.pack("<I", meta["rotary_base_bits"]))[0]
    values = [x, positions]
    for op in recipe["operations"]:
        args = [values[i] for i in op["inputs"]]
        kind = op["kind"]
        if kind == "rotary_inverse_frequency": out = [base**(-2*j/r) for j in range(p)]
        elif kind == "rotary_angles": out = [position*f for position in args[0] for f in args[1]]
        elif kind == "cos": out = list(map(math.cos,args[0]))
        elif kind == "sin": out = list(map(math.sin,args[0]))
        elif kind in ("rotary_first", "rotary_second"):
            coordinate = 0 if kind == "rotary_first" else 1
            out = [args[0][(t*h+head)*d+ab[coordinate]] for t in range(q) for head in range(h)
                   for ab in pairs(r,meta["pairing"])]
        elif kind in ("multiply_rotary_cos", "multiply_rotary_sin"):
            out = [v*args[1][(i//(h*p))*p+i%p] for i,v in enumerate(args[0])]
        elif kind == "subtract": out = [a-b for a,b in zip(*args)]
        elif kind == "add": out = [a+b for a,b in zip(*args)]
        elif kind == "rotary_assemble":
            out = args[2].copy()
            for t in range(q):
                for head in range(h):
                    for j,(a,b) in enumerate(pairs(r,meta["pairing"])):
                        out[(t*h+head)*d+a] = args[0][(t*h+head)*p+j]
                        out[(t*h+head)*d+b] = args[1][(t*h+head)*p+j]
        else: raise AssertionError(kind)
        assert len(out) == recipe["values"][op["output"]]["elements"]
        assert op["output"] == len(values)
        values.append(out)
    return values[recipe["result"]]


class RotaryRecipes(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.api = str(Path(CONFIG.api).resolve(strict=True))
        cls.temp = tempfile.TemporaryDirectory(prefix="aesir-rotary-")
        cls.root = Path(cls.temp.name)
        cls.evidence = Path(CONFIG.evidence).resolve(); cls.evidence.mkdir(parents=True,exist_ok=True)
        cls.runs = []; cls.math = []

    @classmethod
    def tearDownClass(cls):
        (cls.evidence/"runs.json").write_text(json.dumps(cls.runs,indent=2)+"\n")
        (cls.evidence/"isolated-primitive.json").write_text(json.dumps(cls.math,indent=2)+"\n")
        cls.temp.cleanup()
        print("Native child scopes: "+str(dict(Counter(x["scope"] for x in cls.runs))))

    def child(self, command, source, scope):
        identity = hashlib.sha256(source.read_bytes()).hexdigest()
        result = subprocess.run(command,capture_output=True,text=True,stdin=subprocess.DEVNULL,timeout=30)
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),identity)
        self.runs.append(dict(scope=scope,command=command,source_sha256=identity,returncode=result.returncode,
                              stdout=result.stdout,stderr=result.stderr))
        return result

    def accept(self, *, basis="split_half", layers=1, key=4, rotary=4, mask=None, session=(2,1,16),
               value=3, theta=10000., tied=False, kind=1, trace=False, work=10000000, provenance="test-only explicit basis"):
        raw = dense_fixture(layers=layers,key=key,value=value,tied=tied,matrix_kind=kind,
                            hidden=256 if kind==12 else 8,ff=512 if kind==12 else 12,
                            overrides={"llama.rope.dimension_count":(10,rotary),"llama.rope.freq_base":(6,theta)})[0]
        source = self.root/("case-"+str(len(self.runs))+".gguf");source.write_bytes(raw)
        command = [self.binary,str(source),*map(str,session),basis,provenance,"1000",str(work),
                   ",".join(map(str,mask if mask is not None else [1]*layers))]
        if trace:
            command = [CONFIG.strace,"-f","-y","-o",str(self.evidence/"rotary.strace"),"-e",
                       "trace=openat,openat2,connect,ioctl",*command]
        result = self.child(command,source,"rotary")
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        data = json.loads(result.stdout)
        self.check(data,theta)
        return data,source

    def check(self,data,theta):
        for name in ("executable_program","device_execution_verified","ordinary_model_admitted","hardware_fit_verified","source_identity_verified"):
            self.assertIs(data[name],False)
        source = data["source_graph"]; recipes=data["recipes"]; expanded=data["expanded"]
        recipe_map={r["source_operation"]:r for r in recipes["recipes"]}
        selected=[i for i,o in enumerate(source["operations"]) if o["kind"] in ("rope_query","rope_key")]
        meta={m["source_operation"]:m for m in data["rotary_mappings"]}
        self.assertEqual(list(meta),selected)
        self.assertEqual(data["policy"]["charged_work"],len(source["operations"])+len(selected)*(128+len(data["policy"]["pairing"].encode())+len(data["policy"]["provenance"].encode())))
        ordinary=copy.deepcopy(recipes)
        ordinary["recipes"]=[r for r in ordinary["recipes"] if r["source_operation"] not in selected]
        ordinary["remaining_source_operations"]=[dict(id=i,kind=o["kind"]) for i,o in enumerate(source["operations"])
                                                if o["kind"] not in ("rms_norm","silu","softmax")]
        primitive_checks.PrimitiveRecipes("runTest").check_recipes(ordinary,source)
        for i in selected:
            r=recipe_map[i];op=source["operations"][i];m=meta[i]
            shape=source["tensors"][op["inputs"][0]]["shape"]; q,h,d=shape;p=m["rotary_dim"]//2
            self.assertEqual(m["source_inputs"],op["inputs"]);self.assertEqual(m["input_values"],[0,1])
            self.assertEqual(m["rotary_base_bits"],struct.unpack("<I",struct.pack("<f",theta))[0])
            self.assertEqual(m["rotary_dim"],source["parameters"]["rope_dim"])
            self.assertEqual(m["pairing"],data["policy"]["pairing"]);self.assertEqual(m["provenance"],data["policy"]["provenance"])
            self.assertEqual([o["kind"] for o in r["operations"]],KINDS)
            self.assertEqual([o["inputs"] for o in r["operations"]],EDGES)
            shapes=[shape,[q],[p],[q,p],[q,p],[q,p],*([[q,h,p]]*8),shape]
            self.assertEqual([v["shape"] for v in r["values"]],shapes)
            self.assertEqual(r["result"],14);self.assertEqual(r["runtime_preconditions"],PRE)
            self.assertEqual(r["source_output"],op["output"]);self.assertEqual(r["weight_name"],"")
            for j,v in enumerate(r["values"]):
                self.assertEqual(v["producer"],-1 if j<2 else j-2)
                uses=[k for k,o in enumerate(r["operations"]) if j in o["inputs"]]
                self.assertEqual(v["last_use"],13 if j==14 else max(uses,default=v["producer"]))
                self.assertEqual(v["domain"],"index" if j==1 else "real")
                self.assertEqual(v["elements"],math.prod(v["shape"]))
        mapping=expanded["source_to_global"];values=expanded["values"];ops=expanded["operations"]
        self.assertEqual(len(mapping),len(source["tensors"]));self.assertEqual(len(set(mapping)),len(mapping))
        for i,t in enumerate(source["tensors"]):
            v=values[mapping[i]]
            for key in ("name","shape","elements"):self.assertEqual(v[key],t[key])
            self.assertEqual(v["source_tensor"],i)
            if t["alias_of"]>=0:self.assertEqual(v["alias_of"],mapping[t["alias_of"]])
        groups={i:[] for i in range(len(source["operations"]))}
        for o in ops:groups[o["source_operation"]].append(o)
        order=[];metadata={m["operation"]:m for m in data["expanded_rotary_metadata"]}
        for i,o in enumerate(source["operations"]):
            group=groups[i];order.extend([i]*len(group))
            if i not in recipe_map:
                self.assertEqual(len(group),1);self.assertEqual(group[0]["kind"],o["kind"])
                inputs=[mapping[t] for t in o["inputs"]]
                if o["weight"]:inputs.append(expanded["weights"][o["weight"]]["value"])
                self.assertEqual(group[0]["inputs"],inputs)
                self.assertEqual(group[0]["output"],mapping[o["output"]])
            else:
                r=recipe_map[i]
                local={j:mapping[t] for j,t in enumerate(o["inputs"])}
                if r["weight_name"]:local[1]=expanded["weights"][r["weight_name"]]["value"]
                self.assertEqual(len(group),len(r["operations"]))
                for j,(actual,wanted) in enumerate(zip(group,r["operations"])):
                    self.assertEqual(actual["kind"],wanted["kind"]);self.assertEqual(actual["recipe_step"],j)
                    self.assertEqual(actual["inputs"],[local[t] for t in wanted["inputs"]])
                    local[wanted["output"]]=actual["output"]
                    v=values[actual["output"]];w=r["values"][wanted["output"]]
                    self.assertEqual(v["shape"],w["shape"]);self.assertEqual(v["domain"],w["domain"])
                    self.assertEqual(actual["runtime_preconditions"],r["runtime_preconditions"])
                    self.assertEqual(actual["width"],r["divisor"]);self.assertEqual(actual["epsilon_bits"],r["epsilon_bits"])
                    if i in meta:
                        self.assertEqual(metadata[actual["id"]],dict(operation=actual["id"],rotary_dim=meta[i]["rotary_dim"],rotary_base_bits=meta[i]["rotary_base_bits"],pairing=meta[i]["pairing"],provenance=meta[i]["provenance"]))
                    else:self.assertNotIn(actual["id"],metadata)
                self.assertEqual(local[r["result"]],mapping[o["output"]])
        self.assertEqual([o["source_operation"] for o in ops],order)
        self.assertEqual(len(metadata),13*len(selected))
        for j,v in enumerate(values):
            self.assertEqual(v["id"],j);self.assertEqual(v["elements"],math.prod(v["shape"]))
            producing=[k for k,o in enumerate(ops) if o["output"]==j]
            self.assertEqual(producing,[] if v["producer"]==-1 else [v["producer"]])
            uses=[k for k,o in enumerate(ops) if j in o["inputs"]]
            retain=v["storage"] in ("persistent_kv","source_weight") or j==expanded["result"]
            self.assertEqual(v["last_use"],len(ops) if retain else max(uses,default=v["producer"]))
            for use in uses:self.assertLess(v["producer"],use)
        self.assertEqual(expanded["result"],mapping[source["logits"]])
        expected_remaining=[dict(id=i,kind=o["kind"]) for i,o in enumerate(source["operations"]) if i not in recipe_map]
        self.assertEqual(recipes["remaining_source_operations"],expected_remaining)
        self.assertEqual(expanded["unexpanded_source_operations"],expected_remaining)
        storage=data["storage"];sizes=[]
        for v in values:
            width=8 if v["storage"]=="index" else 1 if v["domain"]=="predicate" else 2
            sizes.append(0 if v["storage"] in ("source_weight","kv_view") else ((v["elements"]*width+15)//16)*16)
        self.assertEqual(storage["value_bytes"],sizes)
        real=[];pred=[]
        for step in range(len(ops)+1):
            live=[j for j,v in enumerate(values) if v["storage"]=="activation" and v["producer"]<=step<=v["last_use"]]
            real.append(sum(sizes[j] for j in live if values[j]["domain"]=="real"))
            pred.append(sum(sizes[j] for j in live if values[j]["domain"]=="predicate"))
        total=[a+b for a,b in zip(real,pred)]
        self.assertEqual(storage["real_live_bytes"],real);self.assertEqual(storage["predicate_live_bytes"],pred)
        self.assertEqual(storage["activation_live_bytes"],total)
        kv=sum(sizes[j] for j,v in enumerate(values) if v["storage"]=="persistent_kv")
        indices=sum(sizes[j] for j,v in enumerate(values) if v["storage"]=="index")
        self.assertEqual(storage["persistent_kv_bytes"],kv);self.assertEqual(storage["input_bytes"],indices)
        self.assertEqual(storage["peak_activation_bytes"],max(total));self.assertEqual(storage["peak_step"],total.index(max(total)))
        self.assertEqual(storage["total_bytes"],kv+indices+max(total)+source["weight_bytes"])

    def test_complete_structure_bases_tails_heads_masks_sessions(self):
        for basis in ("adjacent","split_half"):
            for key,rotary in ((2,2),(4,4),(6,4),(8,6)):
                for mask in ([1],[0],[1,0,1]):
                    self.accept(basis=basis,key=key,rotary=rotary,layers=len(mask),mask=mask,value=3,
                                session=(3,2,16),tied=bool(rotary%4))
        self.accept(key=64,rotary=32,kind=12,value=64)
        self.accept(layers=4,mask=[1,1,1,0],key=128,rotary=128,theta=5000000.,session=(1,7,16))

    def test_exact_policy_charge_unicode_and_nope(self):
        for mask in ([1],[0]):
            data,_=self.accept(mask=mask,provenance="basis λ原")
            exact=data["policy"]["charged_work"]
            self.accept(mask=mask,work=exact,provenance="basis λ原")
            raw=dense_fixture()[0];path=self.root/"short.gguf";path.write_bytes(raw)
            result=self.child([self.binary,str(path),"2","1","16","split_half","basis λ原","100",str(exact-1),str(mask[0])],path,"policy_refusal")
            self.assertNotEqual(result.returncode,0)

    def test_isolated_one_primitive_complex_rotation_and_static_pair_oracle(self):
        for basis in ("adjacent","split_half"):
            for key,rotary in ((2,2),(6,4),(8,8)):
                data,_=self.accept(basis=basis,key=key,rotary=rotary,theta=5000000.)
                recipe=next(r for r in data["recipes"]["recipes"] if r["kind"]=="rope_query")
                meta=data["rotary_mappings"][0];q,h,d=recipe["values"][0]["shape"]
                x=[((i*7)%23-11)/4 for i in range(q*h*d)];positions=[0,7]
                actual=isolated_primitive(recipe,meta,x,positions);expected=x.copy()
                for row in range(q*h):
                    for j,(a,b) in enumerate(pairs(rotary,basis)):
                        z=complex(x[row*d+a],x[row*d+b])*cmath.exp(1j*positions[row//h]*5000000.**(-2*j/rotary))
                        expected[row*d+a]=z.real;expected[row*d+b]=z.imag
                    self.assertAlmostEqual(sum(v*v for v in x[row*d:(row+1)*d]),sum(v*v for v in actual[row*d:(row+1)*d]),places=12)
                for a,b in zip(actual,expected):self.assertTrue(math.isclose(a,b,rel_tol=1e-14,abs_tol=1e-14))
                self.math.append(dict(basis=basis,key=key,rotary=rotary,synthetic_input=x,positions=positions,actual=actual,complex_reference=expected))
        oracle=json.loads(Path(CONFIG.oracle).read_text())
        for case in oracle["cases"]:
            x=case["input"];expected=x.copy()
            for a,b in pairs(case["width"],"split_half"):expected[a],expected[b]=-x[b],x[a]
            self.assertEqual(expected,case["rotated"]);self.assertEqual(expected,case["query"])
            self.assertEqual([2*v for v in expected],case["key"])

    def test_native_source_and_expanded_refusals_and_ownership(self):
        path=self.root/"mutations.gguf";path.write_bytes(dense_fixture()[0])
        source=["bad_pairing","empty_provenance","zero_recipe_bound","short_recipe_bound","zero_work","work_short",
                "arity","negative_input","negative_output","weight","input_forward","input_expired","input_rank",
                "input_shape","input_product","input_alias","input_persistent","output_rank","output_shape","output_product",
                "output_producer","output_alias","output_persistent","position_producer","position_name","position_shape",
                "position_product","position_alias","position_persistent","dimension_zero","dimension_odd","dimension_excess",
                "base_zero","base_nan","head_role","product_overflow","source_policy",
                "input_negative_producer","input_excess_lifetime","output_expired","output_excess_lifetime"]
        graph=["pairing","provenance","dim","base","kind","edge","arity","source","step","shape","product","domain",
               "storage","producer","lifetime","position_domain","export","stray_metadata","stray_kind","policy","work",
               "disabled","source_base","width","preconditions",
               "recipe_inputs","recipe_local","recipe_shape","recipe_lifetime","recipe_kind","recipe_edge",
               "recipe_identity","recipe_result","recipe_metadata"]
        for mode in source+["graph_"+x for x in graph]:
            result=self.child([self.api,str(path),mode],path,"refusal:"+mode)
            self.assertNotEqual(result.returncode,0,mode);self.assertEqual(result.stdout,"")
            self.assertTrue(any(prefix in result.stderr for prefix in ("Rotary","SourceInventory","SemanticPlan","ExpandedStorage")),result.stderr)
        for mode in ("ownership","graph_ownership","work_exact"):
            result=self.child([self.api,str(path),mode],path,"ownership_or_exact")
            self.assertEqual(result.returncode,0,result.stderr)

    def test_complete_legacy_outputs_and_read_only_trace(self):
        for i in range(6):
            raw=dense_fixture(layers=1+i%2,key=4,value=3,tied=bool(i%2))[0]
            path=self.root/("legacy-"+str(i)+".gguf");path.write_bytes(raw)
            for name in ("tagged-primitive-recipes","tagged-expanded-graph","tagged-expanded-storage"):
                args=[str(path),"2",str(i%4),"16"]
                if name.endswith("storage"):args += ["2","1","2","8","16","8192","128","1000000","explicit synthetic scenario"]
                old=self.child([str(Path(CONFIG.baseline)/name),*args],path,"frozen_legacy")
                new=self.child([str(Path(CONFIG.binaries)/name),*args],path,"new_legacy")
                self.assertEqual(old.returncode,0,old.stderr);self.assertEqual(new.returncode,0,new.stderr)
                self.assertEqual(new.stdout,old.stdout)
        self.accept(trace=True)
        trace=(self.evidence/"rotary.strace").read_text()
        self.assertNotIn("/dev/h1x",trace);self.assertNotIn("/dev/hailo",trace)
        self.assertNotIn("connect(",trace);self.assertNotIn("libtorch",trace)


if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--binary",required=True);p.add_argument("--api",required=True)
    p.add_argument("--binaries",required=True);p.add_argument("--baseline",required=True);p.add_argument("--oracle",required=True)
    p.add_argument("--strace",default="/usr/bin/strace");p.add_argument("--evidence",required=True)
    CONFIG,remaining=p.parse_known_args();unittest.main(argv=[__file__,*remaining])
