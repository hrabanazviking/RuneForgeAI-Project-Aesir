# A-059 Ledger - Vulkan IQ GEMV (team-01)

- Slice: A-059 | Status: BUILT+TESTED+COMMITTED, awaiting keeper banking after A-058
- Base: 5b172516 (banked main, 57 of 216, A-055..A-057 closure). Worktree was at fbece4ae (A-051); verified A-051 banked in seat closure 9167a21f, backed up untracked CAMPAIGN_STATE.md + hidden_files to /tmp/t01-backup/, reset --hard onto 5b172516. Untracked aesir_engine/hip_bridge.c left untracked and untouched, as every prior lead has.
- Team: lead + 6 Mythic Engineering sub-agents spawned first (no 429).
- Host: purpleraider, AMD Radeon 8060S / RADV STRIX_HALO; llvmpipe refused by device identity check in every case.

## Changes
| File | Change |
|---|---|
| aesir_engine/shaders/iq2_xxs_gemv.comp | new IQ2_XXS GEMV kernel (66B/256 blocks, grid SSBO) |
| aesir_engine/shaders/iq1_s_gemv.comp | new IQ1_S GEMV kernel (50B/256 blocks, grid SSBO) |
| aesir_engine/shaders/iq3_xxs_gemv.comp | new IQ3_XXS GEMV kernel (98B/256 blocks, grid SSBO) |
| aesir_engine/shaders/iq4_nl_gemv.comp | new IQ4_NL GEMV kernel (18B/32 blocks, cols % 32) |
| aesir_engine/vulkan_buffer_shim.c | embedded SPIR-V for the 4 kernels; aesir_vk_buffer_iq2xxs/iq1s/iq3xxs/iq4nl_gemv + dispatch counters, dispatch bodies mirroring A-056; A-056/A-057 entries untouched |
| aesir_engine/core/vulkan_gemv.mojo | VulkanGemv.iq2_xxs_gemv / iq1_s_gemv / iq3_xxs_gemv / iq4_nl_gemv + 4 dispatch counters, fail-closed validation |
| aesir_engine/tests/test_vulkan_iq_gemv.mojo | 5 new cases |
| aesir_engine/tests/run_all.mojo | registrations gpu.vulkan_iq_gemv_*; pin 458 -> 463 |
| docs/bench/A059_VULKAN_IQ_GEMV.md | filed results doc |

## Shader hashes (glslangValidator 16.4.0, purpleraider)
- iq2_xxs_gemv.comp sha256 621817b180b3a8da25636dbd822018b649cbfc3792843ad0d320e28afd25125c; SPIR-V (9356 B) d283ae140a143ef8bfdec76b36f4525ee215f8e8196d43ac761f14bee2cda4b0
- iq1_s_gemv.comp sha256 425b409fb4019702df7563f4811710dad9fa48b7202449a221834b1bf5c805e4; SPIR-V sha256 9f61dde4a19aee8d3bf65896fa63ab6df2cbfc9928cfbb10dde44f746453b2ae
- iq3_xxs_gemv.comp sha256 d6adfd4faf06a457c33f5fc28cef0d9197e028502593755ebde5fe5a963de5c0; SPIR-V sha256 f703d2ff47da795e08a8843de5ecfee0e402ec4a01a105271ad8e5a71c5690ab
- iq4_nl_gemv.comp sha256 32e6e2a5d084c4480dd0472a5d973fe3f1d20009266906ae21501850c29c12ef; SPIR-V sha256 1b8a4a45182d900456a7e2d9b830c21af97584305d258be564d335e7c6d5b0c0
- Embedded words re-extracted from the shim and sha256-verified identical to the compiled .spv for IQ2_XXS (the generator's first pass mis-pointed pCode at the Q8 array - caught by the first suite run's known-value case, fixed by replacing all occurrences, re-verified).

## Verification - counts from log only
- Log: hidden_files/a059_run_all.log sha256 1d5f65502856d7d9c4e541933bea79ace4c1d1a83dd143ef98d265bfe13ecca8 (script hidden_files/run_a059_suite.sh)
- Result: 460 passed / 1 failed / 2 skipped / 463 total. Baseline at 5b172516: 455/1/2/458. Delta +5 passed = exactly the new gpu.vulkan_iq_gemv_* cases, all PASS. Sole failure: gguf.tensor_directory_interface (J-022 drift, tolerated pre-existing). Skips: vision.cuda_session_image_chat + rag.real_engine_integration (2 pre-declared). No other suite was running (ps checked; only an unrelated python lab script).
- Parity worst max_abs 5.72e-05 (filed bound 0.05), per-shape A059_SHAPE lines in log. Known values exact (256 / -224 / 256 / 128, IQ4_NL K=288 = 144). Engine crosscheck within half F16 ULP, all 4 formats. Dispatch counters +2 per format in the evidence case; accounting exact.

## Bug A-046:B1 - precise landing
- GPU path (this slice): RESOLVED for GEMV - iq4_nl_gemv accepts cols % 32 == 0 (the format's own block), proven at K=32/288/512/1024/2048.
- CPU path: STILL OPEN - core/compute.mojo gemm_iq raises unless A.cols % 256 == 0 for all IQ kinds incl. kind 20 (IQ4_NL), so CPU IQ4_NL at K=288 still raises. Named home: the Wave 6 loader/format follow-up or a dedicated B1 fix slice; recorded in CAMPAIGN_STATE.md. Not left silent, not claimed fixed.

## Verdict
- Faithful under law 3 coherence-grade parity; divergence class: none beyond accumulation-order comparator artifacts within the filed bound.
- Follow-up (not in scope): adopt the A-055 SPIR-V pipeline for these shaders (same follow-up A-056/A-058 recorded); CPU B1 fix per above.
- No README touched. No Docker. No merge/push from this worktree.
