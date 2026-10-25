# Co-determination at corpus scale — a bijection (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.22 (AES-NUM-022).
The 4.21 sister-unit law, tested across whole artifacts,
plus the anatomy of the special pair's splitter.

## The datum is a bijective image of the operand word

Grouping every champion burst by its full operand word
(lane 1) and by its datum:

- **MiniLM: 62 lane-1 keys ↔ 62 datum values, zero
  violations in either direction.**
- **Blob 5ab3537d: 417 lane-1 keys ↔ 417 datum values,
  zero violations in either direction.**
- The map is context-free: the same lane 1 carries the
  same datum in every context it appears in (ctx+lane1
  grouping: still zero violations).
- Minimality: the three *variable* fields jointly
  determine the datum (flags+enum+ladder: 0 violations),
  and **every proper subset fails** — enum+ladder (96 /
  4,139 violations), flags+ladder (60 / 2,355),
  flags+enum (64 / 1,864), every single field (thousands).
  All three variable fields are individually necessary;
  the constant `0x0250` field carries no information.

A one-to-one, context-free map from a packed operand word
to a 24-bit value is the behavioural signature of an
*encoding*: the datum is lane 1, transformed. Which
transform is the next question (slice 4.23: affine/GF(2)
linearity test first — if each datum bit is a linear
function of the operand bits, the system of 417 samples
decides it exactly).

## The special pair's splitter is the flags field

At skeleton positions 10–11 in the blob's 95 sister pairs:

- Non-conserved pairs (50) differ in **flags and datum
  only** — enum and ladder never differ there (0/50).
- The flags field takes exactly two values at these
  positions, `0x4000` and `0x8000` (a one-bit choice), and
  the correspondence is **perfect in both directions, at
  both positions, in conserved and non-conserved pairs
  alike**: flags `0x4000` ⟺ datum `0x60e517`; flags
  `0x8000` ⟺ datum `0x56898c` (counts 28/22 and 27/18
  match exactly).
- Positions 10 and 11 are complementary in non-conserved
  pairs: where one takes `0x4000`, the other takes
  `0x8000` (28 pairs) and vice versa (22). The heart of the
  palindrome is a complementary flag pair, and the famous
  datum pair is simply its image under the bijection.

## Evidence boundary

Counts exact over the stated populations (132 and 4,819
champion bursts; 95 sister pairs). The bijection is
empirical over the observed domains (62 and 417 entries);
its closed form is NOT PROVEN — that is the next slice's
question, and the map tables themselves are preserved in
this slice's raw output for the transform hunt.
