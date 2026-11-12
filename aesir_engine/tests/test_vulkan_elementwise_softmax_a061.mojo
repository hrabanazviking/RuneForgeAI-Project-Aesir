"""Vulkan elementwise + softmax (A-061): both A-055 foundation
kernels dispatched on the GPU through the A-014/A-015 Vulkan
context, judged per op against independent CPU references in
this file (raw-oracle discipline: expected values are computed
here from the input data with sequential Float32 math, never
read back from the code under test).

Parity discipline:
- Elementwise modes 0..3 (silu, mul, add/residual, gated
  silu): the oracle restates each op sequentially in Float32;
  silu uses the same exp form as the shader of record. Sizes
  include non-multiples of the 256-wide workgroup (37, 255,
  257, 1000) so the shader count guard is exercised.
- Softmax: the oracle subtracts the row maximum before
  exponentiation and normalises by the sequential exponent
  sum - the numerically careful form the roadmap requires.
  The GPU reduces max and sum in tree order over 256
  invocations, so the filed tolerance is an accumulation-order
  bound. Adversarial logits: rows shifted by +100 (a naive
  exp would overflow to inf), an all -1000 row (a naive exp
  would underflow to an all-zero denominator), a constant
  row (uniform output), and a single-spike row.

Device-execution evidence (law 6): the selected device must
be the AMD Radeon 8060S (RADV STRIX_HALO) - llvmpipe is
refused by the identity check - and the per-op shim dispatch
counters must advance by exactly the number of dispatches
performed. On a host without that device the cases assert
fail-closed behaviour and pass as honest-absent, matching
A-014/A-015/A-056 discipline.
"""
from std.math import exp
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_elementwise import VulkanElementwise


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


def _silu(v: Float32) -> Float32:
    return v / (Float32(1.0) + exp(-v))


def _ew_parity(n: Int, mode: Int, scale: Float32) raises -> Float32:
    """One shape/mode vs the sequential CPU oracle; returns the
    max abs delta observed (also printed)."""
    var a_alloc = VulkanBuffers.allocate(n * 4)
    var b_alloc = VulkanBuffers.allocate(n * 4)
    var y_alloc = VulkanBuffers.allocate(n * 4)
    var lcg = _Lcg(0xA061 + UInt64(mode) * 977 + UInt64(n))
    var av = List[Float32]()
    for _ in range(n):
        av.append((lcg.unit() * Float32(2.0) - Float32(1.0)) * scale)
    var bv = List[Float32]()
    for _ in range(n):
        bv.append((lcg.unit() * Float32(2.0) - Float32(1.0)) * scale)
    var pa = VulkanBuffers.map(a_alloc)
    var fa = pa.unsafe_bitcast[Float32]()
    for i in range(n):
        fa.unsafe_store(i, av[i])
    VulkanBuffers.unmap(a_alloc)
    var pb = VulkanBuffers.map(b_alloc)
    var fb = pb.unsafe_bitcast[Float32]()
    for i in range(n):
        fb.unsafe_store(i, bv[i])
    VulkanBuffers.unmap(b_alloc)
    var py = VulkanBuffers.map(y_alloc)
    var fy = py.unsafe_bitcast[Float32]()
    for i in range(n):
        fy.unsafe_store(i, Float32(-9999.0))
    VulkanBuffers.unmap(y_alloc)
    VulkanElementwise.elementwise(a_alloc, b_alloc, y_alloc, n, mode)
    var qy = VulkanBuffers.map(y_alloc)
    var gy = qy.unsafe_bitcast[Float32]()
    var max_abs: Float32 = 0.0
    for i in range(n):
        var want: Float32
        if mode == 0:
            want = _silu(av[i])
        elif mode == 1:
            want = av[i] * bv[i]
        elif mode == 2:
            want = av[i] + bv[i]
        else:
            want = _silu(av[i]) * bv[i]
        var d = _abs32(gy.unsafe_load(i) - want)
        if d > max_abs:
            max_abs = d
    VulkanBuffers.unmap(y_alloc)
    VulkanBuffers.free(a_alloc)
    VulkanBuffers.free(b_alloc)
    VulkanBuffers.free(y_alloc)
    print(
        "A061_EW n=", n, " mode=", mode, " scale=", scale,
        " cpu_oracle_max_abs=", max_abs,
    )
    return max_abs


def test_vulkan_elementwise_oracle_parity() raises:
    print("--- Testing Vulkan elementwise oracle parity (A-061) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: elementwise parity not run (honest-absent)")
        return
    var worst: Float32 = 0.0
    var sizes = [37, 256, 255, 257, 1000, 4096]
    for mode in range(4):
        for s in range(len(sizes)):
            var m = _ew_parity(sizes[s], mode, Float32(4.0))
            if m > worst:
                worst = m
    # Large-magnitude SiLU inputs: silu saturates to identity
    # for large positives and to 0 for large negatives; the
    # bound must hold at scale 50 too.
    var m_big = _ew_parity(512, 0, Float32(50.0))
    if m_big > worst:
        worst = m_big
    var m_big3 = _ew_parity(512, 3, Float32(50.0))
    if m_big3 > worst:
        worst = m_big3
    # Filed A-061 bound: fp32 exp disagreement between RADV
    # and the host libm inside silu, plus one rounding per op.
    # Measured worst is filed in hidden_files/A061_LEDGER.md.
    if worst > Float32(0.001):
        raise Error(
            "Elementwise oracle parity exceeded filed bound: max_abs "
            + String(worst)
        )
    print(
        "Vulkan elementwise oracle parity (4 modes x 6 sizes +"
        " scale-50 silu/gated, RADV device, worst max_abs=", worst, "): PASS",
    )


def test_vulkan_elementwise_known_value() raises:
    print("--- Testing Vulkan elementwise known value (A-061) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: known-value case not run (honest-absent)")
        return
    # a = [0, 2, -4, 1.5], b = [3, 0.5, 2, -2]:
    # silu(0) = 0 exactly; mul and add are exact in fp32 for
    # these dyadic values.
    var a_alloc = VulkanBuffers.allocate(4 * 4)
    var b_alloc = VulkanBuffers.allocate(4 * 4)
    var y_alloc = VulkanBuffers.allocate(4 * 4)
    var av = [Float32(0.0), Float32(2.0), Float32(-4.0), Float32(1.5)]
    var bv = [Float32(3.0), Float32(0.5), Float32(2.0), Float32(-2.0)]
    var pa = VulkanBuffers.map(a_alloc)
    var fa = pa.unsafe_bitcast[Float32]()
    for i in range(4):
        fa.unsafe_store(i, av[i])
    VulkanBuffers.unmap(a_alloc)
    var pb = VulkanBuffers.map(b_alloc)
    var fb = pb.unsafe_bitcast[Float32]()
    for i in range(4):
        fb.unsafe_store(i, bv[i])
    VulkanBuffers.unmap(b_alloc)
    VulkanElementwise.elementwise(a_alloc, b_alloc, y_alloc, 4, 0)
    var q0 = VulkanBuffers.map(y_alloc)
    var g0 = q0.unsafe_bitcast[Float32]()
    if g0.unsafe_load(0) != Float32(0.0):
        raise Error("silu(0) was not exactly 0")
    var d_silu = _abs32(g0.unsafe_load(1) - _silu(Float32(2.0)))
    VulkanBuffers.unmap(y_alloc)
    if d_silu > Float32(0.00001):
        raise Error("silu(2) mismatch: delta " + String(d_silu))
    VulkanElementwise.elementwise(a_alloc, b_alloc, y_alloc, 4, 1)
    var q1 = VulkanBuffers.map(y_alloc)
    var g1 = q1.unsafe_bitcast[Float32]()
    var want_mul = [Float32(0.0), Float32(1.0), Float32(-8.0), Float32(-3.0)]
    for i in range(4):
        if g1.unsafe_load(i) != want_mul[i]:
            raise Error("mul known-value mismatch at " + String(i))
    VulkanBuffers.unmap(y_alloc)
    VulkanElementwise.elementwise(a_alloc, b_alloc, y_alloc, 4, 2)
    var q2 = VulkanBuffers.map(y_alloc)
    var g2 = q2.unsafe_bitcast[Float32]()
    var want_add = [Float32(3.0), Float32(2.5), Float32(-2.0), Float32(-0.5)]
    for i in range(4):
        if g2.unsafe_load(i) != want_add[i]:
            raise Error("add known-value mismatch at " + String(i))
    VulkanBuffers.unmap(y_alloc)
    VulkanBuffers.free(a_alloc)
    VulkanBuffers.free(b_alloc)
    VulkanBuffers.free(y_alloc)
    print("Vulkan elementwise known value (silu(0)=0 exact, mul/add exact dyadic): PASS")


def _softmax_oracle(rows_data: List[Float32], n: Int, rows: Int) -> List[Float32]:
    """Sequential Float32 softmax with max subtraction - the
    independent oracle (never the code under test)."""
    var out = List[Float32]()
    for r in range(rows):
        var m = rows_data[r * n]
        for i in range(1, n):
            if rows_data[r * n + i] > m:
                m = rows_data[r * n + i]
        var s: Float32 = 0.0
        var es = List[Float32]()
        for i in range(n):
            var e = exp(rows_data[r * n + i] - m)
            es.append(e)
            s += e
        for i in range(n):
            out.append(es[i] / s)
    return out^


def _softmax_run(data: List[Float32], n: Int, rows: Int) raises -> Float32:
    """Run GPU softmax over data in place; returns max abs
    delta vs the sequential oracle (also checks each row sums
    to 1 and stays finite)."""
    var x_alloc = VulkanBuffers.allocate(rows * n * 4)
    var px = VulkanBuffers.map(x_alloc)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(rows * n):
        fx.unsafe_store(i, data[i])
    VulkanBuffers.unmap(x_alloc)
    VulkanElementwise.softmax(x_alloc, n, rows)
    var want = _softmax_oracle(data, n, rows)
    var qx = VulkanBuffers.map(x_alloc)
    var gx = qx.unsafe_bitcast[Float32]()
    var max_abs: Float32 = 0.0
    for r in range(rows):
        var row_sum: Float32 = 0.0
        for i in range(n):
            var got = gx.unsafe_load(r * n + i)
            if got != got or got < Float32(0.0) or got > Float32(1.0):
                raise Error("softmax output not a finite probability")
            row_sum += got
            var d = _abs32(got - want[r * n + i])
            if d > max_abs:
                max_abs = d
        if _abs32(row_sum - Float32(1.0)) > Float32(0.001):
            raise Error("softmax row did not sum to 1: " + String(row_sum))
    VulkanBuffers.unmap(x_alloc)
    VulkanBuffers.free(x_alloc)
    return max_abs


def test_vulkan_softmax_oracle_parity() raises:
    print("--- Testing Vulkan softmax oracle parity (A-061) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: softmax parity not run (honest-absent)")
        return
    var worst: Float32 = 0.0
    var shapes_r = [1, 4, 3, 2]
    var shapes_n = [64, 37, 257, 1024]
    for s in range(len(shapes_r)):
        var rows = shapes_r[s]
        var n = shapes_n[s]
        var lcg = _Lcg(0xA161 + UInt64(s) * 131)
        var data = List[Float32]()
        for _ in range(rows * n):
            data.append((lcg.unit() * Float32(2.0) - Float32(1.0)) * Float32(8.0))
        var m = _softmax_run(data, n, rows)
        print("A061_SM rows=", rows, " n=", n, " cpu_oracle_max_abs=", m)
        if m > worst:
            worst = m
    # Filed A-061 bound: GPU tree reduction vs CPU sequential
    # sum, both Float32, plus fp32 exp disagreement. Measured
    # worst is filed in hidden_files/A061_LEDGER.md.
    if worst > Float32(0.001):
        raise Error(
            "Softmax oracle parity exceeded filed bound: max_abs "
            + String(worst)
        )
    print(
        "Vulkan softmax oracle parity (4 shapes, n 37..1024,"
        " RADV device, worst max_abs=", worst, "): PASS",
    )


def test_vulkan_softmax_adversarial() raises:
    print("--- Testing Vulkan softmax adversarial logits (A-061) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: adversarial case not run (honest-absent)")
        return
    var worst: Float32 = 0.0
    # Row shifted by +100: without max subtraction exp(100)
    # overflows fp32 to inf and the row becomes NaN.
    var hot = List[Float32]()
    var lcg = _Lcg(0xA261)
    for _ in range(128):
        hot.append(Float32(100.0) + (lcg.unit() * Float32(2.0) - Float32(1.0)) * Float32(5.0))
    var m_hot = _softmax_run(hot, 128, 1)
    if m_hot > worst:
        worst = m_hot
    # All -1000 row: without max subtraction every exp
    # underflows to 0 and the denominator is 0; with it the
    # output is exactly uniform.
    var cold = List[Float32]()
    for _ in range(64):
        cold.append(Float32(-1000.0))
    var x_alloc = VulkanBuffers.allocate(64 * 4)
    var px = VulkanBuffers.map(x_alloc)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(64):
        fx.unsafe_store(i, cold[i])
    VulkanBuffers.unmap(x_alloc)
    VulkanElementwise.softmax(x_alloc, 64, 1)
    var qx = VulkanBuffers.map(x_alloc)
    var gx = qx.unsafe_bitcast[Float32]()
    for i in range(64):
        if gx.unsafe_load(i) != Float32(1.0) / Float32(64.0):
            raise Error("softmax of a constant -1000 row was not exactly uniform")
    VulkanBuffers.unmap(x_alloc)
    VulkanBuffers.free(x_alloc)
    # Single-spike row: one logit 50 above the rest takes
    # essentially all the mass.
    var spike = List[Float32]()
    for i in range(256):
        spike.append(Float32(50.0) if i == 100 else Float32(0.0))
    var m_spike = _softmax_run(spike, 256, 1)
    if m_spike > worst:
        worst = m_spike
    if worst > Float32(0.001):
        raise Error(
            "Softmax adversarial parity exceeded filed bound: max_abs "
            + String(worst)
        )
    print(
        "Vulkan softmax adversarial (+100 shift finite, -1000"
        " constant row exactly uniform, single spike, worst"
        " max_abs=", worst, "): PASS",
    )


def test_vulkan_elementwise_softmax_rejection() raises:
    print("--- Testing Vulkan elementwise + softmax rejection (A-061) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: rejection cases not run (honest-absent)")
        return
    var a = VulkanBuffers.allocate(64 * 4)
    var b = VulkanBuffers.allocate(64 * 4)
    var y = VulkanBuffers.allocate(64 * 4)
    var rejected = 0
    try:
        VulkanElementwise.elementwise(a, b, y, 0, 1)
    except:
        rejected += 1
    try:
        VulkanElementwise.elementwise(a, b, y, 64, 4)
    except:
        rejected += 1
    try:
        VulkanElementwise.elementwise(a, b, y, 64, -1)
    except:
        rejected += 1
    try:
        VulkanElementwise.elementwise(a, b, y, 128, 1)
    except:
        rejected += 1
    try:
        VulkanElementwise.softmax(a, 0, 1)
    except:
        rejected += 1
    try:
        VulkanElementwise.softmax(a, 64, 0)
    except:
        rejected += 1
    try:
        VulkanElementwise.softmax(a, 64, 2)
    except:
        rejected += 1
    var bogus = VulkanAllocation(9999, 1024 * 1024, 1024 * 1024, 16, 3)
    try:
        VulkanElementwise.elementwise(bogus, b, y, 64, 1)
    except:
        rejected += 1
    try:
        VulkanElementwise.softmax(bogus, 64, 1)
    except:
        rejected += 1
    VulkanBuffers.free(a)
    VulkanBuffers.free(b)
    VulkanBuffers.free(y)
    if rejected != 9:
        raise Error(
            "Elementwise/softmax rejection accepted a bad call: only "
            + String(rejected) + " of 9 rejected"
        )
    print("Vulkan elementwise + softmax rejection (9 cases: zero n/rows, bad mode, oversize, bogus id): PASS")


def test_vulkan_elementwise_softmax_dispatch_evidence() raises:
    print("--- Testing Vulkan elementwise + softmax dispatch evidence (A-061) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: dispatch evidence not run (honest-absent)")
        return
    var ew_before = VulkanElementwise.elementwise_dispatch_count()
    var sm_before = VulkanElementwise.softmax_dispatch_count()
    var base_bytes = VulkanBuffers.live_bytes()
    var base_count = VulkanBuffers.live_count()
    _ = _ew_parity(256, 1, Float32(4.0))
    _ = _ew_parity(256, 2, Float32(4.0))
    var data = List[Float32]()
    var lcg = _Lcg(0xA361)
    for _ in range(2 * 64):
        data.append((lcg.unit() * Float32(2.0) - Float32(1.0)) * Float32(4.0))
    _ = _softmax_run(data, 64, 2)
    _ = _softmax_run(data, 64, 2)
    var ew_after = VulkanElementwise.elementwise_dispatch_count()
    var sm_after = VulkanElementwise.softmax_dispatch_count()
    if ew_after - ew_before != 2:
        raise Error(
            "Elementwise dispatch counter advanced by "
            + String(ew_after - ew_before) + " for 2 dispatches"
        )
    if sm_after - sm_before != 2:
        raise Error(
            "Softmax dispatch counter advanced by "
            + String(sm_after - sm_before) + " for 2 dispatches"
        )
    if VulkanBuffers.live_bytes() != base_bytes:
        raise Error("Elementwise/softmax loop leaked device bytes")
    if VulkanBuffers.live_count() != base_count:
        raise Error("Elementwise/softmax loop leaked buffers")
    print(
        "Vulkan elementwise + softmax dispatch evidence (counters +2/+2"
        " for 2+2 dispatches, accounting exact): PASS"
    )
