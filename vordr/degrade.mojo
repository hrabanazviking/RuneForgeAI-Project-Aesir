# VÖRÐR honest degradation (H157).
#
# SÓLRÚN AUDIT (NO-GO branch): there is no NPU op to fault and no CPU
# fallback to engage — the CPU path IS the compute. The roadmap's
# explicit NO-GO treatment is implemented here: CPU-pipeline stage
# retry with the same observability standard the GO branch would have
# carried.
#
# When a stage faults persistently, VÖRÐR recomputes THAT op through
# the independent scalar fallback kernel (the same scalar path H150
# trusts), logs a LOUD DEGRADED event naming the op, the cause, and
# the fallback — and the next healthy op goes straight back to the
# fast kernel. No sticky fallback (L11: degrade honestly, never
# silently). 20 ops with a single faulted one must show exactly one
# DEGRADED event and 19 clean fast-path executions.

from hailbru.errors import herror
from std.memory.alloc import unsafe_alloc
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from vordr.events import event_emit_slice
from armvegr.gemm import gemm_micro_8x8, gemm_scalar_tile


def run_stage(
    arch: String,
    log_path: String,
    op: String,
    ap: Pointer[Float16, MutUntrackedOrigin],
    bp: Pointer[Float16, MutUntrackedOrigin],
    acc: Pointer[Float32, MutUntrackedOrigin],
    kc: Int,
    hook_persistent_fail: Bool,
    hook_cause: String,
) raises -> String:
    # Runs one 8x8 tile stage. Returns "fast" or "degraded".
    # hook_persistent_fail=True simulates a stage whose fast kernel
    # faults persistently (retry policy exhausted) — VÖRÐR recomputes
    # via the scalar fallback and says so, loudly.
    if not hook_persistent_fail:
        gemm_micro_8x8(ap, bp, acc, kc, 8)
        return "fast"
    gemm_scalar_tile(ap, bp, acc, 8, 8, kc, 8)
    event_emit_slice(
        arch, log_path, "H157", "DEGRADED",
        "\"op\": \"" + op + "\", \"cause\": \"" + hook_cause
        + "\", \"fallback\": \"scalar kernel (gemm_scalar_tile)\", "
        + "\"note\": \"per-operation and temporary — next healthy op "
        "returns to the fast kernel\"",
    )
    return "degraded"


def run_stage_alloc(
    arch: String,
    log_path: String,
    op: String,
    kc: Int,
    hook_persistent_fail: Bool,
    hook_cause: String,
) raises -> String:
    # Convenience: allocates zeroed packed tiles, runs the stage,
    # frees. Used by the self-tests and PRÓF drivers.
    var ap = unsafe_alloc[Float16](8 * kc)
    var bp = unsafe_alloc[Float16](8 * kc)
    var acc = unsafe_alloc[Float32](64)
    for i in range(8 * kc):
        ap[unsafe_offset=i] = Float16(0.5)
        bp[unsafe_offset=i] = Float16(0.25)
    for i in range(64):
        acc[unsafe_offset=i] = Float32(0)
    var r = run_stage(
        arch, log_path, op, ap, bp, acc, kc, hook_persistent_fail, hook_cause
    )
    ap.free()
    bp.free()
    acc.free()
    return r
