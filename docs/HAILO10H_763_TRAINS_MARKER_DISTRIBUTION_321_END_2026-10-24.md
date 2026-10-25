# 763 trains, marker distribution, 321 end region (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.73 (AES-NUM-073).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef73.py
(sha256 77db0504…) + labelled follow-up hef73b.py
(sha256 655ecbf6…), both delivered by sha-verified
proxy upload (the gzipped chunk transfer's first part
was rejected by the device's base64 validation and the
route was changed, never retried blindly). Controls
reproduce AES-NUM-029/032…072 EXACTLY (128,787 pooled
small actions; 79,001 pooled 24 B bursts; 745,849
pointer actions; 1,504 contexts; trailing distinct
(channel, operand) pairs 2,049; champion-headed bursts
75,215). Definitions (seam set A = 7952, B = 32784,
C = 26896; classes = contexts of one action count;
marker = the action at p−1 before an A entry; CA2 =
C-predecessor gap-2 markers) are as in AES-NUM-061…072.

## (i) The 763 class is two proto-order trains; its subgroups are one size family per train, split by a handful of channel positions

AES-NUM-072 split 0a0d378c's 763 class (32 contexts)
into 9 exact channel-sequence groups (12 / 10 / 4 +
six singletons). The full anatomy:

The class is exactly two arithmetic trains in proto
order (cidx is proto order: contexts enumerate
lexicographically by (network group, position in
group), verified):

- ng 0 (74 contexts): the sixteen 763 contexts are
  cidx 1, 5, 9, …, 61 — exactly 1 + 4k for k = 0…15.
- ng 1 (106 contexts): the sixteen are cidx 76, 82,
  88, …, 166 — exactly 76 + 6k for k = 0…15.

Subgroup size templates vs each other:

- G10 (ng 1, 10 contexts) and G4 (ng 1, 4 contexts)
  are ONE size family: modal size templates agree at
  595/763 positions; at the 586 positions where both
  are single-valued they NEVER disagree (eq 586,
  diff 0); their varying-position sets are the same
  set (172 shared of 177 union, Jaccard 0.972). Their
  channel sequences differ at exactly THREE positions
  (327: 1/2, 368: 0/1, 518: 2/0). Together they fill
  all fourteen ng-1 train slots from 88 to 166.
- G12 (ng 0, 12 contexts) shares nothing with them:
  modal agreement 184–190/763, channel Hamming
  464–467, varying sets almost disjoint (Jaccard
  0.160–0.174).

The singletons are train members, most of them near-
members of their train's family:

- S13 (ng-0 slot 13, one of G12's two step-8 gaps) is
  a G12 member with ONE channel flip (position 621:
  1 vs 2): its size matches G12's template at all
  588 G12-single positions, no exception.
- S37 (ng-0 slot 37, the other gap) is a G12 member
  with three channel flips (430, 493, 509) and one
  size exception on a G12-single position (636:
  16144 vs the template's 16400); it matches the
  other 587/588 single positions. With S13 and S37
  restored, G12's family fills all fourteen ng-0
  slots from 9 to 61.
- S82 (ng-1 slot 82) stands 54 channel positions from
  G10/G4 (a block of 2-vs-0 flips around positions
  88–120 leads), matching 583/587 of G10's single
  sizes — a near member of the ng-1 family.
- S76 (ng-1 slot 76, the train head) is 179–182
  channel positions away, matching 407/590 of G4's
  single sizes — a distant early member.
- S1 and S5 (ng-0 slots 1 and 5, the train head) are
  distant from everything (nearest Hamming 228, S5 to
  G12, with 331/763 modal size agreement; S1's
  nearest is 348) and from each other (360).

So the periodicity is not a cidx coincidence: each
network group carries its own 763 train at a fixed
stride (4 in ng 0, 6 in ng 1), the train's contexts
share one size template (~588/763 single positions,
modal coverage 0.83–0.87), and the exact-channel
subgroups of AES-NUM-072 are that template's family
split by 1–3 channel flips (inside a train) — the
two trains' families are unrelated to each other.

## (ii) The marker rung mirrors the marker-bearing contexts' own 5–7k data distribution

AES-NUM-072 left the CA2 marker rung structurally
unselected. Distributionally, against the contexts'
own 5,000–6,999 data actions (all band sizes are
step-8 in both rotation artifacts, share 1.0000):

- Artifact-wide (all contexts, markers excluded):
  0a0d378c Pearson 0.394 / TV 0.296 over the 41
  rungs; cc9b9d1c Pearson 0.868 / TV 0.213 over the
  58. The 0a0d band vocabulary is a step-8 ladder
  5,448…6,024 (plus a sparse tail to 6,672; 95
  distinct); the marker ladder 5,536…5,856 is a
  contiguous middle slice of it, and the band's top
  sizes (5,496 ×630, 5,488, 5,504) sit BELOW the
  ladder — the artifact-wide population is dominated
  by contexts that never bear CA2 markers.
- Restricted to the marker-bearing contexts
  themselves (the honest comparison): 0a0d378c has
  only 30 such contexts (988 non-marker band
  actions) and the rung distribution matches theirs
  at Pearson 0.968, TV 0.091. cc9b9d1c (171 marker
  contexts, 2,971 non-marker band actions) matches
  at Pearson 0.868, TV 0.213 — its band vocabulary
  is essentially the ladder alone (6,112…6,568
  contiguous, plus five stray sizes at ×2 each:
  5480, 5616, 5808, 5904, 6880).

Verdict: the marker rung is a draw from the same
size population as the 5–7k data actions of the
contexts that bear it — distributionally a genuine
data size (strengthening AES-NUM-072's reading),
while WHICH rung a given entry takes remains NOT
PROVEN as a function of any structural feature.

## (iii) The 321 class's end region is the universal 55 plus a two-action class fixture

0a0d378c's 321 class (16 contexts, themselves a
step-4 proto train at cidx 0, 4, …, 60):

- Its last 55 actions are the artifact-universal end
  block, byte-identical in all 16 contexts (size and
  channel), as in every context of the artifact.
- The extension is exactly two actions: at −56 the
  pair (size 24, channel 1) holds in 16/16 contexts;
  at −57 channel 1 holds in 16/16 and size 25872 in
  15/16 (cidx 0 carries 32784 instead). Channel
  therefore stays single through −57 and size
  through −56, which is exactly why the class holds
  41 single-channel 17-windows (57 − 17 + 1) against
  the universal 39: the window at start 264 spans
  −57…−41. At −58 the class already splits (2 sizes,
  2 channels), so the region ends at 57.
- Artifact-wide there is no 56th universal action:
  at −56 the artifact carries 24 distinct sizes /
  3 distinct channels, at −57 32 sizes / 9 channels.
- The fixture pair is a class-level, not artifact,
  fixture: every n ≥ 8 class has its own modal
  −57/−56 pair (123: (32784, 24) in 16/16; 617:
  (25872, 24) in 16/16 — the same pair as 321;
  623: (26896, 32784); 280: 3 distinct pairs;
  290/419: 8 each), and several classes hold a
  single channel at −57/−56 (123, 290, 617, 623)
  without gaining end windows, because their size
  or channel splits at the other offset. Among the
  classes whose only single windows are the end
  block's (280, 763: extension 0), 321 alone extends
  — by these two actions.
- Beyond the fixture, the class tail stays near-
  frozen: distinct last-k size AND channel sequences
  within 321 number exactly 2 for every k from 57
  to 65 — but only the 55 are artifact-universal.

## What this closes and what it queues

- MEASURED: the 763 class is two proto-order trains
  (ng 0: 1 + 4k, ng 1: 76 + 6k, 16 slots each); one
  size family per train (G10 ≡ G4 wherever both are
  single, split by 3 channel positions; G12 restored
  to 14 slots by S13/S37 at 1 and 3 channel flips);
  the two trains' families are unrelated (Hamming
  ~465, modal agreement ~190/763).
- MEASURED: the CA2 marker-rung distribution mirrors
  the 5–7k band distribution of the marker-bearing
  contexts themselves (0a0d378c Pearson 0.968 / TV
  0.091 over 30 contexts; cc9b9d1c 0.868 / 0.213
  over 171); rung selection by structural features
  remains NOT PROVEN (AES-NUM-072 stands).
- MEASURED: the 321 class's 57-action end region =
  the universal 55 + a two-action class fixture
  ((25872, ch1) 15/16 then (24, ch1) 16/16); no
  56th universal action exists artifact-wide
  (24 sizes / 3 channels at −56).
- NEXT (4.74): the other classes' proto trains —
  stride/family census across all 0a0d classes
  (321 at step 4, 763's two trains; do all classes
  decompose into per-ng trains, and are train
  families related across classes?); S76/S82's
  early-train divergence structure in the ng-1
  train; the cc9 band strays (5480…6880 ×2 each)
  and their contexts. Host/artifact analysis only —
  no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
