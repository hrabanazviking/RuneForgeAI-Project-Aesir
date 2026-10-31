# Run 74's eight internal gaps are exactly its delta-0 pairs in full (channel census {(0, 1): 6, (1, 2): 1, (2, 0): 1}, sizes 32,784×5 and 26,128×3, spacings [8, 1, 1, 1, 3, 5, 12]); the ninth delta-0 pair at A 651 shares the (1, 2) channel pair and the 26,128 size but lies in no run's extent, between run 85's last act at A 650 and run 86's first at A 652; the head's three lowest A offsets (positions 6, 16, 5) are NOT separated from the remaining 25 by the largest consecutive gap — their gap to the fourth-lowest is 7,168, only ninth of the 27 sorted-order gaps, with eight larger — though all three are 417-family members; and runs 76 (+4 pair) and 77 (+8 pair) are each one contiguous B block (AES-NUM-173)

Slice 4.173, worked under `docs/TASK_CONTRACT_4.173.md`
(contract published in the 4.172 closing commit @
c24732a4). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output, read in full.

## Run and closing record

hef173.py (hef172.py verbatim as base plus the new
arms173) sha256
`1b16333feadee4e12122777fab80f7d825893e8b8beb779147fc78feee26b0e1`
(1,074,996 B); arms173 sha256
`988883a8442fecb679e3ea7d851dacbc98e0194ec1396be63c8aa53f5132fb21`
(14,969 B), its gzip sha256
`da0162fc9ed077d9e9bd54987f07987b41e62228d878def5fb40d0daf2bad294`
(4,386 B). The base hef172.py was the on-device
hef172 (sha256 4663f9ba…, verified in the 4.172
closing). Crossing record: the gzipped arms crossed
in 12 sha-gated parts of 373 B (last part 283 B),
all 12 verified on-device first try; the assembled
gzip, decompressed arms and assembled hef173 sha256
all matched the VM exactly on-device; the script
compiled on-device. Before launching, `tmux ls` and
`ps` on Mimir were checked for an existing
hef173/h173 child (none): exactly ONE bounded
host-side child was launched, in detached tmux with
the contract corpus argv (glob order, MiniLM last),
and it finished with DONE173 as its last line, exit
marker 0, err empty (0 B). Output hef173.out:
48,617 lines / 9,216,823 B, sha256
`a5937a29d90c1ddc38c497c2117e83ce70fd4027ad5d9abd646a0623f31a2b3d`.
Prefix check: of its first 48,487 lines against
hef172.out, exactly ONE line differs (line 41,611);
that line has identical length (448) and identical
sorted character content in both outputs —
frozenset element order only, the AES-NUM-150
variance. All other 48,486 lines byte-identical.
Section 173: 130 lines / 18,220 B, sha256
`200b9c8a1ebe9c56985a43decad62ce36155d6e60507ac13d237146e319821fa`,
read in full on-device. Controls EXACT (context
counts 749 / 751, shared 689, A-only 60, B-only 62,
union 811; both-side keys 31; channel census
{(0, 1): 12, (1, 0): 6, (1, 2): 7, (2, 0): 6}; run
table 103 secondary runs; run 74 length 83, shift
+0, first A position 524, last 614; runs 76/77
lengths [2, 2], shifts [+4, +8], first A positions
[616, 618]; head size sequences reproduced exactly).
Raw output kept on the Pi at ~/aesir-build/
(hef173.out, hef173.py, arms173.py, section173.txt);
local lineage in ~/workspace/.verify-tmp/aesir173.

## (i) Run 74's eight internal gaps in full, against the ninth delta-0 pair

Definitions (stated in the output, followed exactly):
run 74 is the secondary run over single-positioned
shared acts in A order, shift +0; its A extent is
524..614 (width 91, 83 occupied). An internal gap is
an A position inside the extent occupied by no act
of run 74. A delta-0 pair is a 1-1 correspondence
pair (same (offset, size) key on both sides,
channels differ) whose B position minus A position
is 0.

The eight gaps recomputed are exactly
[549, 557, 558, 559, 560, 563, 568, 580], and the
delta-0 pairs recomputed are exactly nine, at A
positions [549, 557, 558, 559, 560, 563, 568, 580,
651]. Every gap position is a delta-0 pair's A
position, and every delta-0 pair inside the extent
is a gap (both directions True).

Each of the eight in full (A act; B act; offset;
size; channel pair; positions):

- 549: (788357120, 32784, 2) / (788357120, 32784, 0);
  pair (2, 0); A 549, B 549.
- 557: (788585984, 32784, 0) / (788585984, 32784, 1);
  pair (0, 1); A 557, B 557.
- 558: (788618768, 26128, 0) / (788618768, 26128, 1);
  pair (0, 1); A 558, B 558.
- 559: (788644896, 32784, 0) / (788644896, 32784, 1);
  pair (0, 1); A 559, B 559.
- 560: (788677680, 26128, 0) / (788677680, 26128, 1);
  pair (0, 1); A 560, B 560.
- 563: (788721152, 32784, 0) / (788721152, 32784, 1);
  pair (0, 1); A 563, B 563.
- 568: (788830208, 32784, 0) / (788830208, 32784, 1);
  pair (0, 1); A 568, B 568.
- 580: (789100544, 26128, 1) / (789100544, 26128, 2);
  pair (1, 2); A 580, B 580.

In every case the act at that A position in context
A is the pair's A act and the act at that B position
in context B is the pair's B act (same True, 8/8).

Population: channel-pair census over the eight
{(0, 1): 6, (1, 2): 1, (2, 0): 1}; size census
{32784: 5, 26128: 3}, sizes in gap order
[32784, 32784, 26128, 32784, 26128, 32784, 32784,
26128]; offsets in gap order [788357120, 788585984,
788618768, 788644896, 788677680, 788721152,
788830208, 789100544]. Spacing between consecutive
gaps (A-position differences) [8, 1, 1, 1, 3, 5, 12],
census {1: 3, 3: 1, 5: 1, 8: 1, 12: 1} — three of
the gaps form the consecutive run 557–560 with the
occupied neighbours 556 and 561. Occupied
neighbours of each gap: 549 (548, 550); 557, 558,
559, 560 (all 556, 561); 563 (562, 564); 568 (567,
569); 580 (579, 581).

The ninth delta-0 pair, at A 651, in full: A act
(790694912, 26128, 1), B act (790694912, 26128, 2),
offset 790694912, size 26128, channel pair (1, 2),
A pos 651, B pos 651, delta +0; the acts at those
positions in both contexts are the pair's acts
(same True). Against the eight: its channel pair
(1, 2) IS in the eight's census (one member, the
580 gap) and its size 26128 IS in the eight's size
census (three members); its spacing from the last
gap (580) is 71, far outside the eight's spacing
range (1–12). Its run/extent placement: NO
secondary run's A extent contains 651; the nearest
run ending before it is run 85 (9 acts, shift −1,
last A position 650) and the nearest run starting
after it is run 86 (6 acts, shift +26, first A
position 652). Its shared-act neighbours are run
85's last act (790679568, 14864, 1) at A 650 and
run 86's first act (790721536, 32784, 1) at A 652
— the ninth pair sits in the single-position seam
between runs 85 and 86, not inside any run.

All nine delta-0 pairs: channel-pair census
{(0, 1): 6, (1, 2): 2, (2, 0): 1}; size census
{26128: 4, 32784: 5}.

## (ii) The head's three lowest A offsets against the remaining 25

Definitions: the head is positions 0–27; diff =
B offset minus A offset at the same position; the
417-family is B offset in [1196000000, 1197000000).

The 28 head A offsets in sorted order begin:
position 6 (778,827,776), position 16
(778,828,288), position 5 (778,828,800), then
position 0 (778,835,968) and position 1
(778,836,480); the full sorted order is [6, 16, 5,
0, 1, 2, 3, 4, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17,
18, 19, 20, 21, 22, 23, 24, 25, 26, 27], A offsets
spanning 778,827,776..779,029,008.

The three lowest in full — all size 24 on both
sides, all 417-family members, channels equal on
both sides:

- Position 6: A (778827776, 24, 0), B (1196182528,
  24, 0), diff +417,354,752.
- Position 16: A (778828288, 24, 1), B (1196272072,
  24, 1), diff +417,443,784 — the only 417 diff of
  the three outside the +417,34x,xxx / +417,35x,xxx
  neighbourhood of the others; its B offset is
  89,544 above position 5's.
- Position 5: A (778828800, 24, 2), B (1196182016,
  24, 2), diff +417,353,216.

The 27 consecutive gaps in the full sorted order
are [512, 512, 7168, 512, 512, 512, 512, 512, 512,
33280, 512, 7800, 392, 512, 32728, 14416, 472,
32768, 512, 7712, 480, 512, 24848, 752, 512, 30208,
1552]. The three's internal gaps are 512 and 512
(span 1,024). The gap from the third-lowest to the
fourth-lowest (positions 5 → 0) is 7,168. Against
every other consecutive gap: it ranks 9th of 27 in
descending order — eight gaps are larger (33,280;
32,768; 32,728; 30,208; 24,848; 14,416; 7,800;
7,712), one equals it (itself), and 18 are smaller;
it is 0.218750 of the second-largest gap
(7,168 / 32,768).
Verdict by that measure: the three do NOT form a
separated low cluster — the boundary gap at their
top is not the sorted order's largest, nor in its
top eight. What is true is narrower: their two
internal gaps are both the modal 512, and the
7,168 above them is 14× that modal value.

417 census: the three are 3 of 3 in the family;
the remaining 25 are 13 of 25 in the family
(positions 8, 10, 11, 13, 14, 15, 17, 19, 20, 22,
23, 25, 26); the whole head is 16 of 28.

## (iii) Runs 76 and 77 in full

Run 76: a +4 pair at A 616–617, B 620–621, one
contiguous B block. Acts: (789952512, 32784, 0)
A 616 / B 620 and (789985296, 26128, 0) A 617 /
B 621. B neighbourhood (617–624): run 2's +432
acts at B 617–619 (A 185–187), run 76's pair, then
run 39's +238 pair at B 622–623 (A 384–385) and
run 4's +434 act at B 624 (A 190). A neighbourhood
(613–620): run 74's acts at 613–614, run 75's
−111 singleton at 615, runs 76 and 77, and at
A 620 an A-only distinct act (790071296, 32784, 1),
absent from context B.

Run 77: a +8 pair at A 618–619, B 626–627, one
contiguous B block. Acts: (790011904, 32784, 1)
A 618 / B 626 and (790044688, 26128, 1) A 619 /
B 627 — the same (32784, 26128) size pattern as
run 76, on channel 1 where run 76 is channel 0.
B neighbourhood (623–630): run 39's second act at
B 623, run 4's +434 acts at B 624–625 (A 190–191),
run 77's pair, run 41's +234 pair at B 628–629
(A 394–395), and run 79's +7 act at B 630 (A 623).
A neighbourhood (615–622): run 75's singleton,
runs 76 and 77, the A-only act at 620, and run
78's −391 pair at A 621–622 (B 230–231).

Shared-act order from run 75's first act through
run 78's first act (A order): run 75 at 615, run
76 at 616–617, run 77 at 618–619, run 78's first
at 621 — A position 620 carries no shared act.
Run table 74–81: (74, 83, +0, 524–614), (75, 1,
−111, 615), (76, 2, +4, 616–617, B [620, 621]),
(77, 2, +8, 618–619, B [626, 627]), (78, 2, −391,
621–622, B [230, 231]), (79, 2, +7, 623–624,
B [630, 631]), (80, 4, −393, 625–628, B [232–235]),
(81, 6, +25, 629–634, B [654–659]).

Mechanisms NOT PROVEN; any gap, cluster or
position-delta law NOT PROVEN; the heads' scaffold
mechanism NOT PROVEN.

## Next

Slice 4.174 — the eight larger head gaps in full
(the consecutive gaps in the sorted 28 exceeding
the 7,168 boundary gap: their rank pairs, the
positions they separate, and the 417/diff status
crossing each); the A 640–660 placement region of
the ninth delta-0 pair in full (runs 85 and 86
against the seam at 651); runs 78 and 79 in full.
Host/artifact analysis only.
