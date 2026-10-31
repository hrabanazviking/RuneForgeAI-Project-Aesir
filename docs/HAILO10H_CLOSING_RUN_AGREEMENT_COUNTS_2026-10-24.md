# The closing-run agreement-count sequence, the distinct agreement counts, and the gap-agreement position lists (AES-NUM-248)

Slice 4.248, worked under `docs/TASK_CONTRACT_4.248.md`
(contract published in the 4.247 closing commit @
b6db13e3). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section248.txt).

## Run and closing record

hef248.py is the verified hef247 base plus
arms248: hef247.py sha256
`bbc3c446b244d6a04af03c1c2b55f2b9f128de02be8e62584b78b51b6e411ed3`
(2,062,426 B) on both the VM and the device.
arms248 sha256
`6a384741e354f8051926b33d6c2cac42b7a4941acc0ca9b16f2c0b0b6ca9fbfc`
(15,446 B); hef248.py sha256
`36ab3c64ba74a1dc272bdf55309e5b97cc2f3c3e73272ffed7eb70f87f8fb8ef`
(2,077,872 B) on both the VM and the device.
Crossing, stated exactly: arms248 was gzipped at
gzip -9 (sha256
`e4f6010831347b8e4f4c3a355d9c91aeb0e3d6b25adfb8c5fc8a26f4f09b5671`,
4,288 B) and split into twelve 373 B parts (last
185 B); each part was written as its own file with
its own sha256 gate — all twelve verified
on-device on the first attempt; no byte was ever
accepted unverified. The assembled gzip, arms and
hef248 shas == VM on-device; hef248 assembled
on-device from hef247.py + arms248.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef248/h248 child; exactly ONE bounded host-side
child ran in detached tmux (session h248, launched
2026-10-31 00:28:04 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef248.exit), err empty, and DONE248 as its last
line. Output hef248.out 58,588 lines /
10,622,829 B sha256
`07ab8711e81b3cb0ea4efced6abc8d5c72d4241ede6920a51b2e2eae41df5ae6`;
prefix against hef247.out: the first 58,547
lines differ from hef247.out in exactly ONE line
(line 41611, frozenset element order only — the
AES-NUM-150 variance, verified by
same-sorted-characters comparison; the second
variance line seen in earlier runs, 42872, did
not differ this run), hef248.out adding exactly
its own 41 section lines (7,132 B, sha256
`508766254aed14cecfcfda79a5b004af6a75cb331d0a0242e10f2e10411e3fa6`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef248.out, hef248.py, arms248.py,
section248.txt, hef248.exit, run248.sh, gz248/,
check248.py); local lineage in
~/workspace/.verify-tmp/aesir248.

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
that position's agreement set. The GAP at a gap
position 1–7 is the next act's offset minus this
act's offset; gap agreement means the A gap
equals the B gap at that position.

## (i) The closing-run agreement-count sequence in full

The eight per-position agreement counts of
AES-NUM-247's agreement sets, stated as one
sequence (each printed set equals the AES-NUM-247
printed set and each printed count equals its
expected count, printed tests True for all
eight):

- Position 1 (A rank 741 / B rank 743): set [RUN-102] — count 1 of 6.
- Position 2 (A rank 742 / B rank 744): set [CHANNEL, RUN-102] — count 2 of 6.
- Position 3 (A rank 743 / B rank 745): set [RUN-102] — count 1 of 6.
- Position 4 (A rank 744 / B rank 746): set [] — count 0 of 6.
- Position 5 (A rank 745 / B rank 747): set [SIZE, CHANNEL, RUN-102] — count 3 of 6.
- Position 6 (A rank 746 / B rank 748): set [SIZE, CHANNEL, RUN-102] — count 3 of 6.
- Position 7 (A rank 747 / B rank 749): set [SIZE, CHANNEL, RUN-102] — count 3 of 6.
- Position 8 (A rank 748 / B rank 750): set [SIZE, CHANNEL, RUN-102] — count 3 of 6.

Agreement-count sequence: [1, 2, 1, 0, 3, 3, 3,
3] — equals the counts of the AES-NUM-247 printed
sets (printed test True).

## (ii) The distinct agreement counts in full

Distinct values, in order of first appearance,
with the positions at which each occurs and its
count stated exactly (counts sum to 8, printed
test True):

- 1: positions 1, 3 — count 2.
- 2: position 2 — count 1.
- 0: position 4 — count 1.
- 3: positions 5, 6, 7, 8 — count 4.

Total agreeing family-instances re-summed over
positions: 1 + 2 + 1 + 0 + 3 + 3 + 3 + 3 = 16 —
equal to the sum of AES-NUM-245's family counts
(size 4 + channel 5 + class 0 + run-102 7 +
offset 0 + index 0 = 16, printed test True).

## (iii) The gap-agreement position lists in full

The seven gap positions' agreement results of
AES-NUM-247, stated as two lists (each printed
result equals the AES-NUM-247 printed result,
printed test True for all seven): gap position 1
A 512 against B 712 — disagree; gap position 2
A 512 against B 26624 — disagree; gap position 3
A 512 against B 14848 — disagree; gap position 4
A 512 against B 33280 — disagree; gap position 5
A 512 against B 512 — agree; gap position 6
A 512 against B 512 — agree; gap position 7
A 512 against B 512 — agree.

- Agreeing position list: positions 5, 6, 7 — count 3 (equal to AES-NUM-245, printed test True).
- Disagreeing position list: positions 1, 2, 3, 4 — count 4 (equal to AES-NUM-245, printed test True).

The two counts re-sum to 3 and 4, as in
AES-NUM-245.

Contract tests: the printed agreement-count
sequence equals the counts of the sets printed in
AES-NUM-247 (1, 2, 1, 0, 3, 3, 3, 3) — True; the
distinct-count counts sum to 8 — True; the
re-summed agreeing family-instances equal 16 and
equal AES-NUM-245's family-count sum — True; the
gap-agreement position lists equal AES-NUM-247's
agreeing and disagreeing positions and their
counts re-sum to 3 and 4 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
