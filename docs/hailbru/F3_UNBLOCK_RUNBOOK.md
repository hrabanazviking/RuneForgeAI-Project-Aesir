# F3 Unblock Runbook — HAILBRÚ Driver (H080)

Every item F3-banked in Campaign 4, with the EXACT prerequisites to unblock
it. The moment Volmarr rebuilds Mimir's kernel, this path is clear with
zero re-research.

## §0. UNBLOCK STATUS — MET WITH CORRECTIONS (2026-10-10 ~09:17 EDT)

Volmarr's tryboot of `6.12.112-v8-16k-hailo+` succeeded; Mimir runs it.
Worker-verified (device.invoke recon — supersedes the coordinator's
summary where they differ):

| Criterion (from §1) | Status | Evidence |
|---|---|---|
| Kernel `6.12.112-v8-16k-hailo+` booted | MET | `uname -r` |
| VFIO framework live | MET | `/dev/vfio/vfio` (10,196); dmesg "VFIO - User Level meta-driver version: 0.3"; CONFIG_VFIO=y, VFIO_PCI=y, VFIO_IOMMU_TYPE1=y (builtin) |
| CONFIG_UIO_PCI_GENERIC | MET | `=m`; modules `uio`, `uio_pdrv_genirq` loaded |
| CONFIG_ARM_SMMU | MET (with caveat) | `=y`; 3 platform IOMMU devices present — **but no PCI device has an iommu_group** |
| CONFIG_VFIO_NOIOMMU | **NOT SET** | `# CONFIG_VFIO_NOIOMMU is not set`; no /dev/vfio/noiommu-0 |
| Old kernel + config.txt fallback | INTACT | per Volmarr's tryboot plan (untouched) |

**Consequence (Sólrún addendum 2026-10-10):** VFIO is live but
**unusable for 0001:01:00.0** — no IOMMU group, no noiommu fallback.
The real unblocked path is **UIO_PCI_GENERIC** (F3-2), not VFIO (F3-1).
DMA has no IOMMU: use physical addresses via /proc/self/pagemap with
an uncached /dev/mem O_SYNC CPU alias (no cache maintenance needed).
Vendor driver `hailo1x` (hailo1x_pci 5.3.0) is still bound; /dev/h1x-0
(508,0) exists; fuser shows no userspace holder. Device parked D3hot.

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

### F3-1: IOMMU DMA (`vfio_iommu_map`, H066) — SUPERSEDED

- **Status 2026-10-10:** BLOCKED-WITH-EVIDENCE, not unblocked.
  0001:01:00.0 has no IOMMU group and CONFIG_VFIO_NOIOMMU is not set —
  VFIO cannot attach this device. See §0.
- **Replacement path (real):** physical-address DMA without IOMMU —
  `/proc/self/pagemap` translation (root) + uncached `/dev/mem`
  O_SYNC CPU alias for the DMA buffers (no userspace cache
  maintenance possible per H018; the uncached alias sidesteps it).
  Map carefully, unmap on teardown — there is NO DMA isolation.
- **Unblock criterion (revised):** a DMA buffer's physical address is
  translated and stable across mlock; device-visible via the ATR
  windows (F3-4).
- **HAILBRÚ status:** `vfio_iommu_map` stays fail-closed
  (`IommuError`); the phys-DMA path is implemented in C5.

### F3-2: UIO bind path (H065) — THE REAL PATH (unblocked 2026-10-10)

- **Prerequisite:** §0 MET; `/sys/bus/pci/drivers/uio_pci_generic`
  exists (module `uio_pci_generic`, `=m`).
- **Steps (reversible; restore hailo1x after every session):**
  `probe uio-step --sysfs-root /sys --bdf 0001:01:00.0 --step unbind --as-root`
  (records original driver) → `--step register` → `--step bind` →
  verify `/dev/uioN` appears → `--step restore --original <name>` to
  return the vendor driver.
- **Unblock criterion:** `/dev/uioN` node appears; `uio_open` succeeds.
- **HAILBRÚ status:** implemented with privilege + presence gates.

### F3-3: Device MSI interrupts (H069) — via UIO (unblocked 2026-10-10)

- **Prerequisite:** F3-2 (UIO) — single MSI confirmed at config 0xE0
  (no MSI-X, H062).
- **Steps:** uio_pci_generic sets up MSI; interrupts surface as
  read() events on /dev/uioN (`uio_irq_wait`); acknowledge via the
  BAR0+0x018C status read.
- **Unblock criterion:** a real device MSI (DMA completion or
  doorbell) arrives on /dev/uioN; `uio_irq_wait` returns on interrupt,
  not timeout.
- **HAILBRÚ status:** eventfd/ppoll plumbing real and tested
  (10000/10000 exact); UIO IRQ wait executed for real in C5.

### F3-4: Firmware DMA upload + boot handshake (H074/H075/H076) — attempted for real (unblocked 2026-10-10)

- **Prerequisite:** F3-2 (UIO) + phys-DMA path + operator supervision
  (coordinator directive 2026-10-10).
- **Steps:** stage blobs (H073 verified, /lib/firmware/hailo/hailo10h/),
  program ATR windows at BAR0+0x700 with PHYSICAL DMA addresses
  (no IOMMU), DMA the three boot stages via the VDMA descriptor ring
  in uncached host memory, wait for channel-bitmap completions via
  UIO MSI, trigger each boot step, poll `BootPoller`/`ReadyPoller`.
- **Unblock criterion:** device reports ready; HAILBRÚ ready-poll
  (vendor mirror + status) succeeds post-boot.
- **HAILBRÚ status:** chunk planner, SHA-256 staging verify, and
  pollers implemented and self-tested; the DMA/IRQ halves executed
  for real in C5 — outcome recorded per-step, fail-closed.

### F3-5: Live register writes (H068 full) — unblocked 2026-10-10

- **Prerequisite:** vendor driver unbound via F3-2 (H005 §6 forbids
  writes while it is bound).
- **Steps:** map BAR0 writable via the UIO path, `reg_write32_verified`
  on a study-sanctioned register (ATR windows 0x0700+), readback check.
- **Unblock criterion:** `ReadbackMismatch` never raised across the
  write/readback matrix on live hardware.
- **HAILBRÚ status:** write/readback implemented and tested on emulated
  BARs (50/50); executed for real on the ATR windows in C5.

## §3. Safety rules for the unblock

- Never unbind the vendor driver without recording the original driver
  name first (`uio-step unbind` does this automatically).
- Always restore the original binding after a UIO/VFIO session unless
  Volmarr explicitly directs otherwise.
- Firmware upload is operator-supervised: the blob set is user-side
  (L7); HAILBRÚ verifies but never fetches.
- Each F3 item re-runs its H078 error-path tests after unblocking; the
  gate document (PHASE_B_GATE.md) is updated from NO-GO to GO item by item.
