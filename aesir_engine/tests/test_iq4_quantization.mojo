"""S-084: raw packed known-value regressions for IQ4_NL (kind 20)
and IQ4_XS (kind 23), multi-block, walking packed bytes only.
Fixtures are built byte-level from the ggml layouts and checked
against values computed by hand from kvalues_iq4nl
(-127,-104,-83,-65,-49,-35,-22,-10,1,13,25,38,53,69,89,113).
Also pins scalar-vs-SIMD bit-identity: dequantize_iq_block (SIMD)
must equal iq_value (scalar) exactly on every lane."""

from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16
from core.compute import gemm_f16
from core.extreme_quantization import (
    dequantize_iq4_nl_blocks,
    dequantize_iq4_xs_blocks,
    dequantize_iq_block,
    iq_value,
    iq_block_bytes,
)
from std.memory import Pointer
from std.memory.alloc import alloc


def _build_nl_raw(mut well: MimirWell) raises -> Pointer[UInt8, MutUntrackedOrigin]:
    # Two 256-value super-blocks (16 NL blocks, 288 bytes). Block b:
    # d = [1, .5, 2, 1, .5, 2, 1, .5][b]; qs[j] low=j, high=(j+b)%16.
    var raw = well.allocate(288).unsafe_bitcast[UInt8]()
    for i in range(288):
        raw.unsafe_store(i, UInt8(0))
    var ds = [Float16(1.0), Float16(0.5), Float16(2.0), Float16(1.0), Float16(0.5), Float16(2.0), Float16(1.0), Float16(0.5)]
    for sb in range(2):
        for b in range(8):
            var off = sb * 144 + b * 18
            raw.unsafe_offset(off).unsafe_bitcast[Float16]().unsafe_store(0, ds[b])
            for j in range(16):
                raw.unsafe_store(off + 2 + j, UInt8(j | (((j + b) % 16) << 4)))
    return raw


def test_iq4_nl_known_value() raises:
    var well = MimirWell(1024 * 1024)
    var raw = _build_nl_raw(well)
    if iq_block_bytes(20) != 144:
        raise Error("IQ4_NL iq_block_bytes must be 144 (8 x 18)")
    # SIMD super-block decode vs scalar iq_value, bit-identical, 512 lanes.
    var grid = alloc[UInt16](2048)
    var out32 = alloc[Float32](256)
    for sb in range(2):
        dequantize_iq_block(raw, sb * 144, 20, grid, out32)
        for i in range(256):
            var scalar = iq_value(raw, 0, 20, sb * 256 + i)
            if out32.unsafe_load(i) != scalar:
                raise Error("IQ4_NL SIMD vs scalar mismatch")
    # Hardcoded spot values (hand-computed from kvalues_iq4nl).
    dequantize_iq_block(raw, 0, 20, grid, out32)
    if out32.unsafe_load(0) != Float32(-127.0) or out32.unsafe_load(15) != Float32(113.0):
        raise Error("IQ4_NL block 0 low-nibble spots mismatch")
    if out32.unsafe_load(16) != Float32(-127.0) or out32.unsafe_load(31) != Float32(113.0):
        raise Error("IQ4_NL block 0 high-nibble spots mismatch")
    if out32.unsafe_load(32) != Float32(-63.5) or out32.unsafe_load(47) != Float32(56.5):
        raise Error("IQ4_NL block 1 (d=0.5) spots mismatch")
    if out32.unsafe_load(48) != Float32(-52.0) or out32.unsafe_load(63) != Float32(-63.5):
        raise Error("IQ4_NL block 1 high-nibble spots mismatch")
    if out32.unsafe_load(64) != Float32(-254.0) or out32.unsafe_load(80) != Float32(-166.0):
        raise Error("IQ4_NL block 2 (d=2) spots mismatch")
    grid.unsafe_free()
    out32.unsafe_free()
    # Whole-tensor f16 dequant over both super-blocks (288 bytes, 512 values).
    var expanded = well.allocate(512 * 2).unsafe_bitcast[Float16]()
    dequantize_iq4_nl_blocks(raw, 288, expanded, 512)
    if expanded.unsafe_load(0) != Float16(-127.0) or expanded.unsafe_load(32) != Float16(-63.5):
        raise Error("IQ4_NL blocks dequant spots mismatch")
    if expanded.unsafe_load(256) != Float16(-127.0) or expanded.unsafe_load(288) != Float16(-63.5):
        raise Error("IQ4_NL blocks dequant super-block 1 mismatch (stride)")
    # GEMM: all-ones row over the first super-block sums to -1598 exactly.
    var input_ptr = well.allocate(256 * 2)
    for i in range(256):
        input_ptr.unsafe_store(i, Scalar[f16](1.0))
    var input = RuneTensor[f16](1, 256, input_ptr, False)
    var weights = RuneTensor[f16](1, 256, raw.unsafe_bitcast[Scalar[f16]](), True, CompressedFormatType(CompressedFormatType.IQ4_NL))
    var output_ptr = well.allocate(2)
    var output = RuneTensor[f16](1, 1, output_ptr, False)
    gemm_f16(input, weights, output)
    if well.offset <= 0:
        raise Error("well lifetime anchor")
    if output.data.unsafe_load(0) != Scalar[f16](-1598.0):
        raise Error("IQ4_NL GEMM disagrees with hand-computed sum")
    # Short-input rejection mutates nothing.
    for i in range(512):
        expanded.unsafe_store(i, Float16(99.0))
    var rejected = False
    try:
        dequantize_iq4_nl_blocks(raw, 287, expanded, 512)
    except:
        rejected = True
    if not rejected:
        raise Error("IQ4_NL accepted short packed storage")
    for i in range(512):
        if expanded.unsafe_load(i) != Float16(99.0):
            raise Error("IQ4_NL short-input rejection mutated output")
    print("IQ4_NL canonical 18-byte blocks, SIMD==scalar, GEMM: PASS")


def _build_xs_raw(mut well: MimirWell) raises -> Pointer[UInt8, MutUntrackedOrigin]:
    # Two 136-byte super-blocks. d=1.0; group ib scale ls = 32 + 3*ib
    # (dl = 3*ib); qs[j] low=(j+ib)%16, high=j%16.
    var raw = well.allocate(272).unsafe_bitcast[UInt8]()
    for i in range(272):
        raw.unsafe_store(i, UInt8(0))
    for sb in range(2):
        var base = sb * 136
        raw.unsafe_offset(base).unsafe_bitcast[Float16]().unsafe_store(0, Float16(1.0))
        var sh = 0
        for ib in range(8):
            var ls = 32 + 3 * ib
            sh |= ((ls >> 4) & 3) << (2 * ib)
            var byte_idx = base + 4 + ib // 2
            var cur = Int(raw.unsafe_load(byte_idx))
            if ib % 2 == 0:
                cur = (cur & 0xF0) | (ls & 15)
            else:
                cur = (cur & 0x0F) | ((ls & 15) << 4)
            raw.unsafe_store(byte_idx, UInt8(cur))
            for j in range(16):
                raw.unsafe_store(base + 8 + ib * 16 + j, UInt8(((j + ib) % 16) | ((j % 16) << 4)))
        raw.unsafe_offset(base + 2).unsafe_bitcast[UInt16]().unsafe_store(0, UInt16(sh))
    return raw


def test_iq4_xs_known_value() raises:
    var well = MimirWell(1024 * 1024)
    var raw = _build_xs_raw(well)
    if iq_block_bytes(23) != 136:
        raise Error("IQ4_XS iq_block_bytes must be 136")
    # Pin the scale packing itself: scales_l bytes and scales_h bytes
    # for ls = 32,35,38,41,44,47,50,53 are fixed byte values.
    if raw.unsafe_load(4) != UInt8(48) or raw.unsafe_load(5) != UInt8(150):
        raise Error("IQ4_XS scales_l packing fixture mismatch")
    if raw.unsafe_load(6) != UInt8(252) or raw.unsafe_load(7) != UInt8(82):
        raise Error("IQ4_XS scales_l packing fixture mismatch (bytes 2-3)")
    if raw.unsafe_load(2) != UInt8(170) or raw.unsafe_load(3) != UInt8(250):
        raise Error("IQ4_XS scales_h packing fixture mismatch")
    var grid = alloc[UInt16](2048)
    var out32 = alloc[Float32](256)
    for sb in range(2):
        dequantize_iq_block(raw, sb * 136, 23, grid, out32)
        for i in range(256):
            var scalar = iq_value(raw, 0, 23, sb * 256 + i)
            if out32.unsafe_load(i) != scalar:
                raise Error("IQ4_XS SIMD vs scalar mismatch")
    dequantize_iq_block(raw, 0, 23, grid, out32)
    if out32.unsafe_load(0) != Float32(0.0) or out32.unsafe_load(31) != Float32(0.0):
        raise Error("IQ4_XS group 0 (dl=0) must decode to zero")
    if out32.unsafe_load(32) != Float32(-312.0) or out32.unsafe_load(47) != Float32(-381.0):
        raise Error("IQ4_XS group 1 (dl=3) low spots mismatch")
    if out32.unsafe_load(48) != Float32(-381.0) or out32.unsafe_load(63) != Float32(339.0):
        raise Error("IQ4_XS group 1 high spots mismatch")
    if out32.unsafe_load(224) != Float32(-210.0) or out32.unsafe_load(239) != Float32(-462.0):
        raise Error("IQ4_XS group 7 (dl=21) low spots mismatch")
    if out32.unsafe_load(240) != Float32(-2667.0):
        raise Error("IQ4_XS group 7 high spot mismatch")
    grid.unsafe_free()
    out32.unsafe_free()
    var expanded = well.allocate(512 * 2).unsafe_bitcast[Float16]()
    dequantize_iq4_xs_blocks(raw, 272, expanded, 512)
    if expanded.unsafe_load(32) != Float16(-312.0) or expanded.unsafe_load(48) != Float16(-381.0):
        raise Error("IQ4_XS blocks dequant spots mismatch")
    if expanded.unsafe_load(256 + 32) != Float16(-312.0):
        raise Error("IQ4_XS blocks dequant super-block 1 mismatch (stride)")
    var input_ptr = well.allocate(256 * 2)
    for i in range(256):
        input_ptr.unsafe_store(i, Scalar[f16](1.0))
    var input = RuneTensor[f16](1, 256, input_ptr, False)
    var weights = RuneTensor[f16](1, 256, raw.unsafe_bitcast[Scalar[f16]](), True, CompressedFormatType(CompressedFormatType.IQ4_XS))
    var output_ptr = well.allocate(2)
    var output = RuneTensor[f16](1, 1, output_ptr, False)
    gemm_f16(input, weights, output)
    if well.offset <= 0:
        raise Error("well lifetime anchor")
    if output.data.unsafe_load(0) != Scalar[f16](-15792.0):
        raise Error("IQ4_XS GEMM disagrees with hand-computed sum")
    for i in range(512):
        expanded.unsafe_store(i, Float16(99.0))
    var rejected = False
    try:
        dequantize_iq4_xs_blocks(raw, 271, expanded, 512)
    except:
        rejected = True
    if not rejected:
        raise Error("IQ4_XS accepted short packed storage")
    for i in range(512):
        if expanded.unsafe_load(i) != Float16(99.0):
            raise Error("IQ4_XS short-input rejection mutated output")
    print("IQ4_XS canonical 136-byte super-block, SIMD==scalar, GEMM: PASS")


def main() raises:
    test_iq4_nl_known_value()
    test_iq4_xs_known_value()
    print("IQ4 family tests: ALL PASS")
