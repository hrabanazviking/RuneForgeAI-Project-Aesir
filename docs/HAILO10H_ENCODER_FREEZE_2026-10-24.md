# Encoder freeze — Aesir can now compute the datum (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.26 (AES-NUM-026).
The fitted GF(2) basis of AES-NUM-023–025, frozen as
Aesir-side artifacts and proven in the repo's own toolchain.

## Artifacts (committed with this slice)

- **`hailbru/ccw_datum_basis.json`** — the 16-row reduction
  basis (pivot, input vector, output vector per row) with
  provenance. Canonical byte form (rank + rows as produced
  by the fitting walk) has **sha256
  `7a1635cb32fbd48e935d7902e532a3f700ef28edfed4bee09d2470a8a92a7e5a`**,
  reproduced identically on the VM from the on-device dump.
- **`hailbru/ccw_datum.mojo`** — the reference encoder:
  `ccw_datum(lane1: UInt64) -> Optional[UInt32]`, an
  unrolled descending-pivot reduction over the frozen rows.
  Out-of-span inputs return `None` — the encoder refuses,
  never guesses (the honesty contract is in its header).

## Verification (on Mimir, repo toolchain)

- The module file crossed to Mimir byte-identical
  (sha256-verified against the committed file).
- Standalone build + run: `datum(0) = 0`; the special
  skeleton word `0x2d80025000008000` → `0x56898c`, the known
  datum (AES-NUM-022).
- A harness generated **on-device** from the seven source
  artifacts (all 1,189 distinct operand→datum pairs,
  embedded as literals around the committed encoder text)
  built with `mojo build` and ran:
  **CHECKED 1189 — FAILED 0.**

## Toolchain notes (banked)

- The Pi's Mojo has removed `fn`; the repo convention is
  `def` (as in `soc_transfer.mojo`) — the module follows it.
- `InlineArray` is not available as a bare declaration in
  this toolchain; the encoder uses an unrolled reduction
  (no containers), and harnesses use `List` appends.

## What this means

For the champion burst form, the configuration-word
encoding layer is no longer reverse-engineering — it is a
small, frozen, Aesir-owned encoder with a proven input
domain (the compiler's whole observed variety, rank 16,
saturation-argued in AES-NUM-025). Remaining for the
burst family: the non-champion lane-0 forms (next), then
the wider CCW action forms beyond the 24-byte bursts.
