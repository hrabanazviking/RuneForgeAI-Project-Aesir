# tests/bench_prefill_gemm_a068.mojo
# A-068: GPU prefill GEMM bench (standalone, NOT part of run_all).
# Discipline: CLOCK_MONOTONIC nanosecond timing; correctness is
# gated BEFORE timing at every geometry (sequential Float32 CPU
# oracle over the identical raw Q8_0 bytes, A-068 bound); 1
# settle pass discarded + 5 measured trials, median reported.
# Timed scope (named honestly): weights and activations are
# resident in device buffers before timing; each timed call is
# the production gateway call - pipeline creation, one batched
# dispatch, queue wait-idle - so tokens/s is end-to-end gateway
# throughput, not a kernel-only timestamp. Allocation is outside
# the timed region. No CPU product is computed in the GPU path;
# the CPU rows below time this file's sequential oracle at the
# same geometry for the same-fixture comparison, and the filed
# A-030 full-model CPU baseline is cited in the bench doc as
# the model-level reference (different scope, named there).

from std.ffi import external_call
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_gemm import VulkanGemm


def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("A068: cannot observe monotonic clock")
    if ts[0] < 0 or ts[1] < 0 or ts[1] >= 1000000000:
        raise Error("A068: invalid monotonic clock reading")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


def median_of(mut vals: List[Float64]) -> Float64:
    for i in range(len(vals)):
        for j in range(len(vals) - 1 - i):
            if vals[j] > vals[j + 1]:
                var tmp = vals[j]
                vals[j] = vals[j + 1]
                vals[j + 1] = tmp
    return vals[len(vals) // 2]


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


def _make_q8(
    rows: Int, cols: Int, tokens: Int, seed: UInt64
) raises -> Tuple[VulkanAllocation, VulkanAllocation, VulkanAllocation, List[Float32]]:
    var blocks_per_row = cols // 32
    var w_alloc = VulkanBuffers.allocate(rows * blocks_per_row * 34)
    var x_alloc = VulkanBuffers.allocate(tokens * cols * 4)
    var y_alloc = VulkanBuffers.allocate(tokens * rows * 4)
    var lcg = _Lcg(seed)
    var xs = List[Float32]()
    for _ in range(tokens * cols):
        xs.append(lcg.unit() * Float32(3.0) - Float32(1.5))
    var pw = VulkanBuffers.map(w_alloc)
    for blk in range(rows * blocks_per_row):
        var s = Float32(0.002) + lcg.unit() * Float32(0.018)
        if blk % 97 == 31:
            s = Float32(0.0)
        elif blk % 89 == 17:
            s = -s
        pw.unsafe_bitcast[Float16]().unsafe_store(blk * 17, Float16(s))
        for lane in range(32):
            pw.unsafe_store(blk * 34 + 2 + lane, lcg.byte())
    VulkanBuffers.unmap(w_alloc)
    var px = VulkanBuffers.map(x_alloc)
    var fx = px.unsafe_bitcast[Float32]()
    for i in range(tokens * cols):
        fx.unsafe_store(i, xs[i])
    VulkanBuffers.unmap(x_alloc)
    return (w_alloc, x_alloc, y_alloc, xs^)


def _oracle_check(
    w_alloc: VulkanAllocation,
    y_alloc: VulkanAllocation,
    xs: List[Float32],
    rows: Int,
    cols: Int,
    tokens: Int,
) raises:
    var blocks_per_row = cols // 32
    var qw = VulkanBuffers.map(w_alloc)
    var qy = VulkanBuffers.map(y_alloc)
    var gy = qy.unsafe_bitcast[Float32]()
    var max_abs: Float32 = 0.0
    for t in range(tokens):
        for r in range(rows):
            var acc: Float32 = 0.0
            for blk in range(blocks_per_row):
                var base = (r * blocks_per_row + blk) * 34
                var scale = qw.unsafe_bitcast[Float16]().unsafe_load(
                    (r * blocks_per_row + blk) * 17
                ).cast[DType.float32]()
                for lane in range(32):
                    var raw = Int(qw.unsafe_load(base + 2 + lane))
                    var q = raw - 256 if raw >= 128 else raw
                    acc += scale * Float32(q) * xs[t * cols + blk * 32 + lane]
            var d = gy.unsafe_load(t * rows + r) - acc
            if d < 0:
                d = -d
            if d > max_abs:
                max_abs = d
    VulkanBuffers.unmap(w_alloc)
    VulkanBuffers.unmap(y_alloc)
    if max_abs > Float32(0.001):
        raise Error("A068 bench correctness gate failed: max_abs " + String(max_abs))
    print("A068_CHECK rows=", rows, " cols=", cols, " tokens=", tokens, " max_abs=", max_abs)


def _bench_gemm(rows: Int, cols: Int, tokens: Int, reps: Int) raises:
    var fx = _make_q8(rows, cols, tokens, 0xA068)
    var w_alloc = fx[0]
    var x_alloc = fx[1]
    var y_alloc = fx[2]
    var xs = fx[3].copy()
    VulkanGemm.q8_0_gemm(w_alloc, x_alloc, y_alloc, rows, cols, tokens)
    _oracle_check(w_alloc, y_alloc, xs, rows, cols, tokens)
    var rates = List[Float64]()
    for trial in range(6):
        var t0 = monotonic_ns()
        for _ in range(reps):
            VulkanGemm.q8_0_gemm(w_alloc, x_alloc, y_alloc, rows, cols, tokens)
        var t1 = monotonic_ns()
        if trial > 0:
            var secs = Float64(t1 - t0) / Float64(1000000000)
            rates.append(Float64(tokens * reps) / secs)
    var med = median_of(rates)
    var flops = Float64(2 * tokens * rows * cols)
    print(
        "A068_BENCH_GEMM rows=", rows, " cols=", cols, " tokens=", tokens,
        " reps=", reps, " tokens_per_s=", med,
        " gflops=", med * flops / Float64(tokens) / Float64(1000000000),
    )
    VulkanBuffers.free(w_alloc)
    VulkanBuffers.free(x_alloc)
    VulkanBuffers.free(y_alloc)


def _bench_stack(tokens: Int, reps: Int) raises:
    # A-065 layer geometry: dim 256, kv_dim 128, ffn 512.
    # (rows=out, cols=in): q, k, v, wo, gate, up, down.
    var pr = [256, 128, 128, 256, 512, 512, 256]
    var pc = [256, 256, 256, 256, 256, 256, 512]
    var ws = List[VulkanAllocation]()
    var xs_a = List[VulkanAllocation]()
    var ys = List[VulkanAllocation]()
    var keep = List[List[Float32]]()
    for p in range(7):
        var fx = _make_q8(pr[p], pc[p], tokens, 0xA068 + UInt64(p))
        ws.append(fx[0])
        xs_a.append(fx[1])
        ys.append(fx[2])
        keep.append(fx[3].copy())
    for p in range(7):
        VulkanGemm.q8_0_gemm(ws[p], xs_a[p], ys[p], pr[p], pc[p], tokens)
        _oracle_check(ws[p], ys[p], keep[p], pr[p], pc[p], tokens)
    var rates = List[Float64]()
    for trial in range(6):
        var t0 = monotonic_ns()
        for _ in range(reps):
            for p in range(7):
                VulkanGemm.q8_0_gemm(ws[p], xs_a[p], ys[p], pr[p], pc[p], tokens)
        var t1 = monotonic_ns()
        if trial > 0:
            var secs = Float64(t1 - t0) / Float64(1000000000)
            rates.append(Float64(tokens * reps) / secs)
    print(
        "A068_BENCH_STACK layer_projection tokens=", tokens,
        " reps=", reps, " tokens_per_s=", median_of(rates),
    )
    for p in range(7):
        VulkanBuffers.free(ws[p])
        VulkanBuffers.free(xs_a[p])
        VulkanBuffers.free(ys[p])


def _bench_cpu_stack(tokens: Int) raises:
    # Sequential Float32 CPU oracle timed at the A-065 stack
    # geometry (single thread) - the same-fixture CPU companion.
    var pr = [256, 128, 128, 256, 512, 512, 256]
    var pc = [256, 256, 256, 256, 256, 256, 512]
    var total_work = 0
    var t0 = monotonic_ns()
    var sink: Float32 = 0.0
    for p in range(7):
        var rows = pr[p]
        var cols = pc[p]
        var blocks_per_row = cols // 32
        var lcg = _Lcg(0xA068 + UInt64(p))
        var scales = List[Float32]()
        for _ in range(rows * blocks_per_row):
            scales.append(Float32(0.01))
        var xs = List[Float32]()
        for _ in range(tokens * cols):
            xs.append(lcg.unit())
        for t in range(tokens):
            for r in range(rows):
                var acc: Float32 = 0.0
                for k in range(cols):
                    acc += scales[(r * blocks_per_row + k // 32)] * Float32(1.0) * xs[t * cols + k]
                sink += acc
        total_work += tokens * rows * cols
    var t1 = monotonic_ns()
    var secs = Float64(t1 - t0) / Float64(1000000000)
    print(
        "A068_BENCH_CPU_STACK tokens=", tokens,
        " tokens_per_s=", Float64(tokens) / secs, " sink=", sink,
    )


def main() raises:
    if not _vk_present():
        raise Error("A068 bench: RADV device absent (fail-closed)")
    print("A068_BENCH_BEGIN device=", VulkanBuffers.device_info().vendor_id)
    _bench_gemm(1024, 1024, 1, 50)
    _bench_gemm(1024, 1024, 8, 50)
    _bench_gemm(1024, 1024, 32, 50)
    _bench_gemm(1024, 1024, 64, 20)
    _bench_gemm(1024, 1024, 128, 20)
    _bench_gemm(256, 256, 64, 50)
    _bench_stack(8, 50)
    _bench_stack(32, 50)
    _bench_stack(64, 20)
    _bench_stack(128, 20)
    _bench_cpu_stack(32)
    _bench_cpu_stack(64)
    print("A068_BENCH: PASS")
