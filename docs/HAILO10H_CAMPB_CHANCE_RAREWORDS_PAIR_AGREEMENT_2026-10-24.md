# AES-NUM-107 — the camp-B label-pair correlation is chance-consistent (the non-vacuous as-function property for both label2 bytes arises in ~21% of seeded size-12 subsamples of the pooled segments and ~17% under permutation, so it does not grade as a law); the "unique" singleton words are not rare in the wider corpus (fd000000 occurs 3,223 times across 1,549 distinct referenced segments — its AES-NUM-106 uniqueness was an artefact of the narrow populations scanned); and same-group instance-pair neighbourhood agreement at common offsets is usually high (502 of 789 pairs agree at 4–5 of 5 positions; 0/5 is a 3.2% exception, not the rule — the 9272 target pair is one of 25 such pairs)

Slice 4.107, worked under `docs/TASK_CONTRACT_4.107.md`
(contract committed first @ 8be87db8). Host/artifact
analysis only, on Mimir (purpleviking1) — no physical
child, no device run of any kind.

## Run and transfer record

The prior firing published the contract, built
hef107.py locally (hef106 lineage plus
hef107_arms.py, arms sha256 2f748744…, script sha256
1377ed2b…, gz sha256 becd1302…) and landed the
receiver on Mimir, then stopped before the
proxy-upload (the 4.100/4.103–4.106 stall pattern;
/tmp/hef107.py on Mimir was 0 bytes). This firing
resumed: the receiver was held open and the gz was
proxy-uploaded (saved:38602; gz and script sha256
verified on-device; py_compile OK). The script was
launched fully detached (setsid, own session) and
ran to completion over the 7-artifact corpus:
DONE107 at line 3,701, output 633,975 B, sha256
252e5e17…. Retrieval note: two proxy GET attempts
returned empty replies and one hand-copied base64
tail chunk failed its sha gate and was discarded
uncommitted; the arms section (lines 3,671–3,701)
and all control lines below were read directly from
the on-device output via device stdout, and the
output's sha256 is recorded above from the device
itself.

## Controls

All controls reproduce exactly: 128,787 small
actions; 79,001 bursts; 745,849 pointer actions;
1,504 contexts; 2,049 trailing pairs; 75,215
champion bursts. DONE105 lands at line 3,576 and
DONE106 at line 3,670 of this run's output,
identical to the AES-NUM-105/106 runs — the whole
hef lineage (AES-NUM-029/032…106 headline counts and
populations) reproduced; no arm below is credited
on a failed control, and none failed.

## (i) The camp-B label-pair correlation under a chance control

The 25 camp segments each carry exactly one label
per family (bad segments: none); camps A 13, B 12.
The AES-NUM-106 fact reproduces exactly:

- Camp B: label1 byte1 is a non-vacuous as-function
  of label2 byte0 (determiner distinct 11 of 12; the
  single collision, byte0 = 0x68 at cidx 283/337,
  agrees on label1 byte1 = 162) and of label2 byte1
  (distinct 11; collision byte1 = 0x02 at cidx
  166/229, agreeing on 162). Both bytes: True.
- Camp A: False for both bytes (byte0 collisions
  0x30 and 0x50 disagree; byte1 injective, 13
  distinct, no collision).
- Pooled (25): False for both bytes (byte0 has five
  collisions, three disagreeing; byte1 three
  collisions, two disagreeing).
- Label1 byte1 values: A {162, 163}, B {162, 179},
  pooled {162, 163, 179}; label2 byte0 20 distinct
  pooled, byte1 21 distinct.

**Chance controls** (the contract's test of whether
the camp-B property is itself surprising):

- Seeded random subsamples of the pooled 25, size
  12 (camp-B size), 20,000 draws: the non-vacuous
  as-function property arises for byte0 in 7,059
  draws (35.3%), byte1 in 9,786 (48.9%), either in
  12,666 (63.3%), and **both — the camp-B pattern —
  in 4,179 draws (20.9%)**.
- Seeded permutations of label1 byte1 over the
  pooled label2 values, subsampled likewise,
  20,000 draws: byte0 8,218 (41.1%), byte1 7,878
  (39.4%), either 12,657 (63.3%), both 3,439
  (17.2%).
- Exhaustive size-12 subsamples of camp A (all 13):
  0 hits for either byte — recorded as measured;
  camp A's byte1 determiner is injective at full
  size, so its subsamples inherit near-injectivity.

Verdict: a property that roughly one in five random
size-12 samples exhibits for both bytes at once is
exactly the shape chance produces in near-injective
tables with a two/three-valued target. The camp-B
correlation is **chance-consistent and does NOT
grade as a law** — the caution recorded in
AES-NUM-106 is confirmed by the control it asked
for. Label identity remains NOT PROVEN, and the
label-pair determiner class is now closed in both
directions, in all scopes, with its one local fact
explained.

## (ii) The population-rare singleton words against wider populations

The wider population is every DISTINCT referenced
segment of the corpus, keyed by (artifact, offset,
size): **542,905 distinct segments, 745,849 total
references (the pointer-action count, reproduced),
9,275,073,840 distinct referenced bytes** — strictly
wider than the 18 groups' 102 instance segments and
the 25 camp segments scanned in AES-NUM-106.
Aligned (4-byte) word counts over those distinct
segments:

- **fd000000**: 3,223 aligned occurrences in
  distinct segments (multiplicity-weighted 6,909);
  1,549 distinct segments contain it. Per-artifact
  distinct counts: cc9b9d1c 1,878; 773470cd 399;
  5ab3537d 388; 76c3a8ff 358; 0856a10c 148;
  0a0d378c 32; MiniLM 20.
- **e9ff0000**: 209 distinct-segment occurrences
  (weighted 240); 197 segments contain it;
  cc9b9d1c 180, 0856a10c 19, and 1–4 in each other
  artifact (MiniLM 1 — its own singleton).
- **f6000000**: 2,286 distinct-segment occurrences
  (weighted 2,582); 952 segments; cc9b9d1c 1,622,
  773470cd 287, 5ab3537d 264, 0856a10c 65,
  MiniLM 18, 0a0d378c 16, 76c3a8ff 14.

Verdict: none of the three words is rare in the
wider corpus. fd000000's AES-NUM-106 status —
"unique in everything scanned" — was true of the
populations scanned there (candidate neighbourhoods,
the 206 common-arm neighbourhoods, 102 instance
segments, 25 camp segments) and is an artefact of
those populations: in the full referenced-segment
population it is an ordinary word carried by 1,549
distinct segments, concentrated in cc9b9d1c.
e9ff0000 remains the least common of the three
(209 occurrences) but is likewise not unique.
The singleton-neighbourhood story of
AES-NUM-104/105/106 therefore has no rare-word
component left: the values are ordinary corpus
words, and the disjointness lives in the
DENSE-zero sub-population comparison, as graded
in AES-NUM-106. Word identity NOT PROVEN.

## (iii) Instance-pair neighbourhood agreement at other common offsets

For all 18 groups, every common offset, and every
unordered pair of instances, the 5-word
neighbourhood position-equal count (0–5) was
tallied: 206 common-offset neighbourhood records,
**789 instance pairs**.

- Distribution over all 789 pairs: {0: 25, 1: 172,
  2: 88, 3: 2, 4: 246, 5: 256}; mean position-equal
  3.318; identical tuples 256; mean differing bytes
  2.738.
- Per-position equality counts (-8, -4, 0, +4, +8):
  [527, 549, 275, 742, 525] of 789 — the CENTRE
  position is the least agreed (275), +4 the most
  (742); the flanks sit at 525–549.
- Excluding the target group/offset's pairs (788
  pairs): distribution {0: 24, 1: 172, 2: 88, 3: 2,
  4: 246, 5: 256}; mean 3.322; per-position counts
  identical to the full tally (the target's single
  pair contributes 0 at every position).
- The target itself: (MiniLM, 23, 32768) at 9272
  has exactly ONE instance pair (cidx 3 vs cidx 5):
  position-equal 0, differing bytes 10 — reproduced
  exactly from AES-NUM-106.

Verdict: **0/5 is an exception, not the rule.**
25 of 789 pairs (3.17%; 24 of 788 excluding the
target, 3.05%) agree at no position, while 502 of
789 (63.6%) agree at 4 or 5 positions and 256 are
fully identical. The distribution is strongly
bimodal with a near-empty middle (exactly-3 occurs
only twice). The 9272 pair is one of 25 total-
disagreement pairs — unusual, but a populated class,
not a singularity. What separates the disagreement
class from the agreement majority is NOT PROVEN by
this arm.

## Next

Slice 4.108 — the 25 total-disagreement (0/5)
instance pairs as a class (which groups/offsets,
their forms and zero patterns vs the 256 identical
pairs); the near-empty exactly-3 band and the
bimodality's group structure (is agreement a
per-group property?); the rare-word concentration
in cc9b9d1c (fd000000/f6000000 density per referred
byte vs the other artifacts). Host/artifact
analysis only — no physical child.
