# The A and B closing runs' offset and index sequences, and the closing-run offset/index comparison (AES-NUM-243)

Slice 4.243, worked under `docs/TASK_CONTRACT_4.243.md`
(contract published in the 4.242 closing commit @
6f9ce1c8). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section243.txt).

## Run and closing record

hef243.py is the verified hef242 base plus
arms243: hef242.py sha256
`e07625ffa439dd97df00f0173ff26dd09f21b5d54ee0267870bee561b8313d83`
(1,987,612 B) on both the VM and the device.
arms243 sha256
`332d9f11a01b7e72efdecd578ea81e05e0b846793d9cfa2eedad21327834be8d`
(12,865 B); hef243.py sha256
`29bd382a45153cb2e837354b873efc8c47730d89f6d97a9a8c1c091d5a83ce14`
(2,000,477 B) on both the VM and the device.
Crossing, stated exactly: arms243 was gzipped at
gzip -9 (sha256
`c534c333178b33a1df1224d2e6a08d578f6efb62b5921e2eca9e3ff10cdceae3`,
3,254 B) and split into nine 373 B parts (last
270 B); each part was written as its own file with
its own sha256 gate — all nine verified on-device
on the first attempt; no byte was ever accepted
unverified. The assembled gzip, arms and hef243
shas == VM on-device; hef243 assembled on-device
from hef242.py + arms243.py, sha == VM, py_compile
OK. Pre-launch tmux/ps check found no hef243/h243
child; exactly ONE bounded host-side child ran in
detached tmux (session h243, created 2026-10-30
22:57:16 EDT) with the contract corpus argv (glob
order, MiniLM last), unbuffered (`python3 -u`),
and finished with exit marker 0 (hef243.exit),
err empty, and DONE243 as its last line. Output
hef243.out 58,279 lines / 10,573,474 B sha256
`27a6832512f26b8143dfe66a451e25416234f60b78112fb5052851ab6e05e9f2`;
prefix against hef242.out: the first 58,233
lines differ from hef242.out in exactly ONE line
(line 41611, frozenset element order only — the
AES-NUM-150 variance, verified by
same-sorted-characters comparison), hef243.out
adding exactly its own 46 section lines (8,414 B,
sha256
`c04350a7b675cd359aac63eddf317525827beac76f21209310ca8b8b704a87b2`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef243.out, hef243.py, arms243.py,
section243.txt, hef243.exit, run243.sh, gz243/,
check243.py); local lineage in
~/workspace/.verify-tmp/aesir243.

Definitions: an act's OFFSET is act[0]. An act's
INDEX is its index in its own context's act list
(actsA139 for A, actsB139 for B).

## (i) The A closing run's offset and index sequences in full

The A closing run is ranks 741–748 in A-offset
order, 8 acts, walked in full in AES-NUM-240.
Every act matches its AES-NUM-240 per-act
statement (printed match True for all eight):

- 741: A 734 (791777280, 24, 1) — offset 791777280.
- 742: A 735 (791777792, 24, 2) — offset 791777792.
- 743: A 736 (791778304, 24, 0) — offset 791778304.
- 744: A 744 (791778816, 24, 0) — offset 791778816.
- 745: A 745 (791779328, 24, 0) — offset 791779328.
- 746: A 746 (791779840, 24, 1) — offset 791779840.
- 747: A 747 (791780352, 24, 2) — offset 791780352.
- 748: A 748 (791780864, 24, 0) — offset 791780864.

Offset sequence: [791777280, 791777792, 791778304,
791778816, 791779328, 791779840, 791780352,
791780864] — equals the AES-NUM-240 read-off
exactly (printed test True). Index sequence:
[734, 735, 736, 744, 745, 746, 747, 748] — equals
the AES-NUM-240 read-off exactly (printed test
True).

## (ii) The B closing run's offset and index sequences in full

The B closing run is ranks 743–750 in B-offset
order, 8 acts, walked in full in AES-NUM-240.
Every act matches its AES-NUM-240 per-act
statement (printed match True for all eight):

- 743: B 26 (1196368696, 280, 2) — offset 1196368696.
- 744: B 229 (1196369408, 26128, 2) — offset 1196369408.
- 745: B 272 (1196396032, 14352, 1) — offset 1196396032.
- 746: B 674 (1196410880, 32784, 2) — offset 1196410880.
- 747: B 735 (1196444160, 24, 0) — offset 1196444160.
- 748: B 736 (1196444672, 24, 1) — offset 1196444672.
- 749: B 737 (1196445184, 24, 2) — offset 1196445184.
- 750: B 738 (1196445696, 24, 0) — offset 1196445696.

Offset sequence: [1196368696, 1196369408,
1196396032, 1196410880, 1196444160, 1196444672,
1196445184, 1196445696] — equals the AES-NUM-240
read-off exactly (printed test True). Index
sequence: [26, 229, 272, 674, 735, 736, 737, 738]
— equals the AES-NUM-240 read-off exactly
(printed test True).

## (iii) The closing-run offset/index comparison in full

Position by position (first through eighth act),
offset on each side and whether the offsets agree
at that position; index on each side and whether
the indices agree at that position:

- Position 1: A offset 791777280 / B offset 1196368696 — offset disagree; A index 734 / B index 26 — index disagree.
- Position 2: A offset 791777792 / B offset 1196369408 — offset disagree; A index 735 / B index 229 — index disagree.
- Position 3: A offset 791778304 / B offset 1196396032 — offset disagree; A index 736 / B index 272 — index disagree.
- Position 4: A offset 791778816 / B offset 1196410880 — offset disagree; A index 744 / B index 674 — index disagree.
- Position 5: A offset 791779328 / B offset 1196444160 — offset disagree; A index 745 / B index 735 — index disagree.
- Position 6: A offset 791779840 / B offset 1196444672 — offset disagree; A index 746 / B index 736 — index disagree.
- Position 7: A offset 791780352 / B offset 1196445184 — offset disagree; A index 747 / B index 737 — index disagree.
- Position 8: A offset 791780864 / B offset 1196445696 — offset disagree; A index 748 / B index 738 — index disagree.

Agreement counts, stated exactly: offsets agree at
0 of 8 positions (no positions); the offset
sequences are NOT identical. Indices agree at 0
of 8 positions (no positions); the index
sequences are NOT identical.

Contract tests: each run's printed offset and
index sequences equal the sequences read off the
per-act statements of AES-NUM-232..239 as
re-stated in AES-NUM-240 — True on both sides,
for both sequences.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
