"""J-088 bench harness: dequant cost measured inside
attention, and the faithfulness exercise, at module level.

Shape (fixed, small, stated): 1 layer, 8 kv-heads,
head_dim 128 (kv_width 1024 -- the Llama-3-class head
geometry), 256 positions. Synthetic values are multiples
of 1/8 in [-1, 1], exactly representable in f16, so the
unquantized reference rows hold exactly the values an f16
cache would hold: the comparison is int8 vs the f16 path's
values, computed by the module's f32 reference attention
(core/kv_int8.attention_f32_head, identical math, no
quantization). One attention STEP = one query token
attending over all 256 positions for all 8 kv-heads.
Warmup 20 steps, then 200 measured steps per path, one
process, one run -- the filed numbers are
MEASURED-INDICATIVE (single run, contended VM), never a
baseline. Run: see docs/janas/J088_8BIT_KV.md.
"""
from std.collections import InlineArray
from std.ffi import external_call

from core.kv_int8 import (
    Int8KVStore,
    attention_f32_head,
    attention_int8_head,
)


def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("bench: cannot observe monotonic clock")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


def synth(i: Int) -> Float32:
    return Float32((i * 37 + (i // 13) * 7) % 17 - 8) / Float32(8.0)


def main() raises:
    comptime LAYERS = 1
    comptime HEADS = 8
    comptime HD = 128
    comptime SEQ = 256
    comptime WARM = 20
    comptime REPS = 200
    var width = HEADS * HD
    var store = Int8KVStore(LAYERS, HEADS, HD, SEQ)
    # Per-head reference rows for head-sliced attention.
    var ref_k = List[List[Float32]]()
    var ref_v = List[List[Float32]]()
    for _ in range(HEADS):
        ref_k.append(List[Float32]())
        ref_v.append(List[Float32]())
    for t in range(SEQ):
        var krow = List[Float32]()
        var vrow = List[Float32]()
        for j in range(width):
            krow.append(synth(t * width + j + 11))
            vrow.append(synth(t * width + j + 5000))
        store.append(0, t, krow, vrow)
        for h in range(HEADS):
            for j in range(HD):
                ref_k[h].append(krow[h * HD + j])
                ref_v[h].append(vrow[h * HD + j])
    var queries = List[List[Float32]]()
    for h in range(HEADS):
        var q = List[Float32]()
        for j in range(HD):
            q.append(synth(h * HD + j + 97))
        queries.append(q^)

    # -- faithfulness: K/V round-trip over every element --
    var max_err = Float32(0)
    var sum_err = Float64(0)
    var count = 0
    for t in range(SEQ):
        var rk = store.read_k(0, t)
        var rv = store.read_v(0, t)
        for h in range(HEADS):
            for j in range(HD):
                var ek = rk[h * HD + j] - ref_k[h][t * HD + j]
                if ek < Float32(0):
                    ek = -ek
                if ek > max_err:
                    max_err = ek
                sum_err += Float64(ek)
                count += 1
                var ev = rv[h * HD + j] - ref_v[h][t * HD + j]
                if ev < Float32(0):
                    ev = -ev
                if ev > max_err:
                    max_err = ev
                sum_err += Float64(ev)
                count += 1
    print(
        "FAITH_KV elements=" + String(count)
        + " max_abs_err=" + String(max_err)
        + " mean_abs_err=" + String(sum_err / Float64(count))
    )

    # -- faithfulness: attention output deviation --
    var amax = Float32(0)
    var asum = Float64(0)
    var acount = 0
    var sink = Float64(0)
    for h in range(HEADS):
        var got = attention_int8_head(store, 0, h, queries[h], SEQ)
        var want = attention_f32_head(ref_k[h], ref_v[h], queries[h], SEQ, HD)
        for j in range(HD):
            var d = got[j] - want[j]
            if d < Float32(0):
                d = -d
            if d > amax:
                amax = d
            asum += Float64(d)
            acount += 1
            sink += Float64(got[j])
    print(
        "FAITH_ATTN elements=" + String(acount)
        + " max_abs_dev=" + String(amax)
        + " mean_abs_dev=" + String(asum / Float64(acount))
        + " sink=" + String(sink)
    )

    # -- wall: int8 (dequant inside attention) --
    for _ in range(WARM):
        for h in range(HEADS):
            var o = attention_int8_head(store, 0, h, queries[h], SEQ)
            sink += Float64(o[0])
    var t0 = monotonic_ns()
    for _ in range(REPS):
        for h in range(HEADS):
            var o = attention_int8_head(store, 0, h, queries[h], SEQ)
            sink += Float64(o[0])
    var int8_ns = monotonic_ns() - t0
    # -- wall: unquantized reference path, identical data --
    for _ in range(WARM):
        for h in range(HEADS):
            var o = attention_f32_head(ref_k[h], ref_v[h], queries[h], SEQ, HD)
            sink += Float64(o[0])
    var t1 = monotonic_ns()
    for _ in range(REPS):
        for h in range(HEADS):
            var o = attention_f32_head(ref_k[h], ref_v[h], queries[h], SEQ, HD)
            sink += Float64(o[0])
    var ref_ns = monotonic_ns() - t1
    print(
        "WALL reps=" + String(REPS)
        + " int8_total_ns=" + String(int8_ns)
        + " int8_ns_per_step=" + String(int8_ns // REPS)
        + " ref_total_ns=" + String(ref_ns)
        + " ref_ns_per_step=" + String(ref_ns // REPS)
        + " ratio_x1000=" + String((int8_ns * 1000) // ref_ns)
        + " sink=" + String(sink)
    )
    print("BENCH DONE")
