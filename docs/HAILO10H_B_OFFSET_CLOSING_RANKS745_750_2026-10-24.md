# The acts at B 272, B 674 and B 735 each occur exactly once on the B side only, and the B-offset-order run of ranks 745–750 closes the B-offset order with six consecutive B-only acts, none in run 102 (AES-NUM-215)

Slice 4.215, worked under `docs/TASK_CONTRACT_4.215.md`
(contract published in the 4.214 closing commit @
1bf02594). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device.

## Run and closing record

hef215.py is the verified hef214 base plus
arms215: hef214.py sha256
`961e6bbfe393ceccc49025a3e4908dd17e1c2e897b9497e58d4fa61bfa20e745`
(1,625,346 B) on both the VM and the device.
arms215 sha256
`18abf3ed5a9bd0a6f33ae3583395008fef713181db9552ea42b03a22b6c5a77d`
(12,591 B); hef215.py sha256
`816f845c1ad41b972080ccfd31e53ba350046edf2173a1a031093ca00c97c1d3`
(1,637,937 B) on both the VM and the device.
Crossing, stated exactly: arms215 was gzipped at
gzip -9 (sha256
`6d5028b2a5f3067b99ab3bc8a7a8a7a80b6e21b2ac73c6c6a4d5a1e2db1e6d75`,
3,097 B) and split into nine 373 B parts (last
113 B); each part was written as its own file with
its own sha256 gate and every part verified
on-device first try; the assembled gzip, arms
and hef215 shas == VM on-device; hef215 assembled
on-device from hef214.py + arms215.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef215/h215 child; exactly ONE bounded host-side
child ran in detached tmux (session h215, created
2026-10-30 14:14:30 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef215.exit), err empty, and DONE215 as
its last line. Output hef215.out 56,152 lines /
10,248,469 B sha256
`fc40251645055a1201ae0f434f9aab14071f1c84e5e47dd27a1c1b3c18152b8a`;
prefix against hef214.out: the first 56,048
lines differ from hef214.out in exactly one
line (line 41611, frozenset element
order only — the AES-NUM-150 variance),
hef215.out adding exactly its own 104 section
lines (15,029 B, sha256
`c83607c56e1b7a98f6eeec8957fb3ee7ce874cd022c4c363b88610a12ca42c19`,
read in full on-device). Controls EXACT. Raw
output kept on the Pi at ~/aesir-build/
(hef215.out, hef215.py, arms215.py,
section215.txt, hef215.exit, run215.sh, gz215/);
local lineage in ~/workspace/.verify-tmp/aesir215.

## (i) The act at B 272 in full

The act (1196396032, 14352, 1) occurs exactly once,
on the B side only — B index 272, B-offset
rank 745; no A occurrence. It is B-only
distinct. Its (1196396032, 14352) correspondence
key is held only by itself on the B side; no
act in A carries that key. It is NOT a member
of run 102. It follows the B-only act
(1196369408, 26128, 2) at B 229 immediately in
B-offset order (rank 744 then rank 745), with
incoming gap +26,624 in B-offset order. Its
outgoing gap is +14,848 — NOT its own size
(14,352) — in B-offset order, to the B-only act
(1196410880, 32784, 2) at B 674 at offset rank
746. In B index order it sits between the
B-only act at B 271 and the shared act at B 273.

## (ii) The act at B 674 in full

The act (1196410880, 32784, 2) occurs exactly
once, on the B side only — B index 674, B-offset
rank 746; no A occurrence. It is B-only
distinct. Its (1196410880, 32784) correspondence
key is held only by itself on the B side; no
act in A carries that key. It is NOT a member
of run 102. In B-offset order it follows B 272's
act immediately (rank 745 then rank 746), with
incoming gap +14,848 in B-offset order. Its
outgoing gap is +33,280 — NOT its own size
(32,784) — in B-offset order, to the B-only act
(1196444160, 24, 0) at B 735 at offset rank 747.
In B index order it sits between the shared
act at B 673 and the shared act at B 675.

## (iii) The act at B 735 in full, and the run of ranks 745–750

The act (1196444160, 24, 0) at B 735, B-offset
rank 747, occurs exactly once, on the B side
only; B-only distinct; its (1196444160, 24)
key held only by itself on the B side, no A
act under that key; NOT a member of run 102.
In B-offset order it follows B 674's act
immediately (rank 746 then rank 747), with
incoming gap +33,280 in B-offset order; it also
follows the shared act at B 734 immediately in
B index order (B 734 then B 735). Its outgoing
gap is +512 — NOT its own size (24) — in
B-offset order, to the B-only act
(1196444672, 24, 1) at B 736 at offset rank 748.
In B index order it sits between the shared
act at B 734 and the B-only act at B 736.

The B-offset-order run of ranks 745–750 in
full — every act B-only distinct, occurring
exactly once, none a member of run 102:
rank 745: B 272 (1196396032, 14352, 1), gap to
next rank +14,848; rank 746: B 674
(1196410880, 32784, 2), gap +33,280; rank 747:
B 735 (1196444160, 24, 0), gap +512;
rank 748: B 736 (1196444672, 24, 1), gap
+512; rank 749: B 737
(1196445184, 24, 2), gap +512;
rank 750: B 738 (1196445696, 24, 0),
gap to next rank None — rank 750 is the last
measured rank (B acts 751, ranks 0–750), so
this run closes the B-offset order. The B
indices in rank order are 272, 674, 735, 736,
737, 738.

Any law NOT PROVEN unless the numbers prove
it; no law is claimed here. The meaning of
run 102 is NOT PROVEN.
