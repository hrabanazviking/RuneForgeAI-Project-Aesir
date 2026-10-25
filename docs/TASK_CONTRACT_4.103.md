# TASK_CONTRACT_4.103 — Slice 4.103 (AES-NUM-103)
**Scope (host/artifact analysis only, no physical child):**
Definitions (ff scan, trains, camps, middles, neighbourhood
form) are exactly as in TASK_CONTRACT_4.102 / hef102.py:
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
ff000000. AES-NUM-102 established the DENSE-zero run
census over offset sets: 15 maximal runs of DENSE-zero
offsets spaced exactly 4 apart at both group and
(group, cidx) level — 14 of length exactly 4 and 1 of
length 3 ((0a0d378c, 20, 32752) cidx 44 at
17348..17356) — covering 59 of the 64 DENSE zeros,
leaving exactly 5 singletons (in no run of length
>= 2). AES-NUM-098/099/101/102 established the region-0
block (aligned span 6184..6912, 182 aligned words, 26
units of 7 words; families 0/1/2 = units 0-7 / 8-16 /
17-25; head positions = word positions 0..3 within a
unit, tail positions = 4..6): every camp segment
carries exactly ONE distinct family-1 head word over
its 36 head slots and exactly ONE distinct family-2
head word over its 36 head slots (its labels), family
0 constant ffffff7f, all tails constant per family.
consA / consB are the per-byte majority consensus
segments of camps A / B (hef102 consensus(): at each
byte position the most common byte across the camp's
segments; lengths 21392 / 21648).
1. The 5 singleton DENSE zeros and the length-3 run —
   maximal raw ff000000 run anatomy for all 64 DENSE
   zeros. The raw segment of a candidate is its own
   (group, cidx) instance's segment bytes, re-read
   from the artifact exactly as in the whole-arm
   collection. A maximal raw ff-run containing q is
   the maximal interval of consecutive aligned offsets
   (step 4) around q whose words are all exactly
   ff000000, clipped at the segment's edges.
   (a) Singleton identification: from the whole
   population, the DENSE zeros in no (group, cidx)
   offset-set run of length >= 2 at spacing 4 (the
   AES-NUM-102 census definition) — expected exactly
   5; list each (group, q, cidx, mask, value,
   neighbourhood word-tuple).
   (b) For each singleton: the raw aligned words at
   offsets q-16 .. q+16 step 4 stated verbatim; its
   maximal raw ff-run (start, end, length, position
   of q inside it, 0-based); the words immediately
   flanking the run.
   (c) The length-3 run: its 3 members (group, q,
   cidx, mask, value, neighbourhood) — expected the
   (0a0d378c, 20, 32752) cidx 44 run at
   17348..17356 — the raw aligned words at
   17332..17372 step 4 of its instance stated
   verbatim, its maximal raw ff-run, and its
   flanking words.
   (d) All-64 anatomy: for every DENSE zero, its
   maximal raw ff-run (start, end, length, position
   of q inside it); the distribution of raw run
   lengths over the 64 zeros; how many DISTINCT
   maximal raw runs the 64 zeros fall into, with
   their (group, cidx, start, end, length) list;
   the agreement between raw-run classification
   (singleton iff its raw run has length 1) and the
   AES-NUM-102 offset-set classification (singleton
   iff in no offset run of length >= 2), with every
   disagreement listed individually. A DENSE zero at
   q whose raw word is not ff000000, or a run member
   whose raw interval differs, is a finding to state,
   not to hide. Run-site / singleton selection is
   credited only if an exact law is measured in the
   stated populations; anything less is a measured
   distribution, mechanism NOT PROVEN.
2. The fam1/fam2 label pair within a segment. For
   each of the 25 camp segments (camp A x13, camp B
   x12, in the hef99 camp order with cidx stated):
   label1 = the segment's single distinct family-1
   head word, label2 = its single distinct family-2
   head word (verify each family contributes exactly
   one distinct word per segment; any segment failing
   that is listed and excluded from the pair hunts
   with the reason stated).
   (a) The 25 pairs: (camp, segidx, cidx, label1,
   label2) stated in full; distinct label1 count,
   distinct label2 count, distinct pair count, per
   camp and pooled; whether label1 values repeat
   across camps and whether label2 values repeat
   across camps.
   (b) Byte anatomy of the pairs: per camp and
   pooled, the distinct values of each byte position
   (0..3) of label1 and of label2; which byte
   positions are constant in scope; label1 low3
   (bytes 1..3) groups and their sizes.
   (c) As-function hunts, with the AES-NUM-100
   degeneracy ruling applied throughout (a hit on a
   constant byte, or a hit whose determining side is
   injective in scope, is recorded as DEGENERATE and
   never credited as a law): label2 byte j as a
   function of label1 byte k, for all (k, j), per
   camp and pooled — mixed-key counts and the number
   of segments covered by the largest key class;
   label2 full word as a function of label1 full
   word and of label1 byte 0 (recorded, degenerate
   if injective); label1 byte 0 as a function of
   label2 bytes, symmetrically for byte 0 only.
   (d) Affine hunts: for each scope (camp A, camp B,
   pooled) and each (k, j): whether constants
   a, c exist with label2_byte_j == a * label1_byte_k
   + c (mod 256) on EVERY segment of the scope, with
   a != 0 required for a non-degenerate hit, plus
   the XOR form label2_byte_j == label1_byte_k XOR c
   on every segment. Every hit is listed with its
   (scope, k, j, a, c); scopes where a byte is
   constant are marked degenerate for that byte.
   (e) Whole-word relations: the distribution over
   the 25 segments of label1 XOR label2 (as 4-byte
   words) — distinct count; of the u32 little-endian
   difference label2 - label1 (mod 2^32) — distinct
   count; whether either is constant in any scope.
   What the labels encode remains NOT PROVEN unless
   an exact non-degenerate law above lands.
3. Positional law on the consensus-camp pair. The
   positional law of AES-NUM-099/100/101/102 and the
   method of pos_scope101 in hef101_arms.py (direct
   census; prediction per (a, s) through the B-side
   position sets; out-of-range by bisect over sorted
   position lists; shifts -128..+128) apply unchanged.
   The law is credited for a string pair only if
   predicted == census at EVERY (x, y, s) with zero
   differing triples; out-of-range position pairs are
   counted, not hidden.
   (a) The pair: A = consA_seg (camp A consensus,
   length 21392), B = consB_seg (camp B consensus,
   length 21648), full untrimmed segments.
   Report: lengths, distinct byte counts, ordered
   pairs with >= 1 in-range tally, total tallies,
   differing triples (count and first 20),
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
   tallies, 0 differing). If a control fails, that
   arm's results are not credited.
**Artifacts:** 7 HEF corpus on Mimir as previously located.
**Deliverables:** evidence doc, ledger row AES-NUM-103, TODO update, progress doc, state update, commit/push to yrsa/finish-line-roadmap, verify remote==local.
**Boundaries:** No physical run. No invented CCW/numerical values. Record NOT PROVEN.
