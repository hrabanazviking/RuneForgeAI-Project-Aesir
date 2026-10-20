# Exact RPC descriptor and completion accounting

Date: 2026-10-19. Contract: `TASK_hailo10h_native_rpc_roundtrip.md`, host
portion of slices 2–3. Actual DMA launch is not yet claimed.

`SocRpcProgress` owns the host accounting for one request/reply pair. D2H
must be posted before H2D. Each launch count must equal the exact aligned
2068-byte extent's descriptor count, within the usable ring capacity. For
512-byte pages this is five. Positive-but-wrong counts are refused.

IRQ records count completed transfers, not descriptors. Each owned direction
has one outstanding transfer. Both directions must report one completion;
empty records and zero-count records make no completion claim. Unowned
engines/channels, wrong masks, duplicate completions, excess counts and
254/255 error/inactive statuses are refused. A complete snapshot is validated
before host progress changes. These rules come from the previously observed
reference facts and licensed installed UAPI behavior, not invented opcodes.

Owned storage now arms a pending-transfer state before launch. CPU sync,
read/write and explicit unmap refuse while pending. Only validated completion
or confirmed assigned-channel/file quiescence clears it; successful channel
close now clears this state before mapping release. This does not grant CPU
ownership: explicit sync for CPU is still required after completion.

## Verification and scope

Six host methods pass across 44 native invocations: exact descriptor counts
for nine page sizes, alignment/overflow/ring boundaries, both completion
orders and combined snapshots, zero progress, incorrect positive launch counts
and malformed/error/duplicate/unowned completion refusals. Independent Python
struct-packed IRQ snapshots feed the native Mojo consumer; no driver execution
is fabricated by these fixtures.

A separate actual mapped-session consumer marks software uncertainty without
issuing a transfer. Five unsafe operations are refused before any syscall;
real channel close then unmaps/releases both objects. Its output explicitly
states `software_pending_state_only` and `user_dma_submitted:false`. The
rebuilt storage regression passes eight methods/32 physical child runs.

Evidence: `evidence/rpc-accounting-2026-10-19`. No DMA launch, actual data
completion, cache visibility or source-model execution is proved by this
receipt. Next is the contracted native create/identify/destroy client using
these owners and real directional completions. The broad Mojo/source-model
objective remains unchanged and unfinished.
