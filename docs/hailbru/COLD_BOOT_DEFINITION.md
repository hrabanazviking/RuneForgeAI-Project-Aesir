# Cold-Boot Definition (H081)

Operational definition of "cold boot" for Campaign 5 bring-up work.
H085, H093, and H095 cite this definition.

## Options

### (a) Full Pi reboot + HAT power cycle + driver rebind
The strongest definition: reboot Mimir, power-cycle the Hailo-10 HAT,
rebind the driver, boot to ready. **OPERATOR-ONLY.** Rebooting Mimir
remotely would kill the command channel and disrupt Volmarr's other
services on the machine. Never attempted by Campaign 5 workers.

### (b) Driver-level full re-enumeration from a powered-but-unbound state
Unbind the vendor driver (`hailo1x`), re-enumerate the PCI device,
re-run the bring-up. **OPERATOR-SUPERVISED.** Unbinding the vendor
driver is F3-adjacent: it disturbs live driver state and H005 section 6
restricts writes while the driver is bound. Not used by Campaign 5.

### (c) PM-cycle bring-up (used by Campaign 5)
D3hot → D0 → verify → ready-poll → restore D3hot, via the documented
PCI PM capability register (PMCSR), with the vendor driver remaining
bound throughout. This exercises the full power-state machinery the
device exposes under the current kernel: the PMCSR write path, the
D3hot read behavior (config/BAR reads return 0xFFFFFFFF), the D0
recovery, and register coherency after the transition.

**"Ready" for Campaign 5 (READY_PM)** = D0 + vendor-mirror register
coherency (BAR0+0x0098 = 0x1e60, 5/5) + clean power-state cycle.
It is NOT firmware-booted inference-ready — that state needs F3-4
(IOMMU DMA + MSI + firmware boot handshake) after Volmarr's kernel
rebuild, and stays F3-banked.

## Per-cycle records

H085, H093, and H095 record which option was used per cycle. All
Campaign 5 cycles use option (c); this is an honest, recorded deviation
from the roadmap's (a)/(b), forced by the Phase-B NO-GO (no operator
reboot, no driver unbind by remote workers).
