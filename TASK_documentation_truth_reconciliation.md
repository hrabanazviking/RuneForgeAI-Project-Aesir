# Task: Documentation Truth Reconciliation

**Status:** Approved for implementation on August 14, 2026.
**Forge:** 0E
**Parent ledger:** `CAPABILITY_LEDGER.md`
**Parent audit:** `PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md`
**Owning roles:** Skald, Architect, Cartographer, Auditor, and Scribe
**Owning layers:** vision, domain, interface, execution documentation, and
verification

## Context

Forge 0D made runtime behavior truthful. The repository documentation still
contains a second and larger source of false operational evidence: active
README, architecture, data-flow, vision, overview, domain-map, interface,
decision, and historical-devlog documents describe aspirational slices as
completed physical systems.

The canonical capability ledger currently records 99 capabilities: 28
`verified`, 15 `partial`, 14 `scaffold`, 2 `simulated`, and 40 `missing`. Active
documentation nevertheless describes direct mmap-to-GPU weights, PagedAttention,
sampling, Tensor Core execution, Ollama/llama.cpp/OpenAI compatibility, ONNX and
ExLlama execution, persistent model management, downloads, NPU/GPU discovery,
multi-device inference, recovery, threading, swarm networking, benchmarks, and
production efficiency as present-tense facts.

Forge 0E reconciles those documents without erasing the project's mythic voice
or long-range vision.

## System Statement

Every Markdown document must declare which kind of truth it contains:

1. **current** documents describe only present implementation and cite the
   relevant ledger capability IDs;
2. **vision** documents describe desired future systems using future-tense,
   target, or acceptance-gate language and never imply completion;
3. **historical** documents preserve what was claimed or decided at a past
   moment and explicitly defer current status to the ledger; and
4. **redirect** documents contain no duplicate system specification and point
   to one canonical owner.

The capability ledger remains the sole present-tense maturity authority.

## Canonical Documentation Topology

| Document | Classification | Ownership |
|---|---|---|
| `README.md` | current | landing page, verified quick start, concise status matrix |
| `CAPABILITY_LEDGER.md` | current authority | capability maturity and acceptance gates |
| `TODO.md` | current | evidence-backed work queue |
| `ARCHITECTURE.md` | current | implemented component and dependency map |
| `DATA_FLOW.md` | current | verified CPU flow plus explicit unsupported branches |
| `docs/DOMAIN_MAP.md` | current | domain ownership, allowed dependencies, current boundary status |
| `docs/REPO_OVERVIEW.md` | current | repository navigation and document classifications |
| root/domain `INTERFACE.md` and domain `README.md` files | current | public contracts and domain boundaries |
| `docs/PHILOSOPHY.md` | vision | values and engineering principles, not maturity claims |
| `docs/SYSTEM_VISION.md` | vision | desired-state roadmap and acceptance gates |
| `docs/Vision.md` | redirect | compatibility pointer to `docs/SYSTEM_VISION.md` |
| `docs/ARCHITECTURE.md` | redirect | compatibility pointer to root `ARCHITECTURE.md` |
| `docs/DATA_FLOW.md` | redirect | compatibility pointer to root `DATA_FLOW.md` |
| `DEVLOG.md` | historical/current log | new truth entries plus explicitly historical older claims |
| `docs/DEVLOG.md`, `docs/DECISIONS/`, `docs/bugs/`, `aesir_engine/docs/bugs/`, dated specifications, task files, and guides | historical/reference | preserved records, not current capability evidence |

Each classified canonical document receives a machine-readable
`AESIR-DOC-CLASS` marker. `docs/DOCUMENTATION_MAP.md` records the complete
routing policy so duplicated documents cannot silently regain authority.

## Reconciliation Requirements

### Root landing and current architecture

1. Rewrite `README.md` around the verified Linux x86-64, single-device CPU,
   GGUF v3 Llama F16 deterministic inference slice.
2. Preserve the sovereignty, open-source, and Mythic Engineering identity as
   vision, not performance proof.
3. Replace mmap-to-GPU language with the verified CPU virtual-memory alias
   boundary.
4. Replace PagedAttention/ring-cache claims with the actual contiguous
   request-owned KV cache.
5. Replace stateless sampling claims with deterministic greedy argmax and list
   sampling as missing.
6. Remove present-tense NVIDIA, CUDA, Tensor Core, quantized inference,
   compatibility, production, privacy, power, and efficiency guarantees.
7. Provide reproducible build, test, and real-model commands without absolute
   machine paths or committed model weights.
8. Rewrite root `ARCHITECTURE.md` and `DATA_FLOW.md` as current-state maps with
   status/ledger citations at every broad boundary.

### Domain, overview, vision, and duplicate ownership

1. Rewrite `docs/DOMAIN_MAP.md` so ownership is separated from implementation
   maturity and unsupported surfaces remain in their real domains.
2. Rewrite `docs/REPO_OVERVIEW.md` using the tracked repository rather than
   stale paths, model fixtures, test totals, or server instructions.
3. Rewrite `docs/SYSTEM_VISION.md` as an explicitly future desired-state map;
   no phase is complete merely because a type or function name exists.
4. Re-ground `docs/PHILOSOPHY.md` as principles/targets and remove false current
   invariants.
5. Convert duplicated architecture, data-flow, and vision files into redirects
   so only one canonical copy carries current detail.
6. Add visible historical-status boundaries to both devlogs and the dated root
   specification without rewriting the historical record.
7. Reconcile all root/domain interfaces and domain READMEs with the same current
   terminology, evidence boundary, and document classification.

### Automated drift gate

Add `scripts/check_documentation_truth.sh` and `scripts/README_AI.md`. The gate
must:

1. require the expected classification marker in every canonical/redirect
   document;
2. reject known fabricated-completion phrases in current documents;
3. require a ledger ID on maturity-sensitive current-document lines;
4. verify redirect documents do not regrow into duplicate specifications;
5. verify all cited ledger IDs exist;
6. verify the ledger's five status counts and 99 unique IDs; and
7. exit nonzero with file/line diagnostics on any violation.

The gate is a repository documentation check, not runtime code, and is invoked
from the repository root with:

```bash
bash scripts/check_documentation_truth.sh
```

## Expected Files

- `TASK_documentation_truth_reconciliation.md`
- `README.md`
- `ARCHITECTURE.md`
- `DATA_FLOW.md`
- `docs/DOCUMENTATION_MAP.md`
- `docs/ARCHITECTURE.md`
- `docs/DATA_FLOW.md`
- `docs/DOMAIN_MAP.md`
- `docs/PHILOSOPHY.md`
- `docs/REPO_OVERVIEW.md`
- `docs/SYSTEM_VISION.md`
- `docs/Vision.md`
- `DEVLOG.md`
- `docs/DEVLOG.md`
- `Project_Aesir_Engine_Mojo_Inference_Core_Spec_1_Aug-1-2026.md`
- root/domain `INTERFACE.md` and domain `README.md` files
- `scripts/check_documentation_truth.sh`
- `scripts/README_AI.md`
- `CAPABILITY_LEDGER.md`
- `TODO.md`
- `PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md`

If another document is required to close a present-tense contradiction, it may
be included only when its classification and reason are recorded in the
completion report.

## Constraints

- Preserve the project's mythic identity, philosophy, images, attribution,
  licensing, legal notice, and contributor acknowledgements.
- Preserve historical records; label them instead of silently rewriting their
  past claims.
- Do not change Mojo runtime behavior in this documentation forge.
- Do not delete any public file, function, struct, document, or historical
  record.
- Do not claim general model, platform, protocol, hardware, safety, privacy,
  performance, or production support from the pinned CPU fixture.
- Do not commit model weights, generated binaries, secrets, or absolute
  machine-local paths.
- Keep status vocabulary identical to the capability ledger.
- Any newly discovered missing, incomplete, buggy, misleading, or
  refinement-needing function must be added to the reality audit and TODO.

## Acceptance Criteria

- Every current document describes the same verified CPU boundary and the same
  unsupported subsystem boundaries as the capability ledger.
- README contains no direct mmap-to-GPU, PagedAttention, stateless sampler,
  Tensor Core, NVIDIA optimization, quantized inference, drop-in compatibility,
  or unmeasured performance claim.
- Architecture and data-flow maps do not route requests through unsupported
  server, accelerator, swarm, download, or multi-engine operations.
- Vision language is explicitly future/desired-state and acceptance-gated.
- Duplicate architecture/data-flow/vision documents defer to one canonical
  owner.
- Historical documents visibly state that their claims are not current status.
- Documentation drift gate passes and a deliberate temporary prohibited phrase
  makes it fail nonzero before exact restoration.
- Ledger remains 99 unique entries with exact allowed-status counts.
- Forge 0E TODO items reflect only completed, validated work.
- Counted master suite remains 51/0/1/52.
- Pinned external GGUF, clean build, and real built-CLI oracle remain green.
- `git diff --check`, artifact, secret, and machine-local-path scans pass.

## Explicit Non-Goals

- implementing any missing runtime feature;
- changing ledger capability maturity except AES-OPS-006 if the drift gate and
  document reconciliation satisfy its narrow acceptance boundary;
- creating CI, release packages, benchmarks, network clients, or hardware
  probes;
- rewriting historical prose as though it had never been written;
- validating external compatibility, performance, privacy, or platform claims.

## Successor Forge

After truth restoration, begin Stage 1 with the highest-risk memory boundary:
replace `MimirWell.allocate()` address-1 exhaustion with a checked raising
contract, validate sizes/overflow/alignment, and prove failure occurs before any
invalid pointer can be returned or dereferenced.
