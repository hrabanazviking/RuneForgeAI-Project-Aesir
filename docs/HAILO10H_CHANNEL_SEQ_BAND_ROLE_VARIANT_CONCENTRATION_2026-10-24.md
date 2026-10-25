# Pair-order vs middle channel sequence, lead-band role in standard middles, variant-ordinal concentration (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.50 (AES-NUM-050).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef50.py
(sha256 d9bff251…) plus the labelled follow-up
hef50b.py (sha256 b55e5db6…). Controls reproduce
AES-NUM-029/032/033/034/035/036/037/038/039/040/041/
042/043/044/045/046/047/048/049 EXACTLY in both scripts
(128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts;
trailing distinct (channel, operand) pairs 2,049;
champion-headed bursts 75,215). Transfers were
sha-gated gzipped 373 B-part crossings; both scripts'
whole-file shas verified on-device on the first
attempt. Definitions (middle, pair, binary population)
are as in AES-NUM-049: middle = actions [12 : len−56];
binary contexts 1,428 (693 normal, 735 reversed);
the 76 displaced contexts are excluded from the
function tests.

## The middle CHANNEL sequence is the first stream that passes the function test — at global grain only

AES-NUM-047/048/049 closed the operand, datum, and
middle-size streams. Slice 4.50 tests the last stream
candidate named in AES-NUM-049: the middle's channel
sequence (the per-action channel of every middle
action, in order).

- Local and prefix forms — NO, like every stream
  before it. Any single middle channel position,
  from the start (positions 0–9, accuracy 0.51–0.62)
  or from the end (1–10, 0.52–0.77), is mixed.
  Prefixes grow toward separation without reaching
  it: first-3 channels 0.654, first-5 0.763,
  first-10 0.936, first-20 0.981 (10 mixed groups),
  first-50 0.9993 with exactly ONE mixed group,
  first-100 the same single mixed group. Suffixes:
  last-5 0.924, last-10 0.9979 (2 mixed). Run
  prefixes: first-10 runs 28 mixed groups, first-20
  runs 2 mixed. Stride samples of the whole sequence
  also fail: every-5th channel 1 mixed group
  (2 contexts), every-10th 1 mixed (2), every-20th
  3 mixed (10 contexts).
- The first-50/first-100 mixed group is a single
  periodic stack: 0a0d378c cidx 5 (reversed) against
  cidx 9/13/17/…/61 (14 normal), all 763 actions.
  Inside it the full channel sequence takes 4
  distinct values and the channel counts 3 — the
  separating information exists in that stack's
  channel stream, but not in its first 100 channels.
- Global forms — YES, with a group structure no
  earlier stream had. Grouping the binary contexts
  by each global channel key gives ZERO mixed
  groups, over populations that are mostly
  multi-context:
  - channel run-order alone (the RLE of the channel
    sequence, channels only — no run lengths, no
    sizes): 438 keys, 129 multi-context groups
    covering 1,119 contexts, largest group 56,
    0 mixed.
  - the last 20 middle channels: 384 keys, 119
    multi groups, 1,163 contexts, 0 mixed.
  - the first 40 channel runs (channels only):
    390 keys, 115 multi groups, 1,153 contexts,
    0 mixed (first-20 runs still fails, above).
  - full RLE (channels + run lengths), transition
    counts, and the full channel sequence: 453 keys
    each, 133 multi groups, 1,108 contexts, 0 mixed.
  Contrast the middle SIZE sequence's formal
  separation (AES-NUM-049): 1,100 keys but only 39
  multi-context groups covering 367 contexts — a
  near-unique key. The channel keys are coarse
  (438–453 keys over 1,428 contexts) and exercised
  repeatedly; their separation is not the
  uniqueness artefact, and it is not the
  single-counterexample artefact of AES-NUM-049's
  combined keys either (those separated only by
  resolving one mixed group; here the channel-count
  key's BOTH mixed groups are resolved, and 129–133
  independent multi-context groups are all pure).
- The counterexamples resolve concretely. The
  448-action channel-count group (0856a10c cidx
  14 reversed / 41 normal / 50 reversed) takes 3
  distinct run-order values, one per context; its
  full channel sequences differ pairwise at
  177–244 of 380 positions — separation there is
  per-context, weak evidence alone. The 280-action
  group (18/30 normal, 48/60/72 reversed) takes
  exactly 2 run-order values, one per order: the
  two normal contexts' channel sequences are
  byte-identical (0 differing positions), the three
  reversed contexts' are byte-identical, and the
  two forms differ at 184 of 212 positions. The
  4.47 triple behaves the same way: the two
  reversed members (15, 27) share an identical
  middle channel sequence (counts (0,74),(1,73),
  (2,65); 73 runs; identical transitions), and the
  normal member (39, one action shorter) differs
  at 34 channel positions.
- The honest boundary of the finding. Run-order is
  almost a stack property: only 2 of its 438 keys
  span more than one non-pair champion stack (max
  3 stacks), and 34 of the 111 multi-context
  champion stacks carry more than one run-order
  value. So the channel sequence is a finer
  identity that sits between the champion stack and
  the context, and the order bit is a function of
  THAT identity at corpus scale — but no local,
  prefix, stride, or short-run reading of it
  determines the bit, and no mechanism is
  established. What an encoder may use today: the
  full run-order (or transition / full-sequence)
  key separates the corpus's orders exactly; why
  it does, and a minimal sufficient form, are
  NOT PROVEN.

Graded MEASURED (function, global grain): pair order
is an exact function of the middle channel sequence's
global forms — run-order, transitions, full sequence,
last-20, first-40-runs — with zero violations over
129–133 multi-context groups covering 1,108–1,163
contexts. Graded NOT PROVEN: any local/minimal form
(every prefix ≤100 channels, every stride sample,
every run prefix ≤20 fails), and any mechanism.

## A band action IS a 3856 lead in standard middles too — half of all standard windows are band-led

AES-NUM-049 proved the 156 motif's leads are
position-exclusive in their own contexts and queued
the role question for standard middles, where the
8104–8832 band occurs 16,105 times. Slice 4.50
censuses the band's neighbourhood there:

- A band action is followed by a 3856 in 10,334 of
  16,105 cases (64.2%) — against a base rate of
  3.18% (20,411 of 641,079 middle actions are
  followed by a 3856), a twenty-fold enrichment.
  The band's role in standard middles is the same
  role it has in the motif: it is the size that
  stands before a 3856 window.
- Equivalently, from the windows' side: 10,334 of
  all 20,411 standard 3856 windows (50.6%) are
  band-led. The motif's 312 of 312 (100%) is the
  pinned extreme of a corpus-wide habit, not a
  different construction.
- The values are the motif's own vocabulary, plus
  a tail: standard middles use 92 distinct band
  values; all 82 motif lead values occur, and the
  10 extra values are MORE lead-like, not less —
  band occurrences carrying a motif lead value are
  followed by 3856 in 8,943 of 14,503 cases
  (61.7%), the 1,602 occurrences carrying a
  non-lead band value in 1,391 (86.8%). Commonest
  band value overall: 8208 (2,565 occurrences).
- Band-led windows are messier than the motif's:
  of the 10,334, the window after the 3856 is full
  in 2,815 (27.2%), no30480 in 1,586 (15.3%),
  no32784 in 802 (7.8%), other in 5,131 (49.7%) —
  enriched for full and no32784 against all
  standard windows (14.6% / 22.7% / 4.3% / 58.4%),
  but nowhere near the motif's pinned classes.
  When a band action is NOT followed by a 3856,
  the commonest followers are 4368 (2,168), 4112
  (683), 32784 (318), 8208 (193). Before a band
  action, the commonest predecessors are the
  window's own tail sizes — 30480 (4,473), 32784
  (3,142) — and 3856 itself (1,902): band actions
  also occur inside windows, not only before them.
- The band is a middle-only phenomenon in standard
  contexts: 16,105 occurrences in middles, 7 in
  heads, 0 in trailers. Its channels are near-
  balanced (0: 5,753; 1: 5,216; 2: 5,136), and it
  concentrates in 0856a10c (7,118) and 76c3a8ff
  (6,150), with 383–1,508 in each other artifact
  (MiniLM: 43).

Graded MEASURED: the lead-band's role is
corpus-wide — a band action precedes a 3856 window
in 64.2% of standard-middle occurrences (base rate
3.18%), and 50.6% of all standard windows are
band-led. The 156 motif differs by degree (100%,
pinned window classes), not by kind. What selects
a band value for a given window remains NOT PROVEN
(AES-NUM-048/049 grade stands).

## No variant-ordinal concentration in the ≥12-3856 standard subpopulation — the pinning stays the motif's alone

AES-NUM-049 found 311 standard contexts carrying
≥12 middle 3856 windows and queued whether THAT
subpopulation — the only standard population with
motif-sized runs — concentrates variant classes at
fixed ordinals the way the 156 motif does (ordinal
0 no30480, ordinal 4 no32784, 26/26 each).

- The subpopulation is 311 contexts (0856a10c 110,
  cc9b9d1c 117, 76c3a8ff 84; 14–140 windows each)
  holding 20,346 of the 20,411 standard windows —
  essentially the whole window population, so its
  class totals match the standard totals (full
  2,975; no30480 4,629; no32784 877; other 11,865).
- At NO ordinal does it pin. Ordinal 0 splits
  other 236 (75.9%) / no30480 39 / no32784 30 /
  full 6; ordinal 4 splits other 152 (48.9%) /
  no30480 105 / full 52 / no32784 2. Across
  ordinals 0–30 the highest top-class fraction
  anywhere is 0.794 (ordinal 30) and every top
  class is "other"; NO ordinal 0–30 carries a
  variant class (full / no30480 / no32784) at
  ≥0.90, or anywhere near it.
- The motif's exact double pin (ordinal 0
  no30480 AND ordinal 4 no32784) occurs in exactly
  1 of the 311 contexts: 76c3a8ff cidx 4, a
  609-action standard context with 52 windows.
  Ordinal-0 pin alone: 39 contexts (12.5%);
  ordinal-4 pin alone: 2 (0.6%); either: 40.

Graded MEASURED, NEGATIVE: variant-ordinal
concentration does not appear in the ≥12-3856
standard subpopulation — its ordinals are as
scattered as the full standard population's, and
the 156 motif's fixed-ordinal pinning (26/26 at
both ordinals) remains unique to the motif. The
single both-pinned standard context is recorded
as a curiosity for follow-up, not a class.

## What this closes and what it queues

- MEASURED (function, global grain): the pair-order
  bit IS a function of the middle channel sequence's
  global forms — run-order alone (no lengths, no
  sizes) separates all 1,428 binary contexts with
  zero mixed groups over 129 multi-context groups /
  1,119 contexts; transitions, full sequence,
  last-20 channels, and first-40 runs separate the
  same way. This is the first stream to pass the
  function test (operand 4.47, datum 4.48, middle
  sizes 4.49 all failed at every grain).
- NOT PROVEN: any minimal or local form of that
  function — prefixes ≤100 channels, stride
  samples, and run prefixes ≤20 all retain mixed
  groups (the first-50/first-100 failure is one
  periodic 0a0d378c stack) — and any mechanism;
  run-order is near-isomorphic to stack identity
  (2 of 438 keys span >1 champion stack).
- MEASURED: the lead-band role is corpus-wide —
  64.2% of standard-middle band actions lead a
  3856 window (base rate 3.18%); 50.6% of all
  standard windows are band-led; the band is
  middle-only in standard contexts (16,105 / 7 /
  0 across middle/head/trailer) and its values are
  the motif's 82 plus 10 even-more-lead-like
  extras.
- MEASURED, NEGATIVE: no variant-ordinal
  concentration in the 311-context ≥12-3856
  subpopulation (no variant class ≥0.90 at any
  ordinal 0–30; the motif's double pin occurs
  once, in 76c3a8ff cidx 4).
- NEXT (4.51): where the channel separation
  emerges — run prefixes 20–40 and the last-20
  refinement (last-10 fails), plus the 0a0d378c
  first-50 stack's run-order split (4 values over
  15 contexts, 1 reversed); the band's non-3856
  followers (4368-led structures); the both-pinned
  76c3a8ff cidx-4 context's anatomy vs the 156
  class. Host/artifact analysis only — no
  physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
