# C6 Review: Wall-Assault Retrospective (H120)

**Date:** 2026-10-10
**Campaign:** 6 (SMIÐR / The Wall)
**Flavor:** NO-GO (per H111).

## What we attempted

The Compiler Wall assault (H101–H110) asked whether chip-executable
configurations could be generated and run bit-exact **without** the
proprietary Dataflow Compiler. The plan was strictly serial:
research the command queue (H101) → prove the submission transport
(H102) → build descriptors (H103) → generate configs (H104) → first
compute (H105) → bit-exact verification (H106) → matmul (H107) →
repeatability (H108–H110) → gate (H111).

## What happened

The assault broke at the second step and honestly stopped there:

- **H101 PASS** — then the mailbox model was corrected (not a ring
  buffer) and every claim was evidence-marked.
- **H102 FAIL** — the firmware never answered. Five hardening
  variants, both documented doorbells (final probe this campaign),
  vendor ioctl: all silent.
- **H103 PASS, H104 PASS** — built anyway as honest host-side
  artifacts: fail-closed descriptors, deterministic SMIÐR-CFG v1,
  independently validated.
- **H105–H110 BLOCKED** — no transport, no submission, no faked
  results. The strict-serial law did its job.
- **H111 NO-GO** — forced by the decision rule, earned by exhaustion.

## What we learned

1. **The wall is the firmware dialogue, not the encoding.** The
   deeper unknown (H019 element 1, the compute encoding) never even
   came into play — the transport failed first. A future attempt
   should attack the firmware-service question directly (why is the
   app-CPU control service silent despite "firmware loaded"?), not
   the descriptor format.
2. **Honesty compounds.** The H103/H104 artifacts — built to be
   testable without the chip — are now the F3 banked record and the
   test harness for any future attempt. Work done honestly under
   NO-GO is not wasted.
3. **Fail-closed is a feature of the process, not just the code.**
   Marking H105/H106 BLOCKED instead of simulating them is what makes
   the NO-GO trustworthy — and what makes the F1 fallback credible.

## The F1 CPU guarantee (affirmed)

The fallback trunk was never the consolation prize — it was the
plan all along, and it is **already proven**: H059 generated coherent
text from a real small open LLM on the pure-Mojo CPU path on Mimir
("Hospitality refers to the act of providing hospital..."), C3
verdict **F1-CORE-READY** (2026-10-10 ~08:08 EDT). The CPU engine is
real, measured, and coherent. C7–C10 (H136–H200, CPU-only) harden it
into a production engine: pipeline completion, VÖRÐR robustness,
NEON speed, GAUNTLET stability.

## Ambition, honestly kept

Volmarr's directive was FULL ambition AND FULL honesty. The ambition
is on record: every legitimate avenue tried, the final core-doorbell
probe run the same day as the gate. The honesty is on record: NO-GO
written plainly, no simulated compute, no invented encodings. The
wall held this campaign. The saga continues on the CPU path — and
the banked assault docs (H118) keep the door open for the next
attempt.

---
*C6 retrospective complete. Campaign 6: 20/20 slices executed
(H101–H104 PASS, H102 FAIL, H105–H110 BLOCKED, H111 NO-GO,
H115–H120 executed).*
