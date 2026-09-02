#!/usr/bin/env python3
"""Exercise the built CLI model catalog across independent processes."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import stat
import subprocess
import tempfile


def check(binary: str) -> None:
    def run(*arguments: str, ok: bool = True) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            [binary, *arguments],
            text=True,
            capture_output=True,
            timeout=30,
            check=False,
        )
        if ok and result.returncode != 0:
            raise AssertionError(result.stderr or result.stdout)
        if not ok and result.returncode == 0:
            raise AssertionError(f"command unexpectedly succeeded: {arguments!r}")
        return result

    # The configured store path is deliberately relative to the working
    # directory. Every subprocess gets a fresh process and reloads catalog.v1.
    with tempfile.TemporaryDirectory(prefix=".aesir-native-store-", dir=".") as directory:
        root = Path(directory).relative_to(Path.cwd())
        store = root / "store"
        config = root / "config.json"
        modelfile = root / "Modelfile"
        weights = root / "weights.bin"
        config.write_text(
            json.dumps({"storage": {"model_store_path": store.as_posix()}}, indent=2),
            encoding="utf-8",
        )
        modelfile.write_text(
            "FROM /models/example.gguf\n"
            "PARAMETER temperature 0.7\n"
            "SYSTEM Catalog integration evidence.\n",
            encoding="utf-8",
        )
        weights.write_bytes(b"content-addressed-model-fixture\n")
        common = ("--config", str(config))

        empty = json.loads(run("list", "--format", "json", *common).stdout)
        assert empty == [], "absent catalog did not read as empty"

        run("create", "example:v1", "--modelfile", str(modelfile), *common)
        catalog = store / "catalog.v1"
        assert catalog.is_file(), "create did not publish catalog.v1"
        if store.stat().st_dev == Path("/").stat().st_dev:
            assert stat.S_IMODE(store.stat().st_mode) == 0o700
            assert stat.S_IMODE(catalog.stat().st_mode) == 0o600

        listed = json.loads(run("list", "--format", "json", *common).stdout)
        assert [item["name"] for item in listed] == ["example:v1"]
        shown = json.loads(
            run("show", "example:v1", "--format", "json", *common).stdout
        )
        assert shown["name"] == "example:v1"
        assert shown["digest"].startswith("fnv1a64:")
        assert shown["size"] == 0 and shown["quantization"] == "unknown"

        imported = run(
            "create",
            "weighted:v1",
            "--modelfile",
            str(modelfile),
            "--model",
            str(weights),
            *common,
        )
        assert "sha256:" in imported.stdout and "size=32" in imported.stdout
        weighted = json.loads(
            run("show", "weighted:v1", "--format", "json", *common).stdout
        )
        assert weighted["digest"] == (
            "sha256:9b3737096a1813f0580908da7a52fd6f04a5da9c5e207ccdf2c0483c2db47d96"
        )
        assert weighted["size"] == 32
        verified = run("verify", "weighted:v1", *common)
        assert weighted["digest"] in verified.stdout and "size=32" in verified.stdout

        # Independent processes contend on the same directory lock. Each must
        # reload the preceding catalog commit, share the immutable blob, and
        # publish its own manifest without a lost update.
        concurrent = [
            subprocess.Popen(
                [
                    binary,
                    "create",
                    f"concurrent-{index}:v1",
                    "--modelfile",
                    str(modelfile),
                    "--model",
                    str(weights),
                    *common,
                ],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            for index in range(6)
        ]
        for process in concurrent:
            stdout, stderr = process.communicate(timeout=30)
            assert process.returncode == 0, stderr or stdout
        concurrent_names = {
            item["name"]
            for item in json.loads(run("list", "--format", "json", *common).stdout)
        }
        assert {
            f"concurrent-{index}:v1" for index in range(6)
        }.issubset(concurrent_names), "concurrent catalog commits lost an update"
        blobs = list((store / "blobs" / "sha256").iterdir())
        assert len(blobs) == 1, "identical concurrent imports were not deduplicated"

        run("cp", "example:v1", "example:backup", *common)
        run("rm", "example:v1", *common)
        restarted = json.loads(run("ls", "--format", "json", *common).stdout)
        restarted_names = {item["name"] for item in restarted}
        assert "example:backup" in restarted_names
        assert "example:v1" not in restarted_names
        missing = run("show", "example:v1", *common, ok=False)
        assert "not found" in missing.stderr + missing.stdout

        before = catalog.read_bytes()
        run("cp", "missing:v1", "never:created", *common, ok=False)
        assert catalog.read_bytes() == before, "failed mutation changed the catalog"
        assert not list(store.glob(".catalog.tmp.*")), "staged catalog leaked"
        assert not list((store / "blobs" / "sha256").glob(".ingest.*.tmp")), (
            "staged model blob leaked"
        )

        symlink = root / "linked-modelfile"
        symlink.symlink_to(modelfile.resolve())
        run(
            "create",
            "linked:v1",
            "--modelfile",
            str(symlink),
            *common,
            ok=False,
        )
        assert catalog.read_bytes() == before, "rejected input changed the catalog"

        blob = blobs[0]
        original = blob.read_bytes()
        blob.write_bytes(b"X" + original[1:])
        corrupted = run("verify", "weighted:v1", *common, ok=False)
        assert "SHA-256" in corrupted.stderr + corrupted.stdout
        blob.write_bytes(original)
        run("verify", "weighted:v1", *common)
        blob.unlink()
        missing_blob = run("verify", "weighted:v1", *common, ok=False)
        assert "missing" in missing_blob.stderr + missing_blob.stdout

    print(
        "PASS native model store: restart, JSON, create/show/cp/rm, "
        "blob digest/size, deduplication, concurrent commits, corruption, "
        "missing blobs, rollback, permissions and symlink rejection"
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    check(parser.parse_args().binary)
