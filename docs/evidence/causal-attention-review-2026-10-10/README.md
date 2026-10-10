# AES500-118 — Causal attention implementation review

## Reviewed owner and evidence

Manual primary-agent review of `core/compute.mojo::flash_attention_2`, the
AES500-112 retained noncausal capture, interface/rejection cases, scalar causal
reference, KV-cache integration, and the 33-position tile-boundary adversarial
case.

The implementation now sets `causal_end = i + 1` for each query row and limits
tiled key traversal to `j < causal_end`. The scalar probe gives row 0 exactly
its single allowed V row. Tests also cover future-V perturbation and the 31/32
boundary. Shape failures are asserted not to mutate output.

## Review findings and limits

- The query/key/value/output width equality constraint means grouped-query
  attention is not provided by this function; the separate incremental GQA
  owner remains distinct.
- The online recurrence stores the partial output in F16 after each key, then
  normalizes it. AES500-115's 0.05 absolute bound covers one deterministic
  width-3 corpus only; no broad error bound or SIMD-width matrix is established.
- Integer products/indexes, raw pointer provenance/capacity/lifetime, aliasing,
  exceptional-value behavior, long-context numerical drift, accelerator parity,
  and performance remain unverified.
- Six independent Mythic Engineering reviews could not be launched because the
  app's agent service returned `agent thread limit reached`. This is a primary
  review only; independent approval is not claimed.

No additional code correction was required within AES500-118's scoped causal
mask contract.
