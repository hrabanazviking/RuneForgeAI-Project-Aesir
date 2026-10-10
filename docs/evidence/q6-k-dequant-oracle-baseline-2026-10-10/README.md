# Q6_K dequantization oracle baseline — 2026-10-10

AES500-322 baseline at revision
`bc9ea99a07e81cce07b94903ce79028f66f4e511`.

Pre-oracle source SHA-256 values:

- `aesir_engine/core/packed_quantization.mojo`:
  `13b9d738746f4ac6a31d3b3797a39816c822734ca841a145b73f5d955c2aa20c`.
- `aesir_engine/core/compute.mojo`:
  `c0e18a79ac04be866af16d7f69c600fb68ea8fdd6fafe68c89ac76d3218d1196`.
- `aesir_engine/tests/test_compute.mojo`:
  `eaf3822dc8f41bbb38959ccbe45ce2c42aa6a00acae68293998f9f30a265fd29`.

Existing Q6_K evidence exercised representative dequantization and fused GEMM
parity with hand-calculated values. It did not compare the complete standalone
256-value vector to a separate scalar decoder. This receipt is source
inspection; the focused command is
`pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/test_compute.mojo`.
