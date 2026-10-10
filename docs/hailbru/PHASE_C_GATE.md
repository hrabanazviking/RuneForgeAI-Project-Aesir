# Phase C Gate — HAILBRÚ Bring-up & Firmware (H095)

Date: 2026-10-10. Kernel: `6.12.112-v8-16k-hailo+`. Device 0001:01:00.0
(Hailo-10H, 1e60:45c4), firmware BOOTED (ATR1 == 0x200000, verified).

## What "ready" means (honest redefinition)

READY_PM (Campaign 5 original): D0 + vendor-mirror coherency + clean
power-state cycle. NOT firmware-booted inference-ready.

READY_FW (2026-10-10, kernel rebuild): READY_PM **plus** firmware
verified booted — ATR1 translation address == 0x200000
(`hailo_pcie_is_firmware_loaded`) and boot_status == 1. The vendor
driver booted the firmware at kernel boot; HAILBRÚ verified the
signals read-only. Inference-ready (Phase D) is still a separate
gate — no NPU workloads were run.

## Gate evidence (measured 2026-10-10, new kernel)

| Check | Result | Evidence |
|---|---|---|
| 100× power cycles (H084) | 100/100 OK | min 110.9 / max 133.2 / mean 113.6 ms, 11.4 s total |
| 10× golden register checks (H096) | 10/10 PASS, 0 deviations | 21 registers vs golden_ready.json |
| 20× suspend/resume (H090) | 20/20, max 140 ms | allowance 1000 ms |
| 100× health samples (H087) | 100/100, 0 errors | SoC 38.6–42.5 °C (Pi SoC, NOT device die) |
| Firmware booted | YES | ATR1 == 0x200000; driver "already loaded" |
| UIO bind/restore (H065) | REAL | /dev/uio0 appeared; hailo1x restored |
| Real MSI (H069) | REAL | count=1 on /dev/uio0 via uio_pci_generic |

## Verdict

**GATE PASS (READY_FW).** The device is firmware-booted, power-cycling
cleanly, register-coherent, and the UIO userspace-driver path is real.
Phase D (inference) may proceed to H111 on this basis.

## What was NOT gated

- Full 3-stage firmware re-flash (H075): implemented, not fired —
  the device was already booted and re-flashing a running device is
  unsafe. The code refuses when already_loaded=1 (fail-safe).
- VDMA descriptor DMA (H066): not demonstrated; the PIO strategy
  (driver-supported) made it unnecessary for boot.
- The soft-reset MSI handshake: a real MSI arrived, but the
  SOFT_RESET_IRQ bit was not confirmed in istatus — the completion
  signal path needs a cleaner test.

## Data

Full measurement data: `~/mimisbrunnr_c5/data/` on Mimir (reboot-safe).
Summary: `data/hailbru/c5_20261010/measurements.json` in this repo.
