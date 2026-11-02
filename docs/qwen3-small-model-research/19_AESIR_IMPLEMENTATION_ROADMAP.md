# 19 - Project A.E.S.I.R. Qwen3 Small-Model Implementation Roadmap

**Research snapshot:** 2026-11-02

This roadmap turns the research library into an implementation sequence. It is intentionally evidence-gated: every stage has a definition of done before later optimizations become default claims.

---

# Phase 0 - Preserve the truth boundary

Before changing code:

- retain existing Qwen3 0.6B verification fixtures;
- retain Zen/Qwen3-4B oracle prompts and evidence;
- retain known-value K/IQ decoder tests;
- retain J-087 KV accounting;
- retain J-088 int8-KV component tests;
- keep speculative paths fail-closed where real integration is absent.

**Done when:** current master suite and relevant physical/reference tests have a reproducible baseline.

---

# Phase 1 - First-class profiles for all four models

Add/verify explicit dense-Qwen3 profiles derived from file metadata:

```text
0.6B: layers 28, hidden 1024, ffn 3072, Q/KV 16/8
1.7B: layers 28, hidden 2048, ffn 6144, Q/KV 16/8
4B: layers 36, hidden 2560, ffn 9728, Q/KV 32/8
8B: layers 36, hidden 4096, ffn 12288, Q/KV 32/8
head_dim = 128
rope_theta = 1e6
```

Do not hard-code model identity by filename. Admit by architecture + tensor/config geometry.

**Done when:** each official/trusted file is admitted and tensor mapping is exact.

---

# Phase 2 - Tokenizer and template crown

Build Qwen3 token fixtures for:

- plain user chat;
- system+user;
- multi-turn;
- thinking;
- non-thinking;
- `/think` and `/no_think`;
- tool definitions/calls/results.

Pin reference tokenizer revision.

**Done when:** Aesir renders identical token IDs to reference for all fixtures.

---

# Phase 3 - Model correctness crown

For each size:

- first-token logits;
- teacher-forced multi-token comparison;
- exact greedy raw-token trajectory;
- reset and multi-turn;
- tied/untied LM-head path;
- QK-Norm and RoPE vector checks.

**Done when:** all four have a filed correctness verdict, with discrepancies explained rather than hand-waved.

---

# Phase 4 - Quant acceptance matrix

Run:

```text
Q8_0
Q6_K
Q5_K_M
Q4_K_M
Q3_K_M
Q2_K
selected IQ formats
```

for each size.

Separate:

- file decodes correctly;
- model produces coherent output;
- quality passes Aesir workload gate;
- optimized fast kernel exists.

**Done when:** the repo can state evidence-backed default candidates per size.

---

# Phase 5 - CPU decode optimization

Priority:

1. Q4_K_M fused decode;
2. Q5_K_M fused decode;
3. Q6/Q8 tuned paths;
4. Q3/IQ only where worthwhile;
5. thread/affinity autotuning;
6. output-head/top-k optimization.

Create per-size crown workloads.

**Done when:** batch-1 decode is memory-efficient, no per-token full-layer decode/allocation occurs, and performance is repeatable.

---

# Phase 6 - CPU prefill optimization

Add:

- dedicated GEMM-like quant prefill path;
- tiled causal attention;
- prompt chunking;
- phase-specific thread plan.

**Done when:** prefill no longer shares a decode-optimized path that leaves obvious matrix reuse unused.

---

# Phase 7 - CUDA resident Qwen3

For each size:

- full model residency when memory permits;
- Q4/Q5 fused GPU matmul;
- prefill tensor-core path;
- low-overhead decode;
- correct GQA attention;
- QK-Norm/RoPE fusion candidate;
- graph-captured decode experiment.

**Done when:** CPU and CUDA have separate evidence tables for TTFT/prefill/decode/memory.

---

# Phase 8 - Int8 KV integration

Take the tested component into a complete Qwen3 session:

- append;
- attention read/dequant;
- reset;
- rollback;
- CPU;
- CUDA;
- quality comparison.

**Done when:** 0.6/1.7 and 4/8 geometry both pass short/long context quality gates and measured memory matches accounting.

---

# Phase 9 - Production paged KV

Wire page allocation into real sessions.

Features:

- lazy pages;
- page table;
- logical position mapping;
- rollback;
- memory accounting;
- concurrency.

**Done when:** paged and contiguous reference paths are logit-equivalent under the same precision.

---

# Phase 10 - Lift practical context caps

After paging/int8 KV:

- prove 32K on all four where upstream supports it;
- implement YaRN for 4B/8B;
- prove 64K;
- prove 128K;
- add memory admission control.

**Done when:** context claims are backed by physical runs and long-context quality tests.

---

# Phase 11 - Prefix cache and shared pages

Implement:

- exact-token prefix lookup;
- reference-counted immutable KV pages;
- LRU/cost-aware eviction;
- telemetry for saved tokens/time.

**Done when:** multiple sessions can reuse the same system/tool prefix without duplicating KV or changing logits.

---

# Phase 12 - Thinking-aware API

Expose:

```text
reasoning_mode
reasoning_content
final_content
reasoning_token_count
```

Add official sampler presets and repetition handling.

**Done when:** applications no longer need Qwen3-specific string hacks to switch modes.

---

# Phase 13 - Agent/tool protocol

Implement/verify:

- Qwen-compatible templates;
- structural tool parser;
- schema validation;
- no ReAct stopword triggering;
- repair/retry policy;
- exact agent benchmark.

**Done when:** tool-call success is measured as exact structured behavior.

---

# Phase 14 - Real speculative loop

Build on existing Aesir Janas draft work:

1. real drafter session;
2. token synchronization;
3. batched verification;
4. KV rollback;
5. greedy exactness;
6. adaptive k;
7. lose detection;
8. sampled reconciliation;
9. heterogeneous placement.

**Done when:** at least one Qwen3 pair achieves reproducible net wall-time speedup with unchanged target semantics.

---

# Phase 15 - Multi-model routing

Add optional policy engine:

```text
0.6B router
1.7B worker
4B main assistant
8B escalation
```

Routing inputs:

- task type;
- latency target;
- quality mode;
- hardware load;
- memory pressure;
- prior validation success.

**Done when:** benchmarked task success per joule/time improves over always-8B baseline.

---

# Phase 16 - Continuous batching

Implement:

- active-sequence scheduler;
- decode microbatches;
- variable sequence lengths;
- paged KV integration;
- latency/throughput modes.

**Done when:** concurrency increases total throughput without unacceptable interactive p95 latency.

---

# Phase 17 - Hailo/NPU Qwen3 resume

When project direction resumes native accelerator compilation:

1. Qwen3-0.6B first;
2. Qwen3-1.7B second;
3. QK-Norm + RoPE proof;
4. full block parity;
5. complete model trajectory;
6. energy benchmark;
7. drafter/worker role integration.

**Done when:** physical evidence exists through Aesir-owned lowering, not only a precompiled compatible model route.

---

# Phase 18 - Autotuning

Persist best:

- CPU threads;
- kernel variants;
- prefill chunks;
- GPU graph policy;
- KV page size;
- draft pair/k.

Key by hardware/model/Aesir identity.

**Done when:** sane fast settings are automatic but fully inspectable.

---

# Phase 19 - Release-quality evidence pack

Produce one canonical report containing:

- model/quant matrix;
- correctness status;
- quality status;
- CPU/GPU/NPU results;
- KV memory ladder;
- context support;
- tool-call success;
- speculative results;
- remaining gaps.

No vague 'supports Qwen3' sentence should replace this matrix.

---

# Priority summary

## P0 correctness
- profiles;
- tokenizer/chat;
- QK-Norm/RoPE;
- model oracle.

## P1 memory
- int8 KV;
- paged/lazy KV;
- context admission.

## P2 speed
- Q4/Q5 decode;
- prefill kernels;
- GPU graph/fusion;
- prefix cache.

## P3 higher-level acceleration
- speculative decoding;
- batching;
- multi-model routing.

## P4 heterogeneous future
- Hailo/NPU native Qwen3 compiler route.

---

# Definition of the end state

Aesir should ultimately be able to load any of the four dense small Qwen3 models and automatically answer:

```text
What model/quant is this?
Is it proven correct?
What kernel path is fastest here?
How much memory will this context use?
Should KV be f16 or int8?
Should YaRN be enabled?
Can a prefix be reused?
Would a drafter help?
Which device should run each phase?
What quality/performance evidence supports these choices?
```

That is the difference between merely executing a GGUF and operating a true local-inference engine.