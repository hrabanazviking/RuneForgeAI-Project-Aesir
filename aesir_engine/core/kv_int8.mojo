"""8-bit KV cache: int8 keys and values with per-row scales
(Janas road J-088).

The roadmap text: "Keys and values stored at 8 bits with
per-row/per-channel scales (the shape Janas documents), as
an engine option beside the existing precision; dequant
cost measured inside attention."

DESIGN, stated up front (the J-088 doc is its normative
text; this header records the choices the code embodies):

- SCALE SHAPE. The primary shape is PER-ROW: one f32 scale
  per (layer, K-or-V, kv-head, position) row, covering that
  row's head_dim elements, with scale = maxabs / 127 (a zero
  row stores scale 1.0 and all-zero codes, so it round-trips
  exactly). This is exactly the shape J-087 section 7 priced
  as its projection -- one f32 scale per (layer, K/V,
  kv-head) row per token -- so this module's per-token price
  must reproduce J-087's 67,584 B/token for the Llama 3 8B
  shape, and its tests pin that identity against
  core/kv_account.mojo's kv_int8_projected_per_token. A
  PER-CHANNEL shape is also priced (one f32 scale per
  (layer, K/V, kv-head, channel), stored ONCE for the whole
  cache, not per token): its total is a separate function,
  because its scale bytes do not grow with context. The
  store built here implements the per-row shape; the
  per-channel shape is accounting-only in this slice (a
  channel scale cannot be known until a row has been seen
  or a calibration pass has run -- building it honestly is
  J-090's mixed-discipline question, not an append-time
  fact). No claim mixes the two shapes.
- LAYOUT mirrors the host cache (J-087 section 3.1): K and
  V are separate buffers, row-major
  [layer][position][kv_width]; scales are a separate buffer
  [layer][position][kv_head] per tensor. Nothing is
  interleaved, so a later session integration changes the
  element type and the append/read paths, not the geometry.
- SEMANTICS. append() quantizes on append (the f32/f16
  original is never stored); attention dequantizes INSIDE
  the attention loops, element by element, as each K/V
  element is consumed -- no dequantized copy of any row is
  materialised by the attention path. read_k/read_v exist
  for tests and grading (J-089), and are labelled as such:
  they are not the attention path.
- THE OPTION SURFACE, in the road's established shape
  (J-036/J-083): --kv-precision f16|int8 (env
  AESIR_KV_PRECISION) and --kv-scale per-row|per-channel
  (env AESIR_KV_SCALE), precedence cli > env > default,
  the default is f16 (the existing precision -- an int8
  default would silently change every faithfulness grade
  the tree stands on). Parsing, scanning and resolution
  live here; a per-channel selection RESOLVES but its use
  is refused by require_kv8_use's companion rule (see
  validate_kv8_selection): the store implements per-row
  only, and a configuration naming per-channel is refused
  at use with the reason, never silently run as per-row.
- WHAT THIS MODULE IS NOT. It wires into no live session:
  no session's execution code changes in this slice (the
  J-087 census found three distinct live layouts -- host,
  dense CUDA, Gemma 4 CUDA f32 -- and a session integration
  that cannot be exercised by a live run under this tick's
  machine limits must not be claimed). The store, its
  option surface, its accounting and its attention exercise
  are proven at module level; the exact session-integration
  recipe is filed in the J-088 doc section 7 for J-089/J-098
  to re-cite. The Gemma 4 CUDA f32 path -- where int8 saves
  most (4 bytes to 1) -- is priced in the accounting
  functions but its kernel integration is part of that same
  deferred recipe, not built here.

HOST CONTRACT: (1) resolve the option once through
resolve_kv_precision (chat and server surfaces call the
same resolver); (2) validate_kv8_selection before use --
int8+per-row is the only usable int8 selection today;
(3) price every byte claim through kv8_bytes_per_token /
kv8_total_bytes (per-row) or kv8_per_channel_total_bytes,
never from memory; (4) grade faithfulness through J-089's
teacher-forcing discipline, never from this module's
synthetic-vector exercises, which bound the quantizer and
nothing else.
"""

from std.ffi import external_call
from std.math import exp, sqrt
from std.memory import Pointer
from std.collections import InlineArray

from core.kv_account import (
    KV_ELEM_F16,
    KV_ELEM_F32,
    kv_bytes_per_token,
    kv_int8_projected_per_token,
)

comptime KV8_PRECISION_F16 = 0
comptime KV8_PRECISION_INT8 = 1

comptime KV8_SCALE_PER_ROW = 0
comptime KV8_SCALE_PER_CHANNEL = 1

comptime KV8_SOURCE_DEFAULT = 0
comptime KV8_SOURCE_ENV = 1
comptime KV8_SOURCE_CLI = 2

comptime KV8_SCALE_BYTES = 4  # one f32 per scale


def _abs32(x: Float32) -> Float32:
    return x if x >= Float32(0) else -x


def kv8_precision_name(code: Int) raises -> String:
    if code == KV8_PRECISION_F16:
        return String("f16")
    if code == KV8_PRECISION_INT8:
        return String("int8")
    raise Error("KVInt8: unknown precision code")


def kv8_precision_code(text: String) raises -> Int:
    var t = String(text.strip().lower())
    if t == "f16":
        return KV8_PRECISION_F16
    if t == "int8" or t == "i8":
        return KV8_PRECISION_INT8
    raise Error(
        "KVInt8: unknown KV precision '" + text + "' (options are f16, int8)"
    )


def kv8_scale_name(code: Int) raises -> String:
    if code == KV8_SCALE_PER_ROW:
        return String("per-row")
    if code == KV8_SCALE_PER_CHANNEL:
        return String("per-channel")
    raise Error("KVInt8: unknown scale mode code")


def kv8_scale_code(text: String) raises -> Int:
    var t = String(text.strip().lower())
    if t == "per-row" or t == "per_row" or t == "row":
        return KV8_SCALE_PER_ROW
    if t == "per-channel" or t == "per_channel" or t == "channel":
        return KV8_SCALE_PER_CHANNEL
    raise Error(
        "KVInt8: unknown KV scale mode '"
        + text
        + "' (options are per-row, per-channel)"
    )


def kv8_source_name(code: Int) raises -> String:
    if code == KV8_SOURCE_DEFAULT:
        return String("default")
    if code == KV8_SOURCE_ENV:
        return String("env")
    if code == KV8_SOURCE_CLI:
        return String("cli")
    raise Error("KVInt8: unknown source code")


# -- accounting -------------------------------------------------------


def kv8_bytes_per_token(
    layers: Int, kv_heads: Int, head_dim: Int
) raises -> Int:
    """Per-row int8 price per token: int8 payload plus one
    f32 scale per (layer, K/V, kv-head) row. Mechanically
    J-087's projection -- the two must agree exactly, and
    this function is defined through the census module so
    they cannot drift apart."""
    return kv_int8_projected_per_token(
        layers, kv_heads, head_dim, KV8_SCALE_BYTES
    )


def kv8_payload_per_token(
    layers: Int, kv_heads: Int, head_dim: Int
) raises -> Int:
    return kv_bytes_per_token(layers, kv_heads, head_dim, 1)


def kv8_scales_per_token(layers: Int, kv_heads: Int) raises -> Int:
    if layers <= 0 or kv_heads <= 0:
        raise Error("KVInt8: layers/kv_heads must be positive")
    return layers * 2 * kv_heads * KV8_SCALE_BYTES


def kv8_total_bytes(
    layers: Int, kv_heads: Int, head_dim: Int, context: Int
) raises -> Int:
    """Per-row total at a context: per-token price x context.
    No other metadata exists in the store: the struct's own
    fields are O(1) in context and are not charged per token
    (the same convention as J-087's census)."""
    if context <= 0:
        raise Error("KVInt8: context must be positive")
    return kv8_bytes_per_token(layers, kv_heads, head_dim) * context


def kv8_per_channel_total_bytes(
    layers: Int, kv_heads: Int, head_dim: Int, context: Int
) raises -> Int:
    """PER-CHANNEL accounting (priced, not built): payload
    grows per token; the scale table (one f32 per layer,
    K/V, kv-head, channel) is paid ONCE for the whole cache.
    """
    if context <= 0:
        raise Error("KVInt8: context must be positive")
    var payload = kv8_payload_per_token(layers, kv_heads, head_dim) * context
    var scales = layers * 2 * kv_heads * head_dim * KV8_SCALE_BYTES
    return payload + scales


def kv8_saving_vs_f16_per_token(
    layers: Int, kv_heads: Int, head_dim: Int
) raises -> Int:
    """Bytes saved per token against the f16 baseline of
    J-087 (positive for every real shape)."""
    return kv_bytes_per_token(
        layers, kv_heads, head_dim, KV_ELEM_F16
    ) - kv8_bytes_per_token(layers, kv_heads, head_dim)


def kv8_saving_vs_f32_per_token(
    layers: Int, kv_heads: Int, head_dim: Int
) raises -> Int:
    """Bytes saved per token against an f32 baseline (the
    Gemma 4 CUDA path's precision, J-087 section 3.3)."""
    return kv_bytes_per_token(
        layers, kv_heads, head_dim, KV_ELEM_F32
    ) - kv8_bytes_per_token(layers, kv_heads, head_dim)


# -- quantizer --------------------------------------------------------


def kv8_row_scale(maxabs: Float32) -> Float32:
    """The per-row scale: maxabs / 127; a zero row gets 1.0
    (its codes are all zero, so it round-trips exactly under
    any positive scale)."""
    if maxabs <= Float32(0):
        return Float32(1.0)
    return maxabs / Float32(127.0)


def kv8_quantize(x: Float32, scale: Float32) raises -> Int8:
    if scale <= Float32(0):
        raise Error("KVInt8: scale must be positive")
    var q = x / scale
    var r = Int(q + (Float32(0.5) if q >= Float32(0) else Float32(-0.5)))
    if r > 127:
        r = 127
    if r < -127:
        r = -127
    return Int8(r)


def kv8_dequantize(q: Int8, scale: Float32) -> Float32:
    return Float32(Int(q)) * scale


# -- the store --------------------------------------------------------


struct Int8KVStore(Copyable, Movable):
    """The int8 KV store (per-row scales), host layout.

    K and V are separate int8 buffers laid out
    [layer][position][kv_width]; scales are separate f32
    buffers laid out [layer][position][kv_head] per tensor.
    Fixed capacity, like the host KVCache it mirrors:
    append raises past capacity -- no wrap, no eviction.
    """

    var layers: Int
    var kv_heads: Int
    var head_dim: Int
    var kv_width: Int
    var max_seq_len: Int
    var k_data: List[Int8]
    var v_data: List[Int8]
    var k_scales: List[Float32]
    var v_scales: List[Float32]

    def __init__(
        out self,
        layers: Int,
        kv_heads: Int,
        head_dim: Int,
        max_seq_len: Int,
    ) raises:
        if layers <= 0 or kv_heads <= 0 or head_dim <= 0 or max_seq_len <= 0:
            raise Error("KVInt8: store dimensions must be positive")
        self.layers = layers
        self.kv_heads = kv_heads
        self.head_dim = head_dim
        self.kv_width = kv_heads * head_dim
        self.max_seq_len = max_seq_len
        var elems = layers * max_seq_len * self.kv_width
        var scales = layers * max_seq_len * kv_heads
        self.k_data = List[Int8]()
        self.k_data.resize(elems, Int8(0))
        self.v_data = List[Int8]()
        self.v_data.resize(elems, Int8(0))
        self.k_scales = List[Float32]()
        self.k_scales.resize(scales, Float32(1.0))
        self.v_scales = List[Float32]()
        self.v_scales.resize(scales, Float32(1.0))

    def bytes_per_token(self) raises -> Int:
        """Stored bytes per token of context, from this
        store's own buffers (payload + scales; must equal
        kv8_bytes_per_token for the same shape)."""
        var total = (
            len(self.k_data)
            + len(self.v_data)
            + (len(self.k_scales) + len(self.v_scales)) * KV8_SCALE_BYTES
        )
        return total // self.max_seq_len

    def total_bytes(self) -> Int:
        return (
            len(self.k_data)
            + len(self.v_data)
            + (len(self.k_scales) + len(self.v_scales)) * KV8_SCALE_BYTES
        )

    def _row_offset(self, layer: Int, pos: Int) -> Int:
        return (layer * self.max_seq_len + pos) * self.kv_width

    def _scale_offset(self, layer: Int, pos: Int) -> Int:
        return (layer * self.max_seq_len + pos) * self.kv_heads

    def append(
        mut self,
        layer: Int,
        pos: Int,
        key: List[Float32],
        val: List[Float32],
    ) raises:
        """Quantize-on-append: one token's K and V rows for
        one layer. Per kv-head, the scale is that head-slice's
        maxabs / 127, stored beside the codes."""
        if layer < 0 or layer >= self.layers:
            raise Error("KVInt8.append: layer out of bounds")
        if pos < 0 or pos >= self.max_seq_len:
            raise Error("KVInt8.append: pos exceeds fixed cache capacity")
        if len(key) < self.kv_width or len(val) < self.kv_width:
            raise Error("KVInt8.append: key/val width mismatch")
        var base = self._row_offset(layer, pos)
        var sbase = self._scale_offset(layer, pos)
        for h in range(self.kv_heads):
            var koff = base + h * self.head_dim
            var kmax = Float32(0)
            for j in range(self.head_dim):
                var a = _abs32(key[h * self.head_dim + j])
                if a > kmax:
                    kmax = a
            var kscale = kv8_row_scale(kmax)
            self.k_scales[sbase + h] = kscale
            for j in range(self.head_dim):
                self.k_data[koff + j] = kv8_quantize(
                    key[h * self.head_dim + j], kscale
                )
            var vmax = Float32(0)
            for j in range(self.head_dim):
                var a = _abs32(val[h * self.head_dim + j])
                if a > vmax:
                    vmax = a
            var vscale = kv8_row_scale(vmax)
            self.v_scales[sbase + h] = vscale
            for j in range(self.head_dim):
                self.v_data[koff + j] = kv8_quantize(
                    val[h * self.head_dim + j], vscale
                )

    def read_k(self, layer: Int, pos: Int) raises -> List[Float32]:
        """Dequantized K row (grading/test surface -- NOT the
        attention path, which dequantizes inside its loops)."""
        if layer < 0 or layer >= self.layers:
            raise Error("KVInt8.read_k: layer out of bounds")
        if pos < 0 or pos >= self.max_seq_len:
            raise Error("KVInt8.read_k: pos out of bounds")
        var out = List[Float32]()
        out.resize(self.kv_width, Float32(0))
        var base = self._row_offset(layer, pos)
        var sbase = self._scale_offset(layer, pos)
        for h in range(self.kv_heads):
            for j in range(self.head_dim):
                out[h * self.head_dim + j] = kv8_dequantize(
                    self.k_data[base + h * self.head_dim + j],
                    self.k_scales[sbase + h],
                )
        return out^

    def read_v(self, layer: Int, pos: Int) raises -> List[Float32]:
        if layer < 0 or layer >= self.layers:
            raise Error("KVInt8.read_v: layer out of bounds")
        if pos < 0 or pos >= self.max_seq_len:
            raise Error("KVInt8.read_v: pos out of bounds")
        var out = List[Float32]()
        out.resize(self.kv_width, Float32(0))
        var base = self._row_offset(layer, pos)
        var sbase = self._scale_offset(layer, pos)
        for h in range(self.kv_heads):
            for j in range(self.head_dim):
                out[h * self.head_dim + j] = kv8_dequantize(
                    self.v_data[base + h * self.head_dim + j],
                    self.v_scales[sbase + h],
                )
        return out^


# -- attention: dequantize-inside-attention ---------------------------


def attention_int8_head(
    store: Int8KVStore,
    layer: Int,
    kv_head: Int,
    query: List[Float32],
    seq_len: Int,
) raises -> List[Float32]:
    """Single-head causal attention over the int8 store.

    Scores and the output mix dequantize each K/V element at
    the moment it is consumed (element x its row scale,
    inside both loops); no dequantized row is materialised.
    Softmax is the standard max-subtracted form; the score
    scale is 1/sqrt(head_dim), as the tree's attention uses.
    """
    if layer < 0 or layer >= store.layers:
        raise Error("KVInt8.attention: layer out of bounds")
    if kv_head < 0 or kv_head >= store.kv_heads:
        raise Error("KVInt8.attention: kv_head out of bounds")
    if seq_len <= 0 or seq_len > store.max_seq_len:
        raise Error("KVInt8.attention: seq_len out of bounds")
    if len(query) < store.head_dim:
        raise Error("KVInt8.attention: query width mismatch")
    var hd = store.head_dim
    var scores = List[Float32]()
    scores.resize(seq_len, Float32(0))
    var inv = Float32(1.0) / sqrt(Float32(hd))
    var maximum = Float32(-3.4028235e38)
    for t in range(seq_len):
        var base = store._row_offset(layer, t) + kv_head * hd
        var scale = store.k_scales[store._scale_offset(layer, t) + kv_head]
        var total = Float32(0)
        for j in range(hd):
            total += query[j] * kv8_dequantize(store.k_data[base + j], scale)
        scores[t] = total * inv
        if scores[t] > maximum:
            maximum = scores[t]
    var denom = Float32(0)
    for t in range(seq_len):
        scores[t] = exp(scores[t] - maximum)
        denom += scores[t]
    var out = List[Float32]()
    out.resize(hd, Float32(0))
    for t in range(seq_len):
        var w = scores[t] / denom
        var base = store._row_offset(layer, t) + kv_head * hd
        var scale = store.v_scales[store._scale_offset(layer, t) + kv_head]
        for j in range(hd):
            out[j] += w * kv8_dequantize(store.v_data[base + j], scale)
    return out^


def attention_f32_head(
    keys: List[Float32],
    values: List[Float32],
    query: List[Float32],
    seq_len: Int,
    head_dim: Int,
) raises -> List[Float32]:
    """The same attention over plain f32 rows for ONE head:
    keys/values are [seq_len][head_dim] row-major. This is
    the reference the int8 path is exercised against -- the
    identical math with no quantization anywhere."""
    if seq_len <= 0 or head_dim <= 0:
        raise Error("KVInt8.attention_f32: shape must be positive")
    if len(keys) < seq_len * head_dim or len(values) < seq_len * head_dim:
        raise Error("KVInt8.attention_f32: rows width mismatch")
    if len(query) < head_dim:
        raise Error("KVInt8.attention_f32: query width mismatch")
    var scores = List[Float32]()
    scores.resize(seq_len, Float32(0))
    var inv = Float32(1.0) / sqrt(Float32(head_dim))
    var maximum = Float32(-3.4028235e38)
    for t in range(seq_len):
        var total = Float32(0)
        for j in range(head_dim):
            total += query[j] * keys[t * head_dim + j]
        scores[t] = total * inv
        if scores[t] > maximum:
            maximum = scores[t]
    var denom = Float32(0)
    for t in range(seq_len):
        scores[t] = exp(scores[t] - maximum)
        denom += scores[t]
    var out = List[Float32]()
    out.resize(head_dim, Float32(0))
    for t in range(seq_len):
        var w = scores[t] / denom
        for j in range(head_dim):
            out[j] += w * values[t * head_dim + j]
    return out^


# -- the option surface -----------------------------------------------


struct KvPrecisionChoice(Copyable, ImplicitlyCopyable):
    """One resolved KV precision selection, with its source."""

    var precision: Int
    var scale_mode: Int
    var precision_source: Int
    var scale_source: Int

    def __init__(out self):
        self.precision = KV8_PRECISION_F16
        self.scale_mode = KV8_SCALE_PER_ROW
        self.precision_source = KV8_SOURCE_DEFAULT
        self.scale_source = KV8_SOURCE_DEFAULT

    def describe(self) raises -> String:
        return (
            "kv_precision="
            + kv8_precision_name(self.precision)
            + "("
            + kv8_source_name(self.precision_source)
            + ") kv_scale="
            + kv8_scale_name(self.scale_mode)
            + "("
            + kv8_source_name(self.scale_source)
            + ")"
        )


struct RawKvInputs(Copyable, ImplicitlyCopyable):
    var precision: String
    var precision_set: Bool
    var scale: String
    var scale_set: Bool

    def __init__(out self):
        self.precision = String("")
        self.precision_set = False
        self.scale = String("")
        self.scale_set = False


def scan_kv_args(args: List[String]) raises -> RawKvInputs:
    """Scan argv for --kv-precision / --kv-scale (both
    `--flag value` and `--flag=value` forms). Flags outside
    this surface are ignored; a flag inside it that is
    unknown, valueless, or set twice is refused by name."""
    var raw = RawKvInputs()
    var i = 0
    while i < len(args):
        var arg = args[i]
        if not arg.startswith("--kv"):
            i += 1
            continue
        var eq = arg.find("=")
        var name = String(arg[byte=:eq]) if eq >= 0 else arg
        var value = String(arg[byte=eq + 1:]) if eq >= 0 else String("")
        if name != "--kv-precision" and name != "--kv-scale":
            raise Error(
                "KVInt8: unknown option '"
                + name
                + "' in the KV surface (options are --kv-precision,"
                + " --kv-scale)"
            )
        if eq < 0:
            if i + 1 >= len(args):
                raise Error(
                    "KVInt8: " + name + " requires a value, but none follows it"
                )
            value = args[i + 1]
            i += 1
        if name == "--kv-precision":
            if raw.precision_set:
                raise Error("KVInt8: --kv-precision is set twice; state it once")
            raw.precision = value
            raw.precision_set = True
        else:
            if raw.scale_set:
                raise Error("KVInt8: --kv-scale is set twice; state it once")
            raw.scale = value
            raw.scale_set = True
        i += 1
    return raw


def _kv_env_str(name: String) -> Tuple[Bool, String]:
    var buf = InlineArray[Int8, 32](fill=0)
    var bytes = name.as_bytes()
    if len(bytes) >= 32:
        return (False, String(""))
    for i in range(len(bytes)):
        buf[i] = Int8(bytes[i])
    var raw = external_call["getenv", Pointer[UInt8, MutUntrackedOrigin]](
        buf.unsafe_ptr()
    )
    if Int(raw) == 0:
        return (False, String(""))
    var value = String("")
    var i = 0
    while i < 256:
        var c = raw.unsafe_load(i)
        if c == 0:
            break
        value += chr(Int(c))
        i += 1
    return (True, value)


def kv_env_inputs() -> RawKvInputs:
    var raw = RawKvInputs()
    var p = _kv_env_str("AESIR_KV_PRECISION")
    if p[0]:
        raw.precision = p[1]
        raw.precision_set = True
    var s = _kv_env_str("AESIR_KV_SCALE")
    if s[0]:
        raw.scale = s[1]
        raw.scale_set = True
    return raw


def resolve_kv_precision(
    cli: RawKvInputs, env: RawKvInputs
) raises -> KvPrecisionChoice:
    """Resolve cli > env > default, per field. The default
    precision is f16 (the existing precision); the default
    scale mode is per-row."""
    var choice = KvPrecisionChoice()
    if env.precision_set:
        choice.precision = kv8_precision_code(env.precision)
        choice.precision_source = KV8_SOURCE_ENV
    if cli.precision_set:
        choice.precision = kv8_precision_code(cli.precision)
        choice.precision_source = KV8_SOURCE_CLI
    if env.scale_set:
        choice.scale_mode = kv8_scale_code(env.scale)
        choice.scale_source = KV8_SOURCE_ENV
    if cli.scale_set:
        choice.scale_mode = kv8_scale_code(cli.scale)
        choice.scale_source = KV8_SOURCE_CLI
    return choice


def validate_kv8_selection(choice: KvPrecisionChoice) raises:
    """The use gate for a resolved selection, stated plainly:
    f16 is always usable (it is the existing path); int8 is
    usable only with per-row scales -- the store built in
    this slice. int8 + per-channel is REFUSED at use with
    the reason (priced in this module, not built), never
    silently executed as per-row."""
    if choice.precision == KV8_PRECISION_F16:
        return
    if choice.precision == KV8_PRECISION_INT8 and (
        choice.scale_mode == KV8_SCALE_PER_ROW
    ):
        return
    if choice.precision == KV8_PRECISION_INT8:
        raise Error(
            "KVInt8: int8 with per-channel scales is priced but not built"
            " in J-088 (the store implements per-row scales); refusing"
            " rather than running it as per-row"
        )
    raise Error("KVInt8: unknown precision in selection")
