# H026 — FP16 layernorm, numerically careful.
#
# y = (x - mean) / sqrt(var + eps) * w + b
# mean and variance accumulate in FP32 (8-wide NEON), because layernorm
# error compounds across transformer layers: an fp16 accumulator on
# n=8192 would smear the variance by ~1e-2. The variance uses the
# E[x^2] - mean^2 form in fp32 and is clamped at zero against
# catastrophic cancellation; with eps > 0 the output is always finite,
# including for constant (zero-variance) inputs.

from std.math import sqrt
from std.memory import Pointer
from std.origin import MutUntrackedOrigin


def layernorm_fp16(
    x: Pointer[Float16, MutUntrackedOrigin],
    w: Pointer[Float16, MutUntrackedOrigin],
    b: Pointer[Float16, MutUntrackedOrigin],
    y: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
    eps: Float32,
):
    var vsum = SIMD[DType.float32, 8](0)
    var vsq = SIMD[DType.float32, 8](0)
    var i = 0
    while i + 8 <= n:
        var v = x.unsafe_offset(i).unsafe_load[8]().cast[DType.float32]()
        vsum = vsum + v
        vsq = vsq + v * v
        i += 8
    var tail_sum = Float32(0)
    var tail_sq = Float32(0)
    for kk in range(i, n):
        var v = Float32(x[unsafe_offset=kk])
        tail_sum += v
        tail_sq += v * v
    var mean = (vsum.reduce_add() + tail_sum) / Float32(n)
    var variance = (vsq.reduce_add() + tail_sq) / Float32(n) - mean * mean
    if variance < Float32(0):
        variance = Float32(0)
    var inv = Float32(1) / sqrt(SIMD[DType.float32, 1](variance + eps))[0]
    var j = 0
    while j + 8 <= n:
        var v = x.unsafe_offset(j).unsafe_load[8]().cast[DType.float32]()
        var wv = w.unsafe_offset(j).unsafe_load[8]().cast[DType.float32]()
        var bv = b.unsafe_offset(j).unsafe_load[8]().cast[DType.float32]()
        var yn = (v - mean) * inv * wv + bv
        y.unsafe_store(j, yn.cast[DType.float16]())
        j += 8
    for kk in range(j, n):
        var yn = (Float32(x[unsafe_offset=kk]) - mean) * inv * Float32(
            w[unsafe_offset=kk]
        ) + Float32(b[unsafe_offset=kk])
        y[unsafe_offset=kk] = Float16(yn)
