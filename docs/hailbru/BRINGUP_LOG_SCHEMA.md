# Bring-up Log Schema (H089)

Structured bring-up log: one JSON object per line (JSON lines). Every
H081–H088 log is emitted in this schema by `hailbru/bringup.mojo`
(`BringupLog.emit`); the TEST-ONLY validator
`prof/hailbru/test_log_schema.py` enforces it.

## Fields

| Field     | Type    | Required | Meaning |
|-----------|---------|----------|---------|
| `ts_ms`   | integer | yes | Monotonic clock, milliseconds (`os_clock_ms`). Not wall time — durations are comparable, absolute times are not. |
| `step`    | string  | yes | Step name, e.g. `assert_binding`, `enter_d0`, `ready_poll`, `firmware_load`, `restore_d3hot`, or `bringup` for run-level records. |
| `event`   | string  | yes | One of `step_start`, `step_end`, `step_banked`, `error`, `info`. |
| `outcome` | string  | yes | One of `running`, `ok`, `failed`, `banked`. `step_start` always pairs with `running`; `step_end` with `ok`; banked steps emit `step_banked`/`banked`. |
| `dur_ms`  | integer | yes | Step duration in ms; 0 for `step_start`/`step_banked`/`info` events. |
| `detail`  | string  | yes | Free text: register values, state names, banked-step prerequisite citations, error context. |

## Event semantics

- Every real step emits exactly one `step_start` followed by exactly one
  `step_end` (success) or one `error` (failure, after which the run
  aborts — no further steps run).
- F3-banked steps (`firmware_load`, `boot_handshake`) emit a single
  `step_banked` event with `outcome: banked`; the `detail` cites the
  exact unblock prerequisite (F3-4, `docs/hailbru/F3_UNBLOCK_RUNBOOK.md`).
  Banked steps are never silently skipped and never `ok`.
- A run-level `info` record with `step: bringup` closes each log with the
  summary JSON (result, total_ms, ready meaning).

## Example

```json
{"ts_ms": 24549012, "step": "assert_binding", "event": "step_start", "outcome": "running", "dur_ms": 0, "detail": ""}
{"ts_ms": 24549012, "step": "assert_binding", "event": "step_end", "outcome": "ok", "dur_ms": 0, "detail": "driver=hailo1x"}
{"ts_ms": 24549064, "step": "firmware_load", "event": "step_banked", "outcome": "banked", "dur_ms": 0, "detail": "F3-BANKED: needs F3-4 (IOMMU DMA + MSI) after kernel rebuild; see docs/hailbru/F3_UNBLOCK_RUNBOOK.md F3-4"}
```

## Retrofit status (H081–H088)

All H081–H088 logs are emitted by `BringupLog.emit` in this schema —
no retrofit needed, no known deviations.
