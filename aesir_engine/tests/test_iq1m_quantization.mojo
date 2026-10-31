"""S-087: raw packed known-value regressions for IQ1_M (kind 29),
multi-block, walking packed bytes only. Fixtures are built byte-level
from the ggml block_iq1_m layout (56 bytes per 256 values: qs[32] at
+0, qh[16] at +32, scales[8] at +48; no leading f16) and checked
against values computed by hand from ggml dequantize_row_iq1_m.
Also pins scalar-vs-SIMD bit-identity: dequantize_iq_block (SIMD)
must equal iq_value (scalar) exactly on every lane."""

from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16
from core.compute import gemm_f16
from core.extreme_quantization import (
    dequantize_iq1_m_blocks,
    dequantize_iq_block,
    iq_value,
    iq_block_bytes,
    iq_grid_materialize,
)
from std.memory import Pointer
from std.memory.alloc import alloc


def _build_raw(mut well: MimirWell) raises -> Pointer[UInt8, MutUntrackedOrigin]:
    # Two 56-byte super-blocks (112 bytes). Scale words pin d = 1.0:
    # scale.u16 is assembled from the top nibbles of the four scale
    # words: 0x0 | 0x00 | 0xC00 | 0x3000 = 0x3C00 (f16 1.0).
    # Per-half-group multipliers (2*field + 1), groups 0..7:
    # (1,3) (5,7) (9,11) (7,1) (13,3) (15,5) (1,15) (11,13).
    var raw = well.allocate(112).unsafe_bitcast[UInt8]()
    for i in range(112):
        raw.unsafe_store(i, UInt8(0))
    var sc = [UInt16(0x0688), UInt16(0x00EC), UInt16(0xC5CE), UInt16(0x3D78)]
    for sb in range(2):
        var base = sb * 56
        for w in range(4):
            raw.unsafe_offset(base + 48 + w * 2).unsafe_bitcast[UInt16]().unsafe_store(0, sc[w])
    # Super-block 1: varied qs/qh so grid indices and delta signs are
    # exercised (its scales are the same words, written above).
    for j in range(32):
        raw.unsafe_store(56 + j, UInt8((j * 37 + 11) % 256))
    for j in range(16):
        raw.unsafe_store(56 + 32 + j, UInt8((j * 91 + 0x88) % 256))
    return raw


def test_iq1_m_known_value() raises:
    var well = MimirWell(1024 * 1024)
    var raw = _build_raw(well)
    if iq_block_bytes(29) != 56:
        raise Error("IQ1_M iq_block_bytes must be 56")
    # Pin the scale packing itself as raw bytes (little-endian u16s).
    if raw.unsafe_load(48) != UInt8(0x88) or raw.unsafe_load(49) != UInt8(0x06):
        raise Error("IQ1_M scales word 0 packing fixture mismatch")
    if raw.unsafe_load(50) != UInt8(0xEC) or raw.unsafe_load(51) != UInt8(0x00):
        raise Error("IQ1_M scales word 1 packing fixture mismatch")
    if raw.unsafe_load(52) != UInt8(0xCE) or raw.unsafe_load(53) != UInt8(0xC5):
        raise Error("IQ1_M scales word 2 packing fixture mismatch")
    if raw.unsafe_load(54) != UInt8(0x78) or raw.unsafe_load(55) != UInt8(0x3D):
        raise Error("IQ1_M scales word 3 packing fixture mismatch")
    var grid = alloc[UInt16](2048)
    iq_grid_materialize(29, grid)
    var out32 = alloc[Float32](256)
    # SIMD super-block decode vs scalar iq_value, bit-identical, 512 lanes.
    for sb in range(2):
        dequantize_iq_block(raw, sb * 56, 29, grid, out32)
        for i in range(256):
            var scalar = iq_value(raw, 0, 29, sb * 256 + i)
            if out32.unsafe_load(i) != scalar:
                raise Error("IQ1_M SIMD vs scalar mismatch")
    # Hardcoded spots, super-block 0: qs/qh all zero -> grid index 0
    # (every grid value -1), delta +0.125, so value = -0.875 * mult.
    dequantize_iq_block(raw, 0, 29, grid, out32)
    if out32.unsafe_load(0) != Float32(-0.875) or out32.unsafe_load(7) != Float32(-0.875):
        raise Error("IQ1_M group 0 first-half spots mismatch")
    if out32.unsafe_load(16) != Float32(-2.625) or out32.unsafe_load(31) != Float32(-2.625):
        raise Error("IQ1_M group 0 second-half spots mismatch")
    if out32.unsafe_load(32) != Float32(-4.375):
        raise Error("IQ1_M group 1 first-half spot mismatch")
    if out32.unsafe_load(48) != Float32(-6.125):
        raise Error("IQ1_M group 1 second-half spot mismatch")
    if out32.unsafe_load(128) != Float32(-11.375):
        raise Error("IQ1_M group 4 first-half spot mismatch")
    if out32.unsafe_load(224) != Float32(-9.625) or out32.unsafe_load(240) != Float32(-11.375):
        raise Error("IQ1_M group 7 spots mismatch")
    grid.unsafe_free()
    out32.unsafe_free()
    # Whole-tensor f16 dequant over both super-blocks (112 B, 512 values).
    var expanded = well.allocate(512 * 2).unsafe_bitcast[Float16]()
    dequantize_iq1_m_blocks(raw, 112, expanded, 512)
    if expanded.unsafe_load(0) != Float16(-0.875) or expanded.unsafe_load(16) != Float16(-2.625):
        raise Error("IQ1_M blocks dequant spots mismatch")
    # Super-block 1 lane 0: qs=11, qh=0x88 -> grid index 11, delta
    # -0.125; grid entry 11 has lane values [0, 0, -1, ...], and the
    # group-0 first-half multiplier is 1, so lane 0 = -0.125 exactly
    # and lane 2 = -1.125 exactly.
    if expanded.unsafe_load(256) != Float16(-0.125) or expanded.unsafe_load(258) != Float16(-1.125):
        raise Error("IQ1_M blocks dequant super-block 1 mismatch (stride/grid/delta)")
    # GEMM: all-ones row over super-block 0 sums to -1680 exactly
    # (-14 * (4+12+20+8+16+20+16+24) over the eight groups).
    var input_ptr = well.allocate(256 * 2)
    for i in range(256):
        input_ptr.unsafe_store(i, Scalar[f16](1.0))
    var input = RuneTensor[f16](1, 256, input_ptr, False)
    var weights = RuneTensor[f16](1, 256, raw.unsafe_bitcast[Scalar[f16]](), True, CompressedFormatType(CompressedFormatType.IQ1_M))
    var output_ptr = well.allocate(2)
    var output = RuneTensor[f16](1, 1, output_ptr, False)
    gemm_f16(input, weights, output)
    if well.offset <= 0:
        raise Error("well lifetime anchor")
    if output.data.unsafe_load(0) != Scalar[f16](-1680.0):
        raise Error("IQ1_M GEMM disagrees with hand-computed sum")
    # Short-input rejection mutates nothing.
    for i in range(512):
        expanded.unsafe_store(i, Float16(99.0))
    var rejected = False
    try:
        dequantize_iq1_m_blocks(raw, 111, expanded, 512)
    except:
        rejected = True
    if not rejected:
        raise Error("IQ1_M accepted short packed storage")
    for i in range(512):
        if expanded.unsafe_load(i) != Float16(99.0):
            raise Error("IQ1_M short-input rejection mutated output")
    print("IQ1_M canonical 56-byte super-block, SIMD==scalar, GEMM: PASS")


def main() raises:
    test_iq1_m_known_value()
    print("IQ1_M tests: ALL PASS")
