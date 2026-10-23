# Bounded sealed-program USERPTR mapping evidence

Parent receipt:`../../HAILO10H_MOJO_SEALED_PROGRAM_PIN_PROBE.md`.
`archive-identities.json` pins7035 immutable local raw files and actual source/
test/control copies. Paths resolve relative to the repository root on the Pi.
They include failed attempts;never overwrite or rerun their scripts/caches.

`host-census.json` and`permission-oracle.json` are host-only qualification.
Mock driver results are not physical evidence. `physical-results.json` records
the actual13 returned observations with exact-byte SHA256s;full output hex and
traces remain in the pinned raw files. `physical-census.json` audits lifetimes
and the four permitted ioctl kinds. `physical-gate.json` records the pre-call
host gate. No transfer,coherence,numerical or source-model execution is claimed.
