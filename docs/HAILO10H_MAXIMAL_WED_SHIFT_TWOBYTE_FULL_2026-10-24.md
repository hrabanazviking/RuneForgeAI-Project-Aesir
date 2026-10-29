# Gap 2's chain does not repair under the maximal compound joint key wed to either of its last two companions either — wed the context length, or wed the gap's own left position, and the key count does not move at all (86 distinct keys under either wed, exactly the maximal key's own count; position-1 fails on the same 2 keys, position-2 and the whole tuple on the same 3, with the wed values — lengths 245 / 606 / 873, left positions 220 / 581 / 848 — simply riding on the violating maximal keys they were already constant on). The exception contexts' shared-act shift anatomy is now exact: every one of the 689 shared acts is single-positioned in both homes, so its shift (position in B minus position in A) is well-defined; the 69 distinct shifts run from −455 to +434, dominated by +2 (283 acts) and 0 (126 acts, the same-position population), with 466 acts shifted positive, 97 negative, and a long scattered tail (69 acts at |shift| ≥ 100). The 126 same-position acts cluster — a sparse head at positions 2–24, a pair at 188–189, a solid block at 242–270, and a dense region from 501 to 614 ending in a solid 34-act block at 581–614. Read in A-position order the shared acts form 118 maximal runs of consecutive A-positions at one constant shift (103 runs when A-position gaps are ignored), the longest a single 158-act run at shift +2 over A-positions 26–183. And B byte 0 against the six two-byte sub-keys over the FULL 224-pair population repeats violating under every key (63 repeating values in all, 13 agreeing and 50 violating; (byte 0, byte 3) heaviest at 35 repeating values, 27 violating): no two-byte key determines the byte over the whole population, and almost every repeated value lives entirely inside the great group — the cross-group repeats are exactly the small-group sharings already counted in AES-NUM-134/135, plus (byte 0, byte 1) = (32, 1), the one violating value that touches the great group — mechanisms NOT PROVEN (AES-NUM-137)

Slice 4.137, worked under `docs/TASK_CONTRACT_4.137.md`
(contract published in the 4.136 closing commit @
daaaf688). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef137.py (the hef136 file verbatim as base — itself
the hef135/hef134/hef133/hef132/hef131/hef130 lineage
— plus the new arms137) sha256
`a1b115e693dcfa3f2fcfe707d485262633c629ef29ce0fd60c287f47cb3e62c6`
(519,470 B); arms137 sha256
`f1add2ef3f6e811eee8ea499600592a87207a8585cab65f3781c934358f8ba68`
(12,779 B), its gzip sha256
`0df5e69bc0acf66b04fa665df1b74067edce4d671edc0cfd2b25a86678b85d6c`
(3,849 B). The arms were built locally by the
10-minute continuity worker and crossed by the
proxy-upload route (a one-shot on-device receiver
derived on-device from the verified recv136 receiver,
held in the foreground by a worker agent; the
receiver reported SAVED 3849 and the on-device gz
sha256 matched the VM's before assembly); hef137.py
was assembled on-device from the verified hef136 base
(on-device sha256 81c5790e… == VM) plus the arms, and
the assembled file's sha256 matched the VM's exactly
before the run. The bounded host-side child was
launched in a detached tmux session on-device with
the contract corpus argv (the six hailo-ollama blobs
in glob order, then MiniLM — the launch law recorded
in the contract) and finished on-device (DONE137 is
the output's last line; the run's exit marker is 0;
the error channel carried nothing but that marker).
The retrieved output is 30,308 lines / 5,667,810 B,
sha256
`878dcc178a72ee5f925b49fef4cfdc3f0a627331580d3d5542f60a9c27bb5fbf`;
retrieved gz sha256
`9565ffcf75d96c126f555798feef1f122794624c91333a966a2f1d679e1fd2ce`
(592,905 B, fetched through a temporary on-device HTTP
server via the tunnel proxy; the fetched gz sha256
equals the on-device gz sha256 and decompresses to
exactly the output sha256, verified on the VM at
closing); the 4.137 section begins at output line
28,719 — exactly one past 4.136's total line count, and
the first 28,718 lines are byte-identical to hef136.out
(verified with cmp both on-device and on the VM at
closing), the base having reproduced line-for-line.

## Controls

Inherited controls reproduce EXACTLY: cells 55,902 /
obs 527,236; divergent triples 2,171, verdicts CONT
12,411 / BREAK 476 / INDET 2,365; lane-1 pairs 224;
(byte 3, byte 1, byte 2) keys 222; (byte 3, sum) keys
222; shared 114×251 acts 168; class-271 acts 30; rigid
context set 271; great group (20, 32720) pairs 216;
gap between-tuple counts 34 / 30 / 87 for gaps 0 / 1 / 2;
contexts indexed 1,504.

## (i) Gap 2's chain against the maximal compound joint key wed to the context length and to the gap-2 left position

All six tests are computed exactly over the 271 rigid
contexts (271 rows each). Every test prints its
distinct joint keys, its repeating joint keys in full,
and every violating joint key with its alternatives
and every carrying context's full row. The maximal
compound joint key is (position-0 act, loose distances
(d0, d1), loose order, gap-0 tuple, gap-1 tuple), as
established in AES-NUM-136 (86 distinct, 15 repeating).

- Wed to the context length: 86 distinct keys, 15
  repeating — the wed adds NO distinct key over the
  maximal key alone. Position-1 is NOT a function of
  it (2 violating keys), position-2 is NOT a function
  of it (3 violating), and the whole gap-2 tuple is
  NOT a function of it (the same 3 violating keys).
- Wed to the gap-2 left position: 86 distinct keys,
  15 repeating — again NO distinct key added.
  Position-1 fails on 2 keys, position-2 on 3, the
  whole tuple on the same 3.
- The violating keys are, under both weds, exactly
  the maximal key's violating keys with the wed
  component appended (derived at closing from the
  printed tables): the (33312256, 328, 0) key at
  distances (1, 3) carries length 245 and left
  position 220, with 2 alternatives at position-1
  and 2 at position-2; the (976502784, 328, 0) key
  at (1, 3) carries length 873 and left position
  848, with 2 and 2; the (1255547392, 328, 0) key
  at (2, 9) carries length 606 and left position
  581, violating only at position-2 / the whole
  tuple, with 3 alternatives differing only at
  position-2. Every violating key sits under
  L1-before-L0 in its maximal form, as before.
- Because a wed key refines its base key, a wed that
  adds no distinct key anywhere in the 271 contexts
  proves the wed component is constant on every
  maximal-key family in the population (derived at
  closing): in these 271 contexts the context length
  and the gap-2 left position are each already
  determined by the maximal compound key, so neither
  can carry any further distinction for the chain —
  and neither repairs it.

No companion tested — distances, order, either
sister, both sisters, length, left position, in any
compound — repairs the chain. What varies the fill
inside a maximal family is NOT PROVEN.

## (ii) The exception contexts' shared-act position-shift anatomy

The exception is (791774208, 328, 0), at 5ab3537d
cidx 86 position 725 and cidx 210 position 727
(AES-NUM-136: contexts of 749 and 751 distinct acts,
689 shared, 60 A-only, 62 B-only, union 811 — all
reproduced exactly by this run's controls). Every
shared act is printed in the run with its position
in A, its position in B and its shift.

- Every one of the 689 shared acts occurs at exactly
  one position in A and exactly one in B (multiple
  positions: 0 in A, 0 in B), so the shift (position
  in B minus position in A) is well-defined for the
  whole shared population.
- Shift distribution over the 689 acts, counted
  exactly: 69 distinct shift values, minimum −455,
  maximum +434. The mass is at small positive shifts
  (derived totals from the printed distribution):
  shift +2 on 283 acts, shift 0 on 126 (the
  same-position acts of AES-NUM-136, reproduced),
  shift +3 on 55, shifts −2 and +5 on 26 each, −1
  and +1 on 11 each, −5 on 9; 466 acts shift
  positive, 126 do not shift, 97 shift negative;
  448 acts sit at |shift| 1–9, 46 at 10–99, and 69
  at |shift| ≥ 100 (the scattered tail running to
  −455 and +434). The exception itself shifts +2
  (725 in A, 727 in B).
- The 126 same-position acts' positions in A, in
  full in the run, range from 2 to 614, each position
  carried by exactly one act. Their clusters
  (derived at closing): singletons and a triple in a
  sparse head (2, 3, 4, 7, 9, 12, 18, 21, 24), the
  pair 188–189, one solid block of 29 at 242–270,
  and a dense region from 501 to 614 (86 acts: the
  solid runs 524–548 of 25, 569–579 of 11 and
  581–614 of 34, with smaller runs and singletons
  between). No same-position act stands past
  position 614 in either context, although both
  contexts run ~750 acts long.
- Shift runs over the shared acts in A-position
  order: under the primary reading (maximal runs of
  consecutive A-positions carrying one constant
  shift) there are 118 runs; their length
  distribution runs from 82 singletons-and-pairs
  (43 of length 1, 39 of length 2) up through one
  run of 158. The longest runs: 158 acts at shift
  +2 over A-positions 26–183; 50 at +2 over
  683–732; 41 at +3 over 457–497; 37 at +2 over
  305–341; 34 at shift 0 over 581–614; 29 at shift
  0 over 242–270. Under the secondary reading
  (maximal runs adjacent in the shared-act A-order
  sequence, ignoring A-position gaps, at one
  constant shift) there are 103 runs, the same
  158-act +2 run longest, then 83 at shift 0 over
  A-positions 524–614 (the dense same-position
  region merged across its gaps), 58 at +2 over
  683–744 and 53 at +3 over 438–497. Every run is
  printed in the run with its A-position range,
  length, shift and first and last acts.

So the re-layout of AES-NUM-136 is not a uniform
slide: most shared acts move by a small constant
offset inside long constant-shift runs, a sixth do
not move at all (and none of those stands in the
last ~135 positions), and a scattered tenth moves
by hundreds of positions. Any deeper relation is
NOT PROVEN.

## (iii) B byte 0 against the six two-byte sub-keys over the full 224-pair population

For each of the six two-byte sub-keys of the A word
over all 224 lane-1 pairs, every key value carried
by more than one pair is printed in full in the run
(A and B words, all four A bytes, B byte 0, status,
difference, group and every record), with its
agreeing / violating verdict (agreeing = one B
byte 0 across the value's pairs; violating = more
than one) and its group composition counted exactly.

- (byte 0, byte 1): 213 distinct values, 10
  repeating — 4 agreeing, 6 violating. The agreeing
  values are (0, 3) -> 0 and (128, 68) -> 128 (both
  wholly in the great group), (20, 1) -> 20 with 3
  pairs {(14, 9992): 1, (19, 7712): 2} and (68, 1)
  -> 68 with 2 pairs {(14, 9992): 1, (19, 7712): 1}.
  The widest violating value here is not wide (all
  2 pairs); among them (32, 1) -> {32, 64} with
  composition {(14, 9992): 1, (20, 32720): 1} is the
  only repeated two-byte value in the whole study
  that both touches the great group and crosses a
  group boundary.
- (byte 0, byte 2): 215 distinct, 8 repeating — 1
  agreeing ((0, 87) -> 128, great group only) and 7
  violating, every repeated value wholly inside the
  great group; the heaviest is (128, 124) with 3
  pairs -> {0, 64, 128}. No cross-group repeat
  exists under this key (as AES-NUM-134 found).
- (byte 0, byte 3): 175 distinct, 35 repeating —
  8 agreeing and 27 violating, the heaviest
  two-byte traffic in the population. Its widest
  values are great-group only: (128, 187) with 6
  pairs -> {0, 128}, (128, 186) with 5 -> {0, 128},
  (128, 209) with 4 -> {0, 128}. Its one cross-group
  repeat is the agreeing (20, 128) -> 20, {(14,
  9992): 1, (19, 7712): 1}.
- (byte 1, byte 2): 220 distinct, 3 repeating — 0
  agreeing, 3 violating: (1, 176) -> {20, 28, 32}
  with 3 pairs {(14, 9992): 2, (19, 7712): 1},
  (1, 178) -> {20, 24} wholly in (14, 9992), and
  (128, 146) -> {128, 160} wholly in the great
  group.
- (byte 1, byte 3): 216 distinct, 4 repeating — 0
  agreeing, 4 violating: (1, 128) -> {20, 24, 28,
  32, 68}, 6 pairs {(14, 9992): 4, (19, 7712): 2},
  the widest cross-group value in the study;
  (1, 0) -> {20, 68} {(14, 9992): 1, (19, 7712): 1};
  and the great-group pair (44, 249) -> {104, 128}
  and (84, 252) -> {8, 120}.
- (byte 2, byte 3): 221 distinct, 3 repeating — 0
  agreeing, 3 violating: (176, 128) -> {28, 32}
  and (178, 128) -> {20, 24}, both wholly in
  (14, 9992), and (181, 249) -> {104, 160} wholly
  in the great group.
- Totals over the six keys (derived at closing):
  63 repeating values, 13 agreeing and 50
  violating. Every key carries at least one
  violating repeat, so B byte 0 is a function of
  NO two-byte sub-key over the full population —
  the per-group verdict of AES-NUM-136 pooled:
  pooling the groups adds the cross-group repeats
  and removes none of the violations. Of the 63
  repeated values, all but seven are wholly inside
  one group (the great group holding the large
  majority); the seven cross-group values are the
  six small-group sharings of AES-NUM-134/135 —
  (20, 1), (68, 1), (20, 128), (1, 176), (1, 0),
  (1, 128) — plus the violating (32, 1), the only
  one that involves the great group.

So the two-byte ladder closes over the full
population the same way it closed inside each
group: repetition exists under every key, agreement
does not survive it anywhere except in isolated
small values. Mechanism NOT PROVEN.

## Next

Slice 4.138 — the two wed redundancies certified
directly (context length and gap-2 left position
each tested as a function of the maximal compound
joint key over the 271 contexts, and the maximal
key wed to BOTH companions together, the whole
tuple likewise); the shift anatomy's long runs read
in full (every run of length ≥ 20 act by act, the
|shift| ≥ 100 tail's acts with their positions in
both contexts, and shift class by A-position band);
and B byte 0 against the six two-byte sub-keys wed
to the group (key = (group, two-byte value)) over
the full 224 pairs, with the 13 agreeing repeats'
status company. Host/artifact analysis only.

Mechanisms NOT PROVEN throughout: no feature or key
tested is claimed to be the mechanism of the gap-2
fill, of the exception contexts' re-layout, or of
the byte-0 rewriting; the grades above are exact
population counts and nothing more.
