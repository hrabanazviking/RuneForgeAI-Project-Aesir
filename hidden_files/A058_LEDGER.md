# A-058 Ledger — Vulkan Q6_K + Q5_K GEMV (team-09)

- Slice: A-058 | Status: BUILT+TESTED+COMMITTED, awaiting keeper banking after A-055..A-057
- Base: 45ba57e6 (A-056 commit on seat b62b1481, 54 of 216, Wave 6 COMPLETE). Worktree was reset --hard onto 45ba57e6 after verifying A-050 banked in seat closure 9167a21f; prior untracked CAMPAIGN_STATE.md + hidden_files backed up to /tmp/t09-backup/.
- Host: purpleraider, AMD Radeon 8060S / RADV STRIX_HALO; llvmpipe refused by device identity check in every case.

## Changes
| File | Change |
|---|---|
| aesir_engine/shaders/q6_k_gemv.comp | new Q6_K GEMV kernel (210B blocks) |
| aesir_engine/shaders/q5_k_gemv.comp | new Q5_K GEMV kernel (176B blocks) |
| aesir_engine/vulkan_buffer_shim.c | embedded SPIR-V words for both kernels; vk_kquant_gemv dispatch body mirroring A-056; aesir_vk_buffer_q6_gemv / aesir_vk_buffer_q5_gemv + dispatch counters; A-056 entry untouched |
| aesir_engine/core/vulkan_gemv.mojo | VulkanGemv.q6_k_gemv / q5_k_gemv + q6/q5 dispatch_count, fail-closed validation |
| aesir_engine/tests/test_vulkan_q6k_q5k_gemv.mojo | 5 new cases |
| aesir_engine/tests/run_all.mojo | registrations gpu.vulkan_q6k_q5k_*; pin 450 -> 455 |
| docs/bench/A058_VULKAN_Q6K_Q5K_GEMV.md | filed results doc |

## Shader hashes (glslangValidator 16.4.0, purpleraider)
- q6_k_gemv.comp sha256 2a029dbf5fe6e94dc3b51bea5682e385c74ae2f53ffe20a138c2a108650a7a25; SPIR-V (7928 B) bf97687308c7e654e68e79949c28af1a7577753e89516f40443f11e6b45af15b
- q5_k_gemv.comp sha256 fcfa4ad4df123c53ac9329dc06a8ca9198e198580b9705eb153f4c5b15d6f52b; SPIR-V (9156 B) 5385b81611037a52c85a62cb779744a5fdde4862ce7f0026b4420f6d8f2fff5e

## Verification — counts from log only
- Log: hidden_files/a058_run_all.log sha256 7c1b721cc7e53807ae4ce176338c14a9158707ff6aeadc72e76b22d295dd5482 (script hidden_files/run_a058.sh)
- Result: 452 passed / 1 failed / 2 skipped / 455 total
- Baseline for this base (A-056): 447 / 1 / 2 of 450. Delta: +5 passed = exactly the new gpu.vulkan_q6k_q5k_* cases, all PASS. Sole failure: gguf.tensor_directory_interface (J-022 drift, tolerated pre-existing). Skips: 2 pre-declared. No other suite was running during the run (ps checked); no contention flake observed.
- Parity worst max_abs (sequential CPU oracle, identical raw bytes): Q6_K 6.10e-05, Q5_K 5.19e-04, filed bound 0.05. Per-shape lines A058_SHAPE in log.
- Known values exact: Q6_K -96 (repo known block), Q5_K 192 (constructed block). Engine crosscheck vs gemm_q6_k / gemm_q5_k_m within half F16 ULP. Dispatch counters +2 per format for 2 dispatches; buffer accounting exact.

## Verdict
- Faithful: GPU dequant+GEMV matches the CPU oracle and the engine CPU GEMV under the filed bounds on real device execution; divergence class: none (residual deltas are accumulation-order / F16-rounding comparator artifacts within filed bounds).
- Follow-up (not in scope): adopt the A-055 SPIR-V pipeline for these shaders when it banks (same follow-up A-056 recorded).
- Bugs found: GLSL reserved word half renamed to haf in q6 shader during build; no product bugs found. No README touched. No Docker.
