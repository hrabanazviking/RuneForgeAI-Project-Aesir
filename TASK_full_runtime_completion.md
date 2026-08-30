# Task: Full Runtime Completion and Working-Code Reconciliation

## Authorization

Volmarr authorized this work on August 29, 2026 with the instruction:
"fix all not working code so is all fully working the way it should and push
every step of the way."

This authorization covers additive implementation, repair, tests,
documentation, commits, and pushes on the active feature branch. It does not
override the repository law requiring separate approval before deleting files,
functions, modules, or data.

On August 29, 2026, Volmarr separately approved deletion of temporary files
and directories created by the model-store tests only. The approval excludes
tracked paths, pre-existing paths, user data, model weights, and production
store contents.

## System Statement

Project A.E.S.I.R. has a verified narrow Linux CPU/GGUF inference core, but its
broader public surface still contains partial, scaffolded, simulated, or
missing behavior. A public type or command is not "working" merely because it
compiles or fails honestly. It is working only when it performs its stated
operation, handles its failure boundaries, is connected to its owning domain,
and has executable evidence.

## Current Evidence Baseline

- Branch baseline: `31778ef4c9554d32fee0006658f42185746818a7` on
  `feat/project-consistency-reconciliation`.
- Canonical ledger population: 68 `verified`, 9 `partial`, 2 `scaffold`,
  1 `simulated`, and 27 `missing` capabilities.
- Master suite: 132 passed, 0 failed, 1 explicit external-fixture skip,
  total 133.
- Hosted GitHub Actions run `33239506861` passed the counted suite, native
  build, deliberate negative control, and consistency validator.
- The source inventory contains 681 public declarations across the CLI,
  server, loader, and core domains. Explicit incomplete boundaries remain in
  model management, interactive execution, service APIs, external formats,
  RAG, hardware, resilience/concurrency, Swarm, and operations.

## Definition of Done

A capability may move to `verified` only when all of the following are true:

1. The runtime performs the advertised operation instead of returning a fixed,
   seeded, simulated, or unsupported result.
2. Every public entry point is connected through the correct domain interface.
3. Inputs, ownership, errors, cleanup, and observable side effects have defined
   contracts and negative tests.
4. Local behavior has unit, boundary, integration, and regression evidence.
5. External compatibility has a pinned real fixture and independent oracle;
   physical acceleration has a reproducible run on the named hardware.
6. The capability ledger, TODO, interfaces, task record, and DEVLOG are updated
   in the same commit as the evidence.
7. The master suite, native build, consistency check, negative control, and
   hosted CI all pass.

Where an external prerequisite is unavailable, the boundary must continue to
fail closed and the capability must remain non-verified. The absence of
hardware, credentials, a model fixture, or a supported upstream runtime must
never be disguised as success.

## Owning Domains

- **Project operations:** CI, artifact policy, dependency and release evidence.
- **CLI and storage:** configuration, help, REPL, persistent manifests, model
  mutation, session reporting, and distribution commands.
- **Server:** transport ownership, request parsing, routing, inference calls,
  streaming, lifecycle, limits, and compatibility schemas.
- **Loader:** GGUF generalization, quantized layouts, external formats,
  download/ingestion, and malformed-input handling.
- **Core memory and inference:** cache/tensor safety, generation, sampling,
  grammar, speculative execution, RAG primitives, and compute correctness.
- **Hardware:** physical discovery, allocation, transfer, synchronization, and
  device kernels, each proved on its named target.
- **Resilience and distributed execution:** state persistence, events, workers,
  failure recovery, authenticated membership, and remote work.

## Staged Work Order

### Stage A — Executable census and defect reproduction

1. Reconcile every non-verified ledger entry with its public declarations,
   tests, runtime reachability, external prerequisites, and first failing
   acceptance gate.
2. Run the existing suite, build, CLI smoke tests, configuration checks, and
   source scans from a clean checkout.
3. Record newly discovered concrete defects before changing their owning code.

### Stage B — Local foundation and safety debt

1. Resolve misleading cache terminology and unsafe sentinel-bearing test
   constructors.
2. Complete malformed GGUF regression corpus and deterministic loader fuzz
   seeds without committing model weights.
3. Profile and replace tokenizer merge behavior only with ID-parity evidence.
4. Close remaining local error, cleanup, arithmetic, and ownership defects.

### Stage C — Configuration, CLI, persistent model store, and REPL

1. Make the human-editable configuration file authoritative and validated.
2. Connect acceleration selection to observed supported backends.
3. Complete help output for the actually supported command grammar.
4. Implement an empty durable content-addressed model store with atomic
   mutation, restart, corruption, permission, and concurrency semantics.
5. Connect `list`, `show`, `create`, `cp`, `rm`, `ps`, and `stop` to real state.
6. Connect interactive stdin, conversation state, slash commands, parameter
   changes, cancellation, and real engine generation.

### Stage D — Live service and first compatibility surface

1. Move socket/serialization ownership behind a service interface.
2. Implement bounded accept/serve lifecycle, request IDs, structured errors,
   timeouts, cancellation, backpressure, and graceful shutdown.
3. Select and document one pinned OpenAI-compatible API subset.
4. Connect typed request parsing, real GGUF generation, usage accounting,
   JSON/SSE framing, and official-client wire tests.

### Stage E — Corpus ingestion, embeddings, and end-to-end RAG

1. Implement deterministic supported-format ingestion and chunk metadata.
2. Connect verified embeddings, durable index versioning, update/delete/reindex,
   restart, and corruption behavior.
3. Prove retrieval quality, context budgeting, source metadata, citations, and
   explicit no-result behavior.

### Stage F — Quantized inference and ecosystem formats

1. Implement exact upstream Q4_K_M layout, spans, authoritative decoder parity,
   safe GGUF mapping, fused/dequantized matmul, and real quantized model parity.
2. Add further quantization formats only one real fixture and oracle at a time.
3. Scope ONNX, EXL2, llama.cpp CLI, and Hugging Face distribution separately;
   complete each only with its real format/transport contract and conformance
   evidence.

### Stage G — Concurrency, resilience, grammar, and speculative decoding

1. Implement subscriber delivery and a bounded worker pool with deterministic
   ordering, ownership, cancellation, failure, and shutdown behavior.
2. Implement durable state/checkpoint ownership and injected-failure recovery.
3. Complete tokenizer-aware grammar state and reference-constrained generation.
4. Complete draft/target probability acceptance, rollback, and KV coordination.

### Stage H — Physical acceleration and multi-device execution

1. Inventory physically available backends and select one first target.
2. Implement real discovery, allocation, transfer/zero-copy, synchronization,
   one genuine kernel, CPU parity, and one model-integrated slice.
3. Add a reproducible hardware gate before changing the ledger status.
4. Extend to other backends and multi-device behavior only when their hardware
   and vendor runtimes are available for verification.

### Stage I — Swarm, portability, security, observability, and release

1. Implement authenticated network membership and one real remote inference
   request before expanding distributed claims.
2. Add platform abstractions and CI only for platforms that can be built and
   exercised.
3. Complete threat model, limits, secret redaction, structured observability,
   benchmark methodology, packaging, provenance, and upgrade/rollback gates.

## Invariants to Preserve

- Preserve the pinned F16 GGUF token and multi-token parity evidence.
- Preserve fail-closed behavior until the replacement is genuinely connected.
- Never promote a capability from synthetic or same-process evidence alone.
- Never commit model weights, credentials, machine-specific paths, build
  outputs, caches, or fabricated measurements.
- Preserve AGPL-3.0, NOTICE, attribution, and domain boundaries.
- Use additive repairs; request explicit approval before any deletion.
- Keep each commit reviewable, tested, documented, and pushed before beginning
  the next substantial slice.

## Push and Evidence Routine

For every implementation slice:

1. Write or update the scoped task/bug evidence.
2. Commit and push the evidence boundary.
3. Implement one connected behavior with tests.
4. Run the narrow suite, master suite, native build, consistency validation,
   negative control, and `git diff --check` as appropriate.
5. Reconcile ledger/TODO/interfaces/DEVLOG.
6. Commit and push the verified slice.
7. Observe hosted CI before starting the next high-risk slice.

## First Execution Slice

Begin with Stage A and Stage B because later CLI, service, quantization, and
hardware work all depend on trustworthy ownership, loader behavior, and test
evidence. The first implementation commit will address the highest-severity
locally reproducible defect found by that census; it will not bundle unrelated
feature work.

## Progress — Slice 1: CLI Configuration Truth Boundary

- Reproduced Bug 0021: unreachable `config`, ignored `--config`/`--accel`,
  option leakage into prompts, and no-argument dispatch to unsupported `serve`.
- Connected configuration file reading/validation and normalized output.
- Made explicit acceleration intent fail closed before the verified CPU engine.
- Separated recognized flags from positional model/prompt tokens.
- Added regression coverage and passed the 133-case master proving suite plus a
  clean native build. Hosted CI evidence is recorded after the slice push.

## Progress — Slice 2: CLI Option Applicability

- Recorded explicit presence for every parsed flag.
- Added a command-specific single-shot applicability gate.
- Rejected every option and config field that lacks a connected runtime owner,
  before model loading or other side effects.
- Changed the tracked config to neutral values for unconnected capabilities.
- Preserved 132/0/1/133 master-suite evidence and a clean native build.
