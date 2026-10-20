# Atomic model registration implementation trace — 2026-10-10

AES500-234 review at repository revision `5bdf11b7bdd107d7d9ca30eff02358ec9f331dfa`.
No code change was required; the current transaction matches the documented
contract.

## Source identities

- `aesir_engine/cli/storage.mojo` SHA-256:
  `d9448835759f7ebb312f987d629061453383f51d457a7bbcfb4452923a2d175a`
- `aesir_engine/cli/manifest.mojo` SHA-256:
  `9d04c8c22fdd3e7fd87dfa5e9e1d8279eb6c0884524c62a3a3fc0f16e12b7cad`

## Order and mutation review

- Expected digest syntax and positive paired size reject before store-root
  preparation and source reads.
- The store lock is acquired, then `_load_store` reloads the current durable
  catalog before mutation.
- `_ingest_blob_locked` rejects non-regular/empty inputs, copies and hashes the
  opened inode, requires copied byte count to equal the initial observed size,
  and publishes without replacing an existing digest. Existing digest objects
  are fully verified before deduplication.
- Optional expected digest and size compare with measured `BlobRecord` before
  `create_model_from_blob` and catalog serialization.
- Before catalog replacement, errors remove only a blob marked `created`; a
  pre-existing deduplicated object is not selected for rollback.
- `_atomic_write_catalog` stages and syncs bytes, renames, sets the `replaced`
  flag, then syncs the directory. Thus a post-rename sync error keeps the new
  blob because the visible catalog may already reference it.
- `self.store = candidate` occurs only after the transaction finishes without
  error. The caller receives the measured digest/size and `created` flag.

Source order alone does not prove injected syscall failure outcomes; those are
checked by dedicated native harnesses in later release evidence.
