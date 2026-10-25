# Two-member alternations, collapsed/degraded members, 135 vs 134 (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.64 (AES-NUM-064).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef64.py
(sha256 4e11ab01…) and the labelled follow-up hef64b.py
(sha256 e9f29aea…). Controls reproduce AES-NUM-029/032…063
EXACTLY (128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts; trailing
distinct (channel, operand) pairs 2,049; champion-headed
bursts 75,215). Transfers were sha-gated gzipped files in
373 B parts (hef64) and 300 B parts (hef64b, after one
373 B part corrupted deterministically in re-emission,
was rejected by its base64 gate, and healed on the
re-split — whole-file shas verified on-device before
both runs). Definitions (middle, seam set A = 7952,
B = 32784, C = 26896; alt set 7952/25872/32784) are as
in AES-NUM-061…063.

## (i) Two-member alternations: one genuine population, the rest are projections

### 76c3a8ff B↔C — the genuine alternation, in two regimes

The 14 contexts of AES-NUM-063 (cidx 83–88, 90 and their
ng-1 repeats 343–348, 350; 7952 entirely absent, and no
alt member either) split by action-count class:

- Dense regime (862/936-action contexts: 83, 84, 86, 88,
  90 + repeats): B carries the bulk in runs, C is the
  separator. Pooled over all 14 contexts, B runs average
  1.83 (1,114 runs, max 15) against C runs at 1.21
  (1,109 runs, max 5). Self-transitions are lopsided
  B-side (BB 55–121 per context vs CC 12–28), while the
  CROSS transitions stay near-equal in every context
  (BC vs CB within 2: 92/92, 99/100, 107/106, 110/110,
  42/42, and likewise in the repeats).
- Sparse regime (776-action contexts: 85, 87 + repeats
  345, 347): near-singleton alternation — 97–106 runs
  over 123–126 letters, BC ≈ CB ≈ 48–53, BB/CC only
  8–15 — with wide spacing (gap mean 4.42–4.70 vs the
  dense regime's 1.47–1.90).

Gap structure (all 14 pooled): gap 0 (adjacent members)
is the mode (1,809 gaps), gap 2 second (647); the long
tail reaches 104 once (cidx 350). The actions sitting
between members are dominated by two sizes — 1552
(1,735 occurrences) and 14096 (1,609) of 7,727 total
between-actions over 676 distinct sizes. Boundaries:
the first member sits at action position 13–45, the
last at 700–879, with 56–75 actions after it (the fixed
end region); the size before the first member is 14096
in 6 of 14 contexts — the same size that dominates the
between-gaps.

CORRECTION of emphasis to AES-NUM-063: its "B↔C
transitions symmetric" is exact only for the cross
transitions. The dense regime is not a symmetric
alternation — it is B-runs punctuated by mostly-single
C separators; only the sparse 776 regime approaches a
true 1:1 alternation.

### 0a0d seam-pair subsequences are projections, not blocks

In the alt classes (617/620/763, and equally 280/321),
the seam-pair (7952↔32784) subsequence AES-NUM-063
noted is what remains when the alt third member
(25872, present at full dose 128–161) is deleted from
a full triplet rotation: cross transitions AB ≈ BA
(81/81, 80/80, 96–101/96–101), self AA ≈ BB (46–64
each), gap mean 1.07–1.17. The corpus census agrees:
all 99 of 0a0d's exactly-two-member seam contexts
(n ≥ 20) belong to alt-triplet classes (321 ×16,
763 ×32, 620 ×16, 280 ×16, 617 ×16, plus 3 collapsed
623 contexts whose C died — see (ii)). There is no
independent 0a0d seam-pair block to encode.

The same holds mirrored in cc9b9d1c: its 171
two-member contexts in the alt frame (7952/32784 —
the cycle classes 245/256/259/738 and zone tails) are
the seam triplet with 26896 deleted; there the pooled
self term is C-side (32784→32784 12,554 vs cross
3,525/3,550), because 32784 is the run-carrying member
of cc9's rotation. Genuine two-member populations
outside 76c3 are only small: 0856a10c seam B/C ×5
(cidx 14, 20, 23, 82, 83), cc9 seam B/C ×2 (151, 203),
and 3-context A/B remnants in 76c3/0856.

## (ii) Collapsed/degraded members: B dies first; the replacement is not the band

Member-survival order is uniform across all three
classes (290/419/623): in every partial context the
32784 (B) deficit is the largest, 26896 (C) next,
7952 (A) at or near full dose —

- 290 cidx 109: A48 (full) / B4 / C39; cidx 163:
  A48 / B35 / C46.
- 419 cidx 108: A78/80 / B18 / C66; cidx 162:
  A80 / B66 / C68.
- 623 cidx 23: A126/128 / B24 / C105; cidx 59:
  A128 / B103 / C114.

End states: A-only contexts (290: 115 A8, 127 A26,
133 A10; 419: 114 A26, 126 A47, 132 A24; 623: 27/39
A34 + B2, 35 A73 + B2) and zero contexts (290: 121,
139, 169; 419: 138, 120 A2, 168 A1; 623: 31 A2B2,
43 B2, 63 A1B2). Even A's dose is not conserved in
the end states (48 → 8–26 in 290). Degraded members
cluster mid-sequence in each class's cidx train
(290: partial/collapsed at 109–139, near-full returns
at 145, partial again 163, zero at 169) — graded,
not monotonic.

Replacement accounting (band census, hef64b) refutes
the obvious guess: the 55xx–59xx band count is
INVARIANT at exactly the class dose (48 / 80 / 128)
in full, partial, collapsed and zero contexts alike —
it is a fixed component of every context in the
class, not the filler. What actually fills the space:

- Partial contexts: chiefly 31–32k-class actions
  (45 / 64 / 108 occurrences vs 1–2 in full contexts),
  with 3088 appearing (5 / 9 / 14 vs 0).
- Collapsed/zero contexts: a wholesale diverse
  vocabulary — 74xx–77xx band (0 in full → 22–125),
  25xxx sizes (0 → 31–128), 31–32k (→ 34–130, but
  near-absent in two zero contexts, 419 cidx 138 and
  623 cidx 43, a second flavour) — and the distinct-
  size count explodes (full 46–56 distinct sizes →
  collapsed/zero 119–251). The action count is the
  only thing these contexts share with the full
  members: class membership is by count, and a
  collapsed context is different layer content
  wearing that count, exactly as AES-NUM-063 graded
  the classes.

## (iii) 135 vs 134 at position level: one interruption vs a head-and-tail breakdown

Letter sequences (seam frame, triplet members only):

- 135 (49 members): `BABCABCABCABCBCABCABCABCABC…`
  — after the initial BA, a pure A→B→C rotation with
  exactly TWO non-forward transitions in total: the
  opening BA (seq 0) and one CB at seq 12 (a doubled
  32784/26896 pair inside the block, all-positions
  51–52 region). Non-cyclic trigrams: 3 (BAB at 0,
  BCB/CBC at the single interruption). Members sit
  densely at action positions 21–107.
- 134 (50 members): `BBAABCCABABCABABCABC…BCAACCBCAB`
  — interruptions cluster at both ends. Head (seq
  0–13): six non-forward transitions (BB, BA, AA,
  CC, BA, BA) among 65xx/3088 separators. Middle
  (seq 14–41): near-pure, with only the same doubled-
  pair CB interruptions at seq 22 and 39 that 135
  shows once. Tail (seq 42–49): complete breakdown
  (AA, AC, CC, CB) — the last eight members scatter
  sparsely through non-block material (action
  positions 103–129, across 48/80/12048-class
  actions) instead of closing the block.

The two sequences agree in only 12/49 letter
positions (first difference at index 1); the 97/186
action-sequence agreement AES-NUM-063 measured is
the shared skeleton, head and end block — the triplet
blocks themselves are independently written, 135's
near-perfect, 134's degraded at its head and
dissolved at its tail.

## What this closes and what it queues

- MEASURED: the corpus's only genuine two-member
  alternation population is 76c3's B/C (14 contexts,
  two regimes: dense = B-runs + single C separators,
  cross transitions symmetric, self lopsided B-side;
  sparse 776 = near-1:1 alternation, wide gaps).
  Every other two-member subsequence measured is a
  projection of a three-member rotation under
  deletion of one member.
- MEASURED: collapse inside 290/419/623 follows a
  fixed survival order (32784 first, 26896 second,
  7952 last); partials are filled by 31–32k-class
  actions, collapsed/zero contexts by a diverse
  74xx/25xxx vocabulary with 2.5–4.5× the distinct-
  size count; the 55xx band is invariant and fills
  nothing.
- MEASURED: 135's cycle is interrupted exactly once
  in its block (plus its opening transition); 134's
  interruptions are a head cluster, a clean middle
  sharing 135's doubled-pair pattern, and a tail
  dissolution into non-block material.
- NEXT (4.65): the small genuine two-member remnants
  (0856 B/C ×5, cc9 B/C 151/203) vs the 76c3 regimes;
  zero-context replacement vocabularies compared
  across classes (shared pool or per-context?);
  134's sparse tail members vs the end block's own
  bursts. Host/artifact analysis only — no physical
  child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
