"""Prefill faithfulness battery (J-060): the
pre-registered verdict rule applied to the filed grades
and to synthetic records that pin each clause -- the
post-fix OLMoE grade (the battery's one filed-evidence
pass cell), the pre-fix OLMoE grade (its historical
divergent witness, incl. the rank-2 / gap-1.138 step that
is NOT a near-tie), an all-exact cell, the step-0 boundary
class in both its forms, comparator-artifact precedence,
the not-graded empty cell, the near-tie conjunct edges,
and refusals.

Filed records restated exactly from the tree:
docs/janas/j022_b1_tf_grade_fix.txt (post-fix: 24 steps,
rank 0 at 23, step 23 rank 1 gap 0.108) and
docs/janas/j022_tf_grade.txt (pre-fix: rank 0 at 8/24,
first divergence step 5). Gaps enter as milli-logits
(printed gap x 1000). No run, no wall -- the account
grades records only.
"""
from core.prefill_grade import (
    NEAR_TIE_MAX_GAP_MILLI,
    NEAR_TIE_MAX_RANK,
    STEP_DIVERGENT,
    STEP_EXACT,
    STEP_NEAR_TIE,
    VERDICT_COMPARATOR_ARTIFACT,
    VERDICT_DIVERGENT,
    VERDICT_FAITHFUL,
    VERDICT_NEAR_TIE,
    VERDICT_NOT_GRADED,
    VERDICT_STEP0_BOUNDARY,
    grade_prefill_cell,
    step_class,
    verdict_name,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "PrefillGrade " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_str(actual: String, expected: String, what: String) raises:
    if actual != expected:
        raise Error(
            "PrefillGrade " + what + ": expected '" + expected
            + "', got '" + actual + "'"
        )


def test_postfix_olmoe_filed() raises:
    # The battery's filed-evidence pass cell: J-022
    # section 7.3's post-fix grade, re-verified through
    # the account. 23 exact steps + step 23 (rank 1,
    # gap 108 milli) -> NEAR_TIE, the pass verdict that
    # keeps the near-tie step visible.
    var ranks = List[Int]()
    var gaps = List[Int]()
    for _ in range(23):
        ranks.append(0)
        gaps.append(0)
    ranks.append(1)
    gaps.append(108)
    var s = grade_prefill_cell(ranks, gaps, True)
    expect_eq(s.verdict, VERDICT_NEAR_TIE, "post-fix verdict")
    expect_str(verdict_name(s.verdict), String("NEAR_TIE"), "post-fix name")
    expect_eq(s.steps, 24, "post-fix steps")
    expect_eq(s.exact_count, 23, "post-fix exact")
    expect_eq(s.near_tie_count, 1, "post-fix near-tie")
    expect_eq(s.divergent_count, 0, "post-fix divergent")
    expect_eq(s.first_divergent_step, -1, "post-fix first divergent")
    expect_eq(s.worst_rank, 1, "post-fix worst rank")
    expect_eq(s.worst_gap_milli, 108, "post-fix worst gap")
    print("PASS: filed post-fix OLMoE grade -- NEAR_TIE (23 exact, step 23 near-tie)")


def test_prefix_olmoe_filed() raises:
    # The historical divergent witness: J-022 section 3's
    # pre-fix grade (the B1 defect's evidence). Rank 0 at
    # 8/24; step 10 (rank 1, gap 0.064) is the only
    # near-tie; step 17 (rank 2, gap 1.138) is divergent
    # -- the rank conjunct alone does not make a near-tie.
    var ranks = List[Int]()
    var gaps = List[Int]()
    var filed_ranks = List[Int]()
    filed_ranks.append(0)
    filed_ranks.append(0)
    filed_ranks.append(0)
    filed_ranks.append(0)
    filed_ranks.append(0)
    filed_ranks.append(5)
    filed_ranks.append(57)
    filed_ranks.append(0)
    filed_ranks.append(176)
    filed_ranks.append(367)
    filed_ranks.append(1)
    filed_ranks.append(20)
    filed_ranks.append(7)
    filed_ranks.append(20)
    filed_ranks.append(4300)
    filed_ranks.append(171)
    filed_ranks.append(197)
    filed_ranks.append(2)
    filed_ranks.append(4)
    filed_ranks.append(0)
    filed_ranks.append(81)
    filed_ranks.append(25)
    filed_ranks.append(0)
    filed_ranks.append(512)
    var filed_gaps = List[Int]()
    filed_gaps.append(0)
    filed_gaps.append(0)
    filed_gaps.append(0)
    filed_gaps.append(0)
    filed_gaps.append(0)
    filed_gaps.append(2479)
    filed_gaps.append(5430)
    filed_gaps.append(0)
    filed_gaps.append(7531)
    filed_gaps.append(7573)
    filed_gaps.append(64)
    filed_gaps.append(8169)
    filed_gaps.append(3482)
    filed_gaps.append(6200)
    filed_gaps.append(12516)
    filed_gaps.append(9637)
    filed_gaps.append(6715)
    filed_gaps.append(1138)
    filed_gaps.append(1087)
    filed_gaps.append(0)
    filed_gaps.append(5192)
    filed_gaps.append(4706)
    filed_gaps.append(0)
    filed_gaps.append(8532)
    for i in range(24):
        ranks.append(filed_ranks[i])
        gaps.append(filed_gaps[i])
    var s = grade_prefill_cell(ranks, gaps, True)
    expect_eq(s.verdict, VERDICT_DIVERGENT, "pre-fix verdict")
    expect_eq(s.exact_count, 8, "pre-fix exact (rank 0 at 8/24)")
    expect_eq(s.near_tie_count, 1, "pre-fix near-tie (step 10 only)")
    expect_eq(s.divergent_count, 15, "pre-fix divergent")
    expect_eq(s.first_divergent_step, 5, "pre-fix first divergence at step 5")
    expect_eq(s.worst_rank, 4300, "pre-fix worst rank (step 14)")
    expect_eq(s.worst_gap_milli, 12516, "pre-fix worst gap (step 14)")
    expect_eq(step_class(2, 1138), STEP_DIVERGENT, "step 17 is not a near-tie")
    print("PASS: filed pre-fix OLMoE grade -- DIVERGENT (8 exact, 1 near-tie, first at 5)")


def test_all_exact_faithful() raises:
    var ranks = List[Int]()
    var gaps = List[Int]()
    for _ in range(24):
        ranks.append(0)
        gaps.append(0)
    var s = grade_prefill_cell(ranks, gaps, True)
    expect_eq(s.verdict, VERDICT_FAITHFUL, "all-exact verdict")
    expect_str(verdict_name(s.verdict), String("FAITHFUL"), "faithful name")
    expect_eq(s.exact_count, 24, "all-exact count")
    expect_eq(s.first_divergent_step, -1, "all-exact first divergent")
    print("PASS: all-exact cell -- FAITHFUL, distinct from NEAR_TIE")


def test_step0_boundary() raises:
    # Divergence confined to step 0 is its own class --
    # neither a pass nor an engine divergence.
    var ranks = List[Int]()
    var gaps = List[Int]()
    ranks.append(40)
    gaps.append(3000)
    for _ in range(23):
        ranks.append(0)
        gaps.append(0)
    var s = grade_prefill_cell(ranks, gaps, True)
    expect_eq(s.verdict, VERDICT_STEP0_BOUNDARY, "step0-only verdict")
    expect_str(
        verdict_name(s.verdict), String("STEP0_BOUNDARY"), "step0-only name"
    )
    expect_eq(s.divergent_count, 1, "step0-only divergent count")
    expect_eq(s.first_divergent_step, 0, "step0-only first divergent")
    # A near-tie later step does not change the class.
    var ranks2 = List[Int]()
    var gaps2 = List[Int]()
    ranks2.append(9)
    gaps2.append(2500)
    ranks2.append(1)
    gaps2.append(108)
    ranks2.append(0)
    gaps2.append(0)
    var s2 = grade_prefill_cell(ranks2, gaps2, True)
    expect_eq(s2.verdict, VERDICT_STEP0_BOUNDARY, "step0 + later near-tie")
    expect_eq(s2.near_tie_count, 1, "step0 case near-tie count")
    print("PASS: step-0 boundary -- own verdict class, near-tie later steps keep it")


def test_step0_plus_later_divergent() raises:
    # A divergent step 0 WITH any later divergence is a
    # plain divergence -- the boundary class shelters
    # nothing past the boundary.
    var ranks = List[Int]()
    var gaps = List[Int]()
    ranks.append(40)
    gaps.append(3000)
    ranks.append(0)
    gaps.append(0)
    ranks.append(7)
    gaps.append(2000)
    var s = grade_prefill_cell(ranks, gaps, True)
    expect_eq(s.verdict, VERDICT_DIVERGENT, "step0 + later divergent verdict")
    expect_eq(s.first_divergent_step, 0, "first divergent still step 0")
    expect_eq(s.divergent_count, 2, "divergent count")
    print("PASS: step-0 plus later divergence -- DIVERGENT, boundary class does not shelter")


def test_step0_near_tie_only() raises:
    # A near-tie AT step 0 is not a boundary case: the
    # boundary class requires a divergent step 0.
    var ranks = List[Int]()
    var gaps = List[Int]()
    ranks.append(1)
    gaps.append(108)
    ranks.append(0)
    gaps.append(0)
    var s = grade_prefill_cell(ranks, gaps, True)
    expect_eq(s.verdict, VERDICT_NEAR_TIE, "step0 near-tie verdict")
    print("PASS: step-0 near-tie only -- NEAR_TIE, not the boundary class")


def test_comparator_artifact_precedence() raises:
    # The comparator verdict takes precedence over every
    # step pattern: perfect steps cannot launder a broken
    # comparison, and divergent steps cannot convict the
    # engine through one. Counts still witness the record.
    var ranks = List[Int]()
    var gaps = List[Int]()
    for _ in range(4):
        ranks.append(0)
        gaps.append(0)
    var perfect = grade_prefill_cell(ranks, gaps, False)
    expect_eq(perfect.verdict, VERDICT_COMPARATOR_ARTIFACT, "artifact over perfect")
    expect_str(
        verdict_name(perfect.verdict),
        String("COMPARATOR_ARTIFACT"),
        "artifact name",
    )
    expect_eq(perfect.exact_count, 4, "artifact counts still filed")
    var ranks2 = List[Int]()
    var gaps2 = List[Int]()
    ranks2.append(500)
    gaps2.append(9000)
    var diverged = grade_prefill_cell(ranks2, gaps2, False)
    expect_eq(diverged.verdict, VERDICT_COMPARATOR_ARTIFACT, "artifact over divergent")
    expect_eq(diverged.divergent_count, 1, "artifact divergent count witnessed")
    print("PASS: comparator artifact -- precedence over perfect and divergent records")


def test_not_graded() raises:
    var ranks = List[Int]()
    var gaps = List[Int]()
    var s = grade_prefill_cell(ranks, gaps, True)
    expect_eq(s.verdict, VERDICT_NOT_GRADED, "empty verdict")
    expect_str(verdict_name(s.verdict), String("NOT_GRADED"), "empty name")
    expect_eq(s.steps, 0, "empty steps")
    expect_eq(s.worst_rank, 0, "empty worst rank")
    expect_eq(s.worst_gap_milli, 0, "empty worst gap")
    expect_eq(s.first_divergent_step, -1, "empty first divergent")
    print("PASS: no records -- NOT_GRADED (the unbuilt/unrun cell's only home)")


def test_near_tie_edges() raises:
    expect_eq(NEAR_TIE_MAX_RANK, 2, "band rank constant")
    expect_eq(NEAR_TIE_MAX_GAP_MILLI, 1000, "band gap constant")
    expect_eq(step_class(0, 0), STEP_EXACT, "rank 0 exact")
    expect_eq(step_class(1, 108), STEP_NEAR_TIE, "rank 1 gap 0.108 near-tie")
    expect_eq(step_class(2, 999), STEP_NEAR_TIE, "rank 2 gap 0.999 near-tie")
    expect_eq(step_class(2, 1000), STEP_DIVERGENT, "gap 1.000 is not sub-logit")
    expect_eq(step_class(3, 10), STEP_DIVERGENT, "rank 3 tiny gap not near-tie")
    expect_eq(step_class(2, 1138), STEP_DIVERGENT, "rank 2 gap 1.138 not near-tie")
    print("PASS: near-tie edges -- both conjuncts bind, sub-logit is strict")


def test_refusals() raises:
    var refused = 0
    var one = List[Int]()
    one.append(0)
    var two = List[Int]()
    two.append(0)
    two.append(0)
    try:
        _ = grade_prefill_cell(one, two, True)
    except:
        refused += 1
    var neg_rank = List[Int]()
    neg_rank.append(-1)
    var zero_gap = List[Int]()
    zero_gap.append(0)
    try:
        _ = grade_prefill_cell(neg_rank, zero_gap, True)
    except:
        refused += 1
    var zero_rank = List[Int]()
    zero_rank.append(0)
    var some_gap = List[Int]()
    some_gap.append(5)
    try:
        _ = grade_prefill_cell(zero_rank, some_gap, True)
    except:
        refused += 1
    var pos_rank = List[Int]()
    pos_rank.append(3)
    try:
        _ = grade_prefill_cell(pos_rank, zero_gap, True)
    except:
        refused += 1
    try:
        _ = step_class(1, -1)
    except:
        refused += 1
    expect_eq(refused, 5, "refusal count")
    print("PASS: refusals -- length mismatch, negatives, inconsistent rank/gap pairs")


def main() raises:
    test_postfix_olmoe_filed()
    test_prefix_olmoe_filed()
    test_all_exact_faithful()
    test_step0_boundary()
    test_step0_plus_later_divergent()
    test_step0_near_tie_only()
    test_comparator_artifact_precedence()
    test_not_graded()
    test_near_tie_edges()
    test_refusals()
    print("ALL PASS: prefill grade account (10 groups)")
