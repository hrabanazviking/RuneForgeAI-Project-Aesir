# A-043 — CPU fused attention (flash_attention_gqa)

Roadmap: "Current fused attention measured; SIMD/layout gaps
fixed. Acceptance: before/after timings + reference parity."
Census basis: A-037 row C-002 — `flash_attention_gqa` at 17.93%
of decode self-time (843 samples, perf --no-children), the
second-hottest symbol in the engine.

## The gaps, as found at base d8c57f2a (A-042 banked)

`flash_attention_gqa` (aesir_engine/core/compute.mojo) was
fully scalar, unlike its sibling `flash_attention_2`, which
already ran width-16 SIMD with scalar tails:

1. The QK^T dot product was a per-element scalar loop, and it
   re-loaded and re-cast the query row from F16 for **every**
   key position (seq_len × head_dim redundant loads/casts of
   the same 1-row query).
2. The P·V accumulate was a per-element scalar loop through a
   heap accumulator (load/op/store per element per position).
3. The accumulator zeroing and the final normalization were
   per-element scalar loops.
4. The online-softmax rescale `exp(running_max - next_max)` was
   evaluated on every position, although it is exactly 1.0
   whenever the running max did not move (most positions in a
   long decode window).

## The fix (compute.mojo, flash_attention_gqa only)

- The query head is preloaded **once** into an F32 scratch row
  (`qbuf`, allocated once per call alongside the existing `acc`).
- QK^T dot, P·V accumulate, accumulator zeroing, and the final
  normalization now run width-16 SIMD (`simd_w_f32`) with
  scalar tails, the flash_attention_2 pattern in the same file.
- The rescale exp() is skipped when the max did not move
  (bit-exact: exp(0) == 1).
- Signature, validation, defaults, and the online-softmax
  recurrence are unchanged. The only numerics change is the
  QK^T reduction order (per-chunk `reduce_add`); the P·V and
  normalization steps are per-element operations with no
  cross-lane reduction.

## Before / after timings

Bench: aesir_engine/tests/bench_fused_attention_a043.mojo
(standalone, not in run_all). It times the production function
and an in-file verbatim copy of the pre-A-043 scalar body on
fixed-seed LCG fixtures (seed 0xA043), CLOCK_MONOTONIC around
the calls only, median of 7 reps after warmup, single-threaded.
ns per call (query = 1 row, the decode shape):

| Shape | Before (base prod) | After (A-043 prod) | Speedup |
|---|---|---|---|
| seq 128, hd 64, q8:kv2 | 79,833 | 12,728 | 6.27× |
| seq 512, hd 64, q8:kv2 | 318,992 | 50,595 | 6.30× |
| seq 1024, hd 64, q8:kv2 | 639,123 | 101,257 | 6.31× |
| seq 512, hd 128, q32:kv8 | 2,439,189 | 385,737 | 6.32× |
| seq 256, hd 40, q6:kv3 | 82,409 | 26,959 | 3.06× |
| seq 512, hd 64, q8:kv8 | 325,245 | 52,310 | 6.22× |

The in-run scalar legs agree with the base production leg to
~0.1% in both runs, so the comparison is internally controlled.
The hd40 shape gains least: 24 of its 40 lanes run through the
scalar tail (simd_end = 32). Logs: hidden_files/
a043_bench_before.log, a043_bench_after.log.

## Reference parity

Bench parity (production vs the verbatim scalar body, same
buffers): before the fix, bitwise on every element (proving
the in-file reference is the same math). After the fix:
511/512, 511/512, 511/512, 4091/4096, 240/240, 511/512
bitwise-equal, max abs diff ≤ 1.53e-05 (≤ 1 F16 ULP at these
magnitudes) — the accepted fast-path summation-order class
(A-038/A-042 precedent).

Suite parity (aesir_engine/tests/test_fused_attention_a043
.mojo, 5 cases, pin 403 → 408): general-data bound
max_abs ≤ 0.01; a dyadic fixture (all products and partial
sums exact in F32 under any reduction order) must agree
**bitwise**; unaligned head_dim 40/24 tails; attn_scale +
softcap + sliding-window modifiers; a seq-300 hd-128 shape.

End-to-end raw-oracle parity: the A-034 replay battery
(hidden_files/run_a034.sh) rebuilt against the A-043 kernel
reproduces the pinned A-004 raw-prompt oracle **token-exactly**
— GREEDY FNV-1a 7bb54597001a24e0, and the seeded streams are
also unchanged (SEEDED cd2bc2d155dd6f3e, ALTSEED
c55ae7749fd98274). The only run-to-run file differences are
the A-036 AESIR_TIMING_JSON wall-clock lines (verified: 8
differing lines, all timing JSON, 0 others).
