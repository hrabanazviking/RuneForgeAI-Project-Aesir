# Capability ledger schema baseline — 2026-10-10

AES500-032 recorded a read-only, repeatable census before schema implementation.

## Bound baseline

- Repository revision: `5880af2ceffde638cfae4d457bce9ffdc2b336f8`.
- Ledger: `CAPABILITY_LEDGER.md`, SHA-256
  `81da8d7ba90233fce5797540650fe2a43a1570be7120ab7a46e7e25f9f0bb03c`.
- Existing drift checker: `scripts/check_doc_drift.py`, SHA-256
  `f4e194525a191f401c4f282269fc31dc9c5bf85139b54fe9c9cbb48f141dc89e`.
- Census tool: `scripts/census_capability_ledger.py`, SHA-256
  `f1922268ccb9454774a5de2cb7ac154241e1fb0e11915807045f7efc0366493d`.
- Runtime: Python 3.14.4.
- Deterministic census JSON SHA-256:
  `53557489b8cc14c13c7cf55aa9b61f09e2b7ff8ebb4c20b8e718ae492bf83c02`.
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
- Supplemental top-level metadata is preserved as 80 per-entry occurrences
  across 77 distinct labels; the JSON stores each entry's ordered supplemental
  labels and a repository-wide label count. These remain extensions, not
  inferred aliases for canonical fields.
- Exact missing IDs are retained in the JSON arrays. These absences remain
  source absences; the baseline does not fabricate prose to fill them.

The census tool counts recognized Markdown fields, captures IDs, names, status,
line number, and per-entry field counts, and hashes the exact source bytes. It
does not determine whether evidence is accurate, alter statuses, or implement
the future JSON exporter.
