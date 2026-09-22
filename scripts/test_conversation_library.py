#!/usr/bin/env python3
"""Separate-process tests for the named conversation library."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("conversations.py")


def fnv64(data: bytes) -> int:
    value = 14695981039346656037
    for byte in data:
        value = ((value ^ byte) * 1099511628211) & 0xFFFFFFFFFFFFFFFF
    return value


def hx(value: str) -> str:
    return value.encode().hex()


def snapshot(model: str = "sha256:model-one") -> bytes:
    payload = (
        "AESIR_CONVERSATION_V1\n"
        f"MODEL:{hx(model)}\n"
        f"PROFILE:{hx('llama3')}\n"
        "CONTEXT:512\n"
        f"SYSTEM:{hx('Remember the thread.')}\n"
        f"SAMPLING:{hx('greedy; seed=42')}\n"
        "DRAWS:1\n"
        "TOKENS:128000,9906,128009\n"
        "TURNS:1\n"
        f"USER:{hx('Halló, 世界')}\n"
        f"ASSISTANT:{hx('Still here.')}\n"
    ).encode()
    return payload + f"CHECKSUM:{fnv64(payload):016x}\n".encode()


class ConversationLibraryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="aesir-library-")
        self.root = Path(self.temporary.name)
        self.library = self.root / "library"
        self.source = self.root / "source.aesir"
        self.source.write_bytes(snapshot())

    def tearDown(self):
        self.temporary.cleanup()

    def run_cli(self, *arguments: str, expected: int = 0) -> str:
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--library", str(self.library), *arguments],
            text=True, capture_output=True, timeout=15, check=False,
        )
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result.stdout + result.stderr

    def test_restart_unicode_open_rename_and_export(self):
        self.run_cli("save", "Saga – 世界", "--snapshot", str(self.source))
        listed = json.loads(self.run_cli("list"))
        self.assertEqual([entry["name"] for entry in listed], ["Saga – 世界"])
        opened = json.loads(self.run_cli(
            "open", "Saga – 世界", "--expect-model", "sha256:model-one",
            "--expect-profile", "llama3", "--expect-context", "512",
        ))
        self.assertEqual(opened["turn_count"], 1)
        self.assertTrue(Path(opened["snapshot_path"]).is_file())
        self.run_cli("rename", "Saga – 世界", "Saga II – 世界")
        self.assertIn("Saga II – 世界", self.run_cli("list"))
        output = self.root / "export.md"
        self.run_cli("export", "Saga II – 世界", "--output", str(output))
        exported = output.read_text()
        self.assertIn("Halló, 世界", exported)
        self.assertIn("Still here.", exported)

    def test_duplicate_and_output_overwrite_refusal(self):
        self.run_cli("save", "same", "--snapshot", str(self.source))
        self.assertIn("already exists", self.run_cli(
            "save", "same", "--snapshot", str(self.source), expected=1,
        ))
        output = self.root / "existing.md"
        output.write_text("preserve\n")
        self.run_cli("export", "same", "--output", str(output), expected=1)
        self.assertEqual(output.read_text(), "preserve\n")

    def test_corruption_and_incompatible_model_refusal(self):
        self.run_cli("save", "bound", "--snapshot", str(self.source))
        self.assertIn("incompatible model", self.run_cli(
            "open", "bound", "--expect-model", "sha256:other", expected=1,
        ))
        entry = json.loads(self.run_cli("open", "bound"))
        Path(entry["snapshot_path"]).write_bytes(snapshot() + b"hidden")
        output = self.run_cli("list", expected=1)
        self.assertTrue("checksum" in output or "complete bounded record" in output)

    def test_metadata_type_corruption_is_rejected(self):
        self.run_cli("save", "typed", "--snapshot", str(self.source))
        entry = json.loads(self.run_cli("open", "typed"))
        metadata_path = Path(entry["snapshot_path"]).with_name("metadata.json")
        metadata = json.loads(metadata_path.read_text())
        metadata["name"] = 7
        metadata_path.write_text(json.dumps(metadata))
        self.assertIn("metadata types are invalid", self.run_cli("list", expected=1))

    def test_invalid_name_and_snapshot_rejection(self):
        self.assertIn("control", self.run_cli(
            "save", "bad\nname", "--snapshot", str(self.source), expected=1,
        ))
        corrupt = self.root / "corrupt.aesir"
        corrupt.write_bytes(snapshot().replace(b"MODEL:", b"MODEL:0", 1))
        self.assertIn("checksum", self.run_cli(
            "save", "corrupt", "--snapshot", str(corrupt), expected=1,
        ))


if __name__ == "__main__":
    unittest.main()
