"""Vulkan Q8_0 GEMV (A-056): dequant + single-row GEMV dispatched
on the GPU through the A-014/A-015 Vulkan context, judged against
the Z13 CPU oracle (the A-054 gate declared the CPU path the
campaign's reference oracle).

Parity discipline:
- Non-dyadic shapes: GPU Float32 outputs vs a sequential Float32
  CPU oracle in this file that consumes the identical raw Q8_0
  bytes with the identical math the engine's CPU body uses
  (per-block fp16 scale x int8 x activation, summed in k order).
  The GPU reduces in tree order, so the filed tolerance is an
  accumulation-order bound, not a dequant bound: max_abs and
  max_rel are printed for the ledger and asserted below the
  filed A-056 bound.
- Dyadic shapes: the same fixture is also run through the
  engine's own CPU GEMV (gemm_q8_0, the A-038 route). On dyadic
  data every Float32 partial sum is exact in any summation
  order, so the GPU Float32 outputs are the exact sums; the
  engine writes F16, so GPU outputs must lie within half an
  F16 ULP of the engine outputs - the F16 rounding distance,
  a comparator artifact bound, not a dequant tolerance.
- Known value: one block, scale 0.25, q = i-16, x = 1 gives
  exactly -4 (mirrors the A-038 known-value case).

Device-execution evidence (law 6): the selected device must be
the AMD Radeon 8060S (RADV STRIX_HALO) - llvmpipe is refused by
the identity check - and the shim dispatch counter must advance
by exactly the number of dispatches performed. On a host
without that device the cases assert fail-closed behaviour and
pass as honest-absent, matching A-014/A-015 discipline.
"""
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_gemv import VulkanGemv
from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16
from core.compute import gemm_q8_0


def _vk_present() -> Bool:
    if not VulkanBuffers.runtime_available():
        return False
    if not VulkanBuffers.dispatch_available():
        return False
    try:
        var info = VulkanBuffers.device_info()
        if info.vendor_id != 0x1002:
            return False
        if info.device_type == 4:
            return False
        return VulkanBuffers.device_name_is_radv()
    except:
        return False


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


def _run_gpu(
    w_alloc: VulkanAllocation,
    x_alloc: VulkanAllocation,
    rows: Int,
    cols: Int,
) raises -> List[Float32]:
    var y_alloc = VulkanBuffers.allocate(rows * 4)
    var py = VulkanBuffers.map(y_alloc)
    var fy = py.unsafe_bitcast[Float32]()
    for i in range(rows):
        fy.unsafe_store(i, Float32(-9999.0))
    VulkanBuffers.unmap(y_alloc)
    VulkanGemv.q8_0_gemv(w_alloc, x_alloc, y_alloc, rows, cols)
    var out = List[Float32]()
    var qy = VulkanBuffers.map(y_alloc)
    var gy = qy.unsafe_bitcast[Float32]()
    for i in range(rows):
        out.append(gy.unsafe_load(i))
    VulkanBuffers.unmap(y_alloc)
    VulkanBuffers.free(y_alloc)
    return out^


def _shape_parity(rows: Int, cols: Int) raises -> Float32:
    """One non-dyadic shape vs the sequential CPU oracle; returns
    the max abs delta observed (also printed)."""
    var blocks_per_row = cols // 32
    var w_bytes = rows * blocks_per_row * 34
    var w_alloc = VulkanBuffers.allocate(w_bytes)
    var x_alloc = VulkanBuffers.allocate(cols * 4)
    var lcg = _Lcg(0xA056)
    var xs = List[Float32]()
    for _ in range(cols):
        xs.append(lcg.unit() * Float32(3.0) - Float32(1.5))
    var pw = VulkanBuffers.map(w_alloc)
    for blk in range(rows * blocks_per_row):
        var s = Float32(0.002) + lcg.unit() * Float32(0.018)
        if blk % 97 == 31:
            s = Float32(0.0)
        elif blk % 89 == 17:
            s = -s
        pw.unsafe_bitcast[Float16]().unsafe_store(blk * 17, Float16(s))
        for lane in range(32):
            pw.unsafe_store(blk * 34 + 2 + lane, lcg.byte())
    VulkanBuffers.unmap(w_alloc)
    var px = VulkanBuffers.map(x_alloc)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(cols):
        fx.unsafe_store(i, xs[i])
    VulkanBuffers.unmap(x_alloc)
    var got = _run_gpu(w_alloc, x_alloc, rows, cols)
    # Sequential CPU oracle over the identical bytes.
    var qw = VulkanBuffers.map(w_alloc)
    var max_abs: Float32 = 0.0
    for r in range(rows):
        var acc: Float32 = 0.0
        for blk in range(blocks_per_row):
            var base = (r * blocks_per_row + blk) * 34
            var scale = qw.unsafe_bitcast[Float16]().unsafe_load(
                (r * blocks_per_row + blk) * 17
            ).cast[DType.float32]()
            for lane in range(32):
                var raw = Int(qw.unsafe_load(base + 2 + lane))
                var q = raw - 256 if raw >= 128 else raw
                acc += scale * Float32(q) * xs[blk * 32 + lane]
        var d = got[r] - acc
        if d < 0:
            d = -d
        if d > max_abs:
            max_abs = d
    VulkanBuffers.unmap(w_alloc)
    VulkanBuffers.free(w_alloc)
    VulkanBuffers.free(x_alloc)
    print(
        "A056_SHAPE rows=", rows, " cols=", cols,
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
    # a in [p, 2p) with p = 2^e; F16 ULP there is 2^(e-10),
    # clamped at the subnormal granularity 2^-24.
    var ulp = p / Float32(1024.0)
    var min_ulp = Float32(1.0) / Float32(16777216.0)
    if ulp < min_ulp:
        ulp = min_ulp
    return ulp * Float32(0.5)

def test_vulkan_q8_gemv_oracle_parity() raises:
    print("--- Testing Vulkan Q8_0 GEMV oracle parity (A-056) ---")
    if not _vk_present():
        var rejected = False
        try:
            var a = VulkanBuffers.allocate(4096)
            VulkanBuffers.free(a)
        except:
            rejected = True
        if not rejected:
            raise Error("Vulkan unavailable but allocate succeeded (fabricated)")
        print("Vulkan UNAVAILABLE: GEMV fail-closed: PASS (honest-absent)")
        return
    var shapes_r = [1, 4, 16, 37, 64, 13]
    var shapes_c = [32, 64, 288, 320, 1024, 4096]
    var worst: Float32 = 0.0
    for s in range(len(shapes_r)):
        var m = _shape_parity(shapes_r[s], shapes_c[s])
        if m > worst:
            worst = m
    # Filed A-056 bound: accumulation-order only (GPU tree vs CPU
    # sequential, both Float32, identical dequant). Measured worst
    # is filed in hidden_files/A056_LEDGER.md; the bound carries
    # an order of magnitude of headroom over it.
    if worst > Float32(0.001):
        raise Error(
            "Q8_0 GEMV oracle parity exceeded filed bound: max_abs "
            + String(worst)
        )
    print(
        "Vulkan Q8_0 GEMV oracle parity (6 shapes incl. K=288"
        " stories scale and K=4096, RADV device, worst max_abs=",
        worst, "): PASS",
    )


def test_vulkan_q8_gemv_known_value() raises:
    print("--- Testing Vulkan Q8_0 GEMV known value (A-056) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: known-value case not run (honest-absent)")
        return
    var w_alloc = VulkanBuffers.allocate(34)
    var x_alloc = VulkanBuffers.allocate(32 * 4)
    var pw = VulkanBuffers.map(w_alloc)
    for i in range(34):
        pw.unsafe_store(i, UInt8(0))
    pw.unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.25))
    for i in range(32):
        pw.unsafe_store(2 + i, UInt8(i - 16))
    VulkanBuffers.unmap(w_alloc)
    var px = VulkanBuffers.map(x_alloc)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(32):
        fx.unsafe_store(i, Float32(1.0))
    VulkanBuffers.unmap(x_alloc)
    var got = _run_gpu(w_alloc, x_alloc, 1, 32)
    VulkanBuffers.free(w_alloc)
    VulkanBuffers.free(x_alloc)
    if got[0] != Float32(-4.0):
        raise Error(
            "Q8_0 GEMV known-value mismatch: got " + String(got[0])
            + " want -4"
        )
    print("Vulkan Q8_0 GEMV known value (scale 0.25, q=i-16, x=1 -> -4 exact): PASS")


def test_vulkan_q8_gemv_engine_crosscheck() raises:
    print("--- Testing Vulkan Q8_0 GEMV vs engine CPU GEMV (A-056) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: engine cross-check not run (honest-absent)")
        return
    # Dyadic fixture (A-038 discipline): activations on a 1/4 grid,
    # scales in {0, +/-0.5, +/-0.25, +/-0.0625}; every product and
    # partial sum is exact in Float32 and in the engine's F16
    # output, so GPU and engine CPU outputs must agree exactly.
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
    # Same bytes and activations (as Float32) through the GPU.
    var w_alloc = VulkanBuffers.allocate(weight_bytes)
    var x_alloc = VulkanBuffers.allocate(k_dim * 4)
    var pw = VulkanBuffers.map(w_alloc)
    for i in range(weight_bytes):
        pw.unsafe_store(i, w_ptr.unsafe_load(i))
    VulkanBuffers.unmap(w_alloc)
    var px = VulkanBuffers.map(x_alloc)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(k_dim):
        fx.unsafe_store(i, a_ptr.unsafe_load(i).cast[DType.float32]())
    VulkanBuffers.unmap(x_alloc)
    var got = _run_gpu(w_alloc, x_alloc, n_out, k_dim)
    VulkanBuffers.free(w_alloc)
    VulkanBuffers.free(x_alloc)
    for i in range(n_out):
        var want = c_cpu.unsafe_load(i).cast[DType.float32]()
        var d = got[i] - want
        if d < 0:
            d = -d
        # Half an F16 ULP at |want|: the engine output is the
        # exact dyadic sum rounded to F16, the GPU output is the
        # exact sum itself, so d may not exceed the rounding
        # distance (half the F16 ULP at that magnitude).
        var bound = _half_ulp16(want)
        if d > bound:
            raise Error(
                "Q8_0 GEMV engine cross-check mismatch at output "
                + String(i) + ": got " + String(got[i]) + " want "
                + String(want) + " (beyond half F16 ULP)"
            )
    _ = well
    print(
        "Vulkan Q8_0 GEMV vs engine CPU GEMV (dyadic K=1024 N=96,"
        " within half F16 ULP of engine output at every output): PASS"
    )


def test_vulkan_q8_gemv_rejection() raises:
    print("--- Testing Vulkan Q8_0 GEMV rejection (A-056) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: rejection cases not run (honest-absent)")
        return
    var w = VulkanBuffers.allocate(2 * 34)
    var x = VulkanBuffers.allocate(64 * 4)
    var y = VulkanBuffers.allocate(4 * 4)
    var zero_rows = False
    try:
        VulkanGemv.q8_0_gemv(w, x, y, 0, 64)
    except:
        zero_rows = True
    if not zero_rows:
        raise Error("q8_0_gemv accepted a zero row count")
    var bad_cols = False
    try:
        VulkanGemv.q8_0_gemv(w, x, y, 1, 48)
    except:
        bad_cols = True
    if not bad_cols:
        raise Error("q8_0_gemv accepted cols=48 (not a Q8_0 block multiple)")
    var oversize = False
    try:
        VulkanGemv.q8_0_gemv(w, x, y, 4, 64)
    except:
        oversize = True
    if not oversize:
        raise Error("q8_0_gemv accepted a shape beyond the buffers")
    var bogus = VulkanAllocation(9999, 1024 * 1024, 1024 * 1024, 16, 3)
    var bogus_rejected = False
    try:
        VulkanGemv.q8_0_gemv(bogus, x, y, 1, 64)
    except:
        bogus_rejected = True
    if not bogus_rejected:
        raise Error("q8_0_gemv accepted a bogus weight buffer id")
    VulkanBuffers.free(w)
    VulkanBuffers.free(x)
    VulkanBuffers.free(y)
    print("Vulkan Q8_0 GEMV rejection (zero rows, cols=48, oversize, bogus id): PASS")


def test_vulkan_q8_gemv_dispatch_evidence() raises:
    print("--- Testing Vulkan Q8_0 GEMV dispatch evidence (A-056) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: dispatch evidence not run (honest-absent)")
        return
    var before = VulkanGemv.dispatch_count()
    var base_bytes = VulkanBuffers.live_bytes()
    var base_count = VulkanBuffers.live_count()
    _ = _shape_parity(8, 256)
    _ = _shape_parity(8, 256)
    var after = VulkanGemv.dispatch_count()
    if after - before != 2:
        raise Error(
            "dispatch counter advanced by " + String(after - before)
            + " for 2 dispatches (device-execution evidence broken)"
        )
    if VulkanBuffers.live_bytes() != base_bytes:
        raise Error("q8_0_gemv loop leaked device bytes")
    if VulkanBuffers.live_count() != base_count:
        raise Error("q8_0_gemv loop leaked buffers")
    print(
        "Vulkan Q8_0 GEMV dispatch evidence (counter +2 for 2"
        " dispatches, accounting exact): PASS"
    )
