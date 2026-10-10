# Interrupt Capability Study (H017)

**Date:** 2026-10-10, measured on Mimir (Raspberry Pi 5, Hailo-10 at 0001:01:00.0)

## What the hardware exposes

**Legacy INTx (currently active):**
- `sysfs`: `/sys/bus/pci/devices/0001:01:00.0/irq` = **37**
- PCI config: interrupt pin = 1 (INTA#), interrupt line = 37
- This is the line the device asserts today (no MSI vectors allocated).

**MSI / MSI-X (capability present, not enabled):**
- `sysfs`: `/sys/bus/pci/devices/0001:01:00.0/msi_irqs/` is **EMPTY** — the
  kernel has allocated zero MSI vectors to this device.
- `/sys/bus/pci/devices/0001:01:00.0/msi_bus` = 1 (the PCIe root complex
  supports MSI signaling).
- PCI config: capabilities list present, first cap pointer = 0x80 (beyond
  the 64-byte config window readable without elevated privilege; not
  walked here).
- Per the clean-room transport study (`docs/plunder/HAILO_PCIE_TRANSPORT_GUIDE.md`,
  from the hailort-drivers/HailoRT sources): the vendor driver enables **a
  single MSI vector** — the older single-vector MSI API, **not MSI-X**.
  MSI-X is not used by the vendor stack.

**Acknowledgment model** (per the transport guide):
- The device does NOT clear its interrupt by MSI EOI alone. The driver must
  **read** the host interrupt-status register `BCS_ISTATUS_HOST` at
  **BAR0+0x018C** — it is **read-and-clear**.
- Interrupt masking via the mask register at BAR0+0x0188; per-channel
  completion bitmaps follow in BAR0 config space.
- During firmware boot, interrupts route to a boot-specific handler; the
  steady-state model above applies after boot.

## Mechanism for H069

**H069 implements MSI first** (single vector, matching the vendor driver).

Justification: the vendor stack — the only known-working software for this
chip — uses single-vector MSI, not MSI-X and not INTx. MSI avoids INTx's
shared-line latency and the INTx-disable dance, and the acknowledgment
sequence (read-and-clear 0x018C) is documented in the studied sources.
MSI-X would require discovering and programming the MSI-X table/BIR, which
no studied source describes for this device.

**Fallback order:** MSI → legacy INTx (IRQ 37).
Justification: INTx is provably wired and asserted today (irq=37, pin=INTA#);
it is the only interrupt the device generates without any MSI programming.
If MSI programming fails on Mimir's kernel/PCIe controller, INTx with the
same 0x018C read-and-clear handler is the safe retreat. MSI-X is not a
fallback — it is unproven on this device.

## Userspace delivery primitives per mechanism

**VFIO** (if the kernel ever gains it — currently NO-GO per H004):
`eventfd` + `ioctl`. The userspace driver creates an eventfd, passes it to
the kernel via `VFIO_DEVICE_SET_IRQS` ioctl bound to the MSI vector index,
and `poll`s/`read`s the eventfd for interrupt notifications. One eventfd per
vector (one vector here). Acknowledgment still requires the BAR0+0x018C
read-and-clear from userspace after wakeup.

**UIO** (if `uio_pci_generic` ever exists — currently NO-GO per H004):
**blocking `read`**. The UIO core blocks the userspace `read()` on
`/dev/uioX` until the interrupt fires, returning the interrupt count; the
driver then performs the BAR0+0x018C read-and-clear and re-arms by
re-issuing the blocking read. No eventfd, no ioctl for the wait itself
(though `UIO_INT` semantics vary by UIO driver).

**Bare sysfs** (recon only, not selectable per architecture): no interrupt
delivery primitive exists — sysfs exposes no wait/notify path, which is one
reason H004 rejects it as a driver mechanism.

## Evidence paths

- `/sys/bus/pci/devices/0001:01:00.0/irq`
- `/sys/bus/pci/devices/0001:01:00.0/msi_irqs/` (empty)
- `/sys/bus/pci/devices/0001:01:00.0/msi_bus`
- `/sys/bus/pci/devices/0001:01:00.0/config` (pin/line; cap ptr 0x80)
- `docs/plunder/HAILO_PCIE_TRANSPORT_GUIDE.md` §§ 2–3 (single MSI, 0x018C
  read-and-clear, 0x0188 mask)
