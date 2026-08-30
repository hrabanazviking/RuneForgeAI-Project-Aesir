# Task: Real GPU/NPU Execution Gameplan — 2026-08-29

## Authorization

Volmarr requested a Markdown gameplan covering all code needed to turn GPU and
NPU execution into real runtime functions and instructed that the result be
pushed to the actual GitHub `main` branch. This task authorizes repository and
official-vendor-documentation inspection, one dated implementation gameplan,
verification of that document against current source and the capability
ledger, commits, and pushes. It does not authorize accelerator implementation,
capability promotion, file deletion, or claims of unobserved hardware results.

## System Statement

Project A.E.S.I.R. currently has a verified CPU inference slice and explicit,
fail-closed GPU/NPU gateway surfaces. Runtime-library loadability, accelerator
enums, host-backed buffer descriptors, and sequential host sharding do not
constitute physical acceleration. Real execution requires observed devices,
owned device contexts and memory, explicit transfers or proved shared-memory
mapping, a device kernel or compiled graph, synchronization, readback, parity,
cleanup, model integration, and reproducible evidence on named hardware.

## Owning Domain

- `aesir_engine/core/*_gate.mojo` — vendor discovery and execution boundaries
- `aesir_engine/core/mimir_well.mojo` — memory and topology ownership
- `aesir_engine/core/compute.mojo` — compute dispatch
- `aesir_engine/core/inference.mojo` — model-integrated execution
- `aesir_engine/aesir.mojo` and `aesir_engine/config.mojo` — configuration
- `aesir_engine/tests/` — executable proof
- `.github/workflows/` — hosted and hardware-runner evidence
- `CAPABILITY_LEDGER.md` and `TODO.md` — canonical maturity truth

## Desired End State

Create `GPU_NPU_REAL_EXECUTION_GAMEPLAN_2026-08-29.md` containing:

1. an evidence-backed statement of the current accelerator boundary;
2. a precise definition of real GPU/NPU execution and prohibited substitutes;
3. the common ownership, memory, synchronization, dispatch, error, and
   configuration contracts required before vendor work begins;
4. backend-specific implementation tracks for CUDA, Metal, AMD HIP/ROCm,
   Intel Level Zero, and realistic vendor NPU routes;
5. a staged file-by-file work order from physical discovery through genuine
   end-to-end model inference;
6. unit, parity, integration, hardware, failure, CI, and performance proof
   gates tied to the canonical capability ledger;
7. a reviewable commit-and-push sequence that preserves fail-closed behavior
   until each independently proved slice is complete.

## Invariants

- CPU execution remains the reference oracle and supported fallback only when
  the user selects or explicitly permits it.
- A requested accelerator never silently falls back to CPU.
- Library presence is not physical device discovery.
- Host allocation, pointer slicing, or host `mmap` is not device memory or
  accelerator zero-copy.
- A backend is not promoted without evidence from its named physical hardware.
- NPU integrations use supported vendor deployment artifacts; arbitrary GGUF
  execution is never promised where a vendor requires a compiled graph.
- No fabricated device, benchmark, compatibility, test, fixture, or CI result
  is permitted.
- No file, function, model, asset, fixture, or historical record is deleted.

## Verification Plan

- trace all existing GPU/NPU gates, buffers, topology, dispatch, CLI, and tests
- reconcile the plan with `CAPABILITY_LEDGER.md`, `TODO.md`, and current status
- verify unstable vendor API recommendations against primary documentation
- check every milestone has an owner, failure boundary, and acceptance gate
- run the repository documentation/consistency gates and `git diff --check`
- commit, push to `origin/main`, and observe the associated hosted CI result

## Completion Boundary

This task produces the implementation plan only. It must describe the complete
path to genuine execution without representing planned code or unavailable
hardware evidence as implemented. Accelerator capability statuses remain
unchanged until later implementation tasks satisfy their physical proof gates.

## Implementation Evidence

- `GPU_NPU_REAL_EXECUTION_GAMEPLAN_2026-08-29.md` records the audited current
  boundary, real-execution definition, common architecture, existing-surface
  corrections, CUDA-first GPU sequence, vendor-specific NPU tracks, file
  ownership, test matrix, hardware CI, error contract, commit sequence, and
  ledger promotion gates.
- Live target selection observed one NVIDIA RTX 2060 Max-Q through `nvidia-smi`;
  no GPU/NPU capability status was promoted from that observation alone.
- Current vendor and Mojo/MAX API recommendations were checked against primary
  documentation and remain bounded by the repository's exact dependency lock.
- No runtime code, model, fixture, asset, function, or historical record was
  deleted, moved, fabricated, or represented as implemented.
