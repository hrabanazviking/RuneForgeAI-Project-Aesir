# Team-13 CAMPAIGN_STATE — Aesir Z13 Forge

- Team: team-13 (NEW seat, expansion to 27 teams, Volmarr order 2026-11-13 ~05:59 EST)
- Mustered: 2026-11-13 ~06:47 EST by keeper tick aesir-z13-forge-keeper (scheduled 06:47)
- Worktree: /home/volmarr/aesir-team-13, branch yrsa/aesir-team-13
- Base: 3cfc43702ef1c3d96758d1f799a5946515ffadef = Banking closure: A-078 banked (78 of 216) — banked main, verified by git ls-remote at muster
- Assigned slice: A-083 — HIP Q4_K GEMV. Acceptance: same discipline as A-082 (CPU-oracle parity + device-execution evidence, via the A-010–A-012 gate).
- Rules: work ONE slice only in this worktree; never share a checkout; never merge or push from this worktree (keeper banks in roadmap order at the seat); never touch README.md; NO Docker.
- Banking order note: A-079, A-080, A-081, A-082 are ahead in roadmap order and are NOT yet banked. A-083 builds in parallel; it banks only after them, in roadmap order. Expect a run_all pin union at banking.
- Correctness law: raw-oracle discipline (teacher-forcing rank + logit gap on RAW prompts, CPU vs CPU comparator only, near-tie rank <=2 sub-logit = faithful, IQ graded on coherence); comparator artifacts are a verdict class; accelerator-visible != accelerator-run — device-execution evidence required.
- Never leave a discovered bug unfixed: fix in-slice or record as immediate next work here.
- Coordination: defer full run_all suites while team-03's probe + budget-reorder work uses the shared machine solo; coordinate via keeper notes. Check /home/volmarr/aesir-forge/hidden_files/keeper_note_a079.md before heavy runs.
- Status at muster: worktree created clean from banked main at 06:51 EST, verified by git worktree list; lead spawn requested by keeper this tick.

## A-083 result - HIP Q4_K GEMV (counts READ FROM LOGS)
- Status: A-083 BUILT + TESTED + COMMITTED 2026-11-13 on yrsa/aesir-team-13, base 3cfc4370 (78 of 216 banked). Awaiting banking by the keeper after A-079..A-082 in roadmap order. Do NOT merge or push from this worktree.
- Deliverables: core/hip_q4k_gemv.mojo (HipQ4kGemv: Mojo-native Q4_K dequant+GEMV kernel via DeviceContext api="hip", in-kernel decode mirroring q4k_gemv.comp / CPU kind-12 oracle, f32 accumulation) + hip_memory_shim.c dispatch counter (increments only after synchronized device dispatch) + tests/test_hip_q4k_gemv_a083.mojo (3 cases) + tests/bench_hip_q4k_gemv_a083.mojo + a083_driver. run_all pin 568 -> 571.
- Device evidence: bench PASS on AMD Radeon 8060S Graphics (HIP device 0), counter +1/+3/+50 exact in every check; A-029 triangulation covers the launch path (no CPU fallback).
- Parity vs CPU oracle (dequantize kind 12 -> f16 -> f32 dot) at the A-057 f16-rounding band: max_abs_err 0.0729 (K=256), 0.0970 (512), 0.3298 (1024), 0.3865 (2048), 0.8352 (1024x4096) - all inside band floors 0.32/0.45/0.64/0.91/1.28.
- Timing (honest, end-to-end launcher incl. fresh context per call): small shapes context-bound ~2-7 ms; 1024x4096 HIP 6.99 ms vs CPU 7.65 ms. Kernel is one-thread-per-row; tuning + HIP-vs-Vulkan verdict = A-085.
- Suite (SOLO, ps-verified; hidden_files/a083_run_all.log sha256 c7435ce2...): 568 passed / 1 failed / 2 skipped / 571 total = baseline 565/1/2/568 + 3 new all PASS. Sole failure = pre-existing gguf.tensor_directory_interface J-022 drift. memory.budget_live_meminfo_pressure PASSED.
- DISCOVERED (probed + filed in A083_LEDGER.md): every buffer-bearing MAX DeviceContext retains exactly 8,388,608 B GTT until process exit on this toolchain (exact multiples over 120 calls + attribution probe incl. MojoNative.vec_add and bare buffer+copy contexts) - MAX runtime pool behaviour, pre-existing (A-029/A-079 family), NOT an A-083 operand leak. No-leak case asserts retention == exactly 50 x 8 MiB over 50 calls.
- IMMEDIATE NEXT WORK: (platform) persistent-context launcher or MAX pool-cap investigation to remove the per-call 8 MiB retention + context setup cost - joins team-03 fix road item 3; re-file the no-leak constant if the toolchain changes it.
