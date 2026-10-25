# Displaced-pair gap contents, cc9b9d1c parameter recurrence, high-7 lane-1 vs pointer offset (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.42 (AES-NUM-042).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef42.py
(sha256 af908abf…) plus the labelled follow-up hef42b.py
(sha256 87ecd348…). Controls: the walk reproduces
AES-NUM-029/032/033/034/035/036/037/038/039/040/041
EXACTLY (128,787 pooled small actions; 79,001 pooled
24 B bursts; 745,849 pointer actions; 1,504 contexts;
trailing distinct (channel, operand) pairs 2,049;
champion-headed bursts 75,215). hef42b's reduced
controls also reproduce exactly (79,001 bursts;
1,504 contexts). One uncached first version of hef42
was killed uncommitted after ~5 minutes (its segment
scan copied every occurrence); the cached version
(per-(offset,size) segment cache) completed in 64 s
and is the version of record.

## The gap bursts are the context's own ladder rungs — displacement is a reordering, not an insertion

AES-NUM-041 left the 0x2d80 pair displaced in 76 of
1,504 contexts, dominated by two patterns: A (flags
0x4000) at champion ordinal 12 with B (flags 0x8000)
at 16 (+4, 39 contexts), and A at 16 with B at 14
(−2, 28 contexts). Slice 4.42 reads the bursts at the
gap ordinals, subfield by subfield (flags / enum word
/ const 0x0250 / ladder, u16 slots of the operand):

- +4 pattern (39 contexts; 0a0d378c 14, 76c3a8ff 25).
  Gap ordinal 13: channel 1 in 39/39, enum 0x1000 in
  39/39, ladder 0x14f0 in 39/39, flags 0x3400
  (76c3a8ff) / 0x3c00 (0a0d378c). Gap ordinal 14:
  channel 0, enum 0x0000, ladder 0x16f0 in 39/39,
  flags 0x0000 / 0x1000 by artifact. Gap ordinal 15:
  channel 0, enum 0x0000, ladder 0x18f0 in 39/39,
  flags 0x1400 / 0x1000 (one 0x0400). The three gap
  bursts are therefore one fixed ladder run —
  0x14f0 on channel 1, 0x16f0 and 0x18f0 on channel
  0, each in its class = channel enum form
  (AES-NUM-040) with const 0x0250 — deterministic
  across all 39 contexts, varying only in flags by
  artifact. A sits at ordinal 12 inside this run,
  between the run's own 0x12f0 (ordinal 10) and
  0x14f0 channel-0 (ordinal 11) bursts and the
  channel-1 0x14f0 copy at 13.
- −2 pattern (28 contexts; 76c3a8ff 26, one each in
  0a0d378c and 5ab3537d). The single gap burst at
  ordinal 15 is channel 2 in 27/28, enum 0x2001 in
  26/28, ladder 0x18f0 in 27/28, flags 0x8800 in
  25/28: the channel-2 copy of the 0x18f0 rung,
  sister to the channel-1 copy at ordinal 13 (flags
  0x8800, enum 0x1001, ladder 0x18f0 in 25/28). B
  sits between the two channel copies of its rung.
- Burst counts do not change: champion totals are
  50 in all 39 +4 contexts and in 27 of 28 −2
  contexts (one 51). The nine scattered patterns
  behave the same way where they are singletons —
  their gap bursts are likewise single ladder rungs
  in sequence ((15,10) and (16,10): rungs 0x10f0,
  0x12f0, 0x14f0, 0x16f0, 0x18f0 on channel 0); the
  two 52-burst exceptions, (15,17) in 773470cd and
  (18,15) in 76c3a8ff, carry the rare ladders
  0x2a82 / 0x2a8e in their gaps.
- Multiset check (hef42b): a displaced context's
  champion-operand multiset is no further from its
  artifact's modal adjacent multiset than adjacent
  contexts are from each other (76c3a8ff: displaced
  symmetric differences 36–42 against an adjacent
  mean of 54.6; 0a0d378c: displaced 62–70 against
  adjacent mean 58.6, max 70). Context multisets
  are per-layer, so this test alone cannot prove a
  permutation; combined with the unchanged totals
  and the gap bursts being the run's own rungs in
  their regular enum forms, the graded reading is
  that displacement REORDERS the pair within a
  fixed ladder scaffold — no foreign bursts are
  inserted, and the gap is never a distinct block.

Graded MEASURED: gap contents as above; the
reordering reading is MEASURED as a population
fact (fixed totals, own-rung gaps, no multiset
excess). Why these contexts emit the pair out of
its adjacent order is NOT PROVEN.

## The cc9b9d1c 464 B parameter DOES recur outside the 464 B form — in a denser slot pattern, in the 232–360 B classes

AES-NUM-041 found the cc9b9d1c 464 B form carries one
per-segment parameter byte (0xb0 / 0x64 / 0x70 /
0xf8) at byte 2 of 18 words (positions 1, 15, 17,
19, 21, 24, 27, 33, 35, … 53; the 0x70 segment
shows 19 because the template head itself carries
0x70 at byte 2 — re-verified here, positions
[0, 1, 15, 17, 19, …]). Slice 4.42 tests the same
slot (byte 2 of each 8-byte word) across every
pointer-action segment class in cc9b9d1c:

- Raw recurrence is meaningless at data scale: the
  four values are ordinary data bytes (distinct-
  segment-weighted byte-2 totals in cc9b9d1c:
  0xf8 1,524,740; 0xb0 878,813; 0x70 507,414;
  0x64 323,781), and 93,594 non-464 segment
  occurrences carry ≥3 hits of one value purely by
  density (large classes >4,096 B: 88,210 of 93,171
  occurrences, 94.7%; the top 32,784 B segments
  carry 0x70 alone 421 times). Other artifacts
  pooled show the same densities.
- The STRUCTURED recurrence is in the small
  classes. Of cc9b9d1c's ≤512 B population (7
  classes, 2,573 occurrences), 23 distinct segments
  carry ≥5 hits of a single parameter at byte 2.
  Setting aside the 464 B segments themselves (4)
  and the 80 B class (0x70 at 8–10 of its 10 words
  in 8+ segments — a constant template byte, the
  same in every segment, not a per-segment
  parameter), the remaining family is the
  232 / 296 / 312 / 328 / 360 B classes: distinct
  segments whose single parameter sits at positions
  [1, 2, …, 12, 14, 16, 18, …] — a DENSER slot
  pattern than the 464 B form's — with hit counts
  18 (232 B, param 0xb0), 22 (296 B, 0x64), 23
  (312 B, 0xf8, two segments), 24 (328 B, 0x64,
  two segments), 26 (360 B, 0x70 and 0x64). All
  four 464 B parameter values appear as parameters
  of these smaller segments, one parameter per
  segment, exactly as in the 464 B form.
- In the large classes the slot pattern does not
  exist: over a sample of 40 distinct 32,784 B
  segments, the 0x70 hit-position sets have empty
  intersection (union 176, per-segment counts
  0–6 in the sample's first positions of the
  walk) — positional scatter, not slots.

Graded MEASURED: the parameter mechanism is a
family property of the structured small forms in
cc9b9d1c (232–464 B), with a size-dependent slot
pattern (dense [1..12, evens] in 232–360 B, the
464 B form's sparser set at 464 B); it is NOT a
corpus-wide slot law, and at data scale the same
byte values are unremarkable payload. What the
parameter encodes, and whether the 232–360 B
classes share the 464 B form's template constants
beyond the parameter slots, is NOT PROVEN.

## The high-7 lane-1 field is not an address: no subfield tracks the pointer offset numerically

AES-NUM-041 left the non-champion families' dominant
operand value, high nibble 7 (1,839 bursts, 345
distinct operands, 68 lane-0 families), with the
question whether the 0x7… word is an address-like
field co-varying with the burst's pointer offset.
Slice 4.42 tests every numerical form of that claim:

- No exact formula: no subfield (flags, enum word,
  const word, ladder word) equals offset & 0xffff,
  (offset >> 3) & 0xffff, or (offset >> 6) & 0xffff
  in any of the 1,839 bursts; offset // 24 matches
  each subfield in exactly 1 burst (chance).
- No monotonicity: in each of the ten largest
  families (28–34 distinct (offset, operand) pairs),
  NO subfield is monotonic — increasing or
  decreasing — in the offset.
- Weak, uniform correlation only: Pearson offset
  correlation is −0.2248 for flags, enum, const,
  AND ladder identically, and −0.1575 for the
  datum. The identity across subfields is itself
  the finding: within a family the four subfields
  are not independent fields — in every large
  family the distinct counts of flags, enum, const,
  ladder, and full operand are all EQUAL (e.g.
  14 = 14 = 14 = 14 = 14 over 115 bursts), so each
  distinct operand is one indivisible unit whose
  every subfield changes when any does.
- The one perfect function, offset → operand
  (654 distinct offsets, zero offsets with more
  than one operand, per-artifact as well as
  pooled), is segment identity, not an encoding:
  the burst's bytes are read from that offset, so
  equal offsets trivially yield equal bursts. It
  is recorded here only to close the route — it
  must never be cited as address evidence.
- No context ever contains two bursts of the same
  high-7 family (within-context same-family
  consecutive pairs: 0), so no intra-context
  offset ladder exists to read either.

Graded MEASURED as a negative: the high-7 operand
slot is NOT an address-like field co-varying with
the pointer offset in any tested numerical sense.
The operand behaves as a single co-varying unit —
the same shape as the champion's operand, whose
(lane1 → datum) map is a GF(2)-linear function of
the whole operand (AES-NUM-022/023). What field
the 0x7… high value itself is remains NOT PROVEN.

## What this closes and what it queues

- MEASURED, corpus-wide: the displaced 0x2d80
  pair's gaps are the contexts' own ladder rungs
  in fixed enum = channel forms (0x14f0 ch1 /
  0x16f0 ch0 / 0x18f0 ch0 for +4; the 0x18f0 ch2
  copy for −2), burst totals unchanged — a
  reordering inside a fixed scaffold, no inserted
  block; the cc9b9d1c parameter mechanism recurs
  outside the 464 B form in the 232–360 B classes
  under a denser slot pattern, while at data scale
  the same values are ordinary payload bytes; the
  high-7 operand is not an address field — no
  formula, no monotonicity, one indivisible
  co-varying unit per family.
- NOT established: why displaced contexts reorder
  the pair; what the parameter byte encodes; the
  232–360 B classes' template relationship to the
  464 B form beyond the parameter slots; the
  high-7 operand's field identity.
- NEXT (4.43): the 232–360 B parameter family's
  template anatomy vs the 464 B form (shared
  constant words outside the parameter slots; a
  head-byte pairing like the 464 B form's byte 6);
  the high-7 families' operand → datum function
  and GF(2) affine test (the champion treatment,
  AES-NUM-027 method); displaced contexts vs
  adjacent contexts outside the pair region
  (context type difference). Host/artifact
  analysis only.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
