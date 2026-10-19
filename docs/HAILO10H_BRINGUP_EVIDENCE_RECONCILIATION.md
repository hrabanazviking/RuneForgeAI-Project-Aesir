# Hailo bring-up evidence: historical results versus current snapshot

**Roadmap Slice 018 — complete (evidence reconciliation, 2026-10-12)**

## Historical campaign evidence

The repository records a Phase-B gate NO-GO and Phase-C gate PASS. The Phase-C report says firmware reached READY_FW, including real UIO bind/unbind/restore, MSI, ATR programming, 100/100 power cycles, and health/golden checks. These results establish that historical host/device bring-up was achieved in the recorded campaign environment; they do not establish a usable Æsir inference path today.

The later Phase-D assault is the controlling compute evidence. H102 recorded zero mailbox completions through the tested app-CPU and core doorbells, despite the listed hardening attempts. H105–H110 were blocked; H111 ruled NO-GO. The repository expressly states that no on-chip compute was demonstrated and a required operation encoding remained unknown.

## Current machine snapshot

As of 2026-10-12, the endpoint is enumerated as HAILO10H, bound to `hailo1x`, firmware 5.3.0, link 8.0 GT/s ×1. This read-only census matches key identifiers in the historic campaign but does not prove the historic bind/boot/compute state has been repeated. The software OS is Debian 12 Bookworm, which differs from current Raspberry Pi Trixie guidance for the vendor AI HAT+ 2 workflow.

## Status matrix

| Capability | Evidence-backed status |
|---|---|
| PCIe endpoint discovery on this machine | Observed now |
| Vendor stack device identification | Observed now |
| Historical Hailo firmware bring-up/READY state | Reported PASS in prior campaign |
| Current firmware identity | Observed now: 5.3.0 |
| Æsir Hailo dispatch/inference | Missing/not demonstrated |
| Native command completion | Historic H102 FAIL; no current revalidation supersedes it |
| On-chip arithmetic or LLM inference | Not demonstrated; H111 NO-GO |

## Slice 018 acceptance

- Historical Phase-B/C findings are separated from the current census.
- The later H111 NO-GO remains the controlling inference blocker.
- Detection and firmware identification are not presented as compute or LLM inference.
- No historic state was assumed to exist currently; no device mutation was performed.
