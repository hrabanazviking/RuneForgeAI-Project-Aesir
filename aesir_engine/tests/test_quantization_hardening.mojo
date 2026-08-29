"""
Project Aesir — Quantization System Hardening & Self-Healing Unit Test Suite
════════════════════════════════════════════════════════════════════════════
Verifies crash-proof null/zero bounds handling, invalid dimension rejection,
unrecognized format self-healing fallbacks, and NaN sanitization across all
quantization routines.
"""

from std.memory import Pointer, alloc, Layout
from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16, f32
from core.compute import (
    BlockQ4_K, BlockQ4_0, BlockQ4_1, BlockQ5_0, BlockQ5_1, BlockQ8_0, BlockQ8_1,
    BlockQ3_K, BlockQ5_K,
    dequantize_q4_k_m, dequantize_q4_0, dequantize_q4_1, dequantize_q5_0, dequantize_q5_1,
    dequantize_q8_0, dequantize_q8_1, dequantize_fp8_e4m3, dequantize_fp8_e5m2,
    dequantize_q3_k_m, dequantize_q5_k_m, dequantize_compressed_tensor,
    gemm_q4_0, gemm_q4_1, gemm_q5_0, gemm_q5_1, gemm_q8_0, gemm_q8_1,
    gemm_fp8_e4m3, gemm_fp8_e5m2, gemm_q3_k_m, gemm_q5_k_m, gemm_q4_k_m, gemm_f16
)


def test_dequantizer_zero_and_null_bounds() raises:
    print("--- Testing Dequantizer Zero & Null Bounds Crash-Proofing ---")
    var null_b = Pointer[BlockQ4_K, MutUntrackedOrigin](unsafe_from_address=1)
    var null_out = Pointer[Scalar[f16], MutUntrackedOrigin](unsafe_from_address=1)
    var null_u8 = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=1)

    # 1. Zero block / element count returns immediately without segfault
    dequantize_q4_k_m(null_b, null_out, 0)
    dequantize_q4_0(null_u8.unsafe_bitcast[BlockQ4_0](), null_out, 0)
    dequantize_q4_1(null_u8.unsafe_bitcast[BlockQ4_1](), null_out, 0)
    dequantize_q5_0(null_u8.unsafe_bitcast[BlockQ5_0](), null_out, 0)
    dequantize_q5_1(null_u8.unsafe_bitcast[BlockQ5_1](), null_out, 0)
    dequantize_q8_0(null_u8.unsafe_bitcast[BlockQ8_0](), null_out, 0)
    dequantize_q8_1(null_u8.unsafe_bitcast[BlockQ8_1](), null_out, 0)
    dequantize_fp8_e4m3(null_u8, null_out, 0)
    dequantize_fp8_e5m2(null_u8, null_out, 0)
    dequantize_q3_k_m(null_u8.unsafe_bitcast[BlockQ3_K](), null_out, 0)
    dequantize_q5_k_m(null_u8.unsafe_bitcast[BlockQ5_K](), null_out, 0)

    # 2. Negative block / element count returns immediately
    dequantize_q4_k_m(null_b, null_out, -10)
    dequantize_q8_0(null_u8.unsafe_bitcast[BlockQ8_0](), null_out, -5)
    dequantize_fp8_e4m3(null_u8, null_out, -100)

    print("dequantizer zero & null bounds crash-proofing: PASS")


def test_gemm_invalid_dimensions_rejection() raises:
    print("--- Testing Quantized GEMM Invalid Dimension Rejection ---")
    var well = MimirWell(1024 * 1024)
    var p_a = well.allocate(16)
    var p_b = well.allocate(16)
    var p_c = well.allocate(16)

    # A.rows <= 0
    var a_inv = RuneTensor[f16](0, 4, p_a, False)
    var b_inv = RuneTensor[f16](4, 4, p_b, True, CompressedFormatType(CompressedFormatType.Q4_0))
    var c_inv = RuneTensor[f16](0, 4, p_c, False)
    
    var caught_rows = False
    try:
        gemm_q4_0(a_inv, b_inv, c_inv)
    except:
        caught_rows = True
    if not caught_rows:
        raise Error("test_gemm_invalid_dimensions_rejection: failed to reject non-positive A.rows")

    # Inner dimension mismatch (A.cols != B.cols)
    var a_mismatch = RuneTensor[f16](2, 32, p_a, False)
    var b_mismatch = RuneTensor[f16](2, 64, p_b, True, CompressedFormatType(CompressedFormatType.Q4_0))
    var c_mismatch = RuneTensor[f16](2, 2, p_c, False)

    var caught_mismatch = False
    try:
        gemm_q4_0(a_mismatch, b_mismatch, c_mismatch)
    except:
        caught_mismatch = True
    if not caught_mismatch:
        raise Error("test_gemm_invalid_dimensions_rejection: failed to reject inner dimension mismatch")

    print("quantized GEMM invalid dimension rejection: PASS")


def test_unrecognized_format_self_healing() raises:
    print("--- Testing Unrecognized Format Self-Healing Fallback ---")
    var well = MimirWell(1024 * 1024)
    var M = 2
    var K = 32
    var N = 2

    # Allocation for tensor data
    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr, False)
    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](0.1) * Scalar[f16](i + 1))

    var block_layout = Layout[BlockQ4_K](count=N)
    var block_alloc = alloc(block_layout)
    var B_blocks = block_alloc^.unsafe_leak().unsafe_bitcast[BlockQ4_K]()
    for n in range(N):
        var scales = SIMD[DType.uint8, 16](0x01)
        var qs = SIMD[DType.uint8, 128](0x22)
        var blk = BlockQ4_K(Scalar[f16](0.5), Scalar[f16](-0.25), scales, qs)
        B_blocks.unsafe_offset(n)[] = blk

    var quant_w_ptr = B_blocks.unsafe_bitcast[Scalar[f16]]()
    # Construct tensor with unknown format discriminant 999
    var B_unrecognized = RuneTensor[f16](N, K, quant_w_ptr, True, CompressedFormatType(999))

    var cf_ptr = well.allocate(M * N)
    var C = RuneTensor[f16](M, N, cf_ptr, False)

    # gemm_f16 should self-heal and route unrecognized format safely without crashing
    gemm_f16(A, B_unrecognized, C)

    print("unrecognized format self-healing fallback: PASS")


def test_nan_corrupt_weight_sanitization() raises:
    print("--- Testing FP8 & Quantized NaN / Corrupt Weight Sanitization ---")
    var well = MimirWell(1024 * 1024)
    var data_ptr = well.allocate(16).unsafe_bitcast[UInt8]()
    var out_ptr = well.allocate(16)

    # Store NaN / Inf bit patterns for FP8_E4M3 (0x7F = 01111111 = NaN in E4M3)
    for i in range(16):
        data_ptr.unsafe_store(i, Scalar[DType.uint8](0x7F))

    dequantize_fp8_e4m3(data_ptr, out_ptr, 16)

    for i in range(16):
        var val = out_ptr.unsafe_load(i)
        if val != val:
            raise Error("test_nan_corrupt_weight_sanitization: NaN detected at output index " + String(i))

    print("FP8 & quantized NaN / corrupt weight sanitization: PASS")
