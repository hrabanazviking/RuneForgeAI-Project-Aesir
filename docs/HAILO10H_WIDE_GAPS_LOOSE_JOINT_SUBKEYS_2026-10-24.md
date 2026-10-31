# The rigid block's three wide gaps are shape-constant but act-variable — every gap holds the same size pattern in all 271 contexts ((248, 176), (256, 176), and (328, 328, 328)) while the acts themselves change (34, 30, and 87 distinct between-tuples); the loose pair's distances do not determine each other (d1 as a function of d0 fails on 7 of 13 keys, d0 as a function of d1 on 9 of 12), its order is not a function of either distance alone (each fails on exactly the distance-4 key) but IS a function of their difference (19 distinct differences, 0 violating keys — the order is exactly the sign of d0−d1, as it must be when both acts precede the block), and the single distance-33 context is cidx 143, where L0 stands 32 acts before the block with L1 inside that span at distance 2; and in the great group no proper sub-key of the A word separates byte-0 identity from rewriting or determines the rewritten value, except (byte 3, byte 1, byte 2), which separates only by unique identification (216 distinct values for 216 pairs, no key ever repeating) — the near-miss two-byte keys each fail on exactly one value — while the byte-0 difference is not a function of A byte 0 (21 of 32 values violating) — mechanisms NOT PROVEN (AES-NUM-130)

Slice 4.130, worked under `docs/TASK_CONTRACT_4.130.md`
(contract committed first @ 5107e11a). Host/artifact analysis
only, on Mimir (purpleviking1) — no physical child, no
device run of any kind. All findings below are taken from
the sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef130.py (the hef129 file verbatim as base — itself the
hef128/hef127 lineage — plus the new arms130) sha256
`16b77b5b39b401356995c2aa282bc215d8aa49088b2649f8ffa857713453c2dd`
(425,635 B); arms130.py sha256
`f0427b9a0fd5b458229586272a1997d0855a759b8914b6235011b33690cf0d3f`
(13,773 B), its gzip sha256
`df60c075eb497f2f3440d44879f162da92f318b0d77c1d80bce448d9fed33fe5`
(4,026 B). The resume, build, transfer and launch were
carried out by the 10-minute continuity worker (keeper;
state file entry 04:01 EDT resume — contract @ 5107e11a
published 03:40 EDT, no Aesir processes running, tree
clean at 5107e11a == remote, no hef130 work product
existed). arms130 crossed by the proxy-upload route (a
one-shot on-device receiver held by a subagent; the
receiver reported SAVED 4026 and the on-device gz sha256
matched the VM's before assembly); hef130.py was
assembled on-device from the verified hef129 base
(on-device sha256 2ce607d7… == VM) plus arms130, and the
assembled file's sha256 matched the VM's exactly. The
one bounded host-side child was launched with the
contract corpus argv (the six hailo-ollama blobs in glob
order, then MiniLM — the launch law recorded in the
contract after 4.127's no-argv failure) and finished
on-device with an empty error file; DONE130 is the
output's last line. The retrieved output is 21,006
lines / 3,755,795 B, sha256
`e3f1170d498908ba2f1f7c4b75bb932bf8117d6b407597b4ffa98e25743b047d`;
retrieved gz sha256
`fb4335c0bb40e80266b894f8cba0b3ba493efc93ceb1bc6fc38bc4dc0ed6920a`
(454,313 B, fetched through a temporary on-device HTTP
server via the tunnel proxy; the fetched gz sha256
equals the on-device gz sha256 and decompresses to
exactly the output sha256, verified on the VM at
closing); the 4.130 section begins at output line
18,164 — exactly one past 4.129's total line count, and
the first 18,163 lines are byte-identical to hef129.out
(verified with cmp at closing), the base having
reproduced line-for-line.

## Controls

Inherited controls reproduce EXACTLY: small 128,787 /
burst 79,001 / pointer 745,849 / contexts 1,504 /
trail pairs 2,049 / champion 75,215 (first output line);
cells 55,902 / obs 527,236; divergent triples 2,171,
verdicts CONT 12,411 / BREAK 476 / INDET 2,365; lane-1
pairs 224; (byte 3, byte 1, byte 2) keys 222; (byte 3,
sum) keys 222; shared 114×251 acts 168; occurrence-2
population 127; class-271 acts 30 (loose pair
(2727936, 24, 2) / (2774016, 24, 1), 28 rigid, first
rigid (172544, 376, 0), last rigid (2817536, 24, 0));
rigid from-ends in block order exactly
[54, 53, 52, 51, 50, 47, 46, 45, 44, 43, 42, 41, 38, 37,
36, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 20];
great group (20, 32720) 216 pairs / 36 identity /
180 differing; rigid context set 271 contexts, all in
artifact cc9b9d1c.

## (i) The three wide gaps in every context

For each gap, all 271 contexts were printed in full
(left and right rigid neighbours' positions and
from-ends, the successive difference, and every act
standing between, with its position and from-end).
The gaps are NOT act-constant, but their shape is
rigid (derived at closing from the printed verdict
distributions):

- Gap 0 — (173040, 24, 0) @ from-end 50 → (173568, 816, 0)
  @ 47: 34 distinct between-tuples over 271 contexts.
  Every context holds exactly 2 acts of sizes
  (248, 176) at from-ends 49 and 48. 34 distinct first
  acts, 27 distinct second acts (61 distinct gap acts
  in all, corpus-occurrence counts summing to 542 =
  2 × 271; occurrence distribution {1: 22, 2: 15, 4: 5,
  6: 1, 10: 2, 12: 1, 25: 1, 27: 11, 28: 2, 54: 1} —
  derived). The modal tuples repeat 27–28 times; the
  second act (1198581760, 176, 0) serves 54 contexts
  under more than one first act. Second-minus-first
  offset is +248 in 187 contexts and +512 in 46, and
  negative in the remaining 38 (derived).
- Gap 1 — (174968, 24, 0) @ 41 → (175616, 176, 0) @ 38:
  30 distinct between-tuples. Every context holds
  exactly 2 acts of sizes (256, 176) at from-ends 40
  and 39. 30 distinct first acts, 27 distinct second
  acts (57 distinct gap acts, occurrences summing to
  542; distribution {1: 18, 2: 13, 4: 4, 6: 3, 8: 1,
  10: 2, 27: 12, 28: 4} — derived). Second-minus-first
  offset is +256 in 257 contexts and +512 in 8, negative
  in 6 (derived).
- Gap 2 — (178792, 216, 0) @ 24 → (2817536, 24, 0) @ 20
  (the before-flank): 87 distinct between-tuples.
  Every context holds exactly 3 acts, all of size 328,
  at from-ends 23, 22, 21. 70 / 73 / 72 distinct acts
  at the three positions (215 distinct gap acts,
  occurrences summing to 813 = 3 × 271; distribution
  {1: 158, 2: 18, 3: 3, 4: 2, 12: 11, 13: 11, 21: 1,
  22: 1, 25: 4, 26: 5, 54: 1} — derived). Consecutive
  offsets step by exactly +328 in 189 of 271 contexts
  at the first step and 221 at the second (derived).

Verdict: a wide gap is a fixed-size slot pattern
filled by context-varying acts — the spacing law of
AES-NUM-129 is a law about positions, not about which
acts stand there. Any template or mechanism NOT PROVEN.

## (ii) The loose pair's joint behaviour

Both distances were read together in all 271 contexts
(per-context L0/L1 positions, from-ends, distances,
order, and d0−d1 printed in full):

- Joint distribution: 33 distinct (d0, d1) pairs.
  Modal (1, 3) ×46, (3, 1) ×43, (2, 5) ×26, (2, 9) ×25,
  (2, 4) ×17. Marginals reproduce AES-NUM-129 exactly
  (d0: 1 ×85, 2 ×72, 3 ×43, …, 33 ×1; d1: 1 ×75, 3 ×46,
  9 ×39, …). Order census reproduces it too:
  L1-before-L0 170, L0-before-L1 101.
- d1 is NOT a function of d0 (13 distinct d0 keys, 7
  violating). d0 is NOT a function of d1 (12 distinct
  d1 keys, 9 violating). The two distances do not
  determine each other in either direction.
- Order is NOT a function of d0 (violating on exactly
  one key, d0 = 4, which carries both orders) and NOT
  a function of d1 (violating on exactly one key,
  d1 = 4, both orders). Order IS a function of the
  difference d0−d1 (19 distinct differences, 0
  violating keys) and of the joint (d0, d1) (33 keys,
  0 violating) — the difference result is exactly the
  sign law: with both acts before the block, the act
  with the larger distance stands first, so the order
  adds no information beyond the comparison of the
  two distances. Any deeper relation NOT PROVEN.
- The distance-33 outlier is exactly one context:
  cidx 143 (length 606). L0 (2727936, 24, 2) at
  position 518, from-end 87, distance 33; L1
  (2774016, 24, 1) at position 549, from-end 56,
  distance 2; first rigid act at 551, from-end 54;
  order L0-before-L1. The 32 acts between L0 and the
  block are printed in full: a run of large acts
  (sizes 28168–32784, offsets ascending from
  1224648704) containing L1 itself at position 549,
  followed by one further act (1225459712, 32784, 0)
  between L1 and the block. Against the modal
  contexts — modal joint (1, 3) ×46 and (3, 1) ×43,
  where the loose acts stand within 3 of the block —
  the outlier is the one context where L0 is
  separated from the block by a whole large-act run
  while L1 sits at the modal distance 2 inside that
  same span. Mechanism NOT PROVEN.

## (iii) The great group's byte-0 rewriting vs sub-keys

Population: group (20, 32720), 216 pairs (36 identity,
180 differing). For each of the ten contract sub-keys,
the test was exact: a value fails the status test if
it carries both identity and differing pairs, and
fails the B-value test if it carries two or more
different B byte 0 values among its differing pairs.
Violating values and their pairs are printed in full
in the raw output.

- (byte 3): 59 values; status-violating 14; B-violating 30.
- (byte 1): 146 values; status 15; B 42.
- (byte 2): 147 values; status 15; B 39.
- (byte 0): 33 values (32 in the differing pairs plus
  the identity-only values); status 8; B 21.
- (byte 3, byte 1): 214 values; status 1 — exactly
  (249, 44); B 1 — exactly (252, 84) → {8, 120}.
- (byte 3, byte 2): 215 values; status 1 — exactly
  (249, 181); B 0.
- (byte 1, byte 2): 215 values; status 0; B 1 —
  exactly (128, 146) → {128, 160}.
- (byte 3, byte 1, byte 2): 216 values; status 0; B 0 —
  but the key takes 216 distinct values for 216 pairs:
  it never repeats inside the great group (the
  injectivity already recorded in AES-NUM-124), so
  its separation is determination by unique
  identification only, the same honest grading as the
  full A word in AES-NUM-129. It is not a compressive
  determination.
- (byte 0, byte 1): 209 values; status 1 — exactly
  (128, 136); B 4.
- (byte 0, byte 3): 168 values; status 7; B 21.

So no proper sub-key both separates the statuses and
determines the rewritten byte 0 with any repetition
to spare: the two-byte keys come within one value of
separating the statuses, and each such near-miss is
named above in full. Separately, the differing pairs'
difference (B byte 0 − A byte 0) is NOT a function of
A byte 0: 180 differing pairs over 32 distinct A byte 0
values, 21 violating values (only 11 A byte 0 values
carry a single difference), the differences spanning
−240…+240 in the same 40 values as AES-NUM-129.

Verdict: byte-0 rewriting in the great group is not
explained by any proper part of the A word tested.
What it is a function of beyond the full word is NOT
PROVEN.

## Next

Slice 4.131 — the gap-fillers as a population (the
first→second offset relation inside each gap; the
shared second acts and which firsts they serve; gap
acts read against the contexts' own bodies — gap-only
or body acts too); the outlier's 32-act run read
corpus-wide (does that run, or its acts in that order,
stand anywhere else, and what stands around L0 in the
modal contexts by contrast); and the three near-miss
sub-key collisions in full ((249, 44) and (252, 84)
under (byte 3, byte 1), (249, 181) under (byte 3,
byte 2), (128, 146) under (byte 1, byte 2) — their
pairs, records and cells), with B byte 0 itself tested
as a function of the two-byte sub-keys. Host/artifact
analysis only — no physical child.
