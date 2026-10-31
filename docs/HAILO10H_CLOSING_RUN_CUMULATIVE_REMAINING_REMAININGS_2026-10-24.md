# The closing-run cumulative-remaining remaining-count sequence, the distinct cumulative-remaining remainings, and the gap cumulative-remaining remaining-count sequence (AES-NUM-256)

Slice 4.256, worked under `docs/TASK_CONTRACT_4.256.md`
(contract published in the 4.255 closing commit @
5468e72a). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section256.txt).

## Run and closing record

hef256.py is the verified hef255r base plus
arms256: hef255r.py sha256
`de15b9765100be64c4b1847345812d75d090fcf3a157d6b1d17c15afd4afa26c`
(2,201,940 B) on both the VM and the device.
arms256 sha256
`def0a5cbecc5afc02b2286c5d127360e5e76afc5a773883a254c5e2cb83b5f2b`
(19,337 B); hef256.py sha256
`d83740dac5df5af49666aefb6455a29aa0fd533a49dc74be13ce04ed01c0a60e`
(2,221,277 B) on both the VM and the device.
Crossing, stated exactly: arms256 was gzipped at
gzip -9 (sha256
`cb56e3e235422aeba5b38547f1066e7ea2daa5f2a97b5e6dec9da42d5d05f288`,
5,002 B) and split into fourteen 373 B parts (last
153 B), each part written as its own file with its
own sha256 gate — all fourteen verified on-device
on the first attempt; no byte accepted unverified.
The assembled gzip, arms and hef256 shas == VM
on-device; hef256 assembled on-device from
hef255r.py + arms256.py, sha == VM, py_compile OK.

LAUNCH: pre-launch tmux/ps check found no
hef256/h256 child; exactly ONE bounded host-side
child ran in detached tmux (session h256, launched
2026-10-31 03:50:30 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef256.exit), err empty, and DONE256 as its last
line. Output hef256.out 58,934 lines / 10,719,851 B
sha256
`30693e4914d67fb9fbe5677a28cfc74a657493f0204ad939066c8e6f6be63e28`;
prefix against hef255r.out: the first 58,891 lines
differ from hef255r.out in exactly TWO lines (lines
41611 and 42872, frozenset element order only — the
AES-NUM-150 variance, each verified by
same-sorted-characters comparison via check256.py
sha256
`a43ba9c50d01439481a47928d7e68ce1cd7213ee14a77bbce4a5ef57b26e26de`),
hef256.out adding exactly its own 43 section lines
(15,331 B, sha256
`382a2c7db132173972f2769c40b728f16c14a059020193f43a62049477b6f1ae`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef256.out, hef256.py, arms256.py,
section256.txt, hef256.exit, hef256.err, run256.sh,
gz256/, check256.py); local lineage in
~/workspace/.verify-tmp/aesir256.

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
after that position. The GAP at a gap position
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
remaining total.

## (i) The closing-run cumulative-remaining remaining-count sequence in full

At each position, 70 minus that position's
AES-NUM-254 cumulative remaining total, stated
position by position (each printed set equals the
AES-NUM-247 printed set, each printed count equals
the AES-NUM-248 printed count, each printed
cumulative total equals the AES-NUM-249 printed
cumulative, each printed difference equals the
AES-NUM-250 printed difference, each printed
remaining equals the AES-NUM-251 printed
remaining, each printed cumulative remaining
equals the AES-NUM-254 printed value, each printed
cumulative-remaining remaining equals its expected
value, and remaining-after plus cumulative
remaining equals 70, printed tests True for all
eight):

- Position 1 (A rank 741 / B rank 743): set [RUN-102] — count 1 of 6 — cumulative 1 — difference 0 — remaining 15 — cumulative remaining 15 — cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): set [CHANNEL, RUN-102] — count 2 of 6 — cumulative 3 — difference 1 — remaining 13 — cumulative remaining 28 — cumulative-remaining remaining 42.
- Position 3 (A rank 743 / B rank 745): set [RUN-102] — count 1 of 6 — cumulative 4 — difference 3 — remaining 12 — cumulative remaining 40 — cumulative-remaining remaining 30.
- Position 4 (A rank 744 / B rank 746): set [] — count 0 of 6 — cumulative 4 — difference 4 — remaining 12 — cumulative remaining 52 — cumulative-remaining remaining 18.
- Position 5 (A rank 745 / B rank 747): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 7 — difference 4 — remaining 9 — cumulative remaining 61 — cumulative-remaining remaining 9.
- Position 6 (A rank 746 / B rank 748): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 10 — difference 7 — remaining 6 — cumulative remaining 67 — cumulative-remaining remaining 3.
- Position 7 (A rank 747 / B rank 749): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 13 — difference 10 — remaining 3 — cumulative remaining 70 — cumulative-remaining remaining 0.
- Position 8 (A rank 748 / B rank 750): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 16 — difference 13 — remaining 0 — cumulative remaining 70 — cumulative-remaining remaining 0.

Cumulative-remaining remaining sequence:
[55, 42, 30, 18, 9, 3, 0, 0] — equals the expected
sequence (printed test True); the last remaining
is 0.

## (ii) The distinct cumulative-remaining remainings in full

Distinct remainings, in order of first appearance,
with the positions at which each occurs and its
count stated exactly (counts sum to 8, printed
test True):

- 55: position 1 — count 1.
- 42: position 2 — count 1.
- 30: position 3 — count 1.
- 18: position 4 — count 1.
- 9: position 5 — count 1.
- 3: position 6 — count 1.
- 0: positions 7, 8 — count 2.

Seven distinct remainings; only 0 repeats, at the
last two positions — stated as printed arithmetic
only, no mechanism claimed.

## (iii) The gap cumulative-remaining remaining-count sequence in full

At each gap position, 15 minus that gap position's
AES-NUM-254 gap cumulative remaining total, stated
gap position by gap position (each printed gap
result equals the AES-NUM-247 printed result, each
printed gap remaining equals the AES-NUM-251
printed value, each printed gap cumulative
remaining equals the AES-NUM-254 printed value,
each printed gap remaining-after equals its
expected value, and remaining-after plus gap
cumulative remaining equals 15, printed tests True
for all seven): gap position 1 A 512 against B 712 —
disagree, gap cumulative 0, gap remaining 3, gap
cumulative remaining 3, gap remaining-after 12; gap
position 2 A 512 against B 26624 — disagree, gap
cumulative 0, gap remaining 3, gap cumulative
remaining 6, gap remaining-after 9; gap position 3
A 512 against B 14848 — disagree, gap cumulative
0, gap remaining 3, gap cumulative remaining 9,
gap remaining-after 6; gap position 4 A 512 against
B 33280 — disagree, gap cumulative 0, gap
remaining 3, gap cumulative remaining 12, gap
remaining-after 3; gap position 5 A 512 against
B 512 — agree, gap cumulative 1, gap remaining 2,
gap cumulative remaining 14, gap remaining-after 1;
gap position 6 A 512 against B 512 — agree, gap
cumulative 2, gap remaining 1, gap cumulative
remaining 15, gap remaining-after 0; gap position 7
A 512 against B 512 — agree, gap cumulative 3, gap
remaining 0, gap cumulative remaining 15, gap
remaining-after 0.

Gap cumulative-remaining remaining sequence:
[12, 9, 6, 3, 1, 0, 0] — equals the expected
sequence (printed test True), ends at 0, with
agreeing positions 5, 6, 7 (count 3), equal to
AES-NUM-245; the printed gap cumulative remaining
sequence equals AES-NUM-254, and the printed gap
remaining sequence equals AES-NUM-251.

Contract tests: the printed remaining sequence
equals (55, 42, 30, 18, 9, 3, 0, 0) — True; the
distinct remainings' counts sum to 8 — True; each
remaining plus that position's cumulative remaining
total equals 70 — True for all eight; the last
remaining equals 0 — True; the gap remaining
sequence equals (12, 9, 6, 3, 1, 0, 0) and ends
at 0 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
