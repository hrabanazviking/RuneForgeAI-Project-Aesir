# The deviating ff instances sit in a sparse segment form (zero instances share one byte-identical neighbourhood), the camp middles differ across ranks only in unit 0, and the per-ng lens adds no form inside the classified ff population — its NGIDX offsets are degenerate exactly where a network group contributes one instance (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.94 (AES-NUM-094).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef94.py
(sha256 1224464837b1f5ffc62bff7a67f5000fa2e1374cf5deb40d21cf1a37e06aac7b...,
landed via sha-gated chunked file.write transfer,
gz sha256 60b34428a461f29ea3c09c4ab4d2e40021873e2b200c02936f04ec3c29090c1e...
verified on-device; script sha verified on-device).
Output: /tmp/hef94_out.txt sha256
077fd0e0c51ab1b267eec4fc75edec987d70612ef2ded1db3a75cdc6f3e0d649....
Controls reproduce AES-NUM-029/032...093 EXACTLY
(128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts;
trailing distinct (channel, operand) pairs 2,049;
champion-headed bursts 75,215), the scanner re-derives
AES-NUM-090/091 exactly (in-band 374 groups, OTHER 4
all STEP; band X 60 / 3,335, OTHER 0; band Y 27 / 354,
OTHER 0; S1 OTHER 16, S2b OTHER 10, all non-step),
the 26 non-step OTHER offsets re-derive with per-ng
CONST 14 and combined per-ng coverage 19, residue
exactly 7, trains reproduce exactly (52 trains;
unique-first 28, unanimous 13, elsewhere 11;
D(cidx 113) = 249; firsts' D-positions 3,089;
control-arm D-positions 176), and the rank-2 middles
reproduce AES-NUM-093 (lenA 168 / lenB 232, 21 aligned
mismatches at k = 111, 4 shared distinct units at
indices 1–4). Definitions (ff scan, trains, camps,
middles) are as in AES-NUM-086...093. Contract:
docs/TASK_CONTRACT_4.94.md (published @ 0eb6c64f,
before implementation).

## (i) Deviating-instance anatomy: every target group has exactly one common ff offset; the deviating instances are the sparse-neighbourhood instances, and in T3/T4/T5 the value-0 instances share one byte-identical sparse neighbourhood

The five residue targets of AES-NUM-093, re-derived
exactly (one-deviation NGIDX unless stated):

- T1 0a0d378c pos 21 / 15128, n = 3: values
  (ngidx 1 -> 3, 57 -> 57, 87 -> 87); the deviating
  instance is cidx 74 (ng 1, ngidx 1, value 3).
- T2 0a0d378c pos 13 / 25552, n = 17: values equal
  ngidx (6, 12, ..., 96) except cidx 76 (ng 1,
  ngidx 3, value 15).
- T3 5ab3537d pos 8 / 31848, n = 3: values
  (87 -> 87, 90 -> 0, 116 -> 116); deviating
  instance cidx 89 (ng 0, ngidx 90, value 0).
- T4 773470cd pos 14 / 29184, n = 2: values
  (6 -> 6, 122 -> 0); deviating instance cidx 216
  (ng 1, ngidx 122, value 0).
- T5 773470cd pos 15 / 29184, n = 5: values
  (85 -> 0, 93 -> 0, 38 -> 38, 114 -> 0, 119 -> 0);
  the matching instance is cidx 132 (ng 1).

Each target group has exactly ONE common ff offset —
the target itself — so the deviates-elsewhere test
of the contract has no other offset to bite on in
any of the five groups (every instance's
other-offset deviation count is 0, vacuously).
Separator tests (exact: holds for the distinguished
instance D, for no conforming instance):

- T1: D is first by cidx, train-first (train 14
  rank 1; the conformers sit in train 18 at ranks
  10 and 15), unique word neighbourhood, unique
  (prev, next) action pair (next (18864, 0) vs the
  conformers' (24472, 0)).
- T2: D is first by cidx, unique word
  neighbourhood, unique action pair (next
  (30664, 0) vs (8576, 0)). D is train-first too
  (train 18 rank 1) but so is the first conformer
  (cidx 79, train 15 rank 1) — not a separator.
- T3: unique word neighbourhood and unique action
  pair only (next (9488, 1) vs (24, 1)).
- T4: D is last by cidx, in no train (the
  conformer is in train 43), unique word
  neighbourhood, unique action pair.
- T5 (D = the matching instance cidx 132): unique
  word neighbourhood and unique action pair only.

Inspection of the printed 5-word neighbourhoods
(words at off-8, off-4, off, off+4, off+8) shows a
shared form behind the uniqueness (post-hoc
characterisation of the printed tuples, measured
on these instances): in every target, D — and in
T5 all four value-0 instances — carries a SPARSE
neighbourhood (at least 3 of the 5 words all-zero),
while every conforming / value-carrying instance
carries a DENSE neighbourhood (exactly 1 all-zero
word, the off+4 word). In T3, T4 and T5 the sparse
form is byte-identical across artifacts: words
(00000000, ff0f0000, ff000000, 00000000, 00000000)
— a second ff word carrying value 15 sits at
off-4 and the target word itself reads ff000000
(value 0). T5's matching instance and T4's
conformer share the dense form (01001a00,
1401b100, ffXX0000, 00000000, 02001a00). T1's and
T2's deviating instances carry their own sparse
variants (T2's target word is itself ff0f0000,
value 15 at ngidx 3).

Sister twin: the 5ab3537d group at T5's (pos 15,
size 32608), offset 29184, n = 3: instances
(84, ng 0, ngidx 85, 0), (89, ng 0, ngidx 90, 0),
(132, ng 1, ngidx 38, 38) — pooled OTHER but
per-ng CONST exactly ({ng 0: 0, ng 1: 38}), i.e.
the twin is one of the 19 per-ng-covered offsets,
not residue. The sisters share cidx 84 (value 0,
sparse) and cidx 132 (value 38, dense); 773470cd
additionally has cidx 92, 208, 213 (all sparse,
value 0), and it is the extra ng-1 sparse
instances (208, 213) that break ng-1 constancy
in T5 where the twin's single ng-1 instance
leaves it intact.

Verdict: MEASURED — the deviating instances are
exactly the sparse-form instances in all five
targets; where the sparse form appears it carries
value 0 at the target offset (T3/T4/T5) or, for
the two 0a0d378c targets, the group's only
non-index value from a first-in-group instance.
Whether the sparse form is a distinct segment
species (so the "deviation" is structural, not a
changed scalar) is NOT PROVEN; what the values 3
(T1) and 15 (T2) encode is NOT PROVEN.

## (ii) Per-rank middle units: the four grown ranks' middles differ only in unit 0; units 1–4 are shared at every rank; no B unit at index >= 5 occurs in any A middle

For every grown rank r in {2, 8, 22, 26} the
consensus middles are lenA 168 / lenB 232, cut
into 16 B units (A: 10 full + 8 B tail; B: 14 full
+ 8 B tail):

- At every rank: A has 11 distinct units, B has 14
  distinct of 15 (B unit 6 recurs verbatim at
  index 11 — the lag-5 match of AES-NUM-093);
  exactly 4 distinct units are shared between the
  camps, at indices 1–4 in both middles; A units
  1–4 equal B units 1–4 at the same index.
- Aligned mismatches per A unit are the SAME list
  at every rank and at both insertion offsets:
  [1, 0, 0, 0, 0, 2, 2, 4, 7, 2, 3], total 21, at
  k = 111 and at k = 112; exactly 4 of A's 10 full
  units are exact at their aligned offset (units
  1–4); unit 8 carries 7 mismatches everywhere.
  The 8 B tails differ at every rank (A
  010000800080000b, B 00000000008000a4).
- Unit lags 1–9 are rank-invariant: A matches 0
  units at every lag; B matches 0 except 1/10 at
  lag 5 (the B06/B11 recurrence).
- Cross-rank: the middles differ ONLY in unit 0.
  A unit indices 1–10 and B unit indices 1–14 are
  identical across all 4 ranks; unit 0 varies at
  bytes 6–7 (A: rank 2 8780, rank 8 8900, rank 22
  8500, rank 26 8b80; B unit 0 carries the same
  two bytes). Pairwise byte identity: A 166–167
  of 168, B 230–231 of 232.
- B-tail vocabulary: every full unit of the
  rank-2 B middle at indices 5–13, every full unit
  of the rank-2 A middle at indices 5–9, and the
  pooled distinct B units at indices >= 5 over
  all ranks (8 distinct) searched verbatim in the
  opposite camp's middles (all ranks, any offset):
  ZERO hits in both directions. The camps share
  nothing at unit granularity beyond units 1–4.

Verdict: MEASURED — the rank axis contributes
exactly one varying unit (unit 0, two bytes) to
the camp middles; the unit anatomy of
AES-NUM-093 is rank-invariant, and the B middle's
post-shared-block vocabulary is disjoint from
the A middle's at 16 B granularity. What the two
unit-0 bytes encode, and what carries the
16-byte rhythm if not unit repetition, remain
NOT PROVEN.

## (iii) Per-ng forms inside the classified population: no new form — pooled CONST is one constant across both network groups in all 6,805 both-ng cases, and pooled NGIDX degeneracy is exactly single-instance network groups

The five disjoint scan populations of
AES-NUM-093 re-derived and re-classified in one
pass; the per-population group and class counts
match the scanner's exactly in all five
(INBAND 374 groups: CONST 17,351 / NGIDX 3,290 /
OTHER 4; BANDX 60: 2,802 / 533 / 0; BANDY 27:
285 / 69 / 0; S1 719: 25,681 / 4,639 / 16; S2b 15:
21 / 1 / 10). Pooled classified offsets: CONST
46,140, NGIDX 8,532, OTHER 26.

- CONST arm: 39,335 offsets sit in a single
  network group, 6,805 in both. In ALL 6,805
  both-ng cases the per-ng constants are EQUAL
  (differing per-ng constants: 0) — pooled CONST
  is never two different per-ng constants in
  disguise. 6,447 CONST offsets have a present
  ng contributing exactly 1 instance.
- NGIDX arm: no present ng is ever neither
  NGIDX-exact nor CONST (0), and no ng is CONST
  with >= 2 distinct ngidx values (0) — the
  contract's two candidate new forms do not
  occur. Degeneracy census: SINGLE (one ng
  present) 7,473; ALL-DEG 950; ONE-DEG 90;
  BOTH-NONDEG 19. All degeneracy sits in the S1
  population (the >= 8-instance bands are 100%
  SINGLE: every in-band / X / Y group lives in
  one network group). Since ngidx is distinct
  per instance within an ng, a degenerate ng is
  exactly a single-instance ng: of the 1,059
  both-ng NGIDX offsets, 950 have one instance
  in each ng, 90 have one single-instance ng,
  and only 19 are NGIDX with >= 2 instances in
  both ngs.

Verdict: MEASURED — the per-ng lens adds NO
form inside the already-classified population.
Pooled CONST and pooled NGIDX mean the same
thing per network group as pooled, wherever a
network group contributes enough instances to
tell; the per-ng CONST/NGIDX forms of
AES-NUM-093 are a sparse-population phenomenon
(small groups spanning both ngs), not a hidden
refinement of the classified bulk.

## Next (slice 4.95)

- Sparse-form census: classify instances by
  neighbourhood form (sparse vs dense, by the
  5-word zero count) across the OTHER-habitat
  groups and the 19 per-ng-covered groups — does
  sparse form predict the value at every common
  offset of its segment, or only at the target?
- Middle unit 0: the rank-varying two bytes
  (8780 / 8900 / 8500 / 8b80) — their values in
  the grown regions' prefixes and elsewhere in
  the camp segments; is unit 0 a per-rank form
  of a wider family?
- B06/B11 recurrence: the B middle's one
  repeated unit — its two aligned spans against
  the A middle and the chunk at k = 111/112.
Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts within the stated bands and floors; blob
identities are sha prefixes only. Every count,
occurrence, alignment and distribution above is
MEASURED as stated; every meaning — what the sparse
form is, what the deviating values encode, what the
unit-0 bytes encode — is NOT PROVEN and nothing
here invents one.
