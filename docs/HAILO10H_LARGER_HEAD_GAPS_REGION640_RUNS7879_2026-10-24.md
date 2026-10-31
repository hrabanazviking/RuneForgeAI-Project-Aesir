# The eight larger head gaps are crossed from 417-family positions in all eight cases (below-side 8 of 8 in family, above-side 6 of 8; the two family exits land on diff-0 identity positions 9 and 18, and position 14 is shared between two larger gaps); the A 640–660 region is 20 shared acts plus the ninth pair's A-only act at A 651 on the A side and 19 shared plus two B-only acts at B 650–651 on the B side, with run 85 (A 642–650 / B 641–649) and run 86 (A 652–657 / B 678–683) each one contiguous B block; and runs 78 (−391 pair, sizes 1,552/14,864, channel 0) and 79 (+7 pair, sizes 32,784/26,128, channel 1) are each one contiguous B block (AES-NUM-174)

Slice 4.174, worked under `docs/TASK_CONTRACT_4.174.md`
(contract published in the 4.173 closing commit @
25628bbd). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output, read in full.

## Run and closing record

hef174.py (hef173.py verbatim as base plus the new
arms174) sha256
`f717c9f0845342e4a26db2ab969bab7878874e99338421316aeda89f0c7d0add`
(1,088,188 B); arms174 sha256
`22c8c57e49d43489289c61ab42a791686650cd7eec530873c24524e4bcecde54`
(13,192 B), its gzip sha256
`29c79cca764929fb377c95c76cb277fd1a132bb98f6f9d328b3aa5c02beed8db`
(3,794 B). The base hef173.py was the on-device
hef173 (sha256 1b16333f…, verified in the 4.173
closing). Crossing record: the gzipped arms crossed
in 11 sha-gated parts of 373 B (last part 64 B),
all 11 verified on-device first try; the assembled
gzip, decompressed arms and assembled hef174 sha256
all matched the VM exactly on-device; the script
compiled on-device. Before launching, `tmux ls` and
`ps` on Mimir were checked for an existing
hef174/h174 child (none): exactly ONE bounded
host-side child was launched, in detached tmux with
the contract corpus argv (glob order, MiniLM last),
and it finished with DONE174 as its last line, exit
marker 0, err empty (0 B). Output hef174.out:
48,827 lines / 9,243,983 B, sha256
`3b8755b0972ac3a019f58ef544aa44c0cda2089f0a2dba2dd74c407ff9ef94ca`.
Prefix check: of its first 48,617 lines against
hef173.out, exactly TWO lines differ (lines 41,611
and 42,872); both have identical length (448 and
276) and identical sorted character content in both
outputs — frozenset element order only, the
AES-NUM-150 variance. All other 48,615 lines
byte-identical. Section 174: 210 lines / 27,160 B,
sha256
`f176852d5ea8e0cb617ac7d68cf3f13cdcd20a2030c41a0c31297c9df86faee5`,
read in full on-device. Controls EXACT (context
counts 749 / 751, shared 689, A-only 60, B-only 62,
union 811; both-side keys 31; channel census
{(0, 1): 12, (1, 0): 6, (1, 2): 7, (2, 0): 6}; run
table 103 secondary runs; runs 78/79 lengths [2, 2],
shifts [−391, +7], first A positions [621, 623];
runs 85/86 lengths [9, 6], shifts [−1, +26], last A
positions [650, 657]; head size sequences reproduced
exactly) with ONE stated-expectation correction:
the arms' control line pre-wrote run 85's first A
position as 643; the measured value is 642 (A 642
is run 85's first act; A 640–641 belong to run 84).
The data are consistent throughout; only the
pre-written expectation was off by one. Raw output
kept on the Pi at ~/aesir-build/ (hef174.out,
hef174.py, arms174.py, section174.txt); local
lineage in ~/workspace/.verify-tmp/aesir174.

## (i) The eight larger head gaps in full

Definitions (stated in the output, followed
exactly): the head is positions 0–27; positions are
sorted by A offset; a consecutive gap is the
A-offset difference between ranks i and i+1; the
boundary gap is 7,168 (AES-NUM-173); the larger
gaps are those strictly greater than 7,168; diff =
B offset minus A offset at the same position; the
417-family is B offset in [1196000000, 1197000000).

The 27 consecutive gaps are [512, 512, 7168, 512,
512, 512, 512, 512, 512, 33280, 512, 7800, 392,
512, 32728, 14416, 472, 32768, 512, 7712, 480,
512, 24848, 752, 512, 30208, 1552] — exactly eight
exceed 7,168, at rank pairs (9, 10), (11, 12),
(14, 15), (15, 16), (17, 18), (19, 20), (22, 23),
(25, 26). The eight sum to 183,760 of the
201,232 total span.

Each of the eight in full (below position; above
position; diffs; family status):

- 33,280, ranks 9→10, positions 8 → 9. Below:
  (778839040, 32784, 1) / (1196183040, 32784, 1),
  diff +417,344,000, in family. Above: A and B
  both (778872320, 24, 1), diff +0, NOT in family.
  Family exit (True → False); diff change
  −417,344,000; B-offset step −417,310,720.
- 7,800, ranks 11→12, positions 10 → 11. Below:
  (778872832, 7800, 2) / (1196216320, 7800, 2),
  diff +417,343,488, in family. Above:
  (778880632, 344, 2) / (1196224120, 344, 2), diff
  +417,343,488, in family. Diff change 0; B step
  +7,800 (equal to the gap).
- 32,728, ranks 14→15, positions 13 → 14. Below:
  A (778881536, 32728, 1), B (1196224512, 32768,
  1) — the head position whose A and B sizes
  differ (32,728 vs 32,768); diff +417,342,976,
  in family. Above: (778914264, 14416, 1) /
  (1196257280, 14416, 1), diff +417,343,016, in
  family. Diff change +40; B step +32,768.
- 14,416, ranks 15→16, positions 14 → 15. Below
  is position 14 as above. Above: (778928680,
  376, 1) / (1196271696, 376, 1), diff
  +417,343,016, in family. Diff change 0; B step
  +14,416 (equal to the gap).
- 32,768, ranks 17→18, positions 17 → 18. Below:
  (778929152, 32728, 1) / (1196272096, 32728, 1),
  diff +417,342,944, in family. Above: A and B
  both (778961920, 24, 1), diff +0, NOT in family.
  Family exit (True → False); diff change
  −417,342,944; B-offset step −417,310,176.
- 7,712, ranks 19→20, positions 19 → 20. Below:
  (778962432, 7712, 0) / (1196304896, 7712, 0),
  diff +417,342,464, in family. Above:
  (778970144, 328, 0) / (1196312608, 328, 0), diff
  +417,342,464, in family. Diff change 0; B step
  +7,712 (equal to the gap).
- 24,848, ranks 22→23, positions 22 → 23. Below:
  (778971136, 24848, 1) / (1196313088, 24848, 1),
  diff +417,341,952, in family. Above:
  (778995984, 264, 1) / (1196337936, 264, 1), diff
  +417,341,952, in family. Diff change 0; B step
  +24,848 (equal to the gap).
- 30,208, ranks 25→26, positions 25 → 26. Below:
  (778997248, 30008, 2) / (1196338688, 30008, 2),
  diff +417,341,440, in family. Above:
  A (779027456, 1552, 0), B (1196368696, 280, 2)
  — A and B sizes and A channel differ at this
  position; diff +417,341,240, in family. Diff
  change −200; B step +30,008.

Population: positions below the eight are
[8, 10, 13, 14, 17, 19, 22, 25] — 8 of 8 in the
417-family. Positions above are [9, 11, 14, 15,
18, 20, 23, 26] — 6 of 8 in the family. Family
crossing census {(True, True): 6, (True, False):
2}; no gap is crossed from outside the family.
Position 14 is the one position that is above one
larger gap (32,728) and below another (14,416) —
two larger gaps are consecutive in the sorted
order at ranks 14–16. In four of the six
in-family crossings (7,800; 14,416; 7,712;
24,848) the B-offset step equals the gap exactly
and the diff is unchanged; the other two carry
the size anomalies at positions 13 (diff +40)
and 26 (diff −200). The two family exits land on
positions 9 and 18, both 24 B channel-1 acts
whose A and B offsets are identical (diff +0).
A-channel pairs across the eight are equal in
seven cases, the exception (2, 0) at the 30,208
gap; B-channel pairs are equal in all eight.

## (ii) The A 640–660 placement region of the ninth delta-0 pair

Definitions: A/B positions are indices into the
two contexts; the ninth delta-0 pair is the 1-1
correspondence pair at A 651 / B 651, delta +0,
recomputed here (nine pairs, A positions [549,
557, 558, 559, 560, 563, 568, 580, 651]). In
full: A act (790694912, 26128, 1), B act
(790694912, 26128, 2) — on the A side that act is
A-only distinct, on the B side B-only distinct;
they correspond by their shared (offset, size)
key, which is why 651 carries no shared act on
either side.

The A side of the region, 640–660: run 84's last
two acts at 640–641 (shift −5, B 635–636); run
85's nine acts at 642–650; the ninth pair's
A-only act at 651; run 86's six acts at 652–657;
run 87's two acts at 658–659 (shift −418, B
240–241); run 88's first act at 660 (shift +1,
B 661). Census: 20 shared single-positioned acts
and exactly 1 A-only distinct act (at 651).
Distinct runs on the A side: [84, 85, 86, 87, 88].

The B side of the region, 640–660: run 44's act
at 640 (A 401, shift +239); run 85's nine acts at
641–649 (A 642–650); B-only distinct acts at 650
— (790071296, 32784, 2), the B half of the
correspondence pair whose A half is the A-only
act at A 620 — and at 651, the ninth pair's B
act; run 15's acts at 652–653 (A 236–237, shift
+416); run 81's six acts at 654–659 (A 629–634,
shift +25); run 83's act at 660 (A 636, shift
+24). Census: 19 shared single-positioned acts
and exactly 2 B-only distinct acts (at 650,
651). Distinct runs on the B side: [15, 44, 81,
83, 85].

Run 85 in full: 9 acts, shift −1, A extent
642–650, B extent 641–649, B positions in A order
[641..649] — one contiguous B block. Acts (A pos
/ B pos): (790552064, 1552, 0) 642/641;
(790553616, 14864, 0) 643/642; (790568480, 26128,
0) 644/643; (790594608, 32784, 0) 645/644;
(790627840, 1552, 2) 646/645; (790629392, 14864,
2) 647/646; (790644736, 32784, 0) 648/647;
(790678016, 1552, 1) 649/648; (790679568, 14864,
1) 650/649. Its B neighbourhood (638–652) runs
from run 42's +241 acts and run 44's +239 act
through its own block to the two B-only acts at
650–651 and run 15's act at 652; its A
neighbourhood (639–653) runs from run 84's acts
through its own block, the A-only act at 651,
and run 86's first two acts.

Run 86 in full: 6 acts, shift +26, A extent
652–657, B extent 678–683, B positions in A
order [678..683] — one contiguous B block. Acts:
(790721536, 32784, 1) 652/678; (790754320, 26128,
1) 653/679; (790780448, 32784, 1) 654/680;
(790813232, 26128, 1) 655/681; (790839360, 32784,
1) 656/682; (790872144, 26128, 1) 657/683 — the
(32784, 26128) alternating size pattern on
channel 1. Its B neighbourhood (675–686) holds
run 101's −7 act at 675, run 95's +2 act at 676,
run 45's +275 act at 677, its own block, then
run 82's +49 act at 684 (A 635) and run 102's +2
acts at 685–686. Its A neighbourhood (649–660)
is run 85's last two acts, the seam at 651, its
own block, and runs 87/88 at 658–660.

The seam at 651, stated exactly: on the A side,
position 651 is the region's only non-shared
position, flanked by run 85's last act (650) and
run 86's first act (652); on the B side, the two
consecutive B-only acts at 650–651 sit
immediately after run 85's B block (641–649) and
before run 15's acts at 652.

## (iii) Runs 78 and 79 in full

Run 78: a −391 pair at A 621–622, B 230–231, one
contiguous B block. Acts: (790104576, 1552, 0)
A 621 / B 230 and (790106128, 14864, 0) A 622 /
B 231 — sizes (1552, 14864) on channel 0. B
neighbourhood (227–234): run 12's −5 act at 227
(A 232), run 100's −452 act at 228 (A 680), a
B-only distinct act at 229 (1196369408, 26128,
2), run 78's pair, then run 80's −393 acts at
232–234 (A 625–627). A neighbourhood (618–625):
run 77's pair, the A-only distinct act at 620
(790071296, 32784, 1), run 78's pair, run 79's
pair, and run 80's first act at 625.

Run 79: a +7 pair at A 623–624, B 630–631, one
contiguous B block. Acts: (790121472, 32784, 1)
A 623 / B 630 and (790154256, 26128, 1) A 624 /
B 631 — the (32784, 26128) size pattern on
channel 1, as in runs 76, 77 and 86. B
neighbourhood (627–634): run 77's second act at
627, run 41's +234 pair at 628–629 (A 394–395),
run 79's pair, and run 84's −5 acts at 632–634
(A 637–639). A neighbourhood (620–627): the
A-only act at 620, runs 78 and 79, and run 80's
acts at 625–627 (B 232–234).

Shared-act order from run 77's first act through
run 80's first act (A order): run 77 at 618–619,
run 78 at 621–622, run 79 at 623–624, run 80's
first at 625 — A position 620 carries no shared
act. Run table 76–83: (76, 2, +4, 616–617,
B [620, 621]), (77, 2, +8, 618–619, B [626,
627]), (78, 2, −391, 621–622, B [230, 231]),
(79, 2, +7, 623–624, B [630, 631]), (80, 4, −393,
625–628, B [232–235]), (81, 6, +25, 629–634,
B [654–659]), (82, 1, +49, 635, B [684]),
(83, 1, +24, 636, B [660]).

Mechanisms NOT PROVEN; any gap, cluster or
position-delta law NOT PROVEN; the heads' scaffold
mechanism NOT PROVEN.

## Next

Slice 4.175 — the head's twelve non-417-family
positions in full (including the diff-0 identity
positions 9 and 18 above the two family-exiting
larger gaps, against the positions below them);
runs 84, 87 and 88 in full (the remaining runs
touching the A 640–660 region); runs 80 and 81
in full. Host/artifact analysis only.
