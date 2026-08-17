"""
Project Aesir — Comprehensive All-Format Quantization Suite & Autotuner Test
════════════════════════════════════════════════════════════════════════════
Verifies metadata reporting, autotuning recommendations, and hardware gateway
dispatching across all 25+ quantization formats supported by Project Aesir.
"""

from std.memory import Pointer
from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16, f32
from core.compute import (
    get_quantization_format_info, QuantizationFormatInfo,
    autotune_quantized_gemm, gemm_f16
)


def test_quantization_metadata_store() raises:
    print("--- Testing QuantizationFormatInfo Metadata Store across all formats ---")
    var formats_count = 26
    for i in range(formats_count):
        var fmt = CompressedFormatType(i)
        var info = get_quantization_format_info(fmt)
        if info.format_name.byte_length() == 0:
            raise Error("test_quantization_metadata_store: empty format name for discriminant " + String(i))
        if info.block_size <= 0:
            raise Error("test_quantization_metadata_store: invalid block size for " + info.format_name)
        if info.bits_per_weight <= 0.0:
            raise Error("test_quantization_metadata_store: invalid bits per weight for " + info.format_name)
        if info.compression_ratio <= 0.0:
            raise Error("test_quantization_metadata_store: invalid compression ratio for " + info.format_name)

    print("QuantizationFormatInfo Metadata Store: PASS")


def test_autotune_quantized_gemm_dispatch() raises:
    print("--- Testing autotune_quantized_gemm hardware gateway dispatch ---")
    var well = MimirWell(1024 * 1024)
    var M = 2
    var K = 32
    var N = 2

    var a_ptr = well.allocate(M * K)
    var A = RuneTensor[f16](M, K, a_ptr, False)
    for i in range(M * K):
        A.data.unsafe_store(i, Scalar[f16](0.05) * Scalar[f16](i + 1))

    # Test dispatching Q4_0
    var b0_bytes = well.allocate(N * K).unsafe_bitcast[UInt8]()
    for i in range(N * K):
        b0_bytes.unsafe_store(i, UInt8((i * 11) % 256))
    var B_q4 = RuneTensor[f16](N, K, b0_bytes.unsafe_bitcast[Scalar[f16]](), True, CompressedFormatType(CompressedFormatType.Q4_0))
    var c0_ptr = well.allocate(M * N)
    var C0 = RuneTensor[f16](M, N, c0_ptr, False)
    autotune_quantized_gemm(A, B_q4, C0)
    if C0.data.unsafe_load(0) == Scalar[f16](0.0):
        raise Error("test_autotune_quantized_gemm_dispatch: Q4_0 output is zero")

    # Test dispatching FP8_E4M3
    var b1_bytes = well.allocate(N * K).unsafe_bitcast[UInt8]()
    for i in range(N * K):
        b1_bytes.unsafe_store(i, UInt8((i * 13) % 256))
    var B_fp8 = RuneTensor[f16](N, K, b1_bytes.unsafe_bitcast[Scalar[f16]](), True, CompressedFormatType(CompressedFormatType.FP8_E4M3))
    var c1_ptr = well.allocate(M * N)
    var C1 = RuneTensor[f16](M, N, c1_ptr, False)
    autotune_quantized_gemm(A, B_fp8, C1)
    if C1.data.unsafe_load(0) == Scalar[f16](0.0):
        raise Error("test_autotune_quantized_gemm_dispatch: FP8 output is zero")

    # Test dispatching GPTQ_4BIT
    var b2_bytes = well.allocate(N * K).unsafe_bitcast[UInt8]()
    for i in range(N * K):
        b2_bytes.unsafe_store(i, UInt8((i * 17) % 256))
    var B_gptq = RuneTensor[f16](N, K, b2_bytes.unsafe_bitcast[Scalar[f16]](), True, CompressedFormatType(CompressedFormatType.GPTQ_4BIT))
    var c2_ptr = well.allocate(M * N)
    var C2 = RuneTensor[f16](M, N, c2_ptr, False)
    autotune_quantized_gemm(A, B_gptq, C2)
    if C2.data.unsafe_load(0) == Scalar[f16](0.0):
        raise Error("test_autotune_quantized_gemm_dispatch: GPTQ output is zero")

    print("autotune_quantized_gemm hardware gateway dispatch: PASS")
