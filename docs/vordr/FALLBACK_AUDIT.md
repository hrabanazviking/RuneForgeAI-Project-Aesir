# VÖRÐR Fallback Audit (H159)

Every degradation and fallback path in the codebase, the structured
event it emits at the moment it engages, and the TEST-ONLY proof that
triggering the path produces the event (`prof/vordr/
test_fallback_audit.py` — 100% path coverage, zero silent paths).
L11 (fail closed, degrade honestly) is implemented, not promised.

## VÖRÐR degrade/retry/recovery paths (D6)

| # | Code path | File | Event emitted at engagement |
|---|-----------|------|------------------------------|
| 1 | Stage fast-kernel persistent fault → scalar fallback recompute | vordr/degrade.mojo `run_stage` | `DEGRADED` (names op, cause, fallback) |
| 2 | Transient fault absorbed by retry | vordr/retry.mojo `RetryDriver.execute` | `OpRecovered` (`recovered_after_retries: N`) |
| 3 | Retry budget exhausted → escalate | vordr/retry.mojo | `RetryExhausted` (names PERSISTENT escalation) |
| 4 | Retry scheduled/fired (each attempt) | vordr/retry.mojo | `RetryScheduled`, `RetryFired` (delay vs nominal) |
| 5 | Recovery state transition | vordr/recovery.mojo `transition` | `RecoveryTransition` (from, to, cause) |
| 6 | Staging checksum mismatch | vordr/integrity.mojo `verify` | `IntegrityCorrupt` (buffer, sums) |
| 7 | Re-transfer from pristine copy | vordr/integrity.mojo `retransfer` | `IntegrityRetransferred` (verify: clean) |
| 8 | Shadow kernel-vs-scalar breach | vordr/shadow.mojo `shadow_verify_tile` | `ShadowMismatch` (names layer) |
| 9 | Missed inference heartbeat | vordr/hang.mojo `overdue` | `HangDetected` (names op, budget, overdue_ms) |
| 10 | Thermal threshold crossed | vordr/monitor.mojo | `ThermalWarning` (level, temp, thresholds) |
| 10b | Thresholds file rewritten mid-run | vordr/monitor.mojo | `ThresholdsReloaded` (new warn/crit) |
| 11 | Thermal back under threshold | vordr/monitor.mojo | `ThermalRecovered` |
| 12 | VÖRÐR commands device reset | vordr/reset_ctl.mojo | `ResetCommanded` → `ResetComplete`/`ResetFailed` |
| 13 | Post-reset re-init | vordr/reinit.mojo | `ReinitStarted` → `ReinitReady` (or `ReinitRefused`) |
| 14 | Error register decoded | vordr/errdecode.mojo | `RegisterErrorDecoded` (name, severity, offset, bit) |
| 15 | Watchdog restarts dead child | vordr/watchdog.mojo | `ChildRestarted` (restart #, status, backoff) |
| 16 | Watchdog gives up (budget exhausted) | vordr/watchdog.mojo | `WatchdogGaveUp` |
| 17 | Watchdog itself revived by parent | vordr/watchdog.mojo | `WatchdogRevived` |
| 18 | Supervised-run fault handled | vordr_cli `h158-run` | `FaultHandled` (fault, taxonomy action) |
| 19 | Supervised run halts on fatal | vordr_cli `h158-run` | `SupervisedRunHalted` |

## Cross-domain fallback paths

| # | Code path | File | Observability |
|---|-----------|------|---------------|
| 20 | Backend selection: NPU requested/unavailable → CPU with declared reason | armvegr/backend.mojo `select_backend` | Appends `NPU_UNAVAILABLE_REASON()` to the caller's log list (L11); `BACKEND_NPU` raises named `NpuUnavailable` — never a silent swap |
| 21 | Mechanism selection: VFIO → UIO fallback order | hailbru/mechanism.mojo `select_mechanism` | Returned in `MechReport` (structured); the choice is recorded in bringup logs, not silent |
| 22 | IRQ path: MSI → legacy INTx | hailbru/irq.mojo | Path recorded in IRQ setup report (H065); setup failure raises named `IrqSetupFailed` |
| 23 | GEMM edge tiles: SIMD micro-kernel → scalar tile | armvegr/gemm.mojo `gemm_fp16` | NOT a degradation: shape-driven dispatch, both paths verified bit-exact (H023); no event needed — deterministic, not a fault response |
| 24 | Tokenizer byte-fallback | armvegr/bpe.mojo, sp_tokenizer.mojo | Deterministic decode behavior; unavailable byte-fallback raises a named error — never silent |

## Audit verdict

Paths 1–19 each emit their event synchronously at engagement —
proven by `test_fallback_audit.py`, which triggers every path and
asserts the event in the log. Paths 20–22 are observable through
structured returns/logs (not silent). Paths 23–24 are deterministic
dispatch, not fault responses, and correctly emit no event. **Zero
silent degrade paths.**
