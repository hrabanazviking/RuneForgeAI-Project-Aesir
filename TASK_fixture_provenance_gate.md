# Task: Fixture Classification and Provenance Gate

## Authorization

Volmarr instructed Project A.E.S.I.R. to continue repairing all discovered
issues and to push every completed step to the actual `main` branch. This is a
non-destructive Phase 0 slice. It does not authorize deletion, model download,
fixture generation, or committing model weights.

## System Statement

The repository truthfully keeps its one real GGUF integration model outside
Git and pins its revision, checksum, size, license, and oracle across several
documents. Those facts have no single machine-validated owner. Meanwhile,
`TESTING_PROTOCOL.md` and `GIT_DISCIPLINE.md` still describe nonexistent
committed GGUF fixture directories and a fictional tiny model. A future fixture
can therefore arrive without classification, provenance, licensing, checksum,
consumer, or an honest evidence boundary.

## Owning Domain

- `fixture_manifest.json` — canonical fixture identity and provenance data
- `scripts/check_fixture_manifest.py` — dependency-free live validator
- `scripts/test_fixture_manifest.py` — deterministic schema/policy tests
- `.github/workflows/ci.yml` — hosted enforcement
- tests-domain documentation, ledger, TODO, roadmap, and devlog — evidence truth

## Desired End State

1. Define exactly four fixture classifications: `synthetic`, `malformed`,
   `regression`, and `external-reference`.
2. Give every registered fixture a stable ID, owner, purpose, consumer,
   evidence boundary, storage policy, license, immutable source identity,
   cryptographic checksum, and exact byte size where applicable.
3. Register the pinned `stories260K.F16.gguf` external reference and its
   independent `llama.cpp` oracle once, without committing or downloading it.
4. Reject duplicate IDs/paths, unsafe paths, missing consumers, unknown fields,
   invalid hashes/sizes/revisions, unpinned external URLs, and external fixtures
   that appear in Git.
5. Require tracked fixture data to live only under the canonical
   `aesir_engine/tests/fixtures/` boundary and to exist exactly as registered.
6. Add deterministic in-memory tests for valid, malformed, external, and
   tracked-fixture rules without creating or deleting artifacts.
7. Correct active documents that falsely claim a committed tiny GGUF fixture
   or a currently populated fixture tree.

## Invariants to Preserve

- Do not add, download, generate, delete, move, or rewrite any model weight.
- Do not promote external compatibility from schema validation alone.
- Do not treat an external fixture registration as proof that CI executed it.
- Keep the existing real-model test opt-in and the master-suite integration
  boundary explicitly skipped.
- Keep validation standard-library-only and fail closed.
- Keep `AES-FND-007` `partial`; this gate is provenance prevention, not cleanup.

## Implementation Plan

1. Add a data-owned manifest containing the exact pinned external GGUF and
   oracle facts already evidenced by the ledger and task contracts.
2. Implement pure schema/policy validation plus a live Git/filesystem boundary.
3. Add deterministic self-tests and run them in hosted CI.
4. Reconcile `TESTING_PROTOCOL.md`, `GIT_DISCIPLINE.md`, tests README/interface,
   capability evidence, TODO, roadmap, and devlog.
5. Run the focused validators, consistency checker, master suite, native build,
   fail-closed negative control, and diff check; push and observe hosted CI.

## Verification Plan

- `python3 scripts/test_fixture_manifest.py`
- `python3 scripts/check_fixture_manifest.py`
- `python3 scripts/test_check_doc_drift.py`
- `python3 scripts/check_doc_drift.py`
- `pixi run mojo run aesir_engine/tests/run_all.mojo`
- `pixi run mojo build aesir_engine/main.mojo -o <temporary output>`
- intentional fail-closed runner exits nonzero for its named assertion
- `git diff --check`
- hosted GitHub Actions on `main`

## Completion Boundary

This slice establishes fixture admission and provenance metadata. It does not
create a malformed corpus, run an external-fixture CI job, verify a new model,
scan license text, validate arbitrary file-format bytes, or establish release
provenance.

## Implementation Evidence

- `fixture_manifest.json` is the single machine-readable owner for the pinned
  external GGUF identity and `llama.cpp` oracle already proven elsewhere.
- `scripts/check_fixture_manifest.py` enforces exact schema fields,
  classifications, immutable revisions, pinned URLs, checksums, sizes,
  consumers, canonical tracked paths, and external-storage boundaries.
- `scripts/test_fixture_manifest.py` proves clean tracked and external cases as
  well as unknown classes, unsafe paths, malformed hashes, missing ownership,
  unknown fields, unpinned URLs, accidentally tracked external files, and
  orphan tracked payloads without creating or deleting artifacts.
- Active testing and Git documents no longer claim a fictional committed tiny
  GGUF or nonexistent populated fixture tree; obsolete suite counts are
  reconciled to 132 passed cases plus one explicit skip.
- CI runs both fixture checks before the repository consistency gate.
