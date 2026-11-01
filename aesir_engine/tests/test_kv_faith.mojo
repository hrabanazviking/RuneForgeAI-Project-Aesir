"""KV faithfulness grading harness (J-089): the paired
logit-row reduction -- forced-token rank and logit gap
under the module header's definitions -- and the pair
verdicts it composes through J-060's grade_prefill_cell,
including the near-tie band edges (rank 2 / gap 999 in,
rank 2 / gap 1000 out, rank 3 out, sub-logit strict),
tie handling, the J-022 post-fix witness pattern
reproduced at logit-row level, and the refusals (width /
step-count mismatch, empty rows, non-finite logits, the
sub-milli positive-rank refusal). Synthetic paired rows
with known ranks/gaps throughout: no model, no logits
produced, no wall claimed.
"""
from core.kv_faith import grade_kv_pair, grade_kv_step
from core.prefill_grade import (
    STEP_DIVERGENT,
    STEP_EXACT,
    STEP_NEAR_TIE,
    VERDICT_COMPARATOR_ARTIFACT,
    VERDICT_DIVERGENT,
    VERDICT_FAITHFUL,
    VERDICT_NEAR_TIE,
    VERDICT_NOT_GRADED,
    VERDICT_STEP0_BOUNDARY,
    step_class,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "KVFaith " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def row3(a: Float32, b: Float32, c: Float32) -> List[Float32]:
    var r = List[Float32]()
    r.append(a)
    r.append(b)
    r.append(c)
    return r^


def row4(a: Float32, b: Float32, c: Float32, d: Float32) -> List[Float32]:
    var r = List[Float32]()
    r.append(a)
    r.append(b)
    r.append(c)
    r.append(d)
    return r^


def test_exact_and_near_steps() raises:
    # Identical rows: forced token is the test maximum.
    var s = grade_kv_step(
        row4(Float32(0.1), Float32(2.0), Float32(0.5), Float32(-1.0)),
        row4(Float32(0.1), Float32(2.0), Float32(0.5), Float32(-1.0)),
    )
    expect_eq(s.ref_top, 1, "exact ref_top")
    expect_eq(s.test_top, 1, "exact test_top")
    expect_eq(s.rank, 0, "exact rank")
    expect_eq(s.gap_milli, 0, "exact gap")
    if not s.top_agrees:
        raise Error("KVFaith: exact step must agree on top")
    expect_eq(step_class(s.rank, s.gap_milli), STEP_EXACT, "exact class")
    # The J-022 witness shape at row level: rank 1, gap
    # 0.108 (the post-fix step-23 near-tie, as a row pair).
    var n = grade_kv_step(
        row3(Float32(3.0), Float32(2.9), Float32(0.0)),
        row3(Float32(2.892), Float32(3.0), Float32(0.0)),
    )
    expect_eq(n.ref_top, 0, "near ref_top")
    expect_eq(n.test_top, 1, "near test_top")
    expect_eq(n.rank, 1, "near rank")
    expect_eq(n.gap_milli, 108, "near gap milli")
    if n.top_agrees:
        raise Error("KVFaith: near step tops must differ")
    expect_eq(step_class(n.rank, n.gap_milli), STEP_NEAR_TIE, "near class")
    # Gap rounding is half-up at milli resolution:
    # 0.0625 -> 63 milli exactly (binary-exact values).
    var g = grade_kv_step(
        row3(Float32(2.0), Float32(1.0), Float32(0.0)),
        row3(Float32(1.9375), Float32(2.0), Float32(0.0)),
    )
    expect_eq(g.gap_milli, 63, "half-up rounding 0.0625 -> 63")
    print("PASS: exact + near-tie steps -- rank 0/gap 0 exact; rank 1 gap 108 near-tie; gap rounding half-up")


def test_near_tie_band_edges() raises:
    # Rank 2 with gap 999 milli: IN (both conjuncts, edge).
    var a = grade_kv_step(
        row4(Float32(3.0), Float32(0.0), Float32(0.0), Float32(0.0)),
        row4(Float32(1.0), Float32(1.999), Float32(1.5), Float32(0.0)),
    )
    expect_eq(a.rank, 2, "edge rank 2")
    expect_eq(a.gap_milli, 999, "edge gap 999")
    expect_eq(step_class(a.rank, a.gap_milli), STEP_NEAR_TIE, "rank2/999 near-tie")
    # Rank 2 with gap exactly 1.000 logit: OUT (sub-logit
    # is strict) -- the band's upper edge.
    var b = grade_kv_step(
        row3(Float32(3.0), Float32(0.0), Float32(0.0)),
        row3(Float32(1.0), Float32(2.0), Float32(1.5)),
    )
    expect_eq(b.rank, 2, "edge rank 2 (gap 1000)")
    expect_eq(b.gap_milli, 1000, "edge gap 1000")
    expect_eq(step_class(b.rank, b.gap_milli), STEP_DIVERGENT, "rank2/1000 divergent")
    # Rank 3 with a tiny gap: OUT (the rank conjunct binds).
    var c = grade_kv_step(
        row4(Float32(3.0), Float32(0.0), Float32(0.0), Float32(0.0)),
        row4(Float32(1.0), Float32(1.01), Float32(1.02), Float32(1.03)),
    )
    expect_eq(c.rank, 3, "rank 3")
    expect_eq(c.gap_milli, 30, "rank 3 gap 30")
    expect_eq(step_class(c.rank, c.gap_milli), STEP_DIVERGENT, "rank3 divergent")
    # Rank 2 with gap 1138 milli: OUT (J-022 pre-fix step
    # 17's shape -- rank inside the band, gap outside).
    var d = grade_kv_step(
        row3(Float32(3.0), Float32(0.0), Float32(0.0)),
        row3(Float32(1.0), Float32(2.138), Float32(1.5)),
    )
    expect_eq(d.rank, 2, "rank 2 (gap 1138)")
    expect_eq(d.gap_milli, 1138, "gap 1138")
    expect_eq(step_class(d.rank, d.gap_milli), STEP_DIVERGENT, "rank2/1138 divergent")
    print("PASS: near-tie band edges -- rank2+gap999 IN; rank2+gap1000 OUT; rank3 OUT; rank2+gap1138 OUT")


def test_ties() raises:
    # Reference tie: the forced token is the FIRST maximum.
    var s = grade_kv_step(
        row3(Float32(1.0), Float32(3.0), Float32(3.0)),
        row3(Float32(0.0), Float32(2.5), Float32(2.5)),
    )
    expect_eq(s.ref_top, 1, "ref tie -> first maximum")
    expect_eq(s.test_top, 1, "test tie -> first maximum")
    # A test-row tie AT the forced token's logit shares
    # rank 0: only strictly greater logits count.
    expect_eq(s.rank, 0, "tie at target ranks 0")
    expect_eq(s.gap_milli, 0, "tie at target gaps 0")
    expect_eq(step_class(s.rank, s.gap_milli), STEP_EXACT, "tie step exact")
    print("PASS: ties -- argmax takes the first maximum; a tied maximum shares rank 0 / gap 0")


def test_pair_verdicts() raises:
    var refs = List[List[Float32]]()
    var tst = List[List[Float32]]()
    # FAITHFUL: three identical pairs.
    for _ in range(3):
        refs.append(row3(Float32(3.0), Float32(1.0), Float32(0.0)))
        tst.append(row3(Float32(3.0), Float32(1.0), Float32(0.0)))
    var s = grade_kv_pair(refs, tst, True)
    expect_eq(s.verdict, VERDICT_FAITHFUL, "all-exact verdict")
    expect_eq(s.exact_count, 3, "all-exact count")
    # NEAR_TIE: exact + one near step (rank 1, gap 108).
    tst[1] = row3(Float32(2.892), Float32(3.0), Float32(0.0))
    refs[1] = row3(Float32(3.0), Float32(2.9), Float32(0.0))
    s = grade_kv_pair(refs, tst, True)
    expect_eq(s.verdict, VERDICT_NEAR_TIE, "near-tie verdict")
    expect_eq(s.near_tie_count, 1, "near-tie count")
    expect_eq(s.exact_count, 2, "near-tie cell exact count")
    # DIVERGENT: a divergent step (rank 3) at step 2.
    tst[2] = row4(Float32(1.0), Float32(1.01), Float32(1.02), Float32(1.03))
    refs[2] = row4(Float32(3.0), Float32(0.0), Float32(0.0), Float32(0.0))
    s = grade_kv_pair(refs, tst, True)
    expect_eq(s.verdict, VERDICT_DIVERGENT, "divergent verdict")
    expect_eq(s.first_divergent_step, 2, "first divergent step")
    expect_eq(s.worst_rank, 3, "worst rank")
    # STEP0_BOUNDARY: divergence at step 0 only, exact after.
    var refs0 = List[List[Float32]]()
    var tst0 = List[List[Float32]]()
    refs0.append(row4(Float32(3.0), Float32(0.0), Float32(0.0), Float32(0.0)))
    tst0.append(row4(Float32(1.0), Float32(1.01), Float32(1.02), Float32(1.03)))
    refs0.append(row3(Float32(3.0), Float32(1.0), Float32(0.0)))
    tst0.append(row3(Float32(3.0), Float32(1.0), Float32(0.0)))
    s = grade_kv_pair(refs0, tst0, True)
    expect_eq(s.verdict, VERDICT_STEP0_BOUNDARY, "step0-only verdict")
    print("PASS: pair verdicts -- FAITHFUL / NEAR_TIE / DIVERGENT (first at 2) / STEP0_BOUNDARY")


def test_pair_verdicts_honesty() raises:
    # NOT_GRADED: an empty pair is never a graded class.
    var empty_ref = List[List[Float32]]()
    var empty_tst = List[List[Float32]]()
    var s = grade_kv_pair(empty_ref, empty_tst, True)
    expect_eq(s.verdict, VERDICT_NOT_GRADED, "empty pair not graded")
    expect_eq(s.steps, 0, "empty pair steps")
    # COMPARATOR_ARTIFACT takes precedence over perfect rows.
    var refs = List[List[Float32]]()
    var tst = List[List[Float32]]()
    refs.append(row3(Float32(3.0), Float32(1.0), Float32(0.0)))
    tst.append(row3(Float32(3.0), Float32(1.0), Float32(0.0)))
    s = grade_kv_pair(refs, tst, False)
    expect_eq(s.verdict, VERDICT_COMPARATOR_ARTIFACT, "invalid comparator verdict")
    # The J-022 post-fix witness pattern through logit
    # rows: 23 exact steps + step 23 near-tie (rank 1,
    # gap 108) grades NEAR_TIE with the counts intact.
    var wref = List[List[Float32]]()
    var wtst = List[List[Float32]]()
    for _ in range(23):
        wref.append(row3(Float32(3.0), Float32(1.0), Float32(0.0)))
        wtst.append(row3(Float32(3.0), Float32(1.0), Float32(0.0)))
    wref.append(row3(Float32(3.0), Float32(2.9), Float32(0.0)))
    wtst.append(row3(Float32(2.892), Float32(3.0), Float32(0.0)))
    s = grade_kv_pair(wref, wtst, True)
    expect_eq(s.verdict, VERDICT_NEAR_TIE, "witness verdict")
    expect_eq(s.exact_count, 23, "witness exact count")
    expect_eq(s.near_tie_count, 1, "witness near count")
    expect_eq(s.worst_gap_milli, 108, "witness worst gap")
    print("PASS: pair honesty -- empty NOT_GRADED; invalid comparator overrides perfect rows; J-022 pattern (23 exact + 1 near) grades NEAR_TIE")


def test_refusals() raises:
    var refused = 0
    try:
        _ = grade_kv_step(
            row3(Float32(1.0), Float32(2.0), Float32(0.0)),
            row4(Float32(1.0), Float32(2.0), Float32(0.0), Float32(0.0)),
        )
    except:
        refused += 1
    try:
        var e = List[Float32]()
        _ = grade_kv_step(e, e)
    except:
        refused += 1
    try:
        var a = List[List[Float32]]()
        var b = List[List[Float32]]()
        a.append(row3(Float32(1.0), Float32(2.0), Float32(0.0)))
        _ = grade_kv_pair(a, b, True)
    except:
        refused += 1
    try:
        var nan = Float32(0.0) / Float32(0.0)
        _ = grade_kv_step(
            row3(Float32(1.0), Float32(2.0), Float32(0.0)),
            row3(Float32(1.0), nan, Float32(0.0)),
        )
    except:
        refused += 1
    try:
        var inf = Float32(1.0) / Float32(0.0)
        _ = grade_kv_step(
            row3(inf, Float32(2.0), Float32(0.0)),
            row3(Float32(1.0), Float32(2.0), Float32(0.0)),
        )
    except:
        refused += 1
    # Positive rank with a sub-milli gap (0.0004): refused
    # at the filing resolution, never reclassified.
    try:
        _ = grade_kv_step(
            row3(Float32(3.0), Float32(0.0), Float32(0.0)),
            row3(Float32(1.0), Float32(1.0004), Float32(0.0)),
        )
    except:
        refused += 1
    expect_eq(refused, 6, "refusal count")
    print("PASS: refusals -- width mismatch, empty rows, step-count mismatch, NaN, inf, sub-milli positive-rank gap")


def main() raises:
    test_exact_and_near_steps()
    test_near_tie_band_edges()
    test_ties()
    test_pair_verdicts()
    test_pair_verdicts_honesty()
    test_refusals()
    print("ALL PASS: kv faith (6 groups)")
