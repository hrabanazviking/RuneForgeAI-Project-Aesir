# The acts at A-offset rank 744 and B-offset rank 746 in full, and the closing-run fourth-act comparison (AES-NUM-235)

Slice 4.235, worked under `docs/TASK_CONTRACT_4.235.md`
(contract published in the 4.234 closing commit @
46bd97da). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section235.txt).

## Run and closing record

hef235.py is the verified hef234 base plus
arms235: hef234.py sha256
`c59c2dccc7284e7ed93aeb464f69125ab181cd99078495a7bc41f53388dab8cc`
(1,878,955 B) on both the VM and the device.
arms235 sha256
`f421351feb67a22b2007f74bf61a3a03edb813a78a63a2a4074687df484bf657`
(13,494 B); hef235.py sha256
`2f6932591b6c29601c4ffa18103cab2f10ce9fdfb7478eb2b8c07b4aa1a76e8a`
(1,892,449 B) on both the VM and the device.
Crossing, stated exactly: arms235 was gzipped at
gzip -9 (sha256
`63264f40c74dc4650c558850273e971ff57f66f2695e68f0062c02733f242aa2`,
3,243 B) and split into nine 373 B parts (last
259 B); each part was written as its own file with
its own sha256 gate — all nine verified on-device
first try; the assembled gzip, arms and hef235
shas == VM on-device; hef235 assembled on-device
from hef234.py + arms235.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef235/h235 child; exactly ONE bounded host-side
child ran in detached tmux (session h235, created
2026-10-30 20:18:06 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef235.exit), err empty, and DONE235 as its last
line. Output hef235.out 57,842 lines / 10,493,613 B
sha256
`84875faf00e267bd3bc0cff89052cb6e2f15e3290d9a3340f04021dccd957ffa`;
prefix against hef234.out: the first 57,772
lines differ from hef234.out in exactly TWO lines
(lines 41611 and 42872, frozenset element order
only — the AES-NUM-150 variance, verified by
same-sorted-characters comparison on both lines),
hef235.out adding exactly its own 70 section
lines (11,167 B, sha256
`47023b8d66d40405f2500df3f5a876574456a6cbf04f383a8d334f61b4ccd065`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef235.out, hef235.py, arms235.py,
section235.txt, hef235.exit, run235.sh, gz235/,
check235.py); local lineage in
~/workspace/.verify-tmp/aesir235.

## (i) The act at A-offset rank 744 in full

The act (791778816, 24, 0) at A 744 is A-offset
rank 744 — the fourth act of the A closing run
(ranks 741–748). It occurs exactly once in each
context: occurrences in A [744], in B [746]. It
is shared single-positioned (run 102, shift +2;
shared placement A pos 744, B pos 746), a member
of run 102, and — per the run-102 control and
AES-NUM-230 — run 102's last act. Its
correspondence key (791778816, 24) is held only
by itself on each side: no A-only or B-only act
carries that key, and the only act in either
list with that key is itself. It is the sole
shared single-positioned act in the A closing
run (AES-NUM-231 composition: 7 A-only + this 1
shared).

Its incoming gap from rank 743 is +512 (from
(791778304, 24, 0) at A 736, rank 743) and its
outgoing gap to rank 745 is +512 (to
(791779328, 24, 0) at A 745, rank 745); neither
gap equals its own size (24). The A-offset
neighbourhood of rank 744 is: rank 741: A 734
(791777280, 24, 1) A-only; rank 742: A 735
(791777792, 24, 2) A-only; rank 743: A 736
(791778304, 24, 0) A-only; rank 745: A 745
(791779328, 24, 0) A-only; rank 746: A 746
(791779840, 24, 1) A-only; rank 747: A 747
(791780352, 24, 2) A-only. In A index order it
follows A 743 immediately and precedes A 745
immediately; its A-offset successor A 745 is
also its A index successor, while its
A-offset predecessor is A 736, not its index
predecessor A 743.

## (ii) The act at B-offset rank 746 in full

The act (1196410880, 32784, 2) at B 674 is
B-offset rank 746 — the fourth act of the B
closing run (ranks 743–750). It occurs exactly
once: occurrences in A none, in B [674]. It is
B-only distinct (absent from context A). Its
correspondence key (1196410880, 32784) is held
only by itself: no A-only act carries that key,
no A act of any kind carries it, and the only
act in either list with that key is itself.

Its incoming gap from rank 745 is +14,848 (from
(1196396032, 14352, 1) at B 272, rank 745) and
its outgoing gap to rank 747 is +33,280 (to
(1196444160, 24, 0) at B 735, rank 747); neither
gap equals its own size (32784). The B-offset
neighbourhood of rank 746 is: rank 743: B 26
(1196368696, 280, 2); rank 744: B 229
(1196369408, 26128, 2); rank 745: B 272
(1196396032, 14352, 1); rank 747: B 735
(1196444160, 24, 0); rank 748: B 736
(1196444672, 24, 1); rank 749: B 737
(1196445184, 24, 2) — each B-only distinct.
In B index order B 674 sits between B 673 and
B 675 (shared acts of other runs); its
offset-order neighbours (B 272 before, B 735
after) are not its index-order neighbours on
either side.

## (iii) The closing-run fourth-act comparison in full

Side by side:

- A closing run fourth act: rank 744, index 744,
  act (791778816, 24, 0), class shared
  single-positioned, in run 102 YES, incoming
  gap +512, outgoing gap +512.
- B closing run fourth act: rank 746, index 674,
  act (1196410880, 32784, 2), class B-only
  distinct, in run 102 NO, incoming gap +14,848,
  outgoing gap +33,280.
- Contract tests: the A fourth act's outgoing gap
  (+512) equals the fourth gap of the A closing
  run's gap sequence as measured in AES-NUM-231
  (512) — YES; the B fourth act's outgoing gap
  (+33,280) equals the fourth gap of the B closing
  run's gap sequence as measured in AES-NUM-231
  (33280) — YES.
- The two fourth acts agree in neither incoming
  gap (+512 vs +14,848), nor outgoing gap (+512
  vs +33,280), nor class label (shared
  single-positioned vs B-only distinct); and —
  unlike the third acts — they differ in run-102
  membership too (YES vs NO).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
