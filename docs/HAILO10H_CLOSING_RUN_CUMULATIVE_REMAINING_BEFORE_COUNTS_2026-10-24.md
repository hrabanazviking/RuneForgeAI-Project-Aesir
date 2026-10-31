# The closing-run cumulative remaining-before-count sequence, the distinct cumulative remaining-before totals, and the gap cumulative remaining-before-count sequence (AES-NUM-253)

Slice 4.253, worked under `docs/TASK_CONTRACT_4.253.md`
(contract published in the 4.252 closing commit @
29bb3269). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section253.txt).

## Run and closing record

hef253.py is the verified hef252 base plus
arms253: hef252.py sha256
`32e8e55b7641668619622bd7ba392e6f78b6f0a1ac8d3376b8b867ffa6bb97ee`
(2,144,527 B) on both the VM and the device.
arms253 sha256
`76815df1cc28d4cc0c02f7d541bb66188f7660865f5f2051f2bbce37aa72331f`
(19,313 B); hef253.py sha256
`831909bb8401c1df38c0ea6fa8011efded8df1a742bd3d5bdbeba3c27e656e7b`
(2,163,840 B) on both the VM and the device.
Crossing, stated exactly: arms253 was gzipped at
gzip -9 (sha256
`2f791f8905c797b027351776f29b171d5ca7494728a2eae3daecaf9ca0d84bfb`,
5,015 B) and split into fourteen 373 B parts (last
166 B). The first ten parts were written and
sha-verified on-device in the original claim run;
that run then stalled mid-transfer and the
continuity worker resumed the slice. The remaining
four parts landed in the resume run: p_ak, p_al and
p_am each via 186 B sub-chunk writes closed by
their whole-part sha256 gates (7268ddf5…, 9a19b6b2…,
4afe10bb…), and p_an directly with its sha256 gate
(ff46a5b6…). One direct 373 B attempt at p_ak was
sha-rejected by the device and discarded
uncommitted, as designed; no byte was ever
accepted unverified. The assembled gzip, arms and
hef253 shas == VM on-device; hef253 assembled
on-device from hef252.py + arms253.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef253/h253 child; exactly ONE bounded host-side
child ran in detached tmux (session h253, launched
2026-10-31 02:36:52 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef253.exit), err empty, and DONE253 as its last
line. Output hef253.out 58,804 lines /
10,676,658 B sha256
`3411217de8aee0cba9dd674e14e1c049d12081a599c7085ee5e72533b4f1951b`;
prefix against hef252.out: the first 58,760
lines differ from hef252.out in exactly TWO lines
(lines 41611 and 42872, frozenset element order
only — the AES-NUM-150 variance, each verified by
same-sorted-characters comparison), hef253.out
adding exactly its own 44 section lines (14,482 B,
sha256
`0fac910edcff32d247c6be4e0c9c769693a99ccdf0e00a342902a02ef895e1eb`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef253.out, hef253.py, arms253.py,
section253.txt, hef253.exit, run253.sh, gz253/,
check253.py); local lineage in
~/workspace/.verify-tmp/aesir253.

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
position's difference (AES-NUM-252). The
CUMULATIVE REMAINING-BEFORE after a position is
the running total of the remaining-before values
over positions 1 up to and including that
position — 86 after position 8. The GAP at a
gap position 1–7 is the next act's offset minus
this act's offset; gap agreement means the A gap
equals the B gap at that position; the GAP
CUMULATIVE REMAINING-BEFORE after a gap position
is the running total of the gap remaining-before
values (the gap total 3 minus the gap cumulative
count before that gap position, per AES-NUM-252)
over gap positions 1 up to and including that
gap position.

## (i) The closing-run cumulative remaining-before-count sequence in full

The running total of the AES-NUM-252
remaining-before values, stated position by
position (each printed set equals the AES-NUM-247
printed set, each printed count equals the
AES-NUM-248 printed count, each printed
cumulative total equals the AES-NUM-249 printed
cumulative, each printed difference equals the
AES-NUM-250 printed difference, each printed
remaining equals the AES-NUM-251 printed
remaining, each printed remaining-before equals
the AES-NUM-252 printed remaining-before, each
printed cumulative remaining-before equals its
expected value, and cumulative minus previous
cumulative equals remaining-before, printed
tests True for all eight):

- Position 1 (A rank 741 / B rank 743): set [RUN-102] — count 1 of 6 — cumulative 1 — difference 0 — remaining 15 — remaining-before 16 — cumulative remaining-before 16.
- Position 2 (A rank 742 / B rank 744): set [CHANNEL, RUN-102] — count 2 of 6 — cumulative 3 — difference 1 — remaining 13 — remaining-before 15 — cumulative remaining-before 31.
- Position 3 (A rank 743 / B rank 745): set [RUN-102] — count 1 of 6 — cumulative 4 — difference 3 — remaining 12 — remaining-before 13 — cumulative remaining-before 44.
- Position 4 (A rank 744 / B rank 746): set [] — count 0 of 6 — cumulative 4 — difference 4 — remaining 12 — remaining-before 12 — cumulative remaining-before 56.
- Position 5 (A rank 745 / B rank 747): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 7 — difference 4 — remaining 9 — remaining-before 12 — cumulative remaining-before 68.
- Position 6 (A rank 746 / B rank 748): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 10 — difference 7 — remaining 6 — remaining-before 9 — cumulative remaining-before 77.
- Position 7 (A rank 747 / B rank 749): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 13 — difference 10 — remaining 3 — remaining-before 6 — cumulative remaining-before 83.
- Position 8 (A rank 748 / B rank 750): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 16 — difference 13 — remaining 0 — remaining-before 3 — cumulative remaining-before 86.

Cumulative remaining-before sequence:
[16, 31, 44, 56, 68, 77, 83, 86] — equals the
expected sequence (printed test True); the last
cumulative remaining-before is 86.

## (ii) The distinct cumulative remaining-before totals in full

Distinct totals, in order of first appearance,
with the positions at which each occurs and its
count stated exactly (counts sum to 8, printed
test True):

- 16: position 1 — count 1.
- 31: position 2 — count 1.
- 44: position 3 — count 1.
- 56: position 4 — count 1.
- 68: position 5 — count 1.
- 77: position 6 — count 1.
- 83: position 7 — count 1.
- 86: position 8 — count 1.

Eight distinct cumulative remaining-before
totals; no total repeats — stated as printed
arithmetic only (every remaining-before value is
positive, so each running total rises), no
mechanism claimed.

## (iii) The gap cumulative remaining-before-count sequence in full

The running total of the AES-NUM-252 gap
remaining-before values, stated gap position by
gap position (each printed gap result equals the
AES-NUM-247 printed result and each printed gap
remaining-before equals the AES-NUM-252 printed
value, printed tests True for all seven):
gap position 1 A 512 against B 712 — disagree,
gap cumulative 0, gap difference 0, gap
cumulative before 0, gap remaining-before 3,
gap cumulative remaining-before 3; gap position 2
A 512 against B 26624 — disagree, gap cumulative
0, gap difference 0, gap cumulative before 0,
gap remaining-before 3, gap cumulative
remaining-before 6; gap position 3 A 512 against
B 14848 — disagree, gap cumulative 0, gap
difference 0, gap cumulative before 0, gap
remaining-before 3, gap cumulative
remaining-before 9; gap position 4 A 512 against
B 33280 — disagree, gap cumulative 0, gap
difference 0, gap cumulative before 0, gap
remaining-before 3, gap cumulative
remaining-before 12; gap position 5 A 512 against
B 512 — agree, gap cumulative 1, gap difference
1, gap cumulative before 0, gap remaining-before
3, gap cumulative remaining-before 15; gap
position 6 A 512 against B 512 — agree, gap
cumulative 2, gap difference 1, gap cumulative
before 1, gap remaining-before 2, gap cumulative
remaining-before 17; gap position 7 A 512
against B 512 — agree, gap cumulative 3, gap
difference 1, gap cumulative before 2, gap
remaining-before 1, gap cumulative
remaining-before 18.

Gap cumulative remaining-before sequence:
[3, 6, 9, 12, 15, 17, 18] — equals the expected
sequence (printed test True), ends at 18, with
agreeing positions 5, 6, 7 (count 3), equal to
AES-NUM-245; the printed gap cumulative sequence
equals AES-NUM-249, the printed gap cumulative
difference sequence equals AES-NUM-250, and the
printed gap remaining-before sequence equals
AES-NUM-252.

Contract tests: the printed cumulative
remaining-before sequence equals
(16, 31, 44, 56, 68, 77, 83, 86) — True; the
distinct cumulative totals' counts sum to 8 —
True; each cumulative total minus the previous
cumulative total equals that position's
AES-NUM-252 remaining-before value — True for
all eight; the last cumulative total equals
86 — True; the gap cumulative remaining-before
sequence equals (3, 6, 9, 12, 15, 17, 18) and
ends at 18 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
