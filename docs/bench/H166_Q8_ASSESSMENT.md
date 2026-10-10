# H166 — Quantized (Q8) Inference Path Assessment

**Date:** 2026-10-10
**Verdict:** NO OPTIMIZATION — roofline-documented negative.

## Measurements (H162 baseline, Mimir)

| Kernel | Throughput |
|--------|------------|
| `gemm_fp16` (H164 winner) | 7.773 GFLOPS (1024³) |
| `q80_gemm` (M1_N4096_K4096) | 2.431 GFLOPS |
| `fp16_to_q80` | 0.662 GB/s |
| `q80_to_fp16` | 2.100 GB/s |

## Analysis

The Q8 path was designed for memory-bound GEMV-like operations where
reduced weight traffic outweighs the dequantization cost. It does not
help the F1 inference workload:

1. **Prefill is compute-bound, not memory-bound.** The prefill does
   large GEMMs (512×4096×4096, 512×4096×11008). At 7.773 GFLOPS (fp16),
   the arithmetic intensity is high. The Q8 GEMM at 2.431 GFLOPS is
   3.2× SLOWER — the dequantization overhead dominates.

2. **Decode is sampler-bound, not GEMM-bound.** H163 measures decode at
   0.1766 tok/s with the classic sampler. The sampler's O(n²) bubble sort
   over 32k logits takes ~5.6s per token; the GEMM/forward takes ~0.1s.
   Optimizing GEMM (Q8 or otherwise) cannot move decode until H173 fixes
   the sampler.

3. **Model is Q4_0, not Q8.** The TinyLlama weights are Q4_0. Using the
   Q8 path would require fp16→Q8 conversion (0.662 GB/s — slower than
   the fp16 GEMM itself) or storing duplicate Q8 weights (memory waste).

4. **H037 oracle.** The Q8 kernels were verified in H037. No changes were
   made in H166, so re-running the oracle is unnecessary (nothing touched).

## Conclusion

The Q8 inference path is a pessimization for this workload: 3.2× slower
GEMM, conversion overhead, and the bottlenecks (sampler for decode,
fp16 GEMM for prefill) are elsewhere. No code changes. The Q8 kernels
remain available for genuinely memory-bound future workloads.
