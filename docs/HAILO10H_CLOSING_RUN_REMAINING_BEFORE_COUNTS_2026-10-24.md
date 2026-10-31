# The closing-run remaining-before-count sequence, the distinct remaining-before values, and the gap remaining-before-count sequence (AES-NUM-252)

Slice 4.252, worked under `docs/TASK_CONTRACT_4.252.md`
(contract published in the 4.251 closing commit @
53567ff8). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section252.txt).

## Run and closing record

hef252.py is the verified hef251 base plus
arms252: hef251.py sha256
`2ea8dfe5c2acf4adf93a2a9b187ffaa4f91eded50fbd36124fb0043b4a7750ec`
(2,126,399 B) on both the VM and the device.
arms252 sha256
`6b29f73e1d33f954d78cebc4d9984c9d8c63ea2570db6c63c5680edd62618f28`
(18,128 B); hef252.py sha256
`32e8e55b7641668619622bd7ba392e6f78b6f0a1ac8d3376b8b867ffa6bb97ee`
(2,144,527 B) on both the VM and the device.
Crossing, stated exactly: arms252 was gzipped at
gzip -9 (sha256
`9b39f114c1023e4e8a49b67bc908f53ca3bcaf6eb4501ea90a94232ba8f615d5`,
4,844 B) and split into thirteen 373 B parts (last
368 B); each part was written as its own file with
its own sha256 gate — all thirteen verified
on-device on the first attempt; no byte was ever
accepted unverified. The assembled gzip, arms and
hef252 shas == VM on-device; hef252 assembled
on-device from hef251.py + arms252.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef252/h252 child; exactly ONE bounded host-side
child ran in detached tmux (session h252, launched
2026-10-31 01:56:44 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef252.exit), err empty, and DONE252 as its last
line. Output hef252.out 58,760 lines /
10,662,176 B sha256
`b44f3a3a459e87497c79008ac6eb705f1bbc6c9d6473be6480b124a2c31d6717`;
prefix against hef251.out: the first 58,717
lines differ from hef251.out in exactly ONE line
(line 41611, frozenset element order only — the
AES-NUM-150 variance, verified by
same-sorted-characters comparison; the second
variance line seen in earlier runs, 42872, did
not differ this run), hef252.out adding exactly
its own 43 section lines (12,395 B, sha256
`927162f1a421362e992204948b1f7d49c5bdb6a3150e0eaa3a3a58516c18655a`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef252.out, hef252.py, arms252.py,
section252.txt, hef252.exit, run252.sh, gz252/,
check252.py); local lineage in
~/workspace/.verify-tmp/aesir252.

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
REMAINING-BEFORE at a position is 16 minus that
position's difference — equivalently that
position's AES-NUM-251 remaining plus its own
agreement count — the agreeing family-instances
still to come at and after that position, before
it is counted, 16 at position 1. The GAP at a
gap position 1–7 is the next act's offset minus
this act's offset; gap agreement means the A gap
equals the B gap at that position; the GAP
REMAINING-BEFORE at a gap position is the gap
total 3 minus the gap cumulative count before
that gap position (the AES-NUM-249 gap cumulative
count minus that gap position's AES-NUM-250 gap
cumulative difference).

## (i) The closing-run remaining-before-count sequence in full

The total 16 minus each position's AES-NUM-250
difference, stated position by position
(each printed set equals the AES-NUM-247 printed
set, each printed count equals the AES-NUM-248
printed count, each printed cumulative total
equals the AES-NUM-249 printed cumulative, each
printed difference equals the AES-NUM-250 printed
difference, each printed remaining equals the
AES-NUM-251 printed remaining, each printed
remaining-before equals its expected value, and
remaining-before minus count equals remaining,
printed tests True for all eight):

- Position 1 (A rank 741 / B rank 743): set [RUN-102] — count 1 of 6 — cumulative 1 — difference 0 — remaining 15 — remaining-before 16.
- Position 2 (A rank 742 / B rank 744): set [CHANNEL, RUN-102] — count 2 of 6 — cumulative 3 — difference 1 — remaining 13 — remaining-before 15.
- Position 3 (A rank 743 / B rank 745): set [RUN-102] — count 1 of 6 — cumulative 4 — difference 3 — remaining 12 — remaining-before 13.
- Position 4 (A rank 744 / B rank 746): set [] — count 0 of 6 — cumulative 4 — difference 4 — remaining 12 — remaining-before 12.
- Position 5 (A rank 745 / B rank 747): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 7 — difference 4 — remaining 9 — remaining-before 12.
- Position 6 (A rank 746 / B rank 748): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 10 — difference 7 — remaining 6 — remaining-before 9.
- Position 7 (A rank 747 / B rank 749): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 13 — difference 10 — remaining 3 — remaining-before 6.
- Position 8 (A rank 748 / B rank 750): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 16 — difference 13 — remaining 0 — remaining-before 3.

Remaining-before sequence: [16, 15, 13, 12, 12, 9, 6, 3] —
equals the expected sequence (printed test True);
the first remaining-before is 16, and the sequence
is exactly the AES-NUM-250 differences subtracted
from 16, position by position.

## (ii) The distinct remaining-before values in full

Distinct values, in order of first appearance,
with the positions at which each occurs and its
count stated exactly (counts sum to 8, printed
test True):

- 16: position 1 — count 1.
- 15: position 2 — count 1.
- 13: position 3 — count 1.
- 12: positions 4, 5 — count 2.
- 9: position 6 — count 1.
- 6: position 7 — count 1.
- 3: position 8 — count 1.

Seven distinct remaining-before values; the only
repeated remaining-before value is 12, at the two
positions whose difference does not move
(positions 4 and 5, where position 5's difference
equals position 4's difference because position
5's cumulative rise is exactly its own count
added after position 4's zero-count standstill —
stated as printed arithmetic only, no mechanism
claimed).

## (iii) The gap remaining-before-count sequence in full

The gap total 3 minus the gap cumulative count
before each gap position, stated gap position by
gap position (each printed gap result equals the
AES-NUM-247 printed result, each printed gap
cumulative count equals the AES-NUM-249 printed
gap cumulative, and each printed gap cumulative
difference equals the AES-NUM-250 printed gap
difference, printed tests True for all seven):
gap position 1 A 512 against B 712 — disagree,
gap cumulative 0, gap difference 0, gap cumulative
before 0, remaining-before 3; gap position 2
A 512 against B 26624 — disagree, gap cumulative
0, gap difference 0, gap cumulative before 0,
remaining-before 3; gap position 3 A 512 against
B 14848 — disagree, gap cumulative 0, gap
difference 0, gap cumulative before 0,
remaining-before 3; gap position 4 A 512 against
B 33280 — disagree, gap cumulative 0, gap
difference 0, gap cumulative before 0,
remaining-before 3; gap position 5 A 512 against
B 512 — agree, gap cumulative 1, gap difference
1, gap cumulative before 0, remaining-before 3;
gap position 6 A 512 against B 512 — agree, gap
cumulative 2, gap difference 1, gap cumulative
before 1, remaining-before 2; gap position 7
A 512 against B 512 — agree, gap cumulative 3,
gap difference 1, gap cumulative before 2,
remaining-before 1.

Gap remaining-before sequence: [3, 3, 3, 3, 3, 2, 1] —
equals the expected sequence (printed test True),
starts at 3, with agreeing positions 5, 6, 7
(count 3), equal to AES-NUM-245.

Contract tests: the printed remaining-before
sequence equals (16, 15, 13, 12, 12, 9, 6, 3) —
True; the distinct remaining-before counts sum
to 8 — True; each remaining-before minus its
position's agreement count equals that position's
AES-NUM-251 remaining — True for all eight; the
first remaining-before equals 16 — True; the gap
remaining-before sequence equals
(3, 3, 3, 3, 3, 2, 1) and starts at 3 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
