# Model catalog schema implementation trace — 2026-10-10

AES500-214 source review of the existing v1 implementation. No runtime changes
were needed: the reviewed owner paths match the contract and exposed interface.

## Source identities

- Revision reviewed: `75904796033cae164e3ac5349a4502a03c82bef6`
- `aesir_engine/cli/storage.mojo` SHA-256:
  `d9448835759f7ebb312f987d629061453383f51d457a7bbcfb4452923a2d175a`
- `aesir_engine/cli/manifest.mojo` SHA-256:
  `9d04c8c22fdd3e7fd87dfa5e9e1d8279eb6c0884524c62a3a3fc0f16e12b7cad`

## Owner-path trace

- `serialize_catalog` emits only the v1 header, exact key count, and one
  hex-encoded manifest record per key; it rejects missing/duplicate keys,
  invalid storage identity, key/manifest mismatch, count overflow, and encoded
  payload above 16 MiB.
- `deserialize_catalog` admits the v1 header before count or record decoding,
  validates the decimal bounded count and exact record count, decodes each
  record and rejects malformed records and duplicate normalized identities.
- `_load_store` maps a missing/empty catalog to an empty in-memory store; any
  present nonempty bytes must pass `deserialize_catalog` with no legacy fallback.
- `restore_catalog` parses and reserializes the backup before taking the store
  lock, then validates referenced blobs before atomic catalog replacement.
- `migrate_legacy_catalog` uses the legacy parser only on this explicit path,
  serializes the candidate as canonical v1, requires a catalog-free destination,
  validates blob references, then atomically writes.

This review establishes source ordering and local code behavior, not a filesystem
crash guarantee, concurrency property, or external legacy compatibility claim.
Those require their dedicated lifecycle and crash evidence suites.
