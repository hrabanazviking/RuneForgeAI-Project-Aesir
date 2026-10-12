## Slice 129 — Specify transfer benchmarks after compute proof (complete; benchmark blocked)

Transfer benchmarks may begin only after a real Hailo compute operation, safe DMA mapping, correlated completion, cache/coherency behavior, and output integrity have passed the GO gate. Report host-to-device transfer, device execution, and device-to-host transfer separately where supported; include warm/cold distinction, tensor sizes/shapes, buffer reuse policy, repeat count, latency percentiles, errors, and device/software identity. Do not label host allocation/copy or a vendor-stack demo as Æsir Hailo performance.

Current status: benchmark work is BLOCKED because no compliant compute or transport path is verified. No benchmark was run and no Pi CPU inference performance is relevant to this plan.

Evidence: Slices 085–089, 107–110, 121–128; docs/smidr/PHASE_D_GATE.md.
