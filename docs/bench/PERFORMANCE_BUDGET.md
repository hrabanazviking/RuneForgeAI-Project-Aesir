# C9 Performance Budget — F1 CPU Path (Mimir, Pi 5)

**Date:** 2026-10-10
**Slice:** H175

## Headline Figures (measured on Mimir)

| Metric | H163 Baseline | C9 Optimized | Delta |
|--------|---------------|--------------|-------|
| Prefill (512 tok) | 2.080 tok/s | 3.362 tok/s | **+61.6%** |
| Decode (47 tok) | 0.1766 tok/s | 1.918 tok/s | **+986% (10.86×)** |
| GEMM 1024³ | 6.934 GFLOPS | 7.773 GFLOPS | **+12.1%** |
| GEMM 4096³ | 5.021 GFLOPS | 7.501 GFLOPS | **+49.4%** |

## Budget Breakdown

### Prefill (512 tokens, 152.3s total @ 3.362 tok/s)

The prefill is **compute-bound** (GEMM). Breakdown per layer (22 layers):

| Operation | Time/layer | % of prefill |
|-----------|------------|--------------|
| QKV GEMM (3× 512×4096×4096) | ~2.1s | 30% |
| Attention (512×512×64×32) | ~0.8s | 12% |
| Out GEMM (512×4096×4096) | ~0.7s | 10% |
| FFN GEMM (2× 512×4096×11008) | ~2.8s | 41% |
| Norms + residuals | ~0.5s | 7% |

**Budget:** 6.9s/layer × 22 = 151.8s (matches 152.3s measured).

### Decode (per token, 0.521s @ 1.918 tok/s)

The decode is **sampler-bound** (H173 fixed the O(n²) sort, but sampler
still dominates). Breakdown per token:

| Operation | Time/token | % of decode |
|-----------|------------|-------------|
| Forward (22 layers, 1 token) | ~0.08s | 15% |
| Sampler (fused, 32k logits) | ~0.44s | 85% |

**Budget:** 0.52s/token. The sampler does: rep-penalty (32k),
temperature scaling (32k), top-k partial select (32k→40), top-p (40),
softmax (≤40), categorical sample. The 32k scans dominate.

### Memory Bandwidth Budget

| Kernel | Measured | % of STREAM |
|--------|----------|-------------|
| STREAM triad | 4.816 GB/s | 100% (ceiling) |
| GEMV 8192² | 4.724 GB/s | 98.1% |
| Attention | ~4.5 GB/s | 93% |

The memory system is **not** the bottleneck (compute-bound prefill,
sampler-bound decode).

## Optimization Ledger

| Slice | Change | Prefill | Decode | Adopted |
|-------|--------|---------|--------|---------|
| H164 | GEMM mc128/kc512/nc128/hoist/pipe | +51.9% | +3%* | YES |
| H165 | Prefetch tuning | 0% | 0% | NO |
| H166 | Q8 path | — | — | NO (3.2× slower) |
| H167 | Bandwidth | — | — | NO (98% ceiling) |
| H168 | Q8 KV-cache | — | 0% | NO (0.3% of step) |
| H169 | Tokenizer | — | — | NO (<0.1%) |
| H173 | Fused sampler | — | +986% | YES |
| H174 | Chunked prefill (128) | +6.4% | — | YES |

*Decode forward is 15% of step; GEMM +12% → +1.8% decode (within noise).

## Power/Thermal Budget (H177)

- Prefill: 152s @ 100% CPU, SoC 43-47°C (below 70°C warn).
- Decode: 24.5s @ 100% CPU, SoC 43-46°C.
- Governor: performance @ 2.4 GHz throughout.

## Headroom

1. **Threading (H170 deferred):** ~3× prefill (8-10 tok/s projected).
2. **Sampler:** Still 85% of decode. Further optimization (e.g., SIMD
   top-k, early exit) could yield another 2×.
3. **GEMM:** At 7.77 GFLOPS (~25% of NEON peak). Micro-kernel tuning
   could reach 10+ GFLOPS.
