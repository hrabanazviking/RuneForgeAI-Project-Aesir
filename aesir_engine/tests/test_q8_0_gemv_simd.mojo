"""A-038: wide-SIMD Q8_0 dequant GEMV (single-row) regressions.

The GEMV range (_gemm_q8_0_gemv_range, routed from gemm_q8_0 when
A.rows == 1) is compared against the bit-exact serial body
(_gemm_q8_0_range). The parity case uses dyadic data (activations
on a 1/4 grid, scales in {0, +/-0.5, +/-0.25, +/-0.0625}, int8
weights): every product and every partial sum is then exact in
F32, so the two summation orders must agree bit-for-bit -- the
assertion is bitwise equality of the F16 outputs, no tolerance.
Non-dyadic parity is filed with its measured tolerance in
hidden_files/A038_LEDGER.md (bench_q8_0_gemv_a038).
"""

from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16
from core.compute import gemm_q8_0, _gemm_q8_0_range


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


def _fill_dyadic(
    mut lcg: _Lcg,
    a_ptr: Pointer[Scalar[f16], MutUntrackedOrigin],
    w_ptr: Pointer[UInt8, MutUntrackedOrigin],
    k_dim: Int,
    n_out: Int,
):
    # Activations on a 1/4 grid in [-2, 2].
    for i in range(k_dim):
        var q = Int(lcg.next() % 17) - 8
        a_ptr.unsafe_store(i, Float16(Float32(q) * Float32(0.25)))
    var blocks = n_out * (k_dim // 32)
    for blk in range(blocks):
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


def test_q8_0_gemv_simd_known_value() raises:
    """One block, scale 0.25, q = i-16, a = 1 -> exactly -4, through
    the public gemm_q8_0 (which routes A.rows == 1 to the GEMV
    range). Mirrors quantization.fused_q8_0_parity but on the
    gemm_q8_0 entry instead of the gemm_f16 fused dispatch."""
    var well = MimirWell(4096)
    var raw = well.allocate(34).unsafe_bitcast[UInt8]()
    for i in range(34):
        raw.unsafe_store(i, UInt8(0))
    raw.unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.25))
    for i in range(32):
        raw.unsafe_offset(2).unsafe_bitcast[Int8]().unsafe_store(i, Int8(i - 16))
    var input = well.allocate(32)
    for i in range(32):
        input.unsafe_store(i, Float16(1))
    var A = RuneTensor[f16](1, 32, input, False)
    var B = RuneTensor[f16](1, 32, raw.unsafe_bitcast[Float16](), True, CompressedFormatType(CompressedFormatType.Q8_0))
    var C = RuneTensor[f16](1, 1, well.allocate(1), False)
    gemm_q8_0(A, B, C)
    if C.data.unsafe_load() != Float16(-4):
        raise Error("A038: Q8_0 GEMV known-value mismatch")
    _ = well
    print("Q8_0 GEMV SIMD known value: PASS")


def test_q8_0_gemv_simd_parity() raises:
    """Bitwise parity, GEMV range (via gemm_q8_0) vs serial body,
    dyadic fixture K=1024, N=96 (see file header for exactness)."""
    var k_dim = 1024
    var n_out = 96
    var weight_bytes = n_out * (k_dim // 32) * 34
    var well = MimirWell(1024 * 1024)
    var a_ptr = well.allocate(k_dim)
    var w_ptr = well.allocate(weight_bytes // 2 + 2).unsafe_bitcast[UInt8]()
    var c_gemv = well.allocate(n_out)
    var c_scalar = well.allocate(n_out)
    var lcg = _Lcg(0xA038)
    _fill_dyadic(lcg, a_ptr, w_ptr, k_dim, n_out)
    var A = RuneTensor[f16](1, k_dim, a_ptr, False)
    var B = RuneTensor[f16](n_out, k_dim, w_ptr.unsafe_bitcast[Float16](), True, CompressedFormatType(CompressedFormatType.Q8_0))
    var C = RuneTensor[f16](1, n_out, c_gemv, False)
    gemm_q8_0(A, B, C)
    _gemm_q8_0_range(
        Int64(Int(a_ptr)),
        Int64(Int(w_ptr)),
        Int64(Int(c_scalar)),
        1,
        k_dim,
        n_out,
        0,
        n_out,
    )
    var gv_bits = c_gemv.unsafe_bitcast[UInt16]()
    var sc_bits = c_scalar.unsafe_bitcast[UInt16]()
    for i in range(n_out):
        if gv_bits.unsafe_load(i) != sc_bits.unsafe_load(i):
            raise Error(
                "A038: GEMV vs scalar bit mismatch at output "
                + String(i)
            )
    _ = well
    print("Q8_0 GEMV SIMD parity (bitwise, dyadic): PASS")


def test_q8_0_gemv_multirow_regression() raises:
    """A.rows == 3 must stay on the fast range and still match the
    serial body bitwise on dyadic data (dispatch regression guard
    for the A-038 routing change)."""
    var rows = 3
    var k_dim = 64
    var n_out = 8
    var weight_bytes = n_out * (k_dim // 32) * 34
    var well = MimirWell(65536)
    var a_ptr = well.allocate(rows * k_dim)
    var w_ptr = well.allocate(weight_bytes // 2 + 2).unsafe_bitcast[UInt8]()
    var c_fast = well.allocate(rows * n_out)
    var c_scalar = well.allocate(rows * n_out)
    var lcg = _Lcg(0xA038)
    # Fill row 0 with the shared helper, then rows 1-2 the same way.
    _fill_dyadic(lcg, a_ptr, w_ptr, k_dim, n_out)
    for r in range(1, rows):
        for i in range(k_dim):
            var q = Int(lcg.next() % 17) - 8
            a_ptr.unsafe_store(
                r * k_dim + i, Float16(Float32(q) * Float32(0.25))
            )
    var A = RuneTensor[f16](rows, k_dim, a_ptr, False)
    var B = RuneTensor[f16](n_out, k_dim, w_ptr.unsafe_bitcast[Float16](), True, CompressedFormatType(CompressedFormatType.Q8_0))
    var C = RuneTensor[f16](rows, n_out, c_fast, False)
    gemm_q8_0(A, B, C)
    _gemm_q8_0_range(
        Int64(Int(a_ptr)),
        Int64(Int(w_ptr)),
        Int64(Int(c_scalar)),
        rows,
        k_dim,
        n_out,
        0,
        n_out,
    )
    var f_bits = c_fast.unsafe_bitcast[UInt16]()
    var s_bits = c_scalar.unsafe_bitcast[UInt16]()
    for i in range(rows * n_out):
        if f_bits.unsafe_load(i) != s_bits.unsafe_load(i):
            raise Error(
                "A038: multirow fast-range bit mismatch at element "
                + String(i)
            )
    _ = well
    print("Q8_0 GEMV multirow regression (bitwise, dyadic): PASS")
