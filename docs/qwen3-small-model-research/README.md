# Qwen3 Small-Model Research Library for Project A.E.S.I.R.

**Research snapshot:** 2026-11-02  
**Scope:** `Qwen3-0.6B`, `Qwen3-1.7B`, `Qwen3-4B`, `Qwen3-8B`  
**Aesir baseline inspected:** `main` at `34b7c1bd1fe8ed0e2e4ea7b410f1ef331e118748` before this library was added.

This directory is a performance-and-implementation research library for making the four smallest dense Qwen3 models run as well as possible in Project A.E.S.I.R. It is deliberately broader than a model-card summary. It studies architecture, inference math, quantization, KV-cache economics, CPU and GPU kernels, accelerator placement, long context, YaRN, Qwen3 thinking behavior, sampling, agents, tool calls, speculative decoding, batching, prompt caching, validation, and automatic hardware tuning.

The documents distinguish four kinds of statements:

- **UPSTREAM FACT**: stated by Qwen or directly visible in official model configuration.
- **AESIR FACT**: established by the current Aesir tree, tests, or filed evidence.
- **ENGINEERING RECOMMENDATION**: a proposed Aesir design or tuning policy that still needs measurement.
- **EXPERIMENT**: a concrete benchmark or implementation study that should be run before promoting a recommendation to a project claim.

That distinction matters. A model loading successfully is not proof that every quant, context length, accelerator path, or sampler configuration is optimal.

---

## The four-model family at a glance

| Model | Layers | Hidden | FFN | Q / KV heads | Head dim | Tied embeddings | Native context | Primary Aesir role |
|---|---:|---:|---:|---:|---:|---|---:|---|
| Qwen3-0.6B | 28 | 1024 | 3072 | 16 / 8 | 128 | Yes | 32,768 | ultra-light worker, router, drafter, control-plane model |
| Qwen3-1.7B | 28 | 2048 | 6144 | 16 / 8 | 128 | Yes | 32,768 | edge worker, agent worker, draft model, small assistant |
| Qwen3-4B | 36 | 2560 | 9728 | 32 / 8 | 128 | Yes | 32,768; YaRN extension documented to 131,072 | balanced main assistant |
| Qwen3-8B | 36 | 4096 | 12288 | 32 / 8 | 128 | No | 32,768; YaRN extension documented to 131,072 | quality-oriented local assistant |

All four are dense Qwen3 causal language models using grouped-query attention, SwiGLU, RoPE, RMSNorm, QK-Norm, and the Qwen3 tokenizer/chat family. Qwen3 also unifies thinking and non-thinking behavior in one post-trained model.

A subtle but important context note: Qwen's launch blog presents the 8B as a 128K-class model, while the current 4B/8B model cards describe **32,768 native context plus YaRN-validated extension to 131,072**. For engine design, this library uses the more precise native-versus-extended distinction.

---

## High-value conclusions for Aesir

### 1. Do not optimize all four sizes identically

The 0.6B can become dispatch- and launch-overhead-bound before arithmetic becomes the bottleneck. The 8B is far more likely to be weight-bandwidth-bound during batch-1 decode. Aesir should therefore select kernels, thread counts, accelerator placement, and batching separately for every size.

### 2. Quantization is a kernel problem as much as a file-size problem

Qwen's own H20 benchmarks show lower-precision models can be substantially faster in an optimized serving engine while the same precision can be slower in a generic Transformers path. Aesir should never assume that fewer bits automatically mean higher speed. A quant wins only if its decode and GEMM kernels exploit the representation efficiently.

### 3. KV memory becomes dominant surprisingly quickly

The four models all use 8 KV heads of dimension 128, but the 4B/8B have 36 layers instead of 28. Under Aesir's current dense f16 KV geometry:

- 0.6B / 1.7B: **114,688 bytes per cached token**.
- 4B / 8B: **147,456 bytes per cached token**.

At 32,768 tokens that is roughly **3.5 GiB** for 0.6B/1.7B and **4.5 GiB** for 4B/8B, independent of weight quantization. Aesir's tested int8-KV accounting reduces those figures to about **1.80 GiB** and **2.32 GiB**, respectively. Long context therefore requires attention to KV precision, paging, lazy allocation, and prefix reuse.

### 4. Tiny Qwen3 models are strategically valuable even when a larger model is available

A 0.6B or 1.7B instance can perform routing, classification, query rewriting, tool selection, formatting repair, cheap summarization, or speculative drafting while a 4B/8B model is reserved for tasks that need it. This creates an Aesir-native multi-model hierarchy rather than one model doing every job.

### 5. Thinking mode is a runtime policy, not just a prompt gimmick

Qwen3's thinking mode consumes extra output tokens and time. Aesir should expose a request-level policy so trivial jobs use non-thinking mode while reasoning-heavy jobs can opt in. For local agents this can save more wall time and energy than many low-level micro-optimizations.

### 6. 4B and 8B long context should be demand-activated

Qwen warns that static YaRN can reduce quality on shorter text. Aesir should keep native RoPE behavior for ordinary requests and enable the minimum required YaRN factor only when the requested context exceeds the native window.

### 7. Qwen3 is an unusually convenient speculative-decoding family

The four models share tokenizer/chat semantics and closely related architecture. Candidate pairs include `0.6B -> 1.7B`, `0.6B -> 4B`, `1.7B -> 4B`, `1.7B -> 8B`, and `4B -> 8B`. Acceptance rate, not parameter ratio, must decide which pairs are retained.

---

## Documents

1. [Source ledger and methodology](01_SOURCE_LEDGER_AND_METHODOLOGY.md)
2. [Shared Qwen3 architecture](02_QWEN3_SHARED_ARCHITECTURE.md)
3. [Qwen3-0.6B deep dive](03_QWEN3_0_6B_DEEP_DIVE.md)
4. [Qwen3-1.7B deep dive](04_QWEN3_1_7B_DEEP_DIVE.md)
5. [Qwen3-4B deep dive](05_QWEN3_4B_DEEP_DIVE.md)
6. [Qwen3-8B deep dive](06_QWEN3_8B_DEEP_DIVE.md)
7. [Quantization and weight-memory strategy](07_QUANTIZATION_AND_WEIGHT_MEMORY.md)
8. [KV cache, memory, paging, and long-context economics](08_KV_CACHE_AND_MEMORY.md)
9. [CPU optimization](09_CPU_OPTIMIZATION.md)
10. [CUDA/GPU optimization](10_CUDA_GPU_OPTIMIZATION.md)
11. [NPU, Hailo, and heterogeneous placement](11_NPU_HAILO_HETEROGENEOUS.md)
12. [Context, RoPE, and YaRN](12_CONTEXT_ROPE_YARN.md)
13. [Thinking, sampling, chat templates, and token discipline](13_THINKING_SAMPLING_CHAT.md)
14. [Tool calling, agents, and structured output](14_TOOL_CALLING_AND_AGENTS.md)
15. [Speculative decoding and multi-model swarms](15_SPECULATIVE_AND_SWARMS.md)
16. [Prefill, decode, batching, prefix cache, and scheduling](16_PREFILL_DECODE_BATCHING_CACHE.md)
17. [Benchmark and validation matrix](17_BENCHMARK_VALIDATION_MATRIX.md)
18. [Autotuning and deployment profiles](18_AUTOTUNING_DEPLOYMENT_PROFILES.md)
19. [Aesir implementation roadmap](19_AESIR_IMPLEMENTATION_ROADMAP.md)
20. [Optimization checklist and experiment backlog](20_OPTIMIZATION_CHECKLIST.md)

---

## Existing Aesir evidence this library builds on

The repository already contains important Qwen3 groundwork rather than starting from zero:

- Qwen3 architecture support and corrected split-half NeoX RoPE behavior.
- A Qwen3-0.6B verification script and a dense-GQA profile.
- Qwen3-4B / Zen wave evidence and oracle work.
- Fast K-quant paths across Q2_K through Q6_K and expanded IQ decoding support.
- A corrected IQ embedding path.
- A formal KV precision census and a tested int8-KV component/accounting model.
- Paged-KV structures, although the filed census says production sessions did not yet consume them at that point.
- Speculative-decoding design and verification infrastructure, with some integration paths deliberately failing closed until a real draft-model loop is present.

This library therefore focuses on the next layer: turning that foundation into model-specific policies and measurable performance work.

---

## Primary upstream sources

- Qwen3 launch and model table: https://qwenlm.github.io/blog/qwen3/
- Qwen3 technical report: https://arxiv.org/abs/2505.09388
- Official Qwen3 repository: https://github.com/QwenLM/Qwen3
- Qwen3 speed benchmark: https://github.com/QwenLM/Qwen3/blob/main/docs/source/getting_started/speed_benchmark.md
- Qwen3 function calling: https://github.com/QwenLM/Qwen3/blob/main/docs/source/framework/function_call.md
- Qwen3-0.6B: https://huggingface.co/Qwen/Qwen3-0.6B
- Qwen3-1.7B: https://huggingface.co/Qwen/Qwen3-1.7B
- Qwen3-4B: https://huggingface.co/Qwen/Qwen3-4B
- Qwen3-8B: https://huggingface.co/Qwen/Qwen3-8B

The remaining documents carry source-specific notes and Aesir implementation implications.