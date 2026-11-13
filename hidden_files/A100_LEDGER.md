# A-100 Ledger — Placement planner (team-27)

- Slice: A-100 — Placement planner (Wave 12 opener,
  Heterogeneous scheduling). Roadmap: Per-op device
  assignment driven by the measured cost tables from
  Parts III–IV, not by hand-waving. Acceptance: planner
  decisions on standard fixtures match the measured optima.
- Team: team-27 (1 lead + 6 Mythic Engineering sub-agents,
  all mustered, no rate limit). Worktree:
  /home/volmarr/aesir-team-27, branch yrsa/aesir-team-27.
- Base: 1a611172 (banked main, 99 of 216, A-099 closure;
  ls-remote verified equal at muster). Branch reset --hard
  onto the base before building; A-097 banked status
  verified in the seat log (164c7aab + closure 5b0ce5b1).
- Verdict: PASS — 12/12 standard fixtures at their
  measured optima (standalone check + 6 suite cases).

## Built
- aesir_engine/core/placement_planner.mojo — pure planner
  over the backend registry. Measured tables encoded as
  data: npu_gemm_latency_table() (A-094, 7 rows verbatim),
  prefill_power_table() (A-098, 3 rows verbatim),
  sampler_latency_table() (A-097, 2 rows verbatim);
  constants for the A-094 floor (93.0 us), the A-095 band
  (M >= 64, >= ~0.1M MACs). plan_op() decides per op kind
  + shape + flags (overlap_available, power_capped);
  NPU decisions carry the A-099 CPU fallback; kinds with
  no measured row delegate to the A-017 policy.
- aesir_engine/tests/test_placement_planner_a100.mojo —
  6 cases: standard_fixtures (12 fixtures vs measured
  optima), prefill_variants, gemm_thresholds,
  decode_and_sampling, honesty_and_fallback (unproven NPU
  never placed; HIP probe-only never returned; empty
  registry fails closed), cost_tables_and_lines (filed
  numbers pinned verbatim; doctor lines deterministic).
- run_all.mojo: +6 planner.* cases; finish pin re-pinned
  honestly 610 -> 616 with the re-pin comment.
- aesir_engine/cli/doctor.mojo: planner fixture lines in
  the text rendering + planner_summary() in the JSON,
  beside the existing placement-policy section.
- spikes/a100_planner/check.mojo — standalone fixture
  check: A100_CHECK 12/12 (hidden_files/a100/check.log).
- docs/bench/A100_PLACEMENT_PLANNER.md — verdict doc.

## Suite (E-MASTER, solo, this worktree)
- hidden_files/a100_run_all.log via
  hidden_files/run_a100_suite.sh (seat-gate shape, gfx1151),
  launched only after ps showed no other suite (team-25's
  A-101 suite finished first; team-26's started after mine
  ended). Counts read from the log: 612 passed / 2 failed
  / 2 skipped / 616 total.
- Failure 1: gguf.tensor_directory_interface — pre-existing
  J-022, the baseline's sole standing failure.
- Failure 2: resilience.state_vault_rejects_growth —
  named pre-existing intermittent; solo re-run
  (spikes/a100_planner/rerun_state_vault.mojo) PASSED
  (hidden_files/a100/rerun_state_vault.log). Green-to-
  baseline per the standing rule.
- All 6 planner.* cases PASS in-suite.

## Honesty bounds
- No new device execution is claimed: the planner decides
  and logs; every number is a banked measurement from
  A-094/A-096/A-097/A-098, encoded verbatim and pinned by
  the cost-table test case. A-094's CPU column remains
  the naive oracle, named as such; A-098's optimized-CPU
  row grounds the prefill optimum. Latency estimates are
  shape-exact or -1 (unknown), never interpolated.
- NPU placement requires the proven-path context
  (A-095); XRT presence alone never places (A-017).
  HIP is probe-only and never a planner backend (A-086).

## Process notes
- One bench-doc transfer chunk failed base64 padding on
  first send; re-split smaller and landed sha256-clean.
  All four authored files verified by sha256 on-device
  against the authored originals before decompression.
- Keeper banks in roadmap order after A-101/A-102 etc.
  per WAVE_PLAN; this worktree never merges or pushes.
