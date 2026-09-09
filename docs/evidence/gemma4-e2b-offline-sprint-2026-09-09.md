# Gemma 4 E2B offline sprint evidence — 2026-09-09

## Outcome

Project Aesir can run the pinned Gemma 4 E2B Q4_K_M model locally through its
native Mojo/CUDA engine with a 16,384-token context allocation. The same loaded
engine is available through interactive TUI chat and a foreground
Ollama-compatible loopback service. No inference request needs network access.

## Pinned artifact

- Repository: `unsloth/gemma-4-E2B-it-GGUF`
- Revision: `0314792d7f1f7e229411f620751375812bb9faf2`
- Filename: `gemma-4-E2B-it-Q4_K_M.gguf`
- Bytes: `3106738272`
- SHA-256: `740185b21d22ceb83a11c3aa62ad5842ef32c70f6096d756bbee85a1e4ec34b8`
- Catalog identity: `gemma4-e2b:latest`

The catalog import rehashed the source and stored the same digest and byte
count in `.aesir/models/catalog.v1`. A restart resolved and reverified the model
through its immutable `.aesir/models/blobs/sha256/<digest>` path.

## Verification

- Clean Ada-targeted Mojo build: pass.
- Counted master suite: 173 passed, 0 failed, 1 skipped, 174 total.
- Real CUDA single shot: “Two plus two equals four.” with EOS.
- Tokenizer parity: 6/6 independent cases passed.
- Persistent E2B chat: 20/20 turns completed at context 16,384; final context
  use was 1,378 tokens and every turn stopped at EOS.
- TUI physical check: detected `Gemma 4 E2B / CUDA`, showed context `38 / 16384`,
  measured 11.90 generated tokens/second on the short probe, and accepted
  interactive input.
- Durable model store: SHA-256 identity and 3,106,738,272-byte size verified.
- `GET /api/version`: returned Aesir compatibility version JSON.
- `GET /api/tags`: returned `gemma4-e2b:latest`, its digest, size, family, 2B
  parameter label, and Q4_K_M quantization.
- `POST /api/show`: returned the stored Modelfile and `num_ctx 16384`.
- `POST /api/generate` with `stream:false`: returned `Four`, `done:true`, and
  `done_reason:"stop"` from physical CUDA inference.
- `POST /api/chat` with supplied prior messages: returned `Birch.` after the
  earlier user message established that fact.
- `num_ctx:16385`: rejected with HTTP 400 before generation.
- Foreground Ctrl+C shutdown: clean.

## Honest boundary

The 20-turn model response omitted the usual coordinator's name from its final
compressed handover despite retaining and answering that fact correctly in an
earlier turn. This is a model-answer quality miss, not a lost CUDA session: all
20 turns, cumulative KV/context state, and EOS transitions completed normally.
Ollama NDJSON streaming, concurrency, daemonization, OpenAI compatibility, and
contexts above 16,384 remain outside this sprint.

## Offline commands

```bash
# Interactive native chat with the live dashboard
.aesir/aesir chat .aesir/models/gemma-4-E2B-it-Q4_K_M.gguf \
  --accel cuda --context 16384 --max-tokens 4096 --tui

# Ollama-compatible foreground service
.aesir/aesir serve gemma4-e2b:latest --accel cuda --ollama \
  --context 16384 --max-tokens 256
```
