# The shared residue-0 offsets form 16 chain-to-chain correspondences: 13 of A's 16 chains survive whole and identical in B, A's 6-chain is truncated at its head, and A's 12-chain alone splits across two B chains; the 7 pairs at exactly 3 listings touch NO hub (13 boundary listings: 8 both-three, 5 to neither partners, 0 to a hub) while the hub component is a simple graph (26 listings = 26 distinct hub pairs, every hub's degree equal to its own listing count); gap 8 equals gap 4 on exactly the same 4 of 32 features and nothing else — frame 0 of 9, and the match is unique in run 74 on all four values (AES-NUM-155)

Slice 4.155, worked under `docs/TASK_CONTRACT_4.155.md`
(contract published in the 4.154 closing commit @
54d791d8). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef155.py (hef154.py verbatim as base plus the new
arms155) sha256
`88e204ef46bc92509e010c1765942fc44aa6784342f945f303e7e3b7d4f972f5`
(802,344 B); arms155 sha256
`cbdf57ca911f3ad4bf695219e3e7e8f5d0a262aeee98e8124b73caf5939b34e3`
(13,815 B), its gzip sha256
`619a43e083b1b7cb04c93230a3b72de742e6de2d9a485368a7842cf5ac12571b`
(3,696 B). The base hef154.py was verified on-device ==
VM (sha256 fc5b2abb…) before assembly. Crossing
record: the gzipped arms crossed in 10 sha-gated
parts of 373 B (last part 339 B); the assembled gzip,
arms and hef155 sha256 all matched the VM exactly
on-device, and the script compiled on-device.

The ONE bounded host-side child was launched in a
detached tmux session on Mimir with the contract
corpus argv — the six hailo-ollama blobs in glob
order, then MiniLM — via the sha-gated runner
run155.sh (sha256
`fb0eb7bf939abd539bb60d1227f3d0d9b41a994780b7a1e15bc8e4574cc10ab4`,
verified on-device == VM), and finished with
DONE155 as its last line, exit marker 0, error
channel empty. Output hef155.out: 43,953 lines /
8,487,810 B, sha256
`77529a8d90f5c82d19aa26ac9b3c9367ef78d5d5812e5b7a03b79493c1300909`.
Prefix check, stated honestly: of its first 43,525
lines against hef154.out, exactly ONE line differs
(the frozenset element-order variance already
recorded under AES-NUM-150/153/154; same content
and length), all other 43,524 lines byte-identical
(diff verified on-device). Section155: 428
lines / 69,241 B, sha256
`198e50413fb0bebca3f0e3313dadb013fc6c72936aea23ca68100f2058c602c8`,
returned as the on-device gzip (sha256
`2e74da836ab822ef6089faa610fd341c3d88f0cd6ef3dbb64e48ee25e1dabfcd`)
through a time-boxed on-device HTTP server and the
tunnel proxy, the gzip sha matching on-device and
the decompressed section matching the on-device
section sha exactly. Every control in the controls
echo reproduces its expectation exactly: residue-0
sets 37 / 38 / shared 25 / A-only 12 / B-only 13;
A chains 16 {1: 12, 3: 1, 4: 1, 6: 1, 12: 1}, B
chains 22 {1: 15, 2: 2, 3: 1, 4: 4}; byte2 census
85 listings / 96 distinct individual pairs / 11
hubs / 7 pairs at exactly 3 listings; 8 gap
records, gap 8 in run 102, gap 4 in run 74.

Raw output kept on the Pi at ~/aesir-build/
(hef155.out, hef155.py, arms155.py, section155.txt);
local lineage in ~/workspace/.verify-tmp/aesir155.
This slice was resumed and closed by the 10-minute
continuity worker: the preceding firing had built
arms155, crossed it, and completed the run and the
section extraction on-device; the closing work
(fetch, analysis, this doc, ledger, TODO, progress,
contract 4.156) was completed in this firing from
the sha-verified section.

## (i) The shared offsets' chain correspondence in full

Contexts A (art 5ab3537d cidx 86) and B (cidx 210);
the 25 shared residue-0 offsets of AES-NUM-154 form
exactly **16 chain-to-chain correspondences**:

- 14 correspondences are one-to-one and complete on
  the shared rungs: the twelve singleton chains
  #0–#6 and #10–#14 map to the identically numbered
  B singletons, and A chain #7 (the 4-chain
  768,609,280..768,610,816) maps whole to B chain
  #7, identical in extent and length.
- A chain #9 (the 6-chain 778,835,968..778,838,528)
  corresponds to B chain #8 (778,836,992..778,838,528,
  len 4): the shared rungs are A rungs 3–6, i.e.
  B's chain is A's chain **truncated at its head**
  — A's first two rungs (778,835,968, 778,836,480)
  are A-only, inside a chain that otherwise
  corresponds.
- A chain #15 (the 12-chain 791,775,232..791,780,864)
  is the ONLY chain that splits: its rungs 1–4 are
  B chain #14 (the approach 4-chain
  791,775,232..791,776,768) and its rung 8
  (791,778,816) is B chain #15, a singleton; rungs
  5–7 and 9–12 are A-only.

Verdict census, every chain read against the other
context: **A chains — 13 SURVIVE WHOLE in B
(identical chain), 1 carries its shared part inside
one B chain (the truncated 6-chain), 1 SPLITS
across 2 B chains (the 12-chain), 1 has NO shared
rungs (A chain #8, the whole 3-chain
778,827,776..778,828,800). B chains — 13 survive
whole in A, 3 carry their shared part inside one
A chain, 6 have no shared rungs.** No A chain
merges with another in B, and no B chain merges
two A chains: the correspondence is a partial
bijection of chains, never a many-to-one map.

Where the non-shared rungs sit, in full: of A's 12
A-only offsets, 9 sit INSIDE chains that also carry
shared rungs (the 6-chain's head pair and 7 of the
12-chain's rungs) and only 3 sit in a wholly
non-shared chain (the 3-chain). Of B's 13 B-only
offsets, ZERO sit inside a chain carrying shared
rungs — all 13 are entire non-shared chains (B
chains #16–#21: the 2-chain just above A's maximum,
two singletons, a 3-chain, a 2-chain, and side B's
isolated skipped 4-chain 1,196,444,160..1,196,445,696).
The asymmetry is exact: **A's private rungs are
mostly interior losses inside corresponding
chains; B's private rungs are entirely additional
chains beyond the correspondence.**

Any law behind the split/truncation pattern is
NOT PROVEN; the measured content is the complete
correspondence table, printed in the raw section.

## (ii) The hub closure's boundary and internal structure

Listing-count distribution over the 96 distinct
individual pairs of the AES-NUM-153 byte2 census
(reproduced exactly): {1: 59, 2: 19, 3: 7, 4: 4,
5: 6, 6: 1}. The boundary population is the 7
pairs carrying exactly 3 listings.

- **The threes touch NO hub.** 13 of the 85
  listings involve at least one 3-pair: 8 have
  BOTH sides 3-pairs, 5 have one side a pair that
  is neither hub nor three, and **0 have a hub on
  either side**. Per three, partner classes over
  its 3 listings: three #1 {neither: 3}; #2 and #3
  {three: 2, neither: 1}; #4–#7 {three: 3}. The
  boundary is therefore not a hub fringe: below
  the closed hub component sits a second,
  hub-disjoint population in which the threes are
  mostly interlinked with each other.
- The threes do NOT share the hubs' signature:
  A byte0 splits {128: 4, 20: 2, 64: 1} (hubs are
  128 throughout); A byte2 all 7 distinct; groups
  {(20, 32720): 5, (19, 7712): 1, (14, 9992): 1};
  statuses {SAME: 4, DIFF: 3}; cells {(20, 32720,
  6864): 3, (20, 32720, 6932): 2, (19, 7712, 2384):
  1, (14, 9992, 4336): 1}; record counts {1: 6,
  27: 1} — the single 27-record three is the
  (14, 9992) ladder pair 178, the same pair that
  anchors the (1, 128) ladder chain of AES-NUM-151.
- **Hub internal structure: a simple graph.**
  The 26 hub-hub listings join **26 distinct hub
  pairs** — no pair of hubs is joined twice, and
  there are no self-listings. Every hub's distinct
  partner count EQUALS its own listing count:
  degrees {6: 1 hub, 5: 6 hubs, 4: 4 hubs},
  identical to the listing-count distribution of
  the 11, and the sum of incidences is 52 = 2 × 26
  exactly. So the hub component is an 11-vertex,
  26-edge simple graph in which a pair's census
  count IS its graph degree — the count and the
  degree are the same measurement read two ways,
  not two facts. Sub-key split over the 26
  listings: 25 under (byte0, byte2, byte3), 1 under
  (byte0, byte1, byte2), reproducing the AES-NUM-154
  derived split in-run.

What singles the hub component and the three
population apart is NOT PROVEN; the boundary
(0 hub contact), the interlinking of the threes,
and the hub graph's simplicity are measured over
the complete census.

## (iii) Gap 8 against run 74's gap 4 in full

The 32-feature side-by-side table (gap 8: run 102,
step 49; gap 4: run 74, step 31), printed in full
in the raw section:

- **Equal on exactly 4 of 32 — the same four**:
  A gap distance 5, B gap distance 5, skipped
  count A 4, skipped count B 4 (all SPLIT-KIND).
  Frame matches: **0 of 9** (run 102 vs 74, shifts
  +2 vs +0, run lengths 58 vs 83, extents A
  683..744 / B 685..746 vs 524..614 / 524..614).
- The four matched values are **unique to gap 4
  inside run 74**: the other run-74 gaps (3/5/6/7)
  carry distances 2/2 and skipped counts 1/1 on
  every one of the four features, and run 62's
  gaps carry 3/6 and 2/5 — so gap 8 matches gap 4
  alone, on all four, against every other gap in
  the record set (derived from the run's printed
  wider-context table).
- Everything around the match differs, and the
  differences are structural, not noise: gap 8's
  channel mapping is the identity ((0,0),(1,1),
  (2,2); full ((0,0),(1,1),(2,2),(0,0))) where
  gap 4's is the single cross-channel step
  ((0,1),) repeated; gap 8's four skipped acts are
  24-byte bursts at offsets 791,776,792..
  791,778,304 (A side) and side B's isolated
  4-chain 1,196,444,160..1,196,445,696, with
  skipped channels (0,1,2,0) on both sides, where
  gap 4's skipped acts are large forms (sizes
  32784/26128 alternating) at one shared offset
  set in both contexts, channels (0,0,0,0) in A
  and (1,1,1,1) in B; gap 8's bounding acts are
  24-byte bursts, gap 4's are 26,128 B (left) and
  1,552 B (right). The two gaps agree on **how
  far and how many** and on nothing about **what,
  where, or across which channels**.

Mechanisms remain NOT PROVEN throughout.
Campaign 4's exit condition is unchanged: it
turns on authoring, not on further description
of these populations.

## Next (slice 4.156)

(i) The surviving chains in context-position
space: do the 13 identical chains also sit at
identical context positions in A and B, and where
do the split 12-chain's two B fragments and the
truncated 6-chain sit positionally. (ii) The
three population as a graph in full: the 8
both-three listings as edges (components and
degrees over the 7 threes), and the 5
neither partners read in full (their own listing
counts, classes, and whether the threes plus
their neither partners close a second component).
(iii) The complete pairwise gap table: all 8
gaps against each other on the 32 features
(match counts for all 28 pairs), so gap 8 vs
gap 4's 4/32 sits in the full distribution.
Host/artifact analysis only — no physical child.
