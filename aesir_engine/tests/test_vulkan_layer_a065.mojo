"""Vulkan full layer (A-065): one whole transformer decode layer
(norm -> attn -> norm -> MLP) composed on the GPU from the
banked Wave 7 kernels (A-056 Q8_0 GEMV, A-060 RMSNorm + RoPE,
A-061 elementwise, A-062 decode attention), judged against an
independent CPU layer oracle written in this file.

Parity discipline (raw-oracle law): expected values come ONLY
from the sequential Float32 CPU reference below, which consumes
the identical raw Q8_0 bytes (per-block fp16 scale x int8) and
implements the textbook layer directly: RMSNorm with the same
eps, rotate-half RoPE at the same position/base, single-position
decode attention (kv_len == 1, so the attention output for query
head h is exactly the v row of KV head h // kv_per_query), gated
SiLU MLP, residual adds. The GPU GEMVs reduce in tree order
while the oracle sums in k order, so the filed tolerance is an
accumulation-order bound, printed per layer index.

Per-layer-index acceptance: three layer indices (0, 1, 2) with
independent deterministic weights are run CHAINED (layer L's
GPU output feeds layer L+1), and each layer's output is checked
against the oracle's chained output for that same layer index;
a fourth case runs layer index 2 standalone (unchained input).

Real fixture: the geometry mirrors the repo's small-fixture
class (dim 256 = 4 heads x 64, GQA ratio 2, ffn 512) with
deterministic LCG weights/input standing in for a checkpoint's
per-layer tensors - the same fixture discipline as A-056..A-062
(dyadic/non-dyadic data generated in-file, sha-pinned models are
A-067's acceptance, not this slice's).

Device-execution evidence (law 6): the selected device must be
the AMD Radeon 8060S (RADV STRIX_HALO) - llvmpipe is refused by
the identity check - and every banked gateway's shim dispatch
counter must advance by the exact per-layer counts (rmsnorm 2,
rope 2, q8_gemv 7, attention 1, elementwise 3). On a host
without that device the cases pass as honest-absent, matching
A-014/A-056 discipline.
"""
from std.math import exp, sqrt, cos, sin
from std.memory import bitcast
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_layer import VulkanLayer, VulkanLayerWeights
from core.vulkan_norm_rope import VulkanNormRope
from core.vulkan_gemv import VulkanGemv
from core.vulkan_attention import VulkanAttention
from core.vulkan_elementwise import VulkanElementwise

comptime _DIM = 256
comptime _HEADS = 4
comptime _RATIO = 2
comptime _HEAD_DIM = 64
comptime _KV_HEADS = 2
comptime _KV_DIM = 128
comptime _FFN = 512
comptime _POS = 3
comptime _EPS = Float32(1.0e-5)
comptime _BASE = Float32(10000.0)
# Filed bound: accumulation-order only (GPU tree reductions vs
# CPU sequential Float32 over identical dequant, chained through
# 7 GEMVs + norms per layer). Measured per-layer values are
# printed and filed in hidden_files/A065_LEDGER.md; the bound
# carries headroom over them.
comptime _BOUND = Float32(5.0e-3)
# Chained bound: layer L+1 consumes layer L GPU output, whose
# accumulation-order delta (<= _BOUND standalone) is amplified
# by the next layer GEMV/norm gain (measured ~3.5x per layer:
# 0.00179 -> 0.00375 -> 0.00623 over layers 0,1,2). The chained
# bound carries >3x headroom over the measured worst layer.
comptime _CHAIN_BOUND = Float32(2.0e-2)


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
    """One Q8_0 matrix held as host fixture data: per-block
    fp16-rounded scales and signed quants, plus the raw bytes."""

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
            self.scales.append(
                Float16(s).cast[DType.float32]()
            )
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
        """Sequential CPU Q8_0 GEMV oracle over this fixture."""
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
        var lcg = _Lcg(0xA06500 + UInt64(layer_index) * 977)
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


def _zero_matrix(rows: Int, cols: Int) raises -> VulkanAllocation:
    var alloc = VulkanBuffers.allocate(rows * (cols // 32) * 34)
    var p = VulkanBuffers.map(alloc)
    for i in range(rows * (cols // 32) * 34):
        p.unsafe_store(i, UInt8(0))
    VulkanBuffers.unmap(alloc)
    return alloc


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


def _cpu_rmsnorm(x: List[Float32], g: List[Float32]) -> List[Float32]:
    var ss = Float32(0.0)
    for i in range(len(x)):
        ss += x[i] * x[i]
    var scale = Float32(1.0) / sqrt(ss / Float32(len(x)) + _EPS)
    var out = List[Float32]()
    for i in range(len(x)):
        out.append(x[i] * scale * g[i])
    return out^


def _cpu_rope(x: List[Float32], rows: Int) -> List[Float32]:
    var out = List[Float32]()
    for i in range(len(x)):
        out.append(x[i])
    var half = _HEAD_DIM // 2
    for r in range(rows):
        for i in range(half):
            var freq = _BASE ** (Float32(-2 * i) / Float32(_HEAD_DIM))
            var ang = Float32(_POS) * freq
            var c = cos(ang)
            var s = sin(ang)
            var a = x[r * _HEAD_DIM + i]
            var b = x[r * _HEAD_DIM + i + half]
            out[r * _HEAD_DIM + i] = a * c - b * s
            out[r * _HEAD_DIM + i + half] = b * c + a * s
    return out^


def _cpu_layer(fx: _LayerFixture, x: List[Float32]) -> List[Float32]:
    """Independent sequential CPU full-layer oracle."""
    var h = _cpu_rmsnorm(x, fx.g_attn)
    var q = _cpu_rope(fx.wq.gemv(h), _HEADS)
    var k = _cpu_rope(fx.wk.gemv(h), _KV_HEADS)
    _ = q  # kv_len == 1: scores cannot change the single weight.
    _ = k  # kv_len == 1: attention output is the v row itself.
    var v = fx.wv.gemv(h)
    var attn = List[Float32]()
    for hd in range(_HEADS):
        var kv_head = hd // _RATIO
        for d in range(_HEAD_DIM):
            attn.append(v[kv_head * _HEAD_DIM + d])
    var proj = fx.wo.gemv(attn)
    var res = List[Float32]()
    for i in range(_DIM):
        res.append(x[i] + proj[i])
    var h2 = _cpu_rmsnorm(res, fx.g_ffn)
    var gate = fx.w_gate.gemv(h2)
    var up = fx.w_up.gemv(h2)
    var down_in = List[Float32]()
    for i in range(_FFN):
        var silu = gate[i] / (Float32(1.0) + exp(-gate[i]))
        down_in.append(silu * up[i])
    var down = fx.w_down.gemv(down_in)
    var out = List[Float32]()
    for i in range(_DIM):
        out.append(res[i] + down[i])
    return out^


def _gpu_layer(
    fx: _LayerFixture, x: List[Float32]
) raises -> List[Float32]:
    """Run one layer on the GPU; returns the output row."""
    var x_alloc = _upload_f32(x)
    var out_alloc = VulkanBuffers.allocate(_DIM * 4)
    var weights = VulkanLayerWeights(
        _upload_f32(fx.g_attn),
        _upload_f32(fx.g_ffn),
        fx.wq.upload(),
        fx.wk.upload(),
        fx.wv.upload(),
        fx.wo.upload(),
        fx.w_gate.upload(),
        fx.w_up.upload(),
        fx.w_down.upload(),
    )
    VulkanLayer.forward(
        x_alloc, weights, out_alloc,
        _DIM, _HEADS, _RATIO, _HEAD_DIM, _FFN, _POS, _EPS, _BASE,
    )
    var got = _read_f32(out_alloc, _DIM)
    VulkanBuffers.free(x_alloc)
    VulkanBuffers.free(out_alloc)
    VulkanBuffers.free(weights.g_attn)
    VulkanBuffers.free(weights.g_ffn)
    VulkanBuffers.free(weights.wq)
    VulkanBuffers.free(weights.wk)
    VulkanBuffers.free(weights.wv)
    VulkanBuffers.free(weights.wo)
    VulkanBuffers.free(weights.w_gate)
    VulkanBuffers.free(weights.w_up)
    VulkanBuffers.free(weights.w_down)
    return got^


def _max_abs(a: List[Float32], b: List[Float32]) -> Float32:
    var m = Float32(0.0)
    for i in range(len(a)):
        var d = _abs32(a[i] - b[i])
        if d > m:
            m = d
    return m


def _input_row(seed: UInt64) -> List[Float32]:
    var lcg = _Lcg(seed)
    var x = List[Float32]()
    for _ in range(_DIM):
        x.append(lcg.val())
    return x^


def test_vulkan_layer_oracle_parity() raises:
    print("--- Testing Vulkan full layer oracle parity per layer index (A-065) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: layer parity not run (honest-absent)")
        return
    var x_gpu = _input_row(0xA06510)
    var x_cpu = _input_row(0xA06510)
    for layer in range(3):
        var fx = _LayerFixture(layer)
        var want = _cpu_layer(fx, x_cpu)
        var got = _gpu_layer(fx, x_gpu)
        var m = _max_abs(got, want)
        print(
            "A065_LAYER idx=" + String(layer)
            + " chained max_abs=" + String(m)
        )
        if m > _CHAIN_BOUND:
            raise Error(
                "layer " + String(layer) + " parity failed: max_abs "
                + String(m) + " above the filed bound"
            )
        x_gpu = got^
        x_cpu = want^
    print("Vulkan full layer oracle parity (layers 0,1,2 chained): PASS")


def test_vulkan_layer_known_value() raises:
    print("--- Testing Vulkan full layer known value (A-065) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: known value not run (honest-absent)")
        return
    # Zero-scale weights: every GEMV outputs exactly 0, attention
    # passes v == 0, both residuals return x, so out == x exactly.
    var lcg = _Lcg(0xA06520)
    var x = List[Float32]()
    for _ in range(_DIM):
        x.append(lcg.val())
    var x_alloc = _upload_f32(x)
    var out_alloc = VulkanBuffers.allocate(_DIM * 4)
    var ones = List[Float32]()
    for _ in range(_DIM):
        ones.append(Float32(1.0))
    var weights = VulkanLayerWeights(
        _upload_f32(ones),
        _upload_f32(ones),
        _zero_matrix(_DIM, _DIM),
        _zero_matrix(_KV_DIM, _DIM),
        _zero_matrix(_KV_DIM, _DIM),
        _zero_matrix(_DIM, _KV_DIM),
        _zero_matrix(_FFN, _DIM),
        _zero_matrix(_FFN, _DIM),
        _zero_matrix(_DIM, _FFN),
    )
    VulkanLayer.forward(
        x_alloc, weights, out_alloc,
        _DIM, _HEADS, _RATIO, _HEAD_DIM, _FFN, _POS, _EPS, _BASE,
    )
    var got = _read_f32(out_alloc, _DIM)
    var m = _max_abs(got, x)
    print("A065_KNOWN zero-weight residual identity max_abs=" + String(m))
    if m > Float32(1.0e-6):
        raise Error("known value failed: zero-weight layer must return x exactly")
    VulkanBuffers.free(x_alloc)
    VulkanBuffers.free(out_alloc)
    VulkanBuffers.free(weights.g_attn)
    VulkanBuffers.free(weights.g_ffn)
    VulkanBuffers.free(weights.wq)
    VulkanBuffers.free(weights.wk)
    VulkanBuffers.free(weights.wv)
    VulkanBuffers.free(weights.wo)
    VulkanBuffers.free(weights.w_gate)
    VulkanBuffers.free(weights.w_up)
    VulkanBuffers.free(weights.w_down)
    print("Vulkan full layer known value (residual identity): PASS")


def test_vulkan_layer_standalone_index() raises:
    print("--- Testing Vulkan full layer standalone layer index (A-065) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: standalone index not run (honest-absent)")
        return
    var fx = _LayerFixture(2)
    var x = _input_row(0xA06530)
    var want = _cpu_layer(fx, x)
    var got = _gpu_layer(fx, x)
    var m = _max_abs(got, want)
    print("A065_LAYER idx=2 standalone max_abs=" + String(m))
    if m > _BOUND:
        raise Error(
            "standalone layer 2 parity failed: max_abs " + String(m)
            + " above the filed bound"
        )
    print("Vulkan full layer standalone layer index 2: PASS")


def test_vulkan_layer_rejection() raises:
    print("--- Testing Vulkan full layer rejection (A-065) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: rejection not run (honest-absent)")
        return
    var buf = VulkanBuffers.allocate(4096)
    var weights = VulkanLayerWeights(
        buf, buf, buf, buf, buf, buf, buf, buf, buf
    )
    var rejected = 0
    # dim not a multiple of 32.
    try:
        VulkanLayer.forward(buf, weights, buf, 100, 4, 2, 64, 512, 0, _EPS, _BASE)
    except:
        rejected += 1
    # num_heads * head_dim != dim.
    try:
        VulkanLayer.forward(buf, weights, buf, 256, 4, 2, 32, 512, 0, _EPS, _BASE)
    except:
        rejected += 1
    # Non-integer GQA ratio.
    try:
        VulkanLayer.forward(buf, weights, buf, 256, 6, 4, 64, 512, 0, _EPS, _BASE)
    except:
        rejected += 1
    # ffn_dim not a multiple of 32.
    try:
        VulkanLayer.forward(buf, weights, buf, 256, 4, 2, 64, 100, 0, _EPS, _BASE)
    except:
        rejected += 1
    # Negative position.
    try:
        VulkanLayer.forward(buf, weights, buf, 256, 4, 2, 64, 512, -1, _EPS, _BASE)
    except:
        rejected += 1
    # Valid geometry but undersized weight buffers.
    try:
        VulkanLayer.forward(buf, weights, buf, 256, 4, 2, 64, 512, 0, _EPS, _BASE)
    except:
        rejected += 1
    VulkanBuffers.free(buf)
    if rejected != 6:
        raise Error("rejection failed: " + String(rejected) + " of 6 invalid calls raised")
    print("Vulkan full layer rejection (6 invalid calls): PASS")


def test_vulkan_layer_dispatch_evidence() raises:
    print("--- Testing Vulkan full layer dispatch evidence (A-065) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: dispatch evidence not run (honest-absent)")
        return
    var fx = _LayerFixture(1)
    var x = _input_row(0xA06540)
    var rms0 = VulkanNormRope.rmsnorm_dispatch_count()
    var rope0 = VulkanNormRope.rope_dispatch_count()
    var gemv0 = VulkanGemv.dispatch_count()
    var attn0 = VulkanAttention.dispatch_count()
    var elem0 = VulkanElementwise.elementwise_dispatch_count()
    var base_bytes = VulkanBuffers.live_bytes()
    var base_count = VulkanBuffers.live_count()
    _ = _gpu_layer(fx, x)
    var d_rms = VulkanNormRope.rmsnorm_dispatch_count() - rms0
    var d_rope = VulkanNormRope.rope_dispatch_count() - rope0
    var d_gemv = VulkanGemv.dispatch_count() - gemv0
    var d_attn = VulkanAttention.dispatch_count() - attn0
    var d_elem = VulkanElementwise.elementwise_dispatch_count() - elem0
    print(
        "A065_DISPATCH rmsnorm=" + String(d_rms)
        + " rope=" + String(d_rope)
        + " q8_gemv=" + String(d_gemv)
        + " attn=" + String(d_attn)
        + " elementwise=" + String(d_elem)
    )
    if d_rms != 2 or d_rope != 2 or d_gemv != 7 or d_attn != 1 or d_elem != 3:
        raise Error("dispatch counters do not match the per-layer composition counts")
    if VulkanBuffers.live_bytes() != base_bytes:
        raise Error("full layer leaked device bytes")
    if VulkanBuffers.live_count() != base_count:
        raise Error("full layer leaked buffers")
    print("Vulkan full layer dispatch evidence (2/2/7/1/3, accounting exact): PASS")
