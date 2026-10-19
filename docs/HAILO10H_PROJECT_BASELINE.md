# Hailo roadmap — project commit and authoritative artifacts

**Roadmap Slice 012 — complete (2026-10-12)**

## Commit identity

At the Slice 011 baseline check, the repository default branch `main` pointed to `3b2608a3993ddbadaaac5d7799f22966d5d62896` (`Coordinator: MIMISBRUNNR 200/200 completion seal`, dated 2026-10-11). This is the Æsir project revision against which the Hailo campaign was initially reconciled. The campaign itself is published on `docs/cross-cutting-hailo-mission`; its current head may advance as slices are pushed.

## Authority map for this campaign

| Question | Authoritative evidence |
|---|---|
| What Æsir is and its overall architecture | `AGENT_ONBOARDING.md`, `ENGINEERING_GOALS_AND_BOUNDARIES.md`, `ARCHITECTURE.md`, and `CAPABILITY_LEDGER.md` at the recorded project revision |
| Hailo campaign mission and architecture limits | `docs/HAILO10H_MISSION.md`, `docs/HAILO10H_ARCHITECTURAL_CONSTRAINTS.md` |
| CPU LLM scope exclusion | `docs/HAILO10H_NO_CPU_INFERENCE.md`, `docs/HAILO10H_INFERENCE_POLICY.md` |
| Current machine census | `docs/HAILO10H_ACCESS_CENSUS.md`; snapshot only, not a mutating-device authorization |
| Previous transport attempt and gate | `docs/smidr/H102_ATTEMPT_RECORD.md`, `docs/smidr/PHASE_D_GATE.md` |
| Current campaign plan | `HAILO10H_ONLY_200_SLICE_ROADMAP.md` on the feature branch |
| Historical roadmap containing CPU fallback work | `HAILO10_200_SLICE_ROADMAP.md`; preserve as history, but do not use its CPU fallback slices in this campaign |

## Reconciliation rule

The capability ledger and executable source establish present implementation status. Campaign docs establish current user-authorized scope. The corrected Hailo-only roadmap governs slice sequencing. A planning statement never overrides contradictory implementation evidence, and an old CPU branch never overrides the explicit no-CPU scope.

## Slice 012 acceptance

- The project revision used for the baseline is pinned by full commit SHA.
- The authoritative mission, constraints, capability, machine, and prior-gate records are named.
- Historical CPU fallback roadmap content is marked non-authoritative for campaign execution.
- No repository or hardware state was modified to produce this inventory.
