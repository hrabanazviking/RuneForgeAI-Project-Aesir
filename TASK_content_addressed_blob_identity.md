# AES500-221 — content-addressed blob identity contract

## Objective and owners

Define identity semantics for immutable model bytes and the manifest fields that
reference them. Owners are `cli/manifest.mojo` (`validate_manifest_storage_identity`,
`ModelManifest`, `RuneModelStore.create_model_from_blob`) and
`cli/storage.mojo` (`BlobRecord`, `_ingest_blob_locked`,
`DurableModelStore.ingest_model`, `_verify_blob_locked`).

## Identity forms

- `fnv1a64:<16 lowercase hex>` is a recipe fingerprint only and must have
  `size_bytes == 0`; it is not a cryptographic content-integrity digest.
- `sha256:<64 lowercase hex>` is measured immutable blob identity and must have
  a strictly positive byte size.
- Other schemes, wrong widths, uppercase/non-hex digits, negative sizes,
  zero-sized SHA-256 blobs, and nonzero-sized recipe fingerprints reject.
- SHA-256 blob filenames use the lowercase 64-digit digest without the prefix;
  the digest is computed from the exact opened source inode and its measured
  byte count is recorded with the manifest.
- Existing digest objects are verified against the expected content identity
  before deduplication; an identity mismatch rejects without catalog mutation.
- Optional caller-provided expected digest/size are an exact pair. Either both
  are valid and match measured bytes, or admission fails before catalog
  publication. A size without digest is invalid.

## Invariants and exclusions

- Identity validation applies consistently during manifest decode, catalog
  serialization, ingestion, restore, and blob verification.
- Recipe fingerprints are not promoted to SHA-256 and do not establish model
  weight identity.
- This contract does not define catalog transaction atomicity, crash recovery,
  concurrent registration, garbage collection, model quality, or performance;
  those remain separate slices and evidence gates.

## Acceptance

Capture pre-change source hashes and representative valid/invalid identity
vectors; exercise the public manifest/storage seams; add unit evidence for
scheme, width, case, and size pairings; test measured ingestion and verification
through the built native CLI; run adversarial source/blob mutation and
special-file cases; synchronize interface/ledger/TODO/devlog; then run master,
native store, documentation, build/help, push and exact remote/hosted CI checks.
