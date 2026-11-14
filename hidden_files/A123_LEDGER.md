# A-123 Ledger — Sliding-window attention parity (team-26)

- Base: 881f5025 (banked main, A-121 closure, 121 of 216).
  Worktree reset --hard onto base before building.
- Branch: yrsa/aesir-team-26. Worktree:
  /home/volmarr/aesir-team-26 (purpleraider).
- Roadmap: Wave 14, A-123. Acceptance: "rows judged
  at window-boundary lengths specifically."

## Built

- aesir_engine/core/sliding_window_battery_a123.mojo
  (sha256 a8740a65fea58837128d50ab764ae71cdbae786b013d99c5d68845d4b6d050b3)
- aesir_engine/tests/test_sliding_window_battery_a123.mojo
  (sha256 c7307a95950a751534677eaea3aa3fa65383747ffe1d79253abf4c395e92c66b)
- aesir_engine/tests/bench_sliding_window_battery_a123.mojo
  (sha256 5a38e82366af2bdc781718e5c9943bd3d20db364216b6a87fe3c79f4907b05a0)
- run_all.mojo: +13 cases (sliding.battery_*), pin
  814 -> 827 (ledger.finish(827)).
- CAPABILITY_LEDGER.md: E-MASTER phrase 812/814 ->
  825/827; section 26 entry Z13-P5-123 appended.
- docs/bench/A123_SLIDING_WINDOW_ATTENTION.md.

## Battery result (hidden_files/a123_battery.log, MOJO_EXIT=0)

- 72 rows: FAITHFUL 18 (all cpu, max_diff_x10000 = 0
  on every row), NOT_GRADED 54, DIVERGENT 0.
- Policy owed 72 / coherence 0 (Q4_K_M ->
  TOKEN_EXACTNESS_OWED via banked A-115 policy call).
- Synthetic: 4 total, faithful 1, divergent 2,
  artifact 1 (SYN_OFF_BY_ONE max_diff 3.4849,
  SYN_WINDOW_IGNORED max_diff 3.7456).
- Digest: 14784864525343607696.

## Suite result (E-MASTER, pin 814 -> 827, all runs solo)

- hidden_files/a123_run_all.log: 823 passed / 2 failed /
  2 skipped of 827. Failures: gguf.tensor_directory_
  interface (pre-existing J-022) + resilience.state_
  vault_rejects_growth (named intermittent).
- hidden_files/a123_run_all_rerun.log: 822/3/2 -- plus
  gpu.amd_hip_stream_async_round_trip (named intermittent).
- hidden_files/a123_run_all_rerun2.log: 823/2/2 (gpu
  intermittent cleared; vault intermittent still failing
  in-suite).
- hidden_files/a123_run_all_rerun3.log: 823/2/2, same.
- hidden_files/a123_vault_solo.log: the vault case passes
  3/3 in isolation via the A-113 solo driver (timing-race
  TOCTOU test; pre-existing; this slice touches no
  resilience code). Recorded as a standing intermittent
  that did not clear in-suite this tick.
- All 13 sliding.battery_* cases PASS in every run.
- Discarded: a123_run_all_concurrent_discarded.log
  (launch killed within a minute when a team-27 suite
  appeared) and a123_run_all_parsefail_discarded.log
  (defect 2 below).

## Defects found and fixed in-slice

- Test/core symbol mismatch (found by the first solo
  suite run): tests/test_sliding_window_battery_
  a123.mojo imported battery_backends; the core module
  exports sw_backends. The suite failed to parse
  (a123_run_all_parsefail_discarded.log). Fixed by
  aligning the test import + two call sites to
  sw_backends; core and bench files untouched, battery
  digest unchanged. Test sha256 above is post-fix.

- Compile: float-literal `.cast[f16]()` on (4.0) /
  (-4.0) literals in the boundary-probe fixture —
  Mojo parses these as FloatLiteral with no cast;
  fixed to Float32(4.0).cast[f16]() /
  Float32(-4.0).cast[f16](). No engine defect found;
  no DIVERGENT engine row filed, so A-116 was not
  needed.

## Notes

- No merge or push to main: the keeper banks A-123
  after A-122 in roadmap order.
- README.md untouched. No Docker used.
