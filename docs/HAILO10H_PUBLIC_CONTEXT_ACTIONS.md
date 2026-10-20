# Public configuration-action boundary

Date: 2026-10-19. Study before original codec implementation.
Pinned HailoRT: `d503417f2a0db186a838390fb08690c4ea0f415e` (v5.3.0).

## License and sources

Re-read `hailort/LICENSE`: MIT, copyright Hailo Technologies 2019–2026;
SHA-256 `b7f9de8a9180e5e47f14a34c8291778bd543e144afbf21ddfd191e0b057da4d7`.
Source study extracts interface facts only; no implementation is copied,
translated or vendored. Downloaded study files stay outside the Git tree.

| Public source | SHA-256 |
|---|---|
| `common/include/context_switch_defs.h` | `fa8fa9f979e58285ad52ba6287a613e61324f297a3f283306acdc217cd46568b` |
| `common/include/control_protocol.h` | `a10865db05e18eb14891b4f68d11cee2934c54695e9263d802f4e75df14a2445` |
| `hailort/libhailort/src/core_op/resource_manager/action_list_buffer_builder/action_list_buffer_builder.hpp` | `531e2b1ff21d7fba2179778b4ee34c8c97913ca33d01250d0b429f92d7f14154` |
| Same directory, `action_list_buffer_builder.cpp` | `c444c6c234f130ca9fa08617a38e3127a7effb40fb7057ac5f958bfb6f2da279` |
| `hailort/libhailort/src/core_op/resource_manager/config_buffer.hpp` | `4ca79a5cdbcf9252538b306fd27d0b4b63d373eb5257777768aa1124f4358afc` |
| Same directory, `config_buffer.cpp` | `1a0f541998b575f625521fcea7f94bb4af7e95585ff5b44d27f081c86b13173d` |
| `hailort/libhailort/src/core_op/resource_manager/resource_manager.cpp` | `35228993f4f6a36a9990b278b6b7beded4873cc46d42de9bab8842d8e23ee618` |
| `hailort/libhailort/src/device/device_hrpc_client.hpp` | `995eecac503dd626cac912b9a00e0d3c8148d70fc3e6a6c0816f1638b8a1ab48` |
| `hailort/libhailort/src/vdma/integrated/integrated_device.hpp` | `767295deec0dbd8a5b2bf1ed0595428d4dc08f045d333c21453776609d867c78` |

## Distinct interfaces

The public context action definition is packed: a one-byte action ID followed
by a four-byte timestamp. The timestamp initializer is all ones. The candidate
subset is descriptor fetch (ID 0, u16 count + packed channel), default LCU enable
(ID 3, packed LCU + network byte), CCW-burst fetch (ID 27, u16 bursts + stream
byte), and typed data write (ID 35, address u32, type byte, data u32, shift byte,
mask u32, network byte). Channel packing assigns six low bits to channel and
two high bits to engine; LCU packing uses four low bits for LCU and three bits
for cluster. These are field widths, not this machine's physical resource
counts. Typed writes distinguish general and batch types. No register meaning
or safe address follows from that definition. Packed layout and enum values
still need the independent header oracle required by the contract.

Control protocol definitions separately name preliminary/dynamic/batch-switch/
activation contexts and first/last chunk markers plus type, length and data.
Action-list construction separates context boundaries from control chunking;
resource management passes those controls through the local VDMA device path.
A context byte buffer therefore is not automatically a host hRPC request.

Config buffers carry CCW data separately from the actions. Public buffer facts
include an eight-byte CCW header and all-zero eight-byte padding NOP. The
configuration words for a numerical operation, valid compute addresses and
register meanings remain unresolved. Padding alone cannot compute anything.

The pinned host DeviceHrpcClient class explicitly lacks raw firmware-control
implementation. Its success at create/identify/destroy does not establish a
raw-context upload endpoint. The local integrated VDMA path runs in a different
device environment; its existence does not establish access from the Pi. The
known infer-model hRPC interface expects compiled-container data, not arbitrary
action bytes. Do not send a context on a guessed action ID.

## Next experiments

Implement/verify the bounded host action codec under
`TASK_hailo10h_context_actions.md`. In parallel with subsequent compiler work,
continue public-interface/driver/server study to establish the actual
configuration upload/activation path, CCW operation/register encodings and
hardware placement. No arbitrary write, reset, model/container extraction or
inference is part of this study. The source-model target is unchanged.

Primary source links:
[context definitions](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/common/include/context_switch_defs.h),
[control definitions](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/common/include/control_protocol.h),
[config buffer](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/src/core_op/resource_manager/config_buffer.cpp),
[host hRPC class](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/src/device/device_hrpc_client.hpp).

## Continued pinned server boundary study

`hailort/hailort_server/hailort_server.cpp` SHA-256
`80b8c3c66b976f1cd2f62f52b0b23b8c996d1d3d58241619848b1023ee660668`
was studied under the same already-read MIT license. The registered generic
infer-model creation handler reads the declared compiled-container bytes
separately, then passes that buffer to the local VDevice infer-model API.
Its dispatcher provides model configure/activate/run lifecycles, not a
documented arbitrary action-list upload RPC. This reinforces the separation
between a reachable control channel and a usable original compute-program
endpoint. No server implementation is copied, translated, run or installed.
Actual program/CCW construction and endpoint work remain open; this observation
does not restrict the owner goal to vendor-precompiled models.
