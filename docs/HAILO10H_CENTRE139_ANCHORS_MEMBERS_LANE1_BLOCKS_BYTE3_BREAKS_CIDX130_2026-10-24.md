# Centre 139 read in full, anchors 7/11/95 read as sequence members, lane 1 split the other way, the two 2-act breaks read against the corpus, and cidx 130 read against cidx 267: centre 139's two 28-occurrence cells are ONE cell held identically by both mirror artifacts — the same (pos, size, off) key (21, 30768, 15368), the same 28 cidxs, the same single word in all 28 rows — and that cell is 139's single non-divergent triple, its only presence in the mirror pair; its other 77 cells are DISTINCT cells in two artifacts only, carrying just six further cidx tuples, with 139 always the LAST centre in 0856a10c (42/42) and always an interior centre after 130 in 76c3a8ff (35/35); read as members of their mid/thick divergent hosts, the constant-like anchors obey the varying centres' law — pooled over non-unanimous hosts they sit at start 50 / interior 125 / END 0, every local step already in the host's step set — with 7 always at start, 11 always at index 0 or 1, and 95 always interior after 91; lane 1's wide group (20, 32720) splits into eight offset blocks of 27 pairs that are pairwise DISJOINT in every projection (pair, A, B, diff and XOR intersections all 0 over all 28 block pairs; the pooled 216 are distinct in every projection) and no additive or XOR translate maps any block onto another, while the narrow group (14, 9992)'s five repeated pairs — and (19, 7712)'s three pairs — are pure SIGN FLIPS: every pair has XOR 0x80000000 and per-byte difference (0, 0, 0, ∓128), the two distinct diffs being exactly −2^31 (four pairs) and +2^31 (one pair); byte 3's difference is NOT determined by (A's byte 3, group) — group adds nothing (the same 35 violating values, 192 pairs, all inside group (20, 32720); the two narrow groups are internally determined only because each carries just two byte-3 values with sign-flip diffs) — nor by byte 3 with any single low byte (byte 1 leaves exactly 2 violating keys / 4 pairs, byte 2 exactly 1 violating key / 2 pairs), and the low three bytes jointly "determine" it only by identifying each of the 224 pairs uniquely (224 keys for 224 pairs, the same vacuity as the full-A bijection); the region's two 2-act breaks are breaks of the 144↔267 alignment only: all eight break acts occur solely in cc9b9d1c, the 267-side pairs occur as adjacent pairs in exactly 4 contexts {114, 130, 251, 267} always at positions 792–793 and 801–802 with identical neighbours, the 144-side pairs in exactly 27 contexts {140, 144, …, 244} always at 195–196 and 204–205, reversed pairs occur NOWHERE (0), and cidx 130 — the same length as 267 (842 acts, all distinct) with a near-identical occurrence profile (709 corpus-unique, 50 acts at count ≥4, max 1,060, mean 14.7067 against 267's 14.8824) — shares 111 acts with 267 in IDENTICAL relative order (0 inversions in 6,105 pairs) arranged in 19 shared runs, the longest a 31-act run at identical positions 787–817 in both sequences that CONTAINS both 267-side break pairs (AES-NUM-123)

Slice 4.123, worked under `docs/TASK_CONTRACT_4.123.md`
(contract committed first @ 6ac45e2b). Host/artifact analysis
only, on Mimir (purpleviking1) — no physical child, no
device run of any kind. All findings below are taken from
the sha-verified raw output; where a closing summary
drafted en route misstated a number, the raw output's
number is the one recorded here.

## Run and closing record

hef123.py (hef122 lineage: hef120 base extraction +
arms121 + arms122 + the new arms123) sha256
`ab081ae339f01b8e9826a60d9cf87619f0347e71f40510b8855cc0a111b20582`
(340,314 B); arms123.py sha256
`83658cb37f1760c3c6f22d765e36ca2fc8947f8a0348aef4be6a70130a66a381`
(30,992 B), its gzip sha256
`8357ef408dd48d5ccbb2413d15843ca0dc08946aa619631c134a94b81d3294a2`
(7,889 B). Provenance: the arms gzip was split into 22
binary parts (21 × 373 B + 56 B), each landed on Mimir as
its own file via file.write with its own whole-part
sha256 gate — one parallel batch initially failed with
"No such file or directory" because only the first write
created the target directory; after the directory existed
every part landed and passed its gate. Concatenated
on-device, the whole-gzip sha256 and the decompressed
arms sha256 both matched the VM exactly. hef123.py was
assembled on-device from the verified hef122 base
(sha256
`9ef555ac8c1385ead4ef893a6cca1b86e89e9a88a8a49a1488f4035b993b3b1f`,
byte-identical on Mimir and the VM) plus arms123, and its
on-device sha256 matched the VM-built file exactly before
anything ran. The run was detached via setsid and ran to
DONE123 with no traceback or error lines. The retrieved
output is 13,972 lines / 2,204,713 B, sha256
`c95d0408c7ea5065c08ffc7fa17074c99bdf50b0cdb233d6250dcd7b590fbca7`;
retrieved gz sha256
`97917c276a89341187fb9786e454b4f9c05ce8f3bfcad9d3cfd5b3898b151446`
(227,447 B) decompressing to the same output sha256,
verified on the VM at closing; DONE123 is the output's
last line (13,972); the 4.123 section begins at output
line 12,231.

## Controls

Inherited controls reproduce EXACTLY: cells 55,902 /
obs 527,236; divergent triples 2,171, verdicts
CONT 12,411 / BREAK 476 / INDET 2,365; thin 383
(315 L1 UNANIMOUS + 58 L2 UNANIMOUS + 10 L2 AP);
≥8 cells 25,566, unanimous 18,286, 29 centres;
differing lanes 2,584 by lane {0: 1086, 1: 354, 2: 0,
3: 406, 4: 738}, in-37 differing 535; lane 1 354 lanes /
224 pairs / 218 diffs / 217 XORs; shared 267∩144 acts 36;
cc9 fit exact (train 48 rank 2 = cidx 144, start 8,
steady (CONST_DOM, 7), recorded 8-act head; train 50
also CONST_DOM 7).

## (i)(a) Centre 139 read in full

139 lives in 79 cells holding 1,448 observations, and
occurs 133 times. The 79 cells sit in four artifacts —
0856a10c 42, 76c3a8ff 35, 5ab3537d 1, 773470cd 1 — and
nowhere else (absent from cc9b9d1c, 0a0d378c and MiniLM).
Every one of the 79 is a ≥8-instance cell. Per-cell
occurrence counts are {1: 77, 28: 2}; cell classes are
DISTINCT 77 / UNANIMOUS 2; cell sizes are {8: 11, 15: 8,
18: 17, 20: 23, 21: 8, 25: 10, 28: 2}. At its 133
occurrences 139 carries 78 distinct full words but ONE
centreword — `ff8b0000` in 133/133 — and ng is 1 in all
133.

The two 28-occurrence cells are the same cell twice.
Both sit at key (pos 21, size 30768, off 15368), one in
5ab3537d and one in 773470cd, with the identical cidx
tuple [97, 101, 105, …, 205] (28 cidxs, step 4), all 28
centres 139, and the identical single word
('00000000', 'ff0f0000', 'ff8b0000', '00000000',
'00000000') in every row on both sides; only the rows'
`oo` offsets differ between the artifacts (first row
878,302,720 in A against 878,030,336 in B). These two
cells ARE the 2 UNANIMOUS-word cells centred on 139,
ARE the 2 unanimous ≥8 cells centred on 139, and the
key (21, 30768, 15368) IS 139's single non-divergent
triple — the read-back of that triple shows A and B
identical in cidx, centre and word in 28/28 rows.
Divergent triples containing 139: 0. Extras with centre
139: 0. This refines AES-NUM-122's shorthand "absent
from the mirror pair": read in full, each mirror
artifact holds exactly one 139 cell and it is the same
shared unanimous cell — 139 has no divergent presence
in the pair, and this one cell is its only presence
there. Of the 78 distinct (pos, size, off) keys among
the 79 cells, (21, 30768, 15368) is the ONLY key held
by two artifacts, and its mirror cidx tuples are
identical.

The other 77 cells are DISTINCT, one occurrence each,
and they carry only six distinct cidx tuples: in
0856a10c an n=21 tuple (8 cells), an n=20 tuple
(23 cells) and an n=8 tuple (11 cells); in 76c3a8ff an
n=15 tuple (8 cells), an n=18 tuple (17 cells) and an
n=25 tuple (10 cells). 139's seat inside them is fixed
per artifact. In 0856a10c it is always the LAST centre
(42/42): index 20 of 21, index 19 of 20, index 7 of 8,
with previous centre 134 (31 occurrences) or 124 (11)
and no next centre. In 76c3a8ff it is always interior
(35/35): index 8 in the n=15 and n=18 cells, index 12
in the n=25 cells, always with previous centre 130 and
next centre 148 (27) or 166 (8). The pooled in-cell
neighbour distribution at the 133 occurrences is
{(139,139): 52, (134,None): 31, (130,148): 27,
(124,None): 11, (130,166): 8, (139,None): 2,
(None,139): 2} — the (139,139) block and the two
boundary pairs are the unanimous mirror cell's own
members. So 139 is a closing centre in one artifact's
families and a fixed interior centre in another's, and
in the mirror pair it exists only as a whole cell of
nothing else. Why these seats, NOT PROVEN.

## (i)(b) Anchors 7/11/95 as sequence members

Read on the same terms as AES-NUM-122's varying-centre
arm — every occurrence of each anchor inside every
mid/thick (≥3-instance) divergent host sequence that
contains it:

- **7:** 67 triples (27 UNANIMOUS + 40 NONAP), 468
  occurrences. In its UNANIMOUS hosts (428 occurrences)
  every member is 7 itself. In the 40 NON-UNANIMOUS
  hosts it occurs 40 times, ALWAYS at start (index 0),
  with next centre 11 (16) or 15 (24) and step out 4 or
  8; its local step belongs to the host's step set in
  40/40. Its occurrences ride on only 5 distinct host
  sequences, the largest the 25-long all-7 sequence
  (350 occurrences).
- **11:** 109 triples (14 UNANIMOUS + 95 NONAP), 205
  occurrences. In the 95 NON-UNANIMOUS hosts it occurs
  95 times: start 10 (index 0, step out 6), interior 85
  — every interior occurrence at index 1, after 5 (69,
  steps (6, 6)) or after 7 (16, steps (4, 4)), before
  17 (79) or 15 (16) — END 0; local step in the host
  set in 95/95. 9 distinct host sequences.
- **95:** 45 triples (5 UNANIMOUS + 40 NONAP), 127
  occurrences. In the 40 NON-UNANIMOUS hosts it occurs
  40 times, ALWAYS interior: index 7 (24) or index 9
  (16), always after 91, before 99 (37) or 103 (3),
  steps (4, 4) ×37 and (4, 8) ×3, in the host set
  40/40. 5 distinct host sequences — the same NONAP
  family that carries 7 at its start carries 95 in its
  interior ((7, 15, 23, 79, 83, 87, 91, 95, 99, 103,
  111) ×21; (7, 11, 15, 23, 59, 79, 83, 87, 91, 95,
  99, 103, 111) ×16 carries all three anchors).

Pooled over the three anchors: 800 occurrences in all
hosts (start 96 / interior 658 / end 46), and over
NON-UNANIMOUS hosts only, 175 occurrences — start 50 /
interior 125 / **END 0**. Every end occurrence (46 =
27 + 14 + 5) sits inside the anchor's own UNANIMOUS
host, where the anchor is every member. The
constant-like anchors therefore obey the varying
centres' law exactly (AES-NUM-122 pooled varying:
137 occurrences, start 33 / interior 104 / END 0, all
in NONAP hosts): inside a sequence of other centres,
no anchor is ever an end, and no anchor ever
introduces a step its host does not already take.
Mechanism NOT PROVEN.

## (ii) Lane 1 split the other way

**(a) Group (20, 32720) per offset block.** The group's
216 lanes live in 8 cells at offsets 6796, 6864, 6932,
7000, 7068, 7136, 7204, 7272 (step 68), 27 lanes each.
Every block carries the same 27 cidxs {2, 5, 8, …, 80}
and every lane is at centre 127. Each block internally
has 27 distinct pairs, 27 distinct diffs, 27 distinct
XORs, 27 distinct A and 27 distinct B. Between blocks
there is NOTHING shared: against the first block, every
other block's pair set, A set, B set, diff set and
multiset, and XOR set and multiset are all unequal, no
additive translate (da, db) and no XOR translate
(ta, tb) maps any block onto the first — and the
stronger count, computed from the run's own printed
pair lists, is that over all 28 block pairs the
intersections of pair sets, A sets, B sets, diff sets
and XOR sets are ALL 0. The pooled 216 are distinct in
every projection (216 distinct A, 216 distinct B, 216
distinct pairs, 216 distinct diffs, 216 distinct
XORs). The blocks are eight disjoint pair populations
over one shared cidx frame — not translates, not
shifts, not overlaps of one another in any tested
sense.

**(b) Group (14, 9992)'s five repeated pairs in full.**
Each pair occurs 27 times, each in its own cell, all
five at the same 27 cidxs {101, 105, …, 205} and the
same 27 centres {7, 11, 15, …, 111}:

| cell off | A | B | diff | XOR | per-byte |
|---|---|---|---|---|---|
| 4336 | 1401b280 | 1401b200 | −2147483648 | 0x80000000 | (0,0,0,−128) |
| 9832 | 1801b280 | 1801b200 | −2147483648 | 0x80000000 | (0,0,0,−128) |
| 1744 | 1c01b080 | 1c01b000 | −2147483648 | 0x80000000 | (0,0,0,−128) |
| 6944 | 2001b080 | 2001b000 | −2147483648 | 0x80000000 | (0,0,0,−128) |
| 7424 | 4401a200 | 4401a280 | +2147483648 | 0x80000000 | (0,0,0,+128) |

Every pair differs ONLY in byte 3, and only in byte
3's top bit: four pairs read A byte3 0x80 → B byte3
0x00, one reads 0x00 → 0x80. The group's "2 distinct
diffs" of AES-NUM-122 are exactly −2^31 and +2^31, and
its single XOR is the pure sign bit 0x80000000. Group
(19, 7712)'s three pairs are the same shape — all XOR
0x80000000, diffs +2^31 once and −2^31 twice, single
occurrences at cidx 86, centre 87. The narrow groups'
lane-1 differences are sign flips and nothing else.

**(c) Byte 3 retried on joint keys.** Determination
was credited only with ZERO counterexamples over the
224 pairs:

- f(A byte 3) [4.122 control]: 61 keys, 35 with >1
  diff, 192 pairs under violating keys — NOT determined.
- f(A byte 3, group): 63 keys, 35 violating, 192 pairs
  — NOT determined. Group adds NOTHING: all 35
  violations live inside group (20, 32720) (its own
  table: 59 byte-3 values, 35 multi-valued). Groups
  (14, 9992) and (19, 7712) are each internally
  determined (2 byte-3 values each, 0 multi-valued) —
  trivially, since their only diffs are the sign flips
  of (b).
- f(group) alone: 3 keys, all 3 multi-valued — NOT
  determined.
- f(A byte 3, A byte 0): 175 keys, 32 violating, 78
  pairs — NOT determined.
- f(A byte 3, A byte 1): 216 keys, only 2 violating —
  (249, 44) → {−1, 0} and (252, 84) → {−2, −1}, 4
  pairs — NOT determined.
- f(A byte 3, A byte 2): 221 keys, only 1 violating —
  (249, 181) → {−5, −1}, 2 pairs — NOT determined.
- f(A bytes 0, 1, 2 jointly): 224 keys, 0 violating —
  "determined" only because the key is injective over
  the pair population (224 keys for 224 pairs), the
  same vacuity as the f(full A) sanity check (224 keys,
  0 violating). Adding group to it changes nothing
  (224 keys).

So byte 3's difference has no non-vacuous joint
determination among the keys tried: group contributes
nothing, any single low byte leaves the determination
a few pairs short, and the low bytes together succeed
only by naming each pair. Source NOT PROVEN.

## (iii)(a) The two 2-act breaks against the corpus

The four differing acts of AES-NUM-122's region, on
both sides — 267-side (900761600, 248, 0) @792,
(900761848, 176, 0) @793, (900762112, 256, 0) @801,
(900762624, 176, 0) @802; 144-side (1198581248, 248, 0)
@195, (1198581760, 176, 0) @196, (1198582272, 256, 0)
@204, (1198582528, 176, 0) @205. Components 2 and 3 of
each cross-side pair are identical; only component 1
differs (re-verified in this run).

Corpus-wide, every one of the eight acts occurs ONLY
in cc9b9d1c. Occurrence counts: 267-side 4 / 4 / 4 / 6;
144-side 27 / 54 / 27 / 27.

As adjacent PAIRS: 144 break pair 1
((1198581248, 248, 0), (1198581760, 176, 0)) occurs 27
times — always at position 195, in the 27 contexts
{140, 144, 148, …, 244} (the train-48 family), with
previous act (173040, 24, 0) and next act (173568, 816,
0) in every case; pair 2 occurs 27 times at position
204 in the same 27 contexts. 267 break pair 1
((900761600, 248, 0), (900761848, 176, 0)) occurs 4
times — always at position 792, in exactly the contexts
{114, 130, 251, 267}, framed by the SAME neighbouring
acts as the 144 pair ((173040, 24, 0) before,
(173568, 816, 0) after); pair 2 occurs 4 times at
position 801 in the same 4 contexts, framed by
(174968, 24, 0) and (175616, 176, 0). REVERSED pairs
occur 0 times anywhere in the corpus. The surplus
act occurrences are single-act reuses elsewhere: the
144-side @196 act also occurs 27 further times at
position 557 (in contexts of the {143, 147, …} step-4
family) behind a different previous act, and the
267-side @802 act also occurs
twice at position 646 in cidx 120 and 257. The break
acts are not rare; the PAIRING is what is rationed —
27 contexts on the train side, 4 on the stranger side,
always at the same two positions, never reversed.

## (iii)(b) Cidx 130 read against cidx 267 in full

Cidx 130 is 842 acts long, all distinct — exactly
267's length. Their occurrence profiles are near-twins:
709 corpus-unique acts each; count ≥4 acts 50 each;
max 1,060 each; the identical high band (30 acts at
271, 1 at 1,058, 2 at 1,060); means 14.7067 (130) and
14.8824 (267). Below the band they differ only in
detail (count 2: 80 against 83; count 3: 3 against 0;
267 carries counts 39 ×3 and 47 ×3 where 130 carries
28 ×3, 15 ×3, 14 ×1, 8 ×3, 6 ×1, 4 ×6). Cidx 144
(control) remains the odd one: 245 acts, mean 49.2612.

The two sequences share 111 distinct acts (731 of 842
in each are unshared; union 1,573). Every one of 267's
133 non-unique acts that lies in 130 is shared — 111 of
the 133 — and 130 likewise has exactly 133 non-unique
acts, whose 11,541 other occurrences spread over 1,059
distinct other contexts, the top being cidx 267 itself
(111), then 257, 251 and 6 (40 each). The shared acts
stand in IDENTICAL relative order in both sequences:
0 inversions among 6,105 pairs. Their position offsets
(pos267 − pos130) take only 13 distinct values,
concentrated at 0 (42 acts), −7 (29), +1 (12), −3 (5),
−17 (5), −6 (4), −2 (3). They form 19 maximal shared
runs of length ≥2 — lengths {31: 1, 10: 1, 8: 1, 7: 1,
6: 1, 5: 3, 3: 4, 2: 7}. The longest run, 31 acts, sits
at IDENTICAL positions 787–817 in both sequences, and
it contains both 267-side break pairs at 792–793 and
801–802: against cidx 130 the "break" acts break
nothing — they are shared verbatim, in place. The
breaks of arm (iii)(a) are breaks of the 144↔267
alignment alone. A second run of 8 sits at identical
positions 826–833 (the shared tail); the −7 family
carries runs of 10 (130 pos 156–165 ↔ 267 pos
149–158), 7 and 6; the +1 family runs of 5 and 3.
What fills the spans between the runs in each
sequence, and why the offsets take these values, NOT
PROVEN.

## Next

Slice 4.124 (proposed): (i) centre 139's six
DISTINCT-cell cidx-tuple families read as full centre
sequences — the sequences 139 closes in 0856a10c and
sits inside in 76c3a8ff — and the shared unanimous
mirror cell (21, 30768, 15368) read against the mirror
pair's full shared-cell population; (ii) lane 1's
byte-3 near-misses in full — the 6 pairs under the
violating (byte 3, byte 1) and (byte 3, byte 2) keys —
plus f(A byte 3, A byte 1, A byte 2) tested exactly,
and group (20, 32720)'s per-cidx pair trajectories
across its eight disjoint blocks (the same 27 contexts
at eight offsets: what the offset changes); (iii) the
four break contexts {114, 130, 251, 267} read against
each other in full (lengths, profiles, pairwise shared
acts and runs) and the non-shared spans between
130↔267's 19 shared runs read in full; then broad
ordinary UNMODIFIED source-model support100%.
