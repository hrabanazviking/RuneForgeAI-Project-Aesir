# Phase-B Gate — HAILBRÚ Driver (H077)

**Verdict: NO-GO for Phase C (inference on the Hailo-10).**
**Date:** 2026-10-10. **Evidence:** measured on Mimir (Pi 5, kernel
6.12.109+rpt-rpi-2712), device 0001:01:00.0 (1e60:45c4).

This gate is honest: it passes what the current kernel allows and fails
closed what it forbids. Nothing is simulated.

## What works today (measured)

| Capability | Slice | Evidence |
|------------|-------|----------|
| Device discovery (1e60:45c4 → 0001:01:00.0) | H061 | `discover` on Mimir, real sysfs |
| Config-space identity (vendor/device/class, MSI cap 0xE0, no MSI-X, PM cap 0xF8) | H062/H071 | `identity` as root, 4096 config bytes |
| BAR table (BAR0 16K, BAR2 4K, BAR4 16K, flags 0x14220c) | H063 | `bars` on Mimir |
| Link status (Gen3 x1, 8.0 GT/s, device-limited) | H071 | `link` on Mimir |
| Mechanism selection → `sysfs-recon` (VFIO/UIO absent, cited) | H064/H065 | `mechanism` on Mimir |
| Root sysfs-resource mmap, read-only register probes | H068 | `regs-probe`: vendor mirror 0x1e60 in D0 |
| 50/50 coherency reads of BAR0+0x0098 → 0x1e60 | H068 | `regs-coherency` on Mimir, real device |
| CPU-side DMA alloc/free, mlock, double-free guards | H066/H067 | `dma-selftest` (both archs, + `--lock` as root on Mimir) |
| eventfd/ppoll IRQ plumbing (synthetic) | H069/H070 | `irq-selftest`: 10000/10000 exact, IrqTimeout |
| Firmware presence + SHA-256 (17 blobs, 112MB, pure-Mojo SHA-256) | H073 | `fwcheck` on Mimir; all verified |
| Firmware register map (study-accurate) | H072 | `docs/plunder/HAILO_FW_LOAD_REGISTERS.md` |
| 28 error-path tests, both toolchains | H078 | `prof/hailbru/test_error_paths.py` |
| Frozen API surface + compile-time test | H079 | `hailbru/API.md`, `api_surface_test` |

## What fails closed (the NO-GO items)

| Capability | Slice | Blocker (probe evidence) | Unblocks when |
|------------|-------|--------------------------|---------------|
| IOMMU DMA mapping (`vfio_iommu_map`) | H066 | `IommuError`: no `/dev/vfio/vfio` — CONFIG_VFIO not set (H004, H012) | Kernel rebuild with CONFIG_VFIO + ARM_SMMU (F3 runbook §1) |
| UIO bind path | H065 | `MechanismUnavailable`: no `/dev/uio*` — CONFIG_UIO_PCI_GENERIC not set (H004, H013) | Kernel rebuild with CONFIG_UIO_PCI_GENERIC (F3 runbook §1) |
| Device MSI interrupts via eventfd | H069 | `irq_vfio_set_irqs` → `MechanismUnavailable` (needs VFIO); single-MSI confirmed at config 0xE0 | VFIO available (F3 runbook §1) |
| Firmware DMA upload + boot handshake | H074/H075/H076 | Needs IOMMU DMA + completion IRQs (above); writes forbidden while vendor driver bound (H005 §6) | VFIO/UIO + operator-supervised bring-up (F3 runbook §2) |
| Live register writes | H068 | Forbidden by H005 §6 (no safe scratch register; vendor driver bound) | Vendor driver unbound under operator supervision (F3 runbook §2) |

## D3hot note

The device idles in D3hot; BAR reads return 0xFFFFFFFF. A standard
PCI PM-control write (config 0xFC ← 0x2008, PM cap at 0xF8) transitions it
to D0 — verified by the vendor mirror reading 0x1e60 — and it was returned
to D3hot (0x200b) after probing. The transition uses only the kernel's PCI
config interface; no vendor-driver state was disturbed.

## H014 catalogue discrepancy (found by H073)

`data/phase_a/firmware_catalogue.json` lists a 69-character "sha256" for
`hailo10h/u-boot-spl.bin` (a valid SHA-256 hex digest is 64 chars). The
on-disk blob hashes (Python hashlib AND HAILBRÚ's pure-Mojo SHA-256, in
agreement) to `219b9b98…5c3`. The catalogue entry is corrupt; HAILBRÚ
correctly raised `FirmwareCorrupt`. Recommended correction recorded in
DEVLOG.md — H014's data, not modified here.

## Gate decision

Phase C (inference) requires DMA to the device and completion interrupts.
Both are F3-banked on the current kernel. **The gate is NO-GO**, with the
exact unblock path in `docs/hailbru/F3_UNBLOCK_RUNBOOK.md` — zero
re-research needed the moment Volmarr rebuilds the kernel.
