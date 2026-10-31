# Gap 8's B-side skipped block is a regular 512-stride ladder transplanted to a different offset region (in offset order it is ordinary: contiguous ranks 747–750, first act 496 past a 32,784-byte act's end — the 404,667,368 split is a position-context artifact); the (20, 32720) cells 6864 and 6932 are disjoint 27/27 populations over 54 pairs (no pair carries both; the induced listing graph has 21 internal edges, 4 boundary edges and 28 isolated pairs; membership is a function of NO tested field); and at the seam, runs 71+73 form one contiguous B block at 281–284 while run 70 sits contiguous at B 520–522, every act at B 276–290 and B 516–528 shared single-positioned (AES-NUM-161)

Slice 4.161, worked under `docs/TASK_CONTRACT_4.161.md`
(contract published in the 4.160 closing commit @
539d04d2). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef161.py (hef160.py verbatim as base plus the new
arms161) sha256
`e5d7722645bb07931b59f54cf5c6e15699176904923b03b3d34af614046bebe8`
(884,211 B); arms161 sha256
`a079a3e10cdcd71288865502bb19c9934380594124ded20e7e184b7ec1b8290f`
(13,318 B), its gzip sha256
`40d786f24b2e95bdfc1ba3b614f52ab0d434ee375f62d3d557b659a5ac2cef38`.
The base hef160.py was verified on the VM ==
the on-device hef160 (sha256 ed8c45c5…) before
assembly. Crossing record: the gzipped arms crossed
in 11 sha-gated parts of 373 B (last part 356 B);
10 parts verified on-device first try; part af was
discarded once on a sha256 mismatch (a truncated
sha string in the worker's own call — the write was
discarded uncommitted by the sha gate) and landed
on the verbatim retry with the full sha. The
assembled gzip, the decompressed arms and the
assembled hef161 sha256 all matched the VM exactly
on-device, and the script compiled on-device. The
ONE bounded host-side child was launched directly
in a detached tmux session on Mimir with the
contract corpus argv — the six hailo-ollama blobs
in glob order, then MiniLM — and finished with
DONE161 as its last content line. Exit marker
recorded honestly: the tmux wrapper's exit marker
read 1 while the error channel held nothing but
that marker (no traceback, no stderr text) and the
output is complete through DONE161 with every
control exact; the cause of the marker is NOT
ESTABLISHED and the run was NOT repeated (one
bounded child per contract). Output hef161.out:
45,366 lines / 8,684,774 B, sha256
`82e898ae96bf5a932a3ea799db297ad6f3c50a5d9764f8fef9eca87033e0b0ff`.
Prefix check: of its first 45,198 lines against
hef160.out, exactly TWO lines differ (lines 41,611
and 42,872 — both the frozenset element-order
variance already recorded under AES-NUM-150/153–160;
same content and length), all other 45,196 lines
byte-identical (diff verified on-device).
Section161: 168 lines / 27,002 B, sha256
`4b0b9c2c6c5f1a0088d9870ec49059dddeec1411fc3b645339fee3d82d64f4e0`,
fetched by a device file read and read in full.
Every control in the controls echo reproduces its
expectation exactly: residue-0 sets 37 / 38 /
shared 25 / A-only 12 / B-only 13; byte2 census
85 listings / 96 distinct individual pairs / 11
hubs / 7 pairs at exactly 3 listings; 8 gap
records; gap 8 = run 102, step 49; context act
counts A 749 / B 751; shared distinct acts 689,
all 689 single-positioned; seam control A 518–526
runs [70, 71, 71, 71, 72, 73, 74, 74, 74]; gap 8
past-left-end control A 0 / B 404,667,368.

Raw output kept on the Pi at ~/aesir-build/
(hef161.out, hef161.py, arms161.py, section161.txt);
local lineage in ~/workspace/.verify-tmp/aesir161.

## (i) Gap 8's B-side skipped population in full

Gap 8 (run 102, step 49; distances A 5 / B 5;
shifts left +2, right +2; channel mapping full
((0, 0), (1, 1), (2, 2), (0, 0))). Both bounding
acts are identical in the two contexts: left
(791776768, 24, 0) at A 732 / B 734; right
(768609280, 24, 0) at A 737 / B 739. The left ends
(offset + size) are equal on both sides:
791,776,792.

- **The A-side four** (A positions 733–736) form a
  ladder flush against the left bound: offsets
  791,776,792 / 791,777,280 / 791,777,792 /
  791,778,304, all size 24, channels 0, 1, 2, 0;
  past-left-end values 0, 488, 1000, 1512 (start
  strides 488, 512, 512).
- **The B-side four** (B positions 735–738) have
  the identical shape — size 24 each, channels
  0, 1, 2, 0, start stride a perfectly regular
  512 throughout — but live at offsets
  1,196,444,160 / 1,196,444,672 / 1,196,445,184 /
  1,196,445,696, a wholly different offset region.
  Paired by the gap record's mapping, the B−A
  offset difference is +404,667,368 for pair 0 and
  +404,667,392 for pairs 1–3: the B block is the
  A block transplanted by a constant, except that
  pair 0 sits 24 closer — exactly because the A
  block's first stride is 488 (its first act flush
  at the left end, past-left 0) while the B block
  is regular from its first act. Sizes all equal
  (diff +0); no skipped act is the same act on
  both sides.
- **By position**, the B block is bounded exactly
  by the gap's bounds: B 731–733 are the ordinary
  512-stride ladder acts below the left bound
  (791,775,232 / 791,775,744 / 791,776,256), the
  left bound sits at B 734, the four skipped at
  735–738, the right bound at B 739, and the
  ladder resumes below it at B 740–742
  (768,609,792 onward).
- **By offset**, the block is unremarkable: its
  four acts hold offset ranks 747–750 of 751 —
  contiguous, B-position order == offset order —
  and the first skipped act sits only **496 past
  the end of its offset predecessor** (the
  32,784-byte act (1196410880, 32784, 2) at
  B position 674). Inside the block each act sits
  488 past its predecessor's end, exactly as on
  side A.
- **Verdict on the split.** The 404,667,368
  past-left-end split is a position-context
  artifact: the measure compares a skipped act's
  offset against its *position* neighbour's end,
  and gap 8's B-side skipped acts are not the
  offset neighbours of their position neighbours
  at all. In offset order the block is an ordinary
  contiguous ladder segment. Any deeper mechanism
  (why this gap's B side draws its skipped acts
  from the 1.196 B region) is NOT PROVEN.

## (ii) The (20, 32720) 6864/6932 cell pair — disjoint 27/27

- **Populations.** Cell (20, 32720, 6864) is
  carried by **27 pairs**; cell (20, 32720, 6932)
  by **27 pairs**; the union is **54 pairs** and
  **no pair carries both cells** (6864-only 27,
  6932-only 27). Every one of the 54 carries
  exactly one record and group (20, 32720).
- **The root triangle inside the population.**
  The root 40f019ce sits in 6932; the neither
  40f079cf sits in 6864; its partners split across
  the two cells — 4092dbce in 6864, 40fcb4ce in
  6932 (consistent with AES-NUM-159/160). The leaf
  406820cf sits in 6864.
- **Induced listing graph.** Over the 85 listings,
  the 54 pairs induce **21 internal edges** and
  exactly **4 boundary edges** (listings 11, 16,
  17, 29 — one A-in, three B-in); **28 of the 54
  pairs are isolated** in the induced graph (they
  carry no listing at all). The internal edges
  form small components: the root-triangle
  component (listings 8, 21, 23, 24, 26), the
  census-3 three-cluster (listings 57–59, 64, 65,
  67 — derived at closing: three of its four
  threes, 806092d1 / 807fc7d1 / 8096a8d1, sit in
  6864 while the fourth, 80e07cd1, sits in 6932,
  so that cluster straddles both cells), two
  triangles (68–70; and 18/19 pairs), and disjoint
  pairs (25, 27, 42, 63, 76).
- **Membership is a function of nothing tested.**
  Cell membership (6864 vs 6932) is NOT A FUNCTION
  of group (1 violating value of 3), status (2 of
  2), A byte0 (6 of 36), B byte0 (7 of 29), class
  (3 of 7), census (4 of 7) or record count (1 of
  2 — the whole population has exactly 1 record,
  so that test is vacuous on the population and
  violating only across the wider census). The
  split's determinant remains NOT PROVEN; the
  untested field space (full B value, byte1–byte3,
  offset fields) is named for slice 4.162.

## (iii) The seam runs 70/71/73 B neighbourhoods in full

- **Run 70** (3 acts, shift +4, A 516–518) sits
  **contiguous at B 520–522**, in A order.
- **Run 71** (3 acts, shift −238, A 519–521) sits
  **contiguous at B 281–283**; **run 73** (the
  −239 singleton, A 523) sits at **B 284** —
  immediately after run 71, so in context B the
  two displaced seam runs form **one contiguous
  four-act block at B 281–284** (−238 ×3, then
  −239), even though in A order the +93 intruder
  (run 72) sits between them.
- **B 276–290 in full:** run 18's tail (+2) at
  276–279; a displaced singleton of run 93
  (A 671, shift −391) at B 280; the 71/73 block at
  281–284; run 20 (+5) from B 285 onward. Every
  act in the window is shared single-positioned
  (15/15).
- **B 516–528 in full:** run 69's tail (+2) at
  516–517; run 19's +240 pair at 518–519; run 70
  at 520–522; a run-64 singleton (A 500, +23) at
  B 523; run 74's head (shift 0, in place) from
  B 524 onward. Every act in the window is shared
  single-positioned (13/13).
- So the seam's B geography is block-structured,
  not scattered: each seam run lands as one
  contiguous block, and the blocks' B order
  (…, 71/73 at 281–284, …, 70 at 520–522, 74 from
  524) differs from their A order. Any mechanism
  is NOT PROVEN.

## Next

Slice 4.162 — gap 8's B-block offset region in
full (the acts around offset ranks 740–760 and
the run of the offset predecessor at B 674);
the 6864/6932 split tested against the untested
fields (full B value, byte1–byte3, byte3 diff,
full diff); the B 280 run-93 singleton and the
run 19/20 blocks at the seam in full.
Host/artifact analysis only.
