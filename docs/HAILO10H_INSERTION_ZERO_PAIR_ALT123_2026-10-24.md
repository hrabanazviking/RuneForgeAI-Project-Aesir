# Remnant insertion positions, zero-pair overlap anatomy, 123-class alt frame (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.66 (AES-NUM-066).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef66.py
(sha256 31b3b020…). Controls reproduce AES-NUM-029/032…065
EXACTLY (128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts; trailing
distinct (channel, operand) pairs 2,049; champion-headed
bursts 75,215). Transfer: gzipped script in 373 B parts,
each part sha-gated on-device (one first crossing of
part 3 was corrupted in re-emission, its received byte
count exposed it, the session was discarded uncommitted
and restarted; the second crossing verified whole-file
sha256 80d1dc1b… for the gzip and 31b3b020… for the
script). Definitions (seam set A = 7952, B = 32784,
C = 26896; alt set A = 7952, B = 25872, C = 32784) are
as in AES-NUM-061…065.

## (i) Remnant singleton insertion positions: no universal law — two fixed head insertions, the rest scattered

Population (seam sequence with exactly two distinct
members, minor-member count 1–4): 17 contexts, 32 minor
occurrences — 0856 A/B ×3 (minor A), 0856 B/C ×5 (minor
C), 0a0d A/B ×4 (minor B; the 623 collapsed contexts),
76c3 A/B ×3 (minor A), cc9 B/C ×2 (minor C). Every
minor occurrence is flanked by the major member in the
seam sequence, except the head occurrences (no seam
predecessor) and one terminal occurrence (0856 cidx 23,
ordinal 32/32, the seam sequence's last letter).

- NO universal position law: the 32 occurrences spread
  over action-position fractions 0.021–0.861 and seam
  ordinals 0–181; outside the head cluster below, every
  seam ordinal is unique (exception: ordinal 25 twice,
  with different neighbours — coincidence-grade).
  Fraction thirds split 14 head / 7 mid / 11 tail, with
  no concentration.
- FIXED HEAD INSERTION 1 (0a0d 623 collapsed ×4, cidx
  27/31/35/39): the minor B dose is exactly a BB pair at
  seam ordinals 0–1, action positions 13 and 17, with
  identical action neighbours in all four contexts
  (preceded by sizes 304 / 24, followed by 2824 /
  21408). The collapsed contexts' surviving 32784 dose
  is this head pair, at a fixed address.
- FIXED HEAD INSERTION 2 (cc9 151/203): the single C
  sits at seam ordinal 0, action position 16, preceded
  by 32640 and followed by 424, identical in both
  contexts (AES-NUM-065's head prefix, now positioned).
- The remaining 22 occurrences (0856 + 76c3) are
  scattered singletons with heterogeneous neighbours;
  the only measurable tendency is the following action:
  4368 in 7 and 3856 in 6 of all 32 occurrences (the
  head pairs contribute the 2824 ×4 / 21408 ×4 / 424 ×2
  followers). Recorded as a count, not a law.

Verdict: insertion position is fixed exactly where the
remnant is a structural residue (the two head cases)
and unconstrained where it is a stray singleton. There
is no corpus-wide insertion slot to encode.

## (ii) Zero-pair overlap anatomy: the high-J pairs are exactly the ordinal-matched pairs, and large sizes carry the overlap

All 18 collapsed/zero contexts of the 0a0d 290/419/623
classes were paired (153 pairs). Eleven pairs reach
J ≥ 0.60; the six pairs at J ≥ 0.72 are ALL cross-class
419↔623 pairs, and they are exactly the ORDINAL-matched
pairs — the k-th collapsed/zero context of the 419
class against the k-th of the 623 class, state-matched
(zero↔zero, collapsed↔collapsed), for k = 1…6:
114↔27 collapsed (J 0.768), 120↔31 zero (0.724),
126↔35 collapsed (0.721), 132↔39 collapsed (0.755),
138↔43 zero (0.766), 168↔63 zero (0.774). No
ordinal-mismatched pair reaches 0.72.

Anatomy of the six (J ≥ 0.70 printed in full):

- The overlap is carried by LARGE sizes: in every pair
  exactly 15 shared sizes are ≤ 512 B (the fixed small
  skeleton), while the intersections total 132–202
  sizes — 117–187 shared sizes are > 512 B, dominated
  by the 55xx–58xx band ladders, the 74xx/75xx band,
  and the 25k/30k/31k vocabularies (top shared: size 24
  at 50/50 in all six; 176 at 4/4; the class band —
  5592/5584/5608… in collapsed pairs, 5640/5712/5856…
  in zero pairs; 7952 itself in the collapsed pairs).
- Shared sizes carry 0.907–0.976 of each context's
  actions, but with UNEQUAL doses (e.g. 5856 at
  12 vs 16, 7952 at 26 vs 34, 5592 at 25 vs 41) and
  WITHOUT stream position: first-occurrence positions
  agree for only 1–2 of 132–202 shared sizes per pair.
  The kinship is vocabulary + approximate dose at
  matched ordinal, not a shared stream layout (the
  623 contexts carry 204 more actions).
- The symmetric difference is one-sided: the 419 side
  lacks only 9–11 sizes per pair, around a recurring
  core {48, 80, 184, 232, 312, 11040, 27056, 32368}
  present in all six; the 623 side lacks 34–49 sizes,
  recurrently including 32784 ×2, 16400 ×2, 280 ×2 and
  32768 — the larger class's extra vocabulary is the
  triplet member's own residue plus large-form sizes.

Verdict: the zero/collapsed pool (AES-NUM-065) is drawn
by ORDINAL position within the class train — the k-th
collapsed context of one class is the vocabulary twin
of the k-th in the next — and the overlap lives in the
large-size bands, not the small skeleton.

## (iii) The 123-class pattern in the alt frame: one fixed 24-letter template, balanced, rotating in the corpus sense at degraded strength — a projection, not a new block

The sixteen 0a0d 123-action ng-1 contexts (cidx 75,
81, …, 165, step 6) share ONE alt sequence, identical
in all sixteen and found in no other context
corpus-wide:

`CBABCBAABCACBACBACBCBAAC` (24 letters; A/B/C = 8/8/8)

- 25872 does NOT complete a clean rotation: per-context
  transitions are 6 forward (A→B→C→A in ascending alt
  assignment) / 15 reverse / 2 self of 23 — the
  dominant sense (0.652 reverse) is the corpus's single
  rotational sense of AES-NUM-063 (pooled 3-member alt
  contexts corpus-wide: forward 0.174, reverse 0.687),
  at the same degraded strength as the other classes,
  not the near-perfect cycles seen in single contexts
  (135 at 0.958). The seam sequence is likewise one
  fixed template (`BABAABABABABBAAB`, AES-NUM-065).
- Between-member fillers are the usual body material:
  80 occurs exactly 3 times per context in the gaps,
  the rest are 55xx–57xx band sizes (7–12 distinct gap
  sizes per context, varying while the letter template
  is fixed).

Verdict: in the alt frame the 123 class is the same
fixed triplet template seen through the other member
set — balanced 8/8/8, one rotational sense, degraded —
i.e. a PROJECTION of the triplet machinery (the
AES-NUM-064 grading), not an independent alternating
block. Its distinction is total template identity
across a step-6 train of sixteen contexts.

## What this closes and what it queues

- MEASURED: remnant insertion positions — no universal
  slot; two fixed head insertions (0a0d 623 collapsed
  BB pair at positions 13/17 in 4/4 contexts; cc9 C
  prefix at position 16 in 2/2); the other 22
  occurrences are scattered singletons (fractions
  0.110–0.861, unique ordinals).
- MEASURED: the six J ≥ 0.72 zero/collapsed pairs are
  exactly the ordinal-matched, state-matched 419↔623
  pairs (k = 1…6); their overlap is carried by large
  sizes (117–187 of 132–202 shared sizes > 512 B; only
  15 small), covers 0.907–0.976 of actions at unequal
  doses, and does NOT preserve stream positions
  (first-occurrence agreement 1–2 per pair); the
  vocabulary difference is one-sided (419 lacks 9–11
  sizes around a fixed core; 623 lacks 34–49).
- MEASURED: the 123-class alt sequence is one fixed
  24-letter balanced template in all 16 contexts and
  nowhere else; its rotation is the corpus sense at
  degraded strength (15/23 reverse) — a projection of
  the triplet machinery, not a new block.
- NEXT (4.67): ordinal-matched pairing test for the
  290 class (its k-th collapsed/zero contexts vs the
  419/623 twins — do the J ≥ 0.60 pairs at 0.601–0.656
  complete the same train at lower dose?); the 623
  side's extra vocabulary (32784/16400/280/32768
  residue) vs its surviving triplet dose; scattered-
  singleton follower test (4368/3856 followers vs the
  major member's own follower distribution).
  Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
