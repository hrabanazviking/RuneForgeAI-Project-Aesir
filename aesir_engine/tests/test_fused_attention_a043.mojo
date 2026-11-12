"""A-043: CPU fused attention -- SIMD parity regressions.

flash_attention_gqa (aesir_engine/core/compute.mojo) was fully
scalar at the A-043 base (A-037 census row C-002: 17.93% of
decode self-time). A-043 preloads the query head once as F32 and
runs the QK^T dot, the P*V accumulate, the accumulator zeroing
and the final normalization as width-16 SIMD with scalar tails,
and skips the online-softmax rescale exp() on positions where
the running max did not move (exp(0) == 1 exactly).

These cases pin the optimized kernel against
gqa_scalar_reference_a043 below, a verbatim copy of the
pre-A-043 scalar production body:

- general LCG data: max abs diff within the filed fast-path
  bound (the QK^T reduction order is the only numerics change);
- dyadic data: every product and partial sum is exact in F32
  under any reduction order, so the outputs must agree BITWISE;
- unaligned head_dim (40, 24): the scalar tails must match;
- architecture modifiers (attn_scale, softcap, sliding
  window): the modified paths must match the scalar body;
- a long wide shape (seq 300, head_dim 128): bound holds.
"""

from std.math import exp, max, tanh
from std.memory.alloc import alloc, Layout
from core.mimir_well import MimirWell, RuneTensor, f16, f32
from core.compute import flash_attention_gqa


def gqa_scalar_reference_a043(
    query: RuneTensor[f16],
    keys: RuneTensor[f16],
    values: RuneTensor[f16],
    mut output: RuneTensor[f16],
    sequence_length: Int,
    head_dim: Int,
    query_head_count: Int,
    kv_head_count: Int,
    attn_scale: Scalar[f32] = Scalar[f32](0.0),
    softcap: Scalar[f32] = Scalar[f32](0.0),
    sliding_window: Int = 0,
    query_pos: Int = 0,
):
    """Verbatim copy of the pre-A-043 production flash_attention_gqa
    body (scalar loops), kept as the reference oracle."""
    if sequence_length <= 0 or query.rows != 1 or output.rows != 1:
        return
    if query_head_count <= 0 or kv_head_count <= 0 or head_dim <= 0:
        return
    if query_head_count % kv_head_count != 0:
        return
    var query_heads_per_kv = query_head_count // kv_head_count
    var scale = (1.0 / (Float64(head_dim) ** 0.5)).cast[f32]()
    if attn_scale != Scalar[f32](0.0):
        scale = attn_scale

    var acc = alloc(Layout[Scalar[f32]](count=head_dim)).unsafe_leak()
    for query_head in range(query_head_count):
        var kv_head = query_head // query_heads_per_kv
        var query_base = query_head * head_dim
        var output_base = query_head * head_dim
        for dimension in range(head_dim):
            acc.unsafe_store(dimension, 0.0)

        var running_max: Scalar[f32] = -1e20
        var running_sum: Scalar[f32] = 0.0
        for position in range(sequence_length):
            if sliding_window > 0 and query_pos - position >= sliding_window:
                continue
            var key_base = position * keys.cols + kv_head * head_dim
            var value_base = position * values.cols + kv_head * head_dim
            var score: Scalar[f32] = 0.0
            for dimension in range(head_dim):
                score += (
                    query.data.unsafe_load(query_base + dimension).cast[f32]()
                    * keys.data.unsafe_load(key_base + dimension).cast[f32]()
                )
            score *= scale
            if softcap > Scalar[f32](0.0):
                score = softcap * tanh(score / softcap)
            var next_max = max(running_max, score)
            var previous_scale = exp(running_max - next_max)
            var probability = exp(score - next_max)
            var next_sum = running_sum * previous_scale + probability

            for dimension in range(head_dim):
                var previous = acc.unsafe_load(dimension)
                var value = values.data.unsafe_load(
                    value_base + dimension
                ).cast[f32]()
                acc.unsafe_store(dimension, previous * previous_scale + probability * value)
            running_max = next_max
            running_sum = next_sum

        for dimension in range(head_dim):
            var accumulated = acc.unsafe_load(dimension)
            output.data.unsafe_store(
                output_base + dimension,
                (accumulated / running_sum).cast[f16](),
            )
    acc.unsafe_free()


struct _Lcg:
    var state: UInt64

    def __init__(out self, seed: UInt64):
        self.state = seed

    def next(mut self) -> UInt64:
        self.state = (
            self.state * 6364136223846793005 + 1442695040888963407
        )
        return self.state >> 11

    def unit(mut self) -> Float32:
        return Float32(self.next() & 0xFFFFFF) / Float32(16777216.0)


def _parity(
    label: String,
    seq_len: Int,
    head_dim: Int,
    q_heads: Int,
    kv_heads: Int,
    attn_scale: Scalar[f32],
    softcap: Scalar[f32],
    sliding_window: Int,
    query_pos: Int,
    dyadic: Bool,
    tol: Float32,
    require_bitwise: Bool,
) raises:
    var well = MimirWell(64 * 1024 * 1024)
    var q = RuneTensor[f16](1, q_heads * head_dim, well.allocate(q_heads * head_dim))
    var k = RuneTensor[f16](seq_len, kv_heads * head_dim, well.allocate(seq_len * kv_heads * head_dim))
    var v = RuneTensor[f16](seq_len, kv_heads * head_dim, well.allocate(seq_len * kv_heads * head_dim))
    var out_prod = RuneTensor[f16](1, q_heads * head_dim, well.allocate(q_heads * head_dim))
    var out_ref = RuneTensor[f16](1, q_heads * head_dim, well.allocate(q_heads * head_dim))
    if dyadic:
        for i in range(q.size):
            q.data.unsafe_store(i, (Float32(((i * 7 + 3) % 9) - 4) * 0.25).cast[f16]())
        for i in range(k.size):
            k.data.unsafe_store(i, (Float32(((i * 5 + 1) % 9) - 4) * 0.25).cast[f16]())
        for i in range(v.size):
            v.data.unsafe_store(i, (Float32(((i * 3 + 2) % 9) - 4) * 0.25).cast[f16]())
    else:
        var lcg = _Lcg(0xA043)
        for i in range(q.size):
            q.data.unsafe_store(i, (lcg.unit() * 2.0 - 1.0).cast[f16]())
        for i in range(k.size):
            k.data.unsafe_store(i, (lcg.unit() * 2.0 - 1.0).cast[f16]())
        for i in range(v.size):
            v.data.unsafe_store(i, (lcg.unit() * 2.0 - 1.0).cast[f16]())
    flash_attention_gqa(
        q, k, v, out_prod, seq_len, head_dim, q_heads, kv_heads,
        attn_scale, softcap, sliding_window, query_pos,
    )
    gqa_scalar_reference_a043(
        q, k, v, out_ref, seq_len, head_dim, q_heads, kv_heads,
        attn_scale, softcap, sliding_window, query_pos,
    )
    var n = q_heads * head_dim
    var bits_p = out_prod.data.unsafe_bitcast[UInt16]()
    var bits_r = out_ref.data.unsafe_bitcast[UInt16]()
    var equal = 0
    var max_abs: Float32 = 0.0
    for i in range(n):
        if bits_p.unsafe_load(i) == bits_r.unsafe_load(i):
            equal += 1
        var d = out_prod.data.unsafe_load(i).cast[f32]() - out_ref.data.unsafe_load(i).cast[f32]()
        if d < 0:
            d = -d
        if d > max_abs:
            max_abs = d
    print(
        "A043_TEST_PARITY case=" + label + " elements=" + String(n)
        + " bitwise=" + String(equal) + " max_abs_diff=" + String(max_abs)
    )
    if require_bitwise and equal != n:
        raise Error("A043: " + label + " must be bitwise vs scalar reference")
    if max_abs > tol:
        raise Error("A043: " + label + " max_abs_diff exceeds filed bound")


def test_gqa_simd_reference_parity() raises:
    """General LCG data, decode shape seq=37 head_dim=64 q8:kv2."""
    _parity("reference", 37, 64, 8, 2, Scalar[f32](0.0), Scalar[f32](0.0), 0, 0, False, 0.01, False)


def test_gqa_simd_dyadic_bitwise() raises:
    """Dyadic data: exact under any reduction order -> bitwise."""
    _parity("dyadic", 16, 64, 4, 2, Scalar[f32](0.0), Scalar[f32](0.0), 0, 0, True, 0.0, True)


def test_gqa_simd_tail_parity() raises:
    """Unaligned head_dim 40 and 24: scalar tails must match."""
    _parity("tail40", 19, 40, 6, 3, Scalar[f32](0.0), Scalar[f32](0.0), 0, 0, False, 0.01, False)
    _parity("tail24", 11, 24, 4, 4, Scalar[f32](0.0), Scalar[f32](0.0), 0, 0, False, 0.01, False)


def test_gqa_simd_modifiers_parity() raises:
    """attn_scale + softcap + sliding window vs the scalar body."""
    _parity("modifiers", 13, 32, 4, 2, Scalar[f32](0.05), Scalar[f32](8.0), 5, 12, False, 0.01, False)


def test_gqa_simd_long_parity() raises:
    """Long wide shape: seq=300 head_dim=128 q16:kv4."""
    _parity("long", 300, 128, 16, 4, Scalar[f32](0.0), Scalar[f32](0.0), 0, 0, False, 0.01, False)
