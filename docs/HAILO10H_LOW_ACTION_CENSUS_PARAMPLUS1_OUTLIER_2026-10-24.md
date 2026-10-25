# Low-action context census, parameter+1 slot census, 336-action outlier anatomy (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.44 (AES-NUM-044).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef44.py
(sha256 ab4fc723…) plus the labelled follow-up
hef44b.py (sha256 dec70d70…). Controls: hef44
reproduces AES-NUM-029/032/033/034/035/036/037/038/
039/040/041/042/043 EXACTLY (128,787 pooled small
actions; 79,001 pooled 24 B bursts; 745,849 pointer
actions; 1,504 contexts; trailing distinct (channel,
operand) pairs 2,049; champion-headed bursts 75,215);
hef44b's reduced controls also reproduce exactly
(79,001 bursts; 1,504 contexts; 427 distinct cc9b9d1c
segments at 232–464 B). Both transfers were sha-gated
gzipped 373 B-part crossings; one hef44b part corrupted
in re-emission was rejected by the base64 schema and a
verbatim retry landed clean; all whole-file shas
verified on-device.

## The low-action class is a clean corpus-wide class: 79 contexts at ≤150 actions, separated by empty gaps

AES-NUM-043 left the displaced contexts resolved as a
low-action TYPE without a corpus-wide census of the
class itself. Slice 4.44 counts every context by total
pointer actions, per artifact:

- 0856a10c (256 contexts): exactly 2 low — cidx 99
  (85 actions, displaced; the artifact's single
  displaced context) and cidx 255 (91, pair ADJACENT,
  the artifact's last context). The next-smallest
  context is 206: an empty gap of 115. Standard
  contexts carry a mean of 432.9 large (>512 B)
  actions against the low pair's 9.0.
- 0a0d378c (180): exactly 18 low, ALL displaced —
  cidx 73 (85), 75 (123), 81 + 6k through 165 (123
  each, 15 contexts), and 179 (92, the last context).
  The next-smallest context is 280: an empty gap of
  157, the cleanest bimodal split in the corpus.
- 5ab3537d (219): exactly 1 low — cidx 218 (93,
  displaced, the last context; body champion count
  30). Next-smallest 232 (gap 139).
- 773470cd (219): exactly 1 low — cidx 218 (93,
  displaced, the last context; body champion count
  31). Next-smallest 232 (gap 139). The sisters'
  censuses are identical in shape; their low
  contexts differ in champion count (30 vs 31).
- 76c3a8ff (353): exactly 57 low — 85 ×2 (cidx 91
  and 351, both displaced, pattern (12,14)), 89 ×52
  (all displaced), 91 ×1 (cidx 352, adjacent, the
  last context), 132 ×2 (cidx 100 and 108, both
  adjacent). The displaced low contexts run in a
  pair train from cidx 110: context pairs 2 apart,
  pairs 9 apart — (110, 112), (119, 121), …,
  (335, 337) — the first member carrying pattern
  (12,16) (25 contexts; the train's very first, cidx
  110, carries (16,10) instead) and the second
  always (16,14) (26 contexts). 76c3a8ff ALONE also
  holds an intermediate class: 28 contexts at ~173
  actions (151–185 band), pair-adjacent, below its
  232–279 band (52 contexts).
- MiniLM (6 contexts, 251–279 actions) and
  cc9b9d1c (271, minimum 186) hold NO low contexts
  and no displaced contexts.

Class arithmetic closes exactly: 79 low contexts =
75 displaced-low (every displaced context except the
336-action outlier) + 4 adjacent-low (0856a10c cidx
255; 76c3a8ff cidx 100, 108, 352 — the four small
adjacent contexts of AES-NUM-043). Every low context
in 0856a10c / 0a0d378c / 76c3a8ff carries the
standard body champion count 29 (the sisters' single
low contexts carry 30 / 31 against their standard
29), and every low context carries the end-anchored
trailer (79 / 79).

Exemplar anatomy (first low context per artifact
against the artifact's modal standard size sequence):
every low exemplar is the standard skeleton with the
data body removed — a burst-run head (common prefix
8–13 actions: the 24 B run plus the 304 B triple
where present), a SHORT private middle (0856a10c /
0a0d378c: repeated 9144/184 units; the sisters:
528/80 units, permuted between them; 76c3a8ff: a
528/80 + large-single mix), and the IDENTICAL
56-action end block (common suffix 56 against the
modal standard in four artifacts, 55 in 773470cd).
Total: 85 = ~13 head + ~16 middle + 56 end in the
smallest exemplars. Size-multiset symmetric
difference against the modal standard is 162–668,
essentially all of it missing large actions (low
large-action means 9.0–40.1 against standard
343.1–503.6).

Graded MEASURED: the low-action class is definable
corpus-wide by the single threshold ≤150 actions
(the threshold sits inside an empty gap in every
artifact that holds the class); its members are
periodically placed (0a0d378c 81 + 6k; 76c3a8ff the
(2, 9) pair train; the sisters + 0856a10c at stream
ends / the displaced index), carry the full champion
skeleton and trailer, and differ from standard
contexts only by a nearly-removed data body. What
program role the class holds remains NOT PROVEN.

## The parameter+1 marker is universal: exactly one (X+1) word at word (words − 3) in every skeleton segment

AES-NUM-043 found a `0100<param+1>00…` word in both
vocabularies of the cc9b9d1c parameter family. Slice
4.44 censuses the strict word family (bytes
`01 00 <b2> 00`) over every distinct segment of the
family forms, then over ALL distinct cc9b9d1c
segments at 232–464 B:

The twenty family segments (cc9b9d1c 12, 0a0d378c 7,
0856a10c 1):

- cc9b9d1c small forms (8 segments): exactly ONE
  strict parameter+1 word each, always at word
  (words − 3) — 232 B: word 26; 296 B: 34; 312 B:
  36; 328 B: 38; 360 B: 42. The strict parameter
  words sit at the even positions 12…(words − 5);
  the +1 word is the first strict slot after the
  parameter run. Strict totals by size: 12 / 20 /
  22 / 24 / 28 (byte-2 distribution {00: 4–12,
  param: 7–15, param+1: 1}).
- cc9b9d1c 464 B (4 segments): strict 15 =
  {00: 4, param: 10, param+1: 1}; parameter at
  strict positions [17, 33, 35, 39, 43, 45, 47, 49,
  51, 53], the +1 word at word 55 = words − 3.
  Word 55 is `0100<p+1>009801b…` against word 53's
  `0100<p>008801b…` — the marker word differs from
  its predecessor in byte 2 (+1) AND byte 4
  (0x88 → 0x98).
- 0a0d378c 464 B (7 distinct segments, one
  occurrence each): the identical structure with
  the fixed parameter 0x72 — strict 14 =
  {00: 3, 0x72: 10, 0x73: 1}, +1 at word 55,
  word 55 `010073009801b000`.
- 0856a10c 464 B (1 segment): strict 16 =
  {00: 4, 0x46: 12} at positions [15, 17, 21, 33,
  35, 39, 43, 45, 47, 49, 51, 53] — NO strict +1
  word. But its word 55 is `020047009401b080`:
  byte 2 = 0x47 = parameter + 1 in the `0200…`
  word shape, and byte 4 = 0x94 against word 53's
  0x84 — the same +0x10 byte-4 step as the other
  artifacts' marker words. The +1 marker at
  words − 3 exists in all twenty family segments;
  only its word shape differs in 0856a10c.

The general census (hef44b, all 427 distinct
cc9b9d1c segments at 232–464 B) shows the family is
one instance of a corpus-wide construction:

- 210 segments carry exactly ONE strict (X+1)
  word, ALWAYS at word (words − 3) — zero at any
  other position, zero with more than one. X (the
  segment's dominant nonzero strict byte 2) takes
  71 distinct values in this class; the parameter
  family's four values are merely its instances in
  the dense-parameter segments.
- 212 segments carry a strict skeleton of ≥10
  words: the 210 above plus exactly 2 exceptions
  (296 B) whose dominant X has NO (X+1) word.
- 215 segments (all 328 B) carry only sparse
  all-zero-byte-2 strict words (1–2 words) — a
  different species sharing the size class.
- By size, the marker class is exhaustive where
  the skeleton is dense: 232 B 29/29, 312 B 5/5,
  360 B 57/57, 464 B 4/4, 296 B 11/13, 328 B 104
  (plus the 215 sparse).

Graded MEASURED: the (X+1)-at-(words − 3) marker
is a universal feature of the `0100…` skeleton
construction across the corpus's structured forms,
not a parameter-family peculiarity: one marker word
per segment, at a fixed position, its byte 2 one
above the segment's dominant byte-2 value, its
byte 4 stepped +0x10 against the preceding slot
word in the 464 B forms. What X, or the marker,
encodes remains NOT PROVEN; the two 296 B
exceptions are recorded, not explained.

## The 336-action outlier is a standard context whose pair straddles the rare-ladder pair — a local anomaly at cidx 105–106, not the periodic class

The outlier is unique (76c3a8ff cidx 106, ng 1,
pattern (18,15)) and is NOT a low-action context:
336 actions (rank 224 of 353 in its artifact), 258
large actions, 50 distinct sizes, trailer present,
tail symmetric difference 2 against every neighbour
(the standard tail). Its body champion count is 31
— the standard 29 plus the two rare-ladder bursts,
both champion-headed.

Its pair region, champion ordinals 13–20, reads:
ord 13 ladder 0x16f0; ord 14 ladder 0x18f0; ord 15
= the pair's flags-0x8000 member (ladder 0x2d80);
ord 16 ladder 0x2a82 (flags 0x0001, enum 0, const
0x02cc); ord 17 ladder 0x2a8e (same fields); ord 18
= the flags-0x4000 member (ladder 0x2d80); ords
19–20 the 0x2a00 singletons. The displacement is
exactly the pair straddling the rare-ladder pair:
the 0x4000 member is pushed from its adjacent
ordinal to 18 by the two inserted rare bursts,
whose const field (0x02cc) breaks the pair region's
otherwise-uniform 0x0250.

The neighbourhood is itself anomalous, in a way
the low-action class is not: cidx 105 (400 actions)
is REVERSED-adjacent (pair at (20,19)), carries
champion count 33 and the rare ladders TWICE each
(0x2a82 ×2, 0x2a8e ×2 — the only other context in
the artifact that carries them at all), plus 2
non-champion bursts; cidx 107 (294) is also
reversed-adjacent ((16,15)); cidx 104 (435) and
108 (132, a low adjacent context) are standard-
ordered. Against all four neighbours the outlier's
head multiset is fully private (symmetric
difference 20 — no shared head operand), its size
multiset differs by 100–571, and its common suffix
is 56–58 (the standard end block). Only one other
76c3a8ff context shares its tail multiset.

Graded MEASURED: the outlier's displacement has a
different mechanism from the periodic low-action
class — a full-size context, at a non-periodic
index, whose pair is separated by the rare-ladder
pair, inside a two-context anomaly zone (105–106)
where reversed pair order and doubled rare ladders
also occur. Why the rare-ladder bursts sit there,
and what they encode, remains NOT PROVEN.

## What this closes and what it queues

- MEASURED, corpus-wide: the low-action class is
  79 contexts at ≤150 actions (75 displaced + 4
  adjacent), separated from standard contexts by
  empty gaps of 115–157 in every artifact holding
  it, periodically placed, skeleton- and trailer-
  complete, differing only by a nearly-removed
  data body; 76c3a8ff alone holds an additional
  ~173-action intermediate class (28 contexts).
  The (X+1) marker word at (words − 3) is
  universal across the `0100…` skeleton
  construction (210/212 dense-skeleton cc9b9d1c
  segments, all 20 family segments incl. the
  0856a10c shape variant; 71 distinct X values).
  The 336-action outlier is a standard context
  whose pair straddles the rare-ladder pair in a
  local anomaly zone at 76c3a8ff cidx 105–106.
- NOT established: the low-action class's program
  role; what X or the marker encodes; the two
  296 B marker exceptions; why the rare-ladder
  pair sits at 105–106.
- NEXT (4.45): marker-word anatomy across the 210
  class (byte-4 step and tail fields vs the
  preceding slot word, per size); the two 296 B
  exceptions' anatomy; reversed-adjacent pair
  census corpus-wide (pair order (pA, pA−1)) and
  the cidx 105 anomaly (champion count 33, rare
  ladders doubled); the 76c3a8ff ~173-action
  intermediate class anatomy. Host/artifact
  analysis only.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
