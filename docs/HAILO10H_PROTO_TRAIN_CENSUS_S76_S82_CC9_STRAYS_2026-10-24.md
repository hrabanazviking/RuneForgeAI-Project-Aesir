# Proto-train census, S76/S82 divergence, cc9 strays (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.74 (AES-NUM-074).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef74.py
(sha256 cb384a8e…) + labelled follow-up hef74b.py
(sha256 f66ff357…), both delivered by sha-gated 500-char
part transfer (whole-file sha256 verified on-device for
both the gzip and the script, first try). Controls
reproduce AES-NUM-029/032…073 EXACTLY (128,787 pooled
small actions; 79,001 pooled 24 B bursts; 745,849
pointer actions; 1,504 contexts; trailing distinct
(channel, operand) pairs 2,049; champion-headed bursts
75,215). Definitions (seam set A = 7952, B = 32784,
C = 26896; classes = contexts of one action count;
cidx/ngpos = proto order) are as in AES-NUM-061…073.
One correction is recorded inside arm (ii): hef74's
first pass took the largest channel group overall
(G12, the ng-0 group) as its reference, so its
S76/S82 Hammings (~438/478) are cross-train distances;
hef74b re-ran arm (ii) against the ng-1 train's own
reference (G10) and those are the numbers graded here.

## (i) The proto-train census: 0a0d378c is a residue partition plus a mirrored tail

Every multi-context class in 0a0d378c (180 contexts;
ng 0 = 74 contexts, ng 1 = 106) decomposes into exact
arithmetic trains in ngpos — no exceptions:

- ng 0 main body (ngpos 0–63): four stride-4 trains,
  one per residue, each exactly 16 slots — 321
  (residue 0), 763 (residue 1), 620 (residue 2), 623
  (residue 3). Their ngpos sets are disjoint and cover
  0–63 completely.
- ng 1 main body (ngpos 0–95): six stride-6 trains,
  one per residue, each exactly 16 slots — 280
  (residue 0), 123 (residue 1), 763 (residue 2), 617
  (residue 3), 419 (residue 4), 290 (residue 5).
  Disjoint, covering 0–95 completely.
- 763 is the ONLY class present in both network
  groups; it holds exactly the residue-1 slot of the
  ng-0 partition and the residue-2 slot of the ng-1
  partition (AES-NUM-073's two trains are partition
  slots, not a class peculiarity).

The remaining ten contexts of each group form a tail
with the SAME class sequence in both groups, at
ngpos 64–73 (ng 0) and 96–105 (ng 1): 768, 758,
759, 950, 759, 950, 759, 950, 760, then a singleton
(85 in ng 0, 92 in ng 1). Inside the tail, 759 and
950 are themselves stride-2 trains of three slots in
each group (759 at even offsets 66/68/70 and
98/100/102; 950 at odd offsets 67/69/71 and
99/101/103), and 758/760/768 hold one context per
group at matching offsets (65/97, 72/104, 64/96).

Per-train rigidity (class-wide, from hef74): channel
is single-valued at 290/290 positions in 290,
417/419 in 419, 613/623 in 623, 425/620 in 620,
419/617 in 617, but only 119/763 in the mixed 763
class and 116/321 in 321; size single-valued counts
run 74/321 (321) to 239/620 (620), modal coverage
0.5632 (623) to 0.9278 (123).

Cross-class family relations:

- Tails (universal): every pair of n = 16 classes —
  and both 763 train templates — agree on the last
  55 modal sizes 55/55 (the AES-NUM-072 universal end
  block; graded already, re-verified here).
- Heads (shared size scaffold, private channels):
  pairwise modal head (positions 0–12) size agreement
  between distinct n = 16 classes is 9–12 of 13, and
  the 763 train templates score 9–13 of 13 against
  them — the head SIZE scaffold is common property.
  Head CHANNEL agreement between distinct classes is
  only 2–11 of 13, with one near-exception pair:
  763's ng-1 template matches both 290 and 623 at
  13/13 head sizes and 12/13 head channels, and
  290 vs 623 themselves agree at 13/13 head sizes
  and 11/13 head channels. No other cross-class
  channel relation comes close.
- Tail cross-group test: the 759 templates of the
  two groups agree at 75 of their 76 jointly-single
  size positions, the 950 templates at 65/65 — the
  tail trains carry (nearly) one size family across
  groups where they are rigid at all. The singleton-
  pair classes do NOT: the ng-0 vs ng-1 members of
  758 / 760 / 768 match in size at only 318/758,
  237/760, 252/768 positions (channels 281, 394,
  245) — no cross-group identity for singletons.

## (ii) S76/S82 divergence is a step, not a gradient — and it lives in the head

Against the ng-1 train's own reference (G10's exact
channel sequence; G4 stands 3 flips from it, verified
again here), the sixteen train slots score:

- Slots 2–15 (cidx 88–166): Hamming 0 (G10 members)
  or 3 (G4 members) — family-exact.
- Slot 1, S82 (cidx 82): Hamming 54 to G10 and 54
  to G4; size matches 583 of G10's 587 single
  positions (only 4 exceptions: 65, 85, 114, 129).
  A near member whose divergence is almost purely
  channel-side.
- Slot 0, S76 (cidx 76, the train head): Hamming
  182 to G10 (179 to G4); size matches only 407/587
  of G10's single positions (180 exceptions). A
  distant member in both channels and sizes.

Position structure of the divergence:

- S82's 54 channel diffs concentrate early: first
  diff at position 54, 22 inside the first 128
  positions (40.7% against a uniform expectation of
  16.8%), a 14-count block at 512–575, and exactly
  one diff (position 621) past 575. Only three runs of
  length ≥ 4: 117–122 (6), 323–326 (4), 518–529
  (12). The 88–120 zone from AES-NUM-073 is exactly
  a two-sided flip block: positions 88–108 flip
  0 → 2, positions 111–122 flip 2 → 0.
- S76's 182 diffs start LATER than S82's (first at
  70; block 0–63 is clean) but run much deeper:
  57.1% inside the first 256 (uniform 33.6%), in
  long runs — 146–167 (22), 223–236 (14), 95–108
  (14), 172–184 (13), 517–527 (11) — and ZERO
  diffs from position 704 to the end (the tail,
  including the universal end block's span, is
  channel-identical to the family).

So "early-train divergence" is literal: divergence
is a property of the train's first two slots only,
it is confined to the head/middle of the context
(no diff past position 673 in S76, 621 in S82), and
it comes in two grades — S82 channel-only and near,
S76 channel-and-size and far. There is no gradual
convergence along the train: slot 2 is already
family-exact.

## (iii) The cc9 band strays are paired slot draws at a fixed context offset

cc9b9d1c's 5,000–6,999 band holds 5,676 actions in
63 distinct sizes; 99.82% of band actions sit on the
58-rung ladder (6,112–6,568 step 8, all rungs
present). The ONLY band sizes off the ladder are
the five strays — 5480, 5616, 5808, 5904, 6880 —
each occurring EXACTLY twice in the whole artifact,
never as a CA2 marker (AES-NUM-072/073 definitions).

Each stray's two occurrences form one fixed pattern:

- 5480 / 5616 / 5808 / 5904: one occurrence in an
  ng-0 context of class 259 at position 104, the
  other in an ng-1 context of class 256 at position
  180. Both slots are band slots whose modal value
  is the ladder rung 6160 (class 259 @104: 6160 in
  22/28 contexts, the four strays once each, plus
  32784 and 4112 once each; class 256 @180: 6160 in
  21/27, the four strays once each, plus 48 and
  4112 once each). In both windows the stray sits
  immediately after a 12304 action, inside the same
  seam neighbourhood shape.
- 6880: both occurrences in class 839 at the SAME
  position 461 (slot population over 6 contexts:
  32784 ×3, 6880 ×2, 14864 ×1), one ng-0 (cidx 122)
  and one ng-1 (cidx 259) context. That pair of
  contexts is size-near-identical overall: 826/839
  size positions match (channels only 309/839).
- ALL FIVE pairs stand at the same context offset:
  cidx difference exactly 137, ngpos difference
  exactly +3 (the ng-1 partner is always the ng-0
  context's ngpos + 3). The pairing is uniform
  across two different slot patterns and three
  classes — it is a context-pairing property of
  the artifact, not of any one slot.

Verdict: the strays are not stray at all in kind —
they are ordinary (if rare) draws at band slots
whose modal draw is a ladder rung, and each rare
draw is taken TWICE, once in each member of a
context pair standing at ngpos offset +3. WHY that
offset pairs contexts, and whether the pairing
holds for ordinary slot values artifact-wide in
cc9b9d1c, is NOT PROVEN by this slice.

## What this closes and what it queues

- MEASURED: 0a0d378c's classes are a complete
  residue partition — ng 0: stride 4 × residues
  0–3 over ngpos 0–63; ng 1: stride 6 × residues
  0–5 over ngpos 0–95; 763 is the only dual-group
  class (residues 1 and 2) — plus a ten-context
  tail per group carrying the identical class
  sequence 768, 758, 759, 950, 759, 950, 759, 950,
  760, singleton in both groups.
- MEASURED: cross-class relations are exactly
  three: the universal last-55 (55/55 everywhere),
  a shared head SIZE scaffold (9–13/13 between
  distinct classes) with private head channels
  (2–11/13; sole near-pair 290/623 at 11/13, with
  763-ng1 at 12/13 to both), and tail trains
  759/950 sharing one size family across groups
  where jointly single (75/76, 65/65) while the
  singleton classes share none (237–318 of ~760).
- MEASURED: S76/S82 divergence is a two-slot step
  at the ng-1 train's head (slot 0: 182 channel +
  180 size exceptions; slot 1: 54 channel + 4 size;
  slots 2–15: 0–3 channel, family-exact), confined
  to positions ≤ 673 (S76) and ≤ 621 (S82), with
  zero diffs in either member from 704 on; S82's
  88–122 zone is a two-sided 0↔2 flip block.
- MEASURED: cc9b9d1c's five off-ladder band sizes
  occur exactly twice each, never as markers,
  always as paired draws at band slots (modal draw
  the rung 6160 at both 259@104 and 256@180; 6880
  at 839@461), and every pair stands at cidx +137 /
  ngpos +3.
- NEXT (4.75): the cc9 ngpos+3 context pairing at
  artifact scope (do paired contexts share slot
  values generally, or only rare draws?); S76's
  long diff runs as channel transforms (per-run
  flip maps vs G10); the 0a0d tail singletons
  85/92 and the 758/760/768 cross-group mismatch.
  Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
