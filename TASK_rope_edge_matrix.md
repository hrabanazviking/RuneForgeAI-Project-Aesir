# AES500-101 — Rotary embedding edge matrix contract

## Objective

Define the current CPU `apply_rope` owner, accepted shape boundary, pair layout,
operation order, and evidence exclusions before extending tests or behavior.
This slice changes documentation only.

## Owner and current behavior

- Owner: `aesir_engine/core/compute.mojo::apply_rope`.
- Inputs: in-place row-major `RuneTensor[f16]` query and key matrices; nonnegative
  `start_pos`; positive even `head_dim`; F32 `theta` defaulting to `10000.0`;
  `neox` selecting paired-index layout.
- Q and K are validated independently: each must have positive rows and columns
  divisible by `head_dim`. The implementation does not require equal Q/K row
  counts or equal numbers of heads.
- For row `r`, the position is `start_pos + r`. For pair index `i` in
  `[0, head_dim/2)`, it computes
  `freq = 1 / theta^(2*i/head_dim)`, then `cos(pos*freq)` and `sin(pos*freq)`.
  Each trigonometric coefficient is cast to F16 before it is applied.
- Interleaved layout (`neox == false`) rotates pairs `(2*i, 2*i+1)`; NeoX layout
  rotates `(i, i+head_dim/2)`. Each head in a row shares the same position and
  pair coefficients. The ordered updates are `x0*cos - x1*sin` and
  `x0*sin + x1*cos`, stored in place as F16.
- Current dimension and position admission checks run before the rotation loops,
  so those rejected inputs do not mutate Q or K.

## Known gaps and exclusions

- The current implementation does not require `theta` to be finite and
  positive. Zero, negative, NaN, or infinite theta behavior is not an accepted
  numerical guarantee yet; later slices must capture and decide it explicitly.
- `start_pos + row` and row/head pointer-index products are not checked for
  integer overflow. Pointer provenance, backing capacity, lifetime, overlap
  between Q and K, and arbitrary strides are not established.
- This contract does not establish partial rotary dimensions, scaling variants,
  multi-axis RoPE, accelerator parity, speed, training gradients, or model
  quality. F16 rounding and non-finite input behavior beyond current source
  execution remain evidence questions.

## Planned evidence

- AES500-102 captures the pre-change source/toolchain and current observable
  outputs for interleaved and NeoX layouts.
- AES500-103 adds direct accepted/rejected interface cases, including distinct
  Q/K shapes and mutation-free validation failures.
- Later unit and adversarial slices compare small deterministic cases against
  independent scalar F32 trigonometry and test position/dimension overflow and
  theta-domain behavior after those decisions are documented.

## Acceptance

This contract matches the current code and names the unresolved theta and
integer-overflow behavior without promising a capability the implementation
does not provide. No kernel or caller behavior changes in AES500-101.
