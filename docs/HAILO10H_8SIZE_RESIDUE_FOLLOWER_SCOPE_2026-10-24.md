# Fixed 8-size difference, residue core outside collapsed/zero, follower scope (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.68 (AES-NUM-068).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef68.py
(sha256 9dc873e9…). Controls reproduce AES-NUM-029/032…067
EXACTLY (128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts; trailing
distinct (channel, operand) pairs 2,049; champion-headed
bursts 75,215). Transfer: gzipped script in 373 B parts,
each part received-byte-counted on-device via the
file-write session, whole-file sha256 verified on-device
before the run (landed first try). Definitions (seam set
A = 7952, B = 32784, C = 26896; collapsed/zero states;
ordinal-matched pairs) are as in AES-NUM-061…067.

## (i) The fixed 8-size difference is ONE identical set — a 290-class signature, not a per-pair difference

In every one of the six ordinal-matched 290↔623 pairs
(AES-NUM-067), the 290 side's private vocabulary
(sizes in the 290 context, absent in its 623 twin) is
EXACTLY the same eight sizes, at the same counts, at
the same first-occurrence positions:

- {200 ×3, 360 ×1, 8576 ×1, 13176 ×1, 13480 ×1,
  14224 ×1, 20488 ×1, 32600 ×1} — union over the six
  pairs = intersection = these 8 (recurrence 6/6 each;
  identical-set test true).
- Counts per pair are invariant (200 three times, the
  other seven once each) and first positions in the
  290 context are invariant in all six pairs (by size
  order above: 18, 15, 14, 23, 26, 17, 20, 13 — all in
  the early block, positions 13–26).
- None of the eight occurs in ANY ordinal 419 twin
  (0/8 present in all six pairs).
- Class-wide, each of the eight occurs in ALL SIXTEEN
  290-class contexts (16/16) and in NO 419-class and
  NO 623-class context (0/16 each). Corpus-wide the
  sizes are not unique to 0a0d (e.g. 200 in 223
  contexts, 360 in 373), but inside 0a0d they are a
  clean 290-class marker (16–52 contexts per size,
  the 290 class always among them).

The mirror side sharpens too: the six pairs' 623-only
intersection is exactly 11 sizes — the nine-size
residue core of (ii) plus 264 and 2824.

Verdict: the "exactly 8" of AES-NUM-067 is not six
coincidental counts. It is a single fixed eight-size
set carried by every 290-class context and by no
context of the neighbouring classes — a class
signature sitting at fixed early positions with fixed
multiplicities.

## (ii) The nine-size residue core is a 623-CLASS invariant — present in every 623 context, with eight of nine counts frozen

The AES-NUM-067 core {280, 424, 1280, 4976, 21408,
31984, 32576, 32768, 32784} was tested outside the
collapsed/zero population:

- In the ten OTHER (full/intermediate-dose) 623-class
  contexts, all nine sizes are present in 10/10. Eight
  of the nine hold the collapsed/zero counts EXACTLY
  in every one of the 16 class contexts: 280 ×2, and
  424 / 1280 / 4976 / 21408 / 31984 / 32576 / 32768
  ×1 each. The ninth, 32784, is the seam member B
  itself: its count is the context's B dose (exactly
  2 in the collapsed/zero six; 24–130 in the other
  ten, matching each context's measured B dose).
- The companion 16400 recurs likewise: ×2 in five of
  the six collapsed/zero contexts and present in
  10/10 of the other 623 contexts (mean 1.9).
- Outside the 623 class the core collapses: in 290
  and 419 contexts (collapsed/zero AND other alike)
  the eight non-B sizes occur in ZERO contexts — only
  32784 itself appears, as the ordinary seam member.
  Corpus-wide, exactly 16 contexts hold all nine
  sizes: precisely the 16 contexts of the 623 class
  (0a0d holds 180 contexts; no other artifact holds
  even one all-nine context; the next-strongest core
  members corpus-wide are 424 in 769 contexts and 280
  in 391, while 4976 and 21408 occur in exactly the
  16 class contexts).

Verdict: the residue core is not residue. It is a
fixed per-context fixture of the whole 623 class —
eight sizes at frozen counts in every context of the
class, plus the B member at its dose — and it is
entirely absent (beyond B itself) from both
neighbouring classes. AES-NUM-067's "extra vocabulary"
reading is corrected: what differs between the
collapsed/zero twins is the presence of this class
fixture in the 623 contexts, not debris left by a
dying triplet.

## (iii) Follower identity at larger scope: the band follower does NOT generalise — each artifact's minors follow their own fixed sizes, and two artifacts have no minor population at all

Two populations were tested. Population A is the
exact AES-NUM-066/067 remnant definition (two-member
contexts, minor ≤ 4): 17 contexts (0856 ×8, 0a0d ×4,
76c3 ×3, cc9 ×2; MiniLM and both sisters hold none).
Population B widens the net (any seam member of count
1–4 in a context with total seam ≥ 10 and a major
member ≥ 20): 29 contexts, 34 minor occurrences.

- The 13 band-follower cases of AES-NUM-067 are ALL
  of them, at both scopes: population B's minor
  occurrences are followed by 4368/3856 in 13/34
  (the same 13; 7 in 76c3, 6 in 0856 counting the one
  3856 case in 76c3), against 0/1,694 for the major
  members of the same population-B contexts.
  Corpus-wide baselines agree: all seam occurrences
  are followed by 4368 exactly 7 times in the whole
  corpus (the 76c3 minor cases) and by 3856 175 times
  (0856 5 = its minors; 76c3 21; cc9 149 — none of
  cc9's after a minor).
- 0a0d378c: its minors never take a band follower.
  The head-fixed BB pair is followed by 2824 / 21408
  (population A; population B's head-fixed followers
  2824 ×3, 21408 ×3) — two of the very sizes of the
  (i)/(ii) fixtures — and population B's four extra
  scattered B occurrences are followed by 26896 ×3
  and 26584 ×1 (the major member itself / a neighbour
  size), never 4368/3856.
- cc9b9d1c: its only minors are the head-fixed C
  prefixes, followed by 424 ×2 (another core size);
  no scattered minor population exists.
- MiniLM, 5ab3537d, 773470cd: NO minor population at
  either scope (MiniLM holds only 3 seam occurrences
  in total; the sisters' seam members are balanced),
  so no follower law is defined there — over their
  ~29,600 seam occurrences each, 4368/3856 follow
  exactly zero times.

Verdict: the band-follower law is local to the two
artifacts that hold scattered minors (76c3 → 4368,
0856 → 3856). At larger scope the general shape is
"a minor occurrence is followed by an artifact-fixed
size, never by the major member's ordinary
followers" — 0a0d's minors follow fixture sizes
(2824 / 21408 head-fixed, 26896 scattered), cc9's
follow 424 — but the concrete follower, and even the
existence of a minor population, is per-artifact.
No corpus-wide follower exists.

## What this closes and what it queues

- MEASURED: the fixed 8-size difference is one
  identical set {200 ×3, 360, 8576, 13176, 13480,
  14224, 20488, 32600} — same counts and same first
  positions (13–26) in all six pairs; present in all
  16 290-class contexts, absent from all 419/623
  class contexts; the 623-only intersection over the
  six pairs is 11 sizes (the nine core + 264 + 2824).
- MEASURED: the nine-size core is a 623-class
  invariant — all nine present in 16/16 class
  contexts, eight at frozen counts (280 ×2, seven
  ×1), 32784 = the B dose; the eight non-B sizes
  occur in zero 290/419 contexts; corpus-wide only
  the 16 class contexts hold all nine.
- MEASURED: follower identity at larger scope —
  population B (34 minor occurrences, 29 contexts)
  adds no new band-follower case (13/34, the same
  13; major baseline 0/1,694); 0a0d minors follow
  2824/21408 (head) and 26896 (scattered), cc9
  minors follow 424, MiniLM and both sisters hold
  no minor population at all.
- NEXT (4.69): positions and neighbours of the
  eight-size 290 signature inside its contexts
  (fixed slots? a head fixture like the quartet?);
  the 264 + 2824 companions of the 623 fixture
  (counts/positions in all 16 class contexts);
  0a0d scattered-B follower 26896 mechanism
  (is the follower the stream's next seam member?).
  Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
