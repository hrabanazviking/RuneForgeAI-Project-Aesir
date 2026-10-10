# H034 — Fused single-head scaled dot-product attention with causal mask.
#
# out[i] = softmax_j<=i( dot(q_i, k_j) / sqrt(d) ) @ V   (fp16 in/out)
# One fused kernel: per query row i, scores for j <= i are computed into
# a small fp32 scratch buffer, softmaxed in place, and immediately
# consumed by the V-weighted sum. The full n x n score matrix is NEVER
# materialized: peak temporary memory is one fp32 score row, i.e.
# O(seq_len) <= O(seq_len x head_dim) for head_dim >= 1, never O(n^2).
# The function returns the peak temporary bytes so the test can assert
# the bound on the 1024 case (instrumented, not asserted).
#
# Causal bit-identical property: row i reads only rows j <= i of K and V
# and its own arithmetic never touches padding, so output row i is
# bit-identical whether the call used seq_len = i+1 or seq_len = 2048.

from std.math import exp, sqrt
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from std.memory.alloc import unsafe_alloc


def attn_sdpa_causal_fp16(
    q: Pointer[Float16, MutUntrackedOrigin],
    k: Pointer[Float16, MutUntrackedOrigin],
    v: Pointer[Float16, MutUntrackedOrigin],
    out: Pointer[Float16, MutUntrackedOrigin],
    seq_len: Int,
    head_dim: Int,
) -> Int64:
    var inv_scale = Float32(1) / sqrt(
        SIMD[DType.float32, 1](Float32(head_dim))
    )[0]
    var scores = unsafe_alloc[Float32](seq_len)
    var peak_bytes = Int64(seq_len * 4)
    for i in range(seq_len):
        # scores[j] for j <= i
        var m = Float32(-1e30)
        for j in range(i + 1):
            var dot = SIMD[DType.float32, 8](0)
            var d = 0
            while d + 8 <= head_dim:
                var qv = q.unsafe_offset(i * head_dim + d).unsafe_load[8]().cast[
                    DType.float32
                ]()
                var kv = k.unsafe_offset(j * head_dim + d).unsafe_load[8]().cast[
                    DType.float32
                ]()
                dot = qv.fma(kv, dot)
                d += 8
            var s = dot.reduce_add()
            for dd in range(d, head_dim):
                s += Float32(q.unsafe_offset(i * head_dim + dd)) * Float32(
                    k.unsafe_offset(j * head_dim + dd)
                )
            var sc = s * inv_scale
            scores[unsafe_offset=j] = sc
            if sc > m:
                m = sc
        var esum = Float32(0)
        for j in range(i + 1):
            var e = exp(SIMD[DType.float32, 1](scores[unsafe_offset=j] - m))[0]
            scores[unsafe_offset=j] = e
            esum += e
        var inv = Float32(1) / esum
        for d2 in range(head_dim):
            var acc = Float32(0)
            for j in range(i + 1):
                acc += scores[unsafe_offset=j] * inv * Float32(
                    v.unsafe_offset(j * head_dim + d2)
                )
            out[unsafe_offset=i * head_dim + d2] = Float16(acc)
    return peak_bytes
