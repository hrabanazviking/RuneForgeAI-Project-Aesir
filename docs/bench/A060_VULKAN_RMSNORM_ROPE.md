# A-060 — Vulkan RMSNorm + RoPE

RMSNorm and rotary position embedding (RoPE) dispatched on the
GPU, judged per op against independent CPU references with the
A-056 discipline. Roadmap acceptance: reference parity per op,
incl. adversarial shapes from the existing compute test
patterns.

## What was built

- Shaders: none written. Both kernels are the A-055 foundation
  shaders, written for this slice and already compiled by the
  A-055 SPIR-V build pipeline: aesir_engine/shaders/
  rmsnorm.comp (SPIR-V 3984 B, sha256
  b23cb30bc450a41d97e447c608063a7498b5df218ac95c4702a54c1187d3c7ae;
  source sha256
  74a4c2e758f42b70076cc8e7f12d309520f0e1dd8f5370654a12918e99c8030c)
  and rope.comp (SPIR-V 2880 B, sha256
  5de79760b84c0ca6bbe0ce773241b5fc6a5e260c1a98e86f560e10665da50768;
  source sha256
  1f63e9790883396df28db0e8123957f826d52b79aca1e02ad7b04dc54121412f).
  The shim consumes the words from the A-055 generated header
  (aesir_engine/shaders/generated/aesir_shaders_spv.h,
  kRmsnormSpv / kRopeSpv) — no hand-embedded words, no runtime
  fetch. This slice is the first Wave 7 consumer of the
  pipeline for its dispatch path (A-056..A-058 hand-embedded).
- RMSNorm: y[i] = x[i] * rsqrt(mean(x^2) + eps) * g[i], one
  workgroup of 256 invocations per row, shared-memory
  reduction; push constants {n, rows, eps} (12 B). This is the
  engine CPU rmsnorm math (core/compute.mojo) in Float32
  throughout: eps inside the root, added to the mean of
  squares, weight applied after normalisation, no (1+g).
- RoPE: in place over rows of head_dim, rotate-half pairing
  (i, i + head_dim/2), angle position * base^(-2i/head_dim);
  push constants {head_dim, rows, position, base} (16 B); one
  invocation per pair. Rotate-half is the pairing of the
  shader of record and of the engine CPU apply_rope with
  neox=True; the CPU default (interleaved) is a different
  layout and is NOT what this kernel implements — recorded
  here as the slice's explicit convention decision. The
  kernel's single position for all rows is the decode shape
  (rows = heads of one token); prefill-style per-row
  positions need one dispatch per token.
- Shim dispatch: aesir_vk_buffer_rmsnorm /
  aesir_vk_buffer_rope in aesir_engine/vulkan_buffer_shim.c,
  mirroring the A-056 Q8_0 dispatch on the same context,
  device, queue and buffer slots (per-call pipeline, submit +
  queue-wait-idle before return). Float arguments cross the
  FFI as IEEE-754 bit patterns. Counters
  aesir_vk_rmsnorm_dispatch_count /
  aesir_vk_rope_dispatch_count increment only after submit +
  wait-idle — the filed device-execution evidence (law 6).
- Mojo gateway: core/vulkan_norm_rope.mojo, VulkanNormRope
  .rmsnorm / .rope / .rmsnorm_dispatch_count /
  .rope_dispatch_count, fail-closed with the A-056 error
  taxonomy; shapes validated before any dispatch.

## Parity verdicts (RADV STRIX_HALO, llvmpipe refused)

Oracles are sequential Float32 references written in the test
file from the op definitions (tests/
test_vulkan_rmsnorm_rope_a060.mojo) over the identical input
data — never the code under test, never the F16 engine path.

- RMSNorm (eps 1e-5): 7 shapes (rows x n = 1x64, 4x256,
  13x37, 3x255, 2x257, 37x320, 1x4096) + a scale-1000 shape
  (2x512): worst max_abs 1.2672921e-06 (37x320). Filed bound
  1e-3 (accumulation order only; ~800x headroom). Zero row ->
  exact zeros; constant row -> -g within 1e-4. Known value:
  x=[3,4], eps=3.5, g=[2,0.5] -> [1.5, 0.5] exact (dyadic:
  mean 12.5 + 3.5 = 16, rsqrt = 1/4).
- RoPE (base 10000): 6 shapes (head_dim 32..256, positions
  0..1000): worst max_abs 6.765127e-05 at position 1000
  (head_dim 64); position 128 gives 1.8537045e-05, positions
  0..7 stay at or below 8.42e-07, position 0 is exactly 0.0.
  The growth with position is fp32 angle argument reduction
  (RADV vs host libm on angles up to 1000 rad) — a precision
  verdict, not a layout error: the low-position shapes pin
  the pairing exactly. Filed bound 1e-3 (~15x headroom).
  Position 0 is an exact identity, asserted exactly;
  per-pair squared norms preserved at position 5.

## Cases (6 new, E-MASTER gpu.*)

gpu.vulkan_rmsnorm_oracle_parity, gpu.vulkan_rmsnorm_known_value,
gpu.vulkan_rope_oracle_parity, gpu.vulkan_rope_known_properties,
gpu.vulkan_rmsnorm_rope_rejection (11 bad calls: zero/odd
dims, eps 0, negative position, oversize, bogus id),
gpu.vulkan_rmsnorm_rope_dispatch_evidence (counters +2/+2,
accounting exact). Suite pin 458 -> 464.

## Known pre-existing (not this slice)

- scripts/build_shaders.py --check fails identically on the
  pristine seat at 5b172516: A-056/A-057 added q8_0_gemv /
  q4k_gemv .comp files after the A-055 manifest was written
  (manifest kernel_count 8 vs 10 sources). Manifest
  regeneration is the recorded A-056/A-057 follow-up; A-060
  does not regenerate (it would rewrite the header/manifest
  beyond this slice's scope) and consumes the banked
  generated words for rmsnorm/rope, whose manifest entries
  are present and hash-correct.
