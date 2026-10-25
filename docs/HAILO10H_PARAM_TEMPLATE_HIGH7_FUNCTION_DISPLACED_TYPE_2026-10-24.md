# Parameter-family template anatomy, high-7 datum function + affine test, displaced-context type (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.43 (AES-NUM-043).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef43.py
(sha256 92e8fd98…) plus the labelled follow-ups
hef43b.py (sha256 eb2eea94…) and hef43c.py (sha256
e2644a42…). Controls: hef43 reproduces
AES-NUM-029/032/033/034/035/036/037/038/039/040/041/042
EXACTLY (128,787 pooled small actions; 79,001 pooled
24 B bursts; 745,849 pointer actions; 1,504 contexts;
trailing distinct (channel, operand) pairs 2,049;
champion-headed bursts 75,215); hef43b/43c reduced
controls also reproduce exactly (79,001 bursts; 1,504
contexts). One hef43c transfer chunk was corrupted in
re-emission, rejected at schema validation, and a
verbatim retry landed clean; all whole-file shas
verified on-device.

## The 232–360 B family and the 464 B form are one construction, sharing no substantive constant word

AES-NUM-042 left the cc9b9d1c parameter family's eight
small segments (232 B ×1, 296 B ×1, 312 B ×2, 328 B ×2,
360 B ×2; each occurring exactly once, one parameter
per segment) with two open questions: what constants
they share with the 464 B form outside the parameter
slots, and whether a head byte pairs with the parameter
the way the 464 B form's byte 6 does. Both are now
answered, plus the slot pattern is exact:

- Slot pattern, exact in all eight segments: the
  parameter sits at byte 2 of word positions 1–12 and
  of every even position up to (words − 5); the final
  four words never carry it. Hit counts equal slot
  counts exactly (18 / 22 / 23 / 24 / 26 by size). The
  464 B form's sparser set (AES-NUM-041) is a different
  pattern over the same slot (byte 2 of a word).
- Head byte 6 pairs with the parameter across the
  WHOLE family — all twelve cc9b9d1c segments (eight
  small + four 464 B): 0x64 ↔ 0x19, 0x70 ↔ 0x1c,
  0xb0 ↔ 0x2c, 0xf8 ↔ 0x3e, a bijection (byte 6 is a
  function of the parameter and vice versa; verified
  per size class from the segment heads). No other
  head byte is a function of the parameter: byte 1 is
  0x28 and bytes 4–5 are zero in every family head;
  bytes 0, 2, 3, 7 vary independently (byte 7 is
  size-dependent: 0x17 / 0x19 / 0x11 / 0x13 families).
  The AES-NUM-041 pairing, measured there on the
  464 B form alone, is a family law.
- Word-exact sharing outside the parameter slots is
  NIL beyond the generic: the eight small segments'
  non-parameter word vocabulary is 29 distinct words;
  the four 464 B segments' is 27; the intersection is
  exactly two words — zero and `0100000000000000`.
  Of the 464 B preamble's sixteen constant words
  (AES-NUM-040/041), only the zero words and
  `0100000000000000` occur anywhere in the small
  segments; every substantive preamble constant
  (`0000000003000000`, `a204000000000000`,
  `4809000000000000`, `0200000002000000`,
  `01000000a3040000`, `a404000000000000`,
  `0800000000000000`, `0000000001000000`, …) occurs in
  none of them.
- The construction nevertheless matches at the byte
  level, in three measured ways. (a) Both vocabularies
  carry the `0100<param+1>00…` word family: small
  `010065004c01f000` / `010071004c01f000` /
  `0100b1004c01f000` / `0100f9004c01f000` against 464 B
  `010065009801b200` / `010071009801b100` /
  `0100b1009801b200` / `0100f9009801b080` — byte 2 is
  the segment's parameter + 1 in both forms (in the
  360 B pair it sits at word 42, in the final-four
  zone the parameter itself never enters). (b) The
  360 B pair is one template under two parameters
  (0x64 / 0x70): heads differ only at bytes 6–7, words
  1–11 are the pure parameter word `0000<param>0000
  000000`, and the slot words from word 12 carry
  identical trailing fields with permuted assignment
  (word 28 is byte-identical apart from the parameter
  byte itself). (c) Same-parameter pairs differ only
  in data fields: the 312 B pair (both 0xf8, identical
  heads) differs at exactly two words (33: `0084…` vs
  `0081…`; 38: a data word); the 328 B pair (both
  0x64) differs at the head's bytes 0/7, at the slot
  words' trailing fields (a permuted value set, e.g.
  `…9c019480` / `…9c018a80` / … reassigned between
  instances), and at two data words (35, 40).

Graded MEASURED: the parameter mechanism is one
construction across the 232–464 B structured forms of
cc9b9d1c — a template stamped with a per-segment
parameter byte at byte-2 slots, a paired head byte 6,
and a parameter+1 slot word — but the forms share no
substantive constant WORD verbatim; their slot
patterns and slot-word tails are size-specific. What
the parameter encodes remains NOT PROVEN.

## The high-7 families obey the universal datum laws per family — and the family is part of the key

AES-NUM-042 left the non-champion high-7 population
(operand second-u16 high nibble 7: 1,839 bursts, 345
distinct operands, 68 lane-0 families, all channels)
with the champion treatment queued: is operand →
datum a function, and is it GF(2)-affine
(AES-NUM-027 method, augmented-basis test)?

- Per family, the laws hold WITHOUT EXCEPTION: all
  68 lane-0 families have zero function violations
  and zero affine inconsistencies (per-family ranks
  1–13; the largest family, `0028000000000419` with
  115 bursts / 14 keys, has rank 12). The lane-2
  width law holds in 1,839 / 1,839 bursts. The high-7
  population is not special: it behaves exactly like
  every other non-champion family population measured
  in AES-NUM-027/028/030.
- Pooled by operand ALONE, the function FAILS:
  189 of 345 distinct operands carry more than one
  datum (1,269 occurrence violations), and the pooled
  affine test fails with it (rank 13, 332
  inconsistencies over the 345 distinct pairs). The
  same operand word recurs under different lane-0
  headers with different data.
- Pooled by (lane-0, operand), the function holds
  exactly: 626 distinct keys, zero violations. The
  datum is a function of the operand within its
  family — the header word is part of the key, as
  the per-family freezes of AES-NUM-028/031 already
  assume.

Graded MEASURED: operand → datum is a GF(2)-affine
function per lane-0 family in the high-7 population
too (68 / 68 families, zero violations of either
law); it is NOT a function of the operand alone
across families. The 0x7 high value itself remains
without an assigned meaning (NOT PROVEN) — but it
needs none for the datum component: the family-wise
encoder treatment covers it.

## Displaced contexts are a distinct, periodically placed, low-action context type

AES-NUM-041/042 left the 76 displaced 0x2d80-pair
contexts (of 1,504) with the question whether they
differ from adjacent contexts OUTSIDE the pair
region. Slice 4.43 compares the champion-operand
multisets at body ordinals <10 (head) and >20 (tail)
— the pair region 10–20 excluded — plus whole-context
features, and hef43b adds context positions and
action counts. (Body champion count is 29 in the
standard context: the 50 of AES-NUM-041/042 include
the 21 trailing bursts, which follow the body.)

- The tail does not differ: displaced contexts'
  tail multisets equal the modal adjacent tail
  (symmetric difference 0 in 0a0d378c, 0856a10c and
  5ab3537d; mean 0.04 in 76c3a8ff; 2 in the single
  773470cd context). Whatever displacement is, it
  leaves the context's second half untouched.
- The head belongs to the type, not to the modal
  layer pool: NO displaced context's head multiset
  is shared by ANY adjacent context, in any artifact
  (0 sharing everywhere). 76c3a8ff's displaced heads
  are two dominant multisets (×25 and ×24 — the +4
  and −2 families) plus six singletons; 0a0d378c's
  are one dominant (×14, the +4 family) plus four
  singletons.
- The type is LOW-ACTION: displaced contexts carry
  the standard champion skeleton (body 29, ~50 with
  trailing) but a fraction of the data actions —
  total pointer actions 85–123 against adjacent
  minima of 280 (0a0d378c: all 18 displaced ≤123,
  all 162 adjacent ≥280 — a clean gap) and 232
  (sister pair: the single displaced context has 93
  against an adjacent minimum of 232); large-action
  means 9–40 against 315–503; distinct sizes 22–35
  against 40–83.
- Placement is periodic / positional: in 0a0d378c
  the displaced contexts sit at stream indices
  73, 75, then 81 + 6k through 165, and 179 (the
  artifact's last context); in 76c3a8ff at 91 and
  then in a ~9-step pattern (106, 110, 112, 119, …,
  351); in each sister artifact the single displaced
  context is the LAST context (index 218 of 219);
  in 0856a10c the single one sits at index 99.
- The type does not force displacement, and
  displacement has one outlier: 76c3a8ff holds 3
  adjacent contexts with ≤150 actions and 0856a10c
  holds 1 (small contexts whose pair stays adjacent),
  and one displaced 76c3a8ff context has 336 actions
  (pattern (18,15) — the rare-ladder context of
  AES-NUM-042, a different route to displacement).
  MiniLM and cc9b9d1c have no displaced contexts and
  no contexts under 186 actions.

Graded MEASURED: outside the pair region, displaced
contexts are distinguished by TYPE, not by damage —
a periodically placed low-action context class whose
tail is the standard tail, whose head is its own,
and whose pair is emitted in the displaced order.
Why this class emits the pair displaced — and why a
few of its members do not — is NOT PROVEN.

## What this closes and what it queues

- MEASURED, corpus-wide: the cc9b9d1c parameter
  family is one construction across 232–464 B (exact
  dense slot pattern [1..12, evens to words−5] in the
  small forms; head byte 6 ↔ parameter bijection over
  all twelve segments; a parameter+1 slot word in
  both vocabularies) sharing no substantive constant
  word with the 464 B form (intersection = zero +
  `0100000000000000` only); the high-7 datum map is a
  per-family GF(2)-affine function with zero
  violations in all 68 families (and is not an
  operand-only function — the family is part of the
  key); displaced contexts are a periodically placed
  low-action context type whose outside-pair anatomy
  is a private head + the standard tail.
- NOT established: what the parameter byte encodes;
  the low-action context class's identity (which
  proto/program role it holds); why the class emits
  the pair displaced, and the 336-action outlier's
  route.
- NEXT (4.44): the low-action context class census
  (corpus-wide definition by action count, positions
  and periodicity per artifact, full size-sequence
  anatomy of exemplars vs standard contexts);
  parameter+1 slot census across the structured
  forms (cc9b9d1c small + 464 B family incl. the
  0x72 / 0x46 artifacts); the 336-action outlier's
  context anatomy vs its stream neighbours.
  Host/artifact analysis only.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
