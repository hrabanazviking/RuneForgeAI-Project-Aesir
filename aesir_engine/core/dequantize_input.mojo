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
    # Dense F32 / F16 / BF16 plus the E2B census's K-quants.
    return (
        ggml_type == 0
        or ggml_type == 1
        or ggml_type == 30
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
        + " has no F32 dequantizer wired in QC-3b (the E2B census"
        + " contains only Q4_K/Q5_K/Q6_K quantized tensors); stays"
        + " at source type"
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
