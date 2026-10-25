# Marker ladder, cc9 end-block windows, 763 subgroups (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.72 (AES-NUM-072).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef72.py
(sha256 c3c29a1f…) + labelled follow-up hef72b.py
(sha256 2f9d1f6a…), both sha-gated gzipped 373 B-part
transfers, whole-file shas verified on-device. Controls
reproduce AES-NUM-029/032…071 EXACTLY (128,787 pooled
small actions; 79,001 pooled 24 B bursts; 745,849
pointer actions; 1,504 contexts; trailing distinct
(channel, operand) pairs 2,049; champion-headed bursts
75,215). Definitions (seam set A = 7952, B = 32784,
C = 26896; classes = contexts of one action count;
marker = the action at p−1 before an A entry) are as in
AES-NUM-061…071. The rotation artifacts are 0a0d378c
and cc9b9d1c.

## (i) The marker pool is a complete step-8 ladder; its exact selection is NOT PROVEN

The C→A gap-2 marker population (the reset markers of
AES-NUM-071):

- 0a0d378c: 1,572 markers, exactly 41 distinct sizes —
  the values 5,536…5,856 in steps of 8, with NO missing
  rung (missing-in-step-8 = []). Counts per rung range
  1…152 (mean 38.3; top 5568 ×152, 5576 ×119,
  5664 ×93).
- cc9b9d1c: 2,691 markers, exactly 58 distinct sizes —
  the values 6,112…6,568 in steps of 8, again complete
  with no missing rung. Counts 1…242 (mean 46.4; top
  6520 ×242, 6512 ×234, 6528 ×222).

Widening to ALL A entries (any predecessor, any gap)
does not widen the C-predecessor pool at all, and
barely widens the rest:

- Every C-predecessor marker (0a0d378c 1,637 incl.
  gap > 2; cc9b9d1c 2,966) lies inside its artifact's
  ladder — 100% in both artifacts, distinct 41 / 58.
- A-predecessor markers: 0a0d378c 4,415, 89 distinct,
  range 5,456…6,256, 70.6% inside the CA2 ladder range
  (a sparse upward extension with gaps above 6,024);
  cc9b9d1c 1,550, 52 distinct, 98.6% inside, plus
  21 markers of size 24.
- B-predecessor markers: 0a0d378c 7,471, 92 distinct,
  57.4% inside; cc9b9d1c 1,025, 53 distinct, 97.3%
  inside, plus 28 of size 24.
- All-A totals: 0a0d378c 13,523 markers / 93 distinct
  (the ladder, the sparse extension, and one 24);
  cc9b9d1c 5,541 / 59 distinct (the ladder plus 24).

No tested feature SELECTS the rung. Function tests
(group keys → marker; modal accuracy; every multi-key
group mixed unless noted) on the CA2 populations:
cidx 0.270 / 0.251, A position 0.170 / 0.212, seam
ordinal k 0.251 / 0.190, position decile ≤0.107,
context size class ≤0.133, A channel, marker channel,
next-seam letter+gap, next-seam channel, A+next
channel pair, predecessor letter and the size at p−2
all at ≤0.115 — chance level for a 41/58-value pool
whose top rung holds ~9%. On the A→B gap-1 subset,
B channel and the (A chan, B chan) pair score
≤0.094. The only exact key is (cidx, k) — one marker
per key, a tautology, not a law.

The marker also behaves like ordinary payload data,
not like a structural constant:

- No multi-marker context has a constant marker
  sequence (0/30 contexts in 0a0d378c, 0/171 in
  cc9b9d1c). Consecutive CA2 markers within a context
  move both ways with balanced counts (0a0d378c 1,542
  pairs: equal 275, up 635, down 632, diffs within
  ±80; cc9b9d1c 2,520 pairs: equal 368, up 1,073,
  down 1,079, diffs −352…+376; all diffs multiples
  of 8).
- The marker's size also occurs elsewhere in its own
  context in 1,550/1,572 cases (98.6%) in 0a0d378c
  and 2,260/2,691 (84.0%) in cc9b9d1c.

Verdict: the A-boundary marker is drawn from a
complete, artifact-specific step-8 size ladder
(41 rungs in 0a0d378c, 58 in cc9b9d1c — exactly the
41/58 pools of AES-NUM-071), and for C-predecessor
entries from nothing else. Which rung a given entry
takes is NOT PROVEN as a function of context,
position, ordinal, channel, the following seam pair,
or any other tested structural feature; the rung
behaves as the size of a genuine data action whose
content the seam structure does not carry.

## (ii) The cc9 "39-window block" is the universal end block — there are no other channel-rigid classes in cc9

Every cc9b9d1c class with n ≥ 8 contexts (245, 256,
259, 606, 607, 738, 873) has EXACTLY 39 single-channel
17-windows, forming ONE contiguous block of window
starts. In every class the block starts at exactly
nacts − 55 (190 / 201 / 204 / 551 / 552 / 683 / 818),
its first window's channel sequence is all-zero, and
the block is also single-size (39 size windows in
each class; the 256 class has 43 size windows total,
the 4 extra elsewhere). The same holds verbatim for
every 0856a10c class with n ≥ 8 (206, 280, 405, 448,
453, 553, 653, 832 — 39 windows each, starts at
nacts − 55) and for 0a0d378c's loose classes 280 and
763 (39 each).

The follow-up shows why: the last 55 actions of EVERY
context form a fixed end block —

- Per artifact, the last-55 SIZE sequence has exactly
  1 distinct value over all its contexts, and the
  last-55 CHANNEL sequence likewise (all 7 artifacts;
  6…353 contexts each), and the same holds inside
  every n ≥ 8 class.
- 39 = 55 − 17 + 1: exactly the 17-windows fully
  inside that end block. The block's first 17 channels
  are all zero (its opening stretch), but it is not a
  trailing channel-0 run: the per-context trailing
  ch0 run is exactly 1 in all 1,504 contexts (the last
  action is ch0, the second-last is not).

So in cc9b9d1c's loose population the 39 windows are
carried by EVERY class, rigid and loose alike, and no
cc9 class holds a single-channel window anywhere
else. Classes that exceed 39 do so by real class
rigidity (0a0d378c: 290 class 274 windows, 419: 369,
623: 516, 123: 64, 617: 114, 620: 131; the 321 class
has 41 — its block starts at nacts − 57, two windows
early, the extending window's channel sequence
beginning 1, 1 before the zeros). Cross-class, cc9's
first-block channel sequences are 1 distinct value —
they are the same artifact end block in every class.

Verdict: there are no hidden channel-rigid classes in
cc9b9d1c's loose population. The recurring 39-window
block of AES-NUM-071 is the artifact-universal
55-action end block (the quartet + trailing block of
AES-NUM-034/035) viewed through 17-windows; channel
rigidity beyond it in cc9 is zero.

## (iii) The 763 class: channel dissolution is subgroup structure, not decay

0a0d378c's 763-action class (32 contexts) at class
level looks dissolved: single-channel at 119/763
positions (0.156), single-size at 72/763 (0.094);
first non-single channel position is 0, first
non-single size position 8; max distinct values at
one position are 3 channels vs 29 sizes; positions
are both-single at 56, channel-only 63, size-only
16, neither 628. Its band profile is U-shaped, not
monotone (single-channel 0.306 / 0.200 / 0.140 /
0.040 / 0.244 over bands 0–35 / 36–100 / 101–250 /
251–500 / 501–762), and its only single 17-windows
are the end block's 39 (both streams).

The dissolution is BETWEEN subgroups:

- The 32 contexts carry only 9 distinct full channel
  sequences: subgroups of 12, 10 and 4 contexts plus
  six singletons. The big subgroups sit on periodic
  context indices — 12-group cidx {9, 17, 21, 25, 29,
  33, 41, 45, 49, 53, 57, 61} (step 4 after 17),
  10-group {88, 94, 100, 106, 112, 136, 142, 154,
  160, 166} (step 6), 4-group {118, 124, 130, 148}
  (step 6); singletons at cidx 1, 5, 13, 37, 76, 82.
- Inside a subgroup the SIZE stream is also nearly
  fixed: size-single positions within each big
  subgroup are 588 / 587 / 590 of 763, against 72
  class-wide. Full size sequences remain 32 distinct
  (no two contexts share one) — each subgroup is a
  near-template with ~175 varying size positions.
- Outside the end block, the class keeps only 64
  scattered single-channel positions and 17
  single-size positions (eight of them the shared
  head, positions 0–7).

Against the templated triplet (290: channel single
at 290/290, first break never; 419: 417/419, first
break at 329; 623: 613/623, first break at 188; 123:
107/123), the 763 class is therefore not a fourth
regime of gradual dissolution: from position 0 its
contexts belong to a handful of channel-fixed
subfamilies, and class-level statistics mix them
into apparent looseness — the same lesson as its
size stream, which dissolves class-wide at 72
positions but holds at ~588 inside each subfamily.

## What this closes and what it queues

- MEASURED: the C→A marker pools are complete step-8
  ladders (0a0d378c 5,536…5,856, 41 rungs, no gaps;
  cc9b9d1c 6,112…6,568, 58 rungs, no gaps); C-predecessor
  markers lie in the ladder 100% in both artifacts.
- NOT PROVEN: any structural selection of the rung —
  context, position, ordinal, channel, following pair
  and p−2 size all fail the function test at chance
  level; consecutive rungs move both ways; the rung
  recurs as an ordinary size elsewhere in its context
  in 98.6% / 84.0% of cases.
- MEASURED: the 39-window block is the universal
  55-action end block (last-55 size and channel
  sequences each 1 distinct per artifact over all
  contexts); cc9 and 0856 loose classes hold no
  single-channel window outside it; no hidden
  channel-rigid cc9 classes exist.
- MEASURED: the 763 class splits into 9 channel
  subgroups (12 / 10 / 4 + six singletons, periodic
  cidx), within which size is single at ~588/763
  positions vs 72 class-wide; its dissolution is
  between-subgroup mixing.
- NEXT (4.73): 763 subgroup anatomy (subgroup size
  templates vs each other; the singletons vs the
  subgroups; cidx periodicity vs proto ordering);
  marker-rung distribution vs the contexts' own
  5–7k data-action size distribution; the 321
  class's 57-action end region vs the universal 55.
  Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
