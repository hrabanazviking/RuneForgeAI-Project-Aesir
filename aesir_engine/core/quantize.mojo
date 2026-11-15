# core/quantize.mojo
# The Quantization Forge (WRITE side): F32 values -> GGML packed blocks.
#
# QC-2 delivers the first writer in this module: quantize_q8_0, the
# exact inverse of the engine's Q8_0 dequantizers (core/compute.mojo
# dequantize_q8_0 and loader/quantization.mojo dequantize_q8_0_block,
# which walk the same layout). One module in core/, beside the
# dequantizers it inverts (QC-0-PLAN section 6 placement); the GGUF
# file writer it feeds lives in loader/gguf_writer.mojo (QC-1) and
# stays format-agnostic.
#
# Q8_0 layout (34 B per 32-value block, reader-verified in
# core/compute.mojo dequantize_q8_0):
#   f16 scale d @0 (2 B, little-endian), 32 x int8 qs @2..34.
#   Dequant: value = q * d.
#
# Quantization rule (ggml quantize_row_q8_0_ref, ggml-quants.c in
# ~/llama.cpp-build -- the reference implementation ggml itself
# labels "for deterministic creation of model files"; re-read from
# disk for this slice):
#   amax = max |w| over the 32-value block
#   d    = amax / 127          (f32; stored as f16, round-to-nearest-even)
#   id   = 1 / d               (0 when d == 0)
#   q    = roundf(w * id)      (C roundf: round half AWAY from zero),
#          clamped to [-127, 127] as a guard (the unclamped value is
#          already within +/-127 up to f32 dust, since |w| <= amax)
# A zero block (amax == 0) emits d = 0 and all-zero qs.
# The qs are computed against the UNROUNDED f32 d, exactly as ggml
# does; the stored scale is its f16 rounding. Round-trip error is
# therefore bounded per block by
#   |dequant(w) - w| <= d_hat/2 + 127*|d_hat - d| + amax*2^-10
#                       + d_hat*0.002 + 1e-7
# (rounding of q; f16 rounding of d amplified by |q| <= 127; f16
# product rounding in the dequantizer plus f32 dust in w*id). The
# QC-2 property tests assert this bound elementwise and report the
# measured max/mean errors against it.
#
# Refusals (all raise Error; a refused call produces no payload):
# - element count == 0, or not a multiple of 32: GGUF has no padding
#   semantics and both readers price/refuse non-block-aligned dim0
#   (QC-0 section 3; the QC-1 writer refuses the same shapes). The
#   quantizer refuses rather than pads -- callers keep such tensors
#   at their source type, per the plan's per-role policy.
# - any non-finite value (NaN / +/-Inf): no Q8_0 encoding exists.
# - a block scale d that overflows the f16 range (amax >~ 127*65504):
#   the stored scale would be Inf and every dequantized value in the
#   block garbage. ggml's reference shares the format limit; a
#   writer must refuse rather than emit a corrupt block.
# A scale that UNDERFLOWS f16 (d below the f16 subnormal floor) is
# not refused: d_hat rounds to a subnormal or to 0, the qs are still
# formed against the true d, and the proven bound above still holds
# (127*|d_hat - d| covers the whole block, err <= amax). The block
# dequantizes to (near-)zero -- documented behaviour for absurdly
# tiny blocks, exercised by the QC-2 tiny-value tests.

from std.math import isfinite, sqrt
from std.memory import bitcast

from core.mimir_well import f16, f32


comptime Q8_0_BLOCK_ELEMENTS = 32
comptime Q8_0_BLOCK_BYTES = 34
comptime Q8_0_GGML_TYPE = 8


def _abs_f32(value: Float32) -> Float32:
    return value if value >= Float32(0.0) else -value


def _round_half_away_from_zero(value: Float32) -> Int:
    """C roundf semantics for the small magnitudes the Q8_0 rule
    produces (|value| <= ~127.6): round half away from zero, via
    truncation of value + 0.5 in the sign's direction."""
    if value >= Float32(0.0):
        return Int(value + Float32(0.5))
    return -Int(-value + Float32(0.5))


def q8_0_payload_bytes(element_count: Int) raises -> Int:
    """Reader-priced payload size for a Q8_0 tensor of element_count
    values: (element_count / 32) * 34. Refuses the same counts the
    quantizer refuses, so a caller can price before it quantizes."""
    if element_count <= 0:
        raise Error(
            "q8_0_payload_bytes: element count must be positive (got "
            + String(element_count) + ")"
        )
    if element_count % Q8_0_BLOCK_ELEMENTS != 0:
        raise Error(
            "q8_0_payload_bytes: element count " + String(element_count)
            + " is not a multiple of the 32-value Q8_0 block"
        )
    return (element_count // Q8_0_BLOCK_ELEMENTS) * Q8_0_BLOCK_BYTES


def quantize_q8_0(values: List[Float32]) raises -> List[UInt8]:
    """Quantizes F32 values into Q8_0 payload bytes (34 B per
    32-value block: f16 scale d @0, 32 x int8 qs @2), the exact
    inverse of the engine's Q8_0 dequantizers. The payload length is
    q8_0_payload_bytes(len(values)) -- exactly what the GGUF writer
    (loader/gguf_writer.mojo) prices for a GGML type-8 tensor, so the
    result drops straight into a GGUFWriterTensor. Blocks run along
    the value sequence in order (a tensor's dim0 rows, in the
    writer's emission order). Refusals: see the module header."""
    var count = len(values)
    if count <= 0:
        raise Error("quantize_q8_0: element count must be positive (got 0)")
    if count % Q8_0_BLOCK_ELEMENTS != 0:
        raise Error(
            "quantize_q8_0: element count " + String(count)
            + " is not a multiple of the 32-value Q8_0 block; refusing"
            + " to pad (GGUF has no padding semantics -- a tensor's"
            + " dim0 must be block-aligned, and non-aligned tensors"
            + " stay at their source type per QC-0 section 3)"
        )
    var out = List[UInt8]()
    out.reserve(q8_0_payload_bytes(count))
    for block in range(count // Q8_0_BLOCK_ELEMENTS):
        var base = block * Q8_0_BLOCK_ELEMENTS
        var amax = Float32(0.0)
        for i in range(Q8_0_BLOCK_ELEMENTS):
            var value = values[base + i]
            if not isfinite(value):
                raise Error(
                    "quantize_q8_0: non-finite value at index "
                    + String(base + i) + " has no Q8_0 encoding"
                )
            var magnitude = _abs_f32(value)
            if magnitude > amax:
                amax = magnitude
        var d = amax / Float32(127.0)
        var d_hat = d.cast[f16]()
        if not isfinite(d_hat.cast[f32]()):
            raise Error(
                "quantize_q8_0: block " + String(block) + " scale "
                + String(d) + " overflows the f16 range (amax "
                + String(amax) + "); refusing to emit a corrupt block"
            )
        var d_bits = bitcast[DType.uint16](d_hat)
        out.append(UInt8(d_bits & 0xff))
        out.append(UInt8((d_bits >> 8) & 0xff))
        var inverse_d = Float32(0.0)
        if d != Float32(0.0):
            inverse_d = Float32(1.0) / d
        for i in range(Q8_0_BLOCK_ELEMENTS):
            var q = 0
            if d != Float32(0.0):
                q = _round_half_away_from_zero(values[base + i] * inverse_d)
                if q > 127:
                    q = 127
                elif q < -127:
                    q = -127
            out.append(UInt8(q & 0xFF))
    return out^


# ---------------------------------------------------------------------
# QC-5: K-quant packing writers (Q4_K + Q6_K) -- the WRITE side of
# core/packed_quantization.packed_value (kind 12 / kind 14), whose
# arithmetic order these writers must satisfy exactly:
#   Q4_K: value = d * (scale * q) - dmin * minimum   (integer product
#         scale*q formed first, <= 63*15 = 945, exact in f32)
#   Q6_K: value = d * scale * (q6 - 32)              (scale is a
#         SIGNED i8 per 16 values; this writer emits only
#         non-negative scales -- see the Q6_K rule below)
#
# Q4_K layout (144 B per 256-value super-block, ggml block_q4_K):
#   f16 d @0, f16 dmin @2, 12 scale/min bytes @4..15, 128 qs @16.
#   The 12 bytes pack eight 6-bit sub-block scales and eight 6-bit
#   sub-block mins (sub-block = 32 values) exactly as ggml's
#   get_scale_min_k4 reconstructs them:
#     j < 4:  scale = scales[j] & 63,        min = scales[j+4] & 63
#     j >= 4: scale = (scales[j+4] & 15) | ((scales[j-4] >> 6) << 4)
#             min   = (scales[j+4] >>  4) | ((scales[j-0] >> 6) << 4)
#   (scales[] here is the 12-byte array at block offset 4.) The qs
#   pack as ggml's ref packs them: for each 64-value chunk, one byte
#   per lane pair -- low nibble = first 32 lanes' q, high nibble =
#   next 32 lanes' q.
#
# Q4_K quantization rule (the QC-0-PLAN section 5 first-slice
# choice, mirroring the STRUCTURE of ggml's
# quantize_row_q4_K_ref in ~/llama.cpp-build/ggml/src/
# ggml-quants.c, re-read from disk for this slice):
#   MIRRORED from the ref: (a) per-sub-block affine fit with the
#   min clamped to <= 0 (make_qkx2_quants clamps min > 0 to 0 --
#   the format's -dmin*min term cannot express a positive offset);
#   (b) the eight scales and eight mins are then quantized against
#   the super-block maxima with a 6-bit uniform grid (d =
#   max_scale/63, dmin = max_min/63, both stored as f16; ls/lm are
#   round-to-nearest of scale/d, min/dmin, clamped to [0, 63]);
#   (c) the quants are RE-FORMED against the reconstructed
#   (stored) sub-block scale/min, q = clamp(round((x + m_hat) /
#   s_hat), 0, 15), exactly as the ref's second pass does -- this
#   is what makes the error bound below a bound on the STORED
#   block, not on the ideal fit.
#   SIMPLIFIED vs the ref (named, per the slice brief): the ref's
#   per-sub-block scale/min come from make_qkx2_quants -- a
#   weighted least-squares search over 21 candidate scale
#   multipliers (weights av_x + |x|). This writer uses the plain
#   min/max affine fit the plan fixes as the first-slice choice:
#   scale = (max - min_eff) / 15, min = -min_eff, with min_eff =
#   min(sub_min, 0); a constant sub-block with value c <= 0 gets
#   scale 0 and min -c (the ref's max == min branch), and a
#   constant positive sub-block fits against min_eff = 0. The
#   simplification changes BYTES vs ggml's ref wherever the search
#   would have chosen a different fit; it is allowed because the
#   round-trip bound below is proven for THIS fit and the
#   whole-model grade (QC-5 stage 3) arbitrates the choice, per
#   QC-0 section 5 ("What would change these choices: ONLY
#   grades"). Rounding is round-half-away-from-zero throughout
#   (the QC-2-pinned rule; ggml's nearest_int is round-to-nearest-
#   even -- the two differ only on exact .5 ties, which satisfy
#   the same bound either way).
#
# Q4_K round-trip bound (asserted elementwise by the QC-5 tests):
# per sub-block j, with ideal fit (s_j, m_j) and stored
# reconstruction (s_hat = d_hat * ls_j, m_hat = dmin_hat * lm_j):
#   err <= s_hat/2 + 15*|s_hat - s_j| + |m_hat - m_j|
#          + 1e-6 * (1 + |x| + s_hat + m_hat) + 1e-7
# The s_hat/2 term is the requant rounding against the stored
# scale; the two middle terms bound the range shrink at the
# sub-block ends when the 6-bit super-quantization moves the
# stored scale/min off the ideal fit (a clamped lane can lose at
# most the full range shrink); the last terms cover f32 dust in
# (x + m_hat)/s_hat and in the reader's product. When s_hat == 0
# the stored sub-block is the constant -m_hat and the same
# formula bounds err by 15*s_j + |m_hat - m_j| + dust, which the
# formula's middle terms already give.
#
# Q6_K layout (210 B per 256-value super-block, ggml block_q6_K):
#   128 ql bytes @0, 64 qh bytes @128, 16 x i8 scales @192 (one
#   per 16 values), f16 d @208. Dequant: d * scale * (q6 - 32)
#   with q6 = ql nibble | (qh 2-bit << 4), packed exactly as ggml's
#   quantize_row_q6_K_ref packs them (per 128-value half: ql[l] =
#   q(0+l) low | q(64+l) low << 4, ql[l+32] = q(32+l) low |
#   q(96+l) low << 4, qh[l] gathers the four high 2-bit fields).
#
# Q6_K quantization rule (same structure as the ref, simplified
# the same named way): the ref's per-16 scale comes from
# make_qx_quants (a least-squares search with a signed scale
# whose sign follows the largest-|x| lane). This writer uses the
# symmetric min/max fit s_j = amax_j / 32 with NON-NEGATIVE
# scales only: d = max_s / 127 stored as f16, sc_j = round(s_j /
# d) clamped to [0, 127], and the quants are re-formed against
# the stored scale, l = clamp(round(x / s_hat), -32, 31), stored
# as l + 32 -- the ref's second pass, mirrored. Non-negative
# scales are a legitimate subset of the format (the reader's i8
# scale carries either sign; the product d*scale is what the
# dequantizer sees). Bound per 16-value group:
#   err <= s_hat/2 + 32*|s_hat - s_j| + s_j
#          + 1e-6 * (1 + |x| + s_hat) + 1e-7
# (the + s_j term is the +31/-32 asymmetry: a lane at +amax with
# an exact stored scale rounds to l = 32 and clamps to 31,
# losing exactly one step).
#
# Refusals (both writers; all raise Error, no payload produced):
# - element count == 0 or not a multiple of 256 (GGUF has no
#   padding semantics; the readers price dim0-flat element counts
#   by integer division -- loader _tensor_byte_size -- and a
#   non-multiple count would be silently truncated there).
# - any non-finite value (index named).
# - a super scale d / dmin that overflows the f16 range: the
#   stored scale would be Inf and the block garbage.
# A super scale that UNDERFLOWS f16 is not refused: the stored
# block dequantizes to (near-)zero and the bounds above still
# hold through their range-shrink terms (the QC-2 pattern).

comptime Q4_K_BLOCK_ELEMENTS = 256
comptime Q4_K_BLOCK_BYTES = 144
comptime Q4_K_GGML_TYPE = 12
comptime Q6_K_BLOCK_ELEMENTS = 256
comptime Q6_K_BLOCK_BYTES = 210
comptime Q6_K_GGML_TYPE = 14


def _clamp_int(value: Int, lo: Int, hi: Int) -> Int:
    if value < lo:
        return lo
    if value > hi:
        return hi
    return value


def q4_k_payload_bytes(element_count: Int) raises -> Int:
    """Reader-priced payload size for a Q4_K tensor:
    (element_count / 256) * 144. Refuses the same counts the
    quantizer refuses, so a caller can price before quantizing."""
    if element_count <= 0:
        raise Error(
            "q4_k_payload_bytes: element count must be positive (got "
            + String(element_count) + ")"
        )
    if element_count % Q4_K_BLOCK_ELEMENTS != 0:
        raise Error(
            "q4_k_payload_bytes: element count " + String(element_count)
            + " is not a multiple of the 256-value Q4_K super-block"
        )
    return (element_count // Q4_K_BLOCK_ELEMENTS) * Q4_K_BLOCK_BYTES


def q6_k_payload_bytes(element_count: Int) raises -> Int:
    """Reader-priced payload size for a Q6_K tensor:
    (element_count / 256) * 210. Refuses the same counts the
    quantizer refuses."""
    if element_count <= 0:
        raise Error(
            "q6_k_payload_bytes: element count must be positive (got "
            + String(element_count) + ")"
        )
    if element_count % Q6_K_BLOCK_ELEMENTS != 0:
        raise Error(
            "q6_k_payload_bytes: element count " + String(element_count)
            + " is not a multiple of the 256-value Q6_K super-block"
        )
    return (element_count // Q6_K_BLOCK_ELEMENTS) * Q6_K_BLOCK_BYTES


def quantize_q4_k(values: List[Float32]) raises -> List[UInt8]:
    """Quantizes F32 values into Q4_K payload bytes (144 B per
    256-value super-block), the inverse of the engine's Q4_K
    dequantizer (core/packed_quantization.packed_value kind 12).
    Rule, bound and refusals: see the QC-5 module header above."""
    var count = len(values)
    if count <= 0:
        raise Error("quantize_q4_k: element count must be positive (got 0)")
    if count % Q4_K_BLOCK_ELEMENTS != 0:
        raise Error(
            "quantize_q4_k: element count " + String(count)
            + " is not a multiple of the 256-value Q4_K super-block;"
            + " refusing to pad (GGUF has no padding semantics)"
        )
    var out = List[UInt8]()
    out.reserve(q4_k_payload_bytes(count))
    for block in range(count // Q4_K_BLOCK_ELEMENTS):
        var base = block * Q4_K_BLOCK_ELEMENTS
        var scales = List[Float32]()
        scales.resize(8, Float32(0.0))
        var mins = List[Float32]()
        mins.resize(8, Float32(0.0))
        var quants = List[Int]()
        quants.resize(Q4_K_BLOCK_ELEMENTS, 0)
        var max_scale = Float32(0.0)
        var max_min = Float32(0.0)
        for j in range(8):
            var sub = base + j * 32
            var mn = values[sub]
            var mx = values[sub]
            for i in range(32):
                var value = values[sub + i]
                if not isfinite(value):
                    raise Error(
                        "quantize_q4_k: non-finite value at index "
                        + String(sub + i) + " has no Q4_K encoding"
                    )
                if value < mn:
                    mn = value
                if value > mx:
                    mx = value
            var scale: Float32
            var minute: Float32
            if mx == mn:
                if mn < Float32(0.0):
                    scale = Float32(0.0)
                    minute = -mn
                else:
                    scale = mn / Float32(15.0)
                    minute = Float32(0.0)
            else:
                var min_eff = mn if mn < Float32(0.0) else Float32(0.0)
                scale = (mx - min_eff) / Float32(15.0)
                minute = -min_eff
            scales[j] = scale
            mins[j] = minute
            if scale > max_scale:
                max_scale = scale
            if minute > max_min:
                max_min = minute
            if scale != Float32(0.0):
                var min_eff = -minute
                for i in range(32):
                    var q = _round_half_away_from_zero(
                        (values[sub + i] - min_eff) / scale
                    )
                    quants[j * 32 + i] = _clamp_int(q, 0, 15)
        var d = max_scale / Float32(63.0)
        var dmin = max_min / Float32(63.0)
        var d_hat = d.cast[f16]()
        var dmin_hat = dmin.cast[f16]()
        if not isfinite(d_hat.cast[f32]()) or not isfinite(
            dmin_hat.cast[f32]()
        ):
            raise Error(
                "quantize_q4_k: block " + String(block)
                + " super scale overflows the f16 range (max_scale "
                + String(max_scale) + ", max_min " + String(max_min)
                + "); refusing to emit a corrupt block"
            )
        var d_hat_f32 = d_hat.cast[f32]()
        var dmin_hat_f32 = dmin_hat.cast[f32]()
        var ls = List[Int]()
        ls.resize(8, 0)
        var lm = List[Int]()
        lm.resize(8, 0)
        for j in range(8):
            if d != Float32(0.0):
                ls[j] = _clamp_int(
                    _round_half_away_from_zero(scales[j] / d), 0, 63
                )
            if dmin != Float32(0.0):
                lm[j] = _clamp_int(
                    _round_half_away_from_zero(mins[j] / dmin), 0, 63
                )
        # Re-form the quants against the STORED scale/min (the
        # ref's second pass), so the bound speaks about the stored
        # block.
        for j in range(8):
            var s_hat = d_hat_f32 * Float32(ls[j])
            if s_hat == Float32(0.0):
                continue
            var m_hat = dmin_hat_f32 * Float32(lm[j])
            var sub = base + j * 32
            for i in range(32):
                var q = _round_half_away_from_zero(
                    (values[sub + i] + m_hat) / s_hat
                )
                quants[j * 32 + i] = _clamp_int(q, 0, 15)
        var blk = List[UInt8]()
        blk.resize(Q4_K_BLOCK_BYTES, UInt8(0))
        var d_bits = bitcast[DType.uint16](d_hat)
        blk[0] = UInt8(d_bits & 0xFF)
        blk[1] = UInt8((d_bits >> 8) & 0xFF)
        var dmin_bits = bitcast[DType.uint16](dmin_hat)
        blk[2] = UInt8(dmin_bits & 0xFF)
        blk[3] = UInt8((dmin_bits >> 8) & 0xFF)
        for j in range(8):
            if j < 4:
                blk[4 + j] = UInt8(ls[j] & 63)
                blk[8 + j] = UInt8(lm[j] & 63)
            else:
                blk[8 + j] = UInt8(
                    (ls[j] & 15) | ((lm[j] & 15) << 4)
                )
                blk[j] = blk[j] | UInt8((ls[j] >> 4) << 6)
                blk[4 + j] = blk[4 + j] | UInt8((lm[j] >> 4) << 6)
        for chunk in range(4):
            for lane in range(32):
                blk[16 + chunk * 32 + lane] = UInt8(
                    quants[chunk * 64 + lane]
                    | (quants[chunk * 64 + lane + 32] << 4)
                )
        for i in range(Q4_K_BLOCK_BYTES):
            out.append(blk[i])
    return out^


def quantize_q6_k(values: List[Float32]) raises -> List[UInt8]:
    """Quantizes F32 values into Q6_K payload bytes (210 B per
    256-value super-block), the inverse of the engine's Q6_K
    dequantizer (core/packed_quantization.packed_value kind 14).
    Rule, bound and refusals: see the QC-5 module header above."""
    var count = len(values)
    if count <= 0:
        raise Error("quantize_q6_k: element count must be positive (got 0)")
    if count % Q6_K_BLOCK_ELEMENTS != 0:
        raise Error(
            "quantize_q6_k: element count " + String(count)
            + " is not a multiple of the 256-value Q6_K super-block;"
            + " refusing to pad (GGUF has no padding semantics)"
        )
    var out = List[UInt8]()
    out.reserve(q6_k_payload_bytes(count))
    for block in range(count // Q6_K_BLOCK_ELEMENTS):
        var base = block * Q6_K_BLOCK_ELEMENTS
        var scales = List[Float32]()
        scales.resize(16, Float32(0.0))
        var stored = List[Int]()
        stored.resize(Q6_K_BLOCK_ELEMENTS, 32)
        var max_scale = Float32(0.0)
        for j in range(16):
            var sub = base + j * 16
            var amax = Float32(0.0)
            for i in range(16):
                var value = values[sub + i]
                if not isfinite(value):
                    raise Error(
                        "quantize_q6_k: non-finite value at index "
                        + String(sub + i) + " has no Q6_K encoding"
                    )
                var magnitude = _abs_f32(value)
                if magnitude > amax:
                    amax = magnitude
            var scale = amax / Float32(32.0)
            scales[j] = scale
            if scale > max_scale:
                max_scale = scale
            if scale != Float32(0.0):
                for i in range(16):
                    var l = _round_half_away_from_zero(values[sub + i] / scale)
                    stored[j * 16 + i] = _clamp_int(l, -32, 31) + 32
        var blk = List[UInt8]()
        blk.resize(Q6_K_BLOCK_BYTES, UInt8(0))
        if max_scale == Float32(0.0):
            for i in range(Q6_K_BLOCK_BYTES):
                out.append(blk[i])
            continue
        var d = max_scale / Float32(127.0)
        var d_hat = d.cast[f16]()
        if not isfinite(d_hat.cast[f32]()):
            raise Error(
                "quantize_q6_k: block " + String(block)
                + " super scale overflows the f16 range (max_scale "
                + String(max_scale)
                + "); refusing to emit a corrupt block"
            )
        var d_hat_f32 = d_hat.cast[f32]()
        var sc = List[Int]()
        sc.resize(16, 0)
        for j in range(16):
            sc[j] = _clamp_int(
                _round_half_away_from_zero(scales[j] / d), 0, 127
            )
            var s_hat = d_hat_f32 * Float32(sc[j])
            if s_hat == Float32(0.0):
                continue
            var sub = base + j * 16
            for i in range(16):
                var l = _round_half_away_from_zero(values[sub + i] / s_hat)
                stored[j * 16 + i] = _clamp_int(l, -32, 31) + 32
        for half in range(2):
            for lane in range(32):
                var s0 = stored[half * 128 + lane]
                var s1 = stored[half * 128 + lane + 32]
                var s2 = stored[half * 128 + lane + 64]
                var s3 = stored[half * 128 + lane + 96]
                blk[half * 64 + lane] = UInt8((s0 & 15) | ((s2 & 15) << 4))
                blk[half * 64 + lane + 32] = UInt8(
                    (s1 & 15) | ((s3 & 15) << 4)
                )
                blk[128 + half * 32 + lane] = UInt8(
                    (s0 >> 4)
                    | ((s1 >> 4) << 2)
                    | ((s2 >> 4) << 4)
                    | ((s3 >> 4) << 6)
                )
        for j in range(16):
            blk[192 + j] = UInt8(sc[j] & 0xFF)
        var d_bits = bitcast[DType.uint16](d_hat)
        blk[208] = UInt8(d_bits & 0xFF)
        blk[209] = UInt8((d_bits >> 8) & 0xFF)
        for i in range(Q6_K_BLOCK_BYTES):
            out.append(blk[i])
    return out^


# ---------------------------------------------------------------------
# QS-3: searched-fit K-quant packers -- ggml's own fits, ported.
#
# Same byte layouts, same super-block scale/min quantization, same
# stored-scale re-form second pass as the QC-5 writers above. The
# ONLY change is how each sub-block's (scale, min) [Q4_K] or signed
# scale [Q6_K] is chosen: ggml's weighted least-squares SEARCH
# instead of the plain min/max endpoint fit. Sources re-read from
# disk for this slice (~/llama.cpp-build/ggml/src/ggml-quants.c):
# make_qkx2_quants (L808), make_qx_quants (L637),
# quantize_row_q4_K_ref (L1467), quantize_row_q6_K_ref (L1879).
# Rounding inside the searched writers is ggml's nearest_int:
# round-to-nearest-EVEN (the QC-5 writers' half-away rule differs
# only on exact .5 ties; the searched writers use even so the port
# is faithful on ties too).
#
# Q4_K searched fit (per 32-value sub-block): weights
# w_i = av_x + |x_i|, av_x = sqrt(mean(x^2)) over the sub-block.
# Baseline: min clamped <= 0, iscale = 15/(max-min), weighted SSE
# of the affine reconstruction. Then 21 candidates
# is = 0..20 with iscale = (15 - 1.0 + 0.1*is)/(max-min): each
# candidate's levels are solved in closed form as the weighted
# least-squares affine fit (scale, min) of x on the levels
# (min re-clamped to <= 0 with scale = sum_xl/sum_l2), and the
# candidate with the lowest weighted SSE wins.
#
# Q6_K searched fit (per 16-value group): make_qx_quants with
# rmse_type 1 (weights w = x^2), qw = NULL. iscale = -32/max with
# max the SIGNED largest-|x| lane; initial levels clamped to
# [-32, 31]; least-squares scale = sum(w*x*l)/sum(w*l^2). Search
# is = -9..9 (skip 0) with iscale = -(32 + 0.1*is)/max, keeping
# the candidate maximizing sumlx^2/suml2. The returned scale is
# SIGNED (sign of max). Super-block: iscale = -128/max_scale over
# the signed group scales (max_scale = the largest-|scale| group
# scale, sign kept), d = f16(1/iscale), per-group i8 scale =
# min(127, nearest_int(iscale*scale_j)) -- signed, read back by
# packed_value kind 14 as Int8. Groups with amax < 1e-15
# (GROUP_MAX_EPS) are zero; a super-block whose every group is
# zero is emitted as 210 zero bytes, mirroring the ref's memset.
#
# Refusals: identical to the QC-5 writers (count, finiteness,
# f16-overflow of the stored super scale), with the tensor index
# named. The legacy writers remain the default everywhere; the
# searched writers are selected only by the CLI --fit searched
# mode (QS-3.2) until fixture grades (QS-3.3) arbitrate.


def _nearest_int_even(value: Float32) -> Int:
    """ggml nearest_int semantics (round to nearest, ties to even)
    for the small magnitudes the K fits produce (|value| <= ~130).
    Truncation toward zero plus the fractional part decides; exact
    .5 ties go to the even neighbour."""
    var t = Int(value)
    var frac = value - Float32(t)
    if frac > Float32(0.5):
        return t + 1
    if frac < Float32(-0.5):
        return t - 1
    if frac == Float32(0.5):
        return t if t % 2 == 0 else t + 1
    if frac == Float32(-0.5):
        return t if t % 2 == 0 else t - 1
    return t


def _make_qkx2_searched(
    values: List[Float32], off: Int, weights: List[Float32]
) -> Tuple[Float32, Float32, List[Int]]:
    """ggml make_qkx2_quants(32, 15, x, weights, ..., rmin=-1.0,
    rdelta=0.1, nstep=20, use_mad=false) for the 32 values at
    values[off..off+32]: returns (scale, minute, levels) with
    minute = -min >= 0 and levels in [0, 15]."""
    var mn = values[off]
    var mx = values[off]
    var sum_w = weights[0]
    var sum_x = weights[0] * values[off]
    for i in range(1, 32):
        var v = values[off + i]
        if v < mn:
            mn = v
        if v > mx:
            mx = v
        sum_w += weights[i]
        sum_x += weights[i] * v
    if mn > Float32(0.0):
        mn = Float32(0.0)
    var levels = List[Int]()
    levels.resize(32, 0)
    if mx == mn:
        return (Float32(0.0), -mn, levels^)
    var iscale = Float32(15.0) / (mx - mn)
    var scale = Float32(1.0) / iscale
    var minimum = mn
    var best_error = Float32(0.0)
    for i in range(32):
        var l = _clamp_int(
            _nearest_int_even(iscale * (values[off + i] - minimum)), 0, 15
        )
        levels[i] = l
        var diff = scale * Float32(l) + minimum - values[off + i]
        best_error += weights[i] * diff * diff
    for istep in range(21):
        var cand_iscale = (
            Float32(-1.0) + Float32(0.1) * Float32(istep) + Float32(15.0)
        ) / (mx - mn)
        var aux = List[Int]()
        aux.resize(32, 0)
        var sum_l = Float32(0.0)
        var sum_l2 = Float32(0.0)
        var sum_xl = Float32(0.0)
        for i in range(32):
            var l = _clamp_int(
                _nearest_int_even(cand_iscale * (values[off + i] - mn)),
                0,
                15,
            )
            aux[i] = l
            var w = weights[i]
            sum_l += w * Float32(l)
            sum_l2 += w * Float32(l) * Float32(l)
            sum_xl += w * Float32(l) * values[off + i]
        var d_denom = sum_w * sum_l2 - sum_l * sum_l
        if d_denom > Float32(0.0):
            var this_scale = (sum_w * sum_xl - sum_x * sum_l) / d_denom
            var this_min = (sum_l2 * sum_x - sum_l * sum_xl) / d_denom
            if this_min > Float32(0.0):
                this_min = Float32(0.0)
                this_scale = sum_xl / sum_l2
            var cur_error = Float32(0.0)
            for i in range(32):
                var diff = (
                    this_scale * Float32(aux[i]) + this_min - values[off + i]
                )
                cur_error += weights[i] * diff * diff
            if cur_error < best_error:
                for i in range(32):
                    levels[i] = aux[i]
                best_error = cur_error
                scale = this_scale
                minimum = this_min
    return (scale, -minimum, levels^)


def quantize_q4_k_searched(values: List[Float32]) raises -> List[UInt8]:
    """Q4_K payload with ggml's searched fit (make_qkx2_quants).
    Byte layout, super-block quantization and stored re-form pass
    mirror quantize_q4_k exactly; only the per-sub-block fit and
    the tie rounding differ. Rule: see the QS-3 header above."""
    var count = len(values)
    if count <= 0:
        raise Error(
            "quantize_q4_k_searched: element count must be positive (got 0)"
        )
    if count % Q4_K_BLOCK_ELEMENTS != 0:
        raise Error(
            "quantize_q4_k_searched: element count " + String(count)
            + " is not a multiple of the 256-value Q4_K super-block;"
            + " refusing to pad (GGUF has no padding semantics)"
        )
    var out = List[UInt8]()
    out.reserve(q4_k_payload_bytes(count))
    for block in range(count // Q4_K_BLOCK_ELEMENTS):
        var base = block * Q4_K_BLOCK_ELEMENTS
        var scales = List[Float32]()
        scales.resize(8, Float32(0.0))
        var mins = List[Float32]()
        mins.resize(8, Float32(0.0))
        var quants = List[Int]()
        quants.resize(Q4_K_BLOCK_ELEMENTS, 0)
        var max_scale = Float32(0.0)
        var max_min = Float32(0.0)
        for j in range(8):
            var sub = base + j * 32
            var sum_x2 = Float32(0.0)
            for i in range(32):
                var value = values[sub + i]
                if not isfinite(value):
                    raise Error(
                        "quantize_q4_k_searched: non-finite value at index "
                        + String(sub + i) + " has no Q4_K encoding"
                    )
                sum_x2 += value * value
            var av_x = sqrt(sum_x2 / Float32(32.0))
            var weights = List[Float32]()
            weights.resize(32, Float32(0.0))
            for i in range(32):
                weights[i] = av_x + _abs_f32(values[sub + i])
            var fit = _make_qkx2_searched(values, sub, weights)
            scales[j] = fit[0]
            mins[j] = fit[1]
            for i in range(32):
                quants[j * 32 + i] = fit[2][i]
            if fit[0] > max_scale:
                max_scale = fit[0]
            if fit[1] > max_min:
                max_min = fit[1]
        var d = max_scale / Float32(63.0)
        var dmin = max_min / Float32(63.0)
        var d_hat = d.cast[f16]()
        var dmin_hat = dmin.cast[f16]()
        if not isfinite(d_hat.cast[f32]()) or not isfinite(
            dmin_hat.cast[f32]()
        ):
            raise Error(
                "quantize_q4_k_searched: block " + String(block)
                + " super scale overflows the f16 range (max_scale "
                + String(max_scale) + ", max_min " + String(max_min)
                + "); refusing to emit a corrupt block"
            )
        var d_hat_f32 = d_hat.cast[f32]()
        var dmin_hat_f32 = dmin_hat.cast[f32]()
        var inv_scale = Float32(0.0)
        if max_scale > Float32(0.0):
            inv_scale = Float32(63.0) / max_scale
        var inv_min = Float32(0.0)
        if max_min > Float32(0.0):
            inv_min = Float32(63.0) / max_min
        var ls = List[Int]()
        ls.resize(8, 0)
        var lm = List[Int]()
        lm.resize(8, 0)
        for j in range(8):
            ls[j] = _clamp_int(
                _nearest_int_even(inv_scale * scales[j]), 0, 63
            )
            lm[j] = _clamp_int(_nearest_int_even(inv_min * mins[j]), 0, 63)
        # Re-form against the STORED scale/min (the ref's second
        # pass), exactly as the legacy writer does.
        for j in range(8):
            var s_hat = d_hat_f32 * Float32(ls[j])
            if s_hat == Float32(0.0):
                continue
            var m_hat = dmin_hat_f32 * Float32(lm[j])
            var sub = base + j * 32
            for i in range(32):
                var q = _nearest_int_even(
                    (values[sub + i] + m_hat) / s_hat
                )
                quants[j * 32 + i] = _clamp_int(q, 0, 15)
        var blk = List[UInt8]()
        blk.resize(Q4_K_BLOCK_BYTES, UInt8(0))
        var d_bits = bitcast[DType.uint16](d_hat)
        blk[0] = UInt8(d_bits & 0xFF)
        blk[1] = UInt8((d_bits >> 8) & 0xFF)
        var dmin_bits = bitcast[DType.uint16](dmin_hat)
        blk[2] = UInt8(dmin_bits & 0xFF)
        blk[3] = UInt8((dmin_bits >> 8) & 0xFF)
        for j in range(8):
            if j < 4:
                blk[4 + j] = UInt8(ls[j] & 63)
                blk[8 + j] = UInt8(lm[j] & 63)
            else:
                blk[8 + j] = UInt8(
                    (ls[j] & 15) | ((lm[j] & 15) << 4)
                )
                blk[j] = blk[j] | UInt8((ls[j] >> 4) << 6)
                blk[4 + j] = blk[4 + j] | UInt8((lm[j] >> 4) << 6)
        for chunk in range(4):
            for lane in range(32):
                blk[16 + chunk * 32 + lane] = UInt8(
                    quants[chunk * 64 + lane]
                    | (quants[chunk * 64 + lane + 32] << 4)
                )
        for i in range(Q4_K_BLOCK_BYTES):
            out.append(blk[i])
    return out^


def _make_qx_searched(
    values: List[Float32], off: Int
) -> Tuple[Float32, List[Int]]:
    """ggml make_qx_quants(16, 32, x, L, rmse_type=1, qw=NULL) for
    the 16 values at values[off..off+16]: returns (signed scale,
    levels) with levels in [-32, 31] (NOT offset by +32; the
    caller stores level + 32). Weights are x^2 (rmse_type 1)."""
    var levels = List[Int]()
    levels.resize(16, 0)
    var max_signed = values[off]
    var amax = _abs_f32(values[off])
    for i in range(1, 16):
        var magnitude = _abs_f32(values[off + i])
        if magnitude > amax:
            amax = magnitude
            max_signed = values[off + i]
    if amax < Float32(1e-15):
        return (Float32(0.0), levels^)
    var iscale = Float32(-32.0) / max_signed
    var sumlx = Float32(0.0)
    var suml2 = Float32(0.0)
    for i in range(16):
        var l = _clamp_int(
            _nearest_int_even(iscale * values[off + i]), -32, 31
        )
        levels[i] = l
        var w = values[off + i] * values[off + i]
        sumlx += w * values[off + i] * Float32(l)
        suml2 += w * Float32(l) * Float32(l)
    var scale = Float32(0.0)
    if suml2 != Float32(0.0):
        scale = sumlx / suml2
    var best = scale * sumlx
    for istep in range(-9, 10):
        if istep == 0:
            continue
        var cand_iscale = (
            -(Float32(32.0) + Float32(0.1) * Float32(istep)) / max_signed
        )
        var cand_sumlx = Float32(0.0)
        var cand_suml2 = Float32(0.0)
        var cand = List[Int]()
        cand.resize(16, 0)
        for i in range(16):
            var l = _clamp_int(
                _nearest_int_even(cand_iscale * values[off + i]), -32, 31
            )
            cand[i] = l
            var w = values[off + i] * values[off + i]
            cand_sumlx += w * values[off + i] * Float32(l)
            cand_suml2 += w * Float32(l) * Float32(l)
        if cand_suml2 > Float32(0.0) and cand_sumlx * cand_sumlx > best * cand_suml2:
            for i in range(16):
                levels[i] = cand[i]
            scale = cand_sumlx / cand_suml2
            best = scale * cand_sumlx
    return (scale, levels^)


def quantize_q6_k_searched(values: List[Float32]) raises -> List[UInt8]:
    """Q6_K payload with ggml's searched fit (make_qx_quants,
    signed scales). Byte layout and stored re-form pass mirror
    quantize_q6_k; the fit and the super-block rule are the ref's:
    iscale = -128/max_scale (signed), d = f16(1/iscale), per-group
    i8 scales signed. Rule: see the QS-3 header above."""
    var count = len(values)
    if count <= 0:
        raise Error(
            "quantize_q6_k_searched: element count must be positive (got 0)"
        )
    if count % Q6_K_BLOCK_ELEMENTS != 0:
        raise Error(
            "quantize_q6_k_searched: element count " + String(count)
            + " is not a multiple of the 256-value Q6_K super-block;"
            + " refusing to pad (GGUF has no padding semantics)"
        )
    var out = List[UInt8]()
    out.reserve(q6_k_payload_bytes(count))
    for block in range(count // Q6_K_BLOCK_ELEMENTS):
        var base = block * Q6_K_BLOCK_ELEMENTS
        var scales = List[Float32]()
        scales.resize(16, Float32(0.0))
        var stored = List[Int]()
        stored.resize(Q6_K_BLOCK_ELEMENTS, 32)
        var max_scale = Float32(0.0)
        var max_abs_scale = Float32(0.0)
        for j in range(16):
            var sub = base + j * 16
            for i in range(16):
                if not isfinite(values[sub + i]):
                    raise Error(
                        "quantize_q6_k_searched: non-finite value at index "
                        + String(sub + i) + " has no Q6_K encoding"
                    )
            var fit = _make_qx_searched(values, sub)
            scales[j] = fit[0]
            for i in range(16):
                stored[j * 16 + i] = fit[1][i] + 32
            var magnitude = _abs_f32(fit[0])
            if magnitude > max_abs_scale:
                max_abs_scale = magnitude
                max_scale = fit[0]
        var blk = List[UInt8]()
        blk.resize(Q6_K_BLOCK_BYTES, UInt8(0))
        if max_abs_scale < Float32(1e-15):
            for i in range(Q6_K_BLOCK_BYTES):
                out.append(blk[i])
            continue
        var iscale = Float32(-128.0) / max_scale
        var d_hat = (Float32(1.0) / iscale).cast[f16]()
        if not isfinite(d_hat.cast[f32]()):
            raise Error(
                "quantize_q6_k_searched: block " + String(block)
                + " super scale overflows the f16 range (max_scale "
                + String(max_scale)
                + "); refusing to emit a corrupt block"
            )
        var d_hat_f32 = d_hat.cast[f32]()
        var sc = List[Int]()
        sc.resize(16, 0)
        for j in range(16):
            var s = _nearest_int_even(iscale * scales[j])
            if s > 127:
                s = 127
            sc[j] = s
            var s_hat = d_hat_f32 * Float32(sc[j])
            if s_hat == Float32(0.0):
                continue
            var sub = base + j * 16
            for i in range(16):
                var l = _clamp_int(
                    _nearest_int_even(values[sub + i] / s_hat), -32, 31
                )
                stored[j * 16 + i] = l + 32
        for half in range(2):
            for lane in range(32):
                var s0 = stored[half * 128 + lane]
                var s1 = stored[half * 128 + lane + 32]
                var s2 = stored[half * 128 + lane + 64]
                var s3 = stored[half * 128 + lane + 96]
                blk[half * 64 + lane] = UInt8((s0 & 15) | ((s2 & 15) << 4))
                blk[half * 64 + lane + 32] = UInt8(
                    (s1 & 15) | ((s3 & 15) << 4)
                )
                blk[128 + half * 32 + lane] = UInt8(
                    (s0 >> 4)
                    | ((s1 >> 4) << 2)
                    | ((s2 >> 4) << 4)
                    | ((s3 >> 4) << 6)
                )
        for j in range(16):
            blk[192 + j] = UInt8(sc[j] & 0xFF)
        var d_bits = bitcast[DType.uint16](d_hat)
        blk[208] = UInt8(d_bits & 0xFF)
        blk[209] = UInt8((d_bits >> 8) & 0xFF)
        for i in range(Q6_K_BLOCK_BYTES):
            out.append(blk[i])
    return out^
