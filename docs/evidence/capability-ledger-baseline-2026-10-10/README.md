# Capability ledger schema baseline — 2026-10-10

AES500-032 recorded a read-only, repeatable census before schema implementation.

## Bound baseline

- Repository revision: `5880af2ceffde638cfae4d457bce9ffdc2b336f8`.
- Ledger: `CAPABILITY_LEDGER.md`, SHA-256
  `81da8d7ba90233fce5797540650fe2a43a1570be7120ab7a46e7e25f9f0bb03c`.
- Existing drift checker: `scripts/check_doc_drift.py`, SHA-256
  `f4e194525a191f401c4f282269fc31dc9c5bf85139b54fe9c9cbb48f141dc89e`.
- Census tool: `scripts/census_capability_ledger.py`, SHA-256
  `84b2518f2c30c92a5b8be22832462953c5cbb6ca5256d6cafa144982adc44a49`.
- Runtime: Python 3.14.4.
- Deterministic census JSON SHA-256:
  `9aa0389eab6abcbbb8a5b95f6c6ce05d94dfbecc4b8b5b768a538a4de465434c`.
- Rerunning `python3 scripts/census_capability_ledger.py` three times produced
  byte-identical JSON; the committed snapshot is `ledger-census.json`.
- `python3 scripts/check_doc_drift.py` passed before schema changes.

## Census summary

- 119 recognized capability entries; 0 duplicate IDs.
- Statuses: 76 `verified`, 28 `partial`, 15 `missing`.
- Every entry has exactly one recognized status, owner, executable evidence, and
  evidence boundary.
- `Claim sources` is absent from 2 entries; `Implementation evidence` from 1;
  `Next acceptance gate` from 32; `Audit` from 4. No field is repeated in the
  census.
- Exact missing IDs are retained in the JSON arrays. These absences remain
  source absences; the baseline does not fabricate prose to fill them.

The census tool counts recognized Markdown fields, captures IDs, names, status,
line number, and per-entry field counts, and hashes the exact source bytes. It
does not determine whether evidence is accurate, alter statuses, or implement
the future JSON exporter.
