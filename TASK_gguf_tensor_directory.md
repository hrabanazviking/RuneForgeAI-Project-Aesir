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


## AES500-143 interface receipt

The synthetic tensor-record builder and `mmap_and_load` test interface cover rank 1 and rank 2 with positive 1x1 dimensions (mapping proceeds to the later missing-required-tensor error), rank 3 (rank diagnostic), and rank 1 with dimension zero (positive-dimension diagnostic). Each file ends FAILED/unmapped; rejected ranks/dimensions do not add `fixture.weight` to the tensor map.


## AES500-144 implementation receipt

The parser rejects UInt64 dimensions above signed host `Int` range before conversion; `_map_tensor` checks positive shape/product overflow and absolute-offset addition before arithmetic; `_tensor_byte_size` guards multiplication for F16/F32 and current block-size branches; F32 pool admission now compares requested elements to `capacity - offset` after validating the offset. Native sm_89 build and the focused GGUF module pass. This does not resolve quantization block divisibility or all GGML type byte layouts.


## AES500-145 arithmetic unit evidence

Four hostile directory fixtures cover UInt64::MAX dimension admission, a two-dimensional 3,037,000,500 × 3,037,000,500 element-product overflow, F16 byte-size overflow above `Int::MAX / 2`, and a 32-byte-aligned relative offset whose addition to `data_offset` overflows. Each asserts its specific diagnostic, no tensor descriptor, FAILED state, and mmap cleanup. The focused Mojo module passes.


## AES500-146 integration receipt

A generated 1x1 F32 tensor record containing 1.0 is loaded through `mmap_and_load`. It maps with GGML type F32, consumes exactly one MimirWell element for conversion, then fails at the expected later missing-required-tensor check; mmap cleanup is asserted. This verifies only the exercised conversion and ordering.


## AES500-147 resource adversarial receipt

A generated 1x2 F32 tensor requests two conversion elements from a one-element MimirWell. It rejects with the capacity diagnostic before tensor descriptor insertion; pool offset remains unchanged and loader mapping is cleaned. Focused module passes.


## AES500-148 review receipt

Primary review confirms record rank/dimensions are read before mapping, host-index guards precede product/offset arithmetic, F32 pool capacity is subtraction-based, and the rank/dimension/overflow/resource fixtures assert rejection before descriptor or pool mutation where applicable. The rank-one F16 and F32 conversion cases are synthetic and stop at later missing-required-tensor validation. Independent Auditor agent review is unavailable because the collaboration service thread cap rejects new reviewers; no independent pass is claimed. Quantized block byte layouts, overlap detection, and complete model validation remain outside the reviewed evidence.


AES500-149 documentation sync: `aesir_engine/loader/INTERFACE.md` summarizes rank-one/two positive shapes, aligned in-file offsets, F16 aliasing, F32 pool conversion, arithmetic guards, and the synthetic evidence boundaries.


## AES500-150 release gate

Native sm_89 build and executable `--help` smoke pass. Master suite reports 217 passed, zero failed, one skipped external-fixture case (218 total). Doc-drift and whitespace checks pass. Hosted workflow runs for recent slice heads remain in progress; hosted success is not claimed.
