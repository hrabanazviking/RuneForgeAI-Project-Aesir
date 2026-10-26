# AES-NUM-113 — the per-cell ladder's (base, step) pair is a function of no tested group/offset field (only 72 distinct pairs occur among 2,584 AP cells, step is strongly conditioned by artifact and cell length, and (base, length) nearly determines step at 89 of 92 keys — graded NOT PROVEN as a function); the 813 triple's start is not a function of sub-sequence position either, but inside each stride-4 train the starts collapse to a near-constant or period-2 pattern after a short head transient (lag-8 agreement 0.6996 against a 0.2071 chance level, the noted 8-block repeating verbatim 12 times); and in the 11608 setting proper (groups of ≥8 instances) unanimity holds at the corpus rate (18,286 of 25,566 cells, 71.52%), the centre population narrows to 29 values with ff0f0000 at 62.16%, ff010000 slightly over-represented at 3.07% against its 2.56% corpus share — and the unanimous centre is a function of no tested group/offset field

Slice 4.113, worked under `docs/TASK_CONTRACT_4.113.md`
(contract committed first @ c4081cdf). Host/artifact
analysis only, on Mimir (purpleviking1) — no physical
child, no device run of any kind.

## Run and transfer record

hef113.py was built locally (hef112 base extraction —
everything in hef112.py before its 4.112 arms marker —
plus the new 4.113 arms, hef113_arms.py sha256
9f297504…). Script sha256 f6249610…, gz sha256
62d3b58a… (saved:59170 on the proxy upload through
the one-shot receiver recv113.py, sha256 af4d80a2…
verified identical on both sides; gz and script
sha256 verified on-device, py_compile passed), ran
detached over the 7-artifact corpus to DONE113 at
line 11,061, output 1,507,707 B, sha256 ab3c3a01…
(retrieved gz sha256 97595030… verified identical
both sides). One run; no rerun was needed.

## Controls

All controls reproduce exactly: 128,787 small actions;
79,001 bursts; 745,849 pointer actions; 1,504 contexts;
2,049 trailing pairs; 75,215 champion bursts; TRAINS
52 / unique-first 28 / unanimous 13 / elsewhere 11 /
D113 249 / FIRST-D 3,089 / CTRL-D 176; CAMPS A
21392/13, B 21648/12. The inherited DONE markers stand
at the same lines as in the AES-NUM-112 run (DONE105
at line 3,576, DONE106 at 3,670, DONE107 at 3,701,
DONE108 at 3,910). Arm-level controls also reproduce
exactly: the shared enumeration gives 54,995 groups
with ≥2 instances, 1,323 with ≥1 common offset,
55,902 analysable cells and 527,236 instance-cell
observations (by artifact: 0856a10c 12,631; 0a0d378c
7,854; 5ab3537d 6,970; 76c3a8ff 9,470; 773470cd
7,485; MiniLM 4; cc9b9d1c 11,488); 11,242 all-distinct
ladder cells; 39,673 unanimous cells; the AP subset
is 2,584 cells with the exact AES-NUM-112 step
distribution {0: 352, +2: 26, +3: 489, +4: 741, +6:
164, +8: 350, +9: 217, +12: 200, +24: 34, +40: 11};
the cc9 rare-class union is 929; the 813 target
segment is oo 0, size 304, 813 references; the start
distribution reproduces AES-NUM-112 exactly (4×1,
5×47, 6×31, 7×83, 8×56, 9×44, 10×9); and the
773470cd pos-9/size-32784 offset-11608 cell is found
in the ≥8 unanimous set exactly once, centre
ff010000.

## (i) The per-cell ladder's (base, step) parameters as a population

Parameter extraction over the 11,242 all-distinct
ladder cells (base = the rank-0 centre value; the
cell minimum is recorded alongside): rank 0 is the
cell minimum in 11,224 of 11,242 cells, confirming
the AES-NUM-112 reading that the ladder starts at
its base. The base population spans 99 distinct
values (98 for the minimum), dominated by base 15
(2,297 cells) and base 127 (544), with base 1 in
only 188 cells. Cell lengths run 2–28 (mode 2:
4,510 cells of length 2, which carry no step).

The arithmetic-progression subset (length ≥3,
constant successive difference) is 2,584 cells —
only 38.4% of the 6,732 distinct cells of length
≥3. The remaining 4,148 non-AP cells carry 2–5
distinct successive differences each (2 diffs:
1,877; 3: 1,317; 4: 797; 5: 157); their modal
difference is still +4 (864 cells) but +5 (445),
+6 (428), +12 (401) and +20 (242) stand beside it,
and the difference sequence is monotone within a
cell in only a small minority (non-decreasing
502/4,148; non-increasing 660/4,148). The step
family of AES-NUM-112 is therefore the AP slice of
a wider, mostly non-AP difference population.

Over the AP cells the (base, step) pair population
is strikingly small: only 72 distinct (base0, step)
pairs occur among 2,584 cells (the same 72 for
(basemin, step)). The most common pairs are
(127, 0) ×226, (3, +3) ×148, (1, +3) ×126,
(15, 0) ×126, (10, +4) ×119, (28, +3) ×102,
(5, +4) ×98, (37, +4) ×90, (14, +8) ×83,
(4, +4) ×78, (9, +8) ×78, (42, +4) ×76. Step 0
pairs with only two bases in the whole corpus
(127 and 15); step +24 only with base 2; step +40
only with base 12.

Is the pair a function of the cell's group/offset?
No tested field determines it:

- artifact: all 6 keys ambiguous for step, for base
  and for the joint pair.
- pos: step ambiguous at 23/51 keys; base 24/51;
  joint 24/51.
- segment size: step 23/161; base 44/161; joint
  44/161.
- offset: step 212/1,503; base 436/1,503; joint
  438/1,503.
- group (artifact, pos, segment size): step, base
  and joint each ambiguous at 13/299 keys — close,
  but not a function: the same group carries
  different (base, step) pairs at different offsets
  in 13 of its 299 AP-bearing groups.
- (artifact, pos): 54–78 ambiguous of 138;
  (pos, segsize): 16–18 of 237; (artifact, off):
  64–422 of 2,079; (pos, off): 13–34 of 2,096;
  first-ng, ng-set and first-cidx: all ambiguous.
- Over all distinct cells the same holds for base
  and for the modal difference (e.g. group key:
  base ambiguous 128/1,090; modal difference
  127/1,090).
- Neither component determines the other: step ~
  base0 ambiguous 19/41 keys; base0 ~ step 8/10;
  step ~ span 9/28; step ~ length 18/19; length ~
  step 7/10. Offset/pos residues mod k (2, 3, 4,
  8, 16) determine nothing (offset residues are
  degenerate: common offsets are multiples of 4 by
  construction).

What does govern step-family membership, short of
a function, is a strong joint conditioning by
artifact and cell length, measured exactly:

- By artifact, each network carries a restricted
  step subset: 0856a10c {0, +6, +12, +40};
  0a0d378c {0, +4, +6, +24}; 5ab3537d {0, +3, +4};
  76c3a8ff {0, +2, +9, +12}; 773470cd {0, +3, +4};
  cc9b9d1c {0, +4, +8}. Steps +8 (350 cells), +9
  (217) and +2 (26) are each exclusive to a single
  artifact (cc9b9d1c; 76c3a8ff; 76c3a8ff), +24 to
  0a0d378c (34), +40 to 0856a10c (11), and +3 to
  the sister pair 5ab3537d/773470cd (244/245).
- By cell length, several lengths carry a single
  step (n=11: only +8, 79 cells; n=5: {0, +12};
  n=8: {+3, +4}), and the long lengths are
  step-poor (n=25: {+4, +9}; n=28: {+3, +4}).
- Jointly, (base, length) nearly determines step:
  89 of 92 (base0, n) keys are unambiguous — the
  nearest approach to a law this population
  offers, and still not a function (3 keys carry
  two steps).

Verdict: the (base, step) pair is a function of
NO tested group/offset field — NOT PROVEN. Its
population is nevertheless highly structured: 72
pairs, step membership conditioned by artifact
and length (with several artifact-exclusive
steps), and (base, length) determining step at
89/92 keys.

## (ii) The 813 triple's start vs sub-sequence position

The sub-sequences are cut two ways: (ng, nacts)
classes in cidx order (31 classes; the large ones
have 26–28 contexts), and the base-train runs
(stride-4 runs of length ≥8 inside a (ng, nacts)
class; 217 of the 271 cc9 contexts lie in one of
8 such trains, all of stride 4).

As a function of position, the start fails every
test on this cut too:

- rank within its (ng, nacts) class: all 28 rank
  keys ambiguous; rank-from-end: 28/28; class
  length: 7/7; (rank, length): 64/93; rank mod 2:
  2/2; rank within the nacts class alone: 55/55.
- train rank: 28/28 ambiguous; rank-from-end
  28/28; stride (a single value, 4): 1/1; (stride,
  rank): 28/28; train-relative index (cidx −
  train first): 28/28; train run length: 3/3;
  train-rank mod k deterministic for no k in
  2..64.
- position within locally periodic stretches:
  phase (sequence index mod 8, and cidx mod 8)
  inside the long lag-8 stretches is ambiguous at
  7/8 phases.

But the sub-sequence cut exposes the structure
the global fields hid. Within each train the
start sequence collapses: after a head transient
of at most 3 ranks it is constant, or strictly
period-2 in rank —

- train (ng0, 245 acts): [5, then 8 ×26]
- train (ng0, 259): [10, 10, then (8, 9)
  alternating ×13 pairs]
- train (ng0, 607): [5, then (5, 6) alternating
  from rank 2, one early repeat]
- train (ng0, 738): [8, 9, 9, then 7 ×25]
- train (ng1, 245): 7-dominant, 8 at ranks 2, 3,
  12, 13 only
- train (ng1, 256): [9 ×10, 10, 9 ×16]
- train (ng1, 606): 7-dominant, exceptions 5
  (rank 1), 8 (rank 11), 6 (last rank)
- train (ng1, 738): 5-dominant, 6 at ranks 5, 10,
  11, 26 only

Each train thus carries at most 4 distinct starts
(most carry 2–3) against 7 corpus-wide, and the
steady pattern is a property of the train, not of
the rank: the same rank carries 8 in one train, 9
in another, 7 in a third — which is exactly why
every rank-only determinism test fails. The two
(ng, 873-acts) classes that form no train (6
contexts each) show no such collapse: [6, 7, 8,
6, 6, 4] and [5, 8, 8, 6, 6, 5].

The periodicity is quantified in cidx order.
Lag agreement (probability that contexts L apart
share a start; chance level from the start
distribution is 0.2071) is high exactly at
multiples of the train stride 4: lag 4: 0.5768;
lag 8: 0.6996 (the best lag in 1..32); lag 12:
0.5290; lag 16: 0.6667; lag 24: 0.6478 — while
non-multiples sit at or below chance (lag 2:
0.0446; lag 6: 0.0302; lag 1: 0.1741). Maximal
lag-8 stretches cover 175 of 271 contexts, the
longest spanning sequence indices 11–109 (91
consecutive lag-8 matches); the AES-NUM-112 noted
block [5, 8, 8, 7, 6, 8, 9, 7] occurs verbatim
12 times, at sequence indices 14, 22, …, 102 —
every 8 indices through that stretch. Of the 264
length-8 windows only 108 are distinct, and the
most repeated windows are rotations of one
another ((9, 5, 7, 7) ×2-phased patterns ×18/×16).

Verdict: the start is NOT a function of
sub-sequence position (rank, rank-from-end,
train-relative index, or stretch phase — all
ambiguous): NOT PROVEN on this cut. What is
measured instead is a per-train regime law in
descriptive form: the start is (nearly) constant
or period-2 within each stride-4 train after a
short head transient, and the regime belongs to
the train. Whether (train identity, rank regime)
determines the start exactly — head length,
parity phase, and the few in-train exceptions —
is the open question this cut hands on.

## (iii) Unanimity in the 11608 setting proper (groups of ≥8 instances)

Restricting the AES-NUM-112 enumeration to cells
whose group has ≥8 instances (the 11608 cell's
own group has exactly 8): 25,566 analysable cells
carrying 421,747 observations, of which 18,286
are unanimous — a rate of 0.7152, statistically
the corpus rate (0.7097 overall; 0.7050 among
<8-instance cells). Unanimity does not grow with
group size; the ≥8 restriction changes nothing
about how common unanimity is. By artifact the
≥8 rates are: 0856a10c 1,688/3,413 (0.4946);
0a0d378c 3,110/3,792 (0.8201); 5ab3537d
3,547/4,406 (0.8050); 76c3a8ff 2,682/4,096
(0.6548); 773470cd 3,643/4,555 (0.7998); cc9b9d1c
3,616/5,304 (0.6817); MiniLM has no ≥8 cells.
Exact-size rates stay in the familiar band
(size 8: 1,434/2,010, 0.7134 — reproducing
AES-NUM-112; size 28: 0.8675; the size-17 dip
persists at 127/289, 0.4394).

The centre population narrows sharply under the
restriction: only 29 distinct centres occur among
the 18,286 ≥8 unanimous cells, against 71 in the
full unanimous population — the other 42 centres
live only in small-group cells. The distribution
is again dominated by ff0f0000 (value 15): 11,367
cells, share 0.6216 (corpus unanimous share
0.6119), followed by ff050000 (1,267), ff7f0000
(1,030), ff070000 (875), ff000000 (818) — and
ff010000 (value 1) with 561 cells, share 0.0307.

Against its 2.56% corpus share, value 1 is
therefore slightly OVER-represented in the ≥8
setting (3.07%, a factor of 1.20), not diluted —
and the excess is concentrated: 0a0d378c alone
carries 272 of the 561 centre-1 cells (8.75% of
its own ≥8 unanimous cells), cc9b9d1c 178, while
0856a10c carries only 6 of 1,688. Among <8
unanimous cells the value-1 share is lower than
corpus, at 2.13% (455 cells). The target cell
(773470cd, pos 9, size 32784, offset 11608,
8 instances, centre ff010000) is verified in the
≥8 unanimous set exactly once — an ordinary member
of the centre-1 minority, in the artifact
(773470cd, 45 centre-1 cells) that is not its main
carrier.

Is the unanimous centre a function of
group/offset in this setting? No:

- artifact 6/6 ambiguous; pos 78/141; segment
  size 263/270; offset 2,192/6,082; group
  (artifact, pos, segsize) 471/590; (artifact,
  pos) 190/280; (pos, segsize) 388/470;
  (artifact, off) 1,062/12,708; (pos, off)
  221/14,516; (off, group size) 494/13,623;
  group size 22/47; first-ng, ng-set, first-cidx
  all ambiguous. Only the trivial cell identity
  (artifact, pos, segsize, off) determines the
  centre. The comparison over all unanimous cells
  fails the same way (group key 1,037/1,272
  ambiguous).
- Group purity confirms it from the other side:
  of the 590 (artifact, pos, segsize) groups that
  carry ≥8 unanimous cells, only 119 carry a
  single centre across all their unanimous
  offsets, and only 84 are uniformly centre 15;
  the typical group carries 3–5 distinct unanimous
  centres at different offsets (distinct-centre
  counts per group: 1: 119, 2: 82, 3: 96, 4: 114,
  5: 111, 6: 60, 7: 6, 8: 1, 9: 1). Offsets are
  no better: 2,192 of 6,082 offsets carry more
  than one unanimous centre across groups.

Verdict: in the 11608 setting proper, unanimity
is exactly as common as everywhere else (71.52%),
the centre-15 dominance persists (62.16%), value 1
is modestly over-represented (3.07% vs 2.56%) on
the strength of chiefly one artifact, and the
unanimous centre is a function of NO tested
group/offset field — the value-15 weight is a
population bias of the centre-value system, not
a per-group or per-offset law.

## Grades

- Shared enumeration and all inherited controls:
  reproduced exactly (55,902 cells; 527,236
  observations; 11,242 distinct ladder cells;
  39,673 unanimous cells; AP subset 2,584 with
  the AES-NUM-112 step distribution; 813 start
  distribution; 929 union; target cell in-set
  once): MEASURED.
- (base, step) population: base0 = cell minimum
  in 11,224/11,242 ladder cells; base spans 99
  values (mode 15: 2,297; 127: 544; 1: 188);
  only 72 distinct (base, step) pairs among the
  2,584 AP cells; AP cells are a minority of
  length-≥3 distinct cells (2,584 of 6,732), the
  non-AP majority carrying 2–5 distinct
  differences with modal difference still +4:
  MEASURED.
- (base, step) as a function of group/offset
  (artifact, pos, segment size, offset, group,
  pairs, ng fields, first-cidx, residues): every
  test ambiguous — NOT PROVEN. Step-family
  membership is strongly conditioned by artifact
  (restricted per-artifact step subsets; +8/+9/
  +2/+24/+40 artifact-exclusive) and by cell
  length, and (base, length) determines step at
  89/92 keys: association MEASURED, function
  NOT PROVEN.
- 813 start vs sub-sequence position: rank,
  rank-from-end, train rank, train-relative
  index, class length and stretch phase all
  ambiguous; train-rank mod k deterministic for
  no k in 2..64 — NOT PROVEN as a function of
  position. Per-train regime (constant or
  period-2 after a ≤3-rank head transient; ≤4
  distinct starts per train) and the stride-4
  lag structure (lag-8 agreement 0.6996 vs
  chance 0.2071; lag-8 stretches covering
  175/271 contexts; the noted 8-block verbatim
  ×12): MEASURED.
- Unanimity in the ≥8 setting: 18,286/25,566
  cells (0.7152) vs corpus 0.7097; 29 distinct
  centres; centre 15 share 0.6216; centre 1
  share 0.0307 vs its 0.0256 corpus share
  (over-represented ×1.20, concentrated in
  0a0d378c with 272/561); target cell verified
  in-set exactly once: MEASURED. Unanimous
  centre as a function of group/offset: every
  test ambiguous (group key 471/590) —
  NOT PROVEN.

## Next (slice 4.114)

(i) The near-laws of the ladder parameters: the
3 ambiguous (base, length) keys and the 13
ambiguous group keys for (base, step) — what
distinguishes their exceptions; the step-0 pair
split (base 127 vs base 15) — what separates the
two step-0 families; and the non-AP difference
profile as a population (is the profile a
function of group/offset?). (ii) The 813 start
as a function of (train, rank regime): per-train
head-transient length, steady-state form
(constant vs period-2 and its phase), the
in-train exception census, and the 54 contexts
that lie in no train. (iii) The centre-1
concentration in the ≥8 setting: inside
0a0d378c, is centre 1 a function of (group,
offset); and the 42 centres that vanish at ≥8 —
where exactly do they live in the <8 population?
Host/artifact analysis only — no physical child.
