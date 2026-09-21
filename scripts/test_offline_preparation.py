#!/usr/bin/env python3
"""Isolated contract tests for the offline preparation manifest workflow."""

from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("offline.py")
LIBRARIES = (
    "libKGENCompilerRTShared.so",
    "libAsyncRTMojoBindings.so",
    "libMSupportGlobals.so",
    "libAsyncRTRuntimeGlobals.so",
)
FAKE_LAUNCH = r'''#!/usr/bin/env python3
import hashlib, json, os, pathlib, shutil, sys
root = pathlib.Path(__file__).resolve().parent.parent
build = root / ".aesir/launch"
if "--build" in sys.argv:
    build.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / "fake_aesir.py", build / "aesir")
    (build / "aesir").chmod(0o755)
    digest = hashlib.sha256((build / "aesir").read_bytes()).hexdigest()
    (build / "manifest.json").write_text(json.dumps({"schema": 1, "source": "a" * 64, "binary": digest, "target": "sm_89"}))
    sys.exit(0)
if "--check" in sys.argv and (build / "aesir").is_file():
    sys.exit(0)
sys.exit(1)
'''
FAKE_AESIR = r'''#!/usr/bin/env python3
import hashlib, json, pathlib, sys
root = pathlib.Path(__file__).resolve().parents[2]
store = root / "model-store"
blob = store / "alpha.blob"
payload = blob.read_bytes() if blob.is_file() else b"alpha-model"
record = {"name": "alpha:latest", "digest": "sha256:" + hashlib.sha256(payload).hexdigest(), "size": len(payload)}
command = sys.argv[1]
if command == "list":
    print(json.dumps([record]))
elif command == "verify":
    if sys.argv[2] != record["name"] or not blob.is_file():
        print("model bytes missing", file=sys.stderr)
        sys.exit(4)
elif command == "run":
    (root / "inference-ran").write_text(sys.argv[-1])
    print("OK")
else:
    sys.exit(3)
'''


class OfflinePreparationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="aesir-offline-")
        self.root = Path(self.temporary.name)
        (self.root / "scripts").mkdir()
        shutil.copyfile(SCRIPT, self.root / "scripts/offline.py")
        (self.root / "scripts/launch.py").write_text(FAKE_LAUNCH)
        (self.root / "fake_aesir.py").write_text(FAKE_AESIR)
        (self.root / "pixi.lock").write_text("locked\n")
        mojo = self.root / ".pixi/envs/default/bin/mojo"
        mojo.parent.mkdir(parents=True)
        mojo.write_text("compiler\n")
        libraries = mojo.parent.parent / "lib"
        libraries.mkdir()
        for name in LIBRARIES:
            (libraries / name).write_text(name + "\n")
        store = self.root / "model-store"
        store.mkdir()
        (store / "alpha.blob").write_bytes(b"alpha-model")
        (self.root / "aesir.config.json").write_text(json.dumps({"storage": {"model_store_path": "model-store"}}))
        tools = self.root / "tools"
        tools.mkdir()
        pixi = tools / "pixi"
        pixi.write_text("#!/bin/sh\necho 'pixi 9.9.9'\n")
        pixi.chmod(0o755)
        self.environment = {**os.environ, "PATH": str(tools) + os.pathsep + os.environ.get("PATH", "")}

    def tearDown(self):
        self.temporary.cleanup()

    def run_cli(self, *arguments: str, expected: int = 0) -> str:
        result = subprocess.run(
            [sys.executable, str(self.root / "scripts/offline.py"), *arguments],
            cwd=self.root,
            env=self.environment,
            text=True,
            capture_output=True,
            timeout=30,
            check=False,
        )
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result.stdout + result.stderr

    def prepare(self) -> dict[str, object]:
        output = self.run_cli(
            "prepare", "--model", "alpha:latest", "--model-store", "model-store",
            "--minimum-free-bytes", "0",
        )
        self.assertIn("Pinned models: alpha:latest", output)
        return json.loads((self.root / ".aesir/offline-preparation.v1.json").read_text())

    def test_prepare_check_rebuild_and_inference(self):
        manifest = self.prepare()
        self.assertEqual(manifest["schema"], 1)
        self.assertEqual(manifest["source_fingerprint"], "a" * 64)
        self.assertEqual(manifest["models"][0]["name"], "alpha:latest")
        self.assertEqual(manifest["capacity"]["model_bytes"], len(b"alpha-model"))
        output = self.run_cli("check", "--rebuild", "--inference", "--prompt", "offline proof")
        self.assertIn("Offline preparation check passed", output)
        self.assertEqual((self.root / "inference-ran").read_text(), "offline proof")

    def test_missing_artifacts_are_named_together(self):
        self.prepare()
        (self.root / ".pixi/envs/default/bin/mojo").unlink()
        (self.root / "model-store/alpha.blob").unlink()
        output = self.run_cli("check", expected=1)
        self.assertIn("file:mojo", output)
        self.assertIn("model:alpha:latest", output)

    def test_prepare_names_missing_requested_model(self):
        output = self.run_cli(
            "prepare", "--model", "beta:latest", "--model-store", "model-store",
            "--minimum-free-bytes", "0", expected=1,
        )
        self.assertIn("missing model artifacts: beta:latest", output)

    def test_manifest_and_file_tampering_fail_closed(self):
        self.prepare()
        binary = self.root / ".aesir/launch/aesir"
        binary.write_bytes(binary.read_bytes() + b"\n# tampered\n")
        output = self.run_cli("check", expected=1)
        self.assertIn("file:aesir", output)
        manifest = self.root / ".aesir/offline-preparation.v1.json"
        manifest.write_text("[]")
        self.assertIn("unsupported offline preparation manifest", self.run_cli("check", expected=1))


if __name__ == "__main__":
    unittest.main()
