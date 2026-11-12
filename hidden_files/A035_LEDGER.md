# A-035 Ledger — Two-tier test gates (team-06, purpleraider, 2026-11-12)

Roadmap: "Fast gate (<10 min) and full battery, both one-command scripts
on the Z13. Acceptance: both run green on the CPU path; timings filed."

Base: seat main 37670c17 (A-032 banked; suite pin 368). Branch
yrsa/aesir-team-06. Host: purpleraider (ASUS ROG Flow Z13, Strix Halo).

## Deliverables (committed)

- `scripts/gate_fast.sh` — ONE command: the fast gate.
- `scripts/gate_full.sh` — ONE command: the full battery.
- `hidden_files/run_a035.sh` — the timed driver used for the runs below.
- This ledger.

Both gates reuse the repo's real E-MASTER suite
(`aesir_engine/tests/run_all.mojo`, staged with the 6 canonical shims:
hailo10h stub, par, hip, vulkan (merged context+buffer), zc, aff)
through the existing A-028 `scripts/build_matrix.sh` entries. No toy
suite, no subset, no new test cases; the run_all pin stays 368.

## The two tiers

- FAST (`scripts/gate_fast.sh`): build_matrix `cpu` entry — run_all
  with NO --target-accelerator flag; host code executes on CPU.
  The gate additionally enforces the <10 min budget (600 s) itself:
  a run at/over budget fails the gate.
- FULL (`scripts/gate_full.sh`): build_matrix `all` — the cpu entry
  PLUS the `amd` entry: engine (`aesir_engine/main.mojo`) built with
  the host AMD ROCm compile target gfx1151, a `--help` smoke, and
  run_all under gfx1151. Host code executes on CPU; gfx1151 is a
  compile target, not an execution claim. The suite's
  gpu.mojo_native_* cases may use a HIP device when present —
  inherited suite behaviour, NOT claimed by this gate. No other
  accelerator execution is claimed for either tier.

## Tolerance — encoded exactly, stated plainly

"Green" = the established baseline shape, and the gate scripts
enforce exactly this and nothing else (applied to every suite log):

- a [SUMMARY] block exists and passed+failed+skipped == total;
- skipped == 2 (the 2 pre-declared skips);
- failed == 0, OR failed == 1 whose sole [CASE FAIL] is
  `gguf.tensor_directory_interface` — the pre-existing J-022
  loader/test drift (roads A-165 primary / A-121).

Any other failure, any other skip count, a missing summary, a failed
engine build / --help smoke, or (fast tier) a budget overrun FAILS
the gate with exit 1. The raw suite exits 1 whenever any case fails,
including the tolerated one, so the gates judge the logs themselves;
build_matrix's own judge does not check the skip count — the strict
re-judge in the gate scripts adds that check.

## Timed runs on this machine (2026-11-12, from the logs)

| Run | Log | Wall | Result |
|---|---|---|---|
| gate_fast.sh (driver run) | a035_gate_fast.log | 89 s | PASS, exit 0 |
| gate_full.sh attempt 1 | a035_gate_full.log | 173 s | FAIL, exit 1 (flake, below) |
| build_matrix amd solo re-run | a035_amd_rerun.log | — | PASS, exit 0 |
| gate_full.sh run 2 | a035_gate_full_run2.log | 76 s | PASS, exit 0 |

Suite shape in every passing run: 365 passed / 1 failed / 2 skipped /
368 total; sole failure the tolerated J-022 case. Fast tier is far
under its 600 s budget in both cold-ish (89 s) and warm-cache
conditions. Full-battery wall varies with Mojo compile-cache warmth
(173 s cold incl. the failing attempt, 76 s warm) — both filed, not
cherry-picked. Suite logs kept per tier: a035_fast_suite.log,
a035_full_cpu_suite.log, a035_full_amd_suite.log (attempt 1),
a035_full2_cpu_suite.log, a035_full2_amd_suite.log (run 2).

## Flake found during A-035 (recorded, not hidden)

Attempt 1's amd entry showed a SECOND failure:
`gguf.weight_residency_gpu_visibility` — HipMemory
memcpy_device_to_host refused with MEM-004 USE_AFTER_FREE (A-022).
Evidence it is a flake, not a regression of this slice (A-035 changes
no engine code): the same case PASSES in the seat gate for the same
base (aesir-forge hidden_files/seat_gate_a032.log, gfx1151, 365/1/2),
in team-01's A-033 run, in the amd solo re-run, and in gate_full
run 2 — and it is in the area of team-06's already-recorded A-020
open bug (HIP host-registered mapping interop). Precedent class:
A-026's one-off resilience TOCTOU flake under load; other teams'
suites were running concurrently during attempt 1. The gate behaved
as designed: it refused to bank on an unexplained failure, and the
flake is filed here and in CAMPAIGN_STATE.md as known-open work.
Root-cause work belongs with the A-020 HIP-interop follow-up, not
inside A-035's scope (gate scripts only).

## Verdict

PASS. Both one-command scripts exist, both ran green on the CPU
path on purpleraider, timings filed above from actual timed runs.
