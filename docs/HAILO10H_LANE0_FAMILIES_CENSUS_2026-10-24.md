# The lane-0 families — the affine law is universal (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.27 (AES-NUM-027).
Population: every 24-byte burst (channels 1/2) in MiniLM
and blob 5ab3537d — 5,699 bursts in 61 distinct lane-0
families (18 in MiniLM, 44 in the blob).

## The census

- The champion family (`05280000…`) holds 4,951 bursts.
  The remaining 60 families hold 748, in sizes from 56
  down to single digits; family sizes cluster at multiples
  of 28 (56, 29, 28…).
- Non-champion lane-0 words are themselves structured:
  most carry the `0x28` byte at position 1 (`0028…`,
  `0228…`) with varying tails (`…2419`, `…1c11`, `…2c17`),
  and the `01080000f8bf1812` family carries the `0xbff8`
  constant inside its own header.
- Two families are *fixed* bursts: a single operand word
  repeated verbatim 28 times (function rank 1).

## The laws hold in every family — aggregate over all 61

- **Operand→datum is a function in all 61 families**
  (zero violations anywhere).
- **The map is GF(2)-affine in all 61 families** (zero
  inconsistencies anywhere; per-family ranks 1–15).
- **The lane-2 width law holds in all 5,699 bursts**
  (bytes 3–7 of lane 2 zero, no exceptions — the law is
  burst-universal, not a champion trait).
- Non-champion lane-1 anatomy is periodic where the
  champion's is fielded: byte-distinct patterns alternate
  ([12, 5] ×4, [19, 13] ×4, [4, 3] ×4) — the
  replicated-scalar construction of AES-NUM-020/021 seen
  from the family side.

## Reading

The 24-byte burst, in every header family observed, is the
same kind of object: a header word naming the family, an
operand word, and a 24-bit datum that is an affine image
of the operand. The champion encoder (AES-NUM-026) is one
instance of a general pattern; each family admits the same
freeze (basis + encoder) whenever its sample population
warrants it.

## Evidence boundary

Two artifacts, complete populations. Corpus-wide family
census (all 7 artifacts) and per-family freezes for the
largest families are queued (slice 4.28); families are
counted by exact lane-0 word — finer or coarser family
definitions are possible and unclaimed.
