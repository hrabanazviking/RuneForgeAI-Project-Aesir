> **OWNER TARGET CORRECTION — 2026-10-19:** Project Aesir must implement the
> Mojo path needed to run source models that fit the Hailo-10H hardware. The
> owner explicitly rejects limiting the product to compatible vendor-precompiled
> models and forbids changing the target. Earlier catalog-only execution rules
> in this document are superseded. Historical precompiled-model receipts remain
> observations, not completion evidence for the owner's actual objective.

# Project A.E.S.I.R. on Hailo-10H

**Mission — roadmap Slice 001 (complete)**

Project A.E.S.I.R. is a local, Mojo-native inference engine built to give its
keeper direct control over model execution and data. This roadmap's objective is
to make Æsir serve supported language models with their inference executed on
the Hailo-10H accelerator. The Raspberry Pi may coordinate requests, handle
the user interface, and perform ordinary non-LLM system work; it must not run
LLM inference as a fallback or alternate execution path. Æsir should report
clearly which model and accelerator are active, fail closed when Hailo-10H
inference is unavailable, and make claims only when they are supported by
evidence from the target hardware.

## Current boundary

The repository currently documents verified local CPU and NVIDIA CUDA model
paths, while Hailo/NPU execution remains a roadmap capability. This mission
records the desired Hailo-10H target; it does not claim that target is already
implemented. Existing CPU and CUDA work is outside this Hailo-only roadmap's
execution scope.

## Evidence basis

This wording reflects the repository's `AGENT_ONBOARDING.md`,
`ENGINEERING_GOALS_AND_BOUNDARIES.md`, `CAPABILITY_LEDGER.md`, and
`HAILO10_200_SLICE_ROADMAP.md`, with the user's explicit Hailo-10H-only
inference requirement applied to the campaign boundary.
