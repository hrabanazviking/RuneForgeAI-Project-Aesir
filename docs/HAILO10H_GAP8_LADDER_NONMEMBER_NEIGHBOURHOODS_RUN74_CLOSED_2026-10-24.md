# Gap 8's 512 stride is two ladders, not one: side B's skipped block is a uniform 512 ladder in a different region (offset difference 404,667,392 from side A on pairs 1–3), side A's block is that same ladder shifted, except its first act, which sits 24 bytes after the shared left bounding act — so A's first advance is 488 = 512 − 24, measured, not a preceding-size advance; the two non-member (1, 128) pairs earn no byte-0 near-miss listing for a measured reason — every Hamming-1 neighbour they have under either injective sub-key differs at byte2, never at byte0, while every member pair has a byte0-differing neighbour under both sub-keys; and run 74 is closed: its five gaps share exactly 9 of the 32 features (the run-level frame) and split on the other 23, with feature tables gap 3 vs 4/5/6 at 9/15/15 equal and gap 7 vs 4/5/6 at 9/13/13 equal — mechanisms NOT PROVEN (AES-NUM-152)

Slice 4.152, worked under `docs/TASK_CONTRACT_4.152.md`
(contract published in the 4.151 closing commit @
9c7bf215). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef152.py (hef151.py verbatim as base plus the new
arms152) sha256
`55d22a85a786aba63a3d0cd57f4f649363f632d51a51df18d9f2dccb1db0bf31`
(752,948 B); arms152 sha256
`9ddc57598e724da9b9772dc9e410d25aa6b5a0e03aeafb02d0c35ade0b7f9664`
(10,783 B), its gzip sha256
`3335027aa0ba58cb07022d3bd55c7cbcbff21e22aecf93e243f9dd038e17c0d3`.
The base hef151.py was verified on-device ==
VM (sha256 13dfea5f…) before assembly. Crossing
record: the gzipped arms crossed in 10 sha-gated
parts of 373 B (last part 239 B); every part's
sha256 verified on-device first try, no part
rejected. The assembled gzip, arms and hef152
sha256 all matched the VM exactly on-device, and
the script compiled on-device (py_compile OK).

The ONE bounded host-side child was launched in a
detached tmux session on Mimir with the contract
corpus argv — the six hailo-ollama blobs in glob
order, then MiniLM — via the sha-gated runner
run152.sh (sha256
`264d90fe1fc569f29256ead8cbfe74f97e5122dc45dfb80424604225ba742d4c`),
and finished with DONE152 as its last line, exit
marker 0, error channel empty. Output hef152.out:
42,409 lines / 8,170,799 B, sha256
`446b62ff99883df61f20265052c40dad3308040261ad1bcae5e1bfe5976af4e1`;
its first 41,915 lines are byte-identical to
hef151.out (cmp verified on-device). Section:
494 lines / 83,224 B, sha256
`509d3472ca04fab680f6622237fc56674cc31b8b53d66772517eef1b24caea73`
(gzip sha256
`95707e524be2d6ca1676509b7f4e94b1e136952d044bd0441186ce6029b589da`
kept on the Pi). Section return, stated honestly:
the first 65,536 B crossed by one device file.read
and decoded on the VM; the remainder was fetched
as the on-device gzip through a time-boxed
on-device HTTP server and the tunnel proxy, the
gzip sha256 matching on-device exactly, and the
decompressed section matching the on-device
section sha256 exactly. Controls EXACT: every
controls-echo expectation from slices 4.119–4.151
reproduced, including the 6 distinct near-miss
pair-pairs from the 4.151 arms. Raw output kept
on the Pi at ~/aesir-build/ (hef152.out, hef152.py,
arms152.py, section152.txt); local lineage in
~/workspace/.verify-tmp/aesir152.

## (i) Gap 8's non-contiguous block against gaps 1 and 2

Gap 8 in full: secondary run 102, step 49, run
shift +2, run length 58, run extents A positions
683..744 / B 685..746, distances A 5 / B 5,
skipped counts 4 / 4. Its bounding acts are the
same act in both contexts: LEFT
(791776768, 24, 0) at A pos 732 / B pos 734;
RIGHT (768609280, 24, 0) at A pos 737 / B pos
739. The four skipped acts carry identical sizes
and channels on both sides — sizes
(24, 24, 24, 24), channels (0, 1, 2, 0) — and its
mapping is the identity per act: set
((0, 0), (1, 1), (2, 2)), full
((0, 0), (1, 1), (2, 2), (0, 0)).

The blocks themselves live in different regions:

| pair | side A offset | side B offset | B − A |
|---|---|---|---|
| 0 | 791,776,792 | 1,196,444,160 | 404,667,368 |
| 1 | 791,777,280 | 1,196,444,672 | 404,667,392 |
| 2 | 791,777,792 | 1,196,445,184 | 404,667,392 |
| 3 | 791,778,304 | 1,196,445,696 | 404,667,392 |

Side B's block is a uniform 512 ladder: advances
[512, 512, 512], each exactly 512, none equal to
the preceding size (24). Side A's block advances
[488, 512, 512]. The 488 is measured arithmetic,
not a mystery: side A's first skipped act sits
exactly 24 bytes after the shared left bounding
act (791,776,792 − 791,776,768 = 24 = the bound's
own size, so the first skipped act is offset-
contiguous with the bound), and A's remaining
three skipped acts sit exactly on the 512 ladder
extending the bound (bound + 512, + 1024, + 1536
= 791,777,280 / 791,777,792 / 791,778,304). The
surrounding windows show the ladder approaching
the bound on both sides: the acts before the
bound are (791,775,744, 24, 1) and
(791,776,256, 24, 2) — 512 apart, the bound
itself the next rung — in context A and context
B alike; the contexts share every act up to and
including the bound, then diverge into their two
skipped regions. So side A = one act contiguous
with the bound, then the ladder; side B = the
ladder alone, in a region 404,667,392 bytes away
(the pair-0 difference is 24 less than the
constant 404,667,392 of pairs 1–3, exactly A's
24-byte contiguity). Neither side's skipped
block is offset-adjacent to the right bounding
act, which sits in a third region
(768,609,280). Mechanism NOT PROVEN; the
arithmetic above is exact.

The contrast with gaps 1 and 2, re-read in the
same form:

| | gap 1 | gap 2 | gap 8 |
|---|---|---|---|
| run / step | 62 / 5 | 62 / 11 | 102 / 49 |
| shift | +3 | +3 | +2 |
| distances A/B | 3/3 | 6/6 | 5/5 |
| skipped A/B | 2/2 | 5/5 | 4/4 |
| skipped offsets A vs B | identical (diff 0) | identical (diff 0) | different regions |
| skipped sizes | (1552, 14864) | (26128, 32784, 26128, 32784, 18448) | (24, 24, 24, 24) |
| advances vs preceding sizes | equal (1552) | equal (all four) | 512 stride; A first 488 |
| channels A / B | (1, 1) / (2, 2) | (2×5) / (0×5) | (0, 1, 2, 0) / (0, 1, 2, 0) |
| mapping | ((1, 2),) ×2 | ((2, 0),) ×5 | identity ((0,0), (1,1), (2,2), (0,0)) |
| first skipped beyond bound+size | 448 | 464 | A: 0 (contiguous); B: 404,667,368 |

In gaps 1 and 2 the two contexts skip the *same*
acts at the *same* offsets, the block chains by
preceding size, and one cross-channel mapping
pair repeats per skipped act. Gap 8 shares none
of those three properties: different regions,
a 512 stride instead of a size chain, and an
identity mapping over channels that already
agree. Gap 8 remains a different species;
AES-NUM-151's verdict stands, now with its
internal arithmetic measured.

## (ii) The two non-member (1, 128) pairs: why they earn no listing

The (byte1, byte3) = (1, 128) population is the
same 6 pairs (4 members of distinct pair-pairs
3/4, 2 non-members). Each pair's Hamming-1
neighbourhood over the full 224 was printed
under both injective sub-keys — (byte0, byte1,
byte2) and (byte0, byte2, byte3). A byte-0
near-miss listing (AES-NUM-150) requires a
Hamming-1 neighbour differing at byte0.

The non-members, in full:

**Byte2 177 at byte0 20** (group (19, 7712),
1 record, cell (19, 7712, 2384), SAME):
- Under (byte0, byte1, byte2): 2 neighbours,
  both differing at byte2 — the byte2-176 pair
  (20, 1, 176, byte3 0; group (19, 7712),
  1 record, cell third 7568) and the byte2-178
  member pair (20, 1, 178, 128; group (14, 9992),
  27 records, cell third 4336). Byte0-differing
  neighbours: 0.
- Under (byte0, byte2, byte3): 1 neighbour, the
  same byte2-178 member, differing at byte2.
  Byte0-differing neighbours: 0.

**Byte2 160 at byte0 68** (group (19, 7712),
1 record, cell (19, 7712, 2880), SAME):
- Under (byte0, byte1, byte2): 1 neighbour,
  differing at byte2 — the pair (68, 1, 162,
  byte3 0; group (14, 9992), 27 records, cell
  third 7424). Byte0-differing neighbours: 0.
- Under (byte0, byte2, byte3): 0 neighbours at
  all. Byte0-differing neighbours: 0.

The four members, for contrast, each carry at
least one byte0-differing neighbour under **both**
sub-keys: byte2 178 at byte0 20 (1 and 1 — its
byte0 neighbour is the byte2-178 pair at byte0
24 under both keys); byte2 178 at byte0 24 (1
and 1 — the byte0-20 pair); byte2 176 at byte0
28 (2 under the first key, 1 under the second);
byte2 176 at byte0 32 (2 and 1). Every member's
listing is earned under both sub-keys, matching
AES-NUM-150/151 (distinct pair-pairs 3 and 4 are
each listed under both sub-keys).

So the non-members' exclusion is MEASURED, not
assumed: their byte0 values (20 and 68) have no
Hamming-1 partner at the same (byte1, byte2) or
(byte2, byte3) anywhere in the 224 — byte0 20
exists at byte2 176/177/178, but its partners at
other byte0 values sit only at byte2 176 (byte3
0) and 178, never at 177; byte0 68's only
sub-key neighbour at all is at byte2 162. The
ladder of AES-NUM-151 explains the shape: the
members form the byte0 ladder 20–24–28–32 at
byte2 176/178, each rung one byte0 step from
another rung at the *same* byte2; the
non-members sit off that ladder (byte2 177 is
the rung between 176 and 178 with no byte0
partner; byte2 160 at byte0 68 is outside the
ladder's byte0 range entirely). Why byte2 177
and 160 carry no byte0 partner is NOT PROVEN;
that they carry none is measured over the
complete 224.

## (iii) Run 74 closed: gaps 3 and 7 against 4, 5 and 6

Gap 3 in full: step 24, run shift 0, run length
83, extents 524..614 on both sides; LEFT
(788,330,544, 26128, 1), RIGHT
(788,390,400, 32784, 0), both identical in both
contexts; distances 2/2; one skipped act on each
side, (788,357,120, 32784), channels A 2 / B 0,
mapping ((2, 0),); the skipped act sits 448
bytes beyond the left bound's end (the same 448
as gap 1's first skipped act — recorded as a
coincidence of numbers, no law claimed).

Gap 7 in full: step 48, run shift 0, run length
83, extents 524..614; LEFT
(789,067,376, 32784, 1), RIGHT
(789,127,168, 1552, 0), both identical in both
contexts; distances 2/2; one skipped act,
(789,100,544, 26128), channels A 1 / B 2,
mapping ((1, 2),); the skipped act sits 384
bytes beyond the left bound's end.

Feature tables (32 features, the AES-NUM-149
form):

| comparison | equal | differing |
|---|---|---|
| gap 3 vs gap 4 | 9 | 23 |
| gap 3 vs gap 5 | 15 | 17 |
| gap 3 vs gap 6 | 15 | 17 |
| gap 7 vs gap 4 | 9 | 23 |
| gap 7 vs gap 5 | 13 | 19 |
| gap 7 vs gap 6 | 13 | 19 |

Gap 4 is the distant sibling for both ends of
the run (9 equal, the run frame plus shifts and
little else — its four-act block and distance 5
split it from every single-act gap), while gaps
5 and 6, the (0, 1)-mapping single-act pair, sit
closest to both 3 and 7.

The five-gap closure over all 32 features: the
five gaps of run 74 share exactly **9** features
— `run`, `run shift`, `run length`, `run A first
pos`, `run A last pos`, `run B first pos`,
`run B last pos`, `left shift`, `right shift` —
which is precisely the run-level frame (same
run, same extents, no shift at either bound of
any gap). The other **23** features split the
five: step (5 distinct values), both bounding
acts and their per-side forms (5 each), gap
distances (2 distinct: 5 at gap 4, 2 elsewhere),
positions (5 each), skipped counts (2 distinct:
4 at gap 4, 1 elsewhere), skipped sizes (3
distinct), skipped offsets (5 each), skipped
channels (4 distinct per side), channel mapping
(3 distinct sets: ((2, 0),), ((0, 1),), ((1, 2),)),
mapping full (4 distinct — gap 4's repeats its
pair four times), and both surrounding windows
(5 each). Run 74 is therefore closed as a
population: one shared frame, and every
gap-local property — bounds, skipped act,
mapping — varying from gap to gap, with gap 4
the sole multi-act, distance-5 member and gaps
5/6 the sole mapping-sharing pair. No feature
or feature pair measured here determines the
mapping; mechanisms NOT PROVEN.

## Next

Slice 4.153 — gap 8's two skipped regions read
against their contexts in full (every 24-byte
act at a 512 stride around gap 8 in contexts A
and B; whether side B's ladder at 1,196,444,160
belongs to a wider ladder in context B, and
where side A's ladder ends at the right bound);
the byte2-differing Hamming-1 pair-pairs over
the full 224 as a census (the mirror of the
AES-NUM-150 byte0 census — listings, steps, and
where the two non-members and the four members
sit in it); and run 62's gaps 1 and 2 read
against each other in the 32-feature form,
completing run 62 as run 74 was completed here.
Host/artifact analysis only.
