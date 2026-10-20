# Native source weight byte tiles

Date: 2026-10-20. Contract before implementation.
Owner scope: `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Parent: `TASK_hailo10h_native_matrix_tiles.md` and program-delivery parent.

Consumer: the original SMIÐR source constant/streaming backend. Bind a lazy
matrix weight rectangle to a live read-only PackedGGUF owner. Recheck source
size/data offset/name/columns/rows/packed kind/byte extent against the schedule.
Describe each selected output row with the smallest complete packed-block
span covering its contraction interval: exact scalar spans for F32/F16/BF16;
256-element blocks for Q4_K/Q5_K/Q6_K, with explicit prefix/trailing elements.
Use the existing published packed-row layouts, not an outside model compiler.

Return owned relative/file span descriptors and, under a caller-supplied
aggregate host byte bound, copied source bytes only. Check selection, every
product/sum/row/tensor/file extent and source-owner lifetime before reading.
No opaque pointer may escape. Avoid allocating or decoding a whole model,
full contraction or entire tile list. Tests use independent byte-array/slice
oracles, multiple rows, partial blocks/tails, every loaded source kind, malformed
binding/changed schedule/closed owner/span/host-bound/overflow cases and returned
ownership. No model/layer/attention evaluation, outside compiler or device
open/upload is part of this source-storage slice.

This observes a live source mapping; it does not prove immutable source identity
against concurrent writers or reopen races. Packed copied bytes are not selected
Hailo weight packing, numerical instructions or a valid device program. Keep
actual conversion, precision, register/CCW encoding, physical placement and first
hardware arithmetic result explicit. Publish verification and continue these
actual backend gaps automatically toward broad ordinary-model support.
