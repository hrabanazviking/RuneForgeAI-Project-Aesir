# All four 873-prefix trio flank acts are B-only distinct with no A-side counterpart (the B tail's last four acts, at B-offset ranks 721, 722, 723 and 727), and runs 92 (+1 pair), 93 (−391 singleton), 94 (+1 singleton) and 95 (+2 singleton) are each one contiguous B block (AES-NUM-177)

Slice 4.177, worked under `docs/TASK_CONTRACT_4.177.md`
(contract published in the 4.176 closing commit @
9c0d8803). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output, read in full.

## Run and closing record

hef177.py is the verified hef176 base plus arms177 —
sha256
`f92d5efa36b9b0b0f7425b08331367a3792f6d79944427e3da2657f0e4db4c8c`
(1,124,113 B) on both the VM and the device; arms177
sha256
`7cfbbd9b2610087d479fe4f4a64b2fbe09e47c6b7bf83e96566b9e62f67a33d3`
(11,247 B), gzip sha256
`f641315be608085fd079c77e366dca23431859f89da94aafdb0defbe36f573a8`.
Crossing: nine sha-gated 373 B gz parts (last 352 B),
all nine verified on-device first try; assembled arms
and hef177 shas == VM on-device, py_compile OK.
Before launching, `tmux ls` and `ps` on Mimir were
checked for an existing hef177/h177 child (none —
only the old h142/h147 sessions): exactly ONE
bounded host-side child was launched in detached
tmux (session h177, 2026-10-30 02:15:44 EDT) with
the contract corpus argv (glob order, MiniLM last),
unbuffered (`python3 -u`), and it finished with
DONE177 as its last line, exit marker 0
(hef177.exit), err empty (0 B). Output hef177.out:
49,428 lines / 9,322,046 B, sha256
`e490194328f946b919d39785d95b41078ce80b30c9c0f8882416d477df9b50b5`.
Prefix check: its first 49,229 lines against
hef176.out differ in exactly ONE line (41,611,
frozenset element order only — same sorted content,
the AES-NUM-150 variance); all other 49,228 lines
byte-identical. Section 177: 199 lines / 24,154 B,
sha256
`91eb77ad03fb9c5386da09553f78ba46c8788b30b1dd0b556188a08d7e841c98`,
read in full on-device. Controls EXACT (context
counts 749 / 751, shared 689, A-only 60, B-only 62,
union 811; both-side keys 31; channel census
{(0, 1): 12, (1, 0): 6, (1, 2): 7, (2, 0): 6}; run
table 103 secondary runs; run 92 length 2, shift
+1, A 668–669 / B 669–670 as expected; flank acts
at B indices 747/748/749/750 and their ranks
[722, 721, 723, 727] reproduced exactly; trio ranks
[725, 724, 726]; head size sequences reproduced
exactly on both sides). Runs 93/94/95 lengths,
shifts and positions were measured here for the
first time (no prior expectation was stated).
Raw output kept on the Pi at ~/aesir-build/
(hef177.out, hef177.py, arms177.py, section177.txt,
hef177.exit, run177.sh, gz177/); local lineage in
~/workspace/.verify-tmp/aesir177.

## (i) The trio's B-offset-order flank acts in full

Definitions (stated in the output, followed
exactly): B-offset order is context B's acts sorted
by offset, ranks 0-based of 751; the trio is head
positions 0, 1 and 27 at ranks 725, 724, 726; a
flank act is a B act at rank 721, 722 or 723 below
the trio, or rank 727 above it; occurrences are all
indices of the exact act tuple in a context list;
context B's tail is B indices 745–750.

Each flank act in full — all four are B-only
distinct, each occurs exactly once in B and
nowhere in A, so NONE has an A-side counterpart
act:

- Rank 721: B index 748, act (791781376, 24, 1),
  channel 1.
- Rank 722: B index 747, act (791781888, 24, 0),
  channel 0.
- Rank 723: B index 749, act (800053760, 24, 2),
  channel 2.
- Rank 727: B index 750, act (973679616, 24, 0),
  channel 0 — the last act of context B.

B-index neighbourhoods: the four flank acts are
exactly the last four acts of context B, at B
indices 747–750 in the order 747 (rank 722), 748
(rank 721), 749 (rank 723), 750 (rank 727) — the
747/748 pair is reversed between B-index order and
B-offset order. They follow the tail's two shared
acts: B 745 (755688960, 24, 2), run 102 at +2,
A 743, offset rank 33, and B 746 (791778816, 24, 0),
run 102 at +2, A 744, offset rank 720 — the last
shared act in B-offset order before the flank
window opens.

The full B-offset-order window, ranks 718–732:
ranks 718–720 are shared run-102 acts at +2 (B
indices 733, 734, 746; A positions 731, 732, 744);
from rank 721 onward EVERY act in the window is
B-only distinct — the four flanks (721–723, 727),
the trio (724–726), and the acts above at ranks
728–732 (B indices 5, 6, 8, 10, 11: the
1,196-prefix head acts (1196182016, 24, 2) and
(1196182528, 24, 0), then (1196183040, 32784, 1),
(1196216320, 7800, 2) and (1196224120, 344, 2)).

Offset gaps across the window: 721→722 +512 (the
same step as inside the trio), 722→723 +8,271,872,
723→724 (trio position 1) +73,144,832, trio
724→725 +512 and 725→726 +512, 726→727
+100,480,000, 727→728 +222,502,400. The flanks do
not extend the trio's 512-step ladder: only the
721→722 step is 512, and the steps out of the
window on both sides are three to five orders of
magnitude larger. Any law is NOT PROVEN; the flank
acts' meaning remains NOT PROVEN.

## (ii) Runs 92 and 93 in full

Run 92: a +1 pair, A 668–669 / B 669–670, one
contiguous B block (B gaps [1]). Acts:
(791061504, 32784, 2) at A 668 / B 669 and
(791094784, 26128, 1) at A 669 / B 670. B
neighbourhood (666–673): run 58's +234 act at 666,
run 90's act at 667, run 56's +240 act at 668, its
own pair, then a B-only act at 671, run 30's +315
act at 672 and run 94's act at 673. A neighbourhood
(665–672): runs 89/90/91 at 665–667, its own pair,
the A-only distinct act at A 670, run 93's act at
671, run 94's act at 672.

Run 93: a −391 singleton, therefore trivially one
contiguous B block — act (791154688, 18448, 2) at
A 671 / B 280, the only 18,448-size act in either
neighbourhood. Its length, shift and positions are
measured here for the first time. B neighbourhood
(277–283): run 18's +2 acts at 277–279, its own
act, then run 71's −238 acts at 281–283 — all
channel 2. A neighbourhood (668–674): run 92's
pair, the A-only act at 670, its own act, run 94's
act at 672, an A-only act at 673, run 95's act
at 674.

## (iii) Runs 94 and 95 in full

Both are singletons, each trivially one contiguous
B block; their lengths, shifts and positions are
measured here for the first time.

Run 94: shift +1, act (791173632, 32784, 0) at
A 672 / B 673 — channel 0. B neighbourhood
(670–676): run 92's second act at 670, a B-only
act at 671, run 30's +315 act at 672, its own act,
a B-only 1,196-prefix act at 674
(1196410880, 32784, 2), run 101's −7 act at 675,
run 95's act at 676. A neighbourhood (669–675):
run 92's second act, the A-only acts at 670 and
673 and 675, run 93's act at 671, its own act,
run 95's act at 674.

Run 95: shift +2, act (791240192, 26128, 1) at
A 674 / B 676. B neighbourhood (673–679): run
94's act at 673, the B-only act at 674, run 101's
act at 675, its own act, run 45's +275 act at 677,
then run 86's +26 acts at 678–679. A neighbourhood
(671–677): run 93's act, run 94's act, the A-only
act at 673, its own act, the A-only act at 675,
run 96's −283 act at 676 and run 97's −300 act
at 677.

The shared-act order from run 92's first act
through run 96's first act is A 668, 669, 671,
672, 674, 676 in run order 92, 92, 93, 94, 95, 96
with shifts +1, +1, −391, +1, +2, −283 — the
shared order skips exactly the A-only distinct
acts at A 670, 673 and 675. Run table 92–96
recomputed: run 96 is a −283 singleton at A 676 /
B 393 (its first act already seen above; the run
is given in full by the next slice).

## Next

Slice 4.178 — the B-offset-order window's upper
acts at ranks 728–732 in full (B indices 5, 6, 8,
10, 11) and its lower shared boundary at ranks
718–720 in full; runs 96 and 97 in full; runs 98
and 99 in full. Host/artifact analysis only.
