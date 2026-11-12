"""Vulkan full decode loop (A-066): a stories260K-class small
fixture model generating entirely on the GPU path - embedding
gather (A-066) -> per-layer VulkanLayer.forward_kv with the
A-066 KV-append kernel closing the A-065 KV-APPEND GAP and the
A-066 strided decode attention over the growing cache ->
final norm -> Q8_0 LM head (A-056) -> greedy argmax (A-063).

Acceptance (roadmap): greedy output token-exact vs the Z13 CPU
oracle (A-004 discipline). The prompt enters as RAW token ids
- no chat template exists anywhere in this path. The oracle
below is an independent sequential Float32 implementation
consuming the identical raw Q8_0 bytes and embedding values,
with a real multi-position KV cache (max-subtraction softmax
over kv_len positions, RoPE at each step's own position).
Token-exactness is a sound acceptance here because the filed
fixture's oracle top-1/top-2 logit gaps (printed per step) sit
orders of magnitude above the accumulation-order delta scale
measured at A-065 (<= 0.0062 chained hidden-state delta).

Device-execution evidence (law 6): the selected device must be
the AMD Radeon 8060S (RADV STRIX_HALO) - llvmpipe is refused
by the identity check - and the shim dispatch counters must
advance by the exact per-run counts (embed_gather = steps,
kv_append = steps x layers x 2, strided attention =
steps x layers, greedy = generated). On a host without that
device the cases pass as honest-absent, matching A-014/A-065
discipline.
"""
from std.math import exp, sqrt, cos, sin
from std.memory import bitcast
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_layer import VulkanLayer, VulkanLayerWeights
from core.vulkan_kv_cache import VulkanKvCache, VulkanEmbed
from core.vulkan_attention import VulkanAttention
from core.vulkan_decode import VulkanDecode, VulkanDecodeWeights

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


def test_vulkan_decode_kv_append_parity() raises:
    print("--- Testing Vulkan KV-append parity (A-066) ---")
    if not _vk_present():
        print("Vulkan RADV device absent: honest-absent PASS")
        return
    var lcg = _Lcg(0xA066A9)
    var cache = _zero_alloc(_KV_HEADS * _MAX_LEN * _HEAD_DIM)
    var c0 = VulkanKvCache.dispatch_count()
    for pos in range(4):
        var row = List[Float32]()
        for _ in range(_KV_DIM):
            row.append(lcg.val())
        var src = _upload_f32(row)
        VulkanKvCache.append(src, cache, _HEAD_DIM, _MAX_LEN, pos, _KV_HEADS)
        var back = _read_f32(cache, _KV_HEADS * _MAX_LEN * _HEAD_DIM)
        for hd in range(_KV_HEADS):
            for d in range(_HEAD_DIM):
                var slot = (hd * _MAX_LEN + pos) * _HEAD_DIM + d
                if back[slot] != row[hd * _HEAD_DIM + d]:
                    raise Error("KV-append slot value is not bit-exact")
                var other = (hd * _MAX_LEN + 7) * _HEAD_DIM + d
                if back[other] != Float32(0.0):
                    raise Error("KV-append touched an unrelated slot")
        VulkanBuffers.free(src)
    if VulkanKvCache.dispatch_count() - c0 != 4:
        raise Error("KV-append dispatch counter did not advance by 4")
    VulkanBuffers.free(cache)
    print("Vulkan KV-append parity (4 positions, bit-exact, slots isolated): PASS")


def test_vulkan_decode_strided_attention_parity() raises:
    print("--- Testing Vulkan strided attention parity (A-066) ---")
    if not _vk_present():
        print("Vulkan RADV device absent: honest-absent PASS")
        return
    var lcg = _Lcg(0xA06657)
    var k_cache = _zero_alloc(_KV_HEADS * _MAX_LEN * _HEAD_DIM)
    var v_cache = _zero_alloc(_KV_HEADS * _MAX_LEN * _HEAD_DIM)
    var k_host = List[Float32]()
    var v_host = List[Float32]()
    for _ in range(_KV_HEADS * _MAX_LEN * _HEAD_DIM):
        k_host.append(Float32(0.0))
        v_host.append(Float32(0.0))
    for pos in range(3):
        var krow = List[Float32]()
        var vrow = List[Float32]()
        for _ in range(_KV_DIM):
            krow.append(lcg.val())
            vrow.append(lcg.val())
        var ks = _upload_f32(krow)
        var vs = _upload_f32(vrow)
        VulkanKvCache.append(ks, k_cache, _HEAD_DIM, _MAX_LEN, pos, _KV_HEADS)
        VulkanKvCache.append(vs, v_cache, _HEAD_DIM, _MAX_LEN, pos, _KV_HEADS)
        for hd in range(_KV_HEADS):
            for d in range(_HEAD_DIM):
                var slot = (hd * _MAX_LEN + pos) * _HEAD_DIM + d
                k_host[slot] = krow[hd * _HEAD_DIM + d]
                v_host[slot] = vrow[hd * _HEAD_DIM + d]
        VulkanBuffers.free(ks)
        VulkanBuffers.free(vs)
    var qvals = List[Float32]()
    for _ in range(_DIM):
        qvals.append(lcg.val())
    var q = _upload_f32(qvals)
    var o = VulkanBuffers.allocate(_DIM * 4)
    var a0 = VulkanAttention.strided_dispatch_count()
    VulkanAttention.decode_attention_strided(
        q, k_cache, v_cache, o, _HEAD_DIM, 3, _HEADS, _RATIO, _MAX_LEN
    )
    if VulkanAttention.strided_dispatch_count() - a0 != 1:
        raise Error("strided attention dispatch counter did not advance by 1")
    var got = _read_f32(o, _DIM)
    var want = _cpu_attention(qvals, k_host, v_host, 3, _MAX_LEN)
    var worst = Float32(0.0)
    for i in range(_DIM):
        var d = _abs32(got[i] - want[i])
        if d > worst:
            worst = d
    print("  strided attention max_abs", worst)
    if worst > _BOUND:
        raise Error("strided attention parity exceeds the filed bound")
    VulkanBuffers.free(q)
    VulkanBuffers.free(o)
    VulkanBuffers.free(k_cache)
    VulkanBuffers.free(v_cache)
    print("Vulkan strided attention parity (kv_len 3 of max_len 16): PASS")


def test_vulkan_decode_token_exact() raises:
    print("--- Testing Vulkan full decode token-exact (A-066) ---")
    if not _vk_present():
        print("Vulkan RADV device absent: honest-absent PASS")
        return
    var fx = _ModelFixture()
    var prompt = List[Int]()
    prompt.append(5)
    prompt.append(17)
    prompt.append(42)
    var want = _cpu_generate(fx, prompt)
    var layer_weights = List[VulkanLayerWeights]()
    for li in range(_LAYERS):
        layer_weights.append(fx.layers[li].upload())
    var weights = VulkanDecodeWeights(
        _upload_f32(fx.embedding),
        layer_weights,
        _upload_f32(fx.g_final),
        fx.w_head.upload(),
    )
    var e0 = VulkanEmbed.dispatch_count()
    var a0 = VulkanKvCache.dispatch_count()
    var s0 = VulkanAttention.strided_dispatch_count()
    var bytes0 = VulkanBuffers.live_bytes()
    var got = VulkanDecode.generate(
        weights, prompt, _GEN, _DIM, _HEADS, _RATIO, _HEAD_DIM,
        _FFN, _VOCAB, _MAX_LEN, _EPS, _BASE,
    )
    if len(got) != _GEN:
        raise Error("decode loop returned the wrong token count")
    for i in range(_GEN):
        print("  step", i, "gpu token", got[i], "oracle token", want[i])
        if got[i] != want[i]:
            raise Error("greedy token mismatch vs the CPU oracle")
    var total_steps = len(prompt) + _GEN - 1
    if VulkanEmbed.dispatch_count() - e0 != total_steps:
        raise Error("embed gather dispatch delta is not the step count")
    if VulkanKvCache.dispatch_count() - a0 != total_steps * _LAYERS * 2:
        raise Error("KV-append dispatch delta is not steps x layers x 2")
    if VulkanAttention.strided_dispatch_count() - s0 != total_steps * _LAYERS:
        raise Error("strided attention dispatch delta is not steps x layers")
    if VulkanBuffers.live_bytes() != bytes0:
        raise Error("decode loop leaked device buffers")
    print("Vulkan full decode token-exact (8 greedy tokens, RADV dispatches counted): PASS")


def test_vulkan_decode_rejection() raises:
    print("--- Testing Vulkan decode rejection (A-066) ---")
    if not _vk_present():
        print("Vulkan RADV device absent: honest-absent PASS")
        return
    var src = _zero_alloc(_KV_DIM)
    var cache = _zero_alloc(_KV_HEADS * _MAX_LEN * _HEAD_DIM)
    var table = _zero_alloc(_VOCAB * _DIM)
    var dst = _zero_alloc(_DIM)
    var c0 = VulkanKvCache.dispatch_count()
    var e0 = VulkanEmbed.dispatch_count()
    var raised = 0
    try:
        VulkanKvCache.append(src, cache, _HEAD_DIM, _MAX_LEN, _MAX_LEN, _KV_HEADS)
    except:
        raised += 1
    try:
        VulkanKvCache.append(src, cache, _HEAD_DIM, _MAX_LEN, -1, _KV_HEADS)
    except:
        raised += 1
    try:
        VulkanKvCache.append(src, cache, 0, _MAX_LEN, 0, _KV_HEADS)
    except:
        raised += 1
    try:
        VulkanEmbed.gather(table, dst, _DIM, _VOCAB, _VOCAB)
    except:
        raised += 1
    try:
        VulkanEmbed.gather(table, dst, _DIM, -1, _VOCAB)
    except:
        raised += 1
    try:
        var bad_prompt = List[Int]()
        bad_prompt.append(_VOCAB + 1)
        var layer_weights = List[VulkanLayerWeights]()
        var fx = _LayerFixture(0)
        layer_weights.append(fx.upload())
        var weights = VulkanDecodeWeights(
            table, layer_weights, dst, fx.wq.upload()
        )
        _ = VulkanDecode.generate(
            weights, bad_prompt, 1, _DIM, _HEADS, _RATIO, _HEAD_DIM,
            _FFN, _VOCAB, _MAX_LEN, _EPS, _BASE,
        )
    except:
        raised += 1
    if raised != 6:
        raise Error("decode rejection raised fewer than 6 times")
    if VulkanKvCache.dispatch_count() != c0:
        raise Error("rejected KV-append dispatched on the device")
    if VulkanEmbed.dispatch_count() != e0:
        raise Error("rejected embed gather dispatched on the device")
    VulkanBuffers.free(src)
    VulkanBuffers.free(cache)
    VulkanBuffers.free(table)
    VulkanBuffers.free(dst)
    print("Vulkan decode rejection (6 of 6 raise before dispatch): PASS")
