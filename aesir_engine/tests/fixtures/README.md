# Test Fixture Boundary

This is the only approved location for small tracked fixture data. It currently
contains no fixture payloads.

Before adding a payload, register it in the root `fixture_manifest.json` as
exactly one of `synthetic`, `malformed`, or `regression`, with its owner,
purpose, consumer, evidence boundary, license, deterministic construction
record, exact byte size, and SHA-256. The fixture validator rejects unregistered
files, mismatched bytes, unsafe paths, and duplicate identities.

Real model weights and other `external-reference` fixtures remain outside Git.
Their immutable source, checksum, size, license, consumer, and independent
oracle belong in `fixture_manifest.json`; registration does not prove that the
external test executed.
