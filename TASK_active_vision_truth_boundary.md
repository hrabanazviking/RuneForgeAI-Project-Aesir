# Task: Active Vision Truth Boundary and Status Gate

## Authorization

Volmarr instructed Project A.E.S.I.R. to continue repairing all discovered
issues and push each completed step to the actual `main` branch. This Phase 0
slice changes active documentation and verification only. It authorizes no file
deletion, historical-record deletion, capability promotion, or runtime claim.

## System Statement

`docs/Vision.md` and `docs/SYSTEM_VISION.md` begin with a ledger disclaimer but
then mix old milestone declarations and broad target capability prose into the
active document without a structural historical boundary. A mechanical census
finds 39 ledger-status contradictions in `docs/Vision.md` and 23 in
`docs/SYSTEM_VISION.md`, including unsupported accelerator, swarm, ONNX, EXL2,
REST, RAG, persistence, recovery, and production claims. The text is valuable
history, but its current placement makes historical declarations look
present-tense.

## Owning Domain

- `docs/Vision.md` — design intent and current evidence boundary
- `docs/SYSTEM_VISION.md` — system target and current evidence boundary
- `scripts/check_doc_drift.py` — active declaration enforcement
- `scripts/test_check_doc_drift.py` — deterministic status-boundary tests
- `docs/bugs/0024-active-vision-claim-drift.md` — durable defect record
- capability ledger, TODO, roadmap, and devlog — synchronized evidence

## Desired End State

1. Both active vision documents begin with concise present-tense evidence
   summaries whose status tags match `CAPABILITY_LEDGER.md`.
2. Every existing milestone and broad capability line is preserved in place
   beneath an explicit `HISTORICAL_CLAIMS_BEGIN` marker.
3. The historical section states unambiguously that its completion/status words
   are chronological claims, not current evidence.
4. The consistency checker requires the marker and rejects unsupported status
   tags, unknown capability IDs, and ledger mismatches before it.
5. Deterministic tests prove current-section rejection and historical-section
   exclusion.
6. The census defect and evidence boundary are recorded without changing any
   capability status.

## Invariants

- Preserve all historical milestone prose; do not delete, rewrite, or silently
  modernize the historical record.
- `CAPABILITY_LEDGER.md` remains the only maturity authority.
- A historical claim is not executable evidence.
- Do not describe targets as implemented merely because a symbol or old test
  exists.
- Keep the verified single-device CPU GGUF slice and all broader non-verified
  boundaries truthful.
- No file, function, model, asset, or historical record is deleted or moved.

## Verification Plan

- deterministic current/historical status-boundary tests
- zero mismatches before each historical marker
- exact preservation of every pre-existing line below the new marker
- fixture and artifact consistency validators
- 132/0/1 master suite, native build, intentional negative control
- `git diff --check`
- hosted GitHub Actions on `main`

## Completion Boundary

This slice separates current truth from preserved historical claims. It does
not individually adjudicate or rewrite every historical sentence, establish
new runtime evidence, or make future targets current capabilities.
