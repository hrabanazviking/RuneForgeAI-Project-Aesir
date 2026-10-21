#!/usr/bin/env python3
"""Independent qualified source header/bias oracle. No numerical model evaluation."""
import argparse
import copy
import itertools
import json
from pathlib import Path
import unittest
import test_hailo_decoder_projections as old

CONFIG = argparse.Namespace()


def declared(layers=2, hidden=8, heads=4, kv=2, dimension=None, attention=False, mlp=False, explicit=False, tie=True, output=False):
    d = hidden // heads if dimension is None else dimension
    config, roles = old.declared(layers=layers, hidden=hidden, heads=heads, kv=kv, key=d, value=d, tie=tie, head=output)
    config.update(attention_bias=attention, mlp_bias=mlp)
    if explicit:
        config["head_dim"] = d
    for name, (canonical, shape) in list(roles.items()):
        if (attention and "self_attn." in name) or (mlp and "mlp." in name):
            roles[name.replace(".weight", ".bias")] = (canonical.replace(".weight", ".bias"), [shape[0]])
    return config, roles


class OrdinaryProjectionSchema(unittest.TestCase):
    setUpClass = classmethod(old.DecoderProjections.setUpClass.__func__)
    tearDownClass = classmethod(old.DecoderProjections.tearDownClass.__func__)
    child = old.DecoderProjections.child
    accept = old.DecoderProjections.accept
    refuse = old.DecoderProjections.refuse
    collection = old.DecoderProjections.collection
    invoke = old.DecoderProjections.invoke

    def check(self, obj, config, expected, d, provenance="explicit ordinary projection test"):
        self.assertEqual(obj["scope"], "qualified_ordinary_projection_headers")
        for flag in ("complete_architecture_verified", "execution_tested", "device_access"):
            self.assertIs(obj[flag], False)
        self.assertEqual(obj["head_dim"], d)
        self.assertEqual(obj["head_dim_origin"], "source:head_dim" if "head_dim" in config else "qualified_constructor:floor(hidden_size/num_attention_heads)")
        self.assertEqual(obj["schema_provenance"], "transformers:4.57.1:smollm3:meta-constructor:2026-10-21")
        binding = obj["binding"]
        legacy_view = dict(binding)
        legacy_view["work_units"] -= 7 * config["num_hidden_layers"] * 128
        old.DecoderProjections.check(self, legacy_view, config, expected, d, d, provenance)
        count = len(expected["bindings"])
        files = expected["files"]
        work = (16 * config["num_hidden_layers"] + 3) * 128 + count * 8 + len(files) + len(provenance.encode()) * len(files)
        for path, metadata in expected["metadata"].items():
            work += len(path.encode()) + len(metadata)
            work += sum(len(k.encode()) + len(v.encode()) for k, v in metadata.items())
        work += sum(len(x["original_name"].encode()) + len(x["source_path"].encode()) for x in expected["bindings"].values())
        self.assertEqual(binding["work_units"], work)
        self.assertEqual(obj["work_units"], work + 128 + 8 * config["num_hidden_layers"])

    def test_01_header_geometry_bias_grid(self):
        for hidden, heads, kv, d, explicit in [(8,4,2,2,False),(8,4,2,6,True),(10,4,2,2,False),(10,3,1,3,False),(1,1,1,1,False),(8,4,2,3,True)]:
            for attention, mlp in itertools.product((False,True),repeat=2):
                config, roles = declared(hidden=hidden,heads=heads,kv=kv,dimension=d,explicit=explicit,attention=attention,mlp=mlp)
                root, expected = self.collection(config,roles,shards=3,dtypes=("BF16","F16","F32"))
                self.check(self.accept(self.invoke(root)),config,expected,d)

    def test_02_formats_defaults_ties_raw(self):
        for dtype, attention, mlp, tie in itertools.product(("BF16","F16","F32"),(False,True),(False,True),(False,True,None)):
            config,roles=declared(layers=1,attention=attention,mlp=mlp,tie=tie,output=tie is False)
            config.update(hidden_act="gelu",rope_scaling={"rope_type":"linear","factor":2},pretraining_tp=2)
            if tie is True:
                del config["tie_word_embeddings"]
            root,expected=self.collection(config,roles,dtypes=(dtype,))
            obj=self.accept(self.invoke(root,mode="unindexed"))
            self.check(obj,config,expected,2)
            notes=obj["binding"]["architecture"]["unresolved"]
            self.assertIn("activation_operation_lowering",notes)
            self.assertIn("rotary_scaling_operation_lowering",notes)
            self.assertIn("pretraining_tp_semantics",notes)
            self.assertEqual(obj["binding"]["architecture"]["activation"],"gelu")

    def test_03_source_role_shape_and_flag_refusals(self):
        config,roles=declared(attention=True,mlp=True,explicit=True,dimension=3)
        biases=[k for k in roles if k.endswith(".bias")]
        for name in biases:
            for fault in ("missing","wrong_size","wrong_rank"):
                changed=copy.deepcopy(roles)
                if fault=="missing": del changed[name]
                elif fault=="wrong_size": changed[name]=(changed[name][0],[changed[name][1][0]+1])
                else: changed[name]=(changed[name][0],[1,changed[name][1][0]])
                root,_=self.collection(config,changed)
                self.refuse(self.invoke(root,mode="unindexed"))
        for attention,mlp in [(False,True),(True,False),(False,False)]:
            changed=dict(config,attention_bias=attention,mlp_bias=mlp)
            root,_=self.collection(changed,roles)
            self.refuse(self.invoke(root,mode="unindexed"))
        for name in [k for k in roles if k.endswith(".weight") and "self_attn" in k]:
            changed=copy.deepcopy(roles); canonical,shape=changed[name]; changed[name]=(canonical,[shape[0]+1,shape[1]])
            root,_=self.collection(config,changed)
            self.refuse(self.invoke(root,mode="unindexed"))
        changed=copy.deepcopy(roles);changed["model.layers.0.unqualified.bias"]=("unknown",[3])
        root,_=self.collection(config,changed); self.refuse(self.invoke(root,mode="unindexed"))
        # Legacy metadata intent can describe independent source widths; new qualified
        # declaration must not silently replace them or certify that architecture.
        config,roles=old.declared(key=3,value=5)
        root,_=self.collection(config,roles)
        self.refuse(self.invoke(root,mode="unindexed"))
        self.accept(self.child([CONFIG.legacy,"unindexed",root,"source-0.weights","config.json",8,10000,64,10000000,10000000,"legacy geometric intent"]))

    def test_04_exact_work_and_bad_config_bounds(self):
        config,roles=declared(attention=True,mlp=True)
        root,expected=self.collection(config,roles)
        obj=self.accept(self.invoke(root,mode="unindexed")); work=obj["work_units"]
        self.check(self.accept(self.invoke(root,mode="unindexed",bounds=(8,10000,64,10000000,work))),config,expected,2)
        for bound in (0,1,work-1): self.refuse(self.invoke(root,mode="unindexed",bounds=(8,10000,64,10000000,bound)))
        for dim in (None,True,False,0,-1,1.5,"3",{},[],9223372036854775808):
            changed=dict(config,head_dim=dim); r,_=self.collection(changed,roles);self.refuse(self.invoke(r,mode="unindexed"))
        for key in ("hidden_size","num_attention_heads","num_key_value_heads"):
            for value in (0,-1,9223372036854775807):
                changed=dict(config); changed[key]=value;r,_=self.collection(changed,roles);self.refuse(self.invoke(r,mode="unindexed"))
        for key in ("attention_bias","mlp_bias"):
            for value in (None,0,"true",[]):
                changed=dict(config);changed[key]=value;r,_=self.collection(changed,roles);self.refuse(self.invoke(r,mode="unindexed"))
        # Explicit head mismatch is checked against actual source Q/K/V, not accepted
        # solely because the source word parses or memory might fit.
        r,expected=self.collection(dict(config,head_dim=4),roles)
        self.refuse(self.invoke(r,mode="unindexed",trace="late-head-refusal.strace"))
        trace=(self.evidence/"late-head-refusal.strace").read_text()
        for path in expected["raw_files"]:
            opens=sum(("openat(" in line or "openat2(" in line) and json.dumps(path.name) in line for line in trace.splitlines())
            closes=sum("close(" in line and "<"+str(path)+">" in line for line in trace.splitlines())
            self.assertEqual(opens,closes)
            self.assertGreater(closes,0)
        for forbidden in ("/dev/h1x-","libcuda","libhailort","libggml","ioctl("):
            self.assertNotIn(forbidden,trace)

    def test_05_ownership_mutations_recovery(self):
        config,roles=declared(attention=True,mlp=True)
        root,_=self.collection(config,roles)
        for mode in ("valid","ownership","cycles"):
            self.accept(self.child([self.api,root,"source-0.weights","config.json",mode]))
        modes="head_dim head_origin schema_provenance schema_work key_dim value_dim output notes work owned_policy external_policy source_architecture source_provenance source_extent source_offset source_weight_bytes source_alias source_binding source_kind source_tag source_shape source_name source_path source_policy original_name original_shape original_offset original_extent original_metadata original_metadata_count architecture layer_mask bias_binding bias_shape bias_flag old_validator input_work input_layer_count input_format".split()
        for mode in modes: self.refuse(self.child([self.api,root,"source-0.weights","config.json",mode]))

    def test_06_complete_legacy_output_comparison(self):
        for key,value in [(2,2),(3,5),(6,1)]:
            for shards in (1,3):
                config,roles=old.declared(key=key,value=value)
                root,_=self.collection(config,roles,shards=shards)
                modes=("indexed","unindexed") if shards==1 else ("indexed",)
                for mode in modes:
                    label="index.json" if mode=="indexed" else "source-0.weights"
                    args=[mode,root,label,"config.json",8,10000,64,10000000,10000000,"frozen full output"]
                    before=self.child([CONFIG.frozen,*args]);after=self.child([CONFIG.legacy,*args])
                    self.assertEqual(before.returncode,0,before.stderr);self.assertEqual(after.returncode,0,after.stderr)
                    self.assertEqual(before.stdout,after.stdout)
                    self.assertEqual(before.stderr,after.stderr)

    def test_07_real_remote_headers_and_readonly_trace(self):
        obj=self.accept(self.child([self.api,"remote",CONFIG.public_config,CONFIG.header0,4966315264,CONFIG.header1,1183919744],"real-metadata.strace"))
        self.assertTrue(obj["remote_metadata_only"]);self.assertFalse(obj["local_model_admitted"])
        schema=obj["schema"];self.assertEqual(schema["head_dim"],128)
        self.assertEqual(len(schema["binding"]["source"]["bindings"]),326)
        trace=(self.evidence/"real-metadata.strace").read_text()
        self.assertNotIn("/dev/h1x",trace);self.assertNotIn("/dev/hailo",trace)
        config,roles=declared(attention=True,mlp=True)
        root,expected=self.collection(config,roles)
        obj=self.accept(self.invoke(root,mode="unindexed",trace="owned-readonly.strace"))
        self.check(obj,config,expected,2)
        for path,raw in expected["raw_files"].items(): self.assertEqual(path.read_bytes(),raw)
        trace=(self.evidence/"owned-readonly.strace").read_text()
        for path,raw in expected["raw_files"].items():
            lines=[x for x in trace.splitlines() if str(path) in x]
            self.assertTrue(any("O_RDONLY" in x for x in lines))
            opens=sum(("openat(" in x or "openat2(" in x) and json.dumps(path.name) in x for x in trace.splitlines())
            closes=sum("close(" in x and "<"+str(path)+">" in x for x in lines)
            self.assertEqual(opens,closes)
            self.assertGreater(closes,0)
            reads=[x for x in lines if "pread64(" in x]
            self.assertEqual(len(reads),2)
            self.assertTrue(any(", 8, 0)" in x for x in reads))
            self.assertFalse(any("mmap(" in x for x in lines))
        self.assertNotIn("/dev/h1x",trace)


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    for key in ("binary","api","legacy","frozen","public-config","header0","header1","strace","evidence"):parser.add_argument("--"+key,required=True)
    CONFIG=parser.parse_args();old.CONFIG=CONFIG
    unittest.main(argv=[__file__],verbosity=2)
