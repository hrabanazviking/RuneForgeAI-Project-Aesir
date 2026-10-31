# The 31 pairs' delta match-distance census closes the ±3 window question: 21 pairs match at distance 0, the two +174 exceptions match at distance 1 (run 7), and the other eight exceptions match NO run within three runs either side of either containing run — with distances 2 and 3 occurring zero times; match distance is a function of nothing tested; the heads' offset differences resolve into three exact families (9 shared at 0, three 873-based, sixteen 417-based), the 417-family is not monotone and its diff is a function of no size or channel field, its position-16 outlier is an A-side offset dip (B steps smoothly +376/+24 while A drops −100,392 then rises +100,864), and the three 873 B offsets span exactly 1,024 in +512 steps; runs 70 (+4 triple) and 71 (−238 triple) are each one contiguous B block (AES-NUM-170)

Slice 4.170, worked under `docs/TASK_CONTRACT_4.170.md`
(contract published in the 4.169 closing commit @
43cc82cd). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output, read in full.

## Run and closing record

hef170.py (hef169.py verbatim as base plus the new
arms170) sha256
`e9da44120b2fdbf2fe20d06e30cab49e59b8b00c448e3a738bfe256e5322be1e`
(1,029,187 B); arms170 sha256
`8f2af9648b59a762c88e90bee7fdfea604290a252e4da2d9d8ceafb7a3355b6e`
(17,533 B), its gzip sha256
`cd14b34bc59c9d95f1978e1f24891b309eedb6d983503602facadac4eefc82fc`
(5,244 B). The base hef169.py was verified on the VM ==
the on-device hef169 (sha256 fb4f3bb7…) before
assembly. Crossing record: the gzipped arms crossed
in 15 sha-gated parts of 373 B (last part 22 B); all
15 verified on-device first try — the assembled gzip,
decompressed arms and assembled hef170 sha256 all
matched the VM exactly on-device; the script compiled
on-device. Before launching, `tmux ls` and `ps` on
Mimir were checked twice for an existing hef170/h170
child (none — the 4.168 double-launch did not repeat):
exactly ONE bounded host-side child was launched, in
detached tmux with the contract corpus argv (glob
order, MiniLM last), and it finished with DONE170 as
its last line, exit marker 0, err empty (0 B).
Output hef170.out: 47,821 lines / 9,115,805 B, sha256
`782e51b6da0cb31cc769764c03ac1525fb15d66b0f51ac0263f0564b5f8b5f29`.
Prefix check: of its first 47,634 lines against
hef169.out, exactly ONE line differs (line 41,611);
that line has identical length (448) and identical
sorted character content in both outputs — frozenset
element order only, the AES-NUM-150 variance. All
other 47,633 lines byte-identical. Section 170:
187 lines / 37,705 B, sha256
`880e95f3b3c261a42947b5928b80cd3d36886f9e27a975a4834fb12b62093fd2`,
fetched by a device file read, verified on the VM to
exactly the on-device section sha and read in full.
Controls EXACT (context counts 749 / 751, shared 689,
A-only 60, B-only 62, union 811; both-side keys 31;
channel census {(0, 1): 12, (1, 0): 6, (1, 2): 7,
(2, 0): 6}; runs 70/71 lengths [3, 3], shifts
[+4, −238], first A positions [516, 519]; head size
sequences reproduced exactly). Raw output kept on
the Pi at ~/aesir-build/ (hef170.out, hef170.py,
arms170.py, section170.txt); local lineage in
~/workspace/.verify-tmp/aesir170.

## (i) The delta match-distance census

Definitions (stated in the output, followed exactly):
for each of the 31 1–1 correspondence pairs, delta =
B position − A position; the containing runs are the
runs of the preceding and following single-positioned
shared acts; the candidate window is the union of run
indices within three runs either side of either
containing run; a candidate run's distance is
min(|r − prun|, |r − frun|); the match distance is
the smallest distance among candidate runs with
shift == delta, or NONE.

- Distribution over all 31 pairs: distance 0 in 21,
  distance 1 in 2, distance 2 in 0, distance 3 in 0,
  NONE in 8. Matched within the window: 23 of 31.
- Distance 0 (21) reproduces AES-NUM-169's
  at-least-one-neighbour count exactly, as it must.
- The only distance-1 matches are the two +174
  exception pairs at A 216/217, matched by run 7
  (shift +174) at distance 1 from their containing
  run 6 — the same fact AES-NUM-169 found by hand,
  now falling out of the census mechanically.
- The eight remaining exceptions match NO run in
  the ±3 window at any distance: the +170 pair at
  A 212/213, the −205 pair at A 417/418, the −212
  pair at A 430/431, the +30 singleton at A 620,
  and the delta-0 pair at A 651 (a pair whose delta
  is 0 yet no containing-window run has shift 0 in
  reach — its neighbours' shifts are not 0).
- Match distance is a function of NOTHING tested:
  channel pair (4 keys, 3 violating), delta value
  (11 keys, 2 violating — delta 0 maps to {0, NONE}
  and delta +174 to {0, 1}), A position band
  50-wide (8 keys, 3 violating) and 100-wide
  (5 keys, 3 violating), and size (5 keys, 4
  violating) are all NOT A FUNCTION.
- Any position-delta law remains NOT PROVEN. The
  window question is now closed at ±3: widening the
  window is the only remaining match question, and
  it is slice 4.171's first arm.

## (ii) The heads' offset-difference family structure

Families defined operationally over positions 0–27
aligned by position (B offset minus A offset;
family by the B act): SHARED (diff exactly 0) at
9 positions [2, 3, 4, 7, 9, 12, 18, 21, 24];
873-family (B offset in [873,000,000, 874,000,000))
at 3 positions [0, 1, 27]; 417-family (B offset in
[1,196,000,000, 1,197,000,000)) at 16 positions
[5, 6, 8, 10, 11, 13, 14, 15, 16, 17, 19, 20, 22,
23, 25, 26]. The three families partition all 28
positions exactly — no OTHER position exists.

The 417-family diffs in position order:
417,353,216; 417,354,752; 417,344,000; 417,343,488;
417,343,488; 417,342,976; 417,343,016; 417,343,016;
417,443,784; 417,342,944; 417,342,464; 417,342,464;
417,341,952; 417,341,952; 417,341,440; 417,341,240.
16 values, 12 distinct, min 417,341,240 (position
26), max 417,443,784 (position 16). Successive
differences: +1,536; −10,752; −512; 0; −512; +40;
0; +100,768; −100,840; −480; 0; −512; 0; −512;
−200. The family is monotone in NEITHER direction;
upward steps occur at family indices 1, 6 and 8
(positions 6, 14 and 16 — AES-NUM-169's narrative
named positions 6 and 16; the +40 step at position
14 is now counted explicitly). Four position pairs
share an identical diff: (10, 11), (14, 15),
(19, 20) and (22, 23) — each an adjacent pair.

The 417 diff is a function of NO tested field:
A size (13 keys, 2 violating — size 24 carries
three diffs, size 32,728 two), B size (14 keys,
1 violating — size 24 again), A channel (3 keys,
all 3 violating), B channel (3 keys, all 3
violating), and the (A size, A channel) joint
(15 keys, 1 violating — (32728, 1) carries both
417,342,976 and 417,342,944) are all NOT A
FUNCTION. Position and A offset return FUNCTION
only trivially (every key occurs once).

Position-16 outlier in full: its diff 417,443,784
exceeds the rest of the family's maximum
(417,354,752) by +89,032; steps +100,768 into it
and −100,840 out of it. The outlier is A-side:
B offsets step smoothly through positions
15/16/17 (+376, then +24 — the sizes of the
preceding acts), while the A offset at position
16 (778,828,288) dips −100,392 below position
15's A offset and rises +100,864 to position
17's. The B side does nothing unusual at
position 16; the A head's offset sequence itself
is non-monotone there.

The 873-family across positions 0, 1 and 27: the
three B offsets are 873,199,104 (pos 0),
873,198,592 (pos 1) and 873,199,616 (pos 27) —
a span of exactly 1,024, in +512 steps (pos 1
lowest, pos 0 +512, pos 27 +1,024 over pos 1);
all three B acts are size 24, channels 1/0/2.
Their diffs against the position-aligned A acts
are NOT equal (94,363,136; 94,362,112; 94,170,608):
positions 0/1 differ by exactly 1,024 because the
A offsets step +512 while the B offsets step
−512 between those positions, and position 27's
A act is an unrelated shared act (run 1) — the
27 alignment is by position index only, as
AES-NUM-169 already recorded.

## (iii) Runs 70 and 71 in full

Run 70 is a +4 triple at A 516–518 / B 520–522,
one contiguous B block. In B order it is preceded
by run 69's tail at B 517 and run 19's +240 pair
at B 518–519, and followed by run 64's +23 act at
B 523 and run 74 at B 524–525.

Run 71 is a −238 triple at A 519–521 / B 281–283,
one contiguous B block. In B order it is preceded
by run 18's acts at B 278–279 and run 93's −391
act at B 280, and followed by run 73's −239 act
at B 284 and run 20's +5 pair at B 285–286. Its
acts are the (2064, 14352, 32784) sizes on
channel 2 throughout.

The shared order from run 69's first act through
run 72's first act is runs 69, 70, 71, 72 in A
order. Run table 68–74 stands as printed in the
section (run 72 a +93 singleton at A 522 / B 615;
run 73 a −239 singleton at A 523 / B 284; run 74
an 83-act +0 block at A 524–614).

Mechanisms NOT PROVEN; any position-delta law
NOT PROVEN; the heads' scaffold mechanism NOT
PROVEN. Next: slice 4.171 — the unbounded
match-distance census for the eight NONE pairs;
the 417-family equal-diff pairing structure and
the A-offset ordering of its positions; runs 72
and 73 in full.
