# F1 Completion Plan (H116) — CPU Pipeline to Production

**Date:** 2026-10-10
**Requires:** H111 = NO-GO (F1 fallback trunk).

## Gap analysis: C2/C3 → production-grade CPU engine

C2 (ARMVEGR kernels H021–H040) and C3 (F1 core H041–H060) deliver the
compute kernels and the core inference path. What is missing for a
production-grade CPU engine, and who owns each gap:

| # | Gap | Owning slice | Acceptance summary |
|---|---|---|---|
| 1 | End-to-end prefill + decode orchestration on CPU | H136 | Small open LLM: prompt in, tokens out, CPU-only, coherent |
| 2 | Static batching for throughput | H137 | Batched prefill/decode; measured tokens/s uplift |
| 3 | Multi-turn context management (KV-cache) | H137 + H168 | Context retained across turns; KV-cache memory optimized |
| 4 | Production config coherence (sampler, temps, rep-penalty) | H138 | Coherent text from a small open LLM, production settings |
| 5 | Honest backend selection (AUTO = CPU-only, no NPU phantom) | H139 | SKIPTI AUTO resolves to CPU always; no silent fallback |
| 6 | Health supervision (temp, hang, error registers) | H141–H146 | VÖRÐR monitors; faults detected, never silent |
| 7 | Crash-resistant recovery (reset, re-init, state machine) | H147–H149, H155–H158 | Recovery drills pass; supervised inference under fault injection |
| 8 | No-silent-fallback audit | H159 | Every degrade path is explicit and logged |
| 9 | NEON kernel tuning (tiling, packing, prefetch) | H164, H165 | Measured GFLOPS uplift vs H162 baseline |
| 10 | Quantized inference path (Q8) | H166 | Correctness + speedup measured |
| 11 | Memory-bandwidth optimization | H167 | Packing/alignment; bandwidth measured |
| 12 | Tokenizer throughput | H169 | Tokens/s, not a bottleneck vs decode |
| 13 | Multi-core dispatch on Pi 5 | H170 | Scaling measured across cores |
| 14 | Decode latency / prefill throughput optimization | H173, H174 | Latency budgets met |
| 15 | Performance + power/thermal budgets | H175, H177, H178 | Budgets documented, roofline for CPU path |
| 16 | 4-hour CPU soak + log analysis | H183, H185 | No drift/slowdown; RSS tracked (H189) |
| 17 | Crash-resistance fault-injection campaign | H186, H187, H197 | Faults injected, recovery proven |
| 18 | Determinism check (CPU-only) | H188 | Same input → same output, verified |
| 19 | ARM64 release packaging (no Python required) | H190 | Clean-room Pi install, runs standalone |
| 20 | Mimir deployment script + runbook | H191, H192 | One-command deploy; operator runbook |
| 21 | Victory gates on CPU path | H195, H196 | Any small open LLM → coherent output; soak proof |

**Zero gaps unowned.** Every production concern maps to a C7–C10 slice
that RUNs in the NO-GO branch.

## What F1 will NOT include

- No NPU execution, no HEF parsing/generation, no firmware interaction.
- No NPU performance claims (no "26 TOPS", no TOPS/W).
- No silent CPU fallback masquerading as acceleration: H139 and H159
  make every backend decision explicit.
- No partial-acceleration claims without measured microbenchmarks
  (F2 survey, H117, is the only place such claims may originate).

## Milestones

- **C7 review (H140):** pipeline complete, coherent CPU text proven.
- **C8 review (H160):** ROBUST — crash-resistant under fault injection.
- **C9 review (H180):** speed verdict on measured numbers.
- **H200:** MÍMISBRUNNR fallback verdict — F1 delivered.
