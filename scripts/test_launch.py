#!/usr/bin/env python3
"""Isolated launch-plumbing tests; fake compiler/executable, not inference proof."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPT = Path(__file__).with_name("launch.py")
FAKE_PIXI = '''#!/usr/bin/python3
import json, os, pathlib, sys, time
assert sys.argv[1:8] == ["run", "--frozen", "--no-install", "--offline", "--executable", "mojo", "build"]
if os.environ.get("FAIL_BUILD"):
    sys.exit(17)
if os.environ.get("EDIT_BUILD"):
    pathlib.Path("aesir_engine/main.mojo").write_text("changed during build")
if os.environ.get("SLOW_BUILD"):
    pathlib.Path("compiler-started").write_text(str(os.getpid()))
    time.sleep(60)
output = pathlib.Path(sys.argv[sys.argv.index("-o") + 1])
output.write_text("#!/usr/bin/python3\\nimport json,os,sys\\nprint(json.dumps([os.getcwd(), sys.argv[1:]]))\\nsys.exit(7 if 'fail' in sys.argv else 0)\\n")
output.chmod(0o755)
'''


class LaunchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="aesir launch ' space ")
        self.root = Path(self.temp.name)
        (self.root / "scripts").mkdir()
        shutil.copyfile(SCRIPT, self.root / "scripts/launch.py")
        (self.root / "aesir_engine").mkdir()
        (self.root / "aesir_engine/main.mojo").write_text("source")
        (self.root / "pixi.toml").write_text("manifest")
        (self.root / "pixi.lock").write_text("lock")
        runtime = self.root / ".pixi/envs/default/bin"
        runtime.mkdir(parents=True)
        (runtime / "mojo").touch()
        lib = runtime.parent / "lib"
        lib.mkdir()
        for name in ("libKGENCompilerRTShared.so", "libAsyncRTMojoBindings.so",
                     "libMSupportGlobals.so", "libAsyncRTRuntimeGlobals.so"):
            (lib / name).touch()
        fake_bin = self.root / "fake bin"
        fake_bin.mkdir()
        pixi = fake_bin / "pixi"
        pixi.write_text(FAKE_PIXI)
        pixi.chmod(0o755)
        self.env = {**os.environ, "PATH": str(fake_bin), "HOME": str(self.root)}
        self.binary = self.root / ".aesir/launch/aesir"
        self.manifest = self.binary.with_name("manifest.json")

    def tearDown(self):
        self.temp.cleanup()

    def run_cli(self, *args, code=0, extra=None):
        result = subprocess.run([sys.executable, str(self.root / "scripts/launch.py"), *args],
                                cwd="/", env={**self.env, **(extra or {})},
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, code, result.stdout + result.stderr)
        return result.stdout + result.stderr

    def test_missing_build_and_runtime(self):
        self.assertIn("--build", self.run_cli("--check", code=1))
        self.assertFalse((self.root / ".aesir").exists())
        (self.root / ".pixi/envs/default/bin/mojo").unlink()
        self.assertIn("Mojo environment is missing", self.run_cli("--build", code=1))
        self.assertIn("Pixi is missing", self.run_cli("--build", code=1, extra={"PATH": "/nonexistent"}))

    def test_argv_and_exit_status_no_package_manager_at_launch(self):
        self.run_cli("--build")
        self.run_cli("--check")
        args = ["home", "--model-store", "store space ' $(touch should-not-exist);", 'quote"', "", "雪"]
        output = self.run_cli("--", *args, extra={"PATH": "/nonexistent"})
        self.assertEqual(json.loads(output), [str(self.root), args])
        self.run_cli("--", "fail", code=7)

    def test_source_changes_additions_deletions_and_corruption(self):
        self.run_cli("--build")
        source = self.root / "aesir_engine/extra.mojo"
        source.write_text("new")
        self.assertIn("stale", self.run_cli("--check", code=1))
        source.unlink()
        self.run_cli("--check")
        self.binary.write_bytes(self.binary.read_bytes() + b"# changed")
        self.assertIn("checksum mismatch", self.run_cli("--check", code=1))
        self.manifest.write_text("[]")
        self.assertIn("Unsupported", self.run_cli("--check", code=1))
        self.manifest.write_text("{")
        self.run_cli("--check", code=1)

    def test_failed_or_changed_build_preserves_previous(self):
        self.run_cli("--build")
        old = self.binary.read_bytes(), self.manifest.read_bytes()
        self.assertIn("exit 17", self.run_cli("--build", code=1, extra={"FAIL_BUILD": "1"}))
        self.assertEqual(old, (self.binary.read_bytes(), self.manifest.read_bytes()))
        self.assertIn("Source changed", self.run_cli("--build", code=1, extra={"EDIT_BUILD": "1"}))
        self.assertEqual(old, (self.binary.read_bytes(), self.manifest.read_bytes()))
        self.assertEqual(list(self.binary.parent.glob("staging-*")), [])

    def test_special_executable_fails_promptly(self):
        self.run_cli("--build")
        self.binary.unlink()
        os.mkfifo(self.binary)
        self.assertIn("Not a regular file", self.run_cli("--check", code=1))
        self.binary.unlink()
        self.binary.symlink_to("/dev/null")
        self.run_cli("--check", code=1)
        self.manifest.unlink()
        os.mkfifo(self.manifest)
        self.assertIn("Invalid launch manifest", self.run_cli("--check", code=1))

    def test_missing_runtime_and_permissions(self):
        self.run_cli("--build")
        self.binary.chmod(0o644)
        self.assertIn("permission", self.run_cli("--check", code=1))
        self.binary.chmod(0o755)
        (self.root / ".pixi/envs/default/lib/libKGENCompilerRTShared.so").unlink()
        self.assertIn("runtime library missing", self.run_cli("--check", code=1))

    def test_interruption_preserves_build_and_reaps_compiler(self):
        self.run_cli("--build")
        old = self.binary.read_bytes(), self.manifest.read_bytes()
        child = subprocess.Popen([sys.executable, str(self.root / "scripts/launch.py"), "--build"],
                                 env={**self.env, "SLOW_BUILD": "1"}, cwd=self.root,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
        try:
            marker = self.root / "compiler-started"
            deadline = time.monotonic() + 10
            while not marker.exists():
                self.assertLess(time.monotonic(), deadline)
                time.sleep(0.02)
            compiler_pid = int(marker.read_text())
            child.send_signal(signal.SIGINT)
            output = child.communicate(timeout=10)
            self.assertEqual(child.returncode, 130, output)
            self.assertFalse(Path(f"/proc/{compiler_pid}").exists())
            self.assertEqual(old, (self.binary.read_bytes(), self.manifest.read_bytes()))
            self.assertEqual(list(self.binary.parent.glob("staging-*")), [])
        finally:
            if child.poll() is None:
                os.killpg(child.pid, signal.SIGKILL)
                child.communicate()

    def test_concurrent_builds_publish_consistent_pair(self):
        command = [sys.executable, str(self.root / "scripts/launch.py"), "--build"]
        children = [subprocess.Popen(command, env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE) for _ in range(2)]
        for child in children:
            output = child.communicate(timeout=15)
            self.assertEqual(child.returncode, 0, output)
        self.run_cli("--check")

    def test_conflicting_options(self):
        for args in [("--build", "--check"), ("--check", "--", "home"),
                     ("--build", "--", "home"), ("--target", "bad")]:
            self.run_cli(*args, code=2)


if __name__ == "__main__":
    unittest.main()
