# Body enum relabelling, the framed 304 B tail of the 464 B form, sister census (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.39 (AES-NUM-039).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef39.py
(sha256 9d29ddc2…) plus the labelled follow-up hef39b.py
(sha256 323ab584…). Controls: the walk reproduces
AES-NUM-029/032/033/034/035/036/037/038 EXACTLY (128,787
pooled small actions; 79,001 pooled 24 B bursts; 745,849
pointer actions; 1,504 contexts; trailing distinct
(channel, operand) pairs 2,049). Body = champion-headed
24 B bursts outside the trailing 21 positions: 43,631
bursts, 1,451 distinct (channel, operand) pairs = 1,451
distinct operands (channel-exclusivity of AES-NUM-037
holds here too).

## Body champion pools ARE exact enum relabellings, per ladder rung

Lane 1 splits as in AES-NUM-038 (flags, enum, const,
ladder as little-endian u16s). Grouping the body's
distinct operands by ladder:

- The five skeleton rungs (0x10f0 / 0x12f0 / 0x14f0 /
  0x16f0 / 0x18f0) each split into exactly THREE pools
  by enum high part (enum >> 12 ∈ {0, 1, 2}), with
  pool sizes equal within each rung: 89/89/89,
  93/93/93, 98/98/98, 89/89/89, 108/108/108 distinct
  operands (rung totals 267/279/294/267/324 = 1,431).
- In every one of the five rungs the test is EXACT,
  the same shape as the trailing sister pools: the
  flags sets are identical across the three pools;
  the projection (flags, enum low bit, const, ladder)
  takes the same set of values in all three pools and
  is injective per pool; const is 0x0250 throughout;
  dropping enum produces 116–128 cross-pool collisions
  per rung, dropping flags produces none. Enum values
  per pool are exactly {0x1000·j, 0x1000·j + 1} for
  pool j, with the low-bit split carried identically.
- The difference from the trailing block is only the
  pool count: body rungs carry three enum classes
  (j = 0..2), the trailing groups carry four
  (j = 0..3, AES-NUM-038). Grouping by (channel,
  ladder) instead of ladder alone collapses the
  structure: only ONE (channel, ladder) group in the
  whole body carries more than one enum class — the
  0x2c00 exception group below. Enum class and
  channel are therefore linked in the body pools;
  the exact class↔channel mapping is measured
  directly in slice 4.40.
- Graded: enum relabelling is a corpus-wide law of
  champion operands, not a trailing-block accident:
  one pool per (ladder rung × enum-high class), the
  classes written from a single pool by the
  substitution enum_high = class index.

## The 20 exceptions are not a pool — 14 invariant singletons plus 6 rare operands

The remaining 20 distinct body operands (21,071
bursts) do not fit the rung pattern:

- 14 of them occur EXACTLY once per context (1,504
  bursts each = 21,056 bursts), each with exactly ONE
  distinct datum corpus-wide. Two are the known
  0x2d80 special-slot pair (flags 0x8000 / 0x4000,
  const 0x0250, ladder 0x2d80, datums 0x56898c /
  0x60e517 — the skeleton-unit positions 10–11 pair
  of AES-NUM-019, here counted in the body because
  the skeleton unit is not part of the trailing
  block). The other twelve sit at ladders 0x2900
  (1 operand), 0x2a00 (3) and 0x2c00 (8), mostly on
  channel 0 with flags 0x0000 and enum 0x0000 (one
  carries enum 0x8000, one flags 0x0fff, two flags
  0x0001) and a per-operand const (0x0030…0x17d8).
  These are fixed per-context slots, not pool
  members: a single operand, a single datum, no
  relabelling partners.
- The other 6 are rare (2–4 bursts each, 15 bursts
  total) at ladders 0x2a82 / 0x2a8e — the ladder
  family of the single-context anomaly recorded in
  AES-NUM-018.
- The main pattern therefore covers 1,431 of 1,451
  distinct body operands and exactly 15 bursts per
  context (22,560 bursts); the invariant singletons
  add exactly 14 per context.

## The position-21 framed 304 B form is the tail of the 464 B form — not kin to the 176 B / 424 B frames

In blob 0a0d378c (the only artifact holding the
framed 304 B form, AES-NUM-038):

- The framed 304 B segments (9 distinct, 9
  occurrences) share exactly TWO distinct non-zero
  words with that artifact's 176 B framed population
  (43 distinct segments) — `0100000000000000` and
  `0000000001000000`, both generic markers — and
  exactly ONE with its 424 B population (150
  distinct): `0100000000000000` alone. Their dominant
  vocabularies are different families: the framed
  304 B words are the `01007200…` interleaved family
  (81 of its 342 word slots carry prefix 01007200),
  the 176 B frames run on `02000000…` words, and the
  424 B frames on the `01000e00…` / `01000000…`
  marker-data alternation of AES-NUM-032. Per-position
  profiles share no structure beyond zero runs.
- The same artifact holds a 464 B form: 7 distinct
  segments, 7 occurrences, all with head
  `0328700300801c15` (the framed 304 B head
  `0328300200801c15` with its size words grown from
  304 to 464). All 7 share one template, varying
  only at words 40 and 57. The framed 304 B body
  (its words 1–37) appears INSIDE the 464 B form at
  words 21–57: the same constant words in the same
  order, its two variable words (the `ff…` word and
  the 3-byte trailer) sitting at the corresponding
  shifted positions 40 and 57. 19 of the framed
  304 B form's distinct non-zero words — all of its
  constant template words — are shared with the
  464 B population; none of its variable words are.
- Corpus-wide the 464 B size is rare: 12 occurrences
  in 3 artifacts (0a0d378c 7, cc9b9d1c 4, 0856a10c 1),
  with different heads in the other two artifacts —
  the embedded-tail identity is measured for the
  0a0d378c variant only.
- Graded: in 0a0d378c the position-21 framed 304 B
  form and the 464 B form are ONE template at two
  lengths — the 304 B form is the 464 B form's tail
  component standing alone (a 20-word preamble
  precedes it in the long form). It is not a member
  of the 176 B or 424 B framed families.

## Sister large-break sizes against the sisters' own large-action censuses

Large = pointer actions of size > 512 B. Each sister
holds ≈109,79k of them (5ab3537d: 109,789 actions in
200 distinct sizes; 773470cd: 109,790 in 196; 179
sizes are common to both and 113 of those have
EXACTLY equal census counts, the sisters' totals
differing by one action):

- The break sizes are a thin, skewed slice of that
  census: 22 / 21 distinct sizes ever break a head
  run, and the 178 / 175 sizes that NEVER break carry
  72.6 % / 72.5 % of all large occurrences (the
  pervasive recurring bulk sizes — 1552 B ×14,768,
  3088 B ×7,556, … — are never first in a context).
- Most breaks are census-exhaustive: 13 / 14 break
  sizes have census count EQUAL to their break count
  (131 / 135 of the 219 breaks) — every occurrence
  of those sizes in the artifact is a head break.
  They are rare sizes that exist only as a context's
  first large action.
- The remaining 9 / 7 partial sizes (88 / 84 breaks)
  are dominated by the two pervasive near-cap sizes:
  32784 B breaks 32 / 26 times out of 29,619 / 29,621
  occurrences (ratio ≈0.001) and 32776 B 37 / 39 out
  of 124 / 127 (≈0.30); the 528 B form sits at
  4 / 127 in both sisters.
- Graded: a sister head run ends at the first large
  action of its context, and the size of that action
  is drawn from the rare tail of the artifact's own
  large census, not from its bulk: the bulk sizes
  recur too deep in contexts ever to be first, and
  most first-large sizes occur nowhere else.

## What this closes and what it queues

- MEASURED, corpus-wide: body champion pools are
  exact enum relabellings per ladder rung (three
  classes per rung, flags/projection equality exact,
  injective), with the 20 non-pool exceptions fully
  enumerated (14 invariant once-per-context
  singletons incl. the 0x2d80 pair, 6 rare operands);
  in 0a0d378c the framed 304 B form is the tail
  component of the 464 B form and shares no family
  vocabulary with the 176 B / 424 B frames; sister
  head-break sizes are the rare tail of the sisters'
  own large censuses (most break sizes census-
  exhaustive; never-break sizes carry ≈72.5 % of
  large occurrences).
- NOT established: the meaning of the enum high
  part or low bit; why body rungs carry three enum
  classes where trailing groups carry four; what
  the 464 B form's 20-word preamble encodes, or the
  framed form's variable words; why 14 body slots
  are invariant singletons.
- NEXT (4.40): the three-vs-four enum-class question
  (body rung pools by channel — which class is
  missing per channel, vs the trailing groups'
  channel pattern); the 464 B preamble anatomy vs
  the framed 304 B head words; the 14 invariant
  body singletons' positions within their contexts.
  Host/artifact analysis only.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
