"""
Project Aesir — Quantization System Hardening & Self-Healing Unit Test Suite
════════════════════════════════════════════════════════════════════════════
Verifies crash-proof null/zero bounds handling, invalid dimension rejection,
unrecognized format self-healing fallbacks, and NaN sanitization across all
quantization routines.
"""

from std.memory import Pointer
from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16, f32
from core.compute import (
    BlockQ4_0, BlockQ4_1, BlockQ5_0, BlockQ5_1, BlockQ8_0,
    dequantize_q4_0, dequantize_q4_1, dequantize_q5_0, dequantize_q5_1,
    dequantize_q8_0, dequantize_q8_1, dequantize_fp8_e4m3, dequantize_fp8_e5m2,
    dequantize_ggml_k, dequantize_compressed_tensor,
    gemm_q4_0, gemm_q4_1, gemm_q5_0, gemm_q5_1, gemm_q8_0, gemm_q8_1,
    gemm_fp8_e4m3, gemm_fp8_e5m2, gemm_q3_k_m, gemm_q5_k_m, gemm_q4_k_m, gemm_f16
)
from loader.quantization import (
    get_block_size_bytes, get_weights_per_block,
    quant_block_size_bytes, quant_weights_per_block,
    validate_quantized_byte_span,
    dequantize_q4_0_block, dequantize_q8_0_block,
    dequantize_q4_0_checked, dequantize_q8_0_checked,
)


def test_dequantizer_zero_and_null_bounds() raises:
    print("--- Testing Dequantizer Invalid Bounds Rejection ---")
    var null_out = Pointer[Scalar[f16], MutUntrackedOrigin](unsafe_from_address=1)
    var null_u8 = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=1)

    # Legacy fixed-size block helpers retain mutation-free zero-count behavior.
    dequantize_q4_0(null_u8.unsafe_bitcast[BlockQ4_0](), null_out, 0)
    dequantize_q4_1(null_u8.unsafe_bitcast[BlockQ4_1](), null_out, 0)
    dequantize_q5_0(null_u8.unsafe_bitcast[BlockQ5_0](), null_out, 0)
    dequantize_q5_1(null_u8.unsafe_bitcast[BlockQ5_1](), null_out, 0)
    dequantize_q8_0(null_u8.unsafe_bitcast[BlockQ8_0](), null_out, 0)
    dequantize_q8_1(null_u8, null_out, 0)
    dequantize_fp8_e4m3(null_u8, null_out, 0)
    dequantize_fp8_e5m2(null_u8, null_out, 0)

    # Canonical K-quant decoding is strict because it is a public byte-layout boundary.
    var rejected_zero = False
    try:
        dequantize_ggml_k(null_u8, null_out, 0, 12)
    except:
        rejected_zero = True
    if not rejected_zero:
        raise Error("K-quant decoder accepted a zero element count")

    var rejected_partial = False
    try:
        dequantize_ggml_k(null_u8, null_out, 255, 12)
    except:
        rejected_partial = True
    if not rejected_partial:
        raise Error("K-quant decoder accepted an incomplete block")

    print("dequantizer invalid bounds rejection: PASS")


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

    var quant_w_ptr = well.allocate(N * K)
    # Construct tensor with unknown format discriminant 999
    var B_unrecognized = RuneTensor[f16](N, K, quant_w_ptr, True, CompressedFormatType(999))

    var cf_ptr = well.allocate(M * N)
    var C = RuneTensor[f16](M, N, cf_ptr, False)

    # The primary quantized GEMM dispatcher must reject unknown format 999.
    var rejected = False
    try:
        gemm_f16(A, B_unrecognized, C)
    except:
        rejected = True

    if not rejected:
        raise Error("test_unrecognized_format_fallback failed to reject unrecognized format discriminant 999")

    print("unrecognized format strict rejection: PASS")


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

def test_r014_unknown_format_strict_raising() raises:
    print("--- Testing R014 Unknown Format Strict Raising ---")
    var unknown = CompressedFormatType(999)

    # Legacy fail-open fallbacks are retained for old callers.
    if get_block_size_bytes(unknown) != 144:
        raise Error("R014: legacy get_block_size_bytes fail-open changed for unknown format")
    if get_weights_per_block(unknown) != 32:
        raise Error("R014: legacy get_weights_per_block fail-open changed for unknown format")

    # Strict block-size variant must refuse and name the offending discriminant.
    var msg_block = ""
    try:
        _ = quant_block_size_bytes(unknown)
    except e:
        msg_block = String(e)
    if msg_block.find("999") == -1 or msg_block.find("unknown quantization format") == -1:
        raise Error("R014: quant_block_size_bytes did not name unknown format 999 (got: " + msg_block + ")")

    # Strict weights-per-block variant must refuse and name the offending discriminant.
    var msg_wpb = ""
    try:
        _ = quant_weights_per_block(unknown)
    except e:
        msg_wpb = String(e)
    if msg_wpb.find("999") == -1 or msg_wpb.find("unknown quantization format") == -1:
        raise Error("R014: quant_weights_per_block did not name unknown format 999 (got: " + msg_wpb + ")")

    # validate_quantized_byte_span must raise via the strict path, naming 999.
    var msg_span = ""
    try:
        validate_quantized_byte_span(144, 256, unknown)
    except e:
        msg_span = String(e)
    if msg_span.find("999") == -1:
        raise Error("R014: validate_quantized_byte_span silently accepted unknown format 999 (got: " + msg_span + ")")

    # All known formats still validate exactly as before.
    validate_quantized_byte_span(144, 256, CompressedFormatType(CompressedFormatType.Q4_K_M))
    validate_quantized_byte_span(18, 32, CompressedFormatType(CompressedFormatType.Q4_0))
    validate_quantized_byte_span(20, 32, CompressedFormatType(CompressedFormatType.Q4_1))
    validate_quantized_byte_span(34, 32, CompressedFormatType(CompressedFormatType.Q8_0))
    if quant_block_size_bytes(CompressedFormatType(CompressedFormatType.Q8_0)) != 34:
        raise Error("R014: strict block size wrong for Q8_0")
    if quant_block_size_bytes(CompressedFormatType(CompressedFormatType.Q4_0)) != 18:
        raise Error("R014: strict block size wrong for Q4_0")
    if quant_weights_per_block(CompressedFormatType(CompressedFormatType.Q4_K_M)) != 256:
        raise Error("R014: strict weights-per-block wrong for Q4_K_M")
    if quant_weights_per_block(CompressedFormatType(CompressedFormatType.Q8_0)) != 32:
        raise Error("R014: strict weights-per-block wrong for Q8_0")

    print("R014 unknown format strict raising: PASS")


def test_r015_dequantize_checked_bounds() raises:
    print("--- Testing R015 Dequantize Checked Bounds ---")
    var well = MimirWell(1024 * 1024)

    # Two Q4_0 blocks: 36 source bytes -> 64 f16 values.
    var src_q4 = well.allocate(64).unsafe_bitcast[UInt8]()
    var dst_raw = well.allocate(64)
    var dst_chk = well.allocate(64)
    for i in range(36):
        src_q4.unsafe_store(i, Scalar[DType.uint8]((i * 13 + 7) % 256))
    # fp16 scale 1.0 (0x3C00, little-endian) at the head of each block.
    src_q4.unsafe_store(0, Scalar[DType.uint8](0x00))
    src_q4.unsafe_store(1, Scalar[DType.uint8](0x3C))
    src_q4.unsafe_store(18, Scalar[DType.uint8](0x00))
    src_q4.unsafe_store(19, Scalar[DType.uint8](0x3C))

    dequantize_q4_0_block(src_q4, dst_raw, 2)
    dequantize_q4_0_checked(src_q4, 36, dst_chk, 64, 2)
    for i in range(64):
        if dst_raw.unsafe_load(i) != dst_chk.unsafe_load(i):
            raise Error("R015: checked q4_0 output differs from raw kernel at index " + String(i))

    # Undersized src raises, naming expected (36) vs actual (35).
    var msg_src = ""
    try:
        dequantize_q4_0_checked(src_q4, 35, dst_chk, 64, 2)
    except e:
        msg_src = String(e)
    if msg_src.find("36") == -1 or msg_src.find("35") == -1:
        raise Error("R015: q4_0 undersized src error lacks expected-vs-actual (got: " + msg_src + ")")

    # Undersized dst raises, naming expected (64) vs actual (63).
    var msg_dst = ""
    try:
        dequantize_q4_0_checked(src_q4, 36, dst_chk, 63, 2)
    except e:
        msg_dst = String(e)
    if msg_dst.find("64") == -1 or msg_dst.find("63") == -1:
        raise Error("R015: q4_0 undersized dst error lacks expected-vs-actual (got: " + msg_dst + ")")

    # Negative num_blocks raises.
    var rejected_neg = False
    try:
        dequantize_q4_0_checked(src_q4, 36, dst_chk, 64, -1)
    except:
        rejected_neg = True
    if not rejected_neg:
        raise Error("R015: checked q4_0 accepted negative num_blocks")

    # One Q8_0 block: 34 source bytes -> 32 f16 values.
    var src_q8 = well.allocate(64).unsafe_bitcast[UInt8]()
    var dst8_raw = well.allocate(32)
    var dst8_chk = well.allocate(32)
    for i in range(34):
        src_q8.unsafe_store(i, Scalar[DType.uint8]((i * 5 + 3) % 256))
    src_q8.unsafe_store(0, Scalar[DType.uint8](0x00))
    src_q8.unsafe_store(1, Scalar[DType.uint8](0x3C))

    dequantize_q8_0_block(src_q8, dst8_raw, 1)
    dequantize_q8_0_checked(src_q8, 34, dst8_chk, 32, 1)
    for i in range(32):
        if dst8_raw.unsafe_load(i) != dst8_chk.unsafe_load(i):
            raise Error("R015: checked q8_0 output differs from raw kernel at index " + String(i))

    # Undersized q8_0 src raises, naming expected (34) vs actual (33).
    var msg8 = ""
    try:
        dequantize_q8_0_checked(src_q8, 33, dst8_chk, 32, 1)
    except e:
        msg8 = String(e)
    if msg8.find("34") == -1 or msg8.find("33") == -1:
        raise Error("R015: q8_0 undersized src error lacks expected-vs-actual (got: " + msg8 + ")")

    # Negative num_blocks raises for q8_0 as well.
    var rejected_neg8 = False
    try:
        dequantize_q8_0_checked(src_q8, 34, dst8_chk, 32, -5)
    except:
        rejected_neg8 = True
    if not rejected_neg8:
        raise Error("R015: checked q8_0 accepted negative num_blocks")

    print("R015 dequantize checked bounds: PASS")


def test_r016_enriched_error_messages() raises:
    print("--- Testing R016 Enriched Error Messages ---")
    var fmt_q4_0 = CompressedFormatType(CompressedFormatType.Q4_0)

    # Site 1: non-positive inputs must name the offending values.
    var msg_pos = ""
    try:
        validate_quantized_byte_span(0, 32, fmt_q4_0)
    except e:
        msg_pos = String(e)
    if msg_pos.find("num_elements 32") == -1 or msg_pos.find("validate_quantized_byte_span") == -1:
        raise Error("R016: positivity error lacks offending values (got: " + msg_pos + ")")

    # Site 2: 100 bytes is not a multiple of block size 18 (format Q4_0).
    var msg_mult = ""
    try:
        validate_quantized_byte_span(100, 32, fmt_q4_0)
    except e:
        msg_mult = String(e)
    if msg_mult.find("100") == -1 or msg_mult.find("18") == -1 or msg_mult.find("Q4_0") == -1:
        raise Error("R016: alignment error lacks offending values (got: " + msg_mult + ")")

    # Site 3: 36 bytes = 2 blocks = 64 expected elements, got 63.
    var msg_elem = ""
    try:
        validate_quantized_byte_span(36, 63, fmt_q4_0)
    except e:
        msg_elem = String(e)
    if msg_elem.find("63") == -1 or msg_elem.find("64") == -1 or msg_elem.find("36") == -1:
        raise Error("R016: element-mismatch error lacks offending values (got: " + msg_elem + ")")

    print("R016 enriched error messages: PASS")


def main() raises:
    test_dequantizer_zero_and_null_bounds()
    test_gemm_invalid_dimensions_rejection()
    test_unrecognized_format_self_healing()
    test_nan_corrupt_weight_sanitization()
    test_r014_unknown_format_strict_raising()
    test_r015_dequantize_checked_bounds()
    test_r016_enriched_error_messages()
