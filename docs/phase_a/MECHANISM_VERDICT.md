# Mechanism Verdict — H004

**Verdict: NO-GO** — neither VFIO nor uio_pci_generic is viable on Mimir's
running kernel. Routing: F2/F3 per the H004 acceptance criteria.

**Date:** 2026-10-10
**Evidence:** `data/phase_a/pcie_census/` (H003), kernel config source
`/boot/config-6.12.109+rpt-rpi-2712`, modinfo probes, device-node checks.

## VFIO — rejected as primary

Blocking facts (any one is sufficient; all three were measured):

1. `CONFIG_VFIO` is `# CONFIG_VFIO is not set` in the running kernel's config —
   VFIO is compiled out entirely, not even as a loadable module.
2. `/dev/vfio` does not exist, and `modinfo vfio-pci`, `modinfo vfio`,
   `modinfo vfio-pci-core` all return "Module not found".
3. Even if VFIO existed, DMA isolation would be unavailable:
   `CONFIG_ARM_SMMU` and `CONFIG_ARM_SMMU_V3` are both
   `# ... is not set`, and the Hailo PCI function (0001:01:00.0) appears in
   NO IOMMU group (`/sys/kernel/iommu_groups/` holds only platform devices).

## uio_pci_generic — rejected as fallback

Blocking facts:

1. `CONFIG_UIO_PCI_GENERIC` is `# CONFIG_UIO_PCI_GENERIC is not set` in the
   running kernel's config — compiled out entirely, not a module.
2. `modinfo uio_pci_generic` returns "Module not found". The only UIO modules
   present are `uio.ko.xz` and `uio_pdrv_genirq.ko.xz` (platform-device UIO —
   no PCI binding capability).
3. `/dev/uio*`: no nodes exist.

## Raw sysfs resource mapping — not selectable

Per the architecture, raw sysfs `resourceN` mapping is recon-only and is not
a selectable driver mechanism. (It remains usable for H003-style recon reads.)

## What the chosen mechanism would need (currently absent)

A future VFIO-based HAILBRÚ would need, all currently missing:

- Kernel built with `CONFIG_VFIO=y`, `CONFIG_VFIO_PCI=y`,
  `CONFIG_ARM_SMMU=y` (or V3) plus device-tree SMMU enablement for the PCIe
  root complex, so the Hailo function lands in an IOMMU group.
- `/dev/vfio/vfio` (crw, root:root 0600 by default) and
  `/dev/vfio/<group>` (group-accessible to the runtime user) device nodes.
- The `hailo1x_pci` vendor driver unbound from 0001:01:00.0 (mutual exclusion
  with vfio-pci), with `driver_override` used to bind `vfio-pci`.

A future uio_pci_generic fallback would need `CONFIG_UIO_PCI_GENERIC=m`,
the module loaded, and `/dev/uioN` nodes with runtime-user access.

**Remediation is an operator action** (documented here, not executed):
rebuilding the Raspberry Pi kernel with the flags above. H012/H013 reference
this record.

## Context (not a selectable mechanism)

The vendor kernel driver `hailo1x_pci` v5.3.0 IS bound to 0001:01:00.0
(hailort-drivers family), but created no `/dev/hailo*` node. Per L6 the
vendor driver is an OS-side user prerequisite Aesir never requires, so its
presence does not change this verdict.

## Consequence

Phase B (HAILBRÚ userspace driver) cannot execute on this kernel. The
campaign records this as the H004 NO-GO and routes driver ambitions to
F2 (partial acceleration of whatever documented interfaces yield) /
F3 (driver + protocol docs banked as durable deliverables). Phase-A recon,
the clean-room studies, and all D1 ARMVEGR CPU work are unaffected and
proceed. H010's gate review reconciles this verdict with the Phase-A go gate.
