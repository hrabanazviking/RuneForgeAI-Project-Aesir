# Task: Real GGUF Inference Vertical Slice

## Context

Project A.E.S.I.R. compiles and its current proving suite passes, but the tested
inference path does not yet consume real model data. The checked-in
`aesir_engine/model.gguf` fixture is a 24-byte GGUF v3 header with zero metadata
and zero tensors. Several runtime defaults are fixed to a 32-layer, 4096-wide
model, and the CLI `run` command currently emits a simulated response without
constructing `AesirEngine`.

This task establishes the first truth-bearing end-to-end path:

> Read an actual GGUF model, derive its architecture and tokenizer from file
> metadata, execute a deterministic CPU forward pass over mapped weights, and
> return one genuine decoded model token through `aesir run`.

## Reference Model

The integration target is the MIT-licensed TinyStories Llama 2 micro-model:

- Repository: `shibatch/stories-converted`
- Revision: `4724c9612ac3278f58aa2dbd4d79457e2672247d`
- File: `stories260K.F16.gguf`
- Size: `601248` bytes
- SHA-256: `57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3`
- Download URL: `https://huggingface.co/shibatch/stories-converted/resolve/4724c9612ac3278f58aa2dbd4d79457e2672247d/stories260K.F16.gguf`

The model file is a local verification dependency and must not be committed to
this repository.

Verified model facts:

- GGUF version: 3
- Metadata entries: 21
- Tensor entries: 48
- Architecture: `llama`
- Context length: 128
- Embedding length: 64
- Feed-forward length: 172
- Transformer blocks: 5
- Attention heads: 8
- KV heads: 4
- RoPE dimension count: 8
- Vocabulary entries: 512
- BOS / EOS / unknown token IDs: 1 / 2 / 0
- Matrix tensors: F16
- Normalization vectors: F32

Authoritative GGUF layout references:

- `https://github.com/ggml-org/llama.cpp/blob/master/ggml/include/gguf.h`
- `https://github.com/ggml-org/llama.cpp/blob/master/ggml/src/gguf.cpp`

## Current Findings

### GGUF loader

- `GGUFSeer` reads basic header, vocabulary, and tensor-table fields.
- Tensor offsets are discarded.
- Tensor descriptors point to newly allocated, zero-filled `MimirWell` storage
  rather than `mmap + aligned_data_offset + tensor_offset`.
- GGUF alignment metadata is ignored.
- Required architecture metadata is skipped.
- F32 normalization tensors are mislabeled as quantized F16 tensors.
- File bounds are not checked before most pointer reads.
- Unsupported tensor types silently fall through instead of failing closed.

### Tokenizer

- Only `tokenizer.ggml.tokens` is loaded.
- Token scores, token types, and special-token IDs are ignored.
- Pair priority is inferred from token ID rather than the model's SentencePiece
  scores.
- BOS behavior and UTF-8 byte fallback behavior are not model-driven.

### Inference

- Layer count, hidden size, head count, head dimension, and context length use
  fixed defaults.
- The target model uses grouped-query attention: 8 query heads and 4 KV heads.
  The current KV cache and attention path assume equal Q and KV widths.
- `flash_attention_2` iterates query rows using `seq_len` although incremental
  inference supplies a one-row query tensor.
- Required tensors can be represented by address `1` when missing.
- Invalid token IDs are not rejected before embedding lookup.
- Sampling is deterministic argmax, which is acceptable for this one-token
  proving slice when compared with a temperature-zero reference.

### CLI

- `aesir run <model> <prompt>` calls `run_single_shot`, but that function prints
  a fixed message and never opens the named model.

## Target Outcome

The completed slice must make this command perform real inference:

```text
aesir run /path/to/stories260K.F16.gguf "One day, Timmy went to"
```

The command must load the supplied file, report a concise validated model
summary, tokenize the prompt using model metadata, compute one next-token result,
decode it, and exit successfully. The token ID and decoded text must match a
temperature-zero run of a pinned reference build of `llama.cpp` for the same
model and prompt.

## Implementation Plan

### Phase 1: Safe GGUF reader and model configuration

1. Add bounds-checked scalar, string, and array reading inside the loader.
2. Validate magic, GGUF version, counts, dimensions, alignment, offsets, byte
   sizes, duplicate names, and required metadata before exposing tensors.
3. Preserve `general.alignment` and calculate the aligned tensor-data base.
4. Introduce a model-configuration value owned by the loader domain containing
   architecture, context length, embedding length, feed-forward length, block
   count, query/KV head counts, RoPE dimensions, RMS epsilon, and tokenizer
   special IDs.
5. Point supported F16 matrix tensors directly into the read-only mmap region.
6. Convert the small required F32 normalization vectors to F16 once at load time
   using `MimirWell`; do not pretend they are quantized tensors.
7. Reject unsupported architectures, required tensor types, malformed shapes,
   and truncated files with an explicit failure state. Never return an address-1
   sentinel as usable model storage.

### Phase 2: Model-driven RuneWeaver

1. Load `tokenizer.ggml.tokens`, `tokenizer.ggml.scores`,
   `tokenizer.ggml.token_type`, and special-token IDs as one validated tokenizer
   configuration.
2. Implement the Llama/SentencePiece merge priority needed by the reference
   model, including UTF-8 byte fallback and model-controlled BOS handling.
3. Validate encode and decode behavior against reference token IDs.
4. Keep tokenizer state immutable during generation.

### Phase 3: Configured single-device Llama inference

1. Construct transformer blocks from parsed model configuration rather than
   32-layer defaults.
2. Size workspace and KV cache from the model dimensions and requested context.
3. Represent KV width independently from query/hidden width.
4. Add grouped-query attention mapping from each query head to its KV head.
5. Correct incremental attention so a one-row query attends over the active KV
   sequence without reading nonexistent query rows.
6. Validate every required tensor and shape before starting inference.
7. Reject out-of-range prompt and generated token IDs.
8. Preserve deterministic argmax sampling for this slice.

### Phase 4: Real CLI connection

1. Make `run_single_shot` treat its model argument as a supplied GGUF path.
2. Construct `AesirEngine`, generate exactly one token, print the real decoded
   result, and propagate loader/inference failures.
3. Remove the simulated success response from this execution path.
4. Leave interactive REPL, HTTP streaming, registry pulls, quantized inference,
   and accelerator backends outside this slice.

### Phase 5: Verification and living documentation

1. Expand GGUF unit tests for alignment, metadata, tensor offsets, truncation,
   invalid types, and failure states.
2. Expand tokenizer tests for scores, special IDs, UTF-8, byte fallback, and
   round-trip behavior.
3. Add an opt-in real-model integration test using a dynamically supplied local
   path and the pinned checksum above.
4. Capture reference tokenizer and first-token results from a pinned temporary
   `llama.cpp` build outside the repository.
5. Run the full existing proving suite, the real-model integration test, a clean
   Mojo build, and the real CLI command.
6. Update affected `INTERFACE.md` files, test documentation, `TODO.md`, and
   `DEVLOG.md` only after implementation behavior is verified.

## Expected Files Involved

- `aesir_engine/loader/gguf.mojo`
- `aesir_engine/loader/tokenizer.mojo`
- `aesir_engine/core/mimir_well.mojo`
- `aesir_engine/core/compute.mojo`
- `aesir_engine/core/inference.mojo`
- `aesir_engine/aesir.mojo`
- `aesir_engine/cli/repl.mojo`
- `aesir_engine/cli/commands.mojo`
- `aesir_engine/tests/test_gguf.mojo`
- `aesir_engine/tests/test_tokenizer.mojo`
- `aesir_engine/tests/test_inference.mojo`
- `aesir_engine/tests/test_real_gguf.mojo` (new)
- `aesir_engine/tests/INTERFACE.md`
- `aesir_engine/tests/README.md`
- `aesir_engine/loader/INTERFACE.md`
- `aesir_engine/core/INTERFACE.md`
- `aesir_engine/INTERFACE.md`
- `TODO.md`
- `DEVLOG.md`

If implementation proves that another file must change, its inclusion will be
reported before expanding the task boundary.

## Constraints

- Mojo remains the only runtime language.
- No Python or C/C++ inference dependency may enter the runtime.
- No model weights may be committed.
- The mapped GGUF file is immutable.
- Existing public APIs should remain stable unless the interface documentation
  is updated in the same change.
- Existing tests must continue to pass.
- The implementation must not claim support for an unverified architecture,
  quantization, accelerator, or transport path.
- No Q4/Q8 inference, network downloader, HTTP streaming, multi-GPU, NPU, or
  production benchmark work is included in this slice.
- No file, function, or module will be deleted without Volmarr's approval.

## Acceptance Criteria

- The pinned model's 21 metadata entries and 48 tensor entries are parsed.
- Required architecture values equal the verified facts listed above.
- Every supported F16 matrix descriptor points into its correct mmap tensor-data
  range.
- Required F32 normalization vectors are converted once and numerically checked.
- Missing, malformed, truncated, or unsupported models fail explicitly before
  inference.
- The reference prompt's token IDs match `llama.cpp`.
- The first argmax token ID and decoded text match `llama.cpp`.
- `aesir run <real-model-path> <prompt>` executes this real path and prints no
  simulated inference result.
- The full existing test suite passes.
- The real-model integration test passes using the pinned SHA-256 fixture.
- A clean Mojo build succeeds.
- Documentation describes only behavior demonstrated by the verification run.

## Explicit Non-Goals

- High-quality multi-token conversation
- Temperature, top-k, top-p, repetition penalties, or stochastic sampling
- Chat templates
- Quantized tensor execution
- Real GPU/NPU kernel dispatch
- Ollama registry compatibility
- Hugging Face downloading
- HTTP or OpenAI API integration
- Performance optimization or benchmark publication

Those become later tasks after this vertical slice establishes a trustworthy
foundation.
