# prof/armvegr/test_cpu_smoke.py
# H058 — CPU smoke test (TEST-ONLY, PRÓF).
#
# Generates a seeded tiny random GGUF, builds tests/c3_h058_smoke.mojo, runs
# 20 sampler steps through it with crash detection (timeout + return code),
# and validates the perf JSON. Fails (non-zero exit) on crash or bad output.
#
# Usage: python3 prof/armvegr/test_cpu_smoke.py  (run from repo root)

import json
import os
import random
import struct
import subprocess
import sys
import time

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GGUF_PATH = "/tmp/c3_smoke_tiny.gguf"
SMOKE_SRC = os.path.join(REPO, "tests", "c3_h058_smoke.mojo")
SMOKE_BIN = "/tmp/c3_h058_smoke"
MOJO = os.path.expanduser("~/.pixi/bin/pixi")
MOJO_MANIFEST = os.path.expanduser("~/mimisbrunnr-x86/mojo_xcompile/pixi.toml")


def make_tiny_gguf(path, seed=0xC0FFEE):
    """Seeded tiny GGUF (v3, F32) with a few tensors. Valid header + tensors."""
    rng = random.Random(seed)
    # Minimal v3 header.
    out = bytearray()
    out += b"GGUF"  # magic
    out += struct.pack("<I", 3)  # version
    out += struct.pack("<Q", 2)  # n_tensors
    out += struct.pack("<Q", 1)  # n_kv (metadata)
    # Metadata: one KV (general.architecture = "smoke").
    k = b"general.architecture"
    out += struct.pack("<Q", len(k)) + k
    out += struct.pack("<I", 8)  # type: string
    v = b"smoke"
    out += struct.pack("<Q", len(v)) + v
    # Tensor infos.
    tensors = []
    for name, dims in [(b"tok_embd.weight", [16, 8]), (b"blk0.attn.weight", [8, 8])]:
        nels = 1
        for d in dims:
            nels *= d
        tensors.append((name, dims, nels))
    offset = 0
    for name, dims, nels in tensors:
        out += struct.pack("<Q", len(name)) + name
        out += struct.pack("<I", len(dims))
        for d in dims:
            out += struct.pack("<Q", d)
        out += struct.pack("<I", 0)  # dtype F32
        out += struct.pack("<Q", offset)
        offset += nels * 4
    # Alignment padding.
    while len(out) % 32 != 0:
        out += b"\x00"
    # Tensor data.
    for name, dims, nels in tensors:
        for _ in range(nels):
            out += struct.pack("<f", rng.uniform(-1.0, 1.0))
    open(path, "wb").write(bytes(out))
    print(f"Tiny GGUF: {path} ({len(out)} bytes)")


def build():
    env = dict(os.environ)
    env["TMPDIR"] = os.path.expanduser("~/.tmp")
    r = subprocess.run(
        [MOJO, "run", "--manifest-path", MOJO_MANIFEST, "mojo",
         "build", "-I", REPO, "-o", SMOKE_BIN, SMOKE_SRC],
        cwd=REPO, env=env, capture_output=True, text=True, timeout=300,
    )
    if r.returncode != 0 or not os.path.exists(SMOKE_BIN):
        print("BUILD FAILED")
        print(r.stdout[-2000:])
        print(r.stderr[-2000:])
        sys.exit(2)
    print("Smoke binary built.")


def main():
    make_tiny_gguf(GGUF_PATH)
    build()
    t0 = time.time()
    try:
        proc = subprocess.run(
            [SMOKE_BIN, GGUF_PATH],
            capture_output=True, text=True, cwd=REPO, timeout=120,
        )
    except subprocess.TimeoutExpired:
        print("H058-FAIL: timeout (hang/crash)")
        sys.exit(1)
    dt = time.time() - t0
    if proc.returncode != 0:
        print(f"H058-FAIL: crash (exit {proc.returncode})")
        print(proc.stdout[-2000:])
        print(proc.stderr[-2000:])
        sys.exit(1)
    # Find SMOKE_JSON line.
    payload = None
    for line in proc.stdout.split("\n"):
        if line.startswith("SMOKE_JSON"):
            payload = json.loads(line[len("SMOKE_JSON "):])
            break
    if payload is None:
        print("H058-FAIL: no SMOKE_JSON in output")
        print(proc.stdout[-2000:])
        sys.exit(1)
    if payload.get("status") != "ok" or payload.get("generated_tokens") != 20:
        print("H058-FAIL: bad payload", payload)
        sys.exit(1)
    perf = {
        "test": "cpu_smoke",
        "tensors": payload["tensors"],
        "prompt_tokens": payload["prompt_tokens"],
        "generated_tokens": payload["generated_tokens"],
        "wall_seconds": round(dt, 3),
        "status": "ok",
    }
    print("H058-ALL-PASS")
    print("PERF_JSON " + json.dumps(perf))


if __name__ == "__main__":
    main()
