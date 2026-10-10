#!/usr/bin/env python3
"""H037 PRÓF oracle suite (TEST-ONLY): independent float64 verification of
every Campaign-2 ARMVEGR kernel (H022-H035) against the Mojo implementation.

Runs ON MIMIR (Python 3 stdlib only). For each case in
data/armvegr/oracle_corpus.json it:
  1. generates deterministic inputs from the case seed (random.Random),
  2. writes them as little-endian binary files into the work dir,
  3. emits a Mojo oracle program that reads the inputs, runs the real
     ARMVEGR kernel, and writes the outputs back to binary files,
  4. builds the oracle with the pixi-shim mojo and runs it via subprocess,
  5. recomputes the expected outputs INDEPENDENTLY in float64 pure-Python
     math and compares (per-element max-abs-err with the slice's documented
     bound, or sum/sumsq checksum for the large-shape case),
  6. exits non-zero if any kernel exceeds its bound.

Re-running with the same corpus version yields identical PASS/FAIL
(fixed seeds; no wall-clock or address-space dependence in the checks).

Usage:
    python3 prof/armvegr/test_kernel_oracles.py [--work-dir DIR] [--repo DIR]
"""

import json
import math
import os
import random
import struct
import subprocess
import sys

# ---------------------------------------------------------------- fp16 codec
# struct '<e' is IEEE-754 binary16, round-half-even -- the same rounding the
# Mojo fp16 conversions use, so the Python reference consumes bit-identical
# inputs to the Mojo kernels.


def f16(x):
    return struct.unpack("<e", struct.pack("<e", x))[0]


def f16bytes(vals):
    return struct.pack("<%de" % len(vals), *[float(v) for v in vals])


def f32bytes(vals):
    return struct.pack("<%df" % len(vals), *vals)


def read_f16(path):
    with open(path, "rb") as f:
        raw = f.read()
    return list(struct.unpack("<%de" % (len(raw) // 2), raw))


def read_f32(path):
    with open(path, "rb") as f:
        raw = f.read()
    return list(struct.unpack("<%df" % (len(raw) // 4), raw))


def gen_f16(seed, n, lo, hi):
    rng = random.Random(seed)
    return [f16(rng.uniform(lo, hi)) for _ in range(n)]


# ---------------------------------------------------------------- bound check
# SÓLRÚN re-scope: per-element envelope |got-ref| <= base + 2^-10*|ref|.


def check_ulp(got, ref, base):
    maxerr = 0.0
    excess = 0.0
    for g, r in zip(got, ref):
        d = abs(g - r)
        if d > maxerr:
            maxerr = d
        allowed = base + abs(r) * 2.0**-10
        e = d - allowed
        if e > excess:
            excess = e
    return maxerr, excess


# ---------------------------------------------------------------- Q8_0 / Q4_0
# Independent Python implementations of the documented block formats
# (byte-exact per armvegr/quant.mojo and armvegr/q4.mojo headers).


def q80_quant_block(vals):
    amax = max(abs(v) for v in vals)
    scale = amax / 127.0 if amax != 0 else 1.0
    # scale stored as fp16 bits; decode back exactly like the kernel
    sbits = struct.unpack("<H", struct.pack("<e", scale))[0]
    sdec = struct.unpack("<e", struct.pack("<H", sbits))[0]
    inv = 1.0 / sdec
    out = bytearray(struct.pack("<H", sbits))
    for v in vals:
        q = int(math.floor(v * inv + 0.5)) if v >= 0 else int(math.ceil(v * inv - 0.5))
        q = max(-128, min(127, q))
        out.append(q & 0xFF)
    return bytes(out), sdec


def q80_dequant_block(blk):
    sbits = struct.unpack("<H", blk[0:2])[0]
    sdec = struct.unpack("<e", struct.pack("<H", sbits))[0]
    return [struct.unpack("b", blk[2 + i : 3 + i])[0] * sdec for i in range(32)]


def q80_quant(src):
    assert len(src) % 32 == 0
    return b"".join(q80_quant_block(src[i : i + 32])[0] for i in range(0, len(src), 32))


def q40_quant_block(vals):
    amax = max(abs(v) for v in vals)
    scale = amax / 7.0 if amax != 0 else 1.0
    sbits = struct.unpack("<H", struct.pack("<e", scale))[0]
    sdec = struct.unpack("<e", struct.pack("<H", sbits))[0]
    inv = 1.0 / sdec
    out = bytearray(struct.pack("<H", sbits))
    for b in range(16):
        qs = []
        for t in range(2):
            v = vals[2 * b + t]
            q = int(math.floor(v * inv + 0.5)) if v >= 0 else int(math.ceil(v * inv - 0.5))
            q = max(-8, min(7, q))
            qs.append(q & 0xF)
        out.append(qs[0] | (qs[1] << 4))  # low nibble first
    return bytes(out), sdec


def q40_dequant_block(blk):
    sbits = struct.unpack("<H", blk[0:2])[0]
    sdec = struct.unpack("<e", struct.pack("<H", sbits))[0]
    vals = []
    for b in range(16):
        byte = blk[2 + b]
        for t in range(2):
            q = (byte >> (4 * t)) & 0xF
            if q >= 8:
                q -= 16
            vals.append(q * sdec)
    return vals


def q40_quant(src):
    assert len(src) % 32 == 0
    return b"".join(q40_quant_block(src[i : i + 32])[0] for i in range(0, len(src), 32))


# ---------------------------------------------------------------- Mojo emitter
# The generated oracle reads binary inputs, runs the real kernels, writes
# binary outputs. Helpers are emitted once; each case appends a block.

MOJO_HEADER = """# GENERATED by prof/armvegr/test_kernel_oracles.py -- DO NOT EDIT.
from std.io.file import open
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from std.memory.alloc import unsafe_alloc
from armvegr.gemm import gemm_fp16, gemm_micro_8x8, gemm_pack_a, gemm_pack_b
from armvegr.gemv import gemv_fp16
from armvegr.elem import elem_add, elem_mul, elem_scale, elem_axpy
from armvegr.norm import layernorm_fp16
from armvegr.rmsnorm import rmsnorm_fp16
from armvegr.softmax import softmax_fp16, softmax_masked_fp16
from armvegr.act import silu_fp16, gelu_fp16
from armvegr.rope import rope_fp16
from armvegr.quant import fp32_to_fp16, fp16_to_q80, q80_to_fp16
from armvegr.q4 import fp16_to_q40, q40_to_fp16
from armvegr.qgemm import q80_gemm
from armvegr.attn import attn_sdpa_causal_fp16
from armvegr.mha import mha_forward_seq


def load_raw(path: String, nbytes: Int) raises -> List[UInt8]:
    var fh = open(path, "r")
    var data = fh.read_bytes(nbytes)
    fh.close()
    return data


def new_out(nbytes: Int) -> List[UInt8]:
    var out = List[UInt8](capacity=nbytes)
    out.resize(nbytes, UInt8(0))
    return out


def store_raw(path: String, data: List[UInt8]) raises:
    var fh = open(path, "w")
    fh.write_bytes(data)
    fh.close()


def main() raises:
"""


def mojo_case_gemm_micro(case, wd):
    kc = case["kc"]
    n = 8 * kc
    a = gen_f16(case["seed"], n, -1.0, 1.0)
    b = gen_f16(case["seed"] + 1, n, -1.0, 1.0)
    open(os.path.join(wd, "a.bin"), "wb").write(f16bytes(a))
    open(os.path.join(wd, "b.bin"), "wb").write(f16bytes(b))
    code = """
    # case %(id)s: gemm_micro_8x8 kc=%(kc)d
    var raw_a = load_raw("%(wd)s/a.bin", %(n2)d)
    var raw_b = load_raw("%(wd)s/b.bin", %(n2)d)
    var a = raw_a.unsafe_ptr().unsafe_bitcast[Float16]()
    var b = raw_b.unsafe_ptr().unsafe_bitcast[Float16]()
    var ap = unsafe_alloc[Float16](%(n)d)
    var bp = unsafe_alloc[Float16](%(n)d)
    var acc = unsafe_alloc[Float32](64)
    gemm_pack_a(a, ap, %(kc)d, 0, 8, 0, %(kc)d)
    gemm_pack_b(b, bp, 8, 0, 8, 0, %(kc)d)
    for i in range(64):
        acc[unsafe_offset=i] = Float32(0)
    gemm_micro_8x8(ap, bp, acc, %(kc)d, 8)
    var out_raw = new_out(256)
    var outp = out_raw.unsafe_ptr().unsafe_bitcast[Float32]()
    for i in range(64):
        outp[unsafe_offset=i] = acc[unsafe_offset=i]
    store_raw("%(wd)s/out.bin", out_raw)
""" % {"id": case["id"], "kc": kc, "n": n, "n2": n * 2, "wd": wd}

    def verify(wd):
        got = read_f32(os.path.join(wd, "out.bin"))
        ref = []
        for i in range(8):
            for j in range(8):
                s = 0.0
                for k in range(kc):
                    s += float(a[i * kc + k]) * float(b[k * 8 + j])
                ref.append(s)
        # acc is fp32: compare in fp32 precision, ulp envelope base 1e-3
        maxerr, excess = check_ulp(got, ref, case["base"])
        return excess <= 0, "maxerr=%.6g ulp_excess=%.6g" % (maxerr, excess)

    return code, verify


def mojo_case_gemm(case, wd):
    M, N, K = case["M"], case["N"], case["K"]
    a = gen_f16(case["seed"], M * K, -1.0, 1.0)
    b = gen_f16(case["seed"] + 1, K * N, -1.0, 1.0)
    open(os.path.join(wd, "a.bin"), "wb").write(f16bytes(a))
    open(os.path.join(wd, "b.bin"), "wb").write(f16bytes(b))
    if case["bound"] == "checksum":
        tail = """
    var s = Float64(0)
    var ss = Float64(0)
    for i in range(%(mn)d):
        var v = Float64(c[unsafe_offset=i])
        s += v
        ss += v * v
    var out_raw = new_out(16)
    var outp = out_raw.unsafe_ptr().unsafe_bitcast[Float64]()
    outp[unsafe_offset=0] = s
    outp[unsafe_offset=1] = ss
    store_raw("%(wd)s/out.bin", out_raw)
""" % {"mn": M * N, "wd": wd}
    else:
        tail = """
    var out_raw = new_out(%(mn2)d)
    var outp = out_raw.unsafe_ptr().unsafe_bitcast[Float16]()
    for i in range(%(mn)d):
        outp[unsafe_offset=i] = c[unsafe_offset=i]
    store_raw("%(wd)s/out.bin", out_raw)
""" % {"mn": M * N, "mn2": M * N * 2, "wd": wd}
    code = """
    # case %(id)s: gemm_fp16 %(M)dx%(N)dx%(K)d
    var raw_a = load_raw("%(wd)s/a.bin", %(a2)d)
    var raw_b = load_raw("%(wd)s/b.bin", %(b2)d)
    var a = raw_a.unsafe_ptr().unsafe_bitcast[Float16]()
    var b = raw_b.unsafe_ptr().unsafe_bitcast[Float16]()
    var c = unsafe_alloc[Float16](%(mn)d)
    gemm_fp16(a, b, c, %(M)d, %(N)d, %(K)d)
""" % {
        "id": case["id"],
        "M": M,
        "N": N,
        "K": K,
        "wd": wd,
        "a2": M * K * 2,
        "b2": K * N * 2,
        "mn": M * N,
    } + tail

    def verify(wd):
        if case["bound"] == "checksum":
            s, ss = struct.unpack("<dd", open(os.path.join(wd, "out.bin"), "rb").read())
            rs, rss = 0.0, 0.0
            # blocked fp64 accumulation matching the kernel's K-blocking is
            # unnecessary: checksum tolerance covers summation-order noise.
            for i in range(M):
                for j in range(N):
                    v = 0.0
                    for k in range(K):
                        v += float(a[i * K + k]) * float(b[k * N + j])
                    v16 = f16(v)
                    rs += v16
                    rss += v16 * v16
            tol = case["tol"] * max(1.0, abs(rs))
            ok = abs(s - rs) <= tol and abs(ss - rss) <= tol * max(1.0, abs(rss))
            return ok, "sum=%.6g ref=%.6g sumsq=%.6g ref=%.6g tol=%.6g" % (
                s, rs, ss, rss, tol)
        got = read_f16(os.path.join(wd, "out.bin"))
        ref = []
        for i in range(M):
            for j in range(N):
                v = 0.0
                for k in range(K):
                    v += float(a[i * K + k]) * float(b[k * N + j])
                ref.append(f16(v))
        maxerr, excess = check_ulp(got, ref, case["base"])
        return excess <= 0, "maxerr=%.6g ulp_excess=%.6g" % (maxerr, excess)

    return code, verify


def mojo_case_gemv(case, wd):
    M, N = case["M"], case["N"]
    a = gen_f16(case["seed"], M * N, -1.0, 1.0)
    x = gen_f16(case["seed"] + 1, N, -1.0, 1.0)
    open(os.path.join(wd, "a.bin"), "wb").write(f16bytes(a))
    open(os.path.join(wd, "x.bin"), "wb").write(f16bytes(x))
    code = """
    # case %(id)s: gemv_fp16 %(M)dx%(N)d
    var raw_a = load_raw("%(wd)s/a.bin", %(a2)d)
    var raw_x = load_raw("%(wd)s/x.bin", %(x2)d)
    var a = raw_a.unsafe_ptr().unsafe_bitcast[Float16]()
    var xv = raw_x.unsafe_ptr().unsafe_bitcast[Float16]()
    var y = unsafe_alloc[Float16](%(M)d)
    gemv_fp16(a, xv, y, %(M)d, %(N)d)
    var out_raw = new_out(%(m2)d)
    var outp = out_raw.unsafe_ptr().unsafe_bitcast[Float16]()
    for i in range(%(M)d):
        outp[unsafe_offset=i] = y[unsafe_offset=i]
    store_raw("%(wd)s/out.bin", out_raw)
""" % {"id": case["id"], "M": M, "N": N, "wd": wd, "a2": M * N * 2,
       "x2": N * 2, "m2": M * 2}

    def verify(wd):
        got = read_f16(os.path.join(wd, "out.bin"))
        ref = []
        for i in range(M):
            v = 0.0
            for k in range(N):
                v += float(a[i * N + k]) * float(x[k])
            ref.append(f16(v))
        maxerr, excess = check_ulp(got, ref, case["base"])
        return excess <= 0, "maxerr=%.6g ulp_excess=%.6g" % (maxerr, excess)

    return code, verify


def mojo_case_elem(case, wd):
    n = case["n"]
    kernel = case["kernel"]
    a = gen_f16(case["seed"], n, -1.0, 1.0)
    b = gen_f16(case["seed"] + 1, n, -1.0, 1.0)
    alpha = 0.5
    open(os.path.join(wd, "a.bin"), "wb").write(f16bytes(a))
    open(os.path.join(wd, "b.bin"), "wb").write(f16bytes(b))
    call = {
        "elem_add": "elem_add(a, b, c, %(n)d)",
        "elem_mul": "elem_mul(a, b, c, %(n)d)",
        "elem_scale": "elem_scale(a, c, Float16(0.5), %(n)d)",
        "elem_axpy": "elem_axpy(a, b, c, Float16(0.5), %(n)d)",
    }[kernel] % {"n": n}
    code = """
    # case %(id)s: %(kernel)s n=%(n)d
    var raw_a = load_raw("%(wd)s/a.bin", %(n2)d)
    var raw_b = load_raw("%(wd)s/b.bin", %(n2)d)
    var a = raw_a.unsafe_ptr().unsafe_bitcast[Float16]()
    var b = raw_b.unsafe_ptr().unsafe_bitcast[Float16]()
    var c = unsafe_alloc[Float16](%(n)d)
    %(call)s
    var out_raw = new_out(%(n2)d)
    var outp = out_raw.unsafe_ptr().unsafe_bitcast[Float16]()
    for i in range(%(n)d):
        outp[unsafe_offset=i] = c[unsafe_offset=i]
    store_raw("%(wd)s/out.bin", out_raw)
""" % {"id": case["id"], "kernel": kernel, "n": n, "n2": n * 2,
       "wd": wd, "call": call}

    def verify(wd):
        got = read_f16(os.path.join(wd, "out.bin"))
        if kernel == "elem_add":
            ref = [f16(float(x) + float(y)) for x, y in zip(a, b)]
        elif kernel == "elem_mul":
            ref = [f16(float(x) * float(y)) for x, y in zip(a, b)]
        elif kernel == "elem_scale":
            ref = [f16(float(x) * alpha) for x in a]
        else:
            ref = [f16(float(x) * alpha + float(y)) for x, y in zip(a, b)]
        maxerr, excess = check_ulp(got, ref, case["base"])
        return excess <= 0, "maxerr=%.6g ulp_excess=%.6g" % (maxerr, excess)

    return code, verify


def mojo_case_layernorm(case, wd):
    n = case["n"]
    eps = case["eps"]
    x = gen_f16(case["seed"], n, -3.0, 3.0)
    w = gen_f16(case["seed"] + 1, n, 0.5, 1.5)
    b = gen_f16(case["seed"] + 2, n, -1.0, 1.0)
    for name, vals in (("x", x), ("w", w), ("b", b)):
        open(os.path.join(wd, name + ".bin"), "wb").write(f16bytes(vals))
    code = """
    # case %(id)s: layernorm n=%(n)d
    var raw_x = load_raw("%(wd)s/x.bin", %(n2)d)
    var raw_w = load_raw("%(wd)s/w.bin", %(n2)d)
    var raw_b = load_raw("%(wd)s/b.bin", %(n2)d)
    var x = raw_x.unsafe_ptr().unsafe_bitcast[Float16]()
    var w = raw_w.unsafe_ptr().unsafe_bitcast[Float16]()
    var bv = raw_b.unsafe_ptr().unsafe_bitcast[Float16]()
    var y = unsafe_alloc[Float16](%(n)d)
    layernorm_fp16(x, w, bv, y, %(n)d, Float32(%(eps)r))
    var out_raw = new_out(%(n2)d)
    var outp = out_raw.unsafe_ptr().unsafe_bitcast[Float16]()
    for i in range(%(n)d):
        outp[unsafe_offset=i] = y[unsafe_offset=i]
    store_raw("%(wd)s/out.bin", out_raw)
""" % {"id": case["id"], "n": n, "n2": n * 2, "wd": wd, "eps": eps}

    def verify(wd):
        got = read_f16(os.path.join(wd, "out.bin"))
        mean = sum(float(v) for v in x) / n
        var = sum((float(v) - mean) ** 2 for v in x) / n
        inv = 1.0 / math.sqrt(var + eps)
        ref = [f16((float(v) - mean) * inv * float(wi) + float(bi))
               for v, wi, bi in zip(x, w, b)]
        maxerr, excess = check_ulp(got, ref, case["base"])
        return excess <= 0, "maxerr=%.6g ulp_excess=%.6g" % (maxerr, excess)

    return code, verify


def mojo_case_rmsnorm(case, wd):
    n = case["n"]
    eps = case["eps"]
    x = gen_f16(case["seed"], n, -3.0, 3.0)
    w = gen_f16(case["seed"] + 1, n, 0.5, 1.5)
    for name, vals in (("x", x), ("w", w)):
        open(os.path.join(wd, name + ".bin"), "wb").write(f16bytes(vals))
    code = """
    # case %(id)s: rmsnorm n=%(n)d
    var raw_x = load_raw("%(wd)s/x.bin", %(n2)d)
    var raw_w = load_raw("%(wd)s/w.bin", %(n2)d)
    var x = raw_x.unsafe_ptr().unsafe_bitcast[Float16]()
    var w = raw_w.unsafe_ptr().unsafe_bitcast[Float16]()
    var y = unsafe_alloc[Float16](%(n)d)
    rmsnorm_fp16(x, w, y, %(n)d, Float32(%(eps)r))
    var out_raw = new_out(%(n2)d)
    var outp = out_raw.unsafe_ptr().unsafe_bitcast[Float16]()
    for i in range(%(n)d):
        outp[unsafe_offset=i] = y[unsafe_offset=i]
    store_raw("%(wd)s/out.bin", out_raw)
""" % {"id": case["id"], "n": n, "n2": n * 2, "wd": wd, "eps": eps}

    def verify(wd):
        got = read_f16(os.path.join(wd, "out.bin"))
        ms = sum(float(v) ** 2 for v in x) / n
        inv = 1.0 / math.sqrt(ms + eps)
        ref = [f16(float(v) * inv * float(wi)) for v, wi in zip(x, w)]
        maxerr, excess = check_ulp(got, ref, case["base"])
        return excess <= 0, "maxerr=%.6g ulp_excess=%.6g" % (maxerr, excess)

    return code, verify


def mojo_case_softmax(case, wd, masked):
    n = case["n"]
    rng = random.Random(case["seed"])
    x = [f16(rng.uniform(-2.0, 2.0)) for _ in range(n - 4)]
    x += [f16(50.0), f16(-50.0), f16(100.0), f16(-100.0)]
    rng.shuffle(x)
    open(os.path.join(wd, "x.bin"), "wb").write(f16bytes(x))
    if masked:
        vl = case["valid_len"]
        call = "softmax_masked_fp16(x, y, %(n)d, %(vl)d)" % {"n": n, "vl": vl}
        cid = case["id"]
    else:
        call = "softmax_fp16(x, y, %(n)d)" % {"n": n}
        cid = case["id"]
    code = """
    # case %(id)s: softmax n=%(n)d
    var raw_x = load_raw("%(wd)s/x.bin", %(n2)d)
    var x = raw_x.unsafe_ptr().unsafe_bitcast[Float16]()
    var y = unsafe_alloc[Float16](%(n)d)
    %(call)s
    var out_raw = new_out(%(n2)d)
    var outp = out_raw.unsafe_ptr().unsafe_bitcast[Float16]()
    for i in range(%(n)d):
        outp[unsafe_offset=i] = y[unsafe_offset=i]
    store_raw("%(wd)s/out.bin", out_raw)
""" % {"id": cid, "n": n, "n2": n * 2, "wd": wd, "call": call}

    def verify(wd):
        got = read_f16(os.path.join(wd, "out.bin"))
        if any(math.isnan(v) or math.isinf(v) for v in got):
            return False, "NaN/Inf in output"
        if masked:
            vl = case["valid_len"]
            if any(v != 0.0 for v in got[vl:]):
                return False, "masked positions not exactly 0"
            xs = x[:vl]
            m = max(float(v) for v in xs)
            es = [math.exp(float(v) - m) for v in xs]
            s = sum(es)
            ref = [f16(e / s) for e in es] + [0.0] * (n - vl)
            tot = sum(got[:vl])
        else:
            m = max(float(v) for v in x)
            es = [math.exp(float(v) - m) for v in x]
            s = sum(es)
            ref = [f16(e / s) for e in es]
            tot = sum(got)
        if abs(tot - 1.0) > 1e-3:
            return False, "sum=%.6g != 1" % tot
        maxerr, excess = check_ulp(got, ref, case["base"])
        return excess <= 0, "maxerr=%.6g ulp_excess=%.6g sum=%.6g" % (
            maxerr, excess, tot)

    return code, verify


def mojo_case_act(case, wd):
    n = case["n"]
    kernel = case["kernel"]
    x = gen_f16(case["seed"], n, -10.0, 10.0)
    open(os.path.join(wd, "x.bin"), "wb").write(f16bytes(x))
    code = """
    # case %(id)s: %(kernel)s n=%(n)d
    var raw_x = load_raw("%(wd)s/x.bin", %(n2)d)
    var x = raw_x.unsafe_ptr().unsafe_bitcast[Float16]()
    var y = unsafe_alloc[Float16](%(n)d)
    %(kernel)s(x, y, %(n)d)
    var out_raw = new_out(%(n2)d)
    var outp = out_raw.unsafe_ptr().unsafe_bitcast[Float16]()
    for i in range(%(n)d):
        outp[unsafe_offset=i] = y[unsafe_offset=i]
    store_raw("%(wd)s/out.bin", out_raw)
""" % {"id": case["id"], "kernel": kernel, "n": n, "n2": n * 2, "wd": wd}

    def silu_ref(v):
        return v / (1.0 + math.exp(-v))

    def gelu_ref(v):
        t = math.tanh(0.7978845608028654 * (v + 0.044715 * v**3))
        return 0.5 * v * (1.0 + t)

    fn = silu_ref if kernel == "silu_fp16" else gelu_ref

    def verify(wd):
        got = read_f16(os.path.join(wd, "out.bin"))
        ref = [f16(fn(float(v))) for v in x]
        maxerr, excess = check_ulp(got, ref, case["base"])
        return excess <= 0, "maxerr=%.6g ulp_excess=%.6g" % (maxerr, excess)

    return code, verify


def mojo_case_rope(case, wd):
    hd = case["head_dim"]
    pos = case["pos"]
    theta = case["theta"]
    x = gen_f16(case["seed"], hd, -1.0, 1.0)
    open(os.path.join(wd, "x.bin"), "wb").write(f16bytes(x))
    code = """
    # case %(id)s: rope hd=%(hd)d pos=%(pos)d
    var raw_x = load_raw("%(wd)s/x.bin", %(n2)d)
    var x = raw_x.unsafe_ptr().unsafe_bitcast[Float16]()
    var y = unsafe_alloc[Float16](%(hd)d)
    rope_fp16(x, y, %(hd)d, %(pos)d, Float32(%(theta)r))
    var out_raw = new_out(%(n2)d)
    var outp = out_raw.unsafe_ptr().unsafe_bitcast[Float16]()
    for i in range(%(hd)d):
        outp[unsafe_offset=i] = y[unsafe_offset=i]
    store_raw("%(wd)s/out.bin", out_raw)
""" % {"id": case["id"], "hd": hd, "pos": pos, "wd": wd, "n2": hd * 2,
       "theta": theta}

    def verify(wd):
        got = read_f16(os.path.join(wd, "out.bin"))
        if pos == 0:
            ok = all(g == v for g, v in zip(got, x))
            return ok, "identity@pos0 exact=%s" % ok
        ref = []
        for i in range(hd // 2):
            ang = pos * theta ** (-2.0 * i / hd)
            co, si = math.cos(ang), math.sin(ang)
            x0, x1 = float(x[2 * i]), float(x[2 * i + 1])
            ref += [f16(x0 * co - x1 * si), f16(x0 * si + x1 * co)]
        maxerr, excess = check_ulp(got, ref, case["base"])
        return excess <= 0, "maxerr=%.6g ulp_excess=%.6g" % (maxerr, excess)

    return code, verify


def mojo_case_fp32_to_fp16(case, wd):
    n = case["n"]
    vals = [random.Random(case["seed"]).uniform(-6.0, 6.0) for _ in range(n)]
    open(os.path.join(wd, "x.bin"), "wb").write(f32bytes(vals))
    code = """
    # case %(id)s: fp32_to_fp16 n=%(n)d
    var raw_x = load_raw("%(wd)s/x.bin", %(n4)d)
    var x = raw_x.unsafe_ptr().unsafe_bitcast[Float32]()
    var y = unsafe_alloc[Float16](%(n)d)
    fp32_to_fp16(x, y, %(n)d)
    var out_raw = new_out(%(n2)d)
    var outp = out_raw.unsafe_ptr().unsafe_bitcast[Float16]()
    for i in range(%(n)d):
        outp[unsafe_offset=i] = y[unsafe_offset=i]
    store_raw("%(wd)s/out.bin", out_raw)
""" % {"id": case["id"], "n": n, "n2": n * 2, "n4": n * 4, "wd": wd}

    def verify(wd):
        got = read_f16(os.path.join(wd, "out.bin"))
        ref = [f16(v) for v in vals]
        maxerr = max(abs(g - r) for g, r in zip(got, ref))
        return maxerr == 0.0, "maxerr=%.6g" % maxerr

    return code, verify


def mojo_case_qroundtrip(case, wd):
    n = case["n"]
    is_q80 = case["kernel"] == "q80_roundtrip"
    blk = 34 if is_q80 else 18
    x = gen_f16(case["seed"], n, -6.0, 6.0)
    open(os.path.join(wd, "x.bin"), "wb").write(f16bytes(x))
    qcall = "fp16_to_q80(x, q, %(n)d)" % {"n": n} if is_q80 else \
        "fp16_to_q40(x, q, %(n)d)" % {"n": n}
    dcall = "q80_to_fp16(q, y, %(n)d)" % {"n": n} if is_q80 else \
        "q40_to_fp16(q, y, %(n)d)" % {"n": n}
    code = """
    # case %(id)s: %(kernel)s n=%(n)d
    var raw_x = load_raw("%(wd)s/x.bin", %(n2)d)
    var x = raw_x.unsafe_ptr().unsafe_bitcast[Float16]()
    var q = unsafe_alloc[Int8](%(qb)d)
    var y = unsafe_alloc[Float16](%(n)d)
    %(qcall)s
    %(dcall)s
    var out_raw = new_out(%(n2)d)
    var outp = out_raw.unsafe_ptr().unsafe_bitcast[Float16]()
    for i in range(%(n)d):
        outp[unsafe_offset=i] = y[unsafe_offset=i]
    store_raw("%(wd)s/out.bin", out_raw)
""" % {"id": case["id"], "kernel": case["kernel"], "n": n, "n2": n * 2,
       "qb": (n // 32) * blk, "wd": wd, "qcall": qcall, "dcall": dcall}

    def verify(wd):
        got = read_f16(os.path.join(wd, "out.bin"))
        diffs = [g - v for g, v in zip(got, x)]
        worst = max(abs(d) for d in diffs)
        rms = math.sqrt(sum(d * d for d in diffs) / n)
        if is_q80:
            ok = worst <= 0.024 and rms <= 0.014
        else:
            ok = worst <= 0.43 and rms <= 0.25
        return ok, "max=%.6g rms=%.6g" % (worst, rms)

    return code, verify


def mojo_case_q80_gemm(case, wd):
    M, N, K = case["M"], case["N"], case["K"]
    nb = K // 32
    a = gen_f16(case["seed"], M * K, -1.0, 1.0)
    b = gen_f16(case["seed"] + 1, K * N, -1.0, 1.0)
    # Bq is K-major: row j holds nb blocks over K (per qgemm.mojo header).
    bt = [b[k * N + j] for j in range(N) for k in range(K)]
    aq = q80_quant(a)
    bq = q80_quant(bt)
    open(os.path.join(wd, "aq.bin"), "wb").write(aq)
    open(os.path.join(wd, "bq.bin"), "wb").write(bq)
    code = """
    # case %(id)s: q80_gemm %(M)dx%(N)dx%(K)d
    var raw_aq = load_raw("%(wd)s/aq.bin", %(aqn)d)
    var raw_bq = load_raw("%(wd)s/bq.bin", %(bqn)d)
    var aq = raw_aq.unsafe_ptr().unsafe_bitcast[Int8]()
    var bq = raw_bq.unsafe_ptr().unsafe_bitcast[Int8]()
    var c = unsafe_alloc[Float32](%(mn)d)
    q80_gemm(aq, bq, c, %(M)d, %(N)d, %(K)d)
    var out_raw = new_out(%(mn4)d)
    var outp = out_raw.unsafe_ptr().unsafe_bitcast[Float32]()
    for i in range(%(mn)d):
        outp[unsafe_offset=i] = c[unsafe_offset=i]
    store_raw("%(wd)s/out.bin", out_raw)
""" % {"id": case["id"], "M": M, "N": N, "K": K, "wd": wd,
       "aqn": (M * K // 32) * 34, "bqn": (N * K // 32) * 34,
       "mn": M * N, "mn4": M * N * 4}

    def verify(wd):
        got = read_f32(os.path.join(wd, "out.bin"))
        # fp16 GEMM reference (what the quantized result must track)
        r = []
        for i in range(M):
            for j in range(N):
                v = 0.0
                for k in range(K):
                    v += float(a[i * K + k]) * float(b[k * N + j])
                r.append(f16(v))
        rms = math.sqrt(sum(v * v for v in r) / len(r))
        worst = max(abs(g - ri) for g, ri in zip(got, r))
        # documented contract: max|q-r| <= 0.05 * rms(r)
        ok = worst <= 0.05 * rms
        return ok, "maxerr=%.6g rms=%.6g contract=0.05*rms=%.6g" % (
            worst, rms, 0.05 * rms)

    return code, verify


def mojo_case_attn(case, wd):
    seq, hd = case["seq"], case["head_dim"]
    q = gen_f16(case["seed"], seq * hd, -0.5, 0.5)
    k = gen_f16(case["seed"] + 1, seq * hd, -0.5, 0.5)
    v = gen_f16(case["seed"] + 2, seq * hd, -0.5, 0.5)
    for name, vals in (("q", q), ("k", k), ("v", v)):
        open(os.path.join(wd, name + ".bin"), "wb").write(f16bytes(vals))
    code = """
    # case %(id)s: attn seq=%(seq)d hd=%(hd)d
    var raw_q = load_raw("%(wd)s/q.bin", %(n2)d)
    var raw_k = load_raw("%(wd)s/k.bin", %(n2)d)
    var raw_v = load_raw("%(wd)s/v.bin", %(n2)d)
    var q = raw_q.unsafe_ptr().unsafe_bitcast[Float16]()
    var k = raw_k.unsafe_ptr().unsafe_bitcast[Float16]()
    var vv = raw_v.unsafe_ptr().unsafe_bitcast[Float16]()
    var o = unsafe_alloc[Float16](%(n)d)
    _ = attn_sdpa_causal_fp16(q, k, vv, o, %(seq)d, %(hd)d)
    var out_raw = new_out(%(n2)d)
    var outp = out_raw.unsafe_ptr().unsafe_bitcast[Float16]()
    for i in range(%(n)d):
        outp[unsafe_offset=i] = o[unsafe_offset=i]
    store_raw("%(wd)s/out.bin", out_raw)
""" % {"id": case["id"], "seq": seq, "hd": hd, "wd": wd, "n": seq * hd,
       "n2": seq * hd * 2}

    def verify(wd):
        got = read_f16(os.path.join(wd, "out.bin"))
        inv = 1.0 / math.sqrt(hd)
        ref = []
        for i in range(seq):
            scores = []
            for j in range(i + 1):
                s = sum(float(q[i * hd + d]) * float(k[j * hd + d])
                        for d in range(hd)) * inv
                scores.append(s)
            m = max(scores)
            es = [math.exp(s - m) for s in scores]
            esum = sum(es)
            for d in range(hd):
                acc = sum(es[t] / esum * float(v[t * hd + d])
                           for t in range(i + 1))
                ref.append(f16(acc))
        maxerr, excess = check_ulp(got, ref, case["base"])
        return excess <= 0, "maxerr=%.6g ulp_excess=%.6g" % (maxerr, excess)

    return code, verify


def mojo_case_mha(case, wd):
    seq, nh, hd = case["seq"], case["n_heads"], case["head_dim"]
    dm = nh * hd
    theta = 10000.0
    x = gen_f16(case["seed"], seq * dm, -0.5, 0.5)
    wq = gen_f16(case["seed"] + 1, dm * dm, -0.2, 0.2)
    wk = gen_f16(case["seed"] + 2, dm * dm, -0.2, 0.2)
    wv = gen_f16(case["seed"] + 3, dm * dm, -0.2, 0.2)
    wo = gen_f16(case["seed"] + 4, dm * dm, -0.2, 0.2)
    for name, vals in (("x", x), ("wq", wq), ("wk", wk), ("wv", wv),
                       ("wo", wo)):
        open(os.path.join(wd, name + ".bin"), "wb").write(f16bytes(vals))
    code = """
    # case %(id)s: mha seq=%(seq)d nh=%(nh)d hd=%(hd)d
    var raw_x = load_raw("%(wd)s/x.bin", %(xn2)d)
    var raw_wq = load_raw("%(wd)s/wq.bin", %(wn2)d)
    var raw_wk = load_raw("%(wd)s/wk.bin", %(wn2)d)
    var raw_wv = load_raw("%(wd)s/wv.bin", %(wn2)d)
    var raw_wo = load_raw("%(wd)s/wo.bin", %(wn2)d)
    var x = raw_x.unsafe_ptr().unsafe_bitcast[Float16]()
    var wq = raw_wq.unsafe_ptr().unsafe_bitcast[Float16]()
    var wk = raw_wk.unsafe_ptr().unsafe_bitcast[Float16]()
    var wv = raw_wv.unsafe_ptr().unsafe_bitcast[Float16]()
    var wo = raw_wo.unsafe_ptr().unsafe_bitcast[Float16]()
    var o = unsafe_alloc[Float16](%(dmn)d)
    mha_forward_seq(x, wq, wk, wv, wo, o, %(seq)d, %(nh)d, %(hd)d, Float32(10000))
    var out_raw = new_out(%(dmn2)d)
    var outp = out_raw.unsafe_ptr().unsafe_bitcast[Float16]()
    for i in range(%(dmn)d):
        outp[unsafe_offset=i] = o[unsafe_offset=i]
    store_raw("%(wd)s/out.bin", out_raw)
""" % {"id": case["id"], "seq": seq, "nh": nh, "hd": hd, "wd": wd,
       "xn2": seq * dm * 2, "wn2": dm * dm * 2, "dmn": seq * dm,
       "dmn2": seq * dm * 2}

    def rope_ref(vec, pos):
        out = []
        for i in range(hd // 2):
            ang = pos * theta ** (-2.0 * i / hd)
            co, si = math.cos(ang), math.sin(ang)
            x0, x1 = vec[2 * i], vec[2 * i + 1]
            out += [x0 * co - x1 * si, x0 * si + x1 * co]
        return out

    def verify(wd):
        got = read_f16(os.path.join(wd, "out.bin"))

        def proj(mat, w):
            # mat: seq x dm, w: dm x dm -> seq x dm (fp64)
            return [[sum(mat[s][e] * float(w[e * dm + d]) for e in range(dm))
                     for d in range(dm)] for s in range(seq)]

        xm = [[float(x[s * dm + d]) for d in range(dm)] for s in range(seq)]
        qm = proj(xm, wq)
        km = proj(xm, wk)
        vm = proj(xm, wv)
        inv = 1.0 / math.sqrt(hd)
        ctx = []
        for s in range(seq):
            row = []
            for h in range(nh):
                qh = rope_ref([qm[s][h * hd + d] for d in range(hd)], s)
                kh = [rope_ref([km[t][h * hd + d] for d in range(hd)], t)
                      for t in range(seq)]
                vh = [[float(vm[t][h * hd + d]) for d in range(hd)]
                      for t in range(seq)]
                scores = [sum(qh[d] * kh[t][d] for d in range(hd)) * inv
                          for t in range(s + 1)]
                m = max(scores)
                es = [math.exp(sc - m) for sc in scores]
                esum = sum(es)
                for d in range(hd):
                    acc = sum(es[t] / esum * vh[t][d] for t in range(s + 1))
                    row.append(acc)
            ctx.append(row)
        ref = []
        for s in range(seq):
            for d in range(dm):
                v = sum(ctx[s][e] * float(wo[e * dm + d]) for e in range(dm))
                ref.append(f16(v))
        maxerr, excess = check_ulp(got, ref, case["base"])
        return excess <= 0, "maxerr=%.6g ulp_excess=%.6g" % (maxerr, excess)

    return code, verify


EMITTERS = {
    "gemm_micro_8x8": mojo_case_gemm_micro,
    "gemm_fp16": mojo_case_gemm,
    "gemv_fp16": mojo_case_gemv,
    "elem_add": mojo_case_elem,
    "elem_mul": mojo_case_elem,
    "elem_scale": mojo_case_elem,
    "elem_axpy": mojo_case_elem,
    "layernorm_fp16": mojo_case_layernorm,
    "rmsnorm_fp16": mojo_case_rmsnorm,
    "softmax_fp16": lambda c, w: mojo_case_softmax(c, w, False),
    "softmax_masked_fp16": lambda c, w: mojo_case_softmax(c, w, True),
    "silu_fp16": mojo_case_act,
    "gelu_fp16": mojo_case_act,
    "rope_fp16": mojo_case_rope,
    "fp32_to_fp16": mojo_case_fp32_to_fp16,
    "q80_roundtrip": mojo_case_qroundtrip,
    "q40_roundtrip": mojo_case_qroundtrip,
    "q80_gemm": mojo_case_q80_gemm,
    "attn_sdpa_causal_fp16": mojo_case_attn,
    "mha_forward_seq": mojo_case_mha,
}


def main():
    workdir = "/tmp/oracle_work"
    repo = None
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--work-dir" and i + 1 < len(args):
            workdir = args[i + 1]
            i += 2
        elif args[i] == "--repo" and i + 1 < len(args):
            repo = args[i + 1]
            i += 2
        else:
            print("unknown arg:", args[i], file=sys.stderr)
            return 2
    if repo is None:
        # prof/armvegr/test_kernel_oracles.py -> repo root
        repo = os.path.dirname(os.path.dirname(os.path.dirname(
            os.path.abspath(__file__))))
    corpus_path = os.path.join(repo, "data", "armvegr", "oracle_corpus.json")
    with open(corpus_path) as f:
        corpus = json.load(f)
    print("H037 PRÓF oracle suite -- corpus v%d, %d cases" % (
        corpus["version"], len(corpus["cases"])))
    os.makedirs(workdir, exist_ok=True)

    chunks = [MOJO_HEADER]
    verifiers = []
    for case in corpus["cases"]:
        casedir = os.path.join(workdir, case["id"])
        os.makedirs(casedir, exist_ok=True)
        emitter = EMITTERS[case["kernel"]]
        code, verify = emitter(case, casedir)
        chunks.append(code)
        verifiers.append((case["id"], verify, casedir))

    gen_path = os.path.join(workdir, "oracle_gen.mojo")
    with open(gen_path, "w") as f:
        f.write("\n".join(chunks))
    bin_path = os.path.join(workdir, "oracle_gen")
    print("building oracle binary ...")
    r = subprocess.run(
        ["/usr/local/bin/mojo", "build", "-I", repo, "-o", bin_path, gen_path],
        capture_output=True, text=True, timeout=600)
    if r.returncode != 0:
        print("ORACLE BUILD FAILED")
        print(r.stdout[-4000:])
        print(r.stderr[-4000:])
        return 1
    print("running oracle binary ...")
    r = subprocess.run([bin_path], capture_output=True, text=True, timeout=900)
    if r.returncode != 0:
        print("ORACLE RUN FAILED (exit %d)" % r.returncode)
        print(r.stdout[-4000:])
        print(r.stderr[-4000:])
        return 1

    fails = 0
    for cid, verify, casedir in verifiers:
        try:
            ok, detail = verify(casedir)
        except Exception as e:  # noqa: BLE001 -- fail-closed: any error fails
            ok, detail = False, "verifier raised %r" % e
        if ok:
            print("PASS H037 %s %s" % (cid, detail))
        else:
            print("FAIL H037 %s %s" % (cid, detail))
            fails += 1
    print("H037: %d/%d cases passed" % (
        len(verifiers) - fails, len(verifiers)))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
