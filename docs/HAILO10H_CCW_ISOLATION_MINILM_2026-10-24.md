# Schema-guided CCW isolation — the MiniLM HEF (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.11 (AES-NUM-011),
continuing the empirical program of AES-NUM-010. Question:
where do the CCW-bearing fields sit in a real Hailo-10H
artifact, and what do they look like statistically?

## Schema (pinned public source)

`hailort/libhailort/hef.proto` @ HailoRT pin
`d503417f2a0db186a838390fb08690c4ea0f415e` (fetched via the
GitHub API this slice; the twister forks hold no `.proto` —
they are driver trees, common+linux only, 2.6 MB). The
containment path for configuration actions:

- `ProtoHEFHef` field 2 → `ProtoHEFNetworkGroup`
  (this matches the 56,193-byte region of the AES-NUM-010
  wire map: the artifact's single network group)
- field 3 → `ProtoHEFContext` (×6 in this artifact)
- field 2 → `ProtoHEFOperation`
- field 2 → `ProtoHEFAction`, whose oneof carries
  `write_data_ccw` = field 3 (inline: bytes data=1,
  cfg_channel_index=2) and `write_data_ccw_ptr` = field 16
  (offset u64=1, size u32=2, cfg_channel_index=3).

## Isolation result (schema-guided walk, artifact unmoved)

- **1,605 actions total; every configuration write is the
  POINTER form (field 16). Inline CCW actions: zero.** Other
  action kinds present: allow_input_dataflow ×15,
  write_data_by_type ×30, enable_sequencer ×30,
  wait_for_sequencer ×60, wait_for_module_config_done ×18.
- The pointer actions reference **9,832,200 bytes** in total,
  offsets spanning **1,862,144 → 11,698,480** (the artifact is
  11,759,616 bytes) — i.e. the config/data payload is
  file-resident bulk, carved by (offset, size, channel)
  triples; it is not inside the 56 KB protobuf.
- **Channels used: 0 (753 actions), 1 (452), 2 (400).**
- **Size structure:** the modal small size is **24 bytes =
  3 CCW words** (343 actions), with 32/48/64/72/80/96/120-byte
  classes above it and a heavy tail of large transfers
  (weights-class data rides the same action kind — samples at
  referenced offsets are high-entropy). The small sequential
  24-byte bursts at twin base areas (~2,511,360 ch.1 /
  ~3,018,240 ch.2, offsets advancing by exactly 24) are the
  burst structure the field table's ID-27 record describes.

## Open sub-questions (recorded, not resolved)

- **Offset base:** file-absolute vs protobuf-relative (56 B)
  is NOT discriminated by the two samples taken (both landed
  in weights-class data). Discrimination needs a structured
  target (a small burst whose neighbours differ by base).
- **Word-level structure** inside the pure small bursts:
  which of the 24-byte actions are configuration (vs weight
  chunks) is a classification the differential slice (4.12)
  is designed to force: change one known parameter, watch
  which triples and which words move.

## Evidence boundary

Isolation is ESTABLISHED at the action level for this
artifact (schema + artifact agree field by field). No CCW
word's *meaning* is claimed. The census is untouched. One
artifact, one network — generalization is the differential
program's job, not this slice's.
