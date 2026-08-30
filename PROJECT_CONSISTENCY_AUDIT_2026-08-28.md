# Project A.E.S.I.R. Consistency Audit — August 28, 2026

## Authority

This audit supports `TASK_project_consistency_reconciliation.md` and applies
the status contract in `CAPABILITY_LEDGER.md`. A passing synthetic test proves
only the local behavior it executes. It does not prove external hardware,
network transport, model-format compatibility, persistence, performance, or
production readiness.

## Baseline

- Source branch: `main` at
  `c1d02d1919dc8c98971507b80ddb46a5a24af37f`.
- Master suite: 132 passed, 0 failed, 1 skipped, 133 total.
- Documentation drift check: passed despite the contradictions below.
- Compiler output: three unused-assignment warnings.

## Critical Truth-Boundary Findings

### AES-CONS-001 — Hardware-library presence is reported as physical hardware

`CUDAGate`, `AMDGate`, `IntelGate`, `MetalGate`, and `NPUGate` treat a loadable
runtime library or exported symbol as one detected device. The functions do not
call the vendor device-count APIs. This can report hardware that was never
observed.

### AES-CONS-002 — Host allocations are labeled device allocations

The GPU/NPU allocation functions use Mojo host `alloc()` and return the host
pointer while their names and documentation claim CUDA VRAM, HIP VRAM, Level
Zero device memory, Metal buffers, or NPU buffers. Copy functions perform no
copy. This is simulated device memory, not a partial physical implementation.

### AES-CONS-003 — CPU loops are labeled accelerator kernels

The CUDA, AMD, Intel, Metal, NPU, and MAX launch gateways execute nested CPU
loops over host tensors. They do not dispatch vendor kernels. These paths must
fail closed until genuine device allocation, transfer, launch, synchronization,
and physical parity evidence exist.

### AES-CONS-004 — Interactive REPL fabricates model output

`RuneREPL.process_input_line()` returns `"Aesir response to: " + prompt` and
records it as an assistant response. No model executes. The REPL state machine
and slash commands are local primitives; conversational inference is simulated.

### AES-CONS-005 — Model-management commands fabricate metadata and persistence

`RuneModelStore.create_model()` labels an FNV-1a-style 64-bit fingerprint as
SHA-256 and assigns fixed model size, quantization, hidden dimension, layer
count, and modification time. CLI `create`, `cp`, and `rm` report success against
a process-local store without durable storage. The user-facing commands must
remain unsupported until real file parsing and atomic persistence exist.

### AES-CONS-006 — ONNX and EXL2 parsing accepts synthetic metadata

The ONNX byte parser accepts any four-byte span and assigns fixed IR/opset and
producer values. The EXL2 parser assigns a fixed bitrate without validating the
input bytes. Local operator/sub-block descriptors are usable primitives; model
format parsing is not implemented.

### AES-CONS-007 — Swarm operations fabricate network activity

Mesh join mutates an in-memory registry, remote dispatch returns constructed
text without transport or inference, and task dispatch returns a success-shaped
string. Default credentials and peer resource values are hardcoded. No separate
process, authenticated channel, heartbeat transport, or remote model execution
is present.

### AES-CONS-008 — Experimental transforms are described as inference systems

CIA, WIC, NSFI, MQARI, SKÁLDBRØÐIR, thinking, tool-use, smart-crash, MAX, and TUI
tests prove local deterministic helpers or presentation frames. They do not
prove semantic neural-state caching, accuracy-preserving inference replacement,
AI crash diagnosis, process recovery, hardware acceleration, live telemetry,
or end-to-end integration with the verified GGUF generation path.

### AES-CONS-009 — RAG uses fabricated fallback embeddings and a fixed byte cap

When `token_embd.weight` is absent, query embedding generation creates a
prompt-hash projection and presents it as an embedding. Context inclusion is
bounded by a hardcoded 1024-byte limit rather than the loaded model's token
context. The fallback must fail closed, and context budgeting must use the
model/tokenizer boundary.

## Repository and Workflow Findings

### AES-CONS-010 — Contributor workflow references nonexistent repository state

Active instructions require `TASK_QUEUE.md`, a root `DOMAIN_MAP.md`, and a
`development` branch. The canonical backlog is `TODO.md`, the domain map is
`docs/DOMAIN_MAP.md`, and the remote exposes `main` only.

### AES-CONS-011 — Capability and proving counts are stale

The ledger states 107 passing and 108 total master cases. The current runner
registers 132 `run_case()` calls and one explicit skip. The DEVLOG has no entry
for the 25 cases added by the latest commit.

### AES-CONS-012 — CI state is contradictory and incomplete

CI is tracked and runs the master suite plus the old drift checker, while the
ledger and TODO disagree about whether CI exists. The workflow omits a clean
build, fail-closed negative control, ledger validation, artifact scan, absolute
path scan, and external-fixture boundary.

### AES-CONS-013 — The drift checker validates too little

The checker scans eleven hand-selected documents and four phrases. It does not
validate ledger counts/statuses, test registrations, required paths, workflow
commands, tracked artifacts, root asset duplication, absolute local paths, or
fabricated-success source patterns.

### AES-CONS-014 — Tracked generated and duplicate artifacts remain

Seven compiled ELF binaries, one 24-byte placeholder GGUF file, and 24
byte-identical root image assets are tracked despite ignore rules and completed
cleanup claims. Removal is subject to Volmarr's explicit deletion approval.

### AES-CONS-015 — Active documents contain machine-specific absolute paths

The root DEVLOG and August status report contain prior local workspace paths.
Historical material also contains `file://` links to one machine. These paths
violate location agnosticism and are not portable references.

### AES-CONS-016 — Source violates the double-quote rule

`server/openai.mojo` uses single-quoted string literals. Other apostrophes occur
inside double-quoted strings, comments, and documentation and are not string
delimiter violations.

### AES-CONS-017 — Help and interface text advertises unsupported commands

The newer help module describes interactive inference, a live REST server,
persistent model storage, configuration commands, hardware acceleration,
experimental paradigms, and live TUI telemetry as available. The primary CLI
dispatcher rejects or does not connect those surfaces.

## Remediation Decisions

1. Preserve useful data structures and local primitives.
2. Convert simulated external operations to explicit unsupported errors.
3. Remove fabricated metadata and rename non-cryptographic fingerprints.
4. Make tests assert fail-closed behavior and exact local evidence boundaries.
5. Reconcile the capability ledger and TODO without promoting unproved work.
6. Expand repository consistency validation and run it in CI.
7. Use `main` as the documented integration branch until a real `development`
   branch is deliberately created by the maintainer.
8. Remove generated/duplicate tracked files only after explicit deletion
   approval.

## Remediation Status — August 29, 2026

Findings AES-CONS-001 through AES-CONS-013 and AES-CONS-015 through
AES-CONS-017 were repaired and covered by source, test, documentation, or
consistency-check evidence. AES-CONS-014 remains intentionally open because the
required deletion approval has not been granted; the ledger therefore records
repository artifact hygiene as `partial`, and the checker emits a warning rather
than a false pass claim for that sub-capability.
