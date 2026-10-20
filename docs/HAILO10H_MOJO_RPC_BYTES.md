# Owned RPC message byte access

Date: 2026-10-19. Contract: `TASK_hailo10h_native_rpc_roundtrip.md`, slice 1.

The native `SocRpcStorage` now copies CPU-owned bytes into its logical
2068-byte message extent and returns independent owned snapshots. Writes clear
all unused bytes, including stale bytes from a prior message. Empty writes
clear the logical extent. Bounds and CPU ownership are checked before access;
refused oversized writes preserve existing bytes. Closed storage refuses even
empty access. This implementation neither opens a driver nor submits DMA.

The host native consumer uses actual anonymous page-aligned allocation.
Four methods pass over 38 native child runs: fourteen create/identify/destroy
frames built with independent google.protobuf messages and struct-packed
headers, 22 full-range/seeded byte vectors, seven direct bounds/ownership
refusals plus alias/cleanup checks, and CLI oversized-input refusal. Snapshot
bytes survive replacement/clear and storage destruction. The ownership flag
exercise is explicitly host state proof, not a simulated DMA completion.

Evidence: `evidence/rpc-bytes-2026-10-19`. Initial compile failure used a tuple
as an iterable; the test consumer now uses a List. Initial CLI expectation
looked for storage bounds, but its existing hex decoder correctly refuses
oversized input earlier; direct storage bounds are checked by the native
seven-refusal guard path. These negative records are preserved.

No CPU access while mapped storage is device-owned is admitted. Actual
pending-transfer state, exact descriptor accounting, directional completion,
cache visibility and native RPC remain next gates. The broad Mojo-owned
source-model execution objective is unchanged and unfinished.
