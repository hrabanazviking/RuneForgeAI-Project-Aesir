# Linux clean-build matrix baseline — 2026-10-10

AES500-332 baseline at revision `28c51fd7eeed182a13cd74a4e6e4445546807f52`.

- Pixi declares `linux-64`; CI config uses one `ubuntu-latest` runner and Pixi
  `v0.78.0`.
- This host's current development environment reports Mojo `1.0.0`
  (`ed45d567`) and Pixi `0.76.2`.
- Existing CI clean-build smoke compiles `aesir_engine/main.mojo` with
  `--target-accelerator sm_89`; other CI probes compile selected test files.
- No other operating system or Linux distribution row is declared by the
  project workflow; cross-platform compatibility is unverified.
- This receipt is source/toolchain inspection only. The baseline build command
  is `pixi run mojo build --target-accelerator sm_89 aesir_engine/main.mojo -o
  /tmp/aesir-ci-build`.

## AES500-334/335/336 execution receipt

On the same Linux x86-64 host, clean output paths outside the checkout built
successfully:

- CLI: `pixi run mojo build --target-accelerator sm_89 aesir_engine/main.mojo
  -o /tmp/aesir-clean-cli-build`; artifact SHA-256
  `71910b28a62de153d0e7bcfb30c23cce0d3511b7d9b6692cf930c3d76a932f83`.
- Master: `pixi run mojo build --target-accelerator sm_89
  aesir_engine/tests/run_all.mojo -o /tmp/aesir-clean-master-build`; artifact
  SHA-256
  `328348c67ef2887585029906f9c25015989a8062b1bab7f4aa1c46a21e32b460`.
- The built CLI `--help` exits 0 and displays usage.
- Running the built master executable reports 249 passed, 0 failed, 1 skipped
  (250 total); the skip is the documented real-GGUF RAG integration fixture.

The local toolchain is Pixi 0.76.2/Mojo 1.0.0; hosted CI uses Pixi 0.78.0 on
`ubuntu-latest`. No other distribution/OS has been exercised.
