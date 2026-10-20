#!/usr/bin/env python3
"""Independent source-message bytes through real native-owned host storage."""
import argparse
import json
from pathlib import Path
import random
import struct
import subprocess
import sys
import unittest
from test_hailo_hrpc_device import MESSAGES

CONFIG = argparse.Namespace()


class OwnedBytes(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))

    def invoke(self, mode, data):
        return subprocess.run([self.binary, mode, data.hex()], text=True, capture_output=True,
                              timeout=10, stdin=subprocess.DEVNULL, check=False)

    def roundtrip(self, data):
        result = self.invoke("bytes", data)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(bytes.fromhex(result.stdout.strip()), data + bytes(2068 - len(data)))

    def test_independent_protobuf_requests_and_frame_headers(self):
        for message_id in (0, 0xFFFFFFFF):
            for action in (20, 21, 22):
                handles = (0, 1, 0xFFFFFFFF) if action != 20 else (0,)
                for handle in handles:
                    message = MESSAGES["CreateRequest"]() if action == 20 else MESSAGES["HandleRequest"]()
                    if action != 20:
                        message.device_handle.SetInParent()
                        message.device_handle.id = handle
                    body = message.SerializeToString()
                    frame = struct.pack("<5I", 0x8A554432, len(body), message_id, action, 1) + body
                    self.roundtrip(frame)

    def test_full_range_and_seeded_bytes_are_exact_with_zeroed_padding(self):
        generator = random.Random(0x2068)
        for size in (0, 1, 19, 20, 2067, 2068):
            self.roundtrip(bytes(generator.randrange(256) for _ in range(size)))
        for _ in range(16):
            size = generator.randrange(2069)
            self.roundtrip(bytes(generator.randrange(256) for _ in range(size)))

    def test_refusals_and_independent_copies(self):
        result = self.invoke("guards", bytes(range(256)))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(json.loads(result.stdout), {
            "refusals": 7, "input_copy": True, "snapshot_copy": True,
            "refused_write_preserved_storage": True, "device_access": False})

    def test_oversized_message_refused(self):
        result = self.invoke("bytes", bytes(2069))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("BadRpcHex", result.stdout + result.stderr)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True)
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
