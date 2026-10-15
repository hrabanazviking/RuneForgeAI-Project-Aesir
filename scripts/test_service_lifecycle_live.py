#!/usr/bin/env python3
"""Opt-in S22 lifecycle probe using installed weights and test-owned stores.

No model download/copy. A hardlink pins the installed blob in a temporary
catalog; this script never changes the operator's catalog or service records.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time


def run(binary, *args, expected=0):
    result = subprocess.run([binary, *map(str, args)], capture_output=True,
                            text=True, timeout=45)
    assert (result.returncode == 0) == (expected == 0), (args, result.stdout, result.stderr)
    return result


def catalog_digest(catalog, model):
    for line in catalog.splitlines():
        if not line.startswith("ENTRY:"):
            continue
        fields = dict(row.split(":", 1) for row in bytes.fromhex(line[6:]).decode().splitlines()
                      if ":" in row)
        if fields.get("NAME", "") + ":" + fields.get("TAG", "") == model:
            return fields["DIGEST"]
    raise AssertionError(f"model {model} is absent from source catalog")


def probe_mode(binary, model, original_store, mode):
    catalog = (original_store / "catalog.v1").read_text(encoding="utf-8")
    digest = catalog_digest(catalog, model)
    original_blob = original_store / "blobs" / "sha256" / digest[7:]
    assert original_blob.is_file()
    with (tempfile.TemporaryDirectory(prefix="aesir-s22-", dir=original_store.parent) as directory,
          tempfile.TemporaryDirectory(prefix="aesir-s22-key-") as key_directory):
        root = Path(directory)
        store = root / "models"
        blob = store / "blobs" / "sha256" / digest[7:]
        blob.parent.mkdir(parents=True)
        # Keep every catalog reference valid without copying any weight bytes.
        for line in catalog.splitlines():
            if not line.startswith("ENTRY:"):
                continue
            fields = dict(row.split(":", 1) for row in bytes.fromhex(line[6:]).decode().splitlines()
                          if ":" in row)
            listed_digest = fields.get("DIGEST", "")
            if listed_digest.startswith("sha256:"):
                source = original_store / "blobs" / "sha256" / listed_digest[7:]
                assert source.is_file(), f"catalog blob is missing: {listed_digest}"
                destination = blob.parent / listed_digest[7:]
                if not destination.exists():
                    os.link(source, destination)
        (store / "catalog.v1").write_text(catalog, encoding="utf-8")
        store_arg = store.relative_to(Path.cwd())
        runtime_record = (Path("/tmp") / f"aesir-runtime-{os.geteuid()}" /
                          f"service-{store.stat().st_dev}-{store.stat().st_ino}.v1")
        assert not runtime_record.exists(), "refusing to reuse a test runtime record"
        key_path = Path(key_directory) / "key"
        if mode != "ollama":
            run(binary, "keygen", key_path)
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        target = str(blob.relative_to(Path.cwd())) if mode == "direct" else model
        command = [binary, "serve", target, "--accel", "cuda", "--port", str(port),
                   "--model-store", str(store_arg), "--context", "512",
                   "--max-tokens", "16"]
        command += ["--ollama"] if mode == "ollama" else ["--api-key-file", str(key_path)]
        log_path = root / "service.log"
        try:
            with log_path.open("wb") as log:
                process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
                try:
                    deadline = time.monotonic() + 120
                    while b"inference ready" not in log_path.read_bytes():
                        assert process.poll() is None, log_path.read_text(errors="replace")
                        assert time.monotonic() < deadline, "service startup deadline"
                        time.sleep(.1)
                    listing = json.loads(run(binary, "ps", "--model-store", store_arg,
                                             "--format", "json").stdout)
                    assert len(listing["services"]) == 1, listing
                    entry = listing["services"][0]
                    assert entry["pid"] == process.pid and entry["model"] == target
                    assert entry["mode"] == ("ollama" if mode == "ollama" else "native") and entry["port"] == port
                    wrong = run(binary, "stop", "wrong-model", "--model-store", store_arg,
                                expected=1)
                    assert "requested model is not the owned resident service" in wrong.stdout + wrong.stderr
                    assert process.poll() is None
                    run(binary, "rm", model, "--model-store", store_arg)
                    run(binary, "gc", "--model-store", store_arg)
                    assert blob.is_file(), "GC unlinked a leased resident blob"
                    run(binary, "stop", target, "--model-store", store_arg)
                    process.wait(timeout=30)
                    assert json.loads(run(binary, "ps", "--model-store", store_arg,
                                          "--format", "json").stdout) == {"schema_version": 1, "services": []}
                    run(binary, "gc", "--model-store", store_arg)
                    assert not blob.exists(), "GC retained an unleased orphan blob"
                    stopped = run(binary, "stop", target, "--model-store", store_arg,
                                  expected=1)
                    assert "no live service owns this model store" in stopped.stdout + stopped.stderr
                    # Simulate a stale PID whose number now denotes another
                    # process while an unrelated holder locks the old record.
                    if mode == "native":
                        unrelated = subprocess.Popen(["sleep", "30"])
                        try:
                            with runtime_record.open("r+") as record:
                                fcntl.flock(record, fcntl.LOCK_EX)
                                lines = record.read().splitlines()
                                assert lines[0] == "AESIR_SERVICE_V1"
                                lines[1] = str(unrelated.pid)
                                record.seek(0)
                                record.write("\n".join(lines) + "\n")
                                record.truncate()
                                record.flush()
                                stale = run(binary, "stop", target, "--model-store", store_arg,
                                            expected=1)
                                assert "service process identity changed" in stale.stdout + stale.stderr
                                assert unrelated.poll() is None, "stale PID killed an unrelated process"
                        finally:
                            unrelated.terminate()
                            unrelated.wait(timeout=10)
                    print(f"PASS {mode}: ps/stop identity, wrong-target refusal, resident GC lease, stale PID refusal")
                finally:
                    if process.poll() is None:
                        process.terminate()
                        process.wait(timeout=30)
        finally:
            if runtime_record.exists():
                runtime_record.unlink()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--store", type=Path, required=True)
    options = parser.parse_args()
    for mode in ("native", "ollama", "direct"):
        probe_mode(options.binary, options.model, options.store, mode)


if __name__ == "__main__":
    main()
