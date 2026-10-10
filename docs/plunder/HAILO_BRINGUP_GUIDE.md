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

## Path F — F3-unblocked kernel (REAL since 2026-10-10)

Prerequisites MET 2026-10-10: Mimir runs `6.12.112-v8-16k-hailo+`
(tryboot success). BUT the recon corrected the plan:

- **VFIO is BLOCKED for 0001:01:00.0**: no IOMMU group for the device
  (PCIe not behind the ARM SMMU) and CONFIG_VFIO_NOIOMMU is not set.
  The VFIO framework is live but unusable for this device.
- **UIO is the real path**: CONFIG_UIO_PCI_GENERIC=m; `uio_pci_generic`
  binds, `/dev/uio0` appears, MSI delivered, `hailo1x` restores cleanly.
- **The vendor driver boots the firmware at kernel boot** — HAILBRÚ
  verifies (ATR1 == 0x200000) rather than re-flashing. The full
  userspace flash (`probe fw-boot`) is implemented but refuses when
  already_loaded=1 (fail-safe; re-flashing a running device is unsafe).

### F1. UIO session (executed for real 2026-10-10)

Record the original driver (`hailo1x`); unbind; `new_id "1e60 45c4"`
(the kernel auto-binds — the explicit `bind` write may race, tolerate
it); `/dev/uio0` appears; restore `hailo1x` after. Gotchas found live:
`new_id` is write-only (existence checks must not use O_RDONLY);
re-registering an ID returns EEXIST (tolerate); `modprobe
uio_pci_generic` first. Every step reversible
(`uio_step_unbind/register/bind/restore` — H065).

### F2. DMA without IOMMU

No IOMMU exists for this device — there is no DMA isolation. The
honest userspace path: physical addresses via `/proc/self/pagemap`
(root) + an uncached `/dev/mem` O_SYNC CPU alias for the DMA buffers
(no userspace cache maintenance possible per H018; the uncached alias
sidesteps it). Map carefully, unmap on teardown. **Not yet
demonstrated** — the PIO strategy below made DMA unnecessary for boot.

### F3. Program ATR windows (executed for real)

The ATR table at **BAR0+0x0700** (5×u32 per window, stride 0x20;
`atr_param = 0x17 | index<<12`, `atr_trsl_param = 6`) is programmed
for real (`fw_atr_program`, `hailbru/fwboot.mojo`). The `write_memory`
/ `read_memory` routines save/restore ATR0 around each 4KB-chunked
PIO transfer through BAR4 (fw_access), exactly like the vendor driver.

### F4. The three boot stages (PIO strategy — driver-supported)

The vendor driver itself supports STRATEGY_PCIE_BARS for all stages
(`force_hailo_pcie_boot_mode_over_bars`), so PIO is legitimate:

- Stage 1: `customer_certificate.bin` → 0xA0000; `scu_fw.bin`
  (header-parsed: magic 0xE905DAAB verified; header→0x88000,
  code→0x20000, key→0x88018, content→0x886A8). Trigger: write 1 to
  0x88C98. Wait BOOT_IRQ (0x018C bit 25) via UIO MSI, 5 s timeout.
- Stage 2: `u-boot-<sku>.dtb.signed` → 0xA8004 (SKU read from
  0xDEFFC after stage 1). Trigger 0xDEFF8. Wait 5 s.
- Stage 3: `u-boot-spl.bin` → 0x80300000, `fitImage` → 0x88000000,
  `image-fs` → 0x90000000 (`u-boot-tfa.itb` optional). Trigger
  0x802FF000. Wait 40 s.
- Implemented in `hailbru/fwboot.mojo` + `probe fw-boot`; validated
  against the real blob headers; NOT fired (device already booted).

### F5. Boot handshake (signals verified real)

The handshake signals are read and verified: ATR1 translation ==
0x200000 (`hailo_pcie_is_firmware_loaded`), boot_status == 1
(ATR-windowed read of 0x80000). A soft reset was triggered for real
(u32 8 → BAR4+0x1754 = FW_ACCESS_SOFT_RESET_MASK); a real MSI
arrived on /dev/uio0 (count=1), though the SOFT_RESET_IRQ bit was not
confirmed in istatus — the completion-bit path needs a cleaner test.

### F6. Firmware version

Still open: query the running firmware's version via the mailbox
response slot (**BAR4+0x0640**) or version registers; record in
`data/hailbru/firmware_version.json` and cross-check against the H014
blob catalogue. (H086 — unblocked, not yet executed.)

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
