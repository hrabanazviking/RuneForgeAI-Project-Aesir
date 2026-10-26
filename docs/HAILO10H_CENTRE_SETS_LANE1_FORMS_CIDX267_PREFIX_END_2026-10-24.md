# The disjoint centre sets read corpus-wide, lane 1's bijection tabulated, and cidx 267 against cidx 144: the disjointness is exact only at thin length 1, but the varying centres are special everywhere in a negative way — no varying centre ever anchors a unanimous run anywhere in the corpus (0 unanimous triples at any other stratum, 0 of 18,286 unanimous ≥8 cells, 0 unanimous-word cells in any artifact, each varying centre occurring at most once per cell), while every constant centre anchors unanimity in every stratum and artifact; lane 1's 224-pair bijection carries NONE of the three closed forms (218 distinct differences, 217 distinct XORs, and the GF(2)-affine test fails with 193 residuals over 223 — a measured distribution only), most of its pairs differing in all four bytes with byte 3 shifting by small signed amounts; the in-37 bijection is per-lane wherever lanes occur (lane 0: 431 lanes, 29 ↔ 29; lane 3: 104 lanes, 8 ↔ 8; lanes 1, 2, 4 contribute zero in-37 differing lanes); cidx 267 (842 acts, all distinct, in no train) shares only 36 acts with cidx 144, its longest shared run is the same 15 acts at a constant +597 alignment, the swapped head pair sits isolated at positions 197/199 among corpus-unique neighbours with no head window of length ≥2 anywhere in the context, and cidx 144's prefix uniqueness never ends — every prefix through the full 245 acts occurs exactly once corpus-wide (AES-NUM-121)

Slice 4.121, worked under `docs/TASK_CONTRACT_4.121.md`
(contract committed first @ 28017703). Host/artifact analysis
only, on Mimir (purpleviking1) — no physical child, no
device run of any kind.

## Run and closing record

hef121.py (hef120 lineage: the inherited base extraction
plus the 4.121 arms) sha256
`ae8c168aa951c0f1d3061aa7caf64dc1e0a53bfe1615cac2ddcb2943f6539112`;
the 4.121 arms file arms121.py sha256
`646df8bba81becdf016f0973c7f72249d86a88deda1c7503f535a897a8bb884b`,
its gzip sha256
`37a5a40574380d5d7189740c534b3cbbcb66cb66503af9e7caf8d00888910df0`.
The arms gzip was split into 16 parts (15 × 373 B + 11 B)
and each part was landed on Mimir as its own file via
file.write with its own whole-part sha256 gate — all 16
parts passed their gates individually; the parts were
concatenated on-device and the whole-gzip and decompressed
arms sha256 both matched the VM exactly before anything
ran. (Two earlier whole-file chunked attempts at the arms
transfer were discarded uncommitted by the whole-file sha
gate after spliced chunks, and the first assembled run
completed controls and arms (i)/(ii) before arm (iii) hit a
KeyError on a missing record field; the fixed arms were
re-landed per-part as above and the analysis ran detached
on Mimir to DONE121, output line 11,708.) The retrieved
output is 11,708 lines / 1,579,883 B, sha256
`01040c5b9e3887933bdd9e78de61d00da897896d2d07ad27112c8471edbc635b`;
the retrieved gzip sha256
`1621d662452007357bb8242ebdd72f3934f7c3ecd8cd905fac3312f60a41e74d`
decompresses to exactly that sha256 (verified on the VM at
closing).

## Controls

All inherited controls reproduce exactly. Shared
enumeration: groups ≥2 54,995; groups ≥1 common 1,323;
cells 55,902; observations 527,236; distinct ladder 11,242;
unanimous 39,673; AP 2,584 with the same step histogram;
non-AP 4,148 (317/298/174); ≥8 cells 25,566, unanimous
18,286, 29 centres, centre-1 561; target cell once
ff010000. Divergent triples rebuild exact: A cells 6,970,
B cells 7,485, shared cidx-keyed 2,981, triples in both
5,152 (no triple with >1 cell on a side), divergent 2,171
(both-differ 1,997 / A-only 92 / B-only 82), common
instances 15,488 with centres agreeing 15,488/15,488,
extras 15,252 (A 7,164 / B 8,088), verdicts CONT 12,411 /
BREAK 476 / INDET 2,365, structure splits and triple
grades (1,679 / 72 / 420) all exact. The 37 and the 96
rebuild exact: centres 2,981/2,981, words 2,885/2,981,
37 / reverse 0, 96 cells, 1,971 differing instances (535
in the 37), centre lane 0/1,971, distinct B words 1,350.
The cc9b9d1c fit rebuilds exact: union 929, target refs
813, contexts 271, start distribution exact, 217 in-train
rows, the same 10 exception identities, trains 48/50
CONST_DOM 7. Thin population 383 (315 L1 UNANIMOUS / 58
L2 UNANIMOUS / 10 L2 AP), thin extras 2,435 (A 967 /
B 1,468); differing lanes 2,584 by lane {0: 1,086, 1: 354,
2: 0, 3: 406, 4: 738}; train 48 rank 2 = cidx 144, start 8,
steady 7, with the recorded 8-act head.

## (i) The disjoint common-centre sets read corpus-wide

The divergent triples stratify by common-instance count as
315 at length 1 (all UNANIMOUS), 68 at length 2 (58
UNANIMOUS + 10 AP), 674 at nominal 3–7 (of which 166 are
SINGLE with 0 common instances, leaving 508 with 3–7), and
1,114 at ≥8 (925 UNANIMOUS + 189 NONAP). All 5,152
triples-in-both were read: the 2,171 divergent above plus
2,981 non-divergent (identical cidx tuples).

**The exact disjointness is a property of the thin
length-1 population alone.** At every other stratum the
two sets' behaviours are not mirror images of the length-1
split; what survives corpus-wide is a one-sided asymmetry:

**No varying centre ever anchors a unanimous run, in any
population measured.** As a UNANIMOUS triple's common
centre, each varying centre occurs ONLY at length 1 (the
62: 32 ×11, 40 ×11, 43 ×11, 51 ×9, 85 ×10, 122 ×10) and
nowhere else — unanimous-centre counts at length 2, at
3–7 and at ≥8 are 0 for all six. In the mid and thick
strata the varying centres occur only as members of
non-unanimous common sequences (NONAP/AP structure),
never as the centre: 32 is a common member in 36 mid and
44 thick triples, 51 in 29 mid and 1 thick, 43 in 19 mid,
40 in 8 mid; 85 and 122 occur in NO divergent triple
beyond length 1 at all. Where they are members, their
triples' extras never equal them either (0 extras equal
to the varying centre in every stratum, against the
length-1 constant triples' 1,254/1,254 and, e.g., 4,663
extras equal to 15 among thick triples centred near it).

**The constant centres anchor unanimity everywhere.**
Every constant centre is a unanimous triple centre in
every stratum (15: 153 at length 1, 35 at length 2, 262
at 3–7, 624 at ≥8; 5: 30/22/49/111; 127: 32/0/56/32; the
smallest, 34: 2/0/3/8 and 69: 4/0/1/3). The thick
triples' 76 distinct common centres include all nine
constant centres and only two varying ones (32, 51) —
both as sequence members, neither as an anchor.

**The ≥8-cells population says the same.** Of the 18,286
unanimous ≥8 cells, ZERO are centred on a varying centre;
the constant centres carry 818 (0), 561 (1), 346 (2),
1,267 (5), 11,367 (15), 335 (23), 231 (34), 131 (69) and
1,030 (127). The varying centres do occur inside ≥8
cells — 490 (32), 618 (40), 616 (43), 577 (51), 389 (85),
47 (122) cells contain one — but only as one centre among
varying centres, never as the cell's unanimous centre.

**The full cell population (55,902 cells, all seven
artifacts) sharpens it to a per-cell law.** For every
varying centre, the number of cells containing it EQUALS
the number of observations of it (32: 674/674; 40:
724/724; 43: 770/770; 51: 848/848; 85: 509/509; 122:
217/217) — a varying centre occurs at most once in any
cell, anywhere, and zero unanimous-word cells are centred
on it in any artifact. This holds beyond the mirror pair
(453/470/440/540/320/161 of those cells sit in the other
five artifacts). The constant centres repeat without
limit by contrast (15: 298,610 observations in 31,821
cells, 24,276 unanimous-word cells; 5: 26,761 obs; 0:
20,230 obs; 127: 29,481 obs).

**The non-divergent triples agree.** Of the 2,981, 2,520
have all instances at one single centre; the single-centre
values are {0: 176, 1: 12, 2: 21, 5: 284, 7: 21, 11: 37,
15: 1,708, 23: 15, 34: 40, 69: 9, 95: 5, 127: 191, 139: 1}
— no varying centre is ever the single centre (0 for all
six), even though varying centres occur inside
non-divergent triples' varying sequences (43 in 125
triples, 51 in 115, 40 in 93, 85 in 45, 32 in 5, 122 in
none).

**Extras carrying a varying centre are rare.** Corpus-wide,
extras whose own centre is 51 or 85 number ZERO; 43 has
10 (all INDET, in NONAP mid triples), 40 has 30 (CONT 18 /
INDET 12, NONAP thick), 32 has 9 (all BREAK — one per
varying AP triple, the clone sequence's own 32), 122 has
7 (BREAK, length-1 UNANIMOUS). Constant-centre extras
number in the hundreds to thousands per centre (15:
8,141).

**Grade.** Measured, on the complete populations: the
disjoint centre sets of AES-NUM-120 are a property of the
thin length-1 population in their exact form, but the
varying set is special corpus-wide in the negative —
its centres never anchor unanimity anywhere (triples of
any length, ≥8 cells, single-centre non-divergent triples,
unanimous-word cells in any of the seven artifacts) and
never repeat inside a cell, while the constant set's
centres anchor unanimity in every stratum and artifact.
Why either set has the membership it has: NOT PROVEN;
no cause invented.

## (ii) Lane 1's 224-pair bijection tabulated; the in-37 bijection split per lane

Population: the 224 distinct (A, B) pairs of lane 1
(354 differing lanes), A and B little-endian u32 lane
values, all counted exactly.

**None of the three closed forms holds.**
- Constant difference: 218 distinct differences over the
  224 pairs (positive 50, negative 174, never 0). The
  only repeated differences are −2^31 (6 pairs) and
  +2^31 (2 pairs); the remaining 216 pairs each carry a
  difference seen once. Zero-residual claim: FALSE.
- Constant XOR: 217 distinct XOR patterns. The top
  pattern 0x80000000 covers 8 pairs; every other pattern
  covers at most 1. Zero-residual claim: FALSE.
- GF(2)-affine: the A-difference span has rank 30; of
  the 223 non-base pairs, 193 are INCONSISTENT with the
  affine map fitted on the span (residuals 193/223);
  the fitted-map check over all 224 pairs gives 193
  wrong predictions and 0 unpredictable. Zero-residual
  claim: FALSE. Lane 1's bijection is therefore a
  measured distribution only — a strict bijection with
  no constant-difference, constant-XOR or GF(2)-affine
  form over its full population.

**Byte structure of the 224 pairs.** Pairs differ in
{1: 8, 2: 3, 3: 46, 4: 167} of their four bytes — most
lane-1 pairs differ in ALL FOUR bytes, the opposite
shape from the pooled differing lanes (AES-NUM-120:
1,648 of 2,584 in exactly one byte). Byte 0 is the most
structured byte: 44 pairs share it exactly; its XOR
takes 30 distinct values, topped by 0x80 (34), 0xc0 (24),
0x40 (20), 0x60 (12), 0xa0 (12). Bytes 1 and 2 are
near-unique per pair (XOR distinct 143 and 144 of 224;
signed diffs distinct 168 and 169). Byte 3 moves least
in variety: only 24 distinct signed differences, topped
by −1 (43 pairs), −7 (17), −8 (16), −2 (15), −5 (15),
0 (14) — B's top byte is usually A's top byte minus a
small amount; its XOR takes 40 distinct values topped by
0x1 (29), 0x3 (21), 0x7 (17), 0x2 (15). A values span
10,617,156..4,235,285,620, B values 10,486,084..
4,232,618,376; XOR bit-counts spread 1..20 (mode 11,
31 pairs).

**The in-37 bijection split per lane.** The 535 in-37
differing lanes occur in exactly two lanes: lane 0 with
431 lanes (29 distinct A ↔ 29 distinct B ↔ 29 distinct
pairs) and lane 3 with 104 lanes (8 ↔ 8 ↔ 8). BOTH are
strict bijections per lane — zero counterexamples in
either direction in each. Lanes 1, 2 and 4 contribute
ZERO in-37 differing lanes. So the pooled in-37 bijection
of AES-NUM-120 is not a pooling artifact: it holds lane
by lane wherever in-37 differing lanes exist (and lane 1,
the pooled bijection's other home, simply has no in-37
lanes at all).

**Grade.** Form claims are made only in the strict
zero-residual sense and all three FAIL for lane 1; the
in-37 per-lane bijections pass with zero counterexamples
over their full populations. What produces lane 1's
bijection or its byte structure: NOT PROVEN.

## (iii) cidx 267 against cidx 144; cidx 144's prefix uniqueness past length 40

**cidx 267 whole.** It is an 842-act context (ng 1,
start 6), all 842 acts distinct, and it is NOT a member
of any train in the cc9b9d1c fit (no train row carries
cidx 267). Against cidx 144 (245 acts, all distinct):
act multiset overlap 36, set overlap 36, set union 1,051.

**Shared contiguous runs: only four of length ≥3.** The
longest is 15 acts — the very run AES-NUM-120 found at
cidx 144 position 206, here at cidx 267 position 803.
The other maximal runs are 7 acts (144 pos 197 ↔ 267
pos 794), 5 acts (144 pos 190 ↔ 267 pos 787) and 3 acts
(144 pos 8 ↔ 267 pos 6). The first three sit on ONE
alignment: 267 position − 144 position = +597 in each
case, i.e. a single aligned region (144 positions
190–220 ↔ 267 positions 787–817) broken into three runs;
the 3-act run is the corpus-common material immediately
after 144's head (positions 8–10), recurring at 267
positions 6–8, right after its start.

**The 197–199 window in both contexts, in full.** In
cidx 267: position 197 is the head position-6 act
(1225501696, 24, 0); position 198 is (2215660544, 296,
2), corpus-unique; position 199 is the head position-5
act (1225501184, 24, 2). The whole neighbourhood is
lonely: positions 194, 195, 196, 198, 200, 201, 202 are
each corpus-unique acts (exactly 1 occurrence each), so
the swapped pair sits in a stretch of cidx 267 found
nowhere else. In cidx 144 the same positions 194–202
hold corpus-common material (occurrence counts 271, 27,
54, 271, 271, 271, 271, 271, 271) — nothing of the head
pair is there; in 144 the pair lives only at its own
head positions 5 and 6.

**No other head act, and no head window, occurs in
cidx 267.** Of the eight head acts, only the position-5
and position-6 acts occur in 267 (once each, as above);
the position-0 act and the five corpus-unique acts are
absent. And no contiguous head window of length ≥2
occurs in 267 at all (lengths 8 down to 2 were each
checked over every head start position: all empty) —
the pair recurs as two isolated single acts, order
swapped, one act apart, not as any fragment of the head
sequence.

**cidx 144's prefix uniqueness past length 40: it never
ends.** The length-41 prefix occurs exactly once
corpus-wide by direct full scan (at cc9b9d1c cidx 144,
position 0), and the occurrence count stays exactly 1 at
every length from 41 to 245 — sampled and recorded at
41, 42, 50, 75, 100, 150, 200, 244 and 245, with every
intermediate length counted by extension of the single
candidate (any longer occurrence must extend the
length-41 one). Independent direct full scans at lengths
100 and 245 confirm count 1 at (cc9b9d1c, 144) position
0. There is NO first repeated prefix: the uniqueness
runs to the end of the context, so cidx 144's entire
245-act sequence occurs exactly once in the seven
artifacts.

**Grade.** All counts measured over the complete
populations named. The +597 alignment, the swapped
pair's isolation, and the whole-context uniqueness are
measured facts; any mechanism behind them: NOT PROVEN;
none invented.

## Next

Slice 4.122 — (i) the varying centres as sequence members:
the mid/thick triples whose common sequences pass through
32/40/43/51 — where in those sequences do the varying
centres sit (endpoints or interior, on-step or off-step),
and the OTHER single-centre values {7, 11, 95, 139} that
DO anchor non-divergent unanimity without belonging to
the constant set — what separates them from the varying
six?; (ii) lane 1's formless bijection read against
position: the 224 pairs split by cell/group (the pairs
repeat in blocks of 27), and byte 3's small-difference
law tested as a function of A's byte 3; (iii) the +597
aligned region between cidx 144 and cidx 267 read in
full (144 positions 190–220 against 267 positions
787–817: what breaks the runs, what flanks them), and
cidx 267's own occurrence profile (how many of its 842
acts are corpus-unique, common, or shared with exactly
one other context). Host/artifact analysis only — no
physical child.
