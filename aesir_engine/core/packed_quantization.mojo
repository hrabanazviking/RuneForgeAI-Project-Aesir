"""Architecture-neutral CUDA reads for packed GGML tensor formats.

Architecture kernels request scalar weights through ``packed_value`` and do
not interpret Q4_K, Q5_K, or Q6_K byte layouts themselves. GGUF admission
validates every tensor kind and byte span before these device reads execute.
"""
from std.memory import Pointer, bitcast


comptime Bytes = Pointer[UInt8, MutUntrackedOrigin]


@always_inline
def packed_block_group[kind: Int, group: Int](
    w: Bytes, p: Int, lane: Int, d: Float32, dmin: Float32
) -> Float32:
    """One lane's value in a validated 256-element K block.

    The projection owner hoists block addressing and half scales. Compile-time
    groups remove per-element division and quantization branches. Keep exactly
    packed_value's arithmetic order, including integer Q4/Q5 scale products.
    """
    comptime assert kind == 12 or kind == 13 or kind == 14
    comptime assert group >= 0 and group < 8
    comptime if kind == 14:
        comptime half = group // 4
        comptime within = group % 4
        var low = Int(w.unsafe_load(p + half * 64 + within % 2 * 32 + lane))
        low = (low >> (4 * (within // 2))) & 15
        var high = (Int(w.unsafe_load(p + 128 + half * 32 + lane)) >> (2 * within)) & 3
        var scale = w.unsafe_offset(p + 192).unsafe_bitcast[Int8]().unsafe_load(
            half * 8 + within * 2 + lane // 16)
        return d * Float32(scale) * Float32((low | (high << 4)) - 32)
    else:
        var scale: Int
        var minimum: Int
        comptime if group < 4:
            scale = Int(w.unsafe_load(p + 4 + group)) & 63
            minimum = Int(w.unsafe_load(p + 8 + group)) & 63
        else:
            scale = (Int(w.unsafe_load(p + 8 + group)) & 15) | ((Int(w.unsafe_load(p + group)) >> 6) << 4)
            minimum = (Int(w.unsafe_load(p + 8 + group)) >> 4) | ((Int(w.unsafe_load(p + 4 + group)) >> 6) << 4)
        comptime quants = 16 if kind == 12 else 48
        var q = (Int(w.unsafe_load(p + quants + group // 2 * 32 + lane)) >> (4 * (group % 2))) & 15
        comptime if kind == 13:
            q += ((Int(w.unsafe_load(p + 16 + lane)) >> group) & 1) * 16
        return d * Float32(scale * q) - dmin * Float32(minimum)


@always_inline
def packed_value(w: Bytes, base: Int, kind: Int, index: Int) -> Float32:
    if kind == 0:
        return w.unsafe_offset(base).unsafe_bitcast[Float32]().unsafe_load(index)
    if kind == 1:
        return w.unsafe_offset(base).unsafe_bitcast[Float16]().unsafe_load(index).cast[DType.float32]()
    if kind == 30:
        var bits = w.unsafe_offset(base).unsafe_bitcast[UInt16]().unsafe_load(index)
        return bitcast[DType.float32](UInt32(bits) << 16)
    var j = index % 256
    var block = index // 256
    if kind == 10:
        # GGML Q2_K: 16 scale/min bytes, 64 packed quant bytes, d, dmin.
        var p = base + block * 84
        var subblock = j // 16
        var group = (j % 128) // 32
        var lane_group = (j % 32) // 16
        var lane = j % 16
        var sc = Int(w.unsafe_load(p + subblock))
        var q = (Int(w.unsafe_load(p + 16 + (j // 128) * 32 + lane_group * 16 + lane)) >> (2 * group)) & 3
        var d = w.unsafe_offset(p + 80).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
        var dmin = w.unsafe_offset(p + 82).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
        return d * Float32(sc & 15) * Float32(q) - dmin * Float32(sc >> 4)
    if kind == 11:
        # GGML Q3_K: 32 high-bit bytes, 64 low-bit bytes, 12 scales, d.
        var p = base + block * 110
        var subblock = j // 16
        var low_scale = (Int(w.unsafe_load(p + 96 + subblock)) & 15) if subblock < 8 else (Int(w.unsafe_load(p + 96 + subblock - 8)) >> 4)
        var high_scale = (Int(w.unsafe_load(p + 104 + subblock % 4)) >> (2 * (subblock // 4))) & 3
        var scale = (low_scale | (high_scale << 4)) - 32
        var half = j // 128
        var within = j % 128
        var group = within // 32
        var lane_group = (within % 32) // 16
        var lane = within % 16
        var low = (Int(w.unsafe_load(p + 32 + half * 32 + lane_group * 16 + lane)) >> (2 * group)) & 3
        var high_set = (Int(w.unsafe_load(p + lane_group * 16 + lane)) >> (group + half * 4)) & 1
        var q = low if high_set == 1 else low - 4
        var d = w.unsafe_offset(p + 108).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
        return d * Float32(scale) * Float32(q)
    if kind == 14:
        # GGML Q6_K: 128 low bytes, 64 high bytes, 16 scales, d.
        var p = base + block * 210
        var half = j // 128
        var group = j % 128 // 32
        var lane = j % 32
        var low = Int(w.unsafe_load(p + half * 64 + group % 2 * 32 + lane))
        low = (low >> (4 * (group // 2))) & 15
        var high = (Int(w.unsafe_load(p + 128 + half * 32 + lane)) >> (2 * group)) & 3
        var scale = w.unsafe_offset(p + 192).unsafe_bitcast[Int8]().unsafe_load(half * 8 + group * 2 + lane // 16)
        var d = w.unsafe_offset(p + 208).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
        return d * Float32(scale) * Float32((low | (high << 4)) - 32)
    # GGUF admission permits only kind 12 (Q4_K) or 13 (Q5_K) here.
    var block_bytes = 144 if kind == 12 else 176
    var p = base + block * block_bytes
    var d = w.unsafe_offset(p).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
    var dmin = w.unsafe_offset(p + 2).unsafe_bitcast[Float16]().unsafe_load().cast[DType.float32]()
    var g = j // 32
    var scale: Int
    var minimum: Int
    if g < 4:
        scale = Int(w.unsafe_load(p + 4 + g)) & 63
        minimum = Int(w.unsafe_load(p + 8 + g)) & 63
    else:
        scale = (Int(w.unsafe_load(p + 8 + g)) & 15) | ((Int(w.unsafe_load(p + g)) >> 6) << 4)
        minimum = (Int(w.unsafe_load(p + 8 + g)) >> 4) | ((Int(w.unsafe_load(p + 4 + g)) >> 6) << 4)
    var qs = p + (16 if kind == 12 else 48)
    var q = (Int(w.unsafe_load(qs + j // 64 * 32 + j % 32)) >> (4 * (g % 2))) & 15
    if kind == 13:
        q += ((Int(w.unsafe_load(p + 16 + j % 32)) >> g) & 1) * 16
    return d * Float32(scale * q) - dmin * Float32(minimum)
