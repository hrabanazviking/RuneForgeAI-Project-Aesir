# ARMVEGR shared metadata cursor interface

This section documents the existing `safetensors.mojo` JSON byte cursor and its
2026-10-20 shared metadata methods. It does not promote historical CPU inference
or conversion routes to authorized runtime capabilities. Existing CPU inference
guards remain unchanged; the owner requires all LLM execution on Hailo-10H.

`JsonParser(buf,n,max_depth=64)` borrows exactly n readable bytes. The caller
must establish the actual extent and keep its owner alive through every cursor
operation; the untracked pointer does not retain an owning List or mmap. Use
an explicit owner lifetime extension after the last cursor use when needed.
Cursor state begins at0. Existing `skip_ws`, `expect`, `parse_string`,
`parse_int`, `parse_size`, `parse_number_raw`, `skip_value` and their existing
safetensors grammar/refusals remain unchanged.

New shared methods:

- `peek() raises -> UInt8`: checked0..n cursor lookahead; returns0 at end.
- `copy_raw_span(first,end) raises -> String`: copies checked[first,end) bytes
  through strict UTF-8 construction. Empty spans are valid. It does not by
  itself certify JSON syntax or whole-input validity.
- `parse_raw_value() raises -> String`: validates/skips one JSON value with
  depth policy1..64 and copies its exact text, excluding outer whitespace.
  Nested duplicate keys and malformed strings/numbers/values refuse through
  the existing grammar. It does not require EOF; the consumer must check it.

Returned strings own storage and survive byte-owner destruction. A whole-document
consumer must enforce positive byte/work/nesting policies, top-level/schema
rules and exact trailing-whitespace/EOF handling. Errors from reused grammar
retain the historical `safetensors:` prefix. SMIÐR's source index is the first
additional consumer; the ordinary configuration reader also reuses this API; its borrowed-byte API pins the List through both passes.
Evidence and limits: `docs/HAILO10H_MOJO_SOURCE_INDEX.md` from repository root.


## Owned safetensors header metadata

`SafetensorsHeader(file_size,header_size,descs,metadata)` is a move-only owned
metadata result, with existing STTensorDesc dtype0 F16/1 BF16/2 F32 and full
source axes. No fd, mapping or tensor values are included.
`safetensors_header_length(prefix,file_size,header_bound)` requires exactly8
prefix bytes and validates declared length>=2 within bound and full file extent.
`decode_safetensors_header(data,file_size,header,tensors,rank,work,depth)`
borrows exactly prefix+declared-header bytes, applies positive policies and the
existing strict object/descriptor/metadata/coverage grammar, and returns copied
owned fields. The byte owner is retained through all raw-pointer use. Extra
payload or missing header bytes in this metadata buffer refuse. Full file size
is a separately supplied descriptive extent; the pure decoder does not verify
it on disk. Work remains the existing4*tensor_count squared admission policy;
header/rank/depth bounds separately govern other metadata. Known schema parsing
retains historical nesting behavior; depth applies to recursive skipped values.

The mapped `SafetensorsLoader` delegates header decoding to that same original
implementation and preserves its complete mapping/static constant contract.
Its legacy close still ignores syscall failures; this refactor does not certify
new cleanup or immutable-source behavior. Metadata-only buffers are never
presented as live full-file maps. Callers must not mutate returned fields and
then treat their earlier validation as applying to the mutated values.
Evidence: `docs/HAILO10H_MOJO_SAFETENSORS_FD.md`.
