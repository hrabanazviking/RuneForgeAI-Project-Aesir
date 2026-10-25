# Span growth across the corpus — saturation (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.25 (AES-NUM-025).
The linear datum map of AES-NUM-023/024, fitted
incrementally across all seven corpus artifacts.

## The numbers

| order | artifact | new words | cumulative | rank | new dims |
|---|---|---|---|---|---|
| 1 | MiniLM | 62 | 62 | 12 | 12 |
| 2 | blob 5ab3537d | 379 | 441 | 14 | 2 |
| 3 | blob 773470cd | 59 | 500 | 15 | 1 |
| 4 | blob 0a0d378c | 210 | 710 | 15 | 0 |
| 5 | blob 0856a10c | 302 | 1,012 | 15 | 0 |
| 6 | blob 76c3a8ff | 85 | 1,097 | 16 | 1 |
| 7 | blob cc9b9d1c | 92 | 1,189 | 16 | 0 |

- **1,189 distinct operand words corpus-wide** — equal to
  the datum-pool union of AES-NUM-019, re-confirming the
  bijection at full scale.
- **Zero inconsistencies across all seven artifacts.** One
  map, everywhere.
- The last three artifacts contributed 479 new operand
  words and only **one** new dimension: novel combinations
  land inside the known span, where the map already
  predicts them.

## The field varieties are closed, and they bound the rank

- **flags: 65 values** — `k × 0x400` for k = 0…63 (a 6-bit
  counter in bits 10–15) plus a rare `0x0001`.
- **enum: 5 values** — `0x0, 0x1000, 0x1001, 0x2000,
  0x2001`.
- **ladder: 7 values** — five `…f0` rungs (`0x10f0`–
  `0x18f0`, stride 0x200) plus the special `0x2a8e` and
  `0x2d80`.

The variety's own dimension ceiling is ≈ 7 (flags) + 3
(enum) + ~6 (ladder) = **16 — exactly the measured rank.**
Saturation is therefore plausibly *complete*: every
operand word this burst form can carry may already lie in
the span where the datum is computable from the fitted
basis. This is a hypothesis with its arithmetic shown,
falsifiable by any future artifact that adds a dimension
— and it is the strongest form of the claim the evidence
currently supports.

## Next

Consolidate: freeze the fitted basis as an Aesir-side
encoder artifact (basis table + reference encoder,
host-tested against all 1,189 samples), then give the
non-champion lane-0 families the same treatment. The
burst's encoding layer — the wall Campaign 4 was founded
to breach — is, for the champion form, understood:
operand word in, datum out, by linear algebra we can now
run ourselves.
