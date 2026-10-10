# Capability ledger schema unit evidence — 2026-10-10

AES500-035 tests the new parser and JSON renderer with Python's standard
`unittest` framework.

## Bound run

- Runtime: Python 3.14.4.
- Parser: `scripts/ledger_schema.py`, SHA-256
  `70b516b9423376792042320ea02c649ebb24cfd1bdeb448c8000344ff6a9157e`.
- Unit test: `scripts/test_ledger_schema.py`, SHA-256
  `8eb8c80d2c75593407bb7b24aebca223c73e5dba5db7890f1e5f75f07bd191cf`.
- Command: `python3 scripts/test_ledger_schema.py`.
- Complete stdout SHA-256:
  `1607edbfae007ff56d6138df5d24d28abfe4b1ef27902563e1bb9ad258e5c4ec`.

## Cases

The 11 cases cover all five accepted statuses, absent optional fields mapping
to null, field-order independence, wrapped and blank continuation preservation,
repeated supplemental extension preservation, deterministic JSON rendering,
full-repository parsing (119 entries and 80 extension occurrences), empty input,
malformed headings with line diagnostics, invalid status, missing/empty required
fields, duplicate IDs and canonical fields, malformed labeled rows, and invalid
UTF-8 line attribution.

All 11 tests pass. This checks the parser contract and exported representation;
it does not establish that any underlying capability evidence is factually
correct or that the export is integrated into CI.
