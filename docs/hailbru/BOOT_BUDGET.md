# Boot-Time Budget (H085)

Official bring-up time budget for the Hailo-10 PM-cycle bring-up
(Campaign 5). All later phases (watchdog timeouts, recovery budgets)
derive from this.

## Raw data

`data/hailbru/boot_times.json` — 30 PM-cycle bring-ups on Mimir
(cycles 0–29 of the H084 100-cycle run, 2026-10-10), each per
`docs/hailbru/COLD_BOOT_DEFINITION.md` option (c).

| Metric | Value |
|--------|-------|
| n | 30 |
| min total | 101 ms |
| max total | 102 ms |
| mean total | 101.8 ms |

Per-step means: `assert_binding` 0.1ms, `read_initial_state` 1.1ms,
`enter_d3hot` 0.2ms, `verify_d3hot` 0.2ms, `enter_d0` 50.1ms,
`bar_verify` 0.0ms, `ready_poll` 0.0ms, `restore_d3hot` 50.0ms.

## Slowest step

`enter_d0` at 50.1ms mean = 49.2% of the total. This is NOT an
unexplained black hole: 50ms of it is the deliberate post-transition
settle delay in `pm_set_state` before the functional verify; the PMCSR
write + readback itself completes in <2ms. `restore_d3hot` carries the
same 50ms settle.

## Budget

Rule (per roadmap): budget = max_observed × 2, rounded up to a whole
second.

- max_observed = 102ms → × 2 = 204ms → **1 second**.

**Official PM-cycle bring-up budget: 1 second.** The H088 hang
detector fires at step budget + 5s; the H093 1000-cycle soak compares
its 99th percentile against this budget.

## Honesty notes

- This budget covers the PM-cycle bring-up (option (c)), not a firmware
  boot — firmware boot timing is F3-banked and will get its own budget
  after the kernel rebuild.
- The 50ms settle delays are conservative; a future slice may tune them
  down with evidence, which would revise this budget.
