# 05 - Qwen3-4B Deep Dive for Project A.E.S.I.R.

**Research snapshot:** 2026-11-02  
**Official model:** https://huggingface.co/Qwen/Qwen3-4B

Qwen3-4B is a strong candidate for the default 'serious local assistant' tier in Aesir. It is large enough to gain materially from Qwen3's reasoning and agent training while still fitting comfortably into consumer-class memory under moderate quantization.

---

# 1. Official architecture

| Field | Value |
|---|---:|
| Parameters | ~4.0B |
| Non-embedding parameters | ~3.6B |
| Layers | 36 |
| Hidden size | 2560 |
| FFN intermediate | 9728 |
| Q heads | 32 |
| KV heads | 8 |
| Head dimension | 128 |
| KV width | 1024 |
| Tied embedding / LM head | yes |
| RMSNorm epsilon | 1e-6 |
| RoPE theta | 1,000,000 |
| Native context | 32,768 |
| Extended context | Qwen documents YaRN to 131,072 |
| Architecture | `qwen3` |

Official config: https://huggingface.co/Qwen/Qwen3-4B/blob/main/config.json

---

# 2. Aesir relevance today

The repository already contains real Qwen3-4B evidence through the Zen-4B model-wave work. That campaign found and fixed the Qwen3 RoPE correctness defect, then used raw-input oracle and teacher-forcing checks to show a later suspected defect was actually a prompt-rendering mismatch in the comparison path.

This makes 4B particularly valuable as a continuing regression crown: it is large enough to exercise substantial compute, small enough to test frequently, and already has historical Aesir evidence.

---

# 3. KV-cache economics

Qwen3-4B has 36 layers, 8 KV heads, 128 head dimension.

Aesir f16 KV:

```text
36 * 2 * 8 * 128 * 2 bytes
= 147,456 bytes/token
= 144 KiB/token
```

Aesir's int8-KV accounting shape with row scales:

```text
76,032 bytes/token
```

Approximate cache ladder:

| Context | f16 KV | int8-KV accounting |
|---:|---:|---:|
| 4K | 576 MiB | ~297 MiB |
| 8K | 1.125 GiB | ~594 MiB |
| 16K | ~2.20 GiB | ~1.13 GiB |
| 32K | 4.50 GiB | ~2.32 GiB |
| 64K | 9.00 GiB | ~4.64 GiB |
| 128K | 18.00 GiB | ~9.28 GiB |

This table changes the long-context design conversation. A Q4_K_M 4B checkpoint may be around 2.5 GB, while an f16 32K KV cache alone is 4.5 GiB. At 128K, cache can dwarf weights.

Therefore 4B long context requires:

- quantized KV;
- paged/lazy allocation;
- no full 128K preallocation for ordinary requests;
- prefix sharing where possible;
- history compaction;
- context extension activated only when necessary.

---

# 4. Weight quantization

Typical community GGUF sizes provide a useful scale:

```text
Q2_K    ~1.67 GB
Q3_K_M  ~2.08 GB
Q4_K_M  ~2.50 GB
Q5_K_M  ~2.89 GB
Q6_K    ~3.31 GB
Q8_0    ~4.28 GB
```

Recommended Aesir evaluation order:

- **Q4_K_M**: leading balanced default.
- **Q5_K_M**: quality-biased default if memory bandwidth permits.
- **Q6_K**: quality/reference tier.
- **Q3_K_M**: constrained device tier after reasoning/tool tests.
- **IQ3/IQ2**: task-specific ultra-low-memory experiments.
- **Q8_0**: oracle/reference or systems with large bandwidth headroom.

For 4B, Q4->Q5 may be worth more than on 0.6B because the model has enough reasoning capacity that preserving weights can protect useful higher-level behavior. This is a hypothesis to measure, not a universal rule.

---

# 5. CPU optimization

Qwen3-4B is large enough that batch-1 decode should be treated primarily as a memory-bandwidth problem on typical CPUs.

Important Aesir tactics:

- dequantize in-register or into tiny tiles, not entire layers;
- fuse dequantization with dot-product/GEMV;
- sequential weight traversal to maximize prefetch effectiveness;
- pin threads and memory to the same NUMA node;
- tune the number of active cores to memory bandwidth saturation;
- keep quant metadata contiguous;
- use AVX2/AVX-512/VNNI paths when available;
- avoid false sharing in reductions;
- reuse scratch buffers;
- use larger GEMM tiles for prefill than decode;
- pipeline layer reads where hardware prefetch is insufficient.

At 4B, the difference between a good Q4 kernel and a generic dequant-to-f32 path can dominate every other optimization.

---

# 6. CUDA/GPU optimization

4B is an excellent single-GPU target.

If weights fit entirely in VRAM/unified memory, keep them resident. Layer offload across PCIe should be a fallback, not a default.

Targets:

- fused Q4/Q5 matmul;
- tensor-core prefill path;
- low-launch-overhead decode path;
- CUDA Graphs / captured decode schedule;
- fused RMSNorm/QK-Norm/RoPE where validated;
- flash/tiled attention for prefill;
- optimized single-query GQA for decode;
- int8 KV for long context;
- paged KV for server concurrency;
- prefix-cache reuse.

Qwen's own H20 benchmarks illustrate that an optimized serving engine can make AWQ INT4 or FP8 substantially faster than BF16. Generic framework FP8 can be slower. Aesir should measure its own kernels, not inherit a dtype ranking from another runtime.

---

# 7. Context extension and YaRN

Qwen's current 4B model card distinguishes:

```text
native context: 32,768
validated YaRN extension: 131,072
```

Qwen also warns static YaRN can hurt shorter text. Aesir should therefore make context extension conditional.

Suggested policy:

```text
<= 32K: native RoPE
32K-64K: smallest validated extension factor sufficient for request
64K-128K: larger factor, explicit long-context mode
```

Do not silently use factor 4 for every request merely because the model can reach 128K.

---

# 8. Balanced-assistant role

4B is a natural default for:

- local general assistant;
- coding and repository help;
- structured research summaries;
- multi-tool agent work;
- moderate reasoning;
- creative writing;
- multilingual assistance;
- RAG answer synthesis;
- supervising 0.6B/1.7B workers.

Aesir can route easy tasks down to smaller models and difficult tasks up to 8B or larger models.

A useful hierarchy:

```text
0.6B: route / preprocess / draft
1.7B: worker / tool agent
4B: main assistant / supervisor
8B: escalation / quality pass
```

---

# 9. Thinking policy

For an interactive 4B model, thinking mode becomes more valuable because the model has enough capacity to use the additional reasoning trajectory effectively, but it still costs latency.

Suggested `auto` policy signals:

Enable thinking for:
- math;
- nontrivial coding/debugging;
- planning with dependencies;
- formal reasoning;
- ambiguous multi-tool tasks.

Prefer non-thinking for:
- casual chat;
- rewriting;
- extraction;
- formatting;
- simple lookup after retrieval;
- obvious one-tool calls.

Aesir should log reasoning-token count separately so users can see the latency/cost trade.

---

# 10. Speculative decoding

Candidate drafters:

```text
0.6B -> 4B
1.7B -> 4B
```

The 1.7B is more expensive but may achieve higher acceptance. Aesir should choose dynamically based on observed speedup.

Potential policy:

```text
short/simple generation: 0.6B drafter
code/tool/structured tasks: test 1.7B drafter
hard reasoning: speculation may auto-disable if acceptance collapses
```

A real implementation needs exact KV rollback/reconciliation for both target and drafter plus sampler-state correctness.

---

# 11. Aesir profile proposal

```text
name: qwen3_4b
layers: 36
hidden: 2560
ffn: 9728
q_heads: 32
kv_heads: 8
head_dim: 128
rope_theta: 1000000
tied_embeddings: true
native_context: 32768
yarn_max_validated: 131072
```

Initial deployment policy to test:

```text
weights: Q4_K_M default candidate; Q5_K_M quality profile
KV: f16 correctness baseline; int8 performance profile after integration gate
context: lazy allocation, native <=32K
GPU: preferred when fully resident
CPU: first-class fallback with tuned quant GEMV
reasoning: auto
```

---

# 12. Experiments

### E-4B-01: model-wave regression crown
Preserve exact raw-token prompts from prior Zen work and run on every future Qwen3 kernel change.

### E-4B-02: Q4 vs Q5 vs Q6
Measure tool exactness, coding unit tests, reasoning benchmarks, repetition, multilingual quality, and tokens/s.

### E-4B-03: int8 KV at 8K/32K/64K/128K
Measure retrieval and continuation quality, not just memory.

### E-4B-04: YaRN factor sweep
Compare native, factor 2, factor 4 on short and long tasks to detect short-context regression.

### E-4B-05: 0.6 vs 1.7 drafter
Find crossover where higher acceptance justifies 1.7B's extra draft compute.

### E-4B-06: CUDA Graph decode
Quantify launch-overhead reduction separately from kernel arithmetic.

---

# 13. Sources

- https://huggingface.co/Qwen/Qwen3-4B
- https://huggingface.co/Qwen/Qwen3-4B/blob/main/config.json
- https://qwenlm.github.io/blog/qwen3/
- https://arxiv.org/abs/2505.09388
- https://github.com/QwenLM/Qwen3/blob/main/docs/source/getting_started/speed_benchmark.md
- Aesir: `docs/MODEL_WAVE_CLOUD_HYPERVISOR_EPYC.md`
- Aesir: `docs/janas/J087_KV_PRECISION_CENSUS.md`
- Aesir: `docs/janas/J088_8BIT_KV.md`
