"""Prompt-read economics accounting (Janas road J-094).

The roadmap text: "Prompt-read economics. The 32k
prompt's read time (Janas: 15 minutes on its laptop)
-- Aesir's number, and what Part IV's prefill does
to it."

DESIGN, stated up front (the J-094 doc is its
normative text; this header records the choices the
code embodies, PRE-REGISTERED before any J-094
number was produced):

- THE WITNESS IS THE LADDER'S. Every quantity is
  priced for J-091's dense mid-size witness,
  Qwen2.5-Coder-7B (28 layers, hidden 3584, ffn
  18944, 28 query heads, 4 kv heads, head_dim 128,
  vocab 152064, profile context cap 32768), at
  J-091's rungs 1024 / 4096 / 8192 / 16384 / 32768.
  Janas's published 15-minute laptop figure for a
  32k prompt read is Janas's number on Janas's
  machine, cited from its public documentation as
  recorded in the roadmap: it names the QUESTION
  (what does a 32k read cost?) and is never quoted
  as, or converted into, an Aesir figure.

- PROMPT READ, DEFINED (pre-registered). The prompt
  read at rung L is the PREFILL PASS over a raw
  prompt of exactly L tokens, cold, with no prefix
  reuse, ending when the KV of position L-1 is
  written. It is J-091's READ leg, priced in the
  currencies the tree's own modules define:
    WORK (MACs) = prefill attention MACs + prefill
      projection MACs, defined THROUGH
      core/kv_ladder (J-091) over
      core/prefill_anatomy (J-053). The one LM-head
      pass is NOT part of the read: on every dense
      surface the head is paid by the first
      GENERATED token (J-053 section 3.7; J-091's
      prefill projection column excludes it). It is
      priced separately (read_head_macs) as the
      first-token hand-off, so it is never lost and
      never double-charged.
    KV WRITTEN (bytes) = the KV the prompt leaves
      behind: ladder_kv_total at L, per precision
      (f16 through J-087, per-row int8 through
      J-088).
    KV READ SHAPE (bytes) = the prompt's own
      attention touches: per-token KV price x causal
      pairs, defined THROUGH core/attention_share
      (J-092's prefill traffic form). A by-
      construction TOUCH SHAPE, never a measured
      byte count: caches sit between it and any
      device.
    WEIGHT-PASS BYTES = passes x the sha-pinned
      file's bytes, passes from the surface's own
      plan in core/prefill_anatomy (J-053): the
      host batched plan (chunk cap 256) and the
      width-1 plans (host per-token fallback; the
      GPU line's Coder prefill, which is width-1 --
      the tile-4 form is admitted only for the
      exercised Llama 3.2 3B profile, J-091
      section 3, so NO tile-4 Coder account is
      filed). Same touch-shape honesty as KV reads.
    TOTAL TOUCH SHAPE = KV read shape + weight-pass
      bytes + KV written, per surface and precision.
      A sum of shapes, filed only under that name.
    PASSES AND SYNCS: device synchronised crossings
      are counted where the tree counts them -- the
      GPU width-1 line pays one per token (J-053
      section 3.8, J-055); the host surfaces pay no
      device synchronisation (0).
  Session context for a READ cell is L itself
  (J-091's session definition), so read verdicts
  and GPU read placement are judged at L, never at
  L + 128 (the write leg's session, J-091/J-093).

- VERDICTS AND PLACEMENT, INHERITED UNCHANGED. A
  read cell's verdict is ladder_cell_verdict at
  LADDER_READ (integration judged before caps):
  ACCOUNTED / CAP_REFUSED / INTEGRATION_BLOCKED
  mean exactly what J-091 defined. GPU read
  placement is ladder_gpu_required_bytes at context
  L through the tree's admission shape against the
  filed usable VRAM (5,368,709,120 B, J-031):
  WHOLE_GPU or SPILL_REQUIRED. The int8 columns are
  counterfactuals (CF) wherever they appear: int8
  is INTEGRATION_BLOCKED on both lines (J-091).

- WHAT PART IV DOES TO THE NUMBER, PRE-REGISTERED
  FORMS. Each Part IV prefill choice is priced as
  an exact delta on the account above, or stated
  as changing no accounted quantity:
    (a) HOST CHUNKING (J-053; exists today): chunk
      cap 256 vs the per-token fallback changes
      PASSES and therefore weight-pass bytes by
      exactly (L - ceil(L/256)) x file bytes; work,
      KV written and KV read shape are unchanged
      (batching changes pass counts and weight
      re-reads, never pair or projection counts --
      J-053). Its measured wall effect on another
      model (S-033, re-cited in J-053 section 6)
      is not an Aesir ladder wall and is not
      converted into one here.
    (b) J-054 GPU BLOCK PREFILL (UNBUILT -- M1..M7
      stand): its plan's account at width 256 is
      priced through core/gpu_block_prefill's own
      constants (chunks, one sync per chunk, 7
      batched GEMM calls per layer per chunk, 3
      per-row attention calls per token per layer,
      weight bytes = chunks x file bytes, admission
      UNBUILT). Work and KV quantities are
      unchanged by the plan; weight-pass bytes and
      syncs fall by the chunk factor. Because no
      executor exists, its effect on Aesir's read
      TODAY is exactly zero; the plan figure is a
      counterfactual, labelled CF wherever filed.
      The plan's activation-scratch and batched-
      scores fields are NOT filed for the witness:
      they need a DenseBufferLayout stride, and no
      layout exists for the Coder profile on that
      surface (that absence is part of M2).
    (c) J-055 WHOLE-LAYER DENSE ON GPU: at width 1
      it IS the GPU line's account -- the proven
      sessions run every layer of a token on the
      device at one sync per token -- so it changes
      NO accounted read quantity, and this module
      files no delta for it: the GPU line's passes
      and syncs ARE its account. Its fit verdicts
      govern whether a GPU line exists for a model
      at a context (J-091/J-093 price that), not
      what a read costs. The block form is (b)'s CF.
    (d) J-056 SPLIT PROMPT (not kept; executor
      S1..S3 unbuilt): priced through
      core/split_prompt's own plan and survival
      rule, with per-side weight bytes stated as
      the file's floor half / remainder (a stated
      synthetic split of a filed total, J-056's
      own precedent; the domination verdict does
      not rest on the halves' ratio) and the
      whole-GPU-parent flag taken from THIS
      slice's f16 read placement at the rung.
      J-056's rule grades REJECTED where the parent
      exists and PARENT-ABSENT where it does not;
      its accounted deltas are: work 0, weight
      bytes 0, crossings +2 per chunk against the
      GPU parent (3 per chunk against 1), join
      bytes = L x hidden x 4 added. Effect today:
      zero -- not kept, not built.
    (e) KV PRECISION (J-088's store; integration
      deferred): f16 -> int8 changes NO work
      quantity (MAC counts are precision-invariant,
      J-092) and changes KV written and KV read
      shape by exactly (57,344 - 29,568) = 27,776
      B/token x L (written) and x pairs (read
      shape); admission moves as J-091 filed.
  No other Part IV choice is priced, because no
  other Part IV slice defines a prefill quantity
  for this witness: J-057..J-070's live and design
  material changes no accounted field of this
  frame for the dense ladder witness (their MoE,
  NPU and gate material is a different witness or
  a deferred wall), and inventing a delta for them
  would be a new frame, which this slice refuses.

- TIME HONESTY, BINDING. This module contains no
  time and no speed, and NO wall is filed anywhere
  in this slice: converting accounted work or
  traffic into a claimed 32k read time needs a
  rate this road has not measured for this witness
  at this context, and fitting one from the
  record's Coder walls would cross placements
  (whole-GPU at 4096 vs spilled at 16384 -- the
  J-092 section 3 refusal, which stands). Every
  wall / live read is NOT PROVEN /
  DEFERRED-WITH-REASON to the J-098 gate, with the
  exact recipe in the J-094 doc (section 7).

HOST CONTRACT: (1) price every prompt-read claim
through this module, never from memory; (2) quote
a read with its rung, line, precision and surface
named -- an unnamed read account is a defect in
the claim; (3) a wall may be filed in a read cell
only from a live run under the J-094 doc section 7
recipe at the J-098 gate (guarded window, sha-pin,
machine state, ids-first raw-oracle grading,
never llama-cli --single-turn).
"""

from core.attention_share import (
    share_ppm,
    share_prefill_kv_shape_bytes,
    share_prefill_weight_pass_bytes,
)
from core.gpu_block_prefill import (
    ADMISSION_UNBUILT,
    ATTENTION_KERNELS_PER_ROW,
    PROJECTIONS_PER_LAYER,
)
from core.kv_ladder import (
    LADDER_PRECISION_F16,
    LADDER_PRECISION_INT8,
    LADDER_READ,
    ladder_cell_verdict,
    ladder_gpu_placement,
    ladder_gpu_required_bytes,
    ladder_head_macs,
    ladder_kv_bytes_per_token,
    ladder_kv_total,
    ladder_prefill_attention_macs,
    ladder_prefill_pairs,
    ladder_prefill_projection_macs,
)
from core.prefill_anatomy import (
    SURFACE_CUDA_WIDTH1,
    SURFACE_HOST_BATCHED,
    SURFACE_HOST_PER_TOKEN,
    plan_prefill_passes,
)
from core.split_prompt import (
    SplitPromptPlan,
    SplitVerdict,
    evaluate_split_accounting,
    plan_split_prompt,
)

# The host chunk cap the tree ships by default
# (AESIR_PREFILL_BATCH, J-053): the batched surface's
# graded width in every Part IV/V/VI account.
comptime READ_HOST_CAP = 256


def _check_rung(rung: Int) raises:
    if rung <= 0:
        raise Error("PromptRead: rung must be positive")


def read_work_attention(layers: Int, q_width: Int, rung: Int) raises -> Int:
    """The prompt's attention MACs (J-091/J-053)."""
    _check_rung(rung)
    return ladder_prefill_attention_macs(layers, q_width, rung)


def read_work_projection(
    layers: Int, hidden: Int, q_width: Int, kv_width: Int, ffn: Int, rung: Int
) raises -> Int:
    """The prompt's projection + FFN MACs (J-091/J-053).
    Excludes attention and the head, each priced
    separately so the split stays visible."""
    _check_rung(rung)
    return ladder_prefill_projection_macs(
        layers, hidden, q_width, kv_width, ffn, rung
    )


def read_work_total(
    layers: Int,
    hidden: Int,
    q_width: Int,
    kv_width: Int,
    ffn: Int,
    rung: Int,
) raises -> Int:
    """The prompt read's total accounted work:
    attention + projection. Surface- and
    precision-invariant by construction (J-053)."""
    return read_work_attention(layers, q_width, rung) + read_work_projection(
        layers, hidden, q_width, kv_width, ffn, rung
    )


def read_work_per_token(
    layers: Int,
    hidden: Int,
    q_width: Int,
    kv_width: Int,
    ffn: Int,
    rung: Int,
) raises -> Int:
    """Mean accounted work per prompt token: the
    total over the rung. Exact for this frame --
    the projection part is per-token constant and
    the attention part sums to unit x (L+1) / 2 per
    token with the unit always even (it carries the
    score + value factor 2)."""
    var total = read_work_total(layers, hidden, q_width, kv_width, ffn, rung)
    if total % rung != 0:
        raise Error("PromptRead: work total not divisible by the rung")
    return total // rung


def read_attention_share_ppm(
    layers: Int,
    hidden: Int,
    q_width: Int,
    kv_width: Int,
    ffn: Int,
    rung: Int,
) raises -> Int:
    """Attention's share of the READ work (head
    excluded per this slice's definition), floored
    ppm. J-092's prompt-average share is a
    different form (its rest includes the head);
    the two are filed under different names and
    differ by exactly that head pass."""
    return share_ppm(
        read_work_attention(layers, q_width, rung),
        read_work_projection(layers, hidden, q_width, kv_width, ffn, rung),
    )


def read_head_macs(hidden: Int, vocab: Int) raises -> Int:
    """The one LM-head pass the first generated
    token pays after the read (the first-token
    hand-off, J-053 section 3.7). NOT part of the
    read's work; priced so it is never lost."""
    return ladder_head_macs(hidden, vocab)


def read_kv_written(
    layers: Int, kv_heads: Int, head_dim: Int, precision: Int, rung: Int
) raises -> Int:
    """KV bytes the prompt leaves behind at the
    stated precision (through the ladder: J-087
    f16, J-088 per-row int8)."""
    _check_rung(rung)
    return ladder_kv_total(layers, kv_heads, head_dim, precision, rung)


def read_kv_read_shape(kv_bytes_per_token_value: Int, rung: Int) raises -> Int:
    """The prompt's KV-read touch shape (J-092's
    prefill traffic form, through attention_share)."""
    _check_rung(rung)
    return share_prefill_kv_shape_bytes(kv_bytes_per_token_value, rung)


def read_pairs(rung: Int) raises -> Int:
    """Causal (query, key) pairs in one layer over
    the prompt (J-053, through the ladder)."""
    _check_rung(rung)
    return ladder_prefill_pairs(rung)


def read_passes(surface: Int, rung: Int, cap: Int = READ_HOST_CAP) raises -> Int:
    """Passes one surface's own plan executes over
    the prompt (J-053, through prefill_anatomy)."""
    _check_rung(rung)
    var plan = plan_prefill_passes(surface, rung, cap)
    return plan.passes


def read_weight_pass_bytes(
    surface: Int, rung: Int, weights_bytes: Int, cap: Int = READ_HOST_CAP
) raises -> Int:
    """The prompt's weight-pass bytes on a surface
    (J-053/J-092: passes x the file's bytes)."""
    _check_rung(rung)
    return share_prefill_weight_pass_bytes(surface, rung, weights_bytes, cap)


def read_touch_shape(
    kv_bytes_per_token_value: Int,
    surface: Int,
    rung: Int,
    weights_bytes: Int,
    cap: Int = READ_HOST_CAP,
) raises -> Int:
    """Total touch shape of the read on one surface
    at one precision: KV read shape + weight-pass
    bytes + KV written. A sum of by-construction
    shapes, never a measured byte count."""
    _check_rung(rung)
    if kv_bytes_per_token_value <= 0:
        raise Error("PromptRead: KV per-token price must be positive")
    return (
        read_kv_read_shape(kv_bytes_per_token_value, rung)
        + read_weight_pass_bytes(surface, rung, weights_bytes, cap)
        + kv_bytes_per_token_value * rung
    )


def read_sync_crossings(
    surface: Int, rung: Int, cap: Int = READ_HOST_CAP
) raises -> Int:
    """Device synchronised crossings the read pays:
    the GPU width-1 line synchronises once per
    token (its pass count, J-053/J-055); the host
    surfaces synchronise no device (0)."""
    _check_rung(rung)
    if surface == SURFACE_CUDA_WIDTH1:
        return read_passes(surface, rung, cap)
    if surface == SURFACE_HOST_BATCHED or surface == SURFACE_HOST_PER_TOKEN:
        return 0
    raise Error("PromptRead: unknown read surface")


def read_verdict(
    line: Int,
    precision: Int,
    rung: Int,
    int8_cpu_integrated: Bool,
    int8_gpu_integrated: Bool,
    profile_cap: Int,
) raises -> Int:
    """A read cell's verdict is J-091's ladder
    verdict at LADDER_READ, unchanged."""
    _check_rung(rung)
    return ladder_cell_verdict(
        line,
        precision,
        rung,
        LADDER_READ,
        int8_cpu_integrated,
        int8_gpu_integrated,
        profile_cap,
    )


def read_gpu_required(
    weights_bytes: Int,
    kv_bytes_per_token_value: Int,
    rung: Int,
    activation_fixed_elements: Int,
    activation_per_context_elements: Int,
    sampling_bytes: Int,
) raises -> Int:
    """GPU admission total for the READ leg: the
    tree's shape (J-091) at session context = the
    rung itself."""
    _check_rung(rung)
    return ladder_gpu_required_bytes(
        weights_bytes,
        kv_bytes_per_token_value,
        rung,
        activation_fixed_elements,
        activation_per_context_elements,
        sampling_bytes,
    )


def read_gpu_placement(required_bytes: Int, usable_bytes: Int) raises -> Int:
    """WHOLE_GPU / SPILL_REQUIRED for a read total
    (J-091's placement, unchanged)."""
    return ladder_gpu_placement(required_bytes, usable_bytes)


def read_chunk_weight_delta(
    rung: Int, weights_bytes: Int, cap: Int = READ_HOST_CAP
) raises -> Int:
    """(a) Host chunking's exact weight effect:
    per-token weight-pass bytes minus batched
    weight-pass bytes at the stated cap. Work and
    KV deltas of chunking are exactly zero and are
    asserted in the tests, not returned here."""
    _check_rung(rung)
    if weights_bytes <= 0:
        raise Error("PromptRead: weights must be positive")
    return read_weight_pass_bytes(
        SURFACE_HOST_PER_TOKEN, rung, weights_bytes, cap
    ) - read_weight_pass_bytes(SURFACE_HOST_BATCHED, rung, weights_bytes, cap)


def read_precision_kv_written_delta(
    layers: Int, kv_heads: Int, head_dim: Int, rung: Int
) raises -> Int:
    """(e) f16 KV written minus int8 KV written at
    the rung: (57,344 - 29,568) x L for the
    witness, through the ladder at both precisions."""
    _check_rung(rung)
    return read_kv_written(
        layers, kv_heads, head_dim, LADDER_PRECISION_F16, rung
    ) - read_kv_written(layers, kv_heads, head_dim, LADDER_PRECISION_INT8, rung)


def read_precision_kv_shape_delta(
    layers: Int, kv_heads: Int, head_dim: Int, rung: Int
) raises -> Int:
    """(e) f16 KV read shape minus int8 KV read
    shape at the rung: the per-token saving times
    the causal pairs, through the ladder prices
    and J-092's shape."""
    _check_rung(rung)
    var f16_pt = ladder_kv_bytes_per_token(
        layers, kv_heads, head_dim, LADDER_PRECISION_F16
    )
    var i8_pt = ladder_kv_bytes_per_token(
        layers, kv_heads, head_dim, LADDER_PRECISION_INT8
    )
    return read_kv_read_shape(f16_pt, rung) - read_kv_read_shape(i8_pt, rung)


struct ReadBlockCf(Copyable, ImplicitlyCopyable):
    """(b) J-054's block-prefill plan account at one
    width, counterfactual (UNBUILT): the fields of
    core/gpu_block_prefill's plan that do not depend
    on a buffer-layout stride. The stride-dependent
    fields (activation scratch, batched scores) are
    not filed for the witness -- no Coder layout
    exists on that surface (M2)."""

    var chunks: Int
    var sync_crossings: Int
    var batched_gemm_calls: Int
    var per_row_attention_calls: Int
    var weight_read_bytes: Int
    var width1_weight_read_bytes: Int
    var admission: Int

    def __init__(
        out self,
        chunks: Int,
        sync_crossings: Int,
        batched_gemm_calls: Int,
        per_row_attention_calls: Int,
        weight_read_bytes: Int,
        width1_weight_read_bytes: Int,
        admission: Int,
    ):
        self.chunks = chunks
        self.sync_crossings = sync_crossings
        self.batched_gemm_calls = batched_gemm_calls
        self.per_row_attention_calls = per_row_attention_calls
        self.weight_read_bytes = weight_read_bytes
        self.width1_weight_read_bytes = width1_weight_read_bytes
        self.admission = admission


def read_block_cf(
    rung: Int, width: Int, layers: Int, weights_bytes: Int
) raises -> ReadBlockCf:
    """(b) The J-054 plan's account for the read at
    chunk width: chunks = ceil(L / width), one sync
    per chunk, batched GEMM calls = chunks x layers
    x PROJECTIONS_PER_LAYER, per-row attention
    calls = L x layers x ATTENTION_KERNELS_PER_ROW
    (attention does not batch -- J-053 F2, counted
    not hidden), weight bytes = chunks x file bytes
    against L x file bytes at width 1, admission
    UNBUILT at every width above the proven shapes
    (the tests cross-check every field against
    plan_gpu_block_prefill itself)."""
    _check_rung(rung)
    if width <= 0 or layers <= 0 or weights_bytes <= 0:
        raise Error("PromptRead: block CF shape must be positive")
    var chunks = (rung + width - 1) // width
    return ReadBlockCf(
        chunks,
        chunks,
        chunks * layers * PROJECTIONS_PER_LAYER,
        rung * layers * ATTENTION_KERNELS_PER_ROW,
        chunks * weights_bytes,
        rung * weights_bytes,
        ADMISSION_UNBUILT,
    )


def read_split_plan(
    rung: Int,
    width: Int,
    layers: Int,
    hidden: Int,
    q_width: Int,
    kv_width: Int,
    ffn: Int,
    weights_bytes: Int,
    whole_gpu_fits: Bool,
) raises -> SplitPromptPlan:
    """(d) J-056's split plan for the read, through
    core/split_prompt's own planner: per-side
    weight bytes stated as the file's floor half /
    remainder (a stated synthetic split of a filed
    total, J-056's precedent), the prompt's total
    MACs priced through the ladder (projection x L
    + the attention total -- the split plan's own
    conservation input), the boundary element the
    sessions' f32 hidden state (4 bytes)."""
    _check_rung(rung)
    if weights_bytes <= 0:
        raise Error("PromptRead: weights must be positive")
    var gpu_weights = weights_bytes // 2
    var cpu_weights = weights_bytes - gpu_weights
    var proj_pt = read_work_projection(layers, hidden, q_width, kv_width, ffn, 1)
    var attn = read_work_attention(layers, q_width, rung)
    return plan_split_prompt(
        rung,
        width,
        layers,
        hidden,
        4,
        proj_pt,
        attn,
        gpu_weights,
        cpu_weights,
        whole_gpu_fits,
    )


def read_split_verdict(plan: SplitPromptPlan) -> SplitVerdict:
    """(d) J-056's pre-registered survival rule,
    applied by its own module: REJECTED where the
    whole-GPU parent exists, PARENT-ABSENT where
    it does not, SURVIVES only on domination of
    both parents (which the conservation axes make
    impossible for this shape, J-056 section 6)."""
    return evaluate_split_accounting(plan)
