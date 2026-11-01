"""Cold-start honesty account (J-069): the four cold
components kept separate and summed exactly, the run
classifier (cold-first / warm / conflated), the repetition
rule (a warm median never contains the cold repetition),
and the claim verdict on every branch -- including the
refusal of a cold-first run published as a warm figure.
No timing, no wall, no speed: figures below are stated
millisecond values checking the arithmetic only.
"""
from core.cold_start_account import (
    CLAIM_COLD_WALL,
    CLAIM_SEPARATION,
    CLAIM_WARM_WALL,
    COLD_CLAIM_PERMITTED,
    COLD_CLAIM_REFUSED,
    COLD_CLAIM_REQUIRES_LIVE,
    REP_OK,
    REP_REFUSED_MIXED,
    REP_SINGLE_COLD_ONLY,
    RUN_COLD_FIRST,
    RUN_CONFLATED,
    RUN_WARM,
    classify_run,
    claim_name,
    evaluate_cold_claim,
    overhead_share_bp,
    plan_cold_start,
    repetition_verdict,
    repetition_verdict_name,
    run_class_name,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "ColdStartAccount " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def test_components_sum_exact() raises:
    # A stated cold first prompt: open 1200, compile 300,
    # prep 0 (no prep on this surface), cold prefill 28040
    # (the J-030 idle prefill figure restated as a component
    # value only -- arithmetic, not a new measurement).
    var a = plan_cold_start(1200, 300, 0, 28040, False, False, True, True)
    expect_eq(a.overhead_ms(), 1500, "overhead C1+C2+C3")
    expect_eq(a.total_ms(), 29540, "cold total C1+C2+C3+C4")
    expect_eq(overhead_share_bp(a), 507, "overhead share bp")
    print("PASS: cold components kept separate; total is the exact sum")


def test_prep_cold_vs_cached_are_distinct_figures() raises:
    # J-061's preparation: a cold prep and a graph-cache-hit
    # prep are two different C3 figures over the same C4;
    # the account keeps both, never an average of them.
    var cold = plan_cold_start(100, 0, 36000, 5000, True, False, True, True)
    var cached = plan_cold_start(100, 0, 3800, 5000, True, True, True, True)
    expect_eq(cold.prep_ms, 36000, "cold prep figure")
    expect_eq(cached.prep_ms, 3800, "cached prep figure")
    expect_eq(cold.total_ms(), 41100, "cold-prep total")
    expect_eq(cached.total_ms(), 8900, "cached-prep total")
    print("PASS: prep cold vs graph-cached kept as distinct C3 figures")


def test_plan_refusals() raises:
    var refused = 0
    try:
        _ = plan_cold_start(-1, 0, 0, 100, False, False, True, True)
    except:
        refused += 1
    try:
        # Prep figure for a preparation that does not apply.
        _ = plan_cold_start(0, 0, 500, 100, False, False, True, True)
    except:
        refused += 1
    try:
        # Graph-cache hit without a preparation.
        _ = plan_cold_start(0, 0, 0, 100, False, True, True, True)
    except:
        refused += 1
    try:
        # Cold prefill claimed against a warm expert cache.
        _ = plan_cold_start(0, 0, 0, 100, False, False, False, True)
    except:
        refused += 1
    expect_eq(refused, 4, "plan refusal count")
    print("PASS: plan refusals -- negative / stray prep / stray hit / warm cache (4/4)")


def test_classify_cold_first() raises:
    expect_eq(
        classify_run(True, True, True, True, True),
        RUN_COLD_FIRST,
        "first prompt, empty cache",
    )
    # The J-022/J-023/J-030 shape: a fresh process's only
    # prompt is cold-first however its wall is labelled.
    expect_eq(
        classify_run(True, True, False, False, False),
        RUN_COLD_FIRST,
        "single-shot process prompt",
    )
    print("PASS: first prompt after open with empty cache classifies cold-first")


def test_classify_warm() raises:
    expect_eq(
        classify_run(False, False, False, False, False),
        RUN_WARM,
        "later prompt, no open-time components",
    )
    expect_eq(
        classify_run(False, True, False, False, False),
        RUN_WARM,
        "later prompt, cache state irrelevant to the class",
    )
    print("PASS: later prompt with no open/compile/prep inside classifies warm")


def test_classify_conflated() raises:
    expect_eq(
        classify_run(False, False, True, False, False),
        RUN_CONFLATED,
        "later prompt still carrying open time",
    )
    expect_eq(
        classify_run(False, False, False, False, True),
        RUN_CONFLATED,
        "later prompt still carrying prep time",
    )
    expect_eq(
        classify_run(True, False, False, False, False),
        RUN_CONFLATED,
        "claimed first prompt, cache not empty",
    )
    print("PASS: mixed figures classify conflated, grounding neither claim")


def test_repetition_rule() raises:
    expect_eq(repetition_verdict(3, True), REP_OK, "first filed separately")
    expect_eq(repetition_verdict(3, False), REP_REFUSED_MIXED, "cold folded into median")
    expect_eq(repetition_verdict(1, True), REP_SINGLE_COLD_ONLY, "one run is cold only")
    expect_eq(repetition_verdict(1, False), REP_SINGLE_COLD_ONLY, "one run, no warm figure")
    if repetition_verdict_name(REP_REFUSED_MIXED) != String("refused_mixed_median"):
        raise Error("ColdStartAccount: mixed verdict name")
    print("PASS: repetition rule -- warm median never contains the cold run")


def test_separation_claim() raises:
    expect_eq(
        evaluate_cold_claim(CLAIM_SEPARATION, RUN_COLD_FIRST, True, False),
        COLD_CLAIM_PERMITTED,
        "all four components stated",
    )
    expect_eq(
        evaluate_cold_claim(CLAIM_SEPARATION, RUN_COLD_FIRST, False, False),
        COLD_CLAIM_REFUSED,
        "merged total is not a separation",
    )
    print("PASS: separation claim permitted only with every component stated")


def test_cold_wall_claim() raises:
    expect_eq(
        evaluate_cold_claim(CLAIM_COLD_WALL, RUN_COLD_FIRST, True, True),
        COLD_CLAIM_PERMITTED,
        "live cold-first run grounds a cold wall",
    )
    expect_eq(
        evaluate_cold_claim(CLAIM_COLD_WALL, RUN_COLD_FIRST, True, False),
        COLD_CLAIM_REQUIRES_LIVE,
        "accounting alone permits no cold wall",
    )
    expect_eq(
        evaluate_cold_claim(CLAIM_COLD_WALL, RUN_WARM, True, True),
        COLD_CLAIM_REFUSED,
        "a warm run cannot ground a cold figure",
    )
    print("PASS: cold wall -- permitted live+cold, requires-live unmeasured, refused warm")


def test_warm_wall_claim_refuses_cold_first() raises:
    # The conflation this slice exists to refuse: a cold-first
    # run (the J-030 single-shot shape) published as warm.
    expect_eq(
        evaluate_cold_claim(CLAIM_WARM_WALL, RUN_COLD_FIRST, True, True),
        COLD_CLAIM_REFUSED,
        "cold-first run published as warm",
    )
    expect_eq(
        evaluate_cold_claim(CLAIM_WARM_WALL, RUN_CONFLATED, True, True),
        COLD_CLAIM_REFUSED,
        "conflated run published as warm",
    )
    expect_eq(
        evaluate_cold_claim(CLAIM_WARM_WALL, RUN_WARM, True, False),
        COLD_CLAIM_REQUIRES_LIVE,
        "warm class but unmeasured",
    )
    expect_eq(
        evaluate_cold_claim(CLAIM_WARM_WALL, RUN_WARM, True, True),
        COLD_CLAIM_PERMITTED,
        "live warm run grounds a warm wall",
    )
    print("PASS: warm wall -- cold-first and conflated refused; live warm permitted")


def test_names_and_invalid_inputs() raises:
    if run_class_name(RUN_COLD_FIRST) != String("cold_first"):
        raise Error("ColdStartAccount: cold class name")
    if run_class_name(RUN_WARM) != String("warm"):
        raise Error("ColdStartAccount: warm class name")
    if claim_name(COLD_CLAIM_REQUIRES_LIVE) != String("REQUIRES_LIVE"):
        raise Error("ColdStartAccount: claim name")
    var refused = 0
    try:
        _ = run_class_name(99)
    except:
        refused += 1
    try:
        _ = claim_name(99)
    except:
        refused += 1
    try:
        _ = evaluate_cold_claim(99, RUN_WARM, True, True)
    except:
        refused += 1
    try:
        _ = repetition_verdict(0, True)
    except:
        refused += 1
    try:
        var zero = plan_cold_start(0, 0, 0, 0, False, False, True, True)
        _ = overhead_share_bp(zero)
    except:
        refused += 1
    expect_eq(refused, 5, "invalid input count")
    print("PASS: names exact; unknown codes and zero totals refused (5/5)")


def main() raises:
    test_components_sum_exact()
    test_prep_cold_vs_cached_are_distinct_figures()
    test_plan_refusals()
    test_classify_cold_first()
    test_classify_warm()
    test_classify_conflated()
    test_repetition_rule()
    test_separation_claim()
    test_cold_wall_claim()
    test_warm_wall_claim_refuses_cold_first()
    test_names_and_invalid_inputs()
    print("ALL PASS: cold-start honesty account (11 groups)")
