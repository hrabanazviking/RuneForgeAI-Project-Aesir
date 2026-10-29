# The (byte 3, byte 1 + byte 2) factoring's fibres are all trivial — every one of the 222 fibres carries exactly one distinct (byte 1, byte 2) pair, the two 2-pair fibres differing only in byte 0 — and the map's 167 difference fibres carry no arithmetic structure either: of the 32 cells holding more than one key, the 16 two-key cells are constant-gap only vacuously (a single gap), and all 16 cells with three or more keys fail the constant-gap test (gap gcd 1 in 13 of them); group (20, 32720)'s shrinking steps are near-geometric but never geometric — all 324 consecutive ratios are pairwise distinct, every per-cidx ratio set spanning at most ~1.1×10⁻⁶, yet decay forms F1–F5 all fail on every sequence (F1/F3/F5: 54 of 54 cidx-sides; F2: 161 of 162 ratios per side; F4: 27 of 27 cidxs), and all 324 second differences are negative, with exactly one repeated value among them; the three displaced acts live in exactly the same eight contexts of cc9b9d1c, standing as the consecutive block (1062814208, 24, 0), (1062813184, 24, 1), (1052257280, 24, 2) immediately after the common core's final act in contexts 128, 251 and 265, while 251's closing segment and 130's head share exactly the two head-side displaced acts; and the occurrence-2 exclusivity population around the 54-act run is 127 of the 168 shared 114×251 acts, forming 24 runs of which the 54-act run is the eighth, the other 73 population acts standing in 23 further runs and singles (AES-NUM-126)

Slice 4.126, worked under `docs/TASK_CONTRACT_4.126.md`
(contract committed first @ fcf600b8). Host/artifact analysis
only, on Mimir (purpleviking1) — no physical child, no
device run of any kind. All findings below are taken from
the sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef126.py (the hef125 file verbatim as base — itself the
hef122 base plus arms125 — plus the new arms126) sha256
`9fe7ff67e96757bcb7a622a80cb0f8aa990a529f3dc0f07dcccdd5775ec9ffff`
(364,672 B); arms126.py sha256
`5d41b5c5a2fd01b1021d8f0025f8360bd9fa09c1979dea2beb88579005a8bdd9`
(23,668 B), its gzip sha256
`78c17b16f9fb18b1886ae5384c39c033f9961ec5a1898d1cc67f7a363228cb91`
(6,446 B). Provenance: the arms gzip was split into 18
binary parts (17 × 373 B + 105 B), each landed on Mimir as
its own file via file.write with its own whole-part
sha256 gate. Sixteen parts passed on first landing; parts
4 and 13 were rejected by their gates twice each
(deterministic re-emission corruption at those
boundaries) and were each re-split into two sub-parts
(187 B + 186 B) which landed clean — 20 landed files in
all, re-verified as a set by an on-device sha256sum
listing before assembly. Concatenated on-device in
order, the whole-gzip sha256 and the decompressed arms
sha256 both matched the VM exactly. hef126.py was
assembled on-device from the verified hef125 base
(sha256
`af955835b43ab71e1d7d196335e44c4370da992f4ccc5fad8034a745269bbca9`,
byte-identical on Mimir and the VM) plus arms126, and
its on-device sha256 matched the VM-built file exactly
before anything ran. The run was detached via setsid
over the 7-artifact corpus (the six hailo-ollama blobs
in glob order, then MiniLM) and ran to DONE126 with an
empty error file. The retrieved output is 15,202 lines /
2,384,685 B, sha256
`fdf52667ddcbab9e5a090ddd5d3c31d46f5875f46de1a1066d9d0d9558fb6a51`;
retrieved gz sha256
`68484fc4f75ebe030653778b11254f6adc23a018df4ddc76c57591314d2f17da`
(294,206 B, fetched through a temporary on-device HTTP
server via the tunnel proxy; a first fetch attempt
returned a 335 B HTML error page and was discarded —
the successful fetch's gz sha256 equals the on-device
gz sha256 and decompresses to exactly the output
sha256, verified on the VM at closing); DONE126 is the
output's last line (15,202); the 4.126 section begins
at output line 13,606 — exactly one past 4.125's total
line count, the base having reproduced line-for-line.

## Controls

Inherited controls reproduce EXACTLY: cells 55,902 /
obs 527,236; divergent triples 2,171, verdicts
CONT 12,411 / BREAK 476 / INDET 2,365; thin 383
(315 L1 UNANIMOUS + 58 L2 UNANIMOUS + 10 L2 AP);
≥8 cells 25,566, unanimous 18,286, 29 centres;
differing lanes 2,584 by lane {0: 1086, 1: 354, 2: 0,
3: 406, 4: 738}, in-37 differing 535; lane 1 354 lanes /
224 pairs / 218 diffs / 217 XORs; (byte 3, byte 1,
byte 2) map 222 keys / 224 pairs; (byte 3, byte 1 +
byte 2) keys 222 with 2 multi-pair keys; shared
267∩144 acts 36; lengths cidx 130 / 267 / 144 =
842 / 842 / 245.

## (i)(a) The factoring fibres in full

All 222 (byte 3, byte 1 + byte 2) fibres are printed in
full in the raw output — every key with its pairs, their
(byte 1, byte 2) sets, A and B byte-0 values, groups and
the byte-3 difference (a single difference per fibre
throughout, as the AES-NUM-125 determination requires).

The fibres are **trivial as fibres**: the pair-count
distribution is {1: 220, 2: 2} and the distinct-byte-1
distribution is **{1: 222}** — every fibre carries
exactly ONE distinct (byte 1, byte 2) pair. The only two
multi-pair fibres are the narrow keys already known:
(byte 3 128, sum 177) with (byte 1, byte 2) = (1, 176)
and A byte 0 ∈ {28, 32}, and (byte 3 128, sum 179) with
(1, 178) and A byte 0 ∈ {20, 24}, both at difference
−128, group (14, 9992) — the pairs under a fibre differ
only in byte 0, never in (byte 1, byte 2). No fibre
anywhere trades byte 1 against byte 2 at a fixed sum:
distinct byte 1 per fibre is 1 in all 222 cases, and
likewise byte 2 is fixed once the sum and byte 1 are.

The stated arithmetic test therefore has nothing to
bite on: fibres with ≥2 distinct byte-1 values number
**0**, the sorted-gap lists are empty in all 222
fibres, the gap gcd and constant-gap verdict are
vacuous everywhere, and the range is 0 against a fibre
size of 1 distinct value (2 pairs at most).
Arithmetic-progression structure across the factoring
fibres is **NOT PROVEN** — recorded as vacuous, not as
a law: the factoring is a re-keying of the same 222
keys (AES-NUM-125), and its fibres inherit the full
key's injectivity on (byte 1, byte 2).

## (i)(b) The difference fibres in full

The 222 keys land in **167 (byte 3, difference) cells**
(expect 167), printed in full in the raw output — every
cell with the keys landing in it and each key's pair
count. Cell sizes by keys: {1: 135, 2: 16, 3: 9, 4: 7}
(135 + 32 + 27 + 28 = 222); by pairs: {1: 135, 2: 16,
3: 9, 4: 6, 6: 1} — the single 6-pair cell is
(128, −128), holding the four narrow keys (128, 1, 160),
(128, 1, 176), (128, 1, 177), (128, 1, 178). **32 cells
hold ≥2 keys**; they are printed in full in the raw
output and tabled in the ledger entry. No two keys in
any cell share a sum (derived at closing: the 32
multi-key cells are exactly the 32 cells with ≥2
distinct key sums).

Arithmetic structure of the cells' key sums, tested
exactly as stated (distinct sums sorted; gaps;
constant-gap verdict; gap gcd):

- The 16 two-key cells each have a single gap and are
  constant-gap only vacuously — gaps 14, 12, 190, 61,
  126, 118, 33, 86, 107, 76, 139, 68, 9, 199, 225, 196,
  each equal to its own gcd.
- **All 16 cells with ≥3 keys fail** the constant-gap
  test — counterexample cells 16, constant-gap cells
  with ≥2 gaps 0. First counterexample: cell
  (128, −128), sums [161, 177, 178, 179], gaps
  [16, 1, 1], gcd 1. The remaining failures: (184, −7)
  gaps [29, 124] gcd 1; (187, −1) [7, 17, 85] gcd 1;
  (210, −1) [80, 193] gcd 1; (222, −11) [26, 43]
  gcd 1; (226, −2) [29, 155] gcd 1; (236, −1)
  [3, 96, 31] gcd 1; (242, −7) [143, 15] gcd 1;
  (243, −1) [10, 170, 37] gcd 1; (246, −5) [27, 39]
  gcd 3; (246, −1) [27, 85] gcd 1; (247, −1)
  [12, 115, 34] gcd 1; (249, −4) [82, 25] gcd 1;
  (250, −1) [33, 5, 48] gcd 1; (251, −3) [216, 6]
  gcd 6; (252, −1) [10, 100, 28] gcd 2. Gap gcd is 1
  in 13 of the 16 failing cells.

Constant-gap / arithmetic structure across the
difference cells is **NOT PROVEN**: it survives only
where a single gap makes it vacuous, and fails on
every cell with two or more gaps to compare.

## (ii)(a) The 189 steps as sequences in full

The trajectories were rebuilt exactly as in
AES-NUM-125 (blocks keyed by cell offset over the
lane-1 records of group (20, 32720); 8 block offsets
6796–7272, 27 cidxs, every cidx in all 8 blocks). For
each of the 27 cidxs the raw output prints in full:
the 8 A and B levels, the 7 delta-A and 7 delta-B
values, the 6 consecutive ratios of each as exact
reduced fractions, and the 6 second differences of
each — 189 steps, 324 ratios, 324 second differences.

Pooled, the ratios are **all distinct and all strictly
between 0 and 1**: ratios-A 162 distinct of 162, from
5976349/9115310 (≈0.6557) to 2726495/3484787
(≈0.7824); ratios-B 162 distinct of 162, from
1545014/2343659 (≈0.6592) to 238729/309153 (≈0.7722);
combined 324 distinct of 324, all positive. No two
consecutive-ratio values anywhere in the population
are equal.

The second differences are **all negative** (324 of
324 — the shrinking itself, differentiated): A-side
162 values, 161 distinct, from −135,899,168 to
−16,464,172; B-side 162 distinct of 162, from
−133,807,488 to −16,659,848; combined 323 distinct of
324. The single repeated second difference in the
whole population (derived at closing from the printed
tables) is **−38,363,136, occurring at cidx 11 step
k = 3 and cidx 29 step k = 3, both on the A side**.

The near-miss that defines this section (derived at
closing from the printed ratio tables): within any
one cidx and side, the 6 ratios are tightly clustered
— the widest per-sequence spread is ≈1.12×10⁻⁶
(cidx 50, B side), the narrowest ≈1.6×10⁻⁷ (cidx 71,
B side), the median ≈4.3×10⁻⁷. Each sequence looks
geometric to about six decimal places, and is nowhere
exactly geometric: not one of the 54 sequences has
even two equal ratios.

## (ii)(b) Decay forms F1–F5, tested exactly

All five contract forms **fail**, each on effectively
every sequence:

- **F1 (per-cidx geometric):** constant-ratio sequences
  0 of 54 cidx-sides; counterexample cidx-sides 54;
  counterexample steps (ratios ≠ the sequence's first
  ratio) 270 of 270. First counterexample: cidx 2,
  A side, k = 1 — ratio 1848215/2387291 followed by
  2861739/3696430.
- **F2 (pooled geometric):** A-pooled 161 counterexamples
  of 162 ratios against the first ratio; B-pooled 161
  of 162; combined 323 of 324. First counterexample at
  pool index 1 on every arm.
- **F3 (per-cidx constant second difference):**
  constant sequences 0 of 54; counterexample cidx-sides
  54; counterexample steps 270 of 270. First
  counterexample: cidx 2, A side, k = 1 — second
  differences −69,001,728 then −53,420,224.
- **F4 (per-cidx delta-B / delta-A constant over its
  7 steps):** constant cidxs 0 of 27; counterexample
  steps 162 of 162. First counterexample: cidx 2,
  k = 1 — 5037941/4774582 then 1904347/1848215. (The
  per-cidx F4 ratio lists are printed in full in the
  raw output.)
- **F5 (per-cidx delta proportional to level):**
  constant sequences 0 of 54 cidx-sides; counterexample
  steps 324 of 324. First counterexample: cidx 2,
  A side, k = 1 — 2387291/22982330 then
  1848215/25369621.

No decay form is proven. What the numbers do support,
stated as measurement and not as a form: the decay is
per-cidx near-geometric with a cidx-specific ratio
(the pooled ratio range spans ≈0.656–0.782, while each
single sequence spans ≤≈1.1×10⁻⁶), and the second
differences shrink in magnitude alongside the deltas
(all 324 negative, none zero). An exact generating
form for the steps remains **NOT PROVEN**; the
~10⁻⁶-scale wobble around each cidx's ratio is the
open residue — consistent in size with integer
rounding of an underlying geometric sequence, but
that mechanism is a hypothesis for a stated-form
test, not a finding.

## (iii)(a) The three displaced acts' corpus-wide profiles

Each displaced act occurs exactly **8 times** (expect
8), and every occurrence of all three acts is in the
single artifact **cc9b9d1c** — profiles in full in the
raw output (artifact, cidx, position, context length,
both neighbours for all 24 occurrences). The three
acts share **exactly the same eight contexts** (derived
at closing from the printed profiles): cidx 125, 128,
130, 143, 251, 261, 262, 265.

Their arrangements differ sharply by context:

- In **cidx 128 (length 839), 251 (842) and 265
  (839)** the three stand as one consecutive block in
  the order D2 (1062814208, 24, 0), D3 (1062813184,
  24, 1), D1 (1052257280, 24, 2) — at 128@819–821,
  251@822–824, 265@819–821 — immediately after the
  common core's final act (2817536, 24, 0) (at 818 /
  821 / 818) and immediately before (1113626112, 24, 0).
  The block and both flanks are identical in all three
  contexts.
- In **cidx 130** they are split: D1@6 and D2@7
  adjacent at the head (D2's next act is the head
  3-run's (0, 304, 0)@8), D3 alone at 197.
- In **cidx 125** D1@6 stands at the head (next act
  (0, 304, 0)), while D3@546 and D2@548 stand two
  apart mid-context with the single act (1062813696,
  328, 0) between them; **cidx 262** repeats that
  split exactly in shape: D1@7 at the head (next act
  (0, 304, 0)@8), D3@537 and D2@539 two apart with
  (2174832128, 328, 0) between them.
- In **cidx 143** (length 606) D2@4 is at the head
  (next act (0, 304, 0)), D3@87 and D1@90 stand three
  apart. In **cidx 261** (length 874) D1@4 and D2@5
  are adjacent at the head (D2's next act (0, 304, 0)),
  D3 alone at 288.

So the trio is never scattered at random: in every one
of its eight contexts at least two of the three stand
within three positions of each other, and the head
placements always abut the head 3-run's first act.

## (iii)(b) 251's closing segment against 130's head

Both segments are printed act by act in the raw output
with corpus-occurrence counts and cross-membership.

**251 @818–841 (24 acts):** three private 328-acts at
818–820 (occurrence count 1 each, in no other break
context); the core-final act (2817536, 24, 0)@821
(271 occurrences); the displaced block D2@822, D3@823,
D1@824 (8 each); (1113626112, 24, 0)@825 (3
occurrences); four private acts at 826–829 (1 each);
the 4-act run shared with 114 at 830–833
((49862656, 24, 0), (49863168, 24, 1), (49863680, 24, 2),
(49864192, 24, 0); 3 occurrences each, present in
ctx114, absent from ctx130 and ctx267); and eight
private acts at 834–841 (1 each). Only **4 of the 24**
closing acts occur anywhere in ctx130: (2817536, 24, 0)
and the three displaced acts.

**130 @0–10 (11 acts):** (1128903168, 24, 2)@0 and
(1128903680, 24, 0)@1 (2 occurrences each, in neither
251, 114 nor 267); (93156864, 24, 0)@2 (28);
(976512000, 24, 1)@3 (4; the only head act besides the
3-run found in 267); (1113629696, 24, 1)@4 and
(1116362240, 24, 0)@5 (2 each); D1@6 and D2@7 (8 each);
and the head 3-run (0, 304, 0/1/2)@8–10 (1060 / 1060 /
1058). **5 of the 11** head acts occur anywhere in
ctx251: D1, D2 and the head 3-run.

**Cross-membership of the two segments is exactly 2
acts** — D1 (130@6 / 251@824) and D2 (130@7 / 251@822).
D3 stands in 251's closing segment (823) but not in
130's head (its 130 place is 197); no other act is in
both segments. The two segments are otherwise disjoint
populations: 251's close is built of private acts, the
displaced block and shared tail material, while 130's
head is built of low-occurrence head acts, the two
head-side displaced acts and the universal head 3-run.

## (iii)(c) The occurrence-2 exclusivity population

The population — acts occurring exactly twice in the
corpus, once in cidx 114 and once in cidx 251 (all in
cc9b9d1c) — is **127 acts**, printed in full in
114-position order with both positions in the raw
output. They are **127 of the 168** shared 114×251
acts (the population is a subset of the shared set);
the other 41 shared acts occur 3 or more times. The
population's position-difference distribution
(251 − 114) is {−1: 1, 0: 56, +1: 21, +2: 36, +3: 2,
+4: 11} — against the full shared set's {−1: 4, 0: 93,
+1: 21, +2: 36, +3: 2, +4: 12}, so the 41
non-population shared acts sit at difference 0 in 37
cases, −1 in 3 and +4 in 1 (derived at closing).

The population forms **24 runs** (maximal runs
consecutive in both contexts at matching offsets):
length distribution {54: 1, 9: 1, 7: 1, 6: 3, 5: 1,
3: 6, 2: 5, 1: 6} — 121 acts in runs of length ≥2 and
6 isolated singles, at 114 positions 4, 126, 128, 751,
766, 773. Against AES-NUM-125's 21 runs over all 168
shared acts, the population's runs are exactly the
shared runs minus the head 3-run (occurrence counts
1060 / 1060 / 1058), the 32-act tail run at 786–817
(271) and the 4-act run at 830–833 (3 each), and minus
two of the eight shared singles (the core acts at
780/784 and 821) — derived at closing from the two
slices' printed tables.

**The 54-act run's place:** all 54 of its acts are in
the population (verified: 54 of 54), and it is **RUN 8
of the 24** population runs, at identical positions
130–183 in both contexts — the population's longest
run by a factor of six over the next (9). The other
**73 population acts stand in the remaining 23 runs**:
before the 54-run, a 2-run at 59–60, the 9-run at
73–81, two 3-runs, a 5-run and the singles at 4, 126
and 128; after it, runs at 215–220 (6), 224–230 (7),
233–234 (2), 258–259 (2), 383–384 (2), 387–389 (3),
392–397 (6), 540–545 (6), 578–580 (3), 610–612 (3),
633–634 (2), 755–757 (3) and the singles at 751, 766
and 773 — all at position differences of +4 or less,
none reaching the tail block at 786+ where the shared
population's high-occurrence acts take over.

## Grades

- (i) Factoring fibres read in full (222 keys / 224
  pairs): every fibre carries exactly one distinct
  (byte 1, byte 2) pair; arithmetic structure across
  the fibres VACUOUS, not proven. Difference fibres
  read in full (167 cells / 222 keys / 224 pairs; 32
  multi-key cells): constant-gap structure NOT
  PROVEN — vacuous on the 16 two-key cells, failing
  on all 16 cells with ≥3 keys.
- (ii) Steps as sequences read in full (189 steps,
  324 exact ratios, 324 second differences): all
  ratios pairwise distinct, all second differences
  negative with exactly one repeated value. Decay
  forms F1–F5 all FAIL with their counterexample
  counts recorded; per-cidx near-geometric clustering
  (spread ≤≈1.1×10⁻⁶) measured but NOT a proven form.
  Exact decay form NOT PROVEN.
- (iii) Displaced acts profiled corpus-wide in full
  (8 occurrences each, one artifact, the same eight
  contexts; a consecutive D2–D3–D1 block after the
  core-final act in 128 / 251 / 265). 251's closing
  segment and 130's head read in full; their
  cross-membership is exactly the two head-side
  displaced acts. Occurrence-2 population read in
  full: 127 of 168 shared acts in 24 runs, the
  54-act run verified as RUN 8, all 54 members in
  the population. Mechanisms NOT PROVEN.

## Next (slice 4.127)

(i) the (byte 3, byte 1 + byte 2) → difference table
read as a per-byte-3 function of the sum in full (for
each of the 61 byte-3 values, its keys ordered by sum
with their differences — monotonicity and step
structure tested exactly), and byte 0's own map over
the 224 pairs (A byte 0 → B byte 0 read in full, and
its determination status against the key); (ii) the
near-geometric steps' wobble measured exactly —
per-cidx ratio deviations from the sequence median in
full, and stated integer-rounding geometric forms
tested exactly (delta(k) against round / floor of
delta(0) · r^k for the best per-cidx rational r, with
the candidate forms stated before testing); (iii) the
displaced trio's eight contexts read in wider windows
around every occurrence in full (the three block
contexts 128 / 251 / 265 against the five split
contexts), the block's flanking acts profiled
corpus-wide ((2817536, 24, 0) before the block,
(1113626112, 24, 0) after it — all their occurrences),
and the 41 shared 114×251 acts that are NOT
occurrence-2 read in full by occurrence-count class.
Host/artifact analysis only — no physical child.
