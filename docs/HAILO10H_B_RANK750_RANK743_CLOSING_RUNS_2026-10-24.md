# The acts at B-offset ranks 750 and 743 in full, and the closing-run comparison (AES-NUM-231)

Slice 4.231, worked under `docs/TASK_CONTRACT_4.231.md`
(contract published in the 4.230 closing commit @
ba6f6fa2). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section231.txt).

## Run and closing record

hef231.py is the verified hef230 base plus
arms231: hef230.py sha256
`528eaccb163c10c6961f1988e61d335f0429e06b644f6166476cd2ddefe7b30b`
(1,825,485 B) on both the VM and the device.
arms231 sha256
`abb32e7599619aeedb5673418ed8867a7ce3b8348ba5a87b9a639c5b56e0dd90`
(13,196 B); hef231.py sha256
`1889ace338ce266829eaefed649a92107ce057013bb30b75c0eb79cf33b3fc6d`
(1,838,681 B) on both the VM and the device.
Crossing, stated exactly: arms231 was gzipped at
gzip -9 (sha256
`e11111c43dc9f2bdfbdde00d258f4af5ab48f95fe10de736eca24d06ae60ce5b`,
3,380 B) and split into ten 373 B parts (last
23 B); each part was written as its own file with
its own sha256 gate — all ten verified on-device
first try; the assembled gzip, arms and hef231
shas == VM on-device; hef231 assembled on-device
from hef230.py + arms231.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef231/h231 child; exactly ONE bounded host-side
child ran in detached tmux (session h231, created
2026-10-30 19:04:10 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef231.exit), err empty, and DONE231 as
its last line. Output hef231.out 57,563 lines /
10,448,991 B sha256
`1833e1e5c21ffd7c476d7b69700734a6623a02a945290f4d09f6591102cdde74`;
prefix against hef230.out: the first 57,480
lines are IDENTICAL to hef230.out (zero differing
lines — no AES-NUM-150 frozenset variance this
run), hef231.out adding exactly its own 83
section lines (12,837 B, sha256
`ed84c082495efdeb8ebe0c2cd9ff8f6894e1da998e105fb277d330cf48e2ef80`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef231.out, hef231.py, arms231.py,
section231.txt, hef231.exit, run231.sh, gz231/,
check231.py); local lineage in
~/workspace/.verify-tmp/aesir231.

## (i) The act at B-offset rank 750 in full

The act (1196445696, 24, 0) at B 738 is B-offset
rank 750 — the last measured B-offset rank (B
acts 751, ranks 0–750). It occurs exactly once:
occurrences in A none, in B [738]. It is B-only
distinct (absent from context A). Its
correspondence key (1196445696, 24) is held only
by itself: no A-only act carries that key, and
the only act in either list with that key is
itself.

Its incoming gap from rank 749 is +512 (from
(1196445184, 24, 2) at B 737, rank 749), NOT equal
to its own size (24). Rank 750 has no successor,
so no outgoing gap exists for it and none was
requested. The B-offset neighbourhood of rank
750 is: rank 747: B 735 (1196444160, 24, 0);
rank 748: B 736 (1196444672, 24, 1); rank 749:
B 737 (1196445184, 24, 2) — each B-only distinct.
In B index order it follows B 737 immediately
and precedes B 739 immediately, B 739 holding a
shared single-positioned run-102 act.

## (ii) The act at B-offset rank 743 in full

The act (1196368696, 280, 2) at B 26 is B-offset
rank 743 — the first act of the B closing run
(ranks 743–750). It occurs exactly once:
occurrences in A none, in B [26]. It is B-only
distinct (absent from context A). Its
correspondence key (1196368696, 280) is held only
by itself: no A-only act carries that key, and
the only act in either list with that key is
itself.

Its incoming gap from rank 742 is +30,008 (from
(1196338688, 30008, 2) at B 25, rank 742) and its
outgoing gap to rank 744 is +712 (to
(1196369408, 26128, 2) at B 229, rank 744);
neither gap equals its own size (280). The
B-offset neighbourhood of rank 743 is: rank 740:
B 22 (1196313088, 24848, 1); rank 741: B 23
(1196337936, 264, 1); rank 742: B 25
(1196338688, 30008, 2) — each B-only distinct;
rank 744: B 229 (1196369408, 26128, 2); rank 745:
B 272 (1196396032, 14352, 1); rank 746: B 674
(1196410880, 32784, 2) — each B-only distinct.
In B index order it follows B 25 immediately —
B 25 and B 26 follow each other immediately in
both orders — and precedes B 27 immediately.

## (iii) The closing-run comparison in full

Side by side, each run holding exactly 8 acts:

- Rank range and act count: A closing run —
  ranks 741–748 in A-offset order, 8 acts; B
  closing run — ranks 743–750 in B-offset order,
  8 acts.
- A closing run, in full: 741: A 734
  (791777280, 24, 1) A-only gap +512; 742: A 735
  (791777792, 24, 2) A-only gap +512; 743: A 736
  (791778304, 24, 0) A-only gap +512; 744: A 744
  (791778816, 24, 0) shared single-positioned
  gap +512; 745: A 745 (791779328, 24, 0) A-only
  gap +512; 746: A 746 (791779840, 24, 1) A-only
  gap +512; 747: A 747 (791780352, 24, 2) A-only
  gap +512; 748: A 748 (791780864, 24, 0) A-only
  gap None (last rank of the run).
- B closing run, in full: 743: B 26
  (1196368696, 280, 2) B-only gap +712; 744:
  B 229 (1196369408, 26128, 2) B-only gap
  +26,624; 745: B 272 (1196396032, 14352, 1)
  B-only gap +14,848; 746: B 674 (1196410880,
  32784, 2) B-only gap +33,280; 747: B 735
  (1196444160, 24, 0) B-only gap +512; 748:
  B 736 (1196444672, 24, 1) B-only gap +512;
  749: B 737 (1196445184, 24, 2) B-only gap
  +512; 750: B 738 (1196445696, 24, 0) B-only
  gap None (last rank of the run).
- Class composition: A run {A-only distinct: 7,
  shared single-positioned: 1} summing to 8
  exactly; B run {B-only distinct: 8} summing
  to 8 exactly.
- Run-102 membership: A run 1 in / 7 not in
  (the sole member is rank 744, run 102's last
  act); B run 0 in / 8 not in.
- Gap sequence inside each run (7 gaps): A run
  [512, 512, 512, 512, 512, 512, 512] — uniform;
  B run [712, 26624, 14848, 33280, 512, 512,
  512] — the sequences are NOT identical; the
  two runs agree only in their final three
  gaps (+512 each).

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
