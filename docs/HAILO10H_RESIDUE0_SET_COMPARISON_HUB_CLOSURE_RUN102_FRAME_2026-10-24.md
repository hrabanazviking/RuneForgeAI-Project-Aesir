# The two contexts' residue-0 offset sets share 25 of 50 offsets with positional order preserved exactly (0 inversions), the byte2 census's 11 hub pairs form a CLOSED population (all 26 hub listings are hub-to-hub, all in one cell, one group, A byte0 128 throughout), and run 102's single gap carries none of the run-62/run-74 frame values — the 9 frame features are constant within a run, not across runs (AES-NUM-154)

Slice 4.154, worked under `docs/TASK_CONTRACT_4.154.md`
(contract published in the 4.153 closing commit @
e010d2f7). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef154.py (hef153.py verbatim as base plus the new
arms154) sha256
`fc5b2abb28bad2493fe03c6ab183e5f83ab075a5e67d8790c3229f46d2c88311`
(788,529 B); arms154 sha256
`07910e81cbca78c5141ede72c8f9696d3d49bff0d313684a5e27d66385653759`
(16,950 B), its gzip sha256
`ceec9a9165fd3ee8f1769faf1201482c28fee21d73a21702dbe664de1058f1bc`
(4,977 B). The base hef153.py was verified on-device ==
VM (sha256 247c36de…) before assembly. Crossing
record: the gzipped arms crossed in 14 sha-gated
parts of 373 B (last part 128 B); every part's
sha256 verified on-device first try, no part
rejected. The assembled gzip, arms and hef154
sha256 all matched the VM exactly on-device, and
the script compiled on-device (py_compile OK).

The ONE bounded host-side child was launched in a
detached tmux session on Mimir with the contract
corpus argv — the six hailo-ollama blobs in glob
order, then MiniLM — via the sha-gated runner
run154.sh (sha256
`bb5d6565befd52d7131f1cb53efa85f4eda6a10ea7a69d368961ffd308a1d2f5`,
verified on-device == VM), and finished with
DONE154 as its last line, exit marker 0, error
channel empty. Output hef154.out: 43,525 lines /
8,418,569 B, sha256
`bc8197a3f8ea66a96fd0636124038e70c194afe1053cbb59b05ce188d360c1f1`.
Prefix check, stated honestly: of its first 43,113
lines against hef153.out, exactly ONE line differs
(line 41,611, the frozenset element-order variance
already recorded under AES-NUM-150/153; same content
and length), all other 43,112 lines byte-identical
(cmp/diff verified on-device). Section154: 412
lines / 81,047 B, sha256
`0f38a1c1c5c5527179e4f933f80a2143afa60124f7cac95656d20bc840c9cfb0`,
returned as the on-device gzip (sha256
`c9d3fd505bfb26fc7bcb1b06e02e332db93bdf228d25d0d529ef5c3c6a6fd7a7`)
through a time-boxed on-device HTTP server and the
tunnel proxy, decompressing on the VM to exactly
the on-device section sha. Every control in the
controls echo reproduces its expectation exactly,
including the AES-NUM-153 census controls (85
listings / 84 distinct pair-pairs / 96 individual
pairs) and the two 9-feature frame lists (run62's
frame == run74's frame, verified in-run).

Raw output kept on the Pi at ~/aesir-build/
(hef154.out, hef154.py, arms154.py, section154.txt);
local lineage in ~/workspace/.verify-tmp/aesir154.

## (i) The residue-0 offset sets in full against each other

Contexts A (art 5ab3537d cidx 86) and B (cidx 210),
the residue-0 (mod 512) 24-byte offsets of
AES-NUM-153:

- Sizes: A 37 occurrences / 37 distinct offsets;
  B 38 / 38. Shared 25; A-only 12; B-only 13;
  union 50. Ranges: A 262,656..791,780,864
  (span 791,518,208); B 262,656..1,196,445,696
  (span 1,196,183,040) — the sets share their
  minimum and diverge at the top, where B carries
  13 offsets above A's maximum region (below).
- Positional order is PRESERVED EXACTLY: the 25
  shared offsets ordered by first context position
  give the identical sequence in A and in B;
  0 inversions in 300 pairs. Ordinal (rank in the
  sorted distinct-offset set) differences
  B-minus-A: {0: 11, −5: 13, −8: 1} — 13 shared
  offsets sit exactly 5 ranks lower in B (the
  offsets A carries that B lacks below them), one
  (791,778,816) sits 8 lower. First-context-
  position differences B-minus-A: {+2: 15, 0: 9,
  −7: 1} — most shared offsets sit exactly at the
  +2 run shift in B.
- Shared offsets by the chain they sit in:
  A chain lengths {1: 12, 4: 4, 6: 4, 12: 5};
  B chain lengths {1: 13, 4: 12}. The same offset
  can sit in chains of different lengths across
  the contexts: e.g. the approach/bound offsets
  791,775,232..791,776,768 are rungs of A's
  12-chain but form B's whole approach 4-chain
  (791,775,232..791,776,768), and 791,778,816 is
  a rung of A's 12-chain but a singleton in B.
- The A-only 12 are chain segments, not scatter:
  the whole A 3-chain 778,827,776..778,828,800;
  the first two rungs of A's 6-chain
  (778,835,968, 778,836,480 — B's corresponding
  chain starts two rungs later, at 778,836,992);
  and 7 rungs of A's 12-chain (791,777,280,
  791,777,792, 791,778,304 — side A's skipped
  ladder rungs of gap 8 — plus 791,779,328,
  791,779,840, 791,780,352, 791,780,864, the
  post-bound rungs ending at A's maximum).
- The B-only 13 lie at or above 791,781,376:
  a 2-chain just above A's maximum (791,781,376,
  791,781,888), a singleton (800,053,760), a
  3-chain (873,198,592..873,199,616), a singleton
  (973,679,616), a 2-chain (1,196,182,016..
  1,196,182,528), and side B's isolated skipped
  4-chain of gap 8 (1,196,444,160..1,196,445,696).
  Every B-only offset's nearest A offset is below
  it; none has an A offset above. Chain
  structures diverge in count as well: A 16
  chains {1: 12, 3: 1, 4: 1, 6: 1, 12: 1} against
  B 22 chains {1: 15, 2: 2, 3: 1, 4: 4}, and the
  consecutive-offset step 512 occurs in 21 of A's
  36 steps against 16 of B's 37.

Any law behind the set difference is NOT PROVEN;
the measured content is the full sets, their
orders, and their chain memberships, all printed
in the raw section.

## (ii) The byte2 census's hub pairs as one population

Listing counts over the 96 distinct individual
pairs of the AES-NUM-153 byte2 census:
{1: 59, 2: 19, 3: 7, 4: 4, 5: 6, 6: 1} (170 slots
in 85 listings). The hub population — pairs
carrying >= 4 listings — is 11 pairs (counts:
one at 6, six at 5, four at 4; 52 of the 170
slots).

- THE HUBS ARE CLOSED: 26 listings involve at
  least one hub, and all 26 have BOTH sides hub.
  The distinct partners of hubs number exactly
  11 — the hubs themselves. No hub listing
  touches a non-hub pair, and (derived at closing
  from the printed per-hub listings) the 26
  listings split 25 under sub-key (byte0, byte2,
  byte3) and 1 under (byte0, byte1, byte2).
- The hubs share almost everything measurable:
  A byte0 = 128 in all 11; A byte3 in {186 (5),
  187 (6)}; A byte2 all 11 distinct; A byte1
  distinct except 68 twice. Group (20, 32720)
  in all 11; cell (20, 32720, 6796) in all 11;
  exactly 1 record each. B byte0 splits the
  population: 128 in 6 (status SAME, diff 0) and
  0 in 5 (status DIFF, diff −128) — the same
  6/5 split as the statuses.
- Against the 96 listed pairs: hubs are 11 of
  96 pairs holding 52 of 170 slots in 26 of 85
  listings, and those listings form a closed
  11-pair component of the census graph. What
  singles these 11 pairs out for closure is NOT
  PROVEN; the closure itself, and the shared
  values above, are measured over the complete
  census.

## (iii) Run 102's single gap against the run-62 / run-74 frame

Gap 8 (run 102, step 49) was printed in full and
its 32-feature row read against the 9-feature
frame shared by run 62's gaps and by run 74's
gaps (the two frame lists verified identical
in-run, as were the two 23-name splitting lists).

- On the 9 frame features, run 102 matches the
  run-62 shared value on 0 of 9 and the run-74
  shared value on 0 of 9 — and run 62 and run 74
  also match EACH OTHER on 0 of 9. The frame
  features (run, run shift, run length, run
  first/last positions in both contexts, left
  shift, right shift) are run-identifying
  quantities: constant across the gaps OF one
  run, different for every run. Gap 8's own
  values: run 102, shifts +2/+2, run length 58,
  extents A 683..744, B 685..746.
- The one-gap degeneracy is measured, not
  hidden: run 102 has exactly one gap in the
  record set, so constancy across its gaps is
  vacuous — a singleton shares all 32 features
  trivially and the within-run frame test cannot
  be run inside run 102. The closure recorded
  here is therefore the cross-run reading: gap 8
  carries the frame in KIND (its row states all
  9 frame features, with the shift features
  agreeing left == right == run shift, +2, as in
  the other runs' shared rows) and in none of
  the other runs' VALUES.
- On the remaining 23 (the splitting names of
  runs 62 and 74, verified the same 23): gap 8
  equals at least one run-62 gap value on 0 of
  23, and at least one run-74 gap value on 4 of
  23 — A gap distance 5, B gap distance 5,
  skipped count A 4, skipped count B 4, all four
  matching run 74's gap 4 exactly and no other
  gap. Three-run closure table: run 62 — gaps
  [1, 2], shared 9/32; run 74 — gaps [3, 4, 5, 6,
  7], shared 9/32; run 102 — gap [8], distances
  5/5, mapping ((0, 0), (1, 1), (2, 2)).

Mechanisms remain NOT PROVEN throughout.
Campaign 4's exit condition is unchanged: it
turns on authoring, not on further description
of these populations.

## Next (slice 4.155)

(i) The shared offsets' chain correspondence in
full: each shared offset's A chain mapped to its
B chain (which A chains split, merge, or survive
whole in B), over the 25 shared offsets and both
chain systems. (ii) The hub closure's boundary:
the 7 pairs carrying exactly 3 listings — do
they attach to the hub component, to each other,
or to neither — and the hub component's internal
structure (per-hub partners and degrees within
the 11). (iii) Gap 8 against run 74's gap 4 in
full (the one split-kind match: distances 5/5,
skipped 4/4) — a 32-feature side-by-side table.
Host/artifact analysis only — no physical child.
