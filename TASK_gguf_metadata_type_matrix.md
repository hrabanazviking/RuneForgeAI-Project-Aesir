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


AES500-132 baseline: four generated files confirm mismatched types for
`llama.context_length` (UInt64), `llama.rope.freq_base` (UInt32),
`tokenizer.ggml.add_bos_token` (UInt32), and `general.alignment` (UInt64) are
skipped; each corresponding default remains unchanged and `inspect_metadata`
completes. The corpus, source/tool hashes and reproduction command are in
`docs/evidence/gguf-metadata-type-baseline-2026-10-10/README.md`.


## AES500-133 interface receipt

The executable fixture interface in `aesir_engine/tests/test_gguf_metadata_types.mojo` writes mapped version-3 files and calls `GGUFSeer.inspect_metadata(RuneWeaver)`. Its four currently supported mismatch observations cover UInt32, UInt64, and the parser's bool value type as actual inputs, verify that `inspect_metadata` completes, and assert the corresponding default is unchanged. This interface is the bounded seam for AES500-134 behavior changes; no public method signature changes. Unknown keys remain governed by `skip_value`.


## AES500-134 implementation receipt

`_parse_metadata_value` now derives the expected GGUF value type for each selected scalar/string metadata branch and rejects mismatches with `GGUF metadata key has unexpected value type: <key>` before reading or mutating its destination. The three tokenizer arrays retain their existing dedicated array and element-type diagnostics. Unknown metadata keys retain generic `skip_value` traversal. The four interface fixtures now require key-specific rejection and FAILED/unmapped cleanup; unrelated metadata and public signatures are unchanged.


## AES500-135 unit evidence receipt

Eight generated mapped files now check wrong types for context length, embedding length, RoPE frequency, RMS epsilon, both tokenizer boolean flags, alignment, and `tokenizer.ggml.tokens`. The seven selected scalar keys require the stable key-specific mismatch diagnostic; the recognized array requires its dedicated non-array diagnostic. Every rejection asserts FAILED state and closed mmap. Focused Mojo module passes.


## AES500-136 integration receipt

A generated mapped GGUF with a wrong context-length value type is exercised through `mmap_and_load`. The full load path preserves the key-specific diagnostic, reaches FAILED with mmap closed and `is_loaded` false, and leaves the MimirWell allocation offset unchanged. Focused module passes; this confirms rejection occurs before tensor allocation for this fixture.


## AES500-137 adversarial receipt

The focused fixture adds a recognized tokenizer tokens array with an invalid element-type declaration and an unknown metadata key carrying invalid value type 13. They reject with `tokenizer.ggml.tokens must be a string array` and `GGUF contains an invalid metadata value type` respectively; both end FAILED with mmap closed. Focused module passes. The wrong-element check occurs before reading array length or token entries.


## AES500-138 review receipt

Primary review of AES500-134–137 confirms the type map matches the parser branches, including the distinct `.attention.head_count_kv` suffix; recognized arrays retain their own type and element checks; unknown keys remain on `skip_value`; and the eight mismatch plus integration/adversarial fixtures assert stable errors and mapping cleanup. No independent Auditor signoff is claimed because the collaboration service rejected reviewer assignment at its thread cap. Remaining boundary: only explicitly consumed metadata keys are strict; arbitrary unknown keys are structurally traversed, not semantically validated.


AES500-139 documentation sync: `aesir_engine/loader/INTERFACE.md` now states
the selected-key encodings, key-specific mismatch errors, dedicated tokenizer
array validation, and structural-only handling of unknown keys. Historical
baseline behavior remains separately hash-bound in its evidence README.


## AES500-140 release gate

Mojo 1.0.0 sm_89 native build and executable `--help` smoke pass. The full master suite reports 212 passed, zero failed, one explicitly skipped external-fixture case (213 total). `python3 scripts/check_doc_drift.py` and `git diff --check` pass. The work was pushed to `docs/cross-cutting-500-slice-roadmap`; exact pushed SHA is recorded in Git history. Hosted Actions runs for recent slice heads were still in progress at the time checked; no hosted pass is claimed.
