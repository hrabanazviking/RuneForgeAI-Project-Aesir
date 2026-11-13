# Team-12 CAMPAIGN_STATE — Aesir Z13 Forge

- Team: team-12 (NEW seat, expansion to 27 teams, Volmarr order 2026-11-13 ~05:59 EST)
- Mustered: 2026-11-13 ~06:47 EST by keeper tick aesir-z13-forge-keeper (scheduled 06:47)
- Worktree: /home/volmarr/aesir-team-12, branch yrsa/aesir-team-12
- Base: 3cfc43702ef1c3d96758d1f799a5946515ffadef = Banking closure: A-078 banked (78 of 216) — banked main, verified by git ls-remote at muster
- Assigned slice: A-082 — HIP Q8_0 GEMV. Via the A-010–A-012 gate. Acceptance: CPU-oracle parity + device-execution evidence.
- Rules: work ONE slice only in this worktree; never share a checkout; never merge or push from this worktree (keeper banks in roadmap order at the seat); never touch README.md; NO Docker.
- Banking order note: A-079, A-080, A-081 are ahead in roadmap order and are NOT yet banked (A-079 seat gate blocked by memory.budget_live_meminfo_pressure flake — bisect verdict filed in team-03; A-080 commit 2a1c2eec and A-081 commit 31d88a29 built and awaiting banking). A-082 builds in parallel; it banks only after them, in roadmap order. Expect a run_all pin union at banking.
- Correctness law: raw-oracle discipline (teacher-forcing rank + logit gap on RAW prompts, CPU vs CPU comparator only, near-tie rank <=2 sub-logit = faithful, IQ graded on coherence); comparator artifacts are a verdict class; accelerator-visible != accelerator-run — device-execution evidence required.
- Never leave a discovered bug unfixed: fix in-slice or record as immediate next work here.
- Coordination: defer full run_all suites while team-03's probe + budget-reorder work uses the shared machine solo; coordinate via keeper notes. Check /home/volmarr/aesir-forge/hidden_files/keeper_note_a079.md before heavy runs.
- Status at muster: worktree created clean from banked main at 06:51 EST, verified by git worktree list; lead spawn requested by keeper this tick.

## A-082 result (team-12 lead, 2026-11-13)
- Status: COMPLETE, committed locally (not pushed; keeper
  banks in roadmap order after A-079/A-080/A-081).
- Deliverables: core/hip_gemv.mojo (HipGemv gateway +
  Mojo-native HIP Q8_0 GEMV kernel via the A-010-A-012
  gate), hip_memory_shim.c dispatch-evidence counter,
  tests/test_hip_q8_gemv_a082.mojo (5 cases),
  tests/bench_hip_q8_gemv_a082.mojo,
  tests/probe_hip_q8_gemv_a082.mojo, run_all pin 568->573,
  docs/bench/A082_HIP_Q8_GEMV.md, hidden_files/A082_LEDGER.md.
- Parity: BIT-EXACT vs the sequential CPU oracle at all 6
  shapes (max_abs 0.0); engine cross-check within half an
  F16 ULP; known value -4 exact; rejection PASS.
- Device evidence: gate names exactly one device, "AMD
  Radeon 8060S Graphics", gfx1151; shim dispatch counter
  +2 for 2 in-suite, 123 in the bench run.
- Bench: (512,4096) HIP resident-loop 1.02 ms = 2.03 GiB/s
  vs CPU sequential 1.26 GiB/s; per-call HIP 16.93 ms is
  DeviceContext creation cost (measured, mitigated by
  q8_0_gemv_repeated); small shapes latency-bound (A-085
  bake-off inputs filed in the ledger).
- Suite (a082_run_all.log): 570 passed / 1 failed /
  2 skipped / 573 total; sole failure the pre-existing
  gguf.tensor_directory_interface J-022 drift; skips the
  2 pre-declared; memory.budget_live_meminfo_pressure
  PASSED this run. First staging attempt failed at JIT
  (missing libaesir_aff in my runner; fixed in-slice;
  run_all header has the same omission - doc-drift,
  recorded in the ledger for the keeper).
- Next work: none blocking for A-082. A-085 bake-off
  inputs filed in hidden_files/A082_LEDGER.md (HIP
  resident-loop numbers, small-shape latency floor,
  unprobed tiled/shared-memory kernel shapes).
