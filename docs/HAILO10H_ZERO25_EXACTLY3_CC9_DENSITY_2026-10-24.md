# AES-NUM-108 — the 25 total-disagreement pairs are a concentrated, structurally uniform exception class (4 (group,offset) cells, every pair differing in exactly 10 bytes; no group/offset separator — one cell holds both 0/5 and 5/5 pairs); the exactly-3 band stays near-empty at every level (2 pairs, both MID/MID; agreement grades per-(group,offset) cell, not per group); and cc9b9d1c's rare-word concentration is real per referred byte (fd000000 841.7 and f6000000 726.9 per 1e9 bytes, ~2.5–3x the densest other blob) and is carried by a tiny subpopulation (929 of 112,884 cc9 segments hold all 3,680 cc9 rare occurrences)

Slice 4.108, worked under `docs/TASK_CONTRACT_4.108.md`
(contract committed first @ ea3a2ace). Host/artifact
analysis only, on Mimir (purpleviking1) — no physical
child, no device run of any kind.

## Run and transfer record

The 22:07 firing published the contract @ ea3a2ace and
stopped. The 22:31 firing built hef108.py locally
(hef107 lineage plus hef108_arms.py, arms sha256
c17e16cf…, script sha256 ad8f6ed0…, gz sha256
05a270dc…) and landed the receiver on Mimir, then
stopped before the proxy-upload (the 4.106/4.107 stall
pattern). This firing (22:53) resumed: receiver sha
verified identical on both sides (b70f37c2…), the gz
was proxy-uploaded (saved:41839; gz and script sha256
verified on-device; py_compile OK), and the script ran
detached over the 7-artifact corpus to DONE108 at line
3,910, output 658,695 B, sha256 1441b85f…. The arms
section (lines 3,702–3,910) and the control line were
read directly from the on-device output via device
stdout, as in AES-NUM-107.

## Controls

All controls reproduce exactly: 128,787 small actions;
79,001 bursts; 745,849 pointer actions; 1,504 contexts;
2,049 trailing pairs; 75,215 champion bursts. DONE105
at line 3,576, DONE106 at line 3,670 and DONE107 at
line 3,701 of this run's output, identical to the
AES-NUM-105/106/107 runs — the whole hef lineage
(AES-NUM-029/032…107 headline counts and sub-population
totals) stands behind every number below. The 4.107
pair population reproduces exactly: 789 pairs over 206
common-offset neighbourhood records in 18 groups,
position-equal distribution {0: 25, 1: 172, 2: 88,
3: 2, 4: 246, 5: 256}. The 4.107(ii) wider-population
totals reproduce exactly in arm (iii): 542,905 distinct
referenced segments, 745,849 references, 9,275,073,840
distinct referenced bytes; corpus distinct counts
fd000000 3,223, e9ff0000 209, f6000000 2,286.

## (i) The 25 total-disagreement (0/5) pairs as a class

The 25 pairs live in exactly FOUR (group, offset)
cells:

- 0a0d378c pos 20 size 32752 @ 17344 — 6 pairs, all of
  them cidx 44 against cidx 83/143/149/155/161/167, and
  all six are the SAME pair of neighbourhoods word for
  word (A = 04000a00/a000a280/ff000000/ff000000/
  ff000000, DENSE, 0 zero words; B = 00000000/
  e7ff0100/ff010000/77070000/07000000, DENSE, 1 zero
  word).
- 5ab3537d pos 21 size 32776 @ 17272 — 9 pairs, cidx
  0/3/6/…/24 against the single cidx 95; the B side is
  one identical SPARSE neighbourhood in all nine
  (00000000/00000000/ff0f0000/01000000/00000000, 3 zero
  words); the A sides are DENSE (1 zero word) and
  differ from each other only in the label byte of
  word 2 (ff010000, ff040000, …, ff190000).
- 773470cd pos 21 size 32776 @ 17272 — 9 pairs, the
  sister copy of the same structure, with the same A
  word families and the same B neighbourhood.
- MiniLM pos 23 size 32768 @ 9272 — 1 pair, the
  AES-NUM-104/105/107 target pair itself (cidx 3 vs 5,
  DENSE/DENSE, zero counts 1/1).

Class regularities, all zero-exception over the 25:
every pair differs in EXACTLY 10 bytes total; the
per-position differing-byte counts are 2 at position
0, 4 at position 1 and 1 at position 2 in all 25, with
positions 3/4 taking (1,2) in 7 pairs and (2,1) in 18.
Form pairs are only (DENSE, DENSE) ×7 and (DENSE,
SPARSE) ×18 — never MID or SPARSE/SPARSE. Zero-count
pairs are (0,1) ×6, (1,3) ×18 and (1,1) ×1: in 24 of
25 the two sides have DIFFERENT zero counts.

The 256 identical (5/5) control pairs are the mirror
image: form pairs (SPARSE, SPARSE) ×136, (MID, MID)
×93, (DENSE, DENSE) ×27, and zero-count pairs always
EQUAL — (3,3) ×136, (2,2) ×93, (1,1) ×27. Form-pair
and zero-count-pair vocabularies of the two classes
overlap only in (DENSE, DENSE) and (1,1) respectively.

Separator verdict: at the (group, offset) level there
is NO separator — 3 of the 4 zero-class groups also
contain 5/5 pairs, and the single cell 0a0d378c @
17344 contains both classes (6 zero pairs and 15
identical pairs among its 21). Within the measured
class aggregates, a zero pair is always a DENSE side
against a DENSE or SPARSE side with mismatched zero
counts (24/25) — but the arms did not break form/zero
patterns out per cell, so whether that property
separates the classes INSIDE the mixed 17344 cell is
NOT PROVEN. What is established: the 0/5 class is not
25 independent accidents — it is three repeated
structures (one repeated pair ×6, one singleton
SPARSE neighbourhood against 9 label-variants ×2
artifacts, and the 9272 target), each a DENSE
neighbourhood compared against a neighbourhood from
the other side of a form boundary.

## (ii) The exactly-3 band and the bimodality's structure

The two exactly-3 pairs, in full: 5ab3537d pos 9 size
32584 @ 31452 (cidx 28 vs 211, bytediff 3) and
cc9b9d1c pos 13 size 32784 @ 19268 (cidx 0 vs 134,
bytediff 2). Both are (MID, MID) with zero counts
(2,2) — the same form/zero signature as 93 of the
identical pairs; nothing about them is extreme except
the count 3 itself.

Per-group agreement (all 18 groups printed in the
run output): agreement is NOT a per-group property.
The two large sister groups (5ab3537d and 773470cd
pos 21, 180 pairs each) contain every value except 3
({0: 9, 1: 9, 2: 34, 4: 56, 5: 72}); most other groups
span three or more distinct values. Only 3 of 18
groups contain both a 0/5 and a 5/5 pair. A few groups
are narrow (0a0d378c pos 13: only {1, 4} over 136
pairs; MiniLM pos 23: the single 0/5 pair), but
narrowness is not concentration at one pole in
general.

Per-offset, the distributions narrow sharply — the
bimodality grades as a per-(group, offset) CELL
property: sister pos-21 offsets 11136 and 20300 give
{2: 9, 5: 36} (mean 4.4), offset 17272 gives
{0: 9, 2: 8, 4: 28} (mean 2.84) and offset 32192 gives
{1: 9, 2: 8, 4: 28} (mean 3.04) — the same group at
four offsets with almost disjoint distributions. Of
39 cells with pairs, exactly ONE contains both a 0/5
and a 5/5 pair (0a0d378c @ 17344, above). The
exactly-3 band is near-empty at every level scanned:
no group and no cell concentrates at 3 (max one
exactly-3 pair in any group or cell), so the empty
band is a corpus-wide gap between the {0,1,2} and
{4,5} masses, not a per-group artefact.

## (iii) cc9b9d1c rare-word concentration per referred byte

Per-artifact densities (distinct-segment aligned
occurrences per 1e9 distinct referred bytes):

- fd000000: cc9b9d1c 841.7 (1,878 occurrences; corpus
  count share 58.3% against a byte share of 24.1%) —
  2.5x the densest other blob (773470cd 337.0,
  5ab3537d 320.0), 4.2x 76c3a8ff (198.7), 11.2x
  0856a10c (74.8), 22.6x 0a0d378c (37.3).
- f6000000: cc9b9d1c 726.9 (1,622; share 71.0%) —
  3.0x 773470cd (242.4) and 5ab3537d (217.8); every
  other blob below 33.
- e9ff0000: cc9b9d1c 80.7 (180; share 86.1%) — 8.4x
  the next artifact (0856a10c 9.6); all others ≤3.3.

MiniLM's nominal densities (fd 2,034.1, f6 1,830.7
per 1e9) are a small-denominator artefact: 20 and 18
occurrences on 9,832,200 referred bytes, corpus shares
0.62% and 0.79%. Among the six blobs, cc9b9d1c's
concentration is real on all three words.

The concentration is NOT uniform across cc9b9d1c. It
is carried by a small subpopulation: fd000000 sits in
569 of cc9b9d1c's 112,884 distinct segments (0.50%),
whose bytes are 0.64% of cc9's referred bytes, yet
they hold all 1,878 cc9 occurrences — a mean of 3.30
occurrences per containing segment (elsewhere
1.0–1.6), with a heavy tail (distribution runs to a
max of 28 per segment; 179 segments hold ≥3).
Containing segments are dominated by size 32784 (355
of 569 for fd, 285 of 497 for f6, 104 of 170 for e9).
f6000000 mirrors fd (497 segments, mean 3.26, max 21).
e9ff0000 concentrates differently: 170 segments at a
mean of only 1.06 (max 2) — more containing segments,
not multiplicity. By segment-offset quartile the
occurrences are strongly non-uniform (fd: [12, 938,
152, 776]; f6: [7, 803, 131, 681]; e9: [0, 97, 4,
79]) — the second and fourth quartiles carry almost
everything. Union over the three words: 929 cc9
segments (0.82% of the artifact's segments, 1.03% of
its bytes) hold all 3,680 cc9 rare occurrences.

## Grades

- 0/5 class concentration and structural uniformity
  (4 cells, exactly 10 differing bytes in 25/25,
  per-position pattern, form/zero vocabularies):
  MEASURED.
- A measured property separating 0/5 from 5/5 inside
  the one mixed cell (0a0d378c @ 17344): NOT PROVEN —
  the per-cell form/zero breakout was not run.
- Exactly-3 band: near-empty corpus-wide, both pairs
  ordinary MID/MID (2,2) pairs: MEASURED. Agreement
  as a per-(group, offset) cell property rather than
  a per-group property: MEASURED.
- cc9b9d1c rare-word concentration per referred byte
  and its subpopulation carriage (929 segments):
  MEASURED. Why those segments and quartiles: NOT
  PROVEN.

## Next (slice 4.109)

(i) The mixed cell 0a0d378c @ 17344 broken out pair by
pair: form/zero/word patterns of its 6 zero pairs vs
its 15 identical pairs — the separator hunt at the
one place both classes coexist. (ii) The cc9
rare-containing segments as a class: fd/f6/e9
containing-set overlaps, and their joint size/offset
structure vs the cc9 census. (iii) The sister cidx-95
SPARSE singleton: is its neighbourhood unique in its
group, and do the 9 DENSE partners share any other
common offset where they agree? Host/artifact
analysis only — no physical child.
