# Q5_K dequantization oracle baseline — 2026-10-10

AES500-312 baseline at source revision
`b66fd51206948d1d1978e83baebd45cbebcfe779`.

SHA-256 of the pre-oracle source files:

- `aesir_engine/core/packed_quantization.mojo`:
  `13b9d738746f4ac6a31d3b3797a39816c822734ca841a145b73f5d955c2aa20c`.
- `aesir_engine/core/compute.mojo`:
  `c0e18a79ac04be866af16d7f69c600fb68ea8fdd6fafe68c89ac76d3218d1196`.
- `aesir_engine/tests/test_compute.mojo`:
  `b2e16d054a590cc8387ef64a4767a9fc89aea51d904cfe6361eb2af9d42a89b2`.

Existing `E-MASTER` fused Q5_K cases use raw blocks and hand-calculated
representative outputs. No test independently compared the standalone public
dequantizer's complete 256-value output vector. Baseline is source inspection;
the focused owning command is
`pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/test_compute.mojo`.
