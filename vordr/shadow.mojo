# VÖRÐR CPU shadow-verification sampler (H150).
#
# SÓLRÚN AUDIT (NO-GO branch): there is no NPU compute to shadow, so
# this slice implements the roadmap's explicit NO-GO treatment —
# continuous correctness surveillance as a cross-check between two
# CPU numerics paths (fast kernel vs independent scalar reference) at
# the same sampling discipline the GO branch would have used.
#
# Mechanism: VÖRÐR samples a configurable fraction of tile executions;
# each sampled tile is computed twice — once by the optimized SIMD
# micro-kernel (armvegr.gemm.gemm_micro_8x8) and once by the
# independent scalar reference (armvegr.gemm.gemm_scalar_tile) — and
# compared within the quantization contract. Sampling is unpredictable
# (seeded xorshift64; the seed is logged) but the COUNT is exact: a
# seeded Fisher-Yates shuffle selects exactly round(fraction * n) of
# the n executions. A corruption test hook proves the surveillance
# catches faults: ShadowMismatch names the layer.
#
# If the compiler wall ever falls, this sampler's interface is
# NPU-ready: the scalar reference stays the trusted second opinion
# and the fast path is swapped for the NPU result.

from hailbru.syscall import os_clock_ms
from hailbru.errors import herror
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin
from std.memory import Pointer
from vordr.events import event_emit_slice
from armvegr.gemm import gemm_micro_8x8, gemm_scalar_tile


struct XorShift64:
    var s: UInt64

    def __init__(out self, seed: UInt64):
        var z = seed
        if z == 0:
            z = UInt64(0x9E3779B97F4A7C15)
        self.s = z

    def next(mut self) -> UInt64:
        var x = self.s
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
        self.s = x
        return x

    def below(mut self, n: Int) -> Int:
        return Int(self.next() % UInt64(n))


def shadow_plan(seed: UInt64, n_ops: Int, fraction: Float64) raises -> List[Int]:
    # Exactly round(fraction * n_ops) sampled indices, unpredictably
    # ordered (seeded Fisher-Yates). Returns the sampled indices.
    if n_ops <= 0:
        raise herror("BadShadowPlan", "n_ops must be positive")
    var want = Int(Float64(n_ops) * fraction + 0.5)
    if want < 1:
        want = 1
    if want > n_ops:
        want = n_ops
    var perm = List[Int]()
    for i in range(n_ops):
        perm.append(i)
    var rng = XorShift64(seed)
    var i = n_ops - 1
    while i > 0:
        var j = rng.below(i + 1)
        var t = perm[i]
        perm[i] = perm[j]
        perm[j] = t
        i -= 1
    var out = List[Int]()
    for k in range(want):
        out.append(perm[k])
    return out^


def shadow_verify_tile(
    arch: String,
    log_path: String,
    layer: String,
    ap: Pointer[Float16, MutUntrackedOrigin],
    bp: Pointer[Float16, MutUntrackedOrigin],
    kc: Int,
    contract: Float64,
    hook_corrupt: Bool,
) raises -> Float64:
    # Runs the 8x8xkc tile through both paths, compares within the
    # quantization contract. Returns the max abs difference. On breach
    # (or hook corruption) emits ShadowMismatch NAMING the layer and
    # raises the named error — the surveillance has teeth.
    var acc_fast = unsafe_alloc[Float32](64)
    var acc_ref = unsafe_alloc[Float32](64)
    for i in range(64):
        acc_fast[unsafe_offset=i] = Float32(0)
        acc_ref[unsafe_offset=i] = Float32(0)
    gemm_micro_8x8(ap, bp, acc_fast, kc, 8)
    gemm_scalar_tile(ap, bp, acc_ref, 8, 8, kc, 8)
    if hook_corrupt:
        acc_fast[unsafe_offset=0] = acc_fast[0] + Float32(1000.0)
    var worst = Float64(0)
    for i in range(64):
        var d = Float64(acc_fast[i] - acc_ref[i])
        if d < 0:
            d = -d
        if d > worst:
            worst = d
    acc_fast.unsafe_free()
    acc_ref.unsafe_free()
    if worst > contract:
        event_emit_slice(
            arch, log_path, "H150", "ShadowMismatch",
            "\"layer\": \"" + layer + "\", \"worst_abs_diff\": "
            + String(worst) + ", \"contract\": " + String(contract),
        )
        raise herror(
            "ShadowMismatch",
            "shadow verification failed for layer '" + layer
            + "': worst abs diff " + String(worst)
            + " exceeds contract " + String(contract),
        )
    return worst
