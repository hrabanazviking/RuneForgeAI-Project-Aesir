"""
Project Aesir — Q8 and FP8 Quantization Integration Unit Test Suite
════════════════════════════════════════════════════════════════════════
Verifies fused Q8_0, Q8_1, FP8_E4M3, and FP8_E5M2 matrix-vector multiplication parity
against uncompressed gemm_f16.
"""

from std.memory import Pointer, alloc, Layout
from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16, f32
from core.compute import (
    BlockQ8_0, BlockQ8_1,
    dequantize_q8_0, dequantize_q8_1, dequantize_fp8_e4m3, dequantize_fp8_e5m2,
    gemm_q8_0, gemm_q8_1, gemm_fp8_e4m3, gemm_fp8_e5m2, gemm_f16
)


def test_fused_q8_0_parity() raises:
    print("--- Testing fused Q8_0 GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var M = 2
    var K = 32
    var N = 2

    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr, False)
    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](0.1) * Scalar[f16](i + 1))

    var block_layout = Layout[BlockQ8_0](count=N)
    var block_alloc = alloc(block_layout)
    var B_blocks = block_alloc^.unsafe_leak().unsafe_bitcast[BlockQ8_0]()
    for n in range(N):
        var qs = SIMD[DType.int8, 32]()
        for i in range(32):
            qs[i] = Scalar[DType.int8]((i % 16) - 8)
        var blk = BlockQ8_0(Scalar[f16](0.25), qs)
        B_blocks.unsafe_offset(n)[] = blk

    var quant_w_ptr = B_blocks.unsafe_bitcast[Scalar[f16]]()
    var B_quant = RuneTensor[f16](N, K, quant_w_ptr, True, CompressedFormatType(CompressedFormatType.Q8_0))

    var dequant_w_ptr = well.allocate(N * K)
    dequantize_q8_0(B_blocks, dequant_w_ptr, N * (K // 32))
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
            raise Error("test_fused_q8_0_parity: mismatch at index " + String(i))

    print("fused Q8_0 GEMM parity: PASS")


def test_fused_q8_1_parity() raises:
    print("--- Testing fused Q8_1 GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var M = 2
    var K = 32
    var N = 2

    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr, False)
    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](0.05) * Scalar[f16](i + 1))

    var block_layout = Layout[BlockQ8_1](count=N)
    var block_alloc = alloc(block_layout)
    var B_blocks = block_alloc^.unsafe_leak().unsafe_bitcast[BlockQ8_1]()
    for n in range(N):
        var qs = SIMD[DType.int8, 32]()
        for i in range(32):
            qs[i] = Scalar[DType.int8]((i % 10) - 5)
        var blk = BlockQ8_1(Scalar[f16](0.5), Scalar[f16](0.0), qs)
        B_blocks.unsafe_offset(n)[] = blk

    var quant_w_ptr = B_blocks.unsafe_bitcast[Scalar[f16]]()
    var B_quant = RuneTensor[f16](N, K, quant_w_ptr, True, CompressedFormatType(CompressedFormatType.Q8_1))

    var dequant_w_ptr = well.allocate(N * K)
    dequantize_q8_1(B_blocks, dequant_w_ptr, N * (K // 32))
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
            raise Error("test_fused_q8_1_parity: mismatch at index " + String(i))

    print("fused Q8_1 GEMM parity: PASS")


def test_fused_fp8_e4m3_parity() raises:
    print("--- Testing fused FP8_E4M3 GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var M = 2
    var K = 32
    var N = 2

    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr, False)
    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](0.1) * Scalar[f16](i + 1))

    var bytes_layout = Layout[UInt8](count=N * K)
    var bytes_alloc = alloc(bytes_layout)
    var B_bytes = bytes_alloc^.unsafe_leak().unsafe_bitcast[UInt8]()
    for i in range(N * K):
        B_bytes.unsafe_store(i, UInt8((i * 17) % 256))

    var quant_w_ptr = B_bytes.unsafe_bitcast[Scalar[f16]]()
    var B_quant = RuneTensor[f16](N, K, quant_w_ptr, True, CompressedFormatType(CompressedFormatType.FP8_E4M3))

    var dequant_w_ptr = well.allocate(N * K)
    dequantize_fp8_e4m3(B_bytes, dequant_w_ptr, N * K)
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
            raise Error("test_fused_fp8_e4m3_parity: mismatch at index " + String(i))

    print("fused FP8_E4M3 GEMM parity: PASS")


def test_fused_fp8_e5m2_parity() raises:
    print("--- Testing fused FP8_E5M2 GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var M = 2
    var K = 32
    var N = 2

    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr, False)
    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](0.05) * Scalar[f16](i + 1))

    var bytes_layout = Layout[UInt8](count=N * K)
    var bytes_alloc = alloc(bytes_layout)
    var B_bytes = bytes_alloc^.unsafe_leak().unsafe_bitcast[UInt8]()
    for i in range(N * K):
        B_bytes.unsafe_store(i, UInt8((i * 31) % 256))

    var quant_w_ptr = B_bytes.unsafe_bitcast[Scalar[f16]]()
    var B_quant = RuneTensor[f16](N, K, quant_w_ptr, True, CompressedFormatType(CompressedFormatType.FP8_E5M2))

    var dequant_w_ptr = well.allocate(N * K)
    dequantize_fp8_e5m2(B_bytes, dequant_w_ptr, N * K)
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
            raise Error("test_fused_fp8_e5m2_parity: mismatch at index " + String(i))

    print("fused FP8_E5M2 GEMM parity: PASS")
