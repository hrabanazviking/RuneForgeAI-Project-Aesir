# tests/test_near_tie_gate_a111.mojo
# A-111: Near-tie band, encoded -- the gate rule is the
# roadmap's (rank <= 2 with sub-logit gap = faithful), and
# these cases cover the band edges: each conjunct binding
# alone, the exclusive sub-logit bound at exactly one
# logit, inconsistent records refused, comparator-artifact
# precedence, sequence verdicts, and exact agreement with
# the banked prefill_grade step classification so the two
# encodings cannot drift.

from core.near_tie_gate import (
    BAND_COMPARATOR_ARTIFACT,
    BAND_DIVERGENT,
    BAND_FAITHFUL,
    BAND_FAITHFUL_NEAR_TIE,
    BAND_MAX_GAP_MILLI,
    BAND_MAX_RANK,
    BAND_NOT_GRADED,
    BAND_STEP_DIVERGENT,
    BAND_STEP_EXACT,
    BAND_STEP_NEAR_TIE,
    band_line,
    gate_row,
    gate_steps,
    gate_verdict_name,
    row_is_faithful,
    step_class,
    step_class_name,
    step_is_faithful,
    summary_is_faithful,
)
from core.prefill_grade import (
    NEAR_TIE_MAX_GAP_MILLI,
    NEAR_TIE_MAX_RANK,
    step_class as prefill_step_class,
)


def _raises_step(rank: Int, gap_milli: Int) -> Bool:
    try:
        _ = step_class(rank, gap_milli)
    except:
        return True
    return False


def test_near_tie_band_constants() raises:
    if BAND_MAX_RANK != 2:
        raise Error("band max rank drifted from the roadmap rule")
    if BAND_MAX_GAP_MILLI != 1000:
        raise Error("band sub-logit bound drifted from 1000 milli")
    if BAND_MAX_RANK != NEAR_TIE_MAX_RANK:
        raise Error("gate band disagrees with prefill_grade max rank")
    if BAND_MAX_GAP_MILLI != NEAR_TIE_MAX_GAP_MILLI:
        raise Error("gate band disagrees with prefill_grade max gap")


def test_near_tie_exact_step() raises:
    if step_class(0, 0) != BAND_STEP_EXACT:
        raise Error("rank 0 gap 0 is not exact")
    if not step_is_faithful(0, 0):
        raise Error("exact step is not faithful")
    if gate_row(0, 0, True) != BAND_FAITHFUL:
        raise Error("exact row did not file FAITHFUL")
    if not row_is_faithful(0, 0, True):
        raise Error("exact row is not faithful")


def test_near_tie_band_interior() raises:
    var inside = List[List[Int]]()
    inside.append(List[Int]([1, 1]))
    inside.append(List[Int]([1, 500]))
    inside.append(List[Int]([1, 999]))
    inside.append(List[Int]([2, 1]))
    inside.append(List[Int]([2, 500]))
    inside.append(List[Int]([2, 999]))
    for pair in inside:
        if step_class(pair[0], pair[1]) != BAND_STEP_NEAR_TIE:
            raise Error(
                "band interior record not near-tie: rank "
                + String(pair[0])
                + " gap "
                + String(pair[1])
            )
        if not step_is_faithful(pair[0], pair[1]):
            raise Error("band interior record not faithful")
        if gate_row(pair[0], pair[1], True) != BAND_FAITHFUL_NEAR_TIE:
            raise Error("band interior row did not file FAITHFUL_NEAR_TIE")


def test_near_tie_rank_edge() raises:
    # The rank conjunct binds alone: a tiny gap cannot buy
    # a rank past the band.
    if step_class(2, 999) != BAND_STEP_NEAR_TIE:
        raise Error("rank 2 at the gap edge left the band")
    var outside = List[List[Int]]()
    outside.append(List[Int]([3, 10]))
    outside.append(List[Int]([3, 999]))
    outside.append(List[Int]([3, 1]))
    outside.append(List[Int]([57, 1]))
    for pair in outside:
        if step_class(pair[0], pair[1]) != BAND_STEP_DIVERGENT:
            raise Error(
                "rank past the band not divergent: rank "
                + String(pair[0])
                + " gap "
                + String(pair[1])
            )
        if step_is_faithful(pair[0], pair[1]):
            raise Error("rank past the band filed faithful")
        if gate_row(pair[0], pair[1], True) != BAND_DIVERGENT:
            raise Error("rank past the band row did not file DIVERGENT")


def test_near_tie_gap_edge() raises:
    # The gap conjunct binds alone: exactly one logit
    # (1000 milli) is NOT sub-logit, and the filed J-022
    # witness (rank 2, 1.138 gap) stays divergent.
    if step_class(1, 999) != BAND_STEP_NEAR_TIE:
        raise Error("gap 999 milli left the band")
    var outside = List[List[Int]]()
    outside.append(List[Int]([1, 1000]))
    outside.append(List[Int]([2, 1000]))
    outside.append(List[Int]([2, 1001]))
    outside.append(List[Int]([1, 2479]))
    outside.append(List[Int]([2, 1138]))
    for pair in outside:
        if step_class(pair[0], pair[1]) != BAND_STEP_DIVERGENT:
            raise Error(
                "gap at/past one logit not divergent: rank "
                + String(pair[0])
                + " gap "
                + String(pair[1])
            )
        if row_is_faithful(pair[0], pair[1], True):
            raise Error("gap at/past one logit filed faithful")


def test_near_tie_invalid_records_refused() raises:
    if not _raises_step(0, 5):
        raise Error("rank 0 with a nonzero gap was graded")
    if not _raises_step(1, 0):
        raise Error("positive rank with a zero gap was graded")
    if not _raises_step(-1, 5):
        raise Error("negative rank was graded")
    if not _raises_step(1, -5):
        raise Error("negative gap was graded")
    var len_blocked = False
    try:
        _ = gate_steps(List[Int]([0, 1]), List[Int]([0]), True)
    except:
        len_blocked = True
    if not len_blocked:
        raise Error("mismatched record lengths were graded")


def test_near_tie_comparator_precedence() raises:
    # An invalid comparator files COMPARATOR_ARTIFACT over
    # every record pattern and is never faithful.
    var rows = List[List[Int]]()
    rows.append(List[Int]([0, 0]))
    rows.append(List[Int]([2, 999]))
    rows.append(List[Int]([9, 5000]))
    for pair in rows:
        if gate_row(pair[0], pair[1], False) != BAND_COMPARATOR_ARTIFACT:
            raise Error("invalid comparator did not file artifact")
        if row_is_faithful(pair[0], pair[1], False):
            raise Error("comparator artifact filed faithful")
    var summary = gate_steps(List[Int]([0, 3]), List[Int]([0, 10]), False)
    if summary.verdict != BAND_COMPARATOR_ARTIFACT:
        raise Error("invalid comparator sequence did not file artifact")
    if summary.divergent_count != 1 or summary.exact_count != 1:
        raise Error("artifact summary lost the record counts")
    if summary_is_faithful(summary):
        raise Error("comparator artifact sequence filed faithful")


def test_near_tie_row_verdicts() raises:
    if gate_row(0, 0, True) != BAND_FAITHFUL:
        raise Error("exact row verdict wrong")
    if gate_row(2, 999, True) != BAND_FAITHFUL_NEAR_TIE:
        raise Error("near-tie row verdict wrong")
    if gate_row(3, 10, True) != BAND_DIVERGENT:
        raise Error("divergent row verdict wrong")
    if gate_verdict_name(BAND_FAITHFUL) != String("FAITHFUL"):
        raise Error("faithful verdict name drifted")
    if gate_verdict_name(BAND_FAITHFUL_NEAR_TIE) != String("FAITHFUL_NEAR_TIE"):
        raise Error("near-tie verdict name drifted")
    if gate_verdict_name(BAND_DIVERGENT) != String("DIVERGENT"):
        raise Error("divergent verdict name drifted")
    if gate_verdict_name(BAND_COMPARATOR_ARTIFACT) != String("COMPARATOR_ARTIFACT"):
        raise Error("artifact verdict name drifted")
    if gate_verdict_name(BAND_NOT_GRADED) != String("NOT_GRADED"):
        raise Error("not-graded verdict name drifted")
    if step_class_name(BAND_STEP_EXACT) != String("EXACT"):
        raise Error("exact class name drifted")
    if step_class_name(BAND_STEP_NEAR_TIE) != String("NEAR_TIE"):
        raise Error("near-tie class name drifted")
    if step_class_name(BAND_STEP_DIVERGENT) != String("DIVERGENT"):
        raise Error("divergent class name drifted")


def test_near_tie_sequence_verdicts() raises:
    var empty = gate_steps(List[Int](), List[Int](), True)
    if empty.verdict != BAND_NOT_GRADED or empty.steps != 0:
        raise Error("empty sequence did not file NOT_GRADED")
    if summary_is_faithful(empty):
        raise Error("empty sequence filed faithful")
    var exact = gate_steps(List[Int]([0, 0, 0]), List[Int]([0, 0, 0]), True)
    if exact.verdict != BAND_FAITHFUL or exact.exact_count != 3:
        raise Error("all-exact sequence did not file FAITHFUL")
    if not summary_is_faithful(exact):
        raise Error("all-exact sequence not faithful")
    if exact.first_divergent_step != -1:
        raise Error("all-exact sequence named a divergent step")
    var mixed = gate_steps(List[Int]([0, 2, 1]), List[Int]([0, 999, 12]), True)
    if mixed.verdict != BAND_FAITHFUL_NEAR_TIE:
        raise Error("exact+near-tie sequence did not file FAITHFUL_NEAR_TIE")
    if mixed.exact_count != 1 or mixed.near_tie_count != 2:
        raise Error("mixed sequence counts wrong")
    if not summary_is_faithful(mixed):
        raise Error("near-tie sequence not faithful (the roadmap rule)")
    var diverged = gate_steps(
        List[Int]([0, 3, 0]), List[Int]([0, 10, 0]), True
    )
    if diverged.verdict != BAND_DIVERGENT:
        raise Error("divergent sequence did not file DIVERGENT")
    if diverged.first_divergent_step != 1:
        raise Error("first divergent step wrong")
    if diverged.worst_rank != 3 or diverged.worst_gap_milli != 10:
        raise Error("divergent sequence worst values wrong")
    if summary_is_faithful(diverged):
        raise Error("divergent sequence filed faithful")


def test_near_tie_matches_prefill_grade() raises:
    # The encoded band must agree with the banked prefill
    # account on every consistent record, edges included.
    var gaps = List[Int]([1, 10, 500, 999, 1000, 1138, 2500])
    if step_class(0, 0) != prefill_step_class(0, 0):
        raise Error("exact record disagrees with prefill_grade")
    for rank in range(1, 7):
        for gap in gaps:
            if step_class(rank, gap) != prefill_step_class(rank, gap):
                raise Error(
                    "band disagrees with prefill_grade at rank "
                    + String(rank)
                    + " gap "
                    + String(gap)
                )


def test_near_tie_band_line() raises:
    var line = band_line()
    if "rank <= 2" not in line:
        raise Error("band line lost the rank conjunct")
    if "1000" not in line or "sub-logit" not in line:
        raise Error("band line lost the sub-logit conjunct")
    if "faithful" not in line:
        raise Error("band line lost the faithful verdict")
