# Run 72 is a singleton: the B 615 intruder has no other acts, sitting alone in A order between a −238 triple and a −239 singleton immediately before run 74's head; the partner-cell correspondence is NOT a census law (of 4 neither partners, only 2 sit in a cell of a vertex they touch, 1 sits in a cell only untouched vertices carry, and 1 sits in a cell no other pair carries; the threes score 4 of 7 in touched cells, 1 untouched-only, 2 unique); and the first-skipped past-left-end values of all 8 gaps form a small population on side A (448 ×3, 464 ×2, 480, 384, 0) with the two sides equal for gaps 1–7 and gap 8 alone split (A 0, B 404,667,368 — its B-side first skipped act is not offset-adjacent to its left bounding act at all) (AES-NUM-160)

Slice 4.160, worked under `docs/TASK_CONTRACT_4.160.md`
(contract published in the 4.159 closing commit @
493dd0e7). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef160.py (hef159.py verbatim as base plus the new
arms160) sha256
`ed8c45c5043f5ef95fa91244d397031525b5f3d2bd116706dcd4ef5d3c147bc7`
(870,893 B); arms160 sha256
`c8140b9ad1bc5c6d1b1867693e7271b34b45032cad6a5178626f4ca53e600a8b`
(14,696 B), its gzip sha256
`488c5a0c20c8e5e234bc2b2377a4030fed0ec189c9916ed7bb674e8c8a73d5ad`
(4,009 B). The base hef159.py was verified on-device
== VM (sha256 1e25470f…) before assembly. Crossing
record: the gzipped arms crossed in 11 sha-gated parts
of 373 B (last part 279 B), every part verified
on-device first try, no part rejected; the assembled
gzip at /tmp verified on-device to exactly the VM
sha256, the decompressed arms and the assembled
hef160 sha256 matched the VM exactly on-device, and
the script compiled on-device. The ONE bounded
host-side child was launched directly in a detached
tmux session on Mimir with the contract corpus
argv — the six hailo-ollama blobs in glob order,
then MiniLM — and finished with DONE160 as its last
content line, exit marker 0, error channel empty.
Output hef160.out: 45,198 lines / 8,657,772 B,
sha256
`2c6961e3ee65b397f033b682945b473252c72f2f5f23a2ba1c9964557465fd76`.
Prefix check, stated honestly: of its first 45,027
lines against hef159.out, exactly TWO lines differ
(lines 41,611 and 42,872 — both the frozenset
element-order variance already recorded under
AES-NUM-150/153–159; same content and length), all
other 45,025 lines byte-identical (diff verified
on-device). Section160: 171 lines / 20,592 B, sha256
`ddace38af0ce36212609726572636142bacdde103a6ce33d7f2f0b047bbd2d27`,
fetched by a device file read (full file, eof) and
read in full. Every control in the controls echo
reproduces its expectation exactly: residue-0 sets
37 / 38 / shared 25 / A-only 12 / B-only 13; A chains
16, B chains 22; byte2 census 85 listings / 96
distinct individual pairs / 11 hubs / 7 pairs at
exactly 3 listings; 8 gap records, each with a full
32-feature row; context act counts A 749 / B 751;
shared distinct acts 689, all 689 single-positioned;
intruder control (act at A 522 = (787733504, 32784,
2), shift +93, B position 615, secondary run 72);
run 74 control (length 83, shift +0, A extent
524..614); neither partners 4, threes 7; gap 4
past-left-end control 464 / 464.

Raw output kept on the Pi at ~/aesir-build/
(hef160.out, hef160.py, arms160.py, section160.txt);
local lineage in ~/workspace/.verify-tmp/aesir160.

## (i) The B 615 intruder in full — run 72 is a singleton

- **Run 72 has exactly one act.** Length 1, shift
  **+93**, A extent 522..522, B extent 615..615.
  The intruder act (787733504, 32784, 2) is the
  whole run: there are no other run-72 acts to sit
  anywhere in B, so the "where do run 72's other
  acts sit" question is answered by exhaustion —
  B 615 is the run's entire B footprint, trivially
  contiguous, span 1.
- **The A neighbourhood (518–526) is a seam of
  five runs in nine positions.** A 518 = run 70
  (+4, B 522); A 519–521 = run 71 (three acts at
  shift −238, B 281–283 in order); A 522 = the
  intruder (run 72, +93, B 615); A 523 = run 73
  (a second singleton, shift −239, B 284);
  A 524–526 = run 74's head (shift 0, in place).
  So A order runs 70, 71, 72, 73, 74 consecutively
  at this seam, each run's B landing far from the
  next: B 522, then 281–283, then 615, then 284,
  then 524 onward.
- **Relation to runs 73/74.** Run 73 is also a
  singleton (one act, A 523, −239, B 284) — the
  intruder and its immediate A successor are both
  lone displaced acts, in opposite B directions.
  Run 74 (83 acts, shift 0, A/B extents 524..614)
  begins immediately after the intruder in A
  order; the intruder's B landing (615) is exactly
  the first B position after run 74's B tail ends
  (614) — that is the seam AES-NUM-159 measured
  from the B side. Any mechanism is NOT PROVEN.

## (ii) The partner-cell correspondence, census-wide — NOT a law

The population is the AES-NUM-156 population: **4
distinct neither partners** and **7 threes**, over
224 pairs carrying only **16 distinct cells** in
total. Every partner and three carries exactly one
cell (multi-cell count 0 on both sides), so the
per-vertex and per-cell counts coincide.

- **Partners: 2 of 4 sit in a touched vertex's
  cell.** 40f079cf (the neither of the leaf chain)
  sits in (20, 32720, 6864), the cell of the leaf
  406820cf it touches (listing 21) — its other
  touched vertex, the root, carries 6932. 40fcb4ce
  sits in (20, 32720, 6932), the cell of the root
  40f019ce it touches (listing 26).
- **Partner A 4092dbce does NOT.** Its cell is
  (20, 32720, 6864), but both vertices it touches
  — the root (listing 23) and partner B (listing
  24) — carry 6932. 6864 is carried by pairs it
  does not touch (including the neither
  40f079cf). This corrects the reading invited by
  AES-NUM-159's derived note: partner A sits in
  the neither's cell, but the neither is **not** a
  vertex partner A touches — in the root triangle
  the correspondence holds for partner B and fails
  for partner A.
- **1401b000 sits in a cell no other pair
  carries.** Its cell (19, 7712, 7568) is unique
  in the census; neither three it touches (listings
  3 and 4, cells 2384 and (14, 9992, 4336)) carries
  it, and no untouched pair carries it either.
- **Totals (partners):** in a touched cell 2; not
  in touched but in an untouched vertex's cell 1
  (4092dbce); in no other pair's cell 1
  (1401b000). Cell-level: 2 of 4 partner-cell
  instances in touched cells.
- **Threes: 4 of 7 sit in a touched vertex's
  cell** (the root 40f019ce, in 6932 via its
  partners; 807fc7d1, 8096a8d1 and 806092d1, each
  in 6864 via their three-neighbours). 80e07cd1
  (6932) touches only 6864-carrying threes — it is
  the untouched-only case. 1401b180 (2384) and
  1401b280 ((14, 9992, 4336)) each carry a cell no
  other pair in the census carries at all.
- **Verdict:** the partner-cell correspondence is
  **NOT PROVEN as a general law** — it holds for
  exactly half the partners and fails in two
  different ways (untouched-only, and unique). Cell
  sharing is a property of the (20, 32720) cell
  pair 6864/6932 that dominates this census corner,
  not a listing-graph rule. Mechanisms NOT PROVEN.

## (iii) First-skipped past-left-end values, all 8 gaps

First skipped offset minus (left offset + left
size), computed per side from each gap's own
record (side-specific left acts checked — identical
values):

| gap | run | step | dist | skipped | mapping | past A | past B |
|-----|-----|------|------|---------|---------|--------|--------|
| 1 | 62 | 5 | 3 | 2 | ((1, 2),) | 448 | 448 |
| 2 | 62 | 11 | 6 | 5 | ((2, 0),) | 464 | 464 |
| 3 | 74 | 24 | 2 | 1 | ((2, 0),) | 448 | 448 |
| 4 | 74 | 31 | 5 | 4 | ((0, 1),) | 464 | 464 |
| 5 | 74 | 33 | 2 | 1 | ((0, 1),) | 480 | 480 |
| 6 | 74 | 37 | 2 | 1 | ((0, 1),) | 448 | 448 |
| 7 | 74 | 48 | 2 | 1 | ((1, 2),) | 384 | 384 |
| 8 | 102 | 49 | 5 | 4 | ((0, 0), (1, 1), (2, 2)) | 0 | 404,667,368 |

- **Side A population:** [448, 464, 448, 464, 480,
  448, 384, 0] — five distinct values {0, 384, 448,
  464, 480}, 448 the mode (×3). No value is a
  function of run (74 alone spans 384–480), skipped
  count (count 1 spans 384–480; count 4 gives both
  464 and 0), mapping (each multi-gap mapping spans
  at least two values) or distance (distance 2
  spans the full 384–480 range) on this population.
  Any determination is NOT PROVEN.
- **The two sides agree for gaps 1–7** — every
  contiguous gap's first skipped act sits at
  exactly the same past-left-end distance in both
  contexts.
- **Gap 8 alone splits, and splits totally.** Its
  side-A value is **0**: the first skipped act
  (791776792, 24, 0) begins exactly at its left
  bounding act's end (791776768 + 24). Its side-B
  value is **404,667,368**: the first B-side
  skipped act's offset is 1,196,444,160, nowhere
  near the shared left act's end — gap 8's B-side
  skipped population is not offset-contiguous with
  its bounding acts at all, consistent with
  AES-NUM-152's finding that gap 8 is the
  non-contiguous insertion block. The past-left-end
  measure is therefore a contiguity measure: it is
  small and side-symmetric exactly on the seven
  contiguous gaps, and meaningless as a distance on
  gap 8's B side.

## Next

Slice 4.161 — gap 8's B-side skipped population in
full against its A side (where its four B-side
skipped acts sit in offset order, and what bounds
them in B); the (20, 32720) 6864/6932 cell pair's
full population (every pair carrying either cell,
their listing graph); and the seam runs 70/71/73's
B neighbourhoods in full (B 281–284 and B 522
contexts). Host/artifact analysis only — no
physical child.
