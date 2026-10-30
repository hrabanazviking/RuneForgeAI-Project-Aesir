# All five B-offset-order window upper acts are B-only distinct with no A-side counterpart, its lower boundary is three shared run-102 acts at +2, and runs 96 (−283), 97 (−300), 98 (−455) and 99 (−278) are each a singleton contiguous B block (AES-NUM-178)

Slice 4.178, worked under `docs/TASK_CONTRACT_4.178.md`
(contract published in the 4.177 closing commit @
fdccf47e). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output, read in full.

## Run and closing record

hef178.py is the verified hef177 base plus arms178 —
sha256
`450419b746fa85fbfb587cf706fda3eded4836288467ce808b9408fb4c677ab9`
(1,135,339 B) on both the VM and the device; arms178
sha256
`4c3879e34376f87cbe4297001be8488f75da8a27633ae1bd882b13c2859bd44f`
(11,226 B), gzip sha256
`19addc3fc5247a7398ef88f6f5f23e67d0731377575b1a6b8efa2347bef22648`.
Crossing: nine sha-gated 373 B gz parts (last 205 B),
all nine verified on-device first try; assembled arms
and hef178 shas == VM on-device, py_compile OK.
Before launching, `tmux ls` and `ps` on Mimir were
checked for an existing hef178/h178 child (none —
only the old h142/h147 sessions): exactly ONE
bounded host-side child was launched in detached
tmux (session h178, 2026-10-30 02:46:41 EDT) with
the contract corpus argv (glob order, MiniLM last),
unbuffered (`python3 -u`), and it finished with
DONE178 as its last line, exit marker 0
(hef178.exit), err empty (0 B). Output hef178.out:
49,744 lines / 9,360,885 B, sha256
`59a09ae6b03564e0fb6b3868d0a9ca05a077250d5e75fbad430518269bd035e2`.
Prefix check: its first 49,428 lines against
hef177.out differ in exactly TWO lines (41,611 and
42,872, both frozenset element order only — same
sorted content, the AES-NUM-150 variance); all
other 49,426 lines byte-identical. Section 178:
316 lines / 38,839 B, sha256
`67636927f666d431595a2ed52380fa6336f83e9345099887cda4045097356f8b`,
read in full on-device. Controls EXACT (context
counts 749 / 751, shared 689, A-only 60, B-only 62,
union 811; both-side keys 31; channel census
{(0, 1): 12, (1, 0): 6, (1, 2): 7, (2, 0): 6}; run
table 103 secondary runs; run 96 length 1, shift
−283, A 676 / B 393 and run 97 length 1, shift
−300, A 677 / B 377 as expected; the window acts
at B indices 5, 6, 8, 10, 11 and their ranks
[728, 729, 730, 731, 732] reproduced exactly; the
boundary acts at B indices 733, 734, 746 at ranks
[718, 719, 720]; trio/flank ranks reproduced
exactly; head size sequences reproduced exactly
on both sides). Runs 98/99 lengths, shifts and
positions were measured here for the first time
(no prior expectation was stated). Raw output kept
on the Pi at ~/aesir-build/ (hef178.out, hef178.py,
arms178.py, section178.txt, hef178.exit, run178.sh,
gz178/); local lineage in
~/workspace/.verify-tmp/aesir178.

## (i) The window's upper acts and lower shared boundary in full

Definitions (stated in the output, followed
exactly): B-offset order is context B's acts sorted
by offset, ranks 0-based of 751; the window is
ranks 718–732; its upper acts are ranks 728–732;
its lower shared boundary is ranks 718–720;
occurrences are all indices of the exact act tuple
in a context list.

Each upper act in full — all five are B-only
distinct, each occurs exactly once in B and
nowhere in A, so NONE has an A-side counterpart
act:

- Rank 728: B index 5, act (1196182016, 24, 2),
  channel 2.
- Rank 729: B index 6, act (1196182528, 24, 0),
  channel 0.
- Rank 730: B index 8, act (1196183040, 32784, 1),
  channel 1.
- Rank 731: B index 10, act (1196216320, 7800, 2),
  channel 2.
- Rank 732: B index 11, act (1196224120, 344, 2),
  channel 2.

B-index neighbourhoods: the five upper acts sit
in context B's head at B indices 5, 6, 8, 10, 11,
interleaved with the shared run-0 acts at B 2, 3,
4, 7, 9, 12 (each at its A position, offset ranks
38–43) and followed in B-index order by further
B-only acts at B 13, 14, 15, 16 (offset ranks
733–736). In B-offset order they follow rank 727
(B 750, the last act of context B) directly.

Each lower boundary act in full — all three are
shared single-positioned acts of run 102 at
shift +2, each with an A-side counterpart:

- Rank 718: B index 733, act (791776256, 24, 2),
  at A 731.
- Rank 719: B index 734, act (791776768, 24, 0),
  at A 732.
- Rank 720: B index 746, act (791778816, 24, 0),
  at A 744 — the last shared act in B-offset
  order (AES-NUM-177).

B-index neighbourhoods: ranks 718/719 are
consecutive in B (733/734), inside a run-102
stretch (B 728–734, with the one low-offset
run-102 act (3418112, 24, 0) at B 730, offset
rank 28); rank 720's act at B 746 follows the
run-102 acts at B 741–745 and is followed
immediately by the B-only tail acts at B
747–750. The boundary acts' A positions are
731, 732 and 744 — the first two consecutive,
the third after a twelve-position A gap inside
run 102.

The full window, ranks 718–732: ranks 718–720
are the shared boundary above; from rank 721
onward EVERY act in the window is B-only
distinct — the flanks (721–723), the trio
(724–726), rank 727, and the five upper acts
(728–732). The extended window ranks 715–735
shows ranks 715–717 are also run-102 acts at
+2, and ranks 733–735 (B 13, 14, 15) are
further B-only acts — the B-only stretch in
B-offset order continues above the window.

Offset gaps across the window (rank → next):
717→718 +512, 718→719 +512, 719→720 +2,048,
720→721 +2,560, 721→722 +512, 722→723
+8,271,872, 723→724 +73,144,832, 724→725 +512,
725→726 +512, 726→727 +100,480,000, 727→728
+222,502,400, 728→729 +512, 729→730 +512,
730→731 +33,280, 731→732 +7,800, 732→733 +392.
The two 512 steps inside the upper acts
(728→729, 729→730) match the trio's step, but
the steps above them (730→731, 731→732) do
not. Any law is NOT PROVEN; the upper acts'
meaning remains NOT PROVEN.

## (ii) Runs 96 and 97 in full

Both are singletons, therefore trivially one
contiguous B block each.

Run 96: shift −283, act (791300096, 26128, 2)
at A 676 / B 393 — channel 2. B neighbourhood
(390–396): three B-only acts at 390–392, its
own act, run 7's +174 acts at 394–395 and a
B-only act at 396. A neighbourhood (673–679):
the A-only acts at 673 and 675, run 95's act
at 674, its own act, and runs 97/98/99 at
677–679.

Run 97: shift −300, act (791326720, 32784, 2)
at A 677 / B 377 — channel 2. B neighbourhood
(374–380): run 33's +2 act at 374, a B-only
act at 375, run 54's −49 act at 376, its own
act, then run 49's −31 acts at 378–380. A
neighbourhood (674–680): run 95's act, the
A-only act at 675, runs 96/98/99 and run
100's act at 680.

## (iii) Runs 98 and 99 in full

Both are singletons, each trivially one
contiguous B block; their lengths, shifts and
positions are measured here for the first time.

Run 98: shift −455, act (791360000, 26128, 2)
at A 678 / B 223 — channel 2. B neighbourhood
(220–226): run 59's −213 act at 220, run 9's
−5 acts at 221–222, its own act, run 10's −4
acts at 224–225 and run 12's −5 act at 226. A
neighbourhood (675–681): the A-only act at
675, runs 96/97/99, run 100's act at 680 and
the A-only act at 681 (791452688, 26128, 2).

Run 99: shift −278, act (791386624, 32784, 2)
at A 679 / B 401 — channel 2. B neighbourhood
(398–404): run 55's −28 acts at 398–399, run
57's −29 act at 400, its own act, run 11's
+172 act at 402 and run 13's +170 acts at
403–404. A neighbourhood (676–682): runs
96/97/98, run 100's act at 680, the A-only
act at 681 and run 101's −7 act at A 682
(3446784, 24, 2), B 675.

The shared-act order from run 96's first act
through run 100's first act is A 676, 677,
678, 679, 680 in run order 96, 97, 98, 99,
100 with shifts −283, −300, −455, −278, −452
— five consecutive A positions, no A-only act
skipped in this stretch. Run table 96–100
recomputed: run 100 is a −452 singleton at
A 680 / B 228, act (791419904, 32784, 2) (its
first act already seen above; the run is
given in full by the next slice).

## Next

Slice 4.179 — the B-offset-order acts above
the window at ranks 733–736 in full (B
indices 13, 14, 15, 16); runs 100 and 101 in
full; run 102 in full. Host/artifact analysis
only.
