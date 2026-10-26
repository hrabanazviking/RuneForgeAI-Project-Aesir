# AES-NUM-106 — the singleton-only neighbourhood values are mostly ordinary corpus words (only fd000000 is unique everywhere scanned; the disjointness is specifically against the DENSE-zero run-members), the cidx-3 counterpart at 9272 shares no neighbourhood position with the cidx-5 DENSE zero (0/5 equal, 10/20 bytes differ), and the labels share no stated relation with in-segment block positional structure (one camp-B-local as-function fact for label1 byte1 from the label2 head bytes, both of its collisions agreeing; affine zero everywhere)

Slice 4.106, worked under `docs/TASK_CONTRACT_4.106.md`
(contract committed first @ 8f038d03). Host/artifact
analysis only, on Mimir (purpleviking1) — no physical
child, no device run of any kind.

## Run and transfer record

The prior firing published the contract and stopped
(the 4.100/4.103/4.104/4.105 stall pattern). This
firing resumed: hef106.py built locally as the
hef105.py lineage plus hef106_arms.py (arms sha256
baea3979…, script sha256 cd7d18cc…, gz sha256
59acb293…), landed on Mimir by the proxy-upload
receiver (saved:35868; gz and script sha256 verified
on-device; py_compile OK).

The first launch was killed when its launching invoke
timed out at 30 s (the output stopped at line 2,653
with no DONE106; nothing from that partial run is
credited). The script was relaunched fully detached
(setsid, own session) and ran to completion over the
7-artifact corpus: DONE106 at line 3,670, output
sha256 01b1fa25…, 630,097 B, retrieved byte-complete
(gz sha256 1cf5d831… matched both sides).

## Controls

All controls reproduce exactly: 128,787 small actions;
79,001 bursts; 745,849 pointer actions; 1,504
contexts; 2,049 trailing pairs; 75,215 champion
bursts; whole-arm candidates 7,690, boundary 0;
non-common candidates 7,484 with form × zero splits
SPARSE 2,280/144, MID 2,306/21, DENSE 2,898/64; the
common-arm census reproduces AES-NUM-104 exactly
(206 records, forms DENSE 95 / SPARSE 65 / MID 46,
exactly 2 common-arm DENSE zeros); DONE105 lands at
line 3,576 of this run's output, identical to the
AES-NUM-105 run — AES-NUM-029/032…105 headline counts
all reproduced (no arm below is credited on a failed
control, and none failed).

## (i) The singleton-only neighbourhood values themselves

The 5 singletons and their neighbourhood tuples
(centre ff000000 in all five) are exactly as recorded
in AES-NUM-104/105: (0a0d378c, 21, 32560) q 6156
cidx 74; (5ab3537d, 9, 32584) q 5040 cidx 28; and
three in (MiniLM, 23, 32768) cidx 5 at q 6700, 11408
and 32248. At each relative position the singleton
value set is disjoint from the 59 run-members' set
(reproduced: intersections 0 at -8, -4, +4, +8), so
the singleton-only values are the singleton sets
themselves: 4 values at -8, 5 at -4, 4 at +4, 4 at
+8 — 17 (position, value) pairs over 13 distinct
values pooled.

**Identity across the singletons.** Almost nothing
is shared. The only values carried by two singletons
are 01000800 (at both -8 and +8) and 00000000 (at
+4), and all three are shared exclusively by the two
MiniLM cidx-5 singletons at 11408 and 32248 — same
group, same instance, different offsets; their
tuples are identical at -8, +4 and +8
(01000800 / 00000000 / 01000800 around the centre)
and differ only at -4 (4c01a380 vs 1c01b280). No
singleton-only value is shared across different
groups. Two further values repeat across positions
within a single singleton's own tuple: 02000000 at
-4 and +4 of the 0a0d378c singleton, ff7f0000 at -8
and +8 of the MiniLM q 6700 singleton.

**Recurrence elsewhere.** "Singleton-only" is a
statement about the run-members only — against the
wider corpus populations most of these values are
ordinary. Recurrence was measured in four
populations: all 7,484 whole-population candidate
neighbourhoods (re-derived), all 206 common-arm
neighbourhoods (re-derived), the raw aligned words
of all 102 distinct instance segments of the 18
groups (833,858 tokens, 6,049 distinct), and the raw
aligned words of the 25 camp segments (134,468
tokens, 490 distinct). Findings:

- 12 of the 17 (position, value) pairs recur at the
  SAME relative position in non-singleton
  whole-population neighbourhoods — e.g. ff7f0000 at
  -8 recurs 545 times there (and 3,532 times at any
  neighbourhood position), 02000000 at -4 recurs 227
  times, 00000000 at +4 recurs 4,580 times. The
  disjointness is a property of the DENSE-zero
  sub-populations, not of the values in the corpus.
- Five pairs do NOT recur at the same position in
  any non-singleton whole-population neighbourhood:
  f6000000 at -8 (whole any-position count 1 — itself
  only; raw instance total 2), fd000000 at -4,
  02010000 at +4, e9ff0000 at +4, 04010000 at +8
  (each whole any-position count 1 — itself only).
- Of those five, two still recur as raw aligned
  words outside candidate neighbourhoods: 02010000
  (46 raw instance occurrences) and 04010000 (94 raw
  instance, 25 raw camp). f6000000 has exactly 2 raw
  instance occurrences (one beyond its own).
- **fd000000 (at -4 of the 5ab3537d singleton) is
  unique in everything scanned**: whole-population
  any-position 1 (itself), common-arm 0, raw instance
  total 1, raw camp 0. **e9ff0000 (at +4 of the
  MiniLM q 6700 singleton) is raw-unique** (raw
  instance total 1, camp 0, common-arm 0) with one
  further whole-population neighbourhood occurrence
  at a different relative position (any-position 2).
- The common-arm population shares almost none of
  them: at the same position it contains only
  02000000 (-4: 22, +4: 8), 1c01b280 (-4: 2),
  ffffff7f (-4: 1), ff7f0000 (-8: 1) and 00000000
  (+4: 170).

Verdict: there is no singleton-only value *class* —
the 13 values are a mix of corpus-common words, a
few population-rare words, and one word
(fd000000) that occurs nowhere else in any scanned
population. What the singletons' neighbourhoods are
made of does not separate them from the corpus; the
separation measured in AES-NUM-104/105 lives in the
comparison against the run-members specifically.
Value identity beyond this census is NOT PROVEN.

## (ii) The cidx-3 counterpart at 9272, word by word

Both records re-derived in the group (MiniLM, 23,
32768) (commons exactly [9272]; per-ng form at 9272
{0: OTHER}, prediction None for both instances) and
both neighbourhoods match the contract's stated
tuples exactly:

- cidx 3 (ng 0, ngidx 4): value 127, z 1, DENSE,
  mask 00001, neighbourhood (ff7f0000, ffffff7f,
  ff7f0000, d30b0000, 00000000).
- cidx 5 (ng 0, ngidx 6): value 0, z 1, DENSE,
  mask 01000, neighbourhood (62470000, 00000000,
  ff000000, 02000000, 01000000) — the DENSE zero.

Position by position (-8, -4, 0, +4, +8): **no
position is equal — 0 of 5**; differing bytes per
position 2, 4, 1, 2, 1 — **10 of 20 bytes differ**
in total. The centre words differ by exactly the
value byte (ff7f0000 vs ff000000, XOR 007f0000).
The single zero word of each neighbourhood sits at
opposite ends (cidx 3's at +8, cidx 5's at -4),
which is exactly the mask contrast 00001 vs 01000.
The only word the two neighbourhoods share at all,
at any position, is 00000000 — carried at different
positions in each. Neither neighbourhood contains
the other's centre word except at the centre
itself in altered form: cidx 3's centre ff7f0000
appears in cidx 5's neighbourhood nowhere; cidx 5's
centre ff000000 appears in cidx 3's nowhere.

Verdict: the cidx-3 counterpart is not a near-copy
of the DENSE zero's neighbourhood — the two
instances of the same group at the same offset
agree in form (DENSE), z (1) and the absence of a
prediction, and in nothing positional. The value
byte (127 vs 0) is the centres' only one-byte
difference; everything around them is unrelated.

## (iii) Label values vs in-segment block positional structure

The 25 camp segments and labels are exactly as in
AES-NUM-103/104/105 (camp A 13, camp B 12, exactly
one family-1 and one family-2 label per segment;
bad segments: none). The block is the 182 aligned
words at 6184..6912 (26 units × 7 positions; family
by unit: 0 = units 0–7, 1 = units 8–16, 2 = units
17–25; head positions 0–3, tail positions 4–6 of
each unit). The AES-NUM-100 degeneracy ruling
applies throughout (a hit is degenerate when the
determiner is injective, constant, or takes ≤3
distinct values, or the target byte is constant).

**Definitional identity, excluded.** Each family's
36 head slots carry that segment's own label by
construction: verified 36/36 slots for both
families (every segment's word at its own family's
head slots equals its label). These slots were
excluded from the determiner hunt — a label cannot
be "determined" by itself.

**Slot-word hunt** (the remaining 146 slots × all
4 word bytes × label bytes, scopes A / B / pooled;
7,008 (scope, slot, byte, byte) tests per family):
no full-word exact hit anywhere. Byte-equal hits
occur only at tail slots and are all the
constant-zero coincidence, with counts matching
that explanation exactly: the labels' constant
bytes (label1 bytes 2,3 are 00 in all 25 segments;
label2 byte 3 is 00) against tail words' zero bytes
— family-0 tails are the all-zero word (8
combinations per scope for label1, 4 for label2),
family-1 tails carry three zero bytes (6 / 3),
family-2 tails are all-zero (8 / 4). Affine hits:
non-degenerate **0** for both families (every hit
degenerate). As-function hits: non-degenerate **0**
for family 2, and exactly **72 for family 1, all in
camp B only**: at the 36 family-2 head slots,
label1 byte 1 is a function of the head word's
byte 0 and, separately, of its byte 1 (36 slots ×
2 bytes). Since family-2 head words ARE the
segment's label2, this is a label-pair fact in
positional clothing: in camp B, label1 byte 1
(two-valued: a2 in 9 segments, b3 in 3) is a
function of label2 byte 0 and of label2 byte 1,
each singly. It holds through exactly two
determiner collisions, both agreeing (label2
byte 0 = 68 twice, both with label1 byte 1 = a2;
label2 byte 1 = 02 twice, both with a2); in camp A
the corresponding collisions disagree (label2
byte 0 = 30 and = 50 each pair an a2 with an a3),
and pooled it fails. AES-NUM-103 hunted the pair
in the label1→label2 direction only; this
direction and scope were untested there. It is
recorded as measured — a camp-B-local, one-bit
correlation — and it does not grade as a law:
no affine form, no camp-A or pooled counterpart,
and a two-valued target carried by agreeing
collisions is exactly the shape chance produces
in near-injective tables.

**Positional aggregates** (14 per-segment features:
distinct-word counts for the whole block, heads,
tails and each family × head/tail; consensus-
difference count and first/last differing index;
zero-word and ffffff7f-word counts in the block):
the features are constant or near-constant in
every scope (distinct-word counts are 5 / 3 / 2
for block / heads / tails in every segment;
consensus differences are 72 in all of camp B and
36 or 72 in camp A — the count of label-carrying
slots that differ from the camp consensus, a
label-derived quantity). As-function hits:
non-degenerate 0 for both families; affine hits:
non-degenerate 0 for both families.

Verdict: in-segment block positional structure
determines nothing about the labels beyond the
labels' own head slots. With the tails closed in
AES-NUM-101, the block variation exhausted in
AES-NUM-102, and this arm's slot + aggregate
hunts, every stated in-segment determiner class is
now closed. What the labels encode remains NOT
PROVEN.

## Next

Slice 4.107 — the camp-B label-pair correlation
under a control (does label1 byte 1 follow label2
bytes in camp-B-sized subsamples of the pooled
segments by chance?); the two raw-unique /
population-rare singleton words (fd000000,
e9ff0000, f6000000) against the artifacts' other
segment populations beyond the 18 groups; the
cidx-3/cidx-5 pair at other common offsets of
other groups (is 0/5 neighbourhood agreement the
rule for same-group instance pairs?). Host/artifact
analysis only — no physical child.
