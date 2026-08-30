# Task: Project Consistency Reconciliation

## Target

Restore repository-wide agreement between Project A.E.S.I.R.'s executable
behavior, capability claims, contributor workflow, documentation, tracked
artifacts, and verification automation.

## Why It Matters

Project A.E.S.I.R. treats executable evidence and the canonical capability
ledger as the source of truth. The current `main` branch passes its counted
proving suite, but several active documents, paths, counts, workflow rules, and
tracked assets contradict the checked-in repository state. Those contradictions
make onboarding unreliable and permit the documentation drift check to pass
while material drift remains.

## Owning Domains

- project operations and continuous integration
- documentation and contributor workflow
- tests and evidence reporting
- repository and release hygiene
- affected runtime domains only where verification reveals a concrete defect

## Current Evidence

- `main` at `c1d02d1919dc8c98971507b80ddb46a5a24af37f` passes the
  master suite with 132 passed, 0 failed, 1 skipped, and 133 total cases.
- `CAPABILITY_LEDGER.md` still states 107 passed, 0 failed, 1 skipped, and 108
  total cases.
- `.github/workflows/ci.yml` is tracked while `AES-FND-005` and Stage 11 still
  describe CI as missing.
- `AGENT_ONBOARDING.md` and `ENGINEERING_DOCTRINE.md` require
  `TASK_QUEUE.md`, a root `DOMAIN_MAP.md`, and a `development` branch, none of
  which exists in the current remote branch topology or root file set.
- Root image files duplicate tracked files under `docs/assets/images/` despite
  a completed repository-cleanup claim.
- The master suite emits unused-assignment warnings in
  `tests/test_new_paradigms_suite.mojo` and `core/npu_gate.mojo`.
- `python3 scripts/check_doc_drift.py` passes without detecting these conflicts.
- The latest commit message is `10`, which does not follow the documented
  commit-message format, and the commit changed runtime and test behavior
  without a matching current DEVLOG or capability-ledger reconciliation.

## Desired End State

- Active contributor instructions reference paths and branches that actually
  exist and define one unambiguous workflow.
- The capability ledger, TODO, README, architecture/interface documents, and
  DEVLOG describe the same evidence-backed repository state.
- Counted test evidence is derived or mechanically validated so it cannot drift
  silently.
- CI is described according to what its workflow really executes, including
  explicit evidence boundaries for hardware and external fixtures.
- Duplicate generated or presentation assets are removed from the root only
  after verifying canonical copies and references.
- Compiler warnings found by the baseline suite are corrected without changing
  behavior.
- Consistency automation detects the repaired classes of drift.
- The full proving suite, clean Mojo build, documentation checks, repository
  scans, and relevant negative controls pass from a clean working tree.

## Invariants to Preserve

- no fabricated external capability or hardware claim
- no silent promotion from `missing`, `scaffold`, `simulated`, or `partial` to
  `verified`
- no model weights, secrets, machine-specific paths, or generated binaries
  added to version control
- no public runtime interface change unless a verified defect requires it
- no removal of unique source, legal, attribution, or historical material
- AGPL-3.0, NOTICE, and third-party attribution remain intact
- one responsibility per function and existing domain boundaries remain intact
- unsupported paths continue to fail closed

## Boundaries

- Do not claim physical accelerator execution without a reproducible physical
  hardware gate.
- Do not claim external model-format, API-client, or ecosystem parity from
  synthetic fixtures.
- Do not rewrite unrelated vision or philosophy material.
- Do not modify Git configuration.
- Do not commit the local `aesir_engine/model.gguf` fixture or build/cache output.

## Planned Work

1. Inventory tracked files, active documents, branches, workflow commands,
   source warnings, evidence counts, and duplicate assets.
2. Classify every discovered contradiction against the canonical ledger status
   vocabulary and record any newly identified gaps.
3. Repair contributor workflow and path references without inventing a branch
   that the remote repository does not use.
4. Reconcile CI, capability-ledger evidence, TODO state, current DEVLOG, and
   active architecture/interface claims with executable behavior.
5. Remove only byte-identical root asset duplicates whose canonical copies and
   references are verified under `docs/assets/images/`.
6. Correct compiler warnings and other concrete source/test defects found by
   the audit using additive, behavior-preserving changes.
7. Extend consistency automation so the repaired contradictions fail closed in
   future changes.
8. Run the full verification matrix, update this task with final evidence, and
   preserve the results in the DEVLOG and capability ledger.

## Verification Plan

- `pixi run mojo run tests/run_all.mojo`
- deliberate negative-control run for counted fail-closed reporting
- `pixi run mojo build main.mojo -o <temporary-path>`
- `python3 scripts/check_doc_drift.py`
- CI workflow syntax and command inspection
- tracked-artifact, absolute-path, secret, binary, and duplicate scans
- interface/import/reference consistency scans
- `git diff --check`
- clean-tree confirmation after the final commit

## Role Sequence

1. **Cartographer** — map current repository truth and contradictions.
2. **Auditor** — prove each issue and define its evidence boundary.
3. **Architect** — resolve workflow, ownership, and consistency rules.
4. **Forge Worker** — implement the approved repairs.
5. **Auditor** — run the complete verification matrix.
6. **Scribe** — synchronize ledger, TODO, DEVLOG, task record, and handoff.

## Approval

Volmarr authorized the full consistency and Mythic Engineering compliance pass
on August 28, 2026 with the instruction: "fix all issues you find and make sure
everything is consistent and complies with Mythic Engineering standards."

## Implementation Result — August 29, 2026

- Contributor workflow now uses the existing `TODO.md`, `docs/DOMAIN_MAP.md`,
  and `main` integration target consistently.
- External-operation facades fail closed instead of reporting simulated hardware,
  persistence, model output, network transport, or format parsing.
- Capability/TODO/interface/architecture language now distinguishes verified
  local primitives from partial, scaffolded, simulated, missing, and target work.
- CI now runs the native build, 133-case counted suite, intentional negative
  control, and repository consistency validator.
- `scripts/check_doc_drift.py` now mechanically validates ledger population and
  summary counts, master registration/skip/expected totals, unique test names,
  required CI gates, local absolute paths, obsolete workflow references,
  fabricated-output signatures, fail-closed hardware counts, and tracked
  artifact hygiene.
- Final local verification passed: build; **132 passed / 0 failed / 1 skipped /
  total 133**; intended negative control **0/1/0/1** with nonzero exit;
  consistency check; Python syntax check; and `git diff --check`.
- Hosted GitHub Actions run `33239432026` passed the clean checkout, counted
  master suite, native build, deliberate negative control, and repository
  consistency check after the Pixi bootstrap was updated for the version-7
  lockfile.
- One approval-gated item remains: seven tracked executables, the 24-byte
  placeholder `aesir_engine/model.gguf`, and 24 byte-identical root images are
  inventoried but not removed. `AES-FND-007` remains `partial` until the
  maintainer explicitly approves deletion.
