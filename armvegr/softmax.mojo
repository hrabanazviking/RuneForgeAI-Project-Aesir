# H028 — FP16 softmax, numerically stable.
#
# y[i] = exp(x[i] - max) / sum(exp(x - max)); accumulation in fp32.
# The max-subtraction is what keeps this from silently producing NaN on
# large logits: with inputs at +-100, naive exp(100) overflows fp32 to
# inf and inf/inf = NaN. Here the largest exponent argument is 0.
# Masked variant: positions >= valid_len are forced to -1e30 before the
# max pass, so they contribute exactly 0.0 (exp underflows to zero) and
# the unmasked entries still sum to 1.

from std.math import exp
from std.memory import Pointer
from std.origin import MutUntrackedOrigin


def softmax_fp16(
    x: Pointer[Float16, MutUntrackedOrigin],
    y: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
):
    var m = Float32(-1e30)
    var i = 0
    while i + 8 <= n:
        var v = x.unsafe_offset(i).unsafe_load[8]().cast[DType.float32]()
        var lm = v.reduce_max()
        if lm > m:
            m = lm
        i += 8
    for kk in range(i, n):
        var v = Float32(x.unsafe_offset(kk))
        if v > m:
            m = v
    var vsum = SIMD[DType.float32, 8](0)
    var j = 0
    while j + 8 <= n:
        var v = x.unsafe_offset(j).unsafe_load[8]().cast[DType.float32]() - m
        var e = exp(v)
        vsum = vsum + e
        j += 8
    var s = vsum.reduce_add()
    for kk in range(j, n):
        s += exp(SIMD[DType.float32, 1](Float32(x.unsafe_offset(kk)) - m))[0]
    var inv = Float32(1) / s
    var k2 = 0
    while k2 + 8 <= n:
        var v = x.unsafe_offset(k2).unsafe_load[8]().cast[DType.float32]() - m
        var yn = exp(v) * inv
        y.unsafe_offset(k2).unsafe_store[8](yn.cast[DType.float16]())
        k2 += 8
    for kk in range(k2, n):
        var e = exp(SIMD[DType.float32, 1](Float32(x.unsafe_offset(kk)) - m))[0]
        y[unsafe_offset=kk] = Float16(e * inv)


def softmax_masked_fp16(
    x: Pointer[Float16, MutUntrackedOrigin],
    y: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
    valid_len: Int,
):
    # Causal-style mask: positions >= valid_len contribute exactly 0.0.
    # Implemented by clamping masked logits to -1e30 (fp32) before the
    # max pass; exp(-1e30 - max) underflows to exactly 0.0.
    var m = Float32(-1e30)
    for kk in range(n):
        var v = Float32(x.unsafe_offset(kk)) if kk < valid_len else Float32(-1e30)
        if v > m:
            m = v
    var s = Float32(0)
    for kk in range(n):
        var v = Float32(x.unsafe_offset(kk)) if kk < valid_len else Float32(-1e30)
        s += exp(SIMD[DType.float32, 1](v - m))[0]
    var inv = Float32(1) / s
    for kk in range(n):
        if kk < valid_len:
            var v = Float32(x.unsafe_offset(kk))
            var e = exp(SIMD[DType.float32, 1](v - m))[0]
            y[unsafe_offset=kk] = Float16(e * inv)
        else:
            y[unsafe_offset=kk] = Float16(0)
