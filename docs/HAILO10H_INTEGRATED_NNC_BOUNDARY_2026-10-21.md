# Public integrated NNC interface qualification

Date:2026-10-21. Parent TASK_hailo10h_numerical_encoding_sources.md. Fixed scope:
HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md. This is licensed public-interface research,
with no new native encoder, hardware access or numerical-execution claim.

## Pins and license-first boundary

The public organization/repository/path census located the integrated NNC platform
interfaces in hailo-ai/hailort-drivers. Current-tree metadata pin is
309eb102af12a7986a8d635723b52d33c96bf7b3; the actual seven-file body/interface
study uses the matching installed-v5.3 driver source pin
45e5fc53c6922fd6985febfc09399653497a2082. The root GPL-2.0 license and per-file
GPL-2.0 notices were read before bodies. Root license SHA256:
f9c375a1be4a41f7b70301dd83c91cb89e41567478859b77eef375a52d782505.
Source bodies stay outside Git with exact identities; no external implementation
is copied/translated into Aesir or linked as a new dependency.

A separate Linux path-only census at2e58815fd413114c0aba5e045ead528c374dbd74
has a truncated74221-entry root tree and an untruncated32089-entry driver subtree.
That metadata census is not an exhaustive instruction-source search or proof
that public numerical specifications do not exist. Its GPL-2.0/syscall license
notices were reviewed; no Linux implementation bodies were needed for that census.

## Qualified receiver and profile facts

| Inspected interface | Established boundary | Aesir consequence |
|---|---|---|
| [Platform dispatcher and action-list receiver](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/linux/integrated_nnc/src/file_operations.c) | This integrated driver admits firmware controls and an action-list write request. Supplied bytes are copied into per-file-offset shared memory; a DMA address is returned. | This maps a receiver/storage mechanism. It does not define arithmetic instruction payloads or establish an accessible Pi ioctl route. |
| [Board profiles](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/linux/integrated_nnc/src/main.c) | The inspected table selects H15H, H15L and H12L profiles. A source-channel-mask symbol containing H10H is reused by the two H15 entries. | A symbol name cannot qualify H10H descriptor formats or justify adopting another profile. Exact H10H target compatibility remains open. |
| [DMA declarations](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/linux/integrated_nnc/src/dram_vdma.h) | Address/descriptor-kind/channel/interrupt masks are declared. The channel-address mask literal0x7ffff0000 covers bits16..34 while its comment says17:34. | Retain both observations. Caller alignment, reserved-bit behavior, actual H10H packing and a usable transport still require independent qualification; no writable-bit assumption is made. |
| [Firmware mailbox transport](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/linux/integrated_nnc/src/fw_control.c) | Control framing uses shared-memory buffers, checksum/length data, a mailbox, completion/timeout handling and bounded reply length. | This is a control transport boundary, with no arithmetic CCW/register map established in the inspected interfaces. |

The matching Pi PCIe endpoint still rejects the NNC ioctl family, as recorded in
HAILO10H_PROGRAM_DELIVERY_BOUNDARY.md. A different platform driver's receiver does
not overturn that result. Native hRPC create/identify/destroy and host program/
configure codecs remain useful independent components; original program upload,
activation/result/cleanup and actual numerical configuration remain unverified.
No firmware was downloaded or changed, no reset/rebind/kernel change occurred,
and no device was opened by this research. No unsupported request was retried.

## Required next concrete evidence

Find an actual compatible H10H profile and explicit numerical register/CCW/
placement fields, or a documented original-program receiver that establishes
those fields and lifecycle. Preserve target/version distinctions, source-provided
opaque program bytes and missing arithmetic definitions. Publish a bounded
original contract and independent host oracle before implementing a newly
qualified serializer; physical use needs its own valid original program and
activation/result/cleanup proof. Do not invent instructions or port a driver
implementation. No DFC, outside compiler/machine, specially compiled model or
inference proxy is required or introduced. Broad ordinary-model support remains
the target, and only Hailo-10H may perform LLM execution.

The receipt under docs/evidence/integrated-nnc-boundary-2026-10-21 retains source/
license/tree/census identities and original audit rules. No new capability ID or
numerical encoding field is claimed. Continue original compiler implementation
and bounded public-interface research automatically.

Local consistency remains failing:baseline23254/current23292;
all38 added diagnostics are retained research-receipt paths, with no
new nonreceipt issue after Markdown line normalization. No native code changed;
accepted161-method/6387-call/64-build compiler evidence and113/158 ledger census
remain unchanged. No whole-repository or hosted-CI pass is claimed.
