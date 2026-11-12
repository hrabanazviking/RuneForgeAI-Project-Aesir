# A-057 Ledger - Vulkan Q4_K GEMV (team-08)

- Slice: A-057 Vulkan Q4_K GEMV, Wave 7, roadmap order after A-056.
- Base: b62b1481 (54 of 216 banked, Wave 6 COMPLETE).
- Worktree: /home/volmarr/aesir-team-08, branch yrsa/aesir-team-08.
- Previous lead built the slice; run cancelled before commit.
  This lead verified WIP from disk, re-ran the suite cleanly
  solo, and committed. No code changes were needed.

## Deliverables
- aesir_engine/shaders/q4k_gemv.comp - Q4_K GEMV compute kernel:
  one workgroup (256 threads) per output row, shared-memory tree
  reduction; Q4_K super-block decode mirrors the banked CPU
  oracle (core/compute.mojo _dequantize_ggml_k_simd, ggml kind
  12): 144-byte super-blocks, 6-bit scale/min unpacking from the
  12 header bytes, low/high nibble by group parity,
  value = d * (scale * q) - dmin * min.
- aesir_engine/vulkan_buffer_shim.c (+573) - embeds the shader,
  dispatch plumbing, dispatch counter (increments only after a
  submitted dispatch completes on device).
- aesir_engine/core/vulkan_buffers.mojo (+43) - buffer/dispatch
  API + RADV device identity check.
- aesir_engine/tests/test_vulkan_q4k_gemv_a057.mojo - 3 E-MASTER
  cases: gpu.vulkan_q4k_gemv_oracle, gpu.vulkan_q4k_gemv_rejection,
  gpu.vulkan_q4k_gemv_no_leak.
- aesir_engine/tests/bench_vulkan_q4k_gemv_a057.mojo - standalone
  device bench.
- aesir_engine/tests/run_all.mojo - registers the 3 cases;
  E-MASTER pin re-pinned 445 -> 448.

## Device-execution evidence (bench, hidden_files/a057_bench.log)
- Host purpleraider, RADV STRIX_HALO: A057_DEVICE vendor=4098
  (0x1002 AMD) device=5510 type=1 api=4211042 RADV=1.
- Identity discipline (A-015 pattern): vendor must be 0x1002,
  device_type must not be 4 (CPU), device name must be RADV -
  llvmpipe is explicitly REFUSED; on a host without the device
  the cases assert fail-closed honest-absent behaviour.
- BUILD_EXIT=0, RUN_EXIT=0, A057_VULKAN_Q4K_GEMV_BENCH: PASS.

## Oracle parity (same discipline as A-056)
- Oracle: banked CPU path - dequantize_ggml_k kind 12 into f16,
  then f32 dot. GPU kernel keeps f32 throughout and never rounds
  weights to f16, so parity is judged at the filed f16-rounding
  tolerance |got-want| <= 0.02*sqrt(K) + 0.02*|want|, never
  bit-exactness (raw-oracle discipline; coherence band).
- Bench shapes (deterministic LCG 0xA057 fixture, d/dmin pinned
  to A-040 values), max_abs_err / max_rel_err:
  rows=1 k=256: 0.0014190674 / 5.867199e-06
  rows=7 k=512: 0.104904175 / 0.0006425287
  rows=64 k=1024: 0.23120117 / 0.0034202542
  rows=33 k=2048: 0.35473633 / 0.0008034447
  rows=4096 k=4096: 0.82373047 / 0.21833426 (rel err is against
  the near-zero row outputs at this shape; abs err inside the
  filed band 0.02*sqrt(4096)=1.28 plus the |want| term)
- GPU median ns vs CPU median ns: k=4096 shape gpu 417,722 vs
  cpu 31,179,343 (device execution is the fast path by ~75x at
  the large shape; small shapes are dispatch-bound, recorded
  honestly, not hidden).

## Suite evidence
- Contended first run (hidden_files/a057_run_all_contended.log,
  three Aesir suites concurrent ~11:53-12:07): 444 passed /
  2 failed / 2 skipped / 448 total. Failures: tolerated
  pre-existing gguf.tensor_directory_interface (J-022 drift)
  + resilience.state_vault_rejects_growth.
- CLEAN SOLO RE-RUN by this lead (no other suite running, ps
  verified; hidden_files/a057_run_all_clean.log, runner
  hidden_files/run_a057_suite_clean.sh):
  445 passed / 1 failed / 2 skipped / 448 total.
  Sole failure = gguf.tensor_directory_interface (J-022,
  tolerated). All 3 A-057 cases PASS. resilience case PASSED -
  the contended-run failure is confirmed as the documented
  concurrency flake, not a defect in this slice.
- Count check: baseline 445 total at b62b1481 + 3 new A-057
  cases = 448 total. 445 passed = 442 baseline passed + 3 new.

## Bugs
- None discovered in scope. No code changes by this lead.
- resilience.state_vault_rejects_growth: flake verdict above,
  evidence in the two logs; no silent bug left behind.

## Banking
- Committed on yrsa/aesir-team-08 only. Banks only after A-055
  and A-056, in roadmap order, by the keeper at the seat.
  Never merge/push to main from the team worktree.
