# The acts at A-offset rank 742 and B-offset rank 744 in full, and the closing-run second-act comparison (AES-NUM-233)

Slice 4.233, worked under `docs/TASK_CONTRACT_4.233.md`
(contract published in the 4.232 closing commit @
6be2c585). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section233.txt).

## Run and closing record

hef233.py is the verified hef232 base plus
arms233: hef232.py sha256
`eabb65faca75f125247434f6f44eef2533969adebd17647b7b68fa6a6422358a`
(1,851,990 B) on both the VM and the device.
arms233 sha256
`ff144e1703bc52930c80dd48d804bba77615cc185e66ddd1936cbb816359d067`
(13,489 B); hef233.py sha256
`325e58ca7be9cceba70907544f17d7a043bb02922469c890e55b8a70bb292b28`
(1,865,479 B) on both the VM and the device.
Crossing, stated exactly: arms233 was gzipped at
gzip -9 (sha256
`de0e522720a6b2597f565a83c6de947f026afaab0d8a11c997d37f0172bfdab7`,
3,250 B) and split into nine 373 B parts (last
266 B); each part was written as its own file with
its own sha256 gate — all nine verified on-device
first try; the assembled gzip, arms and hef233
shas == VM on-device; hef233 assembled on-device
from hef232.py + arms233.py, sha == VM,
py_compile OK. Pre-launch tmux/ps check found no
hef233/h233 child; exactly ONE bounded host-side
child ran in detached tmux (session h233, created
2026-10-30 19:39:28 EDT) with the contract corpus
argv (glob order, MiniLM last), unbuffered
(`python3 -u`). The child finished with exit
marker 0 (hef233.exit), err empty, and DONE233 as
its last line. Output hef233.out 57,702 lines /
10,471,244 B sha256
`80799709c0be245e9d5cae0fdd18c3efe662e94913e88c10f7240c63f413ced6`;
prefix against hef232.out: the first 57,632
lines differ from hef232.out in exactly TWO lines
(lines 41611 and 42872, frozenset element order
only — the AES-NUM-150 variance, verified by
same-sorted-characters comparison on both lines),
hef233.out adding exactly its own 70 section
lines (11,223 B, sha256
`eb012c4245393c5730e7e61cfed9f23ee42f92eaabda76b877309b2498e3c6c3`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef233.out, hef233.py, arms233.py,
section233.txt, hef233.exit, run233.sh, gz233/,
check233.py); local lineage in
~/workspace/.verify-tmp/aesir233.

## (i) The act at A-offset rank 742 in full

The act (791777792, 24, 2) at A 735 is A-offset
rank 742 — the second act of the A closing run
(ranks 741–748). It occurs exactly once:
occurrences in A [735], in B none. It is
A-only distinct (absent from context B). Its
correspondence key (791777792, 24) is held
only by itself: no B-only act carries that key,
and the only act in either list with that key is
itself.

Its incoming gap from rank 741 is +512 (from
(791777280, 24, 1) at A 734, rank 741) and its
outgoing gap to rank 743 is +512 (to
(791778304, 24, 0) at A 736, rank 743); neither
gap equals its own size (24). The A-offset
neighbourhood of rank 742 is: rank 739: A 732
(791776768, 24, 0) shared single-positioned
(run 102); rank 740: A 733 (791776792, 24, 0)
A-only; rank 741: A 734 (791777280, 24, 1)
A-only; rank 743: A 736 (791778304, 24, 0)
A-only; rank 744: A 744 (791778816, 24, 0)
shared single-positioned (run 102); rank 745:
A 745 (791779328, 24, 0) A-only. In A index
order it follows A 734 immediately and precedes
A 736 immediately — the same acts as its
offset-order neighbours on both sides.

## (ii) The act at B-offset rank 744 in full

The act (1196369408, 26128, 2) at B 229 is
B-offset rank 744 — the second act of the B
closing run (ranks 743–750). It occurs exactly
once: occurrences in A none, in B [229]. It is
B-only distinct (absent from context A). Its
correspondence key (1196369408, 26128) is held
only by itself: no A-only act carries that key,
and the only act in either list with that key is
itself.

Its incoming gap from rank 743 is +712 (from
(1196368696, 280, 2) at B 26, rank 743) and its
outgoing gap to rank 745 is +26,624 (to
(1196396032, 14352, 1) at B 272, rank 745);
neither gap equals its own size (26128). The
B-offset neighbourhood of rank 744 is: rank 741:
B 23 (1196337936, 264, 1); rank 742: B 25
(1196338688, 30008, 2); rank 743: B 26
(1196368696, 280, 2); rank 745: B 272
(1196396032, 14352, 1); rank 746: B 674
(1196410880, 32784, 2); rank 747: B 735
(1196444160, 24, 0) — each B-only distinct.
In B index order B 229 sits between B 228 and
B 230 (shared acts of other runs); its
offset-order neighbours (B 26 before, B 272
after) are not its index-order neighbours on
either side.

## (iii) The closing-run second-act comparison in full

Side by side:

- A closing run second act: rank 742, index 735,
  act (791777792, 24, 2), class A-only distinct,
  in run 102 NO, incoming gap +512, outgoing
  gap +512.
- B closing run second act: rank 744, index 229,
  act (1196369408, 26128, 2), class B-only
  distinct, in run 102 NO, incoming gap +712,
  outgoing gap +26,624.
- Contract tests: the A second act's outgoing gap
  (+512) equals the second gap of the A closing
  run's gap sequence as measured in AES-NUM-231
  (512) — YES; the B second act's outgoing gap
  (+26,624) equals the second gap of the B closing
  run's gap sequence as measured in AES-NUM-231
  (26624) — YES.
- The two second acts agree in neither incoming
  gap (+512 vs +712), nor outgoing gap (+512
  vs +26,624), nor class label (A-only vs B-only
  distinct, the side-specific labels); they
  agree in run-102 membership only in that
  neither is a member.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
