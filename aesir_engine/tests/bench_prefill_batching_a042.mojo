"""A-042 bench: CPU prefill batching audit, kernel level. (Rerun after the A-042 fast-range fix; the pre-fix rows are filed in the ledger.)

Batched GEMM (one call, A.rows == chunk length) vs row-by-row
(A.rows == 1 calls) on Zen 5, for the three GEMM body classes
that prefill actually exercises:

- dense F16: _gemm_f16_dense_range batched vs per-row calls
  (the A-037 census top row's body; census fixture format).
- Q8_0: decode-once _gemm_q8_0_fast_range batched vs the A-038
  fused _gemm_q8_0_gemv_range called per row.
- Q4_0 (legacy scalar exemplar): public gemm_q4_0 batched vs
  per-row calls -- the legacy body is one serial loop over
  rows, so this leg measures the cost of having NO distinct
  batched body (call overhead only).
- public threaded dispatch (gemm_f16 / gemm_q8_0 via par_for)
  at two shapes, the production call shape of the audit claim.

Fixtures are generated in-file by a fixed-seed LCG (seed
0xA042), byte-reproducible from this source alone (A-038
discipline). Range-level timings are single-thread direct
range calls, median of reps after one warmup, CLOCK_MONOTONIC
nanoseconds around the compute calls only. Parity per shape:
bitwise-equal count + max abs diff, batched vs row-by-row on
identical inputs -- kernel-level slice, no prompt surface, so
raw-oracle discipline reduces to exact input identity, which
the fixtures guarantee by construction.
"""

from std.ffi import external_call
from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16
from core.compute import (
    gemm_f16,
    gemm_q8_0,
    gemm_q4_0,
    _gemm_f16_dense_range,
    _gemm_q8_0_fast_range,
    _gemm_q8_0_gemv_range,
)


def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("A042 clock")
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
        return Float32(self.next() & 0xFFFFFF) / Float32(16777216.0)


def median(mut xs: List[Int]) -> Int:
    for i in range(1, len(xs)):
        var v = xs[i]
        var j = i - 1
        while j >= 0 and xs[j] > v:
            xs[j + 1] = xs[j]
            j -= 1
        xs[j + 1] = v
    return xs[len(xs) // 2]


def parity(
    label: String,
    c_batch: Pointer[Scalar[f16], MutUntrackedOrigin],
    c_rows: Pointer[Scalar[f16], MutUntrackedOrigin],
    n: Int,
):
    var bits_b = c_batch.unsafe_bitcast[UInt16]()
    var bits_r = c_rows.unsafe_bitcast[UInt16]()
    var equal = 0
    var max_abs: Float32 = 0.0
    for i in range(n):
        if bits_b.unsafe_load(i) == bits_r.unsafe_load(i):
            equal += 1
        var d = c_batch.unsafe_load(i).cast[DType.float32]() - c_rows.unsafe_load(i).cast[DType.float32]()
        if d < 0:
            d = -d
        if d > max_abs:
            max_abs = d
    print(
        "A042_PARITY path=" + label + " elements=" + String(n)
        + " bitwise=" + String(equal) + " max_abs_diff=" + String(max_abs)
    )


def run_dense(k_dim: Int, n_out: Int, rows: Int, reps: Int) raises:
    var well = MimirWell(32 * 1024 * 1024)
    var a_ptr = well.allocate(rows * k_dim)
    var b_ptr = well.allocate(n_out * k_dim)
    var c_batch = well.allocate(rows * n_out)
    var c_rows = well.allocate(rows * n_out)
    var lcg = Lcg(0xA042)
    for i in range(rows * k_dim):
        a_ptr.unsafe_store(i, Float16(lcg.unit() * 3.0 - 1.5))
    for i in range(n_out * k_dim):
        b_ptr.unsafe_store(i, Float16(lcg.unit() * 3.0 - 1.5))
    # warmup + parity (untimed)
    _gemm_f16_dense_range(
        Int64(Int(a_ptr)), Int64(Int(b_ptr)), Int64(Int(c_batch)),
        rows, k_dim, n_out, 0, n_out,
    )
    for r in range(rows):
        _gemm_f16_dense_range(
            Int64(Int(a_ptr) + r * k_dim * 2), Int64(Int(b_ptr)),
            Int64(Int(c_rows) + r * n_out * 2), 1, k_dim, n_out, 0, n_out,
        )
    parity("dense_range", c_batch, c_rows, rows * n_out)
    var t_batch = List[Int]()
    for _ in range(reps):
        var t0 = monotonic_ns()
        _gemm_f16_dense_range(
            Int64(Int(a_ptr)), Int64(Int(b_ptr)), Int64(Int(c_batch)),
            rows, k_dim, n_out, 0, n_out,
        )
        t_batch.append(monotonic_ns() - t0)
    var t_rows = List[Int]()
    for _ in range(reps):
        var t0 = monotonic_ns()
        for r in range(rows):
            _gemm_f16_dense_range(
                Int64(Int(a_ptr) + r * k_dim * 2), Int64(Int(b_ptr)),
                Int64(Int(c_rows) + r * n_out * 2), 1, k_dim, n_out, 0, n_out,
            )
        t_rows.append(monotonic_ns() - t0)
    var mb = median(t_batch)
    var mr = median(t_rows)
    print(
        "A042_RESULT path=dense_range K=" + String(k_dim) + " N=" + String(n_out)
        + " rows=" + String(rows) + " batched_ns=" + String(mb)
        + " rowbyrow_ns=" + String(mr)
        + " speedup=" + String(Float64(mr) / Float64(mb))
    )
    _ = well


def run_q8(k_dim: Int, n_out: Int, rows: Int, reps: Int) raises:
    var blocks_per_row = k_dim // 32
    var weight_bytes = n_out * blocks_per_row * 34
    var well = MimirWell(32 * 1024 * 1024)
    var a_ptr = well.allocate(rows * k_dim)
    var w_ptr = well.allocate(weight_bytes // 2 + 2).unsafe_bitcast[UInt8]()
    var c_batch = well.allocate(rows * n_out)
    var c_rows = well.allocate(rows * n_out)
    var lcg = Lcg(0xA042)
    for i in range(rows * k_dim):
        a_ptr.unsafe_store(i, Float16(lcg.unit() * 3.0 - 1.5))
    for blk in range(n_out * blocks_per_row):
        var p = blk * 34
        var s = Float32(0.002) + lcg.unit() * Float32(0.018)
        if blk % 97 == 31:
            s = Float32(0.0)
        elif blk % 89 == 17:
            s = -s
        w_ptr.unsafe_bitcast[Float16]().unsafe_store(blk * 17, Float16(s))
        for lane in range(32):
            w_ptr.unsafe_store(p + 2 + lane, lcg.byte())
    _gemm_q8_0_fast_range(
        Int64(Int(a_ptr)), Int64(Int(w_ptr)), Int64(Int(c_batch)),
        rows, k_dim, n_out, 0, n_out,
    )
    for r in range(rows):
        _gemm_q8_0_gemv_range(
            Int64(Int(a_ptr) + r * k_dim * 2), Int64(Int(w_ptr)),
            Int64(Int(c_rows) + r * n_out * 2), 1, k_dim, n_out, 0, n_out,
        )
    parity("q8_0_range", c_batch, c_rows, rows * n_out)
    var t_batch = List[Int]()
    for _ in range(reps):
        var t0 = monotonic_ns()
        _gemm_q8_0_fast_range(
            Int64(Int(a_ptr)), Int64(Int(w_ptr)), Int64(Int(c_batch)),
            rows, k_dim, n_out, 0, n_out,
        )
        t_batch.append(monotonic_ns() - t0)
    var t_rows = List[Int]()
    for _ in range(reps):
        var t0 = monotonic_ns()
        for r in range(rows):
            _gemm_q8_0_gemv_range(
                Int64(Int(a_ptr) + r * k_dim * 2), Int64(Int(w_ptr)),
                Int64(Int(c_rows) + r * n_out * 2), 1, k_dim, n_out, 0, n_out,
            )
        t_rows.append(monotonic_ns() - t0)
    var mb = median(t_batch)
    var mr = median(t_rows)
    print(
        "A042_RESULT path=q8_0_range K=" + String(k_dim) + " N=" + String(n_out)
        + " rows=" + String(rows) + " batched_ns=" + String(mb)
        + " rowbyrow_ns=" + String(mr)
        + " speedup=" + String(Float64(mr) / Float64(mb))
    )
    _ = well


def run_q4(k_dim: Int, n_out: Int, rows: Int, reps: Int) raises:
    var blocks_per_row = k_dim // 32
    var weight_bytes = n_out * blocks_per_row * 18
    var well = MimirWell(32 * 1024 * 1024)
    var a_ptr = well.allocate(rows * k_dim)
    var w_ptr = well.allocate(weight_bytes // 2 + 2).unsafe_bitcast[UInt8]()
    var c_batch = well.allocate(rows * n_out)
    var c_rows = well.allocate(rows * n_out)
    var lcg = Lcg(0xA042)
    for i in range(rows * k_dim):
        a_ptr.unsafe_store(i, Float16(lcg.unit() * 3.0 - 1.5))
    for blk in range(n_out * blocks_per_row):
        var s = Float32(0.002) + lcg.unit() * Float32(0.018)
        w_ptr.unsafe_bitcast[Float16]().unsafe_store(blk * 9, Float16(s))
        for i in range(16):
            w_ptr.unsafe_store(blk * 18 + 2 + i, lcg.byte())
    var A = RuneTensor[f16](rows, k_dim, a_ptr, False)
    var B = RuneTensor[f16](
        n_out, k_dim, w_ptr.unsafe_bitcast[Float16](), True,
        CompressedFormatType(CompressedFormatType.Q4_0),
    )
    var C = RuneTensor[f16](rows, n_out, c_batch, False)
    gemm_q4_0(A, B, C)
    for r in range(rows):
        var a_row = RuneTensor[f16](
            1, k_dim, a_ptr.unsafe_offset(r * k_dim), False
        )
        var c_row = RuneTensor[f16](
            1, n_out, c_rows.unsafe_offset(r * n_out), False
        )
        gemm_q4_0(a_row, B, c_row)
    parity("q4_0_public", c_batch, c_rows, rows * n_out)
    var t_batch = List[Int]()
    for _ in range(reps):
        var t0 = monotonic_ns()
        gemm_q4_0(A, B, C)
        t_batch.append(monotonic_ns() - t0)
    var t_rows = List[Int]()
    for _ in range(reps):
        var t0 = monotonic_ns()
        for r in range(rows):
            var a_row = RuneTensor[f16](
                1, k_dim, a_ptr.unsafe_offset(r * k_dim), False
            )
            var c_row = RuneTensor[f16](
                1, n_out, c_rows.unsafe_offset(r * n_out), False
            )
            gemm_q4_0(a_row, B, c_row)
        t_rows.append(monotonic_ns() - t0)
    var mb = median(t_batch)
    var mr = median(t_rows)
    print(
        "A042_RESULT path=q4_0_public K=" + String(k_dim) + " N=" + String(n_out)
        + " rows=" + String(rows) + " batched_ns=" + String(mb)
        + " rowbyrow_ns=" + String(mr)
        + " speedup=" + String(Float64(mr) / Float64(mb))
    )
    _ = well


def run_public(k_dim: Int, n_out: Int, rows: Int, reps: Int) raises:
    # Dense F16 through the threaded public dispatch.
    var well = MimirWell(32 * 1024 * 1024)
    var a_ptr = well.allocate(rows * k_dim)
    var b_ptr = well.allocate(n_out * k_dim)
    var c_batch = well.allocate(rows * n_out)
    var c_rows = well.allocate(rows * n_out)
    var lcg = Lcg(0xA042)
    for i in range(rows * k_dim):
        a_ptr.unsafe_store(i, Float16(lcg.unit() * 3.0 - 1.5))
    for i in range(n_out * k_dim):
        b_ptr.unsafe_store(i, Float16(lcg.unit() * 3.0 - 1.5))
    var A = RuneTensor[f16](rows, k_dim, a_ptr, False)
    var B = RuneTensor[f16](n_out, k_dim, b_ptr, False)
    var C = RuneTensor[f16](rows, n_out, c_batch, False)
    gemm_f16(A, B, C)
    for r in range(rows):
        var a_row = RuneTensor[f16](
            1, k_dim, a_ptr.unsafe_offset(r * k_dim), False
        )
        var c_row = RuneTensor[f16](
            1, n_out, c_rows.unsafe_offset(r * n_out), False
        )
        gemm_f16(a_row, B, c_row)
    parity("dense_public", c_batch, c_rows, rows * n_out)
    var t_batch = List[Int]()
    for _ in range(reps):
        var t0 = monotonic_ns()
        gemm_f16(A, B, C)
        t_batch.append(monotonic_ns() - t0)
    var t_rows = List[Int]()
    for _ in range(reps):
        var t0 = monotonic_ns()
        for r in range(rows):
            var a_row = RuneTensor[f16](
                1, k_dim, a_ptr.unsafe_offset(r * k_dim), False
            )
            var c_row = RuneTensor[f16](
                1, n_out, c_rows.unsafe_offset(r * n_out), False
            )
            gemm_f16(a_row, B, c_row)
        t_rows.append(monotonic_ns() - t0)
    var mb = median(t_batch)
    var mr = median(t_rows)
    print(
        "A042_RESULT path=dense_public K=" + String(k_dim) + " N=" + String(n_out)
        + " rows=" + String(rows) + " batched_ns=" + String(mb)
        + " rowbyrow_ns=" + String(mr)
        + " speedup=" + String(Float64(mr) / Float64(mb))
    )
    _ = well


def run_public_q8(k_dim: Int, n_out: Int, rows: Int, reps: Int) raises:
    # Q8_0 through the threaded public dispatch (gemm_q8_0 routes
    # rows == 1 to the A-038 GEMV range, rows > 1 to the decode-once
    # fast range) -- the production call shape for Q8_0 prefill.
    var blocks_per_row = k_dim // 32
    var weight_bytes = n_out * blocks_per_row * 34
    var well = MimirWell(32 * 1024 * 1024)
    var a_ptr = well.allocate(rows * k_dim)
    var w_ptr = well.allocate(weight_bytes // 2 + 2).unsafe_bitcast[UInt8]()
    var c_batch = well.allocate(rows * n_out)
    var c_rows = well.allocate(rows * n_out)
    var lcg = Lcg(0xA042)
    for i in range(rows * k_dim):
        a_ptr.unsafe_store(i, Float16(lcg.unit() * 3.0 - 1.5))
    for blk in range(n_out * blocks_per_row):
        var pp = blk * 34
        var sc = Float32(0.002) + lcg.unit() * Float32(0.018)
        if blk % 97 == 31:
            sc = Float32(0.0)
        elif blk % 89 == 17:
            sc = -sc
        w_ptr.unsafe_bitcast[Float16]().unsafe_store(blk * 17, Float16(sc))
        for lane in range(32):
            w_ptr.unsafe_store(pp + 2 + lane, lcg.byte())
    var A = RuneTensor[f16](rows, k_dim, a_ptr, False)
    var B = RuneTensor[f16](
        n_out, k_dim, w_ptr.unsafe_bitcast[Float16](), True,
        CompressedFormatType(CompressedFormatType.Q8_0),
    )
    var C = RuneTensor[f16](rows, n_out, c_batch, False)
    gemm_q8_0(A, B, C)
    for r in range(rows):
        var a_row = RuneTensor[f16](
            1, k_dim, a_ptr.unsafe_offset(r * k_dim), False
        )
        var c_row = RuneTensor[f16](
            1, n_out, c_rows.unsafe_offset(r * n_out), False
        )
        gemm_q8_0(a_row, B, c_row)
    parity("q8_0_public", c_batch, c_rows, rows * n_out)
    var t_batch = List[Int]()
    for _ in range(reps):
        var t0 = monotonic_ns()
        gemm_q8_0(A, B, C)
        t_batch.append(monotonic_ns() - t0)
    var t_rows = List[Int]()
    for _ in range(reps):
        var t0 = monotonic_ns()
        for r in range(rows):
            var a_row = RuneTensor[f16](
                1, k_dim, a_ptr.unsafe_offset(r * k_dim), False
            )
            var c_row = RuneTensor[f16](
                1, n_out, c_rows.unsafe_offset(r * n_out), False
            )
            gemm_q8_0(a_row, B, c_row)
        t_rows.append(monotonic_ns() - t0)
    var mb = median(t_batch)
    var mr = median(t_rows)
    print(
        "A042_RESULT path=q8_0_public K=" + String(k_dim) + " N=" + String(n_out)
        + " rows=" + String(rows) + " batched_ns=" + String(mb)
        + " rowbyrow_ns=" + String(mr)
        + " speedup=" + String(Float64(mr) / Float64(mb))
    )
    _ = well

def main() raises:
    print("A042 kernel bench: batched GEMM vs row-by-row (Zen 5)")
    # stories260K scale (A-037/A-038 fixture geometry).
    run_dense(288, 512, 8, 15)
    run_dense(288, 512, 32, 15)
    run_dense(288, 512, 128, 15)
    run_q8(288, 512, 8, 15)
    run_q8(288, 512, 32, 15)
    run_q8(288, 512, 128, 15)
    run_q4(288, 512, 32, 15)
    run_q4(288, 512, 128, 15)
    # Mid-size square.
    run_dense(1024, 1024, 8, 5)
    run_dense(1024, 1024, 32, 5)
    run_dense(1024, 1024, 128, 5)
    run_q8(1024, 1024, 8, 5)
    run_q8(1024, 1024, 32, 5)
    run_q8(1024, 1024, 128, 5)
    run_q4(1024, 1024, 32, 5)
    # Larger square, chunk-scale rows only.
    run_dense(2048, 2048, 32, 3)
    run_dense(2048, 2048, 128, 3)
    run_q8(2048, 2048, 32, 3)
    run_q8(2048, 2048, 128, 3)
    # Production dispatch shape (threaded par_for).
    run_public(288, 512, 128, 9)
    run_public(1024, 1024, 32, 5)
    run_public_q8(288, 512, 128, 9)
    run_public_q8(1024, 1024, 32, 5)
    print("A042 kernel bench: DONE")
