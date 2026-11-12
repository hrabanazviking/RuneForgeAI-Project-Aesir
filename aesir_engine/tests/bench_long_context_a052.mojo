"""A-052 bench: Long context on CPU -- the timed 32k run.

Roadmap acceptance: a 32k-token context run completes; KV
growth is accounted; correctness spot-checks at depth pass;
needle-style depth probes pass at filed rates. The filed
design (depths, pattern, tolerance, rates) lives in
core/long_context_cpu.mojo, shared verbatim with the E-MASTER
cases in tests/test_long_context_a052.mojo; this bench is the
timed 2-layer form of the same run.

Legs:
1. Growth: a KVCache of 2 layers x 32,768 positions x 64 dims
   is filled token by token through KVCache.append (the
   production host cache; fixed capacity, raises past the
   wall). Wall time and the census-priced byte growth are
   printed per checkpoint.
2. Readback: sampled positions across the full depth are
   compared exactly (pattern and needle values are F16-exact
   dyadic by construction) -- K and V, every dim.
3. Probes: for each layer and each of the 7 filed needle
   depths, a decode-step query (32.0 * e_j) runs through the
   production flash_attention_gqa over all 32,768 positions;
   the recovered row must match the needle value with max abs
   diff <= 0.010 (filed), rate filed at 14/14 across layers.

Honest boundary: the engine session path clamps context to
16,000 (HOST_RUNTIME_CONTEXT_CAP), so this is a KV +
attention-layer run -- the layer the session path is built
on -- not an AesirEngine session. The bench prints the
session-cap verdict beside its own results. CPU only; no
accelerator claim. Timings: CLOCK_MONOTONIC around the fill
only; single-threaded direct calls.
"""

from std.ffi import external_call
from core.compute import flash_attention_gqa
from core.long_context_cpu import (
    LONG_CONTEXT_HEAD_DIM,
    LONG_CONTEXT_TOKENS,
    NEEDLE_COUNT,
    kv_growth_bp,
    long_context_kv_bytes,
    needle_depth,
    needle_index_at,
    needle_value,
    pattern_component,
    pattern_value_component,
    probe_max_abs_diff,
    probe_passes,
    probe_rate_bp,
    session_cap_verdict,
    session_cap_verdict_name,
)
from core.mimir_well import KVCache, MimirWell, RuneTensor, f16, f32

comptime BENCH_LAYERS = 2


def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("A052 clock")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


def expected_k(pos: Int, d: Int) -> Float32:
    var nj = needle_index_at(pos)
    if nj >= 0:
        if d == nj:
            return Float32(8.0)
        return Float32(0.0)
    return pattern_component(pos, d)


def expected_v(pos: Int, d: Int) -> Float32:
    var nj = needle_index_at(pos)
    if nj >= 0:
        return needle_value(nj)
    return pattern_value_component(pos, d)


def main() raises:
    print("A052_BENCH long_context_cpu layers=" + String(BENCH_LAYERS) + " tokens=" + String(LONG_CONTEXT_TOKENS) + " head_dim=" + String(LONG_CONTEXT_HEAD_DIM))
    print(
        "A052_BENCH_SESSION_CAP tokens=" + String(LONG_CONTEXT_TOKENS)
        + " verdict=" + session_cap_verdict_name(session_cap_verdict(LONG_CONTEXT_TOKENS))
        + " cap=16000"
    )
    # Growth account, priced by the tree census arithmetic.
    for t in range(5):
        var tokens = 1024
        if t == 1:
            tokens = 4096
        elif t == 2:
            tokens = 8192
        elif t == 3:
            tokens = 16384
        elif t == 4:
            tokens = 32768
        print(
            "A052_BENCH_GROWTH tokens=" + String(tokens)
            + " bench_shape_bytes=" + String(long_context_kv_bytes(BENCH_LAYERS, 1, LONG_CONTEXT_HEAD_DIM, tokens))
            + " headline_32l_8kv_128d_bytes=" + String(long_context_kv_bytes(32, 8, 128, tokens))
            + " growth_bp=" + String(kv_growth_bp(tokens, LONG_CONTEXT_TOKENS))
        )
    var well = MimirWell(128 * 1024 * 1024)
    var cache = KVCache(LONG_CONTEXT_TOKENS, LONG_CONTEXT_HEAD_DIM, well, BENCH_LAYERS)
    var krow = RuneTensor[f16](1, LONG_CONTEXT_HEAD_DIM, well.allocate(LONG_CONTEXT_HEAD_DIM))
    var vrow = RuneTensor[f16](1, LONG_CONTEXT_HEAD_DIM, well.allocate(LONG_CONTEXT_HEAD_DIM))
    var t0 = monotonic_ns()
    for layer in range(BENCH_LAYERS):
        for pos in range(LONG_CONTEXT_TOKENS):
            for d in range(LONG_CONTEXT_HEAD_DIM):
                krow.data.unsafe_store(d, expected_k(pos, d).cast[f16]())
                vrow.data.unsafe_store(d, expected_v(pos, d).cast[f16]())
            cache.append(layer, pos, krow, vrow)
    var fill_ns = monotonic_ns() - t0
    print(
        "A052_BENCH_FILL appends=" + String(BENCH_LAYERS * LONG_CONTEXT_TOKENS)
        + " wall_ns=" + String(fill_ns)
        + " ns_per_append=" + String(fill_ns // (BENCH_LAYERS * LONG_CONTEXT_TOKENS))
    )
    # Readback spot-checks at depth, both layers, exact.
    var spots = List[Int]()
    spots.append(0)
    spots.append(1)
    spots.append(1023)
    spots.append(1024)
    spots.append(4095)
    spots.append(4096)
    spots.append(8192)
    spots.append(16384)
    spots.append(24576)
    spots.append(30720)
    spots.append(32766)
    spots.append(32767)
    var checked = 0
    var mismatches = 0
    for layer in range(BENCH_LAYERS):
        var ks = cache.get_k_slice(layer, LONG_CONTEXT_TOKENS)
        var vs = cache.get_v_slice(layer, LONG_CONTEXT_TOKENS)
        for si in range(len(spots)):
            var pos = spots[si]
            for d in range(LONG_CONTEXT_HEAD_DIM):
                var idx = pos * LONG_CONTEXT_HEAD_DIM + d
                checked += 2
                if ks.data.unsafe_load(idx).cast[f32]() != expected_k(pos, d):
                    mismatches += 1
                if vs.data.unsafe_load(idx).cast[f32]() != expected_v(pos, d):
                    mismatches += 1
    print(
        "A052_BENCH_READBACK checked=" + String(checked)
        + " mismatches=" + String(mismatches)
    )
    if mismatches != 0:
        raise Error("A052 bench: readback mismatches at depth")
    # Needle probes at depth, per layer, through the production
    # attention kernel over the full 32k sequence.
    var q = RuneTensor[f16](1, LONG_CONTEXT_HEAD_DIM, well.allocate(LONG_CONTEXT_HEAD_DIM))
    var out = RuneTensor[f16](1, LONG_CONTEXT_HEAD_DIM, well.allocate(LONG_CONTEXT_HEAD_DIM))
    var passed = 0
    var total = 0
    var worst = Float32(0.0)
    for layer in range(BENCH_LAYERS):
        var ks = cache.get_k_slice(layer, LONG_CONTEXT_TOKENS)
        var vs = cache.get_v_slice(layer, LONG_CONTEXT_TOKENS)
        for j in range(NEEDLE_COUNT):
            for d in range(LONG_CONTEXT_HEAD_DIM):
                var qv = Float32(0.0)
                if d == j:
                    qv = Float32(32.0)
                q.data.unsafe_store(d, qv.cast[f16]())
                out.data.unsafe_store(d, Float32(0.0).cast[f16]())
            var p0 = monotonic_ns()
            flash_attention_gqa(q, ks, vs, out, LONG_CONTEXT_TOKENS, LONG_CONTEXT_HEAD_DIM, 1, 1)
            var probe_ns = monotonic_ns() - p0
            var row = List[Float32]()
            for d in range(LONG_CONTEXT_HEAD_DIM):
                row.append(out.data.unsafe_load(d).cast[f32]())
            var diff = probe_max_abs_diff(row, needle_value(j))
            if diff > worst:
                worst = diff
            total += 1
            if probe_passes(diff):
                passed += 1
            print(
                "A052_BENCH_PROBE layer=" + String(layer)
                + " needle=" + String(j)
                + " depth=" + String(needle_depth(j))
                + " max_abs_diff=" + String(diff)
                + " wall_ns=" + String(probe_ns)
            )
    print(
        "A052_BENCH_PROBES passed=" + String(passed) + "/" + String(total)
        + " rate_bp=" + String(probe_rate_bp(passed, total))
        + " worst_max_abs_diff=" + String(worst)
    )
    if passed != total:
        raise Error("A052 bench: needle probes below filed rate")
    print("A052_BENCH_VERDICT PASS")
