#!/usr/bin/env python3
"""Aligned RPC storage layout admission and CPU scatter/gather tests.

HOST ONLY: real host allocations, no driver opened or simulated.
The independent oracle is this file: it reconstructs the canonical
2068-byte logical frame and each physical region from first principles.
"""
import argparse
import json
import subprocess
import sys
import unittest
from pathlib import Path

CONFIG = argparse.Namespace()
LOGICAL = 2068
HEADER = 20
BODY = 2048


def frame(payload: bytes) -> bytes:
    assert len(payload) <= LOGICAL
    return payload + bytes(LOGICAL - len(payload))


class AlignedStorage(unittest.TestCase):
    def run_binary(self, *args):
        return subprocess.run(
            [str(Path(CONFIG.binary).resolve(strict=True)), *map(str, args)],
            capture_output=True, text=True, timeout=15,
            stdin=subprocess.DEVNULL, check=False)

    def ok(self, *args):
        p = self.run_binary(*args)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertEqual(p.stderr, '')
        return json.loads(p.stdout.strip())

    def refuse(self, *args):
        p = self.run_binary(*args)
        self.assertNotEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertIn('HailbruError[', p.stdout + p.stderr)

    def test_layout_legacy_exact(self):
        self.assertEqual(
            self.ok('layout-legacy'),
            {'page': 0, 'body_offset': 20, 'mapped_size': 2068,
             'logical_size': 2068, 'aligned': False})

    def test_layout_admissions(self):
        for page, body_offset, mapped in (
                (64, 64, 2112), (128, 128, 2176), (256, 256, 2304),
                (512, 512, 2560), (4096, 4096, 6144), (32768, 32768, 34816)):
            self.assertEqual(
                self.ok('layout', page),
                {'page': page, 'body_offset': body_offset,
                 'mapped_size': mapped, 'logical_size': 2068,
                 'aligned': True}, page)

    def test_layout_refusals(self):
        for page in (0, 1, 2, 20, 32, 63, 96, 100, 1000, 65536,
                     1 << 40, (1 << 64) - 1):
            self.refuse('layout', page)

    def test_scatter_gather_projection(self):
        for page in (0, 64, 512):
            for size in (0, 1, 19, 20, 21, 100, 2047, 2048, 2068):
                payload = bytes((i * 31 + 5) % 256 for i in range(size))
                result = self.ok('scatter', page, payload.hex())
                expected = frame(payload)
                self.assertEqual(result['gather'], expected.hex(), (page, size))
                self.assertEqual(result['header'], expected[:HEADER].hex(), (page, size))
                self.assertEqual(result['body'], expected[HEADER:].hex(), (page, size))
                self.assertTrue(result['gap_all_zero'], (page, size))
                self.assertEqual(result['gap_size'],
                                 (page if page else HEADER) - HEADER, (page, size))
                self.assertTrue(result['cleared'], (page, size))
                self.assertEqual(result['body_offset'],
                                 page if page else HEADER, (page, size))
                self.assertEqual(result['mapped_size'],
                                 (page + BODY) if page else LOGICAL, (page, size))

    def test_scatter_oversize_refused(self):
        self.refuse('scatter', 512, bytes(2069).hex())
        self.refuse('scatter', 0, bytes(2069).hex())

    def test_guards(self):
        for page in (64, 512):
            self.assertEqual(self.ok('guards', page), {'refusals': 7})


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--binary', required=True)
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
