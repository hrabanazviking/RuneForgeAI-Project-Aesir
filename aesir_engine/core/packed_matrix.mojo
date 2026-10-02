"""Experimental bounded SIMT matrix projection; not a default inference path.

Format equations remain in packed_quantization. Each block stages 32 rows of
decoded weights and 4/8/16/32 activation rows. Padded shared rows avoid stride-32
bank conflicts. Column-chronological F32 dots differ from warp reduction order.
All threads execute both barriers even in row/token tails.
"""
from std.memory import stack_allocation, AddressSpace
from std.gpu import block_idx, thread_idx
from max.gpu import barrier
from max.gpu.host import DeviceContext, DeviceBuffer
from std.collections import InlineArray
from core.packed_quantization import Bytes, packed_block_group
from core.packed_projection import ProjectionFloats


def packed_matrix_kernel[kind: Int, batch: Int, tile_rows: Int = 32, tile_columns: Int = 32](
    w: Bytes, a: ProjectionFloats, base_arg: Int64, columns_arg: Int64,
    rows_arg: Int64, src_arg: Int64, dst_arg: Int64, stride_arg: Int64, tokens_arg: Int64
):
    comptime assert kind == 12 or kind == 13 or kind == 14
    comptime assert batch == 4 or batch == 8 or batch == 16 or batch == 32
    comptime assert tile_rows == 8 or tile_rows == 16 or tile_rows == 32
    comptime assert tile_columns == 32 or tile_columns == 64 or tile_columns == 128
    comptime assert (tile_rows + batch) * (tile_columns + 1) * 4 <= 49152
    comptime block_bytes = 144 if kind == 12 else (176 if kind == 13 else 210)
    comptime outputs = (tile_rows * batch + 127) // 128
    comptime pitch = tile_columns + 1
    var weights = stack_allocation[tile_rows * pitch, Float32, address_space=AddressSpace.SHARED]()
    var inputs = stack_allocation[batch * pitch, Float32, address_space=AddressSpace.SHARED]()
    var tid = Int(thread_idx.x)
    var first_row = Int(block_idx.x) * tile_rows
    var lane = tid % 32
    var totals = InlineArray[Float32, outputs](fill=0)
    var columns = Int(columns_arg)
    for block in range(columns // 256):
        comptime for section in range(256 // tile_columns):
            # Every 32-column subgroup is staged before the section barrier.
            comptime for subgroup in range(tile_columns // 32):
                comptime group = section * (tile_columns // 32) + subgroup
                comptime for part in range(tile_rows // 4):
                    var local_row = tid // 32 + part * 4
                    var row = first_row + local_row
                    var value: Float32 = 0
                    if row < Int(rows_arg):
                        var p = Int(base_arg) + (row * (columns // 256) + block) * block_bytes
                        var d = w.unsafe_offset(p + (208 if kind == 14 else 0)).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
                        var dmin: Float32 = 0
                        comptime if kind != 14:
                            dmin = w.unsafe_offset(p + 2).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
                        value = packed_block_group[kind, group](w, p, lane, d, dmin)
                    weights.unsafe_store(local_row * pitch + subgroup * 32 + lane, value)
                comptime for part in range(batch // 4):
                    var token = tid // 32 + part * 4
                    var value: Float32 = 0
                    if token < Int(tokens_arg):
                        value = a.unsafe_load(Int(src_arg) + token * Int(stride_arg) + block * 256 + group * 32 + lane)
                    inputs.unsafe_store(token * pitch + subgroup * 32 + lane, value)
            barrier()
            comptime for output in range(outputs):
                var linear = tid + output * 128
                if linear < tile_rows * batch:
                    var local_row = linear // batch
                    var token = linear % batch
                    comptime for column in range(tile_columns):
                        totals[output] += weights.unsafe_load(local_row * pitch + column) * inputs.unsafe_load(token * pitch + column)
            barrier()
    comptime for output in range(outputs):
        var linear = tid + output * 128
        if linear < tile_rows * batch:
            var row = first_row + linear // batch
            var token = linear % batch
            if row < Int(rows_arg) and token < Int(tokens_arg):
                a.unsafe_store(Int(dst_arg) + token * Int(stride_arg) + row, totals[output])


def admit_matrix[kind: Int, batch: Int, tile_rows: Int = 32, tile_columns: Int = 32](
    weight_bytes: Int, elements: Int, base: Int, columns: Int, rows: Int,
    src: Int, dst: Int, stride: Int, tokens: Int
) raises:
    comptime assert kind == 12 or kind == 13 or kind == 14
    comptime assert batch == 4 or batch == 8 or batch == 16 or batch == 32
    comptime assert tile_rows == 8 or tile_rows == 16 or tile_rows == 32
    comptime assert tile_columns == 32 or tile_columns == 64 or tile_columns == 128
    comptime assert (tile_rows + batch) * (tile_columns + 1) * 4 <= 49152
    # Fixed limits make all subsequent products fit signed Int64 on this target.
    if columns < 256 or columns > 14336 or columns % 256 != 0 or rows < 1 or rows > 128256:
        raise Error("Matrix candidate shape outside admitted bounds")
    if tokens < 1 or tokens > batch or base < 0 or src < 0 or dst < 0 or stride < 1:
        raise Error("Matrix candidate has invalid span metadata")
    comptime block_bytes = 144 if kind == 12 else (176 if kind == 13 else 210)
    var needed = rows * (columns // 256) * block_bytes
    if base > weight_bytes or needed > weight_bytes - base:
        raise Error("Matrix candidate weights exceed borrowed buffer")
    if src > stride or columns > stride - src or dst > stride or rows > stride - dst:
        raise Error("Matrix candidate span crosses token stride")
    if src < dst + rows and dst < src + columns:
        raise Error("Matrix candidate inputs and outputs overlap")
    if stride > elements // tokens or src + columns > stride or dst + rows > stride:
        raise Error("Matrix candidate token spans exceed borrowed allocation")


def project_matrix[kind: Int, batch: Int, tile_rows: Int = 32, tile_columns: Int = 32](
    ctx: DeviceContext, weights: DeviceBuffer[DType.uint8], activation: DeviceBuffer[DType.float32],
    base: Int, columns: Int, rows: Int, src: Int, dst: Int, stride: Int, tokens: Int
) raises:
    admit_matrix[kind, batch, tile_rows, tile_columns](len(weights), len(activation), base, columns, rows, src, dst, stride, tokens)
    var wp = Bytes(unsafe_from_address=Int(weights.unsafe_ptr()))
    var ap = ProjectionFloats(unsafe_from_address=Int(activation.unsafe_ptr()))
    ctx.enqueue_function[packed_matrix_kernel[kind, batch, tile_rows, tile_columns]](wp, ap, Int64(base), Int64(columns),
        Int64(rows), Int64(src), Int64(dst), Int64(stride), Int64(tokens),
        grid_dim=(rows + tile_rows - 1) // tile_rows, block_dim=128)
