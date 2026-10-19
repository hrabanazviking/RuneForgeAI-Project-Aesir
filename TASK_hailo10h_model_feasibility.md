> **SUPERSEDED — OWNER CORRECTION 2026-10-19.** Stop the vendor-catalog
> selection and precompiled-only progression described here. The owner did not
> authorize changing the target to a precompiled-model product. This contract
> is retained as history and does not authorize further implementation.
> Active contract: `TASK_hailo10h_mojo_model_execution.md`.

# Hailo-10H first-model feasibility: slices 141–150

Date: 2026-10-19. Status: contracted before implementation.

## Authorization and continuation

The owner explicitly directs an automatic repeating loop: finish a slice,
verify and push it, then immediately start the next slice without requesting
another continuation. Publish on `docs/cross-cutting-hailo-mission` in the
existing Project Aesir repository. This contract covers phase 15; subsequent
phases require their own scoped contracts while retaining this authorization.

## Current truth and ownership

Slices 139–140 are published at `d88e818`. Physical canonical-CLI acceptance
passes on Hailo-10H using HailoRT/firmware 5.3.0 and the pinned compiled
Qwen2.5-1.5B-Instruct artifact. The 2048-token context and model fingerprint
are measured. Exact word-only formatting is imperfect. Hosted integration
fails in unchanged historical backend-validation tests; no hosted pass is
claimed. Device inference is owned by the in-process HailoRT GenAI boundary.

## Work and acceptance

- 141: inventory formats and architecture families against actual canonical
  dispatch, source and physical receipts; separate historical generic loaders.
- 142: select the official catalog candidate compatible with installed runtime.
- 143: record authoritative model license, revision, tokenizer and architecture.
- 144: estimate memory from documented hardware/model capacity, labeling
  estimates separately from observed device usage.
- 145: pin artifact, tokenizer/source identities, integrity and licensing.
- 146: verify the exact model/runtime pair using physical evidence; repeat
  only where changed inputs or missing evidence require new execution.
- 147: map model layers to the compiled whole-pipeline execution contract;
  distinguish vendor API guarantees from independently observed layer telemetry.
- 148: apply the candidate acceptance/refusal rule to all required operations
  without inventing knowledge of opaque compiled internals.
- 149: document concrete missing capabilities for rejected candidates.
- 150: publish the evidenced candidate decision and outstanding limitations.

Use primary vendor/model sources with immutable revisions where available.
No LLM execution on CPU/CUDA, proxy services or cloud; Python is test/research
support only. No system upgrades, firmware changes, driver rebinding or raw
device mutation are authorized by this contract. Preserve model bytes.

## Files and completion boundary

Expected changes are per-slice `docs/HAILO10H_SLICE_14*.md` receipts, structured
model/profile metadata if needed, roadmap/TODO/ledger/devlog synchronization,
and focused integrity validators only when they have a real consumer.
Each slice receives its own commit and remote publication before the next.
Source/document consistency checks support inventories; physical compatibility
claims require the exact artifact/runtime/device evidence. Publication alone
does not certify broad model quality, portability, performance or release.

When phase 15 finishes, automatically start the next unfinished phase under
a scoped contract. Keep failed acceptance gates visible and work on remaining
independent slices rather than converting missing evidence into success.
