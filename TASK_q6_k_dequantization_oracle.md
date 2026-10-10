# AES500-321 — Q6_K dequantization oracle contract

## Objective and owner

Validate the canonical 210-byte Q6_K block decoder in `core/compute.mojo` and
`core/packed_quantization.mojo` against a separate scalar layout oracle. The
owner is the core quantization domain.

## Contract

- One block contains 256 values: 128 low-nibble bytes, 64 packed two-bit high
  plane bytes, 16 signed scale bytes, and one F16 global scale (`d`).
- Output index maps to one of two 128-value halves, four 32-value groups, and a
  lane. The oracle independently extracts the nibble, high two bits, signed
  scale, and computes `d * scale * (q - 32)`, converted to F16.
- Compare all 256 output values, including negative scales and every high-bit
  group position.
- Existing zero/partial/invalid storage rejection remains unchanged. One-block
  evidence does not prove multi-block, model, performance, or inference parity.

## Acceptance and exclusions

Run focused compute tests, full master, documentation and hygiene gates. Do not
change production decoding unless the scalar oracle finds a mismatch. Preserve
the current public `dequantize_q6_k_block` contract.
