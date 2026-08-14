# Tests Domain: Verification & Invariant Rites

## Domain Overview
The `tests` domain holds the master test runner and domain-specific verification scripts.

- **`run_all.mojo`:** Master orchestrator for the repository's synthetic and unit proving domains.
- **`test_compute.mojo`:** Unit tests for GEMM, Flash Attention-2, SiLU, GeGLU, and Q4_K_M dequantization.
- **`test_gguf.mojo`:** Unit tests for malformed GGUF rejection and `GGMLType` constants.
- **`test_tokenizer.mojo`:** Unit tests for `RuneWeaver` token encoding/decoding.
- **`test_real_gguf.mojo`:** Opt-in external-fixture proof for metadata,
  zero-copy F16 mapping, F32 normalization conversion, tokenizer parity, and
  exact 32-token deterministic inference parity. It also preserves the original
  first-token assertion. It is intentionally not part of `run_all.mojo` because
  model weights are not committed.
- **`test_inference.mojo`:** Synthetic forward-pass smoke coverage plus isolated
  stable generation-stop policy assertions for EOS, requested length, context
  exhaustion, and continuation.

## Failure Semantics

The master suite is fail closed. Every existing asserted mismatch in an invoked
test raises or propagates `Error`, so `run_all.mojo` exits nonzero and cannot
reach its final success banner. The two former KV-cache print-and-return paths
also raise. A deliberate corruption of the stable `GGMLType.F16` expectation
was verified to exit 1; restoring it returned the focused test and master suite
to exit 0.

The runner currently stops at the first raised failure. Counted pass/fail/skip
aggregation is not implemented yet. The RAG external-fixture boundary prints an
explicit `SKIP` and real model execution remains the opt-in test below.

## How to Run
```bash
cd aesir_engine
pixi run mojo run tests/run_all.mojo
```

Run the real-model proof with the pinned fixture and oracle described in
`TASK_verified_multi_token_generation.md`:

```bash
pixi run mojo run tests/test_real_gguf.mojo /path/to/stories260K.F16.gguf
```

The expected completion for `One day, Timmy went to` at 32 new tokens is:

```text
 the park with his mom. They saw a big box with a big box. The box was very small and
```

This proves only the documented F16 single-device CPU greedy path. The master
suite still includes historical synthetic/scaffold checks whose broader labels
are not proof of real accelerator, quantized-model, server, network,
concurrency, resilience, or distributed behavior. A zero exit means that all
invoked assertions passed; it does not expand their evidence boundary. See
`PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md`.
