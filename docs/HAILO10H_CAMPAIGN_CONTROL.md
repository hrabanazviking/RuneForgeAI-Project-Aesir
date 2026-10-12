## Slice 124 — Define synchronization around device completion (complete; conditional)

For any future submitted operation, the sequence must distinguish host preparation, DMA visibility/synchronization, command acceptance, device completion, output visibility/synchronization, and host reuse. A submission cannot be treated as complete merely because the doorbell write returned. Output cannot be consumed or buffers recycled until the completion identity matches the request and the documented cache/transfer synchronization has succeeded. If synchronization semantics are unknown, execution remains blocked.

Current evidence lacks a successful command completion and a complete public cache-coherency/transfer contract for Æsir. Thus this slice specifies ordering conditions only; it does not add synchronization code or touch the bound endpoint.

Evidence: H102 attempt record; H019 elements 4–7; docs/HAILO10H_ACCESS_MECHANISMS.md; Slices 121–123.
