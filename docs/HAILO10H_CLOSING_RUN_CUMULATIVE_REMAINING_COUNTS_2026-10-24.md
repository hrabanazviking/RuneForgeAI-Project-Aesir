# The closing-run cumulative remaining-count sequence, the distinct cumulative remaining totals, and the gap cumulative remaining-count sequence (AES-NUM-254)

Slice 4.254, worked under `docs/TASK_CONTRACT_4.254.md`
(contract published in the 4.253 closing commit @
0e9c9a1c). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section254.txt).

## Run and closing record

hef254.py is the verified hef253 base plus
arms254: hef253.py sha256
`831909bb8401c1df38c0ea6fa8011efded8df1a742bd3d5bdbeba3c27e656e7b`
(2,163,840 B) on both the VM and the device.
arms254 sha256
`8f7898236617b297ed7820719486e23701f2bb72625c28ab765db5888d37eac6`
(18,278 B); hef254.py sha256
`cd757ce3a7b1931832b9b551a040281a42d8fa89b35a0ebe8154dcf6093f076c`
(2,182,118 B) on both the VM and the device.
Crossing, stated exactly: arms254 was gzipped at
gzip -9 (sha256
`b52b09dccb1d884b5a77f061c341613f103680dd54f287d88fafbd4d0c63f539`,
4,846 B) and split into thirteen 373 B parts (last
370 B), each part written as its own file with its
own sha256 gate — all thirteen verified on-device
on the first attempt; no byte accepted unverified.
The assembled gzip, arms and hef254 shas == VM
on-device; hef254 assembled on-device from
hef253.py + arms254.py, sha == VM, py_compile OK.
Pre-launch tmux/ps check found no hef254/h254
child; exactly ONE bounded host-side child ran in
detached tmux (session h254, launched
2026-10-31 02:56:09 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef254.exit), err empty, and DONE254 as its last
line. Output hef254.out 58,847 lines /
10,688,907 B sha256
`8af645c1fc11744ec04730a20a062cf6ca9dc49438e4ed2ab9f744bce3563662`;
prefix against hef253.out: the first 58,804
lines differ from hef253.out in exactly TWO lines
(lines 41611 and 42872, frozenset element order
only — the AES-NUM-150 variance, each verified by
same-sorted-characters comparison), hef254.out
adding exactly its own 43 section lines (12,249 B,
sha256
`52c6feb5df79d6b6799221bc8a7d86e227f563d9b1d3ebd531c9affddc36ca0d`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef254.out, hef254.py, arms254.py,
section254.txt, hef254.exit, run254.sh, gz254/,
check254.py); local lineage in
~/workspace/.verify-tmp/aesir254.

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
position's cumulative total (AES-NUM-251) — the
agreement instances still uncounted after that
position, ending at 0. The CUMULATIVE REMAINING
after a position is the running total of the
remaining values over positions 1 up to and
including that position — 70 after position 8. The
GAP at a gap position 1–7 is the next act's offset
minus this act's offset; gap agreement means the
A gap equals the B gap at that position; the GAP
REMAINING at a gap position is the gap total 3
minus the gap cumulative agreement count after
that gap position (per AES-NUM-251); the GAP
CUMULATIVE REMAINING after a gap position is the
running total of the gap remaining values over
gap positions 1 up to and including that gap
position.

## (i) The closing-run cumulative remaining-count sequence in full

The running total of the AES-NUM-251
remaining values, stated position by
position (each printed set equals the AES-NUM-247
printed set, each printed count equals the
AES-NUM-248 printed count, each printed
cumulative total equals the AES-NUM-249 printed
cumulative, each printed difference equals the
AES-NUM-250 printed difference, each printed
remaining equals the AES-NUM-251 printed
remaining, each printed cumulative remaining
equals its expected value, and cumulative minus
previous cumulative equals remaining, printed
tests True for all eight):

- Position 1 (A rank 741 / B rank 743): set [RUN-102] — count 1 of 6 — cumulative 1 — difference 0 — remaining 15 — cumulative remaining 15.
- Position 2 (A rank 742 / B rank 744): set [CHANNEL, RUN-102] — count 2 of 6 — cumulative 3 — difference 1 — remaining 13 — cumulative remaining 28.
- Position 3 (A rank 743 / B rank 745): set [RUN-102] — count 1 of 6 — cumulative 4 — difference 3 — remaining 12 — cumulative remaining 40.
- Position 4 (A rank 744 / B rank 746): set [] — count 0 of 6 — cumulative 4 — difference 4 — remaining 12 — cumulative remaining 52.
- Position 5 (A rank 745 / B rank 747): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 7 — difference 4 — remaining 9 — cumulative remaining 61.
- Position 6 (A rank 746 / B rank 748): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 10 — difference 7 — remaining 6 — cumulative remaining 67.
- Position 7 (A rank 747 / B rank 749): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 13 — difference 10 — remaining 3 — cumulative remaining 70.
- Position 8 (A rank 748 / B rank 750): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 16 — difference 13 — remaining 0 — cumulative remaining 70.

Cumulative remaining sequence:
[15, 28, 40, 52, 61, 67, 70, 70] — equals the
expected sequence (printed test True); the last
cumulative remaining is 70.

## (ii) The distinct cumulative remaining totals in full

Distinct totals, in order of first appearance,
with the positions at which each occurs and its
count stated exactly (counts sum to 8, printed
test True):

- 15: position 1 — count 1.
- 28: position 2 — count 1.
- 40: position 3 — count 1.
- 52: position 4 — count 1.
- 61: position 5 — count 1.
- 67: position 6 — count 1.
- 70: positions 7, 8 — count 2.

Seven distinct cumulative remaining
totals; the total 70 repeats once — stated as printed
arithmetic only (the final remaining value is 0,
so the last running total does not rise), no
mechanism claimed.

## (iii) The gap cumulative remaining-count sequence in full

The running total of the AES-NUM-251 gap
remaining values, stated gap position by
gap position (each printed gap result equals the
AES-NUM-247 printed result and each printed gap
remaining equals the AES-NUM-251 printed
value, printed tests True for all seven):
gap position 1 A 512 against B 712 — disagree,
gap cumulative 0, gap remaining 3,
gap cumulative remaining 3; gap position 2
A 512 against B 26624 — disagree, gap cumulative
0, gap remaining 3, gap cumulative
remaining 6; gap position 3 A 512 against
B 14848 — disagree, gap cumulative 0, gap
remaining 3, gap cumulative
remaining 9; gap position 4 A 512 against
B 33280 — disagree, gap cumulative 0, gap
remaining 3, gap cumulative
remaining 12; gap position 5 A 512 against
B 512 — agree, gap cumulative 1, gap remaining
2, gap cumulative remaining 14; gap
position 6 A 512 against B 512 — agree, gap
cumulative 2, gap remaining 1, gap cumulative
remaining 15; gap position 7 A 512
against B 512 — agree, gap cumulative 3, gap
remaining 0, gap cumulative
remaining 15.

Gap cumulative remaining sequence:
[3, 6, 9, 12, 14, 15, 15] — equals the expected
sequence (printed test True), ends at 15, with
agreeing positions 5, 6, 7 (count 3), equal to
AES-NUM-245; the printed gap cumulative sequence
equals AES-NUM-249, and the printed gap
remaining sequence equals AES-NUM-251.

Contract tests: the printed cumulative
remaining sequence equals
(15, 28, 40, 52, 61, 67, 70, 70) — True; the
distinct cumulative totals' counts sum to 8 —
True; each cumulative total minus the previous
cumulative total equals that position's
AES-NUM-251 remaining value — True for
all eight; the last cumulative total equals
70 — True; the gap cumulative remaining
sequence equals (3, 6, 9, 12, 14, 15, 15) and
ends at 15 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
