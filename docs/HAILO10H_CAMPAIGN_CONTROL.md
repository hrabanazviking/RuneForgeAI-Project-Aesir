## Slice 122 — Specify transfer-integrity checks and counters (complete; design only)

A future approved Hailo operation record should capture, at minimum: operation/request sequence ID; source tensor byte count and cryptographic digest; mapped device-buffer identity/size/direction; transfer submission and correlated completion status; returned byte count and digest; expected output digest; timeout/error counter; and device/firmware identity. Counters must distinguish allocated, mapped, submitted, completed, failed, and released buffers. A successful host write/read alone must never increment “device completed.”

No live transfer path exists in Æsir, and H102 failed before a command round-trip. These fields specify evidence requirements; this slice creates no telemetry implementation and authorizes no device I/O.

Evidence: H102 attempt record; Slices 084–087 and 121; HAILBRÚ API and H019 config-surface requirements.
