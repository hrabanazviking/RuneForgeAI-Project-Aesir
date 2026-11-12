# tests/test_long_context_a052.mojo
# A-052 -- Long context on CPU.
#
# The account, pattern, and grading arithmetic under test lives
# in core/long_context_cpu.mojo and is shared with the
# standalone bench (tests/bench_long_context_a052.mojo), which
# files the timed 2-layer run. These cases pin:
# - KV growth priced by the tree census arithmetic
#   (core/kv_account.mojo) at filed context lengths;
# - the honest session boundary: 32,768 exceeds the engine
#   session cap of 16,000, so the run is proven at the KV +
#   attention layer (see the core module header);
# - the filed needle depths, values, and distractor pattern
#   (dyadic, F16-exact, stateless);
# - probe grading at the filed tolerance (max abs diff
#   <= 0.010) and rate arithmetic;
# - the execution proof itself at suite scale: a KVCache is
#   grown to all 32,768 positions, spot-checked bitwise at
#   depth, refused past capacity, and needle-probed through
#   the production flash_attention_gqa kernel.

from core.compute import flash_attention_gqa
from core.kv_account import HOST_RUNTIME_CONTEXT_CAP
from core.long_context_cpu import (
    CTX_EXCEEDS_SESSION,
    CTX_FITS_SESSION,
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


def _expect(cond: Bool, label: String) raises:
    if not cond:
        raise Error("A-052 " + label)


def _fill_long_cache(
    mut cache: KVCache, mut well: MimirWell
) raises:
    """Grow the cache to every position in [0, 32768): needle
    rows at the filed depths, distractor rows elsewhere. The
    pattern is stateless, so this fill and the independent
    readback below regenerate identical values."""
    var krow = RuneTensor[f16](
        1, LONG_CONTEXT_HEAD_DIM, well.allocate(LONG_CONTEXT_HEAD_DIM)
    )
    var vrow = RuneTensor[f16](
        1, LONG_CONTEXT_HEAD_DIM, well.allocate(LONG_CONTEXT_HEAD_DIM)
    )
    for pos in range(LONG_CONTEXT_TOKENS):
        var nj = needle_index_at(pos)
        for d in range(LONG_CONTEXT_HEAD_DIM):
            var kv: Float32
            var vv: Float32
            if nj >= 0:
                if d == nj:
                    kv = Float32(8.0)
                else:
                    kv = Float32(0.0)
                vv = needle_value(nj)
            else:
                kv = pattern_component(pos, d)
                vv = pattern_value_component(pos, d)
            krow.data.unsafe_store(d, kv.cast[f16]())
            vrow.data.unsafe_store(d, vv.cast[f16]())
        cache.append(0, pos, krow, vrow)


def _expected_k(pos: Int, d: Int) -> Float32:
    var nj = needle_index_at(pos)
    if nj >= 0:
        if d == nj:
            return Float32(8.0)
        return Float32(0.0)
    return pattern_component(pos, d)


def _expected_v(pos: Int, d: Int) -> Float32:
    var nj = needle_index_at(pos)
    if nj >= 0:
        return needle_value(nj)
    return pattern_value_component(pos, d)


def test_long_context_growth_account() raises:
    print("--- A-052 growth: KV bytes vs context length ---")
    # Headline uniform shape: 32 layers, 8 KV heads, head_dim
    # 128, F16 -> 131,072 bytes/token; 32k context = 4 GiB.
    _expect(
        long_context_kv_bytes(32, 8, 128, 32768) == 4294967296,
        "growth 32-layer at 32768",
    )
    _expect(
        long_context_kv_bytes(32, 8, 128, 8192) == 1073741824,
        "growth 32-layer at 8192",
    )
    _expect(
        long_context_kv_bytes(32, 8, 128, 1024) == 134217728,
        "growth 32-layer at 1024",
    )
    # Bench shape: 2 layers, 1 KV head, head_dim 64 -> 512
    # bytes/token; the full 32k cache is 16 MiB.
    _expect(
        long_context_kv_bytes(2, 1, 64, 32768) == 16777216,
        "growth bench shape at 32768",
    )
    # Growth is exactly linear: doubling tokens doubles bytes.
    _expect(
        long_context_kv_bytes(2, 1, 64, 16384) * 2
        == long_context_kv_bytes(2, 1, 64, 32768),
        "growth linear",
    )
    _expect(kv_growth_bp(0, 32768) == 0, "growth bp empty")
    _expect(kv_growth_bp(16384, 32768) == 5000, "growth bp half")
    _expect(kv_growth_bp(32767, 32768) == 9999, "growth bp near-full")
    _expect(kv_growth_bp(32768, 32768) == 10000, "growth bp full")
    var refused = False
    try:
        _ = kv_growth_bp(32769, 32768)
    except error:
        refused = "outside [0, capacity]" in String(error)
    _expect(refused, "growth bp above capacity refused")
    print("A-052 growth account: PASS")


def test_long_context_session_cap_verdict() raises:
    print("--- A-052 verdict: context vs engine session cap ---")
    _expect(HOST_RUNTIME_CONTEXT_CAP == 16000, "session cap is 16000")
    _expect(
        session_cap_verdict(8192) == CTX_FITS_SESSION, "8192 fits session"
    )
    _expect(
        session_cap_verdict(16000) == CTX_FITS_SESSION,
        "16000 fits session exactly",
    )
    _expect(
        session_cap_verdict(16001) == CTX_EXCEEDS_SESSION,
        "16001 exceeds session",
    )
    _expect(
        session_cap_verdict(LONG_CONTEXT_TOKENS) == CTX_EXCEEDS_SESSION,
        "32768 exceeds session (filed boundary)",
    )
    _expect(
        session_cap_verdict_name(CTX_FITS_SESSION)
        == String("fits-session-cap"),
        "verdict name fits",
    )
    _expect(
        session_cap_verdict_name(CTX_EXCEEDS_SESSION)
        == String("exceeds-session-cap"),
        "verdict name exceeds",
    )
    print("A-052 session cap verdict: PASS")


def test_long_context_depths_patterns() raises:
    print("--- A-052 depths: needle placement and pattern ---")
    _expect(NEEDLE_COUNT == 7, "seven needles filed")
    _expect(needle_depth(0) == 0, "first needle at depth 0")
    _expect(
        needle_depth(NEEDLE_COUNT - 1) == LONG_CONTEXT_TOKENS - 1,
        "last needle at final position",
    )
    for j in range(NEEDLE_COUNT):
        _expect(needle_index_at(needle_depth(j)) == j, "needle index round-trip")
        if j > 0:
            _expect(
                needle_depth(j) > needle_depth(j - 1),
                "depths strictly ascending",
            )
        for m in range(j + 1, NEEDLE_COUNT):
            _expect(
                needle_value(j) != needle_value(m),
                "needle values pairwise distinct",
            )
    _expect(needle_depth(NEEDLE_COUNT) == -1, "depth sentinel")
    _expect(needle_index_at(500) == -1, "distractor position has no needle")
    _expect(needle_index_at(32766) == -1, "position before last has no needle")
    # Pattern: deterministic, in [-0.5, 0.5), dyadic at 1/32 so
    # every component is exact in F16 (no rounding anywhere in
    # the fill/readback/probe chain).
    for pos in range(0, LONG_CONTEXT_TOKENS, 4093):
        for d in range(LONG_CONTEXT_HEAD_DIM):
            var k = pattern_component(pos, d)
            var v = pattern_value_component(pos, d)
            _expect(k == pattern_component(pos, d), "pattern deterministic")
            _expect(k >= Float32(-0.5) and k < Float32(0.5), "pattern K range")
            _expect(v >= Float32(-0.5) and v < Float32(0.5), "pattern V range")
            _expect(k * Float32(32.0) == Float32(Int(k * Float32(32.0))), "pattern K dyadic")
            _expect(v * Float32(32.0) == Float32(Int(v * Float32(32.0))), "pattern V dyadic")
    print("A-052 depths and patterns: PASS")


def test_long_context_probe_grading() raises:
    print("--- A-052 grading: probe tolerance and rate ---")
    var exact = List[Float32]()
    var near = List[Float32]()
    var off = List[Float32]()
    for _ in range(LONG_CONTEXT_HEAD_DIM):
        exact.append(Float32(1.25))
        near.append(Float32(1.25) + Float32(0.005))
        off.append(Float32(1.25) + Float32(0.02))
    _expect(probe_max_abs_diff(exact, Float32(1.25)) == Float32(0.0), "grading exact diff 0")
    _expect(probe_passes(probe_max_abs_diff(exact, Float32(1.25))), "grading exact passes")
    _expect(probe_passes(probe_max_abs_diff(near, Float32(1.25))), "grading 0.005 passes at filed 0.010")
    _expect(not probe_passes(probe_max_abs_diff(off, Float32(1.25))), "grading 0.02 fails at filed 0.010")
    var empty = List[Float32]()
    _expect(probe_max_abs_diff(empty, Float32(1.25)) == Float32(-1.0), "grading empty sentinel")
    _expect(not probe_passes(Float32(-1.0)), "grading sentinel never passes")
    _expect(probe_rate_bp(7, 7) == 10000, "rate 7/7")
    _expect(probe_rate_bp(6, 7) == 8571, "rate 6/7 floored bp")
    _expect(probe_rate_bp(0, 7) == 0, "rate 0/7")
    var refused = False
    try:
        _ = probe_rate_bp(8, 7)
    except error:
        refused = "outside [0, total]" in String(error)
    _expect(refused, "rate above total refused")
    print("A-052 probe grading: PASS")


def test_long_context_kv_growth_execution() raises:
    print("--- A-052 execution: KV growth to 32768 + readback ---")
    var well = MimirWell(64 * 1024 * 1024)
    var cache = KVCache(LONG_CONTEXT_TOKENS, LONG_CONTEXT_HEAD_DIM, well, 1)
    _fill_long_cache(cache, well)
    _expect(
        kv_growth_bp(LONG_CONTEXT_TOKENS, cache.max_seq_len) == 10000,
        "cache grown to 10000 bp of capacity",
    )
    # Correctness spot-checks at depth: sampled positions across
    # the whole context (both ends, every needle, block edges),
    # every dim, K and V, compared exactly -- pattern and needle
    # values are F16-exact by construction, so any corrupted
    # slot fails bitwise.
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
    var ks = cache.get_k_slice(0, LONG_CONTEXT_TOKENS)
    var vs = cache.get_v_slice(0, LONG_CONTEXT_TOKENS)
    for si in range(len(spots)):
        var pos = spots[si]
        for d in range(LONG_CONTEXT_HEAD_DIM):
            var idx = pos * LONG_CONTEXT_HEAD_DIM + d
            _expect(
                ks.data.unsafe_load(idx).cast[f32]() == _expected_k(pos, d),
                "readback K at depth " + String(pos),
            )
            _expect(
                vs.data.unsafe_load(idx).cast[f32]() == _expected_v(pos, d),
                "readback V at depth " + String(pos),
            )
    # Fixed capacity is a hard wall: position 32768 is refused
    # and the refusal mutates nothing.
    var krow = RuneTensor[f16](
        1, LONG_CONTEXT_HEAD_DIM, well.allocate(LONG_CONTEXT_HEAD_DIM)
    )
    var refused = False
    try:
        cache.append(0, LONG_CONTEXT_TOKENS, krow, krow)
    except error:
        refused = "exceeds fixed cache capacity" in String(error)
    _expect(refused, "append past 32768 refused")
    print("A052_TEST_READBACK positions=" + String(len(spots)) + " dims=" + String(LONG_CONTEXT_HEAD_DIM) + " exact")
    print("A-052 KV growth execution: PASS")


def test_long_context_needle_probes() raises:
    print("--- A-052 probes: needle retrieval at depth, full 32k ---")
    var well = MimirWell(64 * 1024 * 1024)
    var cache = KVCache(LONG_CONTEXT_TOKENS, LONG_CONTEXT_HEAD_DIM, well, 1)
    _fill_long_cache(cache, well)
    var ks = cache.get_k_slice(0, LONG_CONTEXT_TOKENS)
    var vs = cache.get_v_slice(0, LONG_CONTEXT_TOKENS)
    var q = RuneTensor[f16](
        1, LONG_CONTEXT_HEAD_DIM, well.allocate(LONG_CONTEXT_HEAD_DIM)
    )
    var out = RuneTensor[f16](
        1, LONG_CONTEXT_HEAD_DIM, well.allocate(LONG_CONTEXT_HEAD_DIM)
    )
    var passed = 0
    for j in range(NEEDLE_COUNT):
        for d in range(LONG_CONTEXT_HEAD_DIM):
            var qv = Float32(0.0)
            if d == j:
                qv = Float32(32.0)
            q.data.unsafe_store(d, qv.cast[f16]())
            out.data.unsafe_store(d, Float32(0.0).cast[f16]())
        flash_attention_gqa(
            q, ks, vs, out, LONG_CONTEXT_TOKENS,
            LONG_CONTEXT_HEAD_DIM, 1, 1,
        )
        var row = List[Float32]()
        for d in range(LONG_CONTEXT_HEAD_DIM):
            row.append(out.data.unsafe_load(d).cast[f32]())
        var diff = probe_max_abs_diff(row, needle_value(j))
        print(
            "A052_TEST_PROBE needle=" + String(j)
            + " depth=" + String(needle_depth(j))
            + " max_abs_diff=" + String(diff)
        )
        if probe_passes(diff):
            passed += 1
    _expect(passed == NEEDLE_COUNT, "all filed needle probes pass")
    _expect(probe_rate_bp(passed, NEEDLE_COUNT) == 10000, "probe rate 10000 bp")
    print("A-052 needle probes: PASS")
