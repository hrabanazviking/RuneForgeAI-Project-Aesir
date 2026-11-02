"""LoRA merge at conversion: HF safetensors + a PEFT
LoRA adapter in, one merged GGUF out (Janas road
J-120).

The roadmap text: "LoRA merge at conversion. An HF
LoRA adapter merged into its base during conversion
to GGUF (the hf2gguf behaviour), merged weights
verified against the unmerged pair computed the slow
way." The J-119 census (rows C03/C04/C05/C10) found
Aesir had no safetensors parser, no GGUF writer, and
zero LoRA code; this layer is that build chain, in
Aesir's established shape (one pure layer that
decides and serialises; hosts execute). The J-120
doc (docs/janas/J120_LORA_MERGE_CONVERSION.md)
section 0 is the normative protocol: naming and
pairing rules, the merge arithmetic, the exact
verification rule, the storage rule, the C05 scope
decision, and the C10 mode are all pre-registered
there. No Janas material was consulted beyond the
road's own filed records; the merge convention is
the public PEFT/LoRA convention. No Janas source
code was opened.

THE CHAIN (this layer, in order):
- Safetensors reader: a whole file's bytes -> named
  Float32 tensors. Header = 8-byte little-endian
  length + JSON (a bounded scanner of this layer's
  own; the tree has no nested-JSON parser). Dtypes
  F32 / F16 / BF16 decode exactly (BF16 by bit
  extension, F16 by exact widening); any other
  dtype is refused by name. A matching emitter
  round-trips fixtures through the same format
  definition.
- Adapter config: rank r and lora_alpha read from
  the adapter config JSON by name; the merge scale
  is alpha / r.
- Pairing + merge: for base <stem>.weight the
  adapter pair is <stem>.lora_A[.default].weight /
  <stem>.lora_B[.default].weight (an optional
  base_model.model. prefix is stripped). A is
  [rank, in], B is [out, rank]; merged[i, j] =
  W[i, j] + (alpha/r) * sum_k B[i, k] * A[k, j],
  Float32, k increasing. Every refusal is by name:
  non-LoRA adapter tensor, incomplete pair, pair
  with no base tensor, rank/shape mismatch,
  non-2-D merge target, empty adapter (a non-LoRA
  checkpoint is refused, never silently converted
  plain).
- HF -> GGUF naming (llama subset, doc section
  0.4): unknown names refused by name.
- GGUF writer: GGUF v3 bytes mirroring
  loader/gguf.mojo's directory format (metadata,
  tensor directory, data at general.alignment =
  32, offsets relative to the aligned data start).
  Storage rule: 2-D tensors BF16 (round-to-nearest-
  even), 1-D tensors F32. Tensors over 2-D refused
  by name.
- C10 mode (--from-gguf): a BF16/F32 GGUF read
  back through this layer's directory reader,
  optionally merged, and re-emitted through the
  same writer; a quantized input tensor is refused
  by name.

C05 SCOPE (stated here as in the doc): this
converter is BF16-only. The post-conversion file
quantization leg is NOT built; lc_refuse_quantize
refuses any quantization request by name rather
than emitting BF16 under a quantized label.

J-121 EXTENSION (MTP preservation; the J-121 doc
section 0 is its normative protocol): a base tensor
whose name has no llama mapping above but classifies
as a prediction-head tensor under J-076's
pre-registered name rules (nextn / mtp / assistant,
mirrored by lc_mtp_head_kind below and proven to
agree with core/mtp_census.mojo's classifier) is
carried VERBATIM -- GGUF name == HF name, values
through the same storage rule -- and labelled twice:
by its own classifying name and by aesir.mtp.*
metadata emitted only when at least one head tensor
is present (head-free conversions emit exactly the
19 J-120 entries). lc_extract_mtp_block returns a
checkpoint's head tensors alone, for block-only
emission through the same writer. A name with no
mapping and no head classification is still refused
by name, exactly as J-120.
"""

from std.memory import bitcast

comptime LC_DTYPE_F32 = 0
comptime LC_DTYPE_F16 = 1
comptime LC_DTYPE_BF16 = 2
comptime LC_GGML_F32 = 0
comptime LC_GGML_BF16 = 30
comptime LC_MAX_TENSORS = 4096
comptime LC_MAX_ELEMENTS = 268435456
comptime LC_ALIGNMENT = 32


# ---------------------------------------------------------------------------
# Byte and string helpers (this layer imports nothing else)
# ---------------------------------------------------------------------------


def _lc_bytes_of(text: String) -> List[Byte]:
    var out = List[Byte]()
    var raw = text.as_bytes()
    for i in range(len(raw)):
        out.append(raw[i])
    return out^


def _lc_str_from_bytes(bytes: List[Byte]) -> String:
    """Proven idiom (J-109): NUL terminator +
    unsafe_from_utf8_ptr. String(List[Byte]) yields
    the debug representation in this toolchain."""
    var terminated = List[Byte]()
    for b in bytes:
        terminated.append(b)
    terminated.append(Byte(0))
    return String(unsafe_from_utf8_ptr=terminated.unsafe_ptr())


def _lc_str_slice(data: List[Byte], start: Int, stop: Int) -> String:
    var part = List[Byte]()
    for i in range(start, stop):
        part.append(data[i])
    return _lc_str_from_bytes(part)


def _lc_starts_with(text: String, prefix: String) -> Bool:
    var t = text.as_bytes()
    var p = prefix.as_bytes()
    if len(p) > len(t):
        return False
    for i in range(len(p)):
        if t[i] != p[i]:
            return False
    return True


def _lc_ends_with(text: String, suffix: String) -> Bool:
    var t = text.as_bytes()
    var s = suffix.as_bytes()
    if len(s) > len(t):
        return False
    var base = len(t) - len(s)
    for i in range(len(s)):
        if t[base + i] != s[i]:
            return False
    return True


def _lc_drop_prefix(text: String, count: Int) -> String:
    var raw = text.as_bytes()
    var part = List[Byte]()
    for i in range(count, len(raw)):
        part.append(raw[i])
    return _lc_str_from_bytes(part)


def _lc_drop_suffix(text: String, count: Int) -> String:
    var raw = text.as_bytes()
    var part = List[Byte]()
    for i in range(0, len(raw) - count):
        part.append(raw[i])
    return _lc_str_from_bytes(part)


def _lc_read_u16le(data: List[Byte], off: Int) raises -> Int:
    if off < 0 or off + 2 > len(data):
        raise Error("byte range out of bounds (u16 read)")
    return Int(data[off]) | (Int(data[off + 1]) << 8)


def _lc_read_u32le(data: List[Byte], off: Int) raises -> Int:
    if off < 0 or off + 4 > len(data):
        raise Error("byte range out of bounds (u32 read)")
    return (
        Int(data[off])
        | (Int(data[off + 1]) << 8)
        | (Int(data[off + 2]) << 16)
        | (Int(data[off + 3]) << 24)
    )


def _lc_read_u64le(data: List[Byte], off: Int) raises -> Int:
    if off < 0 or off + 8 > len(data):
        raise Error("byte range out of bounds (u64 read)")
    var v = 0
    for i in range(8):
        v |= Int(data[off + i]) << (8 * i)
    return v


def _lc_append_u16le(mut out: List[Byte], v: Int):
    out.append(Byte(v & 0xFF))
    out.append(Byte((v >> 8) & 0xFF))


def _lc_append_u32le(mut out: List[Byte], v: Int):
    for i in range(4):
        out.append(Byte((v >> (8 * i)) & 0xFF))


def _lc_append_u64le(mut out: List[Byte], v: Int):
    for i in range(8):
        out.append(Byte((v >> (8 * i)) & 0xFF))


def _lc_append_str_bytes(mut out: List[Byte], text: String):
    var raw = text.as_bytes()
    for i in range(len(raw)):
        out.append(raw[i])


# ---------------------------------------------------------------------------
# Float codecs (exact where the format is exact)
# ---------------------------------------------------------------------------


def lc_bf16_bits_to_f32(bits: Int) -> Float32:
    """Exact BF16 -> F32 widening (bit extension)."""
    return bitcast[DType.float32](UInt32(bits & 0xFFFF) << 16)


def lc_f32_to_bf16_bits(value: Float32) -> Int:
    """F32 -> BF16 with round-to-nearest-even, the
    writer's storage rounding."""
    var bits = Int(bitcast[DType.uint32](value))
    if (bits & 0x7F800000) == 0x7F800000 and (bits & 0x007FFFFF) != 0:
        # NaN: quiet it and truncate; never produced
        # by the merge of finite fixtures, kept total.
        return (bits >> 16) | 0x0040
    var lsb = (bits >> 16) & 1
    var rounded = bits + 0x00007FFF + lsb
    return (rounded >> 16) & 0xFFFF


def lc_f16_bits_to_f32(bits: Int) -> Float32:
    """Exact F16 -> F32 widening, all cases
    (subnormals, infinities, NaNs)."""
    var b = bits & 0xFFFF
    var sign = Float32(-1.0) if (b & 0x8000) != 0 else Float32(1.0)
    var exp = (b >> 10) & 0x1F
    var mant = b & 0x03FF
    if exp == 0:
        if mant == 0:
            return Float32(0.0) * sign
        # Subnormal: normalise by shifting.
        var m = mant
        var e = -14
        while (m & 0x0400) == 0:
            m <<= 1
            e -= 1
        m &= 0x03FF
        var v = Float32(1.0) + Float32(m) / Float32(1024.0)
        var p = Float32(1.0)
        var ae = e if e >= 0 else -e
        for _ in range(ae):
            p *= Float32(2.0)
        return sign * (v * p if e >= 0 else v / p)
    if exp == 31:
        if mant == 0:
            return sign * Float32(1.0) / Float32(0.0)
        return Float32(0.0) / Float32(0.0)
    var val = Float32(1.0) + Float32(mant) / Float32(1024.0)
    var e2 = exp - 15
    var p2 = Float32(1.0)
    var ae2 = e2 if e2 >= 0 else -e2
    for _ in range(ae2):
        p2 *= Float32(2.0)
    return sign * (val * p2 if e2 >= 0 else val / p2)


def lc_f32_to_f16_bits(value: Float32) -> Int:
    """F32 -> F16 with round-to-nearest-even (the
    safetensors emitter's F16 leg; fixtures only)."""
    var bits = Int(bitcast[DType.uint32](value))
    var sign = (bits >> 16) & 0x8000
    var exp = ((bits >> 23) & 0xFF) - 112
    var mant = bits & 0x007FFFFF
    if ((bits >> 23) & 0xFF) == 0xFF:
        if mant != 0:
            return sign | 0x7E00
        return sign | 0x7C00
    if exp >= 31:
        return sign | 0x7C00
    if exp <= 0:
        if exp < -10:
            return sign
        mant |= 0x00800000
        var shift = 14 - exp
        var lsb = (mant >> shift) & 1
        var rounded = mant + ((1 << (shift - 1)) - 1) + lsb
        return sign | (rounded >> shift)
    var lsb2 = (mant >> 13) & 1
    var rounded2 = mant + 0x00000FFF + lsb2
    if (rounded2 & 0x00800000) != 0:
        rounded2 = 0
        exp += 1
        if exp >= 31:
            return sign | 0x7C00
    return sign | (exp << 10) | (rounded2 >> 13)


def _lc_dtype_name(code: Int) -> String:
    if code == LC_DTYPE_F32:
        return String("F32")
    if code == LC_DTYPE_F16:
        return String("F16")
    return String("BF16")


def _lc_dtype_code(name: String) raises -> Int:
    if name == "F32":
        return LC_DTYPE_F32
    if name == "F16":
        return LC_DTYPE_F16
    if name == "BF16":
        return LC_DTYPE_BF16
    raise Error("safetensors dtype not supported for conversion: " + name)


def _lc_dtype_esize(code: Int) -> Int:
    return 4 if code == LC_DTYPE_F32 else 2


# ---------------------------------------------------------------------------
# Bounded JSON scanner (header + adapter config)
# ---------------------------------------------------------------------------


def _lc_json_ws(data: List[Byte], pos: Int) -> Int:
    var p = pos
    while p < len(data):
        var c = Int(data[p])
        if c == 32 or c == 9 or c == 10 or c == 13:
            p += 1
        else:
            break
    return p


def _lc_json_string(data: List[Byte], pos: Int) raises -> Tuple[String, Int]:
    """Parses a JSON string at pos (data[pos]=='"').
    Returns (value, next_pos). Escapes decoded for
    the common set; anything exotic refused."""
    if pos >= len(data) or Int(data[pos]) != 34:
        raise Error("JSON string expected")
    var out = List[Byte]()
    var p = pos + 1
    while p < len(data):
        var c = Int(data[p])
        if c == 34:
            return (_lc_str_from_bytes(out), p + 1)
        if c == 92:
            if p + 1 >= len(data):
                break
            var e = Int(data[p + 1])
            if e == 34:
                out.append(Byte(34))
            elif e == 92:
                out.append(Byte(92))
            elif e == 47:
                out.append(Byte(47))
            elif e == 110:
                out.append(Byte(10))
            elif e == 116:
                out.append(Byte(9))
            elif e == 114:
                out.append(Byte(13))
            else:
                raise Error("JSON string escape not supported in this scanner")
            p += 2
            continue
        out.append(data[p])
        p += 1
    raise Error("JSON string is not terminated")


def _lc_json_skip_value(data: List[Byte], pos: Int) raises -> Int:
    var p = _lc_json_ws(data, pos)
    if p >= len(data):
        raise Error("JSON value expected")
    var c = Int(data[p])
    if c == 34:
        var parsed = _lc_json_string(data, p)
        return parsed[1]
    if c == 123 or c == 91:
        var open_c = c
        var close_c = 125 if c == 123 else 93
        var depth = 0
        var i = p
        while i < len(data):
            var ch = Int(data[i])
            if ch == 34:
                var s = _lc_json_string(data, i)
                i = s[1]
                continue
            if ch == open_c:
                depth += 1
            elif ch == close_c:
                depth -= 1
                if depth == 0:
                    return i + 1
            i += 1
        raise Error("JSON value is not terminated")
    var i = p
    while i < len(data):
        var ch = Int(data[i])
        if ch == 44 or ch == 125 or ch == 93 or ch == 32 or ch == 9 or ch == 10 or ch == 13:
            break
        i += 1
    if i == p:
        raise Error("JSON value is empty")
    return i


def _lc_json_object_entries(
    data: List[Byte], pos: Int
) raises -> Tuple[List[String], List[Int], List[Int]]:
    """Parses the object at pos (data[pos]=='{').
    Returns (keys, value_starts, value_ends)."""
    var keys = List[String]()
    var starts = List[Int]()
    var ends = List[Int]()
    var p = _lc_json_ws(data, pos)
    if p >= len(data) or Int(data[p]) != 123:
        raise Error("JSON object expected")
    p = _lc_json_ws(data, p + 1)
    if p < len(data) and Int(data[p]) == 125:
        return (keys^, starts^, ends^)
    while True:
        p = _lc_json_ws(data, p)
        var k = _lc_json_string(data, p)
        keys.append(k[0])
        p = _lc_json_ws(data, k[1])
        if p >= len(data) or Int(data[p]) != 58:
            raise Error("JSON object entry is missing ':'")
        var vstart = _lc_json_ws(data, p + 1)
        var vend = _lc_json_skip_value(data, vstart)
        starts.append(vstart)
        ends.append(vend)
        p = _lc_json_ws(data, vend)
        if p < len(data) and Int(data[p]) == 44:
            p += 1
            continue
        if p < len(data) and Int(data[p]) == 125:
            return (keys^, starts^, ends^)
        raise Error("JSON object is not terminated")


def _lc_json_parse_int(data: List[Byte], pos: Int) raises -> Tuple[Int, Int]:
    var p = _lc_json_ws(data, pos)
    var neg = False
    if p < len(data) and Int(data[p]) == 45:
        neg = True
        p += 1
    var v = 0
    var digits = 0
    while p < len(data):
        var c = Int(data[p])
        if c < 48 or c > 57:
            break
        v = v * 10 + (c - 48)
        digits += 1
        p += 1
    if digits == 0:
        raise Error("JSON integer expected")
    return ((-v) if neg else v, p)


def _lc_json_parse_number(data: List[Byte], pos: Int) raises -> Tuple[Float32, Int]:
    """Parses a JSON number to Float32 (integer,
    fraction, exponent forms)."""
    var p = _lc_json_ws(data, pos)
    var neg = False
    if p < len(data) and Int(data[p]) == 45:
        neg = True
        p += 1
    var whole = Float32(0.0)
    var digits = 0
    while p < len(data) and 48 <= Int(data[p]) <= 57:
        whole = whole * Float32(10.0) + Float32(Int(data[p]) - 48)
        digits += 1
        p += 1
    var frac = Float32(0.0)
    var fscale = Float32(1.0)
    if p < len(data) and Int(data[p]) == 46:
        p += 1
        while p < len(data) and 48 <= Int(data[p]) <= 57:
            frac = frac * Float32(10.0) + Float32(Int(data[p]) - 48)
            fscale *= Float32(10.0)
            digits += 1
            p += 1
    if digits == 0:
        raise Error("JSON number expected")
    var v = whole + frac / fscale
    if p < len(data) and (Int(data[p]) == 101 or Int(data[p]) == 69):
        var ep = p + 1
        var eneg = False
        if ep < len(data) and (Int(data[ep]) == 45 or Int(data[ep]) == 43):
            eneg = Int(data[ep]) == 45
            ep += 1
        var ev = 0
        var edigits = 0
        while ep < len(data) and 48 <= Int(data[ep]) <= 57:
            ev = ev * 10 + (Int(data[ep]) - 48)
            edigits += 1
            ep += 1
        if edigits == 0:
            raise Error("JSON exponent is empty")
        var pv = Float32(1.0)
        for _ in range(ev):
            pv *= Float32(10.0)
        v = v / pv if eneg else v * pv
        p = ep
    return ((-v) if neg else v, p)


def _lc_entry_find(
    keys: List[String], starts: List[Int], ends: List[Int], want: String
) -> Tuple[Int, Int]:
    for i in range(len(keys)):
        if keys[i] == want:
            return (starts[i], ends[i])
    return (-1, -1)


# ---------------------------------------------------------------------------
# Tensors and the safetensors reader / emitter
# ---------------------------------------------------------------------------


struct LcTensor(Copyable):
    """One tensor decoded to Float32. dims is the
    source shape as listed (safetensors order:
    [out, in] for a 2-D weight)."""

    var name: String
    var dims: List[Int]
    var values: List[Float32]

    def __init__(out self, name: String, dims: List[Int], values: List[Float32]):
        self.name = name
        self.dims = dims.copy()
        self.values = values.copy()

    def __copyinit__(out self, existing: Self):
        self.name = existing.name
        self.dims = existing.dims.copy()
        self.values = existing.values.copy()

    def element_count(self) -> Int:
        var n = 1
        for d in self.dims:
            n *= d
        return n


def _lc_decode_values(
    data: List[Byte], start: Int, count: Int, dtype: Int
) raises -> List[Float32]:
    var out = List[Float32]()
    if dtype == LC_DTYPE_F32:
        for i in range(count):
            var bits = _lc_read_u32le(data, start + 4 * i)
            out.append(bitcast[DType.float32](UInt32(bits)))
    elif dtype == LC_DTYPE_BF16:
        for i in range(count):
            var bits = _lc_read_u16le(data, start + 2 * i)
            out.append(lc_bf16_bits_to_f32(bits))
    else:
        for i in range(count):
            var bits = _lc_read_u16le(data, start + 2 * i)
            out.append(lc_f16_bits_to_f32(bits))
    return out^


def _lc_encode_values(
    mut out: List[Byte], values: List[Float32], dtype: Int
):
    if dtype == LC_DTYPE_F32:
        for v in values:
            _lc_append_u32le(out, Int(bitcast[DType.uint32](v)))
    elif dtype == LC_DTYPE_BF16:
        for v in values:
            _lc_append_u16le(out, lc_f32_to_bf16_bits(v))
    else:
        for v in values:
            _lc_append_u16le(out, lc_f32_to_f16_bits(v))


def lc_parse_safetensors(data: List[Byte]) raises -> List[LcTensor]:
    """Reads one safetensors file (whole bytes) to
    Float32 tensors. Refusals are by name: bad
    magic length, unsupported dtype, offsets that
    disagree with shape/dtype, truncation, overlap,
    duplicate tensor names."""
    if len(data) < 8:
        raise Error("safetensors file is smaller than its header length prefix")
    var hlen = _lc_read_u64le(data, 0)
    if hlen <= 0 or 8 + hlen > len(data):
        raise Error("safetensors header length exceeds the file (truncated header)")
    var header = List[Byte]()
    for i in range(8, 8 + hlen):
        header.append(data[i])
    var entries = _lc_json_object_entries(header, 0)
    var keys = entries[0].copy()
    var starts = entries[1].copy()
    var data_base = 8 + hlen
    var tensors = List[LcTensor]()
    var ranges = List[Tuple[Int, Int]]()
    var names = List[String]()
    for ei in range(len(keys)):
        var name = String(keys[ei])
        if name == "__metadata__":
            continue
        if name in names:
            raise Error("safetensors contains a duplicate tensor name: " + name)
        names.append(name)
        var vs = starts[ei]
        var inner = _lc_json_object_entries(header, vs)
        var ikeys = inner[0].copy()
        var istarts = inner[1].copy()
        var iends = inner[2].copy()
        var dpos = _lc_entry_find(ikeys, istarts, iends, "dtype")
        var spos = _lc_entry_find(ikeys, istarts, iends, "shape")
        var opos = _lc_entry_find(ikeys, istarts, iends, "data_offsets")
        if dpos[0] < 0 or spos[0] < 0 or opos[0] < 0:
            raise Error("safetensors tensor entry is incomplete: " + name)
        var dtype_str = _lc_json_string(header, dpos[0])[0]
        var dtype = _lc_dtype_code(dtype_str)
        var dims = List[Int]()
        var sp = _lc_json_ws(header, spos[0])
        if sp >= len(header) or Int(header[sp]) != 91:
            raise Error("safetensors shape is not an array: " + name)
        sp += 1
        sp = _lc_json_ws(header, sp)
        if sp < len(header) and Int(header[sp]) == 93:
            sp += 1
        else:
            while True:
                var dim = _lc_json_parse_int(header, sp)
                dims.append(dim[0])
                sp = _lc_json_ws(header, dim[1])
                if sp < len(header) and Int(header[sp]) == 44:
                    sp += 1
                    continue
                if sp < len(header) and Int(header[sp]) == 93:
                    sp += 1
                    break
                raise Error("safetensors shape array is not terminated: " + name)
        var count = 1
        for d in dims:
            if d <= 0:
                raise Error("safetensors tensor has a non-positive dimension: " + name)
            count *= d
        if count > LC_MAX_ELEMENTS:
            raise Error("safetensors tensor exceeds the conversion element bound: " + name)
        var op = _lc_json_ws(header, opos[0])
        if op >= len(header) or Int(header[op]) != 91:
            raise Error("safetensors data_offsets is not an array: " + name)
        var begin = _lc_json_parse_int(header, op + 1)
        var comma = _lc_json_ws(header, begin[1])
        if comma >= len(header) or Int(header[comma]) != 44:
            raise Error("safetensors data_offsets must hold two integers: " + name)
        var finish = _lc_json_parse_int(header, comma + 1)
        var obegin = begin[0]
        var oend = finish[0]
        var want_bytes = count * _lc_dtype_esize(dtype)
        if obegin < 0 or oend - obegin != want_bytes:
            raise Error(
                "safetensors tensor data_offsets disagree with shape/dtype: " + name
            )
        if data_base + oend > len(data):
            raise Error("safetensors tensor data is truncated: " + name)
        for r in ranges:
            if obegin < r[1] and r[0] < oend:
                raise Error("safetensors tensor data ranges overlap: " + name)
        ranges.append((obegin, oend))
        var values = _lc_decode_values(data, data_base + obegin, count, dtype)
        tensors.append(LcTensor(name, dims, values))
    if len(tensors) > LC_MAX_TENSORS:
        raise Error("safetensors tensor count exceeds the conversion bound")
    return tensors^


def _lc_json_safe_name(name: String) raises:
    var raw = name.as_bytes()
    if len(raw) == 0:
        raise Error("tensor name must not be empty")
    for i in range(len(raw)):
        var c = Int(raw[i])
        var ok = (
            (48 <= c <= 57) or (65 <= c <= 90) or (97 <= c <= 122)
            or c == 46 or c == 95 or c == 45 or c == 47
        )
        if not ok:
            raise Error("tensor name is not JSON-safe for the emitter: " + name)


def lc_build_safetensors(tensors: List[LcTensor], dtype: Int) raises -> List[Byte]:
    """Emits a safetensors file holding every tensor
    at the one given dtype (fixtures/round-trips)."""
    var header = String("{")
    var offset = 0
    for ti in range(len(tensors)):
        var t = tensors[ti].copy()
        _lc_json_safe_name(t.name)
        if ti > 0:
            header += ","
        header += "\"" + t.name + "\":{\"dtype\":\"" + _lc_dtype_name(dtype)
        header += "\",\"shape\":["
        for di in range(len(t.dims)):
            if di > 0:
                header += ","
            header += String(t.dims[di])
        var nbytes = t.element_count() * _lc_dtype_esize(dtype)
        header += "],\"data_offsets\":[" + String(offset) + "," + String(offset + nbytes) + "]}"
        offset += nbytes
    header += "}"
    var out = List[Byte]()
    _lc_append_u64le(out, header.byte_length())
    _lc_append_str_bytes(out, header)
    for ti in range(len(tensors)):
        _lc_encode_values(out, tensors[ti].values, dtype)
    return out^


# ---------------------------------------------------------------------------
# Adapter config, pairing, and the merge
# ---------------------------------------------------------------------------


struct LcAdapterConfig(Copyable):
    """The two adapter-config values the merge
    needs, read by name from adapter_config.json."""

    var rank: Int
    var alpha: Float32

    def __init__(out self, rank: Int, alpha: Float32):
        self.rank = rank
        self.alpha = alpha

    def __copyinit__(out self, existing: Self):
        self.rank = existing.rank
        self.alpha = existing.alpha

    def scale(self) -> Float32:
        return self.alpha / Float32(self.rank)


def lc_parse_adapter_config(text: String) raises -> LcAdapterConfig:
    var data = _lc_bytes_of(text)
    var entries = _lc_json_object_entries(data, 0)
    var keys = entries[0].copy()
    var starts = entries[1].copy()
    var ends = entries[2].copy()
    var rpos = _lc_entry_find(keys, starts, ends, "r")
    if rpos[0] < 0:
        raise Error("adapter config is missing required key: r")
    var rank_f = _lc_json_parse_number(data, rpos[0])
    var rank = Int(rank_f[0])
    if Float32(rank) != rank_f[0] or rank <= 0:
        raise Error("adapter config rank must be a positive integer: r")
    var apos = _lc_entry_find(keys, starts, ends, "lora_alpha")
    if apos[0] < 0:
        raise Error("adapter config is missing required key: lora_alpha")
    var alpha = _lc_json_parse_number(data, apos[0])[0]
    if alpha <= Float32(0.0):
        raise Error("adapter config alpha must be positive: lora_alpha")
    return LcAdapterConfig(rank, alpha)


def _lc_adapter_kind(
    name: String,
) -> Tuple[String, Int]:
    """Classifies one adapter tensor name. Returns
    (stem, kind): kind 1 = lora_A, 2 = lora_B,
    0 = not a LoRA tensor. The stem is the adapted
    base name without its .weight suffix."""
    var n = name
    if _lc_starts_with(n, "base_model.model."):
        n = _lc_drop_prefix(n, String("base_model.model.").byte_length())
    var suffixes_a = List[String]()
    suffixes_a.append(".lora_A.default.weight")
    suffixes_a.append(".lora_A.weight")
    var suffixes_b = List[String]()
    suffixes_b.append(".lora_B.default.weight")
    suffixes_b.append(".lora_B.weight")
    for s in suffixes_a:
        if _lc_ends_with(n, s):
            return (_lc_drop_suffix(n, s.byte_length()), 1)
    for s in suffixes_b:
        if _lc_ends_with(n, s):
            return (_lc_drop_suffix(n, s.byte_length()), 2)
    return (String(""), 0)


def _lc_shape_str(dims: List[Int]) -> String:
    var out = String("[")
    for i in range(len(dims)):
        if i > 0:
            out += ","
        out += String(dims[i])
    out += "]"
    return out


struct LcMergeReport(Copyable):
    var merged_names: List[String]
    var passed_names: List[String]

    def __init__(out self):
        self.merged_names = List[String]()
        self.passed_names = List[String]()

    def __copyinit__(out self, existing: Self):
        self.merged_names = existing.merged_names.copy()
        self.passed_names = existing.passed_names.copy()


def lc_merge_model(
    base: List[LcTensor], adapter: List[LcTensor], cfg: LcAdapterConfig
) raises -> Tuple[List[LcTensor], LcMergeReport]:
    """Merges the adapter into a copy of the base
    tensor list (HF names on both sides). The merge
    arithmetic is the protocol's: merged[i, j] =
    W[i, j] + (alpha/r) * sum_k B[i,k] * A[k,j],
    Float32, k increasing."""
    if len(adapter) == 0:
        raise Error(
            "LoRA merge refused: adapter contains no tensors"
            " (non-LoRA checkpoint)"
        )
    var stems = List[String]()
    var a_index = List[Int]()
    var b_index = List[Int]()
    for ai in range(len(adapter)):
        var cls = _lc_adapter_kind(adapter[ai].name)
        if cls[1] == 0:
            raise Error(
                "LoRA merge refused: adapter tensor is not a LoRA tensor: "
                + adapter[ai].name
            )
        var at = -1
        for si in range(len(stems)):
            if stems[si] == cls[0]:
                at = si
                break
        if at < 0:
            stems.append(cls[0])
            a_index.append(-1)
            b_index.append(-1)
            at = len(stems) - 1
        if cls[1] == 1:
            if a_index[at] >= 0:
                raise Error(
                    "LoRA merge refused: duplicate lora_A for " + cls[0] + ".weight"
                )
            a_index[at] = ai
        else:
            if b_index[at] >= 0:
                raise Error(
                    "LoRA merge refused: duplicate lora_B for " + cls[0] + ".weight"
                )
            b_index[at] = ai
    if len(stems) == 0:
        raise Error(
            "LoRA merge refused: no LoRA adapter tensors found"
            " (non-LoRA checkpoint)"
        )
    var out = List[LcTensor]()
    for t in base:
        out.append(t.copy())
    var report = LcMergeReport()
    var targeted = List[Bool]()
    for _ in range(len(out)):
        targeted.append(False)
    var scale = cfg.scale()
    for si in range(len(stems)):
        if a_index[si] < 0:
            raise Error(
                "LoRA merge refused: adapter pair incomplete for "
                + stems[si] + ".weight: missing lora_A"
            )
        if b_index[si] < 0:
            raise Error(
                "LoRA merge refused: adapter pair incomplete for "
                + stems[si] + ".weight: missing lora_B"
            )
        var want_base = stems[si] + ".weight"
        var bi = -1
        for i in range(len(out)):
            if out[i].name == want_base:
                bi = i
                break
        if bi < 0:
            raise Error(
                "LoRA merge refused: adapter pair has no base tensor: " + want_base
            )
        var w = out[bi].copy()
        var a = adapter[a_index[si]].copy()
        var b = adapter[b_index[si]].copy()
        if len(w.dims) != 2:
            raise Error(
                "LoRA merge refused: merge target is not a 2-D tensor: " + want_base
            )
        if len(a.dims) != 2 or len(b.dims) != 2:
            raise Error(
                "LoRA merge refused: rank mismatch for " + want_base
                + ": A " + _lc_shape_str(a.dims) + " B " + _lc_shape_str(b.dims)
                + " base " + _lc_shape_str(w.dims)
                + " configured rank " + String(cfg.rank)
            )
        if a.dims[0] != cfg.rank or b.dims[1] != cfg.rank or a.dims[1] != w.dims[1] or b.dims[0] != w.dims[0]:
            raise Error(
                "LoRA merge refused: rank mismatch for " + want_base
                + ": A " + _lc_shape_str(a.dims) + " B " + _lc_shape_str(b.dims)
                + " base " + _lc_shape_str(w.dims)
                + " configured rank " + String(cfg.rank)
            )
        var rows = w.dims[0]
        var cols = w.dims[1]
        var rank = cfg.rank
        var merged = List[Float32]()
        for i in range(rows):
            for j in range(cols):
                var acc = Float32(0.0)
                for k in range(rank):
                    acc += b.values[i * rank + k] * a.values[k * cols + j]
                merged.append(w.values[i * cols + j] + scale * acc)
        out[bi] = LcTensor(w.name, w.dims, merged)
        targeted[bi] = True
        report.merged_names.append(want_base)
    for i in range(len(out)):
        if not targeted[i]:
            report.passed_names.append(out[i].name)
    return (out^, report^)


# ---------------------------------------------------------------------------
# HF <-> GGUF naming (llama subset, protocol 0.4)
# ---------------------------------------------------------------------------


def _lc_layer_split(name: String) -> Tuple[Int, String]:
    """For model.layers.<N>.<rest>: returns (N, rest),
    or (-1, "") when the name is not of that form."""
    var prefix = String("model.layers.")
    if not _lc_starts_with(name, prefix):
        return (-1, String(""))
    var rest = _lc_drop_prefix(name, prefix.byte_length())
    var raw = rest.as_bytes()
    var digits = 0
    var n = 0
    while digits < len(raw) and 48 <= Int(raw[digits]) <= 57:
        n = n * 10 + (Int(raw[digits]) - 48)
        digits += 1
    if digits == 0 or digits >= len(raw) or Int(raw[digits]) != 46:
        return (-1, String(""))
    return (n, _lc_drop_prefix(rest, digits + 1))


def lc_gguf_name_for_hf(name: String) raises -> String:
    if name == "model.embed_tokens.weight":
        return String("token_embd.weight")
    if name == "lm_head.weight":
        return String("output.weight")
    if name == "model.norm.weight":
        return String("output_norm.weight")
    var split = _lc_layer_split(name)
    if split[0] >= 0:
        var head = String("blk.") + String(split[0]) + "."
        var rest = split[1]
        if rest == "input_layernorm.weight":
            return head + "attn_norm.weight"
        if rest == "self_attn.q_proj.weight":
            return head + "attn_q.weight"
        if rest == "self_attn.k_proj.weight":
            return head + "attn_k.weight"
        if rest == "self_attn.v_proj.weight":
            return head + "attn_v.weight"
        if rest == "self_attn.o_proj.weight":
            return head + "attn_output.weight"
        if rest == "post_attention_layernorm.weight":
            return head + "ffn_norm.weight"
        if rest == "mlp.gate_proj.weight":
            return head + "ffn_gate.weight"
        if rest == "mlp.up_proj.weight":
            return head + "ffn_up.weight"
        if rest == "mlp.down_proj.weight":
            return head + "ffn_down.weight"
    raise Error("conversion refused: no GGUF name mapping for HF tensor: " + name)


def _lc_hf_name_for_gguf(name: String) -> String:
    """Reverse of lc_gguf_name_for_hf for the same
    subset; "" when the GGUF name is outside it."""
    if name == "token_embd.weight":
        return String("model.embed_tokens.weight")
    if name == "output.weight":
        return String("lm_head.weight")
    if name == "output_norm.weight":
        return String("model.norm.weight")
    if not _lc_starts_with(name, "blk."):
        return String("")
    var rest = _lc_drop_prefix(name, 4)
    var raw = rest.as_bytes()
    var digits = 0
    var n = 0
    while digits < len(raw) and 48 <= Int(raw[digits]) <= 57:
        n = n * 10 + (Int(raw[digits]) - 48)
        digits += 1
    if digits == 0 or digits >= len(raw) or Int(raw[digits]) != 46:
        return String("")
    var tail = _lc_drop_prefix(rest, digits + 1)
    var head = String("model.layers.") + String(n) + "."
    if tail == "attn_norm.weight":
        return head + "input_layernorm.weight"
    if tail == "attn_q.weight":
        return head + "self_attn.q_proj.weight"
    if tail == "attn_k.weight":
        return head + "self_attn.k_proj.weight"
    if tail == "attn_v.weight":
        return head + "self_attn.v_proj.weight"
    if tail == "attn_output.weight":
        return head + "self_attn.o_proj.weight"
    if tail == "ffn_norm.weight":
        return head + "post_attention_layernorm.weight"
    if tail == "ffn_gate.weight":
        return head + "mlp.gate_proj.weight"
    if tail == "ffn_up.weight":
        return head + "mlp.up_proj.weight"
    if tail == "ffn_down.weight":
        return head + "mlp.down_proj.weight"
    return String("")


# ---------------------------------------------------------------------------
# MTP preservation (J-121): head identification, verbatim carry, extraction
# ---------------------------------------------------------------------------

comptime LC_HEAD_NONE = 0
comptime LC_HEAD_NEXTN = 1
comptime LC_HEAD_MTP = 2
comptime LC_HEAD_ASSISTANT = 3


def lc_mtp_head_kind(name: String) -> Int:
    """The prediction-head kind one tensor name
    evidences, by J-076's pre-registered rules
    (core/mtp_census.mojo): first match in the order
    nextn, mtp, assistant. This is the conversion-side
    mirror of classify_tensor_name -- the layer imports
    nothing (J-120 section 0.1), so the rule is stated
    here and the J-121 unit suite proves the mirror and
    the classifier agree on every probed name."""
    if "nextn" in name:
        return LC_HEAD_NEXTN
    if "mtp" in name:
        return LC_HEAD_MTP
    if "assistant" in name:
        return LC_HEAD_ASSISTANT
    return LC_HEAD_NONE


def lc_mtp_head_kind_name(kind: Int) -> String:
    if kind == LC_HEAD_NEXTN:
        return String("nextn")
    if kind == LC_HEAD_MTP:
        return String("mtp")
    if kind == LC_HEAD_ASSISTANT:
        return String("assistant")
    return String("none")


def lc_extract_mtp_block(tensors: List[LcTensor]) raises -> List[LcTensor]:
    """J-121 section 0.6 local extraction: exactly the
    head-classified tensors of a checkpoint, in source
    order, values untouched -- the block a block-only
    emission through the GGUF writer carries. A
    checkpoint with zero head tensors is refused by
    name: nothing to extract is not a silent empty
    block file."""
    var out = List[LcTensor]()
    for t in tensors:
        if lc_mtp_head_kind(t.name) != LC_HEAD_NONE:
            out.append(t.copy())
    if len(out) == 0:
        raise Error(
            "conversion refused: MTP extraction found no prediction-head"
            " tensors in the checkpoint (nextn/mtp/assistant name rules)"
        )
    return out^


# ---------------------------------------------------------------------------
# Geometry, census, and the GGUF writer
# ---------------------------------------------------------------------------


struct LcGeometry(Copyable):
    var arch: String
    var model_name: String
    var context_length: Int
    var embedding_length: Int
    var feed_forward_length: Int
    var block_count: Int
    var head_count: Int
    var head_count_kv: Int
    var rope_dimension_count: Int
    var rope_freq_base: Float32
    var rms_epsilon: Float32
    var tokens: List[String]
    var unknown_token_id: Int
    var bos_token_id: Int
    var eos_token_id: Int

    def __init__(
        out self,
        arch: String,
        model_name: String,
        context_length: Int,
        embedding_length: Int,
        feed_forward_length: Int,
        block_count: Int,
        head_count: Int,
        head_count_kv: Int,
        rope_dimension_count: Int,
        rope_freq_base: Float32,
        rms_epsilon: Float32,
        tokens: List[String],
    ):
        self.arch = arch
        self.model_name = model_name
        self.context_length = context_length
        self.embedding_length = embedding_length
        self.feed_forward_length = feed_forward_length
        self.block_count = block_count
        self.head_count = head_count
        self.head_count_kv = head_count_kv
        self.rope_dimension_count = rope_dimension_count
        self.rope_freq_base = rope_freq_base
        self.rms_epsilon = rms_epsilon
        self.tokens = tokens.copy()
        self.unknown_token_id = 0
        self.bos_token_id = 1
        self.eos_token_id = 2

    def __copyinit__(out self, existing: Self):
        self.arch = existing.arch
        self.model_name = existing.model_name
        self.context_length = existing.context_length
        self.embedding_length = existing.embedding_length
        self.feed_forward_length = existing.feed_forward_length
        self.block_count = existing.block_count
        self.head_count = existing.head_count
        self.head_count_kv = existing.head_count_kv
        self.rope_dimension_count = existing.rope_dimension_count
        self.rope_freq_base = existing.rope_freq_base
        self.rms_epsilon = existing.rms_epsilon
        self.tokens = existing.tokens.copy()
        self.unknown_token_id = existing.unknown_token_id
        self.bos_token_id = existing.bos_token_id
        self.eos_token_id = existing.eos_token_id


struct LcCensusEntry(Copyable):
    var name: String
    var dims: List[Int]
    var ggml_type: Int
    var offset: Int
    var byte_count: Int

    def __init__(
        out self, name: String, dims: List[Int], ggml_type: Int, offset: Int, byte_count: Int
    ):
        self.name = name
        self.dims = dims.copy()
        self.ggml_type = ggml_type
        self.offset = offset
        self.byte_count = byte_count

    def __copyinit__(out self, existing: Self):
        self.name = existing.name
        self.dims = existing.dims.copy()
        self.ggml_type = existing.ggml_type
        self.offset = existing.offset
        self.byte_count = existing.byte_count


struct LcConversion(Copyable):
    var bytes: List[Byte]
    var census: List[LcCensusEntry]
    var data_offset: Int
    # J-121: the carried prediction-head tensors of this
    # conversion (GGUF names + J-076 kinds, census order);
    # empty for a head-free conversion.
    var head_names: List[String]
    var head_kinds: List[Int]

    def __init__(
        out self,
        bytes: List[Byte],
        census: List[LcCensusEntry],
        data_offset: Int,
        head_names: List[String],
        head_kinds: List[Int],
    ):
        self.bytes = bytes.copy()
        self.census = census.copy()
        self.data_offset = data_offset
        self.head_names = head_names.copy()
        self.head_kinds = head_kinds.copy()

    def __copyinit__(out self, existing: Self):
        self.bytes = existing.bytes.copy()
        self.census = existing.census.copy()
        self.data_offset = existing.data_offset
        self.head_names = existing.head_names.copy()
        self.head_kinds = existing.head_kinds.copy()


def _lc_align_up(v: Int, alignment: Int) -> Int:
    return ((v + alignment - 1) // alignment) * alignment


def _lc_gguf_string(mut out: List[Byte], text: String):
    _lc_append_u64le(out, text.byte_length())
    _lc_append_str_bytes(out, text)


def _lc_kv_string(mut out: List[Byte], key: String, value: String):
    _lc_gguf_string(out, key)
    _lc_append_u32le(out, 8)
    _lc_gguf_string(out, value)


def _lc_kv_u32(mut out: List[Byte], key: String, value: Int):
    _lc_gguf_string(out, key)
    _lc_append_u32le(out, 4)
    _lc_append_u32le(out, value)


def _lc_kv_f32(mut out: List[Byte], key: String, value: Float32):
    _lc_gguf_string(out, key)
    _lc_append_u32le(out, 6)
    _lc_append_u32le(out, Int(bitcast[DType.uint32](value)))


def _lc_kv_string_array(mut out: List[Byte], key: String, values: List[String]):
    _lc_gguf_string(out, key)
    _lc_append_u32le(out, 9)
    _lc_append_u32le(out, 8)
    _lc_append_u64le(out, len(values))
    for v in values:
        _lc_gguf_string(out, v)


def _lc_kv_f32_zeros(mut out: List[Byte], key: String, count: Int):
    _lc_gguf_string(out, key)
    _lc_append_u32le(out, 9)
    _lc_append_u32le(out, 6)
    _lc_append_u64le(out, count)
    for _ in range(count):
        _lc_append_u32le(out, 0)


def _lc_kv_i32_zeros(mut out: List[Byte], key: String, count: Int):
    _lc_gguf_string(out, key)
    _lc_append_u32le(out, 9)
    _lc_append_u32le(out, 5)
    _lc_append_u64le(out, count)
    for _ in range(count):
        _lc_append_u32le(out, 0)


def _lc_convert_tensors(
    tensors: List[LcTensor], geom: LcGeometry, strict_names: Bool
) raises -> LcConversion:
    if len(geom.tokens) < 3:
        raise Error("conversion refused: tokenizer vocabulary needs at least 3 tokens")
    for tid in [geom.unknown_token_id, geom.bos_token_id, geom.eos_token_id]:
        if tid < 0 or tid >= len(geom.tokens):
            raise Error("conversion refused: special token id outside the vocabulary")
    # Directory plan: names, GGUF dims, types, sizes.
    var names = List[String]()
    var gdims = List[List[Int]]()
    var gtypes = List[Int]()
    var gsizes = List[Int]()
    var head_names = List[String]()
    var head_kinds = List[Int]()
    for t in tensors:
        var gname: String
        if strict_names:
            try:
                gname = lc_gguf_name_for_hf(t.name)
            except:
                # J-121 section 0.2: an unmapped name that
                # classifies as a prediction-head tensor is
                # carried verbatim; any other unmapped name
                # keeps J-120's refusal, text unchanged.
                if lc_mtp_head_kind(t.name) != LC_HEAD_NONE:
                    gname = t.name
                else:
                    raise Error(
                        "conversion refused: no GGUF name mapping for HF tensor: "
                        + t.name
                    )
        else:
            try:
                gname = lc_gguf_name_for_hf(t.name)
            except:
                gname = t.name
        var gkind = lc_mtp_head_kind(gname)
        if gkind != LC_HEAD_NONE:
            head_names.append(gname)
            head_kinds.append(gkind)
        if len(t.dims) == 1:
            var dims = List[Int]()
            dims.append(t.dims[0])
            gdims.append(dims.copy())
            gtypes.append(LC_GGML_F32)
            gsizes.append(t.dims[0] * 4)
        elif len(t.dims) == 2:
            var dims = List[Int]()
            dims.append(t.dims[1])
            dims.append(t.dims[0])
            gdims.append(dims.copy())
            gtypes.append(LC_GGML_BF16)
            gsizes.append(t.dims[0] * t.dims[1] * 2)
        else:
            raise Error(
                "conversion refused: tensor has unsupported rank for GGUF emission: "
                + t.name + " (" + String(len(t.dims)) + " dims)"
            )
        names.append(gname)
    var meta = List[Byte]()
    _lc_kv_string(meta, "general.architecture", geom.arch)
    _lc_kv_string(meta, "general.name", geom.model_name)
    _lc_kv_u32(meta, "general.alignment", LC_ALIGNMENT)
    _lc_kv_u32(meta, geom.arch + ".context_length", geom.context_length)
    _lc_kv_u32(meta, geom.arch + ".embedding_length", geom.embedding_length)
    _lc_kv_u32(meta, geom.arch + ".feed_forward_length", geom.feed_forward_length)
    _lc_kv_u32(meta, geom.arch + ".block_count", geom.block_count)
    _lc_kv_u32(meta, geom.arch + ".attention.head_count", geom.head_count)
    _lc_kv_u32(meta, geom.arch + ".attention.head_count_kv", geom.head_count_kv)
    _lc_kv_u32(meta, geom.arch + ".rope.dimension_count", geom.rope_dimension_count)
    _lc_kv_f32(meta, geom.arch + ".rope.freq_base", geom.rope_freq_base)
    _lc_kv_f32(meta, geom.arch + ".attention.layer_norm_rms_epsilon", geom.rms_epsilon)
    _lc_kv_string(meta, "tokenizer.ggml.model", "llama")
    _lc_kv_string_array(meta, "tokenizer.ggml.tokens", geom.tokens)
    _lc_kv_f32_zeros(meta, "tokenizer.ggml.scores", len(geom.tokens))
    _lc_kv_i32_zeros(meta, "tokenizer.ggml.token_type", len(geom.tokens))
    _lc_kv_u32(meta, "tokenizer.ggml.unknown_token_id", geom.unknown_token_id)
    _lc_kv_u32(meta, "tokenizer.ggml.bos_token_id", geom.bos_token_id)
    _lc_kv_u32(meta, "tokenizer.ggml.eos_token_id", geom.eos_token_id)
    # 19 metadata entries were appended above (counted in the doc).
    # J-121 section 0.3: the explicit head label, emitted only when
    # at least one head tensor is carried (+2 entries, 21 total).
    if len(head_names) > 0:
        _lc_kv_u32(meta, "aesir.mtp.head_count", len(head_names))
        _lc_kv_string_array(meta, "aesir.mtp.head_tensors", head_names)
    var kv_count = 19 + (2 if len(head_names) > 0 else 0)
    # Tensor directory (sizes first to place data).
    var dir_bytes = List[Byte]()
    var offsets = List[Int]()
    var cursor = 0
    for i in range(len(tensors)):
        offsets.append(cursor)
        cursor = _lc_align_up(cursor + gsizes[i], LC_ALIGNMENT)
    for i in range(len(tensors)):
        _lc_gguf_string(dir_bytes, names[i])
        _lc_append_u32le(dir_bytes, len(gdims[i]))
        for d in gdims[i]:
            _lc_append_u64le(dir_bytes, d)
        _lc_append_u32le(dir_bytes, gtypes[i])
        _lc_append_u64le(dir_bytes, offsets[i])
    var header_len = 24 + len(meta) + len(dir_bytes)
    var data_offset = _lc_align_up(header_len, LC_ALIGNMENT)
    var out = List[Byte]()
    _lc_append_u32le(out, 0x46554747)
    _lc_append_u32le(out, 3)
    _lc_append_u64le(out, len(tensors))
    _lc_append_u64le(out, kv_count)
    for b in meta:
        out.append(b)
    for b in dir_bytes:
        out.append(b)
    while len(out) < data_offset:
        out.append(Byte(0))
    var census = List[LcCensusEntry]()
    for i in range(len(tensors)):
        var want_len = data_offset + offsets[i]
        while len(out) < want_len:
            out.append(Byte(0))
        if gtypes[i] == LC_GGML_F32:
            _lc_encode_values(out, tensors[i].values, LC_DTYPE_F32)
        else:
            _lc_encode_values(out, tensors[i].values, LC_DTYPE_BF16)
        census.append(
            LcCensusEntry(names[i], gdims[i], gtypes[i], offsets[i], gsizes[i])
        )
    return LcConversion(out^, census^, data_offset, head_names^, head_kinds^)


def lc_convert_base(base: List[LcTensor], geom: LcGeometry) raises -> LcConversion:
    """Converts an (already merged, or plain) HF
    tensor list to GGUF with strict naming: the
    safetensors path of the protocol."""
    return _lc_convert_tensors(base, geom, True)


# ---------------------------------------------------------------------------
# The GGUF directory reader (C10) and the from-gguf conversion
# ---------------------------------------------------------------------------


def _lc_gguf_skip_value(data: List[Byte], vtype: Int, pos: Int) raises -> Int:
    """Mirrors loader/gguf.mojo's skip_value."""
    if vtype == 0 or vtype == 1 or vtype == 7:
        return pos + 1
    if vtype == 2 or vtype == 3:
        return pos + 2
    if vtype == 4 or vtype == 5 or vtype == 6:
        return pos + 4
    if vtype == 10 or vtype == 11 or vtype == 12:
        return pos + 8
    if vtype == 8:
        var n = _lc_read_u64le(data, pos)
        return pos + 8 + n
    if vtype == 9:
        var etype = _lc_read_u32le(data, pos)
        var count = _lc_read_u64le(data, pos + 4)
        var p = pos + 12
        for _ in range(count):
            p = _lc_gguf_skip_value(data, etype, p)
        return p
    raise Error("GGUF contains an invalid metadata value type")


def _lc_gguf_read_string(data: List[Byte], pos: Int) raises -> Tuple[String, Int]:
    var n = _lc_read_u64le(data, pos)
    if pos + 8 + n > len(data):
        raise Error("GGUF string exceeds the file")
    return (_lc_str_slice(data, pos + 8, pos + 8 + n), pos + 8 + n)


struct LcGgufRead(Copyable):
    var tensors: List[LcTensor]
    var geom: LcGeometry

    def __init__(out self, tensors: List[LcTensor], geom: LcGeometry):
        self.tensors = tensors.copy()
        self.geom = geom.copy()

    def __copyinit__(out self, existing: Self):
        self.tensors = existing.tensors.copy()
        self.geom = existing.geom.copy()


def lc_read_gguf(data: List[Byte]) raises -> LcGgufRead:
    """Reads a BF16/F32 GGUF (this converter's own
    emission class) back to Float32 tensors in
    safetensors shape order ([out, in] for 2-D),
    plus the geometry its metadata carries.
    Quantized tensors are refused by name: the
    BF16-only scope (C05) cannot re-emit them."""
    if len(data) < 24:
        raise Error("GGUF file is smaller than the v3 header")
    if _lc_read_u32le(data, 0) != 0x46554747:
        raise Error("GGUF magic bytes are invalid")
    if _lc_read_u32le(data, 4) != 3:
        raise Error("only GGUF version 3 is supported by the converter")
    var tensor_count = _lc_read_u64le(data, 8)
    var kv_count = _lc_read_u64le(data, 16)
    var arch = String("")
    var model_name = String("converted")
    var alignment = LC_ALIGNMENT
    var ctx = 0
    var emb = 0
    var ffn = 0
    var blocks = 0
    var heads = 0
    var kv_heads = 0
    var rope_dim = 0
    var rope_base = Float32(10000.0)
    var rms = Float32(0.00001)
    var tokens = List[String]()
    var unk = 0
    var bos = 1
    var eos = 2
    var pos = 24
    for _ in range(kv_count):
        var k = _lc_gguf_read_string(data, pos)
        var key = k[0]
        pos = k[1]
        var vtype = _lc_read_u32le(data, pos)
        pos += 4
        var vstart = pos
        pos = _lc_gguf_skip_value(data, vtype, pos)
        if key == "general.architecture" and vtype == 8:
            arch = _lc_gguf_read_string(data, vstart)[0]
        elif key == "general.name" and vtype == 8:
            model_name = _lc_gguf_read_string(data, vstart)[0]
        elif key == "general.alignment" and vtype == 4:
            alignment = _lc_read_u32le(data, vstart)
        elif key == "tokenizer.ggml.tokens" and vtype == 9:
            var etype = _lc_read_u32le(data, vstart)
            if etype != 8:
                raise Error("tokenizer.ggml.tokens must be a string array")
            var count = _lc_read_u64le(data, vstart + 4)
            var p = vstart + 12
            for _ in range(count):
                var s = _lc_gguf_read_string(data, p)
                tokens.append(s[0])
                p = s[1]
        elif key == "tokenizer.ggml.unknown_token_id" and vtype == 4:
            unk = _lc_read_u32le(data, vstart)
        elif key == "tokenizer.ggml.bos_token_id" and vtype == 4:
            bos = _lc_read_u32le(data, vstart)
        elif key == "tokenizer.ggml.eos_token_id" and vtype == 4:
            eos = _lc_read_u32le(data, vstart)
        elif vtype == 4:
            var v = _lc_read_u32le(data, vstart)
            if _lc_ends_with(key, ".context_length"):
                ctx = v
            elif _lc_ends_with(key, ".embedding_length"):
                emb = v
            elif _lc_ends_with(key, ".feed_forward_length"):
                ffn = v
            elif _lc_ends_with(key, ".block_count"):
                blocks = v
            elif _lc_ends_with(key, ".attention.head_count"):
                heads = v
            elif _lc_ends_with(key, ".attention.head_count_kv"):
                kv_heads = v
            elif _lc_ends_with(key, ".rope.dimension_count"):
                rope_dim = v
        elif vtype == 6:
            var fv = bitcast[DType.float32](UInt32(_lc_read_u32le(data, vstart)))
            if _lc_ends_with(key, ".rope.freq_base"):
                rope_base = fv
            elif _lc_ends_with(key, ".attention.layer_norm_rms_epsilon"):
                rms = fv
    if alignment <= 0 or (alignment & (alignment - 1)) != 0:
        raise Error("GGUF alignment must be a power of two")
    var names = List[String]()
    var dims_list = List[List[Int]]()
    var types = List[Int]()
    var offsets = List[Int]()
    for _ in range(tensor_count):
        var nm = _lc_gguf_read_string(data, pos)
        names.append(nm[0])
        pos = nm[1]
        var nd = _lc_read_u32le(data, pos)
        pos += 4
        if nd < 1 or nd > 2:
            raise Error("converter GGUF reader: tensor dimension count out of range: " + nm[0])
        var dims = List[Int]()
        for _ in range(nd):
            dims.append(_lc_read_u64le(data, pos))
            pos += 8
        var gtype = _lc_read_u32le(data, pos)
        pos += 4
        var off = _lc_read_u64le(data, pos)
        pos += 8
        dims_list.append(dims.copy())
        types.append(gtype)
        offsets.append(off)
    var data_offset = _lc_align_up(pos, alignment)
    var tensors = List[LcTensor]()
    for i in range(len(names)):
        var gtype = types[i]
        if gtype != LC_GGML_BF16 and gtype != LC_GGML_F32:
            raise Error(
                "from-gguf conversion refused: quantized tensor cannot be"
                " re-emitted in BF16-only scope: " + names[i]
                + " (ggml type " + String(gtype) + ")"
            )
        var gdims = dims_list[i].copy()
        var count = 1
        for d in gdims:
            count *= d
        var start = data_offset + offsets[i]
        var values: List[Float32]
        if gtype == LC_GGML_F32:
            values = _lc_decode_values(data, start, count, LC_DTYPE_F32)
        else:
            values = _lc_decode_values(data, start, count, LC_DTYPE_BF16)
        var dims = List[Int]()
        if len(gdims) == 2:
            dims.append(gdims[1])
            dims.append(gdims[0])
        else:
            dims.append(gdims[0])
        tensors.append(LcTensor(names[i], dims, values))
    var geom = LcGeometry(
        arch, model_name, ctx, emb, ffn, blocks, heads, kv_heads,
        rope_dim, rope_base, rms, tokens,
    )
    geom.unknown_token_id = unk
    geom.bos_token_id = bos
    geom.eos_token_id = eos
    return LcGgufRead(tensors^, geom^)


def lc_convert_from_gguf(
    data: List[Byte], adapter: List[LcTensor], cfg: LcAdapterConfig, has_adapter: Bool
) raises -> Tuple[LcConversion, LcMergeReport]:
    """The C10 mode: read a BF16/F32 GGUF, rename
    to HF space where the mapping knows the name,
    merge the adapter if one is given, re-emit
    through the same writer."""
    var read = lc_read_gguf(data)
    var working = List[LcTensor]()
    for t in read.tensors:
        var hf = _lc_hf_name_for_gguf(t.name)
        if hf.byte_length() > 0:
            working.append(LcTensor(hf, t.dims, t.values))
        else:
            working.append(t.copy())
    var report = LcMergeReport()
    if has_adapter:
        var merged = lc_merge_model(working, adapter, cfg)
        working = merged[0].copy()
        report = merged[1].copy()
    else:
        for t in working:
            report.passed_names.append(t.name)
    var conv = _lc_convert_tensors(working, read.geom, False)
    return (conv^, report^)


# ---------------------------------------------------------------------------
# The C05 scope, on the layer's own face
# ---------------------------------------------------------------------------


def lc_c05_scope_text() -> String:
    return String(
        "BF16-only scope (C05): this converter emits BF16 weights and F32"
        " norms only; the post-conversion file quantization leg is not"
        " built in J-120, and a quantization request is refused by name"
        " rather than silently emitting BF16 under a quantized label."
    )


def lc_refuse_quantize(requested: String) raises:
    raise Error(
        "conversion refused: file quantization is not built in J-120's"
        " BF16-only scope (C05); requested '" + requested
        + "' would be a silent BF16 emission under a quantized label"
    )
