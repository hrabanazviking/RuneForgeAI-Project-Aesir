# Step-4 rail grades, +137 profile recurrence, windowed populations (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.59 (AES-NUM-059).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef59.py
(sha256 30fc7722…). Controls reproduce AES-NUM-029/032…058
EXACTLY (128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts; trailing
distinct (channel, operand) pairs 2,049; champion-headed
bursts 75,215). Transfer was a sha-gated gzipped file
(gz sha256 27dfc24e…): a single-shot crossing failed its
base64 validation and was discarded uncommitted; the
373 B-part crossing landed with its whole-file sha
verified on-device. Definitions (middle, band, window,
core cluster 9168–9248, exclusive family 9144–9264,
shoulders, POS / DENSE / OTHER, low ladder 8960–9136,
94xx ladder 9408–9488, 97xx ladder 9696–9792, refined
low-none segments) are as in AES-NUM-049…058.

## The rail has seventeen window counts, organised as +137 pairs

AES-NUM-058 left the 606/607-action step-4 rail as 55
cc9-only contexts (cidx 2, 6, …, 110 and 143, 147, …,
247; both blocks re-verified step-4 exact) with four
expected window-count grades (32 / 54–62 / 81 / 96).
The full census is wider and more regular than that:

- Window-count histogram over the 55: 32 ×8, 33 ×2,
  36 ×2, 38 ×2, 41 ×2, 47 ×2, 48 ×2, 50 ×2, 53 ×2,
  54 ×2, 62 ×2, 70 ×2, 81 ×2, 84 ×2, 91 ×4, 95 ×6,
  96 ×11 — seventeen distinct counts, not four grades.
  The TODO's four values are real members (32, 54, 62,
  81, 96) but they are not the whole set.
- The organising unit is the +137 pair. Every count
  except 91, 95 and 96 occurs in exactly one +137 pair
  (e.g. 33 = cidx 58/195, 84 = 30/167, 81 = 34/171 —
  the reduced low-none pair of AES-NUM-058). Count 91
  is two pairs (18/155, 98/235), 95 is three pairs
  (14/151, 90/227, 106/243), 96 is five pairs
  (10/147, 22/159, 26/163, 94/231, 102/239) plus the
  unpaired cidx 2, whose +137 partner (cidx 139) is
  not a rail context. Read in order, the second rail
  block's count sequence is the first block's sequence
  shifted by one position — exactly the +137 pairing.
- Within a pair the profile is (near-)identical: the
  named-family dose vector (band / low / exclusive /
  cluster / 94xx / 97xx / 93 / 89 / 98 segments),
  n32016 (= 32 in every rail context except two 95s
  and one 96 at 33/87) and champion body (= 29 in all
  55) match exactly; n32784 differs by exactly the
  pair's 607→606 step (64 vs 65) and ng flips 0→1.
  Examples: the 84 pair carries exclusive 48 + cluster
  38 + 97-dose 31/32 in both members; the 70 pair
  carries 94xx 26 + 93-segment 5 + n30480 3 in both;
  the 41 pair carries band 8 + 97-dose 31/32 in both.
- Nothing positional selects the count: every cidx
  residue mod 8 and mod 16 holds nearly every count;
  both rail halves hold every count (as the pairs);
  nacts (606/607), ng and order do not separate them
  (order is normal in 47/55; the reversals sit inside
  the 32 and 96 counts only). The count is the pair's
  own lead-family composition — window count = the
  total of its family doses plus its generic step-8
  leads — carried identically across +137. A selector
  beyond the pair profile itself is NOT PROVEN.
- Population split follows the count only loosely:
  96-count contexts are all DENSE, 81-count both POS
  (the reduced pair), 84-count both POS, 91/95-count
  split POS/DENSE, and every other count is OTHER.

## The all-97 quartet is the 32-count, all-97 corner of the rail

Defining all-97 as n97 ≥ nwin−1 over the rail gives
exactly four contexts — cidx 50, 54, 110, 187 — all
of window count 32, all normal-order, all with
n32016 ×32 and champion body 29:

- cidx 110 is the pure member: 32/32 windows 97-led
  in a single run of 32 at ordinal 0, no exception.
- cidx 50: 31/32, runs [11, 20] at starts [0, 12];
  its one non-97 window sits at ordinal 11 with the
  degenerate lead value 24.
- cidx 187: 31/32, runs [8, 23] at starts [0, 9];
  its one non-97 window is likewise at the run break
  (ordinal 8, lead 24).
- cidx 54: 31/32, runs [20, 11] at starts [0, 21];
  its one non-97 window is a 98-segment lead (9800)
  at ordinal 20 — the AES-NUM-058 block0 exception.

The quartet is one +137 pair (50 → 187, both 31/32)
plus two members whose partners are near-all-97
32-count contexts just below the line (191 at 30/32,
247 at 30/32); widening the definition to
n97/nwin ≥ 0.9 adds exactly those two partners plus
the 33-count pair 58/195 (31/33 each). Outside the
rail, the same n97 ≥ nwin−1 test returns only the
trivial single-window contexts (nwin 1, n97 0) of the
256/259-action classes — degenerate, not quartet
members. The quartet's place: it is not a separate
construction, it is the extreme of the 32-count
grade in which the 97xx fixed-dose module
(AES-NUM-055: dose capped at 32) fills the whole
window budget.

## +137 recurrence is a profile law across all of cc9

AES-NUM-058 established profile recurrence for the
reduced six and POS membership (9/10). Over all 134
eligible cc9 pairs (cidx 0–133 against +137), against
the mean preservation rate over all other offsets
2–269 as baseline:

- window count preserved 0.978 (baseline 0.271) —
  131/134 pairs; the only differing sources are
  cidx 0, 1, 2, the stream head before the rail and
  the periodic classes settle;
- population (POS/DENSE/OTHER) preserved 0.985
  (baseline 0.545): transitions are OTHER→OTHER ×93,
  DENSE→DENSE ×30, POS→POS ×9, with exactly two
  exceptions (one POS→OTHER, one DENSE→OTHER);
- n32016 preserved 0.985 (baseline 0.414); segment
  identity 0.978 (0.671); 97-class 0.843 (0.558);
  order 0.769 (0.524); exact nacts 0.582 (0.099) —
  nacts preservation is carried by the odd-cidx run
  cidx 3–111 plus 110–132 in the preserved list, i.e.
  by class membership, not by individual identity;
- POS membership 0.993, shoulder side 0.985 and
  low-none membership 0.978 — all high, but their
  baselines are also high (0.86–0.89 / 0.855), so the
  +137 lift there is real but modest (+0.12–0.13);
- ng is preserved 0/134 — structurally: every source
  cidx 0–133 is ng0 and every partner is ng1, so the
  ng boundary sits between cidx 133 and 137 and +137
  always crosses it. Champion body is 29 at every
  offset (rate 1.0 everywhere) and carries no signal.

Graded MEASURED: at +137 the cc9 stream repeats its
context PROFILES — window count, population, family
doses, segment identity, 97-dose class — at rates
0.84–0.99 against 0.27–0.67 baselines, while its
lead SEQUENCES do not repeat (AES-NUM-058). The
recurrence is a two-pass construction over the same
profile sheet, re-drawn in the second network group.

## The other two windowed populations are band monocultures

Only three artifacts hold windowed contexts at all
(AES-NUM-058). The two non-cc9 populations are far
narrower than cc9's:

- 0856a10c: 112 windowed of 256 contexts. Window
  counts are class-quantised — 16 ×28, 24 ×24,
  28 ×28, 140 ×28, plus four singletons (4, 7, 23,
  23). All 5,785 pooled leads come from a pool of
  just 112 distinct step-8 values (range 7944–9448,
  every value ≡ 0 mod 8); 5,368 of them (92.8%) are
  band-family (8104–8832), and the only other named
  family present anywhere is a single context with
  68 leads in the 94xx ladder. Low / exclusive /
  cluster / 97 / segment doses are all zero. Every
  windowed context repeats lead values (mean 11.6
  distinct per context, max 26 repeats of one lead),
  channels are near-balanced (1900/1993/1892),
  champion body is 29 in all 112, and n32016 is 0 in
  94 of 112 (the 140-count class carries 24 in 8).
- 76c3a8ff: 90 windowed of 325 contexts (the 156/173
  classes excluded as throughout). Counts are again
  quantised — 24 ×26, 28 ×26, 140 ×26, plus small
  classes (1 ×4, 2 ×2, 14 ×2, 52 ×2, 124 ×2). The
  pool is 139 distinct step-8 values; 4,932 of 5,380
  leads (91.7%) are band-family. The only named-family
  exceptions are the two known cluster contexts
  (cidx 3/4: 55 cluster + 63 exclusive leads between
  them) and single stray low/89/98 leads. Order is
  reversed in 58/90, n32016 is either 0 (62 contexts)
  or exactly 24 (28 — the 140-count class), champion
  body 29 in all 90.
- Contrast cc9: 147 windowed, 178 distinct lead
  values, and a genuinely mixed vocabulary — 97xx
  2,128, 94xx 1,622, low 1,235, exclusive 900,
  cluster 688, 93-segment 842, band only 34. The
  quantised 16/24/28/140 count classes of the other
  two artifacts have no cc9 analogue (cc9's counts
  are the +137 pair values above, 96 ×66 dominant).

So the window mechanism is shared (3856-preceded
step-8 leads, champion body 29, balanced channels),
but its vocabulary is per-network: two networks run
it as a band monoculture over a small repeating pool,
cc9 runs it as the full ladder vocabulary. Any
Aesir-side window emitter must therefore treat the
lead vocabulary as a per-network profile, not a
corpus constant.

## What this closes and what it queues

- MEASURED: the step-4 rail's window counts are
  seventeen values (32–96) organised as +137 pairs
  with (near-)identical family-dose profiles; the
  four values in the old TODO line are members, not
  the grade set. No positional, ng, order or nacts
  feature selects a count.
- MEASURED: the all-97 quartet (cidx 50, 54, 110,
  187) is the 32-count grade filled entirely by the
  capped 97xx module; one pure member (110), one
  +137 pair (50/187), two members with near-all-97
  partners (191, 247 at 30/32).
- MEASURED: +137 profile recurrence over all cc9 —
  window count 0.978, population 0.985, n32016 0.985,
  segment 0.978, 97-class 0.843, order 0.769, exact
  nacts 0.582, against baselines 0.099–0.671; ng
  always flips (boundary between cidx 133 and 137).
  Sequences do not recur; profiles do.
- MEASURED: the 0856a10c and 76c3a8ff windowed
  populations are band monocultures (92.8% / 91.7%
  band) over small step-8 pools (112 / 139 distinct
  values) with quantised window-count classes
  (16/24/28/140 and 24/28/140), against cc9's mixed
  ladder vocabulary.
- NEXT (4.60): the 140-count class shared by both
  monocultures (its lead pool, its n32016 24 dose in
  both artifacts, its position in each stream);
  cidx 0–2, the three +137 pairs whose window counts
  differ; the unpaired rail head cidx 2 vs its
  non-rail partner cidx 139. Host/artifact analysis
  only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
The grade vocabulary in the TODO line for this slice
(32 / 54–62 / 81 / 96) is corrected by §1: those are
members of a seventeen-value pair-organised set.
