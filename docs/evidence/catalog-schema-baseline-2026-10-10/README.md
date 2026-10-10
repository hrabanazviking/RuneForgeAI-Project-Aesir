# Model catalog schema baseline — 2026-10-10

This is a source and wire-format baseline for AES500-212, captured before
adding focused schema contract assertions. It makes no compatibility or
whole-store durability claim beyond the observations below.

## Identity

- Repository revision: `13be4c67e8ab81e4ccdfc03ac3ee569bfc49c7f4`
- Toolchain: Mojo 1.0.0 (`ed45d567`), Pixi 0.76.2
- `aesir_engine/cli/storage.mojo` SHA-256:
  `d9448835759f7ebb312f987d629061453383f51d457a7bbcfb4452923a2d175a`
- `aesir_engine/cli/manifest.mojo` SHA-256:
  `9d04c8c22fdd3e7fd87dfa5e9e1d8279eb6c0884524c62a3a3fc0f16e12b7cad`
- `aesir_engine/tests/test_cli.mojo` SHA-256:
  `831c697b0e1383825fa4430aaebcfd11f0463659a737864bf959e2bb950c5728`

## Observations

- The owning serializer produced these exact empty-store bytes (no trailing
  newline): `AESIR_MODEL_CATALOG_V1\nCOUNT:0`.
- The owning deserializer accepted those bytes and returned an empty store.
- The existing CLI test rejects `AESIR_MODEL_CATALOG_V2\nCOUNT:0` as an
  unsupported version.
- `serialize_catalog` emits a header, a count, then one hex-encoded manifest
  record per model key. `deserialize_catalog` requires the declared record
  count and rejects duplicate normalized identities.
- The test harness `/tmp/aesir_catalog_baseline.mojo` invoked the production
  serializer and deserializer with `pixi run mojo run -I aesir_engine`; output
  was the exact two-line representation above and all assertions passed.

This baseline used an empty store, so it does not characterize nonempty manifest
round trips, legacy migration, blob admission, crash behavior, or concurrent
writers. Those are addressed by separate contracts and tests.
