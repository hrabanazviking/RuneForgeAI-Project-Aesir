# 03 - Qwen3-0.6B Deep Dive for Project A.E.S.I.R.

**Research snapshot:** 2026-11-02  
**Official model:** https://huggingface.co/Qwen/Qwen3-0.6B

Qwen3-0.6B is small enough that treating it as merely a miniature chat model misses its most interesting Aesir role. It can become infrastructure: a resident control-plane model that classifies requests, selects tools, rewrites queries, drafts tokens for larger Qwen3 models, repairs formatting, and performs cheap local transformations with very low weight traffic.

---

# 1. Official architecture

| Field | Value |
|---|---:|
| Parameters | ~0.6B |
| Non-embedding parameters | ~0.44B |
| Layers | 28 |
| Hidden size | 1024 |
| FFN intermediate | 3072 |
| Q heads | 16 |
| KV heads | 8 |
| Head dimension | 128 |
| KV width | 1024 |
| Tied embedding / LM head | yes |
| RMSNorm epsilon | 1e-6 |
| RoPE theta | 1,000,000 |
| Native context | 32,768 |
| Weight dtype upstream | BF16 |
| Architecture tag | `qwen3` |

The HF post-trained config currently carries `max_position_embeddings=40960`; Qwen's model card states a 32,768 context target. Aesir should use the documented model behavior rather than advertise the raw metadata integer as a quality guarantee.

---

# 2. Why 0.6B is architecturally unusual in practice

The vocabulary/embedding matrix is a large fraction of this model. Qwen reports only about 0.44B non-embedding parameters, so the tied embedding/LM-head matrix is proportionally far more important than it is in an 8B checkpoint.

Engineering consequences:

- protect the tied embedding/output matrix from reckless low-bit quantization;
- make token-row lookup very cheap;
- optimize the final vocabulary projection carefully;
- do not assume MLP kernels are the only meaningful target;
- mixed-precision quantization can be disproportionately valuable.

---

# 3. Aesir's strongest existing footing

The repository already contains a Qwen3-0.6B verification script and a dense-GQA profile. J-087 also explicitly prices the 0.6B KV geometry as 28 layers, 8 KV heads, 128 head dimension.

Current filed f16 KV cost:

```text
28 layers * 2(K+V) * 8 KV heads * 128 * 2 bytes
= 114,688 bytes/token
= 112 KiB/token
```

This is a useful reminder that the smallest model can still acquire a very large context cache.

---

# 4. KV-memory ladder

Approximate Aesir cache allocation for the 0.6B geometry:

| Context | f16 KV | projected/tested-component int8-KV accounting |
|---:|---:|---:|
| 512 | 56 MiB | ~28.9 MiB |
| 4,096 | 448 MiB | ~231 MiB |
| 8,192 | 896 MiB | ~462 MiB |
| 16,000 | ~1.71 GiB | ~0.88 GiB |
| 32,768 | 3.50 GiB | ~1.80 GiB |

The int8 figure uses Aesir's J-088 per-row scale accounting rather than pretending 8-bit KV costs exactly 50% of f16. For this geometry the projected store is 59,136 bytes/token, approximately 51.56% of f16.

That means an aggressively weight-quantized 0.6B can easily end up using more RAM for long-context KV than for weights.

---

# 5. Weight quantization strategy

Observed community GGUF files provide a useful size scale, though exact size varies by quantizer and metadata. Typical examples are roughly:

```text
Q2_K    ~0.35 GB
Q3_K_M  ~0.41 GB
Q4_K_M  ~0.48 GB
Q5_K_M  ~0.55 GB
Q6_K    ~0.62 GB
Q8_0    ~0.80 GB
```

For 0.6B, saving another 100 MB by moving from a moderate quant to an extreme quant can be a bad trade if tool-call reliability or reasoning deteriorates.

Recommended Aesir profiles to test:

- **Q5_K_M / Q6_K**: quality-first resident worker.
- **Q4_K_M**: likely default for drafter/router workloads if quality passes.
- **Q3_K_M**: memory-constrained embedded worker only after task-specific validation.
- **IQ2 / Q2_K**: specialized experiments, not general default.
- **Q8_0**: useful correctness/oracle step and when RAM is irrelevant, but the extra bandwidth may not buy proportionate quality.

Because the absolute checkpoint is already tiny, 0.6B should generally spend bits on preserving accuracy rather than chase heroic compression for its own sake.

---

# 6. CPU strategy

This is the model where 'more threads' can easily become slower.

At only 0.6B parameters, thread synchronization, cache bouncing, task dispatch, and packing overhead can be a meaningful fraction of token time. Aesir should benchmark thread counts such as:

```text
1, 2, 3, 4, physical-core-count, all-logical-cores
```

rather than defaulting to maximum CPU parallelism.

High-value CPU work:

1. persistent worker threads rather than thread creation per token;
2. NUMA-local/pinned model pages;
3. fused quant decode + dot product;
4. no heap allocation in the token loop;
5. fused residual + norm where measurable;
6. vectorized SiLU multiply;
7. model-specific block sizes for hidden=1024 and FFN=3072;
8. direct quantized embedding lookup;
9. efficient LM-head reduction/top-k selection.

The entire quantized model may fit comfortably in large last-level caches on some server CPUs or at least have much friendlier cache residency than larger models. Measurements should include warm steady-state decode separately from cold first-token behavior.

---

# 7. GPU strategy

A discrete GPU is not automatically the fastest answer for 0.6B at batch 1. Kernel launches and host/device coordination can consume a noticeable share of runtime.

GPU optimization priorities:

- keep all weights resident;
- use CUDA Graphs or an equivalent persistent launch strategy for decode;
- fuse tiny pointwise kernels;
- batch multiple requests when serving;
- separate prefill GEMM kernels from decode GEMV-like kernels;
- avoid CPU/GPU ping-pong at layer granularity;
- use fused low-bit matmul rather than dequantizing whole layers to an intermediate buffer.

Aesir should explicitly compare:

```text
CPU only
GPU only
NPU only when available
CPU prefill + GPU decode
GPU prefill + CPU decode
```

The mixed modes should survive only if data-transfer cost is actually lower than their compute advantage.

---

# 8. NPU / Hailo role

0.6B is arguably the most attractive Qwen3 target for Aesir's accelerator experiments.

Reasons:

- compact weights;
- 28 regular dense blocks;
- fixed 8-head KV geometry;
- useful as an always-resident background model;
- lower bandwidth requirement than 1.7B/4B/8B;
- enough capability for control-plane tasks where a huge model is wasteful.

Aesir already has a verified Hailo compiled-model route for a Qwen2.5 1.5B-class model, while the fully Aesir-owned source-model-to-Hailo pipeline remains incomplete/parked. Qwen3-0.6B would be a logical first Qwen3 target when that road resumes.

Implementation checklist for accelerator admission:

- QK-Norm support;
- correct split-half RoPE;
- SwiGLU;
- GQA 16/8;
- no accidental conventional BOS injection;
- tokenizer/chat semantics handled outside accelerator graph if necessary;
- KV-cache precision and ownership explicitly defined.

---

# 9. Best workloads

Good candidate workloads for a 0.6B resident worker:

- intent classification;
- tool candidate ranking;
- simple function argument extraction with validation;
- query rewriting for search/RAG;
- document chunk labeling;
- format normalization;
- short summarization;
- spelling/grammar repair;
- conversation routing;
- safety-independent application policy classification;
- speculative token drafting;
- simple coding transformations;
- autonomous heartbeat/status text in an agent system.

Tasks that should be escalated more readily:

- difficult multi-step math;
- deep code architecture;
- ambiguous tool planning with many dependencies;
- long-context synthesis where small-model instruction adherence becomes fragile;
- high-stakes decisions;
- tasks where exact factual recall matters more than latency.

---

# 10. Thinking-mode policy

Qwen3-0.6B supports thinking mode, but reasoning tokens are not free. On a tiny local worker, hidden reasoning can multiply latency without necessarily closing the gap to a much larger model.

Recommended router policy:

```text
simple classification / formatting / tool routing -> non-thinking
difficult local reasoning                        -> thinking, bounded
very difficult task                              -> escalate model size
```

This suggests Aesir should support both a reasoning budget and a model-escalation budget.

---

# 11. Sampling

Qwen's official recommendations:

Thinking:

```text
temperature 0.6
top_p       0.95
top_k       20
min_p       0
avoid greedy decoding
```

Non-thinking:

```text
temperature 0.7
top_p       0.8
top_k       20
min_p       0
```

For quantized Qwen3, Qwen specifically suggests using `presence_penalty` when endless repetition appears, with 1.5 given as a useful value in model guidance. Aesir should not force that globally because too much penalty can cause language mixing and quality loss.

---

# 12. Speculative decoding role

0.6B is the natural first drafter to test because it is cheap enough that rejected draft tokens may still be worthwhile.

Candidate targets:

```text
0.6B -> 1.7B
0.6B -> 4B
0.6B -> 8B
```

Expected behavior should be measured by workload class:

- boilerplate prose may yield high acceptance;
- tool-call syntax may yield good acceptance if templates are identical;
- code completion can be promising on repetitive/local structure;
- hard reasoning may yield poor acceptance because internal trajectories diverge;
- thinking mode likely reduces cross-size alignment on complex problems.

Aesir should auto-disable speculation when rolling acceptance rate falls below a profitability threshold.

---

# 13. Prefix-cache role

0.6B is ideal for a persistent agent that sees the same system prompt and tool schema repeatedly. Prefix caching can eliminate repeated prefill work.

Cache key must include at minimum:

```text
model file SHA
quant/kernel interpretation
exact token IDs
RoPE/YaRN policy
chat-template version
```

Never cache by raw text alone.

---

# 14. Aesir-specific profile proposal

Add a canonical runtime profile roughly equivalent to:

```text
name: qwen3_0_6b
layers: 28
hidden: 1024
ffn: 3072
q_heads: 16
kv_heads: 8
head_dim: 128
rope_theta: 1000000
tied_embeddings: true
native_context: 32768
```

Runtime defaults should remain adaptive rather than hard-coded, but a useful initial policy is:

```text
weight quant: Q4_K_M or Q5_K_M
KV: int8 when integrated and quality-proven, f16 fallback
context allocation: lazy, not full 32K reservation
reasoning: non-thinking by default for worker profile
accelerator: auto-benchmark CPU vs GPU/NPU
```

---

# 15. Experiments

### E-0.6-01: thread-count sweep
Measure decode tokens/s and energy/token at 1/2/4/all cores.

### E-0.6-02: quant quality ladder
Q8_0, Q6_K, Q5_K_M, Q4_K_M, Q3_K_M, selected IQ formats across tool calling, coding, multilingual, math, and repetition tests.

### E-0.6-03: launch-overhead study
CPU vs CUDA at batch 1, then concurrency 2/4/8.

### E-0.6-04: int8 KV quality
Compare f16 and int8 KV at 2K/8K/16K/32K with token-level divergence and retrieval tasks.

### E-0.6-05: drafter profitability
Use 0.6B to draft for 1.7B/4B/8B and record acceptance, target passes saved, total wall time, and memory overhead.

### E-0.6-06: Hailo/NPU feasibility
When the native compiler road resumes, make 0.6B the first Qwen3 acceptance target.

---

# 16. Sources

- https://huggingface.co/Qwen/Qwen3-0.6B
- https://huggingface.co/Qwen/Qwen3-0.6B/blob/main/config.json
- https://qwenlm.github.io/blog/qwen3/
- https://arxiv.org/abs/2505.09388
- https://github.com/QwenLM/Qwen3/blob/main/docs/source/getting_started/speed_benchmark.md
- Aesir: `docs/janas/J087_KV_PRECISION_CENSUS.md`
- Aesir: `docs/janas/J088_8BIT_KV.md`
- Aesir: `scripts/verify_qwen3_k_quants.sh`
