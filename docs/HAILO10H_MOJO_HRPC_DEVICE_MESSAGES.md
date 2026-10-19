# Mojo typed device control messages

Completed 2026-10-19 under `TASK_hailo10h_soc_session.md`. The source-model /
Mojo target is unchanged. This is one independently verifiable part of the
integrated-device transport, before a live driver-backed session.

`hailbru/hrpc_device.mojo` constructs the pinned device create/identify/destroy
requests and checks their correlated replies. A bounded independently written
proto3 reader extracts handle and numeric identity fields without importing a
protobuf runtime. The native consumer `smidr/tools/hrpc_device.mojo` constructs
and inspects wire messages; it performs no device access or LLM inference.

## Verification

```sh
mojo build -I . smidr/tools/hrpc_device.mojo -o work/hrpc-device
python3 tests/test_hailo_hrpc_device.py --binary work/hrpc-device -v
```

The native build passes on the installed Mojo 1.1.0 environment. Ten test
methods pass against independently generated messages from the installed
test-only `google.protobuf` 6.33.6 runtime. The test defines the published
schema independently; no production Python or protobuf dependency is added.

Coverage includes complete request bytes, UInt32 boundaries, valid zero-handle
message presence, populated and absent firmware submessages, unfamiliar
architecture values, unknown-field skipping, reply ID/action mismatch, remote
failure before body interpretation, truncated/overflowed varints and lengths,
duplicate recognized singular fields, malformed nested messages and CLI bounds.
An empty identity remains architecture/protocol zero with firmware absent;
it is never promoted to Hailo-10H identity.

The action IDs and field contracts were checked against the pinned official
v5.3.0 `serializer.hpp` enum and `rpc.proto` at
`d503417f2a0db186a838390fb08690c4ea0f415e`. Only protocol facts were used;
vendor implementation code was not copied or translated.

## Session ownership finding and next acceptance

Pinned `pcie_session.cpp` allocates separate input/output descriptor lists,
requests assigned channel IDs through `soc_connect`, creates the channel /
interrupt owners, then activates transfers. Its close order stops new owned
host activity, closes/aborts the assigned connection, and only then cancels
pending transfer storage. That ordering matters: buffers must not be released
while DMA can still own them.

Next work is the exact running driver ABI and an owned Mojo session with
bounded completion and cleanup. The message tests establish wire behavior;
an actual device round-trip and executable source-model program remain
separate required gates. No precompiled-model work is part of this slice.

[Receipt and hashes](evidence/mojo-hrpc-device-2026-10-19/receipt.json) /
[raw passing test output](evidence/mojo-hrpc-device-2026-10-19/tests.txt).
