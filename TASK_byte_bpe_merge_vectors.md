# AES500-151 — byte BPE merge-vector contract

## Objective and owners

Specify the byte/token merge-vector behavior before changing tokenizer code.
Owners are `RuneWeaver._initial_pieces`, `_merge_sentencepiece`,
`_append_piece_tokens`, and `encode` in `aesir_engine/loader/tokenizer.mojo`.
The input vocabulary is the model-provided token-to-ID map with parallel scores.

## Current merge behavior

Text is normalized to `▁` or `Ġ` for spaces when those markers exist in the
vocabulary; otherwise literal spaces remain. Input is split into UTF-8 symbol
pieces. At each iteration, the tokenizer scans adjacent pairs, looks up their
concatenation, and merges the available pair with the highest score. It repeats
until no adjacent vocabulary merge exists. Equal scores keep the earliest pair
because the comparison is strict `>`. Unmapped final pieces use `<0xHH>` byte
tokens when available, otherwise the unknown-token ID.

## Contract and exclusions

The tests should pin deterministic tie-breaking, chained merge order, UTF-8
symbol boundaries, byte fallback for unmapped pieces, and exact output IDs.
They exercise only this RuneWeaver path; they do not establish GPT-2 regex
pre-tokenization, external tokenizer parity, all malformed UTF-8 behavior, or
model-wide multilingual fidelity. AES500-152 captures the pre-change vectors.
No tokenizer code changes in AES500-151.


AES500-152 baseline: equal-score leftmost tie -> `[4,3]`; higher-scored right merge -> `[1,5]`; chained merge -> `[6]`; emoji byte fallback -> `[11,12,13,14]`. Source/tool hashes and limitations are in `docs/evidence/byte-bpe-merge-baseline-2026-10-10/README.md`. Master suite is 218 passed, 0 failed, 1 skipped (219 total).


## AES500-153 interface receipt

The public vocabulary/encoding seam is exercised without private helper calls: registering `x`, `y`, and scored `xy` yields `[3]` for `encode("xy", False)`, while empty input emits no token when BOS is disabled. Master suite: 219 passed, zero failed, one skipped (220 total).
