# Separate program payload framing and staging boundary

Date:2026-10-23. Contract:`TASK_hailo10h_program_delivery.md`. Fixed owner scope:
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

Actual MIT license preceded source bodies. Twelve freshly retrieved public files
at HailoRT revision`d503417f2a0db186a838390fb08690c4ea0f415e` match retained bytes,
including per-file notices where present. Actual681 Mojo/77 Python copies and128
native controls are frozen under`evidence/program-payload-contract-2026-10-23/`.
Interface/call-boundary facts only; no external implementation copied,translated,
compiled or linked.

| Caller → receiver | Qualified consequence |
|---|---|
| Create-infer-model serializes actual input size and supplies that buffer separately. | Metadata count must agree with retained actual bytes. |
| Request client supplies metadata buffer followed by additional buffers in one ordered request. | Preserve the boundary/order; no second hRPC header or invented length prefix on program bytes. |
| RPC allocator/reader uses20 header+2048 body bytes; header.size gives meaningful body length. | First segment2068 bytes. Zero unused bytes is our canonical output policy, not an extra receiver requirement. |
| Server action2 reads exactly the declared separate buffer before creating infer-model and replying. | Metadata-only exchange cannot complete this lifecycle; program storage must survive transfer. |
| Raw PCIe passes the grouped buffers to its boundary channel. | Arbitrary chunking or equivalence of separate transfer requests is not qualified. |

The PCIe header's generic alignment/size comments are not H10H bulk admission:
actual RPC2068 is not a multiple of eight. Driver descriptor limits,matching
producer/consumer transfer patterns,in-flight ownership,total deadlines and late
failure cleanup require their own qualification. No model budget or transfer
limit is inferred from a comment. Existing SocRpcClient exchanges one fixed RPC
buffer and lacks the action2 payload phase; do not submit isolated action2 via
that path or treat staging as a transport consumer.

Next:`TASK_hailo10h_program_payload_staging.md`. Own a copied original v3 outer
envelope beside exact existing action2 metadata; validate actual size,existing
full-residue integrity and explicit request intent before window reads. This is
owned byte preparation,not immutable executable-artifact identity or device
delivery. Checksums do not validate numerical instructions,protobuf semantics,
target,placement or hardware admission. No arbitrary model/vendor container is
opened. Numerical configuration/packing/placement,original payload DMA,handle
ownership/activation/results/cleanup and broad unmodified source-model execution
remain required. No hardware request,model forward,DFC,outside compiler/machine
or precompiled-model prerequisite is introduced.

Primary sources:
[caller](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/src/vdevice/vdevice_hrpc_client.cpp),
[ordered buffers](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/hrpc/client.cpp),
[message/buffer declarations](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/hrpc/rpc_connection.hpp),
[message extents](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/hrpc/rpc_connection.cpp),
[receiver](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/hailort_server/hailort_server.cpp),
[PCIe interface](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/src/vdma/pcie_session.hpp).
