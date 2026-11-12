"""KV cache in unified memory (A-021): the per-layer K/V cache
allocated from the A-019 unified allocator, addressable by both
CPU and GPU kernels.

Layout/bounds cases pin the [layer][kind][seq][head][dim] offset
math against hand-computed values and prove every out-of-capacity
coordinate fails closed (overflow config, seq == max_seq, bad
kind/head/dim/layer, malformed appends - no wrap, no clamp).

Cross-read cases are byte-exact (Float32 equality on values that
are exactly representable) with REAL device execution asserted the
A-019 way: the HIP shim's counters must show kernel launches
advancing while its memcpy counter stays at exactly zero (the shim
never resolves hipMemcpy), and the Vulkan case asserts the
HOST_CACHED coherent type flags (0xe, no DEVICE_UNCACHED_AMD) on a
RADV STRIX_HALO device (llvmpipe refused by the presence check).
A CPU decode step (query.K scores + argmax + score-weighted V
sum) reads GPU-written KV and matches an independent CPU oracle
recomputed from the pattern formula - the A-004 raw-oracle
pattern: expected values come from the formula, never from the
cache under test. On hosts without the devices the GPU cases pass
as honest-absent fail-closed, exactly as A-019.
"""
from core.kv_unified import (
    KVLayout,
    UnifiedKVCache,
    KVDecodeResult,
    kv_cpu_decode_step,
    KV_KIND_K,
    KV_KIND_V,
)
from core.zero_copy import ZeroCopy, BACKEND_VULKAN_CACHED
from core.hip_memory import HipMemory
from core.vulkan_buffers import VulkanBuffers


def _fa(i: Int) -> Float32:
    return Float32((i * 37 + 11) % 997) * Float32(0.5) - Float32(100.0)


def _fb(i: Int) -> Float32:
    return Float32((i * 91 + 7) % 613) * Float32(0.25) + Float32(3.0)


def _hip_present() -> Bool:
    if not ZeroCopy.hip_available():
        return False
    try:
        return HipMemory.device_count() >= 1
    except:
        return False


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


def _raises_layout(l: Int, h: Int, d: Int, s: Int) -> Bool:
    try:
        var lay = KVLayout(l, h, d, s)
        _ = lay.total_elems()
        return False
    except:
        return True


def test_kv_unified_layout() raises:
    print("--- Testing KV unified layout math (A-021) ---")
    var lay = KVLayout(2, 2, 4, 3)
    if lay.elems_per_token() != 8:
        raise Error("elems_per_token != 8")
    if lay.total_elems() != 96:
        raise Error("total_elems != 96")
    if lay.byte_size() != 384:
        raise Error("byte_size != 384")
    # Hand-computed offsets for [layer][kind][seq][head][dim],
    # per-token stride 8, per-(layer,kind) stride 24, layer stride 48.
    var cases = [
        (0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 3, 3), (0, 0, 0, 1, 0, 4),
        (0, 0, 2, 1, 3, 23), (0, 1, 0, 0, 0, 24), (0, 1, 2, 1, 3, 47),
        (1, 0, 0, 0, 0, 48), (1, 1, 2, 1, 3, 95),
    ]
    for c in cases:
        var got = lay.offset(c[0], c[1], c[2], c[3], c[4])
        if got != c[5]:
            raise Error(
                "offset mismatch: got " + String(got) + " want "
                + String(c[5])
            )
    # Token bases are aligned to the per-token stride; K and V of the
    # same (layer, seq) are exactly max_seq*per elements apart.
    for layer in range(2):
        for seq in range(3):
            var kb = lay.token_offset(layer, KV_KIND_K, seq)
            var vb = lay.token_offset(layer, KV_KIND_V, seq)
            if kb % 8 != 0 or vb % 8 != 0:
                raise Error("token base not aligned to per-token stride")
            if vb - kb != 24:
                raise Error("K/V token separation != max_seq*per")
    # Last valid coordinate is the final element; geometry is strict.
    if lay.offset(1, 1, 2, 1, 3) != lay.total_elems() - 1:
        raise Error("last coordinate is not the final element")
    print("KV unified layout (offsets/K-V separation/alignment): PASS")


def test_kv_unified_bounds() raises:
    print("--- Testing KV unified bounds fail-closed (A-021) ---")
    var lay = KVLayout(2, 2, 4, 3)
    var bad = 0
    # Each tuple must raise from offset(): layer==L, kind==2, kind<0,
    # seq==max_seq (one past capacity), seq<0 (misaligned/negative),
    # head==H, dim==D, dim<0.
    var coords = [
        (2, 0, 0, 0, 0), (0, 2, 0, 0, 0), (0, -1, 0, 0, 0),
        (0, 0, 3, 0, 0), (0, 0, -1, 0, 0), (0, 0, 0, 2, 0),
        (0, 0, 0, 0, 4), (0, 0, 0, 0, -1), (-1, 0, 0, 0, 0),
    ]
    for c in coords:
        try:
            _ = lay.offset(c[0], c[1], c[2], c[3], c[4])
        except:
            bad += 1
    if bad != len(coords):
        raise Error("some out-of-range coordinates were admitted")
    # Constructor rejections: zero/negative dims and overflow.
    if not _raises_layout(0, 2, 4, 3):
        raise Error("zero layers accepted")
    if not _raises_layout(2, 0, 4, 3):
        raise Error("zero heads accepted")
    if not _raises_layout(2, 2, 0, 3):
        raise Error("zero head_dim accepted")
    if not _raises_layout(2, 2, 4, 0):
        raise Error("zero max_seq accepted")
    if not _raises_layout(2, 2, 4, -5):
        raise Error("negative max_seq accepted")
    if not _raises_layout(100000, 100000, 100000, 100000):
        raise Error("overflowing geometry accepted (would wrap)")
    if not _raises_layout(3037000500, 3037000500, 4, 4):
        raise Error("overflowing layers*heads accepted")
    print("KV unified bounds (9 coords + 7 geometries rejected): PASS")


def test_kv_unified_gpu_write_cpu_read() raises:
    print("--- Testing KV GPU-write CPU-read + decode (A-021) ---")
    if not _hip_present():
        var rejected = False
        try:
            var c = UnifiedKVCache.allocate_default(KVLayout(1, 1, 4, 2))
            c.free()
        except:
            rejected = True
        if not rejected:
            raise Error("HIP unavailable but KV allocate succeeded")
        print("HIP UNAVAILABLE: KV fail-closed: PASS (honest-absent)")
        return
    var lay = KVLayout(3, 4, 16, 64)
    var cache = UnifiedKVCache.allocate_default(lay)
    var c0 = ZeroCopy.counters()
    cache.gpu_fill_all()
    var c1 = ZeroCopy.counters()
    if c1.hip_kernel_launches <= c0.hip_kernel_launches:
        cache.free()
        raise Error("no HIP kernel launch recorded for KV fill")
    if c1.hip_memcpy_calls != 0:
        cache.free()
        raise Error("memcpy counter moved on the KV zero-copy path")
    # Byte-exact: EVERY element, read through layout coordinates,
    # equals the pattern at its flat layout offset.
    for layer in range(3):
        for kind in range(2):
            for seq in range(64):
                for head in range(4):
                    for d in range(16):
                        var off = lay.offset(layer, kind, seq, head, d)
                        var got = cache.read(layer, kind, seq, head, d)
                        if got != _fa(off):
                            cache.free()
                            raise Error(
                                "KV GPU-write mismatch at off "
                                + String(off)
                            )
    # CPU decode step over GPU-written KV (layer 1, head 2), oracle
    # recomputed from the formula alone, bit-exact.
    var query = List[Float32]()
    for d in range(16):
        query.append(Float32((d * 13 + 5) % 29) * Float32(0.125))
    var res = kv_cpu_decode_step(cache, 1, 2, query, 64)
    var best = Float32(-3.4028235e38)
    var best_seq = 0
    var exp_out = List[Float32]()
    for _ in range(16):
        exp_out.append(Float32(0.0))
    for s in range(64):
        var score = Float32(0.0)
        for d in range(16):
            var koff = lay.offset(1, KV_KIND_K, s, 2, d)
            score += query[d] * _fa(koff)
        if score > best:
            best = score
            best_seq = s
        for d in range(16):
            var voff = lay.offset(1, KV_KIND_V, s, 2, d)
            exp_out[d] += score * _fa(voff)
    cache.free()
    if res.argmax_seq != best_seq or res.best_score != best:
        raise Error("decode argmax/score mismatch vs formula oracle")
    for d in range(16):
        if res.output[d] != exp_out[d]:
            raise Error("decode output mismatch vs formula oracle")
    print(
        "KV GPU kernel write -> CPU read (24576 elems byte-exact) +"
        " CPU decode step vs formula oracle (argmax seq "
        + String(best_seq) + ", bit-exact): PASS"
    )


def test_kv_unified_cpu_write_gpu_read() raises:
    print("--- Testing KV CPU-write GPU-read reverse (A-021) ---")
    if not _hip_present():
        print("HIP UNAVAILABLE: reverse case not run (honest-absent)")
        return
    var lay = KVLayout(2, 2, 8, 32)
    var src = UnifiedKVCache.allocate_default(lay)
    var dst = UnifiedKVCache.allocate_default(lay)
    # CPU writes every KV element through layout coordinates.
    for layer in range(2):
        for kind in range(2):
            for seq in range(32):
                for head in range(2):
                    for d in range(8):
                        var off = lay.offset(layer, kind, seq, head, d)
                        src.write(layer, kind, seq, head, d, _fb(off))
    var c0 = ZeroCopy.counters()
    src.gpu_transform_to(dst)
    var c1 = ZeroCopy.counters()
    if c1.hip_kernel_launches <= c0.hip_kernel_launches:
        src.free()
        dst.free()
        raise Error("no HIP kernel launch recorded for KV transform")
    if c1.hip_memcpy_calls != 0:
        src.free()
        dst.free()
        raise Error("memcpy counter moved on the reverse path")
    # GPU read the CPU-written KV: dst must equal src*2+1 everywhere.
    for layer in range(2):
        for kind in range(2):
            for seq in range(32):
                for head in range(2):
                    for d in range(8):
                        var off = lay.offset(layer, kind, seq, head, d)
                        var got = dst.read(layer, kind, seq, head, d)
                        var want = _fb(off) * Float32(2.0) + Float32(1.0)
                        if got != want:
                            src.free()
                            dst.free()
                            raise Error(
                                "KV CPU-write GPU-read mismatch at off "
                                + String(off)
                            )
    src.free()
    dst.free()
    print(
        "KV CPU write -> GPU kernel read/transform -> CPU verify"
        " (2048 elems byte-exact, memcpy = 0): PASS"
    )


def test_kv_unified_append_roundtrip() raises:
    print("--- Testing KV append/read roundtrip + edges (A-021) ---")
    if not _hip_present():
        print("HIP UNAVAILABLE: append case not run (honest-absent)")
        return
    var lay = KVLayout(2, 2, 4, 5)
    var cache = UnifiedKVCache.allocate_default(lay)
    var per = lay.elems_per_token()
    for layer in range(2):
        for seq in range(5):
            var kv = List[Float32]()
            var vv = List[Float32]()
            for i in range(per):
                kv.append(_fb(layer * 1000 + seq * 100 + i))
                vv.append(_fa(layer * 2000 + seq * 100 + i))
            cache.append_token(layer, seq, kv, vv)
    for layer in range(2):
        for seq in range(5):
            var k = cache.read_token(layer, KV_KIND_K, seq)
            var v = cache.read_token(layer, KV_KIND_V, seq)
            for i in range(per):
                if k[i] != _fb(layer * 1000 + seq * 100 + i):
                    cache.free()
                    raise Error("append K roundtrip mismatch")
                if v[i] != _fa(layer * 2000 + seq * 100 + i):
                    cache.free()
                    raise Error("append V roundtrip mismatch")
    # Edges fail closed: append at seq == max_seq, bad vector length,
    # decode with seq_len beyond capacity, decode with bad query.
    var good = List[Float32]()
    for _ in range(per):
        good.append(Float32(1.0))
    var edge = 0
    try:
        cache.append_token(0, 5, good, good)
    except:
        edge += 1
    var short = List[Float32]()
    short.append(Float32(1.0))
    try:
        cache.append_token(0, 0, short, good)
    except:
        edge += 1
    try:
        _ = kv_cpu_decode_step(cache, 0, 0, good, 6)
    except:
        edge += 1
    try:
        _ = kv_cpu_decode_step(cache, 0, 0, short, 3)
    except:
        edge += 1
    cache.free()
    if edge != 4:
        raise Error("an append/decode edge was admitted")
    print("KV append roundtrip (byte-exact) + 4 edges rejected: PASS")


def test_kv_unified_vulkan_shared() raises:
    print("--- Testing KV Vulkan HOST_CACHED sharing (A-021) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: KV case not run (honest-absent)")
        return
    var lay = KVLayout(2, 2, 8, 16)
    var total = lay.total_elems()
    var a = UnifiedKVCache.allocate(lay, BACKEND_VULKAN_CACHED)
    var b = UnifiedKVCache.allocate(lay, BACKEND_VULKAN_CACHED)
    var c = UnifiedKVCache.allocate(lay, BACKEND_VULKAN_CACHED)
    var flags = VulkanBuffers.buffer_type_flags(a.buffer.vk)
    if flags != 0xE:
        a.free()
        b.free()
        c.free()
        raise Error(
            "KV Vulkan type flags != 0xe (HOST_CACHED coherent): "
            + String(flags)
        )
    # CPU writes KV coordinates in a/b; GPU vec_add reads them.
    for layer in range(2):
        for kind in range(2):
            for seq in range(16):
                for head in range(2):
                    for d in range(8):
                        var off = lay.offset(layer, kind, seq, head, d)
                        a.write(layer, kind, seq, head, d, _fa(off))
                        b.write(layer, kind, seq, head, d, _fb(off))
                        c.write(layer, kind, seq, head, d, Float32(-9999.0))
    var k0 = ZeroCopy.counters()
    ZeroCopy.vk_vec_add(a.buffer, b.buffer, c.buffer, total)
    var k1 = ZeroCopy.counters()
    if k1.vk_copy_calls != 0 or k1.vk_copy_calls != k0.vk_copy_calls:
        a.free()
        b.free()
        c.free()
        raise Error("Vulkan copy counter moved on the KV path")
    for layer in range(2):
        for kind in range(2):
            for seq in range(16):
                for head in range(2):
                    for d in range(8):
                        var off = lay.offset(layer, kind, seq, head, d)
                        var got = c.read(layer, kind, seq, head, d)
                        if got != _fa(off) + _fb(off):
                            a.free()
                            b.free()
                            c.free()
                            raise Error(
                                "KV Vulkan cross-read mismatch at off "
                                + String(off)
                            )
    a.free()
    b.free()
    c.free()
    print(
        "KV Vulkan HOST_CACHED (flags 0xe) CPU write -> GPU vec_add"
        " -> CPU read (1024 elems byte-exact, copy calls = 0): PASS"
    )
