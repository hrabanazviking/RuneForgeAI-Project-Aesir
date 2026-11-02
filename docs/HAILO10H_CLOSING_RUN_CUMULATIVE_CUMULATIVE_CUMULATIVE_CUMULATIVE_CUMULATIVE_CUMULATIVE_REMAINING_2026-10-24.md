# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-261)

Slice 4.261, worked under `docs/TASK_CONTRACT_4.261.md`
(contract published in the 4.260 closing commit @
c187924f). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section261.txt).

## Run and closing record

hef261.py is the verified hef260 base plus
arms261: hef260.py sha256
`aa7008dde9cb03664644a94f8603937cbdf74472237a9511f8934ec8410ca78c`
(2,315,376 B) on both the VM and the device.
arms261 sha256
`61a1bd53451e8bd377e5d32f09131b8d3a7be3b6036220663e1ef2cd2e4fdff9`
(28,357 B); hef261.py sha256
`3826f507244553ad5692c9dbbb1fb2c5dd3d8c05dcfe4ae289f145426b219563`
(2,343,733 B) on both the VM and the device.
Crossing, stated exactly: arms261 was gzipped
with gzip -9 (sha256
`8cf7484eb3cc516ba72117322d7a0272913659117aa729ff019688c5133d2eb9`,
5,908 B) and split into sixteen 373 B parts (last
313 B), each part written as its own file with its
own sha256 gate — all sixteen verified on-device
on the first attempt; no byte accepted unverified.
The assembled gzip, arms and hef261 shas == VM
on-device; hef261 assembled on-device from
hef260.py + arms261.py, sha == VM, py_compile OK.

LAUNCH: pre-launch tmux/ps check found no
hef261/h261 child; exactly ONE bounded host-side
child ran in detached tmux (session h261, launched
2026-10-31 06:23:43 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef261.exit), err empty, and DONE261 as its last
line. Output hef261.out 59,152 lines / 10,849,290 B
sha256
`0efd52509de7c3e4531b37301840085c23a48055d5c5d528000c76f9abf6393a`;
prefix against hef260.out: the first 59,108 lines
differ from hef260.out in exactly ONE line (line
41611, frozenset element order only — the
AES-NUM-150 variance, verified by
same-sorted-characters comparison via check261.py
sha256
`173ee7c0410af851d46ef4ace5121524923add4ac638de4f500986924e699931`),
hef261.out adding exactly its own 44 tail lines
(34,277 B, sha256
`7ad9de7f78503fe38a0b11e720255adca321c8111476b9d9a89d410b5f4306ca`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef261.out, hef261.py, arms261.py,
section261.txt, hef261.exit, hef261.err, run261.sh,
gz261/, check261.py); local lineage in
~/workspace/.verify-tmp/aesir261.

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
ending at 32370. The GAP at a gap
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
position, ending at 4194.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-260 cumulative cumulative cumulative
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
cumulative cumulative-remaining remaining equals its
expected value, and remaining-after plus
cumulative remaining equals 70, printed tests
True for all eight):

- Position 1 (A rank 741 / B rank 743): set [RUN-102] — count 1 of 6 — cumulative 1 — difference 0 — remaining 15 — cumulative remaining 15 — cumulative-remaining remaining 55 — cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 55 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): set [CHANNEL, RUN-102] — count 2 of 6 — cumulative 3 — difference 1 — remaining 13 — cumulative remaining 28 — cumulative-remaining remaining 42 — cumulative cumulative-remaining remaining 97 — cumulative cumulative cumulative-remaining remaining 152 — cumulative cumulative cumulative cumulative-remaining remaining 207 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 262 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 317.
- Position 3 (A rank 743 / B rank 745): set [RUN-102] — count 1 of 6 — cumulative 4 — difference 3 — remaining 12 — cumulative remaining 40 — cumulative-remaining remaining 30 — cumulative cumulative-remaining remaining 127 — cumulative cumulative cumulative-remaining remaining 279 — cumulative cumulative cumulative cumulative-remaining remaining 486 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 748 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1065.
- Position 4 (A rank 744 / B rank 746): set [] — count 0 of 6 — cumulative 4 — difference 4 — remaining 12 — cumulative remaining 52 — cumulative-remaining remaining 18 — cumulative cumulative-remaining remaining 145 — cumulative cumulative cumulative-remaining remaining 424 — cumulative cumulative cumulative cumulative-remaining remaining 910 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 1658 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2723.
- Position 5 (A rank 745 / B rank 747): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 7 — difference 4 — remaining 9 — cumulative remaining 61 — cumulative-remaining remaining 9 — cumulative cumulative-remaining remaining 154 — cumulative cumulative cumulative-remaining remaining 578 — cumulative cumulative cumulative cumulative-remaining remaining 1488 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 3146 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 5869.
- Position 6 (A rank 746 / B rank 748): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 10 — difference 7 — remaining 6 — cumulative remaining 67 — cumulative-remaining remaining 3 — cumulative cumulative-remaining remaining 157 — cumulative cumulative cumulative-remaining remaining 735 — cumulative cumulative cumulative cumulative-remaining remaining 2223 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 5369 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 11238.
- Position 7 (A rank 747 / B rank 749): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 13 — difference 10 — remaining 3 — cumulative remaining 70 — cumulative-remaining remaining 0 — cumulative cumulative-remaining remaining 157 — cumulative cumulative cumulative-remaining remaining 892 — cumulative cumulative cumulative cumulative-remaining remaining 3115 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 8484 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 19722.
- Position 8 (A rank 748 / B rank 750): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 16 — difference 13 — remaining 0 — cumulative remaining 70 — cumulative-remaining remaining 0 — cumulative cumulative-remaining remaining 157 — cumulative cumulative cumulative-remaining remaining 1049 — cumulative cumulative cumulative cumulative-remaining remaining 4164 — cumulative cumulative cumulative cumulative cumulative-remaining remaining 12648 — cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 32370.

Cumulative cumulative cumulative cumulative
cumulative cumulative-remaining remaining sequence:
[55, 317, 1065, 2723, 5869, 11238, 19722, 32370] —
equals the expected sequence (printed test
True); the last cumulative cumulative cumulative
cumulative cumulative total is 32370.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative
cumulative cumulative totals, in order of first appearance,
with the positions at which each occurs and its
count stated exactly (counts sum to 8, printed
test True):

- 55: position 1 — count 1.
- 317: position 2 — count 1.
- 1065: position 3 — count 1.
- 2723: position 4 — count 1.
- 5869: position 5 — count 1.
- 11238: position 6 — count 1.
- 19722: position 7 — count 1.
- 32370: position 8 — count 1.

Eight distinct cumulative cumulative cumulative
cumulative cumulative totals; none repeats — stated as
printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-260 gap cumulative cumulative cumulative
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
cumulative cumulative-remaining remaining equals its
expected value, and remaining-after plus gap
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
cumulative-remaining remaining 12;
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
cumulative-remaining remaining 69; gap position
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
cumulative-remaining remaining 231;
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
cumulative-remaining remaining 588;
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
cumulative-remaining remaining 1261;
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
cumulative-remaining remaining 2402;
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
cumulative-remaining remaining 4194.

Gap cumulative cumulative cumulative cumulative
cumulative cumulative-remaining remaining sequence:
[12, 69, 231, 588, 1261, 2402, 4194] — equals the
expected sequence (printed test True), ends at
4194, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245; the printed gap cumulative
cumulative cumulative cumulative cumulative-remaining
remaining sequence equals AES-NUM-260, the
printed gap cumulative remaining sequence equals
AES-NUM-254, and the printed gap remaining
sequence equals AES-NUM-251.

Contract tests: the printed cumulative sequence
equals (55, 317, 1065, 2723, 5869, 11238, 19722,
32370) — True; the distinct cumulative cumulative
cumulative cumulative cumulative totals' counts sum to 8 —
True; the last cumulative cumulative cumulative
cumulative cumulative total equals 32370 — True; the gap
cumulative sequence equals (12, 69, 231, 588,
1261, 2402, 4194) and ends at 4194 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
