# H167 — Memory Bandwidth (Packing, Alignment) Assessment

**Date:** 2026-10-10
**Verdict:** NO OPTIMIZATION — at efficiency ceiling.

## Measurement (H162 baseline, Mimir)

| Kernel | Throughput |
|--------|------------|
| `stream_triad` (DRAM ceiling) | 4.816 GB/s |
| `gemv_fp16` (8192×8192) | 4.724 GB/s |
| **Efficiency** | **98.1%** |

## Analysis

The GEMV kernel achieves 98.1% of the measured STREAM triad bandwidth.
This is the practical ceiling for a memory-bound kernel on this system:

1. **Alignment:** `unsafe_alloc` returns 16-byte aligned memory; the
   GEMV inner loop processes 8 fp16 elements (16 bytes) per iteration,
   naturally aligned. Forcing 64-byte alignment cannot exceed the DRAM
   controller's 98%-of-STREAM limit.

2. **Packing:** The GEMM packing (pack_a/pack_b) was already optimized
   in H164 (hoist_b). The GEMV does not pack (it's a single matrix-vector
   product; packing would add overhead).

3. **20-site alignment test:** Not run — with 98.1% efficiency, the
   maximum theoretical gain is <2%, below the measurement noise floor
   (±1-2% on memory-bound kernels per H162 spreads).

## Conclusion

Memory bandwidth is not the bottleneck for F1 inference (prefill is
compute-bound GEMM, decode is sampler-bound). The GEMV is already at
the practical ceiling. No code changes.
