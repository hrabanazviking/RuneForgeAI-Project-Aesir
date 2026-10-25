# +3 pair order structure, S76 swap-run converse test, 85→92 segment test (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.76 (AES-NUM-076).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef76.py
(sha256 9bd9bcd0…) + labelled follow-up hef76b.py
(sha256 a45a9164…), both sha-gated gzipped 373 B-part
transfers (assembled gzip and script shas verified
on-device). Controls reproduce AES-NUM-029/032…075
EXACTLY (128,787 pooled small actions; 79,001 pooled
24 B bursts; 745,849 pointer actions; 1,504 contexts;
trailing distinct (channel, operand) pairs 2,049;
champion-headed bursts 75,215). Definitions (seam set
A = 7952, B = 32784, C = 26896; classes = contexts of
one action count; cidx/ngpos = proto order) are as in
AES-NUM-061…075. Matching blocks are difflib
SequenceMatcher blocks over the size sequences
(autojunk off), as in AES-NUM-075's sequence ratios.

## (i) The +3 permutation is blockwise and near its origin — and it does not respect seam segmentation

Same-class +3 pairs (78 of the 134 cc9b9d1c pairs):

- Matching blocks cover 25,106 of 44,710 actions
  (0.5615) in 3,009 blocks (38.6 per pair; median
  block 3, max 757). The matched material is NOT
  scattered singles: 88.4% of it sits in blocks of
  ≥ 4, 75.0% in blocks ≥ 8, 61.2% in blocks ≥ 16.
- Matched elements stay near home: displacement 0
  for 10,264/25,106 (40.9%), median |displacement|
  1, 58.8% within ±2 (top displacements 0, +1, −1,
  −2, +2, −7) — but the tail is long (p90 = 63), so
  a minority of blocks travel far.
- The −1 secondary offset is a weaker animal on
  every one of these measures (57 same-class pairs:
  matched 0.3619, ≥16-block fraction 0.3507,
  displacement median 10 / p90 215, within ±2 only
  42.4%, max block 58). The +3 pairing's order is
  built from long, mostly local blocks; the −1
  tendency's is not.
- The strength is class-dependent: classes 686
  (matched 0.954, displacement median 0, 99.75%
  within ±2), 626 (0.947), 839 (0.957, one block of
  757) and 873 (0.873) are near-copies; 245 (0.543)
  and 842 (0.711) are mid; 738 (0.331, displacement
  median 21) and 606 (0.268) are heavily reordered.
  Positional agreement by region (same-class,
  pooled): head-13 0.6538, body 0.3751, last-55
  1.0000 (the universal end block, as ever).
- Seam segmentation is NOT the unit of the
  permutation: segment counts agree in 103/134
  pairs, but the segment-length SEQUENCE is
  identical in 0/134, the segment-length multiset
  in only 2/134 (overlap mean 0.8751), and seam
  positions themselves coincide at only
  1,980/17,504 zipped positions (11.3%). The
  partner re-cuts its segments even where their
  count survives; the long matching blocks cross
  seam boundaries rather than coinciding with
  segments.

The class deltas (259→256 ×27, 607→606 ×25) are
net differences of larger stereotyped swaps, NOT
deletions of a fixed triple / single action:

- 259→256: every pair drops 12–13 and adds 9–10.
  Dropped in ALL 27 pairs: 80 ×3 plus 32776, 32728,
  23464, 32744, 32416, 16912 (9 actions); added in
  ALL 27: 32608, 25464, 32688, 25240, 31880, 4112
  (6 actions) — a common core of 9-out / 6-in, net
  exactly −3, plus pair-specific churn (union 17
  dropped / 15 added distinct; the full added
  multiset is identical in 22/27 pairs, the dropped
  in only 4/27).
- 607→606: every pair drops EXACTLY 10 and adds
  EXACTLY 9; the full dropped and added multisets
  are each identical in 23/25 pairs. Dropped in
  ALL 25: 32632, 32624, 1448; added in ALL 25:
  32736, 32512 (the remaining stereotyped members
  are absent from one or two outlier pairs only).
- Identity-class controls churn the same way:
  245→245 drops and adds EXACTLY 4 per pair
  (identical multisets 22/27; common core 14352,
  31000, 28672 out / 14584, 30960, 28832 in), and
  738→738 drops/adds 22–40 per pair (identical
  1/27). So a +3 pair ALWAYS performs a swap; the
  −3/−1 classes are simply swaps whose out-leg
  exceeds the in-leg by 3 / 1.

## (ii) The converse holds: inside a swap run, a pair channel NEVER agrees

S76 vs the G10 reference (182 diffs, 49 runs;
AES-NUM-075). For each run, take its span (first to
last diff) and its dominant flip pair; classify
every span position:

- Long runs (span ≥ 4; 16 runs, 131 span
  positions): pair-channel positions 128 — flipped
  128, agreeing 0. Third-channel positions 3 — all
  3 flipped. Flips landing OUTSIDE the dominant
  pair: 7. A pure pair-swap reconstruction of the
  spans matches 121/131 (92.4%); every miss is one
  of those 7 outside-pair flips or 3 third-channel
  flips (concentrated in runs 172–184, 447–451,
  517–527, 551–558, 615–619).
- All runs of span ≥ 2: pair-channel positions
  flipped 162, agreeing 0; third-channel flipped 3
  (165 of the 182 diffs live in runs ≥ 2; 17 are
  isolated).

So the converse test passes exactly: a run is a
span over which the pair exchange is TOTAL — there
is no position inside a run where the reference
carries one of the run's two channels and S76
keeps it. What a run is not, for S76, is a pure
swap: 10/131 long-run positions flip somewhere
else. S82 remains the clean contrast (54 diffs):
its 3 long runs are exact pure 0↔2 swaps (span 22,
pair flipped 22, agreeing 0, reconstruction
22/22), and over runs ≥ 2 its pair positions flip
46, agree 0, with a single third-channel flip.

## (iii) 85→92 is NOT an insertion: it is one rewritten segment, positions 12–35

The two 0a0d378c tail singletons (85 = ng 0 cidx
73; 92 = ng 1 cidx 179), aligned directly:

- difflib alignment: 74 equal, replace 11 (a) →
  18 (b), insert 0, delete 0. There is no pure
  insertion decomposition.
- Localized exactly: a[0:12] == b[0:12]; the ONLY
  disturbed region is a[12:29] → b[12:36] (broken
  by five short equal islands of 2, 1, 1, 2
  actions); a[29:85] == b[36:92] — the remaining
  56 actions are size-identical, shifted by
  exactly +7 (the +7 channel alignment of
  AES-NUM-075 is this suffix shift; suffix-55
  channels are identical).
- Inside the region, a carries a repeated motif —
  12224, then (9144, 184) three times and
  9144, 24, 184, 24 — where b carries a different
  repeated motif — 31840, 328, 24, 11264, then
  (528, 80) three times and a closing run of 80s
  (80, 48, 80, 80, 80, 80, 80). The region expands
  17 → 24 actions = exactly the +7.
- The multiset excess sits in the region: 92 over
  85 = 80 ×9, 528 ×3, 31840, 328, 11264, 48 (+16);
  85 over 92 = 9144 ×4, 184 ×4, 12224 (−9); net
  +7. All nine extra 80s are region actions.
- LCS does not rescue insertion: LCS(sizes)
  75/85, LCS(size, channel) 72/85 — at the level
  of the cross-context controls (85 vs 758
  contexts 74/74; 92 vs 768-ng1 77), because the
  shared material is head + suffix, not a
  subsequence embedding of the whole of 85.

Verdict: the insertion hypothesis is REJECTED as
stated and replaced by a measured one: 92 is 85
with ONE body segment (positions 12–28) rewritten
— a repeated-motif segment swapped for a different
motif and expanded by 7 — while head (12) and
suffix (56) are untouched.

## What this closes and what it queues

- MEASURED: the +3 partner's order is a
  blockwise permutation — 61.2% of matched
  material in blocks ≥ 16, displacement median 1
  (58.8% within ±2), far stronger than the −1
  control on every measure — but block strength
  is class-dependent (686/626/839 near-copies;
  738/606 heavily reordered), and the permutation
  does NOT respect seam segmentation (length
  sequences identical 0/134, seam positions
  11.3% coincident).
- MEASURED: the −3/−1 class deltas are net
  effects of larger stereotyped swaps (259→256:
  common core 9-out / 6-in in all 27 pairs;
  607→606: exactly 10-out / 9-in, identical
  multisets in 23/25 pairs), of the same kind
  identity pairs perform (245: exactly 4-for-4).
  No fixed dropped triple or single exists.
- MEASURED: the S76 converse — inside every run
  span, pair-channel positions flip 128/128
  (long runs) and 162/162 (span ≥ 2) with ZERO
  agreements; the exchange is total over its
  spans. Pure-swap reconstruction is 121/131 for
  S76 (10 outside-pair / third-channel flips)
  and exact 22/22 for S82's long runs.
- MEASURED / REJECTED: 85→92 literal insertion
  (0 insert opcodes; LCS 75/85 sizes, 72/85
  joint). REPLACED by one rewritten segment:
  a[12:29] → b[12:36], motif (9144, 184)-family
  → (528, 80)-family plus an 80-run, +7 exactly,
  head 12 and suffix 56 untouched.
- NEXT (4.77): segment-substitution census —
  other context pairs across 0a0d/cc9 sharing
  head + suffix with one rewritten motif
  segment; the (9144, 184) / (528, 80) motif
  families wherever they occur; S76's 10
  outside-pair span positions vs neighbouring
  runs' pairs (spillover test). Host/artifact
  analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
