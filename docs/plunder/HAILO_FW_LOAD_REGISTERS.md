# HAILO-10 Firmware-Load Register Map (H072)

Clean-room register survey for the firmware-upload path. Every offset below
comes from the Phase-A transport study
(`docs/plunder/HAILO_PCIE_TRANSPORT_GUIDE.md`, §§ 2/4/6); probe observations
are from HAILBRÚ `regs-probe` runs on Mimir (2026-10-10, device D0 via
standard PM-control transition — see H068 evidence).

## BAR0 control registers (16 KB window)

| Offset | Width | R/W semantics        | Purpose (study)                              | Probe-observed (D0) |
|--------|-------|----------------------|----------------------------------------------|---------------------|
| 0x0098 | 16    | Read-only, no side effects | Vendor-ID mirror (study §6)             | 0x1e60 (50/50 stable, H068) |
| 0x0188 | 32    | Read/write           | Interrupt mask — changes delivery (study §6) | 0x00000000          |
| 0x018C | 32    | Read-and-clear       | Host interrupt status; upper byte = firmware software-IRQ flags, lower fields = DMA channel completion (study §3) | 0x00800000 |
| 0x0400 | 32    | Read-and-clear       | Per-channel bitmap, source-side (study §3)   | 0x00000000          |
| 0x0500 | 32    | Read-and-clear       | Per-channel bitmap, dest-side (study §3)     | 0x00000000          |
| 0x0640+| 32    | Write (firmware CPUs)| Firmware-control offsets — "talk to the on-chip CPUs" (study §6). NOT probed for write (forbidden, H005 §6). | — |
| 0x0700+| 32    | Read/write           | ATR address-translation windows: host DMA address ↔ device view (study §4). Driver verifies the window landed at its expected block address. NOT programmed (needs IOMMU DMA → F3). | — |

## BAR4 mailbox (4 KB window, study §2)

The control path to the on-chip firmware is a mailbox with a flag — there is
no classic queue-pair doorbell:

| Offset (in BAR4) | Width | R/W semantics | Purpose (study) |
|------------------|-------|---------------|-----------------|
| 0x0000           | var   | Write (host)  | Command as length-prefixed buffer |
| per-board offset | 32    | Write (host)  | "Raise ready" flag — **this flag write is the doorbell**; selects which on-chip CPU handles the command |
| 0x0640           | var   | Read (host)   | Response slot: response length, then payload |

## Firmware boot sequence (study §4)

Firmware loading rides the VDMA descriptor-ring engine (up to 16 channels):

1. For each of three boot stages, the driver fetches staged firmware files
   through the OS firmware loader (`/lib/firmware/hailo` on the host —
   verified present by H073).
2. Stages are programmed as DMA batches over several channels; each
   descriptor carries page-size/control, DMA address low/high, and a
   remaining-bytes/status field the engine updates.
3. The host waits for a completion signal (channel-bitmap interrupts via
   0x018C/0x0400/0x0500), then triggers the boot step for that stage.
4. During boot, interrupts route to a boot-specific handler until the device
   reports ready.

## What HAILBRÚ can and cannot do today (H072 acceptance)

- **Can (real, probed):** read all BAR0 status registers above; verify the
  vendor mirror; stage and SHA-256-verify every firmware blob (H073);
  program ATR windows' *addresses* in a dry-run structure (not applied).
- **Cannot (F3-banked, prerequisites in F3_UNBLOCK_RUNBOOK.md):**
  programming ATR windows for real (needs IOMMU-mapped DMA addresses),
  DMA-batching the firmware stages (needs VFIO IOMMU DMA), receiving the
  completion interrupts (needs MSI-X eventfds), writing the 0x0640+
  firmware-control offsets or the BAR4 doorbell flag (needs a live boot
  handshake; writes forbidden while the vendor driver is bound, H005 §6).

## Probe notes

- In D3hot, all BAR0 reads return 0xFFFFFFFF (device asleep). The D0
  transition was performed via the standard PCI PM-control register
  (config offset 0xFC, PM cap at 0xF8): write 0x2008 (D0), verified by the
  vendor mirror reading 0x1e60. No vendor-driver state was disturbed; the
  device was returned to D3hot (0x200b) at the end of the probing session.
- irq_status 0x00800000 at rest: bit 23 set with no firmware loaded —
  recorded as the observed reset value, not interpreted further (L5:
  study-only; the studied sources do not name bit 23's reset meaning).
