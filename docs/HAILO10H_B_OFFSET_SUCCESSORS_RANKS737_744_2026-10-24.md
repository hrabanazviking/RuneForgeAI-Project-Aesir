# The acts at B 17, B 19 and B 20 each occur exactly once on the B side only, and the B-offset-order run of ranks 737–744 is eight consecutive B-only acts, none in run 102 (AES-NUM-214)

Slice 4.214, worked under `docs/TASK_CONTRACT_4.214.md`
(contract published in the 4.213 closing commit @
a86ad9c0). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device.

## Run and closing record

hef214.py is the verified hef213 base plus
arms214: hef213.py sha256
`9ba093120c98e93b19759eba2bb1a6985689b3f310405f2d3d73f36e0bba5647`
(1,612,870 B) on both the VM and the device.
arms214 sha256
`a7b4eb95a007cf40e3ab8220eb7acebab41187261d6265f2ba0a8b6560a7f0ec`
(12,476 B); hef214.py sha256
`961e6bbfe393ceccc49025a3e4908dd17e1c2e897b9497e58d4fa61bfa20e745`
(1,625,346 B) on both the VM and the device.
Crossing, stated exactly: arms214 was gzipped at
gzip -9 (sha256
`cadeb753d0da725eda5182a71763422e860779904dcf11e02e6e63b843eb2b87`,
3,052 B) and split into nine 373 B parts (last
68 B); each part was written as its own file with
its own sha256 gate and every part verified
on-device first try; the assembled gzip, arms
and hef214 shas == VM on-device; hef214 assembled
on-device from hef213.py + arms214.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef214/h214 child; exactly ONE bounded host-side
child ran in detached tmux (session h214, created
2026-10-30 13:57:05 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef214.exit), err empty, and DONE214 as
its last line. Output hef214.out 56,048 lines /
10,233,440 B sha256
`31ffe9c40b6200fa7f85fa49cbb5f67147a3d029cb904a0df751ee50aa9fb945`;
prefix against hef213.out: the first 55,942
lines differ from hef213.out in exactly two
lines (lines 41611 and 42872, frozenset element
order only — the AES-NUM-150 variance),
hef214.out adding exactly its own 106 section
lines (15,260 B, sha256
`f921b1fccf2cb3e902214dc63e8fe10355f356c0214a172b2d31afed6747b877`,
read in full on-device). Controls EXACT. Raw
output kept on the Pi at ~/aesir-build/
(hef214.out, hef214.py, arms214.py,
section214.txt, hef214.exit, run214.sh, gz214/);
local lineage in ~/workspace/.verify-tmp/aesir214.

## (i) The act at B 17 in full

The act (1196272096, 32728, 1) occurs exactly once,
on the B side only — B index 17, B-offset
rank 737; no A occurrence. It is B-only
distinct. Its (1196272096, 32728) correspondence
key is held only by itself on the B side; no
act in A carries that key. It is NOT a member
of run 102. It follows the B-only act
(1196272072, 24, 1) at B 16 immediately in
BOTH B index order (B 16 then B 17) and B-offset
order (rank 736 then rank 737), with incoming
gap +24 in B-offset order. Its outgoing gap
is +32,800 — NOT its own size (32,728) — in B-offset
order, to the B-only act (1196304896, 7712, 0)
at B 19 at offset rank 738. In B index order it
sits between B 16 and the shared act at B 18.

## (ii) The act at B 19 in full

The act (1196304896, 7712, 0) occurs exactly
once, on the B side only — B index 19, B-offset
rank 738; no A occurrence. It is B-only
distinct. Its (1196304896, 7712) correspondence
key is held only by itself on the B side; no
act in A carries that key. It is NOT a member
of run 102. In B-offset order it follows B 17's
act immediately (rank 737 then rank 738), with
incoming gap +32,800 in B-offset order; in B index
order the shared act at B 18 sits between B 17
and B 19. Its outgoing gap is +7,712 — exactly its
own size — in B-offset order, to the B-only act
(1196312608, 328, 0) at B 20 at offset rank 739.
In B index order it sits
between the shared act at B 18 and the
B-only act at B 20.

## (iii) The act at B 20 in full, and the run of ranks 737–744

The act (1196312608, 328, 0) at B 20, B-offset
rank 739, occurs exactly once, on the B side
only; B-only distinct; its (1196312608, 328)
key held only by itself on the B side, no A
act under that key; NOT a member of run 102.
In B-offset order it follows B 19's act
immediately (rank 738 then rank 739), with
incoming gap +7,712 in B-offset order; it also
follows B 19 immediately in B index order
(B 19 then B 20). Its outgoing gap is
+480 — NOT its own size (328) — in B-offset
order, to the B-only act (1196313088, 24848, 1)
at B 22 at offset rank 740. In B index order it
sits between B 19 and the shared act at B 21.

The B-offset-order run of ranks 737–744 in
full — every act B-only distinct, occurring
exactly once, none a member of run 102:
rank 737: B 17 (1196272096, 32728, 1), gap to
next rank +32,800; rank 738: B 19
(1196304896, 7712, 0), gap +7,712; rank 739:
B 20 (1196312608, 328, 0), gap +480;
rank 740: B 22 (1196313088, 24848, 1), gap
+24,848; rank 741: B 23
(1196337936, 264, 1), gap +752;
rank 742: B 25 (1196338688, 30008, 2), gap
+30,008; rank 743: B 26
(1196368696, 280, 2), gap +712;
rank 744: B 229 (1196369408, 26128, 2),
gap +26,624 (to rank 745). The B indices in rank
order are 17, 19, 20, 22, 23, 25, 26, 229.

Any law NOT PROVEN unless the numbers prove
it; no law is claimed here. The meaning of
run 102 is NOT PROVEN.
