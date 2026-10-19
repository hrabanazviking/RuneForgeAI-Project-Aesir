# Mojo source-model execution progress

The owner's fixed target is Aesir in Mojo running source models that fit the
Hailo-10H hardware. Only the owner may change it. The precompiled-only branch
interpretation was withdrawn in `cd8f397`; historical receipts remain intact.

Active parent: `TASK_hailo10h_mojo_model_execution.md`. Automatically complete,
verify, publish and advance each bounded work slice.

| Work slice | State | Evidence / next action |
|---|---|---|
| Integrated-device envelope | Verified as a host protocol primitive | `HAILO10H_MOJO_HRPC_FRAMING.md`; native tool, independent wire checks and ownership/refusal checks pass. |
| Typed device requests/replies | Verified as a host wire primitive | `HAILO10H_MOJO_HRPC_DEVICE_MESSAGES.md`; native tool and ten independent protobuf-backed test methods pass. |
| Running driver ABI | Verified as a host byte primitive | `HAILO10H_MOJO_SOC_ABI.md`; twelve ioctl values and 84 complete buffers match the installed C UAPI oracle. |
| Owned native driver query | Verified on the actual Pi driver | `HAILO10H_MOJO_DRIVER_OWNER.md`; actual properties/version, identity and observed close/refusal/error/unwind checks. No connection or DMA. |
| PCIe session ownership / cleanup | In progress | Owned descriptors and assigned channels, then bounded transfers and complete cleanup. |
| Independent Mojo read-only device round-trip | Pending session work | Must identify the actual device with response correlation and complete cleanup. |
| Source-model compiler representation / resource planning | Existing parsers; compiler connection open | Connect real source metadata/tensors to owned lowering inputs and resource estimates. |
| Executable compute-context generation | Open | Learn and emit real operation/configuration/scheduling data, then prove the first operation on hardware. |
| Source-model execution and architecture breadth | Open | Earn complete model, format, quantization, memory, numerical and lifecycle gates toward the same broad target. |

These rows organize implementation dependencies. They do not reduce the
owner's requested model scope or make host-only primitives count as device
execution. Old catalog-selection work orders must not resume.
