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

AES500-112's retained corpus is in
`docs/evidence/causal-attention-baseline-2026-10-10/README.md`: 10/12 captured
F16 values differ from the causal oracle (max absolute error 12.671875), while
the capture is much closer to the all-row oracle. The evidence is bounded to
that shape and input set.

AES500-114 changes the tiled key loop bound for query row `i` to `i+1`, so
future keys are not scored or accumulated. Re-running the retained 3-row probe
after the change makes row 0 equal its sole allowed value row exactly.

AES500-115's `compute.attention_reference` test compares a 3-row, head-width-3
case to a scalar F32 online softmax over `[0, i]`, accepts at most 0.05 absolute
error after F16 storage for this corpus, requires exact row-0 single-key
equality, and repeats with a large future-row V perturbation.

AES500-116 appends two K/V rows through `KVCache`, reads the active slices, and
passes them to causal attention. Query row 0 exactly equals cache position 0's
V row; query row 1 must differ after admitting its second position.

AES500-113 adds direct admission coverage for zero sequence/head width,
nondivisible Q width, K/V/output column mismatches, and each tensor's short-row
case. Rejections assert the entire logical output snapshot is unchanged; one
valid multi-head call must write output.

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
