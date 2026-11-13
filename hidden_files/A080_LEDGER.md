# A-080 Ledger — Equivalence gate (team-10, purpleraider, 2026-11-13)

Status: BUILT + TESTED + COMMITTED on yrsa/aesir-team-10, base
3cfc4370 (78 of 216 banked, verified from git ls-remote).
Awaiting banking by the keeper in roadmap order (A-079 first).
Do NOT merge or push from this worktree. Crew: lead solo (no
sub-agent spawn used; the device work is sequential by nature).

Roadmap: "GPU<->CPU output equivalence scripted into the fast
battery (A-035). Acceptance: gate runs in the fast tier and blocks
banking on regression (keeper enforces)."

## Deliverables (committed)

- `aesir_engine/core/equivalence_gate.mojo` — verdict layer:
  delegates every per-position verdict to A-078's fuzz_classify
  (A-045 parity band) + EquivBattery aggregation + the banking
  decision pass <=> real==0 AND invalid==0 AND total>0.
- `aesir_engine/tests/test_equivalence_gate_a080.mojo` — 6
  E-MASTER cases (equivalence.*), run_all pin 568 -> 574.
- `aesir_engine/a080_driver.mojo` — standalone driver, prints
  A080_DRIVER_ALL_PASS.
- `scripts/gate_equivalence.sh` — the equivalence gate (shim
  staging + driver + strict judge; --verify-blocking self-check).
- `scripts/gate_fast.sh` — A-035 fast gate extended to run the
  equivalence gate after the suite judge; failure fails the fast
  gate; 600 s budget re-checked across the whole gate.
- `docs/bench/A080_EQUIVALENCE_GATE.md` — acceptance doc.
- Run scripts (uncommitted, per A-078 precedent):
  hidden_files/run_a080_{driver,build,gatefast}.sh.

## Evidence (counts READ FROM LOG FILES)

- Compile: a080_build.log, BUILD_EXIT=0 (only pre-existing
  warnings).
- Blocking self-check: `scripts/gate_equivalence.sh
  --verify-blocking` -> "EQUIV VERIFY-BLOCKING: PASS (clean log
  passes, regression log blocked)".
- Equivalence gate standalone (a080_gate_equiv.log, driver log
  a080_driver.log sha256 06aab742b985bf71e526b1506bc57405214451
  f83d9447d6fd7a6a00d89fdc51): GATE_EQUIV RESULT: PASS (21 s).
  EQUIV_SYNTH total=32 faithful=28 near_tie=4 real=0 invalid=0;
  EQUIV_SAMPLE absent=0 cases=12 token-exact vs CPU, dispatches
  12 (device-execution evidence, RADV STRIX_HALO identity check
  inside the cases, llvmpipe refused); EQUIV_REAL absent=0
  positions=7 comparator=7 real=0 invalid=0 gate=PASS (random
  RAW prompts: every position is the filed prompt-boundary
  comparator class, top-1 agreeing — same verdict shape as
  A-078's REAL battery, 147/147 comparator).
- Fast gate end-to-end (a080_gate_fast.log + a080_run_all.log
  sha256 63393d4b61134b05b68ca3b0f575afdb78aa513c8f2753791af712
  e4a8a7b8ea): suite 570 passed / 2 failed / 2 skipped / 574
  total — pin exact (568 + 6 new), ALL 6 equivalence.* cases
  [CASE PASS] in-suite. Failures: (1) gguf.tensor_directory_
  interface, the tolerated J-022 drift; (2) memory.budget_live_
  meminfo_pressure — the PRE-EXISTING in-suite failure under
  team-03/keeper bisect (seat runs 4-12 on the A-079 tree,
  which contains no A-080 code, failed this same case; keeper
  note + preserved seat logs). NOT caused by this slice; the
  bisect is the named owner. gate_fast therefore filed FAIL on
  the suite judge and never reached its equivalence step in
  this run; the equivalence step itself is proven PASS by the
  standalone gate run above and by the in-suite cases.
- Attempt 1 of the fast gate (a080_gate_fast_attempt1_*):
  launched 06:31 on a verified-clear machine; team-03's
  instrumented bisect seat gate (run 13) started at 06:32, so
  the lead KILLED this team's run at 196 [CASE PASS] to leave
  the bisect uncontended, and re-ran in the next clear window
  (above). No result from attempt 1 is claimed.

## Verdict

PASS for the slice's acceptance: the equivalence gate runs in
the fast tier (wired into gate_fast.sh, contract-pinned in the
suite), runs green standalone in 21 s on the real device, and
blocks on regression at three independent points (in-suite
negative control, gate judge + --verify-blocking proof,
gate_fast propagation; keeper enforces at the seat). The one
non-tolerated suite failure is the pre-existing, bisect-owned
memory.budget_live_meminfo_pressure — recorded here and in
CAMPAIGN_STATE.md, not hidden, not fixed in this slice (its
fix belongs to the bisect, which must name the holding case
first). Expect a run_all pin union at banking: seat pin after
A-079 will be 575 + 6 = 581 if A-079 banks first as expected.
