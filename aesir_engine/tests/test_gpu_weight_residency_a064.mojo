"""GPU weight residency (A-064): fixture weights resident once
in unified memory, shared with the CPU path (A-020), judged by
live shim accounting.

Acceptance shape (roadmap A-064):
- Single residency: allocating the resident weight buffer adds
  exactly one allocation of exactly alloc_size bytes to the
  shim live accounting, on a DEVICE_LOCAL + HOST_VISIBLE +
  HOST_COHERENT (unified) memory type, with zero upload/copy
  calls - the CPU fills the weights once through the host map.
- Repeated runs do not re-upload: three Q8_0 GEMV dispatches
  against the SAME resident allocation leave live_bytes,
  live_count and upload_call_count byte-identical, while the
  A-056 dispatch counter advances by exactly 3, and every run
  reproduces the sequential Float32 CPU oracle over the same
  raw bytes (raw-oracle discipline, CPU-vs-CPU reference in
  this file, never code under test).
- Shared with the CPU path: a CPU write through the mapped
  pointer (changing one weight scale) is visible to the next
  GPU dispatch with no upload call in between - the new output
  matches the new sequential oracle.
- Multiple resident tensors account as the exact sum of their
  alloc_sizes; freeing one removes exactly its bytes.

Device-execution evidence (law 6): the selected device must be
the AMD Radeon 8060S (RADV STRIX_HALO) - llvmpipe is refused by
the identity check - and the GEMV dispatch counter must
advance. On a host without that device the cases assert
fail-closed behaviour and pass as honest-absent.
"""
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_gemv import VulkanGemv
from core.gpu_weight_residency import GpuWeightResidency

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


comptime _ROWS = 16
comptime _COLS = 256
comptime _WBYTES = _ROWS * (_COLS // 32) * 34

def _fill_weights(w: VulkanAllocation, mut xs: List[Float32]) raises:
    var lcg = _Lcg(0xA064)
    xs.clear()
    for _ in range(_COLS):
        xs.append(lcg.unit() * Float32(3.0) - Float32(1.5))
    var pw = VulkanBuffers.map(w)
    for blk in range(_ROWS * (_COLS // 32)):
        var s = Float32(0.002) + lcg.unit() * Float32(0.018)
        pw.unsafe_bitcast[Float16]().unsafe_store(blk * 17, Float16(s))
        for lane in range(32):
            pw.unsafe_store(blk * 34 + 2 + lane, lcg.byte())
    VulkanBuffers.unmap(w)


def _oracle(w: VulkanAllocation, xs: List[Float32]) raises -> List[Float32]:
    var out = List[Float32]()
    var qw = VulkanBuffers.map(w)
    for r in range(_ROWS):
        var acc: Float32 = 0.0
        for blk in range(_COLS // 32):
            var base = (r * (_COLS // 32) + blk) * 34
            var scale = qw.unsafe_bitcast[Float16]().unsafe_load(
                (r * (_COLS // 32) + blk) * 17
            ).cast[DType.float32]()
            for lane in range(32):
                var raw = Int(qw.unsafe_load(base + 2 + lane))
                var q = raw - 256 if raw >= 128 else raw
                acc += scale * Float32(q) * xs[blk * 32 + lane]
        out.append(acc)
    VulkanBuffers.unmap(w)
    return out^

def _run_once(
    w: VulkanAllocation, x: VulkanAllocation, xs: List[Float32]
) raises -> List[Float32]:
    var y = VulkanBuffers.allocate(_ROWS * 4)
    var py = VulkanBuffers.map(y)
    var fy = py.unsafe_bitcast[Float32]()
    for i in range(_ROWS):
        fy.unsafe_store(i, Float32(-9999.0))
    VulkanBuffers.unmap(y)
    VulkanGemv.q8_0_gemv(w, x, y, _ROWS, _COLS)
    var out = List[Float32]()
    var qy = VulkanBuffers.map(y)
    var gy = qy.unsafe_bitcast[Float32]()
    for i in range(_ROWS):
        out.append(gy.unsafe_load(i))
    VulkanBuffers.unmap(y)
    VulkanBuffers.free(y)
    return out^


def _make_x(xs: List[Float32]) raises -> VulkanAllocation:
    var x = VulkanBuffers.allocate(_COLS * 4)
    var px = VulkanBuffers.map(x)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(_COLS):
        fx.unsafe_store(i, xs[i])
    VulkanBuffers.unmap(x)
    return x


def _max_delta(a: List[Float32], b: List[Float32]) -> Float32:
    var m: Float32 = 0.0
    for i in range(len(a)):
        var d = a[i] - b[i]
        if d < 0:
            d = -d
        if d > m:
            m = d
    return m

def test_gpu_weight_residency_single() raises:
    print("--- Testing GPU weight residency single residency (A-064) ---")
    if not _vk_present():
        var rejected = False
        try:
            var a = GpuWeightResidency.resident_allocate(4096)
            VulkanBuffers.free(a)
        except:
            rejected = True
        if not rejected:
            raise Error("Vulkan unavailable but resident_allocate succeeded")
        print("Vulkan UNAVAILABLE: residency fail-closed: PASS (honest-absent)")
        return
    var before = GpuWeightResidency.accounting()
    var w = GpuWeightResidency.resident_allocate(_WBYTES)
    var during = GpuWeightResidency.accounting()
    if not GpuWeightResidency.single_residency_delta(before, during, w):
        VulkanBuffers.free(w)
        raise Error("resident allocation is not a single accounted residency")
    if not GpuWeightResidency.is_unified_type(w):
        VulkanBuffers.free(w)
        raise Error("resident weights not on a unified type")
    var flags = VulkanBuffers.buffer_type_flags(w)
    print(
        "A064_SINGLE weight_bytes=", _WBYTES, " alloc_size=", w.alloc_size,
        " type_flags=", flags, " live_delta=", during.live_bytes - before.live_bytes,
        " upload_calls=", during.upload_calls,
    )
    VulkanBuffers.free(w)
    var after = GpuWeightResidency.accounting()
    if not GpuWeightResidency.unchanged(before, after):
        raise Error("freeing the resident buffer did not restore accounting")
    print("GPU weight residency single residency (one alloc, unified type, 0 uploads): PASS")

def test_gpu_weight_residency_no_reupload() raises:
    print("--- Testing GPU weight residency repeated runs (A-064) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: repeated-runs case not run (honest-absent)")
        return
    var xs = List[Float32]()
    var w = GpuWeightResidency.resident_allocate(_WBYTES)
    _fill_weights(w, xs)
    var x = _make_x(xs)
    var want = _oracle(w, xs)
    var base = GpuWeightResidency.accounting()
    var d0 = VulkanGemv.dispatch_count()
    var worst: Float32 = 0.0
    var first = List[Float32]()
    for run in range(3):
        var got = _run_once(w, x, xs)
        if run == 0:
            for v in got:
                first.append(v)
        else:
            var same = _max_delta(got, first)
            if same != Float32(0.0):
                raise Error("repeated run output differs from first run")
        var m = _max_delta(got, want)
        if m > worst:
            worst = m
        var now = GpuWeightResidency.accounting()
        if not GpuWeightResidency.unchanged(base, now):
            raise Error("repeated run changed residency accounting (re-upload?)")
    var d1 = VulkanGemv.dispatch_count()
    VulkanBuffers.free(x)
    VulkanBuffers.free(w)
    if d1 - d0 != 3:
        raise Error("dispatch counter advanced by " + String(d1 - d0) + " for 3 runs")
    if worst > Float32(0.001):
        raise Error("resident GEMV oracle parity exceeded bound: " + String(worst))
    print(
        "A064_REPEAT runs=3 dispatch_delta=3 accounting_unchanged=true",
        " oracle_worst_max_abs=", worst,
    )
    print("GPU weight residency repeated runs do not re-upload: PASS")

def test_gpu_weight_residency_cpu_shared() raises:
    print("--- Testing GPU weight residency CPU-shared visibility (A-064) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: CPU-shared case not run (honest-absent)")
        return
    var xs = List[Float32]()
    var w = GpuWeightResidency.resident_allocate(_WBYTES)
    _fill_weights(w, xs)
    var x = _make_x(xs)
    var before_out = _run_once(w, x, xs)
    var pw = VulkanBuffers.map(w)
    pw.unsafe_bitcast[Float16]().unsafe_store(0, Float16(0.0))
    VulkanBuffers.unmap(w)
    var uploads_before = GpuWeightResidency.upload_call_count()
    var after_out = _run_once(w, x, xs)
    var want = _oracle(w, xs)
    VulkanBuffers.free(x)
    VulkanBuffers.free(w)
    if GpuWeightResidency.upload_call_count() != uploads_before:
        raise Error("an upload/copy call was issued for a CPU-shared write")
    if after_out[0] == before_out[0]:
        raise Error("GPU did not observe the CPU write to resident weights")
    var m = _max_delta(after_out, want)
    if m > Float32(0.001):
        raise Error("post-write GPU output diverged from new oracle: " + String(m))
    print("A064_SHARED cpu_write_visible_to_gpu=true uploads=0 max_abs=", m)
    print("GPU weight residency shared with CPU path (no upload): PASS")

def test_gpu_weight_residency_multi_tensor() raises:
    print("--- Testing GPU weight residency multi-tensor accounting (A-064) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: multi-tensor case not run (honest-absent)")
        return
    var before = GpuWeightResidency.accounting()
    var a = GpuWeightResidency.resident_allocate(_WBYTES)
    var b = GpuWeightResidency.resident_allocate(8192)
    var during = GpuWeightResidency.accounting()
    if during.live_bytes - before.live_bytes != a.alloc_size + b.alloc_size:
        raise Error("two resident tensors do not account as their exact sum")
    if during.live_count - before.live_count != 2:
        raise Error("two resident tensors do not count as exactly two")
    VulkanBuffers.free(a)
    var mid = GpuWeightResidency.accounting()
    if mid.live_bytes - before.live_bytes != b.alloc_size:
        raise Error("freeing one resident tensor removed the wrong bytes")
    VulkanBuffers.free(b)
    var after = GpuWeightResidency.accounting()
    if not GpuWeightResidency.unchanged(before, after):
        raise Error("multi-tensor residency leaked accounting")
    print("GPU weight residency multi-tensor exact-sum accounting: PASS")


def test_gpu_weight_residency_rejection() raises:
    print("--- Testing GPU weight residency rejection (A-064) ---")
    var zero_rejected = False
    try:
        var a = GpuWeightResidency.resident_allocate(0)
        VulkanBuffers.free(a)
    except:
        zero_rejected = True
    if not zero_rejected:
        raise Error("resident_allocate accepted a zero size")
    var neg_rejected = False
    try:
        var a = GpuWeightResidency.resident_allocate(-64)
        VulkanBuffers.free(a)
    except:
        neg_rejected = True
    if not neg_rejected:
        raise Error("resident_allocate accepted a negative size")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: rejection (zero, negative): PASS (honest-absent)")
        return
    var w = GpuWeightResidency.resident_allocate(34)
    var x = VulkanBuffers.allocate(_COLS * 4)
    var y = VulkanBuffers.allocate(_ROWS * 4)
    var undersized = False
    try:
        VulkanGemv.q8_0_gemv(w, x, y, _ROWS, _COLS)
    except:
        undersized = True
    VulkanBuffers.free(w)
    VulkanBuffers.free(x)
    VulkanBuffers.free(y)
    if not undersized:
        raise Error("GEMV accepted an undersized resident weight buffer")
    print("GPU weight residency rejection (zero, negative, undersized): PASS")
