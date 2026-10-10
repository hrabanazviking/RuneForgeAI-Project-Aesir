# VÖRÐR Error Taxonomy (H145)

Every error condition VÖRÐR can encounter — decoded hardware
conditions (H144), VÖRÐR runtime conditions, and the HAILBRÚ named
errors — classified as **TRANSIENT** (retry with backoff), **PERSISTENT**
(reset + re-init), or **FATAL** (fail closed, operator needed), each
with its classification rationale. The machine-readable table is
`vordr/taxonomy.mojo`; a TEST-ONLY test
(`prof/vordr/test_taxonomy_complete.py`) asserts every named error the
Mojo codebase can raise appears there exactly once.

## TRANSIENT — retry (bounded, exponential backoff + jitter, H156)

- **PciStatus.DetectedParityError** — a single parity error on the bus
  is overwhelmingly a one-off electrical event; the sticky bit is
  cleared by the retry path and the operation is re-attempted. Retry
  first; escalate only if it repeats.
- **PciStatus.MasterDataParityError** — same reasoning: data parity is
  per-transfer; a retry re-transfers.
- **Pmcsr.PmeStatus** — a power-management event request is a signal,
  not damage; acknowledge and retry the interrupted operation.
- **UnknownErrorBit** — an undocumented bit is never ignored and never
  mislabeled (H144), but its blast radius is unknown; the conservative
  first response is retry-and-observe rather than a full reset.
- **HangDetected** — a missed heartbeat usually means a transient
  stall (scheduler hiccup, thermal throttle); the op is retried, and
  the retry policy's exhaustion counter escalates if the hang repeats.
- **IntegrityCorrupt** — a staging-buffer checksum mismatch is
  repaired by re-transfer from the pristine copy (H154); retry the
  consume step afterward.
- **ThermalWarning** — over-temperature is environmental; the correct
  response is back-off-and-retry (or throttle), not a device reset.
- **BadSysfs** — a transient sysfs read failure (e.g. a file
  momentarily unreadable during a driver re-probe); retry.
- **ConfigReadFailed** — config-space reads are idempotent; retry.
- **DeviceBusy** — the session guard names a live holder; retry later.
- **DmaError / DmaLockFailed** — allocation failures are usually
  transient resource pressure; retry with backoff before concluding
  the system is out of memory.
- **IrqTimeout** — a single missed interrupt is retried; the IRQ path
  itself is only reset after repeated timeouts.
- **OsError** — generic OS failures (EINTR-class, transient
  resource shortage) are retried; persistent ones surface through
  repeated failure and escalate.
- **UioError** — userspace-IO hiccups are retried before the bind
  sequence is re-attempted.

## PERSISTENT — reset + re-init (H147/H148)

- **PciStatus.ReceivedMasterAbort**, **PciStatus.ReceivedTargetAbort**,
  **PciStatus.SignaledTargetAbort** — aborts mean the transaction layer itself is
  wedged; retrying the same transaction replays the abort. The device
  must be reset and re-initialized.
- **ShadowMismatch** — the fast kernel disagrees with the independent
  scalar reference beyond the quantization contract: the compute path
  is untrustworthy until the device/pipeline is reset and re-verified.
- **RetryExhausted** — by definition the transient policy has failed;
  the fault is persistent; engage the reset path.
- **ResetFailed** — a reset that did not complete cleanly leaves the
  device in an unknown state; the only safe move is another
  commanded reset cycle (which itself fails closed on repeat).
- **BindError** — driver bind/unbind failures leave the device half
  attached; reset the attachment sequence.
- **BootHang** — a hung boot handshake never resolves by waiting;
  reset and re-run the handshake.
- **DeviceNotReady** — the device failed to reach ready; re-init (and
  reset if re-init alone does not converge).
- **DriverBindingMismatch** — wrong driver bound; unbind/rebind is a
  reset-class operation.
- **FirmwareBootTimeout / FirmwareUploadAborted / FwError** — firmware
  lifecycle failures are reset-class: re-run the boot sequence.
- **IrqSetupFailed** — interrupt plumbing failed; tear down and
  re-establish (a reset of the IRQ path).
- **PowerTransitionFailed** — a power-state transition that did not
  land leaves power management inconsistent; reset the PM cycle.
- **ReadbackMismatch / VendorMirrorMismatch** — the device is not
  answering coherently; reset and re-verify against the golden map.
- **VfioError** — VFIO container/group failures are reset-class.

## FATAL — fail closed, operator needed

- **PciStatus.SignaledSystemError** — SERR# means the device believes
  the platform is broken; continuing risks data corruption. Halt.
- **DeviceRemoved** — surprise removal: there is no device to reset.
  Release mappings cleanly (fd-count verified), halt watchdog-aware,
  and wait for the operator.
- **RetransferFailed** — the pristine copy itself is corrupt: the
  integrity root of trust is gone; no recovery is trustworthy. Halt.
- **ReinitRefused / ReinitFailed** — re-init refused (half-reset
  device) or failed: the device cannot be returned to ready by any
  automated path. Halt.
- **IllegalTransition / BadClassification / HeartbeatViolation /
  SpawnFailed** — VÖRÐR's own logic or supervision is broken; a
  supervisor that cannot trust itself must halt rather than
  supervise badly.
- **BadBdf / DeviceNotFound / MultipleDevices** — configuration is
  wrong; no automated action can pick the right device. Operator.
- **BadThresholds / BadBudgets / BadPolicy / BadShadowPlan** —
  corrupt policy/data files; running on would mean supervising
  against lies. Halt.
- **BarParseFailed / RegOutOfRange / RegUnaligned / UnknownBuffer /
  DoubleFree / WrongMechanism / StepOmitted** — programming errors or
  invariant violations; fail closed, never work around.
- **FirmwareCorrupt / FirmwareMissing** — the firmware root of trust
  is gone (L7: Aesir never fetches firmware); operator restores it.
- **IdentityMismatch** — the device is not who it claims to be;
  continuing would drive the wrong hardware. Halt.
- **MechanismUnavailable / PowerManagementUnsupported /
  PrivilegeRequired** — the platform cannot provide what the recovery
  needs; escalate to the operator instead of degrading silently.
