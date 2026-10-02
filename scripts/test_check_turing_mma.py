"""Synthetic MMA record rejection tests; not actual GPU evidence."""
from pathlib import Path
import tempfile
import unittest
import os
import hashlib
import check_turing_mma as check


def fixture():
    rows = ["META,1,cuda,m16n8k8,f16,f32,9"]
    for index, (case, tiles, block, steps) in enumerate(check.CONFIGS):
        rows.append(f"CASE,{index},{case},{tiles},{block},{steps}")
        for tile in range(tiles):
            for row in range(16):
                for column in range(8):
                    rows.append(f"VALUE,{index},{tile},{row},{column},{check.expected(case,tile,row,column,steps)}")
        rows.append(f"GUARD,{index},50,0")
    rows.append("PASS,mma,108,50688,5400")
    return "\n".join(rows) + "\n"


class Contracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.complete = fixture()

    def parse(self, text):
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory) / "probe.csv"
            p.write_text(text)
            return check.parse(p)

    def test_complete_exact_equations(self):
        report = self.parse(self.complete)
        self.assertEqual(report["outputs"], 50688)
        self.assertEqual(report["csv_sha256"], hashlib.sha256(self.complete.encode()).hexdigest())

    def test_partial_or_trailing_records(self):
        for text in (self.complete.replace("PASS,mma,108,50688,5400\n", ""),
                     self.complete + "extra\n", self.complete.replace("VALUE,0,0,0,0,1.0\n", "")):
            with self.assertRaises(ValueError):
                self.parse(text)

    def test_duplicate_out_of_order(self):
        marker = "VALUE,0,0,0,0,1.0\n"
        with self.assertRaises(ValueError):
            self.parse(self.complete.replace(marker, marker * 2))

    def test_wrong_layout_value_and_nonfinite(self):
        for replacement in ("VALUE,0,0,0,0,0.0", "VALUE,0,0,0,0,nan", "VALUE,0,0,0,8,1.0"):
            with self.assertRaises(ValueError):
                self.parse(self.complete.replace("VALUE,0,0,0,0,1.0", replacement))

    def test_metadata_guards_and_counts(self):
        for old, new in (("cuda,m16n8k8", "cpu,m16n8k8"),
                         ("CASE,0,0,1,32,1", "CASE,0,0,1,33,1"),
                         ("GUARD,0,50,0", "GUARD,0,50,1"),
                         ("PASS,mma,108,50688,5400", "PASS,mma,108,50687,5400")):
            with self.assertRaises(ValueError):
                self.parse(self.complete.replace(old,new))

    def test_special_and_oversized_files(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            target = base / "regular.csv"
            target.write_text(self.complete)
            link = base / "linked.csv"
            link.symlink_to(target)
            fifo = base / "fifo.csv"
            os.mkfifo(fifo)
            large = base / "large.csv"
            with large.open("wb") as stream:
                stream.truncate(8 * 1024 * 1024 + 1)
            for path in (link,fifo,large):
                with self.assertRaises((OSError,ValueError)):
                    check.parse(path)


if __name__ == "__main__":
    unittest.main()
