"""
Project Aesir — GPTQ & AWQ Block Quantization Integration Unit Test Suite
══════════════════════════════════════════════════════════════════════════
Verifies fused GPTQ_4BIT, GPTQ_8BIT, AWQ_4BIT, EXL2_VARBIT, HQQ, and
SMOOTHQUANT_INT8 matrix-vector multiplication parity against uncompressed
gemm_f16.
"""

from std.memory import Pointer
from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16, f32
from core.compute import (
    dequantize_gptq_4bit, dequantize_awq_4bit, dequantize_exl2, dequantize_hqq, dequantize_smoothquant_int8,
    gemm_gptq_4bit, gemm_gptq_8bit, gemm_awq_4bit, gemm_exl2, gemm_hqq, gemm_smoothquant_int8, gemm_f16
)


def test_fused_gptq_4bit_parity() raises:
    print("--- Testing fused GPTQ_4BIT GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var M = 2
    var K = 32
    var N = 2

    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr, False)
    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](0.02) * Scalar[f16](i + 1))

    var b_bytes = well.allocate((N * K) // 2).unsafe_bitcast[UInt8]()
    for i in range((N * K) // 2):
        b_bytes.unsafe_store(i, UInt8((i * 13) % 256))

    var B_quant = RuneTensor[f16](N, K, b_bytes.unsafe_bitcast[Scalar[f16]](), True, CompressedFormatType(CompressedFormatType.GPTQ_4BIT))

    var dequant_w_ptr = well.allocate(N * K)
    dequantize_gptq_4bit(b_bytes, dequant_w_ptr, N * K)
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
            raise Error("test_fused_gptq_4bit_parity: mismatch at index " + String(i))

    print("fused GPTQ_4BIT GEMM parity: PASS")


def test_fused_gptq_8bit_parity() raises:
    print("--- Testing fused GPTQ_8BIT GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var M = 2
    var K = 32
    var N = 2

    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr, False)
    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](0.02) * Scalar[f16](i + 1))

    var b_bytes = well.allocate(N * K).unsafe_bitcast[UInt8]()
    for i in range(N * K):
        b_bytes.unsafe_store(i, UInt8((i * 17) % 256))

    var B_quant = RuneTensor[f16](N, K, b_bytes.unsafe_bitcast[Scalar[f16]](), True, CompressedFormatType(CompressedFormatType.GPTQ_8BIT))

    var dequant_w_ptr = well.allocate(N * K)
    for i in range(N * K):
        var val = Scalar[f16](b_bytes.unsafe_load(i).cast[f16]()) * 0.025 - 3.2
        dequant_w_ptr.unsafe_store(i, val)
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
            raise Error("test_fused_gptq_8bit_parity: mismatch at index " + String(i))

    print("fused GPTQ_8BIT GEMM parity: PASS")


def test_fused_awq_4bit_parity() raises:
    print("--- Testing fused AWQ_4BIT GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var M = 2
    var K = 32
    var N = 2

    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr, False)
    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](0.02) * Scalar[f16](i + 1))

    var b_bytes = well.allocate((N * K) // 2).unsafe_bitcast[UInt8]()
    for i in range((N * K) // 2):
        b_bytes.unsafe_store(i, UInt8((i * 19) % 256))

    var B_quant = RuneTensor[f16](N, K, b_bytes.unsafe_bitcast[Scalar[f16]](), True, CompressedFormatType(CompressedFormatType.AWQ_4BIT))

    var dequant_w_ptr = well.allocate(N * K)
    dequantize_awq_4bit(b_bytes, dequant_w_ptr, N * K)
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
            raise Error("test_fused_awq_4bit_parity: mismatch at index " + String(i))

    print("fused AWQ_4BIT GEMM parity: PASS")


def test_fused_exl2_parity() raises:
    print("--- Testing fused EXL2_VARBIT GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var M = 2
    var K = 32
    var N = 2

    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr, False)
    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](0.02) * Scalar[f16](i + 1))

    var b_bytes = well.allocate((N * K) // 2).unsafe_bitcast[UInt8]()
    for i in range((N * K) // 2):
        b_bytes.unsafe_store(i, UInt8((i * 23) % 256))

    var B_quant = RuneTensor[f16](N, K, b_bytes.unsafe_bitcast[Scalar[f16]](), True, CompressedFormatType(CompressedFormatType.EXL2_VARBIT))

    var dequant_w_ptr = well.allocate(N * K)
    dequantize_exl2(b_bytes, dequant_w_ptr, N * K)
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
            raise Error("test_fused_exl2_parity: mismatch at index " + String(i))

    print("fused EXL2_VARBIT GEMM parity: PASS")


def test_fused_hqq_parity() raises:
    print("--- Testing fused HQQ GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var M = 2
    var K = 32
    var N = 2

    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr, False)
    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](0.02) * Scalar[f16](i + 1))

    var b_bytes = well.allocate(N * K).unsafe_bitcast[UInt8]()
    for i in range(N * K):
        b_bytes.unsafe_store(i, UInt8((i * 29) % 256))

    var B_quant = RuneTensor[f16](N, K, b_bytes.unsafe_bitcast[Scalar[f16]](), True, CompressedFormatType(CompressedFormatType.HQQ))

    var dequant_w_ptr = well.allocate(N * K)
    dequantize_hqq(b_bytes, dequant_w_ptr, N * K)
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
            raise Error("test_fused_hqq_parity: mismatch at index " + String(i))

    print("fused HQQ GEMM parity: PASS")


def test_fused_smoothquant_int8_parity() raises:
    print("--- Testing fused SMOOTHQUANT_INT8 GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var M = 2
    var K = 32
    var N = 2

    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr, False)
    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](0.02) * Scalar[f16](i + 1))

    var b_bytes = well.allocate(N * K).unsafe_bitcast[UInt8]()
    for i in range(N * K):
        b_bytes.unsafe_store(i, UInt8((i * 31) % 256))

    var B_quant = RuneTensor[f16](N, K, b_bytes.unsafe_bitcast[Scalar[f16]](), True, CompressedFormatType(CompressedFormatType.SMOOTHQUANT_INT8))

    var dequant_w_ptr = well.allocate(N * K)
    dequantize_smoothquant_int8(b_bytes, dequant_w_ptr, N * K)
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
            raise Error("test_fused_smoothquant_int8_parity: mismatch at index " + String(i))

    print("fused SMOOTHQUANT_INT8 GEMM parity: PASS")
