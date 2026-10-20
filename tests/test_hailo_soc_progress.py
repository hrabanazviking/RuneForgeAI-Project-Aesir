#!/usr/bin/env python3
"""Independent host completion snapshots; no driver or simulated execution."""
import argparse
import json
from pathlib import Path
import struct
import subprocess
import sys
import unittest

CONFIG = argparse.Namespace()


def irqs(*records, mask=65537):
    result = bytearray(385)
    struct.pack_into("<QQQ", result, 0, mask, 0, 0)
    result[24] = len(records)
    for index, record in enumerate(records):
        result[25 + index * 3:28 + index * 3] = bytes(record)
    return result.hex()


class RpcProgress(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))

    def invoke(self, *args):
        return subprocess.run([self.binary, *map(str, args)], text=True, capture_output=True,
                              stdin=subprocess.DEVNULL, timeout=10, check=False)

    def progress(self, *snapshots, input_count=5, output_count=5):
        return self.invoke("progress", 0, 16, input_count, output_count, *snapshots)

    def accepts(self, *snapshots, input_done=False, output_done=False):
        result = self.progress(*snapshots)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(json.loads(result.stdout), {"input_done": input_done,
                         "output_done": output_done, "complete": input_done and output_done})

    def test_exact_aligned_extent_counts(self):
        for page in (64, 128, 256, 512, 1024, 2048, 4096, 16384, 32768):
            result = self.invoke("count", 65536, page, 65536)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(int(result.stdout), (2068 + page - 1) // page)

    def test_alignment_extent_capacity_and_page_bounds(self):
        for address, page, capacity in ((0, 512, 65536), (1, 512, 65536),
                (65536, 32, 65536), (65536, 65, 65536), (65536, 65536, 65536),
                (65536, 64, 32), (65536, 2048, 2), (65536, 512, 3),
                ((1 << 64) - 64, 64, 65536)):
            result = self.invoke("count", address, page, capacity)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("SocTransferBounds", result.stdout + result.stderr)

    def test_no_record_or_zero_transfer_is_not_completion(self):
        self.accepts(irqs())
        self.accepts(irqs((0, 0, 0), (0, 16, 0)))
        self.accepts(irqs((0, 0, 1)), input_done=True)
        self.accepts(irqs((0, 16, 1)), output_done=True)

    def test_both_completion_orders_and_combined_snapshot(self):
        self.accepts(irqs((0, 0, 1)), irqs((0, 16, 1)), input_done=True, output_done=True)
        self.accepts(irqs((0, 16, 1)), irqs((0, 0, 1)), input_done=True, output_done=True)
        self.accepts(irqs((0, 0, 1), (0, 16, 1)), input_done=True, output_done=True)

    def test_launch_count_is_exact_not_just_positive(self):
        for count in (0, 1, 4, 6, 65535):
            for direction in ("input_count", "output_count"):
                result = self.progress(irqs(), **{direction: count})
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("SocTransferCount", result.stdout + result.stderr)

    def test_irq_errors_inactive_unowned_excess_and_duplicates_refuse(self):
        for snapshot in (irqs((0, 0, 254)), irqs((0, 16, 255)), irqs((1, 0, 1)),
                         irqs((0, 1, 1)), irqs((0, 0, 2)), irqs((0, 16, 253)),
                         irqs((0, 0, 1), (0, 0, 1)), irqs(mask=1)):
            result = self.progress(snapshot)
            self.assertNotEqual(result.returncode, 0)
        result = self.progress(irqs((0, 0, 1)), irqs((0, 0, 1)))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("SocTransferState", result.stdout + result.stderr)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True)
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
