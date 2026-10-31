# The acts at B 6, B 8 and B 10 each occur exactly once on the B side only, and the B-offset-order run of ranks 729–736 is eight consecutive B-only acts, none in run 102 (AES-NUM-213)

Slice 4.213, worked under `docs/TASK_CONTRACT_4.213.md`
(contract published in the 4.212 closing commit @
33029e96). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device.

## Run and closing record

hef213.py is the verified hef212 base plus
arms213: hef212.py sha256
`ba5ca27d9688bc2710c4bab78b4a2e7d9cf2c3bcd90c95adf673496facaba516`
(1,600,442 B) on both the VM and the device.
arms213 sha256
`782338c230b053a40de4d9a69856dd82528a64ecae7bfba4e2d1b3f58340314b`
(12,428 B); hef213.py sha256
`9ba093120c98e93b19759eba2bb1a6985689b3f310405f2d3d73f36e0bba5647`
(1,612,870 B) on both the VM and the device.
Crossing, stated exactly: arms213 was gzipped at
gzip -9 (sha256
`34cd9b84ab4c84d5cb1234e76d8f8d773c3b804284042198c57a4928d519b8c2`,
3,046 B) and split into nine 373 B parts (last
62 B); each part was written as its own file with
its own sha256 gate and every part verified
on-device first try; the assembled gzip, arms
and hef213 shas == VM on-device; hef213 assembled
on-device from hef212.py + arms213.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef213/h213 child; exactly ONE bounded host-side
child ran in detached tmux (session h213, created
2026-10-30 13:37:55 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef213.exit), err empty, and DONE213 as
its last line. Output hef213.out 55,942 lines /
10,218,180 B sha256
`c9598751998a83ddd433db7064e370f754b569fc7b3ef761ea92f9230de4e7af`;
prefix against hef212.out: the first 55,836
lines differ from hef212.out in exactly two
lines (lines 41611 and 42872, frozenset element
order only — the AES-NUM-150 variance),
hef213.out adding exactly its own 106 section
lines (15,137 B, sha256
`fa48317df3a418b82c57a8e2db18b5685cbe25d2c54ac52c7b5c7cfdeee39de1`,
read in full on-device). Controls EXACT. Raw
output kept on the Pi at ~/aesir-build/
(hef213.out, hef213.py, arms213.py,
section213.txt, hef213.exit, run213.sh, gz213/);
local lineage in ~/workspace/.verify-tmp/aesir213.

## (i) The act at B 6 in full

The act (1196182528, 24, 0) occurs exactly once,
on the B side only — B index 6, B-offset
rank 729; no A occurrence. It is B-only
distinct. Its (1196182528, 24) correspondence
key is held only by itself on the B side; no
act in A carries that key. It is NOT a member
of run 102. It follows the B-only act
(1196182016, 24, 2) at B 5 immediately in
BOTH B index order (B 5 then B 6) and B-offset
order (rank 728 then rank 729), with incoming
gap +512 in B-offset order. Its outgoing gap
is +512 — NOT its own size (24) — in B-offset
order, to the B-only act (1196183040, 32784, 1)
at B 8 at offset rank 730. In B index order it
sits between B 5 and the shared act at B 7.

## (ii) The act at B 8 in full

The act (1196183040, 32784, 1) occurs exactly
once, on the B side only — B index 8, B-offset
rank 730; no A occurrence. It is B-only
distinct. Its (1196183040, 32784) correspondence
key is held only by itself on the B side; no
act in A carries that key. It is NOT a member
of run 102. In B-offset order it follows B 6's
act immediately (rank 729 then rank 730), with
incoming gap +512 in B-offset order; in B index
order the shared act at B 7 sits between B 6
and B 8. Its outgoing gap is +33,280 — NOT its
own size (32,784) — in B-offset order, to the
B-only act (1196216320, 7800, 2) at B 10 at
offset rank 731. In B index order it sits
between the shared acts at B 7 and B 9.

## (iii) The act at B 10 in full, and the run of ranks 729–736

The act (1196216320, 7800, 2) at B 10, B-offset
rank 731, occurs exactly once, on the B side
only; B-only distinct; its (1196216320, 7800)
key held only by itself on the B side, no A
act under that key; NOT a member of run 102.
In B-offset order it follows B 8's act
immediately (rank 730 then rank 731), with
incoming gap +33,280 in B-offset order; in
B index order the shared act at B 9 sits
between B 8 and B 10. Its outgoing gap is
+7,800 — exactly its own size — in B-offset
order, to the B-only act (1196224120, 344, 2)
at B 11 at offset rank 732.

The B-offset-order run of ranks 729–736 in
full — every act B-only distinct, occurring
exactly once, none a member of run 102:
rank 729: B 6 (1196182528, 24, 0), gap to
next rank +512; rank 730: B 8
(1196183040, 32784, 1), gap +33,280; rank 731:
B 10 (1196216320, 7800, 2), gap +7,800;
rank 732: B 11 (1196224120, 344, 2), gap
+392; rank 733: B 13 (1196224512, 32768, 1),
gap +32,768; rank 734: B 14
(1196257280, 14416, 1), gap +14,416;
rank 735: B 15 (1196271696, 376, 1), gap
+376; rank 736: B 16 (1196272072, 24, 1),
gap +24 (to rank 737). The B indices in rank
order are 6, 8, 10, 11, 13, 14, 15, 16.

Any law NOT PROVEN unless the numbers prove
it; no law is claimed here. The meaning of
run 102 is NOT PROVEN.
