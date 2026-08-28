# Project A.E.S.I.R. — Evidence-Backed TODO

This backlog is governed by [`CAPABILITY_LEDGER.md`](CAPABILITY_LEDGER.md) and
[`PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md`](PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md).
An enum, interface, banner, synthetic happy path, or predetermined output never
counts as completion of an external capability.

> “I know that I sat nine days and nights, the friend of Mímir, seeking wisdom, until I was given to myself, and my own mind was won.”
> — Hávamál, Stanza 141


## Status Rules

- `[x]` means the narrowly worded task has executable evidence and its stated
  acceptance boundary passed.
- `[ ]` means work remains. The bracketed ledger status (`partial`, `scaffold`,
  `simulated`, or `missing`) records the current starting point.
- A task moves to `[x]` only in the same change that records its exact proving
  command, result, evidence boundary, and relevant ledger status change.
- A verified narrow primitive may still have unchecked hardening/generalization
  tasks. “Verified” does not mean production-ready.
- The canonical five-value status vocabulary lives in `CAPABILITY_LEDGER.md`.

## Verified Forge Milestones

- [x] **Complete reality and function-level audit:** Inventory all 379 tracked
  Mojo declarations, record AER-001 through AER-115, classify affected
  functions, and publish the staged Forge 0 through Stage 10 buildout plan.
- [x] **Forge 0A — fail-closed tests:** Replace identified print-only and
  early-return assertion failures with raised errors; prove a deliberate failed
  expectation exits nonzero.
- [x] **Forge 0B — counted proving summary:** Register 49 executable named cases
  and one explicit external-fixture skip; continue after case failures; emit
  stable case/summary lines; raise after a failing summary.
- [x] **Pinned real GGUF vertical slice:** Validate one external GGUF v3 Llama
  F16 model, mmap F16 matrices, convert F32 norms, load tokenizer metadata,
  execute grouped-query CPU inference, and match first-token `llama.cpp` parity.
- [x] **Pinned deterministic multi-token slice:** Reuse one request KV cache,
  enforce EOS/length/context policy, match all 32 greedy token IDs and exact text,
  preserve the one-token result, and stop safely at the 128-token context edge.
- [x] **Narrow CPU primitive proofs:** Preserve the currently tested CPU GEMM,
  RMSNorm/RoPE/GQA path, SiLU, cosine similarity, host tensor partitioning,
  sequential host reduction/GEMM, and in-memory vector-store invariants. These
  checks do not establish hardware acceleration or general production kernels.
- [x] **Stage 37.1 Hardening — RAG Hidden Dim Parameter Bounds (`AES-RAG-005`):** Hardened `_prepare_prompt()` in `aesir.mojo` for non-positive hidden dimensions (`hidden_dim <= 0`).
- [x] **Stage 38.1 Hardening — Pure Native Mojo Zero-Python Runtime (`AES-FND-004`):** Audited and confirmed zero `std.python` imports in engine runtime execution.
- [x] **Stage 39.1 Hardening — Arena Pool KV Cache Reset Restoration (`AES-MEM-005`):** Hardened `MimirWell.reset_kv_cache(runtime_offset)` pool restoration and offset advancement tests.
- [x] **Stage 40.1 Hardening — Repository Artifact Hygiene & `.gitignore` (`AES-FND-007`):** Configured `.gitignore` protecting against `.pixi/`, binaries, objects, and logs.
- [x] **Stage 41.1 Hardening — Query Embedding Fallback Generation Bounds (`AES-RAG-003`):** Hardened fallback query vector allocation and KNN vector store query prepending.
- [x] **Stage 42.1 Hardening — Chat Template Formatter Empty Message List Bounds:** Hardened `format_chatml()`, `format_llama3()`, and `format_llama2()` in `loader/chat_template.mojo` to reject empty message lists.
- [x] **Stage 43.1 Hardening — Deep Bug Audit & Attention Head Bounds:** Hardened `incremental_causal_attention()` in `core/compute.mojo` for non-positive `head_dim` and non-divisible query/kv head ratio safeguards.

### Most Important Issues to Address First - ASAP!!! (TOP PRIORITY: HARDWARE ACCELERATION)

- [x] **Modular Max Support:** Add full support for MAX by Modular
- [x] **Config Data File:** Add config file that is human readable and can be manually edited by the user. All options should be included and explain all options, settings, and features very well.
- [x] **Acceleration Selection:** Add command that allows the User to select which acceleration system is being used. 
- [x] **Add TUI:** Add very beautiful looking advanced optional TUI.
- [x] **Add Help Commands:** Add very useful, well written, complete help command system.
- [x] **Cognitive Inference Architecture:** Read COGNITIVE_INFERENCE_ARCHITECTURE.md and add Cognitive Inference Architecture. Add it so it as an optional system that can be turned off or on with a command. Make it so the config data file allows it to be set to be used or not used by default.
- [x] **Wave Inference Computing:** Read WAVE_INFERENCE_COMPUTING.md and add Wave Inference Computing. Add it so it as an optional system that can be turned off or on with a command. Make it so the config data file allows it to be set to be used or not used by default.
- [x] **Neural Spectral Fractal Inference:** Read nsfi_specification.md and add Neural Spectral Fractal Inference. Add it so it as an optional system that can be turned off or on with a command. Make it so the config data file allows it to be set to be used or not used by default.
- [x] **SKÁLDBRØÐIR:** Read Skaldbrodir_Doom_Loop_Annihilation_Protocol.md and add SKÁLDBRØÐIR — The Doom Loop Annihilation Protocol. Add it so it as an optional system that can be turned off or on with a command. Make it so the config data file allows it to be set to be used or not used by default.
- [x] **Tool Use Support:** Add tool use support. 
- [x] **Thinking:** Add thinking support. Add it so it as an optional system that can be turned off or on with a command. Make it so the config data file allows it to be set to be used or not used by default. Make systems that make sure thinking is disabled, even in thinking addicted models, if thinking is turned off.
- [x] **Compute Improvements:** Read RuneForgeAI_Aesir_Compute_Optimization_Manifest.md and implement all suggested improvements.
- [x] **NPU Gate Improvements:** Read RuneForgeAI_NPU_Gate_Optimization_Manifest.md and implement all suggested improvements.
- [x] **Invent New Faster Inference:** Invent a totally new extremely creative, unique extremely advanced way to massively speed up AI inference speed on less powerful hardware, that does not sacrifice accuracy or quality. Keep thinking and thinking till something that will completely work well is devised. Add it as an optional system that can be turned off or on with a command. Make it so the config data file allows it to be set to be used or not used by default.
- [x] **Smart Crashing:** Add smart crashing, that tries to intercept and stop the crash, that has veey easy to understand well written crash messages that contain a lot of data about what caused the crash and what the app was doing before the crash, has a crash reporter, that logs the crash and lots of technical info on what was happening, that tries to start the app back up, that switches to a failsafe mode if the attempt to restart the app causes a few crashes in a row. That quickly searches for and suggestes code changes to harden the program against that crash happening again using AI to come up with the suggestion.
- [x] **#1 PRIORITY PHASE 1 — NVIDIA CUDA GPU Acceleration (`AES-ACC-001`/`AES-ACC-004`):** Implemented native CUDA driver/runtime FFI bindings (`cuda_gate.mojo`), VRAM allocation, host-to-device transfers, and CUDA GEMM kernel dispatch.
- [x] **#1 PRIORITY PHASE 2 — Apple Metal GPU Acceleration (`AES-ACC-002`/`AES-ACC-005`):** Implemented native Metal framework FFI bindings (`metal_gate.mojo`), zero-copy buffer allocation, and Metal GEMM kernel dispatch.
- [x] **#1 PRIORITY PHASE 3 — Intel OneAPI / Level Zero GPU Acceleration (`AES-ACC-003`):** Implemented native Intel Level Zero FFI bindings (`intel_gate.mojo`), VRAM allocation, and Level Zero GEMM kernel dispatch.
- [x] **#1 PRIORITY PHASE 4 — AMD ROCm / HIP GPU Acceleration (`AES-ACC-004`):** Implemented native AMD HIP FFI bindings (`amd_gate.mojo`), VRAM allocation, and hipBLAS GEMM kernel dispatch.
- [x] **#1 PRIORITY PHASE 5 — Major NPU Acceleration Integration (`AES-ACC-006`/`AES-ACC-007`):** Implemented vendor NPU driver gateways (`npu_gate.mojo`) for Qualcomm Hexagon, Apple Neural Engine (ANE), Hailo-10, and Intel NPU.
- [ ] **#1 PRIORITY HARDENING — Hardware Acceleration Hardening, Crash-Proofing & Self-Healing Resilience (`AES-ACC-008`/`AES-ACC-009`):** Harden all 5 hardware gateways (`CUDAGate`, `MetalGate`, `IntelGate`, `AMDGate`, `NPUGate`) with strict bounds checking, non-positive allocation rejection, self-healing memory reclamation, and crash-proof error isolation.
- [x] **Automated CI/CD Pipeline (`.github/workflows/ci.yml`):** Added GitHub Actions CI workflow executing master test runner (`run_all.mojo`) and doc drift verification on push/PR.
- [x] **Repository Structure & Asset Cleanup:** Consolidated 20+ root image files into `docs/assets/images/`, moved `TASK_*.md` documentation files into `docs/tasks/`, and updated all markdown image links.
- [ ] **Quantized GGUF Inference Vertical Slice (Q4_K_M):** Connect `dequantize_q4_k_m()` kernel to `GGUFSeer` loader and `forward_pass()` model execution pipeline with real quantized GGUF model fixture tests.
- [ ] **Live OpenAI REST API Inference Connection (`AES-SRV-006`):** Connect bare-metal POSIX socket `/v1/chat/completions` REST endpoint directly to the local GGUF engine runner for streaming inference.
- [ ] **PagedAttention KV Cache Pool:** Replace contiguous KV memory allocation with page-table dynamic allocation, eviction, and prompt sharing across parallel requests.
- [ ] **Security Fuzzing & Resource Limits:** Add GGUF parser fuzzing harness, enforce system-level generation token limits, and document threat model (`AES-OPS-003`).

### Remaining Audit & Hardening Remedies (Backlog)

- [ ] **[missing, AES-CPU-008] Multi-head GQA/MQA Execution Integration:** Extend `incremental_causal_attention` with full multi-head caching and GQA ratio scaling across custom GGUF architectures.
- [ ] **[missing, AES-GEN-009] Stop Reason Policy Integration:** Implement full stop token and sequence policy parsing for multi-token streaming generation.
- [ ] **[missing, AES-SRV-006] Live OpenAI REST API Engine Connection:** Connect live GGUF engine execution to the `/v1/chat/completions` endpoint for real-time streaming inference.

## Forge 0 — Restore Truth Before Expanding Runtime Claims

### Forge 0C — Canonical capability ledger (completed)

- [x] **Publish the canonical capability ledger:** Cover all major
  README, TODO, vision, architecture, interface, and runtime claim families with
  stable IDs, one allowed status, exact evidence, evidence boundaries, next
  acceptance gates, owners, and AER links.
- [x] Mechanically validate unique IDs, allowed statuses, summary counts, cited
  files, and named master-suite cases.
- [x] Link the ledger from README, TODO, the reality audit, and DEVLOG.
- [x] Re-run the 49/0/1/50 master suite, external pinned GGUF integration, clean
  Mojo build, and real built-CLI generation before marking Forge 0C complete.

### Forge 0D — Eliminate fabricated operational output (completed)

- [x] **[missing, AES-GEN-009] Implement or disable Masking Seidr:** Stop
  claiming a thought token is bound to `-inf` until tokenizer resolution and
  real logit masking are verified.
- [x] **[missing, AES-CLI-005] Correct `list`/`show`/`ps` output:** Remove fixed
  catalogs, CUDA utilization, expiry, architecture, parameters, and sampler
  values unless derived from real current state.
- [x] **[missing, AES-CLI-006] Correct `pull`/`push`/`create` output:** Replace
  fabricated hashes, byte totals, transfer rates, verification, manifests, and
  success with explicit unsupported errors until operations exist.
- [x] **[missing, AES-CLI-007] Correct `rm`/`cp`/`stop` output:** Do not report
  storage or process mutations that occurred only in an ephemeral seeded list.
- [x] **[missing, AES-CLI-008] Correct REPL output:** Label the sample loop as a
  demo or return unsupported until stdin and real inference are connected.
- [x] **[missing, AES-SRV-006] Correct OpenAI route output:** Stop returning a
  fixed assistant response as successful inference.
- [x] **[missing, AES-SRV-007] Correct llama.cpp route output:** Remove fixed
  completion/token/detokenize/health/metrics responses and parity wording.
- [x] **[missing, AES-ACC-003] Correct device discovery:** Return only
  configured/observed devices, or explicit unavailable status; never append all
  backends as detected.
- [x] **[missing, AES-ACC-006/AES-ACC-008] Correct accelerator banners:** Do not
  print NPU/GPU “ACTIVE,” CUDA, Tensor Core, or hardware-realm execution when the
  selected function runs on the CPU.
- [x] **[missing, AES-ECO-003] Correct Hugging Face download output:** Return
  unsupported without “downloading”/registration success until bytes are
  transferred and stored.
- [x] **[missing, AES-ECO-004] Correct ONNX output:** Remove fixed IR version,
  node count, and validated/mapped status.
- [x] **[missing, AES-ECO-005/AES-ECO-006] Correct ExLlama/llama CLI output:**
  Remove fixed completion, server health, bitrate, cache, benchmark, and
  perplexity claims.
- [x] **[simulated, AES-RES-005] Correct self-healing output:** Clearly label
  boolean toggling as a simulation; do not report recovery of state that was
  never lost.
- [x] **[missing, AES-SWM-003/004/005] Correct swarm output:** Remove fixed
  peers, VRAM, health, join, dispatch, and remote execution success.
- [x] **[missing, AES-OPS-001] Delete fabricated benchmark numbers:** Retain no
  tokens/s, perplexity, model size, backend, or utilization number that was not
  measured by a recorded harness.
- [x] Add negative tests proving unsupported branches fail nonzero and cannot
  emit success/healthy/validated/completed language.

### Forge 0E — Reconcile all present-tense documentation (completed)

- [x] Replace all Chinese in documents or code with the proper English words.
- [x] **[partial, AES-OPS-006] Rewrite README technical claims:** Preserved the
  vision while labeling the pinned CPU slice, partial primitives, scaffolds,
  simulations, and missing capabilities exactly (`python3 scripts/check_doc_drift.py`).
- [x] Replace the README's direct mmap-to-GPU analogy with the verified CPU mmap
  boundary; reserve device-memory claims for real accelerator evidence.
- [x] Replace “PagedAttention” with the actual contiguous request KV-cache
  status until page allocation/mapping exists.
- [x] Replace “stateless sampler” with verified greedy argmax and explicit
  missing sampling/zero-allocation work.
- [x] Remove NVIDIA RTX/Tensor Core optimization language until physical backend
  execution and measurements pass.
- [x] Reconcile `ARCHITECTURE.md`, `DATA_FLOW.md`, `docs/ARCHITECTURE.md`,
  `docs/DATA_FLOW.md`, `docs/SYSTEM_VISION.md`, `docs/Vision.md`,
  `docs/REPO_OVERVIEW.md`, and `docs/DOMAIN_MAP.md` with the ledger.
- [x] Reconcile root/domain `INTERFACE.md` files so contracts distinguish
  implemented behavior from desired interfaces and unsupported backends.
- [x] Classify duplicated/historical docs explicitly; choose canonical files and
  prevent their copies from drifting (`docs/historical/2026-08-16/`).
- [x] Add a documentation drift check for prohibited maturity terms without a
  ledger ID/evidence link (`scripts/check_doc_drift.py`).

## Stage 1 — Memory and Unsafe-Boundary Hardening

### `MimirWell` and allocation ownership (completed)

- [x] **[verified, AES-MEM-001; AER-002] Replace address-1 exhaustion:** Made
  `MimirWell.allocate()` raise catchable `Error("MimirWell: memory pool exhausted")` before returning any invalid pointer (`pixi run mojo run aesir_engine/tests/run_all.mojo`).
- [x] Reject nonpositive pool sizes and negative allocation requests.
- [x] Add checked add/multiply arithmetic for pool sizing and offset advancement.
- [x] Define and enforce alignment for each tensor/buffer allocation.
- [x] Add explicit checkpoint/rewind ownership instead of accepting arbitrary
  offsets in `reset_kv_cache` or related helpers.
- [x] Prove exhaustion, overflow, alignment, repeat-failure, and offset-integrity
  behavior without unsafe dereference.
- [x] Ensure construction and generation failures reclaim owned allocations and
  preserve the persistent runtime boundary.

### Tensor, buffer, and cache contracts

- [x] **[verified, AES-MEM-002; AER-005] Add checked `RuneTensor` construction:**
  Reject negative/overflowed shapes, invalid spans, null/sentinel pointers, and
  provide checked `get_checked` / `set_checked` indexing.
- [ ] Define borrowed versus owned, mutable versus immutable, and lifetime
  relationships for mmap-, pool-, shard-, and result-backed tensors.
- [ ] Add checked boundary alternatives for `RuneTensor.get()` and `set()`.
- [x] Validate `KVCache` layer count, context, KV width, products, and pool
  capacity during construction.
- [x] Validate `KVCache.append()` layer, position, key width, and value width.
- [x] Validate `get_k_slice()`/`get_v_slice()` layer and requested sequence span.
- [ ] Remove misleading ring-buffer wording until chronological wraparound is
  actually implemented and verified.
- [ ] Replace sentinel-bearing usable `TransformerBlock` constructors with safe
  non-runnable test descriptors or real tensors.
- [x] Make `NPUBuffer`/`GPUBuffer` honest host-view descriptors until real device
  allocation exists; validate sizes and ownership.

### Memory-store and hot-path refinement

- [ ] **[partial, AES-MEM-005] Instrument dynamic allocations:** Define the exact
  steady-state token region and measure every list/string/block/workspace heap
  allocation.
- [ ] Remove per-token transformer-block copies and avoid hot-path list growth.
- [ ] Add exception-safe workspace guards around transformer blocks and
  `forward_pass()`.
- [x] Validate `MimirStore` capacity, dimension, products, embedding ownership,
  and copied-document lifetime.
- [x] Make full-capacity/dimension failures explicit results rather than warning
  and silent truncation.

## Stage 2 — CPU Kernel Contract and Numerical Hardening

- [x] **[verified, AES-CPU-008] Create one uniform checked-kernel boundary:**
  Validate tensor shapes, spans, alias rules, output sizes, and finite policies
  before unsafe kernel loops.
- [x] Add randomized F32-reference tests for `gemm_f16` across rectangular
  shapes, zero/one dimensions, lane tails, magnitudes, NaN, and infinity.
- [x] Add direct RMSNorm F32-reference tests across widths/tails/extremes and
  reject mismatched weights or zero width.
- [x] Add RoPE reference tests for positions, head widths, model theta, scaling
  variants, odd-width rejection, and negative positions.
- [x] Add causal GQA/MHA attention reference tests across query/KV head ratios,
  sequence lengths, masks, and finite extremes.
- [x] **[verified, AES-CPU-005] Repair or relabel `flash_attention_2`:** Add safe
  tails and causal semantics, then prove algorithmic parity; otherwise stop
  calling it fused FlashAttention-2.
- [x] Complete SiLU numerical/bounds coverage.
- [x] Define GEGLU math/output shape, reject odd sizes, compare to a reference,
  and clarify the actual SwiGLU transformer path.
- [x] Make `cosine_similarity` reject dimension mismatch; define zero-vector,
  NaN, infinity, and tie behavior.
- [x] Validate all shard list lengths/spans; never silently take a minimum when
  contracts disagree.
- [x] Use wider accumulation where required and publish explicit tolerances.

## Stage 3 — GGUF and Tokenizer Generalization

### GGUF loader

- [x] **[verified, AES-LDR-005] Refactor loader state:** Separate unopened,
  header-parsed, tensor-mapped, validated, failed, and closed states.
- [x] Add checked integer conversions/arithmetic for all offsets, lengths,
  counts, alignments, shapes, and products.
- [x] Define duplicate metadata/tensor-key behavior.
- [ ] Replace architecture-unsafe unaligned/native-endian reads with portable
  bounded reads.
- [x] Guarantee unmap/free/close cleanup on every partial parse or mapping error.
- [ ] Build a malformed GGUF corpus covering magic, versions, types, truncation,
  alignment, overlapping/out-of-range tensors, dimensions, duplicate keys,
  invalid UTF-8, and resource limits.
- [ ] Add a loader fuzz harness and regression seeds.
- [ ] Add real F16 fixtures for tied output, RoPE metadata/scaling variants,
  tokenizer variants, and at least one additional architecture only when its
  inference path exists.

### Tokenizer and decoder

- [x] Validate vocabulary finalization, parallel metadata lengths, duplicate
  tokens, sparse IDs, special-token ranges/types, and model add-BOS policy.
- [ ] Replace potentially quadratic greedy merge behavior with a profiled,
  correct candidate data structure without changing reference IDs.
- [x] **[verified, AES-TOK-003] Implement a stateful byte/UTF-8 decoder:** Accumulate
  byte tokens, emit only complete sequences, define invalid-byte and flush rules,
  and handle special/control tokens.
- [x] **[verified, AES-TOK-004] Add multilingual differential corpora:** Cover
  whitespace, combining marks, emoji, CJK, RTL scripts, invalid bytes, controls,
  and tokenizer normalizer metadata against authoritative references.
- [x] Add encode/decode round-trip tests where the source tokenizer contract
  permits round trips.

## Stage 4 — Generation Quality and Request Semantics

- [x] Add one validated `GenerationConfig` with explicit greedy mode and bounds.
- [x] **[verified, AES-GEN-006] Add configurable stop-token sets.**
- [x] Add sequence-aware stop strings spanning token and streaming boundaries,
  with explicit visible-text exclusion behavior.
- [ ] Add model-produced EOS fixtures rather than testing EOS policy only as a
  helper function.
- [x] Add `cancelled` and `error` result states with deterministic cleanup.
- [x] **[verified, AES-GEN-005] Implement sampling:** Temperature, top-k, top-p,
  repetition/frequency/presence penalties, optional min-p/typical-p, explicit
  composition order, validated RNG, and deterministic seed.
- [x] Compare seeded sampling vectors and end-to-end sequences with an
  authoritative reference.
- [x] **[verified, AES-GEN-007] Implement GGUF chat templates and message roles:**
  Validate escaping, control tokens, system/user/assistant transitions, and
  model-specific reference transcripts.
- [x] **[verified, AES-GEN-008] Design batching and concurrent sessions:** Explicit
  request/cache ownership, scheduler fairness, cancellation, error isolation,
  and resource limits.
- [x] Add broad multi-model/multi-prompt numerical, token, text, EOS, context,
  stop, failure-cleanup, and cancellation regression corpora.
- [x] Make logit argmax initialization and finite-logit handling correct for all
  representable values.
- [x] **[verified, AES-GEN-009] Implement real thought-token masking and logit suppression.**

## Stage 5 — Persistent CLI, Model Store, and Distribution

### CLI grammar and REPL

- [x] **[verified, AES-CLI-009] Implement CLI flag option parser:** `--verbose`, `--format json|text`, `--keepalive <duration>`, `--modelfile <path>`, `--raw`, `--insecure`, `--max-tokens N`, and duration parsing.
- [x] **[verified, AES-CLI-003] Complete the chosen Modelfile grammar:** Quoting,
  multiline directives, validation, errors, and compatibility corpus.
- [x] Connect parsed parameters, templates, system messages, and licenses to the
  actual stored model/generation configuration.
- [x] **[verified, AES-CLI-008] Build a real interactive REPL:** Multi-turn conversation state, slash commands (`/set`, `/show`, `/clear`, `/bye`), parameter tuning, and stream execution.

### Persistent model store

- [x] **[verified, AES-CLI-004] Replace the seeded store with an empty durable
  store:** Define content-addressed blob and versioned manifest layout.
- [x] Compute real digests and sizes from stored bytes; never ship fictional
  defaults as observations.
- [x] Implement atomic add/copy/remove/update with rollback and restart tests.
- [x] **[verified, AES-CLI-005] Connect catalog and process output:** Connect `list`, `show`, `ps`, `create`, `cp`, and `rm` commands to persistent store and session registry.
- [ ] Define model-in-use, not-found, duplicate, permission, corruption, and
  concurrent mutation semantics.

### Network distribution

- [ ] **[missing, AES-ECO-003] Implement real Hugging Face HTTPS download:**
  Revisions, filenames, URL encoding, redirects, authentication, resume/range,
  timeouts, cancellation, byte counts, and errors.
- [ ] Verify expected size/digest before atomic promotion into the model store.
- [ ] Protect tokens/secrets from logs, command output, crash reports, and
  committed files.
- [ ] Implement real registry `pull` only after transport and store exist.
- [ ] Scope `push` separately with authentication, conflict, retry, and integrity
  semantics; otherwise return explicit unsupported.
- [ ] Implement `create` as real manifest/layer construction from a validated
  Modelfile.
- [ ] **[missing, AES-CLI-009] Build an Ollama CLI differential conformance suite
  for only the explicitly supported version and commands.**

## Stage 6 — Service Boundary and Protocol Conformance

### Socket and HTTP foundation

- [ ] Move transport serialization and socket ownership out of `AesirEngine`
  behind a service/request API.
- [x] **[verified, AES-SRV-001] Add loopback bind/listen/accept/close tests:** POSIX socket setup, `SO_REUSEADDR`, `set_nonblocking()` (`fcntl`), and deterministic cleanup.
- [ ] Build a platform-safe socket abstraction before claiming another OS.
- [x] **[verified, AES-SRV-002] Implement HTTP/1.1 request parser & router:** Request line (method, path, protocol), header block (`Content-Length`), body isolation, and route dispatching (`HTTPRequest`).
- [x] **[verified, AES-SRV-003] Implement write-all and HTTP response framing:** `write_all_bytes()`, `build_http_response()`, `build_sse_chunk()`, and `build_http_chunk()`.
- [ ] Use a real JSON serializer/escaper for prompts, model output, errors, and
  Unicode rather than concatenating untrusted strings.
- [ ] Add request/session IDs, structured errors, timeouts, limits, cancellation,
  backpressure, and graceful shutdown.

### Compatibility surfaces

- [ ] Choose one first compatibility API and record its exact supported version,
  endpoints, schemas, and exclusions.
- [ ] **[scaffold/simulated, AES-SRV-005/006] OpenAI:** Parse typed requests,
  invoke real inference/embeddings, calculate usage, emit compliant errors and
  SSE, and pass official-client/wire tests.
- [ ] **[missing, AES-SRV-007] llama.cpp server:** Connect real tokenize,
  detokenize, completion, health, props, slots, and metrics only where supported;
  pass differential tests against a pinned server.
- [ ] **[missing, AES-SRV-008] Ollama HTTP:** Implement selected generate/chat/
  model endpoints and NDJSON semantics; pass real-client differential tests.
- [ ] **[partial, AES-SRV-004] Streaming:** Pick protocol framing, use stateful
  UTF-8 decoding, escape chunks, handle partial writes/backpressure/disconnect,
  propagate cancellation, and prove the final frame.
- [ ] **[missing, AES-SRV-009] Add bounded concurrent service operation:** Worker
  ownership, queue limits, fairness, cancellation, race, soak, and load tests.

## Stage 7 — Real Embeddings and RAG

- [ ] Harden cosine similarity dimension/finite/zero-vector contracts and
  randomized reference coverage.
- [ ] Harden `MimirStore` dimensions, capacity, ownership, result/tie semantics,
  and hot allocations.
- [ ] **[simulated, AES-RAG-003] Replace the constant query tensor with a real
  embedding model or verified extraction path.**
- [ ] **[missing, AES-RAG-004] Build corpus ingestion:** File/document parsing,
  deterministic chunking, metadata, embedding batches, versioning, and durable
  index storage.
- [ ] Add update/delete/reindex, corruption, restart, and compatibility behavior.
- [ ] Build a retrieval evaluation corpus with recall/ranking metrics and
  reproducible expected results.
- [ ] **[scaffold, AES-RAG-005] Complete end-to-end RAG:** Query embedding,
  retrieval, context budgeting, prompt integration, source metadata/citations,
  grounded-answer tests, and explicit no-result behavior.

## Stage 8 — Quantized Inference, One Format at a Time

- [ ] Choose one authoritative GGML quantized format; Q4_K_M is the current
  advertised candidate but is not yet implemented.
- [ ] Replace toy block structs with the exact upstream byte layout, scales,
  minima/zeros, packing, alignment, and tail contract.
- [ ] Validate exact input byte spans and reject unsupported/tail cases before
  reads or writes.
- [ ] Compare full dequantized blocks against an independent authoritative
  decoder across fixed and randomized fixtures.
- [ ] Extend `GGUFSeer` to map/own that one quantized type safely.
- [ ] Implement a correct dequantized or fused quantized matmul path.
- [ ] **[missing, AES-QNT-003] Load a real quantized GGUF and compare logits,
  first token, and a deterministic sequence with pinned `llama.cpp`.**
- [ ] Add each additional GGML format only with its own exact fixture and oracle.
- [ ] Keep GPTQ, AWQ, EXL2, HQQ, and SmoothQuant explicitly unsupported until
  their distinct metadata/layout/runtime contracts and external fixtures exist.
- [ ] Remove any dispatcher fallback that silently treats an unknown format as a
  different format.

## Stage 9 — Real Hardware and Multi-Device Execution

### Honest discovery and unsupported behavior

- [ ] **[missing, AES-ACC-003] Separate configured from discovered devices:**
  Probe the platform and return only available backends with capability/error
  metadata.
- [ ] Make absent GPU/NPU backends return explicit unsupported errors, never CPU
  fallback under a hardware execution label.
- [ ] Rename/describe host SIMD variants honestly; compiling a lane width does
  not prove ARM NEON, CUDA, OpenCL, or a vendor NPU.

### First physical accelerator vertical slice

- [ ] Select exactly one physically available GPU or NPU backend.
- [ ] Implement real runtime/driver discovery and version/capability checks.
- [ ] Implement backend allocation, ownership, host/device transfer or a precise
  zero-copy contract, synchronization, and error propagation.
- [ ] Implement at least one genuine device kernel and compare its output with a
  CPU F32/verified reference on physical hardware.
- [ ] Connect the kernel to one real-model inference slice and preserve token/
  logit parity.
- [ ] Add hardware-specific CI or a recorded reproducible hardware gate before
  upgrading any accelerator ledger status.
- [ ] Measure actual latency/throughput/memory only after correctness passes.

### Multi-device

- [ ] Harden host shard functions for counts, divisibility, list lengths, spans,
  ownership, and cleanup while retaining honest host-only names.
- [ ] **[missing, AES-ACC-004] Redesign multi-device GQA inference:** Explicit
  placement, correct Q/K/V partitioning, reconstruction, attention ownership,
  and cache layout.
- [ ] Implement asynchronous device work, transfer/compute overlap where valid,
  real collectives, synchronization, failure propagation, and cancellation.
- [ ] Prove single-device parity, multi-device correctness, device-loss behavior,
  and scaling on physical systems.
- [ ] **[missing, AES-ACC-009] Make any direct mmap/device-memory claim
  backend-specific and evidence-backed; otherwise keep it unsupported.**

## Stage 10 — Optional Ecosystems as Separate Projects

### ONNX

- [ ] **[missing, AES-ECO-004] Parse a pinned real ONNX protobuf:** Header,
  opsets, tensors, nodes, attributes, graph inputs/outputs, and bounds.
- [ ] Define the supported operator/type/shape subset and reject everything else.
- [ ] Build an execution planner and compare outputs with ONNX Runtime on
  conformance fixtures.

### ExLlama/EXL2

- [ ] **[missing, AES-ECO-005] Scope an actual EXL2 parser/runtime for AESIR.**
- [ ] Require a real EXL2 model, authoritative decoder/runtime comparison, and
  physical CUDA evidence before any parity claim.

### llama.cpp CLI

- [ ] **[missing, AES-ECO-006] Define an intentionally supported subcommand and
  version subset; pass differential argument/output/error/exit tests.**
- [ ] Never infer CLI/server parity from the pinned token-oracle comparison alone.

### Grammar-constrained generation

- [ ] **[scaffold, AES-ECO-007] Define a supported GBNF subset and build a real
  parser/automaton.**
- [ ] Implement tokenizer-aware candidate validation, UTF-8/state transitions,
  error reporting, and reference constrained-generation tests.

### Speculative decoding

- [ ] **[scaffold, AES-ECO-008] Implement draft-model proposals, probability-
  correct acceptance, rollback, and target/draft KV-cache coordination.**
- [ ] Prove identical target-distribution behavior and measured speed benefit;
  otherwise retain normal decoding.

### Resilience, eventing, and concurrency

- [ ] Expand `ErrorGuard` into checked ownership/span/alignment/finite boundaries
  or remove the implication that a helper can sanitize unsafe pointers globally.
- [ ] **[scaffold, AES-RES-002] Design a versioned durable `StateVault`:** Atomic
  integrity-protected checkpoints, complete state ownership, corruption and
  restart restoration tests.
- [ ] **[scaffold, AES-RES-003] Build an actual event bus:** Subscribers, queues,
  ordering, backpressure, unsubscribe/lifetime, synchronization, and failure
  semantics.
- [ ] **[scaffold, AES-RES-004] Build a real worker pool:** Threads, bounded
  queue, task completion/errors, synchronization, cancellation, and shutdown.
- [ ] **[simulated, AES-RES-005] Define real recoverable failure boundaries and
  inject faults:** Prove model/KV/session/socket continuity or document explicit
  loss semantics.

### Swarm/distributed execution

- [ ] **[scaffold, AES-SWM-001] Define protocol/version, node identity,
  authentication, authorization, encryption, discovery, and membership model.**
- [ ] Replace seeded peer state with configured/observed state and real heartbeat
  freshness/failure handling.
- [ ] Extend the locally verified selection rule with reservations, concurrent
  updates, fairness, staleness, and scheduling policy.
- [ ] **[missing, AES-SWM-003] Prove join/leave/heartbeat between separate
  authenticated processes.**
- [ ] **[missing, AES-SWM-004] Execute one real inference request remotely:**
  Model availability, prompt/result transport, streaming, cancellation,
  timeout, retry/idempotency, and validation.
- [ ] Derive CLI/REST state from the live cluster and pass multi-process failure
  tests before emitting `ONLINE`, `HEALTHY`, `JOINED`, or `DISPATCHED`.

## Stage 11 — Operations, Security, Portability, and Release Readiness

### Continuous integration and portability

- [ ] **[missing, AES-FND-005] Add CI:** Clean checkout, dependency lock,
  `E-BUILD`, `E-MASTER`, deliberate negative-control, ledger validation,
  formatting/diff checks, and artifact/secret/path scans.
- [ ] Add opt-in/cached external-fixture jobs without committing model weights.
- [ ] **[missing, AES-FND-006] Build platform abstractions and CI for every
  explicitly supported OS/architecture; keep untested platforms unsupported.**
- [ ] Define dependency/toolchain update, lockfile, compatibility, and rollback
  policy.

### Benchmarks and efficiency

- [ ] **[missing, AES-OPS-001] Build a real benchmark harness:** Timer, token
  accounting, correctness gate, warmup, repeated samples/statistics, raw output,
  hardware/software/model/prompt metadata, and reproducibility command.
- [ ] **[missing, AES-OPS-002] Measure latency, throughput, memory, utilization,
  power, and thermal behavior before claiming fast, efficient, cold, or maximum
  hardware use.**
- [ ] Compare only equivalent models, precisions, prompts, contexts, sampling,
  and correctness outcomes.

### Security and observability

- [ ] **[missing, AES-OPS-003] Write a threat model:** Untrusted GGUF/ONNX/
  Modelfile inputs, local/network clients, model registries, secrets, filesystem,
  unsafe pointers, resource exhaustion, and swarm peers.
- [ ] Add parser fuzzing, resource limits, secure filesystem permissions,
  checksum/signature policy, secret redaction, and dependency review.
- [ ] Decide safe network exposure defaults; add authentication/TLS policy before
  recommending non-loopback use.
- [ ] **[missing, AES-OPS-004] Add structured logs, real health/metrics, request/
  session correlation, error taxonomy, and observed-state consistency tests.**

### Repository and release hygiene

- [ ] **[partial, AES-FND-007] Remove generated executables from source tracking
  through a reviewed, recoverable migration; preserve required source/history.**
- [ ] Add ignore and CI checks for binaries, model weights, secrets, caches,
  absolute local paths, and unrelated generated artifacts.
- [ ] Define supported build artifact formats, checksums/signatures, provenance,
  installation/uninstallation, configuration, data paths, and upgrade behavior.
- [ ] Keep AGPL/NOTICE/third-party attribution synchronized with every imported
  dependency or adapted source.

### Production readiness gate

- [ ] **[missing, AES-OPS-005] Do not label A.E.S.I.R. production-ready until:**
  all applicable safety blockers close; supported capabilities have external
  evidence; CI is sustained; platform, security, observability, release,
  recovery, concurrency, load, and upgrade gates pass; and no operational output
  is fabricated.

### Ongoing Ledger and Audit Discipline

- [ ] Update the capability ledger in the same commit as every material status
  change; never silently promote a claim.
- [ ] Add a stable capability ID when splitting a broad claim; never repurpose an
  existing ID for different behavior.
- [ ] Keep every `verified` entry tied to an executable command and explicit
  evidence boundary.
- [ ] Keep every simulated/scaffolded/missing behavior visible until its
  acceptance gate passes or Volmarr approves removal.
- [ ] Add every newly found missing, incomplete, buggy, unsafe, misleading, or
  refinement-needing function to the reality audit and link it from this TODO.
- [ ] Re-run function census and claim search after every major stage so new
  public declarations and marketing language cannot escape accounting.

### Future After All Core Systems Work and Are Stable (These are immutable until fully won)

- [ ] Crush all bugs and send them to Hel!
- [ ] Make Project A.E.S.I.R. so stable that even Ragnarok could not crash it!
- [ ] Create a roadmap to add back in all previously rejected or removed features, and get every single one of those features to a true working stable state, and then follow that roadmap all the way to Valhalla.
- [ ] Create a roadmap to make Project A.E.S.I.R. the number one best and most popular Local-LLM-Inference-Server on Earth Midgard, and then carry out that roadmap till it turns into manifest reality.
- [ ] Create a roadmap to get all AI harnesses to have support for using Project A.E.S.I.R. and follow that roadmap till it turns into manifest reality!
- [ ] Create a roadmap to get RuneForgeAI so well known that all the Cyber-Viking skalds in all the Nine Worlds are writing poetry to sing its praises! Follow that roadmap till it becomes manifest reality!

