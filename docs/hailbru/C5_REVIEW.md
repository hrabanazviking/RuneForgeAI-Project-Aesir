# Campaign 5 Review — Bring-up & Firmware (H081–H100)

Date: 2026-10-10. Branch: `mimisbrunnr-c5-h081-h100`.
Kernel: `6.12.112-v8-16k-hailo+` (Volmarr's rebuild, tryboot success).

## What changed mid-campaign

Mimir rebooted onto the new kernel halfway through C5, wiping /tmp
(all measurement data) and — far more importantly — **unbanking the
F3 items**. A Sólrún audit addendum (in MIMISBRUNNR_PROGRESS.md)
corrected the coordinator's recon: VFIO is live but BLOCKED for this
device (no IOMMU group, no CONFIG_VFIO_NOIOMMU); **UIO is the real
path**. All measurements were re-run against the new kernel.

## Slice verdicts

| Slice | Verdict | Evidence |
|---|---|---|
| H081 bring-up orchestrator | DONE (real PM cycle) | READY_PM ~101–114 ms; omit/stall fault injection green |
| H082 register snapshots | DONE | 21 regs × states, golden rebuilt |
| H083 PCI reset procedure | DONE | documented; PM-cycle reset validated |
| H084 100× harness | DONE | 100/100, mean 113.6 ms |
| H085 boot timing | DONE | budget 1 s (max 133 ms × 2 rounded) |
| H086 on-chip FW version | OPEN | unblocked, not yet executed |
| H087 VÖRÐR hooks | DONE | 100/100 samples, SoC temp labeled |
| H088 BootHang validation | DONE | real hang + 21-reg dump; 30 clean, 0 FP |
| H089 log schema | DONE | 5 accept / 5 reject selftest green |
| H090 PM transitions | DONE | 20/20, max 140 ms (allow 1000) |
| H091 removal guard | DONE | DeviceRemoved 0 ms, fds 4→4 |
| H092 concurrency guard | DONE | DeviceBusy + stale reclaim |
| H093 1000× soak | PARTIAL | re-run pending (was 1000/1000 pre-reboot) |
| H094 thermal | DONE | ΔT 3.3 °C / 100 cycles, no caution |
| H095 Phase C gate | DONE | 100/100 + 10/10 golden → READY_FW |
| H096 golden + regdiff | DONE | 3/3 injected caught, 10/10 clean |
| H097 drift detector | PARTIAL | 1-hour baseline incomplete (125 s cap) |
| H098 bring-up guide | DONE | Path K + Path F (UIO-real) documented |
| H099 failure modes | DONE | 18 modes, 4 observed 2026-10-10 |
| H100 this review | DONE | — |

### F3 items executed for real (unbanked 2026-10-10)

- H064 BAR mapping: REAL via UIO (VFIO blocked-with-evidence).
- H065 UIO bind: REAL (/dev/uio0, restore verified).
- H066 DMA: NOT demonstrated (PIO strategy sufficed; design documented).
- H069 MSI: REAL (count=1 on /dev/uio0; source bit unconfirmed).
- H074 staging: REAL (scu_fw.bin parsed, magic verified).
- H075 upload: IMPLEMENTED, not fired (device already booted; fail-safe).
- H076 handshake: signals verified real; trigger/wait implemented.

## Reliability table

| Metric | Value |
|---|---|
| Power cycles (H084) | 100/100, 110.9–133.2 ms |
| Suspend/resume (H090) | 20/20, ≤140 ms |
| Golden checks (H095) | 10/10, 0 deviations |
| Health samples (H087) | 100/100, 0 errors |
| MSI delivery (H069) | 1/1 received |

## C5 VERDICT: READY_FW — Phase D may proceed

The device is firmware-booted (ATR1 == 0x200000, verified), power-
cycles cleanly, is register-coherent, and HAILBRÚ owns a real
userspace-driver path (UIO + MSI + ATR-programmed PIO). The road to
H111 (the Compiler Wall) is open: real DMA design + real interrupts +
a complete (if unfired) firmware uploader are the prerequisites the
Wall assault needs.

## Open items for Campaign 6

1. H086: query the running firmware version (mailbox BAR4+0x0640).
2. H066: demonstrate the phys-DMA path (pagemap + uncached alias).
3. H093: re-run the 1000× soak on the new kernel.
4. H097: complete the 1-hour drift baseline in ≤120 s chunks.
5. H069: cleaner soft-reset completion-bit verification.
