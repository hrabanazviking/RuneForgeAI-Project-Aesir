"""A-043 bench: CPU fused attention (flash_attention_gqa).

A-037 census row C-002 puts flash_attention_gqa at 17.93% of
decode self-time -- the second-hottest symbol in the engine.
At the A-043 base the production body is fully scalar: the QK^T
dot, the P*V accumulate, the accumulator zeroing and the final
normalization are all per-element loops, and the query row is
re-loaded and re-cast from F16 for every key position.

This bench times, per decode shape (query rows == 1):
- prod:   the production flash_attention_gqa from core.compute
- scalar: gqa_scalar_reference_a043 below, a verbatim copy of
  the pre-A-043 production body kept in-file as the reference

Run this file on the unmodified base for the BEFORE rows and
again after the A-043 kernel change for the AFTER rows; the
scalar leg is identical in both runs, so prod-vs-scalar is the
honest before/after comparison. Parity per shape: bitwise-equal
count + max abs diff, prod vs scalar on identical inputs --
kernel-level slice, no prompt surface, so raw-oracle discipline
reduces to exact input identity, guaranteed by the fixed-seed
LCG fixtures (seed 0xA043). Timings: CLOCK_MONOTONIC nanoseconds
around the compute calls only, median of reps after one warmup,
single-threaded direct calls.
"""

from std.ffi import external_call
from std.math import exp, max, tanh
from std.memory.alloc import alloc, Layout
from core.mimir_well import MimirWell, RuneTensor, f16, f32
from core.compute import flash_attention_gqa


def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("A043 clock")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


struct Lcg:
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


def median(mut xs: List[Int]) -> Int:
    for i in range(1, len(xs)):
        var v = xs[i]
        var j = i - 1
        while j >= 0 and xs[j] > v:
            xs[j + 1] = xs[j]
            j -= 1
        xs[j + 1] = v
    return xs[len(xs) // 2]


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
    body (scalar loops), kept as the in-file reference oracle."""
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


def run_shape(
    label: String,
    seq_len: Int,
    head_dim: Int,
    q_heads: Int,
    kv_heads: Int,
    inner: Int,
    reps: Int,
) raises:
    var well = MimirWell(64 * 1024 * 1024)
    var q = RuneTensor[f16](1, q_heads * head_dim, well.allocate(q_heads * head_dim))
    var k = RuneTensor[f16](seq_len, kv_heads * head_dim, well.allocate(seq_len * kv_heads * head_dim))
    var v = RuneTensor[f16](seq_len, kv_heads * head_dim, well.allocate(seq_len * kv_heads * head_dim))
    var out_prod = RuneTensor[f16](1, q_heads * head_dim, well.allocate(q_heads * head_dim))
    var out_ref = RuneTensor[f16](1, q_heads * head_dim, well.allocate(q_heads * head_dim))
    var lcg = Lcg(0xA043)
    for i in range(q.size):
        q.data.unsafe_store(i, (lcg.unit() * 2.0 - 1.0).cast[f16]())
    for i in range(k.size):
        k.data.unsafe_store(i, (lcg.unit() * 2.0 - 1.0).cast[f16]())
    for i in range(v.size):
        v.data.unsafe_store(i, (lcg.unit() * 2.0 - 1.0).cast[f16]())

    # Parity on identical inputs (one call each).
    flash_attention_gqa(q, k, v, out_prod, seq_len, head_dim, q_heads, kv_heads)
    gqa_scalar_reference_a043(q, k, v, out_ref, seq_len, head_dim, q_heads, kv_heads)
    var n = q_heads * head_dim
    var bits_p = out_prod.data.unsafe_bitcast[UInt16]()
    var bits_r = out_ref.data.unsafe_bitcast[UInt16]()
    var equal = 0
    var max_abs: Float32 = 0.0
    var sink: Float32 = 0.0
    for i in range(n):
        if bits_p.unsafe_load(i) == bits_r.unsafe_load(i):
            equal += 1
        var d = out_prod.data.unsafe_load(i).cast[f32]() - out_ref.data.unsafe_load(i).cast[f32]()
        if d < 0:
            d = -d
        if d > max_abs:
            max_abs = d
        sink += out_prod.data.unsafe_load(i).cast[f32]()
    print(
        "A043_PARITY shape=" + label + " elements=" + String(n)
        + " bitwise=" + String(equal) + " max_abs_diff=" + String(max_abs)
        + " sink=" + String(sink)
    )

    # Warmup (both legs).
    for _ in range(2):
        flash_attention_gqa(q, k, v, out_prod, seq_len, head_dim, q_heads, kv_heads)
        gqa_scalar_reference_a043(q, k, v, out_ref, seq_len, head_dim, q_heads, kv_heads)

    var prod_times = List[Int]()
    for _ in range(reps):
        var t0 = monotonic_ns()
        for _ in range(inner):
            flash_attention_gqa(q, k, v, out_prod, seq_len, head_dim, q_heads, kv_heads)
        var t1 = monotonic_ns()
        prod_times.append((t1 - t0) // inner)
    var ref_times = List[Int]()
    for _ in range(reps):
        var t0 = monotonic_ns()
        for _ in range(inner):
            gqa_scalar_reference_a043(q, k, v, out_ref, seq_len, head_dim, q_heads, kv_heads)
        var t1 = monotonic_ns()
        ref_times.append((t1 - t0) // inner)
    var prod_med = median(prod_times)
    var ref_med = median(ref_times)
    print(
        "A043_TIME shape=" + label + " seq=" + String(seq_len)
        + " head_dim=" + String(head_dim) + " q_heads=" + String(q_heads)
        + " kv_heads=" + String(kv_heads)
        + " prod_ns_per_call=" + String(prod_med)
        + " scalar_ns_per_call=" + String(ref_med)
        + " speedup=" + String(Float64(ref_med) / Float64(prod_med))
    )


def main() raises:
    print("A043_BENCH fused attention (flash_attention_gqa) prod vs scalar reference")
    run_shape("decode128_hd64_q8kv2", 128, 64, 8, 2, 50, 7)
    run_shape("decode512_hd64_q8kv2", 512, 64, 8, 2, 20, 7)
    run_shape("decode1024_hd64_q8kv2", 1024, 64, 8, 2, 10, 7)
    run_shape("decode512_hd128_q32kv8", 512, 128, 32, 8, 5, 7)
    run_shape("decode256_hd40_q6kv3", 256, 40, 6, 3, 30, 7)
    run_shape("decode512_hd64_q8kv8", 512, 64, 8, 8, 20, 7)
    print("A043_BENCH_DONE")
