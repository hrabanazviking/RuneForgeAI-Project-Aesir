# TASK_CONTRACT_4.102 — Slice 4.102 (AES-NUM-102)
**Scope (host/artifact analysis only, no physical child):**
Definitions (ff scan, trains, camps, middles, neighbourhood
form) are exactly as in TASK_CONTRACT_4.101 / hef101.py:
neighbourhood of an aligned offset p in a segment = the
five aligned 4 B words at p-8, p-4, p, p+4, p+8; zero
count z = number of those words equal to 00000000;
SPARSE z >= 3, MID z == 2, DENSE z <= 1. Mask = the
5-bit zero pattern of the neighbourhood words in order,
1 = zero word. Camps are the 76c3a8ff position-18 camps
(A 21392 x13, B 21648 x12); CPFX {2:132, 8:148, 22:204,
26:204}, suffix 172. The whole non-common population is
exactly the hef100 whole-arm population: candidates
(aligned ff-pattern offsets q in an instance's own
segment, q not a common offset of its group) over the
18 unique (artifact, position, size) groups behind the
26 non-step OTHER offsets, with a defined neighbourhood
— 7,484 candidates with form counts SPARSE 2,280 /
MID 2,306 / DENSE 2,898 and form x zero counts SPARSE
144, MID 21, DENSE 64; those counts must reproduce
exactly or no arm is credited. AES-NUM-101 established:
exactly one DENSE zero sits at a SPARSE-zero offset —
offset 28768, group (0a0d378c, pos 16, size 32776),
cidx 5, mask 00000, value 0, neighbourhood tuple
(ff000000 x4, 01000600) — and that zero's own group
carries 4 DENSE zeros at offsets 28760/28764/28768/
28772. AES-NUM-098/099 established the region-0 block
(aligned span 6184..6912, 182 aligned words, 26 units
of 7 words; families 0/1/2 = units 0-7 / 8-16 / 17-25;
head positions = word positions 0..3 within a unit,
tail positions = 4..6) with 110/182 block offsets
unanimous in the AES-NUM-098 reading, and AES-NUM-101
established the block tails are one constant per
family in all 25 segments while families 1/2 carry a
per-segment label word at the head slots.
1. The DENSE-zero run of four at 28760..28772 in its
   group (0a0d378c, 16, 32776).
   (a) Run members: from the whole population, every
   DENSE zero of that group (offsets, cidx, mask,
   value per zero — expected exactly the four at
   28760, 28764, 28768, 28772), and whether all four
   share one cidx / one instance.
   (b) Neighbourhoods: re-collect, for that group only,
   every candidate at q in 28752..28780 (all forms:
   group, cidx, form, mask, value, neighbourhood
   word-tuple), so the run's boundaries are stated:
   the candidates immediately below 28760 and above
   28772 in the same group, their forms and values.
   (c) Raw segment words: in the run instance's own
   segment (the (group, cidx) instance carrying the
   zeros), the aligned words at offsets 28744..28788
   step 4, stated verbatim; whether the four zero
   words are consecutive aligned words in the raw
   segment, and what words flank them.
   (d) Run census: in the whole population, DENSE-zero
   offset sets per group and per (group, cidx): every
   maximal run of DENSE-zero offsets spaced exactly
   4 apart with length >= 2 (group, cidx or group-
   level, offsets, length); how many runs of length
   >= 3 and >= 4 exist, and whether the 28760..28772
   run is the unique length-4 run. A shared or
   separating law is credited only if exact in the
   stated populations; anything less is a measured
   distribution, mechanism NOT PROVEN.
2. Whole-block per-segment variation census. Block =
   the aligned span 6184..6912 of each individual camp
   segment (segsA x13, segsB x12 as in hef101), 182
   aligned word offsets (word index t = 0..181 at
   block offset 6184 + 4t; unit = t // 7, position =
   t % 7; family by unit as above; head/tail by
   position as above).
   (a) Per camp and pooled over all 25 segments: for
   each of the 182 word indices, the distinct words
   across the camp's segments with counts; how many
   indices are constant (exactly 1 distinct word)
   and how many vary (>= 2), per camp and pooled.
   (b) Breakdown of the varying / constant indices by
   family (0/1/2) and by position class (head 0..3 /
   tail 4..6), per camp and pooled; the full list of
   varying word indices (t, unit, position, family,
   per-camp distinct counts).
   (c) Reconciliation: whether the per-camp constant
   count matches the AES-NUM-098 figure of 110/182
   unanimous block offsets, and if the pooled count
   differs, the stated reason (population difference
   is a finding, not an error to hide).
   (d) For each varying index, whether the distinct
   words are exactly the segments' family label words
   (families 1/2) — i.e. whether variation at that
   index is exhausted by the per-segment label
   population of AES-NUM-099/101 — stated per index
   as label-exhausted or not, with the exceptions
   listed. What the labels encode remains NOT PROVEN.
3. Positional-law completion pairs. The positional law
   of AES-NUM-099/100/101 and the method of
   pos_scope101 in hef101_arms.py (direct census;
   prediction per (a, s) through the B-side position
   sets; out-of-range by bisect over sorted position
   lists; shifts -128..+128) apply unchanged. The law
   is credited for a string pair only if predicted ==
   census at EVERY (x, y, s) with zero differing
   triples; out-of-range position pairs are counted,
   not hidden.
   (a) Reverse cross-camp pair: A = segsB[0] (camp B's
   first segment in sorted order, length 21648),
   B = segsA[0] (length 21392), full untrimmed
   segments — the reverse direction of AES-NUM-101's
   A0 x B0 pair.
   (b) Within-camp B pair: A = segsB[0], B = segsB[1],
   full untrimmed segments.
   Per pair report: lengths, distinct byte counts,
   ordered pairs with >= 1 in-range tally, total
   tallies, differing triples (count and first 20),
   out-of-range totals and the number of ordered
   pairs carrying them.
4. **Controls must reproduce:** 128,787 small actions;
   79,001 bursts; 745,849 pointer actions; 1,504
   contexts; 2,049 trailing pairs; 75,215 champion
   bursts; INBAND (374 groups, OTHER 4 all STEP),
   band X (60 / 3,335, OTHER 0), band Y (27 / 354,
   OTHER 0); S1 OTHER 16, S2b OTHER 10; 26 non-step
   OTHER with per-ng CONST 14 and combined per-ng
   coverage 19, residue exactly 7; trains 52
   (28 / 13 / 11), D(cidx 113) = 249, firsts' D
   3,089, control D 176; camps A 21392 x13 / B 21648
   x12; rank-2 middles lenA 168 / lenB 232 with 21
   aligned mismatches at k = 111 and 4 shared
   distinct units (indices 1-4); AES-NUM-095 headline
   counts: whole-arm candidates 7,690, boundary 0,
   non-common candidates 7,484 with SPARSE zero
   144/2,280, DENSE zero 64/2,898, MID zero 21/2,306;
   AES-NUM-096 headline counts: F = 144 (z3 114/1,932,
   z4 30/348, z5 0 candidates), F masks exactly
   {10011: 108, 11011: 30, 01011: 6}, zeros at 37/869
   distinct (group, offset) pairs, shared-offset zero
   rate 131/1,671, singleton 13/609, rank-8 window6
   hits exactly [own position, 1510] in both camps,
   B06/B11 copy mismatches 2 (A 103, 111) and 4
   (A 116, 119, 125, 126) at both k, k=112 chunk =
   B units 7-10 verbatim; AES-NUM-097 headline
   counts: mask table {01011: 1088/6, 10011: 549/108,
   11011: 348/30, 11001: 61/0, 11010: 234/0},
   region 0 = 2,056 aligned words / 02-count 150 /
   distinct 104 per camp, 89/82 words unanimous
   singletons at 1512/1516, six-pair totals s = 0: 28
   and s = +64: 44, 20>3e at exactly 21 shifts (x4,
   x8 at +31), a9>3e at exactly shifts -16 and +64;
   AES-NUM-098 headline counts: per-offset
   determinism (no partial offset in any mask; 22
   zero (mask, offset) pairs, pairwise disjoint
   across masks), block = 26 units x 7 words with
   exactly 3 unit patterns per camp and 110/182
   unanimous block offsets, 20>3e positional
   prediction exact at all 257 shifts with the
   +31 triples (72, 103) and (152, 183) per rank;
   AES-NUM-099 headline counts: re-collection exact
   (2,280 candidates), counterpart total 2 (both
   non-zero, mask 11011), all 75 (segment, family)
   head cells constant, family 0 = ffffff7f in all
   25 segments (0 deviations), positional law exact
   for all byte pairs (602 pairs, 131,360 tallies,
   0 differing triples, out-of-range 24,544 over
   269 pairs); AES-NUM-100 headline counts: whole
   re-collection exact (7,484; SPARSE 2,280/144,
   MID 2,306/21, DENSE 2,898/64), at the 22 zero
   offsets DENSE+MID candidates 4 with exactly 1
   zero (the DENSE zero at 28768), label stated-
   function hits 501 all degenerate, ungrown
   positional aggregate 36 regions / 4,392,812
   tallies / 0 differing, reverse pooled identical
   to forward; AES-NUM-101 headline counts: exactly
   3 candidates at 28768 (1 DENSE zero, 1 SPARSE
   zero, 1 SPARSE non-zero counterpart), DENSE-zero
   group carries 4 DENSE zeros at 28760..28772, tail
   words constant per family in all 25 segments
   (fam0 00000000, fam1 00020000, fam2 00000000),
   positional law exact on A0 x B0 (5,489,488
   tallies, 0 differing) and A0 x A1 (5,481,232
   tallies, 0 differing). If a control fails, that
   arm's results are not credited.
**Artifacts:** 7 HEF corpus on Mimir as previously located.
**Deliverables:** evidence doc, ledger row AES-NUM-102, TODO update, progress doc, state update, commit/push to yrsa/finish-line-roadmap, verify remote==local.
**Boundaries:** No physical run. No invented CCW/numerical values. Record NOT PROVEN.
