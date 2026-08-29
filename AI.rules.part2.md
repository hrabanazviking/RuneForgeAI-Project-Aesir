# Project A.E.S.I.R. AI Rules — Part 2

## Reality-First Code, Evidence, and Completion Law

**Status:** Active project law

**Established:** 2026-08-29

**Applies to:** Every AI agent, coding assistant, automated editor, reviewer,
script author, and human contributor working in this repository

**Companion law:** [`RULES.AI.md`](RULES.AI.md)

**Present-tense authority:** [`CAPABILITY_LEDGER.md`](CAPABILITY_LEDGER.md)

**Backlog authority:** [`TODO.md`](TODO.md)

**Execution and anti-fabrication authority:**
[`ROADMAP_REALITY_FIRST_COMPLETION.md`](ROADMAP_REALITY_FIRST_COMPLETION.md)

## 1. Purpose

These rules exist to prevent code that merely looks implemented. Project
A.E.S.I.R. accepts only code whose names, behavior, integration, tests,
documentation, and evidence agree.

An AI must never make the repository appear more complete than it is. When a
requested capability cannot yet be implemented or proved, the correct result is
an explicit unsupported boundary, an honest non-verified ledger status, and a
precise next acceptance gate. Plausible-looking output is not progress.

These rules are intentionally strict. They protect the project from:

- pseudocode presented as source;
- stubs presented as features;
- mocks presented as integrations;
- fixed output presented as runtime state;
- filenames presented as format compatibility;
- library probes presented as hardware execution;
- synthetic fixtures presented as external proof;
- swallowed errors presented as resilience;
- local process calls presented as networking;
- memory-only state presented as persistence;
- predetermined results presented as AI inference;
- unmeasured numbers presented as benchmarks;
- untested platforms presented as supported;
- disconnected files presented as architecture; and
- documentation claims that exceed executable reality.

## 2. Authority and Conflict Resolution

- **AUTH-001:** Direct, current instructions from Volmarr govern the requested
  scope, subject to safety and repository law.
- **AUTH-002:** `CAPABILITY_LEDGER.md` is the canonical source for current
  capability status. Filenames, comments, README prose, TODO checkboxes, test
  names, and historical documents cannot override it.
- **AUTH-003:** `TODO.md` is the canonical active backlog. A checked narrow task
  does not automatically verify its broader capability.
- **AUTH-004:** `ROADMAP_REALITY_FIRST_COMPLETION.md` defines execution order,
  evidence boundaries, and anti-fabrication admission rules.
- **AUTH-005:** `RULES.AI.md` remains active. This Part 2 supplements it with
  evidence and code-reality requirements.
- **AUTH-006:** When older generic rules conflict with observed truth, explicit
  failure, security limits, or current repository structure, this Part 2's
  reality-first interpretation controls.
- **AUTH-007:** “Never crash” means prevent uncontrolled corruption and provide
  clear errors. It never means swallowing a failure or returning success.
- **AUTH-008:** “Self-healing” is a claim requiring tested recovery. Until then,
  fail safely and describe the actual loss or restart boundary.
- **AUTH-009:** “Cross-platform” is a design goal, not a support claim. Only
  built and exercised targets may be called supported.
- **AUTH-010:** “Additive fixing” means preserve useful architecture and history.
  It does not authorize retaining fake, unsafe, or misleading behavior forever.
  Any deletion still requires Volmarr's exact approval.
- **AUTH-011:** “No data limits” never forbids necessary, explicit, tested
  security and resource ceilings for untrusted inputs.
- **AUTH-012:** Protocol constants, format magic values, algorithm constants,
  and focused test vectors are not forbidden hardcoding when their ownership,
  source, and meaning are explicit.
- **AUTH-013:** Machine-specific configuration, credentials, model paths, user
  data, and deployment policy must not be compiled into production logic.
- **AUTH-014:** The active integration branch is the branch Volmarr explicitly
  names. For the current project workflow, pushes go to the real `main` branch.
- **AUTH-015:** No AI may change Git configuration, remotes, branch protection,
  credentials, hooks, or repository settings without Volmarr's permission.

## 3. Required Vocabulary

- **TERM-001:** **Real code** performs its advertised operation on real inputs,
  through its actual owner, with defined results, side effects, errors, cleanup,
  and executable evidence.
- **TERM-002:** **Fake code** implies an operation exists when it does not, or
  substitutes a different operation without saying so.
- **TERM-003:** **Connected code** is reachable through the intended production
  entry point and is integrated with configuration, ownership, errors, tests,
  and documentation.
- **TERM-004:** **Orphan code** has no real caller, consumer, integration path,
  test purpose, or intentional archival role.
- **TERM-005:** **Scaffold** preserves a future shape or local primitive but does
  not perform the advertised external capability.
- **TERM-006:** **Simulation** deliberately imitates selected behavior without
  causing the real-world operation.
- **TERM-007:** **Synthetic fixture** is locally constructed test data with a
  narrow, documented invariant. It is not external compatibility evidence.
- **TERM-008:** **External fixture** is a pinned real artifact with provenance,
  license, checksum, retrieval/construction instructions, and an independent
  oracle.
- **TERM-009:** **Fail closed** means reject the unsupported, unsafe, invalid, or
  unproved operation before reporting success or producing ambiguous state.
- **TERM-010:** **Verified** means the exact narrowly worded capability executed
  and passed its declared acceptance gate.
- **TERM-011:** **Partial** means meaningful connected behavior exists, but the
  complete advertised capability has not passed.
- **TERM-012:** **Missing** means the operation is absent even if names, enums,
  interfaces, or unsupported gates exist.
- **TERM-013:** **Evidence boundary** states exactly what a test proves and what
  it cannot prove.
- **TERM-014:** **Independent oracle** derives expected behavior from an
  authoritative implementation, specification, fixture, or calculation that
  does not reuse the implementation being tested.
- **TERM-015:** **Completion** means code, wiring, evidence, documentation, and
  pushed revision all match the requested scope. It does not mean “the file was
  edited.”

## 4. Absolute Truth Directives

- **TRUTH-001:** Never invent code execution, commands, outputs, files, commits,
  pushes, CI runs, devices, models, network responses, users, or state.
- **TRUTH-002:** Never say a test passed unless that exact test command completed
  successfully in the reported environment.
- **TRUTH-003:** Never say code compiles unless the relevant build completed
  successfully after the reported changes.
- **TRUTH-004:** Never say work was pushed until the remote accepted the push.
- **TRUTH-005:** Never say remote CI passed until the run for the exact pushed
  commit completed successfully.
- **TRUTH-006:** Never use an earlier commit's success as proof for a later
  untested commit.
- **TRUTH-007:** Never turn “likely,” “should,” “intended,” or “designed to” into
  “works,” “supports,” or “verified.”
- **TRUTH-008:** Never infer behavior from a function, file, class, enum, test,
  command, or marketing name.
- **TRUTH-009:** Never infer external compatibility from similar shapes,
  schemas, filenames, or sample data.
- **TRUTH-010:** Never infer a side effect from a success message. Observe the
  target state independently.
- **TRUTH-011:** Never infer persistence from in-process memory. Restart and
  reload must be part of persistence evidence.
- **TRUTH-012:** Never infer networking from a same-process call or formatter.
- **TRUTH-013:** Never infer hardware execution from library presence, device
  enums, OS names, PCI listings, environment variables, or banners.
- **TRUTH-014:** Never infer concurrency from lists of tasks, sequential loops,
  async-shaped names, or timestamps.
- **TRUTH-015:** Never infer recovery from catching an exception or toggling a
  Boolean.
- **TRUTH-016:** Never infer security from input validation alone.
- **TRUTH-017:** Never infer quality, speed, efficiency, or production readiness
  from code appearance or theoretical complexity.
- **TRUTH-018:** Never hide uncertainty that materially affects correctness.
- **TRUTH-019:** Never use confident prose to compensate for missing evidence.
- **TRUTH-020:** If an exact fact can be checked cheaply, check it before using
  it as a design premise.
- **TRUTH-021:** If a fact is current, vendor-specific, or version-sensitive,
  verify it against primary documentation and the repository's exact lock.
- **TRUTH-022:** If a claim cannot be verified, label it unverified, leave the
  capability non-verified, and state the next proof needed.

## 5. Session and Task Admission

- **TASK-001:** Read `TODO.md` at the start of every non-trivial project task.
- **TASK-002:** Read the relevant capability-ledger entry before changing a
  capability surface.
- **TASK-003:** Read the owning module's `INTERFACE.md` when one exists.
- **TASK-004:** Read the active roadmap/task/bug record related to the work.
- **TASK-005:** Inspect the real source and tests; do not plan from documentation
  alone.
- **TASK-006:** Check the active branch, remote relationship, status, and recent
  commits before editing.
- **TASK-007:** Preserve unrelated user changes in a dirty worktree.
- **TASK-008:** Write a scoped `TASK_*.md` or bug record before substantial
  implementation.
- **TASK-009:** State authorization, current truth, owning domain, desired end
  state, invariants, files, verification, and completion boundary.
- **TASK-010:** Commit and push the task contract before the implementation
  slice unless Volmarr explicitly changes that workflow.
- **TASK-011:** A task contract authorizes only the stated scope. It does not
  silently authorize deletion, credential use, external publication, or broad
  refactors.
- **TASK-012:** Convert vague mega-requests into reviewable vertical slices
  without shrinking the final requested outcome.
- **TASK-013:** Reproduce the defect or first failing acceptance gate before
  claiming to fix it.
- **TASK-014:** When reproduction requires unavailable hardware, credentials,
  licensed data, or a remote service, keep the boundary open and report the
  exact prerequisite.
- **TASK-015:** Record assumptions that influence architecture or behavior.
- **TASK-016:** Do not ask Volmarr questions whose answers are already available
  in the repository or through safe read-only inspection.
- **TASK-017:** Ask before a materially different design choice would exceed the
  authorized scope.
- **TASK-018:** No task may define success as “tests pass” without identifying
  which tests and why they prove the requested operation.
- **TASK-019:** No task may define success as “code added” or “API created.”
- **TASK-020:** A documentation-only task must never promote runtime status.

## 6. Research and Dependency Truth

- **RESEARCH-001:** Use primary specifications, vendor documentation, upstream
  source, or official release notes for technical behavior.
- **RESEARCH-002:** Use the repository's pinned dependency version, not an
  unpinned latest version, as the implementation contract.
- **RESEARCH-003:** Do not invent APIs from memory or autocomplete plausibility.
- **RESEARCH-004:** Confirm symbol names, signatures, ownership, result codes,
  threading rules, and cleanup order before writing a foreign-function bridge.
- **RESEARCH-005:** Distinguish a runtime library being loadable from the API
  being compatible and the hardware being present.
- **RESEARCH-006:** Distinguish official support, known compatibility,
  experimental community work, and unverified possibility.
- **RESEARCH-007:** Record exact upstream versions for compatibility claims.
- **RESEARCH-008:** Do not copy code without license, attribution, and adaptation
  review.
- **RESEARCH-009:** Do not quote or paraphrase a specification beyond what is
  needed to implement and verify the supported subset.
- **RESEARCH-010:** Do not add a dependency merely to avoid understanding a
  small owned contract.
- **RESEARCH-011:** Do not reimplement a mature dependency merely for novelty
  when the project already locks and can verify a suitable implementation.
- **RESEARCH-012:** New dependencies require ownership, version policy, license,
  platform impact, security impact, and rollback reasoning.
- **RESEARCH-013:** Dependency availability on the developer's machine is not a
  clean-checkout dependency declaration.
- **RESEARCH-014:** Undocumented environment state may not be required for a
  claimed default build.
- **RESEARCH-015:** A future research note belongs in Markdown, not as guessed
  executable source.

## 7. File Admission and Repository Shape

- **FILE-001:** Every new tracked file has exactly one owning domain and a
  current purpose.
- **FILE-002:** Every new runtime file has a current consumer or entry point.
- **FILE-003:** Every new public module has a focused test and interface update.
- **FILE-004:** Every new configuration/data file has a schema, reader,
  validation path, and failure behavior.
- **FILE-005:** Never create an empty file to suggest a feature exists.
- **FILE-006:** Never create a placeholder implementation file for future work.
- **FILE-007:** Never create duplicate files with slightly different names to
  avoid integrating the canonical owner.
- **FILE-008:** Never add an example under a production path and let it appear
  operational.
- **FILE-009:** Never add a binary under a source extension or source under a
  misleading binary extension.
- **FILE-010:** File extensions must match validated content.
- **FILE-011:** Tiny model files may not use real model extensions as
  placeholders.
- **FILE-012:** Generated binaries, objects, shared libraries, caches, logs,
  databases, runtime state, crash dumps, and downloaded weights stay out of Git.
- **FILE-013:** Imported and generated assets require provenance, license,
  checksum, purpose, consumer, and evidence boundary.
- **FILE-014:** Byte-identical assets use one canonical source unless distinct
  ownership is documented.
- **FILE-015:** Machine-local absolute paths are forbidden in tracked content.
- **FILE-016:** Secrets, tokens, private keys, signed URLs, and credential-bearing
  configuration are forbidden in tracked content.
- **FILE-017:** Historical material belongs under an explicit historical
  boundary and cannot define current status.
- **FILE-018:** A migration copy must have a removal/transition contract; do not
  leave two active canonical files indefinitely.
- **FILE-019:** Do not create a new directory until its first real content and
  ownership justify it.
- **FILE-020:** Important new directories require a README stating what they own
  and forbid.
- **FILE-021:** Do not add a manifest that lists artifacts which do not exist or
  are not retrievable under its declared procedure.
- **FILE-022:** Do not add generated data without a deterministic construction
  record when reproducibility is claimed.
- **FILE-023:** Do not use mass-generated filler to satisfy a requested count.
- **FILE-024:** A plan may name future files, but those files are not created
  until their real implementation slice begins.
- **FILE-025:** Before admission, answer owner, purpose, consumer, type,
  validator, evidence boundary, provenance, license, and canonicality.
- **FILE-026:** If any file-admission answer is missing, document the future need
  instead of adding the file.

## 8. Source-Code Reality

- **CODE-001:** Pseudocode is forbidden in production source.
- **CODE-002:** Commented-out imagined implementations are pseudocode and are
  forbidden.
- **CODE-003:** Ellipses, `pass`, placeholder returns, and fixed success are
  forbidden in reachable production paths.
- **CODE-004:** `TODO` comments may identify debt only when the current path is
  safe, honest, and fails closed where necessary.
- **CODE-005:** A function must either perform the operation its public name
  advertises or return/raise an explicit unsupported result.
- **CODE-006:** A function may not call a different backend and retain the
  requested backend's success label.
- **CODE-007:** A GPU/NPU function may not execute CPU work and report hardware
  execution.
- **CODE-008:** A network function may not return a canned response and report
  remote success.
- **CODE-009:** A persistence function may not mutate only memory and report
  durable success.
- **CODE-010:** A cryptographic function may not use a non-cryptographic hash
  under a cryptographic name.
- **CODE-011:** A parser may not accept unknown input by silently interpreting
  it as a supported format.
- **CODE-012:** A dispatcher may not route unknown enum values to a default
  implementation unless the public contract explicitly defines that default.
- **CODE-013:** A fallback must be explicit, permitted, observable, and tested.
- **CODE-014:** An explicit user backend or format request never silently falls
  back.
- **CODE-015:** A success value must derive from completed observed work.
- **CODE-016:** Output metadata must derive from current state, not seeded
  examples or guessed constants.
- **CODE-017:** Device names, sizes, utilization, hashes, byte counts, versions,
  token counts, timings, and status must never be invented.
- **CODE-018:** Public inputs require validation before unsafe reads, allocation,
  mutation, external calls, or partial persistence.
- **CODE-019:** Checked arithmetic is required for untrusted counts, sizes,
  offsets, products, alignments, and conversions.
- **CODE-020:** Raw pointers require owner, span, alignment, mutability, address
  space, and lifetime evidence.
- **CODE-021:** Host and accelerator pointers may not share an unchecked
  representation that host code can dereference incorrectly.
- **CODE-022:** Ownership and borrowing must be explicit at every resource
  boundary.
- **CODE-023:** Every acquired resource has one release owner and a defined
  partial-initialization cleanup path.
- **CODE-024:** Cleanup must be idempotent when repeated close/destruction is
  possible.
- **CODE-025:** Do not leak a resource to avoid designing ownership.
- **CODE-026:** Do not use global mutable state to avoid passing explicit
  context.
- **CODE-027:** Do not duplicate validation across unrelated modules when one
  owning boundary can enforce it.
- **CODE-028:** Do not bypass internal APIs to mutate another domain's state.
- **CODE-029:** Do not introduce circular imports or hidden initialization
  order.
- **CODE-030:** Keep functions focused on one responsibility; split only along
  real ownership boundaries.
- **CODE-031:** Do not split simple behavior into ceremonial files or functions
  with no independent contract.
- **CODE-032:** Names must describe the mechanism that actually executes.
- **CODE-033:** Mythic names may enrich identity but never obscure technical
  ownership, failure, or maturity.
- **CODE-034:** Comments explain invariants, ownership, algorithms, and reasons;
  they do not claim missing behavior.
- **CODE-035:** Comments that become false are bugs and must be reconciled with
  the implementation change.
- **CODE-036:** Do not optimize before establishing correctness and a reference
  oracle.
- **CODE-037:** Do not retain an unsafe compatibility path merely because it
  once existed; fail it closed until an approved migration resolves it.
- **CODE-038:** Do not add generalized abstraction before one concrete vertical
  slice proves the required variation.
- **CODE-039:** Do not add feature flags whose true and false branches are not
  both owned and tested.
- **CODE-040:** A disabled feature must remain observably disabled.
- **CODE-041:** A configuration value must be applied by its owner or rejected
  before side effects.
- **CODE-042:** Silent ignore of accepted configuration is forbidden.
- **CODE-043:** No reachable code may intentionally return plausible nonsense
  to keep a pipeline moving.
- **CODE-044:** Empty success is allowed only when the contract defines empty as
  a valid completed result and tests distinguish it from failure.
- **CODE-045:** If implementation cannot be completed in the authorized slice,
  preserve or strengthen fail-closed behavior and record the exact remaining
  gate.

## 9. Vertical-Slice and Integration Law

- **WIRE-001:** New logic is not complete until the intended production entry
  point reaches it.
- **WIRE-002:** A public symbol with no production consumer remains scaffold or
  local primitive evidence.
- **WIRE-003:** A CLI option is not implemented until parsing, validation,
  configuration precedence, runtime ownership, errors, help, and tests agree.
- **WIRE-004:** An API endpoint is not implemented until transport, parsing,
  validation, routing, owned operation, serialization, errors, and lifecycle
  are connected.
- **WIRE-005:** A model format is not supported until parsing, validated tensor
  ownership, execution, and an external oracle are connected.
- **WIRE-006:** A hardware backend is not supported until discovery, context,
  allocation/mapping, transfer, execution, synchronization, cleanup, and model
  integration are connected.
- **WIRE-007:** A storage operation is not implemented until durable mutation,
  atomicity/rollback, restart visibility, corruption behavior, and errors are
  connected.
- **WIRE-008:** A concurrency feature is not implemented until actual workers,
  synchronization, ordering, cancellation, shutdown, and race evidence exist.
- **WIRE-009:** A recovery feature is not implemented until failure is injected
  and state invariants are demonstrably restored or loss is reported.
- **WIRE-010:** A compatibility wrapper is not complete until compared with a
  pinned real upstream version over the declared subset.
- **WIRE-011:** Do not leave integration “for later” while marking the component
  complete.
- **WIRE-012:** Do not create a second unofficial entry point to avoid repairing
  the canonical one.
- **WIRE-013:** All side effects pass through the owning domain.
- **WIRE-014:** Cross-domain calls use explicit interfaces, not direct internal
  state mutation.
- **WIRE-015:** Data transformations state input and output ownership.
- **WIRE-016:** Every partial failure states what was mutated, what was rolled
  back, and what remains valid.
- **WIRE-017:** An integration test must cross the same boundary the production
  path crosses.
- **WIRE-018:** Same-process replacement of an external boundary proves only
  local contract arithmetic, not integration.
- **WIRE-019:** Feature availability must derive from runtime evidence, not only
  build-time inclusion.
- **WIRE-020:** Public help and documentation must expose only connected support
  and clearly label reserved options.

## 10. Error, Failure, and Recovery Law

- **ERROR-001:** Unsupported behavior returns a distinct non-success result.
- **ERROR-002:** Invalid input, unsupported input, not found, permission denied,
  corruption, timeout, cancellation, conflict, OOM, and internal failure remain
  distinguishable.
- **ERROR-003:** Broad exception handlers must not erase native cause or stable
  error category.
- **ERROR-004:** Catching an error requires a defined action: translate,
  annotate, roll back, retry safely, or propagate.
- **ERROR-005:** Never catch and return a plausible default solely to avoid a
  visible failure.
- **ERROR-006:** Never print a warning and continue with invalid state.
- **ERROR-007:** Error messages name the operation and actionable boundary
  without exposing secrets.
- **ERROR-008:** Error paths must be tested, not merely reasoned about.
- **ERROR-009:** Resource cleanup must run for failures at each initialization
  stage.
- **ERROR-010:** A retry must be bounded and limited to documented idempotent or
  safely resumable operations.
- **ERROR-011:** Retry exhaustion returns failure; it does not become degraded
  success unless the contract explicitly supports a degraded mode.
- **ERROR-012:** Degraded mode must be selected or reported explicitly and
  tested independently.
- **ERROR-013:** Recovery must prove the invariants it claims to restore.
- **ERROR-014:** Restarting a process is not state recovery unless required
  state is reloaded and validated.
- **ERROR-015:** Device loss invalidates all resources owned by that device
  context unless the vendor contract proves otherwise.
- **ERROR-016:** Partial writes require rollback, quarantine, or explicit
  incomplete state; they may not be reported complete.
- **ERROR-017:** Corrupt data is never replaced with invented valid data.
- **ERROR-018:** Cancellation is an owned state transition with cleanup, not an
  arbitrary exception swallowed by the caller.
- **ERROR-019:** Timeouts must state whether underlying work was cancelled,
  abandoned, or may still complete.
- **ERROR-020:** Assertions are not substitutes for validating untrusted runtime
  input when assertions can be disabled or terminate incorrectly.
- **ERROR-021:** Fatal invariant violations must fail before unsafe continuation.
- **ERROR-022:** Error logging must not itself mutate the failed domain in a way
  that hides the original condition.
- **ERROR-023:** “Self-healing” terminology is forbidden until injected failure,
  restoration, and repeated-failure policy pass.
- **ERROR-024:** If safe recovery is unknown, stop and fail closed.

## 11. Test Reality Law

- **TEST-001:** Tests must fail the process when their expectation fails.
- **TEST-002:** Printing `PASS` is not an assertion.
- **TEST-003:** Catching any exception and counting it as pass is forbidden; test
  the expected error category or stable message boundary.
- **TEST-004:** An early return caused by a missing prerequisite is an explicit
  skip, not a pass.
- **TEST-005:** Every skip states the exact external prerequisite.
- **TEST-006:** Test runners must count pass, fail, skip, and total cases.
- **TEST-007:** A runner raises/nonzeros when any registered case fails.
- **TEST-008:** Keep a deliberate negative control proving runner failure
  semantics.
- **TEST-009:** Test names state the narrow invariant actually exercised.
- **TEST-010:** A test name containing `real`, `hardware`, `integration`,
  `compatible`, or `end_to_end` must cross that actual boundary.
- **TEST-011:** Unit tests prove local logic only.
- **TEST-012:** Boundary tests prove interface contracts only.
- **TEST-013:** Integration tests prove connected owners interacting.
- **TEST-014:** Regression tests preserve a reproduced prior defect.
- **TEST-015:** Invariant tests preserve truths across success and failure.
- **TEST-016:** External compatibility tests use a pinned real external fixture
  and independent oracle.
- **TEST-017:** Hardware tests execute on the named physical hardware.
- **TEST-018:** Network tests use real sockets/process boundaries when claiming
  network operation.
- **TEST-019:** Persistence tests restart/reopen before checking durable state.
- **TEST-020:** Concurrency tests create actual concurrent execution and include
  synchronization/race/ordering checks.
- **TEST-021:** Recovery tests inject the failure being claimed as recoverable.
- **TEST-022:** Performance tests establish correctness before timing.
- **TEST-023:** Do not compute expected results with the same implementation
  under test.
- **TEST-024:** Do not weaken tolerances merely to make incorrect numerical code
  pass.
- **TEST-025:** Numerical tolerances state dtype, accumulation, shape, and reason.
- **TEST-026:** Randomized tests use recorded seeds and meaningful shape/value
  coverage.
- **TEST-027:** Include boundary sizes, tails, empty/zero policy, maximum allowed
  sizes where practical, malformed inputs, and overflow cases.
- **TEST-028:** Include cleanup and state-integrity checks after expected errors.
- **TEST-029:** Include repeat-failure tests where stale state could cause later
  corruption.
- **TEST-030:** Include alias, overlap, ownership, and lifetime tests for pointer
  or buffer APIs.
- **TEST-031:** Do not mock the very boundary whose reality is the claim.
- **TEST-032:** Mocks and fakes must be named and scoped as test doubles.
- **TEST-033:** A test double cannot promote an external capability.
- **TEST-034:** Synthetic happy paths cannot prove general input support.
- **TEST-035:** A single model, platform, precision, or protocol version proves
  only that named slice.
- **TEST-036:** Tests must not depend on untracked local state unless explicitly
  classified external and skipped when absent.
- **TEST-037:** A clean checkout must build and run the default proof suite.
- **TEST-038:** New public behavior adds or updates focused executable cases.
- **TEST-039:** Deleted or renamed tests require the same explicit approval and
  evidence reconciliation as the behavior they protect.
- **TEST-040:** Never claim all tests pass if only a focused subset ran.
- **TEST-041:** Never suppress test output or exit status in a way that can hide
  failure.
- **TEST-042:** CI commands must preserve failure propagation through shells and
  pipelines.
- **TEST-043:** Test data cleanup must target only paths created and owned by
  that test.
- **TEST-044:** A test may never delete pre-existing or user data.
- **TEST-045:** Hosted CI success must correspond to the exact reported commit.

## 12. Fixture, Data, and Provenance Law

- **DATA-001:** Every fixture is classified as `synthetic`, `malformed`,
  `regression`, or `external-reference`.
- **DATA-002:** Every tracked fixture records owner, purpose, consumer, format,
  evidence boundary, license, exact size, and SHA-256.
- **DATA-003:** Synthetic fixture construction is deterministic or fully
  documented.
- **DATA-004:** Synthetic fixtures never prove ecosystem, model, hardware,
  protocol, persistence, or performance compatibility.
- **DATA-005:** Malformed fixtures state the exact invariant they violate.
- **DATA-006:** Regression fixtures link to the reproduced defect or task.
- **DATA-007:** External references pin immutable revision, filename, checksum,
  source, license, retrieval procedure, and oracle.
- **DATA-008:** Large or restricted external fixtures stay outside Git.
- **DATA-009:** A missing external fixture produces an explicit skip, not a fake
  local substitute presented as equivalent.
- **DATA-010:** Do not fabricate hashes, sizes, timestamps, source URLs,
  licenses, authors, versions, or creation procedures.
- **DATA-011:** Do not rename arbitrary bytes to satisfy a format extension.
- **DATA-012:** Structured data must pass its declared schema or supported parser
  contract.
- **DATA-013:** Binary data must pass appropriate magic, header, length, offset,
  alignment, and checksum checks.
- **DATA-014:** Do not truncate data silently to create a successful parse.
- **DATA-015:** Resource ceilings reject oversized input explicitly before
  unsafe allocation or partial acceptance.
- **DATA-016:** Immutable base data is not rewritten by runtime session changes.
- **DATA-017:** Generated data must identify generator/tool version and source
  inputs.
- **DATA-018:** Research data must separate facts, interpretations, disputed
  claims, and unknowns.
- **DATA-019:** Do not mass-produce repetitive low-information records to make a
  dataset appear comprehensive.
- **DATA-020:** Do not create fictional sample catalogs in runtime storage.
- **DATA-021:** Example records remain visibly examples and cannot appear in
  operational queries by default.
- **DATA-022:** User-provided data is never silently replaced with defaults.
- **DATA-023:** Data migrations require version, validation, failure, rollback,
  and restart behavior.
- **DATA-024:** Provenance metadata is verified content, not boilerplate.
- **DATA-025:** If provenance is unknown, the artifact is quarantined,
  untracked, or rejected—not represented as trusted.

## 13. Capability and Completion Claims

- **CLAIM-001:** Use only the ledger statuses `verified`, `partial`, `scaffold`,
  `simulated`, and `missing`.
- **CLAIM-002:** Status changes occur in the same commit as executable evidence
  and synchronized documentation.
- **CLAIM-003:** An interface, enum, descriptor, parser shell, or library probe
  cannot by itself promote an external capability.
- **CLAIM-004:** A checked TODO item means its exact sentence passed; it does not
  replace capability status.
- **CLAIM-005:** `verified` must name the exact supported subset.
- **CLAIM-006:** Broader neighboring behavior remains explicitly non-verified.
- **CLAIM-007:** Never reuse one capability ID for materially different
  behavior.
- **CLAIM-008:** Split broad claims with new stable IDs and explicit ownership.
- **CLAIM-009:** Every verified entry names implementation evidence, executable
  evidence, evidence boundary, and audit relationship.
- **CLAIM-010:** Historical milestone prose cannot be cited as current evidence.
- **CLAIM-011:** “Implemented” means connected production behavior, not only a
  declaration.
- **CLAIM-012:** “Working” means the advertised operation succeeds and its
  relevant failures behave correctly.
- **CLAIM-013:** “Complete” means all scoped acceptance gates pass with no known
  required work hidden.
- **CLAIM-014:** “Production-ready” requires the ledger's operations gate,
  sustained CI, security, observability, recovery, concurrency, load, release,
  and upgrade evidence.
- **CLAIM-015:** “Compatible” names the upstream version, supported subset,
  fixture, oracle, and exclusions.
- **CLAIM-016:** “Drop-in replacement” requires differential behavior across the
  declared public contract, including errors and edge cases.
- **CLAIM-017:** “Zero-copy” requires proved backend-specific mapping, lifetime,
  synchronization, and measured transfer behavior.
- **CLAIM-018:** “Accelerated” requires work executed on the named accelerator.
- **CLAIM-019:** “Parallel” and “concurrent” require overlapping execution or
  real worker concurrency as defined by the contract.
- **CLAIM-020:** “Atomic” requires no visible partial state under the tested
  failure model.
- **CLAIM-021:** “Durable” requires the declared restart and storage-failure
  boundary.
- **CLAIM-022:** “Secure” requires a bounded threat model and evidence, not a
  blanket adjective.
- **CLAIM-023:** “Crash-proof,” “bug-proof,” “all,” “universal,” and “never
  fails” are prohibited absolute claims.
- **CLAIM-024:** “Self-healing” requires injected failure and restored
  invariants.
- **CLAIM-025:** “Optimized” requires equivalent correctness plus measurement.
- **CLAIM-026:** “Faster” requires a valid comparator and reproducible results.
- **CLAIM-027:** “Real” in a filename or test title creates a duty to prove the
  external boundary it names.
- **CLAIM-028:** Documentation uses present tense only for currently observed
  behavior.
- **CLAIM-029:** Future vision is labeled target, planned, reserved, proposed,
  or unimplemented.
- **CLAIM-030:** A final report distinguishes changed, tested, pushed, CI-proved,
  skipped, blocked, and still missing work.

## 14. Documentation Reality

- **DOC-001:** Documentation is part of the implementation contract.
- **DOC-002:** Update interface, architecture, data flow, ledger, TODO, task, and
  DEVLOG when the changed behavior affects them.
- **DOC-003:** Documentation changes do not substitute for tests.
- **DOC-004:** Tests do not excuse stale documentation.
- **DOC-005:** Do not copy present-tense capability claims into multiple active
  documents without a canonical owner.
- **DOC-006:** Link to the canonical ledger instead of restating fragile status
  counts unnecessarily.
- **DOC-007:** Snapshot counts include date/revision and are not permanent truth.
- **DOC-008:** Preserve historical documents without allowing them to define
  current behavior.
- **DOC-009:** A completed document contains no hidden placeholder sections.
- **DOC-010:** Invented citations and unverifiable source claims are forbidden.
- **DOC-011:** Technical sources are linked near the recommendation they support
  when practical.
- **DOC-012:** External documentation is checked against exact versions before
  code relies on it.
- **DOC-013:** Examples state whether they are executable, illustrative, or
  unsupported.
- **DOC-014:** Command examples must not imply successful output that was never
  observed.
- **DOC-015:** Error examples must not expose real credentials or user data.
- **DOC-016:** Public help lists operational, partial, reserved, and unsupported
  behavior distinctly.
- **DOC-017:** A roadmap defines future work and gates; it cannot mark that work
  implemented.
- **DOC-018:** A task record states exactly what authorization covered.
- **DOC-019:** Do not retroactively rewrite evidence to make an old claim appear
  justified.
- **DOC-020:** Correct contradictions in the same slice that creates them.

## 15. Model, Format, and Inference Law

- **MODEL-001:** A file is not a model because its extension says so.
- **MODEL-002:** Validate format magic, version, metadata, tensor bounds,
  alignment, types, sizes, and ownership before inference.
- **MODEL-003:** A format is supported only for the explicitly implemented
  subset.
- **MODEL-004:** Unknown architectures, operators, quantization types, or
  metadata fail explicitly.
- **MODEL-005:** Do not reinterpret an unsupported quantization format as a
  supported one.
- **MODEL-006:** Toy block arithmetic does not prove real quantized model
  compatibility.
- **MODEL-007:** A synthetic model does not prove ecosystem compatibility.
- **MODEL-008:** A real-model claim requires immutable model identity,
  checksum, source/license boundary, and independent oracle.
- **MODEL-009:** Token parity records tokenizer, prompt/template, sampling,
  context, precision, and model identity.
- **MODEL-010:** Logit parity defines compared positions, dtype, tolerance, and
  oracle.
- **MODEL-011:** Text parity alone cannot isolate tokenizer, sampling, or
  numerical correctness.
- **MODEL-012:** A single token does not prove multi-token KV-cache behavior.
- **MODEL-013:** Multi-token evidence includes exact token IDs, stop policy,
  context behavior, and cache reuse.
- **MODEL-014:** Predetermined token output is forbidden in production
  inference.
- **MODEL-015:** Seeded sampling evidence states the seed and complete sampling
  configuration.
- **MODEL-016:** “Thinking disabled” requires tokenizer/model-specific control
  and output evidence; a Boolean setting alone is insufficient.
- **MODEL-017:** Tool-use support requires schema, prompt/template integration,
  model output parsing, validation, execution ownership, and result reinsertion.
- **MODEL-018:** RAG requires real ingestion, embeddings, retrieval, context
  integration, source metadata, and no-result behavior before end-to-end claims.
- **MODEL-019:** Model downloads require transferred bytes, integrity checks,
  atomic promotion, cancellation, and credential redaction.
- **MODEL-020:** Compiled accelerator artifacts retain source-model and compiler
  provenance.
- **MODEL-021:** A GGUF cannot be presented as directly runnable on an NPU whose
  supported contract requires a compiled graph artifact.
- **MODEL-022:** Model conversion is a separate capability with its own oracle
  and provenance.
- **MODEL-023:** Unsupported model features must not be silently ignored when
  they affect results.
- **MODEL-024:** Inference errors never return fluent canned text as success.
- **MODEL-025:** Generated text is never used as proof of numerical correctness
  without lower-level evidence.

## 16. GPU, NPU, and Hardware Law

- **HW-001:** Runtime-library presence is not physical device discovery.
- **HW-002:** OS device nodes, PCI listings, or vendor utilities are target
  selection evidence, not engine execution evidence.
- **HW-003:** Physical discovery uses the supported backend API and records
  device identity and capabilities.
- **HW-004:** A hard-coded device count is fake discovery.
- **HW-005:** Host allocation is not VRAM/NPU memory.
- **HW-006:** A host pointer may not be labeled a device pointer.
- **HW-007:** CPU `mmap` is not direct GPU mapping.
- **HW-008:** Pinned host staging is not zero-copy.
- **HW-009:** Unified/shared memory claims name the exact backend contract and
  prove synchronization/residency behavior.
- **HW-010:** A genuine hardware slice owns context, queue/stream, allocation,
  transfer or mapping, execution, synchronization, and cleanup.
- **HW-011:** A kernel must execute on the named physical device.
- **HW-012:** A backend-labeled function may not call the CPU reference and
  return hardware success.
- **HW-013:** Hardware parity compares against an independent CPU/reference
  result.
- **HW-014:** Hardware tests record device, driver, runtime, compiler, commit,
  model/fixture, command, and result.
- **HW-015:** One GPU does not verify all GPUs of the same vendor.
- **HW-016:** One vendor backend does not verify another backend.
- **HW-017:** One operator kernel does not verify full model acceleration.
- **HW-018:** Full-model acceleration requires every operation claimed to be
  accelerated or explicit measured transfer/fallback boundaries.
- **HW-019:** Explicit accelerator selection never silently falls back to CPU.
- **HW-020:** `auto` selects only observed backends with the necessary verified
  model execution level.
- **HW-021:** Hardware OOM, launch failure, synchronization failure, device loss,
  and cleanup require distinct tested behavior.
- **HW-022:** Multi-device requires physical placement, real concurrent work,
  collectives/transfers, ordering, failure propagation, and parity.
- **HW-023:** Sequential host sharding is not multi-GPU.
- **HW-024:** NPU support is vendor/artifact specific; a generic enum is not a
  provider.
- **HW-025:** Private, guessed, or undocumented driver libraries cannot form a
  positive support contract.
- **HW-026:** Hardware performance is measured only after correctness passes.
- **HW-027:** Hardware capability status remains non-verified without a
  reproducible physical gate or trusted hardware CI.

## 17. Service, Network, and Protocol Law

- **NET-001:** A formatter is not a server.
- **NET-002:** A socket bind is not a model-backed service loop.
- **NET-003:** A route table is not endpoint compatibility.
- **NET-004:** Same-process handler calls do not prove network transport.
- **NET-005:** A service owns accept/read/parse/route/execute/write/close
  lifecycle and error propagation.
- **NET-006:** Request parsing validates method, path, protocol, headers, lengths,
  encoding, body, and resource limits before execution.
- **NET-007:** Responses use correct serialization and escaping for untrusted
  text.
- **NET-008:** Partial writes are handled until complete or failed.
- **NET-009:** Streaming proves framing, ordering, final frame, disconnect,
  backpressure, and cancellation.
- **NET-010:** Fixed assistant responses are forbidden as successful inference.
- **NET-011:** Health reports observed owned state, not a constant.
- **NET-012:** Usage totals derive from actual request/model/token processing.
- **NET-013:** Compatibility names the exact protocol/client/server version and
  supported subset.
- **NET-014:** Official-client or wire-level differential tests are required for
  external API compatibility.
- **NET-015:** Error status, schema, headers, and body are part of compatibility.
- **NET-016:** A local-only service must not imply safe remote exposure.
- **NET-017:** Authentication and TLS claims require an implemented threat model
  and interoperability evidence.
- **NET-018:** Timeouts, cancellation, queue limits, fairness, and graceful
  shutdown are required before production service claims.
- **NET-019:** Remote swarm success requires separate authenticated processes
  and real request/result transport.
- **NET-020:** Seeded peers and fixed heartbeat state are not a cluster.

## 18. Persistence and Mutation Law

- **STORE-001:** Durable state survives the declared close/restart boundary.
- **STORE-002:** An in-memory list is not a persistent catalog.
- **STORE-003:** Seeded example state may not appear as discovered operational
  state.
- **STORE-004:** Create, copy, remove, update, pull, and push report success only
  after their actual side effects complete.
- **STORE-005:** Every mutation defines not-found, duplicate, conflict,
  permission, corruption, partial-write, and concurrent-access behavior.
- **STORE-006:** Atomic mutation uses temporary ownership, validation, promotion,
  and rollback appropriate to the storage contract.
- **STORE-007:** A rename alone does not prove durability.
- **STORE-008:** Restart tests reopen state from storage without reusing the
  prior in-memory object.
- **STORE-009:** Checksums and byte sizes derive from stored bytes.
- **STORE-010:** Hash algorithms must match their names.
- **STORE-011:** Content-addressed storage verifies content before trusting an
  address.
- **STORE-012:** Corrupt content is quarantined or rejected, never silently
  normalized into success.
- **STORE-013:** Failed mutation must not leave a successful manifest pointing to
  missing content.
- **STORE-014:** Model-in-use state derives from real session ownership.
- **STORE-015:** A stop command must affect a real owned process/session before
  reporting stopped.
- **STORE-016:** Pull/download reports actual bytes, progress, integrity, and
  final storage state.
- **STORE-017:** Push/upload requires real authentication, transport, conflict,
  retry, integrity, and remote observation.
- **STORE-018:** Runtime tests operate only inside test-owned temporary roots.
- **STORE-019:** Cleanup never targets user or pre-existing storage.
- **STORE-020:** Persistent schema changes require versioning and migration
  tests.

## 19. Concurrency, Events, and Resilience Law

- **CONCUR-001:** A task list is not a thread pool.
- **CONCUR-002:** An event record is not subscriber delivery.
- **CONCUR-003:** Async-shaped APIs are not asynchronous unless work ownership
  and completion semantics exist.
- **CONCUR-004:** Concurrency requires actual overlapping or independently
  scheduled work.
- **CONCUR-005:** Shared mutable state requires synchronization or single-owner
  confinement.
- **CONCUR-006:** Define queue capacity, admission, fairness, ordering, and
  backpressure.
- **CONCUR-007:** Define task completion, error propagation, cancellation, and
  result ownership.
- **CONCUR-008:** Shutdown must reject or drain work according to a tested
  policy.
- **CONCUR-009:** Subscriber lifetime, unsubscribe, delivery failure, and slow
  consumers require explicit behavior.
- **CONCUR-010:** Timestamps do not prove ordering across threads/processes.
- **CONCUR-011:** Tests must attempt races and repeated interleavings where
  ownership could break.
- **CONCUR-012:** Concurrency errors may not be hidden by serial fallback under
  a parallel label.
- **CONCUR-013:** Cancellation must reach the active owner and release request
  resources.
- **CONCUR-014:** Retrying concurrent work requires idempotency or duplicate
  suppression.
- **CONCUR-015:** Recovery states exactly which caches, sessions, requests, and
  outputs survive.
- **CONCUR-016:** A heartbeat Boolean is not process health.
- **CONCUR-017:** Process restart is not transparent recovery unless clients and
  state observe the declared continuity.
- **CONCUR-018:** Fault injection must target the claimed failure boundary.
- **CONCUR-019:** “Crash resistant” means controlled failure and protected
  invariants, not impossible failure.
- **CONCUR-020:** When recovery cannot be proved, report loss explicitly.

## 20. Benchmark and Performance Law

- **PERF-001:** Never invent benchmark numbers.
- **PERF-002:** Never copy vendor or upstream numbers as A.E.S.I.R. results.
- **PERF-003:** Never estimate measured performance and label it observed.
- **PERF-004:** Correctness gates run before timing.
- **PERF-005:** Record commit, build mode, hardware, OS, driver/runtime,
  dependency versions, model, precision, prompt, context, sampling, and command.
- **PERF-006:** Separate initialization, model load, first-token, and steady-state
  timing.
- **PERF-007:** Define token accounting precisely.
- **PERF-008:** Record warmup, sample count, raw samples, summary statistics, and
  timing source.
- **PERF-009:** Record peak host/device memory and transfer volume when relevant.
- **PERF-010:** Record utilization, power, and thermal measurements only from a
  named reliable source.
- **PERF-011:** Compare equivalent models, formats, precisions, prompts,
  contexts, sampling, and correctness outcomes.
- **PERF-012:** Do not compare debug and optimized builds without labeling them.
- **PERF-013:** Do not claim speedup from theoretical operation counts alone.
- **PERF-014:** Do not remove validation or safety to win an unqualified
  benchmark.
- **PERF-015:** Performance regressions are interpreted only after variance and
  environment changes are considered.
- **PERF-016:** A single sample is not a stable performance claim.
- **PERF-017:** Cached and cold results are reported separately.
- **PERF-018:** Failed or incorrect samples cannot be dropped silently.
- **PERF-019:** Benchmark artifacts require provenance and reproduction
  commands.
- **PERF-020:** “Fast,” “efficient,” “cold,” “maximum,” and “optimized” remain
  prohibited until the relevant measured evidence exists.

## 21. Security and Untrusted Input Law

- **SEC-001:** Treat model files, configuration, Modelfiles, network requests,
  registry content, swarm peers, and file paths as untrusted at their boundary.
- **SEC-002:** Validate before allocation, pointer arithmetic, decoding,
  execution, persistence, or external calls.
- **SEC-003:** Use checked arithmetic for attacker-controlled lengths and
  counts.
- **SEC-004:** Define resource ceilings for untrusted input and report rejection
  explicitly.
- **SEC-005:** Prevent path traversal and unsafe symlink behavior according to
  the storage contract.
- **SEC-006:** Use restrictive file permissions for secrets and sensitive
  runtime state.
- **SEC-007:** Never log credentials, authorization headers, tokens, private
  model URLs, or sensitive prompt content by default.
- **SEC-008:** Redaction must be tested against structured and malformed input.
- **SEC-009:** Do not add insecure network exposure as a convenience default.
- **SEC-010:** Cryptographic claims require standard algorithms and libraries,
  correct key/nonce handling, and test vectors.
- **SEC-011:** Checksums detect corruption; they are not authentication unless
  the contract says and proves otherwise.
- **SEC-012:** Signature verification defines trusted roots, key rotation,
  failure, and metadata coverage.
- **SEC-013:** Dependency updates require security and compatibility review.
- **SEC-014:** Fuzzing claims require an actual harness, corpus, execution, and
  recorded findings.
- **SEC-015:** Parsing success does not imply safe execution.
- **SEC-016:** Error messages avoid leaking machine-local paths or secrets while
  retaining actionable categories.
- **SEC-017:** Never disable certificate verification under a secure default.
- **SEC-018:** `--insecure`-style behavior must be explicit, scoped, warned, and
  never selected silently.
- **SEC-019:** Threat models state actors, assets, trust boundaries, attacks,
  mitigations, and residual risk.
- **SEC-020:** Production-ready claims require the applicable security gates to
  pass.

## 22. Platform and Portability Law

- **PORT-001:** Portable design is not platform support.
- **PORT-002:** Claim a platform only after clean build and relevant execution
  tests on that platform.
- **PORT-003:** Keep unsupported platforms explicitly unsupported.
- **PORT-004:** Do not use the developer machine's filesystem layout as a
  runtime contract.
- **PORT-005:** Resolve paths from configuration, executable/resource roots, or
  caller-owned locations.
- **PORT-006:** Do not assume POSIX behavior on Windows or Apple behavior on
  Linux.
- **PORT-007:** Platform-specific code lives behind an owned abstraction and
  explicit availability boundary.
- **PORT-008:** Conditional compilation must preserve tested unsupported
  behavior on other targets.
- **PORT-009:** Architecture-specific SIMD requires runtime/compile capability
  evidence and honest fallback labels.
- **PORT-010:** Endianness, alignment, integer width, and ABI assumptions must be
  explicit at binary boundaries.
- **PORT-011:** Dependency availability must be declared per supported target.
- **PORT-012:** A build-only platform test does not prove runtime services,
  hardware, or installers.
- **PORT-013:** Container success does not automatically prove the host OS.
- **PORT-014:** Emulation success does not automatically prove native hardware.
- **PORT-015:** Mobile platform support requires lifecycle, permissions,
  packaging, resource, and device tests.
- **PORT-016:** Raspberry Pi support names exact architecture, OS, runtime, and
  tested model scope.
- **PORT-017:** GPU support names exact backend and hardware scope.
- **PORT-018:** Platform-specific limitations appear in help and documentation.
- **PORT-019:** Cross-platform refactors preserve current verified Linux CPU
  behavior.
- **PORT-020:** Do not add dead platform branches simply to look portable.

## 23. Git, Commit, and Push Discipline

- **GIT-001:** Inspect branch and status before editing.
- **GIT-002:** Never change Git settings or remotes without permission.
- **GIT-003:** Never use destructive reset/checkout to erase user changes.
- **GIT-004:** Never delete tracked content without exact approval.
- **GIT-005:** Stage only files belonging to the current slice.
- **GIT-006:** Preserve unrelated modifications and untracked user files.
- **GIT-007:** Commits are reviewable and describe actual content.
- **GIT-008:** Do not use a “fix all” commit message for a narrow change.
- **GIT-009:** Do not claim a capability in a commit message beyond evidence.
- **GIT-010:** Push the task contract before substantial implementation.
- **GIT-011:** Push each verified implementation slice before beginning the next
  high-risk slice.
- **GIT-012:** Do not let substantial unpushed work accumulate.
- **GIT-013:** A push must target the branch Volmarr authorized.
- **GIT-014:** Verify local HEAD and remote branch agree after push.
- **GIT-015:** Observe hosted CI for the exact pushed SHA when available.
- **GIT-016:** A failed push is reported as failed; do not imply remote state.
- **GIT-017:** A queued CI run is reported queued, not passed.
- **GIT-018:** Do not rewrite public history without explicit permission.
- **GIT-019:** Do not force-push without explicit permission and exact scope.
- **GIT-020:** Do not commit machine-generated noise or unrelated formatting.
- **GIT-021:** Run `git diff --check` before commit.
- **GIT-022:** Review the staged diff, not only the working-tree diff.
- **GIT-023:** Confirm no secret, model weight, binary, cache, or local path is
  staged.
- **GIT-024:** Documentation and evidence updates land with the behavior they
  describe.
- **GIT-025:** Final reports name commit, branch, push result, CI result, tests,
  skips, and remaining boundaries accurately.

## 24. AI-Specific Conduct

- **AI-001:** An AI must inspect before editing.
- **AI-002:** An AI must not fill knowledge gaps with plausible implementation.
- **AI-003:** An AI must not create code merely because a requested filename or
  function name sounds expected.
- **AI-004:** An AI must not replace difficult work with a success-shaped stub.
- **AI-005:** An AI must not weaken validation or tests to make its code pass.
- **AI-006:** An AI must not edit expected outputs to match incorrect behavior
  without proving the old expectation wrong.
- **AI-007:** An AI must not change ledger status to match its ambition.
- **AI-008:** An AI must not mark TODO work complete because it added a type or
  interface.
- **AI-009:** An AI must not claim exhaustive review without defining the census
  and evidence used.
- **AI-010:** An AI must not say “all code works” while known non-verified
  capabilities remain.
- **AI-011:** An AI must not conceal blocked work to produce a satisfying final
  message.
- **AI-012:** An AI must not fabricate a model, fixture, server, device, account,
  secret, or external service to finish a test.
- **AI-013:** An AI must not download or commit model weights as an ordinary
  implementation shortcut.
- **AI-014:** An AI must not use synthetic data as an unnamed replacement for
  unavailable real evidence.
- **AI-015:** An AI must not convert warnings into passes when the capability
  requires the missing evidence.
- **AI-016:** An AI must not suppress errors, logs, or exit codes that contradict
  its desired result.
- **AI-017:** An AI must not modify user-authored unrelated work.
- **AI-018:** An AI must not delete anything because it appears temporary unless
  the exact target is within explicit approval.
- **AI-019:** An AI must stop before destructive or externally consequential
  action outside authorization.
- **AI-020:** An AI must distinguish observed facts, inferences, plans, and
  unknowns.
- **AI-021:** An AI must report newly discovered defects instead of hiding them
  to keep scope looking complete.
- **AI-022:** An AI must add discovered material debt to the appropriate audit,
  TODO, or task boundary when authorized.
- **AI-023:** An AI must prefer a narrow real vertical slice over many fake
  horizontal stubs.
- **AI-024:** An AI must preserve honest fail-closed behavior until replacement
  code genuinely works.
- **AI-025:** An AI must not call a document, enum, or test “implementation.”
- **AI-026:** An AI must not claim runtime effects from documentation-only work.
- **AI-027:** An AI must provide exact commands and observed summaries for
  verification it performed.
- **AI-028:** An AI must state when verification was impossible and why.
- **AI-029:** An AI must not let tone, mythic language, or confidence obscure
  technical truth.
- **AI-030:** An AI must push only authorized, reviewed, verified changes.

## 25. Mandatory Stop Conditions

An AI must stop implementation, preserve safe state, and report the boundary
when any of the following applies:

- **STOP-001:** The requested action requires deleting an unapproved file,
  function, module, model, fixture, data record, or history.
- **STOP-002:** The action requires Git configuration or remote changes without
  permission.
- **STOP-003:** Required credentials, licensed SDKs, private fixtures, or
  hardware are unavailable.
- **STOP-004:** A reasonable design choice would materially change the user's
  requested scope.
- **STOP-005:** The only way to claim success would be to simulate or fabricate
  the operation.
- **STOP-006:** The required external API or version contract cannot be verified.
- **STOP-007:** The worktree contains overlapping user changes that cannot be
  preserved safely.
- **STOP-008:** A destructive target cannot be resolved exactly.
- **STOP-009:** A test would need to touch non-test-owned user data.
- **STOP-010:** A model/artifact cannot legally or safely be committed.
- **STOP-011:** A capability requires physical evidence not available in the
  current environment.
- **STOP-012:** The requested claim exceeds the supported subset proved by the
  available oracle.
- **STOP-013:** A dependency upgrade would be required but is outside scope.
- **STOP-014:** Existing architecture documents conflict in a way that changes
  ownership materially and cannot be resolved from executable evidence.
- **STOP-015:** Safe cleanup or rollback cannot be guaranteed for an external
  mutation.

Stopping does not mean inventing partial success. The AI must state what is
complete, what is not, the exact blocker, preserved state, and the smallest
next authorization or prerequisite needed.

## 26. Pre-Edit Checklist

Before editing, the AI must be able to answer yes to every applicable item:

- [ ] I read `TODO.md` and the relevant ledger entry.
- [ ] I inspected the actual source, caller, and tests.
- [ ] I know the owning domain.
- [ ] I know the exact advertised operation.
- [ ] I reproduced the defect or first missing gate.
- [ ] I wrote and pushed the task/bug contract.
- [ ] I know what must remain unchanged.
- [ ] I know what files are out of scope.
- [ ] I know the success, failure, cleanup, and evidence contracts.
- [ ] I can implement a connected slice without fake placeholders.
- [ ] I do not need unapproved deletion or Git-setting changes.
- [ ] I know which commands will prove the result.

If an applicable answer is no, do not begin source implementation.

## 27. Function Admission Checklist

No new or materially changed production function is complete until:

- [ ] its name matches its mechanism;
- [ ] its owner and caller are known;
- [ ] it is reachable through the intended production path;
- [ ] inputs and preconditions are validated;
- [ ] arithmetic and spans are checked where relevant;
- [ ] ownership, borrowing, and lifetime are explicit;
- [ ] side effects occur through the owning domain;
- [ ] success derives from completed work;
- [ ] unsupported behavior fails closed;
- [ ] errors preserve actionable categories;
- [ ] partial failure and cleanup are defined;
- [ ] focused positive and negative tests exist;
- [ ] integration evidence crosses the claimed boundary;
- [ ] comments and interface documentation match;
- [ ] ledger/TODO status remains honest.

## 28. Pre-Commit Checklist

- [ ] The staged diff contains only the authorized slice.
- [ ] No pseudocode, placeholder return, fixed success, or canned operational
      output entered production paths.
- [ ] No orphan file, function, option, module, or interface was added.
- [ ] No model weight, binary, cache, log, secret, local path, or unregistered
      fixture is staged.
- [ ] Every new file passed the admission gate.
- [ ] Focused tests passed.
- [ ] Master suite results are known.
- [ ] Native build result is known.
- [ ] Deliberate negative control still proves failure propagation.
- [ ] Consistency, artifact, and fixture gates passed.
- [ ] `git diff --check` passed.
- [ ] Documentation and status claims match the evidence.
- [ ] The commit message does not overclaim.

## 29. Completion Checklist

Before saying the task is complete:

- [ ] The exact requested artifact or behavior exists.
- [ ] It is connected through the intended owner.
- [ ] It performs the advertised operation or clearly fails unsupported.
- [ ] Relevant success, edge, error, cleanup, and regression tests passed.
- [ ] External/hardware/protocol/persistence evidence is real where claimed.
- [ ] No synthetic evidence was promoted beyond its boundary.
- [ ] No known required work was hidden behind “complete.”
- [ ] Ledger, TODO, interfaces, task, roadmap, and DEVLOG are synchronized where
      applicable.
- [ ] The commit was pushed to the authorized real branch.
- [ ] Local HEAD and remote branch agree.
- [ ] Hosted CI for the exact commit passed, or its unavailable/pending state is
      reported honestly.
- [ ] Skips, blockers, legacy warnings, and remaining non-verified capabilities
      are reported.

## 30. Review Questions for Every AI Change

The reviewer must ask:

1. What exact real-world or runtime operation does this change claim?
2. Where is that operation actually performed?
3. What production entry point reaches it?
4. What inputs were real, synthetic, mocked, or absent?
5. What evidence crosses the claimed boundary?
6. Could the same test pass if the external system, device, network, or storage
   operation never happened?
7. Is any success output fixed, seeded, predetermined, or inferred?
8. Are errors being turned into plausible empty success?
9. Is a CPU/local/in-memory substitute wearing an external label?
10. Does the name exceed the mechanism?
11. Does the test title exceed the test?
12. Does documentation exceed executable evidence?
13. Are all accepted options applied or rejected?
14. Are ownership and cleanup complete under partial failure?
15. Are pointer spans, address spaces, and lifetimes proved?
16. Is the oracle independent?
17. Is the fixture classified and provenance complete?
18. Is the capability status narrow enough?
19. Did any unrelated or user-owned content change?
20. Was anything deleted without exact approval?
21. Did every new file pass admission?
22. Could this be a plan in Markdown instead of premature source?
23. Did the exact pushed commit pass the reported gates?
24. What remains missing after this change?

Any answer exposing a false implication blocks completion.

## 31. Enforcement and Escalation

- **ENFORCE-001:** Existing CI, counted tests, deliberate negative control,
  artifact classifier, fixture manifest validator, and documentation drift
  checks remain mandatory.
- **ENFORCE-002:** A written rule is not automatically a mechanical gate; do not
  claim CI enforces rules it does not yet scan.
- **ENFORCE-003:** When a deterministic violation is found repeatedly, add a
  checker rule and a self-test in a separately scoped implementation task.
- **ENFORCE-004:** Mechanical scans must avoid naive patterns that reject honest
  fail-closed scaffolds or documentation discussions.
- **ENFORCE-005:** Every new checker receives positive, negative, and false-
  positive regression cases.
- **ENFORCE-006:** Baseline-locked legacy warnings remain visible until exact
  cleanup is approved and completed.
- **ENFORCE-007:** A warning never promotes the affected capability.
- **ENFORCE-008:** New violations fail CI rather than expanding the baseline.
- **ENFORCE-009:** Do not weaken a gate to merge a violating change.
- **ENFORCE-010:** Fix the violating code or prove the gate wrong with a focused
  test and documented rule correction.
- **ENFORCE-011:** Capability promotion requires the relevant external or
  physical gate, not only the default CPU CI job.
- **ENFORCE-012:** Branch protection and required checks should reflect the
  verified support matrix when repository administration is authorized.
- **ENFORCE-013:** Final human review remains required for claims that cannot be
  determined mechanically.
- **ENFORCE-014:** If an AI violates these rules, its affected claims revert to
  non-verified until a fresh audit and executable proof restore trust.
- **ENFORCE-015:** Truth takes precedence over preserving an AI's work,
  confidence, status report, or completion narrative.

## 32. The Final Law

Project A.E.S.I.R. must never obtain the appearance of capability at the cost of
reality.

When real code is possible, write it completely, connect it, test it, document
it, and prove it. When real code is not yet possible, preserve the safe
boundary, state the missing prerequisite, and leave the capability honestly
non-verified.

No success-shaped fiction enters the forge.
