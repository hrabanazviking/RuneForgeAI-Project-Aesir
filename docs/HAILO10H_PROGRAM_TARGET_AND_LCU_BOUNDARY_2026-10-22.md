# Program target identity and LCU control boundary

Date:2026-10-22. Contract:TASK_hailo10h_numerical_encoding_sources.md.
Fixed owner scope:HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md. This bounded
primary-interface study establishes target/control fields. It establishes no
numerical instruction, placement, hardware acceptance or source-model execution.

## License, pin and scope

Read the MIT root license before bodies and checked per-file notices where
present. Nine source/license files at public HailoRT v5.3.0 revision
`d503417f2a0db186a838390fb08690c4ea0f415e` were fetched from their immutable URLs
and matched byte-for-byte against the retained source archive. Source bodies
remain outside production. Evidence:program-target-lcu-boundary-2026-10-22 under
docs/evidence. Original audit checks declarations; it does not execute, copy or
translate the vendor implementation. No compiler/model/device was invoked.

## Target namespace and layout selection

| Qualified public fact | Consequence for Aesir's original program writer |
|---|---|
| Program header field1 uses ProtoHEFHwArch; HAILO1XH=103. Old HAILO10H=5 is commented as deprecated in both program enum declarations. | Future program metadata must use an explicitly qualified program target namespace. A runtime architecture value cannot be copied into this field. |
| Runtime device enum HAILO_ARCH_HAILO10H has value6. The host's compatibility mapping includes Hailo-10H for program HAILO1XH/GINGER/LAVENDER and for HAILO15M. | A compatible family label is a metadata predicate. It does not establish that an arbitrary program executes or that every member shares register maps. |
| Partial physical layout carries a uint32 bitmap in field1. The multi-layout branch is selected for program HAILO8L/HAILO15M. | Retain target/version/layout provenance independently of inferred memory fit. |
| Partial-core selection has a HAILO15M-on-HAILO15H bypass; that conditional has no Hailo-10H bypass. | The family compatibility list cannot justify picking an arbitrary partial layout on Hailo-10H. Actual matching and placement still need qualification. |

These program-side facts refine the earlier integrated-NNC study. That driver's
profile table still does not qualify a callable Pi NNC interface or actual H10H
register configuration. No alternate board profile is adopted.

The inspected runtime memory calculator uses metadata and descriptor assumptions;
its outputs are allocation estimates, not discovered arithmetic resources, physical
placement or a proof that an unmodified source model fits the accelerator.

Primary sources:
[program schema](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/hef.proto),
[runtime enum](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/include/hailo/hailort.h),
[compatibility predicate](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/src/device_common/device_internal.cpp),
[layout selection](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/src/hef/hef.cpp).

## Concrete next original control serialization

The public packed context interface establishes three additional LCU records:
nondefault enable ID4 has packed-LCU u8,network u8,completion-address u16 and
completion-count u32; disable ID5 has packed-LCU u8; batch switch ID36 has
packed-LCU u8,network u8 and completion-count u32. Their existing common header
is action u8 plus timestamp u32. Thus complete extents are13,6,11 bytes.
Packed LCU uses four low bits for unit and three for cluster, leaving bit7
reserved. These widths do not establish actual resource counts or safe values.
[Public definitions](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/common/include/context_switch_defs.h).

An original isolated codec can now cover these missing control records under
TASK_hailo10h_lcu_action_codec.md. Explicit completion values remain caller
intent; no physical LCU address or instruction is generated from a source op.
The existing four-action codec and its accepted/refused behavior stay frozen.
No callable raw-context hRPC endpoint, complete numerical CCW, resource placement,
program activation or result/cleanup proof follows from these records.

Continue original Mojo serialization plus numerical/configuration research.
Broad ordinary unmodified source-model support stays100% the target. No DFC,
outside compiler/machine, precompiled prerequisite, inference proxy or host LLM
forward is introduced. No new capability ID or native execution claim is added.
