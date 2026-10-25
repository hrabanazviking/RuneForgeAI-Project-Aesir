# Project A.E.S.I.R. Canonical Capability Ledger

**Ledger version:** Application S19 compatibility streaming, September 22, 2026

This is the canonical source of truth for the current implementation status of
Project A.E.S.I.R.

**Owner scope directive (2026-10-12):** all Project Æsir LLM inference work is Hailo-10H-only. CPU LLM inference, CPU fallback, CPU shadow inference, and CPU model-serving are out of scope. The canonical Hailo CLI uses the direct backend described below; unsupported or unavailable inference must fail closed. The ARMVEGR CPU LLM inference CLI and direct inference methods now raise CpuInferenceProhibited before inference math; their underlying historical kernels remain in source but are not an authorized or available runtime route. CPU capability entries below are historical records only and do not authorize further CPU work. Vision documents describe desired direction; task files and
devlogs describe work at a point in time; names, banners, and test titles describe
interfaces. None of those supersede this ledger's present-tense capability
statuses.

The ledger intentionally separates narrow working primitives from the broader
systems they may eventually support. A verified host primitive does not verify Hailo hardware. A tested JSON
formatter does not verify an HTTP API. A deterministic local
simulation can be well tested and still remain `simulated`.

## 1. Status Contract

Every entry has exactly one primary status:

| Status | Meaning |
|---|---|
| `verified` | The narrowly worded capability has executable evidence that performs the claimed work. External compatibility claims require a real fixture, independent oracle, or physical backend. |
| `partial` | Meaningful real logic exists, but correctness breadth, integration, portability, persistence, safety, or representative coverage is incomplete. |
| `scaffold` | Types, interfaces, local structures, or routing shapes exist, but the advertised subsystem operation is not implemented end to end. |
| `simulated` | Predetermined values, seeded state, fixed output, or local toggles are presented in the shape of an operation that did not occur. |
| `missing` | The advertised or required behavior has no meaningful implementation in the repository. |

Status is scoped to the exact capability heading. Synthetic evidence may verify
a local invariant, but never external hardware, protocol, download, persistence,
performance, or ecosystem parity. “Complete,” “production-ready,” “drop-in,” and
“parity” are prohibited as maturity labels unless the corresponding external
acceptance gate has actually passed.

## 2. Reproducible Evidence Commands

Run commands from the repository root unless stated otherwise.

| Evidence key | Command | Establishes |
|---|---|---|
| `E-MASTER` | `pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/run_all.mojo` | 266 named executable cases are registered, 1 external-fixture case is explicitly skipped, total 267. This run includes `cli.catalog_schema_interface`, `cli.catalog_schema_unit_evidence`, `cli.blob_identity_interface`, `cli.blob_identity_unit_evidence`, `cli.atomic_registration_unit_evidence`, `local_service.http_bounds`, `local_service.http_framing`, `local_service.socketpair_framing`, `local_service.transport_adversarial`, `local_service.fd_ownership`, `local_service.socket_admission`, `sampling.greedy_tie_policy`, `sampling.greedy_tie_adversarial`, `sampling.temperature_distribution_oracle`, `sampling.temperature_integration`, `sampling.temperature_adversarial`, `sampling.top_k_boundaries`, `sampling.top_k_integration`, `sampling.top_k_adversarial`, `sampling.top_k_integration`, `memory.checked_span`, `memory.rune_tensor_layout`, `memory.allocation_bounds`, `gguf.version_interface`, `gguf.version_reference`, `gguf.version_integration`, `gguf.header_adversarial`, `gguf.metadata_type_baseline`, `gguf.metadata_type_integration`, `gguf.tensor_directory_baseline`, `gguf.tensor_directory_interface`, `gguf.tensor_directory_adversarial`, `gguf.tensor_directory_integration`, `gguf.tensor_directory_pool_adversarial`, `compute.rmsnorm_interface`, `compute.rmsnorm_reference`, `compute.rmsnorm_adversarial`, `compute.rope_interface`, `compute.rope_reference`, `compute.rope_integration`, `compute.attention_interface`, `compute.attention_reference`, `compute.attention_integration`, `compute.attention_adversarial`, `compute.rope_adversarial`, and `inference.rmsnorm_integration`. Synthetic/scaffold cases prove only their narrow local assertions. |
| `E-REAL` | `pixi run mojo run aesir_engine/tests/test_real_gguf.mojo /path/to/stories260K.F16.gguf` | With the pinned external fixture identified below: exact GGUF metadata, F16 mmap alias, F32 norm conversion, tokenizer IDs, first token, 32 greedy token IDs/text, stop reason, context boundary, and pool restoration. |
| `E-BUILD` | `pixi run mojo build --target-accelerator sm_89 aesir_engine/main.mojo -o /tmp/aesir-sigrun-sm89-build` | Current source compiles into a Linux x86-64 executable in the configured Pixi environment; the resulting binary's `--help` smoke path exits successfully. |
| `E-API-CONTRACT` | `python3 scripts/test_api_contract_v1.py --binary /tmp/aesir-ledger-build --model gemma4-e2b:latest` | With an already-installed local catalog model, 29 independently authored live HTTP cases check the bounded native/Ollama/OpenAI route subset and incremental compatibility framing. Does not download a model or prove full external compatibility. |
| `E-NATIVE-STREAM` | `python3 scripts/test_native_streaming.py --binary /tmp/aesir-ledger-build --model gemma4-e2b:latest` | On the installed Gemma CUDA model, independently reads native NDJSON during decoding, observes first text before final, checks UTF-8/JSON records, deterministic non-streamed text/count replay and a separate EOS terminal record. |
| `E-COMPAT-STREAM` | `python3 scripts/test_compat_streaming.py --binary /tmp/aesir-ledger-build --model gemma4-e2b:latest` | With an installed Gemma CUDA model, a standard-library client parses incremental OpenAI chat/completion SSE and Ollama chat/generate NDJSON, tests reset-peer cancellation and next-request recovery, checks a slow reader, and forces post-header deadlines that produce sanitized error frames without success terminals. |
| `E-BACKPRESSURE` | `pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/probe_stream_backpressure.mojo` | A nonreading socketpair with a small send buffer forces a 1 MiB transport write past the send buffer; the nonblocking service send loop exits at its configured 300 ms deadline. |
| `E-CLI` | `/tmp/aesir-ledger-build run /path/to/stories260K.F16.gguf --max-tokens 32 One day, Timmy went to` | The built single-shot CLI executes the pinned real model and emits the verified 32-token completion. |
| `E-STORE` | `python3 scripts/test_native_model_store.py --binary /tmp/aesir-ledger-build` | Separate native CLI processes perform empty-start, create/list/show/copy/remove, rollback, permission and symlink checks against a caller-owned temporary catalog. |
| `E-CATALOG-LIFECYCLE` | `python3 scripts/test_catalog_lifecycle.py --binary /tmp/aesir-ledger-build` | A real pre-v1 delimiter fixture migrates atomically into an empty store; six concurrent writers preserve every record; backup is synchronized, non-overwriting and symlink-safe; valid restore repairs corrupt current state; FIFO, malformed and missing-blob backups do not publish a catalog. |
| `E-CRASH` | `python3 scripts/test_catalog_crash_atomicity.py --binary /tmp/aesir-ledger-build` | A test-only Linux interposition shim kills the real catalog writer after staged write, staged-file sync, rename, and directory sync; restart exposes exactly the old or complete new catalog and remains writable. |
| `E-HF-RESUME` | `python3 scripts/test_hf_download_resilience.py --binary /tmp/aesir-ledger-build` | A controlled no-network curl fixture proves exact partial continuation, corrupt-partial rejection, complete-partial reuse, exact-inode publication after path replacement on native Linux storage, destination-race non-overwrite, hard-link rejection, and parallel assembly. |
| `E-OFFLINE` | `python3 scripts/test_offline_preparation.py` | Four isolated workflow cases prove manifest creation, rebuild/check/inference dispatch, named aggregate failures for missing runtime/model artifacts, requested-model rejection, and tamper rejection. |
| `E-CONVERSATIONS` | `python3 scripts/test_conversation_library.py` | Five separate-process cases prove named save/list/open/rename/export, Unicode names, restart discovery, duplicate and overwrite refusal, snapshot/metadata integrity, and explicit model/profile/context compatibility gates. |
| `E-AUTOSAVE` | `pixi run mojo build --target-accelerator sm_89 aesir_engine/tests/test_conversation_autosave.mojo -o /tmp/aesir-autosave-probe && python3 scripts/test_conversation_autosave.py --binary /tmp/aesir-autosave-probe` | The native owner rejects symlink/nonprivate roots. A fresh process recovers the latest committed exact-token generation after SIGKILL, identifies a durable interrupted generation, rejects a concurrent second owner without hanging, preserves unrelated files during cleanup, and rejects authoritative-manifest corruption. |
| `E-CHAT-RECOVERY` | `python3 scripts/test_chat_recovery.py --binary /tmp/aesir-ledger-build` | Separate native CLI processes inject initial and post-switch model-load failure. Initial startup names the current-model restart; post-switch startup reports that the prior session was unloaded/reset and carries the exact previous reference to restart. Both exit nonzero without claiming a committed target turn. |
| `E-SPECIAL` | `python3 scripts/test_special_file_admission.py --binary /tmp/aesir-ledger-build` | The built CLI rejects configuration, GGUF, resumable-download staging, Modelfile, source-blob, installed-blob, and catalog FIFOs without stalling. |
| `E-SOURCE` | `rg`/source inspection at the cited paths | Establishes only that the named source shape or absence exists; it is not runtime proof. |

| `E-ARMVEGR-ORACLE` | `python3 prof/armvegr/test_kernel_oracles.py` (on Mimir) | 26/26 oracle cases pass: every C2 kernel's Mojo output matches an independent float64 pure-Python reference within its documented bound; non-zero exit on any violation. |
| `E-ARMVEGR-VERIFY` | `/usr/local/bin/mojo build -I. -o /tmp/c2_verify tests/c2_verify.mojo && /tmp/c2_verify` (on Mimir) | 241/241 checks pass, exit 0: per-kernel contracts, MHA seq/par bit-identity, backend-selection fail-closed, H039 toy forward. |
| `E-ARMVEGR-PERF` | `/usr/local/bin/mojo build -I. -o /tmp/perf_bench armvegr/perf_bench.mojo && taskset -c 3 /tmp/perf_bench` (on Mimir, governor `performance`) | Median-of-11 per-kernel GFLOPS/GB/s written to `data/armvegr/kernel_perf.json`; method in `data/armvegr/BENCHMARK_METHOD.md`. |

Pinned `E-REAL` fixture and oracle:

- model: `shibatch/stories-converted`, revision
  `4724c9612ac3278f58aa2dbd4d79457e2672247d`, file
  `stories260K.F16.gguf`;
- SHA-256: `57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3`;
- reference runtime: `llama.cpp` commit
  `7e4c0a96880dae4fc4268ad441f8a6446bd5460a`;
- prompt: `One day, Timmy went to`; and
- mode: greedy, 32 requested new tokens.

The model path above is deliberately a placeholder. Model weights and machine
paths are not stored in the repository.

## 3. Status Summary

Counts use all numeric AES capability identifiers, including the campaign
appendix. One historical entry retains the noncanonical `blocked` status.
The stricter AES500 schema checker reports pre-existing appendix inconsistencies;
this integration does not promote historical statuses or hide checker failures.

| Status | Count |
|---|---:|
| `verified` | 146 |
| `partial` | 30 |
| `scaffold` | 0 |
| `simulated` | 0 |
| `missing` | 15 |
| Historical noncanonical status | 1 |
| **Total** | **192** |

## 4. Foundation, Build, and Test Truth

### AES-FND-001 — Counted fail-closed master-suite reporting

- **Status:** `verified`
- **Owner:** tests domain
- **Claim sources:** `TODO.md`; `TASK_fail_closed_test_semantics.md`; `TASK_counted_test_reporting.md`
- **Implementation evidence:** `aesir_engine/tests/test_ledger.mojo::TestLedger`, `run_case`, and `record_skip`; registration in `aesir_engine/tests/run_all.mojo`.
- **Executable evidence:** `E-MASTER`; the deliberate Forge 0B negative mutation produced 48 pass, 1 fail, 1 skip, total 50, continued through the final case, printed `Status: FAIL`, and exited 1.
- **Evidence boundary:** This verifies runner accounting and termination, not the external capabilities named by synthetic cases.
- **Next acceptance gate:** Keep the expected total synchronized automatically with registration and run the negative-control proof in CI.
- **Audit:** AER-001, AER-112.

### AES-FND-002 — External real-GGUF integration gate

- **Status:** `verified`
- **Owner:** tests, loader, tokenizer, inference
- **Claim sources:** real-GGUF and multi-token task contracts; audit Sections 4–5
- **Implementation evidence:** `aesir_engine/tests/test_real_gguf.mojo` raises on every mismatch and requires a caller-supplied model path.
- **Executable evidence:** `E-REAL` with the pinned fixture and oracle.
- **Evidence boundary:** One Llama GGUF v3 F16 model, one primary prompt, greedy decoding, and one Linux environment; it is not a general model-compatibility matrix.
- **Next acceptance gate:** Add independently pinned models, malformed corpora, tokenizer variants, quantized fixtures, and platform runs.
- **Audit:** AER-004, AER-042, AER-113.

### AES-FND-003 — Clean native Mojo build on configured Linux platform

- **Status:** `verified`
- **Owner:** build and facade domains
- **Claim sources:** README technical specifications; historical DEVLOG build claims
- **Implementation evidence:** `aesir_engine/main.mojo`; `aesir_engine/pixi.toml` pins Mojo/MAX and `linux-64`.
- **Executable evidence:** `E-BUILD`.
- **Evidence boundary:** Compilation on the current Linux x86-64 toolchain; it does not prove portability, packaging quality, performance, or production readiness.
- **Next acceptance gate:** Reproducible CI builds from clean checkouts on every supported target with artifact and dependency verification.
- **Audit:** AER-096, AER-103, AER-104.

### AES-FND-004 — Mojo runtime without Python imports

- **Status:** `verified`
- **Owner:** build and runtime domains
- **Claim sources:** README “Pure Mojo (Zero Python dependencies in the runtime)”
- **Implementation evidence:** 100% native Mojo runtime codebase; zero `std.python` imports across `core`, `loader`, `cli`, `server`, and `facade` engine source files.
- **Executable evidence:** `E-BUILD`, `E-CLI`, and `E-MASTER` compiled and executed via native Mojo toolchain.
- **Evidence boundary:** Verified zero Python runtime dependency imports across all engine source domains.
- **Audit:** AER-103, AER-104.

### AES-FND-005 — Automated continuous integration

- **Status:** `partial`
- **Owner:** project operations
- **Claim sources:** implied prerequisite for broad completion and production claims
- **Implementation evidence:** `.github/workflows/ci.yml` performs a clean checkout, native build, counted master suite, deliberate fail-closed negative control, and repository consistency check on pushes and pull requests.
- **Executable evidence:** the same commands are reproducible locally; hosted GitHub Actions run `33239432026` passed the clean checkout, counted master suite, native build, deliberate negative control, and repository consistency check on August 29, 2026.
- **Evidence boundary:** The tracked workflow and one successful hosted run prove the current Linux CI path, but no protected required status, supported-target matrix, or opt-in external real-model job is established here.
- **Next acceptance gate:** Require the workflow in branch protection, add supported-target coverage, and add an opt-in pinned external-fixture job.
- **Audit:** AER-100, AER-113.

### AES-FND-006 — Cross-platform runtime support

- **Status:** `missing`
- **Owner:** build and server domains
- **Claim sources:** NPU/GPU interface matrices and mobile/edge vision documents
- **Implementation evidence:** `aesir_engine/pixi.toml` supports only `linux-64`; server and mmap paths use POSIX FFI.
- **Executable evidence:** none on Windows, macOS, iOS, or Android.
- **Evidence boundary:** OS-name helpers and hardware enums are not platform support.
- **Next acceptance gate:** Platform abstractions plus clean build/runtime suites on each explicitly supported OS/architecture.
- **Audit:** AER-076, AER-096, AER-097.

### AES-FND-007 — Repository artifact and source hygiene

- **Status:** `partial`
- **Owner:** project operations
- **Claim sources:** project build and distribution posture
- **Implementation evidence:** root `.gitignore` protects common generated formats; `repository_hygiene_policy.json` pins the exact 32-file legacy exception inventory to commit `c1d02d1919dc8c98971507b80ddb46a5a24af37f`; `scripts/check_doc_drift.py` classifies tracked artifact debt and rejects TODO status tags that drift from the canonical ledger; `fixture_manifest.json` and `scripts/check_fixture_manifest.py` require classified, owned, licensed, checksummed, consumer-bound fixture provenance and keep external references outside Git.
- **Executable evidence:** `python3 scripts/test_check_doc_drift.py` and `python3 scripts/test_fixture_manifest.py` prove fail-closed policy behavior; CI runs both live validators. The artifact inventory reports seven legacy executables, one placeholder model, and 24 duplicate assets; the fixture manifest registers one external reference and no tracked payload.
- **Evidence boundary:** New extension/signature-based artifact debt and unregistered/malformed fixture provenance are rejected, but the 32 deletion-blocked legacy files remain tracked. Deep file-format validation, secret-content scanning, generated-asset license verification, release signing/SBOM, and full-history scanning remain open.
- **Next acceptance gate:** Obtain approval for and remove exact legacy paths, expand content/license/release gates, preserve canonical assets, and prove a clean checkout before promotion.
- **Audit:** AER-098, AER-099, AER-103.

### AES-FND-008 — Prepared-checkout offline build and terminal launch

- **Status:** `verified`
- **Owner:** repository launch/build scripts
- **Claim sources:** S06a, S12; `docs/LOCAL_LAUNCH.md`
- **Implementation evidence:** `scripts/launch.py` explicitly builds with frozen,
  no-install, offline Pixi flags; serializes staged publication; checks source
  and executable fingerprints before replacing itself with the native app.
  `scripts/offline.py prepare` verifies named catalog models, records their exact
  SHA-256/size pins, records the locked build/runtime/Pixi identities and disk
  reserve, then atomically writes a local versioned manifest. `check` reports
  every incomplete artifact by name and can request a cold offline rebuild and
  bounded inference witness.
- **Executable evidence:** `python3 scripts/test_launch.py` (nine passing isolated
  plumbing tests); actual `python3 scripts/launch.py --build`;
  `python3 scripts/test_native_launch.py`; native Home help through
  `unshare -Urn python3 scripts/launch.py -- home --help`; `E-OFFLINE`; and a
  physical `unshare -Urn ... offline.py check --rebuild --inference` run that
  rebuilt from the locked cache, rehashed the installed 3,106,738,272-byte
  Gemma 4 E2B pin and generated one CUDA token with no outbound network.
- **Platform-entry evidence:** `scripts/test_windows_launch.ps1` and actual WSL
  transport `scripts/test_native_windows_launch.ps1` pass on PowerShell 5.1/7;
  `scripts/launch.ps1 -Check` and native Home help pass in the prepared checkout.
  `python3 scripts/test_platform_launch.py` passes four bridge/export cases,
  including independent Gio/GLib desktop parsing and literal-path execution.
- **Evidence boundary:** Prepared trusted Linux/WSL checkout, not an installer,
  signed release, hostile-filesystem guarantee or full transitive-dependency
  audit. The manifest pins Pixi, Mojo, the lockfile, four named runtime libraries,
  the native executable and selected catalog blobs; system libraries and the
  NVIDIA driver remain observed prerequisites rather than packaged artifacts.
  Windows uses WSL, not a Windows-native engine. Desktop command parsing/export
  is verified, not graphical terminal launch. The network-isolated witness uses
  the already prepared checkout/model, not a clean-machine installer. Manifest
  creation requests owner-only mode; WSL DrvFS applies its mounted Windows
  permission semantics.
- **Next acceptance gate:** S06 cold-host/WSL startup and graphical desktop
  click-through; then S39 signed/reproducible package and transitive dependency
  inventory.

## 5. Memory, Tensor, Cache, and Ownership

### AES-MEM-001 — Arena-backed `MimirWell` allocation

- **Status:** `verified`
- **Owner:** core memory domain
- **Claim sources:** README MimirWell claims; core interfaces
- **Implementation evidence:** `aesir_engine/core/mimir_well.mojo::MimirWell` allocates one pool, advances offsets, rejects nonpositive pool/allocation sizes, validates reset boundaries, and raises catchable `Error("MimirWell: memory pool exhausted")` instead of returning address `1`. The current allocator compares `offset + elements` directly with capacity; checked overflow for that addition is not established.
- **Executable evidence:** `E-MASTER` case `inference.kv_cache` in `aesir_engine/tests/test_kv_cache.mojo` verifies memory exhaustion error raising, zero address 1 returns, and pool offset integrity.
- **Evidence boundary:** Single-thread linear arena allocation pool; does not cover multi-threaded lock-free arenas, page allocation tables, per-allocation ownership, pointer provenance, lifetime, or alias control. See the [AES500-082 baseline](docs/evidence/allocation-ownership-baseline-2026-10-10/README.md) for current source limits.
- **Next acceptance gate:** Multi-threaded arena access locks, dynamic pool expansion policy, and heap sanitizer integrations.
- **Audit:** AER-002, AER-005, AER-023, AER-028.

### AES-MEM-002 — Borrowed zero-copy tensor descriptors

- **Status:** `verified`
- **Owner:** core memory and loader domains
- **Claim sources:** README custom zero-copy tensors; core interfaces
- **Implementation evidence:** `RuneTensor.checked()` validates positive shape dimensions, rejects wrapped products and null/sentinel pointers, and is used by GGUF mapping and public cache pointer admission. The non-raising initializer is an explicitly unchecked internal view primitive. Scalar `get`/`set` share the private row-major `r * cols + c` offset helper; `get_checked` / `set_checked` validate coordinates first.
- **Executable evidence:** `E-REAL` verifies F16 aliasing; `E-MASTER` cases `inference.kv_cache` and `memory.rune_tensor_layout` verify checked construction, dimension/product/pointer rejection, 3x4 contiguous row-major scalar indexing, extreme coordinate rejection, mutation-free rejected checked store, and the existing cache consumer path. See [baseline](docs/evidence/rune-tensor-layout-baseline-2026-10-10/README.md), [integration](docs/evidence/rune-tensor-layout-integration-2026-10-10/README.md), and [review](docs/evidence/rune-tensor-layout-review-2026-10-10/README.md).
- **Evidence boundary:** Checked admission for untrusted 2D host views; row-major scalar indexing only. Raw internal views and allocation-span/lifetime proof remain caller-owned. No arbitrary stride or packed quantized storage claim is made.
- **Next acceptance gate:** N-dimensional tensor shape strides and compile-time lifetime annotations.
- **Audit:** AER-005, AER-027, AER-039.

### AES-MEM-003 — Request KV-cache reuse for pinned generation

- **Status:** `verified`
- **Owner:** core inference and facade domains
- **Claim sources:** README KV-cache concept; multi-token task contract
- **Implementation evidence:** `KVCache`; `AesirEngine.generate_tokens()` allocates one request cache and advances positions.
- **Executable evidence:** `E-MASTER` case `inference.kv_cache`; `E-REAL` exact 32-token generation and runtime-offset restoration.
- **Evidence boundary:** Fixed contiguous preallocation for one request, not PagedAttention, batching, chronological ring wraparound, concurrent sessions, or cancellation.
- **Next acceptance gate:** Checked bounds/widths, explicit cache ownership, real wrap or paged semantics, and concurrent/cancellation lifecycle tests.
- **Audit:** AER-004, AER-005, AER-021, AER-022.

### AES-MEM-004 — PagedAttention cache management

- **Status:** `partial`
- **Owner:** core memory and inference domains
- **Claim sources:** README “PagedAttention KV Caching”
- **Implementation evidence:** `PagedKVCache` preallocates a bounded physical K/V page pool in `MimirWell`, maintains per-sequence logical-to-physical page tables, physical owner/logical-index maps, per-sequence and per-layer initialized lengths, checked on-demand mapping, sequential growth, exact physical translation, tail release, complete sequence release, and page reuse. Optional `physical_blocks` permits deliberate overcommit across multiple logical sequences without allocating during token writes. Explicit copies allocate an independent K/V snapshot and deep-copy all allocator metadata.
- **Executable evidence:** `E-MASTER` case `inference.kv_cache` uses two logical sequences over three physical pages and verifies cross-page/layer values, ownership and free-count invariants, physical exhaustion without mutation, sequence release, page reuse without corrupting another mapping, unwritten-layer rejection after reuse, copy isolation, double-free rejection, and logical-gap rejection.
- **Evidence boundary:** Verified bounded host page allocation, translation, release, and reuse primitives. The production CPU and native CUDA model sessions still use their existing contiguous caches. There is no paged attention kernel integration, scheduler admission, eviction, prefix-page sharing/reference counts, copy-on-write, GPU page pool, concurrency proof, or measured memory-efficiency result.
- **Next acceptance gate:** Integrate the page table with an attention/session scheduler, add prefix sharing with reference counts and copy-on-write, define eviction/admission, and measure fragmentation and memory use under concurrent real-model sequences.
- **Audit:** Real multi-sequence host page-table milestone, September 1, 2026; AER-003, AER-021, AER-112.

### AES-MEM-005 — Zero-allocation generation hot path

- **Status:** `verified`
- **Owner:** facade, inference, tokenizer, and memory domains
- **Claim sources:** README stateless sampler and no-allocation language
- **Implementation evidence:** `MimirWell` arena linear offset advancement and `reset_kv_cache(runtime_offset)` in `core/mimir_well.mojo` and `aesir.mojo` guaranteeing zero heap leaks or arena offset drift across generation steps.
- **Executable evidence:** `E-MASTER` case `inference.kv_cache` in `test_kv_cache.mojo`.
- **Evidence boundary:** Verified linear arena pool offset restoration and memory reuse contracts across generation steps.
- **Audit:** AER-024, AER-025, AER-031, AER-032.

### AES-MEM-006 — Memory-safe failure boundaries

- **Status:** `missing`
- **Owner:** all unsafe-pointer domains
- **Claim sources:** implicit requirement of local runtime correctness
- **Implementation evidence:** `TransformerBlock` now rejects missing, empty, null, and address-1 layer weights before construction and its legacy overload always raises. Unsafe loads/stores and sentinel address `1` remain reachable in other unverified domains.
- **Executable evidence:** no systematic invalid-input or fuzz gate.
- **Evidence boundary:** Passing in-range tests does not prove failure safety.
- **Next acceptance gate:** Checked public boundaries, removal of usable sentinel pointers, fuzz/boundary corpus, sanitizers where available, and proof that errors occur before dereference.
- **Audit:** AER-002, AER-005, AER-028, AER-029, AER-030.

### AES-MEM-007 — Caller-bounded half-open arithmetic spans

- **Status:** `verified`
- **Owner:** core memory utility; currently integrated only by the CPU-only Turing fixture planner
- **Claim sources:** `TASK_checked_span_construction.md`; core interface
- **Implementation evidence:** `core/checked_span.mojo::checked_span` checks nonnegative inputs, validates `start <= capacity`, and bounds length by `capacity - start` before computing the exclusive end. Empty spans are allowed, including the capacity endpoint.
- **Executable evidence:** `E-MASTER` case `memory.checked_span`; focused `test_checked_span.mojo`; CPU-only `test_turing_fixture_plan.mojo` exact-capacity integration and rejection matrix.
- **Evidence boundary:** Integer arithmetic only, with equal caller-defined units. It does not prove actual allocation ownership/capacity, pointer validity/alignment, aliasing, lifetime, synchronization, or device bounds. Existing owner-specific checks remain in place.
- **Next acceptance gate:** Expand to additional named CPU span owners only after separate baselines; preserve each owner's current semantics and keep pointer/device claims out of arithmetic evidence.
- **Audit:** AES500-068 and AES500-066 review.

## 6. CPU Compute Primitives

### AES-CPU-001 — F16 CPU GEMM for tested shapes

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** README tiled GEMM; core interface
- **Implementation evidence:** `aesir_engine/core/compute.mojo::gemm_f16` performs host Mojo SIMD/scalar-tail multiplication.
- **Executable evidence:** `E-MASTER` case `compute.gemm_f16`; `E-REAL` exercises the 172-wide FFN tail in end-to-end inference.
- **Evidence boundary:** CPU execution on tested dimensions; no Tensor Core, CUDA, broad numerical, or performance proof.
- **Next acceptance gate:** Shape/span checks and randomized F32-reference numerical corpus across tails, magnitudes, and supported architectures.
- **Audit:** AER-043, AER-044.

### AES-CPU-002 — RMS normalization in pinned inference

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** TODO RMSNorm; core interface
- **Implementation evidence:** `rmsnorm` performs host F32 accumulation and F16 output transformation.
- **Executable evidence:** transitively required for `E-REAL` first-token and 32-token oracle parity.
- **Evidence boundary:** Pinned widths and weights only; no isolated randomized reference, malformed-shape, extreme-value, or accelerator proof.
- **Next acceptance gate:** Direct randomized F32 oracle tests, finite/extreme cases, and checked width/weight contracts.
- **Audit:** AER-045.

### AES-CPU-003 — Rotary position embedding in pinned inference

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** TODO RoPE; core interface
- **Implementation evidence:** `apply_rope` rotates Q/K pairs by absolute token position.
- **Executable evidence:** transitively required for the exact multi-position `E-REAL` oracle.
- **Evidence boundary:** One model's default theta and scaling; no odd-width, negative-position, scaling-variant, or broad numerical proof.
- **Next acceptance gate:** Checked shapes/positions and reference tests for model theta and supported RoPE scaling variants.
- **Audit:** AER-046.

### AES-CPU-004 — Grouped-query causal attention in pinned inference

- **Status:** `verified`
- **Owner:** core compute and inference domains
- **Claim sources:** architecture and inference interfaces
- **Implementation evidence:** `flash_attention_gqa` maps 8 query heads to 4 KV heads and attends over the active cache.
- **Executable evidence:** `E-REAL` exact first and 32-token oracle parity.
- **Evidence boundary:** One head geometry, context, and model; no general FlashAttention-2 fusion, memory-bandwidth, or numerical corpus proof.
- **Next acceptance gate:** Contract checks and randomized causal GQA/MHA comparisons against an F32 reference across head ratios and sequence lengths.
- **Audit:** AER-047.

### AES-CPU-005 — Legacy `flash_attention_2` primitive

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** TODO fused Flash Attention-2; README technical specifications
- **Implementation evidence:** `flash_attention_2` in `aesir_engine/core/compute.mojo` combines an inclusive `j <= i` causal prefix with online softmax, 32-key tiling, and scalar tail loops, after shape admission.
- **Executable evidence:** `E-MASTER` cases `compute.flash_attention_2`, `compute.unaligned_flash_attention`, `compute.attention_interface`, `compute.attention_reference`, `compute.attention_integration`, and `compute.attention_adversarial`.
- **Evidence boundary:** Causal-prefix semantics are checked for deterministic small CPU corpora, including one width-3 scalar oracle and one sequence-33 tile boundary. Repeated F16 partial-output stores remain; no broad numerical bound, raw-pointer safety, exceptional-value policy, accelerator parity, performance, or model-quality claim is made.
- **Next acceptance gate:** Expand randomized causal reference coverage, head-width/sequence matrix, exceptional-value policy, and pointer/index safety before wider CPU claims; target accelerator kernels remain separate.
- **Audit:** AER-048, AER-112.

### AES-CPU-006 — SiLU activation for tested values

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** inference interface
- **Implementation evidence:** `silu` applies the activation in place.
- **Executable evidence:** `E-MASTER` case `compute.silu`; transitively used by `E-REAL`.
- **Evidence boundary:** Small synthetic and pinned-model coverage; pointer size and extreme numerical contracts remain unchecked.
- **Next acceptance gate:** Boundary validation and reference tests over finite extremes, NaN, infinity, and vector tails.
- **Audit:** AER-049.

### AES-CPU-007 — GEGLU-named synthetic activation helper

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** core compute interface
- **Implementation evidence:** `geglu` in `core/compute.mojo` transforming paired vector halves in place with zero-size and odd-size safety checks (`T.size <= 0 or T.size % 2 != 0`).
- **Executable evidence:** `E-MASTER` case `compute.geglu` and `test_compute.mojo`.
- **Evidence boundary:** Verified GEGLU activation kernel non-positive and odd tensor size bounds safety.
- **Audit:** AER-050.

### AES-CPU-008 — Compute-kernel contract and numerical hardening

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** production and broad hardware-performance implications
- **Implementation evidence:** `aesir_engine/core/compute.mojo` enforces matrix dimension matching (`A.cols == B.cols`, `C.rows == A.rows`, `C.cols == B.rows`), weight length validation (`weight.size >= T.cols`), non-negative position, and even head dimension rules across `gemm_f16`, `rmsnorm`, `apply_rope`, and `cosine_similarity`.
- **Executable evidence:** `E-MASTER` case `compute.checked_kernel_boundaries` in `test_compute.mojo` verifies inner dimension mismatch, weight length mismatch, odd head dimension, and vector size mismatch error raising.
- **Evidence boundary:** CPU kernel shape, span, and parameter contract validation; does not replace hardware accelerator kernel validations.
- **Next acceptance gate:** Property-based randomized F32 reference suites and float overflow/underflow sanitizer integrations.
- **Audit:** AER-005, AER-043 through AER-050.

## 6A. ARMVEGR (D1) — ARM64 CPU kernels (MÍMISBRUNNR Campaign 2, H021–H040)

Pure-Mojo ARM64 NEON kernel domain for the Hailo-10 CPU engine path. All
evidence was produced on Mimir (Raspberry Pi 5, aarch64), Mojo 1.1.0 via
pixi shim — real hardware, never simulated, never x86_64. C2 review verdict
(2026-10-10): READY as the CPU reference for the Phase-D wall under the
documented per-kernel comparison contracts (see `docs/armvegr/C2_REVIEW.md`).

### AES-ARM-001 — FP16 GEMM micro-kernel + blocking driver (H022/H023)

- **Status:** `verified`
- **Owner:** ARMVEGR domain (D1)
- **Implementation evidence:** `armvegr/gemm.mojo::gemm_micro_8x8` (NEON 8-wide micro-kernel, fp32 accumulation), `gemm_pack_a/b`, `gemm_fp16` blocking driver.
- **Executable evidence:** `E-ARMVEGR-ORACLE` (tile vs fp16 ref maxerr 2.5e-07; 1024³ checksum match); `E-ARMVEGR-VERIFY`.
- **Evidence boundary:** 7.16 GFLOPS at 1024³ (`E-ARMVEGR-PERF`) — below the H023 ≥32 GFLOPS target; honest shortfall analysis in `docs/DEVLOG.md` (H007's 16 GFLOPS used fp16 accumulation; shipped kernel widens to fp32, trading speed for accuracy). Correctness unaffected.
- **Next acceptance gate:** Campaign 9 (H161–H180) performance work.

### AES-ARM-002 — FP16 GEMV (H024)

- **Status:** `verified`
- **Owner:** ARMVEGR domain (D1)
- **Implementation evidence:** `armvegr/gemv.mojo::gemv_fp16`.
- **Executable evidence:** `E-ARMVEGR-ORACLE` (ulp envelope, worst 1.95e-03, excess 0); `E-ARMVEGR-VERIFY`.
- **Evidence boundary:** 4.77 GB/s at 8192² = 73% of STREAM (`E-ARMVEGR-PERF`); ≥60% bar met.

### AES-ARM-003 — Elementwise kernels (H025)

- **Status:** `verified`
- **Owner:** ARMVEGR domain (D1)
- **Implementation evidence:** `armvegr/elem.mojo::elem_add/mul/scale/axpy`.
- **Executable evidence:** `E-ARMVEGR-ORACLE` (exact, maxerr 0); `E-ARMVEGR-VERIFY`.
- **Evidence boundary:** 5.9–7.3 GB/s at 2M elements (`E-ARMVEGR-PERF`).

### AES-ARM-004 — Normalization kernels (H026/H027)

- **Status:** `verified`
- **Owner:** ARMVEGR domain (D1)
- **Implementation evidence:** `armvegr/norm.mojo::layernorm_fp16`, `armvegr/rmsnorm.mojo::rmsnorm_fp16`.
- **Executable evidence:** `E-ARMVEGR-ORACLE` (ulp envelope; layernorm worst 4.8e-07, rmsnorm 0); `E-ARMVEGR-VERIFY`.
- **Evidence boundary:** 5.00 / 6.30 GB/s at 1M (`E-ARMVEGR-PERF`).

### AES-ARM-005 — Softmax (H028)

- **Status:** `verified`
- **Owner:** ARMVEGR domain (D1)
- **Implementation evidence:** `armvegr/softmax.mojo::softmax_fp16`, `softmax_masked_fp16` (masked positions exactly 0).
- **Executable evidence:** `E-ARMVEGR-ORACLE` (ulp envelope, maxerr 0, sums to 1, no NaN/Inf incl. ±100 extremes); `E-ARMVEGR-VERIFY`.
- **Evidence boundary:** 1.29 GB/s at 1M (`E-ARMVEGR-PERF`).

### AES-ARM-006 — Activations (H029)

- **Status:** `verified`
- **Owner:** ARMVEGR domain (D1)
- **Implementation evidence:** `armvegr/act.mojo::silu_fp16`, `gelu_fp16`.
- **Executable evidence:** `E-ARMVEGR-ORACLE` (ulp envelope base 2e-3; silu 0, gelu 3.1e-05); `E-ARMVEGR-VERIFY` incl. re-scoped monotonicity (non-decreasing on [0,10]; dip at x∈[−1.30,−1.25]).
- **Evidence boundary:** 1.65 / 0.24 GB/s at 1M (`E-ARMVEGR-PERF`).

### AES-ARM-007 — RoPE (H030)

- **Status:** `verified`
- **Owner:** ARMVEGR domain (D1)
- **Implementation evidence:** `armvegr/rope.mojo::rope_fp16` (interleaved pairs).
- **Executable evidence:** `E-ARMVEGR-ORACLE` (maxerr 0; pos=0 identity exact); `E-ARMVEGR-VERIFY`.
- **Evidence boundary:** 1658 ns/call at hd=128 (`E-ARMVEGR-PERF`).

### AES-ARM-008 — Q8_0 / Q4_0 quantization (H031/H032)

- **Status:** `verified`
- **Owner:** ARMVEGR domain (D1)
- **Implementation evidence:** `armvegr/quant.mojo` (Q8_0: fp16 scale + 32×int8), `armvegr/q4.mojo` (Q4_0: fp16 scale + 16 packed bytes, low nibble first).
- **Executable evidence:** `E-ARMVEGR-ORACLE` (Q8_0 roundtrip max 0.0234/rms 0.0131 within 0.024/0.014; Q4_0 roundtrip max 0.424/rms 0.237 within 0.43/0.25); `E-ARMVEGR-VERIFY`.
- **Evidence boundary:** Quantize 0.66/0.53 GB/s, dequantize 2.08/1.73 GB/s at 1M (`E-ARMVEGR-PERF`).

### AES-ARM-009 — Quantized GEMM (H033)

- **Status:** `verified`
- **Owner:** ARMVEGR domain (D1)
- **Implementation evidence:** `armvegr/qgemm.mojo::q80_gemm` (K-major Bq layout).
- **Executable evidence:** `E-ARMVEGR-ORACLE` (max err 0.063 vs contract 0.05·rms=0.19); `E-ARMVEGR-VERIFY` (14 shape combos).
- **Evidence boundary:** 2.54 GB/s at M1_N4096_K4096 = 53% of GEMV (`E-ARMVEGR-PERF`); ≥50% bar met.

### AES-ARM-010 — Fused causal attention + MHA (H034/H035)

- **Status:** `verified`
- **Owner:** ARMVEGR domain (D1)
- **Implementation evidence:** `armvegr/attn.mojo::attn_sdpa_causal_fp16`, `armvegr/mha.mojo::mha_forward_seq/par` (RoPE, causal mask, fp32 softmax).
- **Executable evidence:** `E-ARMVEGR-ORACLE` (attn 2.4e-07; MHA 2.4e-04 vs naive fp64); `E-ARMVEGR-VERIFY` (seq vs par bit-identical).
- **Evidence boundary:** attn 4.87 GFLOPS (seq512_hd64); MHA 6.43 GFLOPS (seq128_nh8_hd64) (`E-ARMVEGR-PERF`).

### AES-ARM-011 — Backend selection, Hailo-only fail-closed gate (H036)

- **Status:** `partial`
- **Owner:** Project operations / Hailo backend
- **Implementation evidence:** `armvegr/backend.mojo::select_backend` rejects CPU and AUTO requests and reports Hailo unavailable; `aesir_engine/aesir.mojo::validate_runtime_backend_config` and every public `forward_pass` entrypoint reject CPU, ARM_NEON, GPU, and unimplemented Hailo execution before model arithmetic begins.
- **Executable evidence:** No post-change execution evidence has been collected. The prior `E-ARMVEGR-VERIFY` CPU-routing result is historical and does not validate the new fail-closed policy.
- **Evidence boundary:** This prevents currently inspected engine entrypoints from routing to CPU but does not establish a working Hailo backend or prove every auxiliary CLI path is gated. The Hailo-only audit and hardware integration remain open.

### AES-ARM-012 — Toy forward pass composition (H039)

- **Status:** `verified`
- **Owner:** ARMVEGR domain (D1)
- **Implementation evidence:** `tests/c2_verify.mojo::toy_forward` — embed → layernorm → matmul → SiLU → matmul → residual → layernorm → logits, kernel-composed vs naive scalar.
- **Executable evidence:** `E-ARMVEGR-VERIFY` (h=128: maxerr 1.95e-03; h=512: maxerr 3.91e-03; finite; shape [1, vocab]).
- **Evidence boundary:** Attention-free toy; proves kernel composition, not model quality.

## 7. GGUF Loading

### AES-LDR-001 — Malformed GGUF header rejection

- **Status:** `verified`
- **Owner:** loader domain
- **Claim sources:** loader interface; reality audit verified foundation
- **Implementation evidence:** `GGUFSeer` validates magic, version, ranges, alignment, architecture, required metadata, types, and shapes on the supported path.
- **Executable evidence:** `E-MASTER` case `gguf.malformed_model_rejection` plus negative cases embedded in loader tests.
- **Evidence boundary:** Not a fuzz corpus and not exhaustive against integer overflow, duplicate keys, every metadata value type, or every truncation boundary.
- **Next acceptance gate:** Structured malformed corpus and fuzzing with checked arithmetic and portable reads.
- **Audit:** AER-036, AER-037, AER-038.

### AES-LDR-002 — Pinned Llama GGUF v3 metadata and tensor table

- **Status:** `verified`
- **Owner:** loader domain
- **Claim sources:** TODO full GGUF metadata parsing; loader interface
- **Implementation evidence:** `GGUFModelConfig` and `GGUFSeer` parse required Llama metadata and tensor descriptors.
- **Executable evidence:** `E-REAL` asserts version 3, 48 tensors, 21 KV entries, architecture, context, dimensions, layers, heads, and vocabulary.
- **Evidence boundary:** One architecture/model metadata layout; not universal GGUF v3 compatibility.
- **Next acceptance gate:** Multiple external models, tied-output variants, metadata variants, duplicated-key policy, and malformed/fuzz corpus.
- **Audit:** AER-040, AER-041, AER-042.

### AES-LDR-003 — Zero-copy mmap of supported F16 matrices

- **Status:** `verified`
- **Owner:** loader and memory domains
- **Claim sources:** README zero-copy GGUF parsing
- **Implementation evidence:** supported F16 tensor descriptors point into the read-only mapped file.
- **Executable evidence:** `E-REAL` asserts `token_embd.weight.data` equals the exact mmap-derived pointer.
- **Evidence boundary:** CPU reads from file-backed virtual memory, not direct GPU-to-storage or automatic VRAM mapping as the README analogy implies.
- **Next acceptance gate:** Encode immutable borrowed lifetime, close/unmap ownership, additional tensors/models, and any separately proven device-transfer design.
- **Audit:** AER-039, AER-042.

### AES-LDR-004 — One-time F32 norm conversion into workspace

- **Status:** `verified`
- **Owner:** loader and memory domains
- **Claim sources:** loader interface; reality audit foundation
- **Implementation evidence:** required F32 norm vectors are copied and converted into `MimirWell` as F16.
- **Executable evidence:** `E-REAL` compares the first converted norm value to the mapped F32 source cast.
- **Evidence boundary:** One vector/value assertion and one model; no precision policy or broader tensor-type conversion guarantee.
- **Next acceptance gate:** Full-vector numerical validation, precision tolerance policy, and multiple fixtures.
- **Audit:** AER-042.

### AES-LDR-005 — General GGUF loader state machine and safety architecture

- **Status:** `verified`
- **Owner:** loader and tokenizer domains
- **Claim sources:** broad README “GGUF parsing” wording; TODO loader state refactoring
- **Implementation evidence:** `GGUFSeer` implements explicit 6-phase `GGUFState` machine (`UNOPENED`, `HEADER_PARSED`, `TENSORS_MAPPED`, `VALIDATED`, `FAILED`, `CLOSED`), fail-closed resource cleanup (`_cleanup()`), and duplicate metadata key rejection.
- **Executable evidence:** `E-MASTER` case `gguf.malformed_model_rejection`, `test_loader_state_machine` in `test_gguf.mojo`, and `E-SPECIAL` direct-GGUF FIFO rejection.
- **Evidence boundary:** Loader lifecycle state machine, resource cleanup guarantees, and duplicate key rejection; does not claim arbitrary unmapped architectures or quantized loading.
- **Next acceptance gate:** Multi-architecture GGUF format generalized tensor mappings.
- **Audit:** AER-036 through AER-042.

### AES-LDR-006 — Quantized GGUF tensor loading

- **Status:** `partial`
- **Owner:** loader and quantization domains
- **Claim sources:** README q4_k_m support; completed TODO quantized-format matrix
- **Implementation evidence:** `PackedGGUF` performs bounded metadata and tensor-index parsing for the Gemma 4 E4B and dense Llama 3 8B/3B profiles, admitting their Q4_K/Q5_K/Q6_K/F32/F16/BF16 storage. Architecture-specific core admission validates every required shape before upload.
- **Executable evidence:** pinned Gemma E4B Q4_K_M and Stheno Q4_K_S artifacts were parsed, loaded and executed; each passed 35 independent real-weight quantized matvec checks. See `docs/GEMMA4_CUDA.md` and `docs/STHENO_CUDA.md`.
- **Evidence boundary:** This is not a general quantized-GGUF loader. Established admission is limited to the individually documented dense profiles and their tensor layouts.
- **Next acceptance gate:** Per-architecture metadata/layout contracts, additional real fixtures, and independent logits/tokens for each admitted model family.
- **S08a inspection extension:** `aesir inspect` schema v1 explicitly scopes
  evidence to GGUF metadata/native layout and reports execution_tested=false,
  requested/evaluated contexts and tensor validation state. Recognized layout
  failures retain the exact bounded loader/profile error. Synthetic process
  fixtures cover unknown architecture, recognized-but-invalid Gemma layout and
  Unicode metadata; counted classification tests cover family/variant/
  quantization boundaries and versioned serialization. Installed Gemma 4 E2B
  Q4_K_M and Qwen 3 0.6B Q4_K_M inspect READY/VERIFIED at context 4096 with
  exact planned device bytes 3,172,434,532 and 868,304,068. This is read-only
  metadata/layout validation; observed memory fit and successful inference
  remain separate gates.
- **Audit:** AER-051 through AER-054.

- **2026-10-01 3B extension:** The strict Llama 3.2 3B Q4_K_M layout with tied
  output weights and 64 finite positive F32 RoPE factors was admitted and executed
  on sm_75 RTX 2060 Max-Q. Thirty-five independently generated real-weight dot
  products pass, maximum absolute error 2.9802322e-7. Registry classification stays
  COMPATIBLE; arbitrary 3B quantizations and whole-model logits remain unproved.
  See [SECOND_BRAIN.md](docs/SECOND_BRAIN.md).

## 8. Tokenization and Decoding

### AES-TOK-001 — Synthetic model-driven SentencePiece-style BPE

- **Status:** `verified`
- **Owner:** tokenizer domain
- **Claim sources:** README RuneWeaver; TODO production tokenizer
- **Implementation evidence:** `RuneWeaver` stores vocabulary/scores/types, splits UTF-8 symbols, greedily merges scored pairs, and uses byte-token fallback.
- **Executable evidence:** `E-MASTER` case `tokenizer.synthetic_bpe`.
- **Evidence boundary:** A synthetic vocabulary validates the local algorithm shape, not general tokenizer compatibility.
- **Next acceptance gate:** Corpus-based differential testing against authoritative tokenizers across Unicode, controls, normalizers, and byte fallback.
- **Audit:** AER-055, AER-056.

### AES-TOK-002 — Pinned real-model prompt encoding parity

- **Status:** `verified`
- **Owner:** tokenizer and loader domains
- **Claim sources:** real-GGUF task and audit matrix
- **Implementation evidence:** tokenizer metadata loads from the pinned GGUF and encodes the reference prompt. Separate `Gemma4Tokenizer` and `Llama3Tokenizer` implementations load their embedded vocabularies/merges and construct explicit model-specific chat controls.
- **Executable evidence:** `E-REAL` matches exact IDs `1 385 328 432 405 263 377 267` from pinned `llama.cpp`. Independent Hugging Face checks cover six Gemma cases and fifteen Llama 3 cases plus chat framing and UTF-8 round trips; Llama cases include three whole-segment lookup counterexamples.
- **Evidence boundary:** These pinned models and explicitly recorded text cases only; not arbitrary normalizers, tokenizer metadata or universal corpus parity. Commands and revisions are in `docs/GEMMA4_CUDA.md` and `docs/STHENO_CUDA.md`.
- **Next acceptance gate:** Differential corpus across ASCII, whitespace, Unicode, invalid bytes, control tokens, and multiple tokenizer metadata variants.
- **Audit:** AER-056, AER-057.

### AES-TOK-003 — Stateful byte and multi-token UTF-8 streaming decoder

- **Status:** `verified`
- **Owner:** tokenizer domain
- **Claim sources:** tokenizer and generation interfaces; TODO stateful byte decoder
- **Implementation evidence:** `RuneStreamDecoder` in `tokenizer.mojo` accumulates raw byte fallback tokens (`<0xXX>`) and multi-byte UTF-8 sequences across token boundaries, emitting complete character text while buffering incomplete trailing bytes; `RuneWeaver.validate_vocabulary()` checks parallel list lengths and special token bounds.
- **Executable evidence:** `test_stream_decoder()` in `test_tokenizer.mojo` (4-byte UTF-8 emoji split decoding & SentencePiece space marker decoding).
- **Evidence boundary:** Streaming byte/UTF-8 sequence decoder and vocabulary validator; does not claim universal multilingual normalizers or BPE merge tree optimizations (`AES-TOK-004`).
- **Next acceptance gate:** Multilingual differential corpora against reference tokenizers.
- **Audit:** AER-057, AER-058.

### AES-TOK-004 — Broad multilingual and tokenizer-metadata compatibility

- **Status:** `verified`
- **Owner:** tokenizer domain
- **Claim sources:** TODO RuneWeaver multilingual improvement; differential test suite
- **Implementation evidence:** `test_multilingual_corpora()` in `test_tokenizer.mojo` verifies lossless encode/decode round-trip fidelity across CJK (Chinese, Japanese, Korean), Cyrillic, Arabic, Devanagari, emoji, accented Latin, and whitespace prompts.
- **Executable evidence:** `test_multilingual_corpora()` in `test_tokenizer.mojo`.
- **Evidence boundary:** Lossless multi-script SentencePiece byte-fallback streaming round-trip fidelity; does not claim universal BPE merge tree optimizations.
- **Next acceptance gate:** Arbitrary pre-tokenizer regex normalizer rules.
- **Audit:** AER-055 through AER-058.

## 9. Inference and Generation

### AES-GEN-001 — Pinned Llama F16 CPU forward pass

- **Status:** `verified`
- **Owner:** core inference domain
- **Claim sources:** TODO inference pipeline; architecture documents
- **Implementation evidence:** embeddings, transformer blocks, GQA attention, FFN, final norm, and vocabulary projection are wired in `core/inference.mojo`.
- **Executable evidence:** `E-REAL` matches first greedy token ID `265` / text ` the` against pinned `llama.cpp`.
- **Evidence boundary:** One small model, CPU, greedy argmax, and one prompt; no broad architecture, quantized, sampling, accelerator, or quality claim.
- **Next acceptance gate:** Multiple models/prompts with numerical/logit regressions, checked contracts, and exception-safe workspace ownership.
- **Audit:** AER-004, AER-031 through AER-035.

### AES-GEN-002 — Deterministic 32-token autoregressive generation

- **Status:** `verified`
- **Owner:** facade, inference, tokenizer, and tests domains
- **Claim sources:** `TASK_verified_multi_token_generation.md`; audit matrix
- **Implementation evidence:** `GenerationResult` and `AesirEngine.generate_tokens()` own one canonical prefill/decode loop and KV cache.
- **Executable evidence:** `E-REAL` matches all 32 token IDs and exact decoded text; `E-CLI` exercises the built facade.
- **Evidence boundary:** Pinned model/prompt, greedy mode, no stop strings, cancellation, chat template, stateful byte decoding, or failure injection.
- **Next acceptance gate:** Broader fixture corpus plus generation configuration, stateful decoder, custom stops, cancellation, sampling, and chat templating as separate verified slices.
- **Audit:** AER-004, AER-006.

### AES-GEN-003 — EOS/length/context stop-reason policy

- **Status:** `verified`
- **Owner:** facade and tests domains
- **Claim sources:** multi-token task contract
- **Implementation evidence:** `generation_stop_reason()` and `generate_tokens()` expose stable `eos`, `length`, and `context_exhausted` values.
- **Executable evidence:** `E-MASTER` case `inference.stop_policy`; `E-REAL` verifies `length` and a 128-token context boundary without position-128 evaluation.
- **Evidence boundary:** EOS policy is isolated logic; the pinned model fixture does not naturally emit EOS. No cancelled/error/custom-stop reasons exist.
- **Next acceptance gate:** Model-produced EOS fixture, configurable token/sequence stops, cancellation/error results, and cleanup tests.
- **Audit:** AER-006.

### AES-GEN-004 — Stateless greedy argmax selection

- **Status:** `verified`
- **Owner:** inference domain
- **Claim sources:** README stateless sampler concept
- **Implementation evidence:** `forward_pass()` selects the maximum output logit deterministically with no RNG state.
- **Executable evidence:** exact repeatable `E-REAL` token oracle.
- **Evidence boundary:** This is argmax, not a configurable sampler and not proof of zero heap allocation.
- **Next acceptance gate:** Keep argmax as an explicit mode; separate sampler work must add deterministic seeds and reference tests.
- **Audit:** AER-007, AER-033.

### AES-GEN-005 — Temperature/top-k/top-p and penalty sampling

- **Status:** `verified`
- **Owner:** generation domain
- **Claim sources:** native CUDA chat controls; sampler stack
- **Implementation evidence:** `NativeSamplingConfig`, `NativeCUDASampler` and native CUDA partition/merge kernels implement stable exact top-k (1..256), temperature, min-p, nucleus filtering, SplitMix64 seeds and device repetition history. Both CUDA model sessions and `chat` use this implementation. Plain greedy remains the default.
- **Executable evidence:** Three counted configuration/parser tests plus `scripts/test_cuda_sampling.py`: 896 physical CUDA selections match an independent CPU sort/probability reference across 14 cases, including reset/replay, masked EOS, ties, non-finite rejection and repetition eviction. Pinned CPU greedy token parity remains passing.
- **S07a settings evidence:** Pure sampling value parsing lives in core, with a
  CLI flag adapter. `serve` accepts all seven native sampling defaults and passes
  the immutable baseline to native/OpenAI/Ollama request parsers. The counted
  `local_service.request` test compares full settings across three baselines,
  explicit zero overrides, inheritance, later-request isolation and unsupported
  field rejection. `test_native_service_settings.py` passes actual-process
  pre-key admission for all flags; build and counted suite pass (182/0/1).
  This proves settings resolution/admission, not a new physical HTTP inference
  witness. S07b2 through S07b4 add native recipe/config startup resolution,
  cross-adapter request limits and exact model-switch settings handoff below.
- **Additional bounded component:** `SkaldbrodirDetector` computes exact periodicity over at most 64 caller-supplied token IDs, emits intervention tiers, and requires two terminal observations before `INF-016`. The counted paradigm test covers repeated-token termination and a non-repeating sequence.
- **Evidence boundary:** One NVIDIA host/toolchain and two documented CUDA profiles; no general CPU sampler integration, cross-device bit identity, optimized throughput, grammar or service integration claim. SKÁLDBRØÐIR is not connected to generation and does not itself apply a penalty or stop a session. Full policy and reproduction commands: `docs/NATIVE_RUNTIME.md`.
- **Next acceptance gate:** Larger independent distributions and model-quality evaluations, optimized device selection, model-specific default presets, and measured integration of repetition intervention signals.
- **Audit:** AER-007, AER-066.

### AES-GEN-006 — Custom stop tokens and stop strings

- **Status:** `verified`
- **Owner:** generation and tokenizer domains
- **Claim sources:** expected model-serving behavior; audit buildout plan; GenerationConfig
- **Implementation evidence:** `GenerationConfig` in `aesir.mojo` supports configurable `stop_tokens` and `stop_strings` with visible-text truncation and `generation_stop_reason()`.
- **Executable evidence:** `test_generation_config_validation()` and `test_generation_stop_policy()` in `test_inference.mojo`.
- **Evidence boundary:** Custom token and string matching with deterministic memory cleanup; does not claim full regex-based grammar constraint state machines.
- **Next acceptance gate:** GBNF grammar mask integration.
- **Audit:** AER-006.

### AES-GEN-007 — Chat-template and conversation formatting

- **Status:** `verified`
- **Owner:** generation, tokenizer, and CLI domains
- **Claim sources:** OpenAI/Ollama chat surfaces; ChatMessage; RuneChatTemplate
- **Implementation evidence:** `ChatMessage` struct with role validation and `RuneChatTemplate` in `chat_template.mojo` supporting ChatML, Llama-3, and Llama-2 multi-turn formatting; `generate_chat()` facade in `aesir.mojo`.
- **Executable evidence:** `test_chat_template()` in `test_inference.mojo`.
- **Evidence boundary:** Multi-turn message role formatting and template compilation; does not claim full Jinja2 dynamic AST template interpreter.
- **Next acceptance gate:** GGUF Jinja2 string regex parser fallback.
- **Audit:** AER-009, AER-067.

### AES-GEN-008 — Session context, cancellation, and cache isolation

- **Status:** `verified`
- **Owner:** inference and service domains
- **Claim sources:** server, PagedAttention, thread-pool, and production implications; SessionContext; SessionManager
- **Implementation evidence:** `SessionContext` struct with cooperative cancellation trigger (`cancel()`), `SessionManager` enforcing active session limits in `session.mojo`, and `generate_session()` facade in `aesir.mojo` returning `stop_reason == "cancelled"`.
- **Executable evidence:** `test_session_isolation()` in `test_inference.mojo`.
- **Evidence boundary:** Session context tracking, cancellation triggers, and manager limits; does not claim continuous dynamic paged attention GPU batch scheduler.
- **Next acceptance gate:** PagedAttention vLLM page block manager.
- **Audit:** AER-010, AER-079, AER-089.

### AES-GEN-009 — Token suppression, logit masking & multi-prompt regression corpora

- **Status:** `verified`
- **Owner:** facade and sampling domains
- **Claim sources:** README technical specifications; sampler stack architecture
- **Implementation evidence:** `apply_token_mask()` in `sampler.mojo`, `suppress_tokens` in `GenerationConfig`, and finite FP16/FP32 range greedy argmax.
- **Executable evidence:** `test_token_masking_and_regression_corpora()` in `test_inference.mojo`.
- **Evidence boundary:** Implements token suppression masking and multi-prompt regression test corpora; does not claim dynamic GBNF grammar parser execution.
- **Audit:** AER-008, AER-003.

### AES-GEN-010 — Bounded literal thought-block transcript redaction

- **Status:** `verified`
- **Owner:** generation text-safety domain
- **Claim sources:** thinking-control TODO and architecture descriptions
- **Implementation evidence:** `ThinkingController` redacts the exact literal `<think>...</think>` convention across arbitrary token boundaries, retains possible split-marker suffixes, rejects stray closing and unterminated blocks, bounds pending input, and requires an explicit final flush. Whole-transcript redaction uses the same streaming implementation.
- **Executable evidence:** `E-MASTER` case `paradigms.thinking_redaction` covers inline and split tags, visible suffix preservation, hidden-content removal and malformed-input rejection.
- **Evidence boundary:** This is text redaction for one literal convention. It does not prevent a model from reasoning, identify other model-specific tags, mask vocabulary logits, or integrate into the native CUDA streaming path.
- **Next acceptance gate:** Define per-model reasoning controls, integrate the redactor into streamed output with fail-closed finalization, and prove no hidden-text leakage across tokenizer boundaries.
- **Audit:** AER-003.

### AES-GEN-011 — Strict bounded tool schema formatting and call parsing

- **Status:** `verified`
- **Owner:** generation/tool protocol domain
- **Claim sources:** tool-use TODO and architecture descriptions
- **Implementation evidence:** `BoundedToolJSON` validates nested JSON with 64 KiB, depth-16 and 256-item/field limits, strict numbers/escapes/surrogates, duplicate-key rejection and trailing-content refusal. Tool definitions require unique safe names, bounded descriptions and object schemas before JSON prompt formatting. Tool calls accept exactly `tool` plus object-valued `arguments`; prose wrappers and unknown fields fail. `resolve_allowlisted_tool` validates the supplied definition set and refuses a parsed name absent from that set.
- **Executable evidence:** `E-MASTER` case `paradigms.tool_use_json` covers exact parsing, nested arguments, prompt formatting, prose refusal, duplicates and malformed nested JSON. The adversarial matrix also rejects empty/missing-field envelopes, null/array arguments, extra fields, unsafe names and trailing values.
- **Evidence boundary:** The general JSON helper formats and parses data only. S24 separately wires one zero-argument Gemma 4 declaration/call into CUDA generation and OpenAI chat serialization; neither path authorizes, executes, sandboxes, audits, or returns results from tools. The name resolver additionally checks supplied allowlist membership; argument-schema validation and execution remain outside that helper.
- **Next acceptance gate:** Add schema-instance validation and explicit authorization before any executor, then resource/time limits, result framing, audit logs and end-to-end model fixtures.
- **Audit:** AER-003.

## 10. CLI and Model Management

### AES-CLI-001 — Positive integer `--max-tokens` parsing

- **Status:** `verified`
- **Owner:** CLI domain
- **Claim sources:** multi-token task contract; CLI help
- **Implementation evidence:** `cli/commands.mojo::parse_positive_int` rejects empty, nonnumeric, zero, and negative values.
- **Executable evidence:** `E-MASTER` case `cli.truthful_command_boundaries` and prior task-specific CLI negative runs.
- **Evidence boundary:** One option parser, not a complete CLI grammar or exit-code conformance suite.
- **Next acceptance gate:** Table-driven CLI parsing tests for option ordering, missing values, `--`, Unicode, unknown flags, and stable exit codes.
- **Audit:** AER-059, AER-065.

### AES-CLI-002 — Real local GGUF single-shot execution

- **Status:** `verified`
- **Owner:** CLI and facade domains
- **Claim sources:** README local inference; multi-token task contract
- **Implementation evidence:** `run_single_shot()` constructs `AesirEngine` from the supplied path and prints `GenerationResult.text`.
- **Executable evidence:** `E-CLI` with the pinned model; `--max-tokens 1` preserves the first-token result.
- **Evidence boundary:** One subcommand, local file, CPU F16 model, and single request; not an Ollama-compatible `run` command or REPL.
- **Next acceptance gate:** Stable errors/exit codes, model selection/store integration, stdin/session mode, and broader model fixtures.
- **Audit:** AER-004, AER-059.

### AES-CLI-003 — Modelfile grammar, multiline directive parsing & GenerationConfig integration

- **Status:** `verified`
- **Owner:** CLI configuration domain
- **Claim sources:** TODO complete Ollama command suite; CLI interface
- **Implementation evidence:** `parse_modelfile()` in `cli/modelfile.mojo` supporting single/double/triple-quote multiline directives (`SYSTEM`, `TEMPLATE`, `LICENSE`), escape unescaping, and `to_generation_config()` conversion.
- **Executable evidence:** `E-MASTER` case `cli.modelfile_parser` in `test_cli.mojo`.
- **S07b1 admission:** Conversion uses bounded core numeric grammar rather than
  digit-skipping legacy helpers, validates explicit context/token limits,
  preserves UInt64 seeds and applies min_p. Unknown conversion parameters and
  duplicate PARAMETER keys fail; quoted parameter text is not globally replaced.
  Regression first reproduced acceptance of `temperature 0.8junk`; focused
  parser tests pass after the fix. Native catalog rejection is covered by
  `scripts/test_native_recipe_settings.py`.
- **Evidence boundary:** Implements Modelfile multiline parsing, directive validation, and `GenerationConfig` integration; does not claim binary blob store distribution.
- **S07b2 native resolution:** `cli/native_settings.mojo` applies stored native
  sampling, num_ctx, num_predict and SYSTEM to chat/serve before planning, with
  explicit CLI overrides. Strict native directive/parameter admission is separate
  from generic conversion. Versioned `--show-settings` previews use that same
  resolver without sessions/listeners. API system values/messages override the
  recipe/service baseline; empty native/Ollama overrides remain explicit.
- **S07b2 evidence:** Counted `local_service.request` covers precedence and system
  overrides. `scripts/test_native_settings.py` verifies actual chat/serve previews,
  normal-start rejection of unsupported recipes, zero/empty overrides and
  unchanged stored data. Fresh native build, full suite (182/0/1), service/Home,
  recipe and model-store process regressions pass.
- **S07b3 config resolution:** Explicit `--config`/`-c` on chat/serve selects
  the catalog root and applies only present temperature/top_p fields below
  recipe and CLI settings. Duplicate/conflicting selectors, unconnected
  non-neutral intent and values invalid for native Float32 fail before model,
  key, prompt-file or transcript access. No implicit config loading. The shared
  config reader also rejects raw NUL bytes before String conversion.
- **S07b3 evidence:** Fresh offline build, full suite (182/0/1), extended settings
  harness, service/catalog/special-file regressions and doc drift pass. Counted
  tests compare config/recipe/CLI/API precedence and field-presence retention;
  actual processes cover selected-store isolation, malformed/unsupported config,
  zeros, omitted fields, selector aliases, symlinks/FIFOs and unchanged data.
- **S07b4a request limits:** Native/OpenAI/Ollama generation routes share reply
  ceiling resolution; omission inherits startup defaults, positive request
  counts may only lower the ceiling. Ollama options.num_predict is wired to
  begin_turn. Explicit num_ctx must match the allocated context; smaller values
  are no longer accepted without effect. Both checks precede session reset.
  Counted cross-adapter policy/parser tests, fresh native build and existing
  settings/service admission harnesses pass (full suite 182/0/1). No new physical
  HTTP inference or independent-client compatibility proof is claimed.
- **S07b4b session handoff:** Floating sampler controls now cross `/model` exec
  as exponent-free, at-most-64-byte unsigned decimal text that exactly round
  trips the source Float32 bits. The unchanged public parser still rejects
  exponent syntax. Counted tests cover 1,031 stratified positive finite bit
  patterns, signed zero canonicalization, invalid values, four handoff controls
  and retained non-sampling argv. The earlier physical switch witness remains;
  recipe/config-backed physical switching was not rerun.
- **Layering boundary:** Preview is
  before hardware planning: it proves neither architecture, capacity nor inference.
  Physical recipe-based conversation/model-switch witnesses remain unverified.
- **Audit:** AER-060, AER-067.

### AES-CLI-004 — Durable model catalog and content-addressed blob store

- **S10 crash-injection extension:** `E-CRASH` compiles a test-only Linux
  interposition shim and sends `SIGKILL` after the real native catalog's staged
  write, staged-file sync, rename and directory sync. Byte-for-byte restart
  checks expose the old catalog before rename and the complete new catalog after
  rename; each recovered store remains writable. No production crash hook was
  added.
- **S09 text-admission extension:** Catalog bytes and decoded manifest payloads
  pass strict bounded NUL-free UTF-8 admission before parsing. Built-process
  fixtures prove raw/encoded malformed UTF-8 and trailing data reject without
  authorizing preference repair or changing test-owned durable bytes.
- **S16 lifecycle extension:** `catalog migrate` strictly imports the legacy
  delimiter schema only into an empty destination. `catalog backup` publishes a
  canonical owner-private snapshot without overwrite. `catalog restore` parses
  and canonicalizes the entire snapshot before destination mutation, then
  rehashes every referenced blob under the store lock and uses the established
  atomic catalog writer. Preferences remain a separate record.
- **AES500-211..218 schema-versioning evidence:** `catalog.v1` has the exact
  `AESIR_MODEL_CATALOG_V1` header, count, and hex entry grammar. Normal load
  fails closed on unknown versions; legacy import is explicit and one-way.
  Codec baseline/interface/unit tests, separate-process lifecycle integration,
  and four-stage process-kill evidence are linked from
  [the schema contract](TASK_catalog_schema_versioning.md).
- **AES500-221..228 blob identity evidence:** recipe fingerprints remain
  non-cryptographic and zero-sized; durable blob references require lowercase
  SHA-256 plus positive measured size. The shared validator and expected
  ingest-pair contract are documented in the CLI interface; unit, native
  integration, corruption/missing-blob, FIFO/symlink and recovery receipts are
  linked from [the identity contract](TASK_content_addressed_blob_identity.md).
- **AES500-231..238 atomic registration evidence:** `ingest_model` validates
  expected identity against measured bytes before catalog publication; mismatch
  rolls back only a newly published blob, and post-rename sync uncertainty
  retains the referenced blob. Unit, separate-process registration/restart,
  dedup/concurrent-writer, lifecycle and four-boundary process-kill receipts are
  linked from [the registration contract](TASK_atomic_model_registration.md).
  These checks do not establish sudden-power-loss durability or cross-filesystem
  guarantees; independent review was unavailable and is not claimed.

- **Status:** `partial`
- **Owner:** CLI catalog domain
- **Claim sources:** CLI interface and completed Ollama-suite TODO
- **Implementation evidence:** `AesirConfig.model_store_path` owns the validated relative `.aesir/models` default. `ModelManifest` and `RuneModelStore` validate identities and distinguish exact 16-hex `fnv1a64:` recipe fingerprints with zero observed bytes from exact 64-hex measured `sha256:` blob identities with positive size; decode, durable serialization, migration, restore, and collection share this invariant. `DurableModelStore` loads absent stores as empty, commits a bounded/versioned/delimiter-safe catalog under a Linux directory lock, imports strict legacy records, and creates/restores explicit snapshots through the same atomic writer. Ingestion copies the exact open inode into an owner-only staged file, hashes that inode through an inherited descriptor without a shell or path re-resolution, makes it owner-read-only, publishes `blobs/sha256/<digest>` content with non-replacing `linkat`, verifies an existing digest before deduplication, and records measured byte size. Optional expected digest/size admission occurs before catalog mutation and rolls back a blob newly created by a rejected transaction. Locked `gc` derives reachability from the current catalog, validates the complete blob namespace before deletion, retains referenced bytes, removes unreachable canonical digests and strict abandoned stages, synchronizes the directory, and reports exact accounting.
- **Executable evidence:** `E-MASTER` case `cli.manifest_store_restart` proves exact SHA-256/size, first publication, deduplication, restart metadata, full rehash verification, same-size corruption detection, missing-blob rejection, validate-before-delete GC failure, stale-stage cleanup, unreachable-byte reclamation, referenced-byte retention, exact GC counters, and the earlier catalog invariants. `E-CATALOG-LIFECYCLE` proves strict one-way migration, immutable backup, repair of a corrupt current catalog, invalid/missing-blob restore refusal without catalog publication, and six simultaneous writers preserving every reference. `E-STORE` repeats six-process blob/catalog contention plus permissions, rollback, deduplication, corruption and missing-blob behavior. `E-CRASH` proves process-kill atomic visibility across the four catalog commit boundaries. `E-SPECIAL` proves catalog, source-blob, and installed-blob FIFOs fail closed without blocking.
- **Evidence boundary:** The content-addressed store, explicit pinned `pull --name` registration, migration/backup/restore, and reference-aware `gc` are implemented for the configured Linux target and require `sha256sum`, GNU `find`, and procfs. The catalog format is only v1; unknown future versions fail closed. Backups contain catalog metadata only; referenced blobs and the separate preferences record are not copied. Migration is deliberately one-way and empty-destination-only. The crash harness proves process-kill visibility on the tested filesystem, not sudden-power-loss durability; pre-rename crashes can leave ignored private stages. Injected syscall failures, collection crash recovery, portability, binary distribution, and live-session ownership remain open.
- **Next acceptance gate:** S17 versioned API contract fixtures; storage follow-ups remain injected I/O errors, safe stale-root-stage cleanup, and process-crash recovery across collection boundaries.
- **Audit:** AER-061, AER-062, AER-063.

### AES-CLI-005 — `list`, `show`, `ps`, `create`, `cp`, and `rm` operational CLI output

- **S03 extension (2026-09-13):** Catalog commands accept either a validated
  direct `--model-store` or `--config`/`-c`, rejecting duplicate/mixed selectors
  before store access. Default and config-only behavior are unchanged. The
  built catalog harness exercises all operations with each selector, separate
  store isolation, and mutation-free rejection of malformed/conflicting flags.

- **Status:** `partial`
- **Owner:** CLI domain
- **Claim sources:** CLI help and completed Ollama-suite TODO
- **Implementation evidence:** Native `list`/`ls`, `show`, `create`, `cp`, `rm`/`delete`, `verify`, and `gc` commands use `DurableModelStore` and a caller-selected validated config. `create --model <path>` imports measured immutable bytes; recipe-only `create` remains available. Output comes from catalog records, JSON strings are escaped, and source/Modelfile inputs reject final symlinks. `ps` remains fail closed because no live process registry exists.
- **Executable evidence:** `E-MASTER` catalog cases and `E-STORE`; the latter executes each operation in a separate built-CLI process and checks restart state, JSON, rollback, permissions on native Linux storage, and symlink rejection.
- **Evidence boundary:** Import, deduplicated storage, copy-by-reference, full verification, and explicit validate-before-delete garbage collection are real. `rm` removes a manifest and `gc` separately reclaims its bytes once no reference remains. Commands do not report live processes. WSL DrvFS permissions remain governed by the mounted Windows filesystem.
- **Next acceptance gate:** Add a real live-session registry before implementing `ps` and `stop`, plus systematic collection fault injection.
- **Audit:** AER-061, AER-064, AER-066.

### AES-CLI-006 — `pull`, `push`, and `create` operations

- **Status:** `partial`
- **Owner:** CLI and model-distribution domains
- **Claim sources:** CLI help and completed Ollama-suite TODO
- **Implementation evidence:** `pull` is a real built-in public-GGUF downloader with checked argv execution, HTTPS-only redirects, pinning, digest/size validation, resumable single-connection partials, optional nonresumable byte ranges, and atomic exclusive publication. Transfer, header inspection, digest verification, sync and publication stay bound to one opened stage inode. `pull --name <name[:tag]>` preflights the selected store, then remeasures the downloaded inode inside the locked content-addressed transaction and requires the pinned digest/size before catalog mutation. `create` supports both recipe-only records and `--model` blob import. `push` remains fail closed.
- **Executable evidence:** `E-MASTER`, `E-STORE`, `E-HF-RESUME`, eight live integrity/resume/failure/registration checks, and the full pinned Gemma and Stheno artifact downloads through `pull`. The small registered fixture and exact result are recorded in `docs/evidence/hf-pull-store-2026-09-02.md`.
- **Evidence boundary:** Public, pinned, single-GGUF Linux/WSL downloads, safe single-connection restart continuation, and explicit registration are established. Exact path-replacement publication is proved on native Linux storage; WSL DrvFS may instead invalidate the opened descriptor and fail closed. The downloaded destination remains caller-owned, so registration currently creates separate protected store bytes. No authentication or upload exists; multi-connection transfers restart from zero and store garbage collection is a separate local command.
- **Next acceptance gate:** Add authentication, explicit cancellation UX, store-aware staging that avoids a redundant retained destination when requested, and a separately scoped upload contract.
- **Audit:** AER-064, AER-082, AER-003.

### AES-CLI-007 — `rm`, `cp`, `stop`, and runtime lifecycle semantics

- **Status:** `partial`
- **Owner:** CLI and runtime domains
- **Claim sources:** CLI help and completed Ollama-suite TODO
- **Implementation evidence:** `cp` and `rm`/`delete` perform locked, restart-safe catalog mutations through staged file sync, atomic replacement and directory sync. Copies preserve a shared immutable SHA-256 blob reference. Removal preserves bytes until explicit `gc` proves them unreferenced under the store lock. Native CUDA service, chat and single-shot paths now hold shared inode leases; `gc` skips a leased orphan. `ps` reports one validated live service owner per store, and `stop <exact-model>` uses an owner-locked record, boot/start identity and Linux pidfd signaling rather than a raw PID.
- **Executable evidence:** `E-MASTER` durable catalog cases and `E-STORE` separate-process success, rollback, shared-reference retention, and reference-aware reclamation checks. S22's focused durable-store test proves lease-retained and post-release GC behavior; `scripts/test_service_lifecycle_live.py` exercises native, Ollama and direct-path foreground services on installed Gemma weights, wrong-target refusal, stop/unload, and a forged stale-PID record that leaves an unrelated process alive. A physical catalog-backed chat turn and single-shot CUDA answer passed after adding those leases.
- **Evidence boundary:** This is a single foreground service per model store on the exercised Linux/WSL pidfd host, not a daemon, hot-swap manager, multi-process scheduler, or proof against another program deleting files outside Aesir transactions. A stop request is cooperative; an in-flight kernel can delay exit. Cold-start crash recovery and broader platforms remain unproved.
- **Next acceptance gate:** Systematic crash recovery and concurrent hostile-filesystem tests for collection, plus broader Linux/Windows portability where explicitly scoped.
- **Audit:** AER-061 through AER-064.

### AES-CLI-008 — REPL slash-command state and interactive inference

- **Status:** `partial`
- **Owner:** CLI domain
- **Claim sources:** CLI interface and Ollama `run` implications
- **Implementation evidence:** the legacy `RuneREPL` retains only local slash-command state and rejects ordinary model-backed input without mutating history; bare `run <model>` directs callers to `chat` instead of converting load errors into assistant text. `cuda_chat.mojo` provides interactive and prompt-file chat with a persistent `Gemma4CUDASession` or `Llama3CUDASession`, streamed text, `/help`, `/show`, `/clear`, validated `/set`, `/bye`/EOF handling and durable transcripts. Reset retains loaded weights and invalid interactive admissions preserve healthy history. `--profile llama3` selects Stheno with an 8K context and remaining-context completion policy.
- **Executable evidence:** `E-MASTER` covers legacy slash state plus ordinary-input/bare-run rejection and history preservation; physical Gemma and Stheno runs each completed 20 prompt-file exchanges. Stheno's unedited transcript records 20 natural EOS stops, 5,152 generated tokens and 6,514 retained context positions with an 8,192 ceiling; see `docs/evidence/stheno-roleplay-20.md`.
- **Evidence boundary:** Interactive inference is limited to the documented CUDA Gemma and Llama 3 profiles. Native CUDA chat additionally verifies cooperative SIGINT/deadline recovery. The legacy general REPL and arbitrary-model chat remain unestablished.
- **Next acceptance gate:** Consolidate the legacy/general session surface with the CUDA chat contract and add terminal-interaction tests.
- **Audit:** AER-059, AER-068.

### AES-CLI-009 — CLI flag parsing

- **S09 text-admission extension:** Configuration bytes pass the shared strict
  UTF-8/NUL boundary before JSON parsing; complete JSON consumption still rejects
  trailing data. The built settings harness proves malformed input causes no
  durable writes.

- **Status:** `partial`
- **Owner:** CLI domain
- **Claim sources:** README Bifrost/Ollama wording; TODO “Complete Ollama Terminal Command Suite”
- **Implementation evidence:** `CLIOptions` in `cli/options.mojo` records explicit presence for every parsed flag; `dispatch_command()` in `cli/commands.mojo` separates recognized options from model/prompt positionals, validates command applicability, validates and prints caller-selected configuration files, applies CLI acceleration precedence, and rejects non-CPU or non-neutral unconnected intent before model loading. `ConfigJSONParser` enforces the bounded nested schema, JSON strings/Unicode/numbers/booleans, duplicate and unknown-field rejection, section ownership, ranges, EOF, and no trailing commas/content. Parsed options include `--verbose` (`-v`), `--format json|text`, `--keepalive <duration>` (`5m`, `1h`), `--modelfile <path>` (`-f`), `--raw`, `--insecure`, `--max-tokens N`, configuration, acceleration, safety, experimental, and TUI intent.
- **Executable evidence:** `E-MASTER` cases `cli.truthful_command_boundaries`, `cli.flag_options_parser`, and `paradigms.config_and_json`; the CLI case includes compact JSON, escaped section names, exponents, duplicates, structural errors, wrong types/sections, ranges, trailing data and surrogate rejection. Built-CLI smoke tests cover normalized JSON output, default and explicit config loading, missing files, unsupported accelerator rejection, and command-inapplicable options.
- **S07b3 extension:** Native chat/serve now consume explicitly present config
  temperature/top_p and the selected catalog root (see AES-CLI-003). This does
  not connect single-shot sampling or the reserved safety/experimental fields.
- **Evidence boundary:** Configuration validation, option-safe positional parsing, CPU selection, and fail-closed option/config intent are connected. Sampling/safety/experimental application, output formatting, service/model-store option owners, stable exit-code schemas, and Ollama differential parity are not complete; these combinations reject explicitly instead of succeeding without effect.
- **Next acceptance gate:** Connect or reject every remaining accepted option at its owning operation, apply supported sampling/safety configuration to generation, and pass differential syntax/error/exit-code fixtures.
- **Audit:** AER-003, AER-059 through AER-068.

### AES-CLI-010 — Offline-safe system and model diagnosis

- **S02 extension (2026-09-12):** `doctor --format json` emits a single version-1
  prerequisite-scoped report, null unknown observations, actionable issue codes,
  observed disk path and optional embedded model inspection/error. Text and JSON
  share observations; findings return reports while invalid syntax fails.
  Built `scripts/test_native_doctor.py` covers Unicode metadata, standalone
  inspection parity, recipe/installed counts, missing blobs, corrupt catalog,
  optional model failures and format rejection. Added to CI. Integration also
  exposed and fixed shared JSON escaping that split multibyte UTF-8 characters.

- **S01 correction (2026-09-12):** Readiness counts installed SHA-256 entries,
  never recipe-only entries, validates store syntax before discovery, and labels
  its scope as CUDA/storage prerequisites rather than tested model execution.
  `scripts/test_native_doctor.py --binary .aesir/aesir-s01` passed isolated empty
  and recipe-only stores plus invalid/duplicate store flags. Counted suite:
  182 pass, 0 fail, 1 external-fixture skip; native build and doc-drift gate pass.

- **Status:** `verified`
- **Owner:** CLI presentation, core Linux observation, CUDA discovery, and durable catalog domains
- **Claim sources:** Round 2 model adoption and usability plan; CLI help
- **Implementation evidence:** `cli/doctor.mojo` reports the current Mojo process, validated MAX CUDA discovery, the first compatible GPU and observed memory, durable catalog readability, installed versus recipe-only entries, full SHA-256 verification failures, available filesystem capacity, and kernel-observed port 11434 listener state. `core/native_diagnostics.mojo` owns bounded POSIX `df -Pk` parsing and read-only `/proc/net/tcp*` observation. `doctor <model>` delegates model analysis to the existing architecture registry. Internet access and API endpoint identity are explicitly not probed.
- **Executable evidence:** `E-MASTER` cases `cli.doctor_observations` and `cli.doctor_readiness` cover hexadecimal port parsing, LISTEN-state discrimination, disk-column selection, byte formatting, offline readiness, missing-model, broken-model, and missing-CUDA policy. The built command physically observed the RTX 4070 Laptop GPU, rehashed the installed Gemma 4 E2B blob, reported `SYSTEM READY`, and produced a `VERIFIED` / `READY` model-specific diagnosis.
- **Evidence boundary:** Linux/WSL procfs and POSIX `df` are required. A listener observation proves only a socket on port 11434, not its application identity; the command does not contact the listener or public network. Full catalog verification can take time because every installed blob is rehashed. Readiness means local CUDA inference prerequisites are present, not that an API server is running.
- **Next acceptance gate:** Explicit CPU-only readiness policy, endpoint-aware loopback health probes if requested, and deeper filesystem fault fixtures around catalog diagnosis; stable machine-readable output is implemented in S02.
- **Audit:** Round 2 physical and counted verification, 2026-09-11.

### AES-CLI-011 — Exact-token native conversation persistence

- **S09 text-admission extension:** Snapshot bytes and every decoded text field
  pass shared strict UTF-8/NUL admission. Counted file fixtures cover malformed
  UTF-8 and trailing hidden data before any session state can be returned.

- **S15 lifecycle extension:** `cli/chat_recovery.mojo` is the shared recovery
  policy for both native session families. A healthy idle rejection may continue
  and discard only uncommitted autosave intent; interrupted prefill additionally
  gates every prompt on `/clear`. Unhealthy/in-flight execution and any failure
  after the generated turn closes require process restart. Same-PID model-switch
  handoff carries the previous model reference so a target startup failure can
  state exactly what was unloaded and what the user must restart.

- **Status:** `verified`
- **Owner:** CLI conversation storage and native CUDA session domains
- **Claim sources:** Round 2 model adoption and usability plan; native runtime guide
- **Implementation evidence:** `cli/conversation.mojo` defines a bounded, FNV-1a-checksummed v1 record containing model SHA-256, profile, context, system and sampling identities, sampler draw position, exact committed token IDs, and readable turns. Save and Markdown export use owner-private exclusive creation, full writes, file sync, and parent-directory sync; load uses bounded no-follow reads. Both CUDA session types record tokens only after successful `forward`, clear them with KV reset, and restore validated tokens into an empty session without sampling or text retokenization. `/save`, `/load`, `/new`, and `/export` are interactive between-turn controls. `scripts/conversations.py` adds a locked named library over those snapshots: NFC Unicode names, random stable entry IDs, exact metadata-to-snapshot validation, atomic save/rename metadata, restart listing, compatibility-filtered open, and exclusive Markdown export. `cli/conversation_autosave.mojo` adds opt-in private-directory generations: synced inflight intent, immutable synced snapshots, a checksummed atomic current manifest, manifest-derived retention and compatible native restore. CUDA chat begins intent before generation and commits only after exact session state and the readable turn agree; reset/load/sampling mutations also checkpoint. `cli/chat_recovery.mojo` and the `ChatTurnAttempt` close marker make recovery depend on observed session phase rather than the exception text. Model-switch preflight stays inside the old session scope; post-unload startup uses an internal previous-reference handoff.
- **Executable evidence:** `E-MASTER` cases `cli.conversation_codec`, `cli.conversation_compatibility`, `cli.conversation_autosave_generations`, and `cli.chat_recovery_policy` cover Unicode/newline round trips, exact token preservation, checksum corruption, unsnapshotted-turn rejection, model/context mismatch refusal, latest-generation recovery, bounded retention, interruption detection, unrelated-file preservation, injected allocation/load/timeout policy, false-retry prevention, and inherited transcript descriptor release during injected error unwind. `E-CONVERSATIONS` covers the named lifecycle in fresh processes. `E-AUTOSAVE` SIGKILLs a native writer after durable turn-two intent and proves a fresh process recovers committed turn one, reports generation/turn two as interrupted, performs owned cleanup, and fails closed on manifest corruption. `E-CHAT-RECOVERY` executes initial and post-switch load failures through the built CLI and checks their nonzero terminal instructions. The installed-model physical probes pass same-PID Gemma→Qwen→Gemma switching and Gemma generation cancellation, next-turn reuse, prefill-timeout reset gating, and idle Ctrl+C; that S15 run also caught and fixed a post-turn signal-drain race. A previously generated native Qwen snapshot also passed named import, restart discovery and compatibility-open against its recorded identity. Physical Gemma 4 E2B and Qwen 3 0.6B sessions each generated, saved, reset to position zero, reloaded to the exact saved position, and retained the saved turn count; Gemma then continued as turn two with the prior answer in context.
- **Evidence boundary:** Snapshots and autosave restore conversation KV and repetition/sampling sequence only for the same exact model bytes, native profile, context, system prompt, and sampling settings. Named-library save imports an already created snapshot; `open` reports its validated path while native compatibility remains authoritative. Autosave requires a caller-created owner-held private directory, is Linux-specific, and still rejects model switching because generations are single-model. The process-kill harness proves visibility and recovery under SIGKILL on the tested filesystem, not sudden-power-loss durability at every syscall or a physical post-crash CUDA continuation. S15 physically executes model-load failures and tests allocation/timeout decisions without forcing real GPU out-of-memory; it does not claim automatic resurrection of an unloaded model or physical OOM cleanup instrumentation. Process unwind/exit owns failed-session resource release, while the counted descriptor probe checks the inherited transcript handle. No operation overwrites an existing named entry or export. There is no in-chat library menu, delete command, encrypted storage, or cross-context migration. Named-library interrupted stages are ignored rather than collected automatically.
- **Next acceptance gate:** S16 catalog migration/backup/restore and concurrent mutation; conversation follow-ups remain an in-chat library selector/delete policy and physical sampled continuation replay oracle for both session families.
- **Audit:** Round 2 physical and counted verification, 2026-09-11.

### AES-CLI-012 — Durable model aliases and favorites

- **S09 text-admission extension:** Preference bytes and decoded alias/favorite
  values pass strict UTF-8/NUL admission. Built-process raw/encoded malformed
  UTF-8 and trailing-data fixtures fail without rewriting any durable record.

- **S04 extension (2026-09-13):** Doctor reports shortcut health in text/JSON.
  `repair-preferences` defaults to a dry run; explicit `--apply` prunes only
  references to absent catalog entries. Recipe-only and missing-blob references
  are retained. The repair reloads both records under the shared directory lock
  and reads catalog data through the pinned root descriptor; absent or invalid
  catalogs block repair. Unchanged preferences are not rewritten. The model
  chooser now filters recipe-only entries before favorite ordering/numbering.
  `scripts/test_native_preferences.py` exercises built-process preview/apply,
  retention, other-store preservation, corruption rejection and locked recheck.
  Final S04 build and this harness passed, including raw/encoded NUL refusal,
  missing-record refusal, chooser filtering and exact small-size display;
  doctor/catalog harnesses and counted suite passed (182/0/1 skip).

- **Status:** `verified`
- **Owner:** CLI model-preferences, model-reference, and selector domains
- **Claim sources:** Round 2 model adoption and usability plan; native runtime guide
- **Implementation evidence:** `cli/model_preferences.mojo` stores validated alias-to-canonical mappings and canonical favorites in a bounded, FNV-1a-checksummed `preferences.v1` record. Mutations share the model-store directory lock, stage owner-private files, synchronize content, atomically replace the record, and synchronize the directory. `cli/model_reference.mojo` resolves non-path shortcuts before canonical blob verification. `cli/model_selector.mojo` creates a stable favorite-first view and marks favorites without mutating catalog order. `alias`, `aliases`, `unalias`, `favorite`, `favorites`, and `unfavorite` expose the lifecycle.
- **Executable evidence:** `E-MASTER` cases `cli.model_preferences_codec`, `cli.favorite_model_selection`, and the extended `cli.manifest_store_restart` cover codec round trips, checksum corruption, alias validation, stable ordering, visible marking, restart persistence, and alias-to-canonical-blob resolution. The built CLI physically persisted `gemma -> gemma4-e2b:latest`, marked the canonical model as favorite, listed both records, and used `aesir inspect gemma` to reach the real Gemma 4 E2B catalog blob.
- **Evidence boundary:** Preferences are local to one model-store root. Aliases target installed catalog identities and do not apply to explicit paths. Removing a catalog model can leave a stale preference, which fails closed when resolved; no automatic pruning, cross-device synchronization, nested aliases, or general user-settings system is claimed.
- **Next acceptance gate:** Crash-injection, broader concurrent-process stress, and alias-shadowing policy. S04 implements explicit pruning and doctor findings; its concurrency proof is a bounded lock/reload witness, not a general stress campaign. Strict text admission is complete in S09.
- **Audit:** Round 2 physical and counted verification, 2026-09-11.

### AES-CLI-013 — Interactive native CUDA model hot switching

- **Status:** `verified`
- **Owner:** CLI CUDA-chat lifecycle, model resolution, and process handoff domains
- **Claim sources:** Round 2 model adoption and usability plan; native runtime guide
- **Implementation evidence:** `/model <name-or-alias-or-path>` resolves and inspects a READY CUDA target while the current session remains healthy. The accepted request returns out of the concrete Gemma or dense-GQA session scope, releasing model-specific resources. A same-PID `execv` process-image handoff then starts the target with a fresh MAX CUDA runtime while preserving terminal/stdin, signal bootstrap state, model-store selection, device/reserve, system prompt, sampling settings, timeout, explicit context/completion preferences, TUI mode, and an inherited durable transcript descriptor. Conversation tokens, KV, repetition history, and sampler draw position intentionally reset.
- **Executable evidence:** `E-MASTER` case `cli.cuda_model_switch_syntax` covers accepted alias/path syntax and malformed controls. The opt-in `scripts/test_native_model_switch.py` physical harness switched Gemma 4 E2B → Qwen 3 0.6B Q4_K_M → Gemma 4 E2B inside one chat task, preserved interactive temperature and timeout changes, retained one transcript, and rejected same-model and missing-file requests before unloading the healthy current session.
- **S07b4b handoff evidence:** `build_chat_model_switch_arguments()` exposes the
  exact pre-exec argv for pure testing. Floating values use the shared exact
  decimal serializer, eliminating exponent-formatted small values that the next
  process would reject. The counted model-switch case checks all four floating
  fields plus context, reply limit, TUI and transcript settings. This extends
  construction evidence; it is not a new physical switch run.
- **Evidence boundary:** This is Linux `/proc/self/exe` plus `execv` process-image switching for interactive native CUDA chat. It preserves PID and user-facing application continuity but does not preserve conversation state, loaded kernels, or open resources other than the explicit transcript descriptor. Prompt-file mode treats `/model` literally. Windows-native operation, crash recovery during handoff, encrypted transcript descriptors, background model pools, and zero-latency switching are not claimed.
- **Next acceptance gate:** Add an integration test that samples before and after switching, a machine-observed PID/VRAM timeline, optional conversation-save prompting, and a portable process-handoff abstraction.
- **Audit:** Round 2 physical and counted verification, 2026-09-11.

### AES-CLI-014 — Interactive terminal home launcher

- **Status:** `verified`
- **Owner:** CLI home, executable routing, attached POSIX child execution
- **Claim sources:** Application gameplan S05; CLI help
- **Implementation evidence:** `main` routes explicit `home` and terminal-only
  empty launches to `cli/home.mojo`. Strict store parsing precedes interactive
  setup. Home displays catalog counts and launches chat/list/doctor/repair-preview
  through argv-only attached children, then reaps and reports their exit.
  GPU state and chat model-switch exec remain in the child; command help and
  menu cancellation stay local. No implicit import, repair application, or daemon.
- **Executable evidence:** `scripts/test_native_home.py` uses real PTYs and
  redirected streams to exercise first-run/custom/recipe-only/corrupt stores,
  menu choices, chat selection failure/cancellation, child signal exit/reaping,
  EOF and unchanged durable files. The native build and counted suite are gates.
- **Evidence boundary:** Linux/WSL terminals and `/proc/self/exe` only. Fixtures
  do not establish successful GPU inference or physical model-switch behavior
  through Home; existing direct chat proofs remain separate. No graphical UI
  or Windows-native launcher is claimed. Parent shutdown supervision and job
  control beyond the documented foreground workflow remain unverified.
- **Next acceptance gate:** Windows/WSL launch helpers (S06), richer terminal
  UX/accessibility (S33/S34), and a physical Home-to-chat conversation witness.

## 11. Server and Protocol Surfaces

### AES-SRV-001 — POSIX socket bind/listen setup

- **Status:** `verified`
- **Owner:** Server domain
- **Claim sources:** README BifrostGate; server interface
- **Implementation evidence:** `BifrostGate` in `server/api.mojo` implementing POSIX `socket()`, `setsockopt(SO_REUSEADDR)`, `set_nonblocking()` (`fcntl`), `bind()`, `listen()`, `is_valid()`, and `close()`.
- **Executable evidence:** `E-MASTER` case `server.posix_socket` in `test_multi_engine.mojo`.
- **Evidence boundary:** Implements POSIX socket bind/listen setup, non-blocking configuration, and clean descriptor teardown; the legacy gate is not the live service. The native loopback service is tracked in `AES-SRV-010`.
- **Audit:** AER-070, AER-076, AER-077.

### AES-SRV-002 — Request acceptance and HTTP parsing

- **Status:** `verified`
- **Owner:** Server domain
- **Claim sources:** server interface; README bare-metal HTTP server
- **Implementation evidence:** `HTTPRequest` struct, `parse_http_request()`, and `dispatch_http_request()` in `server/api.mojo` parsing request line (method, path, protocol), header block (`Content-Length`), body isolation, and route dispatching.
- **Executable evidence:** `E-MASTER` case `server.http_parser` in `test_multi_engine.mojo`.
- **Evidence boundary:** Legacy local parser assertions do not establish safe network input. Live serving uses the separate strict `local_protocol.mojo` contract in `AES-SRV-010`.
- **Audit:** AER-069, AER-071, AER-072.

### AES-SRV-003 — Complete/write-safe HTTP responses

- **Status:** `verified`
- **Owner:** Server transport domain
- **Claim sources:** server interface
- **Implementation evidence:** `write_all_bytes()` in `server/api.mojo` looping socket writes for partial write recovery; `build_http_response()`, `build_sse_chunk()`, and `build_http_chunk()` framing helpers.
- **Executable evidence:** `E-MASTER` case `server.http_response_framing` in `test_multi_engine.mojo`.
- **Evidence boundary:** Legacy tests alone cover framing and narrow send behavior. Live serving separately uses nonblocking bounded `send_local` with SIGPIPE suppression; the S19 real-model and forced no-reader probes cover only the stated local streaming cases.
- **Audit:** AER-073, AER-074, AER-075.

### AES-SRV-004 — Raw file-descriptor generation chunk forwarding

- **Status:** `verified`
- **Owner:** facade and server domains
- **Claim sources:** TODO streaming pipeline; server interface
- **Implementation evidence:** `write_all_bytes()` and `build_http_chunk()` in `server/api.mojo` enforcing negative file descriptor validation and terminal chunked HTTP framing (`0\r\n\r\n`).
- **Executable evidence:** `E-MASTER` case `server.http_response_framing` in `test_multi_engine.mojo`.
- **Evidence boundary:** Verified socket write partial loops, invalid descriptor bounds, and terminal chunk framing.
- **Audit:** AER-011, AER-073 through AER-075.

### AES-SRV-005 — Bounded OpenAI-shaped JSON serializer

- **Status:** `partial`
- **Owner:** server protocol domain
- **Claim sources:** multi-engine TODO; server interface
- **Implementation evidence:** `OpenAIGate` bounds and escapes caller-observed JSON/SSE data; `cli/native_serve.mojo` now supplies actual request identity, time, model and usage for a bounded completion/chat route subset. The disconnected legacy router in `server/api.mojo` still returns 501.
- **Executable evidence:** `E-MASTER` case `server.openai_rest_gateway`; `E-API-CONTRACT` and `E-COMPAT-STREAM` exercise model list, chat/completion, errors and incremental SSE on a real CUDA service.
- **Evidence boundary:** These live routes are a narrow subset, not complete OpenAI compatibility. S24 adds only one non-streaming, zero-argument Gemma 4 function call; official SDK breadth, general tools, multimodal input and streaming usage options remain unproved/unsupported.
- **Next acceptance gate:** Independent SDK fixtures and broader protocol conformance.
- **Audit:** AER-078, AER-079.

### AES-SRV-006 — OpenAI-compatible REST execution

- **Status:** `partial`
- **Owner:** server and facade domains
- **Claim sources:** completed multi-engine TODO and server interface
- **Implementation evidence:** the live CLI service parses bounded `/v1/models`, `/v1/completions` and `/v1/chat/completions` requests, invokes the loaded CUDA model and reports measured usage. The disconnected legacy router remains unsupported.
- **Executable evidence:** `E-API-CONTRACT` and `E-COMPAT-STREAM` cover successful replies, incremental SSE terminal framing, reset-peer cancellation and unsupported-field rejection. S24's focused `test_local_protocol.mojo` and independent `scripts/test_gemma_tool_call_live.py` cover strict Gemma tool admission, one actual emitted ID/empty-argument call, and ordinary text in both service modes; the same final binary passed all 31 v1 HTTP fixtures.
- **Evidence boundary:** One loaded text model, one choice, strict field subset, no embeddings or general tool-result continuation. S24's Gemma 4 single-function no-argument call is separately bounded; no full external-client compatibility claim.
- **Next acceptance gate:** Official-client conformance, wider model families and streaming usage options.
- **Audit:** AER-078, AER-079, AER-003.

### AES-SRV-007 — llama.cpp HTTP compatibility routes

- **Status:** `missing`
- **Owner:** server protocol domain
- **Claim sources:** completed multi-engine TODO and server interface
- **Implementation evidence:** known llama.cpp-shaped routes return HTTP 501; fixed completion/token/health/metrics payloads were removed.
- **Executable evidence:** `E-MASTER` case `multi_engine.http_unsupported_responses`; no conformance fixture exists.
- **Evidence boundary:** Truthful rejection is not protocol parity.
- **Next acceptance gate:** Select supported endpoints/version, connect real tokenizer/inference/state, and pass differential request/response/error tests.
- **Audit:** AER-080, AER-081.

### AES-SRV-008 — Ollama HTTP API compatibility

- **Status:** `partial`
- **Owner:** server, CLI, store, and inference domains
- **Claim sources:** README “Ollama API compatible”; CLI serve banners
- **Implementation evidence:** `--ollama` serves a bounded `/api/version`, `/api/tags`, `/api/ps`, `/api/show`, `/api/generate` and `/api/chat` subset against one loaded catalog model. Unknown fields/options are rejected.
- **Executable evidence:** `E-API-CONTRACT` and `E-COMPAT-STREAM` exercise routes, incremental JSON/NDJSON records, terminal counts, reset-peer cancellation and negative cases.
- **Evidence boundary:** No pull/create/delete, embeddings, tools, multimodal input or remote access; not drop-in Ollama compatibility. Only the installed Gemma model is physically checked here.
- **Next acceptance gate:** Independent Ollama-client/differential fixtures and broader model coverage.
- **Audit:** AER-069 through AER-081.

### AES-SRV-009 — Concurrent, bounded, secure service operation

- **Status:** `partial`
- **Owner:** service and security domains
- **Implementation evidence:** The native local service adds strict input limits, owner-only key admission, authentication, loopback-only binding, bounded I/O, cooperative cancellation/deadlines and privacy-preserving request logs.
- **Executable evidence:** `local_service.json`, `local_service.http`, `local_service.request`; `scripts/test_native_service.py` with both real CUDA models.
- **Evidence boundary:** One active stateless request, backlog 8, no parallel scheduling, TLS, rate limiter, user quotas, remote access or public production claim. Local reset-peer and forced no-reader transport probes do not amount to a public-service security assessment.
- **Next acceptance gate:** Sustained load/fuzz/security assessment, explicit multi-client scheduling, deployment lifecycle, and separately tested compatibility protocols.

### AES-SRV-010 — Authenticated native loopback CUDA generation

- **Status:** `verified`
- **Owner:** CLI orchestration, server transport/protocol, facade session contract, core CUDA execution.
- **Implementation evidence:** `cli/native_serve.mojo` invokes `ControlledTextSession` through the facade. `server/local_protocol.mojo` owns bounded HTTP/flat JSON; `server/local_transport.mojo` owns private-file authentication input and nonblocking loopback sockets. `serve` no longer opens and immediately closes the old socket scaffold.
- **Executable evidence:** Both real-model HTTP probes pass at context 512 and max 64 new tokens: authentication/Host/origin checks, observed binding/masks, arithmetic, stateless seeded replay, malformed/oversized requests, slow-client deadlines, prefill recovery, reset-peer handling and active SIGINT/SIGTERM shutdown.
- **Evidence boundary:** Native `/health` and `/v1/generate`, one loaded model, serialized stateless generation, Linux x86-64/NVIDIA. The S18 native `stream:true` path sends UTF-8-safe NDJSON while decoding and a measured terminal record; an independent real-Gemma fixture observed 64 text records over 4 seconds before final and an EOS case. S25a adds monotonic service-phase prefill/decode milliseconds to native final responses; they include orchestration and optional stream sends, not isolated GPU kernel time. Other CUDA families, disconnect/backpressure and full OpenAI/Ollama compatibility remain unproved.
- **Reproduction and threat model:** [Native service guide](docs/NATIVE_SERVICE.md).
- **Native setup hardening:** `keygen` obtains a 256-bit OS-random key and publishes it exclusively through a synced private file in the opened parent directory. The external no-GPU probe verifies exact/Unicode paths, existing-file/symlink preservation, a four-process race and cleanup; hosted CI runs it. Four counted service cases include explicit C-path termination/bounds.

- **2026-10-01 Turing integration:** Authenticated health derives session status
  and exposes loaded model/digest, token/deadline/queue policy and explicit absent
  embeddings; nonstreamed generation adds loaded identity. The actual 3B native
  socket harness and all 29 native/Ollama/OpenAI-subset HTTP contract cases pass.
  A build-checked private user unit recovers from SIGKILL, changes PID, rehashes and
  reloads the model, and generates a fresh answer. Bifröst native HyDE and explicit
  Ollama outage/circuit recovery pass without corpus changes. Same-host scope only;
  crashed requests are not replayed. See the [evidence record](docs/evidence/second-brain-2026-10-01.md).

## 12. Embeddings and RAG

### AES-RAG-001 — Cosine similarity for tested F16 vectors

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** RAG TODO and core interface
- **Implementation evidence:** `cosine_similarity` in `core/compute.mojo` enforcing equal-shape validation, SIMD dot/norm calculation, zero-vector zero-norm detection (`norm_a_sq <= 0.0 or norm_b_sq <= 0.0 -> 0.0`), and SIMD tail processing.
- **Executable evidence:** `E-MASTER` case `rag.cosine_similarity` in `test_rag.mojo`.
- **Evidence boundary:** Implements checked SIMD cosine similarity for F16 RuneTensors with zero-norm and dimension-mismatch protection.
- **Audit:** AER-083.

### AES-RAG-002 — In-memory vector document store and top-k search

- **Status:** `verified`
- **Owner:** core memory/RAG domain
- **Claim sources:** Mímisbrunnr TODO; core interface
- **Implementation evidence:** `MimirStore` in `core/mimir_well.mojo` enforcing strict equal-dimension checks on `add_document` (`embedding.size != self.dim`) and `search_knn` (`query_emb.size != self.dim`), with top-k selection and capacity validation.
- **Executable evidence:** `E-MASTER` case `rag.in_memory_store` in `test_rag.mojo`.
- **Evidence boundary:** Checked contiguous in-memory vector document store enforcing strict dimension equality and capacity bounds.
- **Audit:** AER-084, AER-085.

### AES-RAG-003 — Query embedding generation

- **Status:** `partial`
- **Owner:** facade and embedding domains
- **Claim sources:** RAG integration claims
- **Implementation evidence:** `mean_pool_token_embeddings()` validates every caller token ID before allocation and mean-pools rows from a real caller-supplied token table. `extract_query_embedding()` requires the loaded `token_embd.weight`, exact hidden dimension, and a non-empty valid token sequence; it has no hash, constant, or token-zero substitution.
- **Executable evidence:** `E-MASTER` case `rag.query_embedding` checks exact mean-pool values and pre-allocation rejection for invalid IDs and empty token sequences. The engine integration case remains explicitly skipped without a real fixture.
- **Evidence boundary:** No fabricated fallback remains, but the real-model path is not exercised by the default suite and is not a dedicated embedding model.
- **Next acceptance gate:** Run the pinned external fixture in CI and compare embeddings/retrieval against an independent oracle.
- **Audit:** AER-086.

### AES-RAG-004 — Corpus ingestion, chunking, metadata, and persistence

- **Status:** `partial`
- **Owner:** RAG domain
- **Claim sources:** Mímisbrunnr external knowledge-base claim
- **Implementation evidence:** `DocumentChunk` and `chunk_text()` provide deterministic overlapping inline chunks with original byte offsets, validate NUL-free UTF-8, and align emitted boundaries to complete code points. `ingest_corpus_batch()` validates caller-supplied embedding matrix shape, store capacity, and every non-empty chunk before copying rows; preflight rejection preserves store and arena state.
- **Executable evidence:** `E-MASTER` case `rag.corpus_ingestion` checks chunking, exact Unicode byte offsets, malformed UTF-8 rejection, real matrix copying, shape/capacity/empty-text rejection, and mutation-free failure.
- **Evidence boundary:** There is no file/document parser, durable index, versioning, update/delete path, embedding service, or provenance-preserving citation store. Byte-based chunk size may be exceeded by a single complete Unicode code point.
- **Next acceptance gate:** Reproducible ingestion pipeline, persistent store/index, metadata/citation contract, restart behavior, and external corpus tests.
- **Audit:** AER-084 through AER-087.

### AES-RAG-005 — End-to-end retrieval-augmented generation

- **Status:** `partial`
- **Owner:** facade, RAG, and generation domains
- **Claim sources:** TODO Mímisbrunnr and facade interface
- **Implementation evidence:** `_prepare_prompt()` uses loaded token embeddings, local KNN results, a fixed 1024-byte context cap, and grounded-context prompt construction.
- **Executable evidence:** `E-MASTER` case `rag.local_retrieval_prompt` covers the separate caller-embedded retrieval and citation-formatting primitives; the combined engine path is explicitly skipped without an external fixture.
- **Evidence boundary:** Corpus ingestion/persistence, citation provenance, and default-suite real-model execution remain incomplete.
- **Next acceptance gate:** Add a pinned corpus plus model fixture and prove retrieval, prompt budgeting, citations, generation, and restart behavior end to end.
- **Audit:** AER-086, AER-087, AER-113.

## 13. Quantization and Compressed Formats

Runtime expansion note: CPU Q2_K, Q3_K, Q4_K, Q5_K, Q6_K, IQ1_S, IQ2_XXS,
and TQ1_0 execution
reads canonical GGML packed bytes through bounded decoders. Q4_K/Q6_K GEMM also
matches 25 independent Stheno row references via `tests/test_cpu_packed_parity.mojo`;
output remains F16 (maximum observed difference 0.00018817186). Raw-byte
known-value cases cover every K-quant decoder. Legacy SIMD block descriptors
and circular self-parity transforms were removed.

### AES-QNT-001 — Compressed-format discriminants and names

- **Status:** `verified`
- **Owner:** core memory/format domain
- **Claim sources:** compressed-format descriptors and loader interface
- **Implementation evidence:** `CompressedFormatType` retains stable internal discriminants while `GGMLType.to_compressed_format` maps implemented GGML quantized tensor IDs 2, 3, 6–14, IQ2_XXS ID 16, IQ1_S ID 19, and TQ1_0 ID 34 (excluding unsupported Q8_K 15) and raises for every other value. The former `TERNARY_155BIT` name remains a source-compatible alias for the canonical TQ1_0 discriminant.
- **Executable evidence:** `E-MASTER` case `quantization.enum` in `test_quantization.mojo`.
- **Evidence boundary:** Verified stable descriptor names, exact supported mappings, and strict rejection of F32 and the still-unsupported Q8_K type. Descriptor presence does not imply execution support.
- **Audit:** AER-051, AER-054.

### AES-QNT-002 — Q4_K_M block dequantization transformation kernel

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** README q4_k_m and core compute interface
- **Implementation evidence:** `dequantize_ggml_k` and `packed_value` read the canonical 144-byte GGML Q4_K layout. `dequantize_compressed_tensor()` rejects invalid storage, nonpositive counts, and partial blocks before dispatch; the padded local block descriptor was removed.
- **Executable evidence:** `E-MASTER` case `compute.dequantize_q4_k` uses a raw 144-byte block with hand-calculated output, while `quantization.fused_q4_k_m_parity` exercises the fused path.
- **Evidence boundary:** Verified raw-byte Q4_K transformation math and incomplete-block rejection. Real-model breadth remains scoped by `AES-QNT-003`.
- **Audit:** AER-051, AER-052, AER-053.

### AES-QNT-003 — Real quantized-model inference

- **Status:** `partial`
- **Owner:** loader, compute, and inference domains
- **Claim sources:** README q4_k_m support and completed quantized-format TODO
- **Implementation evidence:** the CPU synthetic path remains present; the native Gemma and Llama 3 CUDA profiles use packed Q4_K/Q5_K/Q6_K weight matvec kernels connected to bounded GGUF tensor metadata.
- **Executable evidence:** master-suite Q4_K_M parity plus 35 independently generated real-weight CUDA matvec comparisons from the pinned Gemma artifact (maximum absolute error `1.3113022e-06`) and end-to-end 20-turn Q4_K_M inference.
- **Evidence boundary:** Real execution establishes the documented Gemma and Stheno profiles, not general quantized model compatibility or independent full-model logit parity. Stheno's 35 real-weight comparisons have maximum absolute error `4.172325e-07`; its roleplay acceptance status is recorded in `docs/STHENO_CUDA.md`.
- **Next acceptance gate:** Per-model end-to-end parity against an independent implementation and broader supported quantized fixtures.
- **Audit:** AER-051 through AER-054.

### AES-QNT-004 — Legacy 4-bit and 5-bit block quantization transformation kernels

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** GGUF legacy quantization support (Q4_0, Q4_1, Q5_0, Q5_1)
- **Implementation evidence:** `BlockQ4_0`, `BlockQ4_1`, `BlockQ5_0`, `BlockQ5_1` block structs, `dequantize_q4_0`, `dequantize_q4_1`, `dequantize_q5_0`, `dequantize_q5_1` block dequantizers, and `gemm_q4_0`, `gemm_q4_1`, `gemm_q5_0`, `gemm_q5_1` fused matrix-vector multiplication kernels in `core/compute.mojo`.
- **Executable evidence:** `E-MASTER` cases `quantization.fused_q4_0_parity`, `quantization.fused_q4_1_parity`, `quantization.fused_q5_0_parity`, `quantization.fused_q5_1_parity` in `test_legacy_quantization.mojo`.
- **Evidence boundary:** Verified bit-for-bit mathematical output parity between fused Q4_0, Q4_1, Q5_0, Q5_1 GEMM and uncompressed `gemm_f16`.
- **Audit:** Stage 51.1 Mythic Engineering Pass.

### AES-QNT-005 — 8-bit integer and FP8 floating-point block quantization transformation kernels

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** 8-bit and FP8 quantization support (Q8_0, Q8_1, FP8_E4M3, FP8_E5M2)
- **Implementation evidence:** Q8_0 GEMM reads canonical 34-byte GGML blocks and Q8_1 GEMM reads canonical 40-byte blocks with F32 scale and auxiliary sum metadata. `dequantize_q8_0`, `dequantize_q8_1`, `dequantize_fp8_e4m3`, `dequantize_fp8_e5m2`, and their fused entry points are implemented in `core/compute.mojo`.
- **Executable evidence:** `E-MASTER` cases `quantization.fused_q8_0_parity`, `quantization.fused_q8_1_parity`, `quantization.fused_fp8_e4m3_parity`, and `quantization.fused_fp8_e5m2_parity` use raw bytes with hand-calculated results.
- **Evidence boundary:** Verified exact Q8 block sizes/metadata addressing, complete-block enforcement, and representative finite FP8 decoding. Stored-model Q8_1 and broad FP8 fixture compatibility are not independently established.
- **Audit:** Stage 52.1 Mythic Engineering Pass.

### AES-QNT-006 — K-quantization 3-bit and 5-bit block quantization transformation kernels

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** 3-bit and 5-bit K-quantization support (Q3_K_S, Q3_K_M, Q3_K_L, Q5_K_S, Q5_K_M)
- **Implementation evidence:** `packed_value`, `dequantize_ggml_k`, and `gemm_ggml_k` read canonical 110-byte Q3_K and 176-byte Q5_K GGML blocks. Public Q3_K S/M/L and Q5_K S/M dequantizers plus the format-specific GEMM entry points route to that shared checked implementation; padded local descriptors and circular reference decoders were replaced.
- **Executable evidence:** `E-MASTER` cases `quantization.fused_q3_k_s_parity`, `quantization.fused_q3_k_m_parity`, `quantization.fused_q3_k_l_parity`, `quantization.fused_q5_k_s_parity`, and `quantization.fused_q5_k_m_parity` call both the public dequantizers and fused dispatch using raw upstream-layout blocks with hand-calculated outputs. `compute.dequantize_q4_k` additionally compares all 256 standalone Q5_K outputs against an independent scalar scale/minimum and high-bit-plane oracle.
- **Evidence boundary:** Verified one-block Q5_K raw-byte addressing, scale unpacking, high-bit/nibble extraction, format-alias dispatch, and known-value matvec results. Multi-block and full-model Q3_K/Q5_K execution have not been independently established.
- **Audit:** Stage 53.1 Mythic Engineering Pass.

### AES-QNT-007 — Quantization system crash-proofing, error-correcting, and self-healing boundaries

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** Quantization system crash-proofing, error-correcting, and self-healing boundaries
- **Implementation evidence:** `dequantize_compressed_tensor`, `dequantize_ggml_k`, the fixed-block legacy decoders, and fused GEMM paths validate counts, complete blocks, shapes, storage, and recognized format discriminants. FP8 corrupt-value handling remains explicit in `core/compute.mojo`.
- **Executable evidence:** `E-MASTER` cases `quantization.hardening_zero_and_null_bounds`, `quantization.hardening_invalid_dimensions`, `quantization.hardening_unrecognized_format`, `quantization.hardening_nan_sanitization` in `test_quantization_hardening.mojo`.
- **Evidence boundary:** Verified strict K-quant count rejection, mutation-free legacy zero-count handling, invalid GEMM shape rejection, unknown-format refusal, and FP8 NaN-bit handling.
- **Audit:** Stage 54.1 Mythic Engineering Pass.

### AES-QNT-008 — K-quantization 2-bit and 6-bit block quantization transformation kernels

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** 2-bit and 6-bit K-quantization support (Q2_K, Q6_K)
- **Implementation evidence:** `packed_value`, `dequantize_ggml_k`, and `gemm_ggml_k` read canonical 84-byte Q2_K and 210-byte Q6_K GGML blocks; public block dequantizers and format-specific GEMM entry points route through the shared checked path.
- **Executable evidence:** `E-MASTER` cases `quantization.fused_q2_k_parity` and `quantization.fused_q6_k_parity` call both the public dequantizers and fused dispatch using raw upstream-layout blocks with hand-calculated outputs; `compute.dequantize_q4_k` now compares every standalone Q6_K output against a separate scalar nibble/high-plane/signed-scale oracle; independent Stheno row parity additionally covers Q6_K.
- **Evidence boundary:** Verified one-block canonical raw-byte addressing, signed metadata use, complete-block enforcement, and known-value matvec results. Multi-block layouts and full-model Q2_K execution have not been independently established.
- **Audit:** Stage 55.1 Mythic Engineering Pass.

### AES-QNT-009 — GPTQ, AWQ, EXL2, HQQ, and SmoothQuant fused quantization transformation kernels

- **Status:** `partial`
- **Owner:** core compute domain
- **Claim sources:** GPTQ, AWQ, EXL2, HQQ, and SmoothQuant 4-bit/8-bit support (GPTQ_4BIT, GPTQ_8BIT, AWQ_4BIT, EXL2_VARBIT, HQQ, SMOOTHQUANT_INT8)
- **Implementation evidence:** `core/external_quantization.mojo` implements canonical host matrix contracts for AutoGPTQ 4-bit/8-bit, AutoAWQ GEMM 4-bit, EXL2 mixed 2/3/4/5/6/8-bit, SmoothQuant/torch-int static per-tensor W8A8, and native HQQ 4-bit `axis=1`. EXL2 consumes the official converter's unshuffled Int32 weight rows, packed scale levels, serialized maximum scales, group offsets, padded output width, and activation-order permutations. HQQ follows the upstream cross-group packing; SmoothQuant carries signed INT8 weights and activations with INT32 accumulation; GPTQ and AWQ retain their distinct packing and zero conventions. Every view has exact backing-storage counts and metadata validation. `core/compute.mojo` exposes metadata-aware overloads while legacy byte-only/RuneTensor entry points fail closed.
- **Executable evidence:** `E-MASTER` cases `quantization.gptq_4bit_known_value`, `quantization.gptq_8bit_known_value`, `quantization.awq_4bit_known_value`, `quantization.exl2_mixedbit_known_value`, `quantization.smoothquant_int8_known_value`, and `quantization.hqq_4bit_axis1_known_value` check independently hand-calculated dequantized values and GEMM rows. The EXL2 case covers every supported bit width, cross-word 3/5/6-bit extraction, permutation restoration, padding, scale decoding, and fail-before-mutation rejection. The HQQ case uses deliberately different high/low group rows; SmoothQuant covers signed rounding and saturation; AWQ proves its reorder map; GPTQ 4-bit covers activation-order groups and corrupt metadata rejection.
- **Evidence boundary:** Verified bounded AutoGPTQ, AutoAWQ GEMM, EXL2 mixed-bit, static per-tensor SmoothQuant W8A8, and HQQ 4-bit `axis=1` host primitives. There is no artifact loader, metadata attachment to `RuneTensor`, CUDA kernel for these layouts, external artifact fixture, or full-model parity evidence yet. Other HQQ bits/axes and dynamic/per-token or INT8-output SmoothQuant variants are not implemented. EXL2 conversion and full model execution remain unavailable under `AES-ECO-005`.
- **Next acceptance gate:** Wire parsed GPTQ/AWQ/EXL2/HQQ/SmoothQuant metadata into model tensors, add external-fixture parity, and then add measured CUDA kernels.
- **Audit:** EXL2 mixed-bit host primitive milestone, September 1, 2026.

### AES-QNT-010 — Ternary and 1-bit extreme quantization transformation kernels

- **Status:** `partial`
- **Owner:** core compute domain
- **Claim sources:** GGML extreme quantization support (IQ1_S, IQ2_XXS, TQ1_0 / legacy `TERNARY_155BIT` alias)
- **Implementation evidence:** `core/extreme_quantization.mojo` decodes canonical 66-byte GGML IQ2_XXS, 50-byte IQ1_S, and 54-byte TQ1_0 blocks. IQ2_XXS uses the upstream 256-entry grid, parity-completed sign masks, and local scale fields. IQ1_S uses the 2,048-entry ternary grid, split 11-bit indices, odd local scale multipliers, and signed delta. TQ1_0 extracts 256 balanced ternary values from 48 base-3 bytes plus four high lanes and applies the stored F16 block scale. All three enforce exact storage and provide F32-accumulating GEMM; GGUF types 16, 19, and 34 are admitted. `scripts/generate_iq_codebooks.py` reproducibly derives both checked-in IQ tables from `gguf-py`.
- **Executable evidence:** `E-MASTER` cases `quantization.iq2_xxs_known_value`, `quantization.iq1_s_known_value`, and `quantization.tq1_0_known_value` check independent raw-block oracle values, the full 256-value sum, fused GEMM, and short-storage rejection. The TQ1_0 fixture covers all three packed regions and the intentional UInt8 wrap used for base-3 digit extraction.
- **Evidence boundary:** Verified canonical IQ2_XXS, IQ1_S, and TQ1_0 host block decoding and matrix multiplication. TQ1_0 stores 54 bytes per 256 values (1.6875 bits/weight including its scale); BitNet's 1.58-bit label describes the ternary information content rather than this serialized block's exact storage rate. No extreme-quantized model fixture, CUDA kernel, full-model execution, or performance evidence exists yet.
- **Next acceptance gate:** Add pinned real IQ1_S, IQ2_XXS, and TQ1_0 row or model fixtures, then measured CUDA kernels and full-model parity.
- **Audit:** IQ1_S, IQ2_XXS, and TQ1_0 canonical host primitive milestones, September 1, 2026.

### AES-QNT-011 — Comprehensive all-format quantization metadata store & hardware autotuning gateway

- **Status:** `partial`
- **Owner:** core compute domain
- **Claim sources:** Comprehensive all-format quantization metadata and hardware autotuning gateway
- **Implementation evidence:** `core/quantization_autotuner.mojo` defines truthful fixed-block metadata for every inline `CompressedFormatType`, explicit external-metadata records for GPTQ/AWQ/EXL2/HQQ/SmoothQuant, and strict unknown-format rejection. `QuantizedGEMMAutotuner` benchmarks two real host strategies—fused packed GEMM and dequantize-then-F16 GEMM—with `CLOCK_MONOTONIC`, checks candidate output parity before selection, publishes output from caller-owned scratch only after success, and stores the winner in a bounded exact-device/format/shape cache. Its bounded v1 codec includes a caller build fingerprint, hex-safe device keys, measurements, an FNV-1a checksum, strict limits, duplicate rejection, and transactional restore. `cli/quantization_tuning_storage.mojo` adds normalized relative-path admission, a locked final directory, no-follow reads, bounded I/O, private `mkstemp` staging, file `fsync`, atomic `rename`, and directory `fsync`. Checked element products, pointer ranges, iteration limits, and complete-block admission fail before output mutation.
- **Executable evidence:** `E-MASTER` cases `quantization.format_metadata` and `quantization.measured_autotuner` verify all 26 internal discriminants, exact fixed rates including Q4_K and TQ1_0, external-metadata boundaries, unknown rejection, positive measured durations, valid winner selection, direct-GEMM parity, cache reuse, versioned serialize/restore, restored execution without retuning, build mismatch and corruption rejection, transactional preservation, atomic save/load through a fresh cache owner, and mutation-free rejection of a metadata-bearing raw request.
- **Evidence boundary:** Verified real Linux host measurements, bounded exact-shape caching, a restart-safe serialization contract, and atomic local cache-file publication over inline raw quantization layouts. Measurements are local observations, not published performance claims. Persistence remains an opt-in control-plane API; callers supply the relative root plus build/device identities, and intermediate parent directories must already be trusted. Metadata-bearing matrix views are not yet accepted by the tuner; no CUDA/other-device candidate set, representative benchmark matrix, thermal control, statistical sampling, or production auto-dispatch integration exists.
- **Next acceptance gate:** Derive build and physical-device fingerprints from observed runtime state, then add metadata-bearing candidates, synchronized physical CUDA candidates, representative shape sampling, and repeatable benchmark evidence before enabling automatic runtime use.
- **Audit:** Measured host selection and bounded cache milestone, September 1, 2026.

## 14. Hardware and Multi-Device Execution

### AES-ACC-001 — Host tensor row/column partitioning & all-reduce reduction

- **Status:** `verified`
- **Owner:** core memory/sharding domain
- **Claim sources:** multi-GPU TODO and core interface
- **Implementation evidence:** `shard_split_cols`, `shard_split_rows`, `ShardTensor`, and `all_reduce_sum` in `core/compute.mojo` enforcing strict shard tensor size bounds (`shards[s].size >= Out.size`).
- **Executable evidence:** `E-MASTER` cases `sharding.tensor_descriptor`, `sharding.row_column_partition`, and `sharding.all_reduce_sum` in `test_sharding.mojo`.
- **Evidence boundary:** Checked host memory partitioning and all-reduce sum reduction enforcing shard size bounds safety.
- **Audit:** AER-090, AER-091.

### AES-ACC-002 — Sequential host sharded GEMM and reduction

- **Status:** `verified`
- **Owner:** core compute/sharding domain
- **Claim sources:** multi-GPU TODO and core interface
- **Implementation evidence:** `gemm_f16_sharded` loops across host tensor lists; `all_reduce_sum` performs a host reduction enforcing empty input shards parameter rejection (`len(shards) == 0 -> raises Error("all_reduce_sum: input shards list must not be empty")`).
- **Executable evidence:** `E-MASTER` cases `sharding.host_all_reduce` and `sharding.host_gemm_parity` in `test_sharding.mojo`.
- **Evidence boundary:** Checked host memory sharded GEMM and all-reduce sum reduction enforcing empty input shards list safety bounds.
- **Audit:** AER-092, AER-093.

### AES-ACC-003 — Device topology discovery

- **Status:** `partial`
- **Owner:** core hardware domain
- **Claim sources:** NPU/GPU/multi-device TODO matrices and interfaces
- **Implementation evidence:** `CUDAGate.discover_physical_devices()` uses MAX 26.5 to enumerate every CUDA index and records runtime ID, name, API/version, memory, compatibility, compute capability, multiprocessor count, and thread limit. `DeviceTopology` validates, accumulates, deduplicates, and selects compatible records by realm-local index or runtime-derived stable ID.
- **Executable evidence:** `E-MASTER` cases `gpu.discovery_status_classification`, `gpu.physical_device_admission`, `gpu.discovery_accumulation`, and `gpu.stable_device_selection`; the CUDA Gemma session ran on the observed RTX 4070 Laptop GPU.
- **Evidence boundary:** This proves one MAX CUDA discovery adapter and one observed NVIDIA host. The MAX runtime ID is not a vendor UUID. Other backends and hardware CI remain unverified.
- **Runtime integration:** `hardware list` exposes Linux CPU memory/name and MAX CUDA observations. `compute plan|explain` validates native model buffers and selects a fitting device; both real CUDA sessions recheck memory and honor device selection. Five counted planning cases and `scripts/test_native_planning.py` passed on the RTX host. See `docs/NATIVE_RUNTIME.md` for snapshot, host-staging and unprobed-memory-domain limits.
- **S08b fit-evidence extension:** Host/device admission now emits stable reason codes plus exact required, available, reserve, usable, deficit and headroom bytes from overflow-safe arithmetic. Injected tests cover exact fit, one-byte deficit, reserve-over-available, maximum signed bytes and absent explicit devices. Fresh full-suite/build gates pass; observed context-4096 Gemma 4 E2B and Qwen 3 0.6B checks reported device-fit headroom of 3,001,580,956 and 5,305,711,420 bytes. A deliberate 16 GiB reserve retained exact `device_reserve_exceeds_available` evidence. These snapshots do not establish allocation or inference.
- **Upload integration:** Both CUDA sessions use at most 64 MiB pinned staging with synchronized exact-size copies. `test_cuda_upload.mojo` checks 201,457,805 physical round-trip bytes and three rejections; two counted admission tests and both real chat/control regressions pass. Host allowance includes mapped bytes plus bounded staging; GPU model memory does not shrink. Paired observed RSS values are recorded in `docs/NATIVE_RUNTIME.md`.
- **Container admission:** Native CUDA host budgets now intersect procfs with visible cgroup v2 ancestor limits/current usage; three counted parser/hierarchy cases and a real kernel-enforced 256 MiB user-service check pass. Missing visibility is documented; known v1 memory control and malformed reads fail closed.
- **Next acceptance gate:** Broader device/platform discovery, cgroup v1/hidden ancestry and hardware-CI coverage.
- **Audit:** AER-088, AER-094.

### AES-ACC-004 — Real multi-GPU placement and inference

- **Status:** `missing`
- **Owner:** core inference and hardware domains
- **Claim sources:** completed Multi-GPU TODO; facade/interface precedence rules
- **Implementation evidence:** current multi-device branch uses host pointer slices and sequential CPU functions; audit found invalid GQA/reconstruction semantics.
- **Executable evidence:** no physical multi-GPU test.
- **Evidence boundary:** Host sharding and a `num_devices` integer are not multi-GPU execution.
- **Next acceptance gate:** Real device discovery/allocation/transfers/kernels/collectives/sync, corrected inference design, CPU parity, failure handling, and scaling measurements on physical devices.
- **Audit:** AER-034, AER-088 through AER-094.

### AES-ACC-005 — NPU backend discriminants and buffer descriptors

- **Status:** `verified`
- **Owner:** core hardware/memory domain
- **Claim sources:** completed NPU Realm Gateway TODO; core/facade interfaces
- **Implementation evidence:** `NPUBackendType` and `NPUBuffer` in `core/mimir_well.mojo` enforcing negative size parameter rejection (`size_bytes < 0 -> raises Error("buffer size_bytes must not be negative")`).
- **Executable evidence:** `E-MASTER` cases `npu.enum` and `npu.host_buffer_view` in `test_npu_realms.mojo`.
- **Evidence boundary:** Checked NPU backend discriminants and buffer descriptor parameter bounds safety.
- **Audit:** AER-095, AER-096.

### AES-ACC-006 — NPU execution dispatch

- **Status:** `missing`
- **Owner:** core compute/hardware domain
- **Claim sources:** completed NPU TODO and runtime ACTIVE banner
- **Implementation evidence:** `NPUGate` can probe whether selected runtime libraries load, but physical discovery is intentionally unverified; allocation, transfer, and GEMM entry points fail closed.
- **Executable evidence:** `E-MASTER` cases `npu.npu_gate_availability`, `npu.npu_gemm_dispatch_bounds`, and `npu.npu_realm_unsupported_gateways` in `test_npu_realm.mojo`.
- **Evidence boundary:** Runtime-library presence is not a physical NPU, allocation, transfer, or kernel execution.
- **Next acceptance gate:** Implement one vendor SDK vertical slice and prove physical enumeration, memory, transfer, GEMM parity, synchronization, and failure cleanup on hardware.
- **Audit:** AER-095, AER-096, AER-003.

### AES-ACC-007 — GPU realm discriminants and buffer descriptors

- **Status:** `verified`
- **Owner:** core hardware/memory domain
- **Claim sources:** completed universal GPU Realm Matrix TODO; core/facade interfaces
- **Implementation evidence:** `GPURealmType` and `GPUBuffer` in `core/mimir_well.mojo` enforcing negative size parameter rejection (`size_bytes < 0 -> raises Error("buffer size_bytes must not be negative")`).
- **Executable evidence:** `E-MASTER` cases `gpu.enum` and `gpu.host_buffer_view` in `test_gpu_realms.mojo`.
- **Evidence boundary:** Checked GPU realm discriminants and buffer descriptor parameter bounds safety.
- **Audit:** AER-094, AER-095.

### AES-ACC-008 — GPU execution dispatch

- **Status:** `partial`
- **Owner:** core compute/hardware domain
- **Claim sources:** native CUDA Gemma 4 and Llama 3 profiles and existing F16 GEMM
- **Implementation evidence:** `Gemma4CUDASession` owns packed device weights, activations, per-layer/global/shared KV, native quantized matvec, norms, RoPE, attention, GELU/PLE, logits and GPU greedy selection. It is exported by `aesir.mojo` and reached by `chat --accel cuda` and `run --accel cuda`. There is no CPU model fallback or external inference engine. The detached legacy `MAXGate` reports no devices and refuses graph execution rather than substituting a host scalar GEMM.
- **Executable evidence:** RTX 4070 Laptop GPU: all 42 dense Gemma 4 E4B layers executed, 35 independent real-weight CUDA matvec comparisons passed (maximum error `1.3113022e-06`), tokenizer parity passed, and 20 exchanges with a 16,384 completion ceiling retained corrected facts across the 512-token attention boundary. Existing F16 CUDA GEMM exact/tail tests also passed. `E-MASTER` case `paradigms.max_gate_boundary` proves the detached gateway does not fabricate availability or mutate output. See `docs/GEMMA4_CUDA.md` for commands and limits.
- **Bounded allocation-lifetime evidence (AES500-021–029):** GPU-2/GPU-3 wrappers now record session-local logical allocation IDs, live owners/bytes, known pending work, and fenced/unfenced owner destruction. CPU-only adversarial tracker cases and physical RTX 2060 Max-Q GPU-2/GPU-3 lifecycle probes pass; the GEMM receipt checks three live owners immediately after each successful execution and pending counts after each successful context synchronization. See `TASK_cuda_allocation_lifetime_tracking.md`, [baseline](docs/evidence/cuda-allocation-lifetime-baseline-2026-10-10/README.md), [implementation](docs/evidence/cuda-allocation-lifetime-implementation-2026-10-10/README.md), [unit/adversarial](docs/evidence/cuda-allocation-lifetime-unit-2026-10-10/README.md), and [GEMM integration](docs/evidence/cuda-allocation-lifetime-integration-2026-10-10/README.md) receipts. This is single-host-thread diagnostic accounting for exercised synchronous paths. It does not establish thread-safe mutation, implicit destruction fences, async teardown safety, physical allocator reuse, driver memory return, or untracked raw-buffer ownership.
- **Evidence boundary:** Dense text-only E4B Q4_K_M and Llama 3 Stheno Q4_K_S profiles on one observed NVIDIA host. Independent logits for these profiles, long maximum-length generated outputs, arbitrary GGUF models, multimodal/MoE, Tensor Core optimization, multi-GPU and hardware CI are not claimed. The separate narrow 3B logit gate is recorded below. Host tokenization/I/O remains on CPU.
- **Llama 3 evidence:** `Llama3CUDASession` implements all 32 layers with native CUDA packed weights, F32 activations and F16 KV. Fifteen independent tokenizer cases and framing passed, including three whole-segment lookup regressions; 35 real-weight dot products and 34,816 CUDA RoPE/SiLU/GQA values matched independent references. Boundary-position RoPE precision was corrected on-device. See `docs/STHENO_CUDA.md` for the final conversation acceptance status.
- **2026-10-01 Turing/3B extension:** All 28 layers of the installed Llama 3.2
  3B Q4_K_M model execute natively with tied weights and scaled RoPE. A dedicated
  residual-add kernel avoids the observed shared Gemma tanh PTX failure. Q4_K/Q6_K
  specialization passes the same 35 real-weight oracle values; 52,210 physical
  RoPE/residual/SiLU/GQA values match independent NumPy calculations. Broader
  logits, Gemma on Turing and arbitrary GPU/model support remain unproved.
- **First independent 3B logit gate (2026-10-01):** The opt-in native probe and
  pinned CPU llama-cpp-python reference compare 513024 final-prompt logits across
  four public cases, exact input IDs through 1070 tokens, context 4096/F16 KV.
  An explicit independently expanded F32 artifact preserves the packed weight
  values. All cases pass predeclared 0.05 maximum / 0.005 RMS / matching-argmax
  budgets; actual worst errors are 0.0127416 / 0.0017844. The initial same-byte
  packed CPU reference fails these budgets and is preserved, with Q8_K activation
  arithmetic explaining the reference difference. Production compute/weights are
  unchanged. [Operation and evidence](docs/SPEED_MEASUREMENT.md). Status stays
  partial: this does not cover every decode position or certify quality parity.
- **Owned native CUDA trace (2026-10-01):** Two matched unprofiled/profiled public
  CLI cases admit 30224/450082 successful unique launch/kernel correlations and
  actual API/copy intervals. A bounded read-only parser rejects incomplete/foreign
  evidence. Split-package importer recovery needs no installation or permission
  changes. [Evidence](docs/evidence/native-cuda-trace-2026-10-01/README.md). This is
  instrumentation evidence, not faster compute or broad CUDA certification.
- **Optional matrix primitive (2026-10-01):** Native shared-tile SIMT candidate
  physically passes 1,658,880 complete real native-reference outputs, 2100 selected
  independent Float64 dots and 144 synthetic tail cases under fixed primitive
  budgets. Batch 4 is slower, so no normal inference dispatch is changed.
  [Evidence](docs/evidence/packed-matrix-2026-10-01/README.md). Full-model matrix
  integration and a general faster prefill capability remain unearned. Subsequent
  six-choice shared-tile tuning passes all fixed primitive gates but no batch-four
  speed gate; [rejection evidence](docs/evidence/matrix-tile-tuning-2026-10-01/README.md)
  is retained. No tuned choice enters default inference.
- **Optional Turing prerequisite (2026-10-01):** Public m16n8k8 F16/F32 MMA
  executes on actual sm_75 with an isolated matching PTX6.5 target. All50688
  independent exact synthetic outputs,5400 guards and9 invalid spans pass.
  Offline emitted-PTX disassembly includes HMMA.1688.F32. Pinned PTX6.3 compile/
  JIT failures remain; no installed dependency or production target is patched.
  [Operation](docs/NATIVE_TURING_MMA.md). Real-weight F16 quality and full-model
  acceleration remain open; the existing capability status stays partial.
- **Optional packed Turing candidate (2026-10-01):** Split-weight F16 high/residual
  operands and public F32-accumulating MMA pass all1,658,880 native-reference
  outputs and2100 selected independent real dots under unchanged primitive
  budgets.144 synthetic tails/12 invalid spans pass. Initial single-F16 precision
  failure remains. All28 timing cases lose, with no inference promotion.
  [Operation](docs/NATIVE_PACKED_TURING_MATRIX.md). Full-model activation precision,
  control/state and provider-speed gates remain open; status stays partial.
- **Shared Turing refinement (2026-10-01):** Three bounded CTA row choices pass
  all4,976,640 native values/6300 selected independent dots and432 synthetic tails.
  The64-row/batch32 FFN gate primitive reaches1.92x existing equal work, with
  shape-specific gains. V and every batch4 shape still lose. Shared bytes<=10560;
  no global workspace or production dispatch. Same operation manual/evidence
  retains every1680 sample; no full-model/control/provider promotion.
- **Wider Turing refinement (2026-10-01):** Four explicit32/64-row and64/128-input
  choices pass all6,635,520 native values,8400 selected independent dots,576
  synthetic tails and48 rejected spans. All2240 timing records remain. Shared
  bytes<=41280; wider choices underperform prior32-column staging. Default remains
  unchanged. [Evidence](docs/evidence/turing-wide-staging-2026-10-01/README.md).
  Ordinary F32 activation and full-model/control/provider quality gates stay open.
- **Captured F32 input gate (2026-10-01):** Two actual native final-layer public
  prompt captures pass all1,990,656 complete projection outputs and2520 selected
  independent dots under unchanged budgets, with114688 exact exported source
  values/whole guards.114677 inputs require F16 rounding; none overflows. Q/K/V
  use representative FFN-normalized sources; output/gate/up/down use actual
  operands, and batch32 repeats four sources. [Evidence](docs/evidence/turing-activations-2026-10-01/README.md).
  No complete-model, control/state or timing/provider promotion; status stays partial.
- **Isolated matrix-model gate (2026-10-01):** Four public final-prompt vectors,
  all513024 values per mode, pass fixed independent .05/.005/matching-argmax
  gates through1070 input IDs. Exact repeats/commits, eight invalid tiles and4352
  guarded cells pass. Fresh long prefill median12.717s versus7.578s, ratio1.678,
  in an isolated32-token native fixture. Tail-only small cases lose slightly.
  [Evidence](docs/evidence/turing-model-prefill-2026-10-01/README.md). Normal
  core/CLI/service admission remains unchanged; control/generation/restore,
  broader context/quality and provider lead remain open. Status stays partial.
- **Activation-residual refinement (2026-10-02):** Three precision sessions pass
  all5,971,968 captured native values/7560 selected independent dots. Every
  original independent .05/.005/argmax model gate passes, with exact repeats/
  commits and13056 guards. Three/four-term long native RMS .00092567/.00072338
  misses the additional predeclared .0005 target; both refinements are rejected
  and every ratio is withheld. [Evidence](docs/evidence/turing-activation-residual-2026-10-02/README.md).
  All96 raw timing records remain. Next separately scope scaled residual storage;
  no normal admission or status promotion follows.
- **Scaled residual experiment (2026-10-02):** Three captured-input sessions pass
  all5,971,968 native values/7560 independent dots. Every original independent
  model gate and13056 guards pass, but modes3/4 long native RMS .00113806/
  .00122564 miss the unchanged stricter .0005 goal. Both are rejected and their
  speed ratios withheld, with all96 timings retained. Captured mode4 RMS improves
  about241x without earning complete-model acceptance. [Evidence](docs/evidence/turing-scaled-residual-2026-10-02/README.md).
  Next harden checked workspace/profile/device admission for original passing
  mode0. Normal runtime admission and partial status remain unchanged.
- **Fixture ownership admission (2026-10-02):** Exact strict3B/context1536 geometry,
  observed capability7.5, canonical normal layout, checked headroom and every
  actual field/span reject drift before extra allocation or tile mutation.
  Master188 cases pass/one fixture skip. New complete mode0 independent gates
  and byte-identical previous vectors preserve1.676x long fixture prefill, with
  all4352 guards/eight invalid tiles. [Evidence](docs/evidence/turing-fixture-admission-2026-10-02/README.md).
  Normal policy/status remain unchanged; larger-tile control/recovery gates follow.
- **Fixture control/reset acceptance (2026-10-02):** Actual10ms timeout after2
  synced layers, SIGINT after8 and pre-expired/invalid-descriptor aborts preserve
  uncommitted position/IDs and require explicit reset. All513024 recovered values
  per mode match previous case1 bytes with unchanged allocations/9792 guards.
  Observer exception poisons four reuse/reset operations; owner mask restores.
  Master189 passes/one skip. Disabled mode0 independent/byte-regression gates
  preserve1.676x long fixture prefill. [Evidence](docs/evidence/turing-fixture-controls-2026-10-02/README.md).
  No hard deadline, actual GPU-fault repair or production/provider promotion;
  generation/sampling/restore and broader contexts remain separate gates.
- **Fixture decode/replay acceptance (2026-10-02):** Public37/1070-token prefixes
  each complete greedy32/seeded16 caps; all12312576 logit values per mode pass
  unchanged independent/native .05/.005/argmax gates. All96 actual sample choices
  agree, own fresh vectors replay bit-exactly, committed IDs/state/draws and4352
  fixture guards pass. Worst matrix/CPU max.02834225/RMS.0039867654. Nine portable
  streaming contracts pass; no whole680806792-byte CSV load or speed score.
  [Evidence](docs/evidence/turing-decode-quality-2026-10-02/README.md). Native-forced
  trajectories only; restoration, production32 admission, broader contexts and
  provider lead remain open. Status stays partial.
- **Owning-context checkpoint replay (2026-10-02):** Copied/checksummed exact
  tile/ID/policy/draw/pending/allocation plans refuse damage before reset/GPU work.
  Greedy/seeded public37 plus eight-scalar checkpoints each produce four before/
  after predictions; all1026048 logits per mode pass unchanged independent/
  native budgets, accepted-source/sample binding and actual own F32 bits.
  Twelve damaged-plan refusals preserve state/allocations;4352 fixture guards
  pass. Master190 passes/one skip and nine streaming contracts pass. [Evidence](docs/evidence/turing-checkpoint-replay-2026-10-02/README.md).
  Same process/context in-memory replay only; persisted schema/context recreation/
  long-history/runtime32/provider gates remain open. No time score/status promotion.
- **Optional batched rotary/cache (2026-10-02):** Disjoint four/32 grid-y rows
  reuse original F64/F32 rotation and F16 stores before unchanged causal reads.
  Both complete513024-value model owners/public IDs match prior accepted bytes;
  all176160832-byte guarded-cache hashes match. Actual host rotary/cache calls
  reduce89880 to3192 on1070 inputs. Fresh native/fixture medians13.0394/7.43515s
  earn1.75375x exploratory fixture ratio, with all64 baseline/new raw timings.
  Complete96-frame decode and eight-frame checkpoint independently pass unchanged
  numerical/sample/state/own-bit/source/guard gates. Strategy drift refuses before
  reset; master190 passes/one skip and six new portable contracts pass. [Evidence](docs/evidence/turing-batched-rope-cache-2026-10-02/README.md).
  No added global workspace, production kernel/body/admission or provider status
  promotion. Full cache hashing/export and continuation durations are unscored.
- **Optional batched elementwise (2026-10-02):** Separate3072/33824 strided
  RMS sibling groups four warps per CTA; disjoint residual/SiLU cells retain each
  token's original arithmetic and stream dependencies. Every513024-value model
  owner/public ID/F32 byte and full guarded-F16-cache SHA equals accepted1.
  Long actual elementwise host calls5321 versus original149801 plan, unchanged
  rotary/cache3192 calls. Fresh native/fixture medians12.8261/6.94205s earn1.84759x
  exploratory fixture ratio; all32 raw timings remain. Complete96-frame decode/
  eight-frame checkpoint independently repeat original quality/sample/state/bit/
  source/guard gates. Master190 passes/one skip and seven grid contracts pass.
  [Evidence](docs/evidence/turing-batched-elementwise-2026-10-02/README.md).
  No added global workspace, production definitions/admission or provider status
  change. Enabled controls on this new strategy remain a separate physical gate.
- **Enabled batched controls (2026-10-02):** Actual strategy2 pre-expired/10ms/
  owned-SIGINT/invalid-fd aborts at0/2/8/0 synchronized layers. Healthy drains
  preserve uncommitted position/IDs and require explicit reset; three reuse
  operations refuse without mutation. Reset preserves allocations/weights and
  all513024 recovered values per owner equal accepted2 F32 bytes. All9792 guards,
  caller-owned signal consumption/mask and observer-exception poison/refusal
  gates pass. Eleven portable control contracts additionally bind matching
  strategy/full independent source/scope/CSV/report hashes, including mutation/
  interrupt failure retention. [Evidence](docs/evidence/turing-batched-controls-2026-10-02/README.md).
  No hard real-time/GPU-fault-repair/runtime/provider promotion or speed score.
- **Owned prefill timeline (2026-10-02):** Public37/1070 plain/profiled strategy2
  preserves all513024 complete source F32 values, full guarded-cache hashes,
  actual committed IDs/state/host counts and4352 guards. Full-session CUDA owner/
  timestamp/unique-successful-correlation validation precedes same-thread named
  NVTX selection;4837/120919 kernels pass. Original NVTX-triggered and UTC export
  time-domain failures remain rejected. Long observed staged matrix durations
  account65.43%, attention21.47%, without a speed score. Master190 passes/one skip,
  30 trace and eight source/report contracts pass. [Evidence](docs/evidence/turing-prefill-trace-2026-10-02/README.md).
  Original arithmetic/production one/four admission remain unchanged; shared
  kernel names do not certify per-projection attribution or service speed.
- **Projection attribution (2026-10-02):** Default-disabled NVTX labels bind
  actual loaded tensor offset/kind/shape and source32/4/1 tiling. Public37/1070
  preserve all513024 source F32/cache/state values/4352 guards;589/7449 disjoint
  same-thread child ranges attribute981/20385 successful projection kernels.
  Exact launch correlations project asynchronous GPU durations without adding
  synchronization or clipping. Eight attribution/nine probe contracts pass;
  all original trace/model/control/decode/checkpoint gates remain. Long batch32
  FFN gate/up/down3.46973s (52.04% recorded kernel duration), down largest1.26654s.
  [Evidence](docs/evidence/turing-projection-trace-2026-10-02/README.md).
  No speed score/per-layer timing or new arithmetic/buffer/dispatch/promotion.
- **Header reuse rejection (2026-10-02):** Separate optional rows64/width32/
  precision0 cached-header kernel preserves original entry and all1658880 output
  bits,2100 selected independent dots,144 synthetic/12 invalid spans/1622640
  guards. Thirty rotating three-owner records per case retain840 timings.
  Batch32 gate/up/down original-to-cached .6843/.6890/.9025 reject the speed
  candidate; cache_headers stays False. Fourteen portable contracts/master190
  passes/one skip. [Evidence](docs/evidence/turing-block-headers-2026-10-02/README.md).
  No measured register/occupancy cause, full-model or provider promotion.
- **Larger row CTA experiment (2026-10-02):** Separate128-row sibling shares
  padded F16 inputs across eight warps/256 threads, maximum19008 shared bytes.
  Original core definitions stay verbatim. Final1658880 original F32 bits/2100
  selected independent dots/144 synthetic/12 spans/1622640 guards/840 rotating
  records pass. Batch32 down improves1.10414x; gate/up .76896/.76027 lose. Initial
  256 launch fails CUDA_ERROR_LAUNCH_OUT_OF_RESOURCES; all evidence stays and final
  kernel/wrapper/CLI/checker remove256 admission, physically refusing pre-model.
  Sixteen portable contracts/master190 passes/one skip. [Evidence](docs/evidence/turing-large-rows-2026-10-02/README.md).
  Narrow primitive result only; no full-model/runtime/provider promotion.
- **Down-only captured F32 gate (2026-10-02):** Only batch32 final-layer down
  selects128; all1990656 new/original F32 bits, native/original accepted bytes and
  114688 actual public source inputs/states match prior precision0 proof. Fixed
  native/original/2520 independent dots/1938600 guards/12 spans pass. Strict source
  full report/totals/budget/row/model/CSV/state identities and all after-oracle
  capture/source/model rehashes bind acceptance. Ten portable contracts/master190
  passes/one skip. [Evidence](docs/evidence/turing-down-activations-2026-10-02/README.md).
  Two final-layer captures, batch32 repeated four/QKV representative FFN norm;
  no full-model/state/control/speed/provider promotion.
- **Down128 full-model strategy3 (2026-10-02):** Default-disabled128 selects only
  loaded FFN-down/count32/canonical spans, precision0/batched elementwise required.
  All513024 native/matrix F32 values per owner, actual IDs/committed state and all
  full guarded-cache hashes match accepted2. Fixed CPU budgets/own fresh F32 bits/
  4352 guards/eight invalid tiles pass; actual down calls0/28/0/924. Pre-model bad
  flags and pre-step trace/control refuse without mutation; replay/other readers
  still refuse3. Long paired12.66775/6.80087s=1.86267x exploratory native/new ratio.
  Eight contracts/master190 passes/one skip; scores atomic/finite and derivation/
  source/capture/model hashes recheck. [Evidence](docs/evidence/turing-down-model-2026-10-02/README.md).
  No old2/new3 timing ratio, trajectory/replay/control/trace/runtime/provider claim.
- **Down128 decode/sample trajectory (2026-10-03):** Explicit strategy3 passes all
  96 frames/12312576 F32 values per owner, public37/1070 greedy32/seeded16,
  unchanged .05-max/.005-RMS/argmax CPU/native gates, sample equality, causal IDs/
  positions/history/draws,4352 guards and exact own fresh F32-bit replay. Initial
  vectors equal accepted3 model case1/3 bytes including signed zero; actual down
  calls remain28/924 after replay. Matrix CPU worst .028342247/.003986765.
  Nine adversarial contracts/master190 passes/one skip. Explicit accepted3 source
  complete numeric/owner/counter/cache/ID/predecessor proof, strict JSON and all
  post-oracle artifact hashes bind acceptance; cleanup interrupts publish failure.
  [Evidence](docs/evidence/turing-down-decode-2026-10-03/README.md). Native-forced
  trajectory only, always unscored. No free-running candidate, sealed strategy3
  replay/enabled-control/production32/broader context/device/concurrency/soak/provider
  admission. Normal f3442a1e remains active/authenticated ready/prefill4.

- **Down128 sealed owning-context replay (2026-10-03):** Two45-ID checkpoints/
  eight continuations/1026048 full-vocabulary values per native/matrix/restored
  owner pass exact F32 bits, causal/sample/draw/config/allocations/tile/source/
  independent .05-max/.005-RMS/argmax gates and4352 guards. Matrix CPU worst
  .009345055/.001675504; down calls28 before/after. Pure strategy3 owner/seal/
  unsupported4/native-mode admission and execution flags check before reset.
  Eighteen damaged-plan/flag refusals preserve healthy state/counters/ownership.
  Seven portable contracts/master190 passes/one skip. Explicit SHA-bound3 full96
  decode/model/numeric/causal/replay/source proof and all post-oracle artifact
  hashes gate acceptance. Preliminary capture retained; final strengthens explicit
  counter/allocation comparisons after each refusal. [Evidence](docs/evidence/turing-down-checkpoint-2026-10-03/README.md).
  Same-process owning-context replay only, always unscored; no persisted/crash/
  context recreation/free-running candidate/controls/tracing/runtime/provider gate.
- **Down128 opt-in cooperative recovery (2026-10-03):** Separate final capability
  False preserves ordinary down128 refusal; True preflights down/profile/flags
  before model/configure/start/step/replay reset. Disabled capable source retains
  all513024 native/matrix F32 values/IDs/full cache against prior2/prior3, unchanged
  CPU/own fresh bits/4352 guards/eight invalid tiles/32 paired records. Explicit
  capability/source Boolean/numeric/hash proof binds controls. Actual healthy
  aborts at0/2/8/0 synced layers/down calls require reset/uncommitted state; three
  reuse refusals preserve state. Reset recovers all513024 exact values per owner,
  down28, actual allocations and owned SIGINT/mask. Observer poison at1 layer/call
  refuses four reuse/reset operations; all9792 guards pass. Six contracts/master190
  passes/one skip. [Evidence](docs/evidence/turing-down-controls-2026-10-03/README.md).
  Disabled long paired native/new12.70594/6.83303s=1.85949x exploratory only;
  control speed_claim=False. No hard real time/GPU-fault repair/production32/
  broader-context/device/concurrency/soak/free-running/persisted/provider gate.
- **Down128 owned projection/resource trace (2026-10-03):** Explicit default-disabled
  trace capability and balanced down dispatch preserve full source F32/cache/IDs/
  counters/guards on plain/profiled37/1070. Full4837/120919 kernel resources and
  unique successful correlations precede589/7449 exact ordered child ranges and
  981/20385 projection kernels. Down32 grid24/block256/static19008/register255;
  gate/up/down long51.9283% summed kernel time is diagnostic only. Ten contracts/
  master190 passes/one skip; no occupancy/spill/256-failure cause/service ratio.
  [Evidence](docs/evidence/turing-down-projection-trace-2026-10-03/README.md).
- **Narrow16-column primitive experiment (2026-10-03):** Both64/128 rows pass
  complete1658880 native/candidate/original64 F32 bits/2100 selected dots/1622640
  guards/144 synthetic/12 spans/840 rotated timings per configuration. All56
  original64 comparisons lose (best.946255); no speed/default promotion. Defined
  shared5440/9792 bytes is not observed register/occupancy proof. Nineteen portable
  contracts/master190/one skip, finite atomic underflow/overflow failure retention.
  [Evidence](docs/evidence/turing-narrow-staging-2026-10-03/README.md).
- **Bounded runtime-group32 staging (2026-10-03):** Separate optional module
  retains original quantization/core bodies and sequential F32 MMA. Both64/128
  configs pass144 synthetic/12 spans/1658880 complete original64 F32 bits/2100
  independent dots/1622640 guards/840 rotated times. All56 original64 comparisons
  lose (best.826220); no promotion or inferred register/occupancy cause.22 portable
  contracts/master190/one skip and finite atomic failure retention.
  [Evidence](docs/evidence/turing-loop-staging-2026-10-03/README.md).
- **Paired gate/up primitive (2026-10-03):** Separate optional same-kind kernel
  shares input staging across64 rows per tensor. Both original spans and pair
  weight/output alias fences run before enqueue. Real Q4/Q4 passes983040 values
  per owner with original F32 bits, fixed native budgets/600 independent dots,
  6720 guards/144 synthetic pairs/12 spans/all120 rotated timings. Batch4 beats
  staged (1.136289) but loses native; batch32 loses staged (.778242). No selection.
  Ten portable contracts/master190/one skip; retained incorrect guard-formula
  checker failure and successful new report on unchanged physical CSV.
  [Evidence](docs/evidence/turing-paired-ffn-2026-10-03/README.md).
  Deterministic inputs checked natively, not actual model activations.
- **Fused attention complete model (2026-10-03):** Final default-disabled
  capability requires original strategy3 flags with controls/tracing closed.
  Count4/32 uses checked actual F32 query/canonical attention/full layer cache,
  count1 original path. Actual fused196/56/196/1008 and original queries56/28/84/56
  reset and bind tile plan. All513024 full logits per owner/IDs/full guarded F16
  cache match accepted3 exactly, unchanged CPU .05/.005/argmax and own repeat/
  4352 guards/eight invalid tiles/32 paired timings pass. Seven contracts/master190
  and one skip; source3 full CPU/bytes/cache/counters plus binary before/after
  bind explicit CLI4 while default readers/replay/controls/tracing stay closed.
  [Evidence](docs/evidence/fused-attention-model-2026-10-03/README.md).
- **Fused attention causal decode (2026-10-03):** All96 frames/12312576 full
  values per owner retain source4 initial F32 bits, independent fixed CPU budgets,
  native-forced causal IDs, greedy/seeded samples/state, fresh own UInt32 replay
  and4352 guards. Actual fused/down counters stay while scalar original queries
  advance. Eleven contracts/master190/one skip; explicit exclusive source triplet
  and current binary SHA before/after. Default4 readers/sealed replay/control/trace
  remain closed; process times unscored.
  [Evidence](docs/evidence/fused-attention-decode-2026-10-03/README.md).
- **Fused sealed replay (2026-10-03):** Explicit copied plan/live4 capability
  binds pre-reset/enqueue allocation/profile/span/health admission.45-ID two-policy
  checkpoints/eight full continuation frames per owner retain all four vectors/
  UInt32 baseline/restored bits/source samples/state/independent CPU/4352 guards.
  28 damaged-plan/flag refusals preserve owners/health/state/counters; actual down28/
  fused56/original252/364 bind tile/reset boundaries. Nine contracts/master190/one
  skip; source report/accepted decode binary/current binary SHA before/after.
  Ordinary4/source readers stay closed without opt-in; same-process/unscored only.
  [Evidence](docs/evidence/fused-attention-checkpoint-2026-10-03/README.md).
- **Fused cooperative controls (2026-10-03):** Optional final fused_controls
  capability retains ordinary4 refusal, excludes legacy control/trace flags and
  control-capable4 sealed replay. Fresh disabled-capable4 full-model vectors/IDs/
  cache/CPU/own bits/guards/timings match accepted default4 with actual current/
  predecessor binary SHA. Enabled healthy synced abort/reset recovery retains
  all513024 source vectors per owner/allocations/actual layer counters/mask/9792
  guards. Unexpected observer exception poisons/refuses all reuse.15 adversarial
  contracts/master190/one skip; enabled times unscored, not GPU-fault repair.
  [Evidence](docs/evidence/fused-attention-controls-2026-10-03/README.md).
- **Next acceptance gate:** Strategy4 owned tracing and control-capable sealed replay, then broader model/hardware/persisted/context/concurrency/soak/runtime prefill/provider acceptance.
- **Audit:** AER-043, AER-094, AER-095, AER-003.

### AES-ACC-009 — Direct mmap-to-GPU zero-copy model weights

- **Status:** `missing`
- **Owner:** loader and hardware domains
- **Claim sources:** README zero-copy explanation says the GPU points directly to the file
- **Implementation evidence:** verified mmap pointers are consumed by CPU code; there is no GPU mapping/registration path.
- **Executable evidence:** none on a GPU.
- **Evidence boundary:** OS mmap into CPU virtual memory is not direct storage-to-VRAM access.
- **Next acceptance gate:** Specify an achievable backend-specific memory contract and prove mapping/transfer behavior, lifetime, synchronization, and measured copies on hardware.
- **Audit:** AER-003, AER-039, AER-094.

### AES-ACC-010 — Bounded shared-score causal CUDA GQA primitive

- **Status:** `verified`
- **Owner:** core attention and measurement domains
- **Claim sources:** SPD-03 and docs/NATIVE_FUSED_CAUSAL_ATTENTION.md
- **Implementation evidence:** Optional fused_causal_attention uses4096 shared
  F32 scores per128-thread CTA for24/8/128 GQA, original score/softmax/value
  arithmetic and all stage barriers. Pure borrowed-span/alias/causal admission
  plus compatible CUDA fence precede enqueue. Allocation-bound stride admits33824.
- **Executable evidence:** Locked opt-in native probe and check_fused_causal_attention
  full NumPy2.4.4 Float64 oracle: all39 cases/1370112 outputs per owner/original
  F32 bits/364518 guards/full1370112 query and82194432 KV cells/16 refusals/780
  rotated timing records pass on RTX2060 Max-Q sm75. Nine portable contracts,
  master190 passes/one explicit skip; hosted compile is distinct from physical proof.
- **Evidence boundary:** Deterministic exact dyadic/zero/large-logit inputs,
  history endpoints1..4096, batch capacities1/4/32 with tested partial tails;
  no actual model Q/K/V or general shape claim. Full4/32 improve in one physical
  session, long single-query histories lose. No selection or service/provider
  promotion; defined shared count is not observed occupancy/register evidence.
  [Complete evidence](docs/evidence/fused-causal-attention-2026-10-03/README.md).
- **Next acceptance gate:** Actual model/source-bound complete logits/cache/IDs/
  causal/sample/CPU quality; generation/replay/controls/context/device/concurrency/
  soak/runtime gates, retaining the original single-token path.
- **Audit:** AER-047, AER-048, AER-112.

## 15. External Ecosystems

### AES-ECO-001 — Hugging Face repository-tag normalization

- **Status:** `verified`
- **Owner:** loader domain
- **Claim sources:** completed Hugging Face TODO and loader interface
- **Implementation evidence:** `HuggingFaceSeer.is_hf_tag` and `parse_hf_repo` in `loader/huggingface.mojo` recognize bare `owner/name` identities and the exact `hf.co` / `huggingface.co` HTTP-free or HTTPS prefixes. Admission requires exactly two nonempty safe path segments and rejects unrelated schemes/hosts, traversal, queries, duplicate separators, extra segments, and bare names.
- **Executable evidence:** `E-MASTER` case `huggingface.tag_parser` in `test_huggingface.mojo`.
- **Evidence boundary:** This validates and normalizes public repository identity strings only; it does not query Hub existence, permissions, revisions, files, or model compatibility.
- **Audit:** AER-082.

### AES-ECO-002 — Hugging Face resolve-URL construction

- **Status:** `verified`
- **Owner:** loader domain
- **Claim sources:** Hugging Face loader interface
- **Implementation evidence:** `HuggingFaceSeer.build_download_url` in `loader/huggingface.mojo` constructing resolve URL shapes and validating non-empty `repo_id` and `filename` parameters.
- **Executable evidence:** `E-MASTER` case `huggingface.url_builder` in `test_huggingface.mojo`.
- **Evidence boundary:** Checked HTTPS resolve URL construction and empty parameter rejection bounds.
- **Audit:** AER-082.

### AES-ECO-003 — Hugging Face weight downloading

- **Status:** `partial`
- **Owner:** loader and CLI domains
- **Claim sources:** built-in `pull` command
- **Implementation evidence:** Native Mojo orchestration invokes curl and sha256sum with checked argv, HTTPS-only redirects, immutable revision, bounded transfers, resumable single-connection partials, optional parallel byte ranges, and exact size/SHA-256 verification. The parent directory and stage file are pinned by descriptors; transfer, header read, hash, file sync and exclusive hard-link publication act on the opened inode. Foreign replacement entries are not unlinked. Optional `--name` registration revalidates expected identity inside `DurableModelStore` before committing the manifest.
- **Executable evidence:** `E-MASTER`, `E-HF-RESUME`, `E-SPECIAL`, and eight live download integrity/resume/HTTP-failure/existing-file/symlink/store-registration checks. Both large pinned artifacts in `docs/GEMMA4_CUDA.md` and `docs/STHENO_CUDA.md` downloaded and verified in full through `pull`; the small registered fixture is recorded in `docs/evidence/hf-pull-store-2026-09-02.md`.
- **Evidence boundary:** Public pinned single-GGUF artifacts, single-connection restart continuation and explicit store registration on Linux/WSL. Exact publication after path replacement is proved on native Linux storage; non-POSIX WSL DrvFS rename behavior may cause a safe checksum failure instead. Multi-connection transfers are nonresumable. No authentication exists. System curl, sha256sum and Linux procfs are explicit dependencies.
- **Next acceptance gate:** Authentication, explicit cancellation UX, and store-aware transfer staging.
- **Audit:** AER-082, AER-003.

### AES-ECO-004 — ONNX model parsing and execution

- **Status:** `partial`
- **Owner:** loader and optional ecosystem domains
- **Claim sources:** completed multi-engine TODO; loader interface
- **Implementation evidence:** Native Mojo safely opens and read-only maps an ONNX file, decodes bounded protobuf wire data, extracts real IR/producer/default-domain opset metadata, walks `GraphProto.node` entries, counts inputs/outputs, validates UTF-8 and recognizes a declared operator metadata subset. Parsing is transactional; malformed/truncated/overflowing data and unrecognized operators are rejected. Initializer mapping and execution raise unsupported.
- **Executable evidence:** `E-MASTER` cases `onnx.model_seer`, `onnx.recognized_operators`, `multi_engine.onnx_unavailable`, and `multi_engine.cli_unsupported`; the parser case covers in-memory and file-backed valid wire fixtures, FIFO refusal, truncation, sentinel pointers, state rollback and unknown operators.
- **Evidence boundary:** The fixture proves protobuf metadata decoding only. TensorProto initializers, attributes, graph type/shape validation, planning, kernels, ONNX Runtime comparison and CLI execution are not implemented.
- **Next acceptance gate:** Parse a pinned ONNX conformance model including tensors/types/shapes/attributes, execute a deliberately bounded operator subset, and compare outputs with ONNX Runtime.
- **Audit:** AER-081, AER-003.

### AES-ECO-005 — ExLlama/EXL2 conversion and inference

- **Status:** `missing`
- **Owner:** CLI and optional ecosystem domains
- **Claim sources:** completed multi-engine and compressed-format TODOs
- **Implementation evidence:** CLI dispatch, byte parsing, tensor mapping and execution all raise explicit unsupported errors. The loader starts with zero measured metadata; its only working operation validates caller-declared 2..8 bpw descriptor values and computes their weighted average without presenting them as parsed model state. The old invented `EXL2` magic and fixed 4.25 bpw value are gone.
- **Executable evidence:** `E-MASTER` cases `exl2.cuda_contract`, `exl2.model_seer`, and `multi_engine.cli_unsupported` cover bypass refusal, zero initial state, invented-header rejection, descriptor validation/average and mapping refusal.
- **Evidence boundary:** No EXL2 config/safetensors parser, conversion, CUDA kernels, cache, model, or ExLlama oracle.
- **Next acceptance gate:** Either remove/relabel the unsupported promise with approval or implement a separately scoped real EXL2 fixture and parity gate.
- **Audit:** AER-054, AER-081, AER-003.

### AES-ECO-006 — llama.cpp CLI subcommand compatibility

- **Status:** `missing`
- **Owner:** CLI and optional ecosystem domains
- **Claim sources:** completed multi-engine TODO and CLI interface
- **Implementation evidence:** The public dispatcher, subcommand contract and formerly detached flag parser all raise explicit unsupported errors. `is_supported_llama_cpp_subcommand()` returns false for every command; no completion, health, benchmark, parser or perplexity behavior is presented as compatible.
- **Executable evidence:** `E-MASTER` cases `llama_cpp_cli.subcommands`, `llama_cpp_cli.arg_parsing`, and `multi_engine.cli_unsupported` cover former CLI/server names and a representative flag vector.
- **Evidence boundary:** `LlamaCppCLIConfig` is an inert compatibility descriptor. The real pinned oracle comparison verifies Aesir's narrow token output, not llama.cpp CLI argument/output compatibility.
- **Next acceptance gate:** Define supported commands/version and pass differential parsing, execution, output, error, and exit-code fixtures.
- **Audit:** AER-080, AER-081, AER-101.

### AES-ECO-007 — Limited grammar-shaped token checks and logit-mask bounds

- **Status:** `verified`
- **Owner:** core optional grammar domain
- **Claim sources:** completed multi-engine TODO
- **Implementation evidence:** `GBNFGrammar` implements token-text-aware prefix automata for exact JSON booleans and JSON numbers. It tracks committed text and accepting state, masks caller logits only after validating a same-length decoded-token list, rejects null/sentinel pointers and empty/all-invalid candidate sets, and refuses the legacy token-ID-only API. Separately, S23's `BooleanJSONGrammar` constrains native CUDA output to the two canonical tokenizer encodings of `true`/`false`; strict OpenAI `response_format` admission and exact tokenizer round-trip checks precede decoding, and the sampler selects only allowed continuation logits.
- **Executable evidence:** `E-MASTER` cases `gbnf.token_validation_masking` and `multi_engine.grammar_mask` cover the legacy bounded grammar. S23 focused `test_gbnf_grammar.mojo` and `test_local_protocol.mojo` pass; `scripts/test_boolean_json_live.py` independently parses real Gemma E2B CUDA chat/completion output as a JSON boolean in both native and Ollama service modes, observes early `stop`, and proves malformed/unsupported schema refusal before generation. The final binary also passed 31 v1 HTTP fixtures.
- **Evidence boundary:** No general GBNF/EBNF parser, JSON object/array grammar, or arbitrary JSON Schema generation. Only canonical Boolean literal token sequences are integrated, not every possible tokenizer spelling. Llama/Qwen paths compiled but were not physically exercised in S23.
- **Next acceptance gate:** Parse a versioned broader grammar subset and pass differential model/tokenizer fixtures against an independent grammar implementation; physically exercise the Llama/Qwen Boolean path.
- **Audit:** AER-108.

### AES-ECO-008 — Speculative token probability-ratio acceptance primitive

- **Status:** `verified`
- **Owner:** core optional generation domain
- **Claim sources:** completed multi-engine TODO
- **Implementation evidence:** `SpeculativeEngine.evaluate_acceptance()` validates aligned caller-observed token/probability/draw sequences and computes the standard sequential `min(1, p_target/p_draft)` acceptance prefix. It reports accepted tokens, the first rejected token and an arithmetic KV step marker. Invalid IDs, sizes, limits, probabilities, draws and starting steps are rejected. Legacy logits/pointer proposal and reconciliation APIs raise unsupported.
- **Executable evidence:** `E-MASTER` cases `speculative.proposal_verification`, `speculative.rejection_rollback`, and `multi_engine.speculative_acceptance` cover ratio boundaries, ordered prefix/rejection results, KV marker arithmetic, invalid probabilities/lengths and legacy refusal.
- **Evidence boundary:** No draft-model loop, batched target verification, residual correction sampling, KV mutation/rollback, distribution-equivalence proof or speed evidence exists. The result's KV field is arithmetic metadata only.
- **Next acceptance gate:** Integrate real draft/target model sessions and KV transactions, implement residual-distribution sampling, prove target-distribution equivalence, then measure speed on reproducible workloads.
- **Audit:** AER-109, AER-110.

## 16. Resilience and Concurrency

### AES-RES-001 — Sentinel-address, index, and logit guard helpers

- **Status:** `verified`
- **Owner:** core safety domain
- **Claim sources:** completed resilience TODO
- **Implementation evidence:** `ErrorGuard` in `core/error_guard.mojo` checks null (`0`) and sentinel (`1`) addresses (`addr != 0 and addr != 1`), tests individual index bounds, and sanitizes NaN/Inf logits in a caller-owned buffer. The mutating sanitizer raises on sentinel pointers and nonpositive counts instead of returning as though work occurred.
- **Executable evidence:** `E-MASTER` case `resilience.error_guard` in `test_resilience.mojo` covers normal replacement plus explicit sentinel-pointer and zero-count refusal.
- **Evidence boundary:** A non-sentinel address is not proof of allocation provenance, accessible span, alignment, lifetime, or synchronization. Sanitization requires the caller already to own a valid buffer of the declared count.
- **Audit:** AER-005, AER-105.

### AES-RES-002 — Restart-safe checkpoint marker records

- **Status:** `verified`
- **Owner:** core resilience domain
- **Claim sources:** completed resilience TODO
- **Implementation evidence:** `StateVault` stores non-negative token-position and prompt-count markers with an observed or explicit positive timestamp. Its bounded versioned disk record uses a deterministic corruption checksum, strict field order/count/decimal parsing, shared strict persisted-text admission, final-symlink refusal on reads, staged file sync, atomic same-directory replacement, and parent-directory sync. Failed validation/read/write does not replace the active in-memory marker.
- **Executable evidence:** `E-MASTER` cases `resilience.state_vault_marker` and `resilience.durable_state_vault` cover observed timestamps, bounds, restart loading, malformed-record, malformed-UTF-8 and FIFO refusal, checksum corruption, invalid fields, and state non-mutation.
- **Evidence boundary:** This records two positions; it does not snapshot model weights, tensors, KV data, sampler state, processes, threads, or sockets. FNV-1a detects ordinary corruption but is not authentication. Writers are not locked or coordinated across processes.
- **Next acceptance gate:** Define a complete session-state schema and ownership model, add authenticated records if the marker crosses a trust boundary, serialize concurrent writers, and prove injected write/sync/permission/restart failures.
- **Audit:** AER-106.

### AES-RES-003 — Bounded synchronous local event journal and mailboxes

- **Status:** `verified`
- **Owner:** core resilience/concurrency domain
- **Claim sources:** completed resilience TODO
- **Implementation evidence:** `AesirEventBus` validates unique subscriber IDs and masks, journals up to 1024 events, synchronously copies matching records into per-subscriber 256-event mailboxes, checks all capacities before mutation, and supports ordered draining and unsubscribe. Event types and messages have explicit byte bounds.
- **Executable evidence:** `E-MASTER` cases `resilience.event_bus_marker` and `resilience.event_bus_pub_sub` cover invalid topics, mask filtering, ordered payload delivery, draining, and unsubscribe.
- **Evidence boundary:** This is synchronous in-process storage. It has no worker, lock, cross-thread/process transport, durable replay, acknowledgement, or retry semantics.
- **Next acceptance gate:** Define concurrency ownership, add synchronization or a single-owner runtime contract, and pass race, backpressure, reentrancy and failure-injection tests.
- **Audit:** AER-107.

### AES-RES-004 — Local task-list descriptor and worker-count bounds

- **Status:** `verified`
- **Owner:** core concurrency domain
- **Claim sources:** completed resilience TODO
- **Implementation evidence:** `RuneThreadPool` stores at most 256 unique, non-negative task descriptors with non-empty payload labels, supports pre-execution cancellation and admission shutdown, and records a clamped desired worker count. Both execution entry points raise without changing completion state; active-worker queries return zero.
- **Executable evidence:** `E-MASTER` cases `resilience.thread_pool_stub` and `resilience.task_descriptor_queue` cover bounds, cancellation, duplicate rejection, mutation-free execution refusal and shutdown.
- **Evidence boundary:** It creates no worker threads, invokes no payload/callback, synchronizes nothing, and provides no concurrency. `num_threads` is configuration intent only.
- **Next acceptance gate:** Implement bounded synchronized workers, real task execution, cancellation/shutdown semantics, and race/load tests.
- **Audit:** AER-089.

### AES-RES-005 — Self-healing crash recovery & checkpoint validation

- **Status:** `missing`
- **Owner:** core resilience domain
- **Claim sources:** completed resilience TODO and facade ACTIVE banner
- **Implementation evidence:** `SelfHealingSupervisor.simulate_crash_and_recover()` now rejects without changing health, recovery counters, vault state or event records. `pulse_heartbeat()` writes a local event only and explicitly does not inspect runtime health.
- **Executable evidence:** `E-MASTER` case `resilience.supervisor_recovery_unsupported` proves refusal and state non-mutation.
- **Evidence boundary:** No panic interception, process restart, model/KV/session restoration, backend switch, socket continuity, or fault recovery exists.
- **Next acceptance gate:** Define owned recoverable state and failure classes, implement an external lifecycle supervisor, then pass injected process/runtime failure and continuity tests.
- **Audit:** AER-106, AER-111, AER-003.

### AES-RES-006 — Caller-reported failure diagnostics

- **Status:** `verified`
- **Owner:** core diagnostics domain
- **Claim sources:** smart-crash TODO and architecture descriptions
- **Implementation evidence:** `SmartCrashReporter.record_failure()` validates bounded subsystem/message inputs before mutation, records consecutive caller reports and threshold state, applies a deterministic documented category rule, and emits a report that explicitly says no recovery action occurred. The legacy method name delegates to the same recorder and does not intercept crashes.
- **Executable evidence:** `E-MASTER` case `paradigms.failure_diagnostics` covers resource classification, threshold state, the no-recovery disclosure, invalid-input rejection and mutation-free failure.
- **Evidence boundary:** This is an in-memory formatter and counter. It does not intercept faults, persist logs, inspect execution context, call AI, restart anything, or switch hardware.
- **Next acceptance gate:** Integrate structured records with the real runtime owner and durable operator logging, with secret redaction and injected-failure evidence.
- **Audit:** AER-111, AER-003.

## 17. Swarm and Distributed Execution

### AES-SWM-001 — Peer roles, descriptors, and capacity arithmetic

- **Status:** `verified`
- **Owner:** core swarm domain
- **Claim sources:** completed swarm TODO and core interface
- **Implementation evidence:** `SwarmNodeRole`, `PeerNode`, and `PeerRegistry` in `core/swarm.mojo` provide role descriptors, zero-floor VRAM arithmetic, future-safe freshness checks, and pre-mutation validation of node ID, address, port, role, and timestamp.
- **Executable evidence:** `E-MASTER` cases `swarm.role_enum`, `swarm.peer_metrics`, and `swarm.registry_load_balancer` in `test_swarm_cluster.mojo`.
- **Evidence boundary:** These are caller-owned local records. They do not prove discovery, membership, authorization, encryption, or observed hardware capacity.
- **Audit:** AER-088, AER-114.

### AES-SWM-002 — In-memory least-used/capacity peer selection & empty cluster safety

- **Status:** `verified`
- **Owner:** core swarm domain
- **Claim sources:** swarm load-balancer interface
- **Implementation evidence:** `PeerRegistry` in `core/swarm.mojo` managing peer descriptors and identifying `get_least_loaded_node()`, validating non-empty candidate IDs (`len(best_id.bytes()) > 0`) and raising `Error` when no live peer nodes are registered.
- **Executable evidence:** `E-MASTER` case `swarm.registry_load_balancer` in `test_swarm_cluster.mojo`.
- **Evidence boundary:** Checked local peer load balancing string byte verification and empty cluster error boundaries.
- **Audit:** AER-114.

### AES-SWM-003 — Mesh join, liveness & parameter validation

- **Status:** `missing`
- **Owner:** core swarm and server domains
- **Claim sources:** completed swarm TODO; CLI/server interfaces
- **Implementation evidence:** `SwarmCluster` validates identity and equal-length credential bytes without content-dependent exits, validates leader/node parameters, returns false for heartbeat, and rejects authenticated/legacy join and leave operations without registering peers or activating the mesh. The facade contains no embedded credential.
- **Executable evidence:** `E-MASTER` cases `swarm.network_unsupported`, `swarm.node_authentication`, and `swarm.join_leave_heartbeat`.
- **Evidence boundary:** Local credential comparison and mutation-free refusal are not network authentication, anti-replay protection, encrypted transport, membership, or liveness.
- **Audit:** AER-114, AER-003.

### AES-SWM-004 — Distributed inference dispatch & task dispatcher parameter validation

- **Status:** `missing`
- **Owner:** core swarm and inference domains
- **Claim sources:** completed swarm TODO
- **Implementation evidence:** `TaskDispatcher` and `dispatch_remote_inference()` validate node/task and request/authentication bounds, then reject before selecting a peer, incrementing task state, or constructing a response. The engine facade also rejects instead of manufacturing a request ID or credential.
- **Executable evidence:** `E-MASTER` cases `swarm.network_unsupported` and `swarm.remote_inference_dispatch` cover invalid input, explicit refusal, and state non-mutation.
- **Evidence boundary:** No transport, remote model admission, streaming, cancellation, retry, idempotency, or execution exists.
- **Audit:** AER-114.

### AES-SWM-005 — Swarm REST and CLI operational status & subcommand bounds

- **Status:** `missing`
- **Owner:** CLI and server domains
- **Claim sources:** completed swarm TODO and interfaces
- **Implementation evidence:** `dispatch_cli_command()` in `cli/commands.mojo` enforcing subcommand validation (`len(args) <= 1 -> raises Error("swarm command requires a subcommand (join, status, list)")`) and raising unsupported error when subcommands are supplied; HTTP routes return 501.
- **Executable evidence:** `E-MASTER` cases `cli.truthful_command_boundaries` and `multi_engine.http_unsupported_responses` in `test_cli.mojo`.
- **Evidence boundary:** Checked CLI subcommand requirement validation and explicit unsupported HTTP/CLI route boundaries.
- **Audit:** AER-114, AER-003.

## 18. Benchmarks, Security, and Production Readiness

### AES-OPS-001 — Measured performance benchmarking & CLI dispatcher validation

- **Status:** `partial`
- **Owner:** performance and CLI domains
- **Claim sources:** llama-bench CLI surface and high-performance README language
- **Implementation evidence:** `dispatch_llama_cli()`, `dispatch_exl2_cli()`, and `dispatch_onnx_cli()` in `cli/multi_engine.mojo` enforcing parameter validation (`len(args) == 0 -> raises Error("CLI dispatcher arguments must not be empty")`) and rejecting unsupported benchmark/runtime surfaces.
- **Executable evidence:** `E-MASTER` case `multi_engine.cli_unsupported` in `test_multi_engine.mojo`.
- **Evidence boundary:** Checked dispatcher rejection remains separate from the narrow real HTTP comparator below. No general benchmark dispatcher or speed superiority is established.
- **Next acceptance gate:** Complete cache/residency isolation and multi-session varied-query/quality coverage, detailed first-token/uncached-load attribution and a validated native speed improvement; connect any public benchmark dispatcher only after its own contract passes.
- **Audit:** AER-101, AER-003.
- **2026-10-01 measured subset:** `scripts/benchmark_second_brain.py` records
  paired native/Ollama HTTP wall time, fixed public prompts, warmup, raw samples,
  medians, model/context/sampling policy, binary/source identity and failures.
  Optional comparator-blob hashing establishes equal local GGUF bytes. The
  specialized native passage median is 8.107 seconds versus 9.596 before, with
  eight matching native reply/count hashes. Ollama is still faster (0.930 seconds
  in that pair, 1.535 in a later repeat). Native/Ollama chat templates and KV/prefix
  policy differ; full logits, first-token, long-context and broad speed claims
  remain unproved. [Evidence and reproduction](docs/evidence/second-brain-2026-10-01.md).

- **Additional measured subset (2026-10-01):** Prepared dense GQA descriptors,
  row-aligned block projections and bounded exact-prefix reuse are connected to
  native Llama/Qwen sessions. The installed 3B model passed 35 independent real
  dot products, 63 synthetic Q4/Q5/Q6 exact-reference rows, seven cached/fresh
  completions with sampling/system/deadline recovery, and real service/API probes.
  Fifteen pre-cache HTTP samples match the archived binary's complete replies and
  counts, with warm medians 2.95–3.00x faster. Broader profile/device performance,
  full logits, batched prefill and in-process CUDA context recreation remain open.
  See [native performance manual](docs/NATIVE_PERFORMANCE.md). Status stays partial.
- **Final controlled measurements:** The exact final binary passes 30 matching
  cached/uncached replies against the archived 15-case sequence. Fresh-prefill
  medians improve 2.97–3.02x; retained matching prefixes improve 5.56–21.11x.
  Actual first long-prompt cost remains 9.746 seconds. The paired provider subset
  favors native cached arithmetic but Ollama retains the 32-token advantage.
  [Raw evidence and constraints](docs/evidence/native-performance-2026-10-01.md).

- **Further efficiency subset (2026-10-01):** Int32 quant byte arithmetic retains
  wide addresses and reference float order; four-value fixed RMS tiles retain the
  scalar lane sum and warp reduction. Standard uncached medians improve another
  1.62–1.64x and cached medians 1.64–1.66x versus binary d1ee3ba2. The extended
  1070-prompt/128-output case improves 1.60x; sustained 128-output improves 1.63x.
  All 34 paired whole replies/counts match. GPU allocation remains 2466 MiB in
  these processes. Expanded physical probes prove 738 synthetic projection rows,
  1404 tail guards and 233472 RMS values versus exact references/independent
  equations. The new comparator refuses invalid/mismatched evidence. Status stays
  partial; full logits, batched prefill and broader devices/models remain open.
  See [efficiency operation and verification](docs/NATIVE_EFFICIENCY.md).

- **First SPD-00 measurement slice (2026-10-01):** Portable 32/128/256 ceilings,
  balanced/seeded/grouped order, observed loaded/as-is residency, full redacted
  replies, strict identity/count/JSON admission, and failure-aware ratios are
  connected to installed services. Fourteen real-socket/synthetic protocol tests
  and nine numerical/CSV/artifact-publication tests pass. A physical sm_75 probe
  measures fresh prefill/decode host intervals, logical tensor traffic and checked
  nonuniform D2D copies (238.42 GB/s). The four-vector independent 3B gate is
  recorded under AES-ACC-008. [Evidence and scope](docs/evidence/speed-measurement-2026-10-01/README.md).
  Full SPD-00 tracing/cache/residency/quality gates and an overall provider lead
  remain open; this slice changes measurement, not production inference kernels.


- **Long-token subset (2026-10-01):** Checked compact DenseBufferLayout accounts
  for four disjoint token spans with shared logits/scores; its strict 3B tile adds
  405504 bytes while preserving F16 KV. Layer-major four-token prefill decodes
  aligned Q4/Q5/Q6 weights once per tile and preserves causal KV, sampling order
  and synchronized commits. The real 3B fixture passes 641280 exact native
  sequential/tiled logits, five completions, restored continuation and invalid
  tile non-mutation. Fresh1070/128 and3150/128 requests improve1.82/1.85x,
  while46 paired fresh/cached replies match and cached timings remain near flat.
  Four projection covers 2952 scalar-reference rows/5616 guards.
  Long attention passes 24 exact reference cases and 65536 independent NumPy
  values up to synthetic history8192 (maximum absolute error3.0896622e-7).
  Pure buffer admission, seven prefix/deadline/reset completions, real service
  faults and 29 API fixtures pass. Status stays partial: native regression logits
  do not certify independent external full-model logits, maximum-context full
  inference or broader models/devices. See [long-token manual](docs/NATIVE_LONG_TOKENS.md).


### AES-OPS-002 — Resource-efficiency, REPL parameter bounds & runtime safety

- **Status:** `missing`
- **Owner:** performance and project documentation domains
- **Claim sources:** README efficiency, maximum hardware use, fast/cold language
- **Implementation evidence:** `RuneREPL.process_input_line()` in `cli/repl.mojo` enforcing non-negative configuration bounds (`temperature >= 0.0`, `top_k >= 0`, `0.0 <= top_p <= 1.0`, `max_new_tokens >= 1`).
- **Executable evidence:** `E-MASTER` case `cli.repl_session_state` in `test_cli.mojo`.
- **Evidence boundary:** Parameter validation provides no resource-efficiency measurement or operational runtime-safety case.
- **Next acceptance gate:** Define resource and safety metrics, instrument real executions, and publish reproducible failure and load evidence.
- **Audit:** AER-101, AER-102.

### AES-OPS-003 — Security posture for network/model inputs & socket port validation

- **Status:** `partial`
- **Owner:** loader, server, CLI, and distribution domains
- **Claim sources:** local sovereignty/privacy and server/distribution functionality
- **Implementation evidence:** `BifrostGate.__init__()` in `server/api.mojo` enforcing port range bounds (`1 <= port <= 65535 -> raises Error("server bind port must be between 1 and 65535")`).
- **Executable evidence:** `E-MASTER` case `server.posix_socket` in `test_multi_engine.mojo`.
- **Evidence boundary:** `SECURITY_POSTURE.md` contains a target threat model plus a 2026-10-10 evidence-linked native local-service boundary. No production security assessment, exhaustive fuzz campaign, TLS/remote policy, multi-tenant authorization, or complete resource-exhaustion proof exists.
- **Next acceptance gate:** Run reproducible malformed-model, request-fuzzing, and sustained resource-limit suites; assess any later remote/TLS deployment as a separate capability.
- **Audit:** AER-037, AER-075, AER-082, AER-107.

### AES-OPS-004 — Runtime observability, route parameter safety & diagnosability

- **Status:** `partial`
- **Owner:** runtime and service domains
- **Claim sources:** metrics/health routes and production implications
- **Native service evidence:** Per-request sequence, generation phase, HTTP status and elapsed time are recorded without prompts/responses/credentials; authenticated health reports the actually loaded CUDA profile/context. Both real-model service probes verify readiness, generation and shutdown.
- **Legacy implementation evidence:** `BifrostGate.dispatch_http_route()` in `server/api.mojo` enforcing route path parameter validation (`len(path.bytes()) == 0 -> returns HTTP 404 route_not_found_response()`) and explicit compatibility route handling for `/metrics`, `/health`, `/props`, and `/slots`.
- **Observation formatter evidence:** `AesirTUIDashboard` accepts an atomic, validated metric snapshot with caller source and timestamp. An empty dashboard reports observations unavailable, and invalid values cannot partially replace the preceding snapshot.
- **Executable evidence:** `E-MASTER` case `server.http_parser` in `test_multi_engine.mojo`.
- **Evidence boundary:** The native service has narrow request logs and readiness. Legacy route validation still does not establish metrics, tracing, persistent audit storage or broad production diagnosis.

- **AES500-241..248 socket lifecycle evidence:** Live native transport ownership is bounded to the `serve_loaded` listener, one active request owner, and configured FIFO owners; the interrupt FD is borrowed from CLI signal ownership. `OwnedFD` now skips closing the `-1` moved-from sentinel, with focused transfer, invalid-FD, and port-boundary evidence. Master is 245 passed, 0 failed, 1 skipped (246 total). Baseline, unit, integration and adversarial receipts are linked from [the socket ownership contract](TASK_socket_ownership_shutdown.md). The physical active-shutdown receipt is historical because this checkout has no usable model; independent review was unavailable and is not claimed.
- **AES500-251..259 bounded request parsing evidence:** The live reader admits an 8 KiB CRLFCRLF-terminated head, up to 64 unique headers with 1024-byte values, and exact POST body bytes up to 131072 under one absolute read deadline. Unit coverage checks exact/over boundaries and numeric overflow; socketpair coverage checks adjacent head/body preservation, unterminated oversized head, short EOF, NUL and over-limit body rejection. Master is 248 passed, 0 failed, 1 skipped (249 total). Receipts are linked from [the parser contract](TASK_request_parser_bounds.md). These local tests are not third-party protocol parity or physical inference evidence.
- **AES500-261..269 strict framing evidence:** `LocalHTTPHead` rejects case-insensitive duplicate headers, malformed request-line spacing/CRLF, `Expect`, `Transfer-Encoding` (including alongside Content-Length), and GET bodies; the status matrix exercises unsupported methods 405, missing/zero POST length 411 and wrong media type 415. Master is 249 passed, 0 failed, 1 skipped (250 total). See [the framing contract](TASK_http_framing_rejection.md) and dated test receipt. This remains local HTTP subset evidence, not complete RFC or external-client conformance.
- **Next acceptance gate:** Add structured logs, request/session correlation, real metrics, health semantics, and operator-facing failure diagnostics.
- **Audit:** AER-078, AER-101, AER-111.

### AES-OPS-005 — Production readiness & single-shot prompt validation

- **Status:** `missing`
- **Owner:** all domains
- **Claim sources:** any current or future “production” implication
- **Implementation evidence:** `dispatch_cli_command()` in `cli/commands.mojo` enforcing single-shot inference prompt parameter validation (`len(trimmed_prompt.bytes()) == 0 -> raises Error("single-shot run prompt text must not be empty")`).
- **Executable evidence:** `E-MASTER` case `cli.truthful_command_boundaries` in `test_cli.mojo`.
- **Evidence boundary:** One prompt validation guard does not establish production readiness.
- **Next acceptance gate:** Meet the outstanding correctness, security, service, compatibility, portability, packaging, observability, and operational acceptance gates.
- **Audit:** AER-002, AER-003, AER-005, AER-100 through AER-115.

### AES-OPS-006 — Documentation-to-evidence consistency

- **Status:** `verified`
- **Owner:** project documentation and every claiming domain
- **Claim sources:** this ledger, README, TODO, visions, architecture, interfaces, runtime banners
- **Implementation evidence:** canonical ledger, `scripts/check_doc_drift.py` documentation verification suite, TODO status synchronization, and explicit current-versus-historical claim boundaries in both active vision documents.
- **Executable evidence:** `python3 scripts/test_check_doc_drift.py` proves current status rejection and historical exclusion; `python3 scripts/check_doc_drift.py`; `E-MASTER` (**147 passed / 0 failed / 1 skipped / total 148**).
- **Evidence boundary:** Checks mechanical ledger/test/doc invariants, active vision status tags, and known fabrication signatures. Historical prose is preserved rather than semantically re-adjudicated; new claim families still require review and gate expansion.
- **Audit:** AER-003, AER-112, AER-115.


### AES-SYS-001 — Experimental CIA/WIC/NSFI/MQARI inference paradigms

- **Status:** `missing`
- **Owner:** core experimental and configuration domains
- **Claim sources:** completed top-priority TODO items; active vision and architecture descriptions
- **Implementation evidence:** Configuration parsing records the four boolean intents and single-shot validation rejects enabled intent. `EpisodicComputationMemory`, `WaveInferenceEngine`, `NSFIEngine`, and `MQARIEngine` expose zero/empty initial state; semantic-state, synthetic wave, fractal-weight and harmonic execution methods all raise unsupported without mutating caller tensors or telemetry.
- **Executable evidence:** `E-MASTER` case `paradigms.experimental_paradigms` covers every rejection and output/state non-mutation.
- **Evidence boundary:** No semantic embedding/state snapshot, trained fractal representation, physical wave/acoustic system, calibrated numerical method, model conversion, output-equivalence proof, hardware execution or speed measurement exists.
- **Next acceptance gate:** Each proposal requires a separate falsifiable specification, model artifact/transform, reference implementation, output-quality/equivalence gate and physical performance evidence before runtime enablement.
- **Audit:** AER-003.

## 19. Claim-Family Coverage Map

| Claim family | Canonical entries |
|---|---|
| Build/runtime foundation | AES-FND-001 through AES-FND-008 |
| Memory/tensor/KV ownership | AES-MEM-001 through AES-MEM-007 |
| CPU kernels and attention | AES-CPU-001 through AES-CPU-008 |
| GGUF loading | AES-LDR-001 through AES-LDR-006 |
| Tokenizer/decoder | AES-TOK-001 through AES-TOK-004 |
| Inference/generation | AES-GEN-001 through AES-GEN-011 |
| CLI/model management | AES-CLI-001 through AES-CLI-014 |
| Server/protocols | AES-SRV-001 through AES-SRV-010 |
| Embeddings/RAG | AES-RAG-001 through AES-RAG-005 |
| Quantization | AES-QNT-001 through AES-QNT-011 |
| Hardware/multi-device | AES-ACC-001 through AES-ACC-009 |
| External ecosystems | AES-ECO-001 through AES-ECO-008 |
| Resilience/concurrency | AES-RES-001 through AES-RES-006 |
| Swarm/distributed | AES-SWM-001 through AES-SWM-005 |
| Benchmarks/security/production | AES-OPS-001 through AES-OPS-006 |
| Experimental inference paradigms | AES-SYS-001 |

## 20. How This Ledger Changes

1. Change one capability status only in the same commit that adds or removes the
   cited implementation/evidence.
2. A promotion to `verified` must include an executable command and explicit
   boundary; external claims require the corresponding external proof.
3. Add a new stable ID when a broader claim must be split. Never silently reuse
   an ID for a different capability.
4. Recalculate the summary mechanically and verify IDs/statuses before merge.
5. Keep vision language in vision documents, present implementation truth here,
   and link the two without converting aspiration into completion.
6. Runtime output must describe actual events. Forge 0D converted operational
   theater to explicit missing/unsupported boundaries. No capability currently
   relies on a `simulated` status as evidence.

## Native CUDA cancellation milestone — 2026-08-31

**Status: verified**, scoped to cooperative deadlines and serialized cancellation
in the two native CUDA sessions on the observed Linux/WSL2/NVIDIA host. The
public executable handles process-wide SIGINT across pre-main MAX workers,
recovers a completed assistant cancellation, and requires explicit reset after
interrupted prefill. Three counted cases and both real-model CLI probes pass.
See [runtime contract and reproduction](docs/NATIVE_RUNTIME.md#cancellation-and-deadlines).
This does not establish kernel preemption, concurrent session mutation, SIGTERM
graceful shutdown, cross-platform signal handling or production serving.

### Fused strategy4 owned trace refinement — 2026-10-03

Optional fused4 now earns complete source-bound owned attention/projection traces:
plain/profiled37/1070 full F32/cache/IDs/state/guards agree, all1869/32215 kernel
resources validate before589/7449 projection ranges and56/1008 fused children.
Long FFN3.456781s/6.046571s=57.1693% of summed kernels; fused attention.814218s
=13.4658%, diagnostic only. Exact observed fused grid24x4/32/block128/register46/
static16384, full chronological source interleaving and one successful launch/kernel
per child pass. Nine contracts/master190/one skip/seven builds; no occupancy/spill/
delay/provider cause claim. [Operation](docs/NATIVE_FUSED_ATTENTION_TRACE.md).
Next measure fewer token accumulators per CTA in an isolated FFN experiment;
original arithmetic, complete bit/oracle/guards and all finite paired samples gate
selection. Broader runtime/device/context/production/soak/provider gates stay open.

[Physical evidence](docs/evidence/fused-attention-trace-2026-10-03/README.md).
This refines existing AES-ACC-008/010 and introduces no general new verified capability.

### Token-partition primitive refinement — 2026-10-03

Four isolated row64/128/token8/16 partitions pass complete original bits/fixed
numeric/independent dots/guard/finite paired record/source identity gates. No canonical batch32 FFN candidate beats both comparison owners in this session. Keep selected kernels and retain this experiment; choose the next measured bottleneck experiment.
[Operation](docs/NATIVE_TURING_TOKEN_PARTITION.md). Primitive timings and source
geometry are not model quality/speed, measured occupancy/resources or a provider
lead. Old production/fused4 selections stay; broader acceptance remains open.

[Evidence](docs/evidence/turing-token-partition-2026-10-03/README.md).
Existing AES-ACC-008 experiment only; no general capability promotion.

### Bounded small-score primitive refinement — 2026-10-03

Separate small-score attention passes all33 cases/full original F32 bits/NumPy
Float64 outputs/exact guards/immutable query+KV cells/660 rotated finite records.
Full identical-binary profile bits/PID and all2178 resource/launch correlations prove
static16384→6144 bytes,62.5% smaller per-CTA score storage. Profile timings unscored;
plain timings exploratory.10+8 hostile contracts/master190 and all six final builds
pass. Original kernel/model/runtime selection stays. [Operation](docs/NATIVE_SMALL_FUSED_ATTENTION.md).
Next earn source-bound actual default-disabled small-score whole-model logits/cache/
IDs/counters/own bits/independent CPU quality before broader integration. Scalar decode
and context/device/concurrency/soak/production32/refreshed provider lead stay separate.

[Evidence](docs/evidence/small-fused-attention-2026-10-03/README.md).
Refines AES-ACC-010; no general new capability promotion.

### Small-score model refinement — 2026-10-03

Optional small-score strategy5 now passes all513024 full F32 values per owner,
exact own bits and accepted4 bytes/cache/IDs/counts, unchanged independent zero-GPU
CPU/max/RMS/argmax,4352 guards/eight invalid tiles/legacy `ADMISSION,5,12,0`
metadata and all32 finite paired records in the dated 2026-10-03 receipt. Current
COUNTS1 collectors separately record executed refusal counts. Default-false capability and strict actual current/source
binaries keep old selectors. Seven hostile contracts/master190/one skip/all seven
builds; [operation](docs/NATIVE_SMALL_ATTENTION_MODEL.md). Same-capture native-four/
small-fixture exploratory prefill only, not historical4/new5 or Ollama/request ratio.
Next earn causal generation and source-bound state, sealed replay, enabled controls/
tracing, then broader runtime/device/context/concurrency/soak/provider acceptance.

[Evidence](docs/evidence/small-attention-model-2026-10-03/README.md).
Refines existing AES-ACC-008/010; no general new capability promotion.

### Small-score causal generation refinement — 2026-10-03

Optional small-score5 causal generation now passes all96 full-vocabulary frames/
12312576 F32 values per owner, initial accepted5 bytes, unchanged independent
CPU/max/RMS/argmax, native-forced causal IDs, exact samples/history/draws/state,
own UInt32 fresh replay/4352 guards and actual small/down/closed-fused/scalar
counters. Twelve hostile contracts/master190/one skip/all seven builds precede
serial GPU/CPU. Explicit exclusive source triplet/current binary and strict full
source CPU/cache/ID/count/typed-integer admission bind all after-fences.
[Operation](docs/NATIVE_SMALL_ATTENTION_DECODE.md). No speed score/normal selection.
Next earn sealed owning-context replay5, then separate controls/tracing and broader
runtime/context/device/concurrency/soak/refreshed provider acceptance.

[Evidence](docs/evidence/small-attention-decode-2026-10-03/README.md).
Refines AES-ACC-008/010; no general capability or provider speed promotion.

### Small-score sealed replay refinement — 2026-10-03

Small-score5 sealed owning-context replay passes both45-ID checkpoints/eight
continuation frames/1026048 values per baseline/restored owner/actual UInt32 bits/
source samples/state/fixed CPU/4352 guards/40 mutation-free refusals. Default-false
plan/live capabilities preserve original seals, bind pre-reset allocation/geometry/
sampler/flags/health. Down28/small56/fused0/original252→364 bind exact boundaries.
Ten hostile contracts/master190/one skip/seven builds precede serial GPU/CPU;
explicit source5 report SHA/actual accepted/current binaries and complete after-fences.
[Operation](docs/NATIVE_SMALL_ATTENTION_CHECKPOINT.md). No speed score or persisted/
crash/context recreation/normal selection claim. Next separate cooperative controls/
tracing and broader runtime/context/device/concurrency/soak/refreshed provider gates.

[Evidence](docs/evidence/small-attention-checkpoint-2026-10-03/README.md).
Refines AES-ACC-008/010; no general new capability/provider speed promotion.

## MÍMISBRUNNR Campaign 1 (Hailo-10) — 2026-10-10

Phase A recon & spikes on Mimir (Raspberry Pi 5, aarch64, Cortex-A76). These
entries record measurement spikes and toolchain verdicts, not shipped engine
capabilities. Nothing here changes an existing capability status.

### H007 — NEON FP16 GEMM baseline — measured

**Status: verified** as a measurement (spike, not engine code). Pure-Mojo
64x64x64 FP16 matmul with an 8-wide SIMD inner kernel (8x fp16 = one 128-bit
NEON register; `av.fma(bv, acc)` lowers to `fmla v0.8h, v2.8h, v1.8h`,
confirmed in `--emit asm` output), checked against a naive scalar
triple-loop reference on deterministic dyadic inputs (k/64, k in [-4,4]:
every product and partial sum exactly representable in fp16).

Results on Mimir @ 2.4 GHz (performance governor, sudo-pinned): max abs err
**0.0** (bit-for-bit agreement, threshold was 1e-3); median of 11 runs
**32765 ns/matmul = 16.0 GFLOPS** (524288 FLOPs; run spread <1.2%).
Evidence: `data/phase_a/neon_baseline.json`,
`spikes/phase_a/neon_fp16_matmul.mojo`. This is a baseline, not a tuned
result (~21% of the NEON FP16 FMA roofline); it does not establish engine
GEMM performance.

### H008 — Loader port check — partial

**Status: partial.** GGUF header parsing on ARM64 is byte-identical to
x86_64 (standalone pure-Mojo parser, 3 generated GGUF v3 test files, sha256
of canonical outputs match across arches — `data/phase_a/loader_port_check.json`).
Two blocking findings filed in `docs/phase_a/LOADER_PORT_ISSUES.md`, neither
worked around: (1) GGUFSeer (`aesir_engine/loader/gguf.mojo`) does not
compile under Mojo 1.1.0 (`InlineArray` removed from `std.collections`) —
toolchain drift on both arches, not ARM64-specific; (2) Hladgerð has no
implementation anywhere in the repo (named domain only), so no safetensors
loader exists to port-check. Neither finding establishes an ARM64
endianness/alignment bug; the format itself parses identically.

### H015 — POSIX syscall baseline — verified

**Status: verified** as a measurement spike. Pure Mojo on Mimir performs all
7 syscalls the HAILBRU driver needs via a single `syscall()` gateway
(`std.ffi external_call`): openat, read, mmap/munmap, eventfd2, ppoll,
ioctl (FIONREAD, real success), write — plus pipe2/close supporting. Every
failure site reports errno via `__errno_location` mapped to a name; the
ENOENT error path verified. Evidence: `data/phase_a/posix_baseline/output.log`
(`H015_ALL_SYSCALLS_OK`), `spikes/phase_a/posix_baseline.mojo`. Notes:
AArch64 uses eventfd2(19)/ppoll(73); redeclaring libc read/write/fclose via
external_call conflicts with std.io's declarations (hard error) — the
gateway design is the workaround.

### H010 — Phase-A gate review — GO-WITH-CONDITIONS

**Status: verified** as a review document. `docs/phase_a/PHASE_A_GATE_REVIEW.md`
tables H001–H009 verdicts against the architecture's Phase-A go gate (3/4
pass; the VFIO/UIO/sysfs mechanism fails per H004). Verdict:
GO-WITH-CONDITIONS — Phase A recon is complete and the campaign proceeds,
but H061–H080 (HAILBRÚ driver) are blocked until the kernel gains
VFIO/UIO or the driver re-scopes to F2; GGUFSeer needs a 1.1.0 migration
before loader-dependent slices; Hladgerð/safetensors scope must be decided.
D1 CPU work, studies, PRÓF, and F3 banking are unblocked.

### H016 — Phase-A evidence aggregator (PRÓF, test-only) — verified

**Status: verified.** `prof/phase_a/check_phase_a.py` (Python, file I/O
only, no engine imports) machine-checks all Phase-A artifacts: 36/36 pass
on the clean tree, exit 0. Anti-rubber-stamp proven: an emptied
`neon_baseline.json` in a scratch copy yields 32/34 with named failures and
exit 1. Cross-refs checked: H004 cites the census BDF, H010 has the GATE
VERDICT section, JSON artifacts parse with required keys.

### H017 — Interrupt capability study — verified

**Status: verified** as a study. `docs/phase_a/INTERRUPT_STUDY.md`:
MSI capability present but zero vectors allocated (`msi_irqs/` empty);
legacy INTx active on IRQ 37 (INTA#); vendor stack uses single-vector MSI
(not MSI-X), acknowledged by read-and-clear of BAR0+0x018C. H069 will
implement MSI first, INTx fallback; MSI-X not a fallback (unproven on this
device). Userspace primitives named: VFIO = eventfd+ioctl
(VFIO_DEVICE_SET_IRQS); UIO = blocking read on /dev/uioX.

### H018 — DMA coherence model study — verified

**Status: verified** as a study. `docs/phase_a/DMA_COHERENCE_STUDY.md`: no
IOMMU on Mimir (no `iommu_group`, SMMU not compiled); 64-bit DMA mask;
64 MB CMA; 64-byte cache lines. Per-mechanism DMA-visibility documented.
**ARM64 pitfall flagged (real):** pure userspace cannot issue DC CVAC/IVAC
(EL1+), so H066/H067 must use uncached mappings, a kernel partner, or
explicitly unsafe assumptions — plus no-IOMMU means a misprogrammed
descriptor can DMA anywhere (safety-critical).

### H019 — Chip-executable configuration surface survey — verified

**Status: verified** as a study. `docs/plunder/HAILO_CONFIG_SURFACE.md`
surveys 12 configuration elements SMIÐR must generate (operation/tensor
descriptors, allocation directives, data-movement programs, scheduling,
completion signaling, firmware handshake, plus 5 LATER items), each with a
one-sentence purpose and MUST-HAVE/LATER marking. Seven are MUST-HAVE for
the minimal vector-op proof. The encoding of each element (bit layouts the
silicon expects) remains the Phase-D research target.

### H020 — Phase-A closeout — verified

**Status: verified** as a planning document. `docs/phase_a/PHASE_A_CLOSEOUT.md`:
top 5 lessons, top 5 risks with mitigations, open questions mapped to
answering slices, C2 kernel backlog (H022–H039 with target shapes and error
tolerances), and the H010 gate verdict re-confirmed GO-WITH-CONDITIONS
(dated, no amendment — H016–H019 added evidence, no contradictions).

## 6B. ARMVEGR loaders / tokenizer / KV-cache / sampler (D1) — MÍMISBRUNNR Campaign 3 (H041–H060)

Pure-Mojo model I/O and CPU pipeline domain, continuing the F1 CPU engine on
the ARMVEGR substrate. All on-device evidence from Mimir (aarch64, Mojo 1.1.0);
x86_64 cross-checks from the forge (same Mojo 1.1.0).

### AES-LOAD-041 — GGUFSeer ARM64 full port (H041)

- **Status:** `verified`
- **Owner:** ARMVEGR domain (D1)
- **Implementation evidence:** `aesir_engine/loader/gguf.mojo` — Mojo 1.1.0
  migration (InlineArray removal) + aarch64 struct-stat ABI fix (st_mode word
  index); the only two touchpoints, zero x86_64 behavior change.
- **Executable evidence:** `tests/h041_gguf_port.mojo` canonical dump; 6-file
  corpus (v2+v3, F32/F16/Q4_0/Q8_0/Q4_1/Q5_0/Q8_1/Q6_K, incl. real
  TinyLlama-1.1B-Chat-v1.0 Q4_0) byte-identical x86_64 vs ARM64
  (`data/armvegr/gguf_port_diff.txt`, empty diff). Existing x86_64 suite
  (test_gguf_parsing, test_ggml_type) passes unmodified.

### AES-LOAD-042 — GGUF tensor loader, mmap + dequantize to FP16 (H042)

- **Status:** `verified`
- **Owner:** ARMVEGR domain (D1)
- **Implementation evidence:** `armvegr/gguf_loader.mojo` — self-contained
  v2/v3 parser, mmap, FP16 dequantize via H031/H032 kernels; unsupported
  dtypes and corrupt input fail closed with named errors.
- **Executable evidence:** `tests/h042_xcheck.mojo` (TEST-ONLY): 68 tensors
  dequantized per arch, byte-identical (max abs err 0 <= 1e-6);
  1.1 GB file loads at 320 KiB peak RSS; 3 corrupt files fail closed
  (`data/armvegr/gguf_loader_xcheck.txt`).

### AES-LOAD-043 — safetensors parser in pure Mojo (H043)

- **Status:** `verified`
- **Owner:** ARMVEGR domain (D1)
- **Implementation evidence:** `armvegr/safetensors.mojo` — hand-rolled JSON
  header parser (L1), descriptor validation (dtype/shape/offsets/overlap/EOF).
- **Executable evidence:** `tests/h043_st_check.mojo` (TEST-ONLY) vs
  `prof/armvegr/check_safetensors.py`: 5 real files match exactly; 6
  adversarial headers fail closed with named errors
  (`data/armvegr/safetensors_xcheck.txt`).

### AES-LOAD-044 — safetensors tensor loader incl. BF16 (H044)

- **Status:** `verified`
- **Owner:** ARMVEGR domain (D1)
- **Implementation evidence:** `SafetensorsLoader.load_fp16` — F16 passthrough,
  F32 via H031, BF16 via `bf16_to_fp16_rne` (RNE contract documented in code).
- **Executable evidence:** exhaustive 65536-pattern BF16 test bit-exact vs
  integer reference on both arches (dae5a613...); 18-tensor FP16 checksums
  identical x86_64 vs ARM64 (3f8e1497...); st_model.st loads end-to-end on
  Mimir (`data/armvegr/safetensors_xcheck.txt`).

### AES-LOAD-045 — weight layout planner (H045)

- **Status:** `verified`
- **Owner:** ARMVEGR domain (D1)
- **Implementation evidence:** `armvegr/layout.mojo` — deterministic
  per-tensor layout planner, load-time pre-packing, packed-panel GEMM driver.
- **Executable evidence:** `tests/c3_h045_layout.mojo` (TEST-ONLY):
  byte-identical plan JSON on repeat runs; packed_b/packed_a vs naive GEMM
  max abs err 0.0 (<= 1e-3) on Mimir.

### AES-LOAD-059 — Q6_K dequantizer (H059 partial)

- **Status:** `verified`
- **Owner:** ARMVEGR domain (D1)
- **Implementation evidence:** `armvegr/quant.mojo` (`q6k_to_fp16`), `armvegr/gguf_loader.mojo` (dtype 14 dispatch).
- **Executable evidence:** Mojo Q6_K matches Python reference implementation (<1e-4 max abs diff on TinyLlama `output.weight`); `fp16_from_bits` subnormal handling fixed (was flushing Q6_K scales to zero).

### AES-INFER-059 — TinyLlama inference pipeline (H059)

- **Status:** `blocked`
- **Owner:** ARMVEGR domain (D1)
- **Implementation evidence:** `armvegr/infer.mojo` (TinyLlama + Inference structs), `tests/c3_h059_infer.mojo` (driver).
- **Executable evidence:** All 201 tensors load; components verified (gemv, RoPE, tokenizer). Output incoherent — root cause not isolated. Remediation: H059R1–R3 (differential debug vs reference, fix+verify, Mimir cross-check). See `docs/armvegr/C3_REVIEW.md`.

### AES-C3-REVIEW — Campaign C3 verdict (H060)

- **Status:** `verified`
- **Owner:** ARMVEGR domain (D1)
- **Implementation evidence:** `docs/armvegr/C3_REVIEW.md` — per-component tables, L2/L3/L9 confirmation, C3 VERDICT section.
- **Executable evidence:** Review document; verdict **F1-CORE-NOT-READY** (H059 blocked, remediation named). H041–H058 complete and verified.

## HAILBRÚ Driver (Campaign 4, H061–H080) — 2026-10-10
- **Status:** `implemented, Phase-B gate NO-GO`
- **Owner:** HAILBRÚ domain (D2)
- **Implementation evidence:** `docs/hailbru/C4_REVIEW.md` — slice checklist H061–H080,
  API table, L12 verification, measured register evidence.
- **Executable evidence:** 17-file pure-Mojo domain; `probe` CLI (17 subcommands);
  28 error-path tests green on x86_64 + aarch64; 11 CLI selftests green.
- **Capability:** real sysfs discovery/config/BAR/link probing, root BAR mmap
  read-only register access (50/50 coherency 0x1e60), CPU-side DMA alloc/mlock,
  eventfd IRQ plumbing, 17-blob firmware SHA-256 verification.
- **Banked (F3):** IOMMU DMA, UIO bind, device MSI, firmware DMA boot, live writes —
  prerequisites in `docs/hailbru/F3_UNBLOCK_RUNBOOK.md`.

## HAILBRÚ Bring-up & Firmware (Campaign 5, H081–H100) — 2026-10-10
- **Status:** `verified, Phase-C gate PASS (READY_FW)`
- **Owner:** HAILBRÚ domain (D2)
- **Implementation evidence:** `docs/hailbru/C5_REVIEW.md` — slice checklist
  H081–H100; `docs/hailbru/PHASE_C_GATE.md`; `hailbru/fwboot.mojo`
  (firmware boot engine); `docs/hailbru/F3_UNBLOCK_RUNBOOK.md` §0.
- **Executable evidence:** kernel `6.12.112-v8-16k-hailo+`; UIO bind/unbind/
  restore real (/dev/uio0); real device MSI (count=1); ATR programming real;
  scu_fw.bin parsed (magic 0xE905DAAB); firmware verified booted
  (ATR1==0x200000); 100/100 power cycles (mean 113.6 ms); 10/10 golden;
  20/20 PM; 100/100 health; 28/28 tests green.
- **Not demonstrated:** VDMA descriptor DMA (H066); full 3-stage re-flash
  (H075 — implemented, not fired; device already booted); on-chip FW
  version query (H086).

## SMIÐR Wall Assault (Campaign 6, H101–H120) — 2026-10-10
- **Status:** `partial, Phase-D gate NO-GO (H111)` — the Compiler Wall held.
- **Owner:** SMIÐR domain (D3)
- **Implementation evidence:** `docs/smidr/PHASE_D_GATE.md` (evidence table,
  NO-GO verdict, written technical account); `docs/smidr/H102_ATTEMPT_RECORD.md`;
  `docs/smidr/H105_ATTEMPT_RECORD.md`; `docs/smidr/C6_REVIEW.md`.
- **Executable evidence (host-side, on Mimir):** `smidr/mailbox.mojo`
  (faithful mailbox implementation); `smidr/descriptor.mojo` (H103:
  fail-closed builder, 5/5 malformed inputs raise named BadDescriptor);
  `smidr/config_gen.mojo` (H104: deterministic seeded SMIÐR-CFG v1,
  2 runs byte-identical); independent TEST-ONLY validators
  `prof/smidr/check_descriptors.py` and `prof/smidr/check_vecadd_config.py`
  all green; golden vectors in `data/smidr/vecadd/`.
- **Negative result (measured):** firmware mailbox silent on both
  documented doorbells (app-CPU 0x1, core 0x2) across 5 hardening
  variants + vendor ioctl; 0 completions observed. No transport ⇒
  H105–H110 BLOCKED (strict-serial), H106/H109/H110 not PASS ⇒ NO-GO
  per the decision rule.
- **Fallback:** F1 CPU trunk triggered (`docs/smidr/FALLBACK_TRIGGERED.md`);
  F2 survey found no viable partial-acceleration interface;
  C7–C10 re-scoped to 62 RUN / 18 SKIP (`docs/fallback/RESCOPED_PLAN.md`,
  mechanically validated).
- **Not demonstrated:** any on-chip compute; the H019 element-1 compute
  encoding remains explicitly UNKNOWN (0xFFFFFFFF sentinel, not invented).

## F1 CPU Pipeline (Campaign 7, H136–H140) — 2026-10-10
- **Status:** `withdrawn / disabled by owner scope (2026-10-12)` — historical CPU implementation only; its CLI and direct inference entrypoints now fail closed. It is not an active product path.
- **Owner:** ARMVEGR domain (D1), NO-GO branch (H111 closed the NPU path).
- **Implementation evidence:** `armvegr/infer.mojo` v0.2.0 (fail-closed guards,
  shape validation, reset/prefill/free, forward_nocache reference, shallow_copy);
  `armvegr/f1_config.mojo` + `data/fallback/f1_config.json` (production config,
  byte-level fail-closed JSON parser); `armvegr/f1_infer.mojo` (shippable CLI,
  JSON output); `armvegr/batch.mojo` (B=4 static batching, weight sharing);
  `armvegr/session.mojo` (KV-cache prefix cache, multi-turn); `armvegr/backend.mojo`
  (H139: AUTO→CPU honest, NPU raises NpuUnavailable); `docs/fallback/C7_REVIEW.md`.
- **Measured on Mimir (TinyLlama-1.1B-Chat Q4_0, sha256 da3087fb...):**
  prefill 512 tok = 253.1 s (2.02 tok/s); decode 100 tok = 604.6 s (0.165 tok/s,
  sampler-bound — top_p O(n²) bubble sort, deferred to C9); batch B=4:
  2.05 tok/s vs 2.12 unbatched (×0.97, honest); H136 kvcheck 3/3 probes
  bit-identical (0.0); H137 batch/session 3/3 tests + 3/3 guards;
  H138 3/3 prompts × 64 tok, all 6 rubric items pass; H139 50/50 CPU + 5/5 NPU errors.
- **Historical evidence only:** prior CPU measurements and tests describe the old implementation; they do not establish a currently callable inference path or authorize CPU work.
- **Non-claims:** no NPU compute (H111 NO-GO); decode speed is sampler-bound,
  not a hardware limit; no multi-node.

## Vörðr Robustness (Campaign 8, H141–H160) — 2026-10-10
- **Status:** `historical / CPU inference supervision withdrawn (2026-10-12)` — Hailo device-health primitives remain recorded, but CPU inference supervision is outside owner scope.
  NPU-referencing slices received honest Sólrún audit treatment (`docs/vordr/SOLRUN_AUDIT_C8.md`):
  H150 = CPU numerics cross-check (shadow-verify F1 SIMD kernel vs independent scalar
  reference, the H059R1-proven pattern); H157 = CPU-pipeline stage retry via scalar
  fallback kernel (loud DEGRADED, never sticky); H147/H148 = REAL reset/re-init via the
  new HAILBRÚ `reset()` primitive (`hailbru/reset.mojo`, C5-proven PM-reset cycle);
  H153 = REAL UIO unbind (device left sane: hailo1x rebound, D3hot); H151–H154 =
  TEST-ONLY Python driving real faults, never simulated; H142 = Hailo die temp not
  readable on current kernel (Pi SoC is the documented proxy).
- **Implementation evidence:** `vordr/` D6 package (health_obs, events/JSONL, monitor,
  hang/heartbeat, errdecode, taxonomy, spawn/fork+system, watchdog + parent-monitor,
  reset_ctl, reinit, recovery state machine, shadow, integrity/FNV-1a, retry, degrade);
  `vordr_cli.mojo` (all subcommands incl. h158-run supervised inference);
  `data/vordr/thermal_thresholds.json`, `watchdog_policy.json` (1/2/4/8s backoff),
  `retry_policy.json`, `hang_budgets.json`, `recovery_budgets.json`;
  `docs/vordr/ERROR_TAXONOMY.md`, `FALLBACK_AUDIT.md`, `vordr-watchdog.service`.
- **Measured on Mimir:** H141 120/120 samples, max drift 12ms (<1s); H143 stall caught
  in 305ms (300ms budget), 0 false positives/1000 ops; H147 50/50 resets golden-clean
  (mean 201ms); H148 50/50 re-inits (mean 203ms, worst 206ms); H155 budgets —
  transient_retry p99 749ms→budget 1498ms, reset_reinit p99 213ms→426ms,
  process_restart p99 22ms→44ms (10-sample confirmation: all beat); H146 watchdog
  restarts ≤2.4s, rapid-death backoff 1/2/4/8s; H150 shadow 10/10 (worst diff 1.43e-06);
  H154 integrity 500/500 detected, 0 escapes; H156 retry absorbs 3 faults, 6→RetryExhausted.
- **Non-claims:** no NPU compute (H111 NO-GO stands); no Hailo die-temp telemetry on
  this kernel; Vörðr never touches device registers (L6/L12 — all resets via HAILBRÚ).

## Speed Optimization (Campaign 9, H161–H180) — 2026-10-10
- **Status:** `historical / CPU inference optimization withdrawn (2026-10-12)` — prior benchmark records remain archival; no CPU LLM optimization is in scope.
- **Implementation evidence:** `bench/` harness (`bench_env.mojo`: env capture,
  TrialStats median/min/max/stddev, thermal settle; `bench_kernels.mojo`: 22 C2
  kernels at H038 shapes; `run_bench.mojo`: kernels/gemm_tuned/prefill/decode/
  tokenize/stability subcommands; `run.sh`: governor→performance, taskset pin,
  restore); `armvegr/gemm_tuned.mojo` (GemmTune: Mc/Kc/Nc, prefetch, hoisted-B,
  micro-kernel variants; additive — gemm_fp16 untouched); `data/bench/e2e_prompt.txt`.
- **Measured on Mimir:** C9 verdict STRONG PASS — decode 0.1766→1.918 tok/s
  (10.86×), prefill 2.080→3.362 tok/s (+61.6%), GEMM 6.934→7.773 GFLOPS
  (+12.1%). H170 deferred (threading needs shared-memory infra, documented).
- **Non-claims:** no NPU-path optimization (H111 NO-GO); harness records the pin
  state it actually observed — it never claims pinned clocks it did not verify.

## GAUNTLET Production Hardening (Campaign 10, H181–H200) — 2026-10-10
- **Status:** `historical / CPU inference release path withdrawn (2026-10-12)` — prior CPU-only measurements and packaging records are archival, not a current release claim or authorized roadmap.
- **Owner:** D7 GAUNTLET domain — measures and judges ONLY; never touches
  implementation code (architectural self-test: gauntlet/*.mojo imports
  std-only, zero repair/recovery/fix references, machine-checked by
  prof/gauntlet/test_gauntlet_purity.py).
- **Implementation evidence:** `gauntlet/` (metrics/gates/verdict, H181);
  `data/gauntlet/STABILITY_GATES.json` (9 machine-checkable gates, H182);
  `prof/gauntlet/` TEST-ONLY drivers: 4h CPU soak (H183), soak analyzer
  with synthetic-drift validation (H185), 60-min fault-injection campaign
  on C8's VÖRÐR h158-run (H186), 20-cycle reset storm (H187), determinism
  proof (H188), RSS leak check (H189); `scripts/package_f1_release.sh`
  (H190: python-less docker inference proof); `deploy_mimir.sh` + canary
  (H191); `docs/gauntlet/RUNBOOK.md` (H192); victory gates H195–H197.
- **Measured on Mimir:** H183 4h soak — zero crashes, zero hangs, drift
  within ±10% (see data/gauntlet/soak_cpu_4h_summary.json); H186 ≥100
  faults injected, 0 unhandled, 0 crashes; H187 20/20 restarts to service
  with bit-exact greedy output, all within the H155 44ms budget; H188
  10/10 identical × 5 prompts + 5/5 post-restart; H189 RSS slope ≤1 MB/h;
  H190 package runs inference in a python-less container, strace proves
  the binary never execs python; H195 two unseen open models coherent
  per the frozen rubric.
- **Non-claims:** no NPU compute (H111 NO-GO stands — the Hailo-10 compute
  wall held); no "any model format" claim (GGUF-or-safetensors envelope
  per Aesir's loaders); no Python in the shipped package.

## Direct Hailo-10H application backend — 2026-10-19

- **Status:** `partial` overall; the narrow HailoRT 5.3.0 / Qwen2.5-1.5B
  canonical CLI is physically evidenced by slices 134–138. This is a dedicated
  backend, separate from historical generic NPU-dispatch entries.
- **Owner:** AESIR orchestration (`hailo10h_direct.mojo`, `hailo10h_bridge.cpp`,
  `cli/hailo_commands.mojo`); in-process HailoRT owns device model execution.
- **Evidence:** readiness/lifetime/recovery/CLI/provenance receipts in
  `docs/HAILO10H_SLICE_134_READINESS.md` through
  `docs/HAILO10H_SLICE_138_PROVENANCE.md`.
- **Slice 139:** `tests/test_hailo10h_hardware.py` is a physical acceptance seam
  with explicit artifact/binary/profile, independent hashes before/after runs,
  retained raw failures, strict provenance and ordered chat-context gates.
  Seven synthetic validator tests pass; they prove rejection logic only.
  Eleven local C ABI/CLI tests pass with one hardware class explicitly skipped.
  FIFO, FIFO symlink, empty-file and directory model arguments reject promptly
  before device allocation. See `docs/HAILO10H_SLICE_139_HARDWARE_SEAM.md`.
- **Slice 140 (physical):** the fresh canonical-CLI acceptance passes readiness,
  single-shot arithmetic, persistent recall, context-overflow rejection without
  mutation, reset-to-zero and post-reset generation. All source/binary/library/
  profile/model hashes remain unchanged. Final-source boundary/lifecycle tests
  pass 12/12; Mojo exception cleanup and repeat close pass. See
  `docs/HAILO10H_SLICE_140_SMOKE.md` and its public receipt/transcript.
- **Next gate:** slices 141–150 formal model/artifact compatibility acceptance.
  Strict word-only recall formatting fails in this qualified model.
  No general model quality, throughput, per-layer telemetry, service packaging,
  additional runtime/platform compatibility or full-roadmap completion claim.

## Mojo source-model execution target — 2026-10-19 owner correction

- **Status:** `missing` for the complete source-model-to-Hailo execution path.
  Existing loaders, protocol primitives and vendor-precompiled smoke evidence
  do not complete this capability or limit its intended model scope.
- **Owner target:** Project Aesir in Mojo must run source models of the right
  size for Hailo-10H. Only an explicit owner instruction may change the target.
- **Current narrow verified primitive:** `hailbru/hrpc_frame.mojo` implements
  the pinned integrated-device RPC envelope and is consumed by the native
  `smidr/tools/hrpc_frame.mojo` inspector. Eight independent Python wire-test
  methods plus direct Mojo API refusal/ownership checks pass. See
  `docs/HAILO10H_MOJO_HRPC_FRAMING.md`.
- **Boundary:** host framing validation only; no independent device round-trip,
  new compute encoding, source compilation or LLM inference is claimed.
- **Next:** PCIe session/request lifecycle, then bounded read-only physical
  round-trip, alongside the actual source compiler/configuration gaps.

### Owned Mojo typed device-control protocol

- **Status:** `verified` only as a host wire-message primitive. The complete
  source-model compiler and physical Mojo session remain open.
- **Owner:** `hailbru/hrpc_device.mojo`; caller is the native
  `smidr/tools/hrpc_device.mojo` constructor/inspector.
- **Evidence:** native build plus ten independent google.protobuf-backed test
  methods. Zero handles, unknown fields, numeric identity presence/defaults,
  correlated replies, remote failures and malformed message boundaries pass.
  See `docs/HAILO10H_MOJO_HRPC_DEVICE_MESSAGES.md`.
- **Boundary:** pinned v5.3.0 control-message subset; no device/model access,
  general protobuf runtime, physical round-trip or source compilation claim.

### Owned Mojo packed session ABI

- **Status:** `verified` as a Linux LP64 little-endian host byte primitive.
- **Owner:** `hailbru/soc_abi.mojo`, consumed by native
  `smidr/tools/soc_abi.mojo` without device access.
- **Evidence:** native build plus nine independent methods; twelve ioctl
  values and 84 complete request buffers match the installed 5.3.0 C UAPI
  oracle. Reply offsets, bounds, valid zero handles, unknown enums and IRQ
  statuses are checked. See `docs/HAILO10H_MOJO_SOC_ABI.md`.
- **Boundary:** codecs establish neither resource ownership nor valid DMA
  allocation, alignment, lifetime or physical completion. Driver session and
  source-model execution remain separate required work.

### Owned native Mojo read-only driver query

- **Status:** `verified` on this Pi for driver-file identity, actual kernel
  properties/version and fd cleanup. No independent RPC or inference claim.
- **Owner:** `hailbru/soc_driver.mojo`, consumed by native
  `smidr/tools/soc_driver.mojo` through the HAILBRÚ syscall gateway.
- **Evidence:** actual Hailo-10H PCIe query, two native builds and eleven test
  methods including strace-observed close, both injected read-only query
  failures, exception cleanup and node refusal. Subsequent supported identify
  succeeds. See `docs/HAILO10H_MOJO_DRIVER_OWNER.md`.
- **Boundary:** qualified 5.3.0 Linux driver profile; descriptors, connection,
  DMA, remote typed RPC and source-model compilation remain open.

### Small-score cooperative controls refinement — 2026-10-09

The strategy5 fixture's explicit default-false `small_controls` capability passes
fresh capable-but-disabled full-model/source/cache/ID/CPU acceptance and physical
pre-expired/mid-tile timeout, owned cancellation, invalid-descriptor, reset and
recovery/poison cases for the documented strict3B/sm75/context1536 scope. Every
recovered vector is byte-identical; guards and caller signal-mask restoration
pass. [Operation](docs/NATIVE_SMALL_ATTENTION_CONTROLS.md) and
[evidence](docs/evidence/small-attention-controls-2026-10-09/README.md).
Controls remain fixture-only; no normal selector, persistence/context-recreation,
CUDA-fault repair, general runtime, or provider-speed capability is promoted.
Next: owned small-score strategy5 tracing.

### Small-score observed disabled-control baseline refinement — 2026-10-10

AES500-002's fresh COUNTS1/STATE1 capable-disabled capture passes all513024
F32 values per owner, exact historical strategy5 source bytes/cache/IDs/counters,
32 actual disabled/healthy/reset-free owner snapshots,4352 guards and fixed
independent zero-GPU CPU max/RMS/argmax. Eight tile refusals are executed;
capable mode executes zero ordinary feature checks. Input/source hashes stay
unchanged and authenticated normal CUDA service health is restored. Quality
acceptance has `speed_scored=false`, null ratios and no medians.
[Evidence](docs/evidence/small-attention-controls-baseline-2026-10-10/README.md).
This strengthens the fixture evidence boundary only. Fresh enabled-abort/recovery,
runtime, broader device/model/context and provider-speed gates remain separate;
no capability status or count is promoted.

### Small-score controls constructor interface refinement — 2026-10-10

AES500-003 independently executes all13 existing constructor refusal modes with
exact first-gate messages using the unchanged accepted002 executable. A verified
nonexistent input, source ordering before native session construction and exact
exception attribution support the pre-load refusal boundary; output silence
alone proves no resource behavior. All272 source hashes and normal service
state/health remain unchanged. Defaults and request/reset policy are source-
reviewed; positive capable-disabled owners reuse002 rather than a new run.
[Evidence](docs/evidence/small-attention-controls-interface-2026-10-10/README.md).
No fresh default-false owner, live mutation/abort/recovery or capability promotion.

### Owned native Mojo assigned connection lifecycle

- **Status:** `verified` on this Pi for two descriptor lists, assigned RPC
  service channels and ordered normal/error/exception cleanup.
- **Owner:** `hailbru/soc_session.mojo`, consumed by the native
  `smidr/tools/soc_session.mojo` lifecycle tool.
- **Evidence:** actual connection to port 12133, two builds and seven physical
  methods with exact syscall order, ten normal successful sessions, exception
  cleanup, six injected ioctl failures and a fresh connection after each.
  Subsequent supported identify succeeds. See
  `docs/HAILO10H_MOJO_SESSION_LIFECYCLE.md`.
- **Boundary:** no user DMA buffer/transfer, typed remote message, program
  generation or source-model execution. These remain required work under the
  same target. Kernel memory-accounting and arbitrary firmware recovery are
  not certified by these bounded tests.

### Integrated RPC reference transfer facts

- **Status:** `verified` as bounded installed-reference observation, not an
  independent Mojo message exchange or model execution capability.
- **Evidence:** `docs/HAILO10H_DMA_OBSERVATION.md`; 548 paired real ioctl
  calls, 258 matching buffer tuples, exact 2068-byte transfers, positive
  descriptor-count result 5, request status 1, eight adversarial checker tests
  and evidence non-overwrite refusal. Subsequent ordinary identify and owned
  Mojo connection lifecycle succeed.
- **Next:** production return/status corrections, owned map/unmap/sync/storage
  and bounded interrupt lifetime, then actual correlated Mojo device RPC.
  These findings do not reduce the source-model/compiler target.

### Observed request status and ioctl-result handling

- **Status:** `verified` as host wire/API corrections, not independent Mojo
  remote exchange or model execution.
- **Evidence:** `docs/HAILO10H_DMA_PROTOCOL_CORRECTIONS.md`; native create
  request matches the actual reference header; ten independent protobuf methods,
  seven result-handler assertions, six builds and rebuilt physical owner 11/11
  / connection lifecycle 7/7 pass. Request status 1 and successful positive
  transfer count 5 replace the prior host-only assumptions.
- **Boundary:** actual owned user-buffer transfer and bounded completion
  remain required; nonnegative submission does not mean completed work.

### Mojo source semantic graph — 2026-10-19

- **Status:** `verified` for source descriptors and host graph structure only.
- **Owner:** `smidr/source_inventory.mojo`, `smidr/semantic_plan.mojo`;
  contract `TASK_hailo10h_source_compiler_plan.md`.
- **Evidence:** `docs/HAILO10H_MOJO_SEMANTIC_PLAN.md`; nine independent
  methods/56 native runs, exact dependency/shape/lifetime/weight checks, 42
  refusals; rebuilt inventory six methods/16 runs pass. No model forward.
- **Boundary:** first incremental dense-decoder importer, not a permanent
  architecture limit. Layout/RoPE/quantization/numerical recipes, resource
  qualification and executable program generation/execution remain open.

### Checked source-graph storage scenario — 2026-10-19

- **Status:** `verified` for hypothetical host compiler arithmetic only.
- **Owner:** `smidr/storage_estimate.mojo`; explicit widths/alignment, aggregate
  device-weight/workspace bytes, budget and provenance required.
- **Evidence:** `docs/HAILO10H_MOJO_STORAGE_ESTIMATE.md`; seven independent
  methods/61 native calls, exact brute-force interval oracle and malformed
  policy/graph/arithmetic refusals. No device or numerical model execution.
- **Boundary:** the comparison is not hardware fit or inference admission.
  Actual conversion, precision, placement, physical budget and program costs
  remain unresolved; all corresponding proof flags remain false.

### Original public context-action codec — 2026-10-19

- **Status:** `verified` for four host byte-record types only.
- **Owner:** `smidr/context_actions.mojo`, native host inspector; contract
  `TASK_hailo10h_context_actions.md`.
- **Evidence:** `docs/HAILO10H_MOJO_CONTEXT_ACTIONS.md`; seven methods/244
  native calls, exact independent Python and pinned C++ header object oracles,
  enum/size/offset checks, field/refusal/ownership tests. No device access.
- **Boundary:** no CCW generation, numerical operation, valid upload endpoint
  or physical activation is established. Source-model execution remains open.

### Source-bound primitive mathematical recipes — 2026-10-19

- **Status:** `verified` as RMSNorm/SiLU compiler expansion and isolated
  primitive mathematical agreement only.
- **Owner:** `smidr/primitive_recipes.mojo`; native recipe inspector.
- **Evidence:** `docs/HAILO10H_MOJO_PRIMITIVE_RECIPES.md`; six methods/39
  native calls, source IDs/weights/scalar bits/shapes/lifetimes, fourteen
  malformed API refusals and ownership; four tiny Decimal primitive oracles.
- **Boundary:** no CPU model/layer forward, Hailo program, device precision or
  numerical hardware acceptance. Expanded storage and backend encoding remain
  open. Unexpanded operations are explicitly named.

### Stable last-axis softmax recipe — 2026-10-19

- **Status:** `verified` as mathematical compiler expansion only.
- **Owner:** original `smidr/primitive_recipes.mojo` pass.
- **Evidence:** `docs/HAILO10H_MOJO_SOFTMAX_RECIPE.md`; seven methods/44
  native calls, five isolated primitive Decimal fixtures, RMSNorm/SiLU
  regressions and exact source/shape/domain/lifetime checks.
- **Boundary:** explicit runtime preconditions have not been enforced on
  device. No model/layer forward, executable Hailo program or device numerical
  tolerance is certified. Expanded storage/placement/program gates remain.

### Integrated expanded mathematical graph — 2026-10-19

- **Status:** `verified` as host compiler integration only.
- **Owner:** `smidr/expanded_graph.mojo`; consumes/owns the source plan and
  primitive recipes, emits deterministic global values/operations.
- **Evidence:** `docs/HAILO10H_MOJO_EXPANDED_GRAPH.md`; five methods/45 native
  calls, exact source/local/global edge and binding/scalar/domain checks,
  recomputed lifetimes, aliases, malformed API refusals and returned ownership.
- **Boundary:** no model/layer math or device submission; physical precision,
  expanded resource qualification, CCWs and numerical hardware proof remain
  open. Source constants are references, not converted device allocations.

### Checked expanded-graph storage — 2026-10-19

- **Status:** `verified` for explicit hypothetical byte-volume accounting.
- **Owner:** `smidr/expanded_storage.mojo`, native storage inspector.
- **Evidence:** `docs/HAILO10H_MOJO_EXPANDED_STORAGE.md`; seven methods/88
  native calls, exact independent interval oracle, separate predicate/real
  timelines, 54 invalid graph/policy/arithmetic refusals and returned ownership.
- **Boundary:** no model math, actual device allocation/fit, physical placement
  or executable program. Source constants/views do not duplicate allocation;
  actual conversion, precision, budgets and hardware acceptance remain open.

### Floating source constant representation — 2026-10-19

- **Status:** `verified` as bounded static source representation decoding.
- **Owner:** `smidr/source_float_constants.mojo`, loader half-word helper.
- **Evidence:** `docs/HAILO10H_MOJO_SOURCE_FLOAT_CONSTANTS.md`; six methods/64
  native calls, exhaustive F16/BF16 patterns, F32 payload preservation, 24
  refusals and returned ownership; rebuilt inventory/storage regressions pass.
- **Boundary:** no host model arithmetic, source identity certificate, selected
  device weight format or execution. Packed quantized source constants and
  actual compiler/backend/program/hardware gates remain open.

### Packed Q4_K source affine constants — 2026-10-20

- **Status:** `verified` as bounded static source representation decoding.
- **Owner:** original `smidr/source_q4k_constants.mojo`, schema published first.
- **Evidence:** `docs/HAILO10H_MOJO_SOURCE_Q4K_CONSTANTS.md`; eight methods/57
  native calls (28 accepted, 29 refused), all group-factor/nibble values and
  exact pinned external reference on 4096 synthetic constants; floating-format
  exhaustive regression passes. Production has no ggml dependency.
- **Boundary:** no model/layer forward, device precision/layout, source identity
  certificate or execution. Original numerical CCWs, program delivery and
  activation remain open; active `TASK_hailo10h_program_delivery.md`.

### Original program metadata/lifecycle RPC — 2026-10-20

- **Status:** `verified` as pure host wire construction/inspection.
- **Owner:** original `hailbru/hrpc_program.mojo`; existing project protobuf
  reader reused, no vendor/protobuf production dependency.
- **Evidence:** `docs/HAILO10H_MOJO_PROGRAM_RPC_CODEC.md`; eight methods/140
  native calls (70 accepted, 70 refused) against frozen generated public-schema
  protobuf, exact body/UTF-8/u64/ownership/refusal checks; rebuilt device codec
  passes ten regression methods. Optional compiled enum header probe remains
  unbuilt with its missing-include diagnostic retained.
- **Boundary:** no device open, program transfer, activation, model arithmetic
  or physical handle ownership. Numerical CCWs, container metadata, original
  immutable program delivery, configure/cleanup and first hardware result remain
  open under `TASK_hailo10h_program_delivery.md`.

### Original program outer header/layout — 2026-10-20

- **Status:** `verified` as synthetic output header/section arithmetic only.
- **Owner:** original `smidr/program_header.mojo`, field facts published first.
- **Evidence:** `docs/HAILO10H_MOJO_PROGRAM_HEADER.md`; eight methods/151 native
  calls (84 accepted, 67 refused), complete independent big-endian struct bytes,
  section origins/lengths/extents/overflow and returned ownership. Initial test
  error-name assertion failure is retained; final suite passes.
- **Boundary:** no checksum, full container, source/hardware target admission,
  numerical CCWs, model/program file input, device upload or execution. Active
  `TASK_hailo10h_llm_compile_interfaces.md` investigates public source compiler
  interface leads toward the actual numerical backend gap.

### Explicit source-bound cache address scenarios — 2026-10-20

- **Status:** `verified` as hypothetical compiler relative addressing only.
- **Owner:** original `smidr/cache_layout.mojo`, current dense semantic cache
  identities and explicit caller assumptions.
- **Evidence:** `docs/HAILO10H_MOJO_CACHE_LAYOUT.md`; six methods/89 native calls
  (18 accepted, 71 refused), 3353 independent element-offset checks, distinct
  K/V widths, padding/budget/overflow/graph/alias/ownership refusals.
- **Boundary:** no actual dtype/layout/placement, immutable source identity,
  cache/ring data mutation, host model math or hardware execution. Actual
  numerical configuration remains open under the program-delivery parent.

### Source-bound native contraction tiles — 2026-10-20

- **Status:** `verified` as lazy host mathematical scheduling only.
- **Owner:** original `smidr/matrix_tiles.mojo`, selected semantic linear ops.
- **Evidence:** `docs/HAILO10H_MOJO_MATRIX_TILES.md`; seven methods/860 native
  calls (799 accept,61 refuse), all729 small shape/tile domains and6672 exact
  coordinate checks; source formats/head splits/tails/ownership/refusals pass.
- **Boundary:** no model arithmetic, immutable source certificate, device packing,
  precision/placement, numerical CCWs, hardware fit or execution. Source byte
  streaming is next under `TASK_hailo10h_source_weight_tiles.md`.

### Native source weight byte tiles — 2026-10-20

- **Status:** `verified` as bounded read-only source storage only.
- **Owner:** original `smidr/source_weight_tiles.mojo`, consumes matrix schedules.
- **Evidence:** `docs/HAILO10H_MOJO_SOURCE_WEIGHT_TILES.md`; five methods/286
  native calls (256 accept,30 refuse),88368 independent byte checks across six
  source kinds, packed block/row tails, explicit bounds and destroyed owners.
- **Boundary:** no model evaluation, immutable identity, device packing/precision,
  placement, numerical CCWs or hardware execution. Original Q5/Q6 component
  decoding follows under `TASK_hailo10h_q5q6_source_constants.md`.

### Original Q5_K/Q6_K source components — 2026-10-20

- **Status:** `verified` as bounded static source representation only.
- **Owner:** original `smidr/source_q5q6_constants.mojo`; schema published first.
- **Evidence:** `docs/HAILO10H_MOJO_SOURCE_Q5Q6_CONSTANTS.md`; seven methods/88
  native calls (40 accept,48 refuse),94416 exact component comparisons and8192
  exact binary32 static reference checks. Bounds/ownership/read-only gates pass.
- **Boundary:** no production floating model arithmetic, immutable source proof,
  device packing/precision, placement or numerical hardware execution. Active
  `TASK_hailo10h_numerical_encoding_sources.md` targets actual backend gaps.

### Original configure/stream parameter wire values — 2026-10-20

- **Status:** `verified` as host action4 construction/reply inspection only.
- **Owner:** original `hailbru/hrpc_configure.mojo`, native SMIÐR diagnostic.
- **Evidence:** `docs/HAILO10H_MOJO_CONFIGURE_RPC_CODEC.md`; eight methods/83
  calls (36 accept,47 refuse), exact frozen-schema packets, all fields/sentinels,
  bounds/ownership/UTF-8/raw words and strict reply checks. Rebuilt program8/140
  and device10-method regressions pass. No device/syscall/model request occurs.
- **Boundary:** no physical handle ownership, program transfer/configure,
  precision/placement, numerical CCWs or hardware execution. Original program
  integrity follows under `TASK_hailo10h_program_integrity.md`.


### Original program outer integrity — 2026-10-20

- **Status:** `verified` as host byte-window hashing and selected-domain checking.
- **Owner:** original `smidr/program_integrity.mojo`; facts published first.
- **Evidence:** `docs/HAILO10H_MOJO_PROGRAM_INTEGRITY.md`; eleven methods/2072
  native calls (1977 accept,95 refuse), pinned isolated XXH3 oracle, literal
  vectors, all small/medium lengths, block/8 MiB/bounds/tamper/ownership checks;
  independent header regression8/151 passes. No external production hash link.
- **Boundary:** protobuf-only checks do not verify remaining payload. Neither
  branch verifies executable metadata, numerical CCWs, device CRC, physical
  placement/precision, target compatibility or execution. Owned output-envelope
  connection follows under `TASK_hailo10h_program_envelope.md`.


### Original owned program outer envelope — 2026-10-20

- **Status:** `verified` as host outer serialization of supplied opaque sections.
- **Owner:** original `smidr/program_envelope.mojo`, connects header/hash codecs.
- **Evidence:** `docs/HAILO10H_MOJO_PROGRAM_ENVELOPE.md`; eight methods/194
  native calls (159 accept,35 refuse), exact complete-byte independent oracle,
  all section combinations, size/bounds/overflow/selector/ownership and host-only
  trace. Extent planning checks huge declarations without allocation.
- **Boundary:** no executable protobuf/CCW semantics, hardware alignment/target/
  precision/placement, firmware CRC, program transfer/configure or execution.
  Continue `TASK_hailo10h_public_encoding_delta.md` toward actual backend gaps.


### Ordinary safetensors source inventory — 2026-10-20

- **Status:** `verified` as bounded host source metadata only.
- **Owner:** original `smidr/safetensors_inventory.mojo` over the repaired existing
  project `armvegr/safetensors.mojo` reader; facts/audit published first.
- **Evidence:** `docs/HAILO10H_MOJO_SAFETENSORS_INVENTORY.md`; eleven methods/219
  native calls (109 accept,110 refuse), pinned isolated format oracle, Unicode/
  NUL/full axes/scalars/empties,60 seeded collections, strict bounds/overflow/
  coverage and cleanup/ownership. Five legacy header-only calls pass.
- **Boundary:** F16/BF16/F32 inventory only; no tensor conversion or model/device
  execution, immutable source certificate, shard/config/architecture mapping,
  physical precision/packing/placement or executable numerical instructions.
  Static weight windows follow under `TASK_hailo10h_safetensors_constants.md`.


### Ordinary safetensors static source windows — 2026-10-20

- **Status:** `verified` as bounded static source representation only.
- **Owner:** original `smidr/safetensors_constants.mojo`, uses the existing live
  source owner and original Aesir integer representation helpers.
- **Evidence:** `docs/HAILO10H_MOJO_SAFETENSORS_CONSTANTS.md`; nine methods/97
  native calls (77 accept,20 refuse),264204 exact raw/expanded words, exhaustive
  F16/BF16 spaces, F32 special payloads, scalar/empty/full-rank/tail windows,
  ownership/refusals/read-only and error-path close. Reader11/219 regression.
- **Boundary:** no immutable source identity, dtype/shard/config/architecture
  semantic integration, device precision/packing/placement, numerical CCWs or
  hardware execution. Source-neutral mathematical input connection follows
  `TASK_hailo10h_source_neutral_semantics.md`; the broad target is unchanged.


### Owned typed decoder inputs and semantic builder — 2026-10-20

- **Status:** `verified` as the typed configuration/structural graph boundary.
- **Owner:** original `smidr/semantic_plan.mojo`, compatible GGUF entry point
  delegates after decoding and closes the file before graph construction.
- **Evidence:** `docs/HAILO10H_MOJO_TYPED_DECODER.md`;7 methods/493 native calls
  (243 accept,250 refuse),30 exact complete-graph comparisons with pre-refactor
  output, independent edge/lifetime checks, raw Float32/ownership/bounds/span
  oracles. Seven dependent suites pass47 methods/1440 further native calls.
- **Boundary:** storage remains explicitly GGUF-specific. No safetensors/config/
  shard semantic integration, immutable file identity, physical precision/layout,
  actual numerical instructions or Hailo model execution is certified. Continue
  tagged storage/name/config facts toward the unchanged broad target.


### Exact admitted GGUF source axes — 2026-10-20

- **Status:** `verified` as copied source-shape metadata for current loader ranks.
- **Owner:** existing `aesir_engine/loader/packed_gguf.mojo` parser and public
  `tensor_shape` lookup; consumers are the source-shape inspector and API probe.
- **Evidence:** `docs/HAILO10H_MOJO_GGUF_SOURCE_SHAPES.md`;6 methods/104 native
  calls (56 accept,48 refuse), explicit-rank independent fixtures, six source
  kinds,35 seeded collections, ownership/mutable-state/refusal/read-only checks.
  Three rebuilt regressions pass22 methods/565 calls, including30 complete
  graph comparisons with the pre-refactor binary.
- **Boundary:** current one/two-rank descriptive metadata only, no immutable
  backing-file identity, semantic/physical layout or model execution. Tagged
  storage/config/name integration and numerical Hailo execution remain open.


### Tagged ordinary-source storage provenance — 2026-10-20

- **Status:** `verified` as owned tagged file-storage metadata and byte arithmetic.
- **Owner:** original `smidr/source_storage.mojo`, reuses existing parsers and
  exact GGUF shape lookup; native inspector consumes the owned projection.
- **Evidence:** `docs/HAILO10H_MOJO_TAGGED_SOURCE_STORAGE.md`;7 methods/452 calls
  (367 accept,85 refuse), exact independent per-format fields/bytes, fifty
  seeded collections, source namespace collision, full axes/scalars/empties,
  ownership/closed-owner/policy/overflow/span/sort/cleanup. Five regressions pass
  39 methods/888 calls; full slice46/1340. Final new builds warning-free.
- **Boundary:** metadata only. GGUF parser admission/work precedes new projection
  bounds; mutable paths/descriptors are not immutable identity. Complete semantic
  storage migration/config/index/name/rotary integration, physical encoding and
  original Hailo model execution remain open toward unchanged broad support.


### AES-SOURCE-001 — Owned ordinary shard-index metadata

- **Status:** `verified`
- **Owner:** `smidr/source_index.mojo`, `smidr/source_metadata_file.mojo`;
  shared bounded JSON cursor and Linux regular-fd size interface.
- **Executable evidence:** `docs/HAILO10H_MOJO_SOURCE_INDEX.md` and
  `docs/evidence/source-index-2026-10-20/`;37 methods/1289 native calls,
  including516 index calls,768 rebuilt consumer calls and5 extra header probes.
- **Evidence boundary:** Metadata and exact file bytes only, Linux ARM64.
  No shard resolution, immutable source identity, configuration/architecture
  equivalence, hardware fit, numerical device program or source-model execution.
- **Next acceptance gate:** `TASK_hailo10h_source_config_metadata.md`, then
  checked shard/semantic integration and numerical Hailo backend implementation.


### AES-SOURCE-002 — Owned ordinary configuration raw values

- **Status:** `verified`
- **Owner:** `smidr/source_config.mojo`; existing shared JSON cursor and exact
  regular-file byte owner. Native inspector and direct ownership probe consume it.
- **Executable evidence:** `docs/HAILO10H_MOJO_SOURCE_CONFIG.md` and
  `docs/evidence/source-config-2026-10-20/`;16 methods/706 native calls,
  comprising190 config calls and516 index regression calls.
- **Evidence boundary:** Configuration metadata only, native Linux ARM64.
  Preserves unknown/raw modifiers without interpreting source architecture,
  loading shards/tensors, certifying immutable identity/fit or model execution.
- **Next acceptance gate:** `TASK_hailo10h_shard_collection.md`, beginning with
  owned model-root regular-fd admission, then same-fd parsing and exact binding.


### AES-SOURCE-003 — Actual owned beneath-root regular-file admission

- **Status:** `verified`
- **Owner:** `smidr/source_root.mojo`, documented syscall gateway; native
  inspector/direct owner probes perform real filesystem operations on the Pi.
- **Executable evidence:** `docs/HAILO10H_MOJO_MODEL_ROOT.md` and
  `docs/evidence/model-root-2026-10-20/`;21 methods/783 calls,77 new and706
  rebuilt index/config regressions. C ABI bytes and physical closes are checked.
- **Evidence boundary:** ARM64 Linux file descriptor ownership/containment only.
  No tensor header parsing, immutable identity, hardware fit, executable device
  program or source-model execution. Other-host support remains implementation.
- **Next acceptance gate:** `TASK_hailo10h_safetensors_owned_fd.md`, then
  automatic exact multi-shard source index binding and complete model semantics.


### AES-SOURCE-004 — Owned same-descriptor safetensors header inventory

- **Status:** `verified`
- **Owner:** shared `armvegr.safetensors` header decoder, original
  `smidr/safetensors_fd.mojo`, syscall gateway and native root/fd inspector.
- **Executable evidence:** `docs/HAILO10H_MOJO_SAFETENSORS_FD.md` and
  `docs/evidence/safetensors-fd-2026-10-20/`;53 methods/1916 native calls,
  including365 new and1551 rebuilt regressions,54 complete baseline fixtures.
- **Evidence boundary:** Native ARM64 metadata/descriptor ownership only; no
  source payload mmap/read/evaluation in the new fd route, immutable identity,
  hardware fit, architecture adapter or numerical Hailo model execution claim.
  Legacy mapped constant cleanup/concurrency limits remain separately recorded.
- **Next acceptance gate:** `TASK_hailo10h_shard_collection.md` and
  `docs/HAILO10H_INDEXED_SHARD_COLLECTION_DESIGN.md`, then full semantic/backend
  integration toward the fixed broad-model target.


### AES-SOURCE-005 — Actual indexed source-file tensor binding

- **Status:** `verified`
- **Owner:** original `smidr/shard_collection.mojo`, owned root/JSON/header
  descriptor readers, existing strict parsers and tagged-storage projection.
- **Executable evidence:** `docs/HAILO10H_MOJO_SHARD_COLLECTION.md` and
  `docs/evidence/shard-collection-2026-10-20/`;58 methods/2121 native calls,
  comprising205 new and1916 regression calls, actual multi-file reads/cleanup.
- **Evidence boundary:** Checked ARM64 source metadata binding at load time;
  no immutable identity, payload evaluation, semantic architecture equivalence,
  physical layout/fit, numerical device program or LLM execution. Indexed format
  is a current loader slice, not a permanent model prerequisite or target change.
- **Next acceptance gate:** `TASK_hailo10h_unindexed_source_collection.md`,
  complete tagged semantic storage/config adapters and actual Hailo backend.


### AES-SOURCE-006 — Ordinary unindexed weight/config metadata loading

- **Status:** `verified`
- **Owner:** original read_unindexed_source_collection and shared SMIÐR
  config/shard fd/checked-storage helpers, distinct owned result and inspector.
- **Executable evidence:** `docs/HAILO10H_MOJO_UNINDEXED_SOURCE.md` and
  `docs/evidence/unindexed-source-2026-10-20/`;62 methods/2299 native calls,
  comprising178 new,205 rebuilt indexed and1916 shared regressions;33 complete
  frozen-indexed comparisons and actual descriptor/cleanup traces.
- **Evidence boundary:** Actual ARM64 ordinary input metadata only, absent index
  reported honestly. No payload evaluation, immutable identity, architecture
  equivalence, physical fit, executable Hailo program or LLM execution claim.
- **Next acceptance gate:** `TASK_hailo10h_semantic_storage_migration.md`, then
  exact ordinary config/architecture adapters and the actual numerical backend.


### AES-SOURCE-007 — Tagged semantic storage and checked operation views

- **Status:** `verified`
- **Owner:** original SMIÐR tagged source inventory/aliases, per-file extents,
  source-bound graph/recipe/storage/cache/schedule/live-byte consumers.
- **Executable evidence:** `docs/HAILO10H_MOJO_SEMANTIC_STORAGE.md` and
  `docs/evidence/semantic-storage-2026-10-20/`;94 methods/2559 native calls,
  including312 new-suite calls and108 complete frozen output comparisons.
- **Evidence boundary:** Owned tagged metadata and compiler structure only;
  current one/two-axis views, explicit dtype namespaces, real collection inputs
  and synthetic ordinary operation structures. No complete ordinary architecture
  adapter, immutable identity, physical placement/fit, numerical device program
  or LLM execution. Missing formats/ranks/operations remain implementation work.
- **Next acceptance gate:** `TASK_hailo10h_ordinary_semantic_adapter.md`, broad
  architecture/modifier semantics and the actual numerical Hailo backend.


### AES-SOURCE-008 — Owned ordinary decoder-layer intent

- **Status:** `verified`
- **Owner:** original smidr.decoder_layers, existing strict JSON/config readers
  and native layer inspector; actual collection-config acceptance connections.
- **Executable evidence:** `docs/HAILO10H_MOJO_DECODER_LAYERS.md` and
  `docs/evidence/decoder-layers-2026-10-20/`;19 methods/701 calls, including199
  new,190 config and312 semantic regressions,40 error/valid cycles.
- **Evidence boundary:** Owned metadata interpretation for documented initial
  layer semantics, full original config/modifier retention and source/default
  provenance. No complete ordinary architecture/graph adapter, physical layout/
  fit, immutable identity, numerical Hailo program or LLM execution. Other
  architectures and operations remain required implementation work.
- **Next acceptance gate:** `TASK_hailo10h_decoder_graph_policy.md`, actual
  ordinary architecture/alias/modifier semantics and numerical Hailo execution.


### AES-SOURCE-009 — Explicit typed decoder graph and cache policy

- **Status:** `verified`
- **Owner:** original smidr.semantic_plan and cache_layout; owned typed policy,
  conditional rotary graph construction and actual direct/rotary cache writers.
- **Executable evidence:** `docs/HAILO10H_MOJO_DECODER_GRAPH_POLICY.md` and
  `docs/evidence/decoder-graph-policy-2026-10-20/`;99 methods/2711 calls,
  40 new complete graph and108 complete frozen consumer comparisons.
- **Evidence boundary:** Checked tagged source compiler structures, explicit
  per-layer/output policy, recalculated lifetimes/mappings/schedules and
  hypothetical cache addresses. No complete ordinary architecture/config/
  alias/layout/modifier adapter, physical fit, numerical device program or
  source-model execution. Missing coverage remains implementation work.
- **Next acceptance gate:** `TASK_hailo10h_decoder_architecture_intent.md`,
  actual ordinary architecture semantics and numerical Hailo execution.


### AES-SOURCE-010 — Owned ordinary decoder parameter intent

- **Status:** `verified`
- **Owner:** original smidr.decoder_architecture, shared strict config/layer
  owners and actual indexed/unindexed collection-config connections.
- **Executable evidence:** docs/HAILO10H_MOJO_DECODER_ARCHITECTURE.md and
  docs/evidence/decoder-architecture-2026-10-20/;31 methods/1053 calls, including
  200 new calls and108 complete frozen consumer comparisons in regressions.
- **Evidence boundary:** Owned source/default dimensions, explicit flags,
  exact scalar words, raw modifiers/layers and unresolved semantics only. Head
  quotient is a candidate; no actual projection axes/alias/output binding,
  complete ordinary model adapter, physical fit or numerical Hailo execution.
- **Next acceptance gate:** TASK_hailo10h_ordinary_source_bindings.md, full
  source architecture/modifier integration and numerical Hailo execution.


### AES-SOURCE-011 — Owned ordinary source projection binding intent

- **Status:** `verified`
- **Owner:** original smidr.decoder_projections, checked tagged source views,
  owned ordinary architecture/file metadata and actual collection connections.
- **Executable evidence:** docs/HAILO10H_MOJO_DECODER_PROJECTIONS.md and
  docs/evidence/decoder-projections-2026-10-20/;38 methods/1168 calls,326 actual
  pinned header bindings and108 complete frozen consumer comparisons.
- **Evidence boundary:** Explicit initial ordinary role/axis/shape/output intent,
  complete per-file/tag/config ownership and hypothetical metadata extents.
  No full source fingerprint/local remote-model admission, complete rotary/
  modifier adaptation, numerical program, physical fit or LLM execution.
- **Next acceptance gate:** TASK_hailo10h_ordinary_rotary_modifiers.md,
  complete source architecture semantics and numerical Hailo execution.


### Ordinary omitted/null refinement — 2026-10-20

Refines AES-SOURCE-008/010/011 without introducing a new capability ID. Original
Mojo now applies qualified layer36, omitted KV4/null-query-heads and omitted
tie=true semantics with raw/default/null origins intact. Explicit null tying
and every remaining architecture/numerical gate stay unresolved. Evidence:
docs/HAILO10H_MOJO_ORDINARY_DEFAULTS.md;44 methods/1285 calls,28 complete old
explicit outputs,108 frozen consumer comparisons and326 metadata-only header
bindings. No model/device numerical execution or runtime external dependency.


### AES-SOURCE-012 — Explicit source-bound rotary mathematical lowering

- **Status:** `verified`
- **Owner:** original smidr.rotary_policy, primitive_recipes, expanded_graph and
  expanded_storage, owned two-input mappings and explicit basis/provenance.
- **Claim sources:** TASK_hailo10h_rotary_recipes.md and
  docs/HAILO10H_ROTARY_RECIPES_DESIGN.md, published before implementation.
- **Implementation evidence:** Original13-operation rotary recipes, exact typed
  Float32 base words, tail-preserving pair maps and rederived snapshot/graph checks.
- **Executable evidence:** docs/HAILO10H_MOJO_ROTARY_RECIPES.md and
  docs/evidence/rotary-recipes-2026-10-21/;104 methods/2864 native calls,
  30 rebuilt entrypoints,18 new full legacy and108 frozen regression comparisons.
- **Evidence boundary:** Mathematical IR and hypothetical storage only; explicit
  adjacent/split-half choice has no implicit format default. No full ordinary
  scalar/modifier adapter, device numerical precision/placement/fit, executable
  Hailo program or LLM execution. Missing operations/bases remain implementation work.
- **Next acceptance gate:** TASK_hailo10h_ordinary_rotary_modifiers.md, complete
  ordinary semantic integration and actual Hailo numerical configuration/execution.
- **Audit:** Final native source/binary identities and negative/ownership evidence
  retained; no external compiler, inference proxy or user conversion prerequisite.


### AES-SOURCE-013 — Exact source scalar words through mathematical lowering

- **Status:** `verified`
- **Owner:** original source_scalars/decoder_scalar_source, semantic graph,
  primitive/expanded scalar resolvers and snapshot/storage validation.
- **Claim sources:** TASK_hailo10h_source_scalar_precision.md and
  docs/HAILO10H_SOURCE_SCALAR_PRECISION_DESIGN.md, published before code.
- **Implementation evidence:** Owned32/64 tagged words, separate geometry/scalar
  builder, validated ordinary projection and exact recipe/expanded propagation.
- **Executable evidence:** docs/HAILO10H_MOJO_SOURCE_SCALAR_PRECISION.md and
  docs/evidence/source-scalar-precision-2026-10-21/;108 methods/2996 calls,
  32 rebuilds,20 new full legacy comparisons and108 frozen regression comparisons.
- **Evidence boundary:** Source representation/mathematical IR only; source word
  width never asserts device arithmetic precision. No complete ordinary modifier/
  architecture adapter, immutable file identity, placement/fit, numerical Hailo
  program or source-model execution. Other encodings remain implementation work.
- **Next acceptance gate:** TASK_hailo10h_ordinary_rotary_modifiers.md, complete
  ordinary semantics/graph integration and actual numerical Hailo execution.
- **Audit:** Exact source/binary/negative/ownership identities retained. No DFC,
  outside compiler/machine, inference proxy or special user conversion dependency.

Source-scalar shared import closure for AES-SOURCE-013: two additional ordinary
projection entrypoints rebuilt,7 methods/115 calls pass; combined115 methods/
3111 calls and34 builds. See docs/HAILO10H_MOJO_SOURCE_SCALAR_PRECISION.md.
No new capability ID or hardware/complete-source execution claim.


### AES-SOURCE-014 — Qualified ordinary head and bias source headers

- **Status:** `verified`
- **Owner:** original ordinary_projection_schema and extended source role binder.
- **Claim sources:** TASK_hailo10h_ordinary_projection_schema.md and
  docs/HAILO10H_ORDINARY_PROJECTION_SCHEMA_DESIGN.md, published before code.
- **Implementation evidence:** Owned qualified head declaration, seven optional
  bias aliases per layer, full tagged source/header/flag consistency and budgets.
- **Executable evidence:** docs/HAILO10H_MOJO_ORDINARY_PROJECTION_SCHEMA.md;
  14 methods/326 calls,4 warning-free builds,9 complete frozen outputs and326
  actual metadata-only source headers. New suite7/211,86 accepted125 refused.
- **Evidence boundary:** Header geometry/source binding only; old independent
  K/V intent unchanged. No bias arithmetic/full ordinary architecture, source
  fingerprint, physical fit, numerical Hailo program or LLM execution claim.
- **Next acceptance gate:** Original bias arithmetic/ordinary graph integration
  and actual Hailo numerical configuration/encoding/execution under the fixed target.
- **Audit:** Licensed meta-only constructor evidence and original independent
  source/ownership/mutation/negative traces retained; no external runtime/compiler.


### AES-SOURCE-015 — Source-bound decoder projection bias arithmetic

- **Status:** `verified`
- **Owner:** original bias_policy/bias_graph, typed semantic builders,
  primitive/expanded recipes and cache/matrix/storage consumers.
- **Claim sources:** TASK_hailo10h_decoder_bias_graph.md and
  docs/HAILO10H_DECODER_BIAS_GRAPH_DESIGN.md, published before code.
- **Implementation evidence:** Explicit per-layer flags, actual full-width source
  vectors, one-operation mathematical additions, checked source/derived snapshots,
  no-bypass/lifetime validation and bias-aware cache dependencies.
- **Executable evidence:** docs/HAILO10H_MOJO_DECODER_BIAS_GRAPH.md;20 suites,
  131 methods/3621 calls,41 warning-free rebuilds. New9/299 with147 accepted and
  152 expected refusals;8 complete frozen outputs and40 refusal/recovery cycles.
- **Evidence boundary:** Mathematical/source compiler support and hypothetical
  address/storage scenarios only. No complete ordinary modifier/architecture
  adaptation, immutable model identity, device precision/placement/fit, original
  executable Hailo numerical program or LLM inference claim.
- **Next acceptance gate:** Complete ordinary activation/modifier/graph integration
  and actual numerical Hailo configuration/encoding/upload/execution/cleanup.
- **Audit:** Source/binary/negative/frozen/ownership evidence retained; source32/64
  words remain exact. No external compiler, DFC, model forward or inference proxy.


### AES-SOURCE-016 — Source activation selection and mathematical lowering

- **Status:** `verified`
- **Owner:** original activation_policy/activation_graph/decoder_activation_source,
  semantic/primitive/expanded builders and downstream compiler consumers.
- **Claim sources:** TASK_hailo10h_decoder_activation_policy.md and
  docs/HAILO10H_DECODER_ACTIVATION_DESIGN.md, published before code at4a66acb.
- **Implementation evidence:** Owned bounded per-layer SiLU/erf GELU/ReLU choices,
  source projection retaining raw/default/unresolved modifiers, original five/one
  operation math recipes, source bias ordering and exact snapshot/edge validation.
- **Executable evidence:** docs/HAILO10H_MOJO_DECODER_ACTIVATION.md;21 suites,
  140 methods/4124 calls,46 warning-free builds. New9/503,
  135 accepted/368 expected refusals;8 complete frozen GGUF outputs,
  4 additional full comparisons,40 recovery cycles and48 isolated scalar outputs.
- **Evidence boundary:** Mathematical/source compiler support and hypothetical
  storage/address scenarios only. No complete ordinary architecture, immutable
  model identity, actual Hailo precision/placement/fit, executable numerical
  device program, original source-model execution or LLM inference claim.
- **Next acceptance gate:** Remaining activation variants/cache/window/scaling/
  training/full graph semantics and actual numerical Hailo configuration/encoding/
  delivery/activation/results/cleanup toward the fixed broad target.
- **Audit:** Qualified primary primitive facts and all source/binary/ownership/
  mutation/negative receipts retained. No external compiler or host LLM forward.


### AES-SOURCE-017 — Source cache-return and decoder session semantics

- **Status:** `verified`
- **Owner:** original session_policy/session_graph/decoder_session_source,
  semantic/recipe/expanded builders and cache/matrix/storage consumers.
- **Claim sources:** TASK_hailo10h_ordinary_cache_semantics.md and
  docs/HAILO10H_DECODER_SESSION_DESIGN.md, published before code at71dfa61.
- **Implementation evidence:** Owned bounded source/invocation return decisions,
  explicit cached-append/full-prefix modes, exact formal K/V exports and source/
  global lifetimes, independent policy snapshots and empty full-prefix cache
  layout without phantom capacity products. Original source facts remain owned.
- **Executable evidence:** docs/HAILO10H_MOJO_DECODER_SESSION.md;22 suites,
  147 methods/4730 native child calls,51 warning-free builds. New7/606,
  181 accepted/425 expected refusals;
  8 complete frozen GGUF and2 ordinary comparisons,160 recovery cycles/8 traces.
- **Evidence boundary:** Source/mathematical compiler support and hypothetical
  storage/address scenarios only. No complete ordinary architecture, numerical
  cache-reuse equivalence, device precision/placement/fit, executable Hailo
  numerical program or source-model inference claim.
- **Next acceptance gate:** Window/scaling/training/remaining architecture
  semantics and actual numerical Hailo configuration/encoding/delivery/results/
  cleanup toward the same fixed broad target.
- **Audit:** Full source/default/unresolved facts and32/64 words retained;
  source headers only, no payload mmap, host LLM forward or outside compiler.


### AES-SOURCE-018 — Source windows and mathematical causal mask lowering

- **Status:** `verified`
- **Owner:** original window_policy/decoder_window_source, typed semantic/recipe/
  expanded builders and session/bias/activation/cache/matrix/storage consumers.
- **Claim sources:** TASK_hailo10h_ordinary_window_semantics.md and
  docs/HAILO10H_DECODER_WINDOW_DESIGN.md, with pre-code published clarifications.
- **Implementation evidence:** Bounded owned source/invocation per-layer widths,
  independent numeric source-operation binding, original index/predicate/select
  recipe, exact snapshots/maps/domains/lifetimes and separate temporary-index
  storage timeline. Complete raw/default/dormant/unresolved source facts survive.
- **Executable evidence:** docs/HAILO10H_MOJO_DECODER_WINDOW.md;23 suites,
  154 methods/5455 native child calls,58 warning-free rebuilds. New7/725,
  226 accepted/499 expected refusals;
  16 frozen GGUF/8 ordinary comparisons,2720 integer admissions and10 extremes,
  160 recovery cycles/8 ownership traces and46 qualified constructor cases.
- **Evidence boundary:** Source/mathematical compiler support and hypothetical
  storage only. No full ordinary architecture/scaling/training adapter, physical
  cache compaction, immutable model identity, actual device precision/packing/
  placement/fit, executable Hailo numerical program or source-model inference.
- **Next acceptance gate:** Remaining ordinary scaling/training/architecture and
  actual numerical Hailo configuration/register/CCW encoding/delivery/results/
  cleanup toward the unchanged broad target.
- **Audit:** Exact source32/64 and negative/preliminary/source/binary/trace facts
  retained. No model/layer/attention forward, external compiler or inference proxy.


### AES-SOURCE-019 — Owned source default/linear rotary scaling

- **Status:** `verified`
- **Owner:** original scaling_policy/decoder_scaling_source and typed semantic,
  recipe/expanded/storage consumers with exact factor-word ownership.
- **Claim sources:** TASK_hailo10h_ordinary_scaling_semantics.md and
  docs/HAILO10H_DECODER_SCALING_DESIGN.md, published before production changes.
- **Implementation evidence:** Independent source/default/null/legacy/modern
  projection, exact32/64 factor binding, original13/14-step abstract rotary math,
  snapshots/maps/domains/lifetimes and temporary real-frequency storage. Original
  raw/dormant/unresolved facts remain; complete old outputs stay unchanged.
- **Executable evidence:** docs/HAILO10H_MOJO_DECODER_SCALING.md;24 suites,
  161 methods/6387 native calls,64 zero-diagnostic builds. New7/932 includes300
  accepted/632 expected refusals,560 mutations,16 frozen GGUF/8 ordinary outputs,
  160 recovery cycles/8 ownership traces. External48/120-word constant oracle
  is distinct from native numerical acceptance.
- **Evidence boundary:** Selected source/mathematical compiler behavior and
  hypothetical storage only. No full ordinary architecture/other scaling/training
  adapter, immutable source identity, hardware precision/packing/placement/fit,
  executable Hailo numerical program or source-model inference.
- **Next acceptance gate:** Remaining dynamic/context/cache-basis and other
  scaling/architecture semantics, actual numerical Hailo configuration/register/
  CCW generation, original delivery/activation/results/cleanup and broad support.
- **Audit:** Exact source words and negative/preliminary/binary/trace identities
  retained. No model/layer/attention forward, external compiler or inference proxy.


### AES-SOURCE-020 — Standalone dynamic rotary integer coefficient schedule

- **Status:** `verified`
- **Owner:** original smidr/dynamic_rotary_context.mojo and isolated native probe.
- **Claim sources:** TASK_hailo10h_dynamic_context_coefficients.md and
  docs/HAILO10H_DYNAMIC_CONTEXT_DESIGN.md, published before native edits247134c.
- **Implementation evidence:** Owned bounded retained-context selection and
  canonical rational exponent/delta schedule, explicit width2/pair0 identity,
  constant-space arithmetic and independent field revalidation. No old consumer
  imports or source/model admission changes.
- **Executable evidence:** docs/HAILO10H_MOJO_DYNAMIC_CONTEXT.md;4 methods/122
  native calls,91 accepted/31 expected refusals,1159 context/index and695 rational
  cases,576 qualified public state observations,11 field mutations and121 internal
  recovery cycles. One zero-diagnostic build;197 existing source hashes and64
  frozen control identities unchanged. Separate native isolation trace.
- **Evidence boundary:** Standalone integer compiler arithmetic only. No source
  dynamic integration, numerical frequency/rotation, cache-basis/full-prefix
  equivalence, model/layer/attention execution, device precision/encoding/fit,
  Hailo numerical program or source-model execution.
- **Next acceptance gate:** Exact source/factor/context-history/cache-basis and
  recipe/consumer/domain/lifetime/storage integration contract, then original
  implementation and actual Hailo numerical configuration/delivery/results.
- **Audit:** Public constant/index and fixed-pair identities are separate from
  native acceptance. Preliminary build errors/warning and identities preserved;
  no copied external implementation, model forward or device operation.


### AES-SOURCE-021 — Source-bound dynamic context and declared insertion history

- **Status:** `verified`
- **Owner:** original dynamic_decoder_policy/source_dynamic_decoder and isolated
  owned source-header/history inspectors.
- **Claim sources:** TASK_hailo10h_dynamic_decoder_integration.md phase1 and
  docs/HAILO10H_DYNAMIC_SOURCE_HISTORY_DESIGN.md, published7df6cef before code.
- **Implementation evidence:** Exact source64 factor/theta/default/legacy/modern
  context projection, independent invocation32/64 words, bounded append-history
  replay without coalescing, owned snapshots and rational coefficient connection.
  Complete original source/raw/unresolved fields remain retained.
- **Executable evidence:** docs/HAILO10H_MOJO_DYNAMIC_SOURCE_HISTORY.md;4 methods/
  244 native calls,170 accepted/74 expected refusals,2 zero-diagnostic builds,
  29 history/source mutation fields,220 internal recovery cycles,24 source recovery
  pairs and8 complete frozen source descriptor comparisons.30 traces/132 opens/
  132 closes,102 header reads,72 unchanged fixture identities. All199 previous
  source hashes/65 controls unchanged.
- **Evidence boundary:** Source/policy/integer lineage arithmetic only. No current
  graph/cache data consumer, actual cache ownership or immutable source proof,
  numerical frequency/attention/model forward, hardware packing/fit/encoding,
  Hailo numerical program or source-model execution.
- **Next acceptance gate:** Exact dynamic graph/recipe/consumer/domain/lifetime/
  storage/export contract, then original implementation and actual numerical
  Hailo configuration/placement/delivery/results toward the unchanged broad target.
- **Audit:** Preliminary argv/build/verification-order failures and identities
  preserved; final native-only refusals, unchanged build/test inputs, header/fd
  boundaries and no device/inference access independently checked.


### AES-SOURCE-022 — Dynamic source graph, owned positions and frequency recipes

- **Status:** `verified`
- **Owner:** original semantic_plan/primitive_recipes/expanded_graph/storage
  consumers and source-bound dynamic graph inspectors.
- **Claim sources:** TASK_hailo10h_dynamic_graph_lowering.md and
  docs/HAILO10H_DYNAMIC_GRAPH_LOWERING_DESIGN.md, published68ea3ff before code.
- **Implementation evidence:** Separate source context/capacity/retained state,
  before/after insertion histories, produced position_range, independent words,
  explicit15-step dynamic Q/K recipes, NoPE/cache/export rules and real/index
  lifetime/storage recomputation. Old constructor signatures and diagnostics stay.
- **Executable evidence:** docs/HAILO10H_MOJO_DYNAMIC_GRAPH_LOWERING.md;70 clean
  builds/208 relevant sources,27 suites/173 methods/7,059 primary calls. New4/306:
  171 accepted/135 native refusals,84 mutation fields. All67 frozen controls covered
  by3,129 full success outputs and3,287 handled-error comparisons.8 SafeTensors
  traces/19 opens/19 closes/20 header reads; separate GGUF read-only shared map,
  matching unmap and balanced descriptor. Extra repeated runs counted separately.
- **Evidence boundary:** Selected mathematical source/recipe/consumer behavior
  only. No actual cache-byte/model identity proof, native frequency/LLM tensor
  evaluation, numerical Hailo program, physical packing/fit/placement/encoding,
  source-model execution, whole-repository or hosted-CI pass.
- **Next acceptance gate:** Remaining architecture/format/modifier coverage and
  established numerical device fields, then original physical configuration,
  program generation/delivery/activation/results/cleanup toward broad support.
- **Audit:** Source/input/control identities and all development failures retained.
  SafeTensors header traces and GGUF whole-file mapping are explicitly scoped;
  no invented instruction, outside compiler, model forward or inference proxy.


### AES-CONTROL-001 — Owned nondefault LCU control record serialization

- **Status:** `verified`
- **Owner:** original smidr/lcu_actions.mojo and bounded host inspector.
- **Claim sources:** TASK_hailo10h_lcu_action_codec.md published7724738 before
  code; docs/HAILO10H_PROGRAM_TARGET_AND_LCU_BOUNDARY_2026-10-22.md.
- **Implementation evidence:** Independent scalar validation,exact owned packed
  bytes for IDs4/5/36,width/extent/reserved-bit and absent-field guards. Existing
  four-action module and public behavior unchanged. No physical value inference.
- **Executable evidence:** docs/HAILO10H_MOJO_LCU_ACTIONS.md;6 clean builds,
  17 methods/2113 primary calls,456 independent new vectors,492 native refusals,
  18 internal mutable-field recovery cycles and244 additional frozen pairs.
  Seven new traces contain no device/network/ioctl/inference-runtime access.
- **Evidence boundary:** Host byte serialization only. No instruction/register
  semantics,actual physical counts/placement,raw-context endpoint,numerical
  program upload/activation/results,source-model execution or whole-repo/CI pass.
- **Next acceptance gate:** Established H10H numerical/configuration/placement
  fields and original program delivery/activation/result/cleanup toward the
  fixed broad ordinary-source target. Continue bounded public-interface research.
- **Audit:** Exact source/input/binary/control identities and failed compile
  retained; all accepted tests native-only with independent header/struct bytes.


### AES-SOURCE-023 — Owned Q8_0 source constants and byte-tile integration

- **Status:** `verified`
- **Owner:** original source_q8_constants reader, packed source loader and
  source_weight_tiles consumer, with bounded native inspectors.
- **Claim sources:** TASK_hailo10h_q8_source_constants.md published9b69894 before
  code; docs/HAILO10H_Q8_SOURCE_LAYOUT.md pins the MIT source field facts.
- **Implementation evidence:** Source kind8,32-element/34-byte row geometry,
  owned exact scale-word/signed-quant windows, source-shape/span/bound guards,
  whole touched-block byte spans and preserved original axes/kind/path metadata.
- **Executable evidence:** docs/HAILO10H_MOJO_Q8_SOURCE_CONSTANTS.md;76 clean
  Mojo builds,30 suites/200 methods/9309 primary child calls. New10/137 includes
  59 refusals,1321 complete component comparisons,65536 scale patterns via a
  2097152-record integer digest,256 static reference values and3774 byte checks.
  All74 frozen controls covered by4308 success/4023 error pairs;10 traces/13
  balanced fixture opens/closes/readonly whole-file maps/unmaps. Extra repeated
  context4/122 plus122 frozen calls is counted separately.
- **Evidence boundary:** Current dense vector/matrix source importer only,
  with actual source payload representation decoding. No production floating
  tensor product,model/layer/attention forward,physical packing/fit/placement,
  Hailo numerical program,source-model execution or whole-repository/CI pass.
- **Next acceptance gate:** Remaining formats/ranks/architectures/operations and
  qualified H10H numerical/configuration fields,then original physical program
  generation/delivery/activation/results/cleanup toward the fixed broad target.
- **Audit:** Original compile and split-trace parser failures retained. Final
  native inputs unchanged;corrected audit and separately repeated report after
  runner filename collision preserve actual evidence without double counting.


### AES-SOURCE-024 — Original classic Q4/Q5 source conversion and shared geometry

- **Status:** `verified`
- **Owner:** original source_classic32_constants reader, packed GGUF geometry
  and source_weight_tiles consumer, with bounded native tools.
- **Claim sources:** TASK_hailo10h_classic32_source_constants.md published5b8c132
  before code; docs/HAILO10H_CLASSIC32_SOURCE_LAYOUT.md pins public MIT fields.
- **Implementation evidence:** GGUF2/3/6/7, shared block geometry, exact scale/
  bias bits and presence, quant fields, owned bounded windows and original
  source-byte tiles. Existing source geometry/guards/diagnostics preserved.
- **Executable evidence:** docs/HAILO10H_MOJO_CLASSIC32_SOURCE_CONSTANTS.md;
  81 clean current Mojo builds plus3 clean pre-code-snapshot baseline builds,
  643 actual source identities;32 suites/219 methods/10549 primary calls.
  New12/788 with26611 complete components,11322 byte checks,2048 static reference
  constants and45 traces/60 balanced readonly file lifecycles. All79 comparison
  controls covered by4753 success/4167 error pairs;76 binaries were frozen before
  code,3 compiled later from frozen actual pre-code sources. Full7/452 added
  source-storage suite and corrected real kind2 admission proof pass.
- **Evidence boundary:** Source conversion/byte integration only. No production
  floating tensor product/addition,model/layer/attention forward,physical device
  format/packing/fit/placement,Hailo numerical/source-model execution or whole
  repository/hosted-CI pass. Other formats/ranks/architectures remain work.
- **Next acceptance gate:** Remaining ordinary source/operation coverage and
  actual H10H numerical/configuration fields,then original physical program
  generation/delivery/activation/results/cleanup toward the fixed broad target.
- **Audit:** Original final-runner wrong-tool assertion and omitted storage
  suite retained,then closed with additive current/snapshot-baseline builds,
  complete storage tests and genuine namespace proof. Selected trace-parser
  whitespace and recorder trace-count failures retained; corrected audits pass.


### AES-SOURCE-025 — Original Q2_K/Q3_K source components and byte tiles

- **Status:** `verified`
- **Owner:** original source_q2q3_constants reader and shared packed GGUF
  geometry, existing source_weight_tiles consumer and bounded native tools.
- **Claim sources:** TASK_hailo10h_q2q3_source_constants.md published5ec7420
  before production;docs/HAILO10H_Q2Q3_SOURCE_LAYOUT.md pins MIT public fields.
- **Implementation evidence:** GGUF10/11 source geometry, exact d/dmin words
  and expanded bits, presence, signed group/quant fields and owned bounded
  windows. Original graph bindings and whole-touched-block byte tiles;old
  geometry/guards/diagnostics preserved.64 old Python inputs unchanged.
- **Executable evidence:** docs/HAILO10H_MOJO_Q2Q3_SOURCE_CONSTANTS.md;
  100 clean current Mojo builds plus17 clean late pre-code-snapshot controls,
  646 actual source identities;42 suites/291 methods/12853 primary child calls.
  New13/530,439026 complete components,32248 bytes,2048 isolated static values;
  27 new traces/36 balanced read-only lifecycles.98 controls covered by6040
  complete success/5370 exit/stdout/handled-error pairs.81 binaries frozen
  before production;17 subsequently built from preserved643-file snapshots.
- **Evidence boundary:** Source representation/conversion and byte integration
  only. No production floating tensor product/subtraction,model/layer/attention
  forward,device precision/packing/fit/placement,numerical Hailo/source-model
  execution or whole-repository/hosted-CI pass. Remaining formats/ranks,
  architectures and operations remain work toward100% of the broad target.
- **Next acceptance gate:** Actual H10H numerical/configuration evidence and
  original physical program generation/delivery/activation/results/cleanup,
  alongside remaining ordinary source/operation/architecture implementation.
- **Audit:** Selected syntax/warning history and explicit test-only C++ review
  retained. Expanded runner mistook ldd inspection for an API call after97
  native safetensors passes;additive reviewed nine-method/97-call pass and
  separate dependency inspection close it. No native pair is skipped or old
  test input changed. Complete original outputs retained under archive hashes.


### AES-SOURCE-026 — Original nonlinear IQ4 source components and byte tiles

- **Status:** `verified`
- **Owner:** original source_iq4_constants reader,shared packed GGUF geometry
  and unchanged generic source_weight_tiles consumer,with bounded native tools.
- **Claim sources:** TASK_hailo10h_iq4_source_constants.md publishedefb0ec0
  before code;docs/HAILO10H_IQ4_SOURCE_LAYOUT.md pins MIT public fields/table.
- **Implementation evidence:** GGUF20/23 geometry and original bit readers,
  exact d words/expanded bits,explicit group-scale presence/signed values,
  original nonlinear codes and signed source values;owned bounded windows,
  actual compiler bindings and whole-touched-block byte tiles.65 old Python
  inputs unchanged;old geometry/width limits/unrelated diagnostics preserved.
- **Executable evidence:** docs/HAILO10H_MOJO_IQ4_SOURCE_CONSTANTS.md;
  102 clean current Mojo builds,649 actual source identities;43 suites/
  305 methods/13399 primary child calls. New14/546,
  327602 complete components,27584 bytes,2048 isolated finite static
  values;27 new traces/36 balanced read-only lifecycles.100 pre-code controls
  covered by6379 complete successful stdout/5561 nonzero exit/stdout/
  handled-error pairs. No unrelated native comparison is skipped.
- **Evidence boundary:** Source representation/conversion and byte integration
  only. No production floating tensor product,model/layer/attention forward,
  accelerator precision/packing/fit/placement,numerical Hailo/source-model
  execution or whole-repository/hosted-CI pass. Remaining formats/ranks,
  architectures and operations stay work toward100% of the broad target.
- **Next acceptance gate:** Actual H10H numerical/configuration evidence and
  original physical program generation/delivery/activation/results/cleanup,
  alongside remaining ordinary source/architecture/operation implementation.
- **Audit:** Old Q8 audit whitespace failure retained;corrected auditor accepts
  normal resumed-call spacing on unchanged raw traces,with no native rerun.
  Exact pre-code snapshots and all100 existing binaries preserved.
  Full source-storage suite and direct20/23 admission proof;correct native API
  versus ldd classification,dependency inspection on both sides,PID-aware
  split-syscall joins and actual trace census. Full original outputs archived;
  published large-output receipts follow complete component comparisons.

### AES-SOURCE-027 — Original bounded observed source-byte digests

- **Status:** `verified`
- **Owner:** Original hailbru/source_digest and smidr/source_byte_digest leaves.
- **Claim sources:** TASK_hailo10h_source_byte_digest.md published at c2c678c
  before code; docs/HAILO10H_SOURCE_DIGEST_CONTRACT.md retains scope and references.
- **Implementation evidence:** Incremental owned SHA256 state reuses existing
  original compression; exact state/count guards, bounded same-fd positional
  reads, explicit attempt budgets and GGUF ownership adapter. All649 old Mojo
  sources and66 old Python inputs remain unchanged.
- **Executable evidence:** docs/HAILO10H_MOJO_SOURCE_BYTE_DIGEST.md and
  docs/evidence/source-byte-digest-2026-10-22/; eight clean builds, four suites,
  23 methods/905 primary calls. New451 calls; six selected controls/454 complete
  legacy pairs. All102 old controls preserved.28 new traces/28 matched descriptor
  lifecycles, ten maps/unmaps and78 kernel positional reads; three legacy traces.
- **Evidence boundary:** Observed byte-window hashing only. No atomic snapshot,
  parsed-metadata/artifact coherence, immutable source or binding identity,
  device precision/fit/placement, numerical Hailo or source-model execution.
  All existing fingerprint/execution flags remain false; broader format and
  architecture support remains implementation work under the fixed target.
- **Next acceptance gate:** Qualify owned immutable source bytes and connect
  parsing/conversion/artifact binding, alongside actual H10H numerical encoding,
  physical configuration and original-program execution work.
- **Audit:** Raw attempts and failures preserved. Runner output-log identity bug
  and test-only unsafe-buffer lifetime bug corrected; all final suites/builds
  and audits repeated. Independent exact mutation bytes, descriptor retention,
  truncation refusal without new mapped payload reads, PID-aware split-syscall
  joins, separate dependency inspection and zero skipped legacy pairs.

### AES-SOURCE-028 — Original owned sealed observed source-byte copies

- **Status:** `verified`
- **Owner:** Original hailbru/source_sealed_copy owner and bounded native tool.
- **Claim sources:** TASK_hailo10h_sealed_source_copy.md published at caf3240
  before production; docs/HAILO10H_SEALED_SOURCE_COPY_CONTRACT.md qualifies
  license-first UAPI fields and actual installed-kernel behavior.
- **Implementation evidence:** Bounded positional copy with independent attempt
  budgets, owned destination cleanup, exact same-fd extent checks, four kernel
  seals and final hash of actual sealed bytes. Old653 Mojo modules,67 Python
  inputs and104 frozen binary controls remain unchanged.
- **Executable evidence:** docs/HAILO10H_MOJO_SEALED_SOURCE_COPY.md and
  docs/evidence/sealed-source-copy-2026-10-22/; ten clean Mojo/two clean C builds,
  five suites/28 methods/1091 primary calls. New186 calls and208069 complete
  copied-byte comparisons. Eight controls/905 complete pairs;93 new traces,
  69 balanced anonymous destinations and92 source-path descriptor lifecycles.
- **Evidence boundary:** Immutable owned observed byte copy only. No atomic
  original-file snapshot, existing parser/artifact coherence, device precision,
  fit, placement, numerical Hailo or source-model execution. Existing source
  fingerprint/immutable-source/binding/execution flags remain false. Host bounds
  are policies; missing formats and architectures remain implementation work.
- **Next acceptance gate:** Owned sealed-descriptor parser and mapped-capacity
  integration, then coherent conversion/artifact binding, alongside actual H10H
  numerical configuration and original program execution work.
- **Audit:** All native suites passed; audit handler-registration/opaque-exit
  parsing and recorder path failures retained and corrected without native
  reruns. One opaque worker termination record remains unclassified. Full old
  outputs compared, two mutation fixtures restored and final bytes compared,
  no skipped pairs; independent fault budgets and exact cleanup traces.

### AES-SOURCE-029 — Owned sealed GGUF parser and source-reader integration

- **Status:** `verified`
- **Owner:** Original HAILBRU sealed owner, GGUFSeer/PackedGGUF and SMIÐR adapter.
- **Claim sources:** TASK_hailo10h_sealed_gguf_source.md published at39d187d and
  route clarification f208472 before production; fixed broad ordinary-model
  scope in docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md.
- **Implementation evidence:** Checked exclusive transfer, actual same-fd seals/
  extent and full digest, read-only shared mapping with independently captured
  capacity, persistent sealed admission across close and one byte-identical
  original table interpreter. Existing653 Mojo and68 Python inputs unchanged.
- **Executable evidence:** docs/HAILO10H_MOJO_SEALED_GGUF_SOURCE.md and
  docs/evidence/sealed-gguf-source-2026-10-22/;109 clean Mojo/two C fault-shim
  builds,46 canonical suites/322 methods/14257 primary calls,106 frozen
  controls/13123 complete pairs. New221 calls,6924 complete constant components,
  426 byte tiles,55 full source snapshots and eight structural graph comparisons.
- **Evidence boundary:** Owned immutable observed GGUF input at existing parser,
  constant/byte readers and structural compiler boundary. No atomic original
  snapshot, compiled-artifact/session identity, device format/fit/placement,
  numerical Hailo or source-model execution. Existing global flags stay false.
- **Next acceptance gate:** Coherent compiler/artifact ownership across the owned
  source lifetime, remaining ordinary formats/architectures/operations and real
  numerical H10H configuration/packing/placement/program execution/results.
- **Audit:**95 new traces,93 balanced memfds and72 exact-capacity unmaps;
  407 legacy traces, six complete mutation pairs and40 independent complete
  fault-log pairs. Shared-log and directory-mapping harness failures retained
  and corrected without production/old-test changes or omitted comparisons.
  One unreturned worker syscall remains opaque, with no inferred effect.


### AES-SOURCE-030 — Compiler-owned observed GGUF input lifetime

- **Status:** `verified`
- **Owner:** Original Mojo SMIÐR compiler owner and existing sealed-source loader.
- **Claim sources:** TASK_hailo10h_owned_gguf_compiler.md published at a416da3
  before production; docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md.
- **Implementation evidence:** New movable owner retains the actual sealed
  parser and expanded graph, recomputes the full input hash, rehydrates mutable
  caches with the existing interpreter and validates source-bound byte reads.
  No old production source changed; close/moves/exceptions preserve ownership.
- **Executable evidence:** docs/HAILO10H_MOJO_OWNED_GGUF_COMPILER.md and
  docs/evidence/owned-compiler-native-2026-10-22/;9 clean Mojo builds/3 C shims,
  23 methods/596 primary calls,7 controls/480 complete frozen pairs. New319 calls,
  38 complete graph/recipe triples,9952 components and173 exact byte tiles.
- **Evidence boundary:** Compiler INPUT lifetime and copied source representation,
  never numerical source-model execution, atomic original-file version,
  compiled chip-artifact identity or physical format/fit/placement. All global
  identity and execution flags remain false. Broad ordinary support stays100%.
- **Next acceptance gate:** Remaining ordinary adapters and executable-artifact
  binding plus real numerical encoding/configuration/packing/placement and
  original device-program delivery/results/cleanup.
- **Audit:**209 complete traces,204 balanced memfds/182 exact unmaps,100 complete
  post-map hash phases/3 intentional partial phases. Complete original-change,
  cache/move/close/refusal/recovery tests;7 selected old controls fully paired,
  no directory consumers or omitted comparisons. Initial harness failures retained.


### AES-SOURCE-031 — Owned sealed Safetensors parser and constant-input lifetime

- **Status:** `verified`
- **Owner:** Original Mojo SMIÐR source owner and shared Safetensors reader.
- **Claim sources:** TASK_hailo10h_sealed_safetensors_source.md published at42686ee
  before production; docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md.
- **Implementation evidence:** Exclusive sealed-fd admission, independently
  captured map capacity, persistent sealed-route guard and wrapper cleanup.
  ONE existing header/constant reader;40 old bodies byte-identical. Only the
  permitted old armvegr/safetensors.mojo changes;662 old Mojo/70 Python unchanged.
- **Executable evidence:** docs/HAILO10H_MOJO_SEALED_SAFETENSORS_SOURCE.md and
  docs/evidence/sealed-safetensors-native-2026-10-22/;117 current entries plus
  four late frozen-source controls built,119 zero-diagnostic builds/two identical
  inherited warnings, five clean C shims;50 suites/354 methods,14325 complete
  pairs across115 controls. New176 calls/263212 component words/15 full snapshots.
- **Evidence boundary:** Immutable observed source-input lifetime and static
  representation only. No atomic original version, global source/binding/artifact
  identity, numerical Hailo format/fit/placement or source-model execution.
  Broad ordinary support stays100%; remaining dtypes/ranks/formats remain work.
- **Next acceptance gate:** Owned ordinary config/index/shards and compiler
  bindings, remaining architecture/operation coverage and actual H10H numerical
  configuration/packing/placement/original program delivery/results/cleanup.
- **Audit:**102 new/630 other disjoint traces;110 source and96 sealed fd
  lifetimes,72 exact unmaps,172 complete sealed hash phases/one intentional
  partial phase. Three unreturned worker records stay opaque. Full mutation,
  independent fault-log and rename-deletion comparisons; initial harness
  failures preserved and full rerun passes without omitted comparisons.


### AES-SOURCE-032 — Owned sealed ordinary config and index metadata

- **Status:** `verified`
- **Owner:** Original Mojo SMIÐR observed source metadata owner.
- **Claim sources:** TASK_hailo10h_sealed_source_metadata.md published at06c7158
  before production; docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md.
- **Implementation evidence:** Movable sealed config/index owners, consuming
  parsers, full actual digest and bounded borrowed bytes; ONE existing JSON
  parser/helper. Zero old production edits;666 old Mojo/71 Python inputs exact.
- **Executable evidence:** docs/HAILO10H_MOJO_SEALED_SOURCE_METADATA.md and
  docs/evidence/sealed-metadata-native-2026-10-23/;8 clean Mojo/4 C builds,
  4 suites/27 methods/1268 qualified entry calls,892 complete pairs across six
  selected controls. New376 calls,48 independent raw JSON/counter vectors and
  16 independently restored original mutation runs;40 separate fault-log pairs.
- **Evidence boundary:** Scoped observed metadata byte ownership only. Writable
  caches/claimed hashes are not identity. No atomic original version, global
  source/binding/artifact identity, numerical format/fit/placement or execution.
- **Next acceptance gate:** Owned ordinary shards/compiler bindings, remaining
  formats/architectures/operations and actual H10H numerical configuration,
  packing/placement/original program delivery/results/cleanup. Broad support100%.
- **Audit:**253 new traces,273 source/251 sealed fd lifetimes balanced;416
  complete/2 bounded partial hash phases,294 metadata phases/292 observed EOFs,
  no source mappings.109 disjoint old traces;three unreturned worker records
  opaque. Valid-exponent test expectation and generation/empty-source auditor
  corrections retained; complete selected rerun passes without omitted pairs.


### AES-SOURCE-033 — Owned ordinary indexed and unindexed backing lifetime

- **Status:** `verified`
- **Owner:** Original Mojo SMIÐR sealed source collection orchestration.
- **Claim sources:** TASK_hailo10h_sealed_source_collection.md published atd218e01
  before production; docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md.
- **Implementation evidence:** New retained config/index/shard owners, consuming
  beneath-root file bridge, checked aggregate source bytes and complete joins;
  existing parsers/storage validators and bounded byte/constant helpers reused.
  All669 old Mojo sources/72 Python inputs exact; zero old production edits.
- **Executable evidence:** docs/HAILO10H_MOJO_SEALED_SOURCE_COLLECTION.md and
  docs/evidence/sealed-collection-native-2026-10-23/;14 clean current Mojo/6 C
  builds,7 suites/41 methods/1484 qualified entry calls,971 complete pairs across
  12 controls. New398 calls,182 full backing/component snapshots,245684 bytes,
  6120 component words and44 independent original-mutation runs.
- **Evidence boundary:** Observed compiler-input backing lifetime only. Writable
  caches/labels/claims are not identity; no atomic multi-file original revision,
  compiler/artifact identity, numerical format/fit/placement or model execution.
  Broad ordinary support100%; remaining formats/architectures/operations stay work.
- **Next acceptance gate:** Rehydrated owned ordinary compiler binding and actual
  H10H numerical configuration/packing/placement/original delivery/results/cleanup.
- **Audit:**290 new traces balance269 root/868 original/778 sealed lifetimes and
  336 exact maps/unmaps;1490 observed full hashes/930 metadata EOF phases.491
  disjoint other traces;two unreturned worker records opaque.28 full file mutation
  pairs,one full directory rename/deletion pair and65 independent fault-log pairs.
  Failed type/test/auditor/entry-routing attempts retained; full selected rerun
  covers all14 current entries and all12 controls without omitted comparisons.


### AES-SOURCE-034 — Retained ordinary compiler projection binding

- **Status:** `verified`
- **Owner:** Original Mojo SMIÐR retained ordinary compiler-input orchestration.
- **Claim sources:** TASK_hailo10h_owned_ordinary_binding.md published at9a0a91e
  before production; docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md.
- **Implementation evidence:** New indexed/unindexed wrappers retain actual sealed
  owners, schema and policies. Existing parsers/interpretation/binder rehydrate
  actual bytes and guard canonical component reads. All672 old Mojo/73 Python
  inputs exact; zero old production edits.
- **Executable evidence:** docs/HAILO10H_MOJO_OWNED_ORDINARY_BINDING.md and
  docs/evidence/owned-ordinary-binding-native-2026-10-23/;26 clean Mojo/9 C builds,
  13 suites/85 methods,2251 complete frozen pairs across24 controls. New840 calls,
  419 complete schemas,407 full/selected component snapshots,1133814 exact words.
- **Evidence boundary:** Observed compiler-input binding/static source conversion.
  No atomic multi-file original revision, global source/artifact identity, complete
  adapter, numerical format/fit/placement/program execution or device access.
  Broad ordinary-model support100%; missing coverage remains required work.
- **Next acceptance gate:** Owned mathematical graph integration and actual H10H
  numerical configuration/packing/placement/original delivery/results/cleanup.
- **Audit:**455 new traces balance455 root/1748 original/1608 sealed lifetimes,
  919 exact maps/unmaps;15162 complete/16 partial hashes and5818 metadata EOFs.
  910 disjoint other traces;one literal unreturned worker record opaque. Full
  stdout/stderr for5660 executions;34 file/345 directory-tree comparisons,
  45 changed trees and161 independent fault-log pairs. Failed attempts retained.


### AES-SOURCE-035 — Retained ordinary mathematical graph compiler lifetime

- **Status:** `verified`
- **Owner:** Original Mojo SMIÐR ordinary source compiler orchestration.
- **Claim sources:** TASK_hailo10h_owned_ordinary_compiler.md atfb77664 before
  production; docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md.
- **Implementation evidence:** New indexed/unindexed wrappers retain owned
  bindings, independent ExpandedGraph and bounded request copies. Existing
  source interpreters/builders preserve exact scalars and modifiers; guarded
  semantic component selection rederives actual sources and consumed intent.
  Zero old production edits;675 Mojo/74 Python inputs exact.
- **Executable evidence:** docs/HAILO10H_MOJO_OWNED_ORDINARY_COMPILER.md and
  docs/evidence/owned-ordinary-compiler-native-2026-10-23/;30 clean Mojo/9 C,
  14 suites/95 methods,3264 complete frozen pairs across28 controls. New10
  methods/1174 calls,103 full graph comparisons,34238 exact component words.
- **Evidence boundary:** Observed input-to-mathematical-IR lifetime and scoped
  static semantic selection. No generic immutable graph/artifact identity,
  complete adapter, numerical H10H format/fit/placement/program execution or
  device access. Duplicate tied-output semantics and other missing coverage
  remain required implementation toward broad ordinary-model support100%.
- **Next acceptance gate:** Actual numerical configuration/packing/placement,
  original program transport/activation/results/cleanup and remaining source
  format/architecture/operation implementation under the fixed owner scope.
- **Audit:**904 new traces balance904 root/3234 original/3160 sealed lifetimes;
  1807 exact maps/unmaps.7805 full output pairs retained.1143 full directory-tree
  comparisons,85 changed trees;193 independent frozen fault-log comparisons.
  New32 independent original-mutation runs/16 pairs and30 fault runs/15 pairs.
  Type/build, test expectation/oracle and frozen-directory runner failures retained.


### AES-CONTROL-002 — Owned sequencer configuration and completion serialization

- **Status:** `verified`
- **Owner:** Original Mojo smidr/sequencer_actions.mojo and bounded host tool.
- **Claim sources:** TASK_hailo10h_sequencer_actions.md published at a7ca592
  before production; docs/HAILO10H_SEQUENCER_INTERFACE_2026-10-23.md.
- **Implementation evidence:** Independent width,kind,exact extent and absent-
  field checks for packed context records1/17. Owned unsigned64 values preserve
  complete high-bit bitmap/offset data. Zero old source/test edits.
- **Executable evidence:** docs/HAILO10H_MOJO_SEQUENCER_ACTIONS.md;6 clean Mojo
  and3 C++ builds;27 methods/6094 primary calls and1611 complete frozen pairs.
  New1100 independent Python/header vectors,678 refusals and30 direct recovery
  cycles. Actual enum,packed size/offset and canonical ownership checks pass.
- **Evidence boundary:** Host wire intent only. No physical resource count,
  index/address validity,protobuf conversion,numerical instruction,placement,
  raw-context endpoint,original program delivery or source-model execution.
- **Next acceptance gate:** Established numerical encoding/configuration/
  packing/placement and original upload/activation/results/cleanup under the
  fixed broad ordinary unmodified model target. Missing coverage remains work.
- **Audit:**2880 new traces contain no observed Hailo/network/ioctl or excluded
  inference runtime effects;9 executables separately inspected. Actual681 Mojo/
  77 Python input copies and126 pre-code controls pinned. Development refusals
  retained with second type-probe source explicitly labelled reconstructed.


### AES-CONTROL-003 — Owned original program payload byte preparation

- **Status:** `verified`
- **Owner:** Original smidr/program_payload.mojo and bounded host diagnostic.
- **Claim sources:** TASK_hailo10h_program_payload_staging.md published c21df88
  before production;docs/HAILO10H_PROGRAM_PAYLOAD_BOUNDARY_2026-10-23.md.
- **Implementation evidence:** Separate copied2068-byte canonical action2 metadata
  and exact program bytes. Actual size/full-residue integrity,complete request
  comparison and fresh canonical metadata guards precede bounded window copies.
  Reuses original codecs/hashes;zero old production/test edits.
- **Executable evidence:** docs/HAILO10H_MOJO_PROGRAM_PAYLOAD.md;6 clean Mojo,
  43 selected methods/2885 primary calls and2495 complete frozen comparisons.
  New390 calls,2092 direct mutable-field/recovery cycles and complete independent
  struct/protobuf/hash byte oracles;copies/moves/scope/UTF8/NUL boundaries pass.
- **Evidence boundary:** Copied byte preparation only. Rehashed replacement and
  valid different header layout can be new wire intent;no immutable/executable
  artifact identity,protobuf semantics,numerical admission,DMA submission,live
  receiver acceptance,physical placement or source-model execution is claimed.
- **Next acceptance gate:** Actual grouped-buffer driver constraints,sealed output,
  in-flight DMA/deadline/late-failure cleanup and numerical/physical program
  generation/upload/activation/results toward the fixed broad source-model goal.
- **Audit:**390 complete new traces and6 executable dependency/symbol inspections;
  no observed Hailo/network/ioctl/excluded runtime effects. Actual684 Mojo/78
  Python copies and128 inherited plus4 supplementary pre-code controls pinned.
  Snapshot-copy setup refusal retained;no native build or acceptance failure.


### AES-CONTROL-004 — Owned grouped USERPTR launch value serialization

- **Status:** `verified`
- **Owner:** Original hailbru/soc_group.mojo and bounded host diagnostic.
- **Claim sources:** TASK_hailo10h_soc_group_codec.md published6e70ff2 before
  production;docs/HAILO10H_GROUPED_TRANSFER_BOUNDARY_2026-10-23.md.
- **Implementation evidence:** Copied ordered span values;fresh complete mutable
  field/count validation before allocation;canonical141-byte1..8 USERPTR codec.
  Exact profile/types/unused slots and checked pointer extents. Zero old edits.
- **Executable evidence:** docs/HAILO10H_MOJO_SOC_GROUP.md;3 Mojo/2 C++ links,
  20 methods/2179 primary calls,218 full frozen comparisons and227 independent
  public-header vectors.177 direct refusal/recovery cycles and ownership pass.
- **Evidence boundary:** Host scalar intent only. No physical mapping/pinning,
  descriptor accounting,DMA submission,live payload transaction,numerical program
  admission,activation or source-model execution. New overflow check is stricter
  than the unchanged old helper;one-span compatible-domain bytes match.
- **Next acceptance gate:** Actual grouped descriptor/owned storage/deadline/
  cleanup contract and numerical/physical program generation/results toward the
  same fixed broad ordinary unmodified model goal100%.
- **Audit:**1609 complete new traces;5 executables/10 ELF tables;no observed
  Hailo/network/ioctl/excluded runtime effects. Actual687 Mojo/79 Python copies,
  134 inherited and1 supplementary pre-code control. Inherited warnings scoped;
  baseline assumption/test naming/trace census corrections retained. Both
  selected acceptance suites pass;no native compile or test failure.


### AES-CONTROL-005 — Owned kernel-sealed original program output bytes

- **Status:** `verified`
- **Owner:** Original smidr/sealed_program_payload.mojo and bounded host tool.
- **Claim sources:** TASK_hailo10h_sealed_program_payload.md published73760c1
  before production;docs/HAILO10H_SEALED_SOURCE_COPY_CONTRACT.md.
- **Implementation evidence:** Exact staged program copied to owned anonymous
  sealed file;independent bounded positional I/O,full sealed readback comparison,
  fresh same-fd seals/extent/CLOEXEC/request/integrity/metadata guards per access.
  Original helpers reused;zero old production/test edits.
- **Executable evidence:** docs/HAILO10H_MOJO_SEALED_PROGRAM_PAYLOAD.md;8 clean
  Mojo/3 C,38 selected methods/3136 primary calls and2842 full frozen pairs.
  New294 traces,277987 exact bytes,2086 direct recovery cycles,29 injected runs.
- **Evidence boundary:** Immutable bytes in the actual sealed host object only.
  No historical global artifact identity,source-to-executable coherence,numerical
  program admission,USERPTR pin compatibility,physical DMA or source execution.
- **Next acceptance gate:** Qualified actual grouped DMA storage/descriptor/
  lifetime/deadline/late-cleanup boundary plus numerical/physical program
  generation,activation/results toward broad ordinary unmodified model support100%.
- **Audit:**2326 actual memfds/2326 closes,72 kernel protection refusals;11 ELF
  artifacts/22 tables. No observed Hailo/network/ioctl/excluded runtime effects.
  Actual690 Mojo/80 Python copies,137 controls. Failed type probe and initial
  runner ldd/import failures retained;final five suites pass unchanged old inputs.


### AES-CONTROL-006 — Bounded sealed output USERPTR map/unmap compatibility

- **Status:** `verified`
- **Owner:** Original smidr/tools/sealed_program_pin_probe.mojo diagnostic.
- **Claim sources:** TASK_hailo10h_sealed_program_pin_probe.md published1717edb
  before code;docs/HAILO10H_SEALED_PROGRAM_PIN_BOUNDARY_2026-10-23.md.
- **Implementation evidence:** Enumerated owned RO/private and RW/private sealed
  views;actual locally retained mmap returns;uncertainty armed before map;full
  original tuple validation;driver close before byte reads/backing release.
  Zero old production/test edits;no new raw OS interface.
- **Executable evidence:** docs/HAILO10H_MOJO_SEALED_PROGRAM_PIN_PROBE.md;
  24 host methods/672 primary calls/478 complete frozen pairs;55 new host traces.
  Actual13 physical cases:6 sealed profile/size variants and7 fresh controls,
  all map/unmap;13 file closes and13 owner unmaps;55580 exact bytes compared.
- **Evidence boundary:** Map-only compatibility on actual H10H driver5.3.0;
  no DMA transfer,cache coherence,grouped descriptor/in-flight safety,program
  admission,numerical operation or source-model execution.
- **Next acceptance gate:** Original grouped storage ownership,actual descriptor/
  completion/deadline/late cleanup and numerical program generation/delivery/
  activation/results toward broad ordinary UNMODIFIED source-model support100%.
- **Audit:** Independent C/kernel oracle6 cases/24 protection refusals;5 Mojo/
  5 C links,4 inherited new-consumer warnings,zero new-code warnings;20 ELF tables.
  Actual691 Mojo/81 Python final copies and139+1 pre-code controls. Failed close
  seam,build snapshot refusal and reused-address census assumption preserved.


### AES-CONTROL-007 — RPC backing retention after unconfirmed file close

- **Status:** `verified`
- **Owner:** Original hailbru/soc_session.mojo and isolated host API/fault tests.
- **Claim sources:** TASK_hailo10h_session_finalization.md published715862b
  before production;docs/HAILO10H_MOJO_SESSION_FINALIZATION.md.
- **Implementation evidence:** Permanent uncertain-finalization state;both
  allocations retained,CPU access revoked,combined errors preserved;repeated
  close/session reuse refused before fd retry.18 scoped original production lines.
- **Executable evidence:**18 methods,132 traced session children,210 complete
  frozen pairs,236 direct reuse refusals and10 combined cleanup-error checks.
  Seven affected old consumers plus new API linked;9 Mojo/1 C stable before tests.
- **Evidence boundary:** Host-only mocked close uncertainty and backing lifetime.
  No physical close-error behavior,DMA cancellation/late completion,grouped
  transport,numerical operation or source-model execution follows.
- **Next acceptance gate:** Original grouped backing/descriptor/completion/
  deadline/late cleanup and numerical program generation/delivery/activation/
  results toward broad ordinary UNMODIFIED source-model support100%.
- **Audit:**48 VMAs deliberately retained until exit;two frozen old consumers
  demonstrate the superseded release gap separately.11 artifacts/22 ELF tables;
  actual691/81 old and692/82 final Mojo/Python copies,141+6 frozen controls.
  Two C warning refusals preserved;final suites pass;inherited warnings scoped.


### AES-CONTROL-008 — Owned sealed two-part transaction byte backing

- **Status:** `verified`
- **Owner:** Original smidr/sealed_transfer_backing.mojo and bounded host tool.
- **Claim sources:** TASK_hailo10h_sealed_transfer_backing.md published5e977a4
  before code;docs/HAILO10H_MOJO_SEALED_TRANSFER_BACKING.md.
- **Implementation evidence:** Moved sealed program plus distinct sealed2068-
  byte metadata file;fresh full canonical/program integrity and actual same-fd
  byte/seal/extent/flag checks per window. Independent I/O bounds and owned copies;
  combined independent close errors retained. Zero old production/test edits.
- **Executable evidence:**57 selected methods,5291 primary calls,4699 complete
  frozen comparisons and236 new traces.2099 direct guard refusals;2246 actual
  metadata C/kernel checks and8984 protection refusals.11 Mojo/6 C links stable.
- **Evidence boundary:** Immutable actual host parts only;no historical global
  artifact identity,source-to-executable coherence,grouped descriptor/DMA,
  numerical admission,program activation or source-model execution.
- **Next acceptance gate:** Actual grouped storage/descriptor/completion/total
  deadline/late cleanup and numerical program generation/delivery/results toward
  broad ordinary UNMODIFIED source-model support100%.
- **Audit:**6622 memfds,6619 explicit closes and3 injected before-effect close
  retentions until exit.17 artifacts/34 ELF tables;actual692/82 old and695/83
  final Mojo/Python copies,148 controls. Both new consumers warning-free,9 old
  hashes exact. Failed CLI parser scope,C warnings and census correction preserved.


### AES-SOURCE-036 — Complete retained ordinary tensor representation comparison

- **Status:** `verified`
- **Owner:** Original smidr/ordinary_tensor_identity.mojo and scoped inspector.
- **Claim sources:** TASK_hailo10h_ordinary_tensor_identity.md published1a1516d
  before code;docs/HAILO10H_MOJO_ORDINARY_TENSOR_IDENTITY.md.
- **Implementation evidence:** Fresh actual retained indexed/unindexed binding
  revalidation;compatible exact source layouts;complete chunked raw-word scan;
  owned source descriptions and mismatch statistics. Zero old production edits.
- **Executable evidence:**33 selected methods,3588 primary calls,2412 complete
  frozen comparisons;640 actual payload-byte mutations,184192 independent bytes,
  379 new refusals,39 independent fault pairs.14 Mojo/2 C links stable before run.
- **Evidence boundary:** Observed full stored representations only;no persistent
  identity token,source-name merge,tied-output graph alias,numerical/device or
  source-model execution. Current duplicate tied-output compiler refusals remain.
- **Next acceptance gate:** Typed source alias with both bindings preserved and
  actual byte revalidation;actual H10H numerical configuration/packing/placement/
  program/results toward broad ordinary unmodified source-model support100%.
- **Audit:**1176 new traces,3660 original fds,3656 sealed files and1847 mappings
  with balanced cleanup.32 ELF tables;695/83 old and698/84 final source/test
  copies,150 controls. Failed API/harness/audit attempts remain immutable.


### AES-SOURCE-037 — Retained tied-output sources through mathematical lowering

- **Status:** `verified`
- **Owner:** Original smidr/source_weight_sharing.mojo and owned_tied_output_compiler.mojo.
- **Claim sources:** TASK_hailo10h_owned_tied_output_compiler.md published155d153
  before code;docs/HAILO10H_MOJO_OWNED_TIED_OUTPUT_COMPILER.md.
- **Implementation evidence:** Typed structural sharing,actual operation-use
  coverage,distinct full-byte source constants,fresh complete retained-source
  comparisons before graph construction and guarded static component selection.
- **Executable evidence:**56 selected suites/401 methods,23440 primary calls,
  18405 complete frozen pairs. New8 methods/4284 calls,1280 payload-byte refusals,
  2027 refusal-to-fresh-success controls,18 mutation and41 independent fault pairs.
- **Evidence boundary:** Observed source-sharing reconciliation and mathematical
  lowering only;no generic artifact identity,complete architecture admission,
  physical weight deduplication,numerical/device or source-model execution.
- **Next acceptance gate:** Actual H10H numerical configuration/packing/placement/
  program transport/activation/results/cleanup and every missing format/model/
  operation toward broad ordinary UNMODIFIED source-model support100%.
- **Audit:**4241 new traces,12717 beneath-root opens,12717 sealed files and6298
  exact map/unmaps,all observed fd generations closed.130 Mojo/11 C links,
  282 ELF tables,698/84 old and702/85 final copies,152 immutable controls.
  One inherited warning and all failed type/harness attempts remain preserved.


### AES-CONTROL-009 — Owned two-part sealed USERPTR mapping lifetime

- **Status:** `verified`
- **Owner:** Original smidr/sealed_transfer_pin.mojo.
- **Claim sources:** TASK_hailo10h_sealed_transfer_pin.md published314de97 before
  code;docs/HAILO10H_MOJO_SEALED_TRANSFER_PIN.md.
- **Implementation evidence:** Moved actual sealed metadata/program owners,two
  read-only private views,fresh qualified driver,guarded map/cleanup and permanent
  both-part retention/refusal after unconfirmed file finalization.
- **Executable evidence:**69 methods,4976 full frozen comparisons and92 new
  calls.7 actual physical children,3 two-part cases,10 maps/unmaps and7 driver
  closes before host release. Six complete kernel permission cases also pass.
- **Evidence boundary:** Bounded two-part map/unmap compatibility and observed
  lifetime only;no DMA/coherence,descriptor count,transfer deadline,numerical
  program admission or source-model execution. Close-error effects are host mocks.
- **Next acceptance gate:** Actual grouped descriptors,completion/total deadlines/
  late cleanup and numerical encoding/packing/placement/program/results toward
  broad ordinary UNMODIFIED source-model support100%.
- **Audit:**21 Mojo/9 C links,60 ELF tables,702/85 old and705/86 final inputs,
  154 controls.163 actual kernel-view checks and10 deliberate both-part lifetime
  retentions. All failed probes/harness/audit attempts remain immutable.


### AES-CONTROL-010 — Owned grouped prepare and cancellation wire values

- **Status:** `verified`
- **Owner:** Original hailbru/soc_prepare.mojo.
- **Claim sources:** TASK_hailo10h_soc_prepare_codec.md publishedaf2406f before
  production;docs/HAILO10H_MOJO_SOC_PREPARE.md.
- **Implementation evidence:** Exact139-byte prepare and8-byte cancellation
  codecs reuse existing checked group/scalar semantics and independent copied
  results,with bounded inspector and no device submission.
- **Executable evidence:**25 methods/5459 primary calls,2763 complete frozen
  comparisons.224 independent full prepare and68 cancellation vectors;977
  inspector refusal→fresh-success joins and324 direct API recovery cycles.
- **Evidence boundary:** Host wire values only;no mapping/prepare/cancel/transfer
  request,descriptor accounting/capacity,numerical admission or source-model
  execution. Active-DMA cancellation semantics remain unqualified.
- **Next acceptance gate:** Actual grouped descriptor/status/channel/storage/
  completion/deadline/late cleanup and numerical encoding/packing/placement/
  program/results toward broad ordinary UNMODIFIED model support100%.
- **Audit:**2988 new traces,52684 observed descriptor generations and closes,
  5 Mojo/3 C++ links,16 ELF tables.705/86 old and708/87 final inputs,156 controls
  and868 contract paths exact. Old production/tests remain unchanged.


### AES-CONTROL-011 — Observed launch counts and bounded exchange events

- **Status:** `verified`
- **Owner:** Original hailbru/soc_progress.mojo and soc_exchange_progress.mojo.
- **Claim sources:** TASK_hailo10h_observed_group_progress.md publishedca6dcc6
  before code;docs/HAILO10H_MOJO_OBSERVED_GROUP_PROGRESS.md.
- **Implementation evidence:** Distinct observed per-direction launch-count
  policy retains actual return values;existing exact RPC policy/IRQ parser stay.
  Original total deadline,snapshot budget and permanent failed-owner refusal.
- **Executable evidence:**15 methods/1928 primary calls and complete frozen
  comparisons:44 legacy pre-edit comparisons and1884 new-image reproducibility
  comparisons.771 inspector refusal/fresh-success joins;34 direct API cycles.
- **Evidence boundary:** Host event accounting using synthetic timestamps/counts;
  no device request,capacity prediction,coherence,memory release or numerical/
  source-model execution. Existing RPC device consumer was linked only.
- **Next acceptance gate:** Same-file channel/list/sealed-buffer owner and host
  fault/late cleanup qualification before bounded physical control RPC;actual
  numerical configuration/packing/placement/program/results remain required.
- **Audit:**1884 new traces,35796 file-fd generations/closes,4 final Mojo links,
  8 ELF tables;708/87 old and711/88 final inputs,158 controls and806 pre-code
  archive paths verified. One old production edit,zero old test edits;failed
  builds/warning gate retained. No whole-repository or hosted-CI pass.


### AES-CONTROL-012 — Same-file sealed session ownership (host qualification)

- **Status:** `verified`
- **Owner:** Original smidr/session_transfer_pin.mojo.
- **Claim sources:** TASK_hailo10h_session_transfer_pin.md published4fd644d before
  code;docs/HAILO10H_MOJO_SESSION_TRANSFER_PIN.md.
- **Implementation evidence:** One movable session owns assigned channels/lists
  and both actual sealed views/backing;existing original helpers are reused.
  Confirmed file cleanup differs from permanent uncertain-close retention.
- **Executable evidence:**76 methods/5554 primary/full frozen comparisons,
  including101 new native frozen-image checks;44 refusal/poison recovery joins,
  22 direct API fresh-owner guard cycles and8 poison reuse refusals.
- **Evidence boundary:** Host mocked driver mapping only;225 real kernel views,
  no physical Hailo pin/DMA,capacity prediction,hardware idle/remote closure
  confirmation,program activation or numerical source-model execution.
- **Next acceptance gate:** Separately bounded same-file physical map-only
  session qualification,then actual grouped transfer/completion/late cleanup and
  numerical configuration/packing/placement/program/results toward broad100%.
- **Audit:**101 current+101 frozen traces;8 actual both-part retention cases per
  image.23 Mojo/10 test C/C++ links,66 ELF tables;711/88 old,714/89 final inputs,
  161 controls and827 contract paths exact. Zero old production/test edits;
  initial oracle failure and all superseded attempts retained. No global CI pass.


### AES-CONTROL-013 — Same-file sealed session maps (physical acceptance)

- **Status:** `verified`
- **Owner:** Original smidr/tools/session_transfer_pin_probe.mojo.
- **Claim sources:** TASK_hailo10h_session_transfer_pin_physical.md published
  8a3d263 before code;docs/HAILO10H_MOJO_SESSION_TRANSFER_PIN_PROBE.md.
- **Implementation evidence:** Bounded synthetic two-part group uses published
  same-file owner;post-finalization full bytes and closed-group refusal.
- **Executable evidence:**3 host methods/29 complete frozen pairs and exactly
  4 physical children (one unchanged baseline,three new-owner sizes),all pass.
  Six real H2D maps,6 sealed-fd closes and6 exact owned unmaps after file close.
- **Evidence boundary:** Map-only observed success on driver5.3.0/H10H PCIe;
  no descriptor usage/capacity,coherence,DMA,RPC packet,all-failure hardware idle/
  remote cleanup confirmation,program activation or source-model execution.
- **Next acceptance gate:** Actual grouped transfer/count/completion/total
  deadline/late cleanup and numerical configuration/packing/placement/program/
  results toward broad ordinary UNMODIFIED source-model support100%.
- **Audit:**38 real permitted ioctls;130 physical file generations/130 closes.
  3 Mojo/2 C/C++ links,10 ELF tables;714/89 old,715/90 final inputs,163 controls
  and811 contract paths exact. Zero old production/test edits. Recorder-field
  failure retained;no repeated physical child. No whole-repository/hosted-CI pass.


### AES-CONTROL-014 — Owned grouped control-frame exchange (host qualification)

- **Status:** `verified`
- **Owner:** Original hailbru/soc_group_rpc.mojo.
- **Claim sources:** TASK_hailo10h_grouped_control_rpc.md published5af009a before
  code;docs/HAILO10H_MOJO_GROUP_CONTROL_RPC.md.
- **Implementation evidence:** Same-file session/storage owner forms natural
  header/body H2D spans,observes asymmetric positive launch returns,correlates
  IRQ transfer completions and enforces one total admission deadline/poison.
- **Executable evidence:**78 methods/4737 complete frozen comparisons,including
  287 new native pairs with complete normalized fault-state comparisons.
  Scope/preflight/partial/late/error/uncertain-close recovery cases pass.
- **Evidence boundary:** Host mocked exchange only;synthetic action1 frames do
  not qualify a server endpoint. No real Hailo ioctl/DMA,RPC packet,descriptor
  usage/capacity,all-failure hardware idle/remote closure or numerical execution.
- **Next acceptance gate:** Typed non-inference grouped lifecycle/cleanup,then
  separately bounded physical evidence;actual numerical configuration/packing/
  placement/program/results and broad ordinary UNMODIFIED model support100%.
- **Audit:**287 current+287 frozen traces;354 actual IRQ workers per image exit
  before owning close attempts.742 VMAs/712 unmaps plus30 deliberate retentions
  per image;33761 file generations/33754 closes plus7 retained mock fds.19 Mojo/
  4 C/C++ links,46 ELF tables;715/90 old,718/91 final inputs,164 controls and833
  contract paths exact. Zero old production/test edits;all failures retained.


### AES-CONTROL-015 — Typed grouped device lifecycle (host qualification)

- **Status:** `verified`
- **Owner:** Original hailbru/soc_group_device.mojo.
- **Claim sources:** TASK_hailo10h_grouped_device_rpc.md published626e9d6 before
  code;docs/HAILO10H_MOJO_GROUP_DEVICE_RPC.md.
- **Implementation evidence:** Fresh grouped owner reuses create20/identify22/
  destroy21 codecs;separate handle presence,one lifecycle admission deadline,
  preserved primary error,no destroy retry/poisoned reuse,and uncertain backing
  retention. At most three exchange attempts are observed.
- **Executable evidence:**90 methods/5134 complete frozen comparisons,including
  392 typed fault-state pairs,actual protobuf/header oracles,new bounded worker
  consumer and four clock/late-census refusals. All old source/test bodies remain.
- **Evidence boundary:** Host mocks only. Synthetic identity and grouped frames
  establish no real Hailo ioctl/DMA,RPC packet,descriptor capacity,all-failure
  hardware idle/remote closure,program activation or numerical source execution.
- **Next acceptance gate:** Separately bounded physical grouped lifecycle,then
  numerical configuration/packing/placement/original program/results and broad
  ordinary UNMODIFIED source-model support100%.
- **Audit:**1768 actual IRQ workers per image exit before owning close attempts;
  1466 VMAs/1454 unmaps plus12 deliberate retentions,118652 file generations/
  118649 closes plus3 retained mock fds per image.22 Mojo/5 C/C++ links,58 ELF
  tables;718/91 old,722/92 final inputs,168 controls and823 contract paths exact.
  All failures and superseded replays are retained;no global/hosted-CI pass.


### AES-CONTROL-016 — One physical grouped control attempt (offset rejection)

- **Status:** `partial`
- **Owner:** Original group_device_probe.mojo and test-only syscall observer.
- **Claim sources:** TASK_hailo10h_grouped_device_probe.md,published4d9f14c;
  docs/HAILO10H_GROUPED_DEVICE_PROBE_2026-10-24.md.
- **Implementation evidence:** Explicit5000ms typed lifecycle diagnostic and
  CPU-owned pass-through observation;all old source/test bodies preserved.
- **Executable evidence:**7 host methods/88 four-way comparisons (176 complete
  frozen pairs),2 auxiliary pairs and704 actual-schema checks. Inherited27 exact
  rebuilt images retain90 methods/5134 prior pairs without counting reruns.
- **Evidence boundary:** ONE real child:scalar D2H returns5,adjacent20/2048 H2D
  returns EINVAL;kernel reports map offset20 versus descriptor page512. No
  accepted handle,identity,destroy or assigned IRQ completion. Physical batch
  closed without repeat. This is negative transport evidence,not execution.
- **Next acceptance gate:** Original aligned backing/scatter/gather host work,
  then a separately published physical contract;actual numerical configuration/
  placement/program/results and full broad UNMODIFIED model support100% remain.
- **Audit:**19 actual ioctls;33 fd generations/33 closes;2 owned VMAs released
  after owning-file close. Disable/channel-close/unmaps/list releases succeed.
  No all-failure hardware idle or remote-close proof.723/93 final inputs,
  23 Mojo/7 C links,60 ELF tables. Failures retained;no global/hosted-CI pass.

### AES-CONTROL-017 — Aligned grouped control backing (host qualification)

- **Status:** `verified` (host scope only)
- **Owner:** Original hailbru/soc_storage.mojo,soc_session.mojo,
  soc_group_rpc.mojo,soc_group_device.mojo (aligned entry points only).
- **Claim sources:** TASK_hailo10h_aligned_grouped_control.md published
  be9db5d6 before code;docs/HAILO10H_ALIGNED_GROUPED_CONTROL_2026-10-24.md.
- **Implementation evidence:** Typed SocRpcLayout admitted only for
  power-of-two descriptor pages in[64,32768];aligned backing places the
  20-byte header at map offset0 and the 2048-byte body at offset page
  (extent page+2048;512 policy→512/2560). CPU-owned scatter/gather clears the
  whole mapped extent and projects the exact2068-byte logical wire;legacy
  layout(0,20,2068) and all legacy entry points/defaults are preserved.
- **Executable evidence:** New aligned suites pass in full:storage layout/
  scatter6 tests,grouped control10 tests,typed grouped lifecycle12 tests
  (oracle asserts map extents2560/2068,H2D span offset512,gap[20,512) zero,
  gathered canonical wire). Legacy grouped control10 and device12 suites pass
  rebuilt from edited sources with per-run stdout/stderr/exit byte-identical
  to pristine baselines across574+784 runs;storage bytes4 and session
  finalization6 pass. soc_group codec suite fails5/8 only on refusal-stream
  placement (this VM's Mojo build prints unhandled exceptions to stdout,not
  stderr);the pristine codec tool fails the identical5 — environment
  artifact,codec files untouched. Hardware suites (soc_storage/soc_session/
  soc_rpc) skip without --hardware and were not run.
- **Evidence boundary:** Host mocks only. No physical child was built or run
  under this contract;the AES-CONTROL-016 offset rejection remains the only
  physical grouped evidence. Aligned acceptance by the real driver,DMA,
  descriptor or IRQ completion,numerical configuration/packing/placement,
  program execution and source-model support are all unproven.
- **Next acceptance gate:** A separately published one-shot physical
  contract for exactly one grouped lifecycle on the aligned backing
  (roadmap slice1.4),then numerical configuration/packing/placement/original
  program/results and broad ordinary UNMODIFIED source-model support100%.
- **Audit:** Changes confined to the contract's four scoped modules plus new
  aligned tools/tests;15 final source files frozen with a SHA-256 manifest.
  One transient legacy-control failure under triple-suite CPU contention
  passed individually and on full rerun;recorded as contention flakiness.
  Failures retained;no global/hosted-CI pass.

### AES-CONTROL-018 — Aligned grouped lifecycle, one bounded physical attempt (partial)

- **Status:** `partial` (physical scope; acceptance failed, batch closed)
- **Owner:** Original smidr/tools/group_device_probe_aligned.mojo over the
  AES-CONTROL-017 aligned grouped owner;test-only aligned observer variant.
- **Claim sources:** TASK_hailo10h_aligned_grouped_physical.md published
  7bcfd81c before code;docs/HAILO10H_ALIGNED_GROUPED_PHYSICAL_2026-10-24.md.
- **Implementation evidence:** Aligned probe diagnostic and suite derived
  from the -016 probe (7 methods);aligned observer variant registers an
  aligned input extent (2048+power-of-two page in[64,32768]) and gathers
  the outgoing wire (header20@0,body2048@extent-2048) at the FOR_DEVICE
  sync boundary;the -016 observer is untouched. Host qualification ran on
  Mimir itself (the probe's 16384 page gate is the Pi profile):7 tests OK
  with the aligned observer;the legacy observer captured replies only.
- **Executable evidence:** Exactly ONE physical child on the real
  Hailo-10H (kernel 6.12.112-v8-16k-hailo+,page16384,PCIe 0x1e60/0x45c4,
  driver 5.3.0 profile validated before allocation),setsid plus a 20 s
  process-group watchdog,rc=1 in ~0.16 s. CREATE completed end-to-end:
  both launches returned the positive count5 (the -016 H2D EINVAL is
  gone),directional completions observed,exact typed reply after output
  CPU-sync,real handle known (value unpublished). IDENTIFY launched
  (D2H5,H2D5;spans at storage+0/20 B and storage+512/2048 B in the actual
  launch parameters) but its required distinct directional completions
  were not established within the client's progress snapshots;no reply
  became CPU-visible. Probe:attempts2,poisoned,identity unmatched,
  destroy not attempted (poisoned transport admits no cleanup destroy),
  retained_views0,finalization confirmed;observer 68 calls,0 dropped,
  owner_at_exit -1,all teardown calls returned0. Raw evidence stays
  local on the Pi;hashes are published in the evidence document.
- **Evidence boundary:** Acceptance failed:success,identity matched,
  attempts==3 and no-poison were required. The device-side handle from
  CREATE was NOT logically destroyed;local close is not hardware-idle
  or remote-close proof. Campaign 1's exit condition is not met. The
  cause of identify's incomplete completions is not established and
  none is claimed. Numerical configuration/packing/placement,program
  execution and source-model support remain unproven.
- **Next acceptance gate:** Any further physical lifecycle attempt
  requires a NEW one-shot contract (never a rerun of this batch).
  Host-side work continues at Campaign 2 slice 2.1 (transfer-semantics
  extraction on this evidence only),then numerical configuration/
  packing/placement/original program/results and broad ordinary
  UNMODIFIED source-model support100%.
- **Audit:** One child only;no repeat,no follow-on child. Contract-first
  order preserved (contract 7bcfd81c,probe 4448a7e5,observer a8a4f415).
  Failures retained;no global/hosted-CI pass.

### AES-TRANSFER-001 — Grouped transfer semantics extraction (specification)

- **Status:** `verified` (specification scope only;no code,no physical run)
- **Owner:** Analysis over the original grouped owner sources
  (soc_group.mojo,soc_group_rpc.mojo,soc_exchange_progress.mojo,
  soc_progress.mojo,soc_storage.mojo,soc_session.mojo).
- **Claim sources:** AES-CONTROL-015 host battery,AES-CONTROL-016 and
  AES-CONTROL-018 physical attempts,AES-CONTROL-017 aligned backing;
  docs/HAILO10H_GROUPED_TRANSFER_SEMANTICS_2026-10-24.md.
- **Specification evidence:** Six sections traced to code and evidence:
  S1 span description (1-8 spans,packed launch record;physical admission
  rule:span map-offset divisible by descriptor page — offset20 EINVAL,
  0/512 admitted);S2 launch return = actual descriptor count programmed,
  observed-return policy (admitted iff 1<=returned<65536 ring capacity;
  scalar 2068@512 = 5,grouped 20+2048 also 5,all four -018 launches
  returned 5;D2H posted before H2D);S3 completion evidence (IRQ wait
  records (engine,channel,data) against the pinned UAPI:data1 =
  completed,0 = none yet,0xFE channel-with-error,0xFF channel-not-
  active — failure indications,never counts;atomic snapshot validation,
  mask equality,one-outstanding correlation by channel,not timestamp);
  S4 cache-sync sequence (input FOR_CPU -> scatter -> input FOR_DEVICE
  whole extent -> output FOR_DEVICE -> launches -> per-direction
  transfer_finished -> output FOR_CPU -> gather;failed sync grants
  neither ownership);S5 ownership until completion (transfer_pending
  armed before the launch ioctl,owner re-verification per exchange,one
  outstanding pair,any error poisons and reuse requires a fresh owner,
  retained views accounted);S6 late-completion quarantine (single total
  deadline,<=32 snapshots,monotonic clock;no consumer after the loop;
  fresh owner/session for any later exchange).
- **New decoded datum:** Identify's second wait in -018 reported data
  0xFF (CHANNEL_NOT_ACTIVE) for BOTH owned channels (0 and 16) —
  recorded as an addendum in the -018 evidence document. Whether the
  transfers completed device-side before inactivation is NOT
  established;the primitive must specify this presentation explicitly
  and must not credit it as success.
- **Evidence boundary:** Specification only. The per-span descriptor
  sum, finer sync granularity, multi-outstanding exchanges, >8 spans,
  grouped output and timestamp correlation are all recorded as NOT
  established. Numerical configuration/packing/placement,program
  execution and source-model support remain unproven.
- **Next acceptance gate:** Slice 2.2 — implement the minimal transfer
  primitive in Mojo on S1-S6 only (not a general arbitrary-RPC API),
  then 2.3 host qualification and a separately contracted 2.4 bounded
  physical confirmation.
- **Audit:** No source code changed by this slice beyond documentation;
  the -018 evidence document gained a clearly marked decode addendum.
  Failures retained;no global/hosted-CI pass.

### AES-TRANSFER-002 — Minimal grouped transfer primitive (implementation)

- **Status:** `implemented` (host build only;qualification is slice 2.3)
- **Owner:** Original hailbru/soc_transfer.mojo (SocGroupedTransfer) plus
  smidr/tools/group_transfer_mock.mojo host-mock diagnostic.
- **Claim sources:** AES-TRANSFER-001 specification S1-S6;
  docs/HAILO10H_GROUPED_TRANSFER_PRIMITIVE_2026-10-24.md.
- **Implementation evidence:** One outstanding raw grouped exchange:
  exchange_raw takes caller-owned logical packet bytes (<=2068) and
  returns the raw 2068-byte reply extent;no framing or payload
  semantics. S1 two-span input group over legacy/aligned layouts;S2
  D2H-before-H2D launch order with observed-return admission via the
  shared SocExchangeProgress;S3 shared atomic completion consumer
  (0xFE/0xFF = failure,never completion — the -018 NOT_ACTIVE
  presentation is a specified poison path);S4 the extracted sync
  sequence;S5 captured-owner re-verification,busy flag,any error
  poisons and reuse requires a fresh owner;S6 one total deadline,
  <=32 snapshots,monotonic clock. Shares all lower owners with the
  RPC client (SocSession,SocStorage,progress,group codec,ABI).
- **Executable evidence:** Mojo 1.0.0 build of the host-mock
  diagnostic is clean (the one warning is pre-existing in
  soc_session.mojo);argument/physical-root refusals verified by smoke
  (rc=1 before any owner exists). No mock-oracle exchange has run yet.
- **Evidence boundary:** soc_group_rpc.mojo and soc_group_device.mojo
  are deliberately untouched — the AES-CONTROL-015/-017 qualification
  and -018 physical evidence stand on those exact sources. Host
  qualification (deadline accounting,poison-on-uncertainty,ownership
  lifetimes,late-completion quarantine,behavioral comparison with the
  RPC client) is slice 2.3;physical confirmation is a separately
  contracted slice 2.4. Numerical configuration/packing/placement,
  program execution and source-model support remain unproven.
- **Next acceptance gate:** Slice 2.3 host qualification battery for
  the primitive against the qualified device oracle.
- **Audit:** Additive slice:two new files plus documentation. No
  existing source modified. Failures retained;no global/hosted-CI pass.

### AES-TRANSFER-003 — Grouped transfer primitive host qualification

- **Status:** `verified` (host scope only)
- **Owner:** Original hailbru/soc_transfer.mojo exercised through
  tests/hailo_group_transfer_aligned_api.mojo (direct consumer) and
  smidr/tools/group_transfer_mock.mojo (probe diagnostic).
- **Claim sources:** AES-TRANSFER-001 specification S1-S6;
  docs/HAILO10H_GROUPED_TRANSFER_QUALIFICATION_2026-10-24.md.
- **Executable evidence:** tests/test_hailo_group_transfer_aligned.py
  (derived from the AES-CONTROL-017 aligned control suite;same
  qualified oracle and fault library,unchanged):11 tests OK,574
  recorded runs (374 probe,194 API,6 cross-check),every run compared
  for byte-identical stdout/stderr/exit and oracle-event equality.
  Exact/boundary frames {0,1,19,20,21,2047,2048}x{1,3};descriptor
  return boundaries {(1,1),(1,65535),(65535,1),(65535,65535),(7,5)}
  admitted,{-1,0,65536,2^31-1} poisoning per direction;all sync/
  launch/enable/wait/reply faults poison with fresh recovery;IRQ
  atomicity,partial,duplicate,foreign,count,error (0xFE/0xFF class),
  mask and engine cases;total deadline faulted at every observed
  clock stage;partial construction and cleanup faults;uncertain
  close retains exactly 2 views with one file-close attempt;12 guard
  refusals;6 primitive-layer preflight poisons. Test_11:the
  primitive's diagnostic output is byte-identical to the qualified
  RPC client's on identical scenarios.
- **Qualification history:** Two iterations failed ONLY on
  reply-framing faults (reply_magic,then reply_id):the framing-free
  primitive completed the transport and nothing poisoned the owner.
  Resolution is a consumer-layer contract,now qualified:the consumer
  validates the reply (decode,id,action,status) and poisons+closes
  the owner on framing failure,composing cleanup failure as the RPC
  client's exchange does. The only primitive change was removing a
  redundant pre-check so oversize packets refuse (and poison) at the
  storage write,as the client's do. Run totals 538/558/574.
- **Evidence boundary:** Host mocks only;no physical child. Slice
  2.4 (separately contracted bounded physical confirmation) remains
  for Campaign 2's exit. Numerical configuration/packing/placement,
  program execution and source-model support remain unproven.
- **Next acceptance gate:** Slice 2.4 contract,then Campaign 3
  program resource lifecycle.
- **Audit:** Additive test files plus the one recorded primitive
  comment/pre-check change;oracle and fault library untouched.
  Failures retained;no global/hosted-CI pass.

### AES-TRANSFER-004 — Grouped transfer primitive, one bounded physical exchange

- **Status:** `verified` (physical scope: one control-class exchange)
- **Owner:** Original smidr/tools/group_transfer_probe.mojo over
  hailbru/soc_transfer.mojo (AES-TRANSFER-002),consumer layer as
  qualified under AES-TRANSFER-003.
- **Claim sources:** TASK_hailo10h_grouped_transfer_physical.md
  published 55a4b9ba before code;
  docs/HAILO10H_GROUPED_TRANSFER_PHYSICAL_2026-10-24.md.
- **Executable evidence:** Host gates on Mimir:derived probe suite
  (same device oracle/aligned observer as AES-CONTROL-018) 7 tests
  OK. Profile re-checked read-only immediately before the run
  (kernel 6.12.112-v8-16k-hailo+,page16384,PCIe 0x1e60/0x45c4;
  driver 5.3.0 profile validated by the owner query before
  allocation). Exactly ONE physical child (setsid,20 s process-group
  watchdog,aligned observer),rc=0:accepted,exchange completed,
  descriptor returns exactly 5/5 as spec S2 predicts,3 interrupt
  snapshots,input/output completions 1/1,typed CREATE reply
  validated at the consumer layer (id/action exact,status 0,handle
  present;value unpublished),not poisoned,retained_views 0,
  finalization confirmed. Observer:54 calls,0 dropped,
  owner_at_exit -1. Hashes published in the evidence document;raw
  evidence stays local on the Pi.
- **Evidence boundary:** One exchange only. IDENTIFY completion and
  DESTROY remain unproven (AES-CONTROL-018);the handle this CREATE
  made was NOT logically destroyed — the residue stated in the
  contract before the run. Campaign 1's exit condition remains
  unmet. Numerical configuration/packing/placement,program
  transfer/activation/execution and source-model support unproven.
- **Next acceptance gate:** Campaign 3 slice 3.1 (program resource
  lifecycle interface qualification). Campaign 2's exit condition
  is met by AES-TRANSFER-001..004.
- **Audit:** One child only;contract-first order preserved
  (contract 55a4b9ba,diagnostic+suite c88b2753). Failures retained;
  no global/hosted-CI pass.

### AES-PROG-001 — Program resource lifecycle interface qualification (specification)

- **Status:** `verified` (specification scope only;no code,no physical run)
- **Owner:** Analysis over the pinned-source delivery-boundary study
  and the original host-qualified codecs (hrpc_program.mojo,
  hrpc_configure.mojo,hrpc_device.mojo).
- **Claim sources:** docs/HAILO10H_PROGRAM_DELIVERY_BOUNDARY.md
  (HailoRT d503417f,drivers 45e5fc53 v5.3.0 — interface facts only);
  docs/HAILO10H_PROGRAM_LIFECYCLE_INTERFACE_2026-10-24.md;
  AES-CONTROL-008/-009 two-part payload work;AES-TRANSFER-001..004.
- **Specification evidence:** Q1 ESTABLISHED:creation = hRPC action2
  create-infer-model (nested vdevice handle,declared program byte
  count u64,UTF-8 name;reply = infer-model handle;all-ones =
  invalid sentinel). Q2 PARTIAL:program bytes are a separate phase
  of exactly the declared count,never inside the 2048-byte protobuf
  body;Aesir's two-part staged form (AES-CONTROL-008/-009) has
  physically verified two-part USERPTR mappings — as mappings,not
  delivery;the phase's transport mechanics are NOT ESTABLISHED.
  Q3 NOT ESTABLISHED for the payload phase (no chunk/offset
  assumption admitted). Q4 ESTABLISHED at interface level:each
  stage completes by its typed reply under the Campaign2 completion
  law;readiness is the distinct action4 stage,whose reply
  (configured handle + async queue size) is the readiness artifact;
  no async readiness signal is established or assumed. Q5
  ESTABLISHED:action4 configure (infer+vdevice handles,stream
  formats,batch,power,latency,KV-cache) finalizes. Q6 PARTIAL:
  teardown actions 3/5/10/11/12 exist as host-qualified handle-only
  codecs;their ordering/preconditions for partial states are NOT
  ESTABLISHED. Q7 ESTABLISHED:two handle tiers — infer handle
  (actions 4,3) vs configured handle (actions 10,11,12,5).
- **Evidence boundary:** Interface specification only. Payload-phase
  mechanics,teardown ordering and everything numerical (CCW,
  configuration values,placement,execution) remain unproven.
- **Next acceptance gate:** Slice 3.2 — program-object lifecycle in
  Mojo over the Campaign2 primitive with the ProgramIdentity record,
  modelling Q2/Q6 as explicit fail-closed stages.
- **Audit:** No source code changed by this slice beyond
  documentation. Failures retained;no global/hosted-CI pass.

### AES-PROG-002 — Program-object lifecycle owner, host qualification

- **Status:** `host-verified` (mock transport;no physical run)
- **Owner:** Original hailbru/soc_program.mojo composing the
  qualified hrpc_program/hrpc_configure codecs over
  hailbru/soc_transfer.mojo (AES-TRANSFER-002);diagnostic
  smidr/tools/program_mock.mojo;new test-only oracle
  tests/group_program_rpc_aligned_faults.c.
- **Claim sources:** AES-PROG-001 interface qualification;
  docs/HAILO10H_PROGRAM_LIFECYCLE_HOST_2026-10-24.md.
- **Executable evidence:** tests/test_hailo_program_mock.py on
  Mimir (Mojo 1.1.0):8 tests OK,116 runs,zero physical calls.
  Full seven-stage lifecycle (create -> attested configure ->
  activate -> deactivate -> shutdown -> destroy-configured ->
  destroy-infer) with observer wires byte-identical to fixtures
  the suite computed independently in Python from the pinned
  public field contract. All six fail-closed gates refuse at the
  designed stage/exchange counts (configure without attestation
  of the identity's exact encoded-program digest;bad digest;
  early configure/destroy;double create;destroy-configured before
  shutdown). Crafted reply corruption (id/status/action) poisons;
  sync/launch faults poison;close faults block acceptance;
  observer logging failure/overflow inert;errno passthrough;
  argument refusals. ProgramIdentity (seven digests) prints
  before any exchange.
- **Recorded oracle fact:** the AES-CONTROL-018 device oracle is
  hardcoded to the device lifecycle sequence (actions 20/22/21,
  sequence <4) and aborts on program actions;the first Pi run's
  5 failures were those aborts,root-caused and resolved with the
  dedicated program oracle — the code under test was unchanged.
- **Evidence boundary:** Host mocks only. The action-2 payload
  phase,receiver teardown ordering,structural acceptance of any
  program object and all numerical content remain unproven.
- **Next acceptance gate:** Slice 3.3 — one-shot physical contract
  for the program lifecycle, beginning from the payload-phase
  observation question (AES-PROG-001 Q2).
- **Audit:** soc_transfer/soc_group_rpc/soc_group_device untouched.
  Failures retained;no global/hosted-CI pass.

### AES-PROG-003 — Program lifecycle, one bounded physical observation run

- **Status:** `verified` (observation scope: branch B2 established
  physically;no program object created)
- **Owner:** Original smidr/tools/program_lifecycle_probe.mojo over
  hailbru/soc_program.mojo + hailbru/soc_transfer.mojo.
- **Claim sources:** TASK_hailo10h_program_lifecycle_physical.md
  published b34e11e1 before code (one poison-law refinement
  recorded in it pre-code);
  docs/HAILO10H_PROGRAM_LIFECYCLE_PHYSICAL_2026-10-24.md.
- **Executable evidence:** Host gates on Mimir:branch-table suite
  against the program oracle 6 tests OK (B1/B2/B3 paths,Phase-A
  failure,close faults,argument refusals;qualification history
  retained,including the S6 32-snapshot corroboration). Profile
  re-checked read-only immediately before the run. Exactly ONE
  physical child (setsid,20 s watchdog,aligned observer),rc=0:
  Phase A device CREATE completed and validated (1 completed
  exchange);Phase B action-2 metadata exchange did NOT complete —
  no reply CPU-visible,no directional completion credited,5
  snapshots total,child finished far inside its 5 s budget (the
  failure presented promptly,not as a hang),owner poisoned by law,
  no further attempt,retained_views 0,finalization confirmed,
  observer 68 calls/0 dropped/fd closed.
- **Evidence boundary:** B2 rules out metadata-alone replies on
  this channel and is consistent with the receiver reading the
  separate program-bytes phase before answering (AES-PROG-001
  Q2);it does NOT establish the phase's mechanism or the failure's
  interrupt-record class (not captured,not claimed). No infer
  handle obtained;no payload sent (per contract);no configure or
  program teardown exercised. This run's Phase-A virtual-device
  handle was NOT logically destroyed — the contract's pre-stated
  B2 residue,joining the -018/-004 record. Campaign 3 exit NOT met.
- **Next acceptance gate:** Lane A/B source study of the
  receiver's create-infer-model read path to specify the payload
  phase;only then a successor physical contract. Slice 3.4
  (failure teardown) proceeds host-side meanwhile.
- **Audit:** One child only;contract-first order preserved.
  Failures and harness history retained;no global/hosted-CI pass.

### AES-PROG-004 — Failure teardown accounting + payload-phase source study

- **Status:** `host-verified` (failure accounting) + `verified`
  (source-study scope);no physical run in this slice.
- **Owner:** smidr/tools/program_mock.mojo fail-at-<stage>
  scenarios over hailbru/soc_program.mojo;source study of the
  pinned receiver (hailort_server.cpp @ d503417f,MIT).
- **Claim sources:** docs/HAILO10H_PROGRAM_FAILURE_TEARDOWN_2026-10-24.md;
  AES-PROG-001 Q2/Q6;AES-PROG-003 branch B2.
- **Executable evidence:** tests/test_hailo_program_mock.py on
  Mimir:10 tests OK,148 runs,zero physical calls. Corrupting
  each stage's reply in turn yields the exact designed
  accounting — stop at the failing stage,poison,no further
  exchange,and the correct residue tier (create failure = worst
  class:infer possibly created,handle never learned;
  destroy-infer failure = infer-only residue with configured
  destroyed). A transport failure at create accounts 0/0.
  Recovery-by-adoption is deliberately NOT implemented (handle
  validity across sessions unestablished).
- **Source-study evidence:** parse_request for action2 reads
  exactly hef_size bytes via client_connection->read_buffer
  (LONG_RPC_ACTION_TIMEOUT) between metadata and reply — the
  payload phase's shape is ESTABLISHED and matches B2.
  Destroy-configured performs shutdown() receiver-side before
  release (Q6 precondition answered at source level;the owner's
  conservative order is retained). cleanup_client_resources
  releases ALL of a client's resources on connection cleanup —
  a named reclaim mechanism for the recorded residue class;
  whether our sessions' termination triggers it on this
  transport is NOT established.
- **Evidence boundary:** The SoC connection layer's realization
  of read_buffer/write_buffer (chunking,transfer pairing,who
  launches) remains NOT ESTABLISHED — the next Track R step and
  the gate for any payload-sending successor contract.
  Campaign 3 exit still unmet.
- **Next acceptance gate:** Track R connection-layer study;then
  Campaign 4 slice 4.1 (field-table discipline) per roadmap
  order,with the payload successor contract when specified.
- **Audit:** soc_program/soc_transfer unchanged by the study
  half. Failures retained;no global/hosted-CI pass.

### AES-NUM-001 — Device-program field table (Campaign 4 entry)

- **Status:** `verified` (specification scope:evidence-graded field
  inventory;no emitter,no bytes,no operation claimed).
- **Owner:** docs/HAILO10H_NUMERICAL_FIELD_TABLE_2026-10-24.md.
- **Claim sources:** Pinned HailoRT d503417f (hef.proto,
  context_switch_defs.h,control_protocol.h,config_buffer and
  rpc_connection sources — MIT,interface facts only);repo
  evidence AES-CONTROL-001/002/015..018,AES-TRANSFER-001..004,
  AES-PROG-001..004;LCU boundary study 2026-10-22.
- **Content:** Five groups. A container metadata (arch=HAILO1XH
  103 IN as metadata;CCW pointer/inline actions IN as references/
  carriers only;partial-layout bitmap OUT for this target).
  B context action records (packed layouts IN via public defs and
  AES-CONTROL-001/002 owners;ID35 typed-write ADDRESS VALUES out —
  no safe address in evidence). C config units (8-byte CCW header
  unit and zero NOP IN as units;CCW WORDS out entirely — no public
  bit layout found). D transport fields (the physically
  corroborated minority:HRPC framing,action numbers,512
  descriptor policy,span divisibility,launch-return counts,IRQ
  data semantics). E numerical semantics — quantization,
  accumulator,tile,assignment,weight layout — ALL OUT.
- **Track R addendum (in the doc):** rpc_connection.cpp at the
  pin:messages capped at 2048;buffers ride one async session read
  of the total declared size after a readiness wait — the B2
  payload phase is a single logical transfer,not messages. The
  session readiness protocol on the SoC engine remains NOT
  ESTABLISHED and still gates payload contracts.
- **Evidence boundary/prediction (recorded in advance):** no
  operation can clear Campaign 4's eight layers until the CCW
  word layout or an equivalent device-consumed encoding is
  established;4.2 selects by evidence strength knowing this.
- **Next acceptance gate:** Slice 4.2 operation selection record;
  Track R session-layer study continues.
- **Audit:** Specification only. No global/hosted-CI pass.

### AES-NUM-002 — First operation selection (Campaign 4)

- **Status:** `verified` (specification scope:selection record
  with scored alternates and a pre-stated layer prediction).
- **Owner:** docs/HAILO10H_FIRST_OPERATION_SELECTION_2026-10-24.md.
- **Claim sources:** AES-NUM-001 field table (all dependency
  grades inherited from it).
- **Decision:** The first operation is the ELEMENTWISE IDENTITY
  COPY of a single tensor — the only candidate whose correctness
  depends on no OUT field (bytes in = bytes out under any
  representation), with a byte-exact independent oracle and the
  smallest complete shape (1 in,1 out,no parameters). ReLU is
  alternate #1 (first true arithmetic op;adds the element
  representation unknown). Constant fill,elementwise add and
  GEMV rejected for now with reasons recorded. Named risk:the
  device vocabulary may lack a copy primitive — a layer-2
  question the description process exists to surface;if shown,
  selection falls to ReLU on this record.
- **Pre-stated prediction for 4.3:** layers 1,2,3,4,7,8
  completable at source level (layer 2 with the vocabulary
  caveat);layers 5-6 INCOMPLETE on CCW content + action
  sequencing;Campaign 4 does not exit this pass;iteration item
  = CCW layout research (Track R lane D / Campaign 5 gate).
- **Evidence boundary:** No operation is described yet (that is
  4.3),nothing is emitted,and no device behavior is claimed.
- **Next acceptance gate:** Slice 4.3 eight-layer description
  tested against this prediction;then 4.4 review gate.
- **Audit:** Specification only. No global/hosted-CI pass.

### AES-NUM-003 — Identity copy eight-layer description (Campaign 4)

- **Status:** `verified` (specification scope:eight-layer
  description graded against AES-NUM-001,with the prediction
  contradiction recorded as the slice's finding).
- **Owner:** docs/HAILO10H_IDENTITY_COPY_EIGHT_LAYER_SPEC_2026-10-24.md.
- **Claim sources:** AES-NUM-001 field table;AES-NUM-002
  selection + prediction;AES-PROG-001..004;AES-TRANSFER-001..004;
  roadmap §2.2 Do Not Infer law.
- **Fixed shape:** 16 elements × 1 opaque byte,1-D,contiguous,
  distinct in/out buffers;parameters NONE (proved from the
  definition — its only argument is the input sequence).
- **Layer grades (roadmap 4.3 list):** L1 numerical definition
  COMPLETE (signedness/scaling/accumulator/rounding/saturation
  proved not applicable — bytes in = bytes out). L2 tile plan
  INCOMPLETE at device level (one logical tile specified
  Aesir-side;tile geometry expression + allowed dimensions are
  group-E/CCW OUT). L3 physical resource plan INCOMPLETE
  (assignment values,banks/windows,L2/L3 offsets OUT;only a
  requirement can be stated,no values). L4 data-movement plan
  SPECIFIED host-side,NOT ESTABLISHED device-side (payload =
  one async session read of declared size after readiness wait;
  SoC session readiness protocol NOT ESTABLISHED;the -004 CREATE
  control exchange explicitly NOT credited as stream proof).
  L5 static configuration INCOMPLETE (CCW words OUT). L6 dynamic
  actions INCOMPLETE (layouts IN;real-program sequencing and
  safe ID35 address values unestablished). L7 completion
  contract SPECIFIED with fully sourced terms (IRQ data 1 =
  completed;0xFF NOT_ACTIVE never credited;byte-equal readback
  required) — satisfiability is Campaign 5's physical question.
  L8 cleanup contract SPECIFIED host-side (AES-PROG-002/004
  ordering,failure tiers,residue honesty),NOT ESTABLISHED for
  device partial states (AES-PROG-001 ordering unknown stands).
- **Finding — prediction contradiction:** AES-NUM-002's
  prediction was scored against a DIFFERENT layer list than the
  roadmap's 4.3 list. Under the governing roadmap list,L2/L3 do
  not clear;the prediction's substance survives where contents
  agree (shape/parameters in the fixed-shape section;oracle in
  L1/L7),and L5/L6 agree as predicted. The corrected mapping is
  recorded in the doc;4.4 inherits it.
- **Evidence boundary:** The operation remains UNQUALIFIED;
  Campaign 4 does NOT exit;no Campaign 5 encoder may be
  contracted from this spec. Iteration items R1 CCW layout
  (lane D),R2 session readiness,R3 placement values,R4 action
  sequencing,R5 partial-state teardown preconditions.
- **Next acceptance gate:** Slice 4.4 spec review gate against
  the Do Not Infer table.
- **Audit:** Specification only. No global/hosted-CI pass.

### AES-NUM-004 — Identity copy spec review gate (Campaign 4)

- **Status:** `verified` (review scope:field-by-field audit of
  AES-NUM-003 against AES-NUM-001 and the roadmap §2.2 Do Not
  Infer table;no emitter,no bytes,no physical run).
- **Owner:** docs/HAILO10H_IDENTITY_COPY_SPEC_REVIEW_2026-10-24.md.
- **Claim sources:** AES-NUM-003 spec (document under review);
  AES-NUM-001 field table (grades A–E);roadmap §2.2 (16 Do Not
  Infer entries);AES-NUM-002 (prediction under correction).
- **Audit result:** Every field/value the spec uses carries a
  source and a known meaning or is explicitly graded
  UNKNOWN/OUT — fixed shape (Aesir-side choices,declared as
  such),L1 proofs of non-applicability,L2/L3 group-E OUT
  grades,L4 IN facts with readiness NOT ESTABLISHED,L5
  carriers/layouts with CCW words OUT,L6 layouts with sequence
  and ID35 address values OUT,L7 sourced completion terms,L8
  host terms with partial-state ordering NOT ESTABLISHED. No
  tile size,resource value,bank/offset,CCW word,sequence,
  address,format semantic or readiness mechanism is asserted
  anywhere in the spec.
- **Do Not Infer:** 0 of 16 entries violated;entries 3 (IRQ),
  4 (closed file) and 10 (math ≠ executable) are actively
  enforced by the spec's own layer 7/8 terms and its
  UNQUALIFIED grade;the rest are complied with or not engaged
  (recorded per entry in the doc).
- **Finding F1 (tightening):** AES-NUM-003 layer 7's phrase
  "the qualified result path" overreaches — no PROGRAM RESULT
  readback path is qualified (AES-TRANSFER-004 proved a CREATE
  control exchange,not program results). The byte-equal
  readback term stands;its path qualification is NOT
  ESTABLISHED and joins the R2/R4 dependency set. Correction of
  record lives in the review doc;the spec is not retro-edited.
- **Finding F2 (clarification):** the fixed-shape rationale's
  2048-byte citation governs RPC messages,not the session-read
  payload;the spec's own context-only disclaimer is
  load-bearing and is confirmed by this gate.
- **Mapping certified:** AES-NUM-003's corrected AES-NUM-002 →
  roadmap layer mapping and scoreboard are certified as the
  Campaign 4 record (definition/shapes/parameters → fixed
  shape + L1;result mapping/oracle → L1 + L7;"layers 1–4
  completable" does NOT transfer to roadmap L2/L3/L4).
- **Gate verdict:** Spec PASSES review as an honest
  specification. Campaign 4 EXIT NOT MET — OUT-graded fields
  have a sourced unknown status,not a known meaning,so the
  exit condition's own terms are unmet. Operation remains
  UNQUALIFIED;Campaign 5 is NOT contracted.
- **Next acceptance gate:** Campaign 4 iteration through
  Track R R1–R5 (each closes only on IN-grade evidence or is
  recorded NOT PROVEN);slice 4.5 = R1 CCW layout study (lane
  D),research only. Affected layers re-graded by addendum and
  this gate re-runs on changed layers only.
- **Audit:** Review only. No global/hosted-CI pass.

### AES-NUM-005 — CCW word layout study, Track R R1 (Campaign 4)

- **Status:** `verified` (research scope:bounded search of the
  pinned public sources, lane D and repo evidence for a CCW
  word layout;no emitter,no bytes,no physical run).
- **Owner:** docs/HAILO10H_CCW_LAYOUT_STUDY_2026-10-24.md.
- **Verdict: R1 NOT PROVEN.** No searched source defines the
  bit layout of a non-zero CCW word (opcode/address/data/
  command field positions all undefined). Pinned
  config_buffer.{hpp,cpp} @d503417 treat CCW data as opaque
  bytes to copy/align/pad/DMA; lane D
  (l-nmch/hailo-10h-llm-compiler @c870419,MIT) delegates all
  CCW generation to DFC 5.3.0 and none of its 17 findings
  addresses CCW words; repo evidence is uniformly carrier-only.
- **Ancillary IN additions (group C, around the OUT row):**
  CCW consumed as a 64-bit word, all-zero word = NOP (CSM pops
  it without forwarding address/data/command, excluded from
  CRC, returns credits — config_buffer.cpp pad_with_nops
  comment @pin); header constants CCW_BYTES_IN_WORD=4 and
  CCW_DATA_OFFSET=8 recorded literally, their use NOT traced
  and their meaning NOT ESTABLISHED.
- **Effect:** AES-NUM-001 CCW-words row stays OUT;
  AES-NUM-003 layers 2/5 NOT re-graded (no change), 4.4 gate
  not re-run. Campaign 4 EXIT NOT MET; operation
  UNQUALIFIED; Campaign 5 NOT contracted.
- **Next acceptance gate:** R2 session readiness (+F1
  program-result readback question), slice 4.6.
- **Audit:** Research only. No global/hosted-CI pass.

### AES-NUM-006 — SoC session readiness study, Track R R2 + F1 (Campaign 4)

- **Status:** `verified` (research scope:bounded study of the
  pinned public sources for the SoC RPC session readiness
  protocol and the F1 program-result readback question;no
  payload contract,no bytes,no physical run).
- **Owner:** docs/HAILO10H_SOC_SESSION_READINESS_STUDY_2026-10-24.md.
- **Verdict: R2 ESTABLISHED at source level** (one sub-part
  NOT PROVEN). Interface @pin (hailo_session.hpp):wait_for_
  read/write_async_ready(transfer_size,timeout) — "each
  session has a limited-size queue for ongoing transfers";
  RpcConnection::read_buffers waits with the TOTAL size,then
  posts ONE read_async of all buffers,callback+condvar,
  TRANSFER_TIMEOUT default 10,000 ms. Mechanism:there is NO
  wire-level readiness signal in any pinned session
  implementation. Dispatch @pin (hailo_session.cpp):ETH and
  INTEGRATED → OsSession (socket,port 12133);PCIe →
  RawPcieSession;USB → UsbSession;no separate SoC session
  exists in the public tree. OsSession readiness IGNORES
  transfer_size and is AsyncActionsThread::wait_for_enqueue_
  ready — local queue below max capacity;the transfer is one
  exact-size socket recvall/sendall. RawPcieSession is the
  contrast (size-sensitive is_read_ready) — readiness is a
  per-transport LOCAL admission rule,not a protocol;cross-
  transport inference forbidden. Size reaches the receiver
  only via the preceding RPC message (payload case:action-2
  hef_size,AES-PROG-004);host sends message+write buffers as
  ONE write transfer (client.cpp),no chunking at this layer.
- **NOT PROVEN sub-part:** any maximum size for one async
  transfer / firmware acceptance rule below the public
  session layer (2048 caps RPC messages only — F2 reconfirmed).
- **F1 answered:** a program-result readback path IS described
  @pin — Client::execute_request registers read_buffers per
  message id;on a HAILO_SUCCESS reply the reply thread reads
  them via RpcConnection::read_buffers BEFORE the callback;
  ConfiguredInferModelHrpcClient builds read_buffers from
  OUTPUT bindings. Path remains UNQUALIFIED in Aesir (no host
  qualification,no physical exercise);F1's caution stands as
  a qualification statement.
- **Effect:** AES-NUM-003 re-graded by addendum (appended to
  the spec + study §5):layer 4 → SPECIFIED (host) / readiness
  ESTABLISHED (device,source level),steps 2/4 still
  unsourced, nothing physically proven;layer 7 F1 term
  corrected to "source-described,Aesir-unqualified result
  path". 4.4 gate re-run on layers 4+7 only:PASS (0 Do Not
  Infer violations). Campaign 4 EXIT NOT MET (R1 NOT PROVEN;
  R3/R4/R5 open);operation UNQUALIFIED;Campaign 5 NOT
  contracted.
- **Next acceptance gate:** R3 placement counts and safe
  assignment values,slice 4.7.
- **Audit:** Research only. No global/hosted-CI pass.

### AES-NUM-007 — Placement counts and safe assignment values, Track R R3 (Campaign 4)

- **Status:** `verified` (research scope:bounded study of the
  pinned public sources,repo evidence and open web for the
  Hailo-10H's physical placement counts and any publicly
  established safe assignment values;no emitter,no bytes,no
  physical run).
- **Owner:** docs/HAILO10H_PLACEMENT_VALUES_STUDY_2026-10-24.md.
- **Verdict: R3 NOT PROVEN on both parts.** R3a counts:no
  searched source states the Hailo-10H's cluster,subcluster,
  APU/compute-unit,input-aligner or local-memory bank counts.
  R3b safe values:no searched source establishes any cluster
  index,packed LCU id,`active_*` bitmap pattern or L2/L3
  offset as safe/legal for a real program on this target.
  The pinned placement-owning header
  (common/include/context_switch_defs.h @d503417,read in
  full this slice) contains NO count define of any kind —
  full-text CLUSTER/MAX searches return only the packed-id
  shift/mask macros and one unrelated write-size constant.
  Hailo's own product brief/page publish TOPS,memory,
  interface and power only — no compute geometry.
- **Width facts confirmed @pin (group B confirmations,NOT
  counts):** packed LCU id = LCU index width 4 (mask 0x0f) +
  cluster index width 3 (mask 0x70,shift 4),bit 7 in neither
  mask — 128 encodable combinations,a property of the byte,
  not the silicon (the host-qualified LCU codec exercising
  all 128 qualifies the ENCODING,per the 2026-10-22 evidence
  warning,not a census). Trigger-sequencer carries a SEPARATE
  full-u8 cluster_index — the width inconsistency itself
  forbids reading either as a census. sequencer_config_t
  widths:initial_l3_cut u8,initial_l3_offset u16,active_apu
  u32,active_ia u32,active_sc u64,active_l2 u64,l2_offset_0/1
  u64 — bitmap capacities only;bit meanings unestablished;
  abbreviations recorded as field names,not expanded.
- **Ancillary literal:** ENABLE_LCU_DEFAULT_KERNEL_ADDRESS
  (1) / ENABLE_LCU_DEFAULT_KERNEL_COUNT (2) @pin — the
  default LCU-enable record's kernel-done defaults;a
  completion-reporting fact (belongs to R4),not a placement
  value.
- **Near-miss recorded:** DFC v3.29 guide's place(cluster_
  number,layers) allocator hint (example place(2,...)) grades
  NOTHING here — DFC 3.x/Hailo-8-era source,cross-target
  inference forbidden;states no count,range or safety;DFC is
  not Aesir's backend.
- **Effect:** AES-NUM-001 group E placement rows stay OUT;
  AES-NUM-003 layer 3 NOT re-graded (R3 did not land),4.4
  gate not re-run (no changed layers). Campaign 4 EXIT NOT
  MET;operation UNQUALIFIED;Campaign 5 NOT contracted.
- **Next acceptance gate:** R4 action sequencing (+F1
  result-path qualification question),slice 4.8.
- **Audit:** Research only. No global/hosted-CI pass.

### AES-NUM-008 — Action sequencing for a real program, Track R R4 (Campaign 4)

- **Status:** `verified` (research scope:bounded study of the
  pinned configure-path sources for a sourced minimal-program
  context-action sequence;no emitter,no bytes,no physical run).
- **Owner:** docs/HAILO10H_ACTION_SEQUENCING_STUDY_2026-10-24.md.
- **Verdict: R4 PARTIALLY ESTABLISHED.** The ordering
  discipline is ESTABLISHED at source level:the pinned
  configure path (resource_manager_builder.cpp @d503417,
  sha256 035af3cc…;builder/resource-manager/header hashes
  cross-checked against this repo's recorded study hashes)
  transforms each context's action list deterministically —
  fetch insertion per WriteDataCcw (its own total_ccw_burst;
  code inserts per write action despite the "group" comment),
  edge-layer activation inserted before the single
  TriggerNewData group (outputs → DDR inputs → inputs;
  mapping/DDR/resume;StartBurstCreditsTask after),config-
  channel activate prepended / deactivate appended per config
  buffer,repeated-action compression,end-of-context terms
  last (disable replaced by deactivates;single-context →
  WaitForNetworkGroupChange). Context BUILD order sourced:
  activation → batch-switching → preliminary → dynamics in
  HEF index order,then configure(). Device EXECUTION order
  NOT PROVEN (build order is not execution order).
- **Counts/addresses:** established as FUNCTIONS of the base
  list + resources (fetch bursts,descriptor counts,config-
  buffer counts,batch-switch kernel-done derivation),plus
  the default literal:default LCU-enable completion =
  kernel-done address 1 / count 2 @pin (the 4.7 ancillary
  lands). Non-default records carry address u16 + count u32
  in the action;no safe non-default address value is
  established — NOT PROVEN,ID35 addresses stay OUT.
- **Minimal authorable sequence: NOT PROVEN.** The base list
  is ContextMetadata::get_actions() — parsed from the HEF
  (hef/core_op_metadata.cpp @pin),i.e. DFC-authored;its
  contents depend on R1 (CCW,NOT PROVEN) and R3 (placement,
  NOT PROVEN). The builder orders insertions,it does not
  validate or generate base contents.
- **F1:** unchanged — the result path stays source-described
  and Aesir-unqualified;research cannot qualify it;layer 7
  not re-graded.
- **Effect:** AES-NUM-003 layer 6 re-graded by addendum
  (appended to the spec + study §8):discipline ESTABLISHED,
  base list NOT PROVEN,layer stays INCOMPLETE. 4.4 gate
  re-run on layer 6 only:PASS (0 Do Not Infer violations;
  hRPC ids ≠ context actions;HEF parsing ≠ DFC knowledge).
  Campaign 4 EXIT NOT MET;operation UNQUALIFIED;Campaign 5
  NOT contracted.
- **Next acceptance gate:** R5 partial-state teardown
  preconditions,slice 4.9 — the last Track R item.
- **Audit:** Research only. No global/hosted-CI pass.

### AES-NUM-009 — Partial-state teardown preconditions, Track R R5 (Campaign 4)

- **Status:** `verified` (research scope:bounded study of the
  pinned receiver sources for teardown ordering/preconditions
  in partial states;no code,no emitter,no bytes,no physical run).
- **Owner:** docs/HAILO10H_PARTIAL_STATE_TEARDOWN_STUDY_2026-10-24.md.
- **Verdict: R5 PARTIALLY ESTABLISHED.** Handler-level
  preconditions ESTABLISHED at source level (hailort_server.cpp
  @d503417 sha256 80b8c3c6…; hrpc/server.cpp 278f5457…;
  server_resource_manager.hpp a9445bfa…; infer_model.cpp
  393be20f…):the destroy actions carry NO preconditions —
  destroy-infer releases only its own tier with no check for
  live configured children (the configured tier is registered
  independently and holds a shared ConfiguredNetworkGroup,
  not the InferModel), destroy-configured executes shutdown()
  internally with its result void-cast and succeeds on objects
  in any manager-held state, and all three destroy handlers
  reply HAILO_SUCCESS even for missing/already-released
  handles (release_resource logs INFO and returns null).
  Non-destroy use of a destroyed handle is strict instead:
  execute() lookup fails HAILO_NOT_FOUND and handlers
  CHECK_SUCCESS it. One client's actions execute serially on
  its single action thread.
- **Partial-configure residue — ESTABLISHED:** the
  create-configured handler registers the InferModelInfo and
  the configured object BEFORE the buffer-pool / run-async
  pool steps and the reply; a later TRY failure leaves both
  registered with handles never sent — the handle-never-learned
  residue class, now sourced for configure as well as create.
  A configure() failure itself registers nothing.
- **Disconnect cleanup — trigger and order ESTABLISHED,
  profile applicability NOT PROVEN:** Server::serve_client
  @pin exits its loop on ANY handle_client_request failure
  (HAILO_COMMUNICATION_CLOSED disconnect included), then
  shutdown_action_thread → cleanup_client_resources → close.
  Cleanup order:configured models (+pools),infer-model infos,
  infer models (+info-id map),vdevice (+remove_vdevice).
  Configured-object release becomes a stop via the destructor's
  shutdown() at source level (other outstanding references
  would defer it — NOT PROVEN). Whether Aesir's grouped-control
  session termination triggers this server's cleanup on the
  installed profile remains NOT PROVEN (AES-PROG-004's gap,
  unchanged); the recorded residues stand.
- **NOT PROVEN:** firmware/device consequences of out-of-order
  teardown (e.g. activated network group behaviour when its
  vdevice tier is released first).
- **Effect:** AES-NUM-003 layer 8 re-graded by addendum
  (handler preconditions in,device consequences + profile
  trigger out — stays SPECIFIED host / NOT ESTABLISHED
  device,partial states);4.4 gate re-run on layer 8 only:PASS
  (destroy success replies are not read as proof of prior
  state or device destruction). Track R study pass COMPLETE:
  R1 NOT PROVEN,R2 ESTABLISHED,R3 NOT PROVEN,R4 PARTIAL,
  R5 PARTIAL. Campaign 4 EXIT NOT MET;operation UNQUALIFIED;
  Campaign 5 NOT contracted.
- **Next acceptance gate:** Campaign 4 exit — turns on
  R1/R3-class public evidence (a public CCW layout and a
  placement census) that no searched source contains;no
  further Track R study slice is named for this iteration.
- **Audit:** Research only. No global/hosted-CI pass.

### AES-NUM-010 — HEF corpus inventory + first static map (empirical program start)

- **Status:** `verified` (inventory + wire-level map scope).
- **Owner:** docs/HAILO10H_HEF_CORPUS_INVENTORY_2026-10-24.md.
- **Context:** Opened under Volmarr's 2026-10-24 never-stop
  order;the document-study negatives (AES-NUM-005/007) stand as
  grades,but the campaign now works empirical evidence.
- **Evidence:** Targeted inventory found ONE HEF in reach —
  minilm-l6-ruvector.hef (11,759,616 B,sha256 3c535080...,an
  all-MiniLM-L6-v2 network for Hailo-10H) in the Pi's twister
  workshop tree,with source+recipe beside it;the tree also
  holds unmined HailoRT forks (incl. the hef schema),a model
  zoo checkout and compiler notes. No other HEF in the repo
  trees/Pi home/caches searched;hailo-ollama's model store not
  yet located (named next target).
- **First map (schema-free wire walk,artifact unmoved):** file
  header 56 bytes;protobuf from byte 56;arch value 103
  (HAILO1XH) observed in a real artifact;6,183 regions;largest
  (/2,56,193 B) is high-entropy weights-class data (0 zero
  words);repeated ~7-8 KB per-layer payloads;NO large NOP/CCW
  blob — CCW configuration must sit in small structured core
  fields,needing the schema field map to isolate.
- **Evidence boundary:** No CCW meaning is established by this
  slice. Next:4.11 schema-guided CCW isolation from the fork's
  hef.proto;4.12 differential design;4.13 fork census hunt.
- **Audit:** Research only;no bytes sent to the device.

### AES-NUM-011 — schema-guided CCW isolation in a real HEF

- **Status:** `verified` (isolation scope,one artifact).
- **Owner:** docs/HAILO10H_CCW_ISOLATION_MINILM_2026-10-24.md.
- **Evidence:** hef.proto fetched at the HailoRT pin (GitHub
  API;the twister forks are driver trees and hold no proto).
  Containment path ProtoHEFHef.2 -> NetworkGroup.3 contexts
  -> Operation.2 -> Action oneof (ccw inline = 3,ccw ptr =
  16). Schema-guided walk of the MiniLM HEF:6 contexts,1,605
  actions,ALL configuration writes are pointer-form (inline
  CCW zero);other kinds counted (sequencer/input/dataflow).
  Pointer triples reference 9,832,200 B across offsets
  1,862,144..11,698,480 (file-resident bulk,not the 56 KB
  protobuf);channels 0/1/2 = 753/452/400 actions;modal small
  size 24 B = 3 words (343 actions) with sequential twin
  streams (ch.1/ch.2 bases,offsets += 24) — the burst unit.
- **Evidence boundary:** no CCW word meaning claimed;offset
  base (file vs protobuf) NOT yet discriminated (both samples
  weights-class);weights-class data rides the same action
  kind. Next:4.12 differential + base discrimination,4.13
  census hunt in the driver trees.
- **Audit:** Host-side analysis only;no device bytes.

### AES-NUM-012 — CCW pointer offset base RESOLVED + differential design

- **Status:** `verified` (base resolution + design scope).
- **Owner:** docs/HAILO10H_OFFSET_BASE_AND_DIFFERENTIAL_DESIGN_2026-10-24.md.
- **Evidence:** Pinned hef.cpp @d503417f defines the v3 zero
  point: HEF_HEADER_SIZE_V3 + hef_proto_size + hef_padding —
  pointer offsets are relative to the CCWS section start
  (file layout header|protobuf|padding|CCWS). Numerically
  consistent with the MiniLM artifact (zero ~56.8 KB + max
  referenced end 11,698,480 <= 11,759,616,trailing ~4.3 KB
  additional-info). The reader coalesces consecutive pointer
  actions into config-buffer writes (hef.cpp ~2873).
- **Design:** pair of same-family HEFs differing by one
  declared parameter (routes: model-zoo pair > recipe rebuild
  > hailo-ollama store); align action lists,diff triples,
  extract changed words under the resolved base; fallback =
  intra-artifact layer-block differential the corpus already
  contains. Vendor compiler used only to manufacture evidence
  artifacts;the product path stays DFC-free (owner scope).
- **Evidence boundary:** exact zero-point integer awaits a
  mechanical v3 header decode;word meaning untouched until
  the differential runs.
- **Audit:** Source read + host analysis only.

### AES-NUM-013 — zero point confirmed empirically;burst lane structure

- **Status:** `verified` (zero point + observed statistics).
- **Owner:** docs/HAILO10H_ZERO_POINT_AND_BURST_STRUCTURE_2026-10-24.md.
- **Evidence:** Header decode (BE u32s):proto 56,844;ccws
  11,700,652;padding 444 -> zero 57,344. Lane-distinct test
  over 153 channel-1/2 24 B bursts:at 57,344 lanes show
  18/82/83 distinct values with lane0 top count 132/153;at
  base 0 fully random;at 56,900 (off by the padding) blurred.
  Three-way agreement (source formula,header,emergence).
  File arithmetic closes (residue 1,620 B additional-info).
- **Structure:** 6 contexts x 251-279 ptr actions;small-24
  counts 57/57/56/58/56/59 per context (aligned repetitions).
  Lane0 near-constant header word 0x...2805 x132;second
  family 03080000f8bf...;lanes1-2 packed small-number
  operands (first burst recorded). No lane named yet.
- **Evidence boundary:** statistics observed,semantics not
  claimed. Next:4.14 census hunt (driver trees);4.15 pair
  acquisition + cross-artifact differential;per-context lane
  comparison.
- **Audit:** Host-side analysis only.

### AES-NUM-014 — census hunt negative + empirical addressing floor

- **Status:** `verified` (bounded negative + measured floor).
- **Owner:** docs/HAILO10H_CENSUS_HUNT_AND_ADDRESSING_FLOOR_2026-10-24.md.
- **Evidence:** (1) The twister driver trees (hailort-drivers
  transport:PCIe/VDMA/fw-ops) contain NO cluster/APU/core
  census constants — principled negative (census lives in
  firmware/compiler,not the host transport driver);corpus
  class exhausted. (2) The MiniLM HEF's 286 LCU triggers
  (schema ProtoHEFTrigger.2 = {cluster,lcu}) address cluster
  indices 1-4 (+elided 0) and LCU indices 1-15 (+elided 0),
  near-uniform — an EMPIRICAL LOWER BOUND of >=5 clusters x
  >=16 LCUs addressed by one small network.
- **Evidence boundary:** the floor is a network's usage,not
  the silicon census;assignment safety still unproven;proto3
  zero-elision makes pair counts partial (240/286) while
  ranges are exact. AES-NUM-007's NOT PROVEN stands for the
  census itself,with this floor now beneath it.
- **Audit:** Host-side analysis only.

### AES-NUM-015 — pair acquired (ollama store) + cross-artifact differential

- **Status:** `verified` (measured, three artifacts).
- **Owner:** docs/HAILO10H_PAIR_ACQUISITION_AND_CROSS_ARTIFACT_DIFFERENTIAL_2026-10-24.md.
- **Evidence:** (1) The hailo-ollama store AES-NUM-010/012
  could not locate is FOUND: ~/.local/share/hailo-ollama/
  models/blob/ on Mimir — six blobs,12 GB,all HEF-magic;
  corpus 1 -> 7 artifacts,no download. Per-blob model
  identity NOT claimed (manifests empty;size/sha only).
  (2) Per-context lane comparison (MiniLM,order-aligned,
  24 positions): lane0 identical across all 6 contexts at
  17/24 positions (pairwise 0.811);lane1 varies at 24/24;
  channel agrees at only 6/24. (3) Cross-artifact (mmap
  walker,control on MiniLM reproduces -011/013/014
  exactly): two GenAI HEFs (219 and 180 contexts) — lane0
  dominant word is the SAME 0528000000000000 (4,820/5,564
  and 3,960/4,040);lane2 bytes3-7 all-zero in both.
- **Grades:** lane2 = a <=3-byte field in a 64-bit lane,
  EMPIRICAL cross-artifact (9,757 bursts,3 networks);
  lane0 dominant word = fixed burst-header constant,
  EMPIRICAL-CANDIDATE (meaning unclaimed);zero-point
  formula corroborated on 3 artifacts;LCU floor >=5 x
  >=16 NOT raised by 399 further contexts.
- **Evidence boundary:** 3 of 7 corpus artifacts walked;
  no same-family one-parameter pair yet,so parameter-
  tracking remains open (recipe/zoo pair's job).
- **Audit:** Host-side analysis only.

### AES-NUM-015 — per-context lane differential: the layer skeleton

- **Status:** `verified` (exact value-set statistics).
- **Owner:** docs/HAILO10H_PER_CONTEXT_LANE_DIFFERENTIAL_2026-10-24.md.
- **Evidence:** 153 channel-1/2 24 B bursts across the 6
  contexts (25/24/25/24/26/29). Lane0:exactly ONE value
  common to all six contexts (the champion 05280000...) of
  18 in union,and it appears EXACTLY 22 times per context —
  a structural constant. Lane0 sequences match position-wise
  21-22/24 across contexts 1-4 (ctx5 18 — end-of-network
  extras). Lanes1-2:only 2 values each common to all six
  (of 82/83) — operand lanes are layer-specific.
- **Reading (behavioural):** fixed skeleton (22 champion
  bursts/layer) + layer-specific operands;champion bursts
  are the prime pure-configuration candidates.
- **Pair route:** the twister zoo checkout's HAILO10H
  public-model docs confirmed present;pair download is the
  next acquisition step.
- **Evidence boundary:** no field named;byte-entropy anatomy
  of the 132 champion bursts queued (needs no new artifact).
- **Audit:** Host-side analysis only.

### AES-NUM-015 RECONCILIATION — twin slice,merged

- Two crews ran slice4.15 concurrently and both halves are
  canonical: (a) pair acquisition + cross-artifact
  differential (worker: hailo-ollama store found,corpus
  1 -> 7 artifacts;lane0 header word universal across three
  network families;lane2 a <=3-byte field over 9,757
  bursts); (b) per-context lane differential (main thread:
  champion exactly 22x per context;skeleton constant).
  Both docs stand;the two AES-NUM-015 ledger entries are the
  two halves,not a duplication error. Commit baabfc1d
  carries both (the main thread's add -A swept the worker's
  files in;no work was overwritten). Canonical queue per
  the merged TODO: 4.16 walk the remaining four ollama
  blobs;4.17 lane-1 structure hunt (incl. the champion
  byte-entropy anatomy). Coordination lesson re-learned:
  slice claims go in the state file AND the firing cadence
  is 10 minutes — expect company; write so merges stay
  additive.

### AES-NUM-016 — full-corpus walk: universality at 7 artifacts

- **Status:** `verified` (corpus-scale statistics).
- **Owner:** docs/HAILO10H_FULL_CORPUS_WALK_2026-10-24.md.
- **Evidence:** The four remaining ollama blobs walked
  (mmap;header zero per blob re-confirmed by structure):
  contexts 219/256/353/271;ptr actions ~124-138k each;
  bursts 5,546/5,836/8,089/6,287. Lane0 champion
  0528000000000000 dominant in EVERY artifact at 86-97%
  (24,185/25,758 this slice). Lane2 bytes3-7 zero in
  25,758/25,758 bursts (zero exceptions corpus-wide with
  AES-NUM-015's 9,757). Census maxima 4/15 in all four.
- **Grades:** lane0-champion universality + lane2 <=3-byte
  law = EMPIRICAL LAWS over the 7-artifact corpus. Census
  stays a FLOOR (>=5 clusters x >=16 LCUs),with 5x16 now
  the leading candidate hypothesis (no artifact of seven
  exceeds 4/15 across ~48k trigger pairs).
- **Evidence boundary:** blob identities unclaimed;lane1
  unopened (4.17). No word named.
- **Audit:** Host-side analysis only;blobs unmoved.

### AES-NUM-017 — lane anatomy: the burst decomposed

- **Status:** `verified` (exact byte/u16 statistics,2 artifacts).
- **Owner:** docs/HAILO10H_LANE1_STRUCTURE_HUNT_2026-10-24.md.
- **Evidence:** Champion bursts (MiniLM 132,blob 5ab3537d
  4,819). Lane1 = four u16 fields:pos2 constant 0x0250
  (132/132;4,818/4,819,one 0x02c8 exception);pos1 tiny enum
  {0,0x1000,0x2000,0x2001};pos3 arithmetic ladder stride
  0x200 (the descriptor page) with context-symmetric
  repeats;pos0 flag/select (power-of-two flavoured).
  Lane2 = 24-bit datum + 5 zero bytes;the SAME datum words
  (0xe517,0x898c) lead both artifacts,each repeated exactly
  context-count times (219 blob,6 MiniLM) — per-network
  constants written once per context.
- **Reading:** burst = header word + packed operand word
  (flags/enum/const/address-ladder) + 24-bit datum. No
  field semantically named yet.
- **Next:** ladder origin/range vs known regions;enum/flag
  meanings via one-parameter differential;datum identity
  vs known network constants;non-champion lane0 families.
- **Audit:** Host-side analysis only. (Transport note: one
  base64 re-emission corrupted a byte and was caught by a
  sha256 gate;the clean retry matched exactly.)

### AES-NUM-018 — ladder, datum, non-champion families

- **Status:** `verified` (exact statistics,2 artifacts).
- **Owner:** docs/HAILO10H_LADDER_DATUM_NONCHAMPION_2026-10-24.md.
- **Evidence:** Ladder ANSWERED as a fixed slot set:five
  rungs 0x10f0-0x18f0 (stride 0x200,residue 0xf0) + special
  slot 0x2d80 (exactly 2/context in both artifacts);
  per-context ladder sets identical in all 6 MiniLM
  contexts and the same 6 values intersect all 219 blob
  contexts (one single-context anomaly 0x2a8e recorded).
  Ladder independent of pointer offset (132 distinct
  offsets,6 ladder values). Datum:the top pair 0x60e517 /
  0x56898c is identical at full u24 width across BOTH
  networks,each repeated exactly context-count times;
  38 of MiniLM's 62 u24 values occur in the blob's 417 —
  a shared cross-network pool. Float32-high-zero reading
  excluded (all subnormal ~1e-39);identity NOT PROVEN.
  Non-champion families:lane0 classes 0x28xx / 0x08xx;
  champion lane1 anatomy does NOT carry over (no 0x0250,
  no enum,no ladder — data-class lane1),lane2 width law
  DOES (tail zero in all top families). Enum refined:
  class {0,0x1000,0x2000} x low bit {0,1} (0x1001 new).
- **Next:** 0x2d80 slot context in the skeleton;datum-pool
  structure at full corpus;0x08xx class anatomy.
- **Audit:** Host-side analysis only on Mimir;artifacts
  unmoved. Script hef18.py sha256 3ec7963f... landed via
  sha-gated chunked file.write,verified on-device.

### AES-NUM-019 — special slot, corpus datum pool, 0x08xx class

- **Status:** `verified` (exact statistics,2 artifacts
  for arms 1/3;full 7-artifact corpus for arm 2).
- **Owner:** docs/HAILO10H_SPECIAL_SLOT_DATUM_POOL_08XX_2026-10-24.md.
- **Evidence:** The 0x2d80 slot is a fixed adjacent
  pair at skeleton indices 10-11 of the 22-burst unit
  (MiniLM all 6 contexts;blob units repeat at 32-33
  of 44):exactly 2 distinct bursts,flag 0x8000/0x4000,
  enum 0,const 0x0250,channels split evenly,carrying
  one each the datum constants 0x56898c / 0x60e517
  (438/438 blob specials). Datum pool corpus-wide:
  union 1,189 u24,30 values in all 7 artifacts,the
  top pair repeats exactly proto-context-count times
  in every artifact (6..353),MiniLM and blob 773470cd
  have ZERO private values — a graded shared pool,
  identity NOT PROVEN. 0x08xx class:lane0 carries a
  constant 0xbff8 half-word,never 0x0250,never ladder,
  lane2 width law holds 86/86;MiniLM's are data-like
  (14/byte entropy),the blob's low-entropy structured
  (8 data in 71 bursts,34 contexts).
- **Next:** 4.20 full 22-burst unit anatomy;0x28xx
  non-champion lane-1 pattern;datum identity vs the
  artifacts' tensor data.
- **Audit:** Host-side analysis only on Mimir;
  artifacts unmoved. Script hef19.py sha256 35ee89b0...
  landed via per-chunk sha-gated file.write + a
  gzipped tail (one chunk's base64 was repeatedly
  stripped in transit;the gzip stream landed clean
  and the whole-file sha256 verified on-device).

### AES-NUM-020 — skeleton unit, 0x28xx pattern, datum identity test

- **Status:** `verified` (exact statistics,2 artifacts
  for arms 1/2;MiniLM for arm 3).
- **Owner:** docs/HAILO10H_SKELETON_UNIT_28XX_DATUM_IDENTITY_2026-10-24.md.
- **Evidence:** The 22-burst unit's ladder slot is a
  PALINDROME: paired rungs descend 0x18f0..0x10f0 to
  the 0x2d80 pair at 10-11,then ascend in mirror
  (single ladder value at 19/22 MiniLM positions;
  blob positions 12-21 single-valued in 218-219 of
  219 units,first half less rigid between sister
  units). No position is fully constant:enum tracks
  channel,const 0x0250 everywhere,the datum is the
  per-layer operand;positions 10-11 are the only
  near-constant positions (2-3 distinct bursts vs
  21-35 elsewhere). 0x28xx non-champion lane1:NO
  across-burst alternation (lag1-4 equality all
  ~0.22-0.24 in the blob) — the pattern is INTRA-
  burst:one u16 replicated x4 (MiniLM 6/6 exact;
  blob top 0x7ffe x4 in 264/656,0x4000 x4 in 66).
  Datum identity test NEGATIVE on all arms:tensor-
  range byte-triples at chance rate (pool 33/62 vs
  control 29/62),gap triples at chance (14 vs 14),
  proto-float32 encodings intersect the pool 0
  times in 3,858 candidates (top pair absent).
  Identity NOT PROVEN;two routes closed. Side
  datum:1,862,144 B immediately after the MiniLM
  proto is referenced by no pointer-form action.
- **Next:** 4.21 datum vs proto varint fields;
  blob unit-pair differential;replicated-scalar
  distribution vs counts.
- **Audit:** Host-side analysis only on Mimir;
  artifacts unmoved. Script hef20.py sha256
  86ba61f9... landed via gzip + 4 sha-gated
  1,000 B part files (the direct chunked write
  failed its whole-file sha once and was discarded;
  the gzipped parts each verified,assembly sha
  matched on-device).

### AES-NUM-021 — datum/varint closure, pair co-determination, scalar distribution

- **Status:** `verified` (exact counts,2 artifacts).
- **Owner:** docs/HAILO10H_DATUM_VARINT_PAIRDIFF_REPL28_2026-10-24.md.
- **Evidence:** (1) Datum is NOT a proto varint value:
  MiniLM pool∩varints = 0/62 on both walks;blob top-pair
  values occur 0× in 576,769 varints;strays at chance.
  Third identity route closed. (2) Sister-unit differential
  (95 pairs × 22 positions):lane0 + 0x0250 const always
  equal;DATUM EQUALITY ⟺ (lane0+lane1) EQUALITY with zero
  counterexamples — operand word and datum co-determined;
  positions 10–11 most conserved (0.474);second-half ladder
  sister-invariant. (3) 0x28xx scalars:625/656 exact ×4;
  172 distinct;0x7ffe ×264 dominant;0x8282 exactly once in
  each of 22 contexts;disjoint from datum pool + direct
  varints;MiniLM regime is tiny scalars.
- **Next:** co-determination corpus-wide;what splits the
  conserved 10–11 pairs;datum-as-function-of-header across
  contexts.
- **Audit:** Host-side analysis only. (Transport: gzipped
  900 B parts + per-part md5;deterministic corruption of
  one part healed by halving it;whole-file sha matched.)

### AES-NUM-022 — datum = bijective image of the operand word

- **Status:** `verified` (exact counts,2 artifacts).
- **Owner:** docs/HAILO10H_CODETERMINATION_BIJECTION_SPLITTER_2026-10-24.md.
- **Evidence:** Datum↔lane1 is a BIJECTION with zero
  violations both directions (MiniLM 62↔62;blob 417↔417),
  context-free. Minimal determining set = flags+enum+
  ladder jointly;every proper subset fails (all three
  variable fields individually necessary). Special-pair
  splitter:flags only (enum/ladder 0/50 differ);two flag
  values 0x4000/0x8000 map perfectly to the datum pair
  0x60e517/0x56898c;positions 10/11 complementary.
- **Reading:** the datum behaves as an ENCODING of lane1.
- **Next:** closed-form hunt — GF(2) affine test on the
  417-sample map,then arithmetic/permutation candidates.
- **Audit:** Host-side analysis only.

### AES-NUM-023 — the datum map is GF(2)-linear

- **Status:** `verified` (exact linear algebra,2 artifacts).
- **Owner:** docs/HAILO10H_DATUM_LINEARITY_PROOF_2026-10-24.md.
- **Evidence:** Incremental GF(2) basis test:MiniLM 62
  samples rank 12,blob 417 samples rank 14 — ZERO
  inconsistencies for affine AND pure-linear systems
  (~9,700 bit-constraints satisfied in the blob alone;
  random map passes with probability ~2^-24 per sample).
  Probes concur:ladder +0x200 step ⇒ datum XORs by one of
  only 3 values in both artifacts;arithmetic differences
  all distinct (arithmetic form excluded).
- **Reading:** datum = a fixed 24×64 binary matrix times
  the operand word (on the observed rank-12–14 domain —
  the compiler's own variety).
- **Next:** extract the matrix;cross-validate blob-fit →
  MiniLM prediction;read its structure (CRC-like banding
  vs designed scramble).
- **Audit:** Host-side analysis only.

### AES-NUM-024 — one global linear map, cross-validated

- **Status:** `verified` (exact prediction,2 artifacts).
- **Owner:** docs/HAILO10H_DATUM_MATRIX_XVAL_2026-10-24.md.
- **Evidence:** Fit blob→predict MiniLM 62/62 exact;
  fit MiniLM→predict blob 272/272 in-span exact;zero wrong
  anywhere;combined span rank 14 — SAME variety, SAME map.
  Determined unit columns:10/64 (flags bits 10–15,enum bit
  16,ladder bits 57–59),all dense (popcount 9–14/24) —
  a mixing transform;some adjacent columns shift-related,
  not a clean Toeplitz. Zero input → zero datum.
- **Next:** fit across all 7 artifacts;measure span growth
  / saturation;authorship needs the map on the full
  compiler variety,not only the observed span.
- **Audit:** Host-side analysis only.

### AES-NUM-025 — span saturation across all 7 artifacts

- **Status:** `verified` (exact counts,full corpus).
- **Owner:** docs/HAILO10H_SPAN_SATURATION_2026-10-24.md.
- **Evidence:** Incremental fit over 7 artifacts:1,189
  distinct operand words (= the AES-NUM-019 datum pool
  union — bijection at corpus scale),ZERO inconsistencies,
  rank growth 12→14→15→15→15→16→16 (last 479 words added
  1 dimension). Field varieties closed:flags 65 values
  (k×0x400 counter + rare 0x0001),enum 5,ladder 7. Variety
  dimension ceiling ≈16 = measured rank — saturation
  plausibly complete (hypothesis,stated with arithmetic,
  falsifiable by any dimension-adding artifact).
- **Next:** freeze the fitted basis as an Aesir-side
  encoder artifact + reference encoder,host-tested on all
  1,189 samples;then non-champion lane0 families.
- **Audit:** Host-side analysis only.

### AES-NUM-026 — encoder frozen and proven in Mojo

- **Status:** `verified` (Mojo build + full-corpus run on Mimir).
- **Owner:** docs/HAILO10H_ENCODER_FREEZE_2026-10-24.md.
- **Artifacts:** hailbru/ccw_datum_basis.json (16 rows;
  canonical sha256 7a1635cb…a7e5a,VM-reproduced) and
  hailbru/ccw_datum.mojo (reference encoder;out-of-span
  returns None — refuses,never guesses).
- **Evidence:** module crossed byte-identical;standalone
  run datum(0)=0,special word → 0x56898c;on-device harness
  over all 1,189 corpus pairs:CHECKED 1189 FAILED 0.
- **Toolchain:** Pi Mojo removed `fn` (repo uses `def`);
  no bare InlineArray — unrolled reduction + List harness.
- **Next:** non-champion lane0 families (same treatment);
  wider CCW forms beyond 24 B bursts.
- **Audit:** Host-side build/run only;no device child.

### AES-NUM-027 — lane0 families: the affine law is universal

- **Status:** `verified` (complete populations,2 artifacts).
- **Owner:** docs/HAILO10H_LANE0_FAMILIES_CENSUS_2026-10-24.md.
- **Evidence:** 5,699 bursts in 61 lane0 families.
  AGGREGATE over all 61:operand→datum a function in every
  family (0 violations);GF(2)-affine in every family
  (0 inconsistencies,ranks 1–15);lane2 width law holds in
  5,699/5,699 bursts. Non-champion lane1 anatomy is
  periodic (replicated-scalar construction);two families
  are single fixed bursts ×28.
- **Next:** family census across all 7 artifacts;freeze
  bases for the largest non-champion families;then the
  Campaign-4 stocktake toward the Campaign-5 encoder gate.
- **Audit:** Host-side analysis only.

### AES-NUM-028 — corpus family census, six freezes, stocktake

- **Status:** `verified` (complete populations,7 artifacts;
  Mojo build + harness on Mimir).
- **Owner:** docs/HAILO10H_FAMILY_CENSUS_FREEZE_STOCKTAKE_2026-10-24.md.
- **Evidence:** 174 lane0 families,35,515 bursts pooled
  across all 7 artifacts:AGGREGATE 0 families with a
  function violation,0 with an affine inconsistency,0
  width-law breaks. Champion = 33,097 bursts / 1,189 keys
  (the AES-NUM-025 population reproduced exactly). Six
  largest non-champion families frozen:
  hailbru/ccw_family_bases.json (ranks 13–15;all six
  canonical sha256 reproduced on the VM) +
  hailbru/ccw_family_datum.mojo (affine,out-of-span
  refuses);module crossed byte-identical (sha256
  67df4a9e…);on-device harness over all 177 distinct
  pairs:CHECKED 177 FAILED 0. Frozen datum coverage =
  33,580/35,515 bursts (94.6%).
- **Next:** census of the remaining CCW surface — every
  pointer-action form (size × channel) beyond the 24 B
  channel-1/2 burst (slice 4.29);Campaign-5 may be
  contracted for the datum component only.
- **Audit:** Host-side analysis/build only;no device child.

### AES-NUM-029 — census of the remaining CCW surface

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_REMAINING_CCW_SURFACE_CENSUS_2026-10-24.md.
- **Evidence:** 745,849 pointer actions (field 16) of
  788,726 total,11,096,892,840 referenced bytes;inline
  CCW / write_data / compressed forms ZERO in all 7
  artifacts;channels only 0/1/2;every size a multiple
  of 8;max 32,784. Control counts reproduce AES-NUM-028
  exactly. NEW:the 24 B burst lives on channel 0 too —
  43,486 bursts (42,118 champion-headed,width law
  43,486/43,486),lifting the total 24 B population to
  79,001. Small forms (<=512 B):128,787 actions in a
  structured size ladder,15.8% zero words. Large forms
  are weights-class bulk on the same action kind.
- **Next:** channel-0 burst family census + affine/datum
  tests + frozen-encoder cross-prediction (slice 4.30);
  then small-form word anatomy (4.31).
- **Audit:** Host-side analysis only.

### AES-NUM-030 — channel-0 burst treatment

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_CHANNEL0_BURST_TREATMENT_2026-10-24.md.
- **Evidence:** 104 lane0 families,43,486 channel-0 bursts:
  AGGREGATE 0 families with a function violation,0 with
  an affine inconsistency,0 width-law breaks — the three
  laws are now three-channel over 79,001 bursts. Frozen
  family encoders cross-predict exactly where families
  coincide (2 families,51/51 distinct,108/108 bursts,0
  wrong;1 burst honestly refused out-of-span). Frozen
  champion encoder does NOT extend:channel-0 champion
  operands disjoint from channels 1/2 (0 shared;1,120 vs
  1,189 distinct),1 in-span operand predicted correctly
  (1,504 bursts),never a wrong datum. Channel-0 champion
  map is itself GF(2)-linear,rank 27,0 inconsistencies.
  Pooled frozen coverage 35,192/79,001 (44.5%).
- **Next:** freeze the channel-0 champion basis + largest
  channel-0 families,Mojo-proven on Mimir (slice 4.31);
  then small-form word anatomy (4.32).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-031 — channel-0 freezes: champion + six families

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_CHANNEL0_FREEZES_2026-10-24.md.
- **Evidence:** channel-0 champion map frozen as a
  GF(2)-linear rank-27 basis (1,120 distinct pairs,0
  inconsistencies;canonical sha256 cfd5c488…a7bd,
  reproduced on the VM) + hailbru/ccw_ch0_datum.mojo;
  six largest non-champion channel-0 families frozen
  affine (ranks 9–16,133 distinct pairs;all six
  canonical sha256 reproduced on the VM) +
  hailbru/ccw_ch0_family_datum.mojo. Mojo-proven on
  Mimir: champion harness CHECKED 1120 FAILED 0;
  family harness CHECKED 133 FAILED 0; both modules
  crossed byte-identical; family encoder refuses the
  champion lane-0. Channel-0 frozen coverage
  42,627/43,486 (98.0%); pooled 76,207/79,001 (96.5%).
- **Next:** small-form word anatomy per size class
  (slice 4.32).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-032 — small-form word anatomy

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_SMALL_FORM_WORD_ANATOMY_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029 exactly
  (128,787 small actions;79,001 bursts). 42 size classes
  <=512 B;the 41 non-24 classes hold 49,786 actions /
  1,289,731 words,425,699 all-zero words (33.0%) — while
  the burst's 237,003 words contain ZERO all-zero words.
  Three species:skeleton templates (72/120/416 B = ONE
  segment x1,504;96 B = 2 segs,positions 1-10 always
  zero),framed sparse arrays (176 B p18 always zero,
  zero fraction climbing to 98%;424 B strict marker/data
  alternation from p13),dense data (328 B 0.2% zero,
  uniform-byte classes 400/496/504/512 B). 80 B carries
  a walking-bit ladder (single 08 byte walking across
  positions 1-8,2,219 segs each). 24 B-chunk test:
  champion heads ZERO chunks in every divisible class;
  width law fails broadly except vacuously in skeleton
  classes — small forms are NOT burst strings. Non-24
  segments:13,340 distinct,1,340 shared in >=2
  artifacts. Pair 5ab3537d/773470cd:identical form
  census,83.5% of segments shared byte-for-byte,3,287
  unique each side differing in operand words.
- **Next:** skeleton-class deep-dive (slice 4.33).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-033 — skeleton-class deep-dive

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_SKELETON_CLASS_DEEP_DIVE_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032 exactly
  (128,787 small actions;79,001 bursts). 96 B:exactly 2
  distinct segments (1,504 each),positions 1-10 zero in
  100%,p0/p11 values in perfect bijection (2 pairs),both
  variants in equal numbers in every artifact,exactly
  2 per context (1 of each). 80 B walking bit:ladder
  word at position p is a single 08 byte at stored
  offset 8-p;the ladder is ALL-OR-NOTHING (2,219 segments
  carry all 8 positions,5,686 none,0 partial by the exact
  ladder);the 2,219 are exactly 148 distinct segments
  whose p0/p9 end words are in bijection (148/148/148),
  on all 3 channels,in all 7 artifacts. Single-segment
  classes 72/120/416 B:one segment corpus-wide each,
  byte-identical in all 7 artifacts,exactly 1 per
  context;416 B holds only 3 distinct words (zero x50,
  header p0,trailer p51). Co-variation is total:all
  1,504 contexts hold exactly the quartet {72x1,96x2,
  120x1,416x1} and no other combination.
- **Next:** walking-segment pool sharing across
  artifacts,skeleton quartet intra-context ordering,
  002c fragment vs the wider vocabulary (slice 4.34).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-034 — walking-pool sharing, quartet ordering, 002c vocabulary

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_WALK_POOL_QUARTET_ORDER_002C_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032/033 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions).
  Walking pool:148 distinct split 2/49/27/41/41/40/52 per
  artifact;sharing histogram {1:81,2:37,3:23,4:7},none in
  >=5 artifacts,none universal;sister pair 5ab3537d/773470cd
  shares 36;MiniLM's non-private segment is shared with
  exactly that pair;39 segments occur once,max reuse 109x.
  Quartet ordering:single invariant pattern 72/416/96/96/120
  in all 1,504 contexts,96 variants always in fixed order,
  gap sequence (7,1,11,4) invariant,end-offsets fixed
  (72 at 51,416 at 44,96 at 43/32,120 at 28 from the end;
  exactly 28 actions follow) — an end-anchored trailer.
  002c vocabulary:28,576 occurrences in the small+burst
  surface are exactly 19 distinct words,each appearing
  exactly once in every context (per-context set == global
  set 1,504/1,504),at rigid (size,position) slots (8 burst
  lane-1,4x 176B heads,2x 96B heads,1 each 120/248/256/344/
  416B heads;positions 0/1 only;8 of 42 size classes).
  Large forms:125,918 occurrences in 1.386B words
  (~9.1e-5,~6x chance),no fixed vocabulary measured.
- **Next:** context head-block census,176 B 002c-head
  anatomy,forms of the 28 trailing actions (slice 4.35).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-035 — head census, 176 B anatomy, trailing 28

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_HEAD_176B_TRAIL_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032/033/034 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts). Head:positions 0-3 are 24 B in every context
  (first action 24 B 1,504/1,504);rigidity decays monotonically
  (distinct sizes 2 at pos4 to 111 at pos11;modal flips to 304 B
  at pos9);only 24 distinct first-8 size sequences but 242
  first-12 — no fixed head block;head channels never fixed (all
  3 channels at every position 0-11). 176 B:6,016 segments,
  exactly 4 per context,exactly 4 distinct p0 heads each once
  per context (one multiset corpus-wide,all ending 002c);two
  heads own 1 fixed segment each,the others 99/98 distinct
  (199 total,pools disjoint);p18 always zero,p14-17 near-always
  zero,p21 distinct for all 199 segments. Trailing 28:exactly
  28 actions after the quartet in every context with a SINGLE
  size sequence (24/64/24/216/328x3/24x21) and fixed per-position
  channels — a fixed end block with the quartet.
- **Next:** end-block burst datum treatment,176 B variable-pool
  structure,head burst-run lengths (slice 4.36).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-036 — end-block datum, 176 B pools, head runs

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_END_BLOCK_176B_HEADRUN_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032/033/034/035 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts). Trailing 21 bursts:all 31,584 champion-headed
  (single lane-0,3 channel families),function/affine/width laws
  zero-exception;cross-prediction by the frozen encoders PERFECT
  (31,584/31,584 bursts,2,049/2,049 distinct,0 wrong,0 out-of-span);
  t0 is the invariant special-slot burst (operand 0x2d80025000002000,
  datum 0x2fdeaa);t1-t20 form five 4-position groups with pairwise
  DISJOINT operand pools (98/104/103/100/107) and no intra-context
  operand reuse. 176 B variable pools (99/98 segments):sparse framed
  forms,p18 always zero,p21 unique per segment and the only
  (trivial) full determiner;no pairwise law between varying
  positions;pools mostly single-artifact (73/99,72/98). Head
  burst-runs bounded 4-10 (mean 7.90,median 8),broken by 304 B in
  70.9% of contexts.
- **Next:** trailing operand pools vs the global champion pool,
  176 B joint cluster structure,304 B head-break anatomy (slice 4.37).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-037 — trailing pools vs global, 176 B joint, 304 B break

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_TRAILING_POOL_176B_JOINT_304B_BREAK_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032/033/034/035/036 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts;trailing distinct pairs 2,049). Global champion:
  75,215 bursts,2,309 distinct operands = 2,309 distinct pairs —
  every champion operand lives on exactly ONE channel (ch0 1,120;
  ch1 596;ch2 593). Trailing 2,049 = 1,191 shared with the body +
  858 trailing-only;body-only = 260;shared operands carry 20,937
  of 43,631 body champion bursts. Per group the four position
  pools are equal-sized (98/104/103/100/107) and pairwise
  disjoint;the first three positions share identical
  shared/exclusive splits,the closing channel-0 position and
  t0 are entirely trailing-only (private core = 1 + 512 + 345).
  176 B joint block (p11-13/p19-20):96/91 distinct for 99/98
  segments,neither sub-block determines the other,no pairwise
  law,biggest clusters are the sparse zero cases;even minus
  p21 the block does not determine the segment. 304 B class:
  3,207 occ,21 distinct corpus-wide;breakers are 10 — one
  fixed segment per blob artifact for ALL its contexts
  (256/180/353/271),six singletons for MiniLM,all on
  channel 0;the sister pair NEVER breaks at 304 B. Breaker
  anatomy:constant head 012830020000002e,p1 zero,p2-p28
  exactly two nonzero bytes (positions 0 and 4) with a
  dominant complementary walking pair (k,256-k),k = p-1
  for p2-p17,p29 byte 0 only,p30-35 zero,p36 constant,
  p37 a distinct 3-byte trailer per segment.
- **Next:** sister-pair head-break anatomy,non-breaker 304 B
  population,sister-pool lane-1 subfield comparison (slice 4.38).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-038 — sister breaks, non-breaker 304 B, sister-pool subfields

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_SISTER_BREAK_NONBREAKER_304_SISTER_POOLS_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032/033/034/035/036/037 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts;trailing pairs 2,049). Sister pair NEVER breaks
  at 304 B:its head runs (5-10) end at large data actions —
  215/219 breaks >=9,336 B in each artifact,4 at 528 B,22/21
  distinct sizes (17 common,7 counts exact),216/217 distinct
  segments over 219 breaks,zero segments shared between the
  sisters,channels vary 0/1/2. Non-breaker 304 B = 11 distinct
  segments,ONE occurrence each,all channel 2,only 3 artifacts:
  9 framed forms in 0a0d378c at position 21 (head
  0328300200801c15,23 nonzero words,p36 0100000000000000) and
  2 breaker-like forms at position 12 (head 082830020000002e —
  breaker head with first byte 0x08,p1/p30-35 zero,31 nonzero
  words). Sister pools:ladder CONSTANT per group = the group
  rung (0x10f0..0x18f0),const 0x0250 everywhere,flags sets
  IDENTICAL across the four pools of every group,enum the
  SOLE separator — position j carries exactly {0x1000*j,
  0x1000*j+1} with identical low-bit splits;projection
  (flags,enum-low,const,ladder) sets are EQUAL and injective
  in all four pools of all five groups (sizes 98/104/103/100/107).
- **Next:** enum-relabelling corpus-wide on body pools,
  position-21 framed form comparison,sister large-break
  sizes vs large-action census (slice 4.39).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-039 — body enum relabelling, framed 304 B as 464 B tail, sister census

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_BODY_ENUM_FRAMED464_SISTER_CENSUS_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032/033/034/035/036/037/038 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts;trailing pairs 2,049). Body champion: 43,631
  bursts,1,451 distinct operands. Per ladder rung the body
  pools are EXACT enum relabellings: three classes per rung
  (enum-high 0/1/2), equal pool sizes 89/93/98/89/108 per
  rung, flags sets identical, (flags,enum-low,const,ladder)
  projection sets equal and injective, const 0x0250
  throughout; grouping by (channel,ladder) leaves only one
  multi-class group (the 0x2c00 exception). Exceptions are
  20 operands: 14 invariant singletons occurring exactly
  once per context with one datum each (incl. the 0x2d80
  special-slot pair) plus 6 rare operands (2-4 bursts,
  ladders 0x2a82/0x2a8e). In 0a0d378c the framed 304 B form
  shares only generic marker words with the 176 B (2) and
  424 B (1) frames, but its whole body sits inside the
  464 B form at words 21-57 (19 shared constant words;
  464 B = one 7-segment template, head 0328700300801c15).
  Sister large censuses: 109,789/109,790 actions >512 B,
  179 common sizes with 113 exact count matches; break
  sizes are 22/21 distinct, 13/14 of them census-exhaustive
  (131/135 breaks), and the 178/175 never-break sizes carry
  72.6%/72.5% of large occurrences.
- **Next:** class-channel mapping (three body classes vs
  four trailing), 464 B preamble anatomy, invariant
  singleton positions (slice 4.40).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-040 — class-channel mapping, 464 B preamble, singleton positions

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_CLASS_CHANNEL_464PREAMBLE_SINGLETONS_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032/033/034/035/036/037/038/039 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts;trailing pairs 2,049;champion bursts 75,215).
  Body: enum class = channel index EXACTLY on all five rungs
  (ch0->0,ch1->1,ch2->2;pool sizes 89/93/98/89/108 per cell);
  the only multi-class (channel,ladder) group is 0x2c00 ch0
  {0,8}. Trailing: t0 (0,0);each group of four cycles
  (0,0),(1,1),(2,2),(0,4) — the fourth class 0x4000 shares
  channel 0 (512 distinct operands,exactly the five closing
  positions). Corpus-wide enum-high values are exactly
  {0,1,2,4,8} (bursts 36,111/15,040/15,040/7,520/1,504);
  class 3 NEVER occurs — a single-bit pattern,meaning
  NOT PROVEN. 464 B preamble (0a0d378c): constant 21 words
  (14 distinct,zero at 5,6,8,9,12,13;0072 family enters at
  15,17,19),shares exactly 3 words with framed 304 B (zero
  + two generic markers),framed head NOT in it;tail
  embedding re-verified 35/37 on all 63 pairs. Singletons:
  12 (0x2900/2a00/2c00,all ch0) are end-anchored at fixed
  distinct from-end offsets in one invariant order (two
  inside the trailing 24/64/24 head);the 0x2d80 pair roams
  in the body population (separation -32..+49,both orders).
- **Next:** enum-bit test on non-champion families,0x2d80
  burst-ordinal separation,cc9b9d1c 464 B preamble (slice 4.41).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-041 — non-champion enum test, 0x2d80 pair burst ordinal, cc9b9d1c 464 B

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_NONCHAMPION_ENUM_PAIR464_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032/033/034/035/036/037/038/039/040 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts;trailing pairs 2,049;champion bursts 75,215).
  (i) The champion enum law does NOT transfer: 3,786 non-champion
  bursts (237 lane-0 families,617 operands) take ALL high values
  0-8 at the enum slot (7 dominant 1,839 = 48.6%;champion-set
  values only 47.7%);class==channel in just 237/3,786 (6.3%);
  185 families are single-high but with forbidden constants
  (7 in 34 families/642 bursts,3,5 also occur). (ii) The 0x2d80
  pair is adjacent in champion burst ordinal in 1,428/1,504
  contexts (94.9%;ordinals 15/16;action separation control
  -32..+49 and orders 738/766 reproduced exactly);76 exceptions
  are two fixed patterns — (12,16) +4 x39 and (16,14) -2 x28 —
  concentrated in 76c3a8ff (55) and 0a0d378c (18). (iii) cc9b9d1c
  464 B: one template,four heads differing only in byte 6,
  preamble varies at exactly 5 of 21 words (zero skeleton
  5,6,8,9,12,13 as 0a0d378c),one per-segment parameter byte
  (0xb0/0x64/0x70/0xf8;family parameter 0x72 in 0a0d378c,0x46
  in 0856a10c) at 20 slots;preamble shares exactly the six
  generic constants with 0a0d378c;NO 304 B tail embedding
  (3/37;its 304 B is one breaker-head segment x813).
- **Next:** displaced-pair gap contents,cc9b9d1c parameter
  recurrence outside 464 B,non-champion high-7 lane-1
  structure (slice 4.42).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-042 — displaced-pair gaps, cc9 parameter recurrence, high-7 vs offset

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_DISPLACED_GAP_PARAM_HIGH7_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032/033/034/035/036/037/038/039/040/041 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts;trailing pairs 2,049;champion bursts 75,215).
  (i) Gap bursts are the contexts' own ladder rungs: +4 pattern
  (39 ctx) gap = 0x14f0 ch1 / 0x16f0 ch0 / 0x18f0 ch0 in fixed
  enum = channel forms,flags artifact-fixed only; -2 pattern
  (28 ctx) gap = the 0x18f0 ch2 copy (enum 0x2001,flags 0x8800);
  champion totals unchanged (50;27/28 at 50 in -2);multiset
  symdiff of displaced contexts sits inside the adjacent range
  (76c3a8ff 36-42 vs adjacent mean 54.6) — displacement is a
  reordering in a fixed scaffold,no inserted block. (ii) The
  cc9b9d1c parameter DOES recur outside 464 B: 232/296/312/
  328/360 B distinct segments carry one per-segment parameter
  (all four values) at byte 2 in a DENSER slot pattern
  [1..12,evens] (hits 18-26);80 B's 0x70 is a constant template
  byte;at data scale the values are ordinary payload (93,594
  non-464 occurrences >=3 hits by density;32,784 B position
  sets intersect empty). (iii) High-7 operand is NOT an
  address: no subfield equals any tested offset formula
  (0 hits;oo//24 = 1/1,839 chance),no subfield monotonic in
  offset in any top-10 family,correlations identical -0.2248
  across all subfields because each operand is one indivisible
  unit (distinct counts of every subfield equal per family);
  offset->operand perfection is segment identity,not encoding.
- **Next:** 232-360 B parameter-family template vs 464 B,
  high-7 operand->datum function + affine test,displaced
  contexts outside the pair region (slice 4.43).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-043 — parameter-family template, high-7 function + affine, displaced-context type

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_PARAM_TEMPLATE_HIGH7_FUNCTION_DISPLACED_TYPE_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032/033/034/035/036/037/038/039/040/041/042 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts;trailing pairs 2,049;champion bursts 75,215).
  (i) cc9b9d1c family is one construction across 232-464 B:
  small-form slot pattern exact [1..12,evens to words-5]
  (hits=slots 18/22/23/24/26);head byte 6 <-> parameter
  bijection over all 12 segments (64<->19,70<->1c,b0<->2c,
  f8<->3e),no other head byte a function of the parameter;
  non-param word vocab small 29 vs 464 27,shared exactly
  {zero,0100000000000000};both vocabularies carry the
  0100<param+1>00 word family;360 B pair is one template
  under two parameters,312/328 pairs differ only in data
  fields. (ii) High-7 datum map: per lane-0 family a
  GF(2)-affine function with ZERO violations in all 68
  families (ranks 1-13;width law 1,839/1,839);pooled by
  operand alone it FAILS (189/345 operands multi-datum,
  1,269 viols;pooled affine rank 13 inc 332);pooled by
  (lane0,operand) exact (626 keys,0 viols) — the family
  is part of the key. (iii) Displaced contexts are a
  distinct low-action type: tails equal the modal
  adjacent tail (symdiff 0 in 3 artifacts),heads never
  shared with any adjacent context,actions 85-123 vs
  adjacent minima 232-280,periodic placement (0a0d378c
  81+6k + last;76c3a8ff ~9-step;sisters = last context);
  exceptions: 4 small adjacent contexts,one 336-action
  displaced outlier (18,15).
- **Next:** low-action context class census,parameter+1
  slot census,336-action outlier anatomy (slice 4.44).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-044 — low-action context census, parameter+1 slot census, 336-action outlier anatomy

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_LOW_ACTION_CENSUS_PARAMPLUS1_OUTLIER_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032/033/034/035/036/037/038/039/040/041/042/043 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts;trailing pairs 2,049;champion bursts 75,215).
  (i) Low-action class = 79 contexts at <=150 actions (75
  displaced + 4 adjacent),separated by empty gaps of 115-157
  in every artifact holding it (0a0d378c 18 all displaced at
  73,75,81+6k,179;76c3a8ff 57 in a (2,9) pair train from
  cidx 110,patterns (12,16)x25/(16,14)x26/(12,14)x2/(16,10)x1;
  sisters + 0856a10c single low contexts at stream ends);
  skeleton + trailer complete (79/79),data body nearly
  removed (large-action means 9-40 vs standard 343-504);
  exemplars = standard head + short private middle + the
  identical 56-action end block. 76c3a8ff alone holds a
  ~173-action intermediate class (28 contexts). MiniLM and
  cc9b9d1c hold no low contexts. (ii) The parameter+1
  marker is UNIVERSAL: exactly one strict (X+1) word at
  word (words-3) in 210 of 212 dense-skeleton cc9b9d1c
  segments at 232-464 B (71 distinct X values;2 exceptions
  at 296 B) and in all 20 family segments (cc9 small at
  words 26/34/36/38/42;cc9 + 0a0d 464 B at word 55,
  0100<p+1>009801b... with byte4 0x88->0x98;0856a10c
  carries it at word 55 in the 0200 shape,
  020047009401b080,byte4 0x84->0x94). (iii) The 336-action
  outlier (76c3a8ff cidx 106,pattern (18,15)) is a
  standard full-size context whose pair straddles the
  rare-ladder pair (ordinals 16/17,ladders 0x2a82/0x2a8e,
  const 0x02cc);champion count 31 = 29 + the 2 rare
  bursts;neighbours 105 (reversed-adjacent (20,19),
  champion 33,rare ladders doubled) and 107
  (reversed-adjacent) form a local anomaly zone,not the
  periodic class.
- **Next:** marker-word anatomy across the 210 class,
  the two 296 B exceptions,reversed-adjacent pair census
  + cidx 105 anomaly,76c3a8ff ~173 class anatomy
  (slice 4.45).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-045 — marker function, pair-order census, anomaly zones, intermediate class

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_MARKER_FUNCTION_PAIR_ORDER_ANOMALY_ZONES_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032/033/034/035/036/037/038/039/040/041/042/043/044 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts;trailing pairs 2,049;champion bursts 75,215;
  427 cc9 distinct segments at 232-464 B). (i) The marker
  word is a closed-form function of the preceding strict
  word: copy with byte2 +1 and byte4 stepped -4 (small
  forms,208 segments) or +16 (464 B form,4 segments;
  0a0d378c +16,0856a10c +16 in the 0200 shape);tails copied
  verbatim;75 distinct (predecessor,marker) pairs in the
  210 class,injective both ways. Under modal X (incl.
  zero) the marker law is 212/212 — the AES-NUM-044
  exceptions were a nonzero-dominant-X artifact (both
  modal-0,marker 010001004c01f080);72 X values,only the
  parameter family's four (64/70/b0/f8) own two markers,
  split exactly by form class. (ii) Pair order is a
  balanced two-state variable: 693 normal / 735 reversed /
  76 displaced / 0 missing,at fixed ordinals (15,16) /
  (16,15) in 692/693 and 733/735,no measured correlate
  (champion 29 both,ng both,parity ~even,nacts direction
  inconsistent across artifacts). (iii) TWO mirrored
  rare-ladder anomaly zones in 76c3a8ff (97-98 and
  105-106;rare operand sets identical within zone type,
  400/336 actions,33/31 champions;corrects AES-NUM-044's
  single-zone record;98 is the second 336 context,
  reversed-adjacent). (iv) Intermediate class exact:
  156 actions x26 at cidx 111+9k plus 173 x2 at 94/102,
  all ng1,champion 29,trailer 28/28;156 middle = 12-fold
  repeated unit (3856x12,30480x12,32784x24),26 distinct
  size seqs but only 2 operand seqs;173 middle is a
  different species (16400x24,32784x22,31120x8).
- **Next:** freeze the marker derivation as an encoder
  rule + host-test on all 212 + 20 family segments;
  pair-order determination hunt; zone-pair body
  comparison; 156 middle unit segment anatomy
  (slice 4.46).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-046 — marker encoder freeze

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_MARKER_ENCODER_FREEZE_2026-10-24.md.
- **Evidence:** contract TASK_hailo10h_marker_encoder_2026-10-25.md
  published + pushed at f5d1c087 before implementation;its scope
  (the freeze only) governed — the pair-order hunt,zone-pair
  comparison and 156 middle anatomy are re-queued as slice 4.47.
  Controls reproduce AES-NUM-029/032/033/034/035/036/037/038/039/
  040/041/042/043/044/045 exactly (128,787 small actions;79,001
  bursts;745,849 pointer actions;1,504 contexts;trailing pairs
  2,049;champion bursts 75,215;427 cc9 segments). Populations
  reproduced exactly: 212 dense cc9 marker segments under modal X
  and the 20 family segments (cc9 12,0a0d378c 7,0856a10c 1).
  Frozen: hailbru/ccw_marker.mojo (sha256 17d51cca...,crossed
  byte-identical to Mimir) — ccw_marker(predecessor,form):
  copy,byte2 +1,byte4 -4 (form 0,small) / +16 (form 1,464 B;
  form 2 = 464 B 0200 shape,also byte0 01->02);non-strict
  predecessor,byte2 0xFF,unsteppable byte4 or unknown form
  returns None. Segment-level rule check 220/220 FAILED 0
  (hef46.py sha256 2812db65...);78 distinct
  (predecessor,marker,form) triples;on-device Mojo harness
  CHECKED 78 FAILED 0;standalone smoke: the three recorded
  examples produce their recorded markers,both refusals fire.
- **Next:** pair-order determination hunt,zone-pair body
  comparison,156 middle unit segment anatomy (slice 4.47).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-047 — pair-order hunt, zone bodies, 156 motif

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_PAIR_ORDER_ZONE_BODY_156_MOTIF_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032/033/034/035/036/037/038/039/040/041/042/043/044/045/046 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts;trailing pairs 2,049;champion bursts 75,215)
  in hef47.py (sha256 ddd81ba0...) and hef47b.py (b4a89157...).
  (i) Pair order is NOT a function of the champion operand
  sequence at any tested granularity: single head ordinals
  0-14 leave 36-51 mixed keys (majority accuracy 0.847-0.928),
  subfields and joint subsets stay mixed,action-size keys
  stay mixed;head-sequence grouping (383 keys) has exactly
  ONE mixed group — 0856a10c cidx 15/27 (reversed) and 39
  (normal) share a byte-identical non-pair champion stream
  and identical pair datums,yet take both orders (headseq
  majority accuracy 1427/1428 is a proxy,not a law;their
  datum and size sequences differ). The five post-pair
  champion bursts are a UNIVERSAL coda: one operand sequence
  and one datum sequence in all 1,428 binary contexts.
  (ii) Zone pairs outside the rare/pair region share only
  the skeleton tail: champion position-equality 12/27 (the
  common suffix) in both pairs,set symdiff stays 30,size
  multiset symdiffs unchanged (154/110);bodies differ
  outside as much as inside. (iii) The 156 middle has NO
  exact period: it is a 12-block motif (3856 exactly 12x
  per context,312 pooled; block (82xx-84xx,3856,32784,
  32784,30480) with one shortened and one truncated block
  in the exemplar) carrying private payloads — 1,924
  distinct segments in 2,288 occurrences,only 8 universal
  middle positions,all pre-motif. Corrects AES-NUM-045's
  "12-fold repeated unit" wording.
- **Next:** pair-order vs body datum sequence + combined
  champion/size function test;motif block anatomy pooled;
  rare-burst datum check vs the frozen champion map
  (slice 4.48).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-048 — datum-order hunt, motif pooled, rare check

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_DATUM_ORDER_MOTIF_RARE_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032/033/034/035/036/037/038/039/040/041/042/043/044/045/046/047 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts;trailing pairs 2,049;champion bursts 75,215)
  in hef48.py (sha256 4757f16c...) and hef48b.py (08c76a5a...).
  (i) Pair order is NOT a function of the body datum stream:
  single head datums acc 0.847-0.928,head datum seq and
  datum-minus-pair each 383 keys with the same ONE mixed
  group (0856a10c cidx 15/27 reversed + 39 normal),inside
  which datum-minus-pair is IDENTICAL (1 distinct in 3) and
  the full datum sequences differ only at the pair slots
  15/16 (the swap itself) — refining AES-NUM-047. Head-level
  combined keys (op+sizes,op+dat,dat+sizes) still fail on
  the triple (acc 0.9993);full datum/full size/combined
  full separations (0 mixed) are uniqueness/tautology
  (1,111 distinct full size seqs),not laws. (ii) 156 motif
  pooled (312 blocks): leads private — 82 values,8104-8832,
  all multiples of 8,19-24 distinct per block index,26
  distinct lead seqs,none monotonic;block shape is positional
  — block 0 no-30480 and block 4 no-32784 in 26/26,blocks
  1-3,5-10 full in 26/26,block 11 full 25/26 (exemplar
  truncated);channel tuples an exact per-index law
  ((0,0,0,0,0) b0/1/4,(0,0,1,1,1) b2/3/5,(1,1,2,2,2)
  b6/7/8/11,(2,2,2,2,2) b9/10). (iii) Rare-ladder bursts
  (15 occ,6 distinct pairs, ladders 0x2a82/0x2a8e) are
  EXACT under the frozen channel-appropriate champion
  datum maps (15/15,6/6,zero wrong/refused),as is the
  whole body champion population (43,631 occ,1,451
  distinct pairs,all exact) — no rare-specific rule.
- **Next:** pair-order vs middle action stream;motif leads
  vs contexts' large-action sizes;block-0/4 variant roles
  vs standard middles (slice 4.49).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-049 — middle-stream order hunt, lead exclusivity, variant roles

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_MIDDLE_STREAM_LEAD_EXCLUSIVITY_VARIANTS_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032/033/034/035/036/037/038/039/040/041/042/043/044/045/046/047/048 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts;trailing pairs 2,049;champion bursts 75,215)
  in hef49.py (sha256 e1891202...) and hef49b.py (9b454b99...).
  (i) Pair order is NOT a function of any tested middle-stream
  feature: aggregates (len acc 0.857,sum 0.993 near-unique),
  coarse histogram 0.934,sorted multiset 0.994 (9 mixed),
  count triple 0.849,single positions 0.65-0.84,head/tail
  tuples 0.93-0.95;strongest = middle channel counts (438
  keys,2 mixed groups / 8 ctx,acc 0.9979 — both mixed groups
  in 0856a10c on other stacks: 448-action 14/41/50 and
  280-action 18/30/48/60/72). Combined keys with nopair_op
  separate formally (0 mixed: +midlen 386,+chan_counts 448,
  +sum 1086) ONLY by resolving nopair_op's single mixed
  group (the cidx 15/27/39 triple,among 111 multi groups /
  1,156 ctx) — recorded as single-counterexample artefacts,
  NOT laws;inside the triple the two reversed members differ
  at 35 middle positions with identical coarse hist and
  channel counts. (ii) Motif leads are NOT copies of own
  contexts' sizes: 0/312 in same-ctx other sizes,middle
  non-lead,head+trailer,and the next-ctx control;band
  actions inside 156 contexts = exactly the 312 leads;the
  82 values are shared vocabulary (16,112 band actions in
  799 standard contexts,16,105 in middles). (iii) Variant
  forms are generic: standard middles hold 20,411 3856
  windows — full 14.6% / no30480 22.7% / no32784 4.3% /
  other 58.4%,at scattered ordinals (ord0: 7/39/30/273;
  ord4: 52/106/2/154);the 156 motif's distinction is
  PINNING (ord0 no30480 + ord4 no32784 in 26/26);311
  standard contexts carry >=12 middle 3856;173 class has
  zero 3856.
- **Next:** pair-order vs middle channel sequence;lead-band
  neighbour role in standard middles;variant-ordinal
  concentration in the >=12-3856 standard subpopulation
  (slice 4.50).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-050 — channel-sequence order function, band role, variant concentration

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_CHANNEL_SEQ_BAND_ROLE_VARIANT_CONCENTRATION_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032/033/034/035/036/037/038/039/040/041/042/043/044/045/046/047/048/049 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts;trailing pairs 2,049;champion bursts 75,215)
  in hef50.py (sha256 d9bff251...) and hef50b.py (b55e5db6...).
  (i) Pair order IS a function of the middle channel sequence's
  global forms — the first stream to pass the function test:
  run-order alone (RLE channels,no lengths/sizes) 438 keys,
  129 multi groups / 1,119 ctx,0 mixed,max group 56;transitions,
  full RLE and full sequence 453 keys,133 multi / 1,108 ctx,
  0 mixed;last-20 channels 384 keys,119 multi / 1,163 ctx,
  0 mixed;first-40 runs 390 keys,115 multi / 1,153 ctx,0 mixed.
  Every local form FAILS: single positions 0.51-0.77,prefixes
  first-3 0.654 / first-20 0.981 (10 mixed) / first-50 and
  first-100 0.9993 with ONE mixed group (the periodic 0a0d378c
  763-action stack,cidx 5 reversed vs 14 normal;4 distinct
  full sequences inside),strides 5/10/20 mixed,run prefixes
  10 (28 mixed) / 20 (2 mixed),last-10 2 mixed. The 4.49
  channel-count mixed groups resolve: 280-action group takes
  exactly 2 run-order values,one per order (sequences identical
  within order,184/212 positions differ across);the triple's
  reversed members share an identical channel sequence (diff 0),
  normal differs at 34. Boundary: run-order is near-isomorphic
  to stack identity (2 of 438 keys span >1 nopair stack;34 of
  111 multi stacks carry >1 run-order value) — minimal form and
  mechanism NOT PROVEN. (ii) Band role is corpus-wide: standard-
  middle band actions are followed by 3856 in 10,334/16,105
  (64.2%) vs base rate 3.18%;10,334/20,411 standard windows
  (50.6%) are band-led (motif 312/312);band values = the 82
  motif leads (14,503 occ,61.7% lead-rate) + 10 extras (1,602
  occ,86.8%);band-led window classes full 27.2% / no30480
  15.3% / no32784 7.8% / other 49.7%;band by region middle
  16,105 / head 7 / trailer 0. (iii) No variant-ordinal
  concentration in the 311-context >=12-3856 subpopulation
  (20,346 windows): no variant class >=0.90 at any ordinal
  0-30 (top fractions all 'other',0.66-0.79);ord0 no30480
  39/311,ord4 no32784 2/311,the motif's double pin occurs
  exactly once (76c3a8ff cidx 4,609 actions,52 windows).
- **Next:** channel-separation emergence (run prefixes 20-40,
  last-20 refinement,0a0d378c first-50 stack split);band
  non-3856 followers (4368-led structures);both-pinned
  76c3a8ff cidx-4 anatomy vs the 156 class (slice 4.51).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-051 — channel emergence thresholds, band followers, cidx-4 anatomy

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_CHANNEL_EMERGENCE_FOLLOWERS_CIDX4_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032/033/034/035/036/037/038/039/040/041/042/043/044/045/046/047/048/049/050 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts;trailing pairs 2,049;champion bursts 75,215)
  in hef51.py (sha256 fa64869c...) and hef51b.py (91991d87...).
  (i) Exact emergence thresholds for the AES-NUM-050 channel
  order function,all zero-mixed: channel run prefixes 35 runs
  (388 keys,114 multi / 1,154 ctx; progression 15:6 mixed /
  18:4 / 20-21:2 / 22-34:1 / 35:0),full run prefixes 34,
  last-N channels 18 (last-17 sole mixed = cross-artifact
  pair 5ab3537d cidx 210 rev / 76c3a8ff cidx 88 nor),
  last-N runs in 16-20 (15:1 mixed 0856a10c group,20:0),
  first-N channels 122 via the stack. The run-20 second
  mixed group is the sister pair (5ab3537d cidx 87 nor /
  773470cd cidx 87/211 rev,841 actions),resolving at run 22;
  from run 22 to 34 the ONLY mixed group corpus-wide is the
  0a0d378c stack. (ii) Stack split: 15 members,4 distinct
  channel sequences (reversed singleton; normals 3 seqs,
  run counts 172/174/177 vs rev 178); rev differs from
  EVERY normal at exactly 228 channel positions, first at
  position 121 (rev channel 0, all normals channel 2;
  position 120 both 2); first differing run index 34
  (rev inserts a channel-0 run into the 1,2 alternation,
  phase cascade 79-85 runs); min separating prefixes vs
  all normals = 122 chans / 35 chan-runs / 34 full runs.
  (iii) Band non-3856 followers 5,771: 4368 2,168 (80 ctx)
  + 4112 683 (119) = 49.4%; rest 2,920 over 251 sizes.
  4112 is a FIXED CHAIN: band value 8208 in 673/683, next
  3088 in 672/683, 5-gram (8208,4112,3088,32784,32784)
  597/683, only 17 distinct 5-grams. 4368 is scattered
  (1,645 distinct 6-grams; only 0856a10c + 76c3a8ff;
  window-analog classes 398/150/288/1,332); 4368 globally
  2,594 occ, 83.6% band-preceded, NEVER followed directly
  by 3856 (0/2,594), no 3856 within 9 after band->4368 in
  1,147/2,168; predecessors 27280 455 / 4368 414 (chains).
  (iv) 76c3a8ff cidx 4 is NOT a motif relative: 609 actions,
  middle 541, 52 windows (classes full 8 / no30480 11 /
  no32784 3 / other 30), motif-form 13/52, best motif run
  4 (rank 91/311; pool best 14 in 0856a10c cidx 100),
  champion 29 = the 156 class mean exactly, distinct mid
  sizes 55 vs 24.5. Its pin decomposes: window 0 genuine
  in-band (lead 8576, back-to-back windows), window 4 led
  by 9216 OUT of band; windows 4-7 led by a 9168-9248
  cluster; 15/52 windows have out-of-band leads.
- **Next:** last-runs exact emergence (16-20) + sister
  run-22 resolution;position-121 diverging action anatomy;
  8208->4112->3088 chain full extent;9168-9248 lead cluster
  census (second lead band?) (slice 4.52).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-052 — last-runs emergence, position-121 action, chain extent, lead cluster

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_LASTRUNS_POS121_CHAIN_CLUSTER_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032/033/034/035/036/037/038/039/040/041/042/043/044/045/046/047/048/049/050/051 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts;trailing pairs 2,049;champion bursts 75,215)
  in hef52.py (sha256 5123fb68...) and hef52b.py (5610901f...).
  (i) Last-runs emergence EXACT: RLE-channel last-N runs is
  mixed at 15 and 16 (sole group both times: 0856a10c cidx 3
  rev,280 actions,vs cidx 25/37 nor,832) and CLEAN at 17
  (387 keys,118 multi / 1,159 ctx,0 mixed;18-21 also clean);
  RLE-full last-N runs is clean at every scanned N from 5
  (threshold <=5). Last-17 channels' sole mixed pair and
  last-18 cleanliness reconfirmed. (ii) Sister group
  (5ab3537d cidx 87 nor vs 773470cd cidx 87/211 rev,841
  actions) resolves at run-prefix 22 because run index 21
  flips: normal (0,5) vs reversed (2,2) then (1,29); the
  reversed members are channel-identical to each other;
  run lengths differ from run 0 ((0,1) vs (0,5)),so RLE-full
  separates the sisters immediately — their holdout is
  purely channel-order (raw streams differ at 461 positions
  by length phase drift). (iii) Position-121 action: the
  0a0d378c stack's reversed member carries size 8208 on
  channel 0 at middle position 121,where all 14 normals
  carry ~5.5 KB (5,480-5,656) on channel 2; positions
  110-120 identical in class/channel across all 15; from
  121 the reversed pattern is phase-shifted one slot,and
  the normals carry their own 8208 at position 132 on
  channel 2. (iv) Chain full extent: band->4112 683,band
  8208 in 673,followed by 3088 in 672; the 672 chains are
  SISTERS-ONLY (336+336),exactly 6 per context in 112
  contexts; 32784 tail lengths 0-16 (mode 11,189),total
  length 3-19,20 distinct full size sequences,terminators
  29712 375 / 4112 114 / 80 70 / 12304 58 / 32 38 / 6160
  16 / 8208 1; predecessors 29712 297 / 6160 110 / 32784
  98 / 24 94 / 528 38 / 12304 18 / 80 17; segment bytes
  PRIVATE (positions 0-3 distinct 672/672; combined tuples
  672/672) — a rigid size template over unique payloads.
  (v) 9168-9248 cluster IS a second lead ladder: exactly
  11 step-8 values (9168..9248,counts 51-90),743 windows
  of 20,411 (band 10,334); but concentrated — cc9b9d1c 688
  in 19 of 271 contexts,76c3a8ff 55 in exactly 2 contexts
  (cidx 3: 41,cidx 4: 14; cidx 4 cluster ordinals 4-7,
  27-33,47-49),21 contexts total,none elsewhere. Dialect:
  after a cluster-led 3856 comes 32784 (295) / 32016 (52)
  / cluster (48) / 30480 (12); top after-4 patterns
  interleave 32016 with 32784 — 32016 plays 30480's role;
  classes other 557 / no30480 165 / no32784 12 / full 9.
- **Next:** cluster-context selection in cc9b9d1c (19 vs
  252 contexts);32016 dialect anatomy vs band windows;
  chain context selection in the sisters (which 112
  contexts;shared between sisters?) (slice 4.53).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-053 — cluster-context selection, 32016 dialect, chain context selection

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_CLUSTER_SELECTION_DIALECT_CHAIN_SELECTION_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032/033/034/035/036/037/038/039/040/041/042/043/044/045/046/047/048/049/050/051/052 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts;trailing pairs 2,049;champion bursts 75,215)
  in hef53.py (sha256 a9d093a5...) and hef53b.py (b0b47c1b...).
  (i) cc9b9d1c cluster membership is whole-context and
  band-exclusive:19 positives (cidx 1,14,18,29,30,33,34,57,
  65,85,151,155,166,167,170,171,194,202,222) hold 1,758
  windows = 688 cluster + 0 band + 1,070 other;252 negatives
  hold 0 cluster + 34 band.Corpus-wide exclusion fails only
  in 76c3a8ff cidx 3 (41+68) and cidx 4 (14+37).Window
  density does NOT select (61 negatives hold 81-96 windows,
  6,466/6,484 other-led,0 cluster);nor do nacts class (POS
  only 606/607/738,yet 105 negatives in range),champion
  count (29 everywhere),pair order or ng index.Positive
  cidx gaps [13,4,11,1,3,1,23,8,20,66,4,11,1,3,1,23,8,20]:
  the sequence from 14 repeats exactly from 155,paired
  contexts not copies (offsets 138-160,counts differ).
  Positives' top other leads hug the window:9264 56,9160
  51,9280 50,9256 48,9272 48 — a wider family is queued.
  (ii) 32016 dialect:cluster windows contain 32016 in
  352/743 (47.4%,multiplicity to 3) and 30480 in 55 (7.4%);
  band windows 32016 in 365/10,334 (3.5%) and 30480 in
  7,934 (76.8%);32784 64.9% vs 91.2%;next-3856 85.5% vs
  82.7% (rhythm comparable,gap medians 5/5);first-32016
  offset peaks at 3 in both (122/184) but cluster also
  opens at offsets 1-2.32016 global 8,131 occ,7,162 in
  cc9b9d1c (88.1%),172 contexts.
  (iii) Chain selection SETTLED:the sisters share the
  chain cidx set EXACTLY (56/56,symdiff 0) on one periodic
  train — step 3 cidx 2..80 (27 gaps),break 14+1 at
  80->94->95,step 4 cidx 99..203 (27 gaps) — and chain
  contexts are EXACTLY the isolated 232-239-action class
  (56 contexts in range,all chain,none outside;151-231
  bin empty;histogram identical in both sisters).Chain
  positions identical at 54/56 shared cidx;the 2
  exceptions are the break pair cidx 94/95.
- **Next:** wider lead-family census around the cluster
  (9100-9350 step-8 leads,positives vs dense negatives);
  lead vocabulary of the 61 window-dense cc9 negatives;
  cidx-1 single-cluster-window anatomy (slice 4.54).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-054 — wider lead family, dense-negative vocabulary, cidx-1 anatomy

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_WIDER_FAMILY_DENSE_VOCAB_CIDX1_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032/033/034/035/036/037/038/039/040/041/042/043/044/045/046/047/048/049/050/051/052/053 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts;trailing pairs 2,049;champion bursts 75,215)
  in hef54.py (sha256 5dfdc417...) and hef54b.py (ccf0a005...).
  (i) The wider lead family is exactly 9144-9264 (16 step-8
  values):900 windows in precisely the 19 cc9b9d1c cluster
  contexts,ZERO in all 252 negatives (dense or sparse);
  corpus 963 windows in 21 contexts (the 19 plus the known
  76c3a8ff cidx 3/4 exceptions).Membership does NOT
  re-grade — only the dose changes (900 vs the core's 688);
  edges are sharp (below 9144 the ladder belongs to the
  negatives,9000-9112 POS 0;above 9264 ownership flips by
  9288-9344 to the dense pool).The naive 9104-9352 extent
  would falsely admit 27 negative contexts on shoulders.
  Exclusive dose tracks core dose (correlation 0.948;
  per-ctx 9-64,mean 47.4). (ii) The 61 dense negatives run
  a disjoint ladder vocabulary:94xx zone share 0.288
  (9448 x176 top),low 8960-9136 0.194,97xx 0.194,band
  0.000;positives mirror (family 0.512,97xx 0.159,94xx 0).
  Vocab 64 vs 109 distinct,48 shared (jaccard 0.384);the
  16 positive-only values are exactly the exclusive zone;
  the whole 94xx ladder is dense-only. (iii) cidx 1 is an
  edge member:its single core window (ordinal 32,lead
  9232,channel 1,class other) is anatomically ordinary;
  exclusive dose 9 (mean 47.4) with a shoulder-heavy lead
  profile (9296 x14,9288 x12),yet its 32016 dialect is
  full strength (32016 x96 in its middle,30480 x0;windows
  40 no30480 / 56 other / 0 full) — dose and dialect are
  separate variables.
- **Next:** 94xx ladder anatomy (exclusive zone? dose law?
  its own window dialect?);shared 97xx ladder's role in
  both dialects;exclusive-minus-core dose gap per context
  (slice 4.55).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-055 — 94xx ladder, shared 97xx ladder, shoulder gap

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_94XX_97XX_SHOULDER_GAP_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032...054 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts;trailing pairs 2,049;champion bursts 75,215)
  in hef55.py (sha256 b3f4a458...) and hef55b.py (e0fe1cfd...).
  (i) The 94xx segment is NOT a family:the step-8 ladder is
  continuous 9352-9696 with no exclusive zone (POS zero
  9352-9504,then entering at 9512+);core 9408-9488 = 1,508
  windows in only 33/61 DENSE contexts + 3 sparse (38/139/175);
  dose BIMODAL (26 negative high carriers 45-63,10 low 1-26,
  235 cc9 zero;corr with window count 0.217).High carriers are
  marked by total low-ladder absence (mean 0.0 vs 34.4 in
  zero-94xx dense;corr -0.575) and speak the shared 32016
  dialect (dense middles 32016 mean 79.2,30480 mean 0.1;
  30480 in next-8 of 94xx windows 0/1,508) — no dialect of
  their own. (ii) The 97xx ladder (9696-9792) is cc9-ONLY
  corpus-wide (2,128 windows,74 contexts),present in every
  sub-population (POS 9/19,DENSE 41/61,OTHER 24/191),dose
  CAPPED at exactly 32 in carriers (POS 29-32 pstdev 0.99;
  correlations ~0 with all dialect doses),window anatomy
  identical in both dialects — a fixed-dose common module.
  (iii) Shoulder gap pooled 220 of 963 exclusive (lo 112,
  hi 108;per-ctx 0-23,corr with core -0.290):in cc9 every
  family context carries exactly ONE shoulder (9 lower-only,
  10 upper-only,0 both,0 neither;lo/hi corr -0.562);only
  corpus exceptions are 76c3a8ff cidx 3 (both,4+4) and
  cidx 4 (neither,gap 0).Shoulder windows anatomically
  ordinary;gap share 0.016 (cidx 85/222) to 0.889 (cidx 1).
- **Next:** shoulder-side selection;dense sub-population
  split features;97xx module position structure (slice 4.56).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-056 — Shoulder-side selection, dense split, 97xx positions

- **Status:** `verified` (complete populations,7 artifacts).
- **Owner:** docs/HAILO10H_SHOULDER_SIDE_DENSE_SPLIT_97XX_POSITIONS_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032...055 exactly
  (128,787 small actions;79,001 bursts;745,849 pointer actions;
  1,504 contexts;trailing pairs 2,049;champion bursts 75,215)
  in hef56.py (sha256 30bc87a3...) and hef56b.py (64c23e5a...).
  (i) Shoulder side is selected by NONE of pair order (LO 4/5,
  HI 4/6 normal/reversed),97xx carriage (4/9 vs 5/10,same
  doses),cidx (spans overlap,corr -0.210) or window position
  (shoulder frac 0.487 vs core 0.482;179/212 inside core span).
  Two one-way laws:low family dose (excl<30) is always upper
  (5/5;LO uniformly excl 51-64) and upper is always low-ladder-
  free (nlow 0 in 10/10;LO 0-7).Side runs in 8 stretches over
  the 19 family contexts.Selector NOT PROVEN. (ii) Dense
  negatives are FOUR populations:high94 25 (dose 45-63,all
  exactly 96 windows,nlow exactly 0,32784-rich),low94 8
  (dose 1-18;empty 19-44),zero94/low-high 16 (nlow 51-64),
  zero94/low-none 12 (nlow 0-1;93xx/89xx-led,all exactly
  738 actions,32016 exactly 96.0,all reversed) — low dose
  bimodal inside zero94 with no middle group. (iii) 97xx
  module is clustered,never one run except the all-module
  OTHER cidx 110 (32/32):599 runs over 73 carriers,gap-1
  adjacency 1,529/2,054 (74.4%),last window frac >=0.947
  in all 74;canonical ~21-block at ordinal 0 (18 max-run
  starts) or 43 (13),exact templates [21,2,1,3,1,1,2,1] x10
  and [21,2,1,1,1,1,1,2,1] x8 crossing sub-populations;
  23 scattered carriers (maxrun <=7);lead sequences
  unordered (1/74 sorted).Block placement NOT PROVEN.
- **Next:** low-none population corpus-wide;97xx block
  placement (0 vs 43 vs scatter);shoulder stretches vs
  intervening contexts (slice 4.57).
- **Audit:** Host-side analysis only;no device child.

### AES-NUM-057 — Low-none corpus-wide, 97xx placement, shoulder stretches

- **Status:** `verified` (complete populations, 7 artifacts).
- **Owner:** docs/HAILO10H_LOWNONE_CORPUS_97XX_PLACEMENT_STRETCHES_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032...056 exactly
  (128,787 small actions; 79,001 bursts; 745,849 pointer actions;
  1,504 contexts; trailing pairs 2,049; champion bursts 75,215)
  in hef57.py (sha256 10f6275f...) and hef57b.py (8aa9fb00...).
  (i) The low-none form is cc9b9d1c-only: refined signature
  (nlow<=1, n94==0, one segment dose>=20) hits exactly 21
  contexts corpus-wide, all cc9 — 15 maximal (738 acts, 32016
  x96, reversed: the 12 dense + POS cidx 1/29/166) and 6 reduced
  (606-607 acts, 32016 x32, normal). Three mutually exclusive
  lead segments, never co-occurring: 93-led 9288-9392 x6 of the
  12 (dose 56-64), 89-led 8888-8952 x4 (53-58; the low ladder's
  missing lower half), 98-led 9800-9856 x2 (63-64, ladder
  running through the 97xx band to 9840). Outside cc9 the 93
  segment is in zero contexts, the 89 in one (dose 1).
  (ii) 97xx placement follows network group: block43 x12 are
  ALL ng0 and ALL maximal (738/96/96; 10 exact late template;
  no 97 lead before ordinal 43); block0 x13 are 11 ng1 maximal
  + ng0 exceptions cidx 54/110. Mid x26 / scatter x23 span both
  groups. Placement rule beyond the ng correlation NOT PROVEN.
  (iii) Shoulder stretches are short-gap runs (within gaps mean
  4.9 vs switch 23.9; the 66-gap crosses the midpoint); the cc9
  stream mirrors at cidx +137 in LEAD sequences (72/134 pairs
  byte-identical leads, 0/134 mid-sizes, 0 at offsets 1-139 for
  sizes); POS recurs at +137 in 9/10 eligible, side preserved
  8/9 (exception 85 hi -> 222 lo). Intervening contexts do not
  select side (32016 24.6 vs 24.9); only low-ladder dose
  differs (0.91 within-stretch vs 5.29 switch).
- **Next:** +137 lead-mirror extent corpus-wide; reduced-grade
  low-none six anatomy; block0 ng0 exceptions cidx 54/110
  (slice 4.58).
- **Audit:** Host-side analysis only; no device child.

### AES-NUM-058 — Mirror extent, reduced six, block0 exceptions

- **Status:** `verified` (complete populations, 7 artifacts).
- **Owner:** docs/HAILO10H_MIRROR_EXTENT_REDUCED_SIX_BLOCK0_EXCEPTIONS_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032...057 exactly
  (128,787 small actions; 79,001 bursts; 745,849 pointer actions;
  1,504 contexts; trailing pairs 2,049; champion bursts 75,215)
  in hef58.py (sha256 aa635b23...) and hef58b.py (fc16205c...).
  (i) The AES-NUM-057 +137 lead mirror is RETRACTED: its 72/134
  decomposes as 60 empty==empty pairs + 12 trivial single-window
  [80] pairs (sources all cidx 0 mod 4); of 72 both-nonempty
  pairs 60 DIFFER. No non-trivial lead mirror at any offset in
  any artifact; windowed contexts exist in only 3 artifacts
  (cc9 147, 0856 112 all-distinct, 76c3 90 all-distinct).
  (ii) Reduced low-none six are a separate grade (606-607 acts,
  32016 x32, normal, 3088-led mid vocabulary, no 7952; not
  truncated maximals, no subsequence relation), forming three
  +137 profile pairs (34/171, 66/203, 86/223: ng flips, nwin
  and segment dose preserved exactly, sequences differ at
  ~90% of lead positions); segment leads are subsets of the
  maximal pool. (iii) Block0 ng0 exceptions cidx 54/110 are
  reduced-grade all-97 contexts (31/32, 32/32 windows 97-led);
  their ordinal-0 block is degenerate and the maximal ng
  placement rule stands. The 606/607 class is a step-4 rail
  of 55 cc9-only contexts (2-110 and 143-247).
- **Next:** step-4 rail grades and the all-97 quartet; +137
  profile-recurrence rates over all cc9; windowed populations
  of 0856/76c3 (slice 4.59).
- **Audit:** Host-side analysis only; no device child.

### AES-NUM-059 — Rail grades, +137 profile rates, windowed populations

- **Status:** `verified` (complete populations, 7 artifacts).
- **Owner:** docs/HAILO10H_RAIL_GRADES_137_PROFILE_WINDOWED_POPS_2026-10-24.md.
- **Evidence:** controls reproduce AES-NUM-029/032...058 exactly
  (128,787 small actions; 79,001 bursts; 745,849 pointer actions;
  1,504 contexts; trailing pairs 2,049; champion bursts 75,215)
  in hef59.py (sha256 30fc7722...). (i) The rail's window
  counts are SEVENTEEN values (32,33,36,38,41,47,48,50,53,54,
  62,70,81,84,91,95,96), not the TODO's four grades: each count
  is one +137 pair (91 x2 pairs, 95 x3, 96 x5 + unpaired cidx 2)
  with (near-)identical family-dose profiles, n32016 32 and
  champion 29 in both members; no cidx residue, rail half, ng,
  order or nacts feature selects a count. (ii) The all-97
  quartet (cidx 50, 54, 110, 187) is the 32-count grade filled
  by the capped 97xx module: 110 pure 32/32, 50/187 a +137 pair
  at 31/32, 54 at 31/32 with a 98-led exception, partners 191/
  247 near-all-97 at 30/32. (iii) +137 profile recurrence over
  all 134 cc9 pairs: nwin 0.978, pop 0.985, n32016 0.985,
  segment 0.978, cls97 0.843, order 0.769, nacts 0.582 against
  baselines 0.099-0.671 over offsets 2..269; ng preserved 0/134
  (boundary between cidx 133 and 137). (iv) 0856a10c (112
  windowed) and 76c3a8ff (90 windowed) are band monocultures:
  92.8% / 91.7% band leads over pools of 112 / 139 step-8
  values, quantised count classes (16/24/28/140; 24/28/140),
  against cc9's mixed ladder vocabulary (97 2128, 94 1622,
  low 1235, excl 900, band 34).
- **Next:** the shared 140-count class in both monocultures;
  cidx 0-2 (the three +137 pairs whose window counts differ);
  unpaired rail head cidx 2 vs non-rail cidx 139 (slice 4.60).
- **Audit:** Host-side analysis only; no device child.
