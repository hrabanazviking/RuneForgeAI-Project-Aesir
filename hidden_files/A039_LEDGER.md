# A-039 Ledger — Wide-SIMD IQ dequant (team-07)

Base: seat main d98da7fb (33 of 216 banked) reset --hard at slice start;
CAMPAIGN_STATE.md + hidden_files preserved across the reset.
Branch: yrsa/aesir-team-07. No merge/push (keeper banks in order).

## IQ inventory (engine, at base d98da7fb)

All IQ dequant lives in aesir_engine/core/extreme_quantization.mojo,
dispatched from aesir_engine/core/compute.mojo. Formats PRESENT
(9 dequantize_*_blocks entry points, all scalar per-element loops
at base):

| Format | GGML kind | Bytes/256 | Scalar entry point |
|---|---|---|---|
| IQ1_S | 19 | 50 | dequantize_iq1_s_blocks |
| IQ1_M | 29 | 56 | dequantize_iq1_m_blocks |
| IQ2_XXS | 16 | 66 | dequantize_iq2_xxs_blocks |
| IQ2_XS | 17 | 74 | dequantize_iq2_xs_blocks |
| IQ2_S | 22 | 82 | dequantize_iq2_s_blocks |
| IQ3_XXS | 18 | 98 | dequantize_iq3_xxs_blocks |
| IQ3_S | 21 | 110 | dequantize_iq3_s_blocks |
| IQ4_NL | 20 | 18 per 32 (144/256) | dequantize_iq4_nl_blocks |
| IQ4_XS | 23 | 136 | dequantize_iq4_xs_blocks |

No other IQ variants exist in the engine (grep IQ1/IQ2/IQ3/IQ4 over
aesir_engine/): no IQ2_M / IQ3_M / IQ1 variants beyond the nine
above; nothing was invented. TQ1_0/TQ2_0 are ternary, not IQ, and
are out of scope.

Already SIMD at base (not re-done): dequantize_iq_block, the S-030
width-16 block decoder used by the GEMV/GEMM fast paths in
core/compute.mojo, covering all 9 kinds bit-identically vs scalar.

## What A-039 changed

The nine bulk dequantize_*_blocks functions (the
CompressedFormatType dispatch targets in core/compute.mojo, i.e.
the tensor-materialization path) each looped over every element
calling a scalar *_value_g decoder (div/mod index math, branches,
per-element grid loads). They now decode each 256-value super-block
through the existing S-030 SIMD core dequantize_iq_block into an
f32 scratch block and store it as f16 via the new width-16 helper
_iq_store_block_f16 (16-wide load/cast/store). IQ4_NL keeps its
32-value-block API: complete 256-value super-blocks take the SIMD
path; a trailing partial group of 32-blocks keeps the scalar
per-element decode (documented in code). Scalar *_value_g decoders
remain untouched as the parity reference. Signatures, validation,
and error strings unchanged.

Files: aesir_engine/core/extreme_quantization.mojo,
aesir_engine/tests/test_iq_simd_parity.mojo (new),
aesir_engine/tests/run_all.mojo (9 cases registered, pin
373 -> 382).

## Parity battery (per format)

quantization.iq_simd_parity_* — deterministic LCG fixture
(4 super-blocks/format, scale pinned to f16 1.5; IQ1_M packed
scale pinned to d=1.5), SIMD blocks output vs scalar iq_value_g
per element, exact f16 equality lane by lane. Results (suite
run 3, a039_run_all.log): ALL 9 PASS —
IQ1_S, IQ1_M, IQ2_XXS, IQ2_XS, IQ2_S, IQ3_XXS, IQ3_S, IQ4_NL,
IQ4_XS: bit-identical to the scalar decoders (kernel-level
comparison on identical inputs, per campaign law; engine-level
IQ coherence grading is unaffected — no GEMM math changed,
dequantize_iq_block was already the production GEMV decoder).

## Measured deltas (hidden_files/a039_bench.mojo, a039_bench.log)

2048 super-blocks/format, 1 settle + 5 trials, median ns/element,
scalar iq_value_g loop (the pre-A-039 *_blocks definition) vs
A-039 blocks path. Run 2 (quiet machine) — run 1 under team-04
suite contention agreed within noise; sinks identical:

| Format | scalar ns/elem | SIMD ns/elem | speedup |
|---|---|---|---|
| IQ1_S | 4.066 | 0.142 | 28.7x |
| IQ1_M | 6.140 | 0.236 | 26.0x |
| IQ2_XXS | 5.706 | 0.337 | 16.9x |
| IQ2_XS | 5.830 | 0.426 | 13.7x |
| IQ2_S | 4.582 | 0.176 | 26.0x |
| IQ3_XXS | 6.903 | 0.377 | 18.3x |
| IQ3_S | 5.632 | 0.212 | 26.5x |
| IQ4_NL | 7.460 | 0.381 | 19.6x |
| IQ4_XS | 9.841 | 0.365 | 27.0x |

## E-MASTER suite (run_all, worktree)

Run 3 (quiet machine, canonical): 379 passed / 1 failed /
2 skipped / 382 total. Sole failure: pre-existing
gguf.tensor_directory_interface (J-022 drift, tolerated; roads
A-165/A-121). Skips: the 2 pre-declared.
Runs 1-2 (concurrent team suites on the shared GPU/host) each
showed 378/2/2/382 with one rotating unrelated flake
(gpu.amd_hip_no_leak_1000 run 1, resilience.state_vault_rejects_
growth run 2; both PASS in the other runs and at base) — filed
here as contention flakes, not A-039 effects; A-039 touches no
HIP or state-vault code. Logs: a039_run_all.log (run 3),
a039_run_all_run1.log, a039_run_all_run2.log.

## Bugs found / fixed in scope

- Bench/test identifier `out` collides with Mojo's parameter-
  convention keyword (parse error); renamed to `outp` in the new
  bench and battery files. No engine bug found.
