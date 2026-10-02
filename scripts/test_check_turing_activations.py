"""Adversarial captured-activation evidence contracts; no GPU execution claim."""
import json
from pathlib import Path
import os
import tempfile
import unittest
from unittest.mock import patch

import check_turing_activations as check


def fixture(actual=1.0):
    rows = ["[CUDA] synthetic api=cuda cpu_offload=0", "META,1,turing_native_f32,64,32,12"]
    count = 0; values = 0
    for state in range(2):
        rows.append(f"STATE,{state},4,1,2,3,4")
        for identity in range(3):
            rows.append(f"SOURCE,{state},{identity},256,4")
            rows.extend(f"ACT,{state},{identity},{token},{column},1" for token in range(4) for column in range(256))
        for batch in (4, 32):
            for i, name in enumerate(check.TENSORS):
                rows.append(f"CASE,{count},{state},{name},12,256,1,{batch},32,{check.SOURCE_IDS[i]}")
                rows.extend(f"VALUE,{count},{token},0,1,{actual}" for token in range(batch))
                rows.append(f"GUARD,{count},{batch * 361},0")
                metric = check.errors([actual], [1])
                rows.append(f"METRIC,{count},{metric['maximum_scaled_error']},{metric['normalized_rms']}")
                values += batch; count += 1
    rows.append(f"COMPLETE,activation,28,{values},6144,12")
    return "\n".join(rows) + "\n"


class Contracts(unittest.TestCase):
    def parse(self, text):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "capture.csv"; path.write_text(text)
            return check.parse(path)

    def test_complete_collection_is_not_automatic_precision_pass(self):
        data = self.parse(fixture())
        self.assertEqual((len(data["cases"]), data["native_outputs"], data["source_values"]), (28, 504, 6144))
        self.assertTrue(all(c["native_error"]["passed"] for c in data["cases"]))
        self.assertFalse(check.summary(data)["passed"])

    def test_numerical_failure_retains_every_case(self):
        data = self.parse(fixture(1.125))
        self.assertEqual(len(data["cases"]), 28)
        self.assertTrue(all(not c["native_error"]["passed"] for c in data["cases"]))

    def test_explicit_split_identity_and_legacy_default(self):
        old = "META,1,turing_native_f32,64,32,12"
        self.assertEqual(self.parse(fixture())["activation_precision"], 0)
        for precision in (1, 2, 3, 4):
            new = f"META,1,turing_native_f32_split,64,32,{precision},12"
            self.assertEqual(self.parse(fixture().replace(old, new))["activation_precision"], precision)
        for precision in (0, 5, -1):
            with self.assertRaises(ValueError):
                self.parse(fixture().replace(old, f"META,1,turing_native_f32_split,64,32,{precision},12"))

    def test_wrong_mode_replay_and_source_identity(self):
        for old, new in (("META,1,turing_native_f32,64,32,12", "META,1,turing_native_f32,64,64,12"),
                         ("STATE,0,4,1,2,3,4", "STATE,0,5,1,2,3,4"),
                         ("STATE,0,4,1,2,3,4", "STATE,0,4,1,2,3,128256"),
                         ("SOURCE,0,0,256,4", "SOURCE,0,0,99999999,4"),
                         ("SOURCE,0,1,256,4", "SOURCE,0,2,256,4")):
            with self.assertRaises((ValueError, StopIteration)):
                self.parse(fixture().replace(old, new))

    def test_complete_order_counts_and_no_trailing_data(self):
        for text in (fixture().replace("ACT,0,0,0,0,1\n", ""),
                     fixture().replace("VALUE,0,0,0,1,1.0\n", ""),
                     fixture().replace("VALUE,0,0,0,1,1.0\n", "VALUE,0,0,0,1,1.0\n" * 2),
                     fixture().replace("COMPLETE,activation,28,504,6144,12", "COMPLETE,activation,28,505,6144,12"),
                     fixture() + "extra\n"):
            with self.assertRaises((ValueError, StopIteration)):
                self.parse(text)

    def test_input_output_finiteness_exact_f32_and_descriptor(self):
        for old, new in (("ACT,0,0,0,0,1", "ACT,0,0,0,0,nan"),
                         ("ACT,0,0,0,0,1", "ACT,0,0,0,0,1.1"),
                         ("VALUE,0,0,0,1,1.0", "VALUE,0,0,0,1,inf"),
                         ("blk.27.attn_q.weight,12,256,1,4,32,0", "blk.27.attn_q.weight,12,512,1,4,32,0"),
                         ("blk.27.attn_output.weight,12,256,1,4,32,1", "blk.27.attn_output.weight,12,256,1,4,32,0")):
            with self.assertRaises((ValueError, StopIteration)):
                self.parse(fixture().replace(old, new))

    def test_whole_guards_and_reported_metrics(self):
        for old, new in (("GUARD,0,1444,0", "GUARD,0,1,0"),
                         ("GUARD,0,1444,0", "GUARD,0,1444,1"),
                         ("METRIC,0,0,0.0", "METRIC,0,0.5,0.0")):
            with self.assertRaises(ValueError):
                self.parse(fixture().replace(old, new))

    def test_special_files_fail_without_waiting(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); fifo = root / "fifo"; os.mkfifo(fifo)
            real = root / "real"; real.write_text(fixture()); link = root / "link"; link.symlink_to(real)
            for path in (fifo, link, root):
                with self.assertRaises((OSError, ValueError)):
                    check.parse(path)

    def test_independent_failure_is_exclusive_complete_failed_report(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); capture = root / "capture"; capture.write_text(fixture())
            output = root / "report"; model = root / "model"
            oracle = [dict(outputs=1, candidate=dict(passed=False), reference=dict(passed=True))]
            args = ["checker", str(capture), "--model", str(model), "--model-sha256", "ok", "--output", str(output)]
            with patch("sys.argv", args), patch.object(check, "digest", return_value="ok"), patch.object(check, "independent", return_value=oracle):
                self.assertEqual(check.main(), 1)
                report = json.loads(output.read_text())
                self.assertFalse(report["passed"]); self.assertTrue(report["collection_complete"])
                self.assertEqual(len(report["cases"]), 28)
                with self.assertRaises(FileExistsError): check.main()

    def test_model_drift_after_oracle_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); capture = root / "capture"; capture.write_text(fixture())
            output = root / "report"
            args = ["checker", str(capture), "--model", str(root / "model"), "--model-sha256", "ok", "--output", str(output)]
            oracle = [dict(outputs=1, candidate=dict(passed=True), reference=dict(passed=True))]
            with patch("sys.argv", args), patch.object(check, "digest", side_effect=["ok", "changed"]), patch.object(check, "independent", return_value=oracle):
                self.assertEqual(check.main(), 1)
            self.assertIn("changed", json.loads(output.read_text())["error"])


if __name__ == "__main__":
    unittest.main()
