# DMA Coherence Model Study (H018)

**Date:** 2026-10-10, measured on Mimir (Raspberry Pi 5, BCM2712, 4× Cortex-A76)

## Platform facts (measured)

- **IOMMU: none.** `/sys/bus/pci/devices/0001:01:00.0/iommu_group` does not
  exist; kernel has `CONFIG_ARM_SMMU`/`CONFIG_ARM_SMMU_V3` not set (H003).
  There is no translation layer between device DMA addresses and physical
  addresses — the device sees physical addresses directly.
- **DMA mask:** `/sys/bus/pci/devices/0001:01:00.0/dma_mask_bits` = **64**.
  The device can address the full 64-bit physical space; no 32-bit bounce
  window needed. (No `coherent_dma_mask_bits` node exposed; the 64-bit mask
  governs.)
- **CMA:** `/proc/meminfo` → `CmaTotal: 65536 kB`, `CmaFree: 48064 kB`.
  64 MB of contiguous-memory-allocator carveout exists for coherent DMA
  allocations by kernel drivers.
- **Cache line:** 64 bytes
  (`/sys/devices/system/cpu/cpu0/cache/index0/coherency_line_size`).
- **No swiotlb activity** in dmesg — no bounce buffering is currently in play.
- **CPU caches:** Cortex-A76 with 64 KiB L1d/L1i per core (256 KiB total
  across 4), 512 KiB L2 per core (2 MiB total), 2 MiB shared L3.

## Per-mechanism: how a userspace buffer becomes DMA-visible

### VFIO (currently NO-GO per H004; documented for the future)

- **Who maps:** userspace. The driver `mmap`s its buffers (or allocates
  them), then issues `VFIO_IOMMU_MAP_DMA` ioctls against the VFIO container,
  binding each userspace VA range to an IOVA the device will use.
- **IOMMU translation:** performed by the platform IOMMU (absent on this
  kernel — this is one of H004's blocking facts). With no IOMMU, VFIO
  cannot isolate or translate; the mechanism is unusable here regardless.
- **Cache maintenance:** userspace's responsibility. Buffers intended for
  device DMA must be mapped uncached/write-combining, or the driver must
  issue cache clean/invalidate around transfers. On ARM64 this means
  `mmap` with appropriate `pgprot` (not available to pure userspace without
  a kernel partner) or relying on the IOMMU's coherency attributes.
- **Alignment/size:** IOVA and size must be page-granular (4 KiB); the
  device's 64-bit mask removes any sub-4 GiB constraint.

### UIO with uio_pci_generic (currently NO-GO per H004; documented for the future)

- **Who maps:** the kernel UIO driver. `uio_pci_generic` maps the BARs via
  `sysfs` resource mmap; for DMA buffers, userspace typically allocates
  huge pages or CMA-backed memory and passes physical addresses obtained
  via `/proc/self/pagemap` (or a custom UIO driver's `mmap`).
- **IOMMU translation:** none available (no SMMU). The device programs
  physical addresses directly into its VDMA descriptors (BAR2 rings per the
  transport guide).
- **Cache maintenance:** userspace's responsibility, and the sharpest
  ARM64 pitfall (see below). Without kernel help, userspace cannot issue
  DC CVAC/DC IVAC; it must use non-cached mappings (huge pages mapped
  uncached are not trivially obtainable from pure userspace).
- **Alignment/size:** descriptor rings and data buffers should be
  cache-line (64 B) aligned at minimum; page (4 KiB) alignment is the safe
  choice for anything the device DMAs.

### Practical reality on Mimir today

Neither VFIO nor UIO exists on this kernel, so **there is currently no
supported path for userspace to obtain DMA-coherent memory for the
Hailo-10**. The vendor `hailo1x_pci` driver (bound, no /dev node) would own
coherent allocation via the kernel DMA API if it were functional — but per
L6 it is an OS-side prerequisite Aesir never requires, and it is not
currently usable.

## ARM64-specific coherency pitfalls for H066/H067

**PITFALL (real, must be handled): cache maintenance without a kernel
partner.** The BCM2712's Cortex-A76 cores are cache-coherent with each
other (via the interconnect/ACE), but a PCIe endpoint doing DMA is an
*external* master. If the Hailo-10's VDMA writes land in DRAM while the
CPU holds stale lines in L1/L2/L3, userspace reads garbage; conversely,
CPU-written descriptor rings sitting dirty in cache are invisible to the
device. Pure userspace on ARM64 **cannot** execute `DC CVAC` (clean) /
`DC IVAC` (invalidate) — those are EL1+ instructions. Mitigations H066/H067
must choose among:

1. Map DMA buffers **uncached** from the start (requires kernel mapping
   help — not available to pure userspace today).
2. Use a **kernel partner** (even a minimal one) that performs the DMA API
   (`dma_map_single`/`dma_sync_*`) on userspace's behalf.
3. Restrict DMA to **CMA/huge-page** regions and accept that without
   maintenance the design is only safe if the device is configured for
   hardware coherency (no evidence the Hailo-10 participates in ACE/CHI
   coherency — assume it does not).

**No-pitfall items (checked, clear):**
- 64-bit DMA mask → no 32-bit addressing/bounce-buffer concern.
- 64-byte cache lines → align all shared structures to 64 B (cheap).
- No IOMMU → no IOTLB invalidation or IOVA management needed (but also no
  isolation — a misprogrammed descriptor can DMA anywhere in physical RAM;
  H066 must treat descriptor-ring programming as safety-critical).

## Evidence paths

- `/sys/bus/pci/devices/0001:01:00.0/iommu_group` (absent)
- `/sys/bus/pci/devices/0001:01:00.0/dma_mask_bits` (= 64)
- `/proc/meminfo` (`CmaTotal`/`CmaFree`)
- `/sys/devices/system/cpu/cpu0/cache/index0/coherency_line_size` (= 64)
- `docs/plunder/HAILO_PCIE_TRANSPORT_GUIDE.md` § on VDMA descriptor rings
  (BAR2) — the DMA engine H066/H067 will program
- H003 census (`CONFIG_ARM_SMMU` not set)
