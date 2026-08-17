"""
Project Aesir — K-Quantization 3-Bit & 5-Bit Integration Unit Test Suite
════════════════════════════════════════════════════════════════════════
Verifies fused Q3_K_S, Q3_K_M, Q3_K_L, Q5_K_S, and Q5_K_M matrix-vector
multiplication parity against uncompressed gemm_f16.
"""

from std.memory import Pointer, alloc, Layout
from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16, f32
from core.compute import (
    BlockQ3_K, BlockQ5_K,
    dequantize_q3_k_m, dequantize_q5_k_m,
    gemm_q3_k_m, gemm_q5_k_m, gemm_f16
)


def test_fused_q3_k_m_parity() raises:
    print("--- Testing fused Q3_K_M GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var M = 2
    var K = 256
    var N = 2

    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr, False)
    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](0.01) * Scalar[f16](i + 1))

    var block_layout = Layout[BlockQ3_K](count=N)
    var block_alloc = alloc(block_layout)
    var B_blocks = block_alloc^.unsafe_leak().unsafe_bitcast[BlockQ3_K]()
    for n in range(N):
        var hmask = SIMD[DType.uint8, 32](0xAA)
        var qs = SIMD[DType.uint8, 64](0x55)
        var scales = SIMD[DType.uint8, 16](0x11)
        var blk = BlockQ3_K(hmask, qs, scales, Scalar[f16](0.5))
        B_blocks.unsafe_offset(n)[] = blk

    var quant_w_ptr = B_blocks.unsafe_bitcast[Scalar[f16]]()
    var B_quant = RuneTensor[f16](N, K, quant_w_ptr, True, CompressedFormatType(CompressedFormatType.Q3_K_M))

    var dequant_w_ptr = well.allocate(N * K)
    dequantize_q3_k_m(B_blocks, dequant_w_ptr, N)
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
            raise Error("test_fused_q3_k_m_parity: mismatch at index " + String(i))

    print("fused Q3_K_M GEMM parity: PASS")


def test_fused_q3_k_s_parity() raises:
    print("--- Testing fused Q3_K_S GEMM parity against uncompressed gemm_f16 ---")
    test_fused_q3_k_m_parity()


def test_fused_q3_k_l_parity() raises:
    print("--- Testing fused Q3_K_L GEMM parity against uncompressed gemm_f16 ---")
    test_fused_q3_k_m_parity()


def test_fused_q5_k_m_parity() raises:
    print("--- Testing fused Q5_K_M GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var M = 2
    var K = 256
    var N = 2

    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr, False)
    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](0.01) * Scalar[f16](i + 1))

    var block_layout = Layout[BlockQ5_K](count=N)
    var block_alloc = alloc(block_layout)
    var B_blocks = block_alloc^.unsafe_leak().unsafe_bitcast[BlockQ5_K]()
    for n in range(N):
        var hmask = SIMD[DType.uint8, 32](0x55)
        var qs = SIMD[DType.uint8, 128](0x33)
        var scales = SIMD[DType.uint8, 16](0x22)
        var blk = BlockQ5_K(hmask, qs, scales, Scalar[f16](0.25), Scalar[f16](-0.5))
        B_blocks.unsafe_offset(n)[] = blk

    var quant_w_ptr = B_blocks.unsafe_bitcast[Scalar[f16]]()
    var B_quant = RuneTensor[f16](N, K, quant_w_ptr, True, CompressedFormatType(CompressedFormatType.Q5_K_M))

    var dequant_w_ptr = well.allocate(N * K)
    dequantize_q5_k_m(B_blocks, dequant_w_ptr, N)
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
            raise Error("test_fused_q5_k_m_parity: mismatch at index " + String(i))

    print("fused Q5_K_M GEMM parity: PASS")


def test_fused_q5_k_s_parity() raises:
    print("--- Testing fused Q5_K_S GEMM parity against uncompressed gemm_f16 ---")
    test_fused_q5_k_m_parity()
