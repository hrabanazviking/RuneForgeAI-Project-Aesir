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

## FM-11 — Firmware boot timeout (F3-BANKED, HYPOTHESIZED)

- **Symptom:** `HailbruError[FirmwareBootTimeout]` — boot step triggered
  but no completion interrupt within budget.
- **Register signature:** channel bitmaps (0x0400/0x0500) stuck at 0;
  0x018C completion bits never set.
- **Likely cause:** bad DMA addresses (ATR windows misprogrammed),
  corrupt blob (caught earlier by H073 staging verify), or the
  firmware crashed on the on-chip CPU.
- **Recovery:** re-verify blob SHAs, re-program ATR windows, retry the
  stage; persistent → capture full dump for the operator.
- **Handling slice:** H074/H075/H076 (F3-4) — unblocked by
  `docs/hailbru/F3_UNBLOCK_RUNBOOK.md` F3-4.

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
