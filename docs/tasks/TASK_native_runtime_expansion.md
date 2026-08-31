# Native runtime expansion

**Date:** 2026-08-30

**Roles:** Architect, Forge Worker, Auditor, Scribe

**Authorization:** The user requested real implementations of unfinished
features, broader model/device support, and frequent pushes to `main`.
This explicit integration instruction overrides the older feature-branch
workflow for this task. No deletion of existing user data is authorized.

## Starting point

The runtime executes the pinned CPU Llama F16 fixture and two native CUDA
profiles: Gemma 4 E4B and Llama 3 8B. CUDA sessions select device zero directly,
allocate without a model-level memory admission plan, and expose only greedy
generation. The heterogeneous architecture is a proposal, not an implemented
backend matrix.

## Ordered implementation slices

1. Connect physical CPU/CUDA discovery to `hardware list`; expose a checked
   `compute plan`/`explain` for supported GGUF profiles; use the same memory
   accounting and explicit device selection in actual CUDA sessions.
2. Add validated, deterministic non-greedy generation and session controls to
   the real CUDA chat paths, preserving greedy regressions and device compute.
3. Extend native model/device coverage only with numerical reference checks
   and a real fixture. Reject unsupported shapes, formats and devices before
   execution. Do not introduce external inference engines.
4. Keep current status, public interfaces, capability evidence and reproduction
   instructions synchronized with each implementation milestone.

## Ownership and invariants

- Core owns observed hardware, resource admission, kernels and session state.
- Loader owns GGUF metadata and tokenizer compatibility.
- The facade exposes model inspection/planning and runtime entry points.
- CLI owns options, diagnostic formatting, interactive commands and transcripts.
- Tests own synthetic rejection cases and independent/physical proving scripts.
- A discovered device is not automatically an executable backend. Unknown
  properties stay unknown; no invented speed, memory or compatibility claims.
- Memory planning is a checked snapshot, not a reservation against other
  processes. Recheck immediately before allocation and preserve driver errors.
- Explicit CUDA requests cannot silently fall back to CPU. No history is
  discarded to make a context fit; reset must be requested explicitly.
- Preserve native download, both CUDA profiles, UTF-8 output and pinned CPU
  token parity. Never commit model weights, local paths or generated binaries.

## Evidence gates per milestone

Run meaningful unit/negative cases, the counted master suite, native build,
repository/fixture checks and the deliberate failing runner. Exercise connected
commands on the available Linux CPU/NVIDIA host. Record exact limitations for
other hardware. Push each reviewable verified slice and inspect hosted CI.

## Progress

- Slice 1 implemented: observed hardware CLI, checked model plans, CUDA
  device selection, reserve/host admission and automatic single-shot profile
  detection. Five new counted tests and the physical CLI integration passed
  for both models. Master at that milestone: 152 passed, 0 failed, 1 skipped.
- Slice 2 implemented (2026-08-31): native CUDA sampling, strict CLI controls,
  reset/show/settings and safe interactive admission recovery. All 896 physical
  sampling decisions matched an independent reference; both real models passed
  sampled and greedy replay/reset plus protected transcript checks. Master:
  155 passed, 0 failed, 1 skipped. Pinned CPU parity remains passing.
- Upload milestone implemented (2026-08-31): bounded 64 MiB pinned staging,
  exact-byte CUDA round trips, matching host admission and both model/control
  regressions. Measured host peak RSS substantially reduced on the observed
  setup; master 157 passed, 0 failed, 1 skipped.
- Remaining expansion: broader model fixtures/logit parity, additional physical
  backend implementations, container-aware admission, serving and cancellation.
  These are not declared complete by the tested CUDA improvements.

## Production hardening continuation — 2026-08-31

The user explicitly requested implementing the remaining functions as real,
production-quality code. Continue in independently verified milestones:
container admission; native cooperative cancellation and deadlines; a bounded,
authenticated loopback inference service; then broader model/device evidence.
Do not infer that unavailable hardware or legacy scaffolds are production ready.
Cgroup v2 admission is now implemented and verified under a real 256 MiB scope;
cgroup v1/hidden-ancestor handling, generic CPU admission, cancellation, serving
and broader model/device work remain.

Cancellation milestone implemented: native session deadlines/cancel, public-CLI
SIGINT bootstrap, explicit partial-prefill reset gate and physical recovery on
both models. Master 163 passed, zero failed, one skipped. Serving and broader
model/device evidence remain next; cgroup v1/hidden ancestors and generic CPU
arena admission remain limitations.
