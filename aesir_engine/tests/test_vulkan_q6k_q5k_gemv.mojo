"""Vulkan Q6_K + Q5_K GEMV (A-058): dequant + single-row GEMV
dispatched on the GPU through the A-014/A-015 Vulkan context,
judged against the Z13 CPU oracle discipline of A-056.

Parity discipline:
- Non-dyadic shapes: GPU Float32 outputs vs a sequential Float32
  CPU oracle in this file that consumes the identical raw GGUF
  bytes with scalar layout math written from the GGUF Q6_K /
  Q5_K block layouts (210 / 176 bytes per 256-value block). The
  GPU reduces in tree order, so the filed tolerance is an
  accumulation-order bound, not a dequant bound: max_abs is
  printed for the ledger and asserted below the filed bound.
- Dyadic shapes: the same fixture is also run through the
  engine CPU GEMV routes (gemm_q6_k / gemm_q5_k_m, the A-038
  family). On dyadic data every Float32 partial sum is exact in
  any order, so GPU outputs must lie within half an F16 ULP of
  the engine F16 outputs - a comparator artifact bound.
- Known values: the repo Q6_K known block (ql=85, qh=51,
  scales=1, d=0.125, x=1) sums to exactly -96; a constructed
  Q5_K block (d=0.5, dmin=0.25, scales=2, mins=1, qs=0x11,
  qh=0, x=1) sums to exactly 192.

Device-execution evidence (law 6): the selected device must be
the AMD Radeon 8060S (RADV STRIX_HALO) - llvmpipe is refused by
the identity check - and the shim dispatch counters must advance
by exactly the number of dispatches performed. On a host without
that device the cases assert fail-closed behaviour and pass as
honest-absent, matching A-014/A-015/A-056 discipline.
"""
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_gemv import VulkanGemv
from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16
from core.compute import gemm_q6_k, gemm_q5_k_m


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
    which: Int,
) raises -> List[Float32]:
    var y_alloc = VulkanBuffers.allocate(rows * 4)
    var py = VulkanBuffers.map(y_alloc)
    var fy = py.unsafe_bitcast[Float32]()
    for i in range(rows):
        fy.unsafe_store(i, Float32(-9999.0))
    VulkanBuffers.unmap(y_alloc)
    if which == 6:
        VulkanGemv.q6_k_gemv(w_alloc, x_alloc, y_alloc, rows, cols)
    else:
        VulkanGemv.q5_k_gemv(w_alloc, x_alloc, y_alloc, rows, cols)
    var out = List[Float32]()
    var qy = VulkanBuffers.map(y_alloc)
    var gy = qy.unsafe_bitcast[Float32]()
    for i in range(rows):
        out.append(gy.unsafe_load(i))
    VulkanBuffers.unmap(y_alloc)
    VulkanBuffers.free(y_alloc)
    return out^


def _q6_value(qw: Pointer[UInt8, MutUntrackedOrigin], base: Int, i: Int) -> Float32:
    var c = i // 16
    var lane = i % 16
    var haf = c // 8
    var within = c % 8
    var grp = within // 2
    var hl = within % 2
    var ql = Int(qw.unsafe_load(base + haf * 64 + (grp % 2) * 32 + hl * 16 + lane))
    var nib = (ql & 0xF) if grp < 2 else (ql >> 4)
    var qh = Int(qw.unsafe_load(base + 128 + haf * 32 + hl * 16 + lane))
    var hi = (qh >> (2 * grp)) & 3
    var q = nib | (hi << 4)
    var scb = Int(qw.unsafe_load(base + 192 + c))
    var sc = scb - 256 if scb >= 128 else scb
    var d = qw.unsafe_bitcast[Float16]().unsafe_load((base + 208) // 2).cast[DType.float32]()
    return d * Float32(sc) * (Float32(q) - Float32(32.0))


def _q5_value(qw: Pointer[UInt8, MutUntrackedOrigin], base: Int, i: Int) -> Float32:
    var g = i // 32
    var within = i % 32
    var lane = within % 16
    var hs = within // 16
    var qs = Int(qw.unsafe_load(base + 48 + (g // 2) * 32 + hs * 16 + lane))
    var nib = (qs & 0xF) if g % 2 == 0 else (qs >> 4)
    var qhb = Int(qw.unsafe_load(base + 16 + hs * 16 + lane))
    var hibit = (qhb >> g) & 1
    var q = nib | (hibit << 4)
    var sc: Int
    var mn: Int
    if g < 4:
        sc = Int(qw.unsafe_load(base + 4 + g)) & 63
        mn = Int(qw.unsafe_load(base + 4 + g + 4)) & 63
    else:
        sc = (Int(qw.unsafe_load(base + 4 + g + 4)) & 15) | ((Int(qw.unsafe_load(base + 4 + g - 4)) >> 6) << 4)
        mn = (Int(qw.unsafe_load(base + 4 + g + 4)) >> 4) | ((Int(qw.unsafe_load(base + 4 + g)) >> 6) << 4)
    var d = qw.unsafe_bitcast[Float16]().unsafe_load(base // 2).cast[DType.float32]()
    var dmin = qw.unsafe_bitcast[Float16]().unsafe_load((base + 2) // 2).cast[DType.float32]()
    return d * Float32(sc) * Float32(q) - dmin * Float32(mn)


def _shape_parity(rows: Int, cols: Int, which: Int) raises -> Float32:
    var block_bytes = 210 if which == 6 else 176
    var blocks_per_row = cols // 256
    var w_bytes = rows * blocks_per_row * block_bytes
    var w_alloc = VulkanBuffers.allocate(w_bytes)
    var x_alloc = VulkanBuffers.allocate(cols * 4)
    var lcg = _Lcg(0xA058)
    var xs = List[Float32]()
    for _ in range(cols):
        xs.append(lcg.unit() * Float32(3.0) - Float32(1.5))
    var pw = VulkanBuffers.map(w_alloc)
    for i in range(w_bytes):
        pw.unsafe_store(i, lcg.byte())
    for blk in range(rows * blocks_per_row):
        var base = blk * block_bytes
        var d = Float32(0.002) + lcg.unit() * Float32(0.018)
        if which == 6:
            pw.unsafe_bitcast[Float16]().unsafe_store((base + 208) // 2, Float16(d))
            for c in range(16):
                var sc = Int(lcg.next() % 17) - 8
                pw.unsafe_store(base + 192 + c, UInt8(sc % 256))
        else:
            pw.unsafe_bitcast[Float16]().unsafe_store(base // 2, Float16(d))
            pw.unsafe_bitcast[Float16]().unsafe_store((base + 2) // 2, Float16(d * Float32(0.5)))
    VulkanBuffers.unmap(w_alloc)
    var px = VulkanBuffers.map(x_alloc)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(cols):
        fx.unsafe_store(i, xs[i])
    VulkanBuffers.unmap(x_alloc)
    var got = _run_gpu(w_alloc, x_alloc, rows, cols, which)
    var qw = VulkanBuffers.map(w_alloc)
    var max_abs: Float32 = 0.0
    for r in range(rows):
        var acc: Float32 = 0.0
        for k in range(cols):
            var base = (r * blocks_per_row + k // 256) * block_bytes
            var v = _q6_value(qw, base, k % 256) if which == 6 else _q5_value(qw, base, k % 256)
            acc += v * xs[k]
        var dd = got[r] - acc
        if dd < 0:
            dd = -dd
        if dd > max_abs:
            max_abs = dd
    VulkanBuffers.unmap(w_alloc)
    VulkanBuffers.free(w_alloc)
    VulkanBuffers.free(x_alloc)
    print(
        "A058_SHAPE which=", which, " rows=", rows, " cols=", cols,
        " cpu_oracle_max_abs=", max_abs,
    )
    return max_abs


def _half_ulp16(v: Float32) -> Float32:
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


def test_vulkan_q6k_q5k_oracle_parity() raises:
    print("--- Testing Vulkan Q6_K + Q5_K GEMV oracle parity (A-058) ---")
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
    var shapes_r = [1, 4, 16, 37, 13]
    var shapes_c = [256, 512, 768, 1024, 2048]
    var worst6: Float32 = 0.0
    var worst5: Float32 = 0.0
    for s in range(len(shapes_r)):
        var m6 = _shape_parity(shapes_r[s], shapes_c[s], 6)
        if m6 > worst6:
            worst6 = m6
        var m5 = _shape_parity(shapes_r[s], shapes_c[s], 5)
        if m5 > worst5:
            worst5 = m5
    if worst6 > Float32(0.05):
        raise Error("Q6_K GEMV oracle parity exceeded filed bound: max_abs " + String(worst6))
    if worst5 > Float32(0.05):
        raise Error("Q5_K GEMV oracle parity exceeded filed bound: max_abs " + String(worst5))
    print(
        "Vulkan Q6_K + Q5_K GEMV oracle parity (5 shapes each incl."
        " K=2048, RADV device, worst q6 max_abs=", worst6,
        " worst q5 max_abs=", worst5, "): PASS",
    )


def test_vulkan_q6k_q5k_known_value() raises:
    print("--- Testing Vulkan Q6_K + Q5_K GEMV known values (A-058) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: known-value cases not run (honest-absent)")
        return
    var w6 = VulkanBuffers.allocate(210)
    var x6 = VulkanBuffers.allocate(256 * 4)
    var pw = VulkanBuffers.map(w6)
    for i in range(210):
        pw.unsafe_store(i, UInt8(0))
    for i in range(128):
        pw.unsafe_store(i, UInt8(85))
    for i in range(64):
        pw.unsafe_store(128 + i, UInt8(51))
    for i in range(16):
        pw.unsafe_store(192 + i, UInt8(1))
    pw.unsafe_bitcast[Float16]().unsafe_store(208 // 2, Float16(0.125))
    VulkanBuffers.unmap(w6)
    var px = VulkanBuffers.map(x6)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(256):
        fx.unsafe_store(i, Float32(1.0))
    VulkanBuffers.unmap(x6)
    var got6 = _run_gpu(w6, x6, 1, 256, 6)
    VulkanBuffers.free(w6)
    VulkanBuffers.free(x6)
    if got6[0] != Float32(-96.0):
        raise Error("Q6_K GEMV known-value mismatch: got " + String(got6[0]) + " want -96")
    var w5 = VulkanBuffers.allocate(176)
    var x5 = VulkanBuffers.allocate(256 * 4)
    var pw5 = VulkanBuffers.map(w5)
    for i in range(176):
        pw5.unsafe_store(i, UInt8(0))
    pw5.unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.5))
    pw5.unsafe_bitcast[Float16]().unsafe_store(1, Float16(0.25))
    for g in range(4):
        pw5.unsafe_store(4 + g, UInt8(2))
        pw5.unsafe_store(8 + g, UInt8(1))
        pw5.unsafe_store(12 + g, UInt8(0x12))
    for i in range(128):
        pw5.unsafe_store(48 + i, UInt8(0x11))
    VulkanBuffers.unmap(w5)
    var px5 = VulkanBuffers.map(x5)
    var fx5 = px5.unsafe_bitcast[Float32]()
    for i in range(256):
        fx5.unsafe_store(i, Float32(1.0))
    VulkanBuffers.unmap(x5)
    var got5 = _run_gpu(w5, x5, 1, 256, 5)
    VulkanBuffers.free(w5)
    VulkanBuffers.free(x5)
    if got5[0] != Float32(192.0):
        raise Error("Q5_K GEMV known-value mismatch: got " + String(got5[0]) + " want 192")
    print("Vulkan Q6_K + Q5_K GEMV known values (Q6 -96 exact, Q5 192 exact): PASS")


def test_vulkan_q6k_q5k_engine_crosscheck() raises:
    print("--- Testing Vulkan Q6_K + Q5_K GEMV vs engine CPU GEMV (A-058) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: engine cross-check not run (honest-absent)")
        return
    # Q6_K dyadic fixture: d = 0.125, scales in {0, 1, 2, -1},
    # activations on a 1/4 grid; every partial sum is exact in
    # Float32, so GPU vs engine F16 output agree within half an
    # F16 ULP (the F16 rounding distance).
    var k_dim = 1024
    var n_out = 96
    var w_bytes6 = n_out * (k_dim // 256) * 210
    var well = MimirWell(1024 * 1024)
    var a_ptr = well.allocate(k_dim)
    var w_ptr = well.allocate(w_bytes6 // 2 + 2).unsafe_bitcast[UInt8]()
    var c_cpu = well.allocate(n_out)
    var lcg = _Lcg(0xA058)
    for i in range(k_dim):
        var q = Int(lcg.next() % 17) - 8
        a_ptr.unsafe_store(i, Float16(Float32(q) * Float32(0.25)))
    for blk in range(n_out * (k_dim // 256)):
        var base = blk * 210
        for i in range(210):
            w_ptr.unsafe_store(base + i, lcg.byte())
        var pick = blk % 4
        var sc: UInt8 = 1
        if pick == 1:
            sc = 2
        elif pick == 2:
            sc = 0
        elif pick == 3:
            sc = 255
        for c in range(16):
            w_ptr.unsafe_store(base + 192 + c, sc)
        w_ptr.unsafe_bitcast[Float16]().unsafe_store((base + 208) // 2, Float16(0.125))
    var A = RuneTensor[f16](1, k_dim, a_ptr, False)
    var B = RuneTensor[f16](n_out, k_dim, w_ptr.unsafe_bitcast[Float16](), True, CompressedFormatType(CompressedFormatType.Q6_K))
    var C = RuneTensor[f16](1, n_out, c_cpu, False)
    gemm_q6_k(A, B, C)
    var w_alloc = VulkanBuffers.allocate(w_bytes6)
    var x_alloc = VulkanBuffers.allocate(k_dim * 4)
    var pw = VulkanBuffers.map(w_alloc)
    for i in range(w_bytes6):
        pw.unsafe_store(i, w_ptr.unsafe_load(i))
    VulkanBuffers.unmap(w_alloc)
    var px = VulkanBuffers.map(x_alloc)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(k_dim):
        fx.unsafe_store(i, a_ptr.unsafe_load(i).cast[DType.float32]())
    VulkanBuffers.unmap(x_alloc)
    var got = _run_gpu(w_alloc, x_alloc, n_out, k_dim, 6)
    VulkanBuffers.free(w_alloc)
    VulkanBuffers.free(x_alloc)
    for i in range(n_out):
        var want = c_cpu.unsafe_load(i).cast[DType.float32]()
        var d = got[i] - want
        if d < 0:
            d = -d
        if d > _half_ulp16(want):
            raise Error(
                "Q6_K GEMV engine cross-check mismatch at output "
                + String(i) + ": got " + String(got[i]) + " want " + String(want)
            )
    # Q5_K dyadic fixture: d = dmin = 0.0625, scales in {1, 2, 3},
    # mins in {0, 1} via the packed 12-byte scale/min header.
    var k5 = 512
    var n5 = 32
    var w_bytes5 = n5 * (k5 // 256) * 176
    var a5_ptr = well.allocate(k5)
    var w5_ptr = well.allocate(w_bytes5 // 2 + 2).unsafe_bitcast[UInt8]()
    var c5_cpu = well.allocate(n5)
    for i in range(k5):
        var q5 = Int(lcg.next() % 17) - 8
        a5_ptr.unsafe_store(i, Float16(Float32(q5) * Float32(0.25)))
    for blk in range(n5 * (k5 // 256)):
        var base = blk * 176
        for i in range(176):
            w5_ptr.unsafe_store(base + i, lcg.byte())
        var scv = UInt8(1 + blk % 3)
        var mnv = UInt8(blk % 2)
        for g in range(4):
            w5_ptr.unsafe_store(base + 4 + g, scv)
            w5_ptr.unsafe_store(base + 8 + g, mnv)
            w5_ptr.unsafe_store(base + 12 + g, (mnv << 4) | scv)
        w5_ptr.unsafe_bitcast[Float16]().unsafe_store(base // 2, Float16(0.0625))
        w5_ptr.unsafe_bitcast[Float16]().unsafe_store((base + 2) // 2, Float16(0.0625))
    var A5 = RuneTensor[f16](1, k5, a5_ptr, False)
    var B5 = RuneTensor[f16](n5, k5, w5_ptr.unsafe_bitcast[Float16](), True, CompressedFormatType(CompressedFormatType.Q5_K_M))
    var C5 = RuneTensor[f16](1, n5, c5_cpu, False)
    gemm_q5_k_m(A5, B5, C5)
    var w5_alloc = VulkanBuffers.allocate(w_bytes5)
    var x5_alloc = VulkanBuffers.allocate(k5 * 4)
    var pw5 = VulkanBuffers.map(w5_alloc)
    for i in range(w_bytes5):
        pw5.unsafe_store(i, w5_ptr.unsafe_load(i))
    VulkanBuffers.unmap(w5_alloc)
    var px5 = VulkanBuffers.map(x5_alloc)
    var fx5 = px5.unsafe_bitcast[Float32]()
    for i in range(k5):
        fx5.unsafe_store(i, a5_ptr.unsafe_load(i).cast[DType.float32]())
    VulkanBuffers.unmap(x5_alloc)
    var got5 = _run_gpu(w5_alloc, x5_alloc, n5, k5, 5)
    VulkanBuffers.free(w5_alloc)
    VulkanBuffers.free(x5_alloc)
    for i in range(n5):
        var want5 = c5_cpu.unsafe_load(i).cast[DType.float32]()
        var d5 = got5[i] - want5
        if d5 < 0:
            d5 = -d5
        if d5 > _half_ulp16(want5):
            raise Error(
                "Q5_K GEMV engine cross-check mismatch at output "
                + String(i) + ": got " + String(got5[i]) + " want " + String(want5)
            )
    _ = well
    print("Vulkan Q6_K + Q5_K GEMV vs engine CPU GEMV (dyadic, within half F16 ULP): PASS")


def test_vulkan_q6k_q5k_rejection() raises:
    print("--- Testing Vulkan Q6_K + Q5_K GEMV rejection (A-058) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: rejection cases not run (honest-absent)")
        return
    var w = VulkanBuffers.allocate(2 * 210)
    var x = VulkanBuffers.allocate(512 * 4)
    var y = VulkanBuffers.allocate(4 * 4)
    var zero_rows = False
    try:
        VulkanGemv.q6_k_gemv(w, x, y, 0, 512)
    except:
        zero_rows = True
    if not zero_rows:
        raise Error("q6_k_gemv accepted a zero row count")
    var bad_cols = False
    try:
        VulkanGemv.q6_k_gemv(w, x, y, 1, 128)
    except:
        bad_cols = True
    if not bad_cols:
        raise Error("q6_k_gemv accepted cols=128 (not a Q6_K block multiple)")
    var oversize = False
    try:
        VulkanGemv.q6_k_gemv(w, x, y, 4, 512)
    except:
        oversize = True
    if not oversize:
        raise Error("q6_k_gemv accepted a shape beyond the buffers")
    var bogus = VulkanAllocation(9999, 1024 * 1024, 1024 * 1024, 16, 3)
    var bogus_rejected = False
    try:
        VulkanGemv.q6_k_gemv(bogus, x, y, 1, 512)
    except:
        bogus_rejected = True
    if not bogus_rejected:
        raise Error("q6_k_gemv accepted a bogus weight buffer id")
    var bad5 = False
    try:
        VulkanGemv.q5_k_gemv(w, x, y, 1, 384)
    except:
        bad5 = True
    if not bad5:
        raise Error("q5_k_gemv accepted cols=384 (not a Q5_K block multiple)")
    var over5 = False
    try:
        VulkanGemv.q5_k_gemv(w, x, y, 4, 512)
    except:
        over5 = True
    if not over5:
        raise Error("q5_k_gemv accepted a shape beyond the buffers")
    VulkanBuffers.free(w)
    VulkanBuffers.free(x)
    VulkanBuffers.free(y)
    print("Vulkan Q6_K + Q5_K GEMV rejection (zero rows, bad cols, oversize, bogus id): PASS")


def test_vulkan_q6k_q5k_dispatch_evidence() raises:
    print("--- Testing Vulkan Q6_K + Q5_K GEMV dispatch evidence (A-058) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: dispatch evidence not run (honest-absent)")
        return
    var before6 = VulkanGemv.q6_dispatch_count()
    var before5 = VulkanGemv.q5_dispatch_count()
    var base_bytes = VulkanBuffers.live_bytes()
    var base_count = VulkanBuffers.live_count()
    _ = _shape_parity(8, 256, 6)
    _ = _shape_parity(8, 256, 6)
    _ = _shape_parity(8, 256, 5)
    _ = _shape_parity(8, 256, 5)
    var after6 = VulkanGemv.q6_dispatch_count()
    var after5 = VulkanGemv.q5_dispatch_count()
    if after6 - before6 != 2:
        raise Error("Q6 dispatch counter advanced by " + String(after6 - before6) + " for 2 dispatches")
    if after5 - before5 != 2:
        raise Error("Q5 dispatch counter advanced by " + String(after5 - before5) + " for 2 dispatches")
    if VulkanBuffers.live_bytes() != base_bytes:
        raise Error("A-058 GEMV loop leaked device bytes")
    if VulkanBuffers.live_count() != base_count:
        raise Error("A-058 GEMV loop leaked buffers")
    print("Vulkan Q6_K + Q5_K GEMV dispatch evidence (counters +2 each, accounting exact): PASS")
