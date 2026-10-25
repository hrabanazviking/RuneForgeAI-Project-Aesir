# Class↔channel mapping, the 464 B preamble, invariant singleton positions (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.40 (AES-NUM-040).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef40.py
(sha256 5aeb68fb…) plus the labelled follow-up hef40b.py
(sha256 dd9a13ad…). Controls: the walk reproduces
AES-NUM-029/032/033/034/035/036/037/038/039 EXACTLY
(128,787 pooled small actions; 79,001 pooled 24 B bursts;
745,849 pointer actions; 1,504 contexts; trailing distinct
(channel, operand) pairs 2,049). Champion-headed bursts
total 75,215 (body 43,631 + trailing 31,584).

## In the body, enum class IS the channel — exactly, on every rung

Grouping the body's distinct champion operands by
(ladder rung, channel) and by (ladder rung, enum class),
where class = enum >> 12 as in AES-NUM-039:

- Every one of the five skeleton rungs (0x10f0 / 0x12f0 /
  0x14f0 / 0x16f0 / 0x18f0) splits by channel into exactly
  one class per channel, and the mapping is the identity:
  channel 0 → class 0, channel 1 → class 1, channel 2 →
  class 2. Pool sizes are the rung sizes of AES-NUM-039
  in every cell (89 / 93 / 98 / 89 / 108 distinct operands
  per (rung, channel)).
- Read the other way, every (rung, class) group lives on
  exactly one channel — the same identity. The three
  body enum classes of AES-NUM-039 are therefore not an
  independent labelling: a body pool is one pool per
  (rung × channel), and the enum high part is written
  equal to the channel index.
- The non-rung body groups are all class 0 (ladders
  0x2900 ch0 ×1, 0x2a00 ch0 ×3, 0x2a82 ch0 ×3 rare,
  0x2a8e ch1 ×3 rare, 0x2d80 ch1/ch2 ×1 each), with ONE
  exception: ladder 0x2c00 on channel 0 carries classes
  {0, 8} (7 + 1 operands). That is the single
  multi-class (channel, ladder) group recorded in
  AES-NUM-039 — the class-8 member is the invariant
  singleton with enum 0x8000 (see below).

## The trailing fourth class is not a fourth channel — it shares channel 0

Per trailing position t (AES-NUM-036/037 populations),
channel and class are both single-valued in all 1,504
contexts:

- t0: (channel 0, class 0), the single invariant operand.
- Each group of four (t1–t4, t5–t8, t9–t12, t13–t16,
  t17–t20) cycles (0, 0), (1, 1), (2, 2), (0, 4): the
  first three positions repeat the body identity
  (class = channel), and the fourth position returns to
  channel 0 carrying class 4.
- So the trailing block's four enum classes (AES-NUM-038)
  are three channels plus a fourth logical slot that
  rides channel 0 and is distinguished only by its enum
  value 0x4000 and its group position. Corpus-wide the
  class-4 population is exactly those five closing
  positions: 512 distinct operands (98+104+103+100+107).

## Enum high values are exactly {0, 1, 2, 4, 8} — a bit pattern, never a counter

Over all 75,215 champion bursts the distinct enum-high
values are 0 (36,111 bursts, 612 operands), 1 (15,040,
592), 2 (15,040, 592), 4 (7,520, 512) and 8 (1,504, 1).
No other value occurs — in particular class 3, the value
a four-class counter would need for the trailing fourth
slot, NEVER occurs anywhere in the corpus. The observed
enum values are 0x0000 / 0x1000 / 0x2000 / 0x4000 /
0x8000: a single bit (or none) in the high nibble.
Graded MEASURED as a pattern — the enum high nibble
behaves as a bit flag, not an ordinal counter; what the
bit means is NOT PROVEN. Class 8's sole operand is the
enum-0x8000 invariant singleton at ladder 0x2c00.

## The 464 B preamble is a constant 21-word header; the framed head is not in it

In blob 0a0d378c (7 distinct 464 B segments, 7
occurrences; AES-NUM-039 populations):

- The whole 464 B form is constant except at exactly
  two words — 40 and 57, the variable words already
  known from the tail embedding. Its first 21 words
  (the preamble before the framed-304 tail at words
  21–57) are therefore a single fixed header: 14
  distinct words (13 non-zero + zero), with zero words
  at positions 5, 6, 8, 9, 12, 13 and the interleaved
  `01007200…` family entering inside the preamble
  itself at words 15, 17, 19 (and word 1).
- The preamble shares exactly THREE distinct words
  with the framed 304 B population: zero and the two
  generic markers `0100000000000000` and
  `0000000001000000`. The framed form's head word
  `0328300200801c15` is NOT a preamble word; the 464 B
  form's own head `0328700300801c15` differs from it
  only in the size fields (0x87003 vs 0x83002 in the
  size words). The head is a size-bearing variant of
  the same template head, not a shared component.
- The tail embedding of AES-NUM-039 is re-verified
  exhaustively: all 63 framed × 464 segment pairs agree
  at exactly 35 of the 37 tail positions — the only
  disagreements are the two variable words.
- Corpus-wide the 464 B size stays rare (12
  occurrences, 3 artifacts). The other two artifacts'
  forms differ: cc9b9d1c's four segments carry four
  DISTINCT heads (`01287003…` family) and 0856a10c's
  single segment its own (`0328700300801117`). The
  preamble anatomy above is measured for the
  0a0d378c variant only.

## The 14 invariant singletons: twelve are end-anchored at fixed offsets, the 0x2d80 pair is not

The AES-NUM-039 identification (body operands occurring
exactly once per context, one datum each) recovers
exactly 14 operands. They split cleanly in two:

- The twelve at ladders 0x2900 (1), 0x2a00 (3) and
  0x2c00 (8) — all on channel 0 — are END-ANCHORED:
  each has exactly ONE from-end action offset across
  all 1,504 contexts (25, 27, 29, 33, 34, 41, 42, 45,
  46, 50, 52, 53 — all distinct), one fixed
  skeleton-relative offset, and fixed predecessor and
  successor action sizes (1,504 / 1,504 each). Their
  absolute action index varies (103 distinct values)
  only because context length varies (103 distinct
  lengths). Ten of them sit in the body region and
  appear in ONE invariant order in every context —
  the 0x2a00 trio by const (0x0168, 0x0174, 0x01b0),
  then the 0x2c00 seven (0x0598, 0x05ec, 0x0820,
  0x0874, 0x1384, 0x138c, 0x176c). The remaining two
  are the two 24 B slots inside the trailing block's
  own fixed head sequence (AES-NUM-035): const 0x17d8
  at trailing position 0 and const 0x0030 at position
  2 (the 24 / 64 / 24 head). Together with the quartet
  and the trailing 28, these twelve are part of the
  fixed end block of every context.
- The 0x2d80 special-slot pair (flags 0x4000 / 0x8000,
  channels 1 / 2) also occurs exactly once per context
  in the body population, but is NOT end-anchored
  there: 22–24 distinct from-end offsets each, variable
  neighbours (large data actions), and an action-index
  separation that ranges −32…+49 with both orders
  occurring (738 / 766 contexts). Their fixed home is
  the 22-burst skeleton unit (indices 10–11,
  AES-NUM-019; the complementary-positions splitter of
  AES-NUM-022) — in the body population they present
  as a roaming complementary pair, not as end-block
  furniture.

## What this closes and what it queues

- MEASURED, corpus-wide: in the body, enum class =
  channel index exactly (five rungs × three channels,
  no exceptions among rung pools); the trailing fourth
  class (0x4000) shares channel 0 and is a position
  slot, not a channel; enum-high values corpus-wide
  are exactly {0, 1, 2, 4, 8} — single-bit values, with
  class 3 never occurring; the 464 B preamble is a
  constant 21-word header sharing only zero + two
  generic markers with the framed 304 B form, whose
  head word it does not contain; twelve of the
  fourteen invariant singletons are end-anchored at
  fixed distinct from-end offsets in one invariant
  order (two of them inside the trailing head), while
  the 0x2d80 pair roams in the body population.
- NOT established: what the enum bit, the enum low
  bit, or any preamble word means; why the trailing
  cycle needs a fourth slot on channel 0; the
  preamble anatomy of the cc9b9d1c / 0856a10c 464 B
  variants.
- NEXT (4.41): enum-bit test on the non-champion
  lane-0 families (do their operands' enum highs also
  live in {0,1,2,4,8} and follow channel?); the
  0x2d80 body pair's burst-ordinal separation vs its
  skeleton-unit adjacency; 464 B preamble anatomy for
  the cc9b9d1c four-head variant. Host/artifact
  analysis only.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
