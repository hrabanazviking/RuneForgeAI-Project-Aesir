# Family census at corpus scale, six freezes, Campaign-4 stocktake (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.28 (AES-NUM-028).
Population: every 24-byte burst (channels 1/2) in all seven
corpus artifacts — MiniLM plus the six hailo-ollama blobs —
extracted on Mimir with the AES-NUM-027 method (hef28.py,
sha256 c2b1090f…; per-artifact burst counts reproduce the
AES-NUM-016 walk exactly where they overlap: 5,546 / 5,836 /
8,089 / 6,287).

## The census — 174 families, 35,515 bursts

- Per artifact (bursts / families): MiniLM 153/18, 5ab3537d
  5,546/44, 0856a10c 5,836/30, 0a0d378c 4,040/9, 76c3a8ff
  8,089/47, 773470cd 5,564/45, cc9b9d1c 6,287/46. Pooled by
  exact lane-0 word: **174 families, 35,515 bursts**.
- The champion family holds 33,097 bursts (93.2%) with
  exactly **1,189 distinct operand words — the AES-NUM-025
  population, reproduced exactly** by the pooled walk.
- **The three laws hold corpus-wide, no exceptions:**
  operand→datum is a function in all 174 families (0
  violations); the map is GF(2)-affine in all 174 (0
  inconsistencies); the lane-2 width law holds in all
  35,515 bursts (0 breaks). AES-NUM-027's two-artifact
  universality is now a seven-artifact fact.
- Non-champion families are small and artifact-local: the
  largest holds 112 bursts; each of the top families
  appears in only 2–4 of the 7 artifacts. Family sizes
  cluster at 56 and its multiples/doubles, as in 4.27.

## Six freezes — the largest non-champion families

Per-family affine bases fitted over each family's full
corpus population and frozen as repo artifacts:

- **`hailbru/ccw_family_bases.json`** — six families
  (0028000000802419, 0228000000001c11, 01080000f8bf1812,
  0028000000002c15, 0228000000002c17, 0228000000001311),
  ranks 13–15, each with a canonical sha256 that was
  reproduced identically on the VM from the on-device fit
  (all six match).
- **`hailbru/ccw_family_datum.mojo`** —
  `ccw_family_datum(lane0, lane1) -> Optional[UInt32]`,
  unrolled descending-pivot reductions over the frozen
  bases (augmented constant carried explicitly); unknown
  family or out-of-span operand returns None — refuses,
  never guesses. The champion family is NOT served here
  (its encoder is `ccw_datum.mojo`, AES-NUM-026).
- **Verification (on Mimir, repo toolchain):** the module
  crossed byte-identical (sha256 67df4a9e…); standalone
  build + run answers the champion lane-0 with None as
  contracted; a harness generated on-device from the
  source artifacts over all **177 distinct
  operand→datum pairs of the six families: CHECKED 177 —
  FAILED 0**.
- Structural note: the lowest-pivot rows are shared
  verbatim across families (the pivot-48 row is identical
  in all six; pivot-49 in two groups of three) — the
  replicated-scalar low structure of AES-NUM-020/021 seen
  from the basis side; bases diverge as pivots rise.

Frozen coverage: champion (33,097) + six families (483) =
**33,580 of 35,515 bursts (94.6%)** now have an Aesir-owned
datum encoder. The remaining 168 families hold 1,935
bursts (5.4%); every one is proven affine with zero
inconsistencies, so each is freezable by the same method
whenever its population warrants it.

## Campaign-4 stocktake toward the Campaign-5 gate

What the campaign now holds, honestly graded:

- **SOLVED (empirical, Aesir-owned):** the lane-2 datum of
  the 24-byte burst — one global linear map for the
  champion form (AES-NUM-023–026) and per-family affine
  maps for the six largest remaining families (this
  slice), all Mojo-proven on Mimir. The datum was the
  R1-blocked field; for these burst forms it is computed,
  not copied.
- **ESTABLISHED at source level:** session readiness
  (R2), the configure ordering discipline (R4, partial),
  teardown preconditions (R5, partial), the program
  lifecycle interface and its failure accounting
  (Campaign 3).
- **STILL OPEN:** (a) what lane 0 and lane 1 *mean* beyond
  their datum relation — the champion's flags/enum/ladder
  are decoded structurally (AES-NUM-017/018), the family
  header words are observed constants whose *generation*
  rule is unknown, and non-champion lane 1 is a
  replicated-scalar form whose operand semantics are not
  established; (b) CCW action forms beyond the 24-byte
  channel-1/2 burst — pointer actions of other sizes and
  channels are an unmapped surface; (c) placement remains
  a measured floor (clusters 0–4, LCUs 0–15 across ~48k
  triggers), not a silicon census (R3); (d) layers 2/3/5/6
  of the identity-copy spec therefore remain incomplete:
  a full authorable context needs lane-0/lane-1 generation
  plus the non-burst forms, not just the datum.
- **Gate reading:** the Campaign-5 *encoder* may now be
  contracted for the datum component and the burst forms
  covered here. A full program encoder may NOT yet be
  contracted: items (a) and (b) are exactly the remaining
  CCW surface. Next slice (4.29) maps that surface — a
  census of every pointer-action form (size × channel)
  across the corpus, so the unknown is measured, not
  assumed.

## Evidence boundary

Host/artifact analysis only; no physical child ran. All
fits are exact GF(2) algebra over complete populations —
the grades above are empirical over these seven artifacts,
and family identity is by exact lane-0 word, as in 4.27.
