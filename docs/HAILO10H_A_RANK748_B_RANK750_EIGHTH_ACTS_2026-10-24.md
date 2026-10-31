# The acts at A-offset rank 748 and B-offset rank 750 in full, and the closing-run eighth-act comparison (AES-NUM-239)

Slice 4.239, worked under `docs/TASK_CONTRACT_4.239.md`
(contract published in the 4.238 closing commit @
43d497e7). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section239.txt).

## Run and closing record

hef239.py is the verified hef238 base plus
arms239: hef238.py sha256
`448fa3f1981524ac4ff6405abb487adcf1b11951336e71fbf8d2dc9296401d30`
(1,933,007 B) on both the VM and the device.
arms239 sha256
`6b5924be39bad300b6aa3b541a6c8c4b62797e98c50a2159f15773e2eabc4e8e`
(13,799 B); hef239.py sha256
`b6b7ff56d0c13771e73852f21e0b70f61b069eb81d7fae475fd3163c2f624d68`
(1,946,806 B) on both the VM and the device.
Crossing, stated exactly: arms239 was gzipped at
gzip -9 (sha256
`49c067b85625973d3c90bfc058242e437c469f6177e1aa57e397638dc5d5acf3`,
3,434 B) and split into ten 373 B parts (last
77 B); each part was written as its own file with
its own sha256 gate — all ten verified on-device
first try; the assembled gzip, arms and hef239
shas == VM on-device; hef239 assembled on-device
from hef238.py + arms239.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef239/h239 child; exactly ONE bounded host-side
child ran in detached tmux (session h239, created
2026-10-30 21:32:33 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`), and finished with exit marker 0
(hef239.exit), err empty, and DONE239 as its last
line. Output hef239.out 58,097 lines / 10,535,250 B
sha256
`383677120fabec9f43a57742414588f39948968f40a43aff0feac5cabb2ba5ef`;
prefix against hef238.out: the first 58,037
lines differ from hef238.out in exactly TWO lines
(lines 41611 and 42872, frozenset element order
only — the AES-NUM-150 variance, each verified by
same-sorted-characters comparison), hef239.out
adding exactly its own 60 section lines (10,190 B,
sha256
`88bfa1f6f77c4000edc56b8bdd1cb60da0466cf525d0b6f490489b783577cd70`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef239.out, hef239.py, arms239.py,
section239.txt, hef239.exit, run239.sh, gz239/,
check239.py); local lineage in
~/workspace/.verify-tmp/aesir239.

## The AES-NUM-238 defect fix, proven in print

The contract carried the fix for arms238's
comparison defect, and the printed section
carries it: the (iii) comparison's incoming gaps
are computed from the same predecessor ranks as
the per-act statements (A predecessor rank 747,
B predecessor rank 749), and the section prints
a CONSISTENCY CHECK line — comparison A incoming
+512 equals statement A incoming +512 TRUE;
comparison B incoming +512 equals statement B
incoming +512 TRUE. No field of this slice's
printed comparison is defective.

## (i) The act at A-offset rank 748 in full

The act (791780864, 24, 0) at A 748 is A-offset
rank 748 — the eighth and last act of the A
closing run (ranks 741–748) and the last act of
context A in A-offset order (749 acts, ranks
0–748). It occurs exactly once, on the A side
only: occurrences in A [748], in B none. It is
A-only distinct (absent from context B). Its
correspondence key (791780864, 24) is held only
by itself: no B-only act carries that key, no B
act of any kind carries it, and the only act in
either list with that key is itself.

Its incoming gap from rank 747 is +512 (from
(791780352, 24, 2) at A 747, rank 747); the gap
does not equal its own size (24). It has NO
outgoing gap: rank 748 is the last rank of the
749 A-offset ranks, so the act is terminal in
A-offset order. The A-offset neighbourhood of
rank 748 is truncated at the list end: rank 745:
A 745 (791779328, 24, 0) A-only; rank 746: A 746
(791779840, 24, 1) A-only; rank 747: A 747
(791780352, 24, 2) A-only — its offset-order
predecessor is exactly its index predecessor
(A 747), and it has no successor on either side
of the comparison (last in index order as well:
A index 748 of 749).

## (ii) The act at B-offset rank 750 in full

The act (1196445696, 24, 0) at B 738 is B-offset
rank 750 — the eighth and last act of the B
closing run (ranks 743–750) and the last act of
context B in B-offset order (751 acts, ranks
0–750). It occurs exactly once: occurrences in
A none, in B [738]. It is B-only distinct
(absent from context A). Its correspondence key
(1196445696, 24) is held only by itself: no
A-only act carries that key, no A act of any
kind carries it, and the only act in either
list with that key is itself.

Its incoming gap from rank 749 is +512 (from
(1196445184, 24, 2) at B 737, rank 749); the gap
does not equal its own size (24). It has NO
outgoing gap: rank 750 is the last rank of the
751 B-offset ranks, so the act is terminal in
B-offset order. The B-offset neighbourhood of
rank 750 is truncated at the list end: rank 747:
B 735 (1196444160, 24, 0) B-only; rank 748:
B 736 (1196444672, 24, 1) B-only; rank 749:
B 737 (1196445184, 24, 2) B-only — its
offset-order predecessor is exactly its index
predecessor (B 737), and it has no offset-order
successor.

## (iii) The closing-run eighth-act comparison in full

Side by side:

- A closing run eighth act: rank 748, index 748,
  act (791780864, 24, 0), class A-only distinct,
  in run 102 NO, incoming gap +512, outgoing gap
  NONE (terminal).
- B closing run eighth act: rank 750, index 738,
  act (1196445696, 24, 0), class B-only distinct,
  in run 102 NO, incoming gap +512, outgoing gap
  NONE (terminal).
- Contract tests: the A eighth act's incoming gap
  (+512) equals the seventh gap of the A closing
  run's gap sequence as measured in AES-NUM-231
  (512) — YES; the B eighth act's incoming gap
  (+512) equals the seventh gap of the B closing
  run's gap sequence as measured in AES-NUM-231
  (512) — YES. (The seventh gap of each run is
  the transition from its seventh act to its
  eighth act, i.e. the eighth act's incoming
  gap.)
- The two eighth acts agree in run-102 membership
  (both NO), in incoming gap (+512 vs +512), and
  in terminal status (no outgoing gap on either
  side); they differ only in class label (A-only
  distinct vs B-only distinct). With this slice
  both closing runs are walked in full in this
  paired sequence (slices 4.232–4.239, eight acts
  each).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
