# Channel-0 burst treatment: census, laws, cross-prediction (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.30 (AES-NUM-030).
Population: every 24-byte burst on channel 0 in all seven
corpus artifacts — MiniLM plus the six hailo-ollama blobs —
extracted and analysed on Mimir with hef30.py (sha256
ba23e7d3…; the AES-NUM-027/028 schema-guided walk filtered
to channel 0, with the frozen AES-NUM-026 champion basis
and the six AES-NUM-028 family bases embedded verbatim for
cross-prediction). Control: the extraction reproduces
AES-NUM-029's per-artifact channel-0 counts EXACTLY
(190 / 6,614 / 7,218 / 5,058 / 9,983 / 6,596 / 7,827;
pooled 43,486).

## The census — 104 families, 43,486 bursts

- Per artifact (bursts / families): MiniLM 190/23,
  5ab3537d 6,614/25, 0856a10c 7,218/13, 0a0d378c 5,058/4,
  76c3a8ff 9,983/32, 773470cd 6,596/24, cc9b9d1c 7,827/29.
  Pooled by exact lane-0 word: **104 families, 43,486
  bursts**.
- The champion family `0528000000000000` holds 42,118
  bursts (96.9%) with 1,120 distinct operand words, in
  all 7 artifacts. The largest non-champion family holds
  119 bursts; the rest are small and artifact-local, as
  on channels 1/2.

## The three laws hold on channel 0 — no exceptions

- Operand→datum is a **function in all 104 families**
  (0 violations); the map is **GF(2)-affine in all 104**
  (0 inconsistencies); the **lane-2 width law** (bytes
  3–7 zero) holds in **43,486 of 43,486** bursts
  (0 breaks). The AES-NUM-027/028 universality is now a
  three-channel fact over the full 79,001-burst
  population.

## Cross-prediction by the frozen encoders — the honest split

- **Family encoders extend perfectly where families
  coincide.** Three of the six frozen AES-NUM-028
  families appear on channel 0. Two are predicted
  EXACTLY by their frozen (channels-1/2-fitted) bases:
  `0228000000002c17` 29/29 distinct pairs, 54/54 bursts;
  `0028000000002c15` 22/22 distinct, 54/54 bursts —
  0 wrong, 0 out-of-span. The third (`0228000000001311`,
  1 burst) falls outside its frozen span and is honestly
  REFUSED (None), never guessed.
- **The champion encoder does NOT extend.** The
  channel-0 champion operand population is DISJOINT
  from channels 1/2: 0 shared operands between the
  1,120 channel-0 distinct words and the 1,189
  channels-1/2 distinct words. Under the frozen linear
  basis (AES-NUM-026) exactly **1 of 1,120** distinct
  operands is in-span — `0x2d80025000002000` → `0x2fdeaa`,
  predicted CORRECTLY (1,504 bursts; it shares the
  0x2d80/0x0250 skeleton prefix with the channels-1/2
  special word). The other 40,614 champion bursts are
  out-of-span: refused, not wrong — the frozen encoder
  never mispredicts a channel-0 datum.
- **The channel-0 champion map is itself GF(2)-LINEAR**
  (a direct linear fit over its 1,120 distinct pairs:
  rank 27, 0 inconsistencies) — a different, wider map
  than the channels-1/2 champion's rank 16, over a
  different operand form (its most frequent operands,
  e.g. `0x2a00016800000000`, repeat exactly 1,504 times
  each). It is freezable by the AES-NUM-026 method; that
  freeze is slice 4.31.

## Coverage accounting, updated

- Frozen datum coverage is now stated per channel group:
  channels 1/2 stand at 33,580/35,515 (94.6%,
  AES-NUM-028); channel 0 stands at 1,612/43,486 (3.7% —
  the 1,504 in-span champion bursts plus the 108
  family-predicted bursts). Pooled: **35,192/79,001
  (44.5%)**. The gap is one freeze away for the champion
  form (rank-27 linear, proven consistent), plus
  per-family freezes for the channel-0 families by the
  AES-NUM-028 method.
- NEXT (4.31): freeze the channel-0 champion basis +
  the largest channel-0 non-champion families as
  Aesir-owned encoders, Mojo-proven on Mimir (symmetric
  to AES-NUM-026/028). Then (4.32): small-form word
  anatomy per size class.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven artifacts;
all fits are exact GF(2) algebra; blob identities are
sha prefixes only, as before.
