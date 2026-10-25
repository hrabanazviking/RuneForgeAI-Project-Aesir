# cc9 +3 pairing at artifact scope, S76 channel transforms, tail singletons (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.75 (AES-NUM-075).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef75.py
(sha256 760da4fd…; a first build died at arm (ii) on a
missing `modal` helper after completing arm (i) — the
fixed build reproduced arm (i) byte-identically before
completing all three arms). Transfer was sha-gated
373 B-part file.write (one part corrupted in
re-emission, caught by its received-count increment
and by the whole-file sha256 gate, and re-sent fresh;
the assembled gzip and script shas verified
on-device). Controls reproduce AES-NUM-029/032…074
EXACTLY (128,787 pooled small actions; 79,001 pooled
24 B bursts; 745,849 pointer actions; 1,504 contexts;
trailing distinct (channel, operand) pairs 2,049;
champion-headed bursts 75,215). Definitions (seam set
A = 7952, B = 32784, C = 26896; classes = contexts of
one action count; cidx/ngpos = proto order) are as in
AES-NUM-061…074.

## (i) The cc9 ngpos+3 pairing is artifact-wide: partners are near-permutations of each other

cc9b9d1c holds 271 contexts — ng 0: 134 (ngpos
0–133), ng 1: 137 (ngpos 0–136) — so every ng-0
context has an ng-1 partner at ngpos +3. Testing all
offsets −6…+6 (partner = the ng-1 context at
ngpos + d):

- Same class: +3 pairs are the same class in 78/134
  cases (58.2%). Every other offset scores ≤ 3.8%
  except −1 (57/133, 42.9% — a weaker secondary
  tendency, see below).
- Size-multiset overlap (multiset intersection over
  the smaller context): +3 = 0.9695. All other
  offsets sit at 0.604–0.637, except −1 at 0.7689.
  Paired contexts carry ~97% the same inventory of
  action sizes.
- But NOT in the same order: pooled positional size
  agreement among same-class +3 pairs is only
  0.3815, per-pair median 0.3633 (range
  0.111–0.992), and the order-sensitive sequence
  ratio is 0.4892 at +3 against 0.2710 (+2) and
  0.2760 (+4). A few pairs are near-identical
  (873-class pairs at 0.967–0.983, one 874 pair at
  0.992, one 839 pair at 0.985); most are genuine
  re-orderings of the shared inventory.
- Rare draws clinch it: 266 size values occur
  exactly twice in the whole artifact (doubletons);
  every one is hosted by exactly two contexts, and
  250 of the 266 have their two hosts standing at
  ngpos +3 of each other. Mean shared rare
  (count ≤ 2) sizes per pair: 1.866 at +3 (69/134
  pairs share at least one) against EXACTLY 0.000
  at offsets +1, +2 and +4. At count ≤ 4 the
  contrast is 3.619 (105/134 pairs) against
  ≤ 0.030.
- The pairing's class map is systematic, not
  incidental: (245→245) ×27, (259→256) ×27,
  (738→738) ×27, (607→606) ×25, (873→873) ×6,
  (839→839) ×3, (842→842) ×3, (686→686) ×3,
  (626→626) ×3, (606→606) ×2, (874→874) ×2, and a
  single exception (259→499) ×1. The ng-1 partner's
  class is the ng-0 class, or that class minus 3
  (259→256), or minus 1 (607→606).

Verdict: AES-NUM-074's stray pairing was the visible
tip of an artifact-wide law. In cc9b9d1c the two
network groups are paired context-by-context at
ngpos +3, and a pair shares essentially one action-
size inventory — including its rarest draws (250/266
doubletons) — while differing in order. The −1
offset's partial signal (42.9% same class, 0.7689
multiset) is recorded as a secondary observation;
it shares no rare-draw test here and is far weaker
on every measure.

## (ii) S76's diff runs are local pair swaps, not a channel relabelling — and S82 is the clean contrast

Against the ng-1 train's G10 reference (cidx 88, 94,
100, 106, 112, 136, 142, 154, 160, 166; 587
size-single positions; G10 vs G4 Hamming 3,
re-verified), S76's 182 channel diffs form 49 runs
(17 isolated, 16 of length ≥ 4). The global flip map
over all diffs is:

- 1→2: 49, 0→1: 47, 1→0: 31, 2→1: 27, 2→0: 25,
  0→2: 3.

That is NOT a function: ref channel 0 maps to both
1 (47) and 2 (3); ref 1 to both 0 (31) and 2 (49);
ref 2 to both 1 (27) and 0 (25). No global channel
permutation or relabelling produces S76.
Adjacent-channel flips (±1) dominate: 154/182
(84.6%); distance-2 flips are 28/182, and 0→2 is
nearly absent (3).

Per long run, the transform is a LOCAL pair
exchange — both directions of one channel pair
inside the same run:

- 95–108 (14): 0→1 ×8 + 1→0 ×6 — a 0↔1 swap run.
- 146–167 (22): 1→2 ×12 + 2→1 ×10 — a 1↔2 swap run.
- 223–236 (14): 2→1 ×8 + 1→2 ×6; 585–592 (8):
  1→2 ×5 + 2→1 ×3; 172–184 (13): 0→1 ×6 + 1→0 ×5
  plus two strays; 551–558, 189–192, 197–200,
  238–241, 75–78, 670–673: the same mixed
  two-direction shape at smaller scale.
- The exceptions are near-one-way 2→0 runs:
  517–527 (11): 2→0 ×10 + 1→2 ×1; 116–122 (7):
  2→0 ×6 + 0→2 ×1; and one pure run, 327–330:
  1→2 ×4.

So inside a run the two channels of a pair trade
places position-by-position (a swap of interleaved
streams), rather than one channel being renamed.
Isolated single diffs show the same adjacent-flip
mix (0→1 ×7, 1→0 ×4, 1→2 ×2, 2→1 ×2, 2→0 ×2).
Size exceptions (180 on G10-single positions)
split three ways: 86 inside diff runs, 8 at
isolated diffs, and 86 at channel-identical
positions — channel divergence and size divergence
coincide only half the time.

S82 is the clean contrast: its 54 diffs are 94.4%
one pair — 0→2 ×26 and 2→0 ×25, with only three
other flips (1→0 ×2, 2→1 ×1) — and its per-ref
targets are near-functional (0→{2}, 2→{0,1},
1→{0}). S82 IS (almost) a pure 0↔2 channel swap;
S76 is not any single swap.

## (iii) Tail singletons: bodies are strangers, ends are one — and 85/92 differ by a 7-action body

758 / 760 / 768 (one context per group; ng-0 cidx
64–72, ng-1 cidx 170–178):

- Cross-group size matches 318/758, 237/760,
  252/768; channel matches 281/758, 394/760,
  245/768 — the AES-NUM-074 mismatch, now localized:
  the last 55 actions are FULLY identical between
  the groups in BOTH size and channel for all three
  classes (55/55 and 55/55; the final per-64 block
  scores 54/54, 56/56, 57/64 sizes). Agreement lives
  at the ends: head-13 sizes match 9, 6, 9 of 13;
  the eleven body blocks score only 11–42 of 64.
- No shift repairs it: best size shifts score
  0.420 (758, at shift 0 itself), 0.364 (760, at
  −1) and 0.355 (768, at +1) against 0.31–0.42 at
  shift 0 — the bodies are not offset copies.
- The class pairing itself adds little: in the
  six-context cross-matrix, own-class cross-group
  matches (318, 237, 252) barely exceed cross-class
  matches (213–240; e.g. 768-ng1 vs 758-ng0 = 240
  against 768-ng1 vs 768-ng0 = 252). Singleton
  bodies relate to each other only through the
  shared ends.

The tail's end singletons, 85 (ng 0, cidx 73) and
92 (ng 1, cidx 179), are a different animal — a
matched pair modulo a small body difference:

- Size multiset overlap 76/85; head-13 sizes are
  identical at 12/13 positions (only position 12
  differs: 12224 vs 31840); end-aligned suffixes
  match completely at 13, 28 and 55 in both sizes
  and channels (the suffix-55 is the universal end
  block both contexts carry — both also score
  55/55 against every n = 16 template's last 55,
  and 10–12/13 against their head scaffolds).
- The length difference is exactly 7, and the
  channel streams betray it: shifting 92's channels
  by +7 aligns 65/85 of 85's channels, against
  63/84 at −1 and no comparable score elsewhere —
  consistent with 92 carrying ~7 extra actions in
  its body while the channel weave continues.
  Whether 92 is literally 85 plus 7 insertions is
  NOT PROVEN by these tests (no clean size
  alignment at +7 was measured).

## What this closes and what it queues

- MEASURED: cc9b9d1c's network groups are paired
  at ngpos +3 artifact-wide — 134/134 ng-0 contexts
  paired; size-multiset overlap 0.9695 against
  0.60–0.64 at all other offsets (except −1,
  0.7689); 250/266 doubleton sizes hosted by +3
  pairs against zero rare sharing at +1/+2/+4;
  class map systematic (identity, −3 or −1, one
  exception); partners are near-permutations
  (positional agreement median 0.36), not copies.
- MEASURED: S76's channel divergence is not a
  relabelling (flip map non-functional for every
  ref channel); runs are local two-direction pair
  swaps (0↔1 or 1↔2; 84.6% adjacent flips) with
  two near-one-way 2→0 exceptions (517–527,
  116–122); size exceptions coincide with channel
  diff runs only 86/180 times. S82, by contrast,
  is a near-pure 0↔2 swap (51/54 flips).
- MEASURED: the 758/760/768 cross-group mismatch
  is body-only — last 55 identical in size AND
  channel (55/55 ×3), heads partially shared,
  bodies unrelated and not shift-related; class
  pairing adds almost nothing over cross-class
  background. The 85/92 end singletons share head
  (12/13) and end block, hold 76/85 multiset
  overlap, and differ by exactly 7 actions with a
  +7 channel alignment of 65/85 — insertion
  hypothesis recorded, NOT PROVEN.
- NEXT (4.76): the +3 pair's order structure —
  how the ng-1 partner's sequence is a permutation
  of the ng-0 original (block/seam-level), and
  what the −3/−1 class deltas (259→256, 607→606)
  drop; S76 run anatomy — is a swap run exactly
  the ref sequence with one channel pair exchanged
  throughout the run (identity at non-diff
  positions by construction; test the converse:
  positions inside a run where the pair agrees);
  85→92 insertion alignment test. Host/artifact
  analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
