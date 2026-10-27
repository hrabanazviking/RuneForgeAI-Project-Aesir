# Platform follow-up: CPU performance and four-model support

Branch: `platform/cloud-hypervisor-epyc-perf-models` (successor to
`platform/cloud-hypervisor-epyc`; see `PLATFORM_CLOUD_HYPERVISOR_EPYC.md`
for the machine facts and the platform restoration this builds on).
Everything below was measured on the machine itself, on 2026-10-27, with
the repo's Pixi toolchain. Estimates are labelled as estimates.

## Headline result

The same command that opened the campaign —

```
aesir run heretic-3.2-1b:latest --accel cpu --max-tokens 4 "The capital of France is"
```

— went from **185.41 s wall / 4,906 MB peak RSS** (output: token 0
repeated, i.e. garbage) to **4.68 s wall / 1,311 MB peak RSS** with
correct output: a **39.6× speedup and 3.7× less memory**, before any
per-model work. All four benchmark candidate models (llama, granite,
gemma2, qwen35 — all Q4_K_M GGUF) now load, validate, tokenize
bit-exactly against llama.cpp's tokenizer, and generate coherent
on-task output end-to-end on this CPU-only VM. Per-model numbers are in
the table at the end.

## What was actually wrong (three compounding defects)

The ~60 s/forward-pass figure in the platform entry was real but it was
not the whole disease; the forward path also produced wrong results for
every Q4_K_M model. Three defects compounded:

1. **The tokenizer never implemented BPE merges.** The loader ignored
   `tokenizer.ggml.merges` entirely, and `RuneWeaver` encoded with
   score-greedy SentencePiece merging, which degenerates on score-less
   BPE vocabularies (a 173-token llama prompt became 223 tokens of
   mostly fragments), and its special-token splitter recognized only
   five hardcoded spellings. Fixed in `loader/gguf.mojo` /
   `loader/tokenizer.mojo`: merges are parsed into a rank table
   (file order = merge priority), encoding runs lowest-rank-first BPE
   over GPT-2 byte-mapped symbols, and special-token spellings are
   collected from the vocabulary itself (CONTROL / USER_DEFINED token
   types) with longest-match splitting. A SentencePiece quirk is also
   handled: piece splitting prefers `▁` over `Ġ` when both exist
   (Gemma's vocab carries a stray `Ġ` token that otherwise floods
   merges). Token counts now match `llama-tokenize` exactly on all
   four models' battery prompts.
2. **Q6_K embedding rows were decoded as Q4_0.** Every candidate file
   stores `token_embd.weight` as Q6_K, but the CPU embedding lookup
   treated anything that was not Q8_0 as Q4_0 blocks, so every model
   embedded its prompt into garbage and emitted token 0 forever.
   Fixed in `core/inference.mojo`: K-quant rows decode elementwise
   through the packed-format oracle (`packed_value`). One trap worth
   recording: `quant_format.value` is a `CompressedFormatType`
   discriminant, **not** a GGML type number (engine Q6_K = 12, GGML
   Q6_K = 14; engine Q4_K = 6/7, GGML Q4_K = 12). The new
   `ggml_kind_of_format()` in `core/packed_quantization.mojo`
   translates between the two numberings; the GEMM stack was never
   affected because it dispatches on named kinds. `_tensor_byte_size`
   also gained the missing Q2_K/Q3_K/Q5_K/Q6_K block sizes (Q6_K
   bounds had been under-counted by ~27%).
3. **Numerical verification.** A numpy ground-truth forward pass over
   the llama file (dequantized weights, same math) matches the engine
   stage-for-stage to f16 precision (embedding row, per-layer hidden
   states, final argmax ` Paris`), so the remaining behaviour is the
   models' own, not engine error.

## Speed and memory work

- **Fast K-quant GEMM** (`core/compute.mojo`): `_gemm_k_fast` handles
  Q4_K and Q6_K by decoding each 256-value super-block once into an
  f32 scratch row (SIMD nibble unpack, header read once) and running
  f32 SIMD dot products for all activation rows, instead of
  re-decoding packed values per element per row. Verified against the
  scalar oracle path (Q4_K max err identical at 0.0564; Q6_K 0.209 vs
  the oracle's 0.333 — the fast path is at least as accurate). The
  scalar path remains for Q2_K/Q3_K/Q5_K.
- **Bounded runtime context** (`aesir.mojo`): the memory pool
  previously reserved KV for each model's full trained context
  (131,072 positions → a 4.29 GB pool for the 1B). The pool now uses
  `min(16000, max(4096, context_length))`, matching the generation
  cap; the 1B's pool-derived footprint fell accordingly.
- **Pool sizing fix** (`calculate_runtime_pool_bytes`): the first
  Gemma2 battery run died with `MimirWell: memory pool exhausted` —
  the formula budgeted the KV reservation to within ~1 MB of total
  demand and under-counted Gemma2's four hidden-width norms per layer.
  The formula now counts up to four norms/layer plus q/k norms,
  doubles the workspace term, and adds 32 MiB of slack. Gemma2's pool
  is ~907 MB and its battery runs cleanly.
- **Not done, honestly:** threading and batched prefill. This Mojo
  stdlib exposes `vectorize` but no `parallelize`; the engine's
  `RuneThreadPool` is cooperative bookkeeping, not OS threads, so the
  forward path remains single-threaded. Prefill therefore runs at
  decode speed (one `forward_pass` per token). The remaining gap to
  llama.cpp on this box (~7× on the 1B) is those two items plus f32
  (non-VNNI) dot products; they are the named next steps, in that
  order of expected value.

## Architecture support added

- **Granite (granite 3.3):** metadata-driven multipliers, parsed in
  the loader and applied in the forward path — embedding ×12.0,
  attention scale 0.015625 *replacing* 1/√head_dim, residual branches
  scaled ×0.22 before each residual add, logits ÷8.0. (Granite's RoPE
  is the standard interleaved form, not NeoX.)
- **Gemma2:** tanh-approx GELU FFN (`gelu_tanh`), attention logit
  softcapping (50·tanh(s/50)) inside the GQA kernel, final logit
  softcapping (30·tanh), sliding-window attention (4096) on even
  layers, NeoX RoPE, and both post-norms applied to branch outputs
  before their residual adds. `TransformerBlock.copy()` also now
  carries the four optional norm weights it previously dropped.
- **Qwen3.5 (hybrid SSM):** a dedicated `Qwen35Block` +
  `forward_pass_qwen35` (`core/inference.mojo`), dispatched from the
  engine by architecture. Every 4th layer is full attention with a
  fused query+gate projection (split per head), per-head Q/K RMSNorm,
  partial NeoX RoPE (first 64 of 256 dims), and a sigmoid gate on the
  attention output. The other 18 layers are Gated DeltaNet: causal
  depthwise conv1d (kernel 4, ring state), L2-normalized q/k, and the
  delta-rule recurrence over an f32 state matrix (16 heads × 128 ×
  128 per layer, ~18 MB total, heap-held in `Qwen35State` and reset
  per generation), closed by per-head RMSNorm gated by silu(z). The
  loader validates qwen35 files layer-type-aware (no `ffn_norm`
  exists in this arch; `post_attention_norm` is the pre-FFN norm).
  For text input, llama.cpp's MRoPE sections reduce to plain partial
  RoPE, which is what is implemented.

## Per-model results (Aesir, this VM, greedy decoding)

Battery = the four Aurelia awareness prompts in each model's
`model-tests` directory (native chat format, ~170–290 prompt tokens).
llama.cpp figures are the same-prompt tournament numbers from each
directory's `BENCH_REPORT.md` (temp 0.3, 2 threads) for orientation —
decoding settings differ, so compare speeds, not tokens.

| Model (arch) | Aesir s/pass | Aesir tok/s ≈ | Peak RSS | llama.cpp tg | Battery |
|---|---|---|---|---|---|
| Heretic 3.2 1B (llama) | 0.31–0.36 | 2.8–3.2 | 1.38 GB | 19.64 t/s | 4/4 valid JSON* |
| Heretic Granite 3.3 2B (granite) | 0.71–0.93 | 1.1–1.4 | 2.78 GB | 10.91 t/s | 4/4 valid JSON* |
| Hereticsutra Mini 2B (gemma2) | 0.64–0.72 | 1.4–1.6 | 2.56 GB | 9.57 t/s | 4/4 valid JSON* |
| Qwen3.5 2B Heretic (qwen35) | 0.62–0.68 | 1.5–1.6 | 2.12 GB | 12.71 t/s | 4/4 coherent think traces† |

\* At the 96-token sweep budget most responses are well-formed JSON
that does not close before the budget ends (the models write verbose
nested `zone_effects`); granite T3 closed completely inside 96
tokens. 220-token completion proofs were run for llama T1, granite
T2, and gemma2 T1: all three deliver complete, parser-valid JSON
(granite and gemma2 with all six required keys at top level; the
llama model nests its deltas inside `zone_effects`, its own schema
quirk, also observed under llama.cpp in the tournament).
† The Qwen file is a thinking variant: it reasons in a `<think>`
trace before the JSON, exactly as under llama.cpp, and the trace
consumes the budget first (220-token runs end mid-trace, coherent
and on-task throughout).

Catalog names: `heretic-3.2-1b:latest`, `heretic-granite-3.3-2b:latest`,
`hereticsutra-mini-2b:latest`, `qwen3.5-2b-heretic:latest`.

## Known limitations

- Single-threaded forward path; prefill is per-token (see above).
- BPE *decoding* now inverts the full GPT-2 byte map
  (`_bpe_inverted_bytes` in `loader/tokenizer.mojo`, used by both
  `RuneWeaver.decode` and the stream decoder): every token codepoint
  maps back to exactly one original byte, so non-ASCII output is
  byte-exact. Verified regression-free: the llama T1 battery output
  is byte-identical before and after the change. One residual
  behaviour: per-token decoding can surface a transient partial
  UTF-8 sequence mid-stream when a multi-byte character is split
  across tokens; the accumulated text is correct, and the stream
  decoder buffers incomplete sequences properly.
- Sampling on the CPU path is the engine's existing sampler
  (temperature/top-k/top-p/repetition penalty); the catalog entries
  pin temperature 0.0 for deterministic runs.

## Verification

- `test_inference.mojo`: all 10 sections PASS.
- `test_cli.mojo`: 7/7 suites PASS.
- Tokenizer parity vs `llama-tokenize` on all 16 battery prompts
  (counts match; the runs show one fewer token than the file-based
  count because the shell strips the prompts' trailing newline).
- The Hailo path (`cli/hailo_commands.mojo`, hailo10h code, the
  fail-closed stub) is untouched by this branch and still fails
  closed on this machine.
