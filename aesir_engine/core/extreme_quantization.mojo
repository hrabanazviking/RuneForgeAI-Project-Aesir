"""Canonical raw-byte IQ and versioned native ternary primitives."""

from std.memory import Pointer

from .iq_codebooks import IQ1_S_GRID, IQ2_XXS_GRID


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
def iq2_xxs_value(
    data: Pointer[UInt8, MutUntrackedOrigin], base: Int, index: Int
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
    var encoded_grid = Int(IQ2_XXS_GRID[grid_index])
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
    for index in range(output_elements):
        output.unsafe_store(
            index, iq2_xxs_value(data, 0, index).cast[DType.float16]()
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
def iq1_s_value(
    data: Pointer[UInt8, MutUntrackedOrigin], base: Int, index: Int
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
    var encoded_grid = Int(IQ1_S_GRID[grid_index])
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
    for index in range(output_elements):
        output.unsafe_store(
            index, iq1_s_value(data, 0, index).cast[DType.float16]()
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
