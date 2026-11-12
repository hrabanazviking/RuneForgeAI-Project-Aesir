# core/vulkan_prefill.mojo
# VulkanChunkedPrefill: chunked prefill on GPU (slice A-069).
#
# Long prompts are processed in chunks of at most chunk_size
# tokens. For each chunk, one full transformer layer runs
# batched over the chunk's tokens (A-068 F32 GEMM projections,
# A-060 batched RMSNorm, A-061 elementwise), the chunk's k/v
# rows are written incrementally into the caller-owned KV
# caches on the GPU, and chunk causal attention reads the
# caches - prior chunks plus the causal prefix of this chunk.
# The caller streams chunks (upload chunk -> layer_chunk ->
# read chunk outputs); the only state that persists across
# chunks is the KV cache itself.
#
# Three new kernels, all through the A-055 SPIR-V pipeline
# (scripts/build_shaders.py; SHADER_MANIFEST kernel_count
# 22 -> 25, every prior hash byte-identical):
# - rope_batched: RoPE with per-row GLOBAL positions
#   (base_position + token index). Restarting positions per
#   chunk would make chunked output differ from unchunked;
#   global positions are the correctness crux of this slice.
# - kv_append_chunk: a chunk of token-major k/v rows copied
#   into the [kv_heads][max_len][head_dim] cache at slots
#   chunk_start.. - bit-exact, so a chunked cache is
#   byte-identical to the unchunked cache.
# - attention_prefill: causal attention for a chunk of query
#   tokens over the cache. It materialises NO score matrix:
#   scores are recomputed in a second pass, so attention
#   workspace is O(1) per query, never O(seq^2). Positions
#   accumulate in increasing order, the unchunked order.
#
# BOUNDED MEMORY (acceptance): every scratch buffer in
# layer_chunk is sized by the CHUNK's token count, never by
# the sequence length - workspace_bytes() files the exact
# formula. The KV cache is O(seq) by definition
# (2 * kv_heads * max_len * head_dim Float32 for K and V);
# nothing in the path is O(seq^2) or O(seq * chunk) beyond
# the cache. An 8192-token prompt therefore runs in the same
# workspace as a 256-token prompt at the same chunk size.
#
# Scope (honest): weights are dense Float32 (the A-068 F32
# GEMM path) for one layer; the Q8_0 decode layer (A-065/
# A-066) is untouched. Embedding ingestion is the caller's
# (A-066 VulkanEmbed for decode; prefill fixtures upload
# embedding rows per chunk, which is the streaming shape).
#
# Fail-closed contract (matches A-056..A-068): every shape
# and buffer is validated BEFORE any allocation or dispatch;
# when the Vulkan runtime or the RADV device is unavailable
# the underlying gateways raise - no host fallback.
# dispatch_count() reads the shim counters that increment
# only after a submit + queue-wait-idle completed on the
# device (law 6 device-execution evidence). The attention
# kernel's fixed accumulator bounds head_dim to 64.

from std.ffi import external_call
from std.memory import bitcast
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_norm_rope import VulkanNormRope
from core.vulkan_gemm import VulkanGemm
from core.vulkan_elementwise import VulkanElementwise

comptime _VK_ABSENT = -1000000
comptime _VK_INVALID = -1000001


def _raise_for_rc(what: String, rc: Int32) raises:
    if Int(rc) == _VK_ABSENT:
        raise Error(
            "GPU-002 DEVICE_NOT_FOUND: " + what + ": Vulkan loader or dispatch"
            " entry points are not loadable on this host"
            " (honest-absent)"
        )
    if Int(rc) == _VK_INVALID:
        raise Error(
            "VAL-003 VALUE_OUT_OF_RANGE: " + what + ": invalid buffer id or"
            " argument for the Vulkan shim"
        )
    raise Error(
        "GPU-001 CUDA_INIT_FAILED: " + what + ": Vulkan call failed, VkResult "
        + String(Int(rc))
    )


struct VulkanPrefillKernels:
    """Static gateways for the three A-069 kernels."""

    @staticmethod
    def rope_batched(
        x: VulkanAllocation,
        head_dim: Int,
        rows: Int,
        rows_per_token: Int,
        base_position: Int,
        base: Float32,
    ) raises:
        """In-place batched RoPE: rows of head_dim, row r
        belongs to token r // rows_per_token and rotates by
        the GLOBAL position base_position + r //
        rows_per_token (rotate-half, A-060 pairing)."""
        if head_dim <= 0 or head_dim % 2 != 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.rope_batched: head_dim must be positive and even")
        if rows <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.rope_batched: rows must be positive")
        if rows_per_token <= 0 or rows % rows_per_token != 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.rope_batched: rows must be a positive multiple of rows_per_token")
        if base_position < 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.rope_batched: base_position must be non-negative")
        if base <= Float32(0.0):
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.rope_batched: base must be positive")
        if x.requested_size < rows * head_dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.rope_batched: buffer is smaller than rows*head_dim Float32")
        var base_bits = bitcast[DType.uint32](base)
        var rc = external_call["aesir_vk_buffer_rope_batched", Int32](
            UInt64(x.id), UInt32(head_dim), UInt32(rows), UInt32(rows_per_token), UInt32(base_position), base_bits
        )
        if rc != 0:
            _raise_for_rc("VulkanPrefillKernels.rope_batched", rc)

    @staticmethod
    def rope_batched_dispatch_count() -> Int:
        return Int(external_call["aesir_vk_rope_batched_dispatch_count", UInt64]())

    @staticmethod
    def kv_append_chunk(
        src: VulkanAllocation,
        cache: VulkanAllocation,
        head_dim: Int,
        max_len: Int,
        chunk_start: Int,
        kv_heads: Int,
        tokens: Int,
    ) raises:
        """Copy src [tokens][kv_heads][head_dim] (token-major)
        into cache [kv_heads][max_len][head_dim] at slots
        chunk_start .. chunk_start + tokens - 1, on the GPU.
        Bit-exact data movement (compute dispatch, not a host
        copy and not vkCmdCopyBuffer)."""
        if head_dim <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.kv_append_chunk: head_dim must be positive")
        if max_len <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.kv_append_chunk: max_len must be positive")
        if kv_heads <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.kv_append_chunk: kv_heads must be positive")
        if tokens <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.kv_append_chunk: tokens must be positive")
        if chunk_start < 0 or chunk_start + tokens > max_len:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.kv_append_chunk: chunk must lie in [0, max_len)")
        if src.requested_size < tokens * kv_heads * head_dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.kv_append_chunk: src buffer is smaller than the chunk rows")
        if cache.requested_size < kv_heads * max_len * head_dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.kv_append_chunk: cache buffer is smaller than the KV cache")
        var rc = external_call["aesir_vk_buffer_kv_append_chunk", Int32](
            UInt64(src.id), UInt64(cache.id),
            UInt32(head_dim), UInt32(max_len), UInt32(chunk_start), UInt32(kv_heads), UInt32(tokens),
        )
        if rc != 0:
            _raise_for_rc("VulkanPrefillKernels.kv_append_chunk", rc)

    @staticmethod
    def kv_append_chunk_dispatch_count() -> Int:
        return Int(external_call["aesir_vk_kv_append_chunk_dispatch_count", UInt64]())

    @staticmethod
    def attention_chunk(
        q: VulkanAllocation,
        k_cache: VulkanAllocation,
        v_cache: VulkanAllocation,
        o: VulkanAllocation,
        head_dim: Int,
        max_len: Int,
        chunk_start: Int,
        tokens: Int,
        num_heads: Int,
        kv_per_query: Int,
    ) raises:
        """Causal attention for one chunk: query token t
        (global position chunk_start + t) attends over cache
        positions 0 .. chunk_start + t inclusive. q and o are
        [tokens][num_heads][head_dim]; caches are
        [kv_heads][max_len][head_dim]. head_dim <= 64 (the
        kernel's fixed output accumulator)."""
        if head_dim <= 0 or head_dim > 64:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.attention_chunk: head_dim must lie in [1, 64]")
        if max_len <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.attention_chunk: max_len must be positive")
        if tokens <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.attention_chunk: tokens must be positive")
        if chunk_start < 0 or chunk_start + tokens > max_len:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.attention_chunk: chunk must lie in [0, max_len)")
        if num_heads <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.attention_chunk: num_heads must be positive")
        if kv_per_query <= 0 or num_heads % kv_per_query != 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.attention_chunk: num_heads must be an exact multiple of kv_per_query")
        var kv_heads = num_heads // kv_per_query
        if q.requested_size < tokens * num_heads * head_dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.attention_chunk: q buffer is smaller than the chunk queries")
        if o.requested_size < tokens * num_heads * head_dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.attention_chunk: o buffer is smaller than the chunk queries")
        if k_cache.requested_size < kv_heads * max_len * head_dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.attention_chunk: k cache buffer is smaller than the KV cache")
        if v_cache.requested_size < kv_heads * max_len * head_dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanPrefillKernels.attention_chunk: v cache buffer is smaller than the KV cache")
        var rc = external_call["aesir_vk_buffer_attn_prefill_chunk", Int32](
            UInt64(q.id), UInt64(k_cache.id), UInt64(v_cache.id), UInt64(o.id),
            UInt32(head_dim), UInt32(max_len), UInt32(chunk_start), UInt32(tokens), UInt32(num_heads), UInt32(kv_per_query),
        )
        if rc != 0:
            _raise_for_rc("VulkanPrefillKernels.attention_chunk", rc)

    @staticmethod
    def attention_chunk_dispatch_count() -> Int:
        return Int(external_call["aesir_vk_attn_prefill_chunk_dispatch_count", UInt64]())


struct VulkanPrefillWeights(Copyable, ImplicitlyCopyable):
    """Dense Float32 weight + norm-gain buffers for one
    prefill layer (A-069). Layouts:
      wq: [dim][dim]     wk: [kv_dim][dim]  wv: [kv_dim][dim]
      wo: [dim][kv_dim]  w_gate: [ffn][dim] w_up: [ffn][dim]
      w_down: [dim][ffn] g_attn/g_ffn: [dim] Float32 gains.
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


struct VulkanChunkedPrefill:
    """Static chunked-prefill layer composition (A-069)."""

    @staticmethod
    def chunk_count(seq_len: Int, chunk_size: Int) -> Int:
        """Number of chunks for a prompt: ceil(seq / chunk);
        the final chunk may be partial. Pure host math."""
        if seq_len <= 0 or chunk_size <= 0:
            return 0
        return (seq_len + chunk_size - 1) // chunk_size

    @staticmethod
    def chunk_len(seq_len: Int, chunk_size: Int, chunk_index: Int) -> Int:
        """Token count of chunk chunk_index (chunk_size, or
        the partial remainder for the final chunk)."""
        if seq_len <= 0 or chunk_size <= 0 or chunk_index < 0:
            return 0
        var start = chunk_index * chunk_size
        if start >= seq_len:
            return 0
        var rest = seq_len - start
        return chunk_size if rest > chunk_size else rest

    @staticmethod
    def workspace_bytes(tokens: Int, dim: Int, kv_dim: Int, ffn_dim: Int) -> Int:
        """Exact scratch bytes layer_chunk allocates for a
        chunk of `tokens` tokens: 7 dim-wide + 2 kv_dim-wide
        + 3 ffn-wide Float32 rows per token. A function of
        the CHUNK size only - the bounded-memory formula."""
        return tokens * (7 * dim + 2 * kv_dim + 3 * ffn_dim) * 4

    @staticmethod
    def kv_cache_bytes(kv_heads: Int, max_len: Int, head_dim: Int) -> Int:
        """Exact bytes of ONE cache (K or V):
        kv_heads * max_len * head_dim Float32 - the only
        O(seq) state in the path."""
        return kv_heads * max_len * head_dim * 4

    @staticmethod
    def layer_chunk(
        x: VulkanAllocation,
        weights: VulkanPrefillWeights,
        dst: VulkanAllocation,
        k_cache: VulkanAllocation,
        v_cache: VulkanAllocation,
        tokens: Int,
        chunk_start: Int,
        max_len: Int,
        dim: Int,
        num_heads: Int,
        kv_per_query: Int,
        head_dim: Int,
        ffn_dim: Int,
        eps: Float32,
        rope_base: Float32,
    ) raises:
        """Run one full prefill layer over one chunk on the
        GPU and append the chunk's KV rows to the caches at
        slots chunk_start .. chunk_start + tokens - 1.

        x and dst hold [tokens][dim] Float32. All scratch is
        chunk-sized (see workspace_bytes). Per chunk the
        dispatch counts advance by exactly: rmsnorm 2,
        f32_gemm 7, rope_batched 2, kv_append_chunk 2,
        attention_prefill 1, elementwise 3. Raises
        (fail-closed) on any shape/buffer violation before
        any allocation or dispatch."""
        if dim <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: dim must be positive")
        if num_heads <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: num_heads must be positive")
        if kv_per_query <= 0 or num_heads % kv_per_query != 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: num_heads must be an exact multiple of kv_per_query")
        if head_dim <= 0 or head_dim % 2 != 0 or head_dim > 64:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: head_dim must be positive, even and at most 64")
        if num_heads * head_dim != dim:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: num_heads * head_dim must equal dim")
        if ffn_dim <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: ffn_dim must be positive")
        if tokens <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: tokens must be positive")
        if max_len <= 0 or chunk_start < 0 or chunk_start + tokens > max_len:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: chunk must lie in [0, max_len)")
        if eps <= Float32(0.0):
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: eps must be positive")
        if rope_base <= Float32(0.0):
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: rope_base must be positive")
        var kv_heads = num_heads // kv_per_query
        var kv_dim = kv_heads * head_dim
        if x.requested_size < tokens * dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: x buffer is smaller than the chunk")
        if dst.requested_size < tokens * dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: dst buffer is smaller than the chunk")
        if k_cache.requested_size < kv_heads * max_len * head_dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: k_cache buffer is smaller than the KV cache")
        if v_cache.requested_size < kv_heads * max_len * head_dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: v_cache buffer is smaller than the KV cache")
        if weights.g_attn.requested_size < dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: g_attn buffer is smaller than dim Float32")
        if weights.g_ffn.requested_size < dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: g_ffn buffer is smaller than dim Float32")
        if weights.wq.requested_size < dim * dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: wq buffer is smaller than the dense operand")
        if weights.wk.requested_size < kv_dim * dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: wk buffer is smaller than the dense operand")
        if weights.wv.requested_size < kv_dim * dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: wv buffer is smaller than the dense operand")
        if weights.wo.requested_size < dim * kv_dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: wo buffer is smaller than the dense operand")
        if weights.w_gate.requested_size < ffn_dim * dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: w_gate buffer is smaller than the dense operand")
        if weights.w_up.requested_size < ffn_dim * dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: w_up buffer is smaller than the dense operand")
        if weights.w_down.requested_size < dim * ffn_dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanChunkedPrefill.layer_chunk: w_down buffer is smaller than the dense operand")

        var h = VulkanBuffers.allocate(tokens * dim * 4)
        var q = VulkanBuffers.allocate(tokens * dim * 4)
        var k = VulkanBuffers.allocate(tokens * kv_dim * 4)
        var v = VulkanBuffers.allocate(tokens * kv_dim * 4)
        var attn = VulkanBuffers.allocate(tokens * dim * 4)
        var proj = VulkanBuffers.allocate(tokens * dim * 4)
        var res = VulkanBuffers.allocate(tokens * dim * 4)
        var h2 = VulkanBuffers.allocate(tokens * dim * 4)
        var gate = VulkanBuffers.allocate(tokens * ffn_dim * 4)
        var up = VulkanBuffers.allocate(tokens * ffn_dim * 4)
        var mlp = VulkanBuffers.allocate(tokens * ffn_dim * 4)
        var down = VulkanBuffers.allocate(tokens * dim * 4)

        VulkanNormRope.rmsnorm(x, weights.g_attn, h, dim, tokens, eps)
        VulkanGemm.f32_gemm(weights.wq, h, q, dim, dim, tokens)
        VulkanGemm.f32_gemm(weights.wk, h, k, kv_dim, dim, tokens)
        VulkanGemm.f32_gemm(weights.wv, h, v, kv_dim, dim, tokens)
        VulkanPrefillKernels.rope_batched(q, head_dim, tokens * num_heads, num_heads, chunk_start, rope_base)
        VulkanPrefillKernels.rope_batched(k, head_dim, tokens * kv_heads, kv_heads, chunk_start, rope_base)
        VulkanPrefillKernels.kv_append_chunk(k, k_cache, head_dim, max_len, chunk_start, kv_heads, tokens)
        VulkanPrefillKernels.kv_append_chunk(v, v_cache, head_dim, max_len, chunk_start, kv_heads, tokens)
        VulkanPrefillKernels.attention_chunk(q, k_cache, v_cache, attn, head_dim, max_len, chunk_start, tokens, num_heads, kv_per_query)
        VulkanGemm.f32_gemm(weights.wo, attn, proj, dim, kv_dim, tokens)
        VulkanElementwise.elementwise(x, proj, res, tokens * dim, 2)
        VulkanNormRope.rmsnorm(res, weights.g_ffn, h2, dim, tokens, eps)
        VulkanGemm.f32_gemm(weights.w_gate, h2, gate, ffn_dim, dim, tokens)
        VulkanGemm.f32_gemm(weights.w_up, h2, up, ffn_dim, dim, tokens)
        VulkanElementwise.elementwise(gate, up, mlp, tokens * ffn_dim, 3)
        VulkanGemm.f32_gemm(weights.w_down, mlp, down, dim, ffn_dim, tokens)
        VulkanElementwise.elementwise(res, down, dst, tokens * dim, 2)

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
