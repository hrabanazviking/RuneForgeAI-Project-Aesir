"""Placement under memory pressure (J-048): the contention
rule where the Part II expert cache and a Part III device
placement compete for one memory pool -- fixed placement bytes
charged first (J-028 reserve / J-031 division order), the cache
elastic and capped at its open budget, duplicate device copies
cache-class unless a hand names them, degrade-before-refuse for
an optional device cache, clean refusal for a required cache or
an over-pool fixed charge, and J-047 manual supremacy (a hand
choice is refused whole, never overridden).

The byte fixtures are Aesir's filed numbers, not inventions:
OLMoE's mean full-scale pair 3,809,280 B (J-016/J-028: scaled
3,720 x 1,024), floor 128 pairs = 487,587,840 B (J-028), expert
body 1,024 pairs = 3,900,702,720 B and resident set
311,027,712 B with 352,321,536 B of KV/activation/reserve
allowances on a 5,368,709,120 B usable device budget (J-031).
The live group runs J-037's real observer on this machine.
No inference runs; the planner is pure arithmetic.
"""
from core.device_inventory import observe_device_inventory
from core.placement_pressure import (
    CONTENTION_FULL,
    CONTENTION_NO_CACHE,
    CONTENTION_REFUSE,
    CONTENTION_SHRUNK,
    PlacementPressurePlan,
    contention_name,
    plan_placement_pressure,
)

comptime PAIR = 3809280
comptime FLOOR = 487587840
comptime C256 = 975175680
comptime C512 = 1950351360
comptime BODY = 3900702720
comptime RESIDENT = 311027712
comptime ALLOW = 352321536
comptime FIXED = 663349248
comptime DEVPOOL = 5368709120


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "PlacementPressure "
            + what
            + ": expected "
            + String(expected)
            + ", got "
            + String(actual)
        )


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("PlacementPressure " + what + ": expected true")


def expect_false(value: Bool, what: String) raises:
    if value:
        raise Error("PlacementPressure " + what + ": expected false")


def expect_contains(text: String, needle: String, what: String) raises:
    if needle not in text:
        raise Error(
            "PlacementPressure "
            + what
            + ": expected to contain '"
            + needle
            + "', got '"
            + text
            + "'"
        )


def _plan(
    pool: Int,
    fixed: Int,
    reserve: Int,
    open_bytes: Int,
    copy: Int,
    copy_manual: Bool,
    required: Bool,
    manual: Bool,
) raises -> PlacementPressurePlan:
    return plan_placement_pressure(
        pool, fixed, reserve, open_bytes, FLOOR, PAIR, BODY,
        copy, copy_manual, required, manual,
    )


def test_j031_full_gpu_exact() raises:
    var p = _plan(DEVPOOL, RESIDENT, ALLOW, BODY, 0, False, False, False)
    expect_eq(p.decision, CONTENTION_FULL, "j031 division is full")
    expect_eq(p.fixed_bytes, FIXED, "fixed charged first, in full")
    expect_eq(p.cache_target_bytes, BODY, "whole body is the device cache")
    expect_eq(p.headroom_bytes(), 804657152, "j031 headroom exact")
    expect_true(p.placement_stands, "placement stands")
    expect_false(p.below_floor, "not below floor")
    print("PASS: pressure -- J-031 stated machine reproduces FULL exact")


def test_shrunk_to_512_pairs() raises:
    var p = _plan(FIXED + C512, RESIDENT, ALLOW, BODY, 0, False, False, False)
    expect_eq(p.decision, CONTENTION_SHRUNK, "cache shrinks, placement stands")
    expect_eq(p.cache_target_bytes, C512, "cache target is 512 pairs in bytes")
    expect_eq(p.fixed_bytes, FIXED, "fixed bytes never cannibalised")
    expect_eq(p.headroom_bytes(), 0, "pool fully accounted")
    print("PASS: pressure -- contention shrinks the cache to 512 pairs")


def test_floor_exactly_continues() raises:
    var p = _plan(FIXED + FLOOR, RESIDENT, ALLOW, BODY, 0, False, True, False)
    expect_eq(p.decision, CONTENTION_SHRUNK, "at the floor the run continues")
    expect_eq(p.cache_target_bytes, FLOOR, "cache target is the floor")
    expect_false(p.below_floor, "floor exactly is not below floor")
    print("PASS: pressure -- floor exactly continues (J-028 boundary)")


def test_below_floor_optional_degrades() raises:
    var p = _plan(FIXED + FLOOR - 1, RESIDENT, ALLOW, BODY, 0, False, False, False)
    expect_eq(p.decision, CONTENTION_NO_CACHE, "optional cache degrades to zero")
    expect_eq(p.cache_target_bytes, 0, "no device cache")
    expect_true(p.placement_stands, "placement stands; experts stay on host")
    expect_true(p.below_floor, "below floor stated")
    print("PASS: pressure -- optional device cache degrades before refusal")


def test_below_floor_required_refuses() raises:
    var p = _plan(FIXED + FLOOR - 1, RESIDENT, ALLOW, BODY, 0, False, True, False)
    expect_eq(p.decision, CONTENTION_REFUSE, "required cache below floor refuses")
    expect_eq(p.cache_target_bytes, 0, "refusal holds no cache")
    expect_false(p.placement_stands, "the session refuses whole")
    expect_false(p.choice_overridden, "refusal is not an override")
    print("PASS: pressure -- required cache below floor refuses cleanly")


def test_fixed_over_pool_refuses_manual_untraded() raises:
    var p = _plan(FIXED - 1, RESIDENT, ALLOW, BODY, 0, False, False, True)
    expect_eq(p.decision, CONTENTION_REFUSE, "fixed alone over pool refuses")
    expect_true(p.manual_governing, "manual governing stated")
    expect_false(p.choice_overridden, "hand choice never overridden")
    expect_false(p.placement_stands, "whole refusal, no substitution")
    print("PASS: pressure -- over-pool hand placement refused, never traded")


def test_auto_copy_closed_then_admitted() raises:
    var copy = 200000000
    var closed = _plan(
        FIXED + copy + FLOOR - 1, RESIDENT, ALLOW, BODY,
        copy, False, False, False,
    )
    expect_true(closed.copy_closed, "auto copy closed at the floor line")
    expect_eq(closed.copy_charged_bytes, 0, "closed copy charges nothing")
    expect_eq(
        closed.cache_target_bytes, copy + FLOOR - 1,
        "cache keeps the bytes the copy would have taken",
    )
    var admitted = _plan(
        FIXED + copy + FLOOR, RESIDENT, ALLOW, BODY,
        copy, False, False, False,
    )
    expect_false(admitted.copy_closed, "auto copy admitted with floor kept")
    expect_eq(admitted.copy_charged_bytes, copy, "admitted copy charged")
    expect_eq(admitted.cache_target_bytes, FLOOR, "cache at the floor")
    print("PASS: pressure -- auto duplicate copy closed / admitted at floor")


def test_manual_copy_charged_as_fixed() raises:
    var copy = 200000000
    var p = _plan(
        FIXED + copy + FLOOR - 1, RESIDENT, ALLOW, BODY,
        copy, True, False, True,
    )
    expect_false(p.copy_closed, "a hand-named copy is not closed")
    expect_eq(p.copy_charged_bytes, copy, "hand copy charged as fixed")
    expect_eq(p.decision, CONTENTION_NO_CACHE, "cache degrades, copy stands")
    expect_true(p.placement_stands, "placement and its copy stand")
    expect_false(p.choice_overridden, "hand copy never overridden")
    print("PASS: pressure -- hand-named copy charges as fixed (supremacy)")


def test_regrow_and_body_caps() raises:
    var huge = _plan(DEVPOOL * 4, RESIDENT, ALLOW, BODY, 0, False, False, False)
    expect_eq(huge.cache_target_bytes, BODY, "cache capped at the body")
    expect_eq(huge.decision, CONTENTION_FULL, "body-capped cache is full")
    var open_capped = _plan(
        DEVPOOL * 4, RESIDENT, ALLOW, C512, 0, False, False, False
    )
    expect_eq(open_capped.cache_target_bytes, C512, "cache capped at open budget")
    expect_eq(open_capped.decision, CONTENTION_FULL, "open-capped cache is full")
    print("PASS: pressure -- regrow capped at open budget and at the body")


def test_largest_pair_threshold_optional_only() raises:
    var opt = plan_placement_pressure(
        93000, 90000, 0, 10000, 1000, 5000, 100000,
        0, False, False, False,
    )
    expect_eq(opt.decision, CONTENTION_NO_CACHE, "optional cache under one pair holds nothing")
    var req = plan_placement_pressure(
        93000, 90000, 0, 10000, 1000, 5000, 100000,
        0, False, True, False,
    )
    expect_eq(req.cache_target_bytes, 3000, "required cache keeps its above-floor bytes")
    expect_eq(req.decision, CONTENTION_SHRUNK, "required cache shrinks, not degrades")
    print("PASS: pressure -- largest-pair threshold binds optional caches only")


def test_manual_governing_shrinks_cache_never_fixed() raises:
    var p = _plan(FIXED + FLOOR, RESIDENT, ALLOW, BODY, 0, False, True, True)
    expect_eq(p.decision, CONTENTION_SHRUNK, "cache absorbs all contention")
    expect_eq(p.fixed_bytes, FIXED, "hand placement fixed bytes untouched")
    expect_true(p.manual_governing, "manual governing on the plan")
    expect_false(p.choice_overridden, "no override under manual governing")
    print("PASS: pressure -- under a hand choice only the cache moves")


def test_validation_refusals() raises:
    var refused = 0
    try:
        _ = plan_placement_pressure(
            -1, RESIDENT, ALLOW, BODY, FLOOR, PAIR, BODY,
            0, False, False, False,
        )
    except:
        refused += 1
    try:
        _ = plan_placement_pressure(
            DEVPOOL, RESIDENT, ALLOW, BODY, 0, PAIR, BODY,
            0, False, False, False,
        )
    except:
        refused += 1
    try:
        _ = plan_placement_pressure(
            DEVPOOL, RESIDENT, ALLOW, FLOOR - 1, FLOOR, PAIR, BODY,
            0, False, False, False,
        )
    except:
        refused += 1
    try:
        _ = plan_placement_pressure(
            DEVPOOL, RESIDENT, ALLOW, BODY, FLOOR, BODY + 1, BODY,
            0, False, False, False,
        )
    except:
        refused += 1
    expect_eq(refused, 4, "four invalid inputs refused")
    print("PASS: pressure -- validation refusals (pool, floor, open, pair)")


def test_describe_states_the_plan() raises:
    var p = _plan(FIXED + C256, RESIDENT, ALLOW, BODY, 0, False, False, False)
    var text = p.describe()
    expect_contains(text, "decision=shrunk", "describe names the decision")
    expect_contains(text, "cache_target_bytes=" + String(C256), "describe states target")
    expect_contains(text, "choice_overridden=False", "describe states supremacy")
    expect_contains(contention_name(CONTENTION_FULL), "full", "decision names")
    print("PASS: pressure -- describe states decision, bytes, supremacy")


def test_live_inventory_device_pool() raises:
    var inv = observe_device_inventory()
    print("LIVE DEVICE LINE: " + inv.device_line())
    expect_true(inv.cpu.present, "live cpu present")
    expect_true(not inv.gpu.present, "live gpu absent on this VM")
    expect_true(not inv.npu.present, "live npu parked/absent on this road")
    # An absent GPU offers no device pool: a device contention
    # plan over a zero pool refuses, it does not invent memory.
    var p = _plan(0, RESIDENT, ALLOW, BODY, 0, False, False, False)
    expect_eq(p.decision, CONTENTION_REFUSE, "zero device pool refuses")
    expect_false(p.choice_overridden, "live refusal overrides nothing")
    print("PASS: pressure -- live inventory: absent GPU offers no pool")


def main() raises:
    test_j031_full_gpu_exact()
    test_shrunk_to_512_pairs()
    test_floor_exactly_continues()
    test_below_floor_optional_degrades()
    test_below_floor_required_refuses()
    test_fixed_over_pool_refuses_manual_untraded()
    test_auto_copy_closed_then_admitted()
    test_manual_copy_charged_as_fixed()
    test_regrow_and_body_caps()
    test_largest_pair_threshold_optional_only()
    test_manual_governing_shrinks_cache_never_fixed()
    test_validation_refusals()
    test_describe_states_the_plan()
    test_live_inventory_device_pool()
    print("ALL PASS: placement under memory pressure (14 groups)")
