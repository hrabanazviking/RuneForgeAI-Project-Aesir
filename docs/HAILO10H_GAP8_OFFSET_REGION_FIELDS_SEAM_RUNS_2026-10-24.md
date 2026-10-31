# Gap 8's B-block is the very top of context B's offset order — its last skipped act is B's largest-offset act, nothing follows the block in offset order, and the whole top region (ranks 738–750) is thirteen B-only acts scattered across B positions 19–738, the B 674 offset predecessor among them (B-only, no run, no A extent); the 6864/6932 split is a function of NO low-dimensional untested field — every single byte and the byte3 difference fail, and every field that does separate the 54 (full A/B values, full and bytewise differences, XOR, the (byte1, byte2) pairs and the (byte3, byte1+byte2) keys) is near-pair-identity at 217–224 distinct values over 224 pairs, so its function verdict is the trivial one pair-identity itself earns and the determinant stays NOT PROVEN; and the seam's remaining displaced blocks are each one contiguous B block (run 93 the −391 singleton at B 280, run 19's +240 pair at B 518–519, run 20's sixteen +5 acts at B 285–300), with A-adjacent runs 19 and 20 landing far apart in B (AES-NUM-162)

Slice 4.162, worked under `docs/TASK_CONTRACT_4.162.md`
(contract published in the 4.161 closing commit @
f4b52722). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef162.py (hef161.py verbatim as base plus the new
arms162) sha256
`e93050825ed4e516ad88efd338ade87be89aab4d4f31e1464bd3f10d4435933f`
(899,342 B); arms162 sha256
`71f4a145dd88a56b1cd1006c33d7cf951eab7bdf093b3ec5c47a15e59ca7574c`
(15,131 B), its gzip sha256
`a14160140e123fed6d9511323e53442828f4734011333d8a2cac01d54f6341c9`.
The base hef161.py was verified on the VM ==
the on-device hef161 (sha256 e5d77226…) before
assembly. Crossing record: the gzipped arms crossed
in 12 sha-gated parts of 373 B (last part 174 B);
all 12 verified on-device first try, no part
rejected. The assembled gzip, the decompressed
arms and the assembled hef162 sha256 all matched
the VM exactly on-device, and the script compiled
on-device. The ONE bounded host-side child was
launched directly in a detached tmux session on
Mimir with the contract corpus argv — the six
hailo-ollama blobs in glob order, then MiniLM —
and finished with DONE162, exit 0, err empty.
Output hef162.out: 45,601 lines / 8,739,201 B, sha256
`8bb38bde4eac071f1e71db21d314f17abbab623e664e067b50e8cab5d02b1739`.
Prefix check: of its first 45,366 lines against
hef161.out, exactly ONE line differs (line 41,611 —
the frozenset element-order variance already
recorded under AES-NUM-150/153–161; same content
and length), all other 45,365 lines byte-identical
(diff verified on-device).
Section162: 235 lines / 54,427 B, sha256
`2e6af2b3968e734e74c3bad96e45818be55504963ff1035d04005437d8ead619`,
fetched by a device file read, verified on the VM
to exactly the on-device section sha, and read in
full. Every control in the controls echo reproduces
its expectation exactly: residue-0 sets 37 / 38 /
shared 25 / A-only 12 / B-only 13; byte2 census
85 listings / 96 distinct individual pairs / 11
hubs / 7 pairs at exactly 3 listings; 8 gap
records; gap 8 = run 102, step 49; context act
counts A 749 / B 751; shared distinct acts 689,
all 689 single-positioned; gap 8 B skipped offset
ranks [747, 748, 749, 750]; cell populations
27 / 27 / both 0; seam B 280 = act (791154688,
18448, 2), A pos 671, shift −391, run 93.

Raw output kept on the Pi at ~/aesir-build/
(hef162.out, hef162.py, arms162.py, section162.txt);
local lineage in ~/workspace/.verify-tmp/aesir162.

## (i) Gap 8's B-block offset region in full

Context B holds 751 acts with 751 distinct offsets;
its offset order runs from 262,144 to the largest
offset 1,196,445,696 — which is the last gap-8
skipped act itself (B 738, ending at 1,196,445,720,
the largest act end in the context).

- **The region (offset ranks 738–750, 0-based) is
  entirely B-only.** All thirteen acts at ranks
  738–750 are NOT shared single-positioned acts:
  no A position, no shift, no secondary run
  (derived count from the printed table: 13/13).
  Their B positions are scattered across the whole
  context — 19, 20, 22, 23, 25, 26 (ranks 738–743),
  then 229, 272, 674 (ranks 744–746), then the
  skipped block itself at 735–738 (ranks 747–750).
  The top of B's offset order is assembled from
  acts that sit everywhere in B's position order.
- **The region's internal spacing** (past each
  predecessor's end, ranks 738–750): 72, 0, 152, 0,
  488, 0, 432, 496, 496, 496, then inside the block
  488 throughout — the same 488/496/512 family of
  spacings seen across the ladder populations, on
  acts of wildly varying sizes (264–32,784 B) and
  all three channels.
- **The offset predecessor at B 674 in full.** The
  act (1196410880, 32784, 2) holds offset rank 746,
  ends at 1,196,443,664, and the first skipped act
  sits 496 past its end. It is itself **B-only**:
  not a shared single-positioned act, so it has
  **no A position, no shift, no secondary run and
  no A extent** — the predecessor's "run" the
  contract asked for does not exist under the
  shared-act run definitions; its offset role is
  carried by an act context A does not share at
  all. By position its neighbourhood (B 670–678)
  is unrelated to that role: run 92's +1 tail at
  670, a second B-only act (791121408, 32784, 2)
  at 671, run 30's +315 displaced act (A 357) at
  672, run 94's +1 act (A 672) at 673, the
  predecessor itself at 674, run 101's −7 act
  (A 682) at 675, run 95's +2 act (A 674) at 676,
  run 45's +275 act (A 402) at 677 and run 86's
  +26 act (A 652) at 678.
- **What follows the block in offset order:
  nothing.** The last skipped act is rank 750 of
  750 — the region's end is the block's own end.
  By position the block is followed by the gap's
  right bound at B 739 (768609280, 24, 0; run 102,
  shift +2) and run 102's continuation at
  B 740–745, exactly as AES-NUM-161 recorded.

## (ii) The 6864/6932 split against the untested fields

Population as before: 54 pairs, 27 in cell
(20, 32720, 6864), 27 in (20, 32720, 6932), none
in both. Twenty fields were function-tested over
the full 224 pairs (membership as a function of
the field) and membership-tabled over the 54.

- **Every low-dimensional field FAILS.** A byte1
  (146 distinct values over 224; 23 violating
  values; population values 240 and 69 in both
  cells), B byte1 (157; 23 violating; 220 in
  both), A byte2 (148; 27 violating; 124 in both),
  B byte2 (144; 25 violating; 168 and 251 in
  both), A byte3 (61; 6 violating; 206, 207, 209
  in both), B byte3 (70; 7 violating; 210 in
  both), and the byte3 difference B3−A3 (24
  distinct; 16 violating; 11 of its 17 population
  values in both cells). None is a function, none
  separates the 54.
- **Every field that "separates" is near-pair-
  identity, and its verdict is the trivial one.**
  Full B value, full A value, the full differences
  (big- and little-endian), the bytewise
  difference, XOR (bytes and int), the
  (byte1, byte2) pairs (A, B, and combined) and
  the (byte3, byte1+byte2) keys (A, B, and A+B)
  all score FUNCTION with 0 violating values and
  separate the 54 with 54 distinct population
  values — but they carry 217–224 distinct values
  over the 224 pairs, i.e. they (near-)identify
  the pair itself. A field that names the pair
  determines its cell by definition; these
  verdicts earn nothing toward a determinant.
  Recorded plainly so no later slice mistakes
  them for a law: **the split's determinant
  remains NOT PROVEN** — no field of genuinely
  lower dimension than the pair, tested in
  4.161 or here, is a function of the split.

## (iii) The seam's remaining displaced blocks in full

- **Run 93** is the singleton (791154688, 18448, 2):
  A 671, B 280, shift −391, length 1.
- **Run 19** is a +240 pair, A 278–279, sitting
  **contiguous at B 518–519** in A order: acts
  (782847488, 2064, 2) and (782849552, 14352, 2).
- **Run 20** is sixteen acts at shift +5,
  A 280–295, sitting **contiguous at B 285–300**
  in A order — sizes 2064/14352, 32784 ×2, 18448,
  2064/14352, 32784 ×2, 18448, then 1552/14864
  alternating pairs, the last two acts switching
  to channel 0. It is by far the longest of the
  three displaced blocks.
- **Runs 19 and 20 are A-adjacent** (A 278–279
  immediately followed by A 280–295) **yet land
  far apart in B** (518–519 vs 285–300): A
  adjacency does not imply B adjacency at the
  seam.
- **The B 280 singleton's A neighbourhood
  (A 668–674):** run 92's +1 acts at A 668–669
  (B 669–670); A 670 (791121408, 32784, 1) is
  A-only (no B occurrence); the singleton itself
  at A 671; run 94's +1 act at A 672 (B 673);
  A 673 (791206912, 32784, 1) is A-only; run 95's
  +2 act at A 674 (B 676). At home the singleton
  is flanked by in-place +1/+2 runs and two
  A-only acts — its −391 displacement is not
  shared by any A neighbour.
- **B windows in full:** B 276–295 (20/20 shared):
  run 18's +2 tail at 276–279, the run-93
  singleton at 280, the 71/73 block at 281–284,
  run 20 from 285. B 514–530 (17/17 shared):
  run 69's +2 tail at 514–517, run 19 at 518–519,
  run 70 at 520–522, the run-64 singleton at 523,
  run 74's head from 524. The seam's B geography
  stays block-structured: every displaced run
  lands as one contiguous block, and the blocks'
  B order differs from their A order. Any
  mechanism is NOT PROVEN.

## Next

Slice 4.163 — the top offset region's thirteen
B-only acts against context A in full (where
their offsets sit in A's own order and what A
holds there); the 6864/6932 split against the
pairs' record-level fields (per-record cidx /
idx / n / centre / poscat / in37 sequences as a
membership function test over the 54); run 20's
full context (its A neighbourhood A 276–300 and
what follows its B block at B 301–310), plus
runs 92/94/95 in full around the B 280
singleton's A home. Host/artifact analysis only.
