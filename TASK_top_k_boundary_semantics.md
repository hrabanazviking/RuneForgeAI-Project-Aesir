# AES500-201 — top-k boundary semantics

## Objective and owners

Define how top-k admits candidates at `k <= 0`, `k == 1`, `k == candidate
count`, and `k > candidate count`, including score ties. CPU owner:
`apply_top_k` and its stable insertion sort in `core/sampler.mojo`. Native CUDA
owners: exact partition ranking in `core/cuda_sampling.mojo` and
`NativeSamplingConfig.validate` in `core/sampling_config.mojo`.

## Current contract to verify

CPU `apply_top_k` is a no-op for empty candidates, nonpositive k, or k at least
the candidate count; otherwise it sorts descending by score and retains exactly
k entries. Its strict comparison preserves input order for equal scores.
`sample_token_from_logits` separately treats `top_k == 1` as greedy before
penalties and suppression are applied. CUDA validates `1..256`, ranks exact
global top-k after repetition adjustment and vocabulary admission, and resolves
equal scores by smaller token ID. Its temperature-zero behavior may still use
the partition path when repetition penalty is not 1.

## Invariants and exclusions

- For finite unequal scores and `1 <= k < n`, exactly the k highest scores
  remain.
- Ties at a boundary follow the owner-specific rule and must not imply CPU/CUDA
  parity.
- `k >= n` preserves all candidates; CPU nonpositive values preserve the input
  list as a helper behavior, although public CUDA config rejects k below 1.
- This task does not alter greedy special casing, temperature, top-p/min-p,
  repetition policy, RNG, model quality, or performance.

## Acceptance

Capture baseline for empty, 0, 1, n, n+1 and tie-at-cutoff cases; document
public validation versus helper behavior; prove candidate IDs and order;
exercise NativeSamplingConfig rejection; record CUDA physical availability
without converting CPU fixtures into hardware evidence.
