# Hailo-10 Bring-up Guide (H098)

Clean-room bring-up knowledge for the Hailo-10 on Mimir (0001:01:00.0,
1e60:45c4, bound to `hailo1x` / `hailo1x_pci` 5.3.0), written from
Campaign 5 evidence. A reader with the HAILBRÚ API
(`hailbru/API.md`) can bring the device up following this guide alone.

Two paths are documented: **Path K** (current kernel — what works
today) and **Path F** (F3-unblocked kernel — after Volmarr's rebuild).

---

## Path K — current kernel (Mimir today)

Kernel 6.12.109+rpt-rpi-2712 has no VFIO, no UIO_PCI_GENERIC, no ARM
SMMU (Phase-B gate NO-GO). No IOMMU DMA, no device MSI, no firmware
DMA upload. Bring-up = the **PM-cycle bring-up** (COLD_BOOT_DEFINITION.md
option (c)).

### K0. Preconditions

- Device present: `discover("aarch64", "/sys", 0x1E60, 0x45C4)` → BDF.
- Driver binding: `/sys/bus/pci/devices/<bdf>/driver` must resolve to
  `hailo1x`. Named error `DriverBindingMismatch` otherwise.
- Identity: config-space vendor 0x1E60, device 0x45C4, class 0x0B4000
  (`check_identity` → `IdentityMismatch` on drift).
- Root for config-space writes and BAR0 mmap (`PrivilegeRequired`
  otherwise).

### K1. Find the PM capability

Walk the PCI capability list from config 0x34; capability ID 0x01 is
Power Management. On Mimir it is at **0xF8**; PMCSR (control/status)
is at **0xFC** (H071 evidence). `find_pm_cap` raises
`PowerManagementUnsupported` if absent.

### K2. Assert D3hot (the "reset")

Write the PMCSR power-state field [1:0] = 3 (`pm_set_state(..., 3)`).
This is standard PCI power management — the same operation the kernel
performs on suspend — NOT a BAR register write (H005 §6 governs BAR
writes; this practice was established in C4 via setpci
`0xFC.w=0x2008/0x200b`).

- Poll the PMCSR field until it reads back 3 (5s timeout →
  `PowerTransitionFailed`).
- Functional verify: map BAR0 read-only; in D3hot the vendor mirror at
  **BAR0+0x0098** reads 0xFFFF (D3hot all-ones behavior, H068).
- Idempotent: asserting D3hot while already in D3hot is a safe no-op.

### K3. Enter D0 (the "boot")

Write PMCSR[1:0] = 0. Allow ~50ms settle (measured: transition <2ms,
settle dominates). Poll PMCSR until it reads back 0.

**Do NOT trust** `/sys/bus/pci/devices/<bdf>/power_state` after a
manual transition: the kernel's PCI-core bookkeeping does not follow
manual PMCSR writes (measured 2026-10-10: file still read "D3hot"
seconds after PMCSR=D0 with coherent BAR reads). The authoritative
signals are the PMCSR readback plus the functional probe below.

### K4. Verify BARs and coherency

- `parse_resource` → BAR table; BAR0/2/4 expected (H063).
- Map BAR0 read-only (`map_sysfs_resource(..., writable=False)`).
- Read **BAR0+0x0098** (vendor-ID mirror, 16-bit): must read 0x1E60.
  Read 5 consecutive times — 5/5 required (`DeviceNotReady` /
  `VendorMirrorMismatch` otherwise).
- Read **BAR0+0x018C** (host interrupt status): at rest in D0 it reads
  0x00800000 once the device has settled (~100ms+ after D0 entry);
  immediately after entry it may read 0x0000. Bit 23 is time-dependent
  → volatile, masked in golden comparisons (H082 evidence).
- **BAR0+0x0188** (interrupt mask) reads 0x00000000 at rest;
  **BAR0+0x0400/0x0500** (channel bitmaps) read 0x00000000 at rest.

### K5. "Ready" (READY_PM)

Ready = D0 + 5/5 vendor-mirror coherency + clean power-state cycle.
This is NOT firmware-booted inference-ready. Record the distinction
in every log (`ready_meaning` field).

### K6. Restore D3hot

Always end a probing session with PMCSR[1:0] = 3. The vendor driver
left the device in D3hot; leave it undisturbed.

### Timing budget (H085)

- Full PM-cycle bring-up: mean 101.8ms, max 102ms (n=30).
- Official budget: **1 second** (max_observed × 2, rounded up).
- Slowest step: `enter_d0` 50.1ms (49.2%) — the deliberate 50ms
  settle, not the transition itself.
- Resume (D3hot→D0): max 73ms, allowance 1000ms (H090, n=20).

---

## Path F — F3-unblocked kernel (after Volmarr's rebuild)

Prerequisites: kernel rebuilt with CONFIG_VFIO, CONFIG_VFIO_PCI,
CONFIG_UIO, CONFIG_UIO_PCI_GENERIC, CONFIG_ARM_SMMU (operator action;
exact recipe in `docs/hailbru/F3_UNBLOCK_RUNBOOK.md` §1). Unblock
criteria: `/dev/vfio/vfio` exists, `/dev/uioN` appears after bind,
`dmesg | grep -i smmu` shows the SMMU probed, `probe mechanism`
selects `vfio`.

### F1. Bind via VFIO or UIO (operator-supervised)

Record the original driver name first; unbind `hailo1x`; bind
`vfio-pci` (or `uio_pci_generic`); restore the original binding after
the session unless Volmarr directs otherwise. Every step is reversible
(`uio_step_unbind/register/bind/restore`).

### F2. IOMMU DMA mapping

Open the VFIO container, `VFIO_IOMMU_MAP_DMA` for the firmware staging
buffers (`vfio_iommu_map` — fail-closed `IommuError` until this path
is live). Stage the 17 verified blobs (H073, 112MB, SHA-256).

### F3. Program ATR windows

Write the IOMMU-mapped DMA addresses into the ATR address-translation
windows at **BAR0+0x0700** (H072). Driver verifies each window landed
at its expected block address.

### F4. DMA the three boot stages

Program the VDMA descriptor-ring engine (up to 16 channels) with the
three boot-stage batches; each descriptor carries page-size/control,
DMA address low/high, remaining-bytes/status. Wait for completion via
the channel-bitmap interrupts (**BAR0+0x018C/0x0400/0x0500**) —
device MSI via `VFIO_DEVICE_SET_IRQS` + eventfd (F3-3).

### F5. Boot handshake

Trigger each boot step; the firmware-control offsets at **BAR0+0x0640+**
"talk to the on-chip CPUs" (H072); the BAR4 mailbox (4KB window)
carries commands as length-prefixed buffers with the "raise ready"
flag as the doorbell (H072 §mailbox). Poll `BootPoller`/`ReadyPoller`
until the device reports ready (`FirmwareBootTimeout` /
`DeviceNotReady` on failure).

### F6. Firmware version

Query the running firmware's version via the documented version
registers or the mailbox response slot (**BAR4+0x0640**); record in
`data/hailbru/firmware_version.json` and cross-check against the H014
blob catalogue.

---

## Failure modes and recovery (summary; full catalog: FAILURE_MODES.md)

| Symptom | Recovery |
|---|---|
| `DriverBindingMismatch` | Do not proceed; the vendor driver was replaced — operator question. |
| `PowerTransitionFailed` | Dump registers (`bringup_dump_registers`); retry once; if the PMCSR field will not move, stop — possible HAT power issue (operator). |
| `BootHang` (step > budget+5s) | The error carries a ≥10-register dump; diagnose the named step; the CLI wrapper restores D3hot automatically. |
| `VendorMirrorMismatch` / `DeviceNotReady` | Link retraining may be in flight; wait 1s, re-run `ready_poll`; persistent failure → treat as `PowerTransitionFailed`. |
| `DeviceBusy` | Another process holds the session lock (PID named); wait or coordinate — never bypass the guard. |
| `DeviceRemoved` | Mappings already released; exit the session cleanly; re-discover before any new session. |

## Second-pass validation (H098 acceptance)

The builder re-derived the H081 orchestrator's step order from this
guide alone: assert_binding → read_initial_state → enter_d3hot →
verify_d3hot → enter_d0 → bar_verify → ready_poll → [firmware_load,
boot_handshake: F3-banked] → restore_d3hot. Matches
`hailbru/bringup.mojo::run_bringup` exactly. No discrepancies.
