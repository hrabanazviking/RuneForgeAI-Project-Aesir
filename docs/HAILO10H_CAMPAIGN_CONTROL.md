## Slice 125 — Define partial-transfer and timeout behavior (complete; design only)

A future Hailo operation must fail the request if any input transfer reports fewer bytes than its declared length, if a completion is missing/ambiguous, if output length or integrity checks fail, or if the bounded device timeout expires. On failure, mark the operation result invalid, prevent sampling or response publication from incomplete logits, preserve the diagnostic trace, and quarantine any buffer whose device ownership is uncertain until a proven abort/recovery procedure returns it to host ownership. Never retry through CPU inference. A retry is allowed only through the same verified Hailo path and only after safe device state is established.

No Hailo transfer was run for this slice. These rules are conditional acceptance requirements; the existing transport/configuration NO-GO blocks implementation.

Evidence: Slices 085, 097–099, 121–124; docs/smidr/H102_ATTEMPT_RECORD.md.
