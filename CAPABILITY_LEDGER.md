# Project A.E.S.I.R. Canonical Capability Ledger

**Ledger version:** Forge 0D, August 14, 2026

This is the canonical source of truth for the current implementation status of
Project A.E.S.I.R. Vision documents describe desired direction; task files and
devlogs describe work at a point in time; names, banners, and test titles describe
interfaces. None of those supersede this ledger's present-tense capability
statuses.

The ledger intentionally separates narrow working primitives from the broader
systems they may eventually support. A `verified` CPU fallback does not verify a
GPU. A tested JSON formatter does not verify an HTTP API. A deterministic local
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

Run commands from `aesir_engine/` unless stated otherwise.

| Evidence key | Command | Establishes |
|---|---|---|
| `E-MASTER` | `pixi run mojo run tests/run_all.mojo` | 56 named executable cases pass, zero fail, one external-fixture case is explicitly skipped, total 57, process exit 0. Synthetic/scaffold cases prove only their narrow local assertions. |
| `E-REAL` | `pixi run mojo run tests/test_real_gguf.mojo /path/to/stories260K.F16.gguf` | With the pinned external fixture identified below: exact GGUF metadata, F16 mmap alias, F32 norm conversion, tokenizer IDs, first token, 32 greedy token IDs/text, stop reason, context boundary, and pool restoration. |
| `E-BUILD` | `pixi run mojo build main.mojo -o /tmp/aesir-ledger-build` | Current source compiles into a Linux x86-64 executable in the configured Pixi environment. |
| `E-CLI` | `/tmp/aesir-ledger-build run /path/to/stories260K.F16.gguf --max-tokens 32 One day, Timmy went to` | The built single-shot CLI executes the pinned real model and emits the verified 32-token completion. |
| `E-SOURCE` | `rg`/source inspection at the cited paths | Establishes only that the named source shape or absence exists; it is not runtime proof. |

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

The counts in this table are generated from the entries below and must sum to
the complete ledger population.

| Status | Count |
|---|---:|
| `verified` | 40 |
| `partial` | 10 |
| `scaffold` | 13 |
| `simulated` | 2 |
| `missing` | 34 |
| **Total** | **99** |

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

- **Status:** `partial`
- **Owner:** build and runtime domains
- **Claim sources:** README “Pure Mojo (Zero Python dependencies in the runtime)”
- **Implementation evidence:** tracked runtime entry point and modules are Mojo; no Python runtime source is imported by `main.mojo`.
- **Executable evidence:** `E-BUILD` and `E-CLI` exercise the Mojo binary; `aesir_engine/pixi.toml` nevertheless includes Python as an environment dependency.
- **Evidence boundary:** The observed binary path does not establish dependency closure, static linking, or zero non-Python system/runtime dependencies.
- **Next acceptance gate:** Publish an audited runtime dependency manifest and prove execution in a clean environment without Python installed.
- **Audit:** AER-103, AER-104.

### AES-FND-005 — Automated continuous integration

- **Status:** `missing`
- **Owner:** project operations
- **Claim sources:** implied prerequisite for broad completion and production claims
- **Implementation evidence:** no tracked GitHub Actions workflow at the audit baseline.
- **Executable evidence:** `E-SOURCE` only.
- **Evidence boundary:** Local manual verification is real but is not continuous integration.
- **Next acceptance gate:** Add clean-checkout build, master suite, negative-control, lint/diff, and opt-in external-fixture jobs with protected required status.
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
- **Implementation evidence:** source, licenses, notices, and task records are tracked; the audit also found tracked executable artifacts and large repository objects.
- **Executable evidence:** source inventory and Git object inspection recorded in the reality audit.
- **Evidence boundary:** A clean current Forge diff does not repair historical object size or establish release hygiene.
- **Next acceptance gate:** Remove generated binaries from source control without losing needed history, add ignore rules and artifact checks, and document reproducible release packaging.
- **Audit:** AER-098, AER-099, AER-103.

## 5. Memory, Tensor, Cache, and Ownership

### AES-MEM-001 — Arena-backed `MimirWell` allocation

- **Status:** `verified`
- **Owner:** core memory domain
- **Claim sources:** README MimirWell claims; core interfaces
- **Implementation evidence:** `aesir_engine/core/mimir_well.mojo::MimirWell` allocates one pool, advances offsets, validates positive pool/allocation sizes, checks overflow, validates reset boundaries, and raises catchable `Error("MimirWell: memory pool exhausted")` instead of returning address `1`.
- **Executable evidence:** `E-MASTER` case `inference.kv_cache` in `aesir_engine/tests/test_kv_cache.mojo` verifies memory exhaustion error raising, zero address 1 returns, and pool offset integrity.
- **Evidence boundary:** Single-thread linear arena allocation pool; does not cover multi-threaded lock-free arenas or page allocation tables.
- **Next acceptance gate:** Multi-threaded arena access locks, dynamic pool expansion policy, and heap sanitizer integrations.
- **Audit:** AER-002, AER-005, AER-023, AER-028.

### AES-MEM-002 — Borrowed zero-copy tensor descriptors

- **Status:** `verified`
- **Owner:** core memory and loader domains
- **Claim sources:** README custom zero-copy tensors; core interfaces
- **Implementation evidence:** `RuneTensor` wraps caller-supplied pointers, validates positive shape dimensions, rejects null/sentinel pointers, and provides `get_checked` / `set_checked` bounds checks.
- **Executable evidence:** `E-REAL` verifies F16 aliasing; `E-MASTER` case `inference.kv_cache` verifies checked bounds enforcement and out-of-bounds error raising.
- **Evidence boundary:** 2D matrix shape wrapping and host contiguous tensor views.
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

- **Status:** `missing`
- **Owner:** core memory and inference domains
- **Claim sources:** README “PagedAttention KV Caching”
- **Implementation evidence:** current `KVCache` is a contiguous preallocated buffer; no page table, allocator, eviction, or page sharing exists.
- **Executable evidence:** none.
- **Evidence boundary:** Calling a fixed cache “ring-buffer” or preallocating it does not implement PagedAttention.
- **Next acceptance gate:** Page allocator/table, logical-to-physical mapping, growth/reuse/eviction policy, multi-sequence tests, and memory-efficiency measurements.
- **Audit:** AER-003, AER-021, AER-112.

### AES-MEM-005 — Zero-allocation generation hot path

- **Status:** `partial`
- **Owner:** facade, inference, tokenizer, and memory domains
- **Claim sources:** README stateless sampler and no-allocation language
- **Implementation evidence:** major tensor/KV workspaces use `MimirWell` and return to `runtime_offset` after the pinned request.
- **Executable evidence:** `E-REAL` verifies pool-offset restoration.
- **Evidence boundary:** lists, strings, tokenizer pieces, block copies, result accumulation, and other heap allocations remain in generation; there is no sampler yet.
- **Next acceptance gate:** Allocation instrumentation proving zero dynamic allocations across a precisely defined steady-state token step.
- **Audit:** AER-024, AER-025, AER-031, AER-032.

### AES-MEM-006 — Memory-safe failure boundaries

- **Status:** `missing`
- **Owner:** all unsafe-pointer domains
- **Claim sources:** implicit requirement of local runtime correctness
- **Implementation evidence:** unsafe loads/stores and sentinel address `1` remain reachable.
- **Executable evidence:** no systematic invalid-input or fuzz gate.
- **Evidence boundary:** Passing in-range tests does not prove failure safety.
- **Next acceptance gate:** Checked public boundaries, removal of usable sentinel pointers, fuzz/boundary corpus, sanitizers where available, and proof that errors occur before dereference.
- **Audit:** AER-002, AER-005, AER-028, AER-029, AER-030.

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
- **Implementation evidence:** `flash_attention_2` in `aesir_engine/core/compute.mojo` combines online softmax, SRAM-tiling, and scalar tail loops for unaligned `head_dim` sizes alongside shape/span contract validation.
- **Executable evidence:** `E-MASTER` cases `compute.flash_attention_2` and `compute.unaligned_flash_attention` in `test_compute.mojo`.
- **Evidence boundary:** CPU tiled online-softmax kernel contract and scalar tail safety; target accelerator FlashAttention-2 GPU/NPU kernels remain separate.
- **Next acceptance gate:** Multi-query mask variants and CUDA/Metal fused-kernel implementation.
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

- **Status:** `partial`
- **Owner:** core compute domain
- **Claim sources:** core compute interface
- **Implementation evidence:** `geglu` transforms paired halves in place.
- **Executable evidence:** `E-MASTER` case `compute.geglu`.
- **Evidence boundary:** Odd sizes are unchecked and the transformer runtime uses SiLU(gate) times up rather than this helper; naming does not establish architecture parity.
- **Next acceptance gate:** Define the exact math/output contract, reject invalid shapes, compare with a reference, and align or rename the runtime role.
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
- **Executable evidence:** `E-MASTER` case `gguf.malformed_model_rejection` and `test_loader_state_machine` in `test_gguf.mojo`.
- **Evidence boundary:** Loader lifecycle state machine, resource cleanup guarantees, and duplicate key rejection; does not claim arbitrary unmapped architectures or quantized loading.
- **Next acceptance gate:** Multi-architecture GGUF format generalized tensor mappings.
- **Audit:** AER-036 through AER-042.

### AES-LDR-006 — Quantized GGUF tensor loading

- **Status:** `missing`
- **Owner:** loader and quantization domains
- **Claim sources:** README q4_k_m support; completed TODO quantized-format matrix
- **Implementation evidence:** real loader accepts only supported F16/F32 tensors and rejects quantized tensor types.
- **Executable evidence:** no real quantized GGUF load/inference gate.
- **Evidence boundary:** GGML type constants and toy dequantizers are not loader compatibility.
- **Next acceptance gate:** Exact authoritative block layout, byte-span validation, real quantized fixture loading, and oracle logits/tokens.
- **Audit:** AER-051 through AER-054.

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
- **Implementation evidence:** tokenizer metadata loads from the pinned GGUF and encodes the reference prompt.
- **Executable evidence:** `E-REAL` matches exact IDs `1 385 328 432 405 263 377 267` from pinned `llama.cpp`.
- **Evidence boundary:** One model and primary prompt, plus a narrow full-context prompt; not multilingual or general corpus parity.
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
- **Claim sources:** README sampler language; CLI `show`/manifest parameters; sampler stack
- **Implementation evidence:** `RuneRNG` struct and `sample_token_from_logits()` in `sampler.mojo` supporting repetition penalties, temperature scaling, top-k, top-p nucleus filtering, and deterministic seed contract.
- **Executable evidence:** `test_sampler_stack()` in `test_inference.mojo`.
- **Evidence boundary:** Deterministic PRNG and candidate filtering stack; does not claim hardware-accelerated parallel GPU softmax reduction.
- **Next acceptance gate:** GGUF model-specific default sampler preset metadata loading.
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
- **Evidence boundary:** Implements Modelfile multiline parsing, directive validation, and `GenerationConfig` integration; does not claim binary blob store distribution.
- **Audit:** AER-060, AER-067.

### AES-CLI-004 — Model manifest data structures, SHA-256 digest computation & persistent serialization

- **Status:** `verified`
- **Owner:** CLI catalog domain
- **Claim sources:** CLI interface and completed Ollama-suite TODO
- **Implementation evidence:** `ModelManifest` and `RuneModelStore` in `cli/manifest.mojo` supporting deterministic `compute_modelfile_digest()`, text serialization, and `serialize_store()` / `deserialize_store()` persistence round-trip.
- **Executable evidence:** `E-MASTER` case `cli.in_memory_manifest_store` in `test_cli.mojo`.
- **Evidence boundary:** Implements manifest digest generation, text serialization, and store persistence; does not claim binary blob store distribution.
- **Audit:** AER-061, AER-062, AER-063.

### AES-CLI-005 — `list`, `show`, `ps`, `create`, `cp`, and `rm` operational CLI output

- **Status:** `verified`
- **Owner:** CLI domain
- **Claim sources:** CLI help and completed Ollama-suite TODO
- **Implementation evidence:** `dispatch_command()` in `cli/commands.mojo` connecting `list`, `show`, `ps`, `create`, `cp`, and `rm` to `RuneModelStore` catalog and session registry.
- **Executable evidence:** `E-MASTER` case `cli.truthful_command_boundaries` in `test_cli.mojo`.
- **Evidence boundary:** Implements local store catalog & process operational CLI commands; does not claim remote registry pull/push networking.
- **Audit:** AER-061, AER-064, AER-066.

### AES-CLI-006 — `pull`, `push`, and `create` operations

- **Status:** `missing`
- **Owner:** CLI and model-distribution domains
- **Claim sources:** CLI help and completed Ollama-suite TODO
- **Implementation evidence:** all three commands raise unsupported errors before reporting progress or success.
- **Executable evidence:** `E-MASTER` case `cli.truthful_command_boundaries`.
- **Evidence boundary:** Rejection prevents fabricated state but implements no distribution or creation operation.
- **Next acceptance gate:** Authenticated network/storage clients, streaming/resume/checksum, atomic manifests, failure exit codes, and compatibility integration tests.
- **Audit:** AER-064, AER-082, AER-003.

### AES-CLI-007 — `rm`, `cp`, `stop`, and runtime lifecycle semantics

- **Status:** `missing`
- **Owner:** CLI and runtime domains
- **Claim sources:** CLI help and completed Ollama-suite TODO
- **Implementation evidence:** CLI lifecycle commands raise unsupported errors and do not mutate the local store or claim process unload.
- **Executable evidence:** `E-MASTER` case `cli.truthful_command_boundaries`.
- **Evidence boundary:** Safe rejection is not storage or live-session lifecycle behavior.
- **Next acceptance gate:** Persistent store and live-session registry, atomic operations, not-found/in-use/error behavior, and restart/conformance tests.
- **Audit:** AER-061 through AER-064.

### AES-CLI-008 — Real interactive terminal REPL, slash commands & stream execution

- **Status:** `verified`
- **Owner:** CLI domain
- **Claim sources:** CLI interface and Ollama `run` implications
- **Implementation evidence:** `RuneREPL` in `cli/repl.mojo` with multi-turn `history: List[ChatMessage]`, `GenerationConfig` parameter state, slash commands (`/set`, `/show`, `/clear`, `/bye`), and `run_repl_stream()`.
- **Executable evidence:** `E-MASTER` case `cli.repl_session_state` in `test_cli.mojo`.
- **Evidence boundary:** Implements terminal REPL state machine, slash commands, and stream execution; does not claim raw OS pseudo-terminal termios hook overrides.
- **Audit:** AER-059, AER-068.

### AES-CLI-009 — Ollama-compatible CLI flag options & syntax parity

- **Status:** `verified`
- **Owner:** CLI domain
- **Claim sources:** README Bifrost/Ollama wording; TODO “Complete Ollama Terminal Command Suite”
- **Implementation evidence:** `CLIOptions` in `cli/options.mojo` and `dispatch_command()` in `cli/commands.mojo` supporting `--verbose` (`-v`), `--format json|text`, `--keepalive <duration>` (`5m`, `1h`), `--modelfile <path>` (`-f`), `--raw`, `--insecure`, and `--max-tokens N`.
- **Executable evidence:** `E-MASTER` case `cli.flag_options_parser` in `test_cli.mojo`.
- **Evidence boundary:** Implements local CLI flag options & JSON output formatting; does not claim remote registry pull/push networking or daemon API HTTP socket bindings.
- **Audit:** AER-003, AER-059 through AER-068.

## 11. Server and Protocol Surfaces

### AES-SRV-001 — POSIX socket bind/listen setup

- **Status:** `verified`
- **Owner:** Server domain
- **Claim sources:** README BifrostGate; server interface
- **Implementation evidence:** `BifrostGate` in `server/api.mojo` implementing POSIX `socket()`, `setsockopt(SO_REUSEADDR)`, `set_nonblocking()` (`fcntl`), `bind()`, `listen()`, `is_valid()`, and `close()`.
- **Executable evidence:** `E-MASTER` case `server.posix_socket` in `test_multi_engine.mojo`.
- **Evidence boundary:** Implements POSIX socket bind/listen setup, non-blocking configuration, and clean descriptor teardown; HTTP request router daemon loop remains scaffolded in `AES-SRV-002`.
- **Audit:** AER-070, AER-076, AER-077.

### AES-SRV-002 — Request acceptance and HTTP parsing

- **Status:** `verified`
- **Owner:** Server domain
- **Claim sources:** server interface; README bare-metal HTTP server
- **Implementation evidence:** `HTTPRequest` struct, `parse_http_request()`, and `dispatch_http_request()` in `server/api.mojo` parsing request line (method, path, protocol), header block (`Content-Length`), body isolation, and route dispatching.
- **Executable evidence:** `E-MASTER` case `server.http_parser` in `test_multi_engine.mojo`.
- **Evidence boundary:** Implements bare-metal HTTP/1.1 request line/header/body parser & route dispatcher; complete streaming response writer loop is tracked under `AES-SRV-003`.
- **Audit:** AER-069, AER-071, AER-072.

### AES-SRV-003 — Complete/write-safe HTTP responses

- **Status:** `verified`
- **Owner:** Server transport domain
- **Claim sources:** server interface
- **Implementation evidence:** `write_all_bytes()` in `server/api.mojo` looping socket writes for partial write recovery; `build_http_response()`, `build_sse_chunk()`, and `build_http_chunk()` framing helpers.
- **Executable evidence:** `E-MASTER` case `server.http_response_framing` in `test_multi_engine.mojo`.
- **Evidence boundary:** Implements write-safe socket send loop, Content-Length framing, SSE chunk formatting, and chunked transfer encoding; chunk forwarding from active generation engines is tracked under `AES-SRV-004`.
- **Audit:** AER-073, AER-074, AER-075.

### AES-SRV-004 — Raw file-descriptor generation chunk forwarding

- **Status:** `partial`
- **Owner:** facade and server domains
- **Claim sources:** TODO streaming pipeline; server interface
- **Implementation evidence:** `AesirEngine.generate_stream()` reuses canonical generation and sends generated token strings through `send_chunk_static`.
- **Executable evidence:** generation mechanics are covered by `E-REAL`; socket framing is not.
- **Evidence boundary:** Raw writes are not verified Ollama NDJSON, OpenAI SSE, HTTP chunked encoding, backpressure, disconnect cancellation, or safe UTF-8 streaming.
- **Next acceptance gate:** Pick one protocol and pass wire-level chunk, escaping, partial-write, disconnect, cancellation, and final-frame tests.
- **Audit:** AER-011, AER-073 through AER-075.

### AES-SRV-005 — OpenAI REST Gateway & Response Formatter

- **Status:** `verified`
- **Owner:** server protocol domain
- **Claim sources:** multi-engine TODO; server interface
- **Implementation evidence:** `OpenAIGate` in `server/openai.mojo` and `dispatch_http_request()` in `server/api.mojo` formatting valid REST responses for `/v1/chat/completions`, `/v1/models`, and `/v1/embeddings`.
- **Executable evidence:** `E-MASTER` case `server.openai_rest_gateway` in `test_multi_engine.mojo`.
- **Evidence boundary:** Implements OpenAI v1 REST route dispatching, chat completions JSON, SSE chunk framing, model list JSON, and embeddings rejection formatting.
- **Audit:** AER-078, AER-079.

### AES-SRV-006 — OpenAI-compatible REST execution

- **Status:** `missing`
- **Owner:** server and facade domains
- **Claim sources:** completed multi-engine TODO and server interface
- **Implementation evidence:** known OpenAI-shaped routes return HTTP 501 unsupported; no successful response is fabricated.
- **Executable evidence:** `E-MASTER` case `multi_engine.http_unsupported_responses`.
- **Evidence boundary:** Correct HTTP rejection is not OpenAI API execution or conformance.
- **Next acceptance gate:** Parse requests, validate parameters, invoke real generation/embeddings, stream standards-compliant SSE, compute usage, and pass client-level conformance tests.
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

- **Status:** `missing`
- **Owner:** server, CLI, store, and inference domains
- **Claim sources:** README “Ollama API compatible”; CLI serve banners
- **Implementation evidence:** a simple Ollama-shaped terminal response helper exists, but no complete request parsing or endpoint semantics.
- **Executable evidence:** no Ollama client or differential conformance suite.
- **Evidence boundary:** Listening on the conventional port and printing “drop-in” do not establish compatibility.
- **Next acceptance gate:** Define a supported Ollama API version/endpoints and pass real client tests for generate/chat/models/pull/status/errors/streaming.
- **Audit:** AER-069 through AER-081.

### AES-SRV-009 — Concurrent, bounded, secure service operation

- **Status:** `missing`
- **Owner:** service and security domains
- **Claim sources:** server daemon and production implications
- **Implementation evidence:** no real worker pool, request limits, timeouts, auth, TLS, rate limiting, cancellation, or structured observability.
- **Executable evidence:** none.
- **Evidence boundary:** Local-only intent does not eliminate malformed/local-client or network-exposure risks.
- **Next acceptance gate:** Threat model and safe defaults, bounded concurrency/resources, timeouts/cancellation, optional auth/TLS exposure policy, and load/security tests.
- **Audit:** AER-075, AER-077, AER-079, AER-089, AER-107.

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

- **Status:** `simulated`
- **Owner:** facade and embedding domains
- **Claim sources:** RAG integration claims
- **Implementation evidence:** `AesirEngine._prepare_prompt()` uses a constant query tensor rather than model-derived embeddings.
- **Executable evidence:** no real embedding-model comparison.
- **Evidence boundary:** Calling vector search with a predetermined vector is not embedding a query.
- **Next acceptance gate:** Select an embedding model/extraction contract and verify external embedding vectors plus retrieval behavior.
- **Audit:** AER-086.

### AES-RAG-004 — Corpus ingestion, chunking, metadata, and persistence

- **Status:** `missing`
- **Owner:** RAG domain
- **Claim sources:** Mímisbrunnr external knowledge-base claim
- **Implementation evidence:** no document parser, chunker, metadata schema, embedding pipeline, or durable index.
- **Executable evidence:** none.
- **Evidence boundary:** An in-memory primitive does not constitute an external knowledge base.
- **Next acceptance gate:** Reproducible ingestion pipeline, persistent store/index, metadata/citation contract, restart behavior, and external corpus tests.
- **Audit:** AER-084 through AER-087.

### AES-RAG-005 — End-to-end retrieval-augmented generation

- **Status:** `scaffold`
- **Owner:** facade, RAG, and generation domains
- **Claim sources:** TODO Mímisbrunnr and facade interface
- **Implementation evidence:** `_prepare_prompt()` can prepend selected local document text when RAG state is enabled.
- **Executable evidence:** `E-MASTER` explicitly skips `rag.real_engine_integration`; no real external-fixture RAG proof.
- **Evidence boundary:** Constant query embedding and raw text prepend do not establish retrieval quality, context budgeting, citations, or grounded generation.
- **Next acceptance gate:** Real embedding and corpus pipeline, retrieval evaluation, prompt/context budget, citation output, and end-to-end grounded-answer fixture.
- **Audit:** AER-086, AER-087, AER-113.

## 13. Quantization and Compressed Formats

### AES-QNT-001 — Compressed-format discriminants and names

- **Status:** `scaffold`
- **Owner:** core memory/format domain
- **Claim sources:** completed universal compressed-format TODO; core interface
- **Implementation evidence:** `CompressedFormatType` enumerates 21 names and `GGMLType.to_compressed_format` maps some discriminants.
- **Executable evidence:** `E-MASTER` case `quantization.enum`.
- **Evidence boundary:** An enum is not byte-layout parsing, dequantization correctness, loader support, matmul support, or model compatibility.
- **Next acceptance gate:** Retain only explicitly supported formats and connect each to authoritative layouts, fixtures, loader rules, and oracle inference.
- **Audit:** AER-051, AER-054.

### AES-QNT-002 — Q4_K_M block dequantization transformation kernel

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** README q4_k_m and core compute interface
- **Implementation evidence:** `dequantize_q4_k_m` in `core/compute.mojo` performing 32-element Q4_K_M sub-block unpacking (`lower_4` & `upper_4`), `scale * nibble + min_val` affine scaling, zero-blocks safety check (`num_blocks <= 0`), and SIMD store layout.
- **Executable evidence:** `E-MASTER` case `quantization.q4_k_m_dequantization` in `test_quantization.mojo`.
- **Evidence boundary:** Verified Q4_K_M sub-block dequantization transformation math and layout.
- **Audit:** AER-051, AER-052, AER-053.

### AES-QNT-003 — Real quantized-model inference

- **Status:** `missing`
- **Owner:** loader, compute, and inference domains
- **Claim sources:** README q4_k_m support and completed quantized-format TODO
- **Implementation evidence:** real loader rejects quantized types and runtime has no validated quantized matmul/dequant path.
- **Executable evidence:** none with a real quantized model.
- **Evidence boundary:** Synthetic kernel output cannot establish model support.
- **Next acceptance gate:** Real quantized GGUF fixture, exact load/layout, correct compute path, and logits/token parity against pinned `llama.cpp`.
- **Audit:** AER-051 through AER-054.

## 14. Hardware and Multi-Device Execution

### AES-ACC-001 — Host tensor row/column partitioning

- **Status:** `verified`
- **Owner:** core memory/sharding domain
- **Claim sources:** multi-GPU TODO and core interface
- **Implementation evidence:** `shard_split_cols`, `shard_split_rows`, `ShardTensor`, and host list operations form pointer views/copies.
- **Executable evidence:** `E-MASTER` cases `sharding.tensor_descriptor` and `sharding.row_column_partition`.
- **Evidence boundary:** Host memory partitioning only; no device placement, transfer, kernel launch, synchronization, or ownership proof.
- **Next acceptance gate:** Add shape/divisibility/lifetime/capacity checks, then keep device execution as a separately verified capability.
- **Audit:** AER-090, AER-091.

### AES-ACC-002 — Sequential host sharded GEMM and reduction

- **Status:** `verified`
- **Owner:** core compute/sharding domain
- **Claim sources:** multi-GPU TODO and core interface
- **Implementation evidence:** `gemm_f16_sharded` loops across host tensor lists; `all_reduce_sum` performs a host reduction.
- **Executable evidence:** `E-MASTER` cases `sharding.host_all_reduce` and `sharding.host_gemm_parity`.
- **Evidence boundary:** CPU sequential arithmetic, not asynchronous multi-device kernels or a collective.
- **Next acceptance gate:** Validate list lengths/spans and honestly retain host naming; real device work needs separate hardware evidence.
- **Audit:** AER-092, AER-093.

### AES-ACC-003 — Device topology discovery

- **Status:** `missing`
- **Owner:** core hardware domain
- **Claim sources:** NPU/GPU/multi-device TODO matrices and interfaces
- **Implementation evidence:** logical host partitions use `host:N`; NPU/GPU detection clears to empty lists because no platform probe exists.
- **Executable evidence:** `E-MASTER` cases `sharding.logical_host_topology`, `npu.no_fabricated_detection`, and `gpu.no_fabricated_detection`.
- **Evidence boundary:** An honest empty result prevents false discovery but does not implement platform probing.
- **Next acceptance gate:** Platform probes returning only observed/configured devices, capability/error metadata, and physical-hardware tests.
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

- **Status:** `scaffold`
- **Owner:** core hardware/memory domain
- **Claim sources:** completed NPU Realm Gateway TODO; core/facade interfaces
- **Implementation evidence:** `NPUBackendType`, `NPUBuffer`, configuration fields, and dispatch signatures exist.
- **Executable evidence:** `E-MASTER` cases `npu.enum` and `npu.host_buffer_view`.
- **Evidence boundary:** Buffers are host pool pointers with metadata; no DMA-BUF/ION allocation, vendor runtime, device transfer, or NPU memory proof.
- **Next acceptance gate:** Choose one physical backend and implement discovery, allocation/map, transfer/zero-copy contract, kernel invocation, sync, errors, and hardware test.
- **Audit:** AER-095, AER-096.

### AES-ACC-006 — NPU execution dispatch

- **Status:** `missing`
- **Owner:** core compute/hardware domain
- **Claim sources:** completed NPU TODO and runtime ACTIVE banner
- **Implementation evidence:** `gemm_f16_npu` raises an explicit unsupported error for every backend and does not modify output.
- **Executable evidence:** `E-MASTER` cases `npu.host_simd8_parity` and `npu.unsupported_execution`.
- **Evidence boundary:** Host SIMD arithmetic and rejection do not implement NPU execution.
- **Next acceptance gate:** Return explicit unsupported for absent backends; verify one genuine runtime/ISA path on physical hardware against CPU reference.
- **Audit:** AER-095, AER-096, AER-003.

### AES-ACC-007 — GPU realm discriminants and buffer descriptors

- **Status:** `scaffold`
- **Owner:** core hardware/memory domain
- **Claim sources:** completed universal GPU Realm Matrix TODO; core/facade interfaces
- **Implementation evidence:** `GPURealmType`, `GPUBuffer`, configuration fields, and dispatch signatures exist.
- **Executable evidence:** `E-MASTER` cases `gpu.enum` and `gpu.host_buffer_view`.
- **Evidence boundary:** Host pool pointers with CUDA/ROCm/MUSA/etc. labels are not physical GPU allocation or zero-copy device memory.
- **Next acceptance gate:** Pick one backend and implement genuine discovery/allocation/copy/kernel/sync/error contracts with hardware evidence.
- **Audit:** AER-094, AER-095.

### AES-ACC-008 — GPU execution dispatch

- **Status:** `missing`
- **Owner:** core compute/hardware domain
- **Claim sources:** README NVIDIA/Tensor Core optimization; completed GPU matrix; ACTIVE banners
- **Implementation evidence:** `gemm_f16_gpu` and `rmsnorm_gpu` raise explicit unsupported errors for every realm; historically named vector helpers remain host-only experiments.
- **Executable evidence:** `E-MASTER` case `gpu.unsupported_execution` proves rejection without output mutation.
- **Evidence boundary:** No CUDA/ROCm/OpenCL/MUSA/SUPA/MACA/DCU/Metal API, allocation, kernel launch, transfer, synchronization, or physical device is used.
- **Next acceptance gate:** Explicit unsupported behavior for absent backends and one physical GPU vertical slice with CPU parity and hardware CI.
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

## 15. External Ecosystems

### AES-ECO-001 — Hugging Face repository-tag normalization

- **Status:** `verified`
- **Owner:** loader domain
- **Claim sources:** completed Hugging Face TODO and loader interface
- **Implementation evidence:** `HuggingFaceSeer.is_hf_tag` and `normalize_repo_id` recognize and normalize supported string forms.
- **Executable evidence:** `E-MASTER` case `huggingface.tag_parser`.
- **Evidence boundary:** String parsing only; no Hub resolution, revision lookup, auth, metadata, or network access.
- **Next acceptance gate:** Expand a versioned grammar with rejection cases and connect to a real Hub client separately.
- **Audit:** AER-082.

### AES-ECO-002 — Hugging Face resolve-URL construction

- **Status:** `verified`
- **Owner:** loader domain
- **Claim sources:** Hugging Face loader interface
- **Implementation evidence:** `HuggingFaceSeer.build_download_url` constructs the expected resolve URL shape.
- **Executable evidence:** `E-MASTER` case `huggingface.url_builder`.
- **Evidence boundary:** String construction is not URL encoding, revision resolution, authentication, redirect handling, or download.
- **Next acceptance gate:** Define revision/file encoding rules and validate against live authoritative endpoints without upgrading download status.
- **Audit:** AER-082.

### AES-ECO-003 — Hugging Face weight downloading

- **Status:** `missing`
- **Owner:** loader and CLI domains
- **Claim sources:** README/loader comments and completed Hugging Face TODO
- **Implementation evidence:** `download_hf_model()` raises `Hugging Face model download is not implemented` before any success claim.
- **Executable evidence:** `E-MASTER` case `huggingface.download_unsupported`.
- **Evidence boundary:** Rejection proves no fabricated download; it does not transfer or store bytes.
- **Next acceptance gate:** HTTPS streaming, revision/auth/redirect/resume, size/checksum, atomic destination, cancellation, and live/recorded integration tests.
- **Audit:** AER-082, AER-003.

### AES-ECO-004 — ONNX model parsing and execution

- **Status:** `missing`
- **Owner:** loader and optional ecosystem domains
- **Claim sources:** completed multi-engine TODO; loader interface
- **Implementation evidence:** construction reports zero/empty metadata, parsing/mapping return false, and the CLI entry point raises unsupported.
- **Executable evidence:** `E-MASTER` cases `multi_engine.onnx_unavailable` and `multi_engine.cli_unsupported`.
- **Evidence boundary:** No protobuf parse, tensors, operators, graph validation, planner, runtime, or conformance model.
- **Next acceptance gate:** Parse a pinned ONNX fixture, validate graph/tensors/operators, execute a supported graph, and compare outputs with ONNX Runtime.
- **Audit:** AER-081, AER-003.

### AES-ECO-005 — ExLlama/EXL2 conversion and inference

- **Status:** `missing`
- **Owner:** CLI and optional ecosystem domains
- **Claim sources:** completed multi-engine and compressed-format TODOs
- **Implementation evidence:** dispatcher raises an explicit unsupported error and emits no conversion, cache, or completion claims.
- **Executable evidence:** `E-MASTER` case `multi_engine.cli_unsupported`.
- **Evidence boundary:** No EXL2 parser, conversion, CUDA kernels, cache, model, or ExLlama oracle.
- **Next acceptance gate:** Either remove/relabel the unsupported promise with approval or implement a separately scoped real EXL2 fixture and parity gate.
- **Audit:** AER-054, AER-081, AER-003.

### AES-ECO-006 — llama.cpp CLI subcommand compatibility

- **Status:** `missing`
- **Owner:** CLI and optional ecosystem domains
- **Claim sources:** completed multi-engine TODO and CLI interface
- **Implementation evidence:** dispatcher raises an explicit unsupported error and emits no completion, health, benchmark, or perplexity claims.
- **Executable evidence:** `E-MASTER` case `multi_engine.cli_unsupported`.
- **Evidence boundary:** The real pinned oracle comparison verifies Aesir's narrow token output, not llama.cpp CLI argument/output compatibility.
- **Next acceptance gate:** Define supported commands/version and pass differential parsing, execution, output, error, and exit-code fixtures.
- **Audit:** AER-080, AER-081, AER-101.

### AES-ECO-007 — GBNF grammar data path

- **Status:** `scaffold`
- **Owner:** core optional grammar domain
- **Claim sources:** completed multi-engine TODO
- **Implementation evidence:** `GBNFGrammar` owns a state and masks odd token IDs under one condition.
- **Executable evidence:** `E-MASTER` case `multi_engine.grammar_mask` verifies the toy mask.
- **Evidence boundary:** No grammar parser, automaton, tokenizer-aware candidate validation, state transitions, UTF-8 semantics, or reference grammar behavior.
- **Next acceptance gate:** Parse a defined GBNF subset, build/update state, validate token candidates, and compare constrained generation with a reference.
- **Audit:** AER-108.

### AES-ECO-008 — Speculative decoding verifier shape

- **Status:** `scaffold`
- **Owner:** core optional generation domain
- **Claim sources:** completed multi-engine TODO
- **Implementation evidence:** `SpeculativeEngine` checks token identity and one logit threshold.
- **Executable evidence:** `E-MASTER` case `multi_engine.speculative_acceptance`.
- **Evidence boundary:** No draft model, proposal distribution, acceptance ratio, rollback, target/draft KV coordination, or speed/correctness proof.
- **Next acceptance gate:** Two-model algorithm with cache rollback, probability-correct acceptance, deterministic reference sequences, and measured benefit.
- **Audit:** AER-109, AER-110.

## 16. Resilience and Concurrency

### AES-RES-001 — Basic pointer/logit guard helpers

- **Status:** `partial`
- **Owner:** core safety domain
- **Claim sources:** completed resilience TODO
- **Implementation evidence:** `ErrorGuard` checks null pointers and clamps/sanitizes limited logit conditions.
- **Executable evidence:** `E-MASTER` case `resilience.error_guard`.
- **Evidence boundary:** It does not reject sentinel address `1`, validate ownership/span/alignment, protect all loads/stores, or integrate comprehensively into inference.
- **Next acceptance gate:** Boundary-owned validation with unsafe-address/span cases, finite policies, propagation, and coverage across every public unsafe path.
- **Audit:** AER-005, AER-105.

### AES-RES-002 — State checkpoint descriptor

- **Status:** `scaffold`
- **Owner:** core resilience domain
- **Claim sources:** completed resilience TODO
- **Implementation evidence:** `StateVault` stores a few in-memory marker fields.
- **Executable evidence:** `E-MASTER` case `resilience.state_vault_marker`.
- **Evidence boundary:** No serialization, durable storage, model/KV/session snapshot, integrity, compatibility, or restoration.
- **Next acceptance gate:** Versioned durable checkpoint format, atomic writes, complete owned-state boundaries, corruption handling, and restart restoration tests.
- **Audit:** AER-106.

### AES-RES-003 — Event bus state marker

- **Status:** `scaffold`
- **Owner:** core resilience/concurrency domain
- **Claim sources:** completed resilience TODO
- **Implementation evidence:** `AesirEventBus` records a count and last integer/string event state.
- **Executable evidence:** `E-MASTER` case `resilience.event_bus_marker`.
- **Evidence boundary:** No subscribers, delivery, ordering, queue, backpressure, lifetime, synchronization, or inter-module integration.
- **Next acceptance gate:** Explicit publisher/subscriber ownership and delivery semantics with concurrency, ordering, unsubscribe, overflow, and lifetime tests.
- **Audit:** AER-107.

### AES-RES-004 — Worker thread pool

- **Status:** `scaffold`
- **Owner:** core concurrency domain
- **Claim sources:** completed resilience TODO
- **Implementation evidence:** `RuneThreadPool` stores `num_workers`/`is_active`; `parallel_step()` returns the flag.
- **Executable evidence:** `E-MASTER` case `resilience.thread_pool_stub`.
- **Evidence boundary:** No threads, workers, task queue, synchronization, shutdown, errors, or integration.
- **Next acceptance gate:** Real worker lifecycle and bounded queue with task completion, shutdown, race, fault, and service-integration tests.
- **Audit:** AER-089.

### AES-RES-005 — Self-healing crash recovery

- **Status:** `simulated`
- **Owner:** core resilience domain
- **Claim sources:** completed resilience TODO and facade ACTIVE banner
- **Implementation evidence:** `simulate_crash_and_recover()` toggles booleans, publishes marker events, and returns `True` without a real failure boundary.
- **Executable evidence:** `E-MASTER` case `resilience.supervisor_simulation_marker`; runtime output says `SIMULATION ONLY`.
- **Evidence boundary:** No crash, persisted state, engine/KV restoration, socket continuity, retry policy, or process recovery occurs.
- **Next acceptance gate:** Define failure boundaries and inject real recoverable faults; prove state/session continuity or explicit loss semantics across restart.
- **Audit:** AER-106, AER-111, AER-003.

## 17. Swarm and Distributed Execution

### AES-SWM-001 — Peer roles, descriptors, and capacity arithmetic

- **Status:** `scaffold`
- **Owner:** core swarm domain
- **Claim sources:** completed swarm TODO and core interface
- **Implementation evidence:** `SwarmNodeRole`, `PeerNode`, `PeerRegistry`, `TaskDispatcher`, and `SwarmCluster` data structures exist.
- **Executable evidence:** `E-MASTER` cases `swarm.role_enum` and `swarm.peer_metrics`.
- **Evidence boundary:** Local structs and arithmetic do not establish discovery, transport, authenticated peers, liveness, or remote resources.
- **Next acceptance gate:** Separate configured/observed peer state and connect descriptors to an authenticated transport and heartbeat protocol.
- **Audit:** AER-088, AER-114.

### AES-SWM-002 — In-memory least-used/capacity peer selection

- **Status:** `verified`
- **Owner:** core swarm domain
- **Claim sources:** swarm load-balancer interface
- **Implementation evidence:** `PeerRegistry` starts empty and ranks caller-supplied in-memory peer descriptors by available capacity.
- **Executable evidence:** `E-MASTER` case `swarm.registry_load_balancer`.
- **Evidence boundary:** Deterministic selection over caller-provided local records; not live scheduling or distributed load balancing.
- **Next acceptance gate:** Heartbeat-derived metrics, staleness/failure policy, reservations, concurrency, fairness, and multi-process integration.
- **Audit:** AER-114.

### AES-SWM-003 — Mesh join and liveness

- **Status:** `missing`
- **Owner:** core swarm and server domains
- **Claim sources:** completed swarm TODO; CLI/server interfaces
- **Implementation evidence:** clusters start empty/inactive; join raises unsupported and heartbeat returns false.
- **Executable evidence:** `E-MASTER` case `swarm.network_unsupported`; no network peer is contacted.
- **Evidence boundary:** Honest inactive state and rejection are not discovery, handshake, auth, heartbeat, membership, or failure detection.
- **Next acceptance gate:** Authenticated protocol between separate processes, join/leave/heartbeat/timeouts, replay/version policy, and network integration tests.
- **Audit:** AER-114, AER-003.

### AES-SWM-004 — Distributed inference dispatch

- **Status:** `missing`
- **Owner:** core swarm and inference domains
- **Claim sources:** completed swarm TODO
- **Implementation evidence:** both dispatcher and cluster distributed-dispatch entry points raise unsupported errors without creating a result.
- **Executable evidence:** `E-MASTER` case `swarm.network_unsupported`.
- **Evidence boundary:** No model availability, prompt transmission, remote execution, streamed result, cancellation, retry, or failure occurs.
- **Next acceptance gate:** Two-process authenticated transport executing one real request remotely with routing, cancellation, timeout, retry/idempotency, and result validation.
- **Audit:** AER-114.

### AES-SWM-005 — Swarm REST and CLI operational status

- **Status:** `missing`
- **Owner:** CLI and server domains
- **Claim sources:** completed swarm TODO and interfaces
- **Implementation evidence:** swarm CLI commands raise unsupported and swarm HTTP routes return 501; fixed cluster observations were removed.
- **Executable evidence:** `E-MASTER` cases `cli.truthful_command_boundaries` and `multi_engine.http_unsupported_responses`.
- **Evidence boundary:** Fixed tables/JSON are fabricated operational observations.
- **Next acceptance gate:** Derive output from authenticated live cluster state and pass multi-process CLI/API integration and failure tests.
- **Audit:** AER-114, AER-003.

## 18. Benchmarks, Security, and Production Readiness

### AES-OPS-001 — Measured performance benchmarking

- **Status:** `missing`
- **Owner:** performance and CLI domains
- **Claim sources:** llama-bench CLI surface and high-performance README language
- **Implementation evidence:** fixed benchmark/model/perplexity output was removed; the command now raises unsupported.
- **Executable evidence:** `E-MASTER` case `multi_engine.cli_unsupported`; still no benchmark harness exists.
- **Evidence boundary:** Removing fabricated numbers does not create measured performance evidence.
- **Next acceptance gate:** Reproducible benchmark harness with actual work, hardware/software/model metadata, warmup, repeated statistics, correctness guard, and raw results.
- **Audit:** AER-101, AER-003.

### AES-OPS-002 — Resource-efficiency and “run fast/run cold” proof

- **Status:** `missing`
- **Owner:** performance and project documentation domains
- **Claim sources:** README efficiency, maximum hardware use, fast/cold language
- **Implementation evidence:** no measured memory, power, thermal, utilization, latency, throughput, or comparative baseline report.
- **Executable evidence:** none.
- **Evidence boundary:** Architecture intent and absence of a Python hot path do not prove efficiency.
- **Next acceptance gate:** Reproducible measurement plan and comparative results on named hardware/models/workloads with correctness held constant.
- **Audit:** AER-101, AER-102.

### AES-OPS-003 — Security posture for network/model inputs

- **Status:** `missing`
- **Owner:** loader, server, CLI, and distribution domains
- **Claim sources:** local sovereignty/privacy and server/distribution functionality
- **Implementation evidence:** some GGUF range checks exist, but there is no repository-wide threat model, auth/exposure policy, TLS, parser fuzzing, download integrity, or security test gate.
- **Executable evidence:** none sufficient for a security claim.
- **Evidence boundary:** Local execution and AGPL licensing do not make untrusted files or sockets safe.
- **Next acceptance gate:** Threat model, untrusted-input boundaries, secure defaults, fuzzing, auth/exposure decision, integrity verification, dependency review, and incident process.
- **Audit:** AER-037, AER-075, AER-082, AER-107.

### AES-OPS-004 — Runtime observability and diagnosability

- **Status:** `missing`
- **Owner:** runtime and service domains
- **Claim sources:** metrics/health routes and production implications
- **Implementation evidence:** current output is ad hoc `print`; metrics/health payloads are fixed.
- **Executable evidence:** none for structured events, real counters, traces, request IDs, or failure diagnostics.
- **Evidence boundary:** Banners and fixed “healthy” JSON are not observability.
- **Next acceptance gate:** Structured logging levels, real metrics, request/session correlation, error taxonomy, and tests that observed state tracks actual state.
- **Audit:** AER-078, AER-101, AER-111.

### AES-OPS-005 — Production readiness

- **Status:** `missing`
- **Owner:** all domains
- **Claim sources:** any current or future “production” implication
- **Implementation evidence:** a narrow real CPU slice exists, but P0/P1 safety items, external simulations, missing CI/portability/security/concurrency, and fabricated outputs remain.
- **Executable evidence:** no production acceptance program.
- **Evidence boundary:** A passing local build and narrow oracle are essential foundations, not production readiness.
- **Next acceptance gate:** All relevant ledger entries advanced, sustained CI, supported-platform matrix, security/operations/release policy, recovery/load tests, upgrade compatibility, and zero fabricated operational claims.
- **Audit:** AER-002, AER-003, AER-005, AER-100 through AER-115.

### AES-OPS-006 — Documentation-to-evidence consistency

- **Status:** `partial`
- **Owner:** project documentation and every claiming domain
- **Claim sources:** this ledger, README, TODO, visions, architecture, interfaces, runtime banners
- **Implementation evidence:** the reality audit and this canonical ledger now expose verified/partial/scaffold/simulated/missing distinctions.
- **Executable evidence:** ledger validation in Forge 0C; current README/TODO/interfaces still contain broader historical wording.
- **Evidence boundary:** Creating the ledger does not itself correct every runtime message or duplicate document.
- **Next acceptance gate:** Forge 0D removes fabricated operational output; Forge 0E reconciles current README/TODO/vision/architecture/interfaces and installs drift checks.
- **Audit:** AER-003, AER-112, AER-115.

## 19. Claim-Family Coverage Map

| Claim family | Canonical entries |
|---|---|
| Build/runtime foundation | AES-FND-001 through AES-FND-007 |
| Memory/tensor/KV ownership | AES-MEM-001 through AES-MEM-006 |
| CPU kernels and attention | AES-CPU-001 through AES-CPU-008 |
| GGUF loading | AES-LDR-001 through AES-LDR-006 |
| Tokenizer/decoder | AES-TOK-001 through AES-TOK-004 |
| Inference/generation | AES-GEN-001 through AES-GEN-009 |
| CLI/model management | AES-CLI-001 through AES-CLI-009 |
| Server/protocols | AES-SRV-001 through AES-SRV-009 |
| Embeddings/RAG | AES-RAG-001 through AES-RAG-005 |
| Quantization | AES-QNT-001 through AES-QNT-003 |
| Hardware/multi-device | AES-ACC-001 through AES-ACC-009 |
| External ecosystems | AES-ECO-001 through AES-ECO-008 |
| Resilience/concurrency | AES-RES-001 through AES-RES-005 |
| Swarm/distributed | AES-SWM-001 through AES-SWM-005 |
| Benchmarks/security/production | AES-OPS-001 through AES-OPS-006 |

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
   theater to explicit missing/unsupported boundaries; the two remaining
   `simulated` entries are narrowly and visibly labeled local simulations.
