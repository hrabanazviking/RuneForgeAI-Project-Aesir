# AES500-111 — Causal attention reference contract

## Objective and owner

Define the CPU `flash_attention_2` attention window and numerical oracle before
changing the kernel. Owner: `aesir_engine/core/compute.mojo::flash_attention_2`.
This slice is documentation only.

## Intended contract

- Inputs are row-major F16 Q, K, V, and output tensors with `seq_len > 0`,
  `head_dim > 0`, and a positive `Q.cols` divisible by `head_dim`.
- Q/K/V/output provide at least `seq_len` rows. Current interface also requires
  each column count to equal Q.cols. One query head maps to one key/value head
  in the current implementation; grouped-query behavior is not established by
  this function's equal-width interface.
- Query row `i` attends only to keys and values at positions `j` in `[0, i]`.
  This inclusive causal prefix is the semantic contract to be established by
  the upcoming baseline, interface, implementation and reference slices.
- Scores are scalar dot products accumulated in F32, scaled by
  `1/sqrt(head_dim)`. Softmax is normalized over the allowed prefix, and the
  weighted values are written to the corresponding output row in F16.
- Validation failures must occur before output mutation. Numerical checks use
  an independently computed scalar F32 reference and explicitly scoped F16
  output comparisons.

## Current source observation and gaps

The current kernel loops `j` over `[0, seq_len)` for every query row and has no
`j <= i` mask. It therefore leaks future V rows into earlier outputs. The
existing `test_flash_attention` only checks that output is nonzero for one
synthetic shape; it does not detect causality. AES500-112 will capture this
behavior before the implementation change.

The current admission checks do not establish checked products/indexes,
pointer provenance or backing capacity, alias/overlap safety, exceptional-value
policy, broad numerical tolerance, accelerator behavior, performance, or model
quality. The online softmax update and SIMD width/tail behavior also require
oracle evidence before any wider claims.

## Planned evidence

- AES500-112: deterministic pre-change capture with an adversarial future-value
  perturbation, raw outputs, source/toolchain identities, and an independent
  scalar reference showing the present noncausal mismatch.
- AES500-113: direct shape/row/head admission and mutation-free rejection.
- AES500-114: enforce inclusive causal prefix without changing unrelated shape
  behavior.
- AES500-115/116/117: scalar unit oracle, adjacent integration, and hostile
  bounds/exceptional/resource evidence.
- AES500-118/119/120: manual review, documentation reconciliation, then release
  build/master/docs checks and exact-head hosted CI.

## Acceptance

The contract names the owner, desired attention window, shape and numerical
rules, current missing mask, evidence sequence, and explicit non-claims. No
kernel code changes in AES500-111.
