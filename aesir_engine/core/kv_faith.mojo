"""KV faithfulness grading harness: paired logit rows in,
(rank, gap) records and a verdict out (Janas road J-089).

The roadmap text (J-089): "8-bit vs 16-bit KV graded by
teacher-forcing rank/gap across context lengths; the
lengths where 8-bit starts to cost truth are found and
published, not hidden."

WHAT THIS MODULE IS. The reduction the live grading legs
were missing. J-060's core/prefill_grade.mojo is the
road's verdict account: it grades per-step (rank, gap)
RECORDS under the pre-registered near-tie rule. But
nothing in the tree turned a pair of logit rows -- the
reference path's row and the test path's row for the same
forced step -- into those records; every live leg would
have had to improvise that arithmetic at run time. This
module is that arithmetic, pure and tested:

  grade_kv_step(ref_row, test_row) -> (ref_top, test_top,
  rank, gap_milli) for one teacher-forced step, and
  grade_kv_pair(ref_rows, test_rows, comparator_valid)
  -> the J-060 GradeSummary for the whole pair, obtained
  by feeding this module's records through
  grade_prefill_cell. There is NO second verdict rule in
  the tree: the near-tie band (rank <= 2 AND gap < 1000
  milli-logits, both conjuncts, sub-logit strict) is
  J-060's, imported, never restated as code here.

DEFINITIONS (stated before any use; the live recipe in
the J-089 doc section 7 cites them verbatim):

- The FORCED TOKEN of a step is the reference row's top
  token: ref_top = argmax(ref_row), ties resolved to the
  LOWEST index (the first maximum). Teacher forcing grades
  the reference's choice under the test path -- the test
  path's own top token is reported (test_top, top_agrees)
  as a diagnostic beside the grade, never instead of it.
- RANK is the forced token's 0-based rank under the test
  row: rank = #{j : test_row[j] > test_row[ref_top]}.
  Rank 0 means the forced token is a test-row maximum
  (ties for the maximum share rank 0 -- only strictly
  greater logits count). This is exactly the rank
  convention of the tf_oracle grades J-060's account
  consumes (rank 0 at 23/24 in the J-022 witness).
- GAP is the test row's own shortfall for the forced
  token: gap = test_row[test_top] - test_row[ref_top],
  in milli-logits, rounded to nearest (half up). The gap
  is measured inside the TEST row, as the oracle measures
  it inside the comparator's row: it prices how far the
  test path itself demoted the reference's token, in the
  test path's own logit units.
- CONSISTENCY, enforced not assumed: rank 0 holds iff the
  gap is exactly 0 (both by construction here). A positive
  rank whose true gap rounds to 0 milli-logits (a
  sub-milli demotion) is REFUSED with the reason, exactly
  as J-060 refuses such a filed record: at the road's
  milli-logit filing resolution that step is ungradeable,
  and the harness refuses rather than silently calling it
  exact or near-tie. Non-finite logits (NaN, +/-inf) and
  empty or mismatched rows are likewise refused.

WHAT THIS MODULE IS NOT. It produces no logits, runs no
model, opens no device, and grades nothing by itself: a
caller supplies paired rows from two real runs (the live
recipe: section 7 of the J-089 doc -- J-088 section 7's
session integration first, then the f16-KV reference run
and the int8-KV test run of the SAME pinned model on the
SAME raw prompt, the reference checked against the ggml
CPU comparator, never llama-cli --single-turn) and states
comparator_valid explicitly, exactly as J-060 requires.
Synthetic consumers (the J-089 ladder's logit-PROXY rows)
must name themselves synthetic wherever their grades are
filed; this module cannot tell a proxy row from a model
row, and its host contract says so.

HOST CONTRACT: (1) rows are one forced step per row pair,
in step order, same vocabulary width on both sides;
(2) comparator_valid is the caller's explicit statement
that the comparator check passed (CPU comparator only,
raw prompt, no template/BOS/backend artifact) -- with it
False the pair grades COMPARATOR_ARTIFACT whatever the
rows say; (3) file grade_kv_pair's GradeSummary verbatim
beside the raw rows' provenance (model pin, prompt,
context length, KV precision of each side).
"""

from core.prefill_grade import (
    GradeSummary,
    grade_prefill_cell,
)


struct KvStepGrade(Copyable, ImplicitlyCopyable):
    """One forced step's reduction: the forced (reference
    top) token, the test row's own top token, the forced
    token's 0-based rank under the test row, and its gap
    in milli-logits. top_agrees is the diagnostic
    (ref_top == test_top); the verdict never rests on it
    alone -- a tied maximum can disagree in index while
    ranking 0 with gap 0 (exact), and agreement in index
    with a demoted logit is impossible by construction."""

    var ref_top: Int
    var test_top: Int
    var rank: Int
    var gap_milli: Int
    var top_agrees: Bool

    def __init__(
        out self,
        ref_top: Int,
        test_top: Int,
        rank: Int,
        gap_milli: Int,
        top_agrees: Bool,
    ):
        self.ref_top = ref_top
        self.test_top = test_top
        self.rank = rank
        self.gap_milli = gap_milli
        self.top_agrees = top_agrees


def _check_logit(v: Float32) raises:
    if v != v:
        raise Error("KVFaith: NaN logit in a grading row")
    if v > Float32(3.4028235e38) or v < Float32(-3.4028235e38):
        raise Error("KVFaith: infinite logit in a grading row")


def _argmax_first(row: List[Float32]) -> Int:
    """First (lowest-index) maximum -- the tie rule."""
    var best = 0
    for j in range(1, len(row)):
        if row[j] > row[best]:
            best = j
    return best


def grade_kv_step(
    ref_row: List[Float32], test_row: List[Float32]
) raises -> KvStepGrade:
    """Reduce one paired logit row to its (rank, gap)
    record under the definitions in this module's header."""
    if len(ref_row) == 0 or len(test_row) == 0:
        raise Error("KVFaith: logit rows must be non-empty")
    if len(ref_row) != len(test_row):
        raise Error("KVFaith: paired logit rows differ in width")
    for j in range(len(ref_row)):
        _check_logit(ref_row[j])
        _check_logit(test_row[j])
    var ref_top = _argmax_first(ref_row)
    var test_top = _argmax_first(test_row)
    var target = test_row[ref_top]
    var rank = 0
    for j in range(len(test_row)):
        if test_row[j] > target:
            rank += 1
    var gap = test_row[test_top] - target
    var gap_milli = Int(Float64(gap) * 1000.0 + 0.5)
    if rank > 0 and gap_milli == 0:
        raise Error(
            "KVFaith: positive rank with a sub-milli-logit gap is"
            " ungradeable at the road's milli-logit filing"
            " resolution; refusing rather than reclassifying it"
        )
    if rank == 0 and gap_milli != 0:
        raise Error("KVFaith: internal inconsistency (rank 0, nonzero gap)")
    return KvStepGrade(
        ref_top, test_top, rank, gap_milli, ref_top == test_top
    )


def grade_kv_pair(
    ref_rows: List[List[Float32]],
    test_rows: List[List[Float32]],
    comparator_valid: Bool,
) raises -> GradeSummary:
    """Grade a whole paired run: reduce every step with
    grade_kv_step, then hand the (rank, gap) records to
    J-060's grade_prefill_cell -- the one verdict rule.
    An empty pair grades NOT_GRADED through that account,
    never a graded class. comparator_valid is the caller's
    explicit comparator statement (see the host contract).
    """
    if len(ref_rows) != len(test_rows):
        raise Error("KVFaith: paired runs differ in step count")
    var ranks = List[Int]()
    var gaps = List[Int]()
    for i in range(len(ref_rows)):
        var step = grade_kv_step(ref_rows[i], test_rows[i])
        ranks.append(step.rank)
        gaps.append(step.gap_milli)
    return grade_prefill_cell(ranks, gaps, comparator_valid)
