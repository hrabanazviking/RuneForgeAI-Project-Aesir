"""Portable variant/counter/cache/reference contracts; no physical GPU claim."""
import json
import hashlib
import struct
from contextlib import ExitStack
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import check_turing_model_prefill as check
import check_llama3_logits as logits
import check_turing_decode_quality as decode
import check_turing_checkpoint_replay as checkpoint
from test_check_turing_model_prefill import fixture
from test_check_turing_decode_quality import fixture as decode_fixture, Oracle as DecodeOracle
from test_check_turing_checkpoint_replay import fixture as checkpoint_fixture, source, Oracle as CheckpointOracle


def grid(variant):
    marker = f"ATTENTION,rope_cache_grid,{variant},32" if variant < 2 else "ATTENTION,rope_cache_elementwise_grid,1,32"
    text = fixture().replace("META,1,4,1536,32,f16,8", marker+"\nMETA,1,4,1536,32,f16,8")
    for index in range(4):
        text = text.replace(f"GUARD,{index},1088,0\n", f"GUARD,{index},1088,0\nENQUEUE,{index},168\nCACHE,{index},176160832," + "a" * 64 + "\n")
        if variant == 2: text = text.replace(f"ENQUEUE,{index},168\n", f"ENQUEUE,{index},168\nELEMENTWISE,{index},281\n")
    return text


class Contracts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "capture"
        for obj in (check, logits):
            p = patch.object(obj, "VOCABULARY", 4); p.start(); self.addCleanup(p.stop)

    def parse(self, text):
        self.path.write_text(text); return check.parse(self.path)

    def test_legacy_and_explicit_variants_require_reference_before_score(self):
        self.assertIsNone(self.parse(fixture())["attention_variant"])
        for variant in (0, 1):
            data = self.parse(grid(variant)); report = check.summarize(data)
            report["independent_reference"] = dict(passed=True)
            check.score(report); self.assertFalse(report["passed"])
            self.assertTrue(all(c["prefill_speed_ratio"] is None for c in report["cases"]))
            report["fixture_reference"] = dict(passed=True); check.score(report)
            self.assertTrue(report["passed"])
            report["fixture_reference"]["passed"] = False; check.score(report)
            self.assertFalse(report["passed"])
            self.assertTrue(all(c["prefill_speed_ratio"] is None for c in report["cases"]))

    def test_unknown_mixed_duplicate_late_metadata_counts_and_cache_reject(self):
        for old,new in (("rope_cache_grid,1,32", "rope_cache_grid,2,32"), ("rope_cache_grid,1,32", "rope_cache_grid,1,64"),
                        ("ATTENTION,rope_cache_grid,1,32", "ATTENTION,rope_cache_grid,1,32\nATTENTION,rope_cache_grid,1,32"),
                        ("META,1,4,1536,32,f16,8", "META,1,4,1536,32,f16,1,8"),
                        ("ENQUEUE,0,168", "ENQUEUE,0,169"), ("CACHE,0,176160832", "CACHE,0,176160830"),
                        ("CACHE,0,176160832," + "a" * 64, "CACHE,0,176160832," + "A" * 64)):
            with self.assertRaises(ValueError): self.parse(grid(1).replace(old,new))
        with self.assertRaises(ValueError): self.parse(fixture() + "ATTENTION,rope_cache_grid,1,32\n")

    def test_exact_public_plan_host_counts(self):
        self.assertEqual([check.rope_cache_calls(n,0) for n in (30,37,31,1070)], [2520,3108,2604,89880])
        self.assertEqual([check.rope_cache_calls(n,1) for n in (30,37,31,1070)], [756,252,840,3192])

    def test_reference_binds_csv_model_byte_identity_and_cache(self):
        reference = self.path.with_name("reference"); reference.write_text(grid(0))
        before = check.parse(reference); report = check.summarize(before)
        report.update(model_sha256="m", passed=True, independent_reference=dict(passed=True,cases=[dict(native=dict(passed=True),matrix=dict(passed=True)) for _ in range(4)]))
        proof = self.path.with_name("report"); proof.write_text(json.dumps(report))
        after = self.parse(grid(1))
        self.assertTrue(check.fixture_reference(after,reference,proof,"m")["passed"])
        changed = self.parse(grid(1).replace("a"*64,"b"*64))
        self.assertFalse(check.fixture_reference(changed,reference,proof,"m")["passed"])
        changed = self.parse(grid(1).replace("LOGIT,0,0,0,0", "LOGIT,0,0,-0.0,0"))
        self.assertFalse(check.fixture_reference(changed,reference,proof,"m")["passed"])
        with self.assertRaises(ValueError): check.fixture_reference(after,reference,proof,"wrong")
        report["csv_sha256"] = "b"*64; proof.write_text(json.dumps(report))
        with self.assertRaises(ValueError): check.fixture_reference(after,reference,proof,"m")
        report["csv_sha256"] = before["csv_sha256"]
        for key,value in (("attention_variant",1),("guards",4351),("full_model_values_per_mode",15)):
            changed = dict(report); changed[key] = value; proof.write_text(json.dumps(changed))
            with self.assertRaises(ValueError): check.fixture_reference(after,reference,proof,"m")
        proof.write_text(json.dumps(report).replace('"schema": 1','"schema": 1, "schema": 1'))
        with self.assertRaises(ValueError): check.fixture_reference(after,reference,proof,"m")

    def test_shared_metadata_gate_for_streamed_decode_and_checkpoint(self):
        for module in (decode, checkpoint):
            for value in (0,1): self.assertEqual(module.attention_variant(["ATTENTION","rope_cache_grid",str(value),"32"]),value)
            for value in (-1,2):
                with self.assertRaises(ValueError): module.attention_variant(["ATTENTION","rope_cache_grid",str(value),"32"])
        self.assertIsNone(check.attention_variant(["META"]))

    def test_elementwise_counts_and_reference_chain_require_accepted_strategy_one(self):
        self.assertEqual([check.elementwise_calls(n,2) for n in (30,37,31,1070)],[1261,421,1401,5321])
        self.assertEqual([check.elementwise_calls(n,1) for n in (30,37,31,1070)],[4201,5181,4341,149801])
        data = self.parse(grid(2)); reference = self.path.with_name("reference"); proof = self.path.with_name("report")
        for variant in (1,0):
            reference.write_text(grid(variant)); report = check.summarize(check.parse(reference))
            report.update(model_sha256="m",passed=True,independent_reference=dict(passed=True,cases=[dict(native=dict(passed=True),matrix=dict(passed=True)) for _ in range(4)]))
            proof.write_text(json.dumps(report))
            if variant == 1: self.assertTrue(check.fixture_reference(data,reference,proof,"m")["passed"])
            else:
                with self.assertRaises(ValueError): check.fixture_reference(data,reference,proof,"m")
        for old,new in (("ELEMENTWISE,0,281","ELEMENTWISE,0,282"),("ELEMENTWISE,0,281\n",""),("rope_cache_elementwise_grid,1,32","rope_cache_elementwise_grid,2,32"),("rope_cache_elementwise_grid,1,32","rope_cache_grid,2,32")):
            with self.assertRaises(ValueError): self.parse(grid(2).replace(old,new))

    def test_complete_streamed_parsers_bind_variant_and_refuse_duplicate_or_late(self):
        identity = hashlib.sha256(struct.pack("<II",1,2)).hexdigest()
        for module,fixture_fn,oracle in ((decode,decode_fixture,DecodeOracle),(checkpoint,checkpoint_fixture,CheckpointOracle)):
            with ExitStack() as stack:
                for name,value in (("VOCABULARY",4),("INPUT_HASHES",(identity,identity)),("EOS",(3,))):
                    stack.enter_context(patch.object(module,name,value))
                if module is decode: stack.enter_context(patch.object(module,"INPUT_COUNTS",(2,2,2,2)))
                else:
                    stack.enter_context(patch.object(module,"PREFIX",2)); stack.enter_context(patch.object(module,"CHECKPOINT",10))
                def parse(text):
                    self.path.write_text(text)
                    return module.parse(self.path,oracle()) if module is decode else module.parse(self.path,dict(sha256="c"*64,csv_sha256="f"*64,cases=source()["cases"][:2]),oracle())
                for flag in (0,1,2):
                    marker = f"ATTENTION,rope_cache_grid,{flag},32\n" if flag < 2 else "ATTENTION,rope_cache_elementwise_grid,1,32\n"
                    text = fixture_fn(); head,body = text.split("\n",1)
                    report = parse(head+"\n"+marker+body)
                    self.assertTrue(report["passed"]); self.assertEqual(report["attention_variant"],flag)
                    for invalid in (head+"\n"+marker+marker+body,text+marker,head+"\n"+marker.replace(",32",",64")+body):
                        with self.assertRaises(ValueError): parse(invalid)


if __name__ == "__main__": unittest.main()
