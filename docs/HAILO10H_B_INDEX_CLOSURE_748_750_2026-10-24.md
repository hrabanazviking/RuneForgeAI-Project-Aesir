# The acts at B 748, B 749 and B 750 each occur exactly once on the B side only, and the B-index-order closure is complete at index 750, the last measured index (AES-NUM-218)

Slice 4.218, worked under `docs/TASK_CONTRACT_4.218.md`
(contract published in the 4.217 closing commit @
5935a9c7). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section218.txt, via its summary and neighbourhood
lines).

## Run and closing record

hef218.py is the verified hef217 base plus
arms218: hef217.py sha256
`0f0b7d3085dc2f85ba1ad6602be0632204bb7f58ec90bc46a570f6757b8e74f9`
(1,664,763 B) on both the VM and the device.
arms218 sha256
`97398c1985169e6878ae1f52cb0c205839d060d0569520c3e56b40e0470afa20`
(13,530 B); hef218.py sha256
`3d0ca59f0cd706cb15b05bebe7fb277a02389cacfcc81bed9b482376cf694920`
(1,678,293 B) on both the VM and the device.
Crossing, stated exactly: arms218 was gzipped at
gzip -9 (sha256
`41601cdf564bb5b001ed0bce684694addf986ca3feeac08de0df6b23f8a46125`,
3,232 B) and split into nine 373 B parts (last
248 B); each part was written as its own file with
its own sha256 gate — seven parts verified
on-device first try; one part (p_af) failed its
sha256 gate twice at the 373 B boundary (write
discarded both times, nothing committed) and
landed clean when its boundary was changed: it
was split into two halves (187 B + 186 B, each
sha-gated) whose on-device concatenation
reproduced p_af's sha256 exactly; the assembled
gzip, arms and hef218 shas == VM on-device;
hef218 assembled on-device from hef217.py +
arms218.py, sha == VM, py_compile OK. Pre-launch
tmux/ps check found no hef218/h218 child; exactly
ONE bounded host-side child ran in detached tmux
(session h218, created 2026-10-30 15:11:58 EDT)
with the contract corpus argv (glob order, MiniLM
last), unbuffered (`python3 -u`). The child
finished with exit marker 0 (hef218.exit), err
empty, and DONE218 as its last line. Output
hef218.out 56,444 lines / 10,290,531 B sha256
`f0b1c97ef325381e5bb2619d379992c82cc88ddb1c0bc346a1b0c04c25ffcc33`;
prefix against hef217.out: the first 56,346
lines differ from hef217.out in exactly two
lines (lines 41611 and 42872, frozenset element
order only — the AES-NUM-150 variance),
hef218.out adding exactly its own 98 section
lines (14,254 B, sha256
`b6a37bbef9c081060540002d9c586bf0443b83d86054b99610befcc95a05b53f`).
Controls EXACT. Raw
output kept on the Pi at ~/aesir-build/
(hef218.out, hef218.py, arms218.py,
section218.txt, hef218.exit, run218.sh, gz218/);
local lineage in ~/workspace/.verify-tmp/aesir218.

## (i) The act at B 748 in full

The act (791781376, 24, 1) occurs exactly once,
on the B side only — B index 748, B-offset
rank 721; no A occurrence. It is B-only
distinct. Its (791781376, 24) correspondence
key is held only by itself on the B side; no
act in A carries that key. It is NOT a member
of run 102. It follows the shared
single-positioned act (791778816, 24, 0) at
B 746 — the last act of run 102 — immediately
in B-offset order (rank 720 then rank 721),
with incoming gap +2,560 in B-offset order.
Its outgoing gap is +512 — NOT its own size
(24) — in B-offset order, to the B-only act
(791781888, 24, 0) at B 747 at offset rank 722.
In B index order it sits between that same
B 747 act and the B-only act at B 749: B 747
and B 748 stand in opposite orders in the two
orders (in index order B 747 precedes B 748;
in offset order B 748 precedes B 747, their
offsets differing by 512).

## (ii) The act at B 749 in full

The act (800053760, 24, 2) occurs exactly
once, on the B side only — B index 749, B-offset
rank 723; no A occurrence. It is B-only
distinct. Its (800053760, 24) correspondence
key is held only by itself on the B side; no
act in A carries that key. It is NOT a member
of run 102. In B-offset order it follows
B 747's act (791781888, 24, 0) immediately
(rank 722 then rank 723), with incoming gap
+8,271,872 in B-offset order. Its outgoing
gap is +73,144,832 — NOT its own size (24) —
in B-offset order, to the B-only act
(873198592, 24, 0) at B 1 at offset rank 724.
In B index order it sits between the B-only
act at B 748 and the B-only act at B 750.

## (iii) The act at B 750 in full, and the B-index-order closure

The act (973679616, 24, 0) at B 750, B-offset
rank 727, occurs exactly once, on the B side
only; B-only distinct; its (973679616, 24)
key held only by itself on the B side, no A
act under that key; NOT a member of run 102.
In B-offset order it follows the B-only act
(873199616, 24, 2) at B 27 immediately (rank
726 then rank 727), with incoming gap
+100,480,000 in B-offset order. Its outgoing
gap in B-offset order is +222,502,400 — NOT
its own size (24) — to the B-only act
(1196182016, 24, 2) at B 5 at offset rank 728:
rank 727 is NOT the last B-offset rank (B acts
751, ranks 0–750). It IS the last B index
(B acts 751, indices 0–750), so it has no
B-index successor: its offset difference to a
next index is None. In B index order it
follows B 749's act immediately.

The B-index-order closure in full: B acts
751, indices 0–750; the last index is 750, its
act is (973679616, 24, 0) at B-offset rank 727,
offset difference beyond the last index None.
Indices 748–750 in full: index 748: B 748
(791781376, 24, 1), B-only distinct, not in
run 102, B-offset rank 721, offset difference
to next index +8,272,384; index 749: B 749
(800053760, 24, 2), B-only distinct, not in
run 102, rank 723, difference +173,625,856;
index 750: B 750 (973679616, 24, 0), B-only
distinct, not in run 102, rank 727, difference
None. The tail of indices 745–750 in full:
index 745: B 745 (755688960, 24, 2), shared
single-positioned (run 102, shift +2), rank
33, difference +36,089,856; index 746: B 746
(791778816, 24, 0), shared single-positioned
— the last act of run 102 — rank 720,
difference +3,072; index 747: B 747
(791781888, 24, 0), B-only distinct, not in
run 102, rank 722, difference −512 (its index
successor B 748 carries the smaller offset);
index 748, 749 and 750 as above. This tail
closes the B-index order. Unlike the
B-offset closing run (AES-NUM-216, six
consecutive B-only acts, none in run 102),
this B-index tail is NOT uniformly B-only:
its first two acts are shared run-102 acts,
the second of them run 102's last act.

Any law NOT PROVEN unless the numbers prove
it; no law is claimed here. The meaning of
run 102 is NOT PROVEN.
