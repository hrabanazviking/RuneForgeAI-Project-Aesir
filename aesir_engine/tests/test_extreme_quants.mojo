"""Unimplemented extreme quantization layouts must fail without mutation."""

from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16
from core.compute import gemm_f16
from core.extreme_quantization import dequantize_iq2_xxs_blocks


def assert_extreme_format_rejected(format: CompressedFormatType, label: String) raises:
    var well = MimirWell(1024 * 1024)
    var rows = 2
    var columns = 256
    var outputs = 2
    var input = RuneTensor[f16](rows, columns, well.allocate(rows * columns), False)
    var weights = RuneTensor[f16](outputs, columns, well.allocate(outputs * columns), True, format)
    var output = RuneTensor[f16](rows, outputs, well.allocate(rows * outputs), False)
    for i in range(rows * columns):
        input.data.unsafe_store(i, Scalar[f16](i + 1))
    for i in range(outputs * columns):
        weights.data.unsafe_store(i, Scalar[f16](i + 1))
    for i in range(rows * outputs):
        output.data.unsafe_store(i, Scalar[f16](197.0))

    var rejected = False
    try:
        gemm_f16(input, weights, output)
    except error:
        rejected = "not implemented" in String(error)
    if not rejected:
        raise Error(label + " was accepted without its authoritative layout")
    for i in range(rows * outputs):
        if output.data.unsafe_load(i) != Scalar[f16](197.0):
            raise Error(label + " rejection mutated output")
    print(label, "explicit mutation-free rejection: PASS")


def test_iq1_s_boundary() raises:
    assert_extreme_format_rejected(CompressedFormatType(CompressedFormatType.IQ1_S), "IQ1_S")


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


def test_ternary_boundary() raises:
    assert_extreme_format_rejected(CompressedFormatType(CompressedFormatType.TERNARY_155BIT), "TERNARY_155BIT")
