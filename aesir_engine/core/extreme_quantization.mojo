"""Canonical raw-byte IQ and versioned native ternary primitives."""

from std.memory import Pointer
from std.math import max

from .iq_codebooks import (
    IQ1_S_GRID,
    IQ2_XXS_GRID,
    IQ2_XS_GRID,
    IQ2_S_GRID,
    IQ3_XXS_GRID,
    IQ3_S_GRID,
)


@always_inline
def _read_u16_le(data: Pointer[UInt8, MutUntrackedOrigin], offset: Int) -> UInt16:
    return UInt16(data.unsafe_load(offset)) | (
        UInt16(data.unsafe_load(offset + 1)) << 8
    )


@always_inline
def _read_u32_le(data: Pointer[UInt8, MutUntrackedOrigin], offset: Int) -> UInt32:
    return (
        UInt32(data.unsafe_load(offset))
        | (UInt32(data.unsafe_load(offset + 1)) << 8)
        | (UInt32(data.unsafe_load(offset + 2)) << 16)
        | (UInt32(data.unsafe_load(offset + 3)) << 24)
    )


@always_inline
def _iq2_sign_mask(index: Int) -> Int:
    """Expand llama.cpp's 7-bit even-parity sign index to eight bits."""
    var parity = 0
    var value = index
    for _ in range(7):
        parity ^= value & 1
        value >>= 1
    return index | (parity << 7)



@always_inline
def _materialize_iq_grid[size: Int](
    grid_simd: SIMD[DType.uint16, size],
    dst: Pointer[UInt16, MutUntrackedOrigin],
):
    """Copy a comptime SIMD grid constant into addressable memory.

    Dynamic indexing of a wide SIMD constant compiles to a select
    chain (~145 ns/element measured on this host); a wide store into
    a stack buffer plus pointer loads is ~0.5 ns/element. Hot paths
    materialize the grid they need once and pass the pointer to the
    *_value_g decoders.
    """
    dst.unsafe_store[width=size](0, grid_simd)


@always_inline
def _iq4nl_kv(nibble: Int) -> Float32:
    """ggml kvalues_iq4nl: -127,-104,-83,-65,-49,-35,-22,-10,1,13,25,38,53,69,89,113."""
    if nibble == 0:
        return Float32(-127.0)
    if nibble == 1:
        return Float32(-104.0)
    if nibble == 2:
        return Float32(-83.0)
    if nibble == 3:
        return Float32(-65.0)
    if nibble == 4:
        return Float32(-49.0)
    if nibble == 5:
        return Float32(-35.0)
    if nibble == 6:
        return Float32(-22.0)
    if nibble == 7:
        return Float32(-10.0)
    if nibble == 8:
        return Float32(1.0)
    if nibble == 9:
        return Float32(13.0)
    if nibble == 10:
        return Float32(25.0)
    if nibble == 11:
        return Float32(38.0)
    if nibble == 12:
        return Float32(53.0)
    if nibble == 13:
        return Float32(69.0)
    if nibble == 14:
        return Float32(89.0)
    return Float32(113.0)


@always_inline
def iq4_nl_value(
    data: Pointer[UInt8, MutUntrackedOrigin], base: Int, index: Int
) -> Float32:
    """IQ4_NL (kind 20): 32-value blocks of 18 bytes (f16 d, 16 qs);
    low nibbles are values 0..15, high 16..31; value = d * kv[nib]."""
    var block = index // 32
    var lane = index % 32
    var bb = base + block * 18
    var d = data.unsafe_offset(bb).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
    var qs = Int(data.unsafe_load(bb + 2 + lane % 16))
    var nib = (qs & 0x0F) if lane < 16 else ((qs >> 4) & 0x0F)
    return d * _iq4nl_kv(nib)


@always_inline
def iq4_xs_value(
    data: Pointer[UInt8, MutUntrackedOrigin], base: Int, index: Int
) -> Float32:
    """IQ4_XS (kind 23): 256-value super-blocks of 136 bytes (f16 d,
    u16 scales_h, 4 scales_l bytes, 128 qs). Group ib: ls =
    ((scales_l[ib/2] >> 4*(ib%2)) & 0xf) | (((scales_h >> 2*ib) & 3) << 4);
    dl = d * (ls - 32); value = dl * kv[nib] (ggml dequantize_row_iq4_xs)."""
    var sb = index // 256
    var lane = index % 256
    var bb = base + sb * 136
    var d = data.unsafe_offset(bb).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
    var group = lane // 32
    var gl = lane % 32
    var scales_h = Int(_read_u16_le(data, bb + 2))
    var scales_l = Int(data.unsafe_load(bb + 4 + group // 2))
    var ls = ((scales_l >> (4 * (group % 2))) & 0x0F) | (((scales_h >> (2 * group)) & 3) << 4)
    var dl = d * Float32(ls - 32)
    var qs = Int(data.unsafe_load(bb + 8 + group * 16 + gl % 16))
    var nib = (qs & 0x0F) if gl < 16 else ((qs >> 4) & 0x0F)
    return dl * _iq4nl_kv(nib)

def dequantize_iq4_nl_blocks(
    data: Pointer[UInt8, MutUntrackedOrigin],
    input_bytes: Int,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(data) <= 1 or Int(output) <= 1:
        raise Error("dequantize_iq4_nl_blocks: storage pointers must be valid")
    if output_elements <= 0 or output_elements % 32 != 0:
        raise Error("dequantize_iq4_nl_blocks: output must contain complete 32-value blocks")
    var blocks = output_elements // 32
    if input_bytes != blocks * 18:
        raise Error("dequantize_iq4_nl_blocks: input storage length mismatch")
    for index in range(output_elements):
        output.unsafe_store(index, iq4_nl_value(data, 0, index).cast[DType.float16]())


def dequantize_iq4_xs_blocks(
    data: Pointer[UInt8, MutUntrackedOrigin],
    input_bytes: Int,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(data) <= 1 or Int(output) <= 1:
        raise Error("dequantize_iq4_xs_blocks: storage pointers must be valid")
    if output_elements <= 0 or output_elements % 256 != 0:
        raise Error("dequantize_iq4_xs_blocks: output must contain complete 256-value blocks")
    var blocks = output_elements // 256
    if input_bytes != blocks * 136:
        raise Error("dequantize_iq4_xs_blocks: input storage length mismatch")
    for index in range(output_elements):
        output.unsafe_store(index, iq4_xs_value(data, 0, index).cast[DType.float16]())


def dequantize_iq4_nl_block32(
    data: Pointer[UInt8, MutUntrackedOrigin],
    block_base: Int,
    out_ptr: Pointer[Float32, MutUntrackedOrigin],
):
    """Decode one 32-value IQ4_NL block at block_base into out_ptr[0..32)
    (embedding row path; rows are 32-aligned, not always 256-aligned)."""
    var d = data.unsafe_offset(block_base).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
    for j in range(16):
        var qs = Int(data.unsafe_load(block_base + 2 + j))
        out_ptr.unsafe_store(j, d * _iq4nl_kv(qs & 0x0F))
        out_ptr.unsafe_store(j + 16, d * _iq4nl_kv((qs >> 4) & 0x0F))

def iq_grid_materialize(
    kind: Int, dst: Pointer[UInt16, MutUntrackedOrigin]
):
    """Wide-store the grid for a GGML IQ kind (16/17/18/19/21/22)
    into dst; the caller provides a buffer of at least 2048 UInt16."""
    if kind == 20 or kind == 23:
        return
    if kind == 19:
        _materialize_iq_grid[2048](IQ1_S_GRID, dst)
    elif kind == 16:
        _materialize_iq_grid[256](IQ2_XXS_GRID, dst)
    elif kind == 22:
        _materialize_iq_grid[1024](IQ2_S_GRID, dst)
    elif kind == 21:
        _materialize_iq_grid[512](IQ3_S_GRID, dst)
    elif kind == 17:
        _materialize_iq_grid[512](IQ2_XS_GRID, dst)
    else:
        _materialize_iq_grid[256](IQ3_XXS_GRID, dst)

@always_inline
def iq2_xxs_value_g(
    data: Pointer[UInt8, MutUntrackedOrigin],
    base: Int,
    grid: Pointer[UInt16, MutUntrackedOrigin],
    index: Int,
) -> Float32:
    """Decode one value from canonical 66-byte GGML IQ2_XXS blocks."""
    var block = index // 256
    var lane = index % 256
    var block_base = base + block * 66
    var scale = data.unsafe_offset(block_base).unsafe_bitcast[
        Float16
    ]().unsafe_load().cast[DType.float32]()
    var group = lane // 32
    var group_lane = lane % 32
    var subgrid = group_lane // 8
    var grid_lane = group_lane % 8
    var packed_base = block_base + 2 + group * 8
    var grid_index = Int(data.unsafe_load(packed_base + subgrid))
    var encoded_grid = Int(grid.unsafe_load(grid_index))
    var grid_digit = (encoded_grid >> (grid_lane * 2)) & 3
    var grid_value = 8
    if grid_digit == 1:
        grid_value = 25
    elif grid_digit == 2:
        grid_value = 43

    var signs_and_scale = _read_u32_le(data, packed_base + 4)
    var local_scale = (
        Float32(0.5) + Float32(Int(signs_and_scale >> 28))
    ) * Float32(0.25)
    var sign_index = Int(
        (signs_and_scale >> UInt32(subgrid * 7)) & UInt32(0x7F)
    )
    var sign_mask = _iq2_sign_mask(sign_index)
    var sign = Float32(-1.0 if ((sign_mask >> grid_lane) & 1) != 0 else 1.0)
    return scale * local_scale * Float32(grid_value) * sign



@always_inline
def iq2_xxs_value(
    data: Pointer[UInt8, MutUntrackedOrigin], base: Int, index: Int
) -> Float32:
    var buf = InlineArray[UInt16, 256](uninitialized=True)
    _materialize_iq_grid[256](IQ2_XXS_GRID, buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]())
    return iq2_xxs_value_g(data, base, buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), index)


@always_inline
def iq1_s_value(
    data: Pointer[UInt8, MutUntrackedOrigin], base: Int, index: Int
) -> Float32:
    var buf = InlineArray[UInt16, 2048](uninitialized=True)
    _materialize_iq_grid[2048](IQ1_S_GRID, buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]())
    return iq1_s_value_g(data, base, buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), index)


@always_inline
def iq2_s_value(
    data: Pointer[UInt8, MutUntrackedOrigin], base: Int, index: Int
) -> Float32:
    var buf = InlineArray[UInt16, 1024](uninitialized=True)
    _materialize_iq_grid[1024](IQ2_S_GRID, buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]())
    return iq2_s_value_g(data, base, buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), index)


@always_inline
def iq3_s_value(
    data: Pointer[UInt8, MutUntrackedOrigin], base: Int, index: Int
) -> Float32:
    var buf = InlineArray[UInt16, 512](uninitialized=True)
    _materialize_iq_grid[512](IQ3_S_GRID, buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]())
    return iq3_s_value_g(data, base, buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), index)


@always_inline
def iq2_xs_value(
    data: Pointer[UInt8, MutUntrackedOrigin], base: Int, index: Int
) -> Float32:
    var buf = InlineArray[UInt16, 512](uninitialized=True)
    _materialize_iq_grid[512](IQ2_XS_GRID, buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]())
    return iq2_xs_value_g(data, base, buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), index)


@always_inline
def iq3_xxs_value(
    data: Pointer[UInt8, MutUntrackedOrigin], base: Int, index: Int
) -> Float32:
    var buf = InlineArray[UInt16, 256](uninitialized=True)
    _materialize_iq_grid[256](IQ3_XXS_GRID, buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]())
    return iq3_xxs_value_g(data, base, buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), index)

def dequantize_iq2_xxs_blocks(
    data: Pointer[UInt8, MutUntrackedOrigin],
    input_bytes: Int,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(data) <= 1 or Int(output) <= 1:
        raise Error("dequantize_iq2_xxs_blocks: storage pointers must be valid")
    if output_elements <= 0 or output_elements % 256 != 0:
        raise Error("dequantize_iq2_xxs_blocks: output must contain complete 256-value blocks")
    var blocks = output_elements // 256
    if input_bytes != blocks * 66:
        raise Error("dequantize_iq2_xxs_blocks: input storage length mismatch")
    var grid_buf = InlineArray[UInt16, 256](uninitialized=True)
    _materialize_iq_grid[256](IQ2_XXS_GRID, grid_buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]())
    for index in range(output_elements):
        output.unsafe_store(
            index, iq2_xxs_value_g(data, 0, grid_buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), index).cast[DType.float16]()
        )


def gemm_iq2_xxs_blocks(
    input: Pointer[Float16, MutUntrackedOrigin],
    input_elements: Int,
    input_rows: Int,
    weights: Pointer[UInt8, MutUntrackedOrigin],
    weight_bytes: Int,
    in_features: Int,
    out_features: Int,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(input) <= 1 or Int(weights) <= 1 or Int(output) <= 1:
        raise Error("gemm_iq2_xxs_blocks: storage pointers must be valid")
    if input_rows <= 0 or in_features <= 0 or out_features <= 0:
        raise Error("gemm_iq2_xxs_blocks: dimensions must be positive")
    if in_features % 256 != 0:
        raise Error("gemm_iq2_xxs_blocks: in_features must use complete IQ2_XXS blocks")
    if input_elements != input_rows * in_features:
        raise Error("gemm_iq2_xxs_blocks: input storage length mismatch")
    if output_elements != input_rows * out_features:
        raise Error("gemm_iq2_xxs_blocks: output storage length mismatch")
    var bytes_per_row = (in_features // 256) * 66
    if weight_bytes != out_features * bytes_per_row:
        raise Error("gemm_iq2_xxs_blocks: weight storage length mismatch")

    for row in range(input_rows):
        for output_index in range(out_features):
            var accumulator = Float32(0.0)
            var weight_base = output_index * bytes_per_row
            for input_index in range(in_features):
                accumulator += input.unsafe_load(
                    row * in_features + input_index
                ).cast[DType.float32]() * iq2_xxs_value(
                    weights, weight_base, input_index
                )
            output.unsafe_store(
                row * out_features + output_index,
                accumulator.cast[DType.float16](),
            )


@always_inline
def iq1_s_value_g(
    data: Pointer[UInt8, MutUntrackedOrigin],
    base: Int,
    grid: Pointer[UInt16, MutUntrackedOrigin],
    index: Int,
) -> Float32:
    """Decode one value from canonical 50-byte GGML IQ1_S blocks."""
    var block = index // 256
    var lane = index % 256
    var block_base = base + block * 50
    var scale = data.unsafe_offset(block_base).unsafe_bitcast[
        Float16
    ]().unsafe_load().cast[DType.float32]()
    var group = lane // 32
    var group_lane = lane % 32
    var subgrid = group_lane // 8
    var grid_lane = group_lane % 8
    var qh = Int(_read_u16_le(data, block_base + 34 + group * 2))
    var grid_index = Int(
        data.unsafe_load(block_base + 2 + group * 4 + subgrid)
    ) | (((qh >> (subgrid * 3)) & 7) << 8)
    var encoded_grid = Int(grid.unsafe_load(grid_index))
    var grid_digit = (encoded_grid >> (grid_lane * 2)) & 3
    var grid_value = Float32(-1.0)
    if grid_digit == 1:
        grid_value = Float32(0.0)
    elif grid_digit == 2:
        grid_value = Float32(1.0)
    var local_scale = scale * Float32(2 * ((qh >> 12) & 7) + 1)
    var delta = Float32(-0.125 if (qh & 0x8000) != 0 else 0.125)
    return local_scale * (grid_value + delta)


def dequantize_iq1_s_blocks(
    data: Pointer[UInt8, MutUntrackedOrigin],
    input_bytes: Int,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(data) <= 1 or Int(output) <= 1:
        raise Error("dequantize_iq1_s_blocks: storage pointers must be valid")
    if output_elements <= 0 or output_elements % 256 != 0:
        raise Error("dequantize_iq1_s_blocks: output must contain complete 256-value blocks")
    var blocks = output_elements // 256
    if input_bytes != blocks * 50:
        raise Error("dequantize_iq1_s_blocks: input storage length mismatch")
    var grid_buf = InlineArray[UInt16, 2048](uninitialized=True)
    _materialize_iq_grid[2048](IQ1_S_GRID, grid_buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]())
    for index in range(output_elements):
        output.unsafe_store(
            index, iq1_s_value_g(data, 0, grid_buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), index).cast[DType.float16]()
        )


def gemm_iq1_s_blocks(
    input: Pointer[Float16, MutUntrackedOrigin],
    input_elements: Int,
    input_rows: Int,
    weights: Pointer[UInt8, MutUntrackedOrigin],
    weight_bytes: Int,
    in_features: Int,
    out_features: Int,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(input) <= 1 or Int(weights) <= 1 or Int(output) <= 1:
        raise Error("gemm_iq1_s_blocks: storage pointers must be valid")
    if input_rows <= 0 or in_features <= 0 or out_features <= 0:
        raise Error("gemm_iq1_s_blocks: dimensions must be positive")
    if in_features % 256 != 0:
        raise Error("gemm_iq1_s_blocks: in_features must use complete IQ1_S blocks")
    if input_elements != input_rows * in_features:
        raise Error("gemm_iq1_s_blocks: input storage length mismatch")
    if output_elements != input_rows * out_features:
        raise Error("gemm_iq1_s_blocks: output storage length mismatch")
    var bytes_per_row = (in_features // 256) * 50
    if weight_bytes != out_features * bytes_per_row:
        raise Error("gemm_iq1_s_blocks: weight storage length mismatch")

    for row in range(input_rows):
        for output_index in range(out_features):
            var accumulator = Float32(0.0)
            var weight_base = output_index * bytes_per_row
            for input_index in range(in_features):
                accumulator += input.unsafe_load(
                    row * in_features + input_index
                ).cast[DType.float32]() * iq1_s_value(
                    weights, weight_base, input_index
                )
            output.unsafe_store(
                row * out_features + output_index,
                accumulator.cast[DType.float16](),
            )


@always_inline
def tq1_0_value(
    data: Pointer[UInt8, MutUntrackedOrigin], base: Int, index: Int
) -> Float32:
    """Decode one value from canonical 54-byte GGML TQ1_0 blocks."""
    var block = index // 256
    var lane = index % 256
    var block_base = base + block * 54
    var scale = data.unsafe_offset(block_base + 52).unsafe_bitcast[
        Float16
    ]().unsafe_load().cast[DType.float32]()
    var packed_offset: Int
    var power_index: Int
    if lane < 160:
        power_index = lane // 32
        packed_offset = lane % 32
    elif lane < 240:
        var local = lane - 160
        power_index = local // 16
        packed_offset = 32 + local % 16
    else:
        var local = lane - 240
        power_index = local // 4
        packed_offset = 48 + local % 4

    var power = 1
    for _ in range(power_index):
        power *= 3
    # Upstream intentionally performs this multiplication in UInt8 before
    # extracting the base-3 digit from the rescaled byte representation.
    var wrapped = (Int(data.unsafe_load(block_base + packed_offset)) * power) % 256
    var trit = (wrapped * 3) >> 8
    return Float32(trit - 1) * scale


def dequantize_tq1_0_blocks(
    data: Pointer[UInt8, MutUntrackedOrigin],
    input_bytes: Int,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(data) <= 1 or Int(output) <= 1:
        raise Error("dequantize_tq1_0_blocks: storage pointers must be valid")
    if output_elements <= 0 or output_elements % 256 != 0:
        raise Error("dequantize_tq1_0_blocks: output must contain complete 256-value blocks")
    var blocks = output_elements // 256
    if input_bytes != blocks * 54:
        raise Error("dequantize_tq1_0_blocks: input storage length mismatch")
    for index in range(output_elements):
        output.unsafe_store(
            index, tq1_0_value(data, 0, index).cast[DType.float16]()
        )


def gemm_tq1_0_blocks(
    input: Pointer[Float16, MutUntrackedOrigin],
    input_elements: Int,
    input_rows: Int,
    weights: Pointer[UInt8, MutUntrackedOrigin],
    weight_bytes: Int,
    in_features: Int,
    out_features: Int,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(input) <= 1 or Int(weights) <= 1 or Int(output) <= 1:
        raise Error("gemm_tq1_0_blocks: storage pointers must be valid")
    if input_rows <= 0 or in_features <= 0 or out_features <= 0:
        raise Error("gemm_tq1_0_blocks: dimensions must be positive")
    if in_features % 256 != 0:
        raise Error("gemm_tq1_0_blocks: in_features must use complete TQ1_0 blocks")
    if input_elements != input_rows * in_features:
        raise Error("gemm_tq1_0_blocks: input storage length mismatch")
    if output_elements != input_rows * out_features:
        raise Error("gemm_tq1_0_blocks: output storage length mismatch")
    var bytes_per_row = (in_features // 256) * 54
    if weight_bytes != out_features * bytes_per_row:
        raise Error("gemm_tq1_0_blocks: weight storage length mismatch")

    for row in range(input_rows):
        for output_index in range(out_features):
            var accumulator = Float32(0.0)
            var weight_base = output_index * bytes_per_row
            for input_index in range(in_features):
                accumulator += input.unsafe_load(
                    row * in_features + input_index
                ).cast[DType.float32]() * tq1_0_value(
                    weights, weight_base, input_index
                )
            output.unsafe_store(
                row * out_features + output_index,
                accumulator.cast[DType.float16](),
            )

@always_inline
def iq2_s_value_g(
    data: Pointer[UInt8, MutUntrackedOrigin],
    base: Int,
    grid: Pointer[UInt16, MutUntrackedOrigin],
    index: Int,
) -> Float32:
    """Decode one value from canonical 82-byte GGML IQ2_S blocks."""
    var block = index // 256
    var lane = index % 256
    var block_base = base + block * 82
    var scale = data.unsafe_offset(block_base).unsafe_bitcast[
        Float16
    ]().unsafe_load().cast[DType.float32]()
    var group = lane // 32
    var group_lane = lane % 32
    var subgrid = group_lane // 8
    var grid_lane = group_lane % 8
    var scale_byte = Int(data.unsafe_load(block_base + 74 + group))
    var nibble = (scale_byte & 15) if subgrid < 2 else (scale_byte >> 4)
    var local_scale = (Float32(0.5) + Float32(nibble)) * Float32(0.25)
    var qh = Int(data.unsafe_load(block_base + 66 + group))
    var grid_index = Int(
        data.unsafe_load(block_base + 2 + group * 4 + subgrid)
    ) | ((qh << (8 - 2 * subgrid)) & 0x300)
    var encoded_grid = Int(grid.unsafe_load(grid_index))
    var grid_digit = (encoded_grid >> (grid_lane * 2)) & 3
    var grid_value = 8
    if grid_digit == 1:
        grid_value = 25
    elif grid_digit == 2:
        grid_value = 43
    var sign_byte = Int(data.unsafe_load(block_base + 34 + group * 4 + subgrid))
    var sign = Float32(-1.0 if ((sign_byte >> grid_lane) & 1) != 0 else 1.0)
    return scale * local_scale * Float32(grid_value) * sign


def dequantize_iq2_s_blocks(
    data: Pointer[UInt8, MutUntrackedOrigin],
    input_bytes: Int,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(data) <= 1 or Int(output) <= 1:
        raise Error("dequantize_iq2_s_blocks: storage pointers must be valid")
    if output_elements <= 0 or output_elements % 256 != 0:
        raise Error("dequantize_iq2_s_blocks: output must contain complete 256-value blocks")
    var blocks = output_elements // 256
    if input_bytes != blocks * 82:
        raise Error("dequantize_iq2_s_blocks: input storage length mismatch")
    var grid_buf = InlineArray[UInt16, 1024](uninitialized=True)
    _materialize_iq_grid[1024](IQ2_S_GRID, grid_buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]())
    for index in range(output_elements):
        output.unsafe_store(
            index, iq2_s_value_g(data, 0, grid_buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), index).cast[DType.float16]()
        )


def gemm_iq2_s_blocks(
    input: Pointer[Float16, MutUntrackedOrigin],
    input_elements: Int,
    input_rows: Int,
    weights: Pointer[UInt8, MutUntrackedOrigin],
    weight_bytes: Int,
    in_features: Int,
    out_features: Int,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(input) <= 1 or Int(weights) <= 1 or Int(output) <= 1:
        raise Error("gemm_iq2_s_blocks: storage pointers must be valid")
    if input_rows <= 0 or in_features <= 0 or out_features <= 0:
        raise Error("gemm_iq2_s_blocks: dimensions must be positive")
    if in_features % 256 != 0:
        raise Error("gemm_iq2_s_blocks: in_features must use complete IQ2_S blocks")
    if input_elements != input_rows * in_features:
        raise Error("gemm_iq2_s_blocks: input storage length mismatch")
    if output_elements != input_rows * out_features:
        raise Error("gemm_iq2_s_blocks: output storage length mismatch")
    var bytes_per_row = (in_features // 256) * 82
    if weight_bytes != out_features * bytes_per_row:
        raise Error("gemm_iq2_s_blocks: weight storage length mismatch")

    for row in range(input_rows):
        for output_index in range(out_features):
            var accumulator = Float32(0.0)
            var weight_base = output_index * bytes_per_row
            for input_index in range(in_features):
                accumulator += input.unsafe_load(
                    row * in_features + input_index
                ).cast[DType.float32]() * iq2_s_value(
                    weights, weight_base, input_index
                )
            output.unsafe_store(
                row * out_features + output_index,
                accumulator.cast[DType.float16](),
            )


@always_inline
def iq3_s_value_g(
    data: Pointer[UInt8, MutUntrackedOrigin],
    base: Int,
    grid: Pointer[UInt16, MutUntrackedOrigin],
    index: Int,
) -> Float32:
    """Decode one value from canonical 110-byte GGML IQ3_S blocks."""
    var block = index // 256
    var lane = index % 256
    var block_base = base + block * 110
    var scale = data.unsafe_offset(block_base).unsafe_bitcast[
        Float16
    ]().unsafe_load().cast[DType.float32]()
    var group = lane // 32
    var group_lane = lane % 32
    var subgrid = group_lane // 8
    var pos = group_lane % 8
    var scale_byte = Int(data.unsafe_load(block_base + 106 + group // 2))
    var nibble = (scale_byte & 15) if group % 2 == 0 else (scale_byte >> 4)
    var local_scale = Float32(1 + 2 * nibble)
    var qh = Int(data.unsafe_load(block_base + 66 + group))
    var grid_index: Int
    var digit_lane: Int
    if pos < 4:
        grid_index = Int(
            data.unsafe_load(block_base + 2 + group * 8 + 2 * subgrid)
        ) | (((qh >> (2 * subgrid)) & 1) << 8)
        digit_lane = pos
    else:
        grid_index = Int(
            data.unsafe_load(block_base + 2 + group * 8 + 2 * subgrid + 1)
        ) | (((qh >> (2 * subgrid + 1)) & 1) << 8)
        digit_lane = pos - 4
    var encoded_grid = Int(grid.unsafe_load(grid_index))
    var grid_digit = (encoded_grid >> (digit_lane * 3)) & 7
    var grid_value = Float32(2 * grid_digit + 1)
    var sign_byte = Int(data.unsafe_load(block_base + 74 + group * 4 + subgrid))
    var sign = Float32(-1.0 if ((sign_byte >> pos) & 1) != 0 else 1.0)
    return scale * local_scale * grid_value * sign


def dequantize_iq3_s_blocks(
    data: Pointer[UInt8, MutUntrackedOrigin],
    input_bytes: Int,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(data) <= 1 or Int(output) <= 1:
        raise Error("dequantize_iq3_s_blocks: storage pointers must be valid")
    if output_elements <= 0 or output_elements % 256 != 0:
        raise Error("dequantize_iq3_s_blocks: output must contain complete 256-value blocks")
    var blocks = output_elements // 256
    if input_bytes != blocks * 110:
        raise Error("dequantize_iq3_s_blocks: input storage length mismatch")
    var grid_buf = InlineArray[UInt16, 512](uninitialized=True)
    _materialize_iq_grid[512](IQ3_S_GRID, grid_buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]())
    for index in range(output_elements):
        output.unsafe_store(
            index, iq3_s_value_g(data, 0, grid_buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), index).cast[DType.float16]()
        )


def gemm_iq3_s_blocks(
    input: Pointer[Float16, MutUntrackedOrigin],
    input_elements: Int,
    input_rows: Int,
    weights: Pointer[UInt8, MutUntrackedOrigin],
    weight_bytes: Int,
    in_features: Int,
    out_features: Int,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(input) <= 1 or Int(weights) <= 1 or Int(output) <= 1:
        raise Error("gemm_iq3_s_blocks: storage pointers must be valid")
    if input_rows <= 0 or in_features <= 0 or out_features <= 0:
        raise Error("gemm_iq3_s_blocks: dimensions must be positive")
    if in_features % 256 != 0:
        raise Error("gemm_iq3_s_blocks: in_features must use complete IQ3_S blocks")
    if input_elements != input_rows * in_features:
        raise Error("gemm_iq3_s_blocks: input storage length mismatch")
    if output_elements != input_rows * out_features:
        raise Error("gemm_iq3_s_blocks: output storage length mismatch")
    var bytes_per_row = (in_features // 256) * 110
    if weight_bytes != out_features * bytes_per_row:
        raise Error("gemm_iq3_s_blocks: weight storage length mismatch")

    for row in range(input_rows):
        for output_index in range(out_features):
            var accumulator = Float32(0.0)
            var weight_base = output_index * bytes_per_row
            for input_index in range(in_features):
                accumulator += input.unsafe_load(
                    row * in_features + input_index
                ).cast[DType.float32]() * iq3_s_value(
                    weights, weight_base, input_index
                )
            output.unsafe_store(
                row * out_features + output_index,
                accumulator.cast[DType.float16](),
            )


@always_inline
def iq2_xs_value_g(
    data: Pointer[UInt8, MutUntrackedOrigin],
    base: Int,
    grid: Pointer[UInt16, MutUntrackedOrigin],
    index: Int,
) -> Float32:
    """Decode one value from canonical 74-byte GGML IQ2_XS blocks."""
    var block = index // 256
    var lane = index % 256
    var block_base = base + block * 74
    var scale = data.unsafe_offset(block_base).unsafe_bitcast[
        Float16
    ]().unsafe_load().cast[DType.float32]()
    var group = lane // 32
    var group_lane = lane % 32
    var subgrid = group_lane // 8
    var grid_lane = group_lane % 8
    var scale_byte = Int(data.unsafe_load(block_base + 66 + group))
    var nibble = (scale_byte & 15) if subgrid < 2 else (scale_byte >> 4)
    var local_scale = (Float32(0.5) + Float32(nibble)) * Float32(0.25)
    var packed = Int(_read_u16_le(data, block_base + 2 + (group * 4 + subgrid) * 2))
    var encoded_grid = Int(grid.unsafe_load(packed & 511))
    var grid_digit = (encoded_grid >> (grid_lane * 2)) & 3
    var grid_value = 8
    if grid_digit == 1:
        grid_value = 25
    elif grid_digit == 2:
        grid_value = 43
    var sign_mask = _iq2_sign_mask(packed >> 9)
    var sign = Float32(-1.0 if ((sign_mask >> grid_lane) & 1) != 0 else 1.0)
    return scale * local_scale * Float32(grid_value) * sign


def dequantize_iq2_xs_blocks(
    data: Pointer[UInt8, MutUntrackedOrigin],
    input_bytes: Int,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(data) <= 1 or Int(output) <= 1:
        raise Error("dequantize_iq2_xs_blocks: storage pointers must be valid")
    if output_elements <= 0 or output_elements % 256 != 0:
        raise Error("dequantize_iq2_xs_blocks: output must contain complete 256-value blocks")
    var blocks = output_elements // 256
    if input_bytes != blocks * 74:
        raise Error("dequantize_iq2_xs_blocks: input storage length mismatch")
    var grid_buf = InlineArray[UInt16, 512](uninitialized=True)
    _materialize_iq_grid[512](IQ2_XS_GRID, grid_buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]())
    for index in range(output_elements):
        output.unsafe_store(
            index, iq2_xs_value_g(data, 0, grid_buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), index).cast[DType.float16]()
        )


def gemm_iq2_xs_blocks(
    input: Pointer[Float16, MutUntrackedOrigin],
    input_elements: Int,
    input_rows: Int,
    weights: Pointer[UInt8, MutUntrackedOrigin],
    weight_bytes: Int,
    in_features: Int,
    out_features: Int,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(input) <= 1 or Int(weights) <= 1 or Int(output) <= 1:
        raise Error("gemm_iq2_xs_blocks: storage pointers must be valid")
    if input_rows <= 0 or in_features <= 0 or out_features <= 0:
        raise Error("gemm_iq2_xs_blocks: dimensions must be positive")
    if in_features % 256 != 0:
        raise Error("gemm_iq2_xs_blocks: in_features must use complete IQ2_XS blocks")
    if input_elements != input_rows * in_features:
        raise Error("gemm_iq2_xs_blocks: input storage length mismatch")
    if output_elements != input_rows * out_features:
        raise Error("gemm_iq2_xs_blocks: output storage length mismatch")
    var bytes_per_row = (in_features // 256) * 74
    if weight_bytes != out_features * bytes_per_row:
        raise Error("gemm_iq2_xs_blocks: weight storage length mismatch")

    for row in range(input_rows):
        for output_index in range(out_features):
            var accumulator = Float32(0.0)
            var weight_base = output_index * bytes_per_row
            for input_index in range(in_features):
                accumulator += input.unsafe_load(
                    row * in_features + input_index
                ).cast[DType.float32]() * iq2_xs_value(
                    weights, weight_base, input_index
                )
            output.unsafe_store(
                row * out_features + output_index,
                accumulator.cast[DType.float16](),
            )


@always_inline
def iq3_xxs_value_g(
    data: Pointer[UInt8, MutUntrackedOrigin],
    base: Int,
    grid: Pointer[UInt16, MutUntrackedOrigin],
    index: Int,
) -> Float32:
    """Decode one value from canonical 98-byte GGML IQ3_XXS blocks."""
    var block = index // 256
    var lane = index % 256
    var block_base = base + block * 98
    var scale = data.unsafe_offset(block_base).unsafe_bitcast[
        Float16
    ]().unsafe_load().cast[DType.float32]()
    var group = lane // 32
    var group_lane = lane % 32
    var subgrid = group_lane // 8
    var pos = group_lane % 8
    var aux = _read_u32_le(data, block_base + 66 + group * 4)
    var local_scale = (Float32(0.5) + Float32(Int(aux >> 28))) * Float32(0.5)
    var grid_byte = block_base + 2 + group * 8 + 2 * subgrid + (0 if pos < 4 else 1)
    var encoded_grid = Int(grid.unsafe_load(Int(data.unsafe_load(grid_byte))))
    var grid_digit = (encoded_grid >> ((pos % 4) * 3)) & 7
    var grid_value = 62 if grid_digit == 7 else 4 + 8 * grid_digit
    var sign_index = Int((aux >> UInt32(7 * subgrid)) & UInt32(0x7F))
    var sign_mask = _iq2_sign_mask(sign_index)
    var sign = Float32(-1.0 if ((sign_mask >> pos) & 1) != 0 else 1.0)
    return scale * local_scale * Float32(grid_value) * sign


def dequantize_iq3_xxs_blocks(
    data: Pointer[UInt8, MutUntrackedOrigin],
    input_bytes: Int,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(data) <= 1 or Int(output) <= 1:
        raise Error("dequantize_iq3_xxs_blocks: storage pointers must be valid")
    if output_elements <= 0 or output_elements % 256 != 0:
        raise Error("dequantize_iq3_xxs_blocks: output must contain complete 256-value blocks")
    var blocks = output_elements // 256
    if input_bytes != blocks * 98:
        raise Error("dequantize_iq3_xxs_blocks: input storage length mismatch")
    var grid_buf = InlineArray[UInt16, 256](uninitialized=True)
    _materialize_iq_grid[256](IQ3_XXS_GRID, grid_buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]())
    for index in range(output_elements):
        output.unsafe_store(
            index, iq3_xxs_value_g(data, 0, grid_buf.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), index).cast[DType.float16]()
        )


def gemm_iq3_xxs_blocks(
    input: Pointer[Float16, MutUntrackedOrigin],
    input_elements: Int,
    input_rows: Int,
    weights: Pointer[UInt8, MutUntrackedOrigin],
    weight_bytes: Int,
    in_features: Int,
    out_features: Int,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(input) <= 1 or Int(weights) <= 1 or Int(output) <= 1:
        raise Error("gemm_iq3_xxs_blocks: storage pointers must be valid")
    if input_rows <= 0 or in_features <= 0 or out_features <= 0:
        raise Error("gemm_iq3_xxs_blocks: dimensions must be positive")
    if in_features % 256 != 0:
        raise Error("gemm_iq3_xxs_blocks: in_features must use complete IQ3_XXS blocks")
    if input_elements != input_rows * in_features:
        raise Error("gemm_iq3_xxs_blocks: input storage length mismatch")
    if output_elements != input_rows * out_features:
        raise Error("gemm_iq3_xxs_blocks: output storage length mismatch")
    var bytes_per_row = (in_features // 256) * 98
    if weight_bytes != out_features * bytes_per_row:
        raise Error("gemm_iq3_xxs_blocks: weight storage length mismatch")

    for row in range(input_rows):
        for output_index in range(out_features):
            var accumulator = Float32(0.0)
            var weight_base = output_index * bytes_per_row
            for input_index in range(in_features):
                accumulator += input.unsafe_load(
                    row * in_features + input_index
                ).cast[DType.float32]() * iq3_xxs_value(
                    weights, weight_base, input_index
                )
            output.unsafe_store(
                row * out_features + output_index,
                accumulator.cast[DType.float16](),
            )


@always_inline
def iq_value_g(
    data: Pointer[UInt8, MutUntrackedOrigin],
    base: Int,
    kind: Int,
    grid: Pointer[UInt16, MutUntrackedOrigin],
    index: Int,
) -> Float32:
    """Decode one value of any implemented GGML IQ format using a
    grid materialized by iq_grid_materialize for the same kind."""
    if kind == 19:
        return iq1_s_value_g(data, base, grid, index)
    if kind == 16:
        return iq2_xxs_value_g(data, base, grid, index)
    if kind == 22:
        return iq2_s_value_g(data, base, grid, index)
    if kind == 21:
        return iq3_s_value_g(data, base, grid, index)
    if kind == 17:
        return iq2_xs_value_g(data, base, grid, index)
    if kind == 20:
        return iq4_nl_value(data, base, index)
    if kind == 23:
        return iq4_xs_value(data, base, index)
    return iq3_xxs_value_g(data, base, grid, index)


@always_inline
def iq_value(
    data: Pointer[UInt8, MutUntrackedOrigin], base: Int, kind: Int, index: Int
) -> Float32:
    """Decode one value of any implemented GGML IQ format (GGML type
    number as kind: 16 IQ2_XXS, 17 IQ2_XS, 18 IQ3_XXS, 19 IQ1_S,
    21 IQ3_S, 22 IQ2_S)."""
    if kind == 19:
        return iq1_s_value(data, base, index)
    if kind == 16:
        return iq2_xxs_value(data, base, index)
    if kind == 22:
        return iq2_s_value(data, base, index)
    if kind == 21:
        return iq3_s_value(data, base, index)
    if kind == 17:
        return iq2_xs_value(data, base, index)
    if kind == 20:
        return iq4_nl_value(data, base, index)
    if kind == 23:
        return iq4_xs_value(data, base, index)
    return iq3_xxs_value(data, base, index)


@always_inline
def iq_block_bytes(kind: Int) -> Int:
    """Packed byte size of one 256-value GGML IQ super-block."""
    if kind == 19:
        return 50
    if kind == 16:
        return 66
    if kind == 17:
        return 74
    if kind == 18:
        return 98
    if kind == 21:
        return 110
    if kind == 20:
        return 144
    if kind == 23:
        return 136
    return 82


@always_inline
def _iq2_grid_digit_value(encoded_grid: Int, grid_lane: Int) -> Float32:
    """Map one 2-bit IQ2 grid digit to its grid value (8/25/43)."""
    var grid_digit = (encoded_grid >> (grid_lane * 2)) & 3
    if grid_digit == 1:
        return Float32(25.0)
    if grid_digit == 2:
        return Float32(43.0)
    return Float32(8.0)


@always_inline
def _iq3_xxs_grid_digit_value(encoded_grid: Int, digit_lane: Int) -> Float32:
    """Map one 3-bit IQ3_XXS grid digit to its grid value."""
    var grid_digit = (encoded_grid >> (digit_lane * 3)) & 7
    if grid_digit == 7:
        return Float32(62.0)
    return Float32(4 + 8 * grid_digit)


# --- SIMD IQ block decode helpers (S-030) ---------------------------------
# dequantize_iq_block originally decoded every lane scalar: 256 iterations
# of shift/branch/sign work per super-block, while the K-quant fast path
# (kinds 10/11/13 in core/compute) decodes a block with width-16 SIMD
# stores. In single-row (decode) GEMMs that scalar decode is ~90% of the
# IQ GEMM cost, which is why IQ2_M ran ~9x slower per generated token
# than the K rungs while batched prefill (decode amortized over rows)
# was only ~1.4x slower. The helpers below decode a whole 8-lane (or
# 4-lane) grid group with vector ops only. Every mapping is exact in
# f32 for every possible digit (digits are small integers and the
# polynomial coefficients are dyadic), so decoded values are
# bit-identical to the scalar decoders above:
#   IQ2 grid value: digit 0->8, 1->25, 2->43, 3->8 is the cubic
#     -9 d^3 + 27.5 d^2 - 1.5 d + 8 (Horner form below).
#   IQ1_S grid value: digit 0->-1, 1->0, 2->1, 3->-1 is the cubic
#     -0.5 d^3 + 1.5 d^2 - 1 (Horner form at the use site).
#   IQ3_XXS grid value: 4 + 8 d for d < 7 and 62 for d = 7, i.e.
#     4 + 8 d + 2 * (d // 7) with integer division exact on 0..7.
# Signs are pure arithmetic: bit b -> 1 - 2 b. Multiplication order at
# every use site stays (coef * grid_value) * sign, exactly as scalar.


@always_inline
def _iq_sign8(bits: Int) -> SIMD[DType.float32, 8]:
    """Lanes 0..7 of `bits` as +1/-1 floats (bit set means -1)."""
    var b = SIMD[DType.uint32, 8](UInt32(bits))
    var sh = SIMD[DType.uint32, 8](0, 1, 2, 3, 4, 5, 6, 7)
    var v = (b >> sh) & UInt32(1)
    return Float32(1.0) - Float32(2.0) * v.cast[DType.float32]()


@always_inline
def _iq_sign4(bits: Int, base: Int) -> SIMD[DType.float32, 4]:
    """Lanes base..base+3 of `bits` as +1/-1 floats (bit set = -1)."""
    var b = SIMD[DType.uint32, 4](UInt32(bits))
    var sh = SIMD[DType.uint32, 4](
        UInt32(base), UInt32(base + 1), UInt32(base + 2), UInt32(base + 3)
    )
    var v = (b >> sh) & UInt32(1)
    return Float32(1.0) - Float32(2.0) * v.cast[DType.float32]()


@always_inline
def _iq2_gv8(encoded: Int) -> SIMD[DType.float32, 8]:
    """Eight 2-bit digits of an IQ2 grid entry as grid values."""
    var e = SIMD[DType.uint32, 8](UInt32(encoded))
    var sh = SIMD[DType.uint32, 8](0, 2, 4, 6, 8, 10, 12, 14)
    var d = ((e >> sh) & UInt32(3)).cast[DType.float32]()
    return (
        (Float32(-9.0) * d + Float32(27.5)) * d - Float32(1.5)
    ) * d + Float32(8.0)


@always_inline
def _iq_digits3_4(encoded: Int) -> SIMD[DType.uint32, 4]:
    """Four 3-bit digits of an IQ3 grid entry (lanes 0..3)."""
    var e = SIMD[DType.uint32, 4](UInt32(encoded))
    var sh = SIMD[DType.uint32, 4](0, 3, 6, 9)
    return (e >> sh) & UInt32(7)


@always_inline
def _iq4nl_map16(nib: SIMD[DType.uint32, 16]) -> SIMD[DType.float32, 16]:
    """Map 16 nibbles through kvalues_iq4nl with vector ops only.
    kv[n] = -127 + sum_k diff_k * step_k(n), where step_k(n) is
    max(n-(k-1),0) - max(n-k,0) (exactly 1 for n >= k, else 0) and
    diff_k = kv[k] - kv[k-1]. Every intermediate is a small integer,
    exact in f32, so the result is bit-identical to the scalar
    _iq4nl_kv lookup. (Mojo 1.0 SIMD == returns a scalar Bool, so
    mask/select table mapping is not available in this toolchain.)"""
    var nf = nib.cast[DType.float32]()
    var z = SIMD[DType.float32, 16](Float32(0.0))
    var r = SIMD[DType.float32, 16](Float32(-127.0))
    r += Float32(23.0) * (max(nf - Float32(0), z) - max(nf - Float32(1), z))
    r += Float32(21.0) * (max(nf - Float32(1), z) - max(nf - Float32(2), z))
    r += Float32(18.0) * (max(nf - Float32(2), z) - max(nf - Float32(3), z))
    r += Float32(16.0) * (max(nf - Float32(3), z) - max(nf - Float32(4), z))
    r += Float32(14.0) * (max(nf - Float32(4), z) - max(nf - Float32(5), z))
    r += Float32(13.0) * (max(nf - Float32(5), z) - max(nf - Float32(6), z))
    r += Float32(12.0) * (max(nf - Float32(6), z) - max(nf - Float32(7), z))
    r += Float32(11.0) * (max(nf - Float32(7), z) - max(nf - Float32(8), z))
    r += Float32(12.0) * (max(nf - Float32(8), z) - max(nf - Float32(9), z))
    r += Float32(12.0) * (max(nf - Float32(9), z) - max(nf - Float32(10), z))
    r += Float32(13.0) * (max(nf - Float32(10), z) - max(nf - Float32(11), z))
    r += Float32(15.0) * (max(nf - Float32(11), z) - max(nf - Float32(12), z))
    r += Float32(16.0) * (max(nf - Float32(12), z) - max(nf - Float32(13), z))
    r += Float32(20.0) * (max(nf - Float32(13), z) - max(nf - Float32(14), z))
    r += Float32(24.0) * (max(nf - Float32(14), z) - max(nf - Float32(15), z))
    return r

def dequantize_iq_block(
    data: Pointer[UInt8, MutUntrackedOrigin],
    block_base: Int,
    kind: Int,
    grid: Pointer[UInt16, MutUntrackedOrigin],
    out_ptr: Pointer[Float32, MutUntrackedOrigin],
):
    """Decode one complete 256-value IQ super-block at byte offset
    block_base into out_ptr[0..256). Group headers (scales, sign
    masks, grid indices) are derived once per 32-value group instead
    of once per element — the same values the *_value_g decoders
    compute, with their per-element arithmetic factored out. Lane
    values inside a group are produced with SIMD stores (S-030; see
    the helper block above) and are bit-identical to the scalar
    decoders. kind is the GGML tensor type (16/17/18/19/21/22); grid
    must be the grid materialized by iq_grid_materialize for that kind.
    """
    var scale = data.unsafe_offset(block_base).unsafe_bitcast[
        Float16
    ]().unsafe_load().cast[DType.float32]()
    if kind == 20:
        # IQ4_NL super-block: eight 32-value blocks of 18 bytes each
        # (144 bytes per 256 values; iq_block_bytes(20) == 144).
        for sb in range(8):
            var bb = block_base + sb * 18
            var d = data.unsafe_offset(bb).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
            var qv = data.unsafe_load[width=16](bb + 2).cast[DType.uint32]()
            out_ptr.unsafe_store[width=16](sb * 32, d * _iq4nl_map16(qv & UInt32(0x0F)))
            out_ptr.unsafe_store[width=16](sb * 32 + 16, d * _iq4nl_map16((qv >> UInt32(4)) & UInt32(0x0F)))
    elif kind == 23:
        # IQ4_XS super-block: 136 bytes; per-group scale from the
        # packed scales_h/scales_l (see iq4_xs_value for the layout).
        var scales_h = Int(_read_u16_le(data, block_base + 2))
        for group in range(8):
            var scales_l = Int(data.unsafe_load(block_base + 4 + group // 2))
            var ls = ((scales_l >> (4 * (group % 2))) & 0x0F) | (((scales_h >> (2 * group)) & 3) << 4)
            var dl = scale * Float32(ls - 32)
            var qv = data.unsafe_load[width=16](block_base + 8 + group * 16).cast[DType.uint32]()
            out_ptr.unsafe_store[width=16](group * 32, dl * _iq4nl_map16(qv & UInt32(0x0F)))
            out_ptr.unsafe_store[width=16](group * 32 + 16, dl * _iq4nl_map16((qv >> UInt32(4)) & UInt32(0x0F)))
    elif kind == 19:
        # IQ1_S: qs at +2 (32 bytes), qh u16s at +34 (8 groups).
        for group in range(8):
            var qh = Int(_read_u16_le(data, block_base + 34 + group * 2))
            var coef = scale * Float32(2 * ((qh >> 12) & 7) + 1)
            var delta = Float32(-0.125 if (qh & 0x8000) != 0 else 0.125)
            for sub in range(4):
                var grid_index = Int(
                    data.unsafe_load(block_base + 2 + group * 4 + sub)
                ) | (((qh >> (sub * 3)) & 7) << 8)
                var encoded = Int(grid.unsafe_load(grid_index))
                var base_out = group * 32 + sub * 8
                var e = SIMD[DType.uint32, 8](UInt32(encoded))
                var sh = SIMD[DType.uint32, 8](0, 2, 4, 6, 8, 10, 12, 14)
                var d = ((e >> sh) & UInt32(3)).cast[DType.float32]()
                var gv = (Float32(-0.5) * d + Float32(1.5)) * d * d - Float32(1.0)
                out_ptr.unsafe_store[width=8](base_out, coef * (gv + delta))
    elif kind == 16:
        # IQ2_XXS: eight groups of (4 grid bytes + u32 signs/scale).
        for group in range(8):
            var packed_base = block_base + 2 + group * 8
            var aux = _read_u32_le(data, packed_base + 4)
            var coef = scale * (Float32(0.5) + Float32(Int(aux >> 28))) * Float32(0.25)
            for sub in range(4):
                var encoded = Int(grid.unsafe_load(Int(data.unsafe_load(packed_base + sub))))
                var sign_mask = _iq2_sign_mask(Int((aux >> UInt32(sub * 7)) & UInt32(0x7F)))
                var base_out = group * 32 + sub * 8
                out_ptr.unsafe_store[width=8](
                    base_out, coef * _iq2_gv8(encoded) * _iq_sign8(sign_mask)
                )
    elif kind == 22:
        # IQ2_S: qs at +2 (grid bytes 0..31, sign bytes 32..63),
        # qh at +66, scales at +74.
        for group in range(8):
            var scale_byte = Int(data.unsafe_load(block_base + 74 + group))
            var qh = Int(data.unsafe_load(block_base + 66 + group))
            for sub in range(4):
                var nibble = (scale_byte & 15) if sub < 2 else (scale_byte >> 4)
                var coef = scale * (Float32(0.5) + Float32(nibble)) * Float32(0.25)
                var grid_index = Int(
                    data.unsafe_load(block_base + 2 + group * 4 + sub)
                ) | ((qh << (8 - 2 * sub)) & 0x300)
                var encoded = Int(grid.unsafe_load(grid_index))
                var sign_byte = Int(data.unsafe_load(block_base + 34 + group * 4 + sub))
                var base_out = group * 32 + sub * 8
                out_ptr.unsafe_store[width=8](
                    base_out, coef * _iq2_gv8(encoded) * _iq_sign8(sign_byte)
                )
    elif kind == 21:
        # IQ3_S: qs at +2, qh at +66, signs at +74, scales at +106.
        for group in range(8):
            var scale_byte = Int(data.unsafe_load(block_base + 106 + group // 2))
            var nibble = (scale_byte & 15) if group % 2 == 0 else (scale_byte >> 4)
            var coef = scale * Float32(1 + 2 * nibble)
            var qh = Int(data.unsafe_load(block_base + 66 + group))
            for sub in range(4):
                var sign_byte = Int(data.unsafe_load(block_base + 74 + group * 4 + sub))
                var idx1 = Int(
                    data.unsafe_load(block_base + 2 + group * 8 + 2 * sub)
                ) | (((qh >> (2 * sub)) & 1) << 8)
                var idx2 = Int(
                    data.unsafe_load(block_base + 2 + group * 8 + 2 * sub + 1)
                ) | (((qh >> (2 * sub + 1)) & 1) << 8)
                var enc1 = Int(grid.unsafe_load(idx1))
                var enc2 = Int(grid.unsafe_load(idx2))
                var base_out = group * 32 + sub * 8
                var v1 = _iq_digits3_4(enc1).cast[DType.float32]()
                var v2 = _iq_digits3_4(enc2).cast[DType.float32]()
                out_ptr.unsafe_store[width=4](
                    base_out,
                    coef * (Float32(2.0) * v1 + Float32(1.0)) * _iq_sign4(sign_byte, 0),
                )
                out_ptr.unsafe_store[width=4](
                    base_out + 4,
                    coef * (Float32(2.0) * v2 + Float32(1.0)) * _iq_sign4(sign_byte, 4),
                )
    elif kind == 17:
        # IQ2_XS: u16 grid/sign packs at +2, scales at +66.
        for group in range(8):
            var scale_byte = Int(data.unsafe_load(block_base + 66 + group))
            for sub in range(4):
                var nibble = (scale_byte & 15) if sub < 2 else (scale_byte >> 4)
                var coef = scale * (Float32(0.5) + Float32(nibble)) * Float32(0.25)
                var packed = Int(_read_u16_le(data, block_base + 2 + (group * 4 + sub) * 2))
                var encoded = Int(grid.unsafe_load(packed & 511))
                var sign_mask = _iq2_sign_mask(packed >> 9)
                var base_out = group * 32 + sub * 8
                out_ptr.unsafe_store[width=8](
                    base_out, coef * _iq2_gv8(encoded) * _iq_sign8(sign_mask)
                )
    else:
        # IQ3_XXS (kind 18): qs at +2 (64 grid bytes), then 32 bytes
        # of u32 sign/scale packs at +66.
        for group in range(8):
            var aux = _read_u32_le(data, block_base + 66 + group * 4)
            var coef = scale * (Float32(0.5) + Float32(Int(aux >> 28))) * Float32(0.5)
            for sub in range(4):
                var sign_mask = _iq2_sign_mask(Int((aux >> UInt32(7 * sub)) & UInt32(0x7F)))
                var enc1 = Int(grid.unsafe_load(Int(data.unsafe_load(block_base + 2 + group * 8 + 2 * sub))))
                var enc2 = Int(grid.unsafe_load(Int(data.unsafe_load(block_base + 2 + group * 8 + 2 * sub + 1))))
                var base_out = group * 32 + sub * 8
                var du1 = _iq_digits3_4(enc1)
                var du2 = _iq_digits3_4(enc2)
                var gv1 = Float32(4.0) + Float32(8.0) * du1.cast[DType.float32]() + Float32(2.0) * (du1 / UInt32(7)).cast[DType.float32]()
                var gv2 = Float32(4.0) + Float32(8.0) * du2.cast[DType.float32]() + Float32(2.0) * (du2 / UInt32(7)).cast[DType.float32]()
                out_ptr.unsafe_store[width=4](
                    base_out, coef * gv1 * _iq_sign4(sign_mask, 0)
                )
                out_ptr.unsafe_store[width=4](
                    base_out + 4, coef * gv2 * _iq_sign4(sign_mask, 4)
                )
