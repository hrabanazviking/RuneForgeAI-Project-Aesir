# Correlated native Mojo device RPC over owned DMA

Date: 2026-10-19. Contract before implementation.
Parent: `TASK_hailo10h_mojo_model_execution.md`, through
`TASK_hailo10h_soc_session.md` and the storage/completion contracts.

## Fixed consumer and objective

Implement the native Mojo create-device, identify and destroy-device exchange
using the real assigned Hailo-10H session. This transport must carry future
Aesir-generated source-model programs. No vendor model catalog, precompiled-only
policy, inference proxy or host LLM execution is introduced. Completion of this
read-only device RPC is not source-model compiler completion.

## Acceptance slices

1. Add bounded byte write/read APIs to the owned RPC storage. CPU accesses
   require explicit CPU ownership; all writes fit logical size 2068, unused
   bytes are initialized, and no accessor changes storage while DMA owns it.
   Verify independent frame/protobuf bytes and error/refusal behavior first.
2. Enable only assigned channel interrupts **before** posting any transfer.
   Post owned D2H storage before H2D submission. Use the observed non-cyclic,
   pre-mapped USERPTR profile, logical size 2068 and actual descriptor page.
   Validate the returned descriptor count against this exact owned extent and
   ring capacity. Do not treat a positive count alone as completion.
3. Track distinct input/output completion observations from assigned channels.
   Reject error/inactive statuses, unowned channels and impossible counts.
   Join every waiter before cleanup. Apply the verified cancellation policy
   on timeout/error; never free storage with pending DMA. No guessed fragment,
   mailbox, padding or operation opcode is admitted.
4. Sync D2H for CPU only after the corresponding completion. Decode a bounded
   padded frame; require magic, body bounds, message/action correlation and
   remote success before parsing typed device replies. Record unexpected
   messages as evidence and handle only a bounded, specified protocol case.
5. Physically prove create/identify/destroy on this Pi with no model/inference,
   repeated fresh sessions, full cleanup, named negative cases and post-run
   supported identify. Protect private device identifiers in published output.
   Publish exact native/runtime/UAPI fingerprints and raw operational evidence.
6. Then return immediately to source-model representation/lowering, numerical
   recipes, primitive/program configuration and execution. Owner strategy
   proposals remain hypotheses until their numerical and hardware gates pass.

## Scope and constraints

Keep all syscalls, storage ownership and device operations in HAILBRÚ; SMIÐR
consumes typed results. Use already pinned and licensed interfaces, independently
implemented from recorded facts. Preserve negative results and owner uploads.
No kernel/module/firmware changes, reset, unbind/rebind or catalog inference.
Each physical experiment is in a private bounded child. A process deadline is
containment; the actual session retains its proved internal cancellation and
quiescence requirements. Publish this contract before transfer implementation.
