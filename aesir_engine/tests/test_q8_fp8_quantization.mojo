"""Raw known-value Q8 and FP8 matrix-vector regressions."""

from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16, f32
from core.compute import gemm_f16


def test_fused_q8_0_parity() raises:
    """Canonical GGML Q8_0 is a 2-byte F16 scale plus 32 signed bytes."""
    var well = MimirWell(4096)
    var raw = well.allocate(34).unsafe_bitcast[UInt8]()
    for i in range(34):
        raw.unsafe_store(i, UInt8(0))
    raw.unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.25))
    for i in range(32):
        raw.unsafe_offset(2).unsafe_bitcast[Int8]().unsafe_store(i, Int8(i - 16))
    var input = well.allocate(32)
    for i in range(32):
        input.unsafe_store(i, Float16(1))
    var A = RuneTensor[f16](1, 32, input, False)
    var B = RuneTensor[f16](1, 32, raw.unsafe_bitcast[Float16](), True, CompressedFormatType(CompressedFormatType.Q8_0))
    var C = RuneTensor[f16](1, 1, well.allocate(1), False)
    gemm_f16(A, B, C)
    if C.data.unsafe_load() != Float16(-4):
        raise Error("Raw Q8_0 matvec known-value mismatch")
    _ = well
    print("raw Q8_0 matvec: PASS")


def test_fused_q8_1_parity() raises:
    """Canonical GGML Q8_1 is 36 bytes: F16 d + F16 s plus 32 signed bytes.

    Q8-1 fix (deliberate banked-expectation update): this test previously
    encoded the fictitious 40-byte f32/f32 layout the compute reader
    walked. ggml block_q8_1 (ggml-common.h) is ggml_half d @0,
    ggml_half s @2 (s = d * sum(qs)), int8 qs @4..36; sizeof == 36,
    matching the loader's _tensor_byte_size. With d = 0.5 and
    qs = -16..15 (sum -16), s = -8 and the matvec sum is -8, as before.
    """
    var well = MimirWell(4096)
    var raw = well.allocate(36).unsafe_bitcast[UInt8]()
    for i in range(36):
        raw.unsafe_store(i, UInt8(0))
    raw.unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.5))
    raw.unsafe_offset(2).unsafe_bitcast[Float16]().unsafe_store(0, Float16(-8))  # s = d * sum(q)
    for i in range(32):
        raw.unsafe_offset(4).unsafe_bitcast[Int8]().unsafe_store(i, Int8(i - 16))
    var input = well.allocate(32)
    for i in range(32):
        input.unsafe_store(i, Float16(1))
    var A = RuneTensor[f16](1, 32, input, False)
    var B = RuneTensor[f16](1, 32, raw.unsafe_bitcast[Float16](), True, CompressedFormatType(CompressedFormatType.Q8_1))
    var C = RuneTensor[f16](1, 1, well.allocate(1), False)
    gemm_f16(A, B, C)
    if C.data.unsafe_load() != Float16(-8):
        raise Error("Raw Q8_1 matvec known-value mismatch")
    _ = well
    print("raw Q8_1 matvec: PASS")


def test_fused_fp8_e4m3_parity() raises:
    """E4M3 byte 0x38 is exactly +1, so 32 lanes sum to 32."""
    var well = MimirWell(4096)
    var raw = well.allocate(32).unsafe_bitcast[UInt8]()
    var input = well.allocate(32)
    for i in range(32):
        raw.unsafe_store(i, UInt8(0x38))
        input.unsafe_store(i, Float16(1))
    var A = RuneTensor[f16](1, 32, input, False)
    var B = RuneTensor[f16](1, 32, raw.unsafe_bitcast[Float16](), True, CompressedFormatType(CompressedFormatType.FP8_E4M3))
    var C = RuneTensor[f16](1, 1, well.allocate(1), False)
    gemm_f16(A, B, C)
    if C.data.unsafe_load() != Float16(32):
        raise Error("Raw FP8 E4M3 matvec known-value mismatch")
    _ = well
    print("raw FP8 E4M3 matvec: PASS")


def test_fused_fp8_e5m2_parity() raises:
    """E5M2 byte 0x3C is exactly +1, so 32 lanes sum to 32."""
    var well = MimirWell(4096)
    var raw = well.allocate(32).unsafe_bitcast[UInt8]()
    var input = well.allocate(32)
    for i in range(32):
        raw.unsafe_store(i, UInt8(0x3C))
        input.unsafe_store(i, Float16(1))
    var A = RuneTensor[f16](1, 32, input, False)
    var B = RuneTensor[f16](1, 32, raw.unsafe_bitcast[Float16](), True, CompressedFormatType(CompressedFormatType.FP8_E5M2))
    var C = RuneTensor[f16](1, 1, well.allocate(1), False)
    gemm_f16(A, B, C)
    if C.data.unsafe_load() != Float16(32):
        raise Error("Raw FP8 E5M2 matvec known-value mismatch")
    _ = well
    print("raw FP8 E5M2 matvec: PASS")
