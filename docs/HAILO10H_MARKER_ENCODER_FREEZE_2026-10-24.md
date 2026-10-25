# Marker encoder freeze — Aesir can now compute the marker word (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.46 (AES-NUM-046),
under its published contract
`TASK_hailo10h_marker_encoder_2026-10-25.md` (committed
and pushed at f5d1c087 before implementation). Contract
scope is the encoder freeze only; the pair-order hunt,
zone-pair body comparison, and 156 middle unit anatomy
named beside it in TODO 4.46 are re-queued as slice
4.47, not silently dropped.

## Artifact (committed with this slice)

- **`hailbru/ccw_marker.mojo`** — the reference encoder:
  `ccw_marker(predecessor: UInt64, form: UInt8) ->
  Optional[UInt64]`. A word is a UInt64 loaded
  little-endian from its 8 file bytes (byte k of the
  file word is `(word >> (8*k)) & 0xFF`). The encoder
  copies the predecessor word, adds 1 to byte 2, and
  steps byte 4 by −4 (form 0, the small forms) or +16
  (form 1, the 464 B form; form 2, the 464 B form in
  the 0856a10c `0200…` head shape, additionally sets
  the marker's byte 0 to 0x02). File sha256
  `17d51ccaaea35f874a093a9a02e1dc5ed8eeaa981d6b36b8792d0739dc2b3cc2`.
- Honesty contract (in the module header): a
  predecessor that is not a strict word (byte 0 ≠
  0x01, byte 1 ≠ 0, byte 3 ≠ 0), a byte 2 of 0xFF, a
  byte 4 that cannot take the form's step, or an
  unknown form code returns `None` — the encoder
  refuses, never guesses. No discriminator for the
  form-2 head shape is established, so the caller must
  select it explicitly. What the marker encodes
  remains NOT PROVEN (AES-NUM-045).

## Verification (on Mimir, repo toolchain)

Method: hef46.py (sha256
`2812db6589c74b1c99f2f15e6af5b8add9ba10e69a968fa26a898a78190a0b52`),
sha-gated gzipped 373 B-part transfers to Mimir — both
whole-file shas verified on-device (the gz of hef46.py
`efd9fd48…`, of the module `d3284575…`; one hef46 part
corrupted in re-emission was rejected at schema
validation and a verbatim retry landed clean). The
module crossed byte-identical (sha256 above, matched
on-device).

- Controls reproduce AES-NUM-029/032/033/034/035/036/
  037/038/039/040/041/042/043/044/045 EXACTLY:
  128,787 pooled small actions; 79,001 pooled 24 B
  bursts; 745,849 pointer actions; 1,504 contexts;
  trailing distinct (channel, operand) pairs 2,049;
  champion-headed bursts 75,215; 427 distinct
  cc9b9d1c segments at 232–464 B.
- Populations reproduced exactly under the
  AES-NUM-045 definitions: 212 dense-skeleton cc9b9d1c
  marker segments under modal X, and the 20 family
  segments (cc9b9d1c 12, 0a0d378c 7, 0856a10c 1, by
  modal byte 2 in each artifact's parameter set).
- Segment-level rule check in Python (the encoder
  rule applied to each segment's preceding strict
  word, form by size/artifact): **SEG CHECKED 220
  FAILED 0** — the 212 dense segments plus the 8
  family segments outside cc9b9d1c (the cc9b9d1c
  family 12 are a subset of the 212). The population
  holds **78 distinct (predecessor, marker, form)
  triples**.
- Standalone Mojo build + run on Mimir (Mojo 1.1.0):
  the three recorded smoke examples produce their
  recorded markers (small modal-0 form, 464 B family
  form, 464 B `0200` shape), and both refusals fire
  (non-strict word; unknown form code 9).
- A harness generated **on-device** from the seven
  source artifacts (all 78 distinct triples embedded
  as literals around the committed encoder text)
  built with `mojo build` and ran:
  **CHECKED 78 — FAILED 0.**

## What this closes and what it queues

- FROZEN: the skeleton marker derivation is now an
  Aesir-owned encoder, proven against the complete
  measured population (220 segment checks, 78
  distinct triples, zero failures). Together with
  the datum encoders (AES-NUM-026/028/031), another
  component of the structured forms is computable
  by Aesir's own software.
- NOT established: what X, the byte-4 step, or the
  marker encodes; any discriminator for the `0200`
  head-shape variant; the marker's role outside the
  measured forms.
- NEXT (4.47): pair-order determination hunt (order
  vs head-operand identity / first-middle operands);
  zone-pair body comparison (97 vs 105, 98 vs 106
  outside the rare/pair region); 156 middle unit
  segment anatomy (the 12-fold unit's distinct
  segments). Host/artifact analysis only.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven
artifacts; blob identities are sha prefixes only.
