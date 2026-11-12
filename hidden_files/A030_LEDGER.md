# A-030 Ledger — CPU performance baseline (team-07)

- Slice: A-030 — CPU performance baseline (Wave 4). Roadmap:
  docs/AESIR_Z13_MASSIVE_ROADMAP.md. Acceptance: baseline table
  filed from on-device logs.
- Machine: purpleraider (ASUS ROG Flow Z13, Strix Halo), kernel
  7.3.0-10-generic. CPU execution only; gfx1151 is compile target
  only, no accelerator execution claimed.
- Worktree: /home/volmarr/aesir-team-07, branch yrsa/aesir-team-07,
  base 05f61cd6 (A-028 banked; 28 of 216). Mojo 1.2.0 (2016d0cd),
  pixi run --frozen. Previous lead's partial transfer in /tmp/a030q
  was NOT resumed (base64 re-emission corruption); the bench driver
  was authored directly on-device in this worktree.

## Fixture
- stories260K.F16.gguf copied from team-04's verified fixture into
  hidden_files/fixtures/; sha256 verified in team-07:
  57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3
  — exact match to the pinned A-004 / Capability Ledger hash.

## Bench (hidden_files/a030_bench.log, sha256 4bc87fd3...e750aae6)
- Driver aesir_engine/tests/bench_cpu_baseline_a030.mojo, sha256
  765978678a5bcc2cae6b67cd53cb75d56143ee0a69d90bfc185ac9da5dc3aac2
  (standalone; run_all pin untouched). CLOCK_MONOTONIC ns around
  forward loops only; 1 settle + 5 trials; median reported.
- Conditions: quiet window 2026-11-12T05:48-05:49 EST, load
  0.59/0.93/1.44 at start, 0.20/0.55/1.15 at end, zero competing
  mojo/pytest processes (hidden_files/a030_conditions.log). An
  earlier contended window was rejected, not measured.
- Oracle checks all exact: prompt IDs, first token 265, 32 greedy
  decode IDs, facade IDs; batched vs per-token 64-prefill parity
  (last token 416 == 416). A030_BENCH: PASS, MOJO_EXIT=0.

| Config | Median tok/s |
|---|---|
| Prefill 8 per-token | 10,962.7 |
| Prefill 64 per-token | 9,107.0 |
| Prefill 64 batched | 16,334.5 |
| Decode 32 greedy | 8,745.9 |
| Facade generate_tokens e2e | 8,236.6 |

- Filed table: docs/bench/A030_CPU_BASELINE.md.

## E-MASTER suite
- PENDING — filled from hidden_files/a030_run_all.log below.
- Log: hidden_files/a030_run_all.log, sha256
  7f043237f83ebea0ef591a4e6dc8197575f6c6ce311ac32717351af167aa2219.
  Seat-gate shape: all 6 shims staged incl. libaesir_aff, target
  gfx1151 (hidden_files/run_a030_suite.sh).
- Counts (read from log): Passed 356 / Failed 1 / Skipped 2 /
  Total 359 — exactly the expected base shape. Sole failure:
  gguf.tensor_directory_interface ("tensor directory admission
  differs for rank 3"), the pre-existing J-022 drift, roads
  A-165/A-121 — not introduced by A-030. Skips = the 2
  pre-declared. No rotating extra failure; no re-run needed.
- MOJO_EXIT=1 is the suite's normal exit with the one known
  failure present (same as prior seat gates).

## Verdict
- A-030 acceptance: PASS — baseline table filed from on-device
  logs (docs/bench/A030_CPU_BASELINE.md), oracle-exact, quiet
  machine. No new bug discovered; the bench driver's only defect
  (missing std.ffi external_call import) was fixed in-slice
  before the measured run.
