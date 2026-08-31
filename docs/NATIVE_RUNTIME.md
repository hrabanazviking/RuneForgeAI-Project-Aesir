# Native hardware and runtime controls

The runtime-expansion work connects the heterogeneous proposal to the existing
native model sessions. This is a single-device implementation, not completion
of the proposed AMD/Metal/NPU/multi-device backend matrix.

## Inspect before loading

```bash
aesir hardware list
aesir compute explain model.gguf --profile auto --context 8192
aesir compute plan model.gguf --device 0 --reserve-mib 512
aesir chat model.gguf --accel cuda --profile auto --device auto \
  --context 8192 --max-tokens 256 --reserve-mib 256
aesir run model.gguf --accel cuda --max-tokens 32 "Hello"
```

`hardware list` reads the Linux CPU model and `MemTotal`/`MemAvailable` from
procfs, then enumerates CUDA through MAX. Missing CUDA is reported separately
from the usable CPU path. GPU memory values are attributed to
`DeviceContext.get_memory_info`; they need not equal an advertised board size
or whole-machine `nvidia-smi` readings. Memory sharing is reported unknown
because this adapter has not probed it. Other backends are not probed or
represented as working.

`compute plan` and `compute explain` have the same checked behavior. They map
GGUF metadata, validate one implemented tensor profile, calculate explicit
weight/KV/activation/sampling/output bytes, inspect available memory and select a fitting
CUDA device. They do not upload weights or promise tokenizer compatibility.
`auto` selects the compatible fitting device with the most reported free
memory, breaking ties in enumeration order; this is not a speed benchmark.
An explicit device never falls through to another device or to CPU.

The same buffer calculation runs immediately before either CUDA session
allocates. The default reserve is 256 MiB. Driver, allocator and tokenizer
overhead are not exact model-buffer counts; memory observations can race with
other processes, so allocation errors still propagate. Host admission accounts
for both the mapped model and a full pinned upload copy. Linux procfs memory
does not yet account for stricter container/cgroup limits.

`run --accel cuda` now detects either supported CUDA profile. `chat` preserves
its default Gemma profile for compatibility; `--profile auto` inspects metadata
and chooses the corresponding defaults. Model-specific shapes and tokenizers
still have to pass admission. Unsupported GGUFs do not become supported merely
because their architecture string says `llama`.

## Native sampling and interactive controls

Both CUDA chat profiles accept these independent options:

| Option | Default | Accepted range |
|---|---:|---|
| `--temperature` | 0 (greedy) | finite, nonnegative |
| `--top-k` | 40 | 1..256 |
| `--top-p` | 0.95 | greater than 0, at most 1 |
| `--min-p` | 0 | 0..1 |
| `--repeat-penalty` | 1 | positive, finite |
| `--repeat-last-n` | 64 | 1..8192 |
| `--seed` | 42 | 0..18446744073709551615 |

```bash
aesir chat model.gguf --accel cuda --profile auto --context 8192 \
  --max-tokens 256 --temperature 0.8 --top-k 40 --top-p 0.9 \
  --min-p 0.05 --repeat-penalty 1.1 --repeat-last-n 64 --seed 42
```

CLI fractional values use unsigned decimal syntax such as `0.8` (no signs,
exponents, NaN or infinity). Duplicate, unknown and out-of-range flags fail
before model/transcript I/O. `run` and the legacy configuration-file sampler
are separate surfaces; these flags currently belong to native CUDA `chat`.

Repetition penalties apply once to each token present in the last N processed
tokens, including prompt and framing tokens: positive logits are divided by
the penalty, negative logits multiplied. Then CUDA selects exact top-k, applies
temperature, removes probabilities below `min-p` times the maximum, retains
the smallest sorted prefix reaching `top-p` of that filtered probability mass,
and samples using SplitMix64 keyed by seed and draw index. Ties favor lower token
IDs. Temperature zero selects the maximum adjusted logit; top-k/p/min-p then
have no effect. Plain greedy retains the existing selection path. Non-finite
logits fail both paths. The non-greedy/penalized Llama path excludes reserved
control IDs except its two supported EOS IDs.

Logits, candidate selection, probability calculation and repetition history
stay on CUDA; only the chosen token returns to the host. This initial exact
selection implementation prioritizes correctness; it is not a throughput
optimization. Sampling workspaces add 810,496 bytes for Llama and 1,346,048
bytes for Gemma, included under activation/workspace bytes in `compute plan`.
Seed replay is verified on the observed device/toolchain; cross-device floating
point identity is not promised.

Interactive commands run between turns:

- `/show`: context usage and the current sampling policy.
- `/set <setting> <value>`: update temperature, top-k, top-p, min-p,
  repeat-penalty or seed. Use names without `--`. Changing the seed resets the
  draw sequence; changing other settings preserves it.
- `/clear`: explicitly discard conversational context, repetition history and
  draw sequence, while keeping the model loaded. Current settings and system
  prompt remain. KV storage is reused behind a reset position, not securely
  erased; no old positions are attended before replacement.
- `/help` and `/bye`: show controls or exit.

The repetition window is fixed when a session is created. Invalid controls and
prompts that cannot fit the remaining context are reported without changing
healthy history; the user can clear explicitly and continue. CUDA execution
failures still poison the session and terminate. Prompt-file lines are literal
user messages, including slash-prefixed text. Transcripts include successful
settings/reset events and rejection messages and never overwrite existing files.

### Sampling verification

```bash
pixi run mojo build --target-accelerator sm_89 \
  aesir_engine/tests/test_cuda_sampling.mojo -o .aesir/test-cuda-sampling
python scripts/test_cuda_sampling.py --binary .aesir/test-cuda-sampling
python scripts/test_native_chat_controls.py --binary ./aesir \
  --llama models/L3-8B-Stheno-v3.2-Q4_K_S.gguf \
  --gemma models/gemma-4-E4B-it-Q4_K_M.gguf
```

The independent test uses full CPU sorting and probability arithmetic, not the
production kernel. All 896 physical CUDA decisions matched across 14 cases:
ties, small and multi-partition vocabularies, negative/extreme logits, truncated
probabilities, repetition-window eviction, seed extremes, reset/replay, EOS
eligibility, empty candidate sets and non-finite rejection. Three additional
counted tests cover strict syntax, invalid configurations and immutable updates.
Both real models passed four-turn sampled/greedy reset replay at context 512
with 64 maximum new tokens, invalid control/prompt recovery and durable
exclusive-log checks. The pinned CPU 32-token/text/context oracle still passes.

## Verification

Five counted hardware-independent cases cover malformed memory observations,
exact profile byte counts, overflow/reserve/host-budget rejection, injected
multi-device policy and invalid CLI options. The opt-in physical test is:

```bash
python scripts/test_native_planning.py --binary ./aesir \
  --llama models/L3-8B-Stheno-v3.2-Q4_K_S.gguf \
  --gemma models/gemma-4-E4B-it-Q4_K_M.gguf
```

This test passed on Linux/WSL2, Intel i7-12700H and NVIDIA RTX 4070 Laptop GPU,
with locked Mojo 1.0/MAX 26.5: both profiles were planned and executed, and
impossible reserve/device requests were rejected before upload. Multi-device
selection is tested with injected records; physical execution was checked only
on CUDA device 0. With sampling tests the master suite passes 155 cases with
one external skip (156 total).
After integrating concurrent Gemma 3 development, the pinned 32-token CPU
oracle still passes. Restored mandatory download identity checks and failure
assertions, bounded CPU token/shape handling and stable CUDA tanh. CPU packed
Q4_K/Q6_K matmul now also matches 25 independent Stheno weight-row references
(maximum absolute difference 0.00018817186 after F16 output rounding).

The new Gemma 3 CPU development paths are retained, but this task has not
verified their full-model output. Existing CPU block objects with SIMD fields
are not canonical packed GGUF layouts; the repaired raw-byte matmul tests no
longer reinterpret those padded objects as wire-format model data.
Independent model/kernel references and earlier conversations remain in
[the Gemma guide](GEMMA4_CUDA.md) and [the Stheno guide](STHENO_CUDA.md).
