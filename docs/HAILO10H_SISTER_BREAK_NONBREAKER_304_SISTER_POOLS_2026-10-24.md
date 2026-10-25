# Sister-pair head breaks, the non-breaker 304 B population, sister-pool subfields (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.38 (AES-NUM-038).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef38.py
(sha256 1ab7fca2…) plus the labelled follow-up hef38b.py
(sha256 b2adbb5e…). Controls: the walk reproduces
AES-NUM-029/032/033/034/035/036/037 EXACTLY (128,787
pooled small actions; 79,001 pooled 24 B bursts; 745,849
pointer actions; 1,504 contexts; trailing distinct
(channel, operand) pairs 2,049).

## The sister pair breaks its head runs with large data actions

- The five non-sister artifacts break EVERY head run
  with the fixed 304 B segment of AES-NUM-037 (6/256/
  180/353/271 occurrences = their context counts, all
  channel 0, one distinct segment per blob artifact,
  six for MiniLM). The sister pair (5ab3537d /
  773470cd, 219 contexts each) NEVER breaks at 304 B.
- A sister head run is instead broken by a LARGE
  action: 215 of 219 breaks in each artifact are
  >= 9,336 B (max 32,784 B), the remaining 4 are a
  528 B action; no break is <= 512 B otherwise and
  none is a small form. Break sizes span 22 (5ab3537d)
  and 21 (773470cd) distinct values, 17 of them common
  to both; of the common sizes 7 counts match exactly
  and 10 differ by 1–6 (e.g. 32776 B: 37/39; 32784 B:
  32/26; 30936 B: 28/28; 26280 B: 19/19). Five sizes
  are private to 5ab3537d, four to 773470cd.
- The breaking segment is almost always UNIQUE per
  context: 216 distinct segments over 219 breaks in
  5ab3537d, 217 over 219 in 773470cd (the only repeat
  is the 528 B form, 1 distinct segment for 4 breaks
  in 5ab3537d, 2 for 4 in 773470cd), and the two
  artifacts share ZERO breaking segments. Channels
  vary across 0/1/2 by size — unlike the channel-0-only
  304 B breakers. Head-run lengths are similarly but
  not identically distributed (5ab3537d: runs 5–10,
  mode 9 with 104; 773470cd: runs 5–10, split between
  8 with 99 and 9 with 72).
- Graded: in the sister pair there is NO fixed head-
  break form at all — the run ends where the context's
  first large (weights-class) data action happens to
  sit, and that action's segment is context data, not
  a reusable skeleton piece. The 304 B breaker's
  absence is a property of these two networks' layout,
  not a missing form.

## The non-breaker 304 B population — eleven singletons on channel 2

- Of the 21 distinct 304 B segments (3,207
  occurrences), the 10 breakers carry 3,196
  occurrences (1,066 of them at breaker positions —
  each breaker also recurs at the other two channel
  positions of its slot). The 11 non-breakers carry
  exactly ONE occurrence each (11 total), all on
  channel 2, in only three artifacts.
- Nine of them sit in blob 0a0d378c at context
  position 21, all with head word
  `0328300200801c15`, word p36 = `0100000000000000`,
  exactly 23 nonzero words, p1 nonzero and
  p30–p35 not all zero: the interleaved sparse-frame
  anatomy of the NB304 aggregate (odd positions carry
  `01007200…`-family words, p20 and p37 distinct for
  every segment). They are a second 304 B species —
  a framed form, not the breaker's walking-pair form.
- The other two (blob 0856a10c and blob 76c3a8ff,
  each at position 12, channel 2) are breaker-LIKE:
  head `082830020000002e` (the breaker's
  `012830020000002e` with its first byte 0x08 in
  place of 0x01), p1 zero, p30–p35 zero, p36 =
  `0000000001000000`, 31 nonzero words. A one-byte
  head variant of the breaker anatomy at a fixed
  non-breaker slot.
- Graded: the non-breaker population is not a pool —
  it is eleven one-off occurrences in two fixed slots
  (position 21 in one artifact, position 12 in two),
  in two anatomies, neither ever reused.

## The sister pools differ ONLY in the enum field — exactly

Per trailing group (AES-NUM-037's four equal-sized,
disjoint position pools), lane 1 splits as little-
endian u16s (flags, enum, const 0x0250, ladder):

- **Ladder is constant within a group** and equals
  the group's skeleton rung: groups 1–5 carry
  0x10f0 / 0x12f0 / 0x14f0 / 0x16f0 / 0x18f0 at ALL
  four positions. Const is 0x0250 in every operand.
- **Flags sets are identical across the four pools**
  in every group (61–63 distinct values; pairwise
  intersections = the full set in all 30 pairs).
- **Enum is the sole separator**: position j of a
  group (j = 0..3) carries enum values exactly
  {0x1000*j, 0x1000*j + 1} — the four pools' enum
  sets are pairwise disjoint (union 8 per group),
  and the low-bit split is identical in all four
  pools of a group (e.g. group 1: 59 low-0 / 39
  low-1 operands in EVERY pool).
- The equivalence is EXACT, not statistical: the
  projection (flags, enum low bit, const, ladder)
  takes the same set of values in all four pools of
  every group, with set size = pool size (98/104/
  103/100/107 — so the projection is also injective
  per pool). Dropping enum from the operand makes
  the pools collide (183–189 cross-pool collisions
  per group); dropping flags or ladder makes none.
- Graded: each group's four sister pools are ONE
  pool written four times under the substitution
  enum_high = position index. Sister-pool identity
  is a single-field relabelling; no hidden flags or
  ladder transform exists.

## What this closes and what it queues

- MEASURED, corpus-wide: the sister pair has no
  fixed head-break form (large unique data actions
  break its runs; size multisets near-identical
  between the sisters, segments disjoint); the
  non-breaker 304 B population is 11 channel-2
  singletons in two fixed slots and two anatomies;
  the trailing sister pools are exact enum-
  relabellings of one another, with ladder pinned
  to the group rung and const fixed.
- NOT established: the meaning of the enum high
  part, the low bit, or either 304 B non-breaker
  anatomy; why the sister networks lack the 304 B
  breaker slot; what the position-21 framed form is.
- NEXT (4.39): enum-relabelling test corpus-wide —
  do body (non-trailing) champion pools partition
  the same way (one pool per enum-high class)?
  The 0a0d378c position-21 framed 304 B form vs
  that artifact's other framed forms; sister
  large-break size multiset vs the artifacts' own
  large-action size census. Host/artifact analysis
  only.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
