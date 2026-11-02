"""Prefill at 8k account (Janas road J-068).

J-053 filed the prefill anatomy table at 256 / 1,024 / 4,096 /
8,192 tokens by construction, with every wall deferred. J-068
re-derives the 8,192 row with all of Part IV's work in, and this
module is the mechanical half of that re-derivation: it composes
J-053's own accounting (core/prefill_anatomy) at exactly 8,192
tokens and adds the three quantities the 8k row needs that no
earlier module states:

- attention_share_bp: attention's share of (projection +
  attention) MACs at the row's length, in basis points. At 8k
  this share is arch-dependent arithmetic, NOT a universal
  dominance claim: it is computed per arch from the row's own
  totals, and attention_dominates reports share > 50% only.
- context_verdict: whether an 8,192-token prompt fits a stated
  context cap at all, fits with room for a stated generation
  reserve, or is refused by the cap. A prompt equal to the cap
  fits as a fill but leaves no room to generate; a prompt above
  the cap is refused, mirroring the sessions' own fit checks.
- head_waste_macs: the LM-head MACs a width-1 MoE prompt pays
  on discarded results (J-053 finding F1): head passes beyond
  the first, priced at the stated per-pass figure. The planned
  chunk form (J-058) pays the head once, so its waste is zero
  by this same account.

What this module is NOT: it executes nothing, times nothing,
and contains no speed. Every wall, reading-speed, tok/s and
faithfulness figure at 8k remains a live measurement question,
deferred with its recipe in docs/janas/J068_PREFILL_AT_8K.md.

HOST CONTRACT: shape inputs come from the opened model's own
profile/directory exactly as in J-053's contract; the row is
stated for exactly 8,192 tokens and any other length is refused
here (other lengths are J-053's table, not this slice's).
"""

from core.prefill_anatomy import (
    plan_prefill_passes,
    prefill_attention_macs,
    prefill_attention_pairs,
    prefill_kv_bytes,
)

comptime EIGHT_K_TOKENS = 8192

# Context verdict codes for context_verdict.
comptime CTX_FITS = 0
comptime CTX_NO_GENERATION_ROOM = 1
comptime CTX_REFUSED = 2


def attention_share_bp(
    projection_macs_total: Int, attention_macs_total: Int
) raises -> Int:
    """Attention's share of projection+attention MACs, in basis
    points (floored). Both totals are the row's own; a zero or
    negative total is refused rather than divided."""
    if projection_macs_total <= 0 or attention_macs_total < 0:
        raise Error("PrefillAt8k: MAC totals must be positive / >= 0")
    var total = projection_macs_total + attention_macs_total
    return attention_macs_total * 10000 // total


def attention_dominates(
    projection_macs_total: Int, attention_macs_total: Int
) raises -> Bool:
    """True only when attention is strictly more than half of
    projection+attention MACs at this row. Per-arch arithmetic;
    never a blanket claim about 8k."""
    return attention_share_bp(projection_macs_total, attention_macs_total) > 5000


def context_verdict(
    prompt_tokens: Int, context_cap: Int, generation_reserve: Int
) raises -> Int:
    """Grade one prompt against one context cap: REFUSED when
    the prompt exceeds the cap; NO_GENERATION_ROOM when it fits
    but prompt + reserve exceeds the cap; FITS otherwise."""
    if prompt_tokens <= 0 or context_cap <= 0 or generation_reserve < 0:
        raise Error("PrefillAt8k: context inputs must be positive / >= 0")
    if prompt_tokens > context_cap:
        return CTX_REFUSED
    if prompt_tokens + generation_reserve > context_cap:
        return CTX_NO_GENERATION_ROOM
    return CTX_FITS


def context_verdict_name(code: Int) raises -> String:
    if code == CTX_FITS:
        return String("fits")
    if code == CTX_NO_GENERATION_ROOM:
        return String("fits_no_generation_room")
    if code == CTX_REFUSED:
        return String("refused_by_context")
    raise Error("PrefillAt8k: unknown context verdict code")


def head_waste_macs(head_macs_per_pass: Int, head_passes: Int) raises -> Int:
    """LM-head MACs spent on discarded results: every head pass
    beyond the first. One pass (every non-MoE surface, and the
    planned MoE chunk form) wastes zero by construction."""
    if head_macs_per_pass <= 0 or head_passes <= 0:
        raise Error("PrefillAt8k: head inputs must be positive")
    return head_macs_per_pass * (head_passes - 1)


struct EightKRow(Copyable, ImplicitlyCopyable):
    """One arch/surface row of the 8,192-token table, composed
    from J-053's accounting at exactly 8,192 tokens."""

    var passes: Int
    var pure_prefill_passes: Int
    var lm_head_passes: Int
    var kv_bytes_written: Int
    var causal_pairs_per_layer: Int
    var attention_macs: Int
    var projection_macs_total: Int
    var attention_share_bp: Int
    var head_waste_macs: Int

    def __init__(
        out self,
        passes: Int,
        pure_prefill_passes: Int,
        lm_head_passes: Int,
        kv_bytes_written: Int,
        causal_pairs_per_layer: Int,
        attention_macs: Int,
        projection_macs_total: Int,
        attention_share_bp: Int,
        head_waste_macs: Int,
    ):
        self.passes = passes
        self.pure_prefill_passes = pure_prefill_passes
        self.lm_head_passes = lm_head_passes
        self.kv_bytes_written = kv_bytes_written
        self.causal_pairs_per_layer = causal_pairs_per_layer
        self.attention_macs = attention_macs
        self.projection_macs_total = projection_macs_total
        self.attention_share_bp = attention_share_bp
        self.head_waste_macs = head_waste_macs


def plan_8k_row(
    surface: Int,
    cap: Int,
    layers: Int,
    q_width: Int,
    kv_bytes_per_token: Int,
    projection_macs_per_token: Int,
    head_macs_per_pass: Int,
    window: Int = 0,
) raises -> EightKRow:
    """Compose the 8,192-token row for one surface from J-053's
    accounting functions. window > 0 prices sliding-window
    attention pairs (a single-class row; hybrid models compose
    their classes by calling this per class, as J-053's Gemma 4
    row does)."""
    if layers <= 0 or q_width <= 0 or projection_macs_per_token <= 0:
        raise Error("PrefillAt8k: row shape must be positive")
    var plan = plan_prefill_passes(surface, EIGHT_K_TOKENS, cap)
    var attn = prefill_attention_macs(layers, q_width, EIGHT_K_TOKENS, window)
    var proj_total = projection_macs_per_token * EIGHT_K_TOKENS
    return EightKRow(
        plan.passes,
        plan.pure_prefill_passes,
        plan.lm_head_passes,
        prefill_kv_bytes(kv_bytes_per_token, EIGHT_K_TOKENS),
        prefill_attention_pairs(EIGHT_K_TOKENS, window),
        attn,
        proj_total,
        attention_share_bp(proj_total, attn),
        head_waste_macs(head_macs_per_pass, plan.lm_head_passes),
    )
