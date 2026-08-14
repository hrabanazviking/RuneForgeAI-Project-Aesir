# Task: Fail-Closed Master-Suite Semantics

**Status:** Approved for implementation by Volmarr on August 14, 2026.  
**Forge stage:** Forge 0A — Verification truth boundary  
**Parent audit:** `PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md`  
**Owning domain:** tests, with documentation-only updates outside that domain

## Context

The function-level reality re-audit found 118 `FAIL` print sites across 12 Mojo
test modules. Most affected tests record a mismatch in a `success` Boolean and
then print `FAIL`, but return normally. Two KV-cache failure paths print and
return early. Because `tests/run_all.mojo` reaches the end and exits zero in
either case, a broken assertion can be reported as a successful test process.

This is more serious than missing summary polish. It means the current master
suite is not a reliable merge or development gate. A green process exit proves
only that no unhandled runtime error occurred; it does not prove that the test
conditions passed.

The broader reality audit separately establishes that many historical tests
exercise simulations, CPU fallback implementations, format-name scaffolds, or
unconditional success stubs. This task does not convert those subsystems into
real integrations. It makes their existing assertions enforceable and labels
that boundary precisely.

## System Statement

Every asserted mismatch reached by the repository's master Mojo test suite must
terminate the test process with a nonzero exit. A test may print `PASS` only
after all of its asserted conditions hold. A deliberate corruption of a known
expectation must therefore make the relevant test executable fail and must also
prevent the master runner's final success banner from being reached.

## Desired End State

1. Every existing print-only terminal failure branch raises `Error`.
2. Every existing early-return failure branch raises `Error`.
3. Every test function that can raise declares `raises`, including callers.
4. Detailed diagnostics may print before the terminal error, but a mismatch can
   never return success to its caller.
5. The master runner reaches its final banner only when all invoked tests return
   normally.
6. The intentional RAG external-fixture boundary remains an explicit `SKIP`; it
   is not relabeled as a pass and does not pretend that a model fixture exists.
7. All memory read by an assertion is initialized first.
8. Previously assertion-free smoke checks gain a minimal derived-output
   invariant where that can be done without claiming external compatibility.
9. The separate real-GGUF integration proof remains passing.
10. Documentation says exactly what these tests prove and what they do not.

## Current Affected Modules

The census at baseline `4bf7f40` identified print-only or early-return failures
in these master-suite modules:

- `aesir_engine/tests/test_compute.mojo`
- `aesir_engine/tests/test_gguf.mojo`
- `aesir_engine/tests/test_kv_cache.mojo`
- `aesir_engine/tests/test_rag.mojo`
- `aesir_engine/tests/test_npu_edge.mojo`
- `aesir_engine/tests/test_gpu_realms.mojo`
- `aesir_engine/tests/test_cli.mojo`
- `aesir_engine/tests/test_quantization.mojo`
- `aesir_engine/tests/test_multi_engine.mojo`
- `aesir_engine/tests/test_resilience.mojo`
- `aesir_engine/tests/test_huggingface.mojo`
- `aesir_engine/tests/test_swarm_cluster.mojo`

The call chain in `run_all.mojo` and any affected nested wrapper also belongs to
the implementation boundary because Mojo propagates raising behavior through
function signatures.

`test_inference.mojo`, `test_tokenizer.mojo`, `test_sharding.mojo`, and
`test_real_gguf.mojo` must be rechecked for compatible propagation and retained
as regression gates even where they already raise correctly.

## Failure-Semantics Contract

### Direct condition tests

For a direct `if expected ... else ...` test, the false branch must raise an
error containing the test or invariant name. The branch may first print numeric
diagnostics that are awkward to encode in the error string.

### Accumulated condition tests

Where a test evaluates several independent conditions, it may retain a
`success` accumulator so all useful mismatch diagnostics are printed. The final
false branch must raise. The final true branch alone may print `PASS`.

### Wrapper tests

Wrapper functions such as `test_rag()` must declare `raises` and allow the first
failing child test to propagate. They must not catch or downgrade a child
failure.

### Master runner

`run_all.mojo` already declares `main() raises`. It must continue to invoke the
same suite in the same deterministic order. Forge 0A does not add exception
catching, retry, or a counted summary because those can accidentally convert a
failure back into a zero exit. Counted aggregation is Forge 0B.

### Explicit skips

`report_engine_integration_boundary()` is an informational boundary, not an
assertion. Its `SKIP` output remains valid because the repository deliberately
does not commit the external model. Real inference is independently tested by
`test_real_gguf.mojo` when the pinned fixture path is supplied.

## Minimal Test-Quality Refinements in Scope

Fail-closed mechanics alone would leave two known undefined or vacuous checks.
The following narrow repairs are part of Forge 0A:

1. Initialize every `target_logits` element in `test_speculative_engine()`
   before `verify_tokens()` reads it.
2. Make `test_gbnf_grammar()` place the scaffold grammar in its active masking
   state and assert the current documented even/odd masking behavior.
3. Make `test_dequantization_kernels()` assert at least one deterministic output
   property after each dispatched scaffold kernel, without claiming the toy
   layouts are compatible with the named external formats.
4. Add an explicit result assertion to any synthetic forward-pass or formatter
   test that currently checks only that execution returned, where the existing
   local contract exposes a deterministic value.

These refinements do not validate ONNX files, Hugging Face network transfer,
real GPUs/NPUs, real compressed model formats, HTTP conformance, resilience,
threading, or swarm execution.

## Negative-Proof Gate

After the implementation passes normally:

1. Temporarily corrupt one stable `GGMLType` expectation in
   `test_gguf.mojo` using a one-line patch.
2. Run that test executable and require a nonzero exit.
3. Confirm the raised error identifies the failed invariant.
4. Restore the exact source line with another explicit patch.
5. Re-run the focused test and require a zero exit.
6. Re-run the entire master suite and require a zero exit.
7. Confirm no temporary mutation remains in the final diff.

This is a behavioral acceptance gate, not a permanent intentionally failing
test.

## Implementation Phases

### Phase 1 — Propagation inventory

1. Enumerate all current `FAIL` prints and bare failure returns.
2. Classify each as direct, accumulated, wrapper, or informational skip.
3. Mark every affected call chain `raises`.

### Phase 2 — Fail-closed conversion

1. Replace terminal `FAIL`-only branches with raised errors.
2. Replace the two KV-cache early returns with raised errors.
3. Preserve useful mismatch values as diagnostic output where needed.
4. Ensure `PASS` is unreachable after a false assertion.

### Phase 3 — Undefined and vacuous test repair

1. Initialize speculative logits.
2. Exercise and inspect grammar masking.
3. Inspect deterministic dequantization output instead of an unchanged Boolean.
4. Add any other narrowly necessary deterministic result assertion discovered
   during compilation.

### Phase 4 — Verification

1. Run each materially changed test module directly.
2. Run `tests/run_all.mojo`.
3. Perform the deliberate-mutation negative-proof gate.
4. Re-run the restored focused test and master suite.
5. Run the opt-in real-GGUF proof against the pinned model.
6. Build the CLI from a clean output path.

### Phase 5 — Living documentation

1. Update the test README and interface contract.
2. Update the parent reality audit statuses without erasing remaining test
   weakness findings.
3. Correct the TODO regression for the already verified multi-token milestone.
4. Record Forge 0A evidence in `DEVLOG.md`.
5. Mark this task complete only after every acceptance gate passes.

## Expected Files

- this task document
- `aesir_engine/tests/run_all.mojo` if propagation or final wording requires it
- the 12 affected test modules listed above
- any additional affected test module required by raising-call propagation
- `aesir_engine/tests/README.md`
- `aesir_engine/tests/INTERFACE.md`
- `PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md`
- `TODO.md`
- `DEVLOG.md`

No runtime implementation file is expected to change. If a test exposes a real
runtime defect, that defect must be reported and separately scoped rather than
silently repaired inside this verification-semantics task.

## Constraints

- Mojo remains the only executable implementation language.
- No public runtime function, test function, or file is deleted.
- No model weight, generated binary, cache, or absolute local fixture path is
  committed.
- No simulated subsystem is relabeled real because its synthetic test passes.
- No hardware, network, concurrency, server, compressed-format, or distributed
  completion claim is added.
- No broad runtime refactor is bundled into this task.
- Existing test order remains deterministic.
- External fixtures remain opt-in and outside the repository.
- All unrelated user changes are preserved.

## Acceptance Criteria

- Every master-suite mismatch path now raises or propagates a raised error.
- Both KV-cache early-return failures now raise.
- A deliberate stable-expectation mutation exits nonzero.
- The restored focused test exits zero.
- The normal master suite exits zero.
- The final master success banner is printed only on a complete pass.
- Speculative logits are initialized before being read.
- Grammar and dequantization scaffold tests inspect deterministic output.
- The RAG external integration boundary remains explicitly skipped.
- The real-GGUF integration test passes with its pinned fixture.
- A clean CLI build succeeds.
- `git diff --check` passes.
- No deliberate mutation, model file, binary, secret, cache, or unrelated file
  remains in the final change set.
- Documentation explicitly distinguishes fail-closed synthetic assertions from
  real capability evidence.

## Explicit Non-Goals

- counted test aggregation or continue-after-failure execution;
- migration to an external unit-test framework;
- real GPU or NPU execution;
- correct external compressed-format implementations;
- ONNX graph parsing;
- Hugging Face network downloads;
- production model-store semantics;
- real HTTP request serving;
- grammar parsing or state-machine implementation;
- complete speculative decoding;
- real checkpoint persistence, event delivery, threading, or recovery;
- distributed swarm transport;
- test renaming and the full capability ledger planned for Forge 0B; and
- fixing unrelated runtime defects found by the reality audit.

Those remain open, numbered work in
`PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md`.

