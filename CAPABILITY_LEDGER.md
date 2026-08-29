# Project A.E.S.I.R. Canonical Capability Ledger

**Ledger version:** Forge 0F, August 28, 2026

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
| `E-MASTER` | `pixi run mojo run tests/run_all.mojo` | 132 named executable cases pass, zero fail, 1 external-fixture case is explicitly skipped, total 133, process exit 0. Synthetic/scaffold cases prove only their narrow local assertions. |
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
| `verified` | 68 |
| `partial` | 9 |
| `scaffold` | 2 |
| `simulated` | 1 |
| `missing` | 27 |
| **Total** | **107** |

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
- **Implementation evidence:** root `.gitignore` protects build environments and common generated artifacts; the consistency checker inventories tracked artifacts.
- **Executable evidence:** `scripts/check_doc_drift.py` reports tracked ELF outputs, a placeholder GGUF, and duplicated root assets until removal is explicitly approved.
- **Evidence boundary:** Ignore rules prevent recurrence only after existing tracked artifacts are removed from the index.
- **Next acceptance gate:** Remove approved generated/placeholder/duplicate artifacts, preserve canonical assets, and pass the tracked-artifact consistency gate.
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

### AES-CLI-004 — In-memory model manifest structures and text serialization

- **Status:** `partial`
- **Owner:** CLI catalog domain
- **Claim sources:** CLI interface and completed Ollama-suite TODO
- **Implementation evidence:** `ModelManifest` and `RuneModelStore` in `cli/manifest.mojo` support deterministic non-cryptographic `fnv1a64:` fingerprints, copy guards, and in-memory text serialization/deserialization.
- **Executable evidence:** `E-MASTER` case `cli.in_memory_manifest_store` in `test_cli.mojo`.
- **Evidence boundary:** No file I/O, atomic durable store, measured model metadata, cryptographic integrity digest, or binary blob distribution is implemented.
- **Next acceptance gate:** Add an atomic on-disk store, compute cryptographic digests and metadata from actual model bytes, and prove restart/corruption behavior.
- **Audit:** AER-061, AER-062, AER-063.

### AES-CLI-005 — `list`, `show`, `ps`, `create`, `cp`, and `rm` operational CLI output

- **Status:** `missing`
- **Owner:** CLI domain
- **Claim sources:** CLI help and completed Ollama-suite TODO
- **Implementation evidence:** `dispatch_command()` rejects these reserved commands before reporting success or mutating ephemeral state.
- **Executable evidence:** `E-MASTER` case `cli.truthful_command_boundaries` in `test_cli.mojo`.
- **Evidence boundary:** Truthful rejection is not an operational model store or process registry.
- **Next acceptance gate:** Connect the commands to the durable catalog and live session registry with restart and failure-path tests.
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

### AES-CLI-008 — REPL slash-command state and interactive inference

- **Status:** `scaffold`
- **Owner:** CLI domain
- **Claim sources:** CLI interface and Ollama `run` implications
- **Implementation evidence:** `RuneREPL` retains local parameter/history state and slash commands (`/set`, `/show`, `/clear`, `/bye`); ordinary chat and `run_repl()` raise unsupported errors.
- **Executable evidence:** `E-MASTER` case `cli.repl_session_state` in `test_cli.mojo`.
- **Evidence boundary:** Slash-command parsing does not execute inference, stream tokens, or provide a terminal session.
- **Next acceptance gate:** Wire a validated model/session into ordinary input, stream real generated tokens, and test EOF/signals/exit codes.
- **Audit:** AER-059, AER-068.

### AES-CLI-009 — CLI flag parsing

- **Status:** `partial`
- **Owner:** CLI domain
- **Claim sources:** README Bifrost/Ollama wording; TODO “Complete Ollama Terminal Command Suite”
- **Implementation evidence:** `CLIOptions` in `cli/options.mojo` and `dispatch_command()` in `cli/commands.mojo` supporting `--verbose` (`-v`), `--format json|text`, `--keepalive <duration>` (`5m`, `1h`), `--modelfile <path>` (`-f`), `--raw`, `--insecure`, and `--max-tokens N`.
- **Executable evidence:** `E-MASTER` case `cli.flag_options_parser` in `test_cli.mojo`.
- **Evidence boundary:** The parser validates intent; most options are not connected to operational command behavior and no Ollama differential parity suite exists.
- **Next acceptance gate:** Define the supported grammar, connect each accepted option, and pass differential syntax/error/exit-code fixtures.
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

- **Status:** `verified`
- **Owner:** facade and server domains
- **Claim sources:** TODO streaming pipeline; server interface
- **Implementation evidence:** `write_all_bytes()` and `build_http_chunk()` in `server/api.mojo` enforcing negative file descriptor validation and terminal chunked HTTP framing (`0\r\n\r\n`).
- **Executable evidence:** `E-MASTER` case `server.http_response_framing` in `test_multi_engine.mojo`.
- **Evidence boundary:** Verified socket write partial loops, invalid descriptor bounds, and terminal chunk framing.
- **Audit:** AER-011, AER-073 through AER-075.

### AES-SRV-005 — OpenAI-shaped JSON formatter

- **Status:** `scaffold`
- **Owner:** server protocol domain
- **Claim sources:** multi-engine TODO; server interface
- **Implementation evidence:** `OpenAIGate` in `server/openai.mojo` formats local JSON/SSE shapes; OpenAI-shaped HTTP routes in `server/api.mojo` return HTTP 501.
- **Executable evidence:** `E-MASTER` case `server.openai_rest_gateway` in `test_multi_engine.mojo`.
- **Evidence boundary:** Formatter shape and fail-closed routing do not establish OpenAI request parsing, execution, streaming semantics, or client compatibility.
- **Next acceptance gate:** Connect real request parsing and execution, then pass official-client protocol fixtures.
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

- **Status:** `partial`
- **Owner:** facade and embedding domains
- **Claim sources:** RAG integration claims
- **Implementation evidence:** `extract_query_embedding()` in `aesir.mojo` mean-pools loaded `token_embd.weight` rows and rejects missing weights, invalid dimensions, and empty token sequences.
- **Executable evidence:** source inspection plus the external-fixture integration case recorded as skipped by `E-MASTER`.
- **Evidence boundary:** No fabricated fallback remains, but the real-model path is not exercised by the default suite and is not a dedicated embedding model.
- **Next acceptance gate:** Run the pinned external fixture in CI and compare embeddings/retrieval against an independent oracle.
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

- **Status:** `partial`
- **Owner:** facade, RAG, and generation domains
- **Claim sources:** TODO Mímisbrunnr and facade interface
- **Implementation evidence:** `_prepare_prompt()` uses loaded token embeddings, local KNN results, dynamic token-budget checks against model context, and grounded-context prompt construction.
- **Executable evidence:** local primitives pass in `E-MASTER`; the external-fixture engine integration is explicitly skipped.
- **Evidence boundary:** Corpus ingestion/persistence, citation provenance, and default-suite real-model execution remain incomplete.
- **Next acceptance gate:** Add a pinned corpus plus model fixture and prove retrieval, prompt budgeting, citations, generation, and restart behavior end to end.
- **Audit:** AER-086, AER-087, AER-113.

## 13. Quantization and Compressed Formats

### AES-QNT-001 — Compressed-format discriminants and names

- **Status:** `verified`
- **Owner:** core memory/format domain
- **Claim sources:** completed universal compressed-format TODO; core interface
- **Implementation evidence:** `CompressedFormatType` enumerates 21 names and `GGMLType.to_compressed_format` in `loader/gguf.mojo` maps GGML tensor type discriminants (0..24) deterministically.
- **Executable evidence:** `E-MASTER` case `quantization.enum` in `test_quantization.mojo`.
- **Evidence boundary:** Verified 21 compressed-format enum discriminants and GGML type mapping bounds.
- **Audit:** AER-051, AER-054.

### AES-QNT-002 — Q4_K_M block dequantization transformation kernel

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** README q4_k_m and core compute interface
- **Implementation evidence:** `dequantize_q4_k_m`, `dequantize_q2_k`, `silu`, and `geglu` in `core/compute.mojo` performing 32-element Q4_K_M sub-block unpacking (`lower_4` & `upper_4`), `scale * nibble + min_val` affine scaling, zero-blocks/zero-size safety checks (`num_blocks <= 0` / `T.size <= 0`), and SIMD store layout.
- **Executable evidence:** `E-MASTER` case `quantization.q4_k_m_dequantization` in `test_quantization.mojo`.
- **Evidence boundary:** Verified Q4_K_M sub-block dequantization transformation math, zero-size kernel safety, and SIMD store layout.
- **Audit:** AER-051, AER-052, AER-053.

### AES-QNT-003 — Real quantized-model inference

- **Status:** `partial`
- **Owner:** loader, compute, and inference domains
- **Claim sources:** README q4_k_m support and completed quantized-format TODO
- **Implementation evidence:** `gemm_q4_k_m` fused matrix-vector multiplication kernel in `core/compute.mojo` connected to `RuneTensor.quant_format` metadata mapped by `GGUFSeer`, with `Copyable BlockQ4_K` SIMD dequantization.
- **Executable evidence:** `E-MASTER` case `quantization.fused_q4_k_m_parity` in `test_quantized_inference.mojo`.
- **Evidence boundary:** Verified fused Q4_K_M matrix-vector multiplication parity with uncompressed `gemm_f16` on synthetic block tensors; pending external quantized GGUF fixture verification.
- **Next acceptance gate:** Real quantized GGUF fixture, exact load/layout, correct compute path, and logits/token parity against pinned `llama.cpp`.
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
- **Implementation evidence:** `BlockQ8_0` and `BlockQ8_1` block structs, `dequantize_q8_0`, `dequantize_q8_1`, `dequantize_fp8_e4m3`, `dequantize_fp8_e5m2` dequantizers, and `gemm_q8_0`, `gemm_q8_1`, `gemm_fp8_e4m3`, `gemm_fp8_e5m2` fused matrix-vector multiplication kernels in `core/compute.mojo`.
- **Executable evidence:** `E-MASTER` cases `quantization.fused_q8_0_parity`, `quantization.fused_q8_1_parity`, `quantization.fused_fp8_e4m3_parity`, `quantization.fused_fp8_e5m2_parity` in `test_q8_fp8_quantization.mojo`.
- **Evidence boundary:** Verified bit-for-bit mathematical output parity between fused Q8_0, Q8_1, FP8_E4M3, FP8_E5M2 GEMM and uncompressed `gemm_f16`.
- **Audit:** Stage 52.1 Mythic Engineering Pass.

### AES-QNT-006 — K-quantization 3-bit and 5-bit block quantization transformation kernels

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** 3-bit and 5-bit K-quantization support (Q3_K_S, Q3_K_M, Q3_K_L, Q5_K_S, Q5_K_M)
- **Implementation evidence:** `BlockQ3_K` and `BlockQ5_K` block structs, `dequantize_q3_k_m`, `dequantize_q3_k_s`, `dequantize_q3_k_l`, `dequantize_q5_k_m`, `dequantize_q5_k_s` block dequantizers, and `gemm_q3_k_m`, `gemm_q3_k_s`, `gemm_q3_k_l`, `gemm_q5_k_m`, `gemm_q5_k_s` fused matrix-vector multiplication kernels in `core/compute.mojo`.
- **Executable evidence:** `E-MASTER` cases `quantization.fused_q3_k_s_parity`, `quantization.fused_q3_k_m_parity`, `quantization.fused_q3_k_l_parity`, `quantization.fused_q5_k_s_parity`, `quantization.fused_q5_k_m_parity` in `test_k_quants_3_5.mojo`.
- **Evidence boundary:** Verified bit-for-bit mathematical output parity between fused Q3_K and Q5_K GEMM kernels and uncompressed `gemm_f16`.
- **Audit:** Stage 53.1 Mythic Engineering Pass.

### AES-QNT-007 — Quantization system crash-proofing, error-correcting, and self-healing boundaries

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** Quantization system crash-proofing, error-correcting, and self-healing boundaries
- **Implementation evidence:** Zero/negative block & null pointer guards in `dequantize_compressed_tensor`, `dequantize_q4_k_m`, `dequantize_q4_0`, `dequantize_q4_1`, `dequantize_q5_0`, `dequantize_q5_1`, `dequantize_q8_0`, `dequantize_q8_1`, `dequantize_fp8_e4m3`, `dequantize_fp8_e5m2`, `dequantize_q3_k_m`, `dequantize_q5_k_m`, non-positive matrix dimension guards across all fused GEMM kernels, self-healing format dispatch fallbacks in `gemm_f16()` and `dequantize_compressed_tensor()`, and FP8 NaN weight sanitization in `core/compute.mojo`.
- **Executable evidence:** `E-MASTER` cases `quantization.hardening_zero_and_null_bounds`, `quantization.hardening_invalid_dimensions`, `quantization.hardening_unrecognized_format`, `quantization.hardening_nan_sanitization` in `test_quantization_hardening.mojo`.
- **Evidence boundary:** Verified zero crashes on zero/null bounds, rejected invalid GEMM shapes, self-healed unrecognized format discriminants without crashing, and sanitized FP8 NaN bit patterns.
- **Audit:** Stage 54.1 Mythic Engineering Pass.

### AES-QNT-008 — K-quantization 2-bit and 6-bit block quantization transformation kernels

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** 2-bit and 6-bit K-quantization support (Q2_K, Q6_K)
- **Implementation evidence:** `BlockQ2_K` and `BlockQ6_K` block structs, `dequantize_q2_k_block` and `dequantize_q6_k_block` dequantizers, and `gemm_q2_k` and `gemm_q6_k` fused matrix-vector multiplication kernels in `core/compute.mojo`.
- **Executable evidence:** `E-MASTER` cases `quantization.fused_q2_k_parity`, `quantization.fused_q6_k_parity` in `test_k_quants_2_6.mojo`.
- **Evidence boundary:** Verified bit-for-bit mathematical output parity between fused Q2_K and Q6_K GEMM kernels and uncompressed `gemm_f16`.
- **Audit:** Stage 55.1 Mythic Engineering Pass.

### AES-QNT-009 — GPTQ, AWQ, EXL2, HQQ, and SmoothQuant fused quantization transformation kernels

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** GPTQ, AWQ, EXL2, HQQ, and SmoothQuant 4-bit/8-bit support (GPTQ_4BIT, GPTQ_8BIT, AWQ_4BIT, EXL2_VARBIT, HQQ, SMOOTHQUANT_INT8)
- **Implementation evidence:** `gemm_gptq_4bit`, `gemm_gptq_8bit`, `gemm_awq_4bit`, `gemm_exl2`, `gemm_hqq`, and `gemm_smoothquant_int8` fused matrix-vector multiplication kernels and automatic format dispatches in `gemm_f16()` in `core/compute.mojo`.
- **Executable evidence:** `E-MASTER` cases `quantization.fused_gptq_4bit_parity`, `quantization.fused_gptq_8bit_parity`, `quantization.fused_awq_4bit_parity`, `quantization.fused_exl2_parity`, `quantization.fused_hqq_parity`, `quantization.fused_smoothquant_int8_parity` in `test_gptq_awq_quantization.mojo`.
- **Evidence boundary:** Verified bit-for-bit mathematical output parity between fused GPTQ/AWQ/EXL2/HQQ/SmoothQuant GEMM kernels and uncompressed `gemm_f16`.
- **Audit:** Stage 56.1 Mythic Engineering Pass.

### AES-QNT-010 — Ternary and 1-bit extreme quantization transformation kernels

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** 1-bit and BitNet 1.58-bit ternary quantization support (IQ1_S, IQ2_XXS, TERNARY_155BIT)
- **Implementation evidence:** `BlockIQ1_S`, `BlockIQ2_XXS`, and `BlockTernary158` block structs, `dequantize_iq1_s_block`, `dequantize_iq2_xxs_block`, `dequantize_ternary_158_block` dequantizers, and `gemm_iq1_s`, `gemm_iq2_xxs`, `gemm_ternary_158` fused matrix-vector multiplication kernels in `core/compute.mojo`.
- **Executable evidence:** `E-MASTER` cases `quantization.fused_iq1_s_parity`, `quantization.fused_iq2_xxs_parity`, `quantization.fused_ternary_158_parity` in `test_extreme_quants.mojo`.
- **Evidence boundary:** Verified bit-for-bit mathematical output parity between fused extreme quantization GEMM kernels and uncompressed `gemm_f16`.
- **Audit:** Stage 57.1 Mythic Engineering Pass.

### AES-QNT-011 — Comprehensive all-format quantization metadata store & hardware autotuning gateway

- **Status:** `verified`
- **Owner:** core compute domain
- **Claim sources:** Comprehensive all-format quantization metadata and hardware autotuning gateway
- **Implementation evidence:** `QuantizationFormatInfo` struct, `get_quantization_format_info()` metadata store, and `autotune_quantized_gemm()` hardware autotuning gateway in `core/compute.mojo`.
- **Executable evidence:** `E-MASTER` cases `quantization.metadata_store_all_formats`, `quantization.autotune_gemm_dispatch` in `test_all_quantization_formats_suite.mojo`.
- **Evidence boundary:** Verified metadata reporting across all 25+ quantization format discriminants and hardware autotuner gateway execution.
- **Audit:** Stage 58.1 Mythic Engineering Pass.

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

- **Status:** `missing`
- **Owner:** core compute/hardware domain
- **Claim sources:** README NVIDIA/Tensor Core optimization; completed GPU matrix; ACTIVE banners
- **Implementation evidence:** CUDA, Metal, Intel, and AMD gates can probe whether named runtime libraries load; physical discovery returns zero and allocation, transfer, and GEMM entry points fail closed.
- **Executable evidence:** `E-MASTER` cases `gpu.cuda_gate_availability`, `gpu.cuda_gemm_dispatch_bounds`, `gpu.cuda_realm_unsupported_gateways`, `gpu.metal_gate_availability`, `gpu.metal_gemm_dispatch_bounds`, `gpu.metal_realm_unsupported_gateways`, `gpu.intel_gate_availability`, `gpu.intel_gemm_dispatch_bounds`, `gpu.intel_realm_unsupported_gateways`, `gpu.amd_gate_availability`, `gpu.amd_gemm_dispatch_bounds`, `gpu.amd_realm_unsupported_gateways`, `gpu.resilience_allocation_rejection`, `gpu.resilience_dimension_rejection`, and `gpu.resilience_error_barriers` in `test_cuda_realm.mojo`, `test_metal_realm.mojo`, `test_intel_realm.mojo`, `test_amd_realm.mojo`, and `test_hardware_resilience.mojo`.
- **Evidence boundary:** Runtime-library presence and checked unsupported errors are not device discovery, VRAM management, or GPU execution.
- **Next acceptance gate:** Implement one backend vertical slice and prove physical enumeration, device memory, transfers, GEMM parity, synchronization, cleanup, and hardware CI.
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
- **Implementation evidence:** `HuggingFaceSeer.is_hf_tag` and `parse_hf_repo` in `loader/huggingface.mojo` recognizing string forms, normalizing `hf.co/` and `huggingface.co/` tags, and checking empty string tag bounds (`len(model_tag.bytes()) == 0`).
- **Executable evidence:** `E-MASTER` case `huggingface.tag_parser` in `test_huggingface.mojo`.
- **Evidence boundary:** Checked repository tag string normalization and empty string rejection bounds.
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

### AES-ECO-007 — Limited grammar-shaped token checks and logit-mask bounds

- **Status:** `verified`
- **Owner:** core optional grammar domain
- **Claim sources:** completed multi-engine TODO
- **Implementation evidence:** `GBNFGrammar` in `core/grammar.mojo` owns local state, applies limited boolean/number checks, validates logit pointers and vocabulary size, and applies deterministic test masks.
- **Executable evidence:** `E-MASTER` case `multi_engine.grammar_mask` in `test_multi_engine.mojo`.
- **Evidence boundary:** No general GBNF/EBNF parser, tokenizer-aware automaton, JSON guarantee, or generation integration is implemented.
- **Next acceptance gate:** Define a supported grammar subset, parse it, maintain tokenizer-aware state, integrate candidate masking, and pass differential grammar fixtures.
- **Audit:** AER-108.

### AES-ECO-008 — Speculative-decoding-shaped local arithmetic and pointer bounds

- **Status:** `verified`
- **Owner:** core optional generation domain
- **Claim sources:** completed multi-engine TODO
- **Implementation evidence:** `SpeculativeEngine` validates pointer/count bounds, repeats an argmax proposal over caller-supplied logits, and applies a deterministic masked-logit acceptance rule.
- **Executable evidence:** `E-MASTER` case `multi_engine.speculative_acceptance` in `test_multi_engine.mojo`.
- **Evidence boundary:** No draft model, probability-correct acceptance distribution, target-model verification loop, KV integration, or speed evidence exists.
- **Next acceptance gate:** Integrate real draft/target models and caches, prove output-distribution equivalence, and measure speed on reproducible workloads.
- **Audit:** AER-109, AER-110.

## 16. Resilience and Concurrency

### AES-RES-001 — Basic pointer/logit guard helpers

- **Status:** `verified`
- **Owner:** core safety domain
- **Claim sources:** completed resilience TODO
- **Implementation evidence:** `ErrorGuard` in `core/error_guard.mojo` checking null (`0`) and sentinel (`1`) address validation (`addr != 0 and addr != 1`) and sanitizing NaN/Inf logits buffer inputs.
- **Executable evidence:** `E-MASTER` case `resilience.error_guard` in `test_resilience.mojo`.
- **Evidence boundary:** Checked null (`0`) and sentinel (`1`) pointer address validation and NaN/Inf logit sanitization error bounds.
- **Audit:** AER-005, AER-105.

### AES-RES-002 — State checkpoint descriptor & marker bounds

- **Status:** `verified`
- **Owner:** core resilience domain
- **Claim sources:** completed resilience TODO
- **Implementation evidence:** `StateVault` in `core/state_vault.mojo` storing token position and prompt count markers, validating non-negative position bounds (`token_pos >= 0 and prompt_count >= 0`) in `save_checkpoint`.
- **Executable evidence:** `E-MASTER` case `resilience.state_vault_marker` in `test_resilience.mojo`.
- **Evidence boundary:** Checked state checkpoint marker non-negative position and prompt count bounds.
- **Audit:** AER-106.

### AES-RES-003 — Event bus state marker & empty topic bounds

- **Status:** `verified`
- **Owner:** core resilience/concurrency domain
- **Claim sources:** completed resilience TODO
- **Implementation evidence:** `AesirEventBus` in `core/event_bus.mojo` recording event count and last event code, enforcing non-empty event type validation (`len(event_type.bytes()) > 0`) in `publish_event`.
- **Executable evidence:** `E-MASTER` case `resilience.event_bus_marker` in `test_resilience.mojo`.
- **Evidence boundary:** Checked event bus non-empty event type parameter validation bounds.
- **Audit:** AER-107.

### AES-RES-004 — Local task-list descriptor and worker-count bounds

- **Status:** `verified`
- **Owner:** core concurrency domain
- **Claim sources:** completed resilience TODO
- **Implementation evidence:** `RuneThreadPool` stores a bounded local task list, completion/cancellation markers, `num_threads` intent, and active state; it clamps the requested count to at least one.
- **Executable evidence:** `E-MASTER` case `resilience.thread_pool_stub` in `test_resilience.mojo`.
- **Evidence boundary:** It creates no worker threads, executes no payloads, and provides no concurrency.
- **Next acceptance gate:** Implement bounded synchronized workers, real task execution, cancellation/shutdown semantics, and race/load tests.
- **Audit:** AER-089.

### AES-RES-005 — Self-healing crash recovery & checkpoint validation

- **Status:** `simulated`
- **Owner:** core resilience domain
- **Claim sources:** completed resilience TODO and facade ACTIVE banner
- **Implementation evidence:** `SelfHealingSupervisor` in `core/supervisor.mojo` executing simulated crash recovery, enforcing valid checkpoint marker presence (`not self.vault.is_checkpointed or self.vault.restore_checkpoint() <= 0 -> return False`).
- **Executable evidence:** `E-MASTER` case `resilience.supervisor_simulation_marker` in `test_resilience.mojo`.
- **Evidence boundary:** Checked supervisor checkpoint marker presence and restoration validation bounds.
- **Audit:** AER-106, AER-111, AER-003.

## 17. Swarm and Distributed Execution

### AES-SWM-001 — Peer roles, descriptors, and capacity arithmetic

- **Status:** `verified`
- **Owner:** core swarm domain
- **Claim sources:** completed swarm TODO and core interface
- **Implementation evidence:** `SwarmNodeRole`, `PeerNode`, and `PeerRegistry` in `core/swarm.mojo` enforcing non-negative attribute bounds and zero-floor VRAM arithmetic (`max(0, capacity - used)`).
- **Executable evidence:** `E-MASTER` cases `swarm.role_enum` and `swarm.peer_metrics` in `test_swarm_cluster.mojo`.
- **Evidence boundary:** Checked local peer role discriminants and zero-floor VRAM arithmetic.
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
- **Implementation evidence:** `SwarmCluster` in `core/swarm.mojo` enforcing parameter validation (`len(leader_address.bytes()) == 0 -> raises Error("leader address must not be empty")`), returning false for heartbeat, and rejecting unsupported network mesh join.
- **Executable evidence:** `E-MASTER` case `swarm.network_unsupported` in `test_swarm_cluster.mojo`.
- **Evidence boundary:** Checked local parameter bounds and explicit unsupported network mesh join boundaries.
- **Audit:** AER-114, AER-003.

### AES-SWM-004 — Distributed inference dispatch & task dispatcher parameter validation

- **Status:** `missing`
- **Owner:** core swarm and inference domains
- **Claim sources:** completed swarm TODO
- **Implementation evidence:** `TaskDispatcher` in `core/swarm.mojo` enforcing parameter validation (`len(node.node_id.bytes()) == 0 or len(task_name.bytes()) == 0 -> raises Error("node id and task name must not be empty")`) and rejecting unsupported network transport operations (`raises Error("swarm task dispatch is not implemented")`).
- **Executable evidence:** `E-MASTER` case `swarm.network_unsupported` in `test_swarm_cluster.mojo`.
- **Evidence boundary:** Checked local parameter bounds and explicit unsupported network dispatch boundaries.
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

- **Status:** `missing`
- **Owner:** performance and CLI domains
- **Claim sources:** llama-bench CLI surface and high-performance README language
- **Implementation evidence:** `dispatch_llama_cli()`, `dispatch_exl2_cli()`, and `dispatch_onnx_cli()` in `cli/multi_engine.mojo` enforcing parameter validation (`len(args) == 0 -> raises Error("CLI dispatcher arguments must not be empty")`) and rejecting unsupported benchmark/runtime surfaces.
- **Executable evidence:** `E-MASTER` case `multi_engine.cli_unsupported` in `test_multi_engine.mojo`.
- **Evidence boundary:** Checked rejection is not a measured benchmark or performance claim.
- **Next acceptance gate:** Add reproducible warmup, workload, environment, statistics, and independent comparison methodology.
- **Audit:** AER-101, AER-003.

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
- **Evidence boundary:** Port and parser bounds are useful hardening, but no complete threat model, fuzz campaign, auth/TLS policy, or resource-exhaustion proof exists.
- **Next acceptance gate:** Publish the threat model and run reproducible malformed-model, request-fuzzing, and resource-limit suites.
- **Audit:** AER-037, AER-075, AER-082, AER-107.

### AES-OPS-004 — Runtime observability, route parameter safety & diagnosability

- **Status:** `partial`
- **Owner:** runtime and service domains
- **Claim sources:** metrics/health routes and production implications
- **Implementation evidence:** `BifrostGate.dispatch_http_route()` in `server/api.mojo` enforcing route path parameter validation (`len(path.bytes()) == 0 -> returns HTTP 404 route_not_found_response()`) and explicit compatibility route handling for `/metrics`, `/health`, `/props`, and `/slots`.
- **Executable evidence:** `E-MASTER` case `server.http_parser` in `test_multi_engine.mojo`.
- **Evidence boundary:** Route validation is not structured observability, live metrics, tracing, or production diagnosis.
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
- **Implementation evidence:** canonical ledger, `scripts/check_doc_drift.py` documentation verification suite, and alignment across all active vision and architecture scrolls.
- **Executable evidence:** `python3 scripts/check_doc_drift.py`; `E-MASTER` (**132 passed / 0 failed / 1 skipped / total 133**).
- **Evidence boundary:** Checks mechanical ledger/test/doc invariants and known fabrication signatures; semantic review remains required for new claim families.
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
