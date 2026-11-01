"""Prefill faithfulness battery: the grading account for
one battery cell (Janas road J-060).

The roadmap text: "Prefill on GPU vs CPU comparator across
the arch matrix: rank/gap grading on raw prompts, step-0
boundary effects named as their own class." A battery cell
is one (architecture, prefill form, prompt) graded the
road's one way: the engine prefill under test produces its
ids on the RAW prompt, and the ggml CPU comparator -- run
as a teacher-forcing oracle over libllama (the 204 road's
tf_oracle), CPU engine vs CPU comparator only -- scores
each forced id with a rank and a logit gap (the
comparator's top-1 logit minus the forced id's logit).
This module is the account that turns those per-step
(rank, gap) records into the cell's verdict, in the
J-031/J-053/J-059 style: pure arithmetic on stated records,
nothing executed, no device opened, no speed claimed. It
contains no verdict except through the pre-registered rule
below: a caller supplies records and the comparator's
validity, and receives exactly the verdict the rule states.

WHAT EXISTS AND WHAT THIS IS NOT (the slice doc's
inspection, section 2, is first-hand): the tree's only
rank/gap machinery today is the 204 road's tf_oracle -- an
on-box C tool over libllama, not in this repo -- plus
filed grade TEXTS (J-022's pre- and post-fix tables) and
offline python re-parsers of filed logs (J-030/J-034).
There is no in-tree grading code, no battery matrix, and
no verdict account. This module is that missing account;
running the oracle, running any engine, and timing any
prefill stay with the deferred live leg (slice doc
section 7).

GAPS AS MILLI-LOGITS. Filed grades print gaps to three
decimals (0.108, 2.479). Records here carry the gap as an
integer count of milli-logits (gap x 1000, rounded by the
filer from the printed value), so the account stays exact
integer arithmetic like the road's other accounts (basis
points in J-059, floored margins in J-058). The near-tie
test is then exact: sub-logit means gap_milli < 1000.

THE VERDICT RULE, PRE-REGISTERED (stated here and in the
slice doc section 5 BEFORE any filed grade was run
through it; the filed-evidence cells of doc section 6 are
graded by exactly this rule and no other):

  Per step (rank r, gap g in milli-logits):
    (S1) EXACT iff r == 0 (then g == 0 by definition of
         the gap; an inconsistent record is refused, not
         graded).
    (S2) NEAR-TIE iff r <= NEAR_TIE_MAX_RANK (2) AND
         g < 1000 -- BOTH conjuncts bind: rank 2 with a
         1.138 gap is NOT a near-tie (the J-022 pre-fix
         step 17 is the filed witness), and rank 3 with a
         0.010 gap is NOT a near-tie either.
    (S3) DIVERGENT otherwise.

  Per cell (the ordered step records + a comparator-valid
  flag the caller must state explicitly):
    (C1) NOT_GRADED iff there are no step records. An
         unbuilt prefill form, an unrun leg, and a refused
         context all land here -- never in a graded class.
    (C2) COMPARATOR_ARTIFACT iff the comparator check
         failed (comparator_valid == False): the grade
         says something about the comparison, nothing
         about the engine. This verdict takes precedence
         over every step pattern, perfect or divergent --
         check the comparator before suspecting the
         engine. The artifact KINDS are named in advance
         by the protocol (doc section 4): template
         rendering, BOS rendering, backend mismatch, and
         tokenization misalignment; the caller records
         which kind fired beside the verdict.
    (C3) STEP0_BOUNDARY iff comparator-valid, at least one
         step exists, the ONLY divergent steps are at
         step 0, and every later step is exact or
         near-tie. A prompt-boundary effect is its own
         verdict class: it is neither faithful (step 0 did
         diverge) nor divergent (no evidence the prefill
         maths diverges past the boundary). Its
         disposition is the recipe's: re-grade with the
         boundary handled explicitly (doc section 7),
         never a silent pass and never an engine defect
         on this evidence alone.
    (C4) FAITHFUL iff every step is exact.
    (C5) NEAR_TIE iff no step is divergent and at least
         one step is near-tie. NEAR_TIE is a PASS verdict
         under the road's standing discipline (the
         roadmap's near-tie band: rank <= 2 with sub-logit
         gap = faithful) -- it is kept distinct from
         FAITHFUL so a cell with a near-tie step is never
         filed as a perfect cell, and the J-022 post-fix
         OLMoE grade (rank 0 at 23/24, step 23 near-tie)
         is its filed witness.
    (C6) DIVERGENT otherwise: at least one divergent step
         past step 0, or a divergent step 0 with any later
         divergence. first_divergent_step names where the
         evidence starts.

  No other verdict is reachable: the account has no
  wall, no agreement percentage, and no averaged gap --
  a mean gap would let exact steps buy out a divergent
  one, which is precisely what rank/gap grading exists
  to refuse. J-055's top-1 agreement counts ride BESIDE
  this account in the live leg's filing, never instead
  of it.

HOST CONTRACT (who calls this, per the doc's protocol):
the live leg's driver (doc section 7) runs, per cell,
ids first (the form's generated ids vs the same arch's
reference-form ids, token for token), then the tf_oracle
grade on the raw prompt, checks the comparator (CPU
comparator only; raw prompt, no template; tokenization
count equal on both sides; same BOS handling), converts
the printed gaps to milli-logits, and files
grade_prefill_cell's summary verbatim beside the raw
grade text. A cell whose comparator check fails is filed
COMPARATOR_ARTIFACT with its kind named and is re-run,
not debated. Garbage is refused where detectable:
mismatched record lengths, negative rank or gap, and the
inconsistent pairs (rank 0 with a nonzero gap; rank > 0
with a zero gap -- the comparator's top-1 IS the forced
id exactly when the gap is zero).
"""

# The verdict codes. Names are filed verbatim by
# verdict_name(); no other verdict string exists.
comptime VERDICT_NOT_GRADED = 0
comptime VERDICT_FAITHFUL = 1
comptime VERDICT_NEAR_TIE = 2
comptime VERDICT_DIVERGENT = 3
comptime VERDICT_COMPARATOR_ARTIFACT = 4
comptime VERDICT_STEP0_BOUNDARY = 5

# Per-step classes.
comptime STEP_EXACT = 0
comptime STEP_NEAR_TIE = 1
comptime STEP_DIVERGENT = 2

# The near-tie band, pre-registered (the roadmap's rule).
comptime NEAR_TIE_MAX_RANK = 2
comptime NEAR_TIE_MAX_GAP_MILLI = 1000


struct GradeSummary(Copyable, ImplicitlyCopyable):
    """One cell's graded account: the verdict the
    pre-registered rule states for the supplied records,
    with the counts that witness it. first_divergent_step
    is -1 when no step diverges. worst_rank and
    worst_gap_milli are independent maxima over the steps
    (they need not come from the same step); both are 0
    on an empty (NOT_GRADED) account."""

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


def _check_step(rank: Int, gap_milli: Int) raises:
    """One record's internal consistency. A rank-0 forced
    id IS the comparator's top-1, so its gap is zero by
    definition; a positive rank means some other id scored
    strictly higher, so the gap is strictly positive. A
    record violating either is not a grade -- it is a
    broken transcription, refused rather than graded."""
    if rank < 0 or gap_milli < 0:
        raise Error("PrefillGrade: rank and gap must be non-negative")
    if rank == 0 and gap_milli != 0:
        raise Error("PrefillGrade: rank 0 with a nonzero gap is inconsistent")
    if rank > 0 and gap_milli == 0:
        raise Error("PrefillGrade: positive rank with a zero gap is inconsistent")


def step_class(rank: Int, gap_milli: Int) raises -> Int:
    """The pre-registered per-step class (S1-S3): exact,
    near-tie (both conjuncts), or divergent."""
    _check_step(rank, gap_milli)
    if rank == 0:
        return STEP_EXACT
    if rank <= NEAR_TIE_MAX_RANK and gap_milli < NEAR_TIE_MAX_GAP_MILLI:
        return STEP_NEAR_TIE
    return STEP_DIVERGENT


def grade_prefill_cell(
    ranks: List[Int], gaps_milli: List[Int], comparator_valid: Bool
) raises -> GradeSummary:
    """Grade one battery cell from its per-step records.
    ranks and gaps_milli are the oracle's filed per-step
    values in step order (gap as milli-logits);
    comparator_valid is the caller's explicit statement
    that the comparator check passed (CPU comparator only,
    raw prompt, tokenization aligned, no template/BOS/
    backend artifact). The verdict is exactly the
    pre-registered rule (C1-C6) applied to those inputs --
    nothing else is consulted."""
    if len(ranks) != len(gaps_milli):
        raise Error("PrefillGrade: rank and gap record lengths differ")
    var steps = len(ranks)
    var exact = 0
    var near = 0
    var divergent = 0
    var first_divergent = -1
    var divergent_only_at_step0 = True
    var worst_rank = 0
    var worst_gap = 0
    for i in range(steps):
        var cls = step_class(ranks[i], gaps_milli[i])
        if cls == STEP_EXACT:
            exact += 1
        elif cls == STEP_NEAR_TIE:
            near += 1
        else:
            divergent += 1
            if first_divergent < 0:
                first_divergent = i
            if i != 0:
                divergent_only_at_step0 = False
        if ranks[i] > worst_rank:
            worst_rank = ranks[i]
        if gaps_milli[i] > worst_gap:
            worst_gap = gaps_milli[i]
    var verdict: Int
    if steps == 0:
        verdict = VERDICT_NOT_GRADED
    elif not comparator_valid:
        verdict = VERDICT_COMPARATOR_ARTIFACT
    elif divergent > 0 and divergent_only_at_step0:
        verdict = VERDICT_STEP0_BOUNDARY
    elif divergent > 0:
        verdict = VERDICT_DIVERGENT
    elif near > 0:
        verdict = VERDICT_NEAR_TIE
    else:
        verdict = VERDICT_FAITHFUL
    return GradeSummary(
        verdict,
        steps,
        exact,
        near,
        divergent,
        first_divergent,
        worst_rank,
        worst_gap,
    )


def verdict_name(verdict: Int) -> String:
    """The filed name of a verdict code -- the only
    strings a battery filing may use for a cell."""
    if verdict == VERDICT_FAITHFUL:
        return String("FAITHFUL")
    if verdict == VERDICT_NEAR_TIE:
        return String("NEAR_TIE")
    if verdict == VERDICT_DIVERGENT:
        return String("DIVERGENT")
    if verdict == VERDICT_COMPARATOR_ARTIFACT:
        return String("COMPARATOR_ARTIFACT")
    if verdict == VERDICT_STEP0_BOUNDARY:
        return String("STEP0_BOUNDARY")
    return String("NOT_GRADED")
