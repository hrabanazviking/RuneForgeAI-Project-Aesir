"""Attention share accounting (Janas road J-092).

The roadmap text: "Per-token time split (attention vs
the rest) across the ladder; where attention crosses
half the token cost, the optimisation target named
for later roads."

DESIGN, stated up front (the J-092 doc is its
normative text; this header records the choices the
code embodies, PRE-REGISTERED before any J-092 number
was produced):

- THE WITNESS IS J-091'S. Every quantity is priced
  for the ladder's dense mid-size witness,
  Qwen2.5-Coder-7B (28 layers, hidden 3584, ffn 18944,
  28 query heads, 4 kv heads, head_dim 128, vocab
  152064, profile context cap 32768), at J-091's
  rungs 1024 / 4096 / 8192 / 16384 / 32768, and every
  count is DEFINED THROUGH the tree's own accounting
  -- core/kv_ladder.mojo (J-091) over
  core/prefill_anatomy.mojo (J-053), core/kv_account
  (J-087) and core/kv_int8 (J-088) -- so no number in
  this slice can drift from the ladder frame it
  splits. The module is shape-generic; the tests pin
  the Coder values.

- "ATTENTION" AND "THE REST", DEFINED. ATTENTION work
  is the pair work of J-053's account only: per
  attended (query, key) pair per layer, q_width MACs
  for the score plus q_width for the weighted value
  sum -- layers x context x q_width x 2 for one token
  attending at a stated context. The Q/K/V and output
  PROJECTIONS are not attention in this account
  (J-053 prices them as projections, and this slice
  keeps that split so the numbers cannot drift). THE
  REST is everything else the MAC account prices:
  the per-token projection + FFN total of J-053
  (Q/K/V, attention output, gate/up/down), plus --
  where the token pays it -- the LM head pass
  (hidden x vocab). What the MAC account does not
  price is in NEITHER side, and is named, not hidden:
  softmax, norms, RoPE, sampler work, and (for int8
  KV) dequantization carry no MAC price in J-053's
  account; softmax in particular is per-pair
  non-MAC work, so the attention WORK shares filed
  here are a lower bound on attention's true share
  of any future time split. KV traffic is bytes, not
  MACs: it enters only the TRAFFIC shares below,
  never the work shares.

- THE WORK SPLITS, PER LEG. Three per-token forms,
  each an exact integer pair (attention, rest) whose
  share is attention / (attention + rest):
  (a) TOKEN-AT-CONTEXT (the marginal form): a token
      attending at context C pays attention
      unit x C, where unit = layers x q_width x 2.
      As a PREFILL token its rest is the projection
      total alone (a prompt pays the head once, not
      per token); as a DECODE token its rest is
      projection + head (every generated token pays
      the head). The two rests are filed separately
      and never mixed.
  (b) PROMPT-AVERAGE (the prefill leg's headline):
      the whole prompt's attention total (J-091's
      prefill attention MACs) against the whole
      prompt's rest (projection x L + one head pass),
      divided by nothing -- the share of the totals
      is the per-token average's share.
  (c) WRITE-LEG AVERAGE: J-091's write leg (128
      greedy tokens after the rung's prompt): its
      attention total (priced on the decode context
      sum) against 128 x the decode rest.
  Work shares are LINE-INVARIANT by construction:
  J-053's totals are surface-invariant (batching
  changes pass counts and weight re-reads, never the
  pair or projection counts), so the CPU and GPU
  lines share every work number in this slice. Where
  the lines differ by construction is TRAFFIC (below)
  and, unmeasured, TIME.

- THE TRAFFIC SPLITS, PER LEG, NEVER CONFLATED WITH
  WORK. A traffic share is KV-read bytes against
  weight-read bytes, each a by-construction TOUCH
  SHAPE in J-091's sense (caches at every level sit
  between the shape and any device; never a measured
  byte count):
  (a) DECODE, per token at context C: KV reads
      kv_bytes_per_token x C (J-091's per-token
      decode price, at the stated KV precision)
      against the weight set read once per token --
      the sha-pinned file's bytes, 4,683,074,688 B
      for the witness (width-1 decode streams the
      weights once per token on both lines, so this
      split is line-invariant too).
  (b) PREFILL, per prompt of length L: KV-read shape
      kv_bytes_per_token x causal pairs (each pair
      touches its position's K and V rows once, the
      same touch shape as decode, summed over the
      prompt) against weight-pass bytes in J-053's
      account (passes x file bytes, passes from the
      surface's own plan): the CPU line's host
      batched plan (chunk cap 256) amortizes the
      weights over a chunk, the GPU line's Coder
      prefill is WIDTH-1 (J-091 section 3: the
      tile-4 form is admitted only for the exercised
      Llama 3.2 3B profile), so the prefill traffic
      split is the one split in this slice that
      DIFFERS BY LINE, and it is filed per surface.

- THE CROSSING RULE, PRE-REGISTERED. A split CROSSES
  HALF at the smallest stated context (or prompt
  length) at which attention (work forms) or KV
  reads (traffic forms) are at least the rest /
  weight reads: attention >= rest, equality counts
  as crossed (a share of exactly 1/2 is half). Each
  crossing is solved EXACTLY from the closed forms
  (ceiling division for the linear forms, integer
  search for the prompt-average quadratic and the
  prefill-traffic step form) and filed as ACCOUNTED
  arithmetic. For the host-batched prefill traffic
  form the weight term is a step function of L
  (passes jump at chunk boundaries), so the share is
  a SAWTOOTH near the crossing: both the FIRST
  crossing and the PERMANENT crossing (the smallest
  L from which the split stays at or above half) are
  filed, with the re-dip between them named. The
  permanent crossing is scanned to L = 8192 in this
  module; the J-092 doc states (and its inspect
  verifies in Python to L = 1,000,000, plus the
  closed-form bound) why no re-dip can occur beyond
  the scanned range for the witness. For the GPU
  width-1 prefill traffic form the KV/weight ratio
  per prompt is kv_pt x (L+1) / (2 x weights),
  strictly increasing in L, so first == permanent by
  construction (stated, and inspect-checked).

- TIME HONESTY, BINDING. This module contains no
  time and no speed. A MAC share is NOT a time
  share: per-MAC costs differ between the attention
  and projection paths, between lines, and with
  batching (the GPU line's width-1 Coder prefill
  re-reads the weights per token, which inflates
  the rest's TIME without changing its MAC count).
  Every per-token TIME split is NOT PROVEN in this
  slice and is deferred with an exact recipe to the
  J-098 gate (J-092 doc section 7). No
  MEASURED-INDICATIVE time bound is filed either:
  the only filed Coder walls in the record (the
  wave/S-034-class rows re-cited in J-091 section 3)
  sit at different contexts under DIFFERENT
  placements (whole-GPU at 4096, spilled at 16384),
  so a two-point split fitted through them would
  attribute the placement change to attention --
  refused, and the refusal is part of this slice's
  record (doc section 5).

HOST CONTRACT: (1) price every attention-share claim
through this module, never from memory; (2) quote a
share with its form named (token-at-context /
prompt-average / write-leg average; work or traffic;
line and KV precision where they matter) -- an
unnamed share is a defect in the claim; (3) a TIME
split may be filed only from a live run under the
J-092 doc section 7 recipe at the J-098 gate.
"""

from core.kv_ladder import (
    LADDER_GEN_TOKENS,
    ladder_decode_attention_macs,
    ladder_decode_kv_read_bytes,
    ladder_head_macs,
    ladder_prefill_attention_macs,
    ladder_prefill_pairs,
    ladder_prefill_projection_macs,
)
from core.prefill_anatomy import (
    SURFACE_CUDA_WIDTH1,
    SURFACE_HOST_BATCHED,
    plan_prefill_passes,
    prefill_weight_pass_bytes,
)

# Scan bound for the host-batched prefill-traffic
# permanence scan (see the header): every witness
# crossing and re-dip lies far below it, and the
# doc's closed-form bound covers beyond it.
comptime SHARE_HOST_SCAN_BOUND = 8192
# Scan bound for first-crossing searches whose plan
# is O(1) per length (the width-1 surface) and for
# the host first crossing (found below 8192 there).
comptime SHARE_FIRST_SCAN_BOUND = 1048576


def _check_shape(layers: Int, q_width: Int) raises:
    if layers <= 0 or q_width <= 0:
        raise Error("AttentionShare: layers/q_width must be positive")


def _ceil_div(a: Int, b: Int) raises -> Int:
    if a <= 0 or b <= 0:
        raise Error("AttentionShare: ceil_div inputs must be positive")
    return (a + b - 1) // b


def share_attention_unit(layers: Int, q_width: Int) raises -> Int:
    """Attention MACs one token pays per attended
    position: layers x q_width x 2 (score + weighted
    value sum, J-053's per-pair price)."""
    _check_shape(layers, q_width)
    return layers * q_width * 2


def share_attention_macs_at_context(
    layers: Int, q_width: Int, context: Int
) raises -> Int:
    """Attention MACs of one token attending at the
    stated context (the token-at-context form)."""
    _check_shape(layers, q_width)
    if context <= 0:
        raise Error("AttentionShare: context must be positive")
    return share_attention_unit(layers, q_width) * context


def share_projection_macs_per_token(
    layers: Int, hidden: Int, q_width: Int, kv_width: Int, ffn: Int
) raises -> Int:
    """The per-token projection + FFN total, defined
    through J-091's ladder (itself J-053's account):
    the ladder's whole-prompt projection at rung 1."""
    return ladder_prefill_projection_macs(
        layers, hidden, q_width, kv_width, ffn, 1
    )


def share_head_macs(hidden: Int, vocab: Int) raises -> Int:
    """One LM-head pass (J-091/J-053)."""
    return ladder_head_macs(hidden, vocab)


def share_rest_prefill_token(
    layers: Int, hidden: Int, q_width: Int, kv_width: Int, ffn: Int
) raises -> Int:
    """A prefill token's rest: projections alone.
    The prompt's single head pass is charged in the
    prompt-average form, never per token."""
    return share_projection_macs_per_token(
        layers, hidden, q_width, kv_width, ffn
    )


def share_rest_decode_token(
    layers: Int,
    hidden: Int,
    q_width: Int,
    kv_width: Int,
    ffn: Int,
    vocab: Int,
) raises -> Int:
    """A decode token's rest: projections + the head
    pass every generated token pays."""
    return share_projection_macs_per_token(
        layers, hidden, q_width, kv_width, ffn
    ) + share_head_macs(hidden, vocab)


def share_prefill_attention_total(
    layers: Int, q_width: Int, rung: Int
) raises -> Int:
    """The whole prompt's attention MACs (J-091)."""
    return ladder_prefill_attention_macs(layers, q_width, rung)


def share_prefill_rest_total(
    layers: Int,
    hidden: Int,
    q_width: Int,
    kv_width: Int,
    ffn: Int,
    vocab: Int,
    rung: Int,
) raises -> Int:
    """The whole prompt's rest: projection x rung +
    one head pass."""
    if rung <= 0:
        raise Error("AttentionShare: rung must be positive")
    return (
        share_projection_macs_per_token(layers, hidden, q_width, kv_width, ffn)
        * rung
        + share_head_macs(hidden, vocab)
    )


def share_write_attention_total(
    layers: Int, q_width: Int, rung: Int, gen_tokens: Int
) raises -> Int:
    """The write leg's attention MACs (J-091, priced
    on the decode context sum)."""
    return ladder_decode_attention_macs(layers, q_width, rung, gen_tokens)


def share_write_rest_total(
    layers: Int,
    hidden: Int,
    q_width: Int,
    kv_width: Int,
    ffn: Int,
    vocab: Int,
    gen_tokens: Int,
) raises -> Int:
    """The write leg's rest: the decode rest, paid by
    every generated token."""
    if gen_tokens <= 0:
        raise Error("AttentionShare: gen_tokens must be positive")
    return (
        share_rest_decode_token(layers, hidden, q_width, kv_width, ffn, vocab)
        * gen_tokens
    )


def share_is_at_least_half(attention: Int, rest: Int) raises -> Bool:
    """The crossing predicate, pre-registered:
    attention >= rest (equality is half, crossed)."""
    if attention < 0 or rest <= 0:
        raise Error("AttentionShare: share inputs are invalid")
    return attention >= rest


def share_ppm(attention: Int, rest: Int) raises -> Int:
    """The share in parts per million, floored,
    computed EXACTLY in two steps so no intermediate
    exceeds Int64 for any total this road files
    (attention x 10000, remainder x 100)."""
    if attention < 0 or rest <= 0:
        raise Error("AttentionShare: share inputs are invalid")
    if attention > 9223372036854775807 // 10000:
        raise Error("AttentionShare: attention too large for exact ppm")
    var total = attention + rest
    if total > 9223372036854775807 // 100:
        raise Error("AttentionShare: total too large for exact ppm")
    var hi = attention * 10000 // total
    var rem = attention * 10000 % total
    return hi * 100 + rem * 100 // total


def share_marginal_crossing_context(
    layers: Int, hidden: Int, q_width: Int, kv_width: Int, ffn: Int
) raises -> Int:
    """Smallest context at which a PREFILL token's
    attention reaches its rest (projections alone):
    ceil(projection per token / attention unit)."""
    return _ceil_div(
        share_rest_prefill_token(layers, hidden, q_width, kv_width, ffn),
        share_attention_unit(layers, q_width),
    )


def share_decode_crossing_context(
    layers: Int,
    hidden: Int,
    q_width: Int,
    kv_width: Int,
    ffn: Int,
    vocab: Int,
) raises -> Int:
    """Smallest context at which a DECODE token's
    attention reaches its rest (projections + head):
    ceil(decode rest / attention unit)."""
    return _ceil_div(
        share_rest_decode_token(layers, hidden, q_width, kv_width, ffn, vocab),
        share_attention_unit(layers, q_width),
    )


def share_prefill_average_crossing(
    layers: Int,
    hidden: Int,
    q_width: Int,
    kv_width: Int,
    ffn: Int,
    vocab: Int,
) raises -> Int:
    """Smallest prompt length whose PROMPT-AVERAGE
    attention reaches the prompt's rest: integer
    binary search over the closed forms (attention
    grows quadratically, the rest linearly, so the
    predicate is monotone in L)."""
    _check_shape(layers, q_width)
    var lo = 1
    var hi = 4194304
    if not share_is_at_least_half(
        share_prefill_attention_total(layers, q_width, hi),
        share_prefill_rest_total(
            layers, hidden, q_width, kv_width, ffn, vocab, hi
        ),
    ):
        raise Error("AttentionShare: no average crossing within search bound")
    while lo < hi:
        var mid = (lo + hi) // 2
        if share_is_at_least_half(
            share_prefill_attention_total(layers, q_width, mid),
            share_prefill_rest_total(
                layers, hidden, q_width, kv_width, ffn, vocab, mid
            ),
        ):
            hi = mid
        else:
            lo = mid + 1
    return lo


def share_decode_kv_read_per_token(
    kv_bytes_per_token_value: Int, context: Int
) raises -> Int:
    """KV bytes one decode token at the stated
    context reads, defined through J-091's ladder
    (its write-leg price at gen 1 is the per-token
    price at that context)."""
    if kv_bytes_per_token_value <= 0 or context <= 0:
        raise Error("AttentionShare: KV price/context must be positive")
    return ladder_decode_kv_read_bytes(kv_bytes_per_token_value, context, 1)


def share_decode_traffic_crossing_context(
    kv_bytes_per_token_value: Int, weights_bytes: Int
) raises -> Int:
    """Smallest context at which a decode token's KV
    reads reach its weight reads (the file's bytes,
    streamed once per token): ceiling division."""
    if kv_bytes_per_token_value <= 0 or weights_bytes <= 0:
        raise Error("AttentionShare: KV price/weights must be positive")
    return _ceil_div(weights_bytes, kv_bytes_per_token_value)


def share_prefill_kv_shape_bytes(
    kv_bytes_per_token_value: Int, rung: Int
) raises -> Int:
    """The prompt's KV-read touch shape: the per-token
    KV price times the causal pairs (each pair
    touches its position's K and V rows once per
    layer -- J-091's decode touch shape summed over
    the prompt). A shape, never a measured count."""
    if kv_bytes_per_token_value <= 0:
        raise Error("AttentionShare: KV price must be positive")
    return kv_bytes_per_token_value * ladder_prefill_pairs(rung)


def share_prefill_weight_pass_bytes(
    surface: Int, rung: Int, weights_bytes: Int, cap: Int = 256
) raises -> Int:
    """The prompt's weight-pass bytes on a stated
    surface (J-053: passes from the surface's own
    plan, times the file's bytes)."""
    if weights_bytes <= 0:
        raise Error("AttentionShare: weights must be positive")
    var plan = plan_prefill_passes(surface, rung, cap)
    return prefill_weight_pass_bytes(plan.passes, weights_bytes)


def share_prefill_traffic_first_crossing(
    surface: Int, kv_bytes_per_token_value: Int, weights_bytes: Int, cap: Int = 256
) raises -> Int:
    """Smallest prompt length at which the prefill
    KV-read shape reaches the surface's weight-pass
    bytes. Linear scan (the host form is a sawtooth;
    no monotonicity is assumed)."""
    if kv_bytes_per_token_value <= 0 or weights_bytes <= 0:
        raise Error("AttentionShare: KV price/weights must be positive")
    for length in range(1, SHARE_FIRST_SCAN_BOUND + 1):
        if share_is_at_least_half(
            share_prefill_kv_shape_bytes(kv_bytes_per_token_value, length),
            share_prefill_weight_pass_bytes(surface, length, weights_bytes, cap),
        ):
            return length
    raise Error("AttentionShare: no prefill traffic crossing within scan bound")


def share_prefill_traffic_permanent_crossing_host(
    kv_bytes_per_token_value: Int, weights_bytes: Int, cap: Int = 256
) raises -> Int:
    """Host-batched form only: the smallest length
    from which the prefill traffic split stays at or
    above half, scanned to SHARE_HOST_SCAN_BOUND
    (one past the last length below half in range).
    The doc's closed-form bound covers beyond the
    scan; this function refuses rather than guess if
    the split has not crossed, or is still below
    half, inside the scanned range."""
    if kv_bytes_per_token_value <= 0 or weights_bytes <= 0:
        raise Error("AttentionShare: KV price/weights must be positive")
    var last_below = 0
    var crossed = False
    for length in range(1, SHARE_HOST_SCAN_BOUND + 1):
        if share_is_at_least_half(
            share_prefill_kv_shape_bytes(kv_bytes_per_token_value, length),
            share_prefill_weight_pass_bytes(
                SURFACE_HOST_BATCHED, length, weights_bytes, cap
            ),
        ):
            crossed = True
        else:
            last_below = length
    if not crossed:
        raise Error("AttentionShare: host traffic split never crosses in range")
    if last_below >= SHARE_HOST_SCAN_BOUND:
        raise Error("AttentionShare: host traffic split below half at scan bound")
    return last_below + 1
