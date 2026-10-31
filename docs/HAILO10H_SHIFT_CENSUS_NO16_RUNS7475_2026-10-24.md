# The full run-table shift census is mixed against the 31 pair deltas: 69 distinct shifts over 103 runs (range −455 to +434), nine of the eleven distinct pair deltas occur as run shifts and exactly two never do (−205 and −212, four pairs), the pair deltas are neither a subset of nor disjoint from the run shifts; with position 16 removed the 417-family's A-offset ordering has exactly ONE reversal, the (5, 6) pair (104 of 105 concordant), whose A offsets step −1,024 while its B offsets step +512; run 74 is an 83-act +0 in-place block whose eight internal B gaps are exactly the delta-0 correspondence pairs inside its extent, and run 75 is a −111 singleton (AES-NUM-172)

Slice 4.172, worked under `docs/TASK_CONTRACT_4.172.md`
(contract published in the 4.171 closing commit @
58846e3d). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output, read in full.

## Run and closing record

hef172.py (hef171.py verbatim as base plus the new
arms172) sha256
`4663f9ba58c760a17e9d1753e516c2ec1795cff9c8041c6e1f2b64835f891777`
(1,060,027 B); arms172 sha256
`c9d6712e109d69d430c82fcbc9010f933c62956e1df5e47c9dec46c5dd4149c0`
(14,457 B), its gzip sha256
`d809c42280def6133c3b3e5f8e06dba4254a6fb6428de52dc6d2af124c7bf419`
(4,342 B). The base hef171.py was the on-device
hef171 (sha256 b63a8c4e…, verified in the 4.171
closing). Crossing record: the gzipped arms crossed
in 12 sha-gated parts of 373 B (last part 239 B),
all 12 verified on-device first try; the assembled
gzip, decompressed arms and assembled hef172 sha256
all matched the VM exactly on-device; the script
compiled on-device. Before launching, `tmux ls` and
`ps` on Mimir were checked for an existing
hef172/h172 child (none — the 4.168 double-launch
did not repeat): exactly ONE bounded host-side child
was launched, in detached tmux with the contract
corpus argv (glob order, MiniLM last), and it
finished with DONE172 as its last line, exit marker
0, err empty (0 B). Output hef172.out: 48,487 lines /
9,198,603 B, sha256
`a593aacc6a468bb800b8943d311476b12b6eafebe531a423400a613b300640f0`.
Prefix check: of its first 47,947 lines against
hef171.out, exactly ONE line differs (line 41,611);
that line has identical length and identical sorted
character content in both outputs — frozenset element
order only, the AES-NUM-150 variance. All other
47,946 lines byte-identical. Section 172: 540 lines /
53,865 B, sha256
`a87e4734bdd5ce02dd8ccb283b0f0c124a0308598e53a29214f841d2c9afea0e`,
read in full on-device. Controls EXACT (context
counts 749 / 751, shared 689, A-only 60, B-only 62,
union 811; both-side keys 31; channel census
{(0, 1): 12, (1, 0): 6, (1, 2): 7, (2, 0): 6}; run
table 103 secondary runs; runs 74/75 lengths
[83, 1], shifts [+0, −111], first A positions
[524, 615]; head size sequences reproduced exactly).
Raw output kept on the Pi at ~/aesir-build/
(hef172.out, hef172.py, arms172.py, section172.txt);
local lineage in ~/workspace/.verify-tmp/aesir172.

## (i) The full run-table shift census against the 31 pair deltas

Definitions (stated in the output, followed exactly):
the run table is the 103 secondary runs over
single-positioned shared acts in A order, each run
carrying one shift (B position − A position). A pair
delta OCCURS when at least one secondary run has
shift == delta.

The census: 103 runs carry 69 distinct shifts, range
−455 (run 98) to +434 (run 4). Multiplicity: shift 0
is carried by 6 runs (0, 3, 17, 65, 68, 74; lengths
9, 2, 29, 1, 2, 83), +2 by 8 runs, +1 by 5, −5 by 3,
−2 by 3, +4/+5/+7 by 3 each, −391/−29/−4/+3/+32/+234/
+240 by 2 each; the remaining distinct shifts are
each carried by exactly one run. Every distinct
shift, with its run indices, lengths and first A
positions, is printed in full in the section.

The 31 pairs carry 11 distinct deltas
{−283, −212, −205, −157, −49, 0, +1, +3, +30, +170,
+174} with pair counts {−283: 1, −212: 2, −205: 2,
−157: 1, −49: 1, 0: 9, +1: 1, +3: 7, +30: 1, +170: 2,
+174: 4}. Against the census: nine distinct deltas
occur — −283 (run 96), −157 (run 34), −49 (run 54),
0 (the six runs above), +1 (runs 61, 88, 90, 92, 94),
+3 (runs 24, 62), +30 (run 35), +170 (run 13),
+174 (run 7) — and exactly two never occur: −205
and −212, zero runs each.

Set relation, stated exactly: pair deltas 11
distinct, run shifts 69 distinct, intersection 9,
pair-only 2 (−212, −205), run-only 60. The pair
deltas are NOT a subset of the run shifts, NOT
disjoint from them — the relation is MIXED. At pair
level: 27 of the 31 pairs' deltas occur; exactly 4
pairs' deltas never occur — the −205 pair at
A 417/418 and the −212 pair at A 430/431.

The NEVER deltas in full: −205's two pairs are the
A acts (785281536, 1552, 1) / (785283088, 14864, 1)
against their B counterparts at channel 0 with the
same offsets and sizes; its nearest distinct run
shifts by value are −213, −192, −190, −238, −239,
−157. −212's two pairs are the A acts (785580544,
1552, 1) / (785582096, 14864, 1) against channel-0
B counterparts, same offsets and sizes; its nearest
distinct run shifts are −213, −192, −190, −238,
−239, −255. Neither delta is a run shift anywhere
in the table — the AES-NUM-171 NEVER verdict now
censused against every distinct shift in full.

## (ii) The 417-family A-offset ordering with position 16 removed, and the (5, 6) reversal

The family recomputes to the same sixteen positions
[5, 6, 8, 10, 11, 13, 14, 15, 16, 17, 19, 20, 22,
23, 25, 26] with the same diffs in position order.

With position 16 removed, fifteen positions remain.
Their A-offset order is [6, 5, 8, 10, 11, 13, 14,
15, 17, 19, 20, 22, 23, 25, 26] against position
order [5, 6, 8, 10, 11, 13, 14, 15, 17, 19, 20, 22,
23, 25, 26]: of the 105 position-ordered pairs, 104
are concordant and exactly ONE is a reversal —
(5, 6), A offsets 778,828,800 (position 5) against
778,827,776 (position 6). So yes: with 16 removed,
the (5, 6) reversal is the family's ONLY reversal;
every other remaining pair is concordant. The
full-family control reproduces AES-NUM-171 exactly
(112 concordant, 8 reversals: (5, 6) plus position
16 against 5, 8, 10, 11, 13, 14, 15).

Positions 5 and 6 in full: position 5 is the A act
(778828800, 24, 2) / B act (1196182016, 24, 2),
diff +417,353,216; position 6 is the A act
(778827776, 24, 0) / B act (1196182528, 24, 0),
diff +417,354,752. Both are 24 B on both sides;
channels agree within each position (2/2 and 0/0).
The step 5→6: A offset −1,024, B offset +512, diff
change +1,536 — the reversal is an A-side step
backwards against a B-side step forwards, not a
shared step. Neighbours: in family position order
position 5 is first (next 6) and position 6 second
(prev 5, next 8); in the no-16 A-offset order
position 6 is first (next 5) and position 5 second
(prev 6, next 8); in the full head (0–27) A-offset
order position 6 ranks 0 (lowest of all 28, next
16), position 16 ranks 1, and position 5 ranks 2
(prev 16, next position 0) — the three lowest head
A offsets are exactly the family's three
reversal-involved positions, in the order 6, 16, 5.

## (iii) Runs 74 and 75 in full

Run 74 is an 83-act +0 block at A 524–614 / B
524–614: every one of its acts sits at the same
position in both contexts (shift +0, in place).
As a B-position set it is NOT step-1 contiguous:
its B positions are its A positions, and the eight
positions inside its extent that it does not occupy
— 549, 557, 558, 559, 560, 563, 568, 580 (gaps of
2, 5, 2, 2 and 2 in the sorted B list) — are exactly
the eight delta-0 correspondence pairs inside its
extent: at each, the A act is A-only distinct and
the B slot is filled by its B-only counterpart with
the same offset and size and a different channel
(e.g. B 549 (788357120, 32784, 0) against A 549
(788357120, 32784, 2)). The ninth delta-0 pair, at
A 651, lies outside run 74. In B order run 74 is
preceded at B 521–523 by run 70's +4 acts and run
64's +23 act, and followed at B 615–617 by run 72's
+93 act and run 2's +432 acts; in A order it is
preceded by runs 71/72/73 at A 521–523 and followed
by run 75 at A 615 and run 76 from A 616.

Run 75 is a −111 singleton: the act (789919232,
32784, 1) at A 615 / B 504, one contiguous B block
trivially. In B order it sits between run 67's −2
pair at B 502–503 and run 28's +157 act at B 505,
followed by run 68's +0 pair at B 506–507; in A
order between run 74's tail at A 612–614 and run
76's +4 pair at A 616–617.

The shared order from run 73's first act through
run 76's first act is runs 73, 74, 75, 76 in A
order. Run table 72–79 stands as printed in the
section (run 76 a +4 pair at A 616–617; run 77 a
+8 pair at A 618–619; run 78 a −391 pair at
A 621–622; run 79 a +7 pair at A 623–624).

Mechanisms NOT PROVEN; any position-delta law
NOT PROVEN; the heads' scaffold mechanism NOT
PROVEN. Next: slice 4.173 — run 74's eight internal
gaps in full (the delta-0 pairs inside its extent
against the ninth at A 651); the head's three
lowest A offsets (positions 6, 16, 5) against the
remaining 25; runs 76 and 77 in full.
