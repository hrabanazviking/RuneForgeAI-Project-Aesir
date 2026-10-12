# Hailo-10H PCIe, IOMMU, UIO, and VFIO status

**Roadmap Slice 017 — complete (read-only observation, 2026-10-12)**

## Observed endpoint state

- Hailo endpoint `0001:01:00.0` remains bound to `hailo1x`.
- `/sys/bus/pci/devices/0001:01:00.0/iommu_group` is absent; no IOMMU group is associated with the device in the current view.
- `/dev/vfio/vfio` exists, but the absence of a Hailo IOMMU group means this observation does not establish a usable VFIO device/group path.
- The endpoint-specific character device observed is `/dev/h1x-0`; `/dev/hailo0` is absent. HailoRT identifies the device through the bound driver.
- `uio_pci_generic.ko.xz` is present for the running kernel. The module was not loaded or bound during this read-only check; loaded modules included `uio` and `uio_pdrv_genirq`.
- The Hailo module is owned by `hailo1x`; no driver bind/unbind, BAR mapping, interrupt probe, DMA operation, or reset was performed.

## Meaning and limits

VFIO support files alone are insufficient evidence of direct device access. UIO module availability is not proof that this endpoint can be safely bound, that interrupts work, or that DMA is safe. The existing Hailo character device and vendor-managed stack are observations, not approval for Æsir to depend on HailoRT. No userspace mechanism is approved by this slice.

## Slice 017 acceptance

- IOMMU-group absence is distinguished from VFIO character-device presence.
- UIO module presence is distinguished from successful binding or usable DMA/interrupt behavior.
- Current Hailo driver ownership and device nodes are recorded.
- No device mutation or inference workload occurred.
