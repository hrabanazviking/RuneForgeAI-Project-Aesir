# TASK_CONTRACT_4.99 — Slice 4.99 (AES-NUM-099)
**Scope (host/artifact analysis only, no physical child):**
Definitions (ff scan, trains, camps, middles, neighbourhood
form) are exactly as in TASK_CONTRACT_4.98 / hef98.py:
neighbourhood of an aligned offset p in a segment = the
five aligned 4 B words at p-8, p-4, p, p+4, p+8; zero
count z = number of those words equal to 00000000;
SPARSE z >= 3, MID z == 2, DENSE z <= 1. Camps are the
76c3a8ff position-18 camps (A 21392 x13, B 21648 x12);
CPFX {2:132, 8:148, 22:204, 26:204}, suffix 172. The
sparse non-common population is exactly the hef96/97/98
population: candidates (aligned ff-pattern offsets q in
an instance's own segment, q not a common offset of its
group) over the 18 unique (artifact, position, size)
groups behind the 26 non-step OTHER offsets, with a
defined neighbourhood, SPARSE — 2,280 candidates, of
which F (value == 0, value = byte 1 of the ff word at q)
= 144, with mask counts {01011: 1088/6, 10011: 549/108,
11011: 348/30, 11001: 61/0, 11010: 234/0} (total/zero);
those counts must reproduce exactly or no arm is
credited. Mask = the 5-bit zero pattern of the
neighbourhood words in order (p-8, p-4, p, p+4, p+8),
1 = zero word. AES-NUM-098 established exactly 22 zero
(mask, offset) pairs, pairwise disjoint across masks,
with no partial offset in any mask.
1. The 22 zero pairs' neighbourhoods vs same-offset
   other-mask counterparts. Re-collect the population
   WITH its full neighbourhood words (the five aligned
   words per candidate); the re-collection must match
   the hef98 `sn` population exactly (same 2,280
   candidates, same (group, offset, cidx, mask, value)
   multiset) or this arm is not credited.
   (a) The zero pairs: the sorted list of the 22
   (mask, offset) pairs with, per pair, its zero
   candidate count, its distinct groups, and its
   distinct (group) list.
   (b) Per zero pair: among its own zero candidates,
   the distinct full neighbourhood word-tuples (count
   and the tuples), and per neighbourhood position
   (0..4, offsets -8..+8) the distinct word values
   with counts.
   (c) Per zero pair: its same-offset counterparts —
   all candidates at the same offset q whose mask
   differs from the pair's mask: total count, zero
   count, non-zero count, the mask histogram, the
   distinct full neighbourhood word-tuples (count),
   and per neighbourhood position the distinct word
   values with counts; the per-position value-set
   overlap with the zero side (shared / zero-only /
   counterpart-only counts per position), and the
   number of counterpart candidates whose full
   neighbourhood tuple is identical to a zero-side
   tuple at that pair.
   (d) Aggregates over all 22 pairs: total counterpart
   candidates, total counterpart zeros, how many zero
   pairs have >= 1 counterpart, >= 1 counterpart zero,
   and >= 1 identical-tuple counterpart; the
   per-position pooled value-set overlaps.
   A separating law (a neighbourhood feature present
   in all zero candidates at a pair and in no
   counterpart, or vice versa) is credited only if
   exact in the stated population; anything less is a
   measured distribution, mechanism NOT PROVEN.
2. Region-0 data-block per-segment head values as a
   population (consensus camps consA / consB and the
   individual camp segments segsA / segsB as in hef98;
   region 0 = the first ff-delimited region of each
   consensus camp, offsets 0..8224 per AES-NUM-097 —
   re-derived): the block is the aligned span
   6184..6912 (728 B, 182 aligned words = 26 units of
   7 aligned words) per AES-NUM-098: units 0-7 are
   family 0 (consensus head ffffff7f), units 8-16
   family 1 (first x36 head), units 17-25 family 2
   (second x36 head); head positions within a unit
   are word positions 0..3, tail positions 4..6.
   (a) Per camp, per segment (segment index in the
   camp's sorted segment list, with its cidx), per
   family: the head words at every (unit, head
   position) of that family (32 values per segment in
   family 0 = 8 units x 4 positions; 36 values per
   segment in each of families 1 and 2 = 9 units x 4),
   stated exactly as collected: distinct values with
   counts per (camp, segment, family), and whether
   the segment's head value is constant across all
   its units and positions within the family.
   (b) Per camp, per family: the population over
   segments — distinct head values corpus-wide in
   that (camp, family) with per-value segment counts,
   how many values are shared by >= 2 segments, the
   per-segment values listed in segment order, and
   the low-3-byte pattern of each distinct value
   (bytes 1..3 as stored) with its segment count.
   (c) Cross-family and cross-camp structure: per
   segment, whether its family-1 and family-2 head
   values (where not constant, their value sets)
   share any full word or any low-3-byte pattern;
   per camp, the intersection of the family-1 and
   family-2 distinct value sets and low-pattern sets;
   the two camps' family value-set intersections.
   (d) Family 0 control: every segment's family-0
   head words (expected ffffff7f at all 32 slots per
   segment per AES-NUM-098 unanimity) — any deviation
   is stated per segment.
   What the per-segment head values encode is NOT
   PROVEN unless an exact stated law (e.g. a value
   being a stated function of segment identity or of
   another family's value) passes with no
   counterexample in the stated population.
3. Positional-law test for the middles' other byte
   pairs (consensus middles per grown rank as in
   hef98: middles[k] for k in {2, 8, 22, 26}, A middle
   and B middle byte strings; the lag census of an
   ordered byte pair (x, y) at shift s in -128..+128
   pooled over the four ranks counts pairs (i, j)
   with A[i] == x, B[j] == y, j - i == s, as in
   AES-NUM-097 arm (iii)):
   (a) Census by direct enumeration: for every rank,
   every (i, j) with j - i in -128..+128, tally
   (x, y, s). Report the number of distinct byte
   values in the A middles and in the B middles
   (pooled and per rank; whether the per-rank
   position sets of each byte are identical across
   ranks), the number of ordered pairs (x, y) with
   >= 1 in-range tally, and the total tallies.
   (b) Prediction from position sets: for every rank
   and every ordered pair (x, y), the position lists
   posA(x), posB(y); predicted count at shift s =
   number of (a, b) in posA x posB with b - a == s
   and s in -128..+128. Compare predicted vs census
   at EVERY (x, y, s): list every differing triple
   (or its count and the first 20), and every
   position pair whose shift falls outside
   -128..+128 (count per (x, y) aggregated, total).
   The positional law is credited for the middles
   only if predicted == census for all (x, y, s)
   with zero differing triples.
   (c) The six copy-span substitution pairs of
   AES-NUM-096 — (0x20, 0x3e), (0x80, 0x00),
   (0x00, 0x10), (0xa9, 0x3e), (0x02, 0x00),
   (0x00, 0x20) — stated individually: each pair's
   census shift set with counts (in-range), its
   predicted shift set, whether they are equal, and
   its out-of-range triple count.
   An exact positional law is credited only if (b)
   passes with zero differing triples over all
   ordered pairs; anything less is a measured count,
   law NOT PROVEN for the failing pairs (named).
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
   +31 triples (72, 103) and (152, 183) per rank.
   If a control fails, that arm's results are not
   credited.
**Artifacts:** 7 HEF corpus on Mimir as previously located.
**Deliverables:** evidence doc, ledger row AES-NUM-099, TODO update, progress doc, state update, commit/push to yrsa/finish-line-roadmap, verify remote==local.
**Boundaries:** No physical run. No invented CCW/numerical values. Record NOT PROVEN.
