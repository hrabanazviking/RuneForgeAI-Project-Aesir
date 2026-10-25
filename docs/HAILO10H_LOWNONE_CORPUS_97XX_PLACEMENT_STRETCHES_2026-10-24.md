# Low-none corpus-wide, 97xx placement, shoulder stretches (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.57 (AES-NUM-057).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef57.py
(sha256 10f6275f…) plus the labelled follow-up
hef57b.py (sha256 8aa9fb00…). Controls reproduce
AES-NUM-029/032…056 EXACTLY in both scripts (128,787
pooled small actions; 79,001 pooled 24 B bursts;
745,849 pointer actions; 1,504 contexts; trailing
distinct (channel, operand) pairs 2,049; champion-headed
bursts 75,215). Transfers were sha-gated gzipped 373 B
parts; both whole-file shas verified on-device (one
single-shot 6 kB crossing of hef57 failed its sha gate
and was discarded uncommitted; the chunked crossing
landed clean). Definitions (middle, band, window, core
cluster 9168–9248, exclusive family 9144–9264, shoulders,
POS / DENSE / OTHER, low ladder 8960–9136, 94xx ladder
9408–9488, 97xx ladder 9696–9792) are as in
AES-NUM-049…056.

## The low-none form is cc9-only, 21 contexts, three lead families

AES-NUM-056 found 12 dense contexts (zero94, low-ladder
dose 0–1) led by 93xx/89xx segments. Refined segments —
93-led 9288–9392, 89-led 8888–8952, 98-led 9800–9856 —
show the 12 are three mutually exclusive sub-families,
never co-occurring in any context corpus-wide:

- 93-led ×6 (cidx 25, 41, 61, 97, 162, 234): segment
  dose 56–64 of 96 windows; pooled segment is a clean
  step-8 ladder 9288–9392 peaking at 9320.
- 89-led ×4 (cidx 37, 45, 174, 182): dose 53–58; the
  pooled 8800–9000 histogram is one ladder 8880–8952
  peaking at 8912, ending exactly where the low ladder
  (8960+) begins — the 89 segment is the low ladder's
  missing lower half in these contexts, not a foreign
  vocabulary.
- 98-led ×2 (cidx 109, 246): dose 63–64 at 9800–9856,
  with the rest of their top leads at 9760–9792 — the
  ladder continues straight through the 97xx band to
  9840; these two contexts' 97xx count of 32 is the
  lower half of their own lead ladder.

The refined signature (low-ladder dose ≤ 1, 94xx dose
0, and any one segment dose ≥ 20) hits exactly 21
contexts corpus-wide, ALL in cc9b9d1c, in two grades:

- Maximal grade ×15 (738 actions, 96 windows, 32016
  ×96, all reversed): the 12 dense contexts plus three
  POS family contexts — cidx 1 (93-led dose 42; the
  family's edge member of AES-NUM-054 is a low-none
  context wearing the family dose 9 on top), cidx 29
  (93-led 21) and cidx 166 (93-led 21).
- Reduced grade ×6 (606–607 actions, 32016 ×32, all
  normal): cidx 34, 66, 171, 203 (93-led, dose 20–21)
  and cidx 86, 223 (89-led, dose 26 each; near-twins in
  profile but neither mid-size nor lead sequences are
  identical).

No other artifact carries the form at all: outside
cc9b9d1c the 93 segment appears in ZERO contexts and
the 89 segment in exactly one (76c3a8ff, dose 1).
Within cc9b9d1c, 93-led contexts number 20 and 89-led
10 at any dose ≥ 1, with zero overlap.

Graded MEASURED: the low-none form is a cc9b9d1c-only
population of 21 contexts (15 maximal + 6 reduced),
each led by exactly one of three step-8 segments
(9288–9392 / 8888–8952 / 9800–9856) at dose 20–64,
with the low and 94xx ladders absent. It is not a
dense-negative peculiarity: it spans POS, DENSE and
OTHER, and three of its maximal members are family
contexts. What the three segments are is NOT PROVEN.

## 97xx block placement follows the network group

Classifying the 74 cc9b9d1c carriers by their longest
97xx run (AES-NUM-056 classes, recomputed): block0
(maxrun ≥ 15 starting at ordinal 0) ×13, block43
(maxrun ≥ 15 starting at 43) ×12, mid ×26, scatter
(maxrun ≤ 7) ×23. The two canonical placements split
cleanly on the network group (ng):

- block43 is exclusively ng0 and exclusively maximal:
  all 12 are ng0, all 12 are 738-action / 96-window /
  32016-×96 contexts, 10 of 12 carry the exact late
  template [21, 2, 1, 3, 1, 1, 2, 1]. No 97xx lead
  occurs before ordinal 43 in any of them; the 43
  windows before the block are an ordinary mixed
  population (pooled: low 165, 94xx 122, exclusive 25,
  core 30, other 174 of 516).
- block0 is predominantly ng1: 11 of 13 are ng1 and
  maximal (738/96/96); the two ng0 exceptions are
  cidx 54 and the all-module cidx 110 (32 windows, all
  97xx-led). The ng1 block0 contexts still carry 142
  scattered 97xx windows at ordinals ≥ 21 behind the
  block.
- Mid and scatter classes span both groups and every
  sub-population; no feature tested separates them
  from the block classes beyond run length itself.

The low-none population crosses all placements
(block43 ×3, block0 ×2, mid ×3, scatter ×2,
non-carrier ×2), so placement is not a dialect
property. Graded MEASURED: a canonical 21-block at
ordinal 43 occurs only in maximal ng0 contexts and
at ordinal 0 predominantly in maximal ng1 contexts
(11/13); the placement rule beyond that correlation
— and what the mid/scatter carriers lack — is NOT
PROVEN.

## Shoulder stretches: the intervening stream repeats at +137

The 19 POS contexts in index order give 11 same-side
adjacent pairs (within-stretch) and 7 switch pairs.
Two positional facts dominate everything else:

- Gaps differ by an order of magnitude: within-stretch
  cidx gaps are 1, 1, 1, 3, 3, 4, 4, 8, 8, 20 (and one
  further 1) — mean 4.9 — while switch gaps are 11,
  11, 13, 20, 23, 23, 66 — mean 23.9. Side stretches
  are runs of NEARBY family contexts; switches happen
  across long family-free spans (the 66-gap, cidx
  85→151, crosses the artifact's midpoint).
- The stream mirrors at offset +137 in its lead
  sequences: at cidx offset 137, 72 of 134 context
  pairs have byte-identical window-lead sequences
  (mid-size sequences are identical in 0 of 134, and
  0 at every other tested offset 1–139). Nine of the
  ten POS contexts at cidx ≤ 133 recur as POS at
  +137 (14→151, 18→155, 29→166, 30→167, 33→170,
  34→171, 57→194, 65→202, 85→222), eight of them with
  the SAME shoulder side; the exception is 85 (upper)
  → 222 (lower). This mirror is why switch-boundary
  intervening profiles repeat exactly (18→29 ≡
  155→166, 34→57 ≡ 171→194, 57→65 ≡ 194→202,
  65→85 ≡ 202→222 in every pooled statistic).

The intervening contexts themselves barely differ by
boundary type: within-stretch intervening (43 contexts)
vs switch intervening (160) — 32016 mean 24.6 vs 24.9,
97xx mean dose 9.1 vs 8.0, orders alike. The one real
difference is the low ladder: within-stretch
intervening contexts carry it at mean 0.91 (93% zero)
against 5.29 across switch spans — the low ladder is
nearly absent inside a stretch's neighbourhood,
echoing AES-NUM-056's law that upper family contexts
are low-ladder-free, now seen on the intervening
stream as well.

Graded MEASURED: shoulder stretches are short-gap
runs (mean 4.9 vs 23.9 at switches); the cc9b9d1c
context stream repeats its window-lead sequences at
offset +137 (72/134 identical, POS recurring 9/10,
side preserved 8/9); intervening contexts do not
select the side — only their low-ladder dose is
lower within stretches (0.91 vs 5.29). A mechanism
for the side or the mirror is NOT PROVEN.

## What this closes and what it queues

- MEASURED: the low-none form is cc9b9d1c-only,
  21 contexts in two grades (15 maximal reversed,
  6 reduced normal), each led by exactly one of
  three mutually exclusive segments (93 / 89 / 98);
  it spans POS, DENSE and OTHER.
- MEASURED: the canonical 97xx block sits at
  ordinal 43 only in maximal ng0 contexts and at
  ordinal 0 predominantly in maximal ng1 contexts
  (11/13); mid/scatter placements span both groups.
- MEASURED: shoulder stretches are short-gap runs;
  the context stream's lead sequences mirror at
  cidx +137 (72/134 identical; POS 9/10 recurring,
  side 8/9 preserved); intervening contexts differ
  only in low-ladder dose (0.91 within vs 5.29
  across switches).
- NEXT (4.58): the +137 lead mirror's extent (which
  contexts, which artifacts — is it a cc9-only
  construction-wide repetition?); the reduced-grade
  low-none six (their full anatomy vs the maximal
  15); block0's two ng0 exceptions (cidx 54, 110).
  Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
