#!/usr/bin/env python3
"""Independent struct-wire checks against the native Mojo framing tool.

Synthetic protocol vectors only; no hardware, LLM inference or model loading.
"""

import argparse
import json
from pathlib import Path
import random
import struct
import subprocess
import sys
import unittest


CONFIG = argparse.Namespace(binary=None)
HEADER = struct.Struct("<5I")
MAGIC = 0x8A554432
MAX_BODY = 2048


class NativeFrameTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if CONFIG.binary is None:
            raise ValueError("--binary is required; compile the real Mojo tool first")
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))

    def invoke(self, data, *, padded=False):
        arguments = [self.binary, data.hex()]
        if padded:
            arguments.append("--dma-buffer")
        return subprocess.run(arguments, capture_output=True, text=True,
                              timeout=10, check=False, stdin=subprocess.DEVNULL)

    def assert_packet(self, body, ids, *, padded=False):
        packet = HEADER.pack(MAGIC, len(body), *ids) + body
        raw = packet + bytes([0xA5]) * (2068 - len(packet)) if padded else packet
        result = self.invoke(raw, padded=padded)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        value = json.loads(result.stdout)
        self.assertEqual(value, {
            "message_id": ids[0], "action_id": ids[1], "remote_status": ids[2],
            "body_hex": body.hex(), "padding_bytes": len(raw) - len(packet),
            "canonical_hex": packet.hex(), "device_access": False,
        })

    def assert_rejected(self, data, *, padded=False):
        result = self.invoke(data, padded=padded)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("HailbruError[BadRpcFrame]", result.stdout + result.stderr)

    def test_fixed_independent_wire_vector(self):
        # Literal independently assembled bytes also check little-endian field order.
        packet = bytes.fromhex("3244558a04000000785634120403020100000000aabbccdd")
        self.assertEqual(packet, HEADER.pack(MAGIC, 4, 0x12345678, 0x01020304, 0)
                         + bytes.fromhex("aabbccdd"))
        self.assert_packet(bytes.fromhex("aabbccdd"), (0x12345678, 0x01020304, 0))

    def test_body_boundaries_and_all_uint32_fields(self):
        for length in (0, 1, 3, 4, 127, 128, 2047, 2048):
            for ids in ((0, 0, 0), (0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF)):
                with self.subTest(length=length, ids=ids):
                    self.assert_packet(bytes(index % 256 for index in range(length)), ids)

    def test_padded_dma_does_not_leak_padding_into_payload(self):
        for length in (0, 1, 17, 2047, 2048):
            with self.subTest(length=length):
                self.assert_packet(bytes([0x72]) * length, (5, 7, 9), padded=True)

    def test_every_truncated_header_rejects(self):
        packet = HEADER.pack(MAGIC, 0, 1, 2, 3)
        for length in range(20):
            with self.subTest(length=length):
                self.assert_rejected(packet[:length])

    def test_magic_length_truncation_and_extra_bytes_reject(self):
        packets = [
            HEADER.pack(MAGIC ^ 1, 0, 1, 2, 3),
            HEADER.pack(MAGIC, 2049, 1, 2, 3),
            HEADER.pack(MAGIC, 0xFFFFFFFF, 1, 2, 3),
            HEADER.pack(MAGIC, 1, 1, 2, 3),
            HEADER.pack(MAGIC, 0, 1, 2, 3) + b"extra",
            HEADER.pack(MAGIC, 3, 1, 2, 3) + b"ab",
            HEADER.pack(MAGIC, 1, 1, 2, 3) + b"ab",
        ]
        for packet in packets:
            with self.subTest(packet=packet.hex()):
                self.assert_rejected(packet)

    def test_dma_mode_requires_exact_padded_buffer(self):
        for size in (20, 2067):
            with self.subTest(size=size):
                self.assert_rejected(HEADER.pack(MAGIC, 0, 1, 2, 3)
                                     + bytes(size - 20), padded=True)
        raw = HEADER.pack(MAGIC, 2049, 1, 2, 3) + bytes(2048)
        self.assert_rejected(raw, padded=True)

    def test_seeded_independent_vectors(self):
        rng = random.Random(20261019)
        for index in range(32):
            length = rng.randrange(2049)
            body = bytes(rng.randrange(256) for _ in range(length))
            ids = tuple(rng.getrandbits(32) for _ in range(3))
            with self.subTest(index=index, length=length):
                self.assert_packet(body, ids, padded=index % 2 == 0)

    def test_hex_and_mode_arguments_reject_before_decode(self):
        cases = [([], "BadArgs"), (["0"], "BadRpcHex"), (["gg"], "BadRpcHex"),
                 (["00" * 2069], "BadRpcHex"), (["", "--unknown"], "BadArgs")]
        for arguments, error in cases:
            with self.subTest(arguments=arguments[:1]):
                result = subprocess.run([self.binary, *arguments], capture_output=True,
                                        text=True, timeout=10, check=False)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("HailbruError[" + error + "]", result.stdout + result.stderr)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    CONFIG, extra = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *extra])
