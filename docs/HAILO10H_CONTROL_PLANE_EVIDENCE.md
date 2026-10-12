# Hailo-10H firmware and control-plane evidence matrix

**Roadmap Slice 070 — complete (current baseline 2026-10-12)**

| Signal or claim | Evidence | Status | What it establishes |
|---|---|---|---|
| Endpoint identity | PCI `0001:01:00.0`, ID `1e60:45c4`; identify reports HAILO10H | Observed now | Correct accelerator is enumerated |
| Kernel ownership | PCI sysfs driver link points to `hailo1x` | Observed now | Vendor kernel driver currently owns endpoint |
| Firmware identity | identify reports firmware 5.3.0 release/app and protocol v2 | Observed now | Supported vendor identify operation responds |
| Link state | PCIe 8.0 GT/s ×1; max 8.0 GT/s ×4 | Observed now | Current negotiated PCIe link |
| App-CPU mailbox | H102 trace: command writes/readbacks but no completion, MSI, or response | Historic FAIL | Tested raw app-CPU command path did not complete |
| Core mailbox | H102 final probe: no completion within bounded attempt | Historic FAIL | Tested raw core-doorbell path did not complete |
| Vendor raw FW_CONTROL ioctl | H102 record reports integrated-device operation unsupported | Historic unavailable | That ioctl did not provide a tested raw-command alternative |
| HailoRT/driver v5.4 delta | Public v5.3→v5.4 integrated firmware-control framing/timeout change | Research lead only | Possible interface-specific change; not proof raw mailbox is fixed |
| Æsir raw service-ready signal | No reviewed supported read-only signal found | Unknown | Cannot infer mailbox service readiness from current identify output |
| Æsir command completion | None in current Æsir execution path; prior H102 path failed | Missing/NO-GO | No verified Æsir Hailo operation |
| Hailo die temperature/memory telemetry | Not measured/established in this snapshot | Unknown | No thermal or usable-memory claim |

## Gate interpretation

The identify response proves the installed driver/runtime can retrieve board identity. It does not prove that an Æsir-owned raw command reaches the firmware service, that a generated configuration is accepted, or that any operation executes on the Hailo die. H102 remains the controlling raw-command result until materially new, safe evidence supersedes it. The v5.4 integrated control change is not mapped to the raw mailbox protocol and therefore does not change the gate verdict.

## Slice 070 acceptance

- Supported read-only signals, historic failures, unknowns, and interface claims are separated.
- Vendor identify is not misrepresented as Æsir command reachability.
- The upstream v5.4 change is marked as an unproven research lead.
- No mailbox write, firmware action, driver change, or inference was performed.
