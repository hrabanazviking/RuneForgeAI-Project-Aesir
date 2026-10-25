# 290 ordinal train, 623 extra vocabulary, singleton follower test (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.67 (AES-NUM-067).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef67.py
(sha256 729546fd…). Controls reproduce AES-NUM-029/032…066
EXACTLY (128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts; trailing
distinct (channel, operand) pairs 2,049; champion-headed
bursts 75,215). Transfer: gzipped script in 373 B parts,
each part received-byte-counted on-device via the
file-write session, whole-file sha256 verified on-device
before the run (one single-shot crossing was rejected
before the chunked session and nothing from it was used).
Definitions (seam set A = 7952, B = 32784, C = 26896;
collapsed/zero states) are as in AES-NUM-061…066.

## (i) The 290 class completes the ordinal train — cleanly against 623, at lower dose against 419

Each of the three 0a0d classes holds exactly six
collapsed/zero contexts, and their STATE SEQUENCES are
IDENTICAL in all three classes, in cidx order:
[collapsed-A, zero, collapsed-A, collapsed-A, zero,
zero] — 290 cidx 115/121/127/133/139/169; 419 cidx
114/120/126/132/138/168; 623 cidx 27/31/35/39/43/63.
The k-th context of every class is in the same state.

Ordinal-matched Jaccard (vocabulary sets), k = 1…6:

- 290↔623: J = 0.589 / 0.607 / 0.613 / 0.641 / 0.601 /
  0.564 (mean 0.603, min 0.564). The mismatched control
  (all 30 cross pairs at k≠k) reaches at most 0.456
  (mean 0.199). Clean separation: every matched pair
  beats every mismatched pair. The train HOLDS.
- 290↔419: J = 0.453 / 0.431 / 0.442 / 0.505 / 0.456 /
  0.413 (mean 0.450). Mismatched control max 0.431,
  mean 0.197; five of six matched pairs beat the
  control max, and k=6 (0.413) sits just below one
  mismatched pair (290 cidx 127 vs 419 cidx 132,
  0.431) — separation is real but dose-limited, exactly
  the "same train at lower dose" shape AES-NUM-066
  queued. (Replication: 419↔623 matched J reproduced
  at 0.768 / 0.724 / 0.721 / 0.755 / 0.766 / 0.774.)

The vocabularies are near-NESTED along the train: in
every 290↔623 matched pair the 290 side lacks EXACTLY
8 sizes against its 623 twin, while the 623 side lacks
57–105 against the 290 context; shared sizes cover
0.966 of the 290 context's actions in all six pairs
(0.782–0.846 of the 623 side). Against 419 the 290
side lacks 32–47 sizes (coverage 0.807–0.862).
First-occurrence stream positions still do not carry
the kinship (agreement 1–3 shared sizes per pair).

Verdict: ordinal matching is a three-class law. The
k-th collapsed/zero context is a vocabulary relative
of the k-th in each neighbouring class, with the 290
vocabulary an almost-subset (8-size difference) of
its 623 twin's.

## (ii) The 623 side's extra vocabulary is a fixed residue, NOT a function of surviving dose — the surviving B dose itself is a constant

For the six ordinal-matched 419↔623 pairs (AES-NUM-066):

- The 623 side's extra vocabulary (sizes in the 623
  context, absent in its 419 twin) is 34–49 sizes per
  pair (169 distinct across pairs; only 2 per pair are
  ≤ 512 B), carrying 42–58 occurrences in the 623
  context. NINE extra sizes recur in ALL SIX pairs:
  280 (×2 each), 424, 1280, 4976, 21408, 31984, 32576,
  32768 (×1 each), 32784 (×2 each); 2824 and 16400
  (×2) recur in five of six (16400 absent only at k=2).
- The AES-NUM-066 residue set is confirmed as counts,
  in the 623 context of every pair: 32784 exactly 2,
  280 exactly 2, 32768 exactly 1, 16400 exactly 2 in
  five pairs and 0 at k=2; in every 419 twin all four
  counts are ZERO.
- The surviving triplet dose does NOT explain the
  extra vocabulary. In the six 623 contexts the B
  dose is CONSTANT — exactly 2 in every collapsed and
  every zero context (this is precisely the fixed BB
  head pair of AES-NUM-066) — and the C dose is 0
  throughout, while the A dose varies 0 / 1 / 2 / 34 /
  34 / 73 and the total 2–75. With B constant, no
  B-correlation exists; extra-vocabulary size
  (38 / 44 / 41 / 34 / 38 / 49) correlates with the
  A/total dose at only −0.364 (n = 6, not a law).
- At class level the direction reverses: across all
  16 contexts of each class, distinct vocabulary is
  strongly ANTI-correlated with triplet dose (419:
  doseTot −0.979, A −0.952, B −0.944, C −0.966; 623:
  −0.979 / −0.948 / −0.947 / −0.965) — vocabulary
  grows as the triplet dies, in every member alike,
  not through the surviving member.
- Class-union anatomy: the 623 class's union
  vocabulary (635 sizes) holds 95 sizes the 419 union
  (547) never uses, while the 419 union holds only 7
  sizes the 623 union never uses — {48, 80, 184, 232,
  312, 11040, 27056}, the fixed small core that is the
  419 side's entire one-sided difference in the pairs
  (extra-419 = 9–11 sizes per pair around exactly
  this core). Of the 169 distinct pair-level extra-623
  sizes, only 57 are class-union 623-only; the other
  112 occur somewhere in the 419 class, just not in
  the ordinal twin.

Verdict: the 623 extra vocabulary is a class-level
residue pool with a fixed nine-size core present in
every collapsed/zero context, anchored by a constant
surviving B dose of exactly 2 (and C = 0) regardless
of how much A survives. It is not dose debris.

## (iii) Scattered-singleton follower test: the tendency is REAL and minor-specific — 59.1% vs 0% for the major member — but the follower's identity is per-artifact

Population as in AES-NUM-066: 17 remnant contexts, 32
minor occurrences; the 10 head-fixed occurrences
(0a0d BB pair, cc9 C prefix) excluded, leaving the 22
scattered occurrences (0856 ×14, 76c3 ×8).

- Scattered minors are followed by 4368 in 7 cases
  (0.318) and 3856 in 6 (0.273) — combined 13/22 =
  0.591 — with only 10 distinct follower sizes in
  total (the other nine: 4624 ×2, and 27280, 8624,
  32088, 32784, 26744, 8248, 31608 ×1 each).
- The control kills the coincidence reading: the
  MAJOR member's own occurrences in the same 17
  contexts are followed by 4368 or 3856 in ZERO of
  1,609 cases (0/1,338 in the scattered contexts
  alone). Corpus-wide, all 201,012 seam occurrences
  are followed by 4368 exactly 7 times — precisely
  the seven scattered-minor cases — and by 3856 in
  175 (0.001). The head-fixed minors are never
  followed by either (their followers are the fixed
  2824 / 21408 / 424 of AES-NUM-066).
- The choice between the two followers is
  per-artifact: in 76c3a8ff all seven 4368 followers
  occur (7 of its 8 scattered minors; the eighth is
  followed by 3856), while in 0856a10c 3856 leads
  (5 of 14) and 4368 never occurs — the pooled
  4368 ×7 / 3856 ×6 tendency of AES-NUM-066 was the
  sum of two artifact-local laws, not one corpus law.

Verdict: a scattered minor-member singleton is
followed by a small band size (4368 or 3856) in
59.1% of cases against a 0% major-member baseline in
the same contexts — a genuine minor-specific follower
law whose concrete follower is fixed per artifact.

## What this closes and what it queues

- MEASURED: the ordinal train is three-class — state
  sequences identical in 290/419/623; 290↔623 matched
  J 0.564–0.641, all above the mismatched max 0.456;
  290↔419 matched J 0.413–0.505 (mean 0.450 vs control
  mean 0.197, max 0.431); the 290 vocabulary lacks
  exactly 8 sizes against its 623 twin in all six
  pairs (shared coverage 0.966 of its actions).
- MEASURED: the 623 extra vocabulary (34–49 per pair)
  has a fixed nine-size all-six core (280 ×2, 424,
  1280, 4976, 21408, 31984, 32576, 32768 ×1, 32784
  ×2), with 16400 ×2 in five pairs; the surviving
  623 B dose is constant at exactly 2 and C at 0 in
  all six contexts while A varies 0–73, so the extra
  vocabulary is not a function of surviving dose;
  class-wide, vocabulary anti-correlates with total
  triplet dose at −0.979 in both classes; the class-
  union difference is one-sided (623-only 95 sizes,
  419-only the 7-size fixed core).
- MEASURED: scattered-minor followers — 4368/3856 in
  13/22 (59.1%) against 0/1,609 for the major member
  in the same contexts and 7 total 4368 followers
  corpus-wide (all of them these cases); the follower
  identity is per-artifact (76c3 → 4368 in 7/8;
  0856 → 3856 in 5/14, 4368 never).
- NEXT (4.68): the fixed 8-size 290-vs-623 difference
  (identity + recurrence across the six pairs);
  nine-size residue core outside the collapsed/zero
  contexts (full-dose and standard 623 contexts);
  per-artifact follower identity in the other
  artifacts' minor populations (76c3/0856 law vs
  MiniLM/cc9/0a0d scattered cases at larger scope).
  Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
