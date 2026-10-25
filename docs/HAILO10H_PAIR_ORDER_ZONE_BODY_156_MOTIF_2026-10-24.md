# Pair-order determination hunt, zone-pair bodies, 156 middle motif (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.47 (AES-NUM-047).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef47.py
(sha256 ddd81ba0…) plus the labelled follow-up
hef47b.py (sha256 b4a89157…). Controls reproduce
AES-NUM-029/032/033/034/035/036/037/038/039/040/041/
042/043/044/045/046 EXACTLY in both scripts (128,787
pooled small actions; 79,001 pooled 24 B bursts;
745,849 pointer actions; 1,504 contexts; trailing
distinct (channel, operand) pairs 2,049;
champion-headed bursts 75,215). Transfers were
sha-gated gzipped part crossings at 373 B (hef47, one
part rejected and healed by re-splitting at 187 B),
250 B (hef47 first crossing, clean), and 250 B / 200 B
for hef47b (the 250 B crossing failed its whole-file
sha and was discarded uncommitted; the 200 B crossing
landed sha-clean after one part was re-split at
100 B). All whole-file shas verified on-device.

Definitions carried from AES-NUM-045: the pair members
are the body champion bursts with lane-1 operands
`004000005002802d` (A, flags 0x4000) and
`008000005002802d` (B, flags 0x8000); order is normal
(B = A + 1 in body champion ordinal), reversed
(A = B + 1), or displaced. This slice's binary
population is the 1,428 normal/reversed contexts
(693 normal, 735 reversed); the 76 displaced contexts
are excluded from the function tests and no context
is missing the pair.

## Pair order is NOT a function of the champion operand sequence — at any tested granularity

AES-NUM-045 found no correlate of the order bit in
counts, group, parity, or action totals. Slice 4.47
tests operand IDENTITY, the strongest form of the
question: can anything in the champion operand
sequence determine the bit?

Single ordinals — NO. Grouping the 1,428 binary
contexts by the champion operand at any one head
ordinal 0–14 leaves 36–51 mixed keys per ordinal,
with 518–979 contexts sitting in mixed keys;
majority-vote accuracy per ordinal is only
0.847–0.928 (best: ordinal 8 at 0.928, ordinal 9 at
0.927, ordinal 14 at 0.922). No subfield does better:
flags / enum / const / ladder / datum at ordinals 0,
7, 14 are all fully mixed (enum takes 6 keys, every
one mixed; const is a single key). Joint subsets of
the high-accuracy ordinals — (8, 9), (9, 14), (8, 14),
(8, 9, 14), (8, 9, 10, 14), (0, 8, 9, 14), (13, 14) —
still leave 8–24 mixed keys covering 78–377 contexts.

Action-stream keys — NO. The first-12 action sizes
leave 29 mixed keys (608 contexts), the first-middle
action sizes (actions 12–16) 37 mixed keys (325),
the first large action's size 36 mixed keys (1,080);
network group, context index mod 3 and mod 9 are all
fully mixed.

The full head sequence — ALMOST, and the exception
is decisive. Grouping by the head champion sequence
(ordinals 0–14) gives 383 keys with exactly ONE mixed
key covering 3 contexts (head prefix 0–9 alone
already reaches the same pattern: 380 keys, the same
single mixed group). Per artifact, six of seven
artifacts have zero mixed head-sequence groups. The
one mixed group is in 0856a10c: contexts 15 and 27
(reversed, 280 actions each) and context 39 (normal,
279 actions). The follow-up establishes the strength
of this counterexample:

- The three contexts' champion sequences MINUS the
  pair are byte-identical (`champseq-minus-pair`
  equal: True) — not just the head, the whole body
  champion operand stream outside the pair itself.
- Their pair datums are identical (A: `17e560`,
  B: `8c8956` in all three), and their first three
  body datums are identical.
- What differs: their body DATUM sequences are not
  equal, and their action SIZE sequences are all
  distinct (3 distinct size sequences).

So the champion operand stream does not determine
the order bit: the same stream occurs with both
orders. The near-determination (head-sequence
majority accuracy 1,427/1,428 = 0.9993) is real but
is a population statistic, not a law — the head
sequence is a strong proxy for which layer stack a
context carries, and exactly one stack in the corpus
is exercised in both orders. Where the bit lives —
in the datum stream (which provably differs in the
counterexample triple), in the action/size stream
(also distinct there), or in a variable outside the
burst population — is NOT PROVEN, and is the
question slice 4.48 takes up.

One population fact falls out of the hunt for free:
the first-middle champion operands carry NO
information at all, because they are constant. The
five champion ordinals immediately after the pair
(post-pair ordinals 0–4) take exactly ONE operand
sequence in all 1,428 binary contexts of all seven
artifacts — `000000006801002a`, `000000007401002a`,
`00000000b001002a`, `000000009805002c`,
`00000000ec05002c` — and exactly one datum sequence
with it (`10771d`, `539537`, `4c964f`, `8cd04b`,
`c16d0e`). The skeleton unit's tail after the pair
is a universal five-burst coda.

## The zone pairs are mirrors in shape only — their bodies differ outside the rare/pair region as much as inside it

AES-NUM-045 left open whether 76c3a8ff's mirrored
rare-ladder zones (97/105 at 400 actions, 98/106 at
336) are body copies outside the rare/pair region.
They are not. Removing every champion burst whose
operand is a pair member or carries a rare ladder
(0x2a82 / 0x2a8e) from both members of each pair:

- Champion level: 27 outside bursts remain on each
  side; position-wise equality is 12/27 in BOTH
  pairs, the set symmetric difference stays 30 (the
  whole-context value), and the outside sequences
  are not equal. The 12 equal positions are exactly
  the common SUFFIX (outside-champion prefix/suffix
  = (0, 12)): the shared tail is the skeleton coda
  region, the heads share nothing position-wise.
- Action level: removing the region's burst actions
  leaves 394/394 (97/105) and 332/332 (98/106)
  actions; size position-equality is 151 and 103,
  and the size multiset symmetric differences are
  unchanged at 154 and 110 — the region contributed
  nothing to the difference, because its actions are
  all 24 B bursts. The last-28 size block is equal
  in both pairs (the end-anchored trailer); the
  first-12 sizes are equal in 97/105 but NOT in
  98/106.

Graded MEASURED: outside the rare/pair region the
zone pairs share only the universal skeleton tail
(12 champion positions, the 28-action end block,
55 size-suffix positions) and their counts. Their
data bodies are as different outside the region as
inside it. The mirroring is a property of the zone
SHAPE (counts, rare operand sets, champion counts),
not of shared body content.

## The 156 middle is a 12-block size motif with private payloads — not a repeated unit

AES-NUM-045 described the 156-action intermediate
middle (76c3a8ff, contexts 111 + 9k, 26 contexts) as
a "12-fold repeated unit" from its size counters.
Slice 4.47 anatomizes the segments:

- No exact period exists: the exemplar's (cidx 111)
  88-action middle has smallest period 88 in both
  its size sequence and its segment-identity
  sequence. The repetition is a MOTIF, not a unit.
- The motif: a 3856 B action occurs exactly 12 times
  in every one of the 26 middles (312 pooled). In the
  exemplar, 10 of the 12 windows starting one action
  before each 3856 are the five-action block
  (82xx, 3856, 32784, 32784, 30480) — the lead size
  varies per block (8200, 8216, 8232, 8240, 8272,
  8288, 8304, 8312 in the exemplar; pooled top shapes
  run 8248–8456). The two exceptions are structural:
  one shortened block (8232, 3856, 30480 — the
  32784 pair absent) and the final block, which runs
  into the middle's end (8288, 3856, 24, 32784,
  32784). Channels progress across the exemplar's
  blocks (0-blocks, then 1, then 2), consistent with
  the enum = channel law of AES-NUM-040.
- The payloads are private: pooled over the 26
  middles, 2,288 segment occurrences hold 1,924
  distinct segments; 1,906 segments occur exactly
  once. Per middle position, the distinct-segment
  count across the 26 contexts averages 21.9 of 26,
  and in the motif region (positions 26–85) it is 26
  at nearly every position. Only 8 middle positions
  are universal (one segment in all 26 contexts):
  positions 1, 3, 4, 6, 12, 16, 17, 20, all in the
  pre-motif head of the middle, of sizes 24, 24,
  528, 24, 24, 24, 80, 80.
- The champion operand grouping of AES-NUM-045 is
  exactly the order split: the 26 contexts form two
  champion-sequence groups — cidx 111 alone (the
  exemplar; the class's only NORMAL-order context)
  and the other 25 (all reversed, one shared champion
  sequence, but 25 distinct middle identity
  sequences). The motif template is shared; no two
  reversed contexts share a middle.

Graded MEASURED: the 156 middle is a twelve-block
size/channel motif — (variable 82xx–84xx lead, 3856,
32784, 32784, 30480), with one shortened block and a
truncated final block in the exemplar — carrying
per-context private payload segments, over a
pre-motif head whose 8 universal positions are the
only segment-level constants. AES-NUM-045's
"12-fold repeated unit" wording is corrected: the
unit repeats in shape, never in bytes.

## What this closes and what it queues

- MEASURED, NEGATIVE: the 0x2d80 pair's order bit is
  not a function of the champion operand sequence —
  not of any single head ordinal or subfield, not of
  joint high-accuracy subsets, not of the action-size
  keys tested, and not even of the full non-pair
  champion stream (the 0856a10c cidx 15/27/39
  counterexample triple: identical non-pair champion
  stream and pair datums, both orders). Head-sequence
  grouping is a 0.9993-accurate proxy, not a law.
- MEASURED: the five champion bursts after the pair
  are a universal constant coda (one operand sequence
  and one datum sequence in all 1,428 binary
  contexts, all seven artifacts).
- MEASURED: the anomaly-zone pairs (97/105, 98/106)
  share only the universal skeleton tail and their
  counts outside the rare/pair region; their bodies
  differ outside as much as inside.
- MEASURED, with a correction to AES-NUM-045: the
  156 middle is a 12-block motif in size/channel
  shape (312 3856-led blocks over 26 contexts) with
  private payload segments — 1,924 distinct segments
  in 2,288 occurrences, only 8 universal positions,
  all pre-motif.
- NOT established: where the order bit is encoded
  (the counterexample triple's datum and size
  sequences both differ — either could carry it);
  what the motif's lead size encodes; the zones'
  program role.
- NEXT (4.48): pair-order vs the body DATUM sequence
  (function tests on head datums and the full datum
  stream, pooled and in the counterexample triple's
  stack); combined champion + size-stream function
  test; motif block anatomy pooled (lead-size
  distribution and law, channel progression across
  all 26 contexts, shortened-block frequency); rare-
  burst datum check against the frozen champion map.
  Host/artifact analysis only — no physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
