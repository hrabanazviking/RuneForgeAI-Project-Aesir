"""NPU prompt: the preparation account (Janas road J-061).

The roadmap text: "How an NPU prompt pass would bind into
Aesir: which weights it would take (8-bit copies with
per-row scales, from Janas's documented behaviour), which
passes it may never take (reply, draft-check), the
preparation pass and its progress surface. Design only --
the chip is parked."

This module is the host-side accounting half of that
design (docs/janas/J061_NPU_PROMPT_DESIGN.md is its
normative text). It prices, in exact bytes and counts,
the one-time preparation an NPU prompt pass needs before
it may read a single prompt token, and it refuses -- by
construction, at plan time -- every pass the NPU may
never take. It executes nothing, opens no device, probes
no chip, and contains no speed. The NPU executor it
specifies does not exist (the slice doc's N-items are the
build list), and Aesir's only NPU ledger entry -- the
Hailo on the finish-line road -- stays parked and
untouched by everything here: this account is
silicon-agnostic at the placement layer and binds to
neither the census's Intel/OpenVINO stack nor the
Hailo's compiler.

GROUND (the census, J-004, from Janas's public
documentation only; no Janas source was opened):

- The NPU takes prompt blocks of >= 64 tokens. Never a
  reply token, never a draft check. (Aesir's placement
  surface already refuses the NPU for those pass kinds
  at parse time -- core/placement_options.mojo; this
  module's plan gate repeats the refusal fail-closed at
  preparation time, so no caller can reach a copy plan
  for a forbidden pass even by bypassing the parser.)
- Three placements exist in the documented behaviour:
  DENSE_WHOLE (a dense model whose layers fit goes layer
  by layer, whole), SPLIT_BLOCK (each prompt block in
  two halves: the NPU computes a layer on one half while
  the CPU computes attention -- or the recurrence -- on
  the other; leftover layers stay on the CPU), and
  RESIDENT_PRODUCTS (larger and MoE models give the NPU
  the products of the weights that stay in memory --
  attention, recurrent layers, shared experts; routed
  experts stay on CPU/GPU).
- NPU weights are 8-bit copies with a per-row scale,
  computed in f16, norms in f32. An optional 8-bit
  activation mode exists on dense Qwen3 (faster, less
  exact) -- recorded here as a plan flag, dense forms
  only, default off, separately graded (below).
- Preparation is one-time per session: the copies plus
  graph compilation, with progress reported on the chat
  status line in the shape "preparing the NPU 12/25,
  8 s"; compiled graphs are cached, so a later open
  prepares faster. The bench prepares before measuring.
- Where the expert cache cannot hold the feed-forward
  weights, the NPU stays closed unless the prompt option
  names it: its copies' memory is the cache's memory.
  That contention is J-048's rule in this road's planner
  (core/placement_pressure.mojo, rule 3: duplicate
  copies are cache-class unless a hand names them);
  evaluate_npu_contention below is that planner applied
  to this slice's copy charge, not a second rule.

THE COPY ACCOUNT. For one weight matrix of R rows x C
columns, the NPU copy is R*C payload bytes (one 8-bit
value per element) plus R scale values, one per row.
The census states the per-row scale and the f16 compute
but not the scale's stored width; answered locally
(slice doc): the scale is stored as f16, 2 bytes per
row. Norm vectors are NEVER part of the 8-bit copies:
they are carried at f32 (4 bytes per element) beside
them, exactly as the census's "norms in f32" states.
The caller states the copy set as aggregate elements +
rows over exactly the matrices its form takes (the doc
names the set per form; embedding and the LM head are
never in it -- answered locally), and the norm set as
an element count, so the account prices stated inputs
and invents no directory facts.

THE PREPARATION PROGRESS ACCOUNT. Preparation is
accounted in units: one graph per layer the NPU takes.
Its progress discipline MIRRORS J-059's prompt-progress
account (core/prompt_progress.mojo) in record shape and
in rules R2--R5 -- boundary-only (a unit completes, then
a record may speak), a 10% step throttle (at most 10
records at any unit count), the final record exactly
once, never a unit not yet prepared -- but ADAPTS R1:
J-059's watched bound is a prompt-read bound (>= 1024
tokens), and preparation is not a prompt read. The
census's own documented behaviour reports preparation
at 25 units ("12/25"), which a literal token bound
would silence; the preparation bound is therefore
>= PREP_MIN_UNITS (4) units, recorded as an
answered-locally adaptation in the slice doc, not a
silent divergence. The render form follows the census's
documented status line, not J-059's prompt-read line:
"preparing the NPU <done>/<total>", with ", <s> s"
appended when the caller supplies elapsed seconds --
the record never invents a time. No live surface
consumes this account yet (the doc's N4); the wiring
rides with the executor.

THE CONTENTION VERDICT. evaluate_npu_contention charges
the preparation FOOTPRINT (8-bit copies + f32 norm
carriage -- both occupy the contested pool) as
J-048's duplicate copy against a stated pool, through
plan_placement_pressure itself: an automatic copy that
would take the cache below its floor is CLOSED (the
cache keeps its bytes; the originals remain, so closing
loses an accelerator copy, never the weights); a
hand-named copy charges as fixed, and where that leaves
a required cache below its floor the verdict is
REFUSED -- J-047's whole-refusal shape, never an
override. The verdict struct carries the planner's own
decision and cache target so a filing quotes the
planner, not a paraphrase.

FAITHFULNESS DEBT (stated here so no caller mistakes an
accounted plan for a graded one): every NPU form enters
J-060's battery matrix as NOT_GRADED. The 8-bit copies
are an approximation by construction; the pass bar is
the road's raw-oracle discipline -- ids first against
the host reference form, then teacher-forcing rank +
logit gap against the ggml CPU comparator on the raw
prompt (never llama-cli --single-turn), near-tie band
rank <= 2 with sub-logit gap = faithful. The census's
published agreement figures are Janas's evidence on
Janas's engine; they grade nothing here.

HOST CONTRACT: a surface opening a session (1) resolves
placement (J-036 options, J-047 supremacy) and inventory
(J-037 -- tonight its NPU entry is parked/not-probed,
which is itself the refusal reason until the gate
opens), (2) derives the copy set from the opened file's
directory (per-form matrix sets in the slice doc), (3)
calls plan_npu_prompt_prep for the prompt pass it
intends, (4) charges the plan's footprint through
evaluate_npu_contention per contested pool and follows
the verdict (CLOSED: no preparation, the pass runs
where it ran; REFUSED: the open stops with the numbers
stated), and (5) only then prepares, reporting through
this module's progress account. This slice wires the
module into NO live path: no session consumes it, and
claiming otherwise would fake the integration.
"""

from core.placement_options import PASS_DRAFTS, PASS_PROMPT, PASS_REPLY
from core.placement_pressure import (
    CONTENTION_FULL,
    CONTENTION_NO_CACHE,
    CONTENTION_REFUSE,
    CONTENTION_SHRUNK,
    plan_placement_pressure,
)

# The census's NPU prompt floor: prompt blocks of at
# least this many tokens. Aesir's general prompt band
# starts at 17 (J-003/J-035); the NPU's own floor is 64.
comptime NPU_MIN_PROMPT_TOKENS = 64

# The copy account's byte rates (census + the one
# answered-locally storage choice, stated above).
comptime NPU_PAYLOAD_BYTES_PER_ELEMENT = 1
comptime NPU_SCALE_BYTES_PER_ROW = 2
comptime NPU_NORM_BYTES_PER_ELEMENT = 4

# The three documented placements (census J-004).
comptime NPU_FORM_DENSE_WHOLE = 0
comptime NPU_FORM_SPLIT_BLOCK = 1
comptime NPU_FORM_RESIDENT_PRODUCTS = 2

# The preparation progress bound (the R1 adaptation).
comptime PREP_MIN_UNITS = 4
comptime PREP_STEP_BASIS_POINTS = 1000

# Contention verdicts for evaluate_npu_contention.
comptime NPU_CONTENTION_ADMITTED = 0
comptime NPU_CONTENTION_CLOSED = 1
comptime NPU_CONTENTION_REFUSED = 2


def npu_form_name(form: Int) -> String:
    if form == NPU_FORM_SPLIT_BLOCK:
        return String("split_block")
    if form == NPU_FORM_RESIDENT_PRODUCTS:
        return String("resident_products")
    return String("dense_whole")


def npu_contention_name(verdict: Int) -> String:
    if verdict == NPU_CONTENTION_CLOSED:
        return String("closed")
    if verdict == NPU_CONTENTION_REFUSED:
        return String("refused")
    return String("admitted")


struct NpuWeightCopy(Copyable, ImplicitlyCopyable):
    """One copy set's exact price: payload (8-bit values),
    per-row scales (f16), and their sum."""

    var weight_elements: Int
    var weight_rows: Int
    var payload_bytes: Int
    var scale_bytes: Int
    var copy_bytes: Int

    def __init__(
        out self,
        weight_elements: Int,
        weight_rows: Int,
        payload_bytes: Int,
        scale_bytes: Int,
        copy_bytes: Int,
    ):
        self.weight_elements = weight_elements
        self.weight_rows = weight_rows
        self.payload_bytes = payload_bytes
        self.scale_bytes = scale_bytes
        self.copy_bytes = copy_bytes


def plan_npu_weight_copy(
    weight_elements: Int, weight_rows: Int
) raises -> NpuWeightCopy:
    """Price one 8-bit copy set from its aggregate shape:
    one payload byte per element, one f16 scale per row.
    Every row carries at least one element, so a row
    count above the element count is a broken directory
    fact, refused rather than priced."""
    if weight_elements <= 0 or weight_rows <= 0:
        raise Error("NpuPromptPrep: copy set shape must be positive")
    if weight_rows > weight_elements:
        raise Error("NpuPromptPrep: copy set has more rows than elements")
    var payload = weight_elements * NPU_PAYLOAD_BYTES_PER_ELEMENT
    var scales = weight_rows * NPU_SCALE_BYTES_PER_ROW
    return NpuWeightCopy(
        weight_elements, weight_rows, payload, scales, payload + scales
    )


struct NpuPromptPrepPlan(Copyable, ImplicitlyCopyable):
    """One prompt pass's preparation account: the form,
    the layer split, the copy set's price, the f32 norm
    carriage, the total footprint a contention plan must
    charge, the preparation units and their progress
    shape, and what a cold open must actually write
    (zero when the graph cache hits -- the footprint is
    charged either way, because the copies occupy the
    pool whether they were built tonight or cached)."""

    var form: Int
    var prompt_tokens: Int
    var layers_total: Int
    var layers_on_npu: Int
    var layers_leftover: Int
    var copy_set: NpuWeightCopy
    var norm_elements: Int
    var norm_bytes: Int
    var footprint_bytes: Int
    var prep_units: Int
    var prep_watched: Bool
    var prep_records_expected: Int
    var graph_cache_hit: Bool
    var prep_bytes_to_write: Int
    var activations_int8: Bool

    def __init__(
        out self,
        form: Int,
        prompt_tokens: Int,
        layers_total: Int,
        layers_on_npu: Int,
        layers_leftover: Int,
        copy_set: NpuWeightCopy,
        norm_elements: Int,
        norm_bytes: Int,
        footprint_bytes: Int,
        prep_units: Int,
        prep_watched: Bool,
        prep_records_expected: Int,
        graph_cache_hit: Bool,
        prep_bytes_to_write: Int,
        activations_int8: Bool,
    ):
        self.form = form
        self.prompt_tokens = prompt_tokens
        self.layers_total = layers_total
        self.layers_on_npu = layers_on_npu
        self.layers_leftover = layers_leftover
        self.copy_set = copy_set
        self.norm_elements = norm_elements
        self.norm_bytes = norm_bytes
        self.footprint_bytes = footprint_bytes
        self.prep_units = prep_units
        self.prep_watched = prep_watched
        self.prep_records_expected = prep_records_expected
        self.graph_cache_hit = graph_cache_hit
        self.prep_bytes_to_write = prep_bytes_to_write
        self.activations_int8 = activations_int8


def _prep_boundary_bp(total_units: Int, units_done: Int) -> Int:
    """Floored basis-point fraction prepared at a unit
    boundary (J-059's arithmetic, mirrored)."""
    return units_done * 10000 // total_units


def npu_prep_boundary_emits(
    total_units: Int, units_done: Int
) raises -> Bool:
    """The preparation discipline at one unit boundary:
    unwatched preparations never emit; the final unit
    always emits; any other unit emits iff it crosses
    the next 10% step the previous unit had not reached
    (J-059 R2--R4 with the adapted R1 bound). A boundary
    outside the preparation is refused."""
    if total_units <= 0:
        raise Error("NpuPromptPrep: preparation units must be positive")
    if units_done < 1 or units_done > total_units:
        raise Error("NpuPromptPrep: boundary outside the preparation")
    if total_units < PREP_MIN_UNITS:
        return False
    if units_done == total_units:
        return True
    var step_now = (
        _prep_boundary_bp(total_units, units_done) // PREP_STEP_BASIS_POINTS
    )
    var step_prev = (
        _prep_boundary_bp(total_units, units_done - 1)
        // PREP_STEP_BASIS_POINTS
    )
    return step_now > step_prev


def npu_prep_records_expected(total_units: Int) raises -> Int:
    """Exactly how many records the discipline emits for
    a preparation of total_units units, computed by
    walking the boundaries once -- so a surface can
    state the count before preparation starts."""
    if total_units <= 0:
        raise Error("NpuPromptPrep: preparation units must be positive")
    var records = 0
    for k in range(1, total_units + 1):
        if npu_prep_boundary_emits(total_units, k):
            records += 1
    return records


def render_npu_prep_line(
    units_done: Int, total_units: Int, elapsed_seconds: Int = -1
) -> String:
    """The status-line form of one preparation record,
    in the census's documented shape ("preparing the
    NPU 12/25, 8 s"). The elapsed figure rides only when
    the caller supplies one (>= 0); -1 states none was
    supplied -- the record never invents a time.
    Callers render only boundaries that emit."""
    var line = (
        String("preparing the NPU ")
        + String(units_done)
        + String("/")
        + String(total_units)
    )
    if elapsed_seconds >= 0:
        line += String(", ") + String(elapsed_seconds) + String(" s")
    return line


def plan_npu_prompt_prep(
    pass_kind: Int,
    prompt_tokens: Int,
    form: Int,
    layers_total: Int,
    layers_on_npu: Int,
    weight_elements: Int,
    weight_rows: Int,
    norm_elements: Int,
    graph_cache_hit: Bool,
    activations_int8: Bool,
) raises -> NpuPromptPrepPlan:
    """Account one NPU prompt pass's preparation.

    The refusals ARE the design's pass law, in order:
    a pass kind other than PASS_PROMPT is refused by
    construction (the NPU never takes a reply pass and
    never takes a draft-check pass -- there is no plan
    shape for them to return); a prompt below the
    census's 64-token NPU floor is refused for the NPU
    (the pass itself runs on CPU/GPU -- this planner
    only refuses to prepare the NPU for it); the
    dense-whole form with layers left over is refused
    (a partial dense model is the split-block or
    resident-products form, and must be named as such);
    8-bit activations on the resident-products form are
    refused (the census documents that mode on dense
    models only). weight_elements / weight_rows state
    the form's copy set in aggregate (the slice doc
    names the matrices per form); norm_elements states
    the f32-carried norm vectors for the same layers.
    """
    if pass_kind == PASS_REPLY:
        raise Error(
            "NpuPromptPrep: the NPU never takes a reply pass"
            " (refused by construction)"
        )
    if pass_kind == PASS_DRAFTS:
        raise Error(
            "NpuPromptPrep: the NPU never takes a draft-check pass"
            " (refused by construction)"
        )
    if pass_kind != PASS_PROMPT:
        raise Error("NpuPromptPrep: unknown pass kind")
    if prompt_tokens < NPU_MIN_PROMPT_TOKENS:
        raise Error(
            "NpuPromptPrep: an NPU prompt pass takes at least 64"
            " tokens (the census floor); shorter prompts are not"
            " refused as passes -- they are not prepared for the NPU"
        )
    if (
        form != NPU_FORM_DENSE_WHOLE
        and form != NPU_FORM_SPLIT_BLOCK
        and form != NPU_FORM_RESIDENT_PRODUCTS
    ):
        raise Error("NpuPromptPrep: unknown NPU form")
    if layers_total <= 0 or layers_on_npu <= 0 or layers_on_npu > layers_total:
        raise Error("NpuPromptPrep: layer split out of range")
    if form == NPU_FORM_DENSE_WHOLE and layers_on_npu != layers_total:
        raise Error(
            "NpuPromptPrep: dense-whole takes every layer; a partial"
            " dense model is split_block or resident_products"
        )
    if activations_int8 and form == NPU_FORM_RESIDENT_PRODUCTS:
        raise Error(
            "NpuPromptPrep: 8-bit activations are documented on dense"
            " models only, not on the resident-products form"
        )
    if norm_elements < 0:
        raise Error("NpuPromptPrep: norm element count out of range")
    var priced = plan_npu_weight_copy(weight_elements, weight_rows)
    var norm_bytes = norm_elements * NPU_NORM_BYTES_PER_ELEMENT
    var footprint = priced.copy_bytes + norm_bytes
    var units = layers_on_npu
    var watched = units >= PREP_MIN_UNITS
    var records = npu_prep_records_expected(units)
    var to_write = 0 if graph_cache_hit else footprint
    return NpuPromptPrepPlan(
        form,
        prompt_tokens,
        layers_total,
        layers_on_npu,
        layers_total - layers_on_npu,
        priced,
        norm_elements,
        norm_bytes,
        footprint,
        units,
        watched,
        records,
        graph_cache_hit,
        to_write,
        activations_int8,
    )


struct NpuContentionVerdict(Copyable, ImplicitlyCopyable):
    """J-048's contention decision for one preparation
    footprint, restated in this slice's verdict words
    with the planner's own fields carried verbatim:
    decision is the planner's CONTENTION_* code,
    cache_target_bytes its cache target, copy_closed its
    closure flag, headroom its unheld pool bytes."""

    var verdict: Int
    var decision: Int
    var copy_charged_bytes: Int
    var copy_closed: Bool
    var cache_target_bytes: Int
    var headroom_bytes: Int

    def __init__(
        out self,
        verdict: Int,
        decision: Int,
        copy_charged_bytes: Int,
        copy_closed: Bool,
        cache_target_bytes: Int,
        headroom_bytes: Int,
    ):
        self.verdict = verdict
        self.decision = decision
        self.copy_charged_bytes = copy_charged_bytes
        self.copy_closed = copy_closed
        self.cache_target_bytes = cache_target_bytes
        self.headroom_bytes = headroom_bytes


def evaluate_npu_contention(
    pool_bytes: Int,
    placement_fixed_bytes: Int,
    reserve_bytes: Int,
    cache_open_bytes: Int,
    cache_floor_bytes: Int,
    largest_pair_bytes: Int,
    expert_body_bytes: Int,
    footprint_bytes: Int,
    copy_is_manual: Bool,
    cache_required: Bool,
) raises -> NpuContentionVerdict:
    """Charge one preparation footprint as J-048's
    duplicate copy in one contested pool, through
    plan_placement_pressure itself (the governing hand,
    if any, is the caller's J-047 resolution: a copy a
    hand names arrives here as copy_is_manual). Mapping:
    the planner's REFUSE is REFUSED; a closed automatic
    copy is CLOSED whatever the cache then does; anything
    else is ADMITTED with the planner's cache target
    (which may be a degraded zero for an optional cache
    beside a hand-named copy -- the copy stands, the
    cache yields, exactly J-048 rule 4)."""
    if footprint_bytes <= 0:
        raise Error("NpuPromptPrep: contention footprint must be positive")
    var plan = plan_placement_pressure(
        pool_bytes,
        placement_fixed_bytes,
        reserve_bytes,
        cache_open_bytes,
        cache_floor_bytes,
        largest_pair_bytes,
        expert_body_bytes,
        footprint_bytes,
        copy_is_manual,
        cache_required,
        False,
    )
    var verdict = NPU_CONTENTION_ADMITTED
    if plan.decision == CONTENTION_REFUSE:
        verdict = NPU_CONTENTION_REFUSED
    elif plan.copy_closed:
        verdict = NPU_CONTENTION_CLOSED
    return NpuContentionVerdict(
        verdict,
        plan.decision,
        plan.copy_charged_bytes,
        plan.copy_closed,
        plan.cache_target_bytes,
        plan.headroom_bytes(),
    )
