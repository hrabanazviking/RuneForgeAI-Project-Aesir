# AES-NUM-112 — the centre ff-word value ladder is a per-cell ladder, not a single staircase: across 55,902 analysable cells (527,236 observations) all 256 centre values occur, the mode is value 15 (ff0f0000), and ff010000 is neither the minimum, nor the most frequent, nor the index-zero value — it is one member among others; in the all-distinct ladder cells the values are non-decreasing by instance rank in 11,212 of 11,242 cells, with step +4 the modal arithmetic-progression step but a whole family of steps beside it; the 813 triple's start position is determined by NO tested function of the referencing context (graded NOT PROVEN); and 11608-class unanimity is the corpus norm, not the exception — 39,673 of 55,902 analysable cells (71.0%) are unanimous, their centres spanning 71 distinct values with ff0f0000 dominant (24,276 cells) and ff010000 carrying only 1,016 (2.56%)

Slice 4.112, worked under `docs/TASK_CONTRACT_4.112.md`
(contract committed first @ 25a2b310). Host/artifact
analysis only, on Mimir (purpleviking1) — no physical
child, no device run of any kind.

## Run and transfer record

hef112.py was built locally (hef111 lineage: hef111.py
with its final `print('DONE111')` replaced by the
4.112 arms, hef112_arms.py). Two runs stand on the
record, honestly:

- First run: arms sha256 b102df8c…, script sha256
  5c25611d…, gz sha256 687be059… (saved:57387 on the
  proxy upload through the one-shot receiver
  recv112.py, sha256 00f7f14a… verified identical on
  both sides; gz and script sha256 verified on-device,
  py_compile passed), ran detached to DONE112 at line
  11,026, output 1,583,298 B, sha256 fa2e8dc2…
  (retrieved gz sha256 a5fa144b… verified identical
  both sides). Its arm-(ii) cc9 rare-class union,
  however, came out as 1 segment instead of the
  control value 929: a stale-variable defect in the
  arms (the set builder yielded a leftover global
  `(oo, ss)` pair instead of the per-item
  `(oo112, ss112)`), which invalidated exactly the
  class-ref-count and cohort determinism tests of
  arm (ii). All other arms were unaffected.
- Corrected run: the one-line fix was applied, arms
  sha256 eed36559…, script sha256 3f152865…, gz
  sha256 750510f8… (saved:57393, same receiver and
  proxy-upload pattern; gz and script sha256 verified
  on-device, py_compile passed), ran detached over
  the 7-artifact corpus to DONE112 at line 11,026,
  output 1,583,758 B, sha256 0cf729b7… (retrieved gz
  sha256 6753ce5d… verified identical both sides).
  Arms (i) and (iii) are byte-identical between the
  two runs (verified); every number below is from
  the corrected run.

## Controls

All controls reproduce exactly: 128,787 small actions;
79,001 bursts; 745,849 pointer actions; 1,504 contexts;
2,049 trailing pairs; 75,215 champion bursts; TRAINS
52 / unique-first 28 / unanimous 13 / elsewhere 11 /
D113 249 / FIRST-D 3,089 / CTRL-D 176; CAMPS A
21392/13, B 21648/12. The inherited DONE markers stand
at the same lines as in the AES-NUM-111 run (DONE105
at line 3,576, DONE106 at 3,670, DONE107 at 3,701,
DONE108 at 3,910). Arm-level controls also reproduce
exactly: the cc9 rare-class union is 929 in arm (ii)
(per-word 569/170/497 in the inherited arm); the 813
target segment is oo 0, size 304, 813 references; the
start distribution reproduces AES-NUM-111 exactly
(4×1, 5×47, 6×31, 7×83, 8×56, 9×44, 10×9); and the
773470cd pos-9/size-32784 offset-11608 cell is found
in the unanimous set exactly once, centre ff010000.

Shared enumeration (arms (i) and (iii)): of 54,995
groups with ≥2 instances, 1,323 have ≥1 common offset,
giving 55,902 analysable (group, offset) cells and
527,236 instance-cell observations. Cells by artifact:
0856a10c 12,631; 0a0d378c 7,854; 5ab3537d 6,970;
76c3a8ff 9,470; 773470cd 7,485; MiniLM 4; cc9b9d1c
11,488.

## (i) The centre ff-word value ladder as a population

All analysable cells (55,902 cells, 527,236
observations): the centre byte takes ALL 256 values
(0–255). The population is dominated by value 15
(ff0f0000): 298,610 observations, 56.64%. Value 1
(ff010000) occurs 9,729 times (1.85%); value 0 occurs
20,230 times. Consecutive distinct values are spaced
by exactly 1 everywhere (the full byte range is
populated, so there is no corpus-wide "ladder spacing"
at the population level).

The ladder proper — the 11,242 all-distinct cells
(every instance's neighbourhood distinct, the
AES-NUM-111 general-variation setting; 87,178
observations): 255 distinct centre values occur (only
value 251 is absent). Mode is again value 15 (5,064,
5.81%); value 1 occurs 190 times (0.22%); the minimum
is 0 (11 observations). Within these cells the values
are ordered by instance rank with near-perfect
regularity:

- non-decreasing by rank in 11,212 of 11,242 cells
  (99.73%); strictly increasing in 8,541 (75.97%);
  all centres equal in 2,671.
- Rank-arithmetic progressions (cells of length ≥3):
  2,584 cells, with step distribution {0: 352, +2: 26,
  +3: 489, +4: 741, +6: 164, +8: 350, +9: 217, +12: 200,
  +24: 34, +40: 11} — step +4 is the single most common
  nonzero step (the 12752 ladder of AES-NUM-111), but
  it governs only 741 of 2,584 AP cells; +3, +8, +9
  and +12 are substantial beside it.
- Successive rank differences over all distinct cells
  are led by +4 (21,605), then +3 (14,035), +9 (8,260),
  +8 (6,681), 0 (5,702), +6 (5,612), +12 (3,072),
  +5 (2,845) — again +4 first, never alone.
- The centre value is NOT a function of rank alone:
  every rank 0–27 carries many distinct values across
  cells (rank 0: 99 distinct; rank 1: 134). Nor of
  cidx alone: 351 of 1,403 (artifact, cidx) keys carry
  more than one centre value across their distinct
  cells. The ladder is per-cell: a cell-specific base
  and step, jointly.

Is ff010000 the ladder's base? On every reading of
"base", no:

- Minimum: no — value 0 occurs in both populations
  and the ladder minimum is 0, not 1.
- Most frequent: no — the mode in both populations
  is value 15 (ff0f0000), by a wide margin.
- Index-zero (the rank-0 instance's value): no —
  rank 0 takes 99 distinct values in the ladder cells
  (132 in all cells); rank 0 equals 1 in only 188 of
  11,242 ladder cells (1,206 of 55,902 in all cells),
  while rank 0's own mode is value 15 (2,297 ladder
  cells; 31,273 overall). Rank 0 is the cell minimum
  in 11,224 of 11,242 ladder cells — the ladder
  starts at its base — but that base is usually not
  1.

Verdict: ff010000 is a member of the ladder, not its
base. Its distinction is positional, not
populational: it is the centre of particular cells
(notably the unanimity cell at 11608), not the root
of the value system.

## (ii) The 813-triple start position as a function of the referencing context

The referencing law of AES-NUM-111 is reproduced:
all 271 cc9 contexts carry exactly one channel-0
start, the three references are consecutive triples
starting at that start in every context, and the
start distribution is {4: 1, 5: 47, 6: 31, 7: 83,
8: 56, 9: 44, 10: 9}. Every recorded per-context
field was then tested as a would-be function
(start must be uniquely determined by the field):

- network-group (ng): 2 keys, both ambiguous (ng 0
  spans all 7 starts; ng 1 spans 5–10). Not a function.
- ngidx (index within ng): 137 keys, 100 ambiguous.
- Context size / total action count: 20 distinct
  sizes, 14 ambiguous (e.g. 245 acts carries starts
  {5, 7, 8}; 606 acts {5, 6, 7, 8}; 738 acts
  {5, 6, 7, 8, 9}). Not a function.
- Rare-class reference count: 20 distinct counts,
  13 ambiguous.
- Cohort: all three cohorts ambiguous — exactly-3
  contexts span starts 5–10, heavy contexts 4–9,
  the rest 5–10. Heaviness says nothing about start.
- Distinct segments referenced: 20 keys, 14 ambiguous.
- Sum of action sizes: 246 keys, 15 ambiguous (the
  near-unique key still does not determine start).
- First action, as (offset, size, channel): 65 keys,
  14 ambiguous; as (size, channel): all 3 keys
  ambiguous.
- First-4 action sizes: the single key (24, 24, 24,
  24) spans all 7 starts. First-4 channels: 37 keys,
  17 ambiguous.
- The action immediately before the triple: as
  (size, channel) all 3 keys ambiguous; as the full
  (offset, size, channel) 52 keys, 14 ambiguous.
- The action immediately after the triple
  (size, channel): 40 keys, 18 ambiguous.
- Modular tests: cidx mod k, total-acts mod k and
  ngidx mod k determine the start for NO k in 2..64.
- Previous context's start: ambiguous (e.g. a
  previous start of 7 is followed by every start
  5–10).

One honest nuance: read in cidx order, the start
sequence shows long locally periodic stretches
(the block 5, 8, 8, 7, 6, 8, 9, 7 repeats verbatim
through the early contexts), so the placement is
not structureless — but the periodicity is local
and breaks across the full context list, and no
tested global field or modulus captures it.

Verdict: the start position is NOT determined by
any tested function of the referencing context —
not its index, its ng, its position in its ng, its
size, its class load, its head actions, its
neighbouring actions, or the previous context's
start. What seats the triple remains NOT PROVEN.

## (iii) 11608-class unanimity offsets across the corpus

Of the 55,902 analysable cells, 39,673 are unanimous
— all instances of the group share one neighbourhood
at that offset — and 16,229 are not: unanimity is
the corpus norm at 70.97%, not a 11608 curiosity.

Their centres do NOT share the value-1 pattern. The
39,673 unanimous cells span 71 distinct centre
values, dominated by ff0f0000 (value 15) with 24,276
cells (61.19%), followed by ff050000 (2,881),
ff7f0000 (value 127; 2,846), ff070000 (2,122),
ff000000 (1,354), ff020000 (1,070) and only then
ff010000 with 1,016 cells (2.56%). The remaining 64
values carry between 1 and 548 cells each. The
11608 cell (773470cd, pos 9, size 32784, 8 instances,
centre ff010000) is verified present in the set,
exactly once — one member of a large class whose
typical centre is 15, not 1.

Distribution:

- By artifact (unanimous / analysable, rate):
  0856a10c 8,099/12,631 (0.6412); 0a0d378c
  6,469/7,854 (0.8237); 5ab3537d 5,653/6,970
  (0.8110); 76c3a8ff 6,165/9,470 (0.6510);
  773470cd 6,120/7,485 (0.8176); cc9b9d1c
  7,167/11,488 (0.6239); MiniLM 0/4 (its only 4
  analysable cells are all non-unanimous).
- By group size: unanimity is not a small-group
  artifact — rates stay in the 0.58–0.82 band across
  group sizes 2 through 27+ (size 2: 10,622/15,132,
  0.7020; size 8 — the 11608 setting: 1,434/2,010,
  0.7134; size 11: 1,492/1,825, 0.8175; size 25:
  918/1,207, 0.7606), with one dip at size 17
  (127/289, 0.4394).
- By group position: the main positions 5–30 carry
  rates of roughly 0.62–0.82 (pos 9: 1,693 unanimous
  cells, rate 0.8104; pos 6: 0.9202; pos 8: 0.6084);
  no position is unanimity-free and none is
  unanimity-only among the well-populated positions.

Verdict: 11608 is ordinary in kind — a unanimous
cell in a corpus where seven cells in ten are
unanimous — and unusual only in its company (it
sits inside a group whose other 9 common offsets
are [7,1] singleton splits) and in its centre,
value 1, which the unanimous population as a whole
does not favour.

## Grades

- Centre ladder population: 55,902 analysable cells,
  527,236 observations, all 256 centre values;
  mode value 15 in both the full population
  (298,610; 56.64%) and the all-distinct ladder
  cells (5,064/87,178; 5.81%): MEASURED.
- ff010000 as ladder base: NOT the minimum (0
  occurs; ladder minimum 0), NOT the most frequent
  (mode 15), NOT the index-zero value (rank 0 spans
  99 distinct values in ladder cells and equals 1
  in only 188/11,242): MEASURED — it is a member
  among others.
- Ladder ordering: non-decreasing by rank in
  11,212/11,242 all-distinct cells; strictly
  increasing in 8,541; rank-AP in 2,584 length-≥3
  cells with step +4 modal (741) over a family
  {+3: 489, +8: 350, +9: 217, +12: 200, +6: 164,
  +2: 26, +24: 34, +40: 11, 0: 352}; centre value is
  a function of (cell, rank) jointly, not of rank
  or cidx alone: MEASURED.
- 813-triple start: reproduced exactly (7 starts,
  mode 7 ×83, consecutive triples in all 271
  contexts); determined by NO tested per-context
  field (ng, ngidx, cidx mod k, size, class count,
  cohort, distinct segments, size sum, first/head
  actions, preceding and following actions,
  previous start — every test ambiguous): the
  determining function is NOT PROVEN.
- Unanimity across the corpus: 39,673/55,902 cells
  unanimous (70.97%); 71 distinct unanimous centres,
  ff0f0000 dominant (24,276; 61.19%), ff010000 only
  1,016 (2.56%); rates 0.62–0.82 in every artifact
  except MiniLM (0/4) and across group sizes and
  positions; target cell 11608 verified in-set with
  centre ff010000: MEASURED.
- What the per-cell ladder's (base, step) pair is a
  function of, what seats the 813 triple, and why
  the unanimous population's centre is so heavily
  value 15: NOT PROVEN.

## Next (slice 4.113)

(i) The per-cell ladder's parameters as a
population: each ladder cell's (base, step) pair —
is the pair a function of the cell's group/offset,
and what governs the step family {+4, +3, +8, +9,
+12, …}? (ii) The 813 triple's start against
sub-sequence position: the cidx-order start sequence
is locally periodic — is start a function of the
context's rank within its own (ng, size) train or
another sub-sequence the global fields cut across?
(iii) Unanimity in the 11608 setting proper:
restricted to groups of ≥8 instances, how many
cells are unanimous, what are their centres (is
value 1 over- or under-represented there against
its 2.56% corpus share?), and why is the
corpus-wide unanimous centre so heavily value 15 —
is the unanimous centre a function of group/offset?
Host/artifact analysis only — no physical child.
