# F3 Unblock Runbook — HAILBRÚ Driver (H080)

Every item F3-banked in Campaign 4, with the EXACT prerequisites to unblock
it. The moment Volmarr rebuilds Mimir's kernel, this path is clear with
zero re-research.

## §1. Kernel rebuild (operator action — Volmarr's hands-only decision)

**Why:** Mimir's kernel (6.12.109+rpt-rpi-2712) has CONFIG_VFIO,
CONFIG_UIO_PCI_GENERIC, and CONFIG_ARM_SMMU all not-set (H004
MECHANISM_VERDICT.md = NO-GO). Route (a) was explicitly taken off the
table for Campaign 4; this section is the exact recipe for when Volmarr
gives the go.

**Exact config options to enable** (via `make menuconfig` on the Pi kernel
tree, or direct `.config` edits):

| Option | Value | Purpose |
|--------|-------|---------|
| `CONFIG_VFIO` | `m` or `y` | VFIO core framework |
| `CONFIG_VFIO_PCI` | `m` or `y` | VFIO PCI device driver |
| `CONFIG_VFIO_NOIOMMU` | `n` | Must stay off — we need real IOMMU |
| `CONFIG_UIO` | `m` or `y` | Userspace I/O core |
| `CONFIG_UIO_PCI_GENERIC` | `m` or `y` | Generic UIO driver for PCI devices |
| `CONFIG_ARM_SMMU` | `y` | ARM SMMU driver (Pi 5 SoC IOMMU) |
| `CONFIG_IOMMU_SUPPORT` | `y` | IOMMU subsystem (pulled in by SMMU) |

**Operator steps** (per the decided plan, MEMORY.md 2026-10-10):

1. On the Ryzen 9 Kubuntu laptop (second Muse gadget): clone the
   Raspberry Pi kernel tree matching Mimir's version (6.12.109+rpt-rpi).
2. Apply the stock Pi defconfig (`bcm2712_defconfig`), then enable the
   options above.
3. Cross-compile (`ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`). Fast on
   the Ryzen 9.
4. Ship the kernel image + modules + dtbs to Mimir.
5. Install ALONGSIDE the old kernel with bootloader fallback
   (`/boot/firmware/config.txt` keeps the old entry; do not overwrite).
6. **Volmarr gives the explicit go** before install+reboot.
7. Reboot; verify with the unblock criteria below.

**Unblock criteria (run on Mimir after reboot):**

```
ls /dev/vfio/vfio          # exists → CONFIG_VFIO ok
ls /dev/uio*               # appears after bind → CONFIG_UIO_PCI_GENERIC ok
dmesg | grep -i smmu       # SMMU probed → CONFIG_ARM_SMMU ok
sudo ./probe mechanism     # selected should become "vfio" (not sysfs-recon)
```

## §2. Banked items and their exact unblock paths

### F3-1: IOMMU DMA (`vfio_iommu_map`, H066)

- **Prerequisite:** §1 complete; `probe mechanism` selects `vfio`.
- **Steps:** open `/dev/vfio/vfio` (vfio_open_container), bind 0001:01:00.0
  to vfio-pci (operator-supervised; unbinds the vendor driver —
  see §3), map DMA buffers via `VFIO_IOMMU_MAP_DMA`.
- **Unblock criterion:** `vfio_iommu_map` returns without `IommuError`;
  a DMA write/readback through the IOMMU round-trips.
- **HAILBRÚ status:** implemented, fail-closed (`IommuError` today).

### F3-2: UIO bind path (H065)

- **Prerequisite:** §1 complete; `/sys/bus/pci/drivers/uio_pci_generic`
  exists.
- **Steps (operator-supervised, reversible):**
  `probe uio-step --sysfs-root /sys --bdf 0001:01:00.0 --step unbind --as-root`
  (records original driver) → `--step register` → `--step bind` →
  verify `/dev/uioN` appears → `--step restore --original <name>` to
  return the vendor driver.
- **Unblock criterion:** `/dev/uioN` node appears; `uio_open` succeeds.
- **HAILBRÚ status:** implemented with privilege + presence gates.

### F3-3: Device MSI interrupts (H069)

- **Prerequisite:** F3-1 (VFIO) — single MSI confirmed at config 0xE0.
- **Steps:** `VFIO_DEVICE_SET_IRQS` with an eventfd; `irq_wait` on the
  fd; acknowledge via the BAR0+0x018C read-and-clear.
- **Unblock criterion:** `irq-selftest`-style synthetic signal replaced
  by a real device MSI; `irq_wait` returns on interrupt, not timeout.
- **HAILBRÚ status:** eventfd/ppoll plumbing real and tested
  (10000/10000 exact); the VFIO irq-set is F3-gated.

### F3-4: Firmware DMA upload + boot handshake (H074/H075/H076)

- **Prerequisite:** F3-1 (DMA) + F3-3 (IRQs) + operator supervision.
- **Steps:** stage blobs (H073 verified), program ATR windows at BAR0+0x700
  with IOMMU-mapped addresses, DMA the three boot stages via the VDMA
  descriptor ring, wait for channel-bitmap completions, trigger each boot
  step, poll `BootPoller`/`ReadyPoller`.
- **Unblock criterion:** device reports ready; `/dev/hailo*` or HAILBRÚ
  ready-poll succeeds.
- **HAILBRÚ status:** chunk planner, SHA-256 staging verify, and pollers
  implemented and self-tested; the DMA/IRQ halves are F3-gated.

### F3-5: Live register writes (H068 full)

- **Prerequisite:** vendor driver unbound under operator supervision
  (F3-2 or direct unbind) — H005 §6 forbids writes while it is bound.
- **Steps:** map BAR0 writable, `reg_write32_verified` on a
  study-sanctioned register, readback check.
- **Unblock criterion:** `ReadbackMismatch` never raised across the
  write/readback matrix on live hardware.
- **HAILBRÚ status:** write/readback implemented and tested on emulated
  BARs (50/50); live writes refused by policy today.

## §3. Safety rules for the unblock

- Never unbind the vendor driver without recording the original driver
  name first (`uio-step unbind` does this automatically).
- Always restore the original binding after a UIO/VFIO session unless
  Volmarr explicitly directs otherwise.
- Firmware upload is operator-supervised: the blob set is user-side
  (L7); HAILBRÚ verifies but never fetches.
- Each F3 item re-runs its H078 error-path tests after unblocking; the
  gate document (PHASE_B_GATE.md) is updated from NO-GO to GO item by item.
