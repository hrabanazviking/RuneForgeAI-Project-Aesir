# The A and B closing runs in full, and the closing-run full comparison (AES-NUM-240)

Slice 4.240, worked under `docs/TASK_CONTRACT_4.240.md`
(contract published in the 4.239 closing commit @
7017544f). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run
of any kind. All findings below are taken from the
sha-verified raw output, read in full on-device
(section240.txt).

## Run and closing record

hef240.py is the verified hef239 base plus
arms240: hef239.py sha256
`b6b7ff56d0c13771e73852f21e0b70f61b069eb81d7fae475fd3163c2f624d68`
(1,946,806 B) on both the VM and the device.
arms240 sha256
`fbbe915d457e01a50325806eae07be72b10ae53d37b5e09e52e643cf7a552032`
(13,615 B); hef240.py sha256
`32decec8391cf1a6b84928bc30eff0151b59a671e71a2fdb9411ed4743f52534`
(1,960,421 B) on both the VM and the device.
Crossing, stated exactly: arms240 was gzipped at
gzip -9 (sha256
`c6e77a31782c3d4c34e9c1bd9633e9f2f9e13017b015fde9f82b4eae713c1b5f`,
3,415 B) and split into ten 373 B parts (last
58 B); each part was written as its own file with
its own sha256 gate — all ten verified on-device
(two parts were first attempted in parallel with
the directory-creating part and failed on the
missing directory; both were resent sequentially
and verified first try on the resend — no byte
was ever accepted unverified). The assembled
gzip, arms and hef240 shas == VM on-device;
hef240 assembled on-device from hef239.py +
arms240.py, sha == VM, py_compile OK. Pre-launch
tmux/ps check found no hef240/h240 child; exactly
ONE bounded host-side child ran in detached tmux
(session h240, created 2026-10-30 21:47:02 EDT)
with the contract corpus argv (glob order, MiniLM
last), unbuffered (`python3 -u`), and finished
with exit marker 0 (hef240.exit), err empty, and
DONE240 as its last line. Output hef240.out
58,141 lines / 10,545,132 B sha256
`b7f38e9c0eaefc5a92ac7ebaab6a7d40bf55e6a7f4942795a93398119cbd65fd`;
prefix against hef239.out: the first 58,097
lines differ from hef239.out in exactly ONE line
(line 42872, frozenset element order only — the
AES-NUM-150 variance, verified by
same-sorted-characters comparison; line 41611,
the other recurring variance line, did not
differ this run), hef240.out adding exactly its
own 44 section lines (9,882 B, sha256
`735ce8ca3d117100fe6b1094c5d6f858b0ad18b97bab86de7a50c5efce0520af`).
Controls EXACT. Raw output kept on the Pi at
~/aesir-build/ (hef240.out, hef240.py, arms240.py,
section240.txt, hef240.exit, run240.sh, gz240/,
check240.py); local lineage in
~/workspace/.verify-tmp/aesir240.

## (i) The A closing run in full

The A closing run is ranks 741–748 in A-offset
order, 8 acts. Every act's stated rank, index and
act matches its per-act statement in
AES-NUM-232..239 (printed match TRUE for all
eight):

- 741: A 734 (791777280, 24, 1) A-only distinct,
  channel 1, in run 102 NO.
- 742: A 735 (791777792, 24, 2) A-only distinct,
  channel 2, in run 102 NO.
- 743: A 736 (791778304, 24, 0) A-only distinct,
  channel 0, in run 102 NO.
- 744: A 744 (791778816, 24, 0) shared
  single-positioned (run 102, shift +2),
  channel 0, in run 102 YES.
- 745: A 745 (791779328, 24, 0) A-only distinct,
  channel 0, in run 102 NO.
- 746: A 746 (791779840, 24, 1) A-only distinct,
  channel 1, in run 102 NO.
- 747: A 747 (791780352, 24, 2) A-only distinct,
  channel 2, in run 102 NO.
- 748: A 748 (791780864, 24, 0) A-only distinct,
  channel 0, in run 102 NO — terminal (rank 748
  is the last of 749 A-offset ranks).

Internal gap sequence: [512, 512, 512, 512, 512,
512, 512] — equals the AES-NUM-231 measured
sequence exactly (printed test TRUE).

## (ii) The B closing run in full

The B closing run is ranks 743–750 in B-offset
order, 8 acts. Every act's stated rank, index and
act matches its per-act statement in
AES-NUM-232..239 (printed match TRUE for all
eight):

- 743: B 26 (1196368696, 280, 2) B-only distinct,
  channel 2, in run 102 NO.
- 744: B 229 (1196369408, 26128, 2) B-only
  distinct, channel 2, in run 102 NO.
- 745: B 272 (1196396032, 14352, 1) B-only
  distinct, channel 1, in run 102 NO.
- 746: B 674 (1196410880, 32784, 2) B-only
  distinct, channel 2, in run 102 NO.
- 747: B 735 (1196444160, 24, 0) B-only distinct,
  channel 0, in run 102 NO.
- 748: B 736 (1196444672, 24, 1) B-only distinct,
  channel 1, in run 102 NO.
- 749: B 737 (1196445184, 24, 2) B-only distinct,
  channel 2, in run 102 NO.
- 750: B 738 (1196445696, 24, 0) B-only distinct,
  channel 0, in run 102 NO — terminal (rank 750
  is the last of 751 B-offset ranks).

Internal gap sequence: [712, 26624, 14848, 33280,
512, 512, 512] — equals the AES-NUM-231 measured
sequence exactly (printed test TRUE).

## (iii) The closing-run full comparison in full

Side by side, position by position (first through
eighth act): the position table printed in the
section states, for each position, A rank/index/
act/class/channel/run-102 and B rank/index/act/
class/channel/run-102. The only position where
the two sides share a class is position 4, and
only on the A side is any act in run 102: A
position 4 (rank 744) is shared single-positioned
and in run 102; every other act on both sides is
side-only distinct and not in run 102.

- Class composition: A run {A-only distinct: 7,
  shared single-positioned: 1} summing to 8
  exactly; B run {B-only distinct: 8} summing to
  8 exactly. The compositions are NOT identical.
- Run-102 membership: A run 1 in / 7 not in (the
  sole member is position 4, rank 744, run 102's
  last act); B run 0 in / 8 not in. The counts
  are NOT identical.
- Gap sequences: A [512, 512, 512, 512, 512, 512,
  512] — uniform; B [712, 26624, 14848, 33280,
  512, 512, 512]. The sequences are NOT
  identical; the two runs agree only in their
  final three gaps (+512 each, printed test
  TRUE).
- Terminal status: both runs are terminal — each
  run's last act is the last rank of its whole
  offset order (A rank 748 of 749; B rank 750 of
  751), with no outgoing gap on either side.
- Contract tests: each run's printed gap sequence
  equals its AES-NUM-231 measured sequence —
  TRUE on both sides; each act's stated
  rank/index/act equals its AES-NUM-232..239
  per-act statement — TRUE for all sixteen acts.

This reproduces the AES-NUM-231 closing-run
comparison from the fully walked per-act sequence
(AES-NUM-232..239) with no discrepancy.

Mechanisms NOT PROVEN; any offset, prefix or
position law NOT PROVEN; run 102's meaning NOT
PROVEN.
