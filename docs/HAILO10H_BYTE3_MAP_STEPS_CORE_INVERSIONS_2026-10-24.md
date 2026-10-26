# The (byte 3, byte 1, byte 2) determination read as a map: 222 keys over 224 pairs across 61 byte-3 values (24 distinct byte-3 differences, modal −1 ×43), with exactly one non-trivial factoring — the difference is also determined by (byte 3, byte 1 + byte 2) at the same 222 keys, while every other conditioned arithmetic form fails on 1–12 keys and every direct formula fails on 202–224 pairs; the narrow population's byte 0 is free in both directions (under the two shared keys it takes two values each at the same difference, yet byte 0 alone determines nothing — the values 20 and 68 each carry both signs); group (20, 32720)'s 189 trajectory steps are all distinct in every component, and each cidx's step sizes strictly shrink — delta-A and delta-B sequences strictly decreasing for 27/27 cidxs — while A at block k+1 as a function of A at block k is VACUOUS (189 distinct A values, zero collisions, per-step A sets pairwise disjoint); the four break contexts' common core is exactly 37 acts — the head 3-run plus a 34-act tail holding both 267-side break pairs — identical in order in all four (0 core inversions for every context pair), and equal to the 114∩267 and 251∩267 shared sets; 114×251's 168 shared acts sit at identical positions 93 times (position difference 0), their 54-act run at identical positions 130–183 consists of acts occurring exactly twice in the whole corpus; and 130×251's 110 inversions are generated entirely by THREE displaced acts — the size-24 acts at 130 positions 6, 7 and 197 that stand at 251's positions 824, 822 and 823 — every other shared act inverting only against those three (AES-NUM-125)

Slice 4.125, worked under `docs/TASK_CONTRACT_4.125.md`
(contract committed first @ 8e1e5668). Host/artifact analysis
only, on Mimir (purpleviking1) — no physical child, no
device run of any kind. All findings below are taken from
the sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef125.py (hef124 lineage: the hef122 base, byte-identical
to `~/workspace/.verify-tmp/aesir122/hef122.py`, plus the
new arms125) sha256
`af955835b43ab71e1d7d196335e44c4370da992f4ccc5fad8034a745269bbca9`
(341,004 B); arms125.py sha256
`f4c52c5a4b36046728b642f14d9c5aee57efa05907f7fc2a44553020a05d4eb9`
(31,682 B), its gzip sha256
`369890a4dc9cb63ccb9bf90279e50eb63d55f7f8a149eb55ff7ebed9fd5f23b3`
(7,979 B). Provenance: the arms gzip was split into 22
binary parts (21 × 373 B + 146 B), each landed on Mimir as
its own file via file.write with its own whole-part
sha256 gate — all 22 parts passed their gates on first
landing and were re-verified as a set by an on-device
sha256sum listing before assembly. Concatenated on-device,
the whole-gzip sha256 and the decompressed arms sha256
both matched the VM exactly. hef125.py was assembled
on-device from the verified hef122 base (sha256
`9ef555ac8c1385ead4ef893a6cca1b86e89e9a88a8a49a1488f4035b993b3b1f`,
byte-identical on Mimir and the VM) plus arms125, and its
on-device sha256 matched the VM-built file exactly before
anything ran. The run was detached via setsid over the
7-artifact corpus (the six hailo-ollama blobs in glob
order, then MiniLM) and ran to DONE125 with an empty
error file. The retrieved output is 13,605 lines /
2,150,203 B, sha256
`e091795c18320b904d75747d0608cce16466005665b1f66ee14fe29586bad137`;
retrieved gz sha256
`f5374049299d1ad5c6138a525926b5c1223d0e76c24abe813a449df6e4cfa9ae`
(248,327 B, fetched through a temporary on-device HTTP
server via the tunnel proxy) decompressing to the same
output sha256, verified on the VM at closing; DONE125 is
the output's last line (13,605); the 4.125 section begins
at output line 12,231 — the identical offset to 4.124's
section, the base having reproduced line-for-line.

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

## (i)(a) The determination read as a map

The map has 222 keys over 224 pairs — 2 multi-pair keys
carrying 4 pairs, as established in AES-NUM-124 — spread
over **61 distinct A byte-3 values** (0, 128, and a sparse
band 174–252). The byte-3 signed difference (B byte 3 −
A byte 3) takes **24 distinct values** over the 224 pairs:
−128 ×6, −11 ×9, −10 ×8, −9 ×9, −8 ×16, −7 ×17, −6 ×12,
−5 ×15, −4 ×9, −3 ×9, −2 ×15, **−1 ×43 (the mode)**,
0 ×14, +1 ×13, +2 ×7, +3 ×9, +4 ×3, +10 ×2, +11 ×1,
+13 ×1, +14 ×1, +15 ×1, +16 ×2, +128 ×2 — 168 negative,
14 zero, 42 positive, and no difference at all in
+5…+9, +12 or +17…+127.

Per byte-3 value, the map is almost everywhere
one-pair-per-key: **60 of the 61 byte-3 values have
keys == pairs** (derived at closing from the printed
per-byte-3 table); the sole exception is byte 3 = 128
with 6 pairs under 4 keys — the two narrow multi-pair
keys (below) plus two single-pair narrow keys. Only
byte-3 values 0 and 128 carry narrow-group pairs; every
other byte-3 value's pairs are all in group (20, 32720).
The largest byte-3 populations are 250 (12 pairs /
12 keys / 6 diffs), 225 (11 / 11 / 9), 242 (11 / 11 / 8)
and 247 (10 / 10 / 7); 26 byte-3 values carry exactly
one distinct difference (24 of them single-pair values,
plus byte 3 = 0: 2 pairs both +128, and byte 3 = 128:
6 pairs all −128).

The two multi-pair keys, in full:
- **(128, 1, 176) → −128**: `1c01b080 → 1c01b000`
  (A byte 0 = 28) and `2001b080 → 2001b000` (byte 0 = 32),
  both group (14, 9992).
- **(128, 1, 178) → −128**: `1401b280 → 1401b200`
  (byte 0 = 20) and `1801b280 → 1801b200` (byte 0 = 24),
  both group (14, 9992).

## (i)(b) Factoring tests (candidates stated before testing)

No arithmetic on (byte 1, byte 2) alone determines the
difference: all twelve pooled forms fail — x+y (38
violating keys / 91 pairs under them), x−y (42 / 97),
x^y (58 / 139), (x+y) mod 256 (53 / 127), (x−y) mod 256
(58 / 136), (x·y) mod 256 (52 / 141), x&y (43 / 180),
x|y (47 / 179), min (56 / 140), max (54 / 131), byte 1
alone (57 / 131), byte 2 alone (54 / 128). The bare pair
(byte 1, byte 2) also fails (220 keys, 2 violating: the
key (1, 176) carries diffs −128 and +128 over 3 narrow
pairs, and (128, 146) carries −1 and +3 over 2 pairs).

Conditioned on byte 3, **exactly one** of the twelve
forms determines the difference: **(byte 3, byte 1 +
byte 2) — 222 keys, zero violating keys.** It buys no
compression: its key count equals the full key's 222,
and its only multi-pair keys are the same two narrow
keys (pairs sharing (byte 3, byte 1, byte 2) also share
their sum). Every other conditioned form fails, most by
very little: (byte 3, (x+y) mod 256) fails on the single
key (250, 156) → {−5, −1}; (byte 3, byte 2) on the single
key (249, 181) → {−5, −1} (the AES-NUM-123 control);
(byte 3, x−y) on 2 keys {(242, 0) → {−9, −7},
(249, −73) → {−5, 0}}; (byte 3, x^y) on 2 keys {(242, 0),
(251, 25) → {−6, −3}}; (byte 3, byte 1) on the 2
AES-NUM-123 keys (249, 44) and (252, 84); (byte 3, min)
on exactly those same 2 keys; (byte 3, max) on 2 keys
{(241, 214) → {+1, +10}, (249, 181)}; (byte 3, (x−y)
mod 256) and (byte 3, (x·y) mod 256) on 3 keys / 6 pairs
each; (byte 3, x|y) on 6 / 13; (byte 3, x&y) on 12 / 29.

Every direct formula for the difference fails:
d = 0 matches 14/224; the sign-flip rule (+128 if
byte 3 = 0, −128 if byte 3 = 128, else 0) matches
22/224 — exactly the 8 narrow pairs plus the 14
zero-difference pairs; signed256(x+y) matches 0/224,
signed256(x−y) 2/224, signed256(y−x) 1/224,
signed256(x^y) 0/224. **Closed form NOT PROVEN**; the
(byte 3, sum) determination is a factoring of the key,
not a formula for the difference.

## (i)(c) The narrow keys' byte-0 freedom against all eight narrow pairs

The eight narrow pairs (5 in group (14, 9992), 3 in
group (19, 7712)), in full:

| group | key | A → B | A byte 0 | cell off | occ |
|---|---|---|---|---|---|
| (14, 9992) | (0, 1, 162) | `4401a200 → 4401a280` | 68 | 7424 | 27 |
| (14, 9992) | (128, 1, 176) | `1c01b080 → 1c01b000` | 28 | 1744 | 27 |
| (14, 9992) | (128, 1, 176) | `2001b080 → 2001b000` | 32 | 6944 | 27 |
| (14, 9992) | (128, 1, 178) | `1401b280 → 1401b200` | 20 | 4336 | 27 |
| (14, 9992) | (128, 1, 178) | `1801b280 → 1801b200` | 24 | 9832 | 27 |
| (19, 7712) | (0, 1, 176) | `1401b000 → 1401b080` | 20 | 7568 | 1 |
| (19, 7712) | (128, 1, 160) | `4401a080 → 4401a000` | 68 | 2880 | 1 |
| (19, 7712) | (128, 1, 177) | `1401b180 → 1401b100` | 20 | 2384 | 1 |

Six distinct keys over the eight pairs. In all eight,
B's byte 0 equals A's byte 0 and the XOR is exactly
0x80000000 (full differences −2^31 ×6, +2^31 ×2, by
byte-3 sign). The A byte-0 values pooled are
{20, 24, 28, 32, 68} — all multiples of 4.

Byte 0 is free in **both** directions. Under a fixed
key it varies without touching the difference: key
(128, 1, 176) carries byte 0 ∈ {28, 32}, key
(128, 1, 178) carries byte 0 ∈ {20, 24}, same diff
−128 throughout. And byte 0 alone determines nothing
even inside the narrow population: byte 0 = 20 carries
diffs +128 (key (0, 1, 176)) and −128 (keys (128, 1,
178) and (128, 1, 177)) over 3 pairs, and byte 0 = 68
carries +128 and −128 over 2 pairs — f(byte 0) over
the narrow eight has 5 keys, 2 violating, 5 pairs
under violating keys. The key does determine the
difference within the narrow population (6 keys,
0 violating), as it does pooled. Byte-0 values are
not narrow-exclusive: 7 non-narrow pairs share a
narrow byte-0 value (one at byte 0 = 24, six at
byte 0 = 32, all group (20, 32720)); over all 224
pairs there are 36 distinct A byte-0 values, 25 of
them carried by more than one pair.

## (ii)(a) The 189 trajectory steps as a population

All 189 delta triples (delta-A, delta-B, delta-diff)
per (cidx, block-step) are printed in full in the raw
output. Every component is **pairwise distinct over
all 189 steps**: delta-A 189 distinct (min +31,346,620,
max +394,641,536, all positive), delta-B 189 distinct
(min +32,229,224, max +392,664,128, all positive),
delta-diff 189 distinct (min −54,207,616, max
+77,121,728; 123 positive, 66 negative, 0 zero), and
the triples themselves are 189 distinct. The identity
delta-diff = delta-B − delta-A holds for all 189 steps.

The new population fact: **the steps shrink, cidx by
cidx.** For every one of the 27 cidxs, the 7 delta-A
values are in strictly decreasing order along the
blocks, and likewise the 7 delta-B values — 27/27
strictly decreasing on both sides (delta-diff
sequences: 24 neither, 3 strictly decreasing). The
per-step-index ranges descend with the step index and
are pairwise disjoint for the first three steps
(delta-A ranges: step 0: 297,586,368–394,641,536;
step 1: 232,831,360–258,952,448; step 2:
169,641,504–184,078,144; step 3: 111,223,520–
142,527,264; step 4: 72,922,480–111,513,184; step 5:
47,810,792–87,247,840; step 6: 31,346,620–68,262,624),
overlapping only slightly from step 3 on. Each step
index's 27 delta-A (and delta-B, delta-diff) values
are all distinct.

## (ii)(b) A at block k+1 as a function of A at block k

There is nothing to test a function against: **the
189 A values at block k are all distinct** — zero
collision groups pooled, and the per-step A-value sets
are pairwise disjoint across step indices (the same
holds for B). A(k+1) = f(A(k)) is therefore DETERMINED
but **VACUOUS** — recorded as vacuous, not as a law —
pooled and at every step index separately; the same
verdict holds for (k, A(k)), (cidx, A(k)), delta-A as
a function of A(k), and the B companion tests. The
non-vacuous keys fail outright: A(k+1) is not a
function of the step index alone (7 keys, all 7
violating, 27 distinct A(k+1) values at every step)
nor of cidx alone (27 keys, all 27 violating). **Step
source NOT PROVEN** — on this population A never
repeats, so no function of A(k) can earn a
non-vacuous grade either way.

## (iii)(a) The four break contexts' common core in full

The common core — acts present in ALL FOUR contexts
{114, 130, 251, 267} — is **37 acts**: the head 3-run
(0, 304, 0/1/2) at 114@8–10, 130@8–10, 251@7–9,
267@6–8, and a 34-act tail running from (2727936, 24,
2) at 114@780 / 130@783 / 251@784 / 267@783 to
(2817536, 24, 0) at position 821 in all four, through
the shared 786–817 block at identical positions in
all four — holding both 267-side break pairs at
positions 792/801 in every context. The 37 core acts
in order, with positions in each context, are printed
in full in the raw output (section iii(a)).

The core is in **identical order in all four
contexts**: core order inversions are 0 of 666 core
pairs for every one of the six context pairs,
including 130×251. Inside each context the core is
two clusters — 33 of its 36 consecutive gaps are
exactly 1 in contexts 114, 130 and 251 (32 of 36 in
267, whose head sits one position earlier), the one
large gap (770–775 acts) being the body between head
and tail. By corpus-occurrence count the core is
{271 ×30, 1060 ×2, 1058 ×1, 4 ×3, 6 ×1}: thirty
ordinary 271-acts, the three head acts, and the four
break-pair acts. The core **equals** the 114∩267
shared set and **equals** the 251∩267 shared set
(both 37); it is a proper subset of 114∩130 (39) and
of 130×251 (40).

The three 130×251 shared acts NOT in the core —
in neither 114 nor 267 — are (1052257280, 24, 2) at
130@6 / 251@824, (1062814208, 24, 0) at 130@7 /
251@822, and (1062813184, 24, 1) at 130@197 / 251@823.
They are the whole inversion story of (iii)(c).

## (iii)(b) 114×251's shared population in full

All 168 shared acts, with their positions in both
contexts, are printed in full in the raw output
(section iii(b)). The 21 runs (lengths {54: 1, 32: 1,
9: 1, 7: 1, 6: 3, 5: 1, 4: 1, 3: 7, 2: 5}) cover 160
acts; their positions (114 / 251): 8–10 / 7–9 (3),
59–60 / 61–62 (2), 73–81 / 75–83 (9), 83–85 / 85–87
(3), 88–90 / 90–92 (3), 98–102 / 100–104 (5),
**130–183 / 130–183 (54)**, 215–220 / 216–221 (6),
224–230 / 225–231 (7), 233–234 / 234–235 (2),
258–259 / 261–262 (2), 383–384 / 387–388 (2),
387–389 / 391–393 (3), 392–397 / 396–401 (6),
540–545 / 542–547 (6), 578–580 / 580–582 (3),
610–612 / 612–614 (3), 633–634 / 635–636 (2),
755–757 / 756–758 (3), 786–817 / 786–817 (32),
830–833 / 830–833 (4). The 8 isolated shared singles
are (884831744, 24, 2) @4/3, (886637056, 1040, 2)
@126/126, (886667264, 24, 1) @128/128, (899779072,
32784, 1) @751/752, (900232192, 32784, 1) @766/767,
(900421120, 18448, 0) @773/774, (2727936, 24, 2)
@780/784 and (2817536, 24, 0) @821/821.

Shared acts sit at nearly the same address in both
contexts: the position difference (251 − 114) over
the 168 acts is {−1: 4, **0: 93**, +1: 21, +2: 36,
+3: 2, +4: 12} — a majority (93) at identical
positions, none beyond +4/−1.

The 54-act run at identical positions 130–183 in
both contexts is printed act by act in the raw
output. Its 54 acts share a sharp property: **every
one of them has corpus-occurrence count exactly 2**
— each occurs in cidx 114 and cidx 251 and nowhere
else in the seven artifacts. None of the 54 is in
the common core (which lives at the head and tail,
far from 130–183).

## (iii)(c) 130×251's 110 inversions localized

The 40 shared acts are the head 3-run (130@8–10 /
251@7–9), the 32-act run at 786–817 in both, and 5
singles. All 110 inverting pairs are printed in full
in the raw output (section iii(c)). By class:
RUN×RUN inversions **0**, RUN×SINGLE **102**,
SINGLE×SINGLE **8** — no two run acts ever invert,
consistent with the core's 0 inversions.

The inversions are generated by exactly **three
displaced acts** — the size-24 singles (1052257280,
24, 2), (1062814208, 24, 0) and (1062813184, 24, 1),
which stand early in 130 (positions 6, 7, 197) but
at 251's positions 824, 822, 823 — the last three
shared positions in 251, past its final core act at
821 (in 251's order the three stand as 130-positions
7, 197, 6). Their inversion involvements are 39, 38
and 35 respectively. Every other shared act inverts
**only against those three**: the 32-act run's acts
and the two core singles each carry exactly 3
involvements, and the three head acts exactly 2 each
(they precede the 130@197 act in 251 as well, so
that act does not cross them) — 39 + 38 + 35 + 34×3
+ 3×2 = 220 = 2 × 110 (derived at closing from the
printed per-act involvements). Decomposed by
counterpart (also derived at closing): 96 inversions
are the three displaced acts crossing the 32-act
tail run, 6 are the two head-side displaced acts
(130@6, 130@7) crossing the head 3-run, 6 are the
displaced acts crossing the two core singles, and
2 are among the displaced acts themselves — the
(130@6, 130@7) and (130@6, 130@197) pairs; the
(130@7, 130@197) pair keeps its order in 251
(822 < 823).

Each displaced act occurs exactly 8 times in the
corpus, belongs to neither 114 nor 267, and is a
size-24 act — the same size class as the head and
tail acts among which 130 places two of them at
positions 6–7, immediately before its head 3-run at
8–10. Why these three acts sit at 251's end is NOT
PROVEN; the localization itself is complete: remove
the three displaced acts and 130×251's shared order
is inversion-free.

## Grades

- (i) The map is read in full (222 keys / 224 pairs /
  61 byte-3 values / 24 differences). One exact
  factoring beyond the full key: (byte 3, byte 1 +
  byte 2), at equal key count; all other stated forms
  fail with their counterexample counts recorded.
  Closed form NOT PROVEN.
- (i)(c) Byte-0 freedom over the narrow eight:
  ESTABLISHED as stated — free under a fixed key,
  and carrying no difference information alone.
- (ii) Step population: 189 distinct triples; step
  sizes strictly decreasing per cidx on both sides.
  A(k+1) as a function of A(k): VACUOUS (zero
  collisions), not a law. Step source NOT PROVEN.
- (iii) Common core: 37 acts, order-identical in all
  four contexts, equal to both 267 cross-pair shared
  sets. 114×251 shared population read in full; the
  54-act run is an occurrence-2-exclusive block at
  identical positions. 130×251's inversions are
  completely localized to three displaced acts.
  Mechanisms NOT PROVEN.

## Next (slice 4.126)

(i) the (byte 3, byte 1 + byte 2) factoring's fibres
in full, and the map's difference fibres — the 167
distinct (byte 3, difference) combinations against
their 222 keys: which keys share a (byte 3,
difference) cell, and whether a fibre's (byte 1,
byte 2) sets carry arithmetic structure; (ii) the
shrinking steps read as sequences — per-cidx
delta-A / delta-B ratios and second differences in
full over the 189 steps, testing stated decay forms
exactly; (iii) the three displaced acts' corpus-wide
profiles in full (all 8 occurrences each: artifacts,
contexts, positions, neighbours), 251's closing
segment (positions 818–841) against 130's head
(positions 0–10) in full, and the occurrence-2
exclusivity population around the 54-act run (acts
occurring exactly twice in the corpus, both times
in the 114/251 pair). Host/artifact analysis only —
no physical child.
