"""A-038 bench: Q8_0 single-row GEMV, scalar body vs width-16 SIMD
dequant range. Kernel-level fixture of filed provenance: all inputs
are generated in-file by a fixed-seed LCG (seed 0xA038), so the
fixture is byte-reproducible from this source alone. Shapes cover
the stories260K scale (K=288) and Coder-class decode GEMVs.
Parity: f16 outputs compared bitwise, with ULP/abs deltas filed.
Timing: single-thread direct range calls, median of reps, after
warmup; the public gemm_q8_0 par_for dispatch threads the same
GEMV range for A.rows == 1.
"""

from std.ffi import external_call
from core.mimir_well import MimirWell
from core.compute import _gemm_q8_0_range, _gemm_q8_0_gemv_range


def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("A038 clock")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


struct Lcg:
    var state: UInt64

    def __init__(out self, seed: UInt64):
        self.state = seed

    def next(mut self) -> UInt64:
        self.state = (
            self.state * 6364136223846793005 + 1442695040888963407
        )
        return self.state >> 11

    def byte(mut self) -> UInt8:
        return UInt8(self.next() & 0xFF)

    def unit(mut self) -> Float32:
        # [0, 1) with 24-bit granularity.
        return Float32(self.next() & 0xFFFFFF) / Float32(16777216.0)


def median(mut xs: List[Int]) -> Int:
    # insertion sort, small n
    for i in range(1, len(xs)):
        var v = xs[i]
        var j = i - 1
        while j >= 0 and xs[j] > v:
            xs[j + 1] = xs[j]
            j -= 1
        xs[j + 1] = v
    return xs[len(xs) // 2]


def run_shape(k_dim: Int, n_out: Int, reps: Int) raises:
    var blocks_per_row = k_dim // 32
    var weight_bytes = n_out * blocks_per_row * 34
    var well = MimirWell((weight_bytes // 2 + k_dim + 2 * n_out + 4096) * 2)
    var a_ptr = well.allocate(k_dim)
    var w_ptr = well.allocate(weight_bytes // 2 + 2).unsafe_bitcast[UInt8]()
    var c_scalar = well.allocate(n_out)
    var c_simd = well.allocate(n_out)

    var lcg = Lcg(0xA038)
    for i in range(k_dim):
        a_ptr.unsafe_store(i, Float16(lcg.unit() * 3.0 - 1.5))
    for blk in range(n_out * blocks_per_row):
        var p = blk * 34
        # Non-dyadic scales in [0.002, 0.02], a few zero/negative.
        var s = Float32(0.002) + lcg.unit() * Float32(0.018)
        if blk % 97 == 31:
            s = Float32(0.0)
        elif blk % 89 == 17:
            s = -s
        w_ptr.unsafe_bitcast[Float16]().unsafe_store(blk * 17, Float16(s))
        for lane in range(32):
            w_ptr.unsafe_store(p + 2 + lane, lcg.byte())

    var a_addr = Int64(Int(a_ptr))
    var b_addr = Int64(Int(w_ptr))
    var cs_addr = Int64(Int(c_scalar))
    var cv_addr = Int64(Int(c_simd))

    # Parity (single-thread, full range).
    _gemm_q8_0_range(a_addr, b_addr, cs_addr, 1, k_dim, n_out, 0, n_out)
    _gemm_q8_0_gemv_range(a_addr, b_addr, cv_addr, 1, k_dim, n_out, 0, n_out)
    var bit_equal = 0
    var max_ulp = 0
    var max_abs: Float32 = 0.0
    var cs_bits = c_scalar.unsafe_bitcast[UInt16]()
    var cv_bits = c_simd.unsafe_bitcast[UInt16]()
    for i in range(n_out):
        var x = c_scalar.unsafe_load(i)
        var y = c_simd.unsafe_load(i)
        var xb = Int(cs_bits.unsafe_load(i))
        var yb = Int(cv_bits.unsafe_load(i))
        if xb == yb:
            bit_equal += 1
        # Ordered ULP distance for f16 bit patterns.
        var xo = (xb & 0x7FFF) + 0x8000 if (xb & 0x8000) == 0 else 0x8000 - (xb & 0x7FFF)
        var yo = (yb & 0x7FFF) + 0x8000 if (yb & 0x8000) == 0 else 0x8000 - (yb & 0x7FFF)
        var ulp = xo - yo
        if ulp < 0:
            ulp = -ulp
        if ulp > max_ulp:
            max_ulp = ulp
        var d = x.cast[DType.float32]() - y.cast[DType.float32]()
        if d < 0:
            d = -d
        if d > max_abs:
            max_abs = d
    print(
        "A038_SHAPE K=", k_dim, " N=", n_out,
        " parity: bit_equal=", bit_equal, "/", n_out,
        " max_ulp=", max_ulp, " max_abs=", max_abs,
    )

    # Timing: warmup then median of reps, scalar first then SIMD.
    for _ in range(3):
        _gemm_q8_0_range(a_addr, b_addr, cs_addr, 1, k_dim, n_out, 0, n_out)
        _gemm_q8_0_gemv_range(a_addr, b_addr, cv_addr, 1, k_dim, n_out, 0, n_out)
    var t_scalar = List[Int]()
    for _ in range(reps):
        var t0 = monotonic_ns()
        _gemm_q8_0_range(a_addr, b_addr, cs_addr, 1, k_dim, n_out, 0, n_out)
        t_scalar.append(monotonic_ns() - t0)
    var t_simd = List[Int]()
    for _ in range(reps):
        var t0 = monotonic_ns()
        _gemm_q8_0_gemv_range(a_addr, b_addr, cv_addr, 1, k_dim, n_out, 0, n_out)
        t_simd.append(monotonic_ns() - t0)
    var med_s = median(t_scalar)
    var med_v = median(t_simd)
    print(
        "A038_SHAPE K=", k_dim, " N=", n_out,
        " scalar_median_ns=", med_s, " simd_median_ns=", med_v,
        " speedup=", Float64(med_s) / Float64(med_v),
        " scalar_ns_per_out=", Float64(med_s) / Float64(n_out),
        " simd_ns_per_out=", Float64(med_v) / Float64(n_out),
    )
    _ = well


def main() raises:
    print("A038_BENCH seed=0xA038 fixture=in-file LCG")
    run_shape(288, 512, 25)
    run_shape(4096, 4096, 15)
    run_shape(4096, 11008, 9)
    print("A038_BENCH: PASS")
