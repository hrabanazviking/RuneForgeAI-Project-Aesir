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
  counts or equal numbers of heads. Q and K are independently rotated across
  their respective rows.
- For row `r`, the position is `start_pos + r`. For pair index `i` in
  `[0, head_dim/2)`, it computes
  `freq = 1 / theta^(2*i/head_dim)`, then `cos(pos*freq)` and `sin(pos*freq)`.
  Each trigonometric coefficient is cast to F16 before it is applied.
- Interleaved layout (`neox == false`) rotates pairs `(2*i, 2*i+1)`; NeoX layout
  rotates `(i, i+head_dim/2)`. Each head in a row shares the same position and
  pair coefficients. The ordered updates are `x0*cos - x1*sin` and
  `x0*sin + x1*cos`, stored in place as F16.
- Current theta, dimension, and position admission checks run before the
  rotation loops, so those rejected inputs do not mutate Q or K.

## Known gaps and exclusions

- `theta` must be finite and positive. Zero, negative, NaN, and either infinity
  reject before tensor mutation; focused adversarial tests assert this.
- `start_pos + row` and row/head pointer-index products are not checked for
  integer overflow. Pointer provenance, backing capacity, lifetime, overlap
  between Q and K, and arbitrary strides are not established.
- AES500-104 now rejects zero columns and rotates Q/K using independent row
  loops, preserving the existing allowance for distinct row counts. This fixes
  the baseline-observed unrotated K suffix. The historical baseline remains
  available for comparison.
- AES500-105's scalar reference test covers both pair layouts, multiple heads,
  distinct Q/K row counts, and start positions 0 and 7. It requires exact F16
  equality for this deterministic corpus only.
- AES500-106 verifies the adjacent KV-cache path: rotated K values are appended
  and read back unchanged, while V remains unchanged by RoPE. This is local
  integration evidence for one cache position and shape.
- AES500-107 records the historical failure: theta=0 and theta=-1 were admitted
  and produced NaN in both Q and K for the exercised nonzero position.
- AES500-108 closes the observed defect: theta must be finite and positive,
  and zero, negative, NaN, and ±Inf reject before changing Q or K.
- This contract does not establish partial rotary dimensions, scaling variants,
  multi-axis RoPE, accelerator parity, speed, training gradients, or model
  quality. F16 rounding and non-finite input behavior beyond current source
  execution remain evidence questions.

## Planned evidence

- AES500-102 captures the pre-change source/toolchain and current observable
  outputs for interleaved and NeoX layouts.
- AES500-103 records the pre-implementation interface, including historical
  zero-column admission. AES500-104 closes that gap before mutation.
- AES500-105 adds deterministic scalar F32 oracle coverage. AES500-106 verifies
  the KV-cache boundary. AES500-107 captures invalid-theta corruption and
  AES500-108 changes it to finite-positive pre-mutation rejection.
- Position and index overflow, pointer provenance/capacity, overlap, arbitrary
  strides, broad tolerance, and accelerator behavior remain unverified.

## Baseline receipt

AES500-102's deterministic corpus, raw output, independent Python oracle, and
scope notes are preserved in
`docs/evidence/rope-baseline-2026-10-09/README.md`. The unequal-row capture
shows the third K row left untouched by the current Q-driven loop. That is an
historical observation. AES500-104 corrects it by iterating K.rows independently.

## Acceptance

This task records the AES500-101 starting contract and subsequent evidence.
Current owner behavior matches the source after AES500-104 and AES500-108;
remaining limitations are stated above. The numerical results apply only to
the explicitly exercised deterministic corpus.
