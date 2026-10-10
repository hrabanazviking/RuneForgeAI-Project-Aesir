# Bring-up Failure-Mode Catalog (H099)

Every failure mode observed or credibly hypothesized during Campaign 5
bring-up. Each entry: symptom, register signature, likely cause,
recovery action, handling slice. OBSERVED modes cite log evidence;
HYPOTHESIZED modes are marked with their reasoning.

## FM-01 — Driver binding mismatch (OBSERVED)

- **Symptom:** `HailbruError[DriverBindingMismatch]` at bring-up start.
- **Register signature:** none (fails before any register access).
- **Likely cause:** vendor driver replaced/unbound (operator action,
  kernel module update, or another worker's UIO experiment).
- **Recovery:** stop immediately; do not touch the device; escalate to
  the operator. Evidence: `/tmp/bringup_omit` runs (2026-10-10) —
  orchestrator asserts `hailo1x` before any power operation.
- **Handling slice:** H081 (`assert_binding` step).

## FM-02 — Power transition timeout (OBSERVED in test form)

- **Symptom:** `HailbruError[PowerTransitionFailed]` with PMCSR +
  power_state dump.
- **Register signature:** PMCSR[1:0] != target after 5s of polling.
- **Likely cause:** HAT power issue, PCIe link down, or the device wedged
  in an intermediate state. (The named error was exercised via the
  sysfs-file race during development, 2026-10-10: PMCSR=D0 while the
  kernel file lagged — that instance was a verification artifact, fixed
  by functional verification; a true PMCSR stall has not been seen.)
- **Recovery:** register dump via `bringup_dump_registers`; retry once;
  persistent stall → stop, operator checks HAT power/seating.
- **Handling slice:** H083 (`pm_set_state`), H088 (dump on hang).

## FM-03 — Boot hang on a bring-up step (OBSERVED via test hook)

- **Symptom:** `HailbruError[BootHang]` naming the step, with a ≥10
  (actually 21) register dump attached.
- **Register signature:** dump of 16 config dwords + 5 BAR0 offsets at
  hang time.
- **Likely cause:** in production: a step genuinely wedged (link
  retraining storm, device not responding to PMCSR). In testing: the
  `--stall-step` hook.
- **Recovery:** diagnose the named step from the dump; the CLI wrapper
  restores D3hot automatically; re-run the bring-up.
- **Handling slice:** H088. Evidence: `--stall-step enter_d0`
  → BootHang at 8050ms (>7000ms = budget+5s), 21-register dump,
  device restored D3hot (2026-10-10).

## FM-04 — Vendor mirror mismatch (HYPOTHESIZED)

- **Symptom:** `HailbruError[VendorMirrorMismatch]` — BAR0+0x0098 !=
  0x1e60 in D0.
- **Register signature:** BAR0+0x0098 reads 0xFFFF (still D3hot?) or
  garbage (link down?).
- **Likely cause:** D0 transition incomplete (settle too short),
  PCIe link retraining in flight, or — seriously — wrong device at the
  BDF.
- **Recovery:** wait 1s, re-run `ready_poll`; if persistent, treat as
  FM-02. Never "average it away": the coherency check is 5/5 or fail.
- **Handling slice:** H081 (`bar_verify`, `ready_poll`).

## FM-05 — Step omitted / orchestrator bypassed (OBSERVED via test hook)

- **Symptom:** `HailbruError[StepOmitted]` naming the skipped step; boot
  fails.
- **Register signature:** none — the failure is procedural.
- **Likely cause:** test hook (`--omit-step`) or a future caller
  invoking steps out of order.
- **Recovery:** none needed — the failure IS the safety behavior; fix
  the caller. The CLI wrapper restores D3hot on this path too.
- **Handling slice:** H081. Evidence: `--omit-step bar_verify` →
  StepOmitted, device left in D3hot (2026-10-10).

## FM-06 — sysfs power_state file disagrees with PMCSR (OBSERVED)

- **Symptom:** `/sys/.../power_state` reads "D3hot" while PMCSR[1:0]=0
  and BAR0 reads are coherent.
- **Register signature:** PMCSR=0x2008, BAR0+0x0098=0x1e60 (5/5), file
  says D3hot.
- **Likely cause:** NOT a device fault — the kernel's PCI-core
  bookkeeping does not track manual PMCSR writes (measured 2026-10-10).
- **Recovery:** ignore the file for post-transition verification; use
  PMCSR readback + functional BAR probe (`pm_assert_state` does this).
- **Handling slice:** H083 (documented in `hailbru/pm.mojo`).

## FM-07 — irq_status bit23 time-dependent (OBSERVED)

- **Symptom:** BAR0+0x018C reads 0x00000000 ~1ms after D0 entry but
  0x00800000 ~200ms+ later; stable across consecutive reads once set.
- **Register signature:** bit 23 (0x00800000) only.
- **Likely cause:** device-side status settling after the PM transition
  (or vendor-driver poll activity) — not read-and-clear (4 consecutive
  reads all 0x00800000, 2026-10-10).
- **Recovery:** none — mask bit 23 in golden comparisons
  (`KNOWN_VOLATILE`, mask 0xFF7FFFFF). Do not assert on it in ready_poll.
- **Handling slice:** H082/H096 (volatile-mask mechanism).

## FM-08 — Concurrent access contention (OBSERVED via test)

- **Symptom:** `HailbruError[DeviceBusy]` naming the holder PID.
- **Register signature:** none — the failure is at the guard layer.
- **Likely cause:** two Aesir processes (e.g. a soak run and an
  interactive probe) racing the device.
- **Recovery:** wait for the holder or coordinate; never bypass the
  lock file. Stale locks (dead PID) are reclaimed with a warning.
- **Handling slice:** H092. Evidence: `guard-selftest` — contention +
  stale reclaim green (2026-10-10).

## FM-09 — Surprise device removal (SIMULATED per H091 criterion)

- **Symptom:** `HailbruError[DeviceRemoved]` within 1s of the mapping
  going away; process exits cleanly, fds/mappings released.
- **Register signature:** N/A — the mapping itself is gone.
- **Likely cause:** in production: HAT unseated, PCIe hot-unplug event,
  or operator removal. Simulated by severing an emulated BAR mapping.
- **Recovery:** release the session; re-run discovery before any new
  session; do not reuse the old mapping.
- **Handling slice:** H091. Evidence: `removal-selftest` —
  DeviceRemoved in 0ms, fd count 4→4 (2026-10-10).

## FM-10 — Config-space read failure (HYPOTHESIZED)

- **Symptom:** `HailbruError[ConfigReadFailed]` — short/failed read of
  `/sys/.../config`.
- **Register signature:** none readable.
- **Likely cause:** device dropped off the bus (link down), sysfs node
  permissions changed, or the BDF is stale after re-enumeration.
- **Recovery:** re-run `discover`; if the device is gone from the
  census, treat as FM-09.
- **Handling slice:** H061 (discovery) + H081 (`read_initial_state`).

## FM-11 — Firmware boot timeout (PARTIALLY OBSERVED 2026-10-10)

- **Symptom:** `HailbruError[FwError]` — boot step triggered but no
  BOOT_IRQ within budget (observed: stage-less soft-reset test, 5 s
  wait, MSI arrived but bit 24 not set).
- **Register signature:** 0x018C without the expected completion bit;
  channel bitmaps (0x0400/0x0500) stuck at 0.
- **Likely cause:** completion arrived as a different interrupt source,
  or the firmware did not process the trigger.
- **Recovery:** re-verify blob SHAs, re-program ATR windows, retry the
  stage; persistent → capture full dump for the operator.
- **Handling slice:** H074/H075/H076 (F3-4) — unblocked 2026-10-10;
  `probe fw-boot` implements the wait with `IrqTimeout`.

## FM-12 — Golden-map drift (register deviation in production)

- **Symptom:** `regdiff` reports a genuine deviation (volatile-masked
  bits excluded); VÖRÐR drift detector emits a drift event.
- **Register signature:** the named register, got vs expected (masked).
- **Likely cause:** firmware behavior change after an update, device
  aging/fault, or — most suspicious — an unexpected writer (another
  driver or process touching registers).
- **Recovery:** investigate before dismissing: 3 consecutive deviating
  dumps → file a DEVLOG anomaly; check for unexpected bus masters;
  re-baseline the golden map only with operator approval and a stated
  reason.
- **Handling slice:** H096 (golden map), H097 (drift detector).

## FM-13 — Thermal excursion (HYPOTHESIZED)

- **Symptom:** SoC temperature rising >15°C across a bring-up soak
  (H094), or the H087 health hook reporting out-of-range samples.
- **Register signature:** none on-device (no die-temp register
  readable); host proxy only.
- **Likely cause:** inadequate HAT cooling, ambient temperature, or
  (post-F3) heavy inference load.
- **Recovery:** file a thermal caution in the DEVLOG with a proposed
  mitigation slice (active cooling, duty-cycling); do not continue
  unattended soaks under caution.
- **Handling slice:** H094 (measured ΔT=3.3°C over 100 rapid cycles —
  no caution, 2026-10-10).

## FM-14 — Privilege loss mid-run (HYPOTHESIZED)

- **Symptom:** `HailbruError[PrivilegeRequired]` — config write or BAR
  mmap refused.
- **Register signature:** none.
- **Likely cause:** sudo timeout/ticket expiry during a long soak, or
  the session dropped root.
- **Recovery:** the harness aborts with the register dump attached
  (H084); re-authenticate and resume — the bring-up is idempotent, so
  resuming is safe.
- **Handling slice:** H084 (fail-closed abort), H092 (guard re-entry).

## FM-15 — UIO new_id write-only gate (OBSERVED 2026-10-10)

- **Symptom:** `HailbruError[MechanismUnavailable]` — "uio_pci_generic
  not registered" even though the module is loaded.
- **Register signature:** none (sysfs).
- **Likely cause:** the gate checked `new_id` with O_RDONLY; `new_id`
  is write-only (0200) so the open fails. Fixed: check the driver
  directory itself.
- **Recovery:** code fix (done); no device impact.
- **Handling slice:** H065.

## FM-16 — UIO new_id auto-bind race (OBSERVED 2026-10-10)

- **Symptom:** `HailbruError[OsError]` — short write to `.../bind`
  (the kernel auto-binds on `new_id`, so the explicit bind races).
- **Register signature:** none (sysfs).
- **Likely cause:** writing a dynamic ID triggers the driver core to
  bind immediately; the follow-up `bind` write then fails.
- **Recovery:** check the driver link first; skip the explicit bind
  when already bound; tolerate the race on write. Re-registering an
  ID returns EEXIST (17) — tolerated.
- **Handling slice:** H065.

## FM-17 — IRQ "nobody cared" on unbind/rebind (OBSERVED 2026-10-10)

- **Symptom:** kernel `irq 37: nobody cared` + `Disabling IRQ #37`
  during a UIO→hailo1x transition.
- **Register signature:** none (kernel IRQ layer).
- **Likely cause:** the device's legacy INTx line fires while no
  driver owns it (between unbind and rebind). IRQ 37 is the PCIe
  PME/AER line, not the Hailo MSI — no lasting effect (the device
  uses MSI).
- **Recovery:** none needed; the kernel re-enables on next bind.
  Minimize the window by rebinding promptly.
- **Handling slice:** H065/H069.

## FM-18 — VFIO unusable without IOMMU group (OBSERVED 2026-10-10)

- **Symptom:** VFIO framework live (`/dev/vfio/vfio`, dmesg v0.3) but
  `vfio-pci` cannot bind 0001:01:00.0 — no `iommu_group` symlink;
  CONFIG_VFIO_NOIOMMU is not set.
- **Register signature:** none.
- **Likely cause:** the BCM2712 PCIe RC is not behind the ARM SMMU
  (SMMU serves platform devices: codec, ISP).
- **Recovery:** use the UIO path (H065). A device-tree change
  attaching PCIe to the SMMU is operator/boot-config territory.
- **Handling slice:** H064 (re-scoped to UIO).
