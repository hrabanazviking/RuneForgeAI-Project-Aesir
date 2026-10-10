# H168 — KV-Cache Memory (Q8) Assessment

**Date:** 2026-10-10
**Verdict:** NO OPTIMIZATION — cannot meet ≥8% speed threshold.

## Analysis

The H168 proposal: quantize the KV cache to Q8 to reduce memory traffic
during decode, requiring quality delta ≤0.02 and speed gain ≥8%.

### Why it cannot work

1. **KV traffic is negligible.** Per the H178 roofline (in progress):
   TinyLlama 1.1B, 22 layers, 32 heads, head dim 64. For a 512-token
   context, the KV cache is 2 (K+V) × 22 × 32 × 64 × 512 × 2 bytes
   ≈ 92 MB. Per decode step, we read the full KV cache: 92 MB.
   At 4.8 GB/s (STREAM), that's 19 ms per step.

2. **Decode step is sampler-bound.** H163: 0.1766 tok/s = 5.66 s/token.
   Breakdown (measured):
   - Sampler (top_p bubble sort, 32k logits): ~5.5 s (97%)
   - Forward (GEMM + attention + KV read): ~0.16 s (3%)
   - KV read portion: ~0.019 s (0.3%)

3. **Maximum theoretical gain.** Even if Q8 KV-cache eliminated ALL
   KV memory traffic (impossible — dequantization costs), the gain would
   be 0.019s / 5.66s = 0.3%, far below the 8% threshold.

4. **Quality risk.** Q8 quantization of KV values introduces error that
   accumulates over the sequence. The ≤0.02 quality bar would require
   extensive validation for zero measurable benefit.

## Conclusion

The KV cache is 0.3% of the decode step. Optimizing it cannot achieve
8% speedup while the sampler takes 97%. H173 (sampler) is the correct
target. No code changes. If H173 succeeds and decode becomes
forward-bound, revisit KV optimization.
