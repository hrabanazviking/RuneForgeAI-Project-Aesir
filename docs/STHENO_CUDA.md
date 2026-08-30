# Native Stheno CUDA download and roleplay

The admitted profile is dense, text-only Llama 3 8B with the original 8K RoPE
configuration. Aesir implements its byte-level BPE, chat framing, quantized
transformer operations, F16 KV cache and greedy decoding in native Mojo.
No external inference engine or CPU model offload is used. Host code performs
tokenization, scheduling and I/O; this does not promise constant GPU utilization.

## Download and chat

Use the locked Pixi Linux/WSL2 environment and a compatible NVIDIA GPU. The
observed device is an RTX 4070 Laptop with 8,188 MiB VRAM. Packed weights consume
4,692,668,960 bytes and the 8,192-position F16 KV cache consumes 1,073,741,824
bytes, plus activations and CUDA/runtime allocations. Other applications need
to leave enough VRAM free. CUDA allocation/execution failures do not fall back
to CPU.

```bash
pixi run mojo build aesir_engine/main.mojo -o /tmp/aesir
/tmp/aesir pull bartowski/L3-8B-Stheno-v3.2-GGUF \
  L3-8B-Stheno-v3.2-Q4_K_S.gguf \
  --revision dcf7446b0049ee524188ea0b15bd9a5e24cd889b \
  --sha256 2234b17374b1f4781b663c03df24d2bc64fc8474c427b7ca318948535e65e259 \
  --size 4692668960 --connections 8 \
  --output /path/to/L3-8B-Stheno-v3.2-Q4_K_S.gguf
/tmp/aesir chat /path/to/L3-8B-Stheno-v3.2-Q4_K_S.gguf \
  --accel cuda --profile llama3 --context 8192 --max-tokens 8192 \
  --log /path/to/new-conversation.md
```

The transcript must not already exist. Interactive input uses one message per
line; `/bye`, blank input or EOF ends chat. `--prompts file` runs nonblank lines
as successive user messages. The session retains all previous KV; it never
silently removes history.

The model declares an **8,192-token context, including input and output**.
`--max-tokens 8192` is a reply ceiling, not a promise of 8K output after a prompt.
Aesir reserves a closing token and reports `context_exhausted` if the remaining
space is exhausted. Subsequent input that cannot fit is rejected. Gemma's
existing full-completion-reservation policy remains unchanged. `run --accel
cuda` still targets Gemma; use `chat --profile llama3` for Stheno.

## Evidence and reproduction

- Native `pull` completed the pinned artifact and verified size/SHA-256.
- Twelve independent Hugging Face tokenizer cases, UTF-8 round trips and chat
  framing passed against the original tokenizer revision
  `4bb828f6e1b1efd648c39b1ad682c44ff260f018`.
- Thirty-five actual quantized-weight dot products matched `gguf==0.19.0`
  dequantization: maximum absolute error `4.172325e-07`.
- Physical CUDA RoPE at positions 0, 1, 127 and 8191, SiLU and F16-cache GQA
  matched 34,816 NumPy reference values. Maximum observed error was below
  `2.75e-06`. These are primitive checks, not full-model logit parity.
- A short native in-character smoke test completed with natural EOS. The
  complete 20-turn acceptance run is pending at this implementation milestone.

Opt-in tools are `inspect_llama3.mojo`, `test_llama3_tokenizer.py`,
`gemma4_quant_oracle.py --profile llama3`, `test_llama3_quant_parity.mojo`,
`inspect_llama3_kernels.mojo` and `check_llama3_kernels.py`. Build Mojo tools with
`pixi run mojo build -I aesir_engine <source> -o <binary>`; their usage messages
name required external paths. Python is reference/process tooling only.

The acceptance harness runs the native CLI and records concurrent `nvidia-smi`
telemetry:

```bash
python3 scripts/run_stheno_roleplay.py --binary /tmp/aesir \
  --model /path/to/L3-8B-Stheno-v3.2-Q4_K_S.gguf \
  --output-prefix /path/to/new-stheno-run
```

The [publisher model card](https://huggingface.co/bartowski/L3-8B-Stheno-v3.2-GGUF)
identifies CC-BY-NC-4.0. Weights remain external; that license is distinct from
the engine's license. Quantization labels describe a mixed tensor profile:
this Q4_K_S artifact contains Q4_K, Q5_K, Q6_K and F32 tensors.

General Llama-family compatibility, extended RoPE, batched prefill, sampling
beyond greedy, full-model logit parity, API serving and hardware CI are not
established by these checks.
