# tests/test_dequantize_input_qc_3b.mojo
# QC-3b stage 2 proof: the dequantizing input path
# (core/dequantize_input.mojo) returns the engine dequantizers'
# documented F32 output on hand-built blocks, per covered type.
#
# Method (QC-2 harness style): for each K-quant type in the
# gemma-4-E2B census (Q4_K / Q5_K / Q6_K), one 256-value block is
# built byte by byte from the QC-0-PLAN section 1b layout, with
# scales/mins/quants chosen so the expected values are known two
# independent ways: (a) literal hand-computed constants on named
# lanes, (b) a longhand re-derivation of the documented formula
# for all 256 lanes, written from the layout text -- NOT by
# calling the code under test. The path under test closes through
# core/packed_quantization.packed_value only. Dense F32/F16/BF16
# passthroughs and the named refusals for unwired types are
# asserted too.

from std.memory import bitcast

from core.dequantize_input import (
    dequant_input_keep_reason,
    dequant_input_supported,
    dequantize_range_f32,
    dequantize_value_f32,
)
from core.mimir_well import MimirWell
from core.packed_quantization import Bytes


def check(condition: Bool, label: String) raises:
    if not condition:
        raise Error("QC-3b dequant-input check failed: " + label)


def check_f32(actual: Float32, expected: Float32, label: String) raises:
    if actual != expected:
        raise Error(
            "QC-3b dequant-input value mismatch (" + label + "): got "
            + String(actual) + ", expected " + String(expected)
        )


def well_bytes(mut well: MimirWell, data: List[UInt8]) raises -> Bytes:
    # Copies a byte list into a MimirWell allocation and returns the
    # raw pointer -- the codebase's proven pattern for feeding byte
    # fixtures to the packed readers (List.unsafe_ptr does not alias
    # list storage in this toolchain; the QC-2/hardening tests all
    # stage bytes through MimirWell the same way). The caller keeps
    # the well alive for the pointer's lifetime.
    var buf = well.allocate((len(data) + 1) // 2).unsafe_bitcast[UInt8]()
    for i in range(len(data)):
        buf.unsafe_store(i, data[i])
    return buf


def q4_of(j: Int) -> Int:
    return (j * 7 + 3) % 16


def build_q4k_block() -> List[UInt8]:
    # d = 0.5 (f16 0x3800), dmin = 0.25 (f16 0x3400).
    # Sub-block scales 10..17, mins all 3, packed per the layout:
    # bytes 4..7 low 6 bits = scales of groups 0..3, top 2 bits =
    # high bits of scales of groups 4..7; bytes 8..11 likewise for
    # mins; bytes 12..15 = (min low 4 bits << 4) | scale low 4 bits
    # for groups 4..7.
    var block = List[UInt8]()
    block.resize(144, UInt8(0))
    block[0] = 0x00
    block[1] = 0x38
    block[2] = 0x00
    block[3] = 0x34
    block[4] = 10
    block[5] = 11
    block[6] = 76
    block[7] = 77
    block[8] = 3
    block[9] = 3
    block[10] = 3
    block[11] = 3
    block[12] = 62
    block[13] = 63
    block[14] = 48
    block[15] = 49
    for j in range(256):
        var pos = 16 + (j // 64) * 32 + (j % 32)
        var shift = 4 * ((j // 32) % 2)
        block[pos] = block[pos] | UInt8((q4_of(j) << shift) & 0xFF)
    return block^


def expected_k(j: Int, q: Int) -> Float32:
    var scales = List[Int]()
    for g in range(8):
        scales.append(10 + g)
    var g = j // 32
    return Float32(0.5) * Float32(scales[g] * q) - Float32(0.25) * Float32(3)


def test_q4k(block_in: List[UInt8]) raises:
    var block = block_in.copy()
    var well = MimirWell(65536)
    var ptr = well_bytes(well, block)
    for j in range(256):
        var value = dequantize_value_f32(ptr, 0, 12, j)
        check_f32(value, expected_k(j, q4_of(j)), "Q4_K lane " + String(j))
    # Hand-computed constants (d=0.5, dmin=0.25, min=3):
    # lane 0:   g0 scale10 q3  -> 0.5*30 - 0.75 = 14.25
    # lane 100: g3 scale13 q15 -> 0.5*195 - 0.75 = 96.75
    # lane 200: g6 scale16 q11 -> 0.5*176 - 0.75 = 87.25
    check_f32(dequantize_value_f32(ptr, 0, 12, 0), Float32(14.25), "Q4_K hand lane 0")
    check_f32(dequantize_value_f32(ptr, 0, 12, 100), Float32(96.75), "Q4_K hand lane 100")
    check_f32(dequantize_value_f32(ptr, 0, 12, 200), Float32(87.25), "Q4_K hand lane 200")
    var row = dequantize_range_f32(ptr, 0, 12, 0, 256)
    check(len(row) == 256, "Q4_K range length")
    check_f32(row[200], Float32(87.25), "Q4_K range lane 200")
    print("PASS: Q4_K hand-built block -- all 256 lanes exact (incl. g>=4 packed scale/min reconstruction), hand lanes 14.25 / 96.75 / 87.25")


def build_q5k_block() -> List[UInt8]:
    # Same header/scales/mins as the Q4_K block; qs move to @48 and
    # the high bits live in qh bytes @16..47 (bit g of byte 16+lane).
    # High bit set exactly when j % 5 == 0.
    var block = List[UInt8]()
    block.resize(176, UInt8(0))
    block[0] = 0x00
    block[1] = 0x38
    block[2] = 0x00
    block[3] = 0x34
    block[4] = 10
    block[5] = 11
    block[6] = 76
    block[7] = 77
    block[8] = 3
    block[9] = 3
    block[10] = 3
    block[11] = 3
    block[12] = 62
    block[13] = 63
    block[14] = 48
    block[15] = 49
    for j in range(256):
        var pos = 48 + (j // 64) * 32 + (j % 32)
        var shift = 4 * ((j // 32) % 2)
        block[pos] = block[pos] | UInt8((q4_of(j) << shift) & 0xFF)
        if j % 5 == 0:
            block[16 + (j % 32)] = block[16 + (j % 32)] | UInt8(1 << (j // 32))
    return block^


def test_q5k() raises:
    var block = build_q5k_block()
    var well = MimirWell(65536)
    var ptr = well_bytes(well, block)
    for j in range(256):
        var q = q4_of(j) + (16 if j % 5 == 0 else 0)
        var value = dequantize_value_f32(ptr, 0, 13, j)
        check_f32(value, expected_k(j, q), "Q5_K lane " + String(j))
    # Hand constants: lane 0: q = 3 + 16 = 19 -> 0.5*190 - 0.75 = 94.25
    # lane 10: q = 9 + 16 = 25 -> 0.5*250 - 0.75 = 124.25
    check_f32(dequantize_value_f32(ptr, 0, 13, 0), Float32(94.25), "Q5_K hand lane 0")
    check_f32(dequantize_value_f32(ptr, 0, 13, 10), Float32(124.25), "Q5_K hand lane 10")
    print("PASS: Q5_K hand-built block -- all 256 lanes exact (high-bit lanes included), hand lanes 94.25 / 124.25")


def q6_of(j: Int) -> Int:
    return (j * 11 + 7) % 64


def build_q6k_block() -> List[UInt8]:
    # ql 128 B @0, qh 64 B @128, 16 signed scales @192 (s - 4 for
    # s in 0..15, so -4..11 incl. negatives), d = 0.5 @208.
    var block = List[UInt8]()
    block.resize(210, UInt8(0))
    for s in range(16):
        block[192 + s] = UInt8((s - 4) & 0xFF)
    block[208] = 0x00
    block[209] = 0x38
    for j in range(256):
        var half = j // 128
        var group = (j % 128) // 32
        var lane = j % 32
        var q = q6_of(j)
        var ql_pos = half * 64 + (group % 2) * 32 + lane
        block[ql_pos] = block[ql_pos] | UInt8(((q & 15) << (4 * (group // 2))) & 0xFF)
        var qh_pos = 128 + half * 32 + lane
        block[qh_pos] = block[qh_pos] | UInt8((((q >> 4) & 3) << (2 * group)) & 0xFF)
    return block^


def test_q6k() raises:
    var block = build_q6k_block()
    var well = MimirWell(65536)
    var ptr = well_bytes(well, block)
    for j in range(256):
        var half = j // 128
        var group = (j % 128) // 32
        var lane = j % 32
        var scale = (half * 8 + group * 2 + lane // 16) - 4
        var expected = Float32(0.5) * Float32(scale) * Float32(q6_of(j) - 32)
        var value = dequantize_value_f32(ptr, 0, 14, j)
        check_f32(value, expected, "Q6_K lane " + String(j))
    # Hand constants: lane 0: q7, scale -4 -> 0.5 * -4 * -25 = 50.0
    # lane 33: q50, scale -2 -> 0.5 * -2 * 18 = -18.0
    check_f32(dequantize_value_f32(ptr, 0, 14, 0), Float32(50.0), "Q6_K hand lane 0")
    check_f32(dequantize_value_f32(ptr, 0, 14, 33), Float32(-18.0), "Q6_K hand lane 33")
    print("PASS: Q6_K hand-built block -- all 256 lanes exact (signed scales incl. negatives), hand lanes 50.0 / -18.0")


def test_dense() raises:
    var f32_bytes = List[UInt8]()
    for value in [Float32(1.5), Float32(-2.25), Float32(0.0), Float32(100.5)]:
        var bits = bitcast[DType.uint32](value)
        for shift in range(4):
            f32_bytes.append(UInt8((bits >> UInt32(shift * 8)) & 0xFF))
    var well = MimirWell(65536)
    var ptr = well_bytes(well, f32_bytes)
    check_f32(dequantize_value_f32(ptr, 0, 0, 0), Float32(1.5), "F32 lane 0")
    check_f32(dequantize_value_f32(ptr, 0, 0, 1), Float32(-2.25), "F32 lane 1")
    check_f32(dequantize_value_f32(ptr, 0, 0, 3), Float32(100.5), "F32 lane 3")
    var f16_bytes = List[UInt8]()
    f16_bytes.append(0x00)
    f16_bytes.append(0x3E)  # 1.5 in f16 (0x3E00, little-endian)
    f16_bytes.append(0x00)
    f16_bytes.append(0xC0)  # -2.0 in f16 (0xC000)
    var ptr16 = well_bytes(well, f16_bytes)
    check_f32(dequantize_value_f32(ptr16, 0, 1, 0), Float32(1.5), "F16 lane 0")
    check_f32(dequantize_value_f32(ptr16, 0, 1, 1), Float32(-2.0), "F16 lane 1")
    var bf16_bytes = List[UInt8]()
    bf16_bytes.append(0xC0)
    bf16_bytes.append(0x3F)  # 1.5 in bf16 (0x3FC0, little-endian)
    var ptrb = well_bytes(well, bf16_bytes)
    check_f32(dequantize_value_f32(ptrb, 0, 30, 0), Float32(1.5), "BF16 lane 0")
    print("PASS: dense passthroughs F32 / F16 / BF16 exact")


def test_refusals() raises:
    check(dequant_input_supported(12), "Q4_K supported")
    check(dequant_input_supported(13), "Q5_K supported")
    check(dequant_input_supported(14), "Q6_K supported")
    check(dequant_input_supported(0), "F32 supported")
    check(dequant_input_supported(1), "F16 supported")
    check(dequant_input_supported(30), "BF16 supported")
    for t in [2, 3, 6, 7, 8, 9, 10, 11, 15, 20, 23]:
        check(not dequant_input_supported(t), "type " + String(t) + " refused")
    var block = build_q4k_block()
    var well = MimirWell(65536)
    var ptr = well_bytes(well, block)
    var refused = False
    try:
        _ = dequantize_value_f32(ptr, 0, 2, 0)
    except:
        refused = True
    check(refused, "dequantize_value_f32 raises for Q4_0 (type 2)")
    check(len(dequant_input_keep_reason(2).as_bytes()) > 0, "keep reason names the refusal")
    print("PASS: unwired types refused by name (2,3,6,7,8,9,10,11,15,20,23); keep-reason string present")


def main() raises:
    var block = build_q4k_block()
    test_q4k(block)
    test_q5k()
    test_q6k()
    test_dense()
    test_refusals()
    print("QC-3b dequantizing input path proof: ALL PASS")
