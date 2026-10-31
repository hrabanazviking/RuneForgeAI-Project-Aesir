# The A and B closing runs' class and run-102 membership sequences, and the closing-run class/run-102 comparison (AES-NUM-242)

Slice 4.242, worked under `docs/TASK_CONTRACT_4.242.md`
(contract published in the 4.241 closing commit @
687a2e80). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section242.txt).

## Run and closing record

hef242.py is the verified hef241 base plus
arms242: hef241.py sha256
`117f7197f2a1ec58267ef7117815f388f0ec31b71b85ed1a20b27a4c60eafa20`
(1,973,183 B) on both the VM and the device.
arms242 sha256
`2dae8b05c3dde56e0bf861c359c4b62b691d567500b9f41ca323a08670e080c2`
(14,429 B); hef242.py sha256
`e07625ffa439dd97df00f0173ff26dd09f21b5d54ee0267870bee561b8313d83`
(1,987,612 B) on both the VM and the device.
Crossing, stated exactly: arms242 was gzipped at
gzip -9 (sha256
`3617fa640f42f496cbb04395135b194ee4acc102a621d14f1dcd2d96e2894c44`,
3,509 B) and split into ten 373 B parts (last
152 B); each part was written as its own file with
its own sha256 gate — all ten verified on-device
on the first attempt; no byte was ever accepted
unverified. The assembled gzip, arms and hef242
shas == VM on-device; hef242 assembled on-device
from hef241.py + arms242.py, sha == VM, py_compile
OK. Pre-launch tmux/ps check found no hef242/h242
child; exactly ONE bounded host-side child ran in
detached tmux (session h242, created 2026-10-30
22:34:51 EDT) with the contract corpus argv (glob
order, MiniLM last), unbuffered (`python3 -u`),
and finished with exit marker 0 (hef242.exit),
err empty, and DONE242 as its last line. Output
hef242.out 58,233 lines / 10,565,060 B sha256
`059dfa5ad50f2b83dc4e2895d6badada8cdb35ba3406c2dd3800bd1a4f3dc057`;
prefix against hef241.out: the first 58,187
lines differ from hef241.out in exactly ONE line
(line 41611, frozenset element order only — the
AES-NUM-150 variance, verified by
same-sorted-characters comparison), hef242.out
adding exactly its own 46 section lines (11,550 B,
sha256
`46f5b26b076e9fb8c392ecc4e6d92eb2e041a52f044d3c088b022d73b1fb0ca1`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef242.out, hef242.py, arms242.py,
section242.txt, hef242.exit, run242.sh, gz242/,
check242.py); local lineage in
~/workspace/.verify-tmp/aesir242.

Definitions: an act's BASE CLASS is its class3
label with any run/shift detail stripped (the text
before the first opening parenthesis, stripped).
An act's RUN-102 MEMBERSHIP is True if the act is
a member of secondary run 102 (sruns139[102]) and
False otherwise.

## (i) The A closing run's class and run-102 membership sequences in full

The A closing run is ranks 741–748 in A-offset
order, 8 acts, walked in full in AES-NUM-240.
Every act matches its AES-NUM-240 per-act
statement (printed match True for all eight):

- 741: A 734 (791777280, 24, 1) — A-only distinct, run-102 False.
- 742: A 735 (791777792, 24, 2) — A-only distinct, run-102 False.
- 743: A 736 (791778304, 24, 0) — A-only distinct, run-102 False.
- 744: A 744 (791778816, 24, 0) — shared single-positioned (run 102, shift +2), run-102 True.
- 745: A 745 (791779328, 24, 0) — A-only distinct, run-102 False.
- 746: A 746 (791779840, 24, 1) — A-only distinct, run-102 False.
- 747: A 747 (791780352, 24, 2) — A-only distinct, run-102 False.
- 748: A 748 (791780864, 24, 0) — A-only distinct, run-102 False.

Class sequence: [A-only distinct, A-only distinct,
A-only distinct, shared single-positioned, A-only
distinct, A-only distinct, A-only distinct,
A-only distinct] — equals the AES-NUM-240 read-off
exactly (printed test True). Run-102 membership
sequence: [False, False, False, True, False,
False, False, False] — equals the AES-NUM-240
read-off exactly (printed test True).

## (ii) The B closing run's class and run-102 membership sequences in full

The B closing run is ranks 743–750 in B-offset
order, 8 acts, walked in full in AES-NUM-240.
Every act matches its AES-NUM-240 per-act
statement (printed match True for all eight):

- 743: B 26 (1196368696, 280, 2) — B-only distinct, run-102 False.
- 744: B 229 (1196369408, 26128, 2) — B-only distinct, run-102 False.
- 745: B 272 (1196396032, 14352, 1) — B-only distinct, run-102 False.
- 746: B 674 (1196410880, 32784, 2) — B-only distinct, run-102 False.
- 747: B 735 (1196444160, 24, 0) — B-only distinct, run-102 False.
- 748: B 736 (1196444672, 24, 1) — B-only distinct, run-102 False.
- 749: B 737 (1196445184, 24, 2) — B-only distinct, run-102 False.
- 750: B 738 (1196445696, 24, 0) — B-only distinct, run-102 False.

Class sequence: [B-only distinct x8] — equals the
AES-NUM-240 read-off exactly (printed test True).
Run-102 membership sequence: [False x8] — equals
the AES-NUM-240 read-off exactly (printed test
True).

## (iii) The closing-run class/run-102 comparison in full

Position by position (first through eighth act),
class on each side and whether the classes agree
at that position; run-102 membership on each side
and whether the memberships agree at that
position:

- Position 1: A A-only distinct / B B-only distinct — class disagree; A False / B False — membership agree.
- Position 2: A A-only distinct / B B-only distinct — class disagree; A False / B False — membership agree.
- Position 3: A A-only distinct / B B-only distinct — class disagree; A False / B False — membership agree.
- Position 4: A shared single-positioned / B B-only distinct — class disagree; A True / B False — membership disagree.
- Position 5: A A-only distinct / B B-only distinct — class disagree; A False / B False — membership agree.
- Position 6: A A-only distinct / B B-only distinct — class disagree; A False / B False — membership agree.
- Position 7: A A-only distinct / B B-only distinct — class disagree; A False / B False — membership agree.
- Position 8: A A-only distinct / B B-only distinct — class disagree; A False / B False — membership agree.

Agreement counts, stated exactly: classes agree at
0 of 8 positions (no positions); the class
sequences are NOT identical. Run-102 memberships
agree at 7 of 8 positions (positions 1, 2, 3, 5,
6, 7, 8); the run-102 membership sequences are
NOT identical.

Contract tests: each run's printed class and
run-102 membership sequences equal the sequences
read off the per-act statements of AES-NUM-232..239
as re-stated in AES-NUM-240 — True on both sides,
for both sequences.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
