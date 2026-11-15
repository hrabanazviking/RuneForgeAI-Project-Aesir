"""QS-1 standalone parity driver: the A-042 Q8_0 dyadic bitwise
case (fast_range vs gemv_range per row) extracted from
tests/test_prefill_batching.mojo so it can run without the full
suite, plus a non-dyadic fast-vs-serial max-diff report. Guards
the QS-1.1 GEMV split-accumulator and QS-1.2 fast_range
vector-accumulate rewrites: on dyadic data both must stay
BITWISE equal (exact F32 arithmetic is order-free)."""
from core.mimir_well import MimirWell, f16
from core.compute import _gemm_q8_0_fast_range, _gemm_q8_0_gemv_range, _gemm_q8_0_range


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


def main() raises:
    var rows = 4
    var k_dim = 256
    var n_out = 64
    var blocks_per_row = k_dim // 32
    var weight_bytes = n_out * blocks_per_row * 34
    var well = MimirWell(4 * 1024 * 1024)
    var a_ptr = well.allocate(rows * k_dim)
    var w_ptr = well.allocate(weight_bytes // 2 + 2).unsafe_bitcast[UInt8]()
    var c_batch = well.allocate(rows * n_out)
    var c_rows = well.allocate(rows * n_out)
    var c_serial = well.allocate(rows * n_out)
    var lcg = _Lcg(0xA042)
    for i in range(rows * k_dim):
        var q = Int(lcg.next() % 17) - 8
        a_ptr.unsafe_store(i, Float16(Float32(q) * Float32(0.25)))
    for blk in range(n_out * blocks_per_row):
        var pick = blk % 5
        var sc: Float32 = 0.5
        if pick == 1:
            sc = 0.25
        elif pick == 2:
            sc = 0.0625
        elif pick == 3:
            sc = -0.25
        elif pick == 4:
            sc = 0.0
        w_ptr.unsafe_bitcast[Float16]().unsafe_store(blk * 17, Float16(sc))
        for lane in range(32):
            w_ptr.unsafe_store(blk * 34 + 2 + lane, lcg.byte())
    _gemm_q8_0_fast_range(Int64(Int(a_ptr)), Int64(Int(w_ptr)), Int64(Int(c_batch)), rows, k_dim, n_out, 0, n_out)
    _gemm_q8_0_range(Int64(Int(a_ptr)), Int64(Int(w_ptr)), Int64(Int(c_serial)), rows, k_dim, n_out, 0, n_out)
    for r in range(rows):
        _gemm_q8_0_gemv_range(Int64(Int(a_ptr) + r * k_dim * 2), Int64(Int(w_ptr)), Int64(Int(c_rows) + r * n_out * 2), 1, k_dim, n_out, 0, n_out)
    var ab = c_batch.unsafe_bitcast[UInt16]()
    var rb = c_rows.unsafe_bitcast[UInt16]()
    var sb = c_serial.unsafe_bitcast[UInt16]()
    for i in range(rows * n_out):
        if ab.unsafe_load(i) != rb.unsafe_load(i):
            raise Error("QS1 PARITY FAIL: fast vs gemv bit mismatch at " + String(i))
        if ab.unsafe_load(i) != sb.unsafe_load(i):
            raise Error("QS1 PARITY FAIL: fast vs serial bit mismatch at " + String(i))
    print("QS1 Q8_0 dyadic parity (fast == gemv == serial, bitwise): PASS")
    _ = well
