# The acts at B 1, B 0, B 27 and B 5 each occur exactly once on the B side only, and the B-offset-order run of ranks 721–728 is eight consecutive B-only acts, none in run 102 (AES-NUM-212)

Slice 4.212, worked under `docs/TASK_CONTRACT_4.212.md`
(contract published in the 4.211 closing commit @
c03126fe). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device.

## Run and closing record

hef212.py is the verified hef211 base plus
arms212: hef211.py sha256
`3c6d275f9a4af001233475d18da5b4a44950fb239e62f0765ec5f914931b6a5e`
(1,587,710 B) on both the VM and the device.
arms212 sha256
`0ae76d8d1338cdf7c88ef5b02fed19bcd7dc6e9ec4a0d651988466a156a7fc44`
(12,732 B); hef212.py sha256
`ba5ca27d9688bc2710c4bab78b4a2e7d9cf2c3bcd90c95adf673496facaba516`
(1,600,442 B) on both the VM and the device.
Crossing, stated exactly: arms212 was gzipped at
gzip -9 (sha256
`9520d218760a2f95d7ef0700891bb982cbe405446b48ed57a8dd8cc598df506d`,
3,124 B) and split into nine 373 B parts (last
140 B); each part was written as its own file with
its own sha256 gate and every part verified
on-device first try; the assembled gzip, arms
and hef212 shas == VM on-device; hef212 assembled
on-device from hef211.py + arms212.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef212/h212 child; exactly ONE bounded host-side
child ran in detached tmux (session h212, created
2026-10-30 13:21:15 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef212.exit), err empty, and DONE212 as
its last line. Output hef212.out 55,836 lines /
10,203,043 B sha256
`168945ffca764dd4f6bbb948823495de4468c75b45b28cf4c59895647fa5a62e`;
prefix against hef211.out: the first 55,713
lines are IDENTICAL to hef211.out (zero differing
lines this run — the AES-NUM-150 frozenset-order
variance did not occur), hef212.out adding exactly
its own 123 section lines (17,397 B, sha256
`0e4977e1aed444e6f5105d1cd19d45e259828a4dc30907123c2b7937386a90da`,
read in full on-device). Controls EXACT. Raw
output kept on the Pi at ~/aesir-build/
(hef212.out, hef212.py, arms212.py,
section212.txt, hef212.exit, run212.sh, gz212/);
local lineage in ~/workspace/.verify-tmp/aesir212.

## (i) The act at B 1 in full

The act (873198592, 24, 0) occurs exactly once,
on the B side only — B index 1, B-offset
rank 724; no A occurrence. It is B-only
distinct. Its (873198592, 24) correspondence
key is held only by itself on the B side; no
act in A carries that key. It is NOT a member
of run 102. In B-offset order it follows the
B tail act (800053760, 24, 2) at B 749, rank
723, with incoming gap +73,144,832 in B-offset
order. Its outgoing gap is +512 — NOT its own
size (24) — in B-offset order, to the B-only
act (873199104, 24, 1) at B 0 at offset
rank 725. In B index order it sits between
B 0 (its offset-order successor) and the
shared act at B 2.

## (ii) The act at B 0 in full

The act (873199104, 24, 1) occurs exactly once,
on the B side only — B index 0, B-offset
rank 725; no A occurrence. It is B-only
distinct. Its (873199104, 24) correspondence
key is held only by itself on the B side; no
act in A carries that key. It is NOT a member
of run 102. It is the FIRST act of context B
in index order, but at offset rank 725 it
follows B 1's act in offset order (incoming
gap +512 in B-offset order — the B 0 / B 1
pair is reversed between the two orders:
index order B 0 then B 1, offset order
rank 724 B 1 then rank 725 B 0). Its outgoing
gap is +512 — NOT its own size (24) — in
B-offset order, to the B-only act
(873199616, 24, 2) at B 27 at offset rank 726.

## (iii) The acts at B 27 and B 5 in full, and the run of ranks 721–728

The act (873199616, 24, 2) at B 27, B-offset
rank 726, occurs exactly once, on the B side
only; B-only distinct; its (873199616, 24)
key held only by itself on the B side, no A
act under that key; NOT a member of run 102.
Incoming gap +512 in B-offset order (from
B 0's act at rank 725); outgoing gap
+100,480,000 — NOT its own size — in B-offset
order, to the B-only act (973679616, 24, 0)
at B 750 at offset rank 727.

The act (1196182016, 24, 2) at B 5, B-offset
rank 728, occurs exactly once, on the B side
only; B-only distinct; its (1196182016, 24)
key held only by itself on the B side, no A
act under that key; NOT a member of run 102.
Incoming gap +222,502,400 in B-offset order
(from B 750's act at rank 727); outgoing gap
+512 — NOT its own size — in B-offset order,
to the B-only act (1196182528, 24, 0) at B 6
at offset rank 729.

The B-offset-order run of ranks 721–728 in
full — every act B-only distinct, occurring
exactly once, none a member of run 102:
rank 721: B 748 (791781376, 24, 1), gap to
next rank +512; rank 722: B 747
(791781888, 24, 0), gap +8,271,872; rank 723:
B 749 (800053760, 24, 2), gap +73,144,832;
rank 724: B 1 (873198592, 24, 0), gap +512;
rank 725: B 0 (873199104, 24, 1), gap +512;
rank 726: B 27 (873199616, 24, 2), gap
+100,480,000; rank 727: B 750
(973679616, 24, 0), gap +222,502,400;
rank 728: B 5 (1196182016, 24, 2), gap +512
(to rank 729). The B indices in rank order
are 748, 747, 749, 1, 0, 27, 750, 5.

Any law NOT PROVEN unless the numbers prove
it; no law is claimed here. The meaning of
run 102 is NOT PROVEN.
