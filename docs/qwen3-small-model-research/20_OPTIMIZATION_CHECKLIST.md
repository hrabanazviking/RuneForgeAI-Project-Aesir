# 20 - Qwen3 Small-Model Optimization Checklist and Experiment Backlog

**Research snapshot:** 2026-11-02

This is the operational checklist for turning the rest of the research library into measured Aesir work. Checkboxes should only be marked complete when corresponding evidence is filed.

---

# A. Model admission and correctness

- [ ] Qwen3-0.6B canonical profile verified against official config.
- [ ] Qwen3-1.7B canonical profile verified.
- [ ] Qwen3-4B canonical profile verified.
- [ ] Qwen3-8B canonical profile verified.
- [ ] Tied embedding path verified for 0.6B/1.7B/4B.
- [ ] Untied embedding/LM-head path verified for 8B.
- [ ] QK-Norm known-value test.
- [ ] Split-half Qwen3 RoPE known-value test.
- [ ] RoPE high-position test.
- [ ] GQA 16/8 mapping test.
- [ ] GQA 32/8 mapping test.
- [ ] SwiGLU reference test.
- [ ] Exact first-token logit oracle for all four sizes.
- [ ] Teacher-forced trajectory for all four.
- [ ] Raw-token greedy trajectory for all four.

---

# B. Tokenizer and chat

- [ ] Reference tokenizer revision pinned.
- [ ] User-only chat token fixture.
- [ ] System+user fixture.
- [ ] Multi-turn fixture.
- [ ] Thinking fixture.
- [ ] Non-thinking fixture.
- [ ] `/think` fixture.
- [ ] `/no_think` fixture.
- [ ] No accidental conventional BOS insertion.
- [ ] Tool schema fixture.
- [ ] Tool call fixture.
- [ ] Tool-result continuation fixture.

---

# C. Quantization

For every model size:

- [ ] Q8_0 correctness.
- [ ] Q6_K correctness.
- [ ] Q5_K_M correctness.
- [ ] Q4_K_M correctness.
- [ ] Q3_K_M correctness.
- [ ] Q2_K correctness.
- [ ] Selected IQ1/IQ2/IQ3 correctness.
- [ ] Embedding lookup tested for each supported quant family.
- [ ] Unknown quant fails closed.
- [ ] Quality suite run for default-candidate quants.
- [ ] Exact file SHA recorded.

Optimization:

- [ ] Fused Q4 decode kernel.
- [ ] Fused Q5 decode kernel.
- [ ] Tuned Q6 decode kernel.
- [ ] Tuned Q8 decode kernel.
- [ ] K-quant prefill GEMM path.
- [ ] IQ fast paths only where quality/perf justify them.
- [ ] Mixed-precision tensor experiment.
- [ ] Output-head higher-precision experiment for 8B.

---

# D. CPU

- [ ] Separate prefill/decode dispatch.
- [ ] Thread-count sweep 0.6B.
- [ ] Thread-count sweep 1.7B.
- [ ] Thread-count sweep 4B.
- [ ] Thread-count sweep 8B.
- [ ] Phase-specific thread plan tested.
- [ ] CPU affinity benchmark.
- [ ] NUMA policy benchmark on multi-node host.
- [ ] AVX2 path verified.
- [ ] AVX-512 path where available.
- [ ] VNNI/dot-product path where available.
- [ ] No hot-loop heap allocation.
- [ ] Scratch arenas persistent.
- [ ] Software-prefetch distance sweep.
- [ ] Huge-page experiment.
- [ ] Effective memory bandwidth reported with decode speed.
- [ ] Top-k sampler avoids unnecessary full sort.

---

# E. GPU / CUDA

- [ ] Full-residency plan for each model/quant.
- [ ] Q4 fused GPU matmul.
- [ ] Q5 fused GPU matmul.
- [ ] Tensor-core prefill path.
- [ ] Dedicated decode path.
- [ ] QK-Norm + RoPE fusion experiment.
- [ ] RMSNorm/residual fusion experiment.
- [ ] Tiled/flash-style prefill attention.
- [ ] Single-query GQA decode attention.
- [ ] CUDA Graph decode experiment.
- [ ] Device-side sampler experiment.
- [ ] Continuous-batch kernel path.
- [ ] No repeated CPU/GPU per-layer ping-pong.
- [ ] GPU memory planner.
- [ ] Unified-memory contention tests.

---

# F. KV cache

- [ ] f16 reference cache for all four geometries.
- [ ] int8-KV component integrated into full Qwen3 session.
- [ ] int8 append test.
- [ ] int8 attention-read test.
- [ ] int8 reset test.
- [ ] int8 rollback test.
- [ ] int8 measured bytes match accounting.
- [ ] 2K quality comparison.
- [ ] 8K quality comparison.
- [ ] 16K quality comparison.
- [ ] 32K quality comparison.
- [ ] Production paged KV.
- [ ] Lazy page allocation.
- [ ] Paged/contiguous logit equivalence.
- [ ] Prefix-page sharing.
- [ ] Page refcount/release tests.
- [ ] Memory admission control.
- [ ] Cache telemetry.

---

# G. Context and YaRN

- [ ] 32K physical acceptance 0.6B.
- [ ] 32K physical acceptance 1.7B.
- [ ] 32K physical acceptance 4B.
- [ ] 32K physical acceptance 8B.
- [ ] YaRN implementation for 4B/8B.
- [ ] YaRN factor 2 reference test.
- [ ] YaRN factor 4 reference test.
- [ ] Dynamic activation rather than always-on YaRN.
- [ ] 64K physical 4B acceptance.
- [ ] 64K physical 8B acceptance.
- [ ] 128K physical 4B acceptance.
- [ ] 128K physical 8B acceptance.
- [ ] Short-context regression under YaRN factors.
- [ ] Needle retrieval suite.
- [ ] Multi-needle suite.
- [ ] Long code/document QA.

---

# H. Thinking and sampling

- [ ] Official thinking sampler preset.
- [ ] Official non-thinking sampler preset.
- [ ] Thinking output separated from final output.
- [ ] Historical thinking omitted from next-turn context by default.
- [ ] Reasoning token accounting.
- [ ] Reasoning budget control.
- [ ] `auto` reasoning policy experiment.
- [ ] Repetition detector.
- [ ] Adaptive presence-penalty experiment.
- [ ] Language-mixing regression test.
- [ ] Structured/JSON sampler preset.

---

# I. Agents and tools

- [ ] Structural Qwen3 tool parser.
- [ ] No stopword/ReAct action trigger.
- [ ] JSON/schema validation.
- [ ] Invalid-call repair loop.
- [ ] Retry cap.
- [ ] Tool-set filtering/router.
- [ ] Tool-schema prefix cache.
- [ ] Tool-result compression path.
- [ ] Single-tool exact suite.
- [ ] Multi-tool selection suite.
- [ ] Multi-step tool suite.
- [ ] Tool error recovery suite.
- [ ] Thought-text false-trigger test.
- [ ] 0.6B agent success rate.
- [ ] 1.7B agent success rate.
- [ ] 4B agent success rate.
- [ ] 8B agent success rate.

---

# J. Speculative decoding

- [ ] Real drafter model session interface.
- [ ] Exact shared-tokenizer verification.
- [ ] Greedy draft loop.
- [ ] Batched target verification.
- [ ] Drafter KV checkpoint/rollback.
- [ ] Target KV checkpoint/rollback.
- [ ] Sampler checkpoint/rollback.
- [ ] Adaptive `k`.
- [ ] Automatic lose detection.
- [ ] Sampled reconciliation.
- [ ] 0.6B -> 1.7B benchmark.
- [ ] 0.6B -> 4B benchmark.
- [ ] 0.6B -> 8B benchmark.
- [ ] 1.7B -> 4B benchmark.
- [ ] 1.7B -> 8B benchmark.
- [ ] 4B -> 8B benchmark.
- [ ] Drafter quant sweep.
- [ ] Thinking/non-thinking acceptance comparison.
- [ ] CPU/NPU drafter + GPU target comparison.

---

# K. Scheduling and caching

- [ ] Explicit PREFILL phase.
- [ ] Explicit DECODE phase.
- [ ] Explicit DRAFT_CHECK phase.
- [ ] Chunked prefill.
- [ ] Continuous batching.
- [ ] Interactive versus throughput modes.
- [ ] Exact token-prefix cache.
- [ ] Prefix cache hit telemetry.
- [ ] Prefix cache eviction policy.
- [ ] Shared immutable KV prefix pages.
- [ ] Long-prefill fairness/interleaving.
- [ ] Request priority classes.
- [ ] Model residency scheduler.
- [ ] Queue-time telemetry.

---

# L. NPU / Hailo

- [ ] Preserve verified compiled-route evidence.
- [ ] Resume native compiler road only under explicit project direction.
- [ ] Qwen3 QK-Norm lowering.
- [ ] Qwen3 RoPE lowering.
- [ ] Qwen3-0.6B one-block parity.
- [ ] Qwen3-0.6B full-model parity.
- [ ] Qwen3-0.6B generation proof.
- [ ] Qwen3-1.7B admission.
- [ ] Qwen3-1.7B generation proof.
- [ ] End-to-end transfer costs included.
- [ ] Energy/token measured.
- [ ] NPU drafter experiment.

---

# M. Autotuning

- [ ] Hardware fingerprint.
- [ ] Model/quant SHA key.
- [ ] CPU thread autotune.
- [ ] CPU kernel autotune.
- [ ] GPU kernel autotune.
- [ ] Prefill chunk autotune.
- [ ] Attention tile autotune.
- [ ] KV page-size experiment.
- [ ] Speculative pair/k autotune.
- [ ] Context-band profiles.
- [ ] Fast-tune mode.
- [ ] Deep-tune mode.
- [ ] Profile invalidation on runtime/hardware change.
- [ ] Human-readable tuning report.

---

# N. Benchmark evidence

For every published performance claim:

- [ ] Model SHA.
- [ ] Aesir SHA.
- [ ] Hardware.
- [ ] Driver/runtime.
- [ ] Exact token prompt or fixture.
- [ ] Template mode.
- [ ] Sampler.
- [ ] Context.
- [ ] Quant.
- [ ] Thread/device placement.
- [ ] Warm/cold state.
- [ ] TTFT.
- [ ] Prefill tok/s.
- [ ] Decode tok/s.
- [ ] Memory.
- [ ] Repeated-run statistics.
- [ ] Quality/correctness verdict.

---

# O. High-value experiment backlog

## Memory

1. 8B Q4 weights + 32K f16 KV versus Q5 + int8 KV: which gives higher quality inside the same memory budget?
2. 4B Q5 + int8 KV versus 8B Q3 + int8 KV at equal total memory.
3. Recent-page f16 + old-page int8 mixed KV.

## Speed

4. 0.6B CPU versus GPU at batch 1 to locate the launch-overhead crossover.
5. 0.6B GPU at batch 1/4/8/16.
6. 1.7B phase-specific CPU thread count.
7. 8B Q4/Q5/Q6 achieved-memory-bandwidth roofline.

## Quality

8. Quant sensitivity of tied embedding/LM head.
9. 8B output-head higher precision than bulk layers.
10. Tool-call exactness by quant.
11. Thinking-mode repetition by quant.

## Context

12. 4B native 32K versus YaRN factor 2 at short prompts.
13. 8B factor 2 versus factor 4 at 64K.
14. 128K cache memory with paging measured physically.

## Agents

15. 0.6B router + 4B main versus always-4B.
16. 1.7B worker + 8B judge versus always-8B.
17. Dynamic tool-schema filtering effect on TTFT/KV.

## Speculation

18. 0.6B Q5 -> 4B Q4.
19. 1.7B Q4 -> 8B Q4.
20. 4B Q4 -> 8B Q5.
21. Same-GPU versus CPU/GPU heterogeneous drafter.
22. Speculation acceptance in thinking versus non-thinking mode.

## Accelerator

23. Qwen3-0.6B native Hailo block proof when roadmap resumes.
24. Qwen3-1.7B NPU worker energy benchmark.

---

# P. Definition of 'best'

For this research program, 'best' means:

> The fastest and most memory-efficient configuration that still satisfies the required correctness and quality for the actual workload on the actual hardware.

It does **not** mean the lowest bit count, highest isolated kernel FLOPS, maximum context number, or largest parameter count.

That definition should keep the Aesir forge aimed at useful speed instead of benchmark glitter.