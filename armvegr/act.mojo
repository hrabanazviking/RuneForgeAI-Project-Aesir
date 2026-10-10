# H029 — Activation kernels: SiLU and GELU in NEON FP16.
#
# SiLU(x) = x * sigmoid(x), sigmoid via exp, computed in fp32.
# GELU uses the tanh approximation (Hendrycks & Gimpel 2016):
#   gelu(x) = 0.5 * x * (1 + tanh(sqrt(2/pi) * (x + 0.044715 * x^3)))
# tanh itself is computed via exp as (e^2z - 1) / (e^2z + 1), guarded:
# for |z| > 10 the exponential overflows fp32, so tanh saturates to
# +-1 there (exact to fp16 output precision).
#
# SÓLRÚN RE-SCOPE (2026-10-10, recorded in MIMISBRUNNR_PROGRESS.md):
# the roadmap asked for "SiLU verified non-decreasing on [-10, 10]".
# That is mathematically false for a correct SiLU: SiLU has a global
# minimum at x ~ -1.2785 (value ~ -0.2785) and decreases on
# (-inf, -1.2785). The test instead verifies (a) non-decreasing on
# [0, 10] (true for SiLU), and (b) the dip: minimum over [-10, 10]
# attained at x in [-1.30, -1.25] with value in [-0.29, -0.27].
# Both catch approximation sign errors at least as well as the
# original (infeasible) criterion.

from std.math import exp, sqrt
from std.memory import Pointer
from std.origin import MutUntrackedOrigin


def tanh_fp32_vec(v: SIMD[DType.float32, 8]) -> SIMD[DType.float32, 8]:
    var e2 = exp(v + v)
    # Guard the overflow regime: |z| > 10 saturates (fp32 exp(20) is
    # already 4.85e8; beyond 44 it is inf and inf/inf = NaN).
    var t = (e2 - Float32(1)) / (e2 + Float32(1))
    var i = 0
    var out = SIMD[DType.float32, 8](0)
    while i < 8:
        var z = v[i]
        var tv = t[i]
        if z > Float32(10):
            tv = Float32(1)
        elif z < Float32(-10):
            tv = Float32(-1)
        out[i] = tv
        i += 1
    return out


def silu_fp16(
    x: Pointer[Float16, MutUntrackedOrigin],
    y: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
):
    var i = 0
    while i + 8 <= n:
        var v = x.unsafe_offset(i).unsafe_load[8]().cast[DType.float32]()
        var sig = Float32(1) / (Float32(1) + exp(-v))
        var yn = v * sig
        y.unsafe_offset(i).unsafe_store[8](yn.cast[DType.float16]())
        i += 8
    for kk in range(i, n):
        var v = Float32(x.unsafe_offset(kk))
        var sig = Float32(1) / (Float32(1) + exp(SIMD[DType.float32, 1](-v))[0])
        y[unsafe_offset=kk] = Float16(v * sig)


def gelu_fp16(
    x: Pointer[Float16, MutUntrackedOrigin],
    y: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
):
    # Tanh approximation, constants from Hendrycks & Gimpel.
    var c0 = sqrt(SIMD[DType.float32, 1](Float32(2.0) / Float32(3.141592653589793)))[0]
    var i = 0
    while i + 8 <= n:
        var v = x.unsafe_offset(i).unsafe_load[8]().cast[DType.float32]()
        var inner = c0 * (v + Float32(0.044715) * v * v * v)
        var yn = Float32(0.5) * v * (Float32(1) + tanh_fp32_vec(inner))
        y.unsafe_offset(i).unsafe_store[8](yn.cast[DType.float16]())
        i += 8
    for kk in range(i, n):
        var v = Float32(x.unsafe_offset(kk))
        var z = c0 * (v + Float32(0.044715) * v * v * v)
        var e2 = exp(SIMD[DType.float32, 1](z + z))[0]
        var t = (e2 - Float32(1)) / (e2 + Float32(1))
        if z > Float32(10):
            t = Float32(1)
        elif z < Float32(-10):
            t = Float32(-1)
        y[unsafe_offset=kk] = Float16(Float32(0.5) * v * (Float32(1) + t))
