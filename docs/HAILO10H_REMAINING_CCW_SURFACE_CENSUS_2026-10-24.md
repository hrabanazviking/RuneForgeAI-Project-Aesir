# Census of the remaining CCW surface (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.29 (AES-NUM-029).
Population: every action in all seven corpus artifacts —
MiniLM plus the six hailo-ollama blobs — walked on Mimir
with hef29.py (sha256 63984201…; schema-guided walk per
AES-NUM-011, extended to every action kind and every
pointer form). Control: the walk reproduces AES-NUM-028's
per-artifact 24 B channel-1/2 burst counts EXACTLY
(153 / 5,546 / 5,836 / 4,040 / 8,089 / 5,564 / 6,287;
pooled 35,515) and AES-NUM-011's MiniLM pointer totals
(1,605 actions, 9,832,200 bytes, channels 753/452/400).

## The pointer form is the whole write surface

- **745,849 pointer actions** (hef.proto field 16,
  `write_data_ccw_ptr`) across 788,726 total actions,
  referencing **11,096,892,840 bytes**. Per artifact:
  1,605 / 129,664 / 131,262 / 92,107 / 123,746 / 129,665 /
  137,800 actions.
- **Inline CCW (field 3), plain write_data (field 2) and
  write_compressed_data (field 4): ZERO in all seven
  artifacts.** No configuration byte rides inside the
  protobuf anywhere in the corpus; every written byte is
  file-resident bulk carved by (offset, size, channel).
- The non-pointer action set is closed and small, identical
  in kind across the corpus: enable_sequencer (5),
  wait_for_sequencer (6), allow_input_dataflow (10),
  wait_for_module_config_done (11), write_data_by_type
  (14). Fields 7/8 (LCU enable/disable), 9, 12, 13, 15,
  17, 18 never appear.
- **Channels: only 0, 1, 2 — ever.** Every pointer size is
  a multiple of 8; no zero sizes, no sub-word sizes;
  maximum size 32,784 bytes in every artifact.

## The headline: the 24 B burst also lives on channel 0

The AES-NUM-015…028 burst programme censused channels 1/2
only. Channel 0 carries the same 24-byte form:

- **43,486 channel-0 24 B bursts pooled** — more than the
  35,515 of channels 1/2 combined (total 24 B population
  is now 79,001). Per artifact: 190 / 6,614 / 7,218 /
  5,058 / 9,983 / 6,596 / 7,827.
- The lane-0 champion `0528000000000000` heads **42,118 of
  43,486 (96.9%)**; the lane-2 width law (bytes 3–7 zero)
  holds in **43,486 of 43,486**. The burst is not a
  channel-1/2 dialect — it is the corpus's unit of
  configuration on every channel.
- NOT yet established: whether the channel-0 bursts obey
  the operand→datum function/affine laws and whether the
  frozen encoders (AES-NUM-026/028) predict their datums.
  That is slice 4.30, and until it lands the frozen datum
  coverage figure (94.6%) is a channels-1/2 figure.

## The small-form surface (≤512 B) — the config-shaped rest

- Per artifact: 40–90 distinct (size × channel) forms,
  684–28,980 actions, 93 KB–2.8 MB. Pooled: **128,787
  actions, 12,213,872 bytes** — 17.3% of pointer actions
  but 0.11% of referenced bytes.
- Sizes form a structured ladder, all multiples of 8:
  24, 32, 48, 64, 72, 80, 96, 120, 144, 176, 184, 200,
  208, 216, 232, 248, 256, 264, 272, 280, 296, 304, 312,
  320, 328, 344, 360, 376, 392, 400, 408, 416, 424, …
  Channel 0 dominates the small forms (e.g. the 72 B and
  120 B forms are channel-0-only in every artifact —
  one per context).
- Word content of the 8–128 B forms: 423,993 words pooled,
  **66,784 all-zero words (15.8%)** — the NOP-class word
  of AES-NUM-005 is a routine inhabitant of the small
  forms, not an exception.

## The large-form surface (>512 B) — weights-class bulk

- The remaining ~617k pointer actions are large transfers:
  per-artifact distinct sizes run 74–1,469 per channel,
  sizes up to the uniform 32,784 cap. Their size variety
  (thousands of distinct sizes in the GenAI blobs vs 230
  in MiniLM) is data-shaped, not form-shaped: this is the
  weights/payload class riding the same action kind, as
  AES-NUM-011 first sampled.
- Referenced regions are REUSED in the blobs: distinct
  offsets (55k–113k) run well below action counts
  (92k–138k), and union coverage (0.86–2.23 GB) runs below
  summed bytes. MiniLM is the exception (1,605 distinct
  offsets = 1,605 actions, union = sum exactly).
- Unreferenced file bytes after the zero point measure
  1,870,072 (MiniLM) and 0.48–0.65 GB per blob — file
  content no pointer action references (recorded as
  measured; its composition is not claimed).

## What this closes and what it queues

- MEASURED, corpus-wide: the remaining CCW surface is
  (a) the channel-0 24 B bursts, (b) the ≤512 B small-form
  ladder, (c) large weights-class transfers. There is no
  fourth write form and no hidden inline surface.
- The Campaign-5 gate reading of AES-NUM-028 stands for
  the datum component on channels 1/2; channel 0 is now
  the largest untested burst population and goes first.
- NEXT (4.30): channel-0 burst treatment — family census,
  function/affine/width tests, and cross-prediction by the
  frozen champion + family encoders (hef28 method,
  channel-0 population). Then (4.31): small-form word
  anatomy per size class.

## Evidence boundary

Host/artifact analysis only; no physical child ran.
Counts are complete-population over the seven artifacts;
blob identities are sha prefixes only, as before.
