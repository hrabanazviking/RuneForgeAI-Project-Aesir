# core/hip_attention_norms.mojo
# HipAttnNorms: HIP attention + norms gateway (slice A-084).
#
# Minimal set matching the A-060/A-062 Vulkan scope on the HIP
# path: RMSNorm (A-060), RoPE rotate-half (A-060), and single-
# query decode attention with grouped-query mapping (A-062),
# executed on the Radeon 8060S (gfx1151) by Mojo-native kernels
# launched through MAX DeviceContext(api="hip") - the A-029 /
# A-082 proven HIP kernel road - gated by the A-010-A-012 HIP
# gate (AMDGate gfx1151 + HipMemory probe + MojoNative).
#
# Math is identical to the Vulkan shaders of record
# (shaders/rmsnorm.comp, rope.comp, attention_decode.comp
# serial path) and the engine CPU bodies (core/compute.mojo):
# RMSNorm y = x * rsqrt(mean(x^2)+eps) * g in Float32; RoPE
# pair (i, i+head_dim/2) rotated by position*base^(-2i/head_dim);
# attention scores scaled by 1/sqrt(head_dim) with max-
# subtraction softmax, Float32 accumulation throughout (A-075).
#
# Kernel shapes use only A-029-proven forms: one thread per
# output row (RMSNorm), one thread per RoPE pair, one thread
# per (head, lane) recomputing scores serially (attention) -
# no shared memory, barriers, or subgroup ops. The A-085
# bake-off judges speed; this slice claims parity + execution.
#
# Fail-closed: gate failure or any shape violation raises
# before device work; no host fallback is fabricated. Each op
# has its own shim dispatch counter, incremented only after
# launch + readback + synchronize completed - the filed
# device-execution evidence (law 6).

from std.ffi import external_call
from std.gpu import global_idx
from std.math import cos, exp, isinf, isnan, sin, sqrt
from std.memory import Pointer
from core.amd_gate import AMDGate
from core.hip_memory import HipMemory
from core.mojo_gpu_target import MojoNative
from max.gpu.host import DeviceContext


def _rms_kernel[x_origin: Origin[mut=False], g_origin: Origin[mut=False], y_origin: MutOrigin](x: Pointer[Scalar[DType.float32], x_origin], g: Pointer[Scalar[DType.float32], g_origin], y: Pointer[Scalar[DType.float32], y_origin], n: Int32, rows: Int32, eps: Float32):
    var row = Int(global_idx.x)
    if row < Int(rows):
        var nn = Int(n)
        var base = row * nn
        var ss: Scalar[DType.float32] = 0.0
        for i in range(nn):
            var v = x.unsafe_load(base + i)
            ss += v * v
        var scale = Scalar[DType.float32](1.0) / sqrt(ss / Scalar[DType.float32](nn) + eps)
        for i in range(nn):
            y.unsafe_store(base + i, x.unsafe_load(base + i) * scale * g.unsafe_load(i))


def _rope_kernel[x_origin: MutOrigin](x: Pointer[Scalar[DType.float32], x_origin], head_dim: Int32, rows: Int32, position: Int32, base_f: Float32):
    var idx = Int(global_idx.x)
    var hd = Int(head_dim)
    var half = hd // 2
    if idx < Int(rows) * half:
        var row = idx // half
        var i = idx % half
        var off = row * hd + i
        var theta = Scalar[DType.float32](position) * (base_f ** (Scalar[DType.float32](-2.0) * Scalar[DType.float32](i) / Scalar[DType.float32](hd)))
        var c = cos(theta)
        var s = sin(theta)
        var a = x.unsafe_load(off)
        var b = x.unsafe_load(off + half)
        x.unsafe_store(off, a * c - b * s)
        x.unsafe_store(off + half, b * c + a * s)


def _attn_kernel[q_origin: Origin[mut=False], k_origin: Origin[mut=False], v_origin: Origin[mut=False], o_origin: MutOrigin](q: Pointer[Scalar[DType.float32], q_origin], k: Pointer[Scalar[DType.float32], k_origin], v: Pointer[Scalar[DType.float32], v_origin], o: Pointer[Scalar[DType.float32], o_origin], head_dim: Int32, kv_len: Int32, num_heads: Int32, kv_per_query: Int32):
    var idx = Int(global_idx.x)
    var hd = Int(head_dim)
    if idx < Int(num_heads) * hd:
        var head = idx // hd
        var lane = idx % hd
        var kv_head = head // Int(kv_per_query)
        var kl = Int(kv_len)
        var qbase = head * hd
        var scale = Scalar[DType.float32](1.0) / sqrt(Scalar[DType.float32](hd))
        var row_max = Scalar[DType.float32](-3.4028235e38)
        for t in range(kl):
            var kb = (kv_head * kl + t) * hd
            var sc: Scalar[DType.float32] = 0.0
            for d in range(hd):
                sc += q.unsafe_load(qbase + d) * k.unsafe_load(kb + d)
            var s2 = sc * scale
            if s2 > row_max:
                row_max = s2
        var denom: Scalar[DType.float32] = 0.0
        var acc: Scalar[DType.float32] = 0.0
        for t in range(kl):
            var kb = (kv_head * kl + t) * hd
            var sc: Scalar[DType.float32] = 0.0
            for d in range(hd):
                sc += q.unsafe_load(qbase + d) * k.unsafe_load(kb + d)
            var w = exp(sc * scale - row_max)
            denom += w
            acc += w * v.unsafe_load(kb + lane)
        o.unsafe_store(idx, acc / denom)


struct HipAttnNorms:
    """Static HIP attention + norms gateway (A-084)."""

    @staticmethod
    def gate_ok() -> Bool:
        if not HipMemory.runtime_available():
            return False
        try:
            if HipMemory.device_count() != 1:
                return False
        except:
            return False
        var props = AMDGate.get_device_properties(0)
        if not props.plausible():
            return False
        if props.gfx_arch != "gfx1151":
            return False
        return MojoNative.available()

    @staticmethod
    def device_name() raises -> String:
        return MojoNative.device_name()

    @staticmethod
    def _require_gate(what: String) raises:
        if not Self.gate_ok():
            raise Error("GPU-002 DEVICE_NOT_FOUND: HipAttnNorms." + what + ": HIP gate (A-010-A-012) not satisfied - runtime absent, device count != 1, or device is not gfx1151 (honest-absent / wrong-device refused)")

    @staticmethod
    def rmsnorm_dispatch_count() -> Int:
        return Int(external_call["aesir_hip_rmsnorm_dispatch_count", UInt64]())

    @staticmethod
    def rope_dispatch_count() -> Int:
        return Int(external_call["aesir_hip_rope_dispatch_count", UInt64]())

    @staticmethod
    def attn_dispatch_count() -> Int:
        return Int(external_call["aesir_hip_attn_dispatch_count", UInt64]())

    @staticmethod
    def _note_rms():
        external_call["aesir_hip_note_rmsnorm_dispatch", NoneType]()

    @staticmethod
    def _note_rope():
        external_call["aesir_hip_note_rope_dispatch", NoneType]()

    @staticmethod
    def _note_attn():
        external_call["aesir_hip_note_attn_dispatch", NoneType]()

    @staticmethod
    def rmsnorm(x: List[Float32], g: List[Float32], rows: Int, n: Int, eps: Float32) raises -> List[Float32]:
        """y[row,i] = x[row,i]*rsqrt(mean_i(x^2)+eps)*g[i] on HIP."""
        if n <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipAttnNorms.rmsnorm: row length n must be positive")
        if rows <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipAttnNorms.rmsnorm: row count must be positive")
        if isnan(eps) or isinf(eps) or eps <= Float32(0.0):
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipAttnNorms.rmsnorm: eps must be positive")
        if len(x) != rows * n:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipAttnNorms.rmsnorm: input list does not cover rows*n")
        if len(g) != n:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipAttnNorms.rmsnorm: weight list does not cover n")
        Self._require_gate("rmsnorm")
        var total = rows * n
        with DeviceContext(0, api="hip") as ctx:
            var hx = ctx.enqueue_create_host_buffer[DType.float32](total)
            var hg = ctx.enqueue_create_host_buffer[DType.float32](n)
            var hy = ctx.enqueue_create_host_buffer[DType.float32](total)
            var dx = ctx.enqueue_create_buffer[DType.float32](total)
            var dg = ctx.enqueue_create_buffer[DType.float32](n)
            var dy = ctx.enqueue_create_buffer[DType.float32](total)
            for i in range(total):
                hx[i] = x[i]
                hy[i] = Float32(-9999.0)
            for i in range(n):
                hg[i] = g[i]
            ctx.enqueue_copy(dx, hx)
            ctx.enqueue_copy(dg, hg)
            ctx.enqueue_copy(dy, hy)
            ctx.synchronize()
            ctx.enqueue_function[_rms_kernel[origin_of(dx), origin_of(dg), origin_of(dy)]](dx.unsafe_ptr(), dg.unsafe_ptr(), dy.unsafe_ptr(), Int32(n), Int32(rows), eps, grid_dim=(rows + 255) // 256, block_dim=256)
            ctx.enqueue_copy(hy, dy)
            ctx.synchronize()
            var out = List[Float32](capacity=total)
            for i in range(total):
                out.append(hy[i])
            Self._note_rms()
            return out^

    @staticmethod
    def rope(x: List[Float32], head_dim: Int, rows: Int, position: Int, base: Float32) raises -> List[Float32]:
        """RoPE rotate-half applied on HIP; returns rotated copy."""
        if head_dim <= 0 or head_dim % 2 != 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipAttnNorms.rope: head_dim must be positive and even")
        if rows <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipAttnNorms.rope: row count must be positive")
        if position < 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipAttnNorms.rope: position must be non-negative")
        if isnan(base) or isinf(base) or base <= Float32(0.0):
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipAttnNorms.rope: base must be positive")
        if len(x) != rows * head_dim:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipAttnNorms.rope: input list does not cover rows*head_dim")
        Self._require_gate("rope")
        var total = rows * head_dim
        var pairs = rows * (head_dim // 2)
        with DeviceContext(0, api="hip") as ctx:
            var hx = ctx.enqueue_create_host_buffer[DType.float32](total)
            var dx = ctx.enqueue_create_buffer[DType.float32](total)
            for i in range(total):
                hx[i] = x[i]
            ctx.enqueue_copy(dx, hx)
            ctx.synchronize()
            ctx.enqueue_function[_rope_kernel[origin_of(dx)]](dx.unsafe_ptr(), Int32(head_dim), Int32(rows), Int32(position), base, grid_dim=(pairs + 255) // 256, block_dim=256)
            ctx.enqueue_copy(hx, dx)
            ctx.synchronize()
            var out = List[Float32](capacity=total)
            for i in range(total):
                out.append(hx[i])
            Self._note_rope()
            return out^

    @staticmethod
    def decode_attention(q: List[Float32], k: List[Float32], v: List[Float32], head_dim: Int, kv_len: Int, num_heads: Int, kv_per_query: Int) raises -> List[Float32]:
        """Single-query decode attention on HIP (A-062 layout): q [num_heads][head_dim], k/v [num_kv_heads][kv_len][head_dim], GQA head h reads KV head h/kv_per_query."""
        if head_dim <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipAttnNorms.decode_attention: head_dim must be positive")
        if kv_len <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipAttnNorms.decode_attention: kv_len must be positive")
        if num_heads <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipAttnNorms.decode_attention: num_heads must be positive")
        if kv_per_query <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipAttnNorms.decode_attention: kv_per_query must be positive")
        if num_heads % kv_per_query != 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipAttnNorms.decode_attention: num_heads must be an exact multiple of kv_per_query")
        var nkv = num_heads // kv_per_query
        var nq = num_heads * head_dim
        var nkv_total = nkv * kv_len * head_dim
        if len(q) != nq:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipAttnNorms.decode_attention: q list does not cover the query operand")
        if len(k) != nkv_total or len(v) != nkv_total:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: HipAttnNorms.decode_attention: k/v lists do not cover the KV operand")
        Self._require_gate("decode_attention")
        with DeviceContext(0, api="hip") as ctx:
            var hq = ctx.enqueue_create_host_buffer[DType.float32](nq)
            var hk = ctx.enqueue_create_host_buffer[DType.float32](nkv_total)
            var hv = ctx.enqueue_create_host_buffer[DType.float32](nkv_total)
            var ho = ctx.enqueue_create_host_buffer[DType.float32](nq)
            var dq = ctx.enqueue_create_buffer[DType.float32](nq)
            var dk = ctx.enqueue_create_buffer[DType.float32](nkv_total)
            var dv = ctx.enqueue_create_buffer[DType.float32](nkv_total)
            var do_ = ctx.enqueue_create_buffer[DType.float32](nq)
            for i in range(nq):
                hq[i] = q[i]
                ho[i] = Float32(-9999.0)
            for i in range(nkv_total):
                hk[i] = k[i]
                hv[i] = v[i]
            ctx.enqueue_copy(dq, hq)
            ctx.enqueue_copy(dk, hk)
            ctx.enqueue_copy(dv, hv)
            ctx.enqueue_copy(do_, ho)
            ctx.synchronize()
            ctx.enqueue_function[_attn_kernel[origin_of(dq), origin_of(dk), origin_of(dv), origin_of(do_)]](dq.unsafe_ptr(), dk.unsafe_ptr(), dv.unsafe_ptr(), do_.unsafe_ptr(), Int32(head_dim), Int32(kv_len), Int32(num_heads), Int32(kv_per_query), grid_dim=(nq + 255) // 256, block_dim=256)
            ctx.enqueue_copy(ho, do_)
            ctx.synchronize()
            var out = List[Float32](capacity=nq)
            for i in range(nq):
                out.append(ho[i])
            Self._note_attn()
            return out^
