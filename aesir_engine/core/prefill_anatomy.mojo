"""Prefill anatomy accounting (Janas road J-053).

Part IV grades every later slice against a baseline: where prompt
time goes in Aesir today, per architecture, at 256 / 1,024 / 4,096 /
8,192 tokens. Walls for that table need real inference on a quiet,
device-capable machine (the recipe is filed in docs/janas/
J053_PREFILL_ANATOMY.md); what THIS module pins is the part of the
anatomy that is exact by construction, so a later wall can be read
against quantities that cannot drift:

- plan_prefill_passes replays each surface's own prefill loop
  discipline and counts its passes: the host engine's chunked
  batched passes (aesir.mojo _run_generation / _prefill_batch_cap),
  the host per-token fallback, the Llama 3 CUDA tile-4 loop
  (llama3_cuda.mojo begin_turn / prefill_four), the width-1 CUDA
  loop (gemma4_cuda.mojo begin_turn; Llama 3 CUDA at batch 1), and
  the streamed MoE session's width-1 step loop (moe_session.mojo
  step). The count that differs by surface -- and the finding this
  module exists to keep visible -- is lm_head_passes: every surface
  except the MoE session pays the LM head exactly once per prompt
  (pure-prefill passes return before the head; the CUDA sessions
  pass need_logits only on the last prompt token), while the MoE
  step pays the full head plus a vocab-wide argmax scan on EVERY
  prompt token, because step() is its only entry point.
- prefill_kv_bytes prices the KV bytes a prompt WRITES, from a
  stated per-token figure the caller derives from the model's own
  profile (owning layers x K+V x kv width x f16). Allocation is a
  different quantity (the host KVCache is fixed-capacity) and is
  not priced here; J-087 owns the KV census.
- prefill_attention_pairs counts causal (query, key) pairs exactly,
  with an optional sliding window cap (Gemma 4's local layers).
  Attention MACs follow at 2 x q_width per pair per layer (scores
  plus the weighted value sum), the same on every surface: batching
  changes pass counts and weight re-reads, never the pair count.
- prefill_projection_macs counts the dense per-token projection +
  FFN multiply-accumulates (Q/K/V, attention output, gate/up/down).
  This total is surface-invariant by construction -- the batched
  and per-token paths execute the same products -- which is exactly
  why the measured S-033 chunk effect (fewer chunks, less repeated
  weight decode work) is a pass-count effect, priced separately by
  prefill_weight_pass_bytes: each pass re-reads / re-decodes the
  weight blocks it touches, so weight traffic scales with passes,
  not with tokens.
- prefill_moe_mean_stream_bytes projects the streamed MoE line's
  disk traffic at the J-030 filed mean rate (total bytes over total
  stepped tokens, integer-projected). It is a projection of a
  measured rate, labelled SIMULATED wherever it is quoted; the
  session's real per-token bytes are routing-dependent and only a
  run measures them.

What this module is NOT: it executes nothing, times nothing, and
contains no speed. Shapes that do not fit the dense accounting
(Gemma 4's per-layer-input projections, Qwen3.5's sequential
DeltaNet recurrence, OLMoE's routed experts) are stated exclusions
in J053_PREFILL_ANATOMY.md, not silent omissions here.

HOST CONTRACT: the caller derives every shape input from the
opened model's own directory/profile (layers, widths, owning KV
layers, vocab) and states the surface and cap it actually ran.
Garbage inputs are refused where detectable (non-positive token
counts, a batched plan requested with cap < 2, negative widths).
Faithfulness grading for any live leg measured against this
anatomy is the road's raw-oracle discipline: teacher-forcing rank
+ logit gap against a CPU comparator on the raw prompt, ids first;
never a template-rendering comparator.
"""

# Surface codes for plan_prefill_passes. The values name the loop
# discipline, not a device: the same surface code can run on CPU
# today and be graded against a device executor later.
comptime SURFACE_HOST_BATCHED = 0
comptime SURFACE_HOST_PER_TOKEN = 1
comptime SURFACE_CUDA_TILE4 = 2
comptime SURFACE_CUDA_WIDTH1 = 3
comptime SURFACE_MOE_WIDTH1 = 4


struct PrefillPassPlan(Copyable, ImplicitlyCopyable):
    """One prompt's pass account on one surface."""

    var passes: Int
    var pure_prefill_passes: Int
    var final_pass_width: Int
    var lm_head_passes: Int

    def __init__(
        out self,
        passes: Int,
        pure_prefill_passes: Int,
        final_pass_width: Int,
        lm_head_passes: Int,
    ):
        self.passes = passes
        self.pure_prefill_passes = pure_prefill_passes
        self.final_pass_width = final_pass_width
        self.lm_head_passes = lm_head_passes


def plan_prefill_passes(
    surface: Int, prompt_tokens: Int, cap: Int = 256
) raises -> PrefillPassPlan:
    """Replay one surface's prefill loop over prompt_tokens tokens.

    cap is the host chunk cap (AESIR_PREFILL_BATCH as clamped by
    _prefill_batch_cap) and is read only by SURFACE_HOST_BATCHED,
    which refuses cap < 2 -- a cap of 1 IS the per-token surface,
    and the caller must name it as such so the account stays true.
    """
    if prompt_tokens <= 0:
        raise Error("PrefillAnatomy: prompt token count must be positive")
    if surface == SURFACE_HOST_BATCHED:
        if cap < 2:
            raise Error(
                "PrefillAnatomy: batched plan requires cap >= 2"
                " (cap 1 is SURFACE_HOST_PER_TOKEN)"
            )
        var pure = 0
        var pos = 0
        while prompt_tokens - 1 - pos >= cap:
            pure += 1
            pos += cap
        return PrefillPassPlan(pure + 1, pure, prompt_tokens - pos, 1)
    if surface == SURFACE_HOST_PER_TOKEN:
        return PrefillPassPlan(prompt_tokens, prompt_tokens - 1, 1, 1)
    if surface == SURFACE_CUDA_TILE4:
        # begin_turn's loop: a width-4 tile whenever at least 4
        # tokens remain before the last, else width-1 passes; the
        # LM head is paid only by the final width-1 pass.
        var passes = 0
        var i = 0
        while i < prompt_tokens:
            if prompt_tokens - 1 - i >= 4:
                passes += 1
                i += 4
            else:
                passes += 1
                i += 1
        return PrefillPassPlan(passes, passes - 1, 1, 1)
    if surface == SURFACE_CUDA_WIDTH1:
        return PrefillPassPlan(prompt_tokens, prompt_tokens - 1, 1, 1)
    if surface == SURFACE_MOE_WIDTH1:
        # moe_session.step() has no pure-prefill form: every step
        # runs the final norm, the output projection, and a
        # vocab-wide argmax scan. Zero passes are pure prefill in
        # the head sense, and the head is paid prompt_tokens times.
        return PrefillPassPlan(prompt_tokens, 0, 1, prompt_tokens)
    raise Error("PrefillAnatomy: unknown surface code")


def prefill_kv_bytes(kv_bytes_per_token: Int, prompt_tokens: Int) raises -> Int:
    """KV bytes a prompt of prompt_tokens writes, at a stated
    per-token figure (owning layers x 2 (K and V) x kv width x
    2 bytes for f16), derived by the caller from the profile."""
    if kv_bytes_per_token <= 0 or prompt_tokens <= 0:
        raise Error("PrefillAnatomy: KV inputs must be positive")
    return kv_bytes_per_token * prompt_tokens


def prefill_attention_pairs(prompt_tokens: Int, window: Int = 0) raises -> Int:
    """Causal (query, key) pairs in one layer over a prompt.

    window <= 0 means full causal attention: n(n+1)/2. A positive
    window caps each query's attended span (sliding-window layers):
    pairs = window*n - window*(window-1)/2 once n exceeds it.
    """
    if prompt_tokens <= 0:
        raise Error("PrefillAnatomy: prompt token count must be positive")
    if window < 0:
        raise Error("PrefillAnatomy: window must be >= 0")
    if window == 0 or prompt_tokens <= window:
        return prompt_tokens * (prompt_tokens + 1) // 2
    return window * prompt_tokens - window * (window - 1) // 2


def prefill_projection_macs_per_token(
    layers: Int, hidden: Int, q_width: Int, kv_width: Int, ffn: Int
) raises -> Int:
    """Dense projection + FFN MACs for one token across all layers:
    per layer hidden*q (Q) + 2*hidden*kv (K, V) + q*hidden
    (attention output) + 3*hidden*ffn (gate, up, down). Excludes
    attention itself, norms, RoPE, and the LM head -- each priced
    or named separately so the split stays visible."""
    if layers <= 0 or hidden <= 0 or q_width <= 0 or kv_width <= 0 or ffn <= 0:
        raise Error("PrefillAnatomy: projection shape must be positive")
    var per_layer = 2 * hidden * q_width + 2 * hidden * kv_width + 3 * hidden * ffn
    return per_layer * layers


def prefill_attention_macs(
    layers: Int, q_width: Int, prompt_tokens: Int, window: Int = 0
) raises -> Int:
    """Attention MACs over a whole prompt: per layer, each causal
    pair costs q_width MACs for the score and q_width for the
    weighted value sum."""
    if layers <= 0 or q_width <= 0:
        raise Error("PrefillAnatomy: attention shape must be positive")
    return layers * prefill_attention_pairs(prompt_tokens, window) * q_width * 2


def prefill_lm_head_macs(
    hidden: Int, vocab: Int, lm_head_passes: Int
) raises -> Int:
    """LM head MACs a prompt pays: hidden*vocab per head pass. The
    pass count comes from plan_prefill_passes -- 1 on every surface
    except the MoE session, where it equals the prompt length."""
    if hidden <= 0 or vocab <= 0 or lm_head_passes <= 0:
        raise Error("PrefillAnatomy: LM head inputs must be positive")
    return hidden * vocab * lm_head_passes


def prefill_weight_pass_bytes(passes: Int, weight_bytes: Int) raises -> Int:
    """Weight-block traffic shape: each pass re-reads / re-decodes
    the weight blocks it touches, so the traffic a prompt causes
    scales with its pass count at a stated per-pass weight figure.
    An upper shape, not a byte count of any real run: caches at
    every level sit between this figure and the device."""
    if passes <= 0 or weight_bytes <= 0:
        raise Error("PrefillAnatomy: weight-pass inputs must be positive")
    return passes * weight_bytes


def prefill_moe_mean_stream_bytes(
    prompt_tokens: Int, filed_total_bytes: Int, filed_total_tokens: Int
) raises -> Int:
    """Projected streamed bytes for a prompt at a filed mean rate
    (the J-030 leg: filed_total_bytes over filed_total_tokens
    stepped tokens). Integer projection of a measured rate --
    SIMULATED wherever quoted; real bytes are routing-dependent."""
    if prompt_tokens <= 0 or filed_total_bytes <= 0 or filed_total_tokens <= 0:
        raise Error("PrefillAnatomy: MoE stream inputs must be positive")
    return prompt_tokens * filed_total_bytes // filed_total_tokens
