#!/usr/bin/env python3
"""H103 TEST-ONLY (PROF) checker: independently validates the descriptors
emitted by the Mojo builder (smidr/descriptor.mojo via smidr/tools/descemit).

This checker encodes the documented layouts INDEPENDENTLY (from H101 section 4,
the HAILO_PCIE_TRANSPORT_GUIDE.md section 4 field set, and H019) — it is not
the builder's own code. It reads data/smidr/descriptors.json (emitted on
Mimir) and validates every field. Malformed inputs are proven fail-closed by
the emitter's own probes (5/5 on Mimir); this checker verifies the manifest
records that count and re-validates the byte layouts.

Usage: python3 prof/smidr/check_descriptors.py
Exit 0 = all checks pass. Any failure prints the field and exits 1.
"""

import json
import struct
import sys
from pathlib import Path

FAILURES = []


def check(cond, label):
    if cond:
        print("  ok: " + label)
    else:
        print("  FAIL: " + label)
        FAILURES.append(label)


def u32(b, off):
    return struct.unpack_from("<I", b, off)[0]


def main():
    root = Path(__file__).resolve().parents[2]
    data = json.loads((root / "data/smidr/descriptors.json").read_text())
    descs = {d["name"]: d for d in data["descriptors"]}

    print("H103 descriptor validation (independent checker)")
    print("== envelope (all three) ==")
    for name, d in descs.items():
        raw = bytes.fromhex(d["bytes"])
        check(len(raw) == d["len"], name + ": len field matches actual bytes")
        check(u32(raw, 0) == 0x534D4452, name + ": magic u32 == 0x534D4452 (SMIÐR's own, LE bytes 'RDMS' — not vendor)")
        check(u32(raw, 4) == 1, name + ": version == 1")
        check(u32(raw, 12) == len(raw) - 16, name + ": payload_len matches")
    check(descs["noop"]["op"] == 0, "noop op == 0")
    check(descs["memcpy"]["op"] == 1, "memcpy op == 1")
    check(descs["vecadd"]["op"] == 2, "vecadd op == 2")

    print("== noop: byte-exact IDENTIFY (H101 section 4) ==")
    body = bytes.fromhex(descs["noop"]["bytes"])[16:]
    # u32 length=8, then the 8-byte packed request: version=2, opcode=0.
    expected = struct.pack("<III", 8, 2, 0)
    check(body == expected, "noop body is byte-exact IDENTIFY command")
    check(len(body) == 12, "noop body length == 12")

    print("== memcpy: studied VDMA field set ==")
    body = bytes.fromhex(descs["memcpy"]["bytes"])[16:]
    check(len(body) == 28, "memcpy body length == 28 (7 u32 fields)")
    page = u32(body, 0)
    src = u32(body, 4) | (u32(body, 8) << 32)
    dst = u32(body, 12) | (u32(body, 16) << 32)
    nbytes = u32(body, 20)
    remaining = u32(body, 24)
    check(page == 4096, "memcpy page_size == 4096 (emitter input)")
    check(src == 0x100000, "memcpy src == 0x100000 (emitter input)")
    check(dst == 0x200000, "memcpy dst == 0x200000 (emitter input)")
    check(nbytes == 4096, "memcpy nbytes == 4096 (emitter input)")
    check(remaining == 0, "memcpy remaining/status init == 0")
    check(page & (page - 1) == 0 and page > 0, "memcpy page_size is pow2")
    check(src != dst, "memcpy src != dst")
    check(nbytes > 0, "memcpy nbytes positive")

    print("== vecadd: tensor descriptors + UNKNOWN compute ==")
    body = bytes.fromhex(descs["vecadd"]["bytes"])[16:]
    check(len(body) == 24, "vecadd body length == 24 (6 u32 fields)")
    dtype, nelems, ndim, dim0, compute, flags = struct.unpack_from("<6I", body, 0)
    check(dtype == 1, "vecadd dtype == 1 (fp16)")
    check(nelems == 64, "vecadd nelems == 64 (H104 config size)")
    check(ndim == 1, "vecadd ndim == 1")
    check(dim0 == nelems, "vecadd dim0 == nelems (shape consistent)")
    # The critical honesty check: the builder must NOT have invented a
    # chip encoding. The compute section must carry the UNKNOWN sentinel.
    check(compute == 0xFFFFFFFF, "vecadd compute == UNKNOWN sentinel (not invented)")
    check(flags == 0, "vecadd flags reserved == 0")

    print("== fail-closed manifest ==")
    check(data["fail_closed_probes"] == 5, "5/5 malformed-input probes raised BadDescriptor")

    print()
    if FAILURES:
        print("H103 CHECKER: %d FAILURES" % len(FAILURES))
        return 1
    print("H103 CHECKER: ALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
