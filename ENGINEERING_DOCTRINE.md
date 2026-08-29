# ENGINEERING DOCTRINE — Project Æsir

(ENGINEERING_DOCTRINE.md)

## Authority and Purpose

This document is the operational law for all AI agents and human contributors working on Project Æsir. It supersedes improvisation. It overrides stylistic preference. It binds every commit, every file, every architectural decision.

Project Æsir is a bare-metal Mojo LLM inference engine. It is not a Python wrapper. It is not a frontend. It is not a demonstration. It is a production-track system designed to run language models on local hardware with zero cloud dependency, zero telemetry, and zero compromise on performance.

If you are working on this project, you are building infrastructure. Act like it.

---

## Section One: The Cardinal Laws

These laws are immutable. Violating them introduces bugs, technical debt, and architectural rot. Any commit that breaks a Cardinal Law must be reverted or repaired before further work proceeds.

### Law One: Complete Files Only

Never submit partial files. Never submit pseudocode. Never submit placeholder implementations disguised as working code. If a function exists, it must work. If it does not work, it must be clearly marked as scaffold with a `TODO` referencing the blocker.

Acceptable:
```mojo
# Scaffold: Waiting for GGUFSeer tensor metadata parsing to expose dtype
# Blocked by: PR #47, tensor_metadata struct finalization
# Owner: Agent-ForgeWorker
fn load_tensor_weights(tensor_id: Int) -> TensorData:
    # TODO: Implement once TensorMetadata.dtype field lands
    return TensorData.empty()
```

Unacceptable:
```mojo
fn load_tensor_weights(tensor_id: Int) -> TensorData:
    return TensorData.fake_success()  # Hope nobody notices
```

The difference is honesty. The capability ledger exists for a reason. Use it.

### Law Two: Robust and Self-Healing Code

Every subsystem must handle failure gracefully. No panics. No unhandled exceptions propagating to the caller. No crashes on malformed input.

Wrap external operations in error handling. Validate inputs at boundaries. Return error types, not thrown exceptions, for expected failure modes. Reserve exceptions for truly exceptional circumstances.

```mojo
fn parse_gguf_header(data: UnsafePointer[UInt8], size: Int) -> Result[GGUFHeader, ParseError]:
    if size < MIN_HEADER_SIZE:
        return Err(ParseError.TruncatedHeader)
    var magic = data.load[width=4](0)
    if magic != GGUF_MAGIC_BYTES:
        return Err(ParseError.InvalidMagic)
    # ... continued parsing with validation at each step
    return Ok(header)
```

### Law Three: Location Agnosticism

No absolute paths. Ever. Not in code. Not in configs. Not in documentation. Not in tests.

The project must be cloneable to any directory on any machine and function identically. Use relative paths from the project root. Use environment variables for system-specific configuration. Use the project's internal path resolution utilities.

Scan for absolute paths before every commit. This is not optional.

### Law Four: Finish Connections

Never leave integrations incomplete. If module A calls module B, the interface must be fully implemented on both sides. Stub functions with no caller are orphaned code. Stub callers with no implementation are dangling references.

Before committing, verify:
- Every function called has an implementation
- Every implemented function has at least one caller or is explicitly marked as public API
- Every import resolves
- Every type reference exists

### Law Five: Data Lives in Data Files

Settings belong in configuration files. Model metadata belongs in data files. NPC definitions belong in data files. Tokenizer vocabularies belong in data files.

Hardcoding data in source code couples that data to the compilation cycle. It makes updates require rebuilds. It scatters truth across hundreds of files.

If you find yourself typing a literal value that represents configurable behavior, stop. Create a data file. Load it at runtime.

### Law Six: Double Quotes Always

All string literals use double quotes (`"text"`). Never single quotes (`'text'`).

This is not aesthetic preference. It is consistency law. Mixed quoting styles create parsing ambiguities, diff noise, and reviewer fatigue. The entire codebase uses double quotes. Conform.

---

## Section Two: Architecture and Ownership

### The Domain Map

Project Æsir is organized into domains. Each domain owns specific responsibilities and must not bleed into others.

| Domain | Core Module | Owns | Does Not Own |
|--------|------------|------|--------------|
| Inference Coordination | AesirEngine | Orchestration, scheduling, request lifecycle | Tokenization, weight loading, HTTP serving |
| Memory Management | MimirWell | KV cache, paged attention, memory allocation | Model architecture, request routing |
| Model Transport | BifrostGate | HTTP API, request/response marshalling | Inference execution, memory management |
| Tokenization | RuneWeaver | BPE encoding/decoding, vocab management | Inference, model loading |
| Model Parsing | GGUFSeer | GGUF file parsing, tensor extraction, metadata | Tokenization, inference |
| Weight Management | Hladgerð | Weight loading, quantization, conversion | File parsing, inference execution |
| Compute Execution | Mjølnir | Forward pass, attention computation, sampling | Memory allocation, request handling |

### Boundary Rules

A module may only depend on modules in its own domain or explicitly designated interface modules. Circular dependencies are forbidden. The dependency graph must be acyclic.

If you need functionality from another domain, consume it through its published interface, not through internal implementation details. Interface files (`INTERFACE.md`) define what is public. Anything not in the interface is internal and may change without warning.

### When Boundaries Blur

If you find yourself needing to reach across domains for functionality that does not exist, do not hack it. Either:
1. Extend the target domain's interface to expose the needed capability
2. Create a new domain that owns the shared concern
3. Raise the issue for architectural review

Shortcutting boundaries creates the Ball of Mud anti-pattern. Every shortcut taken today costs ten hours of refactoring tomorrow.

---

## Section Three: The Development Workflow

### Role-Based Operation

Contributors operate as one of six specialized roles during any work session. Switch roles consciously. Do not blur role boundaries.

**Skald** — Vision, naming, philosophy, conceptual framing. Use when starting new features, naming modules, writing project-level documentation.

**Architect** — Boundary definition, ownership assignment, structural planning. Use when designing new modules, planning refactors, resolving ownership disputes.

**Cartographer** — System mapping, dependency tracing, impact analysis. Use when understanding how a change propagates, when onboarding to unfamiliar code, when preparing for major modifications.

**Forge Worker** — Implementation, testing, mechanical construction. Use when writing code, fixing bugs, building features.

**Auditor** — Verification, contradiction detection, edge-case analysis. Use when reviewing code, testing claims, finding weaknesses.

**Scribe** — Documentation, continuity preservation, record keeping. Use when ending sessions, recording decisions, updating docs.

### Session Structure

Every work session follows this rhythm:

**Opening (5-10 minutes)**
1. Cartographer reviews current system state and recent changes
2. Scribe reads the latest DEVLOG entry
3. Architect restates the active boundary being worked on
4. Auditor restates any open verification items

**Main Work**
1. Skald clarifies the vision for the current task
2. Architect confirms boundaries and ownership
3. Forge Worker implements
4. Auditor verifies

**Closing (10-15 minutes)**
1. Auditor runs full verification pass
2. Scribe updates DEVLOG, capability ledger, and any drifted documentation
3. Commit with clear message following the commit format

### Task Selection

Before starting work, read `TODO.md` and `CAPABILITY_LEDGER.md`. Pick tasks that are:
- Blocking other work (highest priority)
- Marked as scaffold or missing in the capability ledger
- Within your current role's domain of competence

Never pick a task randomly. Never start work without understanding what depends on it and what it depends on.

---

## Section Four: Mojo Code Standards

### Style

- Four-space indentation. No tabs.
- Snake case for variables and functions: `load_tensor_weights`
- PascalCase for structs and traits: `GGUFHeader`, `TensorParser`
- UPPER_CASE for compile-time constants: `MAX_CONTEXT_LENGTH`
- Lines under 100 characters where possible
- One statement per line
- No trailing whitespace

### Type Annotations

Every function parameter, return type, and variable must have an explicit type annotation. Rely on type inference only for obviously clear local assignments.

```mojo
# Good
fn compute_attention(query: SIMD[DType.float32, 128], key: SIMD[DType.float32, 128]) -> Float32:
    var score: Float32 = query.dot(key)
    return score

# Bad
fn compute_attention(query, key):
    var score = query.dot(key)
    return score
```

### Error Handling

Use `Result` types for expected failure modes. Use `raises` only for truly exceptional circumstances that should propagate upward. Never swallow errors silently.

```mojo
# Good
fn load_model(path: String) -> Result[LoadedModel, LoadError]:
    var parsed = GGUFSeer.parse(path)?
    var weights = Hladgerð.load(parsed)?
    return Ok(LoadedModel(parsed, weights))

# Bad
fn load_model(path: String) -> LoadedModel raises:
    var parsed = GGUFSeer.parse(path)  # Might fail silently
    var weights = Hladgerð.load(parsed)  # Might fail silently
    return LoadedModel(parsed, weights)
```

### Memory Safety

Prefer value semantics. Use `UnsafePointer` only when performance demands it and the lifetime is provably safe. Always pair `alloc` with `free`. Never return pointers to stack memory.

```mojo
# Good — ownership transferred, caller responsible
fn create_buffer(size: Int) -> UnsafePointer[Float32]:
    return UnsafePointer[Float32].alloc(size)

# Bad — dangling pointer
fn get_temp_buffer(size: Int) -> UnsafePointer[Float32]:
    var temp = UnsafePointer[Float32].alloc(size)
    return temp  # Caller has no idea they need to free this
```

### Comments

Comment the why, not the what. Code should explain what it does. Comments should explain why it does it.

```mojo
# Good
# PagedAttention requires block-aligned offsets for correct page table indexing
var aligned_offset = (offset + BLOCK_SIZE - 1) & ~(BLOCK_SIZE - 1)

# Bad
# Align the offset
var aligned_offset = (offset + BLOCK_SIZE - 1) & ~(BLOCK_SIZE - 1)
```

Use Norse cosmological metaphors for architectural comments where they aid comprehension:

```mojo
# Huginn retrieves cached context from MimirWell — memory precedes thought
var cached_context = mimir_well.retrieve(session_id)
```

---

## Section Five: Testing and Verification Doctrine

### The Capability Ledger

Every feature in Project Æsir is tracked in `CAPABILITY_LEDGER.md` with one of five statuses:

| Status | Meaning |
|--------|---------|
| Verified | Implemented, tested, confirmed working with evidence |
| Partial | Implemented but incomplete or lacking test coverage |
| Scaffold | Structure exists but functionality is stubbed |
| Simulated | Appears functional but returns hardcoded/mock responses |
| Missing | Not implemented at all |

Any agent claiming a feature works must upgrade its status to Verified with accompanying test evidence. Any agent discovering a feature is simulated or scaffold must downgrade its status immediately.

This is the honesty system. It is the backbone of project integrity. Lies in the capability ledger are worse than bugs in the code.

### Test Requirements

Every new feature must include:
1. Unit tests for the core logic
2. Boundary tests for interface contracts
3. At least one integration test exercising the feature through its public API
4. A regression test if fixing a bug

Tests must be runnable with a single command:
```bash
mojo test tests/
```

### Verification Before Claims

Before stating that any feature works:
1. Run the tests
2. Confirm they pass
3. Exercise the feature manually if possible
4. Record evidence in the DEVLOG
5. Update the capability ledger

Claims without evidence are noise. The Auditor role exists to destroy unsubstantiated claims.

### Fail-Closed Semantics

When a test fails, the system must fail closed. No fallback to mock behavior. No silent degradation. No "close enough" tolerances.

A failing test is a signal. Fix the code or fix the test. Never mute the signal.

---

## Section Six: Documentation Requirements

### Required Documents

Every domain folder must contain:
- `README.md` — Purpose, contents, boundaries
- `INTERFACE.md` — Public API, inputs, outputs, invariants

The project root must maintain:
- `README.md` — Project overview, build instructions, usage
- `ARCHITECTURE.md` — System structure, domain relationships, data flow
- `docs/DOMAIN_MAP.md` — Ownership boundaries, what each domain does and does not do
- `CAPABILITY_LEDGER.md` — Feature status tracking
- `DEVLOG.md` — chronological record of significant changes
- `TODO.md` — Canonical outstanding work items with priorities

### Documentation Hygiene

Documentation must match reality. If you change code, update docs in the same commit. If you discover docs that disagree with code, either fix the code to match docs or fix the docs to match code. Never leave them in disagreement.

The Scribe role polishes documentation. But every contributor is responsible for keeping docs honest about their own changes.

### The DEVLOG Format

```markdown
## YYYY-MM-DD — Agent Identifier

### Completed
- [Brief description of what was accomplished]

### Changed
- [Files modified and why]

### Verified
- [Tests run, results obtained]

### Discovered
- [Issues found, risks identified, observations recorded]

### Next
- [What the next session should tackle]
```

---

## Section Seven: Plundering and External Integration

When studying or adapting code from external open-source projects (vLLM, llama.cpp, ggml, etc.), follow the plundering workflow:

1. **License Gate** — Verify the upstream license permits reuse. Apache-2.0 and MIT are clean. GPL is contagious. Check before touching.

2. **Intent Recording** — Document why the external code is being studied and what specific problem it solves. Write this to `docs/plunder/[PROJECT]_GUIDE.md`.

3. **Pattern Extraction** — Prefer extracting architectural patterns over copying code. Mojo is not Python. Mojo is not C++. Direct copies usually require significant adaptation anyway.

4. **Attribution** — If code or architecture is adapted, record it in `THIRD_PARTY_NOTICES.md`. Add file headers noting derivation. Never hide upstream origin.

5. **Boundary Assignment** — Plundered code must be assigned to a local domain. It does not get to exist outside the architecture. It conforms to our boundaries or it does not enter.

6. **Verification** — Plundered code is untrusted until proven. Test it. Audit it. Confirm it meets our standards.

---

## Section Eight: Common Failure Modes

### Simulated Success

**Symptom**: A function returns plausible-looking output without actually performing the work. Usually involves hardcoded values or simplified approximations.

**Detection**: The Auditor role checks for hardcoded return values, unused parameters, and functions that always succeed regardless of input.

**Correction**: Mark as Simulated in the capability ledger. Implement real logic. Upgrade to Verified only after testing proves it works.

### Architectural Drift

**Symptom**: A module gradually accumulates responsibilities outside its domain. The boundary blurs. Dependencies proliferate.

**Detection**: If a module's README can no longer describe its purpose in one sentence, it has drifted.

**Correction**: The Architect role extracts the foreign logic and relocates it to the correct domain. Update all interfaces. Run full test suite.

### Naming Decay

**Symptom**: Names that once matched their purpose now describe something different. The function is called `parse_token` but it also validates, normalizes, and caches.

**Detection**: During review, if a name requires explanation beyond its literal meaning, it has decayed.

**Correction**: Rename to reflect current responsibility. Or better, split the function so the name remains accurate.

### Silent Coupling

**Symptom**: Two modules communicate through undocumented channels — shared globals, side effects, implicit ordering assumptions.

**Detection**: Remove one module and see what breaks in unexpected places.

**Correction**: Make all communication explicit through published interfaces. Document the dependency. Test the contract.

### Premature Generalization

**Symptom**: Code is built to handle hypothetical future cases that never materialize. Complexity increases without delivering value.

**Detection**: If you cannot point to a concrete current requirement driving a generalization, it is premature.

**Correction**: Strip to what is needed now. Leave extensibility hooks, not implementations of imaginary features.

---

## Section Nine: Session Discipline

### Before Starting Work

1. Pull latest from the `main` integration branch
2. Read `TODO.md` for current priorities
3. Read `CAPABILITY_LEDGER.md` to understand what exists and what is scaffold
4. Read the last `DEVLOG.md` entry to understand recent context
5. Read the `INTERFACE.md` of any domain you will touch

### During Work

1. Keep the capability ledger open in a buffer
2. Refer to the domain map when uncertain about ownership
3. Run tests after every meaningful change
4. Update documentation as you go, not at the end
5. Commit in small, reviewable increments

### Before Finishing

1. Run the full test suite
2. Update the capability ledger with any status changes
3. Write a DEVLOG entry
4. Update `TODO.md` if tasks were completed or discovered
5. Push the feature branch and open it against `main`
6. Confirm the working tree is clean

### Commit Message Format

```
[type]: [brief description]

[optional body explaining motivation and approach]

[optional footer noting breaking changes or related issues]
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `audit`

Examples:
```
feat: implement BPE token caching in RuneWeaver
fix: correct KV cache block alignment in MimirWell
audit: downgrade GGUFSeer.tensor_extraction from Verified to Partial
docs: update AesirEngine INTERFACE.md with new session lifecycle methods
```

---

## Section Ten: The Prime Directive

Every line of code in this project must serve the goal: a bare-metal Mojo LLM inference engine that runs on local hardware, respects user sovereignty, and delivers performance without bloat.

If a change does not serve this goal, it does not belong in this repository.

If a feature adds complexity without advancing the core mission, reject it.

If an optimization trades correctness for speed, reject it.

If a dependency introduces external control, reject it.

The machine does not lie. The terminal is the only honest interface. Build accordingly.

---

*This document is law within Project Æsir. It evolves through proposal and agreement, not through unilateral deviation. If you believe a rule should change, raise it in a DECISIONS entry and make your case. Until then, obey.*

---

*Maintained by the Architect role. Last updated: 2026-08-15.*
