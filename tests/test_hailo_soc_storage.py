#!/usr/bin/env python3
"""Physical storage lifetime proof with no DMA launch or model inference."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from test_hailo_soc_session import requests, INFO, PROPS, CREATE, RELEASE, CONNECT, CLOSE

CONFIG = argparse.Namespace()
MAP, UNMAP, SYNC = 0xC0207603, 0x80207604, 0x801C7605
PREFIX = [INFO, PROPS, CREATE, CREATE, CONNECT]
NORMAL = PREFIX + [MAP, MAP] + [SYNC] * 4 + [CLOSE, UNMAP, UNMAP, RELEASE, RELEASE]


class OwnedStorage(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not CONFIG.hardware:
            raise unittest.SkipTest("requires explicit --hardware")
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.unwind = str(Path(CONFIG.unwind_binary).resolve(strict=True))
        cls.strace = str(Path(CONFIG.strace).resolve(strict=True))
        cls.temp = None
        if CONFIG.evidence_root:
            cls.root = Path(CONFIG.evidence_root).resolve()
            cls.root.mkdir(parents=True, exist_ok=True)
        else:
            cls.temp = tempfile.TemporaryDirectory(prefix="aesir-storage-")
            cls.root = Path(cls.temp.name)

    @classmethod
    def tearDownClass(cls):
        if cls.temp:
            cls.temp.cleanup()

    def run_owner(self, name, fault=None, unwind=False):
        path = self.root / (name + ".strace")
        command = [self.strace, "-y", "-o", str(path), "-e",
                   "trace=openat,close,statx,ioctl,mmap,munmap"]
        if fault:
            command += ["-e", fault]
        command += [self.unwind if unwind else self.binary, "/sys", "/dev"]
        result = subprocess.run(command, capture_output=True, text=True,
                                timeout=10, stdin=subprocess.DEVNULL, check=False)
        (self.root / (name + ".stdout")).write_text(result.stdout)
        (self.root / (name + ".stderr")).write_text(result.stderr)
        trace = path.read_text()
        self.assertEqual(len(re.findall(r'close\(\d+</dev/h1x-0>\)\s+= 0', trace)), 1)
        # Every allocation made by this storage owner occurs after CONNECT and
        # before the fd closes. Match its actual returned pointer to munmap.
        lines = trace.splitlines()
        device_calls = [i for i, line in enumerate(lines) if "ioctl(" in line and "</dev/h1x-0>" in line]
        start = device_calls[4]
        end = next(i for i, line in enumerate(lines) if re.search(r'close\(\d+</dev/h1x-0>\)\s+= 0', line))
        allocations = []
        for i in range(start, end):
            match = re.fullmatch(r'mmap\(NULL, (\d+), PROT_READ\|PROT_WRITE, MAP_PRIVATE\|MAP_ANONYMOUS, -1, 0\) = (0x[0-9a-f]+)', lines[i])
            if match:
                allocations.append(match.groups())
        for size, pointer in allocations:
            releases = [i for i, line in enumerate(lines)
                        if i > start and re.fullmatch(r"munmap\(" + re.escape(pointer) + r", " + size + r"\)\s+= 0", line)]
            self.assertEqual(len(releases), 1, pointer)
            self.assertGreater(releases[0], end, "host pages released before driver fd finalization")
        self.assertNotIn("retaining storage", result.stdout + result.stderr)
        self.assertNotIn("implicit RPC storage munmap failed", result.stdout + result.stderr)
        self.assertNotIn(0x808D760C, requests(trace), "unexpected DMA launch")
        return result, trace, allocations

    def clean(self, name):
        result, trace, allocations = self.run_owner(name)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(requests(trace), NORMAL)
        data = json.loads(result.stdout)
        self.assertEqual(data["logical_size"], 2068)
        self.assertEqual(data["page_size"], 16384)
        self.assertEqual(data["allocation_size"], 16384)
        self.assertEqual(len(allocations), 2)
        self.assertNotEqual(data["input_mapping_handle"], data["output_mapping_handle"])
        for key in ("zero_initialized", "cpu_access_without_sync_refused", "closed_sync_refused", "live_mapping_release_refused", "storage_released"):
            self.assertIs(data[key], True)
        self.assertIs(data["user_dma_submitted"], False)
        return trace

    def fault(self, name, when, expected):
        result, trace, _ = self.run_owner(name, "inject=ioctl:error=EIO:when=" + str(when))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("(INJECTED)", trace)
        self.assertIn("HailbruError[Soc", result.stdout + result.stderr)
        self.assertEqual(requests(trace), expected)
        self.clean("after-" + name)

    def test_normal_and_repeat_close(self):
        for index in range(3):
            self.clean("normal-" + str(index))

    def test_each_uncertain_map_finalizes_context_before_storage(self):
        self.fault("input-map-failure", 6, PREFIX + [MAP, CLOSE, RELEASE, RELEASE])
        self.fault("output-map-failure", 7, PREFIX + [MAP, MAP, CLOSE, UNMAP, RELEASE, RELEASE])

    def test_successful_map_with_corrupt_reply_retains_actual_kernel_mapping(self):
        for which in (1, 2):
            result, trace, allocations = self.run_owner("corrupt-map-" + str(which), "inject=ioctl:poke_exit=@arg3=ff:when=" + str(5 + which))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("BadSocAbi", result.stdout + result.stderr)
            self.assertEqual(len(allocations), which)
            self.assertIn("= 0 (INJECTED: args)", trace)
            self.assertNotIn("error=", trace)
            self.assertEqual(requests(trace), PREFIX + [MAP] * which + [CLOSE] + ([UNMAP] if which == 2 else []) + [RELEASE, RELEASE])
            self.clean("after-corrupt-map-" + str(which))

    def test_each_sync_failure_preserves_cleanup(self):
        for when in range(8, 12):
            self.fault("sync-failure-" + str(when), when, NORMAL[:when] + NORMAL[11:])

    def test_close_failure_finalizes_file_before_host_memory(self):
        self.fault("close-failure", 12, NORMAL[:12])

    def test_each_unmap_failure_retains_memory_until_fd_close(self):
        for when in (13, 14):
            self.fault("unmap-failure-" + str(when), when, NORMAL)

    def test_exception_unwind_releases_both_mappings_and_pages(self):
        result, trace, allocations = self.run_owner("unwind", unwind=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(requests(trace), PREFIX + [MAP, MAP, CLOSE, UNMAP, UNMAP, RELEASE, RELEASE])
        self.assertEqual(len(allocations), 2)
        self.assertEqual(result.stdout.strip(), "expected storage exception caught")
        self.clean("after-unwind")

    def test_each_host_allocation_failure_keeps_ordered_cleanup(self):
        baseline = self.clean("allocation-baseline")
        lines = baseline.splitlines()
        connect_index = [i for i, line in enumerate(lines) if "ioctl(" in line and "</dev/h1x-0>" in line][4]
        calls = [i for i, line in enumerate(lines) if line.startswith("mmap(")]
        targets = [index + 1 for index, line_index in enumerate(calls) if line_index > connect_index]
        self.assertEqual(len(targets), 2)
        for which, ordinal in enumerate(targets):
            name = "allocation-failure-" + str(which)
            result, trace, allocations = self.run_owner(name, "inject=mmap:error=ENOMEM:when=" + str(ordinal))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("SocStorageFailed", result.stdout + result.stderr)
            self.assertIn("(INJECTED)", trace)
            self.assertEqual(len(allocations), which)
            expected = PREFIX + ([MAP] if which else []) + [CLOSE] + ([UNMAP] if which else []) + [RELEASE, RELEASE]
            self.assertEqual(requests(trace), expected)
            self.clean("after-" + name)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True)
    parser.add_argument("--unwind-binary", required=True)
    parser.add_argument("--strace", required=True)
    parser.add_argument("--evidence-root")
    parser.add_argument("--hardware", action="store_true")
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
