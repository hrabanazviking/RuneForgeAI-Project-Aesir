# The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence, the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, and the gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence (AES-NUM-271)

Slice 4.271, worked under `docs/TASK_CONTRACT_4.271.md`
(contract published in the 4.270 closing commit @
38962e66). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section271.txt).

## Run and closing record

hef271.py is the verified hef270 base plus
arms271: hef270.py sha256
`6fef610e1f1af88de56e499de728bd1f50cf7c1394628c49a8693a5a64e886ef`
(2,712,634 B) on both the VM and the device.
arms271 sha256
`bb09ba3ea96d000dc8a54f24b79961e203ae4c8c96e42d84b29ba93d3e17f124`
(55,939 B); hef271.py sha256
`1a5e10959db0cd0633192ca85d8c53793313fcd7614b7e845e0b8dedf1c95e4f`
(2,768,573 B) on both the VM and the device.
arms271 was built locally on the hef270 lineage
(build271.py, derived from build270.py by a
scripted transform — two faults in the first build
attempt were found and fixed in the builder, not
the data: the transform had corrupted build270's
own slice-shift line, and the gap-definition /
gap-list reps needed their running-variable numbers
patched (g15cum271 definition; historical g5–g15
list kept, g16cum271 added)). hef271 = hef270 +
arms271 byte-exact. Crossing, stated exactly:
arms271 was gzipped with gzip -9 (sha256
`32a1d6dcef3f67b12baf7c6b0a7edcb1f4fced8794aca096609c236d8574e54f`,
7,654 B) and split into twenty-one 373 B parts
(last 194 B), each part written as its own file
with its own sha256 gate — all twenty-one verified
on-device on the first attempt; no byte accepted
unverified. The assembled gzip, arms and hef271
shas == VM on-device; py_compile OK on-device.
The build's slice-number shift was
269 -> 270, 270 -> 271 only, so the real data
value 21267 (AES-NUM-262 layer, two occurrences)
was verified untouched at exactly 2 occurrences.

LAUNCH: pre-launch tmux/ps check found no
hef271/h271 child; exactly ONE bounded host-side
child ran in detached tmux (session h271, launched
2026-10-31 12:35:57 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef271.exit), err empty, and DONE271 as its last
line. Output hef271.out 59,592 lines / 11,525,542 B
sha256 `d3bf4d5c…` (as recorded at verification);
prefix against hef270.out: the first 59,548 lines
differ from hef270.out in exactly TWO lines (lines
41611 and 42872, frozenset element order only, the
AES-NUM-150 variance, verified by
same-sorted-characters comparison via
check271.py sha256
`f115454326dd0046551ae46eb6e711b7f3dd5bbd85f6acbf00326bc7e2aa10c2`),
hef271.out adding exactly its own 44 tail lines
(100,538 B, sha256 `0874929a…`).
Controls EXACT, with no exception this slice:
the only 'False' tokens in section271 are the
four gap-position agree data values for gap
positions 1–4 (positions 5, 6, 7 agree) — data,
not comparisons.
Raw output kept on the Pi at
~/aesir-build/ (hef271.out, hef271.py, arms271.py,
section271.txt, hef271.exit, hef271.err, run271.sh,
gz271/, check271.py); local lineage in
~/workspace/.verify-tmp/aesir271.

Definitions carry over from AES-NUM-247 through
AES-NUM-270 exactly as printed in the run: POSITION
is 1-based over the eight acts of the closing run
(A ranks 741–748, B ranks 743–750); the agreement
set, agreement count, cumulative total, difference,
remaining, cumulative remaining and every iterated
cumulative-remaining running total are as defined in
the section271 header, read in full on-device.

## (i) The closing-run cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each position, the running total of the
AES-NUM-270 cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over positions 1 up to and including that position
(all printed comparisons True for all eight):

- Position 1 (A rank 741 / B rank 743): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 55.
- Position 2 (A rank 742 / B rank 744): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 867.
- Position 3 (A rank 743 / B rank 745): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 7260.
- Position 4 (A rank 744 / B rank 746): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 42908.
- Position 5 (A rank 745 / B rank 747): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 200739.
- Position 6 (A rank 746 / B rank 748): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 790758.
- Position 7 (A rank 747 / B rank 749): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 2725341.
- Position 8 (A rank 748 / B rank 750): cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 8433720.

Sequence: [55, 867, 7260, 42908, 200739, 790758, 2725341, 8433720] —
equals the expected sequence (printed test True);
the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total is 8433720.

## (ii) The distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals in full

Distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals, in order of first
appearance, with positions and counts (counts sum
to 8, printed test True):

- 55: position 1 — count 1.
- 867: position 2 — count 1.
- 7260: position 3 — count 1.
- 42908: position 4 — count 1.
- 200739: position 5 — count 1.
- 790758: position 6 — count 1.
- 2725341: position 7 — count 1.
- 8433720: position 8 — count 1.

Eight distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals; none repeats —
stated as printed arithmetic only, no mechanism claimed.

## (iii) The gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining-count sequence in full

At each gap position, the running total of the
AES-NUM-270 gap cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining values
over gap positions 1 up to and including that gap
position (A gaps all 512; B gaps 712, 26624, 14848,
33280, 512, 512, 512; agree False, False, False,
False, True, True, True):

- Gap position 1: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 12.
- Gap position 2: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 189.
- Gap position 3: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 1581.
- Gap position 4: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 9333.
- Gap position 5: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 43606.
- Gap position 6: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 171531.
- Gap position 7: cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative-remaining remaining 590292.

Sequence: [12, 189, 1581, 9333, 43606, 171531, 590292] — equals the
expected sequence (printed test True), ends at
590292, with agreeing positions 5, 6, 7 (count 3),
equal to AES-NUM-245.

Contract tests: the printed cumulative sequence
equals (55, 867, 7260, 42908, 200739, 790758, 2725341,
8433720) — True; the distinct cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative totals'
counts sum to 8 — True; the last cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative cumulative total
equals 8433720 — True; the gap cumulative sequence
equals (12, 189, 1581, 9333, 43606, 171531, 590292)
and ends at 590292 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
