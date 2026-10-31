from std.memory import Pointer, alloc, Layout
from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16, f32
from core.compute import BlockQ4_0, BlockQ4_1, BlockQ5_0, BlockQ5_1, dequantize_q4_0, dequantize_q4_1, dequantize_q5_0, dequantize_q5_1, gemm_q4_0, gemm_q4_1, gemm_q5_0, gemm_q5_1, gemm_f16


def test_q4_0_parity() raises:
    print("--- Testing fused Q4_0 GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var block_layout = Layout[BlockQ4_0](count=1)
    var block_alloc = alloc(block_layout)
    var block_mem = block_alloc^.unsafe_leak().unsafe_bitcast[BlockQ4_0]()
    
    # scale = 0.5, qs = 0x91 (lower = 1, upper = 9 -> val_lo = (1-8)*0.5 = -3.5, val_hi = (9-8)*0.5 = 0.5)
    block_mem[] = BlockQ4_0(
        scale=Scalar[f16](0.5),
        qs=SIMD[DType.uint8, 16](0x91)
    )

    var f16_w_ptr = well.allocate(32)
    dequantize_q4_0(block_mem, f16_w_ptr, 1)

    var B_f16 = RuneTensor[f16](1, 32, f16_w_ptr, False)
    var quant_w_ptr = block_mem.unsafe_bitcast[Scalar[f16]]()
    var B_quant = RuneTensor[f16](1, 32, quant_w_ptr, True, CompressedFormatType(CompressedFormatType.Q4_0))

    var a_ptr = well.allocate(32)
    for i in range(32):
        a_ptr.unsafe_store(i, Scalar[f16](1.0))
    var A = RuneTensor[f16](1, 32, a_ptr, False)

    var c1_ptr = well.allocate(1)
    var c2_ptr = well.allocate(1)
    var C1 = RuneTensor[f16](1, 1, c1_ptr, False)
    var C2 = RuneTensor[f16](1, 1, c2_ptr, False)

    gemm_f16(A, B_f16, C1)
    gemm_f16(A, B_quant, C2)

    var val1 = C1.data.unsafe_load(0)
    var val2 = C2.data.unsafe_load(0)
    var diff = val1 - val2
    if diff < 0:
        diff = -diff
    if diff > 0.01:
        raise Error("fused Q4_0 GEMM output mismatch vs uncompressed gemm_f16")
    print("fused Q4_0 GEMM parity: PASS")


def test_q4_1_parity() raises:
    """Known-value raw GGUF regression over two packed 20-byte blocks.

    The previous version built a single BlockQ4_1 in Mojo memory, whose
    stride is 32 bytes (padded), not the packed 20-byte GGUF block, so
    it could not see the stride bug S-083 fixed in gemm_q4_1 /
    dequantize_q4_1. Block 0: scale 2, min 1, qs 0x31 -> lo 3 (x16),
    hi 7 (x16). Block 1: scale 1, min 0, qs 0x11 -> lo 1, hi 1 (x16
    each). Dequantized spot values and the all-ones matvec (160 + 32
    = 192) are checked exactly.
    """
    var well = MimirWell(8192)
    var raw = well.allocate(128).unsafe_bitcast[UInt8]()
    for i in range(40):
        raw.unsafe_store(i, UInt8(0))
    raw.unsafe_bitcast[Float16]().unsafe_store(0, Float16(2.0))
    raw.unsafe_offset(2).unsafe_bitcast[Float16]().unsafe_store(0, Float16(1.0))
    for i in range(16):
        raw.unsafe_store(4 + i, UInt8(0x31))
    raw.unsafe_offset(20).unsafe_bitcast[Float16]().unsafe_store(0, Float16(1.0))
    raw.unsafe_offset(22).unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.0))
    for i in range(16):
        raw.unsafe_store(24 + i, UInt8(0x11))

    var dq = well.allocate(64)
    dequantize_q4_1(raw.unsafe_bitcast[BlockQ4_1](), dq, 2)
    if dq.unsafe_load(0) != Float16(3.0) or dq.unsafe_load(16) != Float16(7.0):
        raise Error("Raw Q4_1 dequantize block 0 mismatch")
    if dq.unsafe_load(32) != Float16(1.0) or dq.unsafe_load(48) != Float16(1.0):
        raise Error("Raw Q4_1 dequantize block 1 mismatch (stride)")

    var input = well.allocate(64)
    for i in range(64):
        input.unsafe_store(i, Float16(1))
    var A = RuneTensor[f16](1, 64, input, False)
    var B = RuneTensor[f16](1, 64, raw.unsafe_bitcast[Float16](), True, CompressedFormatType(CompressedFormatType.Q4_1))
    var C = RuneTensor[f16](1, 1, well.allocate(1), False)
    gemm_f16(A, B, C)
    if C.data.unsafe_load().cast[f32]() != Float32(192):
        raise Error("Raw Q4_1 matvec known-value mismatch")
    _ = well  # Keep the arena alive through every borrowed-pointer read.
    print("raw Q4_1 matvec: PASS")


def test_q5_0_parity() raises:
    """Known-value raw GGUF regression, independent of legacy padded structs."""
    var well = MimirWell(8192)
    var raw = well.allocate(22).unsafe_bitcast[UInt8]()
    for i in range(22):
        raw.unsafe_store(i, UInt8(0))
    raw.unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.5))
    for i in range(4):
        raw.unsafe_store(2 + i, UInt8(1))
    for i in range(16):
        raw.unsafe_store(6 + i, UInt8(49))
    # Sixteen low codes 1, sixteen high codes 3; four extra high bits.
    var expected = Float32(-192)

    var input = well.allocate(32)
    for i in range(32):
        input.unsafe_store(i, Float16(1))
    var A = RuneTensor[f16](1, 32, input, False)
    var B = RuneTensor[f16](1, 32, raw.unsafe_bitcast[Float16](), True, CompressedFormatType(CompressedFormatType.Q5_0))
    var C = RuneTensor[f16](1, 1, well.allocate(1), False)
    gemm_f16(A, B, C)
    if C.data.unsafe_load().cast[f32]() != expected:
        raise Error("Raw Q5_0 matvec known-value mismatch")
    _ = well  # Keep the arena alive through every borrowed-pointer read.
    print("raw Q5_0 matvec: PASS")


def test_q5_1_parity() raises:
    """Known-value raw GGUF regression over two packed 24-byte blocks.

    Same padded-struct blind spot as test_q4_1_parity (S-083). Block 0:
    scale 0.5, min 0.25, qh bytes [1,0,0,0], qs 0x31 -> lo0 = 17*0.5
    + 0.25 = 8.75, lo1..15 = 0.75, hi = 1.75 (x16); block sum 48.
    Block 1: scale 1, min 0, qh all zero, qs 0x22 -> lo 2, hi 2 (x16
    each); block sum 64. All-ones matvec must be exactly 112.
    """
    var well = MimirWell(8192)
    var raw = well.allocate(128).unsafe_bitcast[UInt8]()
    for i in range(48):
        raw.unsafe_store(i, UInt8(0))
    raw.unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.5))
    raw.unsafe_offset(2).unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.25))
    raw.unsafe_store(4, UInt8(1))
    for i in range(16):
        raw.unsafe_store(8 + i, UInt8(0x31))
    raw.unsafe_offset(24).unsafe_bitcast[Float16]().unsafe_store(0, Float16(1.0))
    raw.unsafe_offset(26).unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.0))
    for i in range(16):
        raw.unsafe_store(32 + i, UInt8(0x22))

    var dq = well.allocate(64)
    dequantize_q5_1(raw.unsafe_bitcast[BlockQ5_1](), dq, 2)
    if dq.unsafe_load(0) != Float16(8.75) or dq.unsafe_load(1) != Float16(0.75):
        raise Error("Raw Q5_1 dequantize block 0 mismatch")
    if dq.unsafe_load(16) != Float16(1.75) or dq.unsafe_load(32) != Float16(2.0):
        raise Error("Raw Q5_1 dequantize block 1 mismatch (stride)")

    var input = well.allocate(64)
    for i in range(64):
        input.unsafe_store(i, Float16(1))
    var A = RuneTensor[f16](1, 64, input, False)
    var B = RuneTensor[f16](1, 64, raw.unsafe_bitcast[Float16](), True, CompressedFormatType(CompressedFormatType.Q5_1))
    var C = RuneTensor[f16](1, 1, well.allocate(1), False)
    gemm_f16(A, B, C)
    if C.data.unsafe_load().cast[f32]() != Float32(112):
        raise Error("Raw Q5_1 matvec known-value mismatch")
    _ = well  # Keep the arena alive through every borrowed-pointer read.
    print("raw Q5_1 matvec: PASS")


def main() raises:
    test_q4_0_parity()
    test_q4_1_parity()
    test_q5_0_parity()
    test_q5_1_parity()
