# The two refining joints are one partition, not two — over the 216 violating-cell pairs, (per-record idx sequence, A byte 0) and (per-record (cidx, idx) sequence, A byte 0) key every pair identically, pair by pair (23,220 unordered pair-pairs: both joints equal on 57, both unequal on 23,163, discordant on 0), because on this population each of the 27 idx sequences carries exactly one cidx sequence; their shared verdict stands (167 distinct, 42 repeating, 7 agreeing, 35 violating), and the 7 agreeing repeats are seven keys of exactly two pairs each (14 pairs, B byte 0 sets {128}, {192}, {160}, {192}, {128}, {128}, {128}). Wed further to the pair's single cell, the joint separates everything and therefore proves nothing: 216 distinct keys over 216 pairs, no repeating key at all — vacuous, for both joint forms. The +4 byte-0 step belongs to the one sub-key that omits byte 0: under (byte0, byte1, byte2) and (byte0, byte2, byte3) alone over the full 224 pairs there is no pair-pair at all (224 distinct values each, injective), and under (byte0, byte1, byte3) alone there is exactly one pair-pair, whose A byte-0 difference is 0 — as it must be, since a sub-key containing byte 0 forces byte-0 equality on any two pairs sharing it — with B byte-0 difference 0, B-minus-A (0, 0), and cell thirds differing by 1,952. And the per-gap channel mapping earns nothing from weding the channel tuples to count or to sizes: all five weds, against both the mapping set and the full paired sequence, give the identical verdict (7 distinct, 1 repeating, 1 agreeing, 0 violating), the sole repeat being gaps 5/6 at ((0,1),) — the same single agreeing repeat the channels alone earned in AES-NUM-146/147, no determination claimed — while the joint (A channels, B channels) wed is TAUTOLOGICAL in full: all 8 gaps have equal A/B skipped counts and the zip of its two tuples IS the mapping full sequence at every gap (AES-NUM-148)

Slice 4.148, worked under `docs/TASK_CONTRACT_4.148.md`
(contract published in the 4.147 closing commit @
0d8b633b). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef148.py (hef147.py verbatim as base plus the new
arms148) sha256
`db9f86dea3837a6c60378a668360a0c3b1c6258771724d900a3976c8012e0473`
(695,317 B); arms148 sha256
`aaeb35088fe10580a55809e4cd6238fe652e0a9381a5c4987d9b2936723f97f4`
(18,285 B), its gzip sha256
`2857d46b7a10762ad4c6dcdae6fa74b768c3f5fedc5fb832599d87813e1abf95`
(4,824 B). The arms were built locally by the
10-minute continuity worker on the hef147 lineage
(the contract-named base). The crossing used the
per-part sha-gated route banked in AES-NUM-141…147:
the gzipped arms were split into 440 B parts (11
parts), each part crossed as its own file.write with
its own sha256 gate — all eleven verified on-device
first try. The assembled gzip, arms and hef148
sha256 all matched the VM exactly on-device, and the
script compiled on-device (py_compile OK). Launch
record, stated honestly: a first tmux launch at
13:11 EDT was killed within seconds, before it
produced any output (its output file was 0 bytes),
because its stdout was not redirected to the output
file; it produced no evidence and no result of any
kind was read from it. The contract's ONE bounded
host-side child was then launched properly (runner
script sha256 bd0ca040…, sha-gated, in a detached
tmux session with the contract corpus argv — the six
hailo-ollama blobs in glob order, then MiniLM — the
launch law recorded in the contract). That child
finished with DONE148 as its output's last line, exit
marker 0, and the error channel empty. Its output is
40,629 lines / 7,805,705 B, sha256
`740c0ec253dd22bab53ce02ea6940a550a32192b1b5a30587a0b783d35eccb88`;
the first 40,401 lines are byte-identical to
hef147.out (cmp verified on-device), and the 4.148
section begins at output line 40,402 and is 228
lines / 41,415 B, sha256
`e78c7801f6e9ee1751c6df7a63823a9901eac57dba6c980fe84d93ac2d831c51`
(section gz sha256
`f0e144ac4cfef84b4cfe98f267b03b3c2d91dd7b385904e28f28c4da6256bce1`,
kept on the Pi). Controls reproduce exactly: cells
55,902, observations 527,236, divergent triples
2,171, verdicts CONT 12,411 / BREAK 476 / INDET
2,365; lane-1 pairs 224 with 222 keys under both
control maps; shared single-positioned acts 689,
secondary runs 103, secondary long runs 7, secondary
internal gaps 431; gap controls 34 / 30 / 87; gap
records 8. Raw output kept on the Pi at
~/aesir-build/ (hef148.out, hef148.py, arms148.py,
section148.txt); local lineage in
~/workspace/.verify-tmp/aesir148.

## (i) The two refining joints dissected over the 216

The violating-cell population was re-identified
exactly (8 cells (20, 32720, 6796…7272 step 68), 27
pairs each, 216 pairs; every pair in the population
carries exactly one record and exactly one cell).
Both refining joints reproduce the AES-NUM-147
verdict exactly:

- Joint (per-record idx sequence, A byte 0): 167
  distinct keys, 42 repeating, 7 agreeing, 35
  violating — NOT a function.
- Joint (per-record (cidx, idx) sequence, A byte 0):
  167 distinct, 42 repeating, 7 agreeing, 35
  violating — identical in every count.

The 7 agreeing repeats of (idx sequence, A byte 0),
in full (each key holds exactly 2 pairs, 14 pairs in
all):

- ((11,), 128) → B byte 0 {128}: A 807a78d2 →
  B 80acbfc7 (cell (20, 32720, 6864), cidx 35) and
  A 808e20bb → B 802972b3 (cell (20, 32720, 6796),
  cidx 35).
- ((13,), 64) → {192}: A 4092dbce → B c07abac4
  (cell 6864, cidx 41) and A 40da3fde → B c0374bd3
  (cell 6932, cidx 41).
- ((16,), 112) → {160}: A 705ab5f9 → B a08de5f4
  (cell 7272, cidx 50) and A 706510f7 → B a0944ff1
  (cell 7204, cidx 50).
- ((16,), 64) → {192}: A 4002a3db → B c01101d3
  (cell 6932, cidx 50) and A 40c365e6 → B c001fddd
  (cell 7000, cidx 50).
- ((2,), 128) → {128}: A 8044b1bb → B 80c569ba
  (cell 6796, cidx 8) and A 80a3bfec → B 80f043eb
  (cell 7000, cidx 8).
- ((26,), 64) → {128}: A 4096f5d8 → B 8074f4da
  (cell 7000, cidx 80, poscat 'last') and
  A 40f019ce → B 80d906d0 (cell 6932, cidx 80,
  poscat 'last').
- ((9,), 128) → {128}: A 80339bba → B 805014b6
  (cell 6796, cidx 29) and A 807fc7d1 → B 805b8dcb
  (cell 6864, cidx 29).

Every agreeing repeat's two pairs live in different
cells (derived count from the run's printed records).
The 35 violating repeats hold 77 pairs between them
(B byte 0 sets of size 2 in 32 keys, size 3 in 3 keys
— ((18,), 128) → {0, 48, 64}, ((4,), 192) →
{64, 96, 128}, ((8,), 128) → {0, 128, 208}, the last
holding 4 pairs; derived counts).

Pair-by-pair identity of the two joints: the two
partitions of the 216 are IDENTICAL, not merely
equal in aggregate. Each of the 167 joint-1 groups
maps to exactly one joint-2 group and vice versa
(167 / 167, zero splits either way); over all
23,220 unordered pair-pairs of the population, both
joints are equal on 57, both unequal on 23,163, and
discordant (equal under one joint only) on 0. The
mechanism is visible in the run's own tables: the
population carries 27 distinct idx sequences and 27
distinct cidx sequences, and no idx sequence carries
more than one cidx sequence — on this population the
cidx sequence is a function of the idx sequence, so
wedging it in adds no information. (Each pair here
carries one record, so both sequences are
singletons; the identity is a property of this
population, not a corpus law.)

B byte 0 as a function of (idx sequence, A byte 0)
wed further to the cell (the pair's single cell —
all 216 pairs carry exactly one): 216 distinct keys,
0 repeating, 0 agreeing, 0 violating — VACUOUS. The
(cidx, idx) form of the wed gives the identical
216 / 0 / 0 / 0. The cell separates every repeated
joint key (no joint repeat lives inside one cell),
so the wedded key never repeats and no determination
is earned or refuted by it.

## (ii) The +4 step under the other three sub-keys alone

Grouping all 224 pairs by each remaining three-byte
sub-key of the A word alone (any status, group or
record count):

- (byte0, byte1, byte2): 224 distinct values, 0
  multi-pair groups, 0 pair-pairs — the sub-key is
  injective over the full 224 on its own.
- (byte0, byte2, byte3): 224 distinct values, 0
  multi-pair groups, 0 pair-pairs — likewise
  injective.
- (byte0, byte1, byte3): 223 distinct values, 1
  multi-pair group, exactly 1 pair-pair: sub-key
  (20, 1, 128) is shared by A 1401b180 → B 1401b100
  (byte 0 20, SAME, group (19, 7712), 1 record, cell
  (19, 7712, 2384)) and A 1401b280 → B 1401b200
  (byte 0 20, SAME, group (14, 9992), 27 records,
  cell (14, 9992, 4336)). A byte-0 difference 0,
  B byte-0 difference 0, B-minus-A byte-0 differences
  (0, 0), cell-third difference 1,952.
  Distributions over the sub-key's pair-pairs: A
  byte-0 difference {0: 1}; (A difference,
  cell-third difference) {(0, 1952): 1}.

So the +4 step occurs under NONE of the other three
sub-keys: two admit no pair-pair at all, and the
one pair-pair the third admits has step 0. That 0
is forced, and the forcing is recorded as such: any
sub-key containing byte 0 makes byte 0 equal across
any two pairs sharing it, so a +4 A byte-0 difference
is impossible under all three of these sub-keys by
construction. The (byte1, byte2, byte3) sub-key of
AES-NUM-147 is the only three-byte sub-key that
omits byte 0, and it remains the step's whole
measured home (2 pair-pairs, both +4). Whether the
step is a law beyond those two pair-pairs is NOT
PROVEN.

## (iii) The channel tuples wed to count and to sizes

All eight gaps were printed in full (run, step,
skipped acts on both sides, mapping set and paired
sequence). Each wed was tested as a determinant of
both the mapping set and the full paired sequence,
counted exactly over the 8 gaps; the two targets
give identical verdicts for every wed:

- (A channels tuple, A count): 7 distinct keys, 1
  repeating, 1 agreeing, 0 violating — the key
  ((0,), 1) repeats only at gaps 5 and 6, both
  ((0,1),).
- (B channels tuple, B count): 7 distinct, 1
  repeating, 1 agreeing, 0 violating — the key
  ((1,), 1) at gaps 5 and 6.
- (A channels tuple, A sizes tuple): 7 distinct, 1
  repeating, 1 agreeing, 0 violating — the key
  ((0,), (32784,)) at gaps 5 and 6.
- (B channels tuple, B sizes tuple): 7 distinct, 1
  repeating, 1 agreeing, 0 violating — the key
  ((1,), (32784,)) at gaps 5 and 6.
- Joint (A channels tuple, B channels tuple): 7
  distinct, 1 repeating, 1 agreeing, 0 violating —
  the key ((0,), (1,)) at gaps 5 and 6.

Every wed reproduces exactly the channels-alone
verdict of AES-NUM-146/147 (same distinct count,
same sole agreeing repeat at the same two gaps):
wedging in count or sizes adds no new repeat and no
violation, and a single agreeing repeat on eight
gaps earns no determination for any of them.

Target-containment, recorded as the contract
requires: the joint channel wed's value at each gap,
zipped in order, IS the mapping's full paired
sequence — not merely where lengths are equal in
principle, but at all 8 gaps in fact (every gap has
equal A/B skipped counts, lengths 2 / 5 / 1 / 4 / 1 /
1 / 1 / 4, and zip(A channels, B channels) equals the
mapping full sequence at every gap, verified in the
run). Its agreeing verdict against the full-sequence
target is therefore TAUTOLOGICAL, as in AES-NUM-147,
and against the set target it likewise contains
every paired channel in the mapping.

## Next

Slice 4.149 — the 7 agreeing repeats read record by
record (each repeat's two pairs compared field by
field: what, beyond the shared joint key, the two
pairs share and where they differ); the near-miss
census for the two injective sub-keys (pair-pairs
whose (byte0, byte1, byte2) / (byte0, byte2, byte3)
values differ in exactly one byte, with their byte-0
steps); gaps 5 and 6 read in full against each other
(the sole agreeing repeat of every mapping test
since AES-NUM-144), with the same feature-table
treatment gaps 3/7 received in AES-NUM-145.
Host/artifact analysis only — no physical child.
