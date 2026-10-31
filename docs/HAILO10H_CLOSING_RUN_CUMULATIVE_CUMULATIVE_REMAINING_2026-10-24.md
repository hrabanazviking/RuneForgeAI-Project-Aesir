# The closing-run cumulative cumulative-remaining remaining-count sequence, the distinct cumulative totals, and the gap cumulative cumulative-remaining remaining-count sequence (AES-NUM-257)

Slice 4.257, worked under `docs/TASK_CONTRACT_4.257.md`
(contract published in the 4.256 closing commit @
78cf6008). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section257.txt).

## Run and closing record

hef257.py is the verified hef256 base plus
arms257: hef256.py sha256
`d83740dac5df5af49666aefb6455a29aa0fd533a49dc74be13ce04ed01c0a60e`
(2,221,277 B) on both the VM and the device.
arms257 sha256
`823647ff9f4b63014f1cc3a551332d07684676042a1f7126beb38e4b80dc9dce`
(20,870 B); hef257.py sha256
`ac11a35476295794afa8a01c9dfed379c63596b6df29c070762f03f1e1591054`
(2,242,147 B) on both the VM and the device.
Crossing, stated exactly: arms257 was gzipped
(sha256
`41992c679b32e10e9a9887d225441f997327599852331ba291250c7646dc1c3a`,
5,196 B) and split into fourteen 373 B parts (last
347 B), each part written as its own file with its
own sha256 gate — all fourteen verified on-device
on the first attempt; no byte accepted unverified.
The assembled gzip, arms and hef257 shas == VM
on-device; hef257 assembled on-device from
hef256.py + arms257.py, sha == VM, py_compile OK.

LAUNCH: pre-launch tmux/ps check found no
hef257/h257 child; exactly ONE bounded host-side
child ran in detached tmux (session h257, launched
2026-10-31 04:33:13 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef257.exit), err empty, and DONE257 as its last
line. Output hef257.out 58,976 lines / 10,738,023 B
sha256
`e0a6b63e31248f1a738f5eb130ac47b0404ae5201760f242c236bbbb4a553a5a`;
prefix against hef256.out: the first 58,934 lines
differ from hef256.out in exactly TWO lines (lines
41611 and 42872, frozenset element order only — the
AES-NUM-150 variance, each verified by
same-sorted-characters comparison via check257.py
sha256
`f1de28f3d71830a7d38bcca1be90f802962f67bc9a00f6f133973b59fd9f7b1e`),
hef257.out adding exactly its own 42 tail lines
(18,172 B, sha256
`11f354f11ce94db5831512227269b4dcc4deb3f8e0eea5d4378fd17b307195c9`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef257.out, hef257.py, arms257.py,
section257.txt, hef257.exit, hef257.err, run257.sh,
gz257/, check257.py); local lineage in
~/workspace/.verify-tmp/aesir257.

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
positions 1 up to and including that position,
ending at 157. The GAP at a gap position
1–7 is the next act's offset minus this act's
offset; gap agreement means the A gap equals the
B gap at that position; the GAP REMAINING at a
gap position is the gap total 3 minus the gap
cumulative agreement count after that gap
position (per AES-NUM-251); the GAP CUMULATIVE
REMAINING after a gap position is the running
total of the gap remaining values over gap
positions 1 up to and including that gap position
(per AES-NUM-254), ending at the final gap
cumulative remaining total 15; the GAP
CUMULATIVE-REMAINING REMAINING at a gap position
is 15 minus that position's gap cumulative
remaining total (AES-NUM-256); the GAP
CUMULATIVE CUMULATIVE-REMAINING REMAINING after
a gap position is the running total of the gap
cumulative-remaining remaining values over gap
positions 1 up to and including that gap
position, ending at 31.

## (i) The closing-run cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-256 cumulative-remaining remaining values
over positions 1 up to and including that
position, stated position by position (each
printed set equals the AES-NUM-247 printed set,
each printed count equals the AES-NUM-248 printed
count, each printed cumulative total equals the
AES-NUM-249 printed cumulative, each printed
difference equals the AES-NUM-250 printed
difference, each printed remaining equals the
AES-NUM-251 printed remaining, each printed
cumulative remaining equals the AES-NUM-254
printed value, each printed cumulative-remaining
remaining equals the AES-NUM-256 printed value,
each printed cumulative cumulative-remaining
remaining equals its expected value, and
remaining-after plus cumulative remaining equals
70, printed tests True for all eight):

- Position 1 (A rank 741 / B rank 743): set [RUN-102] — count 1 of 6 — cumulative 1 — difference 0 — remaining 15 — cumulative remaining 15 — cumulative-remaining remaining 55 — cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): set [CHANNEL, RUN-102] — count 2 of 6 — cumulative 3 — difference 1 — remaining 13 — cumulative remaining 28 — cumulative-remaining remaining 42 — cumulative cumulative-remaining remaining 97.
- Position 3 (A rank 743 / B rank 745): set [RUN-102] — count 1 of 6 — cumulative 4 — difference 3 — remaining 12 — cumulative remaining 40 — cumulative-remaining remaining 30 — cumulative cumulative-remaining remaining 127.
- Position 4 (A rank 744 / B rank 746): set [] — count 0 of 6 — cumulative 4 — difference 4 — remaining 12 — cumulative remaining 52 — cumulative-remaining remaining 18 — cumulative cumulative-remaining remaining 145.
- Position 5 (A rank 745 / B rank 747): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 7 — difference 4 — remaining 9 — cumulative remaining 61 — cumulative-remaining remaining 9 — cumulative cumulative-remaining remaining 154.
- Position 6 (A rank 746 / B rank 748): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 10 — difference 7 — remaining 6 — cumulative remaining 67 — cumulative-remaining remaining 3 — cumulative cumulative-remaining remaining 157.
- Position 7 (A rank 747 / B rank 749): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 13 — difference 10 — remaining 3 — cumulative remaining 70 — cumulative-remaining remaining 0 — cumulative cumulative-remaining remaining 157.
- Position 8 (A rank 748 / B rank 750): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 16 — difference 13 — remaining 0 — cumulative remaining 70 — cumulative-remaining remaining 0 — cumulative cumulative-remaining remaining 157.

Cumulative cumulative-remaining remaining
sequence: [55, 97, 127, 145, 154, 157, 157, 157] —
equals the expected sequence (printed test True);
the last cumulative total is 157.

## (ii) The distinct cumulative totals in full

Distinct cumulative totals, in order of first
appearance, with the positions at which each
occurs and its count stated exactly (counts sum
to 8, printed test True):

- 55: position 1 — count 1.
- 97: position 2 — count 1.
- 127: position 3 — count 1.
- 145: position 4 — count 1.
- 154: position 5 — count 1.
- 157: positions 6, 7, 8 — count 3.

Six distinct cumulative totals; only 157 repeats,
at the last three positions — stated as printed
arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-256 gap cumulative-remaining remaining
values over gap positions 1 up to and including
that gap position, stated gap position by gap
position (each printed gap result equals the
AES-NUM-247 printed result, each printed gap
remaining equals the AES-NUM-251 printed value,
each printed gap cumulative remaining equals the
AES-NUM-254 printed value, each printed gap
remaining-after equals the AES-NUM-256 printed
value, each printed gap cumulative
cumulative-remaining remaining equals its
expected value, and remaining-after plus gap
cumulative remaining equals 15, printed tests
True for all seven): gap position 1 A 512 against
B 712 — disagree, gap cumulative 0, gap remaining
3, gap cumulative remaining 3, gap
remaining-after 12, gap cumulative
cumulative-remaining remaining 12; gap position 2
A 512 against B 26624 — disagree, gap cumulative
0, gap remaining 3, gap cumulative remaining 6,
gap remaining-after 9, gap cumulative
cumulative-remaining remaining 21; gap position 3
A 512 against B 14848 — disagree, gap cumulative
0, gap remaining 3, gap cumulative remaining 9,
gap remaining-after 6, gap cumulative
cumulative-remaining remaining 27; gap position 4
A 512 against B 33280 — disagree, gap cumulative
0, gap remaining 3, gap cumulative remaining 12,
gap remaining-after 3, gap cumulative
cumulative-remaining remaining 30; gap position 5
A 512 against B 512 — agree, gap cumulative 1,
gap remaining 2, gap cumulative remaining 14, gap
remaining-after 1, gap cumulative
cumulative-remaining remaining 31; gap position 6
A 512 against B 512 — agree, gap cumulative 2,
gap remaining 1, gap cumulative remaining 15, gap
remaining-after 0, gap cumulative
cumulative-remaining remaining 31; gap position 7
A 512 against B 512 — agree, gap cumulative 3,
gap remaining 0, gap cumulative remaining 15, gap
remaining-after 0, gap cumulative
cumulative-remaining remaining 31.

Gap cumulative cumulative-remaining remaining
sequence: [12, 21, 27, 30, 31, 31, 31] — equals
the expected sequence (printed test True), ends
at 31, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245; the printed gap
cumulative-remaining remaining sequence equals
AES-NUM-256, the printed gap cumulative remaining
sequence equals AES-NUM-254, and the printed gap
remaining sequence equals AES-NUM-251.

Contract tests: the printed cumulative sequence
equals (55, 97, 127, 145, 154, 157, 157, 157) —
True; the distinct cumulative totals' counts sum
to 8 — True; the last cumulative total equals
157 — True; the gap cumulative sequence equals
(12, 21, 27, 30, 31, 31, 31) and ends at 31 —
True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
