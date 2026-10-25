# Shoulder-side selection, dense split, 97xx positions (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.56 (AES-NUM-056).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef56.py
(sha256 30bc87a3…) plus the labelled follow-up
hef56b.py (sha256 64c23e5a…). Controls reproduce
AES-NUM-029/032…055 EXACTLY in both scripts (128,787
pooled small actions; 79,001 pooled 24 B bursts;
745,849 pointer actions; 1,504 contexts; trailing
distinct (channel, operand) pairs 2,049; champion-headed
bursts 75,215). Transfers were sha-gated gzipped 373 B
parts; both whole-file shas verified on-device first
try. Definitions (middle, band, window, core cluster
9168–9248, exclusive family 9144–9264, shoulders
9144–9160 lower / 9256–9264 upper, POS / DENSE / OTHER)
are as in AES-NUM-049…055.

## Shoulder side: no tested selector, two correlates

The 19 cc9b9d1c family contexts (9 lower-only, 10
upper-only, per AES-NUM-055) were tested against pair
order, 97xx carriage, context index, and window
position. None of the named candidates selects the
side:

- Pair order is balanced in both groups: lower-only
  4 normal / 5 reversed; upper-only 4 normal /
  6 reversed.
- 97xx carriage is the same rate on both sides:
  lower 4/9, upper 5/10; carrier doses are the same
  ~29–32 module dose on both sides (lower carriers
  32/29/31/30; upper carriers 32/32/32/31/31). Mean
  n97 13.6 vs 15.8, correlation with side +0.072.
- Context index does not separate: lower cidx span
  14–222 (mean 119.8), upper span 1–171 (mean 88.6),
  correlation −0.210; parity (5/4 even/odd vs 4/6)
  and mod-3 / mod-6 classes are mixed in both.
- Position does not separate: shoulder windows are
  interleaved through the core span, not placed at
  an edge. Pooled shoulder windows sit at mean
  window-ordinal fraction 0.487 against core windows'
  0.482; per-context mean-fraction differences
  (shoulder − core) average −0.003 (lower) and
  +0.020 (upper). Of 212 shoulder windows, 179 lie
  inside their context's core span, 19 before the
  first core window and 14 after the last — the same
  spread on both sides (lower 99/108 inside; upper
  80/104 inside).

Two correlates DO hold, both one-directional:

- Low family dose is always upper. The five POS
  contexts with exclusive dose < 30 (9, 19, 16, 20,
  16; core doses 1, 4, 7, 6, 7) are upper-only
  without exception. Lower-only contexts are
  uniformly high-dose (exclusive 51–64, core
  29–63). At high dose the side is mixed (lower 9,
  upper 5), so dose does not determine the side —
  but no low-dose context takes the lower shoulder.
  Side correlates −0.625 with exclusive dose and
  −0.537 with core dose, driven by this split.
- Upper contexts carry no low ladder at all: the
  low ladder (8960–9136) counts exactly 0 in all
  10 upper contexts, while lower contexts carry
  0–7 (21 total, 6 of 9 contexts nonzero;
  correlation −0.536). Recorded as a weak
  subordinate signal, not a selector. The only
  30480 counts in POS sit in two upper contexts
  (cidx 30 and 167, 5 each); all other POS
  contexts carry zero.

The side sequence along the family contexts in
index order is not a per-context coin flip: it runs
in stretches — HI [1], LO [14, 18], HI [29, 30, 33,
34], LO [57, 65], HI [85], LO [151, 155],
HI [166, 167, 170, 171], LO [194, 202, 222] — eight
runs over 19 contexts, the two long runs both
upper. Lower shoulder lead values spread over all
three values with 9160 dominant (9144 ×23, 9152
×34, 9160 ×51 of 108); upper values are near-even
(9256 ×48, 9264 ×56 of 104).

Graded MEASURED: pair order, 97xx carriage, context
index and window position do NOT select the shoulder
side; low family dose implies upper (5/5) and upper
implies zero low ladder (10/10); side is constant
over stretches of consecutive family contexts. The
selector itself remains NOT PROVEN.

## The dense split is four groups, not two

Within the 61 window-dense cc9b9d1c negatives, the
9408–9488 dose is bimodal with an empty middle:
high94 = 25 contexts at dose 45–63, low94 = 8 at
dose 1–18 (1, 6, 11, 15, 16, 18 — nothing between
18 and 45), zero94 = 28 at dose 0. (Corpus-wide the
high class is 26 contexts: the 25 dense plus sparse
cidx 139 at dose 62; the sparse low carriers
cidx 38/175 at dose 26 sit in the same 1–39 band
outside DENSE.) Refinements beyond AES-NUM-055:

- High94 contexts are uniformly full: all 25 carry
  exactly 96 windows (DENSE window counts corpus-
  wide are only 96 ×55, 95 ×4, 91 ×2, and none of
  the shortfalls is high94). Their low ladder is
  exactly 0 in 25/25 (AES-NUM-055's mean-0.0 made
  exact). Beyond the defining ladders, high94
  middles are 32784-richer than zero94 (mean count
  196.6 vs 178.2, the largest non-ladder mid-size
  difference) and 32016-richer (85.6 vs 77.9).
- Zero94 splits cleanly in two with NO middle
  group: 16 contexts carry the low ladder at high
  dose (nlow 51–64; top leads are the low ladder
  itself plus the 97xx values), and 12 carry
  essentially none (nlow 0–1). The low-ladder dose
  over zero94 is itself bimodal (0/1 vs 51–64).
- The 12 low-none zero94 contexts are a coherent
  third population hiding inside zero94: their top
  leads are the 9304–9344 segment and the
  8896–8928 segment (neither the low ladder nor
  94xx), every one of them is a maximal 738-action
  context (mean exactly 738), every one speaks
  32016 at the per-context maximum (mean exactly
  96.0), and all 12 are reversed pair order.
  Their 97xx carriage is 10/12 at doses 5–32.
- The 16 low-high zero94 contexts contrast on
  every one of those axes: mean 672 actions, 32016
  mean 64.2, pair order balanced 8/8, 97xx mean
  dose 26.7 with 14/16 carriers.
- 97xx carriage across the split: zero94 24/28,
  high94 15/25 (doses themselves bimodal: ten 0,
  two 7, thirteen 24–32), low94 2/8. Nothing else
  separates the groups: champion count is 29 in
  all 61, band and exclusive doses are 0 in all
  61, network group and channel means are alike,
  and distinct-lead vocabulary is only modestly
  smaller in zero94 (mean 18.4 vs high94 21.8).

Graded MEASURED: the dense negatives are four
populations — high94/no-low (25, full-window,
32784-rich), low94 mixed (8), zero94/low-high (16),
and zero94/low-none (12, a 93xx/89xx-led, maximal,
all-reversed population) — split by ladder dose
alone, with the low ladder's own dose bimodal
inside zero94. No non-ladder feature selects
high94 vs low-high; the low-none group's coherence
is measured on actions, dialect saturation, order
and lead vocabulary jointly.

## The 97xx module is clustered, never one run

The 74 cc9b9d1c carrier contexts (POS 9, DENSE 41,
OTHER 24; no other artifact carries any) were
mapped window by window. The module is NOT one
contiguous run of windows:

- Only 1 of 74 contexts is a single run: OTHER
  cidx 110, whose 32 windows are all 97xx-led
  (its whole window population is the module).
  The other 73 carriers hold 599 runs in total
  (303 runs of length 1, 120 of length 2, and a
  long tail to 32); runs per context average 8.4
  (POS), 9.1 (DENSE), 6.2 (OTHER).
- Adjacent 97xx windows dominate nonetheless:
  window-ordinal gap 1 accounts for 1,529 of
  2,054 adjacencies (74.4%); the median gap is 1
  and the mean 2.34. In mid-action terms the
  median gap is 5 actions. First 97xx window is
  at ordinal 0 in 50/74 carriers; the last is at
  fraction ≥ 0.947 in all 74 (mean 0.99) — the
  module spans the context but clusters.
- The cluster has canonical placements. The
  longest run is ≥ 15 in 41/74 carriers and
  exactly 19–21 in 29. Its start is bimodal:
  ordinal 0 in 18 carriers and ordinal 43 in 13.
  Two run templates repeat exactly: the late
  template [21, 2, 1, 3, 1, 1, 2, 1] in 10 contexts
  (first window at 43, total 32) and the early
  template [21, 2, 1, 1, 1, 1, 1, 2, 1] in 8
  (block at 0, total 31), with one further
  21-at-0 variant — 55 distinct run-tuples over
  74 carriers, the two canonical templates
  covering 18. The canonical templates cross the
  sub-populations (the late template's contexts
  include POS, low-high and low-none members).
- 23 carriers are scattered-type (longest run
  ≤ 7) with no canonical block. Lead values
  inside the module are not ordered: sequences
  are sorted in only 1 of 74 contexts, adjacent
  equal values are 309/2,054 (15%), and the
  pooled value histogram peaks mid-ladder
  (9752 ×255 of 2,128).

Graded MEASURED: the 97xx module is a clustered
population spanning each carrier context — one
canonical ~21-window block (placed at ordinal 0
or 43) plus a scattered tail in the template
carriers, pure scatter in 23 carriers, and a
single all-module context — never a single
contiguous run in any standard context. What
places the block at 0 vs 43 is NOT PROVEN.

## What this closes and what it queues

- MEASURED: shoulder side is selected by none of
  pair order, 97xx carriage, context index or
  window position; low family dose is always
  upper (5/5), upper is always low-ladder-free
  (10/10), and side runs in stretches over the
  family contexts. Selector NOT PROVEN.
- MEASURED: the dense negatives are four ladder-
  dose populations; the zero94/low-none group
  (12) is a coherent 93xx/89xx-led maximal
  population, and the low ladder's dose is
  bimodal inside zero94 with an empty middle.
- MEASURED: the 97xx module is clustered with
  canonical block placements at ordinals 0 and
  43, two exact run templates (10 + 8 contexts),
  and a scattered tail — not a contiguous run.
- NEXT (4.57): the low-none population corpus-
  wide (does the 93xx/89xx form appear outside
  the 12 dense contexts — POS, OTHER, other
  artifacts?); 97xx block placement (0 vs 43 vs
  scatter — what differs in those contexts?);
  shoulder-side stretches vs the contexts
  between family contexts. Host/artifact
  analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
