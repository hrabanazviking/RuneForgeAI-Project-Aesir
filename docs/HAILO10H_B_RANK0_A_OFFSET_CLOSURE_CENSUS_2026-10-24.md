# The act at B-offset rank 0 in full, the A-offset-order closure in full, and the full-order census over A-offset order (AES-NUM-229)

Slice 4.229, worked under `docs/TASK_CONTRACT_4.229.md`
(contract published in the 4.228 closing commit @
e2f8751e). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section229.txt).

## Run and closing record

hef229.py is the verified hef228 base plus
arms229: hef228.py sha256
`6d89b8ab2e918755546d32c1400cf3a4fafd841194e40a704293a22deee22762`
(1,797,872 B) on both the VM and the device.
arms229 sha256
`14d452528e5297b52694f0d367ec107900e7b4173d1cf43c4337d7b844e08484`
(13,602 B); hef229.py sha256
`9f4beeb831e78148ca1e6a4f424a03cd48a14ca8e47c5e386d22786f9035bbc8`
(1,811,474 B) on both the VM and the device.
Crossing, stated exactly: arms229 was gzipped at
gzip -9 (sha256
`0eba6ccb9e3a3dd7b73250b4128a925455c1a2b75ecf84b7d14d0bbd4d4bc92c`,
3,232 B) and split into nine 373 B parts (last
248 B); each part was written as its own file with
its own sha256 gate — all nine verified on-device
first try; the assembled gzip, arms and hef229
shas == VM on-device; hef229 assembled on-device
from hef228.py + arms229.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef229/h229 child; exactly ONE bounded host-side
child ran in detached tmux (session h229, created
2026-10-30 18:24:30 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef229.exit), err empty, and DONE229 as
its last line. Output hef229.out 57,412 lines /
10,426,073 B sha256
`276b71f9da6ff7524f93b662a7ee9474c0e135655cac69ffe092092b7dcb8cc5`;
prefix against hef228.out: the first 57,348
lines differ from hef228.out in exactly TWO lines
(lines 41611 and 42872, frozenset element order
only — the AES-NUM-150 variance, verified this
run by same-sorted-characters comparison on both
lines), hef229.out adding exactly its own 64
section lines (10,407 B, sha256
`5def52bde54f0ba86869cf98da6a7323ba81dfc06453b2a15bfa2a63389e4746`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef229.out, hef229.py, arms229.py,
section229.txt, hef229.exit, run229.sh, gz229/,
check229.py); local lineage in
~/workspace/.verify-tmp/aesir229.

## (i) The act at B-offset rank 0 in full

The act (262144, 376, 0) at B 696 is B-offset
rank 0. It occurs exactly once in each context:
occurrences in A [694], in B [696]. It is shared
single-positioned (run 102, shift +2): A pos 694,
B pos 696, a member of run 102. Its
correspondence key (262144, 376) is held only by
itself on each side: no A-only or B-only act
carries that key, and the only act in either list
with that key is itself.

Rank 0 has no predecessor, so no incoming gap
exists for it and none was requested. Its
outgoing gap to rank 1 is +512 (to (262656, 24,
0) at B 697, rank 1), NOT equal to its own size
(376). The B-offset neighbourhood of rank 0 is:
rank 1: B 697 (262656, 24, 0); rank 2: B 698
(262680, 24, 0); rank 3: B 699 (262704, 72, 0) —
each shared single-positioned (run 102, shift
+2), at A positions 695, 696 and 697
respectively. In B index order it sits between
B 695's act (3415040, 24, 1) and B 697's act,
following B 695 and preceding B 697 immediately.

## (ii) The A-offset-order closure in full

Ranks 743–748 (A acts 749, ranks 0–748; rank 748
is the last measured rank):

- 743: A 736 (791778304, 24, 0), A-only distinct,
  gap to next rank +512; occurrences in A [736],
  in B none; NOT in run 102.
- 744: A 744 (791778816, 24, 0), shared
  single-positioned (run 102, shift +2), gap
  +512; occurrences in A [744], in B [746]; a
  member of run 102 — it is run 102's last act.
- 745: A 745 (791779328, 24, 0), A-only distinct,
  gap +512; occurrences in A [745], in B none;
  NOT in run 102.
- 746: A 746 (791779840, 24, 1), A-only distinct,
  gap +512; occurrences in A [746], in B none;
  NOT in run 102.
- 747: A 747 (791780352, 24, 2), A-only distinct,
  gap +512; occurrences in A [747], in B none;
  NOT in run 102.
- 748: A 748 (791780864, 24, 0), A-only distinct,
  gap None — rank 748 is the last measured rank
  and no rank beyond 748 was requested;
  occurrences in A [748], in B none; NOT in
  run 102.

The closing run of ranks 741–748 in full on the
same terms adds: 741: A 734 (791777280, 24, 1),
A-only distinct, gap +512; 742: A 735
(791777792, 24, 2), A-only distinct, gap +512;
then ranks 743–748 exactly as above. Of the
eight closing-run acts, seven are A-only
distinct and one (rank 744) is shared
single-positioned; exactly one (rank 744) is a
member of run 102. Every gap inside the closing
run is +512.

## (iii) The full-order census over A-offset order

A acts 749, ranks 0–748. The act at rank 0 is
(262144, 376, 0) at A 694 — the same act as
B-offset rank 0 — shared single-positioned
(run 102, shift +2), occurrences in A [694], in
B [696], a member of run 102. The act at rank
748 is (791780864, 24, 0) at A 748, as above.

Class census over all 749 acts in A-offset
order: shared single-positioned 689; A-only
distinct 60; shared distinct but NOT
single-positioned 0; B-only distinct 0; in
neither context list 0. The census counts sum
to 749, exactly as the contract's test requires.

Run-102 membership count over A-offset order:
58 acts are members of run 102; 691 acts are
not. (The same 58-count was measured over
B-offset order in AES-NUM-228, where the census
was 689 shared single-positioned + 62 B-only
distinct = 751 and 693 not in run 102.)

Any law NOT PROVEN unless the numbers prove
it; no law is claimed here. The meaning of
run 102 is NOT PROVEN.
