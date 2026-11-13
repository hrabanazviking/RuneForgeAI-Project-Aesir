"""A-074 bench: subgroup reductions in softmax and attention.

Standalone timing proof (not an E-MASTER case): interleaved A/B
against the A-073 shared-tree baseline per the A-073 ledger
protocol - the same bench binary is run alternately against the
banked-shader .so and the A-074 variant .so (LD_LIBRARY_PATH
swap), 3 rounds each, medians compared, run ranges checked for
separation. Per-call timing includes pipeline creation + submit
+ wait-idle, identically for all variants (the A-055 per-dispatch
pipeline discipline). Parity is NOT judged here - the E-MASTER
cases of A-061/A-062/A-066/A-069 judge parity at their filed
bounds. Fails closed if the RADV device is not selected.

Shapes: softmax rows of 4096 (logit-row class) and 1024; decode
attention at a Coder-class GQA shape (32 heads, head_dim 128,
kv_per_query 4) at kv_len 1024 and 4096, plus the strided
variant; chunked prefill attention (head_dim 64, 64-token chunk
at position 1024 of a 4096 cache). Softmax is in place: after
the warmup the rows are already normalised, which does not
change the kernel's work (identical loops and traffic); the
first (cold-data) dispatch is in the warmup, not the timings.
"""
from std.ffi import external_call
from std.memory import Pointer
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_elementwise import VulkanElementwise
from core.vulkan_attention import VulkanAttention
from core.vulkan_prefill import VulkanPrefillKernels


def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("A074 clock")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


def _median(mut xs: List[Int]) -> Int:
    for i in range(1, len(xs)):
        var v = xs[i]
        var j = i - 1
        while j >= 0 and xs[j] > v:
            xs[j + 1] = xs[j]
            j -= 1
        xs[j + 1] = v
    return xs[len(xs) // 2]


def _fill(a: VulkanAllocation, count: Int, seed: Int) raises:
    var p = VulkanBuffers.map(a)
    var f = p.unsafe_bitcast[Float32]()
    for i in range(count):
        f.unsafe_store(i, Float32((i * 73 + seed) % 997) * Float32(0.01) - Float32(4.98))
    VulkanBuffers.unmap(a)


def _time_softmax(n: Int, rows: Int, reps: Int) raises:
    var x = VulkanBuffers.allocate(rows * n * 4)
    _fill(x, rows * n, 19)
    for _ in range(2):
        VulkanElementwise.softmax(x, n, rows)
    var before = VulkanElementwise.softmax_dispatch_count()
    var times = List[Int]()
    for _ in range(reps):
        var t0 = monotonic_ns()
        VulkanElementwise.softmax(x, n, rows)
        times.append(monotonic_ns() - t0)
    var after = VulkanElementwise.softmax_dispatch_count()
    print(
        "A074_SOFTMAX n=" + String(n) + " rows=" + String(rows)
        + " median_ns=" + String(_median(times))
        + " dispatches=" + String(after - before)
    )
    VulkanBuffers.free(x)


def _time_decode(strided: Bool, head_dim: Int, kv_len: Int, num_heads: Int, kv_per_query: Int, reps: Int) raises:
    var kv_heads = num_heads // kv_per_query
    var max_len = kv_len + 512 if strided else kv_len
    var q = VulkanBuffers.allocate(num_heads * head_dim * 4)
    var k = VulkanBuffers.allocate(kv_heads * max_len * head_dim * 4)
    var v = VulkanBuffers.allocate(kv_heads * max_len * head_dim * 4)
    var o = VulkanBuffers.allocate(num_heads * head_dim * 4)
    _fill(q, num_heads * head_dim, 7)
    _fill(k, kv_heads * max_len * head_dim, 11)
    _fill(v, kv_heads * max_len * head_dim, 23)
    if strided:
        for _ in range(2):
            VulkanAttention.decode_attention_strided(q, k, v, o, head_dim, kv_len, num_heads, kv_per_query, max_len)
        var before = VulkanAttention.strided_dispatch_count()
        var times = List[Int]()
        for _ in range(reps):
            var t0 = monotonic_ns()
            VulkanAttention.decode_attention_strided(q, k, v, o, head_dim, kv_len, num_heads, kv_per_query, max_len)
            times.append(monotonic_ns() - t0)
        var after = VulkanAttention.strided_dispatch_count()
        print(
            "A074_ATTN_DECODE_STRIDED head_dim=" + String(head_dim)
            + " kv_len=" + String(kv_len) + " heads=" + String(num_heads)
            + " median_ns=" + String(_median(times))
            + " dispatches=" + String(after - before)
        )
    else:
        for _ in range(2):
            VulkanAttention.decode_attention(q, k, v, o, head_dim, kv_len, num_heads, kv_per_query)
        var before = VulkanAttention.dispatch_count()
        var times = List[Int]()
        for _ in range(reps):
            var t0 = monotonic_ns()
            VulkanAttention.decode_attention(q, k, v, o, head_dim, kv_len, num_heads, kv_per_query)
            times.append(monotonic_ns() - t0)
        var after = VulkanAttention.dispatch_count()
        print(
            "A074_ATTN_DECODE head_dim=" + String(head_dim)
            + " kv_len=" + String(kv_len) + " heads=" + String(num_heads)
            + " median_ns=" + String(_median(times))
            + " dispatches=" + String(after - before)
        )
    VulkanBuffers.free(q)
    VulkanBuffers.free(k)
    VulkanBuffers.free(v)
    VulkanBuffers.free(o)


def _time_prefill(head_dim: Int, max_len: Int, chunk_start: Int, tokens: Int, num_heads: Int, kv_per_query: Int, reps: Int) raises:
    var kv_heads = num_heads // kv_per_query
    var q = VulkanBuffers.allocate(tokens * num_heads * head_dim * 4)
    var k = VulkanBuffers.allocate(kv_heads * max_len * head_dim * 4)
    var v = VulkanBuffers.allocate(kv_heads * max_len * head_dim * 4)
    var o = VulkanBuffers.allocate(tokens * num_heads * head_dim * 4)
    _fill(q, tokens * num_heads * head_dim, 5)
    _fill(k, kv_heads * max_len * head_dim, 13)
    _fill(v, kv_heads * max_len * head_dim, 29)
    for _ in range(2):
        VulkanPrefillKernels.attention_chunk(q, k, v, o, head_dim, max_len, chunk_start, tokens, num_heads, kv_per_query)
    var before = VulkanPrefillKernels.attention_chunk_dispatch_count()
    var times = List[Int]()
    for _ in range(reps):
        var t0 = monotonic_ns()
        VulkanPrefillKernels.attention_chunk(q, k, v, o, head_dim, max_len, chunk_start, tokens, num_heads, kv_per_query)
        times.append(monotonic_ns() - t0)
    var after = VulkanPrefillKernels.attention_chunk_dispatch_count()
    print(
        "A074_ATTN_PREFILL head_dim=" + String(head_dim)
        + " tokens=" + String(tokens) + " chunk_start=" + String(chunk_start)
        + " heads=" + String(num_heads)
        + " median_ns=" + String(_median(times))
        + " dispatches=" + String(after - before)
    )
    VulkanBuffers.free(q)
    VulkanBuffers.free(k)
    VulkanBuffers.free(v)
    VulkanBuffers.free(o)


def main() raises:
    if not VulkanBuffers.runtime_available() or not VulkanBuffers.dispatch_available():
        raise Error("A074 bench: Vulkan dispatch unavailable (fail-closed)")
    var info = VulkanBuffers.device_info()
    if info.vendor_id != 0x1002 or info.device_type == 4:
        raise Error("A074 bench: selected device is not the AMD iGPU")
    if not VulkanBuffers.device_name_is_radv():
        raise Error("A074 bench: selected device is not RADV (llvmpipe refused)")
    print("A074_DEVICE vendor=" + String(info.vendor_id) + " RADV=1")
    _time_softmax(4096, 64, 25)
    _time_softmax(1024, 256, 25)
    _time_decode(False, 128, 1024, 32, 4, 25)
    _time_decode(False, 128, 4096, 32, 4, 25)
    _time_decode(True, 128, 1024, 32, 4, 25)
    _time_prefill(64, 4096, 1024, 64, 32, 4, 25)
    print("A074_SUBGROUP_BENCH: PASS")
