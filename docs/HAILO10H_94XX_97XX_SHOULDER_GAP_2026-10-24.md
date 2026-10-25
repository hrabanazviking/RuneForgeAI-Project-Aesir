# 94xx ladder, shared 97xx ladder, shoulder gap (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.55 (AES-NUM-055).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef55.py
(sha256 b3f4a458…) plus the labelled follow-up
hef55b.py (sha256 e0fe1cfd…). Controls reproduce
AES-NUM-029/032…054 EXACTLY in both scripts (128,787
pooled small actions; 79,001 pooled 24 B bursts;
745,849 pointer actions; 1,504 contexts; trailing
distinct (channel, operand) pairs 2,049; champion-headed
bursts 75,215). Transfers were sha-gated gzipped 373 B
parts; both whole-file shas verified on-device first
try. Definitions (middle, band, window, core cluster
9168–9248, exclusive family 9144–9264) are as in
AES-NUM-049…054. POS = the 19 cc9b9d1c cluster-positive
contexts; DENSE = the 61 window-dense (≥81 windows)
cluster negatives; OTHER = the 191 sparse negatives.

## The 94xx ladder is NOT a family like 9144–9264

- No exclusive zone: the step-8 ladder runs continuously
  from 9352 upward through the 94xx range and beyond.
  Dense negatives carry every value 9352–9696; sparse
  negatives carry the lower values too (9352 ×17, 9408
  ×17, 9416 ×26…); positives carry ZERO at every value
  9352–9504, then enter the ladder at 9512 (×2) with
  growing counts through 9600 (×34) and 9608–9696 —
  the ladder's top is shared ground, not a boundary.
  No non-step-8 lead occurs in 9350–9600 in any pool.
- Membership is a subset, not a population: the core
  segment 9408–9488 holds 1,508 dense windows in only
  33 of the 61 dense contexts, plus 114 windows in 3
  sparse contexts (cidx 38 ×26, 139 ×61, 175 ×26).
  Corpus-wide at 9400–9504 the segment lives in 41
  standard contexts: 40 in cc9b9d1c and 1 in 0856a10c.
  235 of 271 cc9b9d1c contexts carry none of it.
- Dose is BIMODAL: 26 negative contexts are high
  carriers (dose 45–63 in the 9408–9488 segment,
  tightly clustered), 10 are low carriers (dose 1–26),
  and the rest are zero. Correlation with window count
  is weak (0.217 — dense window counts are ~96 for
  carriers and non-carriers alike). This is nothing
  like the exclusive family's graded dose law
  (correlation 0.948 with its core).
- The real discriminator is the LOW ladder: high-94xx
  dense contexts carry a mean of 0.0 low-ladder
  (8960–9136) windows — the low ladder is completely
  absent in all 25 dense high carriers — while
  zero-94xx dense contexts carry a mean of 34.4
  (94xx dose vs low dose correlation −0.575). The
  dense population splits into two sub-populations
  that choose one ladder or the other. The two sparse
  low carriers cidx 38/175 are a symmetric pair (607/
  606 actions, 70 windows each, 94xx 26, 97xx 28/27,
  middle 32016 ×32, 30480 ×3, both normal order).
- Its windows speak NO dialect of their own: dense
  contexts' middles hold 32016 at mean 79.2 and 30480
  at mean 0.1 (total 6 in 61 contexts; 57/61 contexts
  have exactly zero 30480) — the same 32016 dialect as
  the cluster positives (mean 69.1 / 0.5). Behind
  94xx-led windows, the next 8 sizes contain 30480
  ZERO times in 1,508 windows; window classes are
  other 1,035 / no30480 473 / full 0; the preceding
  size is most often 32016 (×541). What distinguishes
  the 94xx population is lead vocabulary and the
  low-ladder exclusion — not window internals.

Graded MEASURED: the "94xx ladder" of AES-NUM-054 is
the dense-heavy middle segment of one continuous
9352–9696 ladder; its high-dose carriers form a
sub-population defined equally by what they lack
(the low ladder, dose exactly 0) as by what they
carry, and they speak the shared cc9 32016 dialect.

## The shared 97xx ladder is a fixed-dose common module

- Corpus scope: the 9696–9792 segment appears ONLY in
  cc9b9d1c — 2,128 windows in 74 standard contexts,
  no other artifact carries a single 97xx-led context.
- Presence crosses every cc9 sub-population: POS
  9/19 contexts, DENSE 41/61, OTHER 24/191.
- Dose in carriers is CAPPED and tight: the maximum
  is exactly 32 in every population. POS carriers
  29–32 (mean 31.1, pstdev 0.99); OTHER carriers
  25–32 (mean 29.7, pstdev 2.15); DENSE carriers
  mostly 24–32 with four low outliers (5, 6, 7, 7).
  Correlations with everything else are ~0 (vs
  exclusive dose −0.186, vs core −0.199, vs 94xx
  −0.178, vs window count +0.135/+0.249): the dose
  does not scale with any dialect dose or context
  size. Presence is binary; dose is a ~30 ceiling.
- Its windows are the SAME form in both dialects:
  POS-led classes other 162 / no30480 117, DENSE-led
  other 680 / no30480 455; after-1 is 32784 in both
  (181/280, 724/1,135); the preceding size is 32016
  in both (126, 514); 30480 appears in the next 8
  sizes in only 2 windows in each population.

Graded MEASURED: the 97xx ladder is a cc9-only,
fixed-dose (~32 maximum) common module carried by a
subset of contexts in every sub-population, with
identical window anatomy in the family and ladder
dialects — shared infrastructure, not vocabulary.

## The shoulder gap: one shoulder per context, never both

Pooled over the 21 exclusive-family contexts (19 cc9
positives + 76c3a8ff cidx 3/4): exclusive dose 963,
core dose 743, gap 220 (lower shoulder 9144–9160:
112; upper shoulder 9256–9264: 108), gap share 22.8%
of the family dose.

- Per context the gap is 0–23 (mean 10.5, median 9)
  and does NOT scale with the family: correlation
  with core dose −0.290, with exclusive dose +0.043.
  The gap is a substitution pattern, not an add-on.
- In cc9b9d1c the shoulder SIDE is a per-context
  binary trait: 9 contexts are lower-only, 10 are
  upper-only, ZERO carry both shoulders, ZERO carry
  neither (lower/upper dose correlation −0.562).
  The only corpus exceptions are the known ones:
  76c3a8ff cidx 3 carries both (4 lower + 4 upper,
  gap 8) and cidx 4 carries neither (gap 0, its
  exclusive dose equals its core dose, 14).
- Shoulder-led windows are anatomically ordinary
  family windows: classes other 162 / no30480 49 /
  no32784 1 (core-led: 527 / 157 / 4), after-1 led
  by 32784 (×77), 30480 in next-8 in only 2/212.
- The gap fraction spans the full range: cidx 85 and
  222 are nearly pure core (gap 1, share 0.016),
  while cidx 1's family membership is mostly
  shoulder (gap 8 of 9, share 0.889, all upper) —
  consistent with its edge-member grade in
  AES-NUM-054.

Graded MEASURED: every cc9b9d1c family context adds
exactly ONE shoulder to the core — lower or upper,
never both — at a dose that does not track the core
dose; shoulder choice is a new per-context binary
variable whose selector is NOT PROVEN.

## What this closes and what it queues

- MEASURED: the 94xx segment has no exclusive zone
  and no graded dose law; its high carriers are a
  bimodal sub-population marked by a total absence
  of the low ladder, speaking the shared 32016
  dialect. It is not a second family.
- MEASURED: the 97xx ladder is cc9-only, present in
  all sub-populations, dose-capped at exactly 32,
  anatomically identical across dialects — a common
  fixed-size module, not a dialect feature.
- MEASURED: the exclusive-minus-core gap (220
  windows) is one shoulder per context (9 lower /
  10 upper / 0 both in cc9), uncorrelated with core
  dose; the 76c3a8ff pair are the only exceptions.
- NEXT (4.56): shoulder-side selection (what pairs
  with lower vs upper — pair order, 97xx carriage,
  context index, window positions of shoulder vs
  core); the dense sub-population split (high-94xx
  vs low-ladder contexts: any other distinguishing
  feature?); the 97xx module's position structure
  (are its ~30 windows one contiguous run?).
  Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
