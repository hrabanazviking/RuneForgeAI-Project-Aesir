# The datum's closed form, II: one global matrix (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.24 (AES-NUM-024).
The GF(2)-linear map of AES-NUM-023, extracted as a basis
and cross-validated between artifacts.

## Cross-validation: exact prediction, both directions

- Fit on the blob's 417 samples → **all 62 MiniLM operand
  words lie in the fitted span, and all 62 datums are
  predicted exactly.**
- Fit on MiniLM's 62 → 272 of the blob's 417 words lie in
  its smaller span; **272/272 predicted exactly.**
- Zero wrong predictions anywhere. Combined span rank
  stays 14: both artifacts inhabit the **same
  14-dimensional input variety** and obey the **same
  linear map**. One global transform, proven by
  out-of-sample prediction — not merely by fit.

## The matrix's character (on the determined directions)

- 10 of 64 unit columns are individually determined by the
  observed span (flags bits 10–15, enum bit 16, ladder
  bits 57–59). Their images are **dense** 24-bit values
  (popcount 9–14 of 24): every determined input bit stirs
  about half the output bits — a mixing transform, not a
  permutation or sparse routing.
- Neighbour relations are mixed: some adjacent determined
  columns are exact one-bit shifts of each other (flags
  10→11, 13→14; ladder 58→59), others are unrelated — a
  hint of banded construction under the mixing, not a
  clean CRC-style Toeplitz.
- Zero input maps to zero datum (pure linear, no constant).

## What remains open (and why it matters for authorship)

The map is determined only on the observed span (rank 14).
Operand words Aesir authors itself must land in a span the
map is known on; novel (flags × enum × ladder)
combinations could fall outside rank 14 and be
unpredictable from this fit. The remedy is breadth: fit
across all seven corpus artifacts, watch the span grow,
and test whether it saturates — the variety's true
dimension is bounded by the fields' own variety (enum has
4 values, ladder 7; the flags variety is the open term).
That is slice 4.25.

## Evidence boundary

Exact GF(2) algebra; prediction counts are over complete
artifact maps (62 and 417 distinct operand words).
Off-span behaviour is unobserved and unclaimed.
