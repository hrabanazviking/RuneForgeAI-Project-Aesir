# AES500-091 — RMS normalization oracle contract

## Objective

Define the numerical and shape contract for the current CPU `rmsnorm` kernel
and provide a direct independent F32 reference suite across row widths and SIMD
tails. The first contract slice does not change kernel behavior.

## Owner and current behavior

- Owner: `aesir_engine/core/compute.mojo::rmsnorm`.
- Input/output: in-place row-major `RuneTensor[f16]` `T`; read-only F16 weight
  vector; F32 epsilon defaulting to `1e-5`.
- For each row, accumulate `ss = sum_k(f32(x[r,k]) * f32(x[r,k]))`, compute
  `inv_rms = 1 / sqrt(ss / cols + epsilon)`, then write
  `f16((f32(x[r,c]) * inv_rms) * f32(weight[c]))`.
- Accumulation and normalization are F32, then each output is rounded to F16.
- The SIMD prefix uses the F16 SIMD width (currently 16 lanes) and
  `reduce_add`; any remaining columns use a scalar F32 accumulation. Their
  accumulation order may differ, so oracle parity is tolerance-based rather
  than bitwise F32 equality.
- The SIMD prefix and scalar tail must produce values consistent with the
  scalar reference within the declared tolerance in the implementation slice.

## Admission invariants

- `T.rows > 0` and `T.cols > 0`.
- `weight.size >= T.cols`; the implementation consumes the first `T.cols`
  linear elements regardless of the weight descriptor's row/column shape;
  additional elements are ignored.
- The implementation rejects `epsilon <= 0`. AES500-094 tightens admission to
  finite positive epsilon: NaN and either infinity reject before mutation.
  This makes the normalization denominator an admitted positive finite input;
  it does not define non-finite tensor or weight behavior.
- The kernel reads tensor fields directly and does not call `RuneTensor.checked()`.
  This contract does not imply checked construction, backing capacity, pointer
  provenance, or lifetime safety.
- Widths below, equal to, and above the F16 SIMD width must cover scalar-only,
  exact-vector, and vector-plus-tail paths.
- The kernel remains in-place and preserves its signature in this program.

## Exclusions

No GPU/NPU parity or accelerator admission, performance claim, arbitrary-stride
  support, backing allocation or pointer-lifetime proof, training gradient, or
  change to reduction order is implied. The adversarial evidence defines the
  tested IEEE behavior: F16 NaN input propagates across its row, F16 +/-Inf
  input yields NaN at the infinite element and zero at finite peers in that row,
  and NaN/+Inf/-Inf weights propagate only to their output column. The kernel
  does not sanitize these values. Finite F32 sum-of-squares overflow/underflow
  and wider adversarial distributions remain unproven. F16 result
  comparisons must account for final rounding; the F32 oracle is independent
  scalar arithmetic, not another SIMD call into production code. The numerical
  tolerance must combine absolute and relative error and be justified against
  measured F16 rounding and reduction-order variation in AES500-092 before
  implementation acceptance.

## Planned evidence

- Baseline current source/toolchain and existing boundary test before edits.
- Interface adds this formula and accepted/rejected inputs.
- Unit evidence in `compute.rmsnorm_reference` builds deterministic rows and
  weights, computes expected F32 results with scalar loops independently of
  production SIMD, rounds expected outputs to F16, and checks widths 3, 15,
  16, 17, and 33 across two rows. Exact agreement is confined to this corpus;
  it does not establish a general tolerance.
- Malformed tests reject zero dimensions, short weights, and nonpositive
  epsilon before mutation; exact before/after input snapshots prove no partial
  writes on rejected admission.
- Integration exercises the existing `forward_pass` output-normalization
  consumer with a deterministic token result and arena restoration on success
  and rejected RMSNorm admission, then checks that short-weight and non-finite
  epsilon failures propagate from the shared RMSNorm contract. The convenience
  overload must also roll back its temporary KV-cache arena allocation.
  The registered synthetic transformer forward case also executes the layer
  attention and feed-forward RMSNorm consumers; no inference path is changed.
- Adversarial evidence in `compute.rmsnorm_adversarial` compares F16 minimum
  subnormal and maximum finite input rows to scalar F32 results, exercises the
  documented input/weight IEEE propagation, and preserves the limits on F32
  overflow/underflow and broader data distributions.

## Acceptance

This is a documentation-only contract. Architect and Auditor review the formula,
admission, and unresolved finite policy; `git diff --check` passes. No source or
test behavior changes in AES500-091.
