# The closing-run cumulative-remaining-minus-remaining difference sequence, the distinct differences, and the gap cumulative-remaining difference sequence (AES-NUM-255)

Slice 4.255, worked under `docs/TASK_CONTRACT_4.255.md`
(contract published in the 4.254 closing commit @
cf1b500f). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section255r.txt; its first 34 lines are
byte-identical to the crashed first launch's
section255.txt, which was also read in full).

## Run and closing record

hef255.py is the verified hef254 base plus
arms255: hef254.py sha256
`cd757ce3a7b1931832b9b551a040281a42d8fa89b35a0ebe8154dcf6093f076c`
(2,182,118 B) on both the VM and the device.
arms255 sha256
`62966b86a5ac37d635873da4256f717f41af16ba25471f02ee5a4f01bcda4ebc`
(19,778 B); hef255.py sha256
`9b3deffc075dd3c01bd9ae36d8572aa6f4b38a86545b0bfca9a9e36600d58796`
(2,201,896 B) on both the VM and the device.
Crossing, stated exactly: arms255 was gzipped at
gzip -9 (sha256
`19789386bb34bf6ae788c842ada9d62e6d160a3bfff471996d8756366fd00b28`,
5,065 B) and split into fourteen 373 B parts (last
216 B), each part written as its own file with its
own sha256 gate — all fourteen verified on-device
on the first attempt; no byte accepted unverified.
The assembled gzip, arms and hef255 shas == VM
on-device; hef255 assembled on-device from
hef254.py + arms255.py, sha == VM, py_compile OK.

FIRST LAUNCH (closed): pre-launch tmux/ps check
found no hef255/h255 child; exactly ONE bounded
host-side child ran in detached tmux (session
h255, launched 2026-10-31 03:14:32 EDT) with the
contract corpus argv (glob order, MiniLM last),
unbuffered (`python3 -u`). It ran the full
inherited corpus walk, the controls (all EXACT),
arm (i) and arm (ii) in full, then crashed with
exit marker 1 (hef255.exit), err 1,549 B sha256
`d20320037cd3b726d956c806f6f261ae36299bdee01a213a285e1174b5ca8ce2`:
NameError in the worker-authored 'GAP POSITION'
print in sections255 — it references
expGapCumRem255 inside the gap loop, but that name
is defined after the loop in the inherited layout.
The bug is in the NEW 4.255 section only, not in
any inherited code. There was no DONE255.
hef255.out 58,881 lines / 10,700,426 B sha256
`c0e483012c3a72b0b9945f16fda911518d62a3e4edcd0b5b429c9e6499407435`;
prefix against hef254.out: the first 58,847 lines
differ from hef254.out in exactly ONE line (line
41611, frozenset element order only — the
AES-NUM-150 variance). Partial section 34 lines /
11,519 B sha256
`700ae8b2830aa5befd6f19ee8f348082c521a21a5d6f64d65cef32f6574a3c85`,
read in full on-device: arm (i) printed the
difference sequence [0, 15, 28, 40, 52, 61, 67, 70]
with all tests True and arm (ii) printed eight
distinct differences with counts summing to 8.
That launch is closed and was never repeated
under TASK_CONTRACT_4.255.

RETRY LAUNCH (this slice's evidence): retry
contract `docs/TASK_CONTRACT_4.255_RETRY.md`
published and pushed @ 63e003f3 before any
replacement launch (the AES-NUM-191 one-patch
precedent). The ONLY code change: sections255r
defines expGapCumRem255 = [3, 6, 9, 12, 14, 15, 15]
before the gap loop — verified locally as exactly
one added line against arms255. arms255r sha256
`6e8120a8f870e1454ffb5acbe112bdfe2e14332311536aa6d5274d6100750f05`
(19,822 B); hef255r.py sha256
`de15b9765100be64c4b1847345812d75d090fcf3a157d6b1d17c15afd4afa26c`
(2,201,940 B) on both the VM and the device.
Crossing: arms255r gzipped at gzip -9 (sha256
`632555233cf6fa9234cc0a3e52b2b2d9f17e8510b99fd9b46088b52b9c867000`,
5,067 B), fourteen 373 B parts (last 218 B), each
with its own sha256 gate — all fourteen verified
on-device on the first attempt; assembled gzip,
arms and hef255r shas == VM on-device, py_compile
OK. Pre-launch tmux/ps check found no
hef255r/h255r child; exactly ONE bounded host-side
retry child ran in detached tmux (session h255r,
launched 2026-10-31 03:27:22 EDT) with the
contract corpus argv, unbuffered, and finished
with exit marker 0 (hef255r.exit), err empty, and
DONE255 as its last line. Output hef255r.out
58,891 lines / 10,704,520 B sha256
`841db0f1a3a55840f289bf08259891219e1f0b05d9f8743e359adae28d216245`;
prefix against hef254.out: the first 58,847 lines
differ from hef254.out in exactly ONE line (line
42872, frozenset element order only — the
AES-NUM-150 variance, verified by
same-sorted-characters comparison via
check255.py), hef255r.out adding exactly its own
44 section lines (15,613 B, sha256
`e58a6018f88d7933828076908b6c28867e5a10f438e5b08da3184b019bb015c6`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef255.out, hef255.py, arms255.py,
section255.txt, hef255.exit, hef255.err, run255.sh,
gz255/, hef255r.out, hef255r.py, arms255r.py,
section255r.txt, hef255r.exit, hef255r.err,
run255r.sh, gz255r/, check255.py); local lineage
in ~/workspace/.verify-tmp/aesir255.

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
including that position (AES-NUM-254) — 70 after
position 8. The CUMULATIVE-REMAINING-MINUS-REMAINING
DIFFERENCE at a position is that position's
cumulative remaining total minus its own remaining
value — the cumulative remaining total before that
position's remaining value is counted. The
GAP at a gap position 1–7 is the next act's offset
minus this act's offset; gap agreement means the
A gap equals the B gap at that position; the GAP
REMAINING at a gap position is the gap total 3
minus the gap cumulative agreement count after
that gap position (per AES-NUM-251); the GAP
CUMULATIVE REMAINING after a gap position is the
running total of the gap remaining values over
gap positions 1 up to and including that gap
position (per AES-NUM-254); the GAP
CUMULATIVE-REMAINING DIFFERENCE at a gap position
is that position's gap cumulative remaining total
minus its own gap remaining value.

## (i) The closing-run cumulative-remaining-minus-remaining difference sequence in full

At each position, the AES-NUM-254 cumulative
remaining total minus that position's own
AES-NUM-251 remaining value, stated position by
position (each printed set equals the AES-NUM-247
printed set, each printed count equals the
AES-NUM-248 printed count, each printed
cumulative total equals the AES-NUM-249 printed
cumulative, each printed difference equals the
AES-NUM-250 printed difference, each printed
remaining equals the AES-NUM-251 printed
remaining, each printed cumulative remaining
equals the AES-NUM-254 printed value, each printed
cumulative-remaining difference equals its
expected value, and difference plus remaining
equals cumulative remaining, printed tests True
for all eight):

- Position 1 (A rank 741 / B rank 743): set [RUN-102] — count 1 of 6 — cumulative 1 — difference 0 — remaining 15 — cumulative remaining 15 — cumulative-remaining difference 0.
- Position 2 (A rank 742 / B rank 744): set [CHANNEL, RUN-102] — count 2 of 6 — cumulative 3 — difference 1 — remaining 13 — cumulative remaining 28 — cumulative-remaining difference 15.
- Position 3 (A rank 743 / B rank 745): set [RUN-102] — count 1 of 6 — cumulative 4 — difference 3 — remaining 12 — cumulative remaining 40 — cumulative-remaining difference 28.
- Position 4 (A rank 744 / B rank 746): set [] — count 0 of 6 — cumulative 4 — difference 4 — remaining 12 — cumulative remaining 52 — cumulative-remaining difference 40.
- Position 5 (A rank 745 / B rank 747): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 7 — difference 4 — remaining 9 — cumulative remaining 61 — cumulative-remaining difference 52.
- Position 6 (A rank 746 / B rank 748): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 10 — difference 7 — remaining 6 — cumulative remaining 67 — cumulative-remaining difference 61.
- Position 7 (A rank 747 / B rank 749): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 13 — difference 10 — remaining 3 — cumulative remaining 70 — cumulative-remaining difference 67.
- Position 8 (A rank 748 / B rank 750): set [SIZE, CHANNEL, RUN-102] — count 3 of 6 — cumulative 16 — difference 13 — remaining 0 — cumulative remaining 70 — cumulative-remaining difference 70.

Cumulative-remaining difference sequence:
[0, 15, 28, 40, 52, 61, 67, 70] — equals the
expected sequence (printed test True); the last
difference is 70. Stated as printed arithmetic
only: the difference sequence is the cumulative
remaining sequence shifted by one position with
0 prepended, because each difference subtracts
exactly the value that position added — no
mechanism claimed.

## (ii) The distinct differences in full

Distinct differences, in order of first
appearance, with the positions at which each
occurs and its count stated exactly (counts sum
to 8, printed test True):

- 0: position 1 — count 1.
- 15: position 2 — count 1.
- 28: position 3 — count 1.
- 40: position 4 — count 1.
- 52: position 5 — count 1.
- 61: position 6 — count 1.
- 67: position 7 — count 1.
- 70: position 8 — count 1.

Eight distinct differences; no difference
repeats — stated as printed arithmetic only, no
mechanism claimed.

## (iii) The gap cumulative-remaining difference sequence in full

At each gap position, the AES-NUM-254 gap
cumulative remaining total minus that gap
position's own AES-NUM-251 gap remaining value,
stated gap position by gap position (each printed
gap result equals the AES-NUM-247 printed result,
each printed gap remaining equals the AES-NUM-251
printed value, each printed gap cumulative
remaining equals the AES-NUM-254 printed value,
each printed gap difference equals its expected
value, and difference plus gap remaining equals
gap cumulative remaining, printed tests True for
all seven): gap position 1 A 512 against B 712 —
disagree, gap cumulative 0, gap remaining 3,
gap cumulative remaining 3, gap difference 0; gap
position 2 A 512 against B 26624 — disagree, gap
cumulative 0, gap remaining 3, gap cumulative
remaining 6, gap difference 3; gap position 3
A 512 against B 14848 — disagree, gap cumulative
0, gap remaining 3, gap cumulative remaining 9,
gap difference 6; gap position 4 A 512 against
B 33280 — disagree, gap cumulative 0, gap
remaining 3, gap cumulative remaining 12, gap
difference 9; gap position 5 A 512 against B 512
— agree, gap cumulative 1, gap remaining 2, gap
cumulative remaining 14, gap difference 12; gap
position 6 A 512 against B 512 — agree, gap
cumulative 2, gap remaining 1, gap cumulative
remaining 15, gap difference 14; gap position 7
A 512 against B 512 — agree, gap cumulative 3,
gap remaining 0, gap cumulative remaining 15,
gap difference 15.

Gap cumulative-remaining difference sequence:
[0, 3, 6, 9, 12, 14, 15] — equals the expected
sequence (printed test True), ends at 15, with
agreeing positions 5, 6, 7 (count 3), equal to
AES-NUM-245; the printed gap cumulative remaining
sequence equals AES-NUM-254, and the printed gap
remaining sequence equals AES-NUM-251.

Contract tests: the printed difference sequence
equals (0, 15, 28, 40, 52, 61, 67, 70) — True;
the distinct differences' counts sum to 8 — True;
each difference plus that position's remaining
value equals that position's cumulative remaining
total — True for all eight; the last difference
equals 70 — True; the gap difference sequence
equals (0, 3, 6, 9, 12, 14, 15) and ends at 15 —
True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
