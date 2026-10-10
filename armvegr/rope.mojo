# H030 — RoPE rotary embedding kernel.
#
# Applies rotary position embeddings to a query or key vector of head
# dimension d at position pos with base theta:
#   angle_i = pos * theta^(-2i/d),  i in [0, d/2)
#   (x[2i], x[2i+1]) -> (x[2i] cos a - x[2i+1] sin a,
#                        x[2i] sin a + x[2i+1] cos a)
#
# CONVENTION (documented per H030): interleaved pairs (GPT-NeoX style),
# i.e. pairs are (2i, 2i+1). This matches the Llama-family convention
# used by the small open LLMs this CPU backend targets. The alternative
# "half rotation" (first half rotated against second half) is NOT what
# this implements; mixing the two silently permutes the embedding.
# Position 0 gives angle 0 for all i, hence the identity transform
# (verified by test: catches off-by-one in the angle computation).

from std.math import cos, sin, exp, log
from std.memory import Pointer
from std.origin import MutUntrackedOrigin


def rope_angle(pos: Int, i: Int, head_dim: Int, ln_theta: Float32) -> Float32:
    # theta^(-2i/d) = exp((-2i/d) * ln(theta)); one log per call site,
    # hoisted by the caller.
    var e = -Float32(2 * i) / Float32(head_dim) * ln_theta
    return Float32(pos) * exp(SIMD[DType.float32, 1](e))[0]


def rope_fp16(
    x: Pointer[Float16, MutUntrackedOrigin],
    y: Pointer[Float16, MutUntrackedOrigin],
    head_dim: Int,
    pos: Int,
    theta: Float32,
):
    var half = head_dim // 2
    var ln_theta = log(SIMD[DType.float32, 1](theta))[0]
    var i = 0
    while i + 4 <= half:
        var angs = SIMD[DType.float32, 4](
            rope_angle(pos, i, head_dim, ln_theta),
            rope_angle(pos, i + 1, head_dim, ln_theta),
            rope_angle(pos, i + 2, head_dim, ln_theta),
            rope_angle(pos, i + 3, head_dim, ln_theta),
        )
        var co = cos(angs)
        var si = sin(angs)
        for k in range(4):
            var x0 = Float32(x.unsafe_offset(2 * (i + k)))
            var x1 = Float32(x.unsafe_offset(2 * (i + k) + 1))
            y[unsafe_offset=2 * (i + k)] = Float16(x0 * co[k] - x1 * si[k])
            y[unsafe_offset=2 * (i + k) + 1] = Float16(x0 * si[k] + x1 * co[k])
        i += 4
    for kk in range(i, half):
        var ang = rope_angle(pos, kk, head_dim, ln_theta)
        var co = cos(SIMD[DType.float32, 1](ang))[0]
        var si = sin(SIMD[DType.float32, 1](ang))[0]
        var x0 = Float32(x.unsafe_offset(2 * kk))
        var x1 = Float32(x.unsafe_offset(2 * kk + 1))
        y[unsafe_offset=2 * kk] = Float16(x0 * co - x1 * si)
        y[unsafe_offset=2 * kk + 1] = Float16(x0 * si + x1 * co)
