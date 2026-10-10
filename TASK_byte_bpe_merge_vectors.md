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


## AES500-154 implementation receipt

The score comparator now explicitly selects the lower pair index when candidate scores are equal. This preserves existing finite-score outputs while making deterministic tie behavior visible in the implementation. The master suite passes 219/0/1 (220 total), including all exact merge vectors.


## AES500-155 unit evidence receipt

Repeated equal-score input produces the same `[4,3]` vector twice. A partial byte vocabulary with only `<0xF0>` mapped returns `[11,99,99,99]` for 😀 when unknown ID is 99. Master suite: 220 passed, zero failed, one skipped (221 total).


## AES500-156 integration receipt

The four encoded emoji fallback IDs select their actual `<0xHH>` vocabulary strings and feed them through `RuneStreamDecoder`; the combined output is exactly 😀. Master suite: 221 passed, zero failed, one skipped (222 total).


## AES500-157 adversarial evidence receipt

For input `abc`, pair scores -3 (`ab`) and -1 (`bc`) emit `[1,5]`, proving the numerically higher negative score wins. Equal -2 scores emit `[4,3]`, preserving leftmost tie. Master suite: 222 passed, zero failed, one skipped (223 total).


## AES500-158 review receipt

Primary review reconciles `_merge_sentencepiece` against the exact vectors: strict greater-score choice, explicit lower-index equal-score tie, repeated convergence, and byte fallback. The public `encode` tests cover no-BOS empty input, partial-byte unknown fallback, and streaming decoder reconstruction. All evidence is synthetic; no external BPE parity is claimed. Independent Auditor assignment remains unavailable because the collaboration service reports its thread cap; no separate reviewer signoff is claimed.
