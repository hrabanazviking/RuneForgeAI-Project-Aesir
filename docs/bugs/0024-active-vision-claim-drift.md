# Bug 0024: Active Vision Documents Mix Historical Claims with Current Status

## Symptom

`docs/Vision.md` and `docs/SYSTEM_VISION.md` contain preserved stage milestone
logs in the active present-tense document body. Those logs label unsupported or
narrow capabilities as completed or verified and continue into broad
accelerator, service, ecosystem, swarm, recovery, and production declarations.

## Expected

Active vision introductions state only current evidence-backed boundaries.
Historical milestone prose remains preserved but is structurally marked as
chronology that cannot override `CAPABILITY_LEDGER.md`.

## Suspected Domains

- project documentation
- capability status governance
- repository consistency enforcement

## Invariant Violated

The capability ledger is the sole present-tense maturity authority. Historical
claims must not be visually or mechanically indistinguishable from current
status.

## Reproduction

1. Parse current capability statuses from `CAPABILITY_LEDGER.md`.
2. Scan pre-boundary status declarations in both active vision documents.
3. Before repair, observe 39 contradictory lines in `docs/Vision.md` and 23 in
   `docs/SYSTEM_VISION.md`.
4. Examples include `AES-SWM-003`, `AES-ECO-004`, `AES-ACC-009`,
   `AES-SRV-006`, `AES-MEM-006`, and `AES-FND-007` described as verified while
   their ledger entries are non-verified.

## Repair Contract

- Preserve the complete historical bodies in place.
- Add a concise current evidence boundary to each document.
- Insert one explicit `HISTORICAL_CLAIMS_BEGIN` marker before the old logs.
- Validate all status tags before the marker against the ledger.
- Ignore status vocabulary after the marker only because the section is
  explicitly historical.
- Do not change capability status as part of this repair.
