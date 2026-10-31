# The A-only act at A 734 and the B-only act at B 736 occur exactly once on their own side only, each following the divergent act immediately in both index order and offset order with outgoing gap +512 (not its own size), and the shared act at A 737 / B 739 is the fifty-first act of run 102, resyncing the two index orders for exactly eight acts — the rest of run 102 — after which the tails of the two lists differ at every remaining position (AES-NUM-210)

Slice 4.210, worked under `docs/TASK_CONTRACT_4.210.md`
(contract published in the 4.209 closing commit @
fe489dc9) and, after the first launch crashed on a
worker-authored section bug, under
`docs/TASK_CONTRACT_4.210_RETRY.md` (published @
b9b1270b before the patch, per the AES-NUM-191
precedent). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw outputs, read in full on-device.

## Run and closing record

First launch (closed, never to be repeated under
TASK_CONTRACT_4.210): hef210.py is the verified
hef209 base plus arms210: hef209.py sha256
`de2b2cf14f137f3ce9d164b957f1e14408db42dc978cf064869dc7ddec7a9ad0`
(1,559,293 B) on both the VM and the device.
arms210 sha256
`efce9360859aafd0296f6e4f947ad76ce8aa5d10f01c4400773d8a3b8cb9214e`
(15,026 B); hef210.py sha256
`6457d9840e8f3d6d823c564ffee6393309bb6cc219c96ce89a6628e60c55f01d`
(1,574,319 B) on both the VM and the device.
Crossing, stated exactly: arms210 was gzipped at
gzip -9 (sha256
`73534401a727ebe78a2bdcf5cd073a1087a5760d0a39d0fc857bfc75f4c15084`,
3,787 B) and split into eleven 373 B parts (last
57 B); each part was written as its own file with
its own sha256 gate and every part verified
on-device first try; the assembled gzip and arms
shas == VM on-device; hef210 assembled on-device
from hef209.py + arms210.py, sha == VM, py_compile
OK. Pre-launch tmux/ps check found no hef210/h210
child; exactly ONE bounded host-side child ran in
detached tmux (session h210, created 2026-10-30
12:26:23 EDT) with the contract corpus argv (glob
order, MiniLM last), unbuffered (`python3 -u`).
The child ran the controls (all EXACT), arms (i)
and (ii) and arm (iii) in part, then crashed with
exit marker 1 (hef210.exit), hef210.err 489 B:
IndexError in the new section's 'RESYNC EXTENDED'
print — range(737, 757) asks for A indices up to
756 in a context of 749 acts (CONTEXT SIZES in
that run: A acts 749, B acts 751). No DONE210.
hef210.out 55,526 lines / 10,159,324 B sha256
`65a20990ed5f9b87d30c52271e3d40df7a8f167503f73359bcf847bf8051d023`;
its first 55,401 lines differ from hef209.out in
exactly ONE line (line 41611, frozenset element
order only — the AES-NUM-150 variance); its
partial section (125 lines / 18,348 B, sha256
`4c07c6b9999fc43775a5e7c4631faeb2b81bd47a7514b39ab7cef292c3cc333b`)
was read in full on-device and agrees with the
retry run on every shared line of arms (i)–(iii).

Retry launch (under TASK_CONTRACT_4.210_RETRY):
the ONLY code change was the extended-window
range(737, 757) / range(739, 759) becoming
range(737, 749) / range(739, 751) — exactly to
the end of both context lists — with its print
label becoming 'A 737-748 / B 739-750' (a
de-rename diff against arms210 shows exactly
those two lines and no other change). arms210r
sha256
`5da0f8dbe409c52eece94655ab7d89b9015b1097605173f176e8e53ccf08f0d0`
(15,353 B); hef210r.py sha256
`0eaf6d140d211d190dc6c2e25bf7218c074faa91ff05ade6049b6beb3ddc005d`
(1,574,646 B) on both the VM and the device,
assembled on-device from hef209.py + arms210r.py.
Crossing: arms210r gzipped at gzip -9 (sha256
`0200e9038d9c14deaaaf35403b7dbc8df63f46a26ff6fcfe80d31061a366499a`,
3,798 B), split into eleven 373 B parts (last
68 B), each sha-gated and verified on-device
first try; py_compile OK. Pre-launch tmux/ps
check found no hef210r/h210r child; exactly ONE
bounded host-side child ran in detached tmux
(session h210r, created 2026-10-30 12:36:31 EDT)
with the contract corpus argv, unbuffered. The
child finished with exit marker 0 (hef210r.exit),
err empty, and DONE210r as its last line — the
marker carries the retry lineage's 'r' suffix
because the arms rename (210 → 210r) renamed the
marker string too; every other success term of
the retry contract (exit 0, err empty, complete
section) was met exactly, and the suffix is
recorded here rather than hidden. Output
hef210r.out 55,529 lines / 10,160,000 B sha256
`22a2450f05ea68f87f2a5bd1ada467984420d8e44be50dabd560aecc41153e06`;
prefix against hef209.out: the first 55,401
lines differ from hef209.out in exactly TWO
lines (lines 41611 and 42872, frozenset element
order only — the AES-NUM-150 variance),
hef210r.out adding exactly its own 128 section
lines (19,024 B, sha256
`5ec8d82dde59f933ff8ba7eee46f9b0510194748e023d90ef47d7cb916ab33bd`,
read in full on-device). Controls EXACT. Raw
output kept on the Pi at ~/aesir-build/
(hef210.out, hef210.py, arms210.py,
section210.txt, hef210.exit, hef210.err,
run210.sh, gz210/; hef210r.out, hef210r.py,
arms210r.py, section210r.txt, hef210r.exit,
run210r.sh, gz210r/); local lineage in
~/workspace/.verify-tmp/aesir210 and
~/workspace/.verify-tmp/aesir210r.

## (i) The A-only act at A 734 in full

The act (791777280, 24, 1) occurs exactly once,
on the A side only — A index 734, A-offset
rank 741; no B occurrence. It is A-only
distinct. Its (791777280, 24) correspondence
key is held only by itself on the A side; no
act in B carries that key. It follows the
divergent A-only act (791776792, 24, 0) at
A 733 immediately in BOTH A index order and
A offset order, with incoming gap +488 in
A-offset order. Its outgoing gap is +512 —
NOT its own size (24) — in A-offset order, to
the A-only act (791777792, 24, 2) at A 735 at
offset rank 742.

## (ii) The B-only act at B 736 in full

The act (1196444672, 24, 1) occurs exactly
once, on the B side only — B index 736,
B-offset rank 748; no A occurrence. It is
B-only distinct. Its (1196444672, 24)
correspondence key is held only by itself on
the B side; no act in A carries that key. It
follows the divergent B-only act
(1196444160, 24, 0) at B 735 immediately in
BOTH B index order and B offset order, with
incoming gap +512 in B-offset order. Its
outgoing gap is +512 — NOT its own size
(24) — in B-offset order, to the B-only act
(1196445184, 24, 2) at B 737 at offset
rank 749.

## (iii) The shared resync act at A 737 / B 739 in full

The act (768609280, 24, 0) occurs exactly once
on each side — A index 737, A-offset rank 33;
B index 739, B-offset rank 34 — and is shared
single-positioned. Its (768609280, 24)
correspondence key is held by no A-only or
B-only act on either side. In index order it
follows the four side-only acts on each side
(A 733–736 / B 735–738). In offset order its
placement is distant: its offset-order
predecessor on both sides is (755688960, 24, 2)
at A 743 / B 745, offset rank 32 / 33, with
incoming gap +12,920,320 in both offset
orders; its outgoing gap is +512 — NOT its
own size (24) — in BOTH offset orders, to
(768609792, 24, 1) at A 738 / B 740 at offset
rank 34 / 35.
Run-102 membership, measured directly against
sruns139[102]: the act IS a member of run 102
(length 58, shift +2, A 683–744 / B 685–746)
and is its fifty-first act (1-based ordinal
51); its previous run-102 member is the
fiftieth act (791776768, 24, 0) at A 732 /
B 734 and its next run-102 member is
(768609792, 24, 1) at A 738 / B 740. The four
side-only acts on each side are not run-102
members, so the run's own sequence was never
interrupted — only the raw index orders
diverged.
Resync, measured in index order: the window
A 737–744 against B 739–746 is equal in order,
exactly — eight acts, (768609280, 24, 0),
(768609792, 24, 1), (768610304, 24, 2),
(768610816, 24, 0), (755602432, 24, 0),
(755680256, 24, 1), (755688960, 24, 2) and the
last run-102 act (791778816, 24, 0) at
A 744 / B 746 — i.e. run-102 members 51–58,
the whole remainder of run 102. Extended to
the ends of both lists, A 737–748 against
B 739–750, the sequences are NOT equal: the
consecutive-equal prefix is exactly 8 acts,
and the remaining positions (0-based 8, 9,
10, 11 from the resync) differ at every
position, first at A 745's (791779328, 24, 0)
against B 747's (791781888, 24, 0). The
resumed identical-order sequence is therefore
exactly 8 acts long and ends at the last
run-102 act; after it, each list carries
exactly four further acts (A 745–748 /
B 747–750), no two of which coincide in
position.

Any law NOT PROVEN unless the numbers prove
it; no law is claimed here. The meaning of
run 102 is NOT PROVEN.
