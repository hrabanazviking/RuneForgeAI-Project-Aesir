# Sparse zeros are per-offset deterministic, the region-0 data block is three unit families whose x36 words are per-segment values, and the 20>3e shift set is exactly positional (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.98 (AES-NUM-098).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef98.py
(sha256 5591058425b60400753677157afa978ff35460709ba9c7283e0fbff82a29b961 —
the sha-verified hef97.py lineage with the 4.98 arms
appended; arms file hef98_arms.py sha256
c611b065bc3fac6878d1c04d54cef2e420f25db18b73cabab752a79ebfaec913,
landed via sha-gated chunked file.write transfer, gz
sha256 232e20bd462b923a5f1c00894a93e4199b40d73cee60f76d92161e79e7ab8710
verified on-device; combined script sha verified
on-device and compiled). Output: /tmp/hef98_out.txt
sha256 6bdd205802eaf42874a76cbbc65580daa93d2531b63009709da7f79659954c76
(223,424 B, 2,075 lines, DONE98 reached).
Controls reproduce AES-NUM-029/032...097 EXACTLY
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
reproduce AES-NUM-094/095/096 (21 aligned mismatches
at k = 111, 4 shared distinct units at indices 1–4),
and the AES-NUM-095/096/097 headline counts reproduce
exactly (whole-arm candidates 7,690; SPARSE zero
144/2,280, DENSE zero 64/2,898, MID zero 21/2,306;
F = 144 with masks {10011: 108, 11011: 30, 01011: 6};
mask table 01011 1,088/6, 10011 549/108, 11011 348/30,
11001 61/0, 11010 234/0; region 0 = 2,056 aligned
words / 02-count 150 / distinct 104 per camp; six-pair
totals s = 0: 28 and s = +64: 44; 20>3e at exactly 21
shifts, x8 at +31; a9>3e at exactly shifts -16, +64).

## (i) Per-mask x group/offset anatomy of the sparse zeros

The mask totals reproduce the contract exactly
(2,280 candidates, 144 zeros). The headline is a law
the coarser views could not see:

**Per-offset determinism (EXACT in this population).**
For every mask, every offset is either all-zero or
never-zero among that mask's candidates — there is
NO partial offset in any of the five masks
(01011: 4 all-zero offsets of 289; 10011: 16 of 119;
11011: 2 of 154; 11001: 0 of 24; 11010: 0 of 73).
A sparse candidate's value is zero exactly when its
(mask, offset) is one of the 22 zero (mask, offset)
pairs; the three zero-bearing masks' zero offsets are
pairwise disjoint (cross-mask shared zero offsets 0,
shared zero (group, offset) pairs 0 for all three
mask pairs), so zero-hood here is a function of
(mask, offset), not of the group: per-GROUP tables
ARE partial (10011 zeros split inside 6 groups,
11011 inside 2, 01011 inside 6).

Per mask:
- 10011 (108 zeros): 6 groups, 16 offsets, 27
  (group, offset) pairs. The two 0856a10c groups
  carry 75/108 (69.4%): pos 9 30/95 candidates
  (31.6%), pos 10 45/171 (26.3%). The sister pair
  5ab3537d pos 8 / 773470cd pos 14+15 carries the
  rest at the same offsets (26944, 27496, 31248
  shared verbatim across the three 32608 groups).
  Five offsets (10824, 27520, 28016, 29336, 30704)
  occur only in the two 0856a10c groups, x15 each.
- 11011 (30 zeros): ONLY the two 0856a10c groups
  (pos 9 12/34 = 35.3%, pos 10 18/81 = 22.2%), ONLY
  offsets 28964 and 29156, 4 (group, offset) pairs;
  the pos9+pos10 share is 30/30 = 100%.
- 01011 (6 zeros): 6 groups, 4 offsets (6180, 7632,
  18744, 26104), 6 pairs, one zero each; pos9+pos10
  share only 1/6.
- 11001 / 11010: no zeros anywhere (61 / 234
  candidates, 13 / 15 groups).
F's overall pos9+pos10 share re-derives: 75 + 30 + 1
= 106/144, exactly AES-NUM-096. What makes the 22
(mask, offset) pairs the zero pairs is NOT PROVEN.

## (ii) Region-0 36-occurrence data-block anatomy

The block (consensus camps, aligned 6184..6912,
182 words = 26 units of 7) has exactly 5 distinct
consensus words per camp: 00000000 x51, ffffff7f x32,
00020000 x27, and the camp's two x36 words (A:
3fa20000 at 6408..6644, 50ce0200 at 6660..6896; B:
daa20000, 68020100 at the same offsets). Unit
decomposition is rigid — exactly 3 distinct unit
patterns per camp: units 0–7 = [x36-class word x4,
00000000 x3] with ffffff7f in the head slots, units
8–16 = [first x36 word x4, 00020000 x3], units
17–25 = [second x36 word x4, 00000000 x3].
Per word-position: positions 0–3 carry exactly the
3 head values (8/9/9 units), positions 4–6 carry
00020000 in the 9 middle units and 00000000 in the
other 17. Named populations: ffffff7f gaps
{4: 24, 16: 7}, span 212; 00020000 gaps {4: 18,
20: 8}, span 236; both x36 words gaps {4: 27, 16: 8},
span 240.

**The x36 "consensus" words are not segment words.**
Per-segment unanimity over the 182 block offsets:
110 offsets are unanimous (the ffffff7f / 00000000 /
00020000 positions); the 72 x36 offsets are
non-unanimous in BOTH camps. At those offsets every
individual segment carries a DIFFERENT word, all
sharing the low bytes (A first population: words
??a20000/??a30000, one per segment; A second:
????0200 with low byte 00/01/02 varying; B likewise
??a20000/??b30000 and ????0100/????0200). The
consensus count for the modal word is 1 of 13 in
camp A (0 of 12 in camp B for its second population;
B's first population also 0) — the x36 words of
AES-NUM-097 are mode-tie artefacts of a per-segment
varying field whose shared part is the low 3 bytes
(A: a20000/a30000 then ce0200-class; B: a20000 then
020100-class). What the per-segment values encode
is NOT PROVEN; the block's unit skeleton (26 x 7,
three families, rigid positions) is exact.

## (iii) The 20>3e shift set

**The positional prediction is EXACT.** Per grown
rank (2, 8, 22, 26 — identical at every rank), the
A middle carries byte 0x20 at 11 positions
[72, 88, 94, 103, 104, 110, 120, 136, 142, 152, 158]
and the B middle carries byte 0x3e at exactly 2
positions [103, 183]. Pooled: 44 A-positions,
8 B-positions, 88 triples; the predicted shift
multiset equals the re-derived census count at ALL
257 shifts (differing shifts 0), no triple falls
outside -128..+128, and the predicted positive set
is exactly AES-NUM-097's 21 shifts (x4 each, x8 at
+31). The (20,3e) lag census is therefore a pure
positional consequence of the two position sets —
no alignment-specific content.

**The +31 doubling is a repeated pair.** Per rank,
shift +31 receives TWO triples, (72, 103) and
(152, 183): the (0x20, 0x3e) pair occurs twice in
each middle at a constant internal spacing of 80
(152 - 72 = 80, 183 - 103 = 80), so both an extra
A position and an extra B position contribute —
the doubling is the pair's own repetition, counted
once per rank x 4 ranks = 8.

## Grades

- (i) Per-offset determinism of sparse zeros:
  ESTABLISHED empirically, exact over all 2,280
  candidates (22 zero (mask, offset) pairs, no
  partial offset in any mask). The mechanism
  selecting the 22 pairs: NOT PROVEN.
- (ii) Block unit skeleton (26 units x 7 words,
  3 families, rigid per-position classes):
  ESTABLISHED on both consensus camps. The x36
  words as segment content: REFUTED — they are
  per-segment varying fields; only their low-byte
  skeleton is shared. Their meaning: NOT PROVEN.
- (iii) 20>3e shift-set positional law: ESTABLISHED,
  exact at all 257 shifts; +31 doubling explained
  by the pair's 80-spaced repetition per middle.

NEXT: slice 4.99 — the 22 zero (mask, offset) pairs'
neighbourhoods vs their non-zero same-offset
counterparts in other masks; the block's per-segment
head values as a population (low-byte skeleton x
segment); the middles' other byte pairs under the
positional law (does every pair's census factor
through its position sets?). Host/artifact analysis
only — no physical child.
