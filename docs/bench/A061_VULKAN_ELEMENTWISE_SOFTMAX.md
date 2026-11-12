# A-061 — Vulkan elementwise + softmax

SiLU/mul/add (residual) and gated SiLU, plus a numerically
careful in-place row softmax, dispatched on the GPU. Roadmap
acceptance: reference parity; softmax max-subtraction proven
on adversarial logits.

## What was built

- Shaders: none written. Both kernels are the A-055 foundation
  shaders: aesir_engine/shaders/elementwise.comp (SPIR-V
  2868 B, sha256 804583081f7299d73d96d78ce565a276f51f64db815
  e6756d8512860d33170ca) and softmax.comp (SPIR-V 4552 B,
  sha256 706162baf9e9194a8ea5f3e558bd6bbe00acbce026bd7cd148
  7b6a95e482c1cc). The shim consumes the words from the A-055
  generated header (aesir_engine/shaders/generated/
  aesir_shaders_spv.h, kElementwiseSpv / kSoftmaxSpv) — no
  hand-embedded words, no runtime fetch.
- Elementwise: push constants {n, mode}; mode 0 silu(a),
  1 a*b, 2 a+b, 3 silu(a)*b; one invocation per element,
  dispatch groups = ceil(n/256); the shader count guard makes
  non-multiple sizes exact.
- Softmax: push constants {n, rows}; one workgroup of 256
  invocations per row; the kernel reduces the row maximum,
  subtracts it before exponentiation, reduces the exponent
  sum, and normalises in place.
- Shim: aesir_engine/vulkan_buffer_shim.c gains
  aesir_vk_buffer_elementwise / aesir_vk_buffer_softmax in
  the A-060 pattern (pipeline per call, submit,
  queue-wait-idle; counters increment only after wait-idle —
  the law-6 device-execution evidence).
- Gateway: aesir_engine/core/vulkan_elementwise.mojo
  (VulkanElementwise), fail-closed like A-014/A-015/A-056/
  A-058/A-060: unavailable Vulkan/RADV raises, shapes and
  modes are validated before any dispatch, no host fallback.

## Parity (sequential Float32 oracles, RADV STRIX_HALO)

- Elementwise mul/add: bitwise exact (max abs delta 0.0) at
  n = 37, 255, 256, 257, 1000, 4096. SiLU: worst 4.77e-07
  (scale 4), 9.54e-07 (scale 50). Gated SiLU: worst 1.91e-06
  (scale 4), 3.05e-05 (scale 50, relative ~6e-07). Filed
  bound 1e-3.
- Softmax: worst 5.96e-08 over (rows, n) = (1,64), (4,37),
  (3,257), (2,1024); every row sums to 1.
- Adversarial logits: a row shifted by +100 stays finite and
  matches the oracle (naive exp overflows); an all -1000 row
  produces exactly the uniform distribution (naive exp
  underflows to a zero denominator) — max-subtraction proven;
  a single-spike row matches the oracle.
- Suite: E-MASTER run_all 466 passed / 1 failed / 2 skipped
  / 469 total on the A-058 base; sole failure is the
  pre-existing tolerated gguf.tensor_directory_interface
  (J-022); the 6 new cases all pass. Full record:
  hidden_files/A061_LEDGER.md.
