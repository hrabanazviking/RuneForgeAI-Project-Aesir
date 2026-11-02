"""Whole-layer dense on GPU: fit, sync and agreement accounting
(Janas road J-055).

J-053 anatomised the prompt pass and J-054 named the pieces a
prefill-shaped GPU executor still lacks (M1-M7 in docs/janas/
J054_GPU_BLOCK_PREFILL.md). This slice is the neighbouring
question: for a DENSE model, when can EVERY layer of the prompt
pass live on the GPU at once -- the whole-layer shape Janas
documents for dense Qwen3/Qwen3.5 and, since 26 Oct 2026, for all
four Gemma 4 models (census J-005, behaviour only)?

What already exists in this tree, by inspection: the two CUDA
sessions ARE whole-layer executors at width 1. Llama3CUDASession
.forward and Gemma4CUDASession.forward run every layer of one
token on the device -- embedding, per-layer projections, norms,
RoPE, KV writes, scores/softmax/attention kernels, head -- and
synchronise once per token. A width-1 prompt pass through them is
therefore already whole-layer; what it is not is BLOCK-shaped.
Binding to J-054's M-list, exactly:

- Whole-layer at width 1 needs NO M item. It is the proven decode
  shape extended over the prompt, and its cost is J-053's count:
  one synchronisation per token.
- A whole-layer BLOCK prompt pass (width > 1) is gated by M1
  (general-width quantized GEMM) + M2 (batched layout/admission)
  + M5 (chunk-level session loop); M4 (batched per-row ops) sets
  its launch floor, M6 is the same build for the Gemma 4 session,
  and M7 (instrumentation) gates quoting any per-phase wall.
- M3 (batched attention) does NOT gate whole-layer placement:
  the attention kernels are already device-resident per row.
  M3 gates only the long-context ceiling (J-053 finding F2).

This module is the planning/accounting layer for the fit half of
the question, in the J-031/J-053/J-054 style: pure arithmetic, no
device calls, nothing timed, no speed claimed.

- plan_whole_layer_fit charges one model against one stated
  usable device budget: directory-true weight bytes (embeddings
  and head included -- whole-layer means the whole model), the
  KV bytes for the FULL context the session will hold (prompt +
  generation, at the caller's per-token figure from J-053),
  activation scratch at the caller's stated execution width,
  the scores buffer, and a caller-stated reserve. The verdict is
  in the plan: fits (with headroom) or no-fit (with the exact
  shortfall). No-fit is not a failure state: the honest fallback
  is the proven spill partition (J-021, core/dense_residency
  .mojo) -- front layers on the device, tail on the CPU -- which
  is a DIFFERENT shape and is never reported as whole-layer.
- whole_layer_max_weights inverts the same arithmetic: the
  largest weight bytes that fit beside a stated context, for
  shapes whose file bytes a caller has not pinned yet.
- plan_whole_layer_syncs counts synchronised crossings for the
  whole-layer shapes against the per-layer-submission shape they
  replace: whole-layer submits the layer stack once per token
  (width 1) or once per chunk (block), where a per-layer shape
  pays layers crossings for the same work -- a factor of exactly
  layers, at either width.
- agreement_basis_points states the bit-agreement discipline's
  counting arithmetic (J-055 doc section 5): top-token agreement
  of the GPU path against the CPU path over a stated token
  count, in basis points, so a filed count can never be rounded
  into a verdict it is not. The discipline itself -- counts per
  model beside teacher-forcing rank/gap on raw prompts -- is
  defined in the slice doc; this function only keeps the count
  honest.

HOST CONTRACT: the caller derives weight bytes from the opened
file's tensor directory (or states file bytes, the conservative
charge), KV per token from the model's profile (J-053), scratch
from its session layout at the stated width, and the usable
budget from the device admission figure the dense sessions
themselves use -- never total VRAM. Garbage inputs are refused
where detectable. Faithfulness grading for any live leg is the
road's raw-oracle discipline plus this slice's agreement counts:
ids first, then teacher-forcing rank + logit gap against a CPU
comparator on the raw prompt; never llama-cli --single-turn.
"""

# Verdict codes for plan_whole_layer_fit.
comptime VERDICT_WHOLE_FITS = 0
comptime VERDICT_NO_FIT_SPILL = 1

# The tree's existing upload staging bound (core/cuda_upload.mojo,
# MAX_UPLOAD_STAGING_BYTES = 64 MiB, one synchronisation per
# chunk). Restated so this module stays a lightest-target,
# device-free planning layer (the J-031/J-054 pattern); the value
# must move with cuda_upload's if that bound ever changes.
comptime UPLOAD_STAGING_BYTES = 67108864


def whole_layer_upload_chunks(total_bytes: Int) raises -> Int:
    """Synchronised staging chunks an open-time upload of
    total_bytes costs through the existing 64 MiB staging."""
    if total_bytes < 0:
        raise Error("WholeLayerGPU: upload bytes out of range")
    if total_bytes == 0:
        return 0
    return (total_bytes + UPLOAD_STAGING_BYTES - 1) // UPLOAD_STAGING_BYTES


struct WholeLayerFit(Copyable, ImplicitlyCopyable):
    """One dense model's whole-layer fit account on one device."""

    var weight_bytes: Int
    var kv_bytes: Int
    var activation_scratch_bytes: Int
    var scores_bytes: Int
    var reserve_bytes: Int
    var required_bytes: Int
    var device_budget_bytes: Int
    var headroom_bytes: Int
    var verdict: Int
    var upload_chunks: Int

    def __init__(
        out self,
        weight_bytes: Int,
        kv_bytes: Int,
        activation_scratch_bytes: Int,
        scores_bytes: Int,
        reserve_bytes: Int,
        required_bytes: Int,
        device_budget_bytes: Int,
        headroom_bytes: Int,
        verdict: Int,
        upload_chunks: Int,
    ):
        self.weight_bytes = weight_bytes
        self.kv_bytes = kv_bytes
        self.activation_scratch_bytes = activation_scratch_bytes
        self.scores_bytes = scores_bytes
        self.reserve_bytes = reserve_bytes
        self.required_bytes = required_bytes
        self.device_budget_bytes = device_budget_bytes
        self.headroom_bytes = headroom_bytes
        self.verdict = verdict
        self.upload_chunks = upload_chunks

    def verdict_name(self) -> String:
        if self.verdict == VERDICT_WHOLE_FITS:
            return String("whole_fits")
        return String("no_fit_spill_is_the_fallback")


def plan_whole_layer_fit(
    weight_bytes: Int,
    kv_bytes_per_token: Int,
    context_tokens: Int,
    activation_scratch_bytes: Int,
    scores_bytes: Int,
    reserve_bytes: Int,
    device_budget_bytes: Int,
) raises -> WholeLayerFit:
    """Charge one dense model whole-layer against one device.

    context_tokens is the FULL context the session will hold
    (prompt + generation): the KV charge is for the session's
    life, not for the prompt alone -- a fit that only holds
    until generation starts is not a fit. activation_scratch
    and scores_bytes are the caller's session-layout figures at
    the stated execution width (width 1 is the proven shape;
    a block width charges its wider scratch honestly, per
    J-054 section 5's sizing).
    """
    if weight_bytes <= 0 or kv_bytes_per_token <= 0:
        raise Error("WholeLayerGPU: weight and KV figures must be positive")
    if context_tokens <= 0 or device_budget_bytes <= 0:
        raise Error("WholeLayerGPU: context and budget must be positive")
    if activation_scratch_bytes < 0 or scores_bytes < 0 or reserve_bytes < 0:
        raise Error("WholeLayerGPU: scratch, scores and reserve must be >= 0")
    var kv_bytes = kv_bytes_per_token * context_tokens
    var required = (
        weight_bytes + kv_bytes + activation_scratch_bytes
        + scores_bytes + reserve_bytes
    )
    var headroom = device_budget_bytes - required
    var verdict = VERDICT_WHOLE_FITS
    if required > device_budget_bytes:
        verdict = VERDICT_NO_FIT_SPILL
    return WholeLayerFit(
        weight_bytes,
        kv_bytes,
        activation_scratch_bytes,
        scores_bytes,
        reserve_bytes,
        required,
        device_budget_bytes,
        headroom,
        verdict,
        whole_layer_upload_chunks(weight_bytes),
    )


def whole_layer_max_weights(
    kv_bytes_per_token: Int,
    context_tokens: Int,
    activation_scratch_bytes: Int,
    scores_bytes: Int,
    reserve_bytes: Int,
    device_budget_bytes: Int,
) raises -> Int:
    """The largest weight bytes that fit whole-layer beside a
    stated context on a stated device: budget minus every other
    charge. Zero or negative means no dense model fits at that
    context on that device -- stated, not clamped."""
    if kv_bytes_per_token <= 0 or context_tokens <= 0:
        raise Error("WholeLayerGPU: KV and context must be positive")
    if device_budget_bytes <= 0:
        raise Error("WholeLayerGPU: budget must be positive")
    if activation_scratch_bytes < 0 or scores_bytes < 0 or reserve_bytes < 0:
        raise Error("WholeLayerGPU: scratch, scores and reserve must be >= 0")
    return (
        device_budget_bytes - kv_bytes_per_token * context_tokens
        - activation_scratch_bytes - scores_bytes - reserve_bytes
    )


struct WholeLayerSyncs(Copyable, ImplicitlyCopyable):
    """Synchronised crossings: whole-layer vs per-layer shapes."""

    var prompt_tokens: Int
    var chunk_width: Int
    var layers: Int
    var whole_width1_syncs: Int
    var whole_block_syncs: Int
    var per_layer_width1_syncs: Int
    var per_layer_block_syncs: Int

    def __init__(
        out self,
        prompt_tokens: Int,
        chunk_width: Int,
        layers: Int,
        whole_width1_syncs: Int,
        whole_block_syncs: Int,
        per_layer_width1_syncs: Int,
        per_layer_block_syncs: Int,
    ):
        self.prompt_tokens = prompt_tokens
        self.chunk_width = chunk_width
        self.layers = layers
        self.whole_width1_syncs = whole_width1_syncs
        self.whole_block_syncs = whole_block_syncs
        self.per_layer_width1_syncs = per_layer_width1_syncs
        self.per_layer_block_syncs = per_layer_block_syncs


def plan_whole_layer_syncs(
    prompt_tokens: Int, chunk_width: Int, layers: Int
) raises -> WholeLayerSyncs:
    """Crossings for one prompt: the whole-layer shapes submit
    the layer stack once per token (width 1, the proven CUDA
    sessions' discipline) or once per chunk (the J-054 block
    shape); a per-layer-submission shape pays layers crossings
    for the same tokens at either width. The ratio is exactly
    layers -- the count is the claim, no wall is implied."""
    if prompt_tokens <= 0 or chunk_width <= 0 or layers <= 0:
        raise Error("WholeLayerGPU: sync inputs must be positive")
    var chunks = (prompt_tokens + chunk_width - 1) // chunk_width
    return WholeLayerSyncs(
        prompt_tokens,
        chunk_width,
        layers,
        prompt_tokens,
        chunks,
        prompt_tokens * layers,
        chunks * layers,
    )


def agreement_basis_points(agree: Int, total: Int) raises -> Int:
    """Top-token agreement as a count, stated in basis points:
    agree of total positions, times 10,000 over total. The
    J-055 agreement discipline files the raw counts beside this
    figure per model; the figure never replaces the counts."""
    if total <= 0:
        raise Error("WholeLayerGPU: agreement total must be positive")
    if agree < 0 or agree > total:
        raise Error("WholeLayerGPU: agreement count out of range")
    return agree * 10000 // total
