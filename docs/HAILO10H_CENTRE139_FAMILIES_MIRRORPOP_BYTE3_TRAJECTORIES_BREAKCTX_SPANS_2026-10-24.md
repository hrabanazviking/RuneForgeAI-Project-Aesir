# Centre 139's six DISTINCT-cell families each carry exactly ONE centre sequence — the cidx tuple determines the sequence, and a cidx carries the same centre in every family that contains it — with 139 closing the three 0856a10c sequences and sitting inside the three 76c3a8ff step-9 ladder sequences after 130; the shared mirror cell (21, 30768, 15368) is the UNIQUE single-centre-139 cell among the mirror pair's 2,981 shared cells (2,386 unanimous on both sides; 2,520 single-centre on the A side, of which centre 15 alone holds 1,708 and centre 139 exactly one); lane 1's byte-3 difference IS determined by (A byte 3, A byte 1, A byte 2) — 222 keys, zero counterexamples over all 224 pairs, and NOT injective, the only two multi-pair keys being narrow-group sign-flip keys whose pairs differ only in byte 0 — while the five distinct near-miss pairs under the old violating keys (six key-selections; one pair sits under both) all live in group (20, 32720)'s last two blocks; that group's per-cidx trajectories across its eight blocks change everything except the frame — 8 distinct A values, B values, diffs and XORs for every one of the 27 cidxs, nothing constant anywhere — yet A and B both strictly increase with block offset for all 27 cidxs, and all 189 consecutive-block steps on each side are positive and pairwise distinct; the four break contexts {114, 130, 251, 267} are all 842 acts long on the identical high band and form two near-pairs — {114, 251} sharing 168 acts in 21 runs, {130, 267} sharing 111 in 19 — while every cross-pair shares only 37–40 acts, essentially the head 3-run and the shared tail run holding both 267-side break pairs, which stand at the same positions 792 and 801 in all four contexts (the 144-side pairs' acts are absent from all four), and 130×251 alone inverts (110 of 780 shared pairs); the non-shared spans between 130↔267's 19 shared runs total 739 acts on EACH side (103 in runs + 739 in spans = 842), in 20 spans of which 8 have equal lengths on the two sides, holding the 8 isolated shared singles (AES-NUM-124)

Slice 4.124, worked under `docs/TASK_CONTRACT_4.124.md`
(contract committed first @ 331eec40). Host/artifact analysis
only, on Mimir (purpleviking1) — no physical child, no
device run of any kind. All findings below are taken from
the sha-verified raw output; the two derived counts marked
as such were computed at closing from the run's own
printed pair lists and trajectories, never sampled.

## Run and closing record

hef124.py (hef123 lineage: the hef122 base, byte-identical
to `~/workspace/.verify-tmp/aesir122/hef122.py`, plus the
new arms124) sha256
`6727c3a6843af0ad9b5dbe53defa2c0af58db361a271cb5bb06eb4a5d4ee5a83`
(332,498 B); arms124.py sha256
`c8c5448d8d88e3c4bace0a362294b0ed8ea18ee61c36428b1bc3920197b6f9c1`
(23,176 B), its gzip sha256
`9943dee84da718a6f6f2b7233594efc7543967e824d0ea68ea84761d9ab2838c`
(6,463 B). Provenance: the arms gzip was split into 18
binary parts (17 × 373 B + 122 B), each landed on Mimir as
its own file via file.write with its own whole-part
sha256 gate. Part p_ad failed its gate twice — the
verbatim retry failed identically (deterministic
corruption at that chunk boundary) — and landed clean
when split at a new boundary into two halves of 186 B
(sha256 `f08c809976c8f68e39ea3ac202a008656bf77fb910b83baafc91886090903494`)
and 187 B (sha256 `b98fd25a81fda4d0b0fa7ce90cdbae40cdc8efc2285abf962dcbb0b1830cd4cc`);
three further parts (p_al, p_am, p_ao) failed their gates
on a parallel send, were discarded uncommitted, and
landed on sequential resend. Concatenated on-device, the
whole-gzip sha256 and the decompressed arms sha256 both
matched the VM exactly. hef124.py was assembled on-device
from the verified hef122 base (sha256
`9ef555ac8c1385ead4ef893a6cca1b86e89e9a88a8a49a1488f4035b993b3b1f`,
byte-identical on Mimir and the VM) plus arms124, and its
on-device sha256 matched the VM-built file exactly before
anything ran. The run was detached via setsid over the
7-artifact corpus (the six hailo-ollama blobs in glob
order, then MiniLM) and ran to DONE124 with an empty
error file. The retrieved output is 12,572 lines /
2,044,686 B, sha256
`0b8b990f3104ac05a9ddfc038f8ec914983fd080874fe1ab0e5c802504314815`;
retrieved gz sha256
`9588729cc754780c29c58093fd91364daf6b13d79892d79f5a63955dd03abd1f`
(227,047 B) decompressing to the same output sha256,
verified on the VM at closing; DONE124 is the output's
last line (12,572); the 4.124 section begins at output
line 12,231 — the identical offset to 4.123's section,
the base having reproduced line-for-line.

## Controls

Inherited controls reproduce EXACTLY: cells 55,902 /
obs 527,236; divergent triples 2,171, verdicts
CONT 12,411 / BREAK 476 / INDET 2,365; thin 383
(315 L1 UNANIMOUS + 58 L2 UNANIMOUS + 10 L2 AP);
≥8 cells 25,566, unanimous 18,286, 29 centres;
differing lanes 2,584 by lane {0: 1086, 1: 354, 2: 0,
3: 406, 4: 738}, in-37 differing 535; lane 1 354 lanes /
224 pairs / 218 diffs / 217 XORs; shared 267∩144 acts 36;
lengths cidx 130 / 267 / 144 = 842 / 842 / 245; cc9 fit
exact (train 48 rank 2 = cidx 144, start 8,
steady (CONST_DOM, 7), recorded 8-act head; train 50
also CONST_DOM 7).

## (i)(a) The six DISTINCT-cell families as full centre sequences

The 77 DISTINCT cells centred on 139 fall into exactly
6 families keyed by (artifact, cidx tuple) — sizes
23 / 17 / 11 / 10 / 8 / 8 — and **each family carries
exactly ONE distinct centre sequence** across all its
cells: within a family the cidx tuple determines the
centre sequence completely, while the cells themselves
differ in their (pos, size, off) keys and in their words
(every one of the 77 cells is DISTINCT with
distinct_words == n). At the 139 seat, centreword
`ff8b0000` and ng 1 hold in all 77 cells.

- **0856a10c, n=21 tuple ×8 cells** (keys (9, 32632) ×7 +
  (11, 3912) ×1): sequence
  [4, 14, 19, 24, 29, 34, 39, 44, 54, 59, 64, 79, 89, 94,
  99, 109, 114, 119, 124, 134, 139]; 139 at index 20,
  previous 134, no next.
- **0856a10c, n=20 tuple ×23 cells**: sequence
  [14, 19, 24, 29, 34, 39, 44, 54, 59, 64, 79, 89, 94, 99,
  109, 114, 119, 124, 134, 139]; 139 at index 19,
  previous 134. The tuple is the n=21 tuple without its
  first cidx (103) and the sequence is the n=21 sequence
  without its leading centre (4).
- **0856a10c, n=8 tuple ×11 cells**: sequence
  [29, 34, 39, 94, 99, 114, 124, 139]; 139 at index 7,
  previous 124. Every cidx of this tuple also sits in
  the two longer 0856a10c tuples, carrying the same
  centre there.
- **76c3a8ff, n=25 tuple ×10 cells** (all keys
  (18, 32744)): sequence the full step-9 ladder
  [31, 40, 49, 58, 67, 76, 85, 94, 103, 112, 121, 130,
  139, 148, 157, 166, 175, 184, 193, 202, 211, 220, 229,
  238, 247]; 139 at index 12, previous 130, next 148.
- **76c3a8ff, n=18 tuple ×17 cells**: sequence
  [31, 40, 49, 58, 67, 76, 94, 130, 139, 148, 166, 175,
  184, 193, 211, 229, 238, 247]; 139 at index 8,
  previous 130, next 148. The tuple is the n=25 tuple
  with 7 cidxs dropped (177, 195, 204, 213, 249, 294,
  312), and the sequence is the step-9 ladder with
  exactly those cidxs' centres (85, 103, 112, 121, 157,
  202, 220) removed.
- **76c3a8ff, n=15 tuple ×8 cells** (all keys
  (11, 23592)): sequence
  [31, 40, 49, 58, 67, 76, 94, 130, 139, 166, 175, 184,
  193, 211, 229]; 139 at index 8, previous 130,
  next 166. The tuple drops 3 further cidxs from the
  n=18 tuple (240, 330, 339), with the same centres
  removed from the sequence.

So, read across both artifacts, **a cidx carries the
same centre in every one of the six families that
contains it** (verified tuple-by-tuple against the
printed sequences): the families are windows and
sub-windows on one centre assignment per artifact pair
of ladders — in 0856a10c a closing window (139 always
last, after 134 or 124), in 76c3a8ff a step-9 ladder
window (139 always after 130, before 148 or 166). Why
the assignment has this shape, NOT PROVEN.

## (i)(b) The shared mirror cell against the full shared-cell population

The mirror pair's full shared-cell population — the
2,981 cidx-keyed cells held by both 5ab3537d and
773470cd (of 6,970 A cells and 7,485 B cells) — is, as a
count, exactly the non-divergent 1-1 triple population
(5,152 triples in both, 2,171 divergent, 2,981
non-divergent): the same population counted two ways.
In it, centres are equal in 2,981/2,981 cells and words
equal in 2,885/2,981 (96 differ — the 4.119 differing
population). Class pairs (A, B): UNANIMOUS/UNANIMOUS
2,386; DISTINCT/DISTINCT 479; OTHER/OTHER 73;
UNANIMOUS/OTHER 24; UNANIMOUS/DISTINCT 13;
OTHER/DISTINCT 4; DISTINCT/OTHER 2. A-side unanimous
2,423, B-side unanimous 2,386, both-unanimous 2,386 —
every B-unanimous cell is A-unanimous, and the 37-cell
gap is the 4.119 A-unanimous-not-B set. Cell sizes run
2–28 (n dist: 19 ×812, 28 ×443, 27 ×416, 8 ×506, 2 ×208,
9 ×207, 7 ×237, 18 ×58, 3 ×40, 20 ×31, 6 ×19, 10 ×4);
pos 21 is the modal position (325 cells).

2,520 of the 2,981 cells have all A-side centres equal
to one value. By that centre: 15 ×1,708; 5 ×284;
127 ×191; 0 ×176; 34 ×40; 11 ×37; 2 ×21; 7 ×21;
23 ×15; 1 ×12; 69 ×9; 95 ×5; **139 ×1**. Of these 2,520,
words are equal in 2,441 and A is unanimous in 2,423 —
97 single-centre cells carry varying words under a
constant centre. The target cell (21, 30768, 15368)
sits in this population as: n 28 (the maximum size,
shared by 443 cells), UNANIMOUS on both sides (one of
2,386), words equal A==B, cidxs equal, only the rows'
`oo` offsets differing — and it is **the population's
only single-centre-139 cell**: 139's shared cell is not
one of a family of shared 139 cells, it is the sole
representative of its centre in the whole shared
population, in a population where centre 15 alone holds
1,708 single-centre cells. Mechanism NOT PROVEN.

## (ii)(a) The byte-3 near-miss pairs in full

The violating (byte 3, byte 1) keys hold 4 pairs and the
violating (byte 3, byte 2) key holds 2 pairs — six
key-selections over **five distinct pairs**, because
one pair sits under both a (byte 3, byte 1) and the
(byte 3, byte 2) violating key. All five live in group
(20, 32720), at centre 127, one occurrence each, four of
them in the group's last block (off 7272) and one in
off 7204:

| key | cidx | cell off | A | B | diff | byte-3 diff | XOR | per-byte diffs |
|---|---|---|---|---|---|---|---|---|
| (249, 44) & (249, 181) | 74 | 7204 | 682cb5f9 | 6884f5f8 | −12,560,384 | −1 | 0x0140a800 | (0, +88, +64, −1) |
| (249, 44) | 77 | 7272 | 782c75f9 | 808cb2f9 | +4,022,280 | 0 | 0x00c7a0f8 | (+8, +96, +61, 0) |
| (252, 84) | 8 | 7272 | 745471fc | 089adffb | −9,550,444 | −1 | 0x07aece7c | (−108, +70, +110, −1) |
| (252, 84) | 14 | 7272 | ec546cfc | 781099fa | −30,622,836 | −2 | 0x06f54494 | (−116, −68, +45, −2) |
| (249, 181) | 50 | 7272 | 705ab5f9 | a08de5f4 | −80,727,248 | −5 | 0x0d50d7d0 | (+48, +51, +48, −5) |

(A and B are the little-endian byte strings; u32 values
in the raw output.) Under key (249, 44) the two pairs'
byte-3 diffs are −1 and 0; under (252, 84), −1 and −2;
under (249, 181), −1 and −5. Nothing else about the
five pairs is shared: their full diffs, XORs and
per-byte patterns are all different. What singles these
five out, NOT PROVEN.

## (ii)(b) f(A byte 3, A byte 1, A byte 2) tested exactly

Over the full 224-pair population: **222 keys, 0 keys
with >1 diff, 0 pairs under violating keys —
DETERMINED, and NOT injective** (222 keys < 224 pairs).
Adding group changes nothing (222 keys). This is the
first non-vacuous determination in the byte-3 line:
AES-NUM-123's low-three-bytes key (bytes 0, 1, 2)
reached 224 keys — determination by unique
identification only — while the (byte 3, byte 1,
byte 2) key determines the same difference with two
genuine collisions, both consistent. The two
multi-pair keys, computed at closing from the run's
printed pair lists, are both narrow-group sign-flip
keys: (128, 1, 176) carries A 0x1c01b080 → B 0x00b0011c
and A 0x2001b080 → B 0x00b00120 (the group (14, 9992)
pairs at cell offs 1744 and 6944), and (128, 1, 178)
carries A 0x1401b280 → B 0x00b20114 and A 0x1801b280 →
B 0x00b20118 (cell offs 4336 and 9832) — in each key the
two pairs differ only in byte 0, which the key does not
see, and both carry byte-3 diff −128 (full diff −2^31).
Within the wide group (20, 32720) the key is injective
(216 pairs, 216 keys, from the same printed lists), so
the determination's only compression anywhere is those
two narrow collisions: as a closed form the map remains
essentially a naming of the wide pairs, and any
arithmetic mechanism behind it is NOT PROVEN. But as an
exact statement it stands: byte 3's signed difference
is a function of (A byte 3, A byte 1, A byte 2) over the
whole population, with zero counterexamples.

## (ii)(c) Group (20, 32720) per-cidx trajectories across the eight blocks

Each of the 27 cidxs {2, 5, …, 80} appears in all eight
blocks (offs 6796–7272 step 68, 27 lanes each, all at
centre 127). Per cidx across the blocks: **8 distinct A
values, 8 distinct B values, 8 distinct pairs, 8
distinct diffs and 8 distinct XORs — for every one of
the 27 cidxs** (distinct-A count dist {8: 27},
distinct-diff count dist {8: 27}); cidxs with constant
A, constant B, constant pair, constant diff or constant
XOR: 0 of 27 in every case. The offset therefore
changes the pair completely at every step — nothing of
the pair survives from one block to the next. Yet the
change is not formless (derived at closing from the
run's printed trajectories): **A strictly increases
with block offset for all 27 cidxs, and B strictly
increases for all 27**; all 189 consecutive-block
delta-A values are positive and pairwise distinct
(min 31,346,620, max 394,641,536), all 189 delta-B
values are positive and pairwise distinct
(min 32,229,224, max 392,664,128), and all 189
delta-diff values are pairwise distinct. So the eight
blocks hold, per context, a strictly rising ladder of
pairs whose every rung and every step is unique in the
whole group — no repeated step means no constant stride,
and no shared value means no translate, sharpening
AES-NUM-123's disjointness: the blocks are disjoint
populations arranged in a strict per-cidx order. What
sets the steps, NOT PROVEN.

## (iii)(a) The four break contexts against each other in full

All four contexts are 842 acts, all distinct, on the
identical high band (30 acts at count 271, 1 at 1,058,
2 at 1,060, max 1,060):

| cidx | corpus-unique | count 2 | count 3 | count ≥4 | mean |
|---|---|---|---|---|---|
| 114 | 655 | 136 | 7 | 44 | 14.8729 |
| 130 | 709 | 80 | 3 | 50 | 14.7067 |
| 251 | 661 | 130 | 5 | 46 | 14.6200 |
| 267 | 709 | 83 | 0 | 50 | 14.8824 |

The 144-side break pairs are **absent from all four
contexts entirely** — neither act of either pair occurs
in any of them, even singly. The 267-side pairs occur
in **each of the four contexts exactly once, at the
same positions**: pair 1 at 792, pair 2 at 801, in 114,
130, 251 and 267 alike.

Pairwise (shared distinct acts / order inversions /
shared runs ≥2):

- **114×130:** 39 shared; 0 inversions of 741 pairs;
  3 runs — 33 acts at 786–818 in both, 3 at 8–10 in
  both, 2 at 820–821 in both.
- **114×251:** 168 shared; 0 inversions of 14,028
  pairs; 21 runs (lengths 54/32/9/7/6/6/6/5/4/3×7/2×5) —
  the 54-act run at identical positions 130–183 in
  both, a 32-act run at 786–817 in both, a 4-act run
  at 830–833 in both, and 18 shorter runs between
  positions 7 and 758.
- **114×267:** 37 shared; 0 inversions of 666 pairs;
  2 runs — 3 acts (114 pos 8–10 ↔ 267 pos 6–8) and the
  31-act run at 787–817 in both.
- **130×251:** 40 shared; **110 inversions of 780
  pairs** — the only inverting pair of the four;
  2 runs — 3 acts (130 pos 8–10 ↔ 251 pos 7–9) and a
  32-act run at 786–817 in both.
- **130×267:** 111 shared; 0 inversions of 6,105
  pairs; 19 runs (AES-NUM-123, re-verified exactly).
- **251×267:** 37 shared; 0 inversions of 666 pairs;
  2 runs — 3 acts (251 pos 8–10 ↔ 267 pos 6–8) and the
  31-act run at 787–817 in both.

The four contexts therefore form **two near-pairs** —
{114, 251} (168 shared acts, 21 runs) and {130, 267}
(111 shared, 19 runs) — while every cross-pair shares
only 37–40 acts: essentially the common skeleton, the
head 3-run (0, 304, 0..2) near the start and the long
tail run at 786–818 that contains both 267-side break
pairs (31 acts at 787–817 where 267 is a party, 32–33
acts in the pairs not involving 267, extended by the
act (2774016, 24, 1) at 786 and, against 114, by two
further acts at 820–821). The breaks' four contexts are
not four strangers: they are two pairs of relatives
holding one shared tail. Why these pairings, and why
130×251 alone inverts, NOT PROVEN.

## (iii)(b) The non-shared spans between 130↔267's 19 shared runs in full

The 19 maximal shared runs (re-verified: lengths
31/10/8/7/6/5/5/5/3×4/2×7, 103 acts in all) sit at —
130 positions ↔ 267 positions: 8–10 ↔ 6–8 (3);
79–80 ↔ 75–76 (2); 103–107 ↔ 100–104 (5);
156–165 ↔ 149–158 (10); 168–170 ↔ 161–163 (3);
176–182 ↔ 169–175 (7); 185–190 ↔ 178–183 (6);
222–223 ↔ 216–217 (2); 231–232 ↔ 225–226 (2);
385–387 ↔ 386–388 (3); 390–392 ↔ 391–393 (3);
395–399 ↔ 396–400 (5); 560–564 ↔ 543–547 (5);
599–600 ↔ 580–581 (2); 637–638 ↔ 613–614 (2);
650–651 ↔ 635–636 (2); 751–752 ↔ 756–757 (2);
787–817 ↔ 787–817 (31); 826–833 ↔ 826–833 (8).

Between and around them stand 20 spans (head, 18
between-run spans, tail) whose full act lists stand in
the raw output. Their lengths (130 side / 267 side),
in order: HEAD 8/6; then 68/66, 22/23, 48/44, 2/2,
5/5, 2/2, 31/32, 7/7, 152/159, 2/2, 2/2, 160/142,
34/32, 36/31, 11/20, 99/119, 34/29, 8/8; TAIL 8/8.
**The spans total 739 acts on the 130 side and 739
acts on the 267 side** — the accounting closes exactly
on both sides (103 in runs + 739 in spans = 842) —
although only 8 of the 20 spans have equal lengths on
the two sides; the length differences are absorbed
span-by-span in both directions (largest spans: 160/142
between runs 11–12, 152/159 between runs 8–9, 99/119
between runs 15–16; nine spans are ≤8 acts on both
sides). The 111 − 103 = **8 shared acts that belong to
no run** (isolated singles) all sit inside spans: one
in the HEAD span at (130 pos 3, 267 pos 3); three in
the span between runs 2–3 at (135, 128), (137, 130),
(140, 133) — all at offset −7, the offset of the
neighbouring runs; three in the span between runs
16–17 at (773, 774), (783, 783), (786, 785), the last
immediately before the 31-act run; and one in the span
between runs 17–18 at (821, 821), between the 31-act
run and the shared tail. What fills the long spans in
each sequence beyond these counts, and why the totals
balance exactly while the individual spans do not,
NOT PROVEN.

## Next

Slice 4.125 (proposed): (i) the (byte 3, byte 1,
byte 2) determination read as a map — its per-byte-3
tables over the full 224 pairs, whether it factors
through any arithmetic on (byte 1, byte 2), and the two
narrow shared keys' byte-0 freedom read against all
eight narrow pairs; (ii) group (20, 32720)'s trajectory
steps as a population — the 189 delta-A / delta-B /
delta-diff triples per (cidx, block-step) read in full
for any repeated or factored structure, and A at block
k+1 tested as a function of A at block k over the 189
steps; (iii) the four break contexts' common core —
the acts shared by all four contexts, in order, read
in full — plus 114×251's shared population in full
(168 acts, 21 runs, the 54-act run) and 130×251's 110
inversions localized to the specific shared acts that
invert; then broad ordinary UNMODIFIED source-model
support100%.
