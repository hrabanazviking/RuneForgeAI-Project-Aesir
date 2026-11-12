"""Vulkan continuous batching v1 (A-072): multiple sequences
decoded together on the GPU path via the iteration-level
scheduler in core/vulkan_batch.mojo over the banked A-066
decode step.

Acceptance (roadmap A-072): a 4-sequence run whose
per-sequence outputs match their single-sequence runs
(greedy), with aggregate tokens/s filed (bench doc). The
solo reference is VulkanDecode.generate itself (A-066),
whose output is already proven token-exact vs the
sequential Float32 CPU oracle; case 1 re-anchors sequence 0
to that oracle directly so the chain batch == solo ==
oracle is closed in this file too. Prompts enter as RAW
token ids - no chat template exists anywhere in this path.

Scheduler semantics under test (defined in the gateway
header): at most max_active sequences resident; free slots
refill from the waiting queue in request order at iteration
starts; a sequence admitted mid-run starts at position 0
with isolated KV caches while batchmates are mid-context;
one iteration advances every resident sequence by one
position; a sequence leaves in the iteration of its final
step. admitted_at / finished_at are asserted exactly
against hand-computed schedules.

Device-execution evidence (law 6): the selected device must
be the AMD Radeon 8060S (RADV STRIX_HALO) - llvmpipe is
refused by the identity check - and the shim dispatch
counters must advance by the exact per-run counts summed
over sequences (embed_gather = total steps, kv_append =
steps x layers x 2, strided attention = steps x layers,
greedy = generated tokens). On a host without that device
the cases pass as honest-absent, matching A-014/A-066
discipline.
"""
from std.math import exp, sqrt, cos, sin
from std.memory import bitcast
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_layer import VulkanLayerWeights
from core.vulkan_kv_cache import VulkanKvCache, VulkanEmbed
from core.vulkan_attention import VulkanAttention
from core.vulkan_sampling import VulkanSampling
from core.vulkan_decode import VulkanDecode, VulkanDecodeWeights
from core.vulkan_batch import VulkanBatchDecode, VulkanBatchResult

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
comptime _EPS = Float32(1.0e-5)
comptime _BASE = Float32(10000.0)


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


def _free_weights(weights: VulkanDecodeWeights) raises:
    # The shim caps live buffers at 128 slots; cases must
    # hand their fixture weights back or later cases starve.
    for li in range(len(weights.layers)):
        var w = weights.layers[li]
        VulkanBuffers.free(w.g_attn)
        VulkanBuffers.free(w.g_ffn)
        VulkanBuffers.free(w.wq)
        VulkanBuffers.free(w.wk)
        VulkanBuffers.free(w.wv)
        VulkanBuffers.free(w.wo)
        VulkanBuffers.free(w.w_gate)
        VulkanBuffers.free(w.w_up)
        VulkanBuffers.free(w.w_down)
    VulkanBuffers.free(weights.embedding)
    VulkanBuffers.free(weights.g_final)
    VulkanBuffers.free(weights.w_head)


def _prompt0() -> List[Int]:
    var p = List[Int]()
    p.append(5)
    p.append(17)
    p.append(42)
    return p^


def _prompt1() -> List[Int]:
    var p = List[Int]()
    p.append(11)
    p.append(3)
    return p^


def _prompt2() -> List[Int]:
    var p = List[Int]()
    p.append(90)
    p.append(7)
    p.append(7)
    p.append(33)
    p.append(1)
    return p^


def _prompt3() -> List[Int]:
    var p = List[Int]()
    p.append(64)
    return p^


def _four_prompts() -> List[List[Int]]:
    var ps = List[List[Int]]()
    ps.append(_prompt0())
    ps.append(_prompt1())
    ps.append(_prompt2())
    ps.append(_prompt3())
    return ps^


def _solo(
    weights: VulkanDecodeWeights, prompt: List[Int], gen: Int
) raises -> List[Int]:
    return VulkanDecode.generate(
        weights, prompt, gen, _DIM, _HEADS, _RATIO, _HEAD_DIM,
        _FFN, _VOCAB, _MAX_LEN, _EPS, _BASE,
    )


def _batch(
    weights: VulkanDecodeWeights,
    prompts: List[List[Int]],
    gens: List[Int],
    max_active: Int,
) raises -> VulkanBatchResult:
    return VulkanBatchDecode.generate_batch(
        weights, prompts, gens, max_active, _DIM, _HEADS, _RATIO,
        _HEAD_DIM, _FFN, _VOCAB, _MAX_LEN, _EPS, _BASE,
    )


def _assert_same(got: List[Int], want: List[Int], what: String) raises:
    if len(got) != len(want):
        raise Error("batch output length mismatch: " + what)
    for i in range(len(want)):
        if got[i] != want[i]:
            raise Error("batch token mismatch vs solo: " + what)


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
    fx: _ModelFixture, prompt: List[Int], gen: Int
) -> List[Int]:
    """Independent sequential Float32 full-decode oracle
    (A-066 discipline, RAW prompt token ids)."""
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
    var total_steps = len(prompt) + gen - 1
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
            for i in range(len(logits)):
                if logits[i] > best_val:
                    best_val = logits[i]
                    best = i
            generated.append(best)
            tokens.append(best)
    return generated^


def test_vulkan_continuous_batch_four_match_single() raises:
    print("--- Testing Vulkan continuous batch 4-seq vs solo (A-072) ---")
    if not _vk_present():
        print("Vulkan RADV device absent: honest-absent PASS")
        return
    var fx = _ModelFixture()
    var weights = _upload_weights(fx)
    var prompts = _four_prompts()
    var gens = List[Int]()
    for _ in range(4):
        gens.append(8)
    var bytes0 = VulkanBuffers.live_bytes()
    var solos = List[List[Int]]()
    for i in range(4):
        solos.append(_solo(weights, prompts[i], 8))
    var oracle0 = _cpu_generate(fx, prompts[0], 8)
    _assert_same(solos[0], oracle0, "solo seq0 vs CPU oracle anchor")
    var e0 = VulkanEmbed.dispatch_count()
    var a0 = VulkanKvCache.dispatch_count()
    var s0 = VulkanAttention.strided_dispatch_count()
    var g0 = VulkanSampling.greedy_dispatch_count()
    var result = _batch(weights, prompts, gens, 4)
    if result.iterations != 12:
        raise Error("batch iterations != max total steps (12)")
    for i in range(4):
        _assert_same(result.outputs[i], solos[i], "seq vs solo")
        print("  seq", i, "tokens", result.outputs[i])
        if result.admitted_at[i] != 0:
            raise Error("all four must be admitted at iteration 0")
    # total steps per seq: 10, 9, 12, 8 -> sums 39 steps, 32 greedy.
    if VulkanEmbed.dispatch_count() - e0 != 39:
        raise Error("embed dispatch delta is not the summed step count")
    if VulkanKvCache.dispatch_count() - a0 != 39 * _LAYERS * 2:
        raise Error("KV-append delta is not steps x layers x 2")
    if VulkanAttention.strided_dispatch_count() - s0 != 39 * _LAYERS:
        raise Error("strided attention delta is not steps x layers")
    if VulkanSampling.greedy_dispatch_count() - g0 != 32:
        raise Error("greedy delta is not the summed generated count")
    if VulkanBuffers.live_bytes() != bytes0:
        raise Error("batch run leaked device buffers")
    _free_weights(weights)
    print("Vulkan continuous batch 4-seq match solo + oracle anchor: PASS")


def test_vulkan_continuous_batch_heterogeneous() raises:
    print("--- Testing Vulkan continuous batch heterogeneous (A-072) ---")
    if not _vk_present():
        print("Vulkan RADV device absent: honest-absent PASS")
        return
    var fx = _ModelFixture()
    var weights = _upload_weights(fx)
    var prompts = _four_prompts()
    var gens = List[Int]()
    gens.append(4)
    gens.append(8)
    gens.append(6)
    gens.append(3)
    var result = _batch(weights, prompts, gens, 4)
    # totals 6, 9, 10, 3 -> finishes at iterations 5, 8, 9, 2.
    var want_finish = List[Int]()
    want_finish.append(5)
    want_finish.append(8)
    want_finish.append(9)
    want_finish.append(2)
    if result.iterations != 10:
        raise Error("heterogeneous iterations != 10")
    for i in range(4):
        var solo = _solo(weights, prompts[i], gens[i])
        _assert_same(result.outputs[i], solo, "heterogeneous seq vs solo")
        if result.finished_at[i] != want_finish[i]:
            raise Error("heterogeneous finish schedule mismatch")
    _free_weights(weights)
    print("Vulkan continuous batch heterogeneous lengths/gens: PASS")


def test_vulkan_continuous_batch_dynamic_admission() raises:
    print("--- Testing Vulkan continuous batch admission (A-072) ---")
    if not _vk_present():
        print("Vulkan RADV device absent: honest-absent PASS")
        return
    var fx = _ModelFixture()
    var weights = _upload_weights(fx)
    var prompts = _four_prompts()
    var gens = List[Int]()
    gens.append(4)
    gens.append(8)
    gens.append(6)
    gens.append(3)
    var bytes0 = VulkanBuffers.live_bytes()
    var result = _batch(weights, prompts, gens, 2)
    # max_active 2, totals 6, 9, 10, 3: seq0 fin 5 -> seq2 in at 6,
    # fin 15; seq1 fin 8 -> seq3 in at 9, fin 11; 16 iterations.
    var want_admit = List[Int]()
    want_admit.append(0)
    want_admit.append(0)
    want_admit.append(6)
    want_admit.append(9)
    var want_finish = List[Int]()
    want_finish.append(5)
    want_finish.append(8)
    want_finish.append(15)
    want_finish.append(11)
    if result.iterations != 16:
        raise Error("admission-run iterations != 16")
    for i in range(4):
        if result.admitted_at[i] != want_admit[i]:
            raise Error("admission schedule mismatch")
        if result.finished_at[i] != want_finish[i]:
            raise Error("admission-run finish schedule mismatch")
        var solo = _solo(weights, prompts[i], gens[i])
        _assert_same(result.outputs[i], solo, "admitted seq vs solo")
    if VulkanBuffers.live_bytes() != bytes0:
        raise Error("admission run leaked device buffers")
    _free_weights(weights)
    print("Vulkan continuous batch dynamic admission (2-slot churn): PASS")


def test_vulkan_continuous_batch_isolation() raises:
    print("--- Testing Vulkan continuous batch isolation (A-072) ---")
    if not _vk_present():
        print("Vulkan RADV device absent: honest-absent PASS")
        return
    var fx = _ModelFixture()
    var weights = _upload_weights(fx)
    var gens = List[Int]()
    for _ in range(4):
        gens.append(8)
    var base = _batch(weights, _four_prompts(), gens, 4)
    var alt_prompts = List[List[Int]]()
    var p0_alt = List[Int]()
    p0_alt.append(6)
    p0_alt.append(17)
    p0_alt.append(42)
    alt_prompts.append(p0_alt.copy())
    alt_prompts.append(_prompt1())
    alt_prompts.append(_prompt2())
    alt_prompts.append(_prompt3())
    var alt = _batch(weights, alt_prompts, gens, 4)
    for i in range(1, 4):
        _assert_same(alt.outputs[i], base.outputs[i], "batchmate isolation")
    var solo_alt0 = _solo(weights, alt_prompts[0], 8)
    _assert_same(alt.outputs[0], solo_alt0, "substituted seq vs its solo")
    _free_weights(weights)
    print("Vulkan continuous batch isolation (no KV cross-talk): PASS")


def test_vulkan_continuous_batch_rejection() raises:
    print("--- Testing Vulkan continuous batch rejection (A-072) ---")
    if not _vk_present():
        print("Vulkan RADV device absent: honest-absent PASS")
        return
    var fx = _ModelFixture()
    var weights = _upload_weights(fx)
    var e0 = VulkanEmbed.dispatch_count()
    var a0 = VulkanKvCache.dispatch_count()
    var bytes0 = VulkanBuffers.live_bytes()
    var raised = 0
    var gens_ok = List[Int]()
    gens_ok.append(4)
    # 1: no requests at all.
    try:
        _ = _batch(weights, List[List[Int]](), List[Int](), 4)
    except:
        raised += 1
    # 2: gen_steps length mismatch.
    try:
        var ps = List[List[Int]]()
        ps.append(_prompt0())
        ps.append(_prompt1())
        _ = _batch(weights, ps, gens_ok, 4)
    except:
        raised += 1
    # 3: max_active zero.
    try:
        var ps = List[List[Int]]()
        ps.append(_prompt0())
        _ = _batch(weights, ps, gens_ok, 0)
    except:
        raised += 1
    # 4: empty prompt inside the batch.
    try:
        var ps = List[List[Int]]()
        ps.append(_prompt0())
        ps.append(List[Int]())
        var gs = List[Int]()
        gs.append(4)
        gs.append(4)
        _ = _batch(weights, ps, gs, 4)
    except:
        raised += 1
    # 5: zero gen_steps for one request.
    try:
        var ps = List[List[Int]]()
        ps.append(_prompt0())
        var gs = List[Int]()
        gs.append(0)
        _ = _batch(weights, ps, gs, 4)
    except:
        raised += 1
    # 6: prompt token out of vocab range.
    try:
        var bad = List[Int]()
        bad.append(_VOCAB + 5)
        var ps = List[List[Int]]()
        ps.append(bad.copy())
        _ = _batch(weights, ps, gens_ok, 4)
    except:
        raised += 1
    # 7: prompt + gen exceeds max_len (3 + 14 > 16).
    try:
        var ps = List[List[Int]]()
        ps.append(_prompt0())
        var gs = List[Int]()
        gs.append(14)
        _ = _batch(weights, ps, gs, 4)
    except:
        raised += 1
    if raised != 7:
        raise Error("batch rejection raised fewer than 7 times")
    if VulkanEmbed.dispatch_count() != e0:
        raise Error("rejected batch dispatched embed gathers")
    if VulkanKvCache.dispatch_count() != a0:
        raise Error("rejected batch dispatched KV appends")
    if VulkanBuffers.live_bytes() != bytes0:
        raise Error("rejected batch allocated device buffers")
    _free_weights(weights)
    print("Vulkan continuous batch rejection (7 of 7 pre-dispatch): PASS")


def test_vulkan_continuous_batch_single_slot_serial() raises:
    print("--- Testing Vulkan continuous batch max_active=1 (A-072) ---")
    if not _vk_present():
        print("Vulkan RADV device absent: honest-absent PASS")
        return
    var fx = _ModelFixture()
    var weights = _upload_weights(fx)
    var prompts = _four_prompts()
    var gens = List[Int]()
    for _ in range(4):
        gens.append(8)
    var result = _batch(weights, prompts, gens, 1)
    # Serialised by the scheduler: totals 10, 9, 12, 8 run back
    # to back -> 39 iterations, admissions at 0, 10, 19, 31.
    var want_admit = List[Int]()
    want_admit.append(0)
    want_admit.append(10)
    want_admit.append(19)
    want_admit.append(31)
    if result.iterations != 39:
        raise Error("single-slot iterations != summed total steps")
    for i in range(4):
        if result.admitted_at[i] != want_admit[i]:
            raise Error("single-slot admission schedule mismatch")
        var solo = _solo(weights, prompts[i], 8)
        _assert_same(result.outputs[i], solo, "single-slot seq vs solo")
    _free_weights(weights)
    print("Vulkan continuous batch single-slot serial equivalence: PASS")
