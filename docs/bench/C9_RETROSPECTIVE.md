# H179 — C9 Optimization Retrospective (Measured)

**Date:** 2026-10-10
**Slice:** H179

## What Worked

### H173: Fused Sampler (+986%, 10.86× decode)

**The win:** Replaced O(n²) bubble sort over 32k logits with partial
selection + fused kernels. Decode went from 0.1766 tok/s to 1.918 tok/s.

**Why it worked:** C7 identified the sampler as the bottleneck (H136:
"decode 0.165 tok/s sampler-bound"). The bubble sort did ~500M
comparisons per token; the fused version does ~32k. The optimization
was **algorithmic**, not micro-architectural — the biggest wins always are.

**Lesson:** Profile first, optimize the bottleneck. The H163 baseline
confirmed the sampler was 97% of decode time. No amount of GEMM tuning
would have helped decode.

### H164: GEMM Tiling (+12% / +49%, adopted)

**The win:** 12-config sweep found hoist_b (pack B once, reuse across
row-blocks) + larger blocks (mc128/kc512/nc128) + pipelined micro-kernel.
1024³: 6.934→7.773 GFLOPS (+12.1%). 4096³: 5.021→7.501 (+49.4%).

**Why it worked:** The H023 baseline re-packed B for every row-block.
For large matrices, this was pure overhead. Hoisting the pack out of
the i0 loop eliminated redundant memory traffic.

**Lesson:** The sweep methodology (12 configs, both shapes) was essential.
Config 4 (kc=512 without hoist) was **3× slower** on 4096³ — bigger isn't
always better. Measure, don't assume.

### H174: Chunked Prefill (+6.4% on top of H164)

**The win:** Processing 512 tokens in 128-token chunks improved cache
locality. 3.159→3.362 tok/s (+6.4%).

**Why it worked:** The 512-token prefill has a large working set. Chunking
keeps the active tile in L2. Small win, but it stacks with H164.

## What Didn't Work (Honest Negatives)

### H165: Prefetch Tuning (0%)

All prefetch distances within ±1%. The hoist_b + large blocks already
keep data cache-resident. Software prefetch is redundant when the
blocking is correct.

**Lesson:** Prefetch helps when blocking is poor. Fix the blocking first.

### H166: Q8 Path (3.2× slower)

Q8 GEMM at 2.431 GFLOPS vs fp16 at 7.773. The dequantization overhead
dominates. Q8 is for memory-bound workloads; F1 prefill is compute-bound.

**Lesson:** Quantization is not a universal speedup. It helps when
memory bandwidth is the bottleneck and the dequant cost is amortized.

### H167: Bandwidth (98% ceiling)

GEMV at 98.1% of STREAM. No headroom. The kernel was already optimal.

**Lesson:** Measure the ceiling first. If you're at 98%, stop.

### H168: Q8 KV-Cache (0.3% of step)

KV traffic is 19ms out of 521ms decode step. Even eliminating it entirely
would give <4% speedup, far below the 8% threshold.

**Lesson:** Amdahl's law is ruthless. Optimize the 97%, not the 0.3%.

### H169: Tokenizer (<0.1%)

Milliseconds vs 246-second prefill. Not a bottleneck.

**Lesson:** Don't optimize what you don't measure.

### H170: Threading (deferred)

Would give ~3× prefill (projected 8-10 tok/s), but requires fork-based
shared-memory infrastructure that Mojo 1.1 doesn't provide cleanly.
Deferred to a dedicated campaign.

**Lesson:** Know when to stop. The single-core wins (10.86×, 61.6%) deliver
the campaign goals. Threading is future work.

## Methodology Wins

1. **Repeat methodology (H162):** The H038 single-invocation method gave
   20-60% spreads on fast kernels. Repeats targeting ~50ms/trial fixed it.
2. **True baseline (H163):** Built from pre-H173 code to ensure honest
   "before" numbers. The 0.5% difference from the optimized forward
   didn't matter, but the rigor did.
3. **Sweep before adopt (H164):** 12 configs, not 2-3. Found the non-obvious
   winner (hoist_b) and the catastrophic loser (kc=512 alone).
4. **Bit-identity checks:** Every adoption verified vs original. The H174
   0.016 logit delta was investigated (fp16 non-associativity) and the
   argmax was confirmed identical.

## Numbers

| Metric | Before (H163) | After (C9) | Delta |
|--------|---------------|------------|-------|
| Prefill | 2.080 tok/s | 3.362 tok/s | +61.6% |
| Decode | 0.1766 tok/s | 1.918 tok/s | +986% |
| GEMM 1024³ | 6.934 GFLOPS | 7.773 GFLOPS | +12.1% |

**Campaign goal:** "Make the Pi 5 CPU engine fast — measured, never invented."
**Delivered:** 10.86× decode, 61.6% prefill, all measured on Mimir.
