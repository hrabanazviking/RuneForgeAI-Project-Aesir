# AES500-231 — atomic model registration contract

## Objective and owners

Define the transaction contract for registering measured model bytes in the
persistent catalog. Primary owner is
`cli/storage.mojo::DurableModelStore.ingest_model`, with supporting owners
`_ingest_blob_locked`, `_remove_new_blob_locked`, `_atomic_write_catalog`, and
`cli/manifest.mojo::RuneModelStore.create_model_from_blob`.

## Inputs and result

Inputs are a validated model `name`, stored `modelfile_content`, caller-owned
`source_path`, and an optional expected `sha256:<64 lowercase hex>` plus
positive expected byte size. The result is `BlobRecord(digest, size_bytes,
created)`, where `created` means this transaction published a new blob object.

## Transaction invariants

1. Validate expected digest/size syntax before store mutation or source copying.
2. Acquire the store-root lock and reload the latest catalog under that lock.
3. Open and measure the exact accepted source inode; hash those bytes and
   publish the immutable content-addressed object without replacing an existing
   object.
4. If supplied, compare both expected digest and expected size with measured
   values before candidate manifest/catalog publication.
5. Build the candidate manifest from measured identity, serialize the complete
   candidate, then stage, sync, rename and sync the containing directory through
   the catalog writer.
6. Publish the candidate in-memory state only after the catalog writer succeeds.
7. On pre-rename failure, remove only a blob newly created by this transaction;
   never remove a pre-existing deduplicated object. After rename has made the
   new catalog visible, retain a referenced blob even if directory sync reports
   an error, because visibility is already established and durability is
   uncertain.
8. Return the exact measured record on successful completion. Concurrent writers
   serialize at the root lock and reload prior committed state before mutation.

## Exclusions

This contract does not promise sudden-power-loss durability on every filesystem,
provide distributed locking, define model execution/quality, authenticate an
external hash oracle, or include preferences and backup blob contents. Those
remain separate boundaries.

## Acceptance

Baseline source hashes and observed transaction outcomes; interface evidence for
valid, invalid and optional expected-pair calls; unit coverage for validation
ordering and rollback distinctions; built-CLI integration across registration,
restart and dedup; hostile mismatch, source replacement, concurrent writer and
process-kill evidence; primary/independent review status recorded honestly;
then sync docs, run the master/native/catalog/doc/build gates, push and verify the
exact remote ref and hosted CI.
