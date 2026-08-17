"""
Project Aesir — K-Quantization 2-Bit & 6-Bit Integration Unit Test Suite
════════════════════════════════════════════════════════════════════════
Verifies fused Q2_K and Q6_K matrix-vector multiplication parity against
uncompressed gemm_f16.
"""

from std.memory import Pointer, alloc, Layout
from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16, f32
from core.compute import (
    BlockQ2_K, BlockQ6_K,
    dequantize_q2_k_block, dequantize_q6_k_block,
    gemm_q2_k, gemm_q6_k, gemm_f16
)


def test_fused_q2_k_parity() raises:
    print("--- Testing fused Q2_K GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var M = 2
    var K = 256
    var N = 2

    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr, False)
    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](0.01) * Scalar[f16](i + 1))

    var block_layout = Layout[BlockQ2_K](count=N)
    var block_alloc = alloc(block_layout)
    var B_blocks = block_alloc^.unsafe_leak().unsafe_bitcast[BlockQ2_K]()
    for n in range(N):
        var scales = SIMD[DType.uint8, 16](0x11)
        var qs = SIMD[DType.uint8, 64](0xAA)
        var blk = BlockQ2_K(scales, qs, Scalar[f16](0.25), Scalar[f16](-0.5))
        B_blocks.unsafe_offset(n)[] = blk

    var quant_w_ptr = B_blocks.unsafe_bitcast[Scalar[f16]]()
    var B_quant = RuneTensor[f16](N, K, quant_w_ptr, True, CompressedFormatType(CompressedFormatType.Q2_K))

    var dequant_w_ptr = well.allocate(N * K)
    dequantize_q2_k_block(B_blocks, dequant_w_ptr, N)
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
            raise Error("test_fused_q2_k_parity: mismatch at index " + String(i))

    print("fused Q2_K GEMM parity: PASS")


def test_fused_q6_k_parity() raises:
    print("--- Testing fused Q6_K GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var M = 2
    var K = 256
    var N = 2

    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr, False)
    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](0.01) * Scalar[f16](i + 1))

    var block_layout = Layout[BlockQ6_K](count=N)
    var block_alloc = alloc(block_layout)
    var B_blocks = block_alloc^.unsafe_leak().unsafe_bitcast[BlockQ6_K]()
    for n in range(N):
        var ql = SIMD[DType.uint8, 128](0x55)
        var qh = SIMD[DType.uint8, 64](0x33)
        var scales = SIMD[DType.int8, 16](0x01)
        var blk = BlockQ6_K(ql, qh, scales, Scalar[f16](0.125))
        B_blocks.unsafe_offset(n)[] = blk

    var quant_w_ptr = B_blocks.unsafe_bitcast[Scalar[f16]]()
    var B_quant = RuneTensor[f16](N, K, quant_w_ptr, True, CompressedFormatType(CompressedFormatType.Q6_K))

    var dequant_w_ptr = well.allocate(N * K)
    dequantize_q6_k_block(B_blocks, dequant_w_ptr, N)
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
            raise Error("test_fused_q6_k_parity: mismatch at index " + String(i))

    print("fused Q6_K GEMM parity: PASS")
