# Greedy tie policy baseline — 2026-10-10

## Environment and reproduction

- Toolchain: `Mojo 1.0.0 (ed45d567)` from project Pixi environment.
- Command: `pixi run mojo run -I aesir_engine aesir_engine/tests/_greedy_tie_baseline.mojo`.
- Exit status: 0.
- Output: sampler stack PASS; `cpu_tie_selected= 1` for finite logits `[1,5,5,0,5]`.
- The small executable imports and runs the existing `test_sampler_stack`, then tests the existing public CPU sampler on the tied vector. Its leaked fixture allocation is scoped to this short-lived process.
- This baseline establishes CPU behavior only. CUDA tie behavior is supported by source inspection of `argmax_kernel` (warp maximum followed by minimum matching ID), not a physical GPU run. Non-finite handling, suppression behavior, full-model output, and performance are not measured here.

## Source hashes at baseline

- `aesir_engine/core/sampler.mojo` SHA-256: `08a96af7fb86416abffcd692258befb40f4717f2b242a4c6402b5163cdf476e7`
- `aesir_engine/core/gemma4_kernels.mojo` SHA-256: `ceb8d12815f4eca545812c9852e2a085399cb331cf5510425dd2716978854ce6`
- `aesir_engine/core/cuda_sampling.mojo` SHA-256: `6d585f0717613f2b322c190e57bfae6dbae91f26da905794ff8edaec820d761a`
- `aesir_engine/tests/test_inference.mojo` SHA-256: `be35a46cbc9d2f2b8c4fc867c1ee9cd2e5f7e60c2a11b14a3f7d316318d947fb`
- `aesir_engine/tests/_greedy_tie_baseline.mojo` SHA-256: `e5f7b3a7d9540eed200a4263a9bd79fc8e2b20cb66b05990eea1928bcd477a07`
