"""Synthetic matrix evidence rejection contracts; no GPU execution claim."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import check_packed_matrix as check


def fixture():
    records = ["[CUDA] synthetic api=cuda cpu_offload=0", "SYNTHETIC,144,0"]
    count = 0
    for batch in check.BATCHES:
        for name in check.NAMES:
            records.append(f"CASE,{count},{name},12,256,1,{batch},32")
            records.extend(f"VALUE,{count},{token},0,1,1" for token in range(batch))
            records.append(f"GUARD,{count},20,0")
            records.extend(f"TIME,{count},{mode},{sample},3,0.001" for mode in (0, 1) for sample in range(10))
            count += 1
    records.append("PASS,matrix,28,420,560")
    return "\n".join(records) + "\n"


class Contracts(unittest.TestCase):
    def parse(self, text):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "matrix.csv"
            path.write_text(text)
            return check.parse(path)

    def test_complete_synthetic_schema(self):
        self.assertEqual(len(self.parse(fixture())), 28)

    def test_incomplete_and_trailing(self):
        for text in (fixture().replace("PASS,matrix,28,420,560\n", ""), fixture() + "extra\n", fixture().replace("[CUDA] synthetic api=cuda cpu_offload=0\n", ""),
                     fixture().replace("VALUE,0,0,0,1,1\n", ""),
                     fixture().replace("TIME,0,0,0,3,0.001\n", "")):
            with self.assertRaises(ValueError):
                self.parse(text)

    def test_duplicate_values_timings_and_guards(self):
        for record in ("VALUE,0,0,0,1,1", "TIME,0,0,0,3,0.001", "GUARD,0,20,0"):
            with self.assertRaises(ValueError):
                self.parse(fixture().replace(record + "\n", (record + "\n") * 2))

    def test_wrong_identity_counts_and_nonfinite(self):
        for old, new in (("CASE,0,blk.0.attn_q.weight", "CASE,0,wrong"),
                         ("VALUE,0,0,0,1,1", "VALUE,0,0,0,1,nan"),
                         ("TIME,0,0,0,3,0.001", "TIME,0,0,0,3,-1"),
                         ("GUARD,0,20,0", "GUARD,0,20,1"),
                         ("PASS,matrix,28,420,560", "PASS,matrix,28,421,560")):
            with self.assertRaises(ValueError):
                self.parse(fixture().replace(old, new))

    def test_fixed_error_budgets(self):
        self.assertTrue(check.errors([1, 0], [1, 0])["passed"])
        self.assertFalse(check.errors([1.1, 0], [1, 0])["passed"])
        self.assertFalse(check.errors([1.001, .001], [1, 0])["passed"])
        with self.assertRaises(ValueError):
            check.errors([float("inf")], [1])

    def test_tile_identity_and_legacy_compatibility(self):
        legacy = self.parse(fixture())
        self.assertEqual(legacy[0]["tile"], (32, 32))
        new = fixture().replace("SYNTHETIC,144,0", "TILE,16,128\nSYNTHETIC,144,0")
        self.assertEqual(self.parse(new)[0]["tile"], (16, 128))
        for text in (new.replace("TILE,16,128", "TILE,7,128"),
                     new.replace("TILE,16,128", "TILE,16,128\nTILE,16,128"),
                     new.replace("TILE,16,128", "TILE,16,99999999")):
            with self.assertRaises(ValueError):
                self.parse(text)

    def test_versions_rejected_before_import(self):
        with patch.object(check.importlib.metadata, "version", return_value="unsupported"):
            with self.assertRaises(ValueError):
                check.independent([], Path("unused"))

    def test_turing_mode_and_mixed_layout_rejection(self):
        marker = "MODE,turing_mma_split_weight_f16_f32"
        new = fixture().replace("SYNTHETIC,144,0", marker+"\nSYNTHETIC,144,0")
        cases = self.parse(new)
        self.assertEqual(cases[0]["candidate"], marker.split(",")[1])
        self.assertEqual(cases[0]["tile"], (16, 8))
        for text in (new.replace(marker,"MODE,unknown"),
                     new.replace(marker,marker+"\n"+marker),
                     new.replace(marker,"TILE,32,32\n"+marker),
                     new.replace(marker,marker+"\nTILE,32,32"),
                     new.replace("SYNTHETIC,144,0","SYNTHETIC,144,0\n"+marker)):
            with self.assertRaises(ValueError):
                self.parse(text)

    def test_staged_turing_geometry_and_mode_rejection(self):
        for rows in (16,32,64):
            marker = f"MODE,turing_mma_staged_f16_f32,{rows}"
            text = fixture().replace("SYNTHETIC,144,0",marker+"\nSYNTHETIC,144,0")
            self.assertEqual(self.parse(text)[0]["tile"],(rows,8))
        for marker in ("MODE,turing_mma_staged_f16_f32,8", "MODE,turing_mma_staged_f16_f32,128",
                       "MODE,turing_mma_staged_f16_f32,99999999", "MODE,turing_mma_staged_f16_f32,32,extra",
                       "MODE,turing_mma_staged_f16_f32,16\nMODE,turing_mma_split_weight_f16_f32",
                       "MODE,turing_mma_staged_f16_f32,16\nTILE,32,32"):
            with self.assertRaises(ValueError):
                self.parse(fixture().replace("SYNTHETIC,144,0",marker+"\nSYNTHETIC,144,0"))


if __name__ == "__main__":
    unittest.main()
