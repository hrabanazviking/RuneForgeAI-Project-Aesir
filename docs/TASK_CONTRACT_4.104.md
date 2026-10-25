# TASK_CONTRACT_4.104 — Slice 4.104 (AES-NUM-104)
**Scope (host/artifact analysis only, no physical child):**
Definitions (ff scan, trains, camps, middles, neighbourhood
form) are exactly as in TASK_CONTRACT_4.103 / hef103.py:
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
exactly or no arm is credited. A DENSE zero is a
candidate of that population with form DENSE and value
(seg[q+1]) 0; its word at q is therefore exactly
ff000000. AES-NUM-103 established: exactly 5 offset-set
singleton DENSE zeros and 59 run members (offset-set
runs at spacing 4, (group, cidx) level); maximal raw
ff-runs over the 64 zeros number 20 distinct (15 of
length 4, 5 of length 1), raw classification agreeing
with offset classification 64/64; and the one anomaly:
the raw run 17344..17356 in instance (0a0d378c, 20,
32752) cidx 44 contains only 3 candidates (at 17348,
17352, 17356) — the raw word at 17344 is ff000000 in
that instance yet is not a whole-population candidate
there, while the sister group (0a0d378c, 20, 32688)
cidx 8 carries all four candidates on the same raw
interval. The common-arm population is the hef95
(i)(a) population: for the same 18 unique groups, at
each common offset of the group, one record per group
instance (cidx, ng, ngidx, value = seg[p+1], form,
mask, neighbourhood, per-ng prediction where the
per-ng forms of an ALLOTH object exist).
1. The candidate-less raw word at 17344.
   (a) Common-offset test: for the group (0a0d378c,
   20, 32752), state its common offsets (the
   group_commons list), its instances (cidx, ng,
   ngidx in group order), and whether 17344 is a
   common offset of the group. For each instance,
   state the common-arm record at 17344 verbatim:
   value, z, form, mask, neighbourhood word-tuple,
   and the per-ng prediction from the ALLOTH object
   whose target offset is 17344 itself (per_ng_forms
   of that object; if no such object exists, state
   that and use no prediction). State whether the
   cidx 44 instance's record at 17344 is a DENSE
   zero in the common-arm sense (form DENSE and
   value 0).
   (b) Edge exclusions at the other raw runs: for
   each of the 20 distinct maximal raw runs of
   AES-NUM-103 (group, cidx, start, end, length, in
   that study's sorted order), enumerate every
   aligned offset p in [start, end] and classify it:
   whole-population candidate of that (group, cidx)
   or not; if not, whether p is a common offset of
   its group. Report per run: positions total,
   candidates total, missing positions with their
   classification. Report corpus totals: raw
   positions over all 20 runs, candidate positions,
   missing positions, and how many missing positions
   are common offsets. Also state, for each run,
   the raw words at the edge offsets start-4 and
   end+4 (where in-segment) verbatim, and whether
   either edge offset carries a whole-population
   candidate or is a common offset in that instance.
   The exclusion at 17344 is credited as EXPLAINED
   (by the common-offset definition of the whole
   population) only if (a) shows 17344 is a common
   offset; whether the same exclusion recurs at any
   other raw-run position is exactly the (b) census
   result, stated as measured — no mechanism beyond
   the population definition is credited.
   (c) Common-arm DENSE-zero census: over the 18
   unique groups, at their common offsets, count
   the common-arm records in total, by form, and
   with value 0 by form; list every common-arm
   DENSE zero (group, p, cidx, mask) in full. State
   whether the (0a0d378c, 20, 32752) cidx 44 record
   at 17344 is among them. This bounds what
   "candidate-less" means: absence from the whole
   (non-common) population, presence or absence in
   the common-arm population stated as measured.
2. Singleton neighbourhoods vs run-member
   neighbourhoods. Populations: the 5 offset-set
   singleton DENSE zeros and the 59 offset-set
   run-member DENSE zeros of AES-NUM-103 (offset-set
   runs at spacing 4, (group, cidx) level, exactly
   as in hef103_arms). For each DENSE zero its
   neighbourhood word-tuple is re-derived from its
   own instance's raw segment (words at q-8, q-4,
   q, q+4, q+8).
   (a) Per population: mask histogram; tuple
   distinct count; the list of singleton tuples in
   full (already in AES-NUM-103, restated here for
   the comparison); group distribution and cidx
   distribution.
   (b) Per relative position d in {-8, -4, +4, +8}
   (the centre word is ff000000 in both populations
   by definition): distinct word count per
   population, zero-word (00000000) count per
   population, the most common word and its count
   per population.
   (c) Intersection: how many word values appear at
   a given relative position in BOTH populations,
   per position; how many full tuples are shared
   between the populations.
   (d) Exact-separation hunt: per relative position,
   every word value present in ALL 5 singletons and
   in NO run member, and every word value present in
   ALL 59 run members and in NO singleton; likewise
   for the mask (a mask taken by all of one
   population and none of the other). A distinguishing
   law is credited only on such an exact separation
   in the stated populations; anything less is a
   measured distribution, distinction NOT PROVEN.
3. Label values vs segment cidx arithmetic. The 25
   camp segments and their labels are exactly as in
   AES-NUM-103 arm (ii): (camp, segidx, cidx, label1,
   label2) from seg_fam_vals99, every segment carrying
   exactly one distinct family-1 and one distinct
   family-2 head word (any segment failing that is
   listed and excluded, as in 4.103). Determiners:
   cidx (used mod 256 in the arithmetic forms),
   segidx (the camp-internal rank), and pooled rank
   (0..24 in the campsegs99 order, camp A first).
   Scopes: camp A, camp B, pooled. The AES-NUM-100
   degeneracy ruling applies throughout (a hit on a
   constant target byte, or a hit whose determining
   side is injective in scope, is recorded as
   DEGENERATE and never credited as a law).
   (a) The determiner census per scope: cidx values
   in segment order, distinct cidx count, whether
   cidx is injective in scope; segidx range.
   (b) As-function hunts: each label byte (label1
   bytes 0..3, label2 bytes 0..3) and each full
   label word as a function of cidx and of segidx,
   per scope — function true/false, mixed-key count,
   and the degeneracy flag (injective determiner or
   constant target).
   (c) Affine hunts: for each scope, each determiner
   in {cidx mod 256, segidx, pooled rank (pooled
   scope only)}, and each label byte: whether
   constants a, c exist with byte == a * det + c
   (mod 256) on EVERY segment of the scope, a != 0
   required for a non-degenerate hit, plus the XOR
   form byte == det XOR c on every segment. Every
   hit is listed with (scope, determiner, byte, a,
   c); a hit whose target byte is constant in scope
   is marked degenerate.
   (d) Difference census: per scope, per determiner
   (mod 256), per label byte: the distinct count of
   (byte - det) mod 256 and of byte XOR det over
   the scope's segments; whether either is constant
   (which is the (c) a=1 / XOR hit restated).
   What the labels encode remains NOT PROVEN unless
   an exact non-degenerate law above lands.
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
   tallies, 0 differing); AES-NUM-102 headline
   counts: the run group (0a0d378c, 16, 32776)
   carries exactly 4 DENSE zeros at 28760..28772 in
   the single instance cidx 5, corpus run census 15
   maximal runs at spacing 4 identical at group and
   (group, cidx) level (14 of length 4, 1 of length
   3), 59/64 DENSE zeros in runs and 5 singletons,
   block variation constant 110 / varying 72 in camp
   A, camp B and pooled with every varying index
   label-exhausted in both camps, positional law
   exact on B0 x A0 (7,021 pairs, 5,489,488 tallies,
   0 differing) and B0 x B1 (7,044 pairs, 5,547,024
   tallies, 0 differing); AES-NUM-103 headline
   counts: the 5 singletons are raw singletons
   (maximal raw ff-run length 1 each), classification
   agreement 64/64 with 0 disagreements, raw word
   ff000000 for 64/64, raw-run lengths over the
   zeros {1: 5, 4: 59} over 20 distinct raw runs,
   position-in-run {0: 19, 1: 15, 2: 15, 3: 15}, the
   length-3 run is a raw run of 4 at 17344..17356
   whose first word carries no candidate in its
   instance, label pair 25 distinct pairs with no
   cross-camp repeats, affine/XOR hits 0, positional
   law exact on consA x consB (7,011 pairs,
   5,489,488 tallies, 0 differing). If a control
   fails, that arm's results are not credited.
**Artifacts:** 7 HEF corpus on Mimir as previously located.
**Deliverables:** evidence doc, ledger row AES-NUM-104, TODO update, progress doc, state update, commit/push to yrsa/finish-line-roadmap, verify remote==local.
**Boundaries:** No physical run. No invented CCW/numerical values. Record NOT PROVEN.
