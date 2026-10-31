# Gap 2's broken chain, read in full, does not repair at any wider lens: every violating key's carrying contexts are homogeneous in length (and, the widest key apart, in their gap-0 and gap-1 tuples), yet the alternative acts still differ inside those families; gaps 0 and 1, re-read with the same wider lens, keep their exactness (their own tuple never differs under a repeating first act) while every repeating first act — 22 of 22 in gap 0, 21 of 21 in gap 1 — carries some other contextual difference, always including the gap-2 tuple; at offset level the 333 gap-only acts almost separate too (exactly ONE gap act's offset is carried by another distinct act — the gap-2 act (120529920, 328, 0), whose offset is also carried by the large act (120529920, 32784, 0) — and at (offset, size) level NONE is, 0 of 333), and the outlier run's 31 corpus-unique acts are unique at offset and (offset, size) level as well (0 of 31 at either level); and B byte 0 against every three-byte sub-key of the A word is a function only in the vacuous unique-identification sense (216 distinct values for 216 pairs, zero repetition, zero violating, under all four keys) — no three-byte key is ever tested twice, so no determination with repetition to spare exists; the shared identity pair A 682cb5f9 -> B 6884f5f8, read in full, is the SAME side of both of its status collisions and stands alone under every three-byte key — mechanisms NOT PROVEN (AES-NUM-132)

Slice 4.132, worked under `docs/TASK_CONTRACT_4.132.md`
(contract published in the 4.131 closing commit @
4007026a). Host/artifact analysis only, on Mimir
(purpleviking1) — no physical child, no device run of
any kind. All findings below are taken from the
sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef132.py (the hef131 file verbatim as base — itself
the hef130/hef129 lineage — plus the new arms132)
sha256
`31d0a6052f5d29fb47481a01c466202d53ec8b5786ca6ed6cb360e1316546d63`
(458,612 B); the combined arms132 sha256
`b4303295d8eda537702569420a318b46d22a3b1a963482af7f7603224df2a154`
(17,713 B), its gzip sha256
`12d1807d925d4c6da0635d1f890c70f4d7c2bb832e21edd2683733caac427335`
(4,970 B). The arms were built locally by the earlier
continuity worker (state file entry 05:23 EDT) and
crossed by the proxy-upload route (a one-shot on-device
receiver derived on-device from the verified recv130
receiver, held in the foreground by a worker agent; the
receiver reported SAVED 4970 and the on-device gz
sha256 matched the VM's before assembly); hef132.py
was assembled on-device from the verified hef131 base
(on-device sha256 08b3ae5c… == VM) plus the arms, and
the assembled file's sha256 matched the VM's exactly
before the run. The one bounded host-side child was
launched with the contract corpus argv (the six
hailo-ollama blobs in glob order, then MiniLM — the
launch law recorded in the contract) and finished
on-device with an empty error file; DONE132 is the
output's last line. The retrieved output is 22,820
lines / 4,330,712 B, sha256
`0d6057a7b7fe5c16a1c787e789a8bfe9f136667647269b0b92d89a6f6fb255e7`;
retrieved gz sha256
`78f8d204ca83102afdf4bca4da4b5c8fba4cae4d0892cfe677b16bede2a8f11b`
(496,091 B, fetched through a temporary on-device HTTP
server via the tunnel proxy; the fetched gz sha256
equals the on-device gz sha256 and decompresses to
exactly the output sha256, verified on the VM at
closing); the 4.132 section begins at output line
21,911 — exactly one past 4.131's total line count, and
the first 21,910 lines are byte-identical to hef131.out
(verified with cmp both on-device and on the VM at
closing), the base having reproduced line-for-line.

## Controls

Inherited controls reproduce EXACTLY: cells 55,902 /
obs 527,236; divergent triples 2,171, verdicts CONT
12,411 / BREAK 476 / INDET 2,365; lane-1 pairs 224;
(byte 3, byte 1, byte 2) keys 222; (byte 3, sum) keys
222; shared 114×251 acts 168; occurrence-2 population
127; class-271 acts 30 (loose pair (2727936, 24, 2) /
(2774016, 24, 1), 28 rigid, first rigid (172544, 376,
0), last rigid (2817536, 24, 0)); rigid context set 271
contexts, all in artifact cc9b9d1c; great group
(20, 32720) 216 pairs / 36 identity / 180 differing;
and the three gap controls from AES-NUM-130/131
(34 / 30 / 87 distinct between-tuples, tuple sizes
(248, 176), (256, 176), (328, 328, 328)).

## (i) Gap 2's broken chain in full; gaps 0/1 wider lens

For each of the three gap-2 function tests, every
violating key was printed in full: each alternative
act, every context carrying it with that context's
whole row (length, its gap-2 tuple, left position, its
gap-0 and gap-1 tuples, the loose pair's distances and
order, and the L0/L1/R0 positions), and a
carrying-vs-non-carrying comparison summary per key.

- Position-1 as a function of position-0: NOT A
  FUNCTION — 70 distinct keys, 7 violating (AES-NUM-131
  reproduced). In full: (33312256, 328, 0) carries FIVE
  alternative position-1 acts — (33312584, 328, 0),
  (63024640, 328, 0), (93151744, 328, 0), (1198582784,
  328, 0), (1228129792, 328, 0) — in 54 contexts; the
  other six keys carry two alternatives each:
  (900763136, 328, 0) → (900763464, 328, 0) /
  (1144839680, 328, 0); (915796480, 328, 0) →
  (915796808, 328, 0) / (1159571456, 328, 0);
  (961257984, 328, 0) → (961258496, 328, 0) /
  (2168851968, 328, 0); (976502784, 328, 0) →
  (976503296, 328, 0) / (2043928064, 328, 0);
  (1098455040, 328, 0) → (1098455368, 328, 0) /
  (2159213056, 328, 0); (2117242368, 328, 0) →
  (976503296, 328, 0) / (1036986880, 328, 0) — each of
  these six in exactly 2 contexts.
- Position-2 as a function of position-0: NOT A
  FUNCTION — 70 keys, 8 violating. (33312256, 328, 0)
  carries SEVEN alternatives — (33312912, 328, 0),
  (63024968, 328, 0), (93152072, 328, 0), (123233792,
  328, 0), (1198583112, 328, 0), (1228130120, 328, 0),
  (1497423872, 328, 0) — in the same 54 contexts;
  (1244657152, 328, 0) carries three — (1215153664,
  328, 0), (1244657808, 328, 0), (1513925120, 328, 0) —
  in 26 contexts; (1255547392, 328, 0) carries three —
  (1255548048, 328, 0), (1345591808, 328, 0),
  (1524509184, 328, 0) — in 25 contexts; the remaining
  five carry two each: (961257984, 328, 0) →
  (961258824, 328, 0) / (2168852296, 328, 0);
  (976502784, 328, 0) → (884825088, 328, 0) /
  (2043928576, 328, 0); (1098455040, 328, 0) → the same
  pair (884825088, 328, 0) / (2043928576, 328, 0);
  (1230944256, 328, 0) → (1230944912, 328, 0) /
  (1500232704, 328, 0) in 26 contexts; (2117242368,
  328, 0) → (884825088, 328, 0) / (1128898560, 328, 0).
- Position-2 as a function of position-1: NOT A
  FUNCTION — 73 distinct keys, 10 violating.
  (1244657480, 328, 0) carries three alternatives —
  (1215153664, 328, 0), (1244657808, 328, 0),
  (1513925120, 328, 0) — in 26 contexts; (1255547720,
  328, 0) carries three — (1255548048, 328, 0),
  (1345591808, 328, 0), (1524509184, 328, 0) — in 25;
  the other eight carry two each: (63024640, 328, 0) →
  (63024968, 328, 0) / (123233792, 328, 0) in 13
  contexts; (961258496, 328, 0) → (961258824, 328, 0) /
  (1052249600, 328, 0); (976503296, 328, 0) →
  (884825088, 328, 0) / (1128898560, 328, 0) in 3
  contexts; (1036986880, 328, 0) → (1036987208, 328, 0)
  / (1128898560, 328, 0); (1068221440, 328, 0) →
  (1068221768, 328, 0) / (2176030208, 328, 0);
  (1164493824, 328, 0) → (1164494152, 328, 0) /
  (2242460160, 328, 0); (1228129792, 328, 0) →
  (1228130120, 328, 0) / (1497423872, 328, 0) in 26
  contexts; (1230944584, 328, 0) → (1230944912, 328, 0)
  / (1500232704, 328, 0) in 26 contexts.
- Carrying vs non-carrying (derived at closing from
  the 25 printed COMPARISON rows): EVERY violating
  key's carrying contexts share exactly ONE context
  length — 245 for the widest key (54 contexts) and for
  the 13- and 26-context position-1 keys of the third
  test, 256 for the two 26-context (1230944256 /
  1230944584) families, 738 for the (1244657152 /
  1244657480) families, 606 for the (1255547392 /
  1255547720) families, and a single length for each
  2–3-context key (842, 686, 874, 873, 265). The
  carrying sets are likewise homogeneous in their
  gap-0 and gap-1 tuples — exactly 1 distinct tuple in
  each gap for every key except the widest, whose 54
  contexts hold 2 of each. What differs inside the
  carrying families is the gap-2 fill itself (5 / 7 /
  2–3 distinct later acts) and the loose pair: the
  widest family holds both orders (L1-before-L0 41,
  L0-before-L1 13) and distances d0 {1: 26, 2: 15,
  3: 12, 7: 1} / d1 {1: 12, 2: 1, 3: 23, 4: 16, 7: 1,
  9: 1}. So no printed wider feature — length, the
  other gaps' tuples, loose distances, loose order —
  separates a violating key's alternatives: the split
  happens inside otherwise-homogeneous context
  families. Any determining relation NOT PROVEN.
- Gaps 0 and 1 under the same wider lens: gap 0 has 22
  repeating first acts covering 259 contexts, gap 1 has
  21 covering 262 — and EVERY repeating first act
  carries at least one contextual difference (22 of 22
  and 21 of 21, the printed verdicts), while its OWN
  tuple never differs (distinct own tuples 1 for every
  repeating first act in both gaps — the AES-NUM-131
  exact functions are untouched by the wider lens).
  Difference composition (derived at closing from the
  printed per-first rows): gap 0 — the gap-2 tuple
  differs in 22 of 22, loose distances in 21, loose
  order in 14, the other two-act gap's tuple in 1,
  length in 1; gap 1 — gap-2 tuple in 21 of 21, loose
  distances in 21, loose order in 16, the other gap's
  tuple in 4, length in 2. The one gap-0 first act whose
  only difference is the gap-2 tuple is (1255546880,
  248, 0) (25 contexts, single (d0, d1) (2, 9), single
  order, single other-gap tuple, 3 distinct gap-2
  tuples).

Verdict: gap 2's chain stays broken at every step and
at every wider lens the run printed — the alternatives
split inside context families that agree on length and
on both other gaps — while gaps 0 and 1 stay exact as
functions even though no repeating first act in them is
ever contextually alone. Any form of determination, or
mechanism, NOT PROVEN.

## (ii) The gap-only acts at offset and (offset, size) level; the outlier's unique acts likewise

Corpus indexes over all act occurrences: 538,233
distinct offsets; 542,050 distinct (offset, size)
pairs; 745,849 total act occurrences. Each of the 333
distinct gap acts (gap 0: 61, gap 1: 57, gap 2: 215)
was read at both levels in full (every act carrying
its offset, every context, printed entire), and the
outlier run's 32 acts likewise.

- GAP-ACT LEVEL SUMMARY (printed): gap acts whose
  OFFSET is carried by more than one distinct act: 1
  of 333; whose (OFFSET, SIZE) is carried by more than
  one distinct act: 0 of 333.
- The single offset-level exception, in full: the
  gap-2 position-0 act (120529920, 328, 0) — offset
  120529920 stands in 14 act occurrences corpus-wide,
  carried by exactly 2 distinct acts, (120529920, 328,
  0) itself and the large act (120529920, 32784, 0),
  in 14 distinct contexts. The gap act's own 12
  occurrences are its gap occurrences (cc9b9d1c cidx
  14, 22, 30, 38, 46, 54, 62, 70, 78, 86, 94, 102);
  the remaining 2 contexts are the large act's
  (5ab3537d cidx 12 and 112). At the (offset, size)
  level the pair (120529920, 328) has exactly those 12
  occurrences, 1 distinct act, 12 contexts — the
  collision is purely cross-size: the same offset
  under size 32784 in another artifact. Every other
  gap act (332 of 333) has its offset carried by
  exactly one distinct act — itself — so at offset
  level the gap acts' occurrences are exactly their
  own (198 of the 333 offsets occur exactly once
  corpus-wide; derived at closing from the printed
  per-act rows).
- The outlier run's acts at both levels: the run
  (cidx 143, length 606; L0 at position 518, L1 at 549
  — run index 30 — R0 at 551; 32 acts) holds 31
  corpus-unique acts, the sole non-unique act being L1
  (2774016, 24, 1) with 271 occurrences (AES-NUM-131
  reproduced). UNIQUE-RUN-ACT LEVEL SUMMARY (printed):
  unique acts whose OFFSET is carried by more than one
  distinct act: 0 of 31; whose (OFFSET, SIZE) is
  carried by more than one distinct act: 0 of 31. In
  fact each unique act's offset stands in exactly 1
  occurrence corpus-wide (its own), and even L1's
  offset is carried by L1 alone (271 occurrences, 1
  distinct act at both levels; derived at closing from
  the printed per-act rows: offset-occurrence counts
  over the 32 run acts are {1: 31, 271: 1} at both
  levels).

Verdict: the gap-only separation of AES-NUM-131
survives one level down almost intact — offsets and
(offset, size) pairs of gap acts recur under other
acts essentially never (one cross-size, cross-artifact
offset collision in 333) — and the outlier run's
uniqueness is total at every level read. Any mechanism
NOT PROVEN.

## (iii) B byte 0 against the three-byte sub-keys; the identity pair in full

Population: group (20, 32720), 216 pairs (36 identity,
180 differing). B byte 0 itself (all 216 pairs) was
tested as a function of each three-byte sub-key of the
A word, computed exactly, and the shared identity pair
was read in full with its mates under thirteen sub-keys
printed entire.

- (byte 3, byte 1, byte 2): 216 pairs, 216 distinct
  key values, values with repetition 0, violating
  values 0 — IS A FUNCTION.
- (byte 0, byte 1, byte 2): 216 pairs, 216 distinct
  values, repetition 0, violating 0 — IS A FUNCTION.
- (byte 0, byte 3, byte 1): 216 pairs, 216 distinct
  values, repetition 0, violating 0 — IS A FUNCTION.
- (byte 0, byte 3, byte 2): 216 pairs, 216 distinct
  values, repetition 0, violating 0 — IS A FUNCTION.

All four verdicts are the vacuous kind: every key
value names exactly one pair, so no value is ever
tested twice and no determination is exercised — the
same unique-identification grade AES-NUM-130 recorded
for (byte 3, byte 1, byte 2) on the status test,
now shown to hold for all four three-byte keys on the
B-value test itself. Whether any three-byte key
determines B byte 0 with repetition to spare is NOT
PROVEN — there is no repetition.

- The identity pair in full: A 682cb5f9 -> B 6884f5f8;
  A bytes (byte 0 = 104, byte 1 = 44, byte 2 = 181,
  byte 3 = 249); B byte 0 = 104; status SAME,
  difference +0; group (20, 32720); exactly 1 record —
  cell (20, 32720, 7204), cidx 74, record index 24,
  n 27, centre 127, position class 'interior', in37
  False; the pair's only cell is (20, 32720, 7204).
  Its (byte 3, byte 1, byte 2) key is (249, 44, 181)
  and its fibre under that key is itself alone; its
  (byte 3, sum) key is (249, 225), fibre itself alone.
- Its mates under the lesser keys (printed in full):
  under (byte 3) = 249 it is 1 of 9 pairs, B byte-0 set
  {32, 104, 128, 144, 160, 192, 224, 240}, statuses
  SAME 1 / DIFF 8 — it is the only SAME pair of the
  nine. Under (byte 3, byte 1) = (249, 44) it stands
  with exactly its status-collision mate A 782c75f9 ->
  B 808cb2f9 (120 -> 128, DIFF), B set {104, 128},
  SAME 1 / DIFF 1; under (byte 3, byte 2) = (249, 181)
  with exactly its other status-collision mate
  A 705ab5f9 -> B a08de5f4 (112 -> 160, DIFF), B set
  {104, 160}, SAME 1 / DIFF 1 — the pair carries both
  collisions as their SAME side, as AES-NUM-131
  recorded. Under (byte 1) = 44 the same (249, 44) mate
  pair; under (byte 2) = 181 the same (249, 181) mate
  pair; under (byte 0) = 104 and (byte 0, byte 3) =
  (104, 249) it stands with A 68a7eff9 -> B f04234f5
  (104 -> 240, DIFF), B set {104, 240}. Under
  (byte 1, byte 2) = (44, 181), (byte 0, byte 1) =
  (104, 44), and all four three-byte keys it stands
  entirely alone (1 pair, B set {104}, SAME 1).
- Appearances of the pair across the run's own tables
  (counted at closing with grep over hef132.out, whose
  sections are the cumulative 4.124–4.132 tables):
  `682cb5f9` appears on 29 lines of hef132.out (29
  occurrences; `6884f5f8` likewise 29, the two always
  on the same lines), of which 14 lines are in the
  4.132 section itself and 15 in the inherited
  4.124–4.131 sections (hef131.out alone carries 15 —
  consistent).

Verdict: B byte 0 answers to no three-byte part of the
A word in any exercised sense — the three-byte keys
separate the 216 pairs only by naming each pair once —
and the twice-colliding identity pair is a singleton
under every key of three bytes or (byte 1, byte 2) /
(byte 0, byte 1) size, colliding only where a second
byte-pair mate exists. Any determination or mechanism
NOT PROVEN.

## Next

Slice 4.133 — gap 2's chain against joint keys
(position-1 and position-2 as functions of
(position-0, context length) and of (position-0, the
context-family features the comparisons printed), and
the gap-2 tuple as a function of (length, position-0));
the offset-120529920 collision in full (the
(120529920, 32784, 0) act read in its two 5ab3537d
contexts — position, neighbours, and what stands at
that offset there — against the gap act's 12 contexts);
and B byte 0's three-byte tests extended beyond the
great group (the full 224-pair lane-1 population and
each other group: does any three-byte key ever repeat,
and where it repeats, is B byte 0 a function of it).
Host/artifact analysis only — no physical child.
