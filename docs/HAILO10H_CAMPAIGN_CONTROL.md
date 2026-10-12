## Slice 121 — Define host/device tensor ownership transitions (complete; conditional contract)

For any future verified operation, a tensor must have one explicit owner at each point: host allocation/preparation → successful transport mapping and device-visible address validation → device-owned while submission is in flight → host-readable only after correlated completion and required synchronization → release only after completion or a proven abort. Ownership must not be inferred from a host pointer or a successful mmap. Every transition needs an observable success/failure result and cleanup rule.

This is a requirements contract only. Current Æsir lacks a proven Hailo DMA mapping and completion path; the endpoint remains under hailo1x. Therefore no buffers were mapped, allocated for Hailo, transferred, or submitted. This does not authorize simultaneous or raw access to the bound device. No CPU LLM execution is part of the contract.

Evidence: docs/HAILO10H_ACCESS_MECHANISMS.md; docs/HAILO10H_COMPONENT_BOUNDARIES.md; docs/smidr/H102_ATTEMPT_RECORD.md; H019 configuration surface.
