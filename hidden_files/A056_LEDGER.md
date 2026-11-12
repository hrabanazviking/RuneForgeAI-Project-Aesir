# A-056 Ledger — Vulkan Q8_0 GEMV (team-07)

- Base: b62b1481 (seat main, 54 of 216 banked, Wave 6 COMPLETE;
  ls-remote verified == b62b14810750f03009584dede346aa0d573a152e).
  Previous slice A-048 verified banked in seat git log
  (38564cb2 + banking closure 259ad427) before the reset.
  Worktree reset --hard onto b62b1481; CAMPAIGN_STATE.md +
  hidden_files/ (untracked) preserved (backup at /tmp/t07_backup).
- Crew: lead + 6 Mythic Engineering sub-agents spawned, no 429.
  Scouts covered Vulkan precedent, CPU oracle, harness, GLSL,
  tolerances, A-055 dependency. One scout read a stale tree
  (HEAD at A-038) and its structural claims were discarded;
  all build decisions rest on the lead's direct reads at
  b62b1481.

## Deliverables
- aesir_engine/shaders/q8_0_gemv.comp — GLSL source of record.
- aesir_engine/vulkan_buffer_shim.c — embedded SPIR-V +
  aesir_vk_buffer_q8_gemv dispatch + dispatch counter.
- aesir_engine/core/vulkan_gemv.mojo — VulkanGemv gateway.
- aesir_engine/tests/test_vulkan_q8_gemv.mojo — 5 cases.
- aesir_engine/tests/run_all.mojo — registered gpu.vulkan_q8_gemv_*
  + re-pin 445 -> 450.
- docs/bench/A056_VULKAN_Q8_GEMV.md — filed verdicts.

## Shader / SPIR-V
- glslangValidator -V aesir_engine/shaders/q8_0_gemv.comp
  -> 6076 bytes, sha256
  af3a2f037eff04e192cb9477debbcab14bcebb9354874dcec8e8b337b47ce302.
- Toolchain reproducibility: vec_add.comp recompiles to the
  A-015 filed sha256 b228710b...ce15b exactly.

## GPU-vs-CPU parity verdicts (RADV STRIX_HALO, llvmpipe refused)
- Oracle parity (sequential F32 CPU oracle, identical bytes):
  worst max_abs 9.8347664e-05 at (13, 4096); shapes (1,32),
  (4,64), (16,288), (37,320), (64,1024), (13,4096) all PASS
  under the filed 1e-3 bound (accumulation-order only).
- Engine cross-check (gemm_q8_0, dyadic K=1024 N=96): PASS
  within half an F16 ULP of the engine F16 output at every
  output. Development note: an exact-equality assertion
  failed once at magnitude ~308 (F16 ULP 0.25) — comparator
  artifact (engine output rounding), verdict class filed in
  the bench doc; the bound was corrected, not the kernel.
- Known value: -4 exact. Rejection (zero rows / cols=48 /
  oversize / bogus id): PASS. Dispatch evidence: shim counter
  +2 for 2 dispatches, no leak: PASS.

## Suite (counts READ FROM LOGS)
- Standalone probe (hidden_files/a056_probe.log): all 5 cases
  PASS, PROBE_EXIT=0.
- Full suite run 1 (hidden_files/a056_run_all_run1.log):
  446 passed / 2 failed / 2 skipped / 450 total — second
  failure resilience.state_vault_rejects_growth, the
  documented contention flake (same case flaked in the
  A-054 seat gate run 1 and was exact on re-run there).
- Full suite re-run (hidden_files/a056_run_all.log):
  447 passed / 1 failed / 2 skipped / 450 total == baseline
  at b62b1481 (442/1/2/445) + 5 new cases, all passing.
  Sole failure pre-existing gguf.tensor_directory_interface
  (J-022 drift); skips the 2 pre-declared.

## A-055 follow-up (recorded, not blocking)
A-055 SPIR-V build pipeline (team-04) was not available:
no commit/file/pipeline in any worktree or the seat at build
time. A-056 used the banked A-015/A-013 precedent. Follow-up:
when A-055 banks, regenerate the embedded SPIR-V through its
pipeline and confirm the hash matches
 af3a2f037eff04e192cb9477debbcab14bcebb9354874dcec8e8b337b47ce302
(or re-file the hash if the pipeline's flags differ).
