# Project A.E.S.I.R. Reality Audit and Complete Buildout Report

**Audit date:** August 14, 2026  
**Audit baseline:** `b8a24446d2b174e30e4219b023ccaabcb0e77c64`  
**Function-level re-audit baseline:** `04d10575763997d337a0804c9ae55914cba5359b`
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
- deterministic, EOS-aware, context-safe greedy generation with one reused KV
  cache per request;
- exact 32-token parity with a pinned `llama.cpp` reference build; and
- a real `aesir run <gguf-path> <prompt>` single-shot connection.

That foundation is meaningful. It proves that the repository is no longer only
an architectural mockup.

It does **not** validate the majority of the broader capability claims currently
present in `README.md`, `TODO.md`, `ARCHITECTURE.md`, `DATA_FLOW.md`,
`docs/SYSTEM_VISION.md`, interface documents, CLI help, and test banners. Most
of the following remain simulated, partial, CPU-only under hardware-branded
names, structurally incomplete, or unverified against real external systems:

- stochastic or production-general multi-token generation;
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
| Single next-token CPU inference | **Verified real** | token 265 / ` the` matches pinned oracle | broader model/prompt corpus and numerical regression data |
| Deterministic multi-token generation | **Verified real, narrow** | exact 32-token ID/text parity; EOS/length/context policy; 128-token boundary test | stateful byte decoding, more EOS/model fixtures, failure cleanup, cancellation, stop strings, sampling |
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
9. The complete 32-token greedy sequence matches the pinned reference.
10. A full-context request stops before evaluating an out-of-range position.
11. `run_single_shot()` opens the supplied GGUF and executes the engine instead
    of printing the former fixed inference sentence.

Any future refactor must keep these truths explicit and independently testable.

---

## 6. P0 Findings — Truth and Safety Blockers

### AER-001 — Master-suite failure and counted-reporting semantics

**Status:** resolved by Forge 0A and Forge 0B
**Severity:** closed P0 verification-infrastructure milestone
**Owners:** tests domain; every domain whose tests use print-only failure

Forge 0A converted every identified terminal print-only failure and both
KV-cache early-return failures into raised errors, propagated `raises` through
the affected call graph, and added a deterministic assertion to
`test_forward_pass()`.

Forge 0B added one tests-domain ledger and registered 49 executable named cases
plus one explicit external-fixture skip. Each case is caught and recorded at its
own boundary, so later cases continue after a failure. The runner prints unique
`[CASE ...]` lines, ordered failure details, and `[SUMMARY]` pass/fail/skip/total
keys. It raises after the summary if any case failed or the expected total is
wrong.

The deliberate F16 expectation mutation produced 48 passed, 1 failed, 1
skipped, and 50 total; the final swarm case still executed; and the process
exited 1 only after the summary. Exact restoration produced 49/0/1/50 and exit
0. Historical hardware/ecosystem titles and internal banners still overstate
what their synthetic checks prove, but that evidence-labeling debt is tracked
by AER-003 and AER-112 rather than by runner mechanics.

**Why this matters:** a green process exit does not prove that the output was
green. Automation, contributors, and future agents can mistake a false-green
suite for verified correctness.

**Completed buildout:**

- every failed assertion raises or propagates a
  failure to the master runner;
- the runner emits a counted summary and exits nonzero on any failure;
- `PASS` is printed only
  after the function's asserted invariants are checked;
- skipped tests are counted separately from passed tests; and
- a failure does not prevent later named cases from running.

**Remaining adjacent truth work:** Forge 0C/0D must correct capability titles,
completion labels, and simulated success language. Those changes must not be
misdescribed as runner-semantics work.

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

### AER-004 — Deterministic multi-token generation state machine

**Status:** resolved for the pinned deterministic F16 slice; broader generation remains partial
**Severity:** closed P0 milestone with remaining P1/P2 refinements
**Owners:** `aesir.mojo`, `core/inference.mojo`, tokenizer, CLI, tests

Commit `aad4c08` added `GenerationResult`, a canonical
`AesirEngine.generate_tokens()` loop, a single reused request KV cache,
model-EOS handling, stable `eos`/`length`/`context_exhausted` reasons, generated
token IDs, exact 32-token oracle parity, one-token regression coverage, and a
real context-boundary proof. `generate()` and `generate_stream()` now reuse the
same token mechanics.

**Remaining buildout:** stateful byte decoding, model-produced EOS fixtures,
failure/cancellation cleanup, configurable stop-token sets and stop strings,
stream-safe JSON escaping, sampling, chat templates, and server integration.

**Acceptance achieved:** all 32 pinned token IDs and exact decoded text matched
the pinned `llama.cpp` oracle; a 128-token prompt stopped without evaluating
position 128.

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

The loader records BOS/EOS/unknown IDs. The canonical generation loop now uses
model-controlled BOS, checks model EOS, excludes EOS from visible text, and
returns stable stop reasons. No additional stop tokens can be configured, stop
strings are not supported, byte-stream flush semantics remain incomplete, and
the pinned fixture does not naturally exercise a generated EOS.

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

Repeated independent calls and runtime-offset restoration now have real-model
coverage. Failures mid-generation can still bypass the final pool reset,
partially written KV state is not explicitly invalidated, streaming failure can
leave a client unclosed, and the engine does not expose cancellation or an
explicit reset contract.

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

### Forge 1 — Verified multi-token CPU generation — **completed narrowly**

1. Add reusable generation state and result contracts.
2. Implement max-new-token policy.
3. Implement EOS and context stop reasons.
4. Fix byte-stream decoding. **Still open; not required by the pinned emitted sequence.**
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

The completed multi-token milestone exposed the original prerequisite still
blocking trustworthy work. The next forge task is:

> Make every master-suite test fail closed: replace print-only `FAIL` branches
> and early-return failures with raised errors, preserve legitimate skips as
> explicit skips, and prove that an intentionally corrupted expectation makes
> the process exit nonzero.

This is Forge 0A. A counted aggregate test summary, capability ledger, and
runtime-claim cleanup remain subsequent Forge 0 slices rather than being
silently bundled into one unreviewable change.

---

## 27. Original Audit Closing Statement

Project A.E.S.I.R. has crossed an important boundary: it possesses a small real
inference core. The correct engineering response is neither to dismiss the
project nor to pretend the full vision already exists. The correct response is
to protect that real core, make every test and document tell the truth, and
expand capability one independently verified vertical slice at a time.

The vision can remain vast. The completion labels must remain exact.

---

## 28. Function-Level Re-Audit Addendum

This addendum updates the original baseline after the verified multi-token
milestone and performs the function-level accounting requested by Volmarr. The
re-audit enumerated every `def`/`fn` declaration in tracked Mojo source at commit
`04d1057`:

| Classification | Functions and methods reviewed |
|---|---:|
| Runtime and public source (`aesir`, `core`, `loader`, `server`, `cli`, `main`) | 270 |
| Test-domain functions and test entry points | 60 |
| Legacy/scratch/replacement programs | 35 |
| **Total declarations inventoried** | **365** |

Forge 0B subsequently added eight complete test-harness declarations in
`test_ledger.mojo`: six `TestLedger` methods plus `run_case` and `record_skip`.
The current tracked census is therefore 270 runtime/public declarations, 68
test-domain declarations, and 35 legacy/scratch declarations: **373 total**.
These eight additions implement verified reporting infrastructure and are not
open buildout findings.

The ledger below lists every declaration or tightly coupled declaration group
for which this pass found missing behavior, incomplete behavior, a correctness
bug, unsafe preconditions, misleading semantics, inadequate error propagation,
or material refinement work. Constructors and mechanical copy/equality methods
are grouped when they share one invariant defect. A function not listed here is
not thereby declared production-ready; it means this static pass found no
specific additional defect beyond its owning subsystem's existing findings.

### 28.1 Status changes since the original audit

- AER-004 is resolved for the pinned deterministic F16 CPU slice.
- AER-006 is partially resolved: model EOS and stable reasons exist, but custom
  stops, stop strings, byte-stream flush, and natural EOS fixtures do not.
- AER-014 is partially resolved: repeated successful generation and pool-offset
  restoration are covered, but exception/cancellation cleanup is not.
- Forge 1 is complete except for stateful byte decoding, which the pinned token
  sequence did not exercise.
- Forge 0 remains incomplete and is again the highest-priority trust boundary.
- Forge 0A and Forge 0B are now complete; Forge 0C is the next truth boundary.
- At `04d1057`, `TODO.md` regressed the verified multi-token record by removing
  the completed milestone and reintroducing an older statement that EOS and
  context handling were missing. Forge 0A corrected that record.

## 29. New and Refined Findings

### AER-100 — The current TODO regresses a verified capability back to “missing”

**Status:** resolved after confirmation at `04d1057`
**Severity:** closed P0 documentation regression
**Owner:** project documentation

`TODO.md` removed the completed deterministic multi-token milestone and restored
an older future item saying multi-token generation still needs EOS and context
handling. Both behaviors now exist and passed the pinned integration gates.

**Resolution:** the narrow verified record is restored while sampling, chat,
byte-stream decoding, and production-general behavior remain open work.

### AER-101 — Generation cleanup is not exception-safe

**Status:** confirmed
**Severity:** P0/P1 safety and lifecycle blocker
**Owners:** `AesirEngine._prepare_prompt`, `_run_generation`,
`generate_stream`, `TransformerBlock.forward`, both `forward_pass` overloads

Pool offsets are restored only on normal completion. Any error during RAG
augmentation, tokenization, allocation, a transformer layer, final projection,
decoding, or streaming can bypass restoration. `generate_stream()` closes the
client only after successful generation. Partially written KV state has no
invalid/aborted marker.

**Buildout:** introduce scoped offset guards or explicit `try`/cleanup paths;
close streaming clients on every terminal path; make request state ownership
explicit; add injected-failure tests at prefill, decode, projection, and send.

### AER-102 — Allocation and dimension arithmetic can overflow or move backwards

**Status:** confirmed
**Severity:** P0 memory-safety blocker
**Owners:** `calculate_runtime_pool_bytes`, `MimirWell.__init__`,
`MimirWell.allocate`, `RuneTensor.__init__`, `KVCache.__init__`, buffer and store
constructors, GGUF tensor-size calculations, shard allocation helpers

Negative element counts are not rejected. `offset + elements`, `rows * cols`,
layer/context products, and byte-size products can overflow before bounds are
checked. A negative allocation can move the pool offset backwards and create an
alias into already-owned storage.

**Buildout:** checked nonnegative arithmetic at every public memory boundary,
overflow-before-multiply checks, alignment-aware capacity calculations, and
negative/zero/near-maximum tests.

### AER-103 — Unknown discriminants silently become valid-looking backends or formats

**Status:** confirmed
**Severity:** P1 correctness/truth blocker
**Owners:** `NPUBackendType`, `GPURealmType`, `CompressedFormatType`,
`GGMLType.to_compressed_format`, GPU/NPU/dequant dispatch functions

Unknown NPU values print `GENERIC_NPU`; unknown GPU values print `GENERIC_GPU`;
unknown compressed-format values print `SMOOTHQUANT_INT8`; and unknown GGML
types map to `Q4_K_M`. Dispatch then executes a fallback CPU or toy kernel.
Invalid configuration is therefore converted into plausible but false success.

**Buildout:** validated constructors or explicit `UNKNOWN`/error results; reject
unknown GGML types; never route unsupported formats through a different format.

### AER-104 — Core kernels trust incompatible tensor shapes and spans

**Status:** confirmed
**Severity:** P0/P1 depending on caller
**Owners:** all GEMM, attention, normalization, RoPE, activation, similarity,
dequantization, sharding, and reduction kernels

The kernels receive raw pointer descriptors but generally do not validate
dimensions, divisibility, output capacity, pointer validity, sequence lengths,
head mappings, or packed-input byte counts. Representative failures include
division by zero in RMSNorm, out-of-range width-16 vector access in
`flash_attention_2`, an odd `head_dim` read in `apply_rope`, a zero
`query_heads_per_kv` divisor in `flash_attention_gqa`, and silent truncation of
odd or non-block-aligned dequantization requests.

**Buildout:** checked boundary wrappers and invariant-bearing internal kernels;
exact packed-byte contracts; scalar tails where mathematically valid; explicit
rejection where they are not; randomized reference tests and sanitizers.

### AER-105 — The multi-device transformer path is mathematically invalid for GQA

**Status:** confirmed by source inspection; not exercised by a real device
**Severity:** P1 core correctness blocker
**Owner:** `TransformerBlock.forward` multi-device branch

The branch assumes Q, K, and V shard widths all equal `x.cols / num_devices`,
even though GQA K/V width is `kv_dim`, not the hidden width. It allocates full K
and V using `x.size`, reconstructs only one row's shard indices, feeds sharded
tensors to legacy attention with unchecked head divisibility, and uses host
lists rather than device placement. The verified model itself has 8 query heads
and 4 KV heads, so this assumption is structurally wrong for the project's own
reference architecture.

**Buildout:** disable/reject the branch until a separate real multi-device
contract exists, or rebuild it from explicit Q/K/V layouts, device ownership,
collectives, synchronization, and oracle parity.

### AER-106 — GGUF parsing has re-entry, duplicate-key, and integer-conversion gaps

**Status:** confirmed
**Severity:** P1 loader hardening blocker
**Owners:** `GGUFSeer._open_and_map`, parsing helpers, tensor mapping,
`inspect_metadata`, both `mmap_and_load` overloads

Calling mapping entry points more than once on one seer can overwrite live
mapping/file-descriptor state. Duplicate metadata keys are accepted. UInt64
lengths and offsets are converted to `Int` without a complete representability
check. `rows * cols` can overflow before `_tensor_byte_size` sees it. Raw typed
loads may be unaligned on strict-alignment platforms. Large nested metadata
arrays can consume excessive time before rejection.

**Buildout:** one explicit loader state machine; duplicate-key rejection;
checked UInt64-to-Int conversions and products; portable little-endian reads;
array nesting/work budgets; malformed corpus and fuzzing.

### AER-107 — Tokenizer mutation APIs accept invalid and contradictory state

**Status:** confirmed
**Severity:** P1 compatibility/safety blocker
**Owners:** `RuneWeaver.add_token`, `set_token_score`, `set_token_type`,
`set_special_tokens`, UTF-8/piece helpers, `encode`, `decode`

Negative or sparse token IDs are not validated, duplicate token text silently
overwrites the reverse map, special IDs are not range-checked, UTF-8 lead-byte
width is trusted without continuation validation, and byte-token decoding drops
data. The fallback encoder has no inverse contract. The merge implementation
rebuilds lists repeatedly and is unsuitable for long inputs.

**Buildout:** validated vocabulary finalization; duplicate policy; tokenizer
model/mode metadata; stateful byte decoding; Unicode error policy; corpus parity
and complexity limits that fail honestly rather than truncate data.

### AER-108 — The engine and supervisor expose two different event buses

**Status:** confirmed
**Severity:** P1 integration bug
**Owners:** `AesirEngine.__init__`, `SelfHealingSupervisor.__init__`,
`pulse_heartbeat`, `AesirEventBus`

`AesirEngine` constructs `self.event_bus`, while
`SelfHealingSupervisor` constructs its own `self.bus`. The startup heartbeat is
published to the supervisor's private marker, not the engine bus advertised by
the facade. Neither object has subscribers, but even the scaffold state is
split.

**Buildout:** one injected bus ownership contract before implementing real
delivery; tests must observe the same event object used by engine consumers.

### AER-109 — Model-store operations are ephemeral and ambiguous even in one process

**Status:** confirmed
**Severity:** P1 CLI/data correctness blocker
**Owners:** `RuneModelStore` constructors and all store methods,
`dispatch_command`

Every command creates a newly seeded store. Missing lookups fabricate a model;
prefix lookup can return the wrong tag; create/copy can duplicate key entries;
remove returns success when an exception occurs; active state is fixed; parsed
Modelfile data is mostly ignored. No operation persists to disk.

**Buildout:** explicit store root, validated manifest schema, exact lookup,
atomic persistence, checksum-derived identity, deterministic duplicate policy,
and CLI exit failures.

### AER-110 — Socket and response helpers lose error and protocol state

**Status:** confirmed
**Severity:** P1 server blocker
**Owners:** all `BifrostGate` socket/send/route methods and OS helpers

Windows is inferred as “not Linux or macOS” while still calling POSIX symbols.
Socket-option constants and sockaddr layout are manually guessed. Request bytes
are discarded after one 1024-byte read. Send functions ignore partial writes,
interrupts, disconnects, and content length/chunk framing. Duplicate static and
instance send helpers can drift. JSON is concatenated without escaping.

**Buildout:** platform abstraction; owning request/response structs; bounded but
incremental HTTP parsing; write-all semantics; error propagation; JSON encoder;
one send implementation; conformance and disconnect tests.

### AER-111 — Several “safety” and orchestration functions are no-ops with unsafe edges

**Status:** confirmed
**Severity:** P1 truth/correctness blocker
**Owners:** `ErrorGuard`, grammar, speculative, state vault, event bus, thread
pool, supervisor, and swarm functions

`ErrorGuard.validate_pointer` accepts address 1 and does not check alignment;
grammar state never parses or advances; speculative verification lacks a vocab
bound and returns one accepted token for a zero-count request; StateVault stores
no KV bytes; the event bus has no subscribers; the thread pool has no threads;
the supervisor simulates recovery; heartbeat is unconditional; dispatch ignores
the prompt and only formats a string.

**Buildout:** treat each subsystem as a separate future contract. Until then,
rename outputs and tests as scaffold behavior and prevent operational success
claims.

### AER-112 — Tests can read uninitialized memory or verify only that code returned

**Status:** partially resolved by Forge 0A
**Severity:** P0 verification blocker
**Owners:** test suite, especially quantization, multi-engine, inference,
resilience, accelerator, Hugging Face, and swarm tests

Forge 0A initializes all speculative target logits before verification,
activates and checks the grammar scaffold's current masking behavior, verifies
that every exercised dequantization dispatch writes output, checks supplied
model/content fields in the OpenAI formatter, and asserts deterministic token 0
for zero-initialized synthetic forward passes. Many remaining tests still assert
only values returned by unconditional simulations and therefore do not prove
their advertised external capabilities.

**Buildout:** initialize every byte read; assert derived outputs; add negative
cases; rename scaffold tests; and make all failures raise.

### AER-113 — Public generation defaults remain hardcoded policy

**Status:** confirmed refinement
**Severity:** P2 configuration debt
**Owners:** `generate`, `generate_stream`, `run_single_shot`, CLI parser

The verified token count of 32 is embedded in `generate()` and streaming. The
CLI has a separate 32 default and a fixed 2,147,483,647 parsing ceiling. These
were appropriate proving constants but are not a durable configuration model.

**Buildout:** one validated `GenerationConfig` owned by the facade, with the
verified greedy defaults represented once and model context applied as the
runtime bound.

### AER-114 — Copyable raw-pointer descriptors obscure ownership and lifetime

**Status:** confirmed refinement
**Severity:** P1/P2
**Owners:** `RuneTensor`, KV/buffer/shard descriptors, transformer blocks,
`GenerationResult`, registries, and their copy methods

Copy operations usually alias pointers without encoding the lifetime owner.
Some copies duplicate dynamic lists while others alias backing memory. A mapped
tensor can outlive the seer in type terms. Unmanaged shard allocations have no
owner at all.

**Buildout:** distinguish owned allocation, borrowed view, immutable mapped
view, and request-scoped view in types or constructors; eliminate ownerless
heap leaks; document and test destruction order.

### AER-115 — The suite had 118 print-only failure sites in 12 modules

**Status:** resolved by Forge 0A for terminal failure semantics
**Severity:** closed P0 slice; remaining evidence weakness tracked by AER-003 and AER-112
**Owner:** tests domain

The re-audit found 118 `FAIL` print sites across 12 test modules and two
KV-cache failure paths that returned early. Forge 0A converted every terminal
failure to a raised error, converted both early returns, and proved the nonzero
exit behavior with an intentional mutation. Detailed mismatch diagnostics may
still print before the terminal error; they no longer return success.

**Remaining buildout:** honest test naming, external fixtures, and stronger
capability assertions remain in Forge 0C onward.

## 30. Runtime Function Buildout Ledger

### 30.1 Asgard facade and entry point

| Function(s) | Status | Required work |
|---|---|---|
| `calculate_runtime_pool_bytes` | Real formula, unsafe arithmetic | Reject invalid dimensions/capacity and check every sum/product for overflow. |
| `GenerationResult.__init__`, `__copyinit__`, `copy` | Functional, copy-heavy | Clarify move/copy cost and avoid repeated token-list copies on hot return paths. |
| `generation_stop_reason` | Verified narrow | Validate or encapsulate raw counts/positions; extend only through a generation configuration contract. |
| `AesirEngine.__init__` | Real narrow plus scaffold construction | Avoid double metadata mapping cost, validate conflicting backend flags, inject one event bus, and stop activating fake subsystems by default. |
| `_prepare_prompt` | Partial RAG scaffold | Replace constant query vector; validate dimensions; make temporary pool use exception-safe; add context budgeting. |
| `_run_generation` | Verified deterministic core, incomplete lifecycle | Guaranteed pool cleanup, stateful decode, cancellation, custom stops, bounded/configured policy, stream-safe serialization. |
| `generate_tokens` | Verified narrow | Accept a structured configuration in a later compatible extension and document request isolation. |
| `generate` | Verified facade, hardcoded policy | Source the 32-token default from one configuration owner. |
| `generate_stream` | Reuses real loop, transport-incomplete | Guaranteed close/error result, final stop reason, escaping/framing, cancellation/backpressure; ultimately move transport ownership out of Asgard. |
| `main` | Functional dispatch | Define consistent exit codes and avoid defaulting no-argument execution into a nonpersistent fake server. |

### 30.2 Memory, tensors, caches, stores, and topology

| Function(s) | Status | Required work |
|---|---|---|
| `NPUBackendType.__init__`, `name`; `GPURealmType.__init__`, `name`; `CompressedFormatType.__init__`, `name` | Unvalidated discriminants | Reject unknown values instead of converting them to generic or SmoothQuant labels. |
| `GPUBuffer` constructors, `as_rune_tensor`; `NPUBuffer` constructors, `as_rune_tensor` | Host-memory descriptors mislabeled as accelerator/DMA | Validate even byte size and tensor span; set DMA state truthfully; add real ownership/handle semantics or relabel as host buffers. |
| `RuneTensor.__init__`, `get`, `set` | Unsafe pointer view | Reject negative/overflowed shapes; validate boundary access at public edges; encode borrowed/owned lifetime. |
| `KVCache` constructors | Unsafe products and allocation failure | Validate positive layer/context/width, checked products, pool capacity, and explicit cache ownership. |
| `KVCache.append` | Works for verified in-range path | Reject invalid layer/position/width and remove misleading ring behavior until chronological wraparound exists. |
| `KVCache.get_k_slice`, `get_v_slice` | Unsafe unchecked view | Reject invalid layer/sequence lengths and define wrapped-cache semantics. |
| `MimirWell.__init__` | Real allocation, incomplete validation | Reject nonpositive/odd/overflowed byte sizes and handle allocation failure. |
| `MimirWell.allocate` | Critical bug | Raise on negative/exhausted/overflowed requests; never return address 1. |
| `allocate_npu_buffer`, `allocate_gpu_buffer` | Host-only wrappers | Use checked allocation and honest metadata; later connect real backend allocators. |
| `reset_kv_cache` | Arbitrary offset assignment | Replace with validated checkpoint/rewind ownership, not a caller-provided raw offset. |
| `MimirStore` constructors and copy | Partial primitive | Validate max/dim/products; clarify aliased embedding lifetime and copied document ownership. |
| `MimirStore.add_document` | Partial | Reject dimension mismatch and full capacity explicitly; return a result; avoid silent truncation. |
| `MimirStore.search_knn` | Real simple search, dynamic and under-validated | Validate query width/top-k, define ties/NaN/zero vectors, avoid hot allocations, evaluate retrieval. |
| `DeviceTopology` constructors | Fabricated devices | Represent configured versus discovered devices separately; validate name count and backend availability. |
| `detect_edge_npus`, `detect_gpu_realms` | Simulation | Real platform probes or explicit empty/unavailable results. |
| `shard_split_cols` with well | CPU copying helper | Validate shard count/divisibility/capacity and state that it is host partitioning. |
| `shard_split_cols` without well | Leaks unmanaged allocations | Add an owner or remove only with approval after callers migrate. |
| `shard_split_rows` | Host view helper | Validate shard count and lifetime; do not label as device placement. |

### 30.3 Compute kernels

| Function(s) | Status | Required work |
|---|---|---|
| `BlockQ4_K.__init__`, `dequantize_q4_k_m` | Toy non-GGML block | Implement the authoritative GGML block layout and scales or relabel; validate block/output spans. |
| `dequantize_q2_k`, `dequantize_q3_k`, `dequantize_q4_0`, `dequantize_q4_1`, `dequantize_q5_0`, `dequantize_q6_k`, `dequantize_q8_0` | Simplified incorrect formats | Parse real per-block metadata and packing; handle/reject tails; add real GGML fixtures. |
| `dequantize_gptq_4bit`, `dequantize_awq_4bit`, `dequantize_exl2`, `dequantize_hqq`, `dequantize_smoothquant_int8` | Name-only toy conversions | Each needs its actual external format contract, scales/zeros/group metadata, fixture, and oracle—or honest unsupported status. |
| `dequantize_compressed_tensor` | Unsafe conflating dispatcher | No fallback to another format; exact input byte length; distinct supported cases only. |
| `gemm_f16` | Verified narrow CPU kernel | Shape/output-span checks, broader numerical/reference corpus, architecture-specific performance claims removed. |
| `flash_attention_gqa` | Verified through pinned inference, under-validated | Enforce head divisibility, tensor widths, sequence spans, finite accumulation, and randomized F32 reference parity. |
| `flash_attention_2` | Legacy unsafe kernel | Add scalar tails and causal semantics or retire only with approval; current width-16 loops can overrun. |
| `silu` | Real primitive | Pointer/size validation and numerical extreme tests. |
| `geglu` | Partial/misnamed relative to SwiGLU runtime | Reject odd sizes, define output shape, test overflow; clarify that transformer path actually uses SiLU(gate) times up. |
| `rmsnorm`, `rmsnorm_arm_neon`, `rmsnorm_gpu` | CPU functions with varying lane widths | Reject zero/mismatched widths; stable F32 accumulation tests; remove hardware execution claims. |
| `apply_rope` | Real narrow | Reject odd/mismatched head shapes and negative positions; parse model theta/scaling variants. |
| `cosine_similarity` | Real primitive | Reject mismatched sizes rather than silently taking the minimum; define zero-vector behavior and finite checks. |
| `gemm_f16_sharded` | Sequential host loop | Reject mismatched list lengths instead of silently taking minimum; real device scheduling later. |
| `all_reduce_sum` | Sequential host reduction | Validate every shard span; use wider accumulation where needed; do not call it a device collective. |
| `gemm_f16_arm_neon`, `gemm_f16_gpgpu_vector`, `gemm_f16_mobile_opencl` | CPU SIMD-width variants | F32 accumulation, shape checks, real ISA/backend compilation proof, honest naming. |
| `gemm_f16_npu`, `gemm_f16_gpu` | Misleading dispatch | Return unsupported for unavailable backends; connect real runtimes only after hardware gates. |

### 30.4 Inference orchestration

| Function(s) | Status | Required work |
|---|---|---|
| `TransformerBlock.__init__(..., seer)` | Loader-backed but retains sentinel fallback | Required tensors should raise immediately; never construct usable address-1 weights. |
| legacy `TransformerBlock.__init__` and `copy` | Sentinel-bearing test constructor | Replace with an explicit non-runnable descriptor/test fixture without address-1 pointers. |
| `TransformerBlock.forward` single-device | Verified narrow, oversized function | Exception-safe rewind; precondition validation; split attention/FFN workspace responsibilities; retain exact parity. |
| `TransformerBlock.forward` multi-device branch | Incorrect/unverified | Rebuild as a separate contract; current GQA widths, reconstruction, attention, and placement are invalid. |
| primary `forward_pass` | Verified narrow, hot allocations and weak errors | Reuse block list without copying, reject empty tokens, validate positions/cache/layers, sanitize finite logits, use a true minimum argmax initializer, guarantee rewind. |
| convenience `forward_pass` overload | Unsafe lifecycle convenience | Check embedding existence before lookup; scope/reclaim allocated KV cache; document that it is not reusable generation. |

### 30.5 GGUF and tokenizer loader

| Function(s) | Status | Required work |
|---|---|---|
| `GGMLType.to_compressed_format` | Dangerous default | Raise/return unsupported for unknown GGML types; map only implemented formats. |
| `GGUFModelConfig.head_dim`, `kv_dim`, `validate` | Real narrow | Checked products; validate RMS epsilon and special IDs; support optional/tied/output and RoPE metadata deliberately. |
| `GGUFSeer.__init__`, `_open_and_map`, `__deinit__` | POSIX real path, re-entry unsafe | Explicit state machine, no remap leak, portable platform layer, immutable mapped pointer view. |
| `_require_range`, `_read_u32`, `_read_i32`, `_read_u64`, `_read_f32` | Bounds checks real | Portable unaligned little-endian reads and representability checks. |
| `_read_string`, `_string_end` | Partial | UTF-8/error policy, size/work budget, avoid per-string heap churn where possible. |
| `skip_value` | Real recursive parser, denial-of-service surface | Nesting/element/work bounds and checked cursor arithmetic. |
| `_parse_string_array`, `_parse_score_array`, `_parse_type_array` | Real narrow | Checked UInt64 conversion/product; cross-array cardinality and duplicate semantics. |
| `_parse_metadata_value`, `_parse_metadata` | Real narrow | Duplicate-key detection, type mismatch rejection for recognized keys, tokenizer-model and optional metadata. |
| `_parse_header` | Real narrow | Stronger minimum table feasibility and count arithmetic. |
| `_tensor_byte_size`, `_map_tensor`, `_parse_tensors` | Real F16/F32 narrow | Overflow-before-product, multidimensional/format policy, immutable mapped views, quantized layout only when real. |
| `_require_tensor_shape`, `_validate_required_tensors` | Strong narrow validation | Tied output option, architecture variants, exact vocabulary/special IDs, no unused fake compatibility. |
| `inspect_metadata`, both `mmap_and_load` overloads | Functional but duplicated lifecycle | One stateful inspection/load flow or explicit separate probe type; prevent re-entry and duplicated parsing cost. |
| `RuneWeaver.add_token`, `set_token_score`, `set_token_type`, `set_special_tokens` | Under-validated mutation API | Nonnegative/range/duplicate validation and finalization invariant. |
| `byte_to_hex_token` | Functional helper | Coverage for every byte and tokenizer-specific byte notation. |
| `_append_utf8_symbols`, `_initial_pieces` | Model-specific UTF-8 handling | Validate continuation bytes and tokenizer normalization metadata. |
| `_merge_sentencepiece` | Correct for pinned prompt, inefficient/general-incomplete | Priority-queue or equivalent proven algorithm, tie semantics, corpus parity. |
| `_append_piece_tokens`, `encode` | Verified narrow | Control/user token rules, fallback error policy, multiple real tokenizer fixtures. |
| `decode` | Token-local and lossy | Stateful sequence decoder for bytes/control tokens and UTF-8 flush/error semantics. |

### 30.6 External loaders and CLI

| Function(s) | Status | Required work |
|---|---|---|
| `HuggingFaceSeer.__init__` | Unused configured CDN | Either use an injected trusted endpoint or remove only with approval; validate configuration. |
| `parse_hf_repo`, `is_hf_tag`, `build_download_url` | String helpers, weak validation | Exact URI/repo grammar, revision/file encoding, reject traversal/local-path confusion. |
| `download_hf_model` | Simulation | HTTPS stream, auth, revision, resume, checksum, atomic destination, error result. |
| `ONNXModelSeer.__init__`, `parse_onnx_header`, `map_to_well` | Simulation | Real protobuf parsing, graph/initializer ownership, operator support and conformance fixtures. |
| `ModelManifest.__init__`, `size_formatted` | Fabricated defaults and crude formatting | Validated real metadata; no placeholder digest/size; correct human-readable sizes and negative rejection. |
| all `RuneModelStore` constructors/methods | Ephemeral seeded simulation | Persistent store, exact lookup, atomic operations, real active-state ownership, honest missing errors. |
| `parse_modelfile` | Partial parser | Prefix-safe extraction, quoting/multiline/comment rules, duplicate policy, required directive and parameter validation. |
| `dispatch_llama_cli`, `dispatch_exl2_cli`, `dispatch_onnx_cli` | Simulated unconditional success | Real execution adapters or explicit unsupported nonzero results; remove fabricated metrics. |
| `print_banner`, `print_general_help` | Presentation | Capability-aware help that labels unsupported/scaffold commands. |
| `parse_positive_int` | Real narrow | Reuse a general validated numeric/config parser and one source of token limits. |
| `format_model_table`, `format_ps_table` | Formatting over fake state | Consume persistent real state; no fixed CUDA/expiry values; terminal-width and Unicode tests. |
| `dispatch_command` | Overloaded mixed real/simulated router | Per-command handlers, consistent nonzero errors, no fake progress/success, persistent server loop/store, exact help. |
| `RuneREPL.run_repl` | Scripted demo | Real stdin/EOF/signals, engine session/history, slash-command validation, cancellation. |
| `run_single_shot` | Verified real | Structured error/exit reporting and shared generation configuration. |

### 30.7 Server, formatting, and ancillary systems

| Function(s) | Status | Required work |
|---|---|---|
| `os_is_linux`, `os_is_macos`, `os_is_apple`, `os_is_windows` | Fragile runtime guesses | Compile-time/platform abstraction; Windows must not mean “unknown Unix.” |
| `BifrostGate.__init__`, `start`, `await_request`, `__deinit__` | POSIX socket scaffold | Validated port, portable sockaddr/options, persistent accept loop, request ownership, failure cleanup. |
| `send_response`, both close helpers, both chunk helpers, both embedding helpers | Duplicated unsafe writes | One write-all/error-aware implementation, HTTP framing, escaping, idempotent close ownership. |
| `dispatch_http_route` | Fixed route theater | Parse method/path/body, invoke engine/service APIs, correct errors/status, authentication and conformance. |
| all `OpenAIGate.format_*` functions | Unsafe string templates | JSON escaping, dynamic IDs/timestamps/usage, schema correctness, real embeddings and SSE termination. |
| `GBNFGrammar.__init__`, `copy`, `apply_grammar_mask` | Toy/no-op state | Real parser/state machine/token validation; copy must preserve active state and position; pointer checks. |
| `SpeculativeEngine.__init__`, `copy`, `verify_tokens` | Unsafe toy verifier | Validate count/token/vocab spans; real draft/target probabilities, rollback and KV coordination; zero count returns zero. |
| all `ErrorGuard` functions | Partial helpers, not integrated | Reject sentinel/misalignment/span errors, correctly classify finite/subnormal values, integrate at actual boundaries. |
| all `AesirEventBus` functions | Marker only | Subscriber registration/delivery, message ownership, ordering, concurrency, shared engine instance. |
| all `StateVault` functions | Metadata marker only | Snapshot/restore tokens, KV data, RNG/config/session identity with validation and persistence policy. |
| all `SelfHealingSupervisor` functions | Simulation and split bus | Inject shared bus/vault, observe real failures, recovery eligibility/state verification, no unconditional success. |
| all `RuneThreadPool` functions | Boolean scaffold | Validate thread count, workers/queue/join/shutdown/error propagation and race tests. |
| `SwarmNodeRole` construction/name | Unvalidated enum | Reject unknown roles. |
| `PeerNode` construction, `vram_free_mb` | Unvalidated telemetry | Validate address/port/capacity/usage and prevent negative free memory. |
| all `PeerRegistry` methods | Seeded local simulation | Empty real registry, liveness timestamps, duplicate/update policy, no-alive error, persistence/concurrency. |
| all `TaskDispatcher` methods | String formatter | Real task lifecycle, decrement/completion, request identity, transport errors, cancellation. |
| all `SwarmCluster` methods | Networkless simulation | Authenticated join, heartbeat transport/expiry, prompt-preserving remote inference and result propagation. |

### 30.8 Legacy and scratch declarations

The 35 functions/methods in `replace_gguf.mojo`, `test.mojo`, `test2.mojo`,
`test3.mojo`, `test4.mojo`, `test_buf.mojo`, `test_callback.mojo`,
`test_dict.mojo`, `test_engine.mojo`, `test_keepalive.mojo`, `test_mojo.mojo`,
`test_parse.mojo`, `test_server_loop.mojo`, `test_sys.mojo`, and
`test_trait.mojo` are not part of the supported runtime or proving suite. They
include empty `pass` bodies, unsafe raw-pointer experiments, obsolete loader and
socket copies, and placeholder callbacks. They need one of three explicit
outcomes: promote into real tests, archive outside runtime source, or delete
only after Volmarr's specific approval. Until then they must not be counted as
capability code or test coverage.

## 31. Test Function Truth Ledger

### 31.1 Forge 0A conversion record

The following conversion set was completed and verified. It remains listed so
future regressions can be checked against the exact function inventory.

| Module | Functions converted or minimally refined in Forge 0A |
|---|---|
| `test_compute.mojo` | `test_gemm`, `test_flash_attention`, `test_silu`, `test_geglu`, `test_dequantize_q4_k_m` |
| `test_gguf.mojo` | `test_ggml_type` |
| `test_inference.mojo` | `test_forward_pass` gained an asserted output invariant; `test_generation_stop_policy` already raised correctly |
| `test_kv_cache.mojo` | `test_kv_cache` converted both print-and-return failures and now asserts both synthetic forward results |
| `test_rag.mojo` | `test_cosine_similarity`, `test_mimir_store`; `report_engine_integration_boundary` must be counted as a skip |
| `test_npu_edge.mojo` | `test_npu_backend_enum`, `test_device_topology_npu`, `test_npu_buffer_zero_copy`, `test_arm_neon_precision`, `test_npu_gemm_parity` |
| `test_gpu_realms.mojo` | `test_gpu_realm_enum`, `test_device_topology_gpus`, `test_gpu_buffer_zero_copy`, `test_gpu_gemm_parity` |
| `test_cli.mojo` | `test_modelfile_parser`, `test_model_manifest_store`; `test_cli_command_dispatch` needs actual output/error assertions |
| `test_quantization.mojo` | `test_compressed_format_enum`, `test_dequantization_kernels`; the latter now detects a dispatch that fails to write output |
| `test_multi_engine.mojo` | `test_openai_api_formatter`, `test_gbnf_grammar`, `test_speculative_engine`, `test_onnx_model_seer`, `test_multi_engine_cli` |
| `test_resilience.mojo` | `test_error_guard`, `test_state_vault`, `test_event_bus`, `test_thread_pool`, `test_supervisor_crash_recovery` |
| `test_huggingface.mojo` | `test_hf_repo_parsing`, `test_hf_download_url_builder`, `test_hf_mobile_model_download` |
| `test_swarm_cluster.mojo` | `test_swarm_node_role`, `test_peer_node_metrics`, `test_peer_registry_and_load_balancer`, `test_swarm_cluster_task_dispatch` |

### 31.2 Tests that already raise but still overstate their evidence

- `test_sharding` and its five child tests fail correctly, but they prove host
  partitioning and sequential arithmetic—not device placement or multi-GPU.
- `test_tokenizer` uses process-failing assertions, but covers one synthetic
  ASCII merge graph and token-local decode only.
- `test_gguf_parsing` genuinely proves rejection of the tracked malformed
  fixture; it does not prove general GGUF compatibility.
- `test_generation_stop_policy` genuinely proves the isolated stop decision.
- `test_real_gguf.main` is the strongest test: it raises on exact metadata,
  mapping, tokenization, 32-token output, one-token regression, context boundary,
  and pool restoration mismatches. It remains opt-in because weights are not
  tracked.
- `run_all.main` now registers 49 executable cases and one explicit skip through
  the counted ledger. A failure is recorded, later cases continue, the complete
  summary is printed, and the process then exits nonzero.

### 31.3 Counted runner infrastructure completed in Forge 0B

| Function(s) | Verified contract |
|---|---|
| `TestLedger.__init__` | Starts pass/fail/skip counts and ordered failure details at zero/empty. |
| `record_pass` | Increments only `passed` and emits one stable `[CASE PASS]` line. |
| `record_failure` | Increments only `failed`, preserves name/message order, and emits one `[CASE FAIL]` line. |
| `record_skip` method and function | Increment only `skipped` and emit one `[CASE SKIP]` line. |
| `total` | Returns `passed + failed + skipped`. |
| `finish` | Emits unique `[SUMMARY]` keys, validates the expected total, and raises after reporting on failure. |
| `run_case` | Invokes one thin zero-argument test, catches its `Error`, records exactly one outcome, and continues. |

## 32. Massive Staged Buildout Plan Derived from the Function Ledger

This plan expands the earlier Forge order into reviewable contracts. Each stage
must receive its own `TASK_*.md`, independent acceptance gates, documentation
update, commit, and push.

### Stage 0 — Truth infrastructure

1. **Forge 0A — completed:** convert every print-only/early-return test failure
   to a raised error; prove deliberate corruption exits nonzero.
2. **Forge 0B — completed:** add counted pass/fail/skip reporting without
   swallowing errors.
3. **Forge 0C:** create a capability ledger linking each verified claim to its
   gate and marking scaffolds honestly.
4. **Forge 0D:** remove fabricated success/benchmark/download/hardware messages
   by relabeling or returning unsupported errors; no public function deletion.
5. **Forge 0E:** reconcile TODO, README, vision, architecture, interfaces, and
   duplicate docs with the ledger.

### Stage 1 — Memory and unsafe-boundary hardening

1. Checked `MimirWell` construction/allocation/rewind.
2. Checked tensor/cache/buffer/store dimensions and arithmetic.
3. Remove address-1 from usable runtime objects.
4. Exception-safe generation and forward-pass workspace guards.
5. Ownership/lifetime model for mmap, pool views, shards, and results.

### Stage 2 — Kernel contract hardening

1. Shape-checked GEMM/RMSNorm/RoPE/attention wrappers.
2. Randomized F32 reference tests for CPU primitives.
3. Reject legacy attention/dequant tails that cannot be computed safely.
4. Replace misleading hardware names with explicit CPU variants until real.
5. Disable/reject invalid multi-device inference until separately rebuilt.

### Stage 3 — Loader and tokenizer generalization

1. GGUF loader state machine, checked integers, duplicate keys, portable reads.
2. Malformed corpus and fuzz harness.
3. Vocabulary finalization and special/control-token validation.
4. Stateful byte/UTF-8 decoding.
5. RoPE/tied-output/tokenizer metadata variants and multiple real F16 fixtures.

### Stage 4 — Generation quality

1. One `GenerationConfig` and cancellation/error results.
2. Stop-token sets, stop strings, stateful decoder flush.
3. Numerical/token regression corpus across prompts and models.
4. Deterministically seeded sampler stack.
5. Chat-template and conversation contracts after tokenizer support.

### Stage 5 — Persistent CLI and model store

1. Real on-disk manifest/blob layout with atomic operations.
2. Exact create/copy/remove/show/list/ps semantics and exit codes.
3. Real stdin REPL and session state.
4. HTTPS Hugging Face download with revision, resume, checksum, and atomic move.
5. Modelfile grammar and parameter-to-generation integration.

### Stage 6 — Service boundary

1. Move transport serialization out of `AesirEngine` behind a service API.
2. Platform-safe socket abstraction and persistent serving loop.
3. Incremental HTTP parser and write-all response path.
4. One compatibility API first, with JSON/SSE conformance.
5. Cancellation, backpressure, timeouts, limits, and security defaults.

### Stage 7 — Embeddings and RAG

1. Real embedding model/extraction path.
2. Ingestion, parsing, chunking, metadata, persistence.
3. Query embedding, retrieval evaluation, context budgeting, citations.
4. End-to-end external corpus tests.

### Stage 8 — Quantized inference

1. Pick one authoritative GGML format.
2. Implement exact block layout and verified dequant/matmul.
3. Load a real quantized GGUF and compare logits/tokens to `llama.cpp`.
4. Add formats one at a time; never restore a matrix claim from enum names.

### Stage 9 — Hardware and multi-device

1. Pick one physically available accelerator backend.
2. Real detection, allocation, copy/zero-copy contract, kernel, sync, errors.
3. CPU parity and hardware CI/fixture evidence.
4. Only then design real placement, GQA sharding, collectives, and scaling.

### Stage 10 — Optional ecosystems

Treat ONNX, grammar, speculative decoding, ExLlama, resilience, concurrency, and
swarm as separate projects with individual external fixtures. None may inherit a
“complete” label from the current structs or unconditional `True` returns.

## 33. Forge 0C Recommendation (Completed)

Proceed with **Forge 0C: an evidence-backed capability ledger**.

Forge 0A and Forge 0B now provide trustworthy test termination and counted
reporting. Forge 0C should create one canonical ledger mapping every significant
project claim to a status (`verified`, `partial`, `scaffold`, `simulated`, or
`missing`), its exact executable evidence, and its remaining acceptance gate.
It must not yet rewrite every runtime banner or historical document; those are
Forge 0D and Forge 0E.

Forge 0C completed on August 14, 2026. At Volmarr's explicit request, accurate
TODO reconciliation was pulled forward from Forge 0E; the remaining vision,
architecture, interface, and duplicate-document reconciliation stays in Forge
0E.

---

## 34. Forge 0C Completion Addendum — Canonical Capability Ledger

### 34.1 Delivered truth boundary

`CAPABILITY_LEDGER.md` is now the canonical present-tense capability source of
truth. It contains 99 stable entries spanning every major claim family found in
the README, TODO, architecture/data-flow documents, vision records, domain
interfaces, source, tests, and the preceding AER-001 through AER-115 audit.

Each entry records:

1. a stable `AES-<DOMAIN>-<NUMBER>` identifier;
2. one exact canonical status;
3. the responsible domain;
4. the documents in which the claim appears;
5. the concrete files, types, and functions that currently exist;
6. an executable command or explicit statement that no adequate proof exists;
7. an evidence boundary that prevents a narrow proof from becoming a broad
   marketing claim;
8. the next acceptance gate needed to advance the status; and
9. applicable `AER-*` cross-references.

The five canonical statuses are deliberately stricter and simpler than the
audit's diagnostic vocabulary:

| Canonical status | Entries | Operational rule |
|---|---:|---|
| `verified` | 28 | The narrowly worded behavior executes and has appropriate evidence. External claims require an external fixture, independent oracle, or physical backend. |
| `partial` | 15 | Meaningful real logic exists, but safety, correctness breadth, integration, portability, persistence, or representative coverage is incomplete. |
| `scaffold` | 14 | Types/control flow/interfaces exist without end-to-end subsystem behavior. |
| `simulated` | 20 | Predetermined output, seeded state, or local toggles imitate an operation that did not occur. |
| `missing` | 22 | The advertised or required behavior has no meaningful implementation. |
| **Total** | **99** | Every entry has exactly one status. |

Mechanical inspection proved 99 unique IDs, zero duplicate IDs, zero invalid
status values, and exact agreement between the derived counts and the published
summary. Forty-five master-case names cited as local evidence all exist in
`tests/run_all.mojo`.

### 34.2 Important claim decompositions

Forge 0C did not assign one vague status to each grand subsystem. It split broad
claims where different pieces have materially different truth states:

- the fail-closed counted test harness is `verified`, while external-fixture RAG
  remains an explicit skip rather than an implied pass;
- the pinned GGUF v3 Llama F16/F32 metadata, mmap, conversion, tokenizer, and CPU
  generation path are `verified`, while general GGUF compatibility is `partial`
  and quantized GGUF loading is `missing`;
- exact 32-token greedy generation is `verified`, while sampling, custom stop
  strings, chat templates, batching, concurrency, and cancellation are
  `missing`;
- tested host tensor partitioning, host reduction, and host sharded GEMM are
  `verified`, while device discovery is `simulated` and real multi-GPU execution
  is `missing`;
- GPU/NPU enums and host-backed buffer descriptors are `scaffold`, dispatch
  under hardware names is `simulated`, and physical accelerator execution is
  not claimed;
- Hugging Face tag normalization and URL construction are `verified` string
  operations, while the download operation is `simulated`;
- the local cosine primitive and in-memory vector store are `verified` at their
  tested bounds, while query embeddings are `simulated`, ingestion/persistence
  are `missing`, and end-to-end RAG is a `scaffold`;
- compressed-format discriminants and toy transformations are `scaffold`, while
  real quantized-model inference is `missing`;
- a local OpenAI-shaped formatter is `scaffold`, while fixed successful REST
  responses are `simulated` and actual compatibility is not inferred;
- grammar and speculative types are `scaffold`, while ONNX, ExLlama, and broad
  llama.cpp CLI dispatch currently print simulated results;
- an in-memory swarm peer-selection rule is narrowly `verified`, while join,
  liveness, remote dispatch, and REST/CLI cluster status are `simulated`; and
- fixed benchmark values are `simulated`, while measured efficiency, security,
  observability, cross-platform support, CI, and production readiness remain
  open.

This decomposition is the main Forge 0C buildout result. It prevents a verified
inner primitive from laundering an unimplemented outer system into a completion
claim.

### 34.3 TODO accuracy repair and expansion

The prior TODO marked broad matrices complete based mainly on names, dispatch
branches, and synthetic checks. It has been replaced with an evidence-backed
backlog:

- ten checked items preserve only narrowly verified audit/Forge/CPU milestones;
- 188 unchecked items describe remaining work;
- every major unfinished section states its current ledger status and ID;
- Forge 0D enumerates every known fabricated runtime output family;
- Forge 0E retains the full current-document reconciliation still to come;
- Stages 1 through 11 cover memory safety, CPU contracts, GGUF/tokenizer
  generalization, generation quality, persistent CLI/store/download, service
  protocols, RAG, quantization, physical acceleration, optional ecosystems,
  distributed execution, CI, portability, performance, security, observability,
  repository hygiene, release engineering, and production readiness; and
- an ongoing discipline section requires every newly found incomplete, buggy,
  unsafe, misleading, or refinement-needing function to return to this audit and
  ledger rather than disappearing into an untracked promise.

This addendum introduces no new function-level defect outside AER-001 through
AER-115. Instead, it normalizes the existing findings into capability-sized
acceptance gates and exposes several broad TODO checkmarks as inaccurate. The
function census remains 373 declarations: 270 runtime/public, 68 test-domain,
and 35 legacy/scratch.

### 34.4 Verification record

The documentation-only Forge 0C change passed the same runtime gates as the
preceding truth slices:

- master suite: 49 passed, 0 failed, 1 skipped, total 50, status PASS, exit 0;
- external fixture SHA-256:
  `57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3`;
- real GGUF gate: exact header/model metadata, F16 mmap pointer alias, F32 norm
  conversion, prompt token IDs, first greedy token, complete 32-token IDs/text,
  one-token compatibility, length stop, context-exhaustion boundary, and pool
  restoration all passed;
- clean Mojo build: Linux x86-64 executable produced successfully in a temporary
  directory;
- built CLI: exact pinned 32-token response reproduced;
- ledger structure: 99/99 unique IDs and allowed statuses with exact counts;
- cited master cases: 45/45 found; and
- diff hygiene: `git diff --check` passed, with no model weight, generated
  binary, secret, or committed machine-local path added.

### 34.5 Current recommended next forge

Proceed with **Forge 0D: eliminate fabricated operational output**.

Use the 20 `simulated` ledger entries as the primary queue. Replace fixed
success, benchmark, download, hardware, health, recovery, ecosystem, and swarm
messages with honest unsupported errors or narrowly labeled demo output. Do not
delete public functions or expand subsystem scope without a separate approved
task. Add negative tests proving unsupported paths exit nonzero and cannot emit
operational success language.
