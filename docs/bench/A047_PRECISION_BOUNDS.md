# A-047 — Per-Precision Error Bounds (Z13 CPU)

- Slice: A-047 — Precision paths (Wave 6, Z13 Massive Roadmap)
- Date: 2026-11-12
- Base: 40ce2d88 (A-044 banked; 44 of 216)
- Machine: purpleraider — ASUS ROG Flow Z13, AMD Ryzen AI Max (Strix
  Halo, Zen 5), Radeon 8060S gfx1151 present but NOT used: every path
  verified here is a CPU path. No accelerator execution is claimed.
- Toolchain: Mojo 1.0.0 / MAX 26.5.0 (pixi, frozen), target gfx1151
  build flags as per the E-MASTER gate; engine code at the base above.
- Measurement log: hidden_files/a047_probe.log (team-05 worktree);
  gate cases in aesir_engine/tests/test_precision_paths.mojo assert
  the filed bounds below on every E-MASTER run.

## Method

References are Float64 scalar loops over the EXACT stored inputs —
the F16 values actually in the tensors and the BF16 bit patterns
actually in storage (BF16 patterns decoded arithmetically in Float64:
sign * (1 + mant/128) * 2^(exp-127)). No reference is produced by the
path under test or by its retained scalar oracle (gemm_bf16_scalar is
not used). This measures compute error only; input quantisation to
the storage format is an input property, already inside the exact
stored values the reference consumes.

Probe: aesir_engine/tests/bench_precision_a047.mojo (standalone,
deterministic in-file LCG seeds). Shapes: GEMM M=8, K=1024, N=32 with
inputs uniform in [-1, 1] (BF16 patterns bounded to about [-2, 2]);
RMSNorm 4 rows x 257 cols (SIMD body + scalar tail), epsilon 1e-5.

Error metrics: max_abs = max |got - ref|; max_rel = max |got - ref| /
|ref| over outputs with |ref| >= 1.0 (GEMM) or >= 0.1 (RMSNorm).

## Filed bounds

| Path | Case | Measured max_abs | Measured max_rel | Filed bound (abs) | Filed bound (rel) | Verdict |
|---|---|---:|---:|---:|---:|---|
| F32 accumulation | gemm_f16_direct, dyadic inputs K=256 | 0 (bit-exact) | 0 (bit-exact) | 0 — bit-exact vs F64 ref rounded once to F16 | 0 | PASS |
| F32 internal math | rmsnorm (F32 sumsq/sqrt/scale), 4x257 | 0.000484 | 0.000472 | 4e-3 | 4e-3 | PASS |
| F16 compute | gemm_f16_direct (F16 storage, F32 accumulate), K=1024 | 0.007810 | 0.000415 | 1.6e-2 | 4e-3 | PASS |
| BF16 compute | gemm_bf16 (exact widening, F32 accumulate), K=1024 | 0.031064 | 0.000434 | 6.25e-2 | 4e-3 | PASS |
| BF16 widening | bf16_bits_to_f32, all 65536 patterns | 0 | 0 | 0 — exact for all 65280 normal patterns; +/-0 widen to +/-0 | 0 | PASS |
| F16 rounding | F32 -> F16 -> F32 roundtrip, 1M values, normals (|v| >= 0.01) | — | 0.000487 | — | 4.8828125e-4 (half F16 ULP, 2^-11) | PASS |

Reading of the table:

- The F16 and BF16 GEMM relative errors are the same size (4.2e-4 vs
  4.3e-4) and both are dominated by the single F16 output rounding —
  the flatness across precisions is itself the evidence that both
  paths accumulate in F32. BF16's larger max_abs is a magnitude
  effect (larger outputs), not a precision effect: its max_rel sits
  in the same band. A path that accumulated in BF16/F16 would show
  relative error growing with K; neither does.
- The roundtrip maximum (0.00048733) reaches 99.8% of the half-ULP
  bound (0.00048828): the F32 -> F16 cast rounds to nearest even,
  it does not truncate.
- Subnormal band: for |v| below the F16 minimum normal (6.1e-5),
  F16 spacing is a fixed 2^-24 absolute, so relative error there is
  spacing-dominated and unbounded as |v| -> 0; the filed statement
  for that band is the absolute spacing bound (max abs err <= 2^-25
  under round-to-nearest), not a relative bound. The roundtrip gate
  therefore guards |v| >= 0.01 for the relative claim.

## Reproduction

    # probe (measurements above)
    cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c \
      -o $STAGING/libaesir_par.so -lpthread
    pixi run --frozen mojo run -I . --target-accelerator gfx1151 \
      -Xlinker -L$STAGING -Xlinker -laesir_par \
      aesir_engine/tests/bench_precision_a047.mojo

    # regression gate: the six precision.* cases run inside the
    # canonical E-MASTER suite (aesir_engine/tests/run_all.mojo).

## Caveats

- Bounds are filed for the shapes/ranges above on this CPU. They do
  not transfer to the gfx1151 GPU or XDNA NPU paths (not measured
  here, no claim made), nor to K far beyond 1024 without re-filing.
- NaN/Inf propagation is not part of this slice's bounds; conversion
  of special values follows the F32 cast semantics and is covered
  only for +/-0 widening above.
