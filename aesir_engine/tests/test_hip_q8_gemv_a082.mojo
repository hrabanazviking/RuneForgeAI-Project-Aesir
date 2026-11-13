"""HIP Q8_0 GEMV (A-082): dequant + single-row GEMV executed on
the Radeon 8060S (gfx1151) by a Mojo-native HIP kernel through
the A-010-A-012 gate, judged against the Z13 CPU oracle (the
A-054 gate declared the CPU path the campaign's reference
oracle). The HIP counterpart of the A-056 Vulkan slice.

Parity discipline (same as A-056):
- Non-dyadic shapes: HIP Float32 outputs vs a sequential Float32
  CPU oracle in this file that consumes the identical raw Q8_0
  bytes with the identical math the engine's CPU body uses
  (per-block fp16 scale x int8 x activation, summed in k order).
  The HIP kernel also accumulates in k order, one thread per
  row, so the filed tolerance is a small accumulation bound,
  not a dequant bound: max_abs is printed for the ledger and
  asserted below the filed A-082 bound.
- Dyadic shapes: the same fixture is also run through the
  engine's own CPU GEMV (gemm_q8_0, the A-038 route). On dyadic
  data every Float32 partial sum is exact, so the HIP outputs
  are the exact sums; the engine writes F16, so HIP outputs
  must lie within half an F16 ULP of the engine outputs - the
  F16 rounding distance, a comparator artifact bound.
- Known value: one block, scale 0.25, q = i-16, x = 1 gives
  exactly -4 (mirrors the A-038 / A-056 known-value case).

Device-execution evidence (law 6): the A-010 gate must name
exactly one gfx1151 device (any other identity is refused by
the gateway), the device name must be non-empty, and the hip
shim dispatch counter must advance by exactly the number of
completed dispatches. On a host without that device the cases
assert fail-closed behaviour and pass as honest-absent,
matching A-011/A-029 discipline.
"""
from std.memory import bitcast
from core.hip_gemv import HipGemv
from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16
from core.compute import gemm_q8_0


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


def _set_scale(mut w: List[UInt8], blk: Int, s: Float32):
    var bits = bitcast[DType.uint16](Float16(s))
    w[blk * 34] = UInt8(bits & 0xFF)
    w[blk * 34 + 1] = UInt8((bits >> 8) & 0xFF)


def _get_scale(w: List[UInt8], blk: Int) -> Float32:
    var bits = UInt16(w[blk * 34]) | (UInt16(w[blk * 34 + 1]) << 8)
    return bitcast[DType.float16](bits).cast[DType.float32]()


def _shape_parity(rows: Int, cols: Int) raises -> Float32:
    """One non-dyadic shape vs the sequential CPU oracle;
    returns the max abs delta observed (also printed)."""
    var blocks_per_row = cols // 32
    var w = List[UInt8](capacity=rows * blocks_per_row * 34)
    for _ in range(rows * blocks_per_row * 34):
        w.append(UInt8(0))
    var lcg = _Lcg(0xA082)
    var xs = List[Float32](capacity=cols)
    for _ in range(cols):
        xs.append(lcg.unit() * Float32(3.0) - Float32(1.5))
    for blk in range(rows * blocks_per_row):
        var s = Float32(0.002) + lcg.unit() * Float32(0.018)
        if blk % 97 == 31:
            s = Float32(0.0)
        elif blk % 89 == 17:
            s = -s
        _set_scale(w, blk, s)
        for lane in range(32):
            w[blk * 34 + 2 + lane] = lcg.byte()
    var got = HipGemv.q8_0_gemv(w, xs, rows, cols)
    var max_abs: Float32 = 0.0
    for r in range(rows):
        var acc: Float32 = 0.0
        for blk in range(blocks_per_row):
            var gblk = r * blocks_per_row + blk
            var scale = _get_scale(w, gblk)
            for lane in range(32):
                var raw = Int(w[gblk * 34 + 2 + lane])
                var q = raw - 256 if raw >= 128 else raw
                acc += scale * Float32(q) * xs[blk * 32 + lane]
        var d = got[r] - acc
        if d < 0:
            d = -d
        if d > max_abs:
            max_abs = d
    print(
        "A082_SHAPE rows=", rows, " cols=", cols,
        " cpu_oracle_max_abs=", max_abs,
    )
    return max_abs


def _half_ulp16(v: Float32) -> Float32:
    """Half the F16 ULP at |v| (the F16 rounding distance)."""
    var a = v
    if a < 0:
        a = -a
    if a == 0:
        return Float32(1.0) / Float32(33554432.0)
    var p: Float32 = 1.0
    while a >= p * Float32(2.0):
        p *= Float32(2.0)
    while a < p:
        p /= Float32(2.0)
    var ulp = p / Float32(1024.0)
    var min_ulp = Float32(1.0) / Float32(16777216.0)
    if ulp < min_ulp:
        ulp = min_ulp
    return ulp * Float32(0.5)


def test_hip_q8_gemv_oracle_parity() raises:
    print("--- Testing HIP Q8_0 GEMV oracle parity (A-082) ---")
    if not HipGemv.gate_ok():
        var w = List[UInt8](capacity=34)
        for _ in range(34):
            w.append(UInt8(0))
        var xs = List[Float32](capacity=32)
        for _ in range(32):
            xs.append(Float32(1.0))
        var rejected = False
        try:
            _ = HipGemv.q8_0_gemv(w, xs, 1, 32)
        except:
            rejected = True
        if not rejected:
            raise Error("HIP gate failed but q8_0_gemv succeeded (fabricated)")
        print("HIP UNAVAILABLE: GEMV fail-closed: PASS (honest-absent)")
        return
    var shapes_r = [1, 4, 16, 37, 64, 13]
    var shapes_c = [32, 64, 288, 320, 1024, 4096]
    var worst: Float32 = 0.0
    for s in range(len(shapes_r)):
        var m = _shape_parity(shapes_r[s], shapes_c[s])
        if m > worst:
            worst = m
    if worst > Float32(0.001):
        raise Error(
            "HIP Q8_0 GEMV oracle parity exceeded filed bound: max_abs "
            + String(worst)
        )
    print(
        "HIP Q8_0 GEMV oracle parity (6 shapes incl. K=288"
        " stories scale and K=4096, gfx1151 device, worst max_abs=",
        worst, "): PASS",
    )


def test_hip_q8_gemv_known_value() raises:
    print("--- Testing HIP Q8_0 GEMV known value (A-082) ---")
    if not HipGemv.gate_ok():
        print("HIP UNAVAILABLE: known-value case not run (honest-absent)")
        return
    var w = List[UInt8](capacity=34)
    for _ in range(34):
        w.append(UInt8(0))
    _set_scale(w, 0, Float32(0.25))
    for i in range(32):
        w[2 + i] = UInt8(i - 16)
    var xs = List[Float32](capacity=32)
    for _ in range(32):
        xs.append(Float32(1.0))
    var got = HipGemv.q8_0_gemv(w, xs, 1, 32)
    if got[0] != Float32(-4.0):
        raise Error(
            "HIP Q8_0 GEMV known-value mismatch: got " + String(got[0])
            + " want -4"
        )
    print("HIP Q8_0 GEMV known value (scale 0.25, q=i-16, x=1 -> -4 exact): PASS")


def test_hip_q8_gemv_engine_crosscheck() raises:
    print("--- Testing HIP Q8_0 GEMV vs engine CPU GEMV (A-082) ---")
    if not HipGemv.gate_ok():
        print("HIP UNAVAILABLE: engine cross-check not run (honest-absent)")
        return
    # Dyadic fixture (A-038 discipline, same as A-056): activations
    # on a 1/4 grid, scales in {0, +/-0.5, +/-0.25, +/-0.0625};
    # every product and partial sum is exact in Float32 and in the
    # engine's F16 output, so HIP and engine CPU outputs must
    # agree within half an F16 ULP (the engine rounding distance).
    var k_dim = 1024
    var n_out = 96
    var weight_bytes = n_out * (k_dim // 32) * 34
    var well = MimirWell(1024 * 1024)
    var a_ptr = well.allocate(k_dim)
    var w_ptr = well.allocate(weight_bytes // 2 + 2).unsafe_bitcast[UInt8]()
    var c_cpu = well.allocate(n_out)
    var lcg = _Lcg(0xA038)
    for i in range(k_dim):
        var q = Int(lcg.next() % 17) - 8
        a_ptr.unsafe_store(i, Float16(Float32(q) * Float32(0.25)))
    for blk in range(n_out * (k_dim // 32)):
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
    var A = RuneTensor[f16](1, k_dim, a_ptr, False)
    var B = RuneTensor[f16](n_out, k_dim, w_ptr.unsafe_bitcast[Float16](), True, CompressedFormatType(CompressedFormatType.Q8_0))
    var C = RuneTensor[f16](1, n_out, c_cpu, False)
    gemm_q8_0(A, B, C)
    var w = List[UInt8](capacity=weight_bytes)
    for i in range(weight_bytes):
        w.append(w_ptr.unsafe_load(i))
    var xs = List[Float32](capacity=k_dim)
    for i in range(k_dim):
        xs.append(a_ptr.unsafe_load(i).cast[DType.float32]())
    var got = HipGemv.q8_0_gemv(w, xs, n_out, k_dim)
    for i in range(n_out):
        var want = c_cpu.unsafe_load(i).cast[DType.float32]()
        var d = got[i] - want
        if d < 0:
            d = -d
        var bound = _half_ulp16(want)
        if d > bound:
            raise Error(
                "HIP Q8_0 GEMV engine cross-check mismatch at output "
                + String(i) + ": got " + String(got[i]) + " want "
                + String(want) + " (beyond half F16 ULP)"
            )
    _ = well
    print(
        "HIP Q8_0 GEMV vs engine CPU GEMV (dyadic K=1024 N=96,"
        " within half F16 ULP of engine output at every output): PASS"
    )


def test_hip_q8_gemv_rejection() raises:
    print("--- Testing HIP Q8_0 GEMV rejection (A-082) ---")
    # Shape errors raise before any device work, on every host.
    var w = List[UInt8](capacity=2 * 34)
    for _ in range(2 * 34):
        w.append(UInt8(0))
    var xs = List[Float32](capacity=64)
    for _ in range(64):
        xs.append(Float32(1.0))
    var zero_rows = False
    try:
        _ = HipGemv.q8_0_gemv(w, xs, 0, 64)
    except:
        zero_rows = True
    if not zero_rows:
        raise Error("q8_0_gemv accepted a zero row count")
    var bad_cols = False
    try:
        _ = HipGemv.q8_0_gemv(w, xs, 1, 48)
    except:
        bad_cols = True
    if not bad_cols:
        raise Error("q8_0_gemv accepted cols=48 (not a Q8_0 block multiple)")
    var oversize = False
    try:
        _ = HipGemv.q8_0_gemv(w, xs, 4, 64)
    except:
        oversize = True
    if not oversize:
        raise Error("q8_0_gemv accepted a shape beyond the operand lists")
    var short_x = False
    var xs32 = List[Float32](capacity=32)
    for _ in range(32):
        xs32.append(Float32(1.0))
    try:
        _ = HipGemv.q8_0_gemv(w, xs32, 1, 64)
    except:
        short_x = True
    if not short_x:
        raise Error("q8_0_gemv accepted a short activation list")
    print("HIP Q8_0 GEMV rejection (zero rows, cols=48, oversize, short x): PASS")


def test_hip_q8_gemv_dispatch_evidence() raises:
    print("--- Testing HIP Q8_0 GEMV dispatch evidence (A-082) ---")
    if not HipGemv.gate_ok():
        print("HIP UNAVAILABLE: dispatch evidence not run (honest-absent)")
        return
    var name = HipGemv.device_name()
    if name.byte_length() == 0:
        raise Error("HIP device name empty on a gated device")
    var before = HipGemv.dispatch_count()
    _ = _shape_parity(8, 256)
    _ = _shape_parity(8, 256)
    var after = HipGemv.dispatch_count()
    if after - before != 2:
        raise Error(
            "dispatch counter advanced by " + String(after - before)
            + " for 2 dispatches (device-execution evidence broken)"
        )
    print(
        "HIP Q8_0 GEMV dispatch evidence (device \"", name,
        "\", counter +2 for 2 dispatches): PASS",
    )
