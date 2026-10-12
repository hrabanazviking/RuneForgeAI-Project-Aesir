## Slice 130 — Publish conditional host-to-device data-path contract (complete; BLOCKED)

The Hailo data path requires a verified, compliant chain:

1. Validate Hailo-10H identity and acquire safe exclusive ownership.
2. Allocate bounded host staging memory and verify device-visible DMA addressability, size, alignment, and lifetime.
3. Record tensor metadata, byte length, and input checksum; apply documented cache/transfer synchronization.
4. Submit a documented operation/configuration through a verified transport and record a unique sequence.
5. Await correlated Hailo completion within a bounded timeout; do not infer completion from host calls or register readback.
6. Synchronize device output for host access, verify output size/checksum against the operation contract, then permit downstream sampling.
7. On any error, cancellation, or removal, preserve trace data, invalidate the result, and retain/quarantine buffers until device ownership is safely returned.
8. Release mappings/buffers and restore prior endpoint state only under the reviewed safety procedure; verify restored state.
9. Benchmark transfer and compute separately only after the first real operation passes.

Status: **BLOCKED**. H102 transport did not complete, H019 execution configuration remains unknown, memory/ordering/coherency semantics are unresolved for a compliant raw path, and there is no reviewed current device-mutation safety case. This contract is not executable code and supplies no CPU LLM fallback.

Evidence: Slices 107–110 and 121–129; docs/HAILO10H_ACCESS_MECHANISMS.md; docs/smidr/PHASE_D_GATE.md.
