#!/usr/bin/env python3
"""Source/header, integer lineage and exact-word acceptance; no inference."""
import argparse
import copy
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import random
import struct
import subprocess
import unittest

from test_hailo_ordinary_projection_schema import declared
from test_hailo_safetensors_inventory import fixture

CONFIG = None
RECORDS = []
SOURCE_INPUTS = {}
PROVENANCE = "original dynamic context æ𝄞"

def word(value, width=64):
    return struct.unpack("<Q" if width == 64 else "<I", struct.pack("<d" if width == 64 else "<f", value))[0]

def replay(reference, initial, ends):
    state, states = initial, []
    for end in ends:
        state = reference if end < reference else max(state, end)
        states.append(state)
    return states

def csv(values):
    return ",".join(map(str, values)) if values else "-"

class DynamicDecoderHistory(unittest.TestCase):
    def child(self, args, refused=False, trace=None):
        args = list(map(str, args))
        command = args if trace is None else ["strace", "-f", "-yy", "-qq", "-o", str(CONFIG.evidence / trace), "-e", "trace=%file,%network,pread64,close,mmap,ioctl", *args]
        result = subprocess.run(command, text=True, capture_output=True, timeout=60, stdin=subprocess.DEVNULL)
        RECORDS.append(dict(args=args, returncode=result.returncode, expected_refusal=refused,
                            stdout_bytes=len(result.stdout.encode()), stdout_sha256=hashlib.sha256(result.stdout.encode()).hexdigest(), stderr=result.stderr, trace=trace))
        if refused:
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, "")
            self.assertNotIn("INVALID:", result.stderr)
            self.assertIn("Unhandled exception caught during execution:", result.stderr)
            return
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        return json.loads(result.stdout)

    def history(self, reference=8, limit=64, initial=None, ends=(), contexts=None,
                query=1, past=None, capacity=None, theta=2000000.0, factor=2.0,
                tw=64, fw=64, theta_bits=None, factor_bits=None, work=100000,
                hwork=None, source_work=1000000, origin="invocation", ref_origin="invocation",
                provenance=PROVENANCE, case="valid", refused=False):
        initial = reference if initial is None else initial
        contexts = replay(reference, initial, ends) if contexts is None else contexts
        past = (ends[-1] if ends else 0) if past is None else past
        capacity = limit if capacity is None else capacity
        hwork = work if hwork is None else hwork
        return self.child([CONFIG.history, reference, limit, tw, word(theta,tw) if theta_bits is None else theta_bits,
                           fw, word(factor,fw) if factor_bits is None else factor_bits, origin, ref_origin,
                           provenance, work, hwork, source_work, initial, csv(ends), csv(contexts), past,
                           query, capacity, case], refused)

    def check_history(self, obj, reference, limit, initial, ends, query,
                      factor=2.0, theta=2000000.0, fw=64, tw=64, provenance=PROVENANCE,
                      origin="invocation", ref_origin="invocation", work=100000, hwork=None):
        hwork = work if hwork is None else hwork
        base = 256+len(origin.encode())+len(ref_origin.encode())+len(provenance.encode())
        policy = dict(kind="dynamic",factor=dict(width=fw,bits=word(factor,fw)),theta=dict(width=tw,bits=word(theta,tw)),reference=reference,limit=limit,origin=origin,reference_origin=ref_origin,provenance=provenance,work=work,charged_work=base)
        for name, chain in [("before",list(ends)),("after",[*ends,(ends[-1] if ends else 0)+query])]:
            states = replay(reference, initial, chain)
            selected = states[-1] if states else initial
            wanted = dict(policy=policy,initial_selected=initial,end_tokens=chain,selected_contexts=states,work=hwork,charged_work=base+128+128*len(chain),pair0_identity=dict(width=2,pair=0,theta_num=0,theta_den=1,gain_num=0,gain_den=1,delta_num=selected-reference,delta_den=reference))
            self.assertEqual(obj[name], wanted)
        if "coefficients" in obj:
            selected=obj["after"]["selected_contexts"][-1]
            c=obj["coefficients"]
            self.assertEqual(c,[-2,6,-2,4,selected-reference,reference])
            self.assertEqual(Fraction(*c[:2]),Fraction(-1,3))
            self.assertEqual(Fraction(*c[2:4]),Fraction(-1,2))

    def source_fixture(self, config=None, shards=1):
        base, roles = declared(heads=2,kv=1,dimension=4,explicit=True)
        base.update(max_position_embeddings=8,no_rope_layers=[1,0],rope_theta=2000000.0,
                    rope_scaling={"rope_type":"dynamic","factor":2.0,"original_max_position_embeddings":4,"custom":[1,True,"æ\u0000𝄞"]})
        if config is not None:
            base.update(config)
            for k in list(base):
                if base[k] == "OMIT": del base[k]
        root = CONFIG.evidence / "fixtures" / str(len(list((CONFIG.evidence / "fixtures").iterdir())))
        root.mkdir()
        (root/"config.json").write_text(json.dumps(base,ensure_ascii=False,separators=(",",":")))
        mapping, total = {}, 0
        for shard in range(shards):
            entries=[(name,"BF16",shape) for index,(name,(_,shape)) in enumerate(roles.items()) if index%shards==shard]
            raw, expected, _=fixture(entries,metadata={"format":"pt","custom\u0000":"æ𝄞"})
            label=f"source-{shard}.weights"; (root/label).write_bytes(raw)
            total += sum(e["bytes"] for e in expected.values())
            mapping.update({name:label for name,_,_ in entries})
        if shards > 1:
            (root/"index.json").write_text(json.dumps(dict(metadata=dict(total_size=total),weight_map=mapping),separators=(",",":")))
        for p in root.iterdir(): SOURCE_INPUTS[str(p)] = hashlib.sha256(p.read_bytes()).hexdigest()
        return root, base, shards

    def source(self, data, limit=64, initial=8, ends=(), query=1, capacity=64,
               contexts=None, past=None, work=100000, case="valid", refused=False, trace=None):
        root,config,shards=data
        reference=config.get("max_position_embeddings",32768)
        contexts=replay(reference,initial,ends) if contexts is None else contexts
        past=(ends[-1] if ends else 0) if past is None else past
        return self.child([CONFIG.source,"unindexed" if shards==1 else "indexed",root,"source-0.weights" if shards==1 else "index.json","config.json",limit,initial,csv(ends),csv(contexts),past,query,capacity,work,PROVENANCE,case],refused,trace)

    def test_integer_histories_words_and_extremes(self):
        rng=random.Random(9127)
        for index in range(96):
            ref=rng.randint(1,16);limit=ref+rng.randint(4,32)
            initial=ref if index%2 else limit
            ends=sorted(rng.sample(range(1,limit),rng.randint(0,min(4,limit-1))))
            query=rng.randint(1,limit-(ends[-1] if ends else 0))
            fw=32 if index%2 else 64;tw=32 if index%3 else 64
            factor=(0.5,1.0,2.0,8.0)[index%4]
            obj=self.history(reference=ref,limit=limit,initial=initial,ends=ends,query=query,fw=fw,tw=tw,factor=factor)
            self.check_history(obj,ref,limit,initial,ends,query,fw=fw,tw=tw,factor=factor)
        for kwargs in [dict(reference=1,limit=(1<<63)-1,initial=(1<<63)-1,query=(1<<63)-1),
                       dict(reference=(1<<63)-1,limit=(1<<63)-1,query=(1<<63)-1),
                       dict(initial=32,ends=[4,8],query=1,capacity=9),
                       dict(initial=32,ends=[8],query=1,capacity=9),
                       dict(initial=64,ends=[4,8,17],query=15,capacity=32)]:
            obj=self.history(**kwargs)
            self.check_history(obj,kwargs.get("reference",8),kwargs.get("limit",64),kwargs.get("initial",kwargs.get("reference",8)),kwargs.get("ends",()),kwargs["query"])
        a=self.history(initial=32,ends=[4,8],capacity=9)
        b=self.history(initial=32,ends=[8],capacity=9)
        self.assertEqual(a["after"]["selected_contexts"],[8,8,9])
        self.assertEqual(b["after"]["selected_contexts"],[32,32])
        obj=self.history(case="initial")
        self.check_history(obj,8,64,8,(),1)
        obj=self.history(case="nul")
        self.check_history(obj,8,64,8,(),1,provenance=PROVENANCE+"\0tail")
        for fw,tw,factor,theta in [(32,64,2**-149,1e300),(64,32,1e-320,2**-149),(64,64,1e300,1e-320)]:
            obj=self.history(fw=fw,tw=tw,factor=factor,theta=theta)
            self.check_history(obj,8,64,8,(),1,fw=fw,tw=tw,factor=factor,theta=theta)

    def test_bounds_mutations_copies_and_recovery(self):
        base=256+len("invocation")*2+len(PROVENANCE.encode()); exact=base+128+128*3
        obj=self.history(ends=[4,8],work=exact,hwork=exact)
        self.check_history(obj,8,64,8,[4,8],1,work=exact,hwork=exact)
        self.history(ends=[4,8],work=exact,hwork=exact-1,refused=True)
        bad=[dict(reference=0),dict(limit=7),dict(initial=7),dict(initial=65),dict(ends=[8,4]),
             dict(ends=[4],contexts=[]),dict(ends=[4],contexts=[9]),dict(ends=[4],past=5),
             dict(ends=[4],past=-1),dict(ends=[65]),dict(ends=[4,8],query=0),dict(query=-1),
             dict(capacity=0),dict(capacity=65),dict(ends=[8],capacity=8),dict(query=(1<<63)-1),
             dict(work=300),dict(hwork=100001),dict(source_work=99999),dict(origin="future"),
             dict(ref_origin="source"),dict(provenance=""),dict(fw=16,factor_bits=1),
             dict(fw=32,factor_bits=(1<<32)),dict(factor_bits=0),dict(factor_bits=0x7ff0000000000000),
             dict(theta_bits=0x7ff8000000000000),dict(theta_bits=0x8000000000000000),
             dict(origin="source:modern",ref_origin="source",fw=32),
             dict(initial=32,ends=[8],contexts=[8])]
        for kwargs in bad:self.history(**kwargs,refused=True)
        for field in range(19):
            self.history(ends=[4,8],case=f"mutate:{field}",refused=True)
            obj=self.history(ends=[4,8],case="copy")
            self.check_history(obj,8,64,8,[4,8],1)

    def test_source_projection_raw_words_and_frozen_outputs(self):
        variants=[({},"source:modern"),({"rope_scaling":{"type":"dynamic","factor":1.0}},"source:legacy"),
                  ({"rope_scaling":{"type":"dynamic","rope_type":"linear","factor":0.5}},"source:legacy"),
                  ({"max_position_embeddings":"OMIT"},"source:modern"),
                  ({"rope_theta":"OMIT"},"source:modern"),({"rope_theta":1e-320},"source:modern"),
                  ({"rope_scaling":{"rope_type":"dynamic","factor":1e300}},"source:modern"),
                  ({"rope_scaling":{"rope_type":"dynamic","factor":1e-320}},"source:modern")]
        for index,(patch,origin) in enumerate(variants):
            data=self.source_fixture(patch,1 if index%2==0 else 2);root,config,shards=data
            ref=config.get("max_position_embeddings",32768);limit=max(ref+8,64)
            obj=self.source(data,limit=limit,initial=ref,capacity=limit,case="copy" if index%2 else "valid")
            self.check_history(obj,ref,limit,ref,(),1,factor=config["rope_scaling"]["factor"],theta=config.get("rope_theta",2000000.0),origin=origin,ref_origin="source" if "max_position_embeddings" in config else "documented_default:32768")
            for key in ["ordinary_model_admitted","source_graph_integrated","device_execution_verified"]:self.assertIs(obj[key],False)
            fields=obj["original_source"]["binding"]["architecture"]["layers"]["source"]["fields_raw"]
            self.assertEqual({key:json.loads(value) for key,value in fields.items()},config)
            old=self.child([CONFIG.frozen,"unindexed" if shards==1 else "indexed",root,"source-0.weights" if shards==1 else "index.json","config.json",1,0,8,2,"1,0","0,0","0,0","source64","split_half",1000000,"frozen source descriptor comparison","silu,silu","full_prefix",0,"0,0","default",64,word(1.0)])
            self.assertEqual(obj["original_source"],old["original_source"])
        data=self.source_fixture();obj=self.source(data,initial=32,ends=[4,8],capacity=9,trace="source-growth.strace")
        self.check_history(obj,8,64,32,[4,8],1,origin="source:modern",ref_origin="source")
        self.assertEqual(obj["after"]["selected_contexts"],[8,8,9])
        obj=self.source(data,case="nul",trace="source-nul.strace")
        self.check_history(obj,8,64,8,(),1,origin="source:modern",ref_origin="source",provenance=PROVENANCE+"\0tail")

    def test_source_refusals_and_fresh_recovery(self):
        good=self.source_fixture(shards=2)
        cases=[{"rope_scaling":None},{"rope_scaling":"OMIT"},{"rope_scaling":{}},
               {"rope_scaling":{"rope_type":"default"}},{"rope_scaling":{"rope_type":"future","factor":2}},
               {"rope_scaling":{"type":"linear","rope_type":"dynamic","factor":2}},
               {"rope_scaling":{"rope_type":"dynamic"}},
               *[{"rope_scaling":{"rope_type":"dynamic","factor":value}} for value in [0,-1,"2",None,True]],
               {"max_position_embeddings":None},{"rope_theta":0}]
        for index,patch in enumerate(cases):
            data=self.source_fixture(patch,1 if index%2 else 2)
            self.source(data,refused=True,trace=f"refusal-{index}.strace")
            self.source(good,initial=32,ends=[4,8],capacity=9,trace=f"recovery-{index}.strace")
        for case in ["source_policy_factor","source_policy_theta","source_policy_reference","source_policy_origin","source_policy_reference_origin","source_policy_width","source_flag","source_layer","source_work","source_raw"]:
            self.source(good,case=case,refused=True)
            self.source(good,initial=32,ends=[4,8],capacity=9,case="copy")
        for path,h in SOURCE_INPUTS.items():self.assertEqual(hashlib.sha256(Path(path).read_bytes()).hexdigest(),h)

if __name__ == "__main__":
    p=argparse.ArgumentParser();p.add_argument("--history",type=Path,required=True);p.add_argument("--source",type=Path,required=True);p.add_argument("--frozen",type=Path,required=True);p.add_argument("--evidence",type=Path,required=True)
    CONFIG=p.parse_args()
    for binary in [CONFIG.history,CONFIG.source,CONFIG.frozen]:
        assert binary.is_file() and binary.stat().st_mode & 0o111, str(binary)
    CONFIG.evidence.mkdir(parents=True,exist_ok=False);(CONFIG.evidence/"fixtures").mkdir()
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(DynamicDecoderHistory))
    report=dict(methods=result.testsRun,failures=len(result.failures),errors=len(result.errors),native_child_calls=len(RECORDS),accepted=sum(not r["expected_refusal"] for r in RECORDS),expected_refusals=sum(r["expected_refusal"] for r in RECORDS),source_inputs=SOURCE_INPUTS,calls=RECORDS,model_layer_attention_or_device_execution=False)
    (CONFIG.evidence/"runs.json").write_text(json.dumps(report,indent=2)+"\n")
    raise SystemExit(not result.wasSuccessful())
