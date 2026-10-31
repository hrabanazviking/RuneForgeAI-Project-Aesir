# The +432/+434 excursion is ordinary acts at extraordinary B positions: its 8 acts (A 184–191) carry the same alternating 1552/14864 size pairs and the same 0/480 advance slack as the −2 flank after them, entry slack 384 is the window's only other slack value, and B-order is NOT preserved (the +432 acts land at B 616–619, the two shift-0 acts stay at B 188–189, the +434 acts land at B 624–625); the leaf chain's root three 40f019ce is the head of a 5-vertex graph whose listings 23/24/26 form a triangle with its two neither partners, it touches no hub and no other three, and it has NO direct edge to the leaf; and gaps 3 × 5 and 3 × 6 both score 15 equal / 17 differing of 32 — the 15 equals are exactly the 9 run-frame features plus distances, skipped counts and skipped sizes, and unlike gaps 5 × 6 they differ in skipped channels and channel mapping as well as identity and position; gap 3 sits in the SAME run 74 as gaps 5 and 6 (AES-NUM-158)

Slice 4.158, worked under `docs/TASK_CONTRACT_4.158.md`
(contract published in the 4.157 closing commit @
df1eef22). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef158.py (hef157.py verbatim as base plus the new
arms158) sha256
`b74c55d624829c2849efbb340bcb060d507e865dcdf94c50f8bfb6acb7e9429b`
(845,085 B); arms158 sha256
`63af56a130fddb3bd4740df7da9159f203661ea1637fd212c67baf169faaf681`
(13,635 B), its gzip sha256
`f32cecc7a1d17798aa87e13e9e252ee095cd8c37f0434618619c8d6d22d15b55`.
The base hef157.py was verified on-device == VM
(sha256 9f2b354c…) before assembly. Crossing record:
the gzipped arms crossed in sha-gated parts of 373 B
(sub-parts of 186 B + 187 B were prepared for parts
ac–al after earlier slices' transit lessons); the
assembled gzip at /tmp/arms158.py.gz verified
on-device to exactly the VM sha256, the decompressed
arms and the assembled hef158 sha256 matched the VM
exactly on-device, and the script compiled on-device.
The ONE bounded host-side child was launched directly
in a detached tmux session on Mimir with the
contract corpus argv — the six hailo-ollama blobs
in glob order, then MiniLM — and finished with
DONE158 as its last line, exit marker 0, error
channel empty. Output hef158.out: 44,823 lines /
8,614,377 B, sha256
`316b8bf9a84486260057547df90f08a14f15429306784b94e36cf8636b923a1c`.
Prefix check, stated honestly: of its first 44,590
lines against hef157.out, exactly TWO lines differ
(lines 41,611 and 42,872 — the frozenset
element-order variance already recorded under
AES-NUM-150/153/154/155/156/157; same content and
length in both cases), all other 44,588 lines
byte-identical (diff verified on-device).
Section158: 233 lines / 31,886 B, sha256
`48e4e7324ccef77c74192ba48c7d7177aa3b1051c93ea2ca0224ea5620d43dea`,
fetched by a device file read and verified on the
VM to exactly the on-device section sha. Every
control in the controls echo reproduces its
expectation exactly: residue-0 sets 37 / 38 /
shared 25 / A-only 12 / B-only 13; A chains 16,
B chains 22; byte2 census 85 listings / 96 distinct
individual pairs / 11 hubs / 7 pairs at exactly 3
listings; 8 gap records, each with a full
32-feature row; context act counts A 749 / B 751;
shared distinct acts 689, all 689
single-positioned; excursion shifts at A 184–191
exactly [432, 432, 432, 432, 0, 0, 434, 434];
root three 40f019ce census count 3, three index 1;
gap 3 × gap 5 and gap 3 × gap 6 both 15/32.

Raw output kept on the Pi at ~/aesir-build/
(hef158.out, hef158.py, arms158.py, section158.txt);
local lineage in ~/workspace/.verify-tmp/aesir158.
Resume note: this slice was auto-started at
18:49 EDT by a continuity firing whose transfer
completed (the gzip verified on-device at 19:03)
but whose run never launched; the 19:21 firing
found no processes running, the assembled-script
step and the launch un-done, and resumed exactly
there — no part of the contract was re-run or
duplicated.

## (i) The +432/+434 excursion in full

The excursion is ordered-index range 167..174 of
the shared order, A positions 184–191, read in a
16-act window with 4 flanking acts on each side.

- **The acts in full.** Flank-before (the +2 run's
  tail, A 180–183): offsets 781533760 / 781535312 /
  781550176 / 781582960, sizes [1552, 14864, 32784,
  26128], all channel 2, B positions 182–185.
  Excursion (A 184–191): (781609472, 1552, 2) B 616;
  (781611024, 14864, 2) B 617; (781626368, 1552, 0)
  B 618; (781627920, 14864, 0) B 619;
  (781643264, 1552, 0) B 188; (781644816, 14864, 0)
  B 189; (781660160, 1552, 0) B 624;
  (781661712, 14864, 0) B 625. Flank-after (the −2
  run's head, A 192–195): sizes [1552, 14864, 1552,
  14864], channels [0, 0, 1, 1], B positions
  190–193.
- **Size/advance structure: the excursion is NOT
  structurally distinct.** Its sizes are the strict
  alternating pair (1552, 14864) ×4, its internal
  offset advances alternate 1552 / 15344, and its
  advances-minus-preceding-sizes alternate 0 / 480 —
  exactly the flank-after's pattern on all three
  measures. The flank-before differs (four distinct
  sizes, advances exactly equal to preceding sizes,
  slack 0 throughout). So the pair pattern with
  480 slack is shared by the excursion AND the
  ordinary −2 run that follows it; it is not an
  excursion signature.
- **Entry and exit slack.** The window's only
  other slack value is at the entry: the first
  excursion act's offset minus the last +2 flank
  act's offset+size is **384** (offset advance
  26512 over a 26128 act). At the exit, the first
  −2 flank act follows the last excursion act with
  the regular 480 slack. Entry 384 / internal 0,
  480 / exit 480 — printed, not inferred.
- **Channels.** Excursion channels [2, 2, 0, 0, 0,
  0, 0, 0]: the channel-2 → channel-0 switch happens
  inside the +432 sub-run, between A 185 and 186,
  with no shift change.
- **B placement is the whole anomaly.** B positions
  [616, 617, 618, 619, 188, 189, 624, 625]:
  **B-order is NOT preserved** (strictly increasing:
  False). The four +432 acts sit together at
  B 616–619, the two shift-0 acts stay in place at
  B 188–189, and the two +434 acts sit at B 624–625
  — the excursion is three B fragments, not one
  displaced block. Sub-runs: +432 at A [184–187],
  0 at A [188, 189], +434 at A [190, 191].
  Any mechanism is NOT PROVEN.

## (ii) The leaf chain's root three in full

Root pair **40f019ce**: census listing count 3
(three index 1 of the 7 threes), group (20, 32720),
cell (20, 32720, 6932), status DIFF, exactly 1
record [((20, 32720, 6932), 80, 26, 27, 127,
'last', False)]; A bytes (64, 240, 25, 206) →
B 80d906d0 (byte0 128), diff +64.

- **Its 3 listings.** Listing 8, sub-key (byte0,
  byte1, byte2), values (64, 240, 25) vs (64, 240,
  121): other side **40f079cf** (the chain's
  neither, census 2, cell (20, 32720, 6864), 1
  record). Listing 23, sub-key (byte0, byte2,
  byte3), values (64, 219, 206) vs (64, 25, 206):
  other side **4092dbce** (neither-partner, census
  2, cell (20, 32720, 6864), 1 record, diff +128).
  Listing 26, sub-key (byte0, byte2, byte3), values
  (64, 25, 206) vs (64, 180, 206): other side
  **40fcb4ce** (neither-partner, census 2, cell
  (20, 32720, 6932), 1 record, diff −64).
- **The chain as one graph.** The extended vertex
  set (leaf, neither, root, and the root's two
  other partners) has 5 vertices and exactly 5
  edges: listing 8 (40f019ce—40f079cf), listing 21
  (406820cf—40f079cf), listing 23
  (4092dbce—40f019ce), listing 24
  (4092dbce—40fcb4ce), listing 26
  (40f019ce—40fcb4ce). Degrees: {4092dbce: 2,
  40f019ce: 3, 40f079cf: 2, 40fcb4ce: 2,
  406820cf: 1}. Listings 23/24/26 therefore form a
  **triangle** root—4092dbce—40fcb4ce—root, and the
  leaf chain (21 then 8) hangs off the triangle at
  40f079cf. Chain edges specifically: leaf—neither
  [21]; neither—root [8]; **leaf—root direct: []**.
- **Root touches:** hubs False; other threes
  False; neither partners True; leaf False. The
  root's whole byte2-census world is the 5-vertex
  graph above — measured complete from the census,
  mechanism NOT PROVEN.

## (iii) Gaps 3 × 5 and 3 × 6 in full

Gap 3 in full: run 74, step 24, run shift +0, run
length 83, run extents A 524..614 / B 524..614.
Bounding acts LEFT (788330544, 26128, 1) at
A/B position 548 and RIGHT (788390400, 32784, 0)
at 550, both identical in the two contexts;
distances A 2 / B 2; exactly 1 skipped act per
side, the same act (788357120, 32784) at offset
difference 0, channel A 2 / B 0, mapping ((2, 0),);
its first-skipped offset sits **448** past the
left bounding act's end on both sides.

- **Same run: YES.** Gap 3's run record and gaps
  5/6's run record are the same run 74 (gaps in
  step order [3, 4, 5, 6, 7], steps [24, 31, 33,
  37, 48], shift +0, length 83, extents
  524..614 both contexts). Gap 3's bounding
  positions (548, 550) precede gap 5's (562, 564)
  and gap 6's (567, 569) inside the one run.
- **3 × 5: 15 equal / 17 differing.** **3 × 6:
  15 equal / 17 differing.** In both tables the
  15 equal features are exactly the same list:
  the 9 run-frame features (run, run shift, run
  length, run A/B first/last positions, left
  shift, right shift) plus A/B gap distances 2/2,
  skipped counts 1/1, and skipped sizes (32784,)
  on both sides.
- **The 17 differing features are the same list
  in both tables:** step (24 vs 33, difference 9;
  24 vs 37, difference 13), left/right acts (×2
  each as act and as per-context triples),
  positions — (548, 550) vs (562, 564), exactly
  +14 in both coordinates, and vs (567, 569),
  exactly +19 — skipped offsets (788357120 vs
  788721152, +364,032; vs 788830208, +473,088),
  skipped channels (A 2 vs 0; B 0 vs 1 — the same
  channel pair against both 5 and 6), channel
  mapping and mapping full (((2, 0),) vs
  ((0, 1),)), and both surrounding windows.
- **Contrast with 5 × 6 (AES-NUM-157).** Gaps 5
  and 6 matched on 19 features including skipped
  channels and both mappings; gap 3 matches 5
  and 6 on only 15, and the 4-feature shortfall
  is exactly the channel set: skipped channels A,
  skipped channels B, channel mapping, channel
  mapping full. Gap 3 is the run's channel-(2→0)
  gap; gaps 5 and 6 are both channel-(0→1) gaps.
  That is a measured classification, not a
  mechanism — mechanisms NOT PROVEN.

## Next

Slice 4.159 — the excursion's B fragments in
full (the B 616–625 neighbourhood: what sits
around and between the +432 block, the in-place
pair's B context, and the +434 pair); the root
triangle's two neither partners (4092dbce and
40fcb4ce) in full as a pair; gap 4 (step 31, the
one run-74 gap not yet read in full) in full,
completing run 74's five gaps. Host/artifact
analysis only — no physical child.
