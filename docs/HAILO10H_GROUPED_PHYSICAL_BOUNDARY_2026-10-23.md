# Grouped physical transfer interface frontier

Date:2026-10-23. Continued automatically after publishing the original grouped
value codec at`f77ecbeed30e7703432f89270609fec60c6d8e68`. Parent:
`TASK_hailo10h_program_delivery.md`. Fixed owner scope remains
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

The exact matching HailoRT revision remains
`d503417f2a0db186a838390fb08690c4ea0f415e`. Its full MIT license was read before
source inspection. Fresh license bytes match the retained licensed copy;five
additional public headers retain their MIT notices. Only declarations/interface
constraints inform this report;no external algorithm is adopted or translated.

The public [channel declaration](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/src/vdma/channel/boundary_channel.hpp)
separates launch,completion,prepare and cancellation. Cancellation of pending
work requires deactivation. Its size-based readiness/ongoing-transfer helpers
carry an explicit warning that size does not correctly account for descriptors.
They cannot qualify an original grouped capacity rule.

The [descriptor-list interface](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/src/vdma/memory/descriptor_list.hpp)
separates descriptor count,page size,handle,buffer offset and transfer extent.
The [chunk declarations](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/src/vdma/channel/transfer_splitter.hpp)
carry descriptor counts and first/last boundaries separately from grouped buffer
values. Their policy comments are not an H10H transfer qualification or authority
to borrow a splitting algorithm.

The [transfer values](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/src/vdma/transfer_common.hpp)
distinguish base storage,offset,extent and callback lifetime. The
[driver interface](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/src/vdma/driver/hailort_driver.hpp)
accepts grouped values but does not establish this Pi's descriptor result,
pinning/cache behavior or late-failure cleanup from a declaration alone.

Original Aesir code still fixes RPC storage and descriptor counting to2068 bytes.
The new141-byte codec owns scalar intent only. No formula based on total bytes,
number of buffers or eight-slot UAPI capacity is promoted into physical proof.
No arbitrary chunk/split transaction or live action2 was submitted. Kernel-sealed
program storage is a concrete independent gap that can be implemented next using
already qualified original host interfaces. Its sealing will not prove USERPTR
pin compatibility or grouped DMA safety.

Next native contract:`TASK_hailo10h_sealed_program_payload.md`. Actual687 Mojo/
79 Python inputs and137 retained controls are frozen for that contract. Raw
license/header retrievals and copies:
`evidence/grouped-physical-interface-2026-10-23/`. No new native experiment,
production capability,numerical configuration or source-model execution is
claimed. The fixed broad ordinary UNMODIFIED model target100%,actual numerical
precision/packing/placement and original upload/activation/results/cleanup remain
required work. Hailo-10H owns all eventual LLM execution;DFC,outside compilers,
external compilation machines,precompiled prerequisites and inference proxies
remain excluded.
