# Identical chains are NOT position-identical: of the 13 surviving chains, 5 sit at exactly the same context positions in both contexts, 8 are carried at a single uniform shift (+2 for seven, −7 for one), and none is mixed; the split 12-chain's two B fragments and the truncated 6-chain's shared rungs follow their regions exactly; the three population's graph has three components over the threes ([1], [2,3] joined by a DOUBLE edge, and a complete K4 on 4–7), its 5 neither listings run to only 4 distinct partners, and the threes-plus-neithers union (11 vertices, the hub component's size) is disjoint from the hubs but NOT quite closed — exactly one of its 15 touching listings leaves it; the complete 28-pair gap table is bimodal by run (same-run pairs share the whole 9-feature frame and score 9–19, cross-run pairs share no frame and score 0–4), with gap 8 × gap 4 the unique cross-run pair above 1 (AES-NUM-156)

Slice 4.156, worked under `docs/TASK_CONTRACT_4.156.md`
(contract published in the 4.155 closing commit @
815cf0af). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef156.py (hef155.py verbatim as base plus the new
arms156) sha256
`a885b7cf3bd2cde3243ddbf49b4d0389837a6cece07e7c4bc05b9a51232d888e`
(820,101 B); arms156 sha256
`5706bc6d14372dbc09a0fc7335f3a40a94ac98bf7ccb4f66a02f1e01ff548f9e`
(17,757 B), its gzip sha256
`144af34856f05a783cf1c2ec7e4cbecd7737a663420e42ae49de097b595125d2`.
The base hef155.py was verified on-device == VM
(sha256 88e204ef…) before assembly. Crossing record:
the gzipped arms crossed in 14 sha-gated parts of
373 B (last part 19 B); one part (p_al) was rejected
in its whole form (base64 padding error in transit)
and healed by re-splitting it at new boundaries
(186 B + 186 B + 1 B, each sha-gated and verified);
the assembled gzip, arms and hef156 sha256 all
matched the VM exactly on-device, and the script
compiled on-device. The sha-gated runner file's
transfer was blocked in this run, so the ONE bounded
host-side child was launched directly in a detached
tmux session on Mimir with the contract corpus argv
— the six hailo-ollama blobs in glob order, then
MiniLM — and finished with DONE156 as its last line,
exit marker 0, error channel empty. Output
hef156.out: 44,186 lines / 8,524,624 B, sha256
`d7a40c8b09626395c35eaa399f773bb36f63d0860af650172655ca76bebb73fd`.
Prefix check, stated honestly: of its first 43,953
lines against hef155.out, exactly ONE line differs
(the frozenset element-order variance already
recorded under AES-NUM-150/153/154/155; same content
and length), all other 43,952 lines byte-identical
(diff verified on-device). Section156: 233 lines /
36,814 B, sha256
`1e08bc4cab4a20c46dc72a38b9e6f6043ef879fa4f7f724d935125602d47f3d0`,
fetched by a device file read and verified on the VM
to exactly the on-device section sha. Every control
in the controls echo reproduces its expectation
exactly: residue-0 sets 37 / 38 / shared 25 / A-only
12 / B-only 13; A chains 16 {1: 12, 3: 1, 4: 1, 6: 1,
12: 1}, B chains 22 {1: 15, 2: 2, 3: 1, 4: 4}; byte2
census 85 listings / 96 distinct individual pairs /
11 hubs / 7 pairs at exactly 3 listings; 8 gap
records, each with a full 32-feature row; context
act counts A 749 / B 751.

Raw output kept on the Pi at ~/aesir-build/
(hef156.out, hef156.py, arms156.py, section156.txt);
local lineage in ~/workspace/.verify-tmp/aesir156.

## (i) The surviving chains in context-position space

Contexts A (art 5ab3537d cidx 86, 749 acts) and B
(cidx 210, 751 acts). Every one of the 25 shared
residue-0 offsets occurs **exactly once** in each
context, so a rung's position is a single number,
not a distribution. First-position shifts over the
25 shared rungs: **{+2: 15, 0: 9, −7: 1}** — the same
three values the AES-NUM-154 rank analysis saw, now
read as positions.

- **The 13 surviving (offset-identical) chains:
  5 position-identical, 8 uniformly shifted, 0
  mixed.** The five position-identical chains are
  the head singletons A #10–#14 (offsets
  778,872,320..778,996,736), sitting at positions
  9, 12, 18, 21, 24 in BOTH contexts. Seven chains
  shift by exactly +2 (the tail singletons #0, #1,
  #2, #4, #5, #6 at positions 693–743 and the
  4-chain #7 at positions 737–740, whose span is
  preserved exactly, 3 in both contexts). One
  chain shifts by −7: singleton #3 (offset
  3,446,784), at position 682 in A and 675 in B —
  the sole negative shift in the population.
  **Within every surviving chain the shift is a
  single constant** (multi-rung chain #7: +2 on
  all four rungs); no chain is internally
  stretched or compressed.
- **The truncated 6-chain follows its region.**
  A chain #9's four shared rungs are
  position-identical (positions 2, 3, 4, 7 in both
  contexts, shift 0); its two A-only head rungs
  sit at A positions 0 and 1, before everything
  shared. B chain #8's position range 2..7 lies
  strictly inside A #9's 0..7.
- **The split 12-chain follows the other region.**
  Both B fragments shift uniformly by +2: B chain
  #14 (A rungs 1–4) at positions 731–734 against
  A's 729–732 (span 3 preserved), and B chain #15
  (A rung 8, offset 791,778,816) at position 746
  against A's 744. A's seven A-only rungs sit at
  A positions 734, 735, 736, 745, 746, 747, 748 —
  measured, not inferred: A position 746 is held
  by A-only rung 10 while B position 746 is held
  by the shared rung 8; position equality across
  contexts does not imply offset equality.
- Position is therefore **regional, in two bands**
  (derived from the printed tables): the head band
  (positions 0–24, the chains around the contexts'
  starts) carries shift 0 throughout, and the tail
  band (positions 675–748) carries +2 throughout
  except the single −7 singleton. Where the band
  boundary lies between positions 24 and 675 is
  NOT measured by this slice (no shared rung sits
  between them); any law behind the shifts, and
  the −7 exception's cause, are NOT PROVEN.
- Non-corresponding chains, for the record: the
  A-only 3-chain's rungs sit at A positions
  [6, 16, 5] in offset order — not monotonic; B's
  additional chains sit at B positions 0–27 (the
  3-chain #18, rung positions [1, 0, 27]) and at
  the very end (chains #16, #17, #19, #20 at
  747–750, and side B's isolated skipped 4-chain
  #21 at 735–738, consecutive).

## (ii) The three population as a graph in full

The 7 pairs at exactly 3 listings (indices as in
AES-NUM-155), read as a graph over the 8 both-three
listings:

- **Three components, not one.** Over distinct
  both-three edges the threes split as **[1],
  [2, 3], [4, 5, 6, 7]** (sizes 1, 2, 4). Three 1
  has NO both-three listing at all (degree 0
  within the threes; all 3 of its listings run to
  neither partners). Threes 2 and 3 are joined to
  each other only. Threes 4, 5, 6, 7 form a
  **complete graph K4**: all 6 unordered pairs
  occur, each exactly once, so each of the four
  has distinct-partner degree 3 = its within-
  threes listing count 3.
- **The graph is NOT simple** — the one contrast
  with the hub component (AES-NUM-155: 26 listings
  = 26 distinct pairs). Here 8 listings join only
  **7 distinct pairs**: the (2, 3) pair is joined
  TWICE, once under each of two sub-keys
  ((byte0, byte1, byte2) and (byte0, byte2,
  byte3)), both times with byte2 step +1 and B
  byte0 step 0. No self-listings occur.
- **The 5 neither listings run to only 4 distinct
  partners** — correcting the natural reading of
  AES-NUM-155's "5 to neither partners": that was
  a listing count. The four partners are all
  2-listing pairs with exactly 1 record each:
  three partners in group (20, 32720) serving
  three 1 (cells 6864, 6864, 6932; all DIFF), and
  one partner in group (19, 7712), cell
  (19, 7712, 7568), SAME — the pair 1401b000 —
  which serves BOTH three 2 and three 3 (its 2
  listings are exactly those two).
- **Every listing of the neither partners:** none
  touches a hub (0 of 8 partner listings). Partner
  1401b000's listings go only to threes (2/2).
  Two of three 1's partners list only to three 1
  and to each other (one neither–neither listing
  joins partners 4092dbce and 40fcb4ce). The
  remaining partner (40f079cf) has one listing to
  three 1 and one listing **outside** the union,
  to the 1-listing pair 406820cf.
- **Second-component test: near-closed, not
  closed.** The union of the 7 threes and their 4
  neither partners is **11 vertices — exactly the
  hub component's size** — and is disjoint from
  the hubs. Of the 15 listings touching the union,
  **14 are internal** (8 both-three + 5
  three–neither + 1 neither–neither) and **exactly
  1 leaves it** (listing 21, the 40f079cf ×
  406820cf edge above). So the population is a
  second hub-disjoint near-component with a
  single measured leak, against the hub
  component's perfect closure (26/26 internal).
  What singles these populations apart remains
  NOT PROVEN.

## (iii) The complete pairwise gap table

All 28 unordered pairs of the 8 gap records
(runs 62: gaps 1–2; 74: gaps 3–7; 102: gap 8) on
the 32 features (9 frame + 23 split-kind), printed
in full in the raw section:

- **The table is bimodal by run, exactly.** Match
  distribution (total/32): {0: 14, 1: 2, 4: 1,
  9: 3, 10: 2, 13: 3, 15: 2, 19: 1}. The frame
  split is perfect: frame distribution {0: 17,
  9: 11} — **every same-run pair (11) matches on
  all 9 frame features, every cross-run pair (17)
  matches on 0**. Consequently every same-run pair
  scores ≥ 9 (range 9–19) and every cross-run pair
  scores ≤ 4 (range 0–4); the two bands do not
  overlap.
- **Gap 8 × gap 4 in the full table:** 4/32
  (frame 0/9, split-kind 4/23) — rank 12 of 28,
  with 11 pairs matching more, 16 matching fewer,
  and **no other pair matching exactly 4**. It is
  the **only cross-run pair above 1**: the only
  other cross-run pairs with any match at all are
  gaps 1×7 and 2×3, at 1/32 each (channel mapping
  alone). Gap 8 matches gaps 3, 5, 6, 7 and both
  run-62 gaps on **0 of 32**.
- **The maximum pair is gaps 5 × 6 at 19/32**
  (frame 9/9 + split-kind 10/23: both gap
  distances, both skipped counts, both skipped
  size lists, both skipped channel lists, and
  both channel-mapping features) — two gaps of
  run 74 that agree on everything except their
  steps, bounding acts, offsets, positions and
  surrounding windows (13 features differ).
  Runners-up: gaps 3×5 and 3×6 at 15/32.
- Split-kind distribution over the 28 pairs:
  {0: 17, 1: 4, 4: 4, 6: 2, 10: 1} — the 17 zero
  split-kind pairs are exactly the 14 zero-total
  pairs plus gaps 1×2, 3×4 and 4×7 (frame-only
  agreements within a run).

Mechanisms remain NOT PROVEN throughout.
Campaign 4's exit condition is unchanged: it
turns on authoring, not on further description
of these populations.

## Next (slice 4.157)

(i) The position-shift bands read in full: every
shared act's A/B position shift as a function of
position across both contexts (not just the
residue-0 rungs), locating the 0/+2 band boundary
and the −7 singleton's neighbourhood. (ii) The
one external listing (21) and its 1-listing
partner 406820cf read in full — the leak's other
side, and whether that side touches anything
else. (iii) Gaps 5 × 6 in full: the 13 features
on which the maximum pair still differs.
Host/artifact analysis only — no physical child.
