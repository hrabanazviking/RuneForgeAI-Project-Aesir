#!/usr/bin/env python3
"""Synthetic USERPTR scalar codec tests. No addresses are dereferenced."""
import argparse
import json
from pathlib import Path
import random
import struct
import subprocess
import sys
import unittest

CONFIG = argparse.Namespace()
MAX = (1 << 64) - 1


def packed(channel, handle, spans):
    data = bytearray(141)
    struct.pack_into('<BQB', data, 0, channel, handle, len(spans))
    for i, (address, size) in enumerate(spans):
        struct.pack_into('<IQI', data, 10 + 16 * i, 0, address, size)
    return data.hex()


class GroupCodec(unittest.TestCase):
    @staticmethod
    def run_binary(binary, *args):
        return subprocess.run([str(Path(binary).resolve(strict=True)), *map(str, args)],
                              capture_output=True, text=True, timeout=15,
                              stdin=subprocess.DEVNULL, check=False)

    def ok(self, *args):
        p = self.run_binary(CONFIG.binary, *args)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertEqual(p.stderr, '')
        return p.stdout.strip()

    def refuse(self, *args):
        p = self.run_binary(CONFIG.binary, *args)
        self.assertNotEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertEqual(p.stdout, '')
        self.assertIn('HailbruError[', p.stderr)

    def vector(self, channel, handle, spans):
        words = [x for pair in spans for x in pair]
        expected = packed(channel, handle, spans)
        actual = self.ok('encode', channel, handle, *words)
        self.assertEqual(actual, expected)
        oracle = self.run_binary(CONFIG.oracle, channel, handle, *words)
        self.assertEqual((oracle.returncode, oracle.stdout.strip(), oracle.stderr), (0, expected, ''))
        self.assertEqual(self.ok('decode', actual), actual)
        if len(spans) == 1:
            old = self.run_binary(CONFIG.original, 'transfer', channel, handle, *words, 0)
            self.assertEqual((old.returncode, old.stdout.strip(), old.stderr), (0, expected, ''))

    def test_all_counts_slots_order_extremes(self):
        cases = [(1, 1), (MAX - 1, 1), (MAX - 0xffffffff, 0xffffffff),
                 (0x1122334455667788, 0x89abcdef), (65536, 2068), (196608, 70)]
        for count in range(1, 9):
            for step in range(len(cases)):
                spans = [cases[(i + step) % len(cases)] for i in range(count)]
                self.vector((count * 5 + step) % 40, (0, MAX - 1, 0x123456789abcdef0)[step % 3], spans)
                self.vector(39, 0, list(reversed(spans)))

    def test_walking_bits_and_random_words(self):
        for bit in range(64):
            spans = [(65536 + i, 1 + i) for i in range(8)]
            spans[bit % 8] = (1 << bit, 1)
            self.vector(bit % 40, 1 << min(bit, 63), spans)
        for bit in range(32):
            spans = [(100000 + i, 1) for i in range(8)]
            spans[bit % 8] = (0x1234567890abcdef, 1 << bit)
            self.vector(0, 0, spans)
        rng = random.Random(0xA3512)
        for _ in range(32):
            count = rng.randrange(1, 9)
            spans = []
            for _ in range(count):
                size = rng.randrange(1, 1 << 32)
                spans.append((rng.randrange(1, MAX - size + 1), size))
            self.vector(rng.randrange(40), rng.randrange(MAX), spans)

    def test_invalid_values_and_stricter_extent_scope(self):
        for channel in (40, 255, MAX):
            self.refuse('encode', channel, 0, 1, 1)
        self.refuse('encode', 0, MAX, 1, 1)
        for pair in ((0, 1), (1, 0), (1, 1 << 32), (1, MAX),
                     (MAX, 1), (MAX - 1, 2), (MAX - 0xfffffffe, 0xffffffff)):
            self.refuse('encode', 0, 0, *pair)
        # Old helper accepts wrapped extents: intentional new refusal, no old edit.
        p = self.run_binary(CONFIG.original, 'transfer', 0, 0, MAX, 1, 0)
        self.assertEqual(p.returncode, 0)
        self.assertEqual(p.stdout.strip(), packed(0, 0, [(MAX, 1)]))
        self.vector(0, 0, [(MAX - 1, 1)])

    def test_all_packed_counts_and_profile_fields(self):
        data = bytearray.fromhex(packed(3, 0, [(65536, 2068)]))
        for count in range(256):
            if count == 1:
                continue
            bad = data.copy(); bad[9] = count
            self.refuse('decode', bad.hex())
        for offset in (138, 139, 140):
            for value in (1, 2, 255):
                bad = data.copy(); bad[offset] = value
                self.refuse('decode', bad.hex())
        for offset, value in ((0, 40), (0, 255)):
            bad = data.copy(); bad[offset] = value
            self.refuse('decode', bad.hex())
        bad = data.copy(); struct.pack_into('<Q', bad, 1, MAX)
        self.refuse('decode', bad.hex())

    def test_every_used_slot_and_unused_storage(self):
        for count in range(1, 9):
            spans = [(65536 + i * 4096, 1 + i) for i in range(count)]
            data = bytearray.fromhex(packed(3, 0, spans))
            for slot in range(count):
                for byte in range(4):
                    bad = data.copy(); bad[10 + 16 * slot + byte] = 1
                    self.refuse('decode', bad.hex())
                for address, size in ((0, 1), (1, 0), (MAX, 1)):
                    bad = data.copy(); struct.pack_into('<QI', bad, 14 + 16 * slot, address, size)
                    self.refuse('decode', bad.hex())
            # Every byte in every unused slot, including pointer/type/size.
            for offset in range(10 + 16 * count, 138):
                bad = data.copy(); bad[offset] = 1
                self.refuse('decode', bad.hex())
        self.vector(3, 0, [(65536, 2068), (196608, 70)])

    def test_truncations_and_trailing_bytes(self):
        data = bytes.fromhex(packed(3, 0, [(65536, 2068), (196608, 70)]))
        for extent in range(141):
            self.refuse('decode', data[:extent].hex())
        for extra in range(1, 21):
            self.refuse('decode', (data + bytes(extra)).hex())
        self.refuse('decode', '00' * 2069)
        self.assertEqual(self.ok('decode', data.hex()), data.hex())

    def test_argument_work_bounds_and_malformed_inputs(self):
        for args in ((), ('unknown',), ('encode', 0, 0), ('encode', 0, 0, 1),
                     ('encode', 0, 0, *([1, 1] * 9)), ('encode', '-1', 0, 1, 1),
                     ('encode', str(1 << 64), 0, 1, 1), ('encode', '1' * 21, 0, 1, 1),
                     ('encode', '', 0, 1, 1), ('encode', 'x', 0, 1, 1),
                     ('decode', 'g' * 282), ('decode', '0' * 281),
                     ('decode', '00' * 141, 'extra')):
            self.refuse(*args)
        self.vector(0, 0, [(1, 1)])

    def test_direct_owned_values_mutation_move_and_recovery(self):
        p = self.run_binary(CONFIG.ownership)
        self.assertEqual((p.returncode, p.stderr), (0, ''))
        self.assertEqual(json.loads(p.stdout), {'ownership': True, 'refusal_recovery_cycles': 177})


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    for name in ('binary', 'oracle', 'original', 'ownership'):
        parser.add_argument('--' + name, required=True)
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
