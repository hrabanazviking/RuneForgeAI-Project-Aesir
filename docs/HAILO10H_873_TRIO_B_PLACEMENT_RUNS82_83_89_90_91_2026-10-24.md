# The 873-prefix trio's three B acts are consecutive in B-offset order (ranks 724–726 of 751, in the order 1, 0, 27, at exactly +512 steps), they are the only 873-prefix acts in either context, and runs 82, 83, 89, 90 and 91 are each a singleton and therefore one contiguous B block (AES-NUM-176)

Slice 4.176, worked under `docs/TASK_CONTRACT_4.176.md`
(contract published in the 4.175 closing commit @
80d42201). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output, read in full.

## Run and closing record

hef176.py is the verified hef175 base plus arms176 —
sha256
`2da4745e0bc16487d35f13b450a37f973c96350df8b93dc32c04e4a1757b99c1`
(1,112,866 B) on both the VM and the device; arms176
sha256
`e65b0de50cc8dc1d5e1c4830540ac73e6f3e11b44cafd0435ab9ee6ecf447440`
(13,157 B), gzip sha256
`780e5a5f287f8cfcc20da84e6b1e42262801e567661c5bd8f1a51df546f02038`.
Crossing: ten sha-gated 373 B gz parts (last 313 B),
all ten verified on-device first try; assembled arms
and hef176 shas == VM on-device, py_compile OK.
Before launching, `tmux ls` and `ps` on Mimir were
checked for an existing hef176/h176 child (none —
only the old h142/h147 sessions): exactly ONE
bounded host-side child was launched in detached
tmux (session h176, 2026-10-30 01:46:40 EDT) with
the contract corpus argv (glob order, MiniLM last),
unbuffered (`python3 -u`), and it finished with
DONE176 as its last line, exit marker 0
(hef176.exit), err empty (0 B). Output hef176.out:
49,229 lines / 9,297,892 B, sha256
`5177a19a8c7f5041a1752290a639c529b86446be6fac965bdca667371c69449c`.
Prefix check: its first 49,023 lines against
hef175r.out differ in exactly ONE line (42,872,
frozenset element order only — same sorted content,
the AES-NUM-150 variance); all other 49,022 lines
byte-identical. Section 176: 206 lines / 28,406 B,
sha256
`f5cbc1d4b83a618a93221b142cd37325cd10c2dd85f38fec647c83f52c8324b2`,
read in full on-device. Controls EXACT (context
counts 749 / 751, shared 689, A-only 60, B-only 62,
union 811; both-side keys 31; channel census
{(0, 1): 12, (1, 0): 6, (1, 2): 7, (2, 0): 6}; run
table 103 secondary runs; runs 82/83/89 lengths
[1, 1, 1], shifts [+49, +24, −277], first A
positions [635, 636, 665]; runs 90/91 lengths
[1, 1] — measured here for the first time — shifts
[+1, −255], first A positions [666, 667], first B
positions [667, 412]; 417-family count 16;
non-417 count 12; trio A/B acts reproduced exactly;
head size sequences reproduced exactly on both
sides). Raw output kept on the Pi at ~/aesir-build/
(hef176.out, hef176.py, arms176.py, section176.txt,
hef176.exit, run176.sh, gz176/); local lineage in
~/workspace/.verify-tmp/aesir176.

## (i) The 873-prefix trio's B-side placement in full

Definitions (stated in the output, followed
exactly): the head is positions 0–27, paired by
position index; the trio is head positions 0, 1
and 27 (AES-NUM-175's three non-identity non-417
positions); an 873-prefix offset lies in
[873000000, 874000000); occurrences are all indices
of the exact act tuple in a context list; B-offset
order is context B's acts sorted by offset.

Each of the three in full:

- Position 0: A (778835968, 24, 1) / B
  (873199104, 24, 1), diff +94,363,136. Its A act
  occurs only at A index 0 and nowhere in B
  (A-only distinct); its B act occurs only at B
  index 0 and nowhere in A (B-only distinct).
- Position 1: A (778836480, 24, 0) / B
  (873198592, 24, 0), diff +94,362,112. Same
  occurrence pattern: A act only at A index 1,
  B act only at B index 1, neither act in the
  other context.
- Position 27: A (779029008, 14864, 0) / B
  (873199616, 24, 2), diff +94,170,608. Its B act
  occurs only at B index 27 and nowhere in A
  (B-only distinct); its A act is a shared
  single-positioned act — it occurs at A index 27
  and at B index 29, as run 1's +2 act. So at
  position 27 the B-side slot carries a B-only
  24 B act while the position's own A act lives
  two B slots later, inside run 1.

B-index neighbourhoods: at B indices 0–1 the trio
acts sit immediately before run 0's identity acts
at B 2–4 and the B-only 1,196-prefix acts at B 5–6
(B 5 = (1196182016, 24, 2), B 6 = (1196182528,
24, 0)). At B index 27 the trio act sits after the
B-only acts at B 22–26 (1,196-prefix at 22, 23, 25,
26 and the identity act at 24) and immediately
before run 1's +2 acts at B 28–32, the first of
which (B 28) is position 26's A act and the second
(B 29) position 27's own A act.

B-offset order — the headline: the three B acts
are CONSECUTIVE in B-offset order, at ranks 724,
725 and 726 of 751, in the order position 1
(873,198,592), position 0 (873,199,104), position
27 (873,199,616) — consecutive gaps exactly
[512, 512], span 1,024, against the three's
A-offset order [0, 1, 27] with gaps [512,
192,528] and span 193,040. Their B-offset-order
neighbours are also B-only acts: below, rank 723
(B index 749, (800053760, 24, 2)), rank 722
(B index 747, (791781888, 24, 0)) and rank 721
(B index 748, (791781376, 24, 1)); above, rank
727 (B index 750, (973679616, 24, 0)), then the
1,196-prefix head acts at ranks 728–729
(B indices 5, 6). The three's A acts rank 40, 41
and 64 of 749 in A-offset order.

Pairwise: (0, 1) is the trio's only reversal —
A gap +512, B gap −512. (0, 27): A gap +193,040,
B gap +512, not reversed. (1, 27): A gap
+192,528, B gap +1,024, not reversed. B offsets
are NOT strictly increasing in position order.

873 census: head B positions with an 873-prefix
B offset are exactly [0, 1, 27]; no head position
carries an 873-prefix A offset. Whole-context:
context B contains exactly THREE 873-prefix acts
— the trio's, at B indices [0, 1, 27] — and
context A contains ZERO. No other head B act,
and no other act in either context, carries an
873-prefix offset.

The wider B-side pattern: over the whole head in
A-offset order there are 107 inversions against
B-offset order; 41 of them involve a trio
position (position 0 in 13, position 1 in 13,
position 27 in 16, with the (0, 1) pair counted
in both of the first two). The trio's reversal is
therefore not an isolated oddity in kind — the
head's B-offset order departs from its A-offset
order pervasively — but the trio is the only
873-prefix population, and its three acts'
mutual B-offset adjacency (consecutive ranks,
equal 512 steps) is measured here for the first
time. Any law is NOT PROVEN; the 873-prefix
group's meaning remains NOT PROVEN.

## (ii) Runs 82, 83 and 89 in full

All three are singletons, so each is trivially
one contiguous B block (length 1).

Run 82: shift +49, act (790391296, 32784, 1) at
A 635 / B 684. B neighbourhood (681–687): run
86's +26 acts at 681–683, its own act, then run
102's +2 acts at 685–687. A neighbourhood
(632–638): run 81's last three acts at 632–634,
its own act, run 83's singleton at 636, then run
84's first two acts at 637–638.

Run 83: shift +24, act (790424576, 26128, 1) at
A 636 / B 660. B neighbourhood (657–663): run
81's last three acts at 657–659, its own act,
then run 88's first three acts at 661–663. A
neighbourhood (633–639): run 81's acts at
633–634, run 82's singleton at 635, its own act,
then run 84's first three acts at 637–639.

Run 89: shift −277, act (790974976, 32784, 2) at
A 665 / B 388 — the only channel-2 act in its
A neighbourhood. B neighbourhood (385–391): run
50's −29 acts at 385–387, its own act, run 51's
−30 act at 389, then two B-only channel-1 acts
at 390–391 ((781962752, 1552, 1) and (781964304,
14864, 1)). A neighbourhood (662–668): run 88's
last three acts at 662–664, its own act, then
run 90's act at 666, run 91's act at 667 and run
92's first act at 668.

## (iii) Runs 90 and 91 in full

Both are singletons, each trivially one
contiguous B block; their lengths (1 each) are
measured here for the first time.

Run 90: shift +1, act (791008256, 26128, 0) at
A 666 / B 667 — channel 0, unlike its channel-1
and channel-2 A neighbours. B neighbourhood
(664–670): run 88's last two acts at 664–665,
run 58's +234 act at 666, its own act, run 56's
+240 act at 668, then run 92's +1 pair at
669–670. A neighbourhood (663–669): run 88's
last two acts, run 89's singleton at 665, its
own act, run 91's act at 667, then run 92's pair
at 668–669.

Run 91: shift −255, act (791034880, 26128, 2) at
A 667 / B 412. B neighbourhood (409–415): run
22's +111 acts at 409–410, run 25's +107 act at
411, its own act, then run 38's +33 acts at
413–415. A neighbourhood (664–670): run 88's
last act at 664, runs 89/90 at 665–666, its own
act, run 92's pair at 668–669, and the A-only
distinct act at A 670.

The shared-act order from run 89's first act
through run 92's first act is simply A 665, 666,
667, 668 in run order 89, 90, 91, 92 — four
consecutive A positions with shifts −277, +1,
−255, +1. Run table 82–92 recomputed: run 92 is
a +1 pair at A 668–669 / B 669–670 (its first
act already seen above; the pair is given in
full by the next slice).

## Next

Slice 4.177 — the trio's B-offset-order flank
acts in full (the B-only acts at B-offset ranks
721–723 and 727 — B indices 748, 747, 749, 750 —
their classes, A-side counterparts and
neighbourhoods); runs 92 and 93 in full; runs 94
and 95 in full. Host/artifact analysis only.
