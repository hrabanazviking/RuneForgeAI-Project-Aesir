# The A and B closing runs' internal gap sequences, and the closing-run gap comparison (AES-NUM-244)

Slice 4.244, worked under `docs/TASK_CONTRACT_4.244.md`
(contract published in the 4.243 closing commit @
bb2861a4). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section244.txt).

## Run and closing record

hef244.py is the verified hef243 base plus
arms244: hef243.py sha256
`29bd382a45153cb2e837354b873efc8c47730d89f6d97a9a8c1c091d5a83ce14`
(2,000,477 B) on both the VM and the device.
arms244 sha256
`b15a1c5248921d2559bcbe3881d5f3e40fab770389e53576a5e91abbead29b40`
(13,431 B); hef244.py sha256
`2d0d5ffcd15c7ce66f8b2405712feabef59b7021e836e97582be1701f784afaa`
(2,013,908 B) on both the VM and the device.
Crossing, stated exactly: arms244 was gzipped at
gzip -9 (sha256
`356507313a85670bb5cec4586393ba04c33734e0dac69506ea3335fd85ea7499`,
3,314 B) and split into nine 373 B parts (last
330 B); each part was written as its own file with
its own sha256 gate — all nine verified on-device
on the first attempt; no byte was ever accepted
unverified. The assembled gzip, arms and hef244
shas == VM on-device; hef244 assembled on-device
from hef243.py + arms244.py, sha == VM, py_compile
OK. Pre-launch tmux/ps check found no hef244/h244
child; exactly ONE bounded host-side child ran in
detached tmux (session h244, created 2026-10-30
23:16:07 EDT) with the contract corpus argv (glob
order, MiniLM last), unbuffered (`python3 -u`),
and finished with exit marker 0 (hef244.exit),
err empty, and DONE244 as its last line. Output
hef244.out 58,338 lines / 10,582,727 B sha256
`9cb8a45d29faae235ac18ac2ce5533e968cc5e084de77b2ee30d9380faf9a874`;
prefix against hef243.out: the first 58,279
lines differ from hef243.out in exactly ONE line
(line 41611, frozenset element order only — the
AES-NUM-150 variance, verified by
same-sorted-characters comparison), hef244.out
adding exactly its own 59 section lines (9,253 B,
sha256
`98956282d8dbfd59278e60fe3f9e18bb9c8014198db569294e126f8ab225eb57`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef244.out, hef244.py, arms244.py,
section244.txt, hef244.exit, run244.sh, gz244/,
check244.py); local lineage in
~/workspace/.verify-tmp/aesir244.

Definitions: an act's OFFSET is act[0]. A run's
INTERNAL GAP SEQUENCE is the seven gaps between
its eight consecutive acts in rank order, each
gap = the next act's offset minus this act's
offset.

## (i) The A closing run's internal gap sequence in full

The A closing run is ranks 741–748 in A-offset
order, 8 acts, walked in full in AES-NUM-240.
Every act matches its AES-NUM-240 per-act
statement (printed match True for all eight),
and its offset sequence equals the AES-NUM-243
read-off exactly (printed test True):

- Gap 1: rank 741 offset 791777280 → rank 742 offset 791777792 — gap 512.
- Gap 2: rank 742 offset 791777792 → rank 743 offset 791778304 — gap 512.
- Gap 3: rank 743 offset 791778304 → rank 744 offset 791778816 — gap 512.
- Gap 4: rank 744 offset 791778816 → rank 745 offset 791779328 — gap 512.
- Gap 5: rank 745 offset 791779328 → rank 746 offset 791779840 — gap 512.
- Gap 6: rank 746 offset 791779840 → rank 747 offset 791780352 — gap 512.
- Gap 7: rank 747 offset 791780352 → rank 748 offset 791780864 — gap 512.

Gap sequence: [512, 512, 512, 512, 512, 512,
512] — equals the AES-NUM-240 stated sequence
exactly (printed test True), and each printed
gap equals the difference of the corresponding
printed offsets from AES-NUM-243 (printed test
True for all seven).

## (ii) The B closing run's internal gap sequence in full

The B closing run is ranks 743–750 in B-offset
order, 8 acts, walked in full in AES-NUM-240.
Every act matches its AES-NUM-240 per-act
statement (printed match True for all eight),
and its offset sequence equals the AES-NUM-243
read-off exactly (printed test True):

- Gap 1: rank 743 offset 1196368696 → rank 744 offset 1196369408 — gap 712.
- Gap 2: rank 744 offset 1196369408 → rank 745 offset 1196396032 — gap 26624.
- Gap 3: rank 745 offset 1196396032 → rank 746 offset 1196410880 — gap 14848.
- Gap 4: rank 746 offset 1196410880 → rank 747 offset 1196444160 — gap 33280.
- Gap 5: rank 747 offset 1196444160 → rank 748 offset 1196444672 — gap 512.
- Gap 6: rank 748 offset 1196444672 → rank 749 offset 1196445184 — gap 512.
- Gap 7: rank 749 offset 1196445184 → rank 750 offset 1196445696 — gap 512.

Gap sequence: [712, 26624, 14848, 33280, 512,
512, 512] — equals the AES-NUM-240 stated
sequence exactly (printed test True), and each
printed gap equals the difference of the
corresponding printed offsets from AES-NUM-243
(printed test True for all seven).

## (iii) The closing-run gap comparison in full

Position by position (first through seventh
gap), gap on each side and whether the gaps
agree at that position:

- Position 1: A gap 512 / B gap 712 — disagree.
- Position 2: A gap 512 / B gap 26624 — disagree.
- Position 3: A gap 512 / B gap 14848 — disagree.
- Position 4: A gap 512 / B gap 33280 — disagree.
- Position 5: A gap 512 / B gap 512 — agree.
- Position 6: A gap 512 / B gap 512 — agree.
- Position 7: A gap 512 / B gap 512 — agree.

Agreement count, stated exactly: gaps agree at
3 of 7 positions (positions 5, 6, 7); the gap
sequences are NOT identical.

Contract tests: each run's printed gap sequence
equals the sequence stated in AES-NUM-240 as
measured in AES-NUM-231 — True on both sides;
and each printed gap equals the difference of
the corresponding printed offsets from
AES-NUM-243 — True for all fourteen gaps.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
