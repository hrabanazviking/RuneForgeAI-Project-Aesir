# Task: Counted Master-Suite Reporting

**Status:** Completed and verified on August 14, 2026.
**Forge stage:** Forge 0B — Verification reporting boundary  
**Parent audit:** `PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md`  
**Predecessor:** `TASK_fail_closed_test_semantics.md`  
**Owning domain:** tests, with documentation-only updates outside that domain

## Context

Forge 0A made the master suite fail closed. Every identified assertion failure
now raises, and an unhandled failure makes the Mojo process exit nonzero. That
repair established trustworthy terminal semantics, but `tests/run_all.mojo`
still stops at the first failure and does not report pass, fail, or skip totals.

The existing runner also invokes two aggregate wrappers:

- `test_sharding()` hides five separately named child tests; and
- `test_rag()` hides two executable child tests plus one explicit external-model
  integration skip.

Counting only the current top-level calls would therefore misrepresent test
granularity. Forge 0B must count the named cases that actually establish local
invariants, while preserving their current deterministic order and precise
evidence boundaries.

## System Statement

The master test runner needs one tests-domain ledger that executes every named
master-suite case through a common error boundary, records every pass, failure,
and explicit skip, continues after individual assertion failures, prints a
stable final summary, and still exits nonzero whenever one or more cases fail.

## Desired End State

1. The normal master run reports exactly 49 passed, 0 failed, 1 skipped, and 50
   total cases at the current baseline.
2. The explicit skip is the RAG real-engine integration boundary that requires
   the untracked external GGUF fixture.
3. Every executable case has a stable machine-readable case name.
4. A raised test error is caught only at the case boundary, recorded with its
   case name and message, and not downgraded into a successful process.
5. The runner continues with later cases after one case fails.
6. After printing the complete summary, the runner raises one terminal error if
   the failure count is nonzero.
7. A zero-failure run exits zero.
8. The existing external real-GGUF integration proof remains opt-in and passes
   independently.
9. Synthetic/scaffold checks remain explicitly distinct from external
   capability proof.

## Counted Case Inventory

The baseline contains 50 reportable cases: 49 executable cases and one skip.

| Domain | Passed on a normal run | Skipped | Counted cases |
|---|---:|---:|---:|
| Compute | 5 | 0 | 5 |
| GGUF validation and type constants | 2 | 0 | 2 |
| Tokenizer | 1 | 0 | 1 |
| Inference and KV cache | 3 | 0 | 3 |
| Host sharding scaffolds | 5 | 0 | 5 |
| Local RAG/vector checks | 2 | 1 | 3 |
| NPU-labeled CPU/scaffold checks | 5 | 0 | 5 |
| GPU-labeled CPU/scaffold checks | 4 | 0 | 4 |
| CLI scaffolds | 3 | 0 | 3 |
| Quantization scaffolds | 2 | 0 | 2 |
| Multi-engine scaffolds | 5 | 0 | 5 |
| Resilience scaffolds | 5 | 0 | 5 |
| Hugging Face parsing/simulation | 3 | 0 | 3 |
| Swarm scaffolds | 4 | 0 | 4 |
| **Total** | **49** | **1** | **50** |

The case count is intentionally not a capability count. Five synthetic tests in
one scaffold domain do not prove five external integrations.

## Stable Case Names

### Compute

- `compute.gemm_f16`
- `compute.flash_attention_2`
- `compute.silu`
- `compute.geglu`
- `compute.dequantize_q4_k_m_scaffold`

### GGUF and tokenizer

- `gguf.malformed_model_rejection`
- `gguf.type_constants`
- `tokenizer.synthetic_bpe`

### Inference and cache

- `inference.synthetic_forward`
- `inference.stop_policy`
- `inference.kv_cache`

### Host sharding scaffolds

- `sharding.synthetic_topology`
- `sharding.tensor_descriptor`
- `sharding.row_column_partition`
- `sharding.host_all_reduce`
- `sharding.host_gemm_parity`

### RAG and explicit skip

- `rag.cosine_similarity`
- `rag.in_memory_store`
- `rag.real_engine_integration` — skipped by the master suite

### NPU-labeled CPU/scaffold checks

- `npu.enum`
- `npu.synthetic_topology`
- `npu.host_buffer_view`
- `npu.arm_neon_cpu_parity`
- `npu.cpu_fallback_matrix`

### GPU-labeled CPU/scaffold checks

- `gpu.enum`
- `gpu.synthetic_topology`
- `gpu.host_buffer_view`
- `gpu.cpu_fallback_matrix`

### CLI and quantization scaffolds

- `cli.modelfile_parser`
- `cli.in_memory_manifest_store`
- `cli.command_dispatch_smoke`
- `quantization.enum`
- `quantization.dispatch_writes`

### Multi-engine scaffolds

- `multi_engine.openai_formatter`
- `multi_engine.grammar_mask`
- `multi_engine.speculative_acceptance`
- `multi_engine.onnx_header_stub`
- `multi_engine.cli_dispatch_stubs`

### Resilience scaffolds

- `resilience.error_guard`
- `resilience.state_vault_marker`
- `resilience.event_bus_marker`
- `resilience.thread_pool_stub`
- `resilience.supervisor_simulation`

### Hugging Face and swarm scaffolds

- `huggingface.tag_parser`
- `huggingface.url_builder`
- `huggingface.download_simulation`
- `swarm.role_enum`
- `swarm.peer_metrics`
- `swarm.registry_load_balancer`
- `swarm.dispatch_simulation`

## Harness Contract

### `TestLedger`

The tests domain owns one small ledger with:

- `passed: Int`
- `failed: Int`
- `skipped: Int`
- ordered failed-case names and error messages

The ledger computes `total = passed + failed + skipped`. It does not infer a
result from console text.

### `run_case(...)`

The common executable-case boundary accepts a stable name and a zero-argument
raising test function. It:

1. invokes the function exactly once;
2. records one pass if it returns normally;
3. catches one `Error` if it raises;
4. records one failure with the original message;
5. prints a stable case-result line; and
6. returns control to the runner so later cases execute.

It must never record both pass and failure for one invocation.

### `record_skip(...)`

The skip boundary accepts a stable name and reason, increments only `skipped`,
and prints a stable skip line. A skip is neither a pass nor a failure.

### `finish(...)`

The terminal boundary prints pass/fail/skip/total counts and failure details in
insertion order. It verifies the expected total of 50. It raises after printing
if the total is wrong or if any failure exists; otherwise it returns normally.

## Output Contract

Every case emits exactly one harness-owned terminal line:

```text
[CASE PASS] <stable-name>
[CASE FAIL] <stable-name> :: <error-message>
[CASE SKIP] <stable-name> :: <reason>
```

The final summary contains stable harness-owned keys. The `[SUMMARY]` prefix is
required because a historical ONNX scaffold prints its own unrelated `Status:`
line:

```text
[SUMMARY] Passed: 49
[SUMMARY] Failed: 0
[SUMMARY] Skipped: 1
[SUMMARY] Total: 50
[SUMMARY] Status: PASS
```

On a failing run, `[SUMMARY] Status: FAIL` is printed before the terminal `Error` is
raised. Existing internal diagnostic output may remain; automation should rely
on the harness-owned case lines and final keys.

## Negative-Proof Gate

After the normal counted run passes:

1. Temporarily change the stable `GGMLType.F16` expectation from `1` to `2` with
   an explicit one-line patch.
2. Run the complete master suite, not only the focused GGUF test.
3. Require the corrupted case to be recorded as failed.
4. Require later cases, including the final swarm case, to execute.
5. Require the summary to report 48 passed, 1 failed, 1 skipped, 50 total, and
   `[SUMMARY] Status: FAIL`.
6. Require process exit 1 after the summary.
7. Restore the exact expectation with another explicit patch.
8. Re-run the complete suite and require 49/0/1/50,
   `[SUMMARY] Status: PASS`, and exit 0.
9. Confirm no temporary mutation remains.

## Implementation Phases

### Phase 1 — Tests-domain harness

1. Add the ledger and common case/skip/finish boundaries.
2. Keep the harness independent of runtime domains.
3. Preserve original error messages for failure details.

### Phase 2 — Runner wiring

1. Import the five sharding child tests directly.
2. Import the two executable RAG child tests and explicit boundary reporter.
3. Register all 49 executable cases in their existing deterministic order.
4. Register the one explicit RAG integration skip at its current position.
5. Remove no public wrapper function; `test_sharding()` and `test_rag()` remain
   available to direct callers.

### Phase 3 — Normal and negative verification

1. Run the normal master suite and verify exact totals and exit 0.
2. Perform the full-suite deliberate-mutation gate and verify continuation,
   exact failing totals, and exit 1.
3. Restore and repeat the normal master suite.
4. Run the opt-in real-GGUF integration test.
5. Build the CLI into a temporary output path.

### Phase 4 — Living documentation

1. Update the tests README and interface specification.
2. Update AER-001, AER-115, the Forge plan, and the current recommendation in
   the parent reality audit.
3. Add Forge 0B to `TODO.md` and `DEVLOG.md` using only verified claims.
4. Mark this task complete only after every acceptance gate passes.

## Expected Files

- this task document
- `aesir_engine/tests/test_ledger.mojo` — new tests-domain reporting utility
- `aesir_engine/tests/run_all.mojo`
- `aesir_engine/tests/README.md`
- `aesir_engine/tests/INTERFACE.md`
- `PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md`
- `TODO.md`
- `DEVLOG.md`

`test_gguf.mojo` may be temporarily patched during the negative gate but must
have no final diff. No runtime implementation file is expected to change.

## Constraints

- Mojo remains the only executable implementation language.
- No public runtime or test function is deleted.
- Existing test functions continue to own their local assertions.
- Existing deterministic execution order is preserved.
- A caught case failure is never reported as a successful process.
- Error catching exists only at the master case boundary.
- The opt-in real-model test remains outside the 50-case master total.
- No scaffold test is relabeled as external capability proof.
- No hardware, network, format, protocol, concurrency, resilience, or
  distributed completion claim is added.
- No model weight, generated binary, cache, secret, or absolute fixture path is
  committed.
- No unrelated runtime defect is silently fixed in this task.

## Acceptance Criteria

- The normal master suite reports exactly 49 passed, 0 failed, 1 skipped, and
  50 total.
- The normal master suite prints `[SUMMARY] Status: PASS` and exits 0.
- Every named executable case has exactly one harness-owned pass/fail line.
- The explicit RAG integration boundary has exactly one skip line.
- A deliberately corrupted GGUF expectation reports exactly 48 passed, 1
  failed, 1 skipped, and 50 total.
- The corrupted run prints `[SUMMARY] Status: FAIL` and exits 1 only after later
  cases run.
- The failure detail preserves `gguf.type_constants` and the original error
  message.
- Exact restoration returns the suite to 49/0/1/50 and exit 0.
- The real-GGUF integration test still passes against the pinned fixture.
- A clean CLI build succeeds.
- `git diff --check` passes.
- The final tree contains no deliberate mutation, fixture, binary, cache,
  secret, hardcoded local path, or unrelated change.

## Explicit Non-Goals

- renaming existing internal banners and test functions;
- removing historical synthetic/scaffold output;
- changing runtime implementations;
- making tests parallel;
- retries or flaky-test suppression;
- timing, benchmarking, or performance thresholds;
- JUnit, TAP, JSON, or file-based report export;
- adding the external GGUF fixture to the master suite;
- capability-ledger publication or broad claim correction; and
- proving any external accelerator, format, protocol, network, resilience,
  concurrency, or distributed subsystem.

Those remain Forge 0C onward in the complete reality audit.

## Completion Evidence

Forge 0B satisfied every bounded acceptance gate:

- `TestLedger` owns pass, failure, skip, total, and ordered failure-detail state.
- `run_case()` accepts current Mojo 1.0 thin noncapturing test functions through
  `def () thin raises`, invokes each exactly once, and records exactly one
  terminal outcome.
- The runner registers all 49 executable named cases directly, including the
  five formerly hidden sharding children and two formerly hidden executable RAG
  children.
- `rag.real_engine_integration` is counted once as the sole master-suite skip.
- Harness-owned result lines use `[CASE PASS]`, `[CASE FAIL]`, and
  `[CASE SKIP]` prefixes.
- Harness-owned final keys use `[SUMMARY]` because a historical ONNX scaffold
  already emits an unrelated unprefixed `Status:` line.
- The normal suite emitted 49 case-pass lines, zero case-fail lines, one
  case-skip line, `[SUMMARY]` totals of 49/0/1/50, and exited 0.
- Temporarily changing the stable F16 expectation from `1` to `2` recorded
  `gguf.type_constants :: GGMLType invariant mismatch`.
- The corrupted run continued through `[CASE PASS] swarm.dispatch_simulation`,
  emitted `[SUMMARY]` totals of 48/1/1/50, printed failure status, and exited 1
  only after the summary.
- Exact restoration returned the complete suite to 49/0/1/50 and exit 0.
- The pinned external GGUF proof again matched all 32 token IDs, exact decoded
  text, one-token regression, and the context-exhaustion boundary.
- A clean Mojo CLI build into a temporary output path passed.
- `git diff --check` passed, and no temporary mutation or generated fixture,
  binary, cache, secret, or hardcoded local path remains.

This task changes verification reporting only. It does not validate any
simulation-backed external capability. Forge 0C is now the recommended next
truth slice: a canonical evidence-backed capability ledger.
