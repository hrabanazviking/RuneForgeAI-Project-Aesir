# Ordinary safetensors source facts and reader audit

Date: 2026-10-20. Parent: `TASK_hailo10h_safetensors_inventory.md`.
Controlling owner scope: `HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Format facts before implementation

Read Apache-2.0 LICENSE before the canonical format description at safetensors
v0.7.0 commit `fa27fa835a466cb50d07696ec20b94f46aed0e31`. The pinned format
has an unsigned little endian 64-bit JSON-header length, followed by that many
UTF-8 bytes and the raw tensor buffer. JSON begins with `{`; trailing ASCII
space padding is allowed. A tensor descriptor supplies dtype, all shape axes
and two offsets relative to the start of the tensor buffer, with an exclusive
end. Storage is little endian row major. Duplicate keys are forbidden.

The optional metadata entry is a string-to-string map. Tensor values may retain
NaN/Inf; metadata inspection must not evaluate or sanitize them. Rank-zero shapes
represent scalars. Shapes with a zero axis represent empty tensors and consume
no data. Tensor intervals must cover the entire data buffer without holes or
overlap. A zero-length interval requires no value read. File position is
`8 + header_bytes + relative_tensor_offset`, with checked arithmetic.

An isolated installed safetensors 0.7.0 oracle has the same pinned Apache
license; its binary/license hashes are recorded before use. A five-case tiny
format observation accepts empty tensor offsets at a neighboring tensor's
boundaries (0 and 4) and refuses positions strictly inside that 4-byte tensor
(1, 2 and 3). No framework/model/context/tensor math was imported or executed.
The independent original validator can enforce this boundary invariant without
reading or translating the external implementation. These observed cases do
not certify a complete parser implementation.

## Existing project reader audit

The existing project reader is `armvegr/safetensors.mojo`, SHA-256
`394be01a956b8c5ac7827d60b2317b0b1c26512e632d25bf8deab0bd3b84476b`
before this repair. This is a static source audit, not new execution evidence.
It already provides read-only mapping, pointer-range checks, owned descriptors,
surrogate escape handling, duplicate tensor-name and overlap checks, plus
historical F16/BF16/F32 representation routines. Metadata inspection will never
call those conversion routines or any CPU inference method.

Before SMIÐR consumes that parser, repair these observed code boundaries:

- String construction uses a NUL-terminated unsafe pointer. It does not validate
  raw UTF-8 and cannot preserve an escaped embedded NUL. Reuse the project's
  checked length-aware `String(from_utf8=...)` construction instead.
- Header/tensor/rank/recursive-skip/comparison work has no explicit caller
  bounds. The shape product multiplies unchecked before byte-size validation.
- Descriptor fields may repeat; missing shape currently looks like scalar;
  root/descriptor loops can accept a trailing comma. Integer scanning accepts
  leading-zero forms; skipped numbers are not checked against JSON grammar.
- Metadata is skipped as arbitrary JSON, without its string-map requirement.
  Relative offsets are added to the base before validating their full range.
- Overlap-only checks do not establish complete byte-buffer coverage, and
  zero-length intervals need explicit boundary behavior.
- Failed/reopened/closed owners need deterministic descriptor/metadata reset;
  the new inventory must copy all values and close the reader on every path.

No historical evidence is removed. Existing model execution guards remain in
place; host format repairs do not authorize CPU model math.

## Narrow original implementation contract

Repair the existing project parser and keep its public default calls usable.
Add explicit positive header/tensor/rank/descriptor-work/depth policy arguments
for the new metadata path; check them and file/header extents before parsing,
and rank/tensor/work limits before growing corresponding containers. Bound
recursive skipping; use strict JSON integers/number syntax, checked shape/byte/
relative-origin arithmetic, exact required fields and duplicate keys, metadata
string maps, exact coverage and empty-boundary validation. Preserve Unicode,
embedded NUL data and ordinary row-major axes. Initial descriptor dtype coverage
is the existing three floating types; other dtype decoding remains explicit
implementation work toward broad support, never a permanent model restriction.

Add an original SMIÐR inventory adapter with owned tensor name/dtype/full shape/
element count/file span and owned metadata; retain source byte size and data
origin. Do not invent architecture information absent from the weight file.
Do not project arbitrary ranks/scalars/empty shapes onto the GGUF matrix-only
binding type. Close mappings before returning the snapshot. Immutable file
identity, shard/index/config mapping and semantic source-weight consumption
remain explicit subsequent integration work.

Verify with independent synthetic struct/JSON fixtures and the pinned isolated
format oracle, strict malformed/adversarial cases, empty/scalar/Unicode/NUL,
shape/offset arithmetic, exact policy bounds, reader cleanup/reopen and owned
results. Trace read-only behavior and prohibit external runtime/model/device
libraries. No source-model download, special compilation/conversion workflow,
CPU/CUDA/cloud LLM inference, external compiler, numerical device submission or
hardware support claim belongs to this slice. Preserve all evidence, publish
verified narrow code, and continue actual numerical compiler/configuration/
placement/transport work toward the owner's fixed broad ordinary-model target.

Primary sources:
[license](https://github.com/huggingface/safetensors/blob/fa27fa835a466cb50d07696ec20b94f46aed0e31/LICENSE),
[canonical format description](https://github.com/huggingface/safetensors/blob/fa27fa835a466cb50d07696ec20b94f46aed0e31/README.md#format).
