# Every ff word classified, camp alignment resolved to the middle windows, first-in-train is the norm (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.90 (AES-NUM-090).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef90.py
(sha256 067171545fc684eae2030f90fd02008b908e4070fadb9039eac07425b2defd6a...),
landed via one-shot proxy-receiver transfer (gz sha256
cfac8e97f9913c69122a039251fb721d0b5b80b95d0862e285fcab9dec66047a...
returned by the receiver, matching; script sha verified
on-device). Output file /tmp/hef90_out.txt sha256
6d48a700bceacf64a412f8cf2df3d36959c36b54fafb84c1366cb13e8b6dc19c....
A labelled follow-up, hef90b.py (sha256
256c2bbc8664efe10ee0b1317cc474ab5282fa05bd97dcef12cb3e1834064bcc...;
gz sha256 07d2fa27d645c66c01ebcf290d18bb6513aba3cb98574b235bffa0780d305e4a...,
same receiver route; output sha256
2c8ee4face84261c63211ff538c9f9b3c259329506b9440b64f22bdd26713d3f...),
corrects ONE expression in hef90's content arm (the
others-set was built from hashes[j][j] instead of
hashes[j][i], which made every content count 0). All
non-content results are identical between the two
outputs; every content number below is hef90b's.
Transfer notes: one run with hand-typed blob paths
failed FileNotFoundError on a mistyped filename and was
superseded by shell-glob argv over the same corpus; one
invoke wrapper was interrupted by a service restart
while the device-side run completed regardless; the
first recv90b.py write failed its sha gate (corrupted
re-emission) and was discarded uncommitted, the chunked
256 B re-send landed clean. Controls reproduce
AES-NUM-029/032...089 EXACTLY (128,787 pooled small
actions; 79,001 pooled 24 B bursts; 745,849 pointer
actions; 1,504 contexts; trailing distinct (channel,
operand) pairs 2,049; champion-headed bursts 75,215).
Definitions (camps, classes, cidx / ngpos) are as in
AES-NUM-061...089. Contract:
docs/TASK_CONTRACT_4.90.md (published @ 364159d3 before
implementation).

## (i) Every aligned ff word in the scanned populations is CONST or the within-ng index — with one bounded, fully-mapped exception

The AES-NUM-088/089 scan was re-derived identically:
505 segment groups in the band (positions <= 30, sizes
8,000–40,000 B, >= 8 instances); 374 of them carry
>= 10 common aligned ff offsets (131 fall below that
threshold and are outside this classification); the
374 hold 20,645 common ff offsets in total. Every
common offset was classified by its byte-1 values
across its group's instances:

- CONST (one distinct value): 17,351 offsets.
- NGIDX (value == cidx - ng_start + 1 for every
  instance, each instance's own network group):
  3,290 offsets.
- OTHER: exactly 4 offsets, all in one group (below).

Per artifact (CONST / NGIDX / OTHER): 0856a10c
2000 / 419 / 0; 0a0d378c 3009 / 503 / 4; 5ab3537d
2978 / 613 / 0; 76c3a8ff 2820 / 468 / 0; 773470cd
3152 / 639 / 0; cc9b9d1c 3392 / 648 / 0. MiniLM
contributes no group to this scan (no (position,
size) group in MiniLM meets the band and common-ff
criteria). Of the 374 groups, 372 are variable and 2
are constant-only. The per-segment repetition
property (hef89's alleq) holds in 371 of the 372
variable groups; the sole alleq-false group is the
0a0d exception below.

The CONST scalar vocabulary has 29 distinct values,
dominated by 15 (11,007 offset-instances), then 127
(1,305), 5 (955), 0 (824), 7 (803), 1 (508), 3
(290), 23 (269), 2 (269), 34 (197), 11 (196), 31
(144), 63 (108), 69 (106), 17 (90), 95 (61), and a
tail of 8–139 values at <= 46 each.

The 0a0d exception (0a0d378c, position 25, size
32,632, 14 instances, 48 common ff offsets) has five
variable offsets. Offset 10976 is NGIDX exactly
(values 1, 7, 19, ..., 91 = the instances' ngidx).
The other four form two repeated pairs, each a
two-valued step on ngidx == 1 (the group's first
instance, cidx 74, is ng 1's first context):

- offsets 11820 and 11824: 15 at ngidx 1, 0 in the
  other 13 instances;
- offsets 31512 and 31704: 1 at ngidx 1, 7 in the
  other 13 instances.

So every instance's scalar tuple is (ngidx, 15, 15,
1, 1) for cidx 74 and (ngidx, 0, 0, 7, 7) for all
others. The four OTHER offsets are therefore not the
within-ng index and not constants, but they are exact
functions of ngidx (a step at ngidx == 1); no cidx + C
or ngidx + K fit exists (both fits None). What the
step, the pair duplication, or the values 15/0 and
1/7 MEAN is NOT PROVEN.

Verdict: MEASURED corpus-wide — the unified law
closes the ff vocabulary of the scanned populations:
constant or within-ng index everywhere, except four
offsets in a single group, which are two-valued
first-instance steps.

## (ii) Camp alignment: the tails are shared region-final content; the +64 lives in the grown regions' middle windows

Position-18 camps of 76c3a8ff (camp 21392 = 13
segments, representative cidx 130; camp 21648 = 12,
representative cidx 121; the representatives are
different contexts, so whole-segment equality is
confounded by ordinary per-context variation — the
camp-level facts are the region map and the tail
homes). Both camps carry 43 ff offsets and 44 regions
by the hef89 definition. The region length map
reproduces AES-NUM-088 exactly: lengths are equal at
40 of 44 ranks, and the only differences are the four
grown ranks 2 / 8 / 22 / 26 at +64 each. 34 of 44
regions are byte-equal between the representatives;
the six non-equal equal-length regions (0; the four
748 B regions 4 / 10 / 24 / 28, all cpfx 408 / csfx
339; and 43) differ in bounded middle bands
consistent with per-context fields. The
representatives' ff rank scalar sequences differ
(expected: their variable slots carry each
representative's own cidx - 92 scalar, 38 vs 29).

For each grown region (A length -> B length; common
prefix; common suffix):

- region 2: 472 -> 536; cpfx 132; csfx 172;
- region 8: 488 -> 552; cpfx 148; csfx 172;
- region 22: 544 -> 608; cpfx 204; csfx 172;
- region 26: 544 -> 608; cpfx 204; csfx 172.

Every grown region is therefore common prefix +
middle window + common suffix 172, with the A middle
exactly 168 B and the B middle exactly 232 B in all
four. The suffix 172 contains the AES-NUM-089 tail:
each tail chunk is the FINAL 64 B of its region in
BOTH camps (A home offset-in-region = lenA - 64 in
all four: 408 / 424 / 480 / 480), occurs exactly once
in each representative (A at 8980 / 11228 / 15444 /
17140; B at 9044 / 11356 / 15636 / 17396 — the
+64 / +128 / +192 / +256 staircase of AES-NUM-089),
and is preceded in both camps by the same 108 bytes.

Verdict tests, exactly as contracted: INSERTION
(B representative minus its four tails vs A
representative) FAILS — lengths match (21,392) but
583 bytes differ, first at byte 0; deleting the tails
is the wrong surgery, because the tails are shared
content, not the inserted material. DISPLACEMENT as
contracted (A minus homes vs B minus tails) is
length-degenerate (21,136 vs 21,392) and cannot hold.
The deciding observations: at every A-home range,
B-minus-tails carries A's preceding-64 chunk — the
suffix-alignment signature of the shared suffix, not
of a moved chunk; and each tail sits at the same
region rank and the same region-final position in
both camps.

Verdict: MEASURED — the four tails are NEITHER
duplicated NOR displaced. They are region-final
content present once in both camps. Camp 21648's
extra 256 B lives in the four grown regions' middle
windows (168 B in camp 21392 vs 232 B in camp 21648
at every grown rank). Whether camp B's extra middle
64 B per region is duplicated from elsewhere,
displaced from elsewhere, or new material is NOT
PROVEN — that is slice 4.91's question, and it needs
camp-consensus alignment to strip the per-context
variation that single representatives carry.

## (iii) First-in-train distinction is the norm, not a cidx-113 peculiarity

Trains corpus-wide (maximal constant-step cidx runs
of >= 8 contexts inside one (artifact, ng,
n_actions) group): 52 trains (0856a10c 9, 0a0d378c
11, 5ab3537d 7, 76c3a8ff 10, 773470cd 7, cc9b9d1c 8;
MiniLM none). The schedule distinction metric D(m)
of AES-NUM-087 was computed for every member of every
train; median D is 0 in all 52 trains and at most 3
members per train have D > 0 — distinction is
concentrated, and it lands on the first member in
most trains:

- 28 of 52 trains: the first member is the UNIQUE
  schedule outlier (rank 1, D > 0). Largest:
  773470cd ng 1 / 496 actions, D(first) = 342;
  0a0d378c ng 1 / 617, D = 294; 76c3a8ff ng 1 / 435,
  D = 284; 0a0d378c ng 0 / 620, D = 280; the sibling
  train itself, D = 249.
- 13 of 52 trains are fully unanimous (every member
  D = 0), including all three 76c3a8ff ng 0 trains
  and 0856a10c's four ng 0 trains.
- 11 of 52 trains: the outlier is a later member, or
  the first is undistinguished while another member
  is distinguished (e.g. 773470cd ng 0 / 762: first
  D = 0, max D = 6 at cidx 73).

Content metric (hef90b; positions where the other
members are segment-hash unanimous and the first
member's hash differs), computed for the 28
unique-first trains: content-distinguished in 25 of
28 (counts 1–43); exactly three have schedule
distinction with ZERO content distinction, all in
5ab3537d (232 actions D = 4; 471 actions D = 1; 762
actions D = 2).

Controls reproduce exactly. Sibling train
(76c3a8ff ng 1, 400 actions, step 9, cidx 113–338):
D(cidx 113) = 249 (AES-NUM-087: 249), and
content-distinguished positions for cidx 113 = 23
(AES-NUM-087: 23), at positions [0, 1, 8, 9, 16, 29,
32, 33, 34, 35, 37, 331, 376, 377, 378, 380, 381,
382, 383, 396, 397, 398, 399]. Position-18 camp
controls (AES-NUM-087 byte metric): camp 21392 has
72 two-valued positions in 2 distinct columns, first
segment (cidx 130) deviation 36, max deviation 36;
camp 21648 has 72 two-valued positions, first (cidx
121) deviation 36, max deviation 72 (cidx 274, 301)
— no first-segment privilege in the camps, exactly
as AES-NUM-087 found.

Verdict: MEASURED — a distinguished first context is
a general corpus phenomenon (28 of 52 trains, up to
D = 342, larger than the sibling train's 249), not
something special about cidx 113. It is not
universal: 13 trains are unanimous and in 11 the
outlier sits elsewhere. WHY a train's first context
is so often the outlier is NOT PROVEN.

## Next (slice 4.91)

- Grown-region middle windows under camp-consensus
  alignment: extract camp 21648's extra 64 B at each
  grown rank (consensus-stripped) and search both
  camps' full populations for its home — duplicated,
  displaced, or new.
- The 0a0d exception's step pattern elsewhere: do
  ngidx == 1 two-valued ff pairs recur in groups
  below the scan band or in other artifacts?
- First-in-train mechanism test: compare each
  distinguished first context against the first
  contexts of its network group's other trains
  (cross-train agreement of schedules and content).
Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
Every classification, region measurement, tail home,
train count and control above is MEASURED as stated;
every meaning — what the ngidx == 1 step encodes,
what camp B's extra middle bytes are, why first
contexts are outliers — is NOT PROVEN and nothing
here invents one.
