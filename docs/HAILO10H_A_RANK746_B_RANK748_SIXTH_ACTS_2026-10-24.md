# The acts at A-offset rank 746 and B-offset rank 748 in full, and the closing-run sixth-act comparison (AES-NUM-237)

Slice 4.237, worked under `docs/TASK_CONTRACT_4.237.md`
(contract published in the 4.236 closing commit @
a87acd0a). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section237.txt).

## Run and closing record

hef237.py is the verified hef236 base plus
arms237: hef236.py sha256
`98d1d62bfac931656628682771dd05dfa2474f2640e3465e823cc915013d1b45`
(1,905,918 B) on both the VM and the device.
arms237 sha256
`4c1e68bb7f99caf03ea998c4582fb694d5021843bb42ec06e1e470bbdec368bc`
(13,527 B); hef237.py sha256
`0718e21f57589ff051b3f0b982790e92dda971840cb641478ffdbdbc46822964`
(1,919,445 B) on both the VM and the device.
Crossing, stated exactly: arms237 was gzipped at
gzip -9 (sha256
`15545aced7984e02e72aeed6802eaaf6a83312716d582bf393b519e39d0e59de`,
3,242 B) and split into nine 373 B parts (last
258 B); each part was written as its own file with
its own sha256 gate — all nine verified on-device
first try; the assembled gzip, arms and hef237
shas == VM on-device; hef237 assembled on-device
from hef236.py + arms237.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef237/h237 child; exactly ONE bounded host-side
child ran in detached tmux (session h237, created
2026-10-30 20:58:24 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef237.exit), err empty, and DONE237 as its last
line. Output hef237.out 57,975 lines / 10,514,954 B
sha256
`7ff06fcb7be0f67b0d9a740e5d6aa5d61b958282e79b21038604cface2fe7446`;
prefix against hef236.out: the first 57,910
lines are IDENTICAL to hef236.out in every line
(zero differing lines — the AES-NUM-150 frozenset
element-order variance did not occur in this run),
hef237.out adding exactly its own 65 section
lines (10,481 B, sha256
`279cda1700c658db4366101290786b3386875a48e7346ec71cd014f70f6c2646`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef237.out, hef237.py, arms237.py,
section237.txt, hef237.exit, run237.sh, gz237/,
check237.py); local lineage in
~/workspace/.verify-tmp/aesir237.

## (i) The act at A-offset rank 746 in full

The act (791779840, 24, 1) at A 746 is A-offset
rank 746 — the sixth act of the A closing run
(ranks 741–748). It occurs exactly once, on the
A side only: occurrences in A [746], in B none.
It is A-only distinct (absent from context B).
Its correspondence key (791779840, 24) is held
only by itself: no B-only act carries that key,
no B act of any kind carries it, and the only
act in either list with that key is itself.

Its incoming gap from rank 745 is +512 (from
(791779328, 24, 0) at A 745, rank 745) and its
outgoing gap to rank 747 is +512 (to
(791780352, 24, 2) at A 747, rank 747); neither
gap equals its own size (24). The A-offset
neighbourhood of rank 746 is: rank 743: A 736
(791778304, 24, 0) A-only; rank 744: A 744
(791778816, 24, 0) shared single-positioned
(run 102); rank 745: A 745 (791779328, 24, 0)
A-only; rank 747: A 747 (791780352, 24, 2)
A-only; rank 748: A 748 (791780864, 24, 0)
A-only. In A index order it follows A 745
immediately and precedes A 747 immediately —
its A-offset neighbours are exactly its index
neighbours on both sides (predecessor A 745,
successor A 747), as with the fifth act.

## (ii) The act at B-offset rank 748 in full

The act (1196444672, 24, 1) at B 736 is
B-offset rank 748 — the sixth act of the B
closing run (ranks 743–750). It occurs exactly
once: occurrences in A none, in B [736]. It is
B-only distinct (absent from context A). Its
correspondence key (1196444672, 24) is held
only by itself: no A-only act carries that key,
no A act of any kind carries it, and the only
act in either list with that key is itself.

Its incoming gap from rank 747 is +512 (from
(1196444160, 24, 0) at B 735, rank 747) and
its outgoing gap to rank 749 is +512 (to
(1196445184, 24, 2) at B 737, rank 749); neither
gap equals its own size (24). The B-offset
neighbourhood of rank 748 is: rank 745: B 272
(1196396032, 14352, 1); rank 746: B 674
(1196410880, 32784, 2); rank 747: B 735
(1196444160, 24, 0); rank 749: B 737
(1196445184, 24, 2); rank 750: B 738
(1196445696, 24, 0) — each B-only distinct.
In B index order B 736 sits between B 735 and
B 737 — here, unlike the fifth act, its
offset-order neighbours are exactly its
index-order neighbours on both sides
(predecessor B 735, successor B 737).

## (iii) The closing-run sixth-act comparison in full

Side by side:

- A closing run sixth act: rank 746, index 746,
  act (791779840, 24, 1), class A-only
  distinct, in run 102 NO, incoming
  gap +512, outgoing gap +512.
- B closing run sixth act: rank 748, index 736,
  act (1196444672, 24, 1), class B-only
  distinct, in run 102 NO, incoming gap +512,
  outgoing gap +512.
- Contract tests: the A sixth act's outgoing gap
  (+512) equals the sixth gap of the A closing
  run's gap sequence as measured in AES-NUM-231
  (512) — YES; the B sixth act's outgoing gap
  (+512) equals the sixth gap of the B closing
  run's gap sequence as measured in AES-NUM-231
  (512) — YES.
- The two sixth acts differ only in class label
  (A-only distinct vs B-only distinct); they
  agree in run-102 membership (both NO), in
  incoming gap (+512 vs +512 — where the fifth
  acts' incoming gaps differed), and in outgoing
  gap (+512 vs +512).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
