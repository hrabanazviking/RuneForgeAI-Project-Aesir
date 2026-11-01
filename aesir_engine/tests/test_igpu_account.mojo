"""iGPU account (J-067): the integrated GPU's shape pinned --
kind distinct from discrete, budget charged against the ONE
system pool and never additive with it, J-048's floor
discipline unchanged with an iGPU in the pool, the prefill
bandwidth tax charged in contended bytes with zero copy
bytes, and the claim verdict rule on every branch. No
device, no wall, no speed.
"""
from core.igpu_account import (
    GPU_KIND_DISCRETE,
    GPU_KIND_INTEGRATED,
    GPU_KIND_NONE,
    IGPU_BUDGET_FULL,
    IGPU_BUDGET_REFUSE,
    IGPU_BUDGET_SHRUNK,
    IGPU_CLAIM_PERMITTED,
    IGPU_CLAIM_REFUSED,
    IGPU_CLAIM_REQUIRES_LIVE,
    POOL_SEPARATE_DEVICE,
    POOL_SHARED_SYSTEM,
    claim_name,
    correct_total_bytes,
    evaluate_igpu_claim,
    gpu_kind_name,
    has_own_vram,
    naive_additive_total,
    plan_igpu_budget,
    plan_igpu_prefill_tax,
    pool_for_gpu_kind,
    shares_system_pool,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "IgpuAccount " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def test_kind_distinct_and_pools() raises:
    if gpu_kind_name(GPU_KIND_INTEGRATED) != String("integrated"):
        raise Error("IgpuAccount: integrated kind name")
    if gpu_kind_name(GPU_KIND_DISCRETE) != String("discrete"):
        raise Error("IgpuAccount: discrete kind name")
    expect_eq(pool_for_gpu_kind(GPU_KIND_INTEGRATED), POOL_SHARED_SYSTEM, "igpu pool")
    expect_eq(pool_for_gpu_kind(GPU_KIND_DISCRETE), POOL_SEPARATE_DEVICE, "discrete pool")
    if not shares_system_pool(GPU_KIND_INTEGRATED):
        raise Error("IgpuAccount: integrated must share the system pool")
    if shares_system_pool(GPU_KIND_DISCRETE):
        raise Error("IgpuAccount: discrete must not share the system pool")
    print("PASS: iGPU kind distinct from discrete; pools: integrated=shared-system, discrete=separate")


def test_own_vram_only_discrete() raises:
    if has_own_vram(GPU_KIND_INTEGRATED):
        raise Error("IgpuAccount: integrated GPU must not own VRAM")
    if not has_own_vram(GPU_KIND_DISCRETE):
        raise Error("IgpuAccount: discrete GPU owns VRAM")
    if has_own_vram(GPU_KIND_NONE):
        raise Error("IgpuAccount: no GPU owns nothing")
    print("PASS: own VRAM is discrete-only; an iGPU's 'device memory' is system RAM")


def test_budget_never_additive() raises:
    var pool = 16_000_000_000
    expect_eq(correct_total_bytes(pool), pool, "correct total is the pool once")
    expect_eq(naive_additive_total(pool, 4_000_000_000), pool + 4_000_000_000, "naive additive overstatement named")
    # Every plan this module returns charges <= the pool, once.
    var p = plan_igpu_budget(pool, 2_000_000_000, 500_000_000, 8_000_000_000, 1_000_000_000, 0)
    if p.total_charged_bytes > pool:
        raise Error("IgpuAccount: plan charged more than the one pool")
    expect_eq(p.total_charged_bytes + p.headroom_bytes(), pool, "charged + headroom closes on the pool")
    print("PASS: iGPU budget never additive with the system pool; charged+headroom == pool exactly")


def test_budget_full_exact() raises:
    var p = plan_igpu_budget(10_000, 2_000, 500, 4_000, 1_000, 0)
    expect_eq(p.decision, IGPU_BUDGET_FULL, "full decision")
    expect_eq(p.fixed_bytes, 2_500, "fixed charged first in full")
    expect_eq(p.cache_target_bytes, 4_000, "cache at open budget")
    expect_eq(p.allowance_bytes, 9_000, "allowance = pool - floor")
    expect_eq(p.total_charged_bytes, 6_500, "total charged")
    print("PASS: full budget -- fixed 2500 + cache 4000 charged once against pool 10000")


def test_budget_shrunk_floor_held() raises:
    var p = plan_igpu_budget(10_000, 6_000, 500, 4_000, 1_000, 0)
    expect_eq(p.decision, IGPU_BUDGET_SHRUNK, "shrunk decision")
    expect_eq(p.cache_target_bytes, 3_500, "cache elastic: pool - fixed")
    if p.below_floor:
        raise Error("IgpuAccount: shrunk plan must hold the floor")
    print("PASS: shrunk budget -- cache absorbs the squeeze (3500), floor 1000 held")


def test_budget_refuses_below_floor() raises:
    var p = plan_igpu_budget(10_000, 9_000, 500, 4_000, 1_000, 0)
    expect_eq(p.decision, IGPU_BUDGET_REFUSE, "below-floor refusal")
    expect_eq(p.cache_target_bytes, 0, "refusal sizes no cache")
    var q = plan_igpu_budget(10_000, 10_500, 500, 4_000, 1_000, 0)
    expect_eq(q.decision, IGPU_BUDGET_REFUSE, "fixed-over-pool refusal")
    expect_eq(q.fixed_bytes, 11_000, "refusal states the fixed bytes that do not fit")
    print("PASS: refuse below the floor and refuse fixed-over-pool, numbers stated")


def test_floor_discipline_fixed_never_trimmed() raises:
    # J-048 with an iGPU in the pool: as fixed grows, the cache
    # target falls byte-for-byte; fixed is never trimmed; the
    # step that would break the floor refuses instead.
    var a = plan_igpu_budget(10_000, 1_000, 0, 9_000, 1_000, 0)
    var b = plan_igpu_budget(10_000, 2_000, 0, 9_000, 1_000, 0)
    var c = plan_igpu_budget(10_000, 3_000, 0, 9_000, 1_000, 0)
    expect_eq(a.fixed_bytes, 1_000, "fixed stated in full (a)")
    expect_eq(b.fixed_bytes, 2_000, "fixed stated in full (b)")
    expect_eq(a.cache_target_bytes - b.cache_target_bytes, 1_000, "cache falls byte-for-byte (a->b)")
    expect_eq(b.cache_target_bytes - c.cache_target_bytes, 1_000, "cache falls byte-for-byte (b->c)")
    var edge = plan_igpu_budget(10_000, 9_000, 0, 6_000, 1_000, 0)
    expect_eq(edge.cache_target_bytes, 1_000, "cache exactly at floor still stands")
    var over = plan_igpu_budget(10_000, 9_001, 0, 6_000, 1_000, 0)
    expect_eq(over.decision, IGPU_BUDGET_REFUSE, "one byte past the floor refuses")
    print("PASS: J-048 floor discipline unchanged with an iGPU -- fixed first, cache elastic, floor exact")


def test_tax_zero_copy_contended_bytes() raises:
    var t = plan_igpu_prefill_tax(1_000_000, 200_000, 50_000, 300_000, 0)
    expect_eq(t.copy_bytes_charged, 0, "no copy bytes on a shared fabric")
    expect_eq(t.contended_bytes, 1_250_000, "contended = weights+activations+KV")
    expect_eq(t.shared_traffic_bytes, 1_550_000, "shared traffic adds CPU co-load")
    print("PASS: prefill tax -- 0 copy bytes; contended 1250000; shared traffic 1550000 with co-load")


def test_tax_refuses_discrete_shape() raises:
    var refused = 0
    try:
        _ = plan_igpu_prefill_tax(1_000, 0, 0, 0, 4)
    except:
        refused += 1
    try:
        _ = plan_igpu_prefill_tax(-1, 0, 0, 0, 0)
    except:
        refused += 1
    expect_eq(refused, 2, "copy-claim and negative refusals")
    print("PASS: tax refuses a nonzero copy claim (discrete shape) and negative traffic")


def test_claim_verdict_branches() raises:
    expect_eq(evaluate_igpu_claim(True, True, True, False, False, False), IGPU_CLAIM_PERMITTED, "admission on accounting alone")
    expect_eq(evaluate_igpu_claim(True, True, True, True, False, False), IGPU_CLAIM_REQUIRES_LIVE, "speed win without live measurement")
    expect_eq(evaluate_igpu_claim(True, True, False, False, False, False), IGPU_CLAIM_REQUIRES_LIVE, "reply win never by accounting")
    expect_eq(evaluate_igpu_claim(True, True, True, True, True, True), IGPU_CLAIM_PERMITTED, "measured-faster speed win")
    expect_eq(evaluate_igpu_claim(True, True, True, True, True, False), IGPU_CLAIM_REQUIRES_LIVE, "measured not-faster is no win")
    expect_eq(evaluate_igpu_claim(False, True, True, False, False, False), IGPU_CLAIM_REFUSED, "does not fit refuses outright")
    expect_eq(evaluate_igpu_claim(True, False, True, False, False, False), IGPU_CLAIM_REFUSED, "floor broken refuses outright")
    print("PASS: claim verdict -- admission permitted; speed/reply require live; unfit/floor-broken refused")


def test_names_and_invalid_inputs() raises:
    if claim_name(IGPU_CLAIM_PERMITTED) != String("PERMITTED"):
        raise Error("IgpuAccount: PERMITTED name")
    if claim_name(IGPU_CLAIM_REQUIRES_LIVE) != String("REQUIRES_LIVE"):
        raise Error("IgpuAccount: REQUIRES_LIVE name")
    if claim_name(IGPU_CLAIM_REFUSED) != String("REFUSED"):
        raise Error("IgpuAccount: REFUSED name")
    var refused = 0
    try:
        _ = claim_name(99)
    except:
        refused += 1
    try:
        _ = plan_igpu_budget(10_000, 0, 0, 1_000, 2_000, 0)
    except:
        refused += 1
    try:
        _ = gpu_kind_name(99)
    except:
        refused += 1
    expect_eq(refused, 3, "unknown code / floor-over-open / unknown kind refusals")
    print("PASS: claim names exact; unknown codes and invalid budgets refused")


def main() raises:
    test_kind_distinct_and_pools()
    test_own_vram_only_discrete()
    test_budget_never_additive()
    test_budget_full_exact()
    test_budget_shrunk_floor_held()
    test_budget_refuses_below_floor()
    test_floor_discipline_fixed_never_trimmed()
    test_tax_zero_copy_contended_bytes()
    test_tax_refuses_discrete_shape()
    test_claim_verdict_branches()
    test_names_and_invalid_inputs()
    print("ALL PASS: igpu account (11 groups)")
