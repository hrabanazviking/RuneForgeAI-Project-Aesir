# TASK_CONTRACT_4.100 — Slice 4.100 (AES-NUM-100)
**Scope (host/artifact analysis only, no physical child):**
Definitions (ff scan, trains, camps, middles, neighbourhood
form) are exactly as in TASK_CONTRACT_4.99 / hef99.py:
neighbourhood of an aligned offset p in a segment = the
five aligned 4 B words at p-8, p-4, p, p+4, p+8; zero
count z = number of those words equal to 00000000;
SPARSE z >= 3, MID z == 2, DENSE z <= 1. Camps are the
76c3a8ff position-18 camps (A 21392 x13, B 21648 x12);
CPFX {2:132, 8:148, 22:204, 26:204}, suffix 172. The
whole non-common population is exactly the hef95/96/99
whole-arm population: candidates (aligned ff-pattern
offsets q in an instance's own segment, q not a common
offset of its group) over the 18 unique (artifact,
position, size) groups behind the 26 non-step OTHER
offsets, with a defined neighbourhood — 7,484 candidates
with form counts SPARSE 2,280 / MID 2,306 / DENSE 2,898
and form x zero counts SPARSE 144, MID 21, DENSE 64;
those counts must reproduce exactly or no arm is
credited. AES-NUM-099 established exactly 22 zero
(mask, offset) pairs in the SPARSE population, pairwise
disjoint across masks, at offsets 6180, 7632, 10824,
18744, 26040, 26104, 26184, 26944, 27408, 27496, 27520,
27552, 28016, 28768, 29336, 30136, 30168, 30704, 31248,
31536, 28964, 29156 (the 22 offsets are distinct).
1. The 22 zero offsets across all forms. Re-collect the
   whole non-common population WITH form, mask (the
   5-bit zero pattern of the neighbourhood words in
   order, 1 = zero word) and value (byte 1 of the ff
   word at q) per candidate; the re-collection must
   match the hef99 whole-arm form x zero counts exactly
   (7,484 candidates; SPARSE 2,280/144, MID 2,306/21,
   DENSE 2,898/64) or this arm is not credited.
   (a) Per zero offset q (22, sorted): the candidates
   at q by form — per form the total, zero and
   non-zero counts; the mask histogram per form; the
   distinct groups presenting at q per form.
   (b) Aggregates over the 22 offsets: total DENSE and
   MID candidates at the zero offsets, their zero
   counts, how many of the 22 offsets carry >= 1
   DENSE candidate, >= 1 MID candidate, >= 1 DENSE/MID
   zero; the per-offset DENSE/MID value multisets.
   (c) Control offsets: the same census at every other
   offset that carries >= 1 SPARSE candidate (the
   non-zero SPARSE offsets) — total DENSE/MID
   candidates and zeros there, for comparison.
   Mask-exclusivity (AES-NUM-099) is extended to
   form-exclusivity only if the stated populations
   show it exactly; anything less is a measured
   distribution, mechanism NOT PROVEN.
2. Family-1/2 label values vs segment metadata
   (consensus camps consA / consB and the individual
   camp segments segsA / segsB as in hef99; region 0 =
   the first ff-delimited region of each consensus
   camp, offsets 0..8224; the block is the aligned
   span 6184..6912, families 0 / 1 / 2 = units 0-7 /
   8-16 / 17-25, head positions = word positions
   0..3). AES-NUM-099 established each (segment,
   family) head population is a single constant:
   family 1 and family 2 give one label word per
   segment (25 segments). Segment metadata, stated
   exactly as collected per segment: camp (A/B),
   camp-internal rank (index in the camp's sorted
   segment list), cidx, ng index of its context, ngidx
   (cidx - ng_first[ng] + 1), action count of its
   context, the position-18 action's (offset, size,
   channel).
   (a) The label table: per camp, per segment in
   segment order — metadata + family-1 label +
   family-2 label (full word and per-byte values).
   (b) Stated-function tests, each credited only if
   exact over the stated population (per camp and
   pooled, per family): label byte k (k = 0..3) as an
   affine function mod 256, byte = (a * X + b) mod 256
   for some a, b, of X in {cidx, camp-internal rank,
   ngidx}; label byte k as a function (any mapping)
   of X in {cidx mod m for m in 2..16, camp, segment
   size, channel}; monotonicity of each label byte
   and of the full label word (as a big-endian and as
   a little-endian integer) in cidx order and in
   rank order (number of inversions).
   (c) Cross-family stated functions: per segment,
   whether fam2 byte k is an affine function mod 256
   of fam1 byte j for some (j, k, a, b) exact over the
   population; whether fam1 XOR fam2 and fam2 - fam1
   (byte-wise and full-word) are constant per camp or
   pooled; whether the fam1/fam2 label sets' byte
   distributions differ by a stated constant shift.
   What the labels encode is NOT PROVEN unless an
   exact stated law above passes with no
   counterexample in the stated population; a merely
   bijective labelling (established in AES-NUM-099)
   is not a stated function.
3. Positional law on the ungrown ranks and in the
   reverse direction. The positional law of
   AES-NUM-099 arm (iii): for two byte strings A, B,
   the lag census of an ordered byte pair (x, y) at
   shift s in -128..+128 counts (i, j) with A[i] == x,
   B[j] == y, j - i == s; the prediction from the
   position lists posA(x), posB(y) counts (a, b) in
   posA x posB with b - a == s. The law is credited
   for a string pair only if predicted == census at
   EVERY (x, y, s) with zero differing triples;
   out-of-range position pairs are counted, not
   hidden.
   (a) Ungrown ranks: for every region index ri of
   the consensus camps that is NOT in CPFX {2, 8, 22,
   26} and where both camps' regions are non-empty,
   take A = camp A's region ri bytes and B = camp
   B's region ri bytes (the full untrimmed regions,
   re-derived from the ff offsets of each camp) and
   run the full census-vs-prediction test per region:
   distinct byte counts, ordered pairs with >= 1
   in-range tally, total tallies, differing triples
   (count and first 20), out-of-range totals.
   (b) Reverse direction on the grown middles: for
   each grown rank k in {2, 8, 22, 26}, swap the
   roles — A' = the B middle, B' = the A middle —
   and run the full test per rank and pooled: same
   reporting as (a), plus the six AES-NUM-096
   copy-span substitution pairs stated individually
   in the reverse direction (census shift set,
   predicted-equal, out-of-range count).
   (c) Grown-direction control: the AES-NUM-099
   arm (iii) result must reproduce in the same run
   (602 ordered pairs, 131,360 tallies, 0 differing
   triples, out-of-range 24,544 over 269 pairs).
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
   269 pairs). If a control fails, that arm's
   results are not credited.
**Artifacts:** 7 HEF corpus on Mimir as previously located.
**Deliverables:** evidence doc, ledger row AES-NUM-100, TODO update, progress doc, state update, commit/push to yrsa/finish-line-roadmap, verify remote==local.
**Boundaries:** No physical run. No invented CCW/numerical values. Record NOT PROVEN.
