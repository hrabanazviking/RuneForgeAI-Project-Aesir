"""Fixed-width RMS normalization with the scalar warp's arithmetic order.

Strict profile admission owns dimensions and F32 normalization weights. Keep
one lane's original chronological sum, but expose independent loads to the
compiler in small register tiles. Avoid retaining a whole vector per lane,
which increases register pressure. The second pass uses the same small tiles.
Original runtime-width normalization remains the fallback/reference.
"""
from std.gpu import global_idx
from std.gpu.primitives import warp
from std.math import sqrt
from core.packed_quantization import Bytes
from core.packed_projection import ProjectionFloats


def dense_norm_kernel[width: Int](
    w: Bytes, a: ProjectionFloats, weight_arg: Int64, src_arg: Int64,
    dst_arg: Int64, groups_arg: Int64, epsilon: Float32
):
    comptime assert width > 0 and width % 128 == 0
    var group = Int(global_idx.x) // 32
    var lane = Int(global_idx.x) % 32
    if group < Int(groups_arg):
        var total: Float32 = 0
        comptime for chunk in range(width // 128):
            var base = Int(src_arg) + group * width + chunk * 128 + lane
            var v0 = a.unsafe_load(base)
            var v1 = a.unsafe_load(base + 32)
            var v2 = a.unsafe_load(base + 64)
            var v3 = a.unsafe_load(base + 96)
            total += v0 * v0
            total += v1 * v1
            total += v2 * v2
            total += v3 * v3
        var inv = 1.0 / sqrt(warp.sum(total) / Float32(width) + epsilon)
        comptime for chunk in range(width // 128):
            var index = chunk * 128 + lane
            var src = Int(src_arg) + group * width + index
            var dst = Int(dst_arg) + group * width + index
            var v0 = a.unsafe_load(src) * inv
            var v1 = a.unsafe_load(src + 32) * inv
            var v2 = a.unsafe_load(src + 64) * inv
            var v3 = a.unsafe_load(src + 96) * inv
            if Int(weight_arg) >= 0:
                var weight = w.unsafe_offset(Int(weight_arg)).unsafe_bitcast[Float32]()
                v0 *= weight.unsafe_load(index)
                v1 *= weight.unsafe_load(index + 32)
                v2 *= weight.unsafe_load(index + 64)
                v3 *= weight.unsafe_load(index + 96)
            a.unsafe_store(dst, v0)
            a.unsafe_store(dst + 32, v1)
            a.unsafe_store(dst + 64, v2)
            a.unsafe_store(dst + 96, v3)
