# The acts at B 736, B 737 and B 738 each occur exactly once on the B side only, and the B-offset-order closure is complete at rank 750, the last measured rank (AES-NUM-216)

Slice 4.216, worked under `docs/TASK_CONTRACT_4.216.md`
(contract published in the 4.215 closing commit @
89e9b5f6). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section216.txt, via its summary and neighbourhood
lines).

## Run and closing record

hef216.py is the verified hef215 base plus
arms216: hef215.py sha256
`816f845c1ad41b972080ccfd31e53ba350046edf2173a1a031093ca00c97c1d3`
(1,637,937 B) on both the VM and the device.
arms216 sha256
`159f6583dcf62f16285d4095ac4f6723873e18837183c8b247d6369c49d8ddd7`
(13,445 B); hef216.py sha256
`596dba5ea30cdefb3c4178d34b6de2c532e110a922f3045b2248e771c353f4fe`
(1,651,382 B) on both the VM and the device.
Crossing, stated exactly: arms216 was gzipped at
gzip -9 (sha256
`4199783316408d9a22370ca64e8b21a59f8cf0147547963bc229657eedc72c92`,
3,184 B) and split into nine 373 B parts (last
200 B); each part was written as its own file with
its own sha256 gate and every part verified
on-device first try; the assembled gzip, arms
and hef216 shas == VM on-device; hef216 assembled
on-device from hef215.py + arms216.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef216/h216 child; exactly ONE bounded host-side
child ran in detached tmux (session h216, created
2026-10-30 14:35:16 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef216.exit), err empty, and DONE216 as
its last line. Output hef216.out 56,255 lines /
10,263,243 B sha256
`667c08b8dd4fc7d4b7f6a29dbd0dcfd2cb27b396ec20012adaec6c322c42ad1f`;
prefix against hef215.out: the first 56,152
lines differ from hef215.out in exactly two
lines (lines 41611 and 42872, frozenset element
order only — the AES-NUM-150 variance),
hef216.out adding exactly its own 103 section
lines (14,774 B, sha256
`4f90e8b49b882e36ebed0f1ae5ce0f8533ebb4084606c4c14fa9f725f6e3ccf8`).
Controls EXACT. Raw
output kept on the Pi at ~/aesir-build/
(hef216.out, hef216.py, arms216.py,
section216.txt, hef216.exit, run216.sh, gz216/);
local lineage in ~/workspace/.verify-tmp/aesir216.

## (i) The act at B 736 in full

The act (1196444672, 24, 1) occurs exactly once,
on the B side only — B index 736, B-offset
rank 748; no A occurrence. It is B-only
distinct. Its (1196444672, 24) correspondence
key is held only by itself on the B side; no
act in A carries that key. It is NOT a member
of run 102. It follows the B-only act
(1196444160, 24, 0) at B 735 immediately in
both B index order and B-offset order (rank
747 then rank 748), with incoming gap +512 in
B-offset order. Its outgoing gap is +512 —
NOT its own size (24) — in B-offset order, to
the B-only act (1196445184, 24, 2) at B 737 at
offset rank 749. In B index order it sits
between the B-only act at B 735 and the
B-only act at B 737.

## (ii) The act at B 737 in full

The act (1196445184, 24, 2) occurs exactly
once, on the B side only — B index 737, B-offset
rank 749; no A occurrence. It is B-only
distinct. Its (1196445184, 24) correspondence
key is held only by itself on the B side; no
act in A carries that key. It is NOT a member
of run 102. In B-offset order it follows B 736's
act immediately (rank 748 then rank 749), with
incoming gap +512 in B-offset order; it also
follows B 736's act immediately in B index
order. Its outgoing gap is +512 — NOT its own
size (24) — in B-offset order, to the B-only act
(1196445696, 24, 0) at B 738 at offset rank 750.
In B index order it sits between the B-only
act at B 736 and the B-only act at B 738.

## (iii) The act at B 738 in full, and the B-offset-order closure

The act (1196445696, 24, 0) at B 738, B-offset
rank 750, occurs exactly once, on the B side
only; B-only distinct; its (1196445696, 24)
key held only by itself on the B side, no A
act under that key; NOT a member of run 102.
In B-offset order it follows B 737's act
immediately (rank 749 then rank 750), with
incoming gap +512 in B-offset order; it also
follows B 737's act immediately in B index
order. It has NO outgoing gap: rank 750 is
the last measured rank (B acts 751, ranks
0–750), so its gap to a next rank is None.
In B index order it sits between the B-only
act at B 737 and the shared act at B 739.

The B-offset-order closure in full: B acts
751, ranks 0–750; the last rank is 750, its
B index is 738 and its act is (1196445696,
24, 0), gap beyond the last rank None. The
closing run of ranks 745–750 in full — every
act B-only distinct, occurring exactly once,
none a member of run 102: rank 745: B 272
(1196396032, 14352, 1), gap to next rank
+14,848; rank 746: B 674 (1196410880, 32784,
2), gap +33,280; rank 747: B 735 (1196444160,
24, 0), gap +512; rank 748: B 736
(1196444672, 24, 1), gap +512; rank 749:
B 737 (1196445184, 24, 2), gap +512;
rank 750: B 738 (1196445696, 24, 0), gap to
next rank None. This run closes the B-offset
order. The B indices in rank order are 272,
674, 735, 736, 737, 738.

Any law NOT PROVEN unless the numbers prove
it; no law is claimed here. The meaning of
run 102 is NOT PROVEN.
