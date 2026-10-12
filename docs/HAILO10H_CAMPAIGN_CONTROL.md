## Slice 114 — Assess Hailo memory-layout evidence (complete; no Æsir contract established)

Public evidence reviewed for this slice documents Hailo driver DMA buffer mechanisms and hardware-side support code, and Raspberry Pi documents AI HAT+ 2 as Hailo-10H with 8 GB onboard memory. This evidence is not a complete public specification for the tensor layout, addressability, cache-coherency, or model-layer memory behavior needed by Æsir. The public driver source is tied to the vendor runtime/driver stack and cannot be treated as authorization or a compliant implementation contract for this campaign. Do not infer that 8 GB is all freely addressable to arbitrary Mojo buffers or that a particular tensor packing is accepted.

Result: Æsir’s Hailo memory-layout requirements remain UNKNOWN pending a public, legally usable specification and a proven transport/configuration path. No hardware was accessed or changed.

Sources: https://www.raspberrypi.com/documentation/accessories/ai-hat-plus.html ; https://github.com/hailo-ai/hailort-drivers/blob/master/common/pcie_common.h ; https://github.com/hailo-ai/hailort-drivers/blob/master/linux/vdma/ioctl.c ; docs/HAILO10H_ACCESS_MECHANISMS.md.
