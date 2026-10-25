# The 21 mismatches sit in the middle's tail and are rank-identical, the sparse ff scan completes the census with 26 non-step OTHER offsets and no new step, and distinguished firsts differ from other outliers in kind, not just degree (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.92 (AES-NUM-092).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef92.py
(sha256 d67eef3b77cbd4c49cb799555e02d8c20bb61c4c6b1914af196d305a6a39e64f...),
landed via one-shot proxy-receiver transfer (gz sha256
2b67a6c56e6e6ea489c93610d50a05e948dee0f45e9b3db0678986f3ecab98f4...
returned by the receiver, matching; script sha verified
on-device). Output file /tmp/hef92_out.txt sha256
fa7d88c8fe51dd9f87070f8852c8f5a11a13ee13bc90c44a7f604650497d97f0....
Controls reproduce AES-NUM-029/032...091 EXACTLY
(128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts;
trailing distinct (channel, operand) pairs 2,049;
champion-headed bursts 75,215). Definitions (camps,
regions, ff scan, trains, D metric) are as in
AES-NUM-086...091. Contract:
docs/TASK_CONTRACT_4.92.md (published @ 5fac6557,
amended @ d0abc122, both before implementation).

## (i) Middle mismatches: one list for all four ranks and both best offsets, empty for the first 90 bytes, crowded into the tail; no exact period anywhere

The four grown regions' middles are not byte-identical
across ranks — but their mismatch anatomy is. At both
best insertion offsets (k = 111 and k = 112) and at
every grown rank (2 / 8 / 22 / 26), the mismatch list
against camp 21392's consensus middle is the SAME 21
A-middle positions with the SAME byte pairs (only the
region offsets shift, by region):

0, 91, 94, 103, 111, 116, 119, 125, 126, 130, 131,
132, 133, 135, 142, 143, 148, 151, 160, 163, 167.

Structure of the list:

- position 0 is isolated (the next mismatch is 91
  bytes later); positions 1–90 match exactly;
- the remaining 20 mismatches live in positions
  91–167, i.e. the tail 77 bytes: thirds are
  1 / 4 / 16, the longest run is 4 (positions
  130–133), and gaps inside the tail are 1–9;
- in 11 of the 21 positions camp B's aligned byte
  is 0x00 (pooled over the 4 ranks: byte pairs
  (0x80, 0x00) x12, (0x20, 0x00) x8, (0x10, 0x00)
  x8, and 14 further pairs x4 each — every pair
  occurs exactly once per rank); pooled XOR values
  are dominated by 0x80 (16 of 84), 0x20 and 0x10
  (12 each) — powers of two, but no single pair or
  XOR value dominates.

Shift tolerance / period, measured on rank 2 (the
profiles are rank-identical):

- the 64 B chunk at k = 111 and at k = 112 both
  occur in all four grown regions (AES-NUM-091);
  their self-overlap is strongest at shift 16
  (30/48 bytes at k = 111; 31/48 at k = 112) and
  trivially exact only at shifts 58–63, where the
  compared overlap is 1–6 bytes (border lengths
  1–6, the same tail effect) — no non-trivial
  exact period;
- autocorrelation of the full middles peaks at
  multiples of 16 in BOTH camps (A middle: d = 48
  at 0.700, d = 16 at 0.678, d = 32 at 0.632,
  d = 64 at 0.606; B middle: d = 80 at 0.750,
  d = 32 at 0.715, d = 16 at 0.685, d = 48 at
  0.669) and is exact at NO shift;
- the insertion profile around the minimum is a
  shallow bowl (k = 96: 27 mismatches, falling to
  21 at k = 111/112, 22–23 across k = 113–127) —
  the minimum is real but not sharp.

Verdict: MEASURED — the 21 mismatches are a single
rank-invariant tail phenomenon: the middles agree
for 90 bytes after position 0 and disagree in a
scattered, zero-heavy pattern over the last 77.
A 16-byte rhythm is visible in every autocorrelation
peak, but at fractions 0.63–0.75 it is NOT an exact
period, and what the mismatches or the rhythm MEAN
is NOT PROVEN.

## (ii) Sparse ff scan: the census is complete for every group with >= 2 instances and >= 1 common offset — 31,568 further offsets, CONST/NGIDX except 26 non-step OTHERs, and no step anywhere

The new scanner first re-derived every earlier
result exactly (the byte-find candidate generation
is thereby validated against the step-4 loop):
in-band 374 groups, CONST 17,351 / NGIDX 3,290 /
OTHER 4, all 4 STEP (the 0a0d378c exception group);
band X 60 groups / 3,335 offsets, OTHER 0; band Y
27 groups / 354 offsets, OTHER 0.

The corpus holds 141,456 (artifact, position, size)
groups in all; 86,461 are singletons (classification
undefined — every value is trivially constant;
2,339 of them carry >= 1 ff-pattern offset). The
sparse remainder below all earlier floors:

- S1 (2–7 instances, any position/size, >= 1
  common offset): 719 groups, 30,336 offsets —
  CONST 25,681, NGIDX 4,639, OTHER 16, STEP 0.
  32,617 further S1-range groups have 0 common
  offsets.
- S2a (8+ instances, X/Y territory, 1–2 common):
  0 groups exist — every X/Y-territory group with
  >= 8 instances has 0 or >= 3 common offsets.
- S2b (original band, 1–9 common): 15 groups,
  32 offsets — CONST 21, NGIDX 1, OTHER 10,
  STEP 0.
- S2c (8–600 instances, territory no earlier scan
  reached, >= 1 common): 128 groups, 1,200
  offsets — CONST 1,175, NGIDX 25, OTHER 0.
- S2d (> 600 instances, >= 1 common): 0 groups.
  21,055 groups with >= 8 instances have 0 common
  offsets.

The 26 OTHER offsets (16 in S1, 10 in S2b, all
non-step, every one printed in full in the run
output) share visible traits: all sit in segments
of size 32,560–32,784 B at positions 8–25; most
have only 2 distinct values in tiny groups (n =
2–7); and several S2b groups at position 21 /
size 32,776 in the sister artifacts 5ab3537d and
773470cd carry the SAME offsets (11136, 17272,
20300, 32192) with the SAME value patterns — nine
instances stepping 1, 4, 7, … by 3 (or carrying
5 / 15 at two-valued offsets) and one instance
differing. That stepping pattern is neither CONST
nor the within-ng index; whether it is a within-
train (or other subgroup) index is the next test,
NOT PROVEN here.

Verdict: MEASURED — with this slice, every group
of >= 2 instances with >= 1 common aligned ff
offset in the corpus has been classified: the
vocabulary is CONST and the within-ng index,
plus exactly 30 OTHER offsets in the whole corpus
(the 4 known step offsets of AES-NUM-090, which do
NOT recur in the sparse remainder, and these 26
non-step offsets). No step form exists below the
floors. What the 26 encode is NOT PROVEN.

## (iii) D-position anatomy: distinguished firsts carry ~18x the D-positions of other outliers, spread through the list with a last-decile collapse, and mostly change size and channel together; other outliers are few, head-concentrated, single-aspect

All 52 trains recomputed; controls reproduce
AES-NUM-090/091 EXACTLY (unique-first 28, unanimous
13, outlier-elsewhere 11; sibling D(cidx 113) =
249).

Distinguished firsts (28 members, 3,089
D-positions in total — the full per-first position
lists are in the run output):

- by third: 1,381 / 1,000 / 708 (44.7 % / 32.4 %
  / 22.9 %) — head-loaded but spread through the
  whole list;
- by decile: 283, 456, 502, 356, 284, 312, 291,
  339, 235, and just 31 in decile 9 — the final
  tenth of the action list almost never
  distinguishes a first;
- change kind: channel-only 582 (18.8 %), size-
  only 1,046 (33.9 %), both changed 1,461
  (47.3 %); 178 distinct consensus pairs are
  replaced by 388 distinct own pairs; the top
  transitions are channel rotations among the
  32,784 B actions ((32784,1)->(32784,0) x53,
  (32784,0)->(32784,1) x36, (32784,1)->(32784,2)
  x35, (32784,0)->(32784,2) x34) and size swaps
  among the same-channel bulk actions
  ((25872,1)->(7952,0) x31, (25872,2)->(7952,2)
  x28, (7952,2)->(25872,2) x27).

Control arm (29 non-first members with >= 1
D-position, 176 D-positions total):

- by third 80 / 67 / 29; by decile the mass sits
  in decile 0 (56 of 176, 31.8 %, vs 9.2 % for
  firsts);
- change kind inverted: channel-only 69 (39.2 %),
  size-only 79 (44.9 %), both changed just 28
  (15.9 %).

Verdict: MEASURED — the two populations differ in
kind, not only in count: a distinguished first is
distinguished across the whole action list (saving
only the final decile) and usually by carrying a
wholly different action (size and channel both),
while a non-first outlier differs at a handful of
early positions, usually in one aspect only. No
statistic tested separates the populations
exactly (their thirds and change-kind distributions
overlap), so WHY first contexts are built this way
remains NOT PROVEN; the next arm tests whether a
first's own pair is a deterministic function of
the consensus pair and position.

## Next (slice 4.93)

- ff OTHER form hunt: classify the 26 sparse
  OTHER offsets against within-train / subgroup
  index forms (incl. the step-3 patterns shared
  by the sister artifacts), completing the ff
  vocabulary or grading the forms NOT PROVEN.
- Middle 16-byte unit anatomy: re-cut both
  middles in 16 B units (the autocorrelation
  rhythm), unit-level A/B comparison and the
  tail mismatches per unit.
- Firsts' size-transition structure: is a
  distinguished first's (size, channel) at a
  D-position determined by the consensus pair
  (+ position / train step)? A function test in
  the style of AES-NUM-022.
Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts within the stated bands and floors; blob
identities are sha prefixes only. Every count,
occurrence, alignment and distribution above is
MEASURED as stated; every meaning — what the
middle rhythm is, what the 26 OTHER offsets
encode, why first contexts differ in kind — is
NOT PROVEN and nothing here invents one.
