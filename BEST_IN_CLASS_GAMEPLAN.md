# Project Aesir: best-in-class local AI application program

Established 2026-09-12. Status: **active implementation**.

This is the active execution order requested by Volmarr: publish the plan,
implement slices sequentially, verify each slice, and push each completed slice
to `main`. The capability ledger remains authoritative for shipped capabilities.
Existing engineering boundaries, original Mojo implementation, runtime ownership,
and offline operation remain the foundation. Older roadmaps remain historical
and thematic references; this document sets the order for this program.

## Product promise

A person should be able to install Aesir, prepare models while connected, go
offline, launch a conversation, recover from interruptions, and connect their
favorite local tools without needing to understand GPU internals. Expert users
should retain precise control over models, memory, sampling, APIs, and evidence.

“Best in class” is an ambition to test, not a release label we have earned.
Success requires independent comparison on the same hardware, model bytes,
quantization, prompt, context, sampling, warm/cold state, and power conditions.
No speed, quality, compatibility, portability, or security claim comes from a
synthetic test alone. Competing products may inform requirements through public
documentation; their source must not be mechanically translated into Aesir.

## Starting point and known limits

Baseline source: `dba9da2`. Linux x86-64/WSL and NVIDIA CUDA are the exercised
application platform. Gemma, Llama/Stheno, and dense Qwen have narrowly documented
profiles; CPU inference has a separate pinned F16 fixture. We have model storage,
aliases/favorites, exact-token conversation snapshots, same-PID model switching,
diagnostics, sampling, cancellation, and partial Ollama/OpenAI text APIs.

The counted baseline is 182 pass, 0 fail, 1 external-fixture skip (183 total).
Recent admission fixes cover FIFOs, path truncation, and inherited descriptors.
This does not establish full crash recovery, arbitrary-model execution, genuine
incremental API streaming, cross-platform installers, or optimized prefill.
The last audit could not rerun Stheno from its local zero-byte path, and the local
GitHub CLI's Actions API credentials returned 401 even though Git pushes worked.
Recheck those observations before relying on them; never copy credentials into
logs or source control. Legacy tracked assets await an explicit deletion scope.

## Release gates and measurements

| Area | Release acceptance target |
|---|---|
| Offline reliability | Cold launch, model discovery, 20-turn chat, save/load, restart and local API use with outbound networking denied. |
| Onboarding | A clean supported machine reaches a first local response using documented steps; five independent usability trials, at least four complete without developer intervention. |
| Recovery | Cancellation, invalid input, full disk, process death, truncated data and unavailable GPU yield actionable results and preserve the last committed user data. |
| API correctness | Versioned supported-field matrix; exact wire fixtures, independent clients, streaming framing, disconnect/backpressure, and unsupported-field refusal. |
| Memory | Budget before allocation; bounded host staging; repeated sessions and 100 model transitions show no unexplained resource growth. |
| Performance | Publish raw warm/cold load, first-token latency, prefill/decode throughput, p50/p95 latency, peak RAM/VRAM, idle CPU and optional energy measurements. |
| Optimization | No material quality regression against the pinned oracle; improve a measured bottleneck and stay within a 5% regression budget elsewhere, with noise and exceptions documented. |
| Accessibility | Keyboard-only primary workflows, readable focus/status, narrow terminals, Unicode, no-color and reduced-motion behavior; screen-reader review for a future GUI. |
| Release integrity | Reproducible build instructions, checksummed distribution, pinned dependency provenance, migration/rollback instructions, clean-install and offline smoke gates. |

Numeric targets are proposed release gates, not measured results. Define benchmark
hardware and noise tolerance before tuning. Missing power sensors yield unknown
energy values, never fabricated watts. External download/model license acceptance,
new costs, public service exposure and unrelated data deletion require explicit
authority; ordinary implementation, tests and pushes are already authorized.

## Architectural ownership

| Boundary | Owner and rule |
|---|---|
| Model math and generation state | `aesir_engine/core/`: profiles, kernels, KV, sampling, budgets and cancellation; no terminal or HTTP formatting. |
| Model bytes and metadata | `aesir_engine/loader/`: validate and expose bounded data; no UI policy or GPU scheduling. |
| Durable user data | Existing CLI storage/conversation modules initially; evolve reusable persistence only when two real consumers need it. |
| Diagnostic observations | `core/native_diagnostics.mojo`: measured facts; CLI owns interpretation and presentation. |
| Application commands | `aesir_engine/cli/`: validate intent, orchestrate established core operations, present actionable results. |
| API compatibility | `aesir_engine/server/`: request/response codecs, authentication, streaming and limits; delegate generation to the engine. |
| New local UI | An optional thin local client of the established application API; inference remains Mojo, assets work offline, no mandatory cloud account. |
| Verification and releases | Tests, `scripts/`, CI, fixture manifest and capability ledger; measurement code never becomes a hidden Python inference runtime. |

Prefer extending an existing owner. Introduce interfaces for actual consumers.
Do not create generic scheduler, plugin, or backend abstractions merely to mark a
roadmap row complete. Behavior-changing migrations need explicit fixtures.

## Execution protocol

1. Read this plan, current ledger and affected interfaces; inspect working tree,
   current branch, remote and latest checkpoint. Preserve unrelated user work.
2. Select the earliest uncompleted slice whose dependencies can be met. Write
   its concrete implementation decision and exact acceptance command in the
   execution record before substantial work. Split an oversized slice into
   numbered sub-slices and push each, preserving the parent acceptance gate.
3. Implement behavior, relevant failure handling and meaningful regressions.
   Fix newly discovered blockers in the active slice before continuing.
4. Run focused tests and the required build/integration checks. Run the counted
   suite for shared engine changes; run physical/oracle tests when those claims
   change. Reuse valid evidence for untouched paths, avoid repeated broad tests
   without a reason, and inspect every exit status.
5. Update interfaces/ledger/TODO/devlog when their claims changed, record
   acceptance evidence here, and commit the coherent slice. Push `HEAD:main`
   without force; confirm the remote revision. Never mark a failed push as done.
6. Continue to the next slice automatically. A thread heartbeat resumes the
   queue between interactive turns while the desktop host is available. It is
   not an always-on service, cannot work on a sleeping/offline host, and must
   not redeem usage resets without separate authorization.
7. If hardware, an external fixture, a user decision, or credentials block a
   slice, record the exact unmet gate. Continue only independent prepared work;
   do not weaken the blocked acceptance gate or call a scaffold implemented.
8. Stop automatic work once every slice is accepted, or when the user pauses or
   changes the program. Notify on shipped slices, meaningful failures or required
   decisions; remain quiet when external state is unchanged.

Status vocabulary: `queued`, `active`, `blocked`, `verified` (checks passed; push
pending), `done` (verified and pushed). The commit containing a completion record
is its evidence revision; no self-referential commit hash is required.

## Ordered implementation slices

Each row specifies a concrete deliverable, owning surface, dependency and gate.
Every row is initially queued unless the execution record says otherwise.

### Phase A — A trustworthy everyday application

| Slice | Deliverable and owner | Depends on | Acceptance gate |
|---|---|---|---|
| S01 | Correct `doctor` installed-weight readiness; validate store intent before expensive observations. CLI diagnostics. | Baseline | Recipe-only/empty stores never claim readiness; malformed store rejected before observation; valid installed baseline preserved. |
| S02 | `doctor --format json`: versioned report, null unknowns, explicit scope, actionable failure reasons and optional model result. CLI report/presentation. | S01 | Independent JSON parser accepts the sole stdout document; healthy/empty/corrupt/model-error cases agree with text; no outbound requests. |
| S03 | Consistent `--model-store` and `--config` selection for catalog commands; reject duplicate/conflicting flags. CLI. | S01 | Isolated stores across list/show/create/copy/remove/verify/GC; precedence documented; existing config behavior retained. |
| S04 | Report stale aliases/favorites and missing/recipe-only selection; explicit safe preference repair command. Preferences/doctor/selector. | S02,S03 | Removing a model makes its stale shortcuts visible; dry run changes nothing; explicit repair preserves live preferences. |
| S05 | One-command local launch with an interactive home menu and clear noninteractive behavior. Main/CLI/TUI. | S02,S04 | PTY first-run/no-model/installed-model tests; redirected input never hangs; cancellation returns to a usable state. |
| S06 | WSL/Windows launch helpers, Linux desktop/terminal entry and actionable missing-runtime diagnostics. Packaging/scripts. | S05 | Paths with spaces, cold starts, missing WSL/runtime/model; launched app uses a freshly built version and works offline. |
| S07 | Unified supported generation settings and precedence across recipe/config/CLI/session/API. Profiles/CLI/server. | S03 | Table-driven precedence and unsupported-setting rejection; same supported request yields equivalent effective settings. |
| S08 | Model inspection/explanation with verified family, quantization, context and exact memory-fit reasons. Registry/planner. | S07 | Boundary/overflow/unsupported tensor fixtures; real installed models match the selected native profile and memory observations. |

### Phase B — Data that survives real use

| Slice | Deliverable and owner | Depends on | Acceptance gate |
|---|---|---|---|
| S09 | Shared text admission contract: reject NUL/truncation, malformed UTF-8 and trailing hidden data before decode. Persistence/loaders. | S01 | Adversarial config/catalog/preference/snapshot records fail without changing committed state; Unicode round trips. |
| S10 | Crash-injection harness for staged write/fsync/rename/directory-sync boundaries. Storage/tests. | S09 | Kill writer at each boundary; restart exposes old or complete new record, never silent empty state or partial success. |
| S11 | Harden resumable downloads against inode/path replacement, partial identity mismatch and interruption. Downloader. | S09,S10 | Local controlled transfer fixture plus pinned small HTTPS artifact; preserved partials remain safe; publication matches verified inode. |
| S12 | Offline preparation manifest and explicit `prepare`/`check` workflow for runtime, model pins, capacity and dependencies. CLI/package. | S06,S08,S11 | Produce manifest online; cold verification and inference pass with outbound network denied; incomplete artifacts identified by name. |
| S13 | Named conversation library with explicit save/list/open/rename/export and bounded metadata. Conversation/CLI. | S10 | Restart, Unicode names, duplicate handling, corruption and incompatible model refusal; no implicit overwriting. |
| S14 | Optional crash-recovery autosave with atomic generations and user-controlled retention. Conversation. | S13 | Process kill after a completed turn restores the latest committed turn; interrupted generation is identified; retention only touches owned files. |
| S15 | Session recovery after generation errors and failed model switches, with precise reset requirements. Core/chat lifecycle. | S14 | Inject allocation/load/timeout failures; deterministic recovery or clear restart instruction; no leaked resources or false turn commits. |
| S16 | Catalog schema migration/backup/restore and concurrent mutation contract. Storage. | S10,S13 | Old fixtures migrate atomically; rollback and six concurrent writers preserve references; invalid backups rejected before mutation. |

### Phase C — APIs that other apps can trust

| Slice | Deliverable and owner | Depends on | Acceptance gate |
|---|---|---|---|
| S17 | Versioned API support matrix and contract fixture corpus for native/Ollama/OpenAI routes. Server/tests. | S07 | Independently authored requests/responses; explicit unsupported fields; no claim of complete external compatibility. |
| S18 | Genuine incremental token streaming in native generation callbacks and transport. Core/server. | S15,S17 | First response chunk observed before generation ends; correct Unicode boundaries, EOS, counts and final record. |
| S19 | OpenAI SSE and Ollama NDJSON adapters with cancellation/backpressure. Server. | S18 | Independent clients parse real chunks; disconnect stops work; slow receiver bounded; terminal frames and error framing exact. |
| S20 | Bounded request queue, busy status, deadlines and fair cancellation for one resident model. Server/core orchestration. | S19 | Concurrent clients complete/reject predictably; queue limit enforced; no KV leakage between users. |
| S21 | Accurate model-list/show/version/health/readiness endpoints. Server/catalog/report. | S02,S17 | Catalog changes reflected, health separate from model readiness, stable schema and error codes. |
| S22 | Explicit model lifecycle and residency ownership for load/unload/ps/stop. Application service. | S20,S21 | Stop targets an owned live session; in-use weights survive GC; stale process identity never kills an unrelated PID. |
| S23 | Structured output for a narrow JSON grammar, including schema rejection and early termination. Core grammar/server. | S18,S17 | Independent parser/schema validates generated outputs; malformed grammar and unsupported features rejected before generation. |
| S24 | Tool-call protocol for a proven model template, with no automatic tool execution. Template/server. | S17,S23 | Tool-call text and IDs round trip with an independent client; ordinary text and unsupported models distinguished. |

### Phase D — Model breadth and measured speed

| Slice | Deliverable and owner | Depends on | Acceptance gate |
|---|---|---|---|
| S25 | Reproducible benchmark runner and machine-readable baselines. Scripts/core metrics. | S08,S18 | Warm/cold load, TTFT, prefill/decode, RAM/VRAM, p50/p95; raw runs and model/runtime identities retained. |
| S26 | Independent tokenizer/template/logit/token oracle corpus for every currently claimed family. Tests/fixtures. | S25 | Pinned model revisions and oracle provenance; Unicode/control-token/context tests; missing fixtures remain explicit blocks. |
| S27 | Batched prefill for the most expensive measured supported path. Kernels/session. | S25,S26 | Per-layer/logit tolerance plus deterministic output; measured prompt throughput improvement; memory budget held. |
| S28 | Optimize measured decode bottleneck: quantized matvec/fusion/launch reduction. Kernels. | S27 | Independent parity across supported quantizations, representative lengths, raw before/after results; no speculative speed claim. |
| S29 | Context/KV allocation improvements with explicit ownership and optional prefix reuse. Core memory. | S20,S26 | Isolation across prompts/models/settings, eviction and pressure tests; identical output and bounded memory. |
| S30 | Add one high-value dense model family through a documented profile contract. Registry/loader/core. | S26 | Real pinned artifact, oracle tokenizer and logits, chat/control/API tests; named supported variants only. |
| S31 | Real embedding runtime for one pinned embedding model and `/v1/embeddings`. Core/server. | S17,S26 | Independent embedding tolerance, dimensions, batch limits, normalization and semantic retrieval fixture. |
| S32 | Retrieval with explicit citations and user-owned local documents. Retrieval/CLI/API. | S13,S31 | Ingest/update/delete/restart; bounded context, stable source links, no fabricated citation or automatic external access. |

### Phase E — A polished local experience

| Slice | Deliverable and owner | Depends on | Acceptance gate |
|---|---|---|---|
| S33 | TUI polish: model browser, transcript navigation, multiline editor, copy/export hints and command discovery. CLI/TUI. | S05,S13,S18 | PTY keyboard workflows at 80x24 and narrow/wide terminals; Unicode, redirected output and resize behavior. |
| S34 | Accessibility/no-color/plain-output controls and plain-language error guidance. Presentation. | S33 | Keyboard focus, contrast/no ANSI mode, reduced motion, readable errors; manual usability checks recorded. |
| S35 | Optional offline local GUI prototype for chat/model selection/settings/history. Local client. | S19,S21,S33 | All static assets local; API origin/auth restrictions; no remote fonts/telemetry; actual inference and history workflow. |
| S36 | GUI keyboard/accessibility/responsive polish and robust streaming/reconnection. Local client. | S35,S34 | Independent browser tests, accessible labels/focus, disconnect recovery; mobile-width and desktop visual review. |
| S37 | Opt-in diagnostics export with redaction and reproducible bug report bundle. CLI/UI. | S02,S25,S36 | Secrets/prompts excluded by default; preview manifest, bounded logs, build/model IDs; no automatic upload. |
| S38 | Guided usability trials and prioritised correction slice. Docs/UI. | S12,S34,S36 | Five real trials of install/import/chat/save/reopen/API; record completion time and failure points; fix top friction. |

### Phase F — Distribution, security and endurance

| Slice | Deliverable and owner | Depends on | Acceptance gate |
|---|---|---|---|
| S39 | Release build manifest, checksums and supported-platform package layout. Packaging/CI. | S12,S25 | Clean build on supported Linux; version reflects revision; source/model caches excluded; staged local artifacts inspectable. |
| S40 | Clean-install upgrade/rollback and data migration smoke suite. Packaging/storage. | S16,S39 | Fresh install and previous-version upgrade preserve data; offline restart; failed update leaves working previous version. |
| S41 | Transport/security review and adversarial protocol corpus. Server/persistence. | S19,S22,S37 | Auth timing/limits, request smuggling/framing, path/file races, resource exhaustion and accidental public binding reviewed and tested. |
| S42 | Long-running soak and failure/pressure campaign. Tests/runtime. | S29,S40,S41 | 100 model transitions, 1,000 bounded requests, cancellation/disconnect/low-disk/restart; resource trend and data integrity report. |
| S43 | Operator/developer/user docs aligned with exact release behavior. Documentation. | S38,S42 | Clean-room onboarding walkthrough, API examples executed, support matrix and limits consistent with ledger. |
| S44 | Candidate release comparison and acceptance review. Benchmarks/releases. | S43 | Same-workload independent comparison, unresolved issue register, signed-off release gates; no public release tag until its artifact/release scope is explicit. |

### Phase G — Earned hardware expansion

| Slice | Deliverable and owner | Depends on | Acceptance gate |
|---|---|---|---|
| S45 | CPU quantized inference for a deliberately bounded family and graceful explicit fallback. Core/backend policy. | S26,S44 | Real CPU oracle parity and pressure tests; CPU choice visible; no hidden fallback that mislabels acceleration. |
| S46 | One additional physical GPU backend chosen from available owned hardware. Backend. | S25,S26,S45 | Native vendor runtime execution, memory/transfer/kernel/full-model oracle; absent hardware blocks the claim. |
| S47 | Optional power-aware residency based on observed battery/thermal/power facts. Core policy. | S22,S25,S46 | Unknown-sensor behavior, explicit performance/balanced/expedition policies, measured energy/latency tradeoffs. |
| S48 | Trusted multi-device routing proof for two real owned nodes. Transport/scheduler. | S20,S41,S47 | Mutual identity, bounded workload contract, measured transfer, node-loss recovery and local operation when disconnected. |

## Risk register and deliberate boundaries

- CUDA process-image switching is an established workaround for a measured MAX
  sequential-context deadlock. Do not remove it without a physical lifecycle proof.
- A verified blob is not automatically a supported architecture or a fitting
  runtime plan. Diagnostics must state which level they establish.
- Download correctness must bind validation/publication to the same inode and
  validate resumes; a checksum of a re-resolved path does not establish that.
- Atomic rename alone is not a crash recovery proof. Exercise sync and failure
  boundaries, including preserving old records and resisting special files.
- API streaming must deliver incremental bytes while generation is running;
  one final event does not satisfy S18/S19.
- A local GUI cannot promise a native Windows inference backend; WSL remains
  explicit until a separate supported platform passes its gates.
- Comparative quality/performance work needs pinned inputs and permitted models.
  Existing unavailable fixtures do not authorize multi-gigabyte replacement
  downloads or model license acceptance without reviewing session scope.
- A broad roadmap cannot guarantee completion on the present host or budget.
  Automatic continuation records tangible progress and exact external blockers.

## Execution record

### Plan publication

- Status: done; published to `main` as `54cdeae`.
- Acceptance: 48 ordered slices, ownership, dependencies, gates, release criteria,
  risk register, and per-slice push/continuation contract established.
- Next: S01, then S02, then S03. Continue in listed order thereafter.
- Continuation: hourly thread heartbeat `aesir-sequential-application-build`
  is active; execution requires the desktop host and available usage/network.

### S01 — Doctor readiness

- Status: verified; included in this slice's push checkpoint.
- Decision: readiness here describes CUDA/storage prerequisites only; require
  installed weights rather than a recipe count and expose that scope clearly.
- Gate: focused policy tests plus a built CLI against isolated recipe-only and
  empty stores; no inference/GPU run is required to prove a negative readiness.
- Implementation: installed-count policy, early store validation, explicit
  prerequisite-only scope, expanded negative policy tests and isolated built-CLI
  harness `scripts/test_native_doctor.py`.
- Evidence: CUDA-targeted main build succeeded; counted suite 182 passed,
  0 failed, 1 external-fixture skip (183 total). `python3
  scripts/test_native_doctor.py --binary .aesir/aesir-s01` passed; doc-drift gate
  passed with existing legacy-artifact warnings only.

### S02 — Structured diagnostics

- Status: queued.
- Decision: collect one report, render text/JSON from the same observations;
  `schema_version: 1`, unknown observations as null, explicit prerequisites scope,
  errors retained in structured fields. Optional model inspection belongs inside
  that document. Diagnostic status remains separate from command execution errors.
- Gate: built CLI output parsed by Python `json.loads`; strict option errors,
  missing/corrupt model stores, optional model failure and text/JSON agreement.

### S03–S48

- Status: queued; use the corresponding table row as the initial slice contract.
- Append implementation decisions, commands, results and remaining gates as each
  slice becomes active. No unchecked row implies an implemented feature.
