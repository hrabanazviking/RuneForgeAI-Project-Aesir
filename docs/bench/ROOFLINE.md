# H178 — Roofline Model: Pi 5 CPU Path (Mimir)

**Date:** 2026-10-10
**Slice:** H178

## Measured Peaks (Mimir, Pi 5, 4× Cortex-A76 @ 2.4 GHz)

| Metric | Measured | Method |
|--------|----------|--------|
| DRAM bandwidth (STREAM triad) | 4.816 GB/s | H162 `stream_triad` |
| FP16 GEMM (1024³) | 7.773 GFLOPS | H164 winner |
| FP16 GEMV (8192²) | 4.724 GB/s | H162 `gemv_fp16` |

## Roofline

```
GFLOPS
  ^
8 |                                          * H164 GEMM (7.77)
  |                                        ./
7 |                                      ./
  |                                    ./
6 |                                  ./
  |                                ./
5 |                              ./  <-- ridge point
  |                            ./
4 |                          ./
  |                        ./
3 |                      ./
  |                    ./
2 |                  ./
  |                ./
1 |              ./
  |            ./
0 +------------.----------------------------------> Arithmetic Intensity (FLOP/byte)
  0           1.6                                 100
              ^
              Ridge: 7.773 GFLOPS / 4.816 GB/s = 1.61 FLOP/byte
```

**Ridge point:** 1.61 FLOP/byte. Operations with AI < 1.61 are
memory-bound; AI > 1.61 are compute-bound.

## F1 Workload Placement

### Prefill (512 tokens)

| Op | FLOP | Bytes | AI (FLOP/B) | Bound |
|----|------|-------|-------------|-------|
| QKV GEMM (512×4096×4096 ×3) | 25.8 GF | 0.20 GB | 129 | Compute |
| Attn scores (512×512×64×32) | 1.07 GF | 0.13 GB | 8.2 | Compute |
| Out GEMM (512×4096×4096) | 8.6 GF | 0.07 GB | 123 | Compute |
| FFN (512×4096×11008 ×2) | 46.1 GF | 0.36 GB | 128 | Compute |

**Prefill is firmly compute-bound** (AI >> 1.61). The H164 GEMM
optimization (+51.9%) was the correct target.

### Decode (1 token)

| Op | FLOP | Bytes | AI (FLOP/B) | Bound |
|----|------|-------|-------------|-------|
| Forward (1×4096×4096 etc.) | 2.2 GF | 2.2 GB* | 1.0 | Memory |
| Sampler (32k logits) | 0.1 GF | 0.26 MB | 385 | Compute |

*Weights (2.2 GB for 1.1B Q4_0) stream from DRAM per token.

**Decode forward is memory-bound** (AI=1.0 < 1.61), but the **sampler
dominates** (85% of time, H175). The H173 sampler fix (+986%) was the
correct target; GEMM optimization helps forward (+12%) but forward is
only 15% of decode.

### KV Cache (H168)

Per decode step: 92 MB KV read. At 4.816 GB/s = 19 ms.
Decode step: 521 ms. KV = 3.6% of forward, 0.5% of total step.
**Not a bottleneck** (confirmed H168 negative).

## Conclusions

1. **Prefill:** Compute-bound → GEMM optimization correct (H164+H174).
2. **Decode:** Sampler-bound → sampler optimization correct (H173).
3. **Memory:** 98% efficiency already (H167); not a bottleneck.
4. **Threading:** Would move the compute ceiling 4× (H170 deferred).
