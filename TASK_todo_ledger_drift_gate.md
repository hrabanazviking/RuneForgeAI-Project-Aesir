# Task: TODO and Capability Ledger Status Drift Gate

## Authorization

Volmarr instructed Project A.E.S.I.R. to continue fixing all discovered issues
and push each completed step to the actual `main` branch. This non-destructive
Phase 0 slice changes documentation truth checks only; it authorizes no deletion
or capability promotion.

## System Statement

`TODO.md` uses inline `[status, AES-ID]` tags to connect detailed work to the
canonical capability ledger, but those tags are not validated. A current census
finds 11 mismatches, including completed checklist items still labeled
`missing`, open follow-ups labeled `partial` against `verified` narrow
capabilities, and operations/CI items whose ledger status has changed. These
tags can misstate present capability maturity even when the ledger itself is
correct.

## Desired End State

1. Every status-tagged TODO reference names an existing capability ID.
2. Every TODO status tag exactly matches that capability's current ledger
   status, regardless of whether the checklist item itself is open or complete.
3. Follow-up wording makes clear when an unchecked item extends a narrowly
   verified capability rather than contradicting its verified boundary.
4. The repository consistency checker fails on unknown statuses, unknown IDs,
   and ledger/TODO status mismatches.
5. Deterministic self-tests prove matching, mismatched, unknown-ID, and
   unsupported-status behavior.

## Invariants

- `CAPABILITY_LEDGER.md` remains the only maturity authority.
- A TODO checkbox records task completion, not capability status.
- Repairing a tag does not promote or demote a capability.
- Open work remains open; no backlog item is closed merely to remove drift.
- No file is deleted, moved, or renamed.

## Verification Plan

- focused checker self-tests
- `python3 scripts/check_doc_drift.py`
- zero remaining ledger/TODO tag mismatches
- master suite, native build, intentional negative control, and diff check
- hosted GitHub Actions on `main`

## Completion Boundary

This slice enforces status-reference consistency only. It does not decide
whether every TODO item is well scoped, remove duplicates, implement open work,
or alter capability evidence boundaries.
