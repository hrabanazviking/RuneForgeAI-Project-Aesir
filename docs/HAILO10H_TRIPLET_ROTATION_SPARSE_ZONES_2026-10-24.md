# Triplet rotation, sparse-dose template test, interruption zones (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.62 (AES-NUM-062).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef62.py
(sha256 4c3c8047…) and the labelled follow-up hef62b.py
(sha256 5cfb8b96…). Controls reproduce AES-NUM-029/032…061
EXACTLY (128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts; trailing
distinct (channel, operand) pairs 2,049; champion-headed
bursts 75,215). Transfers were sha-gated gzipped files:
hef62 landed first try (whole-file shas verified
on-device); one hef62b part corrupted deterministically
in re-emission, was rejected by its sha gate, and healed
when re-split at 187 B boundaries (whole-file shas then
verified on-device). Definitions (middle, window, band,
segments) are as in AES-NUM-049…061. A = size 7952,
B = size 32784, C = size 26896 unless a section assigns
letters differently (each reassignment is stated).

## The seam triplet block is a forward rotation — and every 0a0d block runs it backwards

Cc9 cidx 137/138 (AES-NUM-061's 96-fold block), triplet-
only subsequence over (7952, 32784, 26896):

- The dominant rotation is FORWARD, A→B→C→A. Cidx 137:
  forward transitions 213/287 (0.742), reverse 49/287
  (0.171), self 25/287 (0.087); cyclic trigrams
  (ABC/BCA/CAB) carry 0.587 of all trigrams (55–57 each;
  every other trigram ≤13). Cidx 138: forward 187/288
  (0.649), reverse 57/288 (0.198), self 44/288 (0.153);
  cyclic trigram share 0.467. Strict periodicity is
  REFUTED: the full-span categorised pattern matches at
  lag 4 only 0.514 (137) / 0.449 (138), the triplet-only
  subsequence at lag 3 only 0.572 / 0.500 — a dominant
  rotation with interruptions, not a strict cycle. The
  modal gap of every member is 4 actions (44–48 of ~95
  gaps each), and the pattern's head is irregular and
  its tail degrades (138's span ends in a B-run).
- The small-size member sits at the rotation boundary:
  in 137, smalls (121 in span) are preceded by C 83× and
  followed by A 106×; in 138 (137 in span), preceded by
  C 77×, followed by A 115×. The small vocabulary is a
  step-8 band, all values ≡0 mod 8: 137 carries exactly
  the eleven values 6160–6240; 138 carries 6160 plus
  the nine values 6480–6544 (the two bands are disjoint
  above 6160, as AES-NUM-061 found). Channels of all
  three members and of the smalls are spread over
  0/1/2 with no fixed assignment.

The same block at 128/160 dose in 0a0d378c is a
DIFFERENT anatomy in two independent ways:

- At 160 dose (763 class, 32 contexts) and at 128 dose
  (620 class ng 0, 617 class ng 1, 16 contexts each)
  the third member is 25872, not 26896: members
  (7952, 25872, 32784) at exactly 160 (763) or 128
  (620/617) each. With letters A = 7952, B = 25872,
  C = 32784 the dominant transitions are C→B (115 in
  the 763 exemplar), B→A (87), A→C (83) — the REVERSE
  rotation, anti-cyclic share 0.594 (763) / 0.616
  (620); anti-cyclic trigrams (CBA/ACB/BAC) top the
  table. Small vocabularies sit lower: 5504–5560
  step-8 plus 8208 ×20 (763); 5840–5888 step-8
  (620/617).
- 0a0d also holds a true-triplet class with the seam's
  own member set (623 class, 9 contexts: 7952/26896/
  32784 at means 127.4/125.9/126.8) — and it too runs
  REVERSED: dominant transitions C→B 110, A→C 95,
  B→A 91, anti-cyclic share 0.769, anti-cyclic
  trigrams ACB 84 / CBA 82 / BAC 78. Its trigram
  vocabulary is the seam's (Jaccard 0.963 against both
  seam contexts, the same value as 137 vs 138) with
  the weights inverted; its small band is 5648–5704
  step-8. Degraded variants exist in the same class
  family (cidx 23: 32784 collapses to 24, the
  remaining pair alternates A↔B 79/79).
- So member set does not determine rotation: the
  seam's forward rotation is, on this evidence, a
  cc9-seam property; every measured 0a0d block —
  whatever its third member — rotates backwards.
  Rotation direction is a per-block-class invariant
  an encoder must carry, not a corpus universal.

## Sparse doses are not a third template

0856a10c's 24-window class (24 contexts, all 448
actions; AES-NUM-061): the eight full-dose (24)
contexts carry FOUR distinct exact 32016 position
templates in mid indexing — F0 [102…367] at cidx
65/71/77/80, F1 [103…367] at 62/74, F2 [39…371] at
cidx 2 alone, F3 [111…368] at cidx 29 alone. Pairwise
intersections are 1–7 of 24 and no ±1 shift relates
any pair (best 10/24) — F0/F1 form the 102-family and
F3 the 111-family of AES-NUM-061 at family level, but
exact templates are per-context-group, and the shared
tail positions (357–367 range) supply most of the
intersections.

The nine sparse contexts (doses 23, 22, 14, 8, 5, 2,
1, 1, 1) split in two:

- Near-full doses are template SUBSETS: cidx 14
  (dose 23) = F3 minus exactly position 363; cidx 68
  (dose 22) = F0 minus positions 231/264; cidx 83
  (dose 8) ⊂ F0 at template indices 0,1,3,5,7,8,11,12
  — a subsequence, not a prefix. This CORRECTS
  AES-NUM-061's "exact first-8 prefix" wording, which
  does not survive exact re-measurement in the mid
  indexing both slices use.
- True sparse doses (14, 5, 2, 1, 1, 1 at cidx 20, 11,
  26, 17, 23, 56) share no template at all: every
  sparse context's position set is distinct (9/9),
  the pooled sparse intersection is empty, no position
  is reused by more than two sparse contexts (and
  those reuses belong to the near-full subsets), and
  the true-sparse sets intersect every full template
  in ≤4 positions. There is NO third template: sparse
  positions are off-template scatter, one context at
  a time. The seven zero-dose contexts are cidx
  8/35/38/41/47/50/59.

## The interruption zones are one fixed non-cycle block, written twice — and the second writing ends the stream

Cc9's cycle (modal classes by residue, measured
outside the zones) is 259/738/607/245 in the first
pass and 245/256/738/606 in the second. Neither zone
contains a single cycle class:

- Zone 1 (cidx 111–135) and zone 2 (cidx 248–270)
  hold exactly the non-cycle classes and nothing
  else: 873 ×6, 626/686/839/842 ×3 each, 874 ×2,
  727 ×1 in both, in an IDENTICAL 21-context action-
  count sequence (727, 839, 873, 842, 686, 626, 873,
  874, 873, 686, 626, 839, 873, 874, 842, 626, 873,
  839, 873, 842, 686). These seven classes occur
  NOWHERE outside the two zones in cc9 and nowhere
  in any other artifact — the zones are their sole
  corpus home.
- At +137 the repetition is near-verbatim: 22/23
  pairs share the action count exactly (the sole
  exception below), 23/23 share window count and
  32016 count, mid size-multiset Jaccard ≥0.98 in
  22/23 pairs, champion 29 throughout, ng flips
  0→1 as everywhere; pair order is NOT preserved
  (same order in only 11/23 pairs) and the three
  626-class pairs and the 265 pair differ in lead
  sequence despite identical profiles. Zone contexts
  are almost all windowless (the 626 class carries
  36 windows, the 265 class 9, cidx 134 one).
- The tails differ, and they are unique: zone 1
  closes 265, 244, 186, 186; zone 2 closes 265, 247.
  The 244 (cidx 133) and its +137 partner 247
  (cidx 270) are the only pair whose counts differ
  (+3; mid-multiset Jaccard 0.699, the zones' lowest)
  and each is a corpus-wide singleton. The 186 pair
  (cidx 134/135) exists nowhere else in the corpus.
- Two boundary facts: the ng flip to 1 begins at
  cidx 134 — inside zone 1's tail; the only ng-1
  contexts below cidx 140 are 134, 135, 136 and the
  seam trio. And zone 2 is stream-final: cc9 has 271
  contexts, cidx 270 is the last, and no cycle class
  resumes after it. The first pass's cycle is intact
  through cidx 110 (259/738/606 at 108/109/110).

## What this closes and what it queues

- MEASURED: the seam triplet block's order is a
  forward A→B→C→A rotation (0.742/0.649 forward
  share; cyclic trigram share 0.587/0.467; modal
  member gap 4; smalls pinned to the C→A boundary;
  strict periodicity REFUTED at lag 3/4).
- MEASURED + CORRECTED SCOPE: the 0a0d 128/160-dose
  blocks are not the seam block at another dose —
  their third member is 25872 (620/617/763 classes)
  and every measured 0a0d block, including the
  true-triplet 623 class with the seam's member
  set, runs the REVERSE rotation (anti-cyclic share
  0.59–0.77) on lower small bands.
- REFUTED: a third sparse-dose template. Near-full
  sparse doses are exact template subsets (23 = F3
  minus one position; 22 = F0 minus two; 8 = an
  F0 subsequence at indices 0,1,3,5,7,8,11,12 —
  correcting AES-NUM-061's prefix wording); true
  sparse doses are per-context scatter sharing no
  positions law.
- MEASURED: four exact full-dose templates
  (F0/F1/F2/F3), pairwise intersections 1–7, no
  shift relation.
- MEASURED: the interruption zones are a single
  fixed 21-context non-cycle block written twice
  at +137 (identical count sequence; 22/23 pairs
  count-exact; classes found nowhere else in the
  corpus), with unique tails (244/247 singletons;
  the corpus-unique 186 pair), the ng flip starting
  at cidx 134 inside zone 1, and zone 2 closing
  the cc9 stream at cidx 270.
- NEXT (4.63): rotation-direction census over all
  remaining block classes corpus-wide (0a0d's
  48-dose 290 class and 80-dose 419 class with the
  seam's member set; 76c3a8ff's tail triplet
  contexts); the 186 pair + 244/247 singleton
  anatomy; cidx 20's dose-14 scatter vs the 32016
  block's slot structure. Host/artifact analysis
  only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
