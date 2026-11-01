"""Mixed-precision KV layouts: accounting and the keep
verdict (Janas road J-090).

The roadmap text: "Where 8-bit hurts (the layers/heads
J-089 indicts), a mixed layout (sensitive parts at higher
precision) tried and measured; kept only on evidence."

DESIGN, stated up front (the J-090 doc is its normative
text; this header records the choices the code embodies):

- WHAT A MIXED LAYOUT IS, in this module's terms. The
  uniform layouts are J-088's per-row int8 store (every
  K/V row at 8 bits, one f32 scale per row) and the f16
  baseline of J-087's census. A MIXED layout upgrades a
  stated subset of (layer, kv-head) row-pairs -- K and V
  counted separately, so a K-only or V-only upgrade is
  expressible -- to f16, and pays for each upgraded
  tensor-row exactly the difference between its f16 price
  (head_dim x 2 bytes, no scale: f16 needs none) and its
  int8 price (head_dim x 1 byte + one f32 scale). Every
  price in this module is defined through
  core/kv_int8.mojo and core/kv_account.mojo, so a mixed
  price cannot drift from the census or the store: the
  endpoints of every mixed price ARE those modules'
  numbers (zero upgrades == kv8_bytes_per_token; all
  upgrades == the f16 census price), and the tests pin
  both identities.

- THE KEEP RULE, PRE-REGISTERED (stated here and in the
  J-090 doc section 2 BEFORE any J-090 measurement was
  run; mixed_keep_verdict below is its mechanical form).
  A mixed layout is KEPT only if ALL of the following
  hold, on measured evidence at the level claimed:
    (R1) INDICTMENT: uniform int8 is indicted -- at the
         synthetic level, J-089's rule fired (attention
         max deviation above J-088's single-element
         bound B = 0.003937006 at some length, or a
         divergent proxy step), OR J-090's concentration
         measurement indicts a proper subset: a single
         head's max deviation above B with the max at
         least twice the median head's max, or one
         tensor (K-only or V-only) alone above B.
    (R2) RESTORATION: the candidate covering the indicted
         subset, exercised in the same measurement,
         brings the max deviation back to <= B.
    (R3) PRICE: the candidate's per-token overhead over
         uniform int8 is strictly less than half the
         per-token saving uniform int8 makes against
         f16 (the layout keeps more than half the
         saving it exists to protect).
  If no indictment exists, the verdict is NOT KEPT and
  no mixed store is built: a layout that repairs
  nothing measurable is not kept on speculation. This
  module therefore contains accounting and the verdict
  only -- no store, no option surface. Building those
  is conditional on a KEPT verdict under this rule,
  here or at a later gate on live evidence (the J-098
  gate re-cites J-089 section 7's live recipe; a live
  indictment there is judged by this same rule, with
  the live costing rule J-089 pre-registered).

- PER-CHANNEL, PRICED BESIDE. J-088 priced the
  per-channel scale shape (one f32 per layer, K/V,
  kv-head, channel, paid once) but did not build it:
  its scales need a calibration pass. This module adds
  the one comparison J-090 needs: the break-even
  context at which the once-paid table equals the
  per-row scales' growth -- exactly head_dim tokens
  for every shape, since the table is the per-token
  scale bytes times head_dim. Whether per-channel
  DEVIATION differs from per-row is a measurement
  question, answered synthetically by the J-090
  concentration harness under oracle calibration
  (scales computed over the whole sequence: an upper
  bound on per-channel quality, never an append-time
  claim).

HOST CONTRACT: (1) price every mixed claim through
this module, never from memory; (2) judge any keep
question -- synthetic or live -- through
mixed_keep_verdict with the indictment and restoration
facts stated beside it; (3) a NOT KEPT verdict builds
nothing: no store, no option, no default change.
"""

from core.kv_account import KV_ELEM_F16, kv_bytes_per_token
from core.kv_int8 import (
    KV8_SCALE_BYTES,
    kv8_bytes_per_token,
    kv8_payload_per_token,
    kv8_per_channel_total_bytes,
    kv8_scales_per_token,
)

comptime MIXED_NOT_KEPT_NO_INDICTMENT = 0
comptime MIXED_NOT_KEPT_NOT_RESTORED = 1
comptime MIXED_NOT_KEPT_PRICE = 2
comptime MIXED_KEPT = 3


def _check_shape(layers: Int, kv_heads: Int, head_dim: Int) raises:
    if layers <= 0 or kv_heads <= 0 or head_dim <= 0:
        raise Error("KVMixed: layers/kv_heads/head_dim must be positive")


def mixed_pair_delta_bytes(head_dim: Int) raises -> Int:
    """The per-token price of upgrading ONE tensor row
    (one of K or V, for one (layer, kv-head) pair) from
    per-row int8 to f16: head_dim x (2 - 1) payload bytes
    gained, minus the f32 scale the int8 row no longer
    needs. head_dim must exceed the scale bytes, or the
    'upgrade' would not cost anything and the layout
    arithmetic is degenerate."""
    if head_dim <= KV8_SCALE_BYTES:
        raise Error(
            "KVMixed: head_dim must exceed the scale bytes for a"
            " non-degenerate upgrade price"
        )
    return head_dim - KV8_SCALE_BYTES


def mixed_bytes_per_token(
    layers: Int,
    kv_heads: Int,
    head_dim: Int,
    f16_k_pairs: Int,
    f16_v_pairs: Int,
) raises -> Int:
    """Per-token price of a mixed layout: J-088's uniform
    per-row int8 price plus the upgrade delta for each
    stated (layer, kv-head) pair, K and V counted
    separately. f16_k_pairs / f16_v_pairs are counts of
    upgraded pairs for that tensor, each between 0 and
    layers x kv_heads inclusive."""
    _check_shape(layers, kv_heads, head_dim)
    var total_pairs = layers * kv_heads
    if f16_k_pairs < 0 or f16_k_pairs > total_pairs:
        raise Error("KVMixed: f16_k_pairs outside [0, layers*kv_heads]")
    if f16_v_pairs < 0 or f16_v_pairs > total_pairs:
        raise Error("KVMixed: f16_v_pairs outside [0, layers*kv_heads]")
    var base = kv8_bytes_per_token(layers, kv_heads, head_dim)
    var delta = mixed_pair_delta_bytes(head_dim)
    return base + (f16_k_pairs + f16_v_pairs) * delta


def mixed_total_bytes(
    layers: Int,
    kv_heads: Int,
    head_dim: Int,
    f16_k_pairs: Int,
    f16_v_pairs: Int,
    context: Int,
) raises -> Int:
    """Total at a context: per-token mixed price x
    context (the scales of upgraded rows are gone, the
    rest are per-token as in J-088; no other per-token
    metadata exists in the layout)."""
    if context <= 0:
        raise Error("KVMixed: context must be positive")
    return (
        mixed_bytes_per_token(layers, kv_heads, head_dim, f16_k_pairs, f16_v_pairs)
        * context
    )


def mixed_layers_bytes_per_token(
    layers: Int, kv_heads: Int, head_dim: Int, f16_layers: Int
) raises -> Int:
    """Convenience price: whole layers (every head, K
    and V) at f16, the rest per-row int8."""
    _check_shape(layers, kv_heads, head_dim)
    if f16_layers < 0 or f16_layers > layers:
        raise Error("KVMixed: f16_layers outside [0, layers]")
    var pairs = f16_layers * kv_heads
    return mixed_bytes_per_token(layers, kv_heads, head_dim, pairs, pairs)


def mixed_heads_bytes_per_token(
    layers: Int, kv_heads: Int, head_dim: Int, f16_heads: Int
) raises -> Int:
    """Convenience price: whole kv-heads (every layer, K
    and V) at f16, the rest per-row int8."""
    _check_shape(layers, kv_heads, head_dim)
    if f16_heads < 0 or f16_heads > kv_heads:
        raise Error("KVMixed: f16_heads outside [0, kv_heads]")
    var pairs = layers * f16_heads
    return mixed_bytes_per_token(layers, kv_heads, head_dim, pairs, pairs)


def mixed_overhead_vs_int8_per_token(
    layers: Int,
    kv_heads: Int,
    head_dim: Int,
    f16_k_pairs: Int,
    f16_v_pairs: Int,
) raises -> Int:
    """What the mixed layout gives back, per token,
    against uniform int8 (the R3 numerator)."""
    return mixed_bytes_per_token(
        layers, kv_heads, head_dim, f16_k_pairs, f16_v_pairs
    ) - kv8_bytes_per_token(layers, kv_heads, head_dim)


def mixed_saving_vs_f16_per_token(
    layers: Int,
    kv_heads: Int,
    head_dim: Int,
    f16_k_pairs: Int,
    f16_v_pairs: Int,
) raises -> Int:
    """What the mixed layout still saves, per token,
    against the f16 baseline of J-087."""
    return kv_bytes_per_token(
        layers, kv_heads, head_dim, KV_ELEM_F16
    ) - mixed_bytes_per_token(layers, kv_heads, head_dim, f16_k_pairs, f16_v_pairs)


def per_channel_break_even_context(
    layers: Int, kv_heads: Int, head_dim: Int
) raises -> Int:
    """The context at which J-088's per-channel shape
    (scale table paid once) costs exactly what the
    per-row shape's scales cost: the table is the
    per-token scale bytes times head_dim, so the
    break-even is exactly head_dim tokens for every
    shape. Below it per-row is cheaper in total; above
    it per-channel is."""
    _check_shape(layers, kv_heads, head_dim)
    var table = layers * 2 * kv_heads * head_dim * KV8_SCALE_BYTES
    var per_token = kv8_scales_per_token(layers, kv_heads)
    if table % per_token != 0:
        raise Error("KVMixed: per-channel table is not a whole number of contexts")
    var even = table // per_token
    # The identity, checked mechanically rather than
    # asserted: at the break-even the two totals agree.
    var payload = kv8_payload_per_token(layers, kv_heads, head_dim)
    if payload * even + table != kv8_bytes_per_token(
        layers, kv_heads, head_dim
    ) * even:
        raise Error("KVMixed: break-even identity does not close")
    if kv8_per_channel_total_bytes(layers, kv_heads, head_dim, even) != (
        payload * even + table
    ):
        raise Error("KVMixed: per-channel total disagrees at break-even")
    return even


def mixed_keep_verdict(
    indicted: Bool,
    restored: Bool,
    candidate_bytes_per_token: Int,
    int8_bytes_per_token: Int,
    f16_bytes_per_token: Int,
) raises -> Int:
    """The pre-registered keep rule (this module's
    header, R1-R3) in mechanical form. The caller states
    the measured facts: whether an indictment exists
    (R1) and whether this candidate restored the bound
    in the same exercise (R2); the prices are per-token
    bytes for the candidate and the two uniform layouts.
    A candidate must sit strictly between the uniforms
    -- an endpoint is not a mixed layout, and judging
    one here would be a category error, so it is
    refused by name."""
    if int8_bytes_per_token <= 0 or f16_bytes_per_token <= int8_bytes_per_token:
        raise Error("KVMixed: uniform prices must satisfy 0 < int8 < f16")
    if candidate_bytes_per_token <= int8_bytes_per_token:
        raise Error("KVMixed: candidate is not above uniform int8 (not mixed)")
    if candidate_bytes_per_token >= f16_bytes_per_token:
        raise Error("KVMixed: candidate is not below uniform f16 (not mixed)")
    if not indicted:
        return MIXED_NOT_KEPT_NO_INDICTMENT
    if not restored:
        return MIXED_NOT_KEPT_NOT_RESTORED
    var overhead = candidate_bytes_per_token - int8_bytes_per_token
    var saving = f16_bytes_per_token - int8_bytes_per_token
    if 2 * overhead >= saving:
        return MIXED_NOT_KEPT_PRICE
    return MIXED_KEPT


def mixed_verdict_name(code: Int) raises -> String:
    if code == MIXED_NOT_KEPT_NO_INDICTMENT:
        return String("NOT_KEPT_NO_INDICTMENT")
    if code == MIXED_NOT_KEPT_NOT_RESTORED:
        return String("NOT_KEPT_NOT_RESTORED")
    if code == MIXED_NOT_KEPT_PRICE:
        return String("NOT_KEPT_PRICE")
    if code == MIXED_KEPT:
        return String("KEPT")
    raise Error("KVMixed: unknown verdict code")
