# All four B-offset-order acts above the window are B-only distinct with no A-side counterpart, runs 100 and 101 are singletons, and run 102 — the final secondary run — splits into two contiguous B blocks around four B-only acts (AES-NUM-179)

Slice 4.179, worked under `docs/TASK_CONTRACT_4.179.md`
(contract published in the 4.178 closing commit @
ad34f4f4). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output, read in full.

## Run and closing record

hef179.py is the verified hef178 base plus arms179 —
sha256
`20f1b3a08277c2467a3f63e0a08d1c17ae158aa5c06f28d00514245d655ae400`
(1,145,804 B) on both the VM and the device; arms179
sha256
`c3dda175cba972b89014efcd04668f04fd5849a8153fdac9516488c9f843bed0`
(10,465 B), gzip sha256
`9bb4af64504a9bd18e8815977d9d9bea1ad49a188fc0051cf7db577f214e80d5`.
Crossing: nine sha-gated 373 B gz parts (last 35 B),
all nine verified on-device first try; assembled arms
and hef179 shas == VM on-device, py_compile OK.
Before launching, `tmux ls` and `ps` on Mimir were
checked for an existing hef179/h179 child (none —
only the old h142/h147 sessions): exactly ONE
bounded host-side child was launched in detached
tmux (session h179, 2026-10-30 03:00:24 EDT) with
the contract corpus argv (glob order, MiniLM last),
unbuffered (`python3 -u`), and it finished with
DONE179 as its last line, exit marker 0
(hef179.exit), err empty (0 B). Output hef179.out:
50,166 lines / 9,405,029 B, sha256
`07547f020b6fd1a50d3fb86c7ecda79403953d26d54482aacffff141842a22f3`.
Prefix check: its first 49,744 lines against
hef178.out differ in exactly ONE line (41,611,
frozenset element order only — same sorted content,
the AES-NUM-150 variance); all other 49,743 lines
byte-identical. Section 179: 422 lines / 44,144 B,
sha256
`01c118b05f8ca695c87f71247be4a5bc2425c9b341e0669356e2befe4daf7bc4`,
read in full on-device (a sha-identical local copy
was decoded and read in full as well). Controls
EXACT (context counts 749 / 751, shared 689, A-only
60, B-only 62, union 811; both-side keys 31; channel
census {(0, 1): 12, (1, 0): 6, (1, 2): 7, (2, 0): 6};
run table 103 secondary runs; run 100 length 1,
shift −452, A 680 / B 228, act (791419904, 32784, 2);
run 101 length 1, shift −7, A 682 / B 675, act
(3446784, 24, 2); run 102 length 58, shift +2,
A 683–744 / B 685–746 — all as expected; the
above-window acts at B indices 13, 14, 15, 16 and
their ranks [733, 734, 735, 736] reproduced exactly;
window-upper and boundary ranks reproduced exactly;
head size sequences reproduced exactly on both
sides). Raw output kept on the Pi at ~/aesir-build/
(hef179.out, hef179.py, arms179.py, section179.txt,
hef179.exit, run179.sh, gz179/); local lineage in
~/workspace/.verify-tmp/aesir179.

## (i) The acts above the window in full

Definitions (stated in the output, followed
exactly): B-offset order is context B's acts sorted
by offset, ranks 0-based of 751; the window is
ranks 718–732; the acts above the window are ranks
733–736; occurrences are all indices of the exact
act tuple in a context list.

Each above-window act in full — all four are
B-only distinct, each occurs exactly once in B and
nowhere in A, so NONE has an A-side counterpart
act, and all four are channel 1:

- Rank 733: B index 13, act (1196224512, 32768, 1).
- Rank 734: B index 14, act (1196257280, 14416, 1).
- Rank 735: B index 15, act (1196271696, 376, 1).
- Rank 736: B index 16, act (1196272072, 24, 1).

The four are consecutive in BOTH orders: B indices
13, 14, 15, 16 and B-offset ranks 733, 734, 735,
736, with no shared or other act interleaved in
either order. In B-index order they follow the
shared run-0 act at B 12 (offset rank 43) and are
followed by a further B-only act at B 17 (offset
rank 737), the shared run-0 act at B 18 (rank 44),
and B-only acts at B 19, 20 (ranks 738, 739).

Offset gaps above the window: 732→733 is +392,
then 733→734 is +32768, 734→735 is +14416,
735→736 is +376 and 736→737 is +24 — each of those
four steps exactly equals the size of the act at
the lower rank, so ranks 733–737 form one
contiguous offset chain (each act begins exactly
where its predecessor ends: 1196224512 + 32768 =
1196257280; + 14416 = 1196271696; + 376 =
1196272072; + 24 = 1196272096, the rank-737 act).
The chain does NOT extend below rank 733 (the
732→733 gap of 392 exceeds rank 732's size 344 by
48).

The extended range ranks 733–742 is B-only
throughout: rank 737 (B 17, (1196272096, 32728,
1)), rank 738 (B 19, (1196304896, 7712, 0)), rank
739 (B 20, (1196312608, 328, 0)), rank 740 (B 22,
(1196313088, 24848, 1)), rank 741 (B 23,
(1196337936, 264, 1)) and rank 742 (B 25,
(1196338688, 30008, 2)). Together with AES-NUM-178,
every act from rank 721 to rank 742 in B-offset
order is B-only distinct.

## (ii) Runs 100 and 101 in full

Run 100 is a −452 singleton, therefore one
contiguous B block: act (791419904, 32784, 2),
channel 2, at A 680 / B 228. B neighbourhood
(225–231): run 10's −4 act at B 225, run 12's −5
acts at B 226–227, the run-100 act at B 228, a
B-only act (1196369408, 26128, 2) at B 229, and
run 78's −391 acts at B 230–231. A neighbourhood
(677–683): runs 97, 98, 99 at A 677–679, run 100
at A 680, the A-only act (791452688, 26128, 2) at
A 681, run 101 at A 682 and run 102's first act
at A 683.

Run 101 is a −7 singleton, therefore one
contiguous B block: act (3446784, 24, 2), channel
2, at A 682 / B 675 — a low-offset act among
791-prefix neighbours. B neighbourhood (672–678):
run 30's +315 act at B 672, run 94's +1 act at
B 673, the B-only act (1196410880, 32784, 2) at
B 674, run 101 at B 675, run 95's +2 act at
B 676, run 45's +275 act at B 677 and run 86's
+26 act at B 678. A neighbourhood (679–685):
runs 99, 100 at A 679–680, the A-only act at
A 681, run 101 at A 682, and run 102's first
three acts at A 683–685.

## (iii) Run 102 in full — the final secondary run

Run 102 has 58 acts, all at shift +2, A extent
683–744, B extent 685–746 — but it is NOT one
contiguous B block. Its B positions in A order
are 685–734 followed by 739–746: exactly one B
gap (a step of 5 between B 734 and B 739, all
other 56 steps exactly 1), so run 102 is TWO
contiguous B blocks:

- Block 1: 50 acts, A 683–732 / B 685–734. It
  opens with the 791-prefix channel-1 acts at
  A 683–692, passes through the low-offset acts
  at A 693–724 (offsets 3415040, 262144–268904
  and the small 791773184–791774864 cluster), and
  closes with the 24 B acts at A 725–732 ending
  in the window-boundary acts (791776256, 24, 2)
  at A 731 / B 733 and (791776768, 24, 0) at
  A 732 / B 734.
- The interruption, B 735–738: four B-only
  distinct 24 B acts — (1196444160, 24, 0),
  (1196444672, 24, 1), (1196445184, 24, 2),
  (1196445696, 24, 0) — at consecutive +512
  offset steps, channels cycling 0, 1, 2, 0.
- Block 2: 8 acts, A 737–744 / B 739–746:
  (768609280, 24, 0), (768609792, 24, 1),
  (768610304, 24, 2), (768610816, 24, 0),
  (755602432, 24, 0), (755680256, 24, 1),
  (755688960, 24, 2) and (791778816, 24, 0) —
  the last of these is the last shared act in
  B-offset order (rank 720, AES-NUM-177/178).

On the A side the two blocks are separated by
four A-only distinct 24 B acts at A 733–736:
(791776792, 24, 0), (791777280, 24, 1),
(791777792, 24, 2), (791778304, 24, 0), at offset
steps +488, +512, +512 from the first. The
interruption is therefore four acts wide on both
sides — four A-only acts in A where B carries
four B-only acts in B — but the two sets share no
exact act. After run 102's last act, A continues
with A-only acts at A 745–747 and B with the
B-only tail at B 747–750 (AES-NUM-177).

The shared-act order from run 100's first act
through run 102's last act is A 680 (run 100),
A 682 (run 101, skipping exactly the A-only act
at A 681), then run 102's A 683–732 and A
737–744 in order. Run 102 is the final secondary
run (index 102 of 103): with this slice, every
secondary run 0–102 has now been given in full in
this line.

## Grades

All statements above are measured from the
complete populations. Mechanisms NOT PROVEN; any
offset, prefix or position law NOT PROVEN; the
heads' scaffold mechanism NOT PROVEN; the
above-window acts' meaning NOT PROVEN; the
run-102 interruption's meaning NOT PROVEN.

## Next

Slice 4.180 — the B-offset-order acts at ranks
737–742 in full (B indices 17, 19, 20, 22, 23,
25); the four B-only interrupter acts at B
735–738 in full (including their B-offset
ranks); the four A-only acts at A 733–736 in
full. Host/artifact analysis only — no physical
child.
