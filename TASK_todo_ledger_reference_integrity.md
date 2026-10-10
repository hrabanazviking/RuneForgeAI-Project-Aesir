# AES500-041 — TODO-to-ledger reference integrity contract

## Objective

Specify deterministic integrity checks for status-tagged capability
references in the active `TODO.md`. The capability ledger remains the sole
status authority. This contract does not reinterpret prose or infer completion
from checkbox state.

## Owner and inputs

- Primary owner: `scripts/check_doc_drift.py`.
- Canonical capability states: schema-validated `CAPABILITY_LEDGER.md`.
- Consumer input: UTF-8 `TODO.md`.
- Test owner: `scripts/test_check_doc_drift.py`.

## Existing behavior to preserve

`todo_status_reference_errors(content, statuses)` scans lines for explicit
status tags of the form `[status, references...]`. Some real tags contain
semicolon-separated references such as `[verified, AES-MEM-001; AER-002]`,
and some lines contain adjacent tags. Today the implementation recognizes only
the first AES ID immediately after the status, so later AES IDs and adjacent
tags can escape validation. This program closes that gap. The repository
checker already runs schema, legacy ledger, TODO tag, active vision, source and
hygiene checks in one invocation.

## Invariants

- Only explicit status tags in `TODO.md` are status assertions. A checkbox or
  untagged descriptive sentence does not declare a ledger status.
- A status-tag candidate is recognized for validation only when its bracket
  body starts with a lowercase status token and contains at least one
  ledger-shaped `AES-[A-Z]+-N` ID. Arbitrary bracket syntax and status-like
  brackets with no AES ID are ignored.
- Every recognized candidate must use a supported status. Every AES capability
  ID matching the ledger grammar anywhere in its reference list is validated
  independently against the ledger and must match the tag status. Non-AES
  references such as AER audit IDs are preserved and ignored by this check.
- Multiple adjacent status tags on one line are independently validated.
  Unknown or mismatched later references cannot be hidden by an earlier valid
  ID.
- Each error includes the literal source name `TODO.md`, one-based line number,
  and a stable diagnostic message.
- Multiple errors on a line and errors across lines are all returned in
  deterministic source order (left to right, then each ID in source order).
- Markdown historical context and ordinary references are not rewritten.
- The TODO checker consumes the same status mapping validated by
  `check_ledger`; it cannot edit or promote ledger entries.

## Exclusions

- No attempt to determine whether checked TODO items are truly complete.
- No requirement to tag every mention of an AES ID; historical sections and
  prose can mention IDs without declaring current status.
- No status changes or bulk normalization of TODO text.
- No automatic TODO generation or completion inference.

## Acceptance commands

```sh
python3 scripts/test_check_doc_drift.py
python3 scripts/check_doc_drift.py
```

## Follow-on sequence

AES500-042 captures a reproducible count and examples of current TODO tag
coverage, including combined and adjacent tags. AES500-043 pins helper behavior,
ordering and line diagnostics.
AES500-044–047 implement and exercise only approved additions. AES500-048
independently reviews the result; AES500-049 synchronizes documentation;
AES500-050 runs the exact-head release gate.
