"""MoE GPU division plan (J-031): division derivation from stated
budgets, per-token transfer accounting, and open-upload pricing.

All model numbers are the J-015/J-017 measured OLMoE figures and the
J-021 device figure, restated in the test so the arithmetic is
checked against the road's own record, not against new claims:
resident 311,027,712 B; expert body 3,900,702,720 B over 1,024 pairs
(mean pair 3,809,280 B exactly; largest pair 4,079,616 B); cold
per-token routed ceiling 487,587,840 B. The device budget
5,368,709,120 B is the usable figure the engine's own admission
recorded for purplelongship's 6 GiB card (J-021). The KV allowance
67,108,864 B is arithmetic on stated dims (context 512 x 16 layers x
K+V x 2048-wide x f16) -- an allowance input, not a KV census
(J-087 owns that). The reserve 268,435,456 B is the dense CUDA
session's default reserve; the activation allowance 16,777,216 B is
a named planning allowance. Both are inputs the host states, which
is the module's contract.
"""
from core.moe_gpu_plan import (
    DIVISION_CPU_ONLY,
    DIVISION_FULL_GPU,
    DIVISION_RESIDENT_GPU,
    DIVISION_RESIDENT_GPU_EXPERT_CACHE,
    moe_gpu_upload_chunks,
    plan_moe_gpu_division,
    plan_moe_gpu_token_transfers,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "MoeGpuPlan "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("MoeGpuPlan " + what + ": expected true")


# The stated machine's fixed device charge: resident + KV +
# activation + reserve.
comptime FIXED = 311027712 + 67108864 + 16777216 + 268435456


def test_moe_gpu_division_full() raises:
    # On the stated 6 GiB card the whole OLMoE model fits: resident
    # + allowances + the entire expert body stay under the usable
    # budget, so the plan is the degenerate full-residency division
    # (J-017 section 4.3's case, on the device).
    var plan = plan_moe_gpu_division(
        311027712, 3900702720, 3809280, 4079616,
        67108864, 16777216, 268435456, 5368709120,
    )
    expect_eq(plan.division, DIVISION_FULL_GPU, "full division code")
    expect_true(plan.resident_on_gpu(), "full division resident on GPU")
    expect_eq(plan.device_resident_bytes, 311027712, "full resident bytes")
    expect_eq(
        plan.device_expert_budget_bytes, 3900702720, "full expert budget"
    )
    expect_eq(plan.device_expert_pairs, 1024, "full expert pairs")
    expect_eq(plan.fixed_device_bytes(), FIXED, "full fixed charge")
    expect_eq(
        plan.device_total_bytes(),
        FIXED + 3900702720,
        "full device total",
    )
    if plan.device_total_bytes() > plan.device_budget_bytes:
        raise Error("MoeGpuPlan full division exceeds its device budget")
    print("PASS: moe gpu division full residency on the stated card")


def test_moe_gpu_division_cache() raises:
    # A 2 GiB device budget: the resident set fits and the remainder
    # (1,484,134,400 B) holds whole experts -- 389 at the mean pair
    # size, the byte budget governing.
    var plan = plan_moe_gpu_division(
        311027712, 3900702720, 3809280, 4079616,
        67108864, 16777216, 268435456, 2147483648,
    )
    expect_eq(
        plan.division,
        DIVISION_RESIDENT_GPU_EXPERT_CACHE,
        "cache division code",
    )
    expect_eq(
        plan.device_expert_budget_bytes, 1484134400, "cache expert budget"
    )
    expect_eq(plan.device_expert_pairs, 389, "cache expert pairs at mean")
    expect_eq(
        plan.device_total_bytes(), 2147483648, "cache division fills budget"
    )
    # Boundary: a remainder of exactly the largest pair buys exactly
    # one device-resident expert (at the mean-derived count, 1).
    var edge = plan_moe_gpu_division(
        311027712, 3900702720, 3809280, 4079616,
        67108864, 16777216, 268435456, FIXED + 4079616,
    )
    expect_eq(
        edge.division,
        DIVISION_RESIDENT_GPU_EXPERT_CACHE,
        "largest-pair remainder is a cache division",
    )
    expect_eq(edge.device_expert_pairs, 1, "largest-pair remainder pairs")
    print("PASS: moe gpu division device expert cache + boundary")


def test_moe_gpu_division_resident_only() raises:
    # One byte less than the largest pair of remainder: no whole
    # expert fits, so there is no device expert cache at all -- the
    # remainder is reported, never spent on a partial expert (the
    # J-017 atomic-unit rule).
    var plan = plan_moe_gpu_division(
        311027712, 3900702720, 3809280, 4079616,
        67108864, 16777216, 268435456, FIXED + 4079616 - 1,
    )
    expect_eq(plan.division, DIVISION_RESIDENT_GPU, "resident-only code")
    expect_eq(plan.device_expert_pairs, 0, "resident-only pairs")
    expect_eq(
        plan.device_expert_budget_bytes, 4079615, "resident-only remainder"
    )
    expect_true(plan.resident_on_gpu(), "resident-only resident on GPU")
    print("PASS: moe gpu division resident-only below one whole expert")


def test_moe_gpu_division_cpu_only() raises:
    # Resident + allowances exceed the device budget by one byte:
    # the honest plan is the CPU line, allocating nothing.
    var plan = plan_moe_gpu_division(
        311027712, 3900702720, 3809280, 4079616,
        67108864, 16777216, 268435456, FIXED - 1,
    )
    expect_eq(plan.division, DIVISION_CPU_ONLY, "cpu-only code")
    if plan.resident_on_gpu():
        raise Error("MoeGpuPlan cpu-only division claims GPU residency")
    expect_eq(plan.device_resident_bytes, 0, "cpu-only resident bytes")
    expect_eq(plan.device_expert_budget_bytes, 0, "cpu-only expert budget")
    expect_eq(plan.device_total_bytes(), 0, "cpu-only device total")
    print("PASS: moe gpu division cpu-only refusal stated in the plan")


def test_moe_gpu_transfers() raises:
    var cpu_plan = plan_moe_gpu_division(
        311027712, 3900702720, 3809280, 4079616,
        67108864, 16777216, 268435456, FIXED - 1,
    )
    var resident_plan = plan_moe_gpu_division(
        311027712, 3900702720, 3809280, 4079616,
        67108864, 16777216, 268435456, FIXED + 4079616 - 1,
    )
    var cache_plan = plan_moe_gpu_division(
        311027712, 3900702720, 3809280, 4079616,
        67108864, 16777216, 268435456, 2147483648,
    )
    var full_plan = plan_moe_gpu_division(
        311027712, 3900702720, 3809280, 4079616,
        67108864, 16777216, 268435456, 5368709120,
    )

    # CPU line: no device traffic, whatever the token streamed.
    var cpu_tok = plan_moe_gpu_token_transfers(
        cpu_plan, 16, 2048, 487587840, 16
    )
    expect_eq(cpu_tok.total_bytes(), 0, "cpu token total")
    expect_eq(cpu_tok.crossings, 0, "cpu token crossings")

    # Resident-only: the hidden vector (2048 x f16 = 4096 B) crosses
    # both ways at every one of the 16 layers; experts never move.
    var res_tok = plan_moe_gpu_token_transfers(
        resident_plan, 16, 2048, 487587840, 16
    )
    expect_eq(res_tok.h2d_expert_bytes, 0, "resident token expert bytes")
    expect_eq(res_tok.h2d_hidden_bytes, 65536, "resident token h2d hidden")
    expect_eq(res_tok.d2h_hidden_bytes, 65536, "resident token d2h hidden")
    expect_eq(res_tok.crossings, 32, "resident token crossings")
    expect_eq(res_tok.total_bytes(), 131080, "resident token total")

    # Expert-cache division, cold token: the upload re-pays the
    # streamed bytes exactly (487,587,840 B, the J-017 cold ceiling)
    # -- GPU assistance does not shrink the byte traffic.
    var cold_tok = plan_moe_gpu_token_transfers(
        cache_plan, 16, 2048, 487587840, 16
    )
    expect_eq(
        cold_tok.h2d_expert_bytes, 487587840, "cache cold upload == streamed"
    )
    expect_eq(cold_tok.h2d_hidden_bytes, 0, "cache cold hidden stays")
    expect_eq(cold_tok.crossings, 17, "cache cold crossings (1 + layers)")
    expect_eq(cold_tok.total_bytes(), 487587848, "cache cold total")

    # Warm token under the cache division: no misses, no uploads,
    # one synchronisation, token in/out only.
    var warm_tok = plan_moe_gpu_token_transfers(cache_plan, 16, 2048, 0, 0)
    expect_eq(warm_tok.h2d_expert_bytes, 0, "cache warm upload")
    expect_eq(warm_tok.crossings, 1, "cache warm crossings")
    expect_eq(warm_tok.total_bytes(), 8, "cache warm total")

    # Disagreeing miss facts are refused, not averaged over.
    var refused = False
    try:
        _ = plan_moe_gpu_token_transfers(cache_plan, 16, 2048, 100, 0)
    except:
        refused = True
    if not refused:
        raise Error("MoeGpuPlan accepted streamed bytes with no miss layer")

    # Full division: a warm token moves only the token id both ways;
    # a token claiming expert traffic under FULL is refused (cold
    # misses there are open-time uploads, priced separately).
    var full_tok = plan_moe_gpu_token_transfers(full_plan, 16, 2048, 0, 0)
    expect_eq(full_tok.total_bytes(), 8, "full token total")
    expect_eq(full_tok.crossings, 1, "full token crossings")
    refused = False
    try:
        _ = plan_moe_gpu_token_transfers(full_plan, 16, 2048, 100, 1)
    except:
        refused = True
    if not refused:
        raise Error("MoeGpuPlan accepted per-token traffic under FULL")
    print("PASS: moe gpu per-token transfer accounting per division")


def test_moe_gpu_upload_chunks() raises:
    expect_eq(moe_gpu_upload_chunks(0), 0, "no bytes, no chunks")
    expect_eq(moe_gpu_upload_chunks(67108864), 1, "one full chunk")
    expect_eq(moe_gpu_upload_chunks(67108865), 2, "one byte over, two")
    # The resident set's one-time upload: 5 synchronised chunks.
    expect_eq(moe_gpu_upload_chunks(311027712), 5, "resident upload chunks")
    # The expert body's: 59 chunks -- the full division's open cost.
    expect_eq(moe_gpu_upload_chunks(3900702720), 59, "body upload chunks")
    var refused = False
    try:
        _ = moe_gpu_upload_chunks(-1)
    except:
        refused = True
    if not refused:
        raise Error("MoeGpuPlan accepted a negative upload size")
    print("PASS: moe gpu open-upload staging chunks")


def test_moe_gpu_refusals() raises:
    var refused = False
    try:
        _ = plan_moe_gpu_division(
            0, 3900702720, 3809280, 4079616,
            67108864, 16777216, 268435456, 5368709120,
        )
    except:
        refused = True
    if not refused:
        raise Error("MoeGpuPlan accepted a zero resident set")
    refused = False
    try:
        # Largest pair below the mean is a contradiction in inputs.
        _ = plan_moe_gpu_division(
            311027712, 3900702720, 4079616, 3809280,
            67108864, 16777216, 268435456, 5368709120,
        )
    except:
        refused = True
    if not refused:
        raise Error("MoeGpuPlan accepted largest pair below the mean")
    refused = False
    try:
        _ = plan_moe_gpu_division(
            311027712, 3900702720, 3809280, 4079616,
            -1, 16777216, 268435456, 5368709120,
        )
    except:
        refused = True
    if not refused:
        raise Error("MoeGpuPlan accepted a negative allowance")
    print("PASS: moe gpu division input refusals")


def test_moe_gpu_plan() raises:
    test_moe_gpu_division_full()
    test_moe_gpu_division_cache()
    test_moe_gpu_division_resident_only()
    test_moe_gpu_division_cpu_only()
    test_moe_gpu_transfers()
    test_moe_gpu_upload_chunks()
    test_moe_gpu_refusals()


def main() raises:
    test_moe_gpu_plan()
