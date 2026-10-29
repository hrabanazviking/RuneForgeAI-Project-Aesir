# The full shared-act population is NOT two bands: its 689 shifts take 69 distinct values in 103 secondary runs (the opening is clean — 9 acts at shift 0 over A positions 2–24, then 158 acts at +2 over 26–183 — but from A position 184 the shift fragments, with excursions to +432/+434, and only three later long runs: 53 acts at +3, the 83-act shift-0 run that holds gaps 5 and 6, and a final 58 acts at +2); no residue-0 rung sits between A positions 25 and 674, so the rungs' own band boundary remains unmeasured; the −7 singleton is utterly alone (the only −7 act in the population, flanked by five huge negative shifts at 676–680 and by +2 from 683 on); the leak's other side is a leaf (406820cf has exactly one listing, touches no hub and no three, and its chain ends two steps away at three 1); and gaps 5 × 6 differ ONLY in identity and position — all 13 differing features are which acts, where, and what was skipped, never how the gap is built (AES-NUM-157)

Slice 4.157, worked under `docs/TASK_CONTRACT_4.157.md`
(contract published in the 4.156 closing commit @
16044dce). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef157.py (hef156.py verbatim as base plus the new
arms157) sha256
`9f2b354c77375ac5476a562cc7b4f20996202c4973ef6e7129b1da0b7b434e86`
(831,450 B); arms157 sha256
`9834df4b340e876186dc879ca618b35a4d0a4075cc138795e36bbc46cd4abc83`
(11,349 B), its gzip sha256
`6637a3a9d62dbd89a1dbc1326ce5b9e4b51fa0493ed5344b98bcf9c8c0f478cf`.
The base hef156.py was verified on-device == VM
(sha256 a885b7cf…) before assembly. Crossing record:
the gzipped arms crossed in 10 sha-gated parts of
373 B (last part 247 B), all 10 verified on-device
first try, no part rejected; the assembled gzip,
arms and hef157 sha256 all matched the VM exactly
on-device, and the script compiled on-device. The
ONE bounded host-side child was launched directly
in a detached tmux session on Mimir with the
contract corpus argv — the six hailo-ollama blobs
in glob order, then MiniLM — and finished with
DONE157 as its last line, exit marker 0, error
channel empty. Output hef157.out: 44,590 lines /
8,582,491 B, sha256
`0324f1e811a1c318e8727b781adfb633da4bc4461252268f1f7b2885efcf7c2f`.
Prefix check, stated honestly: of its first 44,186
lines against hef156.out, exactly TWO lines differ
(lines 41,611 and 42,872 — the frozenset
element-order variance already recorded under
AES-NUM-150/153/154/155/156; same content and
length in both cases), all other 44,184 lines
byte-identical (diff verified on-device).
Section157: 404 lines / 57,867 B, sha256
`97ae3c70a4ec21cb32f64c22f9b7269d5177f38458269822e051b90c2af09d50`,
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
single-positioned; gap 5 × gap 6 control 19/32.

Raw output kept on the Pi at ~/aesir-build/
(hef157.out, hef157.py, arms157.py, section157.txt);
local lineage in ~/workspace/.verify-tmp/aesir157.

## (i) The position-shift bands in full

Contexts A (art 5ab3537d cidx 86, 749 acts) and B
(cidx 210, 751 acts). The full shared-act
population is **689 distinct acts, every one
single-positioned in both contexts** (A positions
2–744, B positions 2–746), so each act's shift is
a single number.

- **The population is not two bands.** Its shifts
  take **69 distinct values** — 126 acts at 0, 466
  positive, 97 negative; the modal shift is +2
  (283 acts), then 0 (126) and +3 (55). Read in
  A-order the acts form **103 secondary runs**
  (equal shift, consecutive in the shared order),
  with **102 shift transitions, each printed
  exactly** in the raw section. Run lengths:
  {1: 37, 2: 36, 3: 3, 4: 7, 5: 2, 6: 3, 7: 1,
  8: 3, 9: 2, 12: 1, 16: 1, 20: 1, 29: 1, 37: 1,
  53: 1, 58: 1, 83: 1, 158: 1} — most runs are
  singletons or pairs; the structure lives in a
  handful of long runs.
- **The opening IS clean, and its boundary is
  exact.** Run 0: 9 acts at shift **0**, A
  positions 2–24. Run 1: **158 acts at shift +2**,
  A positions 26–183 — the longest run in the
  population. The first transition falls between
  A positions **24 and 26** (no shared act sits
  at A position 25; A-position gap 2, shift change
  +2). In 50-wide bands: A 0–49 holds only shifts
  {0: 9, 2: 24}, and A 50–149 is **pure +2**
  (100 of 100 acts).
- **From A position 184 the shift fragments.**
  Transition 1 (A 183 → 184) jumps +2 → **+432**
  (4 acts, A 184–187), back to 0 for 2 acts, to
  **+434** for 2 acts (A 190–191), then −2 for 20
  acts, and the A 184–523 stretch is a patchwork
  of short runs with shifts from −5 to +434
  (the 200–249 band alone holds 10 distinct
  shifts; 400–449 holds 18). Three later long
  runs stand out: **53 acts at +3** (A 438–497),
  **83 acts at 0** (A 524–614 — the run holding
  gaps 5 and 6, §iii), and the **final 58 acts
  at +2** (A 683–744). Two more bands are pure:
  A 550–599 is all shift 0 (43 of 43, inside the
  83-act run and its continuation) and A 700–749
  is all +2 (41 of 41, inside the final run).
- **The residue-0 rungs' own boundary is STILL
  unmeasured — measured as absent.** The 25
  shared rungs' shifts reproduce AES-NUM-156
  exactly ({0: 9, +2: 15, −7: 1}), and **zero
  shared rungs sit between A positions 25 and
  674 inclusive**: the rung A positions are
  [2, 3, 4, 7, 9, 12, 18, 21, 24, 682, 693, 695,
  728–744]. The full population's clean 24 → 26
  transition is a fact about shared acts in
  general; it does NOT pin where the rungs'
  shift changes, because between the head rungs
  and the tail rungs the general population
  passes through dozens of other shift values.
  Any rung-specific band law remains NOT PROVEN.
- **The −7 neighbourhood.** Fourteen shared acts
  sit at A positions 675–690 (none at 675 or
  681). The five acts at 676–680 are each a
  singleton run with a **huge negative shift**
  (−283, −300, −455, −278, −452; their B
  positions scatter over 223–401). At A 682 sits
  the −7 act itself — the act (3446784, 24, 2),
  the residue-0 singleton rung — **the only act
  with shift −7 in all 689** (transitions +445
  in from −452, +9 out). From A 683 the final
  +2 run begins and never breaks (58 acts to
  A 744). The wider 660–700 window counts:
  {−455: 1, −452: 1, −391: 1, −300: 1, −283: 1,
  −278: 1, −277: 1, −255: 1, −7: 1, +1: 9, +2: 19}.
  The −7 is therefore not a band edge shared
  with its neighbours: it is an isolated value
  between a scrambled cluster and the clean
  final run. Its cause remains NOT PROVEN.

## (ii) Listing 21 and its 1-listing partner in full

Listing 21 of the byte2 census (85 listings) is
the union's single external listing
(AES-NUM-156): sub-key (byte0, byte2, byte3),
values (64, 32, 207) vs (64, 121, 207); A byte2
step **+89**; B byte0 step **−192**. Its two
sides sit in the **same cell** (20, 32720, 6864),
both status DIFF:

- **Side 1 is the target itself:** pair A
  406820cf → B c045adce (A bytes 64, 104, 32,
  207; B byte0 192, diff +128), group
  (20, 32720), **census listing count 1**,
  exactly 1 record: cell (20, 32720, 6864),
  cidx 5, idx 1, n 27, centre 127, interior,
  in37 False.
- **Side 2 is the neither partner** 40f079cf →
  B 003355c5 (B byte0 0, diff −64), same group
  and cell, census listing count 2, 1 record
  (cidx 38, idx 12, otherwise identical record
  fields).

- **406820cf is a leaf.** Its every listing in
  the census is listing 21 alone (1 of 1). It
  touches **no hub, no three** — its only
  partner is the neither partner 40f079cf, and
  there is nothing beyond that listing.
- **The population at its other end is
  exhausted in two steps.** 40f079cf's own two
  listings are listing 21 (to the leaf) and
  listing 8, under (byte0, byte1, byte2), to
  three **40f019ce** (three 1; census count 3).
  So the leak chain reads, in full: leaf
  406820cf —(listing 21)— neither 40f079cf
  —(listing 8)— three 1, and the census carries
  it no further on the leaf side. The
  threes-plus-neithers union's single leak
  therefore ends at a degree-1 pair whose sole
  record shares the union-side pair's exact
  cell; what singles the leaf out remains
  NOT PROVEN.

## (iii) Gaps 5 and 6 in full

Both gaps live in run 74 (the gaps' own run id),
inside **one and the same 83-act shift-0 run**
(A/B extents 524–614 both contexts — secondary
run 74 of §i, coincidentally the same index):
gap 5 is step 33, gap 6 is step 37 of that run.

- **Gap 5:** bounding acts LEFT (788705808,
  14864, 2) at A/B position 562, RIGHT
  (788754432, 1552, 1) at 564, both shifts 0,
  identical in both contexts. Distances A 2 /
  B 2; exactly **1 skipped act per side** —
  (788721152, 32784, 0) in A, (788721152, 32784,
  1) in B (offset difference 0, channel mapping
  ((0, 1),)). First skipped offset minus the
  left act's end: **480** on both sides.
- **Gap 6:** bounding acts LEFT (788803632,
  26128, 1) at A/B position 567, RIGHT
  (788863488, 26128, 1) at 569, both shifts 0.
  Distances A 2 / B 2; 1 skipped act per side —
  (788830208, 32784, 0) in A, (788830208, 32784,
  1) in B; mapping ((0, 1),). First skipped
  offset minus the left act's end: **448** on
  both sides.
- **The 32-feature table: 19 equal, 13
  differing — and every differing feature is
  identity or position, none is structure.**
  Equal: all 9 frame features (run 74, shift 0,
  length 83, extents 524–614 in both contexts,
  bounding shifts 0), plus both gap distances,
  both skipped counts, both skipped size lists
  (32784,), both skipped channel lists, and
  both channel mappings. Differing (all
  split-kind): step (33 vs 37, +4); the left
  and right acts themselves (6 rows counting
  the per-context duplicates); the A and B
  positions ((562, 564) vs (567, 569) — exactly
  **+5** on both sides); the skipped offsets
  (788721152 vs 788830208 — derived difference
  **+109,056**); and the two surrounding
  windows, which differ because the gaps sit 5
  positions apart in the same run (the windows
  overlap: gap 6's window opens with gap 5's
  closing acts). The maximum pair of the
  28-pair table is therefore two instances of
  the **same gap shape at two places in one
  run**, separated by 4 steps and 5 positions;
  no feature of how either gap is built
  differs. Mechanism NOT PROVEN.

Mechanisms remain NOT PROVEN throughout.
Campaign 4's exit condition is unchanged: it
turns on authoring, not on further description
of these populations.

## Next (slice 4.158)

(i) The +432/+434 excursion at A positions
184–191 in full: its 8 acts, their B positions,
and the runs flanking it (the +2 run's end, the
0/-2 returns). (ii) The leaf chain's root:
three 40f019ce in full — every listing, every
partner, and the chain leaf → neither → three
read as one graph. (iii) Gaps 3 × 5 and 3 × 6
(the 15/32 runners-up) in full, completing run
74's top pairs. Host/artifact analysis only —
no physical child.
