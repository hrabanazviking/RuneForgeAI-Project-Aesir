# Rotation census, 186 pair + 244/247 anatomy, dose-14 scatter (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.63 (AES-NUM-063).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef63.py
(sha256 70651a6d…) and the labelled follow-up hef63b.py
(sha256 5e91b8d5…). Controls reproduce AES-NUM-029/032…062
EXACTLY (128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts; trailing
distinct (channel, operand) pairs 2,049; champion-headed
bursts 75,215). Transfers were sha-gated gzipped files in
900 B parts; both whole-file shas verified on-device
before either run. Definitions (middle, window, band,
segments) are as in AES-NUM-049…062.

CONVENTION, stated once and used throughout: rotation
shares are frame-dependent — relabelling two members
swaps "forward" and "reverse". Two frames are used, each
named wherever a number appears. SEAM frame: A = 7952,
B = 32784, C = 26896, forward = A→B→C→A (the frame of
AES-NUM-061/062's seam headline). SORTED frame: members
labelled by ascending size, forward = ascending cyclic.
For the 25872 set ("alt": 7952, 25872, 32784) the sorted
frame is its own labelling, the frame AES-NUM-062 used
for its 128/160-dose blocks.

## The census: one rotational sense corpus-wide — AES-NUM-062's forward/reverse split was a frame artefact

Pooled over each 0a0d378c block class (hef63b):

- Seam-set classes rotate SEAM-FORWARD, at the same
  strength the seam block itself showed: 290 class
  (16 contexts, cidx 79–169 step 6; member dose 48
  each) pooled forward 0.622 / reverse 0.219 / self
  0.159, the eight identical full contexts at
  0.664/0.217 (trigram cyclic share 0.493); 419 class
  (16 contexts, cidx 78–168 step 6; dose 80 each)
  pooled forward 0.695 / reverse 0.134, full contexts
  at 0.753/0.126 (cyclic 0.597); 623 class pooled
  forward 0.708, full contexts 0.769.
- Alt-set classes rotate SORTED-REVERSE: 280 class
  reverse 0.873, 321 class 0.791, 617 class 0.635,
  620 class 0.614, 763 class 0.708 (all pooled,
  sorted frame = their own labelling).
- These are the SAME sense. In the sorted frame the
  seam-set classes read reverse 0.622 (290), 0.695
  (419), 0.708 (623) — the identical magnitudes with
  the label flipped by the B/C swap — and cc9's seam
  block reads sorted-reverse 0.742/0.649, its cycle
  classes (245/256/259) and zone tails likewise.
  Every interleaved three-member block measured in
  the corpus — both artifacts, both member sets —
  rotates in the single anti-sorted cyclic sense
  (largest member → smallest-set successor: e.g.
  7952→32784→26896→7952 for the seam set;
  7952→32784→25872→7952 for the alt set).

CORRECTION to AES-NUM-062: its claim that the 623
class "also runs REVERSED" while the seam block runs
forward compared two different labellings (hef62b
assigned the 623 class sorted letters, the seam block
seam letters). The 0.769 magnitude was exact; the
opposition was not. There is no per-artifact or
per-class direction invariant to encode: direction
is a corpus universal once the frame is fixed, and
an encoder must fix ONE frame and carry the member
set, never a per-class direction flag.

- Degraded variants ride inside the named classes,
  as with the 623 family in AES-NUM-062: the 290
  class's 16 contexts are 8 identical full rotations
  (n = 144) plus partial (cidx 109, n = 91, forward
  0.322, self 0.411; cidx 145 n = 140; cidx 163
  n = 129) and collapsed (cidx 127, n = 26, self
  1.000) members, five contexts under the n ≥ 60
  reporting floor with no rotation at all; the 419
  class likewise (5 identical full n = 240 contexts,
  partials at cidx 108/144/162, collapsed single-
  member runs at 114/126/132). Class membership is
  by action count; rotation lives only in the full
  and partial members.
- Classes whose seam subsequence is a two-member
  alternation carry no rotation: 0a0d 617/620/763
  seam subsequences are 7952↔32784 pairs only (their
  third member is 25872, measured above in the alt
  frame), and the corpus-wide (art, nacts) census
  (hef63, triplet n ≥ 60) shows every remaining
  class in 0856a10c / 5ab3537d / 773470cd / MiniLM
  is self-dominated (forward ≈ reverse ≈ 0: single-
  member runs, no interleaved triplet block).

## 76c3a8ff has no triplet rotation at all

- Of its 325 contexts, 311 carry at most one seam
  member at dose ≥ 10 — overwhelmingly a pure 32784
  run (self share 1.000; e.g. the 826 class carries
  281–282 × 32784 and nothing else from the set).
- The only multi-member contexts are 14 (cidx 83–90
  and their ng-1 repeats at 343–350): a TWO-member
  32784↔26896 alternation with 7952 entirely absent
  (B↔C transitions symmetric — 92/92, 110/110,
  49/49; cyclic and anti-cyclic trigram shares both
  exactly 0). A pair alternation has no rotational
  sense; graded NO ROTATION, not mixed.
- The stream tail (cidx 335–352) repeats this: pure
  32784 runs (338–342), the two-member contexts
  (343–348, 350), a 777-action near-empty context
  (349, one 32784), and two small tails (351/352)
  with no triplet member at all.

## The 186 pair are the purest rotations measured — and are not twins

Cc9 cidx 134/135 (AES-NUM-062's corpus-unique pair;
both ng 1 — the flip starts at 134 — skeleton quartet
intact, champion 29, invariant end block, windowless
but for one window in 134):

- Both are seam-set triplet blocks at dose 16/18/16
  and 16/17/16 (7952/32784/26896). Cidx 135 is the
  purest rotation in the corpus: forward 0.958,
  cyclic trigram share 0.936, self 0.000 — transitions
  A→B 15, B→C 16, C→A 15 with exactly two exceptions
  (one B→A, one C→B). Cidx 134: forward 0.755, cyclic
  0.625, self 0.102.
- They are otherwise different contexts: action
  sequences agree in only 97/186 positions, mid
  size-multiset Jaccard 0.475; 134 is the pair's only
  `normal`-order context (135 and both neighbours
  are `reversed`) and carries the single window
  (lead 26896) plus a 3088 ×8 vocabulary; 135 is
  windowless, carries 80 ×13 and 424 ×5, and its
  champion operands are a disjoint family from
  134's. Same count, same rotation family, different
  layer content — the pair is a count coincidence
  inside one zone tail, not a duplicated context.

## The 244/247 singletons: one block, the +137 copy cleaner

- Cc9 cidx 133 (244) and its +137 partner cidx 270
  (247, stream-final) share the triplet dose exactly
  (32/33/32) and near-identical profiles (mid
  multiset Jaccard 0.699 — the zones' lowest, per
  AES-NUM-062 — position-wise agreement 85/244).
- The +3 actions are mid smalls: 270 carries
  3088 ×16 where 133 carries none, offset in its
  65xx band (6528 ×10 vs ×12, 6520/6536 ×5 each).
- The copy's rotation is markedly cleaner: 270
  forward 0.823 / cyclic 0.695 / self 0.083 against
  133's forward 0.646 / cyclic 0.411 / self 0.177
  (A→A self-transitions 14 in 133, 8 in 270). The
  second writing of the zone tail is not a degraded
  copy — its triplet block is the more regular one.

## Cidx 20's dose-14 scatter: tail-clustered, slot-free

0856a10c cidx 20 (24-window class; 32016 positions
[72, 75, 145, 149, 176, 234, 243, 257, 286, 356, 357,
359, 361, 367] in mid indexing):

- Not a template subset: it meets the four full-dose
  templates in only 3/4/2/1 positions and the
  78-slot template union in 7/14 — above the ~3.3
  expected if its positions were uniform over the
  union's 39..371 span, but the excess is entirely
  the tail cluster (next point), not slot agreement.
- Five of its fourteen positions sit in the tail
  zone 356–367, where every full template also ends
  (357–371 cluster): three of the five are union
  slots (357, 359, 367), two are off-slot neighbours
  (356, 361). The remaining nine are paired or
  single scatter (72/75, 145/149, then 176, 234,
  243, 257, 286) with gaps 1–70, every residue
  mod 4 and mod 8 present, channels spread 0/1/2 —
  no lattice, no period, no slot reservation: the
  union slots it does not use carry ordinary mid
  sizes in this context (32784 ×9, 3856 ×7, 4368 ×5,
  45 distinct values over 78 slots).
- The other true-sparse contexts show no such tail
  concentration (dose 5/2/1/1/1: tail-zone hits 0),
  and the near-full subsets (dose 23/22/8) keep the
  templates' own four tail slots. Graded: cidx 20's
  scatter is region-shaped (a tail cluster plus
  loose pairs) but position-free — it shares the
  templates' coarse anatomy, none of their slots
  beyond the tail cluster's density.

## What this closes and what it queues

- MEASURED + CORRECTED: the rotation census is
  complete for every interleaved three-member block
  class in the corpus. All rotate in ONE sense
  (anti-sorted cyclic); AES-NUM-062's forward-vs-
  reverse opposition between the cc9 seam block and
  the 0a0d blocks — in particular the 623 class —
  was a letter-assignment artefact of its follow-up
  script, and its per-class/per-artifact direction
  framing is retracted. Magnitudes stand everywhere.
- MEASURED: the previously unmeasured classes —
  0a0d 290 (dose 48, seam-forward 0.664 in full
  contexts) and 419 (dose 80, seam-forward 0.753) —
  conform to the same sense, each with degraded and
  collapsed members inside the action-count class.
- MEASURED: 76c3a8ff carries no triplet rotation:
  single-member 32784 runs plus 14 two-member
  32784↔26896 alternation contexts (7 + their ng-1
  repeats), tail included.
- MEASURED: the 186 pair are both triplet rotations
  (135 the corpus's purest at 0.958 forward /
  0.936 cyclic) but share only 97/186 positions —
  a count pair, not twins; the 244/247 pair's +137
  copy rotates cleaner than its source (0.823 vs
  0.646) and its +3 actions are 3088 smalls.
- MEASURED: the dose-14 scatter (cidx 20) is
  tail-clustered but slot-free — 7/14 union hits
  driven by five tail-zone positions, no lattice,
  no subset relation to any of F0–F3.
- NEXT (4.64): the two-member alternation anatomy
  (76c3's B↔C pairs + 0a0d's seam-pair subsequences
  in the alt classes — gap structure, small member,
  boundary); the collapsed/degraded members inside
  the 290/419/623 classes (what replaces the missing
  members); 135's near-perfect cycle vs 134's
  interruptions at position level. Host/artifact
  analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
