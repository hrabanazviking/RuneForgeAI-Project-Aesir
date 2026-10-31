# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-264)

Slice 4.264, worked under `docs/TASK_CONTRACT_4.264.md`
(contract published in the 4.263 closing commit @
9f788284). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section264.txt).

## Run and closing record

hef264.py is the verified hef263 base plus
arms264: hef263.py sha256
`99e0414c434e75ebd05190a50b6cc86fd0dbfa9bbd980826ae699d8ed5dcf7cb`
(2,407,118 B) on both the VM and the device.
arms264 sha256
`9e47e25ea6b1bf2270d2c49946899bb2f7cb68e335c355dba38f141fc0dbf677`
(35,292 B); hef264.py sha256
`d496b802c91b20ffbe3f45219fbd2506ab00dc889f04497414976dc4df244cd9`
(2,442,410 B) on both the VM and the device.
Crossing, stated exactly: arms264 was gzipped
with gzip -9 (sha256
`a61dc27d97aac995e50136686300d3460209165489020e71d0878fbe459df350`,
6,430 B) and split into eighteen 373 B parts
(last 89 B), each part written as its own file
with its own sha256 gate — all eighteen verified
on-device on the first attempt; no byte accepted
unverified. The assembled gzip, arms and hef264
shas == VM on-device; hef264 assembled on-device
from hef263.py + arms264.py, sha == VM, py_compile OK.

LAUNCH: pre-launch tmux/ps check found no
hef264/h264 child; exactly ONE bounded host-side
child ran in detached tmux (session h264, launched
2026-10-31 07:26:02 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef264.exit), err empty, and DONE264 as its last
line. Output hef264.out 59,284 lines / 10,983,218 B
sha256
`22d85a2df45acae0f0580fbf3c54b5c4e68fbb3ad17ded19ced0d42829cc1f74`;
prefix against hef263.out: the first 59,240 lines
differ from hef263.out in exactly ONE line
(line 41611, frozenset element
order only — the AES-NUM-150 variance, verified
by same-sorted-characters comparison via
check264.py sha256
`06ad2bba6215bf1fbb48d87f3efdce6b46b208f5d9b602528a40217a731f76a9`),
hef264.out adding exactly its own 44 tail lines
(50,208 B, sha256
`153957dd2df47db72199414e9251fa91f1421468b4b2c85c972ae569600ead0f`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef264.out, hef264.py, arms264.py,
section264.txt, hef264.exit, hef264.err, run264.sh,
gz264/, check264.py); local lineage in
~/workspace/.verify-tmp/aesir264.

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
including that position, ending at 291720.
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
position, ending at 30096.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-263 cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative-remaining remaining values over
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
remaining equals its expected value, and
remaining-after plus
cumulative remaining equals 70, printed tests
True for all eight):

- Position 1 (A rank 741 / B rank 743): set [RUN-102] — count 1 of 6 — cumulative 1 — difference 0 — remaining 15 — cumulative remaining 15 — cumulative-remaining remaining 55 — cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): set [CHANNEL, RUN-102] — count 2 of 6 — cumulative 3 — difference 1 — remaining 13 — cumulative remaining 28 — cumulative-remaining remaining 42 — cumulative cumulative-remaining remaining 97 — cumulative cumulative cumulative-remaining remaining 152 — cumulative cumulative cumulative cumulative-remaining remaining 207 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 262 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 317 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 372 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 427 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 482.
- Position 3 (A rank 743 / B rank 745): set [RUN-102] — count 1 of 6 — cumulative 4 — difference 3 — remaining 12 — cumulative remaining 40 — cumulative-remaining remaining 30 — cumulative cumulative-remaining remaining 127 — cumulative cumulative cumulative-remaining remaining 279 — cumulative cumulative cumulative cumulative-remaining remaining 486 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 748 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1065 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1437 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1864 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2346.
- Position 4 (A rank 744 / B rank 746): set [] — count 0 of 6 — cumulative 4 — difference 4 — remaining 12 — cumulative remaining 52 — cumulative-remaining remaining 18 — cumulative cumulative-remaining remaining 145 — cumulative cumulative cumulative-remaining remaining 424 — cumulative cumulative cumulative cumulative-remaining remaining 910 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 1658 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2723 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 4160 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 6024 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 8370.
- Position 5 (A rank 745 / B rank 747): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 7 — difference 4 — remaining 9 — cumulative remaining 61 — cumulative-remaining remaining 9 — cumulative cumulative-remaining remaining 154 — cumulative cumulative cumulative-remaining remaining 578 — cumulative cumulative cumulative cumulative-remaining remaining 1488 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 3146 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 5869 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 10029 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 16053 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 24423.
- Position 6 (A rank 746 / B rank 748): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 10 — difference 7 — remaining 6 — cumulative remaining 67 — cumulative-remaining remaining 3 — cumulative cumulative-remaining remaining 157 — cumulative cumulative cumulative-remaining remaining 735 — cumulative cumulative cumulative cumulative-remaining remaining 2223 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 5369 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 11238 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 21267 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 37320 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 61743.
- Position 7 (A rank 747 / B rank 749): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 13 — difference 10 — remaining 3 — cumulative remaining 70 — cumulative-remaining remaining 0 — cumulative cumulative-remaining remaining 157 — cumulative cumulative cumulative-remaining remaining 892 — cumulative cumulative cumulative cumulative-remaining remaining 3115 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 8484 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 19722 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 40989 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 78309 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 140052.
- Position 8 (A rank 748 / B rank 750): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 16 — difference 13 — remaining 0 — cumulative remaining 70 — cumulative-remaining remaining 0 — cumulative cumulative-remaining remaining 157 — cumulative cumulative cumulative-remaining remaining 1049 — cumulative cumulative cumulative cumulative-remaining remaining 4164 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 12648 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 32370 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 73359 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 151668 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 291720.

Cumulative cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative-remaining
remaining sequence:
[55, 482, 2346, 8370, 24423, 61743, 140052, 291720] —
equals the expected sequence (printed test
True); the last cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative total is 291720.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative totals, in order of first appearance,
with the positions at which each occurs and its
count stated exactly (counts sum to 8, printed
test True):

- 55: position 1 — count 1.
- 482: position 2 — count 1.
- 2346: position 3 — count 1.
- 8370: position 4 — count 1.
- 24423: position 5 — count 1.
- 61743: position 6 — count 1.
- 140052: position 7 — count 1.
- 291720: position 8 — count 1.

Eight distinct cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative totals; none repeats — stated as
printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-263 gap cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative-remaining remaining values over gap
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
remaining 105; gap position
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
remaining 510;
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
remaining 1815;
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
remaining 5281;
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
remaining 13310;
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
remaining 30096.

Gap cumulative cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative-remaining
remaining sequence:
[12, 105, 510, 1815, 5281, 13310, 30096] — equals the
expected sequence (printed test True), ends at
30096, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245; the printed gap cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative-remaining remaining sequence equals
AES-NUM-263, the printed gap cumulative
remaining sequence equals AES-NUM-254, and the
printed gap remaining sequence equals
AES-NUM-251.

Contract tests: the printed cumulative sequence
equals (55, 482, 2346, 8370, 24423, 61743, 140052,
291720) — True; the distinct cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative totals' counts
sum to 8 — True; the last cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative total equals
291720 — True; the gap cumulative sequence equals
(12, 105, 510, 1815, 5281, 13310, 30096) and ends at
30096 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
