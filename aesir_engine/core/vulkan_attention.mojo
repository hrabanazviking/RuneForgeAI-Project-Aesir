# core/vulkan_attention.mojo
# VulkanAttention: Vulkan decode attention gateway (slice A-062).
#
# Single-query attention over a unified KV cache dispatched on
# the GPU through the A-014/A-015 Vulkan context and buffer
# slots: the kernel (aesir_engine/shaders/attention_decode.comp,
# A-055 foundation; SPIR-V embedded via the A-055 generated
# header) consumes Float32 q [num_heads][head_dim], k and v
# [num_kv_heads][kv_len][head_dim] with
# num_kv_heads = num_heads / kv_per_query (grouped-query
# mapping: query head h reads KV head h / kv_per_query), scores
# scaled by 1/sqrt(head_dim), numerically careful softmax
# (max-subtraction, mirroring softmax.comp), and writes
# Float32 o [num_heads][head_dim]. All shape arrives as push
# constants, so GQA ratios are a caller choice, not a recompile.
#
# Fail-closed contract (matches A-014/A-015/A-056): when the
# Vulkan runtime or the RADV device is unavailable every
# operation raises; no host fallback is fabricated. Shapes must
# be positive, num_heads must be an exact multiple of
# kv_per_query, and every buffer must cover the full operand;
# violations raise before any dispatch. dispatch_count() reads
# the shim counter that increments only after a submit +
# queue-wait-idle completed on the device - the filed
# device-execution evidence (law 6).

from std.ffi import external_call
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation

comptime _VK_ABSENT = -1000000
comptime _VK_INVALID = -1000001


struct VulkanAttention:
    """Static Vulkan decode attention gateway (A-062)."""

    @staticmethod
    def _raise_for_rc(what: String, rc: Int32) raises:
        if Int(rc) == _VK_ABSENT:
            raise Error(
                "GPU-002 DEVICE_NOT_FOUND: VulkanAttention." + what + ": Vulkan loader or dispatch"
                " entry points are not loadable on this host"
                " (honest-absent)"
            )
        if Int(rc) == _VK_INVALID:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanAttention." + what + ": invalid buffer id or"
                " argument for the Vulkan shim"
            )
        raise Error(
            "GPU-001 CUDA_INIT_FAILED: VulkanAttention." + what + ": Vulkan call failed, VkResult "
            + String(Int(rc))
        )

    @staticmethod
    def decode_attention(
        q: VulkanAllocation,
        k: VulkanAllocation,
        v: VulkanAllocation,
        o: VulkanAllocation,
        head_dim: Int,
        kv_len: Int,
        num_heads: Int,
        kv_per_query: Int,
    ) raises:
        """Dispatch the A-062 decode attention kernel (see file
        header for layouts). Raises (fail-closed) on any shape
        or buffer violation or Vulkan failure - nothing is
        computed on the host instead."""
        if head_dim <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanAttention.decode_attention: head_dim must be positive")
        if kv_len <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanAttention.decode_attention: kv_len must be positive")
        if num_heads <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanAttention.decode_attention: num_heads must be positive")
        if kv_per_query <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanAttention.decode_attention: kv_per_query must be positive")
        if num_heads % kv_per_query != 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanAttention.decode_attention: num_heads must be an exact multiple of kv_per_query (integer GQA ratio)")
        var num_kv_heads = num_heads // kv_per_query
        var need_q = num_heads * head_dim * 4
        var need_kv = num_kv_heads * kv_len * head_dim * 4
        if q.requested_size < need_q:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanAttention.decode_attention: q buffer is smaller than the query operand")
        if k.requested_size < need_kv:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanAttention.decode_attention: k buffer is smaller than the KV operand")
        if v.requested_size < need_kv:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanAttention.decode_attention: v buffer is smaller than the KV operand")
        if o.requested_size < need_q:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanAttention.decode_attention: output buffer is smaller than the query operand")
        var rc = external_call["aesir_vk_buffer_attn_decode", Int32](
            UInt64(q.id), UInt64(k.id), UInt64(v.id), UInt64(o.id),
            UInt32(head_dim), UInt32(kv_len), UInt32(num_heads), UInt32(kv_per_query),
        )
        if rc != 0:
            Self._raise_for_rc("decode_attention", rc)

    @staticmethod
    def dispatch_count() -> Int:
        """Completed A-062 decode attention dispatches on the
        device so far (shim counter; increments only after
        submit + wait-idle)."""
        return Int(external_call["aesir_vk_attn_decode_dispatch_count", UInt64]())
