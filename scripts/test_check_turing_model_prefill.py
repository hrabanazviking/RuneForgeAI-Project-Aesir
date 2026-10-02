"""Whole-model evidence rejects incomplete identity, quality and timing gates."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import check_turing_model_prefill as check
import check_llama3_logits as logits


def fixture(delta=0):
    rows = ["[CUDA] synthetic api=cuda cpu_offload=0", "META,1,4,1536,32,f16,8"]
    for index in range(4):
        rows.append(f"CASE,{index},2")
        rows.extend([f"INPUT,{index},0,1", f"INPUT,{index},1,2"])
        rows.extend(f"LOGIT,{index},{token},{token},{token + delta}" for token in range(4))
        for sample in range(4):
            for step in range(2):
                mode = (sample + step) % 2
                rows.append(f"TIME,{index},{mode},{sample},{.01 if mode == 0 else .005},2,0")
        rows.append(f"GUARD,{index},1088,0")
    rows.append("COMPLETE,matrix_model,4,16,32,8")
    return "\n".join(rows) + "\n"


class Contracts(unittest.TestCase):
    def parse(self, text):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "probe"; path.write_text(text)
            with patch.object(check, "VOCABULARY", 4), patch.object(logits, "VOCABULARY", 4):
                return check.parse(path)

    def test_complete_collection_is_not_quality_certificate(self):
        data = self.parse(fixture())
        self.assertEqual(len(data["cases"]), 4)
        self.assertTrue(all(c["native_comparison"]["passed"] for c in data["cases"]))
        self.assertFalse(check.summarize(data)["passed"])

    def test_failure_keeps_every_vector_and_withholds_ratios(self):
        data = self.parse(fixture(.125)); report = check.summarize(data)
        report["independent_reference"] = dict(passed=True)
        check.score(report)
        self.assertFalse(report["passed"]); self.assertFalse(report["speed_scored"])
        self.assertTrue(all(c["prefill_speed_ratio"] is None for c in report["cases"]))

    def test_score_only_after_independent_pass_excludes_warmup(self):
        report = check.summarize(self.parse(fixture()))
        report["independent_reference"] = dict(passed=False)
        check.score(report); self.assertFalse(report["speed_scored"])
        report["independent_reference"] = dict(passed=True)
        for c in report["cases"]:
            for sample in c["timings"]:
                if sample["sample"] == 0: sample["seconds"] = 1000
        check.score(report)
        self.assertTrue(report["passed"])
        self.assertTrue(all(c["prefill_speed_ratio"] == 2 for c in report["cases"]))

    def test_identity_context_token_and_complete_counts(self):
        for old, new in (("META,1,4,1536,32,f16,8", "META,1,4,4096,32,f16,8"),
                         ("CASE,0,2", "CASE,0,1537"),
                         ("INPUT,0,0,1", "INPUT,0,0,4"),
                         ("INPUT,0,1,2", "INPUT,0,0,2"),
                         ("COMPLETE,matrix_model,4,16,32,8", "COMPLETE,matrix_model,4,15,32,8")):
            with self.assertRaises((ValueError, StopIteration)):
                self.parse(fixture().replace(old, new))

    def test_full_logit_order_and_finite_exact_f32(self):
        for old, new in (("LOGIT,0,0,0,0", "LOGIT,0,0,0,nan"),
                         ("LOGIT,0,0,0,0", "LOGIT,0,0,0,1.1"),
                         ("LOGIT,0,1,1,1", "LOGIT,0,0,1,1"),
                         ("LOGIT,0,0,0,0\n", "")):
            with self.assertRaises((ValueError, StopIteration)):
                self.parse(fixture().replace(old, new))

    def test_actual_sample_order_positions_repeat_and_guards(self):
        for old, new in (("TIME,0,0,0,0.01,2,0", "TIME,0,1,0,0.01,2,0"),
                         ("TIME,0,0,0,0.01,2,0", "TIME,0,0,0,-1,2,0"),
                         ("TIME,0,0,0,0.01,2,0", "TIME,0,0,0,0.01,3,0"),
                         ("TIME,0,0,0,0.01,2,0", "TIME,0,0,0,0.01,2,1"),
                         ("GUARD,0,1088,0", "GUARD,0,1088,1")):
            with self.assertRaises(ValueError):
                self.parse(fixture().replace(old, new))

    def test_incomplete_and_trailing_evidence(self):
        for text in (fixture().replace("COMPLETE,matrix_model,4,16,32,8\n", ""), fixture() + "extra\n"):
            with self.assertRaises((ValueError, StopIteration)):
                self.parse(text)

    def test_reference_derivation_identity(self):
        import json
        value = dict(model_sha256="source", reference_expansion=dict(derived_sha256="derived", exit_code=0, derived_bytes=100, converter_sha256="a" * 64))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "proof"; path.write_text(json.dumps(value))
            self.assertEqual(check.provenance(path, "source", "derived")["derived_bytes"], 100)
            for source, derived in (("wrong", "derived"), ("source", "wrong")):
                with self.assertRaises(ValueError): check.provenance(path, source, derived)
            value["reference_expansion"]["exit_code"] = 1; path.write_text(json.dumps(value))
            with self.assertRaises(ValueError): check.provenance(path, "source", "derived")


if __name__ == "__main__":
    unittest.main()
