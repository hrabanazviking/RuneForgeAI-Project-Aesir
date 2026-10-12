# Hailo-10H inference policy

**Roadmap Slice 004 — inference-path inventory and target**

## Current repository inventory

The capability ledger currently records narrow CPU and NVIDIA CUDA inference
capabilities. It does not record a verified Hailo/NPU LLM path. This is the
starting-state inventory, not a mandate to extend either existing backend.

## Hailo campaign rule

For every LLM request handled by the Hailo-10H campaign, model execution must
be dispatched to and verified on Hailo-10H. The host processor may perform
ordinary control-plane work such as parsing requests, tokenization when the
chosen backend requires it, process management, and displaying results. It may
not perform LLM inference.

If the Hailo device, runtime, model artifact, or accelerator execution cannot
be verified, the request must fail with a specific diagnostic. No CPU LLM
fallback, CPU shadow inference, or alternate CPU generation route is allowed.
Existing CPU and CUDA inference implementations remain untouched by this
campaign.

## Legacy roadmap warning

The repository's older `HAILO10_200_SLICE_ROADMAP.md` defines a CPU inference
fallback and CPU inference work. That content conflicts with this campaign's
user-authorized scope and must not be used to schedule or implement LLM-on-CPU
work. Hailo feasibility blockers must be surfaced as blockers or trigger a
Hailo-only architecture adjustment; they do not authorize CPU inference.

## Slice 004 acceptance

- The existing CPU, CUDA, and missing Hailo capability states are distinguished
  from the campaign's target state.
- Every LLM inference request in this campaign targets Hailo-10H.
- Device/runtime/model failure is fail-closed, with no CPU LLM fallback.
- Existing CPU/CUDA LLM inference code is explicitly outside this campaign.
