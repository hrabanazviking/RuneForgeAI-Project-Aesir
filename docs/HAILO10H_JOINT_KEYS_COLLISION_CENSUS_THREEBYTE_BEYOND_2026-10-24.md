# Gap 2's broken chain does not repair under any joint key: wed the first act to the context's length and it still splits (position-1 fails 7 of 70 joint keys, position-2 8 of 70 — the length joint adds no key at all over the first act alone); wed it to a sister gap's whole tuple and it still splits (8 and 9 violating joint keys of 71 — each sister joint splits only the widest first act, into halves that still violate); wed it to the loose order and it still splits (6 and 7 violating of 73), though there the two first acts (1098455040, 328, 0) and (961257984, 328, 0) fall silent — their alternatives separate by order — while the widest first act splits under both orders; and the whole gap-2 tuple as a function of (length, position-0) fails on 10 of 70 keys, exactly the union of the two positions' failures. The one shared offset, read in full, is a coincidence of numbers and nothing more: the great act (120529920, 32784, 0) stands in two contexts of another artifact (5ab3537d cidx 12 and 112) that share ZERO distinct acts with any of the gap act's twelve contexts and contain none of the 333 gap acts, while the gap act's twelve contexts are identical in every printed feature; and cross-size offset sharing whose smaller act is size 328 is not unique to that offset — the corpus census finds 19 such offsets (the target plus 18 others, 8 of them pairing the 328 act with a size-32784 act). Beyond the great group, exactly one three-byte key is ever repeated without violating anywhere in the 224-pair population: (byte 0, byte 3, byte 1) = (20, 128, 1), carried across groups by A 1401b180 -> B 1401b100 and A 1401b280 -> B 1401b200, both keeping B byte 0 = 20 — the first three-byte determination with any repetition to spare; (byte 3, byte 1, byte 2) is NOT a function over the full population, failing on exactly its two repeated values, the narrow keys (128, 1, 176) -> {28, 32} and (128, 1, 178) -> {20, 24} of group (14, 9992); every other three-byte determination, in the full population and in each group, holds only by unique identification — mechanisms NOT PROVEN (AES-NUM-133)

Slice 4.133, worked under `docs/TASK_CONTRACT_4.133.md`
(contract published in the 4.132 closing commit @
4a08926b). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef133.py (the hef132 file verbatim as base — itself
the hef131/hef130/hef129 lineage — plus the new
arms133) sha256
`fdb56f647dd68e5b8a854af88f894458e114fd3d752f235b2700ad7013567e16`
(468,791 B); arms133 sha256
`75db127740721e5b105b9531d512285c9fcd6588258e92f83e158bee03024769`
(10,179 B), its gzip sha256
`177062ad2ba6b8c45ff01ed2e30f163fa7ce1508905b966d3b4b8cbd28431b1b`
(3,246 B). The arms were built locally by the
10-minute continuity worker and crossed by the
proxy-upload route (a one-shot on-device receiver
derived on-device from the verified recv132 receiver,
held in the foreground by a worker agent; the
receiver reported SAVED 3246 and the on-device gz
sha256 matched the VM's before assembly); hef133.py
was assembled on-device from the verified hef132 base
(on-device sha256 31d0a605… == VM) plus the arms, and
the assembled file's sha256 matched the VM's exactly
before the run. The one bounded host-side child was
launched with the contract corpus argv (the six
hailo-ollama blobs in glob order, then MiniLM — the
launch law recorded in the contract) and finished
on-device with an empty error file; DONE133 is the
output's last line. The retrieved output is 24,170
lines / 4,698,665 B, sha256
`34c6f1df0bb4dd227ecdea92348c0cbcb47a4a184fba5885adb79b0e7c158620`;
retrieved gz sha256
`d9834e1e515da11f1827fd4f75ed78edd7a28ab3301837dffd9ff63e25239ade`
(513,934 B, fetched through a temporary on-device HTTP
server via the tunnel proxy; the fetched gz sha256
equals the on-device gz sha256 and decompresses to
exactly the output sha256, verified on the VM at
closing); the 4.133 section begins at output line
22,821 — exactly one past 4.132's total line count, and
the first 22,820 lines are byte-identical to hef132.out
(verified with cmp both on-device and on the VM at
closing), the base having reproduced line-for-line.

## Controls

Inherited controls reproduce EXACTLY: cells 55,902 /
obs 527,236; divergent triples 2,171, verdicts CONT
12,411 / BREAK 476 / INDET 2,365; lane-1 pairs 224;
(byte 3, byte 1, byte 2) keys 222; (byte 3, sum) keys
222; shared 114×251 acts 168; class-271 acts 30; rigid
context set 271; great group (20, 32720) pairs 216;
gap between-tuple counts 34 / 30 / 87 for gaps 0 / 1 / 2.

## (i) Gap 2's chain against joint keys

All nine tests are computed exactly over the 271 rigid
contexts (271 rows each). Every test prints its distinct
joint keys, its repeating joint keys in full, and every
violating joint key with its alternatives and every
carrying context's full row.

- (position-0, context length): 70 distinct joint keys,
  16 repeating. The distinct count EQUALS the position-0
  count alone (70) — in this population every position-0
  act already carries exactly one context length, so the
  length joint adds no distinction at all (derived at
  closing from the printed counts, consistent with
  AES-NUM-132's homogeneity finding). Position-1 is NOT
  a function of it (7 violating of 70 — the same seven
  position-0 acts as the single-key test, the widest
  (33312256, 328, 0) at length 245 still carrying 5
  alternatives); position-2 is NOT a function of it
  (8 of 70, the widest carrying 7 alternatives).
- (position-0, gap-0 tuple): 71 distinct, 17 repeating.
  The sister joint adds exactly ONE distinct key over
  position-0 alone: the widest position-0 (33312256,
  328, 0) splits into two gap-0 keys, carrying 2 and 3
  position-1 alternatives (3 and 4 position-2
  alternatives) instead of 5 (7) — a partial refinement
  whose halves both still violate (derived). Position-1
  NOT a function (8 violating joint keys), position-2
  NOT a function (9).
- (position-0, gap-1 tuple): 71 distinct, 17 repeating,
  the same shape — the widest position-0 splits into two
  gap-1 keys (2 and 3 / 3 and 4 alternatives), both
  halves violating (derived). Position-1 NOT a function
  (8), position-2 NOT a function (9).
- (position-0, loose order): 73 distinct, 15 repeating.
  Position-1 NOT a function (6 violating joint keys over
  5 position-0 acts), position-2 NOT a function (7 over
  6). Here two single-key failures fall silent:
  (1098455040, 328, 0) and (961257984, 328, 0) violate
  under neither order class for either position — their
  two alternatives separate by loose order (derived from
  their absence in the printed violating lists) — while
  the widest position-0 violates under BOTH orders
  (position-1: 2 alternatives L0-before-L1, 5
  L1-before-L0; position-2: 2 and 6).
- Whole gap-2 tuple as a function of (context length,
  position-0): 70 distinct, 16 repeating, NOT a function
  — 10 violating keys, exactly the union of the
  position-1 (7) and position-2 (8) violating position-0
  acts (derived: the three extra are (1230944256, 328,
  0), (1244657152, 328, 0), (1255547392, 328, 0), which
  fail only at position-2); the widest key (245,
  (33312256, 328, 0)) carries 7 distinct tuples.

No joint key tested repairs the chain. What varies the
fill inside a (position-0, length, sister-tuple, order)
family is not any of those features; the determining
feature, if one exists in the printed material, is
NOT PROVEN.

## (ii) The offset-120529920 collision in full; cross-size census

The corpus offset index is rebuilt in full (538,233
distinct offsets; 745,849 act occurrences).

The gap act (120529920, 328, 0) occurs 12 times, all as
gap-2 position-0, at cc9b9d1c cidx 14, 22, 30, …, 102
(step 8), position 583 in every context. Its twelve
contexts are IDENTICAL in every printed feature
(derived from the twelve printed rows): length 607,
gap-2 tuple ((120529920, 328, 0), (120530248, 328, 0),
(120530576, 328, 0)) — a clean +328 / +328 run — gap-0
tuple ((60314112, 248, 0), (60314360, 176, 0)), gap-1
tuple ((30587904, 256, 0), (30588160, 176, 0)), loose
distances d0 1 / d1 9, order L1-before-L0.

The large act (120529920, 32784, 0) occurs exactly
twice, both in 5ab3537d: cidx 12 at position 721 of
1,021 acts (300 from the end), and cidx 112 at position
474 of 902 acts (428 from the end). Both contexts are
printed with their ±8 neighbourhoods in full, their
size and channel multisets, and their relation to the
gap contexts: NEITHER context is in the 271 rigid set,
NEITHER contains the target gap act, NEITHER contains
ANY of the 333 gap acts, and EACH shares ZERO distinct
acts with EACH of the gap act's twelve contexts (24
pairwise counts, all zero). In cidx 12 the large act
stands inside the artifact's ordinary large-act field
(232 size-32784 acts in that context; its neighbours
are 32784-class acts with 1552 / 784 / 13328
satellites); in cidx 112 likewise (196 size-32784
acts). The collision is an OFFSET-ONLY coincidence
between two artifacts' independent populations; any
deeper relation is NOT PROVEN.

Census of every offset carried by acts of different
sizes whose smaller act is a size-328 act: 19 offsets
in the whole corpus (the target included), each printed
in full with its acts, occurrence counts and contexts.
The cross-size pattern is therefore NOT unique to the
target offset — there are 18 others. Of the 19, eight
pair the 328 act with a size-32784 act (109145088,
112060928, 120529920, 302853120, 319913984, 482159104,
711228416 — three acts there, the 328 act plus 32784
acts on channels 0 and 1 — and 791774208); the other
eleven pair it with mid-size acts (136199680 carries
three acts: 328, 30936 and 32016; the rest pair with
6008, 5488, 10256, 5512, 1552, 3088 twice, 25936, 3272
or 19472) — partner-size census derived at closing from
the printed census rows.

## (iii) B byte 0's three-byte tests beyond the great group

All four three-byte sub-keys are computed exactly over
the full 224-pair lane-1 population and over each group
separately ((14, 9992): 5 pairs; (19, 7712): 3 pairs;
(20, 32720): 216 pairs). Every repeated key value's
pairs are printed in full with their records.

- (byte 3, byte 1, byte 2), FULL: 222 distinct values;
  exactly 2 values repeat — (128, 1, 176) and (128, 1,
  178), both in group (14, 9992) — and BOTH violate:
  (128, 1, 176) -> {28, 32} (A 1c01b080 -> B 1c01b000
  vs A 2001b080 -> B 2001b000, each 27 records) and
  (128, 1, 178) -> {20, 24} (A 1401b280 -> B 1401b200
  vs A 1801b280 -> B 1801b200, each 27 records). NOT a
  function of the full population; the failure is
  localized entirely to those two narrow keys.
- (byte 0, byte 1, byte 2), FULL: 224 distinct values,
  repetition 0, violating 0 — a function only by unique
  identification.
- (byte 0, byte 3, byte 1), FULL: 223 distinct values;
  exactly ONE value repeats — (20, 128, 1), carried
  ACROSS groups by A 1401b180 -> B 1401b100 (byte 2 =
  177; group (19, 7712); 1 record, cell (19, 7712,
  2384)) and A 1401b280 -> B 1401b200 (byte 2 = 178;
  group (14, 9992); 27 records, cell (14, 9992, 4336))
  — and the two pairs AGREE: both are SAME, B byte 0 =
  20 = A byte 0. This key IS a function of the full
  population WITH one genuinely repeated, agreeing
  value — the first three-byte determination anywhere
  in this study with repetition to spare (the repeated
  pair count is one value; everything else still rests
  on unique identification).
- (byte 0, byte 3, byte 2), FULL: 224 distinct values,
  repetition 0, violating 0 — unique identification only.
- Per group: group (14, 9992) repeats only under
  (byte 3, byte 1, byte 2) — the same two narrow values,
  both violating; its other three keys give 5 distinct
  values for 5 pairs. Group (19, 7712) repeats under NO
  key (3 distinct values for 3 pairs under all four).
  Group (20, 32720) repeats under NO key (216 / 216
  under all four, as AES-NUM-132 found).
- Pooled (derived): across all four keys and all
  populations, the only repeated three-byte values in
  existence are the two narrow violating values and the
  one agreeing cross-group value. No other three-byte
  key is ever tested twice.

## Next

Slice 4.134 — gap 2's chain against compound joint
keys ((position-0, loose order, gap-0 tuple),
(position-0, loose order, gap-1 tuple), (position-0,
loose distances (d0, d1)), and the whole gap-2 tuple
as a function of (position-0, loose order)); the 19
cross-size offsets' size-328 acts as a population
(each 328 act's occurrences, gap/class membership,
its partners in full); and the agreeing (byte 0,
byte 3, byte 1) repetition read against the two-byte
cross-group sharings (which two-byte values are
carried by pairs of more than one group, counted
exactly). Host/artifact analysis only.

Mechanisms NOT PROVEN throughout: no feature or key
tested is claimed to be the mechanism of the gap-2
fill, of the cross-size offset sharing, or of the
byte-0 rewriting; the grades above are exact
population counts and nothing more.
