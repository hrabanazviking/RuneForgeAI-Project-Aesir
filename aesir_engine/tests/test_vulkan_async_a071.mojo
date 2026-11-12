"""Vulkan async dispatch (A-071): queued submissions with timeline
profiling over the A-066 decode fixture (identical fixture and
sequential Float32 CPU oracle as test_vulkan_decode_a066, copied
verbatim above this header's test section).

Acceptance: (1) token identity - VulkanDecode.generate_async
(async mode ON: every dispatch queued with a fence, no per-token
host sync) returns EXACTLY the synchronous generate() tokens,
which the A-066 case already proved token-exact vs this CPU
oracle (raw prompt ids, no chat template); here async is ALSO
checked directly against the oracle. (2) No per-token sync: the
shim async counters show wait_idle_calls == 0 for the whole async
run, submits == completed after the final drain, pending == 0,
and max queue depth >= 2 (submissions really queued). (3)
Timeline: GPU timestamp pairs give busy > 0, span >= busy, busy
fraction in (0, 1], fence_waits >= generated tokens (one drain
per token), host wait measured > = 0 and finite. (4) Dispatch
level: a burst of Q8_0 GEMV dispatches queued without any drain
shows pending > 0 before the first mapped read (which
auto-drains) and results identical to the sync path.

Device-execution evidence (law 6): AMD Radeon 8060S (RADV
STRIX_HALO) only - llvmpipe refused by identity; honest-absent
pass on hosts without the device, A-014/A-066 discipline.
"""
from std.math import exp, sqrt, cos, sin
from std.memory import bitcast
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_layer import VulkanLayer, VulkanLayerWeights
from core.vulkan_kv_cache import VulkanKvCache, VulkanEmbed
from core.vulkan_attention import VulkanAttention
from core.vulkan_decode import VulkanDecode, VulkanDecodeWeights
from core.vulkan_async import VulkanAsync
from core.vulkan_gemv import VulkanGemv

comptime _DIM = 256
comptime _HEADS = 4
comptime _RATIO = 2
comptime _HEAD_DIM = 64
comptime _KV_HEADS = 2
comptime _KV_DIM = 128
comptime _FFN = 512
comptime _VOCAB = 96
comptime _LAYERS = 2
comptime _MAX_LEN = 16
comptime _GEN = 8
comptime _EPS = Float32(1.0e-5)
comptime _BASE = Float32(10000.0)
comptime _BOUND = Float32(5.0e-3)


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


def _abs32(v: Float32) -> Float32:
    return -v if v < Float32(0.0) else v


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

    def quant(mut self) -> Int:
        return Int(self.next() & 0xFF) - 128


struct _Q8Matrix:
    var rows: Int
    var cols: Int
    var scales: List[Float32]
    var quants: List[Int]

    def __init__(out self, rows: Int, cols: Int, mut lcg: _Lcg):
        self.rows = rows
        self.cols = cols
        self.scales = List[Float32]()
        self.quants = List[Int]()
        var blocks = rows * (cols // 32)
        for _ in range(blocks):
            var s = Float32(0.002) + lcg.unit() * Float32(0.010)
            if lcg.unit() < Float32(0.1):
                s = -s
            self.scales.append(Float16(s).cast[DType.float32]())
            for _ in range(32):
                self.quants.append(lcg.quant())

    def byte_len(self) -> Int:
        return self.rows * (self.cols // 32) * 34

    def upload(self) raises -> VulkanAllocation:
        var alloc = VulkanBuffers.allocate(self.byte_len())
        var p = VulkanBuffers.map(alloc)
        var blocks = self.rows * (self.cols // 32)
        for blk in range(blocks):
            var bits = bitcast[DType.uint16](Float16(self.scales[blk]))
            p.unsafe_store(blk * 34, UInt8(bits & 0xFF))
            p.unsafe_store(blk * 34 + 1, UInt8((bits >> 8) & 0xFF))
            for lane in range(32):
                var q = self.quants[blk * 32 + lane]
                p.unsafe_store(
                    blk * 34 + 2 + lane,
                    UInt8(q + 256) if q < 0 else UInt8(q),
                )
        VulkanBuffers.unmap(alloc)
        return alloc

    def gemv(self, x: List[Float32]) -> List[Float32]:
        var out = List[Float32]()
        var blocks_per_row = self.cols // 32
        for r in range(self.rows):
            var acc = Float32(0.0)
            for blk in range(blocks_per_row):
                var scale = self.scales[r * blocks_per_row + blk]
                for lane in range(32):
                    var q = self.quants[
                        (r * blocks_per_row + blk) * 32 + lane
                    ]
                    acc += scale * Float32(q) * x[blk * 32 + lane]
            out.append(acc)
        return out^


struct _LayerFixture:
    var g_attn: List[Float32]
    var g_ffn: List[Float32]
    var wq: _Q8Matrix
    var wk: _Q8Matrix
    var wv: _Q8Matrix
    var wo: _Q8Matrix
    var w_gate: _Q8Matrix
    var w_up: _Q8Matrix
    var w_down: _Q8Matrix

    def __init__(out self, layer_index: Int):
        var lcg = _Lcg(0xA06600 + UInt64(layer_index) * 977)
        self.g_attn = List[Float32]()
        self.g_ffn = List[Float32]()
        for _ in range(_DIM):
            self.g_attn.append(Float32(0.75) + lcg.unit() * Float32(0.5))
        for _ in range(_DIM):
            self.g_ffn.append(Float32(0.75) + lcg.unit() * Float32(0.5))
        self.wq = _Q8Matrix(_DIM, _DIM, lcg)
        self.wk = _Q8Matrix(_KV_DIM, _DIM, lcg)
        self.wv = _Q8Matrix(_KV_DIM, _DIM, lcg)
        self.wo = _Q8Matrix(_DIM, _KV_DIM, lcg)
        self.w_gate = _Q8Matrix(_FFN, _DIM, lcg)
        self.w_up = _Q8Matrix(_FFN, _DIM, lcg)
        self.w_down = _Q8Matrix(_DIM, _FFN, lcg)

    def upload(self) raises -> VulkanLayerWeights:
        return VulkanLayerWeights(
            _upload_f32(self.g_attn),
            _upload_f32(self.g_ffn),
            self.wq.upload(),
            self.wk.upload(),
            self.wv.upload(),
            self.wo.upload(),
            self.w_gate.upload(),
            self.w_up.upload(),
            self.w_down.upload(),
        )


struct _ModelFixture:
    var embedding: List[Float32]
    var layers: List[_LayerFixture]
    var g_final: List[Float32]
    var w_head: _Q8Matrix

    def __init__(out self):
        var lcg = _Lcg(0xA066FF)
        self.embedding = List[Float32]()
        for _ in range(_VOCAB * _DIM):
            self.embedding.append(lcg.val() * Float32(0.5))
        self.layers = List[_LayerFixture]()
        for li in range(_LAYERS):
            self.layers.append(_LayerFixture(li))
        self.g_final = List[Float32]()
        for _ in range(_DIM):
            self.g_final.append(Float32(0.75) + lcg.unit() * Float32(0.5))
        self.w_head = _Q8Matrix(_VOCAB, _DIM, lcg)


def _upload_f32(vals: List[Float32]) raises -> VulkanAllocation:
    var alloc = VulkanBuffers.allocate(len(vals) * 4)
    var p = VulkanBuffers.map(alloc)
    var f = p.unsafe_bitcast[Float32]()
    for i in range(len(vals)):
        f.unsafe_store(i, vals[i])
    VulkanBuffers.unmap(alloc)
    return alloc


def _read_f32(alloc: VulkanAllocation, n: Int) raises -> List[Float32]:
    var out = List[Float32]()
    var p = VulkanBuffers.map(alloc)
    var f = p.unsafe_bitcast[Float32]()
    for i in range(n):
        out.append(f.unsafe_load(i))
    VulkanBuffers.unmap(alloc)
    return out^


def _zero_alloc(n_floats: Int) raises -> VulkanAllocation:
    var alloc = VulkanBuffers.allocate(n_floats * 4)
    var p = VulkanBuffers.map(alloc)
    var f = p.unsafe_bitcast[Float32]()
    for i in range(n_floats):
        f.unsafe_store(i, Float32(0.0))
    VulkanBuffers.unmap(alloc)
    return alloc


def _cpu_rmsnorm(x: List[Float32], g: List[Float32]) -> List[Float32]:
    var ss = Float32(0.0)
    for i in range(len(x)):
        ss += x[i] * x[i]
    var scale = Float32(1.0) / sqrt(ss / Float32(len(x)) + _EPS)
    var out = List[Float32]()
    for i in range(len(x)):
        out.append(x[i] * scale * g[i])
    return out^


def _cpu_rope(x: List[Float32], rows: Int, position: Int) -> List[Float32]:
    var out = List[Float32]()
    for i in range(len(x)):
        out.append(x[i])
    var half = _HEAD_DIM // 2
    for r in range(rows):
        for i in range(half):
            var freq = _BASE ** (Float32(-2 * i) / Float32(_HEAD_DIM))
            var ang = Float32(position) * freq
            var c = cos(ang)
            var s = sin(ang)
            var a = x[r * _HEAD_DIM + i]
            var b = x[r * _HEAD_DIM + i + half]
            out[r * _HEAD_DIM + i] = a * c - b * s
            out[r * _HEAD_DIM + i + half] = b * c + a * s
    return out^


def _cpu_attention(
    q: List[Float32],
    k_cache: List[Float32],
    v_cache: List[Float32],
    kv_len: Int,
    max_len: Int,
) -> List[Float32]:
    """Sequential attention oracle over the strided cache."""
    var out = List[Float32]()
    var scale = Float32(1.0) / sqrt(Float32(_HEAD_DIM))
    for hd in range(_HEADS):
        var kv_head = hd // _RATIO
        var scores = List[Float32]()
        var row_max = Float32(-1.0e30)
        for t in range(kv_len):
            var base = (kv_head * max_len + t) * _HEAD_DIM
            var sc = Float32(0.0)
            for d in range(_HEAD_DIM):
                sc += q[hd * _HEAD_DIM + d] * k_cache[base + d]
            sc = sc * scale
            scores.append(sc)
            if sc > row_max:
                row_max = sc
        var denom = Float32(0.0)
        var weights = List[Float32]()
        for t in range(kv_len):
            var w = exp(scores[t] - row_max)
            weights.append(w)
            denom += w
        for d in range(_HEAD_DIM):
            var acc = Float32(0.0)
            for t in range(kv_len):
                var base = (kv_head * max_len + t) * _HEAD_DIM
                acc += weights[t] * v_cache[base + d]
            out.append(acc / denom)
    return out^


def _cpu_generate(
    fx: _ModelFixture, prompt: List[Int]
) -> List[Int]:
    """Independent sequential Float32 full-decode oracle."""
    var k_caches = List[List[Float32]]()
    var v_caches = List[List[Float32]]()
    for _ in range(_LAYERS):
        var kc = List[Float32]()
        var vc = List[Float32]()
        for _ in range(_KV_HEADS * _MAX_LEN * _HEAD_DIM):
            kc.append(Float32(0.0))
            vc.append(Float32(0.0))
        k_caches.append(kc.copy())
        v_caches.append(vc.copy())
    var tokens = prompt.copy()
    var generated = List[Int]()
    var total_steps = len(prompt) + _GEN - 1
    for step in range(total_steps):
        var token = tokens[step]
        var x = List[Float32]()
        for d in range(_DIM):
            x.append(fx.embedding[token * _DIM + d])
        for li in range(_LAYERS):
            var h = _cpu_rmsnorm(x, fx.layers[li].g_attn)
            var q = _cpu_rope(fx.layers[li].wq.gemv(h), _HEADS, step)
            var k = _cpu_rope(fx.layers[li].wk.gemv(h), _KV_HEADS, step)
            var v = fx.layers[li].wv.gemv(h)
            for hd in range(_KV_HEADS):
                for d in range(_HEAD_DIM):
                    var slot = (hd * _MAX_LEN + step) * _HEAD_DIM + d
                    k_caches[li][slot] = k[hd * _HEAD_DIM + d]
                    v_caches[li][slot] = v[hd * _HEAD_DIM + d]
            var attn = _cpu_attention(
                q, k_caches[li], v_caches[li], step + 1, _MAX_LEN
            )
            var proj = fx.layers[li].wo.gemv(attn)
            var res = List[Float32]()
            for i in range(_DIM):
                res.append(x[i] + proj[i])
            var h2 = _cpu_rmsnorm(res, fx.layers[li].g_ffn)
            var gate = fx.layers[li].w_gate.gemv(h2)
            var up = fx.layers[li].w_up.gemv(h2)
            var down_in = List[Float32]()
            for i in range(_FFN):
                var silu = gate[i] / (Float32(1.0) + exp(-gate[i]))
                down_in.append(silu * up[i])
            var down = fx.layers[li].w_down.gemv(down_in)
            x = List[Float32]()
            for i in range(_DIM):
                x.append(res[i] + down[i])
        if step >= len(prompt) - 1:
            var normed = _cpu_rmsnorm(x, fx.g_final)
            var logits = fx.w_head.gemv(normed)
            var best = 0
            var best_val = logits[0]
            var second = Float32(-1.0e30)
            for i in range(len(logits)):
                if logits[i] > best_val:
                    second = best_val
                    best_val = logits[i]
                    best = i
                elif logits[i] > second:
                    second = logits[i]
            print(
                "  oracle step", step, "token", best,
                "logit gap", best_val - second,
            )
            generated.append(best)
            tokens.append(best)
    return generated^



def _upload_weights(fx: _ModelFixture) raises -> VulkanDecodeWeights:
    var layer_weights = List[VulkanLayerWeights]()
    for li in range(_LAYERS):
        layer_weights.append(fx.layers[li].upload())
    return VulkanDecodeWeights(
        _upload_f32(fx.embedding),
        layer_weights,
        _upload_f32(fx.g_final),
        fx.w_head.upload(),
    )


def _prompt() -> List[Int]:
    var prompt = List[Int]()
    prompt.append(5)
    prompt.append(17)
    prompt.append(42)
    return prompt^


def _free_weights(w: VulkanDecodeWeights) raises:
    """Release every uploaded weight buffer. The shim slot table
    holds 128 buffers; five weight-uploading cases plus the
    traced driver section in one process exceed it unless each
    case frees its weights (A-071 in-slice fix: the traced
    section originally died at VulkanBuffers.allocate with the
    table full of leaked weight sets)."""
    VulkanBuffers.free(w.embedding)
    for li in range(len(w.layers)):
        var lw = w.layers[li]
        VulkanBuffers.free(lw.g_attn)
        VulkanBuffers.free(lw.g_ffn)
        VulkanBuffers.free(lw.wq)
        VulkanBuffers.free(lw.wk)
        VulkanBuffers.free(lw.wv)
        VulkanBuffers.free(lw.wo)
        VulkanBuffers.free(lw.w_gate)
        VulkanBuffers.free(lw.w_up)
        VulkanBuffers.free(lw.w_down)
    VulkanBuffers.free(w.g_final)
    VulkanBuffers.free(w.w_head)


def test_vulkan_async_token_identity() raises:
    print("--- Testing Vulkan async decode token identity (A-071) ---")
    if not _vk_present():
        print("Vulkan RADV device absent: honest-absent PASS")
        return
    var fx = _ModelFixture()
    var prompt = _prompt()
    var want = _cpu_generate(fx, prompt)
    var weights = _upload_weights(fx)
    var sync_tokens = VulkanDecode.generate(
        weights, prompt, _GEN, _DIM, _HEADS, _RATIO, _HEAD_DIM,
        _FFN, _VOCAB, _MAX_LEN, _EPS, _BASE,
    )
    var async_tokens = VulkanDecode.generate_async(
        weights, prompt, _GEN, _DIM, _HEADS, _RATIO, _HEAD_DIM,
        _FFN, _VOCAB, _MAX_LEN, _EPS, _BASE,
    )
    if len(async_tokens) != _GEN or len(sync_tokens) != _GEN:
        raise Error("async decode returned the wrong token count")
    for i in range(_GEN):
        print("  step", i, "async", async_tokens[i], "sync", sync_tokens[i], "oracle", want[i])
        if async_tokens[i] != sync_tokens[i]:
            raise Error("async token differs from the synchronous path")
        if async_tokens[i] != want[i]:
            raise Error("async token differs from the CPU oracle")
    _free_weights(weights)
    print("Vulkan async decode token identity (sync == async == oracle): PASS")


def test_vulkan_async_no_wait_idle() raises:
    print("--- Testing Vulkan async no per-token host sync (A-071) ---")
    if not _vk_present():
        print("Vulkan RADV device absent: honest-absent PASS")
        return
    var fx = _ModelFixture()
    var weights = _upload_weights(fx)
    _ = VulkanDecode.generate_async(
        weights, _prompt(), _GEN, _DIM, _HEADS, _RATIO, _HEAD_DIM,
        _FFN, _VOCAB, _MAX_LEN, _EPS, _BASE,
    )
    var st = VulkanAsync.stats()
    print("  submits", st.submits, "completed", st.completed, "pending", st.pending, "max_depth", st.max_depth, "wait_idle", st.wait_idle_calls, "fence_waits", st.fence_waits)
    if st.mode != 0:
        raise Error("async mode still on after generate_async returned")
    if st.submits <= 0:
        raise Error("async run recorded no queued submissions")
    if st.wait_idle_calls != 0:
        raise Error("vkQueueWaitIdle was called during the async run")
    if st.completed != st.submits:
        raise Error("not every queued submission completed at drain")
    if st.pending != 0:
        raise Error("submissions still pending after generate_async")
    if st.max_depth < 2:
        raise Error("queue depth never exceeded 1: submissions did not queue")
    if st.fence_waits < _GEN:
        raise Error("fewer fence waits than generated tokens (per-token drain missing)")
    _free_weights(weights)
    print("Vulkan async no-wait-idle (queued, fence-drained per token): PASS")


def test_vulkan_async_timeline_sane() raises:
    print("--- Testing Vulkan async timeline trace sane (A-071) ---")
    if not _vk_present():
        print("Vulkan RADV device absent: honest-absent PASS")
        return
    var fx = _ModelFixture()
    var weights = _upload_weights(fx)
    _ = VulkanDecode.generate_async(
        weights, _prompt(), _GEN, _DIM, _HEADS, _RATIO, _HEAD_DIM,
        _FFN, _VOCAB, _MAX_LEN, _EPS, _BASE,
    )
    var st = VulkanAsync.stats()
    print("  ts_ok", st.ts_ok, "busy_ns", st.gpu_busy_ns, "span_ns", st.gpu_span_ns, "busy_fraction", st.busy_fraction(), "host_wait_ns", st.host_wait_ns, "period_ps", st.ts_period_ps)
    if not st.ts_ok:
        raise Error("GPU timestamp queries unavailable on RADV (timeline cannot be filed)")
    if st.ts_period_ps <= 0:
        raise Error("timestamp period is not positive")
    if st.gpu_busy_ns <= 0:
        raise Error("GPU busy time is zero: timestamps did not measure dispatch work")
    if st.gpu_span_ns < st.gpu_busy_ns:
        raise Error("timeline span is smaller than GPU busy time")
    var frac = st.busy_fraction()
    if frac <= Float64(0.0) or frac > Float64(1.0):
        raise Error("GPU busy fraction outside (0, 1]")
    _free_weights(weights)
    print("Vulkan async timeline sane (busy fraction in (0,1], span >= busy): PASS")


def test_vulkan_async_dispatch_queueing() raises:
    print("--- Testing Vulkan async dispatch queueing (A-071) ---")
    if not _vk_present():
        print("Vulkan RADV device absent: honest-absent PASS")
        return
    var lcg = _Lcg(0xA07100)
    var mat = _Q8Matrix(32, _DIM, lcg)
    var w = mat.upload()
    var xvals = List[Float32]()
    for _ in range(_DIM):
        xvals.append(lcg.val())
    var x = _upload_f32(xvals)
    var y_sync = VulkanBuffers.allocate(32 * 4)
    var y_async = VulkanBuffers.allocate(32 * 4)
    VulkanGemv.q8_0_gemv(w, x, y_sync, 32, _DIM)
    var want = _read_f32(y_sync, 32)
    VulkanAsync.set_mode(True)
    VulkanAsync.reset_stats()
    for _ in range(16):
        VulkanGemv.q8_0_gemv(w, x, y_async, 32, _DIM)
    var mid = VulkanAsync.stats()
    print("  mid pending", mid.pending, "submits", mid.submits, "max_depth", mid.max_depth)
    if mid.pending <= 0:
        raise Error("queued GEMV burst shows no pending submissions before drain")
    if mid.max_depth < 2:
        raise Error("queued GEMV burst never queued beyond depth 1")
    VulkanAsync.drain()
    VulkanAsync.set_mode(False)
    var got = _read_f32(y_async, 32)
    for i in range(32):
        if _abs32(got[i] - want[i]) > Float32(1.0e-6):
            raise Error("async GEMV result differs from the sync result")
    var oracle = mat.gemv(xvals)
    for i in range(32):
        if _abs32(got[i] - oracle[i]) > Float32(1.0e-4):
            raise Error("async GEMV result differs from the CPU oracle")
    VulkanBuffers.free(w)
    VulkanBuffers.free(x)
    VulkanBuffers.free(y_sync)
    VulkanBuffers.free(y_async)
    print("Vulkan async dispatch queueing (16 queued GEMV, results exact): PASS")


def test_vulkan_async_rejection() raises:
    print("--- Testing Vulkan async rejection (A-071) ---")
    if not _vk_present():
        print("Vulkan RADV device absent: honest-absent PASS")
        return
    VulkanAsync.drain()
    var fx = _ModelFixture()
    var weights = _upload_weights(fx)
    var empty = List[Int]()
    var raised = False
    try:
        _ = VulkanDecode.generate_async(
            weights, empty, _GEN, _DIM, _HEADS, _RATIO, _HEAD_DIM,
            _FFN, _VOCAB, _MAX_LEN, _EPS, _BASE,
        )
    except:
        raised = True
    if not raised:
        raise Error("generate_async accepted an empty prompt")
    var st = VulkanAsync.stats()
    if st.mode != 0:
        raise Error("rejected generate_async left async mode on")
    if st.pending != 0:
        raise Error("rejected generate_async left pending submissions")
    var bad = List[Int]()
    bad.append(_VOCAB + 7)
    raised = False
    try:
        _ = VulkanDecode.generate_async(
            weights, bad, _GEN, _DIM, _HEADS, _RATIO, _HEAD_DIM,
            _FFN, _VOCAB, _MAX_LEN, _EPS, _BASE,
        )
    except:
        raised = True
    if not raised:
        raise Error("generate_async accepted an out-of-vocab prompt token")
    _free_weights(weights)
    print("Vulkan async rejection (validation before mode-on, no residue): PASS")


def test_vulkan_async_dispatch_evidence() raises:
    print("--- Testing Vulkan async dispatch evidence (A-071) ---")
    if not _vk_present():
        print("Vulkan RADV device absent: honest-absent PASS")
        return
    var info = VulkanBuffers.device_info()
    if info.vendor_id != 0x1002:
        raise Error("async evidence not on the AMD device")
    var fx = _ModelFixture()
    var weights = _upload_weights(fx)
    _ = VulkanDecode.generate_async(
        weights, _prompt(), _GEN, _DIM, _HEADS, _RATIO, _HEAD_DIM,
        _FFN, _VOCAB, _MAX_LEN, _EPS, _BASE,
    )
    var st = VulkanAsync.stats()
    var total_steps = 3 + _GEN - 1
    print("  submits", st.submits, "per step", st.submits // total_steps, "host_wait_ns/token", st.host_wait_ns // _GEN)
    if st.submits < total_steps * 10:
        raise Error("async submits too few for a full decode (dispatch evidence thin)")
    if st.host_wait_ns < 0:
        raise Error("host wait time is negative")
    _free_weights(weights)
    print("Vulkan async dispatch evidence (RADV counters + per-token host wait): PASS")
