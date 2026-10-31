# The closing-run remaining agreement-count sequence, the distinct remainings, and the gap remaining agreement-count sequence (AES-NUM-251)

Slice 4.251, worked under `docs/TASK_CONTRACT_4.251.md`
(contract published in the 4.250 closing commit @
c3b3c12a). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section251.txt).

## Run and closing record

hef251.py is the verified hef250 base plus
arms251: hef250.py sha256
`68f50056e71b600e5d2ac94f7583236dec4e60a84957f6555fa219c3169da268`
(2,110,082 B) on both the VM and the device.
arms251 sha256
`fe553451f82d7816ae4da7e063bb909ddd1672c84df4c33ff6949f8c190e6139`
(16,317 B); hef251.py sha256
`2ea8dfe5c2acf4adf93a2a9b187ffaa4f91eded50fbd36124fb0043b4a7750ec`
(2,126,399 B) on both the VM and the device.
Crossing, stated exactly: arms251 was gzipped at
gzip -9 (sha256
`dfbe80ca09c7f83d74c5a3941782c085cf0a32f9cf3d3200593a803b6f8472d5`,
4,491 B) and split into thirteen 373 B parts (last
15 B); each part was written as its own file with
its own sha256 gate — all thirteen verified
on-device on the first attempt; no byte was ever
accepted unverified. The assembled gzip, arms and
hef251 shas == VM on-device; hef251 assembled
on-device from hef250.py + arms251.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef251/h251 child; exactly ONE bounded host-side
child ran in detached tmux (session h251, launched
2026-10-31 01:39:23 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef251.exit), err empty, and DONE251 as its last
line. Output hef251.out 58,717 lines /
10,649,781 B sha256
`725b2aa3b3442c7cf2d5788adc2289d1def4bf41e05956933f60cbda3e8d786d`;
prefix against hef250.out: the first 58,674
lines differ from hef250.out in exactly ONE line
(line 41611, frozenset element order only — the
AES-NUM-150 variance, verified by
same-sorted-characters comparison; the second
variance line seen in earlier runs, 42872, did
not differ this run), hef251.out adding exactly
its own 43 section lines (9,209 B, sha256
`b8d18eebd950146a13a29a0d6a36fae0041d9b0ae14f62b51e159cc4d95cb628`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef251.out, hef251.py, arms251.py,
section251.txt, hef251.exit, run251.sh, gz251/,
check251.py); local lineage in
~/workspace/.verify-tmp/aesir251.

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
REMAINING at a position is 16 minus that
position's cumulative agreement count — the
agreeing family-instances still to come after
that position is counted, 0 at position 8. The
GAP at a gap position 1–7 is the next act's
offset minus this act's offset; gap agreement
means the A gap equals the B gap at that
position; the GAP REMAINING at a gap position is
the gap total 3 minus that position's gap
cumulative agreement count.

## (i) The closing-run remaining agreement-count sequence in full

The total 16 minus each position's AES-NUM-249
cumulative total, stated position by position
(each printed set equals the AES-NUM-247 printed
set, each printed count equals the AES-NUM-248
printed count, each printed cumulative total
equals the AES-NUM-249 printed cumulative, each
printed remaining equals its expected value, and
remaining plus cumulative equals 16, printed
tests True for all eight):

- Position 1 (A rank 741 / B rank 743): set [RUN-102] — count 1 of 6 — cumulative 1 — remaining 15.
- Position 2 (A rank 742 / B rank 744): set [CHANNEL, RUN-102] — count 2 of 6 — cumulative 3 — remaining 13.
- Position 3 (A rank 743 / B rank 745): set [RUN-102] — count 1 of 6 — cumulative 4 — remaining 12.
- Position 4 (A rank 744 / B rank 746): set [] — count 0 of 6 — cumulative 4 — remaining 12.
- Position 5 (A rank 745 / B rank 747): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 7 — remaining 9.
- Position 6 (A rank 746 / B rank 748): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 10 — remaining 6.
- Position 7 (A rank 747 / B rank 749): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 13 — remaining 3.
- Position 8 (A rank 748 / B rank 750): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 16 — remaining 0.

Remaining sequence: [15, 13, 12, 12, 9, 6, 3, 0] —
equals the expected sequence (printed test True);
the last remaining is 0, and the sequence is
exactly the AES-NUM-249 cumulative totals
subtracted from 16, position by position.

## (ii) The distinct remainings in full

Distinct values, in order of first appearance,
with the positions at which each occurs and its
count stated exactly (counts sum to 8, printed
test True):

- 15: position 1 — count 1.
- 13: position 2 — count 1.
- 12: positions 3, 4 — count 2.
- 9: position 5 — count 1.
- 6: position 6 — count 1.
- 3: position 7 — count 1.
- 0: position 8 — count 1.

Seven distinct remainings; the only repeated
remaining is 12, at the two positions whose
cumulative total does not move (positions 3
and 4, where position 4's agreement count is 0).

## (iii) The gap remaining agreement-count sequence in full

The gap total 3 minus AES-NUM-249's gap
cumulative counts, stated gap position by gap
position (each printed gap result equals the
AES-NUM-247 printed result, printed test True
for all seven): gap position 1 A 512 against
B 712 — disagree, gap cumulative 0, remaining 3;
gap position 2 A 512 against B 26624 — disagree,
gap cumulative 0, remaining 3; gap position 3
A 512 against B 14848 — disagree, gap cumulative
0, remaining 3; gap position 4 A 512 against
B 33280 — disagree, gap cumulative 0,
remaining 3; gap position 5 A 512 against B 512
— agree, gap cumulative 1, remaining 2; gap
position 6 A 512 against B 512 — agree, gap
cumulative 2, remaining 1; gap position 7
A 512 against B 512 — agree, gap cumulative 3,
remaining 0.

Gap remaining sequence: [3, 3, 3, 3, 2, 1, 0] —
equals the expected sequence (printed test True),
ends at 0, with agreeing positions 5, 6, 7
(count 3), equal to AES-NUM-245.

Contract tests: the printed remaining sequence
equals (15, 13, 12, 12, 9, 6, 3, 0) — True; the
distinct remainings' counts sum to 8 — True;
each remaining plus its position's cumulative
total equals 16 — True for all eight; the last
remaining equals 0 — True; the gap remaining
sequence equals (3, 3, 3, 3, 2, 1, 0) and ends
at 0 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
