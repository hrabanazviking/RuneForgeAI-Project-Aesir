"""Memory ceiling accounting (Janas road J-093).

The roadmap text: "Peak memory across the ladder with
8-bit KV + expert cache active together; the 2.6->4.9
GiB shape of Janas's growth tested against Aesir's
own."

DESIGN, stated up front (the J-093 doc is its
normative text; this header records the choices the
code embodies, PRE-REGISTERED before any J-093 number
was produced):

- THE TENSION, RESOLVED FROM THE TREE. The ladder's
  witness (J-091) is DENSE: Qwen2.5-Coder-7B has no
  routed experts, so no expert cache ever runs inside
  its session. The expert cache is MoE machinery: its
  witness is OLMoE (Part II; 16 layers, 64 experts,
  top-8; resident set 311,027,712 B, routed body
  3,900,702,720 B, per-token routed demand
  487,587,840 B -- J-015/J-017 MEASURED), and no
  session in the tree runs a dense ladder session and
  an expert cache in one session (inspect-asserted:
  the dense CUDA session admits DenseGQAProfile only;
  the MoE session admits arch "olmoe" only). This
  slice therefore files the ceiling in the TWO honest
  forms the tree supports, each labelled for exactly
  what it is, neither smuggled as the other:
    FORM A -- the dense ladder's own peak, per rung,
      per line, per precision (this section below).
    FORM B -- the combined-PROCESS ceiling under the
      J-026 shared-pool arithmetic, when a KV-bearing
      dense session and an MoE session's expert cache
      share one host process budget (below). Form B is
      a HOST-process account: the pool arithmetic of
      J-018/J-026 is host-memory arithmetic, so the
      dense tenant enters at its host (CPU-line)
      components; its GPU device bytes are Form A's
      GPU column and are never added into Form B (that
      would charge the same weights in two memories).

- FORM A: PEAK, DEFINED. A rung's peak is taken at
  the WRITE leg's session context (rung + 128, J-091's
  session definition): the moment the session's KV is
  largest while every other component is already
  resident. Components, all defined THROUGH the tree:
  weights = the sha-pinned file's bytes (the resident
  set of a dense session is the whole file);
  KV = ladder_kv_total at the session context at the
  stated precision (through core/kv_ladder over
  J-087/J-088); activation = the profile's own
  activation_elements shape (208,896 fixed + 28 per
  context token for the witness) x 4 bytes, exactly
  the term ladder_gpu_required_bytes prices;
  sampling = sampling_device_bytes (905,728 B for the
  witness) on the GPU line only -- the host line has
  no device sampler buffer, so the CPU peak is the
  GPU peak minus exactly that term, at every cell.
  The GPU session peak IS ladder_gpu_required_bytes
  at the session context, so Form A's GPU column must
  reproduce J-091 section 5.3 EXACTLY (the tests' and
  inspect's validation gate). The read leg's total
  (same components at the rung itself) is priced too
  and is never the peak. A rung's PEAK VERDICT is its
  write-leg ladder_cell_verdict (integration judged
  before caps, J-091's order); read verdicts are
  filed beside it in the harness, unchanged.

- THE GROWTH-SHAPE RULE, PRE-REGISTERED. Janas's
  published long-context growth is 2.6 -> 4.9 GiB
  (its public documentation, cited in the roadmap):
  a shape ratio of 49/26 = 1,884,615 ppm (floored).
  Those are Janas's numbers on Janas's machine; they
  name the SHAPE to test and are never quoted as
  Aesir figures. Aesir's shape per line and precision
  is ratio_ppm = top-rung session peak x 1,000,000 //
  base-rung session peak (floored ppm, exact integer
  arithmetic). Verdict, mechanical: ratio_ppm <
  Janas's -> FLATTER; == -> MATCHES; > -> STEEPER.
  The driver is filed in bytes, not adjectives: the
  KV share of the peak (kv x 1,000,000 // peak, ppm)
  at the base and top rungs, per line and precision.

- FORM B: THE POOL RULE, AND WHY. When sessions share
  a process, the expert cache budget is chosen by
  J-026's pool rule (plan_shared_cache_pool), NOT by
  J-018's per-session sizing: J-026 section 2 proved
  independent sizing over-commits (two sessions claim
  14,800 B of a stated 10,000 B machine, the OS
  headroom charged twice). The pool runs J-018's
  reserve arithmetic ONCE over SUMMED reserves, the
  headroom (total // 5) charged once for the process.
  Form B's stated inputs (a STATED machine in the
  J-018/J-026 test style -- an accounting input, not
  a measured machine): total = free-at-open =
  17,179,869,184 B (16 GiB), hard cap unset (0).
  Tenants N = 2 (SharedExpertBudget): the dense
  tenant holds no cache bytes (it protects 0 cache
  bytes; the MoE tenant's cap is the whole pool) and
  the floor is pool // (2N) = pool // 4. Summed
  reserves: resident_total = dense weights
  4,683,074,688 + OLMoE resident 311,027,712 =
  4,994,102,400; kv_total = the dense tenant's KV at
  its session context (the rung's precision) + the
  MoE tenant's KV at its standard live configuration
  (context 512, J-022/J-030: f16 131,072 B/token
  through J-087, per-row int8 67,584 B/token through
  J-088 -- so Form B's int8 column is a
  COUNTERFACTUAL for both tenants, labelled CF,
  exactly as J-091 labels its int8 GPU column);
  scratch_total = the dense tenant's activation
  bytes at its session context (its scratch role in
  this account -- its only per-session volatile
  allocation beside KV in the admission shape; stated
  here, answered-locally) + OLMoE's activation
  allowance 16,777,216 B (J-031's named allowance).
  COMBINED PEAK = resident_total + kv_total +
  scratch_total + min(pool_budget, expert body): a
  cache can never hold more than the body it caches,
  so the peak charges the lesser. The ACCOUNTED
  CEILING (the budget form) charges the full pool
  instead: resident + kv + scratch + pool = free -
  headroom on the stated machine (uncapped), a
  constant the pool defends by shrinking as KV
  grows -- both forms are filed, the peak is the
  headline. The sizing's below_floor flag (pool <
  one token's full routed demand, 487,587,840 B) is
  the pool's refusal shape and is filed per rung.

- HONESTY, BINDING. This module contains no measured
  peak. An accounted ceiling is NOT an RSS or VRAM
  high-water mark: no live peak (RSS/VRAM) is PROVEN
  by anything in this slice; every live peak is
  deferred with an exact recipe to the J-098 gate
  (J-093 doc section 7). No wall, no speed.

HOST CONTRACT: (1) price every memory-ceiling claim
through this module, never from memory; (2) quote a
ceiling with its form named (A per line/precision, or
B with its stated machine) -- an unnamed ceiling is
a defect in the claim; (3) a live peak may be filed
only from a live run under the J-093 doc section 7
recipe at the J-098 gate.
"""

from core.expert_cache import (
    ExpertCacheSizing,
    SharedExpertBudget,
    plan_shared_cache_pool,
)
from core.kv_ladder import (
    LADDER_LINE_CPU,
    LADDER_LINE_GPU,
    ladder_cell_verdict,
    ladder_gpu_required_bytes,
    ladder_kv_bytes_per_token,
    ladder_kv_total,
    ladder_session_context,
)

comptime CEILING_SHAPE_FLATTER = 0
comptime CEILING_SHAPE_MATCHES = 1
comptime CEILING_SHAPE_STEEPER = 2

# Janas's published growth shape, 2.6 -> 4.9 GiB, as a
# floored-ppm ratio: 49 * 1,000,000 // 26. A shape to
# test against, never an Aesir figure.
comptime JANAS_SHAPE_RATIO_PPM = 1884615


def _check_positive(value: Int, what: String) raises:
    if value <= 0:
        raise Error("MemoryCeiling: " + what + " must be positive")


def ceiling_activation_bytes(
    activation_fixed_elements: Int,
    activation_per_context_elements: Int,
    context: Int,
) raises -> Int:
    """Activation bytes at a context: the profile's own
    activation_elements shape (a fixed part plus a
    per-context part) at 4 bytes, the exact term the
    dense admission arithmetic prices."""
    if activation_fixed_elements < 0 or activation_per_context_elements < 0:
        raise Error("MemoryCeiling: activation elements must be nonnegative")
    _check_positive(context, "context")
    return (
        activation_fixed_elements + activation_per_context_elements * context
    ) * 4


def ceiling_dense_peak(
    weights_bytes: Int,
    kv_bytes_per_token_value: Int,
    context: Int,
    activation_fixed_elements: Int,
    activation_per_context_elements: Int,
    sampling_bytes: Int,
    line: Int,
) raises -> Int:
    """Form A at a stated context: weights + KV at that
    context + activation x 4 + sampling. Defined
    THROUGH ladder_gpu_required_bytes (J-091's
    admission shape): the GPU line charges the stated
    sampling bytes; the CPU (host) line charges none
    (no device sampler buffer exists there)."""
    if line != LADDER_LINE_CPU and line != LADDER_LINE_GPU:
        raise Error("MemoryCeiling: unknown line code")
    if sampling_bytes < 0:
        raise Error("MemoryCeiling: sampling bytes must be nonnegative")
    var sampling = sampling_bytes if line == LADDER_LINE_GPU else 0
    return ladder_gpu_required_bytes(
        weights_bytes,
        kv_bytes_per_token_value,
        context,
        activation_fixed_elements,
        activation_per_context_elements,
        sampling,
    )


def ceiling_dense_peak_at_rung(
    weights_bytes: Int,
    layers: Int,
    kv_heads: Int,
    head_dim: Int,
    precision: Int,
    rung: Int,
    direction: Int,
    activation_fixed_elements: Int,
    activation_per_context_elements: Int,
    sampling_bytes: Int,
    line: Int,
) raises -> Int:
    """Form A at a rung's leg: the context is J-091's
    session context for the direction (rung for read,
    rung + 128 for write), the KV price is the
    ladder's own per-token price at the precision."""
    var context = ladder_session_context(rung, direction)
    var kv_pt = ladder_kv_bytes_per_token(layers, kv_heads, head_dim, precision)
    return ceiling_dense_peak(
        weights_bytes,
        kv_pt,
        context,
        activation_fixed_elements,
        activation_per_context_elements,
        sampling_bytes,
        line,
    )


def ceiling_kv_at_context(
    layers: Int, kv_heads: Int, head_dim: Int, precision: Int, context: Int
) raises -> Int:
    """KV bytes held at a context, through the ladder
    (J-087/J-088 prices), for itemised filing."""
    return ladder_kv_total(layers, kv_heads, head_dim, precision, context)


def ceiling_ratio_ppm(top: Int, base: Int) raises -> Int:
    """A growth ratio in floored parts per million:
    top x 1,000,000 // base, exact integer arithmetic
    (every total this road files keeps the product far
    inside Int64, guarded)."""
    _check_positive(top, "top")
    _check_positive(base, "base")
    if top > 9223372036854775807 // 1000000:
        raise Error("MemoryCeiling: top too large for exact ppm")
    return top * 1000000 // base


def ceiling_share_ppm(part: Int, whole: Int) raises -> Int:
    """A component's share of a peak, floored ppm."""
    if part < 0:
        raise Error("MemoryCeiling: share part must be nonnegative")
    _check_positive(whole, "whole")
    if part > 9223372036854775807 // 1000000:
        raise Error("MemoryCeiling: part too large for exact ppm")
    return part * 1000000 // whole


def ceiling_shape_verdict(ratio_ppm_value: Int) raises -> Int:
    """The pre-registered shape verdict against
    Janas's published ratio: FLATTER below it, MATCHES
    at it, STEEPER above it. Exact comparison, no
    tolerance band."""
    _check_positive(ratio_ppm_value, "ratio")
    if ratio_ppm_value < JANAS_SHAPE_RATIO_PPM:
        return CEILING_SHAPE_FLATTER
    if ratio_ppm_value > JANAS_SHAPE_RATIO_PPM:
        return CEILING_SHAPE_STEEPER
    return CEILING_SHAPE_MATCHES


def ceiling_shape_name(code: Int) raises -> String:
    if code == CEILING_SHAPE_FLATTER:
        return String("FLATTER")
    if code == CEILING_SHAPE_MATCHES:
        return String("MATCHES")
    if code == CEILING_SHAPE_STEEPER:
        return String("STEEPER")
    raise Error("MemoryCeiling: unknown shape code")


def ceiling_peak_verdict(
    line: Int,
    precision: Int,
    rung: Int,
    direction: Int,
    int8_cpu_integrated: Bool,
    int8_gpu_integrated: Bool,
    profile_cap: Int,
) raises -> Int:
    """A cell's verdict is J-091's ladder verdict,
    unchanged (integration judged before caps): this
    slice adds no verdict of its own."""
    return ladder_cell_verdict(
        line,
        precision,
        rung,
        direction,
        int8_cpu_integrated,
        int8_gpu_integrated,
        profile_cap,
    )


def ceiling_pool_sizing(
    free_at_open_bytes: Int,
    total_bytes: Int,
    resident_total_bytes: Int,
    kv_total_bytes: Int,
    scratch_total_bytes: Int,
    per_token_routed_bytes: Int,
) raises -> ExpertCacheSizing:
    """Form B's pool: ONE sizing for the process
    through J-026's plan_shared_cache_pool (J-018's
    reserve arithmetic over summed reserves, headroom
    charged once), hard cap unset."""
    return plan_shared_cache_pool(
        free_at_open_bytes,
        total_bytes,
        0,
        resident_total_bytes,
        kv_total_bytes,
        scratch_total_bytes,
        per_token_routed_bytes,
    )


def ceiling_arbiter(
    pool_budget_bytes: Int, tenant_count: Int
) raises -> SharedExpertBudget:
    """The J-026 floor-and-borrow arbiter over the
    pool (floor = pool // (2N))."""
    return SharedExpertBudget(pool_budget_bytes, tenant_count)


def ceiling_cache_resident(pool_budget_bytes: Int, expert_body_bytes: Int) raises -> Int:
    """Bytes the expert cache can actually hold at
    peak: its budget, or the whole routed body when
    the budget exceeds it -- a cache holds no more
    than the body it caches."""
    _check_positive(pool_budget_bytes, "pool budget")
    _check_positive(expert_body_bytes, "expert body")
    return pool_budget_bytes if pool_budget_bytes < expert_body_bytes else expert_body_bytes


def ceiling_combined_peak(
    resident_total_bytes: Int,
    kv_total_bytes: Int,
    scratch_total_bytes: Int,
    pool_budget_bytes: Int,
    expert_body_bytes: Int,
) raises -> Int:
    """Form B's headline: summed residents + summed KV
    + summed scratch + the cache's peak residency
    (min(pool, body))."""
    if resident_total_bytes < 0 or kv_total_bytes < 0 or scratch_total_bytes < 0:
        raise Error("MemoryCeiling: combined components must be nonnegative")
    return (
        resident_total_bytes
        + kv_total_bytes
        + scratch_total_bytes
        + ceiling_cache_resident(pool_budget_bytes, expert_body_bytes)
    )


def ceiling_combined_accounted(
    resident_total_bytes: Int,
    kv_total_bytes: Int,
    scratch_total_bytes: Int,
    pool_budget_bytes: Int,
) raises -> Int:
    """Form B's budget form: the same sum charging the
    FULL pool (the ceiling the process has accounted
    for, whether or not the cache ever fills it)."""
    if (
        resident_total_bytes < 0
        or kv_total_bytes < 0
        or scratch_total_bytes < 0
        or pool_budget_bytes < 0
    ):
        raise Error("MemoryCeiling: combined components must be nonnegative")
    return (
        resident_total_bytes + kv_total_bytes + scratch_total_bytes + pool_budget_bytes
    )
