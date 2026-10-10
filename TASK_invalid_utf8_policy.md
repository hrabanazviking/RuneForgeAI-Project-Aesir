# AES500-171 — invalid UTF-8 policy

## Objective and owner

Define the boundary between RuneWeaver's UTF-8 text API and byte-level fallback.
Owners are `RuneWeaver.encode`, `_initial_pieces`, `_append_utf8_symbols`, and
`_append_piece_tokens` in `aesir_engine/loader/tokenizer.mojo`.

## Current API boundary

`encode` accepts Mojo `String`; it does not accept an arbitrary byte buffer.
When no vocabulary is loaded, it returns each input byte as an integer. With a
vocabulary, it estimates symbol widths from UTF-8 leading-byte ranges and
falls back to one byte when a nominal sequence extends past the buffer. It does
not explicitly validate continuation-byte shape, overlong encodings, surrogate
code points, or maximum scalar value before slicing. Byte fallback emits
canonical `<0xHH>` spellings for bytes when a piece is not in vocabulary.

The public contract should treat valid Unicode `String` as the supported input
surface. Behavior for strings constructed through unsafe invalid-UTF-8 pointers
is not yet specified and must not be advertised as a decoder guarantee. The
policy decision for AES500-171 is to fail closed on malformed byte sequences
if they can enter the public `String` boundary; safe-constructor behavior and
implementation feasibility will be measured in AES500-172/173 before changing
code.

## Scope

This slice does not cover RuneStreamDecoder malformed-byte replacement policy,
normalization, grapheme segmentation, arbitrary byte-buffer APIs, or external
Unicode conformance. AES500-172 captures current behavior for any safely
constructible invalid input and documents when no such input can be represented
without unsafe construction. No tokenizer code changes in AES500-171.


AES500-172 baseline: unsafe truncated `C3` with no vocabulary -> `[195]`; unsafe `C3 28` with byte vocabulary -> `[11,12]` via fallback. This demonstrates current byte preservation for two unsafe-constructed String fixtures, not safe-constructor acceptance. Source/tool hashes and limitations are in `docs/evidence/invalid-utf8-baseline-2026-10-10/README.md`. Master suite: 227/0/1 (228 total).


## AES500-173 interface receipt

The owner seam is the existing public `encode(prompt: String, add_bos: Bool = False) -> List[Int]`; no raising behavior or signature change is planned. Valid Strings keep existing behavior. Malformed byte sequences admitted through unsafe String construction must produce the unknown-token sentinel, with optional BOS prefix as described above. The current baseline test pins the public return path before the implementation changes it.


## AES500-174 implementation receipt

`RuneWeaver._is_valid_utf8` now validates leading-byte ranges, continuation bytes, overlong exclusions, surrogate exclusion, and the U+10FFFF ceiling. `encode` checks the borrowed byte span before tokenization; malformed input returns the configured unknown ID and retains an optional enabled BOS prefix. Valid input keeps the existing path. Focused malformed fixtures cover truncation, a bad continuation, overlong lead, surrogate, and above-maximum scalar; master suite passes 227/0/1 (228 total).


## AES500-175 adversarial unit receipt

Additional cases reject isolated continuation 80, overlong E0 80 80, overlong F0 80 80 80, and illegal F5 lead. The maximum valid scalar F4 8F BF BF remains byte-identical through no-vocabulary encoding. Master suite: 228 passed, zero failed, one skipped (229 total).
