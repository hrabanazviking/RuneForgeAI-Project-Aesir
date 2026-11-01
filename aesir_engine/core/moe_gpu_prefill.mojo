"""MoE prompt on GPU: the batched-prefill plan (Janas road J-058).

The roadmap text: "For mixtures: resident weights' products on
the GPU during prefill, routed experts per Part II's division;
measured against CPU prefill on the J-022 model." J-031 designed
the decode-shaped division (resident set on device, streamed
experts computed where they land, per-token transfer accounts in
core/moe_gpu_plan.mojo). This module is the PREFILL-shaped form
of that division: a prompt of N tokens executed in chunks of a
stated width on the device, graded in accounting form against
the CPU prefill line (J-030) for the same prompt. It stands on
three filed facts:

- The streamed MoE session (core/moe_session.mojo) is width-1
  only: step() is its only forward entry and there is no
  pure-prefill form, so a CPU prompt pays the final norm, the
  output projection, and a vocab-wide argmax scan on EVERY
  prompt token (J-053 finding F1: 103,022,592 head MACs per
  prompt token at OLMoE's shape, ~9.6% on top of each token's
  routed layer work, discarded for all but the last token).
  Every other surface in the tree pays the head exactly once
  (pure-prefill passes return before it; the CUDA sessions pass
  need_logits only on the last prompt token).
- J-031's division for the J-022 model on the road's stated
  card is FULL_GPU (the whole model fits: resident 311,027,712 B
  + allowances 352,321,536 B + expert body 3,900,702,720 B =
  4,564,051,968 B against a 5,368,709,120 B usable budget), so
  the operative prefill division for that model is whole-model
  device residency; the expert-cache division is the
  bigger-than-device form, and the resident-only split was
  designed in J-031 in order to be priced and rejected as the
  default shape (the stack split at every layer).
- Batching never changes MAC totals for the layer work itself
  (J-053: the total is surface-invariant); what a chunk width
  changes is PASSES -- each pass re-reads the resident weights
  it touches (the S-033 mechanism: the host's one measured
  chunk effect) -- and SYNCHRONISATIONS (J-054: one per chunk
  instead of one per token). Routed-expert demand is routing,
  not width: accesses per token are layers x top-k on every
  form, and this plan conserves them exactly.

WHAT THE PLAN ACCOUNTS, per prompt, for the GPU chunk form
beside the CPU width-1 form of the same prompt:

- LM-head passes and MACs: CPU form N passes (step()'s shape);
  GPU form exactly 1 (the pure-prefill discipline the chunk
  loop carries, M5/G2 in the slice doc -- the head collapse is
  a property of that discipline, not of chunking alone, and
  the width-1 GPU row in the tests keeps the two apart).
- Resident weight-read bytes: CPU form N passes over the
  resident set; GPU form one pass per chunk. Expert weights
  are NOT in this figure: routed experts are demand work,
  accounted as accesses and as streamed/upload bytes below.
- Expert demand: total accesses (conserved), and bytes --
  the CPU form's streamed bytes for this prompt (caller-stated
  exact facts from the cache's statistics, or the J-030 mean
  projection, caller-labelled; this module never invents a
  routing outcome) versus the GPU form's expert traffic per
  J-031's division: FULL pays none per prompt (its price is
  the one-time open upload, priced by moe_gpu_plan's
  moe_gpu_upload_chunks); the CACHE division re-pays exactly
  the streamed bytes as host->device uploads (J-031's finding:
  GPU assistance relocates compute, it does not shrink byte
  traffic); the RESIDENT-ONLY form pays no expert upload but
  crosses the hidden vector twice per layer (priced in bytes
  and crossings, per chunk instead of per token).
- Crossings: synchronised batches -- GPU chunk form one per
  chunk (plus, for the cache division, one upload batch per
  (chunk, layer) pair with at least one miss, caller-stated);
  the width-1 GPU form's count for the same division is
  stated beside it, so the chunk economy is visible; the CPU
  form has no device and crosses zero times, which is a
  statement about devices, not a wall claim.
- Per-row attention kernel calls (3 per token per layer,
  J-053 F2 / J-054): conserved on every form -- attention
  does not batch, and this plan does not pretend a chunk
  changes that. KV bytes written are likewise conserved.

THE SURVIVAL RULE, PRE-REGISTERED (stated here and in the
slice doc before the filed shapes were run through it). The
GPU chunk form SURVIVES ACCOUNTING for a stated division and
prompt only if all of these hold: (a) the division places the
resident set on the device at all (CPU_ONLY is
NOT_APPLICABLE -- there is no GPU form to grade, and J-031
already states that division as the CPU line); (b) the
division is not the resident-only split (REJECTED_RESIDENT_
ONLY, carried from J-031: a stack split at every layer,
priced here at chunk width and still the worst shape on the
table); (c) the GPU form's expert upload bytes do not exceed
the CPU form's streamed bytes for the same routing
(REJECTED_EXPERT_BYTES otherwise -- the cache division ties
this axis by construction, the full division pays zero);
(d) the head is paid exactly once; and (e) the resident
weight-read saving reaches the road's standing margin,
saving >= 1000 basis points of the CPU form's resident reads
(the J-040/J-043 margin discipline, as in J-056/J-057). A
form that collapses the head but saves nothing on resident
passes -- the width-1 GPU form -- is HEAD_ONLY: F1's fix
stands, the chunk economy does not. Two honesty clauses ride
with the rule, as in J-057: it grades counts and bytes, never
time -- no byte/MAC-to-time exchange rate is stated or
implied anywhere in this module, and only the deferred live
leg's measured walls (slice doc recipe) can promote an
accounted survival into a speed claim; and per-division
verdicts stay per-division -- the full division's survival
on the J-022 model says nothing about any other model,
device, or budget.

WHAT THIS MODULE IS NOT: it executes nothing, creates no
CUDA context, launches no kernel, and contains no speed.
The executor it specifies does not exist: the missing pieces
(J-054's M1/M2/M4/M5 as they gate this shape, plus the
MoE-specific G1/G3/G4/G5 named in the slice doc) are the
deferred leg's build list.

HOST CONTRACT: the caller derives every shape input from the
opened file's directory/profile (layers, hidden, top-k,
per-token MAC splits, directory-true resident bytes), states
the division from plan_moe_gpu_division (core/moe_gpu_plan
.mojo) for the same budget it actually has, states the
prompt's streamed bytes from the expert cache's own
statistics (or labels a projection as one), and states
miss_batches as the count of (chunk, layer) pairs with at
least one miss for the cache division. Garbage is refused
where detectable (non-positive shapes, a prompt beyond the
stated context, miss facts that disagree, miss batches
charged to a division that takes no uploads). Faithfulness
grading for any live leg is the road's raw-oracle discipline:
ids first against the CPU line's J-030 id set, then
teacher-forcing rank + logit gap against the ggml CPU
comparator on the raw prompt; never llama-cli --single-turn.
"""

from core.moe_gpu_plan import (
    DIVISION_CPU_ONLY,
    DIVISION_FULL_GPU,
    DIVISION_RESIDENT_GPU,
    DIVISION_RESIDENT_GPU_EXPERT_CACHE,
)

# Survival verdicts for evaluate_moe_gpu_prefill.
comptime MOE_PREFILL_SURVIVES = 0
comptime MOE_PREFILL_HEAD_ONLY = 1
comptime MOE_PREFILL_REJECTED_RESIDENT_ONLY = 2
comptime MOE_PREFILL_NOT_APPLICABLE_CPU_ONLY = 3
comptime MOE_PREFILL_REJECTED_EXPERT_BYTES = 4

# The standing margin: a resident-read saving below 10% of
# the CPU form's resident reads does not repay a chunk
# executor (J-040/J-043 margin discipline, carried into this
# rule before any filed shape was graded).
comptime MOE_PREFILL_MARGIN_BASIS_POINTS = 1000

# Per-row attention kernels per token per layer on both CUDA
# sessions (scores, softmax, attention) -- J-053 F2, restated
# from core/gpu_block_prefill.mojo so the count stays in one
# vocabulary.
comptime ATTENTION_KERNELS_PER_ROW = 3


struct MoeGpuPrefillPlan(Copyable, ImplicitlyCopyable):
    """One prompt's MoE prefill account: the planned GPU chunk
    form beside the existing CPU width-1 form, same prompt,
    same routing, counts and bytes only."""

    var prompt_tokens: Int
    var chunk_width: Int
    var chunks: Int
    var final_chunk_width: Int
    var division: Int
    var layers: Int
    var hidden: Int
    var topk: Int
    var resident_macs_per_token: Int
    var expert_macs_per_token: Int
    var head_macs_per_pass: Int
    var cpu_head_passes: Int
    var gpu_head_passes: Int
    var cpu_total_macs: Int
    var gpu_total_macs: Int
    var head_macs_saved: Int
    var resident_weight_bytes: Int
    var cpu_resident_read_bytes: Int
    var gpu_resident_read_bytes: Int
    var resident_read_saving_bp: Int
    var expert_accesses: Int
    var per_row_attention_calls: Int
    var kv_bytes_written: Int
    var cpu_streamed_bytes: Int
    var gpu_expert_upload_bytes: Int
    var gpu_hidden_bytes: Int
    var miss_batches: Int
    var gpu_crossings: Int
    var width1_gpu_crossings: Int

    def __init__(
        out self,
        prompt_tokens: Int,
        chunk_width: Int,
        chunks: Int,
        final_chunk_width: Int,
        division: Int,
        layers: Int,
        hidden: Int,
        topk: Int,
        resident_macs_per_token: Int,
        expert_macs_per_token: Int,
        head_macs_per_pass: Int,
        cpu_head_passes: Int,
        gpu_head_passes: Int,
        cpu_total_macs: Int,
        gpu_total_macs: Int,
        head_macs_saved: Int,
        resident_weight_bytes: Int,
        cpu_resident_read_bytes: Int,
        gpu_resident_read_bytes: Int,
        resident_read_saving_bp: Int,
        expert_accesses: Int,
        per_row_attention_calls: Int,
        kv_bytes_written: Int,
        cpu_streamed_bytes: Int,
        gpu_expert_upload_bytes: Int,
        gpu_hidden_bytes: Int,
        miss_batches: Int,
        gpu_crossings: Int,
        width1_gpu_crossings: Int,
    ):
        self.prompt_tokens = prompt_tokens
        self.chunk_width = chunk_width
        self.chunks = chunks
        self.final_chunk_width = final_chunk_width
        self.division = division
        self.layers = layers
        self.hidden = hidden
        self.topk = topk
        self.resident_macs_per_token = resident_macs_per_token
        self.expert_macs_per_token = expert_macs_per_token
        self.head_macs_per_pass = head_macs_per_pass
        self.cpu_head_passes = cpu_head_passes
        self.gpu_head_passes = gpu_head_passes
        self.cpu_total_macs = cpu_total_macs
        self.gpu_total_macs = gpu_total_macs
        self.head_macs_saved = head_macs_saved
        self.resident_weight_bytes = resident_weight_bytes
        self.cpu_resident_read_bytes = cpu_resident_read_bytes
        self.gpu_resident_read_bytes = gpu_resident_read_bytes
        self.resident_read_saving_bp = resident_read_saving_bp
        self.expert_accesses = expert_accesses
        self.per_row_attention_calls = per_row_attention_calls
        self.kv_bytes_written = kv_bytes_written
        self.cpu_streamed_bytes = cpu_streamed_bytes
        self.gpu_expert_upload_bytes = gpu_expert_upload_bytes
        self.gpu_hidden_bytes = gpu_hidden_bytes
        self.miss_batches = miss_batches
        self.gpu_crossings = gpu_crossings
        self.width1_gpu_crossings = width1_gpu_crossings


def plan_moe_gpu_prefill(
    prompt_tokens: Int,
    chunk_width: Int,
    layers: Int,
    hidden: Int,
    topk: Int,
    resident_macs_per_token: Int,
    expert_macs_per_token: Int,
    head_macs_per_pass: Int,
    resident_weight_bytes: Int,
    kv_bytes_per_token: Int,
    division: Int,
    context_capacity: Int,
    cpu_streamed_bytes: Int,
    miss_batches: Int,
) raises -> MoeGpuPrefillPlan:
    """Account one prompt's MoE prefill on both forms.

    cpu_streamed_bytes is the CPU form's streamed bytes for
    THIS prompt under identical routing (the cache's own
    statistics for a run that happened, or a labelled
    projection); the cache division re-pays exactly that
    figure as uploads, so for that division the miss facts
    must agree with it (zero streamed iff zero miss batches),
    exactly as J-031's per-token accountant refuses
    disagreeing miss facts. miss_batches counts (chunk,
    layer) pairs with at least one miss and is charged only
    to the cache division. Under CPU_ONLY the plan restates
    the CPU account (gpu fields equal cpu fields): the
    division refused device placement, and no GPU form is
    specified by restating one.
    """
    if prompt_tokens <= 0 or chunk_width <= 0:
        raise Error("MoeGpuPrefill: token count and chunk width must be positive")
    if layers <= 0 or hidden <= 0 or topk <= 0:
        raise Error("MoeGpuPrefill: model shape must be positive")
    if (
        resident_macs_per_token <= 0
        or expert_macs_per_token <= 0
        or head_macs_per_pass <= 0
    ):
        raise Error("MoeGpuPrefill: per-token MAC figures must be positive")
    if resident_weight_bytes <= 0 or kv_bytes_per_token <= 0:
        raise Error("MoeGpuPrefill: byte figures must be positive")
    if context_capacity <= 0 or prompt_tokens > context_capacity:
        raise Error("MoeGpuPrefill: prompt exceeds stated context capacity")
    if (
        division != DIVISION_CPU_ONLY
        and division != DIVISION_RESIDENT_GPU
        and division != DIVISION_RESIDENT_GPU_EXPERT_CACHE
        and division != DIVISION_FULL_GPU
    ):
        raise Error("MoeGpuPrefill: unknown division code")
    if cpu_streamed_bytes < 0 or miss_batches < 0:
        raise Error("MoeGpuPrefill: token facts must be >= 0")
    var chunks = (prompt_tokens + chunk_width - 1) // chunk_width
    var final_width = prompt_tokens - (chunks - 1) * chunk_width
    if miss_batches > chunks * layers:
        raise Error("MoeGpuPrefill: miss batches exceed chunk-layer pairs")
    if division == DIVISION_RESIDENT_GPU_EXPERT_CACHE:
        if (cpu_streamed_bytes == 0) != (miss_batches == 0):
            raise Error(
                "MoeGpuPrefill: cache-division miss facts disagree:"
                " streamed bytes and miss batches must both be zero"
                " or both nonzero"
            )
    elif miss_batches != 0:
        raise Error(
            "MoeGpuPrefill: miss batches are charged only to the"
            " expert-cache division"
        )
    var layer_macs = resident_macs_per_token + expert_macs_per_token
    var cpu_head_passes = prompt_tokens
    var cpu_total = prompt_tokens * (layer_macs + head_macs_per_pass)
    var cpu_reads = prompt_tokens * resident_weight_bytes
    var accesses = prompt_tokens * layers * topk
    var attn_calls = prompt_tokens * layers * ATTENTION_KERNELS_PER_ROW
    var kv_written = prompt_tokens * kv_bytes_per_token
    if division == DIVISION_CPU_ONLY:
        return MoeGpuPrefillPlan(
            prompt_tokens, chunk_width, chunks, final_width,
            division, layers, hidden, topk,
            resident_macs_per_token, expert_macs_per_token,
            head_macs_per_pass,
            cpu_head_passes, cpu_head_passes,
            cpu_total, cpu_total, 0,
            resident_weight_bytes, cpu_reads, cpu_reads, 0,
            accesses, attn_calls, kv_written,
            cpu_streamed_bytes, 0, 0, miss_batches, 0, 0,
        )
    var gpu_total = prompt_tokens * layer_macs + head_macs_per_pass
    var gpu_reads = chunks * resident_weight_bytes
    var saving_bp = (cpu_reads - gpu_reads) * 10000 // cpu_reads
    var upload = 0
    var hidden_bytes = 0
    var crossings = chunks
    var width1_crossings = prompt_tokens
    if division == DIVISION_RESIDENT_GPU_EXPERT_CACHE:
        upload = cpu_streamed_bytes
        crossings = chunks + miss_batches
        # The width-1 comparator's miss-batch count is a
        # per-(token, layer) figure that chunked miss facts do
        # not determine; only its base synchronisations (one
        # per token, J-031) are stated, as a floor.
    elif division == DIVISION_RESIDENT_GPU:
        # The stack split: the hidden vector (f16, hidden x 2
        # bytes) crosses device->host and back at every layer,
        # batched per chunk instead of per token. Bytes are
        # width-invariant; only the crossing count shrinks.
        hidden_bytes = prompt_tokens * layers * hidden * 4
        crossings = 2 * layers * chunks
        width1_crossings = 2 * layers * prompt_tokens
    return MoeGpuPrefillPlan(
        prompt_tokens, chunk_width, chunks, final_width,
        division, layers, hidden, topk,
        resident_macs_per_token, expert_macs_per_token,
        head_macs_per_pass,
        cpu_head_passes, 1,
        cpu_total, gpu_total,
        cpu_total - gpu_total,
        resident_weight_bytes, cpu_reads, gpu_reads, saving_bp,
        accesses, attn_calls, kv_written,
        cpu_streamed_bytes, upload, hidden_bytes, miss_batches,
        crossings, width1_crossings,
    )


struct MoePrefillVerdict(Copyable, ImplicitlyCopyable):
    """The pre-registered survival rule, applied to one plan."""

    var verdict: Int
    var resident_read_saving_bp: Int

    def __init__(out self, verdict: Int, resident_read_saving_bp: Int):
        self.verdict = verdict
        self.resident_read_saving_bp = resident_read_saving_bp

    def verdict_name(self) -> String:
        if self.verdict == MOE_PREFILL_SURVIVES:
            return String("survives_accounting")
        if self.verdict == MOE_PREFILL_HEAD_ONLY:
            return String("head_only")
        if self.verdict == MOE_PREFILL_REJECTED_RESIDENT_ONLY:
            return String("rejected_resident_only")
        if self.verdict == MOE_PREFILL_NOT_APPLICABLE_CPU_ONLY:
            return String("not_applicable_cpu_only")
        return String("rejected_expert_bytes")


def evaluate_moe_gpu_prefill(plan: MoeGpuPrefillPlan) -> MoePrefillVerdict:
    """Apply the pre-registered rule to one plan, in the
    plan's own counts and bytes: CPU_ONLY is not applicable;
    the resident-only split is rejected (carried from J-031);
    expert uploads above the CPU form's streamed bytes are
    rejected; the head paid exactly once plus a resident-read
    saving at or above the 10% margin survives; a collapsed
    head without the pass economy is HEAD_ONLY. The saving is
    recomputed from the plan's read fields, so the rule grades
    the account as stated, not as summarised."""
    if plan.division == DIVISION_CPU_ONLY:
        return MoePrefillVerdict(
            MOE_PREFILL_NOT_APPLICABLE_CPU_ONLY, plan.resident_read_saving_bp
        )
    if plan.division == DIVISION_RESIDENT_GPU:
        return MoePrefillVerdict(
            MOE_PREFILL_REJECTED_RESIDENT_ONLY, plan.resident_read_saving_bp
        )
    var saving_bp = plan.resident_read_saving_bp
    if plan.cpu_resident_read_bytes > 0:
        saving_bp = (
            (plan.cpu_resident_read_bytes - plan.gpu_resident_read_bytes)
            * 10000
            // plan.cpu_resident_read_bytes
        )
    if plan.gpu_expert_upload_bytes > plan.cpu_streamed_bytes:
        return MoePrefillVerdict(MOE_PREFILL_REJECTED_EXPERT_BYTES, saving_bp)
    if plan.gpu_head_passes == 1 and saving_bp >= MOE_PREFILL_MARGIN_BASIS_POINTS:
        return MoePrefillVerdict(MOE_PREFILL_SURVIVES, saving_bp)
    return MoePrefillVerdict(MOE_PREFILL_HEAD_ONLY, saving_bp)
