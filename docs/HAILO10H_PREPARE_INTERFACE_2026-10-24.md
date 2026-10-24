# Distinct prepare and cancellation request byte boundaries

Date:2026-10-24. Consumer:original grouped transport under
`TASK_hailo10h_program_delivery.md`. Broad ordinary unmodified source-model
support100% remains fixed;all LLM execution stays Hailo-10H.

Fresh exact-revision GPL-2.0 root license bytes were read before UAPI inspection.
Driver revision:`45e5fc53c6922fd6985febfc09399653497a2082`.
The public UAPI retains `(GPL-2.0 WITH Linux-syscall-note) AND MIT`.
Fresh header/license bytes match the previous matching-v5.3 qualified copies.
No driver implementation body or descriptor algorithm is adopted or translated.

Seventeen independent test-only public-header probes qualify these complete
LP64 little-endian objects against Python struct packing:

| Object | Qualified fields |
|---|---|
| Prepare |139 bytes;channel/u8 at0,descriptor/uintptr at1,count/u8 at9,eight16-byte spans at10,debug/bool at138 |
| Cancellation |8 bytes;descriptor/uintptr at0 |
| Prepare ioctl |read-direction,magic118,number13,size139 |
| Cancellation ioctl |read-direction,magic118,number14,size8 |

Each span retains type/u32 at0,address-or-fd/uintptr at4,size/u32 at12.
The existing canonical Aesir profile uses USERPTR0,debug false and zero unused
slots. Prepare has neither the launch engine byte nor its cyclic byte. The
cancellation handle happens to have the same scalar width as descriptor release;
the operation numbers/purpose are distinct. No request is sent by these probes.

The HailoRT declaration already qualified in
`HAILO10H_GROUPED_PHYSICAL_BOUNDARY_2026-10-23.md` returns hailo_status for
preparation. That declaration does not return a descriptor count. This study
qualifies bytes only;it does not infer a capacity formula,cancellation of active
DMA,actual preparation side effects or safe live ordering. Mapping compatibility
from517d0aa supplies none of those missing facts. Numerical configuration,
packing/placement and original valid program execution remain required.

The first probe runner copied its executable without its execution mode;the
resulting exec permission refusal and exact inputs remain. The corrected copy
preserves mode. All17 final probes and two ELF tables pass;traces show no device
open,ioctl,network or inference runtime. Actual705 Mojo/86 Python copies and156
current qualified controls are frozen before the next native code.

Next original host-only contract:`TASK_hailo10h_soc_prepare_codec.md`. Reuse the
one existing group validator/codec;do not duplicate its slot rules or turn scalar
values into mapping/submission credentials. No new production capability or
source-model execution is claimed by this pre-code interface qualification.

Immutable evidence:`evidence/soc-prepare-contract-2026-10-24/` pins868 raw paths,
including the failed probe. Manifest SHA256:
`e23ddde53977dbf23a0208857457d5ffdf49c026d360cdab02b26af398f1dcac`.
Primary [UAPI declaration](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/common/hailo_ioctl_common.h).
No DFC,outside model compiler/machine,precompiled prerequisite or host/CUDA/cloud
inference/proxy. Missing formats,architectures,operations and numerical/physical
interfaces remain required work toward the same broad target.
