# Mojo PCIe session and typed device requests

Date: 2026-10-19. Status: contracted before implementation.
Fixed parent target: `TASK_hailo10h_mojo_model_execution.md`.

## Current frontier

The owned Mojo RPC frame codec, native inspector and independent wire/API
checks are published at `c01ae775`. The official pinned v5.3.0 host source
shows a distinct integrated-device path: driver-owned descriptor lists,
`soc_connect` to a device service port, assigned input/output channel IDs,
channel activation/transfers, typed create/identify/destroy requests and
ordered session shutdown. This is a transport lead toward source-model
execution; it does not solve compute-context generation.

## Immediate acceptance slices

1. Reconcile the exact running driver ABI and pinned interface definitions.
   Record descriptor-list allocation/free, connection parameters, transfer
   submission/completion and close/cancellation ownership. Recheck licenses
   before reading a newly studied component. Extract interface facts only.
2. Implement the typed device create/identify/destroy wire messages in Mojo,
   consumed by a real native protocol tool and the session client. Preserve
   valid zero-valued handles, bounded protobuf fields, correlated reply IDs,
   remote failure statuses and forward-compatible unknown fields. Validate
   against an independent test-only protobuf/byte oracle and malformed inputs.
3. Implement the driver-backed client using only verified ABI values and
   resources assigned to its own file descriptor/session. No raw mailbox or
   guessed device addresses. Keep device access inside HAILBRÚ.
4. Prove a bounded physical create/identify/destroy round-trip with the actual
   Hailo-10H, then complete resource cleanup and verify subsequent supported
   identification still works. Preserve actual failures and timeout evidence.

Publish and verify each completed acceptance slice before automatically
moving to the next. Partial transport pieces must not be called a physical
round-trip. No precompiled model loading or catalog work belongs in this task.

## Ownership and failure rules

Before a live transfer, prove ownership and cleanup with focused host/API
checks, validate channel/descriptor handles and bound every operation. Mirror
the actual session resource contract: prevent new transfers, quiesce owned
host activity, close/abort the assigned connection, then release pending
transfer storage and descriptor lists. Do not free buffers still owned by
an active DMA operation. If any ABI or ownership fact is unresolved, finish
the independent protocol work and investigate that fact before touching it.

No kernel rebuild, module replacement, firmware change, driver unbind or
reset is authorized by this contract. Normal device-driver session access
for the bounded query stays within the owner's ongoing project authorization.
Host compilation and protocol handling are support work; no CPU/CUDA/cloud
LLM inference or proxy substitution is permitted.

Completion is the independently verified Mojo device-control round-trip and
its cleanup, plus actual source and physical evidence. Then automatically
continue the same source-model target through executable-context generation
and model lowering; a successful control query does not change or complete it.
