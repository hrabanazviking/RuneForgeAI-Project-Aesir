# AES500-031 — capability ledger schema contract

## Objective

Define a fail-closed, machine-readable schema for the canonical capability
ledger and a deterministic read-only export contract. `CAPABILITY_LEDGER.md`
remains the sole authority for present-tense capability status. The proposed
export is derived data for consistency tooling; it cannot overwrite or promote
the Markdown ledger.

## Owner and inputs

- Primary owner: `scripts/ledger_schema.py` (to be introduced by implementation
  slices after this contract and its baseline/interface gates).
- Canonical input: UTF-8 `CAPABILITY_LEDGER.md` from the repository root.
- Existing truth checks: `scripts/check_doc_drift.py`, especially
  `ledger_statuses()` and `check_ledger()`.
- Existing schema precedent: `docs/tasks/TASK_capability_ledger.md` and the
  ledger's `Status Contract` and `Ledger Schema` sections.
- Consumers: repository documentation checks and future read-only tooling.

## Proposed schema

Each parsed capability entry has exactly these fields:

1. `id`: unique stable `AES-[A-Z]+-N` identifier from the heading;
2. `name`: nonempty capability name from the heading;
3. `status`: exactly one of `verified`, `partial`, `scaffold`, `simulated`,
   `missing`;
4. `owner`: nonempty owning domain;
5. `claim_sources`: source description or `null` when absent in Markdown;
6. `implementation_evidence`: implementation description or `null` when absent;
7. `executable_evidence`: nonempty executable command or explicit source-only
   evidence description;
8. `evidence_boundary`: nonempty statement of what the evidence does not prove;
9. `next_acceptance_gate`: next gate or `null` when absent in Markdown;
10. `audit`: related audit IDs or `null` when absent in Markdown.
11. `extensions`: ordered `{label, value}` objects for supplemental metadata
    fields such as dated implementation/evidence extensions; no extension is
    discarded or promoted into a canonical field.

The output document carries `schema_version: 1` and a deterministically ordered
`capabilities` array ordered by their source appearance. All keys are present
in JSON; the four optional fields above use JSON `null` only when their source
field is absent. The current 119-entry ledger census already shows missing next
gates in 32 entries, audits in 4, claim sources in 2, and implementation
evidence in 1. These absences are preserved, not bulk-filled. Baseline work
records exact IDs and checks whether alternate field labels need explicit
mapping. Export values preserve Markdown wording with only continuation
line endings normalized to LF and outer field whitespace trimmed. Internal
continuation newlines and Markdown are preserved. No claims, status, or evidence
are synthesized by the exporter.

## Invariants

- Markdown remains the only editable status authority; JSON is derived output.
- Each capability heading is unique and has exactly one allowed status.
- `id`, `name`, `status`, `owner`, `executable_evidence`, and
  `evidence_boundary` appear exactly once per entry and are nonempty.
- Optional source fields appear at most once per entry; absent source fields
  become JSON `null`, never fabricated placeholder evidence.
- Supplemental labeled fields are preserved in source order under
  `extensions`; repeated extension labels remain separate array elements.
- Field order in Markdown does not affect parsing. Any top-level `- **Label:**`
  row, canonical or supplemental, starts a field and ends the previous field;
  indented field-like lines remain continuation content. Blank lines between a
  field and the next field are retained internally; outer field whitespace is
  trimmed.
- Markdown links, code spans, punctuation, and inline references remain text; the
  exporter does not interpret them as executable content.
- Duplicate IDs, unknown status values, missing fields, repeated fields, and
  malformed headings fail before any output is published.
- Parsing does not silently repair, infer, or promote entries.
- Deterministic input yields UTF-8 JSON with two-space indentation, a final
  newline, source-order entries, extension-order preservation, byte-identical
  output, and stable diagnostics.
- The full ledger is validated before publication; failed validation leaves an
  existing destination untouched (same-directory temporary file plus atomic
  replace). Temporary files are removed after write/replace failures. Export
  rejects an output path resolving to or sharing an inode with the input.
- A heading-like top-level `### AES-...` line that does not match the canonical
  ID/name form is rejected, not consumed as preceding field continuation.
- The existing repository drift checker and TODO-to-ledger status validation
  remain active and retain their current behavior.
- `scripts/check_doc_drift.py` invokes the schema parser against the exact
  already-read ledger text and reports deterministic schema-prefixed errors;
  legacy count/status checks continue to run.
- Atomic replacement guarantees visibility of either the old or complete new
  output. Exported file permissions are restrictive (`0600` on the tested
  platform); parent-directory fsync and power-loss durability are not claimed.
- The schema does not decide whether evidence is true; it validates required
  structure and leaves capability review to the ledger owners.

## Exclusions

- No conversion of `CAPABILITY_LEDGER.md` into generated Markdown or JSON as the
  new source of truth.
- No capability status changes or bulk rewriting of historical evidence.
- No automatic maturity scoring, claim extraction from arbitrary documents,
  TODO completion inference, or external CI/API publication.
- No deletion or renaming of existing ledger IDs.

## Acceptance commands

The implementation and later evidence gates will establish these interfaces:

```sh
python3 scripts/ledger_schema.py check CAPABILITY_LEDGER.md
python3 scripts/ledger_schema.py export-json CAPABILITY_LEDGER.md --output /tmp/aesir-capability-ledger.json
python3 scripts/test_ledger_schema.py
python3 scripts/check_doc_drift.py
```

The baseline slice must inventory current ledger conformance before code changes.
Existing absent optional fields remain absent; do not silently fill or fabricate
evidence to satisfy the export schema.

## Follow-on sequence

AES500-032 records a read-only baseline and conformance census. AES500-033 pins
the parser/output interface and malformed-input behavior. AES500-034 implements
the parser/validator and deterministic export. AES500-035 adds normal/boundary/
malformed unit evidence; AES500-036 integrates with repository truth checks;
AES500-037 adds adversarial file mutation and output-publication cases;
AES500-038 obtains independent review; AES500-039 synchronizes docs; AES500-040
is the exact-head release gate.

## AES500-032 baseline result

The pre-implementation census is preserved in
`docs/evidence/capability-ledger-baseline-2026-10-10/`. It recognizes 119 unique
entries, with 76 verified, 28 partial, and 15 missing statuses. All entries have
status, owner, executable evidence, and evidence boundary fields. Optional
source fields are absent in 2 claim-source, 1 implementation-evidence, 32 next-
gate, and 4 audit entries. The census also records 80 supplemental metadata
occurrences across 77 distinct labels, preserving exact per-entry order without
promoting them to canonical fields. Exact IDs and field-label counts are in the
machine-readable census. Three census runs produced identical bytes and the
existing drift checker passed. This is a structural snapshot, not an evidence
truth evaluation.
