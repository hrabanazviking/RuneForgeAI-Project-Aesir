"""
Project Aesir — Ternary & 1-Bit Extreme Quantization Unit Test Suite
═════════════════════════════════════════════════════════════════════
Verifies fused IQ1_S, IQ2_XXS, and TERNARY_155BIT (BitNet 1.58-bit) matrix-vector
multiplication parity against uncompressed gemm_f16.
"""

from std.memory import Pointer, alloc, Layout
from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16, f32
from core.compute import (
    BlockIQ1_S, BlockIQ2_XXS, BlockTernary158,
    dequantize_iq1_s_block, dequantize_iq2_xxs_block, dequantize_ternary_158_block,
    gemm_iq1_s, gemm_iq2_xxs, gemm_ternary_158, gemm_f16
)


def test_fused_iq1_s_parity() raises:
    print("--- Testing fused IQ1_S GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var M = 2
    var K = 256
    var N = 2

    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr, False)
    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](0.01) * Scalar[f16](i + 1))

    var block_layout = Layout[BlockIQ1_S](count=N)
    var block_alloc = alloc(block_layout)
    var B_blocks = block_alloc^.unsafe_leak().unsafe_bitcast[BlockIQ1_S]()
    for n in range(N):
        var qs = SIMD[DType.uint8, 32](0x55)
        var qh = SIMD[DType.uint8, 16](0x33)
        var blk = BlockIQ1_S(Scalar[f16](0.125), qs, qh)
        B_blocks.unsafe_offset(n)[] = blk

    var quant_w_ptr = B_blocks.unsafe_bitcast[Scalar[f16]]()
    var B_quant = RuneTensor[f16](N, K, quant_w_ptr, True, CompressedFormatType(CompressedFormatType.IQ1_S))

    var dequant_w_ptr = well.allocate(N * K)
    dequantize_iq1_s_block(B_blocks, dequant_w_ptr, N)
    var B_dequant = RuneTensor[f16](N, K, dequant_w_ptr, False)

    var cf_ptr = well.allocate(M * N)
    var cd_ptr = well.allocate(M * N)
    var C_fused = RuneTensor[f16](M, N, cf_ptr, False)
    var C_dequant = RuneTensor[f16](M, N, cd_ptr, False)

    gemm_f16(A, B_quant, C_fused)
    gemm_f16(A, B_dequant, C_dequant)

    for i in range(M * N):
        var diff = C_fused.data.unsafe_load(i) - C_dequant.data.unsafe_load(i)
        var abs_diff = diff if diff >= 0 else -diff
        if abs_diff > 0.05:
            raise Error("test_fused_iq1_s_parity: mismatch at index " + String(i))

    print("fused IQ1_S GEMM parity: PASS")


def test_fused_iq2_xxs_parity() raises:
    print("--- Testing fused IQ2_XXS GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var M = 2
    var K = 256
    var N = 2

    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr, False)
    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](0.01) * Scalar[f16](i + 1))

    var block_layout = Layout[BlockIQ2_XXS](count=N)
    var block_alloc = alloc(block_layout)
    var B_blocks = block_alloc^.unsafe_leak().unsafe_bitcast[BlockIQ2_XXS]()
    for n in range(N):
        var qs = SIMD[DType.uint8, 64](0xAA)
        var blk = BlockIQ2_XXS(Scalar[f16](0.25), qs)
        B_blocks.unsafe_offset(n)[] = blk

    var quant_w_ptr = B_blocks.unsafe_bitcast[Scalar[f16]]()
    var B_quant = RuneTensor[f16](N, K, quant_w_ptr, True, CompressedFormatType(CompressedFormatType.IQ2_XXS))

    var dequant_w_ptr = well.allocate(N * K)
    dequantize_iq2_xxs_block(B_blocks, dequant_w_ptr, N)
    var B_dequant = RuneTensor[f16](N, K, dequant_w_ptr, False)

    var cf_ptr = well.allocate(M * N)
    var cd_ptr = well.allocate(M * N)
    var C_fused = RuneTensor[f16](M, N, cf_ptr, False)
    var C_dequant = RuneTensor[f16](M, N, cd_ptr, False)

    gemm_f16(A, B_quant, C_fused)
    gemm_f16(A, B_dequant, C_dequant)

    for i in range(M * N):
        var diff = C_fused.data.unsafe_load(i) - C_dequant.data.unsafe_load(i)
        var abs_diff = diff if diff >= 0 else -diff
        if abs_diff > 0.05:
            raise Error("test_fused_iq2_xxs_parity: mismatch at index " + String(i))

    print("fused IQ2_XXS GEMM parity: PASS")


def test_fused_ternary_158_parity() raises:
    print("--- Testing fused TERNARY_155BIT GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var M = 2
    var K = 256
    var N = 2

    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr, False)
    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](0.01) * Scalar[f16](i + 1))

    var block_layout = Layout[BlockTernary158](count=N)
    var block_alloc = alloc(block_layout)
    var B_blocks = block_alloc^.unsafe_leak().unsafe_bitcast[BlockTernary158]()
    for n in range(N):
        var qs = SIMD[DType.uint8, 64](0x69)
        var blk = BlockTernary158(Scalar[f16](0.5), qs)
        B_blocks.unsafe_offset(n)[] = blk

    var quant_w_ptr = B_blocks.unsafe_bitcast[Scalar[f16]]()
    var B_quant = RuneTensor[f16](N, K, quant_w_ptr, True, CompressedFormatType(CompressedFormatType.TERNARY_155BIT))

    var dequant_w_ptr = well.allocate(N * K)
    dequantize_ternary_158_block(B_blocks, dequant_w_ptr, N)
    var B_dequant = RuneTensor[f16](N, K, dequant_w_ptr, False)

    var cf_ptr = well.allocate(M * N)
    var cd_ptr = well.allocate(M * N)
    var C_fused = RuneTensor[f16](M, N, cf_ptr, False)
    var C_dequant = RuneTensor[f16](M, N, cd_ptr, False)

    gemm_f16(A, B_quant, C_fused)
    gemm_f16(A, B_dequant, C_dequant)

    for i in range(M * N):
        var diff = C_fused.data.unsafe_load(i) - C_dequant.data.unsafe_load(i)
        var abs_diff = diff if diff >= 0 else -diff
        if abs_diff > 0.05:
            raise Error("test_fused_ternary_158_parity: mismatch at index " + String(i))

    print("fused TERNARY_155BIT GEMM parity: PASS")
