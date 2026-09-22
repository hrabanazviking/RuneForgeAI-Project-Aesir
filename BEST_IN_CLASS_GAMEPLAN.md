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
- Next: S06 launch helpers. Continue in listed order thereafter.
- Continuation: hourly thread heartbeat `aesir-sequential-application-build`
  is active; execution requires the desktop host and available usage/network.

### S01 — Doctor readiness

- Status: done; verified and pushed as `f21cecc`.
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

- Status: done; verified and pushed as `86acb71`.
- Decision: collect one report, render text/JSON from the same observations;
  `schema_version: 1`, unknown observations as null, explicit prerequisites scope,
  errors retained in structured fields. Optional model inspection belongs inside
  that document. Diagnostic status remains separate from command execution errors.
- Gate: built CLI output parsed by Python `json.loads`; strict option errors,
  missing/corrupt model stores, optional model failure and text/JSON agreement.
- Implementation decision: reuse the single observation pass for both renderers;
  embed registry inspection without redirecting or reparsing console output.
  Root `ready` is explicitly scoped to CUDA/storage prerequisites, with model
  inspection success reported separately (never an execution proof).
- Evidence: final native build and `scripts/test_native_doctor.py --binary
  .aesir/aesir-s02` passed, including inspect-result parity and Unicode metadata;
  existing native-model-store harness passed; counted suite 182 pass, 0 fail,
  1 external-fixture skip (183 total); doc-drift gate passed.
- Bug found and resolved: shared JSON escaping sliced multibyte UTF-8 into
  invalid one-byte Strings. Span-based escaping now passes mixed Unicode and
  ASCII-control regressions; the built diagnostic harness is part of CI.

### S03 — Explicit catalog store selection

- Status: done; verified and pushed as `2e13fd4`.
- Design: extend the existing catalog dispatcher, not storage internals. Accept
  exactly one of `--config`/`-c` or `--model-store`; reject duplicates and mixed
  selectors before opening config/store paths. Neither means `.aesir/models`.
  Reuse `validate_model_store_path`; retain config-only behavior. Explicit
  rejection avoids silently targeting the wrong store during `rm` or `gc`.
- Files: `aesir_engine/cli/commands.mojo` owns parsing and help;
  `scripts/test_native_model_store.py` owns built-process store isolation tests;
  CLI interface/ledger/devlog record the contract.
- [x] Extend catalog harness to run all operations with both selectors and
  reject invalid/mixed/duplicate options without mutating the isolated catalog.
- [x] Run against `.aesir/aesir-s02`; observed the direct-selector case fail
  with `unknown catalog option: --model-store`.
- [x] Implement strict selector parsing and shared path validation.
- [x] Build `.aesir/aesir-s03`; run catalog and doctor harnesses, counted suite,
  and `scripts/check_doc_drift.py`; document real results.
- [x] Push this verified slice and confirm remote `main` before starting S04.
- Verification: native main build succeeded; both selector modes passed the
  existing restart/concurrency/import/verify/GC harness plus new selector cases;
  built doctor harness passed; counted suite 182 passed, 0 failed, 1 existing
  external-fixture skip (183 total). Doc-drift and diff-whitespace gates passed
  with existing legacy-artifact warnings.
- Review-driven additions: seeded separate direct/config/default stores with
  matching model names, checked every unselected store's catalog/blob bytes
  after copy/remove/GC, and asserted selector-specific diagnostics with missing
  and malformed configs. Extended built harness passed; independent re-review
  confirmed both test gaps closed with no new findings (static review only).

### S04 — Preference health and safe repair

- Status: done; verified and pushed as `92a00ac`.
- Design: `repair-preferences` defaults to a read-only dry run; only `--apply`
  removes aliases/favorites whose target no longer exists in the catalog.
  Recipe-only targets are reported but preserved. Missing/corrupt blobs do not
  authorize deleting shortcuts. Doctor text/JSON reports findings separately
  from CUDA/storage readiness. Interactive selection excludes recipe entries.
- Transaction: load catalog and preferences after acquiring the existing root
  lock, pin catalog reading to that descriptor, and publish only changed
  preferences. Dry run and failures leave all durable files untouched.
- Test-first gate: built-process harness on S03 must fail for missing command;
  S04 build must pass preview/apply/idempotence/corruption/store-isolation and
  lock-contention cases, alongside doctor/catalog harnesses and counted suite.
- Review-driven fixes: reproduced an embedded-NUL catalog being accepted as an
  empty catalog and authorizing wrong pruning; raw and hex-decoded NUL bytes
  now fail before String conversion in catalog and preference readers. Missing
  preferences are disclosed as unconfigured and block repair. Broader UTF-8
  codec admission remains S09; this is not completion of that slice.
- Selector integration also exposed scientific-notation truncation reporting a
  22-byte fixture as gigabytes. Model size display now uses the tested shared
  binary-unit formatter. Recipe-only choices are filtered before prompting.
- Evidence: final `.aesir/aesir-s04` build passed; preference/selector, doctor,
  and both catalog-selection harnesses passed. Counted suite: 182 pass, 0 fail,
  1 existing external-fixture skip (183 total). Doc-drift and whitespace gates
  passed with existing legacy-artifact warnings only. Initial independent review
  found the NUL and missing-preferences gaps; main-agent verification reproduced
  and fixed both. Independent re-review was unavailable after the reviewer
  session disappeared; no independent approval of the final patch is claimed.

### S05 — Interactive home launcher

- Status: done; verified and pushed as `5c147af`.
- Boundary: `cli/home.mojo` owns a plain terminal home menu; main routes explicit
  `home` and no-argument terminal launches there. Redirected no-argument calls
  retain help, while explicit nonterminal home rejects immediately. Strict
  `--model-store` parsing and `--help` work before interactive setup.
- Actions: start CUDA chat, list catalog, run doctor, preview preference repair,
  show command help, quit. Display catalog/installed/recipe counts without GPU
  startup or hashing; errors are visible and do not create or repair files.
- Process ownership: execute each action as an argv-only attached child of the
  current binary, inherit terminal/environment, wait and reap. This keeps GPU
  session lifetime and same-PID chat model-switch exec confined to the child.
  No shell, implicit network access, hidden downloads, or persistent daemon.
- Gate: Python PTY harness covers initial/default/custom stores, redirected
  stdin/stdout, no-model/recipe-only, invalid choices/flags, chat failure return,
  Ctrl+C and EOF. Native build, previous CLI regressions and counted suite pass.
  Real successful GPU conversation remains the existing chat path; this slice
  must not claim a new physical inference proof from dummy model fixtures.

- Results: CUDA-targeted native build passed; `test_native_home.py`,
  `test_native_preferences.py`, `test_native_doctor.py` and
  `test_native_model_store.py` passed against `.aesir/aesir-s05`.
  Counted suite: 182 pass, 0 fail, 1 existing fixture skip (183 total).
  PTY checks also verify child exit statuses, SIGTERM recovery and reaping.

### S06 — Local launch helpers

- Status: active; split into S06a verified-build terminal entry and S06b
  Windows/WSL and desktop integration, preserving the parent acceptance gate.
- S06a boundary: repository-owned Python build/launch plumbing only, never
  inference. Explicit `--build` uses the installed Pixi environment with
  frozen/no-install/offline flags. Normal launch never invokes a package manager.
  A source/toolchain-input fingerprint and executable digest reject absent,
  stale or modified builds; launch anchors relative model paths to this repo.
  Publication is locked and staged; failed builds preserve the prior artifact.
- S06a gate: isolated fixtures cover spaces/metacharacters in paths and argv,
  missing runtime/build, corruption, source edits, failed/interrupted builds,
  concurrent publication and child status. Build actual source and launch Home
  help through the helper without network. Desktop/Windows and physical offline
  inference remain separate gates, not inferred from fixture output.
- S06a results: nine isolated `python3 scripts/test_launch.py` tests pass;
  `python3 scripts/launch.py --build` builds actual source without installing;
  `python3 scripts/test_native_launch.py` passes real Home PTY/redirected checks.
  `unshare -Urn python3 scripts/launch.py -- home --help` passes with external
  networking unavailable. Engine source unchanged since S05's 182/0/1 suite.
  Full `unshare -Urn python3 scripts/test_native_launch.py` also passed.
  S06a done; pushed as `679aeb1`.
- S06b active contract: Windows PowerShell wrapper selects an optional prepared
  WSL distribution, checks WSL/Python availability and delegates to the existing
  launcher. Encode app argv as UTF-8 JSON/base64 across Windows native quoting;
  a strict Linux bridge decodes data, never shell code. Preserve terminal streams
  and exit status. No installation, distro shutdown, registry or shortcut writes.
  Export an opt-in Linux `Terminal=true` desktop entry without overwriting files.
- S06b gates: Windows PowerShell argument/failure fixtures and actual WSL Home
  help/check; Linux desktop parsing and literal-path fixtures; prior launch tests
  and network-isolated native Home. Cold-machine/graphical desktop interaction
  cannot be inferred from parser tests and must remain an explicit open gate.
- S06b results: both PowerShell contract and actual WSL transport harnesses
  passed on PowerShell 5.1 and 7. Native Home help, `-Check` and error exit 1
  passed through the real Windows wrapper. Four Linux platform tests (including
  Gio/GLib parsing) and nine launcher tests pass. Network-isolated native Home
  PTY harness passed again. Engine source remains unchanged from S05.
  Implementation sub-slice done; pushed as `0c76d82`.
- Remaining S06 parent gates: coordinated cold-host/WSL startup and graphical
  desktop click-through. No active WSL sessions were terminated; no desktop UI
  witness is inferred from parser execution. Keep S06 open until those witnesses
  exist. Next independent development is S07, subject to its listed dependencies.

### S07 — Generation settings and precedence

- Status: done. S03 dependency was published as `2e13fd4`; S06's physical
  launch witnesses do not block this independent settings work.
- S07a contract: move pure native sampling parsing/update validation to core,
  retaining the CLI adapter. Add `serve` sampling flags as immutable service
  defaults. Native/OpenAI/Ollama request constructors inherit that baseline and
  override only supplied fields; request N cannot change request N+1 defaults.
  Explicit zero temperature/seed are real overrides. Unsupported API fields
  remain rejected, including repetition-window changes after allocation.
- Gate: cross-adapter table tests compare full effective settings, default
  inheritance, explicit zero, unsupported fields and no source mutation. Native
  CLI errors must reject invalid flags before key/model access. Build and full
  counted suite pass. No new physical inference or external API parity claim.
- S07b remains recipe/config layering and effective-settings reporting; token,
  context and session precedence still need explicit completion evidence.
- S07a results: focused `test_local_protocol.mojo` passed; explicit offline
  `python3 scripts/launch.py --build` rebuilt the current launcher executable.
  Full counted suite passed 182/0/1 (183 total). Built
  `test_native_service_settings.py` and `test_native_home.py` passed against
  `.aesir/launch/aesir`. S07a done; pushed as `b5805f3`. S07 remains active.
- S07b1 active: before runtime layering, harden the existing generic Modelfile
  conversion. Use strict bounded numeric parsing, reject unknown conversion
  parameters and duplicate PARAMETER entries, preserve literal parameter values,
  and make the conversion's context/default token limit explicit. Do not alter
  legacy parse_int/parse_float consumers or claim native recipe execution.
  Gate: malformed/overflow/zero/UInt64 boundary tests, duplicates, literal stop
  values, known unsupported fields, default and explicit context bounds; full
  counted suite, fresh build and existing model-store process regressions.
- S07b1 results: regression failed before implementation on accepted
  `temperature 0.8junk`; focused CLI tests now pass. Fresh offline launcher build
  and counted suite pass (182 passed, 0 failed, 1 existing fixture skip).
  Native recipe admission and complete model-store harnesses pass; doc drift
  passes with pre-existing artifact warnings. S07b1 done; pushed as `7de7c5b`.
  Next is native recipe/config layering, not S08; S07 remains incomplete.
- S07b2 active: apply stored native recipe sampling, num_ctx, num_predict and
  SYSTEM to chat/serve with explicit CLI overrides. Strict native conversion
  rejects unsupported directives/parameters before planning or GPU allocation.
  Add `--show-settings` with an explicit model for pre-planning JSON preview;
  it opens no model session, transcript or listener. Test real process previews,
  cross-command settings, API system-default overrides, strict rejections and
  untouched catalog bytes. Config-file layering remains S07b3.
- S07b2 results: native recipe/CLI resolver is used by chat and serve. Unsupported
  target recipe syntax/values are checked before model-switch teardown; final
  hardware fit/combined limits remain next-launch checks. Current sampling/system
  are preserved by the existing handoff; non-explicit context/reply requests come
  from the target recipe. No physical recipe switch is claimed.
  Fresh offline launcher build, counted suite (182/0/1), native settings,
  service settings, Home, recipe admission and model-store harnesses pass.
  S07b2 done; verified and pushed as `0d8dfb4`.
- S07b3 active contract: connect the existing JSON configuration schema to
  chat/serve using explicit `--config`/`-c`, mutually exclusive with
  `--model-store`. Resolve native defaults < explicitly present config sampling
  < stored recipe < explicit CLI; request overrides retain S07a behavior.
  Config owns its existing temperature/top_p fields and catalog root; no implicit
  config discovery or new schema fields. Track field presence so `{}` does not
  replace native top_p with the config container's neutral default. Reject
  unsupported non-neutral hardware/safety/experimental/interface intent before
  model/transcript/key access, even in previews. Preserve existing single-shot
  and catalog semantics. Validate native Float32 representability before overlay.
  Gate: `scripts/test_native_settings.py --binary .aesir/launch/aesir` covers
  config/recipe/CLI precedence, omitted/zero fields, selector conflicts, invalid
  and special-file configs, refusal before side effects and no implicit reads;
  focused CLI/protocol tests, full counted suite, fresh offline launcher build,
  catalog/service regressions and doc drift. Session/token unification remains
  a separate S07 follow-up; no physical inference proof from previews.
- S07b3 results: the previous binary fails the new harness on unknown chat
  `--config`; fresh offline build passes config/recipe/CLI/API-mode previews,
  presence/zero overrides, selected-store isolation and all refusal/no-write
  cases. Found and fixed raw NUL truncation in the shared config file reader.
  Focused CLI/protocol tests and counted suite pass (182 pass, 0 fail, 1 existing
  fixture skip). Service settings, both catalog selectors and special-file
  admission pass; doc drift/whitespace checks pass with existing artifact
  warnings. S07b3 done; verified and pushed as `07f0aeb`. Next: S07b4 session handoff and token
  precedence audit. The existing float-to-text handoff needs round-trip tests
  for exponent-formatted/small values before claiming lossless settings across
  `/model`. No new physical inference or config-backed model-switch proof.
- S07b4a active contract: align native/OpenAI/Ollama reply-limit resolution.
  An omitted request limit inherits the resolved service default/ceiling;
  an explicit positive limit may only lower it. Wire Ollama options.num_predict
  to that same policy, refusing zero/negative/unbounded modes. Stop accepting
  ignored smaller Ollama num_ctx values: only omission or the exact loaded
  context is supported, with refusal before session reset. Keep immutable
  startup limits and default service ceiling 256. Gate: table-driven parser and
  shared policy tests across all adapters, no mutation after rejection, full
  counted suite, native build and service/settings regressions. No new wire
  parity or physical inference claim. S07b4b remains float handoff round trips.
- S07b4a results: focused regression reproduced native omission resolving to
  256 instead of configured 512. Shared limit policy now passes cross-adapter
  tables for ceilings 1/64/256/512/32768, omission/override/overflow, malformed
  explicit values and context mismatch refusal. Fresh offline native build,
  settings/service process harnesses and counted suite pass (182/0/1).
  Doc drift and whitespace checks pass with existing artifact warnings.
  Done; verified and pushed as `50bde3e`. Session handoff is next; S07 remains active.
- S07b4b active contract: serialize finite nonnegative native Float32 sampling
  values into the existing bounded unsigned-decimal CLI grammar for `/model`
  handoff. Expand exponent notation from Float64 formatting and verify numerical
  round trips; canonicalize signed zero to zero. Use it for the four floating
  controls only; preserve seed/count integer paths and process-image lifecycle.
  Gate: reproduce current small-value handoff refusal, boundary/stratified IEEE
  value round trips, malformed/negative/nonfinite rejection, counted suite,
  native build and process settings/Home regressions. No new physical model
  switch claim; no widening of public sampling syntax.
- S07b4b results: the focused regression reproduced `String(Float32(0.000001))`
  becoming exponent notation rejected by the unchanged public parser. The core
  handoff formatter now expands exponent form, bounds output and verifies exact
  UInt32 bit round trip before exec; signed zero becomes `0`. A 1,031-value
  stratified positive finite Float32 corpus covers every exponent plus selected
  mantissas, subnormals and maximum finite value; negative/NaN/infinity reject.
  Counted model-switch tests verify four floating argv controls plus preserved
  non-sampling controls. Focused sampling, fresh offline build, settings/Home
  process regressions and full counted suite pass (182/0/1). Doc drift and
  whitespace gates pass with existing artifact warnings. Physical recipe/config
  switching was not rerun. This completion record closes S07 on push; next S08.

### S08 — Model inspection and fit explanation

- Status: done; split into inspection truth (S08a) and observed fit decisions
  (S08b), preserving the parent gate. S07 was published as `3e58c83`.
- S08a contract: version the existing inspect JSON as metadata/layout evidence,
  not execution proof. Report requested/evaluated context and native tensor
  validation state. Preserve exact bounded loader/profile failure text instead
  of replacing all layout failures with one generic reason. Keep unsupported
  family/variant/quantization distinctions and read-only catalog resolution.
  Gate: classification boundary tables, JSON parse/schema parity, malformed and
  unsupported real-process fixtures, fresh build/full suite, and read-only
  inspection of available installed Gemma/Qwen models. Do not claim memory fit,
  allocation or inference from inspection. S08b owns device/host fit reasons.
- S08a results: JSON schema v1 and text now expose metadata/layout scope,
  execution_tested=false, requested/evaluated contexts and tensor-validation
  state. Recognized layout failures preserve the exact bounded validator error.
  Counted family/variant/quantization/schema tests pass; synthetic built-process
  fixtures pass for Unicode metadata, unknown architecture and recognized Gemma
  with missing layout metadata. Fresh offline build, doctor harness and full
  counted suite pass (182/0/1). Read-only inspection of installed Gemma 4 E2B
  Q4_K_M and Qwen 3 0.6B Q4_K_M at context 4096 reports READY/VERIFIED,
  tensor_validation=passed and planned device bytes 3,172,434,532 and 868,304,068
  respectively. This does not observe fit or execute inference. S08a was
  published as `5e88bcf`.
- S08b contract: make every host/device fit decision expose stable reason codes
  and the exact overflow-safe inequality inputs: required, observed available,
  reserve, usable, deficit and headroom bytes. Preserve automatic/explicit CUDA
  selection and fail-closed behavior; retain per-device causes when no device
  fits. Gate with exact-fit, one-byte-deficit, reserve-over-available, maximum
  signed-byte and absent-device fixtures, the full counted suite, a fresh
  offline build, and observed explanations for the installed Gemma/Qwen models.
- S08b results: the planner now returns `MemoryFitExplanation` evidence instead
  of reducing admission to a Boolean. Selection retains incompatible, wrong-API,
  out-of-range, absent-device and arithmetic rejection causes; automatic-context
  exhaustion preserves the final fit evidence. `compute plan|explain` prints
  device and host reason codes plus required/available/reserve/usable/deficit/
  headroom bytes from the same selection snapshot. Counted boundary regressions
  and the full suite pass (182/0/1); a fresh offline build passed. On the observed
  RTX host, installed Gemma 4 E2B and Qwen 3 0.6B at context 4096 reported exact
  device headroom of 3,001,580,956 and 5,305,711,420 bytes. A deliberate 16 GiB
  reserve rejected with `device_reserve_exceeds_available` and retained every
  arithmetic operand. No allocation or inference is inferred. S08 is complete;
  next is S09 shared text admission.

### S09 — Shared persisted-text admission

- Status: done. `core/text_admission.mojo` owns the bounded byte-to-String
  boundary for configuration, catalog, preference, conversation and StateVault
  records. It rejects raw NUL, malformed/truncated/overlong UTF-8, surrogate
  encodings and values above U+10FFFF before String construction. Catalog,
  preference and conversation hex payloads pass through the same contract after
  decoding. Format parsers retain exact record counts/checksums and reject
  appended trailing data before state publication.
- Evidence: the new counted boundary corpus covers valid 1/2/3/4-byte edges,
  NUL, lone continuations, overlong forms, truncation, surrogates, out-of-range
  code points and size limits. Conversation and StateVault file fixtures reject
  malformed UTF-8 without changing active state. Built-process config, catalog
  and preference harnesses reject raw/encoded malformed UTF-8 and trailing data
  while preserving every test-owned durable byte. Fresh offline build and full
  suite pass (183/0/1, 184 total). S09 is complete; next is S10 crash injection.

### S10 — Catalog commit crash injection

- Status: done. A Linux-only process harness compiles a test-owned
  `LD_PRELOAD` shim, performs a real native `cp` catalog mutation, and sends
  `SIGKILL` immediately after successful staged write, staged-file `fsync`,
  atomic rename, or store-directory `fsync`. Each stage starts from the same
  independently created old catalog and is compared byte-for-byte with an
  independently committed new catalog.
- Evidence: pre-rename kills restart with exactly the old record; post-rename
  kills restart with exactly the complete new record. No stage exposes empty,
  partial, or unknown catalog bytes, and every restarted store accepts a later
  mutation. The shim writes an out-of-store marker through direct syscalls so
  the harness proves the intended boundary was reached. The fresh current
  native binary passed all four stages; the harness is now a hosted Linux CI gate.
  This is process-crash evidence, not a simulated sudden-power-loss/filesystem
  durability proof. Pre-rename kills can leave an ignored private staging file;
  automatic root-stage cleanup and garbage-collection fault injection remain
  open. S10 is complete; next is S11 resumable-download hardening.

### S11 — Resumable-download inode hardening

- Status: done. The downloader pins the output parent and deterministic partial
  with open descriptors. Curl, GGUF header inspection, SHA-256 verification,
  file sync and exclusive hard-link publication operate on the same opened
  inode. Partial reuse requires a regular current-owner single-link file; safe
  interruption preserves only an incomplete partial whose name still resolves
  to that inode. Foreign stage replacements and destination races are preserved
  without overwrite. Parallel range files are descriptor-bound but restart from
  zero.
- Evidence: the controlled no-network fixture passed interruption/resume,
  corrupt and complete partials, staging-path replacement, destination race,
  hard-link rejection and three-range assembly. The pinned 689,216-byte public
  HTTPS artifact passed all eight live download/resume/failure/registration
  checks. Special-file admission passed; the full counted suite passed 183/0/1
  (184 total). Exact-inode replacement publication is proved on native Linux
  storage. WSL DrvFS may instead invalidate an open descriptor across rename;
  the digest gate fails closed and publishes nothing. This does not prove
  authenticated or resumable parallel transfer.

### S12 — Explicit offline preparation manifest

- Status: done. `scripts/offline.py prepare` performs the frozen/no-install/
  offline build, verifies every requested catalog model, and writes a versioned
  local manifest containing source/build identity, Pixi, lockfile, Mojo,
  runtime-library and model SHA-256/size pins plus disk-capacity facts. `check`
  verifies the exact artifact set, aggregates missing/corrupt items by stable
  names, and optionally proves an offline rebuild and bounded inference.
- Evidence: four isolated workflow cases pass, including named simultaneous
  `file:mojo` and `model:alpha:latest` failures and binary/manifest tamper
  rejection. On the prepared WSL host, `prepare` pinned the installed
  3,106,738,272-byte Gemma 4 E2B record. Inside a fresh user/network namespace
  with outbound networking unavailable, `check --rebuild --inference` rebuilt
  from the locked cache, verified every recorded dependency and model byte, and
  generated one native CUDA token (`OK`). This is a prepared-checkout witness,
  not an installer, clean-machine proof, driver package or signed release.

### S13 — Named conversation library

- Status: done. `scripts/conversations.py` manages validated native v1 snapshots
  under stable random entry IDs with bounded NFC Unicode names. Explicit
  `save`, `list`, `open`, `rename`, and `export` commands share one library
  lock; snapshot and metadata identities are revalidated on every discovery.
  Save and export never overwrite. Open can require the exact model, profile and
  context before returning the snapshot path for native `/load`.
- Evidence: five separate-process cases pass restart discovery, Unicode naming,
  duplicate refusal, rename, Markdown export, destination non-overwrite,
  checksum corruption rejection and incompatible-model refusal. A previously
  generated native Qwen snapshot was also imported into a fresh library,
  rediscovered in a new process and compatibility-opened under its recorded
  model/profile/context. The existing
  counted native codec/compatibility cases continue to own exact-token restore
  and complete system/sampling/model compatibility. The library imports an
  explicit snapshot rather than silently autosaving a live chat. It has no
  delete UI; interrupted staging directories are ignored, not reclaimed. S14
  owns autosave generations and crash recovery.

### S14 — Optional crash-recovery autosave

- Status: done. Native CUDA chat accepts `--autosave-dir` plus bounded
  `--autosave-retain`. `cli/conversation_autosave.mojo` locks one caller-created
  private directory, records synced inflight intent before generation, publishes
  immutable exact-token snapshots before a checksummed atomic manifest, and
  evicts only generations named by the previous authoritative manifest. Restart
  loads the newest committed generation through the existing full native
  compatibility and KV-replay boundary and reports interrupted generation/turn
  identity. Reset, explicit load and sampling mutations also checkpoint.
- Evidence: the counted native case proves three-generation recovery, retention
  of two, interruption detection, and preservation of an unrelated sentinel.
  A separate-process harness SIGKILLs the compiled native probe after durable
  generation-two intent; restart recovers committed turn one, identifies turn
  two as interrupted, rejects symlink/nonprivate roots and a concurrent second
  owner without hanging, removes only owned interruption state, and rejects a
  checksum-corrupt current manifest. Main builds, named-library/offline
  regressions pass, and the counted suite passes 184/0/1 (185 total).
- Boundary: the autosave directory must already exist, be owner-held and have no
  group/world permissions. This is Linux process-crash evidence on the tested
  filesystem, not sudden-power-loss proof or physical post-crash CUDA
  continuation. Full identity mismatches fail closed. Model switching while
  autosave is enabled is deliberately rejected; generation-error and switch
  recovery belong to S15.

### S15 — Native chat lifecycle recovery

- Status: done. Both native session families now use one phase-based recovery
  policy. Healthy idle rejection removes only uncommitted autosave intent and
  continues; interrupted prefill reports the mandatory `/clear` gate. Unhealthy
  or in-flight execution terminates. A close marker set immediately after the
  generation loop prevents transcript/autosave finalization failure from being
  called an uncommitted turn or inviting a blind retry.
- Model-switch decision: target validation remains inside the live old-session
  scope, so invalid/incompatible targets preserve it. Once a valid switch has
  unwound that scope, same-PID `execv` carries the prior model reference into
  target startup. Planning/allocation/load/restore failure then states that the
  old session was unloaded and conversation reset and names the prior reference
  to restart. Automatic rollback is deliberately not claimed across the process
  image boundary. Autosave-bound switching remains rejected because generations
  are exact-model state, not a migration format.
- Evidence: main builds; `scripts/test_chat_recovery.py` drives initial and
  post-switch model-load failures through separate built processes and verifies
  nonzero exact restart instructions. Counted
  `cli.chat_recovery_policy` injects initial allocation, switched load, prefill
  timeout, unhealthy generation and post-close finalization states, verifies no
  false commit/retry decision, and proves inherited transcript descriptor cleanup
  during error unwind. The installed-model physical probes pass same-PID
  Gemma→Qwen→Gemma switching and Gemma cancellation, next-turn recovery,
  prefill-timeout `/clear`, and idle Ctrl+C. The latter exposed and closed a
  post-turn signal race that had drained an idle interrupt without exiting. The
  complete suite passes 185/0/1 (186 total).
- Boundary: allocation and timeout policy are hardware-independent fault
  injections; this slice did not deliberately exhaust the physical GPU or add
  allocator leak instrumentation. Failed-session resources unwind by native
  scope or process exit. The physical probes remain opt-in and exercise installed
  models, not deliberate target-load OOM; switch assertions now recognize
  pre-unload rejection.

### S16 — Catalog migration, backup, restore and contention

- Status: done. `aesir catalog migrate` strictly imports the pre-v1 delimiter
  schema only into a catalog-free destination and publishes canonical v1 through
  the existing locked staged-write/fsync/rename/directory-fsync transaction.
  `catalog backup` creates one owner-private synchronized snapshot without
  overwrite. `catalog restore` can repair an unreadable current catalog, but
  parses/canonicalizes the complete backup and rehashes all referenced blobs
  before atomically replacing catalog state.
- Evidence: `scripts/test_catalog_lifecycle.py` builds a real legacy fixture,
  migrates it, launches six concurrent native writers and observes all seven
  records, proves backup non-overwrite, restores over deliberately corrupt
  current bytes, and rejects a symlink destination, FIFO source, truncated
  snapshot, and valid snapshot whose blob is absent without publishing
  destination catalog state. The full
  pre-existing native model-store harness passes in direct/config/default modes,
  and the four-boundary SIGKILL catalog harness still exposes only old or complete
  new state and remains writable.
- Boundary: backups contain catalog metadata, not model blobs or preferences;
  restore requires referenced blobs to exist under the destination root.
  Migration is one-way and refuses nonempty destinations. Evidence covers
  process crashes on the tested Linux filesystem, not arbitrary power-loss or
  injected device/fsync failure.

### S17 — Versioned local API support contract

- Status: implemented and verified on the installed Gemma 4 E2B Q4_K_M CUDA
  model.
- Added `docs/API_SUPPORT_MATRIX_V1.md` and an independently authored 27-case
  JSON request/response corpus with a standard-library HTTP runner. The matrix
  names route availability by service mode, accepted fields, explicit exclusions,
  success/error shapes and the current final-record-only streaming behavior.
  The corpus checks native bearer admission, exact content type/framing, model
  catalog, generation/chat/completion responses, usage arithmetic and rejection
  of known unsupported fields/options against a running real CUDA service.
  Route-specific admission rejects otherwise parsed but silently ignored
  prompt/message fields, and `/api/show` now accepts only model identity.
- A live fixture exposed malformed OpenAI chat SSE: pretty-printed JSON was
  placed after only one `data:` prefix. The serializer now emits a single-line
  JSON event, and its Mojo regression assertion checks that shape. Updated the
  older native service test's obsolete expectation that `/v1/models` was 404.
- Evidence: fresh `mojo build --target-accelerator sm_89` succeeded; the v1
  fixture runner passed all 13 native/OpenAI cases and 14 Ollama cases against
  the existing `gemma4-e2b:latest` catalog model on the RTX 4070 Laptop GPU;
  `pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/run_all.mojo`
  reported 185 passed, 0 failed, 1 skipped, 186 total;
  `python scripts/check_doc_drift.py` passed with only pre-existing
  deletion-approval warnings. The fixture corpus and Python runner also passed
  JSON and syntax validation.
- Limits at S17: these are bounded Aesir subsets, not complete Ollama/OpenAI
  compatibility. `stream:true` buffered all generation and sent only one final
  NDJSON/SSE record. The S18/S19 first-token, disconnect and backpressure
  gates were open. This run did not test every model family,
  client SDK, cross-platform host or network threat scenario.

### S18 — Native incremental generation transport

- Status: implemented and verified on the installed Gemma 4 E2B Q4_K_M CUDA
  model. The v1 API matrix records this additive native-only stream contract;
  the OpenAI/Ollama adapters remain S19.
- `GenerateRequest` accepts a strict JSON boolean `stream`, defaulting to
  `false`; numeric/string values still fail. `FlatJSON.fields` recognizes
  booleans without relaxing non-boolean control admission. The native route
  uses `ControlledTextSession.next_chunk()` (complete UTF-8 output from the
  model decoder), sends a close-delimited NDJSON header before decode, writes
  each nonempty text chunk immediately, and sends one terminal record with
  observed finish reason, counts, context and backend. Non-streaming responses
  retain their prior shape. Once headers are sent, failures do not append a
  second HTTP response; an interrupted active generation is cancelled.
- Evidence: fresh `mojo build --target-accelerator sm_89` succeeded;
  `scripts/test_native_streaming.py` on the real RTX 4070/Gemma E2B model
  observed 64 text records with first-to-final separation about 4 seconds,
  independently decoded every line as UTF-8/JSON, checked terminal counts,
  deterministic text/count replay against non-streaming output, and separately
  verified an EOS terminal record. The counted suite reported 185 passed,
  0 failed, 1 skipped, 186 total. The v1 request/response corpus passed all
  27 independently authored HTTP cases against the S18 build.
- Limits: physical incremental evidence is on Gemma E2B only. Connection-close
  framing requires EOF to end the response; a missing `done:true` means an
  incomplete stream. Disconnection, slow-receiver backpressure and correct
  incremental OpenAI SSE/Ollama NDJSON are S19 gates, not claimed here.

### S19 — Incremental OpenAI and Ollama compatibility streams

- Status: implemented and verified on the installed Gemma 4 E2B Q4_K_M CUDA
  model. This is the v1 matrix's bounded text-only subset, not full SDK or
  external-server parity.
- `/v1/chat/completions` and `/v1/completions` now send SSE while native
  decoding runs. Chat begins with an assistant-role delta, intermediate choices
  carry `finish_reason:null`, the terminal choice carries an empty delta/text
  and observed `stop`/`length`, then one `[DONE]`. `/api/generate` and
  `/api/chat` send nonempty `done:false` NDJSON text/message records during
  decoding and one observed counted `done:true` record. All records use
  complete UTF-8 from `next_chunk()`. Non-streaming JSON remains supported.
- Stream headers are close-delimited, no `Content-Length`; all writes use the
  nonblocking bounded send loop. Failed writes cancel active generation so
  the next request can use a healthy reset session. After headers, deadlines
  emit sanitized `Gateway Timeout` SSE/NDJSON error frames without a success
  terminal marker; response limit/internal failures have separate sanitized
  frames. Errors before headers keep ordinary status/JSON shapes.
- Evidence: fresh `sm_89` build; `scripts/test_compat_streaming.py` through
  Python's standard HTTP client observed 64 incremental content records for
  each OpenAI and Ollama generation/chat path, about four seconds between
  first text and final record, parsed terminal and `[DONE]` framing, and saw
  reset-peer recovery in about 0.12 seconds in each mode. A slow client with a
  short reply completed within the bounded reply and left the service healthy;
  an independent 1 MiB no-reader socket probe forced the same transport's
  300 ms write deadline (observed 301 ms). Separate real-model 4.5-second
  generation deadlines yielded 29 prior OpenAI SSE events and 30 prior Ollama
  NDJSON records, then sanitized timeout error frames, no success terminal,
  and successful next-request recovery. The counted suite reported 185 passed,
  0 failed, 1 skipped, 186 total. The 29-case API corpus passed against the
  final S19 build.
- Limits: only Gemma E2B on one NVIDIA host is physically covered. A short
  reply may fit kernel socket buffers even when an application stops reading;
  the forced no-reader probe separately proves the write deadline once buffers
  fill. These checks do not establish official SDK parity, remote/public
  deployment safety, all model families, tools, embeddings, multimodal input,
  or streaming usage options. S20 owns bounded multi-client queueing.

### S20–S48

- Status: queued; use the corresponding table row as the initial slice contract.
- Append implementation decisions, commands, results and remaining gates as each
  slice becomes active. No unchecked row implies an implemented feature.
