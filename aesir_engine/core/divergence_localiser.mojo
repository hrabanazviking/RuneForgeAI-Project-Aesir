"""A-116: First-divergence localisation -- given a
failing row, find the first layer/op where the engine's
and the comparator's outputs separate (Wave 13, Oracle
infrastructure).

The roadmap text: "Tooling that, given a failing row,
finds the first layer/op where outputs separate.
Acceptance: demonstrated on a seeded divergence; used
in anger at least once in Wave 14 or the slice
re-opens."

Before this slice the tree could grade a row (A-111's
near-tie gate, core/near_tie_gate.mojo), refuse a fake
one (A-112's comparator-artifact checklist, core/
comparator_checklist.mojo), and lay the filed rows out
as a matrix (A-114, core/matrix_runner.mojo) -- but when
a row filed DIVERGENT, the next question had no tool:
WHICH layer, WHICH op, first separated? Wave-era
debugging answered it by hand, re-running the row with
per-layer dumps and eyeballing the traces. This module
is the ONE encoding of that walk: an ordered list of
per-checkpoint probe records for the row, each graded
by A-111's gate classes, scanned in execution order;
the first probe outside the near-tie band is the
localisation. No caller re-types the band, no caller
re-runs the checklist by hand, and no localisation is
ever filed from a comparison A-112 would have refused.

THE ACCOUNT (what the caller must state explicitly):
  The comparison account is A-112's, unchanged: the
  exact prompt bytes, both sides' BOS handling, both
  backend names, and the row's per-step teacher-forcing
  records (rank, gap in milli-logits -- the tree's
  exact-integer convention). On top of it the caller
  states the probe records: one Probe per checkpoint,
  in execution order, each carrying the layer index,
  the op name, and the teacher-forcing rank + logit
  gap (milli-logits) graded at that checkpoint (the
  row re-graded with the checkpoint's output forced --
  the logit-lens account this tree's graders already
  file per step, applied per layer/op). Probes are
  stated records; the localiser executes nothing.

THE RULE, PRE-REGISTERED (stated here before any test
in tests/test_divergence_localiser_a116.mojo was run):
  (L1) Every probe and every row record is validated
       by A-111's gate (validate_step_record /
       step_class): an inconsistent record (rank 0
       with a nonzero gap, positive rank with a zero
       gap, negatives), an empty probe list, an empty
       or negative-layer probe, a duplicate (layer, op)
       probe, or probes whose layer order decreases
       are REFUSED, not localised -- a broken trace is
       not a comparison.
  (L2) A-112's checklist runs over the row account
       BEFORE any probe is read for a location. Any
       hit verdicts COMPARATOR_ARTIFACT with the kind
       named by K1-K4 precedence, and NO location is
       filed (first_index / first_layer stay -1, first
       op empty): template rendering, BOS rendering,
       backend mismatch, and step-0 boundary effects
       each fake divergences that are in neither
       engine's maths, and a step-0-only row in
       particular has no layer separation to find.
       Probe class counts are still computed, so the
       filing shows what the invalid comparison would
       have hidden (the gate/checklist convention).
  (L3) A stated row with no records files NOT_GRADED:
       there is no failing row to localise against.
  (L4) A clean row with no divergent record files
       NO_DIVERGENCE: the row is faithful (exact or
       near-tie), so there is no separation to find,
       whatever the probes show.
  (L5) A clean, divergent row is localised by the
       scan: probes are classified by A-111's
       step_class in execution order (EXACT and
       NEAR_TIE are faithful -- a near-tie probe never
       localises; the band's BOTH conjuncts bind, so
       rank 2 with a full-logit gap and rank 3 with a
       sub-logit gap are each divergent); the FIRST
       DIVERGENT probe files LOCALISED with its index,
       layer, op, rank and gap as the witness. Later
       divergent probes are counted, never reported
       as the location: downstream separation is the
       seed's propagation, not its origin.
  (L6) A clean, divergent row whose probes are all
       faithful files NO_DIVERGENCE with the probe
       counts as witness: the stated checkpoints do
       not cover the separating op, and the honest
       filing says so instead of naming a wrong layer.
       The caller adds probes; the tool does not guess.

THE SEEDED DEMONSTRATION (the roadmap acceptance):
  seeded_probes() builds the canonical synthetic trace:
  DEMO_LAYERS (12) layers x the four per-layer ops of
  localiser_ops() (attn.q_proj, attn.out_proj,
  mlp.up_proj, mlp.down_proj), plus the final lm_head
  probe -- 49 probes. Every probe before the seed is
  exact or near-tie (a near-tie every fifth probe, so
  the demo proves the band is respected, not just the
  exact case); the seed sits at SEEDED_LAYER (7),
  SEEDED_OP (mlp.down_proj), probe index 31, with rank
  3 / gap 1450 milli-logits, and every later probe is
  divergent (the separation propagates downstream, as
  a real one does). The seeded row account is clean
  under A-112 (RAW prompt, BOS on both sides, CPU vs
  CPU, divergence past step 0). localise_seeded()
  files LOCALISED at exactly (7, mlp.down_proj); the
  bench driver (tests/bench_localise_a116.mojo) runs
  it on the Z13 and its log is the filed evidence.

CARRIED CONDITION (the roadmap's own words): the
acceptance also requires the tool be "used in anger
at least once in Wave 14 or the slice re-opens". That
use cannot happen inside Wave 13; it is carried,
named, exactly as the roadmap states it, in
hidden_files/A116_LEDGER.md, and the first Wave 14
divergence investigation owes this tool its first
real filing.

INTEGRATION POINTS (honest, named, not depended on):
  A-115 (IQ coherence policy encoding, team-25) is
  building in parallel and has NOT banked; this module
  takes NO dependency on it. IQ rows stay graded on
  coherence, never token-exactness; when A-115 banks,
  its policy names how an IQ row's probes are filed,
  without changing this rule's shape. The matrix
  runner's DIVERGENT cells (A-114) are this tool's
  natural input queue: a divergent cell's row account
  plus per-checkpoint probes is exactly one
  localise_divergence call.

RAW-ORACLE DISCIPLINE (standing): every record this
tool reads comes from teacher-forcing rank + logit
gap on RAW prompts, CPU engine vs CPU comparator
only, with the oracle backend recorded per row
(A-110's registry) and the band applied by A-111's
gate. The localiser itself executes nothing, opens
no device, and claims no speed and no accelerator
execution: pure arithmetic on stated records, in the
J-031/J-053 account style.
"""

from core.comparator_checklist import (
    ARTIFACT_NONE,
    CHECK_COMPARATOR_ARTIFACT,
    artifact_kind_name,
    run_comparator_checklist,
)
from core.near_tie_gate import (
    BAND_STEP_DIVERGENT,
    BAND_STEP_EXACT,
    BAND_STEP_NEAR_TIE,
    step_class as gate_step_class,
    validate_step_record,
)

# Localisation verdicts. This module's own namespace,
# filed separately from the gate's and the checklist's
# (the A-114 convention); COMPARATOR_ARTIFACT here
# means A-112's checklist verdicted the row account --
# the kind is carried in the report's kind field, in
# A-112's ARTIFACT_* codes.
comptime LOC_NO_DIVERGENCE = 0
comptime LOC_LOCALISED = 1
comptime LOC_COMPARATOR_ARTIFACT = 2
comptime LOC_NOT_GRADED = 3

# The seeded demonstration's shape (see the header):
# 12 layers x 4 ops + the final lm_head probe = 49
# probes; the seed is layer 7's mlp.down_proj, probe
# index 7 * 4 + 3 = 31.
comptime DEMO_LAYERS = 12
comptime SEEDED_LAYER = 7
comptime SEEDED_OP = "mlp.down_proj"
comptime SEEDED_INDEX = 31
comptime SEEDED_RANK = 3
comptime SEEDED_GAP_MILLI = 1450


struct Probe(Copyable, ImplicitlyCopyable):
    """One checkpoint record for a row: the teacher-
    forcing rank + logit gap (milli-logits) graded at
    this layer/op checkpoint, in execution order. A
    probe is a stated record; its consistency is
    A-111's validate_step_record, applied by L1."""

    var layer: Int
    var op: String
    var rank: Int
    var gap_milli: Int

    def __init__(
        out self, layer: Int, op: String, rank: Int, gap_milli: Int
    ):
        self.layer = layer
        self.op = op
        self.rank = rank
        self.gap_milli = gap_milli


struct Localisation(Copyable, ImplicitlyCopyable):
    """One failing row after localisation: the verdict,
    the A-112 artifact kind when the checklist refused
    the comparison (ARTIFACT_NONE otherwise), the probe
    class counts that witness the scan, and -- only for
    LOCALISED -- the first divergent probe's index,
    layer, op, rank and gap. On every other verdict
    first_index / first_layer are -1 and first_op is
    empty: no location is filed, never a guessed one.
    row_steps / row_divergent carry the checklist's
    counts for the row account itself."""

    var verdict: Int
    var kind: Int
    var probes: Int
    var exact_count: Int
    var near_tie_count: Int
    var divergent_count: Int
    var first_index: Int
    var first_layer: Int
    var first_op: String
    var first_rank: Int
    var first_gap_milli: Int
    var row_steps: Int
    var row_divergent: Int

    def __init__(
        out self,
        verdict: Int,
        kind: Int,
        probes: Int,
        exact_count: Int,
        near_tie_count: Int,
        divergent_count: Int,
        first_index: Int,
        first_layer: Int,
        first_op: String,
        first_rank: Int,
        first_gap_milli: Int,
        row_steps: Int,
        row_divergent: Int,
    ):
        self.verdict = verdict
        self.kind = kind
        self.probes = probes
        self.exact_count = exact_count
        self.near_tie_count = near_tie_count
        self.divergent_count = divergent_count
        self.first_index = first_index
        self.first_layer = first_layer
        self.first_op = first_op
        self.first_rank = first_rank
        self.first_gap_milli = first_gap_milli
        self.row_steps = row_steps
        self.row_divergent = row_divergent


def loc_fnv1a64(text: String) -> UInt64:
    """FNV-1a 64 over the text bytes -- the tree's
    digest convention (same constants as tf_fnv1a64
    in A-109 and mx_fnv1a64 in A-114)."""
    var hash: UInt64 = 14695981039346656037
    var prime: UInt64 = 1099511628211
    var bytes = text.as_bytes()
    for i in range(len(bytes)):
        hash = hash ^ UInt64(bytes[i])
        hash = hash * prime
    return hash


def localiser_ops() -> List[String]:
    """The per-layer op checkpoints, in execution
    order: the attention projections, then the MLP
    projections. The seeded trace and any real probe
    filing name their ops from this list (plus the
    row-level embed / lm_head checkpoints a caller
    may state at the trace's ends)."""
    var ops = List[String]()
    ops.append(String("attn.q_proj"))
    ops.append(String("attn.out_proj"))
    ops.append(String("mlp.up_proj"))
    ops.append(String("mlp.down_proj"))
    return ops^


def _validate_probes(probes: List[Probe]) raises:
    """L1 for the probe list: non-empty, every record
    consistent under A-111, layers non-negative and
    non-decreasing in execution order, op names
    stated, and no duplicate (layer, op) checkpoint
    -- a duplicated checkpoint would make 'first'
    ambiguous, so it is refused, not resolved."""
    if len(probes) == 0:
        raise Error("DivergenceLocaliser: probe list is empty")
    for i in range(len(probes)):
        var p = probes[i]
        if p.layer < 0:
            raise Error("DivergenceLocaliser: probe layer is negative")
        if p.op.byte_length() == 0:
            raise Error("DivergenceLocaliser: probe op is unnamed")
        validate_step_record(p.rank, p.gap_milli)
        if i > 0 and p.layer < probes[i - 1].layer:
            raise Error(
                "DivergenceLocaliser: probe layers decrease"
                " -- probes must be stated in execution order"
            )
        for j in range(i + 1, len(probes)):
            if probes[j].layer == p.layer and probes[j].op == p.op:
                raise Error(
                    "DivergenceLocaliser: duplicate probe for layer "
                    + String(p.layer)
                    + " op "
                    + p.op
                )


def first_divergent_probe(probes: List[Probe]) raises -> Int:
    """The pure scan (L5's engine, without the L2-L4
    filing rules): the index of the first probe A-111's
    gate classes DIVERGENT, or -1 when every probe is
    exact or near-tie. Probes are validated first (L1):
    an inconsistent trace is refused, not scanned."""
    _validate_probes(probes)
    for i in range(len(probes)):
        var cls = gate_step_class(probes[i].rank, probes[i].gap_milli)
        if cls == BAND_STEP_DIVERGENT:
            return i
    return -1


def localise_divergence(
    prompt: String,
    engine_bos: Bool,
    comparator_bos: Bool,
    engine_backend: String,
    comparator_backend: String,
    ranks: List[Int],
    gaps_milli: List[Int],
    probes: List[Probe],
) raises -> Localisation:
    """Localise one failing row by the pre-registered
    rule (L1-L6): validate, run A-112's checklist over
    the row account, then -- only for a clean, divergent
    row -- file the first divergent probe in execution
    order. The verdict is exactly the rule applied to
    those inputs -- nothing else is consulted."""
    _validate_probes(probes)
    var exact = 0
    var near = 0
    var divergent = 0
    var first = -1
    for i in range(len(probes)):
        var cls = gate_step_class(probes[i].rank, probes[i].gap_milli)
        if cls == BAND_STEP_EXACT:
            exact += 1
        elif cls == BAND_STEP_NEAR_TIE:
            near += 1
        else:
            divergent += 1
            if first < 0:
                first = i
    var check = run_comparator_checklist(
        prompt,
        engine_bos,
        comparator_bos,
        engine_backend,
        comparator_backend,
        ranks,
        gaps_milli,
    )
    if check.verdict == CHECK_COMPARATOR_ARTIFACT:
        return Localisation(
            LOC_COMPARATOR_ARTIFACT,
            check.kind,
            len(probes),
            exact,
            near,
            divergent,
            -1,
            -1,
            String(""),
            0,
            0,
            check.steps,
            check.divergent_count,
        )
    if len(ranks) == 0:
        return Localisation(
            LOC_NOT_GRADED,
            ARTIFACT_NONE,
            len(probes),
            exact,
            near,
            divergent,
            -1,
            -1,
            String(""),
            0,
            0,
            check.steps,
            check.divergent_count,
        )
    if check.divergent_count == 0 or first < 0:
        return Localisation(
            LOC_NO_DIVERGENCE,
            ARTIFACT_NONE,
            len(probes),
            exact,
            near,
            divergent,
            -1,
            -1,
            String(""),
            0,
            0,
            check.steps,
            check.divergent_count,
        )
    var p = probes[first]
    return Localisation(
        LOC_LOCALISED,
        ARTIFACT_NONE,
        len(probes),
        exact,
        near,
        divergent,
        first,
        p.layer,
        p.op,
        p.rank,
        p.gap_milli,
        check.steps,
        check.divergent_count,
    )


def seeded_probes() -> List[Probe]:
    """The canonical seeded trace (see the header):
    DEMO_LAYERS layers x localiser_ops(), plus the
    final lm_head probe. Probes before the seed are
    exact, except every fifth (index % 5 == 4), which
    is near-tie (rank 1, gap 240) -- inside A-111's
    band on both conjuncts. The seed probe (index
    SEEDED_INDEX) carries SEEDED_RANK / SEEDED_GAP_
    MILLI; every later probe is divergent (rank 4,
    gap 1700; the lm_head probe rank 5, gap 2100):
    the separation propagates downstream."""
    var ops = localiser_ops()
    var probes = List[Probe]()
    var idx = 0
    for layer in range(DEMO_LAYERS):
        for oi in range(len(ops)):
            if idx < SEEDED_INDEX:
                if idx % 5 == 4:
                    probes.append(Probe(layer, ops[oi], 1, 240))
                else:
                    probes.append(Probe(layer, ops[oi], 0, 0))
            elif idx == SEEDED_INDEX:
                probes.append(
                    Probe(layer, ops[oi], SEEDED_RANK, SEEDED_GAP_MILLI)
                )
            else:
                probes.append(Probe(layer, ops[oi], 4, 1700))
            idx += 1
    probes.append(Probe(DEMO_LAYERS, String("lm_head"), 5, 2100))
    return probes^


def localise_seeded() raises -> Localisation:
    """The seeded demonstration, one call: the seeded
    trace against its clean row account (RAW prompt,
    BOS on both sides, CPU engine vs CPU comparator,
    the row divergent at steps 2 and 3 -- past step 0,
    so A-112's K4 does not fire). Files LOCALISED at
    (SEEDED_LAYER, SEEDED_OP) or the demo has failed;
    the bench driver and the suite both assert it."""
    return localise_divergence(
        String("The sea is wide."),
        True,
        True,
        String("cpu"),
        String("cpu"),
        List[Int]([0, 0, 3, 4]),
        List[Int]([0, 0, 1450, 1700]),
        seeded_probes(),
    )


def localisation_verdict_name(verdict: Int) -> String:
    """The filed name of a localisation verdict code --
    the only strings a filing may use for the verdict."""
    if verdict == LOC_LOCALISED:
        return String("LOCALISED")
    if verdict == LOC_COMPARATOR_ARTIFACT:
        return String("COMPARATOR_ARTIFACT")
    if verdict == LOC_NOT_GRADED:
        return String("NOT_GRADED")
    return String("NO_DIVERGENCE")


def probe_line(index: Int, probe: Probe) raises -> String:
    """One probe as one filed line, with its A-111
    gate class named."""
    var cls = gate_step_class(probe.rank, probe.gap_milli)
    var cls_name = String("EXACT")
    if cls == BAND_STEP_NEAR_TIE:
        cls_name = String("NEAR_TIE")
    elif cls == BAND_STEP_DIVERGENT:
        cls_name = String("DIVERGENT")
    var s = String("LOC_PROBE index=") + String(index)
    s += String(" layer=") + String(probe.layer)
    s += String(" op=") + probe.op
    s += String(" rank=") + String(probe.rank)
    s += String(" gap_milli=") + String(probe.gap_milli)
    s += String(" class=") + cls_name
    return s


def localisation_render(
    read loc: Localisation, probes: List[Probe]
) raises -> String:
    """The localisation as filed text: header, one
    line per probe in execution order, the verdict
    line. This is the text the digest covers and the
    bench emits for the seeded demonstration."""
    var s = String("A116_LOCALISATION probes=") + String(len(probes))
    s += String("\n")
    for i in range(len(probes)):
        s += probe_line(i, probes[i]) + String("\n")
    s += String("A116_VERDICT verdict=")
    s += localisation_verdict_name(loc.verdict)
    s += String(" kind=") + artifact_kind_name(loc.kind)
    s += String(" first_index=") + String(loc.first_index)
    s += String(" first_layer=") + String(loc.first_layer)
    s += String(" first_op=")
    if loc.first_op.byte_length() == 0:
        s += String("-")
    else:
        s += loc.first_op
    s += String(" exact=") + String(loc.exact_count)
    s += String(" near_tie=") + String(loc.near_tie_count)
    s += String(" divergent=") + String(loc.divergent_count)
    return s


def localisation_line() -> String:
    """The localiser's one-line statement, for doctor /
    filing surfaces that quote what the tool does."""
    return String(
        "A-116 first-divergence localisation: a failing"
        " row that passes A-112's checklist is walked in"
        " execution order and the first probe outside"
        " A-111's near-tie band files its layer/op;"
        " comparator artifacts file no location"
    )
