# The A and B closing runs' size and channel sequences, and the closing-run size/channel comparison (AES-NUM-241)

Slice 4.241, worked under `docs/TASK_CONTRACT_4.241.md`
(contract published in the 4.240 closing commit @
3e9c6db5). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section241.txt).

## Run and closing record

hef241.py is the verified hef240 base plus
arms241: hef240.py sha256
`32decec8391cf1a6b84928bc30eff0151b59a671e71a2fdb9411ed4743f52534`
(1,960,421 B) on both the VM and the device.
arms241 sha256
`2dbd74a284f90fc0cec664f1f75f1299164ae8818f9856715a446918d72d7c93`
(12,762 B); hef241.py sha256
`117f7197f2a1ec58267ef7117815f388f0ec31b71b85ed1a20b27a4c60eafa20`
(1,973,183 B) on both the VM and the device.
Crossing, stated exactly: arms241 was gzipped at
gzip -9 (sha256
`eedcb6392276e62a9c695b88d7fc51ecbb268e8c259c2a0f352a0b75575369cb`,
3,213 B) and split into nine 373 B parts (last
229 B); each part was written as its own file with
its own sha256 gate — all nine verified on-device
(one part, p_ae, was first sent with a corrupted
base64 re-emission, was rejected by its sha256
gate and discarded uncommitted, and a verbatim
resend landed clean; no byte was ever accepted
unverified). The assembled gzip, arms and hef241
shas == VM on-device; hef241 assembled on-device
from hef240.py + arms241.py, sha == VM, py_compile
OK. Pre-launch tmux/ps check found no hef241/h241
child; exactly ONE bounded host-side child ran in
detached tmux (session h241, created 2026-10-30
22:19:01 EDT) with the contract corpus argv (glob
order, MiniLM last), unbuffered (`python3 -u`),
and finished with exit marker 0 (hef241.exit),
err empty, and DONE241 as its last line. Output
hef241.out 58,187 lines / 10,553,510 B sha256
`a3d1c63edd49e8e30d89c30864a0fecf908c01326ade798de26b1806733800bc`;
prefix against hef240.out: the first 58,141
lines differ from hef240.out in exactly TWO lines
(lines 41611 and 42872, frozenset element order
only — the AES-NUM-150 variance, each verified by
same-sorted-characters comparison), hef241.out
adding exactly its own 46 section lines (8,378 B,
sha256
`53a4bc3401859d552162242d95245430d22d57fa923084e9f39aad42a44b00bc`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef241.out, hef241.py, arms241.py,
section241.txt, hef241.exit, run241.sh, gz241/,
check241.py); local lineage in
~/workspace/.verify-tmp/aesir241.

## (i) The A closing run's size and channel sequences in full

The A closing run is ranks 741–748 in A-offset
order, 8 acts, walked in full in AES-NUM-240.
Every act matches its AES-NUM-240 per-act
statement (printed match True for all eight):

- 741: A 734 (791777280, 24, 1) — size 24, channel 1.
- 742: A 735 (791777792, 24, 2) — size 24, channel 2.
- 743: A 736 (791778304, 24, 0) — size 24, channel 0.
- 744: A 744 (791778816, 24, 0) — size 24, channel 0.
- 745: A 745 (791779328, 24, 0) — size 24, channel 0.
- 746: A 746 (791779840, 24, 1) — size 24, channel 1.
- 747: A 747 (791780352, 24, 2) — size 24, channel 2.
- 748: A 748 (791780864, 24, 0) — size 24, channel 0.

Size sequence: [24, 24, 24, 24, 24, 24, 24, 24]
— equals the AES-NUM-240 read-off exactly
(printed test True). Channel sequence:
[1, 2, 0, 0, 0, 1, 2, 0] — equals the
AES-NUM-240 read-off exactly (printed test True).

## (ii) The B closing run's size and channel sequences in full

The B closing run is ranks 743–750 in B-offset
order, 8 acts, walked in full in AES-NUM-240.
Every act matches its AES-NUM-240 per-act
statement (printed match True for all eight):

- 743: B 26 (1196368696, 280, 2) — size 280, channel 2.
- 744: B 229 (1196369408, 26128, 2) — size 26128, channel 2.
- 745: B 272 (1196396032, 14352, 1) — size 14352, channel 1.
- 746: B 674 (1196410880, 32784, 2) — size 32784, channel 2.
- 747: B 735 (1196444160, 24, 0) — size 24, channel 0.
- 748: B 736 (1196444672, 24, 1) — size 24, channel 1.
- 749: B 737 (1196445184, 24, 2) — size 24, channel 2.
- 750: B 738 (1196445696, 24, 0) — size 24, channel 0.

Size sequence: [280, 26128, 14352, 32784, 24, 24,
24, 24] — equals the AES-NUM-240 read-off exactly
(printed test True). Channel sequence:
[2, 2, 1, 2, 0, 1, 2, 0] — equals the
AES-NUM-240 read-off exactly (printed test True).

## (iii) The closing-run size/channel comparison in full

Position by position (first through eighth act),
size on each side and whether the sizes agree at
that position; channel on each side and whether
the channels agree at that position:

- Position 1: A size 24 / B size 280 — disagree;
  A channel 1 / B channel 2 — disagree.
- Position 2: A size 24 / B size 26128 — disagree;
  A channel 2 / B channel 2 — agree.
- Position 3: A size 24 / B size 14352 — disagree;
  A channel 0 / B channel 1 — disagree.
- Position 4: A size 24 / B size 32784 — disagree;
  A channel 0 / B channel 2 — disagree.
- Position 5: A size 24 / B size 24 — agree;
  A channel 0 / B channel 0 — agree.
- Position 6: A size 24 / B size 24 — agree;
  A channel 1 / B channel 1 — agree.
- Position 7: A size 24 / B size 24 — agree;
  A channel 2 / B channel 2 — agree.
- Position 8: A size 24 / B size 24 — agree;
  A channel 0 / B channel 0 — agree.

Agreement counts, stated exactly: sizes agree at
4 of 8 positions (positions 5, 6, 7, 8); the size
sequences are NOT identical. Channels agree at
5 of 8 positions (positions 2, 5, 6, 7, 8); the
channel sequences are NOT identical.

Contract tests: each run's printed size and
channel sequences equal the sequences read off
the per-act statements of AES-NUM-232..239 as
re-stated in AES-NUM-240 — True on both sides,
for both sequences.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
