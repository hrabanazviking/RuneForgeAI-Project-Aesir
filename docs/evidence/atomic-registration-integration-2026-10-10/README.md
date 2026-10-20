# Atomic model registration integration — 2026-10-10

AES500-236 local evidence from source revision
`3bd55443dfba3e5c3704d815ddbacecf5dfcf6a1`.

## Identity and results

- Fresh sm_89 binary: `/tmp/aesir-atomic-registration-236`, SHA-256
  `e80ce0a1fd03dc245d0057a2d419424e879245d99d85816ee31d6f643b5566f9`;
  build and `--help` both passed.
- `python3 scripts/test_native_model_store.py --binary /tmp/aesir-atomic-registration-236` — exit 0. Exact blob digest/size, separate-process restart/verify, deduplication, concurrent create commits, expected identity mismatch rollback, corruption/missing-blob refusal and cleanup all passed.
- `python3 scripts/test_catalog_lifecycle.py --binary /tmp/aesir-atomic-registration-236` — exit 0. Migration, six-writer preservation, backup, restore and invalid destination/source cases passed.
- Harness hashes: native model store
  `df5641084cb66a479394148f2f8a8ed88d03d2dd7291e8f771194ff146433077`;
  catalog lifecycle
  `1ee5d8a3ec972279740b01ba3890e430bd6c6161f81d9597d4fc194f92b8627f`.

Evidence is scoped to generated fixtures and local Linux process/filesystem
behavior. It is not sudden-power-loss durability or a hosted CI result.
