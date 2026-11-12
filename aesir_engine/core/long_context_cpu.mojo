# core/long_context_cpu.mojo
# A-052: Long context on CPU -- the account, the deterministic
# context pattern, and the needle-probe grading arithmetic for
# the 32k-token CPU context run, shared by the standalone bench
# (tests/bench_long_context_a052.mojo) and the E-MASTER cases
# (tests/test_long_context_a052.mojo) so the filed numbers are
# produced by exactly one implementation.
#
# WHAT THE RUN IS. A KVCache sized for 32,768 positions is
# filled token by token on CPU (the engine KV layer,
# core/mimir_well.mojo -- fixed capacity, append raises past
# capacity, no wrap, no eviction), read back at depth, and then
# probed: at seven filed depths a distinctive needle key/value
# pair is planted among deterministic distractor rows, and a
# decode-step query through the production CPU attention kernel
# (core/compute.mojo flash_attention_gqa, the A-043 SIMD body)
# must recover the needle value at that depth. KV growth is
# priced with the tree own census arithmetic
# (core/kv_account.mojo), never restated here.
#
# HONEST BOUNDARY. The engine session/generation path clamps
# context to HOST_RUNTIME_CONTEXT_CAP (16,000; aesir.mojo
# MAX_RUNTIME_CONTEXT, applied in _run_generation and mirrored
# in core/inference.mojo). A 32k session therefore does NOT run
# end-to-end through AesirEngine today: this slice proves the
# 32k run at the KV + attention layer the session path is built
# on, and files the session-cap verdict below so the boundary
# is stated, not hidden. Lifting the session cap is recorded
# as follow-on work in the team CAMPAIGN_STATE.md.
#
# PROBE DESIGN (filed before the run; the bench files its
# measured diffs against these rates):
# - head_dim 64, one KV head. Distractor K/V components are
#   dyadic multiples of 1/32 in [-0.5, 0.5), exact in F16, from
#   the stateless hash in pattern_component below -- the fill
#   and the readback check regenerate the same values
#   independently, so a corrupted slot cannot agree with both.
# - Needle j sits at needle_depth(j); its key is 8.0 * e_j
#   (one-hot at dim j, exact in F16), its value the constant
#   dyadic needle_value(j) on every dim. Distinct needles use
#   distinct dims, so needle keys are mutually orthogonal.
# - The probe query is 32.0 * e_j. At the kernel default scale
#   1/sqrt(64) = 1/8 the needle score is 32*8/8 = 32, while any
#   distractor score is bounded by 32*0.5/8 = 2 in magnitude
#   and every other needle scores exactly 0. The softmax mass
#   off the needle is therefore below 32767 * e^(2-32), under
#   1e-8: the recovered row must equal the needle value to
#   within F16 rounding. Filed pass bound: max abs diff
#   <= 0.010 per probe (PROBE_TOL_MILLI), filed rate 7/7.
#
# Raw-oracle discipline: this module produces no logits and
# grades no model output; the probes grade the KV/attention
# path against values planted by construction (the reference
# is the pattern itself, recomputed -- never the code path
# under test reading its own answer back through itself).
# CPU only; no accelerator claim is made anywhere in A-052.

from core.kv_account import (
    HOST_RUNTIME_CONTEXT_CAP,
    KV_ELEM_F16,
    kv_bytes_per_token,
    kv_total_bytes,
)

comptime LONG_CONTEXT_TOKENS = 32768
comptime LONG_CONTEXT_HEAD_DIM = 64
comptime NEEDLE_COUNT = 7
comptime PROBE_TOL_MILLI = 10

# Session-cap verdict codes for session_cap_verdict.
comptime CTX_FITS_SESSION = 0
comptime CTX_EXCEEDS_SESSION = 1


def long_context_kv_bytes(
    layers: Int, kv_heads: Int, head_dim: Int, tokens: Int
) raises -> Int:
    """Total host KV bytes (F16, K and V) for a uniform shape
    at a stated context length -- core/kv_account arithmetic
    composed, with the length required positive."""
    if tokens <= 0:
        raise Error("LongContext: tokens must be positive")
    var per_token = kv_bytes_per_token(
        layers, kv_heads, head_dim, KV_ELEM_F16
    )
    return kv_total_bytes(per_token, tokens)


def kv_growth_bp(filled: Int, capacity: Int) raises -> Int:
    """How full the context is, in basis points of capacity:
    filled * 10000 // capacity, floored. Refuses a non-positive
    capacity, a negative fill, or a fill above capacity (the
    KVCache itself raises before that state can exist)."""
    if capacity <= 0:
        raise Error("LongContext: capacity must be positive")
    if filled < 0 or filled > capacity:
        raise Error("LongContext: filled outside [0, capacity]")
    return filled * 10000 // capacity


def session_cap_verdict(tokens: Int) raises -> Int:
    """Grade a context length against the engine session cap:
    CTX_FITS_SESSION when tokens <= HOST_RUNTIME_CONTEXT_CAP,
    CTX_EXCEEDS_SESSION above it -- the KV layer admits the
    longer cache, the session path clamps allocation to the
    cap (see the file header)."""
    if tokens <= 0:
        raise Error("LongContext: tokens must be positive")
    if tokens <= HOST_RUNTIME_CONTEXT_CAP:
        return CTX_FITS_SESSION
    return CTX_EXCEEDS_SESSION


def session_cap_verdict_name(code: Int) -> String:
    if code == CTX_FITS_SESSION:
        return String("fits-session-cap")
    if code == CTX_EXCEEDS_SESSION:
        return String("exceeds-session-cap")
    return String("unknown")


def needle_depth(index: Int) -> Int:
    """Filed needle depths, ascending, spanning the full 32k
    context including both ends. -1 for an out-of-range index
    (fail-closed sentinel, never a depth)."""
    if index == 0:
        return 0
    if index == 1:
        return 1024
    if index == 2:
        return 4096
    if index == 3:
        return 8192
    if index == 4:
        return 16384
    if index == 5:
        return 24576
    if index == 6:
        return 32767
    return -1


def needle_index_at(pos: Int) -> Int:
    """The needle planted at pos, or -1 when pos is a plain
    distractor position."""
    for j in range(NEEDLE_COUNT):
        if needle_depth(j) == pos:
            return j
    return -1


def needle_value(index: Int) -> Float32:
    """The constant dyadic value needle index plants on every
    dim of its V row. Values are pairwise distinct and exact
    in F16. 0.0 for an out-of-range index (a value no needle
    uses, so a grading mix-up cannot silently pass)."""
    if index == 0:
        return Float32(-1.75)
    if index == 1:
        return Float32(-1.25)
    if index == 2:
        return Float32(-0.75)
    if index == 3:
        return Float32(0.5)
    if index == 4:
        return Float32(0.75)
    if index == 5:
        return Float32(1.25)
    if index == 6:
        return Float32(1.75)
    return Float32(0.0)


def _pattern_hash(pos: Int, dim: Int, salt: UInt64) -> UInt64:
    var h = UInt64(pos) * 2654435761
    h = h ^ (UInt64(dim) * 40503)
    h = h ^ salt
    h = h * 6364136223846793005
    return h >> 11


def pattern_component(pos: Int, dim: Int) -> Float32:
    """Deterministic distractor K component at (pos, dim):
    a dyadic multiple of 1/32 in [-0.5, 0.5), exact in F16.
    Stateless -- the fill, the readback spot-checks, and the
    suite regenerate identical values from (pos, dim) alone."""
    var k = Int(_pattern_hash(pos, dim, 2654435769) & 31)
    return Float32(k - 16) / Float32(32.0)


def pattern_value_component(pos: Int, dim: Int) -> Float32:
    """Deterministic distractor V component at (pos, dim),
    independently salted from the K pattern, same dyadic
    range and F16 exactness."""
    var k = Int(_pattern_hash(pos, dim, 2246822519) & 31)
    return Float32(k - 16) / Float32(32.0)


def probe_max_abs_diff(row: List[Float32], expected: Float32) -> Float32:
    """Largest |row[i] - expected| over the row; -1.0 on an
    empty row (fail-closed sentinel; real diffs are >= 0)."""
    if len(row) == 0:
        return Float32(-1.0)
    var worst = Float32(0.0)
    for i in range(len(row)):
        var d = row[i] - expected
        if d < Float32(0.0):
            d = -d
        if d > worst:
            worst = d
    return worst


def probe_passes(max_abs_diff: Float32) -> Bool:
    """One needle probe verdict at the filed tolerance:
    0 <= max_abs_diff and max_abs_diff * 1000 <=
    PROBE_TOL_MILLI. The sentinel -1.0 never passes."""
    if max_abs_diff < Float32(0.0):
        return False
    return max_abs_diff * Float32(1000.0) <= Float32(PROBE_TOL_MILLI)


def probe_rate_bp(passed: Int, total: Int) raises -> Int:
    """Filed probe rate in basis points: passed * 10000 //
    total, floored. Refuses a non-positive total or a count
    outside [0, total]."""
    if total <= 0:
        raise Error("LongContext: probe total must be positive")
    if passed < 0 or passed > total:
        raise Error("LongContext: probe passed outside [0, total]")
    return passed * 10000 // total
