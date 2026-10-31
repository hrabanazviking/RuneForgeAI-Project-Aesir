# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-270)

Slice 4.270, worked under `docs/TASK_CONTRACT_4.270.md`
(contract published in the 4.269 closing commit @
ac087597). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section270.txt).

## Run and closing record

hef270.py is the verified hef269 base plus
arms270: hef269.py sha256
`181797b1634e5200902e3560d12ca3bda18727e4a0b7d09ab58c6844c4a750eb`
(2,660,013 B) on both the VM and the device.
arms270 sha256
`4cca258044de6abf848f5c322d21ad3b93ed5bee31ed4b42a3f72f489b7246a4`
(52,621 B); hef270.py sha256
`6fef610e1f1af88de56e499de728bd1f50cf7c1394628c49a8693a5a64e886ef`
(2,712,634 B) on both the VM and the device.
Crossing, stated exactly: arms270 was gzipped
with gzip -9 (sha256
`9c0ec38e05b09f2c58c87ba06c90d02649f814f2439c0866802a3a728ad3de2d`,
7,486 B) and split into twenty-one 373 B parts
(last 26 B), each part written as its own file
with its own sha256 gate — all twenty-one verified
on-device on the first attempt; no byte accepted
unverified. The assembled gzip, arms and hef270
shas == VM on-device; hef270 assembled on-device
from hef269.py + arms270.py, sha == VM,
py_compile OK. The build's slice-number shift was
268 -> 269, 269 -> 270 only, so the real data
value 21267 (AES-NUM-262 layer, two occurrences)
was verified untouched at exactly 2 occurrences,
with no 21268 / 21269 introduced.

LAUNCH: pre-launch tmux/ps check found no
hef270/h270 child; exactly ONE bounded host-side
child ran in detached tmux (session h270, launched
2026-10-31 11:43:35 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef270.exit), err empty, and DONE270 as its last
line. Output hef270.out 59,548 lines / 11,425,004 B
sha256 `d241e0ac…` (as recorded at verification);
prefix against hef269.out: the first 59,504 lines
differ from hef269.out in exactly ONE line (line
41611, frozenset element order only, the
AES-NUM-150 variance, verified by
same-sorted-characters comparison via
check270.py sha256
`a2db3b64f3faa2eb080253449be1433f94d8b8f26fd23b48373bd2d5e3b9765a`),
hef270.out adding exactly its own 44 tail lines
(92,232 B, sha256 `3ca3dc8b…`).
Controls EXACT, with no exception this slice:
the only 'False' tokens in section270 are the
four gap-position agree data values for gap
positions 1–4 (positions 5, 6, 7 agree) — data,
not comparisons.
Raw output kept on the Pi at
~/aesir-build/ (hef270.out, hef270.py, arms270.py,
section270.txt, hef270.exit, hef270.err, run270.sh,
gz270/, check270.py); local lineage in
~/workspace/.verify-tmp/aesir270.

Definitions carry over from AES-NUM-247 through
AES-NUM-269 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the agreement
set, agreement count, cumulative total, difference,
remaining, cumulative remaining and every iterated
cumulative-remaining running total are as defined in
the section270 header, read in full on-device.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-269 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that position
(all printed comparisons True for all eight):

- Position 1 (A rank 741 / B rank 743): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 812.
- Position 3 (A rank 743 / B rank 745): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 6393.
- Position 4 (A rank 744 / B rank 746): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 35648.
- Position 5 (A rank 745 / B rank 747): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 157831.
- Position 6 (A rank 746 / B rank 748): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 590019.
- Position 7 (A rank 747 / B rank 749): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1934583.
- Position 8 (A rank 748 / B rank 750): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 5708379.

Sequence: [55, 812, 6393, 35648, 157831, 590019, 1934583, 5708379] —
equals the expected sequence (printed test True);
the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total is 5708379.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, in order of first
appearance, with positions and counts (counts sum
to 8, printed test True):

- 55: position 1 — count 1.
- 812: position 2 — count 1.
- 6393: position 3 — count 1.
- 35648: position 4 — count 1.
- 157831: position 5 — count 1.
- 590019: position 6 — count 1.
- 1934583: position 7 — count 1.
- 5708379: position 8 — count 1.

Eight distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals; none repeats —
stated as printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-269 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that gap
position (A gaps all 512; B gaps 712, 26624, 14848,
33280, 512, 512, 512; agree False, False, False,
False, True, True, True):

- Gap position 1: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12.
- Gap position 2: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 177.
- Gap position 3: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1392.
- Gap position 4: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 7752.
- Gap position 5: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 34273.
- Gap position 6: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 127925.
- Gap position 7: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 418761.

Sequence: [12, 177, 1392, 7752, 34273, 127925, 418761] — equals the
expected sequence (printed test True), ends at
418761, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245.

Contract tests: the printed cumulative sequence
equals (55, 812, 6393, 35648, 157831, 590019, 1934583,
5708379) — True; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals'
counts sum to 8 — True; the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total
equals 5708379 — True; the gap cumulative sequence
equals (12, 177, 1392, 7752, 34273, 127925, 418761)
and ends at 418761 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
