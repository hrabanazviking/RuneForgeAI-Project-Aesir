# Channel scaffold at corpus scope, the A-boundary law, C→A reset (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.71 (AES-NUM-071).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef71.py
(sha256 658d4703…) + labelled follow-up hef71b.py
(sha256 d893f9a0…), both sha-gated gzipped 373 B-part
transfers, whole-file shas verified on-device. Controls
reproduce AES-NUM-029/032…070 EXACTLY (128,787 pooled
small actions; 79,001 pooled 24 B bursts; 745,849
pointer actions; 1,504 contexts; trailing distinct
(channel, operand) pairs 2,049; champion-headed bursts
75,215). Definitions (seam set A = 7952, B = 32784,
C = 26896; classes = contexts of one action count) are
as in AES-NUM-061…070. The "rotation artifacts" are
0a0d378c, cc9b9d1c and 76c3a8ff; 76c3a8ff holds only
10 A actions corpus-wide (its streams are the B/C
two-member regime of AES-NUM-064), so A-laws rest on
0a0d378c (13,586 A) and cc9b9d1c (5,568 A).

## (i) The channel scaffold is CLASS-local, not artifact-wide — and inside 0a0d's triplet classes it is near-total

At whole-artifact position alignment the scaffold
vanishes completely:

- Per-position channel rigidity (positions with support
  ≥10 contexts and ≥50% of the artifact's contexts):
  ZERO single-channel positions in every artifact and
  every position band (0–12, 13–35, 36–100, 101–250,
  251+), and modal-channel ≥0.9 at only 3 isolated
  positions corpus-wide (0a0d378c one at 13–35; each
  sister one). Position-aligned channel is not an
  artifact-level object at all.
- The two windows AES-NUM-070 froze inside the 623
  class do not survive widening to their own artifact:
  at 205–221 the 162 supporting 0a0d378c contexts carry
  33 distinct channel sequences (vs 1 in the class's
  16), and at 443–459, 29 distinct over 98 contexts.
  Every other artifact is likewise plural at both
  windows (26–92 distinct channel sequences).
- Sliding 17-action windows single-valued in channel
  across ALL supporting contexts of an artifact exist
  only as class shadows: the sisters' 39 windows at
  starts 966–1004 (support 28 = exactly their
  1021-action class; size sequences single there too)
  and cc9b9d1c's 12 windows at starts 826–837 (support
  16, channel-only — size sequences NOT single).
  0856a10c, 0a0d378c, 76c3a8ff and MiniLM have none.

Inside action-count classes the picture inverts, and
channel rigidity EXCEEDS size rigidity:

- 0a0d378c (9 classes, n ≥8): 2,645 of 4,056 pooled
  class positions are single-channel (65.2%) against
  only 1,053 single-size (26.0%); 1,587 of 3,912
  class windows are single-channel-sequence against
  409 single-size-sequence. The triplet classes are
  near-total: the 290 class is single-channel at
  290/290 positions (its full length, far beyond the
  head template's 29), the 419 class at 417/419, the
  623 class at 613/623, the 123 class at 107/123.
  The big 763 class (n 32) is the exception at
  119/763 — rigidity is a property of the templated
  classes, not of class membership alone.
- The sisters behave like 0a0d378c, not like the
  pooled numbers suggest: pooled class positions
  62.3% / 58.5% single-channel (5ab3537d / 773470cd),
  with whole mid classes single at every position
  (470, 471, 496 in both; 761 in 773470cd at
  761/761).
- cc9b9d1c and 0856a10c classes are channel-loose:
  12.6% and 14.3% of pooled class positions
  single-channel, their single windows dominated by
  a recurring block of exactly 39 windows per class.
  76c3a8ff sits between (23.0%).

Verdict: there is NO corpus- or artifact-scope
channel scaffold. The scaffold is real but scoped
exactly like the head templates: it lives inside
homogeneous action-count classes, where in the
templated classes (0a0d378c triplet, sister mids)
the channel at essentially every position is a class
constant even where sizes vary freely — channel is
the MORE rigid of the two streams inside a class,
and wholly unrigid outside one.

## (ii) The A-boundary law: A is never entered adjacently because exactly a 5–7k data action on A's own channel stands before it

Rotation-pooled A entries: 19,164 (successors and
predecessors counted over the seam sequence of each
context). Predecessor seam letters: B 8,504, A 5,966,
C 4,603, FIRST (A is the context's first seam action)
91. Gaps to the predecessor seam action:

- From C: min 2, median 2, mean 2.25, gap ≤2 in
  4,263/4,603 (92.6%), gap 1 in ZERO.
- From A: min 2, median 2, mean 2.87, gap ≤2 in
  4,446/5,966 (74.5%), gap 1 in ZERO.
- From B: median 3, mean 3.24, gap 1 in exactly
  1/8,504 — and that sole exception is one of
  76c3a8ff's 10 A actions (the two-member artifact),
  so in the two true rotation artifacts B→A gap 1
  is 0/8,496.
- First-seam A sits deep: position min 25, median
  34, mean 38.2 (max 323) — A never opens a context
  (0 A at position 0 corpus-wide).

The action immediately before A (position p−1,
non-first entries, 19,073) explains the law:

- Its size is in the 5,000–6,999 band in
  19,015/19,073 (99.7%): 0a0d378c 13,522/13,523
  (sizes ~5.5k; top 5496 ×630, 93 distinct),
  cc9b9d1c 5,492/5,541 (sizes ~6.5k; top 6520 ×480,
  59 distinct), the remaining 50 at 24 B and 8 other.
  The predecessor is an ordinary varying data action
  of one artifact-specific size family — NOT a fixed
  size (143 distinct pooled) and never a seam member.
- Its channel EQUALS A's channel in 18,881/19,073
  (98.99%): 0a0d378c 99.33%, cc9b9d1c 98.23%. The
  controls are far lower (the action before a B
  matches B's channel 69.1% of the time; before a
  C, 85.9%) — channel continuity into A is specific
  to A.
- A's own exit is the mirror: successor B in
  12,121 cases at gap 1 in 11,145 (91.95%);
  successor A never at gap 1 (0/5,966); successor
  C at gap 1 in 865/1,046.

Verdict: the A-boundary is a two-part law. In seam
terms A is a block boundary — never the adjacent
successor of any seam action (one two-member-
artifact exception). In action terms the boundary
is marked, not empty: the last intervening action
before every A is a 5–7k data action on A's own
channel (99.7% / 99.0%), after which A is entered
and typically hands over adjacently to B. What
selects that data action's exact size (93–59
distinct values per artifact) is NOT PROVEN.

## (iii) C→A reset: one intervening data action in 92.6% — no fixed reset segment; cc9's long gaps live on the step-4 rail

C→A gaps, rotation-pooled (n 4,603): min 2, median
2, mean 2.25, p90 2, p99 11, max 20. The reset is
minimal:

- Gap exactly 2 — exactly ONE intervening action —
  in 4,263/4,603 (92.6%): 0a0d378c 1,572/1,637
  (96.0%, max gap 9), cc9b9d1c 2,691/2,966 (90.7%).
  Gap ≤10 covers 98.8% pooled.
- The single intervening action is always a
  5,000–6,999-band data action (100% in both
  artifacts): 41 distinct sizes in 0a0d378c (top
  5568, share 9.7%), 58 in cc9b9d1c (top 6520,
  share 9.0%). It is the same p−1 population as
  §(ii) — the "reset" IS the A-boundary marker
  action, seen from the C side.
- No fixed reset SEQUENCE exists at any length:
  337 distinct intervening size-sequences pooled;
  the most common sequence at each intervening
  length with n ≥20 holds only 4–11% of its class.
  Intervening runs never contain a seam member, a
  skeleton size or a 304 (0/4,603 each); a 24 B
  burst appears inside only 84 (all cc9b9d1c).
  C and A sit at matching stream fractions (means
  0.432 / 0.438) — the reset is local, mid-stream,
  not a head/tail event.
- The long tail is structured, not noise: gaps
  11 and 12 occur ONLY in cc9b9d1c (27 each), in
  exactly the step-4 rail contexts (cidx 4–108 and
  141–245, all ≡0 mod 4 — the 606/607 rail of
  AES-NUM-058/059), with 42 distinct intervening
  sequences over 54 occurrences. 0a0d378c has no
  C→A gap above 9.
- Controls (rotation-pooled gaps): B→A median 3 /
  mean 3.24, A→A median 2 / mean 2.87, A→B median
  1 (gap-1 share 0.9195), B→C median 1 (0.9552),
  C→B median 1 (0.6483), A→C median 1 (0.8270).
  C→A is the only rotation step whose median gap
  exceeds 1 while its gap-1 share is exactly zero
  in the true rotation artifacts.

Verdict: rotation reset after C is a single ordinary
data action — the A-boundary marker of §(ii) — in
92.6% of cases, with no fixed segment, no skeleton
or seam content, and a rail-bound long tail in
cc9b9d1c. The rotation's rhythm is: A entered
across one marker action, B taken adjacently,
C taken adjacently, then exactly one marker action
before the next A.

## What this closes and what it queues

- MEASURED: no artifact-scope channel scaffold
  (0 single-channel positions at artifact alignment
  in all 7 artifacts; the 623 class's windows carry
  33 / 29 distinct channel sequences artifact-wide);
  class-scope scaffold near-total in the templated
  classes (290: 290/290 positions; 419: 417/419;
  623: 613/623) with channel MORE rigid than size
  inside classes (0a0d378c 65.2% vs 26.0%).
- MEASURED: the A-boundary law — gap 1 into A in
  0/19,064 non-first entries in the true rotation
  artifacts (0a0d378c + cc9b9d1c; the sole pooled
  exception is one of 76c3a8ff's 10 A actions);
  the p−1 action is a 5–7k data action (99.7%) on
  A's own channel (98.99%).
- MEASURED: C→A reset = gap 2 in 4,263/4,603
  (92.6%), the intervening action always in the
  5–7k band, no fixed reset sequence (337 distinct;
  top share ≤11% per length class); long gaps
  11/12 are cc9b9d1c step-4-rail only (54).
- NEXT (4.72): the marker action's exact size
  selection (the 41/58-value pools vs context /
  position / the following A–B pair); channel-rigid
  classes in cc9b9d1c's loose population (which
  classes carry the 39-window block); the 763
  class's channel dissolution vs its size stream.
  Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
