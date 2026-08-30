# TESTING PROTOCOL — Project Æsir

## Authority

This document defines how testing works in Project Æsir. It is enforced by the Auditor role and referenced by the capability ledger system. No feature reaches Verified status without satisfying the requirements defined here.

The ENGINEERING_DOCTRINE.md establishes that testing is mandatory. This document establishes what testing actually means.

If the doctrine and this protocol disagree, the doctrine wins on philosophy. This protocol wins on procedure.

---

## Section One: Test Directory Structure

```
aesir_engine/tests/
├── run_all.mojo                 # counted master orchestrator
├── test_ledger.mojo             # pass/fail/skip accounting
├── test_<domain>.mojo           # focused domain and boundary cases
├── test_real_gguf.mojo          # opt-in registered external reference
├── test_fail_closed_runner.mojo # intentional CI negative control
└── fixtures/
    └── README.md                # canonical tracked-fixture boundary; no payloads
```

### Directory Rules

- **`test_<domain>.mojo`** — Current tracked unit, boundary, integration, and
  regression cases are grouped by owning domain.
- **`fixtures/`** — The only approved tracked fixture-data boundary. Every
  payload must be registered in `fixture_manifest.json`; there are currently no
  tracked payloads.
- **External references** — Model weights remain outside Git and are supplied
  only to opt-in tests after their manifest identity is verified.

### File Naming

Test files use `test_[subject].mojo` format. Subjects are snake case and describe what is being tested, not what module is being tested.

Good:
- `test_kv_cache_allocation.mojo`
- `test_bpe_merge_application.mojo`

Bad:
- `test_mimir_mojo`
- `test_stuff.mojo`
- `test_things_that_matter.mojo`

---

## Section Two: Test Types and When to Write Them

### Unit Tests

Write unit tests for:
- Pure functions with deterministic outputs
- Parser and serializer logic
- Data structure operations (insert, lookup, removal)
- Algorithm implementations (sorting, searching, reduction)
- Error path handling for expected failure modes

Unit tests must:
- Execute in under one second each
- Require no network access
- Require no GPU
- Require no files outside the fixtures directory
- Be deterministic (same input always produces same output)

### Boundary Tests

Write boundary tests for:
- Interface contracts between domains
- Public API entry points
- Serialization round trips (serialize then deserialize, verify equivalence)
- Error propagation across module boundaries

Boundary tests verify that modules honor their published interfaces. They do not test internal implementation details. If a boundary test breaks because of an internal change, the interface contract was violated.

### Integration Tests

Write integration tests for:
- End-to-end request processing (HTTP request in, token stream out)
- Model loading through inference execution
- Concurrent request handling
- Memory pressure scenarios

Integration tests:
- May require GPU access
- May take longer to execute (seconds, not milliseconds)
- Must use a registered fixture identity, never an ad hoc download or local path
- Must clean up all allocated resources after execution

### Regression Tests

Write regression tests when:
- A bug is reported and fixed
- A capability ledger downgrade occurs (something believed working is discovered broken)
- An edge case is identified that the original tests missed

Regression tests:
- Are named after the issue identifier: `test_issue_NNN_description.mojo`
- Include a comment block at the top describing the original bug
- Test the specific scenario that triggered the bug
- Must fail if the bug is reintroduced

### Invariant Tests

Write invariant tests for:
- Properties that must always hold regardless of implementation changes
- Save/load round trip integrity
- Entity ID stability across reloads
- Deterministic ordering where required
- Memory safety properties (no leaks, no double-free)

Invariant tests:
- Run on every CI pass
- Must never be skipped or marked as optional
- Document the invariant being tested in a comment block

---

## Section Three: Writing Tests in Mojo

### Basic Test Structure

```mojo
from testing import assert_equal, assert_true, assert_false, assert_raises

fn test_kv_cache_block_alignment() raises:
    """
    Invariant: KV cache blocks must be aligned to BLOCK_SIZE boundaries.
    PagedAttention requires aligned offsets for correct page table indexing.
    """
    var cache = KVCache(block_size=32, max_blocks=128)
    var block = cache.allocate(seq_id=1, token_count=40)
    
    # 40 tokens require 2 blocks of 32 (32 + 8 remainder)
    assert_equal(block.block_count, 2)
    assert_equal(block.physical_offsets[0] % 32, 0)
    assert_equal(block.physical_offsets[1] % 32, 0)
```

### Test Function Naming

All test functions begin with `test_`. Use descriptive names that state what is being verified.

Good:
- `fn test_bpe_handles_unicode_input() raises:`
- `fn test_kv_cache_evicts_least_recently_used() raises:`

Bad:
- `fn test_cache():`
- `fn test_it_works() raises:`

### Assertion Usage

Use the most specific assertion available:

```mojo
# Exact equality
assert_equal(actual, expected, "KV cache block count mismatch")

# Boolean conditions
assert_true(cache.is_full(), "Cache should report full after exhausting blocks")
assert_false(cache.has_capacity(), "Cache should report no capacity when full")

# Expected errors
assert_raises(KVCacheError):
    cache.allocate(seq_id=99, token_count=0)  # Invalid: zero tokens

# Floating point with tolerance
assert_almost_equal(computed_logits[0], expected_logit, tolerance=1e-5)
```

Assertion messages are mandatory. An assertion without a message is a debugging liability. When it fails at 3 AM, the message is all you have.

### Test Independence

Every test must be independent. No test may depend on another test having run first. No test may leave state that affects subsequent tests.

If a test requires setup, perform the setup within the test function itself or use a setup helper that is called at the start of each test. Do not rely on test execution order.

```mojo
# Good — self-contained
fn test_session_creation() raises:
    var engine = create_test_engine()
    var session = engine.create_session(model_path=TINY_TEST_MODEL)
    assert_true(session.is_active(), "Session should be active after creation")
    session.close()

# Bad — depends on previous test
var shared_engine: AesirEngine  # Global state

fn test_setup():
    shared_engine = create_test_engine()

fn test_session_creation():  # Assumes test_setup ran first
    var session = shared_engine.create_session(...)
```

### Fixture Loading

Tracked fixtures resolve from `aesir_engine/tests/fixtures/` and must match the
path, size, and SHA-256 registered in `fixture_manifest.json`. External
references are caller-supplied after checksum verification; tests must not
hardcode machine-local paths or download them implicitly.

### Test Helpers

Shared test utilities must remain in the tests domain, contain no independently
reported test cases, and preserve the manifest and evidence boundaries of any
fixture they consume.

---

## Section Four: Coverage Expectations

### Per-Domain Minimum Coverage

| Domain | Unit Test Coverage | Integration Test Coverage | Notes |
|--------|-------------------|--------------------------|-------|
| AesirEngine | 80% | Required | Coordinator logic is critical |
| MimirWell | 90% | Required | Memory bugs are catastrophic |
| BifrostGate | 80% | Required | API compatibility is contractual |
| RuneWeaver | 95% | Required | Tokenization errors corrupt everything downstream |
| GGUFSeer | 90% | Required | Malformed files must not crash the engine |
| Hladgerð | 85% | Required | Weight corruption produces garbage output |
| Mjølnir | 70% | Required | GPU code is harder to unit test; integration picks up slack |

### What Counts as Covered

A function is covered if:
1. At least one test exercises the happy path (normal successful operation)
2. At least one test exercises a failure path (expected error condition)
3. At least one test exercises an edge case (empty input, maximum input, boundary values)

A module is covered if all public functions meet the above criteria and at least one integration test exercises the module through its published interface.

### What Does Not Count as Covered

- Calling a function in a test without asserting on the result
- Asserting only that no exception was raised (unless the function's contract is purely "does not crash")
- Tests that are marked as skipped or disabled
- Tests that pass because they test nothing (tautological tests)
- Coverage generated by integration tests alone for modules that require unit-level verification

---

## Section Five: The Anti-Simulation Clause

Tests exist to prove that code works. They do not exist to create the appearance that code works.

### Forbidden Test Patterns

**Mock Injection Fraud**: Replacing a real dependency with a mock that always returns success, then claiming the function under test works. The test proves nothing about real behavior.

**Hardcoded Expected Output**: Writing a test that asserts a function returns a specific value, where that value was obtained by running the function once and copying the output. This proves the function is deterministic, not that it is correct.

**Vacuous Assertion**: Asserting `assert_true(True)` or `assert_equal(x, x)`. These tests pass forever and verify nothing.

**Catch-All Pass**: Wrapping a function call in a try/except that catches everything and marks the test as passed regardless of outcome.

**Shadow Implementation**: reimplementing the function's logic inside the test and asserting the function matches the test's own reimplementation. This proves the function agrees with itself.

### Required Test Patterns

**Known-Answer Tests**: For parsers, tokenizers, and serializers, use externally verified expected outputs. The BPE tokenizer test should use token IDs from the original tokenizer's published output, not values generated by our own implementation.

**Property-Based Tests**: For mathematical operations, verify properties that must hold regardless of input. Softmax output sums to 1.0. Dot product is symmetric. Concatenation preserves length.

**Round-Trip Tests**: Serialize then deserialize. Encode then decode. Save then load. The output must equal the input within defined tolerance.

**Negative Tests**: Deliberately malformed input must produce the expected error, not a crash, not a silent acceptance, not a garbled output.

---

## Section Six: Running Tests

### Standard Test Execution

```bash
# Run all tests
mojo test tests/

# Run unit tests only
mojo test tests/unit/

# Run a specific domain's tests
mojo test tests/unit/rune_weaver/

# Run a specific test file
mojo test tests/unit/rune_weaver/test_bpe_encoding.mojo

# Run integration tests (may require GPU)
mojo test tests/integration/

# Run invariant tests only
mojo test tests/invariant/
```

### CI Pipeline Expectations

The CI pipeline must run:
1. All unit tests on every push
2. All invariant tests on every push
3. All integration tests on pull requests to development
4. All regression tests on every push

Any test failure halts the pipeline. No "known failures" are tolerated. If a test is flaky, fix the flakiness or remove the test. Flaky tests are worse than no tests because they train contributors to ignore failures.

### Performance Test Execution

Performance tests live in `tests/performance/` and are run separately from the standard suite. They measure against the budgets defined in PERFORMANCE_BUDGETS.md (when that document exists).

```bash
# Run performance benchmarks
mojo test tests/performance/ -- --benchmark
```

Performance tests do not block CI by default. They produce reports. The human coordinator reviews trends over time. A sudden 20% regression triggers investigation regardless of whether the tests formally fail.

---

## Section Seven: Test Data Management

### Fixture Integrity

Fixture identities are immutable. A changed byte sequence receives a new stable
ID and path. `fixture_manifest.json` classifies every admitted fixture as
`synthetic`, `malformed`, `regression`, or `external-reference` and records its
owner, purpose, consumer, evidence boundary, license, exact size, checksum, and
construction or immutable source. CI validates this policy with
`scripts/check_fixture_manifest.py`.

### Generated Test Data

Some tests require generated data (random tensors, randomized token sequences). Generated data must use a fixed seed.

```mojo
from random import Random

fn test stochastic_sampling() raises:
    var rng = Random(seed=42)  # Fixed seed for reproducibility
    var sampler = Sampler(temperature=0.7, top_k=40, rng=rng)
    var result = sampler.sample(test_logits)
    
    # Same seed, same input, same output — every time
    assert_equal(result.token_id, EXPECTED_TOKEN_ID_SEED_42)
```

### Test Model

No model weight is committed as a test fixture. The one registered real-model
reference is `gguf.stories260k-f16-v3`; its immutable source revision, exact
size, SHA-256, MIT license, consumer, and independent `llama.cpp` oracle live in
`fixture_manifest.json`. It remains an opt-in external dependency and is not
evidence unless the real-model command actually executes successfully.

---

## Section Eight: The Auditor Verification Checklist

Before any feature is upgraded to Verified in the capability ledger, the Auditor role must complete this checklist. Every item must be confirmed. No skipping. No "close enough."

### Checklist

```
AUDITOR VERIFICATION CHECKLIST
===============================

Feature: _________________________________
Domain: _________________________________
Date: _________________________________
Auditor Agent: _________________________________

--- Code Review ---

[ ] Implementation matches the interface contract
[ ] No hardcoded values where computation should occur
[ ] No single-quote string literals present
[ ] No absolute file paths present
[ ] Error handling covers expected failure modes
[ ] No silent error swallowing
[ ] Memory allocations are paired with frees
[ ] No orphaned functions (every function has a caller or is public API)
[ ] Comments explain why, not what
[ ] Domain boundaries respected (no cross-domain internal access)

--- Test Review ---

[ ] Happy path test exists and passes
[ ] Failure path test exists and passes
[ ] Edge case test exists and passes
[ ] Test names are descriptive
[ ] Assertions have messages
[ ] Tests are independent (no execution order dependency)
[ ] No forbidden test patterns detected (mock fraud, vacuous assertions, etc.)
[ ] Fixtures used are committed and documented
[ ] Generated data uses fixed seeds

--- Execution Verification ---

[ ] Full unit test suite passes
[ ] Full invariant test suite passes
[ ] Integration test for this feature passes
[ ] No new warnings or errors in test output
[ ] Test execution time has not increased by more than 10%

--- Documentation ---

[ ] Relevant INTERFACE.md updated if API changed
[ ] `docs/DOMAIN_MAP.md` updated if ownership shifted
[ ] DEVLOG entry written for the verification
[ ] CAPABILITY_LEDGER.md updated to Verified with date and evidence

--- Final Confirmation ---

I confirm that this feature has been verified according to the testing protocol.
The implementation is honest, the tests are substantive, and the capability
ledger accurately reflects the current state.

Signature: [Auditor Agent Identifier]
```

### Checklist Enforcement

The checklist is not advisory. It is procedural law. An Auditor who skips items is derelict. A Forge Worker who claims Verified status without Auditor sign-off is dishonest.

The human coordinator may override the Auditor in exceptional circumstances (e.g., a feature that cannot be fully tested without hardware that is unavailable). Such overrides must be documented in the DECISIONS log with rationale.

---

## Section Nine: Handling Test Failures

### When a Test Fails

1. **Do not delete the test.** A failing test is a signal. Deleting it kills the messenger.
2. **Do not weaken the assertions.** If the test asserted correctness and correctness failed, the code is wrong, not the test.
3. **Investigate the root cause.** Use the debugging playbook (when it exists) or trace the failure to its source.
4. **Fix the code, not the test.** Unless the test itself contains a bug (wrong expected value, incorrect setup), the code is the suspect.
5. **Record the failure.** Add a DEVLOG entry describing what failed, why, and how it was fixed.
6. **Consider a regression test.** If the failure revealed an edge case not covered by existing tests, add one.

### When a Test Is Flaky

Flaky tests (tests that sometimes pass and sometimes fail without code changes) are unacceptable. They undermine confidence in the entire test suite.

1. **Quarantine the test immediately.** Move it to `tests/quarantine/` and mark it with a `FLAKY` prefix.
2. **Investigate the nondeterminism source.** Common causes: race conditions, unordered iteration, time-dependent logic, uninitialized memory, floating-point precision variations.
3. **Fix the root cause.** Make the test deterministic or fix the race condition in the code.
4. **Restore the test.** Once reliably passing, move it back to its proper location.

A quarantined test that remains unfixed for more than one week must be either fixed or permanently removed with a DECISIONS entry explaining why.

### When Tests Cannot Be Written

Some functionality is inherently difficult to test:
- GPU kernel correctness (requires GPU access and comparison against reference implementations)
- Performance characteristics (require benchmarking infrastructure)
- Numerical stability across architectures (floating-point behavior varies)

In these cases:
1. Document why the test cannot be written in the standard manner
2. Provide an alternative verification method (manual test script, inspection procedure, property-based invariant)
3. Record the limitation in the capability ledger as Partial, not Verified
4. Note the gap in TECH_DEBT.md if it exists

Partial status with honest documentation is superior to Verified status with inadequate testing.

---

## Section Ten: Test Maintenance

### Periodic Review

Every sprint or development cycle, the Auditor role reviews the test suite for:

- **Dead tests**: Tests for features that no longer exist or have been replaced
- **Redundant tests**: Multiple tests verifying the same property with no added value
- **Outdated fixtures**: Fixture files that no longer match current data formats
- **Missing coverage**: New features added without corresponding tests
- **Degraded assertions**: Tests whose assertions have been weakened over time

### Test Retirement

Tests are retired when:
- The feature they test has been removed from the codebase
- The test has been superseded by a more comprehensive test
- The test verifies a property that is no longer relevant

Retired tests are deleted, not commented out. A deletion requires a DEVLOG entry explaining why.

### Test Promotion

As the project matures, some unit tests may be promoted to integration tests or invariant tests:
- A unit test that began testing a single function but now effectively tests a module boundary becomes an integration test
- A unit test that verifies a property that must always hold becomes an invariant test

Promotion requires moving the test to the appropriate directory and updating its registration.

---

## Section Eleven: Quick Reference Card

```
BEFORE WRITING CODE:
□ What domain owns this?
□ What interface does it publish?
□ What tests exist for this domain?

BEFORE CLAIMING DONE:
□ Unit tests written and passing?
□ Failure paths tested?
□ Edge cases tested?
□ No forbidden test patterns?
□ Assertions have messages?

BEFORE UPGRADING TO VERIFIED:
□ Auditor checklist completed?
□ Full test suite passes?
□ Capability ledger updated with evidence?
□ DEVLOG entry written?

COMMIT FORMAT:
test: [description]      # New tests
fix: [description]        # Bug fixes with regression test
audit: [description]      # Verification or capability ledger update
```

---

## Closing Principle

Tests are not paperwork. They are not bureaucracy. They are the immune system of the codebase.

Every test you write is a claim about reality. Every test you skip is a gamble that the code is correct without evidence. In a project built by AI agents collaborating asynchronously, gambles aggregate catastrophically.

Write tests that mean something. Run them. Believe them when they fail. Fix the code.

The machine does not lie. The test suite is how you listen to it.

---

*Last updated: 2026-08-15. Maintained by the Auditor role. Changes require Architect review.*

---
