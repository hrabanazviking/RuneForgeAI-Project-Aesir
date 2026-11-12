# core/kv_unified.mojo
# KV cache in unified memory (slice A-021): the per-layer K/V cache
# allocated from the A-019 unified allocator (core/zero_copy), so the
# SAME bytes are addressable by CPU code and by GPU kernels with no
# copy call anywhere in the path (the A-008 zero-copy rule).
#
# Layout (contiguous, Float32 elements):
#   [layer][kind][seq][head][dim]
#   kind 0 = K, 1 = V; seq in [0, max_seq); head in [0, num_heads);
#   dim in [0, head_dim). The offset of a coordinate is
#     (((layer * 2 + kind) * max_seq + seq) * num_heads + head)
#       * head_dim + dim
#   A token's K (or V) vector for (layer, seq) is the contiguous run
#   of num_heads*head_dim elements starting at token_offset().
#
# Fail-closed discipline: the layout constructor validates every
# dimension (positive, checked multiplication - overflow raises,
# never wraps), and every coordinate is admitted through explicit
# bounds checks AND core/checked_span before any pointer arithmetic.
# Sequence positions at or beyond max_seq, negative coordinates,
# out-of-range layers/heads/dims, and malformed append vectors all
# raise; nothing wraps modulo capacity (the historic KV silent-wrap
# bug class, docs/bugs/0026) and nothing is clamped.
#
# Backends are exactly the A-019 ones: HIP managed memory is the
# default (GPU kernels: the zero-copy shim's HIPRTC fill/transform
# launched on the managed pointer directly); the Vulkan backend is
# the HOST_CACHED host-coherent type only. This module builds NO
# second allocator - allocation, mapping, GPU dispatch and the
# copy-call counters all come from core/zero_copy.

from std.memory import Pointer
from core.checked_span import checked_span
from core.zero_copy import (
    ZeroCopy,
    ZeroCopyBuffer,
    BACKEND_HIP_MANAGED,
    BACKEND_VULKAN_CACHED,
)

comptime KV_KIND_K = 0
comptime KV_KIND_V = 1


def _checked_mul(a: Int, b: Int, what: String) raises -> Int:
    if a < 0 or b < 0:
        raise Error("KVLayout: negative factor in " + what)
    if a != 0 and b > 9223372036854775807 // a:
        raise Error("KVLayout: size overflow in " + what)
    return a * b


struct KVLayout(Copyable, ImplicitlyCopyable):
    """Validated KV geometry: layers, KV heads, head dim, capacity."""

    var num_layers: Int
    var num_heads: Int
    var head_dim: Int
    var max_seq: Int

    def __init__(
        out self, num_layers: Int, num_heads: Int, head_dim: Int, max_seq: Int
    ) raises:
        if num_layers <= 0:
            raise Error("KVLayout: num_layers must be positive")
        if num_heads <= 0:
            raise Error("KVLayout: num_heads must be positive")
        if head_dim <= 0:
            raise Error("KVLayout: head_dim must be positive")
        if max_seq <= 0:
            raise Error("KVLayout: max_seq must be positive")
        self.num_layers = num_layers
        self.num_heads = num_heads
        self.head_dim = head_dim
        self.max_seq = max_seq
        _ = self.total_elems()

    def elems_per_token(self) -> Int:
        """Elements in one token's K (or V) vector, all heads."""
        return self.num_heads * self.head_dim

    def total_elems(self) raises -> Int:
        var per = _checked_mul(self.num_heads, self.head_dim, "heads*dim")
        var t = _checked_mul(per, self.max_seq, "token*seq")
        t = _checked_mul(t, 2, "K+V")
        t = _checked_mul(t, self.num_layers, "layers")
        return t

    def byte_size(self) raises -> Int:
        return _checked_mul(self.total_elems(), 4, "bytes")

    def token_offset(
        self, layer: Int, kind: Int, seq: Int
    ) raises -> Int:
        """Element offset of the (layer, kind, seq) token vector."""
        if layer < 0 or layer >= self.num_layers:
            raise Error("KVLayout: layer out of range")
        if kind != KV_KIND_K and kind != KV_KIND_V:
            raise Error("KVLayout: kind must be 0 (K) or 1 (V)")
        if seq < 0 or seq >= self.max_seq:
            raise Error("KVLayout: seq out of capacity (fail-closed)")
        var per = self.elems_per_token()
        var idx = (layer * 2 + kind) * self.max_seq + seq
        return _checked_mul(idx, per, "token offset")

    def offset(
        self, layer: Int, kind: Int, seq: Int, head: Int, dim: Int
    ) raises -> Int:
        if head < 0 or head >= self.num_heads:
            raise Error("KVLayout: head out of range")
        if dim < 0 or dim >= self.head_dim:
            raise Error("KVLayout: dim out of range")
        var base = self.token_offset(layer, kind, seq)
        return base + head * self.head_dim + dim


struct UnifiedKVCache(Copyable, ImplicitlyCopyable):
    """One KV cache living in a single A-019 unified allocation."""

    var layout: KVLayout
    var buffer: ZeroCopyBuffer

    def __init__(out self, layout: KVLayout, buffer: ZeroCopyBuffer):
        self.layout = layout
        self.buffer = buffer

    @staticmethod
    def allocate(layout: KVLayout, backend: Int) raises -> UnifiedKVCache:
        var buf = ZeroCopy.allocate(layout.byte_size(), backend)
        if buf.size != layout.byte_size():
            raise Error("UnifiedKVCache: allocator size mismatch")
        return UnifiedKVCache(layout, buf)

    @staticmethod
    def allocate_default(layout: KVLayout) raises -> UnifiedKVCache:
        """The A-008 default backend: HIP managed memory."""
        return Self.allocate(layout, BACKEND_HIP_MANAGED)

    def free(self) raises:
        ZeroCopy.free(self.buffer)

    def _f32(self) raises -> Pointer[Float32, MutUntrackedOrigin]:
        var p = ZeroCopy.cpu_ptr(self.buffer)
        return p.unsafe_bitcast[Float32]()

    def release_cpu(self) raises:
        ZeroCopy.release_cpu_ptr(self.buffer)

    def write(
        self, layer: Int, kind: Int, seq: Int, head: Int, dim: Int, v: Float32
    ) raises:
        var off = self.layout.offset(layer, kind, seq, head, dim)
        _ = ZeroCopy.checked_f32_span(self.buffer, off, 1)
        var f = self._f32()
        f.unsafe_store(off, v)
        self.release_cpu()

    def read(
        self, layer: Int, kind: Int, seq: Int, head: Int, dim: Int
    ) raises -> Float32:
        var off = self.layout.offset(layer, kind, seq, head, dim)
        _ = ZeroCopy.checked_f32_span(self.buffer, off, 1)
        var f = self._f32()
        var v = f.unsafe_load(off)
        self.release_cpu()
        return v

    def append_token(
        self,
        layer: Int,
        seq: Int,
        k_values: List[Float32],
        v_values: List[Float32],
    ) raises:
        """Append one token's K and V vectors at (layer, seq).
        Vector lengths must equal num_heads*head_dim exactly and seq
        must be inside capacity; anything else raises (no wrap)."""
        var per = self.layout.elems_per_token()
        if len(k_values) != per or len(v_values) != per:
            raise Error("UnifiedKVCache.append_token: bad vector length")
        var kb = self.layout.token_offset(layer, KV_KIND_K, seq)
        var vb = self.layout.token_offset(layer, KV_KIND_V, seq)
        _ = ZeroCopy.checked_f32_span(self.buffer, kb, per)
        _ = ZeroCopy.checked_f32_span(self.buffer, vb, per)
        var f = self._f32()
        for i in range(per):
            f.unsafe_store(kb + i, k_values[i])
            f.unsafe_store(vb + i, v_values[i])
        self.release_cpu()

    def read_token(
        self, layer: Int, kind: Int, seq: Int
    ) raises -> List[Float32]:
        var per = self.layout.elems_per_token()
        var base = self.layout.token_offset(layer, kind, seq)
        _ = ZeroCopy.checked_f32_span(self.buffer, base, per)
        var f = self._f32()
        var out = List[Float32]()
        for i in range(per):
            out.append(f.unsafe_load(base + i))
        self.release_cpu()
        return out^

    def gpu_fill_all(self) raises:
        """GPU kernel writes EVERY KV element (A-019 HIP fill on the
        managed pointer): element at flat layout offset i gets the
        shim's deterministic pattern; the CPU then reads the cache
        through layout coordinates. HIP backend only."""
        ZeroCopy.hip_fill(self.buffer, self.layout.total_elems())

    def gpu_transform_to(self, dst: UnifiedKVCache) raises:
        """GPU kernel: dst = self*2+1 over the whole cache (A-019
        HIP transform). Layouts must match exactly."""
        if (
            dst.layout.num_layers != self.layout.num_layers
            or dst.layout.num_heads != self.layout.num_heads
            or dst.layout.head_dim != self.layout.head_dim
            or dst.layout.max_seq != self.layout.max_seq
        ):
            raise Error("UnifiedKVCache.gpu_transform_to: layout mismatch")
        ZeroCopy.hip_transform(
            dst.buffer, self.buffer, self.layout.total_elems()
        )


struct KVDecodeResult(Copyable):
    var argmax_seq: Int
    var best_score: Float32
    var output: List[Float32]

    def __init__(
        out self, argmax_seq: Int, best_score: Float32, output: List[Float32]
    ):
        self.argmax_seq = argmax_seq
        self.best_score = best_score
        self.output = output.copy()


def kv_cpu_decode_step(
    cache: UnifiedKVCache,
    layer: Int,
    head: Int,
    query: List[Float32],
    seq_len: Int,
) raises -> KVDecodeResult:
    """One CPU decode step over the unified KV cache: scores are
    dot(query, K[layer, seq, head]) for seq in [0, seq_len); the
    output is sum_seq score[seq] * V[layer, seq, head] (fixed
    ascending-seq accumulation order, so a CPU oracle recomputing
    from the same values matches bit-exactly). All reads go through
    the cache's checked coordinate path. seq_len must be in
    [1, max_seq] and the query length must equal head_dim."""
    var lay = cache.layout
    if len(query) != lay.head_dim:
        raise Error("kv_cpu_decode_step: query length != head_dim")
    if seq_len <= 0 or seq_len > lay.max_seq:
        raise Error("kv_cpu_decode_step: seq_len out of capacity")
    if layer < 0 or layer >= lay.num_layers:
        raise Error("kv_cpu_decode_step: layer out of range")
    if head < 0 or head >= lay.num_heads:
        raise Error("kv_cpu_decode_step: head out of range")
    var best_seq = 0
    var best = Float32(-3.4028235e38)
    var out = List[Float32]()
    for _ in range(lay.head_dim):
        out.append(Float32(0.0))
    for s in range(seq_len):
        var score = Float32(0.0)
        for d in range(lay.head_dim):
            score += query[d] * cache.read(layer, KV_KIND_K, s, head, d)
        if score > best:
            best = score
            best_seq = s
        for d in range(lay.head_dim):
            out[d] += score * cache.read(layer, KV_KIND_V, s, head, d)
    return KVDecodeResult(best_seq, best, out^)
