# AES500-161 — Unicode normalization policy

## Objective and owner

Define Unicode normalization at the RuneWeaver text-to-piece boundary. Owner:
`RuneWeaver._initial_pieces` in `aesir_engine/loader/tokenizer.mojo`, with
byte fallback in `_append_piece_tokens`.

## Current behavior and intended policy

The tokenizer preserves input code points and performs no NFC/NFD/NFKC/NFKD
normalization. Its explicit preprocessing is limited to replacing ASCII space
with `▁` or `Ġ` when the corresponding marker is present in the vocabulary;
otherwise the space remains literal. UTF-8 text is split into symbol substrings
before vocabulary merge and byte fallback. Thus canonically equivalent but
byte-distinct inputs such as composed `é` and `e` plus combining acute remain
distinct sequences unless the model vocabulary merges them.

The policy for this slice is preservation: never normalize caller text
implicitly. Token IDs and decoded text depend on the model vocabulary, and
normalization would alter token boundaries and may change meaning in some
scripts. This policy is limited to RuneWeaver's current path and does not
establish Unicode segmentation conformance or correctness for malformed UTF-8.

## Acceptance and evidence

AES500-162 captures composed/decomposed vectors and ASCII space-marker cases
with source/tool identity. Tests must assert exact token IDs and no hidden
canonical-equivalence claim. No tokenizer code changes in AES500-161.


AES500-162 baseline: composed `é` -> `[11,12]` and decomposed `e` + acute -> `[13,14,15]`, demonstrating preservation. Mojo/source identity and hashes are in `docs/evidence/unicode-normalization-baseline-2026-10-10/README.md`. Master suite: 223 passed, zero failed, one skipped (224 total).


## AES500-163 interface receipt

Public `encode(" a", False)` returns the marker ID followed by `a` when `▁` is in vocabulary, and the literal-space ID followed by `a` when the vocabulary instead contains ASCII space. The composed/decomposed preservation vectors remain in the master suite. Suite: 224 passed, zero failed, one skipped (225 total).


## AES500-164 implementation receipt

`_initial_pieces` now states that caller Unicode code points are preserved because model vocabularies can distinguish canonical forms, and that only ASCII space receives marker rewriting. This makes the existing behavior explicit without changing token output. Master suite: 224 passed, zero failed, one skipped (225 total).
