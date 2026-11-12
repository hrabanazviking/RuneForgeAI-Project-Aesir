"""A-071 bench fixture (A-066 decode fixture, verbatim)."""
from std.math import exp, sqrt, cos, sin
from std.memory import bitcast
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_layer import VulkanLayer, VulkanLayerWeights
from core.vulkan_kv_cache import VulkanKvCache, VulkanEmbed
from core.vulkan_attention import VulkanAttention
from core.vulkan_decode import VulkanDecode, VulkanDecodeWeights
from core.vulkan_async import VulkanAsync
from std.ffi import external_call

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



def _monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("A071 bench: cannot observe monotonic clock")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


def _median(mut vals: List[Float64]) -> Float64:
    for i in range(len(vals)):
        for j in range(len(vals) - 1 - i):
            if vals[j] > vals[j + 1]:
                var tmp = vals[j]
                vals[j] = vals[j + 1]
                vals[j + 1] = tmp
    return vals[len(vals) // 2]


def main() raises:
    print("--- A-071 bench: sync vs async decode (RADV STRIX_HALO) ---")
    if not _vk_present():
        print("A071_BENCH: HONEST-ABSENT (no RADV device)")
        return
    var fx = _ModelFixture()
    var prompt = List[Int]()
    prompt.append(5)
    prompt.append(17)
    prompt.append(42)
    var layer_weights = List[VulkanLayerWeights]()
    for li in range(_LAYERS):
        layer_weights.append(fx.layers[li].upload())
    var weights = VulkanDecodeWeights(
        _upload_f32(fx.embedding), layer_weights,
        _upload_f32(fx.g_final), fx.w_head.upload(),
    )
    var sync_tokens = VulkanDecode.generate(
        weights, prompt, _GEN, _DIM, _HEADS, _RATIO, _HEAD_DIM,
        _FFN, _VOCAB, _MAX_LEN, _EPS, _BASE)
    var async_tokens = VulkanDecode.generate_async(
        weights, prompt, _GEN, _DIM, _HEADS, _RATIO, _HEAD_DIM,
        _FFN, _VOCAB, _MAX_LEN, _EPS, _BASE)
    for i in range(_GEN):
        if sync_tokens[i] != async_tokens[i]:
            raise Error("bench gate: async tokens differ from sync")
    print("bench gate: token identity sync == async PASS")
    var sync_times = List[Float64]()
    var async_times = List[Float64]()
    for _ in range(5):
        var t0 = _monotonic_ns()
        _ = VulkanDecode.generate(
            weights, prompt, _GEN, _DIM, _HEADS, _RATIO, _HEAD_DIM,
            _FFN, _VOCAB, _MAX_LEN, _EPS, _BASE)
        sync_times.append(Float64(_monotonic_ns() - t0) / 1000000.0)
    for _ in range(5):
        var t0 = _monotonic_ns()
        _ = VulkanDecode.generate_async(
            weights, prompt, _GEN, _DIM, _HEADS, _RATIO, _HEAD_DIM,
            _FFN, _VOCAB, _MAX_LEN, _EPS, _BASE)
        async_times.append(Float64(_monotonic_ns() - t0) / 1000000.0)
    var sm = _median(sync_times)
    var am = _median(async_times)
    print("sync generate median ms", sm, "per token ms", sm / Float64(_GEN))
    print("async generate median ms", am, "per token ms", am / Float64(_GEN))
    var st = VulkanAsync.stats()
    print("async totals (last run) submits", st.submits, "max_depth", st.max_depth, "wait_idle", st.wait_idle_calls, "fence_waits", st.fence_waits)
    print("host_wait_ns total", st.host_wait_ns, "per token", st.host_wait_ns // _GEN, "gpu_busy_ns", st.gpu_busy_ns, "gpu_span_ns", st.gpu_span_ns, "busy_fraction", st.busy_fraction())
    print("A071_BENCH: PASS")
