# Pair-order vs datum stream, motif blocks pooled, rare-burst datum check (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.48 (AES-NUM-048).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef48.py
(sha256 4757f16c…) plus the labelled follow-up
hef48b.py (sha256 08c76a5a…). Controls reproduce
AES-NUM-029/032/033/034/035/036/037/038/039/040/041/
042/043/044/045/046/047 EXACTLY in both scripts
(128,787 pooled small actions; 79,001 pooled 24 B
bursts; 745,849 pointer actions; 1,504 contexts;
trailing distinct (channel, operand) pairs 2,049;
champion-headed bursts 75,215). Transfers were
sha-gated gzipped part crossings at 373 B (hef48,
whole-file sha verified on-device first try) and
373 B / 200 B for hef48b (the 373 B crossing failed
its whole-file sha and was discarded uncommitted;
the 200 B re-split landed sha-clean). All whole-file
shas verified on-device.

Definitions carried from AES-NUM-045/047: the pair
members are the body champion bursts with lane-1
operands `004000005002802d` (A) and
`008000005002802d` (B); the binary population is the
1,428 normal/reversed contexts (693 normal, 735
reversed); the 76 displaced contexts are excluded
from the function tests. Datum representation note:
hef48.py carried datums as stored-byte hex strings
(opaque tokens — equality and function tests are
representation-invariant); hef48b.py reads the datum
as a little-endian u24 for the numeric frozen-map
check, matching the encoder modules' semantics
(sanity: the frozen channels-1/2 map sends the
special operand 0x2d80025000008000 to 0x56898c, and
datum(0) = 0 under both bases).

## The datum stream does NOT determine the pair order either — and the counterexample is now exact

AES-NUM-047 left three candidate homes for the order
bit: the datum stream, the size stream, or a variable
outside the bursts. Slice 4.48 tests the datum stream
in the same function-test form as the operand stream:

- Single head datums — NO. Grouping the 1,428 binary
  contexts by the datum at any one head ordinal 0–14
  leaves 36–51 mixed keys per ordinal, majority-vote
  accuracy 0.847–0.928 (best: ordinal 8 at 0.9279,
  ordinal 9 at 0.9272, ordinal 14 at 0.9216) — the
  same profile as the operands, as expected where
  datum is a function of operand.
- Head datum sequences — NO, by the same triple.
  The head datum sequence (ordinals 0–14) gives 383
  keys with exactly ONE mixed group, majority
  accuracy 0.9993 (1,427/1,428); the prefix 0–9
  already gives 380 keys with the same single mixed
  group; the datum sequence MINUS the pair gives
  383 keys, the same one mixed group.
- Inside that group the negative is now EXACT. The
  mixed group is again 0856a10c cidx 15 and 27
  (reversed) and cidx 39 (normal). Their datum
  sequences minus the pair are IDENTICAL — one
  distinct value across the three contexts; their
  full datum sequences differ at exactly positions
  15 and 16, which are the pair slots themselves:
  the two pair bursts swap positions and carry their
  datums with them. AES-NUM-047's record that the
  triple's "body DATUM sequences are not equal" is
  thereby refined: outside the pair they are
  byte-identical, and the only datum difference in
  the whole body is the pair swap itself.
- Trivial separations are NOT determination. The
  full ordered datum sequence formally separates
  all 1,428 contexts (384 keys, 0 mixed) — but only
  through the pair slots just described, which is
  the order bit restating itself. The full action-
  size sequence also formally separates (1,111
  keys, 0 mixed), and the combined
  (operand-minus-pair + full sizes) and
  (datum-minus-pair + full sizes) keys separate too
  (1,112 keys, 0 mixed) — but a key that is distinct
  for 1,111 of 1,428 contexts separates any
  labelling; inside the counterexample triple the
  three size sequences are pairwise distinct, with
  first differences at action positions 12/13 and
  35 differing positions (15 vs 27) / 106 differing
  positions (15 vs 39). That is uniqueness, not a
  law, and no size-stream law is claimed from it.
- Head-level combinations — NO. (head operands +
  first-12 sizes), (head operands + head datums)
  and (head datums + first-12 sizes) each still
  leave exactly the one mixed triple (432/383/432
  keys, accuracy 0.9993): the triple shares its
  head operands, its head datums AND its first-12
  action sizes. The pair's own datums are one key
  for all 1,428 contexts (accuracy 0.5147), and the
  universal post-pair coda datum sequence is
  likewise one key — neither carries the bit.

Graded MEASURED, NEGATIVE: the order bit is not a
function of the body datum stream outside the pair
itself. Two of AES-NUM-047's three candidate homes
are now closed (operand stream, datum stream). What
remains: the action/size stream beyond the head
(formally separating only by near-uniqueness — a
law there is NOT PROVEN) or a variable outside the
burst and size streams entirely. Where the bit
lives is still NOT PROVEN.

## The 156 motif pooled: the "shortened" blocks are fixed positions, the leads are private, the channel pattern is a per-index law

Pooled over all 26 intermediate-class middles of
76c3a8ff (312 blocks; exactly 12 per context):

- Leads carry no law. The twelve lead sizes per
  context take 82 distinct values corpus-wide in
  the band 8104–8832, every one a multiple of 8.
  Per block index there are 19–24 distinct leads
  with a modal count of at most 3 of 26; the 26
  lead sequences are all distinct and NONE is
  monotonic (0 strictly increasing, 0
  non-decreasing). The exemplar's tidy 82xx list in
  AES-NUM-047 was one context's draw, not a
  progression. Lead size is a per-(context, block)
  private value in a fixed band — what it encodes
  is NOT PROVEN.
- Block shape is a function of block INDEX, not
  chance. Reading each block as the actions after
  its 3856 (the "after-tuple"):
  blocks 1, 2, 3, 5, 6, 7, 8, 9, 10 are FULL —
  after (32784, 32784, 30480) in 26 of 26 contexts
  each (259 full after-tuples pooled, the rest
  being next-lead values inside blocks 0 and 4).
  Block 0 is the NO-30480 form in 26/26: after
  (32784, 32784, <next block's lead>) — its window
  is (lead, 3856, 32784, 32784) and the next lead
  follows directly. Block 4 is the NO-32784 form
  in 26/26: after (30480, <next lead>, 3856).
  Block 11 is full in 25/26; the exemplar alone
  (cidx 111) truncates it — after (24, 32784,
  32784), running into the middle's end.
  So the "one shortened block" of AES-NUM-047's
  exemplar reading is corrected: EVERY context
  carries exactly two structural variant blocks,
  at fixed indices 0 and 4, of two different
  kinds; the shortened-block frequency is 26/26
  at index 4 (and 26/26 for the block-0 form),
  not an occasional event. The only occasional
  event in the whole motif is the exemplar's
  block-11 truncation (1/26).
- Channels are a fixed per-index pattern. The
  five-action channel tuple (lead, 3856, +1, +2,
  +3) is constant across all 26 contexts at every
  block index (the exemplar's block 11 is the sole
  deviation, (1,1,1,2,2) against (1,1,2,2,2)):
  blocks 0, 1, 4: (0,0,0,0,0); blocks 2, 3, 5:
  (0,0,1,1,1); blocks 6, 7, 8: (1,1,2,2,2);
  blocks 9, 10: (2,2,2,2,2); block 11:
  (1,1,2,2,2). The lead/3856 channel sequence over
  the twelve blocks is 0,0,0,0,0,0,1,1,1,2,2,1
  and the trailing-action channel sequence is
  0,0,1,1,0,1,2,2,2,2,2,2 — in transition blocks
  the lead pair keeps the previous channel while
  the block body steps up. AES-NUM-047's "channels
  progress 0-blocks, then 1, then 2" exemplar
  observation is thus a corpus law, sharpened to
  an exact per-index table.

## The rare-ladder bursts are ordinary champion bursts under the frozen maps — no new datum rule

The rare population (body champion bursts whose
ladder is 0x2a82 or 0x2a8e) is 15 occurrences over
6 distinct (channel, operand) pairs: ladders
{0x2a82: 6, 0x2a8e: 9}, channels {0: 6, 1: 9},
artifacts {76c3a8ff: 12, 5ab3537d: 1, 773470cd: 2}
— the sister pair's last contexts and the 76c3a8ff
anomaly zones, matching AES-NUM-039's exception
record. Operand → datum has zero violations pooled
and per channel. Checked against the frozen
encoders with the channel-appropriate basis
(AES-NUM-026 for channels 1/2, AES-NUM-031 for
channel 0), datum read as little-endian u24:

- Rare bursts: 15/15 occurrences EXACT, 6/6
  distinct pairs EXACT; zero wrong, zero refused.
- Control over the whole body champion population:
  43,631 occurrences EXACT, 1,451 distinct
  (channel, operand) pairs EXACT; zero wrong, zero
  out-of-span refusals. The frozen champion maps
  cover the body champion population completely —
  the rare ladders are inside the maps' span, not
  an exception to them.

Graded MEASURED: the rare-burst datum check
PASSES. No rare-specific datum rule exists or is
needed; the frozen datum component (AES-NUM-026/
031) already encodes these bursts.

## What this closes and what it queues

- MEASURED, NEGATIVE: pair order is not a function
  of the body datum stream outside the pair (the
  0856a10c triple's non-pair datum streams are
  byte-identical; the only datum difference in the
  triple is the pair swap itself — refining
  AES-NUM-047). Head-level champion/datum/size
  combinations still fail on the same triple.
  Full-stream separations are recorded as
  uniqueness/tautology, not laws. The bit's home
  is NOT PROVEN; the size stream beyond the head
  and variables outside the streams remain open.
- MEASURED, with a correction to AES-NUM-047: the
  156 motif's variant blocks are positional —
  block 0 (no 30480) and block 4 (no 32784 pair)
  in 26/26 contexts; blocks 1–3, 5–10 full in
  26/26; block 11 full in 25/26 (exemplar
  truncated). Channel tuples are an exact
  per-index law over all 26 contexts. Lead sizes
  are private per (context, block): 82 values,
  band 8104–8832, all multiples of 8, no
  per-index or progression law.
- MEASURED: rare-ladder bursts (15 occurrences,
  6 distinct pairs) are predicted EXACTLY by the
  frozen channel-appropriate champion datum maps,
  as is the entire body champion population
  (43,631 occurrences, 1,451 distinct pairs, zero
  wrong, zero refused).
- NEXT (4.49): pair-order vs the middle action
  stream (the size-stream law hunt at motif/
  segment level, beyond uniqueness); motif lead
  values vs the contexts' own large-action sizes
  (is a lead a copy of a body size?); block-0 /
  block-4 variant roles vs the standard contexts'
  middles. Host/artifact analysis only — no
  physical child.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
