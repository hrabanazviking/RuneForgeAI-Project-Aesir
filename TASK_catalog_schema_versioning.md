# AES500-211 — catalog schema versioning contract

## Objective and owner

Define the durable model catalog’s supported version and compatibility
transitions. The owner is `cli/storage.mojo`: `CATALOG_FILE`,
`serialize_catalog`, `deserialize_catalog`, `_load_store`, `restore_catalog`, and
`migrate_legacy_catalog`.

## Current schema and transitions

- The sole current durable filename is `catalog.v1`; its header is
  `AESIR_MODEL_CATALOG_V1` followed by an exact `COUNT:n` and exactly n
  hex-encoded manifest `ENTRY:` records.
- Writers serialize v1 only. Readers reject missing, malformed, or unsupported
  version headers; no implicit fallback to legacy data occurs during normal
  load.
- The pre-v1 delimiter format is accepted only by the explicit
  `migrate_legacy_catalog(source)` operation. Migration requires the destination
  to have no catalog, validates all referenced blobs, then atomically writes a
  canonical v1 catalog.
- Backup/restore operates on versioned v1 bytes. Restore fully parses and
  canonicalizes before locking, validates blob references, then atomically
  replaces the destination catalog.
- Existing v1 bytes remain compatible unless a future explicit version change
  defines a migration. Unknown versions fail closed without auto-rewrite.

## Invariants and exclusions

- Version admission happens before record interpretation or destination
  mutation.
- Count, byte, identity, duplicate, and blob invariants remain owned by their
  current validators.
- This task does not add v2, change serialized bytes, or broaden legacy import.
- Cross-version downgrade, backup from future formats, and automatic migrations
  remain unsupported.

## Acceptance

Capture current v1 bytes/source hashes; validate accepted v1 and rejected
unsupported headers; test explicit legacy migration and occupied-destination
rejection; review atomicity and blob-validation ordering; run master, native
model-store tests, documentation checks, and release gate.
