"""A-039 parity battery: wide-SIMD IQ dequant vs the scalar decoders.

For every IQ format present in the engine, a deterministic varied
fixture is decoded twice: once through dequantize_*_blocks (the
A-039 wide-SIMD path, built on dequantize_iq_block) and once through
the scalar per-element iq_value_g decoder, which is the original
decode definition. Every lane must agree exactly (bit-identical f16
after the shared f32->f16 rounding; a NaN on both sides counts as
agreement, since ggml IQ grids can legitimately produce NaN only
from a NaN scale, which the fixture never injects)."""

from std.memory import Pointer
from std.memory.alloc import alloc

from core.extreme_quantization import (
    dequantize_iq1_m_blocks,
    dequantize_iq1_s_blocks,
    dequantize_iq2_s_blocks,
    dequantize_iq2_xs_blocks,
    dequantize_iq2_xxs_blocks,
    dequantize_iq3_s_blocks,
    dequantize_iq3_xxs_blocks,
    dequantize_iq4_nl_blocks,
    dequantize_iq4_xs_blocks,
    iq_grid_materialize,
    iq_value_g,
)


def _fill_fixture(
    data: Pointer[UInt8, MutUntrackedOrigin], nbytes: Int, seed: Int
):
    var state = seed
    for i in range(nbytes):
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        data.unsafe_store(i, UInt8((state >> 8) & 0xFF))


def _set_f16_scale(
    data: Pointer[UInt8, MutUntrackedOrigin], offset: Int
):
    # f16 1.5 == 0x3E00, little-endian.
    data.unsafe_store(offset, UInt8(0))
    data.unsafe_store(offset + 1, UInt8(62))


def _check_format(
    kind: Int, bytes_per_256: Int, super_blocks: Int, seed: Int
) raises:
    var nbytes = bytes_per_256 * super_blocks
    var elements = 256 * super_blocks
    var data = alloc[UInt8](nbytes)
    var outp = alloc[Float16](elements)
    var grid = alloc[UInt16](2048)
    _fill_fixture(data, nbytes, seed)
    if kind == 29:
        # IQ1_M packs its f16 scale into the top nibbles of the four
        # scale words at +48..+56; pin them to d == 1.5 (0x3E00).
        for sb in range(super_blocks):
            var bb = sb * bytes_per_256 + 48
            for j in range(8):
                data.unsafe_store(bb + j, UInt8(0))
            data.unsafe_store(bb + 5, UInt8(224))
            data.unsafe_store(bb + 7, UInt8(48))
    elif kind == 20:
        for b in range(super_blocks * 8):
            _set_f16_scale(data, b * 18)
    else:
        for sb in range(super_blocks):
            _set_f16_scale(data, sb * bytes_per_256)
    iq_grid_materialize(kind, grid)
    if kind == 29:
        dequantize_iq1_m_blocks(data, nbytes, outp, elements)
    elif kind == 19:
        dequantize_iq1_s_blocks(data, nbytes, outp, elements)
    elif kind == 16:
        dequantize_iq2_xxs_blocks(data, nbytes, outp, elements)
    elif kind == 17:
        dequantize_iq2_xs_blocks(data, nbytes, outp, elements)
    elif kind == 22:
        dequantize_iq2_s_blocks(data, nbytes, outp, elements)
    elif kind == 18:
        dequantize_iq3_xxs_blocks(data, nbytes, outp, elements)
    elif kind == 21:
        dequantize_iq3_s_blocks(data, nbytes, outp, elements)
    elif kind == 23:
        dequantize_iq4_xs_blocks(data, nbytes, outp, elements)
    else:
        dequantize_iq4_nl_blocks(data, nbytes, outp, elements)
    for i in range(elements):
        var expected = iq_value_g(data, 0, kind, grid, i).cast[DType.float16]()
        var got = outp.unsafe_load(i)
        if got != expected and not (got != got and expected != expected):
            raise Error(
                "A-039 parity mismatch: kind "
                + String(kind)
                + " lane "
                + String(i)
            )
    data.unsafe_free()
    outp.unsafe_free()
    grid.unsafe_free()
    print("A-039 parity kind", kind, ": PASS")


def test_iq_simd_parity_iq1_s() raises:
    _check_format(19, 50, 4, 101)


def test_iq_simd_parity_iq1_m() raises:
    _check_format(29, 56, 4, 202)


def test_iq_simd_parity_iq2_xxs() raises:
    _check_format(16, 66, 4, 303)


def test_iq_simd_parity_iq2_xs() raises:
    _check_format(17, 74, 4, 404)


def test_iq_simd_parity_iq2_s() raises:
    _check_format(22, 82, 4, 505)


def test_iq_simd_parity_iq3_xxs() raises:
    _check_format(18, 98, 4, 606)


def test_iq_simd_parity_iq3_s() raises:
    _check_format(21, 110, 4, 707)


def test_iq_simd_parity_iq4_nl() raises:
    _check_format(20, 144, 4, 808)


def test_iq_simd_parity_iq4_xs() raises:
    _check_format(23, 136, 4, 909)
