# AES500-122 — GGUF header version baseline

## Reproduction

```sh
pixi run mojo run --target-accelerator sm_89 -I aesir_engine docs/evidence/gguf-header-version-baseline-2026-10-10/version_baseline.mojo > docs/evidence/gguf-header-version-baseline-2026-10-10/raw-output.txt
```

Toolchain: Mojo 1.0.0 (`ed45d567`). Loader source SHA-256 at capture:
`e6e90a1f9f2c6c9c0020079d6630328198981d894d45fd980ec7872dbaa1b6b1`.
Probe SHA-256:
`ccdc01e9323c3c0303a88501a248dba186f7f39ecdec6d1eb493344a0f73bc82`.

## Result

The in-memory `parse_header_bytes` helper accepts versions 0, 1, 2, 3, 4, and
`UInt32::MAX` for a 24-byte buffer with valid magic. It only checks minimum
length and magic. By source inspection, `_parse_header` on the mapped-file
path accepts version 3 only. This confirms an entry-path consistency defect;
the probe does not claim a complete mapped-file run for every version.

Only header-version dispatch is covered. Count validation, metadata, tensor
directory integrity, and whole-model loading are outside this baseline.
