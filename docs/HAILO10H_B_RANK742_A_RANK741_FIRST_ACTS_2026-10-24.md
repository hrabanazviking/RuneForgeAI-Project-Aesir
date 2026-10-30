# The acts at B-offset rank 742 and A-offset rank 741 in full, and the closing-run first-act comparison (AES-NUM-232)

Slice 4.232, worked under `docs/TASK_CONTRACT_4.232.md`
(contract published in the 4.231 closing commit @
ba6f6fa2). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section232.txt).

## Run and closing record

hef232.py is the verified hef231 base plus
arms232: hef231.py sha256
`1889ace338ce266829eaefed649a92107ce057013bb30b75c0eb79cf33b3fc6d`
(1,838,681 B) on both the VM and the device.
arms232 sha256
`232eb90caabde0da368b2dc3f1eb9a565ac072350587635b96fff6ffbba070b7`
(13,309 B); hef232.py sha256
`eabb65faca75f125247434f6f44eef2533969adebd17647b7b68fa6a6422358a`
(1,851,990 B) on both the VM and the device.
Crossing, stated exactly: arms232 was gzipped at
gzip -9 (sha256
`a0a3bf2fa0a0c93fa161a55b01c8fb9af5dfaf35b34be6e045559f36f1b88157`,
3,239 B) and split into nine 373 B parts (last
255 B); each part was written as its own file with
its own sha256 gate — all nine verified on-device
first try; the assembled gzip, arms and hef232
shas == VM on-device; hef232 assembled on-device
from hef231.py + arms232.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef232/h232 child; exactly ONE bounded host-side
child ran in detached tmux (session h232, created
2026-10-30 19:21:28 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef232.exit), err empty, and DONE232 as
its last line. Output hef232.out 57,632 lines /
10,460,021 B sha256
`ad301c932c365f5377c8f8bc0dcccd4363acd036cf600d9604a137014814b3d8`;
prefix against hef231.out: the first 57,563
lines differ from hef231.out in exactly TWO lines
(lines 41611 and 42872, frozenset element order
only — the AES-NUM-150 variance, verified by
same-sorted-characters comparison on both lines),
hef232.out adding exactly its own 69 section
lines (11,030 B, sha256
`c95b5895553e5d40090500b15d4c86ad0a1ef2c961ff73199fcd30bdd2e519be`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef232.out, hef232.py, arms232.py,
section232.txt, hef232.exit, run232.sh, gz232/,
check232.py); local lineage in
~/workspace/.verify-tmp/aesir232.

## (i) The act at B-offset rank 742 in full

The act (1196338688, 30008, 2) at B 25 is B-offset
rank 742 — the act immediately before the B
closing run (ranks 743–750). It occurs exactly
once: occurrences in A none, in B [25]. It is
B-only distinct (absent from context A). Its
correspondence key (1196338688, 30008) is held
only by itself: no A-only act carries that key,
and the only act in either list with that key is
itself.

Its incoming gap from rank 741 is +752 (from
(1196337936, 264, 1) at B 23, rank 741), NOT equal
to its own size (30008). Its outgoing gap to
rank 743 is +30,008 (to (1196368696, 280, 2) at
B 26, rank 743), EQUAL to its own size. The
B-offset neighbourhood of rank 742 is: rank 739:
B 20 (1196312608, 328, 0); rank 740: B 22
(1196313088, 24848, 1); rank 741: B 23
(1196337936, 264, 1) — each B-only distinct;
rank 743: B 26 (1196368696, 280, 2); rank 744:
B 229 (1196369408, 26128, 2); rank 745: B 272
(1196396032, 14352, 1) — each B-only distinct.
In B index order it follows B 24 immediately and
precedes B 26 immediately; its offset-order
neighbours (B 23 before, B 26 after) are not its
index-order neighbours on the incoming side.

## (ii) The act at A-offset rank 741 in full

The act (791777280, 24, 1) at A 734 is A-offset
rank 741 — the first act of the A closing run
(ranks 741–748). It occurs exactly once:
occurrences in A [734], in B none. It is A-only
distinct (absent from context B). Its
correspondence key (791777280, 24) is held only
by itself: no B-only act carries that key, and
the only act in either list with that key is
itself.

Its incoming gap from rank 740 is +488 (from
(791776792, 24, 0) at A 733, rank 740) and its
outgoing gap to rank 742 is +512 (to
(791777792, 24, 2) at A 735, rank 742); neither
gap equals its own size (24). The A-offset
neighbourhood of rank 741 is: rank 738: A 731
(791776256, 24, 2) shared single-positioned
(run 102); rank 739: A 732 (791776768, 24, 0)
shared single-positioned (run 102); rank 740:
A 733 (791776792, 24, 0) A-only; rank 742: A 735
(791777792, 24, 2) A-only; rank 743: A 736
(791778304, 24, 0) A-only; rank 744: A 744
(791778816, 24, 0) shared single-positioned
(run 102). In A index order it follows A 733
immediately and precedes A 735 immediately —
the same acts as its offset-order neighbours
on both sides.

## (iii) The closing-run first-act comparison in full

Side by side:

- A closing run first act: rank 741, index 734,
  act (791777280, 24, 1), class A-only distinct,
  in run 102 NO, incoming gap +488, outgoing
  gap +512.
- B closing run first act: rank 743, index 26,
  act (1196368696, 280, 2), class B-only
  distinct, in run 102 NO, incoming gap +30,008,
  outgoing gap +712.
- Contract tests: the A first act's outgoing gap
  (+512) equals the first gap of the A closing
  run's gap sequence as measured in AES-NUM-231
  (512) — YES; the B first act's outgoing gap
  (+712) equals the first gap of the B closing
  run's gap sequence as measured in AES-NUM-231
  (712) — YES.
- The two first acts agree in neither incoming
  gap (+488 vs +30,008), nor outgoing gap (+512
  vs +712), nor class label (A-only vs B-only
  distinct, the side-specific labels); they
  agree in run-102 membership only in that
  neither is a member.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
