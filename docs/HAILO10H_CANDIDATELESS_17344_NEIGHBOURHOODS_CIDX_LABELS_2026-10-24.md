# AES-NUM-104 — the candidate-less word at 17344 is a common offset (exclusion EXPLAINED by the population definition, and it is a common-arm DENSE zero), singleton and run-member neighbourhood value sets are disjoint at every relative position yet no exact separation exists, and the labels share no stated relation with segment cidx arithmetic

Slice 4.104, worked under `docs/TASK_CONTRACT_4.104.md`
(contract committed first @ f9bd0cf1). Host/artifact
analysis only, on Mimir (purpleviking1) — no physical
child, no device run of any kind.

## Run and transfer record

hef104.py was built by the prior firing (sha256
d8f39e45…) and left staged locally with recv104.py
already on Mimir; that firing stopped before the
transfer (the 4.100/4.103 stall pattern). This firing
resumed at the transfer: proxy-upload of hef104.py.gz
(saved:30183; gz sha256 8e7afa54… and script sha256
d8f39e45… verified on-device; py_compile OK), detached
run over the 7-artifact corpus (DONE104, output sha256
211eea01…, 3,411 lines, retrieved byte-complete, gz sha
matched both sides).

Reading the first run's output caught an indexing bug
in arm (ii)'s intersection loop (the loop enumerated
the shortened offset list [-8, -4, +4, +8], so its
"+4" line actually measured the centre word and its
"+8" line measured +4). The one line was patched in
hef104.py / hef104_arms.py (patched script sha256
6c2b10ac…, gz sha256 ad471c3b…; first re-upload attempt
failed because the receiver's port was still held by
the retrieval server — bind exit 1, nothing landed,
file on-device unchanged; the retry landed
saved:30200, both hashes verified on-device,
py_compile OK) and the script was rerun in full
(DONE104, 3,411 lines, output sha256 6e82671f…).
The on-device diff between the two outputs is exactly
the two mis-indexed lines; every other result in this
doc is identical across both runs. The corrected lines
are the ones credited below.

## Controls

All controls reproduce exactly: 128,787 small actions;
79,001 bursts; 745,849 pointer actions; 1,504
contexts; 2,049 trailing pairs; 75,215 champion
bursts; whole-arm candidates 7,690, boundary 0;
non-common candidates 7,484 with form × zero splits
SPARSE 2,280/144, MID 2,306/21, DENSE 2,898/64 —
AES-NUM-029/032…103 headline counts all reproduced
(the full control list is in the contract; no arm
below is credited on a failed control, and none
failed).

## (i) The candidate-less raw word at 17344

(a) **Common-offset test — the exclusion is
EXPLAINED.** For the group (0a0d378c, 20, 32752) the
common offsets are exactly [13664, 17344]; 17344 IS a
common offset of the group, so its absence from the
whole (non-common) population follows from that
population's definition alone — no further mechanism
is needed or credited. The group's instances, in
group order: (cidx 44, ng 0, ngidx 45), (83, 1, 10),
(143, 1, 70), (149, 1, 76), (155, 1, 82), (161, 1,
88), (167, 1, 94). The ALLOTH object whose target
offset is 17344 itself exists; its per-ng forms are
{0: (CONST, 0), 1: (CONST, 1)}. The common-arm
records at 17344, verbatim:

- cidx 44 (ng 0, ngidx 45): value 0, z 0, form
  DENSE, mask 00000, prediction 0, neighbourhood
  (04000a00, a000a280, ff000000, ff000000, ff000000)
  — **a DENSE zero in the common-arm sense: True**.
- cidx 83 / 143 / 149 / 155 / 161 / 167 (all ng 1):
  value 1, z 1, form DENSE, mask 10000, prediction
  1, neighbourhood (00000000, e7ff0100, ff010000,
  77070000, 07000000) — dense-zero False, identical
  record for all six.

(b) **Edge census at the other raw runs — the
exclusion does not recur.** Over all 20 distinct
maximal raw runs of AES-NUM-103: 65 raw positions,
64 candidate positions, exactly **1 missing
position** — 17344 itself — and that one position
is a common offset (missing-that-are-common 1/1).
Every other raw-run position in the corpus carries
a whole-population candidate. For both runs on the
17344..17356 interval (sister cidx 8 and target
cidx 44 alike) the edge words are the same:
edge-below (17340, a000a280, whole-candidate False,
common False), edge-above (17360, 09000a00,
whole-candidate False, common False).

(c) **Common-arm DENSE-zero census.** Over the 18
unique groups at their common offsets: 206 records,
boundary 0; forms DENSE 95 / SPARSE 65 / MID 46;
value-0 by form: DENSE 2, SPARSE 8, MID 0. Exactly
**2 common-arm DENSE zeros** exist in the corpus:
(0a0d378c, 20, 32752) p 17344 cidx 44 mask 00000,
and (MiniLM, 23, 32768) p 9272 cidx 5 mask 01000.
The target record is among them (True). So
"candidate-less" means exactly this: absent from
the non-common population by definition, present in
the common-arm population as one of only two DENSE
zeros there.

## (ii) Singleton vs run-member neighbourhoods

Populations reproduce: 5 singletons, 59 run members.

Singletons: mask histogram {00000: 3, 00010: 2};
5 distinct tuples; groups (0a0d378c, 21, 32560) ×1,
(5ab3537d, 9, 32584) ×1, (MiniLM, 23, 32768) ×3;
cidx {5: 3, 28: 1, 74: 1}. The five tuples are
restated in the run output (identical to
AES-NUM-103's singleton details).

Run members: mask histogram {00000: 59} — every
member's mask is 00000; 40 distinct tuples over
9 groups ((0a0d378c, 20, 32688) ×12, (0a0d378c, 20,
32752) ×11, (0a0d378c, 13, 32600) ×8, (MiniLM, 23,
32768) ×8, (0a0d378c, 16, 32776) ×4, (0a0d378c, 21,
32560) ×4, (5ab3537d, 21, 32776) ×4, (773470cd, 21,
32776) ×4, (cc9b9d1c, 13, 32784) ×4); cidx {0: 4,
3: 8, 5: 4, 8: 12, 44: 11, 74: 4, 76: 8, 95: 8}.

Per relative position (distinct / zero-word count /
most-common word):

| pos | singletons | run members |
|-----|-----------|-------------|
| −8 | 4 / 0 / 01000800 ×2 | 16 / 0 / ff000000 ×30 |
| −4 | 5 / 0 / (all ×1) | 11 / 0 / ff000000 ×45 |
| +4 | 4 / 2 / 00000000 ×2 | 9 / 0 / ff000000 ×44 |
| +8 | 4 / 0 / 01000800 ×2 | 19 / 0 / ff000000 ×29 |

(The centre word is ff000000 in both populations by
definition: 5/5 and 59/59, zero-count 0.)

Intersection (corrected run): the word-value sets
of the two populations are **disjoint at every
relative position** (−8: 4 vs 16, intersection 0;
−4: 5 vs 11, 0; +4: 4 vs 9, 0; +8: 4 vs 19, 0), and
**0 full tuples are shared**.

Exact-separation hunt: at no relative position is
there a word present in ALL 5 singletons and in NO
run member, or in ALL 59 run members and in NO
singleton (all four lists empty at all four
positions); likewise no mask separates the
populations (00000 is taken by 3/5 singletons and
59/59 members; no mask is taken by all singletons).
Under the contract's crediting rule a distinguishing
law requires such an exact separation, so the
distinction is **NOT PROVEN** — what stands is the
measured distribution above: disjoint per-position
value sets and ff-saturated member neighbourhoods
(most-common word ff000000 at every position,
30–45 of 59) against small, varied singleton
neighbourhoods whose only zero words sit at +4
(2 of 5).

## (iii) Label values vs segment cidx arithmetic

All 25 camp segments carry exactly one distinct
family-1 and one distinct family-2 head word (bad
segments: none); the 25 (camp, segidx, cidx, label1,
label2) pairs are listed verbatim in the run output.

Determiner census: cidx is **injective in every
scope** — camp A 13 distinct over 13 segments
([130, 139, 148, 157, 202, 211, 220, 238, 247, 256,
265, 319, 328]), camp B 12/12 ([121, 166, 175, 184,
193, 229, 274, 283, 292, 301, 310, 337]), pooled
25/25 with no cidx repeated across camps; segidx
ranges (0, 12) in A, (0, 11) in B.

As-function hunts: every label byte and both full
label words come back function True against cidx,
segidx and pooled rank in every scope — and every
one is **degenerate** under the AES-NUM-100 ruling
(injective determiner in scope, or constant target
byte: label1 bytes 2–3 and label2 byte 3 are
constant-target in all scopes).

Affine / XOR hunts: **zero** a != 0 affine hits and
**zero** XOR-constant hits for every (scope,
determiner, label byte) combination; difference and
XOR difference distinct counts are never 1 (they
run 9–25 across the table). The arm's summary line:
AFFINE non-degenerate (non-constant-target) hits
total: 0.

What the labels encode remains **NOT PROVEN**: no
stated function of cidx, segidx or pooled rank —
affine, XOR or as-function beyond the degenerate
kind — determines any label byte.

## Grades

- 17344 exclusion: **EXPLAINED** (common offset of
  its group; population definition), and the word
  is a common-arm DENSE zero — one of exactly 2 in
  the corpus. The exclusion recurs at no other
  raw-run position (64/65 candidate, 1/1 missing =
  the common offset).
- Singleton/member neighbourhood distinction:
  measured distributions and per-position disjoint
  value sets; distinguishing law **NOT PROVEN**
  (no exact separation in the contract's form).
- Labels vs cidx arithmetic: **NOT PROVEN** (all
  as-function hits degenerate; affine/XOR hits 0).

## Next (slice 4.105)

(i) The second common-arm DENSE zero — (MiniLM, 23,
32768) p 9272 cidx 5 mask 01000: its group's common
offsets, its instances' records at 9272, and its raw
anatomy, against the 17344 case. (ii) A control for
the disjointness fact of arm (ii): per-position
value-set disjointness measured between other
population splits of the same DENSE zeros (e.g.
run members split by group), to state whether
disjointness at n=5 is itself surprising. (iii)
Label values vs ngidx / ng arithmetic — the segment
metadata not yet hunted (cidx, segidx and pooled
rank are now all closed). Host/artifact analysis
only — no physical child.
