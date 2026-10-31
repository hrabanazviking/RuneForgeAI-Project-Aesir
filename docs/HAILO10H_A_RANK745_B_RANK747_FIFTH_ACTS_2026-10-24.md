# The acts at A-offset rank 745 and B-offset rank 747 in full, and the closing-run fifth-act comparison (AES-NUM-236)

Slice 4.236, worked under `docs/TASK_CONTRACT_4.236.md`
(contract published in the 4.235 closing commit @
95211b3f). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section236.txt).

## Run and closing record

hef236.py is the verified hef235 base plus
arms236: hef235.py sha256
`2f6932591b6c29601c4ffa18103cab2f10ce9fdfb7478eb2b8c07b4aa1a76e8a`
(1,892,449 B) on both the VM and the device.
arms236 sha256
`743d97e07d1b5ffc45b4ee3cb6e7b6ea022d4d2bba5dafaaa806ec693efd72b7`
(13,469 B); hef236.py sha256
`98d1d62bfac931656628682771dd05dfa2474f2640e3465e823cc915013d1b45`
(1,905,918 B) on both the VM and the device.
Crossing, stated exactly: arms236 was gzipped at
gzip -9 (sha256
`9b7853bbfa6997048620e1b7f344a4237c9ba1fa21961f1ce7dbbecbd7847ba0`,
3,229 B) and split into nine 373 B parts (last
245 B); each part was written as its own file with
its own sha256 gate — all nine verified on-device
first try; the assembled gzip, arms and hef236
shas == VM on-device; hef236 assembled on-device
from hef235.py + arms236.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef236/h236 child; exactly ONE bounded host-side
child ran in detached tmux (session h236, created
2026-10-30 20:33:07 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef236.exit), err empty, and DONE236 as its last
line. Output hef236.out 57,910 lines / 10,504,473 B
sha256
`9bf1b68c73221915b1e419188e0e2b6020824af8997e256a30b55f3e47017fa8`;
prefix against hef235.out: the first 57,842
lines differ from hef235.out in exactly TWO lines
(lines 41611 and 42872, frozenset element order
only — the AES-NUM-150 variance, verified by
same-sorted-characters comparison on both lines),
hef236.out adding exactly its own 68 section
lines (10,860 B, sha256
`3056396f1f3ccaf06b51dcdbf8ecad7640f0b5f8e6db983975773497b7e2cac5`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef236.out, hef236.py, arms236.py,
section236.txt, hef236.exit, run236.sh, gz236/,
check236.py); local lineage in
~/workspace/.verify-tmp/aesir236.

## (i) The act at A-offset rank 745 in full

The act (791779328, 24, 0) at A 745 is A-offset
rank 745 — the fifth act of the A closing run
(ranks 741–748). It occurs exactly once, on the
A side only: occurrences in A [745], in B none.
It is A-only distinct (absent from context B).
Its correspondence key (791779328, 24) is held
only by itself: no B-only act carries that key,
no B act of any kind carries it, and the only
act in either list with that key is itself.

Its incoming gap from rank 744 is +512 (from
(791778816, 24, 0) at A 744, rank 744) and its
outgoing gap to rank 746 is +512 (to
(791779840, 24, 1) at A 746, rank 746); neither
gap equals its own size (24). The A-offset
neighbourhood of rank 745 is: rank 742: A 735
(791777792, 24, 2) A-only; rank 743: A 736
(791778304, 24, 0) A-only; rank 744: A 744
(791778816, 24, 0) shared single-positioned
(run 102); rank 746: A 746 (791779840, 24, 1)
A-only; rank 747: A 747 (791780352, 24, 2)
A-only; rank 748: A 748 (791780864, 24, 0)
A-only. In A index order it follows A 744
immediately and precedes A 746 immediately —
and here, unlike the fourth act, its A-offset
neighbours are exactly its index neighbours on
both sides (predecessor A 744, successor A 746).

## (ii) The act at B-offset rank 747 in full

The act (1196444160, 24, 0) at B 735 is
B-offset rank 747 — the fifth act of the B
closing run (ranks 743–750). It occurs exactly
once: occurrences in A none, in B [735]. It is
B-only distinct (absent from context A). Its
correspondence key (1196444160, 24) is held
only by itself: no A-only act carries that key,
no A act of any kind carries it, and the only
act in either list with that key is itself.

Its incoming gap from rank 746 is +33,280 (from
(1196410880, 32784, 2) at B 674, rank 746) and
its outgoing gap to rank 748 is +512 (to
(1196444672, 24, 1) at B 736, rank 748); neither
gap equals its own size (24). The B-offset
neighbourhood of rank 747 is: rank 744: B 229
(1196369408, 26128, 2); rank 745: B 272
(1196396032, 14352, 1); rank 746: B 674
(1196410880, 32784, 2); rank 748: B 736
(1196444672, 24, 1); rank 749: B 737
(1196445184, 24, 2); rank 750: B 738
(1196445696, 24, 0) — each B-only distinct.
In B index order B 735 sits between B 734
(a shared act of run 102) and B 736 (its
offset successor); its offset-order predecessor
(B 674) is not its index-order neighbour.

## (iii) The closing-run fifth-act comparison in full

Side by side:

- A closing run fifth act: rank 745, index 745,
  act (791779328, 24, 0), class A-only
  distinct, in run 102 NO, incoming
  gap +512, outgoing gap +512.
- B closing run fifth act: rank 747, index 735,
  act (1196444160, 24, 0), class B-only
  distinct, in run 102 NO, incoming gap +33,280,
  outgoing gap +512.
- Contract tests: the A fifth act's outgoing gap
  (+512) equals the fifth gap of the A closing
  run's gap sequence as measured in AES-NUM-231
  (512) — YES; the B fifth act's outgoing gap
  (+512) equals the fifth gap of the B closing
  run's gap sequence as measured in AES-NUM-231
  (512) — YES.
- The two fifth acts differ in incoming gap
  (+512 vs +33,280) and in class label (A-only
  distinct vs B-only distinct), and they agree
  in run-102 membership (both NO) — and, for
  the first time in this closing-run comparison
  sequence, they AGREE in outgoing gap
  (+512 vs +512).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
