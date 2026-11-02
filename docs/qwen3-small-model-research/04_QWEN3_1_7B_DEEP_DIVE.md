# 04 - Qwen3-1.7B Deep Dive for Project A.E.S.I.R.

**Research snapshot:** 2026-11-02  
**Official model:** https://huggingface.co/Qwen/Qwen3-1.7B

Qwen3-1.7B is likely the most strategically interesting 'small worker' in this four-model set. It preserves the compact 28-layer / 16Q-8KV geometry of 0.6B but doubles hidden width and delivers a large capability jump while remaining small enough for aggressive edge deployment.

---

# 1. Official architecture

| Field | Value |
|---|---:|
| Parameters | ~1.7B |
| Non-embedding parameters | ~1.4B |
| Layers | 28 |
| Hidden size | 2048 |
| FFN intermediate | 6144 |
| Q heads | 16 |
| KV heads | 8 |
| Head dimension | 128 |
| KV width | 1024 |
| Tied embedding / LM head | yes |
| RMSNorm epsilon | 1e-6 |
| RoPE theta | 1,000,000 |
| Documented context | 32,768 |
| Architecture | `qwen3` |

Official config: https://huggingface.co/Qwen/Qwen3-1.7B/blob/main/config.json

---

# 2. Why 1.7B may be the small-model sweet spot

Qwen3's reported benchmark scaling shows that 1.7B can be dramatically stronger than 0.6B on reasoning while still being only a fraction of the size of 4B/8B. The technical report's post-training tables, for example, show a particularly large jump in math/reasoning-oriented evaluations between 0.6B and 1.7B.

The engineering implication is not that one benchmark defines the model. It is that Aesir should test 1.7B as the default 'worker with judgment' before paying 4B/8B cost for every task.

Candidate roles:

- local agent worker;
- first-line coding helper;
- tool selection and parameter drafting;
- retrieval-query planner;
- document triage/summarization;
- smaller interactive assistant;
- speculative drafter for 4B/8B;
- autonomous background task model.

---

# 3. KV cache is identical per token to 0.6B

Because 1.7B keeps the same 28 layers, 8 KV heads, and 128-dimensional KV heads, its KV cache costs exactly the same per token as 0.6B under Aesir's current dense layout:

```text
114,688 bytes/token f16
59,136 bytes/token in Aesir's int8-KV accounting shape
```

| Context | f16 KV | int8-KV accounting |
|---:|---:|---:|
| 4K | 448 MiB | ~231 MiB |
| 8K | 896 MiB | ~462 MiB |
| 16K | ~1.71 GiB | ~0.88 GiB |
| 32K | 3.50 GiB | ~1.80 GiB |

This is a major deployment insight: moving from 0.6B to 1.7B increases weight memory substantially but **does not increase per-token KV memory**.

For medium/long contexts, the relative cost of upgrading from 0.6B to 1.7B is therefore smaller than raw parameter count suggests.

---

# 4. Weight quantization

Community GGUF examples place common files roughly around:

```text
Q2_K    ~0.88 GB
Q3_K_M  ~1.07 GB
Q4_K_M  ~1.28 GB
Q5_K_M  ~1.47 GB
```

Exact values vary by producer, tokenizer metadata, and quantization method.

Recommended test hierarchy:

- **Q4_K_M**: leading candidate for general Aesir default.
- **Q5_K_M**: quality-biased worker/main assistant on machines with room.
- **Q6_K**: oracle-adjacent quality test when bandwidth remains acceptable.
- **Q3_K_M**: low-memory edge configuration.
- **IQ2/3**: only after rigorous tool/reasoning quality tests.
- **Q8_0**: correctness/reference and systems where memory bandwidth is not limiting.

Because 1.7B is meant to perform actual agent work, tool-call exactness and instruction adherence should receive more weight than raw perplexity when selecting a quant.

---

# 5. CPU behavior

1.7B is large enough that weight bandwidth becomes more dominant than 0.6B, but still small enough for excellent CPU responsiveness on modern desktop/laptop processors.

Priority work:

- fused K-quant GEMV for batch-1 decode;
- tiled quant GEMM for prefill;
- no full-layer dequantization on every token;
- persistent decoded/packed metadata;
- core pinning and NUMA locality;
- prefetch next weight blocks while current blocks execute;
- thread-count autotuning by phase;
- separate prefill and decode thread settings if profitable.

Aesir should consider a **phase-specific thread plan**:

```text
prefill: more cores, larger chunks
decode: enough cores to saturate memory bandwidth, no more
```

Once memory bandwidth saturates, adding cores can increase contention without increasing tokens/s.

---

# 6. GPU behavior

1.7B is a stronger GPU candidate than 0.6B because each layer has more arithmetic per dispatch. Still, a tiny batch can underutilize a high-end GPU.

Optimization targets:

- keep full checkpoint resident;
- use fused quantized matmul;
- graph/capture repeated decode sequence;
- fuse norm/QK-Norm/RoPE where correctness allows;
- use prefill-specific tensor-core GEMM;
- use low-overhead decode kernels;
- quantize KV when context grows;
- avoid allocating the 32K cache up front for short chats.

Serving several independent worker requests concurrently can turn otherwise idle GPU capacity into useful throughput.

---

# 7. NPU and accelerator role

1.7B is especially attractive because Aesir has already physically proven a compiled Hailo route with a Qwen2.5 1.5B-class model. That does not mean Qwen3-1.7B works automatically, but it makes this scale a highly relevant next target.

Required Qwen3-specific deltas include:

- QK-Norm;
- correct Qwen3 RoPE;
- tokenizer/chat semantics;
- tensor geometry 2048/6144;
- any quant format differences;
- validated KV ownership and precision.

If the whole 1.7B model can remain resident on an NPU-class device, it could serve as an always-on agent worker while GPU resources remain free for larger models or visual generation.

---

# 8. Speculative-decoding value

1.7B may be the best general drafter for the 4B and 8B targets.

Why it is promising:

- same Qwen3 tokenizer;
- same chat template family;
- same 128 head dimension and 8 KV heads;
- stronger token prediction than 0.6B, potentially yielding higher acceptance;
- still much cheaper than the target.

Pairs to benchmark:

```text
1.7B -> 4B
1.7B -> 8B
```

Do not assume `1.7B -> 8B` wins merely because the drafter is small. Profitability is:

```text
(draft tokens accepted * target work avoided)
  > drafter compute + verification overhead + extra memory traffic
```

Aesir should adapt draft length `k` based on rolling acceptance.

---

# 9. Agent profile

1.7B deserves a first-class agent-worker profile rather than only a generic chat profile.

Suggested policy:

```text
reasoning mode: auto
simple tools: non-thinking
multi-step plan: thinking with bounded budget
schema validation: mandatory
max context by default: 8K or 16K, expand only on request
weight quant: Q4_K_M candidate default
KV: int8 when integrated/proven; f16 fallback
prefix cache: on for stable system/tool prefixes
```

The engine should expose escalation to 4B/8B when confidence/validation fails rather than forcing 1.7B to grind through a task it is poorly suited to solve.

---

# 10. Tool calling

Qwen explicitly positions Qwen3 as agent-capable and recommends Qwen-Agent templates/parsers. For Aesir, the critical implementation lesson is protocol discipline:

- parse tool calls structurally;
- validate function name and schema;
- never trigger tools by matching text inside `<think>`;
- do not use ReAct stopword hacks;
- make malformed tool output repairable without executing it;
- allow a larger model to verify expensive or destructive actions at the application layer when appropriate.

1.7B should be benchmarked on **exact tool-call success rate**, not just whether its prose 'looks right.'

---

# 11. Long conversations

Qwen's best practices recommend avoiding retention of historical thinking content in the conversational history, keeping final answers instead. This is valuable for Aesir in three ways:

1. lower token count;
2. smaller KV cache;
3. less chance old reasoning text pollutes future instructions.

For a 32K native model, Aesir should implement history compaction before simply allocating the maximum window.

Suggested hierarchy:

```text
keep system/tools
keep recent turns verbatim
keep important pinned facts
summarize older turns
exclude old hidden reasoning
```

---

# 12. Why 1.7B deserves independent tuning from 0.6B

The two models share layer/KV geometry, but their compute shapes differ significantly:

```text
0.6B: hidden 1024, FFN 3072
1.7B: hidden 2048, FFN 6144
```

That doubles core dimensions and changes:

- optimal vector blocking;
- cache behavior;
- GPU occupancy;
- matrix tile shape;
- thread scaling;
- weight bandwidth;
- prefill/decode balance.

Aesir must not use 'same 28 layers' as a reason to reuse the exact same tuning constants.

---

# 13. First acceptance suite for Aesir

Before declaring a first-class profile:

1. load official BF16 or a trusted GGUF;
2. verify exact tensor geometry;
3. compare reference tokenizer IDs;
4. compare rendered chat tokens;
5. first-token logit comparison;
6. teacher-forced 64-128 token trajectory;
7. greedy raw-token oracle trajectory;
8. thinking and non-thinking generation;
9. tool-call parse round trip;
10. 4K/16K/32K retrieval tests;
11. Q4/Q5/Q6 quality matrix;
12. memory accounting versus measured RSS/VRAM.

---

# 14. Experiments

### E-1.7-01: worker benchmark
Compare 0.6B/1.7B/4B on 100 realistic agent subtasks and compute quality per joule and quality per millisecond.

### E-1.7-02: Q4 vs Q5 default
Measure whether Q5 improves tool-call/format reliability enough to justify the extra bandwidth.

### E-1.7-03: draft model for 8B
Sweep draft length `k=1..16`, workload types, thinking/non-thinking, and contexts.

### E-1.7-04: NPU residency
Measure end-to-end, including transfer, not isolated accelerator kernel time.

### E-1.7-05: phase-specific thread plan
Independent prefill/decode thread-count sweep.

### E-1.7-06: int8-KV 32K
Compare retrieval accuracy and token divergence against f16.

---

# 15. Sources

- https://huggingface.co/Qwen/Qwen3-1.7B
- https://huggingface.co/Qwen/Qwen3-1.7B/blob/main/config.json
- https://qwenlm.github.io/blog/qwen3/
- https://arxiv.org/abs/2505.09388
- https://github.com/QwenLM/Qwen3/blob/main/docs/source/getting_started/speed_benchmark.md
- Aesir: `docs/janas/J087_KV_PRECISION_CENSUS.md`
- Aesir: `docs/janas/J088_8BIT_KV.md`
