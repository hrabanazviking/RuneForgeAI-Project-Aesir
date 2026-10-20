#!/usr/bin/env python3
"""Host-only real pthread callback/deadline/lifetime proof. No device access."""
import argparse
import json
from pathlib import Path
import re
import platform
import subprocess
import sys
import tempfile
import time
import unittest

CONFIG = argparse.Namespace()


def completed_syscalls(trace):
    """Reassemble strace -f lines interleaved across real threads."""
    pending, lines = {}, []
    for line in trace.splitlines():
        tid, body = line.split(" ", 1)
        body = body.lstrip()
        if body.endswith("<unfinished ...>"):
            pending[tid] = body.removesuffix("<unfinished ...>").rstrip()
        elif body.startswith("<... ") and " resumed>" in body:
            lines.append(tid + " " + pending.pop(tid) + body.split(" resumed>", 1)[1])
        else:
            lines.append(line)
    return "\n".join(lines)



class BlockingWorker(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.strace = str(Path(CONFIG.strace).resolve(strict=True))
        cls.oracle = str(Path(CONFIG.oracle).resolve(strict=True))
        cls.temp = None
        if CONFIG.evidence_root:
            cls.root = Path(CONFIG.evidence_root).resolve()
            cls.root.mkdir(parents=True, exist_ok=True)
        else:
            cls.temp = tempfile.TemporaryDirectory(prefix="aesir-worker-")
            cls.root = Path(cls.temp.name)

    @classmethod
    def tearDownClass(cls):
        if cls.temp:
            cls.temp.cleanup()

    def run_worker(self, name, mode="normal", fault=None):
        path = self.root / (name + ".strace")
        command = [self.strace, "-f", "-y", "-o", str(path), "-e",
                   "trace=clone,clone3,read,write,close,futex,clock_gettime,exit_group,pipe2"]
        if fault:
            command += ["-e", fault]
        command += [self.binary, mode]
        start = time.monotonic()
        result = subprocess.run(command, capture_output=True, text=True,
                                timeout=10, stdin=subprocess.DEVNULL, check=False)
        elapsed = time.monotonic() - start
        trace = completed_syscalls(path.read_text())
        (self.root / (name + ".stdout")).write_text(result.stdout)
        (self.root / (name + ".stderr")).write_text(result.stderr)
        (self.root / (name + ".command.json")).write_text(json.dumps(command))
        self.assertNotIn("/dev/h1x-", trace)
        if mode != "abandon":
            pipe = re.search(r'pipe2\(\[\d+<pipe:\[(\d+)\]>, \d+<pipe:\[\1\]>\], O_CLOEXEC\)\s+= 0', trace)
            self.assertIsNotNone(pipe, trace)
            closes = re.findall(r'close\(\d+<pipe:\[' + pipe[1] + r'\]>\)\s+= 0', trace)
            self.assertEqual(len(closes), 2)
        return result, trace, elapsed

    def success(self, name, mode="normal"):
        result, trace, elapsed = self.run_worker(name, mode)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        data = json.loads(result.stdout)
        self.assertTrue(data["joined"])
        self.assertTrue(data["repeat_join_refused"])
        self.assertEqual(data["worker_threads_remaining"], 0)
        self.assertNotIn("LiveWorkerFatal", result.stdout + result.stderr)
        self.assertEqual(data["result"], -1 if mode == "read-error" else 1)
        self.assertEqual(data["errno"], 9 if mode == "read-error" else 0)
        self.assertEqual(data["payload"], 0 if mode == "read-error" else 165)
        return trace, elapsed

    def test_installed_pthread_and_time_abi(self):
        result = subprocess.run([self.oracle, "thread-layout"], capture_output=True,
                                text=True, timeout=10, check=True)
        self.assertEqual(json.loads(result.stdout), {
            "pthread_size": 8, "timespec_size": 16, "seconds_offset": 0,
            "nanos_offset": 8, "time_size": 8, "monotonic": 1,
            "timed_out": 110, "exit_group": 94 if platform.machine() == "aarch64" else 231})

    def test_callback_and_visibility_after_join_32_fresh_runs(self):
        for i in range(32):
            self.success("normal-" + str(i))

    def test_timeout_retains_live_owner_then_wake_join_and_cleanup(self):
        for i in range(8):
            trace, elapsed = self.success("timeout-" + str(i), "timeout")
            self.assertGreaterEqual(elapsed, 0.025)
            self.assertLess(elapsed, 2)
            self.assertIn("ETIMEDOUT", trace)
            self.assertIn("CLOCK_MONOTONIC", trace)

    def test_duplicate_start_and_invalid_deadline_preserve_worker(self):
        self.success("duplicate", "duplicate")
        self.success("invalid-deadline", "invalid-deadline")

    def test_worker_captures_its_own_syscall_errno(self):
        trace, _ = self.success("read-error", "read-error")
        self.assertIn("read(999999,", trace)
        self.assertIn("EBADF", trace)

    def test_failed_native_start_closes_pipe_without_live_worker(self):
        baseline, _ = self.success("start-failure-baseline")
        # Mojo initializes its runtime pool before main. Fault only our callback
        # thread, identified after the private pipe is created, not that pool.
        before_pipe, after_pipe = baseline.split("pipe2(", 1)
        self.assertEqual(len(re.findall(r"clone\(", after_pipe)), 1)
        ordinal = len(re.findall(r"clone\(", before_pipe)) + 1
        result, trace, _ = self.run_worker("start-failure", fault="inject=clone:error=EAGAIN:when=" + str(ordinal))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("WorkerStartFailed", result.stdout + result.stderr)
        self.assertIn("EAGAIN", trace)
        self.assertNotIn("LiveWorkerFatal", result.stdout + result.stderr)

    def test_clock_error_keeps_owner_until_rescue_wake_and_join(self):
        result, trace, _ = self.run_worker("clock-failure", mode="timeout", fault="inject=clock_gettime:error=EIO:when=1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("monotonic clock failed", result.stdout + result.stderr)
        self.assertIn("(INJECTED)", trace)
        self.assertNotIn("LiveWorkerFatal", result.stdout + result.stderr)

    def test_exception_rescues_blocked_worker_before_scope_exit(self):
        result, trace, _ = self.run_worker("unwind", "unwind")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("ExpectedWorkerUnwind", result.stdout + result.stderr)
        self.assertNotIn("LiveWorkerFatal", result.stdout + result.stderr)
        self.assertRegex(trace, r'read\([^\n]*pipe:[^\n]*= 0')

    def test_unrecoverable_live_destructor_fails_closed_whole_process(self):
        result, trace, elapsed = self.run_worker("abandon", "abandon")
        self.assertEqual(result.returncode, 123, result.stdout + result.stderr)
        self.assertIn("LiveWorkerFatal", result.stdout + result.stderr)
        self.assertIn("exit_group(123)", trace)
        self.assertLess(elapsed, 2)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True)
    parser.add_argument("--strace", required=True)
    parser.add_argument("--oracle", required=True)
    parser.add_argument("--evidence-root")
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
