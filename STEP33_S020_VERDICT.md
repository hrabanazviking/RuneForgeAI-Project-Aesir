# Step 33, S-020 — Verdict on the orphaned ledger-schema test

Date: 2026-10-28
Branch: platform/step33-orphan (from platform/step33-remainder)
Verdict: **REPAIR** — `scripts/test_ledger_schema.py` is repaired and
wired into the in-house battery. It is not retired.

## How it actually failed (measured, not assumed)

Running `python3 scripts/test_ledger_schema.py` before the repair:
15 tests run, 14 pass, 1 error, exit 1. The only failure was
`test_repository_ledger_matches_baseline_shape`, and it did not fail
on its stale count assertions (119 entries, 80 extensions) — it never
reached them. `parse_ledger_path` on the current `CAPABILITY_LEDGER.md`
raises `LedgerSchemaError` first, with 176 diagnostics:
89 x missing required field 'Evidence boundary' and
87 x missing required field 'Executable evidence'.

That strict failure is already owned elsewhere: the repository
consistency checker reports exactly those 176 schema diagnostics as
part of its 237 findings (verified by running it, unchanged after
this change). The ledger content debt is a separate step-33 slice;
this slice may not edit the ledger.

Wiring before the repair: a tree-wide search found no reference to
`test_ledger_schema` in the CI workflow or in the in-house battery
harness (`run_battery.sh` and its `steps/` directory in the local
ci-local-2026-10-27 harness copy).

## Coverage comparison (both files read in full)

What `scripts/test_check_doc_drift.py` covers for the ledger schema
is one integration test only: a small valid fixture passes, and the
same fixture with a misspelled Owner field yields exactly one named
diagnostic. It never calls the JSON renderer or the JSON exporter.

What `scripts/test_ledger_schema.py` covers that the drift suite
does not:

- All five canonical statuses parse, with absent optional fields
  rendering as nulls.
- Wrapped Markdown values, blank-line continuations, field order,
  and repeated extension fields are preserved by the parser.
- JSON rendering is deterministic, ends with a newline, carries
  schema version 1, and retains extension fields.
- UTF-8 decode failure is reported with the correct source line.
- Atomic export behaviour: invalid input preserves an existing
  destination and cleans its temporary file; a same-path alias and
  a hard-link alias are both rejected; an injected replace failure
  and an injected write failure preserve the destination and clean
  the temporary file.
- Fail-closed parser diagnostics for: empty ledger, malformed
  heading (with source and line), invalid status, missing and empty
  required fields, duplicate capability IDs, duplicate canonical
  fields, and malformed labeled fields.

A repository-wide search confirms the point: outside
`scripts/ledger_schema.py` itself, the JSON render and export
functions are exercised by no other test. Retiring this file would
have deleted the only coverage of the ledger JSON export path.

## The repair

Only the one repository-baseline test changed; the other 14 tests
are untouched. The baseline was re-measured from the current tree
(parser regexes and canonical-field set, counted block by block,
plus the diagnostics raised by the strict parse):

- 329 capability entries (previous baseline: 119)
- 458 extension fields (previous baseline: 80)
- 176 strict-schema diagnostics pinned by message:
  89 missing 'Evidence boundary', 87 missing 'Executable evidence'

The repaired test pins those measured numbers, including the
diagnostic counts, so any ledger growth, shrinkage, extension
change, or schema-debt change breaks it on purpose and forces a
conscious re-measure. It does not re-assert a clean parse of the
real ledger, because the wired consistency checker already fails
on exactly that, and duplicating its red guard here would keep a
parser unit suite red for a ledger-content problem it cannot fix.

## Wiring

- Battery: added `steps/35.sh` (contents:
  `python3 scripts/test_ledger_schema.py`) and a
  `run_step 35 "Prove Capability Ledger Schema and JSON Export"`
  line after step 34 in the harness `run_battery.sh`. Step numbers
  in use were 03-34, so 35 is the first free slot and collides
  with nothing. The harness files live in the local
  ci-local-2026-10-27 verification copy under `.verify-tmp`, so
  this wiring is a local harness change, not a repository commit.
- CI workflow: not edited. CI is manual-only by owner law, and the
  in-house battery is the verification of record.

## Verification (in this worktree, after the change)

- `python3 scripts/test_ledger_schema.py` — exit 0, 15 tests, OK.
- `python3 scripts/test_check_doc_drift.py` — exit 0.
- `python3 scripts/check_doc_drift.py` — exit 1 with
  "FAILED: 237 repository consistency issue(s)", the same total
  as before the change; this change adds no findings.
