# Cluster-context selection, 32016 dialect anatomy, chain context selection (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.53 (AES-NUM-053).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef53.py
(sha256 a9d093a5…) plus the labelled follow-up
hef53b.py (sha256 b0b47c1b…). Controls reproduce
AES-NUM-029/032/033/034/035/036/037/038/039/040/041/
042/043/044/045/046/047/048/049/050/051/052 EXACTLY in
both scripts (128,787 pooled small actions; 79,001
pooled 24 B bursts; 745,849 pointer actions; 1,504
contexts; trailing distinct (channel, operand) pairs
2,049; champion-headed bursts 75,215). Transfers were
sha-gated: hef53.py via gzipped 373 B parts (whole-file
shas verified on-device first try); hef53b.py's 373 B
part at offset 746 corrupted in re-emission (base64
invalid input, byte count 374), was discarded, and the
remainder crossed at re-split 300 B boundaries with
whole-file shas verified on-device. Definitions
(middle, pair, binary population, band, window classes)
are as in AES-NUM-049/050/051/052: middle = actions
[12 : len−56]; standard middles exclude the 76c3a8ff
156/173 classes; band = sizes 8104–8832; cluster =
9168–9248.

## In cc9b9d1c the cluster replaces the band entirely — and window density does not select it

The 19 cluster-positive cc9b9d1c contexts are cidx
[1, 14, 18, 29, 30, 33, 34, 57, 65, 85, 151, 155, 166,
167, 170, 171, 194, 202, 222], holding all 688 of the
artifact's cluster-led windows (1–63 per context).

- Mutual exclusion is TOTAL inside cc9b9d1c: the 19
  positive contexts carry 1,758 windows = 688 cluster
  + 0 band + 1,070 other-led; the 252 negative contexts
  carry 7,488 windows = 0 cluster + 34 band + 7,454
  other-led. Corpus-wide the exclusion is NOT a law:
  exactly 2 of 1,476 standard contexts hold both
  cluster and band leads, both in 76c3a8ff (cidx 3:
  41 cluster + 68 band of 124 windows; cidx 4: 14 + 37
  of 52). In cc9b9d1c, a context speaks the cluster
  dialect or it does not speak it at all.
- Window density does NOT select the cluster: the
  negative population is bimodal (124 contexts with
  0 windows; 61 with 81–96 windows), and the 72
  negative contexts with ≥50 windows hold 6,484
  windows of which 6,466 are other-led and only 18
  band-led — just as window-dense as the positives
  (81–96 windows, mean 92.5), with zero cluster leads.
- Nor do the simple features: positive nacts take
  only two size classes (606/607 ×8, 738 ×11) but 105
  negative contexts share that nacts range; body
  champion count is 29 in every cc9b9d1c context,
  positive or not; pair order splits 8 normal /
  11 reversed among positives vs 162/90 among
  negatives; network-group index splits 10/9 vs
  124/128. First-8 middle size sequences: 10 distinct
  among positives, 99 among negatives, 5 shared.
- The positive cidx gaps are [13, 4, 11, 1, 3, 1, 23,
  8, 20, 66, 4, 11, 1, 3, 1, 23, 8, 20]: the gap
  sequence from cidx 14 onward (4, 11, 1, 3, 1, 23,
  8, 20) REPEATS exactly from cidx 155 onward. But
  the paired contexts are not copies — offsets vary
  138–160 and paired members differ in cluster count
  (55 vs 29, 29 vs 6, 4 vs 38, …), nacts and window
  count. The repetition is in the SELECTION PATTERN,
  not in the contexts.
- The positives' other-led windows point at a wider
  family: their top other-lead values are 9264 (56),
  9160 (51), 9280 (50), 9256 (48), 9272 (48) — all
  hugging the counted 9168–9248 window from just
  outside, on both sides. The counted ladder is
  likely the dense core of a wider step-8 lead
  family; its full extent is the next slice's census.
- First cluster window ordinal varies 0–48 across
  the positives and cluster counts run 1 (cidx 1,
  an otherwise other-led 96-window context) to 63 —
  the dialect enters at no fixed position and at
  no fixed dose.

Graded MEASURED: in cc9b9d1c, cluster membership is
a whole-context, band-exclusive property (0 band
leads in 19/19 positives) whose cidx selection
pattern repeats its gap sequence once, while window
density, context size class, champion count, pair
order and network-group index all fail to select it.
NOT PROVEN: the selecting feature itself, and the
wider lead family's true extent.

## The 32016 dialect: cluster windows are 32016-rich and 30480-poor; band windows are the mirror

Full-shape comparison over the 743 cluster-led and
10,334 band-led windows in standard middles:

- After the led 3856, cluster windows run 32784
  (295), 32016 (52), another cluster value (48 over
  the top three), 30480 only 12; band windows run
  32784 (6,903), 30480 (802), then small members
  (16400, 12304, band values). Window classes:
  cluster = other 557 / no30480 165 / no32784 12 /
  full 9; band = other 5,131 / full 2,815 / no30480
  1,586 / no32784 802.
- Within the next 8 actions, a cluster window
  contains 32016 in 352/743 (47.4%) — with
  multiplicity (exactly 1 in 152, 2 in 172, 3 in 28)
  — and 30480 in only 55 (7.4%); a band window
  contains 32016 in 365/10,334 (3.5%, at most 2) and
  30480 in 7,934 (76.8%). 32784 appears in 482
  cluster windows (64.9%) vs 9,422 band windows
  (91.2%); the next 3856 appears in 635 (85.5%) vs
  8,549 (82.7%) — window spacing is comparable
  (gap-to-next same-class window: mean 12.5 cluster
  vs 6.8 band, median 5 both), so the dialect
  difference is vocabulary, not rhythm.
- The first 32016 after the 3856 peaks at offset 3
  in both dialects (cluster 122, band 184) — the
  (32784, 32784, 32016, …) slot — but cluster
  windows also carry it at offset 1 (52) and 2 (66)
  far more often, matching their top after-4 shapes
  ((32784,32784,32016,32784) 23; (32784,32016,32784,
  32784) 11; (32784,32016,32784,32016) 10) against
  the band's ((32784,32784,30480,32784) 768; …).
- Globally 32016 occurs 8,131 times in 172 standard
  contexts, 7,162 of them (88.1%) in cc9b9d1c; its
  commonest neighbours are 32784 before (6,045) and
  32784 after (2,668), with 32016 self-chaining
  (407 before and after) and a 3856→32016 edge (826).
  30480 occurs 9,905 times corpus-wide. The 3856
  channel census differs too: cluster-led 3856s sit
  on channels {1: 309, 0: 243, 2: 191} vs band-led
  near-uniform {0: 3,435, 1: 3,490, 2: 3,409}.

Graded MEASURED: the cluster dialect is a distinct
window vocabulary — 32016-rich (47.4% of windows,
multiplicities to 3), 30480-poor (7.4%), 32784-
lighter (64.9%) — against the band dialect's
30480-rich (76.8%), 32016-poor (3.5%) shapes, at
comparable window rhythm and a shared offset-3
32016 slot. 32016 plays 30480's role AND more: it
also opens windows (offset 1) in the cluster dialect.

## Chain context selection: exactly the sisters' small-context class, on one shared periodic train

AES-NUM-052 left the 8208→4112→3088 chain in 112
contexts (56 per sister artifact), exactly 6 chains
each. Slice 4.53 settles the selection:

- The sisters share the chain cidx set EXACTLY:
  |A| = |B| = 56, intersection 56, symmetric
  difference 0 — the same 56 context indices in
  5ab3537d and 773470cd.
- The set is one periodic train, identical in both
  sisters: cidx 2, 5, 8, …, 80 (27 gaps of exactly
  3), then a break (gap 14 to cidx 94, gap 1 to 95),
  then 99, 103, …, 203 (27 gaps of exactly 4).
- Chain contexts are EXACTLY the sisters' isolated
  small-context class: every chain context has
  232–239 actions, every one of the 56 contexts in
  each sister with 232–239 actions is a chain
  context, and no context outside that range carries
  a chain. The nacts histogram is empty at 151–231 —
  the class is separated from the rest (240–499: 62;
  500–799: 42; ≥800: 58) — identical counts in both
  sisters. Chain contexts' middles hold no 3856
  windows at all (nwin 0 in 56/56, both sisters).
- Chain positions inside those contexts agree
  between the sisters at 54 of the 56 shared cidx;
  the two exceptions are exactly the train-break
  pair, cidx 94 (A [20, 79, 96, 112, 123, 139] vs
  B [23, 84, 88, 110, 120, 136]) and cidx 95
  (A [27, 42, 56, 106, 121, 136] vs B [27, 42, 57,
  109, 124, 139] — the first two positions agree).
  Pooled chain middle positions run 20–151
  (mean ~80.6, median 87) in both sisters.
- Pair order does not select chain membership
  either (5ab3537d chain contexts 29 normal /
  27 reversed; 773470cd 28/28).

Graded MEASURED: chain-context selection is class
membership — the sisters' 232–239-action contexts,
arranged on one shared step-3/step-4 cidx train with
a single 14+1 break at cidx 80→94→95 — and the two
contexts at that break are the only ones whose chain
positions differ between the sisters.

## What this closes and what it queues

- MEASURED: cc9b9d1c cluster membership is whole-
  context and band-exclusive (0 band leads across
  the 19 positives' 1,758 windows); corpus-wide
  exclusion fails only in 76c3a8ff cidx 3/4.
- MEASURED: window density, nacts class, champion
  count, pair order and ng index do NOT select
  cluster membership (61 negative contexts are
  equally window-dense with zero cluster leads);
  the positive cidx gap sequence repeats once
  exactly (from 14 and from 155), without the
  paired contexts being copies.
- MEASURED: the positives' other leads hug the
  cluster window (9160, 9256–9280 on top) — the
  counted 11-rung ladder is likely a core, not the
  whole family.
- MEASURED: the 32016 dialect is a full vocabulary
  swap at comparable rhythm (32016 in 47.4% of
  cluster windows with multiplicity to 3, 30480 in
  7.4%; band mirror: 3.5% / 76.8%), with a shared
  offset-3 slot.
- MEASURED: chain contexts = the sisters' shared
  232–239-action class on an identical step-3
  (2–80) / break (94, 95) / step-4 (99–203) train;
  chain positions identical at 54/56 shared cidx,
  differing exactly at the break pair.
- NEXT (4.54): wider lead-family census around the
  cluster (step-8 leads 9100–9350 in the positive
  contexts vs the dense negatives — the family's
  true extent and whether membership re-grades);
  what leads the 61 window-dense cc9b9d1c negatives
  (their lead vocabulary vs the positives'); the
  cidx-1 single-cluster-window anatomy (one cluster
  lead in an otherwise other-led context).
  Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
