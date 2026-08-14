# Project A.E.S.I.R. Reality Audit and Complete Buildout Report

**Audit date:** August 14, 2026  
**Audit baseline:** `b8a24446d2b174e30e4219b023ccaabcb0e77c64`  
**Audited branch:** `main`  
**Audit mode:** source inspection, build inspection, test-behavior inspection,
real-model verification review, documentation comparison, and repository hygiene
review  
**Primary purpose:** establish an exact, non-promotional record of what is real,
what is partial, what is simulated, what is unsafe, what is unverified, and what
must be built before each advertised capability can honestly be called complete

---

## 1. Executive Verdict

Project A.E.S.I.R. now contains one important, genuine inference foundation:

- a bounds-checked GGUF v3 loader for a narrowly defined Llama F16/F32 model
  profile;
- model-derived architecture configuration;
- direct read-only mmap views for supported F16 matrices;
- one-time F32 normalization-vector conversion;
- model-driven SentencePiece tokenization sufficient for the pinned TinyStories
  reference model and prompt;
- single-device CPU transformer execution with grouped-query attention;
- deterministic argmax generation of one real next token;
- exact first-token parity with a pinned `llama.cpp` reference build; and
- a real `aesir run <gguf-path> <prompt>` single-shot connection.

That foundation is meaningful. It proves that the repository is no longer only
an architectural mockup.

It does **not** validate the majority of the broader capability claims currently
present in `README.md`, `TODO.md`, `ARCHITECTURE.md`, `DATA_FLOW.md`,
`docs/SYSTEM_VISION.md`, interface documents, CLI help, and test banners. Most
of the following remain simulated, partial, CPU-only under hardware-branded
names, structurally incomplete, or unverified against real external systems:

- multi-token production generation;
- sampling controls;
- chat templates and conversation state;
- complete SentencePiece and byte-stream decoding;
- quantized GGUF execution;
- CUDA, ROCm, OneAPI, MUSA, SUPA, MACA, DCU, OpenCL, Hailo, Hexagon, ANE, or
  other accelerator execution;
- real device discovery;
- real multi-GPU sharding and collectives;
- Ollama-compatible persistent model management;
- Hugging Face downloading;
- HTTP request parsing and a persistent serving loop;
- real Ollama, OpenAI, or llama.cpp API compatibility;
- ONNX parsing or execution;
- ExLlama conversion or execution;
- real GBNF constrained decoding;
- speculative decoding;
- embeddings generation and end-to-end RAG;
- actual thread-pool concurrency;
- actual publish/subscribe event delivery;
- crash recovery and KV-cache restoration;
- networked swarm membership, heartbeat, or remote inference;
- production benchmarks; and
- cross-platform support beyond the currently exercised Linux x86-64 Mojo
  environment.

The most urgent engineering problem after multi-token generation is not a new
feature. It is **truth enforcement**: tests, documentation, help text, status
labels, and runtime messages must stop converting scaffolding into apparent
completion.

---

## 2. Audit Standards and Terminology

### 2.1 Capability status labels

| Label | Meaning |
|---|---|
| **Verified real** | Executed against real external data or hardware and compared with an independent oracle or authoritative behavior. |
| **Real but narrow** | Contains genuine functional code, but only for a constrained model, platform, format, or scenario. |
| **Partial** | Some real logic exists, but required correctness, integration, error handling, or coverage is missing. |
| **Scaffold** | Types, names, control flow, or public interfaces exist, but the claimed subsystem does not perform the advertised work. |
| **Simulation** | Returns, prints, or mutates predetermined values without performing the advertised external operation. |
| **Misleading claim** | Documentation, output, naming, or tests imply a stronger result than the code demonstrates. |
| **Unverified** | Code may be plausible, but no adequate test or independent comparison establishes the claim. |

### 2.2 Severity labels

| Severity | Meaning |
|---|---|
| **P0 — truth/safety blocker** | Can corrupt memory, silently report false success, or invalidate the trustworthiness of all downstream claims. |
| **P1 — core capability blocker** | Prevents a central advertised feature from being usable or correct. |
| **P2 — production blocker** | Prevents robust packaging, portability, performance, maintenance, or compatibility. |
| **P3 — quality/debt** | Does not immediately block the verified path but increases confusion, drift, or future failure risk. |

### 2.3 What “parity” means in this report

“Parity” is reserved for comparison against the independent system named in the
claim. Two Project A.E.S.I.R. functions returning the same value on the same CPU
does not establish CUDA, NPU, llama.cpp, Ollama, ONNX Runtime, OpenAI API, or
ExLlama parity.

---

## 3. Audit Basis

The audit reviewed:

- all tracked Mojo source files under `aesir_engine/`;
- the master and domain test modules under `aesir_engine/tests/`;
- the root and per-domain interface documents;
- `README.md`, `TODO.md`, `ARCHITECTURE.md`, `DATA_FLOW.md`, `DEVLOG.md`, and
  their `docs/` counterparts;
- the tracked `aesir_engine/model.gguf` fixture;
- tracked executables and scratch programs;
- both Pixi manifests;
- absolute-path references;
- existing bug records;
- the real-GGUF task contract and completion record; and
- the actual full-suite, real-model, build, and CLI results from the preceding
  verified vertical slice.

Repository facts at the audit baseline:

- 167 tracked files;
- 59 tracked Mojo files, approximately 7,543 lines total;
- 70 tracked Markdown files, approximately 7,349 lines total;
- 22 tracked image files;
- approximately 96 MiB of tracked working-tree content;
- approximately 90 MiB in the packed Git object database;
- no tracked GitHub Actions workflow; and
- multiple tracked Linux x86-64 executable artifacts.

---

## 4. Current Capability Truth Matrix

| Area | Current honest status | Evidence | What is required before “complete” |
|---|---|---|---|
| GGUF v3 Llama F16/F32 load | **Verified real, narrow** | `loader/gguf.mojo`; pinned external integration | More model variants, tied output support, tokenizer variants, fuzzing, portable reads, broader metadata |
| F16 matrix mmap | **Verified real, narrow** | pointer-alias assertion in `test_real_gguf.mojo` | Lifetime hardening and immutable tensor typing |
| F32 norm conversion | **Verified real, narrow** | numeric assertion in `test_real_gguf.mojo` | Precision policy and model coverage |
| SentencePiece prompt encode | **Verified real for one model/prompt** | exact reference IDs | broader corpora, Unicode, byte fallback, normalizer metadata, decode-stream correctness |
| Single next-token CPU inference | **Verified real** | token 265 / ` the` matches pinned oracle | multi-token parity, EOS, stop reasons, sampling, numerical regression corpus |
| Multi-token generation | **Partial and unverified** | `generate_stream()` has a fixed five-step loop | reusable generation state, EOS, max token policy, exact 32-token parity, public result contract |
| Quantized GGUF inference | **Not implemented** | real loader rejects everything except F16/F32 | correct block layouts, quantized matmul/dequant, real quantized fixtures and oracle parity |
| GPU acceleration | **Simulation/mislabeling** | all GPU dispatches call host Mojo SIMD functions | real device APIs, allocations, kernels, synchronization, hardware testing |
| NPU acceleration | **Simulation/mislabeling** | all NPU dispatches call CPU functions | vendor runtimes or genuine ISA/runtime bridges, device buffers, hardware testing |
| Multi-GPU | **CPU list sharding only** | sequential loops over pointer slices | device placement, asynchronous kernels, collectives, synchronization, fault handling |
| RAG | **Vector-store primitive only** | cosine search works; query embedding is constant | ingestion, chunking, embeddings model, persistence, retrieval evaluation, real engine integration |
| Ollama CLI compatibility | **Mostly simulation** | hardcoded catalog and command output | persistent store, actual pull/push/create/show/stop/run semantics, compatibility tests |
| Interactive REPL | **Simulation** | loops over built-in sample prompts | stdin, real engine session, history, controls, cancellation, EOF/signal handling |
| HTTP server | **Socket scaffold** | bind/listen exists; request is discarded | persistent accept loop, parser, routing, engine ownership, response correctness, concurrency |
| OpenAI API | **Formatter scaffold/simulation** | hardcoded IDs, usage, response bodies | request schemas, JSON escaping, model execution, streaming protocol, conformance tests |
| Hugging Face download | **Simulation** | prints URL and returns `True` | HTTPS client/download, revisions, auth, resume, checksum, atomic storage |
| ONNX | **Simulation** | nonempty path produces version 8 and 42 nodes | protobuf parser, tensor/operator graph, execution planner, conformance models |
| ExLlama | **Simulation** | fixed bitrate/cache messages | actual format support or honest removal/relabeling |
| GBNF | **Toy mask** | odd token IDs masked only in one state | grammar parser, tokenizer-aware candidate validation, state machine, oracle tests |
| Speculative decoding | **Toy verifier** | checks only token ID and one logit threshold | draft model, probability acceptance, rollback, cache coordination, speed/correctness tests |
| Self-healing | **Simulation** | `simulate_crash_and_recover()` toggles booleans | failure boundaries, persisted state, KV restoration, socket/session continuity tests |
| Thread pool | **Scaffold** | `parallel_step()` returns `is_active` | actual workers, queues, shutdown, synchronization, integration and race tests |
| Event bus | **State marker, not pub/sub** | stores count and last integer code | subscribers, delivery, ordering, backpressure, lifetime and concurrency semantics |
| Swarm | **In-memory simulation** | seeded peers and formatted dispatch string | protocol, authentication, transport, discovery, heartbeat, scheduling, remote execution |
| Benchmarks | **Fabricated output** | fixed token/s and perplexity strings | measured harness, hardware metadata, warmup, statistics, reproducibility |
| Cross-platform | **Unverified; manifest is Linux-only** | Pixi `platforms = ["linux-64"]`; POSIX FFI | platform abstraction and CI on each claimed platform |

---

## 5. Verified Foundation That Should Be Preserved

The audit is not a claim that everything is fake. These are the pieces that now
deserve protection through regression tests:

1. `GGUFModelConfig` derives context length, hidden width, FFN width, layer
   count, query heads, KV heads, RoPE width, RMS epsilon, and special token IDs
   from validated metadata.
2. `GGUFSeer` rejects invalid magic, unsupported GGUF versions, incomplete
   architecture metadata, invalid alignment, unsupported tensor types,
   out-of-range tensor data, missing tensors, and architecture-incompatible
   tensor shapes.
3. Supported F16 matrices alias the read-only mapped model data rather than
   zero-filled workspace.
4. Required F32 norm vectors are copied and converted once into `MimirWell`.
5. The pinned model's tokenizer produces the exact reference prompt IDs.
6. The CPU path correctly represents 8 query heads and 4 KV heads.
7. The corrected GEMM tail handles the reference model's FFN width of 172.
8. The prompt prefill processes each prompt position into the KV cache.
9. The first greedy token matches the pinned reference.
10. `run_single_shot()` opens the supplied GGUF and executes the engine instead
    of printing the former fixed inference sentence.

Any future refactor must keep these truths explicit and independently testable.

---

## 6. P0 Findings — Truth and Safety Blockers

### AER-001 — The master suite can print `FAIL` and still exit successfully

**Status:** confirmed  
**Severity:** P0  
**Owners:** tests domain; every domain whose tests use print-only failure

Many tests set `success = False`, print a `FAIL` message, and return normally.
`tests/run_all.mojo` then prints `All rites concluded. The engine stands.`
without collecting a failure count or raising. Examples include compute, CLI,
GPU, NPU, quantization, multi-engine, resilience, Hugging Face, and swarm tests.
Some KV-cache failures return early without raising. `test_forward_pass()`
prints `PASS` after obtaining a token but does not assert the expected token.

**Why this matters:** a green process exit does not prove that the output was
green. Automation, contributors, and future agents can mistake a false-green
suite for verified correctness.

**Required buildout:**

- every failed assertion must raise or return a failure consumed by the master
  runner;
- the runner must emit a counted summary and exit nonzero on any failure;
- `PASS` must only be printed after all invariants are checked;
- tests that only exercise labels or formatting must not be titled hardware or
  ecosystem parity tests; and
- skipped tests must be counted separately from passed tests.

**Acceptance gate:** deliberately corrupt one expected value in each test style
and prove the suite exits nonzero; restore the value and prove zero exit.

### AER-002 — `MimirWell.allocate()` returns address `1` on exhaustion

**Status:** confirmed  
**Severity:** P0  
**Owner:** `core/mimir_well.mojo`

The allocator prints a fatal message and returns a pointer constructed from
address `1`. Callers generally treat the result as valid and can immediately
read or write it.

**Why this matters:** pool exhaustion can become a segmentation fault or memory
corruption instead of a controlled error. Exact sizing in the verified model
path lowers the probability but does not remove the unsafe API contract.

**Required buildout:** a checked allocation API that raises before returning an
invalid pointer; validated nonnegative sizes; checked arithmetic; alignment
support; and error propagation through engine construction and generation.

**Acceptance gate:** targeted exhaustion tests must fail deterministically
without dereferencing an invalid address and without corrupting the pool offset.

### AER-003 — Documentation and status records convert scaffolds into completed features

**Status:** confirmed and widespread  
**Severity:** P0  
**Owners:** project documentation, all domains

`TODO.md` marks accelerator matrices, Ollama replacement, compressed formats,
multi-engine parity, self-healing, Hugging Face downloading, and swarm execution
complete. `docs/SYSTEM_VISION.md` presents all fourteen phases as completed.
Runtime banners report validated ONNX mapping, CUDA processing, successful
downloads, healthy clusters, benchmark numbers, and other events that did not
occur.

**Why this matters:** documentation is functioning as false evidence. It makes
prioritization, review, funding, adoption, and debugging unreliable.

**Required buildout:** introduce a capability ledger using the status labels in
this report; downgrade unproved completion markers; link every “verified” claim
to an executable test; and prevent simulated commands from printing operational
success language.

**Acceptance gate:** every major README/TODO/vision/interface claim maps to a
test, is explicitly labeled scaffold/experimental, or is removed with Volmarr's
approval.

### AER-004 — Multi-token generation is not yet a verified state machine

**Status:** partial  
**Severity:** P0 for the next inference milestone  
**Owners:** `aesir.mojo`, `core/inference.mojo`, tokenizer, CLI, tests

`generate()` returns exactly one token. `generate_stream()` loops five times,
but the count is hardcoded, EOS is ignored, stop reasons do not exist, output
token IDs are not returned, byte decoding is incomplete, and the sequence has
not been compared with an oracle. The streaming function is also not connected
to a real request-serving loop.

**Required buildout:** an explicit generation result/state contract; reusable
KV-cache progression; max-new-token configuration; EOS stopping; context
exhaustion stopping; deterministic token ID capture; decoded-text aggregation;
and exact 32-token reference parity.

**Acceptance gate:** the pinned model and prompt must match the pinned
`llama.cpp` sequence for every generated token through token 32, or stop at the
same EOS position and reason.

### AER-005 — Unsafe pointer APIs have incomplete invariants

**Status:** confirmed  
**Severity:** P0/P1 depending on call path  
**Owners:** loader, memory, tensor, cache, compute

`RuneTensor.get()` and `set()` perform no bounds checks. `KVCache.append()` does
not validate layer, position, key width, or value width. Cache slice access does
not validate requested sequence length. Several legacy constructors preserve
address-1 placeholders for empty transformer weights. `ErrorGuard` only checks
that a pointer is nonzero; it does not validate address `1`, alignment, span, or
ownership.

**Required buildout:** checked construction at domain boundaries, internal
invariant validation, removal of sentinel pointers from usable objects, explicit
cache bounds, and fuzz/boundary tests.

**Acceptance gate:** invalid dimensions, layer indices, token positions, and
pool ranges must raise before any unsafe load/store.

---

## 7. Core Inference and Generation Findings

### AER-006 — EOS, BOS, stop-token, and stop-string behavior is incomplete

The loader records BOS/EOS/unknown IDs, but generation only uses BOS. EOS is not
checked during streaming, no additional stop tokens can be configured, stop
strings are not supported, and no stop reason is returned.

**Buildout:** generation configuration, validated token stop set, sequence-aware
stop-string handling, and structured reasons such as `eos`, `length`,
`context_exhausted`, `cancelled`, and `error`.

### AER-007 — Sampling controls are advertised but absent

The CLI manifest and `show` output advertise temperature, top-k, and top-p.
Actual generation always uses deterministic argmax. There is no temperature
scaling, candidate filtering, RNG seed, repetition penalty, frequency/presence
penalty, min-p, typical-p, or sampler composition.

**Buildout:** keep argmax as an explicit deterministic mode; add a separately
tested sampler domain; parse settings from a real configuration/Modelfile; and
compare deterministic seeded sampling against a reference.

### AER-008 — The “Masking Seidr” feature only prints a claim

`permit_seidr` is a local constant. No tokenizer lookup finds
`<|start_thought|>`, no logit is changed, and the value cannot be controlled by
HTTP as the comment claims.

**Buildout:** either implement token discovery and pre-sampling logit masking
with tests or relabel the output as unimplemented. Never print that a
probability was set to negative infinity unless the mutation occurred.

### AER-009 — Hot-path dynamic structures contradict zero-allocation claims

Every `forward_pass()` constructs an `active_blocks` list and copies all
transformer blocks. The multi-device branch creates numerous lists and shard
descriptors. Token lists and decoded strings grow dynamically during generation.
RAG search allocates score/index/result lists.

**Buildout:** define which allocations are initialization-time versus
token-time; reuse blocks directly; preallocate generation buffers where useful;
measure allocations; and narrow “zero allocation” claims to demonstrated
regions.

### AER-010 — Attention is only narrowly validated

The GQA path matched one first token, which is valuable but insufficient for
general numerical confidence. Its online value accumulator is stored in F16
between sequence positions. The legacy `flash_attention_2` test uses identical
Q/K/V values and checks one output element, so many indexing or causality bugs
could pass.

**Buildout:** randomized small-matrix reference tests in F32; causal-mask tests;
GQA/MQA/MHA cases; long-context stability; head mapping tests; and multi-token
oracle parity.

### AER-011 — RoPE configuration is incomplete

The model config validates RoPE dimension, but the compute path uses default
theta and ignores frequency-base, scaling type/factor, original context,
YaRN/linear scaling, and architecture-specific variants.

**Buildout:** parse and validate relevant GGUF keys, represent scaling policy in
model config, and verify positions against supported reference models.

### AER-012 — Output weight tying is unsupported

Some Llama-family GGUF files omit `output.weight` and tie logits to
`token_embd.weight`. The loader currently rejects such a model.

**Buildout:** implement explicit, validated tied-weight fallback only for
architectures/metadata where it is correct; test both tied and untied fixtures.

### AER-013 — Numerical behavior lacks a regression corpus

One tiny F16 model and one prompt do not establish correctness across prompts,
token lengths, logits, layers, or model sizes. The first-token match could hide
later cache or accumulation drift.

**Buildout:** store oracle token sequences and selected logit/checkpoint values
for multiple prompts including empty, Unicode, punctuation, repeated tokens,
near-context-limit, and EOS-producing cases.

### AER-014 — Engine lifecycle and repeated-generation behavior need proof

`generate()` resets the pool offset after a call, but repeated calls, failures
mid-generation, and partially written KV caches are not tested. The engine does
not expose cancellation or reset state explicitly.

**Buildout:** repeated independent generations, failure cleanup, state reset,
and cancellation tests; define whether engine instances are single-session,
multi-session, or stateless between calls.

---

## 8. Tokenizer Findings

### AER-015 — Byte-token decoding drops content

`RuneWeaver.decode()` returns an empty string for `<0xXX>` tokens. That avoids
printing token notation but loses the underlying byte. Multi-token text can be
wrong or empty for byte-fallback output, especially for Unicode split across
multiple tokens.

**Buildout:** a streaming decoder that accumulates byte tokens, validates UTF-8
boundaries, emits replacement/error behavior deliberately, and flushes pending
bytes at termination.

### AER-016 — SentencePiece support is model-specific, not production-general

The current score-priority merge path matches the pinned model. It does not yet
honor all tokenizer metadata, normalization rules, added tokens, control/user
defined token semantics, pre-tokenizer variants, add-EOS flags, or chat
templates. Special-token ID ranges are not fully validated against vocabulary
size during load.

**Buildout:** metadata-driven tokenizer modes; special/control token semantics;
normalizer behavior; comprehensive Unicode and byte tests; and parity corpora
for every supported tokenizer family.

### AER-017 — Decode is token-local instead of sequence-aware

Leading SentencePiece space conversion works for simple pieces, but correct
decoding can depend on adjacent byte tokens, special-token suppression, and
stream boundaries.

**Buildout:** separate token-piece lookup from a stateful detokenizer and expose
both token IDs and final text in generation results.

### AER-018 — The fallback tokenizer behavior is not a model contract

With no vocabulary, `encode()` returns raw byte integers. This is convenient for
synthetic tests but can be mistaken for a usable tokenizer and may produce IDs
outside a model vocabulary.

**Buildout:** keep fallback behavior test-only or explicitly label it; real
engine construction must never reach it.

---

## 9. GGUF Loader and Model Compatibility Findings

### AER-019 — Support is intentionally narrow but surrounding docs overstate it

The real path supports GGUF v3, `llama`, one- or two-dimensional F16/F32 tensors,
and a fixed required tensor family. The system vision still claims direct
Q4_K_M and broad compressed-format loading.

**Buildout:** preserve the narrow fail-closed behavior until each additional
format and architecture has a real fixture and oracle test.

### AER-020 — `inspect_metadata()` maps the model and full load maps it again

Engine construction creates a probe mapping to calculate pool size, then creates
a second `GGUFSeer` and mapping for use. This doubles mapping/open work during
initialization and duplicates parsing.

**Buildout:** a metadata-only read object, transfer/ownership strategy, or one
mapping that survives configuration and tensor construction.

### AER-021 — Portable binary reads are not established

Scalar reads use pointer bitcasts and native loads. The code assumes the host's
endianness and tolerates potentially unaligned reads. This is exercised on Linux
x86-64, not on stricter-alignment or big-endian systems.

**Buildout:** explicit little-endian decoding or documented platform restriction;
alignment-safe reads; and tests on ARM64/macOS/Linux targets.

### AER-022 — Duplicate metadata keys are not rejected

Tensor names are checked for duplicates, but repeated metadata keys can silently
overwrite earlier configuration values.

**Buildout:** track seen keys for required/sensitive metadata and fail on
ambiguous duplicates.

### AER-023 — Tokenizer and architecture metadata validation is incomplete

Vocabulary/score/type counts are checked, but special IDs are not fully range
checked, architecture-specific tensor rules are embedded directly in one loader,
and ignored metadata may materially affect inference.

**Buildout:** architecture adapters or validators, complete special-ID checks,
and a declared ignored-key policy.

### AER-024 — Mapped tensors use a mutable pointer type

The OS mapping is read-only, but `RuneTensor` exposes `set()` over the same
pointer type. An accidental write can fault the process.

**Buildout:** distinguish immutable weight views from mutable activation tensors
at the type or API level.

### AER-025 — No in-runtime identity/checksum verification

The external fixture checksum was verified during the integration run, but the
Mojo test accepts a path and does not calculate or enforce the pinned digest.

**Buildout:** a small trusted checksum utility or external test wrapper; record
actual digest, size, and model identity in integration output.

### AER-026 — Loader failure corpus and fuzzing are missing

The checked-in 24-byte fixture proves one malformed case. There are no committed
fixtures for truncation at every field, invalid array types, oversized lengths,
duplicate names, bad alignment, overlapping ranges, wrong shapes, or unsupported
tensor types.

**Buildout:** minimal non-weight malformed fixtures, mutation/fuzz harnesses, and
sanitizer-assisted runs where the Mojo toolchain permits.

---

## 10. Memory, Tensor, and KV-Cache Findings

### AER-027 — The cache is not PagedAttention

The README describes dynamic paged allocation. `KVCache` is a single contiguous
preallocated K tensor and V tensor. There is no page table, free list, block
manager, shared prefix, eviction policy, or per-sequence page mapping.

**Buildout:** either rename the current cache honestly or implement a real paged
cache as a separate milestone with fragmentation and multi-sequence tests.

### AER-028 — “Ring buffer” wraparound does not preserve chronological slices

`append()` writes `pos % max_seq_len`, but `get_k_slice()` and `get_v_slice()`
always return memory from slot zero. After wraparound, logical token order is not
represented as one contiguous chronological slice.

**Buildout:** prevent wrap and return context exhaustion for the current model,
or implement split/gather chronological views and positional policy.

### AER-029 — Cache and buffer dimensions are unchecked

Negative sizes, zero widths, odd byte sizes, layer overflow, and shape mismatch
can reach unsafe pointer arithmetic. `GPUBuffer`/`NPUBuffer` convert bytes to F16
elements with integer division, silently truncating odd sizes.

**Buildout:** validated constructors and checked arithmetic before allocation.

### AER-030 — NPU/GPU buffer metadata is misleading

`NPUBuffer` defaults `is_dma_buf = True` even when `handle_fd = 0` and the memory
is ordinary host heap memory. `GPUBuffer` is also ordinary `MimirWell` host
memory, not CUDA unified memory, ROCm SVM, Level Zero SVM, OpenCL SVM, or an
Android hardware buffer.

**Buildout:** host buffers must be labeled host buffers. Hardware-backed buffer
types must be created only by successful runtime-specific allocation and expose
real ownership/synchronization handles.

### AER-031 — Pointer-copying structs have lifetime hazards

Several `Copyable` structs duplicate raw pointers without ownership tracking.
This is safe only while the originating pool/mapping outlives every copy and no
copy frees shared memory.

**Buildout:** document borrowing/lifetime rules, minimize copied raw-pointer
owners, and add lifetime tests.

### AER-032 — Memory initialization semantics need explicit verification

`unsafe_memset_zero()` is called with `capacity`; the code assumes the count
matches the intended F16 span. This should be verified against the exact Mojo
standard-library signature/version rather than inferred.

**Buildout:** a full-pool initialization test or explicit byte-count-safe API.

---

## 11. Quantization Findings

### AER-033 — Compressed-format names do not equal format implementations

`CompressedFormatType` enumerates 21 names, but names and dispatch branches are
not evidence of correct layouts.

### AER-034 — Dequantizers use hardcoded scales and simplified packing

Functions such as `dequantize_q2_k`, `dequantize_q3_k`, `dequantize_q4_0`,
`dequantize_q4_1`, GPTQ, AWQ, EXL2, HQQ, and SmoothQuant use fixed scale/min
constants and simplified byte interpretation. Real formats store scales,
zero-points, high bits, group metadata, and format-specific block structures in
the data stream.

### AER-035 — `BlockQ4_K` is not a demonstrated GGML Q4_K block layout

The struct contains one scale, one min, and sixteen packed bytes. No proof shows
binary compatibility with the current GGML `block_q4_K` representation.

### AER-036 — Dispatch collapses distinct formats into the same toy kernel

Q3 variants share one decoder; Q5_0/Q5_1 share one; Q8_0/Q8_1 share one;
GPTQ 4/8 share one; unsupported/default formats fall into Q4_K_M.

### AER-037 — The real loader rejects the formats advertised as supported

`GGUFSeer._tensor_byte_size()` only accepts F16/F32 for the verified slice.
Therefore the format matrix is disconnected from actual model execution.

**Required quantization buildout:**

- use authoritative per-format binary layouts;
- distinguish GGML/GGUF formats from GPTQ/AWQ/EXL2/HQQ container semantics;
- implement correct block-size and type-trait calculations;
- integrate quantized dot/GEMM or validated dequantization;
- reject unknown formats without fallback reinterpretation;
- test real quantized tensors against an independent decoder;
- run full real-model token parity for each advertised format; and
- publish accuracy/performance only after measurement.

---

## 12. Hardware Acceleration Findings

### AER-038 — GPU realms execute on the host CPU

`gemm_f16_gpu()` routes realm labels to `gemm_f16`,
`gemm_f16_gpgpu_vector`, or `gemm_f16_mobile_opencl`. These are Mojo loops over
host pointers. There is no CUDA, HIP, Level Zero, MUSA, SUPA, MACA, DCU, OpenCL,
Metal, or device-runtime interaction.

### AER-039 — NPU realms execute on the host CPU

Hailo and Jetson route to generic CPU GEMM; Hexagon and ANE route to the function
named ARM NEON; no vendor graph/compiler/runtime is used.

### AER-040 — ARM NEON is a lane-width label, not proven ISA dispatch

`gemm_f16_arm_neon()` uses Mojo SIMD width eight and also executes in the x86-64
test environment. No assembly inspection or ARM hardware test demonstrates NEON
instruction generation.

### AER-041 — Device discovery fabricates every backend

`detect_edge_npus()` always appends all six NPU types. `detect_gpu_realms()`
always appends all ten GPU realms. `DeviceTopology(2)` names devices `cuda:0`
and `cuda:1` without detecting CUDA.

### AER-042 — Hardware “parity” tests only compare CPU functions

GPU/NPU tests select labels, run host functions, and compare constant matrices.
No accelerator memory, kernel launch, synchronization, error code, or hardware
counter is involved.

### AER-043 — Multi-device sharding is sequential host execution

`gemm_f16_sharded()` loops over lists sequentially. `all_reduce_sum()` reads
host buffers in one process. There is no device placement, peer transfer,
collective library, stream, event, or overlap.

### AER-044 — Some shard helpers allocate unmanaged heap memory

The `shard_split_cols()` overload without `MimirWell` allocates leaked raw
buffers without an ownership-carrying result type. Tests may free only their
original allocations, not all shard copies.

**Required accelerator buildout:** select one real backend first; implement
runtime discovery, device allocation, transfer/zero-copy policy, one kernel,
synchronization, error propagation, CPU parity, and hardware CI. Other realm
names should remain design targets until separately proven.

---

## 13. RAG and Embeddings Findings

### AER-045 — Retrieval uses a constant query vector

When documents exist, `AesirEngine` fills the query vector with `0.1` rather
than embedding the user's prompt. Retrieval therefore does not reflect semantic
query similarity.

### AER-046 — There is no document ingestion pipeline

No loaders chunk MD/JSON/JSONL/YAML/TXT/CSV/PDF content, no embedding model is
selected, no metadata/source IDs are stored, and no persistence/index format
exists.

### AER-047 — The embeddings endpoints format supplied or hardcoded data

The server does not compute an embedding. `OpenAIGate.format_embeddings()`
returns a fixed four-element vector and fixed usage.

### AER-048 — Retrieval quality is not evaluated

The standalone vector-store test proves identical vectors rank together. It
does not measure semantic retrieval, chunking, source citation, recall, or
context usefulness.

### AER-049 — RAG integration is skipped in the master suite

This skip is honest and preferable to the former swallowed error, but it means
end-to-end RAG is not verified.

**Required buildout:** real embedding generation, document ingestion, metadata,
persistence, query embedding, configurable top-k, context budgeting, source
attribution, retrieval evaluation, and real-model integration tests.

---

## 14. CLI and Model Store Findings

### AER-050 — `RuneModelStore` is an in-memory seeded catalog

Construction inserts three fictional manifests. It does not read
`~/.aesir/models`, `~/.ollama/models`, or any disk catalog despite its docs.
Every CLI invocation creates a fresh store.

### AER-051 — Missing models return fabricated manifests

`get_model()` returns a default `ModelManifest` instead of a not-found error.
This lets `show`, `copy`, and active-process output appear successful for models
that do not exist.

### AER-052 — Pull and push are fixed progress theater

Non-Hugging-Face `pull` and all `push` operations print predetermined digests,
sizes, speeds, and success without network or disk activity.

### AER-053 — Hugging Face pull is also simulated

`download_hf_model()` prints a URL and returns `True`. No file is created,
streamed, verified, resumed, or registered from real metadata.

### AER-054 — Create ignores the requested Modelfile path

The CLI advertises `-f Modelfile`, but uses a built-in sample string. Parsed
Modelfile data is largely discarded by `create_model()`, which writes fixed
digest, size, quantization, and dimensions.

### AER-055 — Show, ps, list, and stop use fixed state

`show` prints Llama/7B/context 4096/temperature/top-k/top-p regardless of the
actual model. `ps` always returns the seeded Aesir manifest and prints `100%
CUDA`. `stop` only prints that unloading occurred.

### AER-056 — Remove reports success even on failure

The command prints `deleted` in both branches. The store also treats exceptions
during removal as success.

### AER-057 — Interactive REPL is a scripted demonstration

It iterates four built-in prompts and prints fixed answers. It does not read
stdin, construct an engine, retain conversation state, apply `/set`, or stream
real tokens.

### AER-058 — CLI error paths generally do not produce process failure

Many commands print an error and return. There is no structured exit-code
contract for invalid arguments, missing models, failed network operations, or
failed server startup.

**Required buildout:** persistent atomic model store, real manifest schema,
actual file operations, honest not-found behavior, real CLI option parsing,
exit codes, stdin REPL, signal handling, and compatibility tests against Ollama
only for the commands actually implemented.

---

## 15. HTTP Server and API Findings

### AER-059 — `serve` does not run a serving loop

The command binds/listens, prints that the daemon is running, then returns.
There is no accept loop in `dispatch_command()`. Object destruction closes the
socket as the process exits.

### AER-060 — Accepted request bytes are discarded

`await_request()` reads up to 1,024 bytes and frees the buffer without parsing a
method, path, headers, body, content length, chunking, or keep-alive state. It
does not call `dispatch_http_route()`.

### AER-061 — Request handling is incomplete and unsafe for real HTTP

There is one fixed read, no partial-read loop, no request-size policy, no header
validation, no body framing, no malformed-request response, no timeout, and no
concurrency model.

### AER-062 — Response sending ignores partial writes and errors

Each send occurs once. Partial sends, interruption, peer closure, SIGPIPE-like
behavior, and retry/error handling are ignored. Responses generally omit
`Content-Length`, connection policy, and correct chunked transfer framing.

### AER-063 — JSON content is not escaped

Prompt/model/response text is concatenated directly into JSON. Quotes,
backslashes, control characters, and invalid UTF-8 can corrupt responses or
permit response injection.

### AER-064 — The server binds differently than it reports

The address bytes are zeroed, which represents an all-interfaces bind for IPv4,
while messages claim `127.0.0.1`. This matters for exposure and security.

### AER-065 — OpenAI/Ollama/llama.cpp routes return fixed bodies

Chat completions, model lists, completion, infill, tokenize, detokenize, health,
metrics, and swarm routes do not invoke real engine/state behavior.

### AER-066 — OpenAI response metadata is fabricated

IDs, timestamps, token usage, embedding values, finish reasons, and model
records are fixed. User text is not escaped. SSE termination and `[DONE]`
semantics are incomplete.

### AER-067 — Transport and engine boundaries are contradictory

Architecture docs say transport is decoupled, but `AesirEngine.generate_stream()`
imports `BifrostGate`, writes chunks, and closes the client descriptor itself.

### AER-068 — Security controls do not exist

There is no authentication, authorization, TLS policy, origin policy, request
limits, model-path sandbox, rate limiting, or audit log. A local-only default
would reduce risk, but the actual bind appears broader.

**Required buildout:** persistent server lifecycle; platform socket abstraction;
incremental parser; robust writes; JSON encoder; route/request schemas; engine
service boundary; cancellation; backpressure; concurrency; conformance tests;
and explicit security posture.

---

## 16. Multi-Engine Compatibility Findings

### AER-069 — llama.cpp CLI commands are simulated

The dispatcher prints fixed completion, server, benchmark, and perplexity
results. It does not parse compatible flags or invoke equivalent engine work.

### AER-070 — Benchmark and perplexity numbers are fabricated

The fixed `1420.5 t/s`, `118.2 t/s`, and `5.4218` values have no measurement
harness, hardware identity, model identity, warmup, token counts, or statistical
basis.

### AER-071 — ExLlama support is a fixed message

No EXL2 parser, converter, calibration, quantization, inference path, or VRAM
cache exists.

### AER-072 — ONNX parsing is a fixed message and constants

A nonempty path makes `parse_onnx_header()` set `num_nodes = 42`. No file is
opened. `map_to_well()` always returns `True`.

### AER-073 — OpenAI formatting tests only check nonempty strings

They do not parse JSON, validate schemas, test escaping, verify usage, or use an
official/client conformance harness.

**Required buildout:** each compatibility target needs a separate scoped task,
real parser/flag behavior, independent conformance fixtures, negative tests, and
honest feature matrices. “Drop-in” must not be used until common clients pass.

---

## 17. Grammar and Speculative Decoding Findings

### AER-074 — GBNF is not parsed

`GBNFGrammar` stores a schema-type string and, only in state 1, masks odd token
IDs for JSON. It does not parse grammar text, map tokens to possible byte
sequences, advance a grammar automaton, or guarantee valid JSON.

### AER-075 — Speculative decoding has no draft model

`SpeculativeEngine` reads draft IDs and one target logit per ID. It does not
sample a draft model, compare distributions, perform acceptance/rejection math,
emit a corrective token, or coordinate target/draft KV caches.

### AER-076 — Claimed acceleration is unmeasured

The stated 3–5× speedup is not backed by a working algorithm or benchmark.

**Required buildout:** tokenizer-aware grammar engine with an oracle test suite;
and a separately designed speculative pipeline with two real models, cache
rollback, statistical correctness, and measured performance.

---

## 18. Resilience, Concurrency, and Recovery Findings

### AER-077 — The event bus is not publish/subscribe

It increments a counter and stores the last event code. It has no subscribers,
payload retention, callback/queue delivery, ordering contract, or concurrency.

### AER-078 — The thread pool has no threads

It stores a thread count and active boolean. `parallel_step()` simply returns
the boolean.

### AER-079 — StateVault does not snapshot KV state

It stores a token position and prompt count only. It does not store pool offsets,
KV contents, RNG state, sampler state, decoded bytes, model identity, or session
metadata.

### AER-080 — The supervisor does not catch real failures

`simulate_crash_and_recover()` toggles booleans and publishes local marker
events. No exception/panic boundary, process supervision, checkpoint restore,
or socket continuity is exercised.

### AER-081 — “100% crash-proof” is indefensible

The facade docstring uses this claim while unsafe pointer operations, unchecked
allocation, and unhandled failures remain.

**Required buildout:** first define recoverable failure classes. Then implement
real lifecycle boundaries, checkpoints, cancellation, worker synchronization,
session ownership, recovery integration tests, and honest residual-risk docs.

---

## 19. Swarm Findings

### AER-082 — Peers are hardcoded local objects

The registry seeds three fictional nodes, IPs, VRAM values, and liveness states.

### AER-083 — Join does not contact a leader

It creates a new local `PeerNode` from the supplied string and returns `True`.

### AER-084 — Heartbeat does nothing

`heartbeat_pulse()` returns `True` without network traffic or timestamps.

### AER-085 — Dispatch does not dispatch inference

It selects the largest hardcoded free-VRAM value and returns a formatted string.
The prompt is unused in the actual task operation.

### AER-086 — Swarm REST and CLI output are fixed

They do not share authoritative cluster state and do not perform authenticated
remote actions.

**Required buildout:** protocol definition, node identity, mutual
authentication, discovery/join, heartbeat timestamps, leases, capability/model
inventory, scheduling, request transport, remote inference, retries,
idempotency, failure handling, observability, and multi-process integration
tests.

---

## 20. Platform and Portability Findings

### AER-087 — Both Pixi manifests are Linux-only

They declare only `linux-64`, while documentation claims Windows, macOS, iOS,
Android, and Raspberry Pi support.

### AER-088 — The runtime uses POSIX symbols directly

`open`, `lseek`, `mmap`, `munmap`, `close`, `uname`, `socket`, `bind`, `listen`,
`accept`, `read`, and `send` are called through raw FFI. The Windows predicate
does not provide Windows implementations of those functions.

### AER-089 — Mobile support is not represented in build tooling

There are no iOS/Android targets, packaging, ABI layers, runtime permissions,
or device tests.

### AER-090 — Hardware claims exceed the build matrix

There is no CI or recorded manual gate for ARM64, NVIDIA GPU, AMD GPU, Apple
Silicon, or mobile devices.

**Required buildout:** explicit supported-platform matrix, platform abstraction,
separate target manifests as required, compile/test CI, and hardware test
reports. Unsupported platforms must be called roadmap targets.

---

## 21. Test Quality Findings by Domain

### Compute tests

- Mostly use constant matrices, which hide indexing and numerical issues.
- Several failures only print.
- Q4_K_M tests validate the repository's invented struct against itself, not
  an authoritative encoded block.
- No randomized F32 oracle, property tests, or invalid-shape tests.

### Loader tests

- The checked-in zero-tensor fixture proves one rejection path.
- The real external test is strong but model-specific.
- No malformed fixture matrix or fuzzing.

### Tokenizer tests

- Synthetic BPE uses default equal scores and a tiny English string.
- Real prompt parity covers one prompt.
- No Unicode/byte-stream decode corpus, special-token behavior, invalid UTF-8,
  or multi-model comparison.

### Inference tests

- The synthetic forward pass uses zero-filled weights and prints whatever token
  wins, normally zero.
- It does not assert logits or output token.
- Real integration checks only the first token at the current baseline.

### KV-cache tests

- Some failure branches return, allowing the suite to continue as if passed.
- No wraparound, context exhaustion, invalid layer, repeated-generation, or
  cache-reuse test.

### Accelerator tests

- They test labels and host-function equality, not hardware.
- Constant inputs and exact F16 comparisons are narrow.

### CLI tests

- They validate seeded fake data and fixed dispatch output.
- No subprocess exit-code, filesystem, stdin, signal, or network behavior.

### API tests

- No real server/client interaction.
- No JSON parse/schema validation.
- No escaping, partial I/O, concurrency, malformed request, or compatibility
  client.

### Resilience and swarm tests

- They validate state toggles and formatted strings, not failures or networking.

### Missing test infrastructure

- no GitHub Actions workflow;
- no coverage report;
- no sanitizer/fuzzer gate;
- no benchmark harness;
- no platform matrix;
- no hardware runner matrix;
- no golden API fixtures; and
- no standardized test result object or counted master summary.

---

## 22. Repository Hygiene and Maintainability Findings

### AER-091 — Compiled Linux binaries are tracked

Tracked executables include root `main`, root `aesir_main`,
`aesir_engine/main`, `aesir_engine/aesir_main`, and `aesir_engine/test`. They are
Linux x86-64 ELF files and undermine source portability and reproducibility.

**Action:** ask Volmarr before deleting them, then replace them with documented
build outputs ignored by Git.

### AER-092 — Numerous scratch programs remain in the source root

`test2.mojo`, `test3.mojo`, `test4.mojo`, `test_buf.mojo`,
`test_callback.mojo`, `test_dict.mojo`, `test_engine.mojo`,
`test_keepalive.mojo`, `test_mojo.mojo`, `test_parse.mojo`,
`test_server_loop.mojo`, `test_sys.mojo`, `test_trait.mojo`, and
`replace_gguf.mojo` are experiments or stale alternative implementations.
Some no longer compile against current APIs. They confuse supported entry points
and can preserve unsafe patterns already fixed elsewhere.

**Action:** classify each as delete, move to an examples/experiments archive, or
convert into a real test; obtain approval before removal.

### AER-093 — Root and `docs/` documentation duplicates have drifted

The paired architecture, data-flow, and devlog files are not identical.
`DEVLOG.md` contains the real-GGUF entry that `docs/DEVLOG.md` lacks. The two
architecture/data-flow versions differ substantially.

**Action:** designate one canonical location and replace duplicates with links
or a documented synchronization process, with approval before removing files.

### AER-094 — Two Pixi workspaces duplicate configuration

Root and `aesir_engine/` each contain a manifest and lock. Both declare Linux
only and include Python despite the runtime's “zero Python dependencies” claim.
Python may be development-only, but that distinction is not documented.

### AER-095 — Absolute/home-relative paths remain in documentation

`docs/REPO_OVERVIEW.md` contains an old `~/AntiGravity_Viking_Longhall/...`
command. Several docs claim interoperability with home-directory stores that do
not exist.

### AER-096 — The 24-byte `model.gguf` name is easy to misuse

The fixture is deliberately malformed and useful for rejection tests, but its
generic production-like name previously caused engine/RAG tests to treat it as
a model.

**Action:** with approval, move/rename it under a fixtures directory and make
its malformed purpose explicit.

### AER-097 — Large image assets dominate repository size

The repository is approximately 96 MiB, mostly images, with several individual
PNG files around 7–10 MiB. This is not a runtime correctness problem, but it
slows cloning and increases Git history cost.

**Action:** consider lossless/lossy optimization or Git LFS policy without
discarding canonical art.

### AER-098 — Logging is almost entirely `print()`

There are no levels, timestamps, structured fields, sinks, quiet mode, or
separation between user output and diagnostics. This conflicts with project
rules and makes API/CLI automation noisy.

### AER-099 — Versioning and capability reporting are static

The CLI prints `0.9.0` and broad suite titles without a build-derived version or
runtime capability detection.

---

## 23. Documentation Corrections Required

The following claims should be changed immediately or gated behind explicit
“design target,” “scaffold,” or “not yet implemented” labels:

- GPU mmap directly into VRAM;
- PagedAttention;
- stateless sampler with temperature/top-p;
- Tensor Core targeting;
- Q4_K_M model support;
- Ollama compatibility/drop-in replacement;
- llama.cpp, ExLlama, and ONNX parity;
- OpenAI SDK parity;
- high-concurrency server;
- real-time streaming through a running server;
- masking of thought-token logits;
- semantic RAG;
- all listed GPU/NPU backends;
- device discovery;
- autonomous swarm execution;
- self-healing and crash-proof operation;
- asynchronous Pub/Sub;
- multi-threaded GEMM;
- Hugging Face downloading;
- fixed benchmark/perplexity numbers;
- sub-millisecond time to first token;
- 80% memory reduction; and
- completed phase markers unsupported by real integration tests.

Documentation should distinguish:

1. **vision** — what A.E.S.I.R. intends to become;
2. **scaffold** — interfaces and names that reserve future architecture;
3. **implemented** — code performs a genuine operation;
4. **verified** — code passed a defined independent gate; and
5. **production-ready** — supported, hardened, documented, and continuously
   tested.

---

## 24. Recommended Build Order

### Forge 0 — Truth enforcement and test semantics

1. Make all tests fail the process when they fail.
2. Add counted pass/fail/skip summary.
3. Introduce the capability ledger.
4. Downgrade simulated completion claims.
5. Stop fabricated runtime success/benchmark output.

### Forge 1 — Verified multi-token CPU generation

1. Add reusable generation state and result contracts.
2. Implement max-new-token policy.
3. Implement EOS and context stop reasons.
4. Fix byte-stream decoding.
5. Preserve deterministic argmax mode.
6. Prove 32-token parity with the pinned oracle.
7. Connect the real CLI to the verified path.

### Forge 2 — Memory and unsafe-boundary hardening

1. Replace address-1 allocation failure.
2. Validate cache/tensor dimensions and spans.
3. Remove usable sentinel-weight objects.
4. Prove repeated generation and failure cleanup.
5. Add malformed GGUF corpus/fuzzing.

### Forge 3 — Tokenizer and GGUF compatibility expansion

1. Stateful byte decoding.
2. Special/control token semantics.
3. Tokenizer metadata modes.
4. RoPE configuration.
5. Tied output weights.
6. Multiple real F16 models and prompts.

### Forge 4 — CPU inference quality and sampling

1. Reference kernel tests.
2. Numerical regression corpus.
3. Sampling stack with deterministic seeds.
4. Chat template support.
5. Measured CPU performance harness.

### Forge 5 — Persistent local model management

1. Real store layout and manifests.
2. Atomic create/copy/remove/show/list/ps state.
3. Honest CLI errors/exit codes.
4. Real stdin REPL and session state.
5. Real HTTP/TLS-based Hugging Face download with checksum.

### Forge 6 — Real HTTP service and one compatibility surface

1. Persistent accept loop and engine service boundary.
2. Robust HTTP/JSON implementation.
3. Choose Ollama or OpenAI first, not both at once.
4. Pass real client conformance tests.
5. Add cancellation, backpressure, and security defaults.

### Forge 7 — Real embeddings and RAG

1. Embedding model path.
2. Ingestion/chunking/persistence.
3. Retrieval evaluation.
4. Context budgeting and citations.
5. End-to-end generation evaluation.

### Forge 8 — One real quantized GGUF format

Implement one authoritative GGML format end-to-end before restoring a matrix of
format claims. Q4_0 or Q8_0 may be a simpler first proof than Q4_K_M.

### Forge 9 — One real accelerator backend

Choose one accessible backend and prove it on hardware. Only after one backend
has a real allocation, kernel, synchronization, and parity path should the
generic accelerator architecture expand.

### Forge 10 — Real multi-device execution

Build on the verified accelerator backend with explicit placement and
collectives. Measure scaling and correctness.

### Forge 11 — Additional ecosystems

ONNX, ExLlama, grammar, speculative decoding, and swarm should each become
separate contracts with independent fixtures and gates rather than one broad
“multi-engine” phase.

### Forge 12 — Real resilience and distributed operation

Add recovery and swarm only after local lifecycle, storage, networking,
concurrency, and session ownership are stable.

---

## 25. Definition of Done for Any Future Capability

A capability may be marked **verified** only when all applicable items are true:

- the runtime performs the advertised operation rather than printing it;
- inputs are parsed and validated;
- outputs are derived from the operation;
- errors are propagated and produce nonzero CLI/test failure where appropriate;
- negative and boundary tests exist;
- at least one real fixture/system/hardware target is exercised;
- an independent oracle or conformance suite is used where one exists;
- the master suite cannot silently swallow failure;
- documentation states the exact supported scope and non-goals;
- no benchmark numbers are published without a reproducible harness;
- interfaces and living docs are updated in the same milestone;
- the worktree is audited for generated artifacts, secrets, and absolute paths;
- the change builds cleanly from source; and
- the exact commit and verification commands are recorded.

A capability may be marked **production-ready** only after the verified gate
plus sustained CI, platform support, observability, security posture, upgrade
behavior, and failure recovery are established.

---

## 26. Immediate Next Task Authorized by This Report

The next forge task is the narrowest extension of the truth-bearing foundation:

> Implement EOS-aware, context-safe, deterministic multi-token generation that
> reuses one KV cache, returns structured token IDs/text/stop reason, and matches
> a pinned `llama.cpp` oracle for up to 32 generated tokens on the pinned
> TinyStories F16 model.

This task must not claim stochastic sampling, chat quality, quantization,
streaming-server compatibility, or accelerator support. It should improve the
real CPU path without inheriting the surrounding simulated claims.

---

## 27. Final Audit Statement

Project A.E.S.I.R. has crossed an important boundary: it possesses a small real
inference core. The correct engineering response is neither to dismiss the
project nor to pretend the full vision already exists. The correct response is
to protect that real core, make every test and document tell the truth, and
expand capability one independently verified vertical slice at a time.

The vision can remain vast. The completion labels must remain exact.
