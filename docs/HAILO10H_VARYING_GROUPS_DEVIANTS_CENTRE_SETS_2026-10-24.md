# AES-NUM-115 — the non-AP profile's two varying groups anatomised (they are mirror groups in two artifacts at the same position, segment size and offsets, each carrying exactly two cells whose first nine centres are an exact +3 ladder and whose whole variation is the tenth centre — the sole ng1 instance — worth 15 at one offset and 11 at the other in both artifacts; no tested field separates the variants beyond cell identity and a tautology); train 49's rank-10 deviant carries a measured head cause (one extra act in its head region shifts the identical triple block by one position; every other tested field is the train's modal value, and the train returns to 9 on both sides — an isolated local anomaly, not a phase slip); the train-less cidx 2 outlier carries no mark at all (its start is in-distribution for its class, its residue and phase fields match the train's, and its isolation is purely the missing cidx 6 classmate); the two size-6 873-acts classes share the cidx difference pattern [4, 2, 4, 4, 2] and no tested field or period orders their 12 starts; and the 2^k−1 centre-set completeness at ≥8 is a 0a0d378c-only property (every other artifact's ≥8 set misses some 2^k−1 values and carries non-2^k−1 centres — the mirror pair 5ab3537d/773470cd sharing one identical 13-centre set), while in the <8 setting every 2^k−1 value including 255 occurs corpus-wide and the 42 vanishing centres split 88/13/9/4/1/1 per artifact

Slice 4.115, worked under `docs/TASK_CONTRACT_4.115.md`
(contract committed first @ d3918f99). Host/artifact
analysis only, on Mimir (purpleviking1) — no physical
child, no device run of any kind.

## Run and transfer record

hef115.py was built locally (hef114 base extraction —
everything in hef114.py before its 4.114 arms marker —
plus the new 4.115 arms): arms sha256 7b970b00…, script
sha256 fe16d492…, gz sha256 756f0622… (saved:59759 on
the proxy upload through the one-shot receiver
recv115.py, local sha256 07a1004f…; gz and script
sha256 verified on-device, py_compile passed), ran
detached over the 7-artifact corpus to DONE115 at
line 11,173, output 1,514,649 B, sha256 d862ab5f…
(retrieved gz sha256 319c06ab… verified identical
both sides).

## Controls

All controls reproduce exactly: 128,787 small actions;
79,001 bursts; 745,849 pointer actions; 1,504 contexts;
2,049 trailing pairs; 75,215 champion bursts; TRAINS
52 / unique-first 28 / unanimous 13 / elsewhere 11 /
D113 249 / FIRST-D 3,089 / CTRL-D 176; CAMPS A
21392/13, B 21648/12. The inherited DONE markers stand
at the same lines as in the AES-NUM-114 run (DONE105
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

## (i) The non-AP profile's 2 varying groups

AES-NUM-114 left the non-AP difference profile
group-determined at 518 of 520 groups (ordered,
multiset and set forms alike), with ndiff a function
of group exactly. This run reproduces that split
(group key ambiguous at exactly 2 of 520 keys for
each profile form; ndiff 0 of 520) and anatomises
the two exceptions. They are:

- (5ab3537d, pos 21, segsize 32776)
- (773470cd, pos 21, segsize 32776)

— the same position and segment size in two
artifacts, and the two groups are mirrors of each
other in every recorded particular. Each group
carries exactly 2 non-AP cells (and its full
all-distinct population is exactly those 2 cells —
no AP cells), over n = 10 instances with the
identical cidx list [0, 3, 6, 9, 12, 15, 18, 21,
24, 95] and ng list [0 ×9, 1] in both artifacts;
only the instances' segment addresses (oos) differ,
as they must between artifacts. The cells:

- off 17272: centres [1, 4, 7, 10, 13, 16, 19, 22,
  25, 15], ordered diffs (3, 3, 3, 3, 3, 3, 3, 3,
  −10) — in BOTH artifacts.
- off 32192: centres [1, 4, 7, 10, 13, 16, 19, 22,
  25, 11], ordered diffs (3, 3, 3, 3, 3, 3, 3, 3,
  −14) — in BOTH artifacts.

So the entire within-group variation is one centre:
the first nine centres form an exact +3 ladder
(1, 4, …, 25) in all four cells, and the tenth
centre — the sole ng1 instance, cidx 95 — is 15 at
offset 17272 and 11 at offset 32192, in both
artifacts alike. Every other recorded field is
identical within each group: base0 1, basemin 1,
basemax 25, span 24, mode difference +3, first
difference +3, ndiff 2 (consistent with the exact
ndiff group law), zero-word sum 12, first-cidx and
ng-set constant.

Separator tests inside each group (target: the
multiset profile) come back in only three kinds:
trivially deterministic — the exact offset (two
cells, cell identity), offset mod 16 and mod 64
(vacuous at two cells, each cell its own key), and
the first-instance neighbourhood (read at the
cell's own offset, cell identity again);
tautological — the last difference, which is a
component of the profile itself; and single-valued
— base0, basemin, basemax, span, mode difference,
first difference, ndiff, first-cidx, ng-set,
zero sums and first-instance centreword all take
one value in the group and so cannot separate
anything. The offset-order run count is 2 over 2
cells, which at this size says nothing.

Verdict: what distinguishes the variants is
measured — the tenth centre's value, mirrored
across two artifacts at the same two offsets — but
no tested field separates the variants beyond cell
identity and tautology: NOT PROVEN as a function.
With two cells per group no separator test can
grade stronger, and that limit is recorded, not
papered over.

Population comparison: the 518 determined groups
carry 4,144 non-AP cells with 296 distinct multiset
profiles (315 ordered) among them; neither varying
profile occurs in the determined population at all
(0 cells each). Determined groups carry 1–20
non-AP cells each — 44 of them exactly 1, and so
determined trivially — while the varying groups sit
at 2, the smallest size at which variation is
possible. The near-law's last exceptions are
therefore the smallest possible exceptions, and
their profiles are unique to the mirror pair.

## (ii) The two absorbed deviants and the 873 classes

The per-train formalisation of AES-NUM-114
reproduces exactly (trains 44–47 exact after heads
of 1/2/1/3 ranks; train 49 CONST 9 priced as an
11-rank head by the exact-fit formalism; trains
48/50/51 constant-dominant with 4/2/4 steady
exceptions).

### Train 49's rank-10 deviant (cidx 181)

The deviant context: cidx 181, ng 1, ngidx 48,
256 acts, start 10, target positions [10, 11, 12]
against [9, 10, 11] for every other train member
shown. Its train neighbours are rank 9 (cidx 177,
start 9) and rank 11 (cidx 185, start 9); in cidx
order it sits in the regular four-class rotation
(245/606/738/256 classes cycling through trains
48/50/51/49), with nothing out of place.

Anatomy of the shift: the deviant's acts at
positions 7, 8, 9 are exactly its neighbours' acts
at positions 6, 7, 8 — (5651456, 24, 1),
(65828864, 24, 2), (65828352, 24, 1) — and every
pre-triple act shown matches the corresponding
neighbour act at position −1. The triple block
itself is identical; it simply starts one position
later. After the triple, alignment is restored in
relative terms (the 32608 act follows the triple,
its offset 1497424384 sitting in the train's
regular progression between rank 9's 1467635712
and rank 11's 1527057408). The one place the
deviant differs is its head: its opening pair is
(1201406464, 24, 2), (1201405440, 24, 0), where
25 of the other 26 members open with first act
(33320960, 24, 2) (the remaining one, the train's
own head rank, with (63031296, 24, 2)) — the
deviant carries one extra act in its head region,
and that extra act is the whole deviation.

Field census against the other 26 members: the
act before the triple is the train's modal value
(shared by 25 of 26); the acts after the triple
((0, 304, 1) and (0, 304, 2)), the target count
(3), ngidx mod 4 (0) and cidx mod 4 (1) are
identical for all 27 members. No other tested
field marks the deviant.

Classification: an isolated local anomaly with a
measured head cause — NOT a phase slip (the triple
block is unchanged and both flanking ranks return
to start 9, so nothing propagates), and NOT a
regime head (the train is constant 9 from rank 0
apart from this one context). The exact-fit
formalism's 11-rank head price is, on this
evidence, an artefact of pricing a one-context
head difference as regime structure.

### The train-less cidx 2 outlier of the (0, 607) class

The outlier context: cidx 2, ng 0, ngidx 3, 607
acts, start 6, target positions [6, 7, 8]. Its
class has 26 contexts (cidxs 2, 10, 14, …, 106)
with start distribution {5: 13, 6: 13}; the 25
train-46 members alone give {5: 13, 6: 12}. The
outlier's start of 6 is therefore exactly
in-distribution — a joint mode of its class — and
is not a start deviation at all.

Field census against the 25 train members: cidx
mod 4 is 2, the train's own residue; ngidx mod 4
is 3, shared by all 25 members (their ngidxs run
11, 15, 19, …); the acts after the triple and the
target count (3) are identical; the act before
the triple and the first act carry the outlier's
own segment addresses, values of the same kind
several train members also carry uniquely. No
tested field marks this context.

Its isolation is pure membership geometry: it is
the class minimum, and the next class member is
8 away, not 4 — the intervening cidx 6 belongs to
the (0, 606) class (itself train-less) — so its
stride-4 residue run has length 1 and no train
can form on it. In cidx order its neighbours are
the heads of other classes (cidx 0 in train 45,
start 10; cidx 1 in train 47, start 8; cidx 3 in
train 44, start 5). Verdict: an outlier of train
membership only, with no tested mark — NOT PROVEN
that anything in or around the context signals
its exclusion.

### The two size-6 873-acts classes

Both classes in full:

- (ng 0, 873): cidxs [113, 117, 119, 123, 127,
  129], ngidxs [114, 118, 120, 124, 128, 130],
  starts [6, 7, 8, 6, 6, 4].
- (ng 1, 873): cidxs [250, 254, 256, 260, 264,
  266], ngidxs [117, 121, 123, 127, 131, 133],
  starts [5, 8, 8, 6, 6, 5].

The two classes share their cidx difference
pattern exactly, [4, 2, 4, 4, 2] (modal stride 4,
longest stride-4 run 3 — too short for a train in
both). Their 12 starts combined distribute as
{4: 1, 5: 2, 6: 5, 7: 1, 8: 3}.

Organisation tests: start as a function of class
rank is deterministic only as a lookup (6 distinct
ranks, 6 contexts); the act before the triple is
deterministic only trivially (unique per context).
Every substantive test fails in both classes:
cidx mod 2 (a single key, ambiguous), cidx mod 4
(both keys ambiguous), ngidx mod 2 and mod 4
(ambiguous), the act after the triple (one value,
all starts), target count (one value). Period
search in cidx order finds no lag that organises
the starts: lag agreements are 1/5, 0/4, 1/3 in
the ng0 class and 2/5, 0/4, 0/3 in the ng1 class,
at or below what unrelated sequences show.
Combined, start is not a function of ng either
(2 keys, both ambiguous). Verdict: no tested field
and no period in cidx orders the 12 starts —
NOT PROVEN.

## (iii) The 2^k−1 centre-set shape per artifact

Candidate shape: the 2^k−1 centre values
{0, 1, 3, 7, 15, 31, 63, 127, 255} (k = 0..8).
Corpus-wide, the ≥8 unanimous centre set is the
29 values {0, 1, 2, 3, 5, 6, 7, 8, 11, 15, 16, 17,
23, 27, 31, 34, 35, 47, 63, 69, 71, 91, 95, 104,
107, 127, 139, 143, 191} — every 2^k−1 value up to
127 is present, 255 is absent, and 21 non-2^k−1
values are present. The <8 corpus set is 68 values:
all nine 2^k−1 values including 255, plus 59
non-2^k−1 values. Per artifact:

### ≥8 setting

- 0a0d378c (3,110 cells): set exactly {0, 1, 3, 7,
  15, 31, 63, 127} (counts 98/272/150/270/1,924/
  114/108/174); 255 absent; zero non-2^k−1 centres.
  The shape holds exactly — the only artifact
  where it does.
- 0856a10c (1,688): 20 centres {0, 1, 2, 5, 6, 7,
  11, 15, 17, 23, 27, 34, 35, 47, 69, 71, 91, 95,
  107, 127}; 2^k−1 present {0, 1, 7, 15, 127},
  absent {3, 31, 63, 255}; 15 non-2^k−1 values in
  573 of 1,688 cells.
- 5ab3537d (3,547): 13 centres {0, 1, 2, 5, 7, 11,
  15, 23, 34, 69, 95, 127, 139}; 2^k−1 present
  {0, 1, 7, 15, 127}, absent {3, 31, 63, 255};
  8 non-2^k−1 values in 699 cells.
- 773470cd (3,643): the identical 13-centre set to
  5ab3537d, with near-identical counts (15 at
  2,384 vs 2,326; 127 at 234 vs 223; 5 at 450 vs
  448) — the mirror pair of arm (i) again; 8
  non-2^k−1 values in 708 cells.
- 76c3a8ff (2,682): 25 centres; 2^k−1 present
  {0, 1, 7, 15, 31, 63, 127}, absent {3, 255} —
  the closest approach to the shape after
  0a0d378c — but 18 non-2^k−1 values in 753 cells.
- cc9b9d1c (3,616): 11 centres {0, 1, 2, 3, 5, 7,
  11, 15, 23, 47, 127}; 2^k−1 present {0, 1, 3, 7,
  15, 127}, absent {31, 63, 255}; only 5
  non-2^k−1 values (317 cells) — the fewest
  non-shape values after 0a0d378c, but centre 3 is
  present here while 31 and 63 are not.
- MiniLM: no unanimous cells in either setting
  (its 4 analysable cells are never unanimous);
  both centre sets are empty.

Verdict: the 2^k−1 completeness at ≥8 is a
0a0d378c-only property — NOT corpus-wide. Every
other artifact both lacks some 2^k−1 values
(3 is missing from four of the remaining five;
31 and 63 from three) and carries non-2^k−1
centres of its own.

### <8 setting, and the 42 vanishing centres per artifact

In the <8 setting each artifact's set departs
from the shape by its vanishing centres and a
few more:

- 0a0d378c (3,359 cells): 11 centres — its ≥8
  shape plus 255 (2 cells, completing the 2^k−1
  family) and the non-shape values 95 (3 cells)
  and 128 (2 cells). The near-shape survives in
  <8 with only 5 non-shape cells of 3,359.
- 0856a10c (6,411): 26 centres; its ≥8 set plus
  {53, 77, 101, 128, 149, 254}; 21 non-2^k−1
  values in 1,679 cells.
- 5ab3537d (2,106): 13 centres; its ≥8 set with
  139 replaced by 239; 8 non-2^k−1 values in
  470 cells.
- 773470cd (2,477): 21 centres; its ≥8 set plus
  {4, 17, 50, 192, 224, 233, 239, 252, 255} minus
  139; 15 non-2^k−1 values in 490 cells — the
  mirror with 5ab3537d breaks here: the pair
  shares its ≥8 set exactly but not its <8 set.
- 76c3a8ff (3,483): 23 centres; its ≥8 set minus
  {63, 143, 191} plus {49}; 17 non-2^k−1 values
  in 968 cells.
- cc9b9d1c (3,551): 47 centres — the widest <8
  set; all 2^k−1 values except 31, plus 39
  non-2^k−1 values in 357 cells, including the
  high cluster 199–255.

The 42 vanishing centres (the corpus ≥8-absent
list of AES-NUM-114, reproduced exactly) split
per artifact in the <8 frame as: cc9b9d1c 88 of
the 116 cells across 31 distinct vanishing
centres; 0856a10c 13 cells / 6 centres {53, 77,
101, 128, 149, 254}; 773470cd 9 cells / 8 centres
{4, 50, 192, 224, 233, 239, 252, 255}; 0a0d378c
4 cells / 2 centres {128, 255}; 5ab3537d 1 cell
{239}; 76c3a8ff 1 cell {49}; MiniLM 0. Six
vanishing centres are shared between artifacts
(128, 233, 239, 252, 254, 255); the other 36 are
single-artifact, matching AES-NUM-114's count.
Centre 255 — itself a 2^k−1 value — vanishes at
≥8 corpus-wide and lives in 4 <8 cells across
three artifacts (0a0d378c 2, 773470cd 1,
cc9b9d1c 1). The vanishing population remains a
small-group rarity effect, now with its
per-artifact split measured: over three quarters
of it (88/116) is cc9b9d1c's.

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
- The 2 varying groups: identified as
  (5ab3537d, 21, 32776) and (773470cd, 21, 32776),
  mirror groups with identical cidx/ng/offset
  structure; each carries exactly 2 non-AP cells
  whose variation is entirely the tenth centre
  (15 vs 11) after an exact +3 ladder of nine:
  MEASURED. A separating function beyond cell
  identity and tautology: NOT PROVEN (and
  ungradeable stronger at two cells per group).
- Train 49's deviant: isolated local anomaly with
  a measured head cause (one extra head act; the
  identical triple block shifted by one position;
  all other tested fields modal or universal in
  the train): MEASURED. Phase slip and regime
  head readings: excluded on the same evidence.
- Train-less cidx 2: start in-distribution for
  its class ({5: 13, 6: 13}); residue, phase and
  surrounding-act fields all matching the train;
  isolation purely the missing cidx 6 classmate:
  characterisation MEASURED; any mark of the
  deviation: NOT PROVEN.
- The 873 classes: both enumerated (12 starts);
  identical cidx difference pattern [4, 2, 4, 4,
  2]; no tested field or lag period orders the
  starts: MEASURED as a negative — organisation
  NOT PROVEN.
- Centre-set shape: 2^k−1 completeness at ≥8 is
  0a0d378c-only (exact set there; every other
  artifact missing ≥1 shape value and carrying
  non-shape values); per-artifact sets and counts
  in both settings MEASURED; the mirror pair
  5ab3537d/773470cd shares its ≥8 centre set
  exactly but not its <8 set; the 42 vanishing
  centres split 88/13/9/4/1/1 per artifact
  (cc9b9d1c / 0856a10c / 773470cd / 0a0d378c /
  5ab3537d / 76c3a8ff): MEASURED.

## Next (slice 4.116)

(i) The mirror pair itself: 5ab3537d and
773470cd share the two varying non-AP groups
(same position, segment size, offsets, cidxs and
centres), an identical ≥8 centre set with
near-identical counts, and near-identical ≥8
unanimous totals — but different <8 centre sets.
How deep does the mirroring go: shared groups,
shared cells, shared centre distributions across
the whole shared enumeration, and where exactly
do the two artifacts diverge? (ii) The remaining
deviants given train 49's treatment: the 10
steady exceptions of trains 48/50/51 — does an
extra head act (or another head-region
difference) mark them too, or is train 49's
mechanism unique? (iii) The high centres: the
<8-only centres ≥192 per artifact, and
cc9b9d1c's 199–255 cluster in particular — what
groups and offsets carry them, and is 255's
≥8-absence in 0a0d378c (2 <8 cells) the same
rarity effect as the other vanishing centres?
Host/artifact analysis only — no physical child.
