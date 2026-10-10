# PCIe census notes — Mimir (2026-10-10)

Collected via `device.invoke` system.run on purpleviking1 (homelink-c2ba12).
Device probed: Hailo-10 at 0001:01:00.0.

## Identity (read from sysfs — not from memory or the internet)
- vendor: 0x1e60 (Hailo Technologies Ltd.)
- device: 0x45c4, rev 01
- class: 0x0b4000 (Co-processor)
- subsystem vendor/device: 0x1e60 / 0x45c4
- modalias: pci:v00001E60d000045C4sv00001E60sd000045C4bc0Bsc40i00
- Matches the prior assumption (1e60:45c4) — no difference flagged.

## BARs (from sysfs `resource`, flags 0x14220c = 64-bit prefetchable MMIO)
- BAR0: 0x1800000000-0x1800003fff — 16 KiB
- BAR2: 0x1800008000-0x1800008fff — 4 KiB
- BAR4: 0x1800004000-0x1800007fff — 16 KiB
- sysfs exposes mmap-able `resource0`, `resource2`, `resource4` files plus `_wc`
  (write-combining) variants; all are root-owned rw (`-rw-------`).

## Link
- current: 8.0 GT/s (Gen3) x1; max: 8.0 GT/s x4
- enable: 1; numa_node: -1; reset_method: "flr bus" (FLR available)

## Interrupts
- Legacy INTx: pin A routed to IRQ 37
- msi_bus: 1 (MSI-capable bus); `msi_irqs/` directory exists but is EMPTY —
  no MSI vectors currently allocated to this device.

## DMA
- dma_mask_bits: 64; consistent_dma_mask_bits: 64

## Driver state
- Bound driver: `hailo1x` (kernel module `hailo1x_pci`, version 5.3.0)
- Driver private sysfs dir `hailo1x/` exists under the device, containing `h1x-0`.
- /dev/hailo* : NO device nodes exist despite the driver being bound.
  The hailo1x_pci module probed and bound the PCI function, but no char device
  node was created (bring-up/firmware state unknown — see H014/H081+).

## Kernel config (source: /boot/config-6.12.109+rpt-rpi-2712)
- CONFIG_VFIO: "# CONFIG_VFIO is not set" (absent, not a module)
- CONFIG_VFIO_PCI / CONFIG_VFIO_PCI_CORE: absent (no matching config lines)
- CONFIG_UIO_PCI_GENERIC: "# CONFIG_UIO_PCI_GENERIC is not set" (absent)
- CONFIG_UIO=m (base UIO present as module; uio.ko.xz and uio_pdrv_genirq.ko.xz
  exist in /lib/modules — platform UIO only, no PCI variant)
- CONFIG_IOMMU_SUPPORT=y, but CONFIG_ARM_SMMU and CONFIG_ARM_SMMU_V3 are
  "# ... is not set" (no SMMU driver).
- /sys/kernel/iommu_groups/ contains groups 0, 1, 2 — only platform devices
  (codec, pisp_be, hvs, gpu); the Hailo PCI function is in NO IOMMU group.
- modinfo vfio-pci / uio_pci_generic / vfio: all "Module not found".
- /dev/vfio: does not exist. /dev/uio*: none.

## Topology (lspci -t)
- 0001:00 root port -> 0001:01:00.0 (Hailo-10)
- 0002:00 root port -> 0002:01:00.0 (RP1 south bridge, Ethernet controller)
