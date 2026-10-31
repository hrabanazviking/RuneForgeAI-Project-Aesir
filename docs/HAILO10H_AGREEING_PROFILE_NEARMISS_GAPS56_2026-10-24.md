# The agreeing repeats are a fixed profile, not a resemblance — all seven of the refining joints' agreeing repeats compare exactly 12 equal / 7 differing over the same 19 fields, and the 7 differing fields are the same seven every time (A byte1, A byte2, A byte3, B byte1, B byte2, B byte3, and the record cell): an agreeing repeat's two pairs agree on everything the joint keys on and everything structural (A byte 0, B byte 0, status, diff, group, record count, and the record's cidx, idx, n, centre, poscat and in37) and differ on everything else. The 35 violating repeats as control (50 unordered pair-pairs) differ more on average (mean 9.24 differing fields against the agreeing 7.0; distributions {7: 3, 9: 29, 10: 18} against a single point at 7), and their extra differing fields are exactly the verdict fields: B byte 0 differs in 47 of 50 control comparisons and the diff in the same 47, status in 18 — while A bytes 1–3, B bytes 1–3 and the record cell differ in all 50, as they do in all 7 agreeing. Exactly 3 control comparisons carry the agreeing (12, 7) profile and B byte 0 equal — they sit inside repeats carried violating by their sibling comparisons. The near-miss census for the two injective sub-keys: (byte0, byte1, byte2) admits 27 Hamming-1 pair-pairs of 24,976 (5 differing at byte 0, 10 at byte 1, 12 at byte 2) and (byte0, byte2, byte3) admits 86 (3 at byte 0, 73 at byte 2, 10 at byte 3); a near-miss differing anywhere but byte 0 has A byte-0 difference 0 by construction (the sub-keys contain byte 0), and the byte-0-differing near-misses — the only informative ones — step by {4: 2, 8: 1, 12: 1, 64: 1} under the first sub-key and {4: 2, 8: 1} under the second: +4 occurs, but beside 8, 12 and 64, so no +4 near-miss law is earned. Gaps 5 and 6 are the same gap twice over at their bounds, like gaps 3 and 7 before them: same secondary run 74, shift 0, run length 83, run extents 524–614 in both contexts, distances 2/2, shifts 0/0, one skipped act a side of size 32,784, skipped channels A (0,) and B (1,), mapping ((0, 1),) in both; the 32-feature table reads 19 equal / 13 differing and every differing feature is a location (step 33 vs 37, positions 562/564 vs 567/569), an identity (the bounding acts), or a skipped-act offset. No feature the two gaps share determines their mapping: every shared bounding-side, run, distance, count and size feature is violated over all 8 gaps (its 5/6 value is carried by gaps 3, 4 and/or 7 under other mappings), and the only shared features whose 5/6 value isolates exactly {5, 6} are the skipped channels themselves — components of the mapping, not determinants of it; the mapping-as-feature rows are the target restated (AES-NUM-149)

Slice 4.149, worked under `docs/TASK_CONTRACT_4.149.md`
(contract published in the 4.148 closing commit @
596a739b). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef149.py (hef148.py verbatim as base plus the new
arms149) sha256
`cae5659d59621842df6daa3a6c6119a2da22004862f280377739b8d56421accf`
(712,714 B); arms149 sha256
`1aee398315e7f1d7caae426476707f9e4db4511eaec5dcc46eaaecf72e339ce7`
(17,397 B), its gzip sha256
`16bd8704f0068c8551d3fe3a6a01c9db93a4dbf0ef478ddcd5e5bb7a97ed4b12`
(4,845 B). The arms were built locally by the
10-minute continuity worker on the hef148 lineage
(the contract-named base). The crossing used the
per-part sha-gated route banked in AES-NUM-141…148:
the gzipped arms were split into 440 B parts (12
parts), each part crossed as its own file.write with
its own sha256 gate — all twelve verified on-device
first try. (Three first attempts were addressed to a
wrong absolute home path and were refused
permission-denied with nothing written; the correct
device home was confirmed by a device status read
and every part then landed sha-clean.) The assembled
gzip, arms and hef149 sha256 all matched the VM
exactly on-device, and the script compiled on-device
(py_compile OK). The contract's ONE bounded
host-side child was launched via the sha-gated
runner script (sha256
`b9ed7f2746ea38603e692827127803adb4f1f4bd23a512d2b61bd2c25c9c3516`;
a first hand-typed copy of the runner failed its
sha gate against the locally built file and was
discarded unwritten-to — the verified file was
crossed instead) in a detached tmux session with the
contract corpus argv — the six hailo-ollama blobs in
glob order, then MiniLM — the launch law recorded in
the contract. That child finished with DONE149 as
its output's last line, exit marker 0, and the error
channel empty. Its output is 41,522 lines /
7,994,068 B, sha256
`0ef6271abc625fec01697042b6591923dc3298ce09497cbda96b53a06d5a8538`;
the first 40,629 lines are byte-identical to
hef148.out (cmp verified on-device), and the 4.149
section begins at output line 40,630 and is 893
lines / 188,363 B, sha256
`36258012aea77bd9d4cc5210cd050b0433a4b018ca907cce943fde7eb3b9bacf`
(section gz sha256
`994280cf7eb2e7e272b8e5e8ba0c0cb83a2fac6a14e792450722d2eb2c7b6744`,
kept on the Pi; the section's return crossing is
recorded honestly: a first whole-file base64 read
was corrupted in re-emission and failed its sha256
check on the VM, was discarded, and the section then
crossed byte-exact through a time-boxed on-device
HTTP server and the tunnel proxy, its sha256
matching the Pi's exactly). Controls reproduce
exactly: cells 55,902, observations 527,236,
divergent triples 2,171, verdicts CONT 12,411 /
BREAK 476 / INDET 2,365; lane-1 pairs 224 with 222
keys under both control maps; shared
single-positioned acts 689, secondary runs 103,
secondary long runs 7, secondary internal gaps 431;
gap controls 34 / 30 / 87; gap records 8;
violating-cell population 216 with 7 agreeing and
35 violating repeats reproduced from the 4.148 arms;
every one of the 216 pairs carries exactly 1 record.
Raw output kept on the Pi at ~/aesir-build/
(hef149.out, hef149.py, arms149.py, section149.txt);
local lineage in ~/workspace/.verify-tmp/aesir149.

## (i) The 7 agreeing repeats, field by field

The comparison population is the 19 fields the
contract names: A bytes 0–3, B bytes 0–3, status,
diff (B byte 0 − A byte 0), group, record count, and
the single record's cell, cidx, idx, n, centre,
poscat and in37 (the run confirms all 216
violating-cell pairs carry exactly one record, so
the record fields are single-valued throughout).

Every agreeing repeat scores identically: **12
equal / 7 differing**, per-repeat list
[(12, 7) ×7]. The equal fields are the same twelve
in all seven: A byte 0, B byte 0, status, diff,
group, record count, record cidx, record idx,
record n, record centre, record poscat, record
in37. The differing fields are the same seven in
all seven (differing-field name counts over the 7
comparisons: A byte1 7, A byte2 7, A byte3 7,
B byte1 7, B byte2 7, B byte3 7, record cell 7) —
that is, the two pairs of an agreeing repeat are
identical on the joint's own key (idx sequence and
A byte 0), on the verdict (B byte 0, status, diff),
and on every record field except the cell itself,
whose third component separates them (AES-NUM-148:
every agreeing repeat's pairs live in different
cells); they differ on all six non-keyed word bytes.

The control population — the 35 violating repeats,
all 50 unordered pair-pairs inside them — differs
strictly more: differing-count distribution
{7: 3, 9: 29, 10: 18}, equal-count distribution
{12: 3, 10: 29, 9: 18}; totals 488 equal / 462
differing against the agreeing 84 / 49; means 9.24
differing per comparison against 7.0, 9.76 equal
against 12.0. The differing-field name counts over
the 50 control comparisons: A byte1 50, A byte2 50,
A byte3 50, B byte1 50, B byte2 50, B byte3 50,
record cell 50 (the universal seven, exactly as in
the agreeing comparisons), plus B byte0 47, diff
47, status 18. So the control's excess difference
is concentrated in the verdict fields themselves:
in 47 of 50 control comparisons the two pairs
disagree on B byte 0 (and therefore on the diff),
and in 18 on status. The remaining 3 control
comparisons have B byte 0 equal and carry the
agreeing (12, 7) profile exactly — they are
pair-pairs inside repeats whose other pair-pairs
violate, so the repeat is violating while this
comparison is not (derived at closing from the
run's printed distributions and name counts, which
agree: 50 − 47 = 3 and the (12, 7) count is 3).

Measured statement: over this population, an
agreeing repeat is not "two similar pairs" — it is
two pairs equal on the key, the verdict and the
record-minus-cell, and different on every non-keyed
word byte and the cell. Any mechanism NOT PROVEN.

## (ii) Near-miss census for the two injective sub-keys

Both sub-keys reproduce injective over the full
224: 224 distinct values each. Hamming-1 near-miss
pair-pairs (sub-key values differing in exactly one
byte position), of 24,976 unordered pair-pairs:

- (byte0, byte1, byte2): **27 near-misses** — by
  differing position: byte0 5, byte1 10, byte2 12.
  A byte-0 difference distribution split by
  differing position: byte0 {4: 2, 8: 1, 12: 1,
  64: 1}; byte1 {0: 10}; byte2 {0: 12}; all
  near-misses {0: 22, 4: 2, 8: 1, 12: 1, 64: 1}.
- (byte0, byte2, byte3): **86 near-misses** — by
  differing position: byte0 3, byte2 73, byte3 10.
  A byte-0 difference distribution split by
  differing position: byte0 {4: 2, 8: 1}; byte2
  {0: 73}; byte3 {0: 10}; all near-misses
  {0: 83, 4: 2, 8: 1}.

The zero rows are forced, and are recorded as
such: both sub-keys contain byte 0, so a near-miss
differing at any other position has byte 0 equal
and its A byte-0 difference is 0 by construction.
The informative population is the byte-0-differing
near-misses: 5 under the first sub-key and 3 under
the second, 8 in all. Their A byte-0 steps are
{4, 4, 8, 12, 64} and {4, 4, 8}: +4 is the modal
step in both, but 8 occurs in both, and 12 and 64
occur under the first — so the +4 step of
AES-NUM-146…148 is not a near-miss law; at
Hamming-1 range the byte-0 axis steps by several
amounts. Each near-miss is printed in full in the
raw section with its sub-key values, differing
position and byte size, A and B byte-0
differences, B-minus-A differences, cells and
cell-third difference where both pairs carry a
single cell. Any relation NOT PROVEN.

## (iii) Gaps 5 and 6 in full against each other

Gaps 5 and 6 are two steps of the same secondary
run (run 74, step 33 and step 37), and at their
bounds they are the same gap twice over — the
AES-NUM-145 gaps-3/7 shape repeated: run shift 0,
run length 83, run extents positions 524–614 in
both contexts, left shift 0, right shift 0, A gap
distance 2, B gap distance 2, skipped counts
1 and 1, skipped sizes (32784,) on both sides,
skipped channels A (0,) and B (1,), and the
mapping ((0, 1),) as both set and full sequence.

The 32-feature side-by-side table (the
AES-NUM-145 form) reads **19 equal / 13
differing**. The differing features are: step
(33 vs 37); the left and right bounding acts and
their A/B (offset, size, channel) values (gap 5
left (788705808, 14864, 2), right (788754432,
1552, 1); gap 6 left (788803632, 26128, 1), right
(788863488, 26128, 1)); the A and B positions
(562, 564) vs (567, 569); the skipped offsets
(788721152,) vs (788830208,) on both sides; and
the two surrounding windows. Every differing
feature is a location, an identity, or a
skipped-act offset — no bounding-side structural
feature distinguishes them, and none needs to:
their mappings agree.

The mapping as a function of the features the two
gaps SHARE, stated exactly over all 8 gaps: for
each of the 19 shared features, the verdict of
that single feature as a determinant was printed
against both targets (mapping set and mapping
full). Every shared run, shift, extent, distance,
count and size feature is VIOLATING as a
determinant — its 5/6 value is also carried by
other gaps under other mappings (the run/extent/
shift values by gaps 3, 4, 5, 6, 7 with targets
((0, 1),), ((1, 2),), ((2, 0),); the distance and
count values by gaps 3, 5, 6, 7; the skipped-size
value (32784,) by gaps 3, 5, 6 with targets
((0, 1),) and ((2, 0),)). The only shared features
whose 5/6 value is carried by exactly gaps {5, 6}
are the skipped channels A (0,) and B (1,) — and
those are the mapping's own components, not
determinants of it: a gap whose single skipped
A act is on channel 0 and whose single skipped
B act is on channel 1 has mapping ((0, 1),) by
the mapping's definition. The rows for the mapping
features themselves restate the target (and
against the full-sequence target the set row even
violates, gap 4 carrying the set ((0, 1),) with
the four-long full sequence). So the 5/6 agreeing
repeat is explained by nothing measured upstream
of the channels; it is the channels. Mechanisms
NOT PROVEN.

## Next

Slice 4.150 — the 3 control comparisons with the
agreeing (12, 7) profile read in full (which
repeat carries them, and which field trades place
so a violating repeat can hold an agreeing-profile
comparison); the 8 byte-0-differing near-miss
pair-pairs read against each other (the +4 cases
against the 8/12/64 cases: B byte-0 differences,
B-minus-A, groups, record counts, cell thirds);
and gap 4 read in full against gaps 5 and 6 (it
shares their mapping set ((0, 1),) with a four-long
full sequence — the feature-table treatment, and
what makes its skipped block four long while 5/6
are one long). Host/artifact analysis only — no
physical child.
