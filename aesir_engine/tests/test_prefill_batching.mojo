"""A-042: CPU prefill batching audit -- parity + policy regressions.

The audit (docs/bench/A042_PREFILL_BATCHING_AUDIT.md) compares the
batched GEMM path (one call, A.rows == chunk length) against the
row-by-row path (A.rows == 1 calls) on Zen 5. These cases pin the
correctness half of that comparison so the performance default
(batched, core/prefill_batching.mojo) can never silently change
numbers:

- dense F16: the batched range and the per-row range calls run the
  identical per-output reduction (SIMD-then-tail over K), so the
  outputs must agree BITWISE on general (non-dyadic) data, at both
  the range level and through the public gemm_f16 dispatch.
- Q8_0: the batched decode-once fast range vs the A-038 fused
  GEMV range, one call per row. On dyadic data every product and
  partial sum is exact in F32, so both summation orders must agree
  BITWISE. Non-dyadic tolerance is filed in the A-042 ledger from
  the bench fixture (same accepted fast-path class as A-038).
- Q4_0 (legacy scalar exemplar): the batched public call is one
  serial loop over rows, so batched vs per-row calls must agree
  BITWISE by construction; the case guards that construction.
- policy: prefill_path_for_rows boundaries + fail-closed raise.
"""

from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16
from core.compute import (
    gemm_f16,
    gemm_q4_0,
    _gemm_f16_dense_range,
    _gemm_q8_0_fast_range,
    _gemm_q8_0_gemv_range,
)
from core.prefill_batching import (
    PREFILL_PATH_BATCHED,
    PREFILL_PATH_ROW_BY_ROW,
    PREFILL_BATCHED_MIN_ROWS,
    prefill_path_for_rows,
    prefill_uses_batched,
    prefill_default_chunk_cap,
)


struct _Lcg:
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


def _bitwise_equal(
    a: Pointer[Scalar[f16], MutUntrackedOrigin],
    b: Pointer[Scalar[f16], MutUntrackedOrigin],
    n: Int,
    label: String,
) raises:
    var ab = a.unsafe_bitcast[UInt16]()
    var bb = b.unsafe_bitcast[UInt16]()
    for i in range(n):
        if ab.unsafe_load(i) != bb.unsafe_load(i):
            raise Error(
                "A042: " + label + " bit mismatch at element " + String(i)
            )


def test_prefill_batching_policy() raises:
    """Policy boundaries: 1 row is the decode shape (row-by-row);
    >= PREFILL_BATCHED_MIN_ROWS is batched; the chunk cap default
    matches the facade's 256; non-positive rows raise."""
    if prefill_path_for_rows(1) != PREFILL_PATH_ROW_BY_ROW:
        raise Error("A042: rows=1 must take the row-by-row path")
    if prefill_uses_batched(1):
        raise Error("A042: rows=1 must not be batched")
    if prefill_path_for_rows(PREFILL_BATCHED_MIN_ROWS) != PREFILL_PATH_BATCHED:
        raise Error("A042: min-rows boundary must take the batched path")
    if not prefill_uses_batched(256):
        raise Error("A042: rows=256 must be batched")
    if prefill_default_chunk_cap() != 256:
        raise Error("A042: default chunk cap must be 256 (facade parity)")
    var raised = False
    try:
        _ = prefill_path_for_rows(0)
    except:
        raised = True
    if not raised:
        raise Error("A042: rows=0 must raise (fail-closed)")
    print("Prefill batching policy: PASS")


def test_prefill_batching_dense_range_parity() raises:
    """Dense F16, range level: one batched _gemm_f16_dense_range
    call (rows=8) vs eight single-row calls, general LCG data,
    K=288, N=96 -- bitwise equal (identical per-output reduction
    order in both shapes)."""
    var rows = 8
    var k_dim = 288
    var n_out = 96
    var well = MimirWell(1024 * 1024)
    var a_ptr = well.allocate(rows * k_dim)
    var b_ptr = well.allocate(n_out * k_dim)
    var c_batch = well.allocate(rows * n_out)
    var c_rows = well.allocate(rows * n_out)
    var lcg = _Lcg(0xA042)
    for i in range(rows * k_dim):
        a_ptr.unsafe_store(i, Float16(lcg.unit() * 3.0 - 1.5))
    for i in range(n_out * k_dim):
        b_ptr.unsafe_store(i, Float16(lcg.unit() * 3.0 - 1.5))
    _gemm_f16_dense_range(
        Int64(Int(a_ptr)), Int64(Int(b_ptr)), Int64(Int(c_batch)),
        rows, k_dim, n_out, 0, n_out,
    )
    for r in range(rows):
        _gemm_f16_dense_range(
            Int64(Int(a_ptr) + r * k_dim * 2),
            Int64(Int(b_ptr)),
            Int64(Int(c_rows) + r * n_out * 2),
            1, k_dim, n_out, 0, n_out,
        )
    _bitwise_equal(c_batch, c_rows, rows * n_out, "dense range batched vs rows")
    _ = well
    print("Prefill batching dense range parity (bitwise): PASS")


def test_prefill_batching_dense_public_parity() raises:
    """Dense F16, public dispatch: gemm_f16 with A.rows == 8 vs
    eight A.rows == 1 gemm_f16 calls -- bitwise equal."""
    var rows = 8
    var k_dim = 288
    var n_out = 96
    var well = MimirWell(1024 * 1024)
    var a_ptr = well.allocate(rows * k_dim)
    var b_ptr = well.allocate(n_out * k_dim)
    var c_batch = well.allocate(rows * n_out)
    var c_rows = well.allocate(rows * n_out)
    var lcg = _Lcg(0xA042)
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
    _bitwise_equal(c_batch, c_rows, rows * n_out, "dense public batched vs rows")
    _ = well
    print("Prefill batching dense public parity (bitwise): PASS")


def test_prefill_batching_q8_range_parity() raises:
    """Q8_0, range level: batched decode-once fast range (rows=4)
    vs the A-038 fused GEMV range called per row, dyadic fixture
    K=256, N=64 -- bitwise equal (exact F32 arithmetic makes the
    two summation orders agree exactly; see file header)."""
    var rows = 4
    var k_dim = 256
    var n_out = 64
    var blocks_per_row = k_dim // 32
    var weight_bytes = n_out * blocks_per_row * 34
    var well = MimirWell(1024 * 1024)
    var a_ptr = well.allocate(rows * k_dim)
    var w_ptr = well.allocate(weight_bytes // 2 + 2).unsafe_bitcast[UInt8]()
    var c_batch = well.allocate(rows * n_out)
    var c_rows = well.allocate(rows * n_out)
    var lcg = _Lcg(0xA042)
    # Activations on a 1/4 grid in [-2, 2], every row distinct.
    for i in range(rows * k_dim):
        var q = Int(lcg.next() % 17) - 8
        a_ptr.unsafe_store(i, Float16(Float32(q) * Float32(0.25)))
    for blk in range(n_out * blocks_per_row):
        var pick = blk % 5
        var s: Float32 = 0.5
        if pick == 1:
            s = 0.25
        elif pick == 2:
            s = 0.0625
        elif pick == 3:
            s = -0.25
        elif pick == 4:
            s = 0.0
        w_ptr.unsafe_bitcast[Float16]().unsafe_store(blk * 17, Float16(s))
        for lane in range(32):
            w_ptr.unsafe_store(blk * 34 + 2 + lane, lcg.byte())
    _gemm_q8_0_fast_range(
        Int64(Int(a_ptr)), Int64(Int(w_ptr)), Int64(Int(c_batch)),
        rows, k_dim, n_out, 0, n_out,
    )
    for r in range(rows):
        _gemm_q8_0_gemv_range(
            Int64(Int(a_ptr) + r * k_dim * 2),
            Int64(Int(w_ptr)),
            Int64(Int(c_rows) + r * n_out * 2),
            1, k_dim, n_out, 0, n_out,
        )
    _bitwise_equal(c_batch, c_rows, rows * n_out, "q8_0 fast vs gemv rows")
    _ = well
    print("Prefill batching Q8_0 range parity (bitwise, dyadic): PASS")


def test_prefill_batching_q4_0_public_parity() raises:
    """Q4_0 legacy scalar path: one batched gemm_q4_0 call
    (rows=4) vs four single-row calls -- bitwise equal (the
    batched body is the same serial loop over rows)."""
    var rows = 4
    var k_dim = 64
    var n_out = 32
    var blocks_per_row = k_dim // 32
    var weight_bytes = n_out * blocks_per_row * 18
    var well = MimirWell(1024 * 1024)
    var a_ptr = well.allocate(rows * k_dim)
    var w_ptr = well.allocate(weight_bytes // 2 + 2).unsafe_bitcast[UInt8]()
    var c_batch = well.allocate(rows * n_out)
    var c_rows = well.allocate(rows * n_out)
    var lcg = _Lcg(0xA042)
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
    _bitwise_equal(c_batch, c_rows, rows * n_out, "q4_0 batched vs rows")
    _ = well
    print("Prefill batching Q4_0 public parity (bitwise): PASS")
