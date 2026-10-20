#!/usr/bin/env python3
"""Physical native Mojo RPC, real DMA and private read-only device lifecycle."""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from test_hailo_soc_session import requests, INFO, PROPS, CREATE, RELEASE, CONNECT, CLOSE
from test_hailo_soc_storage import MAP, UNMAP, SYNC
from test_hailo_soc_wait import ENABLE, DISABLE, IRQ
from test_hailo_blocking_worker import completed_syscalls

CONFIG = argparse.Namespace()
LAUNCH = 0x808D760C


class NativeRpc(unittest.TestCase):
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
            cls.temp = tempfile.TemporaryDirectory(prefix="aesir-native-rpc-")
            cls.root = Path(cls.temp.name)

    @classmethod
    def tearDownClass(cls):
        if cls.temp:
            cls.temp.cleanup()

    def run_client(self, name, fault=None):
        path = self.root / (name + ".strace")
        command = [self.strace, "-f", "-y", "-o", str(path), "-e",
                   "trace=ioctl,close,mmap,munmap,clock_gettime,futex,clone,exit_group"]
        if fault:
            command += ["-e", fault]
        command += [self.binary, "/sys", "/dev"]
        result = subprocess.run(command, capture_output=True, text=True, timeout=10,
                                stdin=subprocess.DEVNULL, check=False)
        (self.root / (name + ".stdout")).write_text(result.stdout)
        (self.root / (name + ".stderr")).write_text(result.stderr)
        (self.root / (name + ".command.json")).write_text(json.dumps(command))
        trace = completed_syscalls(path.read_text())
        lines = trace.splitlines()
        calls = [i for i, line in enumerate(lines) if "ioctl(" in line and "</dev/h1x-0>" in line]
        close = [i for i, line in enumerate(lines) if re.search(r'close\(\d+</dev/h1x-0>\)\s+= 0', line)]
        self.assertEqual(len(close), 1)
        allocations = []
        for line in lines[calls[4]:calls[7]]:
            match = re.search(r'mmap\(NULL, (\d+), PROT_READ\|PROT_WRITE, MAP_PRIVATE\|MAP_ANONYMOUS, -1, 0\) = (0x[0-9a-f]+)$', line)
            if match:
                allocations.append(match.groups())
        self.assertEqual(len(allocations), 2)
        for size, pointer in allocations:
            releases = [i for i, line in enumerate(lines) if i > calls[4] and re.search(r'munmap\(' + pointer + ', ' + size + r'\)\s+= 0', line)]
            self.assertEqual(len(releases), 1)
            self.assertGreater(releases[0], close[0])
        self.assertNotIn("LiveWorkerFatal", result.stdout + result.stderr)
        self.assertNotIn("SocWaitCancelFatal", result.stdout + result.stderr)
        self.assertNotIn("retaining storage", result.stdout + result.stderr)
        return result, trace

    def clean(self, name):
        result, trace = self.run_client(name)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        data = json.loads(result.stdout)
        for key in ("native_mojo_rpc", "create_identify_destroy", "closed"):
            self.assertIs(data[key], True)
        self.assertIs(data["model_loaded"], False)
        self.assertIs(data["llm_inference"], False)
        self.assertEqual(data["exchanges"], 3)
        self.assertEqual(data["input_completions"], 3)
        self.assertEqual(data["output_completions"], 3)
        self.assertGreaterEqual(data["irq_snapshots"], 3)
        self.assertLessEqual(data["irq_snapshots"], 96)
        self.assertEqual(data["last_input_descriptors"], 5)
        self.assertEqual(data["last_output_descriptors"], 5)
        self.assertEqual(data["architecture"], 6)
        self.assertEqual(data["protocol_version"], 2)
        self.assertEqual(data["firmware"], "5.3.0")
        counts = Counter(requests(trace))
        self.assertEqual(counts, Counter({INFO: 1, PROPS: 1, CREATE: 2, CONNECT: 1,
                          MAP: 2, SYNC: 12, ENABLE: 1, LAUNCH: 6, IRQ: data["irq_snapshots"],
                          DISABLE: 1, CLOSE: 1, UNMAP: 2, RELEASE: 2}))
        launches = [line for line in trace.splitlines() if "0xc, 0x8d)" in line]
        self.assertEqual(len(launches), 6)
        self.assertTrue(all(re.search(r'= 5$', line) for line in launches))
        return trace

    def failure(self, name, fault, code):
        result, trace = self.run_client(name, fault)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(code, result.stdout + result.stderr)
        self.assertIn("INJECTED", trace)
        self.assertNotIn("logical-device cleanup is unconfirmed", result.stdout + result.stderr)
        self.clean("after-" + name)
        return trace

    def test_eight_fresh_complete_device_lifecycles(self):
        for i in range(8):
            self.clean("normal-" + str(i))

    def test_each_pre_create_sync_enable_and_launch_failure(self):
        for when in range(8, 14):
            trace = self.failure("pre-create-failure-" + str(when),
                                 "inject=ioctl:error=EIO:when=" + str(when), "SocIoctlFailed")
            self.assertLessEqual(requests(trace).count(LAUNCH), 2)

    def test_wrong_positive_launch_counts_never_count_as_completion(self):
        for when in (12, 13):
            self.failure("wrong-positive-" + str(when),
                         "inject=ioctl:retval=4:when=" + str(when), "SocTransferCount")

    def test_missing_h2d_after_actual_d2h_post_times_out_and_quiesces(self):
        # Pretend TX launch returned 5 without entering it. The real posted RX
        # cannot receive a create reply. This is negative injection, not execution.
        trace = self.failure("missing-h2d", "inject=ioctl:retval=5:when=13", "SocWaitTimeout")
        self.assertIn("ETIMEDOUT", trace)
        self.assertEqual(requests(trace).count(LAUNCH), 2)

    def test_post_destroy_channel_close_unmap_and_release_errors(self):
        # Parent ioctl positions are fixed; wait-thread calls are separate.
        for when in range(28, 33):
            self.failure("post-destroy-cleanup-" + str(when),
                         "inject=ioctl:error=EIO:when=" + str(when), "SocCleanupFailed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True)
    parser.add_argument("--strace", required=True)
    parser.add_argument("--evidence-root")
    parser.add_argument("--hardware", action="store_true")
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
