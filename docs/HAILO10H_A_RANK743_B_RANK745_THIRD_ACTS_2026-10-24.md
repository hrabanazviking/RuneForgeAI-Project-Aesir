# The acts at A-offset rank 743 and B-offset rank 745 in full, and the closing-run third-act comparison (AES-NUM-234)

Slice 4.234, worked under `docs/TASK_CONTRACT_4.234.md`
(contract published in the 4.233 closing commit @
d56be653). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section234.txt).

## Run and closing record

hef234.py is the verified hef233 base plus
arms234: hef233.py sha256
`325e58ca7be9cceba70907544f17d7a043bb02922469c890e55b8a70bb292b28`
(1,865,479 B) on both the VM and the device.
arms234 sha256
`abfbb5e69f02985b3f74838e8ca959e5c590501406249557472c723637516008`
(13,476 B); hef234.py sha256
`c59c2dccc7284e7ed93aeb464f69125ab181cd99078495a7bc41f53388dab8cc`
(1,878,955 B) on both the VM and the device.
Crossing, stated exactly: arms234 was gzipped at
gzip -9 (sha256
`6b71860a6100354c194629a9acd16537910b5f67fe88b957026249e1a9f0835f`,
3,254 B) and split into nine 373 B parts (last
270 B); each part was written as its own file with
its own sha256 gate — all nine verified on-device
first try; the assembled gzip, arms and hef234
shas == VM on-device; hef234 assembled on-device
from hef233.py + arms234.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef234/h234 child; exactly ONE bounded host-side
child ran in detached tmux (session h234, created
2026-10-30 19:57:05 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`); a duplicate tmux launch attempt
by this worker was refused by tmux (duplicate
session) and started no second child. The child
finished with exit marker 0 (hef234.exit), err
empty, and DONE234 as its last line. Output
hef234.out 57,772 lines / 10,482,446 B sha256
`ddea83ae7c9a5d12e10d43ea3145e46e528ddc17a7fa2da344b1b1c8b5451abe`;
prefix against hef233.out: the first 57,702
lines differ from hef233.out in exactly TWO lines
(lines 41611 and 42872, frozenset element order
only — the AES-NUM-150 variance, verified by
same-sorted-characters comparison on both lines),
hef234.out adding exactly its own 70 section
lines (11,202 B, sha256
`b631e1f13d29faba6e3218df746c1161c2944ce1bc6e7e53faa8c0a74979349d`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef234.out, hef234.py, arms234.py,
section234.txt, hef234.exit, run234.sh, gz234/,
check234.py); local lineage in
~/workspace/.verify-tmp/aesir234.

## (i) The act at A-offset rank 743 in full

The act (791778304, 24, 0) at A 736 is A-offset
rank 743 — the third act of the A closing run
(ranks 741–748). It occurs exactly once:
occurrences in A [736], in B none. It is
A-only distinct (absent from context B). Its
correspondence key (791778304, 24) is held
only by itself: no B-only act carries that key,
and the only act in either list with that key is
itself.

Its incoming gap from rank 742 is +512 (from
(791777792, 24, 2) at A 735, rank 742) and its
outgoing gap to rank 744 is +512 (to
(791778816, 24, 0) at A 744, rank 744); neither
gap equals its own size (24). The A-offset
neighbourhood of rank 743 is: rank 740: A 733
(791776792, 24, 0) A-only; rank 741: A 734
(791777280, 24, 1) A-only; rank 742: A 735
(791777792, 24, 2) A-only; rank 744: A 744
(791778816, 24, 0) shared single-positioned
(run 102); rank 745: A 745 (791779328, 24, 0)
A-only; rank 746: A 746 (791779840, 24, 1)
A-only. In A index order it follows A 735
immediately and precedes A 737 immediately;
its offset-order neighbours are A 735 before
(same as index order) and A 744 after (not its
index-order successor).

## (ii) The act at B-offset rank 745 in full

The act (1196396032, 14352, 1) at B 272 is
B-offset rank 745 — the third act of the B
closing run (ranks 743–750). It occurs exactly
once: occurrences in A none, in B [272]. It is
B-only distinct (absent from context A). Its
correspondence key (1196396032, 14352) is held
only by itself: no A-only act carries that key,
and the only act in either list with that key is
itself.

Its incoming gap from rank 744 is +26,624 (from
(1196369408, 26128, 2) at B 229, rank 744) and
its outgoing gap to rank 746 is +14,848 (to
(1196410880, 32784, 2) at B 674, rank 746);
neither gap equals its own size (14352). The
B-offset neighbourhood of rank 745 is: rank 742:
B 25 (1196338688, 30008, 2); rank 743: B 26
(1196368696, 280, 2); rank 744: B 229
(1196369408, 26128, 2); rank 746: B 674
(1196410880, 32784, 2); rank 747: B 735
(1196444160, 24, 0); rank 748: B 736
(1196444672, 24, 1) — each B-only distinct.
In B index order B 272 sits between B 271 and
B 273 (shared acts of other runs); its
offset-order neighbours (B 229 before, B 674
after) are not its index-order neighbours on
either side.

## (iii) The closing-run third-act comparison in full

Side by side:

- A closing run third act: rank 743, index 736,
  act (791778304, 24, 0), class A-only distinct,
  in run 102 NO, incoming gap +512, outgoing
  gap +512.
- B closing run third act: rank 745, index 272,
  act (1196396032, 14352, 1), class B-only
  distinct, in run 102 NO, incoming gap +26,624,
  outgoing gap +14,848.
- Contract tests: the A third act's outgoing gap
  (+512) equals the third gap of the A closing
  run's gap sequence as measured in AES-NUM-231
  (512) — YES; the B third act's outgoing gap
  (+14,848) equals the third gap of the B closing
  run's gap sequence as measured in AES-NUM-231
  (14848) — YES.
- The two third acts agree in neither incoming
  gap (+512 vs +26,624), nor outgoing gap (+512
  vs +14,848), nor class label (A-only vs B-only
  distinct, the side-specific labels); they
  agree in run-102 membership only in that
  neither is a member.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
