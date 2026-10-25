# Marker function, pair-order census, anomaly zones, intermediate class (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.45 (AES-NUM-045).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef45.py
(sha256 fa34d22e…) plus the labelled follow-up
hef45b.py (sha256 ade36af1…). Controls: hef45
reproduces AES-NUM-029/032/033/034/035/036/037/038/
039/040/041/042/043/044 EXACTLY (128,787 pooled small
actions; 79,001 pooled 24 B bursts; 745,849 pointer
actions; 1,504 contexts; trailing distinct (channel,
operand) pairs 2,049; champion-headed bursts 75,215;
427 distinct cc9b9d1c segments at 232–464 B); hef45b's
reduced controls also reproduce exactly (79,001
bursts; 1,504 contexts; 427 segments). Both transfers
were sha-gated gzipped 373 B-part crossings; all
whole-file shas verified on-device first try.

## The marker is a pure function of the preceding strict word — and the law is 212/212, not 210/212

AES-NUM-044 recorded the (X+1) marker at word
(words − 3) in 210 of 212 dense-skeleton cc9b9d1c
segments, with two unexplained 296 B exceptions.
Slice 4.45 anatomizes the marker word against its
neighbours, per size class, and resolves the
exceptions.

Against the PRECEDING STRICT word (the last `0100…`
slot word before the marker), the marker's byte-wise
difference is a SINGLE constant pattern per form
class, with zero variation across the whole class:

- Small forms (232/296/312/328/360 B; 208 segments
  in the recount below): difference
  (0, 0, +1, 0, −4, 0, 0, 0) — the marker is its
  predecessor with byte 2 incremented by one and
  byte 4 stepped from 0x50 to 0x4c; every other byte,
  including the tail bytes 5–7, is copied verbatim.
- 464 B form (4 cc9b9d1c segments): difference
  (0, 0, +1, 0, +16, 0, 0, 0) — byte 4 steps from
  0x88 to 0x98, the step AES-NUM-044 recorded. The
  same +16 step holds in the other artifacts' 464 B
  family segments: 0a0d378c (parameter 0x72, seven
  segments, marker `010073009801b000` against
  predecessor `010072008801b000`) and 0856a10c,
  whose marker carries the `0200…` head shape
  (`020047009401b080` against `010046008401b080`:
  byte 2 +1, byte 4 0x84 → 0x94, byte 0 also
  differing 01 → 02 — the only head-byte deviation
  in the family).

Corollaries, all measured: the marker word is
uniquely determined by its preceding strict word
(75 distinct (predecessor, marker) pairs in the
210 class, predecessor → marker injective with zero
violations, and the converse holds); pooled marker
tails (bytes 5–7) take only the values `01f0 00`,
`01f0 80` in the small forms and `01b0/01b1/01b2…`
in the 464 B form, always copied from the
predecessor. The word IMMEDIATELY before the marker
(word words − 4) is not the predecessor in the
small forms — it is the constant `1e00000000000000`
in all 206 small-form marker segments (zero in the
four 464 B segments) — and the word after the
marker is the constant `abba000000000000` in the
small forms (`0100000000000000` in the 464 B form):
the marker sits in a fixed frame. Against X alone
the marker is not quite a function (below).

The two "exceptions" are an artifact of the
AES-NUM-044 definition of X. Both segments (296 B,
sha a0fc07bf… and aed7dd6d…, one occurrence each)
carry a strict skeleton of 20 words whose byte 2 is
0x00 in 19 of them; their dominant NONZERO byte 2 is
0x01, so the old census looked for a 0x02 word and
found none. With X read as the MODAL strict byte 2
(including zero — here X = 0x00), both segments
carry the marker at word (words − 3) = word 34:
`010001004c01f080`, exactly their preceding strict
word `010000005001f080` under the small-form
difference (+1 at byte 2, −4 at byte 4). A full
recount under the modal definition gives:

- 212 of 212 dense-skeleton segments carry exactly
  one (modal + 1) word, always at word (words − 3),
  zero at any other position (232 B 29/29, 296 B
  13/13, 312 B 5/5, 328 B 104/104, 360 B 57/57,
  464 B 4/4); the pooled difference patterns are
  exactly the two above (208 × −4, 4 × +16).
- Modal X takes 72 distinct values (the 71 nonzero
  of AES-NUM-044 plus 0x00). 68 X values own exactly
  one marker word; exactly four own two — and the
  four are precisely the cc9b9d1c parameter family's
  values (0x64, 0x70, 0xb0, 0xf8): each owns its
  small-form marker (byte 4 0x4c, tail `01f000`)
  AND its 464 B marker (byte 4 0x98, tail
  `01b…`). The marker is a function of
  (predecessor word), equivalently of (X, form
  class); it is not a function of X alone, and the
  two-marker split is exactly the form split.

The two modal-0 segments are otherwise a distinct
sub-species, recorded not explained: their strict
words carry `9c01…` tails at even positions 12–28
(byte 2 all zero), words 1–11 are the repeated word
`0000000000000080`, and they share only 4 words with
each of the eleven 296 B marker-class segments.

Graded MEASURED: the (X+1)-at-(words − 3) marker is
universal at 212/212 under the modal-X definition,
and the marker word itself is a closed-form function
of the preceding strict word — copy, byte 2 +1,
byte 4 stepped (−4 in the small forms, +16 in the
464 B form). What X, the byte-4 step, or the marker
encodes remains NOT PROVEN.

## Pair order is a balanced corpus-wide two-state variable at fixed positions — not an anomaly

AES-NUM-044 used "reversed-adjacent" for three
contexts near the outlier. The corpus-wide census
(pair members A = flags 0x4000, B = flags 0x8000,
body champion ordinals) gives:

- normal-adjacent (B = A + 1): 693 contexts;
  reversed-adjacent (A = B + 1): 735; displaced: 76
  (= the displaced population of AES-NUM-034/044);
  missing: 0. Every one of the 1,504 contexts holds
  both pair members.
- Positions are FIXED: normal order sits at
  ordinals (15, 16) in 692 of 693 contexts and
  reversed order at (16, 15) in 733 of 735 — in
  every artifact (per-artifact reversed counts:
  0856a10c 101/256, 0a0d378c 90/180, 5ab3537d
  117/219, 773470cd 122/219, 76c3a8ff 201/353,
  cc9b9d1c 101/271, MiniLM 3/6). The only off-fixed
  positions are the anomaly-zone contexts (below).
- Order correlates with nothing else measured:
  champion count is 29 in both orders (outside the
  anomaly zones), both network groups carry both
  orders, context-index parity is ~even in both,
  and mean action counts differ in INCONSISTENT
  directions across artifacts (cc9b9d1c reversed
  mean 649 vs normal 425; 0a0d378c reversed 444 vs
  normal 695; the sisters ~560–630 both ways).

Graded MEASURED: the 0x2d80 pair's internal order
is a per-context binary variable, roughly balanced
corpus-wide (693/735), realized at one fixed
ordinal pair, carrying no measured correlation with
size, group, parity, or champion composition. What
the bit encodes remains NOT PROVEN. The term
"reversed" is retained only as a label for the
(A after B) state.

## There are TWO anomaly zones in 76c3a8ff, not one — cidx 97–98 mirrors 105–106

The rare-ladder census (ladders 0x2a82 / 0x2a8e in
body champion sequences) finds exactly six contexts
corpus-wide: the sisters' last contexts (5ab3537d
cidx 218: one 0x2a8e burst, champion 30; 773470cd
cidx 218: two, champion 31) and FOUR contexts in
76c3a8ff forming two mirrored zones:

- Zone 1: cidx 97 (400 actions, champion 33) and
  cidx 98 (336 actions, champion 31).
- Zone 2: cidx 105 (400 actions, champion 33) and
  cidx 106 (336 actions, champion 31) — the
  AES-NUM-044 outlier zone.

Corrections to the AES-NUM-044 record, all
measured: cidx 105's rare-ladder doubling is NOT
unique — cidx 97 carries the identical rare operand
SET (four operands: each ladder in two forms,
flags 0x0001 / const 0x02c8 and flags 0x0000 /
const 0x8040); and there are TWO 336-action rare
contexts, not one — cidx 98 (pair reversed-adjacent
at (18, 17), rare pair at ordinals 15–16 in the
single forms, flags 0x0001 / const 0x02cc — the
identical rare operand set as cidx 106) beside
cidx 106 (pair displaced (18, 15), rare pair at
16–17). In both zones the rare block sits
immediately before the pair region: in 97/105 at
ordinals 15–18 with the pair following at 19–20
(normal order in 97, reversed in 105); in 98 the
rare pair precedes a reversed pair at 17–18.

The zones are structural mirrors, not copies:
operand-set symmetric difference between 97 and 105
is 30 (of 33), size-multiset symmetric difference
154; between 98 and 106, 30 (of 31) and 110. Only
the rare operand sets, the action counts (400 /
336), the champion counts (33 / 31), and the
zone shape are shared. The zones sit 8 contexts
apart (97–98, 105–106); no other 76c3a8ff context
carries a rare ladder. Why the rare-ladder bursts
sit in two mirrored zones, and what they encode,
remains NOT PROVEN.

## The intermediate class is exact: 26 contexts at 156 actions on a 9-step train, plus two at 173

AES-NUM-044's "~173-action intermediate class
(28 contexts, 151–185 band)" resolves exactly:

- 26 contexts at EXACTLY 156 actions, at context
  indices 111 + 9k (111, 120, …, 336) in 76c3a8ff;
  preceded by 2 contexts at EXACTLY 173 actions at
  cidx 94 and 102 — the train's head (94, 102, then
  111 + 9k; steps 8, 9, 9, …). All 28 are in
  network group 1, all carry champion count 29,
  the end-anchored trailer (28/28), and the pair in
  reversed order in 27 of 28.
- The 156 class: every context's size sequence is
  distinct (26/26), yet the contexts share only
  TWO distinct champion operand sequences — private
  at the size level, shared at the operand level.
  Anatomy = the standard 12-action head + an
  88-action middle + the identical end block. The
  middle is a 12-fold repeated unit: (82xx, 3856,
  32784, 32784, 30480) ×12 in the exemplar (3856
  ×12, 30480 ×12, 32784 ×24 pooled over the
  middle), a data body the low class lacks.
- The 173 class (cidx 94, 102): same head and end
  block, but a DIFFERENT middle species (105
  actions: 16400 ×24, 32784 ×22, 31120 ×8,
  6928 ×6 in the exemplar) — not the 156 middle
  plus additions: the two middles share almost no
  size vocabulary (the 156 middle's 3856/30480
  repetitions are entirely absent from the 173
  middle). Exemplar symmetric differences: 173 vs
  modal low 98, vs modal standard 684.

Graded MEASURED: 76c3a8ff holds a periodic
intermediate train (indices 94, 102, 111 + 9k)
of skeleton-complete contexts with a real but
reduced data body, in two middle species (156
actions ×26 with a 12-fold repeated middle unit;
173 actions ×2 with a 16400/32784 middle). The
class's program role remains NOT PROVEN.

## What this closes and what it queues

- MEASURED: the marker word is a closed-form
  function of the preceding strict word (copy;
  byte 2 +1; byte 4 −4 small forms / +16 in the
  464 B form), universal at 212/212 dense-skeleton
  segments under modal X (72 values; the four
  two-marker X values are exactly the parameter
  family's, split by form class); the AES-NUM-044
  "exceptions" were a definitional artifact
  (nonzero-dominant X). Pair order is a balanced
  two-state variable (693 normal / 735 reversed /
  76 displaced) at fixed ordinals (15, 16)/(16, 15)
  with no measured correlate. 76c3a8ff holds TWO
  mirrored rare-ladder anomaly zones (97–98 and
  105–106; shared rare operand sets, action counts
  400/336, champion counts 33/31) — correcting
  AES-NUM-044's single-zone record. The
  intermediate class is exact: 156 ×26 at
  111 + 9k plus 173 ×2 at 94/102, two middle
  species, skeleton- and trailer-complete.
- NOT established: what X, the byte-4 step, or the
  marker encodes; what the pair-order bit encodes;
  why the rare ladders sit in two mirrored zones;
  the intermediate class's program role.
- NEXT (4.46): freeze the marker derivation as an
  Aesir-side encoder rule and host-test it against
  all 212 segments (+ the 20 family segments incl.
  the 0856a10c 0200 shape); pair-order determination
  hunt (order vs head-operand identity and vs the
  context's first-middle operands); zone-pair body
  comparison (97 vs 105 and 98 vs 106 outside the
  rare/pair region); the 156 middle unit's segment
  anatomy (the 12-fold unit's distinct segments).
  Host/artifact analysis only.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
