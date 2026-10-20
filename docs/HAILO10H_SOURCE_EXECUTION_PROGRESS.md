# Mojo source-model execution progress

The owner's fixed target is Aesir in Mojo running source models that fit the
Hailo-10H hardware. Only the owner may change it. The precompiled-only branch
interpretation was withdrawn in `cd8f397`; historical receipts remain intact.

Active parent: `TASK_hailo10h_mojo_model_execution.md`. Automatically complete,
verify, publish and advance each bounded work slice.

| Work slice | State | Evidence / next action |
|---|---|---|
| Integrated-device envelope | Verified as a host protocol primitive | `HAILO10H_MOJO_HRPC_FRAMING.md`; native tool, independent wire checks and ownership/refusal checks pass. |
| Typed device requests/replies | Verified as a host wire primitive | `HAILO10H_DMA_PROTOCOL_CORRECTIONS.md`; status 1 now matches observed requests, ten independent protobuf methods pass; replies retain status-0 success. |
| Running driver ABI | Verified as a host byte primitive | `HAILO10H_MOJO_SOC_ABI.md`; twelve ioctl values and 84 complete buffers match the installed C UAPI oracle. |
| Owned native driver query | Verified on the actual Pi driver | `HAILO10H_MOJO_DRIVER_OWNER.md`; actual properties/version, identity and observed close/refusal/error/unwind checks. No connection or DMA. |
| PCIe descriptor / connection lifecycle | Verified on the actual Pi driver | `HAILO10H_MOJO_SESSION_LIFECYCLE.md`; actual assigned channels, ordered close, six injected failures and exception cleanup. |
| Reference DMA interface observation | Verified reference facts | `HAILO10H_DMA_OBSERVATION.md`: actual 2068-byte submissions, positive descriptor-count returns, request status 1, complete mapping tuples. Not independent Mojo exchange. |
| Driver transfer-result handling | Verified host/API correction | `HAILO10H_DMA_PROTOCOL_CORRECTIONS.md`; positive count 5 preserved, errno/error distinctions checked, all rebuilt driver/connection lifecycle tests pass. |
| USERPTR mapping / sync ABI | Verified host byte primitive | `HAILO10H_MOJO_DMA_STORAGE_ABI.md`; fifteen ioctl values, twelve methods including 40 new C-object buffer comparisons. |
| Owned RPC host storage | Verified physical mapping/lifetime primitive | `HAILO10H_MOJO_DMA_STORAGE_OWNER.md`; two actual USERPTR mappings, explicit sync, 32 child runs including eleven injected pre-effect faults and two post-effect malformed map replies. No transfer. |
| Native bounded worker | Verified host ownership/deadline primitive | `HAILO10H_MOJO_BOUNDED_WORKER.md`; nine methods/48 native runs, actual monotonic timeouts, native callback, rescue joins and whole-process terminal invariant. |
| Assigned interrupt cancellation | Verified physical empty-channel gate | `HAILO10H_MOJO_ASSIGNED_WAIT.md`; six methods/18 native runs, disable retry, join before cleanup, persistent-cancel terminal path and fresh-session recovery. No launch. |
| Owned RPC byte access | Verified host copy/bounds gate | `HAILO10H_MOJO_RPC_BYTES.md`; independent protobuf/header vectors, actual host allocation, complete zero padding, owned snapshots and seven direct refusals. |
| RPC descriptor / completion accounting | Verified host policy and pending-state gate | `HAILO10H_MOJO_RPC_ACCOUNTING.md`; exact aligned descriptor counts, both directions required, error/duplicate refusal; actual mapped-storage pending guards prove no transfer. |
| Owned DMA transfer / typed RPC | Verified physical message exchange | `HAILO10H_MOJO_NATIVE_RPC.md`; actual USERPTR submissions, exact counts, both completions, synchronized reply bytes and correlation; no model/compute. |
| Independent Mojo read-only device round-trip | Verified on Hailo-10H without HailoRT linkage | `HAILO10H_MOJO_NATIVE_RPC.md`; five methods/36 child runs, repeated create/identify/destroy, timeout and failure cleanup with fresh-session recovery. |
| Source tensor inventory | Verified compiler input snapshot | `HAILO10H_MOJO_SOURCE_INVENTORY.md`; original typed descriptors, exact source extents, no backend registry restriction, UTF-8/NUL preservation; six methods/16 fixture runs, no execution. |
| Semantic operation plan / resource planning | Next active compiler gate | `TASK_hailo10h_source_compiler_plan.md`; bind real source tensors to operations, checked dimensions/lifetimes, resource estimates and explicit unknown backend gates. |
| Executable compute-context generation | Open | Learn and emit real operation/configuration/scheduling data, then prove the first operation on hardware. |
| Source-model execution and architecture breadth | Open | Earn complete model, format, quantization, memory, numerical and lifecycle gates toward the same broad target. |

These rows organize implementation dependencies. They do not reduce the
owner's requested model scope or make host-only primitives count as device
execution. Old catalog-selection work orders must not resume.
