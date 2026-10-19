#!/usr/bin/env python3
"""Check AESIR's real Hailo C ABI without starting inference.

Default checks use only invalid arguments/handles and never open a device.
--binary adds command line validation checks. --model-path explicitly opts into
opening the real accelerator model, describing it, and closing its session;
even this optional mode never calls generation on a live session.

Run from the repository root:
    python3 tests/test_hailo10h_boundary.py --binary work/aesir -v
    python3 tests/test_hailo10h_boundary.py --model-path artifacts/model.hef -v
"""

import argparse
import ctypes
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
INVALID_HANDLE = (1 << 64) - 1
CONFIG = argparse.Namespace(
    library=ROOT / "work" / "libaesir_hailo10h.so", binary=None, model_path=None,
)


def load_bridge(path):
    """Bind the installed bridge's exported ABI, without replacing its code."""
    bridge = ctypes.CDLL(str(Path(path).resolve()))
    bridge.aesir_hailo10h_open.argtypes = [
        ctypes.c_char_p, ctypes.POINTER(ctypes.c_uint64),
        ctypes.c_void_p, ctypes.c_size_t,
    ]
    bridge.aesir_hailo10h_open.restype = ctypes.c_int
    bridge.aesir_hailo10h_describe.argtypes = [
        ctypes.c_uint64, ctypes.c_void_p, ctypes.c_size_t,
        ctypes.c_void_p, ctypes.c_size_t,
    ]
    bridge.aesir_hailo10h_describe.restype = ctypes.c_int
    bridge.aesir_hailo10h_generate.argtypes = [
        ctypes.c_uint64, ctypes.c_char_p, ctypes.c_uint32, ctypes.c_uint32,
        ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(ctypes.c_size_t),
        ctypes.c_void_p, ctypes.c_size_t,
    ]
    bridge.aesir_hailo10h_generate.restype = ctypes.c_int
    bridge.aesir_hailo10h_clear_context.argtypes = [
        ctypes.c_uint64, ctypes.c_void_p, ctypes.c_size_t,
    ]
    bridge.aesir_hailo10h_clear_context.restype = ctypes.c_int
    bridge.aesir_hailo10h_close.argtypes = [ctypes.c_uint64]
    bridge.aesir_hailo10h_close.restype = ctypes.c_int
    bridge.aesir_hailo10h_free_text.argtypes = [ctypes.c_void_p]
    bridge.aesir_hailo10h_free_text.restype = None
    return bridge


class BoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bridge = load_bridge(CONFIG.library)

    def assert_error(self, status, error):
        self.assertNotEqual(status, 0)
        self.assertTrue(error.value, "native failure must explain the failure")

    def failed_generate(self, handle=INVALID_HANDLE, prompt=b"ignored",
                        max_tokens=1, timeout_ms=1,
                        null_output=False, null_length=False):
        output = ctypes.c_void_p(0x1234)
        length = ctypes.c_size_t(999)
        error = ctypes.create_string_buffer(256)
        status = self.bridge.aesir_hailo10h_generate(
            handle, prompt, max_tokens, timeout_ms,
            None if null_output else ctypes.byref(output),
            None if null_length else ctypes.byref(length), error, len(error),
        )
        self.assert_error(status, error)
        if not null_output:
            self.assertIsNone(output.value, "failure must not expose a stale text pointer")
        if not null_length:
            self.assertEqual(length.value, 0, "failure must not expose a stale length")

    def test_open_null_path_resets_handle_before_returning(self):
        handle = ctypes.c_uint64(INVALID_HANDLE)
        error = ctypes.create_string_buffer(256)
        status = self.bridge.aesir_hailo10h_open(
            None, ctypes.byref(handle), error, len(error),
        )
        self.assert_error(status, error)
        self.assertEqual(handle.value, 0)

    def test_open_null_handle_returns_before_allocating_device(self):
        error = ctypes.create_string_buffer(256)
        status = self.bridge.aesir_hailo10h_open(
            b"unused-model-path", None, error, len(error),
        )
        self.assert_error(status, error)

    def test_generate_rejects_invalid_arguments_and_clears_outputs(self):
        cases = [
            {"handle": 0},
            {"handle": INVALID_HANDLE},
            {"prompt": None},
            {"max_tokens": 0},
            {"timeout_ms": 0},
            {"null_output": True},
            {"null_length": True},
            {"null_output": True, "null_length": True},
        ]
        for case in cases:
            with self.subTest(case=case):
                self.failed_generate(**case)

    def test_describe_rejects_invalid_handles_and_buffers(self):
        output = ctypes.create_string_buffer(256)
        for handle, buffer, capacity in [
            (0, output, len(output)),
            (INVALID_HANDLE, output, len(output)),
            (INVALID_HANDLE, None, len(output)),
            (INVALID_HANDLE, output, 0),
        ]:
            with self.subTest(handle=handle, null_buffer=buffer is None,
                              capacity=capacity):
                error = ctypes.create_string_buffer(256)
                status = self.bridge.aesir_hailo10h_describe(
                    handle, buffer, capacity, error, len(error),
                )
                self.assert_error(status, error)

    def test_clear_context_rejects_invalid_handles(self):
        for handle in (0, INVALID_HANDLE):
            with self.subTest(handle=handle):
                error = ctypes.create_string_buffer(256)
                self.assert_error(self.bridge.aesir_hailo10h_clear_context(
                    handle, error, len(error),
                ), error)

    def test_close_is_idempotent_for_zero_and_unknown_handles(self):
        for handle in (0, INVALID_HANDLE):
            with self.subTest(handle=handle):
                for _ in range(3):
                    self.assertEqual(self.bridge.aesir_hailo10h_close(handle), 0)

    def test_free_null_text_is_safe(self):
        self.bridge.aesir_hailo10h_free_text(None)

    def test_error_capacity_bounds_and_nul_termination(self):
        for capacity in (0, 1, 2, 8, 32):
            with self.subTest(capacity=capacity):
                # The bytes after the advertised capacity must stay untouched.
                buffer = (ctypes.c_char * 64)(*([b"!"] * 64))
                status = self.bridge.aesir_hailo10h_clear_context(
                    INVALID_HANDLE, buffer, capacity,
                )
                self.assertNotEqual(status, 0)
                raw = bytes(buffer)
                self.assertEqual(raw[capacity:], b"!" * (64 - capacity))
                if capacity:
                    self.assertIn(b"\0", raw[:capacity])
                    if capacity > 1:
                        self.assertNotEqual(raw[0:1], b"\0")

    def test_null_error_buffers_are_safe(self):
        for capacity in (0, 32):
            with self.subTest(capacity=capacity):
                handle = ctypes.c_uint64(INVALID_HANDLE)
                self.assertNotEqual(self.bridge.aesir_hailo10h_open(
                    None, ctypes.byref(handle), None, capacity,
                ), 0)
                self.assertEqual(handle.value, 0)
                self.assertNotEqual(self.bridge.aesir_hailo10h_clear_context(
                    INVALID_HANDLE, None, capacity,
                ), 0)


class CommandLineValidationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if CONFIG.binary is None:
            raise unittest.SkipTest("--binary was not supplied")
        cls.binary = str(Path(CONFIG.binary).resolve())
        if not Path(cls.binary).is_file():
            raise FileNotFoundError(cls.binary)

    def run_cli(self, arguments):
        return subprocess.run(
            [self.binary, *arguments], input="", capture_output=True,
            text=True, timeout=15, cwd=ROOT, check=False,
        )

    def test_special_model_files_fail_before_device_allocation(self):
        with tempfile.TemporaryDirectory(prefix="aesir-hailo-admission-") as directory:
            root = Path(directory)
            fifo = root / "model.hef"
            os.mkfifo(fifo)
            empty = root / "empty.hef"
            empty.touch()
            link = root / "fifo-link.hef"
            link.symlink_to(fifo)
            for path in (fifo, link, empty, root):
                with self.subTest(kind=path.name):
                    result = self.run_cli([
                        "run", "--model-path", str(path), "--prompt", "not submitted",
                    ])
                    diagnostic = result.stdout + result.stderr
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("ModelArtifactRequired", diagnostic)
                    self.assertNotIn("VDevice::create_shared", diagnostic)
                    self.assertNotIn("LLM::create", diagnostic)

    def test_invalid_requests_fail_in_parser_before_opening_model(self):
        model = ["--model-path", "/aesir-test-unused-model.hef"]
        cases = [
            (["run"], "requires --model-path"),
            (["run", *model], "run requires nonempty"),
            (["run", *model, "--prompt", "  "], "run requires nonempty"),
            (["run", *model, "--prompt", "hello", "--accel", "cpu"], "--accel must be hailo10h"),
            (["run", *model, "--prompt", "hello", "--accel", "cuda"], "--accel must be hailo10h"),
            (["run", *model, "--prompt", "hello", "--max-tokens", "0"], "must be greater than zero"),
            (["run", *model, "--prompt", "hello", "--max-tokens", "-1"], "requires an integer"),
            (["run", *model, "--prompt", "hello", "--max-tokens", "4294967296"], "must not exceed 4294967295"),
            (["run", *model, "--prompt", "hello", "--timeout-ms", "0"], "must be greater than zero"),
            (["run", *model, "--prompt", "hello", "--timeout-ms", "4294967296"], "must not exceed 4294967295"),
            (["run", *model, "--prompt", "hello", "--format", "yaml"], "--format must be text or json"),
            (["run", *model, "--prompt", "hello", "--unknown"], "Unknown run option"),
            (["run", *model, "--prompt", "hello", "--prompt", "again"], "Duplicate option"),
            (["run", *model, "--prompt", "hello", "--max-tokens"], "requires a value"),
            (["hardware", *model, "--max-tokens", "1"], "is not a hardware option"),
            (["chat", *model, "--prompt", "hello"], "chat reads prompts from standard input"),
        ]
        for arguments, expected in cases:
            with self.subTest(arguments=arguments):
                result = self.run_cli(arguments)
                diagnostic = result.stdout + result.stderr
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(expected, diagnostic)
                self.assertNotIn("Direct Hailo-10H open failed", diagnostic)
                self.assertNotIn("VDevice::create_shared", diagnostic)
                self.assertNotIn("LLM::create", diagnostic)


class HardwareLifecycleTests(unittest.TestCase):
    assert_error = BoundaryTests.assert_error
    failed_generate = BoundaryTests.failed_generate

    @classmethod
    def setUpClass(cls):
        if CONFIG.model_path is None:
            raise unittest.SkipTest("--model-path was not supplied; no device is opened")
        cls.bridge = load_bridge(CONFIG.library)

    def test_real_model_identity_close_and_stale_handles(self):
        handle = ctypes.c_uint64(0)
        error = ctypes.create_string_buffer(2048)
        model = str(Path(CONFIG.model_path).resolve()).encode("utf-8")
        try:
            status = self.bridge.aesir_hailo10h_open(
                model, ctypes.byref(handle), error, len(error),
            )
            self.assertEqual(status, 0, error.value.decode("utf-8", errors="replace"))
            self.assertNotEqual(handle.value, 0)
            live_handle = handle.value
            output = ctypes.create_string_buffer(8192)
            status = self.bridge.aesir_hailo10h_describe(
                live_handle, output, len(output), error, len(error),
            )
            self.assertEqual(status, 0, error.value.decode("utf-8", errors="replace"))
            description = json.loads(output.value.decode("utf-8"))
            self.assertEqual(description["architecture"], "HAILO10H")
            self.assertEqual(description["backend"], "hailort-genai")
            self.assertTrue(description["device_id"])
            self.assertEqual(description["model_path"], model.decode("utf-8"))
            for key in ("runtime_version", "firmware_version"):
                self.assertRegex(description[key], r"^\d+\.\d+\.\d+$")
            self.assertGreater(description["context_capacity"], 0)
            self.assertGreaterEqual(description["context_usage"], 0)
            self.assertLessEqual(description["context_usage"], description["context_capacity"])

            self.assertEqual(self.bridge.aesir_hailo10h_close(live_handle), 0)
            handle.value = 0
            self.assertEqual(self.bridge.aesir_hailo10h_close(live_handle), 0)
            self.assert_error(self.bridge.aesir_hailo10h_describe(
                live_handle, output, len(output), error, len(error),
            ), error)
            self.assert_error(self.bridge.aesir_hailo10h_clear_context(
                live_handle, error, len(error),
            ), error)
            # The registry entry is already gone, so this never reaches LLM.
            self.failed_generate(handle=live_handle)
        finally:
            if handle.value:
                self.bridge.aesir_hailo10h_close(handle.value)


def main():
    global CONFIG
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--library", default=ROOT / "work" / "libaesir_hailo10h.so")
    parser.add_argument("--binary", help="enable invalid command line argument checks")
    parser.add_argument("--model-path", help="enable real model open/describe/close checks; no inference")
    CONFIG, unittest_arguments = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *unittest_arguments])


if __name__ == "__main__":
    main()
