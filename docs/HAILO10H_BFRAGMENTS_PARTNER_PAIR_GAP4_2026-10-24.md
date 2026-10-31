# The excursion's B neighbourhood is fully shared and every fragment neighbour is an other-run act: B 610–614 is run 74's shift-0 tail, a single +93 act (A 522) sits at B 615 immediately before the +432 block, two other displaced pairs (+4 at B 620–621, +238 at B 622–623) fill the whole space between the +432 block and the +434 pair with no empty B slot, and the in-place pair at B 188–189 is itself flanked above by two displaced singletons (−190 at B 186, −192 at B 187); the root triangle's two neither partners are structural twins that differ in every identity field (7 same / 8 different of 15: same census 2, group, status, record count, A byte0 and class; different cell, records, A/B bytes, B byte0, diff, listing numbers and other sides, sharing exactly their mutual listing 24); and gap 4 — run 74's last unread gap — is its only multi-skipped gap (4 skipped acts, distances 5/5) and is channel-(0→1) like gaps 5 and 6, completing run 74's five gaps in full (AES-NUM-159)

Slice 4.159, worked under `docs/TASK_CONTRACT_4.159.md`
(contract published in the 4.158 closing commit @
2a76c5b9). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef159.py (hef158.py verbatim as base plus the new
arms159) sha256
`1e25470f74776fd2d87ac2f9e86f1927521f2cd7389654fa80481f0313b29daf`
(856,197 B); arms159 sha256
`76c1609115f9e03eef5ec402ef1f626585b1219e0494aa342bf2a33f198a37b2`
(11,112 B), its gzip sha256
`544f85428509a4bbfff1059131e9c2c098c945d6d60819c3eea62af4f6df15bf`
(3,311 B). The base hef158.py was verified on-device
== VM (sha256 b74c55d6…) before assembly. Crossing
record: the gzipped arms crossed in 9 sha-gated parts
of 373 B (last part 327 B), every part verified
on-device first try, no part rejected; the assembled
gzip at /tmp/arms159.py.gz verified on-device to
exactly the VM sha256, the decompressed arms and the
assembled hef159 sha256 matched the VM exactly
on-device, and the script compiled on-device. The ONE
bounded host-side child was launched directly in a
detached tmux session on Mimir with the contract
corpus argv — the six hailo-ollama blobs in glob
order, then MiniLM — and finished with DONE159 as
its last content line, exit marker 0, error channel
empty. Output hef159.out: 45,028 lines / 8,637,195 B,
sha256
`0c9a59c88c27b7eb1ee0279e48068aacea9297a1243de0153d7f538ec520aa18`.
Prefix check, stated honestly: of its first 44,823
lines against hef158.out, exactly ONE line differs
(line 41,611 — the frozenset element-order variance
already recorded under AES-NUM-150/153–158; same
content and length), all other 44,822 lines
byte-identical (diff verified on-device; this run the
second historically varying line, 42,872, came out
identical). Section159: 205 lines / 22,818 B, sha256
`af5630487daa75e2e527be6780d040d8c6d40c8384134f5fe1326aea0cfd43c5`,
fetched by device file reads and read back in full.
Every control in the controls echo reproduces its
expectation exactly: residue-0 sets 37 / 38 / shared
25 / A-only 12 / B-only 13; A chains 16, B chains 22;
byte2 census 85 listings / 96 distinct individual
pairs / 11 hubs / 7 pairs at exactly 3 listings; 8 gap
records, each with a full 32-feature row; context act
counts A 749 / B 751; shared distinct acts 689, all
689 single-positioned; excursion shifts at A 184–191
exactly [432, 432, 432, 432, 0, 0, 434, 434] and
B positions exactly [616, 617, 618, 619, 188, 189,
624, 625]; root 40f019ce census 3; both partners
census 2; run 74's gaps in step order [3, 4, 5, 6, 7]
at steps [24, 31, 33, 37, 48], gap 4 at run 74
step 31.

Raw output kept on the Pi at ~/aesir-build/
(hef159.out, hef159.py, arms159.py, section159.txt);
local lineage in ~/workspace/.verify-tmp/aesir159.

## (i) The excursion's B fragments in full

The excursion's three fragments are three distinct
secondary runs: the +432 acts are secondary run 2,
the in-place pair is secondary run 3, the +434 pair
is secondary run 4 (printed per act).

- **B 610–630 is entirely shared.** Every one of the
  21 B positions carries a shared single-positioned
  act, and the all-context-B listing is identical to
  the shared listing — there is no non-shared act and
  no empty slot anywhere in the window.
- **Before the +432 block.** B 610–614 are run 74's
  own tail: the shift-0 acts at A 610–614 (sizes
  32784 / 26128 / 32784 / 32784 / 18448, all channel
  0), the last acts of the 83-act run whose B extent
  ends at 614. Immediately before the block, at
  B 615, sits a single intruder: act (787733504,
  32784, 2) at A position 522, shift **+93**,
  secondary run 72 — displaced into the seam between
  run 74's tail and the +432 block.
- **Between the fragments (B 620–623).** The space
  between the +432 block's end (619) and the +434
  pair (624) is filled by two other displaced pairs,
  back to back: B 620–621 = A 616–617 at shift **+4**
  (secondary run 76; sizes 32784 / 26128, channel 0),
  and B 622–623 = A 384–385 at shift **+238**
  (secondary run 39; same size pair, channel 0).
- **After the +434 pair.** B 626–627 = A 618–619 at
  shift +8 (run 77), B 628–629 = A 394–395 at shift
  +234 (run 41), B 630 = A 623 at shift +7 (run 79),
  B 631 = A 624 at +7, B 632–636 at shift −5
  (run 84), B 637–639 at +241 (run 42), B 640 at
  +239 (run 44) — the B order past the fragments is
  a patchwork of other runs' pairs, not a resumed
  single order.
- **Neighbour classification: no fragment has a
  same-run neighbour.** All six printed neighbours
  of each fragment (three on each side) are class
  **other run**; none is non-shared. +432 block
  neighbour shifts [0, 0, +93, +4, +4, +238];
  in-place pair neighbour shifts [+2, −190, −192,
  −2, −2, −2]; +434 pair neighbour shifts [+4,
  +238, +238, +8, +8, +234].
- **The in-place pair's B context (B 182–195).**
  B 182–185 are the +2 run's tail in place (A
  180–183, run 1). Between that tail and the pair
  sit two displaced singletons: B 186 = A 376 at
  shift **−190** (run 36) and B 187 = A 379 at
  shift **−192** (run 37) — note their A positions
  are not adjacent (376, 379). The pair itself
  (B 188–189, A 188–189, shift 0, run 3) is followed
  in place by the −2 run's head (B 190–195 =
  A 192–197, run 5). So even the "in-place" fragment
  is not in an undisturbed neighbourhood: its upper
  seam carries two foreign singletons. Any mechanism
  is NOT PROVEN.

## (ii) The root triangle's two neither partners in full as a pair

- **Partner A — 4092dbce:** census listing count 2,
  group (20, 32720), cell (20, 32720, **6864**),
  status DIFF, exactly 1 record [((20, 32720, 6864),
  41, 13, 27, 127, 'interior', False)]; A bytes
  (64, 146, 219, 206) → B c07abac4 (192, 122, 186,
  196), diff **+128**. Its 2 listings: 23 (sub-key
  (byte0, byte2, byte3), to the root 40f019ce) and
  24 (same sub-key, to partner B 40fcb4ce).
- **Partner B — 40fcb4ce:** census listing count 2,
  group (20, 32720), cell (20, 32720, **6932**),
  status DIFF, exactly 1 record [((20, 32720, 6932),
  59, 19, 27, 127, 'interior', False)]; A bytes
  (64, 252, 180, 206) → B 0037aade (0, 55, 170, 222),
  diff **−64**. Its 2 listings: 24 (to partner A)
  and 26 (same sub-key, to the root).
- **Field-by-field: 15 fields, 7 same / 8 different.**
  Same: census listing count (2), group (20, 32720),
  status DIFF, record count (1), A byte0 (64), class
  (neither-partner), recomputed listing count (2).
  Different: cell (6864 vs 6932), records, A bytes,
  B bytes, B byte0 (192 vs 0), diff (+128 vs −64),
  listing numbers ((23, 24) vs (24, 26)), other
  sides (('40f019ce', '40fcb4ce') vs ('4092dbce',
  '40f019ce')). The partners share exactly one
  listing — 24, their mutual edge — and each carries
  one root listing (23 for A, 26 for B).
- **Cell cross-reference (derived from the printed
  records and AES-NUM-158's):** partner A's cell
  third component 6864 is the neither 40f079cf's
  cell; partner B's 6932 is the root 40f019ce's own
  cell. Each partner therefore sits in the cell of
  one of the chain's other vertices — A with the
  neither, B with the root. Whether that is a general
  census law is NOT PROVEN (one pair observed);
  slice 4.160 tests it across the census.

## (iii) Gap 4 in full — run 74 completed

Gap 4 in full: run 74, step 31, run shift +0, run
length 83, run extents A 524..614 / B 524..614.
Bounding acts LEFT (788559392, 26128, 0) at A/B
position 556 and RIGHT (788704256, 1552, 2) at 561,
both identical in the two contexts; distances
A 5 / B 5; **4 skipped acts per side** — the same
four acts on both sides at offset difference 0:
(788585984, 32784), (788618768, 26128), (788644896,
32784), (788677680, 26128), channels A all 0 and
B all 1; mapping ((0, 1),), mapping full ((0, 1),)
×4. Internal advances equal the preceding sizes
exactly on both sides (contiguous, slack 0); the
first skipped offset sits **464** past the left
bounding act's end on both sides.

- **Gap 4 is run 74's only multi-skipped gap.** Gaps
  3, 5, 6 and 7 each skip exactly 1 act per side
  (AES-NUM-152/157/158 records); gap 4 skips 4, at
  distance 5 where the others sit at distance 2.
- **Channel classification.** Gap 4 is a
  channel-(0→1) gap — the same mapping as gaps 5
  and 6, against gap 3's (2→0) and gap 7's (1→2).
  Run 74's five mappings in step order are therefore
  [(2→0), (0→1), (0→1), (0→1), (1→2)] at steps
  [24, 31, 33, 37, 48]: the (0→1) mapping holds the
  run's middle three gaps, bracketed by one (2→0)
  before and one (1→2) after. That is a measured
  classification, not a mechanism — mechanisms
  NOT PROVEN.
- **Run 74 is now read in full, all five gaps:**
  gap 7 (AES-NUM-152), gaps 5 and 6 (AES-NUM-157),
  gap 3 (AES-NUM-158), gap 4 (this slice).

## Next

Slice 4.160 — the B 615 intruder in full (the +93
act at A 522 and secondary run 72's place at the
seam); the partner-cell correspondence tested
census-wide (does every neither partner sit in a
cell of a vertex it touches?); and the first-skipped
past-left-end values of all 8 gaps as one table
(gap 4's 464 in the population). Host/artifact
analysis only — no physical child.
