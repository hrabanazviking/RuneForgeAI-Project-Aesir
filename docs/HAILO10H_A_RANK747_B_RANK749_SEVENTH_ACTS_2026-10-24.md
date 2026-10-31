# The acts at A-offset rank 747 and B-offset rank 749 in full, and the closing-run seventh-act comparison (AES-NUM-238)

Slice 4.238, worked under `docs/TASK_CONTRACT_4.238.md`
(contract published in the 4.237 closing commit @
f5125e16). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section238.txt).

## Run and closing record

hef238.py is the verified hef237 base plus
arms238: hef237.py sha256
`0718e21f57589ff051b3f0b982790e92dda971840cb641478ffdbdbc46822964`
(1,919,445 B) on both the VM and the device.
arms238 sha256
`2a16c3110675502f40d4b1d3964b4f130ebc0a0ca35dbda8597c18e3d8386001`
(13,562 B); hef238.py sha256
`448fa3f1981524ac4ff6405abb487adcf1b11951336e71fbf8d2dc9296401d30`
(1,933,007 B) on both the VM and the device.
Crossing, stated exactly: arms238 was gzipped at
gzip -9 (sha256
`5fc9255e0e2ff4abe81bd9e83efd476691bb6700a4445400a91c35ffd39f1362`,
3,254 B) and split into nine 373 B parts (last
270 B); each part was written as its own file with
its own sha256 gate — all nine verified on-device
first try; the assembled gzip, arms and hef238
shas == VM on-device; hef238 assembled on-device
from hef237.py + arms238.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef238/h238 child; exactly ONE bounded host-side
child ran in detached tmux (session h238, created
2026-10-30 21:13:27 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef238.exit), err empty, and DONE238 as its last
line. Output hef238.out 58,037 lines / 10,525,060 B
sha256
`c7b8c9f18c72bfccda69bfa0a42e6cb27d64ac23d5c7908674acd95a8571623b`;
prefix against hef237.out: the first 57,975
lines differ from hef237.out in exactly ONE line
(line 41611, frozenset element order only — the
AES-NUM-150 variance, verified by same-sorted-
characters comparison), hef238.out adding exactly
its own 62 section lines (10,106 B, sha256
`919795290ebc4d7061643af0e31820c0879bd11d50abef05f51a9d42ff3c3121`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef238.out, hef238.py, arms238.py,
section238.txt, hef238.exit, run238.sh, gz238/,
check238.py); local lineage in
~/workspace/.verify-tmp/aesir238.

## Known defect in the printed comparison (iii)

One field of the printed (iii) comparison is a
script defect in arms238, recorded here openly
and NOT rerun (one launch per contract): the
comparison's B incoming gap was computed against
the act at B-offset rank 749 — the B seventh act
itself (bsorted238[749]) — instead of its
predecessor at rank 748, so the comparison line
prints B incoming +0 and "incoming gaps identical
False". The B seventh act's true incoming gap is
established inside the same run by the (ii)
RANK 749 STATEMENT (+512, from (1196444672, 24, 1)
at B 736, rank 748) and by direct arithmetic on
the printed offsets (1196445184 − 1196444672 =
512). All (iii) findings below use the corrected
value; the comparison's remaining fields
(outgoing gaps, classes, run-102 membership, and
both AES-NUM-231 seventh-gap tests) are unaffected
and stand as printed. The 4.239 contract carries
the fix: comparison gap fields must be computed
from the same predecessor/successor ranks as the
per-act statements, with a printed consistency
check between the two.

## (i) The act at A-offset rank 747 in full

The act (791780352, 24, 2) at A 747 is A-offset
rank 747 — the seventh act of the A closing run
(ranks 741–748). It occurs exactly once, on the
A side only: occurrences in A [747], in B none.
It is A-only distinct (absent from context B).
Its correspondence key (791780352, 24) is held
only by itself: no B-only act carries that key,
no B act of any kind carries it, and the only
act in either list with that key is itself.

Its incoming gap from rank 746 is +512 (from
(791779840, 24, 1) at A 746, rank 746) and its
outgoing gap to rank 748 is +512 (to
(791780864, 24, 0) at A 748, rank 748); neither
gap equals its own size (24). The A-offset
neighbourhood of rank 747 is: rank 744: A 744
(791778816, 24, 0) shared single-positioned
(run 102); rank 745: A 745 (791779328, 24, 0)
A-only; rank 746: A 746 (791779840, 24, 1)
A-only; rank 748: A 748 (791780864, 24, 0)
A-only. In A index order it follows A 746
immediately and precedes A 748 immediately —
its A-offset neighbours are exactly its index
neighbours on both sides (predecessor A 746,
successor A 748), as with the sixth act.

## (ii) The act at B-offset rank 749 in full

The act (1196445184, 24, 2) at B 737 is
B-offset rank 749 — the seventh act of the B
closing run (ranks 743–750). It occurs exactly
once: occurrences in A none, in B [737]. It is
B-only distinct (absent from context A). Its
correspondence key (1196445184, 24) is held
only by itself: no A-only act carries that key,
no A act of any kind carries it, and the only
act in either list with that key is itself.

Its incoming gap from rank 748 is +512 (from
(1196444672, 24, 1) at B 736, rank 748) and
its outgoing gap to rank 750 is +512 (to
(1196445696, 24, 0) at B 738, rank 750); neither
gap equals its own size (24). The B-offset
neighbourhood of rank 749 is: rank 746: B 674
(1196410880, 32784, 2); rank 747: B 735
(1196444160, 24, 0); rank 748: B 736
(1196444672, 24, 1); rank 750: B 738
(1196445696, 24, 0) — each B-only distinct.
In B index order B 737 sits between B 736 and
B 738 — its offset-order neighbours are exactly
its index-order neighbours on both sides
(predecessor B 736, successor B 738), as with
the sixth act.

## (iii) The closing-run seventh-act comparison in full

Side by side (B incoming gap corrected per the
defect note above; the printed comparison line
carries +0 there for the stated reason):

- A closing run seventh act: rank 747, index 747,
  act (791780352, 24, 2), class A-only
  distinct, in run 102 NO, incoming
  gap +512, outgoing gap +512.
- B closing run seventh act: rank 749, index 737,
  act (1196445184, 24, 2), class B-only
  distinct, in run 102 NO, incoming gap +512,
  outgoing gap +512.
- Contract tests: the A seventh act's outgoing gap
  (+512) equals the seventh gap of the A closing
  run's gap sequence as measured in AES-NUM-231
  (512) — YES; the B seventh act's outgoing gap
  (+512) equals the seventh gap of the B closing
  run's gap sequence as measured in AES-NUM-231
  (512) — YES.
- The two seventh acts differ only in class label
  (A-only distinct vs B-only distinct); they
  agree in run-102 membership (both NO), in
  incoming gap (+512 vs +512), and in outgoing
  gap (+512 vs +512) — the same full-gap
  agreement the sixth acts showed.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
