# AES-NUM-116 — the mirror pair 5ab3537d/773470cd is centre-perfect on every shared cell (centres equal on 2,981 of 2,981 shared cells and on all 48,988 shared instance observations, with zero differing centre lists; the full neighbourhood words agree on 2,885 of 2,981, the remaining 96 sharing their centres but differing in flanking words), and the pair diverges instead by membership (3,989 cells analysable only in 5ab3537d, 4,504 only in 773470cd; 2,171 (pos, segsize, offset) triples present in both carry different cidx tuples, typically one extra instance in 773470cd extending the centre sequence by one term) and by its <8 centre sets (5ab3537d's 13 values a strict subset of 773470cd's 21), while its ≥8 centre set is verified identical at 13 values with near-identical counts; the train 48/50/51 steady exceptions number exactly 10 (4/2/4) under the reproduced (train, rank regime) fit, of which nine sit +1 above their train's steady value and one — train 50's last rank — sits −1 (a correction to the inherited "all +1" wording), and the head-act explanation covers some of them, not all and not none: seven carry the full train-49 signature (non-modal first act, modal act before the triple, identical triple block, and the pre-triple window equal to a rank neighbour's, two of them with an exact head-insertion alignment), while three carry a head mark but no shift alignment (the adjacent train-48 ranks 1–2 pair, each with a unique act before the triple, and train 50's −1 last rank); and no centre ≥192 occurs at ≥8 anywhere in the corpus — the 23 high values live in 49 <8 unanimous cells in total, 38 of them cc9b9d1c's (20 values, every cell at group size 2), with 255's ≥8 absence in 0a0d378c verified as the same small-group rarity (its two <8 cells are the only high-centre cells in the corpus with group size above 2, at 5 and 7)

Slice 4.116, worked under `docs/TASK_CONTRACT_4.116.md`
(contract committed first @ 3356a706). Host/artifact
analysis only, on Mimir (purpleviking1) — no physical
child, no device run of any kind.

## Run and transfer record

hef116.py was built locally (hef115 base extraction —
everything in hef115.py before its 4.115 arms marker —
plus the new 4.116 arms): arms sha256 97e6fae0…, script
sha256 f45638fb…, gz sha256 a6d1afad… (saved:61485 on
the proxy upload through the one-shot receiver
recv116.py, local sha256 957d6f2d…; gz and script
sha256 verified on-device, py_compile passed), ran
detached over the 7-artifact corpus to DONE116 at
line 11,440, output 1,584,315 B, sha256 ce267d39…
(retrieved gz sha256 389b173c… verified identical
both sides).

## Controls

All controls reproduce exactly: 128,787 small actions;
79,001 bursts; 745,849 pointer actions; 1,504 contexts;
2,049 trailing pairs; 75,215 champion bursts; TRAINS
52 / unique-first 28 / unanimous 13 / elsewhere 11 /
D113 249 / FIRST-D 3,089 / CTRL-D 176; CAMPS A
21392/13, B 21648/12. The inherited DONE markers stand
at the same lines as in the AES-NUM-115 run (DONE105
at line 3,576, DONE106 at 3,670, DONE107 at 3,701,
DONE108 at 3,910). Arm-level controls also reproduce
exactly: the shared enumeration gives 54,995 groups
with ≥2 instances, 1,323 with ≥1 common offset,
55,902 analysable cells and 527,236 instance-cell
observations (by artifact: 0856a10c 12,631; 0a0d378c
7,854; 5ab3537d 6,970; 76c3a8ff 9,470; 773470cd
7,485; MiniLM 4; cc9b9d1c 11,488); 11,242 all-distinct
ladder cells; 39,673 unanimous cells; the AP subset
is 2,584 cells with the exact AES-NUM-112/113 step
distribution {0: 352, +2: 26, +3: 489, +4: 741, +6:
164, +8: 350, +9: 217, +12: 200, +24: 34, +40: 11};
the non-AP subset is 4,148 cells with distinct-
difference counts {2: 1,877, 3: 1,317, 4: 797, 5:
157} and 317 ordered / 298 multiset / 174 set
profiles; the cc9 rare-class union is 929; the 813
target segment is oo 0, size 304, 813 references; the
start distribution reproduces AES-NUM-112/113 exactly
(4×1, 5×47, 6×31, 7×83, 8×56, 9×44, 10×9); ≥8-instance
cells 25,566 with 18,286 unanimous and 29 distinct
centres, centre 1 at 561; and the 773470cd
pos-9/size-32784 offset-11608 cell is found in the
≥8 unanimous set exactly once, centre ff010000.

## (i) The mirror pair anatomised

Throughout, A = 5ab3537d and B = 773470cd.

### Groups

Counting every (pos, segsize) group, singletons
included: A carries 10,286 groups, B 10,196; 8,959
(pos, segsize) keys are shared, 1,327 occur only in
A and 1,237 only in B. Restricting to the groups the
shared enumeration uses (≥2 instances): A 7,531,
B 7,707, shared 6,464, only-A 1,067, only-B 1,243.

Of the 8,959 shared groups, only 2,890 carry an
identical (cidx, ng) instance list; 6,069 differ —
and in no case is a difference an ng-only difference
(0 of the 6,069 keep the same cidx list): whenever
the instance lists differ, the cidx membership
itself differs, in size and usually in content.
The mirror group of AES-NUM-115, (21, 32776), is
one of the identical ones: present in both artifacts
at n = 10 with the same instance list.

### Shared cells: centres never diverge

Cells are keyed by (pos, segsize, off, cidx-tuple).
A contributes 6,970 analysable cells, B 7,485 (no
key collisions in either). Exactly 2,981 keys are
shared; 3,989 cells exist only in A and 4,504 only
in B. One level up, 5,152 (pos, segsize, off)
triples occur in both artifacts, but only 2,981 of
them carry the same cidx tuple — the other 2,171
are membership divergences at a shared address,
treated below.

On the 2,981 shared cells the mirroring is exact
where centres are concerned:

- Centre lists equal: 2,981 of 2,981 (100%). The
  number of shared cells with differing centre
  lists is 0.
- Per-instance centre equality: 48,988 of 48,988
  shared instance observations (100%).
- Centre words and per-instance zero counts also
  agree on all 2,981.
- Full five-word neighbourhoods equal: 2,885 of
  2,981 (96.78%). The remaining 96 cells share
  their centres exactly but differ in flanking
  neighbourhood words (for example a run at pos 12,
  segsize 32728, centres all 127 on both sides).
- The 2,386 cells unanimous on both sides all
  carry the same centre on both sides (0 differing).

Breakdowns per artifact (unanimous / all-distinct /
other; AP and non-AP among the all-distinct cells
of length ≥3): A overall 5,653 / 1,191 / 126 with
521 AP and 399 non-AP; B overall 6,120 / 1,209 /
156 with 595 AP and 363 non-AP. On the shared
subset the two sides nearly coincide: A 2,423 /
481 / 77 (447 AP, 19 non-AP), B 2,386 / 496 / 99
(449 AP, 19 non-AP). The joint classification of
shared cells is: both unanimous 2,386; both
all-distinct 479; both other 73; A unanimous but B
all-distinct 13 and B other 24; A all-distinct but
B other 2; A other but B all-distinct 4 — and no
cell is unanimous in B without being unanimous in
A. Every B-unanimous shared cell is A-unanimous;
A holds 37 extra unanimous shared cells.

Centre distributions make the same point in counts.
Unanimous-centre distributions over all cells
differ by an L1 distance of 499, driven by centre
127 (A 495, B 792) and centre 15 (A 3,591, B
3,729) — B simply carries more unanimous cells.
On the shared subset the L1 distance collapses to
37, and the entire residue sits in two values:
centre 15 (A 1,651, B 1,623) and centre 127 (A 151,
B 142); the other eleven shared-subset values have
identical counts on both sides. That 37 is exactly
the 37 cells unanimous in A but not in B, carrying
centres 15 (28 cells) and 127 (9 cells) on the A
side.

### Where the pair diverges

The divergence is membership, not content:

- Groups present in only one artifact: 1,327 (A)
  and 1,237 (B) counting singletons; 1,067 and
  1,243 at ≥2 instances.
- Cells present in only one artifact: 3,989 (A:
  3,230 unanimous, 710 all-distinct, 49 other) and
  4,504 (B: 3,734 unanimous, 713 all-distinct, 57
  other), spread over many (pos, segsize) groups
  (largest single contributors ≈ 90–160 cells per
  group per side).
- The 2,171 (pos, segsize, off) triples present in
  both but with different cidx tuples: the typical
  anatomy is one extra instance in B inserted into
  the stride pattern, extending the centre sequence
  by exactly one term. Example (pos 10, segsize
  21808, repeatedly): A carries cidxs [103, 111,
  115, 119, 123, 127] where B carries [103, 107,
  111, 115, 119, 123, 127]; at offset 112 the
  centres read [9, 17, 21, 25, 29, 33] in A and
  [9, 13, 17, 21, 25, 29, 33] in B — B's inserted
  cidx 107 contributes centre 13 and the shared
  instances keep their centres in order. At most
  such triples the shared instances are unanimous
  on both sides (centres 15 or 7 or 95 repeated).
  Whether the insertion anatomy holds pair-wide,
  and what determines the inserted centre, is not
  established by this run: NOT PROVEN as a rule;
  the next slice takes it up.
- The 96 shared cells with identical centres but
  differing flanking words: which neighbourhood
  position carries the difference is not separated
  by this run — recorded, not graded.
- The <8 centre sets (next section's frame):
  A's 13 values {0, 1, 2, 5, 7, 11, 15, 23, 34, 69,
  95, 127, 239} are a strict subset of B's 21
  values; B adds {4, 17, 50, 192, 224, 233, 252,
  255}, each in very few cells (192 in 2 cells, the
  rest in 1 each). At ≥8 the sets are verified
  identical — the same 13 values {0, 1, 2, 5, 7,
  11, 15, 23, 34, 69, 95, 127, 139} — with
  near-identical counts (15 at 2,326 vs 2,384; 127
  at 223 vs 234; 5 at 448 vs 450; every other value
  within 6). The AES-NUM-115 observation that 139
  is "replaced by 239" in A's <8 set is, in this
  fuller frame, simply B keeping both: 139 lives
  at ≥8 in both artifacts (1 cell each) and neither
  artifact carries 139 at <8.

Verdict: how deep the mirroring goes is measured —
on shared cells it is total at the centre level
and 96.78% at the full-neighbourhood level; the
pair diverges in which groups, instances and cells
exist at all, and in the <8 tail of the centre
distribution. No tested field explains why a given
group or instance exists in one artifact only:
NOT PROVEN.

## (ii) The 10 steady exceptions under train 49's treatment

The (train, rank regime) formalisation of
AES-NUM-114/115 reproduces exactly: trains 44–47
exact after heads of 1/2/1/3 ranks; train 49 CONST 9
priced as an 11-rank head by the exact-fit formalism;
trains 48/50/51 constant-dominant (CONST_DOM) with
steady values 7/7/5, heads 0/1/0, and steady
exceptions at exactly the recorded ranks — train 48
(245 acts, run 136..244) ranks 1, 2, 11, 12; train
50 (606 acts, run 143..247) ranks 10, 26; train 51
(738 acts, run 142..246) ranks 4, 9, 10, 25: ten
exceptions, 4/2/4.

One correction to the inherited wording: nine of
the ten sit exactly +1 above their train's steady
value, but train 50's rank-26 exception (cidx 247,
the train's last rank) starts at 6 against a steady
7 — it is −1, not +1. The exception identities and
counts are exactly as recorded in AES-NUM-114/115;
the "all exactly +1" summary of them was not exact
for this one rank, and the record is corrected
here.

The ten contexts (train, rank idx, cidx, steady →
actual): (48, 1, 140, 7→8), (48, 2, 144, 7→8),
(48, 11, 180, 7→8), (48, 12, 184, 7→8), (50, 10,
183, 7→8), (50, 26, 247, 7→6), (51, 4, 158, 5→6),
(51, 9, 178, 5→6), (51, 10, 182, 5→6), (51, 25,
242, 5→6). All ten carry target positions exactly
at their start (tgtpos [start, start+1, start+2]).

What all ten share:

- The target triple block is the identical
  ((0, 304, 0), (0, 304, 1), (0, 304, 2)) — equal
  to both rank neighbours' triple blocks in every
  case (19 of 19 neighbour comparisons; train 50's
  rank 26 has only one rank neighbour).
- The acts after the triple (next_act (0, 304, 1),
  next2_act (0, 304, 2)), the target count (3),
  ngidx mod 4 and cidx mod 4 are the train's
  universal values in every case.
- Every exception's first act is non-modal in its
  train — a head mark in all ten (train modals:
  (60413952, 24, 1) ×23/28 in train 48;
  (1244660736, 24, 1) ×21/27 in train 50;
  (5647872, 24, 2) ×22/27 in train 51).
- The post-triple window never equals a neighbour's
  (post-triple acts carry per-context segment
  addresses, as in train 49 — alignment there is a
  matter of progression, not equality).

The split comes at two further tests: whether the
act before the triple (prev_act) is the train's
modal value, and whether the pre-triple window
(acts at start−3..start−1) equals a rank
neighbour's, or the exception's prefix with its
first act removed aligns exactly with a neighbour's
prefix (the pure head-insertion test of train 49's
anatomy).

### The seven with the full head-cause signature

- Train 48 rank 11 (cidx 180) and rank 12 (cidx
  184): prev_act is the train modal (1255554048,
  24, 0); the pre-triple window equals both rank
  neighbours'; and each satisfies the pure
  head-insertion alignment against one neighbour
  (rank 11 against rank 10, rank 12 against rank
  13). Their opening pairs are (49867264, 24, 2),
  (60413952, 24, 1) and (1524509696, 24, 0),
  (60413952, 24, 1) — the second act is the train's
  modal first act itself: one extra act stands in
  front of the modal opening, exactly train 49's
  mechanism.
- Train 50 rank 10 (cidx 183): prev_act modal
  (30589440, 24, 0), held by all 24 steady members;
  pre-triple window equal to both neighbours';
  head-insertion alignment against neither. First
  act (1513927680, 24, 2), unique in the train.
- Train 51 ranks 4, 9, 10, 25 (cidxs 158, 178, 182,
  242): prev_act is the shared value (33324544,
  24, 1) carried by 25 of the other 26 members;
  pre-triple window equal to both neighbours' in
  all four; head-insertion alignment against
  neither. Three of the four (ranks 4, 9, 25) share
  one first act (961269248, 24, 2) and one opening
  pair ((961269248, 24, 2), (964698624, 24, 0))
  among themselves — a repeated head form, not a
  per-context accident; rank 10's first act
  (36127744, 24, 2) is shared with one other member
  and its opening pair is unique.

Classification (these seven): an extra head act —
or, where the pure insertion alignment does not
fire, a head-region difference with the identical
shifted pre-triple window — shifts the identical
triple block by one position; every other tested
field is modal or universal. Head cause MEASURED,
in train 49's exact form for train 48's ranks
11–12 and in the window-equality form for the
other five.

### The three without shift alignment

- Train 48 ranks 1 and 2 (cidxs 140, 144) are
  adjacent exceptions, each the other's rank
  neighbour, immediately after the train's head
  rank 0 (itself start 7). Both carry unique first
  acts ((1036991488, 24, 2) and (961269248, 24, 2),
  each held by that context alone) and unique
  prev_acts ((93162496, 24, 1) and (1225501720,
  24, 0) — the modal prev_act (1255554048, 24, 0)
  is held by 25 of the other 27 members). Neither
  the pre-triple window nor the head-insertion
  alignment matches any rank neighbour, including
  the steady rank 0 beside the pair. A head mark
  is present; the shift is NOT PROVEN for these
  two — with two adjacent exceptions, a shared
  two-context head event is possible but no tested
  field establishes it.
- Train 50 rank 26 (cidx 247) is the −1 exception
  and the train's last rank, so it has a single
  rank neighbour (rank 25, start 7). Its first act
  (1513926144, 24, 1) is non-modal and its prev_act
  (900765184, 24, 1) is unique against the modal
  (30589440, 24, 0) held by all other 25 members
  shown; no window or insertion alignment fires.
  A head mark is present; the mechanism of a −1
  shift (one fewer head act would be the mirror
  guess) is NOT PROVEN on this evidence.

Population verdict: the head-act explanation
covers SOME of the ten — 7 measured, 3 with a head
mark but no measured shift — not all and not none.
The split is clean on one field: prev_act is modal
(or the train's shared value) for exactly the
seven measured exceptions and unique for exactly
the three others. Train 49's mechanism is
therefore not unique, but it is not the whole
story of the steady exceptions either.

## (iii) The <8-only high centres (≥192)

No centre ≥192 occurs at ≥8 anywhere in the
corpus: the ≥8 centre set's maximum is 191, and
the list of ≥192 values present at ≥8 is empty.
The ≥192 population lives entirely in the <8
unanimous frame: 23 distinct values {192, 199,
210, 212, 224, 228, 230, 233, 235, 238, 239, 240,
243, 245, 246, 247, 248, 249, 250, 251, 252, 254,
255} in 49 cells in total.

Per artifact (<8 unanimous cells with centre
≥192):

- cc9b9d1c: 38 cells over 20 values (below).
- 773470cd: 7 cells over 6 values — 192 ×2 (pos
  529/589, segsize 20496, offsets 6488/9336), 224,
  233, 239, 252, 255 ×1 each; every cell at group
  size 2; all but 252 (segsize 26128) and 255
  (segsize 32784) at segsize 20496.
- 0a0d378c: 2 cells, both centre 255 (below).
- 0856a10c: 1 cell, centre 254 (pos 287, segsize
  12560, offset 3704, group size 2).
- 5ab3537d: 1 cell, centre 239 (pos 535, segsize
  26128, offset 20096, group size 2).
- 76c3a8ff: 0 cells. MiniLM: 0 cells.

### cc9b9d1c's cluster in full

cc9b9d1c's <8 set carries 47 values; its ≥192
tail is 20 values in 38 cells: 199 ×9; 249, 250,
251 ×3 each; 240, 243, 245, 246 ×2 each; 210, 212,
228, 230, 233, 235, 238, 247, 248, 252, 254, 255
×1 each. Every one of the 38 cells has group size
exactly 2 — the cluster's group-size profile is
uniform. None of the 20 values occurs in
cc9b9d1c's own ≥8 set, and none occurs at ≥8
anywhere in the corpus. Most are cc9b9d1c-only
even at <8 (corpus <8 counts equal cc9b9d1c's own
counts); the exceptions are 233 (2 corpus cells:
one cc9b9d1c, one 773470cd), 252 (2: same split),
254 (2: one cc9b9d1c, one 0856a10c) and 255 (4:
below). The three corpus ≥192 values cc9b9d1c does
not carry are 192 and 224 (773470cd only) and 239
(5ab3537d + 773470cd).

Positionally the cluster concentrates: centre 199
spreads over pos 145/147/318/409 (segsizes 13872–
32680, nine offsets listed in the run output);
most of the remaining values sit at pos 38 with
segsize 17936 (228, 235, 238, 243 ×2, 246 ×2, 249,
251, 252), at pos 386/267 with segsize 14864 (210,
240 ×2, 250 ×3), or at pos 636 with segsize 17936
(247, 248, 251 ×2). The values read as scattered
singletons and small repeats inside a few small
groups — no ladder or shape organises them, and
no tested field here separates them: any deeper
structure is NOT PROVEN on this run's tests.

### 255's record

- 0a0d378c: exactly 2 <8 cells, both at pos 16,
  offset 11888, centre word ffff0000: (segsize
  32600, group size 7, cidxs [98, 104, 110, 122,
  128, 146, 158]) and (segsize 32712, group size
  5, cidxs [92, 116, 134, 152, 164]). Its ≥8 count
  is 0 — the absence is verified, and with it the
  AES-NUM-115 statement that 255 completes
  0a0d378c's 2^k−1 family only in the <8 frame.
  These two cells are the only ≥192 cells in the
  whole corpus with group size above 2.
- Every other artifact: 773470cd 1 <8 cell (pos
  24, segsize 32784, offset 19836, group size 2),
  ≥8 0; cc9b9d1c 1 <8 cell (pos 101, segsize 1296,
  offset 324, group size 2), ≥8 0; 0856a10c,
  5ab3537d, 76c3a8ff and MiniLM 0 in both settings.
- Corpus: 255 lives in 4 <8 unanimous cells across
  three artifacts and in 0 ≥8 cells.

Verdict: the high centres are the vanishing
population's upper tail and behave exactly like
it — 47 of the 49 ≥192 cells sit at group size 2,
the other two at 5 and 7; no ≥192 value reaches a
group of 8 anywhere. 255's ≥8 absence in
0a0d378c is the same small-group rarity effect as
the other vanishing centres, not a separate
phenomenon: MEASURED as a population statement;
any mechanism assigning these particular values
to these particular small groups is NOT PROVEN.

## Grades

- Shared enumeration and all inherited controls:
  reproduced exactly (55,902 cells; 527,236
  observations; 11,242 distinct ladder cells;
  39,673 unanimous cells; AP subset 2,584 with
  the AES-NUM-112 step distribution; non-AP
  subset 4,148 with 317/298/174 profiles; 813
  start distribution; 929 union; ≥8 cells 25,566
  / unanimous 18,286 / 29 centres / centre-1 561;
  target cell in-set once): MEASURED.
- Mirror pair, shared cells: centres equal on
  2,981/2,981 shared cells and 48,988/48,988
  instance observations, zero differing centre
  lists, both-unanimous 2,386 with zero centre
  disagreements; full neighbourhoods equal on
  2,885/2,981 (96.78%), 96 cells centre-equal but
  word-different: MEASURED. B-unanimous ⊆
  A-unanimous on shared cells, the 37-cell residue
  entirely centres 15 (28) and 127 (9) on the A
  side; shared-subset distribution L1 = 37 against
  all-cells L1 = 499: MEASURED.
- Mirror pair, divergence: shared groups 8,959
  (2,890 with identical instance lists, 6,069
  differing in cidx membership, 0 ng-only);
  only-A 1,327 groups / 3,989 cells, only-B 1,237
  groups / 4,504 cells; 2,171 shared triples with
  different cidx tuples: MEASURED as a census.
  The one-extra-instance insertion anatomy is
  measured at its examples; as a pair-wide rule,
  and any field explaining existence in one
  artifact only: NOT PROVEN.
- Mirror pair, centre sets: ≥8 sets verified
  identical (13 values, counts within 6 per
  value); <8 sets 13 (A) ⊂ 21 (B), B-only {4, 17,
  50, 192, 224, 233, 252, 255}: MEASURED.
- The 10 exceptions: fit reproduced exactly
  (4/2/4 at the recorded ranks); nine at +1 and
  train 50 rank 26 at −1 above/below steady 7 —
  the inherited "all +1" wording corrected:
  MEASURED. Triple block identical to neighbours
  in all ten; head mark (non-modal first act) in
  all ten: MEASURED. Head cause in train 49's
  form: MEASURED for 7 (train 48 ranks 11/12 with
  exact head-insertion alignment; train 50 rank
  10 and train 51 ranks 4/9/10/25 with modal
  prev_act and neighbour-equal pre-triple
  windows); for train 48 ranks 1/2 and train 50
  rank 26 a head mark is present but the shift
  is NOT PROVEN. Population: the head-act
  explanation covers some of the ten, not all.
- High centres: no ≥192 centre at ≥8 anywhere
  (empty list, corpus ≥8 maximum 191); 23 values
  in 49 <8 cells (cc9b9d1c 38 cells / 20 values,
  all group size 2; 773470cd 7/6; 0a0d378c 2;
  0856a10c 1; 5ab3537d 1; 76c3a8ff and MiniLM 0):
  MEASURED. 255's 0a0d378c record (2 <8 cells at
  pos 16 / offset 11888, sizes 32600/32712, group
  sizes 7/5; ≥8 zero) and its corpus record (4 <8
  cells, 0 ≥8): MEASURED. Any organising shape or
  mechanism for the high values: NOT PROVEN.

## Next (slice 4.117)

(i) The mirror pair's 2,171 membership-divergent
triples: is the one-extra-instance anatomy general
(which side carries the extra instance, where it
sits in cidx order, and does the inserted
instance's centre continue the cell's centre
sequence — ladder, AP or unanimity — or break
it)? (ii) The two residue classes of arm (i): the
37 shared cells unanimous in 5ab3537d but not in
773470cd (which instance and which word breaks
unanimity on the B side?) and the 96 shared cells
with identical centres but differing flanking
words (which neighbourhood position differs, and
is the differing word shared with anything?).
(iii) The three unshifted exceptions: the train-48
ranks 1–2 adjacent pair (do the two contexts share
head material with each other that neither shares
with the train?) and train 50's −1 last rank (is
its head one act SHORTER than its neighbours'
heads — the mirror of the insertion test)?
Host/artifact analysis only — no physical child.
