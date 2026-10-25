# The 22 zero pairs have almost no same-offset counterparts, the block's per-segment head values are one constant per segment per family, and the middles' positional law holds for every byte pair (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.99 (AES-NUM-099).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef99.py
(sha256 9b87f53db1a34f41b3bef561291bfd9374d78a3f74f0670612df47ef4fbd7e0f —
the sha-verified hef98.py lineage with the 4.99 arms
appended; arms file hef99_arms.py sha256
09237a150e3da08c13796f0ee8b4f4e245346c30a377ef661bbeb1406c028df7;
combined script sha verified on-device). Contract
docs/TASK_CONTRACT_4.99.md published @ a2da97bc before
implementation. Output: /tmp/hef99_out.txt sha256
02bd57b85cb18020ebc32e9c4f3c2a19dc9704e25626f64207a431a23be70097
(274,395 B, 2,391 lines, DONE99 reached, EXIT 0); the
4.99 sections are also extracted on-device as
/tmp/hef99_s99.txt sha256
5c73e4e8d77250800fc0591b6f031cbade8837b816b0b7dbbe637431414945de
(50,971 B, 316 lines).
Controls reproduce AES-NUM-029/032...098 EXACTLY
(128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts;
trailing distinct (channel, operand) pairs 2,049;
champion-headed bursts 75,215), the scanner re-derives
AES-NUM-090/091 exactly (in-band 374 groups, OTHER 4
all STEP; band X 60 / 3,335, OTHER 0; band Y 27 / 354,
OTHER 0; S1 OTHER 16, S2b OTHER 10, all non-step),
the 26 non-step OTHER offsets re-derive with per-ng
CONST 14 and combined per-ng coverage 19, residue
exactly 7, trains reproduce exactly (52 trains;
unique-first 28, unanimous 13, elsewhere 11;
D(cidx 113) = 249; firsts' D-positions 3,089;
control-arm D-positions 176), camps reproduce
(A 21392 x13, B 21648 x12), the rank-2 middles
reproduce (21 aligned mismatches at k = 111, 4 shared
distinct units at indices 1–4), and the
AES-NUM-095/096/097/098 headline counts reproduce
exactly (whole-arm candidates 7,690; SPARSE zero
144/2,280, DENSE zero 64/2,898, MID zero 21/2,306;
F = 144 with masks {10011: 108, 11011: 30, 01011: 6};
mask table 01011 1,088/6, 10011 549/108, 11011 348/30,
11001 61/0, 11010 234/0; region 0 = 2,056 aligned
words / 02-count 150 / distinct 104 per camp; six-pair
totals s = 0: 28 and s = +64: 44; 20>3e at exactly 21
shifts, x8 at +31; a9>3e at exactly shifts -16, +64;
per-offset determinism with 22 zero (mask, offset)
pairs; block 26 units x 7 words, 3 unit patterns per
camp, 110/182 unanimous block offsets; 20>3e
positional prediction exact at all 257 shifts).

## (i) The 22 zero pairs' neighbourhoods vs same-offset counterparts

The re-collection WITH full neighbourhood words
matches the hef98 `sn` population exactly (same
2,280 candidates, same (group, offset, cidx, mask,
value) multiset), so this arm is credited. The 22
zero (mask, offset) pairs re-derive exactly:
01011 at 6180, 7632, 18744, 26104; 10011 at 10824,
26040, 26184, 26944, 27408, 27496, 27520, 27552,
28016, 28768, 29336, 30136, 30168, 30704, 31248,
31536; 11011 at 28964, 29156.

Zero-candidate counts per pair: 01011 carries
1 + 1 + 2 + 2 = 6 (6180 in 0856a10c pos 9; 7632 in
MiniLM pos 23; 18744 in both 0a0d378c pos 20 groups;
26104 in both sister pos 21 groups). 10011 carries
108: five offsets x15, all in the two 0856a10c
groups pos 9 + pos 10 (10824, 27520, 28016, 29336,
30704); three offsets x7 in the sister 32608 groups
(26944, 27496, 31248); four offsets x2 and four x1
in 5ab3537d pos 8 (26040, 27408, 30168, 31536 x2;
26184, 27552, 28768, 30136 x1). 11011 carries
15 + 15 = 30, only at 28964 / 29156 in the two
0856a10c groups. In every pair, all of its zero
candidates are genuinely zero (nonzero-among-them
0), and every pair's zero side carries exactly ONE
distinct full neighbourhood word-tuple (22 pairs,
22 single-tuple sides) — each zero pair's
neighbourhood is a single rigid template, e.g.
01011 @ 6180: (08000000, 00000000, ff000000,
00000000, 00000000); 01011 @ 18744 and @ 26104
share the tuple (01000101, 00000000, ff000000,
00000000, 00000000) across different groups.

**The counterpart class is nearly empty.** Across
all 22 pairs there are exactly TWO same-offset
other-mask candidates in the whole 2,280-candidate
population: at 7632 one candidate of mask 11011
(non-zero), and at 28768 one candidate of mask
11011 (non-zero). The other 20 pairs have NO
counterpart at all. Aggregate: total counterpart
candidates 2, counterpart zeros 0; zero pairs with
>= 1 counterpart 2/22, with >= 1 counterpart zero
0/22, with >= 1 identical-tuple counterpart 0/22.
Pooled per-position value-set overlaps (shared,
zero-only, counterpart-only), summed over pairs:
pos 0 (rel -8): (1, 21, 1); pos 1 (rel -4):
(1, 21, 1); pos 2 (rel +0): (0, 22, 2); pos 3
(rel +4): (2, 20, 0); pos 4 (rel +8): (2, 20, 0).

So no separating neighbourhood law is credited:
there is essentially nothing on the other side to
separate from. The measured fact is stronger than
a feature law would have been — at a zero pair's
offset, candidates of any other mask essentially
never occur (2 counterparts against 144 zero
candidates, both non-zero, both wearing mask
11011). Zero-hood at these offsets is not merely
(mask, offset)-deterministic (AES-NUM-098); the
offsets themselves are mask-exclusive in this
population. What selects the 22 pairs, and why
other masks do not present at their offsets,
remains NOT PROVEN.

## (ii) Block per-segment head values as a population

Region 0 re-derived per camp (0..8224); the block
is the aligned span 6184..6912, families 0 / 1 / 2
= units 0–7 / 8–16 / 17–25, head positions = word
positions 0..3 of each unit (32 values per segment
in family 0, 36 in each of families 1 and 2).
Camp A segments (13, cidx 130, 139, 148, 157, 202,
211, 220, 238, 247, 256, 265, 319, 328); camp B
segments (12, cidx 121, 166, 175, 184, 193, 229,
274, 283, 292, 301, 310, 337).

**Every (segment, family) head population is a
single constant.** All 75 (camp, segment, family)
cells are constant across every one of their
slots (constant True 75/75): a segment carries ONE
head word per family, repeated at all 32 / 36 /
36 head slots.

- Family 0: the constant is ffffff7f in all 25
  segments of both camps — family-0 deviations
  from ffffff7f: 0. Cross-camp family-0 value set
  intersection = {ffffff7f}.
- Family 1: camp A carries 13 distinct values,
  one per segment, NONE shared by >= 2 segments;
  low-3-byte patterns are a20000 (11 segments) and
  a30000 (2). In segment order the values are
  3fa20000, 7da20000, 56a20000, e0a20000,
  16a30000, 65a20000, 7ba20000, 48a20000,
  83a20000, a0a20000, 82a20000, 6ea30000,
  31a20000 — the per-segment variation is the
  first byte only. Camp B carries 12 distinct
  values, none shared; low-3 patterns a20000 (9)
  and b30000 (3): dab30000, 78a20000, f3a20000,
  cca20000, 43a20000, e1a20000, cdb30000,
  50a20000, 94a20000, 75b30000, efa20000,
  4aa20000. (This also resolves the AES-NUM-098
  mode-tie artefact concretely: the camp-A
  consensus word 3fa20000 is simply segment
  cidx 130's own value, the first segment in the
  camp's sorted order.)
- Family 2: camp A carries 13 distinct values,
  none shared, and all 13 low-3 patterns distinct
  (010200, 020200, 040200, 060200, 0a0200,
  0c0200, 0d0200, 2a0200, ce0100, e80100, f10100,
  fc0100, fe0100): a0ce0100, c82a0200, 88040200,
  f8020200, 500d0200, 500c0200, 58f10100,
  d8060200, 28fe0100, 30010200, a8fc0100,
  300a0200, 00e80100 — here the first TWO bytes
  vary per segment over a ??xx0{1,2}00 skeleton.
  Camp B carries 12 distinct values, none shared
  as full words; 11 distinct low-3 patterns
  (020200 is the low-3 pattern of two segments,
  whose full words 00020200 and 40020200 differ
  in the first byte): f0fa0100, 00020200,
  a0050200, 20e20100, 70fb0100, 40020200,
  802b0200, 68ec0100, 48f60100, b80a0200,
  d0ff0100, 68fc0100.

Cross-family / cross-camp structure is empty
where it could have coupled the families: in
every one of the 25 segments, the family-1 and
family-2 value sets share NO full word and NO
low-3-byte pattern (per-segment intersections
0/25 for both measures; pooled per camp likewise
empty). Across camps, the family-1 value sets are
disjoint (13 A vs 12 B, intersection empty) and
the family-2 value sets are disjoint (13 vs 12,
intersection empty). So the per-segment head
values form a clean injective labelling: 25
segments x 2 varying families, every label used
exactly once, no label reused across segments,
families, or camps. What the labels encode — any
function of segment identity, cidx, or another
family's value — is NOT PROVEN: no exact stated
law was tested and passed, and none is claimed.

## (iii) Positional-law test for the middles' other byte pairs

The AES-NUM-098 result for the single pair
(0x20, 0x3e) generalises to the whole middle
vocabulary. Pooled over the four grown ranks
(2, 8, 22, 26), the A middles carry 24 distinct
byte values and the B middles 28. Position lists
are identical across all four ranks for 18/24
A-side bytes and 22/28 B-side bytes; the
differing bytes are the same six on both sides —
0x00 and 0x80 (position 7 present only at ranks
2 and 26), 0x85 (present only at rank 22, pos 6),
0x87 (present only at rank 2, pos 6), 0x89
(extra pos 6 at rank 8), 0x8b (present only at
rank 26, pos 6).

Direct census over all (i, j) with j - i in
-128..+128, pooled over the four ranks: 602
ordered byte pairs carry >= 1 in-range tally;
total in-range tallies 131,360. Prediction from
the per-rank position sets posA(x), posB(y):

**predicted == census at EVERY (x, y, s) —
differing triples 0.** The positional law is
therefore credited for the middles as a whole:
every ordered byte pair's lag census factors
exactly through the two middles' byte-position
sets, with no alignment-specific content anywhere
in the vocabulary. Position pairs whose shift
falls outside -128..+128 total 24,544 over 269
ordered pairs (accounted, not hidden).

The six AES-NUM-096 copy-span substitution pairs,
individually: all six are predicted-equal True.
(0x20, 0x3e): the 21-shift set of AES-NUM-097/098
(x4, x8 at +31), out-of-range 0. (0xa9, 0x3e):
exactly {-16: 4, +64: 4}, out-of-range 0.
(0x02, 0x00): 168 in-range shifts, 167 of them x4
and one x2 (at -118), out-of-range 0. (0x80, 0x00):
all 257 shifts present, out-of-range 638.
(0x00, 0x10): 202 in-range shifts, out-of-range
304. (0x00, 0x20): 203 in-range shifts,
out-of-range 1,562. No pair is distinguished by
the census: the two alignments' copy spans carry
no pair-specific lag signature beyond position
arithmetic.

## Grades

- (i) Zero-pair neighbourhoods vs counterparts:
  re-collection ESTABLISHED exact; the counterpart
  population is measured at 2 candidates total
  (both non-zero, mask 11011), so no separating
  neighbourhood law is credited and none exists
  to find in this population — the offsets are
  mask-exclusive as measured. The mechanism
  selecting the 22 pairs: NOT PROVEN.
- (ii) Per-segment head values: ESTABLISHED —
  one constant head word per (segment, family)
  in all 75 cells; family 0 = ffffff7f everywhere
  (0 deviations); families 1 and 2 are injective
  per-segment labels, disjoint across segments,
  families, and camps. What the labels encode:
  NOT PROVEN.
- (iii) Positional law for the middles:
  ESTABLISHED for all ordered byte pairs —
  predicted == census with 0 differing triples
  over 602 pairs and 131,360 tallies; all six
  copy-span pairs individually exact.

NEXT: slice 4.100 — the 22 zero offsets across
ALL forms (DENSE/MID candidates at the same
offsets: is mask-exclusivity a form-exclusivity?);
the family-1/family-2 label values vs segment
metadata (cidx order, camp-internal rank, ng
position — a stated-function hunt); the positional
law on the ungrown ranks and the reverse (B, A)
direction. Host/artifact analysis only — no
physical child.
