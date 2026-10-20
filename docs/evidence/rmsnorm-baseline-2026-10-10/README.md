# AES500-092 — RMSNorm baseline

## Identity

- Baseline source commit: `351bc995d4bb41bfa11c30ae6863f492639047f0`.
- This is a historical snapshot from AES500-092, before the finite-epsilon
  change in AES500-094 and the bounded exceptional-value evidence in AES500-097.
- Toolchain: Mojo 1.0.0 (`ed45d567`), Linux x86_64; Pixi environment from
  `pixi.toml`.
- Production owner: `aesir_engine/core/compute.mojo::rmsnorm`.
- Existing focused boundary: `aesir_engine/tests/test_compute.mojo::test_kernel_bounds`.
- No direct numerical RMSNorm test is registered in `aesir_engine/tests/run_all.mojo`.

## Reproduction commands

```sh
pixi run mojo run --target-accelerator sm_89 -I aesir_engine \
  docs/evidence/rmsnorm-baseline-2026-10-10/rmsnorm_baseline.mojo \
  > docs/evidence/rmsnorm-baseline-2026-10-10/raw-output.txt
python3 docs/evidence/rmsnorm-baseline-2026-10-10/compare_scalar_reference.py \
  > docs/evidence/rmsnorm-baseline-2026-10-10/reference-comparison.json
pixi run mojo run --target-accelerator sm_89 -I aesir_engine \
  docs/evidence/rmsnorm-baseline-2026-10-10/rmsnorm_bounds_baseline.mojo
```

It reports `checked kernel boundaries: PASS`; its RMSNorm assertion only checks
that a weight tensor shorter than `T.cols` is rejected. The tracked baseline
probe covers two rows at widths 3, 15, 16, 17, and 33 using deterministic F16
inputs/weights and epsilon `1e-5`. It captures current inputs and outputs,
including the scalar-only, exact 16-lane, vector-plus-tail, and multiple-block
paths. The independent NumPy F32 scalar reference currently matches every
captured F16 output: zero mismatches and maximum absolute error zero across 168
values. This is one deterministic baseline corpus, not a general tolerance or
all-input correctness proof.

## Source and artifact hashes

| File | SHA-256 |
|---|---|
| `aesir_engine/core/compute.mojo` | `9566fc2bd0ce8dd9f07767ab5c329fc0b4706cb73eac9c4aaf2502f04a1d9bea` |
| `aesir_engine/tests/test_compute.mojo` | `b2e16d054a590cc8387ef64a4767a9fc89aea51d904cfe6361eb2af9d42a89b2` |
| `rmsnorm_baseline.mojo` | `01a6a217e45e0fe0e98cb6dab2c3fd9b6f68fa0465b8dd8f5aff861c736afbbb` |
| `rmsnorm_bounds_baseline.mojo` | `27c982eff95430afc02cc3feed4e14f632d452496850a1c28f04af7ab48aed7d` |
| `raw-output.txt` | `cf33dd8a7b6a593ecf73b1a55ec2342c1e458da441b439804a660a3c6b5be208` |
| `compare_scalar_reference.py` | `9a0f75adc7f9d991660a90a04d9f57b0a5ee10d999db05c28866e8c65945b32b` |
| `reference-comparison.json` | `7c913310632ff987ccb0bfd8052e05511e804a4ecabd45b56a00ea0d808c4217` |

## Findings and limits

- Current kernel source and interface tests show the reduction is an F32 sum of
  squares, SIMD-reduced in 16-lane chunks and completed by a scalar tail.
- The source computes `1 / sqrt(sum / cols + epsilon)` and then multiplies each
  input by that inverse and its corresponding flat weight element before F16
  storage.
- At the baseline commit, the contract rejected nonpositive epsilon and short
  weights but did not reject NaN or positive infinity epsilon. This capture
  uses ordinary finite epsilon only; later policy changes are tracked by
  AES500-094 and AES500-097.
- The tested corpus does not cover randomized inputs, near-zero/very-large
  finite values, NaN/infinity inputs, overflow or underflow, arbitrary tensor
  pointer validity, or accelerated implementations.
- Source and existing boundary tests were not changed in AES500-092.
