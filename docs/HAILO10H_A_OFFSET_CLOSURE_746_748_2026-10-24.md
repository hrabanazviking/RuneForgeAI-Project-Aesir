# The acts at A 746, A 747 and A 748 each occur exactly once on the A side only, and the A-offset-order closure is complete at rank 748, the last measured rank (AES-NUM-217)

Slice 4.217, worked under `docs/TASK_CONTRACT_4.217.md`
(contract published in the 4.216 closing commit @
15b8bb94). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section217.txt, via its summary and neighbourhood
lines).

## Run and closing record

hef217.py is the verified hef216 base plus
arms217: hef216.py sha256
`596dba5ea30cdefb3c4178d34b6de2c532e110a922f3045b2248e771c353f4fe`
(1,651,382 B) on both the VM and the device.
arms217 sha256
`d2b3e5128ca1b22c30b415a9a271e6ae6d60e1c45b4517c0c3649c6fcb1b1099`
(13,381 B); hef217.py sha256
`0f0b7d3085dc2f85ba1ad6602be0632204bb7f58ec90bc46a570f6757b8e74f9`
(1,664,763 B) on both the VM and the device.
Crossing, stated exactly: arms217 was gzipped at
gzip -9 (sha256
`7fb2ef6397ad66d05a389907e32633497f49ca99b1d7f692601039d5762c8ec4`,
3,147 B) and split into nine 373 B parts (last
163 B); each part was written as its own file with
its own sha256 gate — eight parts verified
on-device first try; one part (p_ag) was rejected
on its first write attempt (base64 validation,
nothing committed) and was resent verbatim and
verified; the assembled gzip, arms
and hef217 shas == VM on-device; hef217 assembled
on-device from hef216.py + arms217.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef217/h217 child; exactly ONE bounded host-side
child ran in detached tmux (session h217, created
2026-10-30 14:49:37 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef217.exit), err empty, and DONE217 as
its last line. Output hef217.out 56,346 lines /
10,276,277 B sha256
`e1c3d13cd31182c91167f807248530f9deabe244eb8d19add7995cd0982abb6e`;
prefix against hef216.out: the first 56,255
lines differ from hef216.out in exactly two
lines (lines 41611 and 42872, frozenset element
order only — the AES-NUM-150 variance),
hef217.out adding exactly its own 91 section
lines (13,034 B, sha256
`da01683f700857c3b15edf2ba38bd423483098ee5ffd3c5c61148ec28dcbe967`).
Controls EXACT. Raw
output kept on the Pi at ~/aesir-build/
(hef217.out, hef217.py, arms217.py,
section217.txt, hef217.exit, run217.sh, gz217/);
local lineage in ~/workspace/.verify-tmp/aesir217.

## (i) The act at A 746 in full

The act (791779840, 24, 1) occurs exactly once,
on the A side only — A index 746, A-offset
rank 746; no B occurrence. It is A-only
distinct. Its (791779840, 24) correspondence
key is held only by itself on the A side; no
act in B carries that key. It is NOT a member
of run 102. It follows the A-only act
(791779328, 24, 0) at A 745 immediately in
both A index order and A-offset order (rank
745 then rank 746), with incoming gap +512 in
A-offset order. Its outgoing gap is +512 —
NOT its own size (24) — in A-offset order, to
the A-only act (791780352, 24, 2) at A 747 at
offset rank 747. In A index order it sits
between the A-only act at A 745 and the
A-only act at A 747.

## (ii) The act at A 747 in full

The act (791780352, 24, 2) occurs exactly
once, on the A side only — A index 747, A-offset
rank 747; no B occurrence. It is A-only
distinct. Its (791780352, 24) correspondence
key is held only by itself on the A side; no
act in B carries that key. It is NOT a member
of run 102. In A-offset order it follows A 746's
act immediately (rank 746 then rank 747), with
incoming gap +512 in A-offset order; it also
follows A 746's act immediately in A index
order. Its outgoing gap is +512 — NOT its own
size (24) — in A-offset order, to the A-only act
(791780864, 24, 0) at A 748 at offset rank 748.
In A index order it sits between the A-only
act at A 746 and the A-only act at A 748.

## (iii) The act at A 748 in full, and the A-offset-order closure

The act (791780864, 24, 0) at A 748, A-offset
rank 748, occurs exactly once, on the A side
only; A-only distinct; its (791780864, 24)
key held only by itself on the A side, no B
act under that key; NOT a member of run 102.
In A-offset order it follows A 747's act
immediately (rank 747 then rank 748), with
incoming gap +512 in A-offset order; it also
follows A 747's act immediately in A index
order. It has NO outgoing gap: rank 748 is
the last measured rank (A acts 749, ranks
0–748), so its gap to a next rank is None.
It is also the last A index (A acts 749,
indices 0–748), so it has no A-index successor
either.

The A-offset-order closure in full: A acts
749, ranks 0–748; the last rank is 748, its
A index is 748 and its act is (791780864,
24, 0), gap beyond the last rank None. The
closing run of ranks 743–748 in full: rank 743:
A 736 (791778304, 24, 0), A-only distinct,
not in run 102, gap to next rank +512;
rank 744: A 744 (791778816, 24, 0), shared
single-positioned (run 102, shift +2) — the
last act of run 102 — gap +512; rank 745:
A 745 (791779328, 24, 0), A-only distinct,
not in run 102, gap +512; rank 746: A 746
(791779840, 24, 1), A-only distinct, not in
run 102, gap +512; rank 747: A 747
(791780352, 24, 2), A-only distinct, not in
run 102, gap +512; rank 748: A 748
(791780864, 24, 0), A-only distinct, not in
run 102, gap to next rank None. This run
closes the A-offset order. Unlike the
B-offset closing run (AES-NUM-216, six
consecutive B-only acts, none in run 102),
this A closing run is NOT uniformly A-only:
its rank-744 act is the shared run-102 final
act. The A indices in rank order are 736,
744, 745, 746, 747, 748.

Any law NOT PROVEN unless the numbers prove
it; no law is claimed here. The meaning of
run 102 is NOT PROVEN.
