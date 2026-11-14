"""A-112: Comparator-artifact checklist, automated -- the
four pre-filing checks every oracle comparison runs
BEFORE any engine divergence may be filed (Wave 13,
Oracle infrastructure).

The roadmap text: "Template, BOS, backend-mismatch, and
step-0 boundary checks run before any engine divergence
is filed. Acceptance: seeded fake divergences of each
class are caught by the checklist and verdicted as
comparator artifacts."

Before this slice the checklist lived in prose: the
host contract in core/prefill_grade.mojo's header ("the
caller records which kind fired"), A-109's harness gate
(tf_validate_run rejects template input and backend
mismatch for the A-045 reproduction), and the standing
court discipline (check the comparator before suspecting
the engine -- template rendering, BOS rendering, backend
mismatch, and prompt-boundary step-0 effects each fake
divergences that are in neither engine's maths). Every
new grading driver re-stated the checks by hand, and an
omitted check filed a fake divergence. This module is
the ONE automated encoding: four named checks, run in a
pre-registered order over a stated comparison account,
returning one summary whose verdict is either CLEAN
(the comparison may be graded, and a divergence in it
may be filed) or COMPARATOR_ARTIFACT (the comparison
itself is the defect; nothing about the engine may be
filed from it).

THE ACCOUNT (what the caller must state explicitly):
  prompt            the exact prompt bytes graded, as
                    text -- the checklist inspects them
                    for template and rendered-BOS marks;
  engine_bos        whether the engine side applied BOS;
  comparator_bos    whether the comparator side applied
                    BOS;
  engine_backend    the engine backend name;
  comparator_backend the oracle backend name (the pin
                    A-110's registry records per row);
  ranks, gaps_milli the per-step teacher-forcing records
                    (gap as milli-logits, the tree's
                    exact-integer convention).

THE FOUR CHECKS, PRE-REGISTERED (order = precedence
when several fire; every hit is recorded in the summary
whichever kind takes precedence):
  (K1) TEMPLATE: the prompt carries any chat-template
       rendering marker (core/teacher_forcing_harness
       tf_template_markers -- the A-109 harness's own
       list, consulted here so the two cannot drift).
       A template-rendered prompt is a different input
       from the raw prompt; grading it as if raw is the
       llama-cli --single-turn trap that manufactured
       wave-era fake divergences.
  (K2) BOS: the two sides' BOS handling differs
       (engine_bos != comparator_bos), or the prompt
       carries a rendered BOS mark ("<s>" prefix -- the
       mark A-109's detector folds into its template
       rejection) that NEITHER side's stated handling
       accounts for. A BOS present on one side only
       shifts every position by one token.
  (K3) BACKEND_MISMATCH: either backend is unnamed, the
       two backends differ, or the pair is not CPU vs
       CPU. Standing law: CPU engine vs CPU comparator
       only; accelerator-visible is not accelerator-run,
       and a cross-backend comparison grades the
       backends' difference, not the engine.
  (K4) STEP0_BOUNDARY: the records diverge, and every
       divergent record sits at step 0 (later steps are
       exact or near-tie under A-111's gate classes).
       A prompt-boundary step-0 effect is a comparator
       artifact class for filing purposes: it is never
       filed as an engine divergence on this evidence
       alone (prefill_grade keeps its STEP0_BOUNDARY
       cell disposition for the same pattern; the two
       accounts agree that such a pattern is not an
       engine divergence, and the seeded case here
       proves the checklist catches it before filing).

VERDICTS:
  CHECK_CLEAN               no check fired; grading and
                            (if the records diverge past
                            step 0) divergence filing
                            may proceed.
  CHECK_COMPARATOR_ARTIFACT at least one check fired;
                            kind names the first firing
                            check in K1-K4 precedence.
  may_file_divergence(summary) is True exactly for a
  CLEAN summary with at least one divergent record:
  the checklist is the only road to a divergence filing.

Records are validated by A-111's gate (step_class):
inconsistent records (rank 0 with a nonzero gap,
positive rank with a zero gap, negatives) and length
mismatches are REFUSED, not verdicted -- a broken
transcription is not a comparison. An empty record set
fires no step-0 check and files no divergence.

RAW-ORACLE DISCIPLINE (standing): the records this
checklist guards come from teacher-forcing rank + logit
gap on RAW prompts, CPU engine vs CPU comparator only,
with the oracle backend recorded per row (A-110's
registry) and the band applied by A-111's gate. The
checklist itself executes nothing, opens no device, and
claims no speed: pure inspection of a stated account.
IQ-family rows are graded on coherence, never
token-exactness (A-115's policy); this checklist mints
no token-exactness demand.
"""

from core.near_tie_gate import (
    BAND_STEP_DIVERGENT,
    step_class as gate_step_class,
)
from core.teacher_forcing_harness import tf_template_markers

# Artifact kinds, in checklist precedence order (K1-K4).
comptime ARTIFACT_NONE = 0
comptime ARTIFACT_TEMPLATE = 1
comptime ARTIFACT_BOS = 2
comptime ARTIFACT_BACKEND_MISMATCH = 3
comptime ARTIFACT_STEP0_BOUNDARY = 4

# Checklist verdicts.
comptime CHECK_CLEAN = 0
comptime CHECK_COMPARATOR_ARTIFACT = 1

# The checklist always runs exactly these four checks.
comptime CHECKLIST_CHECKS_RUN = 4

# The only backend pair a comparison may grade (K3).
comptime CHECKLIST_CPU_BACKEND = "cpu"


struct ChecklistSummary(Copyable, ImplicitlyCopyable):
    """One comparison account after the checklist: the
    verdict, the artifact kind that took precedence (or
    ARTIFACT_NONE), every check's hit recorded
    independently, and the divergence counts that witness
    what the comparison would have filed. counts are
    computed even for an artifact verdict, so the filing
    shows what the invalid comparison would have hidden.
    first_divergent_step is -1 when no record diverges."""

    var verdict: Int
    var kind: Int
    var checks_run: Int
    var steps: Int
    var divergent_count: Int
    var first_divergent_step: Int
    var template_hit: Bool
    var bos_hit: Bool
    var backend_hit: Bool
    var step0_hit: Bool

    def __init__(
        out self,
        verdict: Int,
        kind: Int,
        checks_run: Int,
        steps: Int,
        divergent_count: Int,
        first_divergent_step: Int,
        template_hit: Bool,
        bos_hit: Bool,
        backend_hit: Bool,
        step0_hit: Bool,
    ):
        self.verdict = verdict
        self.kind = kind
        self.checks_run = checks_run
        self.steps = steps
        self.divergent_count = divergent_count
        self.first_divergent_step = first_divergent_step
        self.template_hit = template_hit
        self.bos_hit = bos_hit
        self.backend_hit = backend_hit
        self.step0_hit = step0_hit


def checklist_template_hit(prompt: String) -> Bool:
    """K1: the prompt carries a chat-template rendering
    marker from A-109's harness list. The rendered-BOS
    mark "<s>" is NOT counted here -- A-109 folds it
    into its rejection, but this checklist files it
    under its own class (K2 BOS)."""
    var markers = tf_template_markers()
    for i in range(len(markers)):
        if markers[i] in prompt:
            return True
    return False


def checklist_bos_hit(
    prompt: String, engine_bos: Bool, comparator_bos: Bool
) -> Bool:
    """K2: BOS handling differs between the sides, or the
    prompt carries a rendered BOS mark that neither
    side's stated handling accounts for."""
    if engine_bos != comparator_bos:
        return True
    if prompt.startswith("<s>") and not engine_bos and not comparator_bos:
        return True
    return False


def checklist_backend_hit(
    engine_backend: String, comparator_backend: String
) -> Bool:
    """K3: an unnamed backend, differing backends, or any
    pair that is not CPU engine vs CPU comparator."""
    if engine_backend.byte_length() == 0:
        return True
    if comparator_backend.byte_length() == 0:
        return True
    if engine_backend != comparator_backend:
        return True
    if engine_backend != String(CHECKLIST_CPU_BACKEND):
        return True
    return False


def run_comparator_checklist(
    prompt: String,
    engine_bos: Bool,
    comparator_bos: Bool,
    engine_backend: String,
    comparator_backend: String,
    ranks: List[Int],
    gaps_milli: List[Int],
) raises -> ChecklistSummary:
    """Run the four pre-filing checks (K1-K4) over one
    stated comparison account. Records are validated by
    A-111's gate before any check reads them: an
    inconsistent record or a length mismatch is refused,
    not verdicted. The verdict is exactly the
    pre-registered rule applied to those inputs --
    nothing else is consulted."""
    if len(ranks) != len(gaps_milli):
        raise Error(
            "ComparatorChecklist: rank and gap record lengths differ"
        )
    var steps = len(ranks)
    var divergent = 0
    var first_divergent = -1
    var divergent_only_at_step0 = True
    for i in range(steps):
        var cls = gate_step_class(ranks[i], gaps_milli[i])
        if cls == BAND_STEP_DIVERGENT:
            divergent += 1
            if first_divergent < 0:
                first_divergent = i
            if i != 0:
                divergent_only_at_step0 = False
    var template_hit = checklist_template_hit(prompt)
    var bos_hit = checklist_bos_hit(prompt, engine_bos, comparator_bos)
    var backend_hit = checklist_backend_hit(engine_backend, comparator_backend)
    var step0_hit = divergent > 0 and divergent_only_at_step0
    var kind = ARTIFACT_NONE
    if template_hit:
        kind = ARTIFACT_TEMPLATE
    elif bos_hit:
        kind = ARTIFACT_BOS
    elif backend_hit:
        kind = ARTIFACT_BACKEND_MISMATCH
    elif step0_hit:
        kind = ARTIFACT_STEP0_BOUNDARY
    var verdict = CHECK_CLEAN
    if kind != ARTIFACT_NONE:
        verdict = CHECK_COMPARATOR_ARTIFACT
    return ChecklistSummary(
        verdict,
        kind,
        CHECKLIST_CHECKS_RUN,
        steps,
        divergent,
        first_divergent,
        template_hit,
        bos_hit,
        backend_hit,
        step0_hit,
    )


def may_file_divergence(summary: ChecklistSummary) -> Bool:
    """The only road to a divergence filing: the
    checklist is CLEAN and the records actually diverge.
    An artifact verdict files nothing about the engine,
    and a clean comparison with no divergence files a
    faithful grade, not a divergence."""
    return summary.verdict == CHECK_CLEAN and summary.divergent_count > 0


def artifact_blocks_filing(summary: ChecklistSummary) -> Bool:
    """True iff the checklist verdicted the comparison a
    comparator artifact: check the comparator, re-run
    the comparison, never suspect the engine from it."""
    return summary.verdict == CHECK_COMPARATOR_ARTIFACT


def artifact_kind_name(kind: Int) -> String:
    """The filed name of an artifact kind code -- the
    only strings a filing may use for the kind."""
    if kind == ARTIFACT_TEMPLATE:
        return String("TEMPLATE_RENDERING")
    if kind == ARTIFACT_BOS:
        return String("BOS_RENDERING")
    if kind == ARTIFACT_BACKEND_MISMATCH:
        return String("BACKEND_MISMATCH")
    if kind == ARTIFACT_STEP0_BOUNDARY:
        return String("STEP0_BOUNDARY")
    return String("NONE")


def checklist_verdict_name(verdict: Int) -> String:
    """The filed name of a checklist verdict code."""
    if verdict == CHECK_COMPARATOR_ARTIFACT:
        return String("COMPARATOR_ARTIFACT")
    return String("CLEAN")


def checklist_line() -> String:
    """The checklist's one-line statement, for doctor /
    filing surfaces that quote the rule."""
    return String(
        "A-112 comparator checklist: template, BOS,"
        " backend-mismatch, and step-0 checks run before"
        " any engine divergence is filed; any hit files"
        " COMPARATOR_ARTIFACT with its kind named"
    )
