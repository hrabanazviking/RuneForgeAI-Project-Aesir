# Last-runs emergence, position-121 action, chain extent, lead cluster (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.52 (AES-NUM-052).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef52.py
(sha256 5123fb68…) plus the labelled follow-up
hef52b.py (sha256 5610901f…). Controls reproduce
AES-NUM-029/032/033/034/035/036/037/038/039/040/041/
042/043/044/045/046/047/048/049/050/051 EXACTLY in
both scripts (128,787 pooled small actions; 79,001
pooled 24 B bursts; 745,849 pointer actions; 1,504
contexts; trailing distinct (channel, operand) pairs
2,049; champion-headed bursts 75,215). Transfers were
sha-gated: hef52.py via gzipped 373 B parts (whole-file
shas verified on-device first try); hef52b.py's first
373 B-part crossing failed its whole-file sha, was
discarded uncommitted, and the file crossed instead
as two sha-gated file.write halves (final sha gate
passed on-device). Definitions (middle, pair, binary
population, band, window classes) are as in
AES-NUM-049/050/051: middle = actions [12 : len−56];
binary contexts 1,428 (693 normal, 735 reversed);
band = sizes 8104–8832.

## Last-runs emergence is exactly 17 channel runs — and ≤5 runs with lengths

AES-NUM-051 left the last-N-runs (RLE channels)
threshold inside 16–20. Slice 4.52 pinpoints it:

- Last-N runs, channels only: N=14 has 2 mixed groups
  (23 contexts); N=15 and N=16 retain exactly ONE
  mixed group of 3 contexts — 0856a10c cidx 3
  (reversed, 280 actions) against cidx 25/37 (normal,
  832) — and N=17 is CLEAN (387 keys, 118 multi
  groups covering 1,159 contexts, 0 mixed), as are
  18–21. The exact threshold is 17 channel runs.
- Last-N runs WITH lengths (RLE full) is clean at
  every scanned N from 5 upward (375–402 keys, ~120
  multi groups, 0 mixed at N=5, 8, 10–14, and 14–20
  in hef52.py) — its threshold is ≤5, the lowest
  scanned; not pinpointed below 5.
- Rechecked anchors from AES-NUM-051 stand: last-17
  channels retains exactly the one cross-artifact
  mixed pair (5ab3537d cidx 210 reversed vs 76c3a8ff
  cidx 88 normal); last-18 channels is clean.

Graded MEASURED: the channel order function's
suffix forms have exact thresholds — last 17 channel
runs, last 18 channels — while the length-carrying
suffix form separates at ≤5 runs, far earlier than
any prefix form (35 runs / 122 channels).

## The sister group resolves at run 22 because run 21 flips channel 0 → 2

The run-prefix-20 second mixed group (AES-NUM-051) —
5ab3537d cidx 87 (normal) against 773470cd cidx
87/211 (reversed), all 841 actions, middles of 773 —
stays mixed at run-prefix 21 and resolves at 22:

- The two reversed members are channel-identical to
  each other (same RLE throughout). Against the
  normal member, the RLE channel sequence first
  differs at run index 21: normal run 21 = (channel
  0, length 5); reversed run 21 = (channel 2,
  length 2), followed by (1, 29) where the normal
  continues (2, 9), (0, 1), (2, 1). Reading 22 runs
  is exactly what includes run 21 — hence the
  prefix-22 resolution.
- Run LENGTHS differ from run 0 (normal (0, 1) vs
  reversed (0, 5)) and at runs 18–20 (lengths 8/14
  vs 7/1 with equal channels), so an RLE-full key
  separates the sisters immediately; the corpus-wide
  RLE-full prefix threshold of 34 is the 0a0d378c
  stack's, not the sisters'. The sisters' raw channel
  streams differ at 461 positions (phase drift from
  the length differences), but their channel ORDER
  agrees for 21 runs.

Graded MEASURED: the sisters' run-22 resolution is
one channel substitution at run 21 (0 in the normal
member, 2 in both reversed members) after 21 runs of
identical channel order with differing lengths.

## The position-121 diverging action is a band-sized 8208 on channel 0

AES-NUM-051 found the 0a0d378c stack (cidx 5 reversed
vs 14 normals, all 763 actions) splits at middle
position 121 (channel 0 vs 2). Slice 4.52 measures
the action itself:

- At position 121 the reversed member carries size
  8208 on channel 0 (offset 41,739,776 in its
  artifact). All 14 normal members carry a ~5.5 KB
  channel-2 action there (sizes 5,480–5,656, all
  distinct-ish per member: 5536 ×3, 5496 ×2, nine
  singletons) — the slot the normals fill with one
  of their repeating (25872, ~5.5k, 7952, 32784)
  pattern's small members.
- The neighbourhood is phase-shifted, not locally
  edited: positions 110–120 are identical in size
  class and channel across all 15 members (25872 /
  ~5.5k / 7952 / 32784 pattern, all channel 2), but
  from 121 onward the reversed member's pattern is
  offset by one slot against every normal (rev 5488
  at 122 where normals hold 7952; rev 7952 at 123
  where normals hold ~5.5k; …), and at 131–132 the
  reversed member holds (7952 ch2, 25872 ch1) where
  normals hold (25872 ch1, 8208 ch2) — the normals
  DO carry an 8208, two pattern-slots later and on
  channel 2.
- So the divergence is structural: the reversed
  member's middle inserts a band-sized 8208 on
  channel 0 at the slot where the normals run their
  small pattern member, and the whole local pattern
  phase-shifts behind it. 8208 is the chain band
  value of part (iii) — the same size, here on
  channel 0 inside 0a0d378c.

Graded MEASURED: position 121's diverging action is
size 8208 / channel 0 in the reversed member vs
~5.5 KB / channel 2 in all 14 normals, with a
one-slot phase shift of the surrounding pattern.
NOT PROVEN: any mechanism, and whether this action
is the pair-order bit's cause or another correlate
of stack identity (AES-NUM-050's boundary stands).

## The 8208→4112→3088 chain: 672 occurrences, sisters only, 6 per context, private payloads

Reconciliation first: band→4112 followers number 683
(AES-NUM-051); of those the band value is 8208 in
673, and 672 of those are followed by 3088. The
chain population (8208, 4112, 3088) in standard
middles is 672 occurrences — ALL in the sister
artifacts (5ab3537d 336, 773470cd 336), in exactly
112 contexts, exactly 6 chains per context.

- Full extent (unbounded follow): after 3088 the
  32784-run length is {0: 2, 1: 73, 3: 144, 4: 20,
  5: 38, 9: 19, 10: 40, 11: 189, 13: 54, 15: 92,
  16: 1}; the terminator after the run is 29712 in
  375, 4112 in 114, 80 in 70, 12304 in 58, 32 in
  38, 6160 in 16, 8208 in 1 — never a middle-end
  truncation (every chain terminates inside its
  middle). Total chain length (8208 through the
  terminator) runs 3–19 actions; 20 distinct full
  size sequences exist, the commonest being
  (8208, 4112, 3088, 32784 ×11, 29712) at 189.
- Predecessors are a small set: 29712 (297), 6160
  (110), 32784 (98), 24 (94), 528 (38), 12304 (18),
  80 (17) — summing to all 672.
- Segment identity: the chain is a SIZE template,
  not shared bytes — the segments at chain positions
  0–3 are distinct in 672/672 occurrences (position
  4: 618 distinct), and all 672 combined hash tuples
  (positions 0–4) are distinct. Every chain carries
  private payload segments under a rigid size shape.
- Channel shape varies (26 distinct 8-channel
  prefixes; commonest (0,0,0,1,1,1,1,1) at 164).

Graded MEASURED: the chain is a sisters-only rigid
size construction (672 = 112 contexts × 6), with a
32784 tail of 0–16 and a small terminator vocabulary
led by 29712, over entirely private segment bytes.

## The 9168–9248 cluster is a second lead ladder — concentrated, with its own dialect

Census of window leads (size before a 3856) in
standard middles: 20,411 windows, 10,334 band-led,
743 led by the 9168–9248 cluster.

- The cluster is an exact step-8 ladder of 11 values
  (9168, 9176, …, 9248), counts 51–90 per value —
  the same ladder shape as the band, one rung-set
  higher. All values are multiples of 8.
- But it is NOT corpus-wide: 688 of 743 sit in
  cc9b9d1c (19 of its 271 contexts; per-context
  counts up to 63) and 55 in 76c3a8ff — in exactly
  TWO contexts there (cidx 3: 41, cidx 4: 14). Total
  cluster-led contexts: 21. No other artifact leads
  a single window from the cluster.
- Its window dialect differs from the band's: the
  size after a cluster-led 3856 is 32784 (295),
  32016 (52), another cluster value (48 over the
  top three), 30480 only 12; the top after-4
  patterns interleave 32784 with 32016
  ((32784,32784,32016,32784) 23; (32784,32016,32784,
  32784) 11; (32784,32016,32784,32016) 10) — 32016
  plays the role 30480 plays behind band leads.
  Window classes: other 557, no30480 165, no32784
  12, full 9.
- In 76c3a8ff cidx 4 the cluster leads 14 windows,
  not just windows 4–7 (AES-NUM-051's pin context):
  ordinals 4–7, 27–33, and 47–49.
- Context: out-of-band leads overall number 9,257
  in 8833–10000 alone over 126 distinct values
  (top: 9752 ×255, 9760 ×248, 9728 ×222) — the
  9168–9248 ladder is one structured family inside
  a broad out-of-band lead population, distinguished
  by its exact 11-rung ladder and its 32016 dialect.

Graded MEASURED: a second lead ladder EXISTS
(11 step-8 values, 743 windows) but it is a
cc9b9d1c-centred family (19 contexts) plus two
76c3a8ff contexts, speaking a 32016 dialect — not a
corpus-wide second band. NOT PROVEN: what selects a
context for cluster vs band leadership.

## What this closes and what it queues

- MEASURED: last-runs emergence exact — 17 channel
  runs (sole holdout through 16 = the 0856a10c
  cidx 3 vs 25/37 group); last-18 channels reconfirmed;
  RLE-full suffix separates at ≤5 runs.
- MEASURED: the sister group resolves at run-prefix
  22 because run 21 flips channel 0 (normal) → 2
  (both reversed); lengths separate the sisters from
  run 0, so their holdout is purely channel-order.
- MEASURED: the stack's position-121 action is an
  8208 on channel 0 (reversed) vs ~5.5 KB on
  channel 2 (all normals), with a one-slot phase
  shift; the normals carry their own 8208 at
  position 132 on channel 2.
- MEASURED: the 8208→4112→3088 chain is sisters-only
  (672, exactly 6 per context in 112 contexts), a
  rigid size template (32784 tail 0–16, terminator
  vocabulary led by 29712) over 672/672 private
  segment payloads.
- MEASURED: the 9168–9248 cluster is an 11-rung
  step-8 lead ladder (743 windows, 21 contexts,
  688 in cc9b9d1c) with a 32016 window dialect —
  a concentrated second lead family, not a
  corpus-wide band.
- NEXT (4.53): cluster-context selection in
  cc9b9d1c (19 contexts vs the other 252 — what
  distinguishes them?); 32016 dialect anatomy
  (cluster windows' full size shapes vs band
  windows'); chain context selection in the
  sisters (112 of their contexts carry exactly 6 —
  which contexts, and do the sisters share the
  same 112?). Host/artifact analysis only — no
  physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
