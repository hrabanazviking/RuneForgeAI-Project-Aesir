"""Oracle-backed tests for canonical GGML extreme quantization layouts."""

from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16
from core.compute import gemm_f16
from core.extreme_quantization import (
    dequantize_iq1_s_blocks,
    dequantize_iq2_xxs_blocks,
    dequantize_tq1_0_blocks,
)


def test_iq1_s_known_value() raises:
    var well = MimirWell(1024 * 1024)
    var packed = well.allocate(50).unsafe_bitcast[UInt8]()
    var expanded = well.allocate(256 * 2).unsafe_bitcast[Float16]()
    var input_ptr = well.allocate(256 * 2)
    var output_ptr = well.allocate(2)
    for i in range(50):
        packed.unsafe_store(i, UInt8(0))
    # F16 scale 2.0. The first group selects four grid entries using both
    # low bytes and packed high bits, scale code 3, and negative delta.
    packed.unsafe_store(0, UInt8(0))
    packed.unsafe_store(1, UInt8(64))
    packed.unsafe_store(2, UInt8(0))
    packed.unsafe_store(3, UInt8(1))
    packed.unsafe_store(4, UInt8(2))
    packed.unsafe_store(5, UInt8(255))
    packed.unsafe_store(34, UInt8(136))
    packed.unsafe_store(35, UInt8(190))

    dequantize_iq1_s_blocks(packed, 50, expanded, 256)
    var expected_first = [
        Float16(-15.75), Float16(-15.75), Float16(-15.75), Float16(-15.75),
        Float16(-15.75), Float16(-15.75), Float16(-15.75), Float16(-15.75),
        Float16(12.25), Float16(-1.75), Float16(12.25), Float16(-1.75),
        Float16(12.25), Float16(-15.75), Float16(-1.75), Float16(-15.75),
        Float16(-1.75), Float16(-1.75), Float16(-15.75), Float16(-1.75),
        Float16(-15.75), Float16(-1.75), Float16(12.25), Float16(-15.75),
        Float16(12.25), Float16(12.25), Float16(12.25), Float16(12.25),
        Float16(12.25), Float16(12.25), Float16(12.25), Float16(12.25),
    ]
    for i in range(32):
        if expanded.unsafe_load(i) != expected_first[i]:
            raise Error("IQ1_S grid/high-index/scale/delta fixture mismatch")
    var sum = Float32(0.0)
    for i in range(256):
        sum += expanded.unsafe_load(i).cast[DType.float32]()
    if sum != Float32(-462.0):
        raise Error("IQ1_S oracle block sum mismatch")

    for i in range(256):
        input_ptr.unsafe_store(i, Scalar[f16](1.0))
    var input = RuneTensor[f16](1, 256, input_ptr, False)
    var weights = RuneTensor[f16](
        1,
        256,
        packed.unsafe_bitcast[Scalar[f16]](),
        True,
        CompressedFormatType(CompressedFormatType.IQ1_S),
    )
    var output = RuneTensor[f16](1, 1, output_ptr, False)
    gemm_f16(input, weights, output)
    if output.data.unsafe_load(0) != Scalar[f16](-462.0):
        raise Error("IQ1_S GEMM disagrees with independent oracle sum")

    for i in range(256):
        expanded.unsafe_store(i, Float16(99.0))
    var rejected = False
    try:
        dequantize_iq1_s_blocks(packed, 49, expanded, 256)
    except:
        rejected = True
    if not rejected:
        raise Error("IQ1_S accepted short packed storage")
    for i in range(256):
        if expanded.unsafe_load(i) != Float16(99.0):
            raise Error("IQ1_S short-input rejection mutated output")
    print("IQ1_S canonical 50-byte block and GEMM: PASS")


def test_iq2_xxs_known_value() raises:
    var well = MimirWell(1024 * 1024)
    var packed = well.allocate(66).unsafe_bitcast[UInt8]()
    var expanded = well.allocate(256 * 2).unsafe_bitcast[Float16]()
    var input_ptr = well.allocate(256 * 2)
    var output_ptr = well.allocate(2)
    for i in range(66):
        packed.unsafe_store(i, UInt8(0))
    # F16 scale 2.0. The first 32-value group uses four distinct grid
    # indices, four distinct 7-bit sign indices, and scale code 15.
    packed.unsafe_store(0, UInt8(0))
    packed.unsafe_store(1, UInt8(64))
    packed.unsafe_store(2, UInt8(0))
    packed.unsafe_store(3, UInt8(1))
    packed.unsafe_store(4, UInt8(2))
    packed.unsafe_store(5, UInt8(255))
    packed.unsafe_store(6, UInt8(128))
    packed.unsafe_store(7, UInt8(128))
    packed.unsafe_store(8, UInt8(224))
    packed.unsafe_store(9, UInt8(255))

    dequantize_iq2_xxs_blocks(packed, 66, expanded, 256)
    var expected_first = [
        Float16(62.0), Float16(62.0), Float16(62.0), Float16(62.0),
        Float16(62.0), Float16(62.0), Float16(62.0), Float16(62.0),
        Float16(-333.25), Float16(62.0), Float16(62.0), Float16(62.0),
        Float16(62.0), Float16(62.0), Float16(62.0), Float16(-62.0),
        Float16(193.75), Float16(-193.75), Float16(62.0), Float16(62.0),
        Float16(62.0), Float16(62.0), Float16(62.0), Float16(-62.0),
        Float16(-62.0), Float16(-193.75), Float16(-62.0), Float16(-62.0),
        Float16(-193.75), Float16(-333.25), Float16(-333.25), Float16(-333.25),
    ]
    for i in range(32):
        if expanded.unsafe_load(i) != expected_first[i]:
            raise Error("IQ2_XXS codebook/sign/scale fixture mismatch")
    var sum = Float32(0.0)
    for i in range(256):
        sum += expanded.unsafe_load(i).cast[DType.float32]()
    if sum != Float32(-404.5):
        raise Error("IQ2_XXS oracle block sum mismatch")

    for i in range(256):
        input_ptr.unsafe_store(i, Scalar[f16](1.0))
    var input = RuneTensor[f16](1, 256, input_ptr, False)
    var weights = RuneTensor[f16](
        1,
        256,
        packed.unsafe_bitcast[Scalar[f16]](),
        True,
        CompressedFormatType(CompressedFormatType.IQ2_XXS),
    )
    var output = RuneTensor[f16](1, 1, output_ptr, False)
    gemm_f16(input, weights, output)
    if output.data.unsafe_load(0) != Scalar[f16](-404.5):
        raise Error("IQ2_XXS GEMM disagrees with independent oracle sum")

    for i in range(256):
        expanded.unsafe_store(i, Float16(99.0))
    var rejected = False
    try:
        dequantize_iq2_xxs_blocks(packed, 65, expanded, 256)
    except:
        rejected = True
    if not rejected:
        raise Error("IQ2_XXS accepted short packed storage")
    for i in range(256):
        if expanded.unsafe_load(i) != Float16(99.0):
            raise Error("IQ2_XXS short-input rejection mutated output")
    print("IQ2_XXS canonical 66-byte block and GEMM: PASS")


def test_tq1_0_known_value() raises:
    var well = MimirWell(1024 * 1024)
    var packed = well.allocate(54).unsafe_bitcast[UInt8]()
    var expanded = well.allocate(256 * 2).unsafe_bitcast[Float16]()
    var input_ptr = well.allocate(256 * 2)
    var output_ptr = well.allocate(2)
    # Independent gguf-py oracle fixture: deterministic packed trits followed
    # by an F16 scale of 2.0 at bytes 52..53.
    for i in range(52):
        packed.unsafe_store(i, UInt8((i * 37 + 11) % 256))
    packed.unsafe_store(52, UInt8(0))
    packed.unsafe_store(53, UInt8(64))

    dequantize_tq1_0_blocks(packed, 54, expanded, 256)
    var indices = [
        0, 1, 2, 3, 4, 5, 6, 7, 31, 32, 64, 128, 159, 160, 175, 176,
        239, 240, 243, 244, 255,
    ]
    var expected = [
        Float16(-2.0), Float16(-2.0), Float16(-2.0), Float16(0.0),
        Float16(0.0), Float16(2.0), Float16(2.0), Float16(-2.0),
        Float16(0.0), Float16(-2.0), Float16(0.0), Float16(0.0),
        Float16(0.0), Float16(2.0), Float16(2.0), Float16(-2.0),
        Float16(2.0), Float16(2.0), Float16(0.0), Float16(2.0),
        Float16(-2.0),
    ]
    for i in range(len(indices)):
        if expanded.unsafe_load(indices[i]) != expected[i]:
            raise Error("TQ1_0 packed-trit fixture mismatch")
    var sum = Float32(0.0)
    for i in range(256):
        sum += expanded.unsafe_load(i).cast[DType.float32]()
    if sum != Float32(-4.0):
        raise Error("TQ1_0 oracle block sum mismatch")

    for i in range(256):
        input_ptr.unsafe_store(i, Scalar[f16](1.0))
    var input = RuneTensor[f16](1, 256, input_ptr, False)
    var weights = RuneTensor[f16](
        1,
        256,
        packed.unsafe_bitcast[Scalar[f16]](),
        True,
        CompressedFormatType(CompressedFormatType.TQ1_0),
    )
    var output = RuneTensor[f16](1, 1, output_ptr, False)
    gemm_f16(input, weights, output)
    if output.data.unsafe_load(0) != Scalar[f16](-4.0):
        raise Error("TQ1_0 GEMM disagrees with independent oracle sum")

    for i in range(256):
        expanded.unsafe_store(i, Float16(99.0))
    var rejected = False
    try:
        dequantize_tq1_0_blocks(packed, 53, expanded, 256)
    except:
        rejected = True
    if not rejected:
        raise Error("TQ1_0 accepted short packed storage")
    for i in range(256):
        if expanded.unsafe_load(i) != Float16(99.0):
            raise Error("TQ1_0 short-input rejection mutated output")
    print("TQ1_0 canonical 54-byte block and GEMM: PASS")
