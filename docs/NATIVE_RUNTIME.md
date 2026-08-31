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
for the mapped model, one pinned staging chunk capped at 64 MiB and a four-byte
output. Transfers use exact device subviews and synchronize before reusing the
chunk, including the short final transfer. No model weights are staged through
the CPU during inference. `compute plan` and session startup report
`host_staging_bytes`; the mapped-file allowance remains conservative.
Host admission intersects procfs with each visible cgroup v2 ancestor's
`memory.max - memory.current` headroom (clamped at zero), and the minimum
finite limit. Mount roots, subtree mounts and kernel path escapes are resolved
from the process's membership and mountinfo. The process must stay in the same
cgroup during observation. Unreadable or malformed values fail admission;
known v1 memory control is explicitly rejected rather than treated as unlimited.
Namespace-hidden ancestor limits remain unobservable, and observations can race
with other allocations. This is a conservative snapshot, not a reservation or
an OOM guarantee. The kernel's [cgroup v2 memory contract](https://docs.kernel.org/admin-guide/cgroup-v2.html)
defines the counters used here.

`hardware list` reports the memory source and observed cgroup levels. Three
counted cases cover mount resolution, nested budgets and malformed observations.
A real user service with `MemoryMax=256M` reported exactly 268,435,456 bytes and
rejected a model allowance exceeding that budget, without allocating the model.
On Linux with a user systemd manager, reproduce this opt-in kernel check:

```bash
pixi run mojo build --target-accelerator sm_89 \
  aesir_engine/tests/test_observed_cgroup.mojo -o .aesir/test-observed-cgroup
systemd-run --user --pipe --wait --quiet -p MemoryMax=256M \
  "$PWD/.aesir/test-observed-cgroup"
```

The fixture above changes only its transient user service's memory limit;
normal engine execution never changes cgroup limits. This admission is wired
to native CUDA plans and sessions; generic CPU arena admission is separate.

For the pinned artifacts, explicit host mapping/upload allowance falls from
9,385,337,924 to 4,759,777,828 bytes (Stheno) and from 9,954,343,172 to
5,044,280,452 bytes (Gemma). These are buffer-accounting values, not measured
whole-process peak RAM. GPU weight/KV requirements are unchanged.

A separate paired load/exit measurement on the observed WSL2/NVIDIA host used
`/usr/bin/time -f MAX_RSS_KIB=%M`, context 512, completion ceiling 64 and `/bye`
on stdin. With the same pinned models and sampling defaults:

| Model | Full-copy peak RSS (KiB) | Bounded-copy peak RSS (KiB) |
|---|---:|---:|
| Stheno | 10,712,272 | 6,125,384 |
| Gemma | 11,305,684 | 6,443,800 |

This is one run per binary/model, not a cross-platform benchmark. Both model
chat/control regressions also pass after changing the uploader.

The physical upload test compares every byte in nine round trips totaling
201,457,805 bytes, including exact boundaries, small chunks and one-byte tails
after 64/128 MiB. Three invalid upload requests reject; two counted tests cover
staging bounds and host admission. Reproduce with:

```bash
pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/test_cuda_upload.mojo
```

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
have no effect. Deterministic selections do not advance the random draw
sequence. Plain greedy retains the existing selection path. Non-finite
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

- `/show`: context usage, sampling policy, timeout and reset-required state.
- `/set <setting> <value>`: update temperature, top-k, top-p, min-p,
  repeat-penalty, seed or timeout-ms. Use names without `--`. Changing the seed resets the
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

## Cancellation and deadlines

Native CUDA chat accepts `--timeout-ms 0..3600000` (zero disables the deadline)
and `/set timeout-ms N` between turns. The monotonic deadline covers native
prompt ingestion and generation, checked between tokens. It does not preempt
an in-flight CUDA operation and is not a hard real-time wall-clock limit.

Ctrl+C during generation finishes with `cancelled`, closes the assistant turn
with the model's EOS and keeps the loaded session usable. A generation deadline
finishes with `timeout` and the same recovery semantics. Ctrl+C at idle exits
cleanly. Interrupted prompt ingestion is different: partial KV state cannot be
rolled back safely for every profile. Chat reports `reset_required=True` and
rejects subsequent prompts until the user explicitly requests `/clear`.
Execution failures remain fatal; cancellation never revives a failed device.

The Linux executable bootstraps `chat` through `/proc/self/exe` once when needed,
preserving arguments/environment/PID while making pre-main MAX workers inherit
blocked SIGINT. A signalfd receives it synchronously; no asynchronous signal
handler runs Mojo. Other commands keep their existing signal behavior. Embedded
users own a pollable cancellation descriptor for the entire session lifetime;
`configure_control(timeout_ms, cancel_fd)` borrows it without consuming/closing
it. Calls, including explicit `cancel()`, must be serialized at token boundaries.
This is not a thread-safe concurrent cancellation API or secure KV erasure.

Three counted tests cover deadlines, invalid controls and signal ownership.
The real CLI test checks every runtime thread's mask, sends process-wide SIGINT,
verifies next-turn arithmetic recovery, forces a prefill deadline, checks the
explicit reset gate, then verifies idle Ctrl+C exit. Both Stheno and Gemma passed
at 1,024 context positions and a 128-new-token ceiling on the observed GPU.

```bash
python scripts/test_native_cancellation.py --binary ./aesir \
  --llama models/L3-8B-Stheno-v3.2-Q4_K_S.gguf \
  --gemma models/gemma-4-E4B-it-Q4_K_M.gguf
```

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
on CUDA device 0. With sampling/upload tests the master suite passes 167 cases with
one external skip (168 total).
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
