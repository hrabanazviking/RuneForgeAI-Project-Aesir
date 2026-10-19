#!/usr/bin/env python3
"""Native owner boundary tests; physical cases require explicit --hardware.

strace observes actual closes and can fail the read-only ioctl before entry.
No fake device, model computation, DMA, driver reset or module change is used.
"""
import argparse
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import tempfile
import unittest

CONFIG = argparse.Namespace()


class DriverOwner(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.unwind = str(Path(CONFIG.unwind_binary).resolve(strict=True))
        cls.strace = str(Path(CONFIG.strace).resolve(strict=True))
        cls.oracle = str(Path(CONFIG.oracle).resolve(strict=True))

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="aesir-soc-owner-")
        self.root = Path(self.temp.name)
        self.sysfs = self.root / "sys"
        self.dev = self.root / "dev"
        self.pci = self.sysfs / "bus/pci/devices/0001:01:00.0"
        self.node = self.pci / "hailo1x/h1x-0"
        self.node.mkdir(parents=True)
        self.dev.mkdir()
        (self.pci / "vendor").write_text("0x1e60\n")
        (self.pci / "device").write_text("0x45c4\n")
        (self.node / "dev").write_text("508:0\n")

    def tearDown(self):
        self.temp.cleanup()

    def invoke(self, sysfs=None, dev=None, *, trace=False, fault=None, unwind=False):
        trace_path = self.root / "syscalls.txt"
        command = [self.unwind if unwind else self.binary,
                   str(sysfs or self.sysfs), str(dev or self.dev)]
        if trace or fault:
            options = [self.strace, "-y", "-o", str(trace_path), "-e", "trace=openat,close,ioctl,statx"]
            if fault:
                options += ["-e", "inject=ioctl:error=EIO:when=" + str(fault)]
            command = options + command
        result = subprocess.run(command, capture_output=True, text=True, timeout=10,
                                stdin=subprocess.DEVNULL, check=False)
        return result, trace_path.read_text() if trace_path.exists() else ""

    def reject(self, code, **kwargs):
        result, trace = self.invoke(**kwargs)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("HailbruError[" + code + "]", result.stderr + result.stdout)
        return trace

    def closed_once(self, trace, path):
        opened = re.findall(r'openat\([^\n]*"' + re.escape(str(path)) + r'"[^\n]*= (\d+)<', trace)
        self.assertEqual(len(opened), 1, trace)
        fd = opened[0]
        closes = re.findall(r'close\(' + fd + '<' + re.escape(str(path)) + r'>\)\s+= 0', trace)
        self.assertEqual(len(closes), 1, trace)
        return fd

    def test_host_uname_statx_layout_matches_compiled_system_headers(self):
        result = subprocess.run([self.oracle, "host-layout"], capture_output=True,
                                text=True, check=True, timeout=10)
        self.assertEqual(json.loads(result.stdout), {
            "uname_size": 390, "uname_machine": 260, "statx_size": 256,
            "statx_mode": 28, "statx_rdev_major": 128, "statx_rdev_minor": 132,
            "statx_syscall": {"aarch64": 291, "x86_64": 332}[platform.machine()],
            "o_nofollow": {"aarch64": 0o100000, "x86_64": 0o400000}[platform.machine()]})

    def test_missing_matching_pci_device(self):
        (self.pci / "device").write_text("0xffff\n")
        self.reject("DeviceNotFound")

    def test_multiple_matching_pci_devices(self):
        second = self.pci.parent / "0002:01:00.0"
        second.mkdir()
        (second / "vendor").write_text("0x1e60\n")
        (second / "device").write_text("0x45c4\n")
        self.reject("MultipleDevices")

    def test_missing_or_ambiguous_node_association(self):
        (self.node / "dev").unlink()
        self.node.rmdir()
        self.reject("SocDriverMismatch")
        self.node.mkdir()
        (self.node.parent / "h1x-1").mkdir()
        self.reject("SocDriverMismatch")

    def test_invalid_node_name_and_missing_device_node(self):
        self.node.rename(self.node.parent / "h1x-invalid")
        self.reject("SocDriverMismatch")
        (self.node.parent / "h1x-invalid").rename(self.node)
        self.reject("SocOpenFailed")

    def test_regular_file_and_fifo_refuse_without_hang_and_close(self):
        path = self.dev / "h1x-0"
        path.write_text("not a device")
        trace = self.reject("SocDriverMismatch", trace=True)
        fd = self.closed_once(trace, path)
        self.assertNotRegex(trace, r'ioctl\(' + fd + '<' + re.escape(str(path)))
        path.unlink()
        os.mkfifo(path)
        trace = self.reject("SocDriverMismatch", trace=True)
        self.closed_once(trace, path)

    def test_node_symlink_refused_at_open(self):
        (self.dev / "h1x-0").symlink_to("/dev/null")
        trace = self.reject("SocOpenFailed", trace=True)
        self.assertNotIn("ioctl(", trace)
        self.assertIn("O_NOFOLLOW", trace)

    def require_hardware(self):
        if not CONFIG.hardware:
            self.skipTest("physical host access requires --hardware")

    def test_physical_query_and_explicit_repeat_close(self):
        self.require_hardware()
        result, trace = self.invoke("/sys", "/dev", trace=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data["arch"], platform.machine())
        self.assertEqual(data["driver"], {"major": 5, "minor": 3, "revision": 0})
        self.assertEqual(data["properties"]["board_type"], 2)
        self.assertEqual(data["properties"]["dma_type"], 0)
        self.assertTrue(data["properties"]["is_fw_loaded"])
        for name in ("fd_closed", "repeat_close", "closed_request_refused"):
            self.assertIs(data[name], True)
        self.assertIs(data["dma_submitted"], False)
        fd = self.closed_once(trace, Path("/dev") / data["node"])
        calls = re.findall(r'ioctl\(' + fd + r'<[^>]+>, (.+), 0x[0-9a-f]+\)\s+= 0', trace)
        codes = []
        for call in calls:
            if call.startswith("0x"):
                codes.append(int(call, 16))
            else:
                expression = re.fullmatch(r'_IOC\((_IOC_WRITE|_IOC_READ), ([^,]+), ([^,]+), ([^)]+)\)', call)
                self.assertIsNotNone(expression, call)
                direction, kind, number, size = expression.groups()
                codes.append(({"_IOC_WRITE": 1, "_IOC_READ": 2}[direction] << 30)
                             | (int(size, 0) << 16) | (int(kind, 0) << 8) | int(number, 0))
        self.assertEqual(codes, [0x400c6701, 0x40136700], trace)

    def test_physical_rdev_mismatch_closes_before_ioctl(self):
        self.require_hardware()
        (self.node / "dev").write_text("0:0\n")
        trace = self.reject("SocDriverMismatch", dev="/dev", trace=True)
        fd = self.closed_once(trace, Path("/dev/h1x-0"))
        self.assertNotRegex(trace, r'ioctl\(' + fd + r'</dev/h1x-0>')

    def test_physical_readonly_query_failures_close(self):
        self.require_hardware()
        for when in (1, 2):
            with self.subTest(ioctl_number=when):
                trace = self.reject("SocIoctlFailed", sysfs="/sys", dev="/dev", fault=when)
                self.assertIn("(INJECTED)", trace)
                self.closed_once(trace, Path("/dev/h1x-0"))

    def test_physical_exception_unwinding_closes(self):
        self.require_hardware()
        result, trace = self.invoke("/sys", "/dev", trace=True, unwind=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("expected exception caught", result.stdout)
        self.closed_once(trace, Path("/dev/h1x-0"))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True)
    parser.add_argument("--unwind-binary", required=True)
    parser.add_argument("--oracle", required=True)
    parser.add_argument("--strace", required=True)
    parser.add_argument("--hardware", action="store_true")
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
