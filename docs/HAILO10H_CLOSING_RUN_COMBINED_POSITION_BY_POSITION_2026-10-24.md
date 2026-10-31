# The A and B closing runs' combined sequences stated position by position, and the closing-run combined comparison stated position by position (AES-NUM-246)

Slice 4.246, worked under `docs/TASK_CONTRACT_4.246.md`
(contract published in the 4.245 closing commit @
7282964d). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section246.txt).

## Run and closing record

hef246.py is the verified hef245 base plus
arms246: hef245.py sha256
`19925ebd4d50b197466a03c4c52fbc17270ffe8324d3978c5526a72d8ac68590`
(2,029,111 B) on both the VM and the device.
arms246 sha256
`eaf6f897b1781b3e362a459db526443c9bf1fa2abc24643d2c0c14ccfd801949`
(18,032 B); hef246.py sha256
`19d779cc99fcd63e6a122d8e72f9d116b8b8a5fb2812d5c5a4c69d78752f3d1c`
(2,047,143 B) on both the VM and the device.
Crossing, stated exactly: arms246 was gzipped at
gzip -9 (sha256
`1f041910cc6642b14ede36bf5b3e814cbeac7a4155fad7de035fcdf26f62490d`,
4,513 B) and split into thirteen 373 B parts (last
37 B); each part was written as its own file with
its own sha256 gate — all thirteen verified
on-device on the first attempt; no byte was ever
accepted unverified. The assembled gzip, arms and
hef246 shas == VM on-device; hef246 assembled
on-device from hef245.py + arms246.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef246/h246 child; exactly ONE bounded host-side
child ran in detached tmux (session h246, created
2026-10-30 23:47:23 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef246.exit), err empty, and DONE246 as its last
line. Output hef246.out 58,500 lines / 10,608,341 B
sha256
`d1a3ef708283596245707abecaa661351c57ea21d92639978a6b808e9dd8b1d0`;
prefix against hef245.out: the first 58,448
lines differ from hef245.out in exactly TWO lines
(lines 41611 and 42872, frozenset element order
only — the AES-NUM-150 variance, each verified by
same-sorted-characters comparison), hef246.out
adding exactly its own 52 section lines (12,306 B,
sha256
`e7df9eea78b129351082d69a23b5e810a1592734de781b476edfc4dee5ecba72`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef246.out, hef246.py, arms246.py,
section246.txt, hef246.exit, run246.sh, gz246/,
check246.py); local lineage in
~/workspace/.verify-tmp/aesir246.

Definitions: POSITION is 1-based over the eight
acts of a closing run (position 1 = first act).
SIZE is act[1]; CHANNEL is act[2]; OFFSET is
act[0]; INDEX is the act's index in its own
context's act list; BASE CLASS is the class3
label before the first opening parenthesis,
stripped; RUN-102 MEMBERSHIP is True if the act
is in secondary run 102 else False; the GAP at
positions 1–7 is the next act's offset minus
this act's offset; position 8 is terminal, no
gap. At each act position, the AGREEMENT SET is
the list, in the canonical family order SIZE,
CHANNEL, CLASS, RUN-102, OFFSET, INDEX, of the
families whose A value equals the B value at
that same position.

## (i) The A closing run's combined sequences, position by position

The A closing run is ranks 741–748 in A-offset
order, 8 acts. Every position's printed values
equal the corresponding AES-NUM-245 combined
entry (printed test True for all eight):

- Position 1: rank 741, index 734, act (791777280, 24, 1) — size 24, channel 1, A-only distinct, run-102 False, offset 791777280, gap to next 512.
- Position 2: rank 742, index 735, act (791777792, 24, 2) — size 24, channel 2, A-only distinct, run-102 False, offset 791777792, gap to next 512.
- Position 3: rank 743, index 736, act (791778304, 24, 0) — size 24, channel 0, A-only distinct, run-102 False, offset 791778304, gap to next 512.
- Position 4: rank 744, index 744, act (791778816, 24, 0) — size 24, channel 0, shared single-positioned, run-102 True, offset 791778816, gap to next 512.
- Position 5: rank 745, index 745, act (791779328, 24, 0) — size 24, channel 0, A-only distinct, run-102 False, offset 791779328, gap to next 512.
- Position 6: rank 746, index 746, act (791779840, 24, 1) — size 24, channel 1, A-only distinct, run-102 False, offset 791779840, gap to next 512.
- Position 7: rank 747, index 747, act (791780352, 24, 2) — size 24, channel 2, A-only distinct, run-102 False, offset 791780352, gap to next 512.
- Position 8: rank 748, index 748, act (791780864, 24, 0) — size 24, channel 0, A-only distinct, run-102 False, offset 791780864, gap to next none (terminal).

Sequences re-stated from the positions: size
[24, 24, 24, 24, 24, 24, 24, 24], channel
[1, 2, 0, 0, 0, 1, 2, 0], class [A-only distinct
x3, shared single-positioned, A-only distinct
x4], run-102 [False, False, False, True, False,
False, False, False], offset [791777280,
791777792, 791778304, 791778816, 791779328,
791779840, 791780352, 791780864], index [734,
735, 736, 744, 745, 746, 747, 748], gap [512,
512, 512, 512, 512, 512, 512] — all equal
AES-NUM-245 (printed test True).

## (ii) The B closing run's combined sequences, position by position

The B closing run is ranks 743–750 in B-offset
order, 8 acts. Every position's printed values
equal the corresponding AES-NUM-245 combined
entry (printed test True for all eight):

- Position 1: rank 743, index 26, act (1196368696, 280, 2) — size 280, channel 2, B-only distinct, run-102 False, offset 1196368696, gap to next 712.
- Position 2: rank 744, index 229, act (1196369408, 26128, 2) — size 26128, channel 2, B-only distinct, run-102 False, offset 1196369408, gap to next 26624.
- Position 3: rank 745, index 272, act (1196396032, 14352, 1) — size 14352, channel 1, B-only distinct, run-102 False, offset 1196396032, gap to next 14848.
- Position 4: rank 746, index 674, act (1196410880, 32784, 2) — size 32784, channel 2, B-only distinct, run-102 False, offset 1196410880, gap to next 33280.
- Position 5: rank 747, index 735, act (1196444160, 24, 0) — size 24, channel 0, B-only distinct, run-102 False, offset 1196444160, gap to next 512.
- Position 6: rank 748, index 736, act (1196444672, 24, 1) — size 24, channel 1, B-only distinct, run-102 False, offset 1196444672, gap to next 512.
- Position 7: rank 749, index 737, act (1196445184, 24, 2) — size 24, channel 2, B-only distinct, run-102 False, offset 1196445184, gap to next 512.
- Position 8: rank 750, index 738, act (1196445696, 24, 0) — size 24, channel 0, B-only distinct, run-102 False, offset 1196445696, gap to next none (terminal).

Sequences re-stated from the positions: size
[280, 26128, 14352, 32784, 24, 24, 24, 24],
channel [2, 2, 1, 2, 0, 1, 2, 0], class [B-only
distinct x8], run-102 [False x8], offset
[1196368696, 1196369408, 1196396032, 1196410880,
1196444160, 1196444672, 1196445184, 1196445696],
index [26, 229, 272, 674, 735, 736, 737, 738],
gap [712, 26624, 14848, 33280, 512, 512, 512] —
all equal AES-NUM-245 (printed test True).

## (iii) The closing-run combined comparison, position by position

At each act position, which of the six act
families agree, stated exactly (each printed
set equals the set derived from AES-NUM-245's
family comparisons, printed test True for all
eight):

- Position 1 (A rank 741 / B rank 743): agreement set [RUN-102] — count 1 of 6.
- Position 2 (A rank 742 / B rank 744): agreement set [CHANNEL, RUN-102] — count 2 of 6.
- Position 3 (A rank 743 / B rank 745): agreement set [RUN-102] — count 1 of 6.
- Position 4 (A rank 744 / B rank 746): agreement set [] — count 0 of 6; no family agrees at this position.
- Position 5 (A rank 745 / B rank 747): agreement set [SIZE, CHANNEL, RUN-102] — count 3 of 6.
- Position 6 (A rank 746 / B rank 748): agreement set [SIZE, CHANNEL, RUN-102] — count 3 of 6.
- Position 7 (A rank 747 / B rank 749): agreement set [SIZE, CHANNEL, RUN-102] — count 3 of 6.
- Position 8 (A rank 748 / B rank 750): agreement set [SIZE, CHANNEL, RUN-102] — count 3 of 6.

At each gap position, whether the gaps agree,
stated exactly (each printed result equals the
AES-NUM-245-derived result, printed test True
for all seven): gap positions 1–4 disagree
(A 512 against B 712, 26624, 14848, 33280);
gap positions 5–7 agree (512 against 512).

Family count re-sum over positions: size 4
(expect 4), channel 5 (expect 5), class 0
(expect 0), run-102 7 (expect 7), offset 0
(expect 0), index 0 (expect 0), gap 3 (expect
3) — all equal AES-NUM-245 counts (printed
test True).

Contract tests: each position's printed values
equal the corresponding entries of the combined
sequences printed in AES-NUM-245 — True for all
sixteen positions; each position's printed
agreement set equals the set derived from
AES-NUM-245's family comparisons — True for
all eight positions; the family agreement
counts re-summed over positions equal size 4,
channel 5, class 0, run-102 7, offset 0, index
0, gap 3 — True.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
