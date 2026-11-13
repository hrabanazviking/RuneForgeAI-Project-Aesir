# A-080 — Equivalence gate (GPU<->CPU, scripted into the fast battery)

Roadmap: "GPU<->CPU output equivalence scripted into the fast battery
(A-035). Acceptance: gate runs in the fast tier and blocks banking on
regression (keeper enforces)."

## What was built

- `aesir_engine/core/equivalence_gate.mojo` — the gate verdict layer.
  Adds NO new grading law: every per-position verdict delegates to
  the A-078 classifier (`core/gpu_fuzz.fuzz_classify`) on the A-045
  parity band. It adds only battery aggregation (`EquivBattery`) and
  the banking decision: **pass <=> real == 0 AND invalid == 0 AND
  total > 0** (an empty battery never passes — no evidence is not
  equivalence).
- `aesir_engine/tests/test_equivalence_gate_a080.mojo` — 6 E-MASTER
  cases (`equivalence.*`), registered in `run_all.mojo`, pin
  568 -> 574: classifier table through the gate wrapper; battery
  aggregation over a 32-case synthetic perturbed-row battery
  (labelled synthetic — machinery proof, not a device claim);
  NEGATIVE control (an injected genuine divergence, an invalid row,
  and an empty battery must each flip the gate to FAIL — the
  in-suite blocking proof); script-contract case (reads the gate
  scripts from disk and pins the fast-tier wiring, so unwiring the
  gate fails the suite); device sampling parity (VulkanSampling
  greedy, 12 seeded rows, token-exact vs CPU, dispatch-counter
  delta == case count); device real-model parity (A-067 path, 3
  seeded RAW prompts, teacher-forcing verdicts through the gate
  battery).
- `aesir_engine/a080_driver.mojo` — standalone driver running
  exactly those 6 cases; prints `A080_DRIVER_ALL_PASS`.
- `scripts/gate_equivalence.sh` — the equivalence gate: stages the
  6 canonical shims, runs the driver under gfx1151, judges the log
  strictly (pass line present, `EQUIV_REAL ... real=0 invalid=0`,
  exit 0). Any real divergence raises inside the driver, so no pass
  line is printed and the gate exits 1. `--verify-blocking` feeds
  the judge a synthetic clean log and a synthetic regression log
  and requires PASS then FAIL.
- `scripts/gate_fast.sh` — A-035 fast gate extended: after the
  suite strict judge, it runs `scripts/gate_equivalence.sh`; an
  equivalence failure fails the fast gate, and the 600 s budget is
  re-checked across the whole gate including the equivalence step.

## Grading law applied (standing, unchanged)

Teacher-forcing rank + logit gap on RAW token sequences only, never
template-rendered prompts; CPU engine vs CPU comparator for the
oracle side; near-tie band rank <= 2 with sub-logit gap = faithful;
IQ graded on coherence, never token-exactness; comparator artifacts
(template, BOS, backend mismatch, prompt-boundary step-0) are a
verdict class checked BEFORE any real-defect verdict.
Device-execution evidence (law 6): the RADV STRIX_HALO identity
check (vendor 0x1002, non-software device type, RADV name) refuses
llvmpipe; sampling dispatches are counted. On a host without that
device or the A-067 fixture, the device sections report
honest-absent and claim nothing; on purpleraider both run real.

## Blocking, stated plainly

Three independent blocks, any one stops banking on a regression:
(1) the in-suite negative control proves the verdict layer flips to
FAIL on a real divergence; (2) `gate_equivalence.sh` exits 1 unless
the driver passes with real=0 (its `--verify-blocking` self-check
proves the judge rejects a regression log); (3) `gate_fast.sh`
propagates that failure, and the keeper enforces the same block at
the banking seat.
