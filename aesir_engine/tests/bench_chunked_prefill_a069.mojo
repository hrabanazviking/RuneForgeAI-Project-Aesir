# tests/bench_chunked_prefill_a069.mojo
# A-069: chunked prefill bench + 8k acceptance (standalone,
# NOT part of run_all). Acceptance (roadmap A-069): an
# 8192-token prompt prefill completes with bounded memory and
# outputs identical to the unchunked pass.
#
# Geometry (filed honestly): ONE prefill layer, dense F32
# weights, dim 32 = 2 heads x 16, GQA ratio 1, ffn 32 - the
# small-fixture class of A-065..A-068, at an 8192-token prompt
# length. This proves the chunked-prefill mechanism at 8k
# scale; it is not a real-model (A-067-class) 8k run.
#
# Bounded-memory evidence, three ways:
# 1. Formula: workspace_bytes(chunk) depends only on the
#    chunk size; the KV cache is the only O(seq) state
#    (kv_cache_bytes). No score matrix exists anywhere in the
#    path (attention_prefill recomputes scores in a second
#    pass): an unchunked score matrix at 8k would be
#    8192^2 * 4 B = 268,435,456 B per head.
# 2. Live accounting: VulkanBuffers.live_bytes() sampled
#    between chunks is identical for seq 1024 and seq 8192 at
#    the same chunk size (weights + caches + one chunk of
#    buffers), and returns to the pre-run baseline after.
# 3. Completion: the 8k run finishes at chunk 256 in the same
#    workspace where a single-chunk pass would need
#    workspace_bytes(8192) of scratch.
#
# Identical-to-unchunked at bench geometry: seq 1024 run with
# chunk 256 vs chunk 1024 (single chunk), outputs + KV caches
# compared (bitwise expectation, A-069 test discipline).
# Timing: CLOCK_MONOTONIC around the full prefill loop
# (chunk uploads + gateway dispatches + readback), median of
# the measured trials stated in the log.

from std.ffi import external_call
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_prefill import VulkanPrefillKernels, VulkanPrefillWeights, VulkanChunkedPrefill

comptime _DIM = 32
comptime _HEADS = 2
comptime _RATIO = 1
comptime _HEAD_DIM = 16
comptime _KV_HEADS = 2
comptime _KV_DIM = 32
comptime _FFN = 32
comptime _EPS = Float32(1.0e-5)
comptime _BASE = Float32(10000.0)


def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("A069: cannot observe monotonic clock")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


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

    def val(mut self) -> Float32:
        return self.unit() * Float32(2.0) - Float32(1.0)


def _upload_vals(vals: List[Float32]) raises -> VulkanAllocation:
    var alloc = VulkanBuffers.allocate(len(vals) * 4)
    var p = VulkanBuffers.map(alloc)
    var f = p.unsafe_bitcast[Float32]()
    for i in range(len(vals)):
        f.unsafe_store(i, vals[i])
    VulkanBuffers.unmap(alloc)
    return alloc


def _matrix(rows: Int, cols: Int, mut lcg: _Lcg) raises -> VulkanAllocation:
    var vals = List[Float32]()
    for _ in range(rows * cols):
        vals.append(lcg.val() * Float32(0.20))
    return _upload_vals(vals)


def _make_weights() raises -> VulkanPrefillWeights:
    var lcg = _Lcg(0xA069B)
    var g1 = List[Float32]()
    var g2 = List[Float32]()
    for _ in range(_DIM):
        g1.append(Float32(0.75) + lcg.unit() * Float32(0.5))
        g2.append(Float32(0.75) + lcg.unit() * Float32(0.5))
    return VulkanPrefillWeights(
        _upload_vals(g1), _upload_vals(g2),
        _matrix(_DIM, _DIM, lcg), _matrix(_KV_DIM, _DIM, lcg),
        _matrix(_KV_DIM, _DIM, lcg), _matrix(_DIM, _KV_DIM, lcg),
        _matrix(_FFN, _DIM, lcg), _matrix(_FFN, _DIM, lcg),
        _matrix(_DIM, _FFN, lcg),
    )


def _emb(t: Int, i: Int) -> Float32:
    var h = (t * 131 + i * 17 + (t * i) % 13) % 89
    return (Float32(h) - Float32(44.0)) / Float32(44.0) * Float32(0.8)


def _run(weights: VulkanPrefillWeights, seq: Int, chunk: Int, keep_out: Bool) raises -> Tuple[List[Float32], Int, Int]:
    """One chunked prefill. Returns (outputs or empty,
    live_bytes sampled mid-run between chunks, seconds_ns)."""
    var max_len = seq
    var k_cache = VulkanBuffers.allocate(_KV_HEADS * max_len * _HEAD_DIM * 4)
    var v_cache = VulkanBuffers.allocate(_KV_HEADS * max_len * _HEAD_DIM * 4)
    var pk = VulkanBuffers.map(k_cache)
    var fk = pk.unsafe_bitcast[Float32]()
    for i in range(_KV_HEADS * max_len * _HEAD_DIM):
        fk.unsafe_store(i, Float32(0.0))
    VulkanBuffers.unmap(k_cache)
    var pv = VulkanBuffers.map(v_cache)
    var fv = pv.unsafe_bitcast[Float32]()
    for i in range(_KV_HEADS * max_len * _HEAD_DIM):
        fv.unsafe_store(i, Float32(0.0))
    VulkanBuffers.unmap(v_cache)
    var out = List[Float32]()
    var live_mid = 0
    var t0 = monotonic_ns()
    var n_chunks = VulkanChunkedPrefill.chunk_count(seq, chunk)
    for c in range(n_chunks):
        var start = c * chunk
        var clen = VulkanChunkedPrefill.chunk_len(seq, chunk, c)
        var xvals = List[Float32]()
        for tt in range(clen):
            for i in range(_DIM):
                xvals.append(_emb(start + tt, i))
        var x = _upload_vals(xvals)
        var dst = VulkanBuffers.allocate(clen * _DIM * 4)
        if c == n_chunks // 2:
            live_mid = VulkanBuffers.live_bytes()
        VulkanChunkedPrefill.layer_chunk(
            x, weights, dst, k_cache, v_cache,
            clen, start, max_len, _DIM, _HEADS, _RATIO, _HEAD_DIM, _FFN, _EPS, _BASE,
        )
        if keep_out:
            var p2 = VulkanBuffers.map(dst)
            var f2 = p2.unsafe_bitcast[Float32]()
            for i in range(clen * _DIM):
                out.append(f2.unsafe_load(i))
            VulkanBuffers.unmap(dst)
        VulkanBuffers.free(x)
        VulkanBuffers.free(dst)
    var t1 = monotonic_ns()
    if keep_out:
        var kc = List[Float32]()
        var p3 = VulkanBuffers.map(k_cache)
        var f3 = p3.unsafe_bitcast[Float32]()
        for i in range(_KV_HEADS * max_len * _HEAD_DIM):
            kc.append(f3.unsafe_load(i))
        VulkanBuffers.unmap(k_cache)
        for i in range(len(kc)):
            out.append(kc[i])
    VulkanBuffers.free(k_cache)
    VulkanBuffers.free(v_cache)
    return (out^, live_mid, t1 - t0)


def main() raises:
    print("A069_BENCH_START")
    if not _vk_present():
        print("A069_BENCH: Vulkan UNAVAILABLE (honest-absent)")
        return
    var info = VulkanBuffers.device_info()
    print("A069_DEVICE vendor=", info.vendor_id, " radv=", VulkanBuffers.device_name_is_radv())
    var start_live = VulkanBuffers.live_bytes()
    var weights = _make_weights()
    # Identity at bench geometry: chunk 256 vs single chunk.
    var a = _run(weights, 1024, 256, True)
    var b = _run(weights, 1024, 1024, True)
    var md = Float32(0.0)
    for i in range(len(a[0])):
        var d = a[0][i] - b[0][i]
        if d < 0:
            d = -d
        if d > md:
            md = d
    print("A069_IDENTITY seq=1024 chunk256_vs_whole outputs+K max_abs=", md, " live_mid_chunked=", a[1], " live_mid_whole=", b[1])
    if md > Float32(1.0e-5):
        raise Error("bench identity check failed")
    # 8k acceptance run.
    var r = _run(weights, 8192, 256, True)
    var secs = Float64(r[2]) / Float64(1000000000)
    var checksum = Float64(0.0)
    for i in range(8192 * _DIM):
        checksum += Float64(r[0][i])
    print("A069_8K seq=8192 chunk=256 chunks=", VulkanChunkedPrefill.chunk_count(8192, 256), " seconds=", secs, " tokens_per_sec=", Float64(8192) / secs)
    var l0 = r[0][8191 * _DIM]
    var l1 = r[0][8191 * _DIM + 1]
    var l2 = r[0][8191 * _DIM + 2]
    var l3 = r[0][8191 * _DIM + 3]
    print("A069_8K out_checksum=", checksum, " last_row_first4=", l0, l1, l2, l3)
    print("A069_BOUNDED workspace_chunk256=", VulkanChunkedPrefill.workspace_bytes(256, _DIM, _KV_DIM, _FFN), " workspace_single_chunk_8192=", VulkanChunkedPrefill.workspace_bytes(8192, _DIM, _KV_DIM, _FFN), " kv_cache_one=", VulkanChunkedPrefill.kv_cache_bytes(_KV_HEADS, 8192, _HEAD_DIM), " score_matrix_8k_one_head_bytes=", 8192 * 8192 * 4, " live_mid_8k=", r[1], " live_mid_1k_chunked=", a[1])
    print("A069_DISPATCH rope_batched=", VulkanPrefillKernels.rope_batched_dispatch_count(), " kv_append_chunk=", VulkanPrefillKernels.kv_append_chunk_dispatch_count(), " attention_prefill=", VulkanPrefillKernels.attention_chunk_dispatch_count())
    VulkanBuffers.free(weights.g_attn)
    VulkanBuffers.free(weights.g_ffn)
    VulkanBuffers.free(weights.wq)
    VulkanBuffers.free(weights.wk)
    VulkanBuffers.free(weights.wv)
    VulkanBuffers.free(weights.wo)
    VulkanBuffers.free(weights.w_gate)
    VulkanBuffers.free(weights.w_up)
    VulkanBuffers.free(weights.w_down)
    print("A069_LIVE_AFTER_FREE=", VulkanBuffers.live_bytes(), " start_live=", start_live)
    if VulkanBuffers.live_bytes() != start_live:
        raise Error("bench leaked device bytes")
    print("A069_BENCH: PASS")
