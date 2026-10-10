# Banked Assault Index (H118) — F3 Durable Deliverable

**Date:** 2026-10-10
**Branch:** NO-GO (F3 = banked assault docs).
**Purpose:** the complete, honest record of the C4–C6 driver + protocol
assault — successes and negative results documented with equal care, so
a future attempt starts where this one stopped.

## C4 — HAILBRÚ driver (H061–H080)

Pure-Mojo userspace driver for the Hailo-10 PCIe interface. Every module
touches device nodes/BARs only through `hailbru/` (L12).

- `hailbru/__init__.mojo` — package root
- `hailbru/api.mojo` — public driver API surface
- `hailbru/bars.mojo` — BAR discovery and mapping
- `hailbru/bringup.mojo` — device bring-up sequencing
- `hailbru/config.mojo` — configuration-space access
- `hailbru/discovery.mojo` — PCIe device discovery
- `hailbru/dma.mojo` — DMA buffer management
- `hailbru/errors.mojo` — named error taxonomy (fail-closed)
- `hailbru/fw.mojo` — firmware interaction surface
- `hailbru/fwboot.mojo` — firmware boot observation (never re-flash; H075)
- `hailbru/guard.mojo` — safety guards
- `hailbru/health_obs.mojo` — read-only health observers
- `hailbru/irq.mojo` — interrupt handling (MSI)
- `hailbru/mechanism.mojo` — transport mechanisms
- `hailbru/pm.mojo` — power management (D0/D3hot)
- `hailbru/removal.mojo` — surprise-removal handling (H091)
- `hailbru/regs.mojo` — register access primitives
- `hailbru/syscall.mojo` — raw syscall layer (no libc)
- `hailbru/uio.mojo` — UIO path (proven viable; VFIO blocked)
- `hailbru/util.mojo` — parsing utilities
- `hailbru/vfio.mojo` — VFIO path (blocked: no CONFIG_VFIO_NOIOMMU)

## C5 — Bring-up and transport proof (H081–H100)

- `docs/plunder/HAILO_BRINGUP_GUIDE.md` — bring-up procedure
- `docs/plunder/HAILO_FW_LOAD_REGISTERS.md` — firmware-load registers
- `docs/plunder/HAILO_PCIE_TRANSPORT_GUIDE.md` — H005 transport study
  (mailbox/doorbell model, VDMA rings, MSI)
- `docs/plunder/HAILO_HEF_CONTAINER_GUIDE.md` — H006 HEF container study
- `docs/plunder/HAILO_CONFIG_SURFACE.md` — H019 config-surface survey
  (12 elements + SMIÐR-CFG v1 manifest, H104)

## C6 — SMIÐR wall assault (H101–H120)

Protocol research and honest artifacts:

- `docs/plunder/HAILO_COMMAND_QUEUE.md` — H101: corrected mailbox model
- `docs/smidr/H102_ATTEMPT_RECORD.md` — H102: FAIL, full evidence
  (5 hardenings + vendor ioctl + core-doorbell final probe)
- `docs/smidr/H105_ATTEMPT_RECORD.md` — H105: BLOCKED, dependency analysis
- `docs/smidr/PHASE_D_GATE.md` — H111: NO-GO verdict + technical account
- `docs/smidr/FALLBACK_TRIGGERED.md` — H115: F1 trigger record
- `smidr/__init__.mojo` — SMIÐR package (HAILBRÚ's authorized client)
- `smidr/mailbox.mojo` — faithful mailbox implementation
- `smidr/descriptor.mojo` — H103: descriptor builder (fail-closed)
- `smidr/config_gen.mojo` — H104: SMIÐR-CFG v1 generator
- `smidr/tools/__init__.mojo`
- `smidr/tools/mbping.mojo` — H102: 100× IDENTIFY tool
- `smidr/tools/mbdbg.mojo` — mailbox debug tool
- `smidr/tools/descemit.mojo` — H103: descriptor emitter
- `smidr/tools/cfgemit.mojo` — H104: config emitter
- `data/smidr/first_command_trace.json` — H102 transaction trace
- `data/smidr/descriptors.json` — H103 emitted descriptors
- `data/smidr/vecadd/vecadd_a.bin` — H104 golden inputs
- `data/smidr/vecadd/vecadd_b.bin` — H104 golden inputs
- `data/smidr/vecadd/vecadd_expected.bin` — H104 golden outputs
- `data/smidr/vecadd/vecadd_config.json` — H104 SMIÐR-CFG v1 manifest

## Negative results (start here next time)

1. **Firmware silent on both doorbells** (`docs/smidr/H102_ATTEMPT_RECORD.md`):
   writes land, doorbell live, zero response. Exact failure signature:
   `completed=False` at 1000–5000 ms, no MSI, response slot 0x0.
2. **Vendor ioctl rejects raw commands**
   ("not supported on integrated device type").
3. **Compute encoding unknown** (H019 element 1): the 0xFFFFFFFF
   sentinel marks the gap honestly — do not invent bytes.
4. **BAR2/VDMAsafety**: blind-programming the DMA engine is rejected
   as unsafe; the programming sequence is uncorroborated.

## Completeness

`prof/smidr/check_banked_index.py` verifies every path above exists and
no banked doc contains TBD/TODO. Run: `python3 prof/smidr/check_banked_index.py`.
