# Grouped USERPTR transfer declaration boundary

Date:2026-10-23. Continued automatically after publishing owned payload staging.
Parent:`TASK_hailo10h_program_delivery.md`. Fixed broad owner scope remains
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

Driver revision`45e5fc53c6922fd6985febfc09399653497a2082` root GPL-2.0 license was
read before the probe. Its UAPI retains the exact SPDX expression
`(GPL-2.0 WITH Linux-syscall-note) AND MIT`;it is not relabelled MIT-only.
Fresh immutable URL bytes match the retained matching-v5.3 header. This study
uses declarations,not an external implementation. No vendor code is copied or
translated into production. The test-only original C++ probe includes that
header outside the production tree. Provenance/raw identities are under
`evidence/grouped-transfer-contract-2026-10-23/`.

## Independent public-header objects

Nine fresh probe calls check layout and complete one-through-eight-buffer
objects against independent Python struct packing on this64-bit little-endian
host. Final C++ build has no diagnostics. The initial missing-climits compile
refusal and exact input remain preserved;no failed binary was executed.

| Field/structure | Actual header object result |
|---|---|
| HAILO_MAX_BUFFERS_PER_SINGLE_TRANSFER |8 array entries |
| Transfer span |16 bytes:type/u32 at0,address-or-fd/uintptr at4,size/u32 at12 |
| Prepare structure |139 bytes:channel/u8 at0,descriptor handle/uintptr at1,count/u8 at9,span array at10,debug/bool at138 |
| Launch structure |141 bytes:prepare at0,engine/u8 at139,cyclic/bool at140 |
| USERPTR buffer type |0 |

Count2 independently represents one2068-byte synthetic metadata span and a
separate70-byte synthetic program span. Values are scalar intent only;no address
is dereferenced or mapped. The grouped array offers a concrete wire-format gap:
existing original `soc_transfer` emits only a single USERPTR entry. Remaining
slots and all tail flags are zero in the tested canonical host profile.

All nine traces show one executable launch and no observed Hailo open,network
connect or ioctl. Separate ELF dynamic/symbol tables are retained. No raw
transfer,descriptor allocation or hardware completion occurred. Array capacity
is not a model/resource budget or a claim that a device accepts arbitrary groups.
Matching source/header objects do not establish actual descriptor accounting,
in-flight ownership,cache synchronization,producer/receiver boundary equivalence,
total deadlines,late-error cleanup or a valid numerical program.

Next original implementation:`TASK_hailo10h_soc_group_codec.md`,under a published
pre-code contract. Actual684 Mojo/78 Python copies and134 existing controls are
frozen before production. Broad ordinary unmodified source support100%,numerical
configuration/packing/placement and original payload DMA/activation/results/cleanup
remain required work. No source-model execution or new production capability is
claimed by this qualification.

Primary source:
[matching public UAPI](https://github.com/hailo-ai/hailort-drivers/blob/45e5fc53c6922fd6985febfc09399653497a2082/common/hailo_ioctl_common.h).
