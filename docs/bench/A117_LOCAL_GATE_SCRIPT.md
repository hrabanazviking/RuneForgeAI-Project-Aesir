# A-117 - Local gate script

**Machine:** purpleraider (ASUS ROG Flow Z13, Ryzen AI Max+ 395, Radeon 8060S gfx1151, XDNA 2, 128 GB unified LPDDR5X)
**Base:** 57f2e2da (banked main, 114 of 216, A-114 closure)
**Gate question (roadmap):** "The whole matrix as one local command (no GitHub Actions - house law). Acceptance: script + timing filed; keeper can run it as the full-tier gate."

## The gate

`scripts/gate_local.sh` is the one local command:

    scripts/gate_local.sh

It runs, in order, each phase timed:

1. **Matrix** - the A-114 full matrix runner (`aesir_engine/tests/bench_matrix_a114.mojo`): 228 cells, a verdict per cell. Judged COMPLETE iff 228 `MX_CELL` lines, the summary counts sum to 228 and equal the A-114 filed account (faithful 4 / near_tie 2 / divergent 2 / artifact 2 / fixture_limited 9 / not_graded 209), and the driver exits 0.
2. **Suite** - E-MASTER (`aesir_engine/tests/run_all.mojo`) under the gfx1151 compile target with the seat staging shims (a compile target, not an execution claim). Judged GREEN-TO-BASELINE iff a `[SUMMARY]` exists, counts sum, skipped == 2 (pre-declared), and failed == 0 or the sole failure is `gguf.tensor_directory_interface` (J-022 drift).

Exit codes: 0 PASS, 1 FAIL, 2 REFUSED (another run_all / bench_matrix process already running - a full suite never runs concurrently with another team or a seat gate - or a staging failure). Logs land in `hidden_files/a117_gate_matrix.log`, `hidden_files/a117_gate_suite.log`, and the timed verdict in `hidden_files/a117_gate.log`.

The pass rule is encoded once in `aesir_engine/core/local_gate.mojo`; the bash judge mirrors it exactly and the 10 `gate.local_*` E-MASTER cases pin it, so the script and any keeper tooling cannot drift apart silently. Divergent and comparator-artifact cells are filed verdicts of the matrix, not gate failures; the gate fails on an incomplete or unexplained matrix and on any suite failure beyond the tolerated J-022 shape. The named intermittents are not tolerated in-log: the gate stays strict like `scripts/gate_full.sh`, and an intermittent is cleared by a solo re-run before banking.

Local and manual-only: no GitHub Actions, no CI, no network gate of any kind.

## Evidence (this Z13, 2026-11-13)

- Full gate run (`hidden_files/a117_gate.log`, `hidden_files/a117_gate_run.log`, GATE_EXIT=0): **GATE_LOCAL RESULT: PASS (239 s)**.
  - Matrix phase: rc=0, 228 cells, summary total=228 with the filed counts, digest 9653520459811539623 (identical to the A-114 filing). Script-reported elapsed 1 s; `/usr/bin/time -v` wall 0.47 s for the mojo invocation - the pure-enumeration driver on a warm Mojo compile cache; a cold-cache keeper run will take longer for this phase.
  - Suite phase: 734 passed / 1 failed / 2 skipped / 737 total = baseline 724/1/2/727 + 10 new `gate.local_*` cases, all PASS; sole failure the pre-existing J-022 `gguf.tensor_directory_interface`; no named intermittent fired. time -v wall 3:58.32 (238 s, compile included). The raw suite exits 1 on the tolerated failure; the gate judges the log itself, exactly as `gate_full.sh` does.
  - Timing: matrix 1 s + suite 238 s = total 239 s, filed in `hidden_files/a117_gate.log`.
- run_all finish pin 727 -> 737. CAPABILITY_LEDGER section 26 entry Z13-P5-117; E-MASTER count 727 -> 737.

## Honest scope

- A-115 (token-exactness policy, team-25) and A-116 (first-divergence localisation, team-26) were building in parallel and NOT banked at build time; this gate takes no dependency on either. Integration points are named in `core/local_gate.mojo` and the script header: A-115's policy can refine the suite judge per quant family when it banks; A-116 is the tool a keeper runs on a gate FAIL before filing a divergence.
- The gate executes the A-114 runner (pure enumeration over filed records - no model executed, no device opened) and the E-MASTER suite; it makes no accelerator-execution claim of its own.
