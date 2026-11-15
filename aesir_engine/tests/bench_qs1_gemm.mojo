"""QS-1 micro-bench: Q8_0 GEMM shapes of the Qwen3.8-27B resident
model, production dispatch vs range bodies, plus par_for dispatch
overhead. Synthetic packed weights (LCG), real shapes:
K=5120; N in {17408 (ffn), 10240 (qkv), 6144 (gate/out)}; rows in
{1 (decode), 32, 256 (prefill chunk)}. LM head 248320x5120 timed
at rows=1 only (its packed size is 1.35 GB; allocated once).
Prints one line per cell: QS1BENCH shape rows threads median_ms
checksum. Thread count is the process env AESIR_THREADS (runner
sweeps it per process, production dispatch end to end).
"""
from std.ffi import external_call
from std.memory import Pointer
from std.collections import InlineArray
from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16, f32
from core.compute import gemm_q8_0, _gemm_q8_0_fast_range, _gemm_q8_0_gemv_range
from core.parallel import par_for


def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("clock_gettime failed")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


struct _Lcg:
    var state: UInt64
    def __init__(out self, seed: UInt64):
        self.state = seed
    def next(mut self) -> UInt64:
        self.state = self.state * 6364136223846793005 + 1442695040888963407
        return self.state >> 11
    def byte(mut self) -> UInt8:
        return UInt8(self.next() & 0xFF)
    def unit(mut self) -> Float32:
        return Float32(self.next() & 0xFFFFFF) / Float32(16777216.0)


def _noop_range(ctx_addr: Int64, start: Int64, end: Int64):
    pass


def median(mut xs: List[Int]) -> Int:
    for i in range(len(xs)):
        for j in range(i + 1, len(xs)):
            if xs[j] < xs[i]:
                var t = xs[i]; xs[i] = xs[j]; xs[j] = t
    return xs[len(xs) // 2]


def bench_shape(k_dim: Int, n_out: Int, rows: Int, reps: Int) raises:
    var blocks_per_row = k_dim // 32
    var weight_bytes = n_out * blocks_per_row * 34
    var well = MimirWell(weight_bytes + 2 * (rows * k_dim + rows * n_out) + 2097152)
    var a_ptr = well.allocate(rows * k_dim)
    var w_ptr = well.allocate(weight_bytes // 2 + 2).unsafe_bitcast[UInt8]()
    var c_ptr = well.allocate(rows * n_out)
    var lcg = _Lcg(0x5153)
    for i in range(rows * k_dim):
        a_ptr.unsafe_store(i, Float16(lcg.unit() * 2.0 - 1.0))
    for blk in range(n_out * blocks_per_row):
        var s = Float32(0.004) + lcg.unit() * Float32(0.012)
        w_ptr.unsafe_bitcast[Float16]().unsafe_store(blk * 17, Float16(s))
        for lane in range(32):
            w_ptr.unsafe_store(blk * 34 + 2 + lane, lcg.byte())
    var A = RuneTensor[f16](rows, k_dim, a_ptr, False)
    var B = RuneTensor[f16](n_out, k_dim, w_ptr.unsafe_bitcast[Float16](), True, CompressedFormatType(CompressedFormatType.Q8_0))
    var C = RuneTensor[f16](rows, n_out, c_ptr, False)
    gemm_q8_0(A, B, C)
    var times = List[Int]()
    for _ in range(reps):
        var t0 = monotonic_ns()
        gemm_q8_0(A, B, C)
        times.append(monotonic_ns() - t0)
    var med = median(times)
    var chk: Float32 = 0.0
    for i in range(rows * n_out):
        chk += c_ptr.unsafe_load(i).cast[f32]()
    print("QS1BENCH K=" + String(k_dim) + " N=" + String(n_out) + " rows=" + String(rows) + " median_ms=" + String(Float64(med) / 1e6) + " checksum=" + String(chk))
    _ = well


def bench_spawn() raises:
    var reps = 200
    var times = List[Int]()
    for _ in range(reps):
        var t0 = monotonic_ns()
        _ = par_for[_noop_range](Int64(0), 24, Int64(2000000))
        times.append(monotonic_ns() - t0)
    var med = median(times)
    print("QS1SPAWN n=24 work=2M median_us=" + String(Float64(med) / 1e3))


def main() raises:
    from std.sys import argv
    var args = argv()
    var mode = String("all")
    if len(args) > 1:
        mode = args[1]
    bench_spawn()
    if mode == String("all") or mode == String("decode"):
        bench_shape(5120, 17408, 1, 15)
        bench_shape(5120, 10240, 1, 15)
        bench_shape(5120, 6144, 1, 15)
        bench_shape(6144, 5120, 1, 15)
        bench_shape(17408, 5120, 1, 15)
    if mode == String("all") or mode == String("prefill"):
        bench_shape(5120, 17408, 32, 7)
        bench_shape(5120, 17408, 256, 3)
        bench_shape(5120, 10240, 256, 3)
    print("QS1_BENCH_DONE")
