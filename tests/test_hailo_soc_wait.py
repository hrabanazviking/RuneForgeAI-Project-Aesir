#!/usr/bin/env python3
"""Actual assigned-channel wait deadlines/cancellation. No DMA launches."""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import unittest
from test_hailo_soc_session import requests, INFO, PROPS, CREATE, RELEASE, CONNECT, CLOSE
from test_hailo_soc_storage import MAP, UNMAP
from test_hailo_blocking_worker import completed_syscalls

CONFIG = argparse.Namespace()
ENABLE, DISABLE, IRQ = 0x80187600, 0x80187601, 0xC1817602
PREFIX = [INFO, PROPS, CREATE, CREATE, CONNECT, MAP, MAP]
NORMAL = PREFIX + [ENABLE, IRQ, DISABLE, CLOSE, UNMAP, UNMAP, RELEASE, RELEASE]


class AssignedWait(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not CONFIG.hardware:
            raise unittest.SkipTest("requires --hardware")
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.strace = str(Path(CONFIG.strace).resolve(strict=True))
        cls.temp = None
        if CONFIG.evidence_root:
            cls.root = Path(CONFIG.evidence_root).resolve()
            cls.root.mkdir(parents=True, exist_ok=True)
        else:
            cls.temp = tempfile.TemporaryDirectory(prefix="aesir-wait-")
            cls.root = Path(cls.temp.name)

    @classmethod
    def tearDownClass(cls):
        if cls.temp:
            cls.temp.cleanup()

    def run_owner(self, name, fault=None, terminal=False):
        path = self.root / (name + ".strace")
        command = [self.strace, "-f", "-y", "-o", str(path), "-e",
                   "trace=ioctl,close,mmap,munmap,clone,clock_gettime,futex,exit_group"]
        if fault:
            command += ["-e", fault]
        command += [self.binary, "/sys", "/dev"]
        start = time.monotonic()
        result = subprocess.run(command, capture_output=True, text=True,
                                timeout=10, stdin=subprocess.DEVNULL, check=False)
        elapsed = time.monotonic() - start
        (self.root / (name + ".stdout")).write_text(result.stdout)
        (self.root / (name + ".stderr")).write_text(result.stderr)
        (self.root / (name + ".command.json")).write_text(json.dumps(command))
        raw = path.read_text()
        trace = completed_syscalls(raw)
        self.assertNotIn(0x808D760C, requests(trace), "DMA unexpectedly launched")
        lines = trace.splitlines()
        closes = [i for i, line in enumerate(lines) if re.search(r'close\(\d+</dev/h1x-0>\)\s+= 0', line)]
        # Runtime mmap calls can appear after enable when pthread starts. Select
        # only the two writable anonymous host pages before that ENABLE ioctl.
        calls = [i for i, line in enumerate(lines) if "ioctl(" in line and "</dev/h1x-0>" in line]
        start_index, end_index = calls[4], calls[7]
        allocations = []
        for i in range(start_index, end_index):
            match = re.search(r'mmap\(NULL, (\d+), PROT_READ\|PROT_WRITE, MAP_PRIVATE\|MAP_ANONYMOUS, -1, 0\) = (0x[0-9a-f]+)$', lines[i])
            if match:
                allocations.append(match.groups())
        self.assertEqual(len(allocations), 2)
        if terminal:
            self.assertEqual(closes, [])
            self.assertNotIn("SocCleanupFailed", result.stdout + result.stderr)
            for size, pointer in allocations:
                self.assertFalse(any(i > start_index and re.search(r'munmap\(' + pointer + ', ' + size + r'\)\s+= 0', line)
                                     for i, line in enumerate(lines)))
        else:
            self.assertEqual(len(closes), 1)
            for size, pointer in allocations:
                released = [i for i, line in enumerate(lines) if i > start_index and re.search(r'munmap\(' + pointer + ', ' + size + r'\)\s+= 0', line)]
                self.assertEqual(len(released), 1)
                self.assertGreater(released[0], closes[0])
            irq_done = [i for i, line in enumerate(lines) if "ioctl(" in line and "0x2, 0x181)" in line]
            if irq_done:
                self.assertLess(irq_done[0], closes[0])
        self.assertLess(elapsed, 5)
        return result, trace, elapsed

    def clean(self, name, fault=None, attempts=1):
        result, trace, elapsed = self.run_owner(name, fault)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data["cancel_attempts"], attempts)
        self.assertEqual(data["owned_mask"].bit_count(), 2)
        self.assertEqual(data["owned_mask"] & 0xFFFF, data["owned_mask"] & -data["owned_mask"])
        self.assertEqual(data["irq_after_disable"], [])
        for key in ("timed_out", "waiter_joined", "cancelled_use_refused", "storage_released"):
            self.assertIs(data[key], True)
        self.assertIs(data["user_dma_submitted"], False)
        expected = NORMAL + ([DISABLE] if attempts == 2 else [])
        self.assertEqual(Counter(requests(trace)), Counter(expected))
        self.assertIn("ETIMEDOUT", trace)
        return trace, elapsed

    def test_eight_fresh_assigned_channel_timeouts_and_cleanup(self):
        for i in range(8):
            self.clean("normal-" + str(i))

    def test_first_disable_failure_retries_then_joins_before_cleanup(self):
        # strace injection counters are per thread. Parent's disable is call 9;
        # the wait thread issues its own first ioctl separately.
        _, elapsed = self.clean("disable-retry", "inject=ioctl:error=EIO:when=9", attempts=2)
        self.assertGreaterEqual(elapsed, 1.025)
        self.clean("after-disable-retry")

    def test_enable_failure_unwinds_armed_interrupt_state(self):
        result, trace, _ = self.run_owner("enable-failure", "inject=ioctl:error=EIO:when=8")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("enable-channels", result.stdout + result.stderr)
        self.assertEqual(Counter(requests(trace)), Counter([value for value in NORMAL if value != IRQ]))
        self.clean("after-enable-failure")

    def test_clock_failure_disables_and_joins_before_unwind(self):
        result, trace, _ = self.run_owner("clock-failure", "inject=clock_gettime:error=EIO:when=1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("monotonic clock failed", result.stdout + result.stderr)
        self.assertEqual(Counter(requests(trace)), Counter(NORMAL))
        self.clean("after-clock-failure")

    def test_close_failure_after_join_retains_pages_until_file_finalization(self):
        result, trace, _ = self.run_owner("close-failure", "inject=ioctl:error=EIO:when=10")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("SocCleanupFailed", result.stdout + result.stderr)
        self.assertEqual(Counter(requests(trace)), Counter(PREFIX + [ENABLE, IRQ, DISABLE, CLOSE]))
        self.clean("after-close-failure")

    def test_persistent_disable_failure_exits_without_unsafe_destructors(self):
        result, trace, elapsed = self.run_owner("disable-terminal", "inject=ioctl:error=EIO:when=9+", terminal=True)
        self.assertEqual(result.returncode, 124, result.stdout + result.stderr)
        self.assertIn("SocWaitCancelFatal", result.stdout + result.stderr)
        self.assertIn("exit_group(124)", trace)
        self.assertGreaterEqual(elapsed, 2.025)
        self.clean("after-disable-terminal")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True)
    parser.add_argument("--strace", required=True)
    parser.add_argument("--evidence-root")
    parser.add_argument("--hardware", action="store_true")
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
