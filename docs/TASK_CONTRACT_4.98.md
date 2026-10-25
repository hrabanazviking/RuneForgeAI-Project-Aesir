# TASK_CONTRACT_4.98 — Slice 4.98 (AES-NUM-098)
**Scope (host/artifact analysis only, no physical child):**
Definitions (ff scan, trains, camps, middles, neighbourhood
form) are exactly as in TASK_CONTRACT_4.97 / hef97.py:
neighbourhood of an aligned offset p in a segment = the
five aligned 4 B words at p-8, p-4, p, p+4, p+8; zero
count z = number of those words equal to 00000000;
SPARSE z >= 3, MID z == 2, DENSE z <= 1. Camps are the
76c3a8ff position-18 camps (A 21392 x13, B 21648 x12);
CPFX {2:132, 8:148, 22:204, 26:204}, suffix 172. The
sparse non-common population is exactly the hef96/97
population: candidates (aligned ff-pattern offsets q in
an instance's own segment, q not a common offset of its
group) over the 18 unique (artifact, position, size)
groups behind the 26 non-step OTHER offsets, with a
defined neighbourhood, SPARSE — 2,280 candidates, of
which F (value == 0) = 144, with mask counts
{01011: 1088/6, 10011: 549/108, 11011: 348/30,
11001: 61/0, 11010: 234/0} (total/zero); those counts
must reproduce exactly or no arm is credited.
1. Per-mask x group/offset anatomy of the sparse zeros:
   mask = the 5-bit zero pattern of the neighbourhood
   words in order (p-8, p-4, p, p+4, p+8), 1 = zero word.
   (a) For every mask that occurs: per-group table
   (group key = (artifact, position, size)): candidate
   count, zero count, non-zero count, zero rate, for
   every group holding >= 1 candidate of that mask.
   (b) For every mask: per-offset table (offset q):
   candidate count, zero count, zero rate, for every
   offset holding >= 1 candidate of that mask.
   (c) For every mask: the zero sub-population's
   distinct groups, distinct offsets, and distinct
   (group, offset) pairs (counts and the lists), and
   the same distinct counts over all candidates of
   that mask; the share of the mask's zeros carried
   by the two groups (0856a10c, pos 9, size 32712) and
   (0856a10c, pos 10, size 32712) — F overall carries
   106/144 there per AES-NUM-096 — stated per mask.
   (d) Cross-mask overlap: for each pair of the three
   zero-bearing masks {10011, 11011, 01011}: shared
   groups, shared offsets, and shared (group, offset)
   pairs among their ZERO sub-populations, and among
   their full candidate populations.
   A concentration law is credited only if exact (no
   counterexample) in the stated population; anything
   less is a measured distribution, law NOT PROVEN.
2. Region-0 36-occurrence data-block anatomy (consensus
   camps consA / consB as in hef97; region 0 = the
   first ff-delimited region of each consensus camp,
   offsets 0..8224 per AES-NUM-097 — re-derived):
   the block is the aligned span 6184..6912 (728 B,
   182 aligned words = 26 units of 7 aligned words),
   delimited by the first and last offsets of the
   words counted 36 / 32 / 27 times in region 0 in
   AES-NUM-097 (ffffff7f x32 from 6184; the two
   camp-specific x36 words from 6408 and 6660; the
   00020000 word x27 ending at 6656; block end 6912
   is the end of the 26th 28 B unit from 6184).
   (a) Per camp: every distinct word value in the
   block with its count and its aligned offsets;
   and specifically the four named populations
   (ffffff7f, 00020000, and the camp's two x36 words)
   with offset lists, gap histogram between
   consecutive offsets, first / last offset, span.
   (b) Unit decomposition: the block as 26 units of
   7 aligned words (unit u = offsets 6184+28u ..
   6184+28u+24, u = 0..25): per camp, the 7-word
   pattern of every unit, the distinct unit patterns
   with their unit indices, and per word-position
   (0..6 within the unit) the distinct values with
   counts across the 26 units.
   (c) Per-segment unanimity: for each camp, at every
   aligned block offset, how many of the camp's
   individual segments (13 A, 12 B) carry the
   consensus word there — the distribution of that
   count over the 182 offsets, the offsets (if any)
   where it is not unanimous, and the same count
   restricted to the offsets of the two x36 words.
   What the block or its words encode is NOT PROVEN
   unless an exact stated law passes with no
   counterexample.
3. The 20>3e shift set (consensus middles per grown
   rank as in hef97; the pair is the ordered byte
   pair (0x20, 0x3e), A-side byte first, counted as
   in AES-NUM-097 arm (iii) over shifts -128..+128
   pooled over the four grown ranks):
   (a) Per rank: the positions of byte 0x20 in the
   A middle and of byte 0x3e in the B middle (full
   position lists and counts), pooled over ranks.
   (b) Predicted shift multiset: for every
   (rank, a-position of 0x20, b-position of 0x3e)
   triple, shift = b - a; the predicted count of
   the (20,3e) pair at each shift in -128..+128 is
   the number of triples at that shift. Compare
   predicted vs the re-derived census count at
   EVERY shift: list every shift where they differ,
   and list every triple whose shift falls outside
   -128..+128 (with its shift). The prediction is
   exact only if predicted == census at all 257
   shifts.
   (c) The +31 doubling: every triple contributing
   at shift +31 (rank, a-position, b-position),
   grouped per rank, stating what multiplicity
   (extra A 0x20 position, extra B 0x3e position,
   or both) makes the pooled count 8 instead of 4.
   (d) The full 21-shift set of AES-NUM-097 must
   reproduce as exactly the in-range shifts with
   predicted count > 0, or the difference is stated.
   An exact positional law is credited only if (b)
   passes with zero differing shifts; anything less
   is a measured count, law NOT PROVEN.
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
   counts: mask table above, region 0 = 2,056
   aligned words / 02-count 150 / distinct 104 per
   camp, 89/82 words unanimous singletons at
   1512/1516, six-pair totals s = 0: 28 and
   s = +64: 44, 20>3e at exactly 21 shifts (x4, x8
   at +31), a9>3e at exactly shifts -16 and +64.
   If a control fails, that arm's results are not
   credited.
**Artifacts:** 7 HEF corpus on Mimir as previously located.
**Deliverables:** evidence doc, ledger row AES-NUM-098, TODO update, progress doc, state update, commit/push to yrsa/finish-line-roadmap, verify remote==local.
**Boundaries:** No physical run. No invented CCW/numerical values. Record NOT PROVEN.
