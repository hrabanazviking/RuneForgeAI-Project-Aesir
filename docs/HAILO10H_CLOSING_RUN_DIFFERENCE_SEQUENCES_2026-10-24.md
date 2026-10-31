# The closing-run cumulative-minus-count difference sequence, the distinct differences, and the gap cumulative difference sequence (AES-NUM-250)

Slice 4.250, worked under `docs/TASK_CONTRACT_4.250.md`
(contract published in the 4.249 closing commit @
fe7d76f6). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section250.txt).

## Run and closing record

hef250.py is the verified hef249 base plus
arms250: hef249.py sha256
`a6a06fa4bcad84ac27bb3e175fc0aba185be230e762385c30f33a29468e03b69`
(2,093,508 B) on both the VM and the device.
arms250 sha256
`7bef237dbe329adcda48cc213b59061f779e0c3fee3b6a520de84e9a264798aa`
(16,574 B); hef250.py sha256
`68f50056e71b600e5d2ac94f7583236dec4e60a84957f6555fa219c3169da268`
(2,110,082 B) on both the VM and the device.
Crossing, stated exactly: arms250 was gzipped at
gzip -9 (sha256
`2c011e8270c55b52bd2617c13a8fba417ae0a6ae7251db42fb708a54808b41f8`,
4,532 B) and split into thirteen 373 B parts (last
56 B); each part was written as its own file with
its own sha256 gate — all thirteen verified
on-device on the first attempt; no byte was ever
accepted unverified. The assembled gzip, arms and
hef250 shas == VM on-device; hef250 assembled
on-device from hef249.py + arms250.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef250/h250 child; exactly ONE bounded host-side
child ran in detached tmux (session h250, launched
2026-10-31 ~01:06 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef250.exit), err empty, and DONE250 as its last
line. Output hef250.out 58,674 lines /
10,640,572 B sha256
`9eafb63ff6c55be526551c7bffe2c037a897b078f3c1d1b6734ac98a927b6310`;
prefix against hef249.out: the first 58,631
lines differ from hef249.out in exactly TWO lines
(lines 41611 and 42872, frozenset element order
only — the AES-NUM-150 variance, each verified by
same-sorted-characters comparison), hef250.out
adding exactly its own 43 section lines (9,582 B,
sha256
`660e14218475c39d87621c0bad20118246167078164104137f139a41cad48578`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef250.out, hef250.py, arms250.py,
section250.txt, hef250.exit, run250.sh, gz250/,
check250.py); local lineage in
~/workspace/.verify-tmp/aesir250.

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
(AES-NUM-249). The DIFFERENCE at a position is
that position's cumulative agreement count minus
that position's own agreement count — equivalently
the cumulative total before that position, 0 at
position 1. The GAP at a gap position 1–7 is the
next act's offset minus this act's offset; gap
agreement means the A gap equals the B gap at
that position; the GAP CUMULATIVE DIFFERENCE at
a gap position is that position's gap cumulative
agreement count minus the previous gap cumulative
count (the count before gap position 1 taken as
0) — the per-gap increment, 1 where the gap
agrees and 0 where it disagrees.

## (i) The closing-run cumulative-minus-count difference sequence in full

The cumulative totals of AES-NUM-249 minus each
position's own AES-NUM-248 agreement count, stated
position by position (each printed set equals the
AES-NUM-247 printed set, each printed count equals
the AES-NUM-248 printed count, each printed
cumulative total equals the AES-NUM-249 printed
cumulative, each printed difference equals its
expected value, and difference plus count equals
cumulative, printed tests True for all eight):

- Position 1 (A rank 741 / B rank 743): set [RUN-102] — count 1 of 6 — cumulative 1 — difference 0.
- Position 2 (A rank 742 / B rank 744): set [CHANNEL, RUN-102] — count 2 of 6 — cumulative 3 — difference 1.
- Position 3 (A rank 743 / B rank 745): set [RUN-102] — count 1 of 6 — cumulative 4 — difference 3.
- Position 4 (A rank 744 / B rank 746): set [] — count 0 of 6 — cumulative 4 — difference 4.
- Position 5 (A rank 745 / B rank 747): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 7 — difference 4.
- Position 6 (A rank 746 / B rank 748): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 10 — difference 7.
- Position 7 (A rank 747 / B rank 749): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 13 — difference 10.
- Position 8 (A rank 748 / B rank 750): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 16 — difference 13.

Difference sequence: [0, 1, 3, 4, 4, 7, 10, 13] —
equals the expected sequence (printed test True);
the first difference is 0, and the sequence is
exactly the AES-NUM-249 cumulative totals shifted
by one position with 0 prepended.

## (ii) The distinct differences in full

Distinct values, in order of first appearance,
with the positions at which each occurs and its
count stated exactly (counts sum to 8, printed
test True):

- 0: position 1 — count 1.
- 1: position 2 — count 1.
- 3: position 3 — count 1.
- 4: positions 4, 5 — count 2.
- 7: position 6 — count 1.
- 10: position 7 — count 1.
- 13: position 8 — count 1.

Seven distinct differences; the largest
difference is 13 at the last position, the
cumulative total before the final position's own
count of 3 brings the total to 16.

## (iii) The gap cumulative difference sequence in full

The per-gap increments of AES-NUM-249's gap
cumulative counts, stated gap position by gap
position (each printed gap result equals the
AES-NUM-247 printed result, printed test True
for all seven): gap position 1 A 512 against
B 712 — disagree, gap cumulative 0, difference 0;
gap position 2 A 512 against B 26624 — disagree,
gap cumulative 0, difference 0; gap position 3
A 512 against B 14848 — disagree, gap cumulative
0, difference 0; gap position 4 A 512 against
B 33280 — disagree, gap cumulative 0,
difference 0; gap position 5 A 512 against B 512
— agree, gap cumulative 1, difference 1; gap
position 6 A 512 against B 512 — agree, gap
cumulative 2, difference 1; gap position 7
A 512 against B 512 — agree, gap cumulative 3,
difference 1.

Gap cumulative difference sequence: [0, 0, 0, 0,
1, 1, 1] — equals the expected sequence (printed
test True), sums to 3, and is exactly the
AES-NUM-247 gap-agreement sequence read as 1/0,
with agreeing positions 5, 6, 7 (count 3), equal
to AES-NUM-245.

Contract tests: the printed difference sequence
equals (0, 1, 3, 4, 4, 7, 10, 13) — True; the
distinct differences' counts sum to 8 — True;
each difference plus its position's agreement
count equals that position's cumulative total —
True for all eight; the gap difference sequence
equals (0, 0, 0, 0, 1, 1, 1) and sums to 3 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
