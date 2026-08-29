# Project A.E.S.I.R. Reality-First Completion Roadmap

- **Status:** Active execution roadmap
- **Established:** August 29, 2026
- **Owning method:** Mythic Engineering
- **Canonical capability authority:** [`CAPABILITY_LEDGER.md`](CAPABILITY_LEDGER.md)
- **Canonical backlog:** [`TODO.md`](TODO.md)
- **Primary audit:** [`PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md`](PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md)
- **Active completion contract:** [`TASK_full_runtime_completion.md`](TASK_full_runtime_completion.md)

## Purpose

This document orders all known remaining repair and completion work and defines
the laws that prevent fake files, fake capabilities, fake evidence, fake
measurements, and success-shaped placeholders from entering the repository.

It does not replace the capability ledger. The ledger remains the present-tense
source of truth. This roadmap describes sequence and acceptance gates. `TODO.md`
retains the detailed backlog. Bug notes retain reproductions and local repair
contracts. When these sources disagree, the narrowest executable evidence wins,
and the disagreement must be repaired before capability work continues.

“All needed fixes” means every known non-verified capability, unchecked backlog
class, audit finding, open bug boundary, and artifact-hygiene issue at this
snapshot. Newly discovered defects enter through the intake rule below; the
roadmap must never pretend that unknown future defects have already been ruled
out.

## Current Evidence Snapshot

At the creation of this roadmap:

- the capability ledger contains 107 capabilities: 68 `verified`, 9 `partial`,
  2 `scaffold`, 1 `simulated`, and 27 `missing`;
- the master suite reports 132 passed, 0 failed, 1 explicit external-fixture
  skip, total 133;
- the verified runtime boundary is one pinned GGUF v3 Llama F16 model on the
  configured Linux CPU path;
- 39 capabilities remain non-verified;
- `TODO.md` contains 130 unchecked items, including follow-up work whose narrow
  primitives may already be verified;
- the durable model catalog and configured relative store root exist, while
  content-addressed blobs and operational CLI wiring remain incomplete; and
- artifact hygiene remains `partial`: seven tracked ELF executables, one tiny
  placeholder `.gguf`, and 24 duplicate root image assets await separate
  deletion approval.

Snapshot numbers are orientation data, not permanent truth. The ledger and
automated checks must be consulted before every implementation slice.

## Governing Principles

1. Reality precedes presentation.
2. A name, file extension, type, enum, interface, banner, or test title is not
   proof that an operation exists.
3. Synthetic tests prove only synthetic invariants. External compatibility,
   persistence, networking, hardware, and performance require external or
   physical evidence appropriate to the claim.
4. Unsupported behavior must fail clearly and nonzero. It must not emit a
   successful, healthy, validated, downloaded, accelerated, recovered, or
   completed result.
5. Every substantial slice begins with a task or bug contract and ends with
   synchronized code, tests, interfaces, ledger, TODO, and devlog evidence.
6. No tracked file is deleted without Volmarr's explicit approval for that
   exact deletion scope. The existing approval covers only temporary paths
   created by model-store tests.
7. Model weights, credentials, machine-specific paths, caches, logs, build
   outputs, and unmeasured benchmark results do not belong in source control.
8. Useful verified foundations are preserved by regression tests while broader
   claims remain fail-closed.

## What Counts as a Fake File

A fake file is any repository artifact whose name, extension, placement,
content, metadata, or surrounding claim implies evidence or functionality that
the file does not actually contain. The term includes more than empty files.

Examples include:

- a `.gguf`, `.onnx`, `.safetensors`, archive, database, executable, image, or
  structured-data file whose bytes do not conform to the named format;
- a tiny placeholder model stored under a real model extension;
- a compiled executable committed as if it were source or a reproducible
  release artifact;
- a copied image stored under multiple names without distinct purpose;
- an empty or filler file created only to make a feature or directory appear
  complete;
- pseudocode, `pass`, fixed-success output, invented metadata, seeded devices,
  predetermined network responses, or fabricated measurements presented as
  runtime implementation;
- a fixture described as real, compatible, representative, or authoritative
  when it is synthetic or lacks provenance;
- generated data with no source, generator version, license, checksum, or
  reproducible construction record;
- a document marked complete while it contains unfinished sections, invented
  citations, stale capability claims, or unverified certainty;
- a filename or comment claiming CUDA, Metal, NPU, zero-copy, recovery,
  concurrency, persistence, protocol parity, or production readiness when the
  named mechanism did not execute; and
- an orphan file with no owner, consumer, test, documentation role, or
  intentional archival classification.

Legitimate minimal synthetic fixtures are not fake when they are explicitly
labeled synthetic, live under a test-owned fixture boundary, exercise a narrow
documented invariant, contain valid bytes for that invariant, and are never
used as proof of external compatibility.

## Immutable Anti-Fabrication Rules

### Identity and format rules

1. File extensions must match validated file content; a filename alone never
   establishes type.
2. Binary formats must pass magic, header, version, length, offset, and checksum
   checks appropriate to the supported subset.
3. Empty and tiny files are rejected unless the owning format explicitly
   permits them and a focused test proves the intended empty-file behavior.
4. Placeholder model files may use `.example`, `.md`, or explicit metadata,
   never a production model extension.
5. Test fixtures must be classified as `synthetic`, `malformed`, `regression`,
   or `external-reference`; the classification must be visible in their path or
   adjacent manifest.
6. Synthetic fixtures must never be cited as hardware, protocol, ecosystem,
   model-format, persistence, or performance parity evidence.

### Ownership and usefulness rules

7. Every new tracked file must have one owning domain and one stated purpose.
8. Every runtime or data file must have a real consumer, validation path, and
   failure contract before it is admitted.
9. Public modules require an interface contract; important directories require
   a README describing what they own and forbid.
10. No orphaned implementation, unused compatibility shell, disconnected
    option, uncalled feature module, or success-shaped stub may be merged.
11. Static data belongs in data/configuration files; reasoning and execution
    logic belongs in code. Runtime state must not rewrite immutable base data.
12. Names must describe the mechanism actually used. A CPU loop cannot be
    labeled a GPU/NPU kernel, and an FNV fingerprint cannot be labeled SHA-256.

### Provenance rules

13. Any generated artifact intended for tracking must record its source inputs,
    producing tool and version, exact command or deterministic procedure,
    license, date, and cryptographic checksum.
14. Imported assets must record origin, license, attribution, and whether they
    are modified.
15. External test fixtures remain outside Git when licensing or size requires
    it. Their immutable revision, filename, checksum, retrieval procedure, and
    independent oracle belong in documentation.
16. No invented citations, hashes, timestamps, sizes, versions, device names,
    benchmark values, usage totals, or provenance fields are permitted.
17. Machine-local absolute paths are never committed. Paths are relative or
    dynamically resolved from caller configuration.

### Source and runtime truth rules

18. Pseudocode in source files is forbidden. Future behavior belongs in
    Markdown plans until complete executable code can be connected.
19. `TODO`, `pass`, placeholder returns, fixed responses, and predetermined
    success values are forbidden in reachable production paths.
20. A scaffold may preserve types or local primitives only when its external
    operation fails closed and its ledger status remains `scaffold`,
    `simulated`, `partial`, or `missing` as appropriate.
21. Every accepted CLI/config/API option must be applied by its owner or
    rejected before side effects. Silent ignoring is forbidden.
22. Every state-changing success must be derived from observed completed side
    effects and survive the persistence/restart boundary claimed by the API.
23. Errors must not be converted into plausible empty success. Not-found,
    permission, corruption, timeout, cancellation, and unsupported conditions
    remain distinct.
24. No broad exception handler may fabricate recovery. Recovery is a verified
    state transition with preserved or restored invariants.

### Evidence and claim rules

25. Capability status changes occur in the same commit as their executable
    evidence and documentation reconciliation.
26. `verified` requires the exact operation in the heading to execute. A helper
    or shape-compatible simulation cannot promote the surrounding subsystem.
27. Hardware claims require observed physical devices, real allocation or
    mapping, real kernel dispatch, synchronization, CPU/reference parity, and a
    reproducible hardware record.
28. Compatibility claims require a pinned upstream version, real fixture,
    independently produced oracle, supported-subset statement, negative cases,
    and wire/byte-level comparison.
29. Benchmark files require measured runs, hardware/software/model identity,
    warmup, sample count, statistics, raw results, and reproduction commands.
30. “Complete,” “production-ready,” “drop-in,” “parity,” “zero-copy,”
    “accelerated,” and “self-healing” are prohibited unless their exact ledger
    acceptance gate has passed.

### Repository hygiene rules

31. Never track build outputs, caches, logs, local databases, downloaded model
    weights, secrets, tokens, private keys, crash dumps, or editor state.
32. Release binaries belong in a release pipeline with checksums, signatures,
    provenance, and reproducible build records—not loose in the source tree.
33. Duplicate byte-identical assets require one canonical source plus links or
    references; copies require documented distinct ownership.
34. Historical documents live under the historical boundary and must not be
    interpreted as current implementation truth.
35. A warning about known hygiene debt cannot be treated as a passing
    sub-capability. The ledger remains non-verified until the debt is resolved.
36. Deletion is never inferred from cleanup language. Exact targets must be
    inventoried and explicitly approved before removal.

### Data-size and safety reconciliation

37. Data must never be silently truncated to create success.
38. Safety ceilings for untrusted input are allowed and required when they are
    configurable or contractually defined, checked before allocation, reported
    explicitly, and do not corrupt or partially accept data.
39. Limits must be justified by ownership, platform capacity, protocol, or
    threat-model evidence—not arbitrary convenience constants.

## File Admission Gate

Before adding any file, answer all of these in the task or review record:

- What domain owns it?
- What exact purpose does it serve?
- What consumes it now?
- Is it source, configuration, documentation, fixture, generated artifact,
  external reference, runtime state, build output, or release output?
- What validates its format and failure cases?
- What evidence may it support, and what may it never be used to prove?
- Is its provenance and license known?
- Could the same purpose be served by an existing canonical file?
- Does `.gitignore` correctly exclude its runtime/generated class?
- Does adding it create a new public interface or documentation obligation?

If any answer is missing, the file is not admitted. Plans may document the
future need, but no placeholder implementation file is created.

## Required Metadata for Tracked Generated Artifacts

When a generated artifact is genuinely appropriate for Git, its adjacent
manifest must contain:

```text
purpose
owner
source inputs and immutable revisions
generator/tool and version
reproduction command or deterministic procedure
created date
license and attribution
SHA-256 checksum
expected consumer
validation command
evidence boundary
```

Missing metadata makes the artifact inadmissible. Model weights remain outside
Git even when metadata is complete unless Volmarr explicitly changes that law
and licensing permits redistribution.

## Automated Prevention Gates

The repository consistency checker and CI must evolve to enforce, not merely
describe, these rules.

| Gate | Required behavior |
|---|---|
| Tracked artifact classifier | Fail on ELF/PE/Mach-O binaries, objects, shared libraries, caches, logs, local databases, crash dumps, and model weights outside approved release/test boundaries. |
| Extension/content verifier | Inspect magic/header/schema for tracked binary and structured-data extensions; reject extension/content mismatches and tiny placeholder models. |
| Fixture manifest validator | Require classification, purpose, owner, checksum, construction/retrieval method, and evidence boundary for test fixtures. |
| Duplicate-content guard | Detect byte-identical assets and require one canonical file or an explicit duplication exception. |
| Provenance guard | Require generated/imported artifact metadata, license, tool version, and reproduction record. |
| Placeholder/source scan | Reject pseudocode, reachable fixed-success signatures, invented metadata patterns, seeded external state, and unsupported branches that emit success language. |
| Secret and path scan | Reject credentials, tokens, private keys, machine-local absolute paths, and unsafe path traversal patterns. |
| Orphan/connectivity scan | Detect new public modules/options/files with no registered consumer, interface entry, or focused test. |
| Claim/ledger drift guard | Validate status counts, capability IDs, evidence cases, prohibited maturity language, TODO state, interface claims, and devlog synchronization. |
| Test truth guard | Preserve counted fail-closed reporting and deliberate negative control; distinguish synthetic, external-fixture, and physical-hardware evidence. |
| Clean-checkout gate | Build and run the master suite from a clean checkout with no dependency on untracked local files. |
| Release provenance gate | Produce release artifacts only through a versioned workflow with hashes, signatures, SBOM/provenance, and installation verification. |

The current checker already covers part of this matrix. Every remaining row is
roadmap work; documentation of a gate is not proof that the gate exists.

## Execution Protocol for Every Fix

1. Re-read `TODO.md`, the capability entry, owning interface, active task, and
   related bug notes.
2. Reproduce the exact defect or first failing acceptance gate.
3. Write or update a scoped task/bug contract before code.
4. Commit and push the contract.
5. Implement one connected vertical slice without orphaned code.
6. Add unit, boundary, integration, regression, invariant, and negative tests
   proportional to the claim.
7. Run the focused test, master suite, native build, deliberate negative
   control, consistency checker, artifact scan, and `git diff --check`.
8. Reconcile the ledger, TODO, interfaces, architecture/data-flow docs, and
   devlog in the same implementation commit.
9. Push the slice and observe hosted CI before beginning the next high-risk
   slice.
10. If deletion becomes necessary, stop, list exact targets, and obtain new
    explicit approval before deleting anything.

## Ordered Repair and Completion Roadmap

### Phase 0 — Make repository truth mechanically enforceable

**Progress:** The first prevention slice is implemented: a baseline-locked data
policy records the exact 32 deletion-blocked legacy artifacts, deterministic
self-tests prove the policy semantics, and CI rejects new tracked executable,
build, model, archive, runtime-state, private-key-format, tiny-placeholder, and
duplicate-root-asset violations. Legacy matches remain visible warnings;
content-level secret detection, format validation, fixture/provenance rules,
release controls, cleanup, and full-history scanning remain open.

- Expand `scripts/check_doc_drift.py` into the automated prevention matrix
  above, beginning with fatal new-artifact detection while preserving the
  existing warning for deletion-blocked legacy artifacts.
- Add a fixture/provenance manifest schema and canonical fixture directories.
- Reconcile stale TODO wording against the already landed durable catalog and
  configuration slices without falsely closing blob or CLI capabilities.
- Re-run the public declaration census and create bug records for newly found
  misleading, unreachable, unsafe, duplicated, or unowned surfaces.
- Request separate deletion approval for the seven tracked executables, tiny
  placeholder GGUF, and 24 duplicate root images. Remove only approved exact
  paths, then make the artifact gate fatal and promote `AES-FND-007` only when
  the clean checkout proves it.

**Exit gate:** A clean checkout contains no unapproved generated/fake artifacts,
new violations fail CI, and `AES-FND-007` has truthful executable evidence.

### Phase 1 — Close local safety and loader debt

- Correct misleading ring-buffer terminology unless real chronological
  wraparound is implemented and tested.
- Replace sentinel-bearing runnable transformer descriptors with safe explicit
  non-runnable fixtures or fully valid tensors.
- Instrument steady-state token-path allocations and remove or account for
  remaining list/string/workspace allocation (`AES-MEM-006` and follow-up to
  the verified memory primitives).
- Build a small valid/malformed GGUF regression corpus with explicit fixture
  classification; add deterministic fuzz seeds and a fuzz harness.
- Add broader real F16 external fixtures only with checksums, licensing, and
  independent oracles.
- Profile and replace tokenizer merge behavior only if token-ID parity and
  performance evidence justify the change.

**Exit gate:** Invalid memory/loader/tokenizer inputs fail before unsafe access,
cleanup survives injected failure, fixture provenance is complete, and no
synthetic corpus is presented as broad format compatibility.

### Phase 2 — Complete the model store and operational CLI

- Add content-addressed model blobs, SHA-256 over the stored bytes, exact byte
  sizes, blob/reference integrity checks, and garbage-collection policy.
- Prove absent store, restart, corruption, missing blob, permission denial,
  atomic rollback, concurrent writers, duplicates, not-found, and in-use rules.
- Connect `list`, `show`, `create`, `cp`, and `rm` to the configured durable
  store; connect `ps` and `stop` only after a live session registry exists.
- Apply each supported configuration and CLI option to its owning subsystem or
  reject it before side effects.
- Complete help from the actually supported grammar and stable error/exit-code
  contracts.
- Connect interactive stdin, conversation state, slash commands, cancellation,
  and real engine generation; remove all response-shaped local simulation.

**Exit gate:** Separate built-CLI processes observe the same verified durable
state, every accepted option has an effect, interactive output comes from the
engine, and `AES-CLI-004` through `AES-CLI-009` are reconciled narrowly.

### Phase 3 — Build one real bounded service surface

- Move socket ownership and serialization behind a service-domain interface.
- Implement bounded accept/read/write/close lifecycle, request/session IDs,
  typed errors, limits, timeouts, cancellation, backpressure, and graceful
  shutdown.
- Default to a safe local bind; document authentication, TLS, origin, and
  exposure policy before non-local operation.
- Select one pinned OpenAI-compatible subset first. Parse typed requests,
  invoke real GGUF generation, derive usage from actual tokenization, and emit
  correct JSON/SSE framing and termination.
- Prove wire behavior with an official or authoritative client plus malformed,
  disconnect, partial-write, cancellation, and concurrent-load tests.
- Keep llama.cpp and Ollama HTTP routes unsupported until separately scoped and
  independently verified.

**Exit gate:** `AES-SRV-005`, `AES-SRV-006`, and `AES-SRV-009` have live
end-to-end evidence; other protocol surfaces remain honestly non-verified.

### Phase 4 — Complete embeddings and RAG

- Require real loaded embedding weights; never restore prompt-hash fallback
  vectors.
- Define supported ingestion formats, parsers, chunking, metadata, provenance,
  deduplication, and deterministic document identity.
- Add durable versioned index storage with update, delete, reindex, restart,
  migration, and corruption behavior.
- Budget retrieved context using tokenizer tokens and the loaded model context,
  never a fixed byte cap.
- Build a cited evaluation corpus and record recall/ranking, no-result,
  source-attribution, and prompt-injection behavior.

**Exit gate:** `AES-RAG-003` through `AES-RAG-005` execute end to end with real
embeddings, durable data, measured retrieval quality, and explicit provenance.

### Phase 5 — Complete quantized inference one format at a time

- Start with exact upstream Q4_K_M byte layout, scales/minima, block sizes,
  spans, tails, and authoritative decoder parity.
- Map and own Q4_K_M tensors safely in `GGUFSeer`.
- Implement correct dequantized or fused matmul and compare logits, tokens, and
  text against a pinned real quantized GGUF oracle.
- Add each further GGML quantization format only with its own exact fixture,
  decoder parity, model parity, and negative cases.
- Keep GPTQ, AWQ, EXL2, HQQ, SmoothQuant, and other ecosystems unsupported until
  their own format/runtime projects pass.

**Exit gate:** `AES-LDR-006` and `AES-QNT-003` are verified first for a narrowly
named real format/model slice; no toy block test is cited as model support.

### Phase 6 — Prove the first physical accelerator

- Separate configured, runtime-loadable, and physically discovered devices.
- Select one backend actually present on controlled hardware.
- Implement real driver/runtime discovery, allocation, ownership, transfer or
  precisely supported zero-copy, kernel launch, synchronization, and errors.
- Compare one genuine device kernel to the CPU/reference path, then integrate
  one real-model inference slice and preserve token/logit parity.
- Add a reproducible hardware gate before publishing performance or changing
  capability status.
- Extend to CUDA, Metal, Intel, AMD, MAX, and vendor NPUs only on hardware where
  each backend can be built and exercised.
- Begin multi-device placement only after single-device correctness; then prove
  partitioning, collectives, overlap, device loss, and deterministic recovery.

**Exit gate:** The first narrow backend has physical evidence for
`AES-ACC-003` and the applicable dispatch capability. Other backends remain
missing rather than inheriting the first backend's evidence.

### Phase 7 — Finish concurrency, resilience, grammar, and speculative decoding

- Build real bounded queues, subscriber delivery, worker ownership,
  deterministic shutdown, cancellation, and failure propagation.
- Implement versioned durable checkpoints and recovery only for explicitly
  recoverable state; prove injected failure and restart.
- Replace the remaining recovery simulation with observed process/state
  transitions and fail-safe limits.
- Complete tokenizer-aware GBNF state transitions and reference-constrained
  generation.
- Complete draft/target speculative acceptance, rejection sampling, KV
  rollback, and target-distribution parity; publish speed benefit only after a
  valid benchmark.

**Exit gate:** `AES-RES-005` is no longer simulated, concurrency is bounded and
observable, and grammar/speculative claims match end-to-end model behavior.

### Phase 8 — Complete distribution and optional ecosystems separately

- Implement real Hugging Face HTTPS transfer with authentication, redirects,
  resume/retry, cancellation, expected digest/size verification, atomic store
  promotion, and secret redaction.
- Scope registry `pull`, `push`, and model creation independently with conflict,
  integrity, rollback, and authentication behavior.
- Parse one pinned real ONNX protobuf and execute a documented operator/type/
  shape subset against ONNX Runtime.
- Scope EXL2 conversion/inference as its own format and CUDA-dependent project.
- Define any llama.cpp CLI compatibility by exact upstream version and selected
  subcommands; never infer CLI parity from token-oracle parity.

**Exit gate:** Each of `AES-ECO-003` through `AES-ECO-006` has separate real
transport/format/conformance evidence or remains explicitly missing.

### Phase 9 — Build real Swarm execution

- Define protocol/version, node identity, capability advertisement, trust,
  authentication, authorization, replay protection, and secret handling.
- Replace seeded peers with configured and observed liveness state.
- Prove join, leave, and heartbeat between separate processes.
- Execute one real remote inference request, including model availability,
  timeout, cancellation, node loss, retry, and result-integrity behavior.
- Derive CLI/REST status only from live cluster state.

**Exit gate:** `AES-SWM-003` through `AES-SWM-005` pass multi-process and
failure-path evidence; no constructed text stands in for transport.

### Phase 10 — Portability, security, observability, and release readiness

- Introduce platform filesystem, mapping, socket, clock, threading, and dynamic
  library boundaries before claiming Windows, macOS, iOS, Android, or Raspberry
  Pi support.
- Add clean CI on each named platform; unsupported platforms remain unclaimed.
- Write and enforce the threat model for untrusted models, corpora, prompts,
  network requests, paths, plugins, credentials, and distributed peers.
- Add fuzzing, configurable resource ceilings, secure permissions, secret
  redaction, dependency policy, and vulnerability response.
- Add structured logs, trace/request IDs, truthful health, real metrics, and
  diagnosable error chains without leaking prompts or secrets by default.
- Build a real benchmark harness with raw results and reproducibility metadata.
- Define packaging, install/uninstall, upgrades, rollback, checksums,
  signatures, SBOM, provenance, licensing, and third-party attribution.
- Enable branch protection and required CI only after the gates are stable.

**Exit gate:** `AES-FND-005`, `AES-FND-006`, and `AES-OPS-001` through
`AES-OPS-005` satisfy their narrow ledger contracts. Production-readiness
language remains forbidden until every production gate passes.

### Phase 11 — Optional experimental systems and product polish

- Treat CIA, WIC, NSFI, MQARI, SKÁLDBRØÐIR, thinking control, tool use, smart
  crash diagnosis, TUI, and novel inference research as separate capabilities.
- Give each system a stable capability ID, owning domain, configuration
  contract, disable path, accuracy/safety hypothesis, integration tests, and
  evidence boundary before presenting it as operational.
- Preserve local helper primitives where useful, but do not promote a helper
  test to end-to-end inference capability.
- Build the TUI only on truthful runtime telemetry and supported actions.
- Research novel acceleration behind opt-in experimental gates; require
  accuracy parity and reproducible measurement before performance claims.

**Exit gate:** Each experimental/product surface is either independently
verified under a narrow ID or visibly unsupported. No feature exists only as a
decorative file, option, or banner.

## Canonical Non-Verified Capability Traceability

| Capability | Current status | Roadmap owner |
|---|---|---|
| AES-FND-005 | partial | Phase 10 — CI/branch protection/external fixtures |
| AES-FND-006 | missing | Phase 10 — platform abstractions and platform CI |
| AES-FND-007 | partial | Phase 0 — artifact cleanup and fatal prevention gate |
| AES-MEM-004 | missing | Phase 1, then service concurrency — real paged cache |
| AES-MEM-006 | missing | Phase 1 — failure cleanup and allocation ownership |
| AES-LDR-006 | missing | Phase 5 — real quantized GGUF loading |
| AES-CLI-004 | partial | Phase 2 — content-addressed blob store |
| AES-CLI-005 | missing | Phase 2 — durable catalog and live process output |
| AES-CLI-006 | missing | Phase 8 — real transfer and creation operations |
| AES-CLI-007 | missing | Phase 2/8 — durable mutation and runtime lifecycle |
| AES-CLI-008 | scaffold | Phase 2 — real interactive inference |
| AES-CLI-009 | partial | Phase 2 — applied/rejected options and conformance |
| AES-SRV-005 | scaffold | Phase 3 — real response formatting from execution |
| AES-SRV-006 | missing | Phase 3 — OpenAI-compatible live execution |
| AES-SRV-007 | missing | Phase 8 — selected llama.cpp HTTP subset |
| AES-SRV-008 | missing | Phase 8 — selected Ollama HTTP subset |
| AES-SRV-009 | missing | Phase 3 — bounded concurrent service |
| AES-RAG-003 | partial | Phase 4 — verified query embeddings |
| AES-RAG-004 | missing | Phase 4 — ingestion and durable index |
| AES-RAG-005 | partial | Phase 4 — end-to-end evaluated RAG |
| AES-QNT-003 | partial | Phase 5 — real quantized-model inference |
| AES-ACC-003 | missing | Phase 6 — observed physical discovery |
| AES-ACC-004 | missing | Phase 6 — real multi-device execution |
| AES-ACC-006 | missing | Phase 6 — vendor NPU dispatch |
| AES-ACC-008 | missing | Phase 6 — real GPU dispatch |
| AES-ACC-009 | missing | Phase 6 — proved device-memory mapping path |
| AES-ECO-003 | missing | Phase 8 — verified Hugging Face download |
| AES-ECO-004 | missing | Phase 8 — real ONNX parse/execution subset |
| AES-ECO-005 | missing | Phase 8 — real EXL2 format/runtime |
| AES-ECO-006 | missing | Phase 8 — selected llama.cpp CLI compatibility |
| AES-RES-005 | simulated | Phase 7 — observed recovery and checkpoint proof |
| AES-SWM-003 | missing | Phase 9 — real membership/liveness |
| AES-SWM-004 | missing | Phase 9 — real remote inference dispatch |
| AES-SWM-005 | missing | Phase 9 — live Swarm CLI/REST state |
| AES-OPS-001 | missing | Phase 10 — reproducible benchmark harness |
| AES-OPS-002 | missing | Phase 1/10 — measured runtime efficiency/safety |
| AES-OPS-003 | partial | Phase 3/10 — threat model and enforced controls |
| AES-OPS-004 | partial | Phase 3/10 — structured observability |
| AES-OPS-005 | missing | Phase 10 — production-readiness gate |

## Newly Discovered Issue Intake

Every newly discovered bug, missing capability, false claim, unsafe boundary,
or fake-file risk must be handled immediately as follows:

1. Record it in a bug/task Markdown file with symptom, owner, violated
   invariant, reproduction, scope, and acceptance gate.
2. Add or update a stable capability ID if it changes a public claim.
3. Add it to `TODO.md` and this roadmap phase if the work is not completed in
   the discovery slice.
4. Fail closed in reachable production behavior until the real implementation
   is verified.
5. Add a regression or consistency rule so the same deception or defect cannot
   silently return.

New findings are evidence of the roadmap working, not permission to declare the
roadmap complete early.

## Global Definition of Done

Project A.E.S.I.R. reaches the end of this roadmap only when:

- every capability has a truthful status and every production claim maps to a
  verified ledger entry;
- every advertised operation executes end to end through its owning interfaces;
- all known P0/P1 defects and safety-boundary violations are closed with tests;
- external formats, protocols, hardware, distribution, and performance claims
  have pinned independent evidence;
- unsupported optional surfaces fail clearly without success-shaped output;
- a clean checkout contains no fake, placeholder, duplicate, generated,
  secret, machine-local, or unproven release artifacts;
- all admission and prevention gates run in required CI;
- supported platforms build and pass their platform-specific suites;
- security, observability, packaging, provenance, licensing, upgrade, rollback,
  and disaster-recovery gates pass; and
- TODO, ledger, interfaces, architecture, data flow, devlog, roadmap, and
  release notes agree in the same commit.

Until then, the project may celebrate narrow victories—but it must name them
narrowly. The rune of truth is simple: no file and no claim may pretend to be
more than the evidence beneath it.
