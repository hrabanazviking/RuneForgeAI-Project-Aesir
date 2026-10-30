# The channel-disagreement correspondence covers exactly 31 of the 122 context-only distinct acts — every corresponding pair is a 1–1 (offset, size) match whose channels always differ (0 equal in 31; four channel-pair types, no constant remapping), position deltas take 11 values and equal a neighbouring secondary-run shift in 21 of 31 pairs (10 exceptions) — and the remaining 29 A-only and 31 B-only acts share no (offset, size) key at all; no tested feature explains the great group's per-ordered-pair FUNCTION pattern (all 17 candidate features fail on both sides and combined), but the verdict is direction-symmetric in 28 of 28 unordered pairs on both sides, and the never-contradicted keys −191/−145 never recur on the aval side outside the original pair's own rows; runs 63 (−154 pair at B 344–345) and 64 (+23 singleton at B 523) are each one contiguous B block (AES-NUM-168)

Slice 4.168, worked under `docs/TASK_CONTRACT_4.168.md`
(contract published in the 4.167 closing commit @
55343579). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef168.py (hef167.py verbatim as base plus the new
arms168) sha256
`85c7fbb408a579b72b5621dd3ceed835f3184eca5a6473fe9f45fd75b806090a`
(995,318 B); arms168 sha256
`9b7a55250511e9f2f06976b891fac5b96a7888244a10ad50765b57f1006ce009`
(19,707 B), its gzip sha256
`1ca472f176c7972c32ff93b7291b48ca40bba2b87f30f75f97d3aae3146bf8a0`
(5,561 B). The base hef167.py was verified on the VM ==
the on-device hef167 (sha256 6320ca8e…) before
assembly. Crossing record: the gzipped arms crossed
in 15 sha-gated parts of 373 B (last part 339 B); all
15 verified on-device first try. The assembled gzip,
the decompressed arms and the assembled hef168 sha256
all matched the VM exactly on-device, and the script
compiled on-device. LAUNCH INCIDENT, recorded plainly:
the bounded host-side child was launched twice within
35 seconds — a launch of the same sha-verified script
with the contract corpus argv (tmux session `h168`,
started 22:47:03 EDT; its origin is not established in
this run's records) was already running when this
worker made its own launch (tmux session `hef168`,
22:47:38 EDT). This worker killed its own duplicate
on discovery (~35 s of overlap); the surviving child
finished with DONE168 as its last line, exit marker
0, and err empty (0 B). The output's integrity is
proven by the campaign's own gates below (prefix test,
controls, section sha) — had any of them failed, the
run would have been written up as failed instead.
Output hef168.out: 47,379 lines / 9,031,477 B, sha256
`ef8504fcc3382fd792628e8664b7724e48a9d7d1150924782d9f09ceb4ef75df`.
Prefix check: of its first 47,067 lines against
hef167.out, exactly ONE line differs (line 41,611,
frozenset element order only — the AES-NUM-150
variance); all other lines byte-identical. Section
168: 312 lines / 49,165 B, sha256
`2df863f4a855c68a24d8e887e348e7aba25104ac27434de7be461c35e9dae0f9`,
fetched by a device file read, verified on the VM to
exactly the on-device section sha and read in full.
Controls EXACT (context counts 749 / 751, shared 689,
A-only 60, B-only 62, union 811; runs 63/64 lengths
[2, 1], shifts [−154, +23], first A positions
[498, 500]; the AES-NUM-167 gap/skipped channel
control). Raw output kept on the Pi at ~/aesir-build/
(hef168.out, hef168.py, arms168.py, section168.txt);
local lineage in ~/workspace/.verify-tmp/aesir168.

## (i) The channel-disagreement correspondence across both full contexts

The two contexts are artifact 5ab3537d context 86
(A, 749 acts, 60 A-only distinct acts) and context 210
(B, 751 acts, 62 B-only distinct acts). Pairing the
122 context-only distinct acts by their (offset, size)
key:

- 91 distinct keys in the union: 60 carried by A-only
  acts, 62 by B-only acts, and exactly 31 keys appear
  on BOTH sides. Every both-side key is 1–1: exactly
  one A-only act and one B-only act (31 + 31 acts);
  there are NO multi-act keys on either side (the
  multi-act listing is empty).
- At every one of the 31 corresponding pairs the
  CHANNELS DIFFER: equal-channel pairings 0 of 31.
  The channel-pair census is {(0, 1): 12, (1, 0): 6,
  (1, 2): 7, (2, 0): 6} — four of the six possible
  ordered unequal pairs occur, so the correspondence
  is a channel disagreement everywhere it exists, and
  it is NOT a constant remapping ((0, 1) and (1, 0)
  both occur, as do (1, 2) and (2, 0); (0, 2) and
  (2, 1) never occur in this population).
- The seven run-62 gap correspondences of AES-NUM-167
  are inside the 31 (channel pairs (1, 2) ×2 and
  (2, 0) ×5, all at delta +3).
- Position correspondence (derived at closing from
  the printed 1–1 table): the 31 deltas (B position
  minus A position) take 11 distinct values,
  distribution {−283: 1, −212: 2, −205: 2, −157: 1,
  −49: 1, 0: 9, 1: 1, 3: 7, 30: 1, 170: 2, 174: 4}.
  Against the neighbouring secondary-run shifts
  printed for each pair, a pair's delta EQUALS its
  preceding shared act's run shift in 19 of 31 pairs,
  EQUALS its following shared act's run shift in 17
  of 31, and equals at least one of the two in 21 of
  31. The 10 exceptions (delta equal to neither
  neighbour's shift) are: the two +170 pairs at
  A 212–213 (neighbours −2 / −4), the two +174 pairs
  at A 216–217 (neighbours −4 / −4), the two −205
  pairs at A 417–418 (neighbours −29 / −30), the two
  −212 pairs at A 430–431 (neighbours −29 / +234),
  the +30 pair at A 620 (neighbours +8 / −391), and
  the 0 pair at A 651 (neighbours −1 / +26). No
  single position law covers all 31: NOT PROVEN.
- Unmatched residue: 29 A-only acts under 29 A-only
  keys and 31 B-only acts under 31 B-only keys share
  no (offset, size) key with the other context at
  all. A-side residue: a 17-act head at A 0–25
  (offsets 778,8xx,xxx), two acts at A 377–378, two
  at A 673 / 681, and eight 24 B tail acts at
  A 733–748; corpus occurrences {1: 22 acts, 2: 3,
  29: 4}. B-side residue: the single act
  (3429888, 2064, ch 1) at B 271, three 873,xxx,xxx
  acts at B 0 / 1 / 27, a 17-act head at B 5–26
  (offsets 1,196,xxx,xxx), three acts at B 229 / 272
  / 674, four 24 B acts at B 735–738, and three
  further 24 B acts at B 747–750; corpus occurrences
  {1: 24 acts, 3: 3, 21: 1, 23: 3}. The two heads
  sit at the same positions with near-identical size
  sequences but unrelated offset bases — their exact
  sequence relation is the next slice's question,
  not a finding here.

## (ii) The per-ordered-cell-pair FUNCTION pattern in the great group

The verdict counts reproduce AES-NUM-167 exactly over
the 56 ordered cell pairs of group (20, 32720) (each
27 matched rows, 0 ambiguous): aval FUNCTION 28,
bval FUNCTION 32, both 16, both NOT 12, aval-only 12,
bval-only 16.

- NO candidate feature explains either side: all 17
  features stated in the contract before testing —
  from-offset, to-offset, offset difference, absolute
  offset difference, direction, signed distance,
  absolute distance, from-index, to-index, the mod-2
  and mod-3 index/distance features, and the two
  joint features — return NOT A FUNCTION for the
  aval verdict, the bval verdict, and the combined
  four-way category. Every feature's every key class
  that could separate the verdicts is violated
  somewhere (violating keys range 2–12 per test; the
  least-violated, absolute distance on the aval side,
  still violates 4 of 7 keys). The pattern's
  determinant remains NOT PROVEN.
- One exact regularity DOES hold: the verdict is
  direction-symmetric. For all 28 unordered cell
  pairs, the ordered pair (x, y) and its reverse
  (y, x) carry the SAME aval verdict (28/28) and the
  SAME bval verdict (28/28). Direction therefore
  cannot be part of any determinant: whatever decides
  FUNCTION vs NOT A FUNCTION here is a property of
  the unordered cell pair (or of quantities symmetric
  in it), even though no symmetric candidate feature
  tested above separates it either.
- The never-contradicted original keys, in full:
  on the aval side, key −191 occurs in exactly 1
  widened row — its own original-pair row
  (6864 → 6932, byte3 difference 16) — and key −145
  in exactly 4 widened rows, ALL of them from the
  original ordered pair (6864 → 6932), all with
  byte3 difference 16. Neither key recurs in any
  other ordered pair's aval rows at all: their
  never-contradicted status is non-recurrence
  outside the original pair, not survival under
  widening. On the bval side the same byte2 keys DO
  recur elsewhere with other values (−191: rows at
  6932 → 6796 with −33 and 7272 → 7136 with −5;
  −145: rows at 7000 → 7136 with 15 and 7204 → 7136
  with −4), two rows each.

## (iii) Runs 63 and 64 in full

- Run 63 is a −154 PAIR at A 498–499 / B 344–345,
  one contiguous B block (acts (787159040, 1552, 0)
  and (787160592, 14864, 0)). Its B neighbourhood
  (B 341–348) is run 26's +2 tail (B 341–343), then
  run 63 itself, then run 66's −156 pair (B 346–347),
  then run 27 (+6) at B 348. Its A neighbourhood
  (A 495–502) is run 62's +3 tail (A 495–497), run
  63, run 64, run 65, run 66 in order.
- Run 64 is a +23 SINGLETON at A 500 / B 523, one
  contiguous B block (act (787175936, 32784, 0)).
  Its B neighbourhood (B 520–526) is run 70's +4
  tail (B 520–522), run 64 itself, then run 74 (+0)
  from B 524. Its A neighbourhood (A 497–503) is
  run 62's last act, run 63's pair, run 64, run 65,
  run 66's pair in order.
- The shared-act order from run 62's last act
  through run 65 is exactly runs 62, 63, 64, 65 in
  A order (A 497–501), with shifts +3, −154, −154,
  +23, +0.

Mechanisms NOT PROVEN; the FUNCTION pattern's
determinant NOT PROVEN; any position law for the
correspondence NOT PROVEN.
