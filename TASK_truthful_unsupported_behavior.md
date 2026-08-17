# Task: Truthful Unsupported Behavior

**Status:** Completed and verified on August 14, 2026.
**Forge:** 0D
**Parent ledger:** `CAPABILITY_LEDGER.md`
**Parent audit:** `PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md`
**Owning domains:** facade, CLI, server, core hardware, loaders, resilience,
swarm, tests, and documentation

## Context

Forge 0C established 99 canonical capability entries. Twenty are `simulated`:
their source prints, returns, seeds, or mutates predetermined values in the shape
of an operation that did not occur. Most of those simulations are currently
presented as operational success:

- thought-token logits are announced as masked without any masking;
- model catalogs, active processes, CUDA utilization, sampler configuration,
  transfers, hashes, and lifecycle changes are printed from fixed values;
- server routes return HTTP 200 with fixed OpenAI, llama.cpp, and swarm payloads;
- every NPU/GPU backend is reported as discovered and hardware dispatch silently
  executes CPU functions;
- Hugging Face download reports success without network or file I/O;
- ONNX, ExLlama, llama.cpp, benchmark, and perplexity commands print fixed
  results;
- swarm constructors seed fictional peers and join/dispatch/status report work
  without transport; and
- self-healing language describes recovery of state that was never lost.

Forge 0D removes false operational evidence. It does not implement these large
subsystems and it does not delete their public surfaces.

## System Statement

Every public development surface must distinguish three outcomes:

1. real implemented work succeeds and returns its real result;
2. unavailable work fails explicitly or returns a protocol-appropriate
   unsupported response; and
3. a deliberately retained local simulation calls itself a simulation and
   cannot be mistaken for operational recovery, networking, hardware, or
   performance.

No unsupported branch may emit a successful download, benchmark, hardware,
protocol, process, recovery, or distributed-execution claim.

## Ownership and Failure Policy

| Domain | Required behavior |
|---|---|
| Facade configuration | Reject `enable_npu`, `enable_gpu_realm`, and multi-device engine construction before model setup; preserve default single-device CPU generation. |
| CLI dispatcher | Preserve help, version, and real local single-shot GGUF `run`; raise a stable error for unimplemented daemon, REPL, store, distribution, ecosystem, and swarm commands. |
| Model store | Start empty, return not-found instead of fictional manifests, and report no active processes until persistence/runtime tracking exists. |
| Server routes | Return HTTP `501 Not Implemented` for known unsupported compatibility routes and `404 Not Found` for unknown routes; never return fixed HTTP 200 success bodies. |
| Hardware topology | Use honest logical host partition names and report no detected NPU/GPU backends without a real probe. |
| Hardware gateways | Raise unsupported rather than running a CPU function under an NPU/GPU execution label. Host CPU helpers remain available under their existing public names for compatibility but must not be cited as hardware proof. |
| Hugging Face | Keep verified tag/URL string helpers; downloading raises unsupported and performs no registration. |
| ONNX | Keep public loader shape; parsing/mapping return unavailable and leave no invented IR/node metadata. CLI raises unsupported. |
| llama.cpp / ExLlama | Public dispatchers raise unsupported; no fixed completion, health, benchmark, perplexity, bitrate, or cache output. |
| Swarm | Start with an empty registry and inactive cluster. Local descriptor/selection tests supply their own nodes. Join, heartbeat, task dispatch, CLI, and REST cannot report network success. |
| Resilience | Retained crash/recovery marker must say `SIMULATION ONLY`; tests assert marker-state behavior, not real recovery. Facade startup cannot say recovery/event/thread/swarm systems are active. |
| Tests | Prove each unsupported surface rejects or returns 501, rename synthetic cases/banners honestly, and retain counted fail-closed reporting. |

## Stable Error and Response Requirements

- CLI/runtime errors must contain the capability name and `not implemented` or
  `unsupported`.
- An unsupported command must propagate to `main()` and exit nonzero.
- Known server compatibility paths must return a body containing
  `"error":"unsupported"` with HTTP status 501.
- Unknown server paths must return 404 and must not echo unescaped input.
- No negative path may print `success`, `healthy`, `validated`, `active`,
  `online`, measured rates, model sizes, fixed hashes, or transfer percentages as
  an event that occurred.
- Enumerations and formatter-only helpers may remain testable, but their output
  and case names must state their narrow role.

## Implementation Phases

### Phase 1 — Facade and hardware truth gates

1. Add a pure configuration validator used at the start of `AesirEngine`
   construction.
2. Reject unimplemented NPU, GPU, and multi-device engine paths before loading a
   model or printing active banners.
3. Remove the unimplemented Masking Seidr success announcement.
4. Replace synthesized CUDA device names with logical host partition names.
5. Make detector lists empty until a real probe is implemented.
6. Make NPU/GPU execution gateways raise explicit unsupported errors.
7. Add focused tests for configuration, discovery, and gateway rejection.

### Phase 2 — CLI, store, and ecosystem truth gates

1. Make `RuneModelStore()` empty and make missing lookup raise.
2. Return an empty active-process list.
3. Rewrite CLI help to label the one implemented run mode and unsupported
   development surfaces.
4. Preserve real local single-shot generation.
5. Reject REPL, serve, model-store lifecycle, distribution, multi-engine, and
   swarm commands.
6. Make Hugging Face download raise unsupported.
7. Make ONNX parsing/mapping return unavailable without fixed metadata.
8. Make llama.cpp, ExLlama, and ONNX CLI dispatchers raise unsupported.
9. Add negative tests that inspect error text.

### Phase 3 — Server, swarm, and resilience truth gates

1. Add a pure server response formatter for 501/404 negative responses.
2. Route every unimplemented OpenAI, llama.cpp, Ollama/embedding, and swarm path
   to 501 rather than fixed 200 success.
3. Start peer registries empty and clusters inactive.
4. Preserve caller-supplied local peer selection as a narrow primitive.
5. Reject join, heartbeat, and distributed dispatch.
6. Label the retained supervisor state-toggle test `SIMULATION ONLY` and remove
   facade “ACTIVE” language.
7. Add server/swarm/resilience negative tests.

### Phase 4 — Re-ground tests and documentation

1. Rename master case IDs and domain headings so they describe scaffold or
   unsupported behavior rather than external capability.
2. Update the counted total for any newly registered cases.
3. Update every affected interface/readme contract.
4. Advance the 18 fabricated operational capability entries from `simulated` to
   `missing` after their false-success paths are removed. Retain the constant RAG
   query and explicitly labeled supervisor exercise as `simulated`.
5. Recalculate ledger counts mechanically.
6. Check Forge 0D TODO items only after their negative evidence passes.
7. Record the Forge in the audit and devlog.

## Expected Files

- `TASK_truthful_unsupported_behavior.md`
- `aesir_engine/aesir.mojo`
- `aesir_engine/cli/commands.mojo`
- `aesir_engine/cli/manifest.mojo`
- `aesir_engine/cli/repl.mojo`
- `aesir_engine/cli/multi_engine.mojo`
- `aesir_engine/core/compute.mojo`
- `aesir_engine/core/mimir_well.mojo`
- `aesir_engine/core/swarm.mojo`
- `aesir_engine/core/supervisor.mojo`
- `aesir_engine/loader/huggingface.mojo`
- `aesir_engine/loader/onnx.mojo`
- `aesir_engine/server/api.mojo`
- affected modules under `aesir_engine/tests/`
- affected root and domain `INTERFACE.md`/README files
- `CAPABILITY_LEDGER.md`
- `TODO.md`
- `DEVLOG.md`
- `PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md`

If another file is required, its inclusion must be reported before expanding
the implementation boundary.

## Constraints

- Preserve every public function, struct, and file.
- Preserve default single-device CPU F16/F32 inference and exact 32-token oracle
  behavior.
- Preserve help/version and real local single-shot CLI execution.
- Do not implement networking, persistence, quantization, accelerator kernels,
  recovery, or distributed execution inside this truth-cleanup forge.
- Do not silently fall back to CPU under an accelerator label.
- Do not replace fake success with a different fake observation.
- Do not commit model weights, generated binaries, secrets, or local absolute
  paths.
- Mojo remains the runtime and test language.
- Every affected assertion must fail closed.

## Acceptance Criteria

- Default CPU `AesirEngine` construction and generation remain verified.
- NPU, GPU, and multi-device engine configurations raise before model loading.
- NPU/GPU detector lists are empty absent real probes.
- NPU/GPU public execution gateways raise instead of writing CPU results.
- Masking Seidr no longer claims logits changed.
- `RuneModelStore()` contains no fictional model and reports no active process.
- Missing model lookup raises instead of returning a fictional manifest.
- Unimplemented CLI commands exit nonzero with stable unsupported text.
- No fixed transfer, hash, catalog, CUDA, model, benchmark, perplexity, health,
  ONNX, ExLlama, or swarm result remains in operational command paths.
- Hugging Face download raises and performs no registration.
- ONNX parse/map report unavailable without fixed IR/node results.
- Known unsupported HTTP routes produce 501; unknown routes produce 404.
- Swarm registry/cluster start empty/inactive; join/heartbeat/dispatch do not
  report success.
- Supervisor output explicitly says simulation and tests do not call it real
  recovery.
- New/updated negative tests are individually counted and fail closed.
- Ledger has unique IDs, allowed statuses, and exact updated counts.
- Forge 0D TODO items reflect only passed work.
- Counted master suite, pinned external GGUF integration, clean build, real CLI
  oracle, and representative negative built-CLI commands all pass.
- `git diff --check` and artifact/secret/local-path scans pass.

## Explicit Non-Goals

- real HTTP request parsing or serving loop;
- real model catalog persistence;
- real Hugging Face or registry transport;
- real GPU, NPU, or multi-device compute;
- real ONNX, ExLlama, or llama.cpp compatibility;
- real benchmark measurement;
- real checkpoint restoration or worker/event infrastructure;
- real swarm transport/discovery/execution;
- full README/vision/architecture reconciliation reserved for Forge 0E;
- deleting obsolete public surfaces.

## Successor Forge

Forge 0E reconciles all present-tense README, architecture, vision, data-flow,
interface, and duplicated documentation with the canonical ledger after runtime
output no longer fabricates evidence.

## Completion Record

All four phases and every acceptance criterion passed. The counted suite reports
51 pass, 0 fail, 1 explicit skip, and 52 total. The pinned external GGUF oracle,
clean Mojo build, exact built-CLI 32-token completion, and representative
nonzero built-CLI rejection cases passed. The capability ledger contains 99
unique allowed-status entries with counts 28 verified, 15 partial, 14 scaffold,
2 simulated, and 40 missing. Forge 0D's 16 TODO items are checked; the overall
backlog is 26 checked and 172 open. Diff hygiene and repository safety scans
passed, and no model weight, generated executable, secret, or machine-local path
was added to the repository.
