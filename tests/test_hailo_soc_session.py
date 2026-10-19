#!/usr/bin/env python3
"""Physical assigned-connection ownership checks; no user DMA/model transfer.

Only --hardware runs these tests. strace injects errors before selected ioctls
enter the driver, observes exact cleanup order and records optional raw evidence.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

CONFIG = argparse.Namespace()
INFO, PROPS = 0x400C6701, 0x40136700
CREATE, RELEASE = 0xC01B7606, 0x80087607
CONNECT, CLOSE = 0xC0147300, 0x80027301
NORMAL = [INFO, PROPS, CREATE, CREATE, CONNECT, CLOSE, RELEASE, RELEASE]


def requests(trace):
    result = []
    for line in trace.splitlines():
        match = re.search(r'ioctl\(\d+</dev/h1x-0>, (.+), 0x[0-9a-f]+\)\s+=', line)
        if not match:
            continue
        expression = match[1]
        if expression.startswith("0x"):
            code = int(expression, 16)
        else:
            fields = re.fullmatch(r'_IOC\(([^,]+), ([^,]+), ([^,]+), ([^)]+)\)', expression)
            if fields is None:
                raise AssertionError("Unexpected ioctl rendering: " + expression)
            direction, kind, number, size = fields.groups()
            bits = 0
            for flag in direction.split("|"):
                bits |= {"_IOC_READ": 2, "_IOC_WRITE": 1}[flag]
            code = (bits << 30) | (int(size, 0) << 16) | (int(kind, 0) << 8) | int(number, 0)
        result.append(code)
    return result


class AssignedSession(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not CONFIG.hardware:
            raise unittest.SkipTest("physical host access requires --hardware")
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.unwind = str(Path(CONFIG.unwind_binary).resolve(strict=True))
        cls.strace = str(Path(CONFIG.strace).resolve(strict=True))
        if CONFIG.evidence_root:
            cls.evidence = Path(CONFIG.evidence_root).resolve()
            cls.evidence.mkdir(parents=True, exist_ok=True)
        else:
            cls.temp = tempfile.TemporaryDirectory(prefix="aesir-soc-session-")
            cls.evidence = Path(cls.temp.name)

    @classmethod
    def tearDownClass(cls):
        if hasattr(cls, "temp"):
            cls.temp.cleanup()

    def run_session(self, name, fault=None, unwind=False):
        trace = self.evidence / (name + ".strace")
        command = [self.strace, "-y", "-o", str(trace), "-e", "trace=openat,close,ioctl,statx"]
        if fault is not None:
            command += ["-e", "inject=ioctl:error=EIO:when=" + str(fault)]
        command += [self.unwind if unwind else self.binary, "/sys", "/dev"]
        result = subprocess.run(command, capture_output=True, text=True, timeout=10,
                                stdin=subprocess.DEVNULL, check=False)
        (self.evidence / (name + ".stdout")).write_text(result.stdout)
        (self.evidence / (name + ".stderr")).write_text(result.stderr)
        raw = trace.read_text()
        self.assertEqual(len(re.findall(r'openat\([^\n]*"/dev/h1x-0"[^\n]*= \d+</dev/h1x-0>', raw)), 1, raw)
        self.assertEqual(len(re.findall(r'close\(\d+</dev/h1x-0>\)\s+= 0', raw)), 1, raw)
        return result, raw

    def clean(self, name):
        result, trace = self.run_session(name)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(requests(trace), NORMAL)
        data = json.loads(result.stdout)
        self.assertEqual(data["port"], 12133)
        self.assertEqual(data["descriptor_count_per_direction"], 65536)
        self.assertEqual(data["descriptor_page_size"], 512)
        self.assertNotEqual(data["input_handle"], data["output_handle"])
        self.assertLess(data["input_channel"], 16)
        self.assertGreaterEqual(data["output_channel"], 16)
        self.assertLess(data["output_channel"], 32)
        for key in ("connection_closed", "repeat_close", "closed_use_refused"):
            self.assertIs(data[key], True)
        self.assertIs(data["user_dma_submitted"], False)

    def fails(self, name, when, expected, code):
        result, trace = self.run_session(name, when)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("HailbruError[" + code + "]", result.stderr + result.stdout)
        self.assertIn("(INJECTED)", trace)
        self.assertEqual(requests(trace), expected)

    def test_normal_order_repeat_close_and_three_fresh_sessions(self):
        for index in range(3):
            self.clean("normal-" + str(index))

    def test_first_descriptor_failure_closes_without_release(self):
        self.fails("first-descriptor-failure", 3, NORMAL[:3], "SocIoctlFailed")
        self.clean("after-first-descriptor-failure")

    def test_second_descriptor_failure_releases_only_acquired_list(self):
        self.fails("second-descriptor-failure", 4, NORMAL[:4] + [RELEASE], "SocIoctlFailed")
        self.clean("after-second-descriptor-failure")

    def test_uncertain_connect_uses_file_context_cleanup(self):
        self.fails("connect-failure", 5, NORMAL[:5], "SocIoctlFailed")
        self.clean("after-connect-failure")

    def test_failed_close_does_not_explicitly_free_active_descriptors(self):
        self.fails("close-failure", 6, NORMAL[:6], "SocCleanupFailed")
        self.clean("after-close-failure")

    def test_each_descriptor_release_failure_still_attempts_remaining_cleanup(self):
        for when in (7, 8):
            self.fails("release-failure-" + str(when), when, NORMAL, "SocCleanupFailed")
            self.clean("after-release-failure-" + str(when))

    def test_exception_unwinding_closes_connection_before_lists_and_fd(self):
        result, trace = self.run_session("exception-unwind", unwind=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(requests(trace), NORMAL)
        self.assertEqual(result.stdout.strip(), "expected exception caught after session scope")
        self.clean("after-exception-unwind")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True)
    parser.add_argument("--unwind-binary", required=True)
    parser.add_argument("--strace", required=True)
    parser.add_argument("--evidence-root")
    parser.add_argument("--hardware", action="store_true")
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
