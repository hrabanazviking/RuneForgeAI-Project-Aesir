# TASK_CONTRACT_4.97 — Slice 4.97 (AES-NUM-097)
**Scope (host/artifact analysis only, no physical child):**
Definitions (ff scan, trains, camps, middles, neighbourhood
form) are exactly as in TASK_CONTRACT_4.96 / hef96.py:
neighbourhood of an aligned offset p in a segment = the
five aligned 4 B words at p-8, p-4, p, p+4, p+8; zero
count z = number of those words equal to 00000000;
SPARSE z >= 3, MID z == 2, DENSE z <= 1. Camps are the
76c3a8ff position-18 camps (A 21392 x13, B 21648 x12);
CPFX {2:132, 8:148, 22:204, 26:204}, suffix 172. The
sparse non-common population is exactly the hef96 arm-(i)
population: candidates (aligned ff-pattern offsets q in
an instance's own segment, q not a common offset of its
group) over the 18 unique (artifact, position, size)
groups behind the 26 non-step OTHER offsets, with a
defined neighbourhood, SPARSE — 2,280 candidates, of
which F (value == 0) = 144; those counts must reproduce
exactly or no arm is credited.
1. Mask law test over ALL sparse non-common candidates:
   mask = the 5-bit zero pattern of the neighbourhood
   words in order (p-8, p-4, p, p+4, p+8), 1 = zero word
   (the target bit is always 0: the target is an ff
   word). AES-NUM-096 found F's masks are exactly
   {10011, 11011, 01011} — all ending in 11 (both
   following words zero).
   (a) Per-mask table over the full 2,280: for every
   mask that occurs, candidate count, zero count,
   non-zero count, zero rate.
   (b) Aggregate tests: masks ending in 11 vs not;
   masks in F's exact set {10011, 11011, 01011} vs
   all other masks; masks ending in 11 with at least
   one preceding zero (bits 0/1) vs the rest.
   For each aggregate: zero count, non-zero count,
   zero rate on both sides, and the confusion counts
   of the candidate law "value == 0 iff mask in the
   aggregate's positive class" (true/false positives
   and negatives over the 2,280).
   (c) Per-z breakdown within the ending-in-11 class
   (z = 3 / 4 / 5): candidate and zero counts.
   A law is credited only if exact (no counterexample)
   in the stated population; anything less is a
   measured rate, law NOT PROVEN.
2. Region-0 02-field anatomy (consensus camps consA /
   consB as in hef96; region 0 = the first ff-delimited
   region of each consensus camp, offsets 0..8224 per
   AES-NUM-096 — re-derived, not assumed):
   (a) Aligned-word census of region 0 per camp: number
   of aligned 4 B words, count of 02000000, number of
   distinct word values, and every distinct non-02
   word value with its count and its aligned offsets
   (offset list capped in print only if a value occurs
   more than 40 times; counts always exact).
   (b) 02-runs: the maximal run of consecutive aligned
   02000000 words immediately before the aligned word
   at 1512 and the maximal run immediately after the
   aligned word at 1516 (start, end, length in words
   and bytes, per camp); the longest 02-run in region
   0 per camp; the run-length histogram of 02-runs in
   region 0 per camp.
   (c) The 89 word (89000000 at aligned 1512) and the
   82 word (82000000 at aligned 1516): occurrences in
   each consensus camp (any offset and aligned-only),
   and in the individual camp segments: the value at
   offsets 1512 and 1516 in every segment (13 A,
   12 B) — unanimous or not — plus each word's total
   aligned occurrence count pooled over the segments
   of each camp.
   What the field or the words encode is NOT PROVEN
   unless an exact stated law passes with no
   counterexample.
3. Substitution-pair census at other lags (consensus
   middles per grown rank as in hef96; the six
   copy-span mismatch ordered byte pairs of
   AES-NUM-096: (20,3e), (80,00), (00,10), (a9,3e),
   (02,00), (00,20), A-side byte first):
   (a) For each shift s in -128..+128 (B middle read
   at position i+s against A middle at position i,
   over the overlap, pooled over all four grown
   ranks): occurrences of each of the six pairs,
   their total, and the total mismatch count at
   that shift. Print every shift whose six-pair
   total is > 0, plus the totals for s = 0 and
   s = +64 in full per-pair detail.
   (b) Controls inside the arm: at s = 0 the pairs
   found inside the copy-1 span (A/B positions
   96-111) must be exactly (20,3e) once and (80,00)
   once per rank; at s = +64 the pairs found for
   A positions 112-127 against B positions 176-191
   must be exactly the four copy-2 pairs, once each
   per rank.
   (c) The same six pairs counted within each camp's
   own middle at lag 0 against itself is excluded
   (trivial identity); only A-vs-B alignments count.
   An exact recurrence law is claimed only for a
   shift whose stated pair pattern is exact over
   every compared position in every rank; anything
   less is a measured count, law NOT PROVEN.
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
   distinct (group, offset) pairs, rank-8 window6 hits
   exactly [own position, 1510] in both camps;
   B06/B11 copy mismatches 2 (A 103, 111) and 4
   (A 116, 119, 125, 126) at both k; k=112 chunk =
   B units 7-10 verbatim.
   If a control fails, that arm's results are not
   credited.
**Artifacts:** 7 HEF corpus on Mimir as previously located.
**Deliverables:** evidence doc, ledger row AES-NUM-097, TODO update, progress doc, state update, commit/push to yrsa/finish-line-roadmap, verify remote==local.
**Boundaries:** No physical run. No invented CCW/numerical values. Record NOT PROVEN.
