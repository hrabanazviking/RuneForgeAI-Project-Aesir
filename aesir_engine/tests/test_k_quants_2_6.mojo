"""Raw-byte GGML Q2_K and Q6_K CPU matvec regressions."""

from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16, f32
from core.compute import gemm_f16


def test_fused_q2_k_parity() raises:
    """Known-value Q2_K block using the upstream 84-byte GGML layout."""
    var well = MimirWell(8192)
    var raw = well.allocate(84).unsafe_bitcast[UInt8]()
    for i in range(84):
        raw.unsafe_store(i, UInt8(0))
    for i in range(16):
        raw.unsafe_store(i, UInt8(0x21))  # scale=1, minimum=2
    for i in range(64):
        raw.unsafe_store(16 + i, UInt8(0xE4))  # 2-bit lanes 0,1,2,3
    raw.unsafe_offset(80).unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.5))
    raw.unsafe_offset(82).unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.25))

    var input = well.allocate(256)
    for i in range(256):
        input.unsafe_store(i, Float16(1))
    var A = RuneTensor[f16](1, 256, input, False)
    var B = RuneTensor[f16](1, 256, raw.unsafe_bitcast[Float16](), True, CompressedFormatType(CompressedFormatType.Q2_K))
    var C = RuneTensor[f16](1, 1, well.allocate(1), False)
    gemm_f16(A, B, C)
    if C.data.unsafe_load().cast[f32]() != Float32(64):
        raise Error("Raw Q2_K matvec known-value mismatch")
    _ = well
    print("raw Q2_K matvec: PASS")


def test_fused_q6_k_parity() raises:
    """Known-value Q6_K block using the upstream 210-byte GGML layout."""
    var well = MimirWell(8192)
    var raw = well.allocate(210).unsafe_bitcast[UInt8]()
    for i in range(210):
        raw.unsafe_store(i, UInt8(0))
    raw.unsafe_offset(208).unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.125))
    for i in range(128):
        raw.unsafe_store(i, UInt8(85))
    for i in range(64):
        raw.unsafe_store(128 + i, UInt8(51))
    for i in range(16):
        raw.unsafe_store(192 + i, UInt8(1))
    # Half the weights are +21/8 and half -27/8, so their sum is -96.
    var input = well.allocate(256)
    for i in range(256):
        input.unsafe_store(i, Float16(1))
    var A = RuneTensor[f16](1, 256, input, False)
    var B = RuneTensor[f16](1, 256, raw.unsafe_bitcast[Float16](), True, CompressedFormatType(CompressedFormatType.Q6_K))
    var C = RuneTensor[f16](1, 1, well.allocate(1), False)
    gemm_f16(A, B, C)
    if C.data.unsafe_load().cast[f32]() != Float32(-96):
        raise Error("Raw Q6_K matvec known-value mismatch")
    _ = well
    print("raw Q6_K matvec: PASS")
