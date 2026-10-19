#!/usr/bin/env python3
"""Test-only installed C UAPI oracle versus independent native Mojo codecs.

Requires explicit native binaries, compiled separately. Does not open a device.
"""
import argparse
import json
from pathlib import Path
import random
import struct
import subprocess
import sys
import unittest

CONFIG = argparse.Namespace(binary=None, oracle=None)
IOCTLS = {
    "properties": "HAILO_QUERY_DEVICE_PROPERTIES", "driver-info": "HAILO_QUERY_DRIVER_INFO",
    "desc-create": "HAILO_DESC_LIST_CREATE", "desc-release": "HAILO_DESC_LIST_RELEASE",
    "connect": "HAILO_SOC_CONNECT", "close": "HAILO_SOC_CLOSE",
    "enable-channels": "HAILO_VDMA_ENABLE_CHANNELS", "disable-channels": "HAILO_VDMA_DISABLE_CHANNELS",
    "interrupts": "HAILO_VDMA_INTERRUPTS_WAIT", "transfer": "HAILO_VDMA_LAUNCH_TRANSFER",
    "prepare-transfer": "HAILO_VDMA_PREPARE_TRANSFER", "cancel-prepared": "HAILO_VDMA_CANCEL_PREPARED_TRANSFER",
}


class NativeSocAbi(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.oracle = str(Path(CONFIG.oracle).resolve(strict=True))
        result = cls.run_binary(cls.oracle, "layout")
        if result.returncode != 0:
            raise RuntimeError("Installed-header oracle failed: " + result.stderr)
        cls.layout = json.loads(result.stdout)

    @staticmethod
    def run_binary(binary, *arguments):
        return subprocess.run([binary, *map(str, arguments)], capture_output=True,
                              text=True, timeout=10, stdin=subprocess.DEVNULL, check=False)

    def success(self, *arguments):
        result = self.run_binary(self.binary, *arguments)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout.strip()

    def rejects(self, *arguments, code="BadSocAbi"):
        result = self.run_binary(self.binary, *arguments)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("HailbruError[" + code + "]", result.stdout + result.stderr)

    def matches_c(self, *arguments):
        expected = self.run_binary(self.oracle, *arguments)
        self.assertEqual(expected.returncode, 0, expected.stderr)
        self.assertEqual(self.success(*arguments), expected.stdout.strip())

    def test_all_session_ioctl_values_match_installed_header(self):
        self.assertEqual(json.loads(self.success("ioctls")),
                         {op: self.layout[name] for op, name in IOCTLS.items()})

    def test_descriptor_bytes_match_c_packed_struct(self):
        for count in (2, 4, 256, 65536):
            for page in (64, 512, 32768):
                for circular in (0, 1):
                    self.matches_c("desc-create", count, page, circular)
        for handle in (0, 1, 0x1122334455667788, (1 << 64) - 2):
            self.matches_c("desc-release", handle)

    def test_connect_close_and_masks_match_c(self):
        generator = random.Random(0xA3512)
        for _ in range(16):
            self.matches_c("connect", generator.randrange(1, 65536),
                           generator.getrandbits(64), generator.getrandbits(64))
            channels = generator.sample(range(40), 2)
            self.matches_c("close", *channels)
            self.matches_c("channels", *(generator.getrandbits(40) for _ in range(3)))

    def test_transfer_bytes_match_c_including_unaligned_fields(self):
        for channel in (0, 15, 16, 39):
            for cyclic in (0, 1):
                self.matches_c("transfer", channel, 0x1122334455667788,
                               0x8877665544332211, 0xFFFFFFF8, cyclic)

    def test_descriptor_and_channel_replies_use_installed_offsets(self):
        for handle, address in ((0, 0), (0x1122334455667788, 0x8877665544332211)):
            data = bytearray(self.layout["hailo_desc_list_create_params"])
            struct.pack_into("<Q", data, self.layout["hailo_desc_list_create_params.desc_handle"], handle)
            struct.pack_into("<Q", data, self.layout["hailo_desc_list_create_params.dma_address"], address)
            self.assertEqual(json.loads(self.success("desc-reply", data.hex())),
                             {"handle": handle, "dma_address": address})
        data = bytearray(self.layout["hailo_soc_connect_params"])
        data[self.layout["hailo_soc_connect_params.input_channel_index"]] = 3
        data[self.layout["hailo_soc_connect_params.output_channel_index"]] = 19
        self.assertEqual(json.loads(self.success("connect-reply", data.hex())),
                         {"input_channel": 3, "output_channel": 19})
        data[3] = 3
        self.rejects("connect-reply", data.hex())
        data[3] = 255
        self.rejects("connect-reply", data.hex())
        data = bytearray(self.layout["hailo_desc_list_create_params"])
        struct.pack_into("<Q", data, 11, (1 << 64) - 1)
        self.rejects("desc-reply", data.hex())

    def test_properties_and_driver_version_preserve_unfamiliar_values(self):
        data = struct.pack("<HIIQB", 512, 2, 0, 1, 1)
        self.assertEqual(len(data), self.layout["hailo_device_properties"])
        self.assertEqual(json.loads(self.success("properties", data.hex())), {
            "desc_max_page_size": 512, "board_type": 2, "dma_type": 0,
            "dma_engines_count": 1, "is_fw_loaded": True})
        data = struct.pack("<HIIQB", 65535, 99, 99, (1 << 64) - 1, 0)
        actual = json.loads(self.success("properties", data.hex()))
        self.assertEqual(actual["board_type"], 99)
        self.assertEqual(actual["dma_engines_count"], (1 << 64) - 1)
        self.assertIs(actual["is_fw_loaded"], False)
        data = struct.pack("<III", 5, 3, 0xFFFFFFFF)
        self.assertEqual(json.loads(self.success("driver-info", data.hex())),
                         {"major": 5, "minor": 3, "revision": 0xFFFFFFFF})

    def test_interrupt_count_statuses_and_bounds(self):
        data = bytearray(self.layout["hailo_vdma_interrupts_wait_params"])
        data[24] = 3
        data[25:34] = bytes((0, 3, 1, 0, 19, 254, 2, 39, 255))
        self.assertEqual(json.loads(self.success("interrupts", data.hex())), [
            {"engine": 0, "channel": 3, "data": 1},
            {"engine": 0, "channel": 19, "data": 254},
            {"engine": 2, "channel": 39, "data": 255}])
        for offset, value in ((24, 121), (25, 3), (26, 40), (28, 3), (29, 3)):
            malformed = data.copy()
            malformed[offset] = value
            # Changing channel 19 to 3 creates a duplicate on engine zero.
            self.rejects("interrupts", malformed.hex())
        full = bytearray(385)
        full[24] = 120
        for i in range(120):
            full[25 + 3 * i:28 + 3 * i] = bytes((i // 40, i % 40, 128))
        self.assertEqual(len(json.loads(self.success("interrupts", full.hex()))), 120)

    def test_every_decoder_rejects_truncated_and_extra_storage(self):
        for op, size in (("properties", 19), ("driver-info", 12), ("desc-reply", 27),
                         ("connect-reply", 20), ("interrupts", 385)):
            for actual in (0, size - 1, size + 1):
                self.rejects(op, bytes(actual).hex())
        data = bytearray(19)
        data[18] = 2
        self.rejects("properties", data.hex())

    def test_invalid_requests_are_rejected_before_any_device_access(self):
        for args in (("desc-create", 0, 512, 1), ("desc-create", 3, 512, 1),
                     ("desc-create", 131072, 512, 1), ("desc-create", 2, 32, 1),
                     ("desc-create", 2, 65536, 1), ("desc-create", 2, 65, 1),
                     ("desc-release", (1 << 64) - 1), ("connect", 0, 1, 2),
                     ("connect", 65536, 1, 2), ("connect", 12133, 1, 1),
                     ("close", 1, 1), ("close", 40, 16), ("channels", 1 << 40, 0, 0),
                     ("transfer", 1, 0, 0, 16, 1), ("transfer", 1, 0, 1, 0, 1),
                     ("transfer", 1, 0, 1, 1 << 32, 1)):
            self.rejects(*args)
        for args in (("desc-release", -1), ("desc-release", 1 << 64),
                     ("desc-create", 2, 512, 2), ("unknown",), ("ioctls", "extra")):
            self.rejects(*args, code="BadArgs")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True)
    parser.add_argument("--oracle", required=True)
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
