"""Prefill/decode overlap: pipeline planning, stall accounting,
and the accounted worth-building rule (Janas road J-057).

The roadmap text: "While the GPU reads the next prompt block,
the CPU prepares what follows; pipeline stalls measured and
removed where real." In Aesir's terms the shape is a two-stage
pipeline over prompt chunks: stage C (compute) runs chunk i on
the accelerator while stage P (preparation) readies chunk i+1
on the CPU -- the next chunk's token slice, its launch/bounds
arithmetic, and any staging the executor needs. This slice
grades that shape the way J-056 graded the split: the
accounting first, under a rule registered before any filed
shape was run through it, and the live leg deferred with its
recipe (docs/janas/J057_PREFILL_DECODE_OVERLAP.md).

HOW THIS DIFFERS FROM J-056's S1 (stated once, binding on
citations). S1 pipelines two COMPUTE halves of one chunk
across two devices (GPU first half || CPU second half of the
previous chunk). This module pipelines PREPARATION against
COMPUTE: the CPU work it accounts is not layer maths, it is
the per-chunk readying work around the maths. The two compose
in principle; neither verdict lends to the other, and J-056's
accounted rejection of the split stands untouched by anything
here.

THE TWO SCHEDULES (exact pipeline arithmetic, in whatever
consistent units the caller states -- measured nanoseconds
when a live leg supplies them, operation counts when it
cannot; the module never converts between kinds). Each chunk
carries one preparation bundle, paid before that chunk's
compute in the SEQUENTIAL schedule:

    sequential_total = sum(compute_i) + chunks * (movable
                       + unmovable)

Preparation splits by DEPENDENCE, stated by the caller from
the tree (the slice doc's inventory grades every real item):
movable prep depends only on data known before the previous
chunk finishes (the prompt's token ids are all known up
front -- every surface tokenises the whole prompt/turn
before its chunk loop), so in the OVERLAPPED schedule chunk
i+1's movable prep runs during chunk i's compute; unmovable
prep depends on the previous chunk's output or is the
boundary synchronisation itself, so it is exposed in BOTH
schedules. Chunk 0's movable prep can never hide (pipeline
fill: nothing precedes it). Every internal boundary therefore
hides exactly

    hidden_per_boundary = min(movable, full_chunk_compute)

-- the overlap gain is bounded by min(prep, compute) per
chunk, as the roadmap's shape requires -- and the overlapped
schedule is

    overlapped_total = sequential_total - hidden_total
    exposed_stall(overlapped) = prep_total - hidden_total

where a full chunk's compute is chunk_width x
compute_units_per_token (every chunk before the final one is
full width, so every internal boundary hides behind a full
chunk; the ragged final chunk's own smaller compute hides
nothing after it inside the prompt -- the prefill-to-decode
boundary is accounted separately, below).

THE WORTH-BUILDING RULE, PRE-REGISTERED (stated here and in
the slice doc before the filed shapes were run through it).
An overlap SURVIVES ACCOUNTING only if all of these hold:
(a) at least two chunks exist (a single-chunk prompt has no
internal boundary -- NO_BOUNDARY, a rejection of shape, not
of effort); (b) movable prep per boundary is non-zero
(NOTHING_TO_HIDE otherwise -- the honest verdict when the
inter-chunk gap contains no readying work, which the slice
doc's inspection shows is Aesir's position tonight for the
shapes that exist); and (c) the hidden fraction of the
sequential total reaches the road's standing margin,
hidden_basis_points >= 1000 (10%, the J-040/J-043
margin discipline), computed as hidden_total x 10000 //
sequential_total, floored. Below the margin the verdict is
REJECTED_BELOW_MARGIN: the pipeline machinery (a second
host thread, a ready handshake, double-buffered staging)
costs more complexity than a sub-margin hiding can repay,
exactly as J-040 keeps a default that no measured winner
beat by the margin. The rule grades the UNITS IT IS GIVEN:
applied to operation counts it is a bound argument (the doc
states the sensitivity sweep that makes the filed verdict
insensitive to the count-to-time exchange rate), and only a
live leg's measured nanoseconds can promote an accounted
survival into a wall claim -- or reopen a rejection, under
the same margin with round separation, per the deferred
recipe.

THE PREFILL-TO-DECODE BOUNDARY (plan_decode_boundary). One
boundary per prompt, not one per chunk: the final chunk's
compute can hide the decode step's movable preparation
(sampler static state is in fact set before prefill on every
surface tonight -- hoisted, doc section 2 -- so the caller
states what movable decode prep actually remains), while
the decode step's INPUT (the sampled token) depends on the
final chunk's logits and is unmovable by construction. Its
hidden share is graded against the whole prompt's
sequential total, so a long prompt cannot dress a one-off
hiding as a pipeline.

This module is the planning/accounting layer in the
J-031/J-053/J-054/J-055/J-056 style: pure arithmetic, no
device calls, nothing timed, no speed claimed. It builds no
executor: the GPU block chunk loop it would pipeline inside
is J-054's M5, unbuilt, and the host chunk loop it inspected
runs compute and preparation on the SAME cores, where
"overlap" without a second resource is core theft, not a
pipeline (doc section 2).

HOST CONTRACT: the caller derives chunk width and prompt
length from the run's own discipline (host cap 256 default,
J-053), compute_units_per_token from J-053's accounting for
the same shape (projection MACs per token; attention stated
separately or folded in by the caller -- excluding it
understates compute and therefore OVERSTATES the hidden
fraction, the conservative direction for a rejection), and
the movable/unmovable split from the slice doc's graded
inventory for the surface it runs. Garbage inputs are
refused where detectable (non-positive shapes, negative
prep). Faithfulness grading for any live leg is the road's
raw-oracle discipline: ids first, then teacher-forcing rank
+ logit gap against a CPU comparator on the raw prompt;
never llama-cli --single-turn.
"""

# Worth-building verdicts for evaluate_overlap_accounting.
comptime OVERLAP_SURVIVES = 0
comptime OVERLAP_REJECTED_BELOW_MARGIN = 1
comptime OVERLAP_REJECTED_NOTHING_TO_HIDE = 2
comptime OVERLAP_NO_BOUNDARY = 3

# The standing margin: a hidden fraction below 10% of the
# sequential total does not repay the pipeline machinery
# (J-040/J-043 margin discipline, carried into this rule
# before any filed shape was graded).
comptime OVERLAP_MARGIN_BASIS_POINTS = 1000


struct OverlapPlan(Copyable, ImplicitlyCopyable):
    """One prompt's prefill-overlap account at one chunk
    width: both schedules' totals and stalls, the hidden
    total, and its basis-point share of the sequential
    total, all in the caller's stated units."""

    var prompt_tokens: Int
    var chunk_width: Int
    var chunks: Int
    var final_chunk_width: Int
    var boundaries: Int
    var compute_units_per_token: Int
    var full_chunk_compute: Int
    var compute_total: Int
    var movable_prep_per_chunk: Int
    var unmovable_prep_per_chunk: Int
    var prep_total: Int
    var hidden_per_boundary: Int
    var hidden_total: Int
    var sequential_total: Int
    var overlapped_total: Int
    var sequential_stall: Int
    var overlapped_stall: Int
    var hidden_basis_points: Int

    def __init__(
        out self,
        prompt_tokens: Int,
        chunk_width: Int,
        chunks: Int,
        final_chunk_width: Int,
        boundaries: Int,
        compute_units_per_token: Int,
        full_chunk_compute: Int,
        compute_total: Int,
        movable_prep_per_chunk: Int,
        unmovable_prep_per_chunk: Int,
        prep_total: Int,
        hidden_per_boundary: Int,
        hidden_total: Int,
        sequential_total: Int,
        overlapped_total: Int,
        sequential_stall: Int,
        overlapped_stall: Int,
        hidden_basis_points: Int,
    ):
        self.prompt_tokens = prompt_tokens
        self.chunk_width = chunk_width
        self.chunks = chunks
        self.final_chunk_width = final_chunk_width
        self.boundaries = boundaries
        self.compute_units_per_token = compute_units_per_token
        self.full_chunk_compute = full_chunk_compute
        self.compute_total = compute_total
        self.movable_prep_per_chunk = movable_prep_per_chunk
        self.unmovable_prep_per_chunk = unmovable_prep_per_chunk
        self.prep_total = prep_total
        self.hidden_per_boundary = hidden_per_boundary
        self.hidden_total = hidden_total
        self.sequential_total = sequential_total
        self.overlapped_total = overlapped_total
        self.sequential_stall = sequential_stall
        self.overlapped_stall = overlapped_stall
        self.hidden_basis_points = hidden_basis_points


def plan_prefill_overlap(
    prompt_tokens: Int,
    chunk_width: Int,
    compute_units_per_token: Int,
    movable_prep_per_chunk: Int,
    unmovable_prep_per_chunk: Int,
) raises -> OverlapPlan:
    """Account one prompt's chunk pipeline under both
    schedules. movable/unmovable prep are per-chunk figures
    in the same units as compute (the doc's inventory grades
    which real items belong to each bucket per surface).
    Compute is per-token x tokens, exact for any ragged final
    chunk; every internal boundary hides behind a full chunk,
    so hidden_per_boundary = min(movable, full_chunk_compute).
    """
    if prompt_tokens <= 0 or chunk_width <= 0:
        raise Error("PrefillOverlap: token count and chunk width must be positive")
    if compute_units_per_token <= 0:
        raise Error("PrefillOverlap: compute per token must be positive")
    if movable_prep_per_chunk < 0 or unmovable_prep_per_chunk < 0:
        raise Error("PrefillOverlap: prep units must be >= 0")
    var chunks = (prompt_tokens + chunk_width - 1) // chunk_width
    var final_width = prompt_tokens - (chunks - 1) * chunk_width
    var boundaries = chunks - 1
    var full_compute = chunk_width * compute_units_per_token
    var compute_total = prompt_tokens * compute_units_per_token
    var prep_total = chunks * (movable_prep_per_chunk + unmovable_prep_per_chunk)
    var hidden_per = movable_prep_per_chunk
    if full_compute < hidden_per:
        hidden_per = full_compute
    var hidden_total = boundaries * hidden_per
    var sequential_total = compute_total + prep_total
    return OverlapPlan(
        prompt_tokens,
        chunk_width,
        chunks,
        final_width,
        boundaries,
        compute_units_per_token,
        full_compute,
        compute_total,
        movable_prep_per_chunk,
        unmovable_prep_per_chunk,
        prep_total,
        hidden_per,
        hidden_total,
        sequential_total,
        sequential_total - hidden_total,
        prep_total,
        prep_total - hidden_total,
        hidden_total * 10000 // sequential_total,
    )


def overlap_staging_bytes(chunk_width: Int, id_bytes: Int) raises -> Int:
    """Bytes of token-id staging one chunk's movable slice
    occupies (chunk_width ids at the caller's stated id
    size). The countable size of the one movable item every
    surface shares; priced so the doc's filed application
    rests on a stated figure, not a gesture."""
    if chunk_width <= 0 or id_bytes <= 0:
        raise Error("PrefillOverlap: staging shape must be positive")
    return chunk_width * id_bytes


struct OverlapVerdict(Copyable, ImplicitlyCopyable):
    """The pre-registered worth-building rule, applied."""

    var verdict: Int
    var hidden_basis_points: Int

    def __init__(out self, verdict: Int, hidden_basis_points: Int):
        self.verdict = verdict
        self.hidden_basis_points = hidden_basis_points

    def verdict_name(self) -> String:
        if self.verdict == OVERLAP_SURVIVES:
            return String("survives_accounting")
        if self.verdict == OVERLAP_NO_BOUNDARY:
            return String("no_boundary_single_chunk")
        if self.verdict == OVERLAP_REJECTED_NOTHING_TO_HIDE:
            return String("rejected_nothing_to_hide")
        return String("rejected_below_margin")


def evaluate_overlap_accounting(plan: OverlapPlan) -> OverlapVerdict:
    """Apply the pre-registered rule to one plan, in the
    plan's own units: no boundary -> NO_BOUNDARY; no movable
    prep -> NOTHING_TO_HIDE; hidden share at or above the
    10% margin -> SURVIVES; otherwise BELOW_MARGIN."""
    if plan.chunks < 2:
        return OverlapVerdict(OVERLAP_NO_BOUNDARY, plan.hidden_basis_points)
    if plan.movable_prep_per_chunk == 0:
        return OverlapVerdict(
            OVERLAP_REJECTED_NOTHING_TO_HIDE, plan.hidden_basis_points
        )
    if plan.hidden_basis_points >= OVERLAP_MARGIN_BASIS_POINTS:
        return OverlapVerdict(OVERLAP_SURVIVES, plan.hidden_basis_points)
    return OverlapVerdict(
        OVERLAP_REJECTED_BELOW_MARGIN, plan.hidden_basis_points
    )


struct DecodeBoundaryPlan(Copyable, ImplicitlyCopyable):
    """The single prefill-to-decode boundary of one prompt:
    what the final chunk's compute can hide of the decode
    step's preparation, graded against the whole prompt's
    sequential total (supplied by the caller from
    plan_prefill_overlap or a filed equivalent)."""

    var final_chunk_compute: Int
    var movable_decode_prep: Int
    var unmovable_decode_prep: Int
    var hidden: Int
    var sequential_stall: Int
    var overlapped_stall: Int
    var hidden_basis_points: Int

    def __init__(
        out self,
        final_chunk_compute: Int,
        movable_decode_prep: Int,
        unmovable_decode_prep: Int,
        hidden: Int,
        sequential_stall: Int,
        overlapped_stall: Int,
        hidden_basis_points: Int,
    ):
        self.final_chunk_compute = final_chunk_compute
        self.movable_decode_prep = movable_decode_prep
        self.unmovable_decode_prep = unmovable_decode_prep
        self.hidden = hidden
        self.sequential_stall = sequential_stall
        self.overlapped_stall = overlapped_stall
        self.hidden_basis_points = hidden_basis_points


def plan_decode_boundary(
    final_chunk_width: Int,
    compute_units_per_token: Int,
    movable_decode_prep: Int,
    unmovable_decode_prep: Int,
    sequential_prompt_total: Int,
) raises -> DecodeBoundaryPlan:
    """Account the prefill-to-decode boundary: hidden =
    min(movable decode prep, final chunk compute); the
    sampled-token input itself is unmovable by construction
    and rides in unmovable_decode_prep, exposed in both
    schedules. sequential_prompt_total is the prompt's whole
    sequential total in the same units, so the one-off
    hiding is graded at prompt scale, never chunk scale."""
    if final_chunk_width <= 0 or compute_units_per_token <= 0:
        raise Error("PrefillOverlap: decode boundary shape must be positive")
    if movable_decode_prep < 0 or unmovable_decode_prep < 0:
        raise Error("PrefillOverlap: decode prep units must be >= 0")
    if sequential_prompt_total <= 0:
        raise Error("PrefillOverlap: sequential prompt total must be positive")
    var final_compute = final_chunk_width * compute_units_per_token
    var hidden = movable_decode_prep
    if final_compute < hidden:
        hidden = final_compute
    var seq_stall = movable_decode_prep + unmovable_decode_prep
    return DecodeBoundaryPlan(
        final_compute,
        movable_decode_prep,
        unmovable_decode_prep,
        hidden,
        seq_stall,
        seq_stall - hidden,
        hidden * 10000 // sequential_prompt_total,
    )
