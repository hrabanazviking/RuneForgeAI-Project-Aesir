# AES-NUM-114 — the ladder near-laws' exceptions anatomised (the 3 ambiguous (base, length) keys dissolve under artifact or segment size; the 13 ambiguous group keys are the same keys for base, step and pair, and every one couples a step-0 pair with a rising pair; the step-0 split between bases 127 and 15 is determined by group and by (position, length), the base-15 family being exactly length-3 cells in two artifacts while base-127 step-0 offsets live in one narrow band; the non-AP difference profile is a function of no tested field, yet is group-determined at 518 of 520 groups and its distinct-difference count is a function of group exactly); the 813 triple's start formalised as (train, rank regime) — four trains exact after heads of 1–3 ranks, one train's lone deviant priced as an 11-rank head by the exact-fit formalism, three trains constant-dominant with exactly 10 steady-region exceptions, the joint (train, regime, phase) model correct on 188 of 198 steady ranks and NOT a function; the 54 train-less contexts are 53 members of classes too small to form a train plus a single residue outlier in the (0, 607) class; inside 0a0d378c centre 1 is a function of no tested field (its ≥8 centre set is exactly {0, 1, 3, 7, 15, 31, 63, 127}); and the 42 centres that vanish at ≥8 live in only 116 cells of the <8 unanimous population, overwhelmingly in size-2 groups in cc9b9d1c

Slice 4.114, worked under `docs/TASK_CONTRACT_4.114.md`
(contract committed first @ f58f81b9). Host/artifact
analysis only, on Mimir (purpleviking1) — no physical
child, no device run of any kind.

## Run and transfer record

hef114.py was built locally (hef113 base extraction —
everything in hef113.py before its 4.113 arms marker —
plus the new 4.114 arms). A FIRST run (script sha256
9ff5bbbb…, arms sha256 13c8415c…) died in arm (i)'s
step-0 section on a TypeError from a misplaced
parenthesis in one arms expression (the distinct-
neighbourhood count) — exactly the 4.112 failure
class: one line, fixed, and the whole slice rerun.
The sections the first run completed are
byte-identical to the corrected run (verified
on-device by md5 over output lines 1–10,854 and
10,855–11,328, both pairs equal). One launch of the
corrected script was also lost when its device invoke
timed out at the node level and killed the detached
child; it was relaunched in the standalone form and
ran to completion — the record stands on that run.

Corrected run: arms sha256 f488bad3…, script sha256
6dd4dc5d…, gz sha256 0f3fd3c0… (saved:60407 on the
proxy upload through the one-shot receiver
recv114.py, local sha256 143f8eb2…; gz and script
sha256 verified on-device, py_compile passed), ran
detached over the 7-artifact corpus to DONE114 at
line 11,567, output 1,596,967 B, sha256 46bfc17e…
(retrieved gz sha256 6d44738a… verified identical
both sides).

## Controls

All controls reproduce exactly: 128,787 small actions;
79,001 bursts; 745,849 pointer actions; 1,504 contexts;
2,049 trailing pairs; 75,215 champion bursts; TRAINS
52 / unique-first 28 / unanimous 13 / elsewhere 11 /
D113 249 / FIRST-D 3,089 / CTRL-D 176; CAMPS A
21392/13, B 21648/12. The inherited DONE markers stand
at the same lines as in the AES-NUM-113 run (DONE105
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
72 distinct (base, step) pairs; the non-AP subset is
4,148 cells with distinct-difference counts {2: 1,877,
3: 1,317, 4: 797, 5: 157}; the cc9 rare-class union
is 929; the 813 target segment is oo 0, size 304, 813
references; the start distribution reproduces
AES-NUM-112/113 exactly (4×1, 5×47, 6×31, 7×83, 8×56,
9×44, 10×9); ≥8-instance cells 25,566 with 18,286
unanimous and 29 distinct centres, centre 1 at 561
(272 of them in 0a0d378c, rate 0.0875); and the
773470cd pos-9/size-32784 offset-11608 cell is found
in the ≥8 unanimous set exactly once, centre ff010000.

## (i) The ladder near-laws' exceptions

### The 3 ambiguous (base, length) keys

AES-NUM-113's near-law — (base, length) determines
step at 89/92 keys — fails at exactly three keys,
now anatomised cell by cell:

- (base 13, length 13): 43 cells, steps {+4, +8}.
  The split is the artifact: every +4 cell is in
  0a0d378c (pos 13, size 22704, 9 cells listed in
  the run output), every +8 cell in cc9b9d1c (pos
  21/24, sizes 23464/32728/32744). Artifact,
  position and segment size are each step-pure at
  every value present at this key.
- (base 4, length 16): 64 cells, steps {+4, +6},
  all in a single artifact. Here segment size
  separates: all 9 segment sizes present are
  step-pure. (Span and maximum also separate, but
  for an AP cell span = step × (length − 1) and
  maximum = base + span, so those two separations
  are arithmetic tautologies, not evidence; the
  same caveat applies at the other two keys.)
- (base 4, length 27): 27 cells, steps {+3, +4}.
  Artifact separates (5ab3537d, 773470cd, cc9b9d1c
  each step-pure), as do position (2 values) and
  segment size (2 values).

So the near-law's three exceptions are not noise:
at every one of them an external field the key
omits — artifact or segment size — is step-pure.
(Base, length) is a projection of a law that also
carries artifact/segment context; as a function of
(base, length) alone the grade stays NOT PROVEN,
by exactly these 134 cells (43 + 64 + 27).

### The 13 ambiguous group keys

For the group key (artifact, pos, segment size) the
ambiguous sets for step alone, for base alone and
for the joint (base, step) pair are THE SAME 13
keys — base and step always change together. Every
ambiguous group carries exactly two (base, step)
pairs, and in all 13 the first pair is a step-0
pair and the second a rising pair:

- 0a0d378c (11, 10560): (127, 0) / (14, +6) — 5 AP cells
- 5ab3537d (12, 32728): (127, 0) / (3, +3) — 20
- 5ab3537d (20, 32720): (127, 0) / (3, +3) — 27
- 76c3a8ff (10, 32736): (15, 0) / (87, +2) — 41
- 76c3a8ff (11, 8528): (15, 0) / (87, +2) — 14
- 76c3a8ff (14, 31976): (15, 0) / (85, +2) — 36
- 773470cd (12, 32728): (127, 0) / (3, +3) — 21
- 773470cd (20, 32720): (127, 0) / (3, +3) — 28
- 773470cd (8, 32784): (127, 0) / (41, +4) — 28
- cc9b9d1c (18, 32776): (127, 0) / (14, +8) — 23
- cc9b9d1c (19, 32776): (127, 0) / (18, +8) — 17
- cc9b9d1c (23, 32744): (127, 0) / (9, +8) — 13
- cc9b9d1c (24, 32744): (127, 0) / (13, +8) — 13

Within each group the two families sit at disjoint
offsets (the run output lists every cell): a group
is ambiguous precisely because one of its offsets
hosts the flat (step-0) ladder while its other
offsets host that artifact's rising ladder. The
group-level near-law therefore fails by a single
recurring mechanism — the step-0 family cohabiting
a group with a rising family — not by scattered
disagreement.

### The step-0 split: base 127 (×226) vs base 15 (×126)

The two step-0 families are far more separable
than AES-NUM-113 could say:

- Length: base 15 occurs ONLY at length 3 (126/126
  cells). Base 127 occurs at lengths {3, 5, 6, 7,
  9, 12, 13, 14, 18, 26, 27} — and at length 3 only
  twice. Length alone is ambiguous at exactly that
  one key (3: {15: 126, 127: 2}).
- Artifact: base 15 lives only in 76c3a8ff (65)
  and cc9b9d1c (61); base 127 in all six artifacts.
  Artifact alone is ambiguous at exactly those two
  artifacts, which carry both bases.
- Offsets: base-127 offsets are confined to one
  narrow band, 5,988–8,672 (167 distinct offsets
  over 226 cells, modal offsets recurring ×4);
  base-15 offsets spread over 20–32,548 (125
  distinct over 126 cells, at most ×2). Offset
  alone is ambiguous at exactly 1 of 291 offsets.
- Jointly the split IS determined: base ~ group
  (artifact, pos, segment size) is deterministic
  over the step-0 population (32 keys, 0 ambiguous),
  and base ~ (pos, length) is deterministic too
  (28 keys, 0 ambiguous), as is (artifact, pos,
  length). No single tested field determines it
  (art 2/6 ambiguous; pos 3/17; segment size 2/19;
  ng-set 2/3; first-cidx 1/22; (artifact, length)
  1/20).
- Content: the families' neighbourhoods differ in
  kind. Base-127 cells' total zero-word counts run
  over 22 distinct values up to 81, and their modal
  first-instance neighbourhood is (ff7f0000,
  00000000, ff7f0000, ff7f0000, ff7f0000) — the
  centre word repeated in the flanks. Base-15
  cells' total zero-word counts are only {3, 6, 9}
  (27/58/41 cells), and no neighbourhood repeats
  more than twice (119 distinct over 126 cells).

Verdict: what distinguishes the two step-0
populations is measured — length (base 15 is
length-3 only, with 2 base-127 exceptions),
artifact range, and a narrow-vs-spread offset
geometry — and jointly the base is a function of
group and of (pos, length) within the step-0
population. No single field is the distinguisher.

### The non-AP difference profile as a population

The 4,148 non-AP cells (length ≥3, non-constant
successive differences) carry 317 distinct ordered
difference tuples, 298 distinct difference
multisets and 174 distinct difference sets. The
population is dominated by near-AP profiles: the
most common multiset is twenty-four +4s and one
+8 (103 cells), the most common diff set is {+4,
+8} (451 cells), then {+6, +12} (173) and {+15,
+20, +25} (156, the most common ordered profile
being (15, 20, 25) ×83). Mode difference is still
+4 (864 cells); the full difference union runs
from −87 to +116, overwhelmingly positive (only
24 negative difference occurrences in total).

As a function of group/offset, the profile (in
ordered, multiset and set form alike) fails every
single-field test: artifact 6/6 ambiguous, pos
51/92, segment size 119/263, offset 1,070/1,929,
(artifact, pos) 113/193, first-ng / ng-set /
first-cidx all ambiguous, and (base, length),
(artifact, length), span and mode-difference keys
all ambiguous. But at the group key the profile
is nearly a law: multiset profile ambiguous at
only 2 of 520 groups, ordered profile at 2 of
520, diff set at 2 of 520 — and the number of
distinct differences (ndiff) is a function of
group EXACTLY (520 keys, 0 ambiguous). The two
groups where the profile itself varies are not
individually enumerated in this run; they are
named as an open item for the next slice.

Verdict: the non-AP profile is a function of NO
tested single group/offset field — NOT PROVEN —
with a measured near-law at group level (518/520)
and one exact group law (ndiff).

## (ii) The 813 start as a function of (train, rank regime)

Formalisation: for each of the 8 stride-4 trains,
the head is the smallest number of leading ranks
after which the tail is EXACTLY constant or
EXACTLY period-2 in rank; where no exact form
exists, the train is fitted constant-dominant
(mode start) with its head taken as the leading
deviant run and every later deviant counted as a
steady-region exception.

- Train 44 (ng0, 245 acts, 27 ranks): head 1,
  CONST 8, 0 exceptions.
- Train 45 (ng0, 259, 28): head 2, PERIOD-2 (8, 9)
  with the phase anchored at the head's end,
  0 exceptions.
- Train 46 (ng0, 607, 25): head 1, PERIOD-2 (5, 6),
  0 exceptions.
- Train 47 (ng0, 738, 28): head 3, CONST 7,
  0 exceptions.
- Train 49 (ng1, 256, 27): CONST 9 with a single
  deviant start (10) at rank index 10. The
  exact-fit formalism prices that one deviant as
  an 11-rank head — a formal artefact, recorded
  as such: the train is constant from rank 0 with
  one mid-train exception, and any honest head
  length for it is 0 with 1 exception.
- Train 48 (ng1, 245, 28): CONST_DOM 7, head 0,
  4 steady exceptions — starts of 8 at rank
  indices 1, 2 (cidx 140, 144) and 11, 12
  (cidx 180, 184): two adjacent pairs.
- Train 50 (ng1, 606, 27): CONST_DOM 7, head 1
  (leading 5), 2 steady exceptions — 8 at rank
  index 10 (cidx 183) and 6 at the last rank
  index 26 (cidx 247).
- Train 51 (ng1, 738, 27): CONST_DOM 5, head 0,
  4 steady exceptions — starts of 6 at rank
  indices 4, 9, 10, 25 (cidx 158, 178, 182, 242).

The in-train exception census is therefore 10
steady-region exceptions under the exact-fit
reading (48: 4, 50: 2, 51: 4 — five starts of 8
against a 7 regime, five starts of 6 against a 5
regime, every exception exactly one step above its
train's steady value), plus train 49's single
head-absorbed deviant (a 10 against a 9 regime,
also one step above). All 11 deviants in all 8
trains sit exactly +1 above their train's steady
start; none sits below it.

Joint determinism test: start as a function of
(train, regime, phase) is ambiguous at 7 of 25
keys — NOT a function, and the ambiguity is
exactly the exception census (the fitted
(train, form, phase) model is correct on 188 of
198 steady ranks). (Train, regime, parity) fails
the same 7 keys; (train, parity) fails 12/16;
train alone 8/8. Only per-train memorisation,
(train, rank), is deterministic (217 keys), which
is a lookup, not a law.

The 54 train-less contexts: 53 of them belong to
(ng, nacts) classes of size ≤6 (sizes {1: 9, 2: 8,
3: 24, 6: 12} contexts) — too small ever to form
a train under the ≥8-run definition, including
both 873-acts classes (6 contexts each, longest
stride-4 run 3). Exactly ONE train-less context
sits in a large class: cidx 2 of the (ng0, 607)
class (26 contexts, 25 of them train 46), whose
own stride-4 residue run has length 1 (the next
context in its residue is 8 away, not 4); its
start is 6. Train membership is therefore a
function of (ng, nacts) class at 30 of 31 classes
and of class size at 6 of 7 sizes, the (0, 607)
class / size 26 being the sole exception on both
tests. The train-less start distribution is
flatter than the in-train one ({4: 1, 5: 9, 6: 14,
7: 10, 8: 11, 9: 3, 10: 6} vs {5: 38, 6: 17, 7: 73,
8: 45, 9: 41, 10: 3}; means 7.0000 vs 7.1982), and
within the train-less population the start is a
function of no tested field (ng, nacts, class,
class size, class rank, ngidx, ngidx mod 4 and
cidx mod 4 all ambiguous) — NOT PROVEN.

Verdict: (train, rank regime) comes as close to
determining the start as any cut has — 188/198
steady ranks predicted by (train, form, phase),
heads of 0–3 ranks on the four ng0 trains — but
it is NOT a function: 10 steady exceptions (all
+1 above regime) and one head-absorbed deviant
stand against it, enumerated above. The
train-less 54 are characterised: a small-class
population plus one residue outlier; their starts
answer to nothing tested.

## (iii) Centre-1 concentration inside 0a0d378c, and the vanishing centres

Per-artifact centre-1 rates among ≥8 unanimous
cells, cell by cell: 0a0d378c 272/3,110 (0.0875,
48.48% of all 561 centre-1 cells); cc9b9d1c
178/3,616 (0.0492); 773470cd 45/3,643 (0.0124);
5ab3537d 39/3,547 (0.0110); 76c3a8ff 21/2,682
(0.0078); 0856a10c 6/1,688 (0.0036). The
concentration is real and graded: 0a0d378c's rate
is 1.8× the next artifact's and 24× the lowest.
In the <8 population the concentration is sharper
still — 0a0d378c carries 313 of the 455 <8
centre-1 cells (cc9b9d1c 84, the rest ≤22 each).

Inside 0a0d378c's ≥8 unanimous population (3,110
cells), the centre population itself is
remarkable: only 8 distinct centres occur —
{0, 1, 3, 7, 15, 31, 63, 127}, the 2^k − 1 values
plus 0 — distributed {15: 1,924, 1: 272, 7: 270,
127: 174, 3: 150, 31: 114, 63: 108, 0: 98}. But
centre 1 is a function of no tested field there:
centre ~ group ambiguous 65/89, ~ offset 227/2,406,
~ segment size 60/65, ~ pos 19/38, ~ first-cidx
26/28; the binary is-centre-1 tests fail the same
way (group 56/89, offset 75/2,406, pos 18/38).
From the group side: 56 of the artifact's 89 ≥8
unanimous groups carry at least one centre-1
cell, NONE is uniformly centre-1, and 24 groups
carry a single centre overall; from the offset
side, 260 offsets carry centre 1 and 75 of those
also carry another centre. The same binary tests
fail in every other artifact (group ambiguous
4–19 keys, offset 1–75). The 8.75% is a
population bias of this artifact's centre system,
not a per-group or per-offset law — NOT PROVEN
as a function.

The 42 vanishing centres (71 corpus-wide minus
the 29 at ≥8) are: 4, 9, 10, 12, 18, 21, 25, 26,
28, 39, 48, 49, 50, 53, 77, 101, 119, 128, 149,
192, 199, 210, 212, 224, 228, 230, 233, 235, 238,
239, 240, 243, 245, 246, 247, 248, 249, 250, 251,
252, 254, 255. Their <8 homes total only 116
cells of the 21,387 <8 unanimous cells (0.54%);
the other 26 centres occur in both populations
(21,271 <8 cells). Home counts per centre:
{1: 18 centres, 2: 12, 3: 5, 4: 3, 5: 1, 9: 1,
15: 1, 18: 1} — the largest homes are centre 119
(18 cells, all cc9b9d1c, group sizes 2–3), centre
39 (15, all cc9b9d1c) and centre 199 (9, all
cc9b9d1c). 36 of the 42 live in a single artifact
(cc9b9d1c is the home artifact for most of them;
101's 5 cells are all in 0856a10c), and their
groups are overwhelmingly of size 2 (the run
output enumerates every centre with its counts,
artifacts, group sizes, offsets and groups). The
vanishing is a small-group rarity effect: these
centres are rare everywhere and simply never
occur in a group of ≥8.

## Grades

- Shared enumeration and all inherited controls:
  reproduced exactly (55,902 cells; 527,236
  observations; 11,242 distinct ladder cells;
  39,673 unanimous cells; AP subset 2,584 with
  the AES-NUM-112 step distribution; non-AP
  subset 4,148; 813 start distribution; 929
  union; ≥8 cells 25,566 / unanimous 18,286 /
  29 centres / centre-1 561 with 272 in
  0a0d378c; target cell in-set once): MEASURED.
- The 3 ambiguous (base, length) keys: (13, 13)
  steps {+4, +8} over 43 cells, separated by
  artifact; (4, 16) {+4, +6} over 64, separated
  by segment size; (4, 27) {+3, +4} over 27,
  separated by artifact — MEASURED. (Base,
  length) as a function: still NOT PROVEN
  (134 exception cells).
- The 13 ambiguous group keys: identical for
  step, base and pair; each carries exactly two
  pairs, always a step-0 pair plus a rising pair,
  at disjoint offsets: MEASURED.
- Step-0 split: base 15 = length-3 only (126/126),
  artifacts {76c3a8ff, cc9b9d1c} only, offsets
  spread 20–32,548; base 127 = lengths 3–27,
  all artifacts, offsets confined to 5,988–8,672;
  base is a function of group and of (pos,
  length) within the step-0 population, and of
  no single tested field: MEASURED.
- Non-AP profile: 317 ordered / 298 multiset /
  174 set profiles over 4,148 cells; a function
  of no tested single field — NOT PROVEN; group
  near-law 518/520 groups for the profile and
  ndiff a function of group exactly (520/520):
  MEASURED.
- 813 start vs (train, rank regime): per-train
  heads and forms MEASURED (exact after heads
  1/2/1/3 on trains 44–47; train 49 constant
  with one head-absorbed deviant; trains 48/50/51
  constant-dominant); exception census 10 steady
  exceptions, all exactly +1 above regime;
  (train, regime, phase) correct on 188/198
  steady ranks but ambiguous at 7/25 keys —
  NOT PROVEN as a function.
- Train-less 54: 53 in classes of size ≤6, one
  residue outlier (cidx 2 of the (0, 607) class,
  start 6); membership a function of class at
  30/31 classes; train-less start a function of
  no tested field — characterisation MEASURED,
  function NOT PROVEN.
- Centre 1 inside 0a0d378c: rate 0.0875 vs
  0.0492 next-best and 0.0036 lowest; the
  artifact's ≥8 centre set is exactly {0, 1, 3,
  7, 15, 31, 63, 127}; centre 1 (and the centre
  generally) a function of no tested field there
  or in any artifact — NOT PROVEN; concentration
  MEASURED.
- The 42 vanishing centres: enumerated; 116 <8
  cells total (0.54% of <8 unanimous), 36/42
  single-artifact, homes predominantly cc9b9d1c
  size-2 groups, largest home centre 119 with
  18 cells: MEASURED.

## Next (slice 4.115)

(i) The non-AP profile's last exceptions: the 2
groups (of 520) whose non-AP profile varies
within the group — anatomise them as 4.114
anatomised the ladder's ambiguous keys, and test
whether offset separates the variants there.
(ii) The two absorbed deviants of the train
regime: train 49's rank-10 start of 10 and the
train-less cidx 2 of the (0, 607) class (start
6) — do their surrounding contexts (the actions
around the triple, the class's other members)
carry any tested mark of the deviation; and the
two size-6 873-acts classes — does any period in
cidx organise their 12 starts? (iii) The
2^k − 1 centre set: is the {0, 1, 3, 7, 15, 31,
63, 127} shape of 0a0d378c's ≥8 centre set true
of the other artifacts' ≥8 sets and of the <8
population, and what are the exact centre sets
per artifact in both settings? Host/artifact
analysis only — no physical child.
