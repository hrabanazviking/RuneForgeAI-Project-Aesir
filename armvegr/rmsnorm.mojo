# H027 — RMSNorm (the norm used by Llama-family models).
#
# y = x / sqrt(mean(x^2) + eps) * w
# No mean subtraction: this is a different operation from layernorm, not
# a copy of it (the H027 acceptance includes a test proving RMSNorm !=
# Layernorm on the same input, guarding against copy-paste between H026
# and H027). Shares only the accumulation discipline: fp32 NEON
# accumulators, epsilon handling, zero-clamp on the mean-square.

from std.math import sqrt
from std.memory import Pointer
from std.origin import MutUntrackedOrigin


def rmsnorm_fp16(
    x: Pointer[Float16, MutUntrackedOrigin],
    w: Pointer[Float16, MutUntrackedOrigin],
    y: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
    eps: Float32,
):
    var vsq = SIMD[DType.float32, 8](0)
    var i = 0
    while i + 8 <= n:
        var v = x.unsafe_offset(i).unsafe_load[8]().cast[DType.float32]()
        vsq = vsq + v * v
        i += 8
    var tail_sq = Float32(0)
    for kk in range(i, n):
        var v = Float32(x[unsafe_offset=kk])
        tail_sq += v * v
    var ms = (vsq.reduce_add() + tail_sq) / Float32(n)
    if ms < Float32(0):
        ms = Float32(0)
    var inv = Float32(1) / sqrt(SIMD[DType.float32, 1](ms + eps))[0]
    var j = 0
    while j + 8 <= n:
        var v = x.unsafe_offset(j).unsafe_load[8]().cast[DType.float32]()
        var wv = w.unsafe_offset(j).unsafe_load[8]().cast[DType.float32]()
        var yn = v * inv * wv
        y.unsafe_store(j, yn.cast[DType.float16]())
        j += 8
    for kk in range(j, n):
        var yn = Float32(x[unsafe_offset=kk]) * inv * Float32(w[unsafe_offset=kk])
        y[unsafe_offset=kk] = Float16(yn)
