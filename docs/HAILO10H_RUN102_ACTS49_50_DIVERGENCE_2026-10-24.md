# The shared run-102 acts at A 731 / B 733 and A 732 / B 734 occur exactly once on each side as the forty-ninth and fiftieth acts of run 102, each following the previous act immediately in both index orders and both offset orders with outgoing gap +512 (not its own size) for the forty-ninth and outgoing gaps differing by side for the fiftieth (+24, exactly its own size, on the A side; +2,048, not its own size, on the B side), after which the two index orders diverge — A 733 carries the A-only act (791776792, 24, 0) and B 735 carries the B-only act (1196444160, 24, 0) — so the first fifty run-102 acts are identical in order on both sides and the identical-order sequence ends exactly at the fiftieth act (AES-NUM-209)

Slice 4.209, worked under `docs/TASK_CONTRACT_4.209.md`
(contract published in the 4.208 closing commit @
b3c20f13). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device.

## Run and closing record

hef209.py is the verified hef208 base plus arms209:
hef208.py sha256
`bc46537d0c75aeed7dd0361e6f51c1214840fb92e5ee5d0e6223b7d9411b370c`
(1,543,323 B) on both the VM and the device.
arms209 sha256
`6ad93e514ae74b33eb41b4e41472632b08807f47690e2773bb64dd2d7ccbc9c0`
(15,970 B); hef209.py sha256
`de2b2cf14f137f3ce9d164b957f1e14408db42dc978cf064869dc7ddec7a9ad0`
(1,559,293 B) on both the VM and the device.
Crossing, stated exactly: arms209 was gzipped at
gzip -9 (sha256
`858900e0d90658c23678f94b73c696b6ecf82b7cbdebd44247fa5233b9a8653e`,
3,782 B) and split into eleven 373 B parts (last
52 B); each part was written as its own file with
its own sha256 gate and every part verified
on-device first try; the assembled gzip and arms
shas == VM on-device; hef209 assembled on-device
from hef208.py + arms209.py, sha == VM, py_compile
OK. Pre-launch tmux/ps check found no hef209/h209
child; exactly ONE bounded host-side child ran in
detached tmux (session h209, created 2026-10-30
12:10:36 EDT) with the contract corpus argv (glob
order, MiniLM last), unbuffered (`python3 -u`).
The child finished with DONE209 as its last line,
exit marker 0 (hef209.exit), err empty. Output
hef209.out 55,401 lines / 10,140,976 B sha256
`b4d251263ff8e36f94c29e7d3ff5f2d55658dbf6bee8fa14f3c686bd57e8dbce`;
prefix against hef208.out: the first 55,221 lines
differ from hef208.out in exactly TWO lines
(lines 41611 and 42872, frozenset element order
only — the AES-NUM-150 variance), hef209.out
adding exactly its own 180 section lines
(25,815 B, sha256
`0dd84863c1910d32e1dc67f72d1889f168f38194280483abc59310d25f0b0b9a`,
read in full on-device). Controls EXACT. Raw
output kept on the Pi at ~/aesir-build/
(hef209.out, hef209.py, arms209.py, section209.txt,
hef209.exit, run209.sh, gz209/); local lineage in
~/workspace/.verify-tmp/aesir209.

## (i) The shared run-102 act at A 731 / B 733 in full

The act (791776256, 24, 2) occurs exactly once
on each side — A index 731, A-offset rank 738;
B index 733, B-offset rank 718 — and is the
forty-ninth act of run 102 in full: run 102 has
length 58 with shift +2 (A 683–744 / B 685–746).
Its (791776256, 24) correspondence key is held
only by itself on each side (no A-only or B-only
act under that key). It follows the forty-eighth
run-102 act at A 730 / B 732 immediately in BOTH
index orders and in BOTH offset orders, with
incoming gap +512 in both offset orders. Its
outgoing gap is +512 in BOTH offset orders —
NOT its own size (24) — to the fiftieth
run-102 act (791776768, 24, 0) at A 732 / B 734
at offset rank 739 / 719.

## (ii) The shared run-102 act at A 732 / B 734 in full

The act (791776768, 24, 0) occurs exactly once
on each side — A index 732, A-offset rank 739;
B index 734, B-offset rank 719 — and is the
fiftieth act of run 102. Its (791776768, 24)
correspondence key is held only by itself on
each side. It follows the act in (i) immediately
in BOTH index orders and in BOTH offset orders,
with incoming gap +512 in both offset orders.
Its outgoing gaps DIFFER by side: +24 in
A-offset order — exactly its own size — to the
A-only act (791776792, 24, 0) at A 733 at offset
rank 740; and +2,048 in B-offset order — NOT
its own size — to the last run-102 act
(791778816, 24, 0) at B 746 at offset rank 720
(in B-offset order its successor is distant).

## (iii) The index-order divergence at A 733 and B 735 in full

The act (791776792, 24, 0) occurs exactly once,
on the A side only — A index 733, A-offset
rank 740; no B occurrence. It is A-only
distinct. Its (791776792, 24) correspondence
key is held only by itself on the A side; no
act in B carries that key. In A-offset order
it follows the fiftieth run-102 act immediately
(rank 739 to 740, incoming gap +24), and its
outgoing gap is +488 — NOT its own size (24) —
to the A-only act (791777280, 24, 1) at A 734
at offset rank 741.
The act (1196444160, 24, 0) occurs exactly
once, on the B side only — B index 735,
B-offset rank 747; no A occurrence. It is
B-only distinct. Its (1196444160, 24)
correspondence key is held only by itself on
the B side; no act in A carries that key. In
B-offset order its placement is distant: its
offset-order predecessor is the B-only act
(1196410880, 32784, 2) at B 674 at offset
rank 746, with incoming gap +33,280; its
outgoing gap is +512 — NOT its own size
(24) — to the B-only act (1196444672, 24, 1)
at B 736 at offset rank 748.
The first fifty run-102 acts are identical in
order on both sides: A 683–732 acts equal
B 685–734 acts in order, exactly. Extended one
step, A 683–733 against B 685–735, the two
sequences differ at exactly ONE position —
0-based position 50, the fifty-first act
position — where A carries (791776792, 24, 0)
and B carries (1196444160, 24, 0). The
identical-order sequence is therefore exactly
50 acts long and ends at the fiftieth act,
(791776768, 24, 0) at A 732 / B 734.
Recorded for the next slice, from this slice's
own neighbourhoods: after the divergence each
side carries exactly four side-only acts in
index order — A 733–736: (791776792, 24, 0),
(791777280, 24, 1) at A-offset rank 741,
(791777792, 24, 2) at rank 742 and
(791778304, 24, 0) at rank 743; B 735–738:
(1196444160, 24, 0), (1196444672, 24, 1) at
B-offset rank 748, (1196445184, 24, 2) at
rank 749 and (1196445696, 24, 0) at rank 750 —
and the two index orders then resync at the
shared act (768609280, 24, 0) at A 737 / B 739,
at A-offset rank 33 / B-offset rank 34.

Any law NOT PROVEN unless the numbers prove
it; no law is claimed here. The meaning of
run 102 is NOT PROVEN.
