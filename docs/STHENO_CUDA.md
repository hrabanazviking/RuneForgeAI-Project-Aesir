# Native Stheno CUDA download and roleplay

The admitted profile is dense, text-only Llama 3 8B with the original 8K RoPE
configuration. Aesir implements its byte-level BPE, chat framing, quantized
transformer operations, F16 KV cache and greedy decoding in native Mojo.
No external inference engine or CPU model offload is used. Host code performs
tokenization, scheduling and I/O; this does not promise constant GPU utilization.

**Completed:** [Read the full, unedited 20-turn roleplay](evidence/stheno-roleplay-20.md).
It follows Captain Sigrun and archivist Eirik through a night at Greywake
Lighthouse, ending with the danger resolved and their departure into town.

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
- Fifteen independent Hugging Face tokenizer cases, UTF-8 round trips and chat
  framing passed against the original tokenizer revision
  `4bb828f6e1b1efd648c39b1ad682c44ff260f018`.
  Three Vietnamese cases specifically fail if whole-segment lookup is omitted.
- Thirty-five actual quantized-weight dot products matched `gguf==0.19.0`
  dequantization: maximum absolute error `4.172325e-07`.
- Physical CUDA RoPE at positions 0, 1, 127 and 8191, SiLU and F16-cache GQA
  matched 34,816 NumPy reference values. Maximum observed error was below
  `2.75e-06`. These are primitive checks, not full-model logit parity.
- The complete native conversation finished all **20 exchanges with natural
  EOS**, generating **5,152 tokens** and using **6,514 of 8,192 context positions**.
  Every turn retained the `max_new_tokens=8192` ceiling; no history was truncated.
- Concurrent NVIDIA telemetry contains 1,243 samples, reaches **100% GPU
  utilization** (274 samples), and peaks at **7,136 MiB total device VRAM used**.
  These are whole-device observations, including runtime/desktop activity, not
  an isolated performance benchmark or a constant-utilization guarantee.
- The Stheno milestone master suite reported **147 passed, 0 failed, 1 skipped,
  148 total**. The explicit external CPU regression separately passes all 32
  reference tokens and context checks. GitHub CI passed implementation commit
  `b14154351fa38d5807de5c3c54df21f571ed7f09`.
- The real-model profile rejects all eight malformed admission cases. Physical
  session tests pass length closure, context exhaustion at a 64-position test
  capacity, unchanged state after rejected input, and poisoned-session rejection.
  The rebuilt CLI also retains Gemma CUDA behavior: its post-Stheno smoke test
  answered “Two plus two equals four” with natural EOS and the 16,384 ceiling.

The final inference binary was built from that implementation and has SHA-256
`e04ee8480a3e7abb292a1e24eee143ae4fe2640959dbfe5ab434c219fd3492f1`.
The published transcript is byte-identical to the native log, SHA-256
`4bf32f0020918c510ee0e4c396f305cbc3c531d9c7d840a8be51313dd125724e`.
The raw final telemetry remains local with SHA-256
`89d8cda45013504751e62ef21bc0c8bceeb1a99beb6ced5492f10c8de7c781ea`.
Raw runtime logs, weights and binaries remain outside Git.

Reading all twenty responses shows a connected chapter: the key, cord, Astrid's
journal, the refusal to sacrifice memories/identity, Sigrun's release and the
final departure remain part of the arc. This is not flawless continuity: the
model shifts who holds the key, writes `Eirid` once in turn 13, rings the
thirteenth bell despite the timing requested in turn 18, and often exceeds the
requested prose word budget. Those model-generated imperfections are preserved,
not edited out. The turn-19 recap retains the central refusal and witness theme;
turn 20 closes the chapter without a new emergency.

An earlier full-run attempt was interrupted during its first reply after the
RoPE boundary test exposed phase error. The unedited partial transcript and
initial failed numerical output remain in `.aesir/evidence/`; the published run
was restarted from an empty session after the device-side precision fix.

Opt-in tools are `inspect_llama3.mojo`, `test_llama3_tokenizer.py`,
`gemma4_quant_oracle.py --profile llama3`, `test_llama3_quant_parity.mojo`,
`inspect_llama3_kernels.mojo` and `check_llama3_kernels.py`. Build Mojo tools with
`pixi run mojo build -I aesir_engine <source> -o <binary>`; their usage messages
name required external paths. Python is reference/process tooling only.

`test_llama3_profile.mojo` checks the admitted real metadata and eight rejected
context, shape, norm, tensor-count, head-count and RoPE cases without allocating
a GPU. `test_llama3_session_limits.mojo` is a physical CUDA state test using
explicitly forced ordinary tokens; it checks length/context closure and
rejection invariants, never roleplay quality. The transcript checker
`scripts/check_stheno_conversation.py` verifies twenty real EOS-complete exchanges
and cumulative prompt/output/context accounting; coherence is reviewed by
reading the responses.

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

Native CUDA sampling and interactive reset/settings are described in
[NATIVE_RUNTIME.md](NATIVE_RUNTIME.md); the historical 20-turn transcript remains
unchanged and used greedy selection. General Llama-family compatibility,
extended RoPE, batched prefill, full-model logit parity, API serving and hardware CI are not
established by these checks.
