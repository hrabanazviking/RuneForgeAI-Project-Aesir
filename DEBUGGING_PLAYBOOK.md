# DEBUGGING PLAYBOOK

**IMPORTANT!!!** *This is a tenative version of this document. See note at the bottom of the document for need for further verification of the document before it becomes law.*

**Owner:** AesirEngine core maintainers
**Authority:** Diagnostic reference for all agents inheriting or troubleshooting Project A.E.S.I.R. code
**Last Updated:** 2026-08-16
**Related Documents:** ERROR_TAXONOMY.md, TESTING_PROTOCOL.md, CAPABILITY_LEDGER.md, ARCHITECTURE.md

---

## Purpose

This document captures known failure modes observed in Project A.E.S.I.R. and their diagnostic procedures. It exists to prevent any inheriting agent from re-discovering solved problems. When something breaks, check here before touching code.

If you diagnose a new failure mode not listed here, you are obligated to add it. Institutional memory is only as strong as the last agent who bothered to write it down.

---

## How To Use This Document

1. Identify the symptom category (inference hang, garbage output, crash, memory exhaustion, server deadlock).
2. Walk the numbered checklist for that category in order. Do not skip steps.
3. Record findings in DEVLOG.md regardless of outcome.
4. If the checklist resolves the issue, add a dated entry noting which step identified the root cause.
5. If no checklist resolves the issue, escalate to ARCHITECTURE.md and file a TASK_ document scoping the investigation.

---

## Section 1: Inference Hangs

**Symptom:** The engine accepts a prompt but produces no tokens. The caller waits indefinitely. No error is thrown. The process may or may not consume GPU cycles.

### Checklist (Check These Five Things)

#### 1. Confirm The GGUF File Actually Loaded

**What to check:** Verify that GGUFSeer parsed the file header and populated weight tensors. A silent parse failure can leave the engine in a state where it has a model reference but no usable weights, causing the forward pass to stall on zero-initialized data.

**Diagnostic procedure:**
- Locate the load log output. If GGUFSeer emits a parse-complete confirmation, proceed. If no confirmation appears, the file path is wrong, the file is corrupted, or the GGUF version is unsupported.
- Verify the file exists at the resolved path. Remember the Law of Flexible Roots — check that no absolute path hardcoded during testing has shipped into the runtime.
- Run a checksum against the source GGUF. Corruption during download or incomplete writes are common on consumer hardware with thermal throttling.
- If using mmap (zero-copy), confirm the file descriptor remained open. Premature closure of the mmap handle will cause page faults that manifest as indefinite hangs on first weight access.

**Resolution path:** Fix the path, re-download the model, or patch the mmap lifecycle in the loader.

---

#### 2. Verify KV Cache Block Availability

**What to check:** PagedAttention allocates KV cache in fixed-size blocks. If the block pool is exhausted — either because concurrent sequences consumed all blocks or because the configured pool size is undersized for the requested context length — the scheduler will block waiting for a free block that never arrives.

**Diagnostic procedure:**
- Check the configured maximum block count against the model's layer count, head count, and head dimension. The formula is: `available_blocks × block_size ≥ max_sequences × max_seq_length × num_layers × 2 (K and V)`.
- If running a single sequence, confirm the requested `max_tokens` plus the prompt length does not exceed `block_size × available_blocks`.
- Look for block leak patterns: sequences that finished but did not release their blocks back to the pool. This is a common bug in schedulers that handle cancellation poorly.
- Check whether prefix caching is enabled. A stale prefix cache entry with an invalidated reference count can permanently reserve blocks.

**Resolution path:** Increase the block pool size, reduce concurrent sequence count, fix the block release logic, or invalidate stale prefix cache entries.

---

#### 3. Check The Sampler For Infinite EOS Suppression

**What to check:** The stateless sampler uses a single scratchpad overwritten each iteration. If the masking configuration suppresses the end-of-sequence (EOS) token probability to negative infinity — either intentionally via Masking Seidr or unintentionally via a malformed logit mask — the engine will generate tokens forever without terminating, which externally appears as a hang if the caller is waiting for completion.

**Diagnostic procedure:**
- Inspect the logit mask applied to the final layer. Search for any mask that sets the EOS token ID to `-inf` or equivalently zeroes its probability.
- If Masking Seidr is active, verify that the `<|start_thought|>` suppression is not accidentally widening to include EOS or other critical control tokens.
- Check the temperature setting. A temperature of exactly 0.0 with argmin sampling (instead of argmax) will always select the lowest-probability token, which may never be EOS.
- Verify the `max_tokens` parameter is actually enforced. If the loop has no termination condition besides EOS, and EOS is suppressed, and max_tokens is unset or ignored, the loop is infinite.

**Resolution path:** Remove the erroneous EOS mask, fix the Masking Seidr scope, enforce max_tokens as a hard loop bound, or switch to argmax sampling at temperature 0.0.

---

#### 4. Probe The BifrostGate HTTP Layer For Blocking I/O

**What to check:** BifrostGate is a bare-metal HTTP server bridging external requests to the engine. If the server performs synchronous I/O on the same thread as the inference loop — or if a client connection stalls without closing — the engine can block on socket read/write, halting token generation.

**Diagnostic procedure:**
- Determine whether BifrostGate uses async I/O or synchronousaccept. If synchronous, a slow or disconnected client will block the entire server.
- Check for socket timeouts. If no timeout is configured, a half-open TCP connection will hang the server thread indefinitely.
- Verify that streaming responses (chunked transfer encoding for token-by-token output) are flushing properly. A buffered-but-unflushed stream will appear as a hang to the client even while the engine is generating internally.
- Test with curl using an explicit timeout: `curl --max-time 10 http://localhost:<port>/api/generate`. If curl times out but the engine process continues consuming GPU, the problem is in BifrostGate, not the inference loop.

**Resolution path:** Switch BifrostGate to async I/O, add socket timeouts, ensure flush calls after each token emission, or separate the HTTP listener thread from the inference thread.

---

#### 5. Confirm GPU Sync Points Are Not Deadlocked

**What to check:** Mojo GPU kernels launch asynchronously. If a kernel encounters an out-of-bounds memory access or an illegal instruction, the GPU may not report the error until the next synchronization point. If the engine calls a sync (explicit or implicit via a dependent operation) and the GPU is in a faulted state, the sync call will block forever.

**Diagnostic procedure:**
- Add explicit error checking after every GPU kernel launch. In Mojo, this means checking the CUDA error state after kernel dispatch.
- Run with `CUDA_LAUNCH_BLOCKING=1` to force synchronous kernel execution. This will surface errors immediately at the launch site rather than deferring them to the next sync.
- Check `nvidia-smi` during the hang. If GPU utilization is 0%, the GPU is idle and the hang is on the CPU side (items 1-4). If utilization is pinned at 100%, a kernel may be in an infinite loop.
- Profile with `nsys profile` to locate the exact kernel that is running when the hang occurs.

**Resolution path:** Fix the offending kernel (likely an indexing error or insufficient bounds checking), add guards on tensor dimensions before kernel launch, or fall back to a CPU implementation for the problematic operation.

---

## Section 2: Garbage Tokenizer Output

**Symptom:** The engine produces tokens, but the decoded text is gibberish, mojibake, repeated nonsense, or untranslated token IDs. The model itself may be functioning correctly, but the output pipeline corrupts the result.

### Checklist (Check These Three Things)

#### 1. Verify RuneWeaver Vocabulary Alignment

**What to check:** The RuneWeaver BPE tokenizer must use a vocabulary file that exactly matches the one used during the model's training. If the vocab file is missing, outdated, or from a different model family, token IDs will map to incorrect strings.

**Diagnostic procedure:**
- Confirm the tokenizer vocab file path resolves correctly relative to the model directory. Check for hardcoded absolute paths that violate the Law of Flexible Roots.
- Compare the vocab file's SHA256 against the model card's published hash. A mismatch means the wrong vocab.
- Encode a known plaintext string through RuneWeaver and inspect the token IDs. Compare these IDs against the reference tokenizer (HuggingFace transformers or llama.cpp's tokenizer) for the same model. If IDs diverge, the vocab is misaligned.
- Check for merged versus unmergedvocab files. Some models ship a `tokenizer.model` (SentencePiece) alongside a `tokenizer.json` (HuggingFace fast tokenizer). RuneWeaver must consume the correct format.

**Resolution path:** Download the correct vocab file, place it beside the model, update the tokenizer configuration, and rebuild the vocab index.

---

#### 2. Inspect BPE Merge Rank Ordering

**What to check:** BPE tokenizers apply merges in a strict rank order. If the merge ranks are loaded out of order, reversed, or truncated, the encoder will produce different token sequences than the model expects, causing the decoder to emit garbage on the return path.

**Diagnostic procedure:**
- Dump the merge table from RuneWeaver and compare it line-by-line against the reference `merges.txt` from the model repository.
- Verify that merge ranks are zero-indexed or one-indexed consistently throughout the codebase. Mixing conventions will shift every merge by one position.
- Test roundtrip encoding: encode a string to token IDs, decode back to string. If the roundtrip fails, the merge logic or vocab lookup is broken.
- Check for Unicode normalization issues. If RuneWeaver normalizes input text (NFKC, NFC) but the model was trained without normalization, token boundaries will shift.

**Resolution path:** Reload merges in correct rank order, fix the indexing convention, disable unwanted normalization, or patch the merge application algorithm.

---

#### 3. Check For Dtype Confusion In Token Embeddings

**What to check:** If the model stores token embeddings in f16 but the inference path casts them to f32 (or vice versa) inconsistently, the embedding lookup will produce numerically wrong vectors. The model will "run" but attend to meaningless representations, generating fluent but nonsensical text — or pure garbage if the cast error is severe enough.

**Diagnostic procedure:**
- Trace the dtype from the GGUF tensor metadata through the embedding lookup to the first transformer layer. The dtype should be consistent or explicitly converted at a single, documented point.
- Check whether quantized embeddings (q4_k_m) are being dequantized correctly. A wrong scale factor or zero-point will produce wildly wrong values.
- Compare the embedding norm for a known token ID against the reference implementation. If norms differ by more than floating-point epsilon, the dtype or dequantization path is broken.
- Inspect the final logits tensor dtype before argmax/sampling. If logits are f16 and the sampler expects f32, precision loss near decision boundaries can flip token selection unpredictably.

**Resolution path:** Enforce a single conversion point, fix the dequantization scale/zero-point computation, or standardize on f32 for the sampler input regardless of internal compute precision.

---

## Section 3: Crashes And Segfaults

**Symptom:** The engine terminates abruptly with a segfault, bus error, or illegal instruction. No clean shutdown occurs.

### Checklist (Check These Four Things)

#### 1. UnsafePointer Bounds In MimirWell

**What to check:** MimirWell manages zero-copy context buffers using raw pointers. Any out-of-bounds access on an UnsafePointer will segfault immediately with no Python-style traceback to guide you.

**Diagnostic procedure:**
- Enable Mojo's debug assertions (`ASSERT=1`) and rerun. Bounds checks that are compiled out in release mode will fire.
- Audit every `ptr[offset]` access in MimirWell for offset validation against the allocated buffer size.
- Check for use-after-free: if a buffer is freed and then accessed via a dangling pointer, the behavior is nondeterministic and will eventually segfault.
- Look for pointer arithmetic errors: `ptr + 1` advances by one element of type T, not one byte. Mixing element-offset and byte-offset calculations will corrupt memory.

**Resolution path:** Add bounds checks, fix pointer arithmetic, or switch to Span for bounded access in debug builds.

---

#### 2. GGUF Tensor Shape Mismatch Against Model Config

**What to check:** If the GGUF file's tensor shapes disagree with the model architecture config (wrong head count, wrong hidden dimension, wrong layer count), the matmul operations will attempt to access memory beyond tensor bounds.

**Diagnostic procedure:**
- Parse the GGUF header and dump all tensor names with their shapes.
- Compare against the model's `config.json` expectations.
- Look for transposition issues: some GGUF converters transpose weight matrices. If the inference code assumes a different layout, shapes will appear correct but strides will be wrong.

**Resolution path:** Regenerate the GGUF with correct conversion settings, or add transposition logic in the loader to normalize layout.

---

#### 3. Stack Overflow From Recursive Descent

**What to check:** Deeply nested prompt structures or pathological token sequences can trigger deep recursion in the parser or tokenizer, exhausting the stack.

**Diagnostic procedure:**
- Run under `ulimit -s unlimited` to see if the crash disappears. If it does, stack exhaustion is confirmed.
- Profile stack depth with `valgrind --tool=callgrind` or `perf record`.
- Identify recursive functions and add depth limits.

**Resolution path:** Convert recursion to iteration, add depth guards, or increase stack size at deployment.

---

#### 4. Invalid CUDA Context During Multi-Kernel Sequences

**What to check:** If the engine switches CUDA contexts (multiple GPUs, or competing processes using the same GPU) between kernel launches in a single inference pass, the context may become invalid, triggering an illegal instruction or segfault on the next launch.

**Diagnostic procedure:**
- Run with `CUDA_DEVICE_ORDER=PCI_BUS_ID` to ensure consistent device enumeration.
- Check for accidental context resets or destructions mid-inference.
- Verify that no other process is resetting the GPU (`nvidia-smi --query-gpu=gpu_bus_id --format=csv` during reproduction).

**Resolution path:** Pin the CUDA context at engine initialization, prevent context switching, or serialize GPU access.

---

## Section 4: Memory Exhaustion (OOM)

**Symptom:** The engine throws an out-of-memory error or the OS kills the process (OOM killer on Linux).

### Checklist (Check These Three Things)

#### 1. Calculate Actual VRAM Budget

**Formula:**
```
total_vram_needed = model_weights + kv_cache_pool + activation_buffers + framework_overhead
```

- Model weights: For q4_k_m quantization, approximately `param_count × 0.5 bytes`.
- KV cache pool: `block_count × block_size × num_layers × 2 × head_dim × dtype_bytes`.
- Activation buffers: Depends on batch size and sequence length. Estimate conservatively at `max_batch × max_seq_len × hidden_dim × dtype_bytes × 4`.
- Framework overhead: 500MB to 1GB for Mojo runtime and CUDA context.

**Action:** If the calculated budget exceeds available VRAM, reduce block count, reduce max sequence length, or use a smaller model.

---

#### 2. Check For KV Cache Block Leaks

**What to check:** Same as Section 1 Item 2, but the symptom is gradual VRAM exhaustion across multiple requests rather than a single-request hang.

**Diagnostic procedure:**
- Log block pool utilization after each request completes. If utilization trends upward and never drops, blocks are leaking.
- Test with a load script that sends 100 sequential single-turn requests. If VRAM fills over time, the leak is confirmed.

**Resolution path:** Fix block release logic in the scheduler's sequence-completion handler.

---

#### 3. Verify mmap Is Actually Zero-Copy

**What to check:** If mmap fails silently and the loader falls back to a read-and-copy path, the entire model weight set is duplicated in system RAM and then copied again to VRAM, doubling memory pressure.

**Diagnostic procedure:**
- Check system RAM usage during model load. If RAM spikes to roughly the model file size, mmap fell back to eager loading.
- Verify the mmap syscall succeeded (check errno or Mojo's mmap wrapper return value).
- On some filesystems (network mounts, some tmpfs configurations), mmap with MAP_SHARED is not supported and will fail.

**Resolution path:** Ensure the model file resides on a local filesystem supporting mmap, or implement an explicit fallback that logs loudly when zero-copy is unavailable.

---

## Section 5: BifrostGate Server Deadlock

**Symptom:** The HTTP server stops accepting connections. Existing connections hang. The inference engine may or may not continue running.

### Checklist (Check These Three Things)

#### 1. Thread Pool Exhaustion

**What to check:** If BifrostGate uses a fixed-size thread pool and all threads are blocked on slow inference requests, no new connections can be serviced.

**Diagnostic procedure:**
- Check the thread pool size configuration.
- Monitor active thread count during load testing.
- Look for requests that hold a thread hostage without completing (client disconnect without server-side detection).

**Resolution path:** Increase thread pool size, add request timeouts, or switch to async I/O.

---

#### 2. Lock Contention On Shared Engine State

**What to check:** If the inference engine and the HTTP server share mutable state (request queue, KV cache manager) behind a mutex, contention can deadlock under load.

**Diagnostic procedure:**
- Identify all shared mutable state between BifrostGate and AesirEngine.
- Check for lock ordering violations: if Thread A locks State X then State Y, and Thread B locks State Y then State X, deadlock is guaranteed.
- Run with deadlock detection enabled (Mojo debug asserts or helgrind).

**Resolution path:** Use lock-free queues for request submission, eliminate shared mutable state, or enforce strict lock ordering.

---

#### 3. Backpressure Cascade

**What to check:** If incoming request rate exceeds inference throughput, the request queue grows unbounded. Eventually, memory exhaustion or thread starvation causes the server to freeze.

**Diagnostic procedure:**
- Monitor queue depth over time under sustained load.
- Check whether any backpressure mechanism exists (request rejection, 503 responses, queue size limits).

**Resolution path:** Add a bounded request queue with explicit rejection when full, implement 503 Service Unavailable responses, or add admission control based on estimated inference time.

---

## General Escalation Procedure

When all applicable checklists have been exhausted without resolution:

1. **Capture the failure state:** Process status, GPU status (`nvidia-smi`), Mojo debug output, any core dump.
2. **Search DEVLOG.md and ERROR_TAXONOMY.md** for prior occurrences of similar symptoms.
3. **Review CAPABILITY_LEDGER.md** to confirm whether the failing subsystem is marked `verified`, `partial`, `scaffold`, or `simulated`. A `simulated` or `scaffold` status means the code was never expected to work and the "bug" is actually a missing implementation.
4. **File a TASK_ document** with the symptom, reproduction steps, and attempted diagnostics.
5. **Do not attempt a blind fix.** Blind fixes violate additive bug-fixing doctrine and risk introducing regressions into adjacent subsystems.

---

## Contribution Protocol

Any agent who successfully diagnoses a new failure mode using this playbook must append a new subsection under the appropriate section. Format:

```markdown
#### N. [Title]

**What to check:** [Description]

**Diagnostic procedure:**
- [Step]
- [Step]

**Resolution path:** [Fix description]
```

Include the date of discovery and reference the commit or TASK_ document that prompted the investigation.

---

## Confirmation Needed

The following items in this playbook are reasoned from the README's architecture description but have not been verified against actual source code in `aesir_engine/`:

- Exact internal API names (GGUFSeer, RuneWeaver, MimirWell, BifrostGate, Masking Seidr) — confirmed as named components, but their internal method signatures are not documented in the scraped content.
- Specific Mojo memory management patterns used in MimirWell.
- BifrostGate's threading model (sync vs async).
- Sampler implementation details beyond "stateless scratchpad."

Before committing this document, an agent with repository access should verify these assumptions against `aesir_engine/source/` and annotate any discrepancies.

---
