# 10 - CUDA / GPU Optimization for Qwen3 0.6B / 1.7B / 4B / 8B

**Research snapshot:** 2026-11-02

GPU optimization should be split into two different problems: high-throughput prefill and ultra-low-overhead decode. The four Qwen3 sizes span a range where GPU launch overhead matters at the tiny end and weight/KV bandwidth dominates at the large end.

---

# 1. Full residency first

If a model fits in device/unified memory, keep it there.

Preferred topology:

```text
weights: resident
KV: resident
activations/scratch: resident
sampling/logits: remain device-side until only final token ID is needed
```

Avoid:

```text
CPU layer -> GPU layer -> CPU layer -> GPU layer
```

for every transformer block. Device crossings can erase compute gains.

If partial offload is unavoidable, split in contiguous blocks and minimize boundaries.

---

# 2. Prefill path

Prompt prefill is matrix-matrix heavy and can use the GPU efficiently.

Targets:

- tensor-core-friendly matrix tiles;
- quantized GEMM with fused dequantization;
- flash/tiled causal attention;
- chunked prefill for long prompts;
- async input staging;
- large enough batches to amortize launches;
- no O(n^2) attention-score materialization.

The optimum prompt chunk size should be autotuned against VRAM and architecture.

---

# 3. Decode path

One-token decode can become launch-bound, especially on 0.6B/1.7B.

Aesir should investigate:

- CUDA Graph capture of the repeated block sequence;
- persistent kernels where practical;
- kernel fusion;
- batched active sequences;
- device-side sampling to avoid sync after every logit buffer;
- fixed scratch buffers;
- avoiding stream synchronization except at externally visible token boundaries.

The objective is not merely high GPU occupancy. The objective is lowest end-to-end token latency.

---

# 4. Quantized GPU matmul

Aesir should implement quant formats as native execution representations rather than storage formats that are expanded before use.

Desired flow:

```text
quant payload + scales
 -> fused unpack/dequant inside matmul tile
 -> tensor/vector accumulation
 -> output
```

Important dimensions:

- quant block size;
- shared-memory staging;
- scale broadcast pattern;
- register pressure;
- output accumulation dtype;
- whether tensor cores can be exploited directly or through efficient conversion.

Q4_K_M and Q5_K_M deserve first-class optimization because they are strong balanced candidates across all four models.

---

# 5. Why dtype alone does not predict speed

Qwen's official H20 benchmark provides direct evidence:

- optimized SGLang often runs FP8/AWQ faster than BF16;
- generic Transformers FP8 is often slower in the tested software stack;
- memory footprint still drops even when speed does not improve.

Aesir policy:

```text
quant format + kernel implementation + workload shape = performance
```

Never publish 'FP8/Q4 is faster' without naming the actual kernel/path.

---

# 6. Attention prefill

A tiled online-softmax kernel should avoid writing the full attention matrix.

For each Q block:

1. load Q tile;
2. iterate K/V tiles;
3. compute causal scores;
4. update running max and normalization sum;
5. accumulate weighted V;
6. write final output.

Qwen3 GQA allows KV reuse across multiple Q heads. The kernel should exploit the 16/8 and 32/8 relationships rather than duplicate KV loads unnecessarily.

---

# 7. Attention decode

Decode is a single-query attention problem over growing KV history.

Optimize:

- coalesced KV reads;
- each KV head reused by its Q-head group;
- fused score + softmax + V accumulation;
- efficient int8 KV dequant;
- page-table traversal if paged KV is enabled;
- minimize global-memory intermediate scores.

At very long context, attention can become a significant bandwidth problem even on an 8B model whose weights dominate at short context.

---

# 8. QK-Norm + RoPE fusion

Qwen3 requires QK-Norm and correct split-half RoPE.

A promising fused pipeline:

```text
Q/K projection output
 -> compute RMS stats per head
 -> normalize Q/K
 -> apply rotary transform
 -> feed attention
```

Potential gain: fewer global-memory round trips.

Correctness gate:

- compare fused output against scalar/reference QK-Norm + RoPE;
- test multiple positions including high positions;
- test 0.6/1.7 16Q geometry and 4/8 32Q geometry;
- test YaRN path separately.

---

# 9. RMSNorm/residual fusion

Residual + RMSNorm is another bandwidth-friendly fusion candidate.

But do not create a mega-kernel that also handles unrelated work if it damages occupancy. Benchmark:

```text
unfused
residual+norm
residual+norm+next input staging
```

---

# 10. SwiGLU fusion

Potential prefill path:

```text
compute gate and up projections in paired schedule
gate = silu(gate)
gate *= up
feed down projection
```

Potential decode path can fuse the pointwise activation/multiply after projection results.

The two large projection matrices still dominate, so fusion should focus on eliminating extra global-memory writes rather than chasing the few FLOPs in SiLU.

---

# 11. CUDA Graphs

The transformer decode schedule repeats nearly identically token after token. CUDA Graph capture can reduce CPU launch overhead.

Especially promising for:

- 0.6B;
- 1.7B;
- batch-1 interactive inference;
- fixed kernel graph with changing token position pointers/scalars.

Challenges:

- variable context/page-table pointers;
- dynamic sampling;
- optional thinking/tool protocol does not change layer graph, but stop conditions do;
- speculative verification introduces variable token batch sizes.

Aesir should create separate captured graphs for common decode batch sizes if needed.

---

# 12. Streams and overlap

Opportunities:

- async host input copy while previous request completes;
- prefetch spilled/offloaded layer blocks only if partial residency is unavoidable;
- overlap sampling/CPU postprocessing carefully;
- multi-stream concurrency for independent requests when memory bandwidth allows.

Do not overlap two bandwidth-saturated 8B decode streams and assume throughput doubles. It may only increase latency.

---

# 13. Multi-request batching

GPUs profit from batching because one weight read can serve several active sequences.

Aesir scheduler should support:

- continuous batching;
- tiny batching delay for interactive latency;
- grouping by model/quant;
- paged KV per sequence;
- variable context lengths;
- finished-sequence removal without rebuilding the batch.

A 0.6B model that is underutilizing a GPU at batch 1 can become extremely efficient as a multi-agent worker at batch 8/16.

---

# 14. KV precision

The 4B/8B long-context cases make int8 KV especially important.

GPU kernel requirements:

- direct read of int8 payload;
- vectorized scale load;
- dequant in registers;
- no intermediate f16/f32 cache copy;
- page-aware coalescing;
- compare f16 and int8 logits at increasing context.

If GPU supports native lower-precision dot products that can use the KV representation directly, investigate them while preserving softmax numerical stability.

---

# 15. Unified-memory GPU/APU systems

On unified-memory architectures, there may be no explicit PCIe copy, but placement and bandwidth still matter.

Aesir should test:

- first-touch placement;
- explicit prefetch/advice APIs if available;
- CPU and GPU competing for the same memory bandwidth;
- weights on GPU while draft model runs CPU;
- whether simultaneous CPU drafter + GPU target degrades target bandwidth.

Capacity abundance does not mean bandwidth abundance.

---

# 16. Model-size-specific expectations

### 0.6B
Launch/dispatch overhead can dominate. Graph capture and batching matter greatly.

### 1.7B
More arithmetic per launch; strong candidate for GPU multi-agent serving.

### 4B
Balanced resident model with efficient tensor-core prefill and quant decode.

### 8B
Bandwidth-heavy. Q4/Q5 fused kernels and KV memory management are crucial.

---

# 17. Memory planner

Before session start, estimate:

```text
weights
+ KV pages requested/expected
+ activations
+ temporary attention buffers
+ logits
+ CUDA graph/static buffers
+ draft model if same device
+ safety margin
```

Then choose:

- full residency;
- smaller quant;
- int8 KV;
- smaller initial KV allocation;
- CPU/NPU drafter;
- CPU fallback;
- request rejection/queue rather than OOM.

---

# 18. GPU benchmark matrix

Every model x quant should be tested at:

```text
prompt: 128 / 2K / 8K / 32K
output: 128 / 512
batch: 1 / 2 / 4 / 8
KV: f16 / int8 when supported
```

Record:

- TTFT;
- prefill tok/s;
- decode tok/s;
- total wall time;
- device memory;
- GPU utilization;
- memory throughput;
- power/energy;
- quality checksum or oracle result.

---

# 19. Recommended implementation order

1. first-class Qwen3 profiles for all four sizes;
2. fused K-quant decode kernels;
3. optimized prefill GEMM;
4. QK-Norm/RoPE fusion;
5. graph-captured decode;
6. int8-KV attention;
7. paged KV;
8. continuous batching;
9. prefix sharing;
10. heterogeneous speculative placement.

---

# 20. Sources

- https://github.com/QwenLM/Qwen3/blob/main/docs/source/getting_started/speed_benchmark.md
- https://github.com/QwenLM/Qwen3/blob/main/README.md
- Qwen model configs listed in source ledger
- Aesir CUDA and quant optimization evidence in repository
