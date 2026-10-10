# Fallback Triggered (H115) — NO-GO Branch Opening

**Date:** 2026-10-10
**Trigger:** H111 Phase-D gate verdict **NO-GO** (see
`docs/smidr/PHASE_D_GATE.md`).

## The verdict and what it means

The Compiler Wall held. After exhausting every legitimate avenue —
faithful mailbox implementation, five hardening variants, both documented
doorbell targets, vendor-driver diagnostic — the Hailo-10's firmware
never answered a single command. No transport exists; no chip-executable
configuration can be submitted. The decision rule (GO iff H106+H109+H110
all PASS) forced NO-GO. This is an honest, earned NO-GO, not an assumed
one.

There is no drift and no denial from this point forward: **any slice
claiming NPU capability fails review.** The campaign continues on the
CPU path — the fallback trunk Volmarr named from the start.

## F1 scope: the guaranteed CPU deliverable

**F1 = fully working pure-Mojo ARM64 CPU inference engine, hardened by
VÖRÐR + GAUNTLET.** Concretely:

- ARMVEGR kernels (C2: H021–H040, incl. FP16 vector-add H025, GEMM H023)
  as the bit-exact compute reference — already the wall's measuring
  stick, now the production path.
- C3 pipeline (H041–H060): F1 core — batching, orchestration, packaging
  gaps closed by H136–H139.
- C7 (H136–H140): CPU pipeline completion — prefill + decode end-to-end
  (H136), batching + context (H137), coherent text from a small open LLM
  in production config (H138), SKIPTI AUTO = honest CPU-only mode (H139).
- C8 (H141–H160): VÖRÐR robustness — CPU-supervising variants
  (H150 shadow, H153 removal, H154 DMA-corrupt, H157 CPU-recompute).
- C9 (H161–H180, minus H171/H172): speed — NEON tuning, quantization,
  threading on the Pi 5.
- C10 (H181–H200, minus H184): GAUNTLET — CPU soak, crash-resistance,
  packaging, victory gates on the CPU path.

What F1 will NOT include: any NPU execution claim, any HEF handling,
any firmware interaction. Written down, honest scope.

## Re-scoped campaign plan (C7–C10, by slice ID)

**SKIP (NPU-only, 18 slices):** H121, H122, H123, H124, H125, H126,
H127, H128, H129, H130, H131, H132, H133, H134, H135 (all Phase E/F —
NPU dispatch, placement, prefill/decode on-chip), H171, H172 (NPU path
optimization), H184 (NPU 4h soak).

**RUN (CPU variants / as-is, 62 slices):** H136, H137, H138, H139
(F1 completion), H140 (C7 review, `docs/fallback/C7_REVIEW.md`),
H141–H170 (VÖRÐR + speed, CPU-supervising variants), H173–H183,
H185–H200 (H185/H196 evaluate H183's CPU-soak logs; H188's
cross-backend check becomes CPU-only).

Dependency hygiene: per the routing table (§5), no shared slice depends
on a branch-exclusive slice — verified mechanically by H119's script.

---
*Trigger announced in DEVLOG 2026-10-10 (H115). The F1 plan follows in
H116; the F2 survey in H117; banked assault docs in H118; the mechanical
re-scope validation in H119.*
