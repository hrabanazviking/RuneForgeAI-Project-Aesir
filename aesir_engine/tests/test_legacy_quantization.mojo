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
    print("--- Testing fused Q4_1 GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var block_layout = Layout[BlockQ4_1](count=1)
    var block_alloc = alloc(block_layout)
    var block_mem = block_alloc^.unsafe_leak().unsafe_bitcast[BlockQ4_1]()
    
    # scale = 2.0, min = 1.0, qs = 0x31 (lower = 1, upper = 3 -> val_lo = 1*2+1 = 3.0, val_hi = 3*2+1 = 7.0)
    block_mem[] = BlockQ4_1(
        scale=Scalar[f16](2.0),
        min_val=Scalar[f16](1.0),
        qs=SIMD[DType.uint8, 16](0x31)
    )

    var f16_w_ptr = well.allocate(32)
    dequantize_q4_1(block_mem, f16_w_ptr, 1)

    var B_f16 = RuneTensor[f16](1, 32, f16_w_ptr, False)
    var quant_w_ptr = block_mem.unsafe_bitcast[Scalar[f16]]()
    var B_quant = RuneTensor[f16](1, 32, quant_w_ptr, True, CompressedFormatType(CompressedFormatType.Q4_1))

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
        raise Error("fused Q4_1 GEMM output mismatch vs uncompressed gemm_f16")
    print("fused Q4_1 GEMM parity: PASS")


def test_q5_0_parity() raises:
    print("--- Testing fused Q5_0 GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var block_layout = Layout[BlockQ5_0](count=1)
    var block_alloc = alloc(block_layout)
    var block_mem = block_alloc^.unsafe_leak().unsafe_bitcast[BlockQ5_0]()
    
    # scale = 0.5, qh = 0x01 (1st element high bit set = 1), qs = 0x31
    block_mem[] = BlockQ5_0(
        scale=Scalar[f16](0.5),
        qh=SIMD[DType.uint8, 4](0x01),
        qs=SIMD[DType.uint8, 16](0x31)
    )

    var f16_w_ptr = well.allocate(32)
    dequantize_q5_0(block_mem, f16_w_ptr, 1)

    var B_f16 = RuneTensor[f16](1, 32, f16_w_ptr, False)
    var quant_w_ptr = block_mem.unsafe_bitcast[Scalar[f16]]()
    var B_quant = RuneTensor[f16](1, 32, quant_w_ptr, True, CompressedFormatType(CompressedFormatType.Q5_0))

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
        raise Error("fused Q5_0 GEMM output mismatch vs uncompressed gemm_f16")
    print("fused Q5_0 GEMM parity: PASS")


def test_q5_1_parity() raises:
    print("--- Testing fused Q5_1 GEMM parity against uncompressed gemm_f16 ---")
    var well = MimirWell(1024 * 1024)
    var block_layout = Layout[BlockQ5_1](count=1)
    var block_alloc = alloc(block_layout)
    var block_mem = block_alloc^.unsafe_leak().unsafe_bitcast[BlockQ5_1]()
    
    # scale = 0.5, min = 0.2, qh = 0x01, qs = 0x31
    block_mem[] = BlockQ5_1(
        scale=Scalar[f16](0.5),
        min_val=Scalar[f16](0.2),
        qh=SIMD[DType.uint8, 4](0x01),
        qs=SIMD[DType.uint8, 16](0x31)
    )

    var f16_w_ptr = well.allocate(32)
    dequantize_q5_1(block_mem, f16_w_ptr, 1)

    var B_f16 = RuneTensor[f16](1, 32, f16_w_ptr, False)
    var quant_w_ptr = block_mem.unsafe_bitcast[Scalar[f16]]()
    var B_quant = RuneTensor[f16](1, 32, quant_w_ptr, True, CompressedFormatType(CompressedFormatType.Q5_1))

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
        raise Error("fused Q5_1 GEMM output mismatch vs uncompressed gemm_f16")
    print("fused Q5_1 GEMM parity: PASS")


def main() raises:
    test_q4_0_parity()
    test_q4_1_parity()
    test_q5_0_parity()
    test_q5_1_parity()
