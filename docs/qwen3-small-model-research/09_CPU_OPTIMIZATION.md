# 09 - CPU Optimization for Qwen3 0.6B / 1.7B / 4B / 8B

**Research snapshot:** 2026-11-02

CPU inference for dense Qwen3 is primarily a problem of moving quantized weights efficiently, keeping hot data local, and avoiding overhead that becomes disproportionately expensive on the smaller models.

---

# 1. Separate the two phases

## Prefill

Many prompt tokens are processed together. Matrix operations become GEMM-like, and weight reuse across tokens is available.

Optimize for:

- large tiles;
- cache reuse;
- SIMD/vector occupancy;
- multiple cores;
- chunked prompt blocks;
- dequantization amortized across several token rows.

## Decode

Usually one token per active sequence. Matrix operations are GEMV/skinny-GEMM-like and weights are streamed repeatedly.

Optimize for:

- lowest possible bytes read;
- fused dequant + dot;
- no allocations;
- minimal synchronization;
- persistent threads;
- memory-bandwidth saturation rather than maximum core count.

One kernel policy should not serve both phases by accident.

---

# 2. Roofline thinking

At batch-1 decode, a simple first-order estimate is:

```text
max tokens/s ~= sustainable memory bandwidth / effective model bytes read per token
```

This ignores KV, activations, and arithmetic, but it quickly identifies impossible claims.

For an 8B Q4-class file around 5 GB, 10 tok/s implies roughly 50 GB/s of model-weight traffic before other overhead. If the machine can sustain only 45 GB/s, compute micro-optimizations cannot magically deliver 30 tok/s without reducing traffic or increasing reuse.

Aesir benchmarks should report both tokens/s and approximate achieved bandwidth.

---

# 3. Persistent quantized representation

Never repeatedly transform immutable model weights during decode.

On load:

- validate tensor layout;
- build lightweight runtime descriptors;
- align/pin mappings as appropriate;
- precompute offsets/strides;
- build any tiny lookup/codebook data once.

During token generation:

- stream quant blocks;
- decode only the block needed for the current vector lane/tile;
- accumulate immediately;
- do not allocate or expand a full matrix.

This aligns with Aesir's existing direction of decode-once/fast K-quant paths.

---

# 4. SIMD specialization

Runtime dispatch should select the best available path:

```text
portable scalar/reference
SSE/NEON where relevant
AVX2
AVX-512
VNNI / dot-product extensions
other architecture-specific SIMD
```

The reference implementation remains essential for correctness. Optimized paths must be cross-checked against known-value quant fixtures and model-level logits.

Potential per-quant specialization:

- Q8_0: integer/vector dot products and scale handling;
- Q4/Q5/Q6 K-quants: block unpack + vector FMA/dot;
- IQ formats: codebook/layout-specialized decode.

---

# 5. Thread count is a tuning variable

More threads help until they do not.

Common failure modes:

- saturating memory bandwidth before all cores are active;
- cache line contention;
- reduction overhead;
- scheduler migration;
- hyperthreads competing for the same core resources;
- tiny 0.6B kernels spending more time coordinating than computing.

Aesir should auto-benchmark thread counts per model and phase.

Candidate sweep:

```text
1
2
4
physical cores / 2
physical cores
logical cores
```

Persist the winner keyed by CPU model + model SHA + quant + Aesir build.

---

# 6. Affinity and NUMA

For multi-socket or chiplet systems:

- pin worker threads;
- keep model pages near workers;
- avoid remote NUMA reads during every layer;
- benchmark one-node execution versus interleaved placement;
- if splitting work across NUMA nodes, split contiguous tensor regions rather than create random remote access.

On small laptops, affinity can still reduce scheduler jitter and improve repeatability.

---

# 7. Memory mapping

Large GGUF-style checkpoints benefit from memory mapping for load time and page sharing, but runtime policy matters:

- sequential access hints can help OS readahead;
- avoid accidental page eviction by giant unrelated allocations;
- measure `mmap` versus explicit resident loading;
- warm benchmark separately from cold-start behavior;
- never count filesystem cache as 'free memory' without stating methodology.

For 0.6B/1.7B, locking the entire working set may be feasible. For 8B, the OS page cache and memory pressure can materially affect steady-state speed.

---

# 8. Huge pages

Transparent or explicit huge pages can reduce TLB pressure for large sequential weight streams, but results are platform-dependent.

Experiment rather than mandate:

```text
normal pages
transparent huge pages
explicit huge pages where available
```

Measure load latency, tokens/s, and memory behavior. Do not turn a Linux tuning anecdote into an engine invariant.

---

# 9. Prefetching

Hardware prefetchers already handle many sequential streams. Software prefetch is useful only when it arrives early enough and does not evict useful cache lines.

Good candidates:

- next quant block;
- next scale block;
- next matrix tile.

Bad candidate:

- enormous speculative lookahead that pollutes caches.

Each quant decoder should have a prefetch-distance experiment.

---

# 10. Scratch memory

Create scratch arenas once per session/thread pool.

Forbidden in hot decode loop unless proven unavoidable:

- heap allocate temporary vector;
- allocate normalized Q/K tensor every layer;
- create transient strings;
- rebuild shape objects;
- repeatedly parse metadata.

A 0.6B model can expose this overhead brutally because its actual math is so small.

---

# 11. Fusion candidates

High-value fusions to benchmark:

- residual add + RMSNorm;
- Q/K projection output + QK-Norm + RoPE;
- quant decode + matvec;
- gate/up projections scheduling + SwiGLU multiply;
- final norm + LM-head input staging;
- sampling top-k extraction while scanning logits.

Fusion is not automatically good. Excessive monolithic kernels can increase register pressure and reduce vectorization. Keep a benchmarkable unfused path.

---

# 12. Attention decode

For one new token, attention reads historical K/V and computes scores against the current Q.

Optimize:

- GQA reuse: one KV head serves multiple Q heads;
- contiguous KV layout;
- vectorized dot products;
- online softmax to avoid storing all scores;
- fused score/softmax/value accumulation where possible;
- int8-KV decode with vector conversion/scale handling;
- avoid materializing expanded K/V for 32 Q heads.

At long context, attention can become a significant bandwidth consumer even if weight decode remains dominant.

---

# 13. Attention prefill

Do not materialize an N x N score matrix for long prompts if an online/tiled attention algorithm can avoid it.

CPU-friendly tiled attention should:

- process Q blocks;
- stream K/V blocks;
- maintain online softmax statistics;
- keep temporary memory bounded;
- respect causal masking without giant masks.

Long-context 4B/8B makes this increasingly important.

---

# 14. LM head

Vocabulary projection is significant, especially on 0.6B where the vocabulary matrix is a large fraction of the model.

Optimize:

- quantized output-head matvec;
- efficient reduction;
- top-k selection without full sort;
- reuse scratch arrays;
- avoid converting the full logits vector between dtypes multiple times.

The model still needs all logits for exact top-p behavior unless an approximate sampler is deliberately chosen.

---

# 15. Sampling overhead

For small models, sampling can be a visible percentage of token latency.

Aesir should benchmark:

- greedy/reference;
- top-k only;
- top-k + top-p;
- min-p;
- repetition/presence penalties;
- grammar/structured constraints.

Efficient implementation:

1. apply penalties in one pass;
2. find top candidates without sorting 151K logits when possible;
3. normalize only candidate subset if mathematically valid for configured sampler;
4. maintain deterministic RNG state.

---

# 16. Per-size CPU tuning hypotheses

### 0.6B
Overhead-sensitive. Fewer threads and aggressive fusion may win.

### 1.7B
Still latency-friendly; likely strong desktop CPU worker. Bandwidth begins to matter more.

### 4B
Quantized weight bandwidth is central. Tune to memory saturation.

### 8B
Strongly bandwidth-bound at batch 1 on many CPUs. Low-bit kernel quality dominates.

These are hypotheses to verify on every hardware class.

---

# 17. Server/concurrency behavior

Batching changes the economics by reusing weight reads across several sequences.

For CPU serving:

- batch active decode tokens into small GEMM when latency SLO allows;
- dynamic microbatch window should be tiny for interactive workloads;
- reuse shared prefixes;
- avoid one thread pool per request;
- central scheduler should understand current context lengths.

Throughput mode and interactive mode need different policies.

---

# 18. Measurement harness

Record:

```text
CPU model and microcode
RAM channels/speed
NUMA topology
OS/kernel
Aesir SHA
model SHA
quant
threads and affinity
context length
prompt length
output length
TTFT
prefill tok/s
decode tok/s
RSS
CPU utilization
package power/energy if available
```

Run enough repetitions to report median and spread, not one lucky sample.

---

# 19. Suggested implementation order

1. exact model profiles for all four sizes;
2. separate prefill/decode dispatch;
3. fused Q4/Q5 decode kernels;
4. thread/affinity autotuner;
5. tiled long-context attention;
6. int8-KV attention kernels;
7. prefix cache/microbatch scheduler;
8. architecture-specific SIMD expansion.

---

# 20. Sources

- Official Qwen speed benchmark: https://github.com/QwenLM/Qwen3/blob/main/docs/source/getting_started/speed_benchmark.md
- Model configs in `01_SOURCE_LEDGER_AND_METHODOLOGY.md`
- Aesir model-wave and quant fast-path evidence
