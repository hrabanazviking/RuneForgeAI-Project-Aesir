# Task: Canonical Evidence-Backed Capability Ledger

**Status:** Completed and verified on August 14, 2026.
**Forge:** 0C
**Parent audit:** `PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md`
**Owning domains:** project documentation, tests, and every runtime domain that
makes a capability claim

## Context

Forge 0A made assertion failures terminate the master suite. Forge 0B added a
counted test ledger with 49 executable cases and one explicit external-fixture
skip. Those changes made the proving machinery trustworthy, but the repository
still has no canonical map from advertised capabilities to what the code and
tests actually establish.

The README, TODO, system-vision documents, interface specifications, runtime
banners, and historical devlogs currently mix five materially different states:
working behavior, narrow or unfinished behavior, interfaces without integration,
predetermined simulations, and absent advertised behavior. In particular,
`TODO.md` marks hardware acceleration, broad quantization, ecosystem parity,
Hugging Face downloading, self-healing, and swarm execution complete even though
the reality audit found host-only dispatch, synthetic tests, fixed output, or no
external operation.

Forge 0C creates the missing source of truth. It does not erase the project
vision and it does not rewrite all historical claims. It records present reality
at a capability boundary precise enough that future documentation and code work
can cite one stable entry instead of inferring maturity from names or banners.

## System Statement

Project A.E.S.I.R. needs one canonical `CAPABILITY_LEDGER.md` that maps every
significant current or advertised subsystem capability to exactly one primary
status, concrete implementation evidence, executable verification where any
exists, the boundary of that evidence, and an acceptance gate for the next
honest status.

The ledger is a truth-control document, not a marketing summary. A type, enum,
route name, dispatcher branch, test title, printed success message, or synthetic
happy path is not evidence that an external capability works.

## Canonical Status Vocabulary

Every capability row must use exactly one of these lowercase statuses:

| Status | Required meaning |
|---|---|
| `verified` | The narrowly worded row claim has executable evidence that performs the claimed work. Claims involving an external format, model, protocol, runtime, or hardware also require a real external fixture, independent oracle, or physical backend as appropriate. |
| `partial` | Meaningful real logic exists and is exercised, but integration, correctness breadth, portability, persistence, error handling, or representative coverage needed by the broader claim remains incomplete. |
| `scaffold` | Types, interfaces, local data structures, routing shapes, or control flow exist, but the advertised subsystem operation is not implemented end to end. |
| `simulated` | The implementation returns, prints, seeds, or mutates predetermined local values while presenting the shape of an operation that did not actually occur. |
| `missing` | The advertised or required behavior has no meaningful implementation in the current repository. |

### Status laws

1. Status applies to the exact, narrow capability named in the row, not to the
   aspirational subsystem name.
2. `verified` may be narrow. Its evidence boundary must say what model, prompt,
   platform, dimensions, protocol, or fixture was actually exercised.
3. Synthetic invariants can verify a narrow local primitive, but cannot verify
   external compatibility, hardware execution, networking, persistence, or
   performance.
4. A dispatcher that selects CPU functions by a GPU or NPU enum is a scaffold or
   simulation, not verified accelerator execution.
5. Predetermined output is `simulated` even if a test verifies the exact string.
6. An unconditional `True`, fixed catalog, seeded peer, fixed benchmark number,
   or printed download message cannot establish the named external operation.
7. `missing` is used for the real advertised capability when only a separate
   interface-shaped scaffold exists. The ledger may include both rows when that
   distinction prevents ambiguity.
8. No row may use `complete`, `production-ready`, `parity`, or `compatible` as a
   substitute status.

## Ledger Schema

Each capability row must contain:

- a stable capability ID;
- a narrowly worded capability;
- exactly one canonical status;
- the owning project domain;
- claim sources where the capability is advertised or specified;
- implementation evidence, including exact repository paths and symbols;
- executable evidence, using exact test names or commands where evidence exists;
- an evidence boundary explaining what the cited proof does *not* establish;
- the next acceptance gate needed to advance the status; and
- related `AER-*` findings from the reality audit.

Umbrella rows may point to more detailed rows, but no major README, TODO,
architecture, vision, or public-interface claim may disappear behind an
untraceable summary.

## Required Capability Domains

The ledger must cover at least these claim families:

1. build and runtime foundation;
2. counted test infrastructure and external-fixture handling;
3. memory pool, tensor, KV-cache, and ownership safety;
4. CPU compute primitives and attention;
5. GGUF metadata, tensor loading, and supported types;
6. tokenizer encoding and decoding;
7. CPU forward pass and deterministic generation;
8. sampling, stop policy, chat templates, batching, and cancellation;
9. CLI parsing, REPL, model catalog, Modelfile, and Ollama command surface;
10. socket server, HTTP parsing, streaming, OpenAI, llama.cpp, and Ollama APIs;
11. embeddings and RAG;
12. quantized formats and real quantized-model inference;
13. GPU, NPU, multi-device placement, and collectives;
14. Hugging Face resolution and downloading;
15. ONNX, ExLlama, grammar, and speculative decoding;
16. resilience, checkpointing, event bus, threading, and recovery;
17. swarm discovery, transport, scheduling, and remote execution;
18. benchmarks, portability, packaging, CI, security, and production readiness.

## Implementation Phases

### Phase 1 — Claim inventory and status normalization

1. Reconcile the reality audit matrix and all `AER-*` findings with current
   source and tests.
2. Inventory significant claims in the root README/TODO/architecture/data-flow
   documents, `docs/` vision/architecture records, and domain interfaces.
3. Split ambiguous umbrella claims when one part is real and another part is
   scaffolded, simulated, or missing.
4. Apply one canonical status to each narrow row using the status laws above.

### Phase 2 — Evidence and acceptance gates

1. Cite concrete symbols and files for every non-`missing` row.
2. Link every `verified` row to executable evidence; state the exact boundary of
   narrow proofs.
3. Cite the fixed or fabricated behavior behind every `simulated` row.
4. Give every row a specific advancement gate that can become a future task.
5. Cross-reference applicable reality-audit findings.

### Phase 3 — Canonical navigation

1. Add a prominent README link to the ledger without attempting the full README
   truth rewrite reserved for Forge 0E.
2. Point the reality audit, TODO, and devlog to the canonical ledger.
3. Record the status distribution and verification evidence.

### Phase 4 — Validation

1. Prove that every row ID is unique.
2. Prove that every primary status belongs to the five-value vocabulary.
3. Recalculate and verify the status summary from the rows.
4. Check that cited repository files and named tests exist.
5. Run Markdown/diff hygiene checks.
6. Re-run the counted master suite, the real external GGUF integration, and a
   clean Mojo build so documentation work cannot conceal regression.

## Expected Files

- `TASK_capability_ledger.md`
- `CAPABILITY_LEDGER.md`
- `README.md`
- `PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md`
- `TODO.md`
- `DEVLOG.md`

If another file is required, its inclusion must be reported before expanding
the implementation boundary.

## Constraints

- No runtime source behavior changes in Forge 0C.
- No public function, file, or historical record is deleted.
- No claim is upgraded based only on a symbol name, branch, banner, or synthetic
  assertion.
- No external fixture, model weight, generated binary, secret, or machine-local
  absolute path is committed.
- Historical task records remain historical; the ledger describes current
  repository reality.
- Full runtime-banner correction is Forge 0D.
- Full reconciliation of README, TODO, vision, architecture, interfaces, and
  duplicated documentation is Forge 0E.
- The broad vision may remain aspirational, but current capability labels must
  remain exact.

## Acceptance Criteria

- `CAPABILITY_LEDGER.md` exists and identifies itself as the canonical current
  capability source of truth.
- Every significant claim family named in this task is represented.
- Every capability has a unique stable ID and exactly one allowed status.
- Every `verified` capability has exact executable evidence and an explicit
  evidence boundary.
- Every `simulated` capability identifies the concrete predetermined behavior.
- Every `missing` capability has a concrete implementation and verification
  gate.
- Every row has an owner, implementation evidence, acceptance gate, and audit
  cross-reference or an explicit `none`.
- Summary counts exactly equal the number of ledger rows.
- README, TODO, the reality audit, and DEVLOG point to the ledger.
- The counted master suite reports 49 passed, 0 failed, 1 skipped, 50 total.
- The real external GGUF integration passes with the pinned fixture.
- A clean Mojo build succeeds.
- `git diff --check` succeeds.
- No model weight, built binary, secret, absolute local path, or unrelated file
  is added to the final diff.

## Explicit Non-Goals

- rewriting all misleading runtime banners or fixed command output;
- implementing any missing runtime capability;
- declaring broad production readiness;
- resolving all duplicate or historical documentation drift;
- changing README marketing prose beyond canonical navigation;
- deleting simulated APIs;
- broadening quantized, accelerator, server, ecosystem, RAG, or swarm claims;
- publishing performance numbers.

## Successor Forge

Forge 0D consumes this ledger to remove fabricated operational success language,
fixed benchmark/download/hardware claims, and false runtime validation banners.
It must preserve public surfaces unless a separately approved task authorizes a
breaking removal.

## Completion Record

Forge 0C produced `CAPABILITY_LEDGER.md` with 99 unique stable entries across all
18 required claim families. Mechanical validation found exactly 28 `verified`,
15 `partial`, 14 `scaffold`, 20 `simulated`, and 22 `missing` entries; zero
duplicate IDs; zero invalid status values; and exact agreement with the summary.
All 45 explicitly cited master-case names exist in `tests/run_all.mojo`.

The README now points prominently to the ledger. At Volmarr's explicit request,
the TODO reconciliation originally reserved for Forge 0E was pulled into this
forge: false broad completion markers were replaced with ten narrowly verified
milestones and 188 open, ledger-linked buildout items. Full reconciliation of
vision, architecture, interface, and duplicated historical documents remains
Forge 0E.

Verification completed from `aesir_engine/`:

- `pixi run mojo run tests/run_all.mojo` — 49 passed, 0 failed, 1 skipped,
  total 50, status PASS, exit 0;
- `pixi run mojo run tests/test_real_gguf.mojo <external-model>` — pinned
  SHA-256 matched; exact metadata, F16 aliasing, F32 conversion, prompt IDs,
  first token, 32-token IDs/text, length stop, context boundary, and pool
  restoration passed;
- `pixi run mojo build main.mojo -o <temporary-output>` — clean Linux x86-64
  build passed;
- the temporary built CLI produced the exact pinned 32-token completion; and
- ledger validation, cited-case validation, `git diff --check`, and artifact
  boundary checks passed.

No runtime source, model weight, generated binary, secret, or machine-local path
was added to the repository by this forge.
