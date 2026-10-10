# Campaign 8 Review — Vörðr Robustness (H141–H160)

**Date:** 2026-10-10 · **Engineer:** Yrsa (Muse Spark) · **Device:** Mimir
(homelink-c2ba12, Pi 5, Hailo-10 AI HAT+) · **Branch:** `mimisbrunnr-c8-vordr`

## Verdict: ROBUST

Vörðr — the warden for the F1 CPU engine and Hailo device health — is built,
measured, and proven on live hardware. Every recovery path was exercised with
real faults; every budget was measured, not invented; every fallback is loud.

## Sólrún audit (docs/vordr/SOLRUN_AUDIT_C8.md)

NPU-referencing slices received honest treatment under H111 NO-GO:

| Slice | Decision | Reasoning |
|---|---|---|
| H150 | CPU numerics cross-check | No NPU compute exists; shadow-verification framework verifies F1 SIMD kernel vs independent scalar reference (H059R1's proven pattern). Rejected ggml/numpy option as already-proven. |
| H157 | CPU stage retry via scalar fallback | Honest equivalent: per-operation scalar fallback, loud DEGRADED, never sticky. |
| H147/H148 | REAL via HAILBRÚ `reset()` | New `hailbru/reset.mojo` primitive; C5-proven D3hot→verify→D0 PM-reset cycle + golden compare. Vörðr never touches registers (L6/L12). |
| H153 | REAL UIO unbind | Stronger than the roadmap's OOM-simulation substitute; device left sane (hailo1x rebound, D3hot) after every run. |
| H151–H154 | TEST-ONLY Python, real faults | Register errors, hangs, removal, DMA corruption — all real, never simulated. |
| H142 | SoC proxy documented | Hailo die temp not readable on current kernel; Pi SoC is the documented proxy. |

## Slice results

| Slice | Result |
|---|---|
| H141 monitor | 120/120 samples, max drift 12ms (<1s tol), SoC 43–48.5°C, MonitorStopped, clean exit |
| H142 thermal | Thresholds live-reload proven (Warning→Recovered); die-temp gap documented |
| H143 hang detect | 300ms stall caught in 305ms; 1000 clean ops, 0 false positives; budgets in `data/vordr/hang_budgets.json` (p99×3) |
| H144 errdecode | 50/50 bits; live register poll every supervised iteration |
| H145 taxonomy | 52 names classified exactly once; 62 entries all documented; machine-checked |
| H146 watchdog | 10/10 SIGKILL restarts ≤2.4s; rapid-death backoff 1/2/4/8s; parent-monitor revives dead watchdog |
| H147 reset | 50/50 cycles golden-clean, mean 201ms (real PM-reset via HAILBRÚ) |
| H148 re-init | 50/50 cycles, mean 203ms worst 206ms; hook-fail → ReinitRefused |
| H149 recovery | 3 scenarios + 5 illegal transitions rejected |
| H150 shadow | 10/10 verifications (worst diff 1.43e-06); corruption → ShadowMismatch |
| H151 reg-FI | 11 patterns decoded+classified; live probes: transient→retry, persistent→reset, fatal→halt |
| H152 hang-FI | 20/20 hangs detected+recovered; post-recovery inference matches reference |
| H153 removal-FI | 3/3 stages: DeviceRemoved named, clean release, no crash, device sane, inference coherent |
| H154 DMA-FI | 500/500 corruptions detected, 0 escapes, 500/500 retransferred |
| H155 budgets | transient_retry 1498ms / reset_reinit 426ms / process_restart 44ms (p99×2); 10-sample confirmation ALL BEAT |
| H156 retry | 3 faults absorbed; 6 → RetryExhausted; backoff 109ms vs 100ms nominal |
| H157 degrade | 19 fast + 1 degraded; exactly 1 DEGRADED event; scalar fallback per-op only |
| H158 supervised | 30-min run, seeded faults @ ~1/60s + PRÓF external injections; injected==handled; coherence holds |
| H159 audit | 20/20 degrade/fallback paths emit their events — zero silent paths |
| H160 | this review |

## Measured recovery-time budgets (H155, on Mimir)

| Class | p50 | p99 | Budget (p99×2) | 10-sample confirm |
|---|---|---|---|---|
| transient_retry | 695ms | 749ms | 1498ms | BEATS |
| reset_reinit | 205ms | 213ms | 426ms | BEATS |
| process_restart | 21ms | 22ms | 44ms | BEATS |

Budgets follow measurements, not wishes.

## Fault-injection summary (PRÓF, TEST-ONLY)

- H151: 11 register-error patterns (PCI status, PMCSR, BAR0 IRQ) — all decoded, classified, actioned.
- H152: 20 hang injections — all detected within budget+5s, iteration retried, post-recovery output identical to reference.
- H153: 3 device removals (UIO unbind at prefill/decode/weight-staging) — DeviceRemoved named each time, clean release, hailo1x rebound to D3hot, inference coherent after.
- H154: 500 DMA corruptions — 500 detected, 0 escapes, 500 retransferred clean.
- H158: ~30 seeded faults + 5 external PRÓF injections over 30 min — injected==handled, zero unhandled, zero crashes.

## Bugs found and fixed in-slice

1. **Spawn status propagation:** SIGKILLed child reported as exit(127); now re-raises the signal so the supervisor sees signal(9). Honest audit trail.
2. **h158-run out-dir:** crashed with ENOENT when out-dir didn't exist; now creates it.
3. **Live poll telemetry:** healthy device produced no poll event; now emits RegisterPollClean so the audit has a positive signal.

## Non-claims

- No NPU compute (H111 NO-GO stands). Vörðr guards the F1 CPU engine + device health.
- No Hailo die-temperature telemetry on this kernel (documented; SoC proxy).
- Vörðr never touches device registers (L6) and only hailbru/ touches device nodes (L12).
- Decode remains sampler-bound (~0.18 tok/s); C9's problem, not C8's.

## Verdict rationale

ROBUST because: (1) every recovery path fired on real faults and was measured;
(2) the audit proved zero silent fallback paths; (3) budgets are empirical with
confirmation runs; (4) the device was left sane after every fault-injection run;
(5) failure modes fail closed (fatal → halt, never silent degradation).
