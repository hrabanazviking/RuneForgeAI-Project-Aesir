# Native Recipe Model Store

Project Aesir has a restart-safe local catalog for validated Modelfile recipes.
It is implemented in Mojo and used by separate native CLI processes. The
default root is `.aesir/models`; an explicit configuration file can select a
different safe relative POSIX path through `storage.model_store_path`.

```bash
aesir create stheno:roleplay --modelfile Modelfile
aesir list
aesir list --format json
aesir show stheno:roleplay
aesir cp stheno:roleplay stheno:backup
aesir rm stheno:roleplay
```

Every command also accepts `--config <path>`. `--format text|json` applies to
`list` and `show`. Unknown, duplicate, missing, or command-inapplicable options
fail before a mutation.

`create` parses the Modelfile and records its recipe. It does **not** copy the
GGUF named by `FROM`, calculate a digest over model weights, or infer size,
quantization, dimensions, or modification time. Those fields remain zero or
`unknown` instead of presenting invented observations. `cp` and `rm` operate on
recipe manifests only.

The Linux catalog is bounded and versioned. Writers reload while holding an
exclusive directory lock, write a same-directory temporary file, synchronize
it, atomically replace `catalog.v1`, and synchronize the directory. Catalog and
configuration reads reject final symlinks; Modelfile reads are capped at 1 MiB
and also reject final symlinks. Created directories request mode `0700` and
catalog files request `0600`. WSL files stored on a Windows-mounted filesystem
remain subject to that mount's Windows ACL and metadata behavior.

The built-binary harness `scripts/test_native_model_store.py` proves empty
startup, separate-process persistence, JSON output, create/show/copy/remove,
failed-mutation rollback, native Linux permissions, and final-symlink rejection.

Content-addressed model-byte storage, SHA-256 and measured metadata, automatic
registration after `pull`, garbage collection, a live process registry,
`ps`/`stop`, authenticated downloads, resume, and `push` remain unfinished and
fail closed where commands exist.
