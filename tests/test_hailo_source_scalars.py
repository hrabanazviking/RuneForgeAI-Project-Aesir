#!/usr/bin/env python3
"""Exact compiler constant words/structure only; no numerical model execution."""
import argparse,copy,hashlib,json,math,struct,subprocess,tempfile,unittest
from pathlib import Path
from collections import Counter
from test_hailo_semantic_plan import dense_fixture

CONFIG=argparse.Namespace()

def word(value,width=64):
    return struct.unpack("<Q" if width==64 else "<I",struct.pack("<d" if width==64 else "<f",value))[0]

def structure(value):
    """Remove only declared source scalar metadata, retain every structural field."""
    if isinstance(value,list):return [structure(x) for x in value]
    if isinstance(value,dict):
        out={k:structure(v) for k,v in value.items() if k not in ("source_scalars","epsilon_scalar","rotary_base_scalar","epsilon_bits","rotary_base_bits","rope_base","rms_epsilon")}
        if "schema_version" in out:out["schema_version"]=1
        return out
    return value


class SourceScalars(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bins=Path(CONFIG.binaries).resolve();cls.baseline=Path(CONFIG.baseline).resolve()
        cls.temp=tempfile.TemporaryDirectory(prefix="aesir-source-scalars-");cls.root=Path(cls.temp.name)
        cls.evidence=Path(CONFIG.evidence).resolve();cls.evidence.mkdir(parents=True,exist_ok=True)
        cls.runs=[]

    @classmethod
    def tearDownClass(cls):
        (cls.evidence/"runs.json").write_text(json.dumps(cls.runs,indent=2)+"\n")
        cls.temp.cleanup();print("Native outcomes:",dict(Counter(r["returncode"]==0 for r in cls.runs)),"calls",len(cls.runs))

    def child(self,command,files,scope):
        identities={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
        r=subprocess.run(list(map(str,command)),capture_output=True,text=True,stdin=subprocess.DEVNULL,timeout=30)
        self.assertEqual(identities,{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files})
        self.runs.append(dict(command=list(map(str,command)),scope=scope,identities=identities,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr))
        return r

    def fixture(self,layers=1):
        path=self.root/("fixture-"+str(len(self.runs))+".gguf")
        path.write_bytes(dense_fixture(layers=layers,key=6,value=3,overrides={"llama.rope.dimension_count":(10,4)})[0])
        return path

    def api(self,mode="valid",epsilon=(64,word(1e-6)),base=(64,word(5000000.)),provenance="explicit scalar source λ",limit=1000,mask="1",path=None):
        path=path or self.fixture(len(mask.split(",")))
        args=[self.bins/"source-scalars-api",path,mode,*epsilon,*base,provenance,limit,mask]
        return self.child(args,[path],"api:"+mode),path

    def check(self,data,epsilon,base,provenance):
        self.assertFalse(data["ordinary_model_admitted"]);self.assertFalse(data["device_execution_verified"])
        source=data["source_graph"];recipes=data["recipes"];expanded=data["expanded"]
        self.assertEqual(source["schema_version"],2);self.assertEqual(recipes["schema_version"],2);self.assertEqual(expanded["schema_version"],2)
        self.assertIsNone(source["parameters"]["rms_epsilon"]);self.assertIsNone(source["parameters"]["rope_base"])
        scalars=source["source_scalars"]
        self.assertEqual(scalars["epsilon"],dict(width=epsilon[0],bits=epsilon[1]));self.assertEqual(scalars["rope_base"],dict(width=base[0],bits=base[1]))
        self.assertEqual(scalars["provenance"],provenance);self.assertEqual(scalars["charged_work"],2+len(provenance.encode()))
        self.assertEqual(scalars,recipes["source_scalars"]);self.assertEqual(scalars,expanded["source_scalars"])
        for r in recipes["recipes"]:
            norm=r["kind"]=="rms_norm";rope=r["kind"] in ("rope_query","rope_key")
            self.assertEqual(r["epsilon_scalar"],scalars["epsilon"] if norm else None)
            self.assertEqual(r["rotary_base_scalar"],scalars["rope_base"] if rope else None)
            self.assertEqual(r["epsilon_bits"],None if norm and epsilon[0]==64 else epsilon[1] if norm else 0)
        for op in expanded["operations"]:
            kind=source["operations"][op["source_operation"]]["kind"]
            norm=kind=="rms_norm";rope=kind in ("rope_query","rope_key") and op["recipe_step"]>=0
            self.assertEqual(op["epsilon_scalar"],scalars["epsilon"] if norm else None)
            self.assertEqual(op["rotary_base_scalar"],scalars["rope_base"] if rope else None)
            self.assertEqual(op["epsilon_bits"],None if norm and epsilon[0]==64 else epsilon[1] if norm else 0)
        for meta in data["rotary_mappings"]:
            self.assertEqual(meta["rotary_base_bits"],None if base[0]==64 else base[1])

    def test_exact_words_extremes_neighbors_mixed_sources_and_full_structure(self):
        values=[1e-6,math.nextafter(1e-6,math.inf),math.nextafter(1e-6,0.),5e-324,float.fromhex("0x1.fffffffffffffp+1023"),1e-300,1e300,1.,2.**-126,2.**40+1]
        self.assertEqual(word(values[0],32),word(values[1],32))
        for index,value in enumerate(values):
            epsilon=(64,word(value));base=(64,word(values[-1-index]))
            r,path=self.api(epsilon=epsilon,base=base,mask="1,0,1" if index%3==0 else "1")
            self.assertEqual(r.returncode,0,r.stderr);data=json.loads(r.stdout);self.check(data,epsilon,base,"explicit scalar source λ")
            mask="1,0,1" if index%3==0 else "1"
            old=self.child([self.baseline/"rotary-recipes",path,2,1,16,"split_half","explicit synthetic basis",1000,1000000,mask],[path],"frozen_structure")
            self.assertEqual(old.returncode,0,old.stderr);self.assertEqual(structure(data),structure(json.loads(old.stdout)))
        for ew,bw in ((32,32),(32,64),(64,32)):
            epsilon=(ew,word(1e-6,ew));base=(bw,word(10000.,bw))
            r,_=self.api(epsilon=epsilon,base=base);self.assertEqual(r.returncode,0,r.stderr)
            self.check(json.loads(r.stdout),epsilon,base,"explicit scalar source λ")
        r,_=self.api(mode="opaque");self.assertEqual(r.returncode,0,r.stderr)
        data=json.loads(r.stdout);self.check(data,(64,word(1e-6)),(64,word(5000000.)),"explicit scalar source λ")
        self.assertFalse(data["rotary_mappings"])

    def test_word_encoding_provenance_bounds_and_derived_refusals(self):
        bad=[(0,0),(16,1),(32,1<<32),(32,0),(32,0x80000000),(32,0xbf800000),(32,0x7f800000),(32,0x7fc00000),
             (64,0),(64,0x8000000000000000),(64,0xbff0000000000000),(64,0x7ff0000000000000),(64,0xfff0000000000000),(64,0x7ff8000000000000)]
        for scalar in bad:
            for role in ("epsilon","base"):
                r,_=self.api(**{role:scalar});self.assertNotEqual(r.returncode,0,(role,scalar));self.assertEqual(r.stdout,"")
        for provenance,limit in (("",100),("valid",0),("valid",6),("λ",3)):
            r,_=self.api(provenance=provenance,limit=limit);self.assertNotEqual(r.returncode,0,r.stderr)
        r,_=self.api(provenance="λ",limit=4);self.assertEqual(r.returncode,0,r.stderr)
        modes=["geometry","source_bound","legacy_epsilon","legacy_negative_zero","state_disabled","state_provenance","state_width","state_zero",
               "graph_norm_word","graph_norm_width","graph_norm_mirror","graph_rope_word","graph_rope_width","graph_rope_mirror",
               "graph_stray_epsilon","graph_stray_base","graph_recipe_word","graph_recipe_mirror","graph_snapshot_word","graph_snapshot_provenance",
               "graph_source_word","graph_source_provenance","graph_legacy_slot","graph_snapshot_mode"]
        for mode in modes:
            r,_=self.api(mode);self.assertNotEqual(r.returncode,0,mode);self.assertEqual(r.stdout,"")
        for mode in ("ownership","graph_ownership"):
            r,_=self.api(mode);self.assertEqual(r.returncode,0,r.stderr)

    def test_actual_ordinary_factory_raw_owner_and_read_only_path(self):
        configs=[{"model_type":"smollm3"},json.loads(Path(CONFIG.public_config).read_text())]
        configs += [dict(model_type="smollm3",rms_norm_eps=e,rope_theta=b) for e,b in ((5e-324,1e300),(1e300,1e-300),(1e-6,1000000000001.))]
        for i,config in enumerate(configs):
            path=self.fixture();cfg=self.root/("config-"+str(i)+".json");cfg.write_text(json.dumps(config))
            cmd=[self.bins/"decoder-scalar-source",path,cfg,2,1,16,"split_half","1","ordinary source λ",1000]
            if i==1:cmd=[CONFIG.strace,"-f","-y","-o",self.evidence/"source-scalars.strace","-e","trace=openat,openat2,connect,ioctl",*cmd]
            r=self.child(cmd,[path,cfg],"ordinary_factory");self.assertEqual(r.returncode,0,r.stderr)
            data=json.loads(r.stdout);self.assertFalse(data["ordinary_model_admitted"]);self.assertTrue(data["unresolved"])
            self.assertEqual({k:json.loads(v) for k,v in data["source_fields"].items()},config)
            self.check(data["lowered"],(64,word(config.get("rms_norm_eps",1e-6))),(64,word(config.get("rope_theta",2000000.))),"ordinary source λ")
        trace=(self.evidence/"source-scalars.strace").read_text()
        self.assertNotIn("/dev/h1x",trace);self.assertNotIn("/dev/hailo",trace);self.assertNotIn("connect(",trace);self.assertNotIn("libtorch",trace)
        for field,value in (("rms_norm_eps",0),("rope_theta",-1),("rms_norm_eps",None),("rope_theta","1")):
            path=self.fixture();cfg=self.root/"invalid.json";cfg.write_text(json.dumps(dict(model_type="smollm3",**{field:value})))
            r=self.child([self.bins/"decoder-scalar-source",path,cfg,2,1,16,"split_half","1","source",1000],[path,cfg],"factory_refusal")
            self.assertNotEqual(r.returncode,0);self.assertEqual(r.stdout,"")

    def test_complete_legacy_consumer_outputs(self):
        for i in range(4):
            path=self.fixture(1+i%2)
            for name in ("tagged-semantic-plan","tagged-primitive-recipes","tagged-expanded-graph","tagged-expanded-storage","rotary-recipes"):
                args=[path,2,1,16]
                if name=="tagged-expanded-storage":args += [2,1,2,8,16,8192,0,1000000,"synthetic"]
                if name=="rotary-recipes":args += ["split_half","explicit",1000,1000000,",".join(["1"]*(1+i%2))]
                old=self.child([self.baseline/name,*args],[path],"legacy_frozen")
                new=self.child([self.bins/name,*args],[path],"legacy_current")
                self.assertEqual(old.returncode,0,old.stderr);self.assertEqual(new.returncode,0,new.stderr);self.assertEqual(new.stdout,old.stdout)


if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--binaries",required=True);p.add_argument("--baseline",required=True)
    p.add_argument("--public-config",required=True);p.add_argument("--evidence",required=True);p.add_argument("--strace",default="/usr/bin/strace")
    CONFIG,rest=p.parse_known_args();unittest.main(argv=[__file__,*rest])
