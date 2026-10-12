## Slice 127 — Define cache-coherency assumptions and evidence gate (complete; unverified)

A host/device data path must prove when input writes become visible to Hailo, when Hailo output becomes visible to the host, which synchronization primitive or memory mapping enforces each transition, and whether cache maintenance is implicit or explicit for the exact SoC, PCIe endpoint, driver, and buffer class. The contract must also cover partial lines, alignment, barriers, and error paths. Coherency cannot be inferred from ARM64 pointer access, BAR mappings, or successful DMA allocation.

Current census and H018 note that the system lacks an IOMMU and userspace cannot perform the required privileged cache maintenance directly. There is no proven Æsir DMA path or public raw coherency contract in scope. Status: **UNKNOWN; blocks data movement**. No memory mapping or cache operation was performed.

Evidence: docs/HAILO10H_ACCESS_MECHANISMS.md; docs/HAILO10H_ACCESS_CENSUS.md; CAPABILITY_LEDGER.md H018; H102 attempt record.
