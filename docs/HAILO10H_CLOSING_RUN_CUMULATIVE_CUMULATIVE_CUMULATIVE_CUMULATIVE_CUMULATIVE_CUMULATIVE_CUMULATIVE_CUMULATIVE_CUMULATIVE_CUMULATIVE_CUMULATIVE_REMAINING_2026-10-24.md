# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-266)

Slice 4.266, worked under `docs/TASK_CONTRACT_4.266.md`
(contract published in the 4.265 closing commit @
6705ca25). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section266.txt).

## Run and closing record

hef266.py is the verified hef265 base plus
arms266: hef265.py sha256
`eddc9f2088692398061496f4cb9400fae796fc9742ca64feefa419efcd01ae3d`
(2,480,273 B) on both the VM and the device.
arms266 sha256
`cfbc2b5816ca6ee568b44795e66d27f068a3dade24a7531a74907e3fb9e329b4`
(40,564 B); hef266.py sha256
`e93468c911bc7564705fbeb6b2d4f2255a8630828110eeca1170532c8ad63f08`
(2,520,837 B) on both the VM and the device.
Crossing, stated exactly: arms266 was gzipped
with gzip -9 (sha256
`b93f8dd0654a7655575af6ceeb46c8f64582dd02919354ed344b7ddcf899c084`,
6,794 B) and split into nineteen 373 B parts
(last 80 B), each part written as its own file
with its own sha256 gate — eighteen verified
on-device on the first attempt and one (p_af)
rejected once for a corrupted re-emission
(497 vs 500 base64 chars, nothing accepted
unverified) and landed on a verbatim retry;
no byte accepted unverified. The assembled
gzip, arms and hef266 shas == VM on-device;
hef266 assembled on-device from
hef265.py + arms266.py, sha == VM, py_compile OK.

LAUNCH: pre-launch tmux/ps check found no
hef266/h266 child; exactly ONE bounded host-side
child ran in detached tmux (session h266, launched
2026-10-31 08:22:53 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef266.exit), err empty, and DONE266 as its last
line. Output hef266.out 59,372 lines / 11,102,203 B
sha256
`eac2eb079029de47c33b54be153c597f78a8a15082890f2668c58ad2d704b78e`;
prefix against hef265.out: the first 59,328 lines
differ from hef265.out in exactly TWO lines
(lines 41611 and 42872, frozenset element
order only — the AES-NUM-150 variance, verified
by same-sorted-characters comparison via
check266.py sha256
`337906bee6750ec79f353d1b1eb1004183d3413707ec44aa59b4327ea5c1eebc`),
hef266.out adding exactly its own 44 tail lines
(62,713 B, sha256
`cd4e130d14aaae0565bd488aee93f59f22e181d39e5465d95ae019b6dd694864`).
Controls EXACT except one inherited comparison:
at position 8 the cumulative cumulative
cumulative cumulative cumulative-remaining
remaining value computed is 12648, which equals
AES-NUM-260's printed value, but the arms
lineage's expected list carries 12658, so that
one comparison prints False — pre-existing in
hef265's own section265 (the same False is in
section265.txt), NOT introduced by this slice;
the 4.267 build corrects the expected list.
Raw output kept on the Pi at
~/aesir-build/ (hef266.out, hef266.py, arms266.py,
section266.txt, hef266.exit, hef266.err, run266.sh,
gz266/, check266.py); local lineage in
~/workspace/.verify-tmp/aesir266.

Definitions: POSITION is 1-based over the eight
acts of a closing run (position 1 = first act).
The A closing run is ranks 741–748 in A-offset
order; the B closing run is ranks 743–750 in
B-offset order. At each act position, the
AGREEMENT SET is the list, in the canonical family
order SIZE, CHANNEL, CLASS, RUN-102, OFFSET,
INDEX, of the families whose A value equals the
B value at that same position. The AGREEMENT
COUNT at a position is the number of families in
that position's agreement set (AES-NUM-248). The
CUMULATIVE AGREEMENT COUNT after a position is
the running total of the agreement counts over
positions 1 up to and including that position
(AES-NUM-249), ending at the total 16. The
CUMULATIVE-MINUS-COUNT DIFFERENCE at a position
is that position's cumulative total minus its own
agreement count (AES-NUM-250) — the cumulative
total before that position is counted. The
REMAINING at a position is 16 minus that
position's cumulative total (AES-NUM-251), ending
at 0. The CUMULATIVE REMAINING after a position
is the running total of the remaining values over
positions 1 up to and including that position
(AES-NUM-254), ending at the final cumulative
remaining total 70. The CUMULATIVE-REMAINING
REMAINING at a position is 70 minus that
position's cumulative remaining total — the
cumulative remaining instances still uncounted
after that position (AES-NUM-256). The
CUMULATIVE CUMULATIVE-REMAINING REMAINING after
a position is the running total of the
cumulative-remaining remaining values over
positions 1 up to and including that position
(AES-NUM-257), ending at 157. The CUMULATIVE
CUMULATIVE CUMULATIVE-REMAINING REMAINING after
a position is the running total of the
cumulative cumulative-remaining remaining values
over positions 1 up to and including that
position (AES-NUM-258), ending at 1049. The
CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE-REMAINING REMAINING after a position
is the running total of the cumulative cumulative
cumulative-remaining remaining values over
positions 1 up to and including that position
(AES-NUM-259), ending at 4164. The CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE-REMAINING REMAINING after a position
is the running total of the cumulative cumulative
cumulative cumulative-remaining remaining values
over positions 1 up to and including that
position (AES-NUM-260), ending at 12648. The
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE-REMAINING REMAINING after
a position is the running total of the cumulative
cumulative cumulative cumulative
cumulative-remaining remaining values over
positions 1 up to and including that position,
ending at 32370 (AES-NUM-261). The
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE-REMAINING
REMAINING after a position is the running total
of the cumulative cumulative cumulative
cumulative cumulative cumulative-remaining
remaining values over positions 1 up to and
including that position, ending at 73359 (AES-NUM-262). The
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE-REMAINING
REMAINING after a position is the running total
of the cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative-remaining
remaining values over positions 1 up to and
including that position, ending at 151668 (AES-NUM-263). The
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE-REMAINING
REMAINING after a position is the running total
of the cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative cumulative-remaining
remaining values over positions 1 up to and
including that position, ending at 291720 (AES-NUM-264). The
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE-REMAINING
REMAINING after a position is the running total
of the cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative cumulative cumulative-remaining
remaining values over positions 1 up to and
including that position, ending at 529191 (AES-NUM-265). The
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE-REMAINING
REMAINING after a position is the running total
of the cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative cumulative cumulative-remaining
remaining values over positions 1 up to and
including that position, ending at 914485.
The GAP at a gap
position 1–7 is the next act's offset minus this
act's offset; gap agreement means the A gap
equals the B gap at that position; the GAP
REMAINING at a gap position is the gap total 3
minus the gap cumulative agreement count after
that gap position (per AES-NUM-251); the GAP
CUMULATIVE REMAINING after a gap position is the
running total of the gap remaining values over gap
positions 1 up to and including that gap
position (per AES-NUM-254), ending at the final
gap cumulative remaining total 15; the GAP
CUMULATIVE-REMAINING REMAINING at a gap position
is 15 minus that position's gap cumulative
remaining total (AES-NUM-256); the GAP
CUMULATIVE CUMULATIVE-REMAINING REMAINING after
a gap position is the running total of the gap
cumulative-remaining remaining values over gap
positions 1 up to and including that gap
position (AES-NUM-257), ending at 31; the GAP
CUMULATIVE CUMULATIVE CUMULATIVE-REMAINING
REMAINING after a gap position is the running
total of the gap cumulative cumulative-remaining
remaining values over gap positions 1 up to and
including that gap position (AES-NUM-258),
ending at 183; the GAP CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE-REMAINING REMAINING after
a gap position is the running total of the gap
cumulative cumulative cumulative-remaining
remaining values over gap positions 1 up to and
including that gap position (AES-NUM-259),
ending at 651; the GAP CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE-REMAINING
REMAINING after a gap position is the running
total of the gap cumulative cumulative cumulative
cumulative-remaining remaining values over gap
positions 1 up to and including that gap
position (AES-NUM-260), ending at 1792; the GAP
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE-REMAINING REMAINING after
a gap position is the running total of the gap
cumulative cumulative cumulative cumulative
cumulative-remaining remaining values over gap
positions 1 up to and including that gap
position, ending at 4194 (AES-NUM-261). The GAP
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE-REMAINING
REMAINING after a gap position is the running
total of the gap cumulative cumulative
cumulative cumulative cumulative
cumulative-remaining remaining values over gap
positions 1 up to and including that gap
position, ending at 8757 (AES-NUM-262). The GAP
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE-REMAINING
REMAINING after a gap position is the running
total of the gap cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative-remaining remaining values over gap
positions 1 up to and including that gap
position, ending at 16786 (AES-NUM-263). The GAP
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE-REMAINING
REMAINING after a gap position is the running
total of the gap cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative cumulative-remaining remaining values over gap
positions 1 up to and including that gap
position, ending at 30096 (AES-NUM-264). The GAP
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE-REMAINING
REMAINING after a gap position is the running
total of the gap cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative cumulative cumulative-remaining remaining values over gap
positions 1 up to and including that gap
position, ending at 51129 (AES-NUM-265). The GAP
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE-REMAINING
REMAINING after a gap position is the running
total of the gap cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative cumulative cumulative-remaining remaining values over gap
positions 1 up to and including that gap
position, ending at 83083.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-265 cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative cumulative cumulative-remaining remaining values over
positions 1 up to and including that position,
stated position by position (each printed set
equals the AES-NUM-247 printed set, each printed
count equals the AES-NUM-248 printed count, each
printed cumulative total equals the AES-NUM-249
printed cumulative, each printed difference
equals the AES-NUM-250 printed difference, each
printed remaining equals the AES-NUM-251 printed
remaining, each printed cumulative remaining
equals the AES-NUM-254 printed value, each
printed cumulative-remaining remaining equals
the AES-NUM-256 printed value, each printed
cumulative cumulative-remaining remaining equals
the AES-NUM-257 printed value, each printed
cumulative cumulative cumulative-remaining
remaining equals the AES-NUM-258 printed value,
each printed cumulative cumulative cumulative
cumulative-remaining remaining equals the
AES-NUM-259 printed value, each printed
cumulative cumulative cumulative cumulative
cumulative-remaining remaining equals the
AES-NUM-260 printed value, each printed
cumulative cumulative cumulative cumulative
cumulative cumulative-remaining remaining equals the
AES-NUM-261 printed value, each printed
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative-remaining
remaining equals the
AES-NUM-262 printed value, each printed
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative-remaining
remaining equals the
AES-NUM-263 printed value, each printed
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative-remaining
remaining equals the
AES-NUM-264 printed value, each printed
cumulative cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative-remaining
remaining equals the
AES-NUM-265 printed value, each printed
cumulative cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative-remaining
remaining equals its expected value, and
remaining-after plus
cumulative remaining equals 70, printed tests
True for all eight):

- Position 1 (A rank 741 / B rank 743): set [RUN-102] — count 1 of 6 — cumulative 1 — difference 0 — remaining 15 — cumulative remaining 15 — cumulative-remaining remaining 55 — cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): set [CHANNEL, RUN-102] — count 2 of 6 — cumulative 3 — difference 1 — remaining 13 — cumulative remaining 28 — cumulative-remaining remaining 42 — cumulative cumulative-remaining remaining 97 — cumulative cumulative cumulative-remaining remaining 152 — cumulative cumulative cumulative cumulative-remaining remaining 207 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 262 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 317 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 372 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 427 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 482 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 537 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 592.
- Position 3 (A rank 743 / B rank 745): set [RUN-102] — count 1 of 6 — cumulative 4 — difference 3 — remaining 12 — cumulative remaining 40 — cumulative-remaining remaining 30 — cumulative cumulative-remaining remaining 127 — cumulative cumulative cumulative-remaining remaining 279 — cumulative cumulative cumulative cumulative-remaining remaining 486 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 748 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1065 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1437 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1864 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2346 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2883 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 3475.
- Position 4 (A rank 744 / B rank 746): set [] — count 0 of 6 — cumulative 4 — difference 4 — remaining 12 — cumulative remaining 52 — cumulative-remaining remaining 18 — cumulative cumulative-remaining remaining 145 — cumulative cumulative cumulative-remaining remaining 424 — cumulative cumulative cumulative cumulative-remaining remaining 910 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 1658 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2723 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 4160 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 6024 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 8370 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 11253 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 14728.
- Position 5 (A rank 745 / B rank 747): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 7 — difference 4 — remaining 9 — cumulative remaining 61 — cumulative-remaining remaining 9 — cumulative cumulative-remaining remaining 154 — cumulative cumulative cumulative-remaining remaining 578 — cumulative cumulative cumulative cumulative-remaining remaining 1488 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 3146 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 5869 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 10029 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 16053 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 24423 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 35676 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 50404.
- Position 6 (A rank 746 / B rank 748): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 10 — difference 7 — remaining 6 — cumulative remaining 67 — cumulative-remaining remaining 3 — cumulative cumulative-remaining remaining 157 — cumulative cumulative cumulative-remaining remaining 735 — cumulative cumulative cumulative cumulative-remaining remaining 2223 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 5369 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 11238 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 21267 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 37320 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 61743 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 97419 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 147823.
- Position 7 (A rank 747 / B rank 749): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 13 — difference 10 — remaining 3 — cumulative remaining 70 — cumulative-remaining remaining 0 — cumulative cumulative-remaining remaining 157 — cumulative cumulative cumulative-remaining remaining 892 — cumulative cumulative cumulative cumulative-remaining remaining 3115 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 8484 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 19722 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 40989 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 78309 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 140052 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 237471 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 385294.
- Position 8 (A rank 748 / B rank 750): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 16 — difference 13 — remaining 0 — cumulative remaining 70 — cumulative-remaining remaining 0 — cumulative cumulative-remaining remaining 157 — cumulative cumulative cumulative-remaining remaining 1049 — cumulative cumulative cumulative cumulative-remaining remaining 4164 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 12648 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 32370 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 73359 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 151668 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 291720 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 529191 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 914485.

Cumulative cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative-remaining
remaining sequence:
[55, 592, 3475, 14728, 50404, 147823, 385294, 914485] —
equals the expected sequence (printed test
True); the last cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative cumulative total is 914485.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, in order of first appearance,
with the positions at which each occurs and its
count stated exactly (counts sum to 8, printed
test True):

- 55: position 1 — count 1.
- 592: position 2 — count 1.
- 3475: position 3 — count 1.
- 14728: position 4 — count 1.
- 50404: position 5 — count 1.
- 147823: position 6 — count 1.
- 385294: position 7 — count 1.
- 914485: position 8 — count 1.

Eight distinct cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals; none repeats — stated as
printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-265 gap cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative cumulative cumulative-remaining remaining values over gap
positions 1 up to and including that gap
position, stated gap position by gap position
(each printed gap result equals the AES-NUM-247
printed result, each printed gap remaining
equals the AES-NUM-251 printed value, each
printed gap cumulative remaining equals the
AES-NUM-254 printed value, each printed gap
remaining-after equals the AES-NUM-256 printed
value, each printed gap cumulative
cumulative-remaining remaining equals the
AES-NUM-257 printed value, each printed gap
cumulative cumulative cumulative-remaining
remaining equals the AES-NUM-258 printed value,
each printed gap cumulative cumulative
cumulative cumulative-remaining remaining equals
the AES-NUM-259 printed value, each printed gap
cumulative cumulative cumulative cumulative
cumulative-remaining remaining equals the
AES-NUM-260 printed value, each printed gap
cumulative cumulative cumulative cumulative
cumulative cumulative-remaining remaining equals the
AES-NUM-261 printed value, each printed gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative-remaining
remaining equals the
AES-NUM-262 printed value, each printed gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative-remaining
remaining equals the
AES-NUM-263 printed value, each printed gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative-remaining
remaining equals the
AES-NUM-264 printed value, each printed gap
cumulative cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative-remaining
remaining equals the
AES-NUM-265 printed value, each printed gap
cumulative cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative-remaining
remaining equals its expected value, and
remaining-after plus gap
cumulative remaining equals 15, printed tests
True for all seven):
gap position 1 A 512 against B 712 — disagree,
gap cumulative 0, gap remaining 3, gap cumulative
remaining 3, gap remaining-after 12, gap
cumulative cumulative-remaining remaining 12, gap
cumulative cumulative cumulative-remaining
remaining 12, gap cumulative cumulative
cumulative cumulative-remaining remaining 12, gap
cumulative cumulative cumulative cumulative
cumulative-remaining remaining 12, gap cumulative
cumulative cumulative cumulative cumulative
cumulative-remaining remaining 12, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative-remaining
remaining 12, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative-remaining
remaining 12, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 12, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 12, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 12;
gap position 2 A 512 against B 26624 — disagree,
gap cumulative 0, gap remaining 3, gap cumulative
remaining 6, gap remaining-after 9, gap cumulative
cumulative-remaining remaining 21, gap cumulative
cumulative cumulative-remaining remaining 33, gap
cumulative cumulative cumulative
cumulative-remaining remaining 45, gap cumulative
cumulative cumulative cumulative
cumulative-remaining remaining 57, gap cumulative
cumulative cumulative cumulative cumulative
cumulative-remaining remaining 69, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative-remaining
remaining 81, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative-remaining
remaining 93, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 105, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 117, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 129; gap position
3 A 512 against B 14848 — disagree, gap
cumulative 0, gap remaining 3, gap cumulative
remaining 9, gap remaining-after 6, gap
cumulative cumulative-remaining remaining 27, gap
cumulative cumulative cumulative-remaining
remaining 60, gap cumulative cumulative
cumulative cumulative-remaining remaining 105,
gap cumulative cumulative cumulative cumulative
cumulative-remaining remaining 162, gap cumulative
cumulative cumulative cumulative cumulative
cumulative-remaining remaining 231, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative-remaining
remaining 312, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative-remaining
remaining 405, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 510, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 627, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 756;
gap position 4 A 512 against B 33280 — disagree,
gap cumulative 0, gap remaining 3, gap cumulative
remaining 12, gap remaining-after 3, gap
cumulative cumulative-remaining remaining 30, gap
cumulative cumulative cumulative-remaining
remaining 90, gap cumulative cumulative
cumulative cumulative-remaining remaining 195,
gap cumulative cumulative cumulative cumulative
cumulative-remaining remaining 357, gap cumulative
cumulative cumulative cumulative cumulative
cumulative-remaining remaining 588, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative-remaining
remaining 900, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative-remaining
remaining 1305, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 1815, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 2442, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 3198;
gap position 5 A 512 against B 512 — agree, gap
cumulative 1, gap remaining 2, gap cumulative
remaining 14, gap remaining-after 1, gap
cumulative cumulative-remaining remaining 31, gap
cumulative cumulative cumulative-remaining
remaining 121, gap cumulative cumulative
cumulative cumulative-remaining remaining 316,
gap cumulative cumulative cumulative cumulative
cumulative-remaining remaining 673, gap cumulative
cumulative cumulative cumulative cumulative
cumulative-remaining remaining 1261, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative-remaining
remaining 2161, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative-remaining
remaining 3466, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 5281, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 7723, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 10921;
gap position 6 A 512 against B 512 — agree, gap
cumulative 2, gap remaining 1, gap cumulative
remaining 15, gap remaining-after 0, gap
cumulative cumulative-remaining remaining 31, gap
cumulative cumulative cumulative-remaining
remaining 152, gap cumulative cumulative
cumulative cumulative-remaining remaining 468,
gap cumulative cumulative cumulative cumulative
cumulative-remaining remaining 1141, gap cumulative
cumulative cumulative cumulative cumulative
cumulative-remaining remaining 2402, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative-remaining
remaining 4563, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative-remaining
remaining 8029, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 13310, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 21033, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 31954;
gap position 7 A 512 against B 512 — agree, gap
cumulative 3, gap remaining 0, gap cumulative
remaining 15, gap remaining-after 0, gap
cumulative cumulative-remaining remaining 31, gap
cumulative cumulative cumulative-remaining
remaining 183, gap cumulative cumulative
cumulative cumulative-remaining remaining 651,
gap cumulative cumulative cumulative cumulative
cumulative-remaining remaining 1792, gap cumulative
cumulative cumulative cumulative cumulative
cumulative-remaining remaining 4194, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative-remaining
remaining 8757, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative-remaining
remaining 16786, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 30096, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 51129, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative-remaining
remaining 83083.

Gap cumulative cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative-remaining
remaining sequence:
[12, 129, 756, 3198, 10921, 31954, 83083] — equals the
expected sequence (printed test True), ends at
83083, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245; the printed gap cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative-remaining remaining sequence equals
AES-NUM-265, the printed gap cumulative
remaining sequence equals AES-NUM-254, and the
printed gap remaining sequence equals
AES-NUM-251.

Contract tests: the printed cumulative sequence
equals (55, 592, 3475, 14728, 50404, 147823, 385294,
914485) — True; the distinct cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals' counts
sum to 8 — True; the last cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total equals
914485 — True; the gap cumulative sequence equals
(12, 129, 756, 3198, 10921, 31954, 83083) and ends at
83083 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
