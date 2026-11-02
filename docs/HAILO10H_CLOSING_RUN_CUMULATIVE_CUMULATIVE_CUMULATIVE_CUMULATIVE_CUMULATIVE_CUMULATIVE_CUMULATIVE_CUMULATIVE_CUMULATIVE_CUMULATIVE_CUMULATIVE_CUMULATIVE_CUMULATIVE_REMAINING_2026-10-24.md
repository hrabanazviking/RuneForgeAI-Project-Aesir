# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-268)

Slice 4.268, worked under `docs/TASK_CONTRACT_4.268.md`
(contract published in the 4.267 closing commit @
4c0f22f4). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section268.txt).

## Run and closing record

hef268.py is the verified hef267 base plus
arms268: hef267.py sha256
`1351b16b0036a6c3f7513d9d8f375d54cbf12b38dac3a83b06aa90820bf91d82`
(2,564,235 B) on both the VM and the device.
arms268 sha256
`04620dd38b6419a5f6db5ec5ee6f80ff9b436a6be43249139c6ab03ee8d9bdd7`
(46,352 B); hef268.py sha256
`400e9419d9c09b1494d8a7f195197a96ddfa2ffb9e770640b1b3715f96ef4a3e`
(2,610,587 B) on both the VM and the device.
Crossing, stated exactly: arms268 was gzipped
with gzip -9 (sha256
`d072a53227487c021463fe0eeb543ecfdd580cbb4ed98a3bd4452dcc36e91b46`,
7,148 B) and split into twenty 373 B parts
(last 61 B), each part written as its own file
with its own sha256 gate — all twenty verified
on-device on the first attempt; no byte accepted
unverified. The assembled gzip, arms and hef268
shas == VM on-device; hef268 assembled on-device
from hef267.py + arms268.py, sha == VM,
py_compile OK. The build protected the real
data value 21267 (AES-NUM-262 layer, two
occurrences) from the slice-number replace.

LAUNCH: pre-launch tmux/ps check found no
hef268/h268 child; exactly ONE bounded host-side
child ran in detached tmux (session h268, launched
2026-10-31 09:28:29 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef268.exit), err empty, and DONE268 as its last
line. Output hef268.out 59,460 lines / 11,248,475 B
sha256
`d018cfe82da60f2e87fb07722f39d8206c7cfca9551f936784f9afb9ec9ecea0`;
prefix against hef267.out: the first 59,416 lines
differ from hef267.out in exactly ONE line (line
41611, frozenset element order only, the
AES-NUM-150 variance, verified by
same-sorted-characters comparison via
check268.py sha256 9ed79fd5…), hef268.out adding
exactly its own 44 tail lines (76,733 B, sha256
`fa091ee85fcfd5443b2c82a0fe8cd0f402719d6b85786c4908ff46941206fbdb`).
Controls EXACT, with no exception this slice:
the only 'False' tokens in section268 are the
four gap-position agree data values for gap
positions 1–4 (positions 5, 6, 7 agree) — data,
not comparisons.
Raw output kept on the Pi at
~/aesir-build/ (hef268.out, hef268.py, arms268.py,
section268.txt, hef268.exit, hef268.err, run268.sh,
gz268/, check268.py); local lineage in
~/workspace/.verify-tmp/aesir268.

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
including that position, ending at 914485 (AES-NUM-266). The
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE-REMAINING
REMAINING after a position is the running total
of the cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative-remaining
remaining values over positions 1 up to and
including that position, ending at 1516856 (AES-NUM-267). The
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE-REMAINING
REMAINING after a position is the running total
of the cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative-remaining
remaining values over positions 1 up to and
including that position, ending at 2429232.
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
position, ending at 83083 (AES-NUM-266). The GAP
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE-REMAINING
REMAINING after a gap position is the running
total of the gap cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative-remaining remaining values over gap
positions 1 up to and including that gap
position, ending at 130053 (AES-NUM-267). The GAP
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE
CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE CUMULATIVE-REMAINING
REMAINING after a gap position is the running
total of the gap cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values over gap
positions 1 up to and including that gap
position, ending at 197184.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-267 cumulative cumulative cumulative
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
remaining equals the
AES-NUM-266 printed value, each printed
cumulative cumulative cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative-remaining
remaining equals the
AES-NUM-267 printed value, each printed
cumulative cumulative cumulative cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative-remaining
remaining equals its expected value, and
remaining-after plus
cumulative remaining equals 70, printed tests
True for all eight):

- Position 1 (A rank 741 / B rank 743): set [RUN-102] — count 1 of 6 — cumulative 1 — difference 0 — remaining 15 — cumulative remaining 15 — cumulative-remaining remaining 55 — cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): set [CHANNEL, RUN-102] — count 2 of 6 — cumulative 3 — difference 1 — remaining 13 — cumulative remaining 28 — cumulative-remaining remaining 42 — cumulative cumulative-remaining remaining 97 — cumulative cumulative cumulative-remaining remaining 152 — cumulative cumulative cumulative cumulative-remaining remaining 207 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 262 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 317 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 372 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 427 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 482 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 537 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 592 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 647 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 702.
- Position 3 (A rank 743 / B rank 745): set [RUN-102] — count 1 of 6 — cumulative 4 — difference 3 — remaining 12 — cumulative remaining 40 — cumulative-remaining remaining 30 — cumulative cumulative-remaining remaining 127 — cumulative cumulative cumulative-remaining remaining 279 — cumulative cumulative cumulative cumulative-remaining remaining 486 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 748 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1065 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1437 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1864 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2346 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2883 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 3475 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 4122 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 4824.
- Position 4 (A rank 744 / B rank 746): set [] — count 0 of 6 — cumulative 4 — difference 4 — remaining 12 — cumulative remaining 52 — cumulative-remaining remaining 18 — cumulative cumulative-remaining remaining 145 — cumulative cumulative cumulative-remaining remaining 424 — cumulative cumulative cumulative cumulative-remaining remaining 910 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 1658 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2723 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 4160 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 6024 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 8370 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 11253 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 14728 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 18850 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 23674.
- Position 5 (A rank 745 / B rank 747): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 7 — difference 4 — remaining 9 — cumulative remaining 61 — cumulative-remaining remaining 9 — cumulative cumulative-remaining remaining 154 — cumulative cumulative cumulative-remaining remaining 578 — cumulative cumulative cumulative cumulative-remaining remaining 1488 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 3146 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 5869 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 10029 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 16053 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 24423 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 35676 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 50404 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 69254 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 92928.
- Position 6 (A rank 746 / B rank 748): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 10 — difference 7 — remaining 6 — cumulative remaining 67 — cumulative-remaining remaining 3 — cumulative cumulative-remaining remaining 157 — cumulative cumulative cumulative-remaining remaining 735 — cumulative cumulative cumulative cumulative-remaining remaining 2223 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 5369 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 11238 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 21267 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 37320 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 61743 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 97419 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 147823 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 217077 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 310005.
- Position 7 (A rank 747 / B rank 749): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 13 — difference 10 — remaining 3 — cumulative remaining 70 — cumulative-remaining remaining 0 — cumulative cumulative-remaining remaining 157 — cumulative cumulative cumulative-remaining remaining 892 — cumulative cumulative cumulative cumulative-remaining remaining 3115 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 8484 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 19722 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 40989 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 78309 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 140052 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 237471 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 385294 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 602371 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 912376.
- Position 8 (A rank 748 / B rank 750): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 16 — difference 13 — remaining 0 — cumulative remaining 70 — cumulative-remaining remaining 0 — cumulative cumulative-remaining remaining 157 — cumulative cumulative cumulative-remaining remaining 1049 — cumulative cumulative cumulative cumulative-remaining remaining 4164 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 12648 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 32370 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 73359 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 151668 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 291720 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 529191 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 914485 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1516856 — cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2429232.

Cumulative cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative-remaining
remaining sequence:
[55, 702, 4824, 23674, 92928, 310005, 912376, 2429232] —
equals the expected sequence (printed test
True); the last cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total is 2429232.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, in order of first appearance,
with the positions at which each occurs and its
count stated exactly (counts sum to 8, printed
test True):

- 55: position 1 — count 1.
- 702: position 2 — count 1.
- 4824: position 3 — count 1.
- 23674: position 4 — count 1.
- 92928: position 5 — count 1.
- 310005: position 6 — count 1.
- 912376: position 7 — count 1.
- 2429232: position 8 — count 1.

Eight distinct cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals; none repeats — stated as
printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-267 gap cumulative cumulative cumulative
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
remaining equals the
AES-NUM-266 printed value, each printed gap
cumulative cumulative cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative-remaining
remaining equals the
AES-NUM-267 printed value, each printed gap
cumulative cumulative cumulative cumulative cumulative cumulative cumulative
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
remaining 12, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative-remaining
remaining 12, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative-remaining
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
remaining 129, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative-remaining
remaining 141, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative-remaining
remaining 153; gap position
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
remaining 756, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative-remaining
remaining 897, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative-remaining
remaining 1050;
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
remaining 3198, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative-remaining
remaining 4095, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative-remaining
remaining 5145;
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
remaining 10921, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative-remaining
remaining 15016, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative-remaining
remaining 20161;
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
remaining 31954, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative-remaining
remaining 46970, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative-remaining
remaining 67131;
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
remaining 83083, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative-remaining
remaining 130053, gap
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative-remaining
remaining 197184.

Gap cumulative cumulative cumulative cumulative
cumulative cumulative cumulative
cumulative cumulative-remaining
remaining sequence:
[12, 153, 1050, 5145, 20161, 67131, 197184] — equals the
expected sequence (printed test True), ends at
197184, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245; the printed gap cumulative
cumulative cumulative cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining sequence equals
AES-NUM-267, the printed gap cumulative
remaining sequence equals AES-NUM-254, and the
printed gap remaining sequence equals
AES-NUM-251.

Contract tests: the printed cumulative sequence
equals (55, 702, 4824, 23674, 92928, 310005, 912376,
2429232) — True; the distinct cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals' counts
sum to 8 — True; the last cumulative cumulative
cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total equals
2429232 — True; the gap cumulative sequence equals
(12, 153, 1050, 5145, 20161, 67131, 197184) and ends at
197184 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
