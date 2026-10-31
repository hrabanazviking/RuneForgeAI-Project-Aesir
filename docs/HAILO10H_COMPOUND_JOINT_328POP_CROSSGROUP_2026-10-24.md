# Gap 2's chain does not repair under any compound joint key either — wed the first act to the loose order AND a sister gap's whole fill and it still splits (75 distinct compound keys under each sister; position-1 fails 6, position-2 fails 7 under both), and wed it to the loose distances and it still splits, though the distances are the strongest companion yet tested (84 distinct keys; position-1 fails only 3, position-2 only 4 — the widest first act under both its distance pairs, plus one more key each); the whole gap-2 tuple as a function of (position-0, loose order) fails on 9 of 73 keys, the widest carrying 6 tuples under one order. The 19 cross-size offsets' small acts are a population of exactly 19 distinct size-328 acts — one per offset — of which exactly ONE is a gap act (the familiar (120529920, 328, 0), gap-2 position-0 in its 12 contexts), NONE is a class-271, loose or rigid act, and the other 18 are none of those; their 21 partner acts are likewise none of those, every one. And the two-byte cross-group sharings are few and mostly small-group: across all six two-byte sub-keys of the A word, exactly 7 distinct key values are carried by pairs of more than one group (3 under (byte 0, byte 1), 1 under (byte 0, byte 3), 1 under (byte 1, byte 2), 2 under (byte 1, byte 3), none under (byte 0, byte 2) or (byte 2, byte 3)); three of the seven agree on B byte 0 — (20, 1), (68, 1) and (20, 128), all between the two small groups — and four violate, including the only value that touches the great group, (byte 0, byte 1) = (32, 1), whose great-group pair rewrites 32 -> 64 against the small group's 32 -> 32. The agreeing three-byte pair of pairs sits inside that company exactly as its projections predict: it shares the agreeing (20, 1) and (20, 128) values, while its (byte 1, byte 3) = (1, 128) projection is the widest violating value of all (6 pairs, B byte 0 {20, 24, 28, 32, 68}) — mechanisms NOT PROVEN (AES-NUM-134)

Slice 4.134, worked under `docs/TASK_CONTRACT_4.134.md`
(contract published in the 4.133 closing commit @
abb476de). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef134.py (the hef133 file verbatim as base — itself
the hef132/hef131/hef130 lineage — plus the new
arms134) sha256
`48eba70264db9524a8b953209279eadc76c5e24abc01a89d3085b848ffd67458`
(480,815 B); arms134 sha256
`9af0b6bfb8d7463f6b4d639f6b71e67015f6b538992dc24b649a04f34305f776`
(12,024 B), its gzip sha256
`11835af26ee9e6daaf820c9c1324add61017dfaf77a222d339b4a2f1c6b08161`
(3,673 B). The arms were built locally by the
10-minute continuity worker and crossed by the
proxy-upload route (a one-shot on-device receiver
derived on-device from the verified recv133 receiver,
held in the foreground by a worker agent; the
receiver reported SAVED 3673 and the on-device gz
sha256 matched the VM's before assembly); hef134.py
was assembled on-device from the verified hef133 base
(on-device sha256 fdb56f64… == VM) plus the arms, and
the assembled file's sha256 matched the VM's exactly
before the run. The one bounded host-side child was
launched with the contract corpus argv (the six
hailo-ollama blobs in glob order, then MiniLM — the
launch law recorded in the contract) and finished
on-device with an empty error file; DONE134 is the
output's last line. The retrieved output is 25,130
lines / 4,954,396 B, sha256
`241c86e1602a6758dec7e405fd55182c4dd6ac7f827446f2678d8102aee0e2bc`;
retrieved gz sha256
`ade4c82be9f401a60e54a3e1bdc1a1dd46556d1003d397fa3cd78cb77a2a0183`
(526,791 B, fetched through a temporary on-device HTTP
server via the tunnel proxy; the fetched gz sha256
equals the on-device gz sha256 and decompresses to
exactly the output sha256, verified on the VM at
closing); the 4.134 section begins at output line
24,171 — exactly one past 4.133's total line count, and
the first 24,170 lines are byte-identical to hef133.out
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
gap acts distinct 333.

## (i) Gap 2's chain against compound joint keys

All seven tests are computed exactly over the 271 rigid
contexts (271 rows each). Every test prints its distinct
joint keys, its repeating joint keys in full, and every
violating joint key with its alternatives and every
carrying context's full row.

- (position-0, loose order, gap-0 tuple): 75 distinct
  compound keys, 16 repeating. Position-1 is NOT a
  function of it (6 violating keys: (2117242368, 328, 0),
  the widest (33312256, 328, 0) under both its gap-0
  tuples — 2 and 3 alternatives — (900763136, 328, 0),
  (915796480, 328, 0) and (976502784, 328, 0));
  position-2 is NOT a function of it (7 violating: the
  same five position-0 acts, the widest under both
  tuples, plus (1230944256, 328, 0), (1244657152, 328, 0)
  and (1255547392, 328, 0), which fail only at
  position-2 — lists derived at closing from the
  printed violating keys).
- (position-0, loose order, gap-1 tuple): 75 distinct,
  16 repeating — the same counts, and the same
  violating position-0 sets (6 for position-1, 7 for
  position-2, derived likewise). Adding the order to
  a sister joint (AES-NUM-133: 71 distinct, 8 / 9
  violating under either sister alone) refines the
  keys from 71 to 75 and silences exactly two
  position-1 and two position-2 violations, no more.
- (position-0, loose distances (d0, d1)): 84 distinct,
  14 repeating — the most distinct keys of any joint
  tested in this study, and the fewest violations.
  Position-1 NOT a function (3 violating keys:
  (33312256, 328, 0) at distances (1, 3) with 3
  alternatives and at (2, 4) with 2, and (976502784,
  328, 0) at (1, 3) with 2); position-2 NOT a function
  (4 violating: the same three keys with their
  position-2 alternatives, plus (1255547392, 328, 0)
  at (2, 9) with 3).
- Whole gap-2 tuple as a function of (position-0,
  loose order): 73 distinct, 15 repeating, NOT a
  function — 9 violating keys (one fewer than the
  (length, position-0) whole-tuple test's 10 in
  AES-NUM-133). The widest key, (33312256, 328, 0)
  under L1-before-L0, carries 6 distinct tuples; under
  L0-before-L1 it carries 2.

No compound joint key tested repairs the chain. The
distances are the strongest companion yet (3 / 4
violations against 6–10 for every other joint), but
they do not close it; what else varies the fill inside
a (position-0, order, sister-tuple, distances) family
is NOT PROVEN.

## (ii) The 19 cross-size offsets' size-328 acts as a population

The corpus offset index is rebuilt in full (538,233
distinct offsets; 745,849 act occurrences). The census
of AES-NUM-133 is reproduced exactly: 19 offsets
carried by acts of different sizes whose smaller act
is size 328. Every size-328 act and every partner act
on those offsets is read in full in the run (all its
corpus occurrences and contexts, its gap roles, its
class-271 index where it has one, its occurrence
positions).

- The population is exactly 19 distinct size-328
  acts — precisely ONE per offset (derived: every
  census row lists exactly one size-328 act). Their
  occurrence counts run from 1 (nine acts) through
  2, 3, 5, 6 and 7 to 12 and 15; each act's occurrences
  are confined to a single artifact, and 18 of the
  19 stand at a single fixed position in every one
  of their contexts (nine of them trivially, with a
  single occurrence; the sole exception, derived
  from the printed occurrence lists, is
  (791774208, 328, 0) at positions 725 and 727 in
  its two 5ab3537d contexts; the most-repeated act,
  (711228416, 328, 0), is fixed at position 258 in
  all 15 of its contexts). The partner acts, by
  contrast, are not position-fixed where they repeat
  (every twice-occurring partner stands at two
  different positions — derived likewise).
- Membership, counted exactly over the 19: ONE act
  is a gap act — (120529920, 328, 0), gap roles
  {(gap 2, position 0)} only, its 12 gap occurrences
  being all its occurrences. NONE of the 19 is a
  class-271 act (loose 0, rigid 0). The other 18 are
  NEITHER gap nor class-271 acts.
- The partners are 21 distinct acts (17 offsets carry
  one partner, two offsets carry two: 136199680 with
  sizes 30936 and 32016, and 711228416 with size-32784
  acts on channels 0 and 1). Membership over the 21:
  gap 0, class-271 0 — every partner is NEITHER.
  Partner sizes: 32784 ×8 acts, 3088 ×2, and one each
  of 1552, 3272, 5488, 5512, 6008, 10256, 19472,
  25936, 30936, 32016 (derived from the printed rows).

So the cross-size sharing touches the study's named
populations exactly once — at the original target
offset, through its gap act — and nowhere else. The
other 18 sharings join two otherwise unremarkable
populations; any deeper relation is NOT PROVEN.

## (iii) The agreeing repetition against the two-byte cross-group sharings

For each of the six two-byte sub-keys of the A word,
every key value carried by pairs of more than one
group is counted exactly over the full 224-pair
population, its pairs printed in full with records.

- (byte 0, byte 1): 213 distinct values; 3 cross-group
  values, 7 pairs. (20, 1): 3 pairs across groups
  (14, 9992) and (19, 7712), B byte 0 {20} — AGREEING.
  (32, 1): 2 pairs across (14, 9992) and the great
  group (20, 32720), B byte 0 {32, 64} — VIOLATING
  (the small-group pair A 2001b080 -> B 2001b000 keeps
  32; the great-group pair A 2001d3ee -> B 40d078e5
  rewrites 32 -> 64). (68, 1): 2 pairs across the two
  small groups, B byte 0 {68} — AGREEING.
- (byte 0, byte 2): 215 distinct values; NO cross-group
  value at all.
- (byte 0, byte 3): 175 distinct values; 1 cross-group
  value: (20, 128), 2 pairs across the small groups,
  B byte 0 {20} — AGREEING (these are exactly the
  agreeing three-byte pair's two pairs).
- (byte 1, byte 2): 220 distinct values; 1 cross-group
  value: (1, 176), 3 pairs across the small groups,
  B byte 0 {20, 28, 32} — VIOLATING.
- (byte 1, byte 3): 216 distinct values; 2 cross-group
  values, 8 pairs. (1, 0): 2 pairs, B byte 0 {20, 68}
  — VIOLATING. (1, 128): 6 pairs, B byte 0
  {20, 24, 28, 32, 68} — VIOLATING, the widest
  cross-group value under any two-byte key.
- (byte 2, byte 3): 221 distinct values; NO cross-group
  value at all.

Totals (derived): 7 distinct cross-group values and
20 pair-instances over the six keys. Cross-group
sharing never joins the two small groups to each
other AND the great group under one value; the great
group is touched exactly once, by the violating
(32, 1). Every agreeing cross-group value is
small-group-only and byte-1 = 1 with byte 0 in
{20, 68} or byte 3 = 128.

The agreeing (byte 0, byte 3, byte 1) pair of pairs
re-read in that company: A 1401b180 -> B 1401b100
(group (19, 7712), 1 record) and A 1401b280 ->
B 1401b200 (group (14, 9992), 27 records), both SAME
at B byte 0 = 20. Its two-byte projections: (byte 0,
byte 1) = (20, 1) — the agreeing cross-group value
above, carried by exactly one further pair (A
1401b000 -> B 1401b080, group (19, 7712), also 20);
(byte 0, byte 3) = (20, 128) — the agreeing value,
carried by these two pairs alone; (byte 0, byte 2),
(byte 1, byte 2) and (byte 2, byte 3) projections are
not cross-group at all (each value sits in one group);
and (byte 1, byte 3) = (1, 128) — the widest violating
value above, in whose B byte-0 set {20, 24, 28, 32,
68} the agreeing pairs' 20 is only one member. The
three-byte agreement is therefore NOT the shadow of
any two-byte agreement: at two bytes the same pairs
already sit inside a violating crowd, and only the
third byte (byte 3 with byte 0 and byte 1 together)
separates them agreeing. Mechanism NOT PROVEN.

## Next

Slice 4.135 — gap 2's chain against distance-compound
joint keys ((position-0, loose distances, loose
order), (position-0, loose distances, gap-0 tuple),
(position-0, loose distances, gap-1 tuple); the whole
gap-2 tuple as a function of (position-0, loose
distances)); the 19 size-328 acts' occurrence
geometry in full (position constancy, artifact
confinement and cidx pattern per act, the two
position-varying exceptions read in their contexts,
partners likewise); and the cross-group two-byte
values' pair company in full (the further pairs
carrying each agreeing value within its own group,
and whether any three-byte value repeats agreeing
inside a single group when the cross-group condition
is dropped). Host/artifact analysis only.

Mechanisms NOT PROVEN throughout: no feature or key
tested is claimed to be the mechanism of the gap-2
fill, of the cross-size offset sharing, or of the
byte-0 rewriting; the grades above are exact
population counts and nothing more.
