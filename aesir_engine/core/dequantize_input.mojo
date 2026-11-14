# core/dequantize_input.mojo
# The dequantizing INPUT path for the compression workstream
# (QC-3b stage 2): F32 values out of a stored GGUF tensor, through
# the engine's OWN dequantizers -- never a second implementation.
#
# QC-3a's converter widened dense floats only (F16/F32/BF16) and
# kept every quantized tensor at its source type. A Q4_K_M source
# (gemma-4-E2B, the QC-3b conversion) is mostly quantized tensors,
# so requantization first needs their values. This module is that
# reader: a thin, checked dispatch over
# core/packed_quantization.packed_value, the engine's scalar packed
# reader (declared in-tree bit-identical to compute.mojo's SIMD
# K-quant dequantizer), which returns Float32 directly -- no F16
# intermediate, so QC-2 finding F-1's f16-output range limit does
# not apply to values obtained here.
#
# Coverage is EXACTLY the gemma-4-E2B census (measured by an
# independent Python parse of the pinned source file, QC-3b):
# the file's quantized tensors are Q4_K (GGML 12, 212 tensors),
# Q5_K (GGML 13, 1 tensor) and Q6_K (GGML 14, 34 tensors); its
# dense tensors are F32 (0) and BF16 (30), which packed_value also
# reads. Every other GGML type is REFUSED here by name and stays
# at source type under the converter's per-role policy -- see
# dequant_input_keep_reason. Wiring a further type is a deliberate
# act in a later slice (its dequantizer must be the engine's own
# and its round-trip proof must land with it), never a fallthrough:
# packed_value itself would silently decode an unlisted kind with
# the Q4_K/Q5_K layout, which is exactly the failure this guard
# exists to prevent.

from core.packed_quantization import Bytes, packed_value


def dequant_input_supported(ggml_type: Int) -> Bool:
    # Dense F32 / F16 / BF16 plus the E2B census's K-quants, plus
    # Q8_0 (QC-6: the 27B source's own storage format, wired below
    # through the engine's Q8_0 layout -- core/compute.mojo
    # dequantize_q8_0 walks exactly these bytes: f16 scale @0 of
    # each 34-byte block, 32 int8 quants @2..34, value = q * d).
    return (
        ggml_type == 0
        or ggml_type == 1
        or ggml_type == 30
        or ggml_type == 8
        or ggml_type == 12
        or ggml_type == 13
        or ggml_type == 14
    )


def dequant_input_type_name(ggml_type: Int) -> String:
    if ggml_type == 0:
        return String("F32")
    if ggml_type == 1:
        return String("F16")
    if ggml_type == 30:
        return String("BF16")
    if ggml_type == 8:
        return String("Q8_0")
    if ggml_type == 12:
        return String("Q4_K")
    if ggml_type == 13:
        return String("Q5_K")
    if ggml_type == 14:
        return String("Q6_K")
    return String("GGML type ") + String(ggml_type)


def dequant_input_keep_reason(ggml_type: Int) -> String:
    # The named reason a tensor of this type stays at source type
    # in a QC-3b conversion (converter policy surface).
    return (
        String("source type ")
        + String(ggml_type)
        + " has no F32 dequantizer wired (QC-3b wired Q4_K/Q5_K/Q6_K;"
        + " QC-6 wired Q8_0); stays at source type"
    )


def dequantize_value_f32(
    w: Bytes, base: Int, ggml_type: Int, index: Int
) raises -> Float32:
    # One element's F32 value from a stored tensor whose payload
    # starts at byte offset `base` in the buffer `w` (a GGUFSeer
    # mmap, in the converter's use). Refuses unwired types by name.
    if not dequant_input_supported(ggml_type):
        raise Error(
            "dequantize_input: " + dequant_input_keep_reason(ggml_type)
        )
    if ggml_type == 8:
        # Q8_0 (QC-6): packed_value has no Q8_0 kind (its fallthrough
        # is the Q4_K/Q5_K layout -- the exact silent-decode hazard
        # this module exists to prevent), so Q8_0 is decoded here
        # directly from the engine's own block layout, F32 out (no
        # F16 intermediate, so the F-1 range limit does not apply).
        var block = index // 32
        var lane = index % 32
        var p = base + block * 34
        var d = (
            w.unsafe_offset(p)
            .unsafe_bitcast[Float16]()
            .unsafe_load()
            .cast[DType.float32]()
        )
        var q = w.unsafe_offset(p + 2).unsafe_bitcast[Int8]().unsafe_load(lane)
        return d * Float32(q)
    return packed_value(w, base, ggml_type, index)


def dequantize_range_f32(
    w: Bytes, base: Int, ggml_type: Int, start: Int, count: Int
) raises -> List[Float32]:
    # `count` consecutive F32 values starting at element `start` --
    # the converter's row-at-a-time read (row = dim0 elements).
    if count < 0 or start < 0:
        raise Error("dequantize_input: negative range")
    var values = List[Float32]()
    values.reserve(count)
    for i in range(count):
        values.append(dequantize_value_f32(w, base, ggml_type, start + i))
    return values^
