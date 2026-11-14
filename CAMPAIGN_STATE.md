# CAMPAIGN_STATE — team-26 (purpleraider)

- Team: team-26, branch yrsa/aesir-team-26,
  worktree /home/volmarr/aesir-team-26.
- Base: 881f5025 (banked main = A-121 closure,
  121 of 216). Prior slice A-120 banked as 28efda7b
  + closure 130bddd0 (verified in seat log).
- Assignment: A-123 — Sliding-window attention
  parity (Wave 14). Acceptance: rows judged at
  window-boundary lengths specifically.

## Outcome

- Built core/sliding_window_battery_a123.mojo +
  tests (13 E-MASTER cases sliding.battery_*) +
  bench driver, following the banked A-121 slice
  pattern.
- Battery: 72 rows (windows 16/512/4096 x boundary
  lengths W-1, W, W+1, 2W-1, 2W, 2W+1 x 4 backends).
  CPU rows execute the banked flash_attention_gqa
  kernel vs an independent in-module scalar
  reference: FAITHFUL 18, all at max_diff 0;
  NOT_GRADED 54 (no CPU comparator for non-cpu
  backends); policy owed 72 (Q4_K_M, A-115 by call).
  Seeded defects discriminated: off-by-one and
  window-ignored both DIVERGENT on the fixture.
  Digest 14784864525343607696, MOJO_EXIT=0
  (hidden_files/a123_battery.log).
- Suite: four solo E-MASTER runs, pin 814 -> 827:
  a123_run_all.log 823/2/2, a123_run_all_rerun.log
  822/3/2, a123_run_all_rerun2.log 823/2/2,
  a123_run_all_rerun3.log 823/2/2 (passed/failed/
  skipped of 827). Sole non-intermittent failure in
  every run: the pre-existing J-022
  gguf.tensor_directory_interface. Named intermittents:
  gpu.amd_hip_stream_async_round_trip failed run 2
  only and cleared; resilience.state_vault_rejects_
  growth failed in-suite in all four runs but passes
  3/3 in isolation (hidden_files/a123_vault_solo.log,
  the A-113 solo-driver pattern; a timing-race TOCTOU
  test, pre-existing, in code this slice does not
  touch -- recorded here as the standing intermittent
  it is, not cleared in-suite this tick). All 13
  sliding.battery_* cases PASS in every run. Two
  discarded attempts kept: a123_run_all_concurrent_
  discarded.log (first launch killed within a minute
  when a team-27 suite appeared; re-run solo) and
  a123_run_all_parsefail_discarded.log (see defect 2).
- Defect 2 fixed in-slice (found by the first solo
  suite run): the new test file imported
  battery_backends, but the core module exports
  sw_backends -- the whole suite failed to parse.
  Fixed by aligning the test import and its two call
  sites to sw_backends (core and bench untouched,
  battery digest unchanged; test sha256 updated in
  hidden_files/A123_LEDGER.md).
- Defect fixed in-slice: float-literal cast compile
  error in the new fixture code (Float32(...)
  .cast[f16]()). No engine bug discovered; no
  DIVERGENT engine row, A-116 not required.
- Not merged or pushed to main: keeper banks A-123
  after A-122 in roadmap order. README untouched.
