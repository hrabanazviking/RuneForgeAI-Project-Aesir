"""Native CUDA kernels for dense Gemma 4. See THIRD_PARTY_NOTICES.md.

Pointers are borrowed only by launches on the owning session's ordered stream.
All offsets and extents must be validated by the loader/session before launch.
"""
from std.memory import Pointer, bitcast
from std.gpu import global_idx
from std.gpu.primitives import warp
from std.math import sqrt, exp, log, cos, sin, tanh, isfinite
from core.packed_quantization import Bytes, packed_value
@always_inline
def fast_fast_tanh(x: Float32) -> Float32:
    return tanh(x)


comptime Floats = Pointer[Float32, MutUntrackedOrigin]
comptime Integers = Pointer[Int32, MutUntrackedOrigin]


def embedding_kernel(w: Bytes, a: Floats, base_arg: Int64, kind_arg: Int64, width_arg: Int64, token_arg: Int64, dst_arg: Int64, scale: Float32):
    var base = Int(base_arg)
    var kind = Int(kind_arg)
    var width = Int(width_arg)
    var token = Int(token_arg)
    var dst = Int(dst_arg)
    var i = Int(global_idx.x)
    if i < width:
        a.unsafe_store(dst + i, packed_value(w, base, kind, token * width + i) * scale)


def matvec_kernel(w: Bytes, a: Floats, base_arg: Int64, kind_arg: Int64, columns_arg: Int64, rows_arg: Int64, src_arg: Int64, dst_arg: Int64):
    var base = Int(base_arg)
    var kind = Int(kind_arg)
    var columns = Int(columns_arg)
    var rows = Int(rows_arg)
    var src = Int(src_arg)
    var dst = Int(dst_arg)
    var row = Int(global_idx.x) // 32
    var lane = Int(global_idx.x) % 32
    if row < rows:
        var total: Float32 = 0
        for col in range(lane, columns, 32):
            total += packed_value(w, base, kind, row * columns + col) * a.unsafe_load(src + col)
        total = warp.sum(total)
        if lane == 0:
            a.unsafe_store(dst + row, total)


def norm_kernel(w: Bytes, a: Floats, weight_arg: Int64, src_arg: Int64, dst_arg: Int64, width_arg: Int64, groups_arg: Int64, epsilon: Float32, scale: Float32):
    var weight = Int(weight_arg)
    var src = Int(src_arg)
    var dst = Int(dst_arg)
    var width = Int(width_arg)
    var groups = Int(groups_arg)
    var group = Int(global_idx.x) // 32
    var lane = Int(global_idx.x) % 32
    if group < groups:
        var total: Float32 = 0
        for j in range(lane, width, 32):
            var value = a.unsafe_load(src + group * width + j) * scale
            total += value * value
        var inv = 1.0 / sqrt(warp.sum(total) / Float32(width) + epsilon)
        for j in range(lane, width, 32):
            var v = a.unsafe_load(src + group * width + j) * scale * inv
            if weight >= 0:
                v *= packed_value(w, weight, 0, j)
            a.unsafe_store(dst + group * width + j, v)


@always_inline
def fast_tanh(x: Float32) -> Float32:
    return tanh(x)

def element_kernel(w: Bytes, a: Floats, op_arg: Int64, src_arg: Int64, second_arg: Int64, dst_arg: Int64, count_arg: Int64, scale: Float32):
    var op = Int(op_arg)
    var src = Int(src_arg)
    var second = Int(second_arg)
    var dst = Int(dst_arg)
    var count = Int(count_arg)
    var i = Int(global_idx.x)
    if i < count:
        var value = a.unsafe_load(src + i)
        if op == 0:
            value *= scale
        elif op == 1:
            value = (value + a.unsafe_load(second + i)) * scale
        elif op == 2:
            value = 0.5 * value * (1.0 + fast_tanh(0.7978845608028654 * value * (1.0 + 0.044715 * value * value))) * a.unsafe_load(second + i)
        elif op == 3:
            value *= packed_value(w, second, 0, 0)
        elif op == 4:
            value = scale * fast_tanh(value / scale)
        a.unsafe_store(dst + i, value)


def rope_kernel(w: Bytes, a: Floats, src_arg: Int64, width_arg: Int64, heads_arg: Int64, position_arg: Int64, freq_base: Float32, factors_arg: Int64):
    var src = Int(src_arg)
    var width = Int(width_arg)
    var heads = Int(heads_arg)
    var position = Int(position_arg)
    var factors = Int(factors_arg)
    var i = Int(global_idx.x)
    if i < heads * width // 2:
        var head = i // (width // 2)
        var j = i % (width // 2)
        var theta = Float32(position) * exp(-log(freq_base) * Float32(2 * j) / Float32(width))
        if factors >= 0:
            theta /= packed_value(w, factors, 0, j)
        var first = src + head * width + j
        var second = first + width // 2
        var x = a.unsafe_load(first)
        var y = a.unsafe_load(second)
        a.unsafe_store(first, x * cos(theta) - y * sin(theta))
        a.unsafe_store(second, x * sin(theta) + y * cos(theta))


def cache_kernel(a: Floats, kv: Floats, key_arg: Int64, value_arg: Int64, offset_arg: Int64, capacity_arg: Int64, width_arg: Int64, position_arg: Int64):
    var key = Int(key_arg)
    var value = Int(value_arg)
    var offset = Int(offset_arg)
    var capacity = Int(capacity_arg)
    var width = Int(width_arg)
    var position = Int(position_arg)
    var i = Int(global_idx.x)
    if i < width:
        var slot = position % capacity
        kv.unsafe_store(offset + slot * width + i, a.unsafe_load(key + i))
        kv.unsafe_store(offset + capacity * width + slot * width + i, a.unsafe_load(value + i))


def scores_kernel(a: Floats, kv: Floats, query_arg: Int64, scores_arg: Int64,
                  offset_arg: Int64, capacity_arg: Int64, width_arg: Int64,
                  query_heads_arg: Int64, kv_heads_arg: Int64,
                  start_arg: Int64, count_arg: Int64):
    var query = Int(query_arg)
    var scores = Int(scores_arg)
    var offset = Int(offset_arg)
    var capacity = Int(capacity_arg)
    var width = Int(width_arg)
    var query_heads = Int(query_heads_arg)
    var kv_heads = Int(kv_heads_arg)
    var start = Int(start_arg)
    var count = Int(count_arg)
    var item = Int(global_idx.x) // 32
    var lane = Int(global_idx.x) % 32
    if item < query_heads * count:
        var head = item // count
        var kv_head = head * kv_heads // query_heads
        var t = item % count
        var slot = (start + t) % capacity
        var total: Float32 = 0
        for j in range(lane, width, 32):
            total += a.unsafe_load(query + head * width + j) * kv.unsafe_load(offset + slot * kv_heads * width + kv_head * width + j)
        total = warp.sum(total)
        if lane == 0:
            a.unsafe_store(scores + item, total)


def softmax_kernel(a: Floats, scores_arg: Int64, count_arg: Int64,
                   query_heads_arg: Int64):
    var scores = Int(scores_arg)
    var count = Int(count_arg)
    var query_heads = Int(query_heads_arg)
    var head = Int(global_idx.x) // 32
    var lane = Int(global_idx.x) % 32
    if head < query_heads:
        var maximum: Float32 = -3.4028235e38
        for t in range(lane, count, 32):
            maximum = max(maximum, a.unsafe_load(scores + head * count + t))
        maximum = warp.max(maximum)
        var total: Float32 = 0
        for t in range(lane, count, 32):
            total += exp(a.unsafe_load(scores + head * count + t) - maximum)
        total = warp.sum(total)
        for t in range(lane, count, 32):
            var index = scores + head * count + t
            a.unsafe_store(index, exp(a.unsafe_load(index) - maximum) / total)


def attention_kernel(a: Floats, kv: Floats, scores_arg: Int64, dst_arg: Int64,
                     offset_arg: Int64, capacity_arg: Int64, width_arg: Int64,
                     query_heads_arg: Int64, kv_heads_arg: Int64,
                     start_arg: Int64, count_arg: Int64):
    var scores = Int(scores_arg)
    var dst = Int(dst_arg)
    var offset = Int(offset_arg)
    var capacity = Int(capacity_arg)
    var width = Int(width_arg)
    var query_heads = Int(query_heads_arg)
    var kv_heads = Int(kv_heads_arg)
    var start = Int(start_arg)
    var count = Int(count_arg)
    var i = Int(global_idx.x)
    if i < query_heads * width:
        var head = i // width
        var kv_head = head * kv_heads // query_heads
        var j = i % width
        var total: Float32 = 0
        var base = offset + capacity * kv_heads * width + kv_head * width + j
        for t in range(count):
            var slot = (start + t) % capacity
            total += a.unsafe_load(scores + head * count + t) * kv.unsafe_load(base + slot * kv_heads * width)
        a.unsafe_store(dst + i, total)


def argmax_kernel(a: Floats, output: Integers, logits_arg: Int64, count_arg: Int64):
    var logits = Int(logits_arg)
    var count = Int(count_arg)
    var lane = Int(global_idx.x)
    var best = -bitcast[DType.float32](UInt32(0x7f800000))
    var best_id = Int32(2147483647)
    var bad = Int32(0)
    for i in range(lane, count, 32):
        var value = a.unsafe_load(logits + i)
        if not isfinite(value):
            bad = 1
        if value > best:
            best = value
            best_id = Int32(i)
    var winner = warp.max(best)
    var selected = warp.min(best_id if best == winner else Int32(2147483647))
    bad = warp.max(bad)
    if lane == 0:
        output.unsafe_store(0, selected if bad == 0 else Int32(-1))
