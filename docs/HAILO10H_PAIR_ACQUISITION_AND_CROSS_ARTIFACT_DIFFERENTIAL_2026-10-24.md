# Pair acquisition + cross-artifact differential (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.15 (AES-NUM-015),
continuing AES-NUM-014. Three arms: the pair is acquired —
from a store the 4.10 inventory never located — the
per-context lane comparison runs on MiniLM, and the
cross-artifact differential runs on two GenAI LLM HEFs.
Two burst facts are now cross-artifact empirical.

## Arm 1 — pair acquisition: the hailo-ollama store, FOUND

AES-NUM-012 ranked the hailo-ollama store as acquisition
route 3 with "inventory still owed"; AES-NUM-010 recorded
the store as not located. It is located now:
`~/.local/share/hailo-ollama/models/blob/` on Mimir holds
**six blobs, 12 GB total, every one carrying the HEF magic
`\x01HEF`** (sizes 1.40–2.88 GB; pulled per the twister
pull-logs for the five GenAI models in `model-list.json`).
The corpus grows from one HEF to **seven**, with no
download and no new artifact manufactured. Per-blob model
identity is NOT claimed: the manifests directory is empty,
so a blob is identified here by size + sha-prefix only
(the 1,677,961,416 B blob's size sits 221,515 B under the
qwen2:1.5b pull-log total — a correspondence, recorded as
such, not an identification).

## Arm 2 — per-context lane comparison (MiniLM, intra)

Method: schema-guided walk (hefmap8.py on Mimir, sha256
f2c2c6f5…), the six contexts' 24-byte channel-1/2 bursts
aligned by action order (24 aligned positions = the
shortest context's count; per-context counts 25/24/25/24/
26/29 of the 153). Alignment by order is an assumption —
counts differ, so positional correspondence is OBSERVED
under that alignment, not proven.

- **Lane 0:** identical across all six contexts at 17 of
  24 aligned positions; pairwise-identical fraction 0.811.
  Every context's dominant lane-0 value is the same word
  `0528000000000000` (22 bursts each).
- **Lane 1:** varies at all 24 positions (mean 4.54
  distinct values); byte 1 varies at 24/24 positions,
  bytes 3 and 7 at 17/24, the rest at 7–9/24.
- **Lane 2:** bytes 0–2 vary at all 24 positions; bytes
  3–7 vary at NONE — resolved by Arm 2b: across all 153
  bursts the lane-2 tail (bytes 3–7) takes exactly **one
  distinct value, `0000000000`** (hefmap9.py). Lane 2 is a
  ≤3-byte field (83 distinct head-3 values) with a
  constant-zero high half. The invariance is a width fact,
  not per-position structure — recorded that way.
- Channel assignment agrees at only 6/24 aligned
  positions: channel is not position-stable across
  contexts under this alignment.

## Arm 3 — cross-artifact differential (two GenAI HEFs)

Method: mmap walker (hefmap10.py, sha256 ea81da71…) that
derives each artifact's zero point from its own v3 header
(proto_size @ word 2, padding @ word 7, zero = 56 + both)
and walks the same schema. **Control:** run on MiniLM it
reproduces AES-NUM-011/013/014 exactly (1,605 actions;
channels 753/452/400; 153 small bursts; lane-0 top word
×132; clusters 1–4 + elided 0; LCU max 15).

- Blob sha256_773470cd… (1,677,961,416 B): zero 3,649,536;
  219 contexts; 129,665 pointer actions; 5,564 small
  bursts. **Lane-0 top value is the same word
  `0528000000000000` — 4,820 of 5,564 (86.6%). Lane-2
  tail distinct = 1 (all-zero).**
- Blob sha256_0a0d378c… (1,402,376,894 B): zero 2,576,384;
  180 contexts; 92,107 pointer actions; 4,040 small
  bursts. **Lane-0 top value the same word — 3,960 of
  4,040 (98.0%). Lane-2 tail distinct = 1 (all-zero).**
- LCU addressing in both: clusters 1–4 (+ elided 0), LCU
  max 15 — the AES-NUM-014 floor (≥5 × ≥16) is NOT raised
  by 219+180 further contexts; it stands as measured.

## Grades

- **Lane-2 width: EMPIRICAL, cross-artifact.** In 9,757
  small bursts across three unrelated networks (embedding
  + two LLMs), lane 2's bytes 3–7 are always zero; only
  its low 3 bytes carry variation. A burst's third word
  is a ≤24-bit field in a 64-bit lane — measured, not
  inferred.
- **Lane-0 dominant word: EMPIRICAL-CANDIDATE.** The word
  `0528000000000000` (LE 0x0000000000002805) dominates the
  small bursts of every artifact walked (132/153,
  4,820/5,564, 3,960/4,040). It behaves as a fixed
  burst-header constant across network families; its
  *meaning* is still not claimed — candidate until a
  field-level source or a counter-artifact speaks.
- **Zero-point formula: corroborated twice more.** Each
  blob's own header-derived zero produced full lane
  structure (a wrong base yields noise, per AES-NUM-013's
  controls) — the formula now holds on three artifacts.
- Census floor: unchanged (≥5 clusters × ≥16 LCUs).

## Evidence boundary

Three of seven corpus artifacts walked; the remaining
four blobs are unexamined. Same-family one-parameter
pairs (AES-NUM-012's ideal) are still not in hand — the
GenAI blobs differ from MiniLM and each other in many
parameters, so parameter-tracking (which field moves WITH
one parameter) remains the recipe/model-zoo pair's job.
Next: 4.16 walk the remaining four blobs (lane-0/lane-2
universality + census floor test at full corpus scale);
4.17 lane-1 structure hunt (the fully-varying lane —
byte-1 always varies, bytes 3/7 often: the operand
lane where parameter fields must live).
