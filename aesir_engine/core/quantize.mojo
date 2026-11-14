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
