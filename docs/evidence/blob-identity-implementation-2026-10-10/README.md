# Content-addressed blob identity implementation trace — 2026-10-10

AES500-224 source review at `9fdc7fbc340e4b36f03546cadc2b3c00ce918ba5`.
No implementation change was needed; the current owner paths implement the
contract as written.

## Source identities

- `aesir_engine/cli/manifest.mojo` SHA-256:
  `9d04c8c22fdd3e7fd87dfa5e9e1d8279eb6c0884524c62a3a3fc0f16e12b7cad`
- `aesir_engine/cli/storage.mojo` SHA-256:
  `d9448835759f7ebb312f987d629061453383f51d457a7bbcfb4452923a2d175a`

## Reviewed data flow

- Manifest decode calls the shared identity validator before returning a
  `ModelManifest`; catalog serialization calls the same validator before
  encoding an entry.
- Recipe identity requires `fnv1a64:` plus exactly 16 lowercase hex digits and
  zero size. Measured blob identity requires `sha256:` plus 64 lowercase hex
  digits and positive size. Unsupported schemes, width/case errors and
  incompatible sizes fail explicitly.
- `ingest_model` validates optional expected digest/size pairing before taking
  the store lock. Under lock it loads current state, ingests/hashes the opened
  source inode, compares expected digest and size with measured values, builds
  the manifest, and atomically writes the catalog. Failed publication removes a
  blob created by this transaction when catalog replacement has not occurred.
- `_validate_catalog_blobs_locked` validates each manifest identity and verifies
  each SHA-256 blob before restore publication. `verify_model` follows the same
  identity and content verification path.
- Garbage collection validates manifest identities, reference-size consistency,
  and the complete blob namespace before deleting an entry.

This is source-order evidence, not a new independent end-to-end test and not a
claim about crash recovery, which is handled by separate harnesses.
