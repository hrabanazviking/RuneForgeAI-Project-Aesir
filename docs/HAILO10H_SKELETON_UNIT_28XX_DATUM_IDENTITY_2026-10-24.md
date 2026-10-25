# Skeleton unit anatomy, 0x28xx lane-1 pattern, datum identity test (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.20 (AES-NUM-020).
Method: hef20.py (sha256 86ba61f9…) on Mimir over the
AES-NUM-017/018 populations (MiniLM, ollama blob
5ab3537d). All counts are over 24-byte channel-1/2
bursts exactly as in AES-NUM-013..019. The skeleton
unit is the 22-burst champion sequence of
AES-NUM-015/019, folded per position (blob contexts
of 44 bursts fold as two units; the single 23-burst
context contributes one unit and one leftover burst).

## 1. The 22-burst unit, per position

**The ladder slot is a palindrome over the unit.**
In MiniLM (6 units) the lane-1 ladder field (pos 3)
is a single value at 19 of 22 positions (two values
at positions 5, 7, 9), and the per-position sequence
is: 0x18f0, 0x18f0, 0x16f0, 0x16f0, 0x14f0, 0x14f0,
0x12f0, 0x12f0, 0x10f0, 0x10f0, **0x2d80, 0x2d80**,
0x10f0, 0x10f0, 0x12f0, 0x12f0, 0x14f0, 0x14f0,
0x16f0, 0x16f0, 0x18f0, 0x18f0 — paired rungs
descending to the special pair at 10–11, then
ascending in mirror. On-ladder fraction is 1.000 at
every position in both artifacts.

**The blob confirms the mirror at scale** (219
units folded): positions 12–21 carry the ascending
half with a single ladder value in 218–219 of 219
units each and a near-pure channel per position
(218/219); positions 0–9 are less rigid (3–5 ladder
values, mixed channels) — the first half differs
between the two units of a 44-burst context where
the second half does not. Position 11 carries the
one recorded anomaly (0x0250 fraction 0.995, one
unit off-ladder), recorded, not smoothed.

**What varies per position is the operand, not the
header.** No position is fully constant in either
artifact. In MiniLM the enum field (pos 1) is a
single value at every position and tracks the
channel (0x1000 on channel 1, 0x2000 on channel 2,
0 at the special pair); the const field (pos 2) is
0x0250 at all 22 positions in both artifacts
(fraction 1.000, the position-11 blob anomaly
excepted). The flag field (pos 0) and the lane-2
datum are the per-context variables: datum
distinct-per-position grows along the unit (MiniLM
2,2,3,3,3,4,4,3,4,5 in the first half), i.e. each
position has a fixed header template and a
layer-specific operand.

**Positions 10–11 are the unit's fixed point.**
They are the only positions whose full burst takes
just 2 distinct values in MiniLM and 2–3 in the
blob (against 21–35 at every other blob position):
the flag/channel variants of §1 of AES-NUM-019,
carrying the two datum constants. At every other
position the datum is a genuine per-layer variable.

## 2. 0x28xx non-champion lane 1: repetition, not alternation

Population: non-champion lane-0 class 0x28xx bursts
in stream order per context — MiniLM 6 bursts in 4
contexts; blob 656 bursts in 100 contexts.

- **No across-burst alternation.** In the blob,
  lane-1 equality at lag 1, 2, 3, 4 is 0.221,
  0.226, 0.229, 0.244 — lag 2 (the alternation lag)
  sits at the same level as every other lag; the
  strict top-2 ABAB pattern covers only 0.40 of
  positions on average, explained by the dominant
  value's frequency. Even/odd lane-1 sets overlap
  by 39 values. Alternation across bursts is
  **refuted** at this population (MiniLM's 6 bursts
  are too few to grade separately).
- **The pattern is inside the burst:** lane 1 is
  dominantly **one u16 value replicated in all
  four slots**. MiniLM: all 6 bursts are exact
  replications (0x42, 0x48, 0x4e, 0x53, 0x67 ×4;
  lane-1 byte-distinct pattern [5,1,5,1,5,1,5,1]).
  Blob: the top lane-1 values are 0x7ffe ×4
  (264/656), 0x4000 ×4 (66), 0x8282 ×4 (22),
  0x127e ×4 (6); the four field-distinct counts
  (175/173/175/174 of 176 lane-1 values) move
  together, and at every lag the four fields'
  equality fractions are identical — the fields
  are one value written four times.
- The lane-2 width law holds here too: bytes
  19–23 zero in 656/656 blob and 6/6 MiniLM
  bursts; blob datum distinct 277.

**Reading:** where the champion burst's lane 1 is
a structured operand record (flags/enum/const/
ladder), the 0x28xx non-champion lane 1 is a
replicated scalar. What the scalar *is* (0x7ffe
sits just below the 0x7fff the AES-NUM-018 blob
families concentrated under) is still not named.

## 3. Datum identity test: negative on all arms

MiniLM only (filesize 11,759,616 B; proto 56,844 B;
1,605 pointer-form actions referencing 9,832,200 B
— the AES-NUM-011 total, cross-checked). The
champion datum pool is 62 u24 values. Controls: 62
deterministic random u24 values (seed 20261025,
pool excluded).

- **T1, tensor-candidate ranges** (all referenced
  ranges except the 24 B channel-1/2 bursts:
  1,452 ranges, 9,828,528 B): pool byte-triples
  (LE or BE) found for **33/62** pool values vs
  **29/62** controls; total occurrences 91 vs 83.
  No enrichment — the pool's triples occur in the
  artifact's other data at chance rate.
- **T1, unreferenced gaps** (19 gaps, 1,870,072 B
  in [zero, filesize); the largest, 1,862,144 B,
  begins immediately after the proto at the zero
  point and is referenced by no pointer-form
  action — a structural datum in itself): pool
  found **14/62** vs control **14/62**;
  occurrences 27 vs 20. No enrichment.
- **T2, proto float32 encodings:** every 4-byte
  window of the proto read as float32, filtered
  to finite 1e-7 < |f| < 1e4, encoded as low-3 /
  high-3 LE bytes and as round(±f · 2^n) for
  n ∈ {8, 12, 16, 20, 23, 24}: 3,858 distinct
  candidate u24 values, pool intersection **0**
  (chance expectation 0.01); neither top-pair
  constant is among the candidates.

**Verdict:** the datum is **not** a copy of the
artifact's tensor-data byte triples and **not**
an encoding of a proto float32 under the tested
encodings. Identity stays **NOT PROVEN**; these
two routes are closed, honestly. Remaining
untested candidate classes: proto *varint* fields
(the datum as an integer parameter of the ops
themselves), and functions of the burst's own
other fields.

## Evidence boundary

Exact counts over the stated populations. The
23-burst blob context's leftover burst is excluded
from the unit fold and counted in the seqlen
distribution. The gap region of §3 is "referenced
by no pointer-form (field-16) action" — other
reference mechanisms are not excluded. No field
is semantically named; the datum identity, the
0x2d80 slot's function, and the replicated
scalar's meaning stay open. Next (4.21): datum
vs proto varint fields (op-parameter identity
test); blob unit-pair differential (why the
first half varies between sister units and the
second half does not); replicated-scalar value
distribution vs burst/context counts.
