# The A and B closing runs' combined sequences, and the closing-run combined comparison (AES-NUM-245)

Slice 4.245, worked under `docs/TASK_CONTRACT_4.245.md`
(contract published in the 4.244 closing commit @
10b1aaea). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section245.txt).

## Run and closing record

hef245.py is the verified hef244 base plus
arms245: hef244.py sha256
`2d0d5ffcd15c7ce66f8b2405712feabef59b7021e836e97582be1701f784afaa`
(2,013,908 B) on both the VM and the device.
arms245 sha256
`3c566891c8ad5102e1e653229f59c109def4c34bbfa70196cdb032180c9c8ed1`
(15,203 B); hef245.py sha256
`19925ebd4d50b197466a03c4c52fbc17270ffe8324d3978c5526a72d8ac68590`
(2,029,111 B) on both the VM and the device.
Crossing, stated exactly: arms245 was gzipped at
gzip -9 (sha256
`d49820a6311eeeaba716c4cdeb39b9fc86f434ffecd90f50f7efa4da6be15859`,
3,813 B) and split into eleven 373 B parts (last
83 B); each part was written as its own file with
its own sha256 gate — all eleven verified on-device
on the first attempt; no byte was ever accepted
unverified. The assembled gzip, arms and hef245
shas == VM on-device; hef245 assembled on-device
from hef244.py + arms245.py, sha == VM, py_compile
OK. Pre-launch tmux/ps check found no hef245/h245
child; exactly ONE bounded host-side child ran in
detached tmux (session h245, created 2026-10-30
23:31:20 EDT) with the contract corpus argv (glob
order, MiniLM last), unbuffered (`python3 -u`),
and finished with exit marker 0 (hef245.exit),
err empty, and DONE245 as its last line. Output
hef245.out 58,448 lines / 10,596,035 B sha256
`5745872c58afc5f9e3bd7af56f997df9f48ff525ec869b89f5e8f7fbed82aa1a`;
prefix against hef244.out: the first 58,338
lines differ from hef244.out in exactly ONE line
(line 41611, frozenset element order only — the
AES-NUM-150 variance, verified by
same-sorted-characters comparison), hef245.out
adding exactly its own 110 section lines (13,308 B,
sha256
`b954065ebee10609fa29ea4101202e0f48031aaf8fa5d1e52a816791b4d5ee86`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef245.out, hef245.py, arms245.py,
section245.txt, hef245.exit, run245.sh, gz245/,
check245.py); local lineage in
~/workspace/.verify-tmp/aesir245.

Definitions: SIZE is act[1]; CHANNEL is act[2];
OFFSET is act[0]; INDEX is the act's index in its
own context's act list; BASE CLASS is the class3
label before the first opening parenthesis,
stripped; RUN-102 MEMBERSHIP is True if the act
is in secondary run 102 else False; the GAP
SEQUENCE is the seven gaps between consecutive
acts in rank order, each gap the next act's
offset minus this act's offset.

## (i) The A closing run's combined sequences in full

The A closing run is ranks 741–748 in A-offset
order, 8 acts, walked in full in AES-NUM-240.
Every act matches its AES-NUM-240 per-act
statement (printed match True for all eight):

- 741: A 734 (791777280, 24, 1) — size 24, channel 1, A-only distinct, run-102 False, offset 791777280.
- 742: A 735 (791777792, 24, 2) — size 24, channel 2, A-only distinct, run-102 False, offset 791777792.
- 743: A 736 (791778304, 24, 0) — size 24, channel 0, A-only distinct, run-102 False, offset 791778304.
- 744: A 744 (791778816, 24, 0) — size 24, channel 0, shared single-positioned, run-102 True, offset 791778816.
- 745: A 745 (791779328, 24, 0) — size 24, channel 0, A-only distinct, run-102 False, offset 791779328.
- 746: A 746 (791779840, 24, 1) — size 24, channel 1, A-only distinct, run-102 False, offset 791779840.
- 747: A 747 (791780352, 24, 2) — size 24, channel 2, A-only distinct, run-102 False, offset 791780352.
- 748: A 748 (791780864, 24, 0) — size 24, channel 0, A-only distinct, run-102 False, offset 791780864.

Size sequence: [24, 24, 24, 24, 24, 24, 24, 24]
— equals AES-NUM-241 exactly (printed test True).
Channel sequence: [1, 2, 0, 0, 0, 1, 2, 0] —
equals AES-NUM-241 exactly (printed test True).
Class sequence: [A-only distinct, A-only distinct,
A-only distinct, shared single-positioned, A-only
distinct, A-only distinct, A-only distinct,
A-only distinct] — equals AES-NUM-242 exactly
(printed test True). Run-102 membership sequence:
[False, False, False, True, False, False, False,
False] — equals AES-NUM-242 exactly (printed test
True). Offset sequence: [791777280, 791777792,
791778304, 791778816, 791779328, 791779840,
791780352, 791780864] — equals AES-NUM-243 exactly
(printed test True). Index sequence: [734, 735,
736, 744, 745, 746, 747, 748] — equals
AES-NUM-243 exactly (printed test True). Gap
sequence: [512, 512, 512, 512, 512, 512, 512] —
equals AES-NUM-244 exactly (printed test True).

## (ii) The B closing run's combined sequences in full

The B closing run is ranks 743–750 in B-offset
order, 8 acts, walked in full in AES-NUM-240.
Every act matches its AES-NUM-240 per-act
statement (printed match True for all eight):

- 743: B 26 (1196368696, 280, 2) — size 280, channel 2, B-only distinct, run-102 False, offset 1196368696.
- 744: B 229 (1196369408, 26128, 2) — size 26128, channel 2, B-only distinct, run-102 False, offset 1196369408.
- 745: B 272 (1196396032, 14352, 1) — size 14352, channel 1, B-only distinct, run-102 False, offset 1196396032.
- 746: B 674 (1196410880, 32784, 2) — size 32784, channel 2, B-only distinct, run-102 False, offset 1196410880.
- 747: B 735 (1196444160, 24, 0) — size 24, channel 0, B-only distinct, run-102 False, offset 1196444160.
- 748: B 736 (1196444672, 24, 1) — size 24, channel 1, B-only distinct, run-102 False, offset 1196444672.
- 749: B 737 (1196445184, 24, 2) — size 24, channel 2, B-only distinct, run-102 False, offset 1196445184.
- 750: B 738 (1196445696, 24, 0) — size 24, channel 0, B-only distinct, run-102 False, offset 1196445696.

Size sequence: [280, 26128, 14352, 32784, 24, 24,
24, 24] — equals AES-NUM-241 exactly (printed test
True). Channel sequence: [2, 2, 1, 2, 0, 1, 2, 0]
— equals AES-NUM-241 exactly (printed test True).
Class sequence: [B-only distinct x8] — equals
AES-NUM-242 exactly (printed test True). Run-102
membership sequence: [False x8] — equals
AES-NUM-242 exactly (printed test True). Offset
sequence: [1196368696, 1196369408, 1196396032,
1196410880, 1196444160, 1196444672, 1196445184,
1196445696] — equals AES-NUM-243 exactly (printed
test True). Index sequence: [26, 229, 272, 674,
735, 736, 737, 738] — equals AES-NUM-243 exactly
(printed test True). Gap sequence: [712, 26624,
14848, 33280, 512, 512, 512] — equals AES-NUM-244
exactly (printed test True).

## (iii) The closing-run combined comparison in full

Sequence family by sequence family, whether each
pair of sequences is identical and the agreement
count over its positions, stated exactly:

- Size: A [24, 24, 24, 24, 24, 24, 24, 24] / B [280, 26128, 14352, 32784, 24, 24, 24, 24] — NOT identical; agree at 4 of 8 positions (5, 6, 7, 8).
- Channel: A [1, 2, 0, 0, 0, 1, 2, 0] / B [2, 2, 1, 2, 0, 1, 2, 0] — NOT identical; agree at 5 of 8 positions (2, 5, 6, 7, 8).
- Class: A [A-only distinct x3, shared single-positioned, A-only distinct x4] / B [B-only distinct x8] — NOT identical; agree at 0 of 8 positions (no positions).
- Run-102 membership: A [False, False, False, True, False, False, False, False] / B [False x8] — NOT identical; agree at 7 of 8 positions (1, 2, 3, 5, 6, 7, 8).
- Offset: A [791777280, 791777792, 791778304, 791778816, 791779328, 791779840, 791780352, 791780864] / B [1196368696, 1196369408, 1196396032, 1196410880, 1196444160, 1196444672, 1196445184, 1196445696] — NOT identical; agree at 0 of 8 positions (no positions).
- Index: A [734, 735, 736, 744, 745, 746, 747, 748] / B [26, 229, 272, 674, 735, 736, 737, 738] — NOT identical; agree at 0 of 8 positions (no positions).
- Gap: A [512, 512, 512, 512, 512, 512, 512] / B [712, 26624, 14848, 33280, 512, 512, 512] — NOT identical; agree at 3 of 7 positions (5, 6, 7).

Combined summary, stated exactly: no sequence
family is identical between the two closing
runs; agreement counts are size 4 of 8, channel
5 of 8, class 0 of 8, run-102 membership 7 of 8,
offset 0 of 8, index 0 of 8, gap 3 of 7.

Contract tests: each printed sequence equals the
sequence measured in its own slice (AES-NUM-241
size/channel, AES-NUM-242 class/run-102,
AES-NUM-243 offset/index, AES-NUM-244 gaps) —
True for all fourteen sequences; and each printed
agreement count equals that slice's printed
count — True for all seven families.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
