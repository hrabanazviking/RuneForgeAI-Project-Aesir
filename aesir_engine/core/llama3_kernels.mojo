"""Native dense GQA operations; validated extents supplied by family profiles.

GGUF Llama Q/K matrices use adjacent-pair RoPE. KV storage is F16, while
dot products, softmax and residual activations accumulate in F32.
"""
from std.memory import Pointer
from std.gpu import global_idx
from std.gpu.primitives import warp
from std.math import exp, log, cos, sin, sqrt, floor
from core.gemma4_kernels import Floats

comptime Halves = Pointer[Float16, MutUntrackedOrigin]


def llama_rope(a: Floats, src_arg: Int64, width_arg: Int64, heads_arg: Int64,
               position_arg: Int64, frequency_base_arg: Float32,
               neox_arg: Int64):
    var i = Int(global_idx.x)
    var width = Int(width_arg)
    var half = width // 2
    if i < Int(heads_arg) * half:
        var head = i // half
        var j = i % half
        # F64 angle reduction prevents accumulated phase error near 8K;
        # activations and output remain F32 on the same CUDA device.
        var theta = Float64(position_arg) * exp(
            -log(Float64(frequency_base_arg)) * Float64(2 * j) / Float64(width)
        )
        var period = Float64(6.2831853071795864769)
        var reduced = (theta - floor(theta / period) * period).cast[DType.float32]()
        var c = cos(reduced)
        var s = sin(reduced)
        var first = Int(src_arg) + head * width + (j if neox_arg != 0 else 2 * j)
        var second = first + (half if neox_arg != 0 else 1)
        var x = a.unsafe_load(first)
        var y = a.unsafe_load(second)
        a.unsafe_store(first, x * c - y * s)
        a.unsafe_store(second, x * s + y * c)


def llama_silu(a: Floats, gate_arg: Int64, up_arg: Int64, count_arg: Int64):
    var i = Int(global_idx.x)
    if i < Int(count_arg):
        var gate = a.unsafe_load(Int(gate_arg) + i)
        a.unsafe_store(Int(up_arg) + i, gate / (1 + exp(-gate)) * a.unsafe_load(Int(up_arg) + i))


def llama_cache(a: Floats, kv: Halves, key_arg: Int64, value_arg: Int64,
                offset_arg: Int64, capacity_arg: Int64, width_arg: Int64,
                position_arg: Int64):
    var i = Int(global_idx.x)
    var width = Int(width_arg)
    if i < width:
        var slot = Int(offset_arg) + Int(position_arg) * width + i
        kv.unsafe_store(slot, a.unsafe_load(Int(key_arg) + i).cast[DType.float16]())
        kv.unsafe_store(slot + Int(capacity_arg) * width, a.unsafe_load(Int(value_arg) + i).cast[DType.float16]())


def llama_scores(a: Floats, kv: Halves, query_arg: Int64, scores_arg: Int64,
                 offset_arg: Int64, count_arg: Int64, head_dim_arg: Int64,
                 query_heads_arg: Int64, kv_heads_arg: Int64):
    var item = Int(global_idx.x) // 32
    var lane = Int(global_idx.x) % 32
    var count = Int(count_arg)
    var head_dim = Int(head_dim_arg)
    var query_heads = Int(query_heads_arg)
    var kv_heads = Int(kv_heads_arg)
    var kv_width = kv_heads * head_dim
    if item < query_heads * count:
        var head = item // count
        var kv_head = head * kv_heads // query_heads
        var t = item % count
        var total: Float32 = 0
        for j in range(lane, head_dim, 32):
            total += a.unsafe_load(Int(query_arg) + head * head_dim + j) * kv.unsafe_load(Int(offset_arg) + t * kv_width + kv_head * head_dim + j).cast[DType.float32]()
        total = warp.sum(total)
        if lane == 0:
            a.unsafe_store(Int(scores_arg) + item, total / sqrt(Float32(head_dim)))


def llama_softmax(a: Floats, scores_arg: Int64, count_arg: Int64,
                  query_heads_arg: Int64):
    var head = Int(global_idx.x) // 32
    var lane = Int(global_idx.x) % 32
    var count = Int(count_arg)
    if head < Int(query_heads_arg):
        var base = Int(scores_arg) + head * count
        var maximum: Float32 = -3.4028235e38
        for t in range(lane, count, 32):
            maximum = max(maximum, a.unsafe_load(base + t))
        maximum = warp.max(maximum)
        var total: Float32 = 0
        for t in range(lane, count, 32):
            total += exp(a.unsafe_load(base + t) - maximum)
        total = warp.sum(total)
        for t in range(lane, count, 32):
            a.unsafe_store(base + t, exp(a.unsafe_load(base + t) - maximum) / total)


def llama_attention(a: Floats, kv: Halves, scores_arg: Int64, dst_arg: Int64,
                    offset_arg: Int64, capacity_arg: Int64, count_arg: Int64,
                    head_dim_arg: Int64, query_heads_arg: Int64,
                    kv_heads_arg: Int64):
    var i = Int(global_idx.x)
    var head_dim = Int(head_dim_arg)
    var query_heads = Int(query_heads_arg)
    var kv_heads = Int(kv_heads_arg)
    var kv_width = kv_heads * head_dim
    if i < query_heads * head_dim:
        var head = i // head_dim
        var kv_head = head * kv_heads // query_heads
        var base = Int(offset_arg) + Int(capacity_arg) * kv_width + kv_head * head_dim + i % head_dim
        var total: Float32 = 0
        for t in range(Int(count_arg)):
            total += a.unsafe_load(Int(scores_arg) + head * Int(count_arg) + t) * kv.unsafe_load(base + t * kv_width).cast[DType.float32]()
        a.unsafe_store(Int(dst_arg) + i, total)
