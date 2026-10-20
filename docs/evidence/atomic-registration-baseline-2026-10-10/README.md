# Atomic model registration baseline — 2026-10-10

AES500-232 pre-change source and behavior baseline at
`d3855f01fa72fc6923536aed8bbea8a0d64efce2`.

## Source identities

- `aesir_engine/cli/storage.mojo` SHA-256:
  `d9448835759f7ebb312f987d629061453383f51d457a7bbcfb4452923a2d175a`
- `aesir_engine/cli/manifest.mojo` SHA-256:
  `9d04c8c22fdd3e7fd87dfa5e9e1d8279eb6c0884524c62a3a3fc0f16e12b7cad`
- `aesir_engine/tests/test_cli.mojo` SHA-256:
  `cc8e37c5d9ced0208d2134d87276fa1cb29555dd119d0e30479bca434faefafb`
- Toolchain: Mojo 1.0.0 (`ed45d567`), Pixi 0.76.2.
- Baseline CLI binary: `/tmp/aesir-blob-identity-230`, SHA-256
  `e80ce0a1fd03dc245d0057a2d419424e879245d99d85816ee31d6f643b5566f9`.

## Observed transaction

A temporary caller-owned source containing exactly 37 bytes was registered via
`create baseline:v1 --model ... --model-store store`. The CLI reported
`sha256:7f09a4538914414d4a82b4a6b750c18cd76482b99003ea3d725b2ff08076d43a`
and size 37. A fresh `show --format json` process reported that same digest and
size, and a separate `verify` process rehashed and reported the same values.
All three commands exited 0. The generated Modelfile/source and store were
confined to a temporary directory and removed on exit.

This baseline does not yet probe injected failure ordering or in-memory state
publication; those are reserved for later unit/adversarial slices.
