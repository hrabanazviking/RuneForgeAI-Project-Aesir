# AES500-311 — Q5_K dequantization oracle contract

## Objective and owner

Validate the canonical 176-byte Q5_K block decoder in `core/compute.mojo` and
`core/packed_quantization.mojo` against a separately written scalar layout
oracle. The owner is the core quantization domain.

## Contract

- One block contains 256 values in 176 bytes: F16 `d`, F16 `dmin`, twelve
  packed six-bit scale/minimum bytes, 32 high-bit plane bytes, and 128 packed
  nibble bytes.
- Eight groups of 32 values select low/high nibble by group parity, a shared
  32-byte quant segment, and one high-bit plane bit per lane/group.
- Each output equals `d * scale * q5 - dmin * minimum`, converted to F16.
- The oracle uses its own scalar indexing and bit extraction and compares all
  256 values. It must exercise the 5th quant bit as well as scale/minimum
  packing boundaries.
- Existing zero/partial/invalid storage rejection remains unchanged. The
  result establishes one-block decoding only, not multi-block safety, model
  compatibility, speed, or full inference parity.

## Acceptance and exclusions

Run the focused compute suite and full master suite, then repository docs and
hygiene gates. No production implementation change is needed if the scalar
oracle passes. Broader stored-model and end-to-end claims remain separate.
