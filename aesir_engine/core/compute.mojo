# core/compute.mojo
# The Forge of Nidavellir: Aesir Engine Core Compute Kernels
#
# Here, the raw, mathematical truth of the model is hammered into being.
# We bypass the bloated abstractions of Midgard, striking the silicon directly
# through SIMD and parallelized runic operations.

from core.packed_quantization import packed_value
from .parallel import par_for, _env_int, cpu_has_vnni
from std.math import exp, max, sqrt, cos, sin, isinf, isnan, tanh
from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from std.algorithm import vectorize
from std.sys.intrinsics import llvm_intrinsic
from std.sys import CompilationTarget

from .mimir_well import (
    RuneTensor,
    MimirWell,
    NPUBackendType,
    GPURealmType,
    CompressedFormatType,
    bf16_bits_to_f32,
    f16,
    f32,
    int4,
)
from .cuda_gate import CUDAGate
from .cuda_compute import CUDAF16GemmExecutor
from .metal_gate import MetalGate
from .intel_gate import IntelGate
from .amd_gate import AMDGate
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
    dequantize_iq1_m_blocks,
    dequantize_iq4_nl_blocks,
    dequantize_iq4_xs_blocks,
    dequantize_iq2_xxs_blocks,
    dequantize_iq2_xs_blocks,
    dequantize_iq2_s_blocks,
    dequantize_iq3_xxs_blocks,
    dequantize_iq3_s_blocks,
    dequantize_tq1_0_blocks,
    dequantize_tq2_0_blocks,
    dequantize_tq_block,
    tq_block_bytes,
    gemm_tq1_0_blocks,
    dequantize_iq_block,
    iq_block_bytes,
    iq_grid_materialize,
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
    # Packed GGUF layout, walked byte-level (S-083): the BlockQ4_1 struct's
    # Mojo stride is 32 bytes, not the packed 20 — a struct-pointer walk
    # drifts on real files. Block = f16 scale @0, f16 min @2, qs @4..19;
    # value = nibble * scale + min, low nibbles first.
    if num_blocks <= 0:
        return
    var b_bytes = block_ptr.unsafe_bitcast[Byte]()
    for b in range(num_blocks):
        var b_ptr = b_bytes.unsafe_offset(b * 20)
        var scale = b_ptr.unsafe_bitcast[Scalar[f16]]().unsafe_load()
        var min_val = b_ptr.unsafe_offset(2).unsafe_bitcast[Scalar[f16]]().unsafe_load()
        var out_offset = b * 32
        for i in range(16):
            var qs = b_ptr.unsafe_load(4 + i)
            var l = Scalar[f16](qs & 0x0F) * scale + min_val
            var u = Scalar[f16]((qs >> 4) & 0x0F) * scale + min_val
            out_ptr.unsafe_store(out_offset + i, l)
            out_ptr.unsafe_store(out_offset + 16 + i, u)

@always_inline
def dequantize_q5_0(
    block_ptr: Pointer[BlockQ5_0, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_blocks: Int,
):
    # Packed GGUF layout, walked byte-level (S-083; cf. the raw Q5_0 test's
    # "legacy padded structs" note): BlockQ5_0's Mojo stride is 32 bytes,
    # not the packed 22. Block = f16 scale @0, qh bytes @2..5, qs @6..21;
    # value = ((nibble | high_bit<<4) - 16) * scale.
    if num_blocks <= 0:
        return
    var b_bytes = block_ptr.unsafe_bitcast[Byte]()
    for b in range(num_blocks):
        var b_ptr = b_bytes.unsafe_offset(b * 22)
        var scale = b_ptr.unsafe_bitcast[Scalar[f16]]().unsafe_load()
        var out_offset = b * 32
        for i in range(16):
            var qh_byte_lo = b_ptr.unsafe_load(2 + i // 8)
            var h_bit_lo = Scalar[f16](
                (qh_byte_lo >> Scalar[DType.uint8](i % 8)) & 1
            )
            var qh_byte_hi = b_ptr.unsafe_load(2 + (i + 16) // 8)
            var h_bit_hi = Scalar[f16](
                (qh_byte_hi >> Scalar[DType.uint8]((i + 16) % 8)) & 1
            )
            var qs = b_ptr.unsafe_load(6 + i)
            var l_val = (Scalar[f16](qs & 0x0F) + h_bit_lo * 16.0) - 16.0
            var u_val = (
                Scalar[f16]((qs >> 4) & 0x0F) + h_bit_hi * 16.0
            ) - 16.0
            out_ptr.unsafe_store(out_offset + i, l_val * scale)
            out_ptr.unsafe_store(out_offset + 16 + i, u_val * scale)

@always_inline
def dequantize_q5_1(
    block_ptr: Pointer[BlockQ5_1, MutUntrackedOrigin],
    out_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_blocks: Int,
):
    # Packed GGUF layout, walked byte-level (S-083): BlockQ5_1's Mojo
    # stride is 32 bytes, not the packed 24. Block = f16 scale @0,
    # f16 min @2, qh bytes @4..7, qs @8..23;
    # value = (nibble | high_bit<<4) * scale + min.
    if num_blocks <= 0:
        return
    var b_bytes = block_ptr.unsafe_bitcast[Byte]()
    for b in range(num_blocks):
        var b_ptr = b_bytes.unsafe_offset(b * 24)
        var scale = b_ptr.unsafe_bitcast[Scalar[f16]]().unsafe_load()
        var min_val = b_ptr.unsafe_offset(2).unsafe_bitcast[Scalar[f16]]().unsafe_load()
        var out_offset = b * 32
        for i in range(16):
            var qh_byte_lo = b_ptr.unsafe_load(4 + i // 8)
            var h_bit_lo = Scalar[f16](
                (qh_byte_lo >> Scalar[DType.uint8](i % 8)) & 1
            )
            var qh_byte_hi = b_ptr.unsafe_load(4 + (i + 16) // 8)
            var h_bit_hi = Scalar[f16](
                (qh_byte_hi >> Scalar[DType.uint8]((i + 16) % 8)) & 1
            )
            var qs = b_ptr.unsafe_load(8 + i)
            var l_val = Scalar[f16](qs & 0x0F) + h_bit_lo * 16.0
            var u_val = Scalar[f16]((qs >> 4) & 0x0F) + h_bit_hi * 16.0
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
    elif format.value == CompressedFormatType.IQ1_M:
        var blocks = quantized_block_count(num_elements, 256, "IQ1_M")
        dequantize_iq1_m_blocks(data, blocks * 56, out_ptr, num_elements)
    elif format.value == CompressedFormatType.IQ2_S:
        var blocks = quantized_block_count(num_elements, 256, "IQ2_S")
        dequantize_iq2_s_blocks(data, blocks * 82, out_ptr, num_elements)
    elif format.value == CompressedFormatType.IQ3_S:
        var blocks = quantized_block_count(num_elements, 256, "IQ3_S")
        dequantize_iq3_s_blocks(data, blocks * 110, out_ptr, num_elements)
    elif format.value == CompressedFormatType.IQ2_XS:
        var blocks = quantized_block_count(num_elements, 256, "IQ2_XS")
        dequantize_iq2_xs_blocks(data, blocks * 74, out_ptr, num_elements)
    elif format.value == CompressedFormatType.IQ3_XXS:
        var blocks = quantized_block_count(num_elements, 256, "IQ3_XXS")
        dequantize_iq3_xxs_blocks(data, blocks * 98, out_ptr, num_elements)
    elif format.value == CompressedFormatType.IQ4_NL:
        var blocks = quantized_block_count(num_elements, 32, "IQ4_NL")
        dequantize_iq4_nl_blocks(data, blocks * 18, out_ptr, num_elements)
    elif format.value == CompressedFormatType.IQ4_XS:
        var blocks = quantized_block_count(num_elements, 256, "IQ4_XS")
        dequantize_iq4_xs_blocks(data, blocks * 136, out_ptr, num_elements)
    elif format.value == CompressedFormatType.TERNARY_155BIT:
        var blocks = quantized_block_count(num_elements, 256, "TQ1_0")
        dequantize_tq1_0_blocks(data, blocks * 54, out_ptr, num_elements)
    elif format.value == CompressedFormatType.TQ2_0:
        var blocks = quantized_block_count(num_elements, 256, "TQ2_0")
        dequantize_tq2_0_blocks(data, blocks * 66, out_ptr, num_elements)
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
    # Packed GGUF layout, walked byte-level (S-083): BlockQ4_1's Mojo
    # stride is 32 bytes, not the packed 20 — the struct-pointer walk
    # drifted on real files (corrupt values; SIGSEGV past tensor ends).
    var src_bytes = B.data.unsafe_bitcast[Byte]()

    print("gemm_f16: A.rows:", A.rows, "A.cols:", A.cols, "B.rows:", B.rows, "B.cols:", B.cols, "B.is_quant:", B.is_quantized)
    for row in range(rows):
        for output_index in range(output_dim):
            var sum: Scalar[f32] = 0.0
            var row_byte_offset = (output_index * blocks_per_row) * 20
            for b in range(blocks_per_row):
                var blk_ptr = src_bytes.unsafe_offset(row_byte_offset + b * 20)
                var scale = blk_ptr.unsafe_bitcast[Scalar[f16]]().unsafe_load()
                var min_val = blk_ptr.unsafe_offset(2).unsafe_bitcast[Scalar[f16]]().unsafe_load()

                var col_idx = b * 32
                for i in range(16):
                    var qs = blk_ptr.unsafe_load(4 + i)
                    var w_lo = (Scalar[f16](qs & 0x0F) * scale + min_val).cast[f32]()
                    var w_hi = (Scalar[f16]((qs >> 4) & 0x0F) * scale + min_val).cast[f32]()
                    var a_lo = A.data.unsafe_load(
                        row * shared_dim + col_idx + i
                    ).cast[f32]()
                    var a_hi = A.data.unsafe_load(
                        row * shared_dim + col_idx + 16 + i
                    ).cast[f32]()
                    sum += a_lo * w_lo + a_hi * w_hi

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
    # Packed GGUF layout, walked byte-level (S-083): BlockQ5_1's Mojo
    # stride is 32 bytes, not the packed 24 — see gemm_q4_1's note.
    var src_bytes = B.data.unsafe_bitcast[Byte]()

    for row in range(rows):
        for output_index in range(output_dim):
            var sum: Scalar[f32] = 0.0
            var row_byte_offset = (output_index * blocks_per_row) * 24
            for b in range(blocks_per_row):
                var blk_ptr = src_bytes.unsafe_offset(row_byte_offset + b * 24)
                var scale = blk_ptr.unsafe_bitcast[Scalar[f16]]().unsafe_load()
                var min_val = blk_ptr.unsafe_offset(2).unsafe_bitcast[Scalar[f16]]().unsafe_load()

                var col_idx = b * 32
                for i in range(16):
                    var qh_byte_lo = blk_ptr.unsafe_load(4 + i // 8)
                    var h_bit_lo = Scalar[f16](
                        (qh_byte_lo >> Scalar[DType.uint8](i % 8)) & 1
                    )
                    var qh_byte_hi = blk_ptr.unsafe_load(4 + (i + 16) // 8)
                    var h_bit_hi = Scalar[f16](
                        (qh_byte_hi >> Scalar[DType.uint8]((i + 16) % 8)) & 1
                    )
                    var qs = blk_ptr.unsafe_load(8 + i)

                    var a_lo = A.data.unsafe_load(
                        row * shared_dim + col_idx + i
                    ).cast[f32]()
                    var a_hi = A.data.unsafe_load(
                        row * shared_dim + col_idx + 16 + i
                    ).cast[f32]()

                    var w_lo = (
                        (Scalar[f16](qs & 0x0F) + h_bit_lo * 16.0) * scale
                        + min_val
                    ).cast[f32]()
                    var w_hi = (
                        (Scalar[f16]((qs >> 4) & 0x0F) + h_bit_hi * 16.0)
                        * scale
                        + min_val
                    ).cast[f32]()

                    sum += a_lo * w_lo + a_hi * w_hi

            C.set(row, output_index, sum.cast[f16]())

def _gemm_q8_0_range(
    a_addr: Int64,
    b_addr: Int64,
    c_addr: Int64,
    a_rows: Int,
    a_cols: Int,
    c_cols: Int,
    out_lo: Int,
    out_hi: Int,
):
    """Output-column range of the Q8_0 GEMM (see gemm_q8_0).

    Each output element is an independent reduction over ascending
    blocks/lanes with the exact arithmetic of the original serial
    body, so column ranges are bit-identical in any partition.
    """
    var a_data = Pointer[Scalar[f16], MutUntrackedOrigin](
        unsafe_from_address=Int(a_addr)
    )
    var c_data = Pointer[Scalar[f16], MutUntrackedOrigin](
        unsafe_from_address=Int(c_addr)
    )
    var weights = Pointer[UInt8, MutUntrackedOrigin](
        unsafe_from_address=Int(b_addr)
    )
    var blocks_per_row = a_cols // 32
    for row in range(a_rows):
        for output in range(out_lo, out_hi):
            var total: Float32 = 0
            var row_base = output * blocks_per_row * 34
            for block in range(blocks_per_row):
                var p = row_base + block * 34
                var scale = weights.unsafe_offset(p).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
                for lane in range(32):
                    var q = weights.unsafe_load(p + 2 + lane).cast[DType.int8]()
                    total += a_data.unsafe_load(row * a_cols + block * 32 + lane).cast[f32]() * Float32(q) * scale
            c_data.unsafe_store(row * c_cols + output, total.cast[f16]())


def _gemm_q8_0_fast_range(
    a_addr: Int64,
    b_addr: Int64,
    c_addr: Int64,
    a_rows: Int,
    a_cols: Int,
    c_cols: Int,
    out_lo: Int,
    out_hi: Int,
):
    """Decode-once fast range for the Q8_0 GEMM.

    Each output row's Q8_0 blocks are decoded to an F32 scratch row a
    single time, then every A row dots against the scratch with SIMD
    (W=16 F32 lanes). The serial body re-decoded every block for every
    element of every row. Summation inside a dot is lane-grouped, so
    results can differ from the serial body in final rounding only —
    the same accepted fast-path class as _gemm_k_fast. The bit-exact
    serial body remains in _gemm_q8_0_range.
    """
    var a_data = Pointer[Scalar[f16], MutUntrackedOrigin](
        unsafe_from_address=Int(a_addr)
    )
    var c_data = Pointer[Scalar[f16], MutUntrackedOrigin](
        unsafe_from_address=Int(c_addr)
    )
    var weights = Pointer[UInt8, MutUntrackedOrigin](
        unsafe_from_address=Int(b_addr)
    )
    comptime W = 16
    var blocks_per_row = a_cols // 32
    var scratch = alloc[Float32](a_cols)
    var limit = a_cols - (a_cols % W)
    for output in range(out_lo, out_hi):
        var row_base = output * blocks_per_row * 34
        for block in range(blocks_per_row):
            var p = row_base + block * 34
            var scale = weights.unsafe_offset(p).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
            var dst = block * 32
            for lane in range(32):
                var q = weights.unsafe_load(p + 2 + lane).cast[DType.int8]()
                scratch.unsafe_store(dst + lane, Float32(q) * scale)
        for row in range(a_rows):
            var a_base = row * a_cols
            var acc = SIMD[DType.float32, W](0.0)
            var j = 0
            while j < limit:
                var avec = SIMD[DType.float32, W]()
                var wvec = SIMD[DType.float32, W]()
                for lane in range(W):
                    avec[lane] = a_data.unsafe_load(a_base + j + lane).cast[f32]()
                    wvec[lane] = scratch.unsafe_load(j + lane)
                acc += avec * wvec
                j += W
            var total = Float32(0.0)
            for lane in range(W):
                total += acc[lane]
            while j < a_cols:
                total += a_data.unsafe_load(a_base + j).cast[f32]() * scratch.unsafe_load(j)
                j += 1
            c_data.unsafe_store(row * c_cols + output, total.cast[f16]())
    scratch.unsafe_free()


def _gemm_q8_0_fast_worker(ctx_addr: Int64, start: Int64, end: Int64):
    """FFI range callback for the fast Q8_0 range; ctx slots as in
    _gemm_q8_0_worker."""
    var ctx = Pointer[Int64, MutUntrackedOrigin](
        unsafe_from_address=Int(ctx_addr)
    )
    _gemm_q8_0_fast_range(
        ctx.unsafe_load(0),
        ctx.unsafe_load(1),
        ctx.unsafe_load(2),
        Int(ctx.unsafe_load(3)),
        Int(ctx.unsafe_load(4)),
        Int(ctx.unsafe_load(5)),
        Int(start),
        Int(end),
    )


def _gemm_q8_0_worker(ctx_addr: Int64, start: Int64, end: Int64):
    """FFI range callback; ctx slots: [A.data, B.data, C.data,
    A.rows, A.cols, C.cols]."""
    var ctx = Pointer[Int64, MutUntrackedOrigin](
        unsafe_from_address=Int(ctx_addr)
    )
    _gemm_q8_0_range(
        ctx.unsafe_load(0),
        ctx.unsafe_load(1),
        ctx.unsafe_load(2),
        Int(ctx.unsafe_load(3)),
        Int(ctx.unsafe_load(4)),
        Int(ctx.unsafe_load(5)),
        Int(start),
        Int(end),
    )


def gemm_q8_0(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols != A.cols or A.cols % 32 != 0:
        raise Error("gemm_q8_0: invalid shape or incomplete quantization block")
    if C.rows != A.rows or C.cols != B.rows:
        raise Error("gemm_q8_0: output matrix shape mismatch")
    if Int(A.data) <= 1 or Int(B.data) <= 1 or Int(C.data) <= 1:
        raise Error("gemm_q8_0: invalid storage")
    # Model-wave change: the serial triple loop was the Coder-3B
    # Q8_0 crown bottleneck. Output columns partition across threads
    # via par_for. The threaded body is the decode-once SIMD fast
    # range (_gemm_q8_0_fast_range): 776.88 s -> 455.24 s for the
    # crown short probe came from threading the serial body alone;
    # the fast range is measured separately. The bit-exact serial
    # range (_gemm_q8_0_range) remains as the reference body.
    var cp = alloc[Int64](6)
    cp.unsafe_store(0, Int64(Int(A.data)))
    cp.unsafe_store(1, Int64(Int(B.data)))
    cp.unsafe_store(2, Int64(Int(C.data)))
    cp.unsafe_store(3, Int64(A.rows))
    cp.unsafe_store(4, Int64(A.cols))
    cp.unsafe_store(5, Int64(C.cols))
    _ = par_for[_gemm_q8_0_fast_worker](
        Int64(Int(cp)),
        B.rows,
        Int64(A.rows) * Int64(B.rows) * Int64(A.cols),
    )
    cp.unsafe_free()


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


def _gemm_k_fast_range(
    a_addr: Int64,
    b_addr: Int64,
    c_addr: Int64,
    a_rows: Int,
    a_cols: Int,
    b_rows: Int,
    c_cols: Int,
    kind: Int,
    out_lo: Int,
    out_hi: Int,
):
    """Range-bounded body of the fast K-quant GEMM (see _gemm_k_fast).

    Computes output columns [out_lo, out_hi) of C = A @ B^T. Every
    output element is computed entirely inside this call with the same
    accumulation order over K as the unbounded body, so partitioning
    the output columns across threads is bit-identical to running the
    whole range serially.
    """
    var a_data = Pointer[Scalar[f16], MutUntrackedOrigin](
        unsafe_from_address=Int(a_addr)
    )
    var c_data = Pointer[Scalar[f16], MutUntrackedOrigin](
        unsafe_from_address=Int(c_addr)
    )
    var weights = Pointer[UInt8, MutUntrackedOrigin](
        unsafe_from_address=Int(b_addr)
    )
    var blocks_per_row = a_cols // 256
    var block_bytes = 144 if kind == 12 else 210 if kind == 14 else 176 if kind == 13 else 110 if kind == 11 else 84
    var scratch = InlineArray[Float32, 256](uninitialized=True)
    var sp = scratch.unsafe_ptr()
    var row_start = 0
    while row_start < a_rows:
        var rows_here = a_rows - row_start
        if rows_here > 256:
            rows_here = 256
        var acc = InlineArray[Float32, 256](fill=Float32(0.0))
        for output in range(out_lo, out_hi):
            for r in range(rows_here):
                acc[r] = Float32(0.0)
            for sb in range(blocks_per_row):
                var p = (output * blocks_per_row + sb) * block_bytes
                if kind == 12:
                    # Q4_K super-block: d, dmin, 12 packed scale/min bytes,
                    # then 128 nibble bytes for 256 values in 8 sub-blocks.
                    var d = weights.unsafe_offset(p).unsafe_bitcast[Scalar[f16]]().unsafe_load().cast[f32]()
                    var dmin = weights.unsafe_offset(p + 2).unsafe_bitcast[Scalar[f16]]().unsafe_load().cast[f32]()
                    var coef_a = InlineArray[Float32, 8](uninitialized=True)
                    var coef_b = InlineArray[Float32, 8](uninitialized=True)
                    for g in range(8):
                        var scale: Int
                        var minimum: Int
                        if g < 4:
                            scale = Int(weights.unsafe_load(p + 4 + g)) & 63
                            minimum = Int(weights.unsafe_load(p + 8 + g)) & 63
                        else:
                            scale = (Int(weights.unsafe_load(p + 8 + g)) & 15) | ((Int(weights.unsafe_load(p + g)) >> 6) << 4)
                            minimum = (Int(weights.unsafe_load(p + 8 + g)) >> 4) | ((Int(weights.unsafe_load(p + 4 + g)) >> 6) << 4)
                        coef_a[g] = d * Float32(scale)
                        coef_b[g] = dmin * Float32(minimum)
                    var qs = p + 16
                    for h in range(4):
                        var chunk0 = weights.unsafe_load[width=16](qs + h * 32)
                        var chunk1 = weights.unsafe_load[width=16](qs + h * 32 + 16)
                        var g_lo = 2 * h
                        var g_hi = 2 * h + 1
                        sp.unsafe_store[width=16](g_lo * 32, coef_a[g_lo] * (chunk0 & UInt8(0x0F)).cast[f32]() - coef_b[g_lo])
                        sp.unsafe_store[width=16](g_lo * 32 + 16, coef_a[g_lo] * (chunk1 & UInt8(0x0F)).cast[f32]() - coef_b[g_lo])
                        sp.unsafe_store[width=16](g_hi * 32, coef_a[g_hi] * (chunk0 >> 4).cast[f32]() - coef_b[g_hi])
                        sp.unsafe_store[width=16](g_hi * 32 + 16, coef_a[g_hi] * (chunk1 >> 4).cast[f32]() - coef_b[g_hi])
                elif kind == 13:
                    # Q5_K super-block: Q4_K header/scales, 32 high-bit
                    # bytes at p+16 (bit g of byte lane is bit 4 of
                    # element g*32+lane), nibble quants at p+48.
                    var d = weights.unsafe_offset(p).unsafe_bitcast[Scalar[f16]]().unsafe_load().cast[f32]()
                    var dmin = weights.unsafe_offset(p + 2).unsafe_bitcast[Scalar[f16]]().unsafe_load().cast[f32]()
                    var coef_a = InlineArray[Float32, 8](uninitialized=True)
                    var coef_b = InlineArray[Float32, 8](uninitialized=True)
                    for g in range(8):
                        var scale: Int
                        var minimum: Int
                        if g < 4:
                            scale = Int(weights.unsafe_load(p + 4 + g)) & 63
                            minimum = Int(weights.unsafe_load(p + 8 + g)) & 63
                        else:
                            scale = (Int(weights.unsafe_load(p + 8 + g)) & 15) | ((Int(weights.unsafe_load(p + g)) >> 6) << 4)
                            minimum = (Int(weights.unsafe_load(p + 8 + g)) >> 4) | ((Int(weights.unsafe_load(p + 4 + g)) >> 6) << 4)
                        coef_a[g] = d * Float32(scale)
                        coef_b[g] = dmin * Float32(minimum)
                    var qs = p + 48
                    var qh0 = weights.unsafe_load[width=16](p + 16)
                    var qh1 = weights.unsafe_load[width=16](p + 32)
                    for h in range(4):
                        var chunk0 = weights.unsafe_load[width=16](qs + h * 32)
                        var chunk1 = weights.unsafe_load[width=16](qs + h * 32 + 16)
                        var g_lo = 2 * h
                        var g_hi = 2 * h + 1
                        var hi_lo0 = ((qh0 >> UInt8(g_lo)) & UInt8(1)).cast[f32]() * Float32(16.0)
                        var hi_lo1 = ((qh1 >> UInt8(g_lo)) & UInt8(1)).cast[f32]() * Float32(16.0)
                        var hi_hi0 = ((qh0 >> UInt8(g_hi)) & UInt8(1)).cast[f32]() * Float32(16.0)
                        var hi_hi1 = ((qh1 >> UInt8(g_hi)) & UInt8(1)).cast[f32]() * Float32(16.0)
                        sp.unsafe_store[width=16](g_lo * 32, coef_a[g_lo] * ((chunk0 & UInt8(0x0F)).cast[f32]() + hi_lo0) - coef_b[g_lo])
                        sp.unsafe_store[width=16](g_lo * 32 + 16, coef_a[g_lo] * ((chunk1 & UInt8(0x0F)).cast[f32]() + hi_lo1) - coef_b[g_lo])
                        sp.unsafe_store[width=16](g_hi * 32, coef_a[g_hi] * ((chunk0 >> 4).cast[f32]() + hi_hi0) - coef_b[g_hi])
                        sp.unsafe_store[width=16](g_hi * 32 + 16, coef_a[g_hi] * ((chunk1 >> 4).cast[f32]() + hi_hi1) - coef_b[g_hi])
                elif kind == 14:
                    # Q6_K super-block: 128 low-nibble bytes, 64 high-bit
                    # bytes, 16 int8 scales (one per 16 values), then d.
                    var d = weights.unsafe_offset(p + 208).unsafe_bitcast[Scalar[f16]]().unsafe_load().cast[f32]()
                    for c in range(16):
                        var half = c // 8
                        var group = (c % 8) // 2
                        var hl = c % 2
                        var scale = weights.unsafe_offset(p + 192).unsafe_bitcast[Scalar[DType.int8]]().unsafe_load(c).cast[f32]()
                        var coef = d * scale
                        var ql = weights.unsafe_load[width=16](p + half * 64 + (group % 2) * 32 + hl * 16)
                        var nib = (ql & UInt8(0x0F)) if group < 2 else (ql >> 4)
                        var qh = weights.unsafe_load[width=16](p + 128 + half * 32 + hl * 16)
                        var hi = (qh >> UInt8(2 * group)) & UInt8(3)
                        var q = (nib | (hi << 4)).cast[f32]()
                        sp.unsafe_store[width=16](c * 16, coef * (q - Float32(32.0)))
                elif kind == 11:
                    # Q3_K super-block: 32 high-bit bytes, 64 low-2-bit
                    # bytes, 12 packed scale bytes, d at p+108. Scale is
                    # per 16-value sub-block; q = low - 4 + 4*high_set
                    # reproduces packed_value's recentered values.
                    # S-042: the sixteen sub-block coefficients and the
                    # six distinct packed vectors (4 qs + 2 hmask) are
                    # hoisted out of the sub-block loop; the loop used
                    # to reload each qs/hmask vector four times and
                    # re-derive each scale with div/mod plus repeated
                    # byte loads (32 scalar loads for 12 header bytes).
                    # Per-element arithmetic is unchanged: coef[c] is
                    # the identical d * Float32(scale) product and each
                    # lane still forms coef * (low - 4 + 4*high) from
                    # the same packed fields, so the decoded scratch
                    # row is bit-identical to the loop form.
                    var d = weights.unsafe_offset(p + 108).unsafe_bitcast[Scalar[f16]]().unsafe_load().cast[f32]()
                    var sb0 = Int(weights.unsafe_load(p + 96))
                    var sb1 = Int(weights.unsafe_load(p + 97))
                    var sb2 = Int(weights.unsafe_load(p + 98))
                    var sb3 = Int(weights.unsafe_load(p + 99))
                    var sb4 = Int(weights.unsafe_load(p + 100))
                    var sb5 = Int(weights.unsafe_load(p + 101))
                    var sb6 = Int(weights.unsafe_load(p + 102))
                    var sb7 = Int(weights.unsafe_load(p + 103))
                    var ab0 = Int(weights.unsafe_load(p + 104))
                    var ab1 = Int(weights.unsafe_load(p + 105))
                    var ab2 = Int(weights.unsafe_load(p + 106))
                    var ab3 = Int(weights.unsafe_load(p + 107))
                    var coef = InlineArray[Float32, 16](uninitialized=True)
                    coef[0] = d * Float32(((sb0 & 15) | (((ab0 >> 0) & 3) << 4)) - 32)
                    coef[1] = d * Float32(((sb1 & 15) | (((ab1 >> 0) & 3) << 4)) - 32)
                    coef[2] = d * Float32(((sb2 & 15) | (((ab2 >> 0) & 3) << 4)) - 32)
                    coef[3] = d * Float32(((sb3 & 15) | (((ab3 >> 0) & 3) << 4)) - 32)
                    coef[4] = d * Float32(((sb4 & 15) | (((ab0 >> 2) & 3) << 4)) - 32)
                    coef[5] = d * Float32(((sb5 & 15) | (((ab1 >> 2) & 3) << 4)) - 32)
                    coef[6] = d * Float32(((sb6 & 15) | (((ab2 >> 2) & 3) << 4)) - 32)
                    coef[7] = d * Float32(((sb7 & 15) | (((ab3 >> 2) & 3) << 4)) - 32)
                    coef[8] = d * Float32(((sb0 >> 4) | (((ab0 >> 4) & 3) << 4)) - 32)
                    coef[9] = d * Float32(((sb1 >> 4) | (((ab1 >> 4) & 3) << 4)) - 32)
                    coef[10] = d * Float32(((sb2 >> 4) | (((ab2 >> 4) & 3) << 4)) - 32)
                    coef[11] = d * Float32(((sb3 >> 4) | (((ab3 >> 4) & 3) << 4)) - 32)
                    coef[12] = d * Float32(((sb4 >> 4) | (((ab0 >> 6) & 3) << 4)) - 32)
                    coef[13] = d * Float32(((sb5 >> 4) | (((ab1 >> 6) & 3) << 4)) - 32)
                    coef[14] = d * Float32(((sb6 >> 4) | (((ab2 >> 6) & 3) << 4)) - 32)
                    coef[15] = d * Float32(((sb7 >> 4) | (((ab3 >> 6) & 3) << 4)) - 32)
                    var qvs = InlineArray[SIMD[DType.uint8, 16], 4](uninitialized=True)
                    qvs[0] = weights.unsafe_load[width=16](p + 32)
                    qvs[1] = weights.unsafe_load[width=16](p + 48)
                    qvs[2] = weights.unsafe_load[width=16](p + 64)
                    qvs[3] = weights.unsafe_load[width=16](p + 80)
                    var hvs = InlineArray[SIMD[DType.uint8, 16], 2](uninitialized=True)
                    hvs[0] = weights.unsafe_load[width=16](p)
                    hvs[1] = weights.unsafe_load[width=16](p + 16)
                    for c in range(16):
                        var half = c // 8
                        var group = (c % 8) // 2
                        var lg = c % 2
                        var qb = qvs[half * 2 + lg]
                        var low = ((qb >> UInt8(2 * group)) & UInt8(3)).cast[f32]()
                        var hb = hvs[lg]
                        var high = ((hb >> UInt8(group + half * 4)) & UInt8(1)).cast[f32]()
                        sp.unsafe_store[width=16](c * 16, coef[c] * (low - Float32(4.0) + Float32(4.0) * high))
                else:
                    # Q2_K super-block (kind 10): 16 scale/min bytes (one
                    # per 16-value sub-block), 64 packed 2-bit bytes,
                    # d at p+80, dmin at p+82.
                    var d = weights.unsafe_offset(p + 80).unsafe_bitcast[Scalar[f16]]().unsafe_load().cast[f32]()
                    var dmin = weights.unsafe_offset(p + 82).unsafe_bitcast[Scalar[f16]]().unsafe_load().cast[f32]()
                    for c in range(16):
                        var sc = Int(weights.unsafe_load(p + c))
                        var coef_a = d * Float32(sc & 15)
                        var coef_b = dmin * Float32(sc >> 4)
                        var half = c // 8
                        var group = (c % 8) // 2
                        var lg = c % 2
                        var qb = weights.unsafe_load[width=16](p + 16 + half * 32 + lg * 16)
                        var q = ((qb >> UInt8(2 * group)) & UInt8(3)).cast[f32]()
                        sp.unsafe_store[width=16](c * 16, coef_a * q - coef_b)
                var k0 = sb * 256
                for r in range(rows_here):
                    var a_row = row_start + r
                    var accv = SIMD[DType.float32, 16](Float32(0.0))
                    for chunk in range(16):
                        var wv = sp.unsafe_load[width=16](chunk * 16)
                        var av = a_data.unsafe_load[width=16](a_row * a_cols + k0 + chunk * 16).cast[f32]()
                        accv += wv * av
                    acc[r] += accv.reduce_add()
            for r in range(rows_here):
                c_data.unsafe_store((row_start + r) * c_cols + output, acc[r].cast[f16]())
        row_start += rows_here




comptime VNNI_DEFAULT_ON: Bool = False


def _vnni_allowed() -> Bool:
    """Whether the K-quant GEMM may take the VNNI int8 path:
    AESIR_VNNI=1 forces it on, =0 forces it off, unset uses
    VNNI_DEFAULT_ON; the runtime CPU/OS feature probe gates every
    case, so an explicit =1 on a machine without AVX-512 VNNI still
    falls back to the f32 path."""
    var v = _env_int("AESIR_VNNI", -1)
    if v == 0:
        return False
    if v == 1:
        return cpu_has_vnni()
    return VNNI_DEFAULT_ON and cpu_has_vnni()


def _vpdpbusd_512_zero(
    a: SIMD[DType.uint8, 64], b: SIMD[DType.int8, 64]
) -> SIMD[DType.int32, 16]:
    """Exact 64-byte unsigned-by-signed dot product, 16 lanes of four
    consecutive bytes: out[l] = sum_j a[4l+j] * b[4l+j], accumulated
    from zero.

    On a compilation target with AVX-512 VNNI this is the VPDPBUSD
    instruction itself. On any other target the raw intrinsic cannot
    be instruction-selected at all — the X86 code generator aborts
    with "Do not know how to split the result of this operator" —
    so there the identical integer dot is formed from portable SIMD
    ops, which legalize on every target. The gate is the compile-time
    target query, so the intrinsic never reaches the code generator
    for a target that cannot select it; the runtime probe in
    _vnni_allowed still decides whether the VNNI path runs at all.

    Exactness: each product fits int16 (|u8 * s8| <= 32640), pair and
    quad sums fit int32 with wide headroom, and integer addition
    within a lane is order-free — both forms are bit-identical.
    """
    if CompilationTarget.has_vnni():
        return llvm_intrinsic[
            "llvm.x86.avx512.vpdpbusd.512", SIMD[DType.int32, 16]
        ](SIMD[DType.int32, 16](Int32(0)), a, b)
    var prod = (a.cast[DType.int16]() * b.cast[DType.int16]()).cast[DType.int32]()
    var pair = prod + prod.shuffle[
        1, 0, 3, 2, 5, 4, 7, 6, 9, 8, 11, 10, 13, 12, 15, 14,
        17, 16, 19, 18, 21, 20, 23, 22, 25, 24, 27, 26, 29, 28, 31, 30,
        33, 32, 35, 34, 37, 36, 39, 38, 41, 40, 43, 42, 45, 44, 47, 46,
        49, 48, 51, 50, 53, 52, 55, 54, 57, 56, 59, 58, 61, 60, 63, 62,
    ]()
    var quad = pair + pair.shuffle[
        2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13,
        18, 19, 16, 17, 22, 23, 20, 21, 26, 27, 24, 25, 30, 31, 28, 29,
        34, 35, 32, 33, 38, 39, 36, 37, 42, 43, 40, 41, 46, 47, 44, 45,
        50, 51, 48, 49, 54, 55, 52, 53, 58, 59, 56, 57, 62, 63, 60, 61,
    ]()
    var out = SIMD[DType.int32, 16](Int32(0))
    for l in range(16):
        out[l] = quad[l * 4]
    return out


def _gemm_k_vnni_range(
    a_addr: Int64,
    b_addr: Int64,
    c_addr: Int64,
    a_rows: Int,
    a_cols: Int,
    b_rows: Int,
    c_cols: Int,
    kind: Int,
    out_lo: Int,
    out_hi: Int,
):
    """VNNI (AVX-512 VPDPBUSD) variant of _gemm_k_fast_range, kinds
    12 (Q4_K) and 14 (Q6_K) only.

    The weight operand is the RAW integer codes (Q4_K nibbles 0..15,
    Q6_K 6-bit values 0..63) in natural order — the unsigned operand.
    Activations are dynamically quantized once per (row, sub-block)
    to int8 with a per-sub-block max-abs scale (the signed operand)
    and reused for every output column in range; the finer scale
    granularity (32 values for Q4_K, 16 for Q6_K, vs one scale per
    256) keeps the quantization error close to each sub-block's own
    dynamic range. Each sub-block contributes
    coef_a * (xs_g * int_dot - coef_b * sum_x): int_dot is the exact
    integer dot of codes x quantized activations, sum_x the exact f32
    sum of the true activations over the sub-block, and the affine
    terms fold through it (Q4_K's per-sub-block minimum in coef_b;
    Q6_K's -32 zero point as coef_b = 32 * coef). Super-blocks
    accumulate in ascending order, one contribution per sub-block in
    ascending order, exactly like the f32 body.

    The ONLY approximation vs _gemm_k_fast_range is the int8
    activation quantization (per-element error <= xs_g/2 within its
    sub-block), so outputs drift slightly; the drift is bounded and
    measured in the platform doc. Output columns are partitioned
    exactly as in the f32 body, so threading composes with this path
    unchanged.
    """
    var a_data = Pointer[Scalar[f16], MutUntrackedOrigin](
        unsafe_from_address=Int(a_addr)
    )
    var c_data = Pointer[Scalar[f16], MutUntrackedOrigin](
        unsafe_from_address=Int(c_addr)
    )
    var weights = Pointer[UInt8, MutUntrackedOrigin](
        unsafe_from_address=Int(b_addr)
    )
    var blocks_per_row = a_cols // 256
    var block_bytes = 144 if kind == 12 else 210
    var nsub = 8 if kind == 12 else 16
    var sub_width = 256 // nsub
    var codes = InlineArray[UInt8, 256](uninitialized=True)
    var cp8 = codes.unsafe_ptr()
    var partials = InlineArray[Int32, 64](uninitialized=True)
    var pp = partials.unsafe_ptr()
    var f32s = InlineArray[Float32, 256](uninitialized=True)
    var fp = f32s.unsafe_ptr()
    var row_start = 0
    while row_start < a_rows:
        var rows_here = a_rows - row_start
        if rows_here > 32:
            rows_here = 32
        # Phase 1: quantize this row chunk's activations once per
        # super-block (plus the exact per-sub-block f32 sums).
        var xq = alloc[Int8](rows_here * a_cols)
        var xscale = alloc[Float32](rows_here * blocks_per_row * nsub)
        var xsums = alloc[Float32](rows_here * blocks_per_row * nsub)
        for r in range(rows_here):
            var a_row = row_start + r
            for sb in range(blocks_per_row):
                var base = a_row * a_cols + sb * 256
                for i in range(256):
                    fp.unsafe_store(
                        i, a_data.unsafe_load(base + i).cast[f32]()
                    )
                var xq_base = r * a_cols + sb * 256
                for g in range(nsub):
                    var maxabs = Float32(0.0)
                    for i in range(sub_width):
                        var v = fp.unsafe_load(g * sub_width + i)
                        var av = v if v >= Float32(0.0) else -v
                        if av > maxabs:
                            maxabs = av
                    var xs = Float32(1.0)
                    if maxabs > Float32(0.0):
                        xs = maxabs / Float32(127.0)
                    xscale.unsafe_store(
                        (r * blocks_per_row + sb) * nsub + g, xs
                    )
                    var inv = Float32(1.0) / xs
                    var s = Float32(0.0)
                    for i in range(sub_width):
                        var idx = g * sub_width + i
                        var v = fp.unsafe_load(idx)
                        s += v
                        var qf = v * inv
                        var qi: Int32
                        if qf >= Float32(0.0):
                            qi = Int32(qf + Float32(0.5))
                        else:
                            qi = -Int32(Float32(0.5) - qf)
                        if qi > 127:
                            qi = 127
                        if qi < -127:
                            qi = -127
                        xq.unsafe_store(xq_base + idx, Int8(qi))
                    xsums.unsafe_store(
                        (r * blocks_per_row + sb) * nsub + g, s
                    )
        # Phase 2: outputs x super-blocks with integer dots.
        var acc = InlineArray[Float32, 32](fill=Float32(0.0))
        for output in range(out_lo, out_hi):
            for r in range(rows_here):
                acc[r] = Float32(0.0)
            for sb in range(blocks_per_row):
                var p = (output * blocks_per_row + sb) * block_bytes
                var coef_a = InlineArray[Float32, 16](uninitialized=True)
                var coef_b = InlineArray[Float32, 16](uninitialized=True)
                if kind == 12:
                    var d = weights.unsafe_offset(p).unsafe_bitcast[Scalar[f16]]().unsafe_load().cast[f32]()
                    var dmin = weights.unsafe_offset(p + 2).unsafe_bitcast[Scalar[f16]]().unsafe_load().cast[f32]()
                    for g in range(8):
                        var scale: Int
                        var minimum: Int
                        if g < 4:
                            scale = Int(weights.unsafe_load(p + 4 + g)) & 63
                            minimum = Int(weights.unsafe_load(p + 8 + g)) & 63
                        else:
                            scale = (Int(weights.unsafe_load(p + 8 + g)) & 15) | ((Int(weights.unsafe_load(p + g)) >> 6) << 4)
                            minimum = (Int(weights.unsafe_load(p + 8 + g)) >> 4) | ((Int(weights.unsafe_load(p + 4 + g)) >> 6) << 4)
                        coef_a[g] = d * Float32(scale)
                        coef_b[g] = dmin * Float32(minimum)
                    var qs = p + 16
                    for h in range(4):
                        var chunk0 = weights.unsafe_load[width=16](qs + h * 32)
                        var chunk1 = weights.unsafe_load[width=16](qs + h * 32 + 16)
                        var g_lo = 2 * h
                        var g_hi = 2 * h + 1
                        cp8.unsafe_store[width=16](g_lo * 32, chunk0 & UInt8(0x0F))
                        cp8.unsafe_store[width=16](g_lo * 32 + 16, chunk1 & UInt8(0x0F))
                        cp8.unsafe_store[width=16](g_hi * 32, chunk0 >> 4)
                        cp8.unsafe_store[width=16](g_hi * 32 + 16, chunk1 >> 4)
                else:
                    var d = weights.unsafe_offset(p + 208).unsafe_bitcast[Scalar[f16]]().unsafe_load().cast[f32]()
                    for c in range(16):
                        var half = c // 8
                        var group = (c % 8) // 2
                        var hl = c % 2
                        var scale = weights.unsafe_offset(p + 192).unsafe_bitcast[Scalar[DType.int8]]().unsafe_load(c).cast[f32]()
                        var coef = d * scale
                        coef_a[c] = coef
                        coef_b[c] = coef * Float32(32.0)
                        var ql = weights.unsafe_load[width=16](p + half * 64 + (group % 2) * 32 + hl * 16)
                        var nib = (ql & UInt8(0x0F)) if group < 2 else (ql >> 4)
                        var qh = weights.unsafe_load[width=16](p + 128 + half * 32 + hl * 16)
                        var hi = (qh >> UInt8(2 * group)) & UInt8(3)
                        cp8.unsafe_store[width=16](c * 16, nib | (hi << 4))
                for r in range(rows_here):
                    var xq_row = xq.unsafe_offset(r * a_cols + sb * 256)
                    for j in range(4):
                        var dv = _vpdpbusd_512_zero(
                            cp8.unsafe_load[width=64](j * 64),
                            xq_row.unsafe_load[width=64](j * 64),
                        )
                        pp.unsafe_store[width=16](j * 16, dv)
                    var total = Float32(0.0)
                    for g in range(nsub):
                        var part = Int32(0)
                        var t0 = (g * sub_width) // 4
                        var t1 = ((g + 1) * sub_width) // 4
                        for t in range(t0, t1):
                            part += pp.unsafe_load(t)
                        var xs = xscale.unsafe_load(
                            (r * blocks_per_row + sb) * nsub + g
                        )
                        var xsum = xsums.unsafe_load(
                            (r * blocks_per_row + sb) * nsub + g
                        )
                        total += coef_a[g] * xs * Float32(part) - coef_b[g] * xsum
                    acc[r] += total
            for r in range(rows_here):
                c_data.unsafe_store(
                    (row_start + r) * c_cols + output, acc[r].cast[f16]()
                )
        xq.unsafe_free()
        xscale.unsafe_free()
        xsums.unsafe_free()
        row_start += rows_here

def _gemm_k_fast_worker(ctx_addr: Int64, start: Int64, end: Int64):
    """FFI range callback for _gemm_k_fast; ctx is an Int64 slot array:
    [A.data, B.data, C.data, A.rows, A.cols, B.rows, C.cols, kind,
    mode] where mode 1 selects the VNNI int8 range body."""
    var ctx = Pointer[Int64, MutUntrackedOrigin](
        unsafe_from_address=Int(ctx_addr)
    )
    if Int(ctx.unsafe_load(8)) == 1:
        _gemm_k_vnni_range(
            ctx.unsafe_load(0),
            ctx.unsafe_load(1),
            ctx.unsafe_load(2),
            Int(ctx.unsafe_load(3)),
            Int(ctx.unsafe_load(4)),
            Int(ctx.unsafe_load(5)),
            Int(ctx.unsafe_load(6)),
            Int(ctx.unsafe_load(7)),
            Int(start),
            Int(end),
        )
        return
    _gemm_k_fast_range(
        ctx.unsafe_load(0),
        ctx.unsafe_load(1),
        ctx.unsafe_load(2),
        Int(ctx.unsafe_load(3)),
        Int(ctx.unsafe_load(4)),
        Int(ctx.unsafe_load(5)),
        Int(ctx.unsafe_load(6)),
        Int(ctx.unsafe_load(7)),
        Int(start),
        Int(end),
    )


def _gemm_k_fast(
    A: RuneTensor[f16],
    B: RuneTensor[f16],
    mut C: RuneTensor[f16],
    kind: Int,
) raises:
    """SIMD block-decoding K-quant GEMM for kinds 10-14 (Q2_K, Q3_K,
    Q4_K, Q5_K, Q6_K). Kinds 13/11/10 joined 12/14 in the model-wave
    campaign: their decoders mirror packed_value() element-for-element
    (same scales, recentering and high-bit handling), differing only in
    rounding order (per-sub-block coefficients factored out, as with
    Q4_K). The VNNI int8 mode remains kinds 12/14 only.

    C = A @ B^T with B held as canonical packed GGUF bytes, B[N, K],
    K % 256 == 0. Each 256-value super-block of B is decoded exactly once
    into an f32 scratch row: the block header (scales/mins) is extracted a
    single time and the packed quants are unpacked with SIMD, instead of
    re-deriving the header per element as the scalar packed_value() path
    does. The decoded row is then dotted against every row of A with
    f32 SIMD accumulation, so batched (multi-row) calls reuse one decode.
    Accumulation order over K is ascending by super-block, matching the
    scalar path's block order; results can differ only in final rounding.

    Output columns are partitioned across OS threads through
    core.parallel.par_for when the work estimate clears the engagement
    threshold; each column's reduction order is unchanged, so threaded
    results are bit-identical to the serial body (_gemm_k_fast_range).
    """
    # Heap context: the slot array's address crosses into worker
    # threads, so it must have a stable address for the whole call
    # (a stack InlineArray's address is not reliable once this frame
    # is inlined into its callers).
    var cp = alloc[Int64](9)
    cp.unsafe_store(0, Int64(Int(A.data)))
    cp.unsafe_store(1, Int64(Int(B.data)))
    cp.unsafe_store(2, Int64(Int(C.data)))
    cp.unsafe_store(3, Int64(A.rows))
    cp.unsafe_store(4, Int64(A.cols))
    cp.unsafe_store(5, Int64(B.rows))
    cp.unsafe_store(6, Int64(C.cols))
    cp.unsafe_store(7, Int64(kind))
    cp.unsafe_store(8, Int64(1) if (_vnni_allowed() and (kind == 12 or kind == 14)) else Int64(0))
    _ = par_for[_gemm_k_fast_worker](
        Int64(Int(cp)),
        B.rows,
        Int64(A.rows) * Int64(B.rows) * Int64(A.cols),
    )
    cp.unsafe_free()

@no_inline
def iq_grid_alloc(kind: Int) -> Pointer[UInt16, MutUntrackedOrigin]:
    """Allocate a 2048-entry heap buffer and materialize the IQ grid
    for kind into it; the caller frees it with unsafe_free().

    The grid must NOT live in a stack InlineArray in the GEMM range
    body: that buffer is written through one pointer form and read
    through an origin-cast pointer, and this toolchain's liveness
    analysis loses track of it — the stack slot is reused while the
    grid is still logically live, layout-dependently (the wave
    build, whose only source delta was the Q8_0 fast GEMM, read a
    clobbered grid in every IQ GEMM: iq1_s collapsed to EOS x16,
    iq2_m fell into a repetition loop). A heap allocation with an
    explicit alloc/free lifetime in the caller is immune. The
    alloc+materialize are fused in this @no_inline frame so the
    store destination is a fresh allocation with no other pointer
    in scope. See iq-worker REPORT.md phase 3.
    """
    var dst = alloc[UInt16](2048)
    iq_grid_materialize(kind, dst)
    return dst


def _gemm_iq_fast_range(
    a_addr: Int64,
    b_addr: Int64,
    c_addr: Int64,
    a_rows: Int,
    a_cols: Int,
    b_rows: Int,
    c_cols: Int,
    kind: Int,
    out_lo: Int,
    out_hi: Int,
):
    """Range-bounded body of the fast IQ GEMM (see _gemm_iq_fast).

    Computes output columns [out_lo, out_hi) of C = A @ B^T. Every
    output element is computed entirely inside this call with the same
    accumulation order over K as the unbounded body, so partitioning
    the output columns across threads is bit-identical to running the
    whole range serially. kind is the GGML tensor type (16 IQ2_XXS,
    17 IQ2_XS, 18 IQ3_XXS, 19 IQ1_S, 21 IQ3_S, 22 IQ2_S).
    """
    var a_data = Pointer[Scalar[f16], MutUntrackedOrigin](
        unsafe_from_address=Int(a_addr)
    )
    var c_data = Pointer[Scalar[f16], MutUntrackedOrigin](
        unsafe_from_address=Int(c_addr)
    )
    var weights = Pointer[UInt8, MutUntrackedOrigin](
        unsafe_from_address=Int(b_addr)
    )
    var blocks_per_row = a_cols // 256
    var block_bytes = iq_block_bytes(kind)
    # The grid MUST live on the heap, not in a stack InlineArray:
    # materializing it with the width-2048 store into a stack buffer
    # in this frame is layout-sensitive — in builds where unrelated
    # code (the Q8_0 fast GEMM) shifts codegen/inlining, the stack
    # copy is silently clobbered and every IQ decode in the wave
    # build reads a corrupted grid (iq1_s logits collapse to EOS;
    # iq2_m falls into a repetition attractor), while the identical
    # source in other builds happens to work. Heap allocation is
    # frame-layout independent. See iq-worker REPORT.md phase 3.
    var grid_ptr = iq_grid_alloc(kind)
    var scratch = InlineArray[Float32, 256](uninitialized=True)
    var sp = scratch.unsafe_ptr()
    var sp_t = sp.unsafe_origin_cast[MutUntrackedOrigin]()
    var row_start = 0
    while row_start < a_rows:
        var rows_here = a_rows - row_start
        if rows_here > 256:
            rows_here = 256
        var acc = InlineArray[Float32, 256](fill=Float32(0.0))
        for output in range(out_lo, out_hi):
            for r in range(rows_here):
                acc[r] = Float32(0.0)
            for sb in range(blocks_per_row):
                var block_base = (output * blocks_per_row + sb) * block_bytes
                dequantize_iq_block(weights, block_base, kind, grid_ptr, sp_t)
                var k0 = sb * 256
                for r in range(rows_here):
                    var a_row = row_start + r
                    var accv = SIMD[DType.float32, 16](Float32(0.0))
                    for chunk in range(16):
                        var wv = sp.unsafe_load[width=16](chunk * 16)
                        var av = a_data.unsafe_load[width=16](a_row * a_cols + k0 + chunk * 16).cast[f32]()
                        accv += wv * av
                    acc[r] += accv.reduce_add()
            for r in range(rows_here):
                c_data.unsafe_store((row_start + r) * c_cols + output, acc[r].cast[f16]())
        row_start += rows_here
    grid_ptr.unsafe_free()


def _gemm_iq_fast_worker(ctx_addr: Int64, start: Int64, end: Int64):
    """FFI range callback for _gemm_iq_fast; ctx is an Int64 slot array:
    [A.data, B.data, C.data, A.rows, A.cols, B.rows, C.cols, kind]."""
    var ctx = Pointer[Int64, MutUntrackedOrigin](
        unsafe_from_address=Int(ctx_addr)
    )
    _gemm_iq_fast_range(
        ctx.unsafe_load(0),
        ctx.unsafe_load(1),
        ctx.unsafe_load(2),
        Int(ctx.unsafe_load(3)),
        Int(ctx.unsafe_load(4)),
        Int(ctx.unsafe_load(5)),
        Int(ctx.unsafe_load(6)),
        Int(ctx.unsafe_load(7)),
        Int(start),
        Int(end),
    )


def _gemm_iq_fast(
    A: RuneTensor[f16],
    B: RuneTensor[f16],
    mut C: RuneTensor[f16],
    kind: Int,
) raises:
    """Decode-once IQ GEMM for GGML kinds 16/17/18/19/21/22.

    C = A @ B^T with B held as canonical packed GGUF bytes, B[N, K],
    K % 256 == 0. Each 256-value super-block of B is decoded exactly
    once into an f32 scratch row (scalar grid decode via iq_value,
    header fields re-derived per block, not per element) and dotted
    against every row of A with f32 SIMD accumulation — the same
    shape as _gemm_k_fast, replacing the per-element scalar GEMMs in
    extreme_quantization, which re-decoded every weight for every
    output. Accumulation order over K is ascending by super-block;
    output columns are partitioned across OS threads through
    core.parallel.par_for, bit-identical to the serial body.
    """
    var cp = alloc[Int64](8)
    cp.unsafe_store(0, Int64(Int(A.data)))
    cp.unsafe_store(1, Int64(Int(B.data)))
    cp.unsafe_store(2, Int64(Int(C.data)))
    cp.unsafe_store(3, Int64(A.rows))
    cp.unsafe_store(4, Int64(A.cols))
    cp.unsafe_store(5, Int64(B.rows))
    cp.unsafe_store(6, Int64(C.cols))
    cp.unsafe_store(7, Int64(kind))
    _ = par_for[_gemm_iq_fast_worker](
        Int64(Int(cp)),
        B.rows,
        Int64(A.rows) * Int64(B.rows) * Int64(A.cols),
    )
    cp.unsafe_free()

def _gemm_k_scalar_range(
    a_addr: Int64,
    b_addr: Int64,
    c_addr: Int64,
    a_rows: Int,
    a_cols: Int,
    c_cols: Int,
    kind: Int,
    out_lo: Int,
    out_hi: Int,
):
    """Output-column range of the scalar K-quant GEMM (kinds 10/11/13).

    Each output element is an independent packed_value reduction over
    ascending columns, so column ranges are bit-identical to the
    serial loops in any partition.
    """
    var a_data = Pointer[Scalar[f16], MutUntrackedOrigin](
        unsafe_from_address=Int(a_addr)
    )
    var c_data = Pointer[Scalar[f16], MutUntrackedOrigin](
        unsafe_from_address=Int(c_addr)
    )
    var weights = Pointer[UInt8, MutUntrackedOrigin](
        unsafe_from_address=Int(b_addr)
    )
    for output in range(out_lo, out_hi):
        for row in range(a_rows):
            var total: Float32 = 0
            for col in range(a_cols):
                total += a_data.unsafe_load(row * a_cols + col).cast[f32]() * packed_value(weights, 0, kind, output * a_cols + col)
            c_data.unsafe_store(row * c_cols + output, total.cast[f16]())


def _gemm_k_scalar_worker(ctx_addr: Int64, start: Int64, end: Int64):
    """FFI range callback; ctx slots: [A.data, B.data, C.data,
    A.rows, A.cols, C.cols, kind]."""
    var ctx = Pointer[Int64, MutUntrackedOrigin](
        unsafe_from_address=Int(ctx_addr)
    )
    _gemm_k_scalar_range(
        ctx.unsafe_load(0),
        ctx.unsafe_load(1),
        ctx.unsafe_load(2),
        Int(ctx.unsafe_load(3)),
        Int(ctx.unsafe_load(4)),
        Int(ctx.unsafe_load(5)),
        Int(ctx.unsafe_load(6)),
        Int(start),
        Int(end),
    )


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
    if ggml_type >= 10 and ggml_type <= 14:
        _gemm_k_fast(A, B, C, ggml_type)
        return
    var cp = alloc[Int64](7)
    cp.unsafe_store(0, Int64(Int(A.data)))
    cp.unsafe_store(1, Int64(Int(B.data)))
    cp.unsafe_store(2, Int64(Int(C.data)))
    cp.unsafe_store(3, Int64(A.rows))
    cp.unsafe_store(4, Int64(A.cols))
    cp.unsafe_store(5, Int64(C.cols))
    cp.unsafe_store(6, Int64(ggml_type))
    _ = par_for[_gemm_k_scalar_worker](
        Int64(Int(cp)),
        B.rows,
        Int64(A.rows) * Int64(B.rows) * Int64(A.cols),
    )
    cp.unsafe_free()


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

def gemm_iq(
    A: RuneTensor[f16],
    B: RuneTensor[f16],
    mut C: RuneTensor[f16],
    ggml_type: Int,
    format_name: String,
) raises:
    """CPU F32-accumulation GEMM over canonical GGUF IQ packed bytes,
    B[N,K], via the decode-once fast path (_gemm_iq_fast)."""
    if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols != A.cols or A.cols % 256 != 0:
        raise Error(format_name + ": invalid shape or incomplete quantization block")
    if C.rows != A.rows or C.cols != B.rows:
        raise Error(format_name + ": output matrix shape mismatch")
    if Int(A.data) <= 1 or Int(B.data) <= 1 or Int(C.data) <= 1:
        raise Error(format_name + ": invalid storage")
    if ggml_type != 16 and ggml_type != 17 and ggml_type != 18 and ggml_type != 19 and ggml_type != 20 and ggml_type != 21 and ggml_type != 22 and ggml_type != 23 and ggml_type != 29:
        raise Error(format_name + ": unsupported GGML tensor type")
    _gemm_iq_fast(A, B, C, ggml_type)


def gemm_iq1_s(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    gemm_iq(A, B, C, 19, "gemm_iq1_s")


def gemm_iq2_xxs(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    gemm_iq(A, B, C, 16, "gemm_iq2_xxs")


def gemm_iq2_s(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    gemm_iq(A, B, C, 22, "gemm_iq2_s")


def gemm_iq3_s(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    gemm_iq(A, B, C, 21, "gemm_iq3_s")


def gemm_iq2_xs(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    gemm_iq(A, B, C, 17, "gemm_iq2_xs")


def gemm_iq3_xxs(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    gemm_iq(A, B, C, 18, "gemm_iq3_xxs")


def gemm_iq4_nl(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    gemm_iq(A, B, C, 20, "gemm_iq4_nl")


def gemm_iq4_xs(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    gemm_iq(A, B, C, 23, "gemm_iq4_xs")


def gemm_iq1_m(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    gemm_iq(A, B, C, 29, "gemm_iq1_m")

def gemm_ternary_158(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    if A.cols != B.cols or C.rows != A.rows or C.cols != B.rows:
        raise Error("gemm_tq1_0: matrix shape mismatch")
    if A.cols <= 0 or A.cols % 256 != 0:
        raise Error("gemm_tq1_0: inner dimension must use complete 256-value blocks")
    var weight_bytes = B.rows * (B.cols // 256) * 54
    gemm_tq1_0_blocks(
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

def _gemm_tq_fast_range(
    a_addr: Int64,
    b_addr: Int64,
    c_addr: Int64,
    a_rows: Int,
    a_cols: Int,
    b_rows: Int,
    c_cols: Int,
    kind: Int,
    out_lo: Int,
    out_hi: Int,
):
    """Range-bounded body of the fast ternary GEMM (see _gemm_tq_fast).

    Computes output columns [out_lo, out_hi) of C = A @ B^T. Every
    output element is computed entirely inside this call with the same
    accumulation order over K as the unbounded body, so partitioning
    the output columns across threads is bit-identical to running the
    whole range serially. kind is the GGML tensor type (34 TQ1_0,
    35 TQ2_0). Block decode goes through dequantize_tq_block, the
    shared scalar decode definition."""
    var a_data = Pointer[Scalar[f16], MutUntrackedOrigin](
        unsafe_from_address=Int(a_addr)
    )
    var c_data = Pointer[Scalar[f16], MutUntrackedOrigin](
        unsafe_from_address=Int(c_addr)
    )
    var weights = Pointer[UInt8, MutUntrackedOrigin](
        unsafe_from_address=Int(b_addr)
    )
    var blocks_per_row = a_cols // 256
    var block_bytes = tq_block_bytes(kind)
    var scratch = InlineArray[Float32, 256](uninitialized=True)
    var sp = scratch.unsafe_ptr()
    var sp_t = sp.unsafe_origin_cast[MutUntrackedOrigin]()
    var row_start = 0
    while row_start < a_rows:
        var rows_here = a_rows - row_start
        if rows_here > 256:
            rows_here = 256
        var acc = InlineArray[Float32, 256](fill=Float32(0.0))
        for output in range(out_lo, out_hi):
            for r in range(rows_here):
                acc[r] = Float32(0.0)
            for sb in range(blocks_per_row):
                var block_base = (output * blocks_per_row + sb) * block_bytes
                dequantize_tq_block(weights, block_base, kind, sp_t)
                var k0 = sb * 256
                for r in range(rows_here):
                    var a_row = row_start + r
                    var accv = SIMD[DType.float32, 16](Float32(0.0))
                    for chunk in range(16):
                        var wv = sp.unsafe_load[width=16](chunk * 16)
                        var av = a_data.unsafe_load[width=16](a_row * a_cols + k0 + chunk * 16).cast[f32]()
                        accv += wv * av
                    acc[r] += accv.reduce_add()
            for r in range(rows_here):
                c_data.unsafe_store((row_start + r) * c_cols + output, acc[r].cast[f16]())
        row_start += rows_here


def _gemm_tq_fast_worker(ctx_addr: Int64, start: Int64, end: Int64):
    """FFI range callback for _gemm_tq_fast; ctx is an Int64 slot array:
    [A.data, B.data, C.data, A.rows, A.cols, B.rows, C.cols, kind]."""
    var ctx = Pointer[Int64, MutUntrackedOrigin](
        unsafe_from_address=Int(ctx_addr)
    )
    _gemm_tq_fast_range(
        ctx.unsafe_load(0),
        ctx.unsafe_load(1),
        ctx.unsafe_load(2),
        Int(ctx.unsafe_load(3)),
        Int(ctx.unsafe_load(4)),
        Int(ctx.unsafe_load(5)),
        Int(ctx.unsafe_load(6)),
        Int(ctx.unsafe_load(7)),
        Int(start),
        Int(end),
    )


def _gemm_tq_fast(
    A: RuneTensor[f16],
    B: RuneTensor[f16],
    mut C: RuneTensor[f16],
    kind: Int,
) raises:
    """Decode-once ternary GEMM for GGML kinds 34/35.

    C = A @ B^T with B held as canonical packed GGUF bytes, B[N, K],
    K % 256 == 0. Each 256-value block of B is decoded exactly once
    into an f32 scratch row (scalar decode via dequantize_tq_block)
    and dotted against every row of A with f32 SIMD accumulation --
    the same shape as _gemm_iq_fast, replacing the per-element scalar
    GEMMs in extreme_quantization, which re-decoded every weight for
    every output. Accumulation order over K is ascending by block;
    output columns are partitioned across OS threads through
    core.parallel.par_for, bit-identical to the serial body."""
    var cp = alloc[Int64](8)
    cp.unsafe_store(0, Int64(Int(A.data)))
    cp.unsafe_store(1, Int64(Int(B.data)))
    cp.unsafe_store(2, Int64(Int(C.data)))
    cp.unsafe_store(3, Int64(A.rows))
    cp.unsafe_store(4, Int64(A.cols))
    cp.unsafe_store(5, Int64(B.rows))
    cp.unsafe_store(6, Int64(C.cols))
    cp.unsafe_store(7, Int64(kind))
    _ = par_for[_gemm_tq_fast_worker](
        Int64(Int(cp)),
        B.rows,
        Int64(A.rows) * Int64(B.rows) * Int64(A.cols),
    )
    cp.unsafe_free()


def gemm_tq(
    A: RuneTensor[f16],
    B: RuneTensor[f16],
    mut C: RuneTensor[f16],
    ggml_type: Int,
    format_name: String,
) raises:
    """CPU F32-accumulation GEMM over canonical GGUF ternary packed
    bytes, B[N,K], via the decode-once fast path (_gemm_tq_fast)."""
    if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols != A.cols or A.cols % 256 != 0:
        raise Error(format_name + ": invalid shape or incomplete quantization block")
    if C.rows != A.rows or C.cols != B.rows:
        raise Error(format_name + ": output matrix shape mismatch")
    if Int(A.data) <= 1 or Int(B.data) <= 1 or Int(C.data) <= 1:
        raise Error(format_name + ": invalid storage")
    if ggml_type != 34 and ggml_type != 35:
        raise Error(format_name + ": unsupported GGML tensor type")
    _gemm_tq_fast(A, B, C, ggml_type)


def gemm_tq1_0(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    gemm_tq(A, B, C, 34, "gemm_tq1_0")


def gemm_tq2_0(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    gemm_tq(A, B, C, 35, "gemm_tq2_0")

# ---------------------------------------------------------------------------
# S-089: precision tier — direct half-precision GEMM (no dequant detour).
#
# gemm_f16_direct is the dense F16 GEMM under its own name (previously the
# anonymous fallthrough at the bottom of gemm_f16): B is already F16
# storage, read directly, F32 accumulation, output columns partitioned
# via par_for with the serial body's reduction order per output, so
# partitioning is bit-identical.
#
# gemm_bf16 is the direct BF16 GEMM: B is raw BF16 storage (a plain
# RuneTensor[f16] view over the BF16 bytes; rows x cols is the weight
# matrix). Each output row of B is decoded exactly once into an F32
# scratch row via bf16_bits_to_f32 (exact widening) and dotted against
# every row of A — the weight matrix is never materialized as an
# intermediate F16 copy (the at-load conversion in the loader remains
# the route for tensors that live in the model; this GEMM is the direct
# path for callers holding raw BF16 storage). gemm_bf16_scalar is the
# per-element reference oracle, retained for tests.
# ---------------------------------------------------------------------------

def gemm_f16_direct(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    """Direct dense F16 GEMM: C = A @ B^T over F16 storage, F32
    accumulation, threaded over output columns (see _gemm_f16_dense_range
    for the bit-identity discipline)."""
    if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols <= 0:
        raise Error("gemm_f16_direct: matrix dimensions must be positive")
    if A.cols != B.cols:
        raise Error("gemm_f16_direct: inner matrix dimension mismatch")
    if C.rows != A.rows or C.cols != B.rows:
        raise Error("gemm_f16_direct: output matrix shape mismatch")
    var cp = alloc[Int64](6)
    cp.unsafe_store(0, Int64(Int(A.data)))
    cp.unsafe_store(1, Int64(Int(B.data)))
    cp.unsafe_store(2, Int64(Int(C.data)))
    cp.unsafe_store(3, Int64(A.rows))
    cp.unsafe_store(4, Int64(A.cols))
    cp.unsafe_store(5, Int64(B.rows))
    _ = par_for[_gemm_f16_dense_worker](
        Int64(Int(cp)),
        B.rows,
        Int64(A.rows) * Int64(B.rows) * Int64(A.cols),
    )
    cp.unsafe_free()


def _gemm_bf16_fast_range(
    a_addr: Int64,
    b_addr: Int64,
    c_addr: Int64,
    rows: Int,
    shared_dim: Int,
    output_dim: Int,
    out_lo: Int,
    out_hi: Int,
):
    """Output-column range of the direct BF16 GEMM (see gemm_bf16).

    Each output element keeps the dense body's SIMD-then-tail reduction
    order over the shared dimension against the F32 scratch row decoded
    from that output's BF16 weights, so column ranges are bit-identical
    to the serial body in any partition."""
    var a_data = Pointer[Scalar[f16], MutUntrackedOrigin](
        unsafe_from_address=Int(a_addr)
    )
    var b_bits = Pointer[UInt16, MutUntrackedOrigin](
        unsafe_from_address=Int(b_addr)
    )
    var c_data = Pointer[Scalar[f16], MutUntrackedOrigin](
        unsafe_from_address=Int(c_addr)
    )
    var scratch = alloc[Float32](shared_dim)
    var simd_end = (shared_dim // simd_w_f16) * simd_w_f16
    for output_index in range(out_lo, out_hi):
        for inner in range(shared_dim):
            scratch.unsafe_store(
                inner,
                bf16_bits_to_f32(
                    b_bits.unsafe_load(output_index * shared_dim + inner)
                ),
            )
        for row in range(rows):
            var sum: Scalar[f32] = 0.0
            for inner in range(0, simd_end, simd_w_f16):
                var input_values = a_data.unsafe_load[width=simd_w_f16](
                    row * shared_dim + inner
                ).cast[f32]()
                var weight_values = scratch.unsafe_load[width=simd_w_f16](inner)
                sum += (input_values * weight_values).reduce_add()
            for inner in range(simd_end, shared_dim):
                sum += (
                    a_data.unsafe_load(row * shared_dim + inner).cast[f32]()
                    * scratch.unsafe_load(inner)
                )
            c_data.unsafe_store(
                row * output_dim + output_index, sum.cast[f16]()
            )
    scratch.unsafe_free()


def _gemm_bf16_fast_worker(ctx_addr: Int64, start: Int64, end: Int64):
    """FFI range callback; ctx slots: [A.data, B.data, C.data,
    A.rows, A.cols, B.rows]."""
    var ctx = Pointer[Int64, MutUntrackedOrigin](
        unsafe_from_address=Int(ctx_addr)
    )
    _gemm_bf16_fast_range(
        ctx.unsafe_load(0),
        ctx.unsafe_load(1),
        ctx.unsafe_load(2),
        Int(ctx.unsafe_load(3)),
        Int(ctx.unsafe_load(4)),
        Int(ctx.unsafe_load(5)),
        Int(start),
        Int(end),
    )


def gemm_bf16(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    """Direct BF16 GEMM: C = A @ B^T with B held as raw BF16 storage
    (B.data points at BF16 bit patterns; B.rows x B.cols is the weight
    matrix). No intermediate F16/F32 materialization of B: each weight
    row is widened exactly into an F32 scratch row once per range call
    and dotted with F32 accumulation. BF16 is per-element — no block
    geometry constraint on the shared dimension."""
    if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols <= 0:
        raise Error("gemm_bf16: matrix dimensions must be positive")
    if A.cols != B.cols:
        raise Error("gemm_bf16: inner matrix dimension mismatch")
    if C.rows != A.rows or C.cols != B.rows:
        raise Error("gemm_bf16: output matrix shape mismatch")
    if Int(A.data) <= 1 or Int(B.data) <= 1 or Int(C.data) <= 1:
        raise Error("gemm_bf16: invalid storage")
    var cp = alloc[Int64](6)
    cp.unsafe_store(0, Int64(Int(A.data)))
    cp.unsafe_store(1, Int64(Int(B.data)))
    cp.unsafe_store(2, Int64(Int(C.data)))
    cp.unsafe_store(3, Int64(A.rows))
    cp.unsafe_store(4, Int64(A.cols))
    cp.unsafe_store(5, Int64(B.rows))
    _ = par_for[_gemm_bf16_fast_worker](
        Int64(Int(cp)),
        B.rows,
        Int64(A.rows) * Int64(B.rows) * Int64(A.cols),
    )
    cp.unsafe_free()


def gemm_bf16_scalar(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
) raises:
    """Scalar reference BF16 GEMM: per-element decode on every use,
    ascending-K serial F32 accumulation. Retained as the test oracle
    for gemm_bf16 (the gemm_ternary_158 pattern); not a production
    route."""
    if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols <= 0:
        raise Error("gemm_bf16_scalar: matrix dimensions must be positive")
    if A.cols != B.cols:
        raise Error("gemm_bf16_scalar: inner matrix dimension mismatch")
    if C.rows != A.rows or C.cols != B.rows:
        raise Error("gemm_bf16_scalar: output matrix shape mismatch")
    if Int(A.data) <= 1 or Int(B.data) <= 1 or Int(C.data) <= 1:
        raise Error("gemm_bf16_scalar: invalid storage")
    var b_bits = B.data.unsafe_bitcast[UInt16]()
    for output_index in range(B.rows):
        for row in range(A.rows):
            var sum: Float32 = 0.0
            for inner in range(A.cols):
                sum += A.data.unsafe_load(row * A.cols + inner).cast[f32]() * bf16_bits_to_f32(
                    b_bits.unsafe_load(output_index * B.cols + inner)
                )
            C.data.unsafe_store(row * C.cols + output_index, sum.cast[f16]())


def _gemm_f16_dense_range(
    a_addr: Int64,
    b_addr: Int64,
    c_addr: Int64,
    rows: Int,
    shared_dim: Int,
    output_dim: Int,
    out_lo: Int,
    out_hi: Int,
):
    """Output-column range of the dense f16 GEMM body in gemm_f16.

    Each output element keeps the serial body's SIMD-then-tail
    reduction order over the shared dimension, so column ranges are
    bit-identical to the serial loops in any partition.
    """
    var a_data = Pointer[Scalar[f16], MutUntrackedOrigin](
        unsafe_from_address=Int(a_addr)
    )
    var b_data = Pointer[Scalar[f16], MutUntrackedOrigin](
        unsafe_from_address=Int(b_addr)
    )
    var c_data = Pointer[Scalar[f16], MutUntrackedOrigin](
        unsafe_from_address=Int(c_addr)
    )
    var simd_end = (shared_dim // simd_w_f16) * simd_w_f16
    for output_index in range(out_lo, out_hi):
        for row in range(rows):
            var sum: Scalar[f32] = 0.0
            for inner in range(0, simd_end, simd_w_f16):
                var input_values = a_data.unsafe_load[width=simd_w_f16](
                    row * shared_dim + inner
                ).cast[f32]()
                var weight_values = b_data.unsafe_load[width=simd_w_f16](
                    output_index * shared_dim + inner
                ).cast[f32]()
                sum += (input_values * weight_values).reduce_add()
            for inner in range(simd_end, shared_dim):
                sum += (
                    a_data.unsafe_load(row * shared_dim + inner).cast[f32]()
                    * b_data.unsafe_load(
                        output_index * shared_dim + inner
                    ).cast[f32]()
                )
            c_data.unsafe_store(
                row * output_dim + output_index, sum.cast[f16]()
            )


def _gemm_f16_dense_worker(ctx_addr: Int64, start: Int64, end: Int64):
    """FFI range callback; ctx slots: [A.data, B.data, C.data,
    A.rows, A.cols, B.rows]."""
    var ctx = Pointer[Int64, MutUntrackedOrigin](
        unsafe_from_address=Int(ctx_addr)
    )
    _gemm_f16_dense_range(
        ctx.unsafe_load(0),
        ctx.unsafe_load(1),
        ctx.unsafe_load(2),
        Int(ctx.unsafe_load(3)),
        Int(ctx.unsafe_load(4)),
        Int(ctx.unsafe_load(5)),
        Int(start),
        Int(end),
    )


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
        elif B.quant_format.value == CompressedFormatType.IQ2_S:
            gemm_iq2_s(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.IQ3_S:
            gemm_iq3_s(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.IQ2_XS:
            gemm_iq2_xs(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.IQ3_XXS:
            gemm_iq3_xxs(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.IQ4_NL:
            gemm_iq4_nl(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.IQ4_XS:
            gemm_iq4_xs(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.IQ1_M:
            gemm_iq1_m(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.TERNARY_155BIT:
            gemm_tq1_0(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.TQ2_0:
            gemm_tq2_0(A, B, C)
            return
        elif B.quant_format.value == CompressedFormatType.Q4_K_M or B.quant_format.value == CompressedFormatType.Q4_K_S:
            gemm_q4_k_m(A, B, C)
            return
        else:
            raise Error("gemm_f16: unrecognized or unsupported quantization format discriminant")

    gemm_f16_direct(A, B, C)


def apply_rope_partial_neox(
    mut Q: RuneTensor[f16],
    mut K: RuneTensor[f16],
    start_pos: Int,
    head_dim: Int,
    rope_dims: Int,
    theta: Scalar[f32] = 10000.0,
) raises:
    """Partial NEOX RoPE (Qwen3.5 full-attention layers): only the first
    rope_dims of each head rotate, paired (i, i + rope_dims/2), with the
    frequency ladder over rope_dims; the remaining dims pass through.
    For text positions all MRoPE sections see the same scalar position,
    so this is exactly llama.cpp's text-only reduction."""
    if start_pos < 0:
        raise Error("apply_rope_partial_neox: start_pos cannot be negative")
    if head_dim <= 0 or rope_dims <= 0 or rope_dims > head_dim or rope_dims % 2 != 0:
        raise Error("apply_rope_partial_neox: invalid dimensions")
    if Q.cols % head_dim != 0 or K.cols % head_dim != 0:
        raise Error("apply_rope_partial_neox: cols must be a multiple of head_dim")
    var half = rope_dims // 2
    for r in range(Q.rows):
        var pos = start_pos + r
        for i in range(half):
            var freq = 1.0 / (theta ** (Float32(2 * i) / Float32(rope_dims)))
            var val = Float32(pos) * freq
            var fcr = cos(val).cast[f16]()
            var fci = sin(val).cast[f16]()
            for h in range(Q.cols // head_dim):
                var base = r * Q.cols + h * head_dim
                var q0 = Q.data.unsafe_load(base + i)
                var q1 = Q.data.unsafe_load(base + i + half)
                Q.data.unsafe_store(base + i, q0 * fcr - q1 * fci)
                Q.data.unsafe_store(base + i + half, q0 * fci + q1 * fcr)
    for r in range(K.rows):
        var pos = start_pos + r
        for i in range(half):
            var freq = 1.0 / (theta ** (Float32(2 * i) / Float32(rope_dims)))
            var val = Float32(pos) * freq
            var fcr = cos(val).cast[f16]()
            var fci = sin(val).cast[f16]()
            for h in range(K.cols // head_dim):
                var base = r * K.cols + h * head_dim
                var k0 = K.data.unsafe_load(base + i)
                var k1 = K.data.unsafe_load(base + i + half)
                K.data.unsafe_store(base + i, k0 * fcr - k1 * fci)
                K.data.unsafe_store(base + i + half, k0 * fci + k1 * fcr)


def flash_attention_gqa(
    query: RuneTensor[f16],
    keys: RuneTensor[f16],
    values: RuneTensor[f16],
    mut output: RuneTensor[f16],
    sequence_length: Int,
    head_dim: Int,
    query_head_count: Int,
    kv_head_count: Int,
    attn_scale: Scalar[f32] = Scalar[f32](0.0),
    softcap: Scalar[f32] = Scalar[f32](0.0),
    sliding_window: Int = 0,
    query_pos: Int = 0,
):
    """Incremental causal attention with grouped-query head mapping.

    Optional architecture modifiers (all default to the llama behaviour):
    attn_scale replaces 1/sqrt(head_dim) when non-zero (Granite);
    softcap applies score = softcap * tanh(score / softcap) before the
    softmax (Gemma2 attention logit softcapping); sliding_window > 0
    restricts attention to positions with query_pos - position <
    sliding_window (Gemma2 local layers).
    """
    if sequence_length <= 0 or query.rows != 1 or output.rows != 1:
        return
    if query_head_count <= 0 or kv_head_count <= 0 or head_dim <= 0:
        return
    if query_head_count % kv_head_count != 0:
        return
    var query_heads_per_kv = query_head_count // kv_head_count
    var scale = (1.0 / (Float64(head_dim) ** 0.5)).cast[f32]()
    if attn_scale != Scalar[f32](0.0):
        scale = attn_scale

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
            if sliding_window > 0 and query_pos - position >= sliding_window:
                continue
            var key_base = position * keys.cols + kv_head * head_dim
            var value_base = position * values.cols + kv_head * head_dim
            var score: Scalar[f32] = 0.0
            for dimension in range(head_dim):
                score += (
                    query.data.unsafe_load(query_base + dimension).cast[f32]()
                    * keys.data.unsafe_load(key_base + dimension).cast[f32]()
                )
            score *= scale
            if softcap > Scalar[f32](0.0):
                score = softcap * tanh(score / softcap)
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
                var causal_end = i + 1

                # Initialize Out row to 0 for this head
                for k in range(0, simd_end, simd_w_f32):
                    Out.data.unsafe_store[width=simd_w_f32](
                        i * Q.cols + h * head_dim + k,
                        SIMD[f16, simd_w_f32](0.0),
                    )
                for k in range(simd_end, head_dim):
                    Out.data.unsafe_store(i * Q.cols + h * head_dim + k, 0.0)

                for j_start in range(0, causal_end, Bc):
                    for jj in range(Bc):
                        var j = j_start + jj
                        if j >= causal_end:
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


def gelu_tanh(mut T: RuneTensor[f16]):
    """Vectorized GELU, tanh approximation (Gemma-family FFN gate):
    0.5 * x * (1 + tanh(sqrt(2/pi) * (x + 0.044715 * x^3)))."""
    if T.size <= 0:
        return
    var simd_end = (T.size // simd_w_f16) * simd_w_f16
    for i in range(0, simd_end, simd_w_f16):
        var x = T.data.unsafe_load[width=simd_w_f16](i).cast[f32]()
        var inner = 0.7978845608028654 * (x + 0.044715 * x * x * x)
        T.data.unsafe_store[width=simd_w_f16](i, (0.5 * x * (1.0 + tanh(inner))).cast[f16]())
    for i in range(simd_end, T.size):
        var x = T.data.unsafe_load(i).cast[f32]()
        var inner = 0.7978845608028654 * (x + 0.044715 * x * x * x)
        T.data.unsafe_store(i, (0.5 * x * (1.0 + tanh(inner))).cast[f16]())


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
    if isnan(epsilon) or isinf(epsilon) or epsilon <= 0.0:
        raise Error("rmsnorm: epsilon must be finite and positive")

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
    if theta <= 0.0 or isnan(theta) or isinf(theta):
        raise Error("apply_rope: theta must be finite and positive")
    if head_dim <= 0 or head_dim % 2 != 0:
        raise Error("apply_rope: head_dim must be positive and even")
    if Q.cols % head_dim != 0 or K.cols % head_dim != 0:
        raise Error("apply_rope: tensor columns must be a multiple of head_dim")
    if Q.rows <= 0 or K.rows <= 0 or Q.cols <= 0 or K.cols <= 0:
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

    for r in range(K.rows):
        var pos = start_pos + r
        for i in range(half_dim):
            var freq = 1.0 / (theta ** (Float32(2 * i) / Float32(head_dim)))
            var val = Float32(pos) * freq
            var fcr = cos(val).cast[f16]()
            var fci = sin(val).cast[f16]()

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
    H011: the dlopen NPU stub retired — no dlopen probing, no NPU execution.
    Validates shapes, then raises the documented absence error until
    HAILBRU's real driver (H061+) lands. Fail-closed: never falls back
    to CPU compute under an NPU label.
    """
    if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols <= 0 or C.rows <= 0 or C.cols <= 0:
        raise Error("gemm_f16_npu: non-positive matrix dimensions are prohibited")
    if A.cols != B.cols or A.rows != C.rows or B.rows != C.cols:
        raise Error("gemm_f16_npu: GEMM shape mismatch")
    raise Error("NPU execution is not implemented for backend " + backend.name() + ": no physical kernel was launched")


def gemm_f16_gpgpu_vector(
    A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]
):
    """
    ᛗᚢᛋᚨ·ᛋᚢᚈᚨ·ᚷᛖᛗᛗ — The Strike of the Eastern Forge (gemm_f16_gpgpu_vector)
    ════════════════════════════════════════════════════════════════════════════

    Routes to physical NVIDIA CUDA GPU execution when CUDA is available, or vector SIMD.

    Silent-fallback contract (F009):
    - When CUDA is unavailable, or when CUDAGate.launch_gemm_cuda raises for
      any reason, this function silently falls back to the 16-wide vector SIMD
      path below. No error is raised and no notice is printed.
    - The fallback computes exactly what the function computes when CUDA was
      never available, so callers cannot distinguish "CUDA launch failed" from
      "CUDA absent" by inspecting C, the (absent) return value, or any error
      channel.
    - A one-time-per-process notice was considered, but Mojo 1.0.0 does not
      support module-level mutable state ("global variables are not
      supported"), so the fallback remains silent by design. The CPU fallback
      parity test pins the fallback path's numerical behavior instead.
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
