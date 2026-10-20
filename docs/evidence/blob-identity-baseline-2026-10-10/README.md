# Content-addressed blob identity baseline — 2026-10-10

AES500-222 pre-change identity baseline at repository revision
`56f1f86483bd8c666523a7dc0450c20ee102c796`.

## Source identity

- `aesir_engine/cli/manifest.mojo` SHA-256:
  `9d04c8c22fdd3e7fd87dfa5e9e1d8279eb6c0884524c62a3a3fc0f16e12b7cad`
- `aesir_engine/cli/storage.mojo` SHA-256:
  `d9448835759f7ebb312f987d629061453383f51d457a7bbcfb4452923a2d175a`
- `aesir_engine/tests/test_cli.mojo` SHA-256:
  `a5372337d54bab18283c9ab96f7353eb08af1d416a1e87f6b14f9b3f13f24d44`
- Toolchain: Mojo 1.0.0 (`ed45d567`), Pixi 0.76.2.

## Reproducible vectors

`pixi run mojo run -I aesir_engine /tmp/aesir_blob_identity_baseline.mojo`
exercised `validate_manifest_storage_identity` directly. It accepted
`fnv1a64:0123456789abcdef` with size 0 and `sha256:` plus 64 lowercase `a`
hex digits with size 1. It rejected uppercase SHA hex, a 63-digit SHA payload,
uppercase recipe hex, and zero-byte SHA identity. All assertions passed.

The temporary harness is a baseline probe, not a tracked deliverable. This is
validator evidence only; it does not yet prove an on-disk blob was measured,
verified, or safely deduplicated.
