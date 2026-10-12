# Hailo-10H campaign evidence inventory

**Roadmap Slice 020 — complete (as of 2026-10-12 UTC)**

| Evidence item | Source | Freshness | Confidence / boundary |
|---|---|---|---|
| Project definition and target architecture | `AGENT_ONBOARDING.md`, `ENGINEERING_GOALS_AND_BOUNDARIES.md`, `ARCHITECTURE.md` | Project baseline commit `3b2608a3993ddbadaaac5d7799f22966d5d62896` | High for documented design; architecture doc distinguishes target from implementation |
| Current Hailo implementation capability | `CAPABILITY_LEDGER.md`, `aesir_engine/aesir.mojo`, `aesir_engine/core/mimir_well.mojo`, `aesir_engine/core/compute.mojo` | Same project baseline | High for code/ledger state: reserved enum and fail-closed errors; no Hailo execution |
| Campaign constraints | `docs/HAILO10H_ARCHITECTURAL_CONSTRAINTS.md`, `docs/HAILO10H_NO_CPU_INFERENCE.md`, `docs/HAILO10H_INFERENCE_POLICY.md` | Published feature branch, 2026-10-12 | High for user-authorized scope; no CPU LLM, no HEF/DFC/vendor runtime |
| Host/device identity | `docs/HAILO10H_HOST_DEVICE_IDENTITY.md` | Live read-only sample, 2026-10-12 14:52 UTC | High for the sample moment; not sustained-load status or inference evidence |
| OS and software identity | `docs/HAILO10H_OS_SOFTWARE_IDENTITY.md` | Live read-only sample, 2026-10-12 | High for sampled version output; package compatibility remains a separate question |
| PCI/IOMMU access state | `docs/HAILO10H_ACCESS_MECHANISMS.md` | Live read-only sample, 2026-10-12 | High for current sysfs/node/module observations; no DMA/UIO/VFIO usability proven |
| Hailo memory specification | `docs/HAILO10H_MODULE_MEMORY_EVIDENCE.md` and official manufacturer sources | Official product documentation checked 2026-10-12; installed board SKU not physically verified | High for product specs; low/unknown for exact installed memory SKU and usable capacity |
| Historic firmware bring-up | `docs/hailbru/PHASE_B_GATE.md`, `docs/hailbru/PHASE_C_GATE.md`, `CAPABILITY_LEDGER.md` | Prior campaign dated 2026-10-10 | High as recorded campaign evidence; does not assert today's live state |
| Command/compute gate | `docs/smidr/H102_ATTEMPT_RECORD.md`, `docs/smidr/PHASE_D_GATE.md`, `docs/HAILO10H_PHASE_D_RECONCILIATION.md` | Prior gate dated 2026-10-10; reconciled 2026-10-12 | High for recorded NO-GO; no current evidence supersedes it |
| User and request target | `docs/HAILO10H_INTERACTION.md`, `docs/HAILO10H_IO.md` | Feature branch, 2026-10-12 | Target contract only; not a working Hailo journey |
| Roadmap | `HAILO10H_ONLY_200_SLICE_ROADMAP.md` | Feature branch, 2026-10-12 | Campaign plan; dependent Hailo execution slices remain blocked by feasibility gates |

## Evidence-handling rules

1. Live observations are timestamped and not generalized beyond the sample.
2. Product documentation is not treated as proof that this exact board exposes a capability to Æsir.
3. Historical PASS results retain their scope and date; later failures are not hidden by earlier bring-up success.
4. A generated descriptor/config is not an executed Hailo operation.
5. The H111 NO-GO remains operative until materially new evidence reopens its gate.
6. No result is routed to Pi CPU LLM development.

## Slice 020 acceptance

- Evidence paths, dates, freshness, and confidence limits are listed.
- Current observations, official specifications, and historic results are distinct.
- The source of truth for campaign scope and sequence is explicit.
- The inventory adds no implementation or device-state changes.
