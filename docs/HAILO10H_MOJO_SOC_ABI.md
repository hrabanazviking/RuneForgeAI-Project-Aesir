# Mojo packed PCIe session ABI

Completed 2026-10-19 under `TASK_hailo10h_soc_session.md`. This advances the
fixed Mojo source-model target through its device transport dependency.

`hailbru/soc_abi.mojo` independently encodes the Linux LP64 little-endian
5.3.0 session UAPI into owned byte lists. It never relies on native struct
padding and performs no device access. Its native consumer is
`smidr/tools/soc_abi.mojo`. The installed header uses one-byte packing:
descriptor creation is 27 bytes (handle at offset 11), connection is 20 bytes
(handles at offsets 4 and 12), and transfer submission is 141 bytes (descriptor
handle at offset 1). Several fields are deliberately unaligned.

The admitted subset covers driver/properties queries, descriptor creation /
release, connect/close, channel masks, single user-pointer transfer submission,
and interrupt response inspection. It does not expose power-off, reset, raw
mailbox or arbitrary request codes. Output channels initialize to the invalid
sentinel before connect. Zero descriptor handles remain valid; only the UAPI's
all-ones handle sentinel rejects. Unknown numeric board/DMA/version values are
preserved. Interrupt error/inactive bytes 254/255 remain statuses, not counts.

## Independent verification

```sh
g++ -std=c++17 -Wall -Wextra -Werror -I "$HAILO_DRIVER_UAPI" \
  tests/hailo_soc_abi_oracle.cpp -o work/soc-abi-oracle
mojo build -I . smidr/tools/soc_abi.mojo -o work/soc-abi
python3 tests/test_hailo_soc_abi.py --binary work/soc-abi \
  --oracle work/soc-abi-oracle -v
```

`HAILO_DRIVER_UAPI` selects the operator's installed common-header directory.
The test-only C++ oracle includes that header, checks LP64/enum widths and
prints actual `sizeof`, `offsetof`, ioctl values and complete C object bytes.
It does not reproduce vendor declarations, call ioctl or open a device.
Production Mojo imports no C++ shim or vendor library.

Native build and all nine methods pass on this Pi. Twelve request codes and
84 complete request buffers match the C oracle. Seeded connection/channel
vectors, UInt64 handles/pointers, zero handles, maximum descriptor sizes,
reply offsets, unfamiliar enum values, all 120 interrupt slots, error statuses,
duplicates, truncation, excess bytes and invalid arguments are checked.
The installed common-header SHA-256 is
`a2731314f4676cb140b970043d53cc06d57da90ea46344ccd44a3c491aede26b`.

## Ownership boundary and next work

ABI encoding cannot establish descriptor or channel ownership, device identity,
pointer allocation, DMA alignment, cache coherence, buffer lifetime, transfer
completion or cleanup. Those belong to the session owner. This slice does not
claim a physical connection or an executed source model. Next is an owned
driver query and descriptor/connection lifecycle, followed by bounded physical
RPC completion and cleanup under the existing contract.

[Raw tests](evidence/mojo-soc-abi-2026-10-19/tests.txt),
[installed layout](evidence/mojo-soc-abi-2026-10-19/layout.json) and
[receipt](evidence/mojo-soc-abi-2026-10-19/receipt.json).
