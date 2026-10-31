# The acts at A-offset ranks 748 and 744 in full, and the cross-order census comparison (AES-NUM-230)

Slice 4.230, worked under `docs/TASK_CONTRACT_4.230.md`
(contract published in the 4.229 closing commit @
3c54eb07). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section230.txt).

## Run and closing record

hef230.py is the verified hef229 base plus
arms230: hef229.py sha256
`9f4beeb831e78148ca1e6a4f424a03cd48a14ca8e47c5e386d22786f9035bbc8`
(1,811,474 B) on both the VM and the device.
arms230 sha256
`171c6c610e6f37ab98f79291a1dfc5c20cecdf3f5915dd5279307bb66a6ed6ae`
(14,011 B); hef230.py sha256
`528eaccb163c10c6961f1988e61d335f0429e06b644f6166476cd2ddefe7b30b`
(1,825,485 B) on both the VM and the device.
Crossing, stated exactly: arms230 was gzipped at
gzip -9 (sha256
`8afd46f4fa0710ca1af1aae26bb6f121cb15a3481280ce8f61ff36916448e0e7`,
3,327 B) and split into nine 373 B parts (last
343 B); each part was written as its own file with
its own sha256 gate — all nine verified on-device
first try; the assembled gzip, arms and hef230
shas == VM on-device; hef230 assembled on-device
from hef229.py + arms230.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef230/h230 child; exactly ONE bounded host-side
child ran in detached tmux (session h230, created
2026-10-30 18:45:42 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef230.exit), err empty, and DONE230 as
its last line. Output hef230.out 57,480 lines /
10,436,154 B sha256
`65206f870fda718dd245c1b007c4f875bb852810fcb6fc15e9ecbab6085d4982`;
prefix against hef229.out: the first 57,412
lines differ from hef229.out in exactly ONE line
(line 41611, frozenset element order only — the
AES-NUM-150 variance, verified this run by
same-sorted-characters comparison), hef230.out
adding exactly its own 68 section lines (10,081 B,
sha256
`8dd9d0bfa04ac4c6567450b7266cdde74f9bc1c229cb5528314855746aeb8c4f`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef230.out, hef230.py, arms230.py,
section230.txt, hef230.exit, run230.sh, gz230/,
check230.py); local lineage in
~/workspace/.verify-tmp/aesir230.

## (i) The act at A-offset rank 748 in full

The act (791780864, 24, 0) at A 748 is A-offset
rank 748 — the last measured A-offset rank (A
acts 749, ranks 0–748). It occurs exactly once:
occurrences in A [748], in B none. It is A-only
distinct (absent from context B). Its
correspondence key (791780864, 24) is held only
by itself: no B-only act carries that key, and
the only act in either list with that key is
itself.

Its incoming gap from rank 747 is +512 (from
(791780352, 24, 2) at A 747, rank 747), NOT equal
to its own size (24). Rank 748 has no successor,
so no outgoing gap exists for it and none was
requested. The A-offset neighbourhood of rank
748 is: rank 745: A 745 (791779328, 24, 0);
rank 746: A 746 (791779840, 24, 1); rank 747:
A 747 (791780352, 24, 2) — each A-only distinct.
In A index order it follows A 747 immediately;
the two A positions before that tail, 743 and
744, hold the shared single-positioned run-102
acts (755688960, 24, 2) at A-offset rank 32 and
(791778816, 24, 0) at rank 744 respectively.

## (ii) The act at A-offset rank 744 in full

The act (791778816, 24, 0) at A 744 is A-offset
rank 744. It occurs exactly once in each
context: occurrences in A [744], in B [746]. It
is shared single-positioned (run 102, shift +2):
A pos 744, B pos 746, a member of run 102 — and
it is run 102's last act (verified this run:
the act equals sruns139[102][-1]). Its
correspondence key (791778816, 24) is held only
by itself on each side: no A-only or B-only act
carries that key, and the only act in either
list with that key is itself.

Its incoming gap from rank 743 is +512 (from
(791778304, 24, 0) at A 736, rank 743, A-only
distinct) and its outgoing gap to rank 745 is
+512 (to (791779328, 24, 0) at A 745, rank 745,
A-only distinct); neither gap equals its own
size (24). The A-offset neighbourhood of rank
744 is: rank 741: A 734 (791777280, 24, 1);
rank 742: A 735 (791777792, 24, 2); rank 743:
A 736 (791778304, 24, 0) — each A-only distinct;
rank 745: A 745 (791779328, 24, 0); rank 746:
A 746 (791779840, 24, 1); rank 747: A 747
(791780352, 24, 2) — each A-only distinct. It is
the sole shared single-positioned act in the A
closing run (ranks 741–748), per AES-NUM-229.

## (iii) The cross-order census comparison in full

Side by side, on the same base classes:

- Acts total and rank range: A-offset order —
  749 acts, ranks 0–748; B-offset order — 751
  acts, ranks 0–750. Difference B−A = +2.
- First act per order: identical — (262144, 376,
  0), at A 694 in A-offset order and at B 696 in
  B-offset order, shared single-positioned
  (run 102, shift +2), a member of run 102 in
  both orders.
- Last act per order: different — A-offset
  rank 748 is (791780864, 24, 0) at A 748,
  A-only distinct; B-offset rank 750 is
  (1196445696, 24, 0) at B 738, B-only distinct.
- Class census per order: A-offset — shared
  single-positioned 689, A-only distinct 60,
  shared distinct but NOT single-positioned 0,
  B-only distinct 0, in neither 0, summing to
  749 exactly; B-offset — shared
  single-positioned 689, B-only distinct 62,
  shared distinct but NOT single-positioned 0,
  A-only distinct 0, in neither 0, summing to
  751 exactly. The shared count is the same in
  both orders (689); the entire +2 total
  difference sits in the side-only classes
  (B-only 62 vs A-only 60, difference +2).
- Run-102 membership per order: 58 acts in
  run 102 in both orders; not in run 102 —
  691 over A-offset order, 693 over B-offset
  order.

Each order's class census sums to its own acts
total, exactly as the contract's tests require.

Any law NOT PROVEN unless the numbers prove
it; no law is claimed here. The meaning of
run 102 is NOT PROVEN.
