# Task: Repository Artifact Prevention Gate

## Authorization

Volmarr instructed the project to continue after approving and merging the
Reality-First Completion Roadmap into `main`. This task implements the first
non-destructive Phase 0 guardrail slice. It does not authorize deletion of any
tracked file. The existing deletion approval remains limited to temporary files
and directories created by model-store tests.

## System Statement

The consistency checker detects a fixed list of known tracked executables, tiny
GGUF placeholders, and duplicate root images. Because `AES-FND-007` remains
`partial`, it reports every artifact issue as a warning. That preserves truth
about deletion-blocked legacy files, but it also means a newly committed fake
model, binary, archive, cache, database, log, or duplicate asset would receive
the same non-fatal treatment. The checker therefore inventories existing debt
without preventing new debt.

## Owning Domain

- `scripts/check_doc_drift.py` — repository truth and hygiene enforcement
- `repository_hygiene_policy.json` — data-owned legacy exception inventory
- `.github/workflows/ci.yml` — hosted enforcement entry point
- `CAPABILITY_LEDGER.md` / `TODO.md` / `DEVLOG.md` — evidence boundary

## Desired End State

1. Store the exact deletion-blocked legacy artifact inventory in a versioned
   data file rather than embedding it in checker logic.
2. Validate the policy schema, unique paths, allowed classifications, reasons,
   approval state, and correspondence to real tracked files.
3. Detect tracked executable magic and forbidden generated/model/archive/cache/
   database/log extensions generally, not only by known filename.
4. Detect tiny placeholder model-format files and root assets that duplicate
   canonical assets.
5. Warn only for exact policy-listed legacy artifacts while
   `AES-FND-007` remains non-verified.
6. Fail CI for every newly introduced artifact violation not listed in the
   policy.
7. Fail if a policy entry hides the wrong artifact class or if the policy grows
   without an explicit non-approved legacy disposition.
8. Add deterministic self-tests proving known legacy warnings, new-artifact
   rejection, schema rejection, and clean synthetic inventories without
   creating or deleting repository artifacts.

## Invariants to Preserve

- Do not delete, move, rename, or rewrite any legacy artifact.
- Keep `AES-FND-007` `partial`; prevention is not cleanup.
- Preserve all existing ledger, master-count, source-truth, absolute-path, and
  CI checks.
- Keep the checker dependency-free beyond the Python standard library and Git.
- Keep the normal CI command `python3 scripts/check_doc_drift.py` stable.
- Do not permit the exception policy to become a general allowlist for new
  generated files.
- Do not commit model weights, credentials, machine-local paths, build outputs,
  caches, or generated test artifacts.

## Implementation Plan

1. Add `repository_hygiene_policy.json` with the exact current legacy paths,
   classifications, reasons, and `deletion_requires_approval` disposition.
2. Refactor artifact classification into pure functions that accept tracked
   path metadata and content signatures.
3. Compare detected violations with policy entries by exact path and exact
   classification.
4. Emit one stable warning for policy-listed legacy debt and fail on all new or
   mismatched violations.
5. Add `scripts/test_check_doc_drift.py` using in-memory/test-owned temporary
   inputs only; it must not delete repository files.
6. Run the self-test from hosted CI before the live repository consistency
   check.
7. Reconcile roadmap, ledger, TODO, DEVLOG, and CI evidence without promoting
   artifact cleanup.

## Verification Plan

- `python3 scripts/test_check_doc_drift.py`
- `python3 scripts/check_doc_drift.py`
- deliberate self-test mutation proving an unlisted ELF/model artifact fails
- `pixi run mojo run aesir_engine/tests/run_all.mojo`
- `pixi run mojo build aesir_engine/main.mojo -o <temporary output>`
- `pixi run mojo run aesir_engine/tests/test_fail_closed_runner.mojo` must fail
  for its intentional reason
- `git diff --check`
- hosted GitHub Actions on `main`

## Completion Boundary

This slice prevents new tracked fake/generated artifact debt. It does not clean
the existing files, verify fixture provenance, implement release provenance,
scan full Git history, establish SBOM/signing, or complete `AES-FND-007`.
