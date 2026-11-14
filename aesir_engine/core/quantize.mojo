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

from std.math import isfinite
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
