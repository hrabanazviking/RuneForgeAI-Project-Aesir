"""Fail-closed synthetic CSV and numerical-gate tests; no physical inference claim."""
from array import array
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import check_llama3_logits as check


def fixture() -> str:
    records = ["[CUDA] native Mojo fixture api=cuda cpu_offload=0\n",
               "META,1,128256,4096,4,f16\n", "TRAFFIC,2000,1000,100,20,10,4\n"]
    for size in check.COPY_BYTES:
        for i in range(10):
            records.append(f"BANDWIDTH,{size},{i},10,1.0,{size * 20 / 1e9}\n")
        records.append(f"BANDWIDTH_CHECK,{size // 4},0\n")
    for i in range(4):
        records.append(f"INPUT,{i},128000\n")
        records.append(f"INPUT,{i},25\n")
        records.extend(f"LOGIT,{i},{t},0.0\n" for t in range(check.VOCABULARY))
        for exported in (1, 0, 0, 0):
            records.append(f"CASE,{i},{exported},2,128,1.0,2.0,0.1,128,length\n")
    records.append("PASS,measurement,4,16,513024\n")
    return "".join(records)


class Contracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.valid = fixture()

    def parse(self, text):
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory) / "probe.csv"
            p.write_text(text)
            return check.parse_probe(p)

    def test_complete_schema_and_conditional_arithmetic(self):
        data = self.parse(self.valid)
        result = check.summarize_physical(data)
        self.assertEqual(len(result["bandwidth_samples"]), 20)
        self.assertEqual(result["cases"]["0"]["prefill_median_seconds"], 1)
        self.assertEqual(result["cases"]["0"]["first_visible_median_seconds"], 1.1)
        self.assertAlmostEqual(result["conditional_fixed_weight_floor_seconds"],
                               1130 / (max(check.COPY_BYTES) * 20))
        self.assertIn("conditional", result["limits"])

    def test_missing_trailing_and_duplicate_records_rejected(self):
        invalid = [self.valid.removesuffix("PASS,measurement,4,16,513024\n"),
                   self.valid + "unexpected\n",
                   self.valid.replace("LOGIT,0,0,0.0\n", "LOGIT,0,0,0.0\nLOGIT,0,0,0.0\n"),
                   self.valid.replace("LOGIT,0,0,0.0\n", ""),
                   self.valid.replace("META,1,128256,4096,4,f16\n", "META,1,128256,4096,4,f16\n" * 2),
                   self.valid.replace("INPUT,0,25", "INPUT,0,128256")]
        for text in invalid:
            with self.subTest(kind=text[:20]), self.assertRaises((ValueError, OverflowError)):
                self.parse(text)

    def test_nonfinite_values_and_malformed_shapes_rejected(self):
        for original, replacement in [("LOGIT,0,0,0.0", "LOGIT,0,0,nan"),
                                       ("CASE,0,1,2", "CASE,0,1,3"),
                                       ("CASE,0,1,2,128,1.0", "CASE,0,1,2,128,-1"),
                                       ("TRAFFIC,2000,1000", "TRAFFIC,20,1000"),
                                       ("BANDWIDTH_CHECK,8388611,0", "BANDWIDTH_CHECK,8388611,2")]:
            with self.subTest(replacement=replacement), self.assertRaises(ValueError):
                self.parse(self.valid.replace(original, replacement))

    def test_bandwidth_not_trusted_without_arithmetic(self):
        data = {"bandwidth": []}
        with self.assertRaises(ValueError):
            check.parse_bandwidth(["BANDWIDTH", str(check.COPY_BYTES[0]), "0", "10", "1", "100"], data)
        with self.assertRaises(ValueError):
            check.parse_bandwidth(["BANDWIDTH", str(check.COPY_BYTES[0]), "0", "10", "nan", "1"], data)

    def test_numerical_budget_detects_local_and_global_errors(self):
        expected = array("f", [0]) * check.VOCABULARY
        expected[7] = 1
        expected[9] = .998
        self.assertTrue(check.compare_case(expected, expected)["passed"])
        shifted = array("f", expected)
        shifted[11] = .1
        self.assertFalse(check.compare_case(shifted, expected)["passed"])
        shifted = array("f", (v + .01 for v in expected))
        self.assertFalse(check.compare_case(shifted, expected)["passed"])
        changed_choice = array("f", expected)
        changed_choice[7] = .999
        changed_choice[9] = 1.001
        result = check.compare_case(changed_choice, expected)
        self.assertFalse(result["passed"])
        self.assertLess(result["maximum_absolute_error"], check.MAX_ABSOLUTE_ERROR)

    def test_numerical_gate_rejects_shape_and_nonfinite(self):
        with self.assertRaises(ValueError):
            check.compare_case([1], [1])
        a = array("f", [0]) * check.VOCABULARY
        a[0] = float("inf")
        with self.assertRaises(ValueError):
            check.compare_case(a, a)

    def test_expansion_refuses_existing_or_original_destination(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "model"
            source.write_text("original")
            with patch.object(check.subprocess, "run") as run:
                with self.assertRaises(ValueError):
                    check.expand_reference(source, source, source, 1)
                run.assert_not_called()
            self.assertEqual(source.read_text(), "original")

    def test_expansion_refuses_dangling_destination(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "model"
            source.write_text("original")
            target = Path(directory) / "dangling"
            target.symlink_to(Path(directory) / "missing")
            with patch.object(check.subprocess, "run") as run:
                with self.assertRaises(ValueError):
                    check.expand_reference(source, target, source, 1)
                run.assert_not_called()
            self.assertTrue(target.is_symlink())

    def test_expansion_publication_is_exclusive_under_race(self):
        import subprocess
        for race in (False, True):
            with self.subTest(race=race), tempfile.TemporaryDirectory() as directory:
                source = Path(directory) / "model"
                source.write_bytes(b"original synthetic input")
                target = Path(directory) / "derived"
                converter = Path(directory) / "converter"
                converter.write_bytes(b"synthetic converter identity")
                def convert(args, **kwargs):
                    Path(args[3]).write_bytes(b"synthetic expansion bytes")
                    if race:
                        target.write_bytes(b"unrelated publication")
                    return subprocess.CompletedProcess(args, 0, "synthetic conversion", "")
                with patch.object(check.subprocess, "run", side_effect=convert):
                    if race:
                        with self.assertRaises(FileExistsError):
                            check.expand_reference(source, target, converter, 1)
                        self.assertEqual(target.read_bytes(), b"unrelated publication")
                    else:
                        record = check.expand_reference(source, target, converter, 1)
                        self.assertEqual(target.read_bytes(), b"synthetic expansion bytes")
                        self.assertEqual(record["exit_code"], 0)
                self.assertEqual(source.read_bytes(), b"original synthetic input")


if __name__ == "__main__":
    unittest.main()
