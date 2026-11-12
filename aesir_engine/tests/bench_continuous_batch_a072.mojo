# tests/bench_continuous_batch_a072.mojo
# A-072: continuous batching bench (standalone, NOT part of
# run_all). Acceptance (roadmap A-072): a 4-sequence run,
# per-sequence outputs match their single-sequence runs
# (greedy), aggregate tokens/s filed.
#
# Geometry: the A-066 small fixture (dim 256, 4 heads,
# GQA ratio 2, head_dim 64, ffn 512, vocab 96, 2 layers),
# max_len 32, four prompts of length 3/2/5/1, 16 greedy
# tokens each = 64 generated tokens per run.
#
# Filed honestly: v1 batching issues the same per-sequence
# A-066 dispatches under the scheduler (no fused batched
# GEMV), so the batch aggregate is expected near the serial
# aggregate - the bench reports the measured ratio whatever
# it is. Timing: CLOCK_MONOTONIC around the full run
# (scheduler + dispatches + readbacks), median of 3 trials
# after 1 warmup, correctness (batch == solo token-exact)
# asserted on the warmup run.

from std.ffi import external_call
from std.memory import bitcast
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_layer import VulkanLayerWeights
from core.vulkan_decode import VulkanDecode, VulkanDecodeWeights
from core.vulkan_batch import VulkanBatchDecode

comptime _DIM = 256
comptime _HEADS = 4
comptime _RATIO = 2
comptime _HEAD_DIM = 64
comptime _KV_HEADS = 2
comptime _KV_DIM = 128
comptime _FFN = 512
comptime _VOCAB = 96
comptime _LAYERS = 2
comptime _MAX_LEN = 32
comptime _GEN = 16
comptime _EPS = Float32(1.0e-5)
comptime _BASE = Float32(10000.0)


def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("A072: cannot observe monotonic clock")
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




def _median3(a: Float64, b: Float64, c: Float64) -> Float64:
    if a > b:
        if b > c:
            return b
        return c if a > c else a
    if a > c:
        return a
    return c if b > c else b


def main() raises:
    if not _vk_present():
        print("A072_BENCH: SKIP (RADV device absent)")
        return
    var fx = _ModelFixture()
    var weights = _upload_weights(fx)
    var prompts = _four_prompts()
    var gens = List[Int]()
    for _ in range(4):
        gens.append(_GEN)
    var bytes0 = VulkanBuffers.live_bytes()
    # Warmup + correctness: batch tokens must equal solo tokens.
    var warm = VulkanBatchDecode.generate_batch(
        weights, prompts, gens, 4, _DIM, _HEADS, _RATIO, _HEAD_DIM,
        _FFN, _VOCAB, _MAX_LEN, _EPS, _BASE,
    )
    for i in range(4):
        var solo = VulkanDecode.generate(
            weights, prompts[i], _GEN, _DIM, _HEADS, _RATIO,
            _HEAD_DIM, _FFN, _VOCAB, _MAX_LEN, _EPS, _BASE,
        )
        if len(warm.outputs[i]) != _GEN:
            raise Error("A072 bench: warmup batch length wrong")
        for j in range(_GEN):
            if warm.outputs[i][j] != solo[j]:
                raise Error("A072 bench: batch != solo in warmup")
    print("warmup correctness: batch == solo for 4 sequences")
    var tokens = Float64(4 * _GEN)
    var solo_times = List[Float64]()
    var batch_times = List[Float64]()
    for _ in range(3):
        var t0 = monotonic_ns()
        for i in range(4):
            _ = VulkanDecode.generate(
                weights, prompts[i], _GEN, _DIM, _HEADS, _RATIO,
                _HEAD_DIM, _FFN, _VOCAB, _MAX_LEN, _EPS, _BASE,
            )
        solo_times.append(Float64(monotonic_ns() - t0) / 1.0e9)
        var t1 = monotonic_ns()
        _ = VulkanBatchDecode.generate_batch(
            weights, prompts, gens, 4, _DIM, _HEADS, _RATIO,
            _HEAD_DIM, _FFN, _VOCAB, _MAX_LEN, _EPS, _BASE,
        )
        batch_times.append(Float64(monotonic_ns() - t1) / 1.0e9)
    var solo_med = _median3(solo_times[0], solo_times[1], solo_times[2])
    var batch_med = _median3(batch_times[0], batch_times[1], batch_times[2])
    var solo_tps = tokens / solo_med
    var batch_tps = tokens / batch_med
    print("solo serial: median", solo_med, "s, aggregate", solo_tps, "tok/s")
    print("batch x4   : median", batch_med, "s, aggregate", batch_tps, "tok/s")
    print("batch/solo aggregate ratio:", batch_tps / solo_tps)
    if VulkanBuffers.live_bytes() != bytes0:
        raise Error("A072 bench: device buffers leaked")
    _free_weights(weights)
    print("A072_BENCH: PASS")
