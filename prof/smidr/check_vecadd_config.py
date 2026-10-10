#!/usr/bin/env python3
"""H104 TEST-ONLY (PROF) validator: independently validates the vecadd
configuration emitted by smidr/config_gen.mojo (via smidr/tools/cfgemit).

Independent reimplementation: xorshift64 PRNG, the value mapping
((x % 2001) - 1000) / 8, and f32->f16 bit conversion are all re-derived
here from the documented spec — not copied from the Mojo source. Golden
values in data/smidr/vecadd/ (seed 12345, emitted on Mimir) are compared
byte-for-byte. Determinism was proven on Mimir (two runs, seed 12345,
byte-identical; seed 999 differs).

Usage: python3 prof/smidr/check_vecadd_config.py
Exit 0 = all checks pass.
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


MASK64 = (1 << 64) - 1


def xorshift64(state):
    # Independent reimplementation of the documented xorshift64.
    while True:
        x = state
        x ^= (x << 13) & MASK64
        x ^= x >> 7
        x ^= (x << 17) & MASK64
        x &= MASK64
        state = x
        yield x


def f32_to_f16_bits(x):
    # Independent round-to-nearest-even f32->f16 (via struct).
    u = struct.unpack("<I", struct.pack("<f", x))[0]
    sign = (u >> 16) & 0x8000
    exp = (u >> 23) & 0xFF
    mant = u & 0x7FFFFF
    if exp == 0:
        return sign
    if exp == 0xFF:
        return sign | (0x7C00 if mant == 0 else 0x7E00)
    e = exp - 112
    if e >= 31:
        return sign | 0x7C00
    if e <= 0:
        if e < -10:
            return sign
        m = mant | 0x800000
        s = 14 - e
        sub = m >> s
        dropped = m & ((1 << s) - 1)
        half = 1 << (s - 1)
        if dropped > half or (dropped == half and (sub & 1)):
            sub += 1
        return sign | (sub & 0xFFFF)
    h = (mant >> 13) & 0x3FF
    dropped = mant & 0x1FFF
    if dropped > 0x1000 or (dropped == 0x1000 and (h & 1)):
        h += 1
        if h == 0x400:
            h = 0
            e += 1
            if e >= 31:
                return sign | 0x7C00
    return sign | (e << 10) | h


def f16_bits_to_f32(b):
    return struct.unpack("<e", struct.pack("<H", b))[0]


def main():
    root = Path(__file__).resolve().parents[2]
    vdir = root / "data/smidr/vecadd"
    seed = 12345
    nelems = 64

    print("H104 vecadd config validation (independent validator)")

    print("== golden value regeneration (seed 12345) ==")
    rng = xorshift64(seed if seed != 0 else 0x9E3779B97F4A7C15)
    exp_a, exp_b, exp_e = bytearray(), bytearray(), bytearray()
    for _ in range(nelems):
        av = ((next(rng) % 2001) - 1000) / 8.0
        bv = ((next(rng) % 2001) - 1000) / 8.0
        ev = av + bv
        exp_a += struct.pack("<H", f32_to_f16_bits(av))
        exp_b += struct.pack("<H", f32_to_f16_bits(bv))
        exp_e += struct.pack("<H", f32_to_f16_bits(ev))

    a_bin = (vdir / "vecadd_a.bin").read_bytes()
    b_bin = (vdir / "vecadd_b.bin").read_bytes()
    e_bin = (vdir / "vecadd_expected.bin").read_bytes()
    check(len(a_bin) == 128, "a.bin is 128 bytes (64 fp16)")
    check(len(b_bin) == 128, "b.bin is 128 bytes (64 fp16)")
    check(len(e_bin) == 128, "expected.bin is 128 bytes (64 fp16)")
    check(bytes(a_bin) == bytes(exp_a), "a.bin matches independent golden")
    check(bytes(b_bin) == bytes(exp_b), "b.bin matches independent golden")
    check(bytes(e_bin) == bytes(exp_e), "expected.bin matches independent golden")

    print("== arithmetic correctness (a+b == expected, exact) ==")
    bad = 0
    for i in range(nelems):
        a = f16_bits_to_f32(struct.unpack_from("<H", a_bin, 2 * i)[0])
        b = f16_bits_to_f32(struct.unpack_from("<H", b_bin, 2 * i)[0])
        e = f16_bits_to_f32(struct.unpack_from("<H", e_bin, 2 * i)[0])
        if abs((a + b) - e) > 0:
            bad += 1
    check(bad == 0, "all 64 expected[i] == a[i]+b[i] exactly (%d bad)" % bad)

    print("== no magic bytes: every byte is fp16 payload ==")
    for name, blob in (("a", a_bin), ("b", b_bin), ("e", e_bin)):
        vals = struct.unpack("<64H", blob)
        finite = all((v & 0x7C00) != 0x7C00 for v in vals)
        check(finite, name + ".bin: all 64 values finite (no inf/nan smuggled)")

    print("== config JSON schema ==")
    cfg = json.loads((vdir / "vecadd_config.json").read_text())
    allowed = {"format", "version", "op", "seed", "dtype", "nelems",
               "layout", "files", "notes"}
    check(set(cfg.keys()) == allowed, "JSON has exactly the documented fields")
    check(cfg["format"] == "SMIDR-CFG", "format == SMIDR-CFG (own magic)")
    check(cfg["format"] != "HEF", "format is NOT a HEF")
    check(cfg["version"] == 1, "version == 1")
    check(cfg["op"] == "vecadd", "op == vecadd")
    check(cfg["seed"] == seed, "seed == 12345")
    check(cfg["dtype"] == "fp16", "dtype == fp16")
    check(cfg["nelems"] == nelems, "nelems == 64")
    check(cfg["layout"] == "contiguous-1d", "layout documented")
    check(cfg["files"] == ["vecadd_a.bin", "vecadd_b.bin",
                           "vecadd_expected.bin"], "files list documented")
    check("NOT a HEF" in cfg["notes"] and "UNPROVEN" in cfg["notes"],
          "notes carry the honesty marking")

    print()
    if FAILURES:
        print("H104 VALIDATOR: %d FAILURES" % len(FAILURES))
        return 1
    print("H104 VALIDATOR: ALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
