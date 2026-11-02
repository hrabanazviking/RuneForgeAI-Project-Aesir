"""Split prompt: block-halves planning, join accounting, and the
accounted survival rule (Janas road J-056).

The roadmap text: "The prompt pass split by block halves across
GPU and CPU concurrently (Janas's NPU split, generalised): the
join cost measured, kept only where it wins." Janas documents
the split for its NPU (dense layers split by block with the CPU,
census J-004, behaviour only); this slice generalises the shape
to Aesir's GPU+CPU pair and grades it under Aesir's laws.

HOW THIS DIFFERS FROM J-043 (stated once, binding on citations).
J-043's co-work split divides a prompt batch BY ROWS inside one
matrix product: both sides compute disjoint output rows of the
same product, no output element depends on the other side, and
the join is a gather. A BLOCK-HALVES split divides the layer
stack BY BLOCKS (layers): the GPU side runs blocks
[0, gpu_layers), the CPU side runs blocks [gpu_layers, layers).
Block k+1 consumes block k's hidden state, so the two halves
are SEQUENTIALLY DEPENDENT per token/chunk -- there is no
row-style independence inside a chunk. The only concurrency
this shape admits is PIPELINING ACROSS CHUNKS: while the CPU
side works chunk i's second half, the GPU side can start chunk
i+1's first half. What crosses is the hidden state at the one
split boundary, once per chunk -- not J-043's replicated shared
matrix and gathered output rows. J-043's accounting discipline
(join stated, never dropped; joined cost never a side's cost
alone) and its survival shape (beat BOTH parents or be
rejected) are reused; its split geometry and crossing contents
are not. The proven spill partition (J-021, core/
dense_residency.mojo) is this shape at an UNEQUAL fraction,
chosen by fit; J-056 grades the balanced-halves fraction as a
speed candidate, which is a different question.

THE SURVIVAL RULE, PRE-REGISTERED IN ACCOUNTING FORM (stated
here and in docs/janas/J056_SPLIT_PROMPT.md before any filed
shape was run through it). No wall exists on this slice (the
live leg is deferred, doc section 7), and no exchange rate
between bytes, crossings and MACs is invented to fake one. A
split therefore SURVIVES on accounting alone only if it
DOMINATES both parents: less-or-equal on every accounted axis
and strictly less on at least one, against EACH parent
separately. The axes, all exact by construction:

- total MACs (J-053: projection MACs over the prompt plus the
  caller-stated attention MACs; surface-invariant -- a split
  executes the same products as either parent);
- weight-read bytes per prompt (J-053/J-054 pass-count shape:
  each chunk re-reads the weight bytes of the blocks it runs;
  the split's sides together re-read exactly the whole stack
  per chunk, as does each parent at the same chunk width);
- synchronised crossings (whole-GPU block parent: one per
  chunk, J-055; whole-CPU/host parent: zero device crossings;
  the split: one completion sync per side per chunk PLUS one
  synchronised boundary transfer per chunk);
- join bytes (parents: zero -- nothing crosses; the split:
  prompt_tokens x hidden x elem_bytes of hidden state at the
  boundary, the join this slice exists to price).

A split that is dominated by either parent (parent <= on all
axes, < on at least one) is ACCOUNTED-AND-REJECTED: kept
nowhere, exactly the roadmap's "kept only where it wins" in
the only form accounting can honestly state it. A split whose
whole-GPU parent does not exist (the model does not fit
whole-layer, J-055's no-fit verdict) is NOT graded by this
rule at all: there the split shape is the residency fallback
(J-021's spill), recorded as PARENT-ABSENT, never as a win
and never as a rejection. Whether pipelining (above) wins in
WALL time despite dominated accounting is a measured question
this rule does not prejudge -- it is the deferred live leg's
(doc section 7), and its answer may reopen this verdict only
with measured walls under the margin+separation discipline
of J-040/J-043, never on accounting alone.

THE SPLIT GEOMETRY. gpu_layers = ceil(layers/2) (the GPU side
takes the extra block on odd counts -- the first half is the
one that must finish before anything crosses, and the boundary
position is stated in the plan either way); cpu_layers =
layers - gpu_layers. Per-side MACs split the prompt total by
layer fraction with integer floor to the GPU side and the
conservation remainder to the CPU side, so per-side MACs
always sum to the total exactly; the uniform-per-layer
assumption this encodes is stated, and hybrid shapes (Gemma
4's local/global layer classes, J-053 section 5) make it an
approximation the doc names, not an exact per-layer account.
KV writes never cross: each side writes the KV of the blocks
it owns, on its own side (bytes priced by J-053/J-087, not
re-priced here). Each side's weights are uploaded once at
open through the existing 64 MiB staging (priced in J-055);
per prompt, weight traffic is the pass-count shape above.

This module is the planning/accounting layer in the
J-031/J-053/J-054/J-055 style: pure arithmetic, no device
calls, nothing timed, no speed claimed.

HOST CONTRACT: the caller derives layers/hidden from the
model's profile, proj_macs_per_token and attn_macs_prompt
from J-053's accounting for the same shape, per-side weight
bytes from the opened file's tensor directory (the bytes of
the blocks each side owns; their sum is the whole stack's
weight bytes), elem_bytes from the hidden state's element
precision at the boundary (4 for the sessions' f32 state),
and whole_gpu_fits from J-055's plan for the same model and
context. Garbage inputs are refused where detectable (an
empty side, a one-block "split", non-positive shapes).
Faithfulness grading for any live leg is the road's
raw-oracle discipline: ids first, then teacher-forcing rank
+ logit gap against a CPU comparator on the raw prompt;
never llama-cli --single-turn.
"""

# Survival verdicts for evaluate_split_accounting.
comptime SPLIT_SURVIVES = 0
comptime SPLIT_REJECTED_DOMINATED = 1
comptime SPLIT_PARENT_ABSENT = 2


struct SplitPromptPlan(Copyable, ImplicitlyCopyable):
    """One prompt's block-halves split account (GPU first half,
    CPU second half), with both parents at the same chunk width
    stated beside it for the survival rule."""

    var prompt_tokens: Int
    var chunk_width: Int
    var chunks: Int
    var final_chunk_width: Int
    var layers: Int
    var gpu_layers: Int
    var cpu_layers: Int
    var hidden: Int
    var elem_bytes: Int
    var total_macs: Int
    var gpu_macs: Int
    var cpu_macs: Int
    var bottleneck_macs: Int
    var gpu_weight_bytes: Int
    var cpu_weight_bytes: Int
    var gpu_weight_read_bytes: Int
    var cpu_weight_read_bytes: Int
    var split_weight_read_bytes: Int
    var parent_weight_read_bytes: Int
    var gpu_side_syncs: Int
    var cpu_side_syncs: Int
    var boundary_transfers: Int
    var split_crossings: Int
    var parent_gpu_crossings: Int
    var parent_cpu_crossings: Int
    var join_bytes: Int
    var join_bytes_per_full_chunk: Int
    var whole_gpu_fits: Bool

    def __init__(
        out self,
        prompt_tokens: Int,
        chunk_width: Int,
        chunks: Int,
        final_chunk_width: Int,
        layers: Int,
        gpu_layers: Int,
        cpu_layers: Int,
        hidden: Int,
        elem_bytes: Int,
        total_macs: Int,
        gpu_macs: Int,
        cpu_macs: Int,
        bottleneck_macs: Int,
        gpu_weight_bytes: Int,
        cpu_weight_bytes: Int,
        gpu_weight_read_bytes: Int,
        cpu_weight_read_bytes: Int,
        split_weight_read_bytes: Int,
        parent_weight_read_bytes: Int,
        gpu_side_syncs: Int,
        cpu_side_syncs: Int,
        boundary_transfers: Int,
        split_crossings: Int,
        parent_gpu_crossings: Int,
        parent_cpu_crossings: Int,
        join_bytes: Int,
        join_bytes_per_full_chunk: Int,
        whole_gpu_fits: Bool,
    ):
        self.prompt_tokens = prompt_tokens
        self.chunk_width = chunk_width
        self.chunks = chunks
        self.final_chunk_width = final_chunk_width
        self.layers = layers
        self.gpu_layers = gpu_layers
        self.cpu_layers = cpu_layers
        self.hidden = hidden
        self.elem_bytes = elem_bytes
        self.total_macs = total_macs
        self.gpu_macs = gpu_macs
        self.cpu_macs = cpu_macs
        self.bottleneck_macs = bottleneck_macs
        self.gpu_weight_bytes = gpu_weight_bytes
        self.cpu_weight_bytes = cpu_weight_bytes
        self.gpu_weight_read_bytes = gpu_weight_read_bytes
        self.cpu_weight_read_bytes = cpu_weight_read_bytes
        self.split_weight_read_bytes = split_weight_read_bytes
        self.parent_weight_read_bytes = parent_weight_read_bytes
        self.gpu_side_syncs = gpu_side_syncs
        self.cpu_side_syncs = cpu_side_syncs
        self.boundary_transfers = boundary_transfers
        self.split_crossings = split_crossings
        self.parent_gpu_crossings = parent_gpu_crossings
        self.parent_cpu_crossings = parent_cpu_crossings
        self.join_bytes = join_bytes
        self.join_bytes_per_full_chunk = join_bytes_per_full_chunk
        self.whole_gpu_fits = whole_gpu_fits


def plan_split_prompt(
    prompt_tokens: Int,
    chunk_width: Int,
    layers: Int,
    hidden: Int,
    elem_bytes: Int,
    proj_macs_per_token: Int,
    attn_macs_prompt: Int,
    gpu_weight_bytes: Int,
    cpu_weight_bytes: Int,
    whole_gpu_fits: Bool,
) raises -> SplitPromptPlan:
    """Account one prompt split by block halves: GPU runs
    blocks [0, ceil(layers/2)), CPU runs the rest.

    attn_macs_prompt is the caller-stated attention MAC total
    over the whole prompt (J-053's prefill_attention_macs for
    the same shape; it is quadratic in prompt length, so it
    cannot be a per-token figure). Per-side MACs split the
    prompt total by layer fraction, floor to the GPU side,
    remainder to the CPU side: the sum is always the total.
    """
    if prompt_tokens <= 0 or chunk_width <= 0:
        raise Error("SplitPrompt: token count and chunk width must be positive")
    if layers < 2:
        raise Error("SplitPrompt: a block-halves split needs at least 2 blocks")
    if hidden <= 0 or elem_bytes <= 0:
        raise Error("SplitPrompt: hidden width and element bytes must be positive")
    if proj_macs_per_token <= 0 or attn_macs_prompt < 0:
        raise Error("SplitPrompt: MAC inputs must be positive / >= 0")
    if gpu_weight_bytes <= 0 or cpu_weight_bytes <= 0:
        raise Error("SplitPrompt: neither side of a split may be empty")
    var chunks = (prompt_tokens + chunk_width - 1) // chunk_width
    var final_width = prompt_tokens - (chunks - 1) * chunk_width
    var gpu_layers = (layers + 1) // 2
    var cpu_layers = layers - gpu_layers
    var total_macs = proj_macs_per_token * prompt_tokens + attn_macs_prompt
    var gpu_macs = total_macs * gpu_layers // layers
    var cpu_macs = total_macs - gpu_macs
    var bottleneck = gpu_macs
    if cpu_macs > bottleneck:
        bottleneck = cpu_macs
    var gpu_read = chunks * gpu_weight_bytes
    var cpu_read = chunks * cpu_weight_bytes
    return SplitPromptPlan(
        prompt_tokens,
        chunk_width,
        chunks,
        final_width,
        layers,
        gpu_layers,
        cpu_layers,
        hidden,
        elem_bytes,
        total_macs,
        gpu_macs,
        cpu_macs,
        bottleneck,
        gpu_weight_bytes,
        cpu_weight_bytes,
        gpu_read,
        cpu_read,
        gpu_read + cpu_read,
        chunks * (gpu_weight_bytes + cpu_weight_bytes),
        chunks,
        chunks,
        chunks,
        3 * chunks,
        chunks,
        0,
        prompt_tokens * hidden * elem_bytes,
        chunk_width * hidden * elem_bytes,
        whole_gpu_fits,
    )


struct SplitVerdict(Copyable, ImplicitlyCopyable):
    """The pre-registered accounted survival rule, applied."""

    var verdict: Int
    var beats_gpu_parent: Bool
    var beats_cpu_parent: Bool
    var dominated_by_gpu: Bool
    var dominated_by_cpu: Bool

    def __init__(
        out self,
        verdict: Int,
        beats_gpu_parent: Bool,
        beats_cpu_parent: Bool,
        dominated_by_gpu: Bool,
        dominated_by_cpu: Bool,
    ):
        self.verdict = verdict
        self.beats_gpu_parent = beats_gpu_parent
        self.beats_cpu_parent = beats_cpu_parent
        self.dominated_by_gpu = dominated_by_gpu
        self.dominated_by_cpu = dominated_by_cpu

    def verdict_name(self) -> String:
        if self.verdict == SPLIT_SURVIVES:
            return String("survives")
        if self.verdict == SPLIT_PARENT_ABSENT:
            return String("parent_absent_spill_fallback_shape")
        return String("accounted_and_rejected_dominated")


def _dominates(
    a_macs: Int,
    a_weight: Int,
    a_crossings: Int,
    a_join: Int,
    b_macs: Int,
    b_weight: Int,
    b_crossings: Int,
    b_join: Int,
) -> Bool:
    """True iff account A dominates account B: <= on every axis
    and strictly < on at least one. The axes and their order
    are the pre-registered rule in this module's header."""
    if a_macs > b_macs or a_weight > b_weight:
        return False
    if a_crossings > b_crossings or a_join > b_join:
        return False
    return (
        a_macs < b_macs or a_weight < b_weight
        or a_crossings < b_crossings or a_join < b_join
    )


def evaluate_split_accounting(plan: SplitPromptPlan) -> SplitVerdict:
    """Apply the pre-registered rule to one plan. The parents
    are taken from the same plan (same prompt, same chunk
    width): the whole-GPU block parent (MACs = total, weight
    reads = the parent figure, crossings = chunks, join = 0)
    and the whole-CPU/host parent (same MACs and weight reads,
    zero crossings, zero join). When the whole-GPU parent does
    not exist (whole_gpu_fits is False), no verdict is graded:
    the shape is the residency fallback, PARENT-ABSENT."""
    if not plan.whole_gpu_fits:
        return SplitVerdict(SPLIT_PARENT_ABSENT, False, False, False, False)
    var split_beats_gpu = _dominates(
        plan.total_macs,
        plan.split_weight_read_bytes,
        plan.split_crossings,
        plan.join_bytes,
        plan.total_macs,
        plan.parent_weight_read_bytes,
        plan.parent_gpu_crossings,
        0,
    )
    var split_beats_cpu = _dominates(
        plan.total_macs,
        plan.split_weight_read_bytes,
        plan.split_crossings,
        plan.join_bytes,
        plan.total_macs,
        plan.parent_weight_read_bytes,
        plan.parent_cpu_crossings,
        0,
    )
    var gpu_dominates_split = _dominates(
        plan.total_macs,
        plan.parent_weight_read_bytes,
        plan.parent_gpu_crossings,
        0,
        plan.total_macs,
        plan.split_weight_read_bytes,
        plan.split_crossings,
        plan.join_bytes,
    )
    var cpu_dominates_split = _dominates(
        plan.total_macs,
        plan.parent_weight_read_bytes,
        plan.parent_cpu_crossings,
        0,
        plan.total_macs,
        plan.split_weight_read_bytes,
        plan.split_crossings,
        plan.join_bytes,
    )
    var verdict = SPLIT_REJECTED_DOMINATED
    if split_beats_gpu and split_beats_cpu:
        verdict = SPLIT_SURVIVES
    return SplitVerdict(
        verdict,
        split_beats_gpu,
        split_beats_cpu,
        gpu_dominates_split,
        cpu_dominates_split,
    )
