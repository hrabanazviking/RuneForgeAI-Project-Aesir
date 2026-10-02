"""Portable adversarial contracts; synthetic streams are never GPU evidence."""
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

import check_turing_decode_quality as check
import check_llama3_logits as logits

INPUT_HASH = hashlib.sha256(struct.pack("<II", 1, 2)).hexdigest()


def fixture(delta=0):
    value = lambda v: repr(struct.unpack("<f", struct.pack("<f", v))[0])
    rows = ["[CUDA] native Mojo synthetic api=cuda cpu_offload=0", "META,1,turing_decode,1536,4,4,2",
            f"POLICY,0,0.0,40,{value(.95)},0.0,1.0,64,42",
            f"POLICY,1,{value(.7)},40,{value(.9)},{value(.05)},{value(1.1)},64,1234"]
    for index in range(4):
        choice = index % 2; cap = 16 if choice else 32
        rows.extend([f"CASE,{index},2,{choice},{cap}", f"INPUT,{index},0,1", f"INPUT,{index},1,2"])
        for step in range(2):
            token = 2 + step; pos = 2 + step; draws = step + 1 if choice else 0
            rows.append(f"STEP,{index},{step},{token},{token},{pos},{pos},{pos},{pos},{draws},{draws},0,0")
            rows.append(f"CAUSAL,{index},{step},{pos},0")
            for ordinal, native in enumerate([0, 1, 5, 0] if step == 0 else [0, 1, 0, 5]):
                rows.append(f"LOGIT,{index},{step},{ordinal},{native},{native + delta}")
        rows.append(f"END,{index},2,eos")
        for step in range(2):
            token = 2 + step; pos = 2 + step; draws = step + 1 if choice else 0
            rows.append(f"REPLAY,{index},{step},{token},{token},{pos},{pos},{pos},{pos},{draws},{draws},0,0")
            rows.append(f"CAUSAL,{index},{step},{pos},0")
        rows.extend([f"REPLAY_END,{index},2,eos", f"GUARD,{index},1088,0"])
    rows.append("COMPLETE,turing_decode,4,8,32,4352,2")
    return "\n".join(rows) + "\n"


class Oracle:
    identity = {"synthetic_test_only": True}
    def __init__(self): self.begins = []; self.advances = []; self.closed = False
    def begin(self, ids): self.begins.append(ids)
    def expected(self, position): return [0, 1, 5, 0] if position == 2 else [0, 1, 0, 5]
    def advance(self, token): self.advances.append(token)
    def close(self): self.closed = True


class Contracts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "capture"; self.path.write_text(fixture())
        for obj, name, value in ((check, "VOCABULARY", 4), (logits, "VOCABULARY", 4),
                                 (check, "INPUT_COUNTS", (2, 2, 2, 2)), (check, "INPUT_HASHES", (INPUT_HASH, INPUT_HASH)),
                                 (check, "EOS", (3,))):
            p = patch.object(obj, name, value); p.start(); self.addCleanup(p.stop)

    def parse(self, text=None, oracle=None):
        if text is not None: self.path.write_text(text)
        return check.parse(self.path, oracle)

    def test_stream_complete_requires_independent_and_exact_causal_calls(self):
        self.assertFalse(self.parse()["passed"])
        oracle = Oracle()
        with patch.object(Path, "read_text", side_effect=AssertionError("whole-file read forbidden")):
            report = self.parse(oracle=oracle)
        self.assertTrue(report["passed"]); self.assertFalse(report["speed_scored"])
        self.assertEqual(oracle.begins, [[1, 2]] * 4); self.assertEqual(oracle.advances, [2] * 4)
        self.assertEqual(report["full_model_values_per_mode"], 32)

    def test_every_numerical_failure_retained_with_no_speed_score(self):
        report = self.parse(fixture(.125), Oracle())
        self.assertTrue(report["collection_complete"]); self.assertFalse(report["passed"])
        frames = [f for c in report["cases"] for f in c["frames"]]
        self.assertEqual(len(frames), 8)
        self.assertTrue(all(not f["native_comparison"]["passed"] and not f["independent"]["matrix"]["passed"] for f in frames))
        self.assertFalse(report["speed_scored"])

    def test_sample_and_replay_failures_retained(self):
        for old, new in (("STEP,0,0,2,2", "STEP,0,0,2,1"),
                         ("REPLAY,0,0,2,2", "REPLAY,0,0,1,2"),
                         ("REPLAY,0,0,2,2,2,2,2,2,0,0,0,0", "REPLAY,0,0,2,2,2,2,2,2,0,0,1,0")):
            report = self.parse(fixture().replace(old, new), Oracle())
            self.assertFalse(report["passed"]); self.assertTrue(report["collection_complete"])
            self.assertEqual(report["evaluated_frames"], 8)

    def test_metadata_policy_input_and_total_identity(self):
        for old, new in (("META,1,turing_decode,1536,4,4,2", "META,1,turing_decode,4096,4,4,2"),
                         ("POLICY,1,", "POLICY,2,"), (",64,1234", ",64,1235"),
                         ("INPUT,0,0,1", "INPUT,0,0,0"), ("INPUT,0,1,2", "INPUT,0,0,2"),
                         ("COMPLETE,turing_decode,4,8,32,4352,2", "COMPLETE,turing_decode,4,8,31,4352,2")):
            with self.assertRaises(ValueError): self.parse(fixture().replace(old, new))

    def test_state_history_draw_range_and_order(self):
        old = "STEP,1,0,2,2,2,2,2,2,1,1,0,0"
        for new in ("STEP,1,1,2,2,2,2,2,2,1,1,0,0", "STEP,1,0,4,2,2,2,2,2,1,1,0,0",
                    "STEP,1,0,2,2,2,2,3,2,1,1,0,0", "STEP,1,0,2,2,2,2,2,2,0,1,0,0",
                    "STEP,1,0,2,2,2,2,2,2,1,1,1,0", "STEP,1,0,02,2,2,2,2,2,1,1,0,0"):
            with self.assertRaises(ValueError): self.parse(fixture().replace(old, new))
        with patch.object(check, "VOCABULARY", 128256), patch.object(check, "EOS", (128001, 128009)):
            with self.assertRaises(ValueError): check.state(["STEP", "1", "0", "128002", "2", "2", "2", "2", "2", "1", "1", "0", "0"], "STEP", 1, 0, 2, 1)
        with self.assertRaises(ValueError): self.parse(fixture().replace("CAUSAL,0,0,2,0", "CAUSAL,0,0,2,1"))

    def test_full_vectors_finite_exact_f32_and_order(self):
        for old, new in (("LOGIT,0,0,0,0,0", "LOGIT,0,0,0,nan,0"),
                         ("LOGIT,0,0,0,0,0", "LOGIT,0,0,0,1.1,0"),
                         ("LOGIT,0,0,1,1,1", "LOGIT,0,0,0,1,1"),
                         ("LOGIT,0,0,0,0,0\n", "")):
            with self.assertRaises(ValueError): self.parse(fixture().replace(old, new))

    def test_eos_length_cap_replay_guard_and_trailing(self):
        for old, new in (("STEP,0,0,2,2", "STEP,0,0,3,3"), ("END,0,2,eos", "END,0,2,length"),
                         ("REPLAY_END,0,2,eos", "REPLAY_END,0,1,eos"), ("GUARD,0,1088,0", "GUARD,0,1088,1"),
                         ("COMPLETE,turing_decode,4,8,32,4352,2\n", "")):
            with self.assertRaises(ValueError): self.parse(fixture().replace(old, new))
        with self.assertRaises(ValueError): self.parse(fixture() + "late\n")
        with self.assertRaises(ValueError): self.parse(fixture().rstrip("\n"))
        with patch.object(check, "MAX_FRAMES", 7):
            with self.assertRaises(ValueError): self.parse(fixture())

    def test_regular_nofollow_byte_line_field_and_growth_bounds(self):
        target = self.path.with_name("link"); target.symlink_to(self.path)
        with self.assertRaises(OSError): check.parse(target)
        fifo = self.path.with_name("fifo"); os.mkfifo(fifo)
        with self.assertRaises(ValueError): check.parse(fifo)
        with patch.object(check, "MAX_BYTES", 8):
            with self.assertRaises(ValueError): self.parse()
        with self.assertRaises(ValueError): self.parse("x" * 1025 + "\n")
        with self.assertRaises(ValueError): self.parse("x" * 257 + "\n")
        self.path.write_text(fixture()); records = check.Records(self.path)
        try:
            while records.next(optional=True) is not None: pass
            with self.path.open("a") as output: output.write("growth\n")
            with self.assertRaises(ValueError): records.finish()
        finally: records.close()

    def test_partial_failure_report_and_exclusive_output(self):
        model = self.path.with_name("model"); model.write_bytes(b"m")
        reference = self.path.with_name("reference"); reference.write_bytes(b"r")
        output = self.path.with_name("report")
        args = ["check", str(self.path), "--model", str(model), "--model-sha256", "a" * 64,
                "--reference-model", str(reference), "--reference-sha256", "b" * 64,
                "--reference-provenance", str(self.path.with_name("proof")), "--output", str(output)]
        oracle = Oracle()
        with patch.object(sys, "argv", args), patch.object(check, "digest", side_effect=["a" * 64, "b" * 64, "c" * 64]), \
             patch.object(check, "provenance", return_value={"derived_bytes": 1}), patch.object(check, "CPUReference", return_value=oracle):
            self.assertEqual(check.main(), 1)
        report = json.loads(output.read_text())
        self.assertFalse(report["passed"]); self.assertTrue(report["collection_complete"])
        self.assertEqual(report["evaluated_frames"], 8); self.assertTrue(oracle.closed)
        with patch.object(sys, "argv", args):
            with self.assertRaises(FileExistsError): check.main()
        output2 = self.path.with_name("cleanup-report"); args[-1] = str(output2)
        with patch.object(sys, "argv", args), patch.object(check, "digest", side_effect=["a" * 64, "b" * 64] * 2), \
             patch.object(check, "provenance", return_value={"derived_bytes": 1}), patch.object(check, "CPUReference", return_value=Oracle()), \
             patch.object(Oracle, "close", side_effect=RuntimeError("controlled cleanup failure")):
            self.assertEqual(check.main(), 1)
        cleanup = json.loads(output2.read_text())
        self.assertTrue(cleanup["collection_complete"]); self.assertFalse(cleanup["passed"])
        self.assertIn("cleanup failed", cleanup["error"])
        output3 = self.path.with_name("interrupted-report"); args[-1] = str(output3)
        interrupted = Oracle()
        with patch.object(sys, "argv", args), patch.object(check, "digest", side_effect=["a" * 64, "b" * 64]), \
             patch.object(check, "provenance", return_value={"derived_bytes": 1}), patch.object(check, "CPUReference", return_value=interrupted), \
             patch.object(Oracle, "expected", side_effect=KeyboardInterrupt()):
            self.assertEqual(check.main(), 1)
        partial = json.loads(output3.read_text())
        self.assertFalse(partial["collection_complete"]); self.assertFalse(partial["passed"])
        self.assertTrue(interrupted.closed); self.assertIn("KeyboardInterrupt", partial["error"])


if __name__ == "__main__": unittest.main()
