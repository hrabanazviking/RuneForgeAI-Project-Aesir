# Native Content-Addressed Model Store

Project Aesir has a restart-safe local catalog for validated Modelfile recipes
and immutable model-byte blobs. It is implemented in Mojo and used by separate native CLI processes. The
default root is `.aesir/models`; an explicit configuration file can select a
different safe relative POSIX path through `storage.model_store_path`.

```bash
aesir create stheno:roleplay --modelfile Modelfile
aesir create stheno:stored --modelfile Modelfile --model ./model.gguf
aesir verify stheno:stored
aesir pull owner/repo model.gguf --revision COMMIT --sha256 DIGEST --size BYTES \
  --name stheno:pinned --config aesir.config.json
aesir list
aesir list --format json
aesir show stheno:roleplay
aesir cp stheno:roleplay stheno:backup
aesir rm stheno:roleplay
aesir gc
```

Every command also accepts `--config <path>`. `--format text|json` applies to
`list` and `show`. Unknown, duplicate, missing, or command-inapplicable options
fail before a mutation.

Recipe-only `create` parses the Modelfile and records its recipe without
pretending that `FROM` bytes were inspected. `create --model <path>` additionally
opens a nonempty seekable source without following its final symlink, copies
the exact opened inode into staged owner-only storage, computes SHA-256 over
that descriptor, records the exact copied size, and publishes
`blobs/sha256/<digest>` without replacement. Re-importing identical bytes
verifies and shares the existing blob. `verify` reopens the addressed blob and
checks both its size and full SHA-256. Quantization, architecture dimensions,
and modification time remain `unknown` until a loader supplies measured values.
Catalog decoding and serialization enforce the identity/size coupling: recipe
fingerprints are exactly 16 lowercase FNV-1a hex digits with size zero, while
stored blobs are exactly 64 lowercase SHA-256 hex digits with positive size.

The Linux catalog and blob writer are bounded by their source files and
versioned metadata. Writers reload while holding an
exclusive directory lock, write a same-directory temporary file, synchronize
it, atomically replace `catalog.v1`, and synchronize the directory. Catalog and
configuration reads reject final symlinks; Modelfile reads are capped at 1 MiB
and also reject final symlinks. Created directories request mode `0700` and
catalog files request `0600`. WSL files stored on a Windows-mounted filesystem
remain subject to that mount's Windows ACL and metadata behavior.

Blob hashing invokes `sha256sum` with an argv vector and no shell. The child
inherits a duplicate of the exact open descriptor and reads it through procfs,
so hashing does not resolve a replaceable caller path. Publication uses
`linkat` under the locked store directory. If catalog publication fails, a blob
created by that transaction is removed and the directory is synchronized.
`cp` shares the digest. `rm` removes only the manifest; `gc` performs the
separate destructive storage sweep.

Garbage collection reloads the catalog while holding the same exclusive store
lock used by imports and catalog commits. Before the first deletion it validates
every catalog blob reference and exact size, enumerates the SHA-256 directory
with NUL-delimited filenames, and rejects unknown names, symlinks, directories,
FIFOs, missing references, and inconsistent sizes. It then removes only canonical
64-lowercase-hex blobs that have no manifest reference plus strictly shaped
`.ingest.<pid>.<attempt>.tmp` remnants, synchronizes the directory, and reports
scanned/referenced/removed/stale/reclaimed counters. A failure after deletion has
started can leave some unreachable files for the next idempotent run, but cannot
delete a catalog-referenced blob based on the validated snapshot.

Pinned public Hub downloads accept `--name <name[:tag]>` and optional
`--config <path>`. The CLI validates the selected store before transfer, then
copies and remeasures the downloaded inode under the store lock and requires
the pinned SHA-256/size before catalog mutation. The caller-selected download
destination remains present, so this mode currently retains both the download
and protected store copy. See the [live fixture evidence](evidence/hf-pull-store-2026-09-02.md).

The built-binary harness `scripts/test_native_model_store.py` proves empty
startup, separate-process persistence, JSON output, create/show/copy/remove,
exact digest/size, full verification, deduplication, six concurrent imports
without lost catalog updates, same-size corruption, missing blobs,
failed-mutation rollback, native Linux permissions, final-symlink rejection,
fail-before-delete directory validation, unreachable-blob collection, stale-stage
cleanup, exact reclaimed-byte accounting, and referenced-blob retention.

Authenticated/resumable transfer, store-aware staging without a redundant
caller destination, systematic injected crash recovery at every filesystem
boundary, a live process registry,
`ps`/`stop`, authenticated downloads, resume, and `push` remain unfinished and
fail closed where commands exist.
