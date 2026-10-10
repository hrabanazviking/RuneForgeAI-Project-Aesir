# SÓLRÚN AUDIT — Campaign 8 (Vörðr), H141–H160

**Auditor role:** Sólrún (the sun that sees all — honest scope under NO-GO).
**Branch context:** H111 GO/NO-GO gate returned **NO-GO (Compiler Wall)**. There is no
NPU compute: the Hailo-10 is present on the PCIe fabric, healthy, resting in
D3hot on the vendor `hailo1x` driver, but no chip-executable configuration can
be produced without the Dataflow Compiler. All "NPU-referencing" slices below
are audited for honest scope. The verdict per slice: implement the roadmap's
explicit NO-GO treatment, or a strictly-equivalent honest mechanism — never
the GO-branch behavior under a different name.

## H150 — CPU shadow-verification (production sampler)

**Roadmap offers:** GO = shadow NPU layer executions on the CPU path.
NO-GO (explicit): *"this slice instead implements cross-check between two CPU
numerics paths (kernel vs scalar) at the same sampling rate — same surveillance
discipline, honest scope."*

**Audit decision: take the roadmap's explicit NO-GO treatment.**
Reasoning: there are no NPU results to verify — the device has never executed
a single op (H111). Option (a) from the task brief (shadow framework vs an
independent ggml/numpy reference) is a different slice's job (H059R1 already
proved that pattern for the F1 trunk). The honest surveillance equivalent is
exactly what the roadmap prescribes: VÖRÐR samples a configurable fraction of
CPU numerics executions (the optimized kernel path) and re-runs each sampled op
through the *independent scalar path* (e.g. `armvegr.gemm` NEON kernel vs
`gemm_scalar_tile`), comparing within the quantization contract. Seeded RNG,
seed logged, exact-count acceptance (10% of 100 → 10±1), corruption-hook
proves the `ShadowMismatch` event names the layer. If the compiler wall ever
falls, the sampler's `verify(op)` interface is NPU-ready by construction —
the future hook is a new verifier plug, not a rewrite.

## H157 — Error correction: recompute on CPU after NPU fault

**Roadmap offers:** GO = recompute a failed NPU op on the verified CPU path.
NO-GO (explicit): *"this slice implements CPU-pipeline stage retry with the
same observability standard."*

**Audit decision: take the roadmap's explicit NO-GO treatment.**
Reasoning: there is no NPU op to fault and no CPU fallback to engage —
the CPU path IS the compute. The honest equivalent is per-stage retry inside
the F1 CPU pipeline: a stage that faults persistently is retried through the
independent scalar fallback kernel (the same scalar path H150 trusts as its
reference), with a loudly-logged `DEGRADED` event naming the op, the cause,
and the fallback — and the next healthy op returns to the fast kernel (no
sticky fallback). This is degradation under L11 (fail closed, degrade
honestly), not a silent swap.

## H147 — Device reset via HAILBRÚ interface

**Audit decision: REAL, via the proven H083 PM-reset mechanism.**
The task brief says "REAL via the UIO path (proven: bind/unbind, soft reset
survived in C5)". The precise reading: C5's H083 proved a *soft* reset
(PMCSR-asserted D3hot → verify → D0 → coherency) survives on live hardware;
the UIO bind/unbind sequence is the *removal* primitive (H153), not the reset.
VÖRÐR will call a new HAILBRÚ public primitive `reset()` (added to
`hailbru/reset.mojo`, exported through `hailbru.api`) which implements the
H083 soft-reset cycle and nothing else. VÖRÐR never touches registers itself
(L6/L12); the call path is grep-audited in the H147 DEVLOG entry.
Post-reset state is confirmed by golden-map comparison against the H096
re-scoped golden (21 registers: 16 config dwords + 5 BAR0), 50/50.

## H148 — Re-init sequence after reset

**Audit decision: REAL.**
After `reset()`: BAR re-validation (`bars_sane`), firmware-state probe
(honest: the H073 firmware check reports what the *vendor driver* exposes;
whether FW survives reset is determined empirically in-slice by the probe —
documented as observed, not assumed), DMA buffer re-establishment via
`hailbru.dma` create/free, and return-to-ready. A test hook forcing reset
failure must fail closed with a named error (`ReinitFailed`), never proceed
on a half-reset device.

## H151–H154 — PRÓF fault injection (TEST-ONLY Python)

**Audit decision: all REAL faults, never simulated.**
- H151 register errors: injected through a Mojo test-hook register image
  (emulated mapping — H005 §6 forbids live-device writes; the image is
  labeled emulated, honestly). VÖRÐR's H144 decoder + H145 taxonomy +
  prescribed action verified per pattern.
- H152 hangs: real stalled completions via the test hook; H143 detector
  must fire within budget+5s; recovery state machine engages; post-recovery
  inference matches the pre-fault reference.
- H153 device removal: **REAL UIO unbind** (the task brief explicitly
  authorizes this as real and safe; it supersedes the roadmap's weaker NO-GO
  substitute of OOM simulation with reasoning recorded here: real removal
  evidence is strictly stronger than the simulated substitute, and the
  device's healthy rest state (hailo1x, D3hot) is untouched by a brief
  unbind-rebind since the F1 CPU engine never depends on the device). The
  H091 removal path must engage: named `DeviceRemoved`, clean mapping
  release, watchdog-aware halt, no segfault. Device left sane
  (hailo1x rebound, D3hot) after every run — verified by driver-link check.
- H154 DMA corruption: REAL bit flips in host-side staging buffers
  (NO-GO branch per roadmap); 500/500 caught by the integrity layer before
  compute consumes the data (escape count = 0), re-transfer per taxonomy,
  re-transferred data verifies clean.

## H141–H146, H149, H155, H156, H158–H160

**Audit decision: apply directly** to the F1 CPU engine + device health.
H141's H087-hook relocation (move, not copy) is executed with the H087 DEVLOG
entry updated. H142's "device temperature" is the H087 honest position:
the Hailo-10 die temperature is NOT readable on the current kernel — the
thresholds file documents Pi SoC (calibrated millidegree Celsius, per sysfs)
as the host proxy and device-die as unavailable; the roadmap's "via HAILBRÚ
registers" is satisfied by the BAR0/PMCSR health registers HAILBRÚ *can*
read, with the gap stated, not filled.

**Signed:** Sólrún, 2026-10-10.
