# Channel-separation emergence, band non-3856 followers, both-pinned cidx-4 anatomy (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.51 (AES-NUM-051).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef51.py
(sha256 fa64869c…) plus the labelled follow-up
hef51b.py (sha256 91991d87…). Controls reproduce
AES-NUM-029/032/033/034/035/036/037/038/039/040/041/
042/043/044/045/046/047/048/049/050 EXACTLY in both
scripts (128,787 pooled small actions; 79,001 pooled
24 B bursts; 745,849 pointer actions; 1,504 contexts;
trailing distinct (channel, operand) pairs 2,049;
champion-headed bursts 75,215). Transfers were
sha-gated gzipped 373 B-part crossings; both scripts'
whole-file shas verified on-device on the first
attempt. Definitions (middle, pair, binary population,
band, window classes) are as in AES-NUM-049/050:
middle = actions [12 : len−56]; binary contexts 1,428
(693 normal, 735 reversed); band = sizes 8104–8832.

## The channel separation emerges at exact, small thresholds — and every late failure is one named group

AES-NUM-050 proved the pair-order bit is an exact
function of the middle channel sequence's global forms
and left the emergence question: how much of the
sequence must be read before the separation appears?
Slice 4.51 scans each form's threshold and names every
mixed group that survives below it.

- Channel run-order prefixes (RLE channels, first N
  runs): mixed groups fall 6 (N=15, 51 contexts) → 4
  (N=18, 41) → 2 (N=20–21, 18) → 1 (N=22–34, 15) → 0
  at exactly N=35 (388 keys, 114 multi-context groups
  covering 1,154 contexts). The N=20 second group is a
  sister-artifact group — 5ab3537d cidx 87 (normal)
  against 773470cd cidx 87/211 (reversed), all 841
  actions — and it resolves at N=22. From N=22 to
  N=34 the ONLY mixed group in the corpus is the
  0a0d378c first-50 stack (below).
- Run prefixes WITH lengths (RLE full, first N runs)
  emerge one run earlier: still 1 mixed group (the
  same stack) at N=31–33, zero at exactly N=34 (398
  keys, 115 multi groups).
- Last-N channels emerge at exactly N=18: last-17
  retains exactly one mixed group of 2 contexts — a
  cross-artifact pair, 5ab3537d cidx 210 (reversed,
  751 actions) vs 76c3a8ff cidx 88 (normal, 936) —
  and last-18/19/20 are clean (382–384 keys, ~120
  multi groups). At last-12 the single mixed group
  holds 5 contexts (0a0d378c cidx 74/175 reversed,
  5ab3537d cidx 210 reversed, 76c3a8ff cidx 0/88
  normal).
- Last-N runs (RLE channels, last N runs): 38 mixed
  groups at N=5, 23 at N=10, exactly 1 at N=15 — an
  0856a10c group (cidx 3 reversed, 280 actions, vs
  cidx 25/37 normal, 832) — and 0 at N=20 (391 keys,
  120 multi groups). The exact threshold lies in
  16–20; not pinpointed further.
- First-N raw channels: first-100's only mixed group
  is the same 0a0d378c stack; first-150 is clean, and
  the stack's own threshold (below) puts the exact
  first-N emergence at 122 channels.

Graded MEASURED: the global channel function of
AES-NUM-050 has exact finite thresholds — 35 channel
runs (34 with run lengths), the last 18 channels, the
last ≤20 runs, the first 122 channels — each with
zero mixed groups over 113–122 multi-context groups
covering ~1,150 contexts. Below every threshold the
failures are not diffuse: from run-prefix 22 upward
a single named stack is the corpus's only holdout.

## The 0a0d378c stack splits at one channel-0 action at middle position 121

The periodic stack that defeats every prefix form —
0a0d378c cidx 5 (reversed) against cidx 9/13/…/61
(14 normal), all 763 actions, middles of 695 — was
dissected pairwise:

- The 15 members take 4 distinct full channel
  sequences (also 4 RLE-channel and 4 RLE-full
  values, 3 channel-count values, 1 first-100 key).
  The reversed member is a singleton sequence; the
  14 normals take 3 sequences (run counts 172/174/
  177 vs the reversed member's 178).
- Against EVERY normal member the reversed sequence
  differs at exactly 228 channel positions, and the
  first differing position is always 121: at
  position 120 both carry channel 2; at position
  121 the reversed member carries channel 0 where
  all 14 normals carry channel 2. Run-wise the
  first differing run is index 34 — the normals run
  …1,2,1,2,1,2… while the reversed member inserts
  the channel-0 run (…1,2,1,2,**0**,2,1,2…), a phase
  shift whose differences then cascade (79–85
  differing runs of ~175). The minimum separating
  prefixes against all 14 normals are exactly:
  122 channels, 35 channel runs, 34 full runs —
  the corpus thresholds of part (i) are this one
  stack's thresholds.
- What the diverging action IS (its size, its
  neighbourhood sizes) was not measured; the channel
  streams alone were compared. Queued in 4.52.

Graded MEASURED: inside the stack, order separation
is a single-position channel divergence (channel 0
vs 2 at middle position 121) plus its run-phase
cascade; the reversed member is the stack's unique
sequence. NOT PROVEN: any mechanism, and whether
position-121 divergence is the bit's cause or
another correlate of stack identity (AES-NUM-050's
boundary stands: run-order remains near-isomorphic
to stack identity corpus-wide).

## The band's non-3856 followers are half structured — one fixed chain, one scattered form

AES-NUM-050 counted 5,771 standard-middle band
occurrences NOT followed by a 3856 (of 16,105).
Slice 4.51 censuses them (follower = the size
immediately after the band action):

- Follower census heads: 4368 (2,168 occurrences,
  80 contexts), 4112 (683, 119), 32784 (318, 146),
  8208 (192, 79), 25872 (158), 80 (129), 24 (105),
  1296 (83), 48 (82). The 4368+4112 pair alone is
  2,851 of 5,771 (49.4%); the remaining 2,920
  scatter over 251 distinct follower sizes.
- The 4112 follower is a FIXED CHAIN, not a family:
  the band value is 8208 in 673 of 683 cases; the
  size after 4112 is 3088 in 672 of 683; and the
  5-gram (8208, 4112, 3088, 32784, 32784) alone
  accounts for 597 — only 17 distinct 5-grams exist
  in total. This is a second rigid construction
  beside the 3856 window: band 8208 → 4112 → 3088 →
  32784 → 32784 …
- The 4368 follower is the opposite: 1,645 distinct
  6-grams over 2,168 occurrences, confined to two
  artifacts (0856a10c 1,225; 76c3a8ff 943) with
  near-balanced channels (726/766/676). Its commonest
  frame is (band, 4368, 32784, 32784) — 160 for the
  top band value 8480 — but the window-analog classes
  split (32784,32784,27280) 398 / (32784,32784,other)
  150 / (32784,other) 288 / other 1,332: most 4368
  continuations are NOT window-shaped. A 4368 in
  standard middles (2,594 total) is band-preceded in
  83.6% of cases, is NEVER followed directly by a
  3856 (0 of 2,594), and after a band→4368 the next
  3856 is absent within 9 actions in 1,147 of 2,168
  cases (distance 6 is the modal hit, 211). Its
  commonest predecessors are 27280 (455) and 4368
  itself (414 — 4368s chain).
- Followers 32784 and 8208 are scattered like 4368
  (220 and 128 distinct 5-grams over 318/192
  occurrences).

Graded MEASURED: exactly one non-3856 follower form
is a rigid construction — the 8208→4112→3088→32784
chain (673–597 of 683 at each joint). The 4368 form
is a frequent but unstructured continuation, and
4368 is a 3856-avoiding size (never followed by one
directly, in any context, band-led or not).

## The both-pinned cidx-4 context is a coincidence of two different lead families — not a motif relative

76c3a8ff cidx 4 (609 actions, reversed, pair at
ordinals 16/15) — the single standard context in
the ≥12-3856 pool whose window 0 is no30480 and
window 4 is no32784 (AES-NUM-050) — dissected
against the 156 class:

- Scale: its middle is 541 actions with 52 windows
  (156 class: 88 middle actions, 12 windows). Its
  champion count, 29, equals the 156 class mean
  exactly (29.0), but its middle holds 55 distinct
  sizes vs the motif's 24.5 and 520 large actions
  vs 68.
- Its window classes are scattered like any
  standard context (full 8, no30480 11, no32784 3,
  other 30); motif-form windows (band-led with a
  variant/full class) number 13 of 52, and its
  longest motif-form run is 4 — rank 91 of 311 in
  the ≥12 pool (pool best: 14, in 0856a10c cidx 100,
  a 206-action context; pool motif-form mean 16.7
  windows, driven by window counts far above 12).
- The pin itself decomposes: window 0 IS a genuine
  motif-form window (lead 8576, in band; the first
  windows run back-to-back — 3856, 32784, 32784,
  then a band-led 3856 with no 30480 between — which
  is exactly the no30480 shape). Window 4's class
  matches the motif's pin in SHAPE only: its lead
  is 9216, outside the band, and windows 4–7 are led
  by a 9168–9248 lead cluster (9216/9208/9224/9168)
  that the band census never counted. 15 of its 52
  windows have out-of-band leads (range 24–9248);
  window 15's lead is the size 24 itself.
- So the double pin is two unrelated facts in one
  context: an in-band no30480 at ordinal 0, and an
  out-of-band-led no32784 at ordinal 4. No 12-block
  structure, no pinned run, no shared construction
  with the 156 class beyond the ordinary band habit.

Graded MEASURED, NEGATIVE: the both-pinned context
is not a motif relative and not a bridge class; the
156 motif's pinning remains unique. NEW OBJECT: a
9168–9248 lead cluster leading windows 4–7 of this
context — whether a second lead band exists
corpus-wide is queued in 4.52.

## What this closes and what it queues

- MEASURED: exact emergence thresholds for the
  channel order function — 35 channel runs / 34
  full runs / last 18 channels / last ≤20 runs /
  first 122 channels, all zero-mixed; below-threshold
  failures concentrate in named groups, and from
  run-prefix 22 the 0a0d378c stack is the only one.
- MEASURED: the stack's split is one channel-0 vs
  channel-2 divergence at middle position 121 with
  a run-phase cascade (228 differing positions vs
  every normal member; the reversed member is the
  stack's unique sequence).
- MEASURED: the band's non-3856 followers are 49.4%
  two forms — the rigid 8208→4112→3088→32784 chain
  (a second fixed construction) and the scattered,
  3856-avoiding 4368 continuation; the rest scatter
  over 251 sizes.
- MEASURED, NEGATIVE: 76c3a8ff cidx 4 is not a motif
  relative; its double pin mixes an in-band window 0
  with an out-of-band (9168–9248) led window 4.
- NEXT (4.52): last-runs exact emergence (16–20) and
  the sister group's run-22 resolution detail; the
  position-121 diverging action's anatomy (size and
  neighbourhood in the stack members); the
  8208→4112→3088 chain's full extent (length,
  terminator, segment identity across contexts);
  the 9168–9248 lead cluster census in standard
  middles (a second lead band?). Host/artifact
  analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
