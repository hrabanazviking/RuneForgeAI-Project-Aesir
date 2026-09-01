"""Raw-byte GGML Q3_K and Q5_K CPU matvec regressions."""

from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16, f32
from core.compute import (
    gemm_f16,
    dequantize_q3_k_s,
    dequantize_q3_k_m,
    dequantize_q3_k_l,
    dequantize_q5_k_s,
    dequantize_q5_k_m,
)


def _run_q3_k(format: CompressedFormatType) raises:
    """Known-value Q3_K block using the upstream 110-byte GGML layout."""
    var well = MimirWell(8192)
    var raw = well.allocate(110).unsafe_bitcast[UInt8]()
    for i in range(110):
        raw.unsafe_store(i, UInt8(0))
    for i in range(32):
        raw.unsafe_store(i, UInt8(0xFF))  # high bits set: q is 0..3
    for i in range(64):
        raw.unsafe_store(32 + i, UInt8(0xE4))
    for i in range(8):
        raw.unsafe_store(96 + i, UInt8(0x11))
    for i in range(4):
        raw.unsafe_store(104 + i, UInt8(0xAA))  # encoded scale is 33 => signed scale 1
    raw.unsafe_offset(108).unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.5))

    var decoded = well.allocate(256)
    if format.value == CompressedFormatType.Q3_K_S:
        dequantize_q3_k_s(raw, decoded, 1)
    elif format.value == CompressedFormatType.Q3_K_L:
        dequantize_q3_k_l(raw, decoded, 1)
    else:
        dequantize_q3_k_m(raw, decoded, 1)
    var decoded_sum: Float32 = 0
    for i in range(256):
        decoded_sum += decoded.unsafe_load(i).cast[f32]()
    if decoded_sum != Float32(192):
        raise Error("Q3_K public dequantizer known-value mismatch")

    var input = well.allocate(256)
    for i in range(256):
        input.unsafe_store(i, Float16(1))
    var A = RuneTensor[f16](1, 256, input, False)
    var B = RuneTensor[f16](1, 256, raw.unsafe_bitcast[Float16](), True, format)
    var C = RuneTensor[f16](1, 1, well.allocate(1), False)
    gemm_f16(A, B, C)
    if C.data.unsafe_load().cast[f32]() != Float32(192):
        raise Error("Raw Q3_K matvec known-value mismatch")
    _ = well


def test_fused_q3_k_s_parity() raises:
    _run_q3_k(CompressedFormatType(CompressedFormatType.Q3_K_S))
    print("raw Q3_K_S matvec: PASS")


def test_fused_q3_k_m_parity() raises:
    _run_q3_k(CompressedFormatType(CompressedFormatType.Q3_K_M))
    print("raw Q3_K_M matvec: PASS")


def test_fused_q3_k_l_parity() raises:
    _run_q3_k(CompressedFormatType(CompressedFormatType.Q3_K_L))
    print("raw Q3_K_L matvec: PASS")


def _run_q5_k(format: CompressedFormatType) raises:
    """Known-value Q5_K block using the upstream 176-byte GGML layout."""
    var well = MimirWell(8192)
    var raw = well.allocate(176).unsafe_bitcast[UInt8]()
    for i in range(176):
        raw.unsafe_store(i, UInt8(0))
    raw.unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.5))
    raw.unsafe_offset(2).unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.25))
    for i in range(4):
        raw.unsafe_store(4 + i, UInt8(1))
        raw.unsafe_store(8 + i, UInt8(2))
        raw.unsafe_store(12 + i, UInt8(0x21))
    for i in range(128):
        raw.unsafe_store(48 + i, UInt8(0x21))

    var decoded = well.allocate(256)
    if format.value == CompressedFormatType.Q5_K_S:
        dequantize_q5_k_s(raw, decoded, 1)
    else:
        dequantize_q5_k_m(raw, decoded, 1)
    var decoded_sum: Float32 = 0
    for i in range(256):
        decoded_sum += decoded.unsafe_load(i).cast[f32]()
    if decoded_sum != Float32(64):
        raise Error("Q5_K public dequantizer known-value mismatch")

    var input = well.allocate(256)
    for i in range(256):
        input.unsafe_store(i, Float16(1))
    var A = RuneTensor[f16](1, 256, input, False)
    var B = RuneTensor[f16](1, 256, raw.unsafe_bitcast[Float16](), True, format)
    var C = RuneTensor[f16](1, 1, well.allocate(1), False)
    gemm_f16(A, B, C)
    if C.data.unsafe_load().cast[f32]() != Float32(64):
        raise Error("Raw Q5_K matvec known-value mismatch")
    _ = well


def test_fused_q5_k_s_parity() raises:
    _run_q5_k(CompressedFormatType(CompressedFormatType.Q5_K_S))
    print("raw Q5_K_S matvec: PASS")


def test_fused_q5_k_m_parity() raises:
    _run_q5_k(CompressedFormatType(CompressedFormatType.Q5_K_M))
    print("raw Q5_K_M matvec: PASS")
