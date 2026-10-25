# Channel-0 freezes: champion basis + six families (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.31 (AES-NUM-031).
The channel-0 maps found in AES-NUM-030, frozen as
Aesir-owned encoders by the AES-NUM-026/028 method and
proven in Mojo on Mimir. Population: every 24-byte burst
on channel 0 in all seven corpus artifacts, extracted
and fitted on Mimir with hef31.py (sha256 adfb0d01…;
the AES-NUM-030 channel-0 walk re-run as the fit input).
Control: per-artifact counts reproduce AES-NUM-029/030
EXACTLY (190 / 6,614 / 7,218 / 5,058 / 9,983 / 6,596 /
7,827; pooled 43,486 bursts, 104 families).

## The channel-0 champion freeze — a linear rank-27 map

- The channel-0 champion family `0528000000000000`
  (42,118 bursts, 1,120 distinct operand words, all 7
  artifacts) fits GF(2)-**linearly**: rank 27, **0
  inconsistencies**, self-verified 1,120/1,120 on-device.
  An affine fit lands on the same rank 27 with 0
  inconsistencies, and the zero operand is absent from
  the population — the map carries no constant term
  that the data can see, exactly as AES-NUM-030's direct
  linear fit reported.
- **`hailbru/ccw_ch0_datum_basis.json`** — the 27-row
  reduction basis. Canonical byte form (rank + rows as
  fitted) has **sha256
  `cfd5c48878dc378c461376b38786e17c4ad9e2c55cfde39a001d2208a704a7bd`**,
  reproduced identically on the VM from the on-device
  fit (transfer gate).
- **`hailbru/ccw_ch0_datum.mojo`** —
  `ccw_ch0_datum(lane1: UInt64) -> Optional[UInt32]`,
  unrolled descending-pivot reduction; out-of-span
  returns None — refuses, never guesses. The module
  crossed to Mimir byte-identical (sha256 f34a2eef…).
- Structural note: the new basis shares whole rows
  with the channels-1/2 champion basis (AES-NUM-026)
  at pivots 10, 11, 13, 14 and 47 (x and y identical)
  — the two maps are cousins in the low structure and
  strangers above it: the channel-0 basis carries 27
  rows to the other map's 16, for its wider operand
  population.
- Standalone smoke on Mimir: `datum(0) = 0`; the most
  frequent channel-0 operand `0x2a00016800000000`
  (1,504 bursts) → `0x1d7710` (it is itself the pivot-61
  basis vector, so the smoke is also a basis self-check).

## Six channel-0 family freezes

The largest non-champion channel-0 families with at
least 16 bursts, fitted GF(2)-affine over their full
corpus populations (zero inconsistencies, zero
verification failures each):

| lane-0 family | bursts | distinct | rank | artifacts |
|---|---|---|---|---|
| 0028000000000419 | 119 | 17 | 14 | 3 |
| 0028000000800015 | 57 | 36 | 15 | 3 |
| 0028000000000415 | 57 | 26 | 14 | 3 |
| 0228000000800219 | 56 | 19 | 16 | 2 |
| 0228000000001719 | 56 | 26 | 12 | 2 |
| 0028000000000819 | 56 | 9 | 9 | 2 |

- **`hailbru/ccw_ch0_family_bases.json`** — the six
  bases, each with a canonical sha256 reproduced
  identically on the VM from the on-device fit (all
  six match; transfer gate).
- **`hailbru/ccw_ch0_family_datum.mojo`** —
  `ccw_ch0_family_datum(lane0, lane1) ->
  Optional[UInt32]`; unknown family or out-of-span
  operand returns None. The channel-0 champion lane-0
  is correctly REFUSED by this encoder (its own encoder
  is `ccw_ch0_datum.mojo`). Crossed byte-identical
  (sha256 0d243065…).
- Structural note: the pivot-64 augmented rows of four
  families share the constant vector
  `0x17ffe7ffe7ffe7ffe` (the same constant seen in an
  AES-NUM-028 family), and the pivot-48/49 rows repeat
  across families exactly as on channels 1/2 — the
  replicated low structure is a three-channel fact.

## Verification (on Mimir, repo toolchain)

- Harnesses generated **on-device** from the seven
  source artifacts, embedding the committed encoder
  texts: champion harness over all **1,120 distinct
  channel-0 champion pairs: CHECKED 1120 — FAILED 0**;
  family harness over all **133 distinct pairs of the
  six families: CHECKED 133 — FAILED 0**.
- Standalone builds of both modules run clean with the
  smokes above.

## Coverage accounting, updated

- Channel 0: 42,118 champion + 401 newly frozen family
  bursts + 108 bursts of the two AES-NUM-028 families
  already predicted on channel 0 (AES-NUM-030) =
  **42,627 of 43,486 bursts (98.0%)** now have an
  Aesir-owned datum encoder. The remaining 859 bursts
  sit in 95 small families, every one proven affine
  with zero inconsistencies (AES-NUM-030), so each is
  freezable by the same method when warranted.
- Pooled over all 79,001 bursts: channels 1/2 stand at
  33,580 (AES-NUM-028); pooled frozen coverage is now
  **76,207 of 79,001 (96.5%)**, up from 44.5%.
- NEXT (4.32): small-form word anatomy — the pointer
  actions of size <= 512 B mapped by AES-NUM-029
  (128,787 actions, structured size ladder, 15.8% zero
  words), per size class.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
All fits are exact GF(2) algebra over complete
populations; blob identities are sha prefixes only.
