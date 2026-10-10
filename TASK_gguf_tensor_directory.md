# AES500-141 — GGUF tensor directory contract

## Objective and owners

Define the mapped tensor-directory contract before changing parser behavior.
Owners are `GGUFSeer._parse_tensors`, `_tensor_byte_size`, and `_map_tensor` in
`aesir_engine/loader/gguf.mojo`; required model shapes are subsequently checked
by `_validate_required_tensors`. The directory consists of `tensor_count`
records starting after metadata. Each record has a length-prefixed name, a
rank, dimensions, GGML type, and relative data offset.

## Current admitted shape and placement

The inference loader accepts rank one or two, maps rank one to one row, and
rejects non-positive dimensions. Only aligned relative offsets are admitted;
absolute data offsets are `data_offset + tensor_offset` and are checked against
the mapped file before mapping or F32 conversion. Duplicate names reject.
F16 tensors alias mapped storage, F32 tensors are copied to MimirWell as F16,
and selected compressed types map as quantized RuneTensor views. Required
names, dimensions, and types are checked later for the inference architecture.

The parser first collects directory records, aligns the cursor to `alignment`
to determine `data_offset`, then maps each tensor. The current code does not
record an explicit declared directory byte length. This contract therefore
covers existing record/range behavior, not arbitrary integer-overflow safety,
all-rank GGUF support, complete quantization-block arithmetic, tensor overlap
rejection, or validation of every optional tensor. AES500-142 captures baseline
acceptance and rejection before implementation changes.

## Acceptance

This document names directory layout, parser owners, rank and dimension rules,
placement, mapping modes, later required-tensor checks, and explicit exclusions.
AES500-141 changes no parser code.


AES500-142 baseline: one generated rank-one 1x1 F16 `fixture.weight` maps successfully before expected missing-required-tensor rejection. The test checks descriptor dimensions plus FAILED/unmapped cleanup. Source/tool hashes and scope limits are in `docs/evidence/gguf-tensor-directory-baseline-2026-10-10/README.md`; this is not complete model or compressed-layout evidence.
