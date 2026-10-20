# Pinned Q4_K source layout facts

Date: 2026-10-19. Study before original implementation.
Contract: `TASK_hailo10h_q4k_constants.md`.

## License and provenance

Re-read ggml MIT license at frozen revision
`a05c9922613c6a2230dbb1d0de679519ecafb4f0` before this continued source study.
License SHA-256:
`94f29bbed6a22c35b992c5c6ebf0e7c92f13b836b90f36f461c9cf2f0f1d010d`.
Public definitions/reference interpretation supplied data-format facts only;
no implementation is copied or translated. Study files remain outside Git.

| Source | SHA-256 |
|---|---|
| `src/ggml-common.h` | `0061131b615c5721fc88a78feeb22c1f8c450f1c2646a317d80796a653bf595c` |
| `src/ggml-quants.c` | `5574a2dccf7c07e75b143733e04a5412d3d8c819e7945f5217a7b83a2b2ff8ab` |
| `src/ggml-quants.h` | `28ae5fca1f3be636b36cd6c4fa2ca74fd42d229bfbd5352eaf66f3727bb8a6da` |

## Byte/field schema

One block represents 256 elements in 144 bytes. Offsets are block-relative:
scale `d` is binary16 at 0, minimum scale `dmin` binary16 at 2, packed group
parameters occupy bytes 4–15, and 128 nibble bytes occupy 16–143. There are eight
consecutive groups of 32 elements, each with unsigned six-bit scale/min factors.
The mathematical source value is `(d * scale_factor) * q - dmin * min_factor`.
This describes source representation, not a chosen device rounding/packing rule.

A parameter's low field and high field below combine as low + 16 * high;
zero-width high fields contribute zero. Bit positions are within each byte.

| Group | Scale low: byte/bits | Scale high: byte/bits | Min low: byte/bits | Min high: byte/bits |
|---|---|---|---|---|
| 0 | 4 / 0–5 | none | 8 / 0–5 | none |
| 1 | 5 / 0–5 | none | 9 / 0–5 | none |
| 2 | 6 / 0–5 | none | 10 / 0–5 | none |
| 3 | 7 / 0–5 | none | 11 / 0–5 | none |
| 4 | 12 / 0–3 | 4 / 6–7 | 12 / 4–7 | 8 / 6–7 |
| 5 | 13 / 0–3 | 5 / 6–7 | 13 / 4–7 | 9 / 6–7 |
| 6 | 14 / 0–3 | 6 / 6–7 | 14 / 4–7 | 10 / 6–7 |
| 7 | 15 / 0–3 | 7 / 6–7 | 15 / 4–7 | 11 / 6–7 |

For element i inside a block, group is floor(i/32). Its nibble is in byte
16 + 32 * floor(group/2) + (i mod 32), using bits 0–3 for even groups and
4–7 for odd groups. Row width must contain complete 256-element blocks under
the existing importer; successive blocks/rows retain source element order.

## Independent implementation and acceptance plan

Use an original generic bit-field schema reader over these published facts.
Return owned affine constant components with exact source scale bits and
integer q/scale/min factors; do not silently materialize a full F32 model or
choose Hailo weight precision. Reuse exact binary16 representation expansion
already exhaustively checked. Read only explicitly bounded source windows.

Synthetic fixtures must vary every group and low/high parameter bit plane,
nibbles and block/row boundaries. Independent fixture packing plus an externally
built pinned reference constant-dequantization oracle may validate the schema;
that test-only library is never a production dependency. Only isolated static
constant reconstruction is allowed, never a model/layer/attention forward.
Record any reference build dependencies/license facts before using it.

Source identity, additional formats, device weight conversion/layout, actual
CCWs, upload/activation and numerical hardware proof remain open. These source
format facts cannot narrow the owner's broad model objective or certify fit.

Primary sources:
[public layout](https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/src/ggml-common.h),
[reference format interpretation](https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/src/ggml-quants.c).
