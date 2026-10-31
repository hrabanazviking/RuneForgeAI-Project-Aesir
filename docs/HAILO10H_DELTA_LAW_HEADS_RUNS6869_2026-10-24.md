# The 31 correspondence pairs' position-delta law, recomputed directly, confirms AES-NUM-168's derived census exactly (preceding run shift 19 of 31, following 17, at least one neighbour 21, the same 10 exceptions at the same positions and deltas) — and delta is a function of nothing tested (channel pair, size, A position band at either width, and the (channel pair, size) joint all NOT A FUNCTION); the two +174 exceptions do equal run 7's +174 shift two runs past their following run, while the other eight exceptions equal no neighbouring run shift within three runs either side; the two unmatched heads, aligned by position over 0–27, agree in size at 25 of 28 positions and in channel at 26, differ in size only at position 13 (32,728 vs 32,768, +40) and at the B-only tail positions 26–27, share exactly the nine shared 24 B acts, and their offset differences at size-agreeing positions take 13 distinct values (not constant); runs 68 (+0 pair in place) and 69 (+2 block of 8) are each one contiguous B block (AES-NUM-169)

Slice 4.169, worked under `docs/TASK_CONTRACT_4.169.md`
(contract published in the 4.168 closing commit @
aa660e04). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output, read in full.

## Run and closing record

hef169.py (hef168.py verbatim as base plus the new
arms169) sha256
`fb4f3bb78e21f4129436a92b7dccb46ed13f8fa2644a20847c12e5f873f36a54`
(1,011,654 B); arms169 sha256
`c8a5cbf5ad5dcf5ca33eee2046166494a46baa982343b2432743aa74b0eb9e40`
(16,336 B), its gzip sha256
`b31ad1ab8cf67f17625d6f855c614520712eafccb330be7a367209780f0d635e`
(4,689 B). The base hef168.py was verified on the VM ==
the on-device hef168 (sha256 85c7fbb4…) before
assembly. Crossing record: the gzipped arms crossed
in 13 sha-gated parts of 373 B (last part 213 B); all
13 verified on-device — the assembled gzip sha256
matched the VM exactly on the final chunk's whole-file
gate, and the decompressed arms and assembled hef169
sha256 matched the VM exactly on-device; the script
compiled on-device. Before launching, `tmux ls` and
`ps` on Mimir were checked for an existing hef169/h169
child (none — the 4.168 double-launch did not repeat):
exactly ONE bounded host-side child was launched, in
detached tmux with the contract corpus argv (glob
order, MiniLM last), and it finished with DONE169 as
its last line, exit marker 0, err empty (0 B).
Output hef169.out: 47,634 lines / 9,078,100 B, sha256
`b2daa7044a92647431b8e48e90c791d1305492f161085244557d3734ca2ce716`.
Prefix check: of its first 47,379 lines against
hef168.out, exactly TWO lines differ (lines 41,611
and 42,872); both differing lines have identical
length and identical sorted character content in both
outputs — frozenset element order only, the
AES-NUM-150 variance (line 41,611 is the AES-NUM-168
differing line; line 42,872 is the AES-NUM-167 one).
All other 47,377 lines byte-identical. Section 169:
255 lines / 46,623 B, sha256
`89e7b080a347e2eb6c33ebd5b34bc0ae6593a45bdbc2dfe8e43599628c2a5202`,
fetched by a device file read, verified on the VM to
exactly the on-device section sha and read in full.
Controls EXACT (context counts 749 / 751, shared 689,
A-only 60, B-only 62, union 811; both-side keys 31;
channel census {(0, 1): 12, (1, 0): 6, (1, 2): 7,
(2, 0): 6}; runs 68/69 lengths [2, 8], shifts
[+0, +2], first A positions [506, 508]). Raw output
kept on the Pi at ~/aesir-build/ (hef169.out,
hef169.py, arms169.py, section169.txt); local lineage
in ~/workspace/.verify-tmp/aesir169.

## (i) The position-delta law, recomputed directly

The recomputation is direct: every delta, preceding
and following shared act, and containing run was
recomputed from the two full context lists, not
derived from AES-NUM-168's printed table. The direct
census CONFIRMS the derived census exactly:

- delta == preceding shared act's run shift in
  19 of 31 pairs; == following's in 17 of 31;
  == both in 15; == at least one neighbour in 21;
  == neither (the exceptions) in 10.
- The delta distribution is reproduced exactly:
  {−283: 1, −212: 2, −205: 2, −157: 1, −49: 1, 0: 9,
  1: 1, 3: 7, 30: 1, 170: 2, 174: 4}.
- The 10 exceptions are the same pairs, at the same
  A positions with the same deltas, as the derived
  list: +170 at A 212–213, +174 at A 216–217,
  −205 at A 417–418, −212 at A 430–431, +30 at
  A 620, and 0 at A 651.

The exceptions in full, against every neighbouring
run shift within three runs either side (the runs
containing the preceding and following shared acts,
extended three runs in both directions):

- The two +174 exceptions (A 216–217, channel pair
  (0, 1)) DO match a nearby run: both their
  preceding and following shared acts sit in run 6
  (shift −4), and run 7 — the run immediately after
  run 6 in run order — has shift exactly +174
  (run 7: length 2, A extent 220–221), so delta ==
  the pred+1 / foll+1 run shift for both. (Two of
  the four +174 deltas in the population are these
  exceptions; the other two +174 pairs, at
  A 222–223, are non-exceptions whose preceding
  shared act is in run 7 itself, delta == its
  shift directly.)
- The other eight exceptions (+170 ×2 at A 212–213,
  −205 ×2 at A 417–418, −212 ×2 at A 430–431, +30
  at A 620, 0 at A 651) equal NO neighbouring run
  shift within three runs either side: the
  three-run neighbourhood census finds no True match
  for any of them, and the six-shift census
  (preceding run −1 / run / +1 and following run
  −1 / run / +1) leaves exactly these 8 unmatched
  (10 exceptions − the two +174 pairs = 8).
  For the +170 pair the nearby shifts are
  {+434, −2, −4, +174} — +170 itself occurs nowhere
  nearby. For the 0 pair at A 651 the nearby shifts
  are {+8, −391} at the immediate neighbours (per
  AES-NUM-168) and no 0 within three runs.

Delta as a function of single features — all fail:

- Channel pair: 4 keys, ALL 4 violating
  ((0, 1) → {0, +170, +174}; (1, 0) → {−212, −205,
  −157, −49}; (1, 2) → {−283, 0, +1, +3, +30};
  (2, 0) → {0, +3}). NOT A FUNCTION.
- Size: 5 keys, 4 violating (only size 18448 is
  single-valued, → {+3}); sizes 1552 and 14864 each
  carry six different deltas. NOT A FUNCTION.
- A position band, 50-wide: 8 keys, 3 violating
  (band 200 → {+170, +174}; band 400 → {−212, −205,
  −49, +3}; band 650 → {−283, 0, +1}); the clean
  bands are singletons or the +0 band 500.
  NOT A FUNCTION. The 100-wide band test fails the
  same way (5 keys, 3 violating).
- The (channel pair, size) joint: 13 keys, 6
  violating — even jointly the two strongest fields
  do not determine delta. NOT A FUNCTION.

No position-delta law is proven: NOT PROVEN. What
the direct recomputation adds is certainty (the
derived census was exact, not approximate) and the
run-7 refinement for the +174 exceptions.

## (ii) The unmatched heads, aligned by position

Positions 0–27 of both contexts, aligned by position
index (28 positions):

- Size agreement 25 of 28 — the size sequences are
  IDENTICAL except at position 13 (A 32,728 vs
  B 32,768) and at positions 26–27 (A 1552 / 14864
  vs B 280 / 24). Channel agreement 26 of 28 (the
  channels differ only at positions 26 and 27:
  A 0 / 0 vs B 2 / 2). Offset agreement 9 of 28,
  and full-act agreement also 9 of 28 at exactly the
  same positions {2, 3, 4, 7, 9, 12, 18, 21, 24} —
  those nine are shared 24 B acts, identical in
  both contexts; every other aligned pair differs
  at least in offset.
- Context-only acts in the window: A carries 17
  A-only acts, at A positions 0–25 (all offsets in
  the 778,8xx,xxx base). B carries 19 B-only acts in
  B positions 0–27: three with offsets in the
  873,xxx,xxx base (positions 0, 1 and 27) and 16
  with offsets in the 1,196,xxx,xxx base (positions
  5–26). The 17 positions where BOTH sides carry a
  context-only act are exactly A's 17 head
  positions; B's two extra context-only positions
  (26, 27) face shared acts on the A side.
- The position-13 split in full: A pos 13 is
  (778881536, 32728, 1); B pos 13 is
  (1196224512, 32768, 1) — same channel 1, size
  difference exactly +40. Corpus of the two sizes
  inside these contexts: A holds TWO acts of size
  32,728 (positions 13 and 17) and none of 32,768;
  B holds ONE of each (32,768 at position 13,
  32,728 at position 17). At position 17 both sides
  therefore carry a 32,728 act, but on unrelated
  offset bases (778,929,152 vs 1,196,272,096) — both
  context-only, not the same act.
- Offset differences (B − A) at the 25
  size-agreeing positions take 13 distinct values —
  NOT constant. They fall in three groups: 0 at the
  nine shared positions; {94,363,136 at position 0,
  94,362,112 at position 1} for the 873-based head
  acts (the two differ by exactly 1,024); and a
  417,34x,xxx family at the sixteen 1,196-based
  positions, declining overall from 417,354,752
  (position 6) to 417,341,440 (position 25) with two
  upward steps (position 6 itself, +1,536 over
  position 5; and position 16, 417,443,784 — a
  +100,768 jump over its neighbours, the window's
  outlier difference).
- The B head's extra (280) act: B position 26
  carries (1196368696, 280, 2), B-only. Context A
  holds exactly ONE act of size 280 in its full
  list, at A 377: (784342016, 280, 2). Same size,
  same channel 2, unrelated offsets (difference
  +412,026,680) — not the same act, and no
  correspondence: the (offset, size) keys differ,
  so the two 280 acts do not pair under the
  AES-NUM-168 correspondence either.

The heads are therefore one size/channel scaffold
read on three offset bases (778… in A; 873… and
1,196… in B), with a single size substitution at
position 13 and a two-act tail divergence at
26–27. Any mechanism behind the scaffold is
NOT PROVEN.

## (iii) Runs 68 and 69 in full

- Run 68 is a +0 PAIR at A 506–507 / B 506–507 —
  in place, one contiguous B block (acts
  (787312128, 32784, 1) and (787344912, 26128, 1)).
  Its B neighbourhood (B 503–510) is run 67's −2
  tail at B 503, a run-75 (−111) act at B 504 and a
  run-28 (+157) act at B 505 immediately before it,
  then run 68 itself, then run 32's +149 pair at
  B 508–509 and run 69's head at B 510. Its A
  neighbourhood (A 503–510) is run 66's tail, run
  67's pair, run 68, then run 69 in order.
- Run 69 is a +2 BLOCK OF 8 at A 508–515 /
  B 510–517, one contiguous B block (sizes
  32784 / 26128 / 32784 / 32784 / 18448 / 32784 /
  32784 / 18448; channels 1, 1, then six 0s). Its
  B neighbourhood (B 507–520) is run 68's tail at
  B 507, run 32's +149 pair intruding at B 508–509
  between runs 68 and 69 in B order, run 69 itself,
  then run 19's +240 pair at B 518–519 and run 70
  (+4) from B 520. Its A neighbourhood
  (A 505–518) is runs 67, 68, 69, 70 in A order.
- The shared-act order from run 67's first act
  through run 70's first act is exactly runs 67,
  68, 69, 70 in A order (A 504–516), with shifts
  −2, −2, +0, +0, then +2 ×8, then +4.

Mechanisms NOT PROVEN; any position-delta law for
the correspondence NOT PROVEN; the heads' scaffold
mechanism NOT PROVEN.
