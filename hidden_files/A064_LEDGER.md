# A-064 Ledger — GPU weight residency (team-04)

- Slice: A-064 — GPU weight residency (Wave 8 opener)
- Worktree: /home/volmarr/aesir-team-04, branch yrsa/aesir-team-04
- Base: 3d89b1e8 (seat main, 62 of 216 banked)
- Status: BUILT + GATED + COMMITTED — awaiting keeper banking in roadmap order. Do NOT merge or push from this worktree.

## Deliverable
- aesir_engine/core/gpu_weight_residency.mojo (new, 118 lines): GpuWeightResidency gateway over the A-014 VulkanBuffers gateway. resident_allocate() creates ONE Vulkan allocation per weight tensor in the unified pool; accounting() snapshots live_bytes/live_count/copy_call_count; is_unified_type() requires DEVICE_LOCAL|HOST_VISIBLE|HOST_COHERENT; single_residency_delta() and unchanged() are the measured residency proofs. Fail-closed: unavailable Vulkan raises, non-positive sizes raise VAL-003 before allocation, nothing simulated.
- aesir_engine/tests/test_gpu_weight_residency_a064.mojo (new, 308 lines): 5 cases (single, no_reupload, cpu_shared, multi_tensor, rejection).
- aesir_engine/tests/run_all.mojo: +5 cases wired; ledger.finish re-pinned 485 -> 490 honestly (A-063 built in parallel on same base; union reconciles at banking).

## Residency accounting evidence (READ FROM hidden_files/a064_gate.log)
- A064_SINGLE weight_bytes=4352 alloc_size=4352 type_flags=7 live_delta=4352 upload_calls=0 — exactly one allocation of exactly the weight size; type_flags 7 = DEVICE_LOCAL(0x1)+HOST_VISIBLE(0x2)+HOST_COHERENT(0x4), the unified type: host map and device buffer are one residency.
- A064_REPEAT runs=3 dispatch_delta=3 accounting_unchanged=true oracle_worst_max_abs=5.72e-06 — three repeated GEMV dispatches against the same allocation advanced the dispatch counter by 3 while live_bytes/live_count/upload_calls did not move: repeated runs do not re-upload.
- A064_SHARED cpu_write_visible_to_gpu=true uploads=0 max_abs=5.72e-06 — CPU writes through the host map are visible to GPU dispatch with zero upload calls (shared with the CPU path, extends A-020).
- Multi-tensor: exact-sum accounting, no leak on free. Rejection: zero/negative/undersized raise.
- Device-execution evidence: cases ran against the real RADV device on purpleraider (gfx1151) via the Vulkan shim — not simulated (fail-closed honest-absent path exists in the tests but was NOT taken; the PASS lines carry live accounting numbers).

## Gate (counts READ FROM LOG)
- hidden_files/a064_gate.log: 487 passed / 1 failed / 2 skipped / 490 total.
- Sole failure: gguf.tensor_directory_interface (pre-existing J-022 drift, tolerated at seat baseline 482/1/2 of 485). Delta vs baseline = +5 passed, +0 failed, +0 skipped — exactly the five new A-064 cases, all PASS.
- Skips: the 2 pre-declared (vision.cuda_session_image_chat, rag.real_engine_integration).

## Bug found and fixed in scope
- hidden_files/run_a064.sh (previous lead, cancelled mid-build): shim staging wrote the shared libraries to "/libaesir_*.so" (filesystem root, empty staging variable) and passed -Xlinker "-L" with no directory, so Mojo JIT materialization failed with "Symbols not found: [aesir_vk_*, aesir_hip_*, aesir_zc_*, aesir_par_*, ...]". Fixed to the canonical run_a061.sh shape: staging=$(mktemp -d), libs staged as $staging/libaesir_*.so, -Xlinker "-L$staging", real exit codes recorded (stub/par/hip/vk/zc/aff cc and MOJO_EXIT). This was a runner staging failure, not a slice-logic verdict.
- Untracked partial aesir_engine/core/.gpu_weight_residency.mojo.musegadget-partial inspected: truncated at line 55 mid-function, superseded by the complete gpu_weight_residency.mojo — discarded.

## Open bugs carried (pre-existing, named homes — unchanged by this slice)
- Bug B1: gguf.weight_residency_gpu_visibility intermittent (A-022/A-020 line) — did NOT fire in this gate run.
- Bug B2: resilience.state_vault_rejects_growth intermittent (A-053 line).
- Bug A-046:B1: IQ4_NL GEMM shape gate — home A-059 line.
