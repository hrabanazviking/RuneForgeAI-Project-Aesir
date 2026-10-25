# Non-champion enum test, the 0x2d80 pair in burst ordinal, the cc9b9d1c 464 B variant (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.41 (AES-NUM-041).
Populations: all seven corpus artifacts (MiniLM plus the
six hailo-ollama blobs), walked on Mimir with hef41.py
(sha256 47736f39…) plus the labelled follow-up hef41b.py
(sha256 7d56aaa9…). Controls: the walk reproduces
AES-NUM-029/032/033/034/035/036/037/038/039/040 EXACTLY
(128,787 pooled small actions; 79,001 pooled 24 B bursts;
745,849 pointer actions; 1,504 contexts; trailing distinct
(channel, operand) pairs 2,049; champion-headed bursts
75,215). hef41b's reduced controls also reproduce exactly
(79,001 bursts; 1,504 contexts).

## The enum-bit law does NOT transfer to the non-champion families

AES-NUM-040 established for the champion-headed bursts
(lane-0 word `0528000000000000`): the operand's enum high
nibble takes exactly the values {0, 1, 2, 4, 8} — single
bits, never a counter — and in the body the class equals
the channel index. Slice 4.41 tests the same two claims
on the remaining 24 B population: 3,786 bursts under 237
distinct non-champion lane-0 words, 617 distinct operands,
reading the same operand slot (u16 at operand bytes 2–3,
high nibble = value >> 12). Both claims FAIL:

- The slot's high values are NOT confined to
  {0, 1, 2, 4, 8}. All nine values 0–8 occur. Per burst:
  0: 793 (20.9%), 1: 11, 2: 14, 3: 23, 4: 760 (20.1%),
  5: 10, 6: 108, 7: 1,839 (48.6%), 8: 228 (6.0%). Only
  1,806 of 3,786 bursts (47.7%) carry a champion-set
  value; the single most common value, 7, never occurs
  in the champion population at all. Per distinct
  operand the picture is the same (7: 345 of 617).
- Class == channel holds for only 237 of 3,786 bursts
  (6.3%); 3,549 bursts (593 distinct operands) violate
  it, across essentially every family. The 237 matches
  are the coincidence-level residue (value 0 on channel
  0, value 4 on channel 2, and kin).
- The slot is often family-constant without being an
  enum: 185 of 237 families carry a single high value
  (2,040 bursts), but the constant is 7 in 34 families
  (642 bursts), 3 in 3 families, 5 in 1 — values the
  champion law forbids. 191 families (2,086 bursts) are
  single-valued per channel. The remaining 52 families
  (1,746 bursts) carry 2–6 distinct values.

Graded MEASURED as a negative: the {0,1,2,4,8}
single-bit pattern and the class = channel identity are
properties of the champion lane-0 family only. In the
non-champion families the operand's second u16 is a
different field — consistent with AES-NUM-018's finding
that the champion's lane-1 anatomy does not transfer to
the non-champion families (their lane 1 is data-bearing
in the 0x28xx class and structured differently in the
0x08xx class). What that field is in each family is NOT
PROVEN; no enum meaning is assigned to it here.

## The 0x2d80 pair: adjacency is a burst-ordinal fact, and it is 94.9%, not 100%

AES-NUM-040 measured the pair's ACTION-index separation
in the body population as −32…+49 with both orders
(738 / 766) — no adjacency at action granularity.
hef41 reproduces that control exactly (same range, same
order counts) and adds the burst-ordinal view: counting
only champion-headed bursts within each context, the
pair (flags 0x4000 = A, flags 0x8000 = B; both found in
all 1,504 contexts) is ADJACENT — separation exactly ±1 —
in 1,428 contexts (94.9%): B one after A in 693, one
before in 735 (signed separation B−A: −1 ×735, +1 ×693).
Counting all 24 B bursts (non-champion bursts interleave)
adjacency drops to 1,286 (85.5%). The roaming pair of
AES-NUM-040 is therefore the skeleton unit's adjacent
pair (indices 10–11, AES-NUM-019) seen through the
action stream: the bursts between them at action
granularity are non-burst actions, not other bursts.

The pair's champion ordinals are tight: in adjacent
contexts the pair occupies ordinals (15, 16) or (16, 15)
in 1,425 of 1,428 cases (the remaining 3 sit at
(18, 17), (19, 20), (20, 19) in longer contexts).

The 76 non-adjacent contexts (5.1%) are structured, not
noise — two fixed patterns dominate, concentrated in
two artifacts (76c3a8ff: 55; 0a0d378c: 18; one each in
0856a10c, 5ab3537d, 773470cd):

- (ordA, ordB) = (12, 16), separation +4: 39 contexts —
  B holds its usual ordinal 16 while A sits four
  champion bursts earlier, at 12.
- (ordA, ordB) = (16, 14), separation −2: 28 contexts —
  A holds 16 while B sits at 14, one champion burst
  between them.
- The remaining 9 contexts scatter over seven other
  (ordA, ordB) pairs (separations −6…+5). 73 of the 76
  contexts have the standard 50 champion bursts.

Graded MEASURED: burst-ordinal adjacency is the pair's
dominant presentation (94.9%) but not a law; the
exceptions are two artifact-concentrated ordinal
patterns. Why those contexts displace one member is NOT
PROVEN.

## The cc9b9d1c 464 B variant: one template, a per-segment parameter, no 304 B tail

Corpus 464 B census (AES-NUM-040 populations): 12
occurrences in 3 artifacts — 0a0d378c 7 (one head),
cc9b9d1c 4 (four heads), 0856a10c 1 (its own head).
The cc9b9d1c variant, all four segments (58 words each):

- The four heads are `0128700300001913`,
  `0128700300001c13`, `0128700300002c13`,
  `0128700300003e13` — one template head differing only
  in byte 6 (0x19 / 0x1c / 0x2c / 0x3e); byte 7 is 0x13
  (0a0d378c's head carries 0x1c15 there and a leading
  0x03 for its 0x01).
- The 21-word preamble varies at exactly 5 positions
  (0, 1, 15, 17, 19); the other 16 words are constant
  across all four segments, with zero at positions
  5, 6, 8, 9, 12, 13 — the same zero skeleton as the
  0a0d378c preamble (AES-NUM-040). Each segment's
  preamble holds 15 distinct words; the union over the
  four is 30, the intersection 10.
- The variable words are one per-segment PARAMETER
  written at every variable slot: segment parameters
  0xb0 / 0x64 / 0x70 / 0xf8 (paired with head byte-6
  values 0x2c / 0x19 / 0x1c / 0x3e respectively) recur
  at preamble words 1, 15, 17, 19 and throughout the
  tail at words 21, 24, 27, 33, 35, 37, 39, 41, 43, 45,
  47, 49, 51, 53, 55 (e.g. word 15:
  `0200b0000000b280` / `020064000000b280` /
  `020070000000b180` / `0200f8000000b000`). The same
  interleaved family, with a fixed parameter 0x72,
  forms the 0a0d378c preamble (its union literally
  contains `190072000080b000`, `020072000000b080`,
  `010072000c00b080`, `020072001c00b000`), and 0x46 in
  the single 0856a10c segment (`1900460000e0b080`,
  `010046000000b000`, …). Variable positions over the
  whole cc9b9d1c form: 22 of 58 (the 5 preamble slots,
  15 tail parameter slots, word 40 — `ff73/ff83/ff76/
  ff86…` — and the fully distinct trailer word 57).
- Preamble sharing with 0a0d378c is exactly six words:
  zero, `0000000001000000`, `0000000003000000`,
  `0100000000000000`, `0200000002000000`,
  `0800000000000000` — the generic template constants;
  no cc9b9d1c head word appears in the 0a0d378c
  preamble.
- There is NO framed-304 tail embedding in cc9b9d1c:
  its 304 B population is 813 occurrences of ONE
  segment (head `012830020000002e` — the breaker-form
  head of AES-NUM-037, not the framed head, which
  occurs 0 times), and its words 1–37 match the 464 B
  words 21–57 at only 3 of 37 positions for every
  pairing. The 35/37 tail composition of AES-NUM-039
  is a property of the 0a0d378c variant only.

Graded MEASURED for the cc9b9d1c variant's anatomy as
above; what the parameter byte, the head byte-6 values,
or word 40 / word 57 encode is NOT PROVEN.

## What this closes and what it queues

- MEASURED, corpus-wide: the champion enum-bit /
  class = channel law is champion-specific — in the
  237 non-champion lane-0 families the same operand
  slot takes all values 0–8 (7 dominant, 48.6% of
  bursts) and matches the channel in only 6.3% of
  bursts; the 0x2d80 pair is adjacent in champion
  burst ordinal in 94.9% of contexts (ordinals 15/16),
  with two fixed non-adjacent patterns (12→16 ×39,
  16→14 ×28) concentrated in 76c3a8ff and 0a0d378c;
  the cc9b9d1c 464 B form is one template instantiated
  with a per-segment parameter byte (0xb0/0x64/0x70/
  0xf8; the family parameter is 0x72 in 0a0d378c, 0x46
  in 0856a10c), sharing only the six generic constants
  with the 0a0d378c preamble, and it does NOT embed
  its artifact's 304 B form as a tail.
- NOT established: the non-champion lane-1 field's
  identity in any family; why 76 contexts displace
  one pair member; what the 464 B parameter, head
  byte 6, word 40, or word 57 encode.
- NEXT (4.42): the displaced-pair contexts — which
  champion bursts occupy the gap ordinals (13–15 in
  the +4 pattern; 15 in the −2 pattern) and whether
  they are a fixed insertion; the cc9b9d1c parameter's
  recurrence outside the 464 B form (other segment
  classes in cc9b9d1c carrying 0xb0/0x64/0x70/0xf8 at
  the same slot); the non-champion high-7 families'
  lane-1 structure (is the 0x7… value an address-like
  field co-varying with the pointer offset?).
  Host/artifact analysis only.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
