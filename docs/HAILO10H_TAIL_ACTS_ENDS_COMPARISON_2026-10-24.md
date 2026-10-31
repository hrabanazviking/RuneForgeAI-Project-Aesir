# The act at A 745 and the act at B 747 each occur exactly once on their own side only, and all eight tail acts (A 745–748 / B 747–750) are side-only, with the two tails differing at every one of their four positions (AES-NUM-211)

Slice 4.211, worked under `docs/TASK_CONTRACT_4.211.md`
(contract published in the 4.210 closing commit @
b0e04a16). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device.

## Run and closing record

hef211.py is the verified hef210r base plus
arms211: hef210r.py sha256
`0eaf6d140d211d190dc6c2e25bf7218c074faa91ff05ade6049b6beb3ddc005d`
(1,574,646 B) on both the VM and the device.
arms211 sha256
`3d4fa1fd2f32fb5b6b2dbed1c95d56345d3d5b4e5f2f27ae2e7b8727da03e25d`
(13,064 B); hef211.py sha256
`3c6d275f9a4af001233475d18da5b4a44950fb239e62f0765ec5f914931b6a5e`
(1,587,710 B) on both the VM and the device.
Crossing, stated exactly: arms211 was gzipped at
gzip -9 (sha256
`4c28fd4f18827605fb92bf283610d030618d90672319525b4aab2cf207cd2ec7`,
3,388 B) and split into ten 373 B parts (last
31 B); each part was written as its own file with
its own sha256 gate and every part verified
on-device first try; the assembled gzip and arms
shas == VM on-device; hef211 assembled on-device
from hef210r.py + arms211.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef211/h211 child; exactly ONE bounded host-side
child ran in detached tmux (session h211, created
2026-10-30 13:06:48 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef211.exit), err empty, and DONE211 as
its last line. Output hef211.out 55,713 lines /
10,185,646 B sha256
`777c9bdca1a0622b32786541128b153634710a512062437f0c2fd115dd92c1f7`;
prefix against hef210r.out: the first 55,529
lines differ from hef210r.out in exactly ONE line
(line 41611, frozenset element order only — the
AES-NUM-150 variance), hef211.out adding exactly
its own 184 section lines (25,646 B, sha256
`638830b37bb7d4dff1a4e9a281e9b6140e8f02055153bd15eda17769589e361d`,
read in full on-device). Controls EXACT. Raw
output kept on the Pi at ~/aesir-build/
(hef211.out, hef211.py, arms211.py,
section211.txt, hef211.exit, run211.sh, gz211/);
local lineage in ~/workspace/.verify-tmp/aesir211.

## (i) The act at A 745 in full

The act (791779328, 24, 0) occurs exactly once,
on the A side only — A index 745, A-offset
rank 745; no B occurrence. It is A-only
distinct. Its (791779328, 24) correspondence
key is held only by itself on the A side; no
act in B carries that key. It is NOT a member
of run 102. It follows the last run-102 act
(791778816, 24, 0) at A 744 immediately in BOTH
A index order and A offset order (that act is
also A-offset rank 744), with incoming gap +512
in A-offset order. Its outgoing gap is +512 —
NOT its own size (24) — in A-offset order, to
the A-only act (791779840, 24, 1) at A 746 at
offset rank 746.

## (ii) The act at B 747 in full

The act (791781888, 24, 0) occurs exactly once,
on the B side only — B index 747, B-offset
rank 722; no A occurrence. It is B-only
distinct. Its (791781888, 24) correspondence
key is held only by itself on the B side; no
act in A carries that key. It is NOT a member
of run 102. It follows the last run-102 act
(791778816, 24, 0) at B 746 immediately in
B index order, but NOT in B offset order: its
offset-order predecessor is the B-only act
(791781376, 24, 1) at B 748, offset rank 721,
with incoming gap +512 in B-offset order. Its
outgoing gap is +8,271,872 — NOT its own size
(24) — in B-offset order, to the B-only act
(800053760, 24, 2) at B 749 at offset rank 723.

## (iii) The tail ends A 746–748 / B 748–750 in full

A side — the A tail is consecutive in BOTH
orders (index = offset rank at every tail
position), each act A-only distinct, occurring
exactly once, its key held only by itself on
the A side, none a member of run 102:
(791779840, 24, 1) at A 746, rank 746, outgoing
gap +512 in A-offset order; (791780352, 24, 2)
at A 747, rank 747, outgoing gap +512; and
(791780864, 24, 0) at A 748, rank 748 — the
last act of context A in both index order and
offset order (rank 748 is the maximum A rank).

B side — each act B-only distinct, occurring
exactly once, its key held only by itself on
the B side, none a member of run 102:
(791781376, 24, 1) at B 748, B-offset rank 721
— in B-offset order it sits BEFORE B 747
(rank 722) although it follows it in B index
order; its incoming gap is +2,560 in B-offset
order from the last run-102 act
(791778816, 24, 0) at B 746, rank 720, and its
outgoing gap is +512 to B 747's act.
(800053760, 24, 2) at B 749, B-offset rank 723;
its outgoing gap is +73,144,832 in B-offset
order to (873198592, 24, 0) at B 1, rank 724.
(973679616, 24, 0) at B 750, B-offset rank 727
— the last act of context B in index order,
but not in offset order: its offset-order
neighbours at ranks 724–726 are the B-only
acts at B 1, B 0 and B 27, and its outgoing
gap is +222,502,400 in B-offset order to
(1196182016, 24, 2) at B 5, rank 728.

Cross-side occurrences: NO tail act
(A 745–748 / B 747–750) occurs on the other
side at any index (A tail acts with
occurrences in B: none; B tail acts with
occurrences in A: none).

Full tail comparison: A 745–748 against
B 747–750 are NOT equal in order; they differ
at every position — differing positions
(0-based within the tail) [0, 1, 2, 3], 4 of
4. A tail: [(791779328, 24, 0),
(791779840, 24, 1), (791780352, 24, 2),
(791780864, 24, 0)]; B tail:
[(791781888, 24, 0), (791781376, 24, 1),
(800053760, 24, 2), (973679616, 24, 0)].
Measured observation only: the channel
sequence by tail position is (0, 1, 2, 0) on
BOTH tails, although no position's act
coincides.

Any law NOT PROVEN unless the numbers prove
it; no law is claimed here. The meaning of
run 102 is NOT PROVEN.
