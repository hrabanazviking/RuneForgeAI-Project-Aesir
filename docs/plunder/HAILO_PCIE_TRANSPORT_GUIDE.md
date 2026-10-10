# Hailo PCIe Transport Guide (clean-room study)

**Purpose:** Understanding for HAILBRU's independently-designed userspace
driver. STUDY ONLY — no code was copied, translated, or vendored.
**Studied:** `hailort-drivers` (GPL-2.0) and `HailoRT` (MIT) — see
`CLEAN_ROOM_LOG.md` for the audit trail.
**Date:** 2026-10-10. **Studied by:** MIMISBRUNNR Campaign 1 worker.

> Everything below is original prose describing observed architecture.
> No code blocks from the studied sources appear here; no functions were
> translated. File names are cited so the observations can be re-verified.

## 1. How the host discovers the device

The kernel driver's PCI probe matches on the Hailo vendor ID (0x1e60) plus a
per-board device ID table (Hailo-10H is 0x45C4 — the same IDs read from
Mimir's sysfs in H003). On a match the driver enables the PCI function,
claims its three memory BARs, and maps each into a named role:

- **BAR0 — configuration register space.** Interrupt status/mask registers,
  per-channel interrupt bitmaps, address-translation window config, and a
  vendor-ID mirror live here.
- **BAR2 — DMA-engine registers.** The VDMA engine's control registers.
- **BAR4 — firmware-access window.** The staging area for firmware control
  commands and responses.

After mapping, the driver enables a single MSI interrupt (the older
single-vector MSI API, not MSI-X) and registers a character device
(`/dev/hailoN`) that exposes an ioctl family to userspace programs.

*Files studied: `hailort-drivers/linux/pcie/src/pcie.c`,
`hailort-drivers/common/pcie_common.h`.*

## 2. How commands are submitted (the doorbell model)

There is no classic queue-pair with a tail-pointer doorbell. The control
path to the on-chip firmware works like a mailbox with a flag:

1. The host writes the command as a length-prefixed buffer into the BAR4
   window starting at offset 0.
2. The host then writes a 32-bit "raise ready" flag at a per-board offset in
   the same window, selecting which on-chip CPU should handle it. **This flag
   write is the doorbell** — it tells the firmware to consume the mailbox.
3. The host reads the response back from the BAR4 window at a fixed
   request-size offset (0x640): first the response length, then the payload.

So submission is "write mailbox, ring the ready flag, poll/read the reply
slot" — synchronous at the transport level, with the firmware's CPUs doing
the actual work.

*Files studied: `hailort-drivers/common/pcie_common.c`.*

## 3. How completions and interrupts are signaled

Interrupt delivery uses one MSI vector for the whole device. The interrupt
service routine does not get a reason code from the hardware directly;
instead it **reads** a host interrupt-status register in BAR0 config space,
and the read itself clears the bits (read-and-clear semantics). The status
word is partitioned: the upper byte carries software-IRQ flags from the
firmware, while two lower byte-fields mark which DMA channels have source-
side or destination-side completions pending. Two further read-and-clear
registers expand those into per-channel bitmaps.

The practical consequence: **acknowledgment is implicit in the status read.**
A userspace driver must read the status register to learn the cause and that
same read clears it; there is no separate EOI write. DMA completion waiters
are woken based on the channel bitmap extracted from those reads. During
firmware boot, interrupts are instead routed to a boot-specific handler
until the device reports ready.

*Files studied: `hailort-drivers/linux/pcie/src/fops.c`,
`hailort-drivers/common/pcie_common.c`.*

## 4. How DMA buffers are shared

Data movement uses a descriptor-ring DMA engine ("VDMA") with up to 16
channels and one engine instance. The model:

- The host allocates DMA-coherent memory for the payload.
- The host builds a list of descriptors in a contiguous chunk of memory the
  engine can read. Each descriptor carries a page-size/control field, the
  low and high halves of the 64-bit DMA address, and a
  remaining-bytes/status field the engine updates as it works.
- The engine walks the descriptor list and moves data between host memory
  and the device; completion is reported through the channel-bitmap
  interrupt mechanism described above.

Firmware loading rides the same engine: for each of three boot stages the
driver fetches staged firmware files through the OS firmware loader (the
files live in `/lib/firmware/hailo` on the host), programs them as DMA
batches over several channels, waits for a completion signal, and then
triggers the boot step for that stage.

Address translation between the host's DMA addresses and the device's view
is set up through ATR (address translation) windows programmed at BAR0
offset 0x700 and up; the driver verifies the window landed at its expected
block address before trusting it.

*Files studied: `hailort-drivers/common/vdma_common.c`,
`hailort-drivers/linux/pcie/src/pcie.c`,
`hailort-drivers/common/pcie_common.c`.*

## 5. The userspace contract (ioctl surface)

Userspace talks to the kernel driver through `/dev/hailoN` ioctls grouped
into families by magic byte: general (`g`), DMA engine (`v`), SoC control
(`s`), neural-network core (`n`), and PCIe endpoint (`p`). The general
family includes a device-properties query that reports board type and
capabilities. HAILBRU will not use this interface (it is a userspace driver
that replaces the kernel module's role), but the ioctl grouping documents
which concerns the transport must cover: properties, DMA programming,
firmware control, and inference control.

*Files studied: `hailort-drivers/common/hailo_ioctl_common.h`.*

## 6. Scratch register survey (for H068)

**No safe scratch register identified.** Evidence:

- A full-text search for "scratch" across every C and header file of the
  studied driver tree returned zero hits — the vendor driver defines no
  general-purpose or spare register.
- Every BAR0 register surveyed in the studied sources has a functional side
  effect: the interrupt mask (0x0188) changes interrupt delivery, the host
  interrupt status (0x018C) is read-and-clear, the per-channel bitmaps
  (0x400/0x500) are read-and-clear, the ATR window registers (0x700+) remap
  PCIe address windows, and the firmware-control offsets (0x640+) talk to
  the on-chip CPUs. Writing any of them for a loopback test would disturb
  device state.

Per the H005 acceptance criteria, H068's write/readback test is therefore
replaced by a **read-only coherency check**: 50 repeated 16-bit reads of the
vendor-ID mirror at BAR0 offset 0x0098 — a side-effect-free, read-only
register the studied driver itself uses to verify the device — each
expected to return 0x1e60. Stability of all 50 reads proves the
register path is coherent without touching device state.
