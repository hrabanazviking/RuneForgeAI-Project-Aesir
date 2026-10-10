# AES500-131 — GGUF metadata value type matrix

## Objective and owners

Specify the current metadata value-type admission and traversal contract before
changing parser code. Owners are `GGUFSeer.skip_value` and
`GGUFSeer._parse_metadata_value` in `aesir_engine/loader/gguf.mojo`, with the
fixed-count traversal in `_parse_metadata`. This slice is documentation only.

## Supported generic value traversal

The parser currently skips scalar values by encoded width: types 0, 1 and 7
consume 1 byte; types 2 and 3 consume 2; types 4, 5 and 6 consume 4; and types
10, 11 and 12 consume 8. Type 8 is a length-prefixed string. Type 9 reads an
array element type and UInt64 length, rejects element types >=13, rejects a
length greater than mapped file size, then recursively skips each element.
Other types reject. This is traversal support, not a claim that all GGUF
versions or all semantic encodings are accepted by inference.

## Inference-consumed metadata

`_parse_metadata_value` consumes `general.architecture` as string type 8;
selected dimensions, head counts, RoPE dimension, alignment, and tokenizer IDs
as UInt32 type 4; RoPE frequency base and RMS epsilon as F32 type 6; tokenizer
boolean controls as type 7; and tokenizer tokens/scores/token types as arrays
of types 8/6/5 respectively. These are the exact current parser branches.
For most selected scalar keys, a mismatched type currently falls through to
`skip_value` rather than reporting a key-specific type error. The three
recognized tokenizer arrays reject non-array values and enforce their element
types in dedicated readers.

## Scope and evidence boundaries

This matrix covers branch selection and bounded byte traversal only. It does
not establish semantic validity of arbitrary metadata, Unicode validity,
complete recursive-array resource bounds, count/offset overflow safety, complete
GGUF compatibility, or inference readiness. AES500-132 captures the current
mismatch behavior and representative valid/invalid type cases before any
implementation change.

## Acceptance

The owners, scalar widths, string/array layout, consumed metadata types, current
mismatch behavior, and exclusions are explicit. No parser code changes in
AES500-131.
