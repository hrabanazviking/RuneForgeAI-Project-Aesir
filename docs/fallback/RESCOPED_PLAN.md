# Re-scoped Plan (H119) — C7–C10 CPU-Only Execution Order

**Date:** 2026-10-10
**Requires:** H111 = NO-GO.

## Slice disposition (H121–H200)

**SKIP (NPU-only, 19 slices):**

| Slice | Title | Reason |
|---|---|---|
| H121–H135 | SKIPTI dispatch → NPU end-to-end | All require H111=GO; NPU dispatch/placement/prefill/decode |
| H171 | NPU path optimization | Requires H111=GO |
| H172 | Transfer overlap tuning | Requires H111=GO |
| H184 | NPU 4h soak | Requires H111=GO |

**RUN (CPU variants / as-is, 61 slices):**

- H136, H137, H138, H139 — F1 pipeline completion (require H111=NO-GO)
- H140 — C7 review (`docs/fallback/C7_REVIEW.md`, branch-aware)
- H141–H170 — VÖRÐR + speed (CPU-supervising variants: H150 shadow,
  H153 removal, H154 DMA-corrupt, H157 CPU-recompute)
- H173–H183 — decode-latency/prefill opt, budgets, CPU soak
- H185–H200 — soak analysis (H183's CPU logs), fault-injection,
  determinism (CPU-only), packaging, runbook, victory gates on CPU

**Degradation notes (documented, not silent):**

- H175/H179: H171/H172 rows absent — tables note "N/A (NO-GO)".
- H185/H196: evaluate H183's CPU-soak logs only (not H184's).
- H188: cross-backend check becomes CPU-only determinism.

## New dependency chain

```
H136 → H137 → H138 → H139 → H140 (C7 review)
  → H141–H160 → H160 (C8 review, ROBUST)
  → H161–H180 → H180 (C9 review, speed)
  → H181–H200 → H200 (fallback verdict)
```

Linear within each campaign; C7→C8→C9→C10 strictly ordered. No slice
depends on a skipped slice — verified mechanically by
`prof/smidr/check_rescope.py`.

## Validation

Run: `python3 prof/smidr/check_rescope.py`. It checks:
1. Every `[requires H111=GO]` slice is SKIP; every
   `[requires H111=NO-GO]` slice is RUN.
2. No RUN slice has a hard dependency on a SKIP slice (known
   cross-branch edges from the routing table, all documented as
   gracefully degrading).
