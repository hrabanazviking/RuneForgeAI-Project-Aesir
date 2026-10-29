# The agreeing profile inside violating repeats is the verdict fields agreeing locally — the 3 control comparisons with the agreeing (12, 7) profile are exactly the pair-pairs inside violating repeats 3, 18 and 35 whose two pairs agree on B byte 0 and status, and in all 3 their differing seven fields are name-for-name the agreeing seven (A byte1, A byte2, A byte3, B byte1, B byte2, B byte3, record cell): each repeat is carried violating by its other pairs (repeat 3's third pair carries B byte 0 64 against 0/0; repeat 18's third pair carries B byte 0 160 and status DIFF against 128/SAME; repeat 35's first and third pairs carry B byte 0 0 and 208 against the control pair-pair's 128/128). The 8 byte-0-differing near-miss listings are 6 distinct pair-pairs, not 8: exactly 2 pair-pairs are counted under both injective sub-keys (the (20,178)→(24,178) and (28,176)→(32,176) ladder steps), so the listings share 5 individual pairs and cover 9 distinct pairs in 16 slots. The +4 listings (4, two distinct pair-pairs counted twice) agree with each other on every printed field the non-+4 listings do not share as a set: both pairs in group (14, 9992), B byte-0 step +4, B-minus-A (0, 0), statuses SAME/SAME, cell-third differences {5200, 5496}; the non-+4 listings split — steps 8 and 12 in the (19, 7712)/(14, 9992) groups also carry B-minus-A (0, 0) and SAME/SAME, while step 64 (group (20, 32720)) steps B by −32 with B-minus-A (32, −64) and step 8 under the second sub-key (group (20, 32720)) steps B by +56 with B-minus-A (0, 48) — so no field separates +4 from all the rest short of the B step itself, which is +4 by the group's definition on the A side and measured +4 on the B side. Gap 4 is gaps 5/6's sibling at distance: same run 74, shift 0, length 83, extents 524–614, mapping set ((0, 1),), and the same 10 of 32 features equal against each of gaps 5 and 6 (22 differing); what makes its skipped block four long is measured act by act — between its bounds (positions 556 and 561, distance 5) sit four consecutive acts at identical offsets on both sides (788585984, 788618768, 788644896, 788677680; sizes alternating 32784, 26128, 32784, 26128; offsets advancing exactly by the preceding size) that are channel 0 in context A and channel 1 in context B, pairing 1-to-1 into the mapping (0, 1) four times, where gaps 5 and 6 enclose exactly one such act (distance 2). Mechanisms NOT PROVEN (AES-NUM-150)

Slice 4.150, worked under `docs/TASK_CONTRACT_4.150.md`
(contract published in the 4.149 closing commit @
319e93f7). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef150.py (hef149.py verbatim as base plus the new
arms150) in its final patched form sha256
`51a5246c6652ca2710cdfcf1b85df02cf39dd2b1bcb1b82362ca086433a46cbd`
(726,561 B); arms150 sha256
`9df8855cf1cf0238f43796143e4b7fba606ed998b9ae43725b1e7c53e2b34d2a`
(13,863 B), its gzip sha256
`1dd2bba6b28e626770bf572b415981f3220454b95e2dd62a881569536c53e934`.
The arms were built locally by the 10-minute
continuity worker on the hef149 lineage (the
contract-named base). The crossing record is stated
honestly: the banked per-part sha-gated file.write
route landed the first four 440 B gz parts sha-clean,
then repeatedly corrupted later parts in re-emission
(two parts failed with base64 padding errors and were
never committed; a 220 B re-split of the tail failed
the same way on its first part). The crossing was
completed by the banked proxy-upload pattern instead:
a tiny one-shot receiver script (sha256 bd8fac56…,
verified byte-exact on-device) held on the Pi by a
subagent while the gzipped arms were POSTed from the
VM through the tunnel proxy — the Pi's returned
sha256 matched the VM's gzip exactly, for both the
original arms and the patched arms. Assembled arms
and hef150 sha256 matched the VM exactly on-device in
both builds, and the script compiled on-device
(py_compile OK).

Launch record, stated honestly: the sha-gated runner
script (sha256
`3dde7475d8d43de7d890f7c1fcd7956317a24df19b626134abcbdd49c8148c4c`)
was first launched through a backgrounded invoke,
which the node session teardown killed after partial
output (650,863 B, no exit marker, nothing read from
it as evidence; the partial file was discarded). The
contract's bounded host-side child was then launched
in a detached tmux session with the contract corpus
argv — the six hailo-ollama blobs in glob order, then
MiniLM — the launch law recorded in the contract.
That first completed launch (arms sha256 acde800f…)
crashed in arm (ii) after the controls, arm (i) and
the near-miss listings had printed: a parenthesis
bug in the +4-group summary print (`sorted(set(…))`
misplaced a closing parenthesis around a generator,
raising `TypeError: 'int' object is not iterable`;
error channel 1,001 B, exit marker 1). Under the
AES-NUM-105 precedent (one-line patch, full rerun,
on-device diff), the summary was patched to a named
helper (arms sha256 9df8855c… above), the full child
was rerun once, and it finished with DONE150 as its
output's last line, exit marker 0, and the error
channel empty. The rerun's output is 41,723 lines /
8,037,604 B, sha256
`96e420d1a81e17f34f29b4436030519f6bfe55d7c216fe1bd9b862593395dbb4`;
the first 41,521 lines are byte-identical to
hef149.out (cmp verified on-device; line 41,522 of
hef149.out is its DONE149 line, where the 4.150 arms
begin), and the rerun's 4.150 section agrees with the
crashed run's section on its first 92 lines except
line 90, where the overlap dict's frozenset keys print
in the other element order — the same two pair-pairs
with the same sub-key listings, a rendering order
only. The 4.150 section is 202 lines / 43,544 B,
sha256
`7656dae225edef5de30125029ee3435888114ce66e54691e29ffe2e46dc1a48b`
(section gz sha256
`30a9946b189154524590a6da43a2671224684256ee10a508dade0f207eb2a299`,
kept on the Pi; the section's return crossing was a
single device file.read, decoded on the VM to exactly
the on-device sha256). Controls reproduce exactly:
cells 55,902, observations 527,236, divergent triples
2,171, verdicts CONT 12,411 / BREAK 476 / INDET 2,365;
lane-1 pairs 224 with 222 keys under both control
maps; shared single-positioned acts 689, secondary
runs 103, secondary long runs 7, secondary internal
gaps 431; gap controls 34 / 30 / 87; gap records 8;
violating-cell population 216 with 7 agreeing and 35
violating repeats reproduced from the 4.148 arms; the
4.149 arms' agreeing comparisons reproduce as seven
(12, 7) and their violating control pair-pairs as 50.
Raw output kept on the Pi at ~/aesir-build/
(hef150.out, hef150_run1.out, hef150.py, arms150.py,
section150.txt); local lineage in
~/workspace/.verify-tmp/aesir150. One printed field
is NOT used as evidence: the +4-group summary's
"shared other sub-key bytes" entry flattened each
member's byte set and kept only the last member per
sub-key, so it does not state what its label claims;
the +4 contrast below is read from the full
pair-by-pair prints instead, which are complete.

## (i) The 3 agreeing-profile controls, in full

Exactly 3 of the 50 control comparisons carry the
(12, 7) profile (expectation 3, from AES-NUM-149's
distribution {7: 3, 9: 29, 10: 18}):

- Violating repeat 3, pair-pair 1–2 (repeat key
  ((10,), 128)): A 800284ba → B 009519b5 (B byte 0 0,
  status DIFF, diff −128, group (20, 32720), cell
  (20, 32720, 6796)) against A 8096a8d1 → B 003427ca
  (B byte 0 0, status DIFF, diff −128, same group,
  cell (20, 32720, 6864)).
- Violating repeat 18, pair-pair 1–2 (repeat key
  ((20,), 128)): A 800c7cbb → B 80dc71ba (B byte 0
  128, status SAME, diff 0, group (20, 32720), cell
  (20, 32720, 6796)) against A 8020f1d2 → B 805d90d1
  (B byte 0 128, status SAME, diff 0, same group,
  cell (20, 32720, 6864)).
- Violating repeat 35, pair-pair 2–4 (repeat key
  ((8,), 128)): A 806092d1 → B 8047b6c9 (B byte 0
  128, status SAME, diff 0, group (20, 32720), cell
  (20, 32720, 6864)) against A 80a801e1 → B 80ddcfd8
  (B byte 0 128, status SAME, diff 0, same group,
  cell (20, 32720, 6932)).

In all 3, the equal twelve fields are the agreeing
twelve (A byte 0, B byte 0, status, diff, group,
record count, record cidx, record idx, record n,
record centre, record poscat, record in37) and the
differing seven are name-for-name the agreeing seven:
A byte1, A byte2, A byte3, B byte1, B byte2, B byte3,
record cell — the identical set in all 3, stated
exactly. No field trades place: an agreeing-profile
comparison inside a violating repeat is field-for-field
indistinguishable from an agreeing repeat's comparison.

What makes each host repeat violating is its sibling
comparisons, stated from the numbers. Repeat 3's
pairs carry B byte 0 values [0, 0, 64], all status
DIFF: the control pair-pair's two pairs agree on B
byte 0 (and trivially on status), while both sibling
comparisons against the third pair differ on B byte 0
and diff (profiles (10, 9) and (10, 9)). Repeat 18's
pairs carry B byte 0 [128, 128, 160] and statuses
[SAME, SAME, DIFF]: both siblings differ on B byte 0,
diff and status (profiles (9, 10) and (9, 10)).
Repeat 35's four pairs carry B byte 0 [0, 128, 208,
128] and statuses [DIFF, SAME, DIFF, SAME]: the
control pair-pair (2–4) is the one pair-pair whose
members agree on both verdict fields; all five of
its siblings differ on B byte 0 (the repeat's B
byte-0 values are [0, 128, 208, 128], so every
sibling pairs two different values), with profiles
(9, 10) / (10, 9) as printed in the section. So a violating repeat can
hold an agreeing-profile comparison exactly when two
of its pairs agree locally on the verdict fields
while a further pair breaks the repeat-wide agreement
— the profile is a property of a pair-pair, the
verdict a property of the whole repeat. Mechanisms
NOT PROVEN.

## (ii) The 8 byte-0-differing near-miss listings against each other

The listings, in full (sub-key, sub-key values,
A byte-0 step, B byte-0 step, B-minus-A pair, cells,
cell-third difference):

1. (byte0, byte1, byte2), (20, 1, 176) vs (28, 1, 176);
   step +8, B step +8, (0, 0); cells (19, 7712, 7568) /
   (14, 9992, 1744); cell-third −5824. Pairs
   1401b000 → 1401b080 (group (19, 7712), 1 record)
   and 1c01b080 → 1c01b000 (group (14, 9992), 27 records).
2. (byte0, byte1, byte2), (20, 1, 176) vs (32, 1, 176);
   step +12, B step +12, (0, 0); cells (19, 7712, 7568) /
   (14, 9992, 6944); cell-third −624. First pair as in
   listing 1; second 2001b080 → 2001b000 (group
   (14, 9992), 27 records).
3. (byte0, byte1, byte2), (20, 1, 178) vs (24, 1, 178);
   step +4, B step +4, (0, 0); cells (14, 9992, 4336) /
   (14, 9992, 9832); cell-third +5496. Pairs
   1401b280 → 1401b200 and 1801b280 → 1801b200, both
   group (14, 9992), 27 records each.
4. (byte0, byte1, byte2), (28, 1, 176) vs (32, 1, 176);
   step +4, B step +4, (0, 0); cells (14, 9992, 1744) /
   (14, 9992, 6944); cell-third +5200. Pairs
   1c01b080 → 1c01b000 and 2001b080 → 2001b000, both
   group (14, 9992), 27 records each.
5. (byte0, byte1, byte2), (128, 128, 146) vs
   (192, 128, 146); step +64, B step −32, (32, −64);
   cells (20, 32720, 7136) / (20, 32720, 7000);
   cell-third −136. Pairs 808092f7 → a071c6f6 and
   c08092da → 80a1f7dd, both group (20, 32720),
   1 record each, both status DIFF.
6. (byte0, byte2, byte3) — the same pair-pair as
   listing 3, counted again: (20, 178, 128) vs
   (24, 178, 128), step +4.
7. (byte0, byte2, byte3) — the same pair-pair as
   listing 4, counted again: (28, 176, 128) vs
   (32, 176, 128), step +4.
8. (byte0, byte2, byte3), (104, 181, 249) vs
   (112, 181, 249); step +8, B step +56, (0, 48);
   cells (20, 32720, 7204) / (20, 32720, 7272);
   cell-third +68. Pairs 682cb5f9 → 6884f5f8 (status
   SAME) and 705ab5f9 → a08de5f4 (status DIFF), both
   group (20, 32720), 1 record each.

Step distribution over the 8 listings {4: 4, 8: 2,
12: 1, 64: 1}; by sub-key {4: 2, 8: 1, 12: 1, 64: 1}
and {4: 2, 8: 1}. B byte-0 step distribution
{−32: 1, 4: 4, 8: 1, 12: 1, 56: 1}; B-minus-A pairs
{(0, 0): 6, (0, 48): 1, (32, −64): 1}.

Overlap, stated exactly: 2 of the 8 listings are the
same pair-pair counted under both sub-keys (listings
3 = 6 and 4 = 7), so the 8 listings are 6 distinct
pair-pairs. Five individual pairs appear in more than
one listing (the (19, 7712) pair in listings 1–2; the
three ladder pairs of listings 3/4/6/7; counts 2, 3,
3, 2, 2 as printed), and the 16 pair slots hold 9
distinct pairs.

The +4 cases against the rest, on every printed
field: the +4 listings are 2 distinct pair-pairs
(the ladder steps (20, 178)→(24, 178) and
(28, 176)→(32, 176)), and in both, both pairs sit in
group (14, 9992) with 27 records each, both statuses
are SAME, B-minus-A is (0, 0), the B byte-0 step
equals the A step +4, and the cell-third differences
are 5496 and 5200. The non-+4 listings do not share
that set: listings 1 and 2 (steps +8, +12) also carry
B-minus-A (0, 0), SAME statuses and B steps equal to
their A steps, but their pairs split across groups
(19, 7712) and (14, 9992) with record counts 1 and
27, and their cell-third differences are −5824 and
−624; listing 5 (step +64) and listing 8 (step +8,
second sub-key) sit in group (20, 32720) with 1
record a pair, and there the B step does not follow
the A step at all (−32 against +64; +56 against +8,
B-minus-A (32, −64) and (0, 48)). So the fields on
which the +4 pair-pairs agree with each other and
differ from every non-+4 listing are: both pairs in
group (14, 9992), and cell-third difference in
{5200, 5496} against {−5824, −624, −136, 68}. Every
other candidate separator fails on listings 1–2,
which share the +4 pair-pairs' verdict pattern
(B-minus-A (0, 0), B step = A step, SAME/SAME) at
steps 8 and 12. The B byte-0 step being +4 for the
+4 group is measured, not definitional — the group
is defined by the A step — but it is shared with the
step-8 and step-12 listings in kind (B step = A
step), so no +4-specific B law is earned. Mechanisms
NOT PROVEN.

## (iii) Gap 4 in full, against gaps 5 and 6

Gap 4 in the AES-NUM-145 form: secondary run 74,
step 31, run shift 0, run length 83, run extents
positions 524–614 in both contexts. Bounding acts
identical in both contexts: LEFT (788559392, 26128,
0) at position 556, RIGHT (788704256, 1552, 2) at
position 561; shifts 0/0; distances A 5, B 5.
Skipped acts, paired in order (offset diff B−A 0 in
all four):

| # | offset | size | A channel | B channel |
|---|--------|------|-----------|-----------|
| 0 | 788585984 | 32784 | 0 | 1 |
| 1 | 788618768 | 26128 | 0 | 1 |
| 2 | 788644896 | 32784 | 0 | 1 |
| 3 | 788677680 | 26128 | 0 | 1 |

Channel mapping set ((0, 1),); mapping full
((0, 1), (0, 1), (0, 1), (0, 1)).

The 32-feature tables read identically against both
siblings: gap 4 vs gap 5 = 10 equal / 22 differing;
gap 4 vs gap 6 = 10 equal / 22 differing. The equal
ten are the same in both tables: run, run shift, run
length, run A first/last positions, run B first/last
positions, left shift, right shift, and the channel
mapping set. Against the 19 features gaps 5 and 6
share with each other (AES-NUM-149), gap 4 agrees
with the shared value on 10 and differs on 9 — the
nine being the two gap distances (5 against 2), the
two skipped counts (4 against 1), the two skipped
size tuples, the two skipped channel tuples, and the
mapping full sequence.

What makes the block four long, stated from the
numbers: gap 4's four skipped acts are consecutive
acts of both contexts (positions 557–560) at
identical offsets, with sizes alternating 32784,
26128, 32784, 26128 and each successive offset
advancing by exactly the preceding act's size
(788585984 + 32784 = 788618768; + 26128 = 788644896;
+ 32784 = 788677680) — one unbroken (offset, size)
chain carried on channel 0 in context A and channel
1 in context B, so each of its four acts pairs into
the mapping (0, 1) and the full sequence is four
long. Gaps 5 and 6 enclose exactly one act of that
same form (a single 32784 act, channels (0,) / (1,)),
their bounds 2 apart where gap 4's are 5 apart; the
block length is the distance minus one in all three
gaps, and the mapping full sequence repeats once per
skipped act. Nothing upstream of the bounds
themselves is measured to decide where a run's
bounds fall; why these bounds enclose four chained
acts here and one there is NOT PROVEN.

## Next

Slice 4.151 — the 6 distinct byte-0 near-miss
pair-pairs as one population (the (14, 9992) ladder
chain at A byte 0 20/24/28/32 read against the full
224: every pair sharing (byte1, byte3) = (1, 128),
its A and B byte-0 sets and cells); the 50 control
comparisons decomposed by verdict-field pattern
(B byte 0 only / status only / both / neither —
neither is the 3 of this slice; the decomposition
stated exactly, status-only tested, not assumed);
and run 74's internal gaps read as one sequence
(steps 31, 33, 37 = gaps 4, 5, 6 in order: bounds,
distances and skipped blocks in sequence, the
contiguity of each gap's skipped block measured —
offset advance against preceding size — over all 8
gaps). Host/artifact analysis only — no physical
child.
