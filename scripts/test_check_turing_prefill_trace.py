"""Portable reduced-vocabulary adversarial evidence contracts, not GPU proof."""
from array import array
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import check_turing_prefill_trace as check


class Contracts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.path = self.root / "probe.csv"
        self.golden = dict(input_ids=[1, 2], logits=array("f", [0., -0., 1.]), guarded_cache_sha256="a"*64)
        self.text = ("[CUDA] api=cuda cpu_offload=0\nTRACE,1,2,1,123,aesir.fixture.prefill\n"
                     "STATE,2,2,2,2\nINPUT,0,1\nINPUT,1,2\nLOGIT,0,0\nLOGIT,1,-0\nLOGIT,2,1\n"
                     "ENQUEUE,168,281\nCACHE,176160832,"+"a"*64+"\nGUARD,1088,0\nCOMPLETE,prefill_trace,3\n")
        self.path.write_text(self.text)
        self.vocabulary = patch.object(check, "VOCABULARY", 3); self.vocabulary.start(); self.addCleanup(self.vocabulary.stop)

    def test_complete_bits_cache_and_state(self):
        self.assertTrue(check.parse(self.path, self.golden, 1)["passed"])
        self.path.write_text(self.text.replace("LOGIT,1,-0", "LOGIT,1,0"))
        result = check.parse(self.path, self.golden, 1)
        self.assertFalse(result["passed"]); self.assertFalse(result["f32_bytes_equal"])

    def test_wrong_case_strategy_pid_ids_state_counts(self):
        for before, after in [("TRACE,1,2,1", "TRACE,1,1,1"), (",123,aesir", ",0,aesir"),
                              ("STATE,2,2,2,2", "STATE,2,1,2,2"), ("INPUT,1,2", "INPUT,1,1"),
                              ("ENQUEUE,168,281", "ENQUEUE,168,280")]:
            with self.subTest(before=before):
                self.path.write_text(self.text.replace(before, after))
                with self.assertRaises(ValueError): check.parse(self.path, self.golden, 1)
        self.path.write_text(self.text)
        with self.assertRaises(ValueError): check.parse(self.path, self.golden, 3)

    def test_duplicate_missing_trailing_nonfinite_and_guard(self):
        for text in [self.text.replace("LOGIT,2,1", "LOGIT,1,1"), self.text.replace("LOGIT,2,1\n", ""),
                     self.text+"trailing\n", self.text.replace("LOGIT,2,1", "LOGIT,2,nan"),
                     self.text.replace("GUARD,1088,0", "GUARD,1088,1"), self.text.rstrip("\n")]:
            with self.subTest(text=text[-60:]):
                self.path.write_text(text)
                with self.assertRaises((ValueError, StopIteration)): check.parse(self.path, self.golden, 1)

    def test_complete_numerical_failure(self):
        self.path.write_text(self.text.replace("a"*64, "b"*64))
        result = check.parse(self.path, self.golden, 1)
        self.assertFalse(result["passed"]); self.assertEqual(result["values"], 3)

    def test_special_file_input(self):
        import os
        path = self.root / "fifo"; os.mkfifo(path)
        with self.assertRaises(ValueError): check.parse(path, self.golden, 1)
        path = self.root / "link"; path.symlink_to(self.path)
        with self.assertRaises(OSError): check.parse(path, self.golden, 1)

    def arguments(self, output):
        return ["check", "--unprofiled", str(self.path), "--profiled", str(self.path),
                "--sqlite", str(self.path), "--binary", str(self.path), "--binary-sha256", "b"*64,
                "--model", str(self.path), "--model-sha256", "b"*64,
                "--reference-csv", str(self.path), "--reference-report", str(self.path),
                "--case", "1", "--output", str(output)]

    def test_interrupt_and_exclusive_report(self):
        output = self.root / "failure.json"
        with patch.object(sys, "argv", self.arguments(output)), patch.object(check, "digest", side_effect=KeyboardInterrupt):
            self.assertEqual(check.main(), 1)
        result = json.loads(output.read_text()); self.assertFalse(result["passed"])
        self.assertFalse(result["speed_scored"]); self.assertIn("KeyboardInterrupt", result["error"])
        before = output.read_bytes()
        with patch.object(sys, "argv", self.arguments(output)), self.assertRaises(FileExistsError): check.main()
        self.assertEqual(output.read_bytes(), before)

    def test_changed_artifact_preserves_complete_failure(self):
        output = self.root / "changed.json"
        parsed = check.parse(self.path, self.golden, 1)
        proof = dict(attention_variant=2, csv_sha256="b"*64, report_sha256="b"*64)
        trace = dict(gpu=dict(compute="7.5"))
        with patch.object(sys, "argv", self.arguments(output)), patch.object(check, "digest", side_effect=["b"*64]*3+["c"*64]), \
             patch.object(check, "reference", return_value=({}, proof)), \
             patch.object(check, "source_parse", return_value=dict(csv_sha256="b"*64,cases=[self.golden]*4)), \
             patch.object(check, "parse", return_value=parsed), patch.object(check, "analyze", return_value=trace):
            self.assertEqual(check.main(), 1)
        result = json.loads(output.read_text())
        self.assertFalse(result["passed"]); self.assertTrue(result["collection_complete"])
        self.assertIn("artifact changed", result["error"]); self.assertFalse(result["speed_scored"])

    def test_wrong_source_strategy_refuses_before_trace(self):
        output = self.root / "source.json"
        with patch.object(sys, "argv", self.arguments(output)), patch.object(check, "digest", return_value="b"*64), \
             patch.object(check, "reference", return_value=({}, dict(attention_variant=1))), \
             patch.object(check, "analyze") as trace:
            self.assertEqual(check.main(), 1)
            trace.assert_not_called()
        self.assertIn("accepted strategy2", json.loads(output.read_text())["error"])


if __name__ == "__main__": unittest.main()
