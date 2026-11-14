"""A-111: Near-tie band, encoded -- the canonical gate rule
for oracle faithfulness grading (Wave 13, Oracle
infrastructure).

The roadmap text: "Rank <=2 with sub-logit gap = faithful,
as a gate rule (not a human judgement call per row)."
Before this slice the band lived as prose and as separate
re-statements inside individual graders (core/prefill_grade
.mojo's per-step rule, core/gpu_fuzz.mojo's classifier,
core/parity_battery.mojo's header, core/kv_faith.mojo's
milli-logit rule) -- every new grader re-typed the numbers
and a drift in any one of them would have been invisible.
This module is the ONE encoding: the constants, the record
validation, the per-record classification, and the row /
sequence verdicts every oracle grader files by. A row is
faithful exactly when this gate says so; no caller re-types
the band and no human re-judges a row the gate has graded.

THE RULE, PRE-REGISTERED (stated here before any test in
tests/test_near_tie_gate_a111.mojo was run):

  Records carry the gap as an integer count of
  milli-logits (gap x 1000, rounded by the filer from the
  printed value) -- the tree's exact-integer convention
  (prefill_grade, kv_faith), so the band test is exact:
  sub-logit means gap_milli < 1000, with no float edge.

  Per record (rank r, gap g in milli-logits):
    (S1) EXACT iff r == 0 (then g == 0 by definition of
         the gap; an inconsistent record is refused, not
         graded).
    (S2) NEAR_TIE iff r <= BAND_MAX_RANK (2) AND
         g < BAND_MAX_GAP_MILLI (1000) -- BOTH conjuncts
         bind: rank 2 with a 1.138 gap is NOT a near-tie
         (the J-022 pre-fix step 17 is the filed witness),
         and rank 3 with a 0.010 gap is NOT a near-tie
         either.
    (S3) DIVERGENT otherwise.
  A record is FAITHFUL iff its class is EXACT or NEAR_TIE:
  the near-tie band counts as faithful (the roadmap's
  rule), and it is kept distinct from EXACT so a near-tie
  row is never filed as a perfect row.

  Per row / sequence (the ordered records + a
  comparator-valid flag the caller must state explicitly):
    (G1) NOT_GRADED iff there are no records.
    (G2) COMPARATOR_ARTIFACT iff the comparator check
         failed (comparator_valid == False). This verdict
         takes precedence over every record pattern,
         perfect or divergent -- check the comparator
         before suspecting the engine (the standing
         comparator-artifact verdict class; the artifact
         KINDS and their automated checklist are A-112's
         slice, not this gate's).
    (G3) DIVERGENT iff any record is divergent.
    (G4) FAITHFUL_NEAR_TIE iff no record diverges and at
         least one is near-tie. A PASS verdict.
    (G5) FAITHFUL iff every record is exact.
  No other verdict is reachable: the gate has no averaged
  gap and no agreement percentage -- a mean would let
  exact steps buy out a divergent one, which is precisely
  what rank/gap grading exists to refuse.

RELATIONSHIP TO THE BANKED GRADERS: core/prefill_grade
.mojo grades prefill CELLS with this same band per step
(its S2) and refines a sequence whose ONLY divergent
steps sit at step 0 into its own STEP0_BOUNDARY cell
class. That refinement is a cell disposition, not a band
change: such a sequence is not faithful under either
account, and this gate's per-record classes agree with
prefill_grade's step_class on every consistent record --
the A-111 suite cases prove the agreement over a grid so
the two encodings cannot drift apart silently. The
float-gap graders (gpu_fuzz, parity_battery) convert by
the filed convention (gap x 1000, rounded by the filer)
before consulting this gate.

RAW-ORACLE DISCIPLINE (standing): the records this gate
grades come from teacher-forcing rank + logit gap on RAW
prompts, CPU engine vs CPU comparator only, with the
oracle backend recorded per row (A-110's registry). The
gate itself executes nothing, opens no device, and claims
no speed: pure arithmetic on stated records, in the
J-031/J-053 account style. IQ-family rows are graded on
coherence, never token-exactness (A-115's policy); this
gate is the band such rows are filed under when rank/gap
evidence exists, and it mints no token-exactness demand.
"""

# The near-tie band, pre-registered (the roadmap's rule).
# Sub-logit is an EXCLUSIVE bound: gap_milli == 1000 is a
# full logit and is NOT inside the band.
comptime BAND_MAX_RANK = 2
comptime BAND_MAX_GAP_MILLI = 1000

# Per-record classes. Codes match core/prefill_grade.mojo's
# STEP_* codes so filings from both accounts read alike.
comptime BAND_STEP_EXACT = 0
comptime BAND_STEP_NEAR_TIE = 1
comptime BAND_STEP_DIVERGENT = 2

# Gate verdicts for a row or a sequence of records.
comptime BAND_FAITHFUL = 0
comptime BAND_FAITHFUL_NEAR_TIE = 1
comptime BAND_DIVERGENT = 2
comptime BAND_COMPARATOR_ARTIFACT = 3
comptime BAND_NOT_GRADED = 4


struct GateSummary(Copyable, ImplicitlyCopyable):
    """One row/sequence graded by the gate: the verdict
    the pre-registered rule states for the supplied
    records, with the counts that witness it.
    first_divergent_step is -1 when no record diverges.
    worst_rank and worst_gap_milli are independent maxima
    over the records (they need not come from the same
    record); both are 0 on an empty (NOT_GRADED) account.
    The counts are computed even when the verdict is
    COMPARATOR_ARTIFACT, so the filing shows what the
    invalid comparison would have hidden."""

    var verdict: Int
    var steps: Int
    var exact_count: Int
    var near_tie_count: Int
    var divergent_count: Int
    var first_divergent_step: Int
    var worst_rank: Int
    var worst_gap_milli: Int

    def __init__(
        out self,
        verdict: Int,
        steps: Int,
        exact_count: Int,
        near_tie_count: Int,
        divergent_count: Int,
        first_divergent_step: Int,
        worst_rank: Int,
        worst_gap_milli: Int,
    ):
        self.verdict = verdict
        self.steps = steps
        self.exact_count = exact_count
        self.near_tie_count = near_tie_count
        self.divergent_count = divergent_count
        self.first_divergent_step = first_divergent_step
        self.worst_rank = worst_rank
        self.worst_gap_milli = worst_gap_milli


def validate_step_record(rank: Int, gap_milli: Int) raises:
    """One record's internal consistency. A rank-0 forced
    id IS the comparator's top-1, so its gap is zero by
    definition; a positive rank means some other id scored
    strictly higher, so the gap is strictly positive. A
    record violating either is not a grade -- it is a
    broken transcription, refused rather than graded."""
    if rank < 0 or gap_milli < 0:
        raise Error("NearTieGate: rank and gap must be non-negative")
    if rank == 0 and gap_milli != 0:
        raise Error("NearTieGate: rank 0 with a nonzero gap is inconsistent")
    if rank > 0 and gap_milli == 0:
        raise Error("NearTieGate: positive rank with a zero gap is inconsistent")


def step_class(rank: Int, gap_milli: Int) raises -> Int:
    """The pre-registered per-record class (S1-S3): exact,
    near-tie (both conjuncts), or divergent."""
    validate_step_record(rank, gap_milli)
    if rank == 0:
        return BAND_STEP_EXACT
    if rank <= BAND_MAX_RANK and gap_milli < BAND_MAX_GAP_MILLI:
        return BAND_STEP_NEAR_TIE
    return BAND_STEP_DIVERGENT


def step_is_faithful(rank: Int, gap_milli: Int) raises -> Bool:
    """The gate's faithful predicate for one record: exact
    or inside the near-tie band."""
    return step_class(rank, gap_milli) != BAND_STEP_DIVERGENT


def gate_row(rank: Int, gap_milli: Int, comparator_valid: Bool) raises -> Int:
    """The gate verdict for a single oracle row. The
    comparator check precedes grading (G2): an invalid
    comparison files COMPARATOR_ARTIFACT whatever the
    record shows."""
    var cls = step_class(rank, gap_milli)
    if not comparator_valid:
        return BAND_COMPARATOR_ARTIFACT
    if cls == BAND_STEP_EXACT:
        return BAND_FAITHFUL
    if cls == BAND_STEP_NEAR_TIE:
        return BAND_FAITHFUL_NEAR_TIE
    return BAND_DIVERGENT


def row_is_faithful(rank: Int, gap_milli: Int, comparator_valid: Bool) raises -> Bool:
    """True iff the gate files the row faithful (exact or
    near-tie) under a valid comparator. A comparator
    artifact is never faithful: the row was not graded."""
    var verdict = gate_row(rank, gap_milli, comparator_valid)
    return verdict == BAND_FAITHFUL or verdict == BAND_FAITHFUL_NEAR_TIE


def gate_steps(
    ranks: List[Int], gaps_milli: List[Int], comparator_valid: Bool
) raises -> GateSummary:
    """Grade one sequence of records (one prompt's steps,
    or one matrix row's positions) by the pre-registered
    rule (G1-G5). The verdict is exactly the rule applied
    to those inputs -- nothing else is consulted."""
    if len(ranks) != len(gaps_milli):
        raise Error("NearTieGate: rank and gap record lengths differ")
    var steps = len(ranks)
    var exact = 0
    var near = 0
    var divergent = 0
    var first_divergent = -1
    var worst_rank = 0
    var worst_gap = 0
    for i in range(steps):
        var cls = step_class(ranks[i], gaps_milli[i])
        if cls == BAND_STEP_EXACT:
            exact += 1
        elif cls == BAND_STEP_NEAR_TIE:
            near += 1
        else:
            divergent += 1
            if first_divergent < 0:
                first_divergent = i
        if ranks[i] > worst_rank:
            worst_rank = ranks[i]
        if gaps_milli[i] > worst_gap:
            worst_gap = gaps_milli[i]
    var verdict: Int
    if steps == 0:
        verdict = BAND_NOT_GRADED
    elif not comparator_valid:
        verdict = BAND_COMPARATOR_ARTIFACT
    elif divergent > 0:
        verdict = BAND_DIVERGENT
    elif near > 0:
        verdict = BAND_FAITHFUL_NEAR_TIE
    else:
        verdict = BAND_FAITHFUL
    return GateSummary(
        verdict,
        steps,
        exact,
        near,
        divergent,
        first_divergent,
        worst_rank,
        worst_gap,
    )


def summary_is_faithful(summary: GateSummary) -> Bool:
    """True iff the gate filed the sequence faithful
    (all-exact or near-tie band) under a valid comparator."""
    return (
        summary.verdict == BAND_FAITHFUL
        or summary.verdict == BAND_FAITHFUL_NEAR_TIE
    )


def step_class_name(cls: Int) -> String:
    """The filed name of a per-record class code."""
    if cls == BAND_STEP_EXACT:
        return String("EXACT")
    if cls == BAND_STEP_NEAR_TIE:
        return String("NEAR_TIE")
    if cls == BAND_STEP_DIVERGENT:
        return String("DIVERGENT")
    return String("UNKNOWN")


def gate_verdict_name(verdict: Int) -> String:
    """The filed name of a gate verdict code -- the only
    strings a matrix filing may use for a row's verdict."""
    if verdict == BAND_FAITHFUL:
        return String("FAITHFUL")
    if verdict == BAND_FAITHFUL_NEAR_TIE:
        return String("FAITHFUL_NEAR_TIE")
    if verdict == BAND_DIVERGENT:
        return String("DIVERGENT")
    if verdict == BAND_COMPARATOR_ARTIFACT:
        return String("COMPARATOR_ARTIFACT")
    return String("NOT_GRADED")


def band_line() -> String:
    """The gate's one-line statement of the encoded band,
    for doctor / filing surfaces that quote the rule."""
    return String(
        "A-111 near-tie gate: rank <= 2 AND gap_milli < 1000"
        " (sub-logit) = faithful; exact kept distinct from"
        " near-tie; comparator artifact precedes grading"
    )
