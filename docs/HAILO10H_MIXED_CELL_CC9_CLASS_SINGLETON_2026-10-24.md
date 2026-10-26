# AES-NUM-109 — the mixed cell resolves to two neighbourhoods (cidx 44 alone against six identical instances; zero-count pair and neighbourhood identity separate the classes inside the cell, form does not); the cc9 rare-containing segments are a distinct subpopulation (set overlaps 37–1325x the independence expectation, only 11 segment sizes, offset quartiles concentrated in Q2/Q4); and the sister cidx-95 SPARSE singleton is unique at every common offset of its group, not only @17272 (total disagreement is confined to @17272)

Slice 4.109, worked under `docs/TASK_CONTRACT_4.109.md`
(contract committed first @ c7d3b401). Host/artifact
analysis only, on Mimir (purpleviking1) — no physical
child, no device run of any kind.

## Run and transfer record

The 23:05 firing published the contract @ c7d3b401 and
stopped. This firing (23:24) resumed: hef109.py built
locally (hef108 lineage plus hef109_arms.py, arms sha256
16d06f99…, script sha256 508cee03…, gz sha256 b0b531a5…),
the one-shot receiver landed on Mimir via file.write
(recv109.py, sha256 32a3c45d… verified identical on both
sides), the gz was proxy-uploaded (saved:45020; gz and
script sha256 verified on-device; py_compile OK), and
the script ran detached over the 7-artifact corpus to
DONE109 at line 9,554, output 1,204,591 B, sha256
a1b85028…. (The output is larger than recent slices
because arm (ii) prints a per-size share line for every
distinct cc9 census size; all findings below are taken
from the arm summary lines, which are complete.)

## Controls

All controls reproduce exactly: 128,787 small actions;
79,001 bursts; 745,849 pointer actions; 1,504 contexts;
2,049 trailing pairs; 75,215 champion bursts. DONE105
at line 3,576, DONE106 at line 3,670, DONE107 at line
3,701 and DONE108 at line 3,910 of this run's output,
identical to the AES-NUM-105/106/107/108 runs — the
whole hef lineage stands behind every number below.
Arm-level controls also reproduce exactly: the mixed
cell holds 21 pairs with position-equal distribution
{0: 6, 5: 15} (AES-NUM-108), and the cc9 containing
sets are fd 569 / f6 497 / e9 170 segments with union
929 of the 112,884-segment cc9 census (AES-NUM-108).

## (i) The mixed 0a0d378c @17344 cell, pair by pair

The cell (group 0a0d378c pos 20 size 32752, offset
17344; the group has exactly 2 common offsets) contains
7 instances — cidx 44, 83, 143, 149, 155, 161, 167 —
and exactly TWO distinct neighbourhoods:

- cidx 44 alone: 04000a00 / a000a280 / ff000000 /
  ff000000 / ff000000 (DENSE, 0 zero words).
- The other six instances, byte-identical to each
  other: 00000000 / e7ff0100 / ff010000 / 77070000 /
  07000000 (DENSE, 1 zero word).

All 21 pairs enumerated: the 6 total-disagreement
pairs are exactly cidx 44 against each of the six
others (each differing in exactly 10 bytes, per-position
(2,4,1,2,1) in all six); the 15 identical pairs are
exactly the pairs within the six. No other class
exists in the cell.

Separator tests within the cell (property values of
the 0/5 class vs the 5/5 class, overlap empty =
separates):

- Neighbourhood identity (same vs different
  neighbourhood): SEPARATES — definitionally, every
  0/5 pair is cross-neighbourhood and every 5/5 pair
  is within-neighbourhood.
- Zero-count pair: SEPARATES — (0,1) for all zero
  pairs, (1,1) for all identical pairs, ordered and
  unordered.
- The word at every one of the 5 positions (and each
  side's word, and each position's differing-byte
  count 2/4/1/2/1 vs 0): SEPARATES — with only two
  neighbourhoods in the cell, every position carries
  the split.
- Form pair: does NOT separate — both classes are
  (DENSE, DENSE); the AES-NUM-108 aggregate form
  signal (zero pairs never MID/SPARSE-paired) does
  not operate inside this cell.
- Instance identity: cidx 44 is in all 6 zero pairs
  and in no identical pair; each other instance is
  in exactly 1 zero pair and 5 identical pairs. The
  cell's zero class is one singleton instance set
  against a sixfold-repeated neighbourhood — the
  same singleton-vs-many structure as the sister
  @17272 cells, here with both sides DENSE.

So the within-cell separator AES-NUM-108 left NOT
PROVEN is now ESTABLISHED for this cell: the classes
are separated by neighbourhood identity itself (and
equivalently by the zero-count pair (0,1) vs (1,1));
what form cannot do, identity does. The 0/5 phenomenon
in this cell is a two-neighbourhood cell read pairwise.

## (ii) The cc9b9d1c rare-containing segments as a class

Containing sets (cc9 census N = 112,884 distinct
referenced segments): fd000000 in 569, f6000000 in
497, e9ff0000 in 170; union 929.

Set overlaps vs the independence expectation
(|A|·|B|/N):

- fd × f6: observed 251, expected 2.51 — 100.2x.
- fd × e9: observed 33, expected 0.857 — 38.5x.
- e9 × f6: observed 28, expected 0.748 — 37.4x.
- Triple (all three words): observed 5, expected
  0.0038 — 1,325x.

302 of the 929 union segments (32.5%) contain at
least two of the three words; exclusive membership
is fd-only 290, f6-only 223, e9-only 114 segments.
The three words do not merely concentrate in the
same artifact — they co-occur in the same segments
far beyond any independent placement.

Joint size structure: the class's segments take only
11 distinct sizes — 304, 2576, 3856, 14352, 14864,
17936, 18320, 26896, 28968, 32016, 32784 — against
the census's long size ladder (hundreds of distinct
sizes; census mean 19,766.5 B). The union's
mean size is 24,636.3 B. Size 32784 alone carries
542 of 929 class segments (58.3%, vs its 28.4%
census share); 17936 carries 118 (12.7% vs a 2.25%
census share) and 14864 carries 95 (10.2% vs 2.25%).
Per word: fd segments span 10 of the 11 sizes
(32784: 355 of 569), f6 spans all 11 (32784: 285 of
497), and e9 spans only 4 sizes (14864: 27, 17936:
29, 18320: 10, 32784: 104 of 170).

Occurrence structure over the union: total rare
occurrences per segment run 1–38 (mean 3.96); 548
segments hold exactly 1, and the tail is heavy
(segments at 24–38 total occurrences exist for the
fd/f6 pair). Per word, fd runs to 28 in one segment
and f6 to 21 (AES-NUM-108), while e9 stays at 1–2
per segment (160 of 170 hold exactly 1).

Offset structure (segment-offset quartiles of the
cc9 address span, the AES-NUM-108 construction):
census segments split near-uniformly [28,935,
27,885, 28,478, 27,586], but union segments split
[19, 461, 57, 392] — Q2 holds 49.6% (2.01x its census
share) and Q4 42.2% (1.73x), while Q1 is nearly empty
(2.0%, 0.08x) and Q3 is depleted (6.1%, 0.24x). All
three words show the same Q2/Q4 concentration
individually (fd [12, 283, 42, 232]; f6 [7, 239, 39,
212]; e9 [0, 91, 4, 75]).

Verdict: the rare-containing class is a DISTINCT
subpopulation of cc9b9d1c, not a density artefact of
the census — it is size-restricted (11 sizes),
offset-concentrated (Q2+Q4 hold 91.8% of it), and
its three words co-occur in shared segments at
37–1,325x the independence expectation. Which
referencing actions (positions/channels/contexts)
point at these 929 segments was not measured in
this slice and is the open half of the class's
identity.

## (iii) The sister cidx-95 SPARSE singleton's uniqueness

Both sister groups (5ab3537d and 773470cd, pos 21
size 32776, 10 instances: cidx 0, 3, 6, …, 24 and 95)
have exactly 4 common offsets — 11136, 17272, 20300,
32192 — and the two artifacts agree on every number
below, line for line.

At @17272 cidx 95 is the only SPARSE instance (3 zero
words; the nine partners are DENSE with 1). The arm
then tested cidx 95 at the other three common offsets:

- @11136: singleton MID (2 zeros), words 00000000 /
  03000000 / ff010000 / 00000000 / 000e0000; eq vs
  every partner = 2 (9/9); partners among themselves
  eq 5 in all 36 pairs (one shared neighbourhood).
- @17272: singleton SPARSE, eq 0 vs all 9 partners;
  partner-partner eq {2: 8, 4: 28}.
- @20300: singleton SPARSE (00b08800 / 00000000 /
  ff0f0000 / 00000000 / 00000000), eq 2 vs all 9;
  partner-partner eq 5 in all 36 pairs.
- @32192: singleton SPARSE (00000000 / 03000000 /
  ff0b0000 / 00000000 / 00000000), eq 1 vs all 9;
  partner-partner eq {2: 8, 4: 28}.

At EVERY common offset the singleton's neighbourhood
is distinct from all nine partners', its form is
unique in the group, and its zero count is unique in
the group (4 of 4 offsets, both artifacts). Its
eq-vs-partners is a single value at each offset
(2, 0, 2, 1 respectively) — it stands at one fixed
distance from a partner population that is itself
either unanimous (eq 5 at 11136/20300) or split into
label-variants (at 17272/32192).

Verdict: the singleton's uniqueness is NOT confined
to @17272 — it is a group-wide property at every
common offset, on neighbourhood identity, form and
zero count alike. What IS confined to @17272 is the
total-disagreement (0/5) expression of that
uniqueness: no other common offset gives eq 0
against any partner, and none gives eq 5 either —
the singleton never fully agrees and only once
fully disagrees.

## Grades

- Mixed cell @17344: two-neighbourhood structure
  (cidx 44 singleton vs six identical instances),
  all 21 pairs enumerated: MEASURED. Within-cell
  separator ESTABLISHED (neighbourhood identity;
  zero-count pair (0,1) vs (1,1); every position's
  word) — the AES-NUM-108 NOT PROVEN is closed for
  this cell. Form as a within-cell separator:
  REFUTED (both classes (DENSE, DENSE)).
- cc9 rare-containing class: distinct subpopulation
  MEASURED (overlaps 37–1,325x independence; 11
  sizes only; Q2+Q4 = 91.8% of the class vs 49.1%
  of the census). The referencing-action profile of
  the 929 segments: NOT MEASURED this slice.
- Sister singleton: uniqueness at all 4 common
  offsets (identity, form, zero count), in both
  sister artifacts: MEASURED. Total disagreement
  confined to @17272: MEASURED. Why cidx 95 is the
  singleton (its role in the group): NOT PROVEN.

## Next (slice 4.110)

(i) The mixed cell's second common offset, and
cidx 44's profile across the other groups it sits
in — is the @17344 singleton the same kind of
instance at the cell's other offset and elsewhere?
(ii) The referencing-action profile of the cc9 929:
which (pos, size, channel) actions and which
contexts reference them, vs all cc9 references —
the class's identity from the pointing side.
(iii) The cidx-95 singleton's per-offset differing
positions (which of the 5 positions carry its
distance 2/0/2/1 at the four offsets) and its
profile in the other groups of its artifacts.
Host/artifact analysis only — no physical child.
