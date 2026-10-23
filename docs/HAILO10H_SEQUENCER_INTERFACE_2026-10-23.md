# Sequencer configuration and completion record boundary

Date:2026-10-23. Parent:`TASK_hailo10h_numerical_encoding_sources.md`.
Controlling scope:`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Pinned declarations and provenance

Actual HailoRT MIT license was read before declaration bodies. Fresh immutable
URL retrievals at revision `d503417f2a0db186a838390fb08690c4ea0f415e`
match the previously retained bytes. Per-file MIT notices are preserved. This
study extracts interface fields; it adopts no external implementation. The
program schema is data-format evidence under that repository license.
Raw sources remain outside production; identities and retrieval order are in
`evidence/sequencer-action-contract-2026-10-23/`.

The public packed context enum assigns trigger-sequencer1 and
sequencer-done-interrupt17. The common header is action/u8 then timestamp/u32,
with an all-ones timestamp initializer. The trigger body is cluster-index/u8
followed by the packed configuration below. The completion body has only
sequencer-index/u8. These are context record IDs, never arithmetic opcodes.

| Configuration member | Unsigned width | Body-relative offset within configuration |
|---|---:|---:|
| initial_l3_cut | 8 | 0 |
| initial_l3_offset | 16 | 1 |
| active_apu | 32 | 3 |
| active_ia | 32 | 7 |
| active_sc | 64 | 11 |
| active_l2 | 64 | 19 |
| l2_offset_0 | 64 | 27 |
| l2_offset_1 | 64 | 35 |

Configuration extent43, trigger body44 and complete trigger49 bytes; completion
body1 and complete record6 bytes. Original codec qualification will compare
these inferred offsets/extents and enum values against actual header objects
on this little-endian host. No numerical bitfield is inferred from the names.

The public C++ declaration independently exposes the same trigger parameter
widths. The program protobuf has a different representation: initial-L3 index
and offset/u32 plus a presence flag, four l2_write/u32 members, cluster/u32 and
active bitmaps. This study does **not** establish the conversion from those
four words to the two packed offsets or qualify physical indices/bitmaps.
Do not cast the protobuf representation into this packed body.

## Concrete original implementation and limits

Add an isolated original Mojo value codec for these two packed records under
`TASK_hailo10h_sequencer_actions.md`. Callers provide explicit final wire values.
Validate widths, exact record extents, known kinds and zero absent trigger
fields on completion. Preserve the full unsigned64 range of bitmaps/offsets;
their high bits are not known reserved bits. Do not invent resource-count
limits from field widths. Decode/encode remain host byte operations.

No source operation is assigned a physical cluster, L3 cut, APU, input aligner,
subcluster or L2 address. This adds neither arithmetic instructions nor a safe
raw-context transport. The Pi NNC boundary remains unchanged. Actual numerical
encoding/precision/packing/placement, original program upload/activation and
bounded hardware results/cleanup remain required work under the fixed broad
ordinary-source-model target. No model, compiler, vendor container or device
was opened or executed in this study. Search excerpts and unrelated mirrors
were excluded from field qualification.

Primary sources:
[packed context declarations](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/common/include/context_switch_defs.h),
[typed trigger declaration](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/src/hef/context_switch_actions.hpp),
[distinct program schema](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/hef.proto).
