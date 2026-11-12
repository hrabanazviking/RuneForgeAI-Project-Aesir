"""Vulkan chunked prefill (A-069): long prompts processed in
chunks with KV written incrementally on GPU, judged against
an independent sequential Float32 CPU oracle in this file and
against the unchunked (single-chunk) GPU pass.

The prefill layer composes the banked gateways (A-068 F32
GEMM, A-060 RMSNorm, A-061 elementwise) with three new A-069
kernels (rope_batched with GLOBAL positions, kv_append_chunk,
attention_prefill with no materialised score matrix).

Parity discipline (raw-oracle law):
- CPU oracle: per token, in prompt order, textbook layer -
  RMSNorm, dense projections, rotate-half RoPE at the token's
  global position, causal attention over the oracle KV cache
  accumulated from earlier tokens, gated SiLU MLP, residuals.
  The GPU GEMMs reduce in tree order while the oracle sums in
  k order, so the filed bound is an accumulation-order bound.
- Identical to unchunked (acceptance): the same GPU pipeline
  run with chunk_size == seq must reproduce the chunked run;
  every kernel's math is per-token independent of the chunk
  partition (GEMM workgroups are per (row, token), RoPE uses
  global positions, attention accumulates positions in the
  same increasing order, KV appends are bit-exact copies), so
  the filed expectation is bitwise equality, asserted with a
  small accumulation-order allowance and printed.
- Causal isolation: perturbing a later token must leave every
  earlier token's output bitwise unchanged - this catches
  bidirectional leakage inside a chunk.
- RoPE positions: a dedicated kernel case pins global
  positions across a chunk boundary and asserts the result
  differs from chunk-local (restarted) positions.

Device-execution evidence (law 6): the selected device must
be the AMD Radeon 8060S (RADV STRIX_HALO) - llvmpipe is
refused by the identity check - and the A-069 shim counters
must advance by the exact per-chunk counts (rope_batched 2,
kv_append_chunk 2, attention_prefill 1 per chunk, plus the
composed gateways' rmsnorm 2 / f32_gemm 7 / elementwise 3).
On a host without that device the cases pass as honest-absent,
matching A-014/A-056 discipline.
"""
from std.math import exp, sqrt, cos, sin
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_prefill import VulkanPrefillKernels, VulkanPrefillWeights, VulkanChunkedPrefill
from core.vulkan_norm_rope import VulkanNormRope
from core.vulkan_gemm import VulkanGemm
from core.vulkan_elementwise import VulkanElementwise

comptime _DIM = 64
comptime _HEADS = 2
comptime _RATIO = 1
comptime _HEAD_DIM = 32
comptime _KV_HEADS = 2
comptime _KV_DIM = 64
comptime _FFN = 64
comptime _EPS = Float32(1.0e-5)
comptime _BASE = Float32(10000.0)
# Filed bound: accumulation-order only (GPU tree reductions vs
# CPU sequential Float32 over identical dense operands,
# chained through 7 GEMMs + norms + one causal attention).
comptime _BOUND = Float32(2.0e-3)


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


struct _F32Matrix:
    var rows: Int
    var cols: Int
    var vals: List[Float32]

    def __init__(out self, rows: Int, cols: Int, mut lcg: _Lcg, scale: Float32):
        self.rows = rows
        self.cols = cols
        self.vals = List[Float32]()
        for _ in range(rows * cols):
            self.vals.append(lcg.val() * scale)

    def upload(self) raises -> VulkanAllocation:
        var alloc = VulkanBuffers.allocate(len(self.vals) * 4)
        var p = VulkanBuffers.map(alloc)
        var f = p.unsafe_bitcast[Float32]()
        for i in range(len(self.vals)):
            f.unsafe_store(i, self.vals[i])
        VulkanBuffers.unmap(alloc)
        return alloc

    def matvec(self, x: List[Float32]) -> List[Float32]:
        var out = List[Float32]()
        for r in range(self.rows):
            var acc = Float32(0.0)
            for k in range(self.cols):
                acc += self.vals[r * self.cols + k] * x[k]
            out.append(acc)
        return out^


struct _PrefillFixture:
    var g_attn: List[Float32]
    var g_ffn: List[Float32]
    var wq: _F32Matrix
    var wk: _F32Matrix
    var wv: _F32Matrix
    var wo: _F32Matrix
    var w_gate: _F32Matrix
    var w_up: _F32Matrix
    var w_down: _F32Matrix

    def __init__(out self):
        var lcg = _Lcg(0xA06900)
        self.g_attn = List[Float32]()
        self.g_ffn = List[Float32]()
        for _ in range(_DIM):
            self.g_attn.append(Float32(0.75) + lcg.unit() * Float32(0.5))
        for _ in range(_DIM):
            self.g_ffn.append(Float32(0.75) + lcg.unit() * Float32(0.5))
        self.wq = _F32Matrix(_DIM, _DIM, lcg, Float32(0.20))
        self.wk = _F32Matrix(_KV_DIM, _DIM, lcg, Float32(0.20))
        self.wv = _F32Matrix(_KV_DIM, _DIM, lcg, Float32(0.20))
        self.wo = _F32Matrix(_DIM, _KV_DIM, lcg, Float32(0.20))
        self.w_gate = _F32Matrix(_FFN, _DIM, lcg, Float32(0.20))
        self.w_up = _F32Matrix(_FFN, _DIM, lcg, Float32(0.20))
        self.w_down = _F32Matrix(_DIM, _FFN, lcg, Float32(0.20))


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


def _prompt_xs(seq: Int) -> List[Float32]:
    var lcg = _Lcg(0xA06911)
    var xs = List[Float32]()
    for _ in range(seq * _DIM):
        xs.append(lcg.val())
    return xs^


def _cpu_rmsnorm_row(x: List[Float32], off: Int, g: List[Float32]) -> List[Float32]:
    var ss = Float32(0.0)
    for i in range(_DIM):
        ss += x[off + i] * x[off + i]
    var scale = Float32(1.0) / sqrt(ss / Float32(_DIM) + _EPS)
    var out = List[Float32]()
    for i in range(_DIM):
        out.append(x[off + i] * scale * g[i])
    return out^


def _cpu_rope_row(mut row: List[Float32], head_dim: Int, position: Int):
    var half = head_dim // 2
    for i in range(half):
        var freq = _BASE ** (Float32(-2 * i) / Float32(head_dim))
        var ang = Float32(position) * freq
        var c = cos(ang)
        var s = sin(ang)
        var a = row[i]
        var b = row[i + half]
        row[i] = a * c - b * s
        row[i + half] = b * c + a * s


def _cpu_oracle(fx: _PrefillFixture, xs: List[Float32], seq: Int, max_len: Int) -> Tuple[List[Float32], List[Float32], List[Float32]]:
    """Sequential Float32 CPU oracle: full layer per token in
    prompt order with an accumulating KV cache. Returns
    (outputs [seq][dim], k_cache, v_cache) with caches in the
    GPU layout [kv_heads][max_len][head_dim]."""
    var out = List[Float32]()
    var kc = List[Float32]()
    var vc = List[Float32]()
    for _ in range(_KV_HEADS * max_len * _HEAD_DIM):
        kc.append(Float32(0.0))
        vc.append(Float32(0.0))
    var ok_all = List[Float32]()
    var ov_all = List[Float32]()
    for p in range(seq):
        var h = _cpu_rmsnorm_row(xs, p * _DIM, fx.g_attn)
        var q = fx.wq.matvec(h)
        var k = fx.wk.matvec(h)
        var v = fx.wv.matvec(h)
        for hd in range(_HEADS):
            var qrow = List[Float32]()
            for d in range(_HEAD_DIM):
                qrow.append(q[hd * _HEAD_DIM + d])
            _cpu_rope_row(qrow, _HEAD_DIM, p)
            for d in range(_HEAD_DIM):
                q[hd * _HEAD_DIM + d] = qrow[d]
        for hd in range(_KV_HEADS):
            var krow = List[Float32]()
            for d in range(_HEAD_DIM):
                krow.append(k[hd * _HEAD_DIM + d])
            _cpu_rope_row(krow, _HEAD_DIM, p)
            for d in range(_HEAD_DIM):
                k[hd * _HEAD_DIM + d] = krow[d]
        for i in range(_KV_DIM):
            ok_all.append(k[i])
            ov_all.append(v[i])
        for hd in range(_KV_HEADS):
            for d in range(_HEAD_DIM):
                kc[(hd * max_len + p) * _HEAD_DIM + d] = k[hd * _HEAD_DIM + d]
                vc[(hd * max_len + p) * _HEAD_DIM + d] = v[hd * _HEAD_DIM + d]
        var attn = List[Float32]()
        var scale = Float32(1.0) / sqrt(Float32(_HEAD_DIM))
        for hd in range(_HEADS):
            var kvh = hd // _RATIO
            var row_max = Float32(-1.0) / Float32(0.0)
            var scores = List[Float32]()
            for s in range(p + 1):
                var sc = Float32(0.0)
                for d in range(_HEAD_DIM):
                    sc += q[hd * _HEAD_DIM + d] * ok_all[(s * _KV_HEADS + kvh) * _HEAD_DIM + d]
                scores.append(sc * scale)
                if scores[s] > row_max:
                    row_max = scores[s]
            var denom = Float32(0.0)
            var acc = List[Float32]()
            for _ in range(_HEAD_DIM):
                acc.append(Float32(0.0))
            for s in range(p + 1):
                var w = exp(scores[s] - row_max)
                denom += w
                for d in range(_HEAD_DIM):
                    acc[d] = acc[d] + w * ov_all[(s * _KV_HEADS + kvh) * _HEAD_DIM + d]
            for d in range(_HEAD_DIM):
                attn.append(acc[d] / denom)
        var proj = fx.wo.matvec(attn)
        var res = List[Float32]()
        for i in range(_DIM):
            res.append(xs[p * _DIM + i] + proj[i])
        var h2 = _cpu_rmsnorm_row(res, 0, fx.g_ffn)
        var gate = fx.w_gate.matvec(h2)
        var up = fx.w_up.matvec(h2)
        var mlp = List[Float32]()
        for i in range(_FFN):
            var silu = gate[i] / (Float32(1.0) + exp(-gate[i]))
            mlp.append(silu * up[i])
        var down = fx.w_down.matvec(mlp)
        for i in range(_DIM):
            out.append(res[i] + down[i])
    return (out^, kc^, vc^)


def _upload_weights(fx: _PrefillFixture) raises -> VulkanPrefillWeights:
    return VulkanPrefillWeights(
        _upload_f32(fx.g_attn), _upload_f32(fx.g_ffn),
        fx.wq.upload(), fx.wk.upload(), fx.wv.upload(), fx.wo.upload(),
        fx.w_gate.upload(), fx.w_up.upload(), fx.w_down.upload(),
    )


def _free_weights(w: VulkanPrefillWeights) raises:
    VulkanBuffers.free(w.g_attn)
    VulkanBuffers.free(w.g_ffn)
    VulkanBuffers.free(w.wq)
    VulkanBuffers.free(w.wk)
    VulkanBuffers.free(w.wv)
    VulkanBuffers.free(w.wo)
    VulkanBuffers.free(w.w_gate)
    VulkanBuffers.free(w.w_up)
    VulkanBuffers.free(w.w_down)


def _run_prefill(weights: VulkanPrefillWeights, xs: List[Float32], seq: Int, chunk_size: Int, max_len: Int) raises -> Tuple[List[Float32], List[Float32], List[Float32]]:
    """Chunked GPU prefill: stream the prompt chunk by chunk;
    only the KV caches persist across chunks. Returns
    (outputs, k_cache, v_cache) read back from the device."""
    var k_cache = _zero_alloc(_KV_HEADS * max_len * _HEAD_DIM)
    var v_cache = _zero_alloc(_KV_HEADS * max_len * _HEAD_DIM)
    var out = List[Float32]()
    var n_chunks = VulkanChunkedPrefill.chunk_count(seq, chunk_size)
    for c in range(n_chunks):
        var start = c * chunk_size
        var clen = VulkanChunkedPrefill.chunk_len(seq, chunk_size, c)
        var xvals = List[Float32]()
        for i in range(clen * _DIM):
            xvals.append(xs[start * _DIM + i])
        var x = _upload_f32(xvals)
        var dst = VulkanBuffers.allocate(clen * _DIM * 4)
        VulkanChunkedPrefill.layer_chunk(
            x, weights, dst, k_cache, v_cache,
            clen, start, max_len, _DIM, _HEADS, _RATIO, _HEAD_DIM, _FFN, _EPS, _BASE,
        )
        var rows = _read_f32(dst, clen * _DIM)
        for i in range(len(rows)):
            out.append(rows[i])
        VulkanBuffers.free(x)
        VulkanBuffers.free(dst)
    var kc = _read_f32(k_cache, _KV_HEADS * max_len * _HEAD_DIM)
    var vc = _read_f32(v_cache, _KV_HEADS * max_len * _HEAD_DIM)
    VulkanBuffers.free(k_cache)
    VulkanBuffers.free(v_cache)
    return (out^, kc^, vc^)


def _max_abs(a: List[Float32], b: List[Float32]) -> Float32:
    var m = Float32(0.0)
    for i in range(len(a)):
        var d = _abs32(a[i] - b[i])
        if d > m:
            m = d
    return m


def test_vulkan_chunked_prefill_cpu_oracle_parity() raises:
    print("--- Testing Vulkan chunked prefill CPU oracle parity (A-069) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: chunked prefill parity not run (honest-absent)")
        return
    var fx = _PrefillFixture()
    var weights = _upload_weights(fx)
    var seq = 40
    var max_len = 64
    var xs = _prompt_xs(seq)
    var oracle = _cpu_oracle(fx, xs, seq, max_len)
    var got = _run_prefill(weights, xs, seq, 16, max_len)
    var out_diff = _max_abs(got[0], oracle[0])
    var k_diff = _max_abs(got[1], oracle[1])
    var v_diff = _max_abs(got[2], oracle[2])
    print(
        "A069_ORACLE seq=", seq, " chunk=16 (16/16/8 partial final)",
        " max_len=", max_len, " out_max_abs=", out_diff,
        " k_max_abs=", k_diff, " v_max_abs=", v_diff,
    )
    _free_weights(weights)
    if out_diff > _BOUND or k_diff > _BOUND or v_diff > _BOUND:
        raise Error("chunked prefill diverged from the CPU oracle beyond the filed bound")
    print("Vulkan chunked prefill CPU oracle parity (seq=40, chunk=16, outputs + KV caches, RADV device): PASS")


def test_vulkan_chunked_prefill_identical_to_unchunked() raises:
    print("--- Testing Vulkan chunked prefill identical to unchunked (A-069) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: identical-to-unchunked not run (honest-absent)")
        return
    var fx = _PrefillFixture()
    var weights = _upload_weights(fx)
    var seq = 40
    var max_len = 64
    var xs = _prompt_xs(seq)
    var whole = _run_prefill(weights, xs, seq, seq, max_len)
    var c16 = _run_prefill(weights, xs, seq, 16, max_len)
    var c7 = _run_prefill(weights, xs, seq, 7, max_len)
    var d16 = _max_abs(c16[0], whole[0])
    var d7 = _max_abs(c7[0], whole[0])
    var dk = _max_abs(c7[1], whole[1])
    var dv = _max_abs(c7[2], whole[2])
    print(
        "A069_IDENTICAL seq=", seq, " chunk16_vs_whole_out=", d16,
        " chunk7_vs_whole_out=", d7, " chunk7_k=", dk, " chunk7_v=", dv,
    )
    _free_weights(weights)
    if d16 > Float32(1.0e-5) or d7 > Float32(1.0e-5) or dk > Float32(1.0e-5) or dv > Float32(1.0e-5):
        raise Error("chunked prefill outputs are not identical to the unchunked pass")
    print("Vulkan chunked prefill identical to unchunked (chunk 16 and chunk 7 vs single-chunk, outputs + KV): PASS")


def test_vulkan_chunked_prefill_causal_isolation() raises:
    print("--- Testing Vulkan chunked prefill causal isolation (A-069) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: causal isolation not run (honest-absent)")
        return
    var fx = _PrefillFixture()
    var weights = _upload_weights(fx)
    var seq = 24
    var max_len = 32
    var xs = _prompt_xs(seq)
    var base = _run_prefill(weights, xs, seq, 8, max_len)
    var xs2 = xs.copy()
    for i in range(_DIM):
        xs2[20 * _DIM + i] = xs2[20 * _DIM + i] + Float32(1.25)
    var pert = _run_prefill(weights, xs2, seq, 8, max_len)
    _free_weights(weights)
    var early = Float32(0.0)
    for i in range(20 * _DIM):
        var d = _abs32(base[0][i] - pert[0][i])
        if d > early:
            early = d
    var late = Float32(0.0)
    for i in range(20 * _DIM, seq * _DIM):
        var d = _abs32(base[0][i] - pert[0][i])
        if d > late:
            late = d
    print("A069_CAUSAL perturbed_token=20 early_max_abs=", early, " late_max_abs=", late)
    if early != Float32(0.0):
        raise Error("future token leaked into earlier outputs (causality broken)")
    if late <= Float32(0.0):
        raise Error("perturbed token had no effect on its own outputs (fixture is inert)")
    print("Vulkan chunked prefill causal isolation (token 20 perturbation: positions <20 bitwise unchanged, >=20 changed): PASS")


def test_vulkan_chunked_prefill_rope_global_positions() raises:
    print("--- Testing Vulkan chunked prefill RoPE global positions (A-069) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: rope positions not run (honest-absent)")
        return
    var lcg = _Lcg(0xA06922)
    var vals = List[Float32]()
    for _ in range(4 * _HEADS * _HEAD_DIM):
        vals.append(lcg.val())
    var x = _upload_f32(vals)
    VulkanPrefillKernels.rope_batched(x, _HEAD_DIM, 4 * _HEADS, _HEADS, 8, _BASE)
    var got = _read_f32(x, 4 * _HEADS * _HEAD_DIM)
    VulkanBuffers.free(x)
    var want_global = List[Float32]()
    var want_local = List[Float32]()
    for t in range(4):
        for hd in range(_HEADS):
            var rg = List[Float32]()
            var rl = List[Float32]()
            for d in range(_HEAD_DIM):
                rg.append(vals[(t * _HEADS + hd) * _HEAD_DIM + d])
                rl.append(vals[(t * _HEADS + hd) * _HEAD_DIM + d])
            _cpu_rope_row(rg, _HEAD_DIM, 8 + t)
            _cpu_rope_row(rl, _HEAD_DIM, t)
            for d in range(_HEAD_DIM):
                want_global.append(rg[d])
                want_local.append(rl[d])
    var dg = _max_abs(got, want_global)
    var dl = _max_abs(got, want_local)
    print("A069_ROPE base_position=8 vs_global_max_abs=", dg, " vs_local_max_abs=", dl)
    if dg > Float32(1.0e-5):
        raise Error("rope_batched does not apply global positions")
    if dl < Float32(1.0e-3):
        raise Error("rope_batched is indistinguishable from chunk-local positions (restart bug would pass)")
    print("Vulkan chunked prefill RoPE global positions (chunk starting at 8 matches global oracle, differs from restarted): PASS")


def test_vulkan_chunked_prefill_kv_append_chunk_slots() raises:
    print("--- Testing Vulkan chunked prefill KV append chunk slots (A-069) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: kv append chunk not run (honest-absent)")
        return
    var tokens = 5
    var max_len = 16
    var src_vals = List[Float32]()
    for i in range(tokens * _KV_HEADS * _HEAD_DIM):
        src_vals.append(Float32(i) * Float32(0.01) - Float32(3.0))
    var src = _upload_f32(src_vals)
    var cache = VulkanBuffers.allocate(_KV_HEADS * max_len * _HEAD_DIM * 4)
    var p = VulkanBuffers.map(cache)
    var f = p.unsafe_bitcast[Float32]()
    for i in range(_KV_HEADS * max_len * _HEAD_DIM):
        f.unsafe_store(i, Float32(-777.0))
    VulkanBuffers.unmap(cache)
    VulkanPrefillKernels.kv_append_chunk(src, cache, _HEAD_DIM, max_len, 7, _KV_HEADS, tokens)
    var got = _read_f32(cache, _KV_HEADS * max_len * _HEAD_DIM)
    VulkanBuffers.free(src)
    VulkanBuffers.free(cache)
    for hd in range(_KV_HEADS):
        for s in range(max_len):
            for d in range(_HEAD_DIM):
                var v = got[(hd * max_len + s) * _HEAD_DIM + d]
                if s >= 7 and s < 7 + tokens:
                    var want = src_vals[((s - 7) * _KV_HEADS + hd) * _HEAD_DIM + d]
                    if v != want:
                        raise Error("kv_append_chunk wrote a wrong value into the cache")
                else:
                    if v != Float32(-777.0):
                        raise Error("kv_append_chunk overwrote a cache slot outside its chunk")
    print("Vulkan chunked prefill KV append chunk (5 tokens at slot 7, bit-exact, neighbours untouched): PASS")


def test_vulkan_chunked_prefill_rejection() raises:
    print("--- Testing Vulkan chunked prefill rejection (A-069) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: rejection cases not run (honest-absent)")
        return
    var fx = _PrefillFixture()
    var weights = _upload_weights(fx)
    var x = _zero_alloc(16 * _DIM)
    var dst = VulkanBuffers.allocate(16 * _DIM * 4)
    var kc = _zero_alloc(_KV_HEADS * 32 * _HEAD_DIM)
    var vc = _zero_alloc(_KV_HEADS * 32 * _HEAD_DIM)
    var rb0 = VulkanPrefillKernels.rope_batched_dispatch_count()
    var ka0 = VulkanPrefillKernels.kv_append_chunk_dispatch_count()
    var at0 = VulkanPrefillKernels.attention_chunk_dispatch_count()
    var zero_tokens = False
    try:
        VulkanChunkedPrefill.layer_chunk(x, weights, dst, kc, vc, 0, 0, 32, _DIM, _HEADS, _RATIO, _HEAD_DIM, _FFN, _EPS, _BASE)
    except:
        zero_tokens = True
    if not zero_tokens:
        raise Error("layer_chunk accepted zero tokens")
    var overrun = False
    try:
        VulkanChunkedPrefill.layer_chunk(x, weights, dst, kc, vc, 16, 24, 32, _DIM, _HEADS, _RATIO, _HEAD_DIM, _FFN, _EPS, _BASE)
    except:
        overrun = True
    if not overrun:
        raise Error("layer_chunk accepted a chunk overrunning max_len")
    var big_head = False
    try:
        VulkanChunkedPrefill.layer_chunk(x, weights, dst, kc, vc, 4, 0, 32, _DIM, _HEADS, _RATIO, 128, _FFN, _EPS, _BASE)
    except:
        big_head = True
    if not big_head:
        raise Error("layer_chunk accepted head_dim 128 (kernel accumulator bound is 64)")
    var bad_append = False
    try:
        VulkanPrefillKernels.kv_append_chunk(x, kc, _HEAD_DIM, 32, 30, _KV_HEADS, 5)
    except:
        bad_append = True
    if not bad_append:
        raise Error("kv_append_chunk accepted a chunk overrunning max_len")
    var bogus = VulkanAllocation(9999, 1024 * 1024, 1024 * 1024, 16, 3)
    var bogus_rejected = False
    try:
        VulkanPrefillKernels.attention_chunk(bogus, kc, vc, dst, _HEAD_DIM, 32, 0, 4, _HEADS, _RATIO)
    except:
        bogus_rejected = True
    if not bogus_rejected:
        raise Error("attention_chunk accepted a bogus query buffer id")
    if VulkanPrefillKernels.rope_batched_dispatch_count() != rb0:
        raise Error("rejected calls dispatched rope_batched")
    if VulkanPrefillKernels.kv_append_chunk_dispatch_count() != ka0:
        raise Error("rejected calls dispatched kv_append_chunk")
    if VulkanPrefillKernels.attention_chunk_dispatch_count() != at0:
        raise Error("rejected calls dispatched attention_prefill")
    VulkanBuffers.free(x)
    VulkanBuffers.free(dst)
    VulkanBuffers.free(kc)
    VulkanBuffers.free(vc)
    _free_weights(weights)
    print("Vulkan chunked prefill rejection (zero tokens, chunk overrun, head_dim 128, append overrun, bogus id; counters unmoved): PASS")


def test_vulkan_chunked_prefill_dispatch_and_bounds() raises:
    print("--- Testing Vulkan chunked prefill dispatch evidence + bounds (A-069) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: dispatch evidence not run (honest-absent)")
        return
    # Chunk plan: pure host math, incl. the 8k acceptance shape.
    if VulkanChunkedPrefill.chunk_count(8192, 256) != 32:
        raise Error("chunk_count(8192, 256) is not 32")
    if VulkanChunkedPrefill.chunk_len(8192, 256, 31) != 256:
        raise Error("chunk_len(8192, 256, 31) is not 256")
    if VulkanChunkedPrefill.chunk_count(8191, 256) != 32:
        raise Error("chunk_count(8191, 256) is not 32")
    if VulkanChunkedPrefill.chunk_len(8191, 256, 31) != 255:
        raise Error("chunk_len(8191, 256, 31) is not 255 (partial final chunk)")
    if VulkanChunkedPrefill.chunk_count(40, 16) != 3 or VulkanChunkedPrefill.chunk_len(40, 16, 2) != 8:
        raise Error("chunk plan for seq 40 / chunk 16 is wrong")
    # Bounded workspace: a function of chunk size only.
    var ws256 = VulkanChunkedPrefill.workspace_bytes(256, _DIM, _KV_DIM, _FFN)
    if ws256 != 256 * (7 * _DIM + 2 * _KV_DIM + 3 * _FFN) * 4:
        raise Error("workspace_bytes formula mismatch")
    if VulkanChunkedPrefill.kv_cache_bytes(_KV_HEADS, 8192, _HEAD_DIM) != 2 * 8192 * 32 * 4:
        raise Error("kv_cache_bytes formula mismatch")
    var fx = _PrefillFixture()
    var weights = _upload_weights(fx)
    var xs = _prompt_xs(16)
    var rb0 = VulkanPrefillKernels.rope_batched_dispatch_count()
    var ka0 = VulkanPrefillKernels.kv_append_chunk_dispatch_count()
    var at0 = VulkanPrefillKernels.attention_chunk_dispatch_count()
    var rn0 = VulkanNormRope.rmsnorm_dispatch_count()
    var gm0 = VulkanGemm.f32_dispatch_count()
    var el0 = VulkanElementwise.elementwise_dispatch_count()
    var base_bytes = VulkanBuffers.live_bytes()
    var base_count = VulkanBuffers.live_count()
    _ = _run_prefill(weights, xs, 16, 16, 32)
    if VulkanBuffers.live_bytes() != base_bytes:
        raise Error("chunked prefill leaked device bytes")
    if VulkanBuffers.live_count() != base_count:
        raise Error("chunked prefill leaked buffers")
    var leak_delta = VulkanBuffers.live_count() - base_count
    _free_weights(weights)
    if VulkanPrefillKernels.rope_batched_dispatch_count() - rb0 != 2:
        raise Error("rope_batched dispatch delta is not 2 for one chunk")
    if VulkanPrefillKernels.kv_append_chunk_dispatch_count() - ka0 != 2:
        raise Error("kv_append_chunk dispatch delta is not 2 for one chunk")
    if VulkanPrefillKernels.attention_chunk_dispatch_count() - at0 != 1:
        raise Error("attention_prefill dispatch delta is not 1 for one chunk")
    if VulkanNormRope.rmsnorm_dispatch_count() - rn0 != 2:
        raise Error("rmsnorm dispatch delta is not 2 for one chunk")
    if VulkanGemm.f32_dispatch_count() - gm0 != 7:
        raise Error("f32 gemm dispatch delta is not 7 for one chunk")
    if VulkanElementwise.elementwise_dispatch_count() - el0 != 3:
        raise Error("elementwise dispatch delta is not 3 for one chunk")
    print(
        "A069_BOUNDS workspace_chunk256=", ws256,
        " kv_cache_8k_bytes=", VulkanChunkedPrefill.kv_cache_bytes(_KV_HEADS, 8192, _HEAD_DIM),
        " live_count_delta=", leak_delta,
    )
    print("Vulkan chunked prefill dispatch evidence + bounds (per-chunk deltas rope 2 / kv 2 / attn 1 / rmsnorm 2 / gemm 7 / elem 3; 8k plan 32 chunks; workspace chunk-sized only): PASS")
