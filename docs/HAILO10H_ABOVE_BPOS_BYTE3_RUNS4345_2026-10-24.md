# The above-boundary population's B-position structure is a dense head-and-tail interleaving with a monotone main block (19 of the 30 above acts sit in the B 0–27 head window, interleaved with 9 shared run-0 acts in place and nothing else; the main block's 23 acts follow B position in strictly increasing offset rank; three outliers at B 229/272/674 and the tail at B 735–738/747–750 complete it; the only offset-order reversals in B position are the 873M ladder triple and the just-past-ceiling pair); the matched-pair byte3 difference confined to {14, 15, 16} is a function of NO non-trivial remaining companion (every single byte3 value, poscat, status, within-pair byte3 difference and byte3-of-diff byte fails on both sides; the only FUNCTION verdicts are the definitional ones — a side's diff from its own byte3 pair — and the trivial 27-distinct-key ones); and runs 43 (+32 pair, A 399–400), 44 (+239 singleton), 45 (+275 singleton, landing beside the B 674 outlier), 47 (+2 pair) and 48 (+32 pair, A 407–408) are each one contiguous B block — runs 43 and 48 are PAIRS, correcting the abbreviated single-act prose of AES-NUM-164 (AES-NUM-165)

Slice 4.165, worked under `docs/TASK_CONTRACT_4.165.md`
(contract published in the 4.164 closing commit @
b4dcc717). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef165.py (hef164.py verbatim as base plus the new
arms165) sha256
`4118f3b6b266a3230b7592bfb69028a25ecf6e23cd3b53ae69562eea4d9f74cc`
(945,836 B); arms165 sha256
`eadaa948d130c489e0819dd45fc49ef9369e41ef0a72d5a1b480a299fb03fbdb`
(14,985 B), its gzip sha256
`830302c13fd32876ed23cb7b3c8ec3825b0c48de906eee2211fee55c92d1561f`
(4,419 B). The base hef164.py was verified on the VM ==
the on-device hef164 (sha256 62cb1305…) before
assembly. Crossing record: the gzipped arms crossed
in 12 sha-gated parts of 373 B (last part 316 B);
11 verified on-device first try, part af was rejected
once on a sha mismatch (a corrupted re-emission in the
worker's own call), discarded uncommitted, and landed
on verbatim retry. The assembled gzip, the decompressed
arms and the assembled hef165 sha256 all matched
the VM exactly on-device, and the script compiled
on-device. The ONE bounded host-side child was
launched directly in a detached tmux session on
Mimir with the contract corpus argv — the six
hailo-ollama blobs in glob order, then MiniLM —
and finished with DONE165 as its last line, exit
marker 0, and a complete output, err empty (0 B).
Output hef165.out: 46,282 lines / 8,874,797 B, sha256
`cd221bcbc73a60abaf0c12069912bcc9e3760519f312efee353d7a0d198d418c`.
Prefix check: of its first 45,997 lines against
hef164.out, exactly TWO lines differ (lines 41,611
and 42,872 — the frozenset element-order variance
already recorded under AES-NUM-150/153–164; same
content and length), all other 45,995 lines
byte-identical (diff verified on-device).
Section165: 285 lines / 46,593 B, sha256
`3f2dba063c0dc2581e8f0f8d59af7b40326a1394007e3d85ec8890b51e564b9c`,
fetched by a device file read, verified on the VM
to exactly the on-device section sha, and read in
full. Controls: residue-0 sets 37 / 38 / shared 25 /
A-only 12 / B-only 13; byte2 census 85 listings /
96 distinct individual pairs / 11 hubs / 7 pairs at
exactly 3 listings; 8 gap records; gap 8 = run 102,
step 49; context act counts A 749 / B 751; shared
distinct acts 689, all single-positioned; above
population count 30, offset ranks 721–750, all
unshared, B positions exactly the AES-NUM-164 list;
cell populations 6864 = 27, 6932 = 27, matched cidx
keys 27, every key carrying both cells; run shifts
+32 / +239 / +275 / +2 / +32 — all exact. TWO
CONTROL EXPECTATIONS FAILED, and both were the
worker's own, written into arms165 from
AES-NUM-164's abbreviated prose (the same failure
class as the run-23 expectation in AES-NUM-164):
run 43 was expected from A 400 and is a +32 PAIR
at A 399–400 / B 431–432 (its first act is
(784832000, 32784, 2) at A 399), and run 48, named
in the contract from A 407, is a +32 PAIR at
A 407–408 / B 439–440. The measured values are the
record; the 4.164 prose's "run 43 (+32, A 400)" and
"run 48 (+32, A 407)" each named only one act of
the pair. All other run controls exact (runs
44/45 lengths 1/1, run 47 length 2 at A 405–406).
Raw output kept on the Pi at ~/aesir-build/
(hef165.out, hef165.py, arms165.py, section165.txt);
local lineage in ~/workspace/.verify-tmp/aesir165.

## (i) The above-boundary population's B-position structure in full

The 30 above acts in B-position order fall into 13
B-position segments (derived from the printed gaps):
(0–1), (5–6), (8), (10–11), (13–17), (19–20),
(22–23), (25–27), (229), (272), (674), (735–738)
and (747–750) — four isolated acts (B 8, 229, 272,
674) and no segment longer than 5. The gaps between
consecutive above acts in B position take only the
values {1, 2, 4, 9, 43, 61, 202, 402}, the maximum
402 between the B 272 and B 674 outliers.

**The head window B 0–27 holds 19 of the 30 above
acts and 9 shared acts and NOTHING else:** every
non-above position in the window is a shared act of
secondary run 0 sitting in place at shift +0 (A
positions 2, 3, 4, 7, 9, 12, 18, 21, 24 — exactly the
positions the above acts do not occupy). The above
acts interleave through the run-0 head at B
positions 0, 1, 5, 6, 8, 10, 11, 13–17, 19, 20,
22, 23, 25–27.

**Offset rank against B position:** the main
block's 23 acts are strictly increasing in offset
rank as B position increases — B 5 (rank 728),
6 (729), 8 (730), 10 (731), 11 (732), 13 (733),
14 (734), 15 (735), 16 (736), 17 (737), 19 (738),
20 (739), 22 (740), 23 (741), 25 (742), 26 (743),
229 (744), 272 (745), 674 (746), 735 (747),
736 (748), 737 (749), 738 (750) — the main block
reads in the same order in both orders (derived at
closing from the printed table). The ONLY
reversals are the two small clusters: the 873M
ladder triple sits at B 1 (rank 724), B 0 (rank
725), B 27 (rank 726) — its first two acts swapped
against offset order, its third displaced to the
head window's last position — and the
just-past-ceiling pair sits at B 748 (rank 721)
and B 747 (rank 722), also swapped. The 800M
singleton (B 749, rank 723) and the 973M singleton
(B 750, rank 727) close B's position order.

The outlier windows: B 229's window (226–232)
holds 6 shared acts and no other non-shared act —
runs 12 (−5), 100 (−452), 78 (−391) and 80 (−393)
around it. B 272's window (269–275) holds one
further non-above non-shared act, (3429888, 2064,
1) at B 271 (offset rank 29), between run 17 in
place and run 18 (+2). B 674's window (671–677)
holds a second B-only act at B 671 ((791121408,
32784, 2), offset rank 689), the −7 tail act at
B 675 (run 101), run 95 at B 676, and run 45's own
act at B 677 (see (iii)). The tail window B
730–750 holds 8 above acts and 13 shared acts
(all run 102 at +2) and nothing else: run 102's
acts fill B 730–734, the above block occupies
735–738, run 102 resumes at 739–746, and the four
remaining above acts close the context at
747–750. Any law behind the interleaving is
NOT PROVEN.

## (ii) The matched-pair byte3-difference confinement against the remaining companions

The confinement itself reproduces exactly: the
A-side byte3 difference (6932 minus 6864, per
matched cidx) takes {14 ×4, 15 ×13, 16 ×10} and
the B-side {14 ×2, 15 ×20, 16 ×5}, while the byte3
values themselves range widely — A 6864 takes 13
distinct values (192–211), A 6932 10 (206–226),
B 6864 15 (193–210), B 6932 15 (208–226). The
two sides' differences are equal in only 12 of 27
matches; the (A diff, B diff) pairs spread over
seven combinations, and the cross-side function
tests fail both ways (each side's diff value maps
to two or three values of the other side).

**The byte3 difference is a function of NO
non-trivial remaining companion, on either side:**
every single byte3 value fails (6864 A: violating
values 209/210 on the A side, 207/209/210 on the
B side; 6932 A: five violating values on the A
side, two on the B side; 6864 B: five / four;
6932 B: five / four); poscat fails (the interior
value carries all three diffs); the 6864 status,
the 6932 status and the status pair all fail
(DIFF carries all three diffs on both sides);
the within-pair byte3 differences fail (6864
side: four violating values per side; 6932 side:
four per side; their relation takes only the
three values {−1, 0, +1} and every one of them
carries at least two diffs on both sides); and
the byte3-of-diff bytes of both within-pair int
diffs fail (four to five violating values per
side). The within-pair byte3 distributions are
themselves wide (6864: −11…+15 over 13 values;
6932: −11…+16 over 15 values).

The only FUNCTION verdicts are the two classes
already graded trivial in this campaign: the
definitional ones — the A-side diff IS a function
of the pair of A byte3 values (15 keys, 0
violating) and the B-side diff of the pair of B
byte3 values (19 keys, 0 violating), because the
diff is computed from that pair, while each pair
fails for the OTHER side's diff (3 and 4
violating keys) — and the identity ones: cidx,
cidx order position, idx and the within-pair int
diffs each carry 27 distinct keys over 27 matches,
so their FUNCTION verdicts are the pair-identity
ones and earn nothing toward a determinant. The
confinement {14, 15, 16} therefore survives every
remaining companion tested with no companion
separating 14 from 15 from 16. The determinant
remains NOT PROVEN.

## (iii) Runs 43/44/45 and 47/48 in full

All five runs are single contiguous B blocks in
A order:

- Run 43: +32 PAIR at A 399–400, B 431–432 — acts
  (784832000, 32784, 2), (784865280, 26128, 0)
  (the pair correction recorded in the closing
  record above). Its B neighbourhood (428–435)
  reads: run 8's tail act (+203), run 53's +7 pair,
  run 43 itself, run 60's −1 pair, and run 23's
  second act (+135) at B 435.
- Run 44: +239 singleton (784891904, 32784, 0) at
  A 401 / B 640, flanked at B by run 42's +241
  triple (B 637–639, A 396–398 — its own shift
  three greater) before and run 85's −1 acts
  from B 641 after.
- Run 45: +275 singleton (784925184, 26128, 0) at
  A 402 / B 677. Its B neighbourhood (674–680)
  is the B 674 outlier window of (i): the
  above-boundary act itself at 674, run 101's −7
  act at 675, run 95's +2 act at 676, run 45 at
  677, then run 86's +26 acts from 678.
- Run 47: +2 pair at A 405–406, B 407–408 — acts
  (784968704, 32784, 2), (785001488, 26128, 2).
  Its B neighbourhood (404–411) is scrambled:
  single acts of runs 13 (+170), 35 (+30) and 14
  (+171) interleave at B 404–406 immediately
  before it, and run 22's +111 pair follows at
  B 409–410, then run 25 (+107) at 411.
- Run 48: +32 PAIR at A 407–408, B 439–440 — acts
  (785028096, 32784, 2), (785060880, 26128, 2)
  (the second pair correction). Its B
  neighbourhood (436–443) reads: run 23's second
  act at 436, run 61's +1 pair, run 48 itself,
  then run 62's +3 acts from 441.

Run 46's A window thus resolves completely: in A
order it is run 43's pair (+32), run 44 (+239),
run 45 (+275), run 46's −102 pair, run 47's pair
(+2) and run 48's pair (+32) — six runs over
A 399–408, every one a single contiguous B block,
landing at B 431–432, 640, 677, 301–302, 407–408
and 439–440 respectively: no two A-adjacent runs
of the window land adjacent at B except 47, which
sits in place. Mechanisms NOT PROVEN.

## Next

Slice 4.166 — the above population's B-position /
offset-rank order relation in full (every adjacent
pair in B-position order with its rank delta; the
873M triple and the ceiling pair reversals against
their full B neighbourhoods); the byte3-difference
confinement against the matched pairs' remaining
byte fields (byte0–byte2 values and matched
differences, each side, each cell); runs 42/53/60
and 61/62 in full (the B neighbours of runs 43
and 48). Host/artifact analysis only.
