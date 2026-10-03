"""Adversarial explicit strategy3 decode/source contracts; no physical proof."""
from array import array
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import check_turing_decode_quality as check
import check_turing_down_source as source
import check_turing_model_prefill as model
import check_llama3_logits as logits
from test_check_turing_decode_quality import fixture as base, Oracle, INPUT_HASH
from test_check_turing_down_model import fixture as model_fixture, MARKER


def fixture():
    text = base().replace("META,1,turing_decode", MARKER + "\nMETA,1,turing_decode")
    for index in range(4):
        text = text.replace(f"INPUT,{index},1,2\n", f"INPUT,{index},1,2\nDOWN_ROWS128,{index},0\n")
        text = text.replace(f"REPLAY_END,{index}", f"REPLAY_DOWN_ROWS128,{index},0\nREPLAY_END,{index}")
    return text


class Contracts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name); self.csv = self.root / "capture"; self.csv.write_text(fixture())
        for obj, name, value in ((check, "VOCABULARY", 4), (model, "VOCABULARY", 4), (source, "VOCABULARY", 4),
            (logits, "VOCABULARY", 4), (check, "INPUT_COUNTS", (2, 2, 2, 2)),
            (check, "INPUT_HASHES", (INPUT_HASH, INPUT_HASH)), (check, "EOS", (3,))):
            item = patch.object(obj, name, value); item.start(); self.addCleanup(item.stop)

    def accepted(self):
        path = self.root / "model.csv"; text = model_fixture()
        for index in range(4):
            for token, value in enumerate((0, 1, 5, 0)):
                text = text.replace(f"LOGIT,{index},{token},{token},{token}", f"LOGIT,{index},{token},{value},{value}")
        path.write_text(text); data = model.parse(path); report = model.summarize(data)
        report.update(passed=True, speed_scored=True, model_sha256="a" * 64,
            independent_reference=dict(passed=True, requested_gpu_layers=0, context=4096, kv="f16", batch=128, threads=4,
                weight_mode="dequantized_f32", numpy="2.4.4", llama_cpp_python="0.3.23", library_sha256="b" * 64,
                cases=[dict(native=c["native_comparison"], matrix=c["native_comparison"]) for c in data["cases"]]),
            fixture_reference=dict(passed=True, attention_variant=2, csv_sha256="c" * 64, report_sha256="d" * 64,
                cases=[dict(input_ids_equal=True, native_f32_bytes_equal=True, matrix_f32_bytes_equal=True,
                    guarded_cache_identity_passed=True, passed=True) for _ in range(4)]))
        report_path = self.root / "model.json"; report_path.write_text(json.dumps(report))
        return path, report_path, report

    def parse(self, text=None, *, independent=True):
        if text is not None: self.csv.write_text(text)
        path, report_path, _ = self.accepted()
        data, proof = source.accepted_model(path, report_path, "a" * 64)
        report = check.initial_report(); report["accepted_down_model"] = proof
        return check.parse(self.csv, Oracle() if independent else None, report, down_source=data)

    def test_explicit_source_only_and_full_initial_bits(self):
        with self.assertRaises(ValueError): check.parse(self.csv, Oracle())
        report = self.parse(); self.assertTrue(report["passed"]); self.assertFalse(report["speed_scored"])
        self.assertTrue(report["model_source_passed"]); self.assertEqual(report["evaluated_frames"], 8)
        for owner in ("native", "matrix"):
            text = fixture().replace("LOGIT,0,0,0,0,0", "LOGIT,0,0,0,-0.0,0" if owner == "native" else "LOGIT,0,0,0,0,-0.0")
            report = self.parse(text); self.assertFalse(report["passed"]); self.assertTrue(report["collection_complete"])
            self.assertEqual(report["evaluated_frames"], 8); self.assertFalse(report["model_source_passed"])
        self.assertFalse(self.parse(fixture(), independent=False)["passed"])

    def test_initial_replay_counters_and_marker_must_match(self):
        for old, new in (("DOWN_ROWS128,0,0", "DOWN_ROWS128,0,1"),
            ("REPLAY_DOWN_ROWS128,0,0", "REPLAY_DOWN_ROWS128,0,1"),
            ("DOWN_ROWS128,0,0\n", ""), (MARKER, "ATTENTION,rope_cache_elementwise_grid,1,32")):
            with self.subTest(old=old), self.assertRaises(ValueError): self.parse(fixture().replace(old, new))

    def test_acceptance_boolean_cannot_hide_bad_numeric_owner_scope(self):
        path, report_path, original = self.accepted()
        for key, value in (("maximum_absolute_error", .051), ("rms_error", .0051),
            ("values", True), ("reference_argmax", 0), ("maximum_absolute_error", -1)):
            report = json.loads(json.dumps(original)); report["independent_reference"]["cases"][3]["matrix"][key] = value
            report_path.write_text(json.dumps(report))
            with self.subTest(key=key), self.assertRaises(ValueError): source.accepted_model(path, report_path, "a" * 64)
        for key, value in (("requested_gpu_layers", True), ("requested_gpu_layers", 1), ("numpy", "other"),
            ("kv", "q8"), ("weight_mode", "packed"), ("library_sha256", "invalid")):
            report = json.loads(json.dumps(original)); report["independent_reference"][key] = value
            report_path.write_text(json.dumps(report))
            with self.assertRaises(ValueError): source.accepted_model(path, report_path, "a" * 64)

    def test_source_scope_predecessor_counters_cache_ids_and_strict_json(self):
        path, report_path, original = self.accepted()
        for mutate in (lambda r: r.update(attention_variant=2), lambda r: r.update(activation_precision=False),
            lambda r: r.update(full_model_values_per_mode=15), lambda r: r["fixture_reference"].update(attention_variant=1),
            lambda r: r["fixture_reference"]["cases"][0].update(matrix_f32_bytes_equal=False),
            lambda r: r["cases"][3].update(down128_host_enqueues=1),
            lambda r: r["cases"][1].update(guarded_cache_sha256="e" * 64),
            lambda r: r["cases"][0].update(input_ids=[2, 1])):
            r = json.loads(json.dumps(original)); mutate(r); report_path.write_text(json.dumps(r))
            with self.assertRaises(ValueError): source.accepted_model(path, report_path, "a" * 64)
        for text in (json.dumps(original).replace('"schema": 1', '"schema": 1,"schema": 1'),
            json.dumps(original).replace('"schema": 1', '"schema": NaN')):
            report_path.write_text(text)
            with self.assertRaises(ValueError): source.accepted_model(path, report_path, "a" * 64)
        report_path.write_text(json.dumps(original))
        with self.assertRaises(ValueError): source.accepted_model(path, report_path, "wrong")

    def test_source_mutation_during_admission_refuses(self):
        path, report_path, _ = self.accepted()
        with patch.object(source, "digest", return_value="f" * 64), self.assertRaises(ValueError):
            source.accepted_model(path, report_path, "a" * 64)

    def main(self, suffix, *, mutate=None, interrupted=False):
        self.csv.write_text(fixture()); path, report_path, _ = self.accepted()
        data, proof = source.accepted_model(path, report_path, "a" * 64)
        model_path = self.root / "weights"; model_path.write_bytes(b"m")
        derived = self.root / "derived"; derived.write_bytes(b"r")
        receipt = self.root / "derivation"; receipt.write_bytes(b"d")
        output = self.root / suffix
        args = ["checker", str(self.csv), "--model", str(model_path), "--model-sha256", "a" * 64,
            "--reference-model", str(derived), "--reference-sha256", "b" * 64, "--reference-provenance", str(receipt),
            "--down-model-csv", str(path), "--down-model-report", str(report_path), "--output", str(output)]
        expected = {model_path: "a" * 64, derived: "b" * 64, receipt: "d" * 64,
            self.csv: hashlib.sha256(self.csv.read_bytes()).hexdigest(), path: proof["csv_sha256"], report_path: proof["report_sha256"]}
        counts = {}
        def digest(p):
            counts[p] = counts.get(p, 0) + 1
            if p == mutate and counts[p] >= (2 if p in (model_path, derived) else 1): return "e" * 64
            return expected[p]
        oracle = Oracle()
        def expected_vector(position):
            if interrupted: raise KeyboardInterrupt()
            return [0, 1, 5, 0] if position == 2 else [0, 1, 0, 5]
        with patch.object(sys, "argv", args), patch.object(check, "digest", side_effect=digest), \
            patch.object(check, "provenance", return_value=dict(derived_bytes=1, snapshot_sha256="d" * 64)), \
            patch.object(source, "accepted_model", return_value=(data, proof)), patch.object(check, "CPUReference", return_value=oracle), \
            patch.object(oracle, "expected", side_effect=expected_vector):
            status = check.main()
        return status, json.loads(output.read_text()), args, oracle, (model_path, derived, self.csv, receipt, path, report_path)

    def test_post_oracle_capture_derivation_source_and_weights_mutations(self):
        _, _, _, _, paths = self.main("paths")
        for index, path in enumerate(paths):
            status, report, _, oracle, _ = self.main("changed" + str(index), mutate=path)
            self.assertEqual(status, 1); self.assertFalse(report["passed"]); self.assertFalse(report["speed_scored"])
            self.assertTrue(report["collection_complete"]); self.assertEqual(report["evaluated_frames"], 8)
            self.assertTrue(oracle.closed); self.assertIn("changed during oracle", report["error"])

    def test_interrupt_closes_oracle_preserves_partial_exclusive_report(self):
        status, report, args, oracle, _ = self.main("interrupt", interrupted=True)
        self.assertEqual(status, 1); self.assertFalse(report["collection_complete"]); self.assertFalse(report["passed"])
        self.assertIn("KeyboardInterrupt", report["error"]); self.assertTrue(oracle.closed)
        saved = Path(args[-1]).read_bytes()
        with patch.object(sys, "argv", args), self.assertRaises(FileExistsError): check.main()
        self.assertEqual(Path(args[-1]).read_bytes(), saved)

    def test_cleanup_interruption_is_retained_and_failed(self):
        with patch.object(Oracle, "close", side_effect=KeyboardInterrupt()):
            status, report, _, _, _ = self.main("cleanup-interrupt")
        self.assertEqual(status, 1); self.assertFalse(report["passed"])
        self.assertTrue(report["collection_complete"]); self.assertFalse(report["speed_scored"])
        self.assertIn("Reference cleanup failed: KeyboardInterrupt", report["error"])

    def test_successful_report_is_exclusive_and_source_pair_required(self):
        status, report, args, oracle, _ = self.main("success")
        self.assertEqual(status, 0); self.assertTrue(report["passed"]); self.assertTrue(oracle.closed)
        with patch.object(sys, "argv", args), self.assertRaises(FileExistsError): check.main()
        del args[args.index("--down-model-report"):args.index("--down-model-report") + 2]
        with patch.object(sys, "argv", args), self.assertRaises(SystemExit) as error: check.main()
        self.assertEqual(error.exception.code, 2)


if __name__ == "__main__": unittest.main()
