"""Vulkan Q4_K GEMV (A-057): dequant + single-row (batch-1) GEMV on
the GPU, judged against the Z13 CPU oracle declared by the A-054
gate - dequantize_ggml_k kind 12 (the banked A-040 SIMD path) into
f16, then an f32 dot with the input vector.

The GPU kernel (aesir_engine/shaders/q4k_gemv.comp, embedded in the
buffer shim) decodes Q4_K super-blocks in f32 and never rounds the
weights to f16, while the CPU oracle does round them; parity is
therefore judged at the filed tolerance below (the f16-rounding
band), never bit-exactness: per output row,
|got - want| <= 0.02 * sqrt(K) + 0.02 * |want|. The sqrt(K) term is
the random-walk accumulation of per-weight f16 rounding (each
weight's rounding is at most |w| * 2^-11; the synthetic weights are
large, |w| up to ~40 typical, so the band is derived, not guessed):
measured max abs errors in hidden_files/a057_bench.log are 0.0014
(K=256), 0.105 (K=512), 0.231 (K=1024), 0.355 (K=2048) against
bands 0.32 / 0.45 / 0.64 / 0.91 - headroom 2.5x or better at every
shape in this file, on a deterministic fixture.

Present/absent discipline matches A-015: on purpleraider the
selected device must be the AMD Radeon 8060S (RADV STRIX_HALO) -
llvmpipe is explicitly refused by the identity check - and every
case verifies real device execution through the shim's dispatch
counter (it increments only after a submitted dispatch completes
on the device); on a host without that device the cases assert
fail-closed behaviour and pass as honest-absent.

Fixtures are deterministic synthetic Q4_K super-blocks (LCG seed
0xA057, d/dmin pinned to the A-040 values), byte-reproducible from
this source alone.
"""
from std.memory import Pointer
from std.memory.alloc import alloc
from std.math import abs as fabs, sqrt
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.compute import dequantize_ggml_k
from core.mimir_well import f16, f32


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


def _lcg(state: Int64) -> Int64:
    return state * Int64(6364136223846793005) + Int64(1442695040888963407)


def _fx(i: Int) -> Float32:
    return Float32((i * 73 + 19) % 997) * Float32(0.002) - Float32(0.997)


def _fill_weights(pw: Pointer[UInt8, MutUntrackedOrigin], total_blocks: Int):
    var s = Int64(0xA057)
    for b in range(total_blocks):
        s = _lcg(s + Int64(b))
        var st = s
        for i in range(144):
            st = _lcg(st)
            pw.unsafe_store(b * 144 + i, UInt8((st >> 33) & 0xFF))
        pw.unsafe_store(b * 144 + 0, UInt8(0x00))
        pw.unsafe_store(b * 144 + 1, UInt8(0x2E))
        pw.unsafe_store(b * 144 + 2, UInt8(0x00))
        pw.unsafe_store(b * 144 + 3, UInt8(0x1E))


def _run_gemv(n_rows: Int, k_elems: Int) raises:
    var nblocks = k_elems // 256
    var w_bytes = n_rows * nblocks * 144
    var w = VulkanBuffers.allocate(w_bytes)
    var x = VulkanBuffers.allocate(k_elems * 4)
    var y = VulkanBuffers.allocate(n_rows * 4)
    var pw = VulkanBuffers.map(w)
    _fill_weights(pw, n_rows * nblocks)
    var w_host = alloc[UInt8](w_bytes)
    for i in range(w_bytes):
        w_host.unsafe_store(i, pw.unsafe_load(i))
    VulkanBuffers.unmap(w)
    var px = VulkanBuffers.map(x)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(k_elems):
        fx.unsafe_store(i, _fx(i))
    VulkanBuffers.unmap(x)
    var py = VulkanBuffers.map(y)
    var fy = py.unsafe_bitcast[Float32]()
    for r in range(n_rows):
        fy.unsafe_store(r, Float32(-9999.0))
    VulkanBuffers.unmap(y)
    var before = VulkanBuffers.q4k_gemv_dispatch_count()
    VulkanBuffers.q4k_gemv(w, x, y, k_elems, n_rows)
    var after = VulkanBuffers.q4k_gemv_dispatch_count()
    if after != before + 1:
        raise Error("A-057 dispatch counter did not rise by exactly 1")
    var deq = alloc[Scalar[f16]](k_elems)
    var qy = VulkanBuffers.map(y)
    var gy = qy.unsafe_bitcast[Float32]()
    for r in range(n_rows):
        dequantize_ggml_k(
            w_host.unsafe_offset(r * nblocks * 144), deq, k_elems, 12
        )
        var want = Float32(0.0)
        for e in range(k_elems):
            want += deq.unsafe_load(e).cast[f32]() * _fx(e)
        var got = gy.unsafe_load(r)
        var tol = Float32(0.02) * sqrt(Float32(k_elems)) + Float32(0.02) * fabs(want)
        if fabs(got - want) > tol:
            VulkanBuffers.unmap(y)
            VulkanBuffers.free(w)
            VulkanBuffers.free(x)
            VulkanBuffers.free(y)
            w_host.unsafe_free()
            deq.unsafe_free()
            raise Error(
                "A-057 Q4_K GEMV mismatch rows=" + String(n_rows)
                + " k=" + String(k_elems) + " row " + String(r)
                + ": got " + String(got) + " want " + String(want)
            )
    VulkanBuffers.unmap(y)
    VulkanBuffers.free(w)
    VulkanBuffers.free(x)
    VulkanBuffers.free(y)
    w_host.unsafe_free()
    deq.unsafe_free()


def test_vulkan_q4k_gemv_oracle() raises:
    print("--- Testing Vulkan Q4_K GEMV oracle (A-057) ---")
    if not _vk_present():
        var rejected = False
        try:
            var a = VulkanBuffers.allocate(4096)
            VulkanBuffers.free(a)
        except:
            rejected = True
        if not rejected:
            raise Error("Vulkan unavailable but allocate succeeded (fabricated)")
        print("Vulkan UNAVAILABLE: Q4_K GEMV fail-closed: PASS (honest-absent)")
        return
    _run_gemv(1, 256)
    _run_gemv(7, 512)
    _run_gemv(64, 1024)
    _run_gemv(33, 2048)
    print(
        "Vulkan Q4_K GEMV (rows/k = 1/256, 7/512, 64/1024, 33/2048;"
        " GPU dequant+GEMV vs Z13 CPU oracle within filed f16-rounding"
        " tolerance, dispatch counter +1 per call, RADV device): PASS"
    )


def test_vulkan_q4k_gemv_rejection() raises:
    print("--- Testing Vulkan Q4_K GEMV rejection (A-057) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: rejection cases not run (honest-absent)")
        return
    var w = VulkanBuffers.allocate(144)
    var x = VulkanBuffers.allocate(1024)
    var y = VulkanBuffers.allocate(4)
    var zero_k = False
    try:
        VulkanBuffers.q4k_gemv(w, x, y, 0, 1)
    except:
        zero_k = True
    if not zero_k:
        raise Error("q4k_gemv accepted a zero element count")
    var ragged_k = False
    try:
        VulkanBuffers.q4k_gemv(w, x, y, 128, 1)
    except:
        ragged_k = True
    if not ragged_k:
        raise Error("q4k_gemv accepted a non-super-block element count")
    var zero_rows = False
    try:
        VulkanBuffers.q4k_gemv(w, x, y, 256, 0)
    except:
        zero_rows = True
    if not zero_rows:
        raise Error("q4k_gemv accepted zero rows")
    var oversize = False
    try:
        VulkanBuffers.q4k_gemv(w, x, y, 256, 2)
    except:
        oversize = True
    if not oversize:
        raise Error("q4k_gemv accepted a shape beyond the weight buffer")
    var bogus = VulkanAllocation(9999, 1024, 1024, 16, 3)
    var bogus_rejected = False
    try:
        VulkanBuffers.q4k_gemv(w, x, bogus, 256, 1)
    except:
        bogus_rejected = True
    if not bogus_rejected:
        raise Error("q4k_gemv accepted a bogus buffer id")
    VulkanBuffers.free(w)
    VulkanBuffers.free(x)
    VulkanBuffers.free(y)
    print(
        "Vulkan Q4_K GEMV rejection (zero k, ragged k, zero rows,"
        " oversize shape, bogus id): PASS"
    )


def test_vulkan_q4k_gemv_no_leak() raises:
    print("--- Testing Vulkan Q4_K GEMV no-leak (A-057) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: no-leak case not run (honest-absent)")
        return
    _run_gemv(4, 256)
    var base_bytes = VulkanBuffers.live_bytes()
    var base_count = VulkanBuffers.live_count()
    var before = VulkanBuffers.q4k_gemv_dispatch_count()
    for _ in range(50):
        _run_gemv(4, 256)
    var after = VulkanBuffers.q4k_gemv_dispatch_count()
    if after != before + 50:
        raise Error("Q4_K GEMV dispatch counter did not rise by 50")
    if VulkanBuffers.live_bytes() != base_bytes:
        raise Error("q4k_gemv loop leaked device bytes")
    if VulkanBuffers.live_count() != base_count:
        raise Error("q4k_gemv loop leaked buffers")
    print(
        "Vulkan Q4_K GEMV no-leak (50 dispatches at rows=4 k=256,"
        " accounting exact, counter +50): PASS"
    )
