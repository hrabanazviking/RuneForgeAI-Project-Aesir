# The unbounded census resolves six of the eight NONE pairs and proves the other two deltas occur as no run shift anywhere: the +170 pair matches only run 13 at distance 7, the +30 singleton only run 35 at distance 42, the delta-0 pair at A 651 matches run 74 at distance 11, while −205 and −212 are shifts of NO run in the full 103-run table (NEVER); the 417-family's equal-diff pairing is exactly its adjacent pairing (four pairs, no non-adjacent equal diffs, each pair's A and B offset steps both equal its first member's size), and its A-offset ordering departs from position order in exactly eight reversals, seven of them position 16 against a later position and the eighth the (5, 6) pair, position 16's A offset ranking second-lowest of all 28 head A offsets; runs 72 (+93 singleton) and 73 (−239 singleton) are each one contiguous B block (AES-NUM-171)

Slice 4.171, worked under `docs/TASK_CONTRACT_4.171.md`
(contract published in the 4.170 closing commit @
ca9b2090). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output, read in full.

## Run and closing record

hef171.py (hef170.py verbatim as base plus the new
arms171) sha256
`b63a8c4e0fae2e5cde02b90faa79f7fa865e0eec03ecae3e85c75ee7e64adb02`
(1,045,570 B); arms171 sha256
`6e905b081e8cc2013f6e6627aa08c240b29ab0a2359b7f77d7651d6001fd60d8`
(16,383 B), its gzip sha256
`f9948517d99ce55c211a322177809b1cb24c5dded8efdb227ede259216fc9588`
(5,062 B). The base hef170.py was the on-device
hef170 (sha256 e9da4412…, verified in the 4.170
closing). Crossing record: the gzipped arms crossed
in 14 sha-gated parts of 373 B (last part 213 B);
one part (p_ai) failed its sha gate on first send
and was discarded uncommitted, then resent verbatim
and landed — all 14 parts verified on-device; the
assembled gzip, decompressed arms and assembled
hef171 sha256 all matched the VM exactly on-device;
the script compiled on-device. Before launching,
`tmux ls` and `ps` on Mimir were checked for an
existing hef171/h171 child (none — the 4.168
double-launch did not repeat): exactly ONE bounded
host-side child was launched, in detached tmux with
the contract corpus argv (glob order, MiniLM last),
and it finished with DONE171 as its last line, exit
marker 0, err empty (0 B). Output hef171.out:
47,947 lines / 9,144,738 B, sha256
`9e7a932e63926ce1144a834de2ab71e59c8879916c0164652aa126691484c97f`.
Prefix check: of its first 47,821 lines against
hef170.out, exactly ONE line differs (line 41,611);
that line has identical length (448) and identical
sorted character content in both outputs — frozenset
element order only, the AES-NUM-150 variance. All
other 47,820 lines byte-identical. Section 171:
126 lines / 28,933 B, sha256
`6b89bb385c49858ecb6d0d41e7479b75a910baf1bb5b146e36e1c0c296797358`,
fetched by a device file read and read in full.
Controls EXACT (context counts 749 / 751, shared 689,
A-only 60, B-only 62, union 811; both-side keys 31;
channel census {(0, 1): 12, (1, 0): 6, (1, 2): 7,
(2, 0): 6}; run table 103 secondary runs; runs 72/73
lengths [1, 1], shifts [+93, −239], first A positions
[522, 523]; head size sequences reproduced exactly).
Raw output kept on the Pi at ~/aesir-build/
(hef171.out, hef171.py, arms171.py, section171.txt);
local lineage in ~/workspace/.verify-tmp/aesir171.

## (i) The unbounded delta match-distance census

Definitions (stated in the output, followed exactly):
as in AES-NUM-170, delta = B position − A position
and the containing runs are the runs of the preceding
and following single-positioned shared acts. The
unbounded search takes every secondary run in the
full table (103 runs) whose shift == delta, at
distance min(|r−prun|, |r−frun|); the unbounded
match distance is the smallest such distance, or
NEVER when no run in the full table has shift ==
delta.

Distribution over all 31 pairs: distance 0 in 21
(exactly the AES-NUM-170 window count), distance 1
in 2 (the +174 exceptions via run 7), distance 7 in
2, distance 11 in 1, distance 42 in 1, NEVER in 4.
No pair matches at distances 2–6, 8–10, or 12–41.

The eight AES-NUM-170 NONE pairs, in full:

- The +170 pair at A 212/213 (containing runs 5/6):
  exactly ONE run in the full table has shift +170 —
  run 13 (a 2-act run at A 233–234) — at distance 7.
  Unbounded match distance 7.
- The −205 pair at A 417/418 (containing runs
  50/51): NO run in the full table has shift −205.
  NEVER.
- The −212 pair at A 430/431 (containing runs
  57/58): NO run in the full table has shift −212.
  NEVER.
- The +30 singleton at A 620 (containing runs
  77/78): exactly ONE run has shift +30 — run 35
  (a singleton at A 375) — at distance 42.
  Unbounded match distance 42.
- The delta-0 pair at A 651 (containing runs
  85/86): six runs have shift 0 — runs 0, 3, 17,
  65, 68 and 74 — at distances 85, 82, 68, 20, 17
  and 11 respectively; the nearest is run 74, the
  83-act +0 block. Unbounded match distance 11.

Unbounded match distance is NOT A FUNCTION of
channel pair (4 keys, 3 violating), delta value
(11 keys, 2 violating: delta 0 → {0, 11}, delta
+174 → {0, 1}), A position band 50-wide (8 keys,
3 violating) or 100-wide (5 keys, 3 violating), or
size (5 keys, 4 violating).

## (ii) The 417-family equal-diff pairing and A-offset ordering

The family recomputes to the same sixteen positions
[5, 6, 8, 10, 11, 13, 14, 15, 16, 17, 19, 20, 22,
23, 25, 26] with the same twelve distinct diffs.

Equal-diff pairing is EXACTLY the adjacent pairing:
over all 120 position pairs of the family, exactly
four share an identical diff — (10, 11) at
417,343,488, (14, 15) at 417,343,016, (19, 20) at
417,342,464 and (22, 23) at 417,341,952 — all four
adjacent in family order, and there are NO
non-adjacent equal-diff pairs. In each of the four
pairs the A offset step and the B offset step
between the two positions are both equal to the
first member's size (+7,800, +14,416, +7,712 and
+24,848 respectively; channels agree within each
pair on both sides).

A-offset ordering: the family positions in A-offset
order are [6, 16, 5, 8, 10, 11, 13, 14, 15, 17, 19,
20, 22, 23, 25, 26] against position order
[5, 6, 8, 10, 11, 13, 14, 15, 16, 17, 19, 20, 22,
23, 25, 26]: 112 of 120 position-ordered pairs are
concordant and exactly 8 are reversals — (5, 6),
and position 16 against each of 5, 8, 10, 11, 13,
14 and 15. Position 16, the family's only
non-monotone member, sits second in A-offset order
despite standing ninth in position order.

Position 16 against every other head A offset
(positions 0–27): its A offset 778,828,288 ranks
1 of 28 (0-based; second-lowest) — exactly one head
A offset lies below it (position 6, 778,827,776)
and 26 above; its lower neighbour in offset order
is position 6 and its upper neighbour is position
5 (778,828,800, exactly +512 above it). The head
A-offset order over all 28 positions is not the
position order. In position order the steps into
and out of position 16 remain −100,392 / +100,864
(AES-NUM-170).

## (iii) Runs 72 and 73 in full

Run 72 is a +93 singleton: the act (787733504,
32784, 2) at A 522 / B 615, one contiguous B block
trivially. In B order it is preceded by run 74's
acts at B 612–614 and followed by run 2's +432
acts at B 616–618. In A order it is preceded by
run 71's triple at A 519–521 and followed by run
73 at A 523 and run 74 from A 524.

Run 73 is a −239 singleton: the act (787766784,
18448, 2) at A 523 / B 284, one contiguous B block
trivially. In B order it is preceded by run 71's
triple at B 281–283 and followed by run 20's +5
acts at B 285–287. In A order it shares run 72's
neighbourhood (A 520–526 printed in full in the
section).

The shared order from run 71's first act through
run 74's first act is runs 71, 72, 73, 74 in A
order. Run table 70–77 stands as printed in the
section (run 74 an 83-act +0 block at A 524–614;
run 75 a −111 singleton at A 615; run 76 a +4
pair at A 616–617; run 77 a +8 pair at A 618–619).

Mechanisms NOT PROVEN; any position-delta law
NOT PROVEN; the heads' scaffold mechanism NOT
PROVEN. Next: slice 4.172 — the full run-table
shift census against the 31 pair deltas (the
NEVER deltas −205/−212 in full); the 417-family
A-offset ordering with position 16 removed and
the (5, 6) reversal in full; runs 74 and 75
in full.
