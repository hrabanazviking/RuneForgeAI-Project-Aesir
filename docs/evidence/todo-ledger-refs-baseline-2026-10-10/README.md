# TODO capability-tag baseline — 2026-10-10

AES500-042 records explicit status-tag coverage before changing TODO reference
validation. This is a structural census only; it does not evaluate task
completion or the truth of capability evidence.

## Bound inputs and tool

- Repository revision: `95ed12f3adc8ae6721b756b267fa70b2f85a5d2c`.
- `TODO.md` SHA-256: `81c3622abceecebc42354831badf94bc56488137445b54b4489feb7c3965151d`.
- `CAPABILITY_LEDGER.md` SHA-256:
  `81da8d7ba90233fce5797540650fe2a43a1570be7120ab7a46e7e25f9f0bb03c`.
- Existing checker SHA-256:
  `edeb3105ba62695d557b98618ab41bfecaa60cbe1dff596bf71eb0f90667d937`.
- Census utility SHA-256:
  `64a13b9588e85571a4aa9a793a46be822da7ef32c54bd4114430ff0257dcd1b3`.
- Runtime: Python 3.14.4.
- Output SHA-256:
  `d611c9f83afa556108ccf5980b9bc9ab899b3ff0d224ea98a7d1bac5734495ad`.
- Two utility runs produced byte-identical JSON. Rerun with
  `python3 scripts/census_todo_ledger_refs.py`.

## Summary

- 95 explicit status tags contain 95 AES capability references across 68
  unique IDs: 34 verified, 38 partial and 23 missing tags.
- Four lines contain adjacent tags; two tags also carry AER audit references.
  Those AER IDs are recorded separately and are not capability IDs.
- The census finds zero unsupported statuses, unknown AES references and
  status mismatches under the full-reference interpretation.
- The current checker remains narrower than that interpretation: it captures
  only the first AES reference immediately after a tag's status. The baseline
  is therefore a shape and coverage inventory, not evidence that all later
  references were validated by the pre-change checker.

`todo-reference-census.json` retains every recognized tag with its line,
status, AES IDs, AER IDs, and structural validation counts. The census does not
edit source files or infer completion from TODO checkboxes.
