"""Row-aligned native K-quant projections; formats belong to packed_quantization.

The caller admits byte spans and requires columns divisible by 256. Each warp
owns one output row. Lane/group accumulation follows the scalar reference, with
the same final warp reduction and no additional device workspace.
"""
from std.memory import Pointer
from std.gpu import global_idx
from std.gpu.primitives import warp
from core.packed_quantization import Bytes, packed_block_group

comptime ProjectionFloats = Pointer[Float32, MutUntrackedOrigin]


def block_matvec_kernel[kind: Int](
    w: Bytes, a: ProjectionFloats, base_arg: Int64, columns_arg: Int64,
    rows_arg: Int64, src_arg: Int64, dst_arg: Int64
):
    comptime assert kind == 12 or kind == 13 or kind == 14
    comptime block_bytes = 144 if kind == 12 else (176 if kind == 13 else 210)
    var row = Int(global_idx.x) // 32
    var lane = Int(global_idx.x) % 32
    var columns = Int(columns_arg)
    if row < Int(rows_arg):
        var total: Float32 = 0
        var first = Int(base_arg) + row * (columns // 256) * block_bytes
        for block in range(columns // 256):
            var p = first + block * block_bytes
            var d = w.unsafe_offset(p + (208 if kind == 14 else 0)).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
            var dmin: Float32 = 0
            comptime if kind != 14:
                dmin = w.unsafe_offset(p + 2).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
            comptime for group in range(8):
                total += packed_block_group[kind, group](w, p, lane, d, dmin) * a.unsafe_load(
                    Int(src_arg) + block * 256 + group * 32 + lane)
        total = warp.sum(total)
        if lane == 0:
            a.unsafe_store(Int(dst_arg) + row, total)
