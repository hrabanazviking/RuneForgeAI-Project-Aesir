# Native source weight byte tiles

Date: 2026-10-20. Contract: `TASK_hailo10h_source_weight_tiles.md`.
Original Mojo `smidr/source_weight_tiles.mojo` connects lazy matrix rectangles
to actual source bytes under a live read-only PackedGGUF owner. It validates
the complete schedule, then compares mapping size/data offset and the selected
weight's name, offset, columns, rows, packed kind and byte count. Closed owners
reject before any byte access. This is descriptor consistency, not an immutable
source fingerprint or protection against external concurrent file writers.

For each output row, the returned owned `SourceWeightSpan` records source row,
file origin/byte count, covered logical column/count, prefix/suffix constants
outside the requested interval and offset in an owned concatenated payload.
F32/F16/BF16 spans cover exact selected scalars. Q4_K/Q5_K/Q6_K spans cover the
smallest complete 256-element blocks, using the existing 144/176/210-byte source
layouts. Spans never cross rows/tensor/file extents. Arithmetic and aggregate
host byte bound are checked before allocation/copy; all spans are validated
before reading payload through checked little-endian halfwords. Whole source
rows/models and full contraction products are not materialized by this pass.

`read_source_weight_tile(source,schedule,index,host_byte_bound)` returns move-
only `SourceWeightTile` with copied binding, rectangle, spans and payload.
No borrowed pointer escapes. The copied bytes remain valid after source owner,
semantic graph and schedule destruction or descriptor mutation. The host bound
covers aggregate payload bytes, not interpreter/list/descriptor overhead or
physical device memory. Matrix workspace remains an independent explicit
scenario. The diagnostic CLI takes separate workspace and host byte bounds.

## Verification

Both builds pass warning-free on Mojo 1.1.0:

```sh
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine smidr/tools/source_weight_tiles.mojo -o ../source-weight-tiles
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine tests/hailo_source_weight_tiles_api.mojo -o ../source-weight-tiles-api
python3 tests/test_hailo_source_weight_tiles.py --binary ../source-weight-tiles --api-binary ../source-weight-tiles-api --strace /usr/bin/strace --evidence docs/evidence/source-weight-tiles-2026-10-20
```

Five methods pass, 286 native calls (256 accepted,30 refused), with 88368
byte-for-byte independent slice checks. Frozen seeded synthetic payloads span
all six formats, multiple selected rows, output/contraction tails, partial and
crossing packed blocks, maximum tile extents and repeated M tiles. Explicit
minimum payload bounds accept; one byte short rejects. Twenty direct API
mutations cover closed owner, changed live source and returned schedule, missing
weight, source extents, overflow and invalid bounds/indices. Owned payloads
match before/after closing and destroying their owners. Source hashes stay
unchanged. Read-only trace opens no Hailo/CUDA/HailoRT/ggml node/library and
performs no ioctl. Evidence: `docs/evidence/source-weight-tiles-2026-10-20/`.

## Remaining hardware gates

This is source storage, not dequantized model evaluation, selected device weight
packing, physical placement, numerical CCWs or hardware execution. All device/
execution/immutable-source/packing flags remain false. Ordinary model files are
read directly inside Aesir; no external compiler or precompiled artifact is
required. Q5/Q6 component decoding is next under
`TASK_hailo10h_q5q6_source_constants.md`; actual numerical encoding/program
activation/result/cleanup remain open under the program-delivery parent.
