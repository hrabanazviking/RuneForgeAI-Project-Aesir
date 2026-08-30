# Tests Domain: Verification & Invariant Rites

## Domain Overview
The `tests` domain holds the master test runner and domain-specific verification scripts.

- **`run_all.mojo`:** Master orchestrator registering 147 executable named cases
  and one explicit external-fixture skip.
- **Native Gemma CUDA evidence:** `test_gemma4_cuda.mojo`,
  `test_gemma4_quant_parity.mojo`, and `inspect_gemma4.mojo` are opt-in physical
  checks. `scripts/check_gemma4_conversation.py` validates the logged 20-turn
  transcript. See `docs/GEMMA4_CUDA.md` for their scope.
- **Native Stheno CUDA evidence:** independent tokenizer, packed matvec and
  RoPE/SiLU/GQA checks, profile admission, session limits and 20-turn transcript
  accounting are documented in `docs/STHENO_CUDA.md`. These opt-in proofs keep
  large weights external and do not establish general Llama compatibility.
- **`test_hardware_discovery.mojo`:** Deterministic injected-record tests for
  discovery statuses, validation, accumulation, deduplication, and selection.
- **`test_gpu_discovery.mojo`:** Opt-in physical MAX CUDA enumeration and
  topology-selection proof; intentionally excluded from the CPU master suite.
- **`test_cuda_resource_budget.mojo`:** CPU-only GPU-2 byte accounting,
  transactional rejection, rollback, overflow, and device-policy admission.
- **`test_gpu_resources.mojo`:** Opt-in physical GPU-2 selected-context,
  budgeted F16 buffer, synchronized transfer, and scope-cleanup proof.
- **`test_cuda_gemm_plan.mojo`:** CPU-only GPU-3 shape/product/ABI/launch and
  transactional three-buffer budget verification.
- **`test_gpu_gemm.mojo`:** Opt-in physical GPU-3 production-gateway F16 GEMM,
  independent F32 parity, reuse, failure, and negative-control proof.
- **`test_ledger.mojo`:** Tests-domain pass/fail/skip ledger, per-case error
  boundary, stable result lines, ordered failure details, and terminal status.
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

The runner catches errors only at each named case boundary, records the failure,
and continues with later cases. After all 145 reportable cases, it prints unique
`[SUMMARY]` keys and raises if any case failed or the expected total is wrong.
The RAG external-fixture boundary is counted as one skip, and real model
execution remains the opt-in test below.

A normal baseline run reports:

```text
[SUMMARY] Passed: 144
[SUMMARY] Failed: 0
[SUMMARY] Skipped: 1
[SUMMARY] Total: 145
[SUMMARY] Status: PASS
```

The historical Forge 0B negative gate deliberately corrupted the F16 type expectation.
The runner recorded `gguf.type_constants` as failed, continued through the final
swarm case, reported 48/1/1/50, and exited 1 after the summary. Exact restoration
returned that Forge's suite to 49/0/1/50 and exit 0. Later stages expanded the
current baseline to 144/0/1/145; the consistency checker mechanically keeps
the runner total and capability ledger synchronized.

## How to Run

Run the master suite from the repository root so tracked configuration fixtures
resolve through their production-relative paths:

```bash
pixi run mojo run aesir_engine/tests/run_all.mojo
```

Run the opt-in physical GPU-2 resource proof from the repository root:

```bash
MODULAR_NVPTX_COMPILER_PATH=/usr/bin/ptxas pixi run mojo run aesir_engine/tests/test_gpu_resources.mojo
```

Its `--negative-control` form must exit nonzero after injecting one transfer
mismatch. Neither command is part of hosted CPU CI.

Run the opt-in production GPU-3 CUDA GEMM proof from the repository root:

```bash
MODULAR_NVPTX_COMPILER_PATH=/usr/bin/ptxas pixi run mojo run aesir_engine/tests/test_gpu_gemm.mojo
```

Its `--negative-control` form must exit nonzero after corrupting an independently
computed expectation. The normal command executes two shapes for three rounds
each through the reusable production gateway; it is not part of hosted CPU CI.

Run the real-model proof with the pinned fixture and oracle described in the
root `fixture_manifest.json` and `TASK_verified_multi_token_generation.md`:

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
counted local assertions passed; it does not expand their evidence boundary. See
`PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md`.

Tracked fixture payloads, if added, belong only under `tests/fixtures/` and must
be registered before admission. Run `python3 scripts/check_fixture_manifest.py`
from the repository root to validate classifications, provenance, consumers,
storage boundaries, byte sizes, and SHA-256 values. The directory currently
contains only its policy README and no payload data.
