## Slice 128 — Define cleanup after cancellation or device removal (complete; conditional)

On cancellation, timeout, or endpoint removal, mark the request cancelled and stop admitting work. Release host-only allocations immediately only if they are not mapped or device-owned. For mapped/in-flight buffers, require a documented cancellation/abort completion or verified device quiescence before unmapping or freeing. If ownership cannot be proven returned, quarantine the buffer and report a named recovery-required error; do not reuse memory or claim clean recovery. Restore driver ownership only under the reviewed handoff procedure and verify post-state before reporting success.

No cancellation or removal behavior was exercised because Æsir has no verified Hailo submission path. This records required lifecycle behavior only.

Evidence: Slices 097–099, 121, 124–127; docs/HAILO10H_ACCESS_MECHANISMS.md; docs/HAILO10H_COMPONENT_BOUNDARIES.md.
