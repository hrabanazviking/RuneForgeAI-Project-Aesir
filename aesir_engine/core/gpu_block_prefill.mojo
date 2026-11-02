"""GPU block prefill: the block plan (Janas road J-054).

J-053 measured where prompt time goes by construction and named
the ceiling this slice works against: on every CUDA surface in the
tree, prefill is decode-shaped. Llama3CUDASession.forward runs one
token and synchronises once per token; prefill_four batches only
the seven projections per layer across a width-4 tile (admitted
only for the exercised Llama 3.2 3B profile, core/dense_buffers
.mojo effective_prefill_batch) while norms, RoPE, KV-cache writes,
bias, SiLU and the scores/softmax/attention kernels still run per
token inside the tile; Gemma4CUDASession has no tile at all. The
quantized kernels that exist are matvec-shaped: block_matvec_kernel
(width 1) and four_matvec_kernel (width 4), kinds 12/13/14, columns
divisible by 256 (core/packed_projection.mojo). The F16 GEMM
executor (core/cuda_compute.mojo) refuses quantized tensors by
contract, so it is not a prefill GEMM road for GGUF weights.

This module is the planning/accounting layer a prefill-shaped GPU
executor must satisfy, in the J-031/J-053 style: pure arithmetic,
no device calls, nothing timed, no speed claimed.

- plan_gpu_block_prefill divides a prompt into chunks of a stated
  width and accounts, exactly: chunk count (all chunks but the last
  are pure prefill; the final chunk also pays the LM head, once --
  the host batched discipline of J-053), synchronised crossings
  (one per chunk, generalising forward's one-per-token and
  prefill_four's one-per-tile), batched GEMM calls (7 projections
  per layer per chunk: Q, K, V, attention output, gate, up, down),
  per-row attention kernel calls (3 per token per layer: scores,
  softmax, attention -- J-053 finding F2: attention does not batch
  on any surface today, and this plan does NOT pretend a chunk
  changes that; it counts the per-row calls a chunk still pays),
  weight-read bytes (each chunk re-reads the stated weight bytes
  once, against prompt_tokens times at width 1 -- the pass-count
  effect J-053 priced), activation scratch bytes for the chunk
  (width x the caller's per-token stride, f32), and the scores
  bytes a TRULY batched attention would additionally need (width
  simultaneous rows x heads x context, f32) -- the sizing fact
  that makes batched attention a build, not a flag.
- Admission is stated in the plan, never implied: width 1 is the
  proven decode shape, width 4 is the proven tile shape (3B
  profile only, a restriction the caller must check against
  effective_prefill_batch), every other width is UNBUILT -- a plan
  at an unbuilt width is a specification for the kernel work named
  in docs/janas/J054_GPU_BLOCK_PREFILL.md, not an executable claim.
- gpu_block_upload_chunks prices putting weights on the device
  through the tree's existing bounded pinned staging
  (core/cuda_upload.mojo, MAX_UPLOAD_STAGING_BYTES = 64 MiB, one
  synchronisation per chunk). In the proven sessions the weights
  are uploaded once at open and stay resident, so prefill itself
  pays no per-chunk weight upload; this prices the open leg and
  any non-resident variant honestly.

CPU KEEPS (the division this plan encodes): tokenisation and
admission, the chunk loop itself, sampling, and every per-row op
until a batched kernel exists for it. GPU TAKES, per chunk: the
seven projections as batch GEMM work over device-resident weights.
That is the whole honest claim of J-054; walls and faithfulness
grades are DEFERRED-WITH-REASON to the recipe in the slice doc.

HOST CONTRACT: the caller derives weight bytes from the opened
file's tensor directory, stride from DenseBufferLayout for its
profile, and heads/context from the profile; garbage inputs are
refused where detectable (non-positive shapes, a prompt longer
than the stated context capacity). Faithfulness grading for any
live leg is the road's raw-oracle discipline: ids first, then
teacher-forcing rank + logit gap against a CPU comparator on the
raw prompt; never llama-cli --single-turn.
"""

comptime ADMISSION_WIDTH1_PROVEN = 0
comptime ADMISSION_TILE4_PROVEN = 1
comptime ADMISSION_UNBUILT = 2

# The tree's existing upload staging bound (core/cuda_upload.mojo).
comptime UPLOAD_STAGING_BYTES = 67108864

# Projections batched per layer per chunk: Q, K, V, attention
# output, gate, up, down -- the seven project/project_four calls in
# llama3_cuda.mojo's run_layer / prefill_four layer body.
comptime PROJECTIONS_PER_LAYER = 7

# Per-row attention kernels per token per layer in both CUDA
# sessions: scores, softmax, attention (llama_scores/llama_softmax/
# llama_attention_tiled; scores_kernel/softmax_kernel/
# attention_kernel). J-053 finding F2.
comptime ATTENTION_KERNELS_PER_ROW = 3


def gpu_block_upload_chunks(total_bytes: Int) raises -> Int:
    """Synchronised staging chunks an upload of total_bytes costs
    through the existing 64 MiB bounded pinned staging."""
    if total_bytes < 0:
        raise Error("GpuBlockPrefill: upload bytes out of range")
    if total_bytes == 0:
        return 0
    return (total_bytes + UPLOAD_STAGING_BYTES - 1) // UPLOAD_STAGING_BYTES


struct GpuBlockPlan(Copyable, ImplicitlyCopyable):
    """One prompt's GPU block-prefill account at one chunk width."""

    var prompt_tokens: Int
    var chunk_width: Int
    var chunks: Int
    var pure_prefill_chunks: Int
    var final_chunk_width: Int
    var lm_head_passes: Int
    var sync_crossings: Int
    var batched_gemm_calls: Int
    var per_row_attention_calls: Int
    var weight_read_bytes: Int
    var width1_weight_read_bytes: Int
    var activation_scratch_bytes: Int
    var batched_attention_scores_bytes: Int
    var admission: Int

    def __init__(
        out self,
        prompt_tokens: Int,
        chunk_width: Int,
        chunks: Int,
        pure_prefill_chunks: Int,
        final_chunk_width: Int,
        lm_head_passes: Int,
        sync_crossings: Int,
        batched_gemm_calls: Int,
        per_row_attention_calls: Int,
        weight_read_bytes: Int,
        width1_weight_read_bytes: Int,
        activation_scratch_bytes: Int,
        batched_attention_scores_bytes: Int,
        admission: Int,
    ):
        self.prompt_tokens = prompt_tokens
        self.chunk_width = chunk_width
        self.chunks = chunks
        self.pure_prefill_chunks = pure_prefill_chunks
        self.final_chunk_width = final_chunk_width
        self.lm_head_passes = lm_head_passes
        self.sync_crossings = sync_crossings
        self.batched_gemm_calls = batched_gemm_calls
        self.per_row_attention_calls = per_row_attention_calls
        self.weight_read_bytes = weight_read_bytes
        self.width1_weight_read_bytes = width1_weight_read_bytes
        self.activation_scratch_bytes = activation_scratch_bytes
        self.batched_attention_scores_bytes = batched_attention_scores_bytes
        self.admission = admission

    def admission_name(self) -> String:
        if self.admission == ADMISSION_WIDTH1_PROVEN:
            return String("width1_proven")
        if self.admission == ADMISSION_TILE4_PROVEN:
            return String("tile4_proven_3b_only")
        return String("unbuilt")


def plan_gpu_block_prefill(
    prompt_tokens: Int,
    chunk_width: Int,
    layers: Int,
    weight_bytes: Int,
    stride_elements: Int,
    heads: Int,
    context_capacity: Int,
) raises -> GpuBlockPlan:
    """Account one prompt as GPU block prefill at chunk_width.

    weight_bytes is the caller-stated quantized weight bytes one
    full layer-stack pass reads (directory-true, from the opened
    file). stride_elements is the per-token activation stride
    (DenseBufferLayout.stride for the profile, f32 elements).
    context_capacity bounds the prompt (a prompt that does not fit
    is refused here, mirroring the sessions' own fit checks).
    """
    if prompt_tokens <= 0 or chunk_width <= 0:
        raise Error("GpuBlockPrefill: token count and chunk width must be positive")
    if layers <= 0 or weight_bytes <= 0 or stride_elements <= 0 or heads <= 0:
        raise Error("GpuBlockPrefill: model shape must be positive")
    if context_capacity <= 0 or prompt_tokens > context_capacity:
        raise Error("GpuBlockPrefill: prompt exceeds stated context capacity")
    var chunks = (prompt_tokens + chunk_width - 1) // chunk_width
    var final_width = prompt_tokens - (chunks - 1) * chunk_width
    var admission = ADMISSION_UNBUILT
    if chunk_width == 1:
        admission = ADMISSION_WIDTH1_PROVEN
    elif chunk_width == 4:
        admission = ADMISSION_TILE4_PROVEN
    return GpuBlockPlan(
        prompt_tokens,
        chunk_width,
        chunks,
        chunks - 1,
        final_width,
        1,
        chunks,
        chunks * layers * PROJECTIONS_PER_LAYER,
        prompt_tokens * layers * ATTENTION_KERNELS_PER_ROW,
        chunks * weight_bytes,
        prompt_tokens * weight_bytes,
        chunk_width * stride_elements * 4,
        chunk_width * heads * context_capacity * 4,
        admission,
    )
