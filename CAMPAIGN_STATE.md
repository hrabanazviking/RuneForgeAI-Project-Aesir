# CAMPAIGN_STATE - team-27 (Aesir Z13 forge)

- Team: team-27 (1 lead + 6 Mythic Engineering sub-agents)
- Worktree: /home/volmarr/aesir-team-27, branch yrsa/aesir-team-27
- Base: 1a611172 (banked main, 99 of 216, A-099 closure;
  seat == ls-remote verified at muster 2026-11-13 ~15:53 EST)
- Previous slice: A-097 BANKED (seat log carries 164c7aab
  A-097 + closure 5b0ce5b1, verified from git on disk).
- Assigned slice: A-100 - Placement planner (Wave 12
  opener, Heterogeneous scheduling). Per-op device
  assignment driven by the measured cost tables from
  Parts III-IV. Acceptance: planner decisions on standard
  fixtures match the measured optima.
- Suite baseline on this base: 607 passed / 1 failed /
  2 skipped / 610 total; sole failure pre-existing
  gguf.tensor_directory_interface (J-022 drift); known
  intermittents: resilience.state_vault_rejects_growth,
  gpu.amd_hip_stream_async_round_trip,
  gguf.weight_residency_gpu_visibility,
  memory.budget_live_meminfo_pressure.
- Build and commit on the team branch only; the keeper
  banks in roadmap order. Never merge or push. Never
  touch README.md. No Docker, ever.

## Team-27 outcome 2026-11-13 - A-100 DONE (PASS)
- 6 Mythic Engineering sub-agents mustered, no rate limit.
- Built core/placement_planner.mojo: measured tables as
  data (A-094 GEMM sweep + 93.0 us floor, A-098 power
  table, A-097 sampler rows, all verbatim and pinned by
  test); plan_op() per op kind + shape + flags; GPU the
  default optimum (A-098), NPU for power-capped (A-098)
  and overlapped (A-096) prefill with the A-099 CPU
  fallback named, CPU below the floor and for NOT FIT
  classes (A-094/A-097), A-017 policy delegate for
  unmeasured kinds; HIP probe-only never placed (A-086);
  unproven NPU never placed (A-017 honesty).
- Wired into doctor (fixture lines + JSON summary) beside
  the placement-policy section.
- Acceptance: 12/12 standard fixtures at their measured
  optima — standalone check spikes/a100_planner/
  check.mojo (hidden_files/a100/check.log) and 6 suite
  cases planner.* all PASS.
- Suite E-MASTER: 612 passed / 2 failed / 2 skipped /
  616 total (pin re-pinned 610 -> 616, +6 planner cases),
  read from hidden_files/a100_run_all.log. Failures:
  pre-existing J-022 + named intermittent
  resilience.state_vault_rejects_growth, which PASSED
  its solo re-run (hidden_files/a100/
  rerun_state_vault.log) — green-to-baseline. Suite ran
  solo (ps-verified against teams 25/26 suites).
- Evidence: docs/bench/A100_PLACEMENT_PLANNER.md;
  ledger hidden_files/A100_LEDGER.md; logs
  hidden_files/a100_run_all.log, hidden_files/a100/.
- Commit: this slice's commit on yrsa/aesir-team-27,
  subject "A-100: Placement planner" (hash = branch HEAD
  at banking, reported to the keeper with this state).
  Never merged or pushed from this worktree.
- Next work (recorded, not started): A-101 should consume
  plan_op for its prefill/decode split; A-107 pins these
  fixtures as the regression battery; A-108 judges
  default-on. No bug discovered in-slice left unfixed.
