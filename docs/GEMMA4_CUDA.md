# Native Gemma 4 CUDA download and chat

Aesir runs dense text-only Gemma 4 E4B Q4_K_M using its own Mojo kernels.
There is no llama.cpp subprocess, Python inference, remote API, or CPU model
fallback. Host code handles tokenization, file I/O and kernel scheduling; packed
weights, model arithmetic, activations, KV cache and greedy token selection stay
on the NVIDIA device. This is one supported model profile, not universal GGUF,
multimodal, MoE, multi-GPU, or Tensor Core optimization support.

## Build and download

Use Linux or WSL2 with a working NVIDIA driver and the repository's locked Pixi
environment. This run used Mojo 1.0.0, MAX 26.5.0 and an RTX 4070 Laptop GPU with
8188 MiB VRAM. Keep other VRAM usage low; allocation failure is an error.
When compiling on a machine without a GPU, add `--target-accelerator sm_89` to
`mojo build`/`mojo run` for the tested Ada target. CI uses this explicit compile
target; its CPU runner does not execute GPU inference.

```bash
pixi install --locked
mkdir -p .aesir/models .aesir/evidence
pixi run mojo build -I aesir_engine aesir_engine/main.mojo -o .aesir/aesir
.aesir/aesir pull unsloth/gemma-4-E4B-it-GGUF gemma-4-E4B-it-Q4_K_M.gguf \
  --revision bfc15c382204943c3a8fff0c750b94ae2364d7a3 \
  --sha256 85a896a047553e842f25297ee5b031d64ff30147d9c4af17b1e4b394cd1fab87 \
  --size 4977171584 --connections 8 \
  --output .aesir/models/gemma-4-E4B-it-Q4_K_M.gguf
```

The built-in downloader verifies the complete 4,977,171,584-byte artifact before
publishing it. It refuses to overwrite files or symlinks. A completed model can
be reused; do not repeat `pull` to the same output path. Downloads require system
curl and sha256sum; see [dependencies](DEPENDENCIES.md). Interrupted downloads
are not resumable yet. Weights are not committed to Git.

## Interactive and repeatable conversations

```bash
.aesir/aesir chat .aesir/models/gemma-4-E4B-it-Q4_K_M.gguf \
  --accel cuda --max-tokens 16384 --context 32768 \
  --log .aesir/evidence/my-conversation.md
```

Type one message per line; `/bye` or EOF exits. The model remains loaded and
retains KV state between turns. For the repeatable 20-turn conversation:

```bash
.aesir/aesir chat .aesir/models/gemma-4-E4B-it-Q4_K_M.gguf \
  --accel cuda --max-tokens 16384 --context 32768 \
  --prompts aesir_engine/tests/fixtures/gemma4_conversation_20.txt \
  --system 'You are a helpful planning assistant. Preserve agreed facts and apply later corrections. Keep each answer under 65 words, using at most two short sentences unless a list is requested. Do not invent missing details.' \
  --log .aesir/evidence/conversation-20.md
python3 scripts/check_gemma4_conversation.py .aesir/evidence/conversation-20.md
```

Log destinations must not already exist. Text streams to both console and
transcript; each completed turn records prompt/output counts, cumulative
context, completion limit and finish reason, then synchronizes the file.
`run <model> --accel cuda --max-tokens 16384 '<prompt>'` uses the same engine.

The completion ceiling is **16,384 new tokens per response**, not a request to
emit exactly that many. The 32,768-token context accommodates input and replies.
Before prefill, the engine reserves room for the entire requested completion;
it rejects an overfull request without silently truncating history. Local
attention uses a 512-position ring; global attention retains the complete
configured context. Shared layers reuse the correct earlier local/global KV.

## Evidence and boundaries

The checked conversation completed 20 exchanges and retained the corrected
budget, date, venue and responsibilities through its final handover. It used
693 generated tokens and 1,535 context positions, with 20 natural EOS stops and
the 16,384 ceiling on every turn. The first trial contained an arithmetic error;
the retained fixture explicitly corrects it in user turn 7. This evaluates
conversational correction/retention, not flawless arithmetic or general model
intelligence. Raw trial transcripts remain in local ignored evidence files.

- The full model download passed its pinned size and SHA-256.
- CUDA Q4_K/Q5_K/Q6_K/BF16/F32 matvec results passed 35 independently generated
  real-weight checks; maximum absolute error was `1.3113022e-06`.
- Six tokenizer cases matched independent Hugging Face token IDs, including
  repeated whitespace, accents, Japanese, emoji and an empty BOS-only prompt.
- A complete native CUDA prompt answered “Two plus two equals four” and emitted
  Gemma's EOS. The 20-turn run crossed the local-attention ring boundary.
- Final-run device telemetry reached 100% utilization and 7,256 MiB used.
  Utilization varies; full model offload does not promise constant utilization.
- The existing pinned CPU regression again matches all 32 oracle token IDs and
  exact decoded text, including its context-boundary check.

Numerical matvec checks are not full-model logit parity. Long 16,384-token
outputs, arbitrary Gemma variants, other GPUs and hardware CI are not claimed
as tested. Current sampling is deterministic greedy. Do not pass unsupported
sampling flags expecting them to take effect.

For independent CUDA matvec verification, install `gguf==0.19.0` and NumPy in a
test environment, generate expectations with
`python3 scripts/gemma4_quant_oracle.py --model "$MODEL" --output oracle.csv`,
then run `pixi run mojo -I aesir_engine aesir_engine/tests/test_gemma4_quant_parity.mojo "$MODEL" oracle.csv`.
For tokenizer parity, build `aesir_engine/tests/inspect_gemma4.mojo` and run
`scripts/test_gemma4_tokenizer.py --inspector <binary> --model "$MODEL"`.
