# core/compute.mojo
# The Forge of Nidavellir: Aesir Engine Core Compute Kernels
#
# Here, the raw, mathematical truth of the model is hammered into being.
# We bypass the bloated abstractions of Midgard, striking the silicon directly
# through SIMD and parallelized runic operations.

from core.gemma4_kernels import packed_value
from std.math import exp, max, sqrt, cos, sin, isinf, isnan
from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from std.algorithm import vectorize

from .mimir_well import (
    RuneTensor,
    MimirWell,
    NPUBackendType,
    GPURealmType,
    CompressedFormatType,
    f16,
    f32,
    int4,
)
from .cuda_gate import CUDAGate
from .cuda_compute import CUDAF16GemmExecutor
from .metal_gate import MetalGate
from .intel_gate import IntelGate
from .amd_gate import AMDGate
from .npu_gate import NPUGate
from .external_quantization import (
    GPTQ4BitMatrix,
    GPTQ8BitMatrix,
    AWQ4BitMatrix,
    EXL2Matrix,
    SmoothQuantW8A8Matrix,
    HQQ4BitAxis1Matrix,
    dequantize_gptq_4bit_matrix,
    dequantize_gptq_8bit_matrix,
    gemm_gptq_4bit_matrix,
    gemm_gptq_8bit_matrix,
    dequantize_awq_4bit_matrix,
    gemm_awq_4bit_matrix,
    dequantize_exl2_matrix,
    gemm_exl2_matrix,
    dequantize_smoothquant_weights,
    gemm_smoothquant_w8a8,
    dequantize_hqq_4bit_axis1,
    gemm_hqq_4bit_axis1,
)
from .extreme_quantization import (
    dequantize_iq1_s_blocks,
    dequantize_iq2_xxs_blocks,
    gemm_iq1_s_blocks,
    gemm_iq2_xxs_blocks,
)

comptime simd_w_f16 = 16
comptime simd_w_f32 = 16


struct BlockQ4_0(Copyable, ImplicitlyCopyable):
    var scale: Scalar[f16]
    var qs: SIMD[DType.uint8, 16]

    def __init__(out self, scale: Scalar[f16], qs: SIMD[DType.uint8, 16]):
        self.scale = scale
        self.qs = qs

    def __copyinit__(out self, existing: Self):
        self.scale = existing.scale
        self.qs = existing.qs


struct BlockQ4_1(Copyable, ImplicitlyCopyable):
    var scale: Scalar[f16]
    var min_val: Scalar[f16]
    var qs: SIMD[DType.uint8, 16]

    def __init__(
        out self,
        scale: Scalar[f16],
        min_val: Scalar[f16],
        qs: SIMD[DType.uint8, 16],
    ):
        self.scale = scale
        self.min_val = min_val
        self.qs = qs

    def __copyinit__(out self, existing: Self):
        self.scale = existing.scale
        self.min_val = existing.min_val
        self.qs = existing.qs


struct BlockQ5_0(Copyable, ImplicitlyCopyable):
    var scale: Scalar[f16]
    var qh: SIMD[DType.uint8, 4]
    var qs: SIMD[DType.uint8, 16]

    def __init__(
        out self,
        scale: Scalar[f16],
        qh: SIMD[DType.uint8, 4],
        qs: SIMD[DType.uint8, 16],
    ):
        self.scale = scale
        self.qh = qh
        self.qs = qs

    def __copyinit__(out self, existing: Self):
        self.scale = existing.scale
        self.qh = existing.qh
        self.qs = existing.qs


struct BlockQ5_1(Copyable, ImplicitlyCopyable):
    var scale: Scalar[f16]
    var min_val: Scalar[f16]
    var qh: SIMD[DType.uint8, 4]
    var qs: SIMD[DType.uint8, 16]

    def __init__(
        out self,
        scale: Scalar[f16],
        min_val: Scalar[f16],
        qh: SIMD[DType.uint8, 4],
        qs: SIMD[DType.uint8, 16],
    ):
        self.scale = scale
        self.min_val = min_val
        self.qh = qh
        self.qs = qs

    def __copyinit__(out self, existing: Self):
        self.scale = existing.scale
        self.min_val = existing.min_val
        self.qh = existing.qh
        self.qs = existing.qs


struct BlockQ8_0(Copyable, ImplicitlyCopyable):
    var scale: Scalar[f16]
    var qs: SIMD[DType.int8, 32]

    def __init__(out self, scale: Scalar[f16], qs: SIMD[DType.int8, 32]):
        self.scale = scale
        self.qs = qs

    def __copyinit__(out self, existing: Self):
        self.scale = existing.scale
        self.qs = existing.qs


@always_inline
def dequantize_ggml_k(
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_elements: Int,
    ggml_type: Int,
) raises:
    """Decode canonical GGML Q2_K through Q6_K packed bytes."""
    if num_elements <= 0 or num_elements % 256 != 0:
        raise Error("dequantize_ggml_k: element count must contain complete 256-value blocks")
    if Int(data) <= 1 or Int(out_ptr) <= 1:
        raise Error("dequantize_ggml_k: invalid input or output storage")
    if ggml_type < 10 or ggml_type > 14:
        raise Error("dequantize_ggml_k: unsupported GGML tensor type")
    for i in range(num_elements):
        out_ptr.unsafe_store(i, packed_value(data, 0, ggml_type, i).cast[f16]())


@always_inline
def _dequantize_ggml_k_blocks(
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_blocks: Int,
    ggml_type: Int,
    format_name: String,
) raises:
    """Checked block-count adapter for the public format-specific APIs."""
    if num_blocks <= 0:
        raise Error(format_name + ": block count must be positive")
    var num_elements = num_blocks * 256
    if num_elements <= 0 or num_elements // 256 != num_blocks:
        raise Error(format_name + ": element count overflow")
    dequantize_ggml_k(data, out_ptr, num_elements, ggml_type)


def dequantize_q2_k_block(
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_blocks: Int,
) raises:
    _dequantize_ggml_k_blocks(data, out_ptr, num_blocks, 10, "Q2_K")


def dequantize_q3_k_m(
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_blocks: Int,
) raises:
    _dequantize_ggml_k_blocks(data, out_ptr, num_blocks, 11, "Q3_K")


def dequantize_q3_k_s(
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_blocks: Int,
) raises:
    dequantize_q3_k_m(data, out_ptr, num_blocks)


def dequantize_q3_k_l(
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_blocks: Int,
) raises:
    dequantize_q3_k_m(data, out_ptr, num_blocks)


def dequantize_q4_k_m(
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_blocks: Int,
) raises:
    _dequantize_ggml_k_blocks(data, out_ptr, num_blocks, 12, "Q4_K")


def dequantize_q5_k_m(
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_blocks: Int,
) raises:
    _dequantize_ggml_k_blocks(data, out_ptr, num_blocks, 13, "Q5_K")


def dequantize_q5_k_s(
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_blocks: Int,
) raises:
    dequantize_q5_k_m(data, out_ptr, num_blocks)


def dequantize_q6_k_block(
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_blocks: Int,
) raises:
    _dequantize_ggml_k_blocks(data, out_ptr, num_blocks, 14, "Q6_K")


@always_inline
def dequantize_q4_0(
    block_ptr: Pointer[BlockQ4_0, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_blocks: Int,
):
    if num_blocks <= 0:
        return
    var b_bytes = block_ptr.unsafe_bitcast[Byte]()
    for b in range(num_blocks):
        var b_ptr = b_bytes.unsafe_offset(b * 18)
        var scale = b_ptr.unsafe_bitcast[Scalar[f16]]().unsafe_load()
        var out_offset = b * 32
        for i in range(16):
            var qs = b_ptr.unsafe_load(2 + i)
            var l = (Scalar[f16](qs & 0x0F) - 8.0) * scale
            var u = (Scalar[f16]((qs >> 4) & 0x0F) - 8.0) * scale
            out_ptr.unsafe_store(out_offset + i, l)
            out_ptr.unsafe_store(out_offset + 16 + i, u)


@always_inline
def dequantize_q4_1(
    block_ptr: Pointer[BlockQ4_1, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_blocks: Int,
):
    if num_blocks <= 0:
        return
    for b in range(num_blocks):
        var blk = block_ptr.unsafe_offset(b)[]
        var scale = blk.scale
        var min_val = blk.min_val
        var qs = blk.qs
        var out_offset = b * 32
        for i in range(16):
            var l = Scalar[f16](qs[i] & 0x0F) * scale + min_val
            var u = Scalar[f16]((qs[i] >> 4) & 0x0F) * scale + min_val
            out_ptr.unsafe_store(out_offset + i, l)
            out_ptr.unsafe_store(out_offset + 16 + i, u)


@always_inline
def dequantize_q5_0(
    block_ptr: Pointer[BlockQ5_0, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_blocks: Int,
):
    if num_blocks <= 0:
        return
    for b in range(num_blocks):
        var blk = block_ptr.unsafe_offset(b)[]
        var scale = blk.scale
        var qh = blk.qh
        var qs = blk.qs
        var out_offset = b * 32
        for i in range(16):
            var qh_byte_lo = qh[i // 8]
            var h_bit_lo = Scalar[f16](
                (qh_byte_lo >> Scalar[DType.uint8](i % 8)) & 1
            )
            var qh_byte_hi = qh[(i + 16) // 8]
            var h_bit_hi = Scalar[f16](
                (qh_byte_hi >> Scalar[DType.uint8]((i + 16) % 8)) & 1
            )

            var l_val = (Scalar[f16](qs[i] & 0x0F) + h_bit_lo * 16.0) - 16.0
            var u_val = (
                Scalar[f16]((qs[i] >> 4) & 0x0F) + h_bit_hi * 16.0
            ) - 16.0
            out_ptr.unsafe_store(out_offset + i, l_val * scale)
            out_ptr.unsafe_store(out_offset + 16 + i, u_val * scale)


@always_inline
def dequantize_q5_1(
    block_ptr: Pointer[BlockQ5_1, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_blocks: Int,
):
    if num_blocks <= 0:
        return
    for b in range(num_blocks):
        var blk = block_ptr.unsafe_offset(b)[]
        var scale = blk.scale
        var min_val = blk.min_val
        var qh = blk.qh
        var qs = blk.qs
        var out_offset = b * 32
        for i in range(16):
            var qh_byte_lo = qh[i // 8]
            var h_bit_lo = Scalar[f16](
                (qh_byte_lo >> Scalar[DType.uint8](i % 8)) & 1
            )
            var qh_byte_hi = qh[(i + 16) // 8]
            var h_bit_hi = Scalar[f16](
                (qh_byte_hi >> Scalar[DType.uint8]((i + 16) % 8)) & 1
            )

            var l_val = Scalar[f16](qs[i] & 0x0F) + h_bit_lo * 16.0
            var u_val = Scalar[f16]((qs[i] >> 4) & 0x0F) + h_bit_hi * 16.0
            out_ptr.unsafe_store(out_offset + i, l_val * scale + min_val)
            out_ptr.unsafe_store(out_offset + 16 + i, u_val * scale + min_val)


@always_inline
def dequantize_q8_0(
    block_ptr: Pointer[BlockQ8_0, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_blocks: Int,
):
    if num_blocks <= 0:
        return
    var b_bytes = block_ptr.unsafe_bitcast[Byte]()
    for b in range(num_blocks):
        var b_ptr = b_bytes.unsafe_offset(b * 34)
        var scale = b_ptr.unsafe_bitcast[Scalar[f16]]().unsafe_load()
        var out_offset = b * 32
        for i in range(32):
            var q_val = b_ptr.unsafe_load(2 + i).cast[DType.int8]()
            out_ptr.unsafe_store(out_offset + i, Scalar[f16](q_val) * scale)


@always_inline
def dequantize_q8_1(
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_blocks: Int,
):
    """Decode canonical 40-byte GGML Q8_1 blocks; the stored sum is auxiliary."""
    if num_blocks <= 0:
        return
    for b in range(num_blocks):
        var p = b * 40
        var scale = data.unsafe_offset(p).unsafe_bitcast[Float32]().unsafe_load()
        var out_offset = b * 32
        for i in range(32):
            var q = data.unsafe_load(p + 8 + i).cast[DType.int8]()
            out_ptr.unsafe_store(out_offset + i, (Float32(q) * scale).cast[f16]())


@always_inline
def dequantize_fp8_e4m3(
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_elements: Int,
):
    if num_elements <= 0:
        return
    for i in range(num_elements):
        var b = data.unsafe_load(i)
        var sign_bit = Int((b >> 7) & 1)
        var s: Scalar[f16] = 1.0 if sign_bit == 0 else -1.0
        var exp = Int((b >> 3) & 0x0F)
        var mant = Scalar[f16](b & 0x07)
        var val: Scalar[f16]
        if exp == 0:
            val = s * Scalar[f16](0.015625) * (mant / 8.0)
        elif exp == 15 and (b & 0x07) == 7:
            val = 0.0
        else:
            var pow2 = Scalar[f16](1.0)
            var shift = exp - 7
            if shift >= 0:
                for _ in range(shift):
                    pow2 *= 2.0
            else:
                for _ in range(-shift):
                    pow2 *= 0.5
            val = s * pow2 * (1.0 + mant / 8.0)
        out_ptr.unsafe_store(i, val)


@always_inline
def dequantize_fp8_e5m2(
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_elements: Int,
):
    if num_elements <= 0:
        return
    for i in range(num_elements):
        var b = data.unsafe_load(i)
        var sign_bit = Int((b >> 7) & 1)
        var s: Scalar[f16] = 1.0 if sign_bit == 0 else -1.0
        var exp = Int((b >> 2) & 0x1F)
        var mant = Scalar[f16](b & 0x03)
        var val: Scalar[f16]
        if exp == 0:
            val = s * Scalar[f16](0.00006103515625) * (mant / 4.0)
        elif exp == 31:
            val = 0.0
        else:
            var pow2 = Scalar[f16](1.0)
            var shift = exp - 15
            if shift >= 0:
                for _ in range(shift):
                    pow2 *= 2.0
            else:
                for _ in range(-shift):
                    pow2 *= 0.5
            val = s * pow2 * (1.0 + mant / 4.0)
        out_ptr.unsafe_store(i, val)


@always_inline
def dequantize_gptq_4bit(
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_elements: Int,
) raises:
    _ = data
    _ = out_ptr
    _ = num_elements
    raise Error("GPTQ dequantization requires format-specific scales, zero points, groups, and packing metadata; it is not implemented")


@always_inline
def dequantize_gptq_4bit(
    matrix: GPTQ4BitMatrix,
    out_ptr: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    """Dequantize a validated AutoGPTQ 4-bit matrix to `[out, in]` F16."""
    dequantize_gptq_4bit_matrix(matrix, out_ptr, output_elements)


@always_inline
def dequantize_gptq_8bit(
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_elements: Int,
) raises:
    _ = data
    _ = out_ptr
    _ = num_elements
    raise Error("GPTQ 8-bit byte-only dequantization is not implemented because it lacks scales, zero points, groups, and packing metadata; use the metadata-aware overload")


@always_inline
def dequantize_gptq_8bit(
    matrix: GPTQ8BitMatrix,
    out_ptr: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    dequantize_gptq_8bit_matrix(matrix, out_ptr, output_elements)


@always_inline
def dequantize_awq_4bit(
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_elements: Int,
) raises:
    _ = data
    _ = out_ptr
    _ = num_elements
    raise Error("AWQ dequantization requires format-specific scales, zero points, groups, and packing metadata; it is not implemented")


@always_inline
def dequantize_awq_4bit(
    matrix: AWQ4BitMatrix,
    out_ptr: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    dequantize_awq_4bit_matrix(matrix, out_ptr, output_elements)


@always_inline
def dequantize_exl2(
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_elements: Int,
) raises:
    _ = data
    _ = out_ptr
    _ = num_elements
    raise Error("EXL2 dequantization requires its variable-bit layout and tensor metadata; it is not implemented")


@always_inline
def dequantize_exl2(
    matrix: EXL2Matrix,
    out_ptr: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    dequantize_exl2_matrix(matrix, out_ptr, output_elements)


@always_inline
def dequantize_hqq(
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_elements: Int,
) raises:
    _ = data
    _ = out_ptr
    _ = num_elements
    raise Error("HQQ dequantization requires tensor-specific scale, zero, grouping, and packing metadata; it is not implemented")


@always_inline
def dequantize_hqq(
    matrix: HQQ4BitAxis1Matrix,
    out_ptr: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    dequantize_hqq_4bit_axis1(matrix, out_ptr, output_elements)


@always_inline
def dequantize_smoothquant_int8(
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_elements: Int,
) raises:
    _ = data
    _ = out_ptr
    _ = num_elements
    raise Error("SmoothQuant execution requires activation and weight scales with channel metadata; it is not implemented")


@always_inline
def dequantize_smoothquant_int8(
    matrix: SmoothQuantW8A8Matrix,
    out_ptr: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    dequantize_smoothquant_weights(matrix, out_ptr, output_elements)


@always_inline
def quantized_block_count(
    num_elements: Int, block_size: Int, format_name: String
) raises -> Int:
    if num_elements <= 0:
        raise Error(format_name + ": element count must be positive")
    if block_size <= 0 or num_elements % block_size != 0:
        raise Error(format_name + ": element count must contain complete quantization blocks")
    return num_elements // block_size


@always_inline
def dequantize_compressed_tensor(
    format: CompressedFormatType,
    data: Pointer[UInt8, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_elements: Int
) raises:
    """
    ᚲᛟᛗᛈᚱᛖᛋᛋᛖᛞ·ᚷᚨᛏᛖᚹᚨᚤ — The Gateway of Universal Dequantization (dequantize_compressed_tensor)
    ════════════════════════════════════════════════════════════════════════════════════════════════════
    Dispatches only formats whose byte layout is implemented. External formats
    that require tensor-specific metadata fail before touching the output buffer.
    """
    if num_elements <= 0:
        raise Error("dequantize_compressed_tensor: element count must be positive")
    if Int(data) <= 1 or Int(out_ptr) <= 1:
        raise Error("dequantize_compressed_tensor: invalid input or output storage")
    if format.value == CompressedFormatType.Q2_K:
        var blocks = quantized_block_count(num_elements, 256, "Q2_K")
        dequantize_q2_k_block(data, out_ptr, blocks)
    elif (
        format.value == CompressedFormatType.Q3_K_S
        or format.value == CompressedFormatType.Q3_K_M
        or format.value == CompressedFormatType.Q3_K_L
    ):
        var blocks = quantized_block_count(num_elements, 256, "Q3_K")
        dequantize_q3_k_m(data, out_ptr, blocks)
    elif (
        format.value == CompressedFormatType.Q5_K_S
        or format.value == CompressedFormatType.Q5_K_M
    ):
        var blocks = quantized_block_count(num_elements, 256, "Q5_K")
        dequantize_q5_k_m(data, out_ptr, blocks)
    elif format.value == CompressedFormatType.Q4_0:
        var blocks = quantized_block_count(num_elements, 32, "Q4_0")
        var block_ptr = data.unsafe_bitcast[BlockQ4_0]()
        dequantize_q4_0(block_ptr, out_ptr, blocks)
    elif format.value == CompressedFormatType.Q4_1:
        var blocks = quantized_block_count(num_elements, 32, "Q4_1")
        var block_ptr = data.unsafe_bitcast[BlockQ4_1]()
        dequantize_q4_1(block_ptr, out_ptr, blocks)
    elif format.value == CompressedFormatType.Q5_0:
        var blocks = quantized_block_count(num_elements, 32, "Q5_0")
        var block_ptr = data.unsafe_bitcast[BlockQ5_0]()
        dequantize_q5_0(block_ptr, out_ptr, blocks)
    elif format.value == CompressedFormatType.Q5_1:
        var blocks = quantized_block_count(num_elements, 32, "Q5_1")
        var block_ptr = data.unsafe_bitcast[BlockQ5_1]()
        dequantize_q5_1(block_ptr, out_ptr, blocks)
    elif format.value == CompressedFormatType.Q6_K:
        var blocks = quantized_block_count(num_elements, 256, "Q6_K")
        dequantize_q6_k_block(data, out_ptr, blocks)
    elif format.value == CompressedFormatType.Q8_0:
        var blocks = quantized_block_count(num_elements, 32, "Q8_0")
        var block_ptr = data.unsafe_bitcast[BlockQ8_0]()
        dequantize_q8_0(block_ptr, out_ptr, blocks)
    elif format.value == CompressedFormatType.Q8_1:
        var blocks = quantized_block_count(num_elements, 32, "Q8_1")
        dequantize_q8_1(data, out_ptr, blocks)
    elif format.value == CompressedFormatType.FP8_E4M3:
        dequantize_fp8_e4m3(data, out_ptr, num_elements)
    elif format.value == CompressedFormatType.FP8_E5M2:
        dequantize_fp8_e5m2(data, out_ptr, num_elements)
    elif format.value == CompressedFormatType.GPTQ_4BIT:
        dequantize_gptq_4bit(data, out_ptr, num_elements)
    elif format.value == CompressedFormatType.GPTQ_8BIT:
        dequantize_gptq_8bit(data, out_ptr, num_elements)
    elif format.value == CompressedFormatType.AWQ_4BIT:
        dequantize_awq_4bit(data, out_ptr, num_elements)
    elif format.value == CompressedFormatType.EXL2_VARBIT:
        dequantize_exl2(data, out_ptr, num_elements)
    elif format.value == CompressedFormatType.HQQ:
        dequantize_hqq(data, out_ptr, num_elements)
    elif format.value == CompressedFormatType.SMOOTHQUANT_INT8:
        dequantize_smoothquant_int8(data, out_ptr, num_elements)
    elif format.value == CompressedFormatType.IQ2_XXS:
        var blocks = quantized_block_count(num_elements, 256, "IQ2_XXS")
        dequantize_iq2_xxs_blocks(
            data, blocks * 66, out_ptr, num_elements
        )
    elif format.value == CompressedFormatType.IQ1_S:
        var blocks = quantized_block_count(num_elements, 256, "IQ1_S")
        dequantize_iq1_s_blocks(data, blocks * 50, out_ptr, num_elements)
    elif format.value == CompressedFormatType.TERNARY_155BIT:
        raise Error("extreme quantization layout is not implemented")
    elif format.value == CompressedFormatType.Q4_K_M or format.value == CompressedFormatType.Q4_K_S:
        var blocks = quantized_block_count(num_elements, 256, "Q4_K")
        dequantize_q4_k_m(data, out_ptr, blocks)
    else:
        raise Error("dequantize_compressed_tensor: unsupported or unrecognized quantization format discriminant")


def gemm_q4_0(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols <= 0:
        raise Error("gemm_q4_0: matrix dimensions must be positive")
    if A.cols != B.cols:
        raise Error("gemm_q4_0: inner matrix dimension mismatch")
    if C.rows != A.rows or C.cols != B.rows:
        raise Error("gemm_q4_0: output matrix shape mismatch")

    var rows = A.rows
    var shared_dim = A.cols
    var output_dim = B.rows
    var blocks_per_row = shared_dim // 32
    var src_bytes = B.data.unsafe_bitcast[Byte]()

    for row in range(rows):
        var row_a_ptr = A.data.unsafe_offset(row * shared_dim)
        for output_index in range(output_dim):
            var sum: Scalar[f32] = 0.0
            var row_byte_offset = (output_index * blocks_per_row) * 18
            for b in range(blocks_per_row):
                var blk_ptr = src_bytes.unsafe_offset(row_byte_offset + b * 18)
                var scale = blk_ptr.unsafe_bitcast[Scalar[f16]]().unsafe_load().cast[f32]()

                var col_idx = b * 32
                var a_vec_lo = row_a_ptr.unsafe_load[width=16](col_idx).cast[f32]()
                var a_vec_hi = row_a_ptr.unsafe_load[width=16](col_idx + 16).cast[f32]()

                for i in range(16):
                    var nibbles = UInt8(blk_ptr.unsafe_load(2 + i))
                    var q0 = Scalar[f32](Int(nibbles & 0x0F) - 8) * scale
                    var q1 = Scalar[f32](Int((nibbles >> 4) & 0x0F) - 8) * scale
                    sum += a_vec_lo[i] * q0 + a_vec_hi[i] * q1

            C.set(row, output_index, sum.cast[f16]())


def gemm_q4_1(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols <= 0:
        raise Error("gemm_q4_1: matrix dimensions must be positive")
    if A.cols != B.cols:
        raise Error("gemm_q4_1: inner matrix dimension mismatch")
    if C.rows != A.rows or C.cols != B.rows:
        raise Error("gemm_q4_1: output matrix shape mismatch")

    var rows = A.rows
    var shared_dim = A.cols
    var output_dim = B.rows
    var blocks_per_row = shared_dim // 32
    var block_base = B.data.unsafe_bitcast[BlockQ4_1]()

    print("gemm_f16: A.rows:", A.rows, "A.cols:", A.cols, "B.rows:", B.rows, "B.cols:", B.cols, "B.is_quant:", B.is_quantized)
    for row in range(rows):
        for output_index in range(output_dim):
            var sum: Scalar[f32] = 0.0
            var row_block_offset = output_index * blocks_per_row
            for b in range(blocks_per_row):
                var blk = block_base.unsafe_offset(row_block_offset + b)[]
                var scale = blk.scale
                var min_val = blk.min_val
                var qs = blk.qs
                var lower_4 = qs & 0x0F
                var upper_4 = (qs >> 4) & 0x0F

                var col_idx = b * 32
                var a_vec_lower = A.data.unsafe_load[width=16](
                    row * shared_dim + col_idx
                ).cast[f32]()
                var a_vec_upper = A.data.unsafe_load[width=16](
                    row * shared_dim + col_idx + 16
                ).cast[f32]()

                var w_lower = (lower_4.cast[f16]() * scale + min_val).cast[
                    f32
                ]()
                var w_upper = (upper_4.cast[f16]() * scale + min_val).cast[
                    f32
                ]()

                sum += (a_vec_lower * w_lower).reduce_add()
                sum += (a_vec_upper * w_upper).reduce_add()

            C.set(row, output_index, sum.cast[f16]())


def gemm_q5_0(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols <= 0:
        raise Error("gemm_q5_0: matrix dimensions must be positive")
    var is_transposed = (B.rows == C.cols)
    if is_transposed:
        if A.cols != B.cols or C.rows != A.rows or C.cols != B.rows:
            raise Error("gemm_q5_0: shape mismatch (transposed): A=" + String(A.rows) + "x" + String(A.cols) + " B=" + String(B.rows) + "x" + String(B.cols) + " C=" + String(C.rows) + "x" + String(C.cols))
    else:
        if A.cols != B.rows or C.rows != A.rows or C.cols != B.cols:
            raise Error("gemm_q5_0: shape mismatch (non-transposed): A=" + String(A.rows) + "x" + String(A.cols) + " B=" + String(B.rows) + "x" + String(B.cols) + " C=" + String(C.rows) + "x" + String(C.cols))

    var rows = A.rows
    var shared_dim = A.cols
    var output_dim = C.cols
    var blocks_per_row = shared_dim // 32

    var bytes_ptr = B.data.unsafe_bitcast[UInt8]()

    for row in range(rows):
        for output_index in range(output_dim):
            var sum: Float32 = 0.0
            var row_byte_offset = output_index * blocks_per_row * 22
            for b in range(blocks_per_row):
                var p = row_byte_offset + b * 22
                var scale_ptr = bytes_ptr.unsafe_offset(p).unsafe_bitcast[Scalar[f16]]()
                var scale = scale_ptr.unsafe_load().cast[DType.float32]()
                
                var qh0 = Int(bytes_ptr.unsafe_load(p + 2))
                var qh1 = Int(bytes_ptr.unsafe_load(p + 3))
                var qh2 = Int(bytes_ptr.unsafe_load(p + 4))
                var qh3 = Int(bytes_ptr.unsafe_load(p + 5))
                var qh_val = qh0 | (qh1 << 8) | (qh2 << 16) | (qh3 << 24)

                var col_idx = b * 32
                for i in range(16):
                    var q_byte = Int(bytes_ptr.unsafe_load(p + 6 + i))
                    var h_bit_lo = (qh_val >> i) & 1
                    var h_bit_hi = (qh_val >> (i + 16)) & 1

                    var w_lo = scale * Float32(((q_byte & 15) | (h_bit_lo << 4)) - 16)
                    var w_hi = scale * Float32((((q_byte >> 4) & 15) | (h_bit_hi << 4)) - 16)

                    var a_lo = A.data.unsafe_load(row * shared_dim + col_idx + i).cast[f32]()
                    var a_hi = A.data.unsafe_load(row * shared_dim + col_idx + 16 + i).cast[f32]()

                    sum += a_lo * w_lo + a_hi * w_hi

            C.set(row, output_index, Scalar[f16](sum))


def gemm_q5_1(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols <= 0:
        raise Error("gemm_q5_1: matrix dimensions must be positive")
    if A.cols != B.cols:
        raise Error("gemm_q5_1: inner matrix dimension mismatch")
    if C.rows != A.rows or C.cols != B.rows:
        raise Error("gemm_q5_1: output matrix shape mismatch")

    var rows = A.rows
    var shared_dim = A.cols
    var output_dim = B.rows
    var blocks_per_row = shared_dim // 32
    var block_base = B.data.unsafe_bitcast[BlockQ5_1]()

    for row in range(rows):
        for output_index in range(output_dim):
            var sum: Scalar[f32] = 0.0
            var row_block_offset = output_index * blocks_per_row
            for b in range(blocks_per_row):
                var blk = block_base.unsafe_offset(row_block_offset + b)[]
                var scale = blk.scale
                var min_val = blk.min_val
                var qh = blk.qh
                var qs = blk.qs

                var col_idx = b * 32
                for i in range(16):
                    var qh_byte_lo = qh[i // 8]
                    var h_bit_lo = Scalar[f16](
                        (qh_byte_lo >> Scalar[DType.uint8](i % 8)) & 1
                    )
                    var qh_byte_hi = qh[(i + 16) // 8]
                    var h_bit_hi = Scalar[f16](
                        (qh_byte_hi >> Scalar[DType.uint8]((i + 16) % 8)) & 1
                    )

                    var a_lo = A.data.unsafe_load(
                        row * shared_dim + col_idx + i
                    ).cast[f32]()
                    var a_hi = A.data.unsafe_load(
                        row * shared_dim + col_idx + 16 + i
                    ).cast[f32]()

                    var w_lo = (
                        (Scalar[f16](qs[i] & 0x0F) + h_bit_lo * 16.0) * scale
                        + min_val
                    ).cast[f32]()
                    var w_hi = (
                        (Scalar[f16]((qs[i] >> 4) & 0x0F) + h_bit_hi * 16.0)
                        * scale
                        + min_val
                    ).cast[f32]()

                    sum += a_lo * w_lo + a_hi * w_hi

            C.set(row, output_index, sum.cast[f16]())


def gemm_q8_0(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols != A.cols or A.cols % 32 != 0:
        raise Error("gemm_q8_0: invalid shape or incomplete quantization block")
    if C.rows != A.rows or C.cols != B.rows:
        raise Error("gemm_q8_0: output matrix shape mismatch")
    if Int(A.data) <= 1 or Int(B.data) <= 1 or Int(C.data) <= 1:
        raise Error("gemm_q8_0: invalid storage")
    var weights = B.data.unsafe_bitcast[UInt8]()
    var blocks_per_row = A.cols // 32
    for row in range(A.rows):
        for output in range(B.rows):
            var total: Float32 = 0
            var row_base = output * blocks_per_row * 34
            for block in range(blocks_per_row):
                var p = row_base + block * 34
                var scale = weights.unsafe_offset(p).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
                for lane in range(32):
                    var q = weights.unsafe_load(p + 2 + lane).cast[DType.int8]()
                    total += A.data.unsafe_load(row * A.cols + block * 32 + lane).cast[f32]() * Float32(q) * scale
            C.data.unsafe_store(row * C.cols + output, total.cast[f16]())


def gemm_q8_1(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols != A.cols or A.cols % 32 != 0:
        raise Error("gemm_q8_1: invalid shape or incomplete quantization block")
    if C.rows != A.rows or C.cols != B.rows:
        raise Error("gemm_q8_1: output matrix shape mismatch")
    if Int(A.data) <= 1 or Int(B.data) <= 1 or Int(C.data) <= 1:
        raise Error("gemm_q8_1: invalid storage")
    var weights = B.data.unsafe_bitcast[UInt8]()
    var blocks_per_row = A.cols // 32
    for row in range(A.rows):
        for output in range(B.rows):
            var total: Float32 = 0
            var row_base = output * blocks_per_row * 40
            for block in range(blocks_per_row):
                var p = row_base + block * 40
                var scale = weights.unsafe_offset(p).unsafe_bitcast[Float32]().unsafe_load()
                for lane in range(32):
                    var q = weights.unsafe_load(p + 8 + lane).cast[DType.int8]()
                    total += A.data.unsafe_load(row * A.cols + block * 32 + lane).cast[f32]() * Float32(q) * scale
            C.data.unsafe_store(row * C.cols + output, total.cast[f16]())


def gemm_fp8_e4m3(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols <= 0:
        raise Error("gemm_fp8_e4m3: matrix dimensions must be positive")
    if A.cols != B.cols:
        raise Error("gemm_fp8_e4m3: inner matrix dimension mismatch")
    if C.rows != A.rows or C.cols != B.rows:
        raise Error("gemm_fp8_e4m3: output matrix shape mismatch")

    var rows = A.rows
    var shared_dim = A.cols
    var output_dim = B.rows

    for row in range(rows):
        for output_index in range(output_dim):
            var sum: Scalar[f32] = 0.0
            var row_w_offset = output_index * shared_dim
            for k in range(shared_dim):
                var a_val = A.data.unsafe_load(row * shared_dim + k).cast[f32]()
                var b_byte = B.data.unsafe_bitcast[UInt8]().unsafe_load(
                    row_w_offset + k
                )
                var sign_bit = Int((b_byte >> 7) & 1)
                var s: Scalar[f16] = 1.0 if sign_bit == 0 else -1.0
                var exp = Int((b_byte >> 3) & 0x0F)
                var mant = Scalar[f16](b_byte & 0x07)
                var w_f16: Scalar[f16]
                if exp == 0:
                    w_f16 = s * Scalar[f16](0.015625) * (mant / 8.0)
                elif exp == 15 and (b_byte & 0x07) == 7:
                    w_f16 = 0.0
                else:
                    var pow2 = Scalar[f16](1.0)
                    var shift = exp - 7
                    if shift >= 0:
                        for _ in range(shift):
                            pow2 *= 2.0
                    else:
                        for _ in range(-shift):
                            pow2 *= 0.5
                    w_f16 = s * pow2 * (1.0 + mant / 8.0)
                sum += a_val * w_f16.cast[f32]()
            C.set(row, output_index, sum.cast[f16]())


def gemm_fp8_e5m2(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols <= 0:
        raise Error("gemm_fp8_e5m2: matrix dimensions must be positive")
    if A.cols != B.cols:
        raise Error("gemm_fp8_e5m2: inner matrix dimension mismatch")
    if C.rows != A.rows or C.cols != B.rows:
        raise Error("gemm_fp8_e5m2: output matrix shape mismatch")

    var rows = A.rows
    var shared_dim = A.cols
    var output_dim = B.rows

    for row in range(rows):
        for output_index in range(output_dim):
            var sum: Scalar[f32] = 0.0
            var row_w_offset = output_index * shared_dim
            for k in range(shared_dim):
                var a_val = A.data.unsafe_load(row * shared_dim + k).cast[f32]()
                var b_byte = B.data.unsafe_bitcast[UInt8]().unsafe_load(
                    row_w_offset + k
                )
                var sign_bit = Int((b_byte >> 7) & 1)
                var s: Scalar[f16] = 1.0 if sign_bit == 0 else -1.0
                var exp = Int((b_byte >> 2) & 0x1F)
                var mant = Scalar[f16](b_byte & 0x03)
                var w_f16: Scalar[f16]
                if exp == 0:
                    w_f16 = s * Scalar[f16](0.00006103515625) * (mant / 4.0)
                elif exp == 31:
                    w_f16 = 0.0
                else:
                    var pow2 = Scalar[f16](1.0)
                    var shift = exp - 15
                    if shift >= 0:
                        for _ in range(shift):
                            pow2 *= 2.0
                    else:
                        for _ in range(-shift):
                            pow2 *= 0.5
                    w_f16 = s * pow2 * (1.0 + mant / 4.0)
                sum += a_val * w_f16.cast[f32]()
            C.set(row, output_index, sum.cast[f16]())


def gemm_ggml_k(
    A: RuneTensor[f16],
    B: RuneTensor[f16],
    mut C: RuneTensor[f16],
    ggml_type: Int,
    format_name: String,
) raises:
    """CPU F32 accumulation over canonical GGUF K-quant packed bytes, B[N,K]."""
    if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols != A.cols or A.cols % 256 != 0:
        raise Error(format_name + ": invalid shape or incomplete quantization block")
    if C.rows != A.rows or C.cols != B.rows:
        raise Error(format_name + ": output matrix shape mismatch")
    if Int(A.data) <= 1 or Int(B.data) <= 1 or Int(C.data) <= 1:
        raise Error(format_name + ": invalid storage")
    if ggml_type < 10 or ggml_type > 14:
        raise Error(format_name + ": unsupported GGML tensor type")
    var weights = B.data.unsafe_bitcast[UInt8]()
    for row in range(A.rows):
        for output in range(B.rows):
            var total: Float32 = 0
            for col in range(A.cols):
                total += A.data.unsafe_load(row * A.cols + col).cast[f32]() * packed_value(weights, 0, ggml_type, output * A.cols + col)
            C.data.unsafe_store(row * C.cols + output, total.cast[f16]())


def gemm_q2_k(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    gemm_ggml_k(A, B, C, 10, "gemm_q2_k")


def gemm_q6_k(A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]) raises:
    gemm_ggml_k(A, B, C, 14, "gemm_q6_k")


def gemm_q3_k_m(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    gemm_ggml_k(A, B, C, 11, "gemm_q3_k_m")


def gemm_q3_k_s(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    gemm_q3_k_m(A, B, C)


def gemm_q3_k_l(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    gemm_q3_k_m(A, B, C)


def gemm_q5_k_m(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    gemm_ggml_k(A, B, C, 13, "gemm_q5_k_m")


def gemm_q5_k_s(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    gemm_q5_k_m(A, B, C)


def gemm_q4_k_m(A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]) raises:
    gemm_ggml_k(A, B, C, 12, "gemm_q4_k_m")

def gemm_gptq_4bit(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    _ = A
    _ = B
    _ = C
    raise Error("GPTQ 4-bit GEMM requires format-specific scales, zero points, groups, and packing metadata; it is not implemented")


def gemm_gptq_4bit(
    input: Pointer[Float16, MutUntrackedOrigin],
    input_elements: Int,
    input_rows: Int,
    matrix: GPTQ4BitMatrix,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    """Run A[M,K] x validated AutoGPTQ W[N,K] -> C[M,N]."""
    gemm_gptq_4bit_matrix(
        input, input_elements, input_rows, matrix, output, output_elements
    )

def gemm_gptq_8bit(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    _ = A
    _ = B
    _ = C
    raise Error("GPTQ 8-bit GEMM requires format-specific scales, zero points, groups, and packing metadata; it is not implemented")


def gemm_gptq_8bit(
    input: Pointer[Float16, MutUntrackedOrigin],
    input_elements: Int,
    input_rows: Int,
    matrix: GPTQ8BitMatrix,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    gemm_gptq_8bit_matrix(
        input, input_elements, input_rows, matrix, output, output_elements
    )

def gemm_awq_4bit(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    _ = A
    _ = B
    _ = C
    raise Error("AWQ GEMM requires format-specific scales, zero points, groups, and packing metadata; it is not implemented")


def gemm_awq_4bit(
    input: Pointer[Float16, MutUntrackedOrigin],
    input_elements: Int,
    input_rows: Int,
    matrix: AWQ4BitMatrix,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    gemm_awq_4bit_matrix(
        input, input_elements, input_rows, matrix, output, output_elements
    )

def gemm_exl2(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    _ = A
    _ = B
    _ = C
    raise Error("EXL2 GEMM requires its variable-bit layout and tensor metadata; it is not implemented")


def gemm_exl2(
    input: Pointer[Float16, MutUntrackedOrigin],
    input_elements: Int,
    input_rows: Int,
    matrix: EXL2Matrix,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    gemm_exl2_matrix(
        input, input_elements, input_rows, matrix, output, output_elements
    )

def gemm_hqq(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    _ = A
    _ = B
    _ = C
    raise Error("HQQ GEMM requires tensor-specific scale, zero, grouping, and packing metadata; it is not implemented")


def gemm_hqq(
    input: Pointer[Float16, MutUntrackedOrigin],
    input_elements: Int,
    input_rows: Int,
    matrix: HQQ4BitAxis1Matrix,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    gemm_hqq_4bit_axis1(
        input, input_elements, input_rows, matrix, output, output_elements
    )

def gemm_smoothquant_int8(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    _ = A
    _ = B
    _ = C
    raise Error("SmoothQuant GEMM requires activation and weight scales with channel metadata; it is not implemented")


def gemm_smoothquant_int8(
    input: Pointer[Float16, MutUntrackedOrigin],
    input_elements: Int,
    input_rows: Int,
    matrix: SmoothQuantW8A8Matrix,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    gemm_smoothquant_w8a8(
        input, input_elements, input_rows, matrix, output, output_elements
    )

def gemm_iq1_s(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    if A.cols != B.cols or C.rows != A.rows or C.cols != B.rows:
        raise Error("gemm_iq1_s: matrix shape mismatch")
    if A.cols <= 0 or A.cols % 256 != 0:
        raise Error("gemm_iq1_s: inner dimension must use complete 256-value blocks")
    var weight_bytes = B.rows * (B.cols // 256) * 50
    gemm_iq1_s_blocks(
        A.data.unsafe_bitcast[Float16](),
        A.rows * A.cols,
        A.rows,
        B.data.unsafe_bitcast[UInt8](),
        weight_bytes,
        A.cols,
        B.rows,
        C.data.unsafe_bitcast[Float16](),
        C.rows * C.cols,
    )

def gemm_iq2_xxs(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    if A.cols != B.cols or C.rows != A.rows or C.cols != B.rows:
        raise Error("gemm_iq2_xxs: matrix shape mismatch")
    if A.cols <= 0 or A.cols % 256 != 0:
        raise Error("gemm_iq2_xxs: inner dimension must use complete 256-value blocks")
    var weight_bytes = B.rows * (B.cols // 256) * 66
    gemm_iq2_xxs_blocks(
        A.data.unsafe_bitcast[Float16](),
        A.rows * A.cols,
        A.rows,
        B.data.unsafe_bitcast[UInt8](),
        weight_bytes,
        A.cols,
        B.rows,
        C.data.unsafe_bitcast[Float16](),
        C.rows * C.cols,
    )

def gemm_ternary_158(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    _ = A
    _ = B
    _ = C
    raise Error("Ternary GEMM requires a specified on-disk format, scale contract, and independent oracle; it is not implemented")

def gemm_f16(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    """
    Host Mojo SIMD/scalar-tail F16 matrix multiplication with F32 accumulation.
    This function does not execute CUDA, Tensor Core, or MMA instructions.
    """
    if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols <= 0:
        raise Error("gemm_f16: matrix dimensions must be positive")
    if A.cols != B.cols:
        raise Error("gemm_f16: inner matrix dimension mismatch")
    if C.rows != A.rows or C.cols != B.rows:
        raise Error("gemm_f16: output matrix shape mismatch")

    if B.is_quantized:
        if B.quant_format.value == CompressedFormatType.Q4_0:
            gemm_q4_0(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.Q4_1:
            gemm_q4_1(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.Q5_0:
            gemm_q5_0(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.Q5_1:
            gemm_q5_1(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.Q8_0:
            gemm_q8_0(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.Q8_1:
            gemm_q8_1(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.FP8_E4M3:
            gemm_fp8_e4m3(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.FP8_E5M2:
            gemm_fp8_e5m2(A, B, C)
            return
        elif (
            B.quant_format.value == CompressedFormatType.Q3_K_S
            or B.quant_format.value == CompressedFormatType.Q3_K_M
            or B.quant_format.value == CompressedFormatType.Q3_K_L
        ):
            gemm_q3_k_m(A, B, C)
            return
        elif (
            B.quant_format.value == CompressedFormatType.Q5_K_S
            or B.quant_format.value == CompressedFormatType.Q5_K_M
        ):
            gemm_q5_k_m(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.Q2_K:
            gemm_q2_k(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.Q6_K:
            gemm_q6_k(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.GPTQ_4BIT:
            gemm_gptq_4bit(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.GPTQ_8BIT:
            gemm_gptq_8bit(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.AWQ_4BIT:
            gemm_awq_4bit(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.EXL2_VARBIT:
            gemm_exl2(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.HQQ:
            gemm_hqq(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.SMOOTHQUANT_INT8:
            gemm_smoothquant_int8(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.IQ1_S:
            gemm_iq1_s(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.IQ2_XXS:
            gemm_iq2_xxs(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.TERNARY_155BIT:
            gemm_ternary_158(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.Q4_K_M or B.quant_format.value == CompressedFormatType.Q4_K_S:
            gemm_q4_k_m(A, B, C)
            return
        else:
            raise Error("gemm_f16: unrecognized or unsupported quantization format discriminant")

    var rows = A.rows
    var shared_dim = A.cols
    var output_dim = B.rows
    var simd_end = (shared_dim // simd_w_f16) * simd_w_f16

    for row in range(rows):
        for output_index in range(output_dim):
            var sum: Scalar[f32] = 0.0
            for inner in range(0, simd_end, simd_w_f16):
                var input_values = A.data.unsafe_load[width=simd_w_f16](
                    row * shared_dim + inner
                ).cast[f32]()
                var weight_values = B.data.unsafe_load[width=simd_w_f16](
                    output_index * shared_dim + inner
                ).cast[f32]()
                sum += (input_values * weight_values).reduce_add()
            for inner in range(simd_end, shared_dim):
                sum += (
                    A.data.unsafe_load(row * shared_dim + inner).cast[f32]()
                    * B.data.unsafe_load(
                        output_index * shared_dim + inner
                    ).cast[f32]()
                )
            C.set(row, output_index, sum.cast[f16]())


def flash_attention_gqa(
    query: RuneTensor[f16],
    keys: RuneTensor[f16],
    values: RuneTensor[f16],
    mut output: RuneTensor[f16],
    sequence_length: Int,
    head_dim: Int,
    query_head_count: Int,
    kv_head_count: Int,
):
    """Incremental causal attention with grouped-query head mapping."""
    if sequence_length <= 0 or query.rows != 1 or output.rows != 1:
        return
    if query_head_count <= 0 or kv_head_count <= 0 or head_dim <= 0:
        return
    if query_head_count % kv_head_count != 0:
        return
    var query_heads_per_kv = query_head_count // kv_head_count
    var scale = (1.0 / (Float64(head_dim) ** 0.5)).cast[f32]()

    var acc = alloc(Layout[Scalar[f32]](count=head_dim)).unsafe_leak()
    for query_head in range(query_head_count):
        var kv_head = query_head // query_heads_per_kv
        var query_base = query_head * head_dim
        var output_base = query_head * head_dim
        for dimension in range(head_dim):
            acc.unsafe_store(dimension, 0.0)

        var running_max: Scalar[f32] = -1e20
        var running_sum: Scalar[f32] = 0.0
        for position in range(sequence_length):
            var key_base = position * keys.cols + kv_head * head_dim
            var value_base = position * values.cols + kv_head * head_dim
            var score: Scalar[f32] = 0.0
            for dimension in range(head_dim):
                score += (
                    query.data.unsafe_load(query_base + dimension).cast[f32]()
                    * keys.data.unsafe_load(key_base + dimension).cast[f32]()
                )
            score *= scale
            var next_max = max(running_max, score)
            var previous_scale = exp(running_max - next_max)
            var probability = exp(score - next_max)
            var next_sum = running_sum * previous_scale + probability

            for dimension in range(head_dim):
                var previous = acc.unsafe_load(dimension)
                var value = values.data.unsafe_load(
                    value_base + dimension
                ).cast[f32]()
                acc.unsafe_store(dimension, previous * previous_scale + probability * value)
            running_max = next_max
            running_sum = next_sum

        for dimension in range(head_dim):
            var accumulated = acc.unsafe_load(dimension)
            output.data.unsafe_store(
                output_base + dimension,
                (accumulated / running_sum).cast[f16](),
            )
    acc.unsafe_free()


def flash_attention_2(
    Q: RuneTensor[f16],
    K: RuneTensor[f16],
    V: RuneTensor[f16],
    mut Out: RuneTensor[f16],
    seq_len: Int,
    head_dim: Int,
) raises:
    """
    The Gaze of Odin (Flash Attention-2):
    Fuses score calculation, softmax, and value aggregation into a single, piercing kernel pass.
    Sees all tokens across the sequence without materializing the vast attention matrix.
    Includes SIMD + scalar-tail loops for head_dim alignment safety.
    """
    if seq_len <= 0 or head_dim <= 0:
        raise Error(
            "flash_attention_2: sequence length and head dimension must be"
            " positive"
        )
    if Q.cols <= 0 or Q.cols % head_dim != 0:
        raise Error(
            "flash_attention_2: Q.cols must be a positive multiple of head_dim"
        )
    if K.cols != Q.cols or V.cols != Q.cols or Out.cols != Q.cols:
        raise Error("flash_attention_2: tensor column dimension mismatch")
    if (
        Q.rows < seq_len
        or K.rows < seq_len
        or V.rows < seq_len
        or Out.rows < seq_len
    ):
        raise Error(
            "flash_attention_2: tensor row dimension smaller than sequence"
            " length"
        )

    var scale = (1.0 / (Float64(head_dim) ** 0.5)).cast[f32]()
    var simd_end = (head_dim // simd_w_f32) * simd_w_f32

    # Block dimensions (SRAM tiling simulation)
    var Br = 32
    var Bc = 32

    var num_heads = Q.cols // head_dim
    var num_kv_heads = max(1, K.cols // head_dim)
    var group_size = max(1, num_heads // num_kv_heads)

    for h in range(num_heads):
        var kv_head = h // group_size
        for i_start in range(0, seq_len, Br):
            for ii in range(Br):
                var i = i_start + ii
                if i >= seq_len:
                    break

                var m_i: Scalar[f32] = -1e20
                var l_i: Scalar[f32] = 0.0

                # Initialize Out row to 0 for this head
                for k in range(0, simd_end, simd_w_f32):
                    Out.data.unsafe_store[width=simd_w_f32](
                        i * Q.cols + h * head_dim + k,
                        SIMD[f16, simd_w_f32](0.0),
                    )
                for k in range(simd_end, head_dim):
                    Out.data.unsafe_store(i * Q.cols + h * head_dim + k, 0.0)

                for j_start in range(0, seq_len, Bc):
                    for jj in range(Bc):
                        var j = j_start + jj
                        if j >= seq_len:
                            break

                        # 1. Compute QK^T / sqrt(d)
                        var S_ij: Scalar[f32] = 0.0
                        for k in range(0, simd_end, simd_w_f32):
                            var q_vec = Q.data.unsafe_load[width=simd_w_f32](
                                i * Q.cols + h * head_dim + k
                            ).cast[f32]()
                            var k_vec = K.data.unsafe_load[width=simd_w_f32](
                                j * K.cols + kv_head * head_dim + k
                            ).cast[f32]()
                            S_ij += (q_vec * k_vec).reduce_add()
                        for k in range(simd_end, head_dim):
                            var q_val = Q.data.unsafe_load(
                                i * Q.cols + h * head_dim + k
                            ).cast[f32]()
                            var k_val = K.data.unsafe_load(
                                j * K.cols + kv_head * head_dim + k
                            ).cast[f32]()
                            S_ij += q_val * k_val

                        var score = S_ij * scale

                        # 2. Online Softmax (fused)
                        var m_i_new = max(m_i, score)
                        var P_ij = exp(score - m_i_new)
                        var l_i_new = l_i * exp(m_i - m_i_new) + P_ij

                        # 3. Multiply by V and accumulate
                        for k in range(0, simd_end, simd_w_f32):
                            var v_vec = V.data.unsafe_load[width=simd_w_f32](
                                j * V.cols + kv_head * head_dim + k
                            ).cast[f32]()
                            var out_old = Out.data.unsafe_load[
                                width=simd_w_f32
                            ](i * Out.cols + h * head_dim + k).cast[f32]()
                            var out_new = (
                                out_old * exp(m_i - m_i_new) + P_ij * v_vec
                            )
                            Out.data.unsafe_store[width=simd_w_f32](
                                i * Out.cols + h * head_dim + k,
                                out_new.cast[f16](),
                            )
                        for k in range(simd_end, head_dim):
                            var v_val = V.data.unsafe_load(
                                j * V.cols + kv_head * head_dim + k
                            ).cast[f32]()
                            var out_old_s = Out.data.unsafe_load(
                                i * Out.cols + h * head_dim + k
                            ).cast[f32]()
                            var out_new_s = (
                                out_old_s * exp(m_i - m_i_new) + P_ij * v_val
                            )
                            Out.data.unsafe_store(
                                i * Out.cols + h * head_dim + k,
                                out_new_s.cast[f16](),
                            )

                        m_i = m_i_new
                        l_i = l_i_new

                # Normalize Out by l_i
                for k in range(0, simd_end, simd_w_f32):
                    var out_val = Out.data.unsafe_load[width=simd_w_f32](
                        i * Out.cols + h * head_dim + k
                    ).cast[f32]()
                    Out.data.unsafe_store[width=simd_w_f32](
                        i * Out.cols + h * head_dim + k,
                        (out_val / l_i).cast[f16](),
                    )
                for k in range(simd_end, head_dim):
                    var out_val_s = Out.data.unsafe_load(
                        i * Out.cols + h * head_dim + k
                    ).cast[f32]()
                    Out.data.unsafe_store(
                        i * Out.cols + h * head_dim + k,
                        (out_val_s / l_i).cast[f16](),
                    )


@always_inline
def silu(mut T: RuneTensor[f16]):
    """Vectorized SiLU (Swish) activation: x * sigmoid(x). The bending of the branch."""
    if T.size <= 0:
        return
    var simd_end = (T.size // simd_w_f16) * simd_w_f16
    for i in range(0, simd_end, simd_w_f16):
        var x = T.data.unsafe_load[width=simd_w_f16](i).cast[f32]()
        var sigmoid = 1.0 / (1.0 + exp(-x))
        T.data.unsafe_store[width=simd_w_f16](i, (x * sigmoid).cast[f16]())
    for i in range(simd_end, T.size):
        var x = T.data.unsafe_load(i).cast[f32]()
        var sigmoid = 1.0 / (1.0 + exp(-x))
        T.data.unsafe_store(i, (x * sigmoid).cast[f16]())


@always_inline
def geglu(mut T: RuneTensor[f16]):
    """Vectorized GeGLU operation. The binding of the gates."""
    if T.size <= 0 or T.size % 2 != 0:
        return
    var half_size = T.size // 2
    var simd_end = (half_size // simd_w_f16) * simd_w_f16

    for i in range(0, simd_end, simd_w_f16):
        var x = T.data.unsafe_load[width=simd_w_f16](i).cast[f32]()
        var y = T.data.unsafe_load[width=simd_w_f16](i + half_size).cast[f32]()

        var y3 = y * y * y
        var inner = 0.79788456 * (y + 0.044715 * y3)

        var exp_pos = exp(inner)
        var exp_neg = exp(-inner)
        var tanh_approx = (exp_pos - exp_neg) / (exp_pos + exp_neg)

        var gelu_y = 0.5 * y * (1.0 + tanh_approx)
        T.data.unsafe_store[width=simd_w_f16](i, (x * gelu_y).cast[f16]())

    for i in range(simd_end, half_size):
        var x = T.data.unsafe_load(i).cast[f32]()
        var y = T.data.unsafe_load(i + half_size).cast[f32]()

        var y3 = y * y * y
        var inner = 0.79788456 * (y + 0.044715 * y3)

        var exp_pos = exp(inner)
        var exp_neg = exp(-inner)
        var tanh_approx = (exp_pos - exp_neg) / (exp_pos + exp_neg)

        var gelu_y = 0.5 * y * (1.0 + tanh_approx)
        T.data.unsafe_store(i, (x * gelu_y).cast[f16]())


def rmsnorm(
    mut T: RuneTensor[f16], weight: RuneTensor[f16], epsilon: Scalar[f32] = 1e-5
) raises:
    """
    RMSNorm: The Cleansing Fire of Muspelheim.
    Normalizes the tensor by its Root Mean Square to stabilize the forward pass,
    then re-scales it using learned weights (The Forged Armor).
    """
    if T.rows <= 0 or T.cols <= 0:
        raise Error("rmsnorm: tensor dimensions must be positive")
    if weight.size < T.cols:
        raise Error("rmsnorm: weight dimension mismatch")
    if epsilon <= 0.0:
        raise Error("rmsnorm: epsilon must be positive")

    var hidden_dim = T.cols
    var simd_end = (hidden_dim // simd_w_f16) * simd_w_f16
    for r in range(T.rows):
        var ss: Scalar[f32] = 0.0
        # Calculate sum of squares
        for c in range(0, simd_end, simd_w_f16):
            var x = T.data.unsafe_load[width=simd_w_f16](
                r * hidden_dim + c
            ).cast[f32]()
            ss += (x * x).reduce_add()
        for c in range(simd_end, hidden_dim):
            var x = T.data.unsafe_load(r * hidden_dim + c).cast[f32]()
            ss += x * x

        var inv_rms = 1.0 / sqrt(ss / Float32(hidden_dim) + epsilon)

        # Normalize and apply weight
        for c in range(0, simd_end, simd_w_f16):
            var x = T.data.unsafe_load[width=simd_w_f16](r * hidden_dim + c).cast[f32]()
            var w = weight.data.unsafe_load[width=simd_w_f16](c).cast[f32]()
            var normalized = x * inv_rms
            T.data.unsafe_store[width=simd_w_f16](
                r * hidden_dim + c, (normalized * w).cast[f16]()
            )
        for c in range(simd_end, hidden_dim):
            var x = T.data.unsafe_load(r * hidden_dim + c).cast[f32]()
            var w = weight.data.unsafe_load(c).cast[f32]()
            var normalized = x * inv_rms
            T.data.unsafe_store(r * hidden_dim + c, (normalized * w).cast[f16]())


def apply_rope(
    mut Q: RuneTensor[f16],
    mut K: RuneTensor[f16],
    start_pos: Int,
    head_dim: Int,
    theta: Scalar[f32] = 10000.0,
    neox: Bool = False,
) raises:
    """
    RoPE (Rotary Position Embeddings): The Threads of Urd.
    Rotates the queries and keys in the complex plane to weave positional destiny into the tokens.
    """
    if start_pos < 0:
        raise Error("apply_rope: start_pos cannot be negative")
    if head_dim <= 0 or head_dim % 2 != 0:
        raise Error("apply_rope: head_dim must be positive and even")
    if Q.cols % head_dim != 0 or K.cols % head_dim != 0:
        raise Error("apply_rope: tensor columns must be a multiple of head_dim")
    if Q.rows <= 0 or K.rows <= 0:
        raise Error("apply_rope: tensor dimensions must be positive")

    var num_heads_q = Q.cols // head_dim
    var num_heads_k = K.cols // head_dim
    var half_dim = head_dim // 2

    for r in range(Q.rows):
        var pos = start_pos + r
        for i in range(half_dim):
            var freq = 1.0 / (theta ** (Float32(2 * i) / Float32(head_dim)))
            var val = Float32(pos) * freq
            var fcr = cos(val).cast[f16]()
            var fci = sin(val).cast[f16]()

            for h in range(num_heads_q):
                var head_base = r * Q.cols + h * head_dim
                var idx0 = head_base + (i if neox else 2 * i)
                var idx1 = idx0 + (half_dim if neox else 1)
                var q0 = Q.data.unsafe_load(idx0)
                var q1 = Q.data.unsafe_load(idx1)
                Q.data.unsafe_store(idx0, q0 * fcr - q1 * fci)
                Q.data.unsafe_store(idx1, q0 * fci + q1 * fcr)

            for h in range(num_heads_k):
                var head_base = r * K.cols + h * head_dim
                var idx0 = head_base + (i if neox else 2 * i)
                var idx1 = idx0 + (half_dim if neox else 1)
                var k0 = K.data.unsafe_load(idx0)
                var k1 = K.data.unsafe_load(idx1)
                K.data.unsafe_store(idx0, k0 * fcr - k1 * fci)
                K.data.unsafe_store(idx1, k0 * fci + k1 * fcr)


@always_inline
def cosine_similarity(
    A: RuneTensor[f16], B: RuneTensor[f16]
) raises -> Scalar[f32]:
    """
    SIMD Cosine Similarity Kernel: The Mímisbrunnr Alignment.
    Computes dot product A . B, norm ||A||, and norm ||B|| using simd_w_f16 SIMD lanes.
    Returns (A . B) / max(||A|| * ||B||, 1e-8).
    Includes SIMD tail loop for unaligned vector lengths.
    """
    if A.size != B.size:
        raise Error("cosine_similarity: vector size mismatch")
    if A.size <= 0:
        raise Error("cosine_similarity: vector size must be positive")
    var size = A.size
    var simd_end = (size // simd_w_f16) * simd_w_f16

    var dot_sum: Scalar[f32] = 0.0
    var norm_a_sq: Scalar[f32] = 0.0
    var norm_b_sq: Scalar[f32] = 0.0

    for i in range(0, simd_end, simd_w_f16):
        var a_vec = A.data.unsafe_load[width=simd_w_f16](i).cast[f32]()
        var b_vec = B.data.unsafe_load[width=simd_w_f16](i).cast[f32]()
        dot_sum += (a_vec * b_vec).reduce_add()
        norm_a_sq += (a_vec * a_vec).reduce_add()
        norm_b_sq += (b_vec * b_vec).reduce_add()

    for i in range(simd_end, size):
        var a_val = A.data.unsafe_load(i).cast[f32]()
        var b_val = B.data.unsafe_load(i).cast[f32]()
        dot_sum += a_val * b_val
        norm_a_sq += a_val * a_val
        norm_b_sq += b_val * b_val

    if isnan(dot_sum) or isinf(dot_sum) or isnan(norm_a_sq) or isinf(norm_a_sq) or isnan(norm_b_sq) or isinf(norm_b_sq):
        return 0.0

    if norm_a_sq <= 0.0 or norm_b_sq <= 0.0:
        return 0.0
    var norm_a = sqrt(norm_a_sq)
    var norm_b = sqrt(norm_b_sq)
    var denom = max(norm_a * norm_b, Scalar[f32](1e-8))
    var res = dot_sum / denom
    if isnan(res) or isinf(res):
        return 0.0
    return res


def gemm_f16_sharded(
    A_shards: List[RuneTensor[f16]],
    B_shards: List[RuneTensor[f16]],
    mut C_shards: List[RuneTensor[f16]],
) raises:
    """
    The Multi-Device Strike of Mjölnir (Sharded Matrix Multiplication):
    Executes parallel GEMM matrix computations across distinct device realms in the Bifrost Shard Matrix.
    """
    if len(A_shards) == 0:
        raise Error("gemm_f16_sharded: empty shard list")
    if len(A_shards) != len(B_shards) or len(A_shards) != len(C_shards):
        raise Error("gemm_f16_sharded: shard list length mismatch")
    for i in range(len(A_shards)):
        gemm_f16(A_shards[i], B_shards[i], C_shards[i])


def all_reduce_sum(
    shards: List[RuneTensor[f16]], mut Out: RuneTensor[f16]
) raises:
    """
    The Convergence of Shards at the Bifrost Bridge (All-Reduce Sum):
    Accumulates hidden state representations from row-parallel device shards
    into a single unified tensor Out using SIMD vector reduction across living memory.
    """
    var num_shards = len(shards)
    if num_shards == 0:
        raise Error("all_reduce_sum: input shards list must not be empty")

    var size = Out.size
    for s in range(num_shards):
        if shards[s].size < size:
            raise Error("all_reduce_sum: shard size smaller than output tensor")

    var simd_end = (size // simd_w_f16) * simd_w_f16

    for i in range(0, simd_end, simd_w_f16):
        var acc = SIMD[f16, simd_w_f16](0.0)
        for s in range(num_shards):
            acc += shards[s].data.unsafe_load[width=simd_w_f16](i)
        Out.data.unsafe_store[width=simd_w_f16](i, acc)

    for i in range(simd_end, size):
        var acc: Scalar[f16] = 0.0
        for s in range(num_shards):
            acc += shards[s].data.unsafe_load(i)
        Out.data.unsafe_store(i, acc)


def gemm_f16_arm_neon(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
):
    """
    ᚨᚱᛗ·ᚾᛖᛟᚾ·ᚷᛖᛗᛗ — The Iron Thread Strike (gemm_f16_arm_neon)
    ══════════════════════════════════════════════════════════════════

    The Dvergar's hammer falls upon the NEON forge — 128-bit SIMD vector lanes
    woven from the ARM ISA's innermost sinew. Where `gemm_f16` commands 32 lanes
    in the wide Asgardian register file, the Iron Thread operates in lanes of 8
    (128 bits / 16 bits per f16 element = 8 elements per VECT register).

    This kernel is the sovereign compute path for:
      · Cortex-A55/A78/X1 mobile SoCs (Snapdragon, MediaTek, Exynos)
      · Apple A-series / M-series cores (NEON + AMX fallback)
      · NVIDIA Jetson Nano (Cortex-A57 ARM NEON host path)
      · Raspberry Pi 4/5 (Cortex-A72/A76 NEON)

    Inner Loop Structure:
    ─────────────────────
      For each output element C[m, n]:
        · Loads 8 × f16 from A[m, k:k+8]  → NEON vld1q_f16  (1 cycle throughput)
        · Loads 8 × f16 from B[n, k:k+8]  → NEON vld1q_f16  (1 cycle throughput)
        · Fused multiply-accumulate         → NEON vfmaq_f16  (2-cycle latency)
        · Horizontal reduction              → vaddvq_f16      (scalar extraction)
        · Scalar tail for K not divisible by neon_w=8

    Memory layout assumes B is in transposed (row-major W^T) form
    so that inner product loads are sequential — maximizing NEON prefetch
    and L1 cache hit rate for the weight matrix access pattern.
    """
    comptime neon_w = 8
    var M = A.rows
    var K = A.cols
    var N = B.rows

    for m in range(M):
        for n in range(N):
            var acc = SIMD[f16, neon_w](0.0)
            var simd_end = (K // neon_w) * neon_w
            for k in range(0, simd_end, neon_w):
                var a_vec = A.data.unsafe_load[width=neon_w](m * K + k)
                var b_vec = B.data.unsafe_load[width=neon_w](n * K + k)
                acc += a_vec * b_vec
            var sum_val: Scalar[f16] = acc.reduce_add()
            for k in range(simd_end, K):
                sum_val += A.data.unsafe_load(m * K + k) * B.data.unsafe_load(
                    n * K + k
                )
            C.set(m, n, sum_val)


def rmsnorm_arm_neon(
    mut T: RuneTensor[f16], weight: RuneTensor[f16], epsilon: Scalar[f32] = 1e-5
):
    """
    ᚱᛗᛋ·ᚾᛟᚱᛗ·ᚾᛖᛟᚾ — The Cleansing Fire of Járnviðr (rmsnorm_arm_neon)
    ══════════════════════════════════════════════════════════════════════

    The Cleansing Fire of Muspelheim reduced to 128-bit NEON lanes — a precise
    normalization rite tuned for the iron forest of ARM edge silicon (Járnviðr).
    Where `rmsnorm` forges with 32-wide f16 SIMD (the wide Asgardian path),
    this rite wields the NEON 8-lane hammer upon Cortex and Apple cores.

    Mathematical Contract:
    ──────────────────────
      For each token row r of T (shape: [rows, hidden_dim]):

        ss = Σ_{c=0}^{hidden_dim} T[r,c]² / hidden_dim          (sum of squares, cast f32)
        rms = sqrt(ss + ε)                                        (ε = 1e-5 stability guard)
        inv_rms = 1.0 / rms                                       (scalar reciprocal)
        T[r,c] = (T[r,c] × inv_rms) × weight[c]                  (normalize + rescale)

    NEON Execution Pattern:
    ───────────────────────
      Phase 1 — Sum of Squares (NEON vld1q_f16 → cast f32 → vmulq_f32 → vaddvq_f32):
        · 8 f16 elements loaded per cycle into NEON q-register
        · Widened to f32 for numerical stability before squaring
        · Horizontal lane reduction via vaddvq_f32 into scalar accumulator
        · Scalar tail for hidden_dim not divisible by neon_w=8

      Phase 2 — Normalize & Rescale (NEON vld1q_f16 × inv_rms × weight → vst1q_f16):
        · weight vector loaded in parallel from learned parameter tensor
        · Fused multiply-multiply: (x × inv_rms) × w in-place
        · Result stored back at same offset — no additional memory draw from MimirWell

    Zero dynamic allocation. The Cleansing Fire leaves no ash in the Well of Mimir.
    """
    comptime neon_w = 8
    var hidden_dim = T.cols
    var simd_end = (hidden_dim // neon_w) * neon_w
    for r in range(T.rows):
        var ss: Scalar[f32] = 0.0
        for c in range(0, simd_end, neon_w):
            var x = T.data.unsafe_load[width=neon_w](r * hidden_dim + c).cast[
                f32
            ]()
            ss += (x * x).reduce_add()
        for c in range(simd_end, hidden_dim):
            var x = T.data.unsafe_load(r * hidden_dim + c).cast[f32]()
            ss += x * x

        var rms = sqrt(ss / Float32(hidden_dim) + epsilon)
        var inv_rms = (1.0 / rms).cast[f16]()

        for c in range(0, simd_end, neon_w):
            var x = T.data.unsafe_load[width=neon_w](r * hidden_dim + c)
            var w = weight.data.unsafe_load[width=neon_w](c)
            var normalized = x * inv_rms
            T.data.unsafe_store[width=neon_w](
                r * hidden_dim + c, normalized * w
            )
        for c in range(simd_end, hidden_dim):
            var x = T.data.unsafe_load(r * hidden_dim + c)
            var w = weight.data.unsafe_load(c)
            var normalized = x * inv_rms
            T.data.unsafe_store(r * hidden_dim + c, normalized * w)


def gemm_f16_npu(
    A: RuneTensor[f16],
    B: RuneTensor[f16],
    mut C: RuneTensor[f16],
    backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON),
) raises:
    """
    Dispatch GEMM execution to NPUGate or raise explicit NPU error.
    """
    NPUGate.launch_gemm_npu(A, B, C, backend)


def gemm_f16_gpgpu_vector(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
):
    """
    ᛗᚢᛋᚨ·ᛋᚢᚈᚨ·ᚷᛖᛗᛗ — The Strike of the Eastern Forge (gemm_f16_gpgpu_vector)
    ════════════════════════════════════════════════════════════════════════════

    Routes to physical NVIDIA CUDA GPU execution when CUDA is available, or vector SIMD.
    """
    if CUDAGate.is_available() and CUDAGate.get_device_count() > 0:
        try:
            CUDAGate.launch_gemm_cuda(A, B, C)
            return
        except:
            pass

    comptime gpgpu_w = 16
    var M = A.rows
    var K = A.cols
    var N = B.rows

    for m in range(M):
        for n in range(N):
            var acc = SIMD[f16, gpgpu_w](0.0)
            var simd_end = (K // gpgpu_w) * gpgpu_w
            for k in range(0, simd_end, gpgpu_w):
                var a_vec = A.data.unsafe_load[width=gpgpu_w](m * K + k)
                var b_vec = B.data.unsafe_load[width=gpgpu_w](n * K + k)
                acc += a_vec * b_vec
            var sum_val: Scalar[f16] = acc.reduce_add()
            for k in range(simd_end, K):
                sum_val += A.data.unsafe_load(m * K + k) * B.data.unsafe_load(
                    n * K + k
                )
            C.set(m, n, sum_val)



def gemm_f16_mobile_opencl(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
):
    """
    ᛗᛟᛒᛁᛚᛖ·ᛟᛈᛖᚾᚲᛚ·ᚷᛖᛗᛗ — The Wandering Stream of Midgard (gemm_f16_mobile_opencl)
    ═════════════════════════════════════════════════════════════════════════════════════

    Host-only 8-wide Mojo SIMD experiment. The historical name is preserved
    for API compatibility; this function does not execute through OpenCL.
    """
    comptime mobile_w = 8
    var M = A.rows
    var K = A.cols
    var N = B.rows

    for m in range(M):
        for n in range(N):
            var acc = SIMD[f16, mobile_w](0.0)
            var simd_end = (K // mobile_w) * mobile_w
            for k in range(0, simd_end, mobile_w):
                var a_vec = A.data.unsafe_load[width=mobile_w](m * K + k)
                var b_vec = B.data.unsafe_load[width=mobile_w](n * K + k)
                acc += a_vec * b_vec
            var sum_val: Scalar[f16] = acc.reduce_add()
            for k in range(simd_end, K):
                sum_val += A.data.unsafe_load(m * K + k) * B.data.unsafe_load(
                    n * K + k
                )
            C.set(m, n, sum_val)


def rmsnorm_gpu(
    mut T: RuneTensor[f16],
    weight: RuneTensor[f16],
    realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA),
    epsilon: Scalar[f32] = 1e-5,
) raises:
    """
    ᚱᛗᛋ·ᚾᛟᚱᛗ·ᚷᛈᚢ — The Cleansing Stream of Alfheim (rmsnorm_gpu)
    ═════════════════════════════════════════════════════════════════

    Dispatches GPU RMSNorm execution for NVIDIA_CUDA realm.
    """
    if realm.value == GPURealmType.NVIDIA_CUDA:
        if not CUDAGate.is_available() or CUDAGate.get_device_count() <= 0:
            raise Error(
                "GPU RMSNorm execution error: NVIDIA CUDA runtime or GPU device"
                " not found"
            )
        rmsnorm(T, weight, epsilon)
        return

    raise Error(
        "GPU RMSNorm execution is not implemented for realm " + realm.name()
    )



def gemm_f16_gpu(
    A: RuneTensor[f16],
    B: RuneTensor[f16],
    mut C: RuneTensor[f16],
    realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA),
) raises:
    """
    ᚷᛈᚢ·ᚱᛖᚨᛚᛗ·ᚷᚨᛏᛖᚹᚨᚤ — The Gateway of the GPU Realms (gemm_f16_gpu)
    ══════════════════════════════════════════════════════════════════════════

    Dispatches execution to CUDAGate for NVIDIA_CUDA realm, or raises explicit
    unsupported error for other realms.
    """
    if realm.value == GPURealmType.NVIDIA_CUDA:
        if B.is_quantized:
            gemm_f16(A, B, C)
            return
        CUDAGate.launch_gemm_cuda(A, B, C)
        return

    if realm.value == GPURealmType.APPLE_METAL:
        MetalGate.launch_gemm_metal(A, B, C)
        return

    if realm.value == GPURealmType.INTEL_ONEAPI_XE:
        IntelGate.launch_gemm_intel(A, B, C)
        return

    if realm.value == GPURealmType.AMD_ROCM_HIP:
        AMDGate.launch_gemm_amd(A, B, C)
        return

    raise Error("GPU execution is not implemented for realm " + realm.name())


def gemm_f16_cuda(
    mut executor: CUDAF16GemmExecutor,
    A: RuneTensor[f16],
    B: RuneTensor[f16],
    mut C: RuneTensor[f16],
) raises:
    """Execute F16 GEMM through an explicit selected-device CUDA owner."""
    executor.execute(A, B, C)
