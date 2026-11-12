# A-040 K-quant GEMV audit bench (standalone, not in run_all).
# Fixtures: deterministic synthetic super-blocks (LCG seed 0xA040),
# headers d/dmin pinned to sane f16 values, quant bytes LCG-filled.
# Oracle: scalar packed_value() per element (the preserved comparator).
from std.time import perf_counter_ns
from std.memory import Pointer
from std.memory.alloc import alloc
from core.compute import dequantize_ggml_k, gemm_q4_k_m, gemm_q5_k_m, gemm_q6_k
from core.packed_quantization import packed_value
from core.mimir_well import RuneTensor, f16, f32

def lcg(state: Int64) -> Int64:
    return state * Int64(6364136223846793005) + Int64(1442695040888963407)

def fill_block(w: Pointer[UInt8, MutUntrackedOrigin], p: Int, kind: Int, seed: Int64):
    var bb = 144 if kind == 12 else 176 if kind == 13 else 210
    var s = seed
    for i in range(bb):
        s = lcg(s)
        w.unsafe_store(p + i, UInt8((s >> 33) & 0xFF))
    # pin d (and dmin) to sane f16: 0.046875 = 0x2E00, 0.01171875 = 0x1E00
    if kind == 14:
        w.unsafe_store(p + 208, UInt8(0x00)); w.unsafe_store(p + 209, UInt8(0x2E))
    else:
        w.unsafe_store(p + 0, UInt8(0x00)); w.unsafe_store(p + 1, UInt8(0x2E))
        w.unsafe_store(p + 2, UInt8(0x00)); w.unsafe_store(p + 3, UInt8(0x1E))

def median(mut v: List[Int]) -> Int:
    for i in range(len(v)):
        for j in range(i + 1, len(v)):
            if v[j] < v[i]:
                var t = v[i]; v[i] = v[j]; v[j] = t
    return v[len(v) // 2]

def main() raises:
    print("A040_BENCH start")
    comptime NB = 8192
    comptime NE = NB * 256
    for kind in [12, 13, 14]:
        var bb = 144 if kind == 12 else 176 if kind == 13 else 210
        var w = alloc[UInt8](NB * bb)
        var s = Int64(0xA040) + Int64(kind)
        for b in range(NB):
            s = lcg(s + Int64(b))
            fill_block(w, b * bb, kind, s)
        var out = alloc[Scalar[f16]](NE)
        # parity: dequantize vs scalar packed_value, bit-exact f16
        dequantize_ggml_k(w, out, NE, kind)
        var bad = 0
        var firstbad = -1
        for i in range(NE):
            var refv = packed_value(w, 0, kind, i).cast[f16]()
            if out.unsafe_load(i) != refv:
                bad += 1
                if firstbad < 0: firstbad = i
        print("DEQ_PARITY kind=", kind, " bad=", bad, " firstbad=", firstbad, " of ", NE)
        # timing: dequantize, 15 reps
        var times = List[Int]()
        for _ in range(15):
            var t0 = perf_counter_ns()
            dequantize_ggml_k(w, out, NE, kind)
            times.append(Int(perf_counter_ns() - t0))
        print("DEQ_TIME kind=", kind, " median_ns=", median(times), " elems=", NE)
        w.unsafe_free(); out.unsafe_free()
    # GEMV: single row, K=4096, N=4096
    comptime K = 4096
    comptime N = 4096
    for kind in [12, 13, 14]:
        var bb = 144 if kind == 12 else 176 if kind == 13 else 210
        var bpr = K // 256
        var w = alloc[UInt8](N * bpr * bb)
        var s = Int64(0xB040) + Int64(kind)
        for b in range(N * bpr):
            s = lcg(s + Int64(b))
            fill_block(w, b * bb, kind, s)
        var a = alloc[Scalar[f16]](K)
        var sa = Int64(12345)
        for i in range(K):
            sa = lcg(sa)
            a.unsafe_store(i, (Float32(Int((sa >> 40) & 0xFF)) / Float32(255.0) - Float32(0.5)).cast[f16]())
        var c = alloc[Scalar[f16]](N)
        var A = RuneTensor[f16](1, K, a)
        var B = RuneTensor[f16](N, K, w.unsafe_bitcast[Scalar[f16]]())
        var C = RuneTensor[f16](1, N, c)
        if kind == 12: gemm_q4_k_m(A, B, C)
        elif kind == 13: gemm_q5_k_m(A, B, C)
        else: gemm_q6_k(A, B, C)
        # parity vs scalar packed_value GEMV (f32 ascending-K sum)
        var maxdiff = Float32(0.0)
        var maxabs = Float32(0.0)
        for n in range(N):
            var tot = Float32(0.0)
            for k in range(K):
                tot += a.unsafe_load(k).cast[f32]() * packed_value(w, 0, kind, n * K + k)
            var d = c.unsafe_load(n).cast[f32]() - tot
            if d < 0: d = -d
            if d > maxdiff: maxdiff = d
            var at = tot if tot >= 0 else -tot
            if at > maxabs: maxabs = at
        print("GEMV_PARITY kind=", kind, " maxabsdiff_vs_scalar=", maxdiff, " maxabs_out=", maxabs)
        var times = List[Int]()
        for _ in range(15):
            var t0 = perf_counter_ns()
            if kind == 12: gemm_q4_k_m(A, B, C)
            elif kind == 13: gemm_q5_k_m(A, B, C)
            else: gemm_q6_k(A, B, C)
            times.append(Int(perf_counter_ns() - t0))
        print("GEMV_TIME kind=", kind, " median_ns=", median(times), " K=", K, " N=", N)
        w.unsafe_free(); a.unsafe_free(); c.unsafe_free()
    print("A040_BENCH done")
