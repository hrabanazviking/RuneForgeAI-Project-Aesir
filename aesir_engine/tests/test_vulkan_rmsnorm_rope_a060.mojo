"""Vulkan RMSNorm + RoPE (A-060): both A-055 foundation kernels
dispatched on the GPU through the A-014/A-015 Vulkan context,
judged per op against independent CPU references in this file
(raw-oracle discipline: expected values are computed here from
the input data with sequential Float32 math, never read back
from the code under test).

Parity discipline:
- RMSNorm: y[i] = x[i] * rsqrt(mean(x^2) + eps) * g[i], the
  engine CPU rmsnorm math (core/compute.mojo) restated
  sequentially in Float32. The GPU reduces the sum of squares
  in tree order over 256 invocations, so the filed tolerance
  is an accumulation-order bound. Shapes include the
  adversarial compute patterns: odd row lengths (37, 255,
  257), a zero row, a constant row, and a large-magnitude row
  (RMSNorm is scale-invariant, so the bound must not grow).
- RoPE: rotate-half pairing (pair (i, i + head_dim/2), angle
  position * base^(-2i/head_dim)) - the layout of the shader
  of record and of the engine CPU apply_rope with neox=True.
  The oracle computes cos/sin per pair in Float32 from the
  same formula; the filed tolerance covers fp32 pow/cos/sin
  disagreement between RADV and the host libm. Position 0 is
  an exact identity and is asserted exactly.

Device-execution evidence (law 6): the selected device must
be the AMD Radeon 8060S (RADV STRIX_HALO) - llvmpipe is
refused by the identity check - and the per-op shim dispatch
counters must advance by exactly the number of dispatches
performed. On a host without that device the cases assert
fail-closed behaviour and pass as honest-absent, matching
A-014/A-015/A-056 discipline.
"""
from std.math import sqrt, cos, sin
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_norm_rope import VulkanNormRope


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

    def unit(mut self) -> Float32:
        return Float32(self.next() & 0xFFFFFF) / Float32(16777216.0)


def _abs32(v: Float32) -> Float32:
    return -v if v < Float32(0.0) else v


def _rmsnorm_parity(rows: Int, n: Int, scale: Float32, eps: Float32) raises -> Float32:
    """One shape vs the sequential CPU oracle; returns the max
    abs delta observed (also printed)."""
    var x_alloc = VulkanBuffers.allocate(rows * n * 4)
    var g_alloc = VulkanBuffers.allocate(n * 4)
    var y_alloc = VulkanBuffers.allocate(rows * n * 4)
    var lcg = _Lcg(0xA060)
    var xs = List[Float32]()
    for _ in range(rows * n):
        xs.append((lcg.unit() * Float32(2.0) - Float32(1.0)) * scale)
    var gs = List[Float32]()
    for _ in range(n):
        gs.append(lcg.unit() * Float32(1.5) + Float32(0.25))
    var px = VulkanBuffers.map(x_alloc)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(rows * n):
        fx.unsafe_store(i, xs[i])
    VulkanBuffers.unmap(x_alloc)
    var pg = VulkanBuffers.map(g_alloc)
    var fg = pg.unsafe_bitcast[Float32]()
    for i in range(n):
        fg.unsafe_store(i, gs[i])
    VulkanBuffers.unmap(g_alloc)
    var py = VulkanBuffers.map(y_alloc)
    var fy = py.unsafe_bitcast[Float32]()
    for i in range(rows * n):
        fy.unsafe_store(i, Float32(-9999.0))
    VulkanBuffers.unmap(y_alloc)
    VulkanNormRope.rmsnorm(x_alloc, g_alloc, y_alloc, n, rows, eps)
    var qy = VulkanBuffers.map(y_alloc)
    var gy = qy.unsafe_bitcast[Float32]()
    var max_abs: Float32 = 0.0
    for r in range(rows):
        var ss: Float32 = 0.0
        for i in range(n):
            var v = xs[r * n + i]
            ss += v * v
        var rms_scale = Float32(1.0) / sqrt(ss / Float32(n) + eps)
        for i in range(n):
            var want = xs[r * n + i] * rms_scale * gs[i]
            var d = _abs32(gy.unsafe_load(r * n + i) - want)
            if d > max_abs:
                max_abs = d
    VulkanBuffers.unmap(y_alloc)
    VulkanBuffers.free(x_alloc)
    VulkanBuffers.free(g_alloc)
    VulkanBuffers.free(y_alloc)
    print(
        "A060_RMSNORM rows=", rows, " n=", n, " scale=", scale,
        " eps=", eps, " cpu_oracle_max_abs=", max_abs,
    )
    return max_abs


def test_vulkan_rmsnorm_oracle_parity() raises:
    print("--- Testing Vulkan RMSNorm oracle parity (A-060) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: RMSNorm parity not run (honest-absent)")
        return
    var eps = Float32(1e-5)
    var worst: Float32 = 0.0
    var shapes_r = [1, 4, 13, 3, 2, 37, 1]
    var shapes_n = [64, 256, 37, 255, 257, 320, 4096]
    for s in range(len(shapes_r)):
        var m = _rmsnorm_parity(shapes_r[s], shapes_n[s], Float32(3.0), eps)
        if m > worst:
            worst = m
    # Large-magnitude row: RMSNorm is scale-invariant, so the
    # delta must stay on the same bound at scale 1000.
    var m_big = _rmsnorm_parity(2, 512, Float32(1000.0), eps)
    if m_big > worst:
        worst = m_big
    # Zero row and constant row: a zero row normalizes to exact
    # zeros (0 * rsqrt(0 + eps) * g), a constant row to g * sign
    # pattern of the constant over its own magnitude.
    var zx = VulkanBuffers.allocate(2 * 128 * 4)
    var zg = VulkanBuffers.allocate(128 * 4)
    var zy = VulkanBuffers.allocate(2 * 128 * 4)
    var pz = VulkanBuffers.map(zx)
    var fz = pz.unsafe_bitcast[Float32]()
    for i in range(128):
        fz.unsafe_store(i, Float32(0.0))
        fz.unsafe_store(128 + i, Float32(-2.5))
    VulkanBuffers.unmap(zx)
    var pg2 = VulkanBuffers.map(zg)
    var fg2 = pg2.unsafe_bitcast[Float32]()
    for i in range(128):
        fg2.unsafe_store(i, Float32(0.75))
    VulkanBuffers.unmap(zg)
    VulkanNormRope.rmsnorm(zx, zg, zy, 128, 2, eps)
    var qz = VulkanBuffers.map(zy)
    var gz2 = qz.unsafe_bitcast[Float32]()
    for i in range(128):
        if gz2.unsafe_load(i) != Float32(0.0):
            raise Error("RMSNorm zero row produced a nonzero output")
        var d = _abs32(gz2.unsafe_load(128 + i) - Float32(-0.75))
        if d > Float32(0.0001):
            raise Error("RMSNorm constant row mismatch: delta " + String(d))
    VulkanBuffers.unmap(zy)
    VulkanBuffers.free(zx)
    VulkanBuffers.free(zg)
    VulkanBuffers.free(zy)
    # Filed A-060 bound: accumulation-order + fp32 sqrt only
    # (GPU tree vs CPU sequential, both Float32). Measured
    # worst is filed in hidden_files/A060_LEDGER.md; the bound
    # carries headroom over it.
    if worst > Float32(0.001):
        raise Error(
            "RMSNorm oracle parity exceeded filed bound: max_abs "
            + String(worst)
        )
    print(
        "Vulkan RMSNorm oracle parity (7 shapes + scale-1000 +"
        " zero/constant rows, RADV device, worst max_abs=", worst, "): PASS",
    )


def test_vulkan_rmsnorm_known_value() raises:
    print("--- Testing Vulkan RMSNorm known value (A-060) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: known-value case not run (honest-absent)")
        return
    # x = [3, 4], eps = 3.5: mean(x^2) = 12.5, 12.5 + 3.5 = 16,
    # rsqrt = 1/4 exactly (dyadic throughout). g = [2, 0.5]
    # gives y = [3 * 0.25 * 2, 4 * 0.25 * 0.5] = [1.5, 0.5].
    var x_alloc = VulkanBuffers.allocate(2 * 4)
    var g_alloc = VulkanBuffers.allocate(2 * 4)
    var y_alloc = VulkanBuffers.allocate(2 * 4)
    var px = VulkanBuffers.map(x_alloc)
    var fx = px.unsafe_bitcast[Float32]()
    fx.unsafe_store(0, Float32(3.0))
    fx.unsafe_store(1, Float32(4.0))
    VulkanBuffers.unmap(x_alloc)
    var pg = VulkanBuffers.map(g_alloc)
    var fg = pg.unsafe_bitcast[Float32]()
    fg.unsafe_store(0, Float32(2.0))
    fg.unsafe_store(1, Float32(0.5))
    VulkanBuffers.unmap(g_alloc)
    VulkanNormRope.rmsnorm(x_alloc, g_alloc, y_alloc, 2, 1, Float32(3.5))
    var qy = VulkanBuffers.map(y_alloc)
    var gy = qy.unsafe_bitcast[Float32]()
    var d0 = _abs32(gy.unsafe_load(0) - Float32(1.5))
    var d1 = _abs32(gy.unsafe_load(1) - Float32(0.5))
    VulkanBuffers.unmap(y_alloc)
    VulkanBuffers.free(x_alloc)
    VulkanBuffers.free(g_alloc)
    VulkanBuffers.free(y_alloc)
    if d0 > Float32(0.000001) or d1 > Float32(0.000001):
        raise Error(
            "RMSNorm known-value mismatch: deltas " + String(d0)
            + ", " + String(d1) + " want [1.5, 0.5]"
        )
    print("Vulkan RMSNorm known value (x=[3,4], eps=3.5, g=[2,0.5] -> [1.5, 0.5]): PASS")


def _rope_parity(head_dim: Int, rows: Int, position: Int, base: Float32) raises -> Float32:
    """One shape vs the sequential CPU oracle (rotate-half);
    returns the max abs delta observed (also printed)."""
    var x_alloc = VulkanBuffers.allocate(rows * head_dim * 4)
    var lcg = _Lcg(0xA061)
    var xs = List[Float32]()
    for _ in range(rows * head_dim):
        xs.append(lcg.unit() * Float32(6.0) - Float32(3.0))
    var px = VulkanBuffers.map(x_alloc)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(rows * head_dim):
        fx.unsafe_store(i, xs[i])
    VulkanBuffers.unmap(x_alloc)
    VulkanNormRope.rope(x_alloc, head_dim, rows, position, base)
    var qx = VulkanBuffers.map(x_alloc)
    var gx = qx.unsafe_bitcast[Float32]()
    var half = head_dim // 2
    var max_abs: Float32 = 0.0
    for r in range(rows):
        for i in range(half):
            var freq = base ** (Float32(-2 * i) / Float32(head_dim))
            var ang = Float32(position) * freq
            var c = cos(ang)
            var s = sin(ang)
            var a = xs[r * head_dim + i]
            var b = xs[r * head_dim + i + half]
            var want0 = a * c - b * s
            var want1 = b * c + a * s
            var d0 = _abs32(gx.unsafe_load(r * head_dim + i) - want0)
            var d1 = _abs32(gx.unsafe_load(r * head_dim + i + half) - want1)
            if d0 > max_abs:
                max_abs = d0
            if d1 > max_abs:
                max_abs = d1
    VulkanBuffers.unmap(x_alloc)
    VulkanBuffers.free(x_alloc)
    print(
        "A060_ROPE head_dim=", head_dim, " rows=", rows,
        " position=", position, " cpu_oracle_max_abs=", max_abs,
    )
    return max_abs


def test_vulkan_rope_oracle_parity() raises:
    print("--- Testing Vulkan RoPE oracle parity (A-060) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: RoPE parity not run (honest-absent)")
        return
    var base = Float32(10000.0)
    var worst: Float32 = 0.0
    var dims = [64, 128, 32, 256, 64, 128]
    var rows_l = [4, 2, 13, 1, 1, 3]
    var poss = [1, 7, 128, 3, 1000, 0]
    for s in range(len(dims)):
        var m = _rope_parity(dims[s], rows_l[s], poss[s], base)
        if m > worst:
            worst = m
    # Filed A-060 bound: fp32 pow/cos/sin disagreement between
    # RADV and the host libm on angles up to 1000 radians, plus
    # one multiply-add of rounding per output. Measured worst
    # is filed in hidden_files/A060_LEDGER.md.
    if worst > Float32(0.001):
        raise Error(
            "RoPE oracle parity exceeded filed bound: max_abs "
            + String(worst)
        )
    print(
        "Vulkan RoPE oracle parity (6 shapes, head_dim 32..256,"
        " positions 0..1000, RADV device, worst max_abs=", worst, "): PASS",
    )


def test_vulkan_rope_known_properties() raises:
    print("--- Testing Vulkan RoPE known properties (A-060) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: RoPE properties not run (honest-absent)")
        return
    var head_dim = 64
    var rows = 3
    var x_alloc = VulkanBuffers.allocate(rows * head_dim * 4)
    var lcg = _Lcg(0xA062)
    var xs = List[Float32]()
    for _ in range(rows * head_dim):
        xs.append(lcg.unit() * Float32(4.0) - Float32(2.0))
    var px = VulkanBuffers.map(x_alloc)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(rows * head_dim):
        fx.unsafe_store(i, xs[i])
    VulkanBuffers.unmap(x_alloc)
    # Position 0 is an exact identity: every angle is 0, so
    # cos = 1 and sin = 0 on any conformant device.
    VulkanNormRope.rope(x_alloc, head_dim, rows, 0, Float32(10000.0))
    var qx = VulkanBuffers.map(x_alloc)
    var gx = qx.unsafe_bitcast[Float32]()
    for i in range(rows * head_dim):
        if gx.unsafe_load(i) != xs[i]:
            raise Error("RoPE position 0 was not an exact identity")
    VulkanBuffers.unmap(x_alloc)
    # Rotation preserves every pair's squared norm:
    # out0^2 + out1^2 == a^2 + b^2 up to fp32 rounding.
    VulkanNormRope.rope(x_alloc, head_dim, rows, 5, Float32(10000.0))
    var rx = VulkanBuffers.map(x_alloc)
    var gr = rx.unsafe_bitcast[Float32]()
    var half = head_dim // 2
    for r in range(rows):
        for i in range(half):
            var a = xs[r * head_dim + i]
            var b = xs[r * head_dim + i + half]
            var o0 = gr.unsafe_load(r * head_dim + i)
            var o1 = gr.unsafe_load(r * head_dim + i + half)
            var want = a * a + b * b
            var got = o0 * o0 + o1 * o1
            var d = _abs32(got - want)
            var tol = want * Float32(0.001) + Float32(0.0001)
            if d > tol:
                raise Error(
                    "RoPE pair-norm not preserved at row " + String(r)
                    + " pair " + String(i) + ": delta " + String(d)
                )
    VulkanBuffers.unmap(x_alloc)
    VulkanBuffers.free(x_alloc)
    print("Vulkan RoPE known properties (position 0 exact identity, pair norms preserved): PASS")


def test_vulkan_rmsnorm_rope_rejection() raises:
    print("--- Testing Vulkan RMSNorm + RoPE rejection (A-060) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: rejection cases not run (honest-absent)")
        return
    var x = VulkanBuffers.allocate(64 * 4)
    var g = VulkanBuffers.allocate(64 * 4)
    var y = VulkanBuffers.allocate(64 * 4)
    var rejected = 0
    try:
        VulkanNormRope.rmsnorm(x, g, y, 0, 1, Float32(1e-5))
    except:
        rejected += 1
    try:
        VulkanNormRope.rmsnorm(x, g, y, 64, 0, Float32(1e-5))
    except:
        rejected += 1
    try:
        VulkanNormRope.rmsnorm(x, g, y, 64, 1, Float32(0.0))
    except:
        rejected += 1
    try:
        VulkanNormRope.rmsnorm(x, g, y, 64, 2, Float32(1e-5))
    except:
        rejected += 1
    try:
        VulkanNormRope.rope(x, 63, 1, 0, Float32(10000.0))
    except:
        rejected += 1
    try:
        VulkanNormRope.rope(x, 0, 1, 0, Float32(10000.0))
    except:
        rejected += 1
    try:
        VulkanNormRope.rope(x, 64, 0, 0, Float32(10000.0))
    except:
        rejected += 1
    try:
        VulkanNormRope.rope(x, 64, 1, -1, Float32(10000.0))
    except:
        rejected += 1
    try:
        VulkanNormRope.rope(x, 256, 1, 0, Float32(10000.0))
    except:
        rejected += 1
    var bogus = VulkanAllocation(9999, 1024 * 1024, 1024 * 1024, 16, 3)
    try:
        VulkanNormRope.rmsnorm(bogus, g, y, 64, 1, Float32(1e-5))
    except:
        rejected += 1
    try:
        VulkanNormRope.rope(bogus, 64, 1, 0, Float32(10000.0))
    except:
        rejected += 1
    VulkanBuffers.free(x)
    VulkanBuffers.free(g)
    VulkanBuffers.free(y)
    if rejected != 11:
        raise Error(
            "RMSNorm/RoPE rejection accepted a bad call: only "
            + String(rejected) + " of 11 rejected"
        )
    print("Vulkan RMSNorm + RoPE rejection (11 cases: zero/odd dims, eps 0, negative position, oversize, bogus id): PASS")


def test_vulkan_rmsnorm_rope_dispatch_evidence() raises:
    print("--- Testing Vulkan RMSNorm + RoPE dispatch evidence (A-060) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: dispatch evidence not run (honest-absent)")
        return
    var rn_before = VulkanNormRope.rmsnorm_dispatch_count()
    var rp_before = VulkanNormRope.rope_dispatch_count()
    var base_bytes = VulkanBuffers.live_bytes()
    var base_count = VulkanBuffers.live_count()
    _ = _rmsnorm_parity(8, 256, Float32(3.0), Float32(1e-5))
    _ = _rmsnorm_parity(8, 256, Float32(3.0), Float32(1e-5))
    _ = _rope_parity(64, 8, 3, Float32(10000.0))
    _ = _rope_parity(64, 8, 3, Float32(10000.0))
    var rn_after = VulkanNormRope.rmsnorm_dispatch_count()
    var rp_after = VulkanNormRope.rope_dispatch_count()
    if rn_after - rn_before != 2:
        raise Error(
            "RMSNorm dispatch counter advanced by "
            + String(rn_after - rn_before) + " for 2 dispatches"
        )
    if rp_after - rp_before != 2:
        raise Error(
            "RoPE dispatch counter advanced by "
            + String(rp_after - rp_before) + " for 2 dispatches"
        )
    if VulkanBuffers.live_bytes() != base_bytes:
        raise Error("RMSNorm/RoPE loop leaked device bytes")
    if VulkanBuffers.live_count() != base_count:
        raise Error("RMSNorm/RoPE loop leaked buffers")
    print(
        "Vulkan RMSNorm + RoPE dispatch evidence (counters +2/+2"
        " for 2+2 dispatches, accounting exact): PASS"
    )
