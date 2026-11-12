# core/vulkan_layer.mojo
# VulkanLayer: one full transformer layer on GPU (slice A-065).
#
# A whole decode layer composed ONLY from the banked Wave 7
# Vulkan kernels, in roadmap order:
#   h    = RMSNorm(x, g_attn)                    (A-060)
#   q    = Q8_0 GEMV(wq, h)                      (A-056)
#   k    = Q8_0 GEMV(wk, h)                      (A-056)
#   v    = Q8_0 GEMV(wv, h)                      (A-056)
#   q, k = RoPE(q), RoPE(k) at position          (A-060)
#   attn = decode_attention(q, k, v)             (A-062)
#   res  = x + Q8_0 GEMV(wo, attn)               (A-056 + A-061 add)
#   h2   = RMSNorm(res, g_ffn)                   (A-060)
#   mlp  = silu(Q8_0 GEMV(w_gate, h2))
#          * Q8_0 GEMV(w_up, h2)                 (A-056 + A-061 gated)
#   out  = res + Q8_0 GEMV(w_down, mlp)          (A-056 + A-061 add)
# Every kernel's SPIR-V comes from the A-055 generated header
# (aesir_engine/shaders/generated/aesir_shaders_spv.h) through
# the banked gateways; this module adds no shader and no shim
# entry - it is pure composition of VulkanNormRope, VulkanGemv,
# VulkanAttention and VulkanElementwise over A-014 buffers.
#
# KV scope, filed honestly: this is a decode layer for a
# single-position context (kv_len == 1). At kv_len == 1 the
# decode-attention K/V operand layout [kv_heads][1][head_dim]
# IS the k/v projection layout [kv_heads][head_dim], so the
# projection buffers feed attention directly with no copy.
# Multi-position decode needs a KV-append (insert-at-position)
# kernel that does not exist in the Wave 7 set; that gap is
# recorded in CAMPAIGN_STATE.md as the immediate next work and
# is A-066's problem to solve, not silently papered over here.
#
# Fail-closed contract (matches A-056/A-060/A-061/A-062): every
# shape and buffer is validated BEFORE any scratch allocation
# or dispatch; when the Vulkan runtime or the RADV device is
# unavailable the underlying gateways raise - no host fallback
# is fabricated. Device-execution evidence (law 6) is the
# banked gateways' dispatch counters, which the A-065 tests
# assert advance by the exact per-layer dispatch counts
# (rmsnorm 2, rope 2, q8_gemv 7, attention 1, elementwise 3).

from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_norm_rope import VulkanNormRope
from core.vulkan_gemv import VulkanGemv
from core.vulkan_attention import VulkanAttention
from core.vulkan_elementwise import VulkanElementwise


struct VulkanLayerWeights(Copyable, ImplicitlyCopyable):
    """Q8_0 weight + norm-gain buffers for one layer (A-065).

    Layouts (raw GGUF Q8_0 bytes: per 32 values, one fp16 scale
    + 32 int8 = 34 bytes):
      wq: [dim][dim]        wk: [kv_dim][dim]   wv: [kv_dim][dim]
      wo: [dim][kv_dim]     w_gate: [ffn][dim]  w_up: [ffn][dim]
      w_down: [dim][ffn]    g_attn/g_ffn: [dim] Float32 gains.
    """

    var g_attn: VulkanAllocation
    var g_ffn: VulkanAllocation
    var wq: VulkanAllocation
    var wk: VulkanAllocation
    var wv: VulkanAllocation
    var wo: VulkanAllocation
    var w_gate: VulkanAllocation
    var w_up: VulkanAllocation
    var w_down: VulkanAllocation

    def __init__(
        out self,
        g_attn: VulkanAllocation,
        g_ffn: VulkanAllocation,
        wq: VulkanAllocation,
        wk: VulkanAllocation,
        wv: VulkanAllocation,
        wo: VulkanAllocation,
        w_gate: VulkanAllocation,
        w_up: VulkanAllocation,
        w_down: VulkanAllocation,
    ):
        self.g_attn = g_attn
        self.g_ffn = g_ffn
        self.wq = wq
        self.wk = wk
        self.wv = wv
        self.wo = wo
        self.w_gate = w_gate
        self.w_up = w_up
        self.w_down = w_down


struct VulkanLayer:
    """Static full-layer GPU composition gateway (A-065)."""

    @staticmethod
    def _q8_bytes(rows: Int, cols: Int) -> Int:
        return rows * (cols // 32) * 34

    @staticmethod
    def forward(
        x: VulkanAllocation,
        weights: VulkanLayerWeights,
        dst: VulkanAllocation,
        dim: Int,
        num_heads: Int,
        kv_per_query: Int,
        head_dim: Int,
        ffn_dim: Int,
        position: Int,
        eps: Float32,
        rope_base: Float32,
    ) raises:
        """Run one full decode layer on the GPU (see header).

        x and out each hold dim Float32 (one token). All weight
        buffers hold raw Q8_0 bytes at the VulkanLayerWeights
        layouts for the stated geometry. position is the decode
        position fed to RoPE; the attention context is the
        single current position (kv_len == 1, see header).
        Raises (fail-closed) on any shape/buffer violation
        before dispatch, or on any Vulkan failure - nothing is
        computed on the host instead."""
        if dim <= 0 or dim % 32 != 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: dim must be a positive multiple of 32")
        if num_heads <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: num_heads must be positive")
        if kv_per_query <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: kv_per_query must be positive")
        if num_heads % kv_per_query != 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: num_heads must be an exact multiple of kv_per_query")
        if head_dim <= 0 or head_dim % 2 != 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: head_dim must be positive and even")
        if num_heads * head_dim != dim:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: num_heads * head_dim must equal dim")
        if ffn_dim <= 0 or ffn_dim % 32 != 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: ffn_dim must be a positive multiple of 32")
        if position < 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: position must be non-negative")
        if eps <= Float32(0.0):
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: eps must be positive")
        if rope_base <= Float32(0.0):
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: rope_base must be positive")
        var kv_heads = num_heads // kv_per_query
        var kv_dim = kv_heads * head_dim
        if x.requested_size < dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: x buffer is smaller than dim Float32")
        if dst.requested_size < dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: out buffer is smaller than dim Float32")
        if weights.g_attn.requested_size < dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: g_attn buffer is smaller than dim Float32")
        if weights.g_ffn.requested_size < dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: g_ffn buffer is smaller than dim Float32")
        if weights.wq.requested_size < Self._q8_bytes(dim, dim):
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: wq buffer is smaller than the Q8_0 operand")
        if weights.wk.requested_size < Self._q8_bytes(kv_dim, dim):
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: wk buffer is smaller than the Q8_0 operand")
        if weights.wv.requested_size < Self._q8_bytes(kv_dim, dim):
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: wv buffer is smaller than the Q8_0 operand")
        if weights.wo.requested_size < Self._q8_bytes(dim, kv_dim):
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: wo buffer is smaller than the Q8_0 operand")
        if weights.w_gate.requested_size < Self._q8_bytes(ffn_dim, dim):
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: w_gate buffer is smaller than the Q8_0 operand")
        if weights.w_up.requested_size < Self._q8_bytes(ffn_dim, dim):
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: w_up buffer is smaller than the Q8_0 operand")
        if weights.w_down.requested_size < Self._q8_bytes(dim, ffn_dim):
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanLayer.forward: w_down buffer is smaller than the Q8_0 operand")

        var h = VulkanBuffers.allocate(dim * 4)
        var q = VulkanBuffers.allocate(dim * 4)
        var k = VulkanBuffers.allocate(kv_dim * 4)
        var v = VulkanBuffers.allocate(kv_dim * 4)
        var attn = VulkanBuffers.allocate(dim * 4)
        var proj = VulkanBuffers.allocate(dim * 4)
        var res = VulkanBuffers.allocate(dim * 4)
        var h2 = VulkanBuffers.allocate(dim * 4)
        var gate = VulkanBuffers.allocate(ffn_dim * 4)
        var up = VulkanBuffers.allocate(ffn_dim * 4)
        var mlp = VulkanBuffers.allocate(ffn_dim * 4)
        var down = VulkanBuffers.allocate(dim * 4)

        # norm -> attn projections -> RoPE -> decode attention.
        VulkanNormRope.rmsnorm(x, weights.g_attn, h, dim, 1, eps)
        VulkanGemv.q8_0_gemv(weights.wq, h, q, dim, dim)
        VulkanGemv.q8_0_gemv(weights.wk, h, k, kv_dim, dim)
        VulkanGemv.q8_0_gemv(weights.wv, h, v, kv_dim, dim)
        VulkanNormRope.rope(q, head_dim, num_heads, position, rope_base)
        VulkanNormRope.rope(k, head_dim, kv_heads, position, rope_base)
        VulkanAttention.decode_attention(
            q, k, v, attn, head_dim, 1, num_heads, kv_per_query
        )
        VulkanGemv.q8_0_gemv(weights.wo, attn, proj, dim, kv_dim)
        VulkanElementwise.elementwise(x, proj, res, dim, 2)
        # norm -> gated MLP -> residual.
        VulkanNormRope.rmsnorm(res, weights.g_ffn, h2, dim, 1, eps)
        VulkanGemv.q8_0_gemv(weights.w_gate, h2, gate, ffn_dim, dim)
        VulkanGemv.q8_0_gemv(weights.w_up, h2, up, ffn_dim, dim)
        VulkanElementwise.elementwise(gate, up, mlp, ffn_dim, 3)
        VulkanGemv.q8_0_gemv(weights.w_down, mlp, down, dim, ffn_dim)
        VulkanElementwise.elementwise(res, down, dst, dim, 2)

        VulkanBuffers.free(h)
        VulkanBuffers.free(q)
        VulkanBuffers.free(k)
        VulkanBuffers.free(v)
        VulkanBuffers.free(attn)
        VulkanBuffers.free(proj)
        VulkanBuffers.free(res)
        VulkanBuffers.free(h2)
        VulkanBuffers.free(gate)
        VulkanBuffers.free(up)
        VulkanBuffers.free(mlp)
        VulkanBuffers.free(down)
