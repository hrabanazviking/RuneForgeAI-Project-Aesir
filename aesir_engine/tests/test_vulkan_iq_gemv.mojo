"""Vulkan IQ GEMV (A-059): dequant + single-row GEMV dispatched
on the GPU through the A-014/A-015 Vulkan context, judged
against the Z13 CPU oracle discipline of A-056/A-058. IQ2_XXS
first, then IQ1_S, IQ3_XXS and IQ4_NL - the IQ formats with
fast CPU paths in the A-046 census (GEMM kind registry 16/19/
18/20). Acceptance per the roadmap is coherence-grade parity
per law 3: outputs are graded against the CPU oracle under a
filed accumulation-order tolerance (rank/logit-gap discipline
applies at the model level; at this GEMV level the filed bound
below is the grade), never token-exactness.

Parity discipline:
- Non-dyadic shapes: GPU Float32 outputs vs a sequential Float32
  CPU oracle in this file that consumes the identical raw GGUF
  bytes with scalar layout math written from the GGML block
  layouts (66/50/98 bytes per 256-value block; 18 bytes per
  32-value IQ4_NL block). The grid tables are GGML format
  constants, materialized from core.iq_codebooks via
  iq_grid_materialize - shared format data, not expected values;
  every expected output is computed by the scalar oracle here,
  never by the code under test.
- Dyadic shapes: the same fixture also runs through the engine
  CPU GEMV routes (gemm_iq2_xxs / gemm_iq1_s / gemm_iq3_xxs /
  gemm_iq4_nl). On dyadic data every Float32 partial sum is
  exact in any order, so GPU outputs must lie within half an
  F16 ULP of the engine F16 outputs.
- Known values: all-zero blocks with d = 1 give exactly 256
  (IQ2_XXS), -224 (IQ1_S) and 256 (IQ3_XXS) at K = 256, x = 1;
  an IQ4_NL block with d = 0.5 and qs = 0x88 gives exactly 128
  at K = 256 and 144 at K = 288.
- Bug A-046:B1 landing: IQ4_NL is a 32-value-block format, so
  this slice's GPU gateway accepts any positive multiple of 32
  columns (K = 288 included). The CPU gemm_iq wrapper still
  demands cols % 256 for kind 20 - recorded in CAMPAIGN_STATE
  as B1's remaining CPU-side home.

Device-execution evidence (law 6): the selected device must be
the AMD Radeon 8060S (RADV STRIX_HALO) - llvmpipe is refused by
the identity check - and the shim dispatch counters must
advance by exactly the number of dispatches performed. On a
host without that device the cases assert fail-closed
behaviour and pass as honest-absent, matching A-056 discipline.
"""
from std.memory.alloc import alloc
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_gemv import VulkanGemv
from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16
from core.compute import gemm_iq2_xxs, gemm_iq1_s, gemm_iq3_xxs, gemm_iq4_nl
from core.extreme_quantization import iq_grid_materialize


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


# Format ids: 0 IQ2_XXS, 1 IQ1_S, 2 IQ3_XXS, 3 IQ4_NL.
def _block_bytes(which: Int) -> Int:
    if which == 0:
        return 66
    if which == 1:
        return 50
    if which == 2:
        return 98
    return 18


def _block_values(which: Int) -> Int:
    return 32 if which == 3 else 256


def _grid_kind(which: Int) -> Int:
    if which == 0:
        return 16
    if which == 1:
        return 19
    return 18


def _grid_alloc(which: Int) raises -> VulkanAllocation:
    var host = alloc[UInt16](2048)
    for i in range(2048):
        host.unsafe_store(i, UInt16(0))
    iq_grid_materialize(_grid_kind(which), host)
    var a = VulkanBuffers.allocate(4096)
    var p = VulkanBuffers.map(a)
    var bytes = host.unsafe_bitcast[UInt8]()
    for i in range(4096):
        p.unsafe_store(i, bytes.unsafe_load(i))
    VulkanBuffers.unmap(a)
    host.unsafe_free()
    return a^


def _grid_host(which: Int) -> Pointer[UInt16, MutUntrackedOrigin]:
    var host = alloc[UInt16](2048)
    for i in range(2048):
        host.unsafe_store(i, UInt16(0))
    iq_grid_materialize(_grid_kind(which), host)
    return host


def _sign_mask8(index: Int) -> Int:
    var parity = 0
    var v = index
    for _ in range(7):
        parity ^= v & 1
        v >>= 1
    return index | (parity << 7)


def _u32le(qw: Pointer[UInt8, MutUntrackedOrigin], base: Int) -> Int:
    return (
        Int(qw.unsafe_load(base))
        | (Int(qw.unsafe_load(base + 1)) << 8)
        | (Int(qw.unsafe_load(base + 2)) << 16)
        | (Int(qw.unsafe_load(base + 3)) << 24)
    )


def _f16_at(qw: Pointer[UInt8, MutUntrackedOrigin], base: Int) -> Float32:
    return qw.unsafe_bitcast[Float16]().unsafe_load(base // 2).cast[DType.float32]()


def _iq_value(
    qw: Pointer[UInt8, MutUntrackedOrigin],
    grid: Pointer[UInt16, MutUntrackedOrigin],
    base: Int,
    i: Int,
    which: Int,
) -> Float32:
    if which == 3:
        var d = _f16_at(qw, base)
        var lane = i % 32
        var qs = Int(qw.unsafe_load(base + 2 + lane % 16))
        var nib = (qs & 0x0F) if lane < 16 else ((qs >> 4) & 0x0F)
        var kv = Float32(-127.0)
        if nib == 1:
            kv = Float32(-104.0)
        elif nib == 2:
            kv = Float32(-83.0)
        elif nib == 3:
            kv = Float32(-65.0)
        elif nib == 4:
            kv = Float32(-49.0)
        elif nib == 5:
            kv = Float32(-35.0)
        elif nib == 6:
            kv = Float32(-22.0)
        elif nib == 7:
            kv = Float32(-10.0)
        elif nib == 8:
            kv = Float32(1.0)
        elif nib == 9:
            kv = Float32(13.0)
        elif nib == 10:
            kv = Float32(25.0)
        elif nib == 11:
            kv = Float32(38.0)
        elif nib == 12:
            kv = Float32(53.0)
        elif nib == 13:
            kv = Float32(69.0)
        elif nib == 14:
            kv = Float32(89.0)
        elif nib == 15:
            kv = Float32(113.0)
        return d * kv
    var d2 = _f16_at(qw, base)
    var group = i // 32
    var gl = i % 32
    var sub = gl // 8
    var glane = gl % 8
    if which == 0:
        var packed = base + 2 + group * 8
        var enc = Int(grid.unsafe_load(Int(qw.unsafe_load(packed + sub))))
        var digit = (enc >> (glane * 2)) & 3
        var gv = Float32(8.0)
        if digit == 1:
            gv = Float32(25.0)
        elif digit == 2:
            gv = Float32(43.0)
        var sas = _u32le(qw, packed + 4)
        var local = (Float32(0.5) + Float32(sas >> 28)) * Float32(0.25)
        var mask = _sign_mask8((sas >> (sub * 7)) & 0x7F)
        var sign = Float32(-1.0) if ((mask >> glane) & 1) != 0 else Float32(1.0)
        return d2 * local * gv * sign
    if which == 1:
        var qh = Int(qw.unsafe_load(base + 34 + group * 2)) | (Int(qw.unsafe_load(base + 35 + group * 2)) << 8)
        var gidx = Int(qw.unsafe_load(base + 2 + group * 4 + sub)) | (((qh >> (sub * 3)) & 7) << 8)
        var enc1 = Int(grid.unsafe_load(gidx))
        var digit1 = (enc1 >> (glane * 2)) & 3
        var gv1 = Float32(-1.0)
        if digit1 == 1:
            gv1 = Float32(0.0)
        elif digit1 == 2:
            gv1 = Float32(1.0)
        var local1 = d2 * Float32(2 * ((qh >> 12) & 7) + 1)
        var delta = Float32(-0.125) if (qh & 0x8000) != 0 else Float32(0.125)
        return local1 * (gv1 + delta)
    var aux = _u32le(qw, base + 66 + group * 4)
    var local3 = (Float32(0.5) + Float32(aux >> 28)) * Float32(0.5)
    var gbyte = base + 2 + group * 8 + 2 * sub + (0 if glane < 4 else 1)
    var enc3 = Int(grid.unsafe_load(Int(qw.unsafe_load(gbyte))))
    var digit3 = (enc3 >> ((glane % 4) * 3)) & 7
    var gv3 = Float32(62.0) if digit3 == 7 else Float32(4 + 8 * digit3)
    var mask3 = _sign_mask8((aux >> (7 * sub)) & 0x7F)
    var sign3 = Float32(-1.0) if ((mask3 >> glane) & 1) != 0 else Float32(1.0)
    return d2 * local3 * gv3 * sign3


def _run_gpu(
    w_alloc: VulkanAllocation,
    x_alloc: VulkanAllocation,
    g_alloc: VulkanAllocation,
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
    if which == 0:
        VulkanGemv.iq2_xxs_gemv(w_alloc, x_alloc, y_alloc, g_alloc, rows, cols)
    elif which == 1:
        VulkanGemv.iq1_s_gemv(w_alloc, x_alloc, y_alloc, g_alloc, rows, cols)
    elif which == 2:
        VulkanGemv.iq3_xxs_gemv(w_alloc, x_alloc, y_alloc, g_alloc, rows, cols)
    else:
        VulkanGemv.iq4_nl_gemv(w_alloc, x_alloc, y_alloc, rows, cols)
    var out = List[Float32]()
    var qy = VulkanBuffers.map(y_alloc)
    var gy = qy.unsafe_bitcast[Float32]()
    for i in range(rows):
        out.append(gy.unsafe_load(i))
    VulkanBuffers.unmap(y_alloc)
    VulkanBuffers.free(y_alloc)
    return out^


def _shape_parity(rows: Int, cols: Int, which: Int) raises -> Float32:
    var bb = _block_bytes(which)
    var bv = _block_values(which)
    var blocks_per_row = cols // bv
    var w_bytes = rows * blocks_per_row * bb
    var w_alloc = VulkanBuffers.allocate(w_bytes)
    var x_alloc = VulkanBuffers.allocate(cols * 4)
    var g_alloc = _grid_alloc(which if which != 3 else 0)
    var grid = _grid_host(which if which != 3 else 0)
    var lcg = _Lcg(0xA059)
    var xs = List[Float32]()
    for _ in range(cols):
        xs.append(lcg.unit() * Float32(3.0) - Float32(1.5))
    var pw = VulkanBuffers.map(w_alloc)
    for i in range(w_bytes):
        pw.unsafe_store(i, lcg.byte())
    for blk in range(rows * blocks_per_row):
        var base = blk * bb
        var d = Float32(0.002) + lcg.unit() * Float32(0.01)
        pw.unsafe_bitcast[Float16]().unsafe_store(base // 2, Float16(d))
    VulkanBuffers.unmap(w_alloc)
    var px = VulkanBuffers.map(x_alloc)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(cols):
        fx.unsafe_store(i, xs[i])
    VulkanBuffers.unmap(x_alloc)
    var got = _run_gpu(w_alloc, x_alloc, g_alloc, rows, cols, which)
    var qw = VulkanBuffers.map(w_alloc)
    var max_abs: Float32 = 0.0
    for r in range(rows):
        var acc: Float32 = 0.0
        for k in range(cols):
            var base = (r * blocks_per_row + k // bv) * bb
            acc += _iq_value(qw, grid, base, k % bv, which) * xs[k]
        var dd = got[r] - acc
        if dd < 0:
            dd = -dd
        if dd > max_abs:
            max_abs = dd
    VulkanBuffers.unmap(w_alloc)
    VulkanBuffers.free(w_alloc)
    VulkanBuffers.free(x_alloc)
    VulkanBuffers.free(g_alloc)
    grid.unsafe_free()
    print(
        "A059_SHAPE which=", which, " rows=", rows, " cols=", cols,
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


def test_vulkan_iq_gemv_oracle_parity() raises:
    print("--- Testing Vulkan IQ GEMV oracle parity (A-059) ---")
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
    var shapes4_c = [32, 288, 512, 1024, 2048]
    var worst: Float32 = 0.0
    for which in range(4):
        for s in range(len(shapes_r)):
            var cols = shapes4_c[s] if which == 3 else shapes_c[s]
            var m = _shape_parity(shapes_r[s], cols, which)
            if m > worst:
                worst = m
    if worst > Float32(0.05):
        raise Error("IQ GEMV oracle parity exceeded filed bound: max_abs " + String(worst))
    print(
        "Vulkan IQ GEMV oracle parity (4 formats x 5 shapes incl."
        " IQ4_NL K=288, RADV device, worst max_abs=", worst, "): PASS",
    )


def _known_run(which: Int, cols: Int, fill: UInt8, d: Float32) raises -> Float32:
    var bb = _block_bytes(which)
    var bv = _block_values(which)
    var w_bytes = (cols // bv) * bb
    var w_alloc = VulkanBuffers.allocate(w_bytes)
    var x_alloc = VulkanBuffers.allocate(cols * 4)
    var g_alloc = _grid_alloc(which if which != 3 else 0)
    var pw = VulkanBuffers.map(w_alloc)
    for i in range(w_bytes):
        pw.unsafe_store(i, fill)
    for blk in range(cols // bv):
        pw.unsafe_bitcast[Float16]().unsafe_store((blk * bb) // 2, Float16(d))
    VulkanBuffers.unmap(w_alloc)
    var px = VulkanBuffers.map(x_alloc)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(cols):
        fx.unsafe_store(i, Float32(1.0))
    VulkanBuffers.unmap(x_alloc)
    var got = _run_gpu(w_alloc, x_alloc, g_alloc, 1, cols, which)
    VulkanBuffers.free(w_alloc)
    VulkanBuffers.free(x_alloc)
    VulkanBuffers.free(g_alloc)
    return got[0]


def test_vulkan_iq_gemv_known_value() raises:
    print("--- Testing Vulkan IQ GEMV known values (A-059) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: known-value cases not run (honest-absent)")
        return
    var v2 = _known_run(0, 256, UInt8(0), Float32(1.0))
    if v2 != Float32(256.0):
        raise Error("IQ2_XXS GEMV known-value mismatch: got " + String(v2) + " want 256")
    var v1 = _known_run(1, 256, UInt8(0), Float32(1.0))
    if v1 != Float32(-224.0):
        raise Error("IQ1_S GEMV known-value mismatch: got " + String(v1) + " want -224")
    var v3 = _known_run(2, 256, UInt8(0), Float32(1.0))
    if v3 != Float32(256.0):
        raise Error("IQ3_XXS GEMV known-value mismatch: got " + String(v3) + " want 256")
    var v4 = _known_run(3, 256, UInt8(0x88), Float32(0.5))
    if v4 != Float32(128.0):
        raise Error("IQ4_NL GEMV known-value mismatch: got " + String(v4) + " want 128")
    var v4b = _known_run(3, 288, UInt8(0x88), Float32(0.5))
    if v4b != Float32(144.0):
        raise Error("IQ4_NL GEMV K=288 known-value mismatch: got " + String(v4b) + " want 144")
    print("Vulkan IQ GEMV known values (256 / -224 / 256 / 128 / K=288 144, all exact): PASS")


def test_vulkan_iq_gemv_engine_crosscheck() raises:
    print("--- Testing Vulkan IQ GEMV vs engine CPU GEMV (A-059) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: engine cross-check not run (honest-absent)")
        return
    var k_dim = 512
    var n_out = 32
    var well = MimirWell(1024 * 1024)
    var a_ptr = well.allocate(k_dim)
    var lcg = _Lcg(0xA059)
    for i in range(k_dim):
        var q = Int(lcg.next() % 17) - 8
        a_ptr.unsafe_store(i, Float16(Float32(q) * Float32(0.25)))
    var fmts = [
        CompressedFormatType(CompressedFormatType.IQ2_XXS),
        CompressedFormatType(CompressedFormatType.IQ1_S),
        CompressedFormatType(CompressedFormatType.IQ3_XXS),
        CompressedFormatType(CompressedFormatType.IQ4_NL),
    ]
    for which in range(4):
        var bb = _block_bytes(which)
        var bv = _block_values(which)
        var w_bytes = n_out * (k_dim // bv) * bb
        var w_ptr = well.allocate(w_bytes // 2 + 2).unsafe_bitcast[UInt8]()
        var c_cpu = well.allocate(n_out)
        for blk in range(n_out * (k_dim // bv)):
            var base = blk * bb
            for i in range(bb):
                w_ptr.unsafe_store(base + i, lcg.byte())
            w_ptr.unsafe_bitcast[Float16]().unsafe_store(base // 2, Float16(0.125))
        var A = RuneTensor[f16](1, k_dim, a_ptr, False)
        var B = RuneTensor[f16](n_out, k_dim, w_ptr.unsafe_bitcast[Float16](), True, fmts[which])
        var C = RuneTensor[f16](1, n_out, c_cpu, False)
        if which == 0:
            gemm_iq2_xxs(A, B, C)
        elif which == 1:
            gemm_iq1_s(A, B, C)
        elif which == 2:
            gemm_iq3_xxs(A, B, C)
        else:
            gemm_iq4_nl(A, B, C)
        var w_alloc = VulkanBuffers.allocate(w_bytes)
        var x_alloc = VulkanBuffers.allocate(k_dim * 4)
        var g_alloc = _grid_alloc(which if which != 3 else 0)
        var pw = VulkanBuffers.map(w_alloc)
        for i in range(w_bytes):
            pw.unsafe_store(i, w_ptr.unsafe_load(i))
        VulkanBuffers.unmap(w_alloc)
        var px = VulkanBuffers.map(x_alloc)
        var fx = px.unsafe_bitcast[Float32]()
        for i in range(k_dim):
            fx.unsafe_store(i, a_ptr.unsafe_load(i).cast[DType.float32]())
        VulkanBuffers.unmap(x_alloc)
        var got = _run_gpu(w_alloc, x_alloc, g_alloc, n_out, k_dim, which)
        VulkanBuffers.free(w_alloc)
        VulkanBuffers.free(x_alloc)
        VulkanBuffers.free(g_alloc)
        for i in range(n_out):
            var want = c_cpu.unsafe_load(i).cast[DType.float32]()
            var dd = got[i] - want
            if dd < 0:
                dd = -dd
            if dd > _half_ulp16(want):
                raise Error(
                    "IQ GEMV engine cross-check mismatch which=" + String(which)
                    + " at output " + String(i) + ": got " + String(got[i])
                    + " want " + String(want)
                )
    _ = well
    print("Vulkan IQ GEMV vs engine CPU GEMV (dyadic, 4 formats, within half F16 ULP): PASS")


def test_vulkan_iq_gemv_rejection() raises:
    print("--- Testing Vulkan IQ GEMV rejection (A-059) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: rejection cases not run (honest-absent)")
        return
    var w = VulkanBuffers.allocate(2 * 98)
    var x = VulkanBuffers.allocate(512 * 4)
    var y = VulkanBuffers.allocate(4 * 4)
    var g = _grid_alloc(0)
    var zero_rows = False
    try:
        VulkanGemv.iq2_xxs_gemv(w, x, y, g, 0, 512)
    except:
        zero_rows = True
    if not zero_rows:
        raise Error("iq2_xxs_gemv accepted a zero row count")
    var bad_cols = False
    try:
        VulkanGemv.iq2_xxs_gemv(w, x, y, g, 1, 128)
    except:
        bad_cols = True
    if not bad_cols:
        raise Error("iq2_xxs_gemv accepted cols=128 (not a 256-block multiple)")
    var oversize = False
    try:
        VulkanGemv.iq3_xxs_gemv(w, x, y, g, 4, 512)
    except:
        oversize = True
    if not oversize:
        raise Error("iq3_xxs_gemv accepted a shape beyond the buffers")
    var bogus = VulkanAllocation(9999, 1024 * 1024, 1024 * 1024, 16, 3)
    var bogus_rejected = False
    try:
        VulkanGemv.iq1_s_gemv(bogus, x, y, g, 1, 512)
    except:
        bogus_rejected = True
    if not bogus_rejected:
        raise Error("iq1_s_gemv accepted a bogus weight buffer id")
    var bogus_grid = False
    try:
        VulkanGemv.iq1_s_gemv(w, x, y, bogus, 1, 256)
    except:
        bogus_grid = True
    if not bogus_grid:
        raise Error("iq1_s_gemv accepted a bogus grid buffer id")
    var bad4 = False
    try:
        VulkanGemv.iq4_nl_gemv(w, x, y, 1, 16)
    except:
        bad4 = True
    if not bad4:
        raise Error("iq4_nl_gemv accepted cols=16 (not a 32-block multiple)")
    var over4 = False
    try:
        VulkanGemv.iq4_nl_gemv(w, x, y, 4, 512)
    except:
        over4 = True
    if not over4:
        raise Error("iq4_nl_gemv accepted a shape beyond the buffers")
    VulkanBuffers.free(w)
    VulkanBuffers.free(x)
    VulkanBuffers.free(y)
    VulkanBuffers.free(g)
    print("Vulkan IQ GEMV rejection (zero rows, bad cols x2, oversize x2, bogus id, bogus grid): PASS")


def test_vulkan_iq_gemv_dispatch_evidence() raises:
    print("--- Testing Vulkan IQ GEMV dispatch evidence (A-059) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: dispatch evidence not run (honest-absent)")
        return
    var b2 = VulkanGemv.iq2xxs_dispatch_count()
    var b1 = VulkanGemv.iq1s_dispatch_count()
    var b3 = VulkanGemv.iq3xxs_dispatch_count()
    var b4 = VulkanGemv.iq4nl_dispatch_count()
    var base_bytes = VulkanBuffers.live_bytes()
    var base_count = VulkanBuffers.live_count()
    _ = _shape_parity(8, 256, 0)
    _ = _shape_parity(8, 256, 0)
    _ = _shape_parity(8, 256, 1)
    _ = _shape_parity(8, 256, 1)
    _ = _shape_parity(8, 256, 2)
    _ = _shape_parity(8, 256, 2)
    _ = _shape_parity(8, 288, 3)
    _ = _shape_parity(8, 288, 3)
    if VulkanGemv.iq2xxs_dispatch_count() - b2 != 2:
        raise Error("IQ2_XXS dispatch counter did not advance by exactly 2")
    if VulkanGemv.iq1s_dispatch_count() - b1 != 2:
        raise Error("IQ1_S dispatch counter did not advance by exactly 2")
    if VulkanGemv.iq3xxs_dispatch_count() - b3 != 2:
        raise Error("IQ3_XXS dispatch counter did not advance by exactly 2")
    if VulkanGemv.iq4nl_dispatch_count() - b4 != 2:
        raise Error("IQ4_NL dispatch counter did not advance by exactly 2")
    if VulkanBuffers.live_bytes() != base_bytes:
        raise Error("A-059 GEMV loop leaked device bytes")
    if VulkanBuffers.live_count() != base_count:
        raise Error("A-059 GEMV loop leaked buffers")
    print("Vulkan IQ GEMV dispatch evidence (counters +2 per format, accounting exact): PASS")
