# A-040 Ledger - K-quant GEMV audit (team-08)

Slice: A-040, team-08, branch yrsa/aesir-team-08, base 9d0fd725
(A-036 banked, 36 of 216). Wave 5, census row A-037:C-001
(GEMV family; A-037 profiled an F16 fixture, so this slice
profiled its own quant fixtures, per the census note).
Roadmap: "Q4_K/Q5_K/Q6_K single-row paths audited for scalar
pockets; fixed where found. Acceptance: per-format before/after
timings + parity."

## Audit - which single-row paths exist

CPU decode (single row = gemm with A.rows == 1; there is no
separate GEMV entry point - inference decode calls gemm_q4_k_m /
gemm_q5_k_m / gemm_q6_k, all funnelled by gemm_ggml_k):

| Path | Where | Verdict |
|---|---|---|
| GEMM/GEMV fast path kinds 12/13/14 | compute.mojo _gemm_k_fast_range | ALREADY SIMD width-16: block decode into f32 scratch via width-16 loads/unpack, dot via width-16 FMA + per-super-block reduce_add. No scalar pocket in the hot loop. Residual scalar work: per-super-block coefficient extraction (8 iterations Q4_K/Q5_K, 16 Q6_K, incl. div/mod index math in Q6_K/Q2_K loops) - measured immaterial (see GEMV timings: unchanged by this slice, already at memory-bound pace). |
| Scalar GEMM comparator | compute.mojo _gemm_k_scalar_range | Scalar by design (packed_value per element); unreachable from gemm_ggml_k for kinds 10-14 (fast path returns first) - preserved as the parity comparator. NOT a live pocket. |
| Public dequantizer Q4_K/Q5_K/Q6_K | compute.mojo dequantize_ggml_k -> dequantize_q4_k_m / dequantize_q5_k_m / dequantize_q6_k_block, dispatched by dequantize_compressed_tensor (used by core/quantization_autotuner.mojo) | **SCALAR POCKET - FIXED.** Element-by-element loop over packed_value(): per element it re-derived div/mod block indices AND the full block header (d/dmin loads, scale unpack). 8.9-12.3 ms per 2,097,152 elements. |
| Public dequantizer Q2_K/Q3_K (kinds 10/11) | same dequantize_ggml_k loop | Scalar, same shape - OUT OF SCOPE for A-040 (roadmap names Q4_K/Q5_K/Q6_K only); recorded as follow-up below. |
| GPU Gemma4 matvec | gemma4_kernels.mojo matvec_kernel / packed_matvec_kernel (CUDA) | Per-lane packed_value reads - GPU warp path, different hardware line; noted, not touched. |

Search evidence: grep -rn Q4_K/Q5_K/Q6_K over aesir_engine/core
+ loader (file list in bench log header); every CPU entry point
above was read in full. No other CPU K-quant single-row path
exists in the engine.

## Fix

compute.mojo: new _dequantize_ggml_k_simd (width-16 SIMD block
decode, one header extraction per 256-value super-block) wired
into dequantize_ggml_k for kinds 12/13/14 only; kinds 10/11 keep
the scalar loop. Bit-identical by construction: Q4_K/Q5_K keep
packed_value's integer scale*q product (exact in f32, <= 1953)
formed before the d multiply, dmin*minimum formed once per
sub-block exactly as scalar forms it per element; Q6_K keeps
(d*scale)*(q-32) order. Scalar packed_value preserved untouched
as comparator.

Regression pin: tests/test_k_dequant_simd_a040.mojo adds 3
run_all cases (quantization.k_dequant_simd_q4_k/q5_k/q6_k_parity),
run_all pin 377 -> 380.

## Fixtures and method

Bench: aesir_engine/tests/bench_k_gemv_a040.mojo (standalone,
not in run_all), logs hidden_files/a040_bench_before.log /
a040_bench_after.log. Fixtures: deterministic synthetic
super-blocks, LCG seed 0xA040+kind (dequant) / 0xB040+kind
(GEMV), d pinned to f16 0.046875, dmin to 0.01171875, quant bytes
LCG-filled - filed synthetic provenance (no on-disk model carries
all three K formats; stories260K is F16). Dequant: 8,192 blocks =
2,097,152 elements/format, 15 reps, median. GEMV: single row,
K=4096, N=4096, 15 reps, median. Machine: purpleraider, quiet
(loadavg 0.19 at before-run start; after-run waited for the
seat's concurrent run_all to finish before launching).

## Before / after timings

Dequantize (median ns per 2,097,152 elements):
| Format | Before (scalar) | After (SIMD) | Speedup |
|---|---|---|---|
| Q4_K (12) | 8,939,308 | 116,187 | 76.9x |
| Q5_K (13) | 9,382,678 | 141,715 | 66.2x |
| Q6_K (14) | 12,347,211 | 160,280 | 77.0x |

GEMV single-row K=4096 N=4096 (median ns) - fast path unchanged
by this slice; reported per acceptance (audit result: no pocket):
| Format | Before | After | Delta |
|---|---|---|---|
| Q4_K | 448,418 | 447,887 | -0.1% (noise) |
| Q5_K | 458,357 | 434,282 | -5.3% (noise band) |
| Q6_K | 459,730 | 453,007 | -1.5% (noise) |

## Parity

- Dequant: BIT-IDENTICAL vs scalar packed_value, 0 mismatches of
  2,097,152 elements per format, before trivially and after the
  fix (bench DEQ_PARITY bad=0 for kinds 12/13/14 in both logs).
- GEMV: fast path vs scalar packed_value GEMV (f32 ascending-K):
  max abs diff 0.484 / 0.993 / 3.664 against max |output| 1556 /
  3028 / 8996 - relative 3.1e-4 / 3.3e-4 / 4.1e-4, i.e. at the
  f16 output ulp for those magnitudes; identical before and
  after (GEMV untouched). Kernel-level parity class: filed
  tolerance = f16 final rounding, evidence above.
- Engine-level raw-oracle claims: none made by this slice
  (kernel audit; A-045 owns the wave parity battery).

## Suite

E-MASTER run_all via hidden_files/run_a040.sh, log
hidden_files/a040_run_all.log: 377 passed / 1 failed / 2 skipped / 380 total (new pin). Sole failure = pre-existing gguf.tensor_directory_interface J-022 drift (tolerated); the 3 new quantization.k_dequant_simd_* cases all PASS.

## Follow-ups (recorded, not silently dropped)

- Q2_K/Q3_K public dequantizer remains scalar (kinds 10/11 in
  dequantize_ggml_k) - same fix pattern applies; natural home is
  a later format-breadth slice, not A-040's named scope.
- GEMV coefficient-extraction loops (Q6_K div/mod per sub-block)
  are scalar but immaterial at current GEMV pace; revisit only if
  a future census row names them.
