# TASK_CONTRACT_4.101 — Slice 4.101 (AES-NUM-101)
**Scope (host/artifact analysis only, no physical child):**
Definitions (ff scan, trains, camps, middles, neighbourhood
form) are exactly as in TASK_CONTRACT_4.100 / hef100.py:
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
exactly or no arm is credited. AES-NUM-100 established
at the 22 SPARSE-zero offsets: 146 SPARSE candidates
(144 zero; the 2 non-zero are the AES-NUM-099
counterparts at 7632 and 28768) and only 4 DENSE+MID
candidates, of which exactly one is zero: a DENSE
candidate at offset 28768, group (0a0d378c, pos 16,
size 32776), mask 00000, value 0. At 28768 the SPARSE
candidates are 2 (1 zero, 1 non-zero), masks {11011,
10011}, groups (0a0d378c, 20, 32688) and (5ab3537d, 8,
32784).
1. The single DENSE zero at 28768. Re-collect the whole
   non-common population WITH form, mask, value (byte 1
   of the ff word at q), group key and cidx per
   candidate, plus the full neighbourhood words for
   every candidate at q = 28768; the re-collection must
   match the hef100 whole-arm form x zero counts exactly
   (7,484; SPARSE 2,280/144, MID 2,306/21, DENSE
   2,898/64) or this arm is not credited.
   (a) The DENSE zero itself: every DENSE candidate at
   28768 (count, zero count), and for the zero one its
   group key, cidx, mask, value and full neighbourhood
   word-tuple; whether more than one DENSE zero exists
   at 28768 corpus-wide.
   (b) The SPARSE candidates at 28768 stated the same
   way (per candidate: group, cidx, mask, value, zero
   or not, neighbourhood tuple), split zero / non-zero.
   (c) Comparison: per neighbourhood position (0..4)
   the DENSE zero's word vs the SPARSE zero's word(s)
   and vs all SPARSE words at 28768 (shared / DENSE-only
   / SPARSE-only); whether the DENSE zero's full tuple
   equals any SPARSE tuple at 28768; whether the DENSE
   zero's (group, cidx) instance coincides with any
   SPARSE candidate's (group, cidx) at 28768; whether
   the DENSE zero's group appears among the SPARSE-zero
   groups at any of the 22 zero offsets, and among the
   SPARSE groups at 28768.
   (d) Wider placement: of the 64 DENSE zeros in the
   whole population, how many sit at one of the 22
   SPARSE-zero offsets (expected exactly 1, this one);
   the DENSE zero's offset 28768 within its own group:
   the group's other DENSE zeros, if any, with offsets.
   A shared or separating law is credited only if exact
   in the stated populations; anything less is a
   measured distribution, mechanism NOT PROVEN.
2. Family-1/2 label byte0 values vs the segments' own
   block words beyond the head positions (consensus
   camps consA / consB and the individual camp segments
   segsA / segsB as in hef100; region 0 = the first
   ff-delimited region of each consensus camp; the block
   is the aligned span 6184..6912, 26 units of 7 aligned
   words; families 0 / 1 / 2 = units 0-7 / 8-16 / 17-25;
   head positions = word positions 0..3, tail positions
   = word positions 4..6). AES-NUM-099/100 established
   each (segment, family) head population is a single
   constant label word: family 1 byte0 fully varying
   (25 distinct pooled), family 2 bytes 0-1 fully
   varying. Tail slots of a family = its units x tail
   positions (family 0: 24 slots, families 1/2: 27
   slots each); all non-head block slots pooled = 78.
   (a) Tail population: per (camp, segment, family) the
   distinct tail words with counts and whether the
   segment's tail words are constant within the family;
   per (camp, family) the pooled distinct tail words,
   how many are shared by >= 2 segments.
   (b) Verbatim presence: per segment and family,
   whether the segment's own label word (families 1
   and 2) occurs among its own same-family tail words,
   among its own other-family tail words, and among
   all 78 non-head block words; counts of segments
   where it occurs, per family and scope.
   (c) Slot-exact tests: for each tail slot (family-
   relative unit index, tail position) and each byte
   k = 0..3, per camp and pooled: whether label byte0
   == that slot's word byte k for EVERY segment in
   scope, and whether the full label word == that
   slot's word for every segment in scope. Exact hits
   stated individually; all other slots are failures,
   counted.
   (d) Affine / as-function tests, per family (1, 2),
   per scope (camp A, camp B, pooled): label byte0 as
   an affine function mod 256, byte = (a * X + b) mod
   256, and as a function (any mapping), of X = byte k
   of tail slot t of the SAME family (t over the
   family's 27 tail slots, k = 0..3). Every exact hit
   is classified under the AES-NUM-100 degeneracy
   ruling: a hit is degenerate if the label byte is
   constant in scope (it is not, for byte0), if X is
   injective in scope (a function of an injective key
   is a tautology), or if X takes <= 3 distinct values
   in scope; an affine hit is additionally degenerate
   if a == 0. Only a non-degenerate exact hit credits
   a stated function. What the labels encode is NOT
   PROVEN unless such a hit passes with no
   counterexample in the stated population.
3. Positional-law scope test on non-camp segment pairs.
   The positional law of AES-NUM-099/100: for two byte
   strings A, B, the lag census of an ordered byte pair
   (x, y) at shift s in -128..+128 counts (i, j) with
   A[i] == x, B[j] == y, j - i == s; the prediction from
   the position lists posA(x), posB(y) counts (a, b) in
   posA x posB with b - a == s. The law is credited for
   a string pair only if predicted == census at EVERY
   (x, y, s) with zero differing triples; out-of-range
   position pairs are counted, not hidden. Method =
   exactly the AES-NUM-100 (iii)(a) ungrown method
   (direct census; prediction per (a, s) through the
   B-side position sets; out-of-range by bisect over
   sorted position lists).
   (a) Cross-camp pair: A = segsA[0] (camp A's first
   segment in sorted order, length 21392), B =
   segsB[0] (length 21648), full untrimmed segments.
   (b) Within-camp pair: A = segsA[0], B = segsA[1],
   full untrimmed segments.
   Per pair report: lengths, distinct byte counts,
   ordered pairs with >= 1 in-range tally, total
   tallies, differing triples (count and first 20),
   out-of-range totals and the number of ordered pairs
   carrying them.
   (c) Control: the AES-NUM-099 grown-middles pooled
   result must reproduce in the same run (602 ordered
   pairs, 131,360 tallies, 0 differing triples,
   out-of-range 24,544 over 269 pairs).
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
   to forward. If a control fails, that arm's
   results are not credited.
**Artifacts:** 7 HEF corpus on Mimir as previously located.
**Deliverables:** evidence doc, ledger row AES-NUM-101, TODO update, progress doc, state update, commit/push to yrsa/finish-line-roadmap, verify remote==local.
**Boundaries:** No physical run. No invented CCW/numerical values. Record NOT PROVEN.
