# Classic Q4/Q5 source block fields

Date: 2026-10-22. Contract: TASK_hailo10h_classic32_source_constants.md.
These are GGUF source storage facts. They establish no Hailo instruction,
precision, physical packing, resource fit or numerical execution.

The public ggml MIT license was re-read before this format study. The immutable
revision is `a05c9922613c6a2230dbb1d0de679519ecafb4f0`; retained source/license
hashes match the previous fetched pin. No external implementation is copied,
translated or adopted. Source bodies remain outside production. Provenance and
pre-code identities: docs/evidence/classic32-source-contract-2026-10-22.

All four formats have 32 logical elements per block. Scale/bias words and the
four-byte high-bit plane use little-endian source ordering. Offsets are bytes.

| GGUF kind | Format | Bytes/block | Scale d | Bias m | High plane | Nibbles | Quant interpretation |
|---|---|---:|---|---|---|---|---|
| 2 | Q4_0 | 18 | 0..1 | absent | absent | 2..17 | unsigned nibble minus8 |
| 3 | Q4_1 | 20 | 0..1 | 2..3 | absent | 4..19 | unsigned nibble |
| 6 | Q5_0 | 22 | 0..1 | absent | 2..5 | 6..21 | unsigned five-bit quant minus16 |
| 7 | Q5_1 | 24 | 0..1 | 2..3 | 4..7 | 8..23 | unsigned five-bit quant |

For lane i in0..31, the nibble byte is its origin plus i mod16. Lanes0..15
use the low nibble; lanes16..31 use the high nibble. For Q5, the additional
quant bit is high-plane bit i, equivalently byte floor(i/8), bit i mod8.
Combine it with the nibble before applying the stated centering offset.

The static source expression is d*q for Q4_0/Q5_0 and d*q+m for Q4_1/Q5_1.
Both d and m are binary16 words. A source reader must preserve their exact
bits, expanded representations and bias presence independently; an absent bias
is distinct from a present zero or signed-zero bias. Production need not evaluate
a floating product or addition to own these source components.

Rows contain whole blocks, so columns divide32 and row bytes are block count
multiplied by the listed byte size. Adjacent rows need not begin at a new GGUF
tensor-alignment boundary. Partial byte tiles retain complete touched blocks
and exact unused prefix/suffix elements. No byte address becomes an NPU address.

Primary pinned sources:
[type tags](https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/include/ggml.h),
[block fields and sizes](https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/src/ggml-common.h),
[static interpretation](https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/src/ggml-quants.c),
[license](https://github.com/ggml-org/ggml/blob/a05c9922613c6a2230dbb1d0de679519ecafb4f0/LICENSE).

This contract qualifies four additional formats; all remaining formats, ranks
and architecture semantics stay implementation work toward broad ordinary
unmodified source models. It introduces no outside model compiler/machine,
precompiled prerequisite or inference proxy. LLM execution remains Hailo-only.
