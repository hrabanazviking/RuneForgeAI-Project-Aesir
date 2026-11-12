# core/vulkan_decode.mojo
# VulkanDecode: full autoregressive decode loop on GPU (A-066).
#
# A stories260K-class small-fixture model generating entirely
# on the GPU path, composed ONLY from banked gateways plus the
# two A-066 data-movement kernels:
#   for each step (prompt token, then each generated token):
#     x    = embed_gather(table, token)              (A-066)
#     per layer L: x = VulkanLayer.forward_kv(x, w_L,
#                  k_cache_L, v_cache_L, position)   (A-065 +
#                  A-066 KV-append + strided attention)
#     logits = Q8_0 GEMV(w_head, RMSNorm(x, g_final)) (A-056/A-060)
#     token  = greedy_argmax(logits)                  (A-063)
# The host loop only sequences steps and reads back the
# device-produced token id (one uint per generated step); every
# arithmetic and data-movement operation runs in a device
# dispatch. Fail-closed: all shapes/tokens are validated before
# the first allocation or dispatch, and any gateway failure
# raises - no host fallback is fabricated. Acceptance is
# greedy token-exactness against the sequential Float32 CPU
# oracle (A-004 discipline, raw prompt token ids - no chat
# template exists anywhere in this path).

from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_layer import VulkanLayer, VulkanLayerWeights
from core.vulkan_kv_cache import VulkanEmbed
from core.vulkan_norm_rope import VulkanNormRope
from core.vulkan_gemv import VulkanGemv
from core.vulkan_sampling import VulkanSampling


struct VulkanDecodeWeights:
    """Resident weights for the decode fixture model.

    embedding: Float32 [vocab][dim] table. layers: one
    VulkanLayerWeights per layer. g_final: Float32 [dim]
    final-norm gains. w_head: raw Q8_0 bytes [vocab][dim]."""

    var embedding: VulkanAllocation
    var layers: List[VulkanLayerWeights]
    var g_final: VulkanAllocation
    var w_head: VulkanAllocation

    def __init__(
        out self,
        embedding: VulkanAllocation,
        layers: List[VulkanLayerWeights],
        g_final: VulkanAllocation,
        w_head: VulkanAllocation,
    ):
        self.embedding = embedding
        self.layers = layers.copy()
        self.g_final = g_final
        self.w_head = w_head


struct VulkanDecode:
    """Static full-decode-loop gateway (A-066)."""

    @staticmethod
    def generate(
        weights: VulkanDecodeWeights,
        prompt: List[Int],
        gen_steps: Int,
        dim: Int,
        num_heads: Int,
        kv_per_query: Int,
        head_dim: Int,
        ffn_dim: Int,
        vocab: Int,
        max_len: Int,
        eps: Float32,
        rope_base: Float32,
    ) raises -> List[Int]:
        """Greedy-generate gen_steps tokens after the raw
        prompt token ids, entirely on the GPU (see header).
        Returns the generated token ids in order. Raises
        (fail-closed) on any shape/token violation before
        dispatch, or on any Vulkan failure."""
        if len(prompt) <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanDecode.generate: prompt must be non-empty")
        if gen_steps <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanDecode.generate: gen_steps must be positive")
        if len(weights.layers) <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanDecode.generate: at least one layer is required")
        if dim <= 0 or dim % 32 != 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanDecode.generate: dim must be a positive multiple of 32")
        if vocab <= 0 or vocab % 1 != 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanDecode.generate: vocab must be positive")
        if max_len < len(prompt) + gen_steps:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanDecode.generate: max_len must cover prompt + generated tokens")
        for i in range(len(prompt)):
            if prompt[i] < 0 or prompt[i] >= vocab:
                raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanDecode.generate: prompt token out of vocab range")
        if weights.embedding.requested_size < vocab * dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanDecode.generate: embedding buffer is smaller than the table")
        if weights.g_final.requested_size < dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanDecode.generate: g_final buffer is smaller than dim Float32")
        if weights.w_head.requested_size < vocab * (dim // 32) * 34:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanDecode.generate: w_head buffer is smaller than the Q8_0 operand")
        var kv_heads = num_heads // kv_per_query
        var cache_floats = kv_heads * max_len * head_dim

        var k_caches = List[VulkanAllocation]()
        var v_caches = List[VulkanAllocation]()
        for _ in range(len(weights.layers)):
            k_caches.append(VulkanBuffers.allocate(cache_floats * 4))
            v_caches.append(VulkanBuffers.allocate(cache_floats * 4))
        var x = VulkanBuffers.allocate(dim * 4)
        var normed = VulkanBuffers.allocate(dim * 4)
        var logits = VulkanBuffers.allocate(vocab * 4)
        var tok_out = VulkanBuffers.allocate(4)

        var tokens = prompt.copy()
        var generated = List[Int]()
        var total_steps = len(prompt) + gen_steps - 1
        for step in range(total_steps):
            var token = tokens[step]
            VulkanEmbed.gather(weights.embedding, x, dim, token, vocab)
            var cur = x
            var owned = List[VulkanAllocation]()
            for li in range(len(weights.layers)):
                var nxt = VulkanBuffers.allocate(dim * 4)
                VulkanLayer.forward_kv(
                    cur, weights.layers[li], nxt,
                    k_caches[li], v_caches[li],
                    dim, num_heads, kv_per_query, head_dim, ffn_dim,
                    step, max_len, eps, rope_base,
                )
                owned.append(nxt)
                cur = nxt
            if step >= len(prompt) - 1:
                VulkanNormRope.rmsnorm(cur, weights.g_final, normed, dim, 1, eps)
                VulkanGemv.q8_0_gemv(weights.w_head, normed, logits, vocab, dim)
                VulkanSampling.greedy(logits, tok_out, vocab)
                var p = VulkanBuffers.map(tok_out)
                var nxt_token = Int(p.unsafe_bitcast[UInt32]().unsafe_load(0))
                VulkanBuffers.unmap(tok_out)
                generated.append(nxt_token)
                tokens.append(nxt_token)
            for i in range(len(owned)):
                VulkanBuffers.free(owned[i])

        for i in range(len(k_caches)):
            VulkanBuffers.free(k_caches[i])
            VulkanBuffers.free(v_caches[i])
        VulkanBuffers.free(x)
        VulkanBuffers.free(normed)
        VulkanBuffers.free(logits)
        VulkanBuffers.free(tok_out)
        return generated^
