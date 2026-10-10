# Content-addressed blob identity integration — 2026-10-10

AES500-226 local native CLI evidence from repository revision
`9d7ac784c8dc472c4bb0a59b7147d30db6a4062c`.

## Identity and commands

- Toolchain: Mojo 1.0.0 (`ed45d567`), Pixi 0.76.2, sm_89 target.
- Binary `/tmp/aesir-blob-identity-226` SHA-256:
  `e80ce0a1fd03dc245d0057a2d419424e879245d99d85816ee31d6f643b5566f9`.
- `/tmp/aesir-blob-identity-226 --help`: exit 0.
- `python3 scripts/test_native_model_store.py --binary /tmp/aesir-blob-identity-226`: exit 0. The harness observed fixture bytes as 32 bytes with exact digest
  `sha256:9b3737096a1813f0580908da7a52fd6f04a5da9c5e207ccdf2c0483c2db47d96`, verified the installed bytes, and exercised deduplication, restart, concurrency, corruption, missing-blob, rollback, GC, permission and symlink cases.
- `python3 scripts/test_catalog_lifecycle.py --binary /tmp/aesir-blob-identity-226`: exit 0. This extends coverage across explicit migration/backup/restore; the six writers preserve all records.
- Harness hashes: `scripts/test_native_model_store.py` is
  `df5641084cb66a479394148f2f8a8ed88d03d2dd7291e8f771194ff146433077`;
  `scripts/test_catalog_lifecycle.py` is
  `1ee5d8a3ec972279740b01ba3890e430bd6c6161f81d9597d4fc194f92b8627f`.

This is local Linux/generated-fixture evidence for the checked CLI paths. It is
not third-party digest certification, hosted CI, or a power-loss test.
