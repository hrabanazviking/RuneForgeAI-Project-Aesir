# core/vulkan_batch.mojo
# VulkanBatchDecode: continuous batching v1 (A-072).
#
# Multiple sequences decoded together on the GPU path: an
# iteration-level scheduler over the banked A-066 decode step
# (embed gather -> per-layer VulkanLayer.forward_kv -> final
# norm -> Q8_0 LM head -> greedy argmax). Sequences share the
# resident weights (A-064) and nothing else: every sequence
# owns its KV caches (A-066 layout [kv_heads][max_len]
# [head_dim] per layer), its token stream, and its position
# counter, so a sequence's arithmetic is bit-for-bit the solo
# A-066 computation and its greedy output must match its
# single-sequence VulkanDecode.generate run token-exactly
# (the roadmap A-072 acceptance).
#
# Continuous, not static: at most max_active sequences are
# resident at once. At the start of each iteration, free
# slots are refilled from the waiting queue in request order;
# a sequence admitted mid-run starts at position 0 while its
# batchmates are mid-context (heterogeneous positions,
# isolated caches). A sequence leaves the batch in the
# iteration where it processes its final step; its caches are
# freed at that moment and the slot is reusable from the next
# iteration. One iteration advances every resident sequence
# by exactly one position, in request order.
#
# Scope filed honestly (v1): the per-step device work is the
# A-066 single-sequence step issued once per resident
# sequence per iteration - the batching proven here is the
# scheduler, the isolation, and the continuous admission;
# fusing the per-sequence GEMVs into one batched dispatch is
# later work (the A-068 GEMM road), not claimed here. The
# A-071 async-dispatch line is NOT banked at build time and
# nothing here depends on it: every dispatch below is the
# banked synchronous gateway call, exactly as in A-066. If
# queued async submission lands with A-071, it slots under
# this scheduler without changing its semantics; that
# dependency is recorded in hidden_files/A072_LEDGER.md.
#
# Fail-closed: every request and shape is validated before
# the first allocation or dispatch (mirroring A-066), and any
# gateway failure raises - no host fallback is fabricated.
# The shared transient buffers (x / normed / logits / tok_out
# / ping-pong layer scratch, A-070 discipline) are allocated
# once for the whole batch run; the only per-sequence device
# state is the KV caches, allocated at admission and freed
# at completion, so live device bytes return to the pre-run
# baseline.

from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_layer import VulkanLayer
from core.vulkan_kv_cache import VulkanEmbed
from core.vulkan_norm_rope import VulkanNormRope
from core.vulkan_gemv import VulkanGemv
from core.vulkan_sampling import VulkanSampling
from core.vulkan_decode import VulkanDecodeWeights


struct VulkanBatchResult:
    """Outcome of one continuous-batching run (A-072).

    outputs[i]: the greedy tokens generated for request i
    (request order, NOT completion order). admitted_at[i]:
    the iteration in which request i entered the batch.
    finished_at[i]: the iteration in which request i
    processed its final step. iterations: total scheduler
    iterations executed."""

    var outputs: List[List[Int]]
    var admitted_at: List[Int]
    var finished_at: List[Int]
    var iterations: Int

    def __init__(
        out self,
        outputs: List[List[Int]],
        admitted_at: List[Int],
        finished_at: List[Int],
        iterations: Int,
    ):
        self.outputs = outputs.copy()
        self.admitted_at = admitted_at.copy()
        self.finished_at = finished_at.copy()
        self.iterations = iterations


struct VulkanBatchDecode:
    """Static continuous-batching gateway (A-072)."""

    @staticmethod
    def generate_batch(
        weights: VulkanDecodeWeights,
        prompts: List[List[Int]],
        gen_steps: List[Int],
        max_active: Int,
        dim: Int,
        num_heads: Int,
        kv_per_query: Int,
        head_dim: Int,
        ffn_dim: Int,
        vocab: Int,
        max_len: Int,
        eps: Float32,
        rope_base: Float32,
    ) raises -> VulkanBatchResult:
        """Continuously batch-decode every request on the GPU
        (see header). prompts[i] is the RAW prompt token ids
        for request i (no chat template exists anywhere in
        this path) and gen_steps[i] its greedy token count;
        at most max_active sequences are resident at once.
        Returns per-request outputs plus the admission /
        finish schedule. Raises (fail-closed) on any shape or
        token violation before dispatch, or on any Vulkan
        failure."""
        if len(prompts) <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanBatchDecode.generate_batch: at least one request is required")
        if len(gen_steps) != len(prompts):
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanBatchDecode.generate_batch: gen_steps must match the request count")
        if max_active <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanBatchDecode.generate_batch: max_active must be positive")
        if len(weights.layers) <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanBatchDecode.generate_batch: at least one layer is required")
        if dim <= 0 or dim % 32 != 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanBatchDecode.generate_batch: dim must be a positive multiple of 32")
        if vocab <= 0 or vocab % 1 != 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanBatchDecode.generate_batch: vocab must be positive")
        if max_len <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanBatchDecode.generate_batch: max_len must be positive")
        for i in range(len(prompts)):
            if len(prompts[i]) <= 0:
                raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanBatchDecode.generate_batch: every prompt must be non-empty")
            if gen_steps[i] <= 0:
                raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanBatchDecode.generate_batch: every gen_steps must be positive")
            if max_len < len(prompts[i]) + gen_steps[i]:
                raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanBatchDecode.generate_batch: max_len must cover prompt + generated tokens for every request")
            for j in range(len(prompts[i])):
                if prompts[i][j] < 0 or prompts[i][j] >= vocab:
                    raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanBatchDecode.generate_batch: prompt token out of vocab range")
        if weights.embedding.requested_size < vocab * dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanBatchDecode.generate_batch: embedding buffer is smaller than the table")
        if weights.g_final.requested_size < dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanBatchDecode.generate_batch: g_final buffer is smaller than dim Float32")
        if weights.w_head.requested_size < vocab * (dim // 32) * 34:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanBatchDecode.generate_batch: w_head buffer is smaller than the Q8_0 operand")
        var kv_heads = num_heads // kv_per_query
        var cache_floats = kv_heads * max_len * head_dim
        var n = len(prompts)
        var num_layers = len(weights.layers)

        # Shared transients for the whole run (A-070: no
        # per-step alloc/free; every dispatch is synchronous,
        # so reuse across sequences and iterations is safe).
        var x = VulkanBuffers.allocate(dim * 4)
        var normed = VulkanBuffers.allocate(dim * 4)
        var logits = VulkanBuffers.allocate(vocab * 4)
        var tok_out = VulkanBuffers.allocate(4)
        var scratch_a = VulkanBuffers.allocate(dim * 4)
        var scratch_b = VulkanBuffers.allocate(dim * 4)

        # Per-sequence state. KV caches are allocated lazily
        # at admission and freed at completion.
        var tokens_all = List[List[Int]]()
        var generated_all = List[List[Int]]()
        var step_all = List[Int]()
        var active = List[Bool]()
        var admitted_at = List[Int]()
        var finished_at = List[Int]()
        var k_all = List[List[VulkanAllocation]]()
        var v_all = List[List[VulkanAllocation]]()
        for i in range(n):
            tokens_all.append(prompts[i].copy())
            generated_all.append(List[Int]())
            step_all.append(0)
            active.append(False)
            admitted_at.append(-1)
            finished_at.append(-1)
            k_all.append(List[VulkanAllocation]())
            v_all.append(List[VulkanAllocation]())

        var waiting = 0
        var active_count = 0
        var finished_count = 0
        var iteration = 0
        while finished_count < n:
            # Admission: refill free slots in request order.
            while active_count < max_active and waiting < n:
                var idx = waiting
                var kc = List[VulkanAllocation]()
                var vc = List[VulkanAllocation]()
                for _ in range(num_layers):
                    kc.append(VulkanBuffers.allocate(cache_floats * 4))
                    vc.append(VulkanBuffers.allocate(cache_floats * 4))
                k_all[idx] = kc.copy()
                v_all[idx] = vc.copy()
                active[idx] = True
                admitted_at[idx] = iteration
                active_count += 1
                waiting += 1
            # One step per resident sequence, request order.
            for i in range(n):
                if not active[i]:
                    continue
                var step = step_all[i]
                var token = tokens_all[i][step]
                VulkanEmbed.gather(weights.embedding, x, dim, token, vocab)
                var cur = x
                var use_a = True
                for li in range(num_layers):
                    var nxt = scratch_a if use_a else scratch_b
                    VulkanLayer.forward_kv(
                        cur, weights.layers[li], nxt,
                        k_all[i][li], v_all[i][li],
                        dim, num_heads, kv_per_query, head_dim, ffn_dim,
                        step, max_len, eps, rope_base,
                    )
                    use_a = not use_a
                    cur = nxt
                if step >= len(prompts[i]) - 1:
                    VulkanNormRope.rmsnorm(cur, weights.g_final, normed, dim, 1, eps)
                    VulkanGemv.q8_0_gemv(weights.w_head, normed, logits, vocab, dim)
                    VulkanSampling.greedy(logits, tok_out, vocab)
                    var p = VulkanBuffers.map(tok_out)
                    var nxt_token = Int(p.unsafe_bitcast[UInt32]().unsafe_load(0))
                    VulkanBuffers.unmap(tok_out)
                    generated_all[i].append(nxt_token)
                    tokens_all[i].append(nxt_token)
                step_all[i] = step + 1
                if step + 1 >= len(prompts[i]) + gen_steps[i] - 1:
                    for li in range(num_layers):
                        VulkanBuffers.free(k_all[i][li])
                        VulkanBuffers.free(v_all[i][li])
                    active[i] = False
                    finished_at[i] = iteration
                    active_count -= 1
                    finished_count += 1
            iteration += 1

        VulkanBuffers.free(x)
        VulkanBuffers.free(scratch_a)
        VulkanBuffers.free(scratch_b)
        VulkanBuffers.free(normed)
        VulkanBuffers.free(logits)
        VulkanBuffers.free(tok_out)
        return VulkanBatchResult(
            generated_all.copy(), admitted_at.copy(),
            finished_at.copy(), iteration,
        )
