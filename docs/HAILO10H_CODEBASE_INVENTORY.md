# Hailo-10H source and evidence inventory

**Roadmap Slice 013 — complete (read-only code/documentation inventory)**

## Existing Æsir implementation surface

- `aesir_engine/core/mimir_well.mojo` reserves `NPUBackendType.HAILO_10`; the enum value is metadata, not Hailo device execution.
- `aesir_engine/aesir.mojo` rejects NPU-enabled runtime configuration and raises for NPU engine execution.
- `aesir_engine/core/compute.mojo` raises for NPU execution; no physical Hailo kernel is launched.
- `aesir_engine/tests/test_npu_realm.mojo` and `aesir_engine/tests/test_npu_edge.mojo` cover scaffolding/boundary behavior; test names do not prove Hailo inference.

## Prior Hailo research and attempt artifacts

- Transport/config research: `smidr/mailbox.mojo`, `smidr/descriptor.mojo`, `smidr/config_gen.mojo`, and diagnostic tools under `smidr/tools/`.
- Attempt evidence: `data/smidr/first_command_trace.json`, descriptor/config artifacts under `data/smidr/`, and `docs/smidr/H102_ATTEMPT_RECORD.md`.
- Protocol/design studies: `docs/plunder/HAILO_COMMAND_QUEUE.md`, `docs/plunder/HAILO_PCIE_TRANSPORT_GUIDE.md`, `docs/plunder/HAILO_CONFIG_SURFACE.md`, and `docs/plunder/HAILO_FW_LOAD_REGISTERS.md`.
- Authoritative gate and downstream historical records: `docs/smidr/PHASE_D_GATE.md`, `docs/smidr/C6_REVIEW.md`, and `CAPABILITY_LEDGER.md`.

## Important status distinctions

- Descriptor/config generation artifacts are not proof of device acceptance or execution.
- A live BAR write/readback is not proof of command completion or LLM inference.
- Hailo device detection through the installed driver is not Æsir Hailo inference.
- Existing CPU fallback artifacts are historical project work and out of scope for this Hailo campaign.

## Slice 013 acceptance

- Hailo-related source, test, evidence, and documentation locations were inventoried read-only.
- Reserved types, probes, generated descriptors, and actual device execution are distinguished.
- H111 remains the authoritative Phase-D outcome unless new evidence supersedes it.
- No code, device state, or CPU inference path was changed.
