# A-083 Ledger - HIP Q4_K GEMV (team-13)

- Slice: A-083 HIP Q4_K GEMV, Wave 10 (HIP/ROCm fair trial),
  roadmap order after A-082. Acceptance (roadmap): same
  discipline as A-082 - CPU-oracle parity + device-execution
  evidence, via the A-010-A-012 HIP gate.
- Base: 3cfc4370 (78 of 216 banked, A-078 closure).
- Worktree: /home/volmarr/aesir-team-13, branch yrsa/aesir-team-13.
- Banks only after A-079..A-082, in roadmap order, by the keeper
  at the seat. Never merge/push from this worktree.

## Deliverables
- aesir_engine/core/hip_q4k_gemv.mojo - HipQ4kGemv gateway:
  a Mojo-native kernel (one thread per output row, f32
  accumulation per A-075) launched via MAX DeviceContext
  (api="hip") on device 0 - the A-029 road. The kernel consumes
  raw GGUF Q4_K bytes (144-byte super-blocks per 256 values)
  and decodes in-kernel: fp16 d/dmin decoded arithmetically,
  6-bit scale/min unpacking from the 12 header bytes, low/high
  nibble by group parity, value = d*(scale*q) - dmin*min -
  byte-for-byte the decode of shaders/q4k_gemv.comp (A-057) and
  the CPU oracle (core/compute.mojo, ggml kind 12). Nothing is
  dequantized on the host. Fail-closed: shape violations raise
  before any device work; no device -> raise, no host fallback.
- aesir_engine/hip_memory_shim.c (+16 lines) - A-083 dispatch
  counter (aesir_hip_q4k_dispatch_count / _note_dispatch): the
  launcher increments it ONLY after the device context has
  synchronized without error, mirroring the Vulkan shim
  dispatch counters (device-execution evidence, law 6).
- aesir_engine/tests/test_hip_q4k_gemv_a083.mojo - 3 E-MASTER
  cases: gpu.hip_q4k_gemv_oracle, gpu.hip_q4k_gemv_rejection,
  gpu.hip_q4k_gemv_no_leak.
- aesir_engine/tests/bench_hip_q4k_gemv_a083.mojo - standalone
  device bench (hidden_files/a083_bench.log).
- aesir_engine/a083_driver.mojo + hidden_files/run_a083_*.sh -
  standalone case driver + runners.
- aesir_engine/tests/run_all.mojo - registers the 3 cases
  (after the gpu.mojo_native_* cases, so the A-079 bisect GTT
  attribution is untouched); E-MASTER pin 568 -> 571.

## Device-execution evidence (bench, hidden_files/a083_bench.log
## sha256 8eebb9ad...; driver log a083_driver.log 8c611096...)
- Host purpleraider; BUILD_EXIT=0, RUN_EXIT=0,
  A083_HIP_Q4K_GEMV_BENCH: PASS; A083_DRIVER: PASS.
- Device identity: A083_DEVICE name=AMD Radeon 8060S Graphics
  (MAX DeviceContext api="hip", device 0) - the real gfx1151
  iGPU, not a host fallback. The A-029 triangulation covers this
  launch path: gfx1151 code object embedded, wrong-arch builds
  rejected at launch, hidden device raises hipErrorNoDevice -
  no silent CPU fallback exists in the path.
- Dispatch counter rose by exactly the number of calls in every
  check (+1 per oracle call, +3 per bench shape, +50 in the
  no-leak loop) - it increments only after a synchronized,
  error-free device dispatch.

## Oracle parity (same discipline as A-057/A-082)
- Oracle: banked CPU path - dequantize_ggml_k kind 12 into f16,
  then f32 dot. The HIP kernel keeps f32 throughout and never
  rounds weights to f16, so parity is judged at the filed
  f16-rounding tolerance |got-want| <= 0.02*sqrt(K) +
  0.02*|want|, never bit-exactness.
- Bench shapes (deterministic LCG 0xA083 fixture, d/dmin pinned
  to the A-040 values), max_abs_err vs filed band floor
  0.02*sqrt(K) (the |want| term only widens the band):
  rows=1 k=256: 0.07287598 (band >= 0.32)
  rows=7 k=512: 0.09698486 (band >= 0.4525)
  rows=64 k=1024: 0.32977295 (band >= 0.64)
  rows=33 k=2048: 0.3864746 (band >= 0.905)
  rows=1024 k=4096: 0.8351822 (band >= 1.28)
  All inside the band at every shape; in-suite oracle shapes
  (1/256, 7/512, 64/1024, 33/2048) PASS.
- Timing honesty: launcher medians are END-TO-END per call
  (fresh DeviceContext + host copies + launch + sync):
  gpu_median_ns 7,136,858 / 2,006,976 / 2,987,221 / 3,866,888 /
  6,986,005 vs cpu_median_ns 501 / 6,512 / 118,963 / 122,850 /
  7,649,207 for the shapes above. Small shapes are
  context-setup-bound (~2-7 ms per fresh context); at
  1024x4096 the HIP path is comparable to CPU (6.99 vs 7.65 ms).
  The kernel is one-thread-per-row (naive); kernel-level tuning
  and the HIP-vs-Vulkan verdict belong to A-085 - not claimed
  here.

## Suite evidence
- SOLO run (ps verified: no other Aesir suite/gate live -
  team-12 A-082 suite had finished, team-03 probe idle;
  hidden_files/a083_run_all.log sha256 c7435ce2...):
  568 passed / 1 failed / 2 skipped / 571 total = baseline
  565/1/2/568 + 3 new A-083 cases, all PASS, zero regressions.
  Sole failure = pre-existing gguf.tensor_directory_interface
  (J-022 drift, tolerated). Skips = the 2 pre-declared.
  memory.budget_live_meminfo_pressure PASSED this run.
- Standalone driver (a083_driver.log): all 3 cases PASS,
  MOJO_EXIT=0, run before the suite on the same tree.

## Discovered behaviour (probed, filed, NOT hidden)
- MAX per-context GTT retention: after the one-time arena pin
  (A-079 bisect family), every buffer-bearing DeviceContext on
  this pinned toolchain retains exactly 8,388,608 bytes (8 MiB)
  of GTT until process exit. Evidence: retention probe
  (hidden_files/a083_retention_probe.log) - free bytes fell by
  exactly 10 x 8 MiB per 10 HipQ4kGemv calls across 120 calls
  (never plateauing); attribution probe
  (hidden_files/a083_attr_probe.log) - bare name-only contexts
  retain ~0.25 GB total for 10, MojoNative.vec_add contexts and
  bare buffer+copy contexts each retain exactly 10 x 8 MiB per
  10 after their first kernel context triggers the arena pin.
  Verdict: MAX DeviceContext buffer-pool behaviour, pre-existing
  and shared with the A-029 MojoNative path - NOT an A-083
  operand leak (operands here are ~2.4 KB/call and are scoped
  to the context). The no-leak case therefore asserts the exact
  slice-level invariant: 50 calls retain exactly 50 x 8 MiB -
  any slice-attributable leak on top would break the equality.
- Immediate next work (platform, joins the team-03 fix road
  item 3): investigate a persistent-context launcher or a MAX
  pool cap knob so per-call context creation stops paying the
  8 MiB retention + ~2-7 ms setup; re-file the no-leak constant
  if the toolchain changes it.

## Bugs
- None discovered in engine code in scope. The driver-first
  no-leak design (hipMemGetInfo equality after 1 warm-up call)
  failed on the retention above; root-caused by probe to the
  runtime behaviour and re-filed exactly - see above. All
  probe attempts and the failed first driver run are preserved
  in the logs on disk.
