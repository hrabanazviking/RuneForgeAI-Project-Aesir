#!/usr/bin/env python3
"""Built-CLI diagnostic regression; uses isolated stores and no inference."""

import argparse
import json
from pathlib import Path
import subprocess
import struct
import tempfile


def check(binary: str) -> None:
    binary = str(Path(binary).resolve())
    with tempfile.TemporaryDirectory(prefix="aesir-doctor-") as directory:
        root = Path(directory)

        def run(*args: str, ok: bool = True) -> str:
            result = subprocess.run(
                [binary, *args], cwd=root, capture_output=True, text=True,
                timeout=60, check=False,
            )
            assert (result.returncode == 0) == ok, result.stderr or result.stdout
            return result.stdout

        empty = run("doctor", "--model-store", "store")
        assert "SYSTEM NEEDS ATTENTION" in empty
        assert "model execution not tested" in empty
        (root / "config.json").write_text(
            json.dumps({"storage": {"model_store_path": "store"}}), encoding="utf-8"
        )
        (root / "Modelfile").write_text("FROM example.gguf\n", encoding="utf-8")
        run("create", "recipe:v1", "--modelfile", "Modelfile", "--config", "config.json")
        recipe = run("doctor", "--model-store", "store")
        rows = recipe.splitlines()
        assert any(row.startswith("Recipe-only entries") and row.endswith("1") for row in rows)
        assert any(row.startswith("Installed weights") and row.endswith("0") for row in rows)
        assert "SYSTEM NEEDS ATTENTION" in recipe, recipe
        def report(*args: str) -> dict:
            data = json.loads(run("doctor", *args, "--model-store", "store", "--format", "json"))
            assert data["schema_version"] == 1
            assert data["scope"] == "cuda_storage_prerequisites"
            assert data["execution_tested"] is False
            assert data["network_probed"] is False
            assert data["api"]["endpoints_probed"] is False
            assert all(set(issue) == {"code", "action"} for issue in data["issues"])
            return data

        data = report()
        assert not data["ready"] and data["model"] is None
        assert data["store"]["installed_count"] == 0
        assert data["store"]["recipe_count"] == 1
        assert "no_installed_weights" in {issue["code"] for issue in data["issues"]}
        absent = json.loads(run("doctor", "--model-store", "absent", "--format", "json"))
        assert not absent["ready"] and absent["store"]["model_count"] == 0
        assert absent["disk"]["observed_path"] == "."
        missing = report('missing"model')
        assert missing["model"]["reference"] == 'missing"model'
        assert missing["model"]["inspection_ok"] is False
        assert missing["model"]["result"] is None and missing["model"]["error"]
        assert "Inspection failed:" in run("doctor", 'missing"model', "--model-store", "store")

        def gguf_string(value: str) -> bytes:
            encoded = value.encode("utf-8")
            return struct.pack("<Q", len(encoded)) + encoded

        # A metadata-only synthetic file is inspectable but not executable.
        payload = struct.pack("<4sIQQ", b"GGUF", 3, 0, 1)
        payload += gguf_string("general.name") + struct.pack("<I", 8)
        payload += gguf_string('Rune ✓ æ 🛠 "fixture"')
        payload += bytes((-len(payload)) % 32)
        (root / "metadata.gguf").write_bytes(payload)
        inspected = report("./metadata.gguf")
        assert inspected["model"]["inspection_ok"]
        assert inspected["model"]["error"] is None
        assert inspected["model"]["result"]["name"] == 'Rune ✓ æ 🛠 "fixture"'
        standalone = json.loads(run("inspect", "./metadata.gguf", "--format", "json"))
        assert standalone == inspected["model"]["result"]
        assert not standalone["cuda_support"]

        (root / "weights.bin").write_bytes(b"not-a-gguf-but-trusted-local-bytes\n")
        run("create", "weighted:v1", "--modelfile", "Modelfile", "--model", "weights.bin",
            "--config", "config.json")
        intact = report("weighted:v1")
        assert intact["store"]["installed_count"] == 1
        assert intact["store"]["broken_count"] == 0
        assert not intact["model"]["inspection_ok"]  # Hash integrity is not GGUF compatibility.
        text = run("doctor", "--model-store", "store")
        assert ("SYSTEM READY" in text) == intact["ready"]
        blobs = list((root / "store" / "blobs" / "sha256").iterdir())
        assert len(blobs) == 1
        blobs[0].unlink()  # Only this harness's temporary fixture, not user data.
        broken = report()
        assert not broken["ready"] and broken["store"]["broken_count"] == 1
        assert len(broken["store"]["broken_models"]) == 1
        (root / "store" / "catalog.v1").write_text("corrupt\n", encoding="utf-8")
        corrupt = report()
        assert not corrupt["ready"] and not corrupt["store"]["readable"]
        assert corrupt["store"]["model_count"] is None
        assert corrupt["store"]["installed_count"] is None
        assert "store_unreadable" in {issue["code"] for issue in corrupt["issues"]}
        for args in [("--model-store", ""), ("--model-store", "../unsafe"),
                     ("--model-store",), ("--model-store", "a", "--model-store", "b"),
                     ("--format",), ("--format", "yaml"),
                     ("--format", "json", "--format", "text"), ("--unknown",)]:
            assert "Project Aesir Diagnostic" not in run("doctor", *args, ok=False)
    print("PASS: doctor text/JSON readiness, counts, model errors, corrupt/missing blobs and strict arguments")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    check(parser.parse_args().binary)
