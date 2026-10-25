# Datum identity III, unit pairs, replicated scalars (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.21 (AES-NUM-021).
Three arms, all exact counts. Transport note: the analysis
script reached Mimir by gzipped 900-byte parts with
per-part md5 gates; one part corrupted deterministically
and was healed by splitting it in half — assembled file
sha256-verified identical to the local original.

## Arm 1 — datum vs protobuf varint fields: route CLOSED

- MiniLM: pool of 62 datum values intersects the recursive
  varint walk (9,822 occurrences, 5,375 distinct < 2²⁴)
  **0 times**, and the op-direct varints (1,763) **0 times**.
- Blob 5ab3537d: 576,769 recursive varint occurrences; the
  pool's leading pair values (`0x60e517`, `0x56898c`) occur
  **0 times**. Stray intersection 9/417 vs chance
  expectation 3.7 (random control pools: 2–3); every hit is
  a singleton value. The pool's *frequent* members are never
  varints.
- **Verdict: the datum is not a protobuf varint field
  value** — not an offset, size, channel, or op parameter
  in disguise (the direct-varint set *is* those fields).
  Identity remains NOT PROVEN; three routes now closed
  (tensor data 4.20, gap/float encodings 4.20, varints
  here).

## Arm 2 — sister-unit differential: co-determination

95 blob contexts carry two 22-burst units (44 champion
bursts). Comparing position-by-position:

- Lane 0 and the `0x0250` const are equal at **every**
  position in **every** pair (1.000).
- **Co-determination law: at all 22 positions, datum
  equality and (lane0+lane1) equality coincide exactly** —
  zero cases of same-header-different-datum and zero of
  same-datum-different-header across 95 × 22 comparisons.
  Within sister units, the operand word and the datum are
  functions of a common key.
- The special pair (positions 10–11) is the most conserved
  region: full equality 0.474, with enum and ladder fields
  at 1.000 — sisters differ there at most in flags/datum,
  together.
- Second half (12–21): ladder is sister-invariant (1.000)
  while the enum varies (0.28–0.94) — the slot set belongs
  to the unit, the enum to the burst.
- Units are otherwise near-total variants (pairs differ at
  20 or 22 of 22 positions typically); channel sequences
  vary per unit.

## Arm 3 — replicated-scalar (0x28xx) distribution

- Blob: 625 of 656 non-champion 0x28 bursts are exact ×4
  u16 replications; 172 distinct scalars. Leaders:
  `0x7ffe` ×264 (66 contexts, 1–11 per context), `0x4000`
  ×66, `0x8282` ×22 — exactly once in each of 22 contexts.
  100 of 124 contexts carry the class; per-context counts
  favour even numbers (8, 4, 2, 16 lead).
- MiniLM: only 6 such bursts (4 contexts), all exact ×4,
  scalars tiny (`0x42, 0x48, 0x4e, 0x53, 0x67`) — a
  different regime from the blob's `0x4000–0x82xx` cluster.
- The scalar set is **disjoint from the datum pool**
  (0/172) and from op-direct varints (0/172). 31
  non-replicated remainder bursts carry only 4 distinct
  lane-1 words.
- What the scalars *are* stays unproven; the behaviour —
  one value repeated across the whole operand word, at
  structured per-context counts — is recorded.

## Evidence boundary

All counts exact over the stated populations. The
co-determination law is stated for sister units in one
artifact; corpus-wide testing is queued (slice 4.22),
together with: what splits the conserved 10–11 pairs from
the rest, and whether the datum-as-function-of-header
holds across contexts.
