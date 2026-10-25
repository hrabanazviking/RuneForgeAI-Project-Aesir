# Distinguished segment, ff drift staircase, sibling ff-words (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.86 (AES-NUM-086).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef86.py
(sha256 23133e58...), sha-verified on-device after a
one-shot proxy-receiver transfer (the gz bytes never
passed through tool re-emission; the receiver returned
the gz sha256 bccf5420... and it matched). Output file
/tmp/hef86_out.txt sha256 e5e21bdd.... A labelled
follow-up, hef86b.py (sha256 2792fcc2..., gz sha256
c7a9556b..., output sha256 974dd55b...), crossed the
same way and supplied the distinguished-segment,
ladder-fit and staircase arms. Controls reproduce
AES-NUM-029/032...085 EXACTLY (128,787 pooled small
actions; 79,001 pooled 24 B bursts; 745,849 pointer
actions; 1,504 contexts; trailing distinct (channel,
operand) pairs 2,049; champion-headed bursts 75,215).
Definitions (camps, classes, cidx / ngpos) are as in
AES-NUM-061...085. The sibling population is the
AES-NUM-084 home: 76c3a8ff, position 20, size 14,528,
channel 0, ng 1 400-action contexts, cidx 113-338
step 9 (26 segments). The position-18 population is
unchanged: 76c3a8ff len-89 B-main segments at
position 18, cidx %9 == 4, cidx != 112 — 13 contexts
in camp 21392, 12 in camp 21648; tail = segment bytes
6,408-end. Contract: docs/TASK_CONTRACT_4.86.md
(published @ 261e0b70 before implementation).

## (i) The 544 two-valued positions are ONE distinguished segment, not a choice structure

AES-NUM-085 left 544 of the sibling segments' 600
variable positions taking exactly two values, and
asked whether they form columns/blocks like the
position-18 binary tier (two per-context bits over
36 slots each). Grouping the 544 positions by their
choice-vector across the 26 segments gives a far
stronger answer:

- There are exactly TWO distinct exact columns for
  all 544 positions: one block of 322 positions with
  popcount 1, one block of 222 positions with
  popcount 25. Up to complement there is ONE column:
  both blocks describe the same partition of the
  population, {1 segment} against {25 segments}.
- The distinguished segment is cidx 113 — index 0,
  the FIRST segment of the train. It deviates from
  the majority at 544 of 544 two-valued positions;
  every other segment deviates at 0. The other 25
  segments are UNANIMOUS at all 544 positions.
- Segment-pair agreement over the 544 positions is
  bimodal with nothing between: the 25 pairs that
  involve cidx 113 agree at 0 positions, the 300
  pairs among the other 25 agree at all 544.
- The distinguished byte is HIGHER than the consensus
  at 322 positions and LOWER at 222 (never equal).
  The 544 positions carry 72 distinct value pairs
  (top: (0,1) x66, (0,128) x65, (0,12) x30, (0,3)
  x30, (0,4) x29, (161,162) x27, (0,2) x26,
  (0,32) x24, (162,163) x22, (4,12) x21, (0,64) x20,
  (176,179) x19); their offsets fall on all four
  word-byte lanes (mod 4 = 213/70/136/125). Grouping
  by (column + value pair) gives 93 groups — the
  pair varies freely inside the single column.
- The remaining 56 variable positions are a
  different species: among the other 25 segments
  alone they still take 2-25 distinct values
  (histogram 2x9, 3x2, 4x7, 14x4, 18x9, 21x1, 23x14,
  24x2, 25x8 — the rich per-context positions of
  AES-NUM-085), and cidx 113's byte there never
  equals the other-25 modal value (0/56) and is one
  of the other-25 values at only 21/56.

Verdict: the two-valued variability is not per-slot
choice and not a Q/P-style block system. It is the
fingerprint of a single segment: at exactly these
544 positions, cidx 113 carries a private byte while
the other 25 segments share one consensus byte. The
26 segments thus consist of a 25-segment consensus
template plus one distinguished first segment at the
binary positions, with genuinely per-context
variation confined to the 56 richer positions. Why
the first segment is distinguished, and what the
bytes MEAN, is NOT PROVEN.

## (ii) The 39 constant ff offsets drift on ONE staircase; scalars follow rank, not offset

AES-NUM-085 froze 39 constant-scalar ff offsets per
position-18 camp and noted most sit at camp-drifted
offsets. Rank-wise comparison (camp 21392 offsets in
order against camp 21648 offsets in order) resolves
the drift completely:

- The scalar sequence is IDENTICAL in both camps:
  rank-wise scalar match 39/39, and both camps carry
  the same vocabulary counts {15 x27, 35 x4, 2 x4,
  71 x2, 11 x2}. Scalar identity follows RANK (order
  in the segment), never the absolute offset: only
  2 absolute offsets coincide across camps at all
  (8224 -> 35 and 15700 -> 15, both scalar-equal,
  the second at different ranks — a numeric
  coincidence of the drift).
- The rank-wise offset delta (21648 minus 21392) is
  a MONOTONIC STAIRCASE: 0 x1, +64 x5, +128 x13,
  +192 x4, +256 x16 for the constant 39. Over all
  43 ff words (constants plus the 4 variable slots)
  the same staircase holds: 0 x2, +64 x6, +128 x14,
  +192 x4, +256 x17, monotonic nondecreasing, with
  step-ups at camp-21392 offsets 9044 (-> +64),
  11292 (-> +128), 15508 (-> +192) and 17204
  (-> +256). Delta is therefore a function of the
  offset REGION alone: [.., 9044) -> 0;
  [9044, 11292) -> +64; [11292, 15508) -> +128;
  [15508, 17204) -> +192; [17204, ..) -> +256.
- The four variable ff slots obey the same staircase
  by region (their deltas are 0, +64, +128, +256 at
  offsets 8568, 10800, 13064, 21232 — no variable
  slot sits in the +192 region). The end-distance
  view is the mirror image (delta histogram 0 x16,
  +64 x4, +128 x13, +192 x5, +256 x1): the head of
  the frame is start-anchored, the tail end-anchored,
  and the +256 length difference between the camps
  is absorbed in four +64 steps at fixed thresholds.

Verdict: the ff frame is ONE ordered fixture carried
identically (same scalars, same order) by both
camps; the longer camp's copy is the same fixture
stretched by a four-step staircase at offsets 9044 /
11292 / 15508 / 17204. What sits at those thresholds,
and what the frame MEANS, is NOT PROVEN.

## (iii) The sibling segments' 18 ff-words: 15 constant + one repeated rank-ladder scalar

The sibling segments carry exactly 18 aligned
ff ?? 00 00 words each (AES-NUM-085 census), and
their anatomy is now exact:

- The offset set is a SINGLE fixed set of 18 offsets
  shared by all 26 segments (union 18, every offset
  present in 26/26, zero partial offsets, exactly 1
  distinct offset-set): 6960, 7360, 9868, 9876,
  10060, 10252, 11004, 11208, 11776, 12332, 12524,
  12716, 12720, 12908, 13660, 13864, 14088, 14384.
- Fifteen offsets carry a CONSTANT scalar: 15 at
  eleven offsets (9868, 10060, 10252, 11004, 11208,
  12332, 12524, 12716, 12908, 13660, 13864), 5 at
  two (6960, 9876) and 104 at two (12720, 14088).
- The other three offsets — 7360, 11776, 14384 —
  carry ONE repeated per-segment scalar, the same
  value at all three offsets in every segment, and
  that scalar is a pure RANK LADDER: in cidx order
  it runs 21, 30, 39, ..., 246 — exactly 21 + 9 x
  rank over ranks 0-25 (all 25 diffs are +9; the
  formula fits 26/26). The distinguished segment
  cidx 113 holds the ladder's first rung (21).
- Instance-weighted vocabulary: 15 x286, 5 x52,
  104 x52, and each ladder value 21-246 step 9 x3.
  Overlap with the position-18 ff vocabulary
  {2, 11, 15, 35, 71} is exactly {15}; the
  sibling-only values are 5, 104 and the ladder.
  Distinct scalar-tuples across segments: 26,
  driven entirely by the ladder.

Verdict: the sibling ff fixture mirrors the
position-18 construction — a fixed offset set, a
bed of constant scalars dominated by 15, and a small
set of variable slots repeating one per-context
scalar — but here the variable scalar is not free:
it is the segment's rank in the train, encoded as
21 + 9 x rank. What the ladder or the fixture MEANS
is NOT PROVEN.

## What this closes and what it queues

- MEASURED: the sibling 544 two-valued positions are
  a single partition — cidx 113 (first segment)
  deviates at all 544; the other 25 are unanimous
  there. No per-slot or block choice structure.
- MEASURED: the position-18 ff frame's cross-camp
  drift is one monotonic +64 staircase with
  thresholds at 9044 / 11292 / 15508 / 17204; scalars
  are rank-locked and identical across camps (39/39).
- MEASURED: the sibling segments' 18 ff-words sit at
  one fixed offset set — 15 constant-scalar offsets
  {15 x11, 5 x2, 104 x2} plus 3 variable slots
  repeating the rank-ladder scalar 21 + 9 x rank.
- NEXT (4.87): is cidx 113 distinguished beyond the
  sibling segments (its whole context vs the other
  25 contexts; other segment classes in its context;
  first-in-train privilege elsewhere)?; what sits at
  the staircase thresholds 9044 / 11292 / 15508 /
  17204 inside the position-18 segments (content
  landmarks, action boundaries)?; the position-18
  camps' own ff scalar sequences against a rank
  ladder (step +9 was "mostly" there in AES-NUM-084
  — exact form per camp?). Host/artifact analysis
  only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
