# In the two-act gaps the second act IS an exact function of the first (gap 0: 34 keys, gap 1: 30 keys, zero violating keys in either) even though the offset between them is not constant (+248 in 187 of 271 gap-0 contexts, +512 in 46, negative in 38; +256 in 257 gap-1 contexts, +512 in 8, negative in 6), while in the three-act gap no position is a function of any earlier one (second as a function of first fails on 7 of 70 first acts, third as a function of first on 8 of 70, third as a function of second on 10 of 73); every one of the 333 distinct gap acts is gap-only corpus-wide — none stands anywhere outside its own gap slot, in any context, in any artifact; the outlier's 32-act run occurs exactly once in the whole corpus (its own context, cidx 143), and 31 of its 32 acts occur exactly once corpus-wide — the sole exception is L1 itself, at run index 30, which occurs 271 times — so the run's acts do not even co-occur anywhere else (zero co-present pairs, zero inversions, in all 1,503 other contexts); in the modal contexts the distance-1 loose act is immediately followed by the first rigid act in every context (46 of 46 and 43 of 43) while every other neighbour varies essentially per context; the four near-miss collisions are each exactly two pairs, two of them sharing the same identity pair; and B byte 0 itself is NOT a function of any two-byte sub-key of the A word — (byte 3, byte 1) fails on exactly its two named collision values (249, 44) and (252, 84), (byte 3, byte 2) on exactly (249, 181), (byte 1, byte 2) on exactly (128, 146), (byte 0, byte 1) on 5 values, (byte 0, byte 3) on 27 — mechanisms NOT PROVEN (AES-NUM-131)

Slice 4.131, worked under `docs/TASK_CONTRACT_4.131.md`
(contract committed first @ 2a35fb78). Host/artifact analysis
only, on Mimir (purpleviking1) — no physical child, no
device run of any kind. All findings below are taken from
the sha-verified raw output; the few derived counts marked
as such were computed at closing from the run's own
printed tables, never sampled.

## Run and closing record

hef131.py (the hef130 file verbatim as base — itself the
hef129/hef128/hef127 lineage — plus the new arms131)
sha256
`08b3ae5c5d77a4f878907a7451f75b9215924fe4d60b73bc197ad0960bb991ab`
(440,899 B); arms131.py sha256
`63243d2c8186eb64ca5ce5fa28277984f381eb8e38969fe24e0af136b4622d74`
(15,264 B), its gzip sha256
`12abd8c70ecc90794c589c80609078f6c4b5dfa424c71fdc1ad1ffff4f0f0a31`
(4,630 B). arms131 was built locally by the earlier
continuity worker (state file entries 04:44–04:52 EDT);
a first chunked file.write transfer was aborted by that
worker (one part landed short, session never finalized,
no file on-device) and was NOT reused. A second chunked
file.write attempt by this worker was rejected by the
device (invalid base64 length — a chunk corrupted in
re-emission) before any file committed, and that route
was abandoned. arms131 crossed by the proxy-upload route
(a one-shot on-device receiver, derived on-device from
the verified recv130 receiver, held by a subagent; the
receiver reported SAVED 4630 and the on-device gz sha256
matched the VM's before assembly); hef131.py was
assembled on-device from the verified hef130 base
(on-device sha256 16b77b5b… == VM) plus arms131, and the
assembled file's sha256 matched the VM's exactly. The
one bounded host-side child was launched with the
contract corpus argv (the six hailo-ollama blobs in glob
order, then MiniLM — the launch law recorded in the
contract after 4.127's no-argv failure) and finished
on-device with an empty error file; DONE131 is the
output's last line. The retrieved output is 21,910
lines / 3,944,864 B, sha256
`e6252cf73817328fe5c0982e846024058824ae4c5072bc5173b4f1394b5fa07a`;
retrieved gz sha256
`0b8861d0327d2f5a8fec0a2acbeef79516eb38f1997d4d8be27dfab0c2f9737e`
(472,174 B, fetched through a temporary on-device HTTP
server via the tunnel proxy; the fetched gz sha256
equals the on-device gz sha256 and decompresses to
exactly the output sha256, verified on the VM at
closing); the 4.131 section begins at output line
21,007 — exactly one past 4.130's total line count, and
the first 21,006 lines are byte-identical to hef130.out
(verified with cmp both on-device and on the VM at
closing), the base having reproduced line-for-line.

## Controls

Inherited controls reproduce EXACTLY: small 128,787 /
burst 79,001 / pointer 745,849 / contexts 1,504 /
trail pairs 2,049 / champion 75,215 (first output line);
cells 55,902 / obs 527,236; divergent triples 2,171,
verdicts CONT 12,411 / BREAK 476 / INDET 2,365; lane-1
pairs 224; (byte 3, byte 1, byte 2) keys 222; (byte 3,
sum) keys 222; shared 114×251 acts 168; occurrence-2
population 127; class-271 acts 30 (loose pair
(2727936, 24, 2) / (2774016, 24, 1), 28 rigid, first
rigid (172544, 376, 0), last rigid (2817536, 24, 0));
rigid context set 271 contexts, all in artifact
cc9b9d1c; great group (20, 32720) 216 pairs / 36 identity /
180 differing; and the three gap controls from
AES-NUM-130 (34 / 30 / 87 distinct between-tuples, tuple
sizes (248, 176), (256, 176), (328, 328, 328)).

## (i) The gap-fillers as a population

For each gap, every context's between-tuple was read
against the tuple's own first act (exact function tests
over all 271 contexts, violating keys in full), the
shared later acts were censused (which distinct first
acts each serves, in how many contexts), and every
distinct gap act was read against the contexts' own
bodies and the whole corpus.

- Gap 0 — (173040, 24, 0) → (173568, 816, 0), 34 tuples:
  the second act IS a function of the first act (34
  distinct first acts, 0 violating keys). The function
  is not a constant offset: second-minus-first offset
  is +248 in 187 contexts, +512 in 46, and negative in
  38 (largest negative share −56965120 in 25). 27
  distinct second acts; 5 of them serve more than one
  distinct first act. The widest-shared second act is
  (1198581760, 176, 0): 3 distinct first acts
  ((1198581248, 248, 0), (1225492992, 248, 0),
  (1255546880, 248, 0)), 54 contexts — the AES-NUM-130
  example, now counted exactly.
- Gap 1 — (174968, 24, 0) → (175616, 176, 0), 30 tuples:
  the second act IS a function of the first act (30
  distinct first acts, 0 violating keys). Offset +256
  in 257 contexts, +512 in 8, negative in 6. 27
  distinct second acts; 2 serve more than one first
  act — (915795968, 176, 0) serves 3 firsts in 8
  contexts and (900762624, 176, 0) serves 2 firsts in
  6 contexts.
- Gap 2 — (178792, 216, 0) → (2817536, 24, 0), 87
  tuples, three size-328 acts: NO position is a
  function of an earlier one. Position-1 as a function
  of position-0 fails on 7 of 70 distinct first acts
  (the first act (33312256, 328, 0) alone carries five
  different position-1 acts); position-2 as a function
  of position-0 fails on 8 of 70; position-2 as a
  function of position-1 fails on 10 of 73. Offsets:
  position-1 minus position-0 is exactly +328 in 189
  contexts (the AES-NUM-130 step, reproduced), +512 in
  6, and one large repeated value +1194817536 in 26,
  the rest scattered; position-2 minus position-0 is
  +656 in 163 contexts. Shared acts: 6 of 73 position-1
  acts and 10 of 72 position-2 acts serve more than
  one distinct first act.
- Gap acts against the bodies: all 333 distinct gap
  acts (61 + 57 + 215) are GAP-ONLY corpus-wide. Not
  one of them stands outside its gap slot in any of
  its own gap contexts, not one stands in a 271-set
  context where it is not a gap act, and not one
  stands in any context outside the 271 set — their
  corpus occurrences are exactly their gap occurrences
  (derived at closing from the per-act printed rows:
  333 of 333 verdicts GAP-ONLY (corpus-wide)).

Verdict: in the two-act gaps the filler pair is a
rigid couplet — the second act is fully determined by
the first, though not by a fixed stride — while the
three-act gap's fillers are not chained by any
first-to-next determination; and gap acts as a class
live nowhere else in the corpus. Any form of the
two-act functions, or mechanism, NOT PROVEN.

## (ii) The outlier's 32-act run read corpus-wide

cidx 143 (length 606): L0 (2727936, 24, 2) at position
518, from-end 87; L1 (2774016, 24, 1) at position 549;
R0 (172544, 376, 0) at position 551. The 32 acts
between L0 and R0 were printed in full, in order (run
indices 0–31, positions 519–550; L1 stands at run
index 30, with one further act (1225459712, 32784, 0)
between L1 and the block, exactly as AES-NUM-130
recorded).

- Consecutive-run search over all 1,504 contexts:
  exactly 1 exact occurrence — (cc9b9d1c, cidx 143,
  start position 519), its own context. The run
  stands nowhere else.
- The 32 acts read individually: 31 of the 32 occur
  exactly once in the whole corpus (one occurrence,
  one context — cidx 143 itself). The single exception
  is the act at run index 30, L1 (2774016, 24, 1),
  with 271 occurrences in 271 contexts. (Derived at
  closing from the printed per-act rows.)
- Relative order anywhere else: over all contexts
  except cidx 143, NO context holds two or more of
  the run's acts (co-present pairs 0, inverted pairs
  0) — the question of the acts standing in that
  relative order elsewhere does not arise; there is
  nothing to invert. The run is a singularity of
  cidx 143, not a recurring pattern.
- L0's neighbourhood in the modal contexts, by
  contrast: joint (1, 3) ×46 — L0 (distance 1) is
  immediately followed by R0 (172544, 376, 0) in all
  46 contexts; the single act standing between L1 and
  L0 (after L1, before L0 — the same act, the two
  distances differing by exactly 2) takes 34 distinct
  values, modal (95954944, 80, 1) ×13, the rest
  singletons; before L1 all 46 predecessors are
  distinct. Joint (3, 1) ×43 — L1 (distance 1) is
  immediately followed by R0 in all 43; the act
  between L0 and L1 takes 43 distinct values, all
  singletons, and L0's 43 predecessors are all
  distinct. So in the modal contexts the loose pair
  hugs the block with only its distance-1 member
  pinned to the block's edge; everything further out
  varies per context — the exact opposite of the
  outlier, where L0 is held 32 acts away by a run
  found nowhere else.

Any recurrence or mechanism NOT PROVEN — there is no
recurrence to grade.

## (iii) The near-miss collisions in full + B byte 0 against the two-byte keys

Population: group (20, 32720), 216 pairs (36 identity,
180 differing). Each named collision was printed in
full (every pair carrying the value: A and B words,
byte-0 status and values, group, records, cells), and
B byte 0 itself (all 216 pairs, not only differing)
was tested as a function of each two-byte sub-key,
violating values in full.

The four collisions — each is exactly two pairs, one
record each:

- (byte 3, byte 1) = (249, 44), status collision:
  A 682cb5f9 → B 6884f5f8 (byte 0 104 → 104, SAME,
  diff +0; cell (20, 32720, 7204), cidx 74) and
  A 782c75f9 → B 808cb2f9 (120 → 128, DIFF, +8;
  cell (20, 32720, 7272), cidx 77).
- (byte 3, byte 1) = (252, 84), B-value collision:
  A 745471fc → B 089adffb (116 → 8, DIFF, −108;
  cell (20, 32720, 7272), cidx 8) and
  A ec546cfc → B 781099fa (236 → 120, DIFF, −116;
  same cell, cidx 14). Both differing, B byte 0
  {8, 120}.
- (byte 3, byte 2) = (249, 181), status collision:
  the SAME identity pair as (249, 44) — A 682cb5f9 →
  B 6884f5f8 (104 → 104, SAME; cell (20, 32720, 7204),
  cidx 74) — against A 705ab5f9 → B a08de5f4
  (112 → 160, DIFF, +48; cell (20, 32720, 7272),
  cidx 50). One pair carries both status collisions.
- (byte 1, byte 2) = (128, 146), B-value collision:
  A 808092f7 → B a071c6f6 (128 → 160, DIFF, +32;
  cell (20, 32720, 7136), cidx 62) and
  A c08092da → B 80a1f7dd (192 → 128, DIFF, −64;
  cell (20, 32720, 7000), cidx 2, position class
  'first' — the only non-'interior' record among the
  eight). Both differing, B byte 0 {128, 160}.

B byte 0 as a function of the two-byte sub-keys —
NOT A FUNCTION for every key tested:

- (byte 3, byte 1): 214 distinct values, 2 with
  repetition, 2 violating — exactly (249, 44) →
  {104, 128} and (252, 84) → {8, 120}: the key's
  only two repeated values are precisely its two
  AES-NUM-130 near-miss collisions.
- (byte 3, byte 2): 215 values, 1 repeated, 1
  violating — exactly (249, 181) → {104, 160}.
- (byte 1, byte 2): 215 values, 1 repeated, 1
  violating — exactly (128, 146) → {128, 160}.
- (byte 0, byte 1): 209 values, 7 repeated, 5
  violating — (0, 197) → {176, 192}, (64, 150) →
  {0, 128}, (64, 240) → {0, 128}, (128, 136) →
  {64, 128} (the AES-NUM-130 status value, failing
  here too), (192, 0) → {32, 240}.
- (byte 0, byte 3): 168 values, 34 repeated, 27
  violating (sets of size 2–3; the widest keys
  (128, 187) with 6 pairs and (128, 186) with 5,
  both → {0, 128}).

Verdict: B byte 0 is not a function of any two-byte
part of the A word. For the three near-miss keys the
obstruction is exactly the named collisions and
nothing else — each such key repeats on exactly one
or two values and fails on all of them. What B byte 0
is a function of beyond the full word is NOT PROVEN.

## Next

Slice 4.132 — gap 2's broken chain in full (the
7 / 8 / 10 violating first and second acts: which
contexts carry each alternative, and what else in
those contexts differs); the gap-only acts read at
offset and size level (do their offsets recur under
other sizes or channels anywhere in the corpus, and
the outlier run's 31 unique acts likewise); and
B byte 0 against the three-byte sub-keys of the A
word ((byte 3, byte 1, byte 2), (byte 0, byte 1,
byte 2), (byte 0, byte 3, byte 1), (byte 0, byte 3,
byte 2) — exact over the 216 pairs, repetition
counted, violating values in full), with the shared
identity pair A 682cb5f9 → B 6884f5f8 that carries
both status collisions read in full. Host/artifact
analysis only — no physical child.
