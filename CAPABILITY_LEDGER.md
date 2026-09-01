# Project A.E.S.I.R. Canonical Capability Ledger

**Ledger version:** GPU-9, September 1, 2026

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

Run commands from the repository root unless stated otherwise.

| Evidence key | Command | Establishes |
|---|---|---|
| `E-MASTER` | `pixi run mojo run aesir_engine/tests/run_all.mojo` | 171 named executable cases pass, zero fail, 1 external-fixture case is explicitly skipped, total 172, process exit 0. Synthetic/scaffold cases prove only their narrow local assertions. |
| `E-REAL` | `pixi run mojo run aesir_engine/tests/test_real_gguf.mojo /path/to/stories260K.F16.gguf` | With the pinned external fixture identified below: exact GGUF metadata, F16 mmap alias, F32 norm conversion, tokenizer IDs, first token, 32 greedy token IDs/text, stop reason, context boundary, and pool restoration. |
| `E-BUILD` | `pixi run mojo build aesir_engine/main.mojo -o /tmp/aesir-ledger-build` | Current source compiles into a Linux x86-64 executable in the configured Pixi environment. |
| `E-CLI` | `/tmp/aesir-ledger-build run /path/to/stories260K.F16.gguf --max-tokens 32 One day, Timmy went to` | The built single-shot CLI executes the pinned real model and emits the verified 32-token completion. |
| `E-STORE` | `python3 scripts/test_native_model_store.py --binary /tmp/aesir-ledger-build` | Separate native CLI processes perform empty-start, create/list/show/copy/remove, rollback, permission and symlink checks against a caller-owned temporary catalog. |
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
| `verified` | 70 |
| `partial` | 20 |
| `scaffold` | 1 |
| `simulated` | 0 |
| `missing` | 19 |
| **Total** | **110** |

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
- **Implementation evidence:** `RuneTensor.checked()` validates positive shape dimensions, rejects wrapped products and null/sentinel pointers, and is used by GGUF mapping and public cache pointer admission. The non-raising initializer is an explicitly unchecked internal view primitive. `get_checked` / `set_checked` provide coordinate bounds checks.
- **Executable evidence:** `E-REAL` verifies F16 aliasing; `E-MASTER` case `inference.kv_cache` verifies valid checked construction plus dimension, overflow, sentinel-pointer, and coordinate rejection.
- **Evidence boundary:** Checked admission for untrusted 2D host views; raw internal views and allocation-span/lifetime proof remain caller-owned.
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
- **Implementation evidence:** current `KVCache` is a contiguous preallocated buffer. The reserved `PagedKVCache` API now rejects construction and block operations; no page table, allocator, ownership map, eviction, or page sharing exists.
- **Executable evidence:** `E-MASTER` case `inference.kv_cache` proves `PagedKVCache` construction fails with a stable unsupported error.
- **Evidence boundary:** The fixed contiguous cache rejects capacity overflow; preallocation alone does not implement PagedAttention, sliding windows, or chronological wraparound.
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
- **Implementation evidence:** `TransformerBlock` now rejects missing, empty, null, and address-1 layer weights before construction and its legacy overload always raises. Unsafe loads/stores and sentinel address `1` remain reachable in other unverified domains.
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

- **Status:** `partial`
- **Owner:** loader and quantization domains
- **Claim sources:** README q4_k_m support; completed TODO quantized-format matrix
- **Implementation evidence:** `PackedGGUF` performs bounded metadata and tensor-index parsing for the Gemma 4 E4B and dense Llama 3 8B profiles, admitting their Q4_K/Q5_K/Q6_K/F32/F16/BF16 storage. Architecture-specific core admission validates every required shape before upload.
- **Executable evidence:** pinned Gemma E4B Q4_K_M and Stheno Q4_K_S artifacts were parsed, loaded and executed; each passed 35 independent real-weight quantized matvec checks. See `docs/GEMMA4_CUDA.md` and `docs/STHENO_CUDA.md`.
- **Evidence boundary:** This is not a general quantized-GGUF loader. Established admission is limited to the two documented dense profiles and their tensor layouts.
- **Next acceptance gate:** Per-architecture metadata/layout contracts, additional real fixtures, and independent logits/tokens for each admitted model family.
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
- **Evidence boundary:** One NVIDIA host/toolchain and two documented CUDA profiles; no general CPU sampler integration, cross-device bit identity, optimized throughput, grammar or service integration claim. Full policy and reproduction commands: `docs/NATIVE_RUNTIME.md`.
- **Next acceptance gate:** Larger independent distributions and model-quality evaluations, optimized device selection, model-specific default presets.
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

### AES-CLI-004 — Durable model catalog and incomplete blob store

- **Status:** `partial`
- **Owner:** CLI catalog domain
- **Claim sources:** CLI interface and completed Ollama-suite TODO
- **Implementation evidence:** `AesirConfig.model_store_path` owns the validated relative `.aesir/models` default. `ModelManifest` and `RuneModelStore` in `cli/manifest.mojo` validate model identities and retain deterministic non-cryptographic `fnv1a64:` fingerprints. `DurableModelStore` in `cli/storage.mojo` loads absent stores as empty, uses a bounded/versioned/delimiter-safe catalog, serializes writers with a Linux directory lock, and commits through same-directory stage, file sync, atomic rename, and directory sync.
- **Executable evidence:** `E-MASTER` case `cli.manifest_store_restart` in `test_cli.mojo` proves empty start, validated traversal rejection, version rejection, delimiter-safe content, and create/copy/remove persistence across reconstructed store instances.
- **Evidence boundary:** Catalog durability is implemented for the configured Linux target. The suite does not yet prove separate-process execution, injected write rollback, permission failures, or concurrent processes. Model-byte ingestion, measured metadata, cryptographic integrity digest, content-addressed blobs, and binary distribution remain unimplemented.
- **Next acceptance gate:** Add content-addressed blob ingestion with cryptographic digest and exact byte size, then prove multi-process restart, corruption, permission, rollback, missing-blob, and concurrent-writer behavior.
- **Audit:** AER-061, AER-062, AER-063.

### AES-CLI-005 — `list`, `show`, `ps`, `create`, `cp`, and `rm` operational CLI output

- **Status:** `partial`
- **Owner:** CLI domain
- **Claim sources:** CLI help and completed Ollama-suite TODO
- **Implementation evidence:** Native `list`/`ls`, `show`, `create`, `cp`, `rm`/`delete` commands use `DurableModelStore` and a caller-selected validated config. Output comes from catalog records, JSON strings are escaped, and Modelfile input is bounded and rejects final symlinks. `ps` remains fail closed because no live process registry exists.
- **Executable evidence:** `E-MASTER` catalog cases and `E-STORE`; the latter executes each operation in a separate built-CLI process and checks restart state, JSON, rollback, permissions on native Linux storage, and symlink rejection.
- **Evidence boundary:** These are recipe-catalog operations. They do not ingest or delete model bytes, calculate model-byte SHA-256/size, or report live processes. WSL DrvFS permissions remain governed by the mounted Windows filesystem.
- **Next acceptance gate:** Add content-addressed model-byte ingestion and a real live-session registry before implementing `ps`.
- **Audit:** AER-061, AER-064, AER-066.

### AES-CLI-006 — `pull`, `push`, and `create` operations

- **Status:** `partial`
- **Owner:** CLI and model-distribution domains
- **Claim sources:** CLI help and completed Ollama-suite TODO
- **Implementation evidence:** `pull` is a real built-in public-GGUF downloader with checked argv execution, HTTPS-only redirects, pinning, digest/size validation, optional byte ranges, and atomic exclusive publication. `create` now validates and durably records a Modelfile recipe. `push` remains fail closed.
- **Executable evidence:** `E-MASTER` downloader/catalog admission cases, `E-STORE`, six live integrity/failure checks, and the full pinned Gemma and Stheno artifact downloads through `pull`.
- **Evidence boundary:** Only public, pinned, single-GGUF Linux/WSL downloads are established. Catalog `create` records a recipe and deliberately reports unknown byte metadata; it does not ingest weights. No authentication, resume, upload, or automatic pull-to-store registration exists.
- **Next acceptance gate:** Add authenticated/resumable download, content-addressed weight ingestion, and upload as separate contracts.
- **Audit:** AER-064, AER-082, AER-003.

### AES-CLI-007 — `rm`, `cp`, `stop`, and runtime lifecycle semantics

- **Status:** `partial`
- **Owner:** CLI and runtime domains
- **Claim sources:** CLI help and completed Ollama-suite TODO
- **Implementation evidence:** `cp` and `rm`/`delete` perform locked, restart-safe catalog mutations through staged file sync, atomic replacement and directory sync. `stop` remains unsupported and cannot claim process unload.
- **Executable evidence:** `E-MASTER` durable catalog cases and `E-STORE` separate-process success and rollback checks.
- **Evidence boundary:** Copy/remove mutate recipe manifests only; shared model blobs and live process ownership do not exist yet.
- **Next acceptance gate:** Content-addressed blob reference counting plus a live-session registry with real in-use and stop semantics.
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

- **Status:** `partial`
- **Owner:** CLI domain
- **Claim sources:** README Bifrost/Ollama wording; TODO “Complete Ollama Terminal Command Suite”
- **Implementation evidence:** `CLIOptions` in `cli/options.mojo` records explicit presence for every parsed flag; `dispatch_command()` in `cli/commands.mojo` separates recognized options from model/prompt positionals, validates command applicability, validates and prints caller-selected configuration files, applies CLI acceleration precedence, and rejects non-CPU or non-neutral unconnected intent before model loading. `ConfigJSONParser` enforces the bounded nested schema, JSON strings/Unicode/numbers/booleans, duplicate and unknown-field rejection, section ownership, ranges, EOF, and no trailing commas/content. Parsed options include `--verbose` (`-v`), `--format json|text`, `--keepalive <duration>` (`5m`, `1h`), `--modelfile <path>` (`-f`), `--raw`, `--insecure`, `--max-tokens N`, configuration, acceleration, safety, experimental, and TUI intent.
- **Executable evidence:** `E-MASTER` cases `cli.truthful_command_boundaries`, `cli.flag_options_parser`, and `paradigms.config_and_json`; the CLI case includes compact JSON, escaped section names, exponents, duplicates, structural errors, wrong types/sections, ranges, trailing data and surrogate rejection. Built-CLI smoke tests cover normalized JSON output, default and explicit config loading, missing files, unsupported accelerator rejection, and command-inapplicable options.
- **Evidence boundary:** Configuration validation, option-safe positional parsing, CPU selection, and fail-closed option/config intent are connected. Sampling/safety/experimental application, output formatting, service/model-store option owners, stable exit-code schemas, and Ollama differential parity are not complete; these combinations reject explicitly instead of succeeding without effect.
- **Next acceptance gate:** Connect or reject every remaining accepted option at its owning operation, apply supported sampling/safety configuration to generation, and pass differential syntax/error/exit-code fixtures.
- **Audit:** AER-003, AER-059 through AER-068.

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
- **Evidence boundary:** Legacy tests cover framing and narrow send behavior, not production streaming safety. Live serving uses nonblocking bounded `send_local` with SIGPIPE suppression; no streaming endpoint is exposed.
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

- **Status:** `partial`
- **Owner:** service and security domains
- **Implementation evidence:** The native local service adds strict input limits, owner-only key admission, authentication, loopback-only binding, bounded I/O, cooperative cancellation/deadlines and privacy-preserving request logs.
- **Executable evidence:** `local_service.json`, `local_service.http`, `local_service.request`; `scripts/test_native_service.py` with both real CUDA models.
- **Evidence boundary:** One active stateless request, backlog 8, no parallel scheduling, streaming endpoint, TLS, rate limiter, user quotas, remote access or public production claim.
- **Next acceptance gate:** Sustained load/fuzz/security assessment, explicit multi-client scheduling, deployment lifecycle, and separately tested compatibility protocols.

### AES-SRV-010 — Authenticated native loopback CUDA generation

- **Status:** `verified`
- **Owner:** CLI orchestration, server transport/protocol, facade session contract, core CUDA execution.
- **Implementation evidence:** `cli/native_serve.mojo` invokes `ControlledTextSession` through the facade. `server/local_protocol.mojo` owns bounded HTTP/flat JSON; `server/local_transport.mojo` owns private-file authentication input and nonblocking loopback sockets. `serve` no longer opens and immediately closes the old socket scaffold.
- **Executable evidence:** Both real-model HTTP probes pass at context 512 and max 64 new tokens: authentication/Host/origin checks, observed binding/masks, arithmetic, stateless seeded replay, malformed/oversized requests, slow-client deadlines, prefill recovery, reset-peer handling and active SIGINT/SIGTERM shutdown.
- **Evidence boundary:** Native `/health` and `/v1/generate`, one loaded model, serialized stateless nonstreaming responses, Linux x86-64/NVIDIA. OpenAI/Ollama compatibility and arbitrary device/model support remain unimplemented.
- **Reproduction and threat model:** [Native service guide](docs/NATIVE_SERVICE.md).
- **Native setup hardening:** `keygen` obtains a 256-bit OS-random key and publishes it exclusively through a synced private file in the opened parent directory. The external no-GPU probe verifies exact/Unicode paths, existing-file/symlink preservation, a four-process race and cleanup; hosted CI runs it. Four counted service cases include explicit C-path termination/bounds.

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
- **Executable evidence:** `E-MASTER` case `rag.query_embedding` checks exact mean-pool values and pre-allocation rejection. The engine integration case remains explicitly skipped without a real fixture.
- **Evidence boundary:** No fabricated fallback remains, but the real-model path is not exercised by the default suite and is not a dedicated embedding model.
- **Next acceptance gate:** Run the pinned external fixture in CI and compare embeddings/retrieval against an independent oracle.
- **Audit:** AER-086.

### AES-RAG-004 — Corpus ingestion, chunking, metadata, and persistence

- **Status:** `partial`
- **Owner:** RAG domain
- **Claim sources:** Mímisbrunnr external knowledge-base claim
- **Implementation evidence:** `DocumentChunk` and `chunk_text()` provide deterministic overlapping inline chunks and byte offsets. `ingest_corpus_batch()` transactionally validates caller-supplied embedding matrix shape, store capacity, and non-empty text before copying rows into `MimirStore`; it performs no synthetic embedding generation.
- **Executable evidence:** `E-MASTER` case `rag.corpus_ingestion` checks chunking, real matrix copying, shape rejection, and mutation-free failure.
- **Evidence boundary:** There is no file/document parser, durable index, versioning, update/delete path, embedding service, or provenance-preserving citation store. The byte-window chunker does not yet prove arbitrary UTF-8 boundary safety.
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

Runtime expansion note: CPU raw-byte Q4_K/Q6_K GEMM now matches 25 independent
Stheno row references via `tests/test_cpu_packed_parity.mojo`; output remains
F16 (maximum observed difference 0.00018817186). Q4_K/Q5_0/Q6_K known-value
raw-byte tests assert their results. Legacy SIMD block descriptors and other
synthetic transforms are not proof of general GGUF wire-layout compatibility.

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

- **Status:** `partial`
- **Owner:** core hardware domain
- **Claim sources:** NPU/GPU/multi-device TODO matrices and interfaces
- **Implementation evidence:** `CUDAGate.discover_physical_devices()` uses MAX 26.5 to enumerate every CUDA index and records runtime ID, name, API/version, memory, compatibility, compute capability, multiprocessor count, and thread limit. `DeviceTopology` validates, accumulates, deduplicates, and selects compatible records by realm-local index or runtime-derived stable ID.
- **Executable evidence:** `E-MASTER` cases `gpu.discovery_status_classification`, `gpu.physical_device_admission`, `gpu.discovery_accumulation`, and `gpu.stable_device_selection`; the CUDA Gemma session ran on the observed RTX 4070 Laptop GPU.
- **Evidence boundary:** This proves one MAX CUDA discovery adapter and one observed NVIDIA host. The MAX runtime ID is not a vendor UUID. Other backends and hardware CI remain unverified.
- **Runtime integration:** `hardware list` exposes Linux CPU memory/name and MAX CUDA observations. `compute plan|explain` validates native model buffers and selects a fitting device; both real CUDA sessions recheck memory and honor device selection. Five counted planning cases and `scripts/test_native_planning.py` passed on the RTX host. See `docs/NATIVE_RUNTIME.md` for snapshot, host-staging and unprobed-memory-domain limits.
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
- **Evidence boundary:** Dense text-only E4B Q4_K_M and Llama 3 Stheno Q4_K_S profiles on one observed NVIDIA host. Full-model independent logit parity, long maximum-length generated outputs, arbitrary GGUF models, multimodal/MoE, Tensor Core optimization, multi-GPU and hardware CI are not claimed. Host tokenization/I/O remains on CPU.
- **Llama 3 evidence:** `Llama3CUDASession` implements all 32 layers with native CUDA packed weights, F32 activations and F16 KV. Fifteen independent tokenizer cases and framing passed, including three whole-segment lookup regressions; 35 real-weight dot products and 34,816 CUDA RoPE/SiLU/GQA values matched independent references. Boundary-position RoPE precision was corrected on-device. See `docs/STHENO_CUDA.md` for the final conversation acceptance status.
- **Next acceptance gate:** Broader model/hardware coverage, independent full-model logits, long-generation/context tests and optimized batched prefill.
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

- **Status:** `partial`
- **Owner:** loader and CLI domains
- **Claim sources:** built-in `pull` command
- **Implementation evidence:** Native Mojo orchestration invokes curl and sha256sum with checked argv, HTTPS-only redirects, immutable revision, bounded transfers, optional parallel byte ranges, exact size/SHA-256 verification and atomic exclusive publication.
- **Executable evidence:** `E-MASTER` admission/argv cases; six live download integrity, HTTP-failure and existing-file/symlink protection checks passed with both one and eight connections. Both pinned artifacts in `docs/GEMMA4_CUDA.md` and `docs/STHENO_CUDA.md` downloaded and verified in full through `pull`.
- **Evidence boundary:** Public pinned single-GGUF artifacts on Linux/WSL; no authentication, restart/resume or model-store registration. System curl/sha256sum are explicit dependencies.
- **Next acceptance gate:** Authentication, restart/resume, cancellation/recovery and store integration.
- **Audit:** AER-082, AER-003.

### AES-ECO-004 — ONNX model parsing and execution

- **Status:** `partial`
- **Owner:** loader and optional ecosystem domains
- **Claim sources:** completed multi-engine TODO; loader interface
- **Implementation evidence:** Native Mojo safely opens and read-only maps an ONNX file, decodes bounded protobuf wire data, extracts real IR/producer/default-domain opset metadata, walks `GraphProto.node` entries, counts inputs/outputs, validates UTF-8 and recognizes a declared operator metadata subset. Parsing is transactional; malformed/truncated/overflowing data and unrecognized operators are rejected. Initializer mapping and execution raise unsupported.
- **Executable evidence:** `E-MASTER` cases `onnx.model_seer`, `onnx.recognized_operators`, `multi_engine.onnx_unavailable`, and `multi_engine.cli_unsupported`; the parser case covers in-memory and file-backed valid wire fixtures, truncation, sentinel pointers, state rollback and unknown operators.
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
- **Implementation evidence:** `GBNFGrammar` implements token-text-aware prefix automata for exact JSON booleans and JSON numbers. It tracks committed text and accepting state, masks caller logits only after validating a same-length decoded-token list, rejects null/sentinel pointers and empty/all-invalid candidate sets, and refuses the legacy token-ID-only API.
- **Executable evidence:** `E-MASTER` cases `gbnf.token_validation_masking` and `multi_engine.grammar_mask` cover valid/invalid boolean prefixes, incremental number states, masking, completed-literal rejection, general-JSON refusal and mutation-free legacy rejection.
- **Evidence boundary:** No general GBNF/EBNF parser, JSON object/array grammar, tokenizer-vocabulary adapter, or generation-loop integration is implemented. The class name is broader than this exact two-schema subset.
- **Next acceptance gate:** Parse a versioned GBNF subset, integrate the model tokenizer and generation loop, and pass differential fixtures against an independent grammar implementation.
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
- **Native service evidence:** Per-request sequence, generation phase, HTTP status and elapsed time are recorded without prompts/responses/credentials; authenticated health reports the actually loaded CUDA profile/context. Both real-model service probes verify readiness, generation and shutdown.
- **Legacy implementation evidence:** `BifrostGate.dispatch_http_route()` in `server/api.mojo` enforcing route path parameter validation (`len(path.bytes()) == 0 -> returns HTTP 404 route_not_found_response()`) and explicit compatibility route handling for `/metrics`, `/health`, `/props`, and `/slots`.
- **Executable evidence:** `E-MASTER` case `server.http_parser` in `test_multi_engine.mojo`.
- **Evidence boundary:** The native service has narrow request logs and readiness. Legacy route validation still does not establish metrics, tracing, persistent audit storage or broad production diagnosis.
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
| Build/runtime foundation | AES-FND-001 through AES-FND-007 |
| Memory/tensor/KV ownership | AES-MEM-001 through AES-MEM-006 |
| CPU kernels and attention | AES-CPU-001 through AES-CPU-008 |
| GGUF loading | AES-LDR-001 through AES-LDR-006 |
| Tokenizer/decoder | AES-TOK-001 through AES-TOK-004 |
| Inference/generation | AES-GEN-001 through AES-GEN-009 |
| CLI/model management | AES-CLI-001 through AES-CLI-009 |
| Server/protocols | AES-SRV-001 through AES-SRV-010 |
| Embeddings/RAG | AES-RAG-001 through AES-RAG-005 |
| Quantization | AES-QNT-001 through AES-QNT-003 |
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
