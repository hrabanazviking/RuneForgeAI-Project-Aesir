# Original program delivery boundary

Date: 2026-10-20. Contract: `TASK_hailo10h_program_delivery.md`.

## Pinned license and source evidence

HailoRT revision `d503417f2a0db186a838390fb08690c4ea0f415e` uses the already-read
MIT license. Driver tag v5.3.0 resolves to
`45e5fc53c6922fd6985febfc09399653497a2082`. The installed package copyright,
GPL-2.0 file notices and root GPL-2.0 license were read before driver study.
Common `pcie_common.c` has its own MIT notice. This study records interface
facts only; no external implementation is copied/translated or linked.
Downloaded files stay outside Git. The evidence provenance lists file SHA-256
values and confirms all five studied driver source/header files are identical
to the installed sources. No inference about uninspected binaries is made.

## Caller → transport → receiver

| Path | Established receiver behavior | Consequence for Aesir |
|---|---|---|
| Pi PCIe driver, Hailo10H board classification | Common board mapping selects the discrete device type. PCIe ioctl dispatch admits the SoC ioctl family for that type and rejects the NNC family with EINVAL. | HAILO_FW_CONTROL is in the NNC family; the existence of its UAPI declaration does not make it usable on this path. No retry/write is needed to learn this from the matching sources. |
| SoC ioctl dispatch | Recognizes session connect, close and power-off; no raw configuration upload operation is present in that dispatcher. | Existing connect/DMA/RPC ownership is useful. Power-off is unrelated and remains excluded. |
| Host DeviceHrpcClient | Raw firmware interaction returns NOT_IMPLEMENTED. | Native create/identify/destroy success cannot admit action bytes or CCWs as raw firmware controls. |
| hRPC action 2, VDevice create-infer-model | Protobuf metadata declares virtual-device handle, compiled-program byte count and name. Server then reads exactly that separate buffer and calls local VDevice create-infer-model. | Candidate delivery interface for future Aesir-generated compiled programs. Metadata framing alone is not upload, acceptance or numerical execution. |
| hRPC action 4, create-configured-infer-model | Applies requested stream formats, batch/power/latency/cache settings and calls configure; returns configured handle and queue size. | Original program must also carry valid stream/network/architecture metadata. Configure is a separate lifecycle operation. |
| hRPC actions 10/11/12/5/3 | Activate/deactivate/shutdown/destroy-configured/destroy-infer-model operate on the respective server-owned handle. | Publish exact typed lifecycle codecs before any future physical use; ownership and safe lifecycle need a separate physical contract. |

The installed driver's terminology can be misleading: its host-facing
Hailo10H PCIe classification is discrete even though an application processor
and integrated neural-core driver run inside the accelerator. That inner
device environment is distinct from the Pi endpoint. This is a source-derived
explanation of the control boundary, not a new physical execution observation.

## Wire facts for the next original codec

All action numbers are pinned enum values, not guessed opcodes. Request status
is the already-observed 1; successful reply status is 0. Protobuf field 1 of
create-infer-model is a nested object handle, whose scalar id is nested field
1/u32. Field 2 is program byte count/u64; field 3 is UTF-8 name. Empty scalar
defaults are omitted according to proto3 while an explicitly supplied zero
handle retains nested-message presence. Program bytes follow separately, not
inside the 2048-byte protobuf body. Reply field 1 contains the infer-model
handle in the same nested form. Each handle-only lifecycle request has nested
field 1; its reply has no defined fields. Unknown valid protobuf fields may be
skipped, while wrong known wire types, duplicates, malformed lengths/varints,
correlation/status mismatch and the published all-ones invalid handle sentinel
must be rejected. A request codec needs an explicit host program-size bound;
that is neither physical memory discovery nor device compatibility admission.

## Compiled output and the remaining numerical gap

Public `hef.proto` describes network/stream/context metadata and configuration
actions. A CCW pointer action names offset/u64 (field 1), size/u32 (field 2),
configuration-channel index/u32 (field 3). An inline CCW action carries opaque
bytes (field 1) and channel index/u32 (field 2). These are container references,
not definitions of numerical CCW/register semantics. Public config buffers
still establish only the eight-byte header unit/zero NOP padding already
recorded in `HAILO10H_PUBLIC_CONTEXT_ACTIONS.md`. No arithmetic CCW bit layout,
register address, placed resource map or executable first operation was found
in these inspected declarations. This is a bounded search result, not proof
that such information cannot be discovered elsewhere.

Aesir may need to emit a compiled container accepted by this receiver. That
would be a compiler output format for owner-supplied source models; it cannot
justify a vendor-precompiled-only product. This study never opens a vendor
compiled model, extracts numerical programs, uploads bytes or invokes model
configuration/execution. No hardware state changes or device opens occur.

Next: original host-only metadata/lifecycle codec under
`TASK_hailo10h_program_rpc_codec.md`, independently checked against pinned public
schema/enum oracles. Then continue program structure/CCW generation, placement,
original buffer delivery, configuration and first numerical hardware proof.

Primary sources:
[matching driver dispatch](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/linux/pcie/src/fops.c),
[board classification](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/common/pcie_common.c),
[SoC operations](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/linux/pcie/src/soc.c),
[RPC schema](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/hrpc_protocol/rpc.proto),
[action enum](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/hrpc_protocol/serializer.hpp),
[server receivers](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/hailort_server/hailort_server.cpp),
[public program schema](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/hef.proto).
