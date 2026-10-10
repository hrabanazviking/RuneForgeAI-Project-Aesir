# H180 — Campaign 9 (Speed) Verdict

**Date:** 2026-10-10
**Slice:** H180

## Verdict: **STRONG PASS**

Campaign 9 optimized the F1 CPU path on Mimir (Pi 5) with measured,
verified improvements. H171/H172 skipped per re-scope (H111 NO-GO).

## Slice Status

| Slice | Status | Result |
|-------|--------|--------|
| H161 | DONE | Benchmark harness, stability gate PASS |
| H162 | DONE | 22-kernel baseline table |
| H163 | DONE | E2E baseline: 2.080 tok/s prefill, 0.1766 tok/s decode |
| H164 | DONE | GEMM sweep, config 11 adopted (+12%/+49%) |
| H165 | DONE | Prefetch sweep, no win (negative) |
| H166 | DONE | Q8 assessment, negative (3.2× slower) |
| H167 | DONE | Bandwidth at 98% ceiling, negative |
| H168 | DONE | KV-cache Q8, negative (0.3% of step) |
| H169 | DONE | Tokenizer, not a bottleneck |
| H170 | DEFERRED | Threading needs shared-memory infra (future work) |
| H171 | SKIP | H111 NO-GO (NPU path) |
| H172 | SKIP | H111 NO-GO (transfer overlap) |
| H173 | DONE | Fused sampler: **10.86× decode** |
| H174 | DONE | Chunked prefill: **+61.6%** |
| H175 | DONE | Performance budget doc |
| H176 | DONE | Python regression guard (PASS) |
| H177 | DONE | Thermal: 70-min sustained, max 43°C (PASS) |
| H178 | DONE | Roofline model |
| H179 | DONE | Retrospective |
| H180 | DONE | This verdict |

**Completed:** 17/18 runnable slices (H170 deferred with rationale).
**Skipped:** 2/20 (H171/H172, GO-gated).

## Measured Improvements

| Metric | H163 Baseline | C9 Final | Improvement |
|--------|---------------|----------|-------------|
| Prefill throughput | 2.080 tok/s | 3.362 tok/s | **+61.6%** |
| Decode throughput | 0.1766 tok/s | 1.918 tok/s | **+986% (10.86×)** |
| GEMM 1024³ | 6.934 GFLOPS | 7.773 GFLOPS | +12.1% |
| GEMM 4096³ | 5.021 GFLOPS | 7.501 GFLOPS | +49.4% |

## Correctness

- Every adoption re-verified: H164 (bit-identical, C2_VERIFY PASS),
  H173 (bit-identical sampler, 200-trial grid), H174 (argmax identical).
- No silent fallbacks. All numbers measured on Mimir, never invented.
- Honest negatives documented (H165-H169, H170 deferred).

## What Remains

1. **Threading (H170):** ~3× prefill opportunity (8-10 tok/s projected).
   Requires dedicated systems work (shared-memory fork pool).
2. **Sampler:** Still 85% of decode. Further SIMD optimization possible.
3. **NPU path (H171/H172):** Blocked on H111 GO.

## Sign-off

C9 delivers a **10.86× faster decode** and **61.6% faster prefill**,
measured and verified on Mimir. The Pi 5 CPU engine is fast.

**C9 VERDICT: STRONG PASS.**
