#!/usr/bin/env python3
"""J-076 MTP census: GGUF header + tensor-directory inspection only.

Reads, for each listed file, ONLY the GGUF metadata block and the
tensor directory (names, dims, types, offsets) -- never tensor data,
never runs a model. Computes each file's sha256 by streaming (the
pin), then classifies prediction-head evidence mechanically:

  tensor-name patterns (lowercase substring, Aesir-local rules --
  the same rules core/mtp_census.mojo implements):
    "nextn"     -> NEXTN  (next-layer / next-token prediction block)
    "mtp"       -> MTP    (multi-token prediction block)
    "assistant" -> ASSISTANT (assistant-drafter tensors in-file)
  metadata keys containing "nextn" or "mtp" are filed as metadata
  evidence beside the tensor evidence.

Verdicts per file: WITH_MTP (any pattern hit in the directory),
NO_MTP (full directory read, zero hits), VOCAB_ONLY (zero tensors
in the directory -- the directory is empty, so no head can hide in
it, and the file is not a model file at all).

Run: j076_mtp_census.py -> JSON on stdout, one record per file,
in the stated census order. Deterministic: same files, same output.
"""
import hashlib
import json
import os
import struct
import sys

PATTERNS = (("nextn", "NEXTN"), ("mtp", "MTP"), ("assistant", "ASSISTANT"))


class R:
    def __init__(self, f):
        self.f = f

    def u32(self):
        return struct.unpack("<I", self.f.read(4))[0]

    def u64(self):
        return struct.unpack("<Q", self.f.read(8))[0]

    def s(self):
        n = self.u64()
        return self.f.read(n)


def read_value(r, t):
    if t == 0:
        return struct.unpack("<B", r.f.read(1))[0]
    if t == 1:
        return struct.unpack("<b", r.f.read(1))[0]
    if t == 2:
        return struct.unpack("<H", r.f.read(2))[0]
    if t == 3:
        return struct.unpack("<h", r.f.read(2))[0]
    if t == 4:
        return r.u32()
    if t == 5:
        return struct.unpack("<i", r.f.read(4))[0]
    if t == 6:
        return struct.unpack("<f", r.f.read(4))[0]
    if t == 7:
        return bool(struct.unpack("<B", r.f.read(1))[0])
    if t == 8:
        return r.s()
    if t == 10:
        return r.u64()
    if t == 11:
        return struct.unpack("<q", r.f.read(8))[0]
    if t == 12:
        return struct.unpack("<d", r.f.read(8))[0]
    if t == 9:
        et = r.u32()
        n = r.u64()
        if et == 8:  # string array: skip values, keep the count
            for _ in range(n):
                r.s()
            return {"array_of": "string", "len": n}
        return [read_value(r, et) for _ in range(n)]
    raise ValueError(f"bad meta type {t}")


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(8 * 1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def census_file(path):
    size = os.path.getsize(path)
    with open(path, "rb") as f:
        r = R(f)
        magic = f.read(4)
        if magic != b"GGUF":
            return {"path": path, "error": f"bad magic {magic!r}"}
        version = r.u32()
        n_tensors = r.u64()
        n_kv = r.u64()
        meta = {}
        for _ in range(n_kv):
            key = r.s().decode("utf-8", "replace")
            meta[key] = read_value(r, r.u32())
        names = []
        for _ in range(n_tensors):
            name = r.s().decode("utf-8", "replace")
            nd = r.u32()
            for _ in range(nd):
                r.u64()
            r.u32()  # type
            r.u64()  # offset
            names.append(name)
    hits = []
    for name in names:
        low = name.lower()
        for pat, kind in PATTERNS:
            if pat in low:
                hits.append({"tensor": name, "pattern": pat, "kind": kind})
                break
    meta_hits = sorted(
        k for k in meta if "nextn" in k.lower() or "mtp" in k.lower()
    )
    arch = meta.get("general.architecture")
    if isinstance(arch, bytes):
        arch = arch.decode("utf-8", "replace")
    if n_tensors == 0:
        verdict = "VOCAB_ONLY"
    elif hits or meta_hits:
        verdict = "WITH_MTP"
    else:
        verdict = "NO_MTP"
    return {
        "path": path,
        "bytes": size,
        "sha256": sha256_of(path),
        "gguf_version": version,
        "arch": arch,
        "n_kv": n_kv,
        "n_tensors": n_tensors,
        "mtp_hits": hits,
        "mtp_hit_count": len(hits),
        "meta_mtp_keys": meta_hits,
        "verdict": verdict,
    }


CENSUS_FILES = [
    # The wave's VM-present ladder (zen-4b-i1 = the Qwen3-4B family
    # file of J-074's first pair; arch qwen3).
    "/home/hatch/workspace/model-tests/wave/zen-4b-i1/zen-4b.i1-IQ1_S.gguf",
    "/home/hatch/workspace/model-tests/wave/zen-4b-i1/zen-4b.i1-IQ2_M.gguf",
    "/home/hatch/workspace/model-tests/wave/zen-4b-i1/zen-4b.i1-Q2_K.gguf",
    "/home/hatch/workspace/model-tests/wave/zen-4b-i1/zen-4b.i1-Q3_K_M.gguf",
    "/home/hatch/workspace/model-tests/wave/zen-4b-i1/zen-4b.i1-Q4_K_M.gguf",
    "/home/hatch/workspace/model-tests/wave/zen-4b-i1/zen-4b.i1-Q5_K_M.gguf",
    "/home/hatch/workspace/model-tests/wave/zen-4b-i1/zen-4b.i1-Q6_K.gguf",
    # The one non-wave full file on the VM (Llama family witness).
    "/home/hatch/workspace/tinyllama.Q4_0.gguf",
]

VOCAB_DIR = "/home/hatch/workspace/model-tests/tools/llama.cpp/models"


def main():
    files = list(CENSUS_FILES)
    if os.path.isdir(VOCAB_DIR):
        files += sorted(
            os.path.join(VOCAB_DIR, n)
            for n in os.listdir(VOCAB_DIR)
            if n.endswith(".gguf")
        )
    out = []
    for path in files:
        if not os.path.isfile(path):
            out.append({"path": path, "error": "ABSENT on this VM"})
            continue
        out.append(census_file(path))
    print(json.dumps(out, indent=1))
    bad = [r for r in out if "error" in r]
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
