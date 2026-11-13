# CAMPAIGN_STATE - team-26 (Aesir Z13 forge)

- Team: team-26 (1 lead + 6 Mythic Engineering sub-agents)
- Worktree: /home/volmarr/aesir-team-26, branch yrsa/aesir-team-26
- Base: ee1aa0a3 (banked main, 94 of 216, A-094 closure)
- Assigned slice: A-096 - NPU prefill-assist experiment. NPU computes a prefill chunk while the GPU decodes the previous token. Acceptance: overlap benefit measured on a mixed workload - or an honest negative verdict filed.
- Context: Wave 11 (NPU first light). Builds on banked A-092 (real NPU matmul proven), A-093 (NPU memory sharing), A-094 (candidate table: prefill projection GEMM M >= 64 is the FIT candidate; dispatch floor ~93 us warm) and A-095 (team-25, implementation in flight - coordinate; if A-095 has not landed, do preparatory/measurement-scaffolding work and file the dependency honestly). NPU tools run via sudo (RLIMIT_MEMLOCK wall from A-007; never change that limit yourself - it is Volmarr to rule on). Coordinate sudo NPU use with teams 25/27 so probes do not collide; never run a suite concurrently with a seat gate.
- Status: MUSTERED 2026-11-13 by the keeper (expansion to 27 teams COMPLETE with this seat). Build and commit on the team branch only; the keeper banks at the seat in roadmap order after A-095. Never merge or push from this worktree. Never touch README.md. No Docker, ever.
- Suite baseline on this base: 607 passed / 1 failed / 2 skipped / 610 total (seat gate A-094); sole failure pre-existing gguf.tensor_directory_interface (J-022 drift); skips the 2 pre-declared. Known intermittents (pre-existing): resilience.state_vault_rejects_growth, gpu.amd_hip_stream_async_round_trip, gguf.weight_residency_gpu_visibility - a suite showing only those plus J-022 is green-to-baseline; re-run once before treating any as new.
- Raw-oracle discipline for all correctness work; accelerator-visible is not accelerator-run - every accelerator claim needs device-execution evidence on the real XDNA 2 / gfx1151.

## Team-26 outcome 2026-11-13 - A-096 DONE (POSITIVE, measured)
- 6 Mythic Engineering sub-agents mustered, no rate limit.
- Verdict POSITIVE: NPU prefill (128x1024x1024, A-094 FIT
  shape) overlapped with GPU decode GEMV (Vulkan, Radeon
  8060S) -- median benefit 4,198/4,289/3,819 us over serial
  across 3 runs x 21 reps; overlap wall 4,000-4,111 us vs
  serial 7,916-8,310 us. Doc: docs/bench/
  A096_NPU_PREFILL_ASSIST.md; ledger hidden_files/
  A096_LEDGER.md; logs hidden_files/a096/a096_run{1,2,3}.log.
- Correctness: NPU exact vs CPU oracle (131,072 el, checksum
  2848816214485251074 == team-25 A-095 p128); GPU GEMV max
  err 0.000035. Device evidence in every run log.
- A-095 dependency filed honestly: NOT landed at run time
  (team-25 on 92-base, prep+measurements in flight); no
  duplication -- concurrency premise measured on banked
  A-092/A-094 artifacts; re-check end-to-end when A-095 banks.
- Suite E-MASTER: 607 passed / 1 failed / 2 skipped / 610 =
  baseline exactly; sole failure pre-existing J-022
  gguf.tensor_directory_interface. Log hidden_files/a096/
  a096_suite.log. Committed on team branch only; keeper banks
  after A-095 in roadmap order.

## Team-26 outcome 2026-11-13 - A-099 DONE (PASS)
- Slice: A-099 - NPU fallback contract (Wave 11 closer). Base 21044acf (96 of 216); A-097 banked at the seat during the build; keeper banks A-099 after A-098.
- Contract: NPUFailure taxonomy + npu_fallback_decision in core/npu_offload.mojo (every failure -> CPU, reason FALLBACK_<NAME>); executor fallback in npu_prefill_offload.cpp (stage-tracked exceptions, non-COMPLETED states, missing/corrupt artifacts, output mismatch all degrade; fallback output verified exact vs CPU oracle or fail-closed).
- Proven: Mojo check 8/8 failures + 4/4 dispatch fallbacks; runner fault cases all exit 0 with exact fallback output (DEVICE_ABSENT real via index-99 + genuine MEMLOCK wall, XCLBIN_LOAD_FAILED real x3, INSTR_LOAD_FAILED real, OUTPUT_MISMATCH real run with 1 corrupted element, KERNEL_RUN_FAILED/KERNEL_TIMEOUT contract-layer injection - honest limit filed in the ledger). Happy path unchanged: NPU exact, checksum 16383547698108786409 reproduced, no fallback.
- Found+fixed in-slice: post-run-start fault injection aborted on XRT run-object teardown; injection moved before run creation, re-proven exit 0.
- Suite E-MASTER: 607 passed / 1 failed / 2 skipped / 610 = baseline exact; sole failure pre-existing J-022. Log hidden_files/a099_run_all.log. Ledger hidden_files/A099_LEDGER.md.
- Committed on team branch only; never merged or pushed.
